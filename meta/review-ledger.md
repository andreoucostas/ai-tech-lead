# Review ledger

One row per release, written by `.claude/scripts/release.ps1` and committed with the release it
describes. It records **whether** an independent review happened and what the reviewer re-ran --
never whether the review was any good, which no gate here can judge. A `reviewer: none` row is a
legitimate outcome, deliberately not a silent one: it files a post-ship review item in
`meta/BACKLOG.md`. See root `CLAUDE.md` > Maintenance model.

| version | date | evidence |
|---------|------|----------|
| v0.44.0 | 2026-08-02 | reviewer: none -- post-ship review owed. **Discharged 2026-08-03** (B-86): adversarial pass by codex CLI `gpt-5.6-sol`, every finding re-run here; 8 re-runs incl. the `HarnessIntegrity` red-test under Windows PowerShell 5.1. Filed B-92 (P2), B-93 (P2), B-94 (P3). |
