# Framework backlog

Open work only, at most 40 entries (`AGENTS.md`, "Records"). Take the first unblocked row of the
pick-up order, one item per fresh session; the tier is read off the changed paths at work time. An
entry is its heading, filed-against line, priority line and at most three lines of status; the
evidence lives in the plans and decisions it names. An empty backlog says "No open entries." on its
own line under Open entries; the hygiene tests refuse that line beside an entry. A session that
finds an adjacent defect outside AGENTS.md's four guarded harms, which no field report raised,
closes it per WSD-106 with one CLOSED line in `meta/BACKLOG-DONE.md` instead of filing it here.
Full pre-reset text: `git show 36babcaf:meta/BACKLOG.md`.

## Pick-up order — ranked 2026-09-30 (WSD-105 probe); re-ranked 2026-10-01 (WSD-107, field replies); B-331 to the idle queue 2026-10-02 (WSD-109); B-346 filed and done the same day; B-330 done and B-336 closed by measurement 2026-10-03; B-331 done, B-326 done and B-348 filed, and B-327, B-328, B-329 and B-337 done 2026-10-04; B-352 to B-354 filed 2026-10-05 (Fable review, consumer host reply), B-352 and B-354 done the same day (WSD-110), B-353 done the same day, B-356 filed the same day (maintainer request; first numbered B-355 at 254c904f, renumbered because 99253721 closed a different B-355); B-357 filed 2026-10-06 (the 0.94.0 Copilot skill wrappers); B-359 and B-360 filed 2026-10-07 (attack rounds on those wrappers); B-348's and B-356's wordings shipped unmeasured 2026-10-08 (WSD-111), their measurements kept open; B-361 and B-362 done 2026-10-09 without filing (field report #9), B-363 to B-366 closed by decision the same day (WSD-106); re-ranked 2026-10-09: B-367 filed at rank 1 (maintainer request, Angular v21-v22 audit) and B-368 done the same day, B-369 and B-370 closed by decision (WSD-106) and B-371 filed the same day (a reviewing session's build.ps1 run); B-372 done and B-373 and B-374 filed the same day (audit batch 2, its fresh-session attack and its CP437 leg); B-375 filed and done 2026-10-10 and B-376 2026-10-11 (audit batches 3 and 4); re-ranked 2026-10-11: B-377 to B-382 filed (maintainer request, review of the VS Code 1.132-1.141 and Copilot CLI 1.0.80-1.0.95 releases) and B-357 to the bottom (consumers host on Bitbucket Data Center, so Copilot code review on github.com never sees their PRs), then B-348 widened to VS Code and B-383 and B-384 filed the same day (maintainer request); B-386 and B-387 filed and done the same day (audit batches 5a and 5b), and B-367 done the same day (audit batch 6, the last); B-377 closed by measurement the same day (Copilot CLI 1.0.95 still delivers the prompt hook's context), unblocking B-380; B-384 closed by measurement the same day (on CLI 1.0.95 the eval runner's hook opt-in still loads hooks, and `-p` still passes slash commands to the model as text); B-348's Copilot CLI half measured the same day (pre-registered at f00d3e1d: the shipped wording reached the CLI's built-in agent in 3 of 6 refund runs), with B-388 and B-389 filed after it and B-390 closed by decision (WSD-106); B-389 done the same day (pre-registered at 04548f59: without the advance approval the always-loaded rule alone got a pass in 4 of 4 runs, and with `route-prompt`'s reminder firing in 4 of 4, so the approval suppressed the rule and the sensitive pattern was widened), with B-391 filed from its fresh-session attack; B-388 done the same day (pre-registered at ac9bef70: the skill renamed `security-gate`, WSD-114, after which the refund prompt ran this framework's review in 6 of 6 runs), with B-392 filed the same day (maintainer report, eval case angular-003) and B-393 from its fresh-session attack; B-378's documentation shipped 2026-10-12 and its entry narrowed to its VS Code canary (pre-registered at 93844fb8: the runtime VS Code 1.139.1 bundles ran both hook files), with B-394 closed by decision (WSD-106); B-379 done the same day (pre-registered at e5c35e72), with B-395 filed at rank 1 (its canary: gpt-6.1-sol wrote a key-shaped value through `apply_patch`, which the guard does not read) and B-396 at rank 4 (the hooks in the CLI's local sandbox); B-395 done 2026-10-14 (pre-registered at 1adbe21a: the fixed guard blocked gpt-6.1-sol's `apply_patch` canary 3 of 3 on the CLI and 1 of 1 on the bundled runtime), with B-397 filed after it; B-398 filed and done the same day (maintainer report; pre-registered at 2c2b6e7e: 0.95.0's `model: sonnet` stopped `/bootstrap`'s worker on Copilot CLI), with B-399 filed at rank 2; B-400 and B-401 filed and done the same day (maintainer request; pre-registered at 06c7ab75), with B-402 filed after B-401; B-371 done 2026-10-15 and B-399 blocked the same day (Copilot access ended), and B-397 done the same day; re-ranked 2026-10-19 (maintainer request): B-418 done and B-422 filed from it, B-403, B-404, B-414, B-416, B-417, B-419, B-420 and B-422 ranked, B-399 unblocked (Copilot access restored: B-414b, B-421 and B-421b ran on CLI 1.0.98), B-414 narrowed by B-421b, and B-393 raised (data-loss class); B-422 done and B-423 filed from it 2026-10-19, and B-423 done the same day; B-399 closed by measurement the same day (CLI 1.0.98 ran the three `model: haiku` reviewers through their model-less wrappers on the session's model); B-425 filed at rank 2 and B-426 closed by decision the same day (Fable's advice on when the reviewers run, maintainer decision), and B-427 filed at rank 11 (maintainer request, reopening B-424's question); B-414c measured the same day (pre-registered at b6917f46: in a bootstrapped repository Copilot red-first 0/6 on both prompts, Claude Code 6/6, so B-414 stays open), with B-428 closed by decision (WSD-106); B-393 done the same day for 0.98.2, its fresh-session attack filing B-429 to B-432 (older defects in the same installer) with B-429 at rank 2; B-396 closed by measurement the same day (pre-registered at aeb06a6e: not reproduced on CLI 1.0.98 or 1.0.95; attributed cause a host without the sandbox's filesystem enumeration), with B-433 filed at its rank; B-429 done the same day for 0.98.2, with B-434 and B-435 filed from its implementation (two reasoned leaks); B-434 then fixed within B-429's hardening after its first fresh-session attack executed it; B-433 done the same day for 0.98.2; idle queue added 2026-09-30 (WSD-106); every earlier entry closed 2026-09-29 (WSD-105); B-450 to B-455 filed 2026-10-21 (field report, six items): B-450, B-454, B-451 and B-452 ranked 3 to 6 as field-raised, B-453 and B-455 below B-440; B-450 done 2026-10-22 and B-441's stale entry (done and shipped in 0.98.2) removed, with B-456 closed by decision (WSD-106); B-454 done 2026-10-22; B-459 filed 2026-10-23 at rank 18 (maintainer request relaying a consumer's expectation, reopening B-129's question); B-463 filed 2026-10-23 at rank 2 (maintainer-requested bug hunt over the eleven scripts B-460 left untouched; captured, not fixed, at the maintainer's request), B-416 to B-461 each one rank down; B-464 filed 2026-10-24 at rank 2 (maintainer-requested bug hunt batch 3 over the maintainer tooling, the gates, the installers and the shipped wiring), B-463 to B-461 each one rank down, and narrowed the same day to three leftovers after its batch fixed or closed every other finding, with B-465 closed by decision (WSD-106); B-466 filed 2026-10-27 at rank 4 (maintainer request: whether the framework's lead over the bare agent grows with repository size, pre-registered the same day), B-451 to B-461 each one rank down; B-467 filed 2026-10-27 at rank 15 (maintainer request: the sub-agent context measurement read FILE), B-356 to B-461 each one rank down; B-468 filed 2026-10-27 at rank 28 (maintainer request: the test-level eval's skipped regression tests); B-469 filed 2026-10-28 at rank 29 (maintainer request, out of scope of the `-Reinstall` change); B-470 filed 2026-10-28 at rank 30 (maintainer request: a pre-registered UX-consistency probe, after a fresh-session attack on the proposal); B-470 closed by measurement 2026-10-31 (Copilot CLI after the Claude Code launch was refused: framework 6/6 and bare 6/6 mirrored the sibling)

