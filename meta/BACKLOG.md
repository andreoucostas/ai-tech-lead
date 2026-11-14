# Framework backlog

Open work only, with no cap on entries (`AGENTS.md`, "Records"; WSD-124). Take unblocked rows of the
pick-up order from the top; a session may take several; the tier is read off the changed paths at
work time. A self-found or attack finding inside AGENTS.md's four guarded harms stays here only with a
trigger ordinary use executes; one that could leak a secret always stays (WSD-124). An
entry is its heading, filed-against line, priority line and at most three lines of status; the
evidence lives in the plans and decisions it names. An empty backlog says "No open entries." on its
own line under Open entries; the hygiene tests refuse that line beside an entry. A session that
finds an adjacent defect outside AGENTS.md's four guarded harms, which no field report raised,
closes it per WSD-106 with one CLOSED line in `meta/BACKLOG-DONE.md` instead of filing it here.
Full pre-reset text: `git show 36babcaf:meta/BACKLOG.md`.

## Pick-up order — re-ranked 2026-11-14 (maintainer, in chat; WSD-124): the architecture review filed as B-506 to B-513, then B-514 to B-520, with the project-skills work at ranks 8, 9, 11 and 12 after B-506, B-509, B-507 and B-498, and seven findings shut; earlier ranking history is in `git log -p meta/BACKLOG.md`

