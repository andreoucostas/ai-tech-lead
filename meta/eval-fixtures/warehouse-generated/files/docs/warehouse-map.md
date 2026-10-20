<!-- warehouse-map full pass: 2026-10-20T02:28Z -->

# Warehouse Map

Grep-based structure detection from the repository's SQL, not execution. Confirm against a load run or the team before relying on it for a destructive change.

## 1. Table inventory

| entity | layer | classification | grain | primary key | natural/business key |
|--------|-------|----------------|-------|-------------|----------------------|
| `stg.StgSalesOrder` | stg | staging | one row per order record; no uniqueness declared on `SalesId` | none | `SalesId` |
| `dim.DimCustomer` | dim | dimension, SCD2-shaped | one row per customer version | `CustomerKey` | `CustomerId` (no unique constraint) |
| `dim.DimProduct` | dim | dimension | one row per product | `ProductKey` | `ProductId` (no unique constraint) |
| `dim.DimRegion` | dim | dimension | one row per region | `RegionKey` | none (only `RegionName`) |
| `dim.DimDate` | dim | dimension | one row per calendar date | `DateKey` | `CalendarDate` (no unique constraint) |
| `fact.FactSales` | fact | transaction fact | one row per `SalesId` | `SalesKey` | `SalesKey` is a copy of `SalesId` (degenerate key) |
| `ctl.LoadRun` | ctl | control | one row per load run | `LoadRunId` | none |
| `rpt.vwExecutiveSummary`, `rpt.vwFinanceExtract`, `rpt.vwOrderDetail` | rpt | views | see section 4 | n/a | n/a |

## 2. Relationship edge list

No `FOREIGN KEY` constraints are declared (consistent with AGENTS.md > Conventions).

| fact | fk column | → dimension | role | version resolution | evidence | confidence |
|------|-----------|-------------|------|--------------------|----------|------------|
| FactSales | `CustomerKey` | DimCustomer | customer | **Pinned at load**, to the version current at load time, not as of the order date | `usp_LoadFactSales.sql:5` joins `CustomerId AND IsCurrent=1`; `vwFinanceExtract` joins on `CustomerKey` | Load-derived, In use |
| FactSales | `ProductKey` | DimProduct | product | n/a (no history columns) | `usp_LoadFactSales.sql:6`; `vwExecutiveSummary` | Load-derived, In use |
| FactSales | `OrderDateKey` | DimDate | order date | n/a | `usp_LoadFactSales.sql:7`; `vwFinanceExtract` | Load-derived, In use |
| FactSales (via DimCustomer) | `DimCustomer.RegionKey` | DimRegion | customer's region | follows the customer version | `vwFinanceExtract` | In use; no region key on the fact |
| FactSales | `LoadRunId` | ctl.LoadRun | load run | UNRESOLVED | copied from `stg.BatchId`; nothing links it to `ctl.LoadRun` | **UNRESOLVED** (naming only) |

`FactSales.RegionName`, `CategoryName` and `SegmentName` are copies of dimension attributes that no load writes (finding F1); they are not edges.

## 3. Loading

| entity | load proc/pipeline | orchestrated by | rerun protection | SCD | partitioning |
|--------|--------------------|-----------------|------------------|-----|--------------|
| DimRegion | `usp_LoadDimRegion` | none in repo | none; inserts `(-1,'Unknown')` per staging row, PK fails on the second | none (Type 1) | none found |
| DimCustomer | `usp_LoadDimCustomer` | none in repo | none; MERGE matches on `CustomerId`, only `WHEN NOT MATCHED` | SCD2 columns, no close-out | none found |
| DimProduct | no loader in repo | n/a | n/a | none | none found |
| DimDate | no loader in repo | n/a | n/a | none | none found |
| FactSales | `usp_LoadFactSales` | none in repo | none, apart from the `SalesKey` PK | n/a; no reversal, correction or late-arrival handling | none found |

Load order implied by the joins (not orchestrated): Region → Customer → Product/Date (no loader) → Fact.

## 4. Dimensional semantics

- **Fact type:** `FactSales` is a transaction fact. `NetAmount` is fully additive.
- **Role-playing dimensions:** none; `DimDate` is reached only as order date.
- **Conformed dimensions:** one fact only, so conformance cannot be assessed.
- **Degenerate dimension:** `SalesKey` (= `SalesId`).
- **Views:**
  - `vwExecutiveSummary` sums `NetAmount` by `DimProduct.CategoryName`.
  - `vwFinanceExtract` returns fact rows joined to customer, region and date.
  - `vwOrderDetail` reads `FactSales` alone.

## 5. Coverage

Inspected in full: 7 tables, 3 procedures and 3 views (all 15 SQL files under `Tables/`, `StoredProcedures/`, `Views/`), plus `warehouse.sqlproj`. Not readable from the repo: whatever populates `stg.StgSalesOrder`, `DimProduct` and `DimDate`; any orchestration, `.dtsx`, dynamic SQL or live catalog. One edge is `UNRESOLVED`: `FactSales.LoadRunId → ctl.LoadRun`.