| Rank | Item | Why here |
|---|---|---|
| 1 | B-416 | P1: the only route to whether 0.98.0's restated criteria and Option A/B designs are right and used, and it gates B-417 to B-419's shipping changes; needs the maintainer and the first consumer team |
| 2 | B-464 | Two leftovers of bug-hunt batch 3: the step-4 attack on the installer attack-fix diff, and D6's Copilot fallback line shipped unmeasured |
| 3 | B-463 | Bug-hunt batch 2, 26 findings captured in one plan: the guard's credential exemption is inert for any checkout under a test- or development-named folder (secret-leak class, executed), two quadratic guard regexes that outlast the hosts' hook timeouts, and two smaller guard items to decide; G2 and G3 done; guarded, step 4 |
| 4 | B-466 | Maintainer request: the first test of whether the framework's lead over the bare agent grows with repository size, the case for large legacy codebases; pre-registered, runner work and three generations before any run, at most 60 USD |
| 5 | B-451 | Field report: a 3,856-line committed baseline, one evidence row per file per claim, noisy to review and conflict-prone |
| 6 | B-452 | Field question: the baseline pins about 1,000 blob hashes, so any PR shows drift; decide and say whether it stays committed |
| 7 | B-425 | A plain-words review may dispatch no reviewer, and so skip B-418's contract step; blocked on B-416's review answer; guarded, about 3 USD and 3 premium requests to measure |
| 8 | B-348 | False-green class: its Copilot CLI half was measured 2026-10-11 (B-388, B-389); the VS Code half needs a maintainer-driven VS Code session, since nothing here drives VS Code's Copilot harness headlessly |
| 9 | B-417 | Improvement to 0.98.0's core: B-412 saw no downstream difference because prompt K states every outcome; about 10 USD |
| 10 | B-403 | Shipped unmeasured (WSD-111); Claude Code's first turn is seen (B-406, B-410), the underspecified and no-gap prompts and the Copilot arm are left |
| 11 | B-380 | Improvement: end-of-turn Boy Scout delivery on Copilot instead of the next-prompt queue, which B-377 saw still delivered on CLI 1.0.95 |
| 12 | B-420 | The fix path's restated criterion, unchanged since 0.97; about 8 USD; better after B-416's field answers |
| 13 | B-419 | Improvement with no field report; starts with a hand-read of the retained security passes |
| 14 | B-383 | Maintainer request reopening B-343: shipped descriptions use about 40-60% of the cap before consumer skills; no field report |
| 15 | B-467 | Measured, not field-raised: each `/review` reviewer carries the main agent's whole instruction chain, about 53% of its input; `omitClaudeMd` drops it, so what is left is which rules each reviewer needs |
| 16 | B-356 | Maintainer idea with no field report; its bullet shipped unmeasured (WSD-111), so the decoy's false-offer rate decides whether it stays |
| 17 | B-373 | Stall class, but only on a degenerate C# file; no field report |
| 18 | B-432 | Stall class, reasoned only: B-393's longer save paths on Windows PowerShell 5.1 without long-path support; nothing changes before it would throw |
| 19 | B-440 | Data-loss class, contrived: an ignored backup copy can be overwritten by a checkout of a branch that tracks the same backup path; guarded |
| 20 | B-453 | Field report: a zero-byte `.cs` sat in a claim's evidence; the baseline could name it instead of silently resting on it |
| 21 | B-455 | Field question: whether a semantic repository index is needed beyond the wiki index and Repository Structure; decide before building |
| 22 | B-459 | Consumer expectation, not a defect: no recipe for writing a reporting view or procedure; B-129's budget blocker is gone, its no-observed-error bar is not; decide before building |
| 23 | B-449 | Possible false green: a framework file written at a skip-worktree path never shows in `git status`, so committing the install leaves it out; guarded |
| 24 | B-374 | False-green class, but only for a focus indented with non-ASCII whitespace on a non-UTF-8 console; no field report |
| 25 | B-448 | Secret-leak class, tr-TR only: the Turkish-cased `APİ_KEY` passes the guard since B-445; guarded, step 4 |
| 26 | B-357 | Reaches only a consumer hosting on github.com; the field consumers host on Bitbucket Data Center (maintainer, 2026-10-11) |
| 27 | B-461 | Data-loss class, environment-only: a caller's `GIT_LITERAL_PATHSPECS` or `GIT_ICASE_PATHSPECS` changes what the installer's and review-scope's pathspecs match; guarded |
| 28 | B-468 | Measured, not field-raised: 2 of 26 plain bug fixes skipped the regression test, wrongly saying a SQLite test needs a new package; the agent said the fix was untested |
| 29 | B-469 | Maintainer request: an update's `.claude/framework-update-backup/` copies get forgotten and committed; `-Reinstall` already relies on the last commit instead; guarded |

