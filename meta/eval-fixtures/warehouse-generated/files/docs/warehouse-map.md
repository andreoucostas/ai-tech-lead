# Warehouse Map

> Written by `/map-warehouse` on 2026-10-01. Results are grep-based structure detection, not
> execution — confirm against a load run or the team before relying on them for a destructive
> change. Match `AGENTS.md > Conventions`; if this map and the code disagree, the code wins —
> re-run `/map-warehouse` rather than trusting this file further.

## 1. Table inventory

| entity | layer | classification | grain | primary key | natural/business key |
|---|---|---|---|---|---|
| `stg.StgSalesOrder` | staging | staging | one row per incoming sales order per batch | *(none declared)* | — |
| `dim.DimCustomer` | warehouse core | dimension | one row per customer version | `CustomerKey` | `CustomerId` |
| `dim.DimProduct` | warehouse core | dimension | one row per product | `ProductKey` | `ProductId` |
| `dim.DimRegion` | warehouse core | dimension | one row per region | `RegionKey` | *(none declared — only `RegionName`, no business-key column)* |
| `dim.DimDate` | warehouse core | dimension | one row per calendar date | `DateKey` | `CalendarDate` |
| `fact.FactSales` | warehouse core | fact | **one row per source sales order** (`SalesKey` = `stg.StgSalesOrder.SalesId`, no aggregation) | `SalesKey` | — |
| `ctl.LoadRun` | control | control | one row per load-run instance (intended) | `LoadRunId` | — |
| `rpt.vwExecutiveSummary` | reporting | mart/view | one row per `CategoryName` (aggregated) | — | — |
| `rpt.vwFinanceExtract` | reporting | mart/view | one row per `fact.FactSales` row (pass-through, no aggregation) | — | — |
| `rpt.vwOrderDetail` | reporting | mart/view | one row per `fact.FactSales` row (raw projection) | — | — |

## 2. Relationship edge list

| fact | fk column | → dimension | role | version resolution | evidence | confidence |
|---|---|---|---|---|---|---|
| `fact.FactSales` | `CustomerKey` | `dim.DimCustomer` | customer | **Pinned at load** — the load joins on `c.IsCurrent = 1` before stamping the key | `StoredProcedures/usp_LoadFactSales.sql:5`; `Views/rpt.vwFinanceExtract.sql:4` (joins on `CustomerKey`) | Load-derived + In use |
| `fact.FactSales` | `ProductKey` | `dim.DimProduct` | product | Not applicable — `DimProduct` has no SCD columns, always exactly one version | `StoredProcedures/usp_LoadFactSales.sql:6`; `Views/rpt.vwExecutiveSummary.sql:1` | Load-derived + In use |
| `fact.FactSales` | `OrderDateKey` | `dim.DimDate` | order date | Not applicable — `DimDate` is static | `StoredProcedures/usp_LoadFactSales.sql:7`; `Views/rpt.vwFinanceExtract.sql:5` | Load-derived + In use |
| `dim.DimCustomer` | `RegionKey` | `dim.DimRegion` | customer's region (**snowflake** — reached through `DimCustomer`; `fact.FactSales` has no direct `RegionKey`) | Not applicable — `DimRegion` is static | `Views/rpt.vwFinanceExtract.sql:5` (`JOIN dim.DimRegion r ON r.RegionKey = c.RegionKey`); `StoredProcedures/usp_LoadDimCustomer.sql:1` (hardcodes `-1`) | In use + Load-derived |
| `fact.FactSales` | `LoadRunId` | `ctl.LoadRun` (**naming-implied only**) | — | **CONFLICTING** | `Tables/ctl.LoadRun.sql` (PK named `LoadRunId`) **vs.** `StoredProcedures/usp_LoadFactSales.sql:3` (actually assigns `s.BatchId` from `stg.StgSalesOrder`, never any `ctl.LoadRun` value) | CONFLICTING |

