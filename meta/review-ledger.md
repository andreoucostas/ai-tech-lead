# Review ledger

One row per release, written by `.claude/scripts/release.ps1` and committed with the release it
describes. It records **whether** an independent review happened and what the reviewer re-ran --
never whether the review was any good, which no gate here can judge. A `reviewer: none` row is a
legitimate outcome, deliberately not a silent one: it files a post-ship review item in
`meta/BACKLOG.md`. See root `CLAUDE.md` > Maintenance model.

| version | date | evidence |
|---------|------|----------|
| v0.44.0 | 2026-08-02 | reviewer: none -- post-ship review owed. **Discharged 2026-08-03** (B-86): adversarial pass by codex CLI `gpt-5.6-sol`, every finding re-run here; 8 re-runs incl. the `HarnessIntegrity` red-test under Windows PowerShell 5.1. Filed B-92 (P2), B-93 (P2), B-94 (P3). |
| v0.45.0 | 2026-08-05 | B-97: implemented by codex (gpt-5.6-sol lead, terra/luna delegated); reviewed independently by Claude Opus 5 in a separate session, which re-ran three gate red-tests itself -- marker-expansion inventory (planted a deleted hash-marker snippet in route-prompt: old check printed OK, new gate exit 1), section-path citation (planted CLAUDE.md > SOLID: exit 1) and carrier-import (removed the import line: exit 1) -- plus a false-positive guard (prose 'CLAUDE.md > Conventions wins on any conflict' must NOT fire: it did not). Found four defects absent from the implementer's report, incl. a .ps1 gate blind to 15 of 117 markers and a .sh twin that could never finish. B-102: NO independent review -- found, implemented and verified in one session by one model; post-ship review filed as B-103 per Maintenance model #2. Its red-test (jq hidden, real python present) was observed going from exit 0 'write-guard INACTIVE' to exit 2 'Blocked write', against both src and the composed dist. |
