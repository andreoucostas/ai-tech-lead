# Architecture Decisions

Append-only ADR log. Entries are added by the `create-adr` skill (format: `## ADR-NNN: <title>` with Date / Status / Decision / Context / Alternatives considered / Consequences). The one-line index lives in `AGENTS.md > Architecture Decisions`.

## ADR-001: In-memory outbox with in-process dispatch

- **Date**: 2026-11-25 (recorded by `/bootstrap` from code; original decision date unknown)
- **Status**: Observed, unconfirmed (may be interim)
- **Decision**: Lifecycle events are enqueued to a singleton `InMemoryOutbox` and drained by the hosted `OutboxProcessor`, which publishes via `IMessagePublisher` and then invokes the handler in-process (`src/Orders.Infrastructure/Messaging/`).
- **Context**: `ServiceBusPublisher` only logs, so the pipeline is not yet connected to a real bus.
- **Alternatives considered**: not recorded.
- **Consequences**: events are lost on restart and are not atomic with the database save (DEBT-003, DEBT-004). Review: confirm with the team whether this is intended for production.

## ADR-002: Reports read SQL views through a least-privilege login

- **Date**: 2026-11-25 (recorded by `/bootstrap` from code; original decision date unknown)
- **Status**: Observed
- **Decision**: Exports query `rpt.*` views using the `Reporting` connection string, which signs in as `ReportReader` with `SELECT` granted per view (`db/security/reporting-grants.sql`).
- **Context**: Separates report reads from the EF-managed `dbo` tables.
- **Alternatives considered**: not recorded.
- **Consequences**: each new view needs its own `GRANT`; deployment of the scripts is unrecorded (DEBT-010).