## Open entries

### B-373 · The write guard's C# `[Ignore]` pattern scans quadratically on a long run of blank lines
**Filed against:** v0.94.0 (2026-10-09)
**Priority:** P3 · **Effort:** S · **Invariants:** #1
**Status:** Open; found by the fresh-session attack on B-372. `(?m)^\s*\[` lets `\s` span newlines, so a `.cs` write with 60k blank lines takes 2.5 s under
PowerShell 7 and one with 20k takes 4.7 s under Windows PowerShell 5.1, growing quadratically. B-372 gave the TypeScript patterns `^[^\S\r\n]*`; the same change
here needs its own red case and a step-4 review.

### B-374 · Hooks decode their stdin with the console's input code page, not as the UTF-8 the agents send
**Filed against:** v0.94.0 (2026-10-09)
**Priority:** P3 · **Effort:** S · **Invariants:** #1 #3 #7
**Status:** Open; found by B-372's CP437 leg. `guard.ps1`, `route-prompt.ps1`, `session-start.ps1` and `audit-trail.ps1` read stdin through `[Console]::In`, so
under code page 437 (and 850 and 1252, per the reviewing session) a `fit` indented with a no-break space (UTF-8 C2 A0) arrives mis-decoded and passes, on both
hosts, before B-372 and after it alike. Fix verified by that session: a UTF-8 `StreamReader` over `[Console]::OpenStandardInput()`, not `[Console]::InputEncoding` (it changes the user's console); red case: that row on the CP437 leg.

### B-348 · Measure whether the agent's own security pass on Copilot CLI and VS Code runs the project's skill or the host's built-in agent
**Filed against:** v0.92.0 (2026-10-04)
**Priority:** P2 · **Effort:** S to M to measure · **Invariants:** #1 #7
**Status:** Open for VS Code only. The Copilot CLI half was measured 2026-10-11 on CLI 1.0.95 (`meta/eval-results.md`, pre-registered at f00d3e1d; `meta/host-certification.md`):
the shipped wording reached the CLI's built-in agent (B-388), and, under the prompts' advance approval, the pass ran only when the per-prompt reminder fired (B-389). VS Code was not driven: 1.139.1 here has no headless chat (`code chat`
opens a window). Run Part A's T-K and P-B prompts in a maintainer-driven session on an installed fixture; design: `.claude/plans/2026-10-08-b348-b356-plan-v2.md` Part A.

### B-357 · Measure whether Copilot code review on github.com loads the `review` or `security-gate` skill wrapper, and what it posts
**Filed against:** v0.93.0 (2026-10-06)
**Priority:** P2 · **Effort:** S to M to measure · **Invariants:** #1 #7
**Status:** Open; found while shipping the unreleased 0.94.0 `.agents/skills/` wrappers, no field report. GitHub documents that Copilot code review uses
relevant repository skills automatically, review-named ones first; the wrapper runs `.claude/commands/review.md`, which needs `scripts/review-scope.ps1`.
Measure one PR on an installed fixture before changing the wrapper's model invocation, which Copilot CLI's by-name route to the framework's `/review` uses.

### B-356 · Measure a plan-step offer of a test, Conventions line or project-skill draft when a feature creates a repeatable operation
**Filed against:** v0.93.0 (2026-10-05)
**Priority:** P3 · **Effort:** M to measure, S to change · **Invariants:** #1 #7
**Status:** Open; raised by the maintainer 2026-10-05, no field report (WSD-109). The candidate bullet shipped unmeasured in carrier §2 (WSD-111).
Measure it (B-346 method): an extension-point feature, a third instance and a plain CRUD decoy whose false-offer rate decides whether it stays;
design: `.claude/plans/2026-10-08-b348-b356-plan-v2.md` Part B.

### B-380 · Measure an `agentStop` `decision: block` for the Boy Scout nudge on Copilot, replacing the next-prompt queue
**Filed against:** v0.94.0 (2026-10-11)
**Priority:** P3 · **Effort:** M · **Invariants:** #5 #7
**Status:** Open; maintainer request 2026-10-11; unblocked the same day by B-377, which saw the next-prompt queue still delivered on CLI 1.0.95 and `agentStop` fire in a `-p` run. The Copilot runtime documents
`{"decision":"block","reason":...}` on `agentStop` (at most 8 in a row, `stop_hook_active` on re-entry); VS Code's Local harness maps `agentStop` to `Stop` and needs the `hookSpecificOutput` form or exit 2. copilot-cli
issue #3894 (open, not primary) reports `agentStop` firing on subagent turns and stalling `/review`, so run `meta/canaries/agent-stop-delivery/` with the review fan-out before changing `boy-scout-check.ps1`.

### B-383 · Skill descriptions share a 15,000-character cap in VS Code's Copilot harness; measure the shipped and consumer load against it
**Filed against:** v0.94.0 (2026-10-11)
**Priority:** P3 · **Effort:** S · **Invariants:** #1 #7
**Status:** Open; maintainer request 2026-10-11, reopening B-343's question (closed by decision 2026-10-02 pending a field report). VS Code 1.139-1.141 cap skill descriptions in the Copilot
harness at 15,000 characters (`chat.copilot.skillCharBudget`, experimental; seen in source and the settings text, not the release notes; 30,000 on `main`), overflow undocumented. Shipped
`.claude/skills` plus `.agents/skills` descriptions total about 5.9k (angular), 8.1k (dotnet) and 8.9k (monorepo) before any other skill; state the cap, then decide on a validate-dist ceiling.

### B-403 · Measure whether the plan gate asks its tech-lead questions before it plans
**Filed against:** v0.96.0 (2026-10-14)
**Priority:** P3 · **Effort:** M · **Invariants:** #5
**Status:** Open; shipped unmeasured (WSD-111 precedent, plan `.claude/plans/2026-10-14-plan-gate-tech-lead-interview.md`). B-406 S1 shows Claude Code `-p` without the approval clause stops
before writing (12/12 T, 6/6 C); hand-read, the S1-C replies ask 3-5 questions with an assumption each 6/6 and post the plan in the same message 6/6. B-410's C-K leg 1 repeated it on HEAD: 28 questions, 27 with an assumption, the plan in the same message 6/6.
Still needed: an underspecified prompt and a no-gap prompt, and the Copilot CLI arm, where the host's own `-p` prompt says to proceed autonomously (B-348's RAIL result, `meta/host-certification.md`).

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
**Status:** Blocked on B-416's review answer (maintainer, 2026-10-19, on Fable's advice). `$railsReview` (`src/core/.claude/hooks/route-prompt.ps1:88`) is an inline checklist naming neither `/review` nor a reviewer, and carrier §1 has no Review bullet, so the reviewers and B-418's contract step run only when `/review` is typed or chosen; the field's VS Code Local harness (`meta/field-reports.md:174`) may run no hooks, so only the carrier reaches it.
Candidate: a §1 Review bullet plus `$railsReview` in `$railsSecurity`'s shape (run this repository's `review` skill, by name on Copilot CLI; a verdict given without reviewers says so); guarded (`hooks/**`), with the `rail-sync` pair in `scripts/validate-dist.ps1` re-recorded.
Measure T vs C on both CLIs on the retained B-412 tree, graded by a reviewer `Task` or `Skill review` plus `review-scope.ps1`: about 3 USD and 3 premium requests.

