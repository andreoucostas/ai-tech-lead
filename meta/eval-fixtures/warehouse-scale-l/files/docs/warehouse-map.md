<!-- warehouse-map full pass: none -->
# Warehouse Map

Scoped pass of 2026-11-15, grep/read-based (no execution, no live catalog). Mapped in full: the Sales core (`Jobs/NightlyCore.sql`) and the PayrollOverdraft subject. All other subjects are inventory-only.

Repo size: 2,161 tables (646 fact, 213 of them `*Snapshot`), 1,532 procedures, 874 views, 432 job scripts. No `FOREIGN KEY`, `REFERENCES` or `UNIQUE` in `Tables/*.sql`.

## 1. Table inventory

### Staging (`stg`)

| entity | layer | classification | grain | primary key | natural/business key |
|--------|-------|----------------|-------|-------------|----------------------|
| stg.StgSalesOrder | stg | staging | one row per sales order id per batch | none | SalesId |
| stg.StgPayrollOverdraftSnapshot | stg | staging | not stated | none | SourceId |
| stg.StgPayrollOverdraftEvent | stg | staging | not stated | none | SourceId |

### Dimensions (`dim`)

| entity | layer | classification | grain | primary key | natural/business key |
|--------|-------|----------------|-------|-------------|----------------------|
| dim.DimCustomer | dim | dimension (Type 2 columns, insert-only load) | one row per customer version | CustomerKey | CustomerId |
| dim.DimRegion | dim | dimension | one row per region | RegionKey | none (RegionName only) |
| dim.DimProduct | dim | dimension | one row per product | ProductKey | ProductId |
| dim.DimDate | dim | dimension | one row per calendar date | DateKey | CalendarDate |
| dim.DimPayrollOverdraft | dim | dimension (Type 2 columns, insert-only load) | one row per overdraft version | PayrollOverdraftKey | PayrollOverdraftId |
| dim.DimPayrollOverdraftSegment | dim | dimension (lookup) | one row per segment | PayrollOverdraftSegmentKey | PayrollOverdraftSegmentCode |
| dim.DimPayrollOverdraftStatus | dim | dimension (lookup) | one row per status | PayrollOverdraftStatusKey | PayrollOverdraftStatusCode |

### Facts and control

| entity | layer | classification | grain | primary key | natural/business key |
|--------|-------|----------------|-------|-------------|----------------------|
| fact.FactSales | fact | transaction fact | one row per sales order id | SalesKey | SalesKey (copied SalesId, degenerate) |
| fact.FactPayrollOverdraftSnapshot | fact | periodic snapshot (by name) | not stated by keys; probably one row per overdraft per business date | PayrollOverdraftSnapshotKey | SourceId (copied) |
| fact.FactPayrollOverdraftEvent | fact | transaction fact | one row per fee event | PayrollOverdraftEventKey | SourceId (copied) |
| ctl.LoadRun | ctl | control | one row per run | LoadRunId | LoadRunId |

Inventory-only (not read): all other `stg`, `dim`, `fact` tables. Names suggest a Snapshot fact plus an Event or Movement fact per subject, but this is unverified.

## 2. Relationship edge list

