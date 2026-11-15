# Architecture Decisions

Append-only ADR log. Entries are added by the `create-adr` skill (format: `## ADR-NNN: <title>` with Date / Status / Decision / Context / Alternatives considered / Consequences). The one-line index lives in `AGENTS.md > Architecture Decisions`.

## ADR-001: SQL project as schema deployment vehicle

- **Date**: 2026-11-15
- **Status**: Accepted (observed, recorded retroactively; intent unconfirmed)
- **Decision**: Schema objects are source-controlled as one `.sql` file per object and built by `warehouse.sqlproj` using the `Microsoft.Build.Sql/0.2.0` SDK.
- **Context**: `warehouse.sqlproj`; objects under `Tables/`, `StoredProcedures/`, `Views/`, `Jobs/`.
- **Alternatives considered**: not recorded.
- **Consequences**: Deployment is a DACPAC-style publish; no build or publish command is evidenced in the repo. `Jobs/NightlyCore.sql` uses `msdb` calls, which a SQL project does not normally deploy; how it is applied is unknown.

## ADR-002: SQL Agent job step order as sole load orchestration

- **Date**: 2026-11-15
- **Status**: Accepted (observed, recorded retroactively; intent unconfirmed)
- **Decision**: Load ordering (dimensions before facts) is expressed only as the step sequence of the "Nightly core" job.
- **Context**: `Jobs/NightlyCore.sql:1-5`.
- **Alternatives considered**: not recorded.
- **Consequences**: Procedures carry no dependency checks, so running one by hand or adding a load without a job step can break ordering; failure handling and run records are absent (DEBT-005, DEBT-007).
