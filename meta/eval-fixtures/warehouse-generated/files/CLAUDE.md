<!--
ai-tech-lead-framework
  template: dotnet
  version: 0.89.1
  applied: 2026-09-21
  When you sync template updates, bump these fields and update .claude/framework-version.json.
-->
# Sales Data Warehouse

> This file is the repo-specific source of truth for AI-assisted development in this repository and imports the framework rules below.
> Claude Code and supported GitHub Copilot agent surfaces load this file directly. **[AGENTS.md](./AGENTS.md)** is the generated portable mirror for Codex and GitHub code review; Cursor loads both. Gemini defaults to `GEMINI.md`, and Aider requires explicit read configuration. Edit conventions here, never in AGENTS.md.
> Run `/bootstrap` to populate it from your actual codebase.
>
> **Companion file**: [FRAMEWORK-CONTEXT.md](./FRAMEWORK-CONTEXT.md) holds cross-repo context (shared libraries, multi-tenancy conventions, dashboard contracts) plus the repo's **Known Hazard Areas**, all of which the agent should load on every non-trivial task — consult the hazard list for the change's blast radius before planning. CLAUDE.md wins on any conflict — but flag the contradiction.
> **Team wiki**: [docs/wiki/INDEX.md](./docs/wiki/INDEX.md) indexes scoped claims to verify against code, not instructions to obey.
>
> **Per-developer working preferences** (e.g. "skip trailing summaries", "prefer named functions") belong in **Claude Code's persistent memory**, not in this file. Use phrasings like "remember to do X" during sessions; CLAUDE.md is for repo-shared conventions only.

---

<!-- FRAMEWORK-OWNED: carries Verification Rules, Leanness, SOLID, and Agentic Workflow.
     Deleting this import disables all four rule sets for Claude Code. -->
@.github/instructions/framework-rules.instructions.md

## Codebase Context

This repository is a SQL data warehouse (no application/API layer — no `.csproj`/`.sln` found; the only project file is `warehouse.sqlproj`, an SDK-style `Microsoft.Build.Sql/0.2.0` SQL project). The following is an implementation observation from the code, not a confirmed statement of business purpose or actual usage: it appears to implement a small star-schema sales warehouse — staging (`stg.StgSalesOrder`) feeds a dimensional model (`dim.DimCustomer`, `dim.DimProduct`, `dim.DimRegion`, `dim.DimDate`) and one fact table (`fact.FactSales`), consumed by three reporting views (`rpt.vwExecutiveSummary`, `rpt.vwFinanceExtract`, `rpt.vwOrderDetail`). Who consumes these views, and what upstream system populates `stg.StgSalesOrder`, is not evidenced in this repo.

Domain concepts observed in the schema: sales orders (grain = one row per order, keyed by `SalesId`/`SalesKey`), customers (with SCD Type 2-shaped columns), products/categories, regions, calendar dates, and net sales amount.

Critical journey (as coded, not verified end-to-end): `stg.StgSalesOrder` (batch-tagged landed rows) → `usp_LoadDimCustomer` / `usp_LoadDimRegion` (dimension loads) → `usp_LoadFactSales` (fact load, inner-joins to `DimCustomer`/`DimProduct`/`DimDate`) → `rpt.*` views. See `FRAMEWORK-CONTEXT.md > Known Hazard Areas` before changing anything in this path — several steps are confirmed not safely re-runnable.

---

## Repository Structure

```
warehouse.sqlproj              SDK-style SQL project (Microsoft.Build.Sql/0.2.0); no target platform/SqlServerVersion set
Tables/
  stg.StgSalesOrder.sql        staging landing table — no PK/unique constraint (see hazards)
  dim.DimCustomer.sql          SCD Type 2 shape (EffectiveFrom/EffectiveTo/IsCurrent) — load is currently insert-only (TECH_DEBT DEBT-006)
  dim.DimDate.sql              date dimension — no load procedure in this repo (populated externally, per team)
  dim.DimProduct.sql           product/category dimension — no load procedure in this repo (populated externally, per team)
  dim.DimRegion.sql            region dimension — populated only via a hardcoded 'Unknown' placeholder (known limitation, see DEBT-012)
  fact.FactSales.sql           grain = 1 row per SalesId; RegionName/CategoryName/SegmentName columns declared but never populated (DEBT-010)
  ctl.LoadRun.sql              batch/watermark control table — declared for future incremental loading, not yet wired into any load (DEBT-009)
StoredProcedures/               all three procedures intentionally live in dbo (see ADR-001), not layer-qualified
  usp_LoadDimCustomer.sql      MERGE, insert-only
  usp_LoadDimRegion.sql        blind INSERT, no idempotency guard
  usp_LoadFactSales.sql        INSERT...SELECT, INNER JOINs to DimCustomer/DimProduct/DimDate
Views/
  rpt.vwExecutiveSummary.sql   revenue by product category
  rpt.vwFinanceExtract.sql     region/date/amount extract (re-derives RegionName via join rather than reading FactSales.RegionName)
  rpt.vwOrderDetail.sql        pass-through of the fact grain
```