| fact | fk column | → dimension | role | version resolution | evidence | confidence |
|------|-----------|-------------|------|--------------------|----------|------------|
| fact.FactSales | CustomerKey | dim.DimCustomer | customer | Pinned at load (`IsCurrent = 1` chosen in the load) | `usp_LoadFactSales` join on CustomerId | Load-derived |
| fact.FactSales | ProductKey | dim.DimProduct | product | UNRESOLVED (no history columns, but no loader exists) | `usp_LoadFactSales` join on ProductId | Load-derived |
| fact.FactSales | OrderDateKey | dim.DimDate | order date | n/a | load join; `rpt.vwSalesLoadAudit` | In use |
| fact.FactSales | LoadRunId | ctl.LoadRun | run | n/a | `rpt.vwSalesByLoadRun` and three other views | In use |
| dim.DimCustomer | RegionKey | dim.DimRegion | customer region | UNRESOLVED | name only; load writes constant `-1` | UNRESOLVED |
| fact.FactPayrollOverdraftSnapshot | PayrollOverdraftKey | dim.DimPayrollOverdraft | overdraft | Pinned at load | `usp_LoadFactPayrollOverdraftSnapshot` | Load-derived |
| fact.FactPayrollOverdraftSnapshot | PayrollOverdraftSegmentKey | dim.DimPayrollOverdraftSegment | segment | n/a | load join | Load-derived |
| fact.FactPayrollOverdraftSnapshot | PayrollOverdraftStatusKey | dim.DimPayrollOverdraftStatus | status | n/a | load join | Load-derived |
| fact.FactPayrollOverdraftSnapshot | BusinessDateKey | dim.DimDate | business date | n/a | load join; `rpt.vwPayrollOverdraftByMonth` | In use |
| fact.FactPayrollOverdraftEvent | PayrollOverdraftKey | dim.DimPayrollOverdraft | overdraft | Pinned at load | `usp_LoadFactPayrollOverdraftEvent` | Load-derived |
| fact.FactPayrollOverdraftEvent | PayrollOverdraftSegmentKey | dim.DimPayrollOverdraftSegment | segment | n/a | load join | Load-derived |
| fact.FactPayrollOverdraftEvent | PayrollOverdraftStatusKey | dim.DimPayrollOverdraftStatus | status | n/a | load join | Load-derived |
| fact.FactPayrollOverdraftEvent | BusinessDateKey | dim.DimDate | business date | n/a | load join | Load-derived |
| fact.FactSales | RegionName, CategoryName, SegmentName | none (denormalised columns) | n/a | n/a | declared in DDL, written by no load | UNRESOLVED |

## 3. Loading

| entity | load proc/pipeline | orchestrated by | rerun protection | SCD | partitioning |
|--------|--------------------|-----------------|------------------|-----|--------------|
| dim.DimCustomer | `usp_LoadDimCustomer` | `Jobs/NightlyCore.sql` step 1 | `MERGE ... WHEN NOT MATCHED` on CustomerId | no update branch; `EffectiveTo`/`IsCurrent` never maintained | none found |
| dim.DimRegion | `usp_LoadDimRegion` | `NightlyCore` step 2 | none (inserts `-1, 'Unknown'` every run) | none | none found |
| dim.DimProduct | none in repo | none | n/a | n/a | n/a |
| dim.DimDate | none read | none read | unknown | n/a | none found |
| fact.FactSales | `usp_LoadFactSales` | `NightlyCore` step 3 | none; only the PK on SalesKey (a rerun errors) | n/a | none found |
| fact.FactSales (variants) | 21 other `usp_LoadFactSales*` | none | variants: `_Merge` key match, `Incremental` watermark, `_Restartable` delete-on-failure | n/a | none found |
| dim.DimPayrollOverdraft | `usp_LoadDimPayrollOverdraft` | `PayrollOverdraftDaily` step 1 | `MERGE` on id + `IsCurrent = 1` | insert-only | none found |
| Segment / Status dims | `usp_LoadDimPayrollOverdraftSegment` / `...Status` | steps 2-3 | `NOT EXISTS` on code | none | none found |
| fact.FactPayrollOverdraftSnapshot | `usp_LoadFactPayrollOverdraftSnapshot` | step 4 | none; only the PK | n/a | none found |
| fact.FactPayrollOverdraftEvent | `usp_LoadFactPayrollOverdraftEvent` | step 5 | none; only the PK | n/a | none found |

## 4. Dimensional semantics

