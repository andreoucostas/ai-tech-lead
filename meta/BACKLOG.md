# Framework backlog

Open work only, at most 40 entries (`AGENTS.md`, "Records"). Take the first unblocked row of the
pick-up order, one item per fresh session; the tier is read off the changed paths at work time. An
entry is its heading, filed-against line, priority line and at most three lines of status; the
evidence lives in the plans and decisions it names. An empty backlog says "No open entries." on its
own line under Open entries; the hygiene tests refuse that line beside an entry. A session that
finds an adjacent defect outside AGENTS.md's four guarded harms, which no field report raised,
closes it per WSD-106 with one CLOSED line in `meta/BACKLOG-DONE.md` instead of filing it here.
Full pre-reset text: `git show 36babcaf:meta/BACKLOG.md`.

## Pick-up order — ranked 2026-09-30 (WSD-105 probe); re-ranked 2026-10-01 (WSD-107, field replies); B-331 to the idle queue 2026-10-02 (WSD-109); B-346 filed and done the same day; B-330 done and B-336 closed by measurement 2026-10-03; B-331 done, B-326 done and B-348 filed, and B-327, B-328, B-329 and B-337 done 2026-10-04; B-352 to B-354 filed 2026-10-05 (Fable review, consumer host reply), B-352 and B-354 done the same day (WSD-110), B-353 done the same day, B-356 filed the same day (maintainer request; first numbered B-355 at 254c904f, renumbered because 99253721 closed a different B-355); B-357 filed 2026-10-06 (the 0.94.0 Copilot skill wrappers); B-359 and B-360 filed 2026-10-07 (attack rounds on those wrappers); B-348's and B-356's wordings shipped unmeasured 2026-10-08 (WSD-111), their measurements kept open; B-361 and B-362 done 2026-10-09 without filing (field report #9), B-363 to B-366 closed by decision the same day (WSD-106); re-ranked 2026-10-09: B-367 filed at rank 1 (maintainer request, Angular v21-v22 audit) and B-368 done the same day, B-369 and B-370 closed by decision (WSD-106) and B-371 filed the same day (a reviewing session's build.ps1 run); B-372 done and B-373 and B-374 filed the same day (audit batch 2, its fresh-session attack and its CP437 leg); B-375 filed and done 2026-10-10 and B-376 2026-10-11 (audit batches 3 and 4); re-ranked 2026-10-11: B-377 to B-382 filed (maintainer request, review of the VS Code 1.132-1.141 and Copilot CLI 1.0.80-1.0.95 releases) and B-357 to the bottom (consumers host on Bitbucket Data Center, so Copilot code review on github.com never sees their PRs), then B-348 widened to VS Code and B-383 and B-384 filed the same day (maintainer request); B-386 and B-387 filed and done the same day (audit batches 5a and 5b), and B-367 done the same day (audit batch 6, the last); B-377 closed by measurement the same day (Copilot CLI 1.0.95 still delivers the prompt hook's context), unblocking B-380; B-384 closed by measurement the same day (on CLI 1.0.95 the eval runner's hook opt-in still loads hooks, and `-p` still passes slash commands to the model as text); B-348's Copilot CLI half measured the same day (pre-registered at f00d3e1d: the shipped wording reached the CLI's built-in agent in 3 of 6 refund runs), with B-388 and B-389 filed after it and B-390 closed by decision (WSD-106); B-389 done the same day (pre-registered at 04548f59: without the advance approval the always-loaded rule alone got a pass in 4 of 4 runs, and with `route-prompt`'s reminder firing in 4 of 4, so the approval suppressed the rule and the sensitive pattern was widened), with B-391 filed from its fresh-session attack; B-388 done the same day (pre-registered at ac9bef70: the skill renamed `security-gate`, WSD-114, after which the refund prompt ran this framework's review in 6 of 6 runs), with B-392 filed the same day (maintainer report, eval case angular-003) and B-393 from its fresh-session attack; B-378's documentation shipped 2026-10-12 and its entry narrowed to its VS Code canary (pre-registered at 93844fb8: the runtime VS Code 1.139.1 bundles ran both hook files), with B-394 closed by decision (WSD-106); B-379 done the same day (pre-registered at e5c35e72), with B-395 filed at rank 1 (its canary: gpt-6.1-sol wrote a key-shaped value through `apply_patch`, which the guard does not read) and B-396 at rank 4 (the hooks in the CLI's local sandbox); B-395 done 2026-10-14 (pre-registered at 1adbe21a: the fixed guard blocked gpt-6.1-sol's `apply_patch` canary 3 of 3 on the CLI and 1 of 1 on the bundled runtime), with B-397 filed after it; B-398 filed and done the same day (maintainer report; pre-registered at 2c2b6e7e: 0.95.0's `model: sonnet` stopped `/bootstrap`'s worker on Copilot CLI), with B-399 filed at rank 2; B-400 and B-401 filed and done the same day (maintainer request; pre-registered at 06c7ab75), with B-402 filed after B-401; B-371 done 2026-10-15 and B-399 blocked the same day (Copilot access ended), and B-397 done the same day; re-ranked 2026-10-19 (maintainer request): B-418 done and B-422 filed from it, B-403, B-404, B-414, B-416, B-417, B-419, B-420 and B-422 ranked, B-399 unblocked (Copilot access restored: B-414b, B-421 and B-421b ran on CLI 1.0.98), B-414 narrowed by B-421b, and B-393 raised (data-loss class); B-422 done and B-423 filed from it 2026-10-19, and B-423 done the same day; B-399 closed by measurement the same day (CLI 1.0.98 ran the three `model: haiku` reviewers through their model-less wrappers on the session's model); B-425 filed at rank 2 and B-426 closed by decision the same day (Fable's advice on when the reviewers run, maintainer decision), and B-427 filed at rank 11 (maintainer request, reopening B-424's question); B-414c measured the same day (pre-registered at b6917f46: in a bootstrapped repository Copilot red-first 0/6 on both prompts, Claude Code 6/6, so B-414 stays open), with B-428 closed by decision (WSD-106); B-393 done the same day for 0.98.2, its fresh-session attack filing B-429 to B-432 (older defects in the same installer) with B-429 at rank 2; B-396 closed by measurement the same day (pre-registered at aeb06a6e: not reproduced on CLI 1.0.98 or 1.0.95; attributed cause a host without the sandbox's filesystem enumeration), with B-433 filed at its rank; B-429 done the same day for 0.98.2, with B-434 and B-435 filed from its implementation (two reasoned leaks); B-434 then fixed within B-429's hardening after its first fresh-session attack executed it; B-433 done the same day for 0.98.2; idle queue added 2026-09-30 (WSD-106); every earlier entry closed 2026-09-29 (WSD-105)

