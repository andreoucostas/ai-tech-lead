# Architecture Decisions

Append-only ADR log. Entries are added by the `create-adr` skill (format: `## ADR-NNN: <title>` with Date / Status / Decision / Context / Alternatives considered / Consequences). The one-line index lives in `AGENTS.md > Architecture Decisions`.

_No decisions recorded yet._

## ADR-001: Star schema with SCD2 customer dimension and surrogate-key facts

- **Date**: 2026-10-20
- **Status**: Accepted (observed in code; recorded by /bootstrap, not authored by the team)
- **Decision**: Sales data is modelled as `stg` → `dim`/`fact` → `rpt`, with `fact.FactSales` holding dimension surrogate keys and `dim.DimCustomer` carrying SCD2 columns (`EffectiveFrom`, `EffectiveTo`, `IsCurrent`).
- **Context**: Evidence: `Tables/*.sql`, `StoredProcedures/usp_LoadFactSales.sql:5-7` (joins current customer rows). The repository states no rationale; intent is unconfirmed.
- **Alternatives considered**: not recorded.
- **Consequences**: Facts must resolve surrogate keys at load, so dimensions must load first. SCD2 handling and rerun control are not yet implemented (DEBT-001, DEBT-002).
