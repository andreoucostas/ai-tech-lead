# B-232 B: bounded native read-recovery observation

Status: revised after independent blind-first critique; final check precedes dispatch.
Baseline: v0.86.1, `e47b3b6` (resolve full object in the evidence packet).
Authority: user accepted the next-step proposal with "ok let's do it" on 2026-09-09.
This authorizes the bounded read-only observation and evidence-supported small repair;
it does not reopen ABP adoption, RK1, or other campaigns.

## Scope and proportionality

The retained native Copilot 1.0.83 observation returned an oversized-file message
instead of the adoption workflow while marking the tool result successful. Delivery A
already shipped the archive schema correction. Test the existing delivery-B paragraph
in the existing rules carrier before deciding whether to ship it. A single read-only
public-document observation is proportionate; phase splitting and new runners are not.

Alternatives: retain current rules plus operator-directed paging; add the proposed
short recovery paragraph if the named observation succeeds. One success shows retrieval
and bounded comprehension in that run, not causal improvement or adoption completion.

## Frozen task and route

Use a disposable local Git root containing only copies of the released .NET public
instruction documents and the candidate rules carrier. No consumer data, hooks,
scripts, adoption marker, secrets, or remote. Evidence and grading stay outside it.
Keep native instruction loading enabled. Copy the ordinary CLAUDE.md, AGENTS.md and
Copilot instruction carrier required by that loading route. The workflow is the exact
released dotnet adopt.md; do not pad, shrink, or rewrite it to provoke a failure.

Native Copilot CLI 1.0.83; `claude-sonnet-5`, medium effort, fresh UUID session,
prompt mode (memory disabled), no remote/export, no auto-update, builtin MCP disabled,
temporary-directory auto-access disabled. Expose only `view`; deny shell, write and URL
tools; retain normal path checks. Inspect actual tool/context events. No MCP/plugin
configuration may add a second callable surface. Use a new COPILOT_HOME with only
the existing signed-in account selection copied, no inherited user settings/plugins/MCP/hooks,
and clear additional-instruction/provider/telemetry overrides in the child environment.
Keep OS credential-store authentication; never copy or print credentials. If that
route cannot authenticate, stop rather than changing authentication machinery.
Set supported `disableAllHooks=true`, `ide.autoConnect=false`, `memory=false`, and
`customAgents.defaultLocalOnly=true` in that isolated configuration.

One model session, a configured 30-AI-credit threshold and 15 elapsed minutes. No resume or semantic
retry. Capture exact arguments, prompt, process exit, typed events, usage receipt and
before/after file hashes. A timeout retains partial evidence and stops the process.
Local CLI help says one completed call can exceed that threshold before another call
is blocked. It is not a hard spend ceiling; report the actual receipt and any overrun.

Exact user prompt:

> This is a read-only documentation question, not an instruction to execute adoption.
> First use view on .claude/commands/adopt.md without a line range. Then determine
> from that workflow the governing interactive/headless mode rules, early stops,
> archive and pending-marker recovery requirements, and completion conditions.
> Give a concise source-grounded answer with line references. Do not execute the
> workflow, run commands, modify files, or ask for adoption approval.

The prompt deliberately triggers the initial full-file read; it does not prescribe
the recovery method or reproduce the candidate paragraph. No claim of spontaneous
trigger selection or comparison against a matched old-rule arm follows.

## Candidate

Insert one paragraph after the Verification Rules introduction and before the
stack marker in `src/core/.github/instructions/framework-rules.instructions.md`:

> A size limit, error, or truncated response is not a completed read. When a task requires
> a workflow's governing instructions, obtain them completely through bounded contiguous
> ranges, including mode overrides, precedence/early stops, marker lifecycle, failure
> recovery and completion conditions wherever they appear. Headings and search hits
> locate instructions but do not replace reading them. If required instructions remain
> unreadable, report cannot-examine and do not execute a guessed procedure.

