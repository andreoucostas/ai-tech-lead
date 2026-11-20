# Framework backlog

Open work only, with no cap on entries (`AGENTS.md`, "Records"; WSD-124). Take unblocked rows of the
pick-up order from the top; a session may take several; the tier is read off the changed paths at
work time. A self-found or attack finding inside AGENTS.md's four guarded harms stays here only with a
trigger ordinary use executes, a possible secret leak included (WSD-124, WSD-125). An
entry is its heading, filed-against line, priority line and at most three lines of status; the
evidence lives in the plans and decisions it names. An empty backlog says "No open entries." on its
own line under Open entries; the hygiene tests refuse that line beside an entry. A session that
finds an adjacent defect outside AGENTS.md's four guarded harms, which no field report raised,
closes it per WSD-106 with one CLOSED line in `meta/BACKLOG-DONE.md` instead of filing it here.
Full pre-reset text: `git show 36babcaf:meta/BACKLOG.md`.

## Pick-up order — re-ranked 2026-11-14 (maintainer, in chat; WSD-124, WSD-125): the architecture review filed as B-506 to B-513, then B-514 to B-520, with the project-skills work ranked after B-506 and B-507 (now ranks 4 and 5), eight findings shut, and the release review's B-521 and B-522; B-509 and B-498 done the same day, B-507 and B-513 on 2026-11-15, B-466 moved after B-515 (maintainer, in chat) and done the same day, B-514 done the same day, B-515 and B-517 closed the same day (maintainer, in chat), B-523 closed the same day after two NO-SHIP measurements (maintainer, in chat), and B-523 filed and placed after B-466 by the coordinator (the maintainer set no rank); B-521 closed 2026-11-16; B-524 to B-527 filed 2026-11-15 from the maintainer-requested review against current Anthropic guidance and placed last by the reviewing session (the maintainer set no rank); B-528 filed 2026-11-16 from field report #14 and put at rank 1 the same day (maintainer, in chat), the rows below one rank down; B-510 done 2026-11-16; B-469 done 2026-11-16; B-493 done 2026-11-16; B-491 done 2026-11-17; B-484 done 2026-11-17; B-496 done 2026-11-17; B-511 done 2026-11-17; B-489 done 2026-11-17; B-529 filed 2026-11-17 by the maintainer in chat, placed last by the coordinator (the maintainer set no rank); B-528 closed 2026-11-18 as not reproduced (maintainer, in chat); B-416's review decision taken 2026-11-19 (maintainer, in chat; WSD-131), B-425 folded into B-530, which takes its rank, and B-490 and B-504 decided the same day (WSD-132, WSD-133); B-531 to B-533 filed 2026-11-19 by the maintainer in chat, to follow B-416's measurement, placed last by the filing session (the maintainer set no rank); B-534 filed 2026-11-19 from the maintainer's chat request and placed last by the filing session (the maintainer set no rank); B-522 done 2026-11-19; B-502 done 2026-11-19; B-534 closed 2026-11-19 as NO-SHIP (maintainer, in chat); B-416 done 2026-11-19, the rows below one rank up; B-520 closed 2026-11-19 (maintainer, in chat; WSD-139), the rows below one rank up; B-532 and B-533 closed 2026-11-19 (maintainer, in chat) and B-535 and B-536 filed from their reports and placed last by the filing session (the maintainer set no rank), taking ranks 22 and 23; B-537 filed 2026-11-19 from the maintainer's chat request and field report #15 and put at rank 1 the same day (maintainer, in chat), the rows below one rank down; B-536 done 2026-11-20, B-538 one rank up; B-483 done 2026-11-20, the rows below one rank up; B-539 filed 2026-11-20 from field report #16 and placed last by the filing session (the maintainer set no rank); B-540 and B-541 filed 2026-11-20 from field report #15 and the maintainer's chat request ("yes on the filing") and placed last by the filing session (the maintainer set no rank); B-525 done 2026-11-20; B-497 closed 2026-11-20 (maintainer, in chat; WSD-139), the rows below each one rank up; B-467's re-run ruled 'Finish it' and B-516's template fix ruled now (maintainer, in chat 2026-11-20), B-530's questions answered the same day; B-538 gains a Fable 5.2 reading; B-542 filed 2026-11-20 from two CI timing failures and placed last by the coordinator (the maintainer set no rank); B-543 and B-544 filed 2026-11-20 from field report #17 and placed last by the filing session (the maintainer set no rank); earlier ranking history is in `git log -p meta/BACKLOG.md`