### B-432 · B-393's save paths may pass Windows PowerShell 5.1's 260-character limit without long-path support
**Filed against:** v0.98.1 (2026-10-19)
**Priority:** P3 · **Effort:** S · **Invariants:** #3
**Status:** Open; reasoned by B-393's fresh-session attack, not run (this host has LongPathsEnabled=1). Save paths are at least 39 characters longer than their originals, so on a 5.1 host without long paths a deep framework path may throw an uncaught `PathTooLongException` at planning time: a stall, before any change.
Candidate: catch it and refuse with a line naming the path and the setting; red case on a synthetic deep path. Guarded.

### B-440 · An ignored backup copy, the only copy of a skip-worktree file's local content, can be overwritten by a checkout
**Filed against:** v0.98.1 (2026-10-20)
**Priority:** P3 · **Effort:** S · **Invariants:** #7
**Status:** Open; found by B-429's fourth fresh-session attack (`N5checkout`, executed on pwsh), caused by WSD-117's blanket keep-out. Git treats an ignored file as expendable, so `git checkout` of a branch that tracks the same backup path overwrote the saved copy silently (exit 0), where an untracked, unignored file would have stopped the checkout. Contrived: it needs a branch that commits that backup path. Candidate: name such copies in the update's NOTICE so the team moves them out first. Guarded (`install.ps1`).