- **Fact types:** FactSales is a transaction fact. FactPayrollOverdraftSnapshot is a periodic snapshot by name only. FactPayrollOverdraftEvent is a transaction fact.
- **Role-playing:** none observed in the mapped objects. Each fact has a single date key.
- **Conformed:** `dim.DimDate` is shared by both subjects and joined on `CalendarDate`, so it is conformed in practice. Cross-subject conformance of other dimensions was not checked.
- **Degenerate:** `SalesKey`, `SourceId`-derived keys.
- **Measure additivity:** `NetAmount` is additive across all dimensions. `FeeAmount` is additive (event fact). `SettledAmount` on a snapshot fact is unresolved; do not sum it across dates until its meaning is confirmed.
- **Views fed:**
  - FactSales feeds `rpt.vwSalesByLoadRun`, `vwSalesRunHistory`, `vwLoadRunSalesSummary` and `vwSalesLoadAudit`.
  - FactPayrollOverdraftSnapshot feeds `rpt.vwPayrollOverdraftByMonth`.
  - FactPayrollOverdraftEvent feeds no mapped view.

## 5. Coverage

- **Inspected, source read:** the Sales DDL (`stg.StgSalesOrder`, `dim.DimCustomer`, `DimRegion`, `DimProduct`, `DimDate`, `fact.FactSales`, `ctl.LoadRun`), `usp_LoadDimCustomer`, `usp_LoadDimRegion`, `usp_LoadFactSales`, `_v3`, `_Merge`, `_Restartable` and `Incremental`, the four Sales views, `Jobs/NightlyCore.sql`, and the full PayrollOverdraft set (tables, procedures, view, job).
- **Grep only:** the other `usp_LoadFactSales*` variants, checked only for `RegionName`/`CategoryName`/`SegmentName` and for rerun keywords.
- **Inventory-only:** all other subjects (~430), including the 213 `*Snapshot` facts. Their keys and relationships are unresolved.
- **Not available:** `dim.DimDate` and `dim.DimProduct` loaders (none found), staging ingestion (outside the repo), and any live catalog or deployed state.
- **Facts with UNRESOLVED edges:** FactSales (ProductKey version resolution and the three denormalised name columns). DimCustomer.RegionKey is also UNRESOLVED.

## 6. Findings

| finding | entity | evidence | finding confidence | severity if confirmed | consequence | remediation |
|---------|--------|----------|--------------------|-----------------------|-------------|-------------|
| `DimProduct` has no writer in the repo | dim.DimProduct, fact.FactSales | 0 `INSERT`/`MERGE`/`UPDATE` on it; no `usp_LoadDimProduct`; absent from `NightlyCore` | Likely | blocking | the inner join in `usp_LoadFactSales` loads zero rows unless the table is filled outside the repo | confirm the external loader, or add one to the job. Impact analysis first |
| FactSales name columns never populated | fact.FactSales | `RegionName`, `CategoryName` and `SegmentName` appear in none of the 22 `usp_LoadFactSales*` procs or Sales views | Confirmed (inspected objects) | significant | reports reading them get NULLs, not an error | read the attribute from `DimRegion`/`DimProduct`; drop the columns only after impact analysis |
| `LoadRunId` has two meanings | fact.FactSales, ctl.LoadRun | the scheduled proc stamps `s.BatchId`; the variants stamp `MAX(LoadRunId)+1` and insert into `ctl.LoadRun`; four views inner-join `ctl.LoadRun` | Confirmed | blocking | rows loaded by the scheduled job vanish from the run-based views | pick one meaning, and left-join or reconcile in the views |
| Literal `-1` keys against a PK | dim.DimRegion, dim.DimCustomer, the three PayrollOverdraft dims | `usp_LoadDimRegion` inserts `-1` each run; `DimCustomer` and the Payroll dims insert `-1` per new member | Confirmed from source | blocking | the second member or run violates the PK; every loaded fact gets `CustomerKey = -1` | generate real surrogate keys (`IDENTITY` or `SEQUENCE`) and seed a single `-1` row. Schema impact analysis first |
| Snapshot measure summed over time | rpt.vwPayrollOverdraftByMonth | `SUM(SettledAmount)` over snapshot rows grouped by month | Likely | significant | inflated if `SettledAmount` is a balance | confirm the measure's meaning, then choose a period-end value or average |
| No rerun guard on scheduled loads | fact.FactSales, both Payroll facts | bare `INSERT...SELECT`, PK only | Confirmed | significant | a rerun errors out, or loads duplicates under new ids | per the repo's DEBT-002; use the `_Merge` pattern or a run guard |
| Duplicate views | rpt.vwSalesByLoadRun, rpt.vwSalesRunHistory | identical definitions | Confirmed | advisory | two paths to maintain | consolidate after checking consumers |
| Ambiguous 'Unknown' member | Customer, Segment and Status dims | all seed key `-1`, name `'Unknown'` | Possible | advisory | unmapped customer, segment and status look the same in reports | confirm intent |

