<!--
ai-tech-lead-framework
  template: dotnet
  version: 0.97.2
  applied: 2026-10-15
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

Implementation observations only (README.md and code); intended users and business value are not stated in the repo and are unknown.

- ASP.NET Core (net8.0) order-management service: customers, products, orders, invoices (CRUD under `api/*`).
- Checkout journey: `api/checkout` place / ship / issue-invoice emits integration events (`order-placed`, `order-shipped`, `invoice-issued`) via an in-memory outbox.
- CSV report exports over SQL Server `rpt.*` views, gated by feature flags.
- Declared but unwired: scheduled jobs (`IScheduledJob`) and pricing/shipping/tax HTTP clients.

---

## Repository Structure

- `src/Orders.Api` — host (`Program.cs`, all DI registrations) and 6 controllers.
- `src/Orders.Application` — `OrderLifecycle` (enqueues events), event handlers, DTO records, job and HTTP-client stubs.
- `src/Orders.Domain` — entities (`Order`, `Invoice`, `Customer`, `Product`) and event records; no dependencies.
- `src/Orders.Infrastructure` — EF Core `OrdersDbContext` + per-entity configurations, outbox, `EventRegistry`, dispatcher.
- `src/Orders.Reporting` — `IReportExport` implementations, `ReportCatalog`, ADO.NET `SqlReportReader` (separate `Reporting` connection).
- `contracts/events` — JSON schemas per event/version; `db/views`, `db/security` — `rpt.*` views and grants; `config/feature-flags.json` — flags.
- `tests/Orders.Tests` — xUnit.

```
Api -> Application -> Domain      Api -> Infrastructure -> Application, Domain
Api -> Reporting (independent; SQL views via db/)
```

---

## Conventions

Observed in code unless marked *(target)*. Debt items are in [TECH_DEBT.md](./TECH_DEBT.md).

- **Architecture**: dependencies point inward; Domain has none and Application never references Infrastructure (`src/*/*.csproj`). Nullable and ImplicitUsings are on everywhere.
- **Naming**: file-per-type, PascalCase, `Async` suffix, `I` prefix for service seams (`IOutbox`, `IMessagePublisher`, `IReportReader`, `IReportExport`); entities, DTOs and events are interface-free (events share the `IIntegrationEvent` marker).
- **DI**: manual registration in `src/Orders.Api/Program.cs` only; no scanning. Every new event handler must be registered there, because `OutboxDispatcher` resolves it with `GetRequiredService`.
- **Data access**: EF Core 8 / SQL Server via `OrdersDbContext`, one `IEntityTypeConfiguration` per entity (auto-applied by assembly scan); no migrations in the repo. Reports use ADO.NET against `rpt.*` views as the `ReportReader` login.
- **API** *(target)*: new endpoints use an Application-layer service and request DTOs. Existing CRUD controllers query `DbContext` directly and bind entities as request bodies (DEBT-003). Intent unconfirmed by the developer.
- **Messaging**: events carry `[EventVersion(n)]` and must match the `vN` in their `contracts/events/*.vN.schema.json`; a mismatch is published to `<topic>.dlq` and the handler is skipped (`OutboxDispatcher.cs:29-35`).
- **Outbound HTTP** *(target)*: `IHttpClientFactory` typed clients, async with `CancellationToken`. Current clients violate this (DEBT-007).
- **Async**: `CancellationToken` is used on reports and the outbox only; controllers and EF calls omit it. No `async void`.
- **Logging**: `ILogger<T>` with message templates in handlers and the publisher; no other telemetry packages.
- **Money**: `decimal` fields with no currency, precision config or computation rules. Invariants are unconfirmed: do not invent rules (see Known Hazard Areas).
- **Testing**: xUnit 2.9.2 with `Microsoft.NET.Test.Sdk`; no mocking or assertion library; plain `Assert`. Two tests cover only registry and report-catalog wiring. *(target)* behaviour tests on `OutboxDispatcher` and `OrderLifecycle` using real instances and an in-memory `IMessagePublisher`/`IOutbox` fake.

### Verification Commands

| Category | Command | Evidence | Execution policy |
|----------|---------|----------|------------------|
| build | `dotnet build Orders.sln` | `.github/workflows/ci.yml`, `README.md` | run freely |
| test | `dotnet test Orders.sln` | `.github/workflows/ci.yml`, `README.md` | run freely |
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

Full detail in [docs/architecture-decisions.md](./docs/architecture-decisions.md). No ADRs are recorded yet; observed decisions that became convention (undocumented by the team):

- In-memory outbox (`InMemoryOutbox`) as the event queue, drained by a `BackgroundService` — accidental, see Known Hazard Areas.
- Schema-file-name versioning of integration events, enforced at dispatch time rather than build time.
- Reports served from dedicated `rpt.*` views under a least-privilege `ReportReader` login.

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
