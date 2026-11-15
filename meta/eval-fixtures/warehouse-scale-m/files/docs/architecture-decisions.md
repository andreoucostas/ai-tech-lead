# Architecture Decisions

Append-only ADR log. Entries are added by the `create-adr` skill (format: `## ADR-NNN: <title>` with Date / Status / Decision / Context / Alternatives considered / Consequences). The one-line index lives in `AGENTS.md > Architecture Decisions`.

## ADR-001: Fact loads are plain INSERT…SELECT with `stg.BatchId` as `LoadRunId`

- **Date**: 2026-11-15
- **Status**: Observed (accidental convention); developer-assumed intended, not formally approved
- **Decision**: 64 of 65 `usp_LoadFact*` procs insert from `stg` with inner joins to dims and `DimDate`, taking `LoadRunId` from `stg.BatchId` (`StoredProcedures/usp_LoadFactDepositBalanceMovement.sql`).
- **Context**: `ctl.LoadRun` is only written by `usp_LoadFactSalesIncremental.sql` and `usp_LoadFactSales_v2.sql`, neither scheduled in `Jobs/`.
- **Alternatives considered**: watermark load via `ctl.LoadRun` (`usp_LoadFactSalesIncremental.sql`), not adopted.
- **Consequences**: no rerun guard (PK failure or double-load risk), inner joins drop rows with no dim match silently, `ctl.LoadRun` does not track most loads.
- **Review notes**: confirm with the team; see `FRAMEWORK-CONTEXT.md > Known Hazard Areas`.