Edge-list gaps and the missing declarations are inspected-object findings only, and live deployment may differ. These findings also go beyond `AGENTS.md > Conventions > Data Access` DEBT-001 to DEBT-003: the `-1` PK failure is harsher than "no SCD", and `LoadRunId` has two meanings.

## 7. Querying this warehouse

Rules for reading the warehouse, not loading it. They address the ways a report goes wrong quietly, producing a number rather than an error.

1. **Start at the fact and state its grain** in one sentence before writing any SQL. FactSales is one row per sales order id. If the grain is not clear, resolve that first.
2. **Reach an attribute by following a fact key to the dimension that owns it.** Never read it off a column that merely sits on a table already in the join. `FactSales.RegionName`, `CategoryName` and `SegmentName` are declared but never populated, so they return NULLs, not an error. Use `DimRegion` or `DimProduct.CategoryName` instead.
3. **Use an existing reporting view's join path as a usage lead before inventing one.** It shows the path this warehouse uses, not that the result is correct. Freeze the report's grain, temporal predicate, expected result and tolerances before claiming correctness. If two views disagree, record the conflict in the edge list rather than picking one.
4. **Treat a same-named column on an already-joined table as suspect** until you know which table populates it. Same name is not same meaning, and it is not evidence of a relationship.
5. **Replicating a report from another warehouse: write the source-column → target-concept mapping before any SQL.** Name what is unresolved and ask. Do not substitute the nearest-looking column.
6. **Add an effective-date predicate only when the key does not already identify one version.** The discriminator is a property of the edge, recorded as `version resolution`:
   - **`Pinned at load`**: the load found the dimension version that applied and stamped its surrogate key on the fact (`FactSales.CustomerKey` and the `PayrollOverdraftKey` edges). Adding `EffectiveFrom`/`EffectiveTo`/`IsCurrent` to that join silently drops every fact pointing at a superseded row. It yields a low row count, not an error.
   - **`Deferred to query`**: the key does not pick a version on its own (a natural or durable key, or a run/snapshot register where several rows are live). The temporal predicate is required. Use the warehouse's own as-of rule, copied from a reporting view. No such edge is mapped yet.
   - **`UNRESOLVED`** (`FactSales.ProductKey`, `DimCustomer.RegionKey`): do not choose. Copy an existing view's join for that edge, or ask.

Two named path hazards:

- **Fan trap:** joining a chained one-to-many below the fact multiplies the fact rows and double-counts the measure. Aggregate at the fact's own grain, or aggregate the many-side separately before joining.
- **Chasm trap:** joining two facts directly through a shared dimension (for example FactPayrollOverdraftSnapshot and FactPayrollOverdraftEvent through `DimPayrollOverdraft` or `DimDate`) multiplies their rows within each shared key group and inflates both measures. Sharing a conformed dimension is legitimate drill-across. Aggregate each fact to the shared grain independently first, then join the two aggregates on the shared keys.

If the map marks an edge `UNRESOLVED` or `CONFLICTING`, that is the map telling you it does not know. Treat it as a question to ask, not a gap to fill with the most plausible-looking column.
