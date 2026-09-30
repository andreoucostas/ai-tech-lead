<!--
ai-tech-lead-framework
  template: dotnet
  version: 0.90.0
  applied: 2026-09-29
  After a framework update, copy these fields from .claude/framework-version.json.
-->
# [Project Name]

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

<!-- Populated by /bootstrap — do not fill manually -->

Implementation observations only — code establishes what is built, not confirmed product intent,
actual users, or production behaviour. No README, product spec, or maintainer-authored description
of this warehouse's purpose exists in the repo; treat intended purpose and actual users as unknown.

- This repository is a SQL Server data warehouse delivered as an SSDT-style SQL project
  (`warehouse.sqlproj`, `Microsoft.Build.Sql/0.2.0` SDK). No `*.csproj` exists anywhere in the
  repo — this is a **warehouse-SQL-only** repo; the .NET-oriented sections/skills below do not apply.
- Schema objects model a sales-order warehouse: one staging table (`stg.StgSalesOrder`), four
  dimensions (`dim.DimCustomer`, `dim.DimProduct`, `dim.DimDate`, `dim.DimRegion`), one fact
  (`fact.FactSales`), one load-run control table (`ctl.LoadRun`), and three reporting views
  (`rpt.vwExecutiveSummary`, `rpt.vwFinanceExtract`, `rpt.vwOrderDetail`).
- Domain concepts as implemented: sales orders, customers, products, regions, and calendar dates,
  rolled up into revenue-by-category and finance/region reporting extracts.
- Critical journey as implemented (currently incomplete — see `TECH_DEBT.md`): staging sales-order
  rows → `usp_LoadDimCustomer` / `usp_LoadDimRegion` populate dimensions → `usp_LoadFactSales` joins
  staging to dimensions into the fact table → `rpt.*` views serve reporting.

---

## Repository Structure

<!-- Populated by /bootstrap — replaces separate CODEMAP.md -->

```
warehouse.sqlproj            SSDT-style SQL project (Microsoft.Build.Sql/0.2.0), no further config
Tables/
  ctl.LoadRun.sql             Load-run control table — declared, never read/written (TECH_DEBT DEBT-005)
  stg.StgSalesOrder.sql       Staging table — no in-repo producer (TECH_DEBT DEBT-006)
  dim.DimCustomer.sql         Customer dimension — SCD2-shaped columns, loader never uses them (DEBT-002)
  dim.DimProduct.sql          Product dimension — no in-repo loader (DEBT-006)
  dim.DimDate.sql             Date dimension — no in-repo loader (DEBT-006)
  dim.DimRegion.sql           Region dimension — stub loader only (DEBT-001, DEBT-004)
  fact.FactSales.sql          Sales fact, grain = one row per stg.StgSalesOrder.SalesId
StoredProcedures/
  usp_LoadDimCustomer.sql     dbo schema; MERGE with insert-only branch (DEBT-002)
  usp_LoadDimRegion.sql       dbo schema; single hardcoded row (DEBT-001)
  usp_LoadFactSales.sql       dbo schema; unparameterized full-table insert (DEBT-009)
Views/
  rpt.vwExecutiveSummary.sql  Revenue by product category
  rpt.vwFinanceExtract.sql    Revenue by region and date — region always "Unknown" (DEBT-004)
  rpt.vwOrderDetail.sql       Pass-through fact detail
```

Evidence-backed data flow (`?` = no in-repo producer):

```
? ---------------------------> stg.StgSalesOrder
stg.StgSalesOrder --(usp_LoadDimCustomer)--> dim.DimCustomer   [insert-only, hardcoded key]
stg.StgSalesOrder --(usp_LoadDimRegion)-----> dim.DimRegion    [single stub row]
? ---------------------------------------> dim.DimProduct
? ---------------------------------------> dim.DimDate

stg.StgSalesOrder + dim.DimCustomer + dim.DimProduct + dim.DimDate
    --(usp_LoadFactSales)--> fact.FactSales

fact.FactSales + dim.DimProduct                              --> rpt.vwExecutiveSummary
fact.FactSales + dim.DimCustomer + dim.DimRegion + dim.DimDate --> rpt.vwFinanceExtract
fact.FactSales                                                --> rpt.vwOrderDetail
```

---

## Conventions

### Data Access — warehouse structure

- Schema-per-layer: `ctl` (load-run control), `stg` (staging), `dim` (dimensions), `fact` (facts),
  `rpt` (reporting/mart views). Tables and views follow this consistently. Stored procedures do
  **not** — all three live in `dbo` rather than a layer-aligned schema (see `TECH_DEBT.md` DEBT-012;
  developer input on whether this is intentional was not resolved during bootstrap).
- No physical mart layer exists — `rpt.*` views query `fact`/`dim` tables directly; there are no
  intermediate aggregate/mart tables. A new reporting need should extend or add a view, not a table,
  unless materialization is specifically required.
- Fact/dimension relationships are enforced by column-naming convention only — no `FOREIGN KEY`
  constraint exists anywhere in the schema (`TECH_DEBT.md` DEBT-010).
- The model is a snowflake, not a pure star: `fact.FactSales` does not reference `dim.DimRegion`
  directly — region is reached only via `dim.DimCustomer.RegionKey`. `Views/rpt.vwFinanceExtract.sql`
  demonstrates this join path (`FactSales → DimCustomer → DimRegion`).
