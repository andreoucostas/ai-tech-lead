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

## Pick-up order — re-ranked 2026-11-14 (maintainer, in chat; WSD-124, WSD-125): the architecture review filed as B-506 to B-513, then B-514 to B-520, with the project-skills work ranked after B-506 and B-507 (now ranks 4 and 5), eight findings shut, and the release review's B-521 and B-522; B-509 and B-498 done the same day, B-507 and B-513 on 2026-11-15, B-466 moved after B-515 (maintainer, in chat) and done the same day, B-514 done the same day, B-515 and B-517 closed the same day (maintainer, in chat), B-523 closed the same day after two NO-SHIP measurements (maintainer, in chat), and B-523 filed and placed after B-466 by the coordinator (the maintainer set no rank); B-521 closed 2026-11-16; B-524 to B-527 filed 2026-11-15 from the maintainer-requested review against current Anthropic guidance and placed last by the reviewing session (the maintainer set no rank); B-528 filed 2026-11-16 from field report #14 and put at rank 1 the same day (maintainer, in chat), the rows below one rank down; B-510 done 2026-11-16; B-469 done 2026-11-16; B-493 done 2026-11-16; B-491 done 2026-11-17; B-484 done 2026-11-17; B-496 done 2026-11-17; B-511 done 2026-11-17; B-489 done 2026-11-17; B-529 filed 2026-11-17 by the maintainer in chat, placed last by the coordinator (the maintainer set no rank); B-528 closed 2026-11-18 as not reproduced (maintainer, in chat); B-416's review decision taken 2026-11-19 (maintainer, in chat; WSD-131), B-425 folded into B-530, which takes its rank, and B-490 and B-504 decided the same day (WSD-132, WSD-133); B-531 to B-533 filed 2026-11-19 by the maintainer in chat, to follow B-416's measurement, placed last by the filing session (the maintainer set no rank); B-534 filed 2026-11-19 from the maintainer's chat request and placed last by the filing session (the maintainer set no rank); B-522 done 2026-11-19; B-502 done 2026-11-19; B-534 closed 2026-11-19 as NO-SHIP (maintainer, in chat); B-416 done 2026-11-19, the rows below one rank up; B-520 closed 2026-11-19 (maintainer, in chat; WSD-139), the rows below one rank up; B-532 and B-533 closed 2026-11-19 (maintainer, in chat) and B-535 and B-536 filed from their reports and placed last by the filing session (the maintainer set no rank), taking ranks 22 and 23; B-537 filed 2026-11-19 from the maintainer's chat request and field report #15 and put at rank 1 the same day (maintainer, in chat), the rows below one rank down; B-536 done 2026-11-20, B-538 one rank up; B-483 done 2026-11-20, the rows below one rank up; earlier ranking history is in `git log -p meta/BACKLOG.md`

