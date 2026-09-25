# Framework backlog

Open work only, at most 40 entries (`AGENTS.md`, "Records"). Take the first unblocked row of the
pick-up order, one item per fresh session; the tier is read off the changed paths at work time. An
entry is its heading, filed-against line, priority line and at most three lines of status; the
evidence lives in the plans and decisions it names.
Full pre-reset text: `git show 36babcaf:meta/BACKLOG.md`.

## Pick-up order — ranked 2026-09-18 (WSD-090, WSD-091); WP rows added 2026-09-19 (WSD-093); B-276 and B-257 closed 2026-09-25

| Rank | Item | Why here |
|---|---|---|
| 17 | B-258 distribution re-audit | One-to-two-day spike; decides the shape of B-259 |
| 18 | B-259 installer lifecycle basics | After B-258 so nothing is built twice |
| 19 | B-261 Stop-time verification | B-248 bounded post-write at 45 s; settle Stop-hook latency against that |
| 20 | B-284 incremental `/rebootstrap` | User-requested 2026-09-23; the discovery-pass half waits on WSD-097 |
| Held | B-222, B-223, B-224 | WSD-097 (user, 2026-09-21): held after B-253's first report; everything already shipped stays. A defect in shipped behaviour is still fixable as its own item |
| Held | B-216, B-226, B-232 | Shipped; what remains is live host observation or target-host acceptance that a session cannot authorize for itself |
| Blocked | B-42 independent FS2 pair | Needs a participant; B-262 lowers the barrier |
| Low | B-292, B-291, B-290, B-289, B-287, B-286, B-285, B-282, B-263, B-256, B-252, B-251, B-242, B-243, B-266, B-265, B-267, B-268, B-269, B-270, B-271, B-273, B-274 | Take when adjacent work opens the same files; B-252 and B-251 can ride any release batch; B-265 measures a workflow before shipping it |
| Deferred | B-49 drill redesign | Instrument invalid under WSD-062; no execution authority |

## Open entries

### B-232 · Repair adoption instruction delivery and archive-plan documentation
**Filed against:** v0.86.0 (2026-09-09).
**Priority / effort:** P2 / M.
**Status:** PARTIALLY DONE. Delivery A released in v0.86.1. Delivery B's read-only observation did
not pass an overconstrained frozen acceptance test; comprehension or execution failure is not
established. No candidate paragraph shipped; B remains deferred.

### B-222 · Discover repository knowledge broadly, not only recurring recipes
**Filed against:** v0.83.0 (2026-09-05)
**Priority:** P1 · **Effort:** L · **Invariants:** #1 #2 #3 #6 #7
**Status:** PARTIALLY DONE; held by WSD-097. Shipped in v0.84.0; synthetic observations exercised
quiet facts, 40-file exhaustion and capture routing but retained source-grounding and report-fidelity
misses. Representative enterprise and target-host behaviour remain unobserved.

### B-223 · Capture and refresh grounded knowledge in existing project-owned artifacts
**Filed against:** v0.83.0 (2026-09-05)
**Priority:** P1 · **Effort:** L · **Invariants:** #1 #2 #3 #6 #7
**Status:** PARTIALLY DONE; held by WSD-097. Shipped in v0.84.0; the skill-path write route is
proven, but factual capture retained grounding misses and refresh refused an owner-approved
application. Broad recall and target-host efficacy are not established.

### B-224 · Make ordinary Copilot tasks consult relevant project knowledge
**Filed against:** v0.83.0 (2026-09-05)
**Priority:** P1 · **Effort:** M · **Invariants:** #1 #2 #5 #6 #7
**Status:** PARTIALLY DONE; held by WSD-097. Shipped in v0.84.0; one ordinary CLI run read scoped
knowledge and passed hidden grading, but its fixture failed the shipped validity check. A conforming
fixture, VS Code, enterprise scale and outcome comparison remain unobserved.

### B-216 · Project-adapt instance-shaped skills instead of imposing framework defaults
**Filed against:** v0.81.0 (2026-09-03)
**Priority:** P1 · **Effort:** L · **Invariants:** #1 #2 #3 #6 #7
**Status:** PARTIALLY DONE under the WSD-074 re-lock. Shipped in v0.84.0; source, lifecycle
preservation and one Unity composition-root observation are accepted. Alternative .NET/Angular,
conflicting or unreadable sidecar, and target-host semantic behaviour remain unobserved.