| Rank | Item | Why here |
|---|---|---|
| 1 | B-537 | Maintainer priority (in chat 2026-11-19, "put it to the top"): Field report #15 and maintainer request: a chat asked to address pull-request review comments gets no guidance, and the comments are sometimes wrong; measure before anything ships; guarded if it ships |
| 2 | B-516 | Maintainer priority: approval is two manual edits and a draft is live before review, where B-514 saw it followed as often as an approved skill; guarded; Claude Code leg read 2026-11-20, Copilot leg waits for 2026-12-01; template fix shipped and re-run 3 of 3 (2026-11-20); only the Copilot leg is left |
| 3 | B-530 | The opt-in review line on Copilot CLI, where the consumer team runs and where the `review` skill loaded and dispatched no reviewer (B-425, folded in); questions answered (maintainer, in chat 2026-11-20); runs wait only for the Copilot allowance to refill on 2026-12-01 |
| 4 | B-467 | Measured 2026-11-04: omitClaudeMd cuts each reviewer's first request by about 9,200 tokens; the findings comparison was not settled under the eval harness, so a re-run decides shipping; maintainer ruled "Finish it" (in chat 2026-11-20), 12 USD cap |
| 5 | B-508 | Extract the installer's pure planning functions with unit cases; the copy and the install-commit notice shipped 2026-11-17; guarded, step 4 |
| 6 | B-512 | `presentation/` single copy and the wrapper SHA-256 bullet remain (`adopt.md`/`playbook.md` shipped 2026-11-17); guarded (AGENTS.md) |
| 7 | B-417 | Improvement to 0.98.0's core: B-412 saw no downstream difference because prompt K states every outcome; about 10 USD |
| 8 | B-420 | The fix path's restated criterion, unchanged since 0.97; about 8 USD; better after B-416's field answers |
| 9 | B-419 | Improvement with no field report; starts with a hand-read of the retained security passes |
| 10 | B-468 | Measured, not field-raised: 2 of 26 plain bug fixes skipped the regression test, wrongly saying a SQLite test needs a new package; the agent said the fix was untested |
| 11 | B-451 | Field report, narrowed: the compact baseline shipped; review-tool markers for it wait on the reporter saying what their host honours; guarded |
| 12 | B-490 | Audit, reproduced: the agent can rewrite the hook registrations; decided 2026-11-19: the guard refuses a settings write that drops its own registration and any write to the hook files; guarded, step 4; maintainer, in chat 2026-11-19: not to be picked up unless it is shown to be the highest-value item, since a scan the same day of 412 retained Claude Code eval sessions (36 with a blocked call) found no agent write to the settings or hook files |
| 13 | B-504 | Vendor-guidance audit, read: the reviewers are read-only in prose only; decided 2026-11-19: keep the shell, give the Copilot wrappers a tool list and stop saying read-only; blocked for the host check until the Copilot allowance refills on 2026-12-01 (maintainer, in chat 2026-11-19) |
| 14 | B-518 | Consumers have a stated floor for Claude Code only, and no statement of what 1.0 promises; ordinary |
| 15 | B-519 | The always-loaded rules file, cut only where a measurement can go red; every cut measured |
| 16 | B-524 | Guidance review, read: after a compaction Claude Code keeps only the start of a long command, and the write steps of `/bootstrap` and `/adopt` sit past it; size the session first; guarded, text-only |
| 17 | B-527 | Guidance review: the maintainer gate's stillness check missed the one case recorded, and the rule names no next step; ordinary for the skill, guarded for `AGENTS.md` |
| 18 | B-526 | Guidance review, observed, no harm recorded: consumer instructions and skills load into maintainer sessions; one sentence to correct, one setting for the maintainer to decide |
| 19 | B-529 | Maintainer request, exploration only: whether a model call is a quick fallback when the router's keyword rules cannot tell the intent; report before any change |
| 20 | B-535 | Maintainer request, from the host-guidance report: whether VS Code's default Copilot mode lists the framework's commands; unmeasured, no field report; needs Copilot access |
| 21 | B-538 | Observed on Fable 5.1 (n=2, one scenario): the production edit was made by shell `sed -i`, which the write guard and post-write hooks do not see; possible secret leak ordinary use triggers (WSD-124, WSD-125); Fable 5.2 used the Edit tool in 2 of 2 (n=2); measure first |
| 22 | B-539 | Field report #16: after an AI-assisted .NET upgrade a host built, passed its unit tests and did not start, and the UI did not load; nothing in the framework asks for the application to be started; measure first |
| 23 | B-540 | Maintainer's idea, from field report #15: learn what a team treats as too much from its decisions on past review comments; design first, and a free counts-only pass over past pull requests before that |
| 24 | B-541 | Field report #15: a team's CI reviewer reads every installed Markdown file, and the CI guide still says pull-request review is done locally; ordinary, docs only |
| 25 | B-542 | Observed in CI, false red on a guarded runner that ordinary pushes trigger (a 5000 ms timing limit; not known whether the guard or the runner is slow); no consumer harm, a re-run clears it, so it follows B-538, the one guarded-harm item here, and ranks last |
| 26 | B-543 | Field report #17: on .NET, feature work creates too many classes, read by the reporter as SOLID applied mechanically; two shipped lines create a class by rule; measure first |
| 27 | B-544 | Field report #17: on .NET, the agent puts utilities only tests use in production code and writes too many tests; no shipped line says where test support belongs; measured with B-543 |