- Warehouse structure — tables and keys, fact → dimension relationships, load ordering — is mapped
  using [docs/warehouse-map.md](./docs/warehouse-map.md). Read it before writing a warehouse query or
  load; run `/map-warehouse` to create or refresh it (no map exists yet as of this bootstrap).

### Data Access — load correctness & idempotency

- **None of the three existing load procedures are safely rerunnable as written — do not copy their
  pattern into a new load.** `usp_LoadDimRegion` inserts one hardcoded row with no `MERGE`/existence
  check (fails on primary key on a second run); `usp_LoadDimCustomer`'s `MERGE` has only a
  `WHEN NOT MATCHED` branch and hardcodes the same surrogate key (`-1`) for every new customer; see
  `TECH_DEBT.md` DEBT-001 and DEBT-002 before touching either.
- `ctl.LoadRun` (the batch/watermark control table) exists in the schema but is not read or written
  by any procedure — there is no incremental/watermark-based loading and no run tracking today
  (`TECH_DEBT.md` DEBT-005). `fact.FactSales.LoadRunId` is populated from
  `stg.StgSalesOrder.BatchId`, not from `ctl.LoadRun`.
- No load procedure wraps its work in a transaction or `TRY/CATCH` — a failure partway through a
  load leaves partial writes with no rollback (`TECH_DEBT.md` DEBT-008).
- No load procedure takes a `@BatchId`/`@LoadRunId` parameter — every execution processes the whole
  of `stg.StgSalesOrder` unconditionally (`TECH_DEBT.md` DEBT-009).
- `dim.DimProduct`, `dim.DimDate`, and the population of `stg.StgSalesOrder` itself have no load or
  ingestion procedure anywhere in this repo (`TECH_DEBT.md` DEBT-006) — `usp_LoadFactSales` inner-joins
  both dimensions assuming they are already populated by a process outside this repo.

### Testing / Validation

- No warehouse test or validation assets exist in this repo: no tSQLt (or equivalent) tests, no
  data-quality/reconciliation checks, no SQL lint/format configuration, and no CI step builds or
  validates `warehouse.sqlproj` (`TECH_DEBT.md` DEBT-003, DEBT-007).
- Target test shape: a tSQLt (or equivalent SQL-native) test project alongside `Tables/`, `Views/`,
  and `StoredProcedures/`, covering each load procedure's rerun/idempotency behaviour and each
  dimension's grain, plus a CI step that builds `warehouse.sqlproj`.

### Verification Commands

| Category | Command | Evidence | Execution policy |
|---|---|---|---|
| build | not available (no evidenced command) | — | — |
| test | not available (no evidenced command) | — | — |
| format | not available (no evidenced command) | — | — |
| lint | not available (no evidenced command) | — | — |
| migration/deploy | not available (no evidenced command) | — | manual/CI-only |
| data-validation | not available (no evidenced command) | — | — |

`warehouse.sqlproj` is a bare `<Project Sdk="Microsoft.Build.Sql/0.2.0" />` with no publish profile,
deploy script, or CI step referencing it — nothing in the repo names an exact build/deploy invocation
to record here.

---

## Architecture Decisions

<!-- One-line INDEX of significant decisions here (ID — title — date — link). Full ADRs
     (Decision → Context → Consequences → Review notes) live in docs/architecture-decisions.md,
     added by the create-adr skill. Rationale: AGENTS.md loads on nearly every agent turn and
     anchors the prompt cache — keep it small; detail loads on demand. -->

A one-line index of significant decisions (including accidental ones that became convention). Full detail in [docs/architecture-decisions.md](./docs/architecture-decisions.md).

- ADR-001 — Schema-per-layer naming for tables/views, not procedures — 2026-09-30
- ADR-002 — Reporting layer is views-only; no physical mart tables — 2026-09-30
- ADR-003 — Fact/dimension relationships are convention-only; no FOREIGN KEY constraints — 2026-09-30

---

## Common Tasks

When a task matches a skill below, invoke that skill with your skill tool before planning or editing.

Skills are a delivery-profile superset, not evidence that they apply. This repo evidences the
**warehouse-SQL** profile only (no `*.csproj` anywhere) — only the skills below are applicable here.
The framework's .NET-oriented skills (`add-endpoint`, `add-entity`, `register-service`, `add-tests`,
`perf`, `dependency-audit`, `enforce-architecture`, `enforce-standards`) remain installed but dormant
and are not advertised in this list; do not invoke them against this repo.

- `map-warehouse` — map this SQL data-warehouse repo: layers (staging → warehouse → marts), tables, keys and fact → dimension relationships, grain, load orchestration, SCD strategy, partitioning. No map exists yet — run this before your first warehouse change.
- `add-warehouse-load` — add or extend a warehouse load following the repo's existing patterns: idempotent re-runnable loads, no double-loading, SCD handling, partition alignment. **No clean exemplar exists in this repo** — all three current load procedures (`usp_LoadDimCustomer`, `usp_LoadDimRegion`, `usp_LoadFactSales`) are flagged in `TECH_DEBT.md` (DEBT-001, DEBT-002, DEBT-009); do not copy their pattern.
- `create-adr` — record a significant architecture decision in Architecture Decisions
- `remember-for-team` — draft a team wiki entry (gotcha/context/recipe/failed-approach) for PR review

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