| Rank | Item | Why here |
|---|---|---|
| 1 | B-416 | P1: the only route to whether 0.98.0's restated criteria and Option A/B designs are right and used, and it gates B-417 to B-419's shipping changes; needs the maintainer and the first consumer team |
| 2 | B-430 | Data-loss and secret-leak class, executed twice: disabling a framework skill deletes a team skill at its path (left only in Git HEAD) and moves an ignored local file to a committable path; guarded |
| 3 | B-441 | Secret-leak class, executed: a brownfield install archives and replaces a team's own `.claude/.gitignore`, so the local files it ignored show as committable; guarded |
| 4 | B-425 | A plain-words review may dispatch no reviewer, and so skip B-418's contract step; blocked on B-416's review answer; guarded, about 3 USD and 3 premium requests to measure |
| 5 | B-414 | Copilot red-first in a bootstrapped repository, every consumer's steady state, is 0/6 on both prompts (B-414c); its next lever, C past `/bootstrap`, is guarded and the maintainer's decision |
| 6 | B-348 | False-green class: its Copilot CLI half was measured 2026-10-11 (B-388, B-389); the VS Code half needs a maintainer-driven VS Code session, since nothing here drives VS Code's Copilot harness headlessly |
| 7 | B-378 | The guard's deny on VS Code's Copilot harness, which 1.141 is making the default for enterprise users, is documented but not observed; it needs a maintainer-driven VS Code session |
| 8 | B-435 | Secret-leak class, reasoned only: the brownfield archive still asks only `check-ignore`, so a skip-worktree original lands committable; guarded |
| 9 | B-417 | Improvement to 0.98.0's core: B-412 saw no downstream difference because prompt K states every outcome; about 10 USD |
| 10 | B-403 | Shipped unmeasured (WSD-111); Claude Code's first turn is seen (B-406, B-410), the underspecified and no-gap prompts and the Copilot arm are left |
| 11 | B-380 | Improvement: end-of-turn Boy Scout delivery on Copilot instead of the next-prompt queue, which B-377 saw still delivered on CLI 1.0.95 |
| 12 | B-404 | Consumer-docs polish: every miss asked before committing, under Claude Code's own commit rule; decide the gate's scoring first |
| 13 | B-420 | The fix path's restated criterion, unchanged since 0.97; about 8 USD; better after B-416's field answers |
| 14 | B-419 | Improvement with no field report; starts with a hand-read of the retained security passes |
| 15 | B-383 | Maintainer request reopening B-343: shipped descriptions use about 40-60% of the cap before consumer skills; no field report |
| 16 | B-356 | Maintainer idea with no field report; its bullet shipped unmeasured (WSD-111), so the decoy's false-offer rate decides whether it stays |
| 17 | B-359 | Latent false green: no shipped command carries such a value today |
| 18 | B-360 | CI already stops it at checkout; a local check only moves the stop earlier |
| 19 | B-373 | Stall class, but only on a degenerate C# file; no field report |
| 20 | B-432 | Stall class, reasoned only: B-393's longer save paths on Windows PowerShell 5.1 without long-path support; nothing changes before it would throw |
| 21 | B-440 | Data-loss class, contrived: an ignored backup copy can be overwritten by a checkout of a branch that tracks the same backup path; guarded |
| 22 | B-374 | False-green class, but only for a focus indented with non-ASCII whitespace on a non-UTF-8 console; no field report |
| 23 | B-445 | Secret-leak class, but only under a Turkish culture: the guard's `(?i)` credential check lets `API_KEY = "..."` through under tr-TR on both hosts; guarded, step 4 |
| 24 | B-392 | Maintainer report, decided 2026-10-11 (the shipped rule wins); a shipped eval case fails a rule-compliant answer, no runtime harm |
| 25 | B-357 | Reaches only a consumer hosting on github.com; the field consumers host on Bitbucket Data Center (maintainer, 2026-10-11) |

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

