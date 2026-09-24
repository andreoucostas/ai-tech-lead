# Framework backlog

Open work only, at most 40 entries (`AGENTS.md`, "Records"). Take the first unblocked row of the
pick-up order, one item per fresh session; the tier is read off the changed paths at work time. An
entry is its heading, filed-against line, priority line and at most three lines of status; the
evidence lives in the plans and decisions it names.
Full pre-reset text: `git show 36babcaf:meta/BACKLOG.md`.

## Pick-up order — ranked 2026-09-18 (WSD-090, WSD-091); WP rows added 2026-09-19 (WSD-093)

| Rank | Item | Why here |
|---|---|---|
| 12b | B-279 `map-warehouse` skill surface | README half shipped with B-262; the listing half rides B-256, the invocation flag B-257 |
| 13 | B-255 instruction-text de-duplication | Largest always-loaded saving; measure with `-TargetPatch` (B-253) |
| 13a | B-272 `AGENTS.md` as the one instruction file | Same always-loaded text as B-255; removes the mirror and its drift gate. Rank provisional, set by the filing session |
| 13b | B-281 retire `.github/copilot-instructions.md` | Third copy of the same rules now that every host reads `AGENTS.md`; do it with or after B-272 |
| 15 | B-264 process diet | WP5 of the lean reset plan (section 7); WSD-093 replaces WSD-089's success measure |
| 16 | B-257 commands as skills, routing, scoped rules | Host facts must be verified first; WSD-045 must be answered |
| 17 | B-258 distribution re-audit | One-to-two-day spike; decides the shape of B-259 |
| 18 | B-259 installer lifecycle basics | After B-258 so nothing is built twice |
| 19 | B-261 Stop-time verification | B-248 bounded post-write at 45 s; settle Stop-hook latency against that |
| 20 | B-284 incremental `/rebootstrap` | User-requested 2026-09-23; the discovery-pass half waits on WSD-097 |
| Held | B-222, B-223, B-224 | WSD-097 (user, 2026-09-21): held after B-253's first report; everything already shipped stays. A defect in shipped behaviour is still fixable as its own item |
| Held | B-216, B-226, B-232 | Shipped; what remains is live host observation or target-host acceptance that a session cannot authorize for itself |
| Blocked | B-42 independent FS2 pair | Needs a participant; B-262 lowers the barrier |
| Low | B-282, B-263, B-256, B-252, B-251, B-242, B-243, B-266, B-265, B-267, B-268, B-269, B-270, B-271, B-273, B-274 | Take when adjacent work opens the same files; B-252 and B-251 can ride any release batch; B-265 measures a workflow before shipping it |
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

### B-276 · A missing hook interpreter is now silent on Claude Code
**Filed against:** v0.88.0 (2026-09-21)
**Priority:** P2 · **Effort:** S · **Invariants:** #5
**Status:** Open; measured by B-275's fresh-session review. With `pwsh` off `PATH` the registered guard
command exited 1 (a visible hook error) before B-275's suffix and exits 0 after it. A branch in the
command string stalls every write under a bash carrier; detect in the doctor or installer instead.

### B-279 · Developer-triggered generators are listed and graded as task-time recipes
**Filed against:** v0.89.1 (2026-09-21)
**Priority:** P2 · **Effort:** M · **Invariants:** #1 #2
**Status:** Narrowed 2026-09-23. `map-warehouse` is dual-mode: a request-only generator of `docs/warehouse-map.md` and a
mid-task answerer (`SKILL.md` USE FOR; `add-warehouse-load` calls it); B-280 measured the doc (opened 0/6), not the skill.
The READMEs show it as a conditional developer step (B-262). Left: Common Tasks/defaults/ARCHITECTURE listing with B-256,
`disable-model-invocation` with B-257; no WSD until one of those settles it.

### B-255 · De-duplicate the shipped instruction text and remove maintainer-epistemic disclaimers
**Filed against:** v0.86.7 (2026-09-18)
**Priority:** P2 · **Effort:** M · **Invariants:** #1 #2
**Status:** Open. The frozen-bundle paragraph appears 15 times across eight files, several hedges four to five times, the
rails in three places. Measure the candidate with `-TargetPatch` (B-253) against the unpatched arm, non-inferiority fixed in
advance, on a scenario that opens the changed text. Copilot CLI loads all three instruction files (~111K chars, B-278).

### B-256 · List the warehouse skills only where repository evidence selects them
**Filed against:** v0.86.7 (2026-09-18)
**Priority:** P3 · **Effort:** M · **Invariants:** #1
**Status:** Open. `map-warehouse` and `add-warehouse-load` appear in every .NET consumer's Common
Tasks; WSD-021 forbids a separate warehouse distribution, not an evidence-selected listing.

### B-257 · Investigate workflow commands as skills, retiring regex prompt routing, and path-scoped rules
**Filed against:** v0.86.7 (2026-09-18)
**Priority:** P2 · **Effort:** M · **Invariants:** #2 #5
**Status:** Open; investigation, outcome is a WSD. `route-prompt.ps1` spawns on every prompt, carries a third copy of the
rails, and under `claude -p` fires and is read (B-253 probe, 3/3, 2026-09-24). Removing it needs a non-inferiority test, not
n=12 superiority. Weigh skills and `.claude/rules/` against Copilot parity, WSD-031/WSD-032 and WSD-045.

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

### B-264 · Process diet: release batching, one-in-one-out for meta tests, backlog narrative trim
**Filed against:** v0.86.7 (2026-09-18)
**Priority:** P2 · **Effort:** M · **Invariants:** #7
**Status:** Open; WP5 of `.claude/plans/2026-09-19-lean-maintainer-reset.md`. About a third of the
meta suite tests process or records; candidates include `GateBudgetConsistency.Tests.ps1`.

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

### B-272 · Make `AGENTS.md` the one instruction file, shipped and in this repo
**Filed against:** v0.86.7 (2026-09-19)
**Priority:** P2 · **Effort:** L · **Invariants:** #2 (rewrites it) #1 #6 #7
**Status:** Open; user-requested. Claude Code v2.1.277+ reads `AGENTS.md` only when no `CLAUDE.md` or
`CLAUDE.local.md` exists; not on Bedrock, telemetry-off or `allowManagedHooksOnly` sessions. Decide
no file versus a one-line `@AGENTS.md` stub, plus the upgrade path for populated consumer `CLAUDE.md`.

### B-281 · Retire the generated `.github/copilot-instructions.md`
**Filed against:** v0.89.1 (2026-09-22)
**Priority:** P2 · **Effort:** M · **Invariants:** #1 #2 #7
**Status:** Open; user-requested 2026-09-22 — every host reads `AGENTS.md` now, so the terse generated
ruleset is a third copy. Removal also retires `/generate-copilot` and its prompt, the canary, the
`docs-sync-check`/`template-checks` legs and the manifest entry; confirm VS Code inline completion first.

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

## Archived

B-219 and B-221 — see `meta/BACKLOG-DONE.md`.
B-225 and B-254 — see `meta/BACKLOG-DONE.md`.