| Rank | Item | Why here |
|---|---|---|
| 1 | B-506 | Before 0.98.7 ships: its fail-closed guard stops a teammate without `pwsh`, and the documented remedy edits the shared settings file and is reverted by the next update; guarded |
| 2 | B-416 | P1: the only route to whether 0.98.0's restated criteria and Option A/B designs are right and used, and it gates B-417 to B-419's shipping changes; needs the maintainer and the first consumer team |
| 3 | B-475 | P1 until a Chat-view check: on VS Code 1.144.1 no repository hook ran in a trusted folder (0 of 7); on 1.146.0 they ran 3 of 3 (2026-11-13), so what is left is that check and a guarded fix to the docs and doctor row that say they do not |
| 4 | B-466 | Maintainer request: the first test of whether the framework's lead over the bare agent grows with repository size, the case for large legacy codebases; pre-registered, its 60 USD stop approved by the maintainer 2026-11-11; runner work and three generations before any run |
| 5 | B-509 | Data-loss class, run: the only test of the installer's retired-path reparse branch is skipped on every Windows host; S |
| 6 | B-507 | Data-loss class, run: every update drops a team's own `env` variables and hook entries (recoverable from HEAD); guarded |
| 7 | B-498 | Raised 2026-11-14: a false green (the doctor passes with `disableAllHooks` set), one of the four guarded harms; red-first |
| 8 | B-514 | Maintainer priority: nothing yet shows an auto-created skill being used (0 of 4 follow-ups called one); the measurement the rest of the skills work hangs on; needs the maintainer's spend stop |
| 9 | B-515 | Maintainer priority: 3 of 6 measured drafts missed a step their own instances contain; guarded |
| 10 | B-510 | CI is at 88% of the watcher's 2,400 s and growing; past it every push and release reads CANT-VERIFY; guarded |
| 11 | B-516 | Maintainer priority: approval is two manual edits and a draft is live before review; after B-514; guarded |
| 12 | B-356 | Project-skills work: how skills keep appearing after `/bootstrap`; its bullet shipped unmeasured (WSD-111), so the decoy's false-offer rate decides whether it stays |
| 13 | B-469 | Maintainer request: an update's `.claude/framework-update-backup/` copies get forgotten and committed; `-Reinstall` already relies on the last commit instead; guarded |
| 14 | B-491 | Audit, reproduced: `route-prompt` routes "yes, go ahead" and plain questions as a feature with the plan gate, and "concurrency" gets the security overlay; guarded |
| 15 | B-493 | Audit, read: `dependency-audit` forbids inferring the read-only scan commands, so it reports every scan as not available; guarded, text-only |
| 16 | B-425 | A plain-words review runs no reviewer: on Copilot CLI it loads the `review` skill (5 of 6, 2026-11-13) but skips its dispatch step (0 of 6), with or without the candidate; blocked on B-416; the Claude Code leg is about 3 USD |
| 17 | B-497 | Audit, read: `/review` has no merge, de-duplication or verdict step, and two reviewers give opposite advice on delegation; ordinary |
| 18 | B-467 | Measured 2026-11-04: omitClaudeMd cuts each reviewer's first request by about 9,200 tokens; the findings comparison was not settled under the eval harness, so a re-run decides shipping |
| 19 | B-513 | Needs the maintainer: the 2026-11-14 decision audit's contradiction, unread decisions and stale premises |
| 20 | B-508 | Where the recent data-loss defects sit has no unit tests; guarded, step 4 |
| 21 | B-511 | Deletions: release tooling that never fires or only raises its ceiling, and closed eval studies; guarded |
| 22 | B-512 | Three hand-edited copies kept by a stale ~6-marker cap; guarded (AGENTS.md) |
| 23 | B-417 | Improvement to 0.98.0's core: B-412 saw no downstream difference because prompt K states every outcome; about 10 USD |
| 24 | B-420 | The fix path's restated criterion, unchanged since 0.97; about 8 USD; better after B-416's field answers |
| 25 | B-419 | Improvement with no field report; starts with a hand-read of the retained security passes |
| 26 | B-468 | Measured, not field-raised: 2 of 26 plain bug fixes skipped the regression test, wrongly saying a SQLite test needs a new package; the agent said the fix was untested |
| 27 | B-451 | Field report, narrowed: the compact baseline shipped; review-tool markers for it wait on the reporter saying what their host honours; guarded |
| 28 | B-478 | Write-guard leftovers of the 2026-11-04 step-4 attacks: `password` spelt with the long s passes, and a path-less `NotebookEdit` falls through (the host's schema requires the path); kept as secret-leak class (WSD-124); guarded, step 4 |
| 29 | B-484 | Secret-leak class, adjacent to field report #13: a committed credential's hazard row commits its `path:line`, which `/security-gate` forbids; guarded, text-only |
| 30 | B-499 | Secret-leak class, B-487's step-4 attacks: the guard still passes an auto-property initializer, `NetworkCredential`, URL userinfo and other credential forms; guarded, step 4 |
| 31 | B-496 | Audit, a sub-session's run: the removal checklist leaves `.claude/settings.json` registering deleted hooks; ordinary |
| 32 | B-489 | Audit, reproduced: the guard blocks UI labels, vault references and documentation samples with no waiver; needs the maintainer's decision (a WSD) first |
| 33 | B-490 | Audit, reproduced: the agent can rewrite the hook registrations (the missing-`pwsh` exit 0 is fixed for 0.98.7); needs the maintainer's decision first |
| 34 | B-502 | Data-loss class, pre-existing, B-480's scope check (run): a disabled skill's exemplar line survives the update that disables it and is dropped by the next one; guarded, step 4 |
| 35 | B-504 | Vendor-guidance audit, read: the reviewers are read-only in prose only (a shell on Claude Code, every tool on Copilot); needs the maintainer's decision first |
| 36 | B-517 | Maintainer priority, proposed: a Git-history pass to find repeated operations in large repositories; after B-514 and B-515 |
| 37 | B-518 | Consumers have a stated floor for Claude Code only, and no statement of what 1.0 promises; ordinary |
| 38 | B-519 | The always-loaded rules file, cut only where a measurement can go red; every cut measured |
| 39 | B-520 | Six small leftovers of the 2026-11-14 reviews, each narrowed by its attack |
| 40 | B-483 | False-green class, run by a fresh-session review: the warehouse map check reports `current` for deleted tables; was missing from this table |

## Open entries

### B-356 · Measure a plan-step offer of a test, Conventions line or project-skill draft when a feature creates a repeatable operation
**Filed against:** v0.93.0 (2026-10-05)
**Priority:** P3 · **Effort:** M to measure, S to change · **Invariants:** #1 #7
**Status:** Open; raised by the maintainer 2026-10-05, no field report (WSD-109). The candidate bullet shipped unmeasured in carrier §2 (WSD-111).
Measure it (B-346 method): an extension-point feature, a third instance and a plain CRUD decoy whose false-offer rate decides whether it stays;
design: `.claude/plans/2026-10-08-b348-b356-plan-v2.md` Part B. Its Copilot stage: `.claude/plans/2026-11-13-copilot-window-briefs.md`, "B-356". Part of the project-skills work (WSD-124) with B-514 to B-517: this is how skills keep appearing after `/bootstrap`.

B-225 and B-254 — see `meta/BACKLOG-DONE.md`.

### B-416 · Observe 0.98.0 at the first consumer: do the restated criteria and Option A/B designs help, and are they right
**Filed against:** v0.98.0 (2026-10-19)
**Priority:** P1 · **Effort:** S · **Invariants:** none
**Status:** Open (maintainer, 2026-10-19). Give the first consumer team a six-question observation card (plan opened with `Done when:`; did you correct a line; Option A/B on a risky change and was it real; did the PR carry the lines; did tests run; did a review run: `/review` typed or asked for by name, started by the agent, or none, and did its output name reviewers or "Contract lines pinned"; host and model) and record answers as field reports.
The only route to whether the lines are correct and used; gates any reviewer-side or auto-review change. On close, decide plan v2 §5 item 5 (the auto-review sentence) and B-425 from the review answer. Review: `.claude/plans/inbox/2026-10-19-open-threads-review.md` T5.

### B-417 · Measure tests derived from the restated criteria on a prompt that hides a boundary
**Filed against:** v0.98.0 (2026-10-19)
**Priority:** P2 · **Effort:** M · **Invariants:** #7 if it ships
**Status:** Open; measured 2026-10-20 as NOT EXERCISED (pre-registered at e91d132c, `meta/eval-results.md`; 4.23 USD). On `done-when-h` ("open" orders, defined only by `rpt.vwOpenOrders`: Placed or Picking) Picking reached a Done-when line in 1 of 6 T and 1 of 6 C runs, and both then waited for a "go" after "go with your defaults".
The other 10 assumed "open" from the code's two states, so no test had a Picking case (PINNED 0/6 each) while every written suite killed the customer-scope mutant (8 of 8). Part B's `:74` text stays unshipped.
Next, the maintainer's choice: a boundary the agent meets in the code it reads, with a leg 2 that says go; `done-when-h`, the patch and the 0.98.1 fixture are reusable.

### B-419 · Review depth scales with blast radius (plan v2 Phase 3, never run)
**Filed against:** v0.98.0 (2026-10-19)
**Priority:** P3 · **Effort:** M · **Invariants:** none
**Status:** Open (maintainer, 2026-10-19). `review-scope.ps1`'s manifest gains the hazard rows whose paths intersect the captured paths (reuse `hazard-check.ps1`'s parsing by AST), and `review.md` hands them to the auditors. First a hand-read: did any retained security pass read the hazard rows. Plan `.claude/plans/2026-10-17-delivery-architecture.md` §5 item 3. Review T3.

