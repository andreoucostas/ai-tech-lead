<!--
ai-tech-lead-framework
  template: dotnet
  version: 0.96.0
  applied: 2026-10-12
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

This repository is a SQL Server data warehouse — no application/API layer exists (no `.csproj` files). It stages sales-order data (`stg.StgSalesOrder`), resolves it against customer/product/date/region dimensions, and loads a sales fact table (`fact.FactSales`) consumed by three reporting views (`rpt.*`). **Implementation observation**: the current load procedures have several correctness gaps — hardcoded placeholder surrogate keys, no rerun/idempotency guard, and a dimension with no load procedure at all — tracked in `TECH_DEBT.md` and `FRAMEWORK-CONTEXT.md > Known Hazard Areas`. Intended purpose, actual users/consumers, and production deployment are not evidenced in this repository; a maintainer should document them.

---

## Repository Structure

- `Tables/` — schema-per-layer DDL: `stg.*` (staging), `dim.*` (dimensions), `fact.*` (fact), `ctl.*` (load control). New tables go here, under the matching schema prefix.
- `StoredProcedures/` — load procedures (`usp_Load*`). Note: `dim.DimProduct` and `dim.DimDate` currently have no load procedure evidenced anywhere in the repo.
- `Views/` — `rpt.*` reporting views over `fact.FactSales` joined to the dimensions.
- `warehouse.sqlproj` — the one deployment vehicle (SQL Server Database Project, `Microsoft.Build.Sql` SDK); new objects are added as `.sql` files under the three folders above.

```
stg.StgSalesOrder --> usp_LoadDimCustomer --> dim.DimCustomer --\
                  --> usp_LoadDimRegion   --> dim.DimRegion  ----+--> usp_LoadFactSales --> fact.FactSales --> rpt.*
   (dim.DimProduct, dim.DimDate: no load procedure evidenced) --/
```

---

## Conventions

### Schema & Layering
- Objects are organized by schema-per-layer — `stg` (staging), `dim` (dimensions), `fact` (facts), `ctl` (load control), `rpt` (reporting views) — follow this schema prefix for any new table or view.

### Grain & Keys
- `fact.FactSales` grain is one row per staged sales-order line, carrying `CustomerKey`, `ProductKey`, and `OrderDateKey` as surrogate foreign keys resolved from `dim.DimCustomer` (current row only), `dim.DimProduct`, and `dim.DimDate`.
- `dim.DimCustomer` is modeled as a slowly-changing dimension (`EffectiveFrom`, `EffectiveTo`, `IsCurrent`); fact loads join only the current row (`IsCurrent = 1`).

### Load Ordering
- Dimension loads run before the fact load that depends on them — `usp_LoadDimCustomer` and `usp_LoadDimRegion` before `usp_LoadFactSales` — since the fact load inner-joins current dimension rows and silently drops any staging row with no match.

### Data Access
- Warehouse structure — tables and keys, fact → dimension relationships, load ordering — is mapped using [docs/warehouse-map.md](./docs/warehouse-map.md). Read it before writing a warehouse query or load; run `/map-warehouse` to create or refresh it.

### Deployment
- Schema changes go through the one deployment vehicle — the `warehouse.sqlproj` SQL Server Database Project (`Microsoft.Build.Sql` SDK) — adding new objects as `.sql` files under `Tables/`, `StoredProcedures/`, or `Views/`, never as ad-hoc scripts.

### Validation / Testing
- No warehouse test or validation assets exist in this repository today (no tSQLt, dbt tests, or data-quality scripts) — see `TECH_DEBT.md` DEBT-005. Target shape: a referential-integrity check that every fact row resolves to a current dimension row, plus a row-count reconciliation between `stg` and `fact` per load run.

### Verification Commands

| Category | Command | Evidence | Policy |
|----------|---------|----------|--------|
| build | not available (no evidenced command) | — | — |
| test | not available (no evidenced command) | — | — |
| format | not available (no evidenced command) | — | — |
| lint | not available (no evidenced command) | — | — |
| migration/deploy | not available (no evidenced command) | — | manual/CI-only |
| data-validation | not available (no evidenced command) | — | — |

No committed CI workflow, script, or documented command builds, deploys, tests, lints, or validates `warehouse.sqlproj`. See `TECH_DEBT.md` DEBT-008.

---

## Architecture Decisions

- **ADR-001** — Warehouse schema is deployed via a SQL Server Database Project (`warehouse.sqlproj`, `Microsoft.Build.Sql` SDK) rather than migration scripts — see [docs/architecture-decisions.md](./docs/architecture-decisions.md).

Full detail in [docs/architecture-decisions.md](./docs/architecture-decisions.md).

---

## Common Tasks

When a task matches a skill below, invoke that skill with your skill tool before planning or editing.

Skills are a delivery-profile superset, not evidence that they apply. Use only when repository
evidence satisfies the gate:

- `map-warehouse` — map a SQL data-warehouse repo: layers (staging → warehouse → marts), tables, keys and fact → dimension relationships, grain, load orchestration, SCD strategy, partitioning
- `add-warehouse-load` — add or extend a warehouse load following the repo's existing patterns: idempotent re-runnable loads, no double-loading, SCD handling, partition alignment. No existing load in this repo passes the quality cross-check cleanly (all three are flagged in `TECH_DEBT.md`), so no exemplar path is recorded here — fix the flagged debt before treating any current load as a pattern to copy.
- `create-adr` — record a significant architecture decision in Architecture Decisions
- `remember-for-team` — draft a team wiki entry (gotcha/context/recipe/failed-approach) for PR review

The .NET-only skills (`add-tests`, `perf`, `dependency-audit`, `enforce-architecture`, `enforce-standards`) remain installed but dormant — this repo has no `.csproj` files, so none are evidenced here.

`/bootstrap` drafts a project skill under `.claude/skills/`, the shared canonical location for Claude Code and supported GitHub Copilot skill surfaces, for an operation this repository repeats at least three times; add its line here once the team approves the draft.

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
