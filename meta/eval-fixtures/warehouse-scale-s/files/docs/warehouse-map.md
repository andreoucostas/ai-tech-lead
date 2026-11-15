<!-- warehouse-map full pass: 2026-11-15T00:00Z -->
# Warehouse map

Note: the applicability gate `scripts/warehouse-map-check.ps1` was not run for this pass (it needed approval). The time in the first line is a date only; the hour is not meaningful.

## 1. Table inventory

| entity | layer | classification | grain | primary key | natural/business key |
|--------|-------|----------------|-------|-------------|----------------------|
| `stg.StgSalesOrder` | staging | staging | one row per `SalesId` (no PK or uniqueness declared) | none | `SalesId` |
| `dim.DimCustomer` | core | dimension (SCD2 columns) | one row per customer version (intended) | `CustomerKey` | `CustomerId` |
| `dim.DimRegion` | core | dimension | one row per region | `RegionKey` | none (`RegionName` only) |
| `dim.DimProduct` | core | dimension | one row per product | `ProductKey` | `ProductId` (not declared unique) |
| `dim.DimDate` | core | dimension | one row per date | `DateKey` | `CalendarDate` (not declared unique) |
| `fact.FactSales` | core | transaction fact | one row per `SalesKey` (= staging `SalesId`) | `SalesKey` | none |
| `ctl.LoadRun` | control | control | one row per run | `LoadRunId` | none |

Consumption: `rpt.vwExecutiveSummary`, `rpt.vwFinanceExtract`, `rpt.vwOrderDetail`.

## 2. Relationship edge list

No `FOREIGN KEY` constraints are declared in the inspected source.

| fact | fk column | → dimension | role | version resolution | evidence | confidence |
|------|-----------|-------------|------|--------------------|----------|------------|
| FactSales | `CustomerKey` | DimCustomer | customer | Pinned at load | `usp_LoadFactSales` joins on `CustomerId` with `IsCurrent = 1`; `vwFinanceExtract` joins on `CustomerKey` | Load-derived; In use |
| FactSales | `ProductKey` | DimProduct | product | Pinned at load | load joins on `ProductId`; `vwExecutiveSummary` joins on `ProductKey` | Load-derived; In use |
| FactSales | `OrderDateKey` | DimDate | order date | Pinned at load | load joins on `CalendarDate`; `vwFinanceExtract` joins on `DateKey` | Load-derived; In use |
| FactSales | none (via `DimCustomer.RegionKey`) | DimRegion | customer region | not applicable | `vwFinanceExtract` joins `DimRegion` on `c.RegionKey` | In use |
| FactSales | `RegionName`, `CategoryName`, `SegmentName` | none | none | UNRESOLVED | columns are never written by any load; naming only | UNRESOLVED |
| FactSales | `LoadRunId` | `ctl.LoadRun` | none | UNRESOLVED | filled from `stg.BatchId`; nothing links it to `ctl.LoadRun` | UNRESOLVED |

## 3. Loading

| entity | load proc/pipeline | orchestrated by | rerun protection | SCD | partitioning |
|--------|--------------------|-----------------|------------------|-----|--------------|
| DimCustomer | `dbo.usp_LoadDimCustomer` | `Jobs/NightlyCore.sql` step 1 | none | declared SCD2, actually insert-only | none |
| DimRegion | `dbo.usp_LoadDimRegion` | step 2 | none | Type 1 | none |
| FactSales | `dbo.usp_LoadFactSales` | step 3 | none | not applicable | none |
| DimProduct | none in repo | none | unknown | unknown | none |
| DimDate | none in repo | none | unknown | unknown | none |

Load order is dimensions then fact, and exists only in the job's step order.

## 4. Dimensional semantics

- **Fact type:** `FactSales` is a transaction fact. `NetAmount` is fully additive.
- **Degenerate dimension:** `SalesKey` (the staging `SalesId`).
- **Role-playing and conformed dimensions:** none. Only one fact exists.
- **Feeds:**
  - `vwExecutiveSummary` ← FactSales, DimProduct
  - `vwFinanceExtract` ← FactSales, DimCustomer, DimRegion, DimDate
  - `vwOrderDetail` ← FactSales only

## 5. Coverage

- Inspected: every `.sql` file in the repo (7 tables, 3 load procs, 3 views, 1 job), in schemas `stg`, `dim`, `fact`, `ctl`, `rpt` and `dbo`.
- Not read: the `stg.StgSalesOrder` loader and the DimProduct and DimDate loaders (not in the repo). There are no `.dtsx` files and no dynamic SQL.
- `UNRESOLVED` edges: FactSales `RegionName`, `CategoryName`, `SegmentName` and `LoadRunId`.
- Modelling-health deepening was not run.
- Findings are scoped to the inspected source, not to a live database.

## 6. Findings