### B-226 · Give every review participant the same explicit change scope
**Filed against:** v0.83.0 (2026-09-05)
**Priority:** P1 · **Effort:** M · **Invariants:** #1 #3 #5 #6 #7
**Status:** PARTIALLY DONE under the accepted bounded contract. Snapshot and scanner mechanics and
all 39 carrier changes shipped in v0.84.0. Actual model Task or sequential dispatch and
installed-host end-to-end behaviour remain unobserved.

### B-42 · Obtain balanced independent field outcomes using FS2
**Filed against:** v0.31.0 (2026-07-17)
**Priority:** P1 when a participant exists · **Effort:** M setup plus diary time · **Invariants:** #6
**Status:** PARTIALLY DONE. Production use and maintainer replay exist; the missing outcome is a
balanced non-author FS2 Module A pair and associated independent friction evidence.

### B-49 · Re-design the live-fire drill and consumer self-assessment when justified
**Filed against:** v0.31.0 (2026-07-17)
**Priority:** P3 · **Effort:** M redesign, execution separately authorized · **Invariants:** #3 #5 #6
**Status:** DEFERRED; instrument INVALID under WSD-062. The value outcome remains open. No automatic
quarterly execution or general host recertification is required by this entry.

### B-242 · Amend release.ps1 refusal text and the ledger preamble for disclosed non-review cells
**Filed against:** v0.86.7 (2026-09-16)
**Priority:** P3 · **Effort:** S · **Invariants:** #6
**Status:** Open. `release.ps1`'s refusal text and the ledger preamble describe evidence only as "the
reviewer's", and still ask for an orthogonal reviewer for high-risk changes; the stub
`-NoIndependentReview` writes asks for one too. Text-only strings; no gate change.

### B-243 · Refuse a claimed change class that a changed path exceeds
**Filed against:** v0.86.7 (2026-09-16)
**Priority:** P3 · **Effort:** M · **Invariants:** #6
**Status:** Open. The outgoing-commit guard already inspects every outgoing blob and could refuse a
commit subject whose tier is lower than its paths require. File-level policy only.

### B-268 · Maintainer skills still instruct obligations WSD-092 dropped
**Filed against:** v0.86.7 (2026-09-18)
**Priority:** P3 · **Effort:** S · **Invariants:** —
**Status:** Open. The lean reset (WSD-093) deletes `meta-release` and `meta-review-handoff` and
rewrites `meta-gates` to the two tiers; confirm no stale obligation remains, then archive.

### B-269 · assert-red-first.ps1: a parameter-binding failure exits in the WRONG domain
**Filed against:** v0.86.7 (2026-09-18)
**Priority:** P3 · **Effort:** S · **Invariants:** —
**Status:** Open; observed 2026-09-18. With `-File` and a repeated `-Case`, binding fails and exits 1
without a `RED_FIRST` line, the same code as WRONG. Decide whether to accept repeated `-Case`.


### B-251 · Retire `scripts/fidelity-check.ps1` and `FidelityCheck.Tests.ps1`
**Filed against:** v0.86.7 (2026-09-18)
**Priority:** P3 · **Effort:** S · **Invariants:** —
**Status:** Open. A manual re-audit tool for the finished two-repo migration, out of CI since
v0.26.0, still carried and tested.

### B-252 · Stop copying the presentation deck into every consumer repository
**Filed against:** v0.86.7 (2026-09-18)
**Priority:** P3 · **Effort:** S · **Invariants:** #1 #7
**Status:** Open. Four files, about 97 KB, under `docs/presentation/` install into each consumer
tree; keep the FAQ content reachable and link the deck instead.

### B-256 · List the warehouse skills only where repository evidence selects them
**Filed against:** v0.86.7 (2026-09-18)
**Priority:** P3 · **Effort:** M · **Invariants:** #1
**Status:** Open, narrowed 2026-09-24. `/bootstrap` Phase 3a already advertises both only when the
warehouse-SQL profile was selected (`bootstrap.md:180`); the template lists them until bootstrap runs,
and whether `/adopt` applies the same gate is unverified. WSD-021 forbids only a separate distribution.

### B-258 · Distribution re-audit: Claude Code plugin prototype versus a simplified file-copy installer
**Filed against:** v0.86.7 (2026-09-18)
**Priority:** P2 · **Effort:** M · **Invariants:** #1 #6
**Status:** Open; investigation, outcome is a WSD re-auditing WSD-012/WSD-043. A one-to-two-day plugin
spike against a manifest-only copy/delete installer; a plugin cannot deliver project `CLAUDE.md`,
registers, `.github/` or permission rules.

