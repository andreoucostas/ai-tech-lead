# Framework backlog

Open work only, at most 40 entries (`AGENTS.md`, "Records"). Take the first unblocked row of the
pick-up order, one item per fresh session; the tier is read off the changed paths at work time. An
entry is its heading, filed-against line, priority line and at most three lines of status; the
evidence lives in the plans and decisions it names. An empty backlog says "No open entries." on its
own line under Open entries; the hygiene tests refuse that line beside an entry. A session that
finds an adjacent defect outside AGENTS.md's four guarded harms, which no field report raised,
closes it per WSD-106 with one CLOSED line in `meta/BACKLOG-DONE.md` instead of filing it here.
Full pre-reset text: `git show 36babcaf:meta/BACKLOG.md`.

## Pick-up order — ranked 2026-09-30 (WSD-105 probe); re-ranked 2026-10-01 (WSD-107, field replies); B-331 to the idle queue 2026-10-02 (WSD-109); B-346 filed and done the same day; B-330 done, B-336 closed by measurement and B-331 done 2026-10-03; B-326 done and B-348 filed 2026-10-03; B-327, B-328 and B-329 done 2026-10-03; idle queue added 2026-09-30 (WSD-106); every earlier entry closed 2026-09-29 (WSD-105)

| Rank | Item | Why here |
|---|---|---|
| 1 | B-337 | Field-triggered: both reporting teams use VS Code Copilot or Copilot CLI, and setup text sends them to Claude Code |
| 2 | B-348 | False-green class split from B-326: the agent's own security pass on Copilot CLI; measure before changing the carrier or hook |

## Open entries

### B-337 · Tell Copilot-only teams how to run /bootstrap and /adopt, after observing it on Copilot
**Filed against:** v0.91.0 (2026-10-01)
**Priority:** P2 · **Effort:** S to observe, M to change · **Invariants:** #1 #7
**Status:** Open; field-triggered: report #6's and #8's teams use VS Code Copilot or Copilot CLI (`meta/field-reports.md`), yet the installer
handoff and each README's step-3 rows say `/bootstrap` and `/adopt` need a Claude Code session, while both ship as `.github/prompts`. Observe one
Copilot `/bootstrap` on a scratch install and record a dated row first; then the guarded installer text (requirement 4) and the READMEs.

### B-348 · Measure whether the agent's own security pass on Copilot CLI runs the project's skill or the CLI's built-in agent
**Filed against:** v0.92.0 (2026-10-03)
**Priority:** P2 · **Effort:** S to M to measure · **Invariants:** #1 #7
**Status:** Open; false-green class, split from B-326 (`meta/host-certification.md`). On Copilot CLI 1.0.89 `/security-review` is
rewritten into an instruction to use the built-in Security Review Agent, while the carrier's security-pass rule and `route-prompt`'s
overlay name the bare `/security-review`. Measure agent-initiated passes on an installed fixture before changing either wording (WSD-107).



## Archived

B-219 and B-221 — see `meta/BACKLOG-DONE.md`.
B-225 and B-254 — see `meta/BACKLOG-DONE.md`.
