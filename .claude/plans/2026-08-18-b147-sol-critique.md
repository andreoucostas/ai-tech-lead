# B-147 adversarial critique

Date: 2026-08-18

Scope: critique only. I read root `CLAUDE.md`, `meta/decisions-index.md`, B-147 in
`meta/BACKLOG.md`, and the proposed design before inspecting the implementation. I did not treat
the reported Copilot CLI 1.0.79/1.0.80 observation as disputed.

## Findings

### 1. BLOCKING — the existing control flow cannot deliver a queued nudge when routing is empty

The design says that routing and the queued Boy Scout text are independently optional, including
"if either half is empty the other is emitted alone." The proposed host does not currently reach
its surface branch in all of those cases:

- PowerShell exits for empty input/prompt at lines 110/122, for slash commands at line 125, and for
  no routed intent or security match at line 151. The non-Claude branch is only lines 187-195.
- Bash exits for an empty prompt at line 53 and slash commands at lines 55-58. `emit_body` also exits
  before the surface dispatch when neither intent nor security applies; the dispatch is lines
  205-223.

Thus merely "draining in the non-Claude branch" loses the queue on an ordinary question, an
unclassified prompt, and a slash command. This is not a test-detail correction: the implementation
must establish the surface and obtain the queue before every routing-only early exit, while still
leaving the Claude path exactly unchanged. The queue-only test must use an unclassified or slash
prompt so it proves this particular defect can fail.

Command:

```text
$ n=0; Get-Content src/core/.claude/hooks/route-prompt.ps1 | % { ... }
110: if ([string]::IsNullOrEmpty($inputJson)) { exit 0 }
122: if ([string]::IsNullOrEmpty($prompt)) { exit 0 }
125: if ($prompt.StartsWith('/')) { exit 0 }
151: if ([string]::IsNullOrEmpty($intent) -and -not $sensitive) { exit 0 }
187: if ($inputJson -match '"hook_event_name"') {
```

Command and observed output from the existing hook harness:

```text
$ . src/core/tests/hooks/_HookHarness.ps1; Invoke-Hook route-prompt.ps1 <fixture>
INPUT={"prompt":"explain this","timestamp":1}
EXIT=0 OUTPUT_BYTES=0 STARTS_JSON=False HAS_RAILS=False
INPUT={"prompt":"/review","timestamp":1}
EXIT=0 OUTPUT_BYTES=0 STARTS_JSON=False HAS_RAILS=False
```

Required design change: define the composition algorithm explicitly as (1) parse the event and
surface, (2) calculate routing text without returning, (3) on non-Claude only read and consume the
queue, (4) compose routing first and queue second, (5) emit only if the composition is non-empty.
On Claude, preserve today's early/no-output behavior and never read or remove the queue.

### 2. BLOCKING — the proposed validator scope rejects a legitimate existing configuration

The design proposes failing when "any Copilot event carries more than one hook entry." The current
registration legitimately has two independent `postToolUse` entries: `post-write` provides build
feedback and `audit-trail` performs a side effect. B-147's live observation is specific to
`userPromptSubmitted` `additionalContext`; it supplies no evidence that two hooks are invalid for
events whose effects are blocks or side effects. An all-event cardinality rule would reject the
current intended configuration.

Command and real output:

```text
$ $j=Get-Content -Raw src/core/.github/hooks/hooks.json|ConvertFrom-Json;
  $j.hooks.psobject.Properties | % { "{0}={1}" -f $_.Name,@($_.Value).Count }
sessionStart=1
agentStop=1
userPromptSubmitted=2
preToolUse=1
postToolUse=2
```

Required design change: if this residue is added, scope it specifically to
`userPromptSubmitted`, in both `validate-dist` twins, and red-test exactly that event. An even more
semantic rule (at most one model-context-producing hook on that event) would require parsing command
behavior and is not proportionate here. The one-event cardinality rule is small and directly tied
to the observed failure.

### 3. Non-blocking, but the design overstates surface detection as a clean existing branch