### B-448 · Under tr-TR the guard now passes the Turkish-cased `APİ_KEY` it used to block
**Filed against:** v0.98.1 (2026-10-20)
**Priority:** P3 · **Effort:** S · **Invariants:** #3
**Status:** Open; found by B-445's fresh-session attack (executed, both hosts and surfaces). B-445 made the guard's patterns culture-invariant, so `APİ_KEY` (U+0130, what tr-TR uppercasing of `api_key` gives) no longer matches `I`; the old culture-sensitive match blocked it under tr-TR. Candidate: accept U+0130 where a pattern has `i` (`[iİ]`); red case under tr-TR. Guarded, `guard.ps1` on step 4's list.
### B-449 · A framework file an install writes at a skip-worktree path never shows in git status, so its commit leaves it out
**Filed against:** v0.98.1 (2026-10-20)
**Priority:** P3 · **Effort:** S · **Invariants:** #7
**Status:** Open; found by B-435's implementation, reasoned, not run. A brownfield install archives a tracked original marked skip-worktree or assume-unchanged and writes the framework's file at its path, but Git does not look there, so "commit the copied files" keeps the team's committed version and teammates never get the framework's. Candidate: name such paths in the handoff, as B-313 names ignored ones; red case first. Guarded (`install.ps1`).

