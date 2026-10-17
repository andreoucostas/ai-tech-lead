<!--
ai-tech-lead-framework
  template: dotnet
  version: 0.97.2
  applied: 2026-10-15
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

Implementation observations (code shows what exists, not intent; purpose beyond the README line, users, and event consumers are unknown here):
- ASP.NET Core (net8.0) order-management service: customers, products, orders, invoices over EF Core/SQL Server (`README.md`).
- Checkout actions (`place`, `ship`, `invoices/{id}/issue`) enqueue integration events (`order-placed`, `order-shipped`, `invoice-issued`) to an in-memory outbox drained by a hosted service.
- CSV report exports read SQL views `rpt.*`, gated by `config/feature-flags.json`.
- Also present: two no-op scheduled job classes and three pricing/shipping/tax HTTP clients, neither wired into `Program.cs`.

---

## Repository Structure

- `src/Orders.Api` — host and entry point (`Program.cs`, manual DI) plus `Controllers/`. HTTP changes go here.
- `src/Orders.Application` — `OrderLifecycle` (event creation), event handlers, job classes, outbound clients, DTO records.
- `src/Orders.Domain` — entities (`Entities/`) and integration events (`Events/`); no dependencies.
- `src/Orders.Infrastructure` — `Persistence/` (DbContext + per-entity configurations) and `Messaging/` (outbox, dispatcher, registry, publisher).
- `src/Orders.Reporting` — report catalog, exports, SQL reader. SQL for it lives in `db/views/` and `db/security/`.
- `contracts/events/` — JSON schemas per event; `config/feature-flags.json` — report visibility flags; `tests/Orders.Tests` — xUnit.

```
Api ─► Application ─► Domain        Api ─► Infrastructure ─► Application, Domain
Api ─► Reporting (standalone; SQL views in db/)
```

---

## Conventions

Observed reality, not endorsement; known deviations are in [TECH_DEBT.md](./TECH_DEBT.md).

- **Architecture**: project references run Api → Application/Infrastructure/Reporting → Domain (`*.csproj`); Domain references nothing. Controllers still use `OrdersDbContext` directly (DEBT-004), so do not copy that for new behaviour: put it in Application.
- **Naming**: namespace = project + folder; file-scoped namespaces; `sealed` classes and positional `record`s for DTOs/events; `_camelCase` private fields; `Async` suffix on service methods.
- **DI**: manual registration only, in `src/Orders.Api/Program.cs` (no scanning). Handlers/dispatcher/lifecycle Scoped; registry/publisher/outbox/report reader Singleton. Interfaces exist only at real seams (`IOutbox`, `IMessagePublisher`, `IReportReader`, `IIntegrationEventHandler<T>`); everything else is concrete.
- **Data access**: EF Core 8 SQL Server; one `IEntityTypeConfiguration<T>` per entity, auto-applied by `OrdersDbContext.OnModelCreating`. No repositories, no migrations in repo. Reports use ADO.NET (`SqlReportReader`) over `rpt.*` views as the `ReportReader` login; grant each new view in `db/security/reporting-grants.sql`.
- **API**: `[ApiController]`, route `api/<resource>`, `IActionResult`. No authN/Z, validation, request DTOs, versioning, or error middleware exist; do not assume any.
- **Events**: each event has an `[EventVersion(n)]`, a `contracts/events/<topic>.v<n>.schema.json` whose `v<n>` must match, a handler, and an `EventRegistry` entry; a mismatch routes to `<topic>.dlq` and an unregistered event is dropped (`OutboxDispatcher.cs:24-34`).
- **Async**: `CancellationToken` is threaded through reporting, outbox and handlers but not the CRUD/checkout actions (DEBT-010). Add it where the path is touched and the outcome needs it.
- **Null handling / logging**: `<Nullable>enable</Nullable>` everywhere; string properties default `= ""`. `ILogger<T>` with structured templates (`{Topic}`, `{EventId}`); no OpenTelemetry.
- **Money**: `decimal` (`Order.Total`, `Invoice.Amount`, `MoneyDto`). Sign, precision, rounding, and idempotency policy are not stated anywhere; treat as unverified (DEBT-003, DEBT-007).
- **Testing**: xUnit 2.9.2 with `Microsoft.NET.Test.Sdk`; no mocking or assertion library beyond `Xunit.Assert`; tests in `tests/Orders.Tests` use `[Theory]`/`[InlineData]` per key and read `config/feature-flags.json` via a csproj link. No `WebApplicationFactory`. Target shape: behaviour tests over Application/Infrastructure/Reporting plus controller integration tests.

### Verification Commands

| Category | Command | Evidence | Execution policy |
|----------|---------|----------|------------------|
| build | not available (no evidenced command) | none in CI, scripts, or manifests | n/a |
| test | not available (no evidenced command) | none | n/a |
| format | not available (no evidenced command) | none | n/a |
| lint | not available (no evidenced command) | none | n/a |
| migration/deploy | not available (no evidenced command) | `db/` holds SQL but no deploy invocation | manual/CI-only |
| data-validation | not available (no evidenced command) | none | n/a |

---

## Architecture Decisions

- ADR-001 — Outbox is an in-process queue drained by a hosted service — 2026-10-17 — [detail](./docs/architecture-decisions.md)
- ADR-002 — Event schema version is the `.vN.` file-name suffix, compared to `[EventVersion]` — 2026-10-17 — [detail](./docs/architecture-decisions.md)
- ADR-003 — CSV reports read `rpt.*` SQL views through a read-only login — 2026-10-17 — [detail](./docs/architecture-decisions.md)

A one-line index of significant decisions (including accidental ones that became convention). Full detail in [docs/architecture-decisions.md](./docs/architecture-decisions.md).

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
