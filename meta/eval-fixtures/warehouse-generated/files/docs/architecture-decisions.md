# Architecture Decisions

Append-only ADR log. Entries are added by the `create-adr` skill (format: `## ADR-NNN: <title>` with Date / Status / Decision / Context / Alternatives considered / Consequences). The one-line index lives in `AGENTS.md > Architecture Decisions`.

## ADR-001: Schema-per-layer naming for tables/views, not procedures

- **Date**: 2026-09-30
- **Status**: Accepted (observed convention; drift flagged)

### Decision
Tables and views are named and owned by warehouse layer via SQL Server schema: `ctl` (load-run
control), `stg` (staging), `dim` (dimensions), `fact` (facts), `rpt` (reporting/mart views). Stored
procedures do not follow this — all three (`usp_LoadDimCustomer`, `usp_LoadDimRegion`,
`usp_LoadFactSales`) are created under the default `dbo` schema.

### Context
Every table and view file under `Tables/` and `Views/` uses a layer-prefixed schema
(`Tables/stg.StgSalesOrder.sql`, `Tables/dim.DimCustomer.sql`, `Tables/fact.FactSales.sql`,
`Views/rpt.vwFinanceExtract.sql`, etc.) with no exception. All three files under
`StoredProcedures/` instead declare `CREATE PROCEDURE dbo.usp_Load...`. No document in the repo
records whether `dbo` for procedures is intentional or a naming-convention gap; this was raised in
`/bootstrap` Phase 2b and the developer chose not to resolve it at bootstrap time (see
`TECH_DEBT.md` DEBT-012).

### Consequences
- Reasoning about "what owns this object" requires checking the object type, not just applying the
  schema convention uniformly.
- A new load procedure can be added to `dbo` (following the only precedent that exists) or to a
  layer-aligned schema (following the tables/views convention) — both are locally consistent with
  *something*, which makes this an easy inconsistency to propagate further.

### Review notes
Open: confirm with the team whether `dbo` for procedures is the intended convention or should be
migrated to a layer-aligned schema (e.g. `stg.usp_Load...` or a dedicated `etl` schema).

---

## ADR-002: Reporting layer is views-only; no physical mart tables

- **Date**: 2026-09-30
- **Status**: Accepted (observed structure)

### Decision
The "mart" layer is implemented entirely as `rpt.*` views selecting directly from `fact`/`dim`
tables. There are no physical mart or aggregate tables anywhere in the schema.

### Context
`Views/rpt.vwExecutiveSummary.sql`, `Views/rpt.vwFinanceExtract.sql`, and
`Views/rpt.vwOrderDetail.sql` are the only reporting-layer objects in the repo. No `mart.*` or
`dw.*` table exists under `Tables/`. Each view queries `fact.FactSales` joined to the relevant
dimension tables live, with no intermediate materialization or pre-aggregation.

### Consequences
- A new reporting requirement should land as a new or extended `rpt.*` view by default; adding a
  physical mart table is a deliberate escalation, not the existing pattern.
- Query cost for reporting is paid at read time on every view execution — there is no
  materialization to amortize repeated reads. At the current object count (one fact, four
  dimensions) this is not evidenced as a problem, but it is worth re-checking if the warehouse
  grows.

### Review notes
None open. Re-evaluate if a reporting view's query cost becomes a measured problem.

---

## ADR-003: Fact/dimension relationships are convention-only; no FOREIGN KEY constraints

- **Date**: 2026-09-30
- **Status**: Accepted (observed gap, not a deliberate trade-off recorded anywhere)

### Decision
Referential integrity between `fact.FactSales` and its dimensions (`dim.DimCustomer`,
`dim.DimProduct`, `dim.DimDate`), and between `dim.DimCustomer` and `dim.DimRegion`, is expressed
only through column naming (`CustomerKey`, `ProductKey`, `OrderDateKey`, `RegionKey`) — no
`FOREIGN KEY` constraint exists anywhere in the schema.

### Context
Every file under `Tables/` was read in full; none contains the `FOREIGN KEY` keyword. There is also
no `UNIQUE` constraint backing `dim.DimCustomer.CustomerId` or `dim.DimProduct.ProductId` (the
natural/business keys), so `usp_LoadDimCustomer`'s `MERGE ... ON target.CustomerId =
source.CustomerId` relies entirely on application logic — not the engine — to prevent duplicate
business-key rows (see `TECH_DEBT.md` DEBT-010).

### Consequences
- The engine cannot reject an orphaned fact row (a `CustomerKey`/`ProductKey`/`OrderDateKey` with no
  matching dimension row) or a duplicate business key in a dimension — both are possible today.
- Anyone adding a new fact or dimension should not assume FK-backed integrity checks exist; join
  correctness must be verified by inspection or by the future `docs/warehouse-map.md`.

### Review notes
Open: decide whether to add `FOREIGN KEY`/`UNIQUE` constraints (tracked as `TECH_DEBT.md` DEBT-010)
or to formally accept convention-only integrity as the warehouse's design.
