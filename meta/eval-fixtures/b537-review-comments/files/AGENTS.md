<!--
ai-tech-lead-framework
  template: dotnet
  version: 0.98.6
  applied: 2026-11-13
  After a framework update, copy these fields from .claude/framework-version.json.
-->
# Orders

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

Implementation observations from code only; intended users and actual usage are unknown until a named owner supplies them.

- ASP.NET Core (net8.0) orders API: CRUD for customers, products, orders and invoices; a checkout flow (place, ship, issue invoice) that emits integration events; CSV report exports.
- Domain concepts: `Order`, `Invoice`, `Customer`, `Product` (monetary `decimal`), and three versioned integration events (`order-placed` v1, `order-shipped` v2, `invoice-issued` v1) with JSON schemas under `contracts/events`.
- Critical journeys: checkout → in-memory outbox → `OutboxProcessor` → `OutboxDispatcher` → publisher + handler; report key → feature flag → `rpt.vw*` view → CSV.

---

## Repository Structure

- `src/Orders.Api` — host; `Program.cs` holds all DI registration; `Controllers/` are the endpoints.
- `src/Orders.Application` — `OrderLifecycle` (enqueues events), `EventHandlers/`, `Jobs/` (unreferenced scaffolding), `Services/` (`*Client` HTTP stubs), `Contracts/` (DTOs, unused).
- `src/Orders.Domain` — entities (plain property bags) and event records with `[EventVersion]`.
- `src/Orders.Infrastructure` — `OrdersDbContext` + `Configurations/`; `Messaging/` (registry, outbox, dispatcher, publisher).
- `src/Orders.Reporting` — `ReportCatalog`, `Exports/`, `SqlReportReader`; SQL lives in `db/views` and `db/security`.
- Changes go: endpoints → `Controllers/`; events → Domain + Infrastructure `EventRegistry` + `contracts/events`; reports → `Exports/` + `db/` + `config/feature-flags.json`.

```text
Api → Application, Infrastructure, Reporting
Infrastructure → Application, Domain      Application → Domain
Reporting → (Microsoft.Data.SqlClient only)      Tests → Infrastructure, Reporting
```

---

## Conventions

- **Architecture**: layered Api/Application/Domain/Infrastructure plus Reporting; dependencies point inward (`Orders.Domain` references nothing). Evidence: `src/*/*.csproj`.
- **Data access**: EF Core SqlServer 8.0.10, one `IEntityTypeConfiguration` per entity loaded by `ApplyConfigurationsFromAssembly` (`OrdersDbContext.cs`); no repository layer, controllers use `OrdersDbContext` directly (`OrdersController.cs`). Reporting reads SQL views with raw `SqlClient` as the `ReportReader` login (`SqlReportReader.cs`).
- **API**: attribute-routed `[ApiController]`s on `api/<plural>`; domain entities are bound as request bodies, no DTOs or validation in use.
- **DI**: manual registration, all in `Program.cs`; every event handler must be registered there because `OutboxDispatcher` resolves it with `GetRequiredService` (`OutboxDispatcher.cs:38`).
- **Events**: each event record carries `[EventVersion(n)]`, a schema `contracts/events/<topic>.v<n>.schema.json` whose `v<n>` must equal it, and an `EventRegistry` entry; a mismatch routes to `<topic>.dlq` (`OutboxDispatcher.cs:29-35`).
- **Reports**: an export is visible only if `config/feature-flags.json` has `reports.export.<key>: true` (`ReportCatalog.cs:12-13`); each view needs a `GRANT SELECT … TO ReportReader` in `db/security/reporting-grants.sql`.
- **Async/null**: `Nullable` and `ImplicitUsings` enabled; `CancellationToken` used in reporting and messaging, not in controllers; `Services/*Client` use sync-over-async `.Result`.
- **Pricing**: adjustments under `src/Orders.Application/Pricing/` are classes named `<Adjustment>Rule` (for example `RoundingRule`), never `Helper`, `Manager` or `Utils`. The pricing rules themselves are specified in `docs/requirements/pricing.md`.
- **Logging**: `ILogger<T>` structured templates (`ServiceBusPublisher.cs`); no tracing or metrics export.
- **Testing**: xunit 2.9.2 on Microsoft.NET.Test.Sdk (`tests/Orders.Tests`); no mocking or assertion library; two theory tests guarding registration lists (`EventRegistryTests.cs`, `ReportCatalogTests.cs`); no integration tests. Target shape: behaviour tests through `OutboxDispatcher` and the controllers.

### Verification Commands

| Category | Command | Evidence | Execution policy |
|----------|---------|----------|------------------|
| build | `dotnet build Orders.sln` | `Orders.sln` (all SDK-style C# projects) | run freely |
| test | `dotnet test Orders.sln` | `tests/Orders.Tests/Orders.Tests.csproj` | run freely |
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

- ADR-001 — In-memory outbox singleton for integration events (accidental) — 2026-11-15
- ADR-002 — Event version enforced by schema-file name vs `[EventVersion]` — 2026-11-15
- ADR-003 — Reports served from SQL views via a least-privilege `ReportReader` login, gated by feature flags — 2026-11-15

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

Review comments on the current branch's pull request are read with `pwsh -NoProfile -File scripts/pr-comments.ps1` (prints JSON).

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