Prepare this as an external candidate copy first. No shipped source edit before the
route and critique are accepted. The trigger is deliberately broader than the earlier
proposal's "before executing": a documentation question requiring the governing
instructions now falls within it. This adjudicates the independent blind-first
critique; the obligation applies equally to reading and execution tasks.

## Observations and stop rules

Require the exact candidate paragraph in initial native system context before the first
workflow read. Require a real oversized-file result, followed by successful contiguous
range reads collectively covering every actual workflow line. Tool success alone,
search hits, actor claims, or ranges whose returned text is truncated do not count.
Inspect matched tool calls/results, source text and actual returned endpoints.

Grade source-grounded obligations separately: interactive approval; headless restricted
surface (inability to meet it prevents conforming execution, an inference from the
requirement rather than an explicit quoted stop in that paragraph); frozen archive
integrity and legacy cannot-verify;
pending-marker lifecycle and the two archive verification checkpoints; bootstrap and
documentation completion. Freeze exact source line anchors in the external packet
before dispatch. A wrong or omitted material obligation is a semantic miss.

Required answer groups (equivalent accurate paraphrases accepted):

- Lines 17–44, 50–54, 143, 161, 193, 233–236, 299: interactive branch/merge-plan
  confirmation and per-file quarantine approval; headless stages external merges for
  human review, excludes quarantine, propagates headless bootstrap with unverified
  hazards, and never opens/merges a PR. No exhaustive list of unrelated phase details
  is required, but these mode/approval distinctions must be correct.
- Lines 21–23, 50–54, 96, 199: clean-tree requirement, three headless denials,
  failed inventory or missing/malformed ownership stops; legacy GitHub skills cause
  a pre-Phase-2 stop with marker intact and manual review/migration, never automatic
  movement or trust upgrade. Protected live framework paths are not legacy inputs.
- Lines 209–225: object-with-entries plan, freeze all selected pairs once before moves,
  exact frozen-pair helper only, no silent re-hash/rebaseline; only verified moves
  or narrow exact-digest crash recovery count as progress.
- Lines 308–340: pre-bootstrap Verify PASS, exact marker backup, marker removed only
  immediately before bootstrap, bootstrap gate PASS and post-gate Verify PASS;
  FAIL/CANT-VERIFY or non-PASS restores exact marker and retains both recovery files,
  stops before final report/commit; legacy absence of pre-move digests cannot verify.
  On success remove temporary plan/recovery files, retaining archived originals.
- Lines 344–390: updated canonical/mirror files, applicable preserved archives/evidence,
  all three passing checks, reported evidence and final commit; headless default-branch
  marker/guards persist until a human merges. A documentation-shape pass is insufficient.

Calibrate the observation against the retained real oversized-read event (failure is
not content), an intentionally omitted range (incomplete), and complete source-bound
contiguous range records (reachable success). Synthetic records calibrate the observer,
not native model behavior. Unavailable initial context, no real size error, missing
receipts, route mismatch or truncated evidence is cannot-examine / not exercised,
not product failure or a passing observation. Any actor write or forbidden tool call
fails the scope. Stop without a second paid attempt; retain all outcomes.

## Delivery decision

If the full named observation succeeds, apply the one paragraph in source, compose all
three distributions, inspect placement and existing mirrors/static ceilings, perform
native PS7/PS5.1 install checks, independent frozen-range implementation review and
ordinary release/CI for v0.86.2 with all four changelogs. Do not add a comprehension regex
or new generic evaluation gate. Record live evidence separately from static checks.

If it fails or is unexercised, retain B as deferred with the exact reason, commit/push
the bounded evidence and RCA, and make no product release for an unvalidated proposal.
No result authorizes headless adoption, further model spend, host/relay engineering,
or a framework-efficacy claim. Update the existing backlog/decision record without
rewriting earlier evidence. Raw local session data remains outside authoring Git.
