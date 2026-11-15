# Architecture Decisions

Append-only ADR log. Entries are added by the `create-adr` skill (format: `## ADR-NNN: <title>` with Date / Status / Decision / Context / Alternatives considered / Consequences). The one-line index lives in `AGENTS.md > Architecture Decisions`.

## ADR-001: In-memory outbox singleton for integration events

- **Date**: 2026-11-15
- **Status**: Accepted (accidental; recorded from code, not by a decision-maker)
- **Decision**: `IOutbox` is bound to `InMemoryOutbox`, a singleton `ConcurrentQueue` (`src/Orders.Api/Program.cs:13`); `OutboxProcessor` drains it every second.
- **Context**: Controllers save to EF Core, then enqueue (`CheckoutController.cs:26-27`). Intent is unknown.
- **Alternatives considered**: none evidenced.
- **Consequences**: events are not durable and not atomic with the database write; they are lost on restart or crash.
- **Review notes**: see hazard in `FRAMEWORK-CONTEXT.md`.

## ADR-002: Event version enforced by schema-file name against `[EventVersion]`

- **Date**: 2026-11-15
- **Status**: Accepted (observed)
- **Decision**: `OutboxDispatcher` compares `[EventVersion]` on the event type with the `.v<n>.schema.json` suffix of its registered schema path and publishes to `<topic>.dlq` on mismatch (`OutboxDispatcher.cs:29-35`).
- **Context**: `order-shipped` is at v2, the others at v1 (`EventRegistry.cs`).
- **Alternatives considered**: none evidenced.
- **Consequences**: bumping a version requires renaming the schema file and updating the registry together; schema content is never validated at runtime.
- **Review notes**: none.

## ADR-003: Reports served from SQL views via a least-privilege login, gated by feature flags

- **Date**: 2026-11-15
- **Status**: Accepted (observed)
- **Decision**: exports read `rpt.vw*` views through the `Reporting` connection string signing in as `ReportReader` (`SqlReportReader.cs`), with `GRANT SELECT` per view (`db/security/reporting-grants.sql`) and visibility from `config/feature-flags.json` (`ReportCatalog.cs:12-13`).
- **Context**: separates report reads from the `Orders` EF Core connection.
- **Alternatives considered**: none evidenced.
- **Consequences**: a new view needs a grant and a flag or the export is hidden or fails.
- **Review notes**: none.
