# B-41 remaining scope · Copilot CLI leg, B-23, cross-host evidence

**Status:** LOCKED — designed (Opus), independently adversarially reviewed (Opus, separate session) 2026-08-09,
then re-verified by a third pass (orchestrating session) which independently re-ran every load-bearing
claim from both prior passes and found one further correction (§4). Implementation must preserve this
contract; do not silently re-expand scope the three passes agreed to cut.
**Base:** `origin/master` at `4a7757a` (v0.51.5)
**Effort:** S (cut down from L) · **Priority:** P2 · **Invariants:** #1, #3, #4, #5, #7
**Process note:** this design went through three independent passes rather than the usual two, because
the second pass (adversarial review) itself contained a verification error that a third pass caught —
see §4. This is not a failure of the process; it is the process working as designed (CLAUDE.md
Maintenance rule 1: "a reviewer's corrections are input, not verdict").

---

## 0. What B-41 is and why this document is much smaller than the original item

B-41 ("Agent-behavior eval harness — close the 'prose steers a model' blind spot") shipped its Phase 1
already (maintainer-only Claude harness, typed graders, release gate). `meta/BACKLOG.md`'s entry named
three remaining pieces before DONE: a Copilot CLI eval leg, resolving B-23's open question about the
old `tests/evals/` runner, and cross-host threshold results. All three were scoped by the initial design
pass as real work. Two adversarial passes cut that down to almost nothing. **This document locks the
cut-down scope**, not the original ambition — read it as "what survived scrutiny," not "what was hoped
for."

## 1. Proportionality (rule 6) — per sub-item, as it now stands after three passes

**Sub-item 2 (B-23) — real, observed, present-tense harm. Ship it.**

Four shipped docs elevate `tests/evals/cases.yaml`/`run_evals.py` as something a consumer should run
(`dist/dotnet/docs/REVIEW-GUIDE.md:16,24`; `dist/dotnet/docs/ARCHITECTURE.md:169,194`;
`dist/dotnet/docs/playbook.md:157`; `dist/*/tests/evals/README.md:18/21/24`). The runner requires an
Anthropic API key and pinned model ids while the framework's stated primary target is Copilot/VS Code
(`src/core/docs/enforcement-surfaces.md`); it grades response text with the exact method
`meta/eval-results.md:8-13` formally invalidated on 2026-07-17; `git log` confirms it has not been
substantively edited since the merge relocation (`ca819cd`) while `cases.yaml` was touched by a B-97 doc
sweep (`9692251`) — maintained by sweeps, never run. `playbook.md:157` additionally has stale prose
("the eval harness … **when added** …") independently confirmed by the second pass — the harness IS
added; fix this in the same pass.

**Sub-item 1 (Copilot CLI leg) — cut to a narrow instrument-repair + audit step. No new behavioral harness.**

Original premise: Copilot has its own typed `events.jsonl` stream (genuinely true, independently
verified — see §3) richer than assumed, so a Copilot eval leg seemed newly cheap. Two things killed
building on it:
- The payload the design most needed (`permissionDecision: deny` inside a `preToolUse` `hook.end`) has
  **never been observed** in 38 real Copilot CLI sessions on this box — only the `additionalContext`
  shape has. All schema evidence is from CLI 1.0.71; the installed CLI is 1.0.78, seven patch versions
  later, in a repo whose own record shows hook behavior changing release to release (B-50).
- **The Copilot-shape test coverage this sub-item would have built already exists and already ships.**
  Independently confirmed (§4): `guard.ps1`, `route-prompt.ps1`, `session-start.ps1`, and
  `audit-trail.ps1` all already have Copilot-event-shape assertions in the shipped `dist/*/tests/hooks/`
  suite, covering both the deny path (`Guard.Tests.ps1`) and the `additionalContext` path
  (`RoutePrompt.Tests.ps1`, three `SessionStart*.Tests.ps1` files, `TwinParity.Tests.ps1`). There is no
  known uncovered hook-shape gap left to fill.

**Sub-item 3 (cross-host threshold evidence) — cut outright, not conditionally.**

The design's own confound check found something worse than "a weaker model tier": two real sessions in
the *same* canary folder resolved Copilot's `auto` mode to **different vendor models**
(`claude-haiku-4.5` vs `gpt-5-mini`), non-deterministically, per run. A Claude-vs-Copilot comparison
built on this is uninterpretable by construction under this repo's own pre-registered rule
(`meta/eval-results.md:279-283`). Re-scope B-41's DONE bar to "Claude behavioral evidence + Copilot
hook-shape coverage" (already true, per §0's coverage-already-exists finding) and hand the cross-host
behavioral question to B-43/B-49 (the existing quarterly recertification vehicle), with the limitation
recorded explicitly in `enforcement-surfaces.md` rather than silently dropped.