**Not an edge** (read-side trap, rule 4 below): `fact.FactSales.RegionName`/`CategoryName`/`SegmentName` are plain text columns that *share a name* with `dim.DimRegion.RegionName`/`dim.DimProduct.CategoryName`/`dim.DimCustomer.SegmentName` — but they are never populated (`usp_LoadFactSales`'s INSERT list omits them) and no view reads them. Same name, no relationship, no data.

## 3. Loading

| entity | load proc/pipeline | orchestrated by | rerun protection | SCD | partitioning |
|---|---|---|---|---|---|
| `dim.DimCustomer` | `usp_LoadDimCustomer` | none (no `EXEC` chain exists) | **none** — `WHEN NOT MATCHED` only, hardcoded `CustomerKey = -1` (PK collision on 2nd new customer) | Declared Type 2, **not implemented** (no `WHEN MATCHED`) | none |
| `dim.DimRegion` | `usp_LoadDimRegion` | none | **none** — unconditional `INSERT`, hardcoded `RegionKey = -1` (PK violation on any rerun) | Type 1 (no history columns) | none |
| `dim.DimProduct` | *(no load procedure exists)* | — | — | — | — |
| `dim.DimDate` | *(no load procedure exists)* | — | — | — | — |
| `fact.FactSales` | `usp_LoadFactSales` | none — implied only by its own `INNER JOIN`s to the three dimensions | **none** — unconditional `INSERT`, no watermark/batch filter | n/a | none |
| `ctl.LoadRun` | *(no load procedure writes to it)* | — | — | — | — |

Required load order (**implied, not enforced**): `DimCustomer`, `DimRegion`, `DimProduct`, `DimDate` all before `FactSales` — nothing in the repo enforces this.

## 4. Dimensional semantics

- **Fact type**: `fact.FactSales` is a **transaction fact** (one row per sales-order event).
- **Measure additivity**: `NetAmount` — **fully additive** (confirmed by `SUM()` usage in `rpt.vwExecutiveSummary`).
- **Role-playing dimensions**: none — `DimDate` is reached by only one role (`OrderDateKey`).
- **Conformed dimensions**: not assessable — only one fact table exists in this repo.
- **Degenerate dimensions**: none beyond `SalesKey` itself (already the PK).
- **Views/marts fed**: `fact.FactSales` → all three `rpt.*` views; `dim.DimProduct` → `vwExecutiveSummary`; `dim.DimCustomer`+`dim.DimRegion`+`dim.DimDate` → `vwFinanceExtract`; `vwOrderDetail` reads only `fact.FactSales` (raw keys, no attribute names).

## 5. Coverage

**Semantically inspected (13 of 13 SQL files + `warehouse.sqlproj`, full read, no sampling)**: every file in `Tables/`, `StoredProcedures/`, `Views/`. There is no other database/schema scope in this repo — no second `.sqlproj`, no external schema files.

**Not evidenced / unresolved**: no orchestration layer exists to inspect (no scheduler, SSIS, ADF, dbt DAG); actual runtime behavior (row counts, whether `DimProduct`/`DimDate` are populated by *something* outside this repo, whether `ctl.LoadRun` is written by an external process) — this is grep-based structure detection, not execution. **1 fact carries a CONFLICTING edge**: `fact.FactSales.LoadRunId` ↔ `ctl.LoadRun` (edge-list row 5 above).

## 6. Findings

| finding | entity | evidence | finding confidence | severity if confirmed | consequence | remediation |
|---|---|---|---|---|---|---|
| Fact load depends on two dimensions with no load procedure (`DimProduct`, `DimDate`) | `fact.FactSales` | `StoredProcedures/usp_LoadFactSales.sql:6-7` (`INNER JOIN`); absence of `usp_LoadDimProduct`/`usp_LoadDimDate` | **Confirmed** | **blocking** | `INNER JOIN`s against unloaded dimensions silently return zero/incomplete fact rows, not an error | Add `usp_LoadDimProduct`/`usp_LoadDimDate`, or document an external seeding process if one genuinely exists *(= TECH_DEBT.md DEBT-001)* |
| `usp_LoadDimCustomer` never implements its declared SCD2 strategy; hardcodes surrogate keys | `dim.DimCustomer` | `StoredProcedures/usp_LoadDimCustomer.sql:1` (`WHEN NOT MATCHED` only, `VALUES(-1, ...)`) | **Confirmed** | **blocking** | `CustomerKey` PK always `-1` → PK violation on 2nd new customer; no version history ever created | Real `MERGE` with generated surrogate key + `WHEN MATCHED` branch closing the prior row *(= DEBT-002)* |
| `usp_LoadDimRegion` loads no real region data; not re-runnable | `dim.DimRegion` | `StoredProcedures/usp_LoadDimRegion.sql:1`; `Tables/stg.StgSalesOrder.sql` (no region column); `Tables/dim.DimRegion.sql` (no natural key) | **Confirmed** | **blocking** | `RegionKey` PK always `-1` → PK violation on any rerun; no real region ever represented | Add natural key column, source real region data, rewrite as keyed upsert *(= DEBT-003)* |
| `ctl.LoadRun` control/watermark table is fully orphaned | `ctl.LoadRun` | `Tables/ctl.LoadRun.sql`; absence across `StoredProcedures/*.sql`; `usp_LoadFactSales.sql:3` sources `LoadRunId` from `s.BatchId` instead | **Confirmed** | **significant** | No working rerun/idempotency control exists; the fact column named `LoadRunId` does not trace to any `ctl.LoadRun` row — misleading to a report author | Wire `ctl.LoadRun` into each load, or remove it *(= DEBT-004)* |
| No load has rerun/idempotency protection | `fact.FactSales`, `dim.DimRegion` | `usp_LoadFactSales.sql:1-7`, `usp_LoadDimRegion.sql:1` (unconditional `INSERT`) | **Confirmed** | **blocking** | A rerun against unchanged staging fails on PK violation; nothing distinguishes an already-loaded batch from a new one | Batch-id dedup or `MERGE` keyed on business key, tied to `ctl.LoadRun` once wired in *(= DEBT-005)* |
| `fact.FactSales` denormalized columns are dead schema | `fact.FactSales` | `Tables/fact.FactSales.sql:7-9`; `usp_LoadFactSales.sql:2-3` (omitted from INSERT); both `rpt.*` views re-derive via joins instead | **Confirmed** | **significant** | Always `NULL`; a future direct reader gets silent `NULL`, not an error | Populate in the load or drop the columns *(= DEBT-008)* |
| No orchestrator enforces dimension-before-fact ordering | `fact.FactSales` + 3 dimensions | `StoredProcedures/*.sql` (no proc `EXEC`s another) | **Confirmed** | **significant** | Sequencing depends entirely on the external caller; wrong order yields fewer/no rows silently | Add an orchestrator proc (e.g. `usp_LoadWarehouse`) *(= DEBT-007)* |
| `rpt.vwFinanceExtract` omits the `IsCurrent` filter `usp_LoadFactSales` applies | `dim.DimCustomer` (via view) | `Views/rpt.vwFinanceExtract.sql:4` vs. `usp_LoadFactSales.sql:5` | **Confirmed** (convention inconsistency) | **advisory today** — becomes **blocking** if the `DimCustomer` SCD2 finding above is ever fixed without this | Latent double-count risk once/if `DimCustomer` SCD2 actually starts versioning | Add `AND c.IsCurrent = 1` now, ahead of that fix *(= DEBT-010)* |

All seven findings above were already recorded during `/bootstrap` as `TECH_DEBT.md` DEBT-001 through DEBT-005, DEBT-008, and DEBT-010 — this map doesn't re-propose them as new, just situates them structurally.

## 7. Querying this warehouse

> Rules for reading the warehouse, not loading it. They address the ways a report goes wrong
> quietly — producing a number, not an error.

1. **Start at the fact and state its grain** in one sentence before writing any SQL: `fact.FactSales` = one row per source sales order. If a query's result doesn't match that grain, something upstream multiplied or collapsed rows.
2. **Reach an attribute by following a fact key to the dimension that owns it.** Never read it off a column that merely happens to sit on a table already in the join. `CategoryName` comes from `dim.DimProduct` via `ProductKey` — **never** from `fact.FactSales.CategoryName`, which is declared but always `NULL`. Same for `RegionName` (via `DimCustomer` → `DimRegion`, two hops) and `SegmentName` (via `DimCustomer`). A column that is declared in DDL but never populated by any load looks identical to a real one in a `SELECT` list — and returns `NULL`s, not an error.
3. **Use an existing reporting view's join path as a usage lead before inventing one.** `rpt.vwFinanceExtract` is the only evidenced path from `fact.FactSales` to region (`Fact.CustomerKey → DimCustomer.RegionKey → DimRegion.RegionName`) — copy that path, don't invent a shortcut through the fact's dead `RegionName` column. It shows the path this warehouse uses, not that the result is correct.
4. **Treat a same-named column on an already-joined table as suspect** until you know which table populates it. `fact.FactSales.RegionName`/`CategoryName`/`SegmentName` share names with real dimension attributes but are not populated by any load in this repo. Same name is not same meaning, and it is not evidence of a relationship.
5. **Replicating a report from another warehouse: write the source-column → target-concept mapping before any SQL.** Not applicable here today — no second warehouse or external source is evidenced in this repo.
6. **Add an effective-date predicate only when the key does not already identify one version.** The `fact.FactSales → DimCustomer` edge is **Pinned at load** (`usp_LoadFactSales` already filters `IsCurrent = 1` before stamping `CustomerKey`), so a query joining `fact.FactSales` to `dim.DimCustomer` on `CustomerKey` needs **no** extra `IsCurrent` filter — the version is already chosen. The one exception today is `rpt.vwFinanceExtract` itself, which is missing that filter on its own *independent* join to `DimCustomer` (Finding row 7 above) — until that's fixed, treat `vwFinanceExtract`'s customer attributes as unguarded if `DimCustomer` ever gains a second version.

Two named path hazards:

- **Fan trap** — not currently exercisable: `fact.FactSales` has no one-to-many dimension below it in this repo.
- **Chasm trap** — not currently exercisable: only one fact table (`fact.FactSales`) exists in this repo, so no shared-dimension drill-across path exists yet.

If this map marks an edge `UNRESOLVED` or `CONFLICTING` (see the `LoadRunId` row in section 2), that is the map telling you it does not know — treat it as a question to ask, not a gap to fill with the most plausible-looking column.
