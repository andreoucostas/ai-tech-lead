# Framework backlog

Open work only, at most 40 entries (`AGENTS.md`, "Records"). Take the first unblocked row of the
pick-up order, one item per fresh session; the tier is read off the changed paths at work time. An
entry is its heading, filed-against line, priority line and at most three lines of status; the
evidence lives in the plans and decisions it names. An empty backlog says "No open entries." on its
own line under Open entries; the hygiene tests refuse that line beside an entry. A session that
finds an adjacent defect outside AGENTS.md's four guarded harms, which no field report raised,
closes it per WSD-106 with one CLOSED line in `meta/BACKLOG-DONE.md` instead of filing it here.
Full pre-reset text: `git show 36babcaf:meta/BACKLOG.md`.

## Pick-up order — ranked 2026-09-30 (WSD-105 probe); re-ranked 2026-10-01 (WSD-107, field replies); B-331 to the idle queue 2026-10-02 (WSD-109); B-346 filed and done the same day; B-330 done and B-336 closed by measurement 2026-10-03; B-331 done, B-326 done and B-348 filed, and B-327, B-328, B-329 and B-337 done 2026-10-04; B-352 to B-354 filed 2026-10-05 (Fable review, consumer host reply), B-352 and B-354 done the same day (WSD-110), B-353 done the same day, B-356 filed the same day (maintainer request; first numbered B-355 at 254c904f, renumbered because 99253721 closed a different B-355); B-357 filed 2026-10-06 (the 0.94.0 Copilot skill wrappers); B-359 and B-360 filed 2026-10-07 (attack rounds on those wrappers); B-348's and B-356's wordings shipped unmeasured 2026-10-08 (WSD-111), their measurements kept open; B-361 and B-362 done 2026-10-09 without filing (field report #9), B-363 to B-366 closed by decision the same day (WSD-106); re-ranked 2026-10-09: B-367 filed at rank 1 (maintainer request, Angular v21-v22 audit) and B-368 done the same day, B-369 and B-370 closed by decision (WSD-106) and B-371 filed the same day (a reviewing session's build.ps1 run); B-372 done and B-373 and B-374 filed the same day (audit batch 2, its fresh-session attack and its CP437 leg); B-375 filed and done 2026-10-10 and B-376 2026-10-11 (audit batches 3 and 4); re-ranked 2026-10-11: B-377 to B-382 filed (maintainer request, review of the VS Code 1.132-1.141 and Copilot CLI 1.0.80-1.0.95 releases) and B-357 to the bottom (consumers host on Bitbucket Data Center, so Copilot code review on github.com never sees their PRs), then B-348 widened to VS Code and B-383 and B-384 filed the same day (maintainer request); B-386 and B-387 filed and done the same day (audit batches 5a and 5b), and B-367 done the same day (audit batch 6, the last); B-377 closed by measurement the same day (Copilot CLI 1.0.95 still delivers the prompt hook's context), unblocking B-380; B-384 closed by measurement the same day (on CLI 1.0.95 the eval runner's hook opt-in still loads hooks, and `-p` still passes slash commands to the model as text); B-348's Copilot CLI half measured the same day (pre-registered at f00d3e1d: the shipped wording reached the CLI's built-in agent in 3 of 6 refund runs), with B-388 and B-389 filed after it and B-390 closed by decision (WSD-106); B-389 done the same day (pre-registered at 04548f59: without the advance approval the always-loaded rule alone got a pass in 4 of 4 runs, and with `route-prompt`'s reminder firing in 4 of 4, so the approval suppressed the rule and the sensitive pattern was widened), with B-391 filed from its fresh-session attack; B-388 done the same day (pre-registered at ac9bef70: the skill renamed `security-gate`, WSD-114, after which the refund prompt ran this framework's review in 6 of 6 runs), with B-392 filed the same day (maintainer report, eval case angular-003) and B-393 from its fresh-session attack; B-378's documentation shipped 2026-10-12 and its entry narrowed to its VS Code canary (pre-registered at 93844fb8: the runtime VS Code 1.139.1 bundles ran both hook files), with B-394 closed by decision (WSD-106); B-379 done the same day (pre-registered at e5c35e72), with B-395 filed at rank 1 (its canary: gpt-6.1-sol wrote a key-shaped value through `apply_patch`, which the guard does not read) and B-396 at rank 4 (the hooks in the CLI's local sandbox); B-395 done 2026-10-14 (pre-registered at 1adbe21a: the fixed guard blocked gpt-6.1-sol's `apply_patch` canary 3 of 3 on the CLI and 1 of 1 on the bundled runtime), with B-397 filed after it; B-398 filed and done the same day (maintainer report; pre-registered at 2c2b6e7e: 0.95.0's `model: sonnet` stopped `/bootstrap`'s worker on Copilot CLI), with B-399 filed at rank 2; B-400 and B-401 filed and done the same day (maintainer request; pre-registered at 06c7ab75), with B-402 filed after B-401; B-371 done 2026-10-15 and B-399 blocked the same day (Copilot access ended), and B-397 done the same day; re-ranked 2026-10-19 (maintainer request): B-418 done and B-422 filed from it, B-403, B-404, B-414, B-416, B-417, B-419, B-420 and B-422 ranked, B-399 unblocked (Copilot access restored: B-414b, B-421 and B-421b ran on CLI 1.0.98), B-414 narrowed by B-421b, and B-393 raised (data-loss class); B-422 done and B-423 filed from it 2026-10-19, and B-423 done the same day; B-399 closed by measurement the same day (CLI 1.0.98 ran the three `model: haiku` reviewers through their model-less wrappers on the session's model); B-425 filed at rank 2 and B-426 closed by decision the same day (Fable's advice on when the reviewers run, maintainer decision), and B-427 filed at rank 11 (maintainer request, reopening B-424's question); B-414c measured the same day (pre-registered at b6917f46: in a bootstrapped repository Copilot red-first 0/6 on both prompts, Claude Code 6/6, so B-414 stays open), with B-428 closed by decision (WSD-106); B-393 done the same day for 0.98.2, its fresh-session attack filing B-429 to B-432 (older defects in the same installer) with B-429 at rank 2; B-396 closed by measurement the same day (pre-registered at aeb06a6e: not reproduced on CLI 1.0.98 or 1.0.95; attributed cause a host without the sandbox's filesystem enumeration), with B-433 filed at its rank; B-429 done the same day for 0.98.2, with B-434 and B-435 filed from its implementation (two reasoned leaks); B-434 then fixed within B-429's hardening after its first fresh-session attack executed it; B-433 done the same day for 0.98.2; idle queue added 2026-09-30 (WSD-106); every earlier entry closed 2026-09-29 (WSD-105); B-450 to B-455 filed 2026-10-21 (field report, six items): B-450, B-454, B-451 and B-452 ranked 3 to 6 as field-raised, B-453 and B-455 below B-440; B-450 done 2026-10-22 and B-441's stale entry (done and shipped in 0.98.2) removed, with B-456 closed by decision (WSD-106); B-454 done 2026-10-22; B-459 filed 2026-10-23 at rank 18 (maintainer request relaying a consumer's expectation, reopening B-129's question); B-463 filed 2026-10-23 at rank 2 (maintainer-requested bug hunt over the eleven scripts B-460 left untouched; captured, not fixed, at the maintainer's request), B-416 to B-461 each one rank down; B-464 filed 2026-10-24 at rank 2 (maintainer-requested bug hunt batch 3 over the maintainer tooling, the gates, the installers and the shipped wiring), B-463 to B-461 each one rank down, and narrowed the same day to three leftovers after its batch fixed or closed every other finding, with B-465 closed by decision (WSD-106); B-466 filed 2026-10-27 at rank 4 (maintainer request: whether the framework's lead over the bare agent grows with repository size, pre-registered the same day), B-451 to B-461 each one rank down; B-467 filed 2026-10-27 at rank 15 (maintainer request: the sub-agent context measurement read FILE), B-356 to B-461 each one rank down; B-468 filed 2026-10-27 at rank 28 (maintainer request: the test-level eval's skipped regression tests); B-469 filed 2026-10-28 at rank 29 (maintainer request, out of scope of the `-Reinstall` change); B-470 filed 2026-10-28 at rank 30 (maintainer request: a pre-registered UX-consistency probe, after a fresh-session attack on the proposal); B-470 closed by measurement 2026-10-31 (Copilot CLI after the Claude Code launch was refused: framework 6/6 and bare 6/6 mirrored the sibling); B-383 closed by measurement 2026-10-31 (no validate-dist ceiling), B-467 to B-469 each one rank up; B-452 done 2026-10-31 (WSD-118: the baseline stays committed), B-425 to B-469 each one rank up; B-451 narrowed 2026-10-31 to its review-tool markers (the compact schema shipped) and moved to the last rank, B-466 to B-469 each one rank up; B-449 done 2026-10-31, B-374 to B-451 each one rank up; B-464 leftover (1) done 2026-10-31 (step-4 attack and its fixes, reviewed again), B-471 filed the same day at rank 27 (that attack's and the B-449 review's installer leftovers); B-463 done 2026-10-31 (G1 and G2, with G1's follow-up) and B-373 done the same day, B-466 to B-471 each one or two ranks up; B-472 and B-473 filed the same day at ranks 26 and 27 (the guard review's leftovers, B-463's adjacent scripts); B-474 filed the same day at rank 20 (B-463 G1 item 5 reopened: its WSD-106 close was in the secret-leak class, which WSD-106 excludes; found by the fresh-session attack on 1cbedd79), B-357 to B-473 each one rank down; B-475 and B-476 filed 2026-11-03 at ranks 2 and 3 (maintainer request: VS Code 1.144.1's Copilot harness driven through its agent host), B-464 to B-473 each two ranks down; B-455 and B-459 closed by decision 2026-11-04 (WSD-120, WSD-121; a Fable review under the maintainer's chat mandate to answer direction questions, not yet read by the maintainer), B-374 to B-473 each two ranks up; B-374 done 2026-11-04 (post-write reads its event as UTF-8; boy-scout-check examined, unchanged), B-448 to B-473 each one rank up; B-403 closed by measurement 2026-11-04 (Claude Code arm pre-registered at daafbfc2: the underspecified prompt held 3 of 3, the no-gap prompt passed through 3 of 3), B-420 to B-473 each one rank up; B-473 done 2026-11-04 (test-weakening-scan reads a OneDrive folder as a folder; template-checks runs at a path holding [); B-453 done 2026-11-04 (a zero-byte file is left out of a claim's evidence and named on an EMPTY line); B-448 done 2026-11-04 (Turkish-cased credential key names blocked again); B-472 done 2026-11-04 (UNC repository root, trailing separator and 8.3 names), with B-477 and B-478 filed at ranks 21 and 22 from its and B-474's step-4 attacks; B-474 done 2026-11-04 (Claude Code 2.1.312's NotebookEdit captured and guarded; Copilot CLI 1.0.98 has no notebook tool); B-461 and B-432 done 2026-11-04 (installer and review-scope run Git without the caller's GIT_*_PATHSPECS; 5.1 without long paths refuses before any change), with B-479 filed at rank 20 from B-432's step-4 attack; B-440 done and B-471 narrowed 2026-11-04 (stop lines carry their overrides, the writes after the copy loop stop with exit 3, saved copies of skip-worktree files named; two WARNING gaps left), with B-480 filed at rank 20 from their step-4 attack; B-467 measured 2026-11-04 (pre-registered at d7da3b75), not shipped: R2 not settled; B-481 and B-482 filed 2026-11-05 at ranks 21 and 22 from the step-4 attack on the `-Reinstall` instruction-file archive; B-484 filed 2026-11-06 at rank 23 (field report #13, the adjacent finding); B-485 to B-497 filed 2026-11-10 at ranks 24 to 36 (maintainer-requested external audit; briefs in `.claude/plans/2026-11-10-external-audit-briefs.md`; ranked among themselves only, the maintainer ranks them against the rows above); B-492 done 2026-11-10 (the audit's first five, maintainer request), B-485 to B-494 each one rank up; B-485 done 2026-11-10, B-488 to B-494 each one rank up; B-486 done 2026-11-10, B-488 to B-494 each one rank up; B-498 filed 2026-11-10 at rank 34 (B-486's step-4 attack); B-488 done 2026-11-10, the rows below it each one rank up; B-487 done 2026-11-10; B-499 filed 2026-11-10 at rank 24 in its place (B-487's step-4 attacks), the rows below unchanged; re-ranked 2026-11-11 (maintainer request): the installer items B-494, B-481, B-480, B-482, B-495 and B-469 and the everyday-friction items B-491, B-493, B-425, B-497 and B-467 to ranks 5 to 15, below B-466, whose 60 USD stop the maintainer approved the same day; B-494 done 2026-11-11 (WSD-123), the rows below it each one rank up; B-481 done 2026-11-11, the rows below it each one rank up, with B-500 and B-501 filed at ranks 32 and 33 from its scope check and its step-4 attack; B-480 done 2026-11-11, the rows below it each one rank up, with B-502 filed at rank 33 from its scope check; B-482 done 2026-11-11, the rows below it each one rank up, with B-503 filed at rank 33 from its step-4 attack; B-495 done 2026-11-12, the rows below it each one rank up; B-348 done 2026-11-13 (its VS Code half measured), the rows below it each one rank up, and its runs narrowed B-475 and unblocked B-476; B-425's Copilot leg measured 2026-11-13, its status and row restated; B-357 closed by decision 2026-11-14 (maintainer, in chat: no consumer hosts on github.com; not measured), the rows below it each one rank up; B-476 done 2026-11-14 (pre-registered at 19ffd9ea: on VS Code 1.146.0 `session-start` carried the first prompt's rails to the model 6 of 6, the security pass followed 1 of 6), the rows below it each one rank up

