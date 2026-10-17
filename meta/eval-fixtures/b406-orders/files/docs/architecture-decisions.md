# Architecture Decisions

Append-only ADR log. Entries are added by the `create-adr` skill (format: `## ADR-NNN: <title>` with Date / Status / Decision / Context / Alternatives considered / Consequences). The one-line index lives in `AGENTS.md > Architecture Decisions`.

> ADR-001 to ADR-003 were inferred by `/bootstrap` from the code on 2026-10-17. They record what the code does; no person has confirmed the intent.

## ADR-001: Outbox is an in-process queue drained by a hosted service

- **Date**: 2026-10-17
- **Status**: Observed (accidental or intentional unknown); see DEBT-005
- **Decision**: `IOutbox` is bound to `InMemoryOutbox` (a `ConcurrentQueue`), drained every second by `OutboxProcessor` (`src/Orders.Api/Program.cs:13,16`).
- **Context**: Controllers save to SQL, then call `OrderLifecycle`, which enqueues the event (`CheckoutController.cs:26-27`).
- **Alternatives considered**: not recorded.
- **Consequences**: events are lost on restart or crash, and the DB write and the enqueue are not atomic. Only a single instance publishes.

## ADR-002: Event schema version is the `.vN.` file-name suffix

- **Date**: 2026-10-17
- **Status**: Observed
- **Decision**: `OutboxDispatcher` compares `[EventVersion(n)]` with the `.v<n>.schema.json` suffix of the registered schema path; a mismatch publishes to `<topic>.dlq` (`OutboxDispatcher.cs:29-35`).
- **Context**: `EventRegistry` pairs each event type with a topic, handler and schema path.
- **Alternatives considered**: not recorded.
- **Consequences**: schema contents are never read or validated at runtime; only the number is compared. Bumping an event version means renaming the schema file too.

## ADR-003: CSV reports read `rpt.*` SQL views through a read-only login

- **Date**: 2026-10-17
- **Status**: Observed
- **Decision**: `SqlReportReader` uses the `Reporting` connection string (login `ReportReader`) and `SELECT * FROM <view>`; `db/security/reporting-grants.sql` grants SELECT per view.
- **Context**: `ReportCatalog.All` lists exports; `config/feature-flags.json` controls which are visible.
- **Alternatives considered**: not recorded.
- **Consequences**: a new report needs a view, a grant, a catalog entry and a flag. How `db/` is deployed is not evidenced in the repo.
