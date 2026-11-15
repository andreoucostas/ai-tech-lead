<!--
ai-tech-lead-framework
  template: dotnet
  version: 0.98.6
  applied: 2026-11-13
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

Implementation observations (intended purpose, users and value are unknown until a named owner supplies them):

- SQL data warehouse (SSDT-style `warehouse.sqlproj`, `Microsoft.Build.Sql/0.2.0`) on SQL Server: staging → dimension/fact → reporting views.
- Domains are financial-product areas (Deposit, Brokerage, Escrow, Factoring, Treasury, Payroll, Pension, Remittance, Retail, Trade, Wealth, Card, Clearing, Custody, Corporate, Lending) plus a Sales/Customer/Product/Region/Date core.
- Critical journey: SQL Agent jobs run `usp_Load*` procs (dims, then facts) that read `stg.*` and write `dim.*`/`fact.*`; `rpt.vw*` views read the result.
- No application code, API, tests or CI for the SQL exist in the repo.

---

## Repository Structure

One file per object, `<schema>.<Name>.sql` for tables/views, `usp_<Name>.sql` for procs:

- `Tables/` — `stg.Stg*` (214 tables across stg/dim/fact/ctl), `dim.Dim*`, `fact.Fact*`, `ctl.LoadRun`
- `StoredProcedures/` — `dbo.usp_LoadDim*` (85) and `dbo.usp_LoadFact*` (65); one proc per target table
- `Jobs/` — 43 SQL Agent scripts (`msdb.dbo.sp_add_job*`), one per domain (`<Domain>Daily.sql`, plus `NightlyCore.sql`), dim steps before fact steps; no schedules defined
- `Views/` — `rpt.vw*` reporting views (88) over fact + dim
- Change locations: new load = stg table + dim/fact table + proc + step in the domain's job + optional `rpt` view

```text
source -> stg.Stg* -> usp_LoadDim* -> dim.Dim* --\
                  \-> usp_LoadFact* (join dim by business id) -> fact.Fact* -> rpt.vw*
Jobs/*.sql orchestrate procs; ctl.LoadRun is used only by the FactSales variants
```

---

## Conventions

Profile: warehouse-SQL only (no `*.csproj`; .NET rules do not apply). Observed, not endorsed.

### Data Access / Warehouse
- **Layers**: `stg` → `dim`/`fact` → `rpt`; `ctl` holds run control. Reports read only fact/dim (`Views/rpt.vwDepositBalanceDetail.sql`).
- **Naming**: `Stg<Domain><Entity>`, `Dim<Domain>[<Attr>]`, `Fact<Domain><Entity><Event|Movement|Snapshot>`, `usp_LoadDim<X>`/`usp_LoadFact<X>`, `rpt.vw<Domain><Detail|Summary|Trend|ByMonth>`.
- **Keys**: dim surrogate `<X>Key INT` PK + business `<X>Id NVARCHAR(50)`; fact PK is the staging `SourceId`; facts carry `BusinessDateKey` → `dim.DimDate` and `LoadRunId`.
- **Money**: `DECIMAL(18,2)` with `CurrencyCode CHAR(3)` on fact and staging rows (`Tables/fact.FactDepositBalanceMovement.sql`).
- **Fact load shape**: one plain `INSERT … SELECT` from `stg` with inner joins to dims and `DimDate`; `LoadRunId` = `stg.BatchId` (`StoredProcedures/usp_LoadFactDepositBalanceMovement.sql`). Convention for new facts (developer-assumed; the Sales Incremental/_v2 variants are unscheduled experiments).
- **SCD**: history columns (`EffectiveFrom/EffectiveTo/IsCurrent`) exist on 26 of 87 dims only; facts filter `IsCurrent = 1` on those and join the rest unfiltered. Intended as selective (developer-assumed).
- **Dim loads**: all 85 insert only a `-1`/`'Unknown'` row (`usp_LoadDimDepositBalance.sql`); real member loading is absent. Treat as unresolved, see Known Hazard Areas.
- **Load ordering**: each `Jobs/<Domain>Daily.sql` lists dim steps before fact steps (`Jobs/TreasuryAccrualDaily.sql`).
- **Rerun/idempotency**: no guard in fact loads; only `usp_LoadFactSalesIncremental.sql` uses `ctl.LoadRun` watermark. Do not assume reruns are safe.
- **Deployment**: SDK-style SQL project `warehouse.sqlproj`; no pipeline, deploy script or schedule is committed.
- Warehouse structure — tables and keys, fact → dimension relationships, load ordering — is mapped using [docs/warehouse-map.md](./docs/warehouse-map.md). Read it before writing a warehouse query or load; run `/map-warehouse` to create or refresh it.

### Testing / Validation
- No SQL test, data-quality or validation assets exist (see `TECH_DEBT.md`). Target shape: a tSQLt or SQL-project-test suite per load proc covering rerun, unmatched-dim and unknown-member cases, wired to a committed command.

### Verification Commands

| Category | Command | Evidence | Policy |
|----------|---------|----------|--------|
| build | not available (no evidenced command) | `warehouse.sqlproj` alone evidences no command | — |
| test | not available (no evidenced command) | no SQL test assets | — |
| format | not available (no evidenced command) | — | — |
| lint | not available (no evidenced command) | — | — |
| migration/deploy | not available (no evidenced command) | no deploy script or pipeline; if one is added it is manual/CI-only | manual/CI-only |
| data-validation | not available (no evidenced command) | — | — |

Framework check (reported separately, not application evidence): `pwsh -NoProfile -File scripts/docs-sync-check.ps1`.

---

## Architecture Decisions

<!-- One-line INDEX of significant decisions here (ID — title — date — link). Full ADRs
     (Decision → Context → Consequences → Review notes) live in docs/architecture-decisions.md,
     added by the create-adr skill. Rationale: AGENTS.md loads on nearly every agent turn and
     anchors the prompt cache — keep it small; detail loads on demand. -->

A one-line index of significant decisions (including accidental ones that became convention). Full detail in [docs/architecture-decisions.md](./docs/architecture-decisions.md).

- ADR-001 — Fact loads are plain INSERT…SELECT with `stg.BatchId` as `LoadRunId` (accidental convention) — 2026-11-15

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
