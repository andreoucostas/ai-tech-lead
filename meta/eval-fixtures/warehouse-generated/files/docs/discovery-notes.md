# Repository Knowledge Discovery Notes

> Written by `/bootstrap`'s shared A8 pass. Detailed continuation for the summary in
> `FRAMEWORK-CONTEXT.md > Repository Knowledge Discovery`. This file is created once and then
> updated by future discovery runs — it does not overwrite owner-authored content elsewhere.

## 2026-09-30 — initial bootstrap discovery

### Actual reads (24 files)

All of `Tables/*.sql` (7), `Views/*.sql` (3), `StoredProcedures/*.sql` (3), `warehouse.sqlproj`,
`framework-ownership.json`, `AGENTS.md`, `LEARNINGS.md`, `docs/wiki/INDEX.md`,
`docs/ARCHITECTURE.md`, `specs/README.md`, `TECH_DEBT.md`, `FRAMEWORK-CONTEXT.md`,
`docs/architecture-decisions.md`, `.claude/ai-audit.log`, plus `git log`/`git show` (inventory-only,
not a content read).

### Excluded (framework-owned, per `framework-ownership.json`)

`.claude/**`, `.github/**` (other than confirming `.github/workflows/docs-sync-check.yml`'s
content is the framework's own docs-sync guardrail, not a warehouse pipeline), most of `docs/**`,
`tests/evals/**`, `LICENSES/**`, `NOTICE-ai-tech-lead.md`, `scripts/**`.

### Inaccessible / not present

- `analysis/` — named in the bootstrap task brief but does not exist in this repository (`Glob`
  confirmed empty).
- No root `README.md`, `Makefile`, or publish profile exists.

### Unresolved — bounded continuation

1. **`stg.StgSalesOrder` population** — no producer exists anywhere in this repo. Next useful
   source: an external ETL/ingestion repo, or a maintainer confirming how staging data arrives.
2. **`dim.DimProduct` / `dim.DimDate` population** — same: no producer in this repo. Next useful
   source: a maintainer confirming whether these are seeded by a separate reference-data process,
   or whether loaders for them are simply missing (tracked as `TECH_DEBT.md` DEBT-006 either way).

### Outcome

Every scoped finding from this pass (broken/incomplete loads, a dead control table, dead
denormalized columns, the `dbo`-vs-layer-schema naming inconsistency) had an existing, more
specific owner — `TECH_DEBT.md` or `docs/architecture-decisions.md` — and was routed there rather
than duplicated as a wiki entry. No new `.claude/skills/` draft was created: the three existing
load procedures are all debt-flagged, so there is no clean in-repo exemplar to codify as a
reviewed pattern yet (see `AGENTS.md > Common Tasks > add-warehouse-load`).