## Open entries


Archived items. B-225 and B-254 — see `meta/BACKLOG-DONE.md`.
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

### B-530 · Measure the plan's opt-in review line on Copilot CLI, where the `review` skill loads and dispatches no reviewer
**Filed against:** v0.98.6 (2026-11-19)
**Priority:** P2 · **Effort:** S to measure, S to M to change · **Invariants:** #5 #7
**Status:** The plan's six questions are answered (maintainer, in chat 2026-11-20); the runs wait only for the Copilot allowance to refill on 2026-12-01 (maintainer, in chat 2026-11-19). A probe by the main session at about 21:40 UTC that day (Copilot CLI 1.0.98) was refused with "You have exceeded your monthly quota"; an earlier probe had been refused "by policy settings". Part A and B1/B4/B6 shipped (`f8ae49e8`, `470b1aa8`, `8992c77b`, `02ee5560`). Then run B-416's pre-registered cells (`.claude/plans/2026-11-19-b416-review-offer.md`, `ask_user` left on) on Copilot CLI in plan mode with the shipped wording, including the risk-change order and a completed review. Plan: `.claude/plans/2026-11-19-b530-copilot-go-ahead-measurement.md`.
Carries B-425's finding (2026-11-13, CLI 1.0.98): "Review my changes." reached `review.md` in 5 of 6 runs; 0 of 6 started a reviewer; 3 of 6 gave the diff's size as the reason (re-read 2026-11-19, `meta/eval-results.md`).
Next candidate if that reproduces: `review.md` Step 1's wording, not the routing; B-425's `$railsReview` candidate was not shown to help and is dropped.