There is a usable branch for the two observed event shapes, but it is a raw substring test rather
than structural surface detection:

- PowerShell: line 187 tests `$inputJson -match '"hook_event_name"'` even though the event was
  already parsed at lines 114-121.
- Bash: line 213 runs `grep -q '"hook_event_name"'` over the complete raw input.

This does prove the current Claude branch for the registered Claude hook: all three stack
`.claude/settings.json` files register `route-prompt.ps1` under `UserPromptSubmit` with no mode
argument, and the hook's documented discriminator sends an event carrying `hook_event_name` to
plain stdout. Conversely, the current Copilot fixture without that member produces JSON.

Command and observed output:

```text
$ rg -n -A 4 'UserPromptSubmit|route-prompt' src/stacks/*/files/.claude/settings.json
11:    "UserPromptSubmit": [
14:          { "type": "command", "command": "pwsh ... route-prompt.ps1" }

$ Invoke-Hook route-prompt.ps1 '{"prompt":"fix the bug","timestamp":1}'
EXIT=0 OUTPUT_BYTES=2885 STARTS_JSON=True HAS_RAILS=True
```

The raw test can misclassify a future non-Claude payload containing a nested member with that name,
and it makes the PowerShell twin ignore already-parsed structure. That is weaker than "clean,
reliable" detection, but changing the established discriminator is not necessary to fix the
observed P1 and would enlarge this item. Preserve it for B-147, make the tests prove both known
shapes, and file structural detection separately if desired. Critically, the new queue read must
be gated by this test and must not occur merely because routing text is empty.

### 4. Non-blocking — moving delivery preserves the two-file state contract if it is a literal move

The Boy Scout sources are stack whole-file overrides, not core files: each of dotnet, angular, and
monorepo owns a `.ps1`/`.sh` pair. All six use the same state names and delivery protocol:

- `.claude/.state/last-boy-scout-hash`: written by scan/Claude mode after hashing the sorted current
  finding set; an equal hash exits silently. Delivery never reads, changes, or deletes it. This is
  why silence means "already flagged," not "resolved."
- `.claude/.state/boy-scout-queue`: written only by `--mode scan`; `--mode deliver` reads it, emits
  non-whitespace content, and deletes it unconditionally after the read. A missing queue is silent.
- The scan input is current Git state (`git diff`, `git diff --cached`, and untracked files), but no
  additional persistent Boy Scout state exists.

Representative dotnet lines are PowerShell 37-45 and 135-156, and Bash 37-49 and 128-151. The
angular and monorepo twins have the same state protocol at their corresponding lines.

Command and real output from the composed dotnet twin suite:

```text
$ pwsh -NoProfile -File dist/dotnet/tests/hooks/TwinParity.Tests.ps1
[ok] boy-scout twins agree: deliver emits queued Copilot context and consumes the queue
[ok] boy-scout regression: deliver with no queue never scans or speaks on a read-only prompt
...
TwinParity.Tests (.ps1 vs .sh): 11 passed, 2 failed, 0 skipped
```

The two failures were existing scan queue-presence failures in the bash leg, not delivery failures:

```text
[FAIL] boy-scout twins agree: Mongo ToListAsync has zero findings -- ... ps1 ... queue=True; sh ... queue=False
[FAIL] boy-scout twins agree: EF ToListAsync without AsNoTracking flags -- ... ps1 ... queue=True; sh ... queue=False
```

I do not attribute those failures to B-147, but they mean this suite run is not green and must not
be reported as such. A literal move of the read/non-whitespace/delete behavior into `route-prompt`
preserves the contract. Deleting the queue only after successful payload composition would subtly
change today's at-most-once contract; the design should say whether it intends that change. The
least-change answer is today's unconditional delete after read.

### 5. Non-blocking — Claude remains unchanged only if queue acquisition happens after the surface gate