### B-420 · Measure the fix path's restated criterion and regression test on a planted defect (plan v2 Phase 4)
**Filed against:** v0.98.0 (2026-10-19)
**Priority:** P3 · **Effort:** M · **Invariants:** none
**Status:** Open (maintainer, 2026-10-19). Plant one defect in a copy of `b409-orders-ci`, pre-register S3 (the fix opens with a Done-when line; the regression test pins the boundary and fails first), T vs C. `$railsFix` and `fix.md:21` are unchanged since 0.97. About 8 USD. Review T4.

### B-425 · Plain-words "review my changes" names no reviewer: a carrier Review bullet and `$railsReview` in `$railsSecurity`'s shape
**Filed against:** v0.98.1 (2026-10-19)
**Priority:** P2 · **Effort:** S to change, S to measure · **Invariants:** #5 #7
**Status:** Blocked on B-416's review answer (maintainer, 2026-10-19, on Fable's advice). Copilot leg measured 2026-11-13 on CLI 1.0.98 (`meta/eval-results.md`, pre-registered at 873bb161): "Review my changes." on a 12-line refund diff loaded the `review` skill 2 of 3 as installed and 3 of 3 with the candidate below, but no run started a reviewer (0 of 6), so the candidate is not shown to help there.
On Copilot CLI the gap is the skill's Step 1, not the routing: 5 of 6 said they read the small diff directly instead of dispatching, which `review.md` does not allow, and one gave its verdict without saying so; the candidate moved scope capture from 0 of 3 to 2 of 3.
Candidate as filed: a §1 Review bullet plus `$railsReview` in `$railsSecurity`'s shape (run this repository's `review` skill, by name on Copilot CLI; a verdict given without reviewers says so); guarded (`hooks/**`), `rail-sync` re-recorded. Left: the Claude Code leg (about 3 USD), and whether the next candidate targets Step 1.

### B-451 · The rebootstrap baseline has no review-tool markers, so a diff still shows its rows
**Filed against:** v0.98.2 (2026-10-21)
**Priority:** P3 · **Effort:** S · **Invariants:** #1 #7
**Status:** Narrowed 2026-10-31: schema 2 shipped (`file <path> <blob>` once per matched file, `evidence <id> <pattern>` per claim; 600 files x 36 claims 9,424 -> 766 lines, Impact output identical in 22 scenarios; a schema 1 baseline is read and rewritten). Open: shipped `.claude/.gitattributes`
lines (`bootstrap-baseline.tsv -diff linguist-generated=true`) so review tools collapse the file; guarded (a framework-owned file below `.claude/` goes through the installer's ownership policy, step 4, with a brownfield-archive case).
First ask the reporter what their Bitbucket host honours, and do it only if the compaction alone did not answer field report #10 item 2.

### B-466 · Measure whether the framework's lead over the bare agent grows with repository size
**Filed against:** v0.98.2 (2026-10-27)
**Priority:** P2 · **Effort:** M · **Invariants:** none
**Status:** Open (maintainer, 2026-10-27): tests the hypothesis that the framework earns its cost in large legacy codebases; every framework-against-bare comparison so far ran on a few to 499 files.
Pre-registered in `meta/eval-results.md` (B-466 pre-registration): `warehouse-route-p4` at about 14, 500 and 5,000 SQL files, framework against bare, n = 6, with the prediction written down.
Before any run, an amendment freezes the sized fixture and per-run cap in the runner, three generated overlays and checks I1 to I3; the maintainer approved the 60 USD stop in chat 2026-11-11.

### B-467 · Each `/review` reviewer sub-agent carries the main agent's whole instruction chain
**Filed against:** v0.98.2 (2026-10-27)
**Priority:** P3 · **Effort:** S · **Invariants:** #2
**Status:** Open (maintainer request; `meta/eval-results.md`, "Sub-agent context results", read FILE): Claude Code injects the consumer `CLAUDE.md`, `AGENTS.md` and the rules carrier, 25,805 chars, into all six reviewers.
Measured 2026-11-04 (pre-registered at d7da3b75, results in "B-467 results"): `omitClaudeMd: true` cut each reviewer's first request by about 9,200 tokens (R1 holds) and Copilot CLI 1.0.98 loads it; R2 (findings) not settled, one valid run per arm.
Left: re-run R2 with the eval harness's hook also covering cmdlet aliases (test-critic's `Select`), on the ready candidate (local branch `b467-candidate`, fb299354; no `review.md` change needed), then ship it guarded.

### B-468 · A plain bug fix can skip the regression test, wrongly saying a SQLite test needs a new package
**Filed against:** v0.98.2 (2026-10-27)
**Priority:** P3 · **Effort:** S · **Invariants:** none
**Status:** Open (maintainer request; `meta/eval-results.md`, "Test-level clause before/after"): 2 of 26 variant-B runs, one per arm, fixed an EF translation bug with no test and said SQLite needed
"a new package" and harness; the provider already reached the test project through its reference to the API, and 21 other runs used it without touching a `.csproj`. Suspected carrier: the Bug-fix
bullet's and fix rail's "add no foreign harness", read as forbidding an engine the code under test already uses. n = 2: measure (about 0.25 USD a run) before any wording change.

### B-469 · Retire `.claude/framework-update-backup/` in favour of "it is in your last commit"
**Filed against:** v0.98.2 (2026-10-28)
**Priority:** P3 · **Effort:** M · **Invariants:** #7
**Status:** Open (maintainer request, filed with `-Reinstall`, which writes no backup because it requires a clean Git tree). A plain update still saves copies under
`.claude/framework-update-backup/` (wrappers, unowned files, skills, the layout move) and `.claude/.state/settings.json.pre-update`; consumers forget and commit them.
Replace each save with the commit id and `git show`/`git checkout` lines, keeping a save only where the copied bytes are not in HEAD (ignored or skip-worktree files). A team's own `hooks` entry, which no update merges, outlives one update in the backup and then only in Git (B-486's step-4 attack).