| Rank | Item | Why here |
|---|---|---|
| 1 | B-537 | Maintainer priority (in chat 2026-11-19, "put it to the top"): Field report #15 and maintainer request: a chat asked to address pull-request review comments gets no guidance, and the comments are sometimes wrong; measure before anything ships; guarded if it ships |
| 2 | B-516 | Maintainer priority: approval is two manual edits and a draft is live before review, where B-514 saw it followed as often as an approved skill; guarded; Claude Code leg read 2026-11-20, Copilot leg waits for 2026-12-01 |
| 3 | B-530 | The opt-in review line on Copilot CLI, where the consumer team runs and where the `review` skill loaded and dispatched no reviewer (B-425, folded in); blocked until the Copilot allowance refills on 2026-12-01 (maintainer, in chat 2026-11-19) |
| 4 | B-497 | Merge the three Haiku reviewers into one pass, measured with B-467's 12-defect harness (the `/review` merge, verdict and delegation parts shipped 2026-11-17); guarded |
| 5 | B-467 | Measured 2026-11-04: omitClaudeMd cuts each reviewer's first request by about 9,200 tokens; the findings comparison was not settled under the eval harness, so a re-run decides shipping |
| 6 | B-508 | Extract the installer's pure planning functions with unit cases; the copy and the install-commit notice shipped 2026-11-17; guarded, step 4 |
| 7 | B-512 | `presentation/` single copy and the wrapper SHA-256 bullet remain (`adopt.md`/`playbook.md` shipped 2026-11-17); guarded (AGENTS.md) |
| 8 | B-417 | Improvement to 0.98.0's core: B-412 saw no downstream difference because prompt K states every outcome; about 10 USD |
| 9 | B-420 | The fix path's restated criterion, unchanged since 0.97; about 8 USD; better after B-416's field answers |
| 10 | B-419 | Improvement with no field report; starts with a hand-read of the retained security passes |
| 11 | B-468 | Measured, not field-raised: 2 of 26 plain bug fixes skipped the regression test, wrongly saying a SQLite test needs a new package; the agent said the fix was untested |
| 12 | B-451 | Field report, narrowed: the compact baseline shipped; review-tool markers for it wait on the reporter saying what their host honours; guarded |
| 13 | B-490 | Audit, reproduced: the agent can rewrite the hook registrations; decided 2026-11-19: the guard refuses a settings write that drops its own registration and any write to the hook files; guarded, step 4; maintainer, in chat 2026-11-19: not to be picked up unless it is shown to be the highest-value item, since a scan the same day of 412 retained Claude Code eval sessions (36 with a blocked call) found no agent write to the settings or hook files |
| 14 | B-504 | Vendor-guidance audit, read: the reviewers are read-only in prose only; decided 2026-11-19: keep the shell, give the Copilot wrappers a tool list and stop saying read-only; blocked for the host check until the Copilot allowance refills on 2026-12-01 (maintainer, in chat 2026-11-19) |
| 15 | B-518 | Consumers have a stated floor for Claude Code only, and no statement of what 1.0 promises; ordinary |
| 16 | B-519 | The always-loaded rules file, cut only where a measurement can go red; every cut measured |
| 17 | B-524 | Guidance review, read: after a compaction Claude Code keeps only the start of a long command, and the write steps of `/bootstrap` and `/adopt` sit past it; size the session first; guarded, text-only |
| 18 | B-525 | Guidance review: no run on Fable 5.2; set 1 ran on Fable 5.1 (4.83 USD), where the alias resolves on this Claude Code; one pass of the per-release model-change check |
| 19 | B-527 | Guidance review: the maintainer gate's stillness check missed the one case recorded, and the rule names no next step; ordinary for the skill, guarded for `AGENTS.md` |
| 20 | B-526 | Guidance review, observed, no harm recorded: consumer instructions and skills load into maintainer sessions; one sentence to correct, one setting for the maintainer to decide |
| 21 | B-529 | Maintainer request, exploration only: whether a model call is a quick fallback when the router's keyword rules cannot tell the intent; report before any change |
| 22 | B-535 | Maintainer request, from the host-guidance report: whether VS Code's default Copilot mode lists the framework's commands; unmeasured, no field report; needs Copilot access |
| 23 | B-538 | Observed on Fable 5.1 (n=2, one scenario): the production edit was made by shell `sed -i`, which the write guard and post-write hooks do not see; possible secret leak ordinary use triggers (WSD-124, WSD-125); measure first |

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
**Status:** Blocked until the Copilot allowance refills on 2026-12-01 (maintainer, in chat 2026-11-19). A probe by the main session at about 21:40 UTC that day (Copilot CLI 1.0.98) was refused with "You have exceeded your monthly quota"; an earlier probe had been refused "by policy settings". Part A and B1/B4/B6 shipped (`f8ae49e8`, `470b1aa8`, `8992c77b`, `02ee5560`). Then run B-416's pre-registered cells (`.claude/plans/2026-11-19-b416-review-offer.md`, `ask_user` left on) on Copilot CLI in plan mode with the shipped wording, including the risk-change order and a completed review. Plan: `.claude/plans/2026-11-19-b530-copilot-go-ahead-measurement.md`.
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
Left: re-run R2 with the eval harness's hook also covering cmdlet aliases (test-critic's `Select`), on the ready candidate (local branch `b467-candidate`, fb299354; no `review.md` change needed), then ship it guarded.

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
### B-497 · `/review` hands back six reviewers' findings with no merge, de-duplication or verdict rule
**Filed against:** v0.98.4 (2026-11-10)
**Priority:** P3 · **Effort:** S to M · **Invariants:** #1 #7
**Status:** Open. Shipped 2026-11-17 for 0.99.0: `/review` merges findings on one `file:line`, maps every reviewer's scale to blocker, should-fix or note, ends with one verdict line naming the blocker count and the reviewers returned or missing, and names a reviewer that errors as missing; existing debt entries and justified bloat do not block; `bloat-radar` and `solid-check` agree on delegation, the lines-per-file heuristic is gone, and the commented-out-code threshold is one line everywhere.
Remaining: merge the three Haiku reviewers (convention-check, bloat-radar, debt-radar; B-427) into one pass, measured with B-467's 12-defect harness, and do the de-duplication there. Brief: `.claude/plans/2026-11-10-external-audit-briefs.md`.
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
B-514 (2026-11-15, Claude Code and Copilot CLI): an unreviewed draft is called as often as an approved skill (6 of 6 each on each host, first thing, through the host's skill list), and B-515 then found no draft missing a step (0 of 8; none written on 4,999 files). Maintainer 2026-11-15: drafts stay live; B-515 closed. Claude Code leg read 2026-11-20 (Sonnet 5.5, 0.61 USD, `meta/eval-results.md`): oracle 1 of 3, hand read 3 of 3 approved in one ask (the two FAILs only removed draft markers from the skill's own reference file); no candidate T indicated by this leg; Copilot leg held until the allowance refills on 2026-12-01; stays open until it.
### B-518 · Consumers are not told which Copilot CLI and VS Code versions are supported, or what 1.0 will promise
**Filed against:** v0.98.6 (2026-11-14)
**Priority:** P3 · **Effort:** S · **Invariants:** #7
**Status:** Open; architecture review 2026-11-14. `docs/enforcement-surfaces.md` states a floor for Claude Code only (2.1.141); nothing is stated for Copilot CLI or VS Code, whose behaviour the maintainer re-measures release by release (`meta/host-certification.md`). The framework has 115 release tags and is at 0.98 with no statement of what a 1.0 guarantees an installed repository.
Candidate: one support statement per host in `enforcement-surfaces.md`, drawn from `host-certification.md`; a short maintainer decision on what 1.0 promises (update path, ownership classes, hook contract). Ordinary for the docs.
Also: `enforcement-surfaces.md`'s "Status notes" and Copilot-harness bullet still say the guard's deny was not observed on VS Code's Copilot harness, stale since 2026-11-03 (understates); refresh them with the per-host statement.
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
### B-525 · No standing scenario has run on Fable 5.2, the model Claude Code now moves saved Fable 5.1 sessions to
**Filed against:** v0.98.6 (2026-11-15)
**Priority:** P3 · **Effort:** S · **Invariants:** none
**Status:** Open; same review and attack. Not yet run on Fable 5.2: on Claude Code 2.1.312 the `fable` alias resolves to Fable 5.1, and set 1 ran on 5.1 (4.83 USD, `meta/eval-results.md`); `route-fix`'s 1.25 USD budget is too small for this model. Claude Code 2.1.321 moves a saved `claude-fable-5-1` to Fable 5.2 on Pro, Max and Ultra plans, and `DEVELOPING.md`'s per-release check asks for a rerun when the model changed.
Anthropic's Fable 5.2 prompting page says a prompt silent on who owns the code makes the model add to existing structure "even when that duplicated existing code": the behaviour Leanness #1 exists to stop, measured on Opus 5.5 only (WSD-104). It also says long turns end early at `medium`, Claude Code's default effort. Not observed here; no field report names the model.
Candidate: that per-release line once with `-Model fable` (`route-fix`, `warehouse-bind-sql`, `angular-feature-placement`), rows in `meta/eval-results.md`, a backlog line only on its alarm; B-518's support statement then names the models measured. The harness's unpinned effort level stays as B-330 decided.
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
**Status:** Open; field report #15 and the maintainer's request in chat 2026-11-19. The first consumer team's own CI reviewer posts pull-request comments, sometimes too many or wrong; developers ask a new Copilot chat to address them, and the framework has no router intent or installed text for that chat. Not observed: an agent applying a wrong comment, so nothing ships before a failing control arm (WSD-139).
Wanted: the agent reads every open comment, checks each claim against the code, proposes fix, decline with evidence, defer or ask, and accounts for each; the developer owns every disposition. Candidate carrier: an on-demand `address-comments` command, with and without a router intent, three arms on a twelve-comment fixture built on the field's example of a wrong comment (more tests or an edge case that makes the solution over-complex), about 22 USD on Claude Code; Copilot when access returns (B-530).
Next: the harness is being built on a branch; the maintainer approved the spend in chat 2026-11-19, so the main session pre-registers and runs once the harness is verified. Second stage, not built (plan section 11): learn from the team's decisions on past comments, offering a convention line the third time a kind of comment is declined. Plan, adversarially reviewed and compared with vendor guidance: `.claude/plans/2026-11-19-b537-address-review-comments.md`.

### B-538 · The agent edited production code through the shell, where the write guard and post-write hooks do not see it
**Filed against:** v0.98.6 (2026-11-19)
**Priority:** P2 · **Effort:** S to measure, M to change · **Invariants:** #5
**Status:** Open; the main session's hand read of B-525 set 1 (2026-11-19, `meta/eval-results.md`): in 2 of 2 `route-fix` runs on Fable 5.1, Claude Code 2.1.312, the agent made its production edit with `sed -i` through the Bash tool (n=2, one scenario). The write guard and post-write hooks match Write, Edit and NotebookEdit only; `src/core/docs/enforcement-surfaces.md` (lines 173-179) already says a shell-routed write fires neither. It qualifies under WSD-124 and WSD-125 as a possible secret leak that ordinary use triggers.
First step: measure how often, on which models, from retained transcripts, before any change.