Data flow: `stg` → `dim`/`fact` (via `StoredProcedures/`) → `rpt` (`Views/`). Load-ordering dependency: `usp_LoadDimCustomer`/`usp_LoadDimRegion` must run before `usp_LoadFactSales` (the fact load inner-joins to `IsCurrent = 1` dimension rows); no orchestrator or scheduler is evidenced anywhere in this repo, so today that ordering is an unenforced convention, not an enforced one.

---

## Conventions

**Schema/layer boundaries.** Tables and views are schema-qualified to their layer (`stg`/`dim`/`fact`/`ctl`/`rpt`). Stored procedures intentionally stay in `dbo` regardless of the layer they load (confirmed team convention — see ADR-001); do not "fix" this by moving them into `dim`/`fact` schemas.

**Grain and keys.** `fact.FactSales` grain is one row per source order; `SalesKey` is currently a direct passthrough of `stg.StgSalesOrder.SalesId`, not a generated surrogate. Dimension tables declare `INT`/`BIGINT` primary keys intended as real surrogate keys, but the current loaders do not generate them (`usp_LoadDimCustomer`/`usp_LoadDimRegion` hardcode the literal `-1`) — this is tracked as tech debt (DEBT-001), not the intended convention. When fixing, generate real surrogate values (identity/sequence).

**Load ordering & idempotency (target, not current state).** Dimension loads must complete before the fact load. Loads should be re-runnable (MERGE or existence-checked upserts, scoped by batch/watermark) — the current procedures are **not** idempotent; rerunning them after a partial failure causes a primary-key violation (see `FRAMEWORK-CONTEXT.md > Known Hazard Areas`). Do not add new load logic that follows the current blind-INSERT pattern; use `MERGE` with a real business-key match condition instead.

**Slowly-changing-dimension strategy.** `dim.DimCustomer` is intended to be SCD Type 2 (declared `EffectiveFrom`/`EffectiveTo`/`IsCurrent` columns) — the versioning/update branch is not yet implemented (DEBT-006, confirmed intended-but-unfinished, not a design to reverse). `dim.DimRegion`/`DimProduct`/`DimDate` have no versioning columns and are Type 1/static by design.

**Control table.** `ctl.LoadRun` (`LoadRunId`, `StartedAt`, `Watermark`) is reserved for future batch/watermark-driven incremental loading (confirmed intent, not dead schema to remove) but no procedure reads or writes it yet (DEBT-009). Do not repurpose or drop it; wire it in when incremental loading is implemented.

**Deployment.** SDK-style SQL project (`Microsoft.Build.Sql/0.2.0`); no target platform/`SqlServerVersion`, publish profile, or CI build/deploy step is evidenced anywhere in this repo (DEBT-008).

