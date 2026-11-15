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

_Implementation observations from code; intended purpose and users are unknown until a named owner supplies them._

- SQL Server data warehouse (`warehouse.sqlproj`, `Microsoft.Build.Sql/0.2.0`): sales star schema, `stg` → `dim`/`fact` → `rpt` views.
- Sources/consumers: `stg.StgSalesOrder` is the only source table (its loader is not in this repo); consumers are the three `rpt.*` views.
- Critical journey: SQL Agent job "Nightly core" runs `usp_LoadDimCustomer` → `usp_LoadDimRegion` → `usp_LoadFactSales`.
- Load procedures are currently skeletal (see TECH_DEBT.md and FRAMEWORK-CONTEXT.md > Known Hazard Areas).

---

## Repository Structure

- `Tables/` — one `<schema>.<Object>.sql` per table: `stg`, `dim`, `fact`, `ctl` (`ctl.LoadRun` batch/watermark control).
- `StoredProcedures/` — `dbo.usp_Load<Dim|Fact><Entity>.sql`, one load per target table.
- `Views/` — `rpt.vw*.sql` reporting views over `fact`/`dim`.
- `Jobs/NightlyCore.sql` — SQL Agent job; step order is the load order. A new load needs a step here.
- Not present: `CREATE SCHEMA` DDL, job schedule, tests, a build CI; `.github/workflows` holds framework checks only.

```text
stg.StgSalesOrder -> dbo.usp_Load* -> dim.* / fact.FactSales -> rpt.vw*
Jobs/NightlyCore.sql orders: DimCustomer, DimRegion, FactSales
```

---

## Conventions

- Tables are `<schema>.<Object>.sql` in `Tables/`; loads are `usp_Load<Dim|Fact><Entity>.sql` in `StoredProcedures/`.
- Layering is stg → dim/fact → rpt; reports read only `fact`/`dim` — `Views/rpt.vwFinanceExtract.sql`.
- Dimensions load before facts; ordering lives only in the job steps — `Jobs/NightlyCore.sql`.
- Fact grain is one row per `SalesKey` (= staging `SalesId`); facts join dimensions on natural keys, `IsCurrent = 1` for `DimCustomer` — `StoredProcedures/usp_LoadFactSales.sql`.
- `DimCustomer` carries SCD2-style columns (`EffectiveFrom`/`EffectiveTo`/`IsCurrent`) but `usp_LoadDimCustomer` does not version; do not rely on history. Other dimensions are Type 1 by shape.
- `ctl.LoadRun` (`LoadRunId`, `Watermark`) exists but no load reads or writes it; `FactSales.LoadRunId` is filled from `stg.BatchId`. No load is rerun-safe yet; a new load must define idempotency explicitly (`add-warehouse-load`).
- Money is `DECIMAL(18,2)` (`NetAmount`) — `Tables/fact.FactSales.sql`.
- Warehouse structure — tables and keys, fact → dimension relationships, load ordering — is mapped using [docs/warehouse-map.md](./docs/warehouse-map.md). Read it before writing a warehouse query or load; run `/map-warehouse` to create or refresh it.

### Validation / testing

No warehouse tests, data-quality checks, lint or format config exist (TECH_DEBT.md DEBT-006). Target shape: a rerunnable validation script per load asserting row counts, key uniqueness and orphan-free fact joins against seed data.

### Verification Commands

| Category | Command | Evidence | Execution policy |
|----------|---------|----------|------------------|
| build | not available (no evidenced command) | `warehouse.sqlproj` evidences no command | n/a |
| test | not available (no evidenced command) | no test assets | n/a |
| format | not available (no evidenced command) | none | n/a |
| lint | not available (no evidenced command) | none | n/a |
| migration/deploy | not available (no evidenced command) | `Jobs/NightlyCore.sql` creates the job; it is not a validation/dry-run | manual/CI-only |
| data-validation | not available (no evidenced command) | none | n/a |

---

## Architecture Decisions

<!-- One-line INDEX of significant decisions here (ID — title — date — link). Full ADRs
     (Decision → Context → Consequences → Review notes) live in docs/architecture-decisions.md,
     added by the create-adr skill. Rationale: AGENTS.md loads on nearly every agent turn and
     anchors the prompt cache — keep it small; detail loads on demand. -->

- ADR-001 — SQL project (`Microsoft.Build.Sql`) as schema deployment vehicle — 2026-11-15
- ADR-002 — SQL Agent job step order as sole load orchestration — 2026-11-15

Full detail in [docs/architecture-decisions.md](./docs/architecture-decisions.md).

---

## Common Tasks

When a task matches a skill below, invoke that skill with your skill tool before planning or editing.

Only skills applicable to this warehouse-SQL repo are listed; the other shipped skills stay installed but dormant (no .NET evidence).

For `add-warehouse-load`: no current load is a usable exemplar (all three carry open debt, DEBT-001 to DEBT-003), so none is cited.

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
