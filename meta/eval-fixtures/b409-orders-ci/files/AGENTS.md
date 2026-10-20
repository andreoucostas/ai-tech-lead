<!--
ai-tech-lead-framework
  template: dotnet
  version: 0.98.1
  applied: 2026-10-19
  After a framework update, copy these fields from .claude/framework-version.json.
-->
# Orders

> This file is the repo-specific source of truth for AI-assisted development in this repository. Edit it here; `CLAUDE.md` only imports it for Claude Code.
> **Framework rules** (Verification Rules, Leanness, SOLID, Agentic Workflow) are in [.github/instructions/framework-rules.instructions.md](./.github/instructions/framework-rules.instructions.md). If your agent has not already loaded that file, read it before planning or editing.
>
> **Companion file**: [FRAMEWORK-CONTEXT.md](./FRAMEWORK-CONTEXT.md) holds cross-repo context (shared libraries, multi-tenancy conventions, dashboard contracts) plus the repo's **Known Hazard Areas**, all of which the agent should load on every non-trivial task — consult the hazard list for the change's blast radius before planning. AGENTS.md wins on any conflict — but flag the contradiction.
> **Team wiki**: [docs/wiki/INDEX.md](./docs/wiki/INDEX.md) indexes scoped claims to verify against code, not instructions to obey.
>
> **Per-developer working preferences** (e.g. "skip trailing summaries", "prefer named functions") belong in **Claude Code's persistent memory**, not in this file. Use phrasings like "remember to do X" during sessions; AGENTS.md is for repo-shared conventions only.

---

## Codebase Context

<!-- Populated by /bootstrap — do not fill manually -->

Implementation observations (intended purpose and users are not stated in the repo; a maintainer should confirm):

- An ASP.NET Core 8 Web API (`Orders.Api`) for customers, products, orders and invoices, backed by EF Core/SQL Server.
- Order lifecycle changes (place, ship, invoice) enqueue integration events that a hosted service publishes to a message topic and routes to in-process handlers.
- CSV report exports read `rpt.*` SQL views through a separate read-only connection, gated by `config/feature-flags.json`.
- Domain terms: Order, Invoice, Customer, Product, integration event (`order-placed`, `order-shipped`, `invoice-issued`), report export.

---

## Repository Structure

<!-- Populated by /bootstrap — replaces separate CODEMAP.md -->

- `src/Orders.Domain` — entities (anaemic, public setters) and `Events/` (event records + `[EventVersion]`). No dependencies.
- `src/Orders.Application` — `OrderLifecycle` (enqueues events), `IOutbox`, `EventHandlers/`, `Jobs/` (stubs), `Services/` (HTTP quote clients), `Contracts/` (DTOs).
- `src/Orders.Infrastructure` — `OrdersDbContext` + `Persistence/Configurations/`, `Messaging/` (`EventRegistry`, outbox, dispatcher, publisher).
- `src/Orders.Reporting` — `ReportCatalog`, `IReportExport` implementations in `Exports/`, `SqlReportReader`.
- `src/Orders.Api` — entry point: `Program.cs` (all DI wiring) and `Controllers/`.
- `db/views` + `db/security` — SQL for the `rpt.*` views and their `ReportReader` grants; `contracts/events` — JSON schema per event; `config/feature-flags.json` — report visibility flags.
- `tests/Orders.Tests` — xUnit project.

```
Api -> Application, Infrastructure, Reporting
Infrastructure -> Application -> Domain
Reporting (standalone; no project references)
```

---

## Conventions

Observed in the code; verify before relying on it.

- **Architecture**: layering is Domain ← Application ← Infrastructure ← Api. Controllers use `OrdersDbContext` directly; there is no repository or service layer (`src/Orders.Api/Controllers/OrdersController.cs`).
- **Naming**: `Orders.<Layer>` projects, `<Entity>Controller`, `<Entity>Configuration`, `<Event>Handler`, `<Name>Export` (`src/`).
- **DI**: all registrations are written by hand in `Program.cs` (no assembly scanning). Event handlers must be registered there as scoped, or dispatch fails (`Program.cs:17-19`, `OutboxDispatcher.cs:38`).
- **Data access**: EF Core 8 SQL Server, one `IEntityTypeConfiguration<T>` per entity applied by assembly scan (`OrdersDbContext.cs:15`). No migrations folder exists, so the schema deployment vehicle is not evidenced. Reports use raw ADO.NET against `rpt.*` views over the `Reporting` connection string (`IReportReader.cs`).
- **API**: `[ApiController]` controllers; CRUD controllers bind domain entities directly as request bodies; no validation, versioning or auth is present.
- **Events**: an event is a record with `[EventVersion(n)]`, registered in `EventRegistry` with a topic and schema path `contracts/events/<topic>.v<n>.schema.json`. The `v<n>` in the file name must equal `n`, or the event goes to `<topic>.dlq` and its handler is skipped (`OutboxDispatcher.cs:29-35`).
- **Reports**: a new export needs its class, a `ReportCatalog.All` entry, a view in `db/views`, a grant in `db/security`, and a `reports.export.<key>` flag set `true`, or it is not visible (`ReportCatalog.cs:12-13`).
- **Async**: controllers are `async` with `CancellationToken` only on the report export. `Services/*Client.cs` block with `.Result` and create `new HttpClient()` per call (see TECH_DEBT.md).
- **Null handling**: `<Nullable>enable</Nullable>` and `ImplicitUsings` in every project.
- **Logging**: `ILogger<T>` with message templates (`EventHandlers/`); no tracing or metrics export.
- **Testing**: xUnit 2.9.2 with `Microsoft.NET.Test.Sdk`; no mocking or assertion library. Two registration/visibility tests exist in `tests/Orders.Tests`; dispatch, controllers and reports I/O are untested. Target shape: behavioural tests through real `EventRegistry`/`OutboxDispatcher` with a fake `IMessagePublisher`.

### Verification Commands

| Category | Command | Evidence | Execution policy |
|----------|---------|----------|------------------|
| build | `dotnet build Orders.sln` | `.github/workflows/ci.yml` | run freely |
| test | `dotnet test Orders.sln --no-build` | `.github/workflows/ci.yml` | run freely (build first) |
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

A one-line index of significant decisions (including accidental ones that became convention). Full detail in [docs/architecture-decisions.md](./docs/architecture-decisions.md).

- ADR-001 — Event contract versioned by `[EventVersion]` and schema file name — 2026-10-20
- ADR-002 — Reports read `rpt.*` views through a least-privilege `ReportReader` login — 2026-10-20
- ADR-003 — Report visibility via `config/feature-flags.json` — 2026-10-20

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