## 6. Findings

| finding | entity | evidence | finding confidence | severity if confirmed | consequence | remediation |
|---------|--------|----------|--------------------|-----------------------|-------------|-------------|
| F1: denormalised attribute columns never populated | `fact.FactSales` | `fact.FactSales.sql:7-9`; insert list at `usp_LoadFactSales.sql:2` omits them | Confirmed | significant | Selecting them from the fact returns `NULL`s with no error | Reach attributes through the dimensions; dropping the columns is a schema change and needs impact analysis first |
| F2: hardcoded `CustomerKey = -1` / `RegionKey = -1` | `dim.DimCustomer` | `usp_LoadDimCustomer.sql:1` | Confirmed | blocking | A second new customer violates the PK; every customer sits in the Unknown region | Generate real surrogate keys and resolve the region |
| F3: SCD2 contradicted by the load | `dim.DimCustomer` | MERGE has only `WHEN NOT MATCHED` and matches on `CustomerId` without `IsCurrent` | Confirmed | significant | No history is produced; `EffectiveTo` is never set | Add close-out and insert path (DEBT-001) |
| F4: no rerun protection, no real region data | `dim.DimRegion` | `usp_LoadDimRegion.sql:1` | Confirmed | significant | Fails on the second staging row or a rerun | See DEBT-002 |
| F5: no rerun protection | `fact.FactSales` | `usp_LoadFactSales.sql:2-7` | Confirmed | significant | A rerun fails on the PK rather than double-loading; that guard is accidental | `BatchId`/watermark anti-join; `ctl.LoadRun` exists but is unread |
| F6: inner joins drop unmatched rows silently | `fact.FactSales` | `usp_LoadFactSales.sql:5-7`; DimProduct and DimDate have no loader | Likely | blocking | Revenue understated with no error or reject count | Unknown-member fallback or staging-vs-fact reconciliation |
| F7: joined business keys not declared unique | `DimProduct`, `DimDate`, `DimCustomer` | no unique constraint on `ProductId`, `CalendarDate`, `CustomerId` | Possible | blocking | Duplicate matches would multiply fact rows and double-count `NetAmount` | Confirm uniqueness with the team |
| F8: customer attributes reflect the version current at load | `fact.FactSales` | `usp_LoadFactSales.sql:5` | Likely | advisory | Order-date history cannot be reproduced once SCD2 works | Record the intent in an ADR |

## 7. Querying this warehouse

Rules for reading the warehouse, not loading it. They address the ways a report goes wrong quietly, producing a number rather than an error.

1. **Start at the fact and state its grain** in one sentence before writing any SQL. `FactSales` has one row per `SalesId`.
2. **Reach an attribute by following a fact key to the dimension that owns it.** Never read `FactSales.RegionName`, `CategoryName` or `SegmentName`: they are declared but never populated (F1) and return `NULL`s, not an error.
3. **Use an existing reporting view's join path as a usage lead before inventing one.** `vwExecutiveSummary` and `vwFinanceExtract` show the paths in use, not that the result is correct. Freeze the report's grain, temporal predicate, expected result and tolerances before claiming correctness. If two views disagree, record the conflict in the edge list.
4. **Treat a same-named column on an already-joined table as suspect** until you know which table populates it. `FactSales.CategoryName` is not `DimProduct.CategoryName`.
5. **Replicating a report from another warehouse: write the source-column → target-concept mapping before any SQL.** Name what is unresolved and ask; do not substitute the nearest-looking column.
6. **Add an effective-date predicate only when the key does not already identify one version.**
   - **`Pinned at load`**: `FactSales.CustomerKey → DimCustomer`. The load chose the version and stamped its surrogate key. Adding `EffectiveFrom`/`EffectiveTo`/`IsCurrent` to that join silently drops every fact pointing at a superseded row.
   - **`Deferred to query`**: reaching `DimCustomer` from a business key (`CustomerId`). The temporal predicate is required; copy the as-of rule from a reporting view rather than inventing one.
   - **`UNRESOLVED`**: `FactSales.LoadRunId → ctl.LoadRun`. Do not choose; copy an existing view's join or ask.

Two named path hazards:

- **Fan trap**: joining a chained one-to-many below the fact multiplies fact rows and double-counts the measure. `ProductId`, `CalendarDate` and `CustomerId` are not declared unique (F7), so a join on them could fan out. Aggregate at the fact's own grain, or aggregate the many-side separately first.
- **Chasm trap**: joining two facts directly through a shared dimension inflates both measures. Only one fact exists today. If another is added, aggregate each to the shared grain independently, then join the aggregates.

If the map marks an edge `UNRESOLVED` or `CONFLICTING`, treat it as a question to ask, not a gap to fill with the most plausible-looking column.
