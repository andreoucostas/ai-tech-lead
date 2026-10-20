# Architecture Decisions

Append-only ADR log. Entries are added by the `create-adr` skill (format: `## ADR-NNN: <title>` with Date / Status / Decision / Context / Alternatives considered / Consequences). The one-line index lives in `AGENTS.md > Architecture Decisions`.

ADR-001 to ADR-003 were recorded by `/bootstrap` from the code (inferred, not authored by the team); the Context and Alternatives are unknown and need a maintainer.

## ADR-001: Event contract versioned by `[EventVersion]` and schema file name

- **Date**: 2026-10-20
- **Status**: Observed (inferred from code; pending team confirmation)
- **Decision**: Each integration event carries `[EventVersion(n)]` and is registered with a schema path `contracts/events/<topic>.v<n>.schema.json`; the dispatcher requires the two versions to match.
- **Context**: not stated in the repo. Evidence: `OutboxDispatcher.cs:29-35`, `EventRegistry.cs:12-14`.
- **Alternatives considered**: unknown.
- **Consequences**: a mismatch silently routes the event to `<topic>.dlq` and skips the handler. The file name is therefore load-bearing.

## ADR-002: Reports read `rpt.*` views through a least-privilege `ReportReader` login

- **Date**: 2026-10-20
- **Status**: Observed (inferred from code; pending team confirmation)
- **Decision**: Exports query SQL views over a separate `Reporting` connection string whose login is granted `SELECT` on each view only.
- **Context**: not stated. Evidence: `IReportReader.cs:11`, `db/security/reporting-grants.sql`.
- **Alternatives considered**: unknown.
- **Consequences**: every new report needs a view and a grant; the SQL under `db/` has no evidenced deployment vehicle.

## ADR-003: Report visibility via `config/feature-flags.json`

- **Date**: 2026-10-20
- **Status**: Observed (inferred from code; pending team confirmation)
- **Decision**: An export is visible only when `reports.export.<key>` is `true` in a JSON file read at request time.
- **Context**: not stated. Evidence: `ReportCatalog.cs:12-13`, `ReportsController.cs:17-18`.
- **Alternatives considered**: unknown.
- **Consequences**: a missing flag hides the export; the file is not copied by the Api project (see wiki `reports-feature-flags-path`).