### B-259 · Installer lifecycle basics: uninstall, `-WhatIf` parity, structured output, a real update check
**Filed against:** v0.86.7 (2026-09-18)
**Priority:** P2 · **Effort:** L · **Invariants:** #6 #7
**Status:** Open. No uninstall or rollback; `-WhatIf` skips the dirty-tree guard; conflicts surface
as unstructured text; the version stamp promises a future update command. Sequence after B-258.

### B-261 · Stop-time verification on Claude Code: run the evidenced build or tests before work is presented as complete
**Filed against:** v0.86.7 (2026-09-18)
**Priority:** P2 · **Effort:** M · **Invariants:** #5
**Status:** Open. The verification promise rests on the agent's self-report; the only Stop hook is
an advisory style scan. WSD-024 keeps the Copilot nudge advisory; post-write is bounded at 45 s (B-248).

### B-263 · State the Copilot VS Code surface as best-effort until a capability is certified
**Filed against:** v0.86.7 (2026-09-18)
**Priority:** P3 · **Effort:** S · **Invariants:** #5
**Status:** Open. Every Copilot VS Code row in `meta/host-certification.md` reads "not certified — no
seat" while shipped text says "supported".

### B-265 · Missing consumer workflows: PR description, read-only codebase explanation, major-version upgrade, Angular perf/accessibility
**Filed against:** v0.86.7 (2026-09-18)
**Priority:** P3 · **Effort:** M · **Invariants:** #1
**Status:** Open. Measure each new workflow on a scenario with `-TargetPatch` (B-253) before shipping it;
split into one item per workflow when taken.

### B-266 · Add a PSScriptAnalyzer leg for framework PowerShell
**Filed against:** v0.86.7 (2026-09-18)
**Priority:** P3 · **Effort:** S · **Invariants:** #3 #4
**Status:** Open. The only static check is the AST parse in `validate-dist`; a maintainer-side CI
lint adds no consumer dependency.

### B-267 · The optional eval-evidence commit lands on ambient HEAD
**Filed against:** v0.86.7 (2026-09-18)
**Priority:** P3 · **Effort:** S · **Invariants:** #6
**Status:** Open. After the tag, `release.ps1` commits eval results on whatever HEAD is and pushes
it, so a commit made during the watch would be published beneath it; it cannot move the tag.

### B-270 · release.ps1 -NoIndependentReview files its stub under an anchor that no longer exists
**Filed against:** v0.86.7 (2026-09-19)
**Priority:** P3 · **Effort:** S · **Invariants:** #7
**Status:** Open. The "Known deferred work" level-2 heading that `release.ps1:669` anchors on is
absent from this file, so the stub filing already degrades to a WARNING; the new rules use
`-ReviewEvidence` only.

### B-271 · A release resumed on a records-only HEAD stalls its CI watch
**Filed against:** v0.86.7 (2026-09-19)
**Priority:** P3 · **Effort:** S · **Invariants:** #6
**Status:** Open. With nothing to stage, `release.ps1` tags HEAD; a light HEAD (WP2) gets no CI run, so
the watch exits 3 and nothing is tagged. Fails closed; WP3 edits the same file.

### B-273 · `assert-red-first.ps1` cannot examine a red case in a driver-style suite
**Filed against:** v0.86.7 (2026-09-20)
**Priority:** P3 · **Effort:** S · **Invariants:** —
**Status:** Open; observed 2026-09-20 on `ValidateDist.Tests.ps1`. A failing case there prints two
`[FAIL] <name>` lines — the child's own summary and the driver's "child exited" line — so
`Resolve-Mark` finds two matches and exits CANNOT_EXAMINE for every red case in that suite.

### B-274 · `guard.ps1`'s block-shape comment misdescribes the empty-tool-name case
**Filed against:** v0.86.7 (2026-09-20)
**Priority:** P3 · **Effort:** S · **Invariants:** #5
**Status:** Open; observed 2026-09-20 by the fresh-session review of B-247, pre-existing and
unchanged by it. The header says an empty tool name emits the Claude signal, but `if (-not $tool)`
turns `''` into `$null`, so `tool_name: ""` alone takes the Copilot JSON path at exit 0.

### B-282 · Installed docs point at a README that is not installed
**Filed against:** v0.89.1 (2026-09-23)
**Priority:** P3 · **Effort:** S · **Invariants:** #1
**Status:** Open. Each stack's `docs/ARCHITECTURE.md` (lines 4, 12, ~178) sends readers to `README.md` "Quick Start" and
calls it the "human + AI-agent entrypoint", but `install.ps1` excludes `README.md`, so in a consumer repo it is theirs.