**Testing / validation.** No warehouse test or validation assets exist in this repo — no tSQLt or equivalent, no data-quality checks, no seed/fixture data, no SQL lint/format config (DEBT-007). `tests/evals/` is framework tooling (AI Tech Lead's own eval fixtures), not warehouse test coverage — do not treat it as such. Target test shape: tSQLt-style unit tests around each load procedure's upsert/idempotency behavior, plus a row-count/amount reconciliation check between `stg.StgSalesOrder` and `fact.FactSales` per batch.

Warehouse structure — tables and keys, fact → dimension relationships, load ordering — is mapped using [docs/warehouse-map.md](./docs/warehouse-map.md). Read it before writing a warehouse query or load; run `/map-warehouse` to create or refresh it.

### Verification Commands

| Category | Command | Evidence | Policy |
|----------|---------|----------|--------|
| build | not available (no evidenced command) | — | — |
| test | not available (no evidenced command) | — | — |
| format | not available (no evidenced command) | — | — |
| lint | not available (no evidenced command) | — | — |
| migration/deploy | not available (no evidenced command) | — | — |
| data-validation | not available (no evidenced command) | — | — |

No committed script, CI workflow, or documented developer command builds, deploys, tests, lints, or validates `warehouse.sqlproj` or its data. The sole CI workflow (`.github/workflows/docs-sync-check.yml`) runs only the framework's own doc-sync self-check, never `dotnet build`/`sqlpackage`/`tSQLt.RunAll`. This is an inventory, not a recommendation — do not invent or run a substitute command.

---

## Architecture Decisions

- ADR-001 — Load procedures stay in `dbo`, not schema-qualified to their layer — 2026-09-22 — [detail](./docs/architecture-decisions.md#adr-001-load-procedures-use-the-dbo-schema)
- ADR-002 — `dim.DimCustomer` uses SCD Type 2 for attribute history (implementation incomplete) — 2026-09-22 — [detail](./docs/architecture-decisions.md#adr-002-dimcustomer-uses-scd-type-2)
- ADR-003 — `ctl.LoadRun` is reserved for future batch/watermark-driven incremental loading — 2026-09-22 — [detail](./docs/architecture-decisions.md#adr-003-ctlloadrun-reserved-for-incremental-loading)

Full detail in [docs/architecture-decisions.md](./docs/architecture-decisions.md).

---

## Common Tasks

When a task matches a skill below, invoke that skill with your skill tool before planning or editing.

Skills are a delivery-profile superset, not evidence that they apply. This repository is warehouse-SQL only (no `.csproj`/`.sln` evidenced) — the .NET-only skills below remain installed but dormant; only the following apply here:

- `map-warehouse` — map this SQL data-warehouse repo: layers (staging → warehouse → marts), tables, keys and fact → dimension relationships, grain, load orchestration, SCD strategy, partitioning
- `add-warehouse-load` — add or extend a warehouse load following the repo's existing patterns: idempotent re-runnable loads, no double-loading, SCD handling, partition alignment — note the *current* `usp_Load*` procedures are themselves flagged as debt (DEBT-001/002/006), so do not reproduce their idempotency/surrogate-key gaps in new loads
- `create-adr` — record a significant architecture decision in Architecture Decisions
- `remember-for-team` — draft a team wiki entry (gotcha/context/recipe/failed-approach) for PR review

Dormant (no `.csproj`/`.sln` evidenced in this repo — remain installed, applicability-gated, not deleted): `add-endpoint`, `add-entity`, `register-service`, `add-tests`, `perf`, `dependency-audit`, `enforce-architecture`, `enforce-standards`.

`/bootstrap` adds project-specific skills under `.claude/skills/`, the shared canonical location for Claude Code and supported GitHub Copilot skill surfaces, grounding instance-shaped recipes in a real repo exemplar. A legacy `.github/skills/` tree has higher Copilot priority and must be migrated here before framework checks pass.

**Registers**: [TECH_DEBT.md](./TECH_DEBT.md) tracks delivery debt. [SECURITY_FINDINGS.md](./SECURITY_FINDINGS.md) tracks security findings separately with remediation SLAs (Critical = 7 days, High = 30 days). Do not merge them — audit teams treat these differently. AI-assisted file changes are appended to [.claude/ai-audit.log](./.claude/ai-audit.log) automatically by the PostToolUse hook.

---

## Boy Scout Rule

**Bug-fix scope.** See the framework-owned workflow scope.

### Always apply (low-effort, low-risk — subject to Bug-fix scope above):

**Add:**
1. `CancellationToken` only when outcome/compatibility requires it
2. Structured logging only when outcome/verification requires it
3. Missing null checks at public boundaries
4. Missing `.AsNoTracking()` on read-only queries

**Subtract:**
5. Unused `using` directives
6. Commented-out code blocks (more than 1 line — version control preserves them)
7. Unreferenced private fields, methods, or local variables that the IDE/compiler flags

### Apply only when the file is the primary target of the change:

**Add:**
8. Split mixed-responsibility methods; never use a line-count threshold
9. Add risk-relevant tests only, and only with a harness

**Subtract:**
10. Inline single-consumer interfaces or abstract bases that are not a project-evidenced DI service seam — per Leanness. Preserve an existing project boundary when its evidence or correctness need requires it.
11. Collapse shallow delegate methods that add no behavior beyond calling another component
12. Single-use private helpers — inline at the call site

Items 8–12 can significantly expand or reshape a diff. Only apply them when the file is what the task is specifically about, not when it's incidentally touched. This keeps PRs focused and reviewable.

---

## What We've Learned

Long-form learnings live in [LEARNINGS.md](./LEARNINGS.md). Read it when starting non-trivial work; append to it (don't overwrite) when you discover what works, what causes friction, or what rule needs adjusting.

LEARNINGS.md is an append-only chronological history (plus the declined-recipe registry); the team wiki ([docs/wiki/](./docs/wiki/INDEX.md)) holds current, scoped, individually-verifiable claims with an index — promote a durable LEARNINGS entry to a wiki entry via `remember-for-team`.