### B-392 · Eval case angular-003 fails the `takeUntilDestroyed()` swap that the shipped Feature rail and Boy Scout rule ask for
**Filed against:** v0.94.0 (2026-10-11)
**Priority:** P3 · **Effort:** S · **Invariants:** #1 #7
**Status:** Open; maintainer report 2026-10-11, decided the same day: the shipped rule wins, so the case accepts the swap instead of failing it. `tests/evals/cases.yaml` (angular, monorepo; reworded in b5eb284f)
asks for a feature and fails an answer that changes the component's `ngOnDestroy` cleanup, but the Feature rail ("Apply Boy Scout to every file you touch") and Boy Scout always-apply Add item 1 (item 5 in the
monorepo) say to replace that cleanup with `takeUntilDestroyed()`, so a framework-compliant agent fails the case. Predates b5eb284f (since 663ae91a).

### B-357 · Measure whether Copilot code review on github.com loads the `review` or `security-gate` skill wrapper, and what it posts
**Filed against:** v0.93.0 (2026-10-06)
**Priority:** P2 · **Effort:** S to M to measure · **Invariants:** #1 #7
**Status:** Open; found while shipping the unreleased 0.94.0 `.agents/skills/` wrappers, no field report. GitHub documents that Copilot code review uses
relevant repository skills automatically, review-named ones first; the wrapper runs `.claude/commands/review.md`, which needs `scripts/review-scope.ps1`.
Measure one PR on an installed fixture before changing the wrapper's model invocation, which Copilot CLI's by-name route to the framework's `/review` uses.