### B-475 · VS Code 1.144.1: repository hooks never load in a folder VS Code trusts, so no framework hook runs in its Copilot harness
**Filed against:** v0.98.3 (2026-11-03)
**Priority:** P1 · **Effort:** M · **Invariants:** #5 #7
**Status:** Open, narrowed 2026-11-13 by B-348's VS Code runs (`meta/eval-results.md`, `meta/host-certification.md`): on VS Code 1.146.0 (69047191fc) with runtime 1.0.108-0, sessions the agent host granted folder trust ran the repository's hooks 3 of 3 and untrusted ones 7 of 7, where 1.144.1 ran none in 7 trusted
(the root cause then: deferral to `sessions.loadDeferredRepoHooks`, which the agent host still never references, so the change is presumably the runtime's). Script-created sessions in folder isolation only; microsoft/vscode#345931 is still open.
Left: one Chat-view session in a trusted folder on this version, then a guarded change to the docs and the doctor's `Copilot hook liveness` row (0.98.4), which say a trusted folder runs no repository hook. Then a hook-liveness canary run on each new host release: evidence-triggered, so WSD-066 stands (2026-11-14 decision audit: host-release reviews found B-395 and this item).

### B-478 · Write-guard leftovers of the 2026-11-04 step-4 attacks: the long s in `password`, and a path-less `NotebookEdit`
**Filed against:** v0.98.3 (2026-11-04)
**Priority:** P3 · **Effort:** S · **Invariants:** #3
**Status:** Open; pre-existing on b1f42438, executed by the attacks on B-472 and B-474. (a) `pa` U+017F U+017F `word = "…"` passes on pwsh and 5.1, like B-445's Kelvin-sign `k` on 5.1; no culture's casing writes either, so decide both together (a secret-leak finding needs a WSD, not WSD-106).
(b) A `NotebookEdit` with `notebook_path` absent, empty or null and a key in `new_source` exits 0 where a path-less `Write` blocks (`NotebookEdit` is not in `$knownWrite`); Claude Code's schema requires the path. Guarded, step 4.
Kept by the 2026-11-14 audit: the secret-leak class keeps WSD-106's exclusion from the ordinary-use test until the maintainer says otherwise (WSD-124).
### B-483 · `warehouse-map-check` reports `current` for a map whose tables were deleted, or that has no full-pass stamp
**Filed against:** v0.98.4 (2026-11-05)
**Priority:** P3 · **Effort:** M · **Invariants:** none
**Status:** Open; found by the fresh-session review of WSD-122's design and re-run (executed on scratch fixtures with the shipped check). It compares file write times only: deleting a mapped table's SQL leaves `WAREHOUSE_MAP current`, exit 0 (a rename too, in the review's run), and one row appended to a stale map with no full-pass line turned it `current` (exit 1 to 0), which the scoped pass can still do. `add-warehouse-load` step 1 prefers a `current` map; its "confirm the entities still exist" is the only backstop.
The same clock reads `stale` in a fresh clone of an unchanged commit (executed), so the answer depends on who cloned when.
Candidate: the check prints a digest of the warehouse artifacts' paths and contents, a full pass copies it into the stamp line, a map is current when the digests match and stale without one; red cases: the three runs above. e003c8c8 rejected parsing the Coverage line, and the review's runs showed git commit time wrong in both directions.
### B-484 · A committed credential's hazard row writes the secret's `path:line` into Git
**Filed against:** v0.98.4 (2026-11-06)
**Priority:** P3 · **Effort:** S · **Invariants:** none
**Status:** Open; found reading the hazard step for field report #13 (reasoned, not run). `/bootstrap` 3d-bis and `/rebootstrap` 3c put each hazard's `path:line` in its Hazard cell and require a resolving path in `Area / file(s)`, so a committed credential's row names where the secret sits, in a committed file; `/security-gate` forbids naming "concrete secret paths or lines" for a credential finding, and the hazard step never says to leave the value out.
Candidate: such a row names the area without the line and never the value, or the finding stays in chat and on the PR question only; `hazard-check` needs a resolving path, so decide which. Guarded (`src/stacks/*/files/.claude/**`), text-only.
### B-489 · The guard blocks UI labels, vault references and documentation samples, with no waiver
**Filed against:** v0.98.4 (2026-11-10)
**Priority:** P2 · **Effort:** S to change · **Invariants:** #3 #5 #7
**Status:** Open, waiting on the maintainer's decision; maintainer-requested external audit. Reproduced: an i18n JSON file whose `password` key holds the sentence *Enter your password* exits 2. A sub-session's runs: a label map, a Key Vault reference, a CSS class starting `sk-`, a Cypress login, a `docs/*.md` sample.
Option A requires a secret-shaped value (lets through a passphrase with spaces); Option B is a PR-reviewed allowlist. A relaxation in the secret-leak class needs a WSD. Guarded, step 4. Brief: `.claude/plans/2026-11-10-external-audit-briefs.md`.
Decided 2026-11-14 (maintainer, in chat: "go ahead with all of the findings this far"): Option B, a PR-reviewed path allowlist, its WSD written with the change. Same change: root `README.md` calls a required CI build with secret scanning "the gate" while `ci-integration.md` (the "Recommended alongside" section) says secret scanning is "not part of the required build"; make them agree.
### B-490 · The agent can rewrite the hook registrations, and the doctor passes a wired interpreter that is not on `PATH`
**Filed against:** v0.98.4 (2026-11-10)
**Priority:** P2 · **Effort:** S to M · **Invariants:** #3 #5
**Status:** Open, waiting on the maintainer's decision; maintainer-requested external audit. Part (a) is done for 0.98.7: the maintainer chose fail closed in chat on 2026-11-13, the guard command exits 2 when its interpreter is not found and its entry sets `"onFailure": "block"`. Reproduced: a write of `{ "hooks": {} }` to `.claude/settings.json` exits 0.
Left: decide how narrowly to protect the registrations without stopping `/adopt`, and make the doctor's `CANT-VERIFY` for an interpreter that is not on `PATH` a failing row. Guarded. Brief: `.claude/plans/2026-11-10-external-audit-briefs.md`.
### B-491 · `route-prompt` routes approvals and questions as new work, and matches sensitive terms inside other words
**Filed against:** v0.98.4 (2026-11-10)
**Priority:** P2 · **Effort:** S · **Invariants:** #3 #5 #7
**Status:** Open; maintainer-requested external audit (reproduced on the installed hook): "yes, go ahead and implement the plan" and "What does the build pipeline do?" return the feature rails with the plan gate, and "fix the concurrency bug in the cache" returns the security overlay (`currency` inside `concurrency`).
Candidate: no intent for an approval-shaped prompt, an imperative in a question counts only as the first word or after a request phrase, and `currency`, `token` and `balance` are word-bounded in the three stack snippets. Guarded (`hooks/**`). Brief: `.claude/plans/2026-11-10-external-audit-briefs.md`.
### B-493 · `dependency-audit` forbids inferring the scan commands, so on a typical repository it scans nothing
**Filed against:** v0.98.4 (2026-11-10)
**Priority:** P2 · **Effort:** S · **Invariants:** #1 #7
**Status:** Open; maintainer-requested external audit (read, behaviour predicted, not run). The skill says "do not infer a `dotnet` command, target, or flag" (Angular: `npm audit`, `npm outdated`), and Verification Commands has no dependency-scan category, so `/bootstrap` records none.
Candidate: once the skill's package-evidence gate passes, allow the read-only vulnerable, deprecated and outdated scans without a recorded row, as `ng update` already is. Guarded, text-only. Brief: `.claude/plans/2026-11-10-external-audit-briefs.md`.
### B-496 · "Remove the framework" leaves every agent session calling deleted hooks
**Filed against:** v0.98.4 (2026-11-10)
**Priority:** P3 · **Effort:** S · **Invariants:** #1 #7
**Status:** Open; maintainer-requested external audit (a sub-session's run, not re-run). Following the checklist by hand left `.claude/settings.json` registering six deleted hooks and `CLAUDE.md` importing the deleted rules file; its "restore your copy from `.claude/.state/settings.json.pre-update`" restores a file that registers `guard.ps1`.
Candidate: rewrite the section as numbered steps that end with no file naming `.claude/hooks/`; an installer `-Uninstall` is the larger candidate, guarded. Ordinary. Brief: `.claude/plans/2026-11-10-external-audit-briefs.md`.
Same file (2026-11-14 architecture review): `upgrade-checklist.md:111` says a non-zero exit is a refusal, which an exit 3 after writes began is not; document exits 2, 3 and 4 in one line.
### B-497 · `/review` hands back six reviewers' findings with no merge, de-duplication or verdict rule
**Filed against:** v0.98.4 (2026-11-10)
**Priority:** P3 · **Effort:** S to M · **Invariants:** #1 #7
**Status:** Open; maintainer-requested external audit (a sub-session's reading, noise predicted, not measured). `review.md` has no thresholds or de-duplication where `security-gate.md` has thresholds; `bloat-radar` flags a single-delegation method while `solid-check` flags a controller action that does more than delegate; commented-out code has two thresholds.
Candidate: a merge on `file:line`, one severity scale and one verdict line; drop the lines-per-file heuristic. Ordinary unless a stack file changes. Brief: `.claude/plans/2026-11-10-external-audit-briefs.md`.
Widened 2026-11-14 (architecture review, maintainer go-ahead): merge the three Haiku reviewers (convention-check, bloat-radar, debt-radar; B-427) into one pass, measured with B-467's 12-defect harness, and do the de-duplication there; align the commented-out-code threshold (`AGENTS.md` more than 1 line, `bloat-radar.md:34` more than 2).
### B-498 · `framework-doctor` reads every `command` in `.claude/settings.json` as a hook and ignores `disableAllHooks`
**Filed against:** v0.98.4 (2026-11-10)
**Priority:** P2 · **Effort:** S · **Invariants:** #1 #7
**Status:** Open; found by B-486's step-4 attack (a sub-session's runs, not re-run). The doctor walks every `command` property, not only those under `hooks`, so a team's `statusLine` with a `bash` command reads `[MISSING] Hook registration topology` and exits 1; with `"disableAllHooks": true` it still reports `8 ok / 0 missing`. A hand-added key already tripped it; since B-486 an update keeps the key, so it trips it on every run.
Candidate: read commands under `hooks` only; report `disableAllHooks: true` as `[MISSING]`. Ordinary by path; the false green is a guarded harm, so it takes a red-first case. Raised to P2 2026-11-14 (architecture review, maintainer go-ahead).
### B-499 · Credential forms the write guard still does not read after B-487
**Filed against:** v0.98.4 (2026-11-10)
**Priority:** P3 · **Effort:** M · **Invariants:** #3 #5 #7
**Status:** Open; B-487's step-4 attacks (a sub-session's runs, not re-run). Not read: an auto-property initializer `public string Password { get; set; } = "…"`, Redis `password=`, URL userinfo outside a connection-string key, a backtick string, a `Dictionary` initializer, `new NetworkCredential(…)`, `SetEnvironmentVariable`, `password?:`, a `"""` or `$"` literal, a `??` or `||` fallback, VB; and B-487's stated limits: `string.Join`, `;;`, a quote inside the literal, a JDBC neighbour, a `:` in a neighbouring key, the computed key `['password']:`, a no-break space or vertical tab, a one-pair literal standing alone, a variable between the pieces (`"Server=" + host + ";Password=…"`, the commonest real shape), VB `&`, `+=`, `string.Concat`, `AppendFormat`, `.Add(` or `.push(` pieces, an unkeyed password opening with `@`; and its false blocks on a mask, message or SQL text that is a piece of a longer string.
Candidate: decide per form whether the guard or CI secret scanning owns it; extending the guard is guarded, step 4, and each form needs its false-block survey (B-487 audited 145 repo and 476 npm files).
### B-502 · A disabled skill's exemplar line is dropped by the update after the one that disables it
**Filed against:** v0.98.5 (2026-11-11)
**Priority:** P3 · **Effort:** S · **Invariants:** #7
**Status:** Open; found by B-480's scope check (run on dist/dotnet: install, a "For a concrete current instance" line added to `add-warehouse-load`, the skill disabled in LEARNINGS.md; the first update kept the line in `.claude/disabled-skills/add-warehouse-load/SKILL.md`, the second, exit 0, replaced it without the line). The update reads exemplar lines only under `.claude/skills/`.
Candidate: read a disabled skill's line from `.claude/disabled-skills/<name>/SKILL.md` too; red case from that run. Guarded, step 4.
### B-504 · The reviewers are read-only in prose only: a shell on Claude Code, every tool on Copilot
**Filed against:** v0.98.6 (2026-11-13)
**Priority:** P2 · **Effort:** S for a tool list, M to drop the shell · **Invariants:** #2 #5 #7
**Status:** Open, waiting on the maintainer's decision; vendor-guidance audit and its adversarial review (read, not run). The seven `.claude/agents` files list `PowerShell`; the six `.github/agents` wrappers have no `tools:`, which Copilot reads as all tools; both vendors say a tool list is the boundary and an instruction is not.
Decide: drop the shell (`Read, Grep, Glob`; `["read", "search"]`), which moves the reviewers' hash recompute to the parent in six agents, six wrappers, `review.md` and `security-gate.md`, where `/security-gate` has no parent recompute today; or keep it, add `tools: ["read", "search", "execute"]` to the wrappers and stop saying read-only. Either needs a Copilot host check that a reviewer starts, reads its bundle and has no edit tool.
Also: VS Code documents that it does not forward `include-custom-instructions`, which four wrappers rely on; not measured.
### B-506 · 0.98.7's remedy for a machine without PowerShell 7 edits the shared settings file and is reverted by the next update
**Filed against:** v0.98.6 (2026-11-14)
**Priority:** P1 · **Effort:** S · **Invariants:** #3 #7
**Status:** Open; architecture review 2026-11-14 (a reviewer's run on a scratch install). Since 9e8dbb28 the Claude Code guard refuses every write without `pwsh`; `src/core/docs/enforcement-surfaces.md:21-22` says to copy `settings.windows.json` over the committed `settings.json`, which switches the whole team, and the next update run where `pwsh` exists writes the PowerShell 7 variant back (`$useFirst`, `install.ps1:2773`, no NOTICE). `settings.local.json` cannot help: hooks merge across settings files.
Candidate: an update keeps whichever shipped variant is committed (`$currentIsRelease`, `install.ps1:2769`, already recognises both), or the Claude command picks its interpreter at run time; fix `src/core/docs/getting-started.md:29`, which says 5.1 suffices. First the maintainer says whether 5.1 stays a Claude Code hook host (the review's largest deletion candidate; no consumer without `pwsh` is on record). Guarded, step 4; before 0.98.7 ships.
### B-507 · An update drops the team's own `env` variables and hook entries from `.claude/settings.json`
**Filed against:** v0.98.6 (2026-11-14)
**Priority:** P2 · **Effort:** M · **Invariants:** #7
**Status:** Open; architecture review 2026-11-14 (a reviewer's run: two `env` variables, a Bash `PreToolUse` and a `PostToolUse` hook added and committed; the update exited 0, carried `permissions`, dropped all four with one NOTICE per key). The release owns every top-level key it ships (`env`, `hooks`); the team's file survives in HEAD and the single `.claude/.state/` copy. `README.md` says the file holds the framework's registrations "next to your own settings".
Candidate: carry `env` per variable and hook entries per inner entry, recognising framework entries by the exact commands any release shipped (a list like `$script:SjEverShipped`, `install.ps1:2479`, which lists top-level keys), never by a `.claude/hooks/` path, where teams keep their own scripts; both settings variants. Guarded, step 4.
### B-508 · The installer's HEAD-comparison and ownership planning has no unit tests, and an edited framework-owned file is replaced unannounced
**Filed against:** v0.98.6 (2026-11-14)
**Priority:** P2 · **Effort:** M · **Invariants:** #7
**Status:** Open; architecture review and decision audit 2026-11-14. WSD-101 asks only that hashes gate retirement and a migration floor is named, not how the installer is structured; WSD-043's noise premise predates WSD-051's per-path digests. f759e572, 03f25b38 and two findings shut under WSD-124 (a letter-case mismatch, a staged archive version) all sit in the HEAD-comparison logic, reachable only through end-to-end runs.
Candidate: extract the pure planning functions with unit cases first; record installed digests at install time, keeping the ledger as the floor for older installs; a NOTICE naming each owned file whose bytes match no released digest, with the commit to recover it from (no backup copy, WSD-117). Also check whether the legacy pre-commit inspection (`install.ps1:936-1200`) and the file-named retired-path messages still serve a reachable install. Guarded, step 4.
### B-509 · The retired-path reparse case never runs: its probe expects `Test-Path` to call a dangling link absent
**Filed against:** v0.98.6 (2026-11-14)
**Priority:** P2 · **Effort:** S · **Invariants:** #3
**Status:** Open; maintainer-code review 2026-11-14 (run: a dangling junction gives `Test-Path` True on pwsh 7 and 5.1; CI run 43602216106 skips the case on both hosts with "host cannot construct an unprivileged dangling file symlink"). The probe (`UpdateDelivery.Tests.ps1:4114-4123`) needs `Test-Path` False, which Windows does not give, so privilege is not the blocker; the case at `:4129` is the only assertion of `install.ps1:567`'s retired-path CANT-VERIFY, a data-loss branch.
Candidate: build the dangling reparse with an unprivileged junction and drop the `Test-Path` clause; seen red by breaking the branch in a scratch copy. Ordinary.
### B-510 · CI takes about 32 minutes a push, 88% of the watcher's 2,400 s, and its timing lines break their own format
**Filed against:** v0.98.6 (2026-11-14)
**Priority:** P2 · **Effort:** M · **Invariants:** #3
**Status:** Open; maintainer-code review and its attack 2026-11-14 (gh run data). The `windows` job's meta step is about 95% of it; `UpdateDelivery.Tests.ps1` (654 to 1,215 s) starts 30th of 34 because `Invoke-HookTests.ps1:241` still prices it at 83.7 s; CI printed `TIMING UpdateDelivery.Tests.ps1 1,013.3` against the `\d+\.\d` grammar; the last reorder's model was wrong (`:221-233`).
Candidate: invariant-culture TIMING lines; order by file size, measured over three or more runs per host; then UpdateDelivery in its own job per host with a check that the shards cover the 34-file manifest (parity cannot see a case dropped on both hosts), changing `watch-ci.ps1`, `assert-ci-case-parity.ps1` and `ReleaseDistGateTiming.Tests.ps1` with it. Also decide whether UpdateDelivery's B-194 cases, which run the installer under both hosts inside one leg, break invariant 3. Guarded.
### B-511 · Delete maintainer code that no longer earns its place: the post-release eval prompt, the local gate time budget, finished eval studies
**Filed against:** v0.98.6 (2026-11-14)
**Priority:** P3 · **Effort:** S · **Invariants:** none
**Status:** Open; maintainer-code review and its attack 2026-11-14. The post-release eval branch (`release.ps1:893-948`) has never fired; it goes with `ReleasePostEvalPrompt.Tests.ps1`, `ci.yml`'s `meta/eval-results.md` re-include, `push-and-check.ps1`'s mirror of it and PushAndCheck case (d), keeping the `review-ledger.md` re-include and `-NoEvals` as an accepted no-op. The time budget refused releases five times and each time its ceiling was raised; its 700 s ceiling sits on a stage of about 30 s: delete it, `-AllowFailingGate` and their cases (about 20), keeping `ReleaseDistGateTiming`'s CI-topology and B-170 cases.
A finished study's scenarios, graders and fixtures leave `run-agent-evals.ps1` as a unit. Guarded.
### B-512 · `adopt.md` and `playbook.md` are kept as three hand-edited copies
**Filed against:** v0.98.6 (2026-11-14)
**Priority:** P3 · **Effort:** M · **Invariants:** #1
**Status:** Open; decision audit 2026-11-14: the ~6-marker cap (WSD-012) was a migration rule of thumb, and `src/core/AGENTS.md` (12 markers) and the rules file (9) already exceed it. 23 of 28 commits touching `adopt.md` edited all three copies; the audit counts about 15 differing hunks in `adopt.md`, 11 in `playbook.md` and 44 to 49 in `bootstrap.md`, which stays as it is.
Candidate: core files with `@stack` markers and byte-identical dist output, adding the core paths to AGENTS.md's guarded list so the tier does not drop; also one copy of `presentation/` (built into all three dists, never installed) and one SHA-256 bullet fewer in the bloat-radar and test-critic Copilot wrappers. Guarded (AGENTS.md).
### B-513 · Decision-log upkeep after the 2026-11-14 decision audit
**Filed against:** v0.98.6 (2026-11-14)
**Priority:** P2 · **Effort:** S · **Invariants:** none
**Status:** Open; needs the maintainer. Reconcile WSD-116 ("releases follow as soon as work lands") with AGENTS.md's "roughly weekly"; read or ratify WSD-117, WSD-120 and WSD-121 (each says the maintainer has not read it); record WSD-043's carve-outs, retire WSD-012's ~6-marker cap, restate B-157's pin rationale (its Bash oracle is gone) and WSD-105's premise (B-325's A2 arm: MISLEADING 0/6 against 6/6); time-box B-416.
Then AGENTS.md (guarded, under 120 lines): check reopen triggers whenever eval or field evidence is recorded; one cost-benefit line when something ships unmeasured; one removal candidate per re-rank. Named anchors for the rules file's numbers, as B-142 suggests. The trigger test for findings and the uncapped backlog landed with WSD-124.
### B-514 · Measure whether an auto-created project skill is used on the next matching task and changes its outcome
**Filed against:** v0.98.6 (2026-11-14)
**Priority:** P2 · **Effort:** M · **Invariants:** none
**Status:** Open; maintainer direction 2026-11-14 (WSD-124). Drafting is observed on Claude Code (B-346: both planted operations in 3 of 3 runs; the billing fixture's `wire-unity-service` in 2 of 2); use is not: in the one study that looked, none of 4 follow-up tasks called the drafted skill, and the arm with no `/bootstrap` landed the same (3 of 3; `meta/eval-results.md`, the late-fee follow-up). A draft is not in `AGENTS.md > Common Tasks` until approved, and that list is what tells the agent to invoke a skill.
Design: on `meta/eval-fixtures/b345-bootstrap-skills`, whose operations have steps that are easy to miss (registry line, schema version, flag, GRANT), ask for a new instance with the skill approved, with the draft as `/bootstrap` leaves it, with a Conventions line only, and bare; n = 6 each; graded on a Skill call and on every non-obvious step being present. Pre-register; a driver and grader come first. About 10 to 25 USD: the maintainer sets the stop before any run. A Copilot leg follows (its one run wrote Conventions lines, not skills).
### B-515 · A drafted project skill can miss a step its own instances contain
**Filed against:** v0.98.6 (2026-11-14)
**Priority:** P2 · **Effort:** S to change, M to measure · **Invariants:** #1 #7
**Status:** Open; maintainer direction 2026-11-14 (WSD-124). B-346, one reviewer's unregistered read: 3 of 6 drafts missed a step. One event draft omits the handler's DI registration (it builds, passes its tests, and faults at the first dispatch), two omit the test step, and no event draft says an unregistered event is not published; 4 of 6 give the reference as a code span, not a link.
Candidate: 3a-bis checks each draft against every instance it lists before writing it: every file an instance touches maps to a step or is marked unresolved, taking the commit that added an instance as its file list where Git history has one. Measure omitted steps before and after on the B-346 fixture. Guarded (`src/stacks/*/files/.claude/**`, three `bootstrap.md` copies).
### B-516 · A draft skill becomes active only through two manual edits, and is discoverable before anyone reviews it
**Filed against:** v0.98.6 (2026-11-14)
**Priority:** P2 · **Effort:** S · **Invariants:** #1 #7
**Status:** Open; maintainer direction 2026-11-14 (WSD-124). Approval today is the draft's `## After review` paragraph: add one Common Tasks line to `AGENTS.md` and delete the draft wording, by hand. Meanwhile 3a-bis keeps the draft "immediately discoverable", so an unreviewed draft that misses a step (B-515) can be followed.
Candidate: one action approves a draft that passed B-515's check (asked to approve it, the agent makes both edits). For the maintainer: whether a checked draft may go live without review (WSD-109 says pending PR review), and whether an unchecked one should sit where no host loads it. After B-514 says whether drafts are used at all. Guarded.
### B-517 · Discovery reads at most 40 files, so it cannot find repeated operations across a large repository
**Filed against:** v0.98.6 (2026-11-14)
**Priority:** P3 · **Effort:** M · **Invariants:** #1 #3 #7
**Status:** Open; maintainer direction 2026-11-14 (WSD-124); proposed, not designed. A8 read 43 to 60 files against its 40-file budget on a small fixture (B-346), and WSD-074's consumers are very large repositories.
Candidate: a shipped script that lists commits adding the same shape of files three or more times, with each instance's full file list, for A8 to name and 3a-bis to draft from; it would also give B-515 its ground truth. A new shipped script, so decide after B-514 and B-515, with B-466's sized fixtures as the test bed. Guarded if it ships.
### B-518 · Consumers are not told which Copilot CLI and VS Code versions are supported, or what 1.0 will promise
**Filed against:** v0.98.6 (2026-11-14)
**Priority:** P3 · **Effort:** S · **Invariants:** #7
**Status:** Open; architecture review 2026-11-14. `docs/enforcement-surfaces.md` states a floor for Claude Code only (2.1.141); nothing is stated for Copilot CLI or VS Code, whose behaviour the maintainer re-measures release by release (`meta/host-certification.md`). The framework has 115 release tags and is at 0.98 with no statement of what a 1.0 guarantees an installed repository.
Candidate: one support statement per host in `enforcement-surfaces.md`, drawn from `host-certification.md`; a short maintainer decision on what 1.0 promises (update path, ownership classes, hook contract). Ordinary for the docs.
### B-519 · Trim the always-loaded rules file only where a measurement can go red
**Filed against:** v0.98.6 (2026-11-14)
**Priority:** P3 · **Effort:** M · **Invariants:** #1 #7
**Status:** Open; architecture review 2026-11-14, narrowed by its attack. The carrier is 15.6 KB on every turn; B-411 showed 5.8 KB could go with every measured behaviour holding, but its cells cover about 3 of the file's 38 directives and WSD-107 measured one added sentence doing harm. The ownership sentence stays (WSD-071); the rule numbers are cited across `src/` and their renaming is B-513's.
Candidate: cut or shorten only text a discriminating cell covers, one group per measurement; B-356's bullet is decided by its own measurement. Ordinary by path; every cut measured.
### B-520 · Smaller leftovers of the 2026-11-14 reviews
**Filed against:** v0.98.6 (2026-11-14)
**Priority:** P3 · **Effort:** S each · **Invariants:** none
**Status:** Open; each stood its attack in this narrowed form. (1) Headless `/adopt` (about 6.8 KB) into its own file. (2) When a live eval run is hand-checked, keep its scrubbed transcript and verdict as a self-test fixture: grader defects were found by reading transcripts, not by the hand-written fixtures. (3) Time `UpdateDelivery.Tests.ps1` per case, then replace only the setup installs whose result no case asserts.
(4) One meta case asserting the five `Test-IsLinkEntry` copies are identical and none uses a bare `-band ReparsePoint`, in place of the five per-copy cases. (5) `build.ps1`'s second ownership listing (`:383-390`): the Bash oracle it replaced is gone (B-157), so keep or delete it on purpose. (6) Release tests also run under 5.1, though `release.ps1` needs PowerShell 7.
