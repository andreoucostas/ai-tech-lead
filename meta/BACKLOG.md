# Framework backlog

Open work only, at most 40 entries (`AGENTS.md`, "Records"). Take the first unblocked row of the
pick-up order, one item per fresh session; the tier is read off the changed paths at work time. An
entry is its heading, filed-against line, priority line and at most three lines of status; the
evidence lives in the plans and decisions it names. An empty backlog says "No open entries." on its
own line under Open entries; the hygiene tests refuse that line beside an entry.
Full pre-reset text: `git show 36babcaf:meta/BACKLOG.md`.

## Pick-up order — ranked 2026-09-30 (WSD-105 probe); every earlier entry closed 2026-09-29 (WSD-105)

| Rank | Item | Why here |
|---|---|---|
| 1 | B-325 | A decision for the user; a rules change, if any, follows it |

## Open entries

### B-325 · Decide what an agent does when recorded project knowledge contradicts the literal request
**Filed against:** v0.91.0 (2026-09-30)
**Priority:** P3 · **Effort:** S to decide, M if the rules change · **Invariants:** #1 #7
**Status:** Open; needs the user's decision. In the WSD-105 probe (`meta/eval-results.md`, 2026-09-30) all six agents with the
`/bootstrap` fact saw that `fact.FactSales.LoadRunId` is not a `ctl.LoadRun` key; five still joined it behind a caveat, one asked.
Choose a rule ("never build on a relationship the project records as false; deliver what is answerable, name the gap") or the caveated join.

## Archived

B-219 and B-221 — see `meta/BACKLOG-DONE.md`.
B-225 and B-254 — see `meta/BACKLOG-DONE.md`.