### B-359 · validate-dist check 15 passes frontmatter values that Copilot CLI 1.0.92 refuses
**Filed against:** v0.93.0 (2026-10-07)
**Priority:** P3 · **Effort:** S · **Invariants:** #1
**Status:** Open; latent, found by the fourth attack round on the unreleased 0.94.0 wrappers. Copilot refuses an unquoted `argument-hint: [...]` ("must be
a string"), a non-boolean `disable-model-invocation` and an unquoted value holding `: `, and since a wrapper copies its command's frontmatter, /name then
loads nowhere; check 15 checks keys, delimiters and descriptions only. Every shipped command quotes these values today.

### B-360 · No local gate refuses a tracked path that Windows cannot check out
**Filed against:** v0.93.0 (2026-10-07)
**Priority:** P3 · **Effort:** S · **Invariants:** #3
**Status:** Open; found by the fifth attack round on the unreleased 0.94.0 wrappers. An empty root file named `*.bodydiff` rode in a commit whose
local gates were all green, and every Windows CI job failed at checkout. Candidate: RepositoryPrivacy or DocTruth refuses a tracked path holding
`* ? " < > | :` or a reserved device name.

### B-356 · Measure a plan-step offer of a test, Conventions line or project-skill draft when a feature creates a repeatable operation
**Filed against:** v0.93.0 (2026-10-05)
**Priority:** P3 · **Effort:** M to measure, S to change · **Invariants:** #1 #7
**Status:** Open; raised by the maintainer 2026-10-05, no field report (WSD-109). The candidate bullet shipped unmeasured in carrier §2 (WSD-111).
Measure it (B-346 method): an extension-point feature, a third instance and a plain CRUD decoy whose false-offer rate decides whether it stays;
design: `.claude/plans/2026-10-08-b348-b356-plan-v2.md` Part B.

### B-378 · Observe the write guard's deny in VS Code's Copilot harness itself
**Filed against:** v0.94.0 (2026-10-11)
**Priority:** P2 · **Effort:** S to measure · **Invariants:** #5 #7
**Status:** Open for its canary only; maintainer request 2026-10-11. The matrix's VS Code column became Copilot and Local harness columns and the `chat.useClaudeHooks` advice was dropped on 2026-10-12;
the runtime VS Code 1.139.1 bundles, driven headlessly (pre-registered at 93844fb8), ran both hook files and denied every tool on an erroring `preToolUse`, but claude-sonnet-5 declined the key-shaped
canary write 2 of 2. Left: a guard deny in a maintainer-driven Copilot-harness session on an installed fixture, with VS Code's own hook callbacks and client tools, and a prompt the model attempts.

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

### B-404 · An installing agent given "install this" sometimes asks before committing
**Filed against:** v0.97.2 (2026-10-15)
**Priority:** P3 · **Effort:** S · **Invariants:** none
**Status:** Open; consumer-docs arms in `meta/eval-results.md`: URL-install commits B 6/6, A 4/6, A2 3/6, A3 5/6; every miss asked first, under Claude Code's
commit-only-when-asked rule, and pushing wording read as injection. The README now suggests a prompt that asks for the commit; measure that prompt (a
scenario variant), and decide whether the gate should count "asked before committing" as a pass.

### B-414 · Copilot CLI agents fix first and run the test after: red-first is 1 of 3 and 0 of 3 with the full carrier
**Filed against:** v0.97.2 (2026-10-18)
**Priority:** P2 · **Effort:** M to measure · **Invariants:** #5
**Status:** Open; found in B-411 (Copilot red-first 1/3). B-421 and B-421b: with A (43d44030) and the unbootstrapped session-start list C (cf0b9159), Copilot went red first 6/6 on `route-fix`. B-414c (`meta/eval-results.md`), the steady state (bootstrapped, `AGENTS.md` records the test command, C silent): Copilot CLI 1.0.98 `claude-sonnet-5.5` red-first 0/6 on `route-fix` and 0/6 on `route-fix-nl`, Claude Code 6/6.
Every Copilot run sent its first test run in one turn with the edit; the CLI ran both at once and the edit finished first (12 of 12).
Next lever, the maintainer's decision (guarded, pre-register first): C past `/bootstrap`, a session-start line naming the recorded test command, to run it alone and see it fail before any edit.

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

### B-430 · A team's own skill at a disabled framework skill's path is deleted on update, left only in Git HEAD
**Filed against:** v0.98.1 (2026-10-19)
**Priority:** P2 · **Effort:** S · **Invariants:** #7
**Status:** Open; found by B-393's fresh-session attack, executed, predating it. With `## Disabled framework skill: perf` in `LEARNINGS.md` and the team's own committed `.claude/skills/perf/SKILL.md` (the skill-backup folder already present), the update planned `create .claude/disabled-skills/perf/SKILL.md` and `delete .claude/skills/perf`.
Afterwards the team's text existed only in Git HEAD; gone if it had been ignored (reasoned). `.claude/disabled-skills/**` paths are never in a manifest, yet are replaced without B-393's save. Candidate: B-393's save before that delete and that write; red case: that fixture. Guarded.
Also executed by B-429's attack (secret-leak class): disabling `create-adr` moved a developer's ignored `.claude/skills/create-adr/local.env` to `.claude/disabled-skills/create-adr/local.env`, which Git then showed as `??`; the original was gone, and the kept-out line counted only the backup copy.

### B-432 · B-393's save paths may pass Windows PowerShell 5.1's 260-character limit without long-path support
**Filed against:** v0.98.1 (2026-10-19)
**Priority:** P3 · **Effort:** S · **Invariants:** #3
**Status:** Open; reasoned by B-393's fresh-session attack, not run (this host has LongPathsEnabled=1). Save paths are at least 39 characters longer than their originals, so on a 5.1 host without long paths a deep framework path may throw an uncaught `PathTooLongException` at planning time: a stall, before any change.
Candidate: catch it and refuse with a line naming the path and the setting; red case on a synthetic deep path. Guarded.

### B-435 · `docs/pre-adoption` archives ask only `git check-ignore`, so a skip-worktree original archived there stays committable
**Filed against:** v0.98.1 (2026-10-19)
**Priority:** P3 · **Effort:** S · **Invariants:** #7
**Status:** Open; reasoned by B-429's implementation, not run. B-429 keeps a saved copy out of Git when the original is tracked but marked skip-worktree or assume-unchanged (`ls-files -v`); the brownfield archive path still decides by `check-ignore` alone, which never reports tracked files, so such an original's local content lands in a committable archive.
Candidate: the same `-OrSkipped` check on the archive's keep-out; red case first. Guarded (`install.ps1` / `adoption-archive.ps1`; step 4).

### B-440 · An ignored backup copy, the only copy of a skip-worktree file's local content, can be overwritten by a checkout
**Filed against:** v0.98.1 (2026-10-20)
**Priority:** P3 · **Effort:** S · **Invariants:** #7
**Status:** Open; found by B-429's fourth fresh-session attack (`N5checkout`, executed on pwsh), caused by WSD-117's blanket keep-out. Git treats an ignored file as expendable, so `git checkout` of a branch that tracks the same backup path overwrote the saved copy silently (exit 0), where an untracked, unignored file would have stopped the checkout. Contrived: it needs a branch that commits that backup path. Candidate: name such copies in the update's NOTICE so the team moves them out first. Guarded (`install.ps1`).

### B-445 · Under tr-TR the guard's case-insensitive credential check lets `API_KEY = "..."` through
**Filed against:** v0.98.1 (2026-10-20)
**Priority:** P3 · **Effort:** S · **Invariants:** #3
**Status:** Open; found by B-391's hook audit, executed on both hosts: `guard.ps1`'s `(?i)` credential pattern follows the current culture, where `I` folds to dotless `ı`, so `API_KEY = "..."` passes under tr-TR. Not a one-call fix: the patterns need culture-invariant matching (`RegexOptions.CultureInvariant`, or an invariant-culture scope around the checks); red case under tr-TR first. Guarded, `guard.ps1` on step 4's list.

### B-441 · A brownfield install archives and replaces a team's own `.claude/.gitignore`, so the local files it ignored become committable
**Filed against:** v0.98.1 (2026-10-20)
**Priority:** P2 · **Effort:** S · **Invariants:** #7
**Status:** Open; found by B-431's implementation, executed on pwsh, predating it. A repository whose committed `.claude/.gitignore` holds `mcp.local.json`, with an ignored `.claude/mcp.local.json`, installs brownfield: the file moves to `docs/pre-adoption/.claude/.gitignore`, the framework's replaces it, and Git shows `?? .claude/mcp.local.json` while the handoff says to commit the copied files.
B-431 keeps such files ignored on update only: brownfield archives the file for `/adopt` to merge, and B-313's case pins the replaced rule. Candidate: B-431's anchored lines for files Git ignored before, on a brownfield install too; red case: that fixture. Guarded (`install.ps1`; step 4).
