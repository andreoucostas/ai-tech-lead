# Framework backlog

Open work only, at most 40 entries (`AGENTS.md`, "Records"). Take the first unblocked row of the
pick-up order, one item per fresh session; the tier is read off the changed paths at work time. An
entry is its heading, filed-against line, priority line and at most three lines of status; the
evidence lives in the plans and decisions it names. An empty backlog says "No open entries." on its
own line under Open entries; the hygiene tests refuse that line beside an entry. A session that
finds an adjacent defect outside AGENTS.md's four guarded harms, which no field report raised,
closes it per WSD-106 with one CLOSED line in `meta/BACKLOG-DONE.md` instead of filing it here.
Full pre-reset text: `git show 36babcaf:meta/BACKLOG.md`.

## Pick-up order — ranked 2026-09-30 (WSD-105 probe); re-ranked 2026-10-01 (WSD-107, field replies); B-331 to the idle queue 2026-10-02 (WSD-109); B-346 filed and done the same day; B-330 done and B-336 closed by measurement 2026-10-03; B-331 done, B-326 done and B-348 filed, and B-327, B-328, B-329 and B-337 done 2026-10-04; B-352 to B-354 filed 2026-10-05 (Fable review, consumer host reply), B-352 and B-354 done the same day (WSD-110), B-353 done the same day, B-356 filed the same day (maintainer request; first numbered B-355 at 254c904f, renumbered because 99253721 closed a different B-355); B-357 filed 2026-10-06 (the 0.94.0 Copilot skill wrappers); B-359 filed 2026-10-07 (an attack round on those wrappers); idle queue added 2026-09-30 (WSD-106); every earlier entry closed 2026-09-29 (WSD-105)

| Rank | Item | Why here |
|---|---|---|
| 1 | B-348 | False-green class split from B-326: the agent's own security pass on Copilot CLI; measure before changing the carrier or hook |
| 2 | B-357 | Possible false green or stalled review from a new wrapper on github.com; measure before changing its invocation |
| 3 | B-356 | Maintainer idea with no field report; the decoy's false-offer rate is measured before any carrier wording |
| 4 | B-359 | Latent false green: no shipped command carries such a value today |

## Open entries

### B-348 · Measure whether the agent's own security pass on Copilot CLI runs the project's skill or the CLI's built-in agent
**Filed against:** v0.92.0 (2026-10-04)
**Priority:** P2 · **Effort:** S to M to measure · **Invariants:** #1 #7
**Status:** Open; false-green class, split from B-326 (`meta/host-certification.md`). On Copilot CLI 1.0.89 `/security-review` is
rewritten into an instruction to use the built-in Security Review Agent, while the carrier's security-pass rule and `route-prompt`'s
overlay name the bare `/security-review`. Measure agent-initiated passes on an installed fixture before changing either wording (WSD-107).

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

### B-356 · Measure a plan-step offer of a test, Conventions line or project-skill draft when a feature creates a repeatable operation
**Filed against:** v0.93.0 (2026-10-05)
**Priority:** P3 · **Effort:** M to measure, S to change · **Invariants:** #1 #7
**Status:** Open; raised by the maintainer 2026-10-05, no field report (WSD-109). Between bootstraps nothing checks whether a feature created an
extension point or a third instance of an operation. Candidate: one plan-step carrier sentence naming the test, Conventions line or 3a-bis
draft the plan adds. Pre-register (B-346 method): one feature of each kind plus a plain CRUD decoy; the decoy's false-offer rate decides.





## Archived

B-219 and B-221 — see `meta/BACKLOG-DONE.md`.
B-225 and B-254 — see `meta/BACKLOG-DONE.md`.
