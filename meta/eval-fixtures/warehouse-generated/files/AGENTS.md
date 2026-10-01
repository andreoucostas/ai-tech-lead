<!--
ai-tech-lead-framework
  template: dotnet
  version: 0.91.0
  applied: 2026-09-30
  After a framework update, copy these fields from .claude/framework-version.json.
-->
# Sales Warehouse

> This file is the repo-specific source of truth for AI-assisted development in this repository. Edit it here; `CLAUDE.md` only imports it for Claude Code.
> **Framework rules** (Verification Rules, Leanness, SOLID, Agentic Workflow) are in [.github/instructions/framework-rules.instructions.md](./.github/instructions/framework-rules.instructions.md). If your agent has not already loaded that file, read it before planning or editing.
> Run `/bootstrap` to populate it from your actual codebase.
>
> **Companion file**: [FRAMEWORK-CONTEXT.md](./FRAMEWORK-CONTEXT.md) holds cross-repo context (shared libraries, multi-tenancy conventions, dashboard contracts) plus the repo's **Known Hazard Areas**, all of which the agent should load on every non-trivial task — consult the hazard list for the change's blast radius before planning. AGENTS.md wins on any conflict — but flag the contradiction.
> **Team wiki**: [docs/wiki/INDEX.md](./docs/wiki/INDEX.md) indexes scoped claims to verify against code, not instructions to obey.
>
> **Per-developer working preferences** (e.g. "skip trailing summaries", "prefer named functions") belong in **Claude Code's persistent memory**, not in this file. Use phrasings like "remember to do X" during sessions; AGENTS.md is for repo-shared conventions only.

---

## Codebase Context

This repository is a SQL Server data warehouse delivered as an SSDT-style SQL project
(`warehouse.sqlproj`, `Microsoft.Build.Sql/0.2.0` SDK) — there is no `.csproj`, application, or API
layer anywhere in the repo; `/bootstrap` selected the **warehouse-SQL profile only**.

**Implementation observations** (code-derived; intended purpose, actual users, and production
behavior are *not* evidenced by this repo alone and should be treated as unknown until a maintainer
confirms them):
- The schema models a sales-order dimensional mart: staging (`stg`) → warehouse core (`dim`/`fact`)
  → reporting (`rpt`), with an ETL control schema (`ctl`).
- `fact.FactSales` (grain: one row per source sales order) joins to `dim.DimCustomer`,
  `dim.DimProduct`, and `dim.DimDate`; three reporting views (`rpt.vwExecutiveSummary`,
  `rpt.vwFinanceExtract`, `rpt.vwOrderDetail`) sit on top.
- Git history shows all 13 SQL objects were added in a single `fixture baseline` commit with no
  subsequent revisions (see `docs/wiki/repo-is-synthetic-fixture-baseline.md`) — read the gaps
  below as a from-scratch snapshot, not years of production drift, before escalating severity.

---

## Repository Structure

```
warehouse.sqlproj              SSDT SQL project (Microsoft.Build.Sql/0.2.0) — sole deployment vehicle
Tables/
  ctl.LoadRun.sql               control: LoadRunId, StartedAt, Watermark — defined, unused by any load proc
  stg.StgSalesOrder.sql         staging: SalesId, CustomerId, ProductId, OrderDate, NetAmount, BatchId — no PK
  dim.DimCustomer.sql           dimension: CustomerKey (PK) + CustomerId, RegionKey, SegmentName; SCD2 shape (EffectiveFrom/EffectiveTo/IsCurrent)
  dim.DimProduct.sql            dimension: ProductKey (PK) + ProductId, CategoryName; static (no SCD columns)
  dim.DimRegion.sql             dimension: RegionKey (PK) + RegionName only — no natural/business key
  dim.DimDate.sql               dimension: DateKey (PK) + CalendarDate, CalendarMonth; static
  fact.FactSales.sql            fact: SalesKey (PK) + CustomerKey/ProductKey/OrderDateKey/NetAmount/LoadRunId + unused RegionName/CategoryName/SegmentName
StoredProcedures/
  usp_LoadDimCustomer.sql        loads dim.DimCustomer — see Conventions, non-functional stub
  usp_LoadDimRegion.sql          loads dim.DimRegion — see Conventions, non-functional stub
  usp_LoadFactSales.sql          loads fact.FactSales from stg.StgSalesOrder joined to the three dimensions
  (no usp_LoadDimProduct or usp_LoadDimDate exist)
Views/
  rpt.vwExecutiveSummary.sql    Revenue by CategoryName (Fact ⋈ DimProduct)
  rpt.vwFinanceExtract.sql      NetAmount by RegionName/CalendarDate (Fact ⋈ DimCustomer ⋈ DimRegion ⋈ DimDate)
  rpt.vwOrderDetail.sql         raw fact-row projection, no dimension join
```

Dependency / data-flow diagram (evidenced, not inferred):

