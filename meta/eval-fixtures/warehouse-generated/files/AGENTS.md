<!--
ai-tech-lead-framework
  template: dotnet
  version: 0.98.1
  applied: 2026-10-19
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

Implementation observations (intent and consumers not stated in the repo; unknown until a named owner supplies them):

- A SQL Server data warehouse project (`warehouse.sqlproj`, `Microsoft.Build.Sql/0.2.0`) of 15 SQL files: one sales star schema.
- Flow: `stg.StgSalesOrder` → `dbo.usp_Load*` → `dim.*` / `fact.FactSales` → `rpt.*` views.
- Grain: one `FactSales` row per `SalesId` (`SalesKey`); measure `NetAmount DECIMAL(18,2)`. `DimCustomer` is the only SCD2 dimension.
- Control: `stg.BatchId` is copied to `FactSales.LoadRunId`; `ctl.LoadRun` (with `Watermark`) exists but no proc reads it.

---

## Repository Structure

Flat folders at the repo root; the schema is encoded in the file name (`<schema>.<Object>.sql`).

- `Tables/` — `stg.`, `dim.`, `fact.`, `ctl.` tables. Change table shape here.
- `StoredProcedures/` — `dbo.usp_Load<Dim|Fact><Name>`, one per load (Region, Customer, Sales). No Product or Date load exists.
- `Views/` — `rpt.vw*` reporting views over `fact` + `dim`.
- No orchestrator, migration scripts, tests, or SQL CI are committed; the only workflow is the framework's `docs-sync-check`.

```
stg.StgSalesOrder -> usp_LoadDimRegion / usp_LoadDimCustomer -> dim.*
                  -> usp_LoadFactSales (joins dim.*)          -> fact.FactSales -> rpt.vw*
ctl.LoadRun (unused)
```

---

## Conventions

- **Schema layering**: `stg` → `dim`/`fact` → `rpt`, plus `ctl` for control. Evidence: `Tables/`. Procs sit in `dbo`, not a layer schema.
- **Surrogate keys**: `INT`/`BIGINT` `*Key` primary keys, no `IDENTITY`, no foreign keys declared. `FactSales` stores dimension surrogate keys; business keys (`CustomerId`, `ProductId`) join staging to dims (`StoredProcedures/usp_LoadFactSales.sql:5-6`).
- **SCD**: `DimCustomer` is SCD2-shaped (`EffectiveFrom/EffectiveTo/IsCurrent`) and facts join `IsCurrent = 1`. The loader does not yet close old rows (`usp_LoadDimCustomer.sql:1`). Other dims carry no history columns.
- **Load ordering** (implied by joins, not orchestrated): Region → Customer → Product/Date (no loader in repo) → Fact.
- **Idempotency/rerun**: no mechanism is implemented. `BatchId`/`LoadRunId`/`Watermark` columns exist but are unread, so the loads are not re-runnable (see DEBT-001..003, Known Hazard Areas).
- **Loader state**: the Region and Customer loads insert constant `-1`/`'Unknown'` rows. Treat them as incomplete, not as a pattern to copy.
- **Money**: `DECIMAL(18,2)` for `NetAmount` (`Tables/fact.FactSales.sql:6`).
- **Warehouse structure** — tables and keys, fact → dimension relationships, load ordering — is mapped using [docs/warehouse-map.md](./docs/warehouse-map.md). Read it before writing a warehouse query or load; run `/map-warehouse` to create or refresh it.

### Testing / Validation

No SQL tests, data-quality checks, or reconciliation assets exist (DEBT-004). Target shape: a repeatable load-and-reconcile check per load (row counts staging vs fact, rerun yields no change) once a harness is chosen.

### Verification Commands

| Category | Command | Evidence | Policy |
|----------|---------|----------|--------|
| build | not available (no evidenced command) | `warehouse.sqlproj` is a SQL project, not command evidence | n/a |
| test | not available (no evidenced command) | none | n/a |
| format | not available (no evidenced command) | none | n/a |
| lint | not available (no evidenced command) | none | n/a |
| migration/deploy | not available (no evidenced command) | none | manual/CI-only |
| data-validation | not available (no evidenced command) | none | n/a |

---

## Architecture Decisions

<!-- One-line INDEX of significant decisions here (ID — title — date — link). Full ADRs
     (Decision → Context → Consequences → Review notes) live in docs/architecture-decisions.md,
     added by the create-adr skill. Rationale: AGENTS.md loads on nearly every agent turn and
     anchors the prompt cache — keep it small; detail loads on demand. -->

A one-line index of significant decisions (including accidental ones that became convention). Full detail in [docs/architecture-decisions.md](./docs/architecture-decisions.md).

- ADR-001 — Star schema with SCD2 customer dimension and surrogate-key facts — accidental/observed — [docs/architecture-decisions.md](./docs/architecture-decisions.md)

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