## 2. Locked scope — build only this

1. **Repair `no-dead-instruction`'s grammar** (`scripts/validate-dist.ps1` check 7, ~line 561, + its
   `.sh` twin per invariant #3). Independently confirmed (all three passes ran the actual regex):
   `(?:pwsh|bash|powershell)(?:\s+-[A-Za-z]+(?:\s+[A-Za-z]+)?)*\s+([A-Za-z0-9_./-]+\.(?:ps1|sh))` matches
   zero references in `python run_evals.py`, `python run_evals.py --model claude-sonnet-4-6`, or
   `pip install -r requirements.txt` — the exact instructions sub-item 2 needs the gate to catch. This
   is the load-bearing fix: without it, deleting the runner while a doc still says "run it" would be a
   **false green**, exactly the class Maintenance rule 4 exists to catch (B-64/B-72/B-74/B-75).
   Extend the grammar to also recognize `python <x>.py`. Red-test properly: plant the exact defect
   (runner deleted, doc reference remains), observe non-zero exit, then the clean pass.
2. **Ship the B-23 fix (2C).** Delete `src/core/tests/evals/run_evals.py` and `requirements.txt`; trim
   `src/core/tests/evals/README.md` to the "what each case proves / adding a case" material (drop
   Setup/Run). Remove the `case-cmd` composer marker from `src/core/tests/evals/README.md` **and** all
   three `src/stacks/{dotnet,angular,monorepo}/snippets/tests/evals/README.md/case-cmd` files (the
   composer trap both review passes independently caught — deleting the Run section without removing
   the marker breaks the build). **Leave `case-id` in place** (same directory, feeds the "Adding a case"
   section, survives 2C) but confirm during implementation that it still resolves correctly once
   `case-cmd` is gone. **Keep** `src/stacks/*/files/tests/evals/cases.yaml` ×3 — the documentary half has
   real, cited value (WSD-013 reviewer-profile relevance) and no observed cost. Reframe the four doc
   references from "run this" to "read this"; soften "executable spec" → "declarative spec" in
   `ARCHITECTURE.md` since nothing executes it anymore; fix the stale "(when added)" parenthetical in
   `playbook.md:157`. Invariant #7 applies (B-54): root `CHANGELOG.md` plus a matching head in all three
   `src/stacks/*/files/CHANGELOG.md` must exist before `release.ps1` will stamp — it does not create
   them; write them in the consumer's voice for the shipped ones. Invariant #1 monorepo-sibling review
   applies to every stack-side edit.
3. **Do NOT build new Copilot-shape hook assertions.** Before writing any test, run the coverage audit
   this design already ran (`grep -rl Copilot dist/dotnet/tests/hooks/*.ps1` cross-referenced against
   every hook in `src/core/.claude/hooks/`) as a cheap first step of implementation, to catch drift since
   this document was written. If it confirms what all three passes found — every hook already has
   Copilot-shape coverage — record that confirmation in the BACKLOG closure and build nothing here. If
   it finds a genuine gap the audit missed, build only the specific missing assertion, following the
   existing `Guard.Tests.ps1` two-surface-loop pattern and `_HookHarness.ps1`'s `New-CopilotEvent`/
   `Get-Decision` helpers — do not build a parallel conformance layer.