### B-451 · The committed rebootstrap baseline repeats one evidence row per matched file per claim, so it runs to thousands of lines
**Filed against:** v0.98.2 (2026-10-21)
**Priority:** P2 · **Effort:** M · **Invariants:** #1 #7
**Status:** Open; field report 2026-10-21 (item 2): a 3,856-line `.claude/bootstrap-baseline.tsv` where dozens of claims each list the same full file-and-hash set, noisy to review and prone to merge conflicts.
`bootstrap-baseline.ps1` writes `evidence <id> <pattern> <path> <blob>` per matched file at Record and compares per path at Impact. Candidates: one row per pattern with a hash of its matched set (as `Get-Areas`
already does per area; schema bump, Impact must still name the changed path), and shipped `.gitattributes` lines (`-diff`, `linguist-generated`) so review tooling collapses it. `BootstrapBaseline.Tests.ps1` red case first; B-452 decides whether it stays committed. Direction: `.claude/plans/2026-10-21-field-report-10-b450-b455.md` (field report #10).

### B-452 · Decide whether the rebootstrap baseline stays committed, and say that drift on any source change is by design
**Filed against:** v0.98.2 (2026-10-21)
**Priority:** P2 · **Effort:** S · **Invariants:** #7
**Status:** Open; field question 2026-10-21 (item 3): the baseline pins blob hashes of about 1,000 files, so almost any unrelated PR makes `/rebootstrap` report drift, and the team asks whether it is meant to be
committed rather than generated locally or in CI. It is committed on purpose (0.90.0 CHANGELOG: "commit it with the other artifacts"): it records the last run's state for every clone, and drift is the signal, not a defect; an ignored
local file makes each teammate's first run full. Record that as a WSD, state it in `rebootstrap.md` and the CHANGELOG in the consumer's voice, and check the line-ending half: `git hash-object --stdin-paths` applies the clean filter, so `core.autocrlf` should not move a hash; one test case over a CRLF checkout. Direction: `.claude/plans/2026-10-21-field-report-10-b450-b455.md` (field report #10).

### B-453 · The baseline records a zero-byte source file as evidence without saying so
**Filed against:** v0.98.2 (2026-10-21)
**Priority:** P3 · **Effort:** S · **Invariants:** #1
**Status:** Open; field report 2026-10-21 (item 4): a `.cs` carrying the empty-blob hash (`e69de29b…`) sat in a claim's evidence list, a stray 0-byte file the team noticed only through the baseline, beside files
already in `TECH_DEBT.md`. Record resolves a glob to every matched file, so an empty one supports a claim it cannot evidence. Candidate: `-Mode Record` prints one `EMPTY <path>` line per zero-byte match and
`/bootstrap` 3f routes it to `TECH_DEBT.md` rather than the baseline; `BootstrapBaseline.Tests.ps1` red case first. Direction: `.claude/plans/2026-10-21-field-report-10-b450-b455.md` (field report #10).

### B-455 · Decide whether the framework needs a semantic repository index beyond the wiki index and Repository Structure
**Filed against:** v0.98.2 (2026-10-21)
**Priority:** P3 · **Effort:** S to decide, M to build · **Invariants:** #7
**Status:** Open; field question 2026-10-21 (item 6). Shipped today: `AGENTS.md > Repository Structure` (directories, entry points, where each change goes), `docs/wiki/INDEX.md` (scoped claims),
`docs/architecture-decisions.md`, and `docs/warehouse-map.md` on demand; no symbol or module index, and each host brings its own search (Claude Code's tools, Copilot's workspace index). Answer by WSD: what one
consumer task in a bootstrapped repository fails to find with those, measured before anything is built; if nothing, close by decision and answer the team in the CHANGELOG or `docs/reference.md`. Direction: `.claude/plans/2026-10-21-field-report-10-b450-b455.md` (field report #10).

### B-459 · Reopen B-129: a write-side recipe for warehouse reporting views and procedures
**Filed against:** v0.98.2 (2026-10-23)
**Priority:** P3 · **Effort:** S to decide, M to build · **Invariants:** #1 #7
**Status:** Open; maintainer request 2026-10-23, relaying a consumer's expectation that `/map-warehouse` would bring skills for adding facts, dimensions, reporting procedures and Power BI reports. Facts and dimensions are `add-warehouse-load`'s; reporting views and procedures have no write-side recipe, only `map-warehouse`'s read-side Querying rules.
B-129 shipped nothing on 2026-08-31 for three reasons: 473 (dotnet) and 116 (monorepo) characters of static headroom, two paid probes voided by the spend limit, and no framework-caused publication error observed — see `meta/BACKLOG-DONE.md`. The first is gone: `scripts/context-footprint.ps1 -Check` on 2026-10-23 left 5,908 (dotnet) and 10,263 (monorepo).
The third still holds, so decide first whether a consumer's expectation clears B-129's reopen bar; if it does, start from B-129's bounded section in the `map-warehouse` body. Power BI authoring stays out of scope (B-129's proportionality).

### B-461 · The installer and review-scope let a caller's `GIT_*_PATHSPECS` change what their pathspecs match
**Filed against:** v0.98.2 (2026-10-23)
**Priority:** P3 · **Effort:** S · **Invariants:** #1 #3
**Status:** Open; found by the fresh-session attack on the adoption-archive `:(literal)` fix, which now clears `GIT_LITERAL_PATHSPECS`, `GIT_GLOB_PATHSPECS`,
`GIT_NOGLOB_PATHSPECS` and `GIT_ICASE_PATHSPECS` for its own git calls. `src/core/scripts/install.ps1` (its `:(literal)` calls; its GIT_DIR-family refusal at ~243, ~638, ~871)
and `review-scope.ps1` (~142, ~193-195, ~233-235, ~264) do not, so with `GIT_LITERAL_PATHSPECS=1` set a `:(literal)` path matches nothing. Red case: that variable set around one update.

### B-463 · Bug-hunt batch 2: 26 findings over the eleven scripts B-460 left untouched; G2 and G3 fixed, G1 open
**Filed against:** v0.98.2 (2026-10-23)
**Priority:** P2 · **Effort:** M (three sessions) · **Invariants:** #1 #3 #5 #7
**Status:** Open; G3 landed 2026-10-31 (items 1 to 12 and 14 to 16 fixed red first, item 13 closed by decision in `meta/BACKLOG-DONE.md`); G2 done 2026-10-31 (items 7 to 11 fixed red first, item 9 red on 5.1 only); G1 remains open. Hunt: three audit sessions, every finding executed on pwsh and 5.1 unless the plan says PLAUSIBLE.
Plan `.claude/plans/2026-10-23-bug-hunt-2-b463.md` holds every finding with its `path:line`, repro, fix and red case, in three groups: G1 `guard.ps1` (step 4; the credential exemption reads the absolute path, so `C:\Projects\test\repo` or `D:\Development\repo` disables it), G2 `audit-trail.ps1` and `session-start.ps1` (done), G3 the seven ordinary scripts (done).
Adjacent, outside the batch: `src/core/scripts/template-checks.ps1` has the same `Set-Location` without `-LiteralPath` as G3 item 2 and dies at a repository path containing `[`; `test-weakening-scan.ps1` (:25, :32, :77) still tests the bare `ReparsePoint` attribute, which B-464 C4 replaced in four other scripts and G3 in `warehouse-map-check.ps1`, so a OneDrive folder reads as a link there; session-start's debt-heat `git log --name-only` lacks `core.quotepath=off`, so a non-ASCII path never matches `TECH_DEBT.md`.

### B-464 · Bug-hunt batch 3: three leftovers of the 2026-10-24 batch
**Filed against:** v0.98.2 (2026-10-24)
**Priority:** P2 · **Effort:** S · **Invariants:** #1 #7
**Status:** Open, narrowed 2026-10-31; plan `.claude/plans/2026-10-24-bug-hunt-3-b464.md`. (1) Step 4 for the installer commit that fixed the fresh-session attack's findings on C5 (a greenfield stopped late re-ran as brownfield; the re-run line dropped override flags) ran no second attack: per WSD-116 a fresh session attacks that diff.
(2) D6's line under the four `@.claude/workflow.md` imports shipped unmeasured (WSD-111): one Copilot CLI `/fix` run graded on the calibration line, premium requests. Leftover (3), a release resume past an index-flagged change, done 2026-10-31: release.ps1 refuses any assume-unchanged or skip-worktree entry before `add -A`.

### B-466 · Measure whether the framework's lead over the bare agent grows with repository size
**Filed against:** v0.98.2 (2026-10-27)
**Priority:** P2 · **Effort:** M · **Invariants:** none
**Status:** Open (maintainer, 2026-10-27): tests the hypothesis that the framework earns its cost in large legacy codebases; every framework-against-bare comparison so far ran on a few to 499 files.
Pre-registered in `meta/eval-results.md` (B-466 pre-registration): `warehouse-route-p4` at about 14, 500 and 5,000 SQL files, framework against bare, n = 6, with the prediction written down.
Before any run, an amendment freezes the sized fixture and per-run cap in the runner, three generated overlays, checks I1 to I3, and the maintainer's approval of the 60 USD stop.

### B-467 · Each `/review` reviewer sub-agent carries the main agent's whole instruction chain
**Filed against:** v0.98.2 (2026-10-27)
**Priority:** P3 · **Effort:** S · **Invariants:** #2
**Status:** Open (maintainer request; `meta/eval-results.md`, "Sub-agent context results", read FILE): Claude Code injects the consumer `CLAUDE.md`, `AGENTS.md` and the rules carrier, 25,805 chars, about 9,100 tokens, into all six reviewers: about 53% of their pooled input at that ratio.
Step 1 done 2026-10-28: the frontmatter field `omitClaudeMd: true` (Claude Code 2.1.271+) drops it; on 2.1.312 a probe agent's first request fell from 11,782 to 2,656 tokens with it, and kept the chain without it (0.01 USD).
Left: which reviewers need which rules (convention-check already Reads `AGENTS.md`; the others would need them restated in the dispatch prompt), then a red-first `/review` comparison before shipping.

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
Replace each save with the commit id and `git show`/`git checkout` lines, keeping a save only where the copied bytes are not in HEAD (ignored or skip-worktree files).