### B-451 · The rebootstrap baseline has no review-tool markers, so a diff still shows its rows
**Filed against:** v0.98.2 (2026-10-21)
**Priority:** P3 · **Effort:** S · **Invariants:** #1 #7
**Status:** Narrowed 2026-10-31: schema 2 shipped (`file <path> <blob>` once per matched file, `evidence <id> <pattern>` per claim; 600 files x 36 claims 9,424 -> 766 lines, Impact output identical in 22 scenarios; a schema 1 baseline is read and rewritten). Open: shipped `.claude/.gitattributes`
lines (`bootstrap-baseline.tsv -diff linguist-generated=true`) so review tools collapse the file; guarded (a framework-owned file below `.claude/` goes through the installer's ownership policy, step 4, with a brownfield-archive case).
First ask the reporter what their Bitbucket host honours, and do it only if the compaction alone did not answer field report #10 item 2.

### B-467 · Each `/review` reviewer sub-agent carries the main agent's whole instruction chain
**Filed against:** v0.98.2 (2026-10-27)
**Priority:** P3 · **Effort:** S · **Invariants:** #2
**Status:** Open (maintainer request; `meta/eval-results.md`, "Sub-agent context results", read FILE): Claude Code injects the consumer `CLAUDE.md`, `AGENTS.md` and the rules carrier, 25,805 chars, into all six reviewers.
Measured 2026-11-04 (pre-registered at d7da3b75, results in "B-467 results"): `omitClaudeMd: true` cut each reviewer's first request by about 9,200 tokens (R1 holds) and Copilot CLI 1.0.98 loads it; R2 (findings) not settled, one valid run per arm.
The maintainer ruled "Finish it" (in chat 2026-11-20), 12 USD cap: re-run R2 on the ready candidate (local branch `b467-candidate`, fb299354), pre-registered in `.claude/plans/2026-11-20-b467-r2.md`, then ship it guarded; the maintainer gave the go on that plan as written ("Go as planned", in chat 2026-11-20).

### B-468 · A plain bug fix can skip the regression test, wrongly saying a SQLite test needs a new package
**Filed against:** v0.98.2 (2026-10-27)
**Priority:** P3 · **Effort:** S · **Invariants:** none
**Status:** Open (maintainer request; `meta/eval-results.md`, "Test-level clause before/after"): 2 of 26 variant-B runs, one per arm, fixed an EF translation bug with no test and said SQLite needed
"a new package" and harness; the provider already reached the test project through its reference to the API, and 21 other runs used it without touching a `.csproj`. Suspected carrier: the Bug-fix
bullet's and fix rail's "add no foreign harness", read as forbidding an engine the code under test already uses. n = 2: measure (about 0.25 USD a run) before any wording change.

### B-490 · The agent can rewrite the hook registrations
**Filed against:** v0.98.4 (2026-11-10)
**Priority:** P2 · **Effort:** S to M · **Invariants:** #3 #5
**Status:** Open; maintainer-requested external audit. Done for 0.99.0: part (a), fail closed (maintainer, in chat 2026-11-13: the guard command exits 2 when its interpreter is not found, its entry sets `"onFailure": "block"`), and, with B-506, the doctor's `Wired hook shell` row is `MISSING` for an interpreter not on `PATH`. Reproduced: a write of `{ "hooks": {} }` to `.claude/settings.json` exits 0.
Decided 2026-11-19 (maintainer, in chat; WSD-132), the narrow block: the guard refuses a settings write whose result no longer registers `guard.ps1`, and any agent write to `.claude/hooks/*.ps1` or `.github/hooks/hooks.json`; `/adopt` and the upgrade checklist keep editing other settings. Left: implement it, guarded, step 4. Brief: `.claude/plans/2026-11-10-external-audit-briefs.md`. Plan, adversarially reviewed: `.claude/plans/2026-11-19-b490-guard-wiring-block.md`.
B-489's round-2 attack: the guard does not refuse a Write to `.claude/settings.json` or `.claude/hooks/guard.ps1` on either surface (settings.json run; guard.ps1 by the same logic, not run). Also, to be fixed with this item (maintainer, in chat 2026-11-19): the shipped guard decides on the path as typed, so its secret rule is passed by a Windows short (8.3) name that looks like a test file (`test+cfg.json` blocked, exit 2; its alias `TEST_C~1.JSO` allowed, exit 0; run 2026-11-19 on the dist/dotnet guard; low impact: non-test names and their aliases are blocked).
### B-504 · The reviewers are read-only in prose only: a shell on Claude Code, every tool on Copilot
**Filed against:** v0.98.6 (2026-11-13)
**Priority:** P2 · **Effort:** S for a tool list, M to drop the shell · **Invariants:** #2 #5 #7
**Status:** Open; vendor-guidance audit and its adversarial review (read, not run). The seven `.claude/agents` files list `PowerShell`; the six `.github/agents` wrappers have no `tools:`, which Copilot reads as all tools; both vendors say a tool list is the boundary and an instruction is not.
Decided 2026-11-19 (maintainer, in chat; WSD-133): keep the shell. The six wrappers get `tools: ["read", "search", "execute"]` and the shipped text stops calling the reviewers read-only; dropping the shell (the hash recompute moved to the parent in six agents, six wrappers, `review.md` and `security-gate.md`) is rejected. Blocked until the Copilot allowance refills on 2026-12-01 (maintainer, in chat 2026-11-19); the change needs a host check that a reviewer starts, reads its bundle and has no edit tool. Plan, adversarially reviewed: `.claude/plans/2026-11-19-b504-reviewer-tool-lists.md`.
Also: VS Code documents that it does not forward `include-custom-instructions`, which four wrappers rely on; not measured.
### B-508 · The installer's HEAD-comparison and ownership planning has no unit tests, and an edited framework-owned file is replaced unannounced
**Filed against:** v0.98.6 (2026-11-14)
**Priority:** P2 · **Effort:** M · **Invariants:** #7
**Status:** Open. The copy of an uncommitted framework-file edit and the notice for a committed one (HEAD against the last install commit) shipped 2026-11-17 for 0.99.0 (WSD-129); attack rounds 1 and 2 fixed (round 2: a false notice in an offline partial clone).
Remaining: extract the pure planning functions with unit cases. Pre-existing: a framework file held open with share Read only gives a half-applied update (exit 3, "62 of 90 framework files were written", nothing lost), and the `.gitignore` and disabled-skill loops read with `ReadAllBytes` and stop with exit 4 on a held file. Keep the legacy pre-commit inspection: updates accept 0.76.0, the helpers it protects retired in 0.83.0, and `InstallerConvergence` exercises it.
Guarded, step 4.
### B-512 · `presentation/` and a wrapper SHA-256 bullet are still kept as duplicates
**Filed against:** v0.98.6 (2026-11-14)
**Priority:** P3 · **Effort:** S · **Invariants:** #1
**Status:** Open; `adopt.md` and `playbook.md` are single core files with stack markers, dist byte-identical, shipped 2026-11-17 (WSD-126 retired the marker cap); `bootstrap.md` stays as three copies. Attack round 1: a missing monorepo snippet now fails validate-dist.
Remaining: one copy of `presentation/` (built into all three dists, never installed) and one SHA-256 bullet fewer in the bloat-radar and test-critic Copilot wrappers. Guarded (AGENTS.md). Composer gaps the attack found, pre-existing: a snippet's trailing blank lines pass validate; a stack line typed into the core file ships to every stack; a marker only one stack supplies drops silently from the others; a restored `files/` whole file silently wins over the core file.
### B-516 · A draft skill becomes active only through two manual edits, and is discoverable before anyone reviews it
**Filed against:** v0.98.6 (2026-11-14)
**Priority:** P2 · **Effort:** S · **Invariants:** #1 #7
**Status:** Open; maintainer direction 2026-11-14 (WSD-124). Approval today is the draft's `## After review` paragraph: add one Common Tasks line to `AGENTS.md` and delete the draft wording, by hand. Meanwhile 3a-bis keeps the draft "immediately discoverable", so an unreviewed draft is followed as written.
Candidate: one action approves a draft (asked to approve it, the agent makes both edits). For the maintainer: whether a draft may go live without review (WSD-109 says pending PR review). Guarded.
B-514 (2026-11-15, Claude Code and Copilot CLI): an unreviewed draft is called as often as an approved skill (6 of 6 each on each host, first thing, through the host's skill list), and B-515 then found no draft missing a step (0 of 8; none written on 4,999 files). Maintainer 2026-11-15: drafts stay live; B-515 closed. Claude Code leg read 2026-11-20 (Sonnet 5.5, 0.61 USD, `meta/eval-results.md`): oracle 1 of 3, hand read 3 of 3 approved in one ask (the two FAILs only removed draft markers from the skill's own reference file); no candidate T indicated by this leg; Copilot leg held until the allowance refills on 2026-12-01; stays open until it. Maintainer ruled in chat 2026-11-20: fix the template gap now (draft markers in the skill's reference files); shipped in `078328ae`; the re-run read 3 of 3 PASS (0.61 USD, `meta/eval-results.md`). Claude Code leg done on both counts: the one-ask approval works and the reference-file gap is fixed; only the Copilot leg is left.
### B-518 · Consumers are not told which Copilot CLI and VS Code versions are supported, or what 1.0 will promise
**Filed against:** v0.98.6 (2026-11-14)
**Priority:** P3 · **Effort:** S · **Invariants:** #7
**Status:** Open; architecture review 2026-11-14. `docs/enforcement-surfaces.md` states a floor for Claude Code only (2.1.141); nothing is stated for Copilot CLI or VS Code, whose behaviour the maintainer re-measures release by release (`meta/host-certification.md`). The framework has 115 release tags and is at 0.98 with no statement of what a 1.0 guarantees an installed repository.
Candidate: one support statement per host in `enforcement-surfaces.md`, drawn from `host-certification.md`; a short maintainer decision on what 1.0 promises (update path, ownership classes, hook contract). Ordinary for the docs.
Also: `enforcement-surfaces.md`'s "Status notes" and Copilot-harness bullet still say the guard's deny was not observed on VS Code's Copilot harness, stale since 2026-11-03 (understates); refresh them with the per-host statement. Also (field report #15): a team's CI reviewer reads the installed Markdown, so the names and headings of the files that hold repository knowledge are a contract an update can break; the 1.0 decision says which of them stay stable.
### B-519 · Trim the always-loaded rules file only where a measurement can go red
**Filed against:** v0.98.6 (2026-11-14)
**Priority:** P3 · **Effort:** M · **Invariants:** #1 #7
**Status:** Open; architecture review 2026-11-14, narrowed by its attack. The carrier is 15.6 KB on every turn; B-411 showed 5.8 KB could go with every measured behaviour holding, but its cells cover about 3 of the file's 38 directives and WSD-107 measured one added sentence doing harm. The ownership sentence stays (WSD-071); the rule numbers are cited across `src/`, so before any cut renumbers rules, replace rule numbers with named anchors, as the 2026-11-14 decision audit proposed (B-142 proposed only a range check and, closing as a deliberate non-action on 2026-08-19, called stable rule identities "a materially larger canonicalisation design").
Candidate: cut or shorten only text a discriminating cell covers, one group per measurement; B-356's bullet was measured 2026-11-18 and stays (`meta/eval-results.md`). Ordinary by path; every cut measured.
### B-524 · `/bootstrap` and `/adopt` lose their write steps when Claude Code compacts the conversation
**Filed against:** v0.98.6 (2026-11-15)
**Priority:** P3 · **Effort:** S · **Invariants:** #1 #7
**Status:** Open; maintainer-requested review against current Anthropic guidance, 2026-11-15, and its attack (vendor pages read; not observed on a host). Claude Code's skills page: after a compaction it re-attaches only "the first 5,000 tokens" of an invoked command and does not re-read the file. `bootstrap.md` is 57 KB (dotnet) and its write steps, completion gate and report start at byte 23,055; `adopt.md` is 43 KB, and its Phase 7 deletes `.claude/adoption-pending.json` before it runs `/bootstrap`.
Trigger: both commands pause for the developer, and the best-practices page says a session past about 200K tokens that sits idle is compacted before its one-hour cache expires; a gateway held at 200K or a typed `/compact` does the same. No recorded run reached that size (a headless `/bootstrap` on the fixtures costs 1.10 to 1.20 USD).
Candidate: first read the parent session's size on B-466's sized repositories; if it nears 200K, one line near the top of `adopt.md` and the three `bootstrap.md` copies (after a compaction, read this file again before the next phase), or the phases as supporting files. Guarded (`src/stacks/*/files/.claude/**`), text-only. From B-520 (closed): `adopt.md`'s headless block (bytes 895 to 7,677) fills about a third of what survives a compaction; if `/adopt` is sized near 200K, moving it to the file's end is cheaper than a second file. B-466's sizes were `/bootstrap`'s, not `/adopt`'s.
### B-526 · Shipped consumer instructions and skills load into maintainer sessions, and root `CLAUDE.md` names two of the four trees they load from
**Filed against:** v0.98.6 (2026-11-15)
**Priority:** P3 · **Effort:** S · **Invariants:** none
**Status:** Open; same review and attack (observed in this review's Claude Code desktop sessions; no harm recorded). Reading a file under `dist/dotnet/` loaded that tree's `CLAUDE.md` and listed its nine skills as invocable; `src/stacks/dotnet/files/` and `src/core/` added nine more. `meta/eval-fixtures/` holds two `CLAUDE.md`, five `AGENTS.md` and seven skills. Root `CLAUDE.md` warns about `src/core/` and `dist/*/` only.
Candidate: correct that sentence (ordinary). The maintainer decides whether `.claude/settings.json` gains `claudeMdExcludes` with `**/`-anchored patterns, the vendor's documented control for the `CLAUDE.md` files (guarded; only a host run can show it red).
Nested skills have no documented switch by path (`skillOverrides` goes by skill name, about twenty to keep in step), so they stay a prose warning.
### B-527 · The maintainer gate's stillness check cannot see another session's uncommitted edits, and the rule it serves names no next step
**Filed against:** v0.98.6 (2026-11-15)
**Priority:** P3 · **Effort:** S · **Invariants:** none
**Status:** Open; same review and attack. `.claude/skills/meta-gates/SKILL.md` step 1 compares `git rev-parse HEAD` three seconds apart. On 2026-11-13 the other session's edits were uncommitted, so HEAD stood still; step 0 would also have read that session's changed paths into this change's tier. `AGENTS.md` ("Do not run suites while another session is editing the tree") says to stop and not what follows: that night a reviewed guarded fix waited until the next morning (9e8dbb28), with no release held up.
Candidate: step 1 also compares `git status --porcelain` before and after and names the paths this session did not touch (ordinary, the skill file). One clause in `AGENTS.md` for the blocked session (wait a stated time, check once more, then report), with a clause cut and the step-4 attack that file requires.
Worktrees are not the way out: `push-and-check.ps1` watches `master` only, and worktrees inside the repository left stray entries in v0.42.0 and v0.43.0 (`.gitignore`).

### B-529 · Explore a model-call fallback for `route-prompt` when its keyword rules cannot tell the intent
**Filed against:** v0.98.6 (2026-11-17)
**Priority:** P3 · **Effort:** M to explore · **Invariants:** #3 #5
**Status:** Open; raised by the maintainer in chat 2026-11-17 while reviewing B-491, no field report. B-491's keyword rules mis-routed approvals, questions and words inside other words, and each narrowing trades one miss for another.
Explore, in a Fable 5.2 session, whether asking a small model for the intent only when the rules are unsure is a quick fallback a prompt hook can afford: latency, cost per prompt, what happens with no network or key, and both surfaces. Report before any change.

### B-535 · Does VS Code's default Copilot mode list the framework's commands
**Filed against:** v0.98.6 (2026-11-19)
**Priority:** P3 · **Effort:** S · **Invariants:** none
**Status:** Open; maintainer request in chat 2026-11-19, from the host-guidance report (read, not run). VS Code's documentation names `.github/skills/` as the Copilot harness's project skill folder and does not say that it reads `.agents/skills`, `.claude/skills` or `.claude/commands`, so the twelve command wrappers per stack (`.agents/skills/<name>/SKILL.md`) may not appear there; unmeasured, no field report.
First step: open a framework-installed repository in VS Code's Copilot harness and list the commands; blocked until the Copilot allowance refills on 2026-12-01 (maintainer, in chat 2026-11-19). If they are missing, that is a defect with its own fix; if the harness lists the `.agents/skills` wrappers as the CLI does (the CLI lists them in place of a same-named `.claude/commands` entry, `meta/host-certification.md:64`), the report suggests the wrappers could shrink, each change its own.

### B-537 · A chat asked to address pull-request review comments applies no judgement the framework asked for
**Filed against:** v0.98.6 (2026-11-19)
**Priority:** P2 · **Effort:** M for the measurement, M to ship · **Invariants:** #1 #5 #7 if it ships
**Status:** Open; measured 2026-11-19 and 2026-11-20 on Claude Code (`meta/eval-results.md`, "B-537 results"; 18 runs, 7.18 USD): the shipped tree judged 3 of 6 runs, the on-demand `address-comments` command 6 of 6 with and without a router intent; no arm applied the field's class of wrong comment (more tests, an edge case that cannot occur), and the shipped tree's failures reversed a decline after a vague follow-up. The registered rule read not settled; the maintainer decided to ship (WSD-140).
Shipped for Claude Code 2026-11-20 for 0.99.0 (Unreleased; guarded): the `/address-comments` command and its Copilot wrapper, the measured text byte for byte, no router intent; a fresh session's four attacks on the ownership change held. A phrasing check the same day (8 runs, 2.63 USD) found the command called and held in 4 of 4 runs on the shipped tree for two wordings the router sends to the fix and review rails. Left: the same arms on Copilot when access returns (B-530's queue), where the router intent is decided, with a person's blocking comment and a larger volume added to the fixture; the harness is on `master` (`review-comments-c` now removes the command, `-a` is the shipped tree, `-ab` adds the intent, and four more cells carry the two other wordings).
Second stage, not built (plan section 11): learn from the team's decisions on past comments, offering a convention line the third time a kind of comment is declined. Plan, adversarially reviewed and compared with vendor guidance: `.claude/plans/2026-11-19-b537-address-review-comments.md`.

### B-538 · The agent edited production code through the shell, where the write guard and post-write hooks do not see it
**Filed against:** v0.98.6 (2026-11-19)
**Priority:** P2 · **Effort:** S to measure, M to change · **Invariants:** #5
**Status:** Open; the main session's hand read of B-525 set 1 (2026-11-19, `meta/eval-results.md`): in 2 of 2 `route-fix` runs on Fable 5.1, Claude Code 2.1.312, the agent made its production edit with `sed -i` through the Bash tool (n=2, one scenario); on Fable 5.2 (n = 2, one scenario) the production edit was made with the Edit tool in 2 of 2 `route-fix` runs, the opposite of 5.1's `sed -i` (`meta/eval-results.md`, B-525 on Fable 5.2). The write guard and post-write hooks match Write, Edit and NotebookEdit only; `src/core/docs/enforcement-surfaces.md` (lines 173-179) already says a shell-routed write fires neither. It qualifies under WSD-124 and WSD-125 as a possible secret leak that ordinary use triggers.
First step: measure how often, on which models, from retained transcripts, before any change.

### B-539 · A change is reported verified when the application was never started
**Filed against:** v0.98.6 (2026-11-20)
**Priority:** P2 · **Effort:** M · **Invariants:** #7 if it ships
**Status:** Open; field report #16 (2026-11-20): after an AI-assisted .NET upgrade one host failed at start-up with a "multiple constructors" error while the unit tests passed, and the UI did not load. Read in `dist/dotnet` the same day: verification is build and test only, with no category for starting the application, and Test leanness #12, `add-tests` and `/test` discourage a test that the application's own wiring resolves.
Phase 1 measured 2026-11-20 on Claude Code (`meta/eval-results.md`, "B-539 results, phase 1"; 6 valid runs, 1.64 USD): read NOT EXERCISED, since only 1 of 6 handed the broken tree back in silence; yet 6 of 6 final trees do not start, 0 of 6 started the host, 5 of 6 said the wiring was unverified, and 3 of 6 gave Test leanness #12 as the reason for writing no start-up test. Phase 2 re-registered the same day at the maintainer's choice ("B-539 phase 2, re-registered"): the rules line, the suite-owned start-up test and a reworded #12, each against "the final tree starts" (0 of 6 in phase 1). Halted after 8 runs, not settled ("B-539 phase 2 — halted"; 3.52 of 16 USD spent): this machine's Application Control policy blocked the built test assembly in 6 of 8 runs, and the host refuses the compound start commands agents write. Phase 3 registered the same day at the maintainer's direction ("B-539 phase 3 pre-registration"): one candidate, a reworded #12 under which the agent adds and runs one start-up test when a change touches start-up wiring; policy-blocked runs are repeated. Copilot and VS Code wait for 2026-12-01.

### B-540 · Learn what a team treats as too much from its decisions on past review comments
**Filed against:** v0.98.6 (2026-11-20)
**Priority:** P3 · **Effort:** S for the counts pass, M to design · **Invariants:** #1 #7 if it ships
**Status:** Open; the maintainer's idea in chat 2026-11-19 (B-537's second stage, plan section 11), filed at their request 2026-11-20. Not built, no harm observed: it is a capability the framework lacks, so it ships on WSD-141's lighter bar (a fixture check that it works and does no harm, a removal trigger, the hosts named). Developers sometimes reply to or leave unresolved the comments they disagree with (field report #15); how often is not captured.
First, at no cost: a counts-only script for a developer to run over past pull requests through the team's Bitbucket tool (comments, how many a person declined, answered or left unresolved, how many were followed by a change to the anchored line), as B-416's observation card was run; nothing but counts leaves the machine. It also gives the first field number for how often the reviewer is wrong.
Then a design, attacked by a fresh session before any build: what a declined comment is recorded as and where, the third-decline offer of one `AGENTS.md > Conventions` or wiki line the developer approves, and the guard against a pattern of declines that hides tests the team needs. A recorded line reaches the team's reviewer too, since it reads every Markdown file. Plan: `.claude/plans/2026-11-19-b537-address-review-comments.md`.

### B-541 · A team's CI reviewer reads every installed Markdown file, and the CI guide says pull-request review is local
**Filed against:** v0.98.6 (2026-11-20)
**Priority:** P3 · **Effort:** S · **Invariants:** #1 #7
**Status:** Open; field report #15, filed at the maintainer's request in chat 2026-11-20. The first consumer team's own pull-request reviewer takes all Markdown in the repository as context. `dist/dotnet` holds about 490 KB of installed Markdown (measured 2026-11-19, the changelog left out), most of it setup commands and operating manuals: `bootstrap.md` 58 KB, `enforcement-surfaces.md` 49 KB, `adopt.md` 43 KB. What that costs the team's reviewer, or does to its comments, is not measured.
Candidate, ordinary and docs only: one short list, in `docs/ci-integration.md`, of the files that hold repository knowledge a reviewer should read (the conventions, the hazard areas, the wiki, the warehouse map, the decisions) and the framework's own files it can leave out; and that guide's "What CI still cannot gate" section stops saying semantic review happens only before push and by hand, since a team can run its own reviewer in CI on these files.
Before writing it, ask the team which files their reviewer is given and whether its cost or noise is a problem; if neither, the list alone ships with its cost-benefit line.

### B-542 · A guard timing test failed three times in CI on pushes that did not touch the guard
**Filed against:** v0.98.6 (2026-11-20)
**Priority:** P3 · **Effort:** S to measure · **Invariants:** none
**Status:** Open; the `Guard.Tests` case "a list line built to backtrack answers within 5 s and waives nothing it does not match" (`**/fixtures/**/samples/**/*.json` on a 10308-character path, Copilot) took 8575 ms on `windows-hooks (monorepo, 1)` for the push of `fd2a90e2` (run 44656073360) 8052 ms on `windows-hooks (angular, 1)` for `01c8d954` (run 44686907594) and 9661 ms on `windows-hooks (dotnet, 1)` for `9d210db9` (run 44707512175), and a fourth time, 9502 ms on `windows-hooks (angular, 1)` (Claude) for `4e71939c` (run 44704377117), against a 5000 ms limit; no push touched the guard; all green on re-run.
Not known: whether the guard is near its limit on that input or the CI runner is slow. A false red on a guarded runner that ordinary pushes trigger. Measure the case's time on this host and on a CI re-run before touching test or guard.

### B-543 · Feature work on .NET creates more classes than the change needs
**Filed against:** v0.98.6 (2026-11-20)
**Priority:** P2 · **Effort:** M · **Invariants:** #1 #7 if it ships
**Status:** Open; field report #17 (2026-11-20): "strict SOLID is creating too many classes", with a proposed goal of the simplest maintainable solution; which kind of class, the host and the model were not captured. Read in `src/stacks/dotnet` the same day: Leanness #1 gives new code "its own class … even with one consumer" (WSD-104, from field report #8, which complained of the opposite) and SOLID #1 splits on "more than ~5 injected collaborators"; the SOLID section itself asks for no interface without project evidence.
First a measurement (WSD-139): one .NET feature on the shipped tree against no framework, counting new production types, single-implementation interfaces and one-method services; then a plan for the wording, attacked by a fresh session and compared with published practice, as the maintainer asked in chat. WSD-104's reopen trigger is approached, not met.

### B-544 · Code only tests use lands in the production project, and a feature gets more tests than it needs
**Filed against:** v0.98.6 (2026-11-20)
**Priority:** P2 · **Effort:** S to M · **Invariants:** #1 #7 if it ships
**Status:** Open; field report #17 (2026-11-20): "it's adding utilities for unit tests in regular code that it shouldn't -- going over the top with unit tests", the example "like a csv reader"; no diff, and how many tests is too many was not captured. Read the same day: Test leanness #12 to #15 and the Feature rail ask for the smallest useful tests, and no shipped line says that code only tests use belongs in the test project.
Measured on B-543's fixture and runs: production types and members that only tests reference, and tests added per stated behaviour. It pulls against B-539 (field report #16: unit tests green, the application did not start), so a wording that cuts tests is read against that too.
