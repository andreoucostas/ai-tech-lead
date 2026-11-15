<!--
ai-tech-lead-framework
  template: dotnet
  version: 0.98.6
  applied: 2026-11-13
  After a framework update, copy these fields from .claude/framework-version.json.
-->
# Warehouse SQL Project

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

Implementation observations from code only; intended purpose, target users and actual value are unknown until a named owner states them.

- A single-database SQL data warehouse (`warehouse.sqlproj`, `Microsoft.Build.Sql/0.2.0`) of about 5,000 `.sql` files. No application code.
- Repeated subject areas (Brokerage, Card, Clearing, Corporate, Custody, PayrollOverdraft, …, about 430) each flow staging → dimensions/facts → `rpt` views, run by a SQL Agent job.
- Staging (`stg.*`) is populated outside this repo; no source or ingestion code is present.
- Sales core (`Jobs/NightlyCore.sql`: DimCustomer, DimRegion, FactSales) is the only non-subject-area load.

---

## Repository Structure

- `Tables/` — `<schema>.<Object>.sql`; schemas `stg`, `dim`, `fact`, `ctl` (`ctl.LoadRun`). New tables go here.
- `StoredProcedures/` — `dbo.usp_LoadDim*` / `usp_LoadFact*`, one file per procedure.
- `Views/` — `rpt.vw<Subject>{ByMonth,Trend,Detail,Summary}`; no separate mart schema.
- `Jobs/` — `<Subject>Daily.sql` SQL Agent job scripts (`msdb.dbo.sp_add_job` / `sp_add_jobstep`), plus `NightlyCore.sql`.
- Build root: `warehouse.sqlproj` (SDK globbing, no explicit item lists). Everything else (`.claude`, `.agents`, `.github`, `scripts`, `docs`, `tests/evals`) is framework-owned.

```text
stg.Stg<Subject><Grain> -> dbo.usp_LoadDim* -> dim.Dim<Subject>*
                        -> dbo.usp_LoadFact* (joins dim.* IsCurrent=1, dim.DimDate) -> fact.Fact<Subject><Grain>
fact.* + dim.* -> rpt.vw*      Jobs/<Subject>Daily.sql orders the EXEC steps
```

---

## Conventions

### Data Access (warehouse)

- **Layers**: `stg` → `dim`/`fact` → `rpt` views; no foreign keys, UNIQUE constraints or reconciliation objects exist (`Tables/fact.FactSales.sql`). Fact → dimension links exist only as joins in load procedures.
- **Subject-area template**: per subject, `stg.Stg<Subject><Grain>`, `dim.Dim<Subject>` (+ `Segment`/`Status` lookups), `fact.Fact<Subject><Grain>`, `usp_LoadDim*`, `usp_LoadFact*`, `rpt.vw*`, `Jobs/<Subject>Daily.sql` (`Jobs/PayrollOverdraftDaily.sql`).
- **Load ordering**: dimensions before facts, enforced only by `@step_id` order in the job script, with no dependency check. A procedure not listed in a job never runs (`Jobs/NightlyCore.sql:2-4`).
- **Fact load shape (observed)**: bare `INSERT…SELECT` from staging with inner joins to `dim.*` (`IsCurrent = 1`) and `dim.DimDate`; fact PK is the source id; `LoadRunId` is `s.BatchId` (`StoredProcedures/usp_LoadFactPayrollOverdraftSnapshot.sql:2-8`). No rerun guard; unmatched staging rows drop silently. Do not copy this as an idempotent pattern (DEBT-002).
- **Dimension load shape (observed)**: `MERGE … WHEN NOT MATCHED THEN INSERT` with literal key `-1` and `'Unknown'`; no update branch, so `EffectiveTo`/`IsCurrent` are never maintained and no SCD is implemented (`StoredProcedures/usp_LoadDimCustomer.sql:1`; DEBT-001).
- **Run control**: `ctl.LoadRun(LoadRunId, StartedAt, Watermark)`; only `usp_LoadFactSales_*` variants use it, via `MAX(LoadRunId)+1` (`StoredProcedures/usp_LoadFactSales_v3.sql:3-4`; DEBT-003).
- **Money**: `DECIMAL(18,2)` amount columns with `CurrencyCode CHAR(3)` on subject facts (`Tables/fact.FactSales.sql`).
- **SQL safety**: no dynamic SQL and no `TRUNCATE` anywhere; `DELETE` only inside `usp_LoadFactSales_*` CATCH handlers, scoped by `LoadRunId`.
- **Naming**: tables `<schema>.<Object>.sql`; procedures `dbo.usp_Load<Dim|Fact><Subject>[<Grain>]`; views `rpt.vw<Subject><Shape>`; jobs `<Subject>Daily.sql`.
- Warehouse structure — tables and keys, fact → dimension relationships, load ordering — is mapped using `[docs/warehouse-map.md](./docs/warehouse-map.md)`. Read it before writing a warehouse query or load; run `/map-warehouse` to create or refresh it.

### Validation (warehouse)

- No SQL tests, data-quality checks, fixtures, seed data, lint/format config, or consumer CI exist. Target test shape: tSQLt-style or scripted checks per load (row-count reconciliation staging → fact, PK/rerun checks) once a harness is chosen (DEBT-004).

### Verification Commands

| Category | Command | Evidence | Execution policy |
|----------|---------|----------|------------------|
| build | not available (no evidenced command) | `warehouse.sqlproj` is an SDK `*.sqlproj`; no committed build command | — |
| test | not available (no evidenced command) | — | — |
| format | not available (no evidenced command) | — | — |
| lint | not available (no evidenced command) | — | — |
| migration/deploy | not available (no evidenced command) | `Jobs/*.sql` mutate `msdb` | manual/CI-only |
| data-validation | not available (no evidenced command) | — | — |

---

## Architecture Decisions

Accidental decisions that became convention. Full detail in [docs/architecture-decisions.md](./docs/architecture-decisions.md).

- ADR-001 — Job scripts, not code, own load ordering and orchestration (`Jobs/*.sql`).
- ADR-002 — No declared FKs; fact → dimension integrity lives only in load joins.

---

## Common Tasks

When a task matches a skill below, invoke that skill with your skill tool before planning or editing.

Skills are a delivery-profile superset, not evidence that they apply. Use only when repository
evidence satisfies the gate:

- `map-warehouse` — map a SQL data-warehouse repo: layers (staging → warehouse → marts), tables, keys and fact → dimension relationships, grain, load orchestration, SCD strategy, partitioning
- `add-warehouse-load` — add or extend a warehouse load following the repo's existing patterns: idempotent re-runnable loads, no double-loading, SCD handling, partition alignment
- `create-adr` — record a significant architecture decision in Architecture Decisions
- `remember-for-team` — draft a team wiki entry (gotcha/context/recipe/failed-approach) for PR review

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
