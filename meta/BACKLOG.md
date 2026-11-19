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

## Pick-up order — re-ranked 2026-11-14 (maintainer, in chat; WSD-124, WSD-125): the architecture review filed as B-506 to B-513, then B-514 to B-520, with the project-skills work ranked after B-506 and B-507 (now ranks 4 and 5), eight findings shut, and the release review's B-521 and B-522; B-509 and B-498 done the same day, B-507 and B-513 on 2026-11-15, B-466 moved after B-515 (maintainer, in chat) and done the same day, B-514 done the same day, B-515 and B-517 closed the same day (maintainer, in chat), B-523 closed the same day after two NO-SHIP measurements (maintainer, in chat), and B-523 filed and placed after B-466 by the coordinator (the maintainer set no rank); B-521 closed 2026-11-16; B-524 to B-527 filed 2026-11-15 from the maintainer-requested review against current Anthropic guidance and placed last by the reviewing session (the maintainer set no rank); B-528 filed 2026-11-16 from field report #14 and put at rank 1 the same day (maintainer, in chat), the rows below one rank down; B-510 done 2026-11-16; B-469 done 2026-11-16; B-493 done 2026-11-16; B-491 done 2026-11-17; B-484 done 2026-11-17; B-496 done 2026-11-17; B-511 done 2026-11-17; B-489 done 2026-11-17; B-529 filed 2026-11-17 by the maintainer in chat, placed last by the coordinator (the maintainer set no rank); B-528 closed 2026-11-18 as not reproduced (maintainer, in chat); B-416's review decision taken 2026-11-19 (maintainer, in chat; WSD-131), B-425 folded into B-530, which takes its rank, and B-490 and B-504 decided the same day (WSD-132, WSD-133); B-531 to B-533 filed 2026-11-19 by the maintainer in chat, to follow B-416's measurement, placed last by the filing session (the maintainer set no rank); earlier ranking history is in `git log -p meta/BACKLOG.md`

