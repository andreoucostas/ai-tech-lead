# Architecture Decisions

Append-only ADR log. Entries are added by the `create-adr` skill (format: `## ADR-NNN: <title>` with Date / Status / Decision / Context / Alternatives considered / Consequences). The one-line index lives in `AGENTS.md > Architecture Decisions`.

---

## ADR-001: Warehouse schema managed as a SQL Server Database Project

- **Date**: 2026-10-14
- **Status**: Accepted (observed — recorded by `/bootstrap`, not confirmed with a maintainer)

### Decision
The warehouse schema (`Tables/`, `StoredProcedures/`, `Views/`) is defined as `.sql` source files built and deployed through `warehouse.sqlproj`, a SQL Server Database Project using the `Microsoft.Build.Sql` SDK (version `0.2.0`). This is the repository's only build/deployment artifact.

### Context
No migration-script folder, DACPAC publish profile, or other schema-change mechanism exists in the repository. Every `.sql` file under `Tables/`, `StoredProcedures/`, and `Views/` is included in the project by the SDK's default glob (the `.sqlproj` file itself has no explicit `<Build Include>` items — it relies entirely on the SDK's implicit inclusion).

### Alternatives considered
Not evidenced in the repository — no record of a prior migration-script approach or other tooling choice exists to compare against.

### Consequences
- Schema changes are reviewable as plain `.sql` diffs and build-checked by the SDK rather than applied as ad-hoc scripts.
- No evidenced CI step currently builds or publishes this project (see `TECH_DEBT.md` DEBT-008) — the decision to use a database project is not yet backed by an evidenced deployment pipeline.

### Review notes
Recorded from code evidence only; a maintainer should confirm this was a deliberate choice (versus, e.g., an unfinished migration away from another approach) and fill in why `Microsoft.Build.Sql` was chosen over SSDT's traditional `.sqlproj` or another tool.
