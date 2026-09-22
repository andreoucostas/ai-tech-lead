# Architecture Decisions

Append-only ADR log. Entries are added by the `create-adr` skill (format: `## ADR-NNN: <title>` with Date / Status / Decision / Context / Alternatives considered / Consequences). The one-line index lives in `CLAUDE.md > Architecture Decisions`.

## ADR-001: Load procedures use the dbo schema

- **Date**: 2026-09-22
- **Status**: Confirmed (via `/bootstrap` Phase 2b developer clarification)
- **Decision**: `usp_LoadDimCustomer`, `usp_LoadDimRegion`, and `usp_LoadFactSales` are created in `dbo`, not schema-qualified to the dimensional layer they load (`dim`/`fact`).
- **Context**: Every table and view in the repo is schema-qualified to its layer (`stg`/`dim`/`fact`/`ctl`/`rpt`), but the three load procedures break that pattern by living in `dbo`. Bootstrap analysis flagged this as a possible naming-convention drift.
- **Alternatives considered**: Schema-qualifying procedures to match their target layer (e.g. `dim.usp_LoadDimCustomer`) was considered, since it would make procedure ownership visually consistent with table/view ownership.
- **Consequences**: `dbo` remains the home for all load orchestration code regardless of which layer(s) it touches (some procedures, like `usp_LoadFactSales`, span multiple layers and would not cleanly schema-qualify to a single one anyway). New load procedures should also be created in `dbo`.

---

## ADR-002: DimCustomer uses SCD Type 2

- **Date**: 2026-09-22
- **Status**: Confirmed intended, implementation incomplete (via `/bootstrap` Phase 2b developer clarification)
- **Decision**: `dim.DimCustomer` is designed as a Slowly Changing Dimension Type 2 — it declares `EffectiveFrom`, `EffectiveTo`, and `IsCurrent` to preserve customer attribute history over time.
- **Context**: `usp_LoadDimCustomer` currently only has a `WHEN NOT MATCHED THEN INSERT` branch — there is no `WHEN MATCHED` branch to close out a changed row (`EffectiveTo`, `IsCurrent = 0`) and insert a new version. A customer whose `SegmentName` or `RegionKey` changes today is never updated. The developer confirmed SCD2 is still the intended target, not an accidental/vestigial schema — see `TECH_DEBT.md > DEBT-006`.
- **Alternatives considered**: Treating `DimCustomer` as SCD Type 1 (overwrite-in-place, drop the versioning columns) was considered and rejected — attribute history is a requirement.
- **Consequences**: The versioning/update branch in `usp_LoadDimCustomer` is open tech debt (DEBT-006), not a design to reverse. `usp_LoadFactSales` already correctly joins on `IsCurrent = 1`, anticipating this design once implemented.

---

## ADR-003: ctl.LoadRun reserved for incremental loading

- **Date**: 2026-09-22
- **Status**: Confirmed intended, not yet wired in (via `/bootstrap` Phase 2b developer clarification)
- **Decision**: `ctl.LoadRun` (`LoadRunId`, `StartedAt`, `Watermark`) exists to support future batch/watermark-driven incremental loading of the warehouse.
- **Context**: No current load procedure reads or writes `ctl.LoadRun`. `fact.FactSales.LoadRunId` is instead populated directly from `stg.StgSalesOrder.BatchId`, an independent value with no evidenced relationship to `ctl.LoadRun.LoadRunId`. Every load currently reprocesses the entire staging table unconditionally.
- **Alternatives considered**: Removing `ctl.LoadRun` as dead schema was considered and rejected — the developer confirmed it is intentionally reserved for a future incremental-load implementation.
- **Consequences**: `ctl.LoadRun` must not be repurposed or dropped. When incremental/watermark-driven loading is implemented (tracked as `TECH_DEBT.md > DEBT-009`), procedures should insert a `LoadRunId`/`StartedAt` row and scope the staging read by `Watermark`.