| Rank | Item | Why here |
|---|---|---|
| 1 | B-416 | P1: the first developer's answers came in 2026-11-16 (field report #14, no review in 39 sessions); the maintainer chose an opt-in review line in the plan on 2026-11-19; measured on Claude Code the same day as a ship candidate (20 runs), so it waits on the maintainer's ship decision |
| 2 | B-516 | Maintainer priority: approval is two manual edits and a draft is live before review, where B-514 saw it followed as often as an approved skill; guarded |
| 3 | B-530 | The opt-in review line on Copilot CLI, where the consumer team runs and where the `review` skill loaded and dispatched no reviewer (B-425, folded in); blocked: Copilot access ended 2026-11-18 |
| 4 | B-497 | Merge the three Haiku reviewers into one pass, measured with B-467's 12-defect harness (the `/review` merge, verdict and delegation parts shipped 2026-11-17); guarded |
| 5 | B-467 | Measured 2026-11-04: omitClaudeMd cuts each reviewer's first request by about 9,200 tokens; the findings comparison was not settled under the eval harness, so a re-run decides shipping |
| 6 | B-508 | Extract the installer's pure planning functions with unit cases; the copy and the install-commit notice shipped 2026-11-17; guarded, step 4 |
| 7 | B-512 | `presentation/` single copy and the wrapper SHA-256 bullet remain (`adopt.md`/`playbook.md` shipped 2026-11-17); guarded (AGENTS.md) |
| 8 | B-417 | Improvement to 0.98.0's core: B-412 saw no downstream difference because prompt K states every outcome; about 10 USD |
| 9 | B-420 | The fix path's restated criterion, unchanged since 0.97; about 8 USD; better after B-416's field answers |
| 10 | B-419 | Improvement with no field report; starts with a hand-read of the retained security passes |
| 11 | B-468 | Measured, not field-raised: 2 of 26 plain bug fixes skipped the regression test, wrongly saying a SQLite test needs a new package; the agent said the fix was untested |
| 12 | B-451 | Field report, narrowed: the compact baseline shipped; review-tool markers for it wait on the reporter saying what their host honours; guarded |
| 13 | B-499 | Secret-leak class, B-487's step-4 attacks: the guard still passes an auto-property initializer, `NetworkCredential`, URL userinfo and other credential forms; guarded, step 4 |
| 14 | B-490 | Audit, reproduced: the agent can rewrite the hook registrations; decided 2026-11-19: the guard refuses a settings write that drops its own registration and any write to the hook files; guarded, step 4 |
| 15 | B-502 | Data-loss class, pre-existing, B-480's scope check (run): a disabled skill's exemplar line survives the update that disables it and is dropped by the next one; guarded, step 4 |
| 16 | B-504 | Vendor-guidance audit, read: the reviewers are read-only in prose only; decided 2026-11-19: keep the shell, give the Copilot wrappers a tool list and stop saying read-only; blocked on Copilot access for the host check |
| 17 | B-518 | Consumers have a stated floor for Claude Code only, and no statement of what 1.0 promises; ordinary |
| 18 | B-519 | The always-loaded rules file, cut only where a measurement can go red; every cut measured |
| 19 | B-520 | Seven small leftovers of the 2026-11-14 reviews, each narrowed by its attack |
| 20 | B-483 | False-green class, run by a fresh-session review: the warehouse map check reports `current` for deleted tables; was missing from this table |
| 21 | B-524 | Guidance review, read: after a compaction Claude Code keeps only the start of a long command, and the write steps of `/bootstrap` and `/adopt` sit past it; size the session first; guarded, text-only |
| 22 | B-525 | Guidance review: no run on Fable 5.2, which Claude Code now moves saved Fable 5.1 sessions to; one pass of the per-release model-change check |
| 23 | B-527 | Guidance review: the maintainer gate's stillness check missed the one case recorded, and the rule names no next step; ordinary for the skill, guarded for `AGENTS.md` |
| 24 | B-526 | Guidance review, observed, no harm recorded: consumer instructions and skills load into maintainer sessions; one sentence to correct, one setting for the maintainer to decide |
| 25 | B-529 | Maintainer request, exploration only: whether a model call is a quick fallback when the router's keyword rules cannot tell the intent; report before any change |
| 26 | B-531 | Maintainer request: a full implementation plan, each put through an adversarial review, for the items decided 2026-11-19 (the review line's shipping change, B-490, B-504, B-530); after B-416's measurement |
| 27 | B-532 | Maintainer request: re-read current Claude Code, Copilot CLI and VS Code guidance for what the framework ships that is now outdated or can be deleted, such as `CLAUDE.md` if every host reads `AGENTS.md` |
| 28 | B-533 | Maintainer request: review the testing strategy, whether end-to-end tests belong in it, and what published practice says about releasing fast; report before any change |

## Open entries

### B-416 · Observe 0.98.0 at the first consumer: do the restated criteria and Option A/B designs help, and are they right
**Filed against:** v0.98.0 (2026-10-19)
**Priority:** P1 · **Effort:** S · **Invariants:** none
**Status:** Open (maintainer, 2026-10-19). The observation card ran at the first consumer (`meta/field-reports.md` #14, one developer, mostly on 0.98.2): the `Done when:` lines before code in 28 of 39 sessions and judged right, no review run in any, options in 3 plans (B-528, closed as not reproduced). A team has started, so WSD-126's 2026-12-12 re-decision does not apply.
Decided 2026-11-19 (maintainer, in chat; WSD-131): in place of plan v2 §5 item 5's automatic review sentence, the plan closes with an opt-in review line and a plain go-ahead means no review; measured on Claude Code first, with the results to the maintainer before anything ships; B-425 is folded into B-530, the Copilot leg.
Measured 2026-11-19 on Claude Code (`meta/eval-results.md`, "B-416 results"; 20 counted runs, 7.57 USD): SHIP CANDIDATE. The line was in 12 of 12 plans and 0 of 6 without it; "with review" started the review in 6 of 6 on a plain change; a plain go-ahead started none in 6 of 6; the options, the Done-when lines and the security gate held. Left: the maintainer's ship decision, with one open question: on a security-sensitive change the asked-for review replaced the security gate in 1 of 3 runs.


B-225 and B-254 — see `meta/BACKLOG-DONE.md`.
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
**Status:** Blocked: Copilot access ended 2026-11-18 (maintainer, in chat 2026-11-19; WSD-131). Run B-416's pre-registered cells (`.claude/plans/2026-11-19-b416-review-offer.md`) on Copilot CLI in plan mode, as B-528's Copilot leg did: the consumer team runs on Copilot, and the Claude Code reading does not carry over.
Carries B-425's finding (2026-11-13, CLI 1.0.98, `meta/eval-results.md`): "Review my changes." loaded the `review` skill in 5 of 6 runs and started a reviewer in 0 of 6; five said they read the small diff directly instead of dispatching, which `review.md` Step 1 does not allow. A review asked for through the plan line may load the skill there and still run no reviewer.
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

### B-483 · `warehouse-map-check` reports `current` for a map whose tables were deleted, or that has no full-pass stamp
**Filed against:** v0.98.4 (2026-11-05)
**Priority:** P3 · **Effort:** M · **Invariants:** none
**Status:** Open; found by the fresh-session review of WSD-122's design and re-run (executed on scratch fixtures with the shipped check). It compares file write times only: deleting a mapped table's SQL leaves `WAREHOUSE_MAP current`, exit 0 (a rename too, in the review's run), and one row appended to a stale map with no full-pass line turned it `current` (exit 1 to 0), which the scoped pass can still do. `add-warehouse-load` step 1 prefers a `current` map; its "confirm the entities still exist" is the only backstop.
The same clock reads `stale` in a fresh clone of an unchanged commit (executed), so the answer depends on who cloned when.
Candidate: the check prints a digest of the warehouse artifacts' paths and contents, a full pass copies it into the stamp line, a map is current when the digests match and stale without one; red cases: the three runs above. e003c8c8 rejected parsing the Coverage line, and the review's runs showed git commit time wrong in both directions.
### B-490 · The agent can rewrite the hook registrations
**Filed against:** v0.98.4 (2026-11-10)
**Priority:** P2 · **Effort:** S to M · **Invariants:** #3 #5
**Status:** Open; maintainer-requested external audit. Done for 0.99.0: part (a), fail closed (maintainer, in chat 2026-11-13: the guard command exits 2 when its interpreter is not found, its entry sets `"onFailure": "block"`), and, with B-506, the doctor's `Wired hook shell` row is `MISSING` for an interpreter not on `PATH`. Reproduced: a write of `{ "hooks": {} }` to `.claude/settings.json` exits 0.
Decided 2026-11-19 (maintainer, in chat; WSD-132), the narrow block: the guard refuses a settings write whose result no longer registers `guard.ps1`, and any agent write to `.claude/hooks/*.ps1` or `.github/hooks/hooks.json`; `/adopt` and the upgrade checklist keep editing other settings. Left: implement it, guarded, step 4. Brief: `.claude/plans/2026-11-10-external-audit-briefs.md`.
B-489's round-2 attack: the guard does not refuse a Write to `.claude/settings.json` or `.claude/hooks/guard.ps1` on either surface (settings.json run; guard.ps1 by the same logic, not run).
### B-497 · `/review` hands back six reviewers' findings with no merge, de-duplication or verdict rule
**Filed against:** v0.98.4 (2026-11-10)
**Priority:** P3 · **Effort:** S to M · **Invariants:** #1 #7
**Status:** Open. Shipped 2026-11-17 for 0.99.0: `/review` merges findings on one `file:line`, maps every reviewer's scale to blocker, should-fix or note, ends with one verdict line naming the blocker count and the reviewers returned or missing, and names a reviewer that errors as missing; existing debt entries and justified bloat do not block; `bloat-radar` and `solid-check` agree on delegation, the lines-per-file heuristic is gone, and the commented-out-code threshold is one line everywhere.
Remaining: merge the three Haiku reviewers (convention-check, bloat-radar, debt-radar; B-427) into one pass, measured with B-467's 12-defect harness, and do the de-duplication there. Brief: `.claude/plans/2026-11-10-external-audit-briefs.md`.
### B-499 · Credential forms the write guard still does not read after B-487
**Filed against:** v0.98.4 (2026-11-10)
**Priority:** P3 · **Effort:** M · **Invariants:** #3 #5 #7
**Status:** Open; B-487's step-4 attacks (a sub-session's runs, not re-run). Not read: an auto-property initializer `public string Password { get; set; } = "…"`, Redis `password=`, URL userinfo outside a connection-string key, a backtick string, a `Dictionary` initializer, `new NetworkCredential(…)`, `SetEnvironmentVariable`, `password?:`, a `"""` or `$"` literal, a `??` or `||` fallback, VB; and B-487's stated limits: `string.Join`, `;;`, a quote inside the literal, a JDBC neighbour, a `:` in a neighbouring key, the computed key `['password']:`, a no-break space or vertical tab, a one-pair literal standing alone, a variable between the pieces (`"Server=" + host + ";Password=…"`, the commonest real shape), VB `&`, `+=`, `string.Concat`, `AppendFormat`, `.Add(` or `.push(` pieces, an unkeyed password opening with `@`; and its false blocks on a mask, message or SQL text that is a piece of a longer string.
Candidate: decide per form whether the guard or CI secret scanning owns it; extending the guard is guarded, step 4, and each form needs its false-block survey (B-487 audited 145 repo and 476 npm files).
B-489's round-2 attack: the patch (U+FEFF header, repeated `*** Move to:`) and unparseable-input gaps are fixed (B-499 part 1); VS Code agent-mode `insert_edit_into_file`, `edit_notebook_file`, `multi_replace_string_in_file` and Claude Code's `MultiEdit` items are now read, with every path field of an item deciding (checked against the VS Code 1.146 package schema, not a live hook event; two attack rounds run on it). Open from those attacks: an item path under an unknown key such as `uri`, a non-string path, and `code` under an unknown tool name without `explanation`. Round 2 left, pre-existing: a `toolArgs` array, `str_replace_based_edit_tool`, an unknown tool with a string `tool_input`, and a nested `input:{input}` are not read as writes.
### B-502 · A disabled skill's exemplar line is dropped by the update after the one that disables it
**Filed against:** v0.98.5 (2026-11-11)
**Priority:** P3 · **Effort:** S · **Invariants:** #7
**Status:** Open; found by B-480's scope check (run on dist/dotnet: install, a "For a concrete current instance" line added to `add-warehouse-load`, the skill disabled in LEARNINGS.md; the first update kept the line in `.claude/disabled-skills/add-warehouse-load/SKILL.md`, the second, exit 0, replaced it without the line). The update reads exemplar lines only under `.claude/skills/`.
Candidate: read a disabled skill's line from `.claude/disabled-skills/<name>/SKILL.md` too; red case from that run. Guarded, step 4.
### B-504 · The reviewers are read-only in prose only: a shell on Claude Code, every tool on Copilot
**Filed against:** v0.98.6 (2026-11-13)
**Priority:** P2 · **Effort:** S for a tool list, M to drop the shell · **Invariants:** #2 #5 #7
**Status:** Open; vendor-guidance audit and its adversarial review (read, not run). The seven `.claude/agents` files list `PowerShell`; the six `.github/agents` wrappers have no `tools:`, which Copilot reads as all tools; both vendors say a tool list is the boundary and an instruction is not.
Decided 2026-11-19 (maintainer, in chat; WSD-133): keep the shell. The six wrappers get `tools: ["read", "search", "execute"]` and the shipped text stops calling the reviewers read-only; dropping the shell (the hash recompute moved to the parent in six agents, six wrappers, `review.md` and `security-gate.md`) is rejected. Blocked: Copilot access ended 2026-11-18, and the change needs a host check that a reviewer starts, reads its bundle and has no edit tool.
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
B-514 (2026-11-15, Claude Code and Copilot CLI): an unreviewed draft is called as often as an approved skill (6 of 6 each on each host, first thing, through the host's skill list), and B-515 then found no draft missing a step (0 of 8; none written on 4,999 files). Maintainer 2026-11-15: drafts stay live; B-515 closed.
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
### B-520 · Smaller leftovers of the 2026-11-14 reviews
**Filed against:** v0.98.6 (2026-11-14)
**Priority:** P3 · **Effort:** S each · **Invariants:** none
**Status:** Open; each stood its attack in this narrowed form. (1) Headless `/adopt` (about 6.8 KB) into its own file. (2) When a live eval run is hand-checked, keep its scrubbed transcript and verdict as a self-test fixture: grader defects were found by reading transcripts, not by the hand-written fixtures. (3) Time `UpdateDelivery.Tests.ps1` per case, then replace only the setup installs whose result no case asserts.
(4) One meta case asserting the five `Test-IsLinkEntry` copies are identical and none uses a bare `-band ReparsePoint`, in place of the five per-copy cases. (5) `build.ps1`'s second ownership listing (`:383-390`): the Bash oracle it replaced is gone (B-157), so keep or delete it on purpose.
(6) `BacklogHygiene.Tests.ps1:206` reads commit subjects only, so a closure recorded in a body under the 72-character subject rule (WSD-125) escapes its open-item check: read bodies too, after checking the last 200. (7) `release.ps1:766` builds `v<version>: <summary>` with no tier and no length bound.
### B-524 · `/bootstrap` and `/adopt` lose their write steps when Claude Code compacts the conversation
**Filed against:** v0.98.6 (2026-11-15)
**Priority:** P3 · **Effort:** S · **Invariants:** #1 #7
**Status:** Open; maintainer-requested review against current Anthropic guidance, 2026-11-15, and its attack (vendor pages read; not observed on a host). Claude Code's skills page: after a compaction it re-attaches only "the first 5,000 tokens" of an invoked command and does not re-read the file. `bootstrap.md` is 57 KB (dotnet) and its write steps, completion gate and report start at byte 23,055; `adopt.md` is 43 KB, and its Phase 7 deletes `.claude/adoption-pending.json` before it runs `/bootstrap`.
Trigger: both commands pause for the developer, and the best-practices page says a session past about 200K tokens that sits idle is compacted before its one-hour cache expires; a gateway held at 200K or a typed `/compact` does the same. No recorded run reached that size (a headless `/bootstrap` on the fixtures costs 1.10 to 1.20 USD).
Candidate: first read the parent session's size on B-466's sized repositories; if it nears 200K, one line near the top of `adopt.md` and the three `bootstrap.md` copies (after a compaction, read this file again before the next phase), or the phases as supporting files. Guarded (`src/stacks/*/files/.claude/**`), text-only.
### B-525 · No standing scenario has run on Fable 5.2, the model Claude Code now moves saved Fable 5.1 sessions to
**Filed against:** v0.98.6 (2026-11-15)
**Priority:** P3 · **Effort:** S · **Invariants:** none
**Status:** Open; same review and attack. `meta/eval-results.md` names Sonnet 5.5 178 times, Opus 5.5 24 times and no Fable model as a run's model; every run in B-425, B-514 and B-515 is Sonnet 5.5. Claude Code 2.1.321 moves a saved `claude-fable-5-1` to Fable 5.2 on Pro, Max and Ultra plans, and `DEVELOPING.md`'s per-release check asks for a rerun when the model changed.
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

### B-531 · Full implementation plans, each adversarially reviewed, for the items decided on 2026-11-19
**Filed against:** v0.98.6 (2026-11-19)
**Priority:** P2 · **Effort:** M · **Invariants:** none
**Status:** Open; maintainer request in chat 2026-11-19, to start once B-416's measurement is reported and the tree is clear. One plan each for the review line's shipping change (if the maintainer says ship; WSD-131), the guard's narrow wiring block (B-490, WSD-132), the reviewers' tool lists and wording (B-504, WSD-133) and the Copilot measurement (B-530).
Each plan names the files, the red-first case, the verification recipe and what could be let through, and goes through one adversarial review by a session that did not write it, with the review's executed attack recorded in the plan.

### B-532 · Re-read current host guidance for what the framework ships that is now outdated or can be deleted
**Filed against:** v0.98.6 (2026-11-19)
**Priority:** P2 · **Effort:** M · **Invariants:** #2 #5 if it ships
**Status:** Open; maintainer request in chat 2026-11-19, after B-531. Read what Claude Code, Copilot CLI and VS Code have published since the 2026-11-15 guidance review (B-524 to B-527) and list each shipped file, hook or wording that a host feature has made unnecessary or wrong.
The maintainer's example: whether the shipped `CLAUDE.md` stub can go if every supported host now reads `AGENTS.md` (Invariant #2 keeps it today as the import and rules carrier). Report first; each deletion is then its own change, checked on a host.

### B-533 · Review the testing strategy: whether end-to-end tests belong in it, and what published practice says about releasing fast
**Filed against:** v0.98.6 (2026-11-19)
**Priority:** P2 · **Effort:** M · **Invariants:** none
**Status:** Open; maintainer request in chat 2026-11-19, after B-532. Lay out what the gates cover today (hook and installer tests, `validate-dist`, the paid agent evals, CI at a median 28 minutes) against published guidance, including what Anthropic has said publicly about how it tests and ships Claude Code at its pace, attributed to its source and not inferred.
Answer whether an end-to-end layer (install, then a real agent session on a fixture, on each host) should be a standing part, what it would cost a release, and what it would replace. Report before any change; the four numbers a release now prints (B-522, done 2026-11-19) are its baseline.
