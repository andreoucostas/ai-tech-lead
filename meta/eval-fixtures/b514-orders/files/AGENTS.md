<!--
ai-tech-lead-framework
  template: dotnet
  version: 0.99.0
  applied: 2026-11-23
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

Implementation observations (intent and users are not stated in code): a .NET 8 Orders API over customers, products, orders and invoices (EF Core / SQL Server).
- Order/invoice lifecycle actions raise integration events (`order-placed`, `order-shipped`, `invoice-issued`) via an in-memory outbox and a background dispatcher.
- Three CSV report exports read `rpt.*` SQL views through a separate `ReportReader` login, gated by feature flags.
- Critical journeys: place → ship → invoice (`CheckoutController`); report export (`ReportsController`).

---

## Repository Structure

- `src/Orders.Domain` — anaemic entities (public setters), event records with `[EventVersion]`.
- `src/Orders.Application` — `OrderLifecycle` (enqueues events), event handlers, `IScheduledJob` classes (not wired), unused HTTP clients.
- `src/Orders.Infrastructure` — `OrdersDbContext` + per-entity configurations; `Messaging/` (`EventRegistry`, outbox, dispatcher, stub `ServiceBusPublisher`).
- `src/Orders.Reporting` — `IReportExport` per report, `ReportCatalog`, `SqlReportReader`.
- `src/Orders.Api` — controllers and `Program.cs` (entry point; all DI registered here).
- `db/views`, `db/security` — `rpt.*` views and `GRANT`s; `contracts/events` — JSON schemas; `config/feature-flags.json` — flags.
- `tests/Orders.Tests` — xUnit. Change locations: endpoints → `Orders.Api/Controllers`; events → Domain + Infrastructure/Messaging + `contracts/`; reports → Reporting + `db/`.

```
Api -> Application, Infrastructure, Reporting
Infrastructure -> Application -> Domain
```

---

## Conventions

Observed in code; "not endorsed" marks a pattern logged as debt in [TECH_DEBT.md](./TECH_DEBT.md).

- **Architecture**: Domain ← Application ← Infrastructure ← Api; Reporting is standalone (`src/Orders.Reporting/Orders.Reporting.csproj`). net8.0, nullable and implicit usings on.
- **DI**: manual registration, all in `src/Orders.Api/Program.cs`; event handlers must be registered there because the dispatcher resolves them by type. Interfaces only at seams (`IOutbox`, `IMessagePublisher`, `IReportReader`).
- **Data access**: EF Core 8 + SQL Server, one `IEntityTypeConfiguration` per entity auto-applied (`OrdersDbContext.cs`). No migrations folder and no evidenced deploy command for `db/` scripts. Raw ADO.NET only in `SqlReportReader`.
- **API**: `[ApiController]`, `api/<resource>` routes. Four CRUD controllers use `OrdersDbContext` directly and bind entities as bodies (not endorsed, DEBT-005). No authentication or authorization configured (DEBT-006).
- **Events**: record + `[EventVersion(n)]` + `contracts/events/<topic>.v<n>.schema.json` + `EventRegistry` entry + handler registered in `Program.cs`; a version/schema mismatch routes to `<topic>.dlq` (`OutboxDispatcher.cs:29-35`).
- **Reports**: `IReportExport` + `ReportCatalog.All` entry + `db/views/rpt.vw*.sql` + `GRANT` in `db/security/reporting-grants.sql` + flag `reports.export.<key>` in `config/feature-flags.json` (a missing flag hides the report).
- **Async/logging**: `CancellationToken` flows through dispatch and reporting; handlers log with structured templates. `.Result` in the unused HTTP clients is not a convention (DEBT-011).
- **Testing**: xUnit 2.9.2 with `Microsoft.NET.Test.Sdk`; plain `Assert`, no mocking library; theories over registered events/reports (`tests/Orders.Tests/`). No start-up test. Target shape: behaviour tests through real objects, one theory row per new event or report.

### Verification Commands

| Category | Command | Evidence | Policy |
|----------|---------|----------|--------|
| build | `dotnet build Orders.sln` | `src/Orders.Api/Orders.Api.csproj` (every solution project is SDK-style C#) | run |
| test | `dotnet test Orders.sln` | `tests/Orders.Tests/Orders.Tests.csproj` | run |
| format | not available (no evidenced command) | — | — |
| lint | not available (no evidenced command) | — | — |
| migration/deploy | not available (no evidenced command) | — | manual/CI-only |
| data-validation | not available (no evidenced command) | — | — |

---

## Architecture Decisions

<!-- One-line INDEX of significant decisions here (ID — title — date — link). Full ADRs
     (Decision → Context → Consequences → Review notes) live in docs/architecture-decisions.md,
     added by the create-adr skill. Rationale: AGENTS.md loads on nearly every agent turn and
     anchors the prompt cache — keep it small; detail loads on demand. -->

- Events use an in-memory outbox and in-process dispatcher, not a durable outbox (`src/Orders.Infrastructure/Messaging/`; accidental or interim, unconfirmed).
- Reports read SQL views through a separate least-privilege `ReportReader` login (`db/security/reporting-grants.sql`).

Full detail in [docs/architecture-decisions.md](./docs/architecture-decisions.md).

---

## Common Tasks

When a task matches a skill below, invoke that skill with your skill tool before planning or editing.

Skills are a delivery-profile superset, not evidence that they apply. Use only when repository
evidence satisfies the gate:

- `add-tests` — add unit/integration tests following the repo's existing test framework, fixtures, and naming
- `perf` — scan a file, directory, or the whole repo for ~50 performance anti-patterns; produces tiered findings (Critical / Moderate / Info) with file locations and TECH_DEBT.md integration
- `dependency-audit` — scan for vulnerable/deprecated/outdated NuGet packages, set up automated scanning, or upgrade .NET to a newer major
- `create-adr` — record a significant architecture decision in Architecture Decisions
- `remember-for-team` — draft a team wiki entry (gotcha/context/recipe/failed-approach) for PR review
- `enforce-architecture` — wire the deterministic DIP/layering CI gate (NetArchTest)
- `enforce-standards` — make warnings, skipped tests, and analyzer findings build-breaking (`TreatWarningsAsErrors` + `.editorconfig` severities)

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