### B-284 · Make `/rebootstrap` incremental from a content-hash baseline
**Filed against:** v0.89.1 (2026-09-23)
**Priority:** P2 · **Effort:** L · **Invariants:** #1 #3 #7
**Status:** Open; user-requested for high-churn repos, token cost. Design after a fresh-session
adversarial review: `.claude/plans/2026-09-23-incremental-rebootstrap.md`. Scheduling was dropped
by the user; bounding the discovery pass needs WSD-097 lifted.

### B-285 · Retire the B-97 block-manifest tooling
**Filed against:** v0.90.0 (2026-09-24)
**Priority:** P3 · **Effort:** S · **Invariants:** none
**Status:** Open. `.claude/scripts/build-block-manifest.ps1` and `meta/block-manifest.json` have no caller; its
`-SelfTest` reads blocks from `dist/dotnet/CLAUDE.md`, which B-272 made a two-line stub. Delete both, or repoint.

### B-286 · The brownfield installer says originals were displaced when none were
**Filed against:** v0.90.0 (2026-09-25)
**Priority:** P3 · **Effort:** S · **Invariants:** —
**Status:** Open; observed by B-281's fresh-session attack. A repo whose only tooling is `.cursorrules` or, since B-281,
its own `.github/copilot-instructions.md` gets "The originals this install displaced are under docs/pre-adoption/"
although nothing was archived and the directory does not exist.

### B-287 · Hash-gated `.md` retirements never delete a CRLF checkout
**Filed against:** v0.90.0 (2026-09-25)
**Priority:** P3 · **Effort:** S · **Invariants:** #6
**Status:** Open; observed by B-281's fresh-session attack. Git for Windows ships `core.autocrlf=true`, so an update run
from a fresh clone sees CRLF bytes, matches no ledger digest (none are CRLF), and preserves and reports every retired
`.md` file instead of deleting it. Fails safe; the retirement is just never applied there.

### B-289 · `release.ps1` still says the release runs the full root meta suite
**Filed against:** v0.90.0 (2026-09-25)
**Priority:** P3 · **Effort:** S · **Invariants:** —
**Status:** Open; found by B-264's review, widened by B-288's. The header (`:12-13`), the stage comment (`:528-537`) and
the release commit message (`:825`, `:827`) name the "full root meta suite"; since B-245 the stage runs four files locally
(`:606`), so the v0.87.0–v0.89.2 release commits each carry a false claim. Text-only, on a guarded path.

### B-290 · Re-scope or delete the SATURATED `angular-form-control` eval scenario
**Filed against:** v0.90.0 (2026-09-25)
**Priority:** P3 · **Effort:** S · **Invariants:** —
**Status:** Open; named by the 2026-09-18 review under B-264, carried here when B-264 closed; B-253 closed without it.
`scenarios.json:56` calls its own pass uninformative; `run-agent-evals.ps1` self-test fixtures (`:1443`, `:2556-2621`) use it.

### B-291 · Spike: let the host's PowerShell run hooks and drop the named inner interpreter
**Filed against:** v0.90.0 (2026-09-25)
**Priority:** P3 · **Effort:** S spike, M change · **Invariants:** #3 #5
**Status:** Open; from B-276's review. In-process guard kept exit 2/0 and saved ~0.2-0.3 s per hook; the prize is deleting the
5.1 variant and installer copy. First observe live that Claude Code's outer shell falls back to 5.1 without `pwsh` and passes
`-ExecutionPolicy Bypass` (read only from binary strings); if not, stop. Copilot's `hooks.json` still names `pwsh`.

### B-292 · Stop the `route-prompt` rails drifting from the canonical workflow bullets
**Filed against:** v0.90.0 (2026-09-25)
**Priority:** P3 · **Effort:** S · **Invariants:** #1
**Status:** Open; from WSD-100. The test and feature rails lost two §1 non-negotiables at v0.77.0 unnoticed; only the
consumer-run `/docs-sync` step 2 compares them. Options: compose the rails from the §1 snippets in `build.ps1`, a
`validate-dist` check per rail for named non-negotiables, or a pointer-only hook (changes salience, so measure it).

## Archived

B-219 and B-221 — see `meta/BACKLOG-DONE.md`.
B-225 and B-254 — see `meta/BACKLOG-DONE.md`.