| Rank | Item | Why here |
|---|---|---|
| 1 | B-416 | P1: the only route to whether 0.98.0's restated criteria and Option A/B designs are right and used, and it gates B-417 to B-419's shipping changes; needs the maintainer and the first consumer team |
| 2 | B-475 | P1 until a Chat-view check: on VS Code 1.144.1 no repository hook ran in a trusted folder (0 of 7); on 1.146.0 they ran 3 of 3 (2026-11-13), so what is left is that check and a guarded fix to the docs and doctor row that say they do not |
| 3 | B-466 | Maintainer request: the first test of whether the framework's lead over the bare agent grows with repository size, the case for large legacy codebases; pre-registered, its 60 USD stop approved by the maintainer 2026-11-11; runner work and three generations before any run |
| 4 | B-469 | Maintainer request: an update's `.claude/framework-update-backup/` copies get forgotten and committed; `-Reinstall` already relies on the last commit instead; guarded |
| 5 | B-491 | Audit, reproduced: `route-prompt` routes "yes, go ahead" and plain questions as a feature with the plan gate, and "concurrency" gets the security overlay; guarded |
| 6 | B-493 | Audit, read: `dependency-audit` forbids inferring the read-only scan commands, so it reports every scan as not available; guarded, text-only |
| 7 | B-425 | A plain-words review runs no reviewer: on Copilot CLI it loads the `review` skill (5 of 6, 2026-11-13) but skips its dispatch step (0 of 6), with or without the candidate; blocked on B-416; the Claude Code leg is about 3 USD |
| 8 | B-497 | Audit, read: `/review` has no merge, de-duplication or verdict step, and two reviewers give opposite advice on delegation; ordinary |
| 9 | B-467 | Measured 2026-11-04: omitClaudeMd cuts each reviewer's first request by about 9,200 tokens; the findings comparison was not settled under the eval harness, so a re-run decides shipping |
| 10 | B-417 | Improvement to 0.98.0's core: B-412 saw no downstream difference because prompt K states every outcome; about 10 USD |
| 11 | B-420 | The fix path's restated criterion, unchanged since 0.97; about 8 USD; better after B-416's field answers |
| 12 | B-419 | Improvement with no field report; starts with a hand-read of the retained security passes |
| 13 | B-356 | Maintainer idea with no field report; its bullet shipped unmeasured (WSD-111), so the decoy's false-offer rate decides whether it stays |
| 14 | B-468 | Measured, not field-raised: 2 of 26 plain bug fixes skipped the regression test, wrongly saying a SQLite test needs a new package; the agent said the fix was untested |
| 15 | B-451 | Field report, narrowed: the compact baseline shipped; review-tool markers for it wait on the reporter saying what their host honours; guarded |
| 16 | B-471 | Installer leftovers of the 2026-10-31 attacks, narrowed to two skip-worktree WARNING gaps (a case-mismatched subfolder target, an unchanged flagged file named); guarded, step 4 |
| 17 | B-477 | Stall class, contrived: the write guard walks a written path twice, so on PowerShell 7 a path of about 400 KB of collapsing segments now outlives Copilot's 10 s; guarded, step 4 |
| 18 | B-478 | Write-guard leftovers of the 2026-11-04 step-4 attacks: `password` spelt with the long s passes, and a path-less `NotebookEdit` falls through (the host's schema requires the path); guarded, step 4 |
| 19 | B-479 | B-432's refusal misses one unplanned write: a brownfield at a 197 to 206 character target on 5.1 without long paths stops with the old unnamed-cause message (exit 3, nothing written); guarded, step 4 |
| 20 | B-484 | Secret-leak class, adjacent to field report #13: a committed credential's hazard row commits its `path:line`, which `/security-gate` forbids; guarded, text-only |
| 21 | B-499 | Secret-leak class, B-487's step-4 attacks: the guard still passes an auto-property initializer, `NetworkCredential`, URL userinfo and other credential forms; guarded, step 4 |
| 22 | B-496 | Audit, a sub-session's run: the removal checklist leaves `.claude/settings.json` registering deleted hooks; ordinary |
| 23 | B-489 | Audit, reproduced: the guard blocks UI labels, vault references and documentation samples with no waiver; needs the maintainer's decision (a WSD) first |
| 24 | B-490 | Audit, a sub-session's run: with `pwsh` missing the guard's registered command exits 0, and the agent can rewrite the hook registrations; needs the maintainer's decision first |
| 25 | B-498 | False-green and false-red class, a sub-session's runs: the doctor reads a carried `statusLine` command as a hook and ignores `disableAllHooks`; ordinary |
| 26 | B-500 | Wrong-repository class, read: the outdated-clone advice double-quotes the clone path, so pasted into PowerShell a `$` in it expands and the `checkout` or `pull` runs elsewhere; guarded, step 4 |
| 27 | B-501 | Wrong-repository class, contrived: the installer writes printed paths in the console's code page, so on CP437 a `’` in a restore line's path arrives as `'` and the pasted line names another folder; guarded, step 4 |
| 28 | B-502 | Data-loss class, pre-existing, B-480's scope check (run): a disabled skill's exemplar line survives the update that disables it and is dropped by the next one; guarded, step 4 |
| 29 | B-503 | Data-loss class, pre-existing, B-482's step-4 attack (run): `-Reinstall` replaces an instruction file Git tracks under another letter case without checking it against the commit; guarded, step 4 |

## Open entries

### B-356 · Measure a plan-step offer of a test, Conventions line or project-skill draft when a feature creates a repeatable operation
**Filed against:** v0.93.0 (2026-10-05)
**Priority:** P3 · **Effort:** M to measure, S to change · **Invariants:** #1 #7
**Status:** Open; raised by the maintainer 2026-10-05, no field report (WSD-109). The candidate bullet shipped unmeasured in carrier §2 (WSD-111).
Measure it (B-346 method): an extension-point feature, a third instance and a plain CRUD decoy whose false-offer rate decides whether it stays;
design: `.claude/plans/2026-10-08-b348-b356-plan-v2.md` Part B. Its Copilot stage: `.claude/plans/2026-11-13-copilot-window-briefs.md`, "B-356".

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

### B-471 · Installer leftovers of the 2026-10-31 step-4 attacks: stops outside the copy loop, two remedies that fail, and three B-449 warning gaps
**Filed against:** v0.98.2 (2026-10-31)
**Priority:** P3 · **Effort:** S · **Invariants:** #7
**Status:** Narrowed 2026-11-04: (a), (b) and two of (c)'s gaps done. Left, both B-449 WARNING gaps: nothing is listed for a subfolder target whose on-disk case differs from Git's index (`ls-files` run from the target lists nothing; reading from the repository root with an icase pathspec changes the skipped set -Reinstall and the brownfield archive also read), and a flagged file whose bytes this run left unchanged is named too. Guarded, step 4.

### B-475 · VS Code 1.144.1: repository hooks never load in a folder VS Code trusts, so no framework hook runs in its Copilot harness
**Filed against:** v0.98.3 (2026-11-03)
**Priority:** P1 · **Effort:** M · **Invariants:** #5 #7
**Status:** Open, narrowed 2026-11-13 by B-348's VS Code runs (`meta/eval-results.md`, `meta/host-certification.md`): on VS Code 1.146.0 (69047191fc) with runtime 1.0.108-0, sessions the agent host granted folder trust ran the repository's hooks 3 of 3 and untrusted ones 7 of 7, where 1.144.1 ran none in 7 trusted
(the root cause then: deferral to `sessions.loadDeferredRepoHooks`, which the agent host still never references, so the change is presumably the runtime's). Script-created sessions in folder isolation only; microsoft/vscode#345931 is still open.
Left: one Chat-view session in a trusted folder on this version, then a guarded change to the docs and the doctor's `Copilot hook liveness` row (0.98.4), which say a trusted folder runs no repository hook.

### B-477 · The write guard walks a written path twice, so on PowerShell 7 a pathological path takes twice as long to decide
**Filed against:** v0.98.3 (2026-11-04)
**Priority:** P3 · **Effort:** S · **Invariants:** #3
**Status:** Open; found by B-472's step-4 attack (executed). `Get-CheckedFileName` and `Get-RepositoryRelativePath` each walk the path's segments, and a UNC path is now walked too: a 1.4 MB `src\x\..\…\Foo.cs` (Node 24 writes it into `Foo.cs`) took 34.0 s on pwsh 7.6.9 against 16.7 s on b1f42438 (1.4 s on 5.1), and a 1.5 MB UNC path 42 s against about 1 s.
Contrived; about 400 KB of collapsing path now outlives Copilot's 10 s (was about 700 KB). Candidate: derive the checked name from the exemption walk's kept list (one walk), timed red first. Guarded, step 4.

### B-478 · Write-guard leftovers of the 2026-11-04 step-4 attacks: the long s in `password`, and a path-less `NotebookEdit`
**Filed against:** v0.98.3 (2026-11-04)
**Priority:** P3 · **Effort:** S · **Invariants:** #3
**Status:** Open; pre-existing on b1f42438, executed by the attacks on B-472 and B-474. (a) `pa` U+017F U+017F `word = "…"` passes on pwsh and 5.1, like B-445's Kelvin-sign `k` on 5.1; no culture's casing writes either, so decide both together (a secret-leak finding needs a WSD, not WSD-106).
(b) A `NotebookEdit` with `notebook_path` absent, empty or null and a key in `new_source` exits 0 where a path-less `Write` blocks (`NotebookEdit` is not in `$knownWrite`); Claude Code's schema requires the path. Guarded, step 4.
### B-479 · B-432's long-path refusal misses the brownfield marker's temp file
**Filed against:** v0.98.3 (2026-11-04)
**Priority:** P3 · **Effort:** S · **Invariants:** #3
**Status:** Open; found by B-432's step-4 attack (executed on emulated 5.1 without long paths). The marker's `.claude/.adoption-pending-<32 hex>.tmp` is 34 characters longer than the planned marker and is not in the create, replace or archive plan, so for a brownfield target of 197 to 206 characters planning passes and the marker write stops with "could not persist the complete pre-move archive inventory … Could not find a part of the path" (exit 3, tree unchanged, as on b1f42438). Candidate: add the temp path to the length check; red case at a 201-character brownfield. Guarded, step 4.
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
### B-490 · With `pwsh` missing the guard's registered command exits 0, and the agent can rewrite the hook registrations
**Filed against:** v0.98.4 (2026-11-10)
**Priority:** P2 · **Effort:** S to M · **Invariants:** #3 #5
**Status:** Open, waiting on the maintainer's decision; maintainer-requested external audit. A sub-session's run, not re-run: the registered `pwsh … guard.ps1 ; exit $LASTEXITCODE` string through `powershell.exe` with PowerShell 7 off `PATH` exits 0 on a key-shaped write. Reproduced: a write of `{ "hooks": {} }` to `.claude/settings.json` exits 0.
Decide fail closed (stalls a teammate without PowerShell 7) against fail open (a false green), and how narrowly to protect the registrations without stopping `/adopt`. Guarded. Brief: `.claude/plans/2026-11-10-external-audit-briefs.md`.
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
### B-497 · `/review` hands back six reviewers' findings with no merge, de-duplication or verdict rule
**Filed against:** v0.98.4 (2026-11-10)
**Priority:** P3 · **Effort:** S to M · **Invariants:** #1 #7
**Status:** Open; maintainer-requested external audit (a sub-session's reading, noise predicted, not measured). `review.md` has no thresholds or de-duplication where `security-gate.md` has thresholds; `bloat-radar` flags a single-delegation method while `solid-check` flags a controller action that does more than delegate; commented-out code has two thresholds.
Candidate: a merge on `file:line`, one severity scale and one verdict line; drop the lines-per-file heuristic. Ordinary unless a stack file changes. Brief: `.claude/plans/2026-11-10-external-audit-briefs.md`.
### B-498 · `framework-doctor` reads every `command` in `.claude/settings.json` as a hook and ignores `disableAllHooks`
**Filed against:** v0.98.4 (2026-11-10)
**Priority:** P3 · **Effort:** S · **Invariants:** #1 #7
**Status:** Open; found by B-486's step-4 attack (a sub-session's runs, not re-run). The doctor walks every `command` property, not only those under `hooks`, so a team's `statusLine` with a `bash` command reads `[MISSING] Hook registration topology` and exits 1; with `"disableAllHooks": true` it still reports `8 ok / 0 missing`. A hand-added key already tripped it; since B-486 an update keeps the key, so it trips it on every run.
Candidate: read commands under `hooks` only; report `disableAllHooks: true` as `[MISSING]`. Ordinary by path; the false green is a guarded harm, so it takes a red-first case.
### B-499 · Credential forms the write guard still does not read after B-487
**Filed against:** v0.98.4 (2026-11-10)
**Priority:** P3 · **Effort:** M · **Invariants:** #3 #5 #7
**Status:** Open; B-487's step-4 attacks (a sub-session's runs, not re-run). Not read: an auto-property initializer `public string Password { get; set; } = "…"`, Redis `password=`, URL userinfo outside a connection-string key, a backtick string, a `Dictionary` initializer, `new NetworkCredential(…)`, `SetEnvironmentVariable`, `password?:`, a `"""` or `$"` literal, a `??` or `||` fallback, VB; and B-487's stated limits: `string.Join`, `;;`, a quote inside the literal, a JDBC neighbour, a `:` in a neighbouring key, the computed key `['password']:`, a no-break space or vertical tab, a one-pair literal standing alone, a variable between the pieces (`"Server=" + host + ";Password=…"`, the commonest real shape), VB `&`, `+=`, `string.Concat`, `AppendFormat`, `.Add(` or `.push(` pieces, an unkeyed password opening with `@`; and its false blocks on a mask, message or SQL text that is a piece of a longer string.
Candidate: decide per form whether the guard or CI secret scanning owns it; extending the guard is guarded, step 4, and each form needs its false-block survey (B-487 audited 145 repo and 476 npm files).
### B-500 · The outdated-clone advice expands a `$` in the clone path when pasted into PowerShell
**Filed against:** v0.98.5 (2026-11-11)
**Priority:** P3 · **Effort:** S · **Invariants:** #3
**Status:** Open; found by B-481's scope check (read, not paste-tested). A clone behind its remote prints `git -C "<clone>" fetch --tags <remote>, then git -C "<clone>" checkout v<x>` or `git -C "<clone>" pull`; with `$x` in the clone path the pasted command fails, or checks out or pulls in a sibling repository at the expanded path. B-495's off-tag clause in the `source:` line prints the same string.
Candidate: the script-scope `$quote` B-481 added, moved above this check; red case: a `$`-named clone behind its newest tag, the line run as printed. Guarded, step 4.
### B-501 · A printed path loses its non-code-page characters on the way to the console
**Filed against:** v0.98.5 (2026-11-11)
**Priority:** P3 · **Effort:** S to M · **Invariants:** #3
**Status:** Open; found by B-481's step-4 attack (executed: `[Console]::Error.WriteLine` of U+2019 read back through a pipe as `'` on 5.1, 5.1 under CP437, and 7). The installer writes in the console's code page, so a restore line for a target named `Bob’s` arrives as `Bob's`: pasted, it fails, or names another folder with that spelling.
Candidate: write the stop lines as UTF-8, or name the path's unprintable characters; the B-481 cases read the output as UTF-8 to step around it. Guarded, step 4.
### B-502 · A disabled skill's exemplar line is dropped by the update after the one that disables it
**Filed against:** v0.98.5 (2026-11-11)
**Priority:** P3 · **Effort:** S · **Invariants:** #7
**Status:** Open; found by B-480's scope check (run on dist/dotnet: install, a "For a concrete current instance" line added to `add-warehouse-load`, the skill disabled in LEARNINGS.md; the first update kept the line in `.claude/disabled-skills/add-warehouse-load/SKILL.md`, the second, exit 0, replaced it without the line). The update reads exemplar lines only under `.claude/skills/`.
Candidate: read a disabled skill's line from `.claude/disabled-skills/<name>/SKILL.md` too; red case from that run. Guarded, step 4.
### B-503 · `-Reinstall` skips the commit check for `CLAUDE.md` or `AGENTS.md` that Git tracks in another letter case
**Filed against:** v0.98.5 (2026-11-11)
**Priority:** P3 · **Effort:** S · **Invariants:** #7
**Status:** Open; found by B-482's step-4 attack (run on dist/dotnet, adoption pending, the mirror tracked as `agents.md`, then a same-size edit with its write time restored so `git status` stayed empty): exit 0, the edit replaced and in no commit, while the `LAYOUT:` line says the commit holds it; with `AGENTS.md` cased as tracked the same edit stops with exit 4. `$heldCheck` filters the two names through the ordinal `$trackedBlobs`, while `$reinstallTracked` (ignore-case) lets the move through.
Candidate: look the two names up in `$trackedBlobs` by their tracked spelling; red case from that run. The final `moved:` summary line names the bare commit too. Guarded, step 4.