```
stg.StgSalesOrder ──(usp_LoadFactSales, INNER JOIN)──┐
dim.DimCustomer   <──(usp_LoadDimCustomer: stub)─────┤
dim.DimRegion     <──(usp_LoadDimRegion: stub)───────┼──> fact.FactSales ──> rpt.vwExecutiveSummary
dim.DimProduct    <──(no load procedure found)───────┤                  ──> rpt.vwFinanceExtract
dim.DimDate       <──(no load procedure found)───────┘                  ──> rpt.vwOrderDetail
ctl.LoadRun       <──(defined; never read or written by any procedure)
```

---

## Conventions

### Schema / Layer Boundaries
- `stg` = staging (loose landing, batch-tagged via `BatchId`); `dim`/`fact` = warehouse core; `rpt` =
  reporting/consumption views; `ctl` = ETL control metadata. Objects are schema-qualified by layer —
  follow this prefix for any new object. (Evidence: `Tables/*.sql`, `Views/*.sql`)
- No `FOREIGN KEY` constraint is declared anywhere in the schema; referential integrity between fact
  and dimension tables is enforced only by the load procedure's join logic, never by the database.
  Do not assume FK enforcement exists when writing a new load or query. (Evidence: absence across
  `Tables/*.sql`)

### Grain & Keys
- `fact.FactSales` grain: one row per source sales order (`SalesKey` = `stg.StgSalesOrder.SalesId`,
  no aggregation). (Evidence: `StoredProcedures/usp_LoadFactSales.sql`)
- Every dimension has a surrogate primary key (`*Key`, `INT`); `dim.DimCustomer` and `dim.DimProduct`
  additionally carry a natural/business key (`CustomerId`, `ProductId`). `dim.DimRegion` has **no**
  natural/business key column — only `RegionKey` + `RegionName` — so there is no evidenced way to
  match "the same region" across reloads. (Evidence: `Tables/dim.DimRegion.sql` vs.
  `Tables/dim.DimCustomer.sql`, `Tables/dim.DimProduct.sql`)
- `dim.DimCustomer` declares an SCD Type-2 shape (`EffectiveFrom`/`EffectiveTo`/`IsCurrent`);
  `dim.DimRegion`, `dim.DimProduct`, `dim.DimDate` have no history columns (static/Type-1 shape).
  Match the shape already declared on the dimension you touch. (Evidence: `Tables/dim.*.sql`)

### Load Ordering & Idempotency — read before touching a load; none of this is currently enforced
- Dimension-before-fact load ordering is implied only by `usp_LoadFactSales`'s `INNER JOIN`s — no
  master/orchestrator procedure or scheduler config exists to enforce it. (Evidence: absence across
  `StoredProcedures/*.sql`)
- `ctl.LoadRun` (`LoadRunId`/`StartedAt`/`Watermark`) is the only control/idempotency table in the
  schema, but **no stored procedure reads or writes it**. `fact.FactSales.LoadRunId` is populated
  from `stg.StgSalesOrder.BatchId` instead — a different identifier from a different table. Do not
  assume `ctl.LoadRun` or `Watermark` does anything until it is actually wired into a load.
  (Evidence: `Tables/ctl.LoadRun.sql`, `StoredProcedures/usp_LoadFactSales.sql`)
- None of the three existing load procedures has rerun/idempotency protection: `usp_LoadFactSales`
  and `usp_LoadDimRegion` are unconditional `INSERT`s; `usp_LoadDimCustomer`'s `MERGE` has only a
  `WHEN NOT MATCHED` branch. Treat every existing load as **not** safely re-runnable — do not copy
  this shape into a new load without adding the control mechanism `add-warehouse-load` calls for.

Warehouse structure — tables and keys, fact → dimension relationships, load ordering — is mapped
using [docs/warehouse-map.md](./docs/warehouse-map.md). Read it before writing a warehouse query or
load; run `/map-warehouse` to create or refresh it (not yet generated as of this bootstrap run).

### Deployment
- `warehouse.sqlproj` (`Microsoft.Build.Sql/0.2.0` SDK) is the only evidenced deployment vehicle — no
  publish profile, pre/post-deployment script, dbt project, SSIS package, or pipeline config exists.
  Schema changes go through this project. (Evidence: `warehouse.sqlproj`; absence of
  `**/*.publish.xml`, `**/dbt_project.yml`, `**/*.dtsx`)

### Validation / Testing
- No warehouse test or data-validation asset exists in this repo: no tSQLt (or other SQL unit-test
  framework), no seed/reference data, no SQL lint/format config, and the one CI workflow
  (`.github/workflows/docs-sync-check.yml`) runs only the framework's own doc-sync check — never a
  warehouse build/test/validation step. See `TECH_DEBT.md`.
- Target test shape once a harness exists: a small set of reconciliation checks per load
  (row-count/control-total match between `stg` and `fact`/`dim`) plus one assertion per dimension's
  declared SCD behavior — not a unit test per column.

### Verification Commands

