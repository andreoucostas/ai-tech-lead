# Framework backlog

Open work only, at most 40 entries (`AGENTS.md`, "Records"). Take the first unblocked row of the
pick-up order, one item per fresh session; the tier is read off the changed paths at work time. An
entry is its heading, filed-against line, priority line and at most three lines of status; the
evidence lives in the plans and decisions it names. An empty backlog says "No open entries." on its
own line under Open entries; the hygiene tests refuse that line beside an entry. A session that
finds an adjacent defect outside AGENTS.md's four guarded harms, which no field report raised,
closes it per WSD-106 with one CLOSED line in `meta/BACKLOG-DONE.md` instead of filing it here.
Full pre-reset text: `git show 36babcaf:meta/BACKLOG.md`.

## Pick-up order — ranked 2026-09-30 (WSD-105 probe); re-ranked 2026-10-01 (WSD-107, field replies); B-331 to the idle queue 2026-10-02 (WSD-109); B-346 filed and done the same day; B-330 done and B-336 closed by measurement 2026-10-03; B-331 done, B-326 done and B-348 filed, and B-327, B-328, B-329 and B-337 done 2026-10-04; B-352 to B-354 filed 2026-10-05 (Fable review, consumer host reply), B-352 and B-354 done the same day (WSD-110), B-355 filed the same day (maintainer request); idle queue added 2026-09-30 (WSD-106); every earlier entry closed 2026-09-29 (WSD-105)

| Rank | Item | Why here |
|---|---|---|
| 1 | B-348 | False-green class split from B-326: the agent's own security pass on Copilot CLI; measure before changing the carrier or hook |
| 2 | B-353 | Leak class; state the floor first, widen the patterns only on evidence |
| 3 | B-355 | Maintainer idea with no field report; the decoy's false-offer rate is measured before any carrier wording |

## Open entries

### B-348 · Measure whether the agent's own security pass on Copilot CLI runs the project's skill or the CLI's built-in agent
**Filed against:** v0.92.0 (2026-10-04)
**Priority:** P2 · **Effort:** S to M to measure · **Invariants:** #1 #7
**Status:** Open; false-green class, split from B-326 (`meta/host-certification.md`). On Copilot CLI 1.0.89 `/security-review` is
rewritten into an instruction to use the built-in Security Review Agent, while the carrier's security-pass rule and `route-prompt`'s
overlay name the bare `/security-review`. Measure agent-initiated passes on an installed fixture before changing either wording (WSD-107).

### B-353 · State the write guard's credential floor in the shipped docs, then decide on widening it
**Filed against:** v0.93.0 (2026-10-05)
**Priority:** P2 · **Effort:** S (docs) to M (patterns) · **Invariants:** #1 #7
**Status:** Open; leak class (Fable review). Exit 0 reproduced for a password inside `ConnectionStrings` in `appsettings.json`, an unquoted YAML
`password:`, and a Stripe `sk_live_` key under `"SecretKey"`; `enforcement-surfaces.md` calls write hard-blocks "Guaranteed" without saying the
floor is known key prefixes plus quoted credential literals. A 2026-10-05 scan found no real credential two widening candidates would add.

### B-355 · Measure a plan-step offer of a test, Conventions line or project-skill draft when a feature creates a repeatable operation
**Filed against:** v0.93.0 (2026-10-05)
**Priority:** P3 · **Effort:** M to measure, S to change · **Invariants:** #1 #7
**Status:** Open; raised by the maintainer 2026-10-05, no field report (WSD-109). Between bootstraps nothing checks whether a feature created an
extension point or a third instance of an operation. Candidate: one plan-step carrier sentence naming the test, Conventions line or 3a-bis
draft the plan adds. Pre-register (B-346 method): one feature of each kind plus a plain CRUD decoy; the decoy's false-offer rate decides.




## Archived

B-219 and B-221 — see `meta/BACKLOG-DONE.md`.
B-225 and B-254 — see `meta/BACKLOG-DONE.md`.
