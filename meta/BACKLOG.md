# Framework backlog

Open work only, at most 40 entries (`AGENTS.md`, "Records"). Take the first unblocked row of the
pick-up order, one item per fresh session; the tier is read off the changed paths at work time. An
entry is its heading, filed-against line, priority line and at most three lines of status; the
evidence lives in the plans and decisions it names. An empty backlog says "No open entries." on its
own line under Open entries; the hygiene tests refuse that line beside an entry. A session that
finds an adjacent defect outside AGENTS.md's four guarded harms, which no field report raised,
closes it per WSD-106 with one CLOSED line in `meta/BACKLOG-DONE.md` instead of filing it here.
Full pre-reset text: `git show 36babcaf:meta/BACKLOG.md`.

## Pick-up order — ranked 2026-09-30 (WSD-105 probe); re-ranked 2026-10-01 (WSD-107, field replies); B-331 to the idle queue 2026-10-02 (WSD-109); B-346 filed and done the same day; B-330 done and B-336 closed by measurement 2026-10-03; B-331 done, B-326 done and B-348 filed, and B-327, B-328, B-329 and B-337 done 2026-10-04; B-352 to B-354 filed 2026-10-05 (Fable review, consumer host reply), B-352 and B-354 done the same day (WSD-110), B-353 done the same day, B-356 filed the same day (maintainer request; first numbered B-355 at 254c904f, renumbered because 99253721 closed a different B-355); B-357 filed 2026-10-06 (the 0.94.0 Copilot skill wrappers); B-359 and B-360 filed 2026-10-07 (attack rounds on those wrappers); B-348's and B-356's wordings shipped unmeasured 2026-10-08 (WSD-111), their measurements kept open; B-361 and B-362 done 2026-10-09 without filing (field report #9), B-363 to B-366 closed by decision the same day (WSD-106); re-ranked 2026-10-09: B-367 filed at rank 1 (maintainer request, Angular v21-v22 audit) and B-368 done the same day, B-369 and B-370 closed by decision (WSD-106) and B-371 filed the same day (a reviewing session's build.ps1 run); B-372 done and B-373 and B-374 filed the same day (audit batch 2, its fresh-session attack and its CP437 leg); B-375 filed and done 2026-10-10 (audit batch 3); idle queue added 2026-09-30 (WSD-106); every earlier entry closed 2026-09-29 (WSD-105)

| Rank | Item | Why here |
|---|---|---|
| 1 | B-367 | Maintainer request: consumers on Angular 21.2 get stale v21/v22 guidance today; batches in the audit's order |
| 2 | B-348 | False-green class split from B-326: the agent's own security pass on Copilot CLI; its wording shipped unmeasured (WSD-111), so measure the pass under it |
| 3 | B-371 | False green in a guarded build script; it wrote into the real repository once on 2026-10-09 |
| 4 | B-357 | Possible false green or stalled review from a new wrapper on github.com; measure before changing its invocation |
| 5 | B-356 | Maintainer idea with no field report; its bullet shipped unmeasured (WSD-111), so the decoy's false-offer rate decides whether it stays |
| 6 | B-359 | Latent false green: no shipped command carries such a value today |
| 7 | B-360 | CI already stops it at checkout; a local check only moves the stop earlier |
| 8 | B-373 | Stall class, but only on a degenerate C# file; no field report |
| 9 | B-374 | False-green class, but only for a focus indented with non-ASCII whitespace on a non-UTF-8 console; no field report |

## Open entries

### B-367 · Bring the shipped Angular guidance to v21-v22: the remaining batches of the 2026-10-09 audit
**Filed against:** v0.94.0 (2026-10-09)
**Priority:** P1 · **Effort:** L (five batches) · **Invariants:** #1 #7
**Status:** Open; maintainer request 2026-10-09: consumers are on Angular 21.2 and keep within one or two majors of the latest, so the floor is v21. Batches 1 to 3 are B-368,
B-372 and B-375. Next, in order: docs and defaults (reversing 6879e5e8's neutral standalone and `inject()` wording, WSD-112), commands, agents and skills, then metrics
and evals; plan and sources: `.claude/plans/2026-10-09-angular-v21-v22-audit.md`.

### B-371 · `scripts/build.ps1` writes into the caller's process directory when that is not the repository
**Filed against:** v0.94.0 (2026-10-09)
**Priority:** P2 · **Effort:** S · **Invariants:** #1
**Status:** Open; found 2026-10-09 when a reviewing session ran a scratch clone's `build.ps1` with the real repository as process directory: `Set-Location`
anchors PowerShell's location, but `[System.IO.File]` resolves relative paths against the process directory, so the run wrote into the other tree (three
`framework-ownership.json` manifests cut to one entry, restored from HEAD) and, per that session, reported success. Anchor both, with a case seen red.

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

### B-348 · Measure whether the agent's own security pass on Copilot CLI runs the project's skill or the CLI's built-in agent
**Filed against:** v0.92.0 (2026-10-04)
**Priority:** P2 · **Effort:** S to M to measure · **Invariants:** #1 #7
**Status:** Open; false-green class, split from B-326 (`meta/host-certification.md`). Copilot CLI 1.0.89 sends `/security-review` to its
built-in Security Review Agent; the security-pass rule and `route-prompt`'s overlay now name this repository's skill instead, unmeasured (WSD-111).
Measure agent-initiated passes under it on an installed fixture; design: `.claude/plans/2026-10-08-b348-b356-plan-v2.md` Part A.

### B-357 · Measure whether Copilot code review on github.com loads the `review` or `security-review` skill wrapper, and what it posts
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





## Archived

B-219 and B-221 — see `meta/BACKLOG-DONE.md`.
B-225 and B-254 — see `meta/BACKLOG-DONE.md`.
