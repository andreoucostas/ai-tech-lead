<!--
ai-tech-lead-framework
  template: dotnet
  version: 0.98.6
  applied: 2026-11-13
  After a framework update, copy these fields from .claude/framework-version.json.
-->
# Warehouse (SQL warehouse project)

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

Implementation observations from code (intended purpose and users are not stated in the repo — maintainer to confirm):

- A SQL Server star-schema warehouse (`warehouse.sqlproj`, `Microsoft.Build.Sql/0.2.0`): `stg` staging → `dim`/`fact`/`bridge` → `rpt` reporting views/procedure.
- A hand-written core (accounts, branches, customers, regions, dates, `FactTransaction`, `FactAccountBalanceMonthly`) plus ~38 uniform banking-product domains (Brokerage, Card, Escrow, Factoring, Payroll, Pension, Remittance, Treasury, …), each with staging, dims, facts, a daily job and reporting views.
- Loads run as SQL Agent jobs (`Jobs/`); consumers read `rpt.*` through the `ReportReader` role. Critical journey: staging → `usp_Load*` → fact/dim → `rpt.vw*`.

---

## Repository Structure

One object per file, grouped by kind (no SQL project subfolders by schema):

- `Tables/<schema>.<Name>.sql` — `stg.*`, `dim.*`, `fact.*`, `bridge.*` DDL. New table → here.
- `StoredProcedures/usp_Load{Dim,Fact,Bridge}<Name>.sql` — loads (`dbo`); `rpt.usp_BranchBalanceAsAt.sql` is the one report proc.
- `Jobs/<Domain>Daily.sql` (+ `NightlyCore.sql`) — one SQL Agent job per domain; one step per load, dims before facts. New load → add a step.
- `Views/rpt.vw*.sql` — reporting views; `Deploy/reporting.manifest` — ordered deploy list for the reporting replica; `Security/` — schemas, `ReportReader` role, `rpt.Permissions.sql` grants.
- `scripts/`, `.claude/`, `.github/`, `docs/`, `specs/`, `tests/evals` — framework, not application.

```
stg.Stg* → usp_Load* (Jobs/) → dim/bridge/fact → rpt.vw* → ReportReader
```

---

## Conventions

Warehouse-SQL profile only; no application code.

**Data Access / warehouse**
- Layers: `stg` (raw, each row carries `BatchId`) → `dim`/`bridge`/`fact` (`fact` rows carry `LoadRunId` = source `BatchId`) → `rpt`. Evidence: `Tables/stg.StgTransaction.sql`, `Tables/fact.FactTransaction.sql`.
- Naming: `Stg/Dim/Fact/Bridge<Name>`, procs `dbo.usp_Load<Kind><Name>`, views `rpt.vw<Name>`; surrogate key `<Name>Key`, business key `<Name>Id`/`Code`.
- Load order: dims → bridge → facts; encode it as ordered steps in the domain's `Jobs/*.sql` (`Jobs/NightlyCore.sql`).
- Idempotent fact load (convention for new loads, per developer default): one transaction, `@BatchId = MAX(BatchId)` from staging, `DELETE` that batch's rows from the fact, re-`INSERT` filtered by `BatchId`. Evidence: `StoredProcedures/usp_LoadFactTransaction.sql`. Most domain facts (e.g. `usp_LoadFactBrokerageRepaymentEvent.sql`) do not follow it — see DEBT-001.
- Dimension history: only `dim.DimCustomer` is real SCD2 (`ValidFrom/ValidTo/IsCurrent`, `usp_LoadDimCustomer.sql`); `DimAccount`/`DimBranch` are Type 1 `MERGE`. Domain dims with `EffectiveFrom/To/IsCurrent` are not maintained as history — DEBT-003.
- Reporting objects: a new `rpt` view needs three edits — the view file, a line in `Deploy/reporting.manifest`, a `GRANT SELECT … TO [ReportReader]` in `Security/rpt.Permissions.sql` (85/85/85 today).
- Warehouse structure — tables and keys, fact → dimension relationships, load ordering — is mapped using [docs/warehouse-map.md](./docs/warehouse-map.md). Read it before writing a warehouse query or load; run `/map-warehouse` to create or refresh it.

**Testing / validation**: no warehouse tests or data-quality checks exist (`tests/evals` is framework). Target shape: rerun-twice and reconciliation checks per load, in whatever SQL test tooling the team picks.

### Verification Commands

| Category | Command | Evidence | Execution policy |
|----------|---------|----------|------------------|
| build | not available (no evidenced command) | `warehouse.sqlproj` is a `*.sqlproj`, which evidences no command | — |
| test | not available (no evidenced command) | — | — |
| format | not available (no evidenced command) | — | — |
| lint | not available (no evidenced command) | — | — |
| migration/deploy | not available (no evidenced command); the release pipeline that applies `Deploy/reporting.manifest` is not in the repo | `Deploy/reporting.manifest` | manual/CI-only |
| data-validation | not available (no evidenced command) | — | — |

---

## Architecture Decisions

<!-- One-line INDEX of significant decisions here (ID — title — date — link). Full ADRs
     (Decision → Context → Consequences → Review notes) live in docs/architecture-decisions.md,
     added by the create-adr skill. Rationale: AGENTS.md loads on nearly every agent turn and
     anchors the prompt cache — keep it small; detail loads on demand. -->

Full detail in [docs/architecture-decisions.md](./docs/architecture-decisions.md).

- ADR-001 — Batch-scoped delete-and-reload for fact loads (and its drift in domain facts) — 2026-11-15

---

## Common Tasks

When a task matches a skill below, invoke that skill with your skill tool before planning or editing.

Skills are a delivery-profile superset, not evidence that they apply. Use only when repository
evidence satisfies the gate:

- `map-warehouse` — map a SQL data-warehouse repo: layers (staging → warehouse → marts), tables, keys and fact → dimension relationships, grain, load orchestration, SCD strategy, partitioning
- `add-warehouse-load` — add or extend a warehouse load following the repo's existing patterns: idempotent re-runnable loads, no double-loading, SCD handling, partition alignment. For a concrete current instance, see `StoredProcedures/usp_LoadFactTransaction.sql` — reproduce its **conventions and structure**, not its contents; AGENTS.md > Conventions wins on any conflict.
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