| Category | Command | Evidence | Policy |
|----------|---------|----------|--------|
| build | not available (no evidenced command) | — | — |
| test | not available (no evidenced command) | — | — |
| format | not available (no evidenced command) | — | — |
| lint | not available (no evidenced command) | — | — |
| migration/deploy | not available (no evidenced command) | — | manual/CI-only |
| data-validation | not available (no evidenced command) | — | — |

No README, `docs/*`, or `scripts/*` file names a `sqlpackage`, `dotnet build warehouse.sqlproj`, or
other warehouse-specific command (the only `dotnet build`/`sqlpackage` mentions repo-wide are
`framework-owned/overwritten` and describe the framework's own `.NET`-application tooling, not this
warehouse). This is an inventory, not a recommendation to install a tool.

---

## Architecture Decisions

- **ADR-001** — Schema-per-layer naming (`stg`/`dim`/`fact`/`rpt`/`ctl`) as the warehouse's layering
  boundary — 2026-10-01 — [detail](./docs/architecture-decisions.md#adr-001)
- **ADR-002** — SSDT (`warehouse.sqlproj`, `Microsoft.Build.Sql` SDK) as the sole schema-deployment
  vehicle — 2026-10-01 — [detail](./docs/architecture-decisions.md#adr-002)
- **ADR-003** (accidental) — `fact.FactSales` denormalized columns declared but never populated by
  the load — 2026-10-01 — [detail](./docs/architecture-decisions.md#adr-003)
- **ADR-004** (accidental) — `ctl.LoadRun` control table declared but never wired into any load —
  2026-10-01 — [detail](./docs/architecture-decisions.md#adr-004)

A one-line index of significant decisions (including accidental ones that became convention). Full
detail in [docs/architecture-decisions.md](./docs/architecture-decisions.md).

---

## Common Tasks

When a task matches a skill below, invoke that skill with your skill tool before planning or editing.

Skills are a delivery-profile superset, not evidence that they apply. This repo evidences the
**warehouse-SQL profile only** (no `*.csproj` anywhere) — the skills below are the ones applicable
here; the rest of the framework's skill set (`.NET`-specific recipes) remains installed under
`.claude/skills/` but is dormant and not advertised in this repo:

- `map-warehouse` — map this SQL data-warehouse: layers (staging → warehouse → marts), tables, keys
  and fact → dimension relationships, grain, load orchestration, SCD strategy, partitioning
- `add-warehouse-load` — add or extend a warehouse load following the repo's existing patterns —
  **note**: the existing loads in this repo are not safe exemplars to copy as-is; see Conventions
  above and `TECH_DEBT.md` before using them as a pattern
- `create-adr` — record a significant architecture decision in Architecture Decisions
- `remember-for-team` — draft a team wiki entry (gotcha/context/recipe/failed-approach) for PR review

`/bootstrap` adds project-specific skills under `.claude/skills/`, the shared canonical location for
Claude Code and supported GitHub Copilot skill surfaces, grounding instance-shaped recipes in a real
repo exemplar. A legacy `.github/skills/` tree has higher Copilot priority and must be migrated here
before framework checks pass.

**Registers**: [TECH_DEBT.md](./TECH_DEBT.md) tracks delivery debt. [SECURITY_FINDINGS.md](./SECURITY_FINDINGS.md) tracks security findings separately with remediation SLAs (Critical = 7 days, High = 30 days). Do not merge them — audit teams treat these differently. AI-assisted file changes are appended to [.claude/ai-audit.log](./.claude/ai-audit.log) automatically by the PostToolUse hook.

---

## Boy Scout Rule

**Bug-fix scope.** See the framework-owned workflow scope.

### Always apply (low-effort, low-risk — subject to Bug-fix scope above):

**Add:**
1. Missing null/existence checks at public (external-caller-facing) boundaries
2. Parameterization where a statement would otherwise concatenate input into SQL

**Subtract:**
3. Commented-out code blocks (more than 1 line — version control preserves them)
4. Unreferenced objects the tooling flags

### Apply only when the file is the primary target of the change:

**Add:**
5. Split a load procedure that mixes staging validation, dimension resolution, and fact insertion
   into separate steps; never use a line-count threshold
6. Add risk-relevant data-validation checks only, and only with an evidenced harness

**Subtract:**
7. Collapse shallow wrapper views/procedures that add no behavior beyond calling another object
8. Single-use helper objects — inline at the call site

Items 5–8 can significantly expand or reshape a diff. Only apply them when the file is what the task
is specifically about, not when it's incidentally touched. This keeps PRs focused and reviewable.

---

## What We've Learned

Long-form learnings live in [LEARNINGS.md](./LEARNINGS.md). Read it when starting non-trivial work; append to it (don't overwrite) when you discover what works, what causes friction, or what rule needs adjusting.

LEARNINGS.md is an append-only chronological history (plus the declined-recipe registry); the team wiki ([docs/wiki/](./docs/wiki/INDEX.md)) holds current, scoped, individually-verifiable claims with an index — promote a durable LEARNINGS entry to a wiki entry via `remember-for-team`.