Claude's separate registrations are proven by code: every stack `settings.json` registers
`route-prompt.ps1` on `UserPromptSubmit` and `boy-scout-check.ps1` independently on `Stop` (lines
11-15 and 35-39). `boy-scout-check` without `-Mode` resolves a payload containing
`hook_event_name` to `claude` mode (dotnet PowerShell lines 22-30; Bash lines 24-32).
`route-prompt` sends raw inputs containing that member to plain stdout (PowerShell 187-189; Bash
213-214).

Therefore Claude does not take the current non-Claude output branch. However, finding 1 forces queue
logic earlier than the existing branch if implemented carelessly. The regression guard must seed a
real queue, invoke a Claude-shaped prompt that produces routing text, assert no Boy Scout sentinel,
and assert the queue still exists. Merely asserting "plain stdout" is insufficient: duplicated Boy
Scout text can also be plain stdout.

### 6. Non-blocking — composition is proportionate; reorder is the correct emergency patch, not the better final fix

Arguing for reorder: it is a one-line registration change, restores all three load-bearing routing
rows immediately, cannot touch Claude, adds no parser/state/timeout behavior, and reduces the P1
harm to loss of an advisory nudge. Given finding 1, it is materially safer than implementing the
current under-specified merge verbatim. If an immediate hotfix must ship before redesign, reorder
and correct the Boy Scout CLI row.

Arguing against reorder as the locked fix: the observed failure is deterministic, the existing
queue/deliver protocol is small, and the requested merge retains both the load-bearing rail and the
advisory feature. Once finding 1 is specified, the extra implementation is bounded to reading one
known state file, composing two strings, and deleting that file. It also remains correct if the
vendor later restores multi-hook consumption. That benefit is proportionate to a P1 false guarantee
across three rows. I therefore retain merge as the preferred final fix, with reorder as a genuine
emergency fallback.

### 7. Non-blocking — no observed timeout problem; payload ceiling remains unverified

`timeoutSec` is 10. The existing PowerShell routing hook's largest exercised fixture emitted 3,369
UTF-8 bytes. Fifteen process-isolated harness runs of the current route measured 339.9 ms minimum,
362.4 ms median, and 946.6 ms maximum on this host, leaving substantial observed margin. Empty
Boy Scout delivery is just repo-root resolution plus a file-existence check; the existing composed
suite completes that path.

Command and real output:

```text
$ Measure-Command { Invoke-Hook dist/dotnet/.claude/hooks/route-prompt.ps1 <fixture> } # 15 runs
ROUTE_MS_MIN=339.9 MEDIAN=362.4 MAX=946.6
$ Invoke-Hook route-prompt.ps1 '{"prompt":"implement payment authentication","timestamp":1}'
MAX_ROUTE_OUTPUT_BYTES=3369
```

I found no payload-size ceiling in this repository (`rg -i
'additionalContext.*(limit|max|size)|payload.*(limit|max|size)' ...` returned no relevant match),
and I did not run a live Copilot host, so maximum accepted payload is **NOT OBSERVED**. The queue is
also unbounded today: one finding can be appended per changed file/pattern. Composition adds routing
text to that existing unbounded queue. This is not evidence of a current failure, but the live
re-verification should include a realistically large queue and record whether Copilot consumes it.
Do not invent a truncation policy inside this P1 without an observed ceiling.

### 8. Evidence constraints and environment corrections

Contrary to the task's expectation that this sandbox has no Bash, Git Bash is present and was used
by the composed twin suite:

```text
$ bash --version
GNU bash, version 5.2.37(1)-release (x86_64-pc-msys)
```

PowerShell 7.6.5 is present. Windows PowerShell 5.1 was not found by `Get-Command` and is **NOT
OBSERVED**. No live Copilot CLI consumption test was run. No source, generated distribution, test,
registration, documentation, changelog, or version file was modified in this phase.

## Verdict

**REQUEST CHANGES**

The premise and merge direction survive critique, but the design is not implementable as written:
its host exits before queue-only composition can happen, and its proposed all-event validator would
reject a legitimate two-hook event. Re-lock the design with the algorithm and validator scope above.
Per the requested phase gate, phase 2 stops here and no implementation is authorised in this turn.
