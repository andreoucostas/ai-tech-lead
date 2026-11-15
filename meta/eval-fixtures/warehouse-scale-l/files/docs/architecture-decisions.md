# Architecture Decisions

Append-only ADR log. Entries are added by the `create-adr` skill (format: `## ADR-NNN: <title>` with Date / Status / Decision / Context / Alternatives considered / Consequences). The one-line index lives in `AGENTS.md > Architecture Decisions`.

ADR-001 and ADR-002 were recovered by `/bootstrap` from code on 2026-11-15 as accidental decisions that became convention. Their rationale is not recorded in the repo; a maintainer should confirm or amend them.

## ADR-001: Job scripts own load ordering and orchestration

- **Date**: 2026-11-15 (recovered)
- **Status**: Observed convention; rationale unconfirmed
- **Decision**: Load order (dimensions before facts) is the `@step_id` order of `msdb.dbo.sp_add_jobstep` calls in `Jobs/<Subject>Daily.sql` and `Jobs/NightlyCore.sql`. No procedure calls another and no dependency metadata exists.
- **Context**: 432 job scripts, each one `sp_add_job`, one step per `usp_Load*` procedure, then `sp_add_jobserver` (`Jobs/NightlyCore.sql:1-5`). No `sp_add_jobschedule`, failure-action settings or `.sqlproj` discovery were found.
- **Consequences**: A new procedure must be added to a job by hand or it never runs. Ordering mistakes are not detectable from source. Schedules are not version-controlled.
- **Review notes**: Unknown whether the jobs are deployed from these scripts or recreated elsewhere.

## ADR-002: No declared foreign keys; integrity lives in load joins

- **Date**: 2026-11-15 (recovered)
- **Status**: Observed convention; rationale unconfirmed
- **Decision**: Tables declare a primary key only. Fact → dimension relationships exist as inner joins inside `usp_LoadFact*` procedures.
- **Context**: No `FOREIGN KEY`, `REFERENCES` or `UNIQUE` appears in `Tables/*.sql` (W2 grep count 0). Example: `Tables/fact.FactSales.sql`.
- **Consequences**: Unmatched staging rows are dropped silently by the inner joins; the database enforces no referential integrity or business-key uniqueness.
- **Review notes**: Common in warehouses for load speed; confirm intent.