| finding | entity | evidence | finding confidence | severity if confirmed | consequence | remediation |
|---------|--------|----------|--------------------|-----------------------|-------------|-------------|
| Fact columns never populated | `FactSales.RegionName`, `CategoryName`, `SegmentName` | `usp_LoadFactSales` `INSERT` column list omits them | Confirmed | blocking | A report reading them gets NULLs | Read attributes via the dimension, as `vwExecutiveSummary` does. Dropping the columns is a schema change and needs impact analysis first. |
| Every customer gets `CustomerKey = -1` and `RegionKey = -1` | `usp_LoadDimCustomer` | hardcoded `VALUES (-1, …, -1, 'Unknown', …)`; `CustomerKey` is the PK | Confirmed | blocking | A second distinct new customer violates the PK, and all facts resolve to one placeholder customer | Generate real surrogate keys and resolve `RegionKey` |
| DimRegion only ever `(-1, 'Unknown')` | `usp_LoadDimRegion` | `SELECT DISTINCT -1, 'Unknown'` | Confirmed | blocking | `vwFinanceExtract` can only report region "Unknown", and a rerun violates the PK | Load regions from a real source |
| No rerun protection | all three loads | no watermark, no delete or merge on the fact insert, `ctl.LoadRun` unused | Confirmed | blocking | A rerun fails on the PK or double-loads | Define idempotency (see `add-warehouse-load`) |
| SCD2 declared but not implemented | DimCustomer | `WHEN NOT MATCHED` only: no update, no expire | Confirmed | significant | `EffectiveFrom`/`EffectiveTo`/`IsCurrent` carry no history | Do not rely on history until the load versions rows |
| Fact load joins on natural keys not declared unique | DimProduct `ProductId`, DimDate `CalendarDate` | join predicates in `usp_LoadFactSales` | Possible | blocking if duplicates exist | Duplicate dimension rows would multiply fact rows | Confirm uniqueness in the (out-of-repo) loaders |
| Inner joins drop unmatched staging rows silently | `usp_LoadFactSales` | `JOIN` throughout, no reject path | Likely | significant | Staging rows with no dimension match vanish without error | Add an orphan check or reject path |
| No load for DimProduct or DimDate in the repo | DimProduct, DimDate | absent from `StoredProcedures/` and the job | Confirmed | significant | If not populated elsewhere, the fact load inserts nothing | Confirm the population path with the team |

## 7. Querying this warehouse

Rules for reading the warehouse, not loading it. They address the ways a report goes wrong quietly, producing a number rather than an error.

1. **Start at the fact and state its grain** in one sentence before writing any SQL. For `FactSales` it is one row per `SalesKey` (= staging `SalesId`).
2. **Reach an attribute by following a fact key to the dimension that owns it.** Never read it off a column that merely sits on a table already in the join. `FactSales.RegionName`, `CategoryName` and `SegmentName` are declared but never populated, so they return NULLs, not an error. Take category from `DimProduct`, segment from `DimCustomer`, and region via `DimCustomer.RegionKey` → `DimRegion`.
3. **Use an existing reporting view's join path as a usage lead before inventing one.** It shows the path this warehouse uses, not that the result is correct. Freeze the report's applicable grain, temporal predicate, expected result and tolerances before claiming correctness. If two views disagree, record that conflict in the edge list rather than picking one.
4. **Treat a same-named column on an already-joined table as suspect** until you know which table populates it. Same name is not same meaning, and it is not evidence of a relationship.
5. **Replicating a report from another warehouse: write the source-column → target-concept mapping before any SQL.** Same-named columns across two warehouses are the trap. Name what is unresolved and ask. Do not substitute the nearest-looking column.
6. **Add an effective-date predicate only when the key does not already identify one version.** The discriminator is a property of the edge, recorded as `version resolution` in section 2:
   - **`Pinned at load`**: the load found the dimension version that applied and stamped its surrogate key onto the fact. Adding `EffectiveFrom`/`EffectiveTo`/`IsCurrent` to that join **silently drops every fact pointing at a superseded row**, giving a low row count rather than an error. All three `FactSales` → dimension edges (`CustomerKey`, `ProductKey`, `OrderDateKey`) are Pinned at load. `DimCustomer` does not version today, but do not add `IsCurrent` to the `CustomerKey` join regardless.
   - **`Deferred to query`**: the key does not pick a version on its own (a natural or business key, a durable key shared by every version row, or a run/version/snapshot register where several rows are live). The temporal predicate is **required**. Use the warehouse's own as-of rule, copied from a reporting view rather than invented. No edge in this warehouse is currently in this state.
   - **`UNRESOLVED`**: do not choose. Copy an existing view's join for that edge, or ask. This applies to `RegionName`, `CategoryName`, `SegmentName` and `LoadRunId` on `FactSales`.

Two named path hazards:

- **Fan trap**: joining a chained one-to-many below the fact multiplies the fact rows and double-counts the measure. Aggregate at the fact's own grain, or aggregate the many-side separately before joining. `DimProduct.ProductId` and `DimDate.CalendarDate` are not declared unique, so joining on them (as the load does) risks this.
- **Chasm trap**: joining two facts directly through a shared dimension multiplies their rows within each shared key group, inflating both measures. Two facts sharing a conformed dimension is legitimate drill-across: aggregate each fact to the shared grain independently first, then join the two aggregates on the shared keys. Only one fact exists today.

If the map marks an edge `UNRESOLVED` or `CONFLICTING`, treat it as a question to ask, not a gap to fill with the most plausible-looking column.