4. **Run spike S1, rescoped as a zero-credit schema re-verification, not a build gate.** ~10 minutes:
   confirm the `events.jsonl` shapes documented in §3 still hold on the currently-installed CLI (1.0.78,
   not 1.0.71). Back up and restore `~/.copilot/config.json` around the run (it is the live trust store,
   mutating it is real, not zero-risk, contrary to the original draft's framing). Record the result in
   `meta/canaries/b52-copilot-two-hook/README.md` (reuse the existing file; do not create a new one).
   This no longer unlocks or blocks anything else in this scope — it exists to keep the schema claims in
   this document from silently rotting, since Copilot has changed hook behavior across six observed
   versions.
5. **Close B-41.** Re-scope its DONE bar in `meta/BACKLOG.md` to "Claude behavioral evidence + Copilot
   hook-shape coverage (confirmed already shipping)"; record the cross-host behavioral evidence
   limitation in `docs/enforcement-surfaces.md` rather than leaving it implicit; hand that open question
   to B-43/B-49.
6. **RCA (Maintenance rule 5) — three questions, not the usual two, because of §4:**
   - Why did no gate catch that `no-dead-instruction` is blind to every non-shell interpreter? Sweep:
     what other `python`/`node`/`npm` instructions ship unguarded in shipped docs?
   - What else in this repo is measured only on the host we develop with, not the host we ship to? (The
     sweep question from the design's proportionality section — B-98 step 2's flagship `r=0/6→6/6,
     p≈0.002` result, measuring a Copilot-delivery carrier, entirely on Claude Code, is the first known
     instance; name it in the BACKLOG closure.)
   - Why did an adversarial review's own remediation contain a verification gap (§4)? Not to relitigate
     it, but because "check the aggregate runner file, not the leaf test files it invokes" is a specific,
     nameable trap that could recur in any future coverage audit of this test suite's structure.

## 3. What's independently confirmed true (do not re-litigate; do re-verify if implementation surfaces a contradiction)

- Copilot CLI 1.0.71 writes a typed `events.jsonl` event stream at
  `~/.copilot/session-state/<uuid>/events.jsonl`, richer than Claude's `stream-json` in one respect
  (`hook.start`/`hook.end` carry the hook's returned payload) and poorer in another (no observed `deny`
  shape). Confirmed directly against real session files by two independent passes, including one exact
  payload verbatim check.
- `~/.copilot/config.json`'s `trustedFolders` being empty is likely explained by Copilot pruning entries
  for deleted paths (the sessions that fired hooks ran in now-deleted scratchpad temp dirs), not by
  trust being unconfigurable — `meta/BACKLOG.md:254` already records folder-trust working in `-p` mode.
  Hook-firing evidence (`hook.start`/`hook.end` with a full payload) is confirmed to flush before a
  quota-exceeded (`402`) shutdown, so the trust question is answerable at zero credits.
- Two real sessions resolved Copilot's `auto` mode to different vendor models
  (`claude-haiku-4.5` / `gpt-5-mini`) non-deterministically — confirmed by directly reading both
  sessions' `session.auto_mode_resolved` events.
- `no-dead-instruction`'s check-7 regex does not match `python <x>.py` invocations — confirmed by
  running the actual regex from `scripts/validate-dist.ps1` against the actual shipped doc strings.

## 4. The correction the third pass made to the second pass (record this; do not let it get lost)

The adversarial reviewer's locked-scope recommendation included building "the missing `additionalContext`
assertions" for `route-prompt`/`session-start` as the one piece of new work worth keeping, based on
`grep -c additionalContext dist/dotnet/tests/hooks/Invoke-HookTests.ps1` returning 0. That grep checked
the **aggregate runner file**, which dot-sources/invokes the individual test files rather than containing
their assertion strings itself. Direct verification against the leaf files it invokes
(`RoutePrompt.Tests.ps1:27-31`, `SessionStartFrameworkRules.Tests.ps1:21`,
`SessionStartHazard.Tests.ps1:26`, `SessionStartWiki.Tests.ps1:11-22`, `TwinParity.Tests.ps1:130-153`)
shows the Copilot-shape `additionalContext` assertions already exist for both hooks the reviewer thought
were uncovered. A follow-up systematic check (every hook in `src/core/.claude/hooks/` cross-referenced
against `grep -rl Copilot dist/dotnet/tests/hooks/*.ps1`) found all four shipped hooks already have some
Copilot-shape coverage. This is why §2 step 3 is an audit-first, build-only-if-a-real-gap-survives
instruction rather than a concrete assertion to write.

## Verification (name the command, show the result; red observed before green)

1. Plant the `no-dead-instruction` defect class (a doc referencing `python <x>.py` that doesn't exist),
   observe non-zero exit on the unfixed check, then the clean pass after the grammar fix.
2. `pwsh -NoProfile -File scripts/build.ps1 <dist>` ×3, then `git status --porcelain dist/` empty.
3. `pwsh -NoProfile -File scripts/validate-dist.ps1 <dist>` ×3 — the B-23 red test: a tree with the
   runner deleted but a shipped doc still saying "run python run_evals.py" must fail `no-dead-instruction`
   non-zero; green after the real doc edits land.
4. `.claude/hooks/tests/Invoke-HookTests.ps1` (meta suite) — `DocTruth` catches any dead authoring-doc
   path left by the B-23 removal.
5. `pwsh -NoProfile -File dist/<d>/tests/hooks/Invoke-HookTests.ps1` ×3 — confirm the coverage audit's
   claim (all hooks already Copilot-tested) still holds against the dist copy, not just src.
6. If step 3 of §2 finds a real gap and something gets built: red-test it the same way — plant the
   missing-assertion condition, observe red, fix, observe green — under both pwsh and Windows PowerShell
   5.1.
7. S1's schema re-verification, recorded in `meta/canaries/b52-copilot-two-hook/README.md` regardless of
   outcome.
