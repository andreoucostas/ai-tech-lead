<!-- warehouse-map full pass: 2026-11-15T18:40Z -->
# Warehouse map

Grep- and read-based structure detection, not execution. Confirm against a load run or the team before relying on it for a destructive change.

## 1. Table inventory

Flow: `stg.Stg*` → `dbo.usp_Load*` (SQL Agent jobs in `Jobs/`) → `dim` / `bridge` / `fact` → `rpt.vw*` / `rpt.usp_BranchBalanceAsAt` → `ReportReader`.

Counts: 66 stg, 86 dim, 62 fact, 1 bridge, 85 rpt views + 1 rpt proc, 149 load procs, 42 job files.

### Core (read in full)

| entity | layer | classification | grain | primary key | natural/business key |
|--------|-------|----------------|-------|-------------|----------------------|
| `stg.StgTransaction` | stg | staging | one row per transaction line per batch | none | `TransactionLineId` |
| `stg.StgAccountBalance` | stg | staging | one row per account per month-end per batch | none | `AccountId`, `MonthEndDate` |
| `stg.StgAccount`, `StgBranch`, `StgCustomer`, `StgAccountHolder` | stg | staging | one row per source record per batch | none | `AccountId`, `BranchCode`, `CustomerId`, (`AccountId`,`CustomerId`) |
| `dim.DimDate` | dim | dimension | one row per calendar day (rolling window: current year − 10 to current year + 1) | `DateKey` (yyyymmdd) | `CalendarDate` |
| `dim.DimRegion` | dim | dimension (Type 1) | one row per region | `RegionKey` | `RegionCode` |
| `dim.DimBranch` | dim | dimension (Type 1) | one row per branch | `BranchKey` | `BranchCode` |
| `dim.DimAccount` | dim | dimension (Type 1) | one row per account | `AccountKey` | `AccountId` |
| `dim.DimCustomer` | dim | dimension (SCD2) | one row per customer version | `CustomerKey` | `CustomerId` (durable, shared by all versions) |
| `bridge.BridgeAccountHolder` | bridge | bridge | one row per account per holder | (`AccountKey`, `CustomerId`) | — |
| `fact.FactTransaction` | fact | transaction fact | one row per transaction line | `TransactionLineKey` (= source `TransactionLineId`) | — |
| `fact.FactAccountBalanceMonthly` | fact | periodic snapshot | one row per account per month-end | (`AccountKey`, `MonthEndDateKey`) | — |

### Domain family (about 38 domains; 81 dims, 60 facts, 60 stg)

Sampled in full: CardFacility, BrokerageRepayment. DDL, load and view read: EscrowAccrual, PayrollOverdraft (partial), PayrollGuarantee (DDL only). All other domains are **inventory-only** (counts by grep).

| entity pattern | layer | classification | grain | primary key | natural/business key |
|----------------|-------|----------------|-------|-------------|----------------------|
| `stg.Stg<Domain>{Event,Movement,Snapshot}` | stg | staging | one row per `SourceId` per batch | none | `SourceId` + domain `<Name>Id` |
| `dim.Dim<Domain>` | dim | dimension; 26 carry `EffectiveFrom/To/IsCurrent` | one row per `<Name>Id` (never versioned in practice) | `<Name>Key` (no IDENTITY) | `<Name>Id` |
| `dim.Dim<Domain>{Channel,Status,Type,Segment}` | dim | dimension (code/name lookup) | one row per code | `<Name>Key` (no IDENTITY) | `<Name>Code` |
| `fact.Fact<Domain>{Event,Movement,Snapshot}` | fact | PK is `SourceId` only, so the grain is **not stated**; "one row per source record" is inferred | one row per `SourceId` (inferred) | `<Fact>Key` (= `SourceId`) | — |

## 2. Relationship edge list

No `FOREIGN KEY` constraint exists anywhere in the inspected source, so no edge below is "Declared".

| fact | fk column | → dimension | role | version resolution | evidence | confidence |
|------|-----------|-------------|------|--------------------|----------|------------|
| `FactTransaction` | `AccountKey` | `DimAccount` | account | Type 1 (one row per account) | `usp_LoadFactTransaction` join; `vwTransactionDetail` | Load-derived, In use |
| `FactTransaction` | `TransactionDateKey` | `DimDate` | transaction date | Pinned at load | same | Load-derived, In use |
| `FactTransaction` | `PostingDateKey` | `DimDate` | posting date | Pinned at load | same; `vwMonthlyPostedAmountByBranch` | Load-derived, In use |
| `FactAccountBalanceMonthly` | `AccountKey` | `DimAccount` | account | Type 1 | `usp_LoadFactAccountBalanceMonthly`; `vwMonthEndBalanceByRegion` | Load-derived, In use |
| `FactAccountBalanceMonthly` | `MonthEndDateKey` | `DimDate` | month-end date | Pinned at load | same | Load-derived, In use |
| `DimAccount` | `BranchKey` | `DimBranch` | branch | Type 1 | `usp_LoadDimAccount` `MERGE`; views | Load-derived, In use |
| `DimBranch` | `RegionKey` | `DimRegion` | region | Type 1 | `usp_LoadDimBranch` `MERGE`; views | Load-derived, In use |
| `BridgeAccountHolder` | `AccountKey` | `DimAccount` | account | Type 1 | `usp_LoadBridgeAccountHolder` | Load-derived |
| `BridgeAccountHolder` | `CustomerId` | `DimCustomer` | holder | **Deferred to query**: `IsCurrent = 1` or an as-of rule is required | `rpt.vwAccountHolders` | In use |
| 28 domain facts (all with a `CustomerKey` column) | `CustomerKey` | `DimCustomer` | customer | **Pinned at load**, to the current version when the load ran (not as of `BusinessDate`) | `DimCustomer c ON c.CustomerId = s.CustomerId AND c.IsCurrent = 1` in 28 fact load procs, e.g. `usp_LoadFactEscrowAccrualSnapshot` | Load-derived |
| Domain facts (sampled: CardFacility, BrokerageRepayment, EscrowAccrual) | `<Domain>Key` | `Dim<Domain>` | the domain entity | UNRESOLVED as a family. The dim is never versioned. Some loads join `IsCurrent = 1` (CardFacility, EscrowAccrual), others do not (BrokerageRepayment). | load joins, sampled domains only | Load-derived (sampled) |
| Domain facts (sampled) | `<Domain>{Channel,Status,Type,Segment}Key` | `Dim<Domain><Lookup>` | lookup | Pinned at load (no versioning) | load joins | Load-derived (sampled) |
| Domain facts (sampled) | `BusinessDateKey` | `DimDate` | business date | Pinned at load | load joins | Load-derived (sampled) |
| About 50 domain facts not read | same pattern | same pattern | — | UNRESOLVED | naming and counts only | UNRESOLVED |

## 3. Loading

| entity | load proc/pipeline | orchestrated by | rerun protection | SCD | partitioning |
|--------|--------------------|-----------------|------------------|-----|--------------|
| `DimDate` | `usp_LoadDimDate` | `Jobs/NightlyCore.sql` step 1 | `NOT EXISTS` on `CalendarDate` | n/a | none found |
| `DimRegion` | `usp_LoadDimRegion` | NightlyCore step 2 | `MERGE` on `RegionCode` | Type 1 | none found |
| `DimBranch` | `usp_LoadDimBranch` | NightlyCore step 3 | `MERGE` on `BranchCode` | Type 1 | none found |
| `DimAccount` | `usp_LoadDimAccount` | NightlyCore step 4 | `MERGE` on `AccountId` | Type 1 (`OpenedDate` not updated on match) | none found |
| `DimCustomer` | `usp_LoadDimCustomer` | NightlyCore step 5 | closes the current row on change, inserts when no current row exists | SCD2 | none found |
| `BridgeAccountHolder` | `usp_LoadBridgeAccountHolder` | NightlyCore step 6 | delete the accounts present in staging, then re-insert; not batch-scoped | n/a | none found |
| `FactTransaction` | `usp_LoadFactTransaction` | NightlyCore step 7 | batch delete-and-reload on `LoadRunId = MAX(BatchId)`, in one transaction | n/a | none found |
| `FactAccountBalanceMonthly` | `usp_LoadFactAccountBalanceMonthly` | NightlyCore step 8 | deletes all rows for the month-ends present in the batch, then re-inserts (a month is replaced wholesale, including accounts absent from the batch) | n/a | none found |
| 81 domain dims | `usp_LoadDim<Domain>[<Lookup>]` | `Jobs/<Domain>Daily.sql`, dims first | insert only for new codes or ids | not versioned (DEBT-003) | none found |
| 60 domain facts | `usp_LoadFact<Domain><Kind>` | `Jobs/<Domain>Daily.sql`, after dims | **none** for 60 of 62 facts: no batch filter and no delete. `SourceId` PK makes a rerun fail rather than silently duplicate. | n/a | none found |

Load order is encoded as job steps: dims, then bridge, then facts (verified in `NightlyCore.sql` and `CardFacilityDaily.sql`). 149 load procs match the 149 job steps per the discovery notes (grep count). No partition function, scheme, `SWITCH`, columnstore, purge or archive job exists in the inspected source.

## 4. Dimensional semantics

- **Fact type:** `FactTransaction` is a transaction fact. `FactAccountBalanceMonthly` is a periodic snapshot. Domain `Event` / `Movement` / `Snapshot` suffixes are naming only. I verified none of them against load behavior.
- **Role-playing dimensions:** `DimDate` is reached by `TransactionDateKey` and `PostingDateKey`. `vwMonthlyPostedAmountByBranch` correctly uses the posting-date role.
- **Conformed dimensions:** `DimDate`, `DimAccount` / `DimBranch` / `DimRegion` and `DimCustomer` are shared. Each domain's own dims are used only by that domain.
- **Degenerate dimensions:** none identified. `SourceId` is the PK of domain facts.
- **Measure additivity:**
  - `FactTransaction.Amount` is additive.
  - `FactAccountBalanceMonthly.ClosingBalance` is semi-additive: it sums across accounts for one month-end but not across months. The core views and proc respect this by filtering or grouping by month-end.
  - Domain measures (`BalanceAmount`, `AccruedAmount`, `SettledAmount`, `GrossAmount`, `ExposureAmount`, `FeeAmount`) are **UNRESOLVED**. The names do not settle whether they are flows or balances.
- **Feeds:** the core facts feed `vwMonthlyPostedAmountByBranch`, `vwMonthEndBalanceByRegion`, `vwTransactionDetail` and `usp_BranchBalanceAsAt`. `vwAccountHolders` reads the bridge. Each domain feeds its own Detail / Summary / Trend / ByMonth views.

## 5. Coverage

- **Read in full:** the core tables, procs, views, `NightlyCore.sql`, `Security/*`, `Deploy/reporting.manifest`.
  - Domain **CardFacility**: tables, procs, views, job.
  - Domain **BrokerageRepayment**: tables, procs, views.
  - **EscrowAccrual**: fact and dim DDL, the snapshot fact load, two dim loads, the ByMonth, Summary and Detail views.
  - **PayrollOverdraft**: fact DDL, `Segment` DDL, ByMonth view.
- **Inventory-only (grep counts and file names):** the other ~36 domains. Counts: 81 dim loads with a `-1` key, 26 dims with `IsCurrent`, 28 fact loads joining `DimCustomer`, 2 fact loads with `DELETE`, 20 views using `CalendarMonth`.
- **Unresolved edges:** about 50 domain facts, inferred by pattern only. Their key and relationship properties remain unresolved.
- **Not read or not in this repo:** the release pipeline, the upstream staging process, `TECH_DEBT.md` (so overlap with DEBT-001 and DEBT-003 is taken from AGENTS.md), and any live catalog. `warehouse.sqlproj` is a bare SDK reference. No dynamic SQL was encountered in the files read.
- **Drift:** AGENTS.md says "85/85/85". Actual: 85 views, 86 manifest entries (the extra one is the `rpt` proc), 85 `GRANT SELECT` plus 1 `GRANT EXECUTE`. Neither file has been edited.

## 6. Findings

| finding | entity | evidence | finding confidence | severity if confirmed | consequence | remediation |
|---------|--------|----------|--------------------|-----------------------|-------------|-------------|
| 19 `…ByMonth` views group by `CalendarMonth` without `CalendarYear` | `rpt.vwEscrowAccrualByMonth`, `vwPayrollOverdraftByMonth`, and 17 more (`Views/`; only `vwMonthlyPostedAmountByBranch` includes the year); `DimDate` spans about 12 years | Confirmed | blocking | The same month of different years is summed into one row, so totals are wrong | Add `CalendarYear` to the select and `GROUP BY` (view-only change; the view and its manifest and grant entries already exist) |
| Domain dim loads insert the literal key `-1` into a non-identity PK, and the name is always `'Unknown'` | 81 `usp_LoadDim*` procs; e.g. `usp_LoadDimCardFacility`, `usp_LoadDimBrokerageRepaymentStatus`, `usp_LoadDimEscrowAccrual` | Confirmed from the statements; not executed | blocking | A second distinct member breaks the PK. Any member that loads has key −1 and the name "Unknown", so `vwCardFacilitySummary` and `vwEscrowAccrualSummary`, which group by the name, collapse to one row. | Needs a key-and-name design decision. Schema impact analysis is required first. |
| Domain fact loads have no rerun protection | 60 of 62 fact procs; e.g. `usp_LoadFactBrokerageRepaymentEvent`, `usp_LoadFactCardFacilityMovement` | Confirmed | significant | Each run reads all of staging. A rerun, or a staging table holding old batches, causes PK violations on `SourceId`. AGENTS.md records this as DEBT-001. | Apply the `usp_LoadFactTransaction` batch delete-and-reload pattern (ADR-001) |
| Fact loads `INNER JOIN` every dim with no reject path or reconciliation | `usp_LoadFactTransaction` and all sampled domain loads | Confirmed | significant | A staging row with an unknown account or a date outside the `DimDate` window is silently dropped | Per-load row-count reconciliation (none exists today) |
| `DimBranch.RegionName` is never populated | `Tables/dim.DimBranch.sql` vs `usp_LoadDimBranch` | Confirmed | significant | A report reading `DimBranch.RegionName` gets NULLs, not an error | Take the name from `DimRegion` via `RegionKey` |
| Snapshot- and Movement-fact measures are summed across days | `vwPayrollOverdraftByMonth` (`SettledAmount`), `vwEscrowAccrualByMonth` (`GrossAmount`), `vwCardFacilitySummary` / `vwCardFacilityTrend` (`BalanceAmount`) | Possible: the names do not prove balance semantics | significant if the measures are balances | Month and facility totals inflate | The maintainer confirms the meaning of each measure |
| `DimCustomer` is pinned to the current version at load | 28 domain fact load procs | Likely | advisory | Backdated or late-arriving facts take the current segment and name, not the one in force on `BusinessDate` | Convention decision |
| `BridgeAccountHolder` carries the business key `CustomerId`. `HolderWeight` is `1/n` at 6 decimal places, so a 3-holder account's weights sum to 0.999999. | `Tables/bridge.BridgeAccountHolder.sql`, `usp_LoadBridgeAccountHolder` | Possible | advisory | A join without `IsCurrent = 1` fans out. Weighted allocation carries small rounding error. | None needed now |

Recorded as conventions, not defects: `DimAccount` / `DimBranch` are Type 1, so history re-attributes to the current branch. Domain dims have `IsCurrent` columns but are never versioned (DEBT-003).

## 7. Querying this warehouse

Rules for reading the warehouse, not loading it. They address the ways a report goes wrong quietly, producing a number rather than an error.

1. **Start at the fact and state its grain** in one sentence before writing any SQL. `FactTransaction` is one row per transaction line. `FactAccountBalanceMonthly` is one row per account per month-end. Domain facts have no stated grain; resolve that first.
2. **Reach an attribute by following a fact key to the dimension that owns it.** Never read it off a column that merely sits on a table already in the join. A column declared in DDL but never populated by any load returns `NULL`s or blanks, not an error. Example: `DimBranch.RegionName` is never loaded; use `DimRegion.RegionName` through `RegionKey`.
3. **Use an existing reporting view's join path as a usage lead before inventing one.** It shows the path this warehouse uses, not that the result is correct. Freeze the report's applicable grain, temporal predicate, expected result and tolerances before claiming correctness. If two views disagree, record that conflict in the edge list rather than picking one. Do not copy the `…ByMonth` views' month grouping, which omits the year.
4. **Treat a same-named column on an already-joined table as suspect** until you know which table populates it. Same name is not same meaning, and it is not evidence of a relationship.
5. **Replicating a report from another warehouse: write the source-column → target-concept mapping before any SQL.** Same-named columns across two warehouses are the trap this rule exists for. Name what is unresolved and ask. Do not substitute the nearest-looking column.
6. **Add an effective-date predicate only when the key does not already identify one version.** The discriminator is a property of the edge, and the edge list records it as `version resolution`:
   - **`Pinned at load`**: the load found the dimension version that applied and stamped that version's surrogate key onto the fact. Adding `EffectiveFrom` / `EffectiveTo` / `IsCurrent` to that join **silently drops every fact pointing at a superseded row**, giving a low row count rather than an error. Example: the 28 domain facts' `CustomerKey` → `DimCustomer`.
   - **`Deferred to query`**: the key does not pick a version on its own (a natural or business key, or a durable key shared by every version row). The temporal predicate is **required**, and omitting it multiplies or mis-selects rows. Use the warehouse's own as-of rule, copied from a reporting view. Example: `BridgeAccountHolder.CustomerId` → `DimCustomer`, where `vwAccountHolders` uses `IsCurrent = 1`.
   - **`UNRESOLVED`**: do not choose. Copy an existing view's join for that edge, or ask. This covers the unread domain facts.

Two named path hazards:

- **Fan trap**: joining a chained one-to-many below the fact multiplies the fact rows and double-counts the measure. Aggregate at the fact's own grain, or aggregate the many-side separately before joining. `BridgeAccountHolder` is the one-to-many to watch: join it only with weights or after aggregating.
- **Chasm trap**: joining two facts directly through a shared dimension multiplies their rows within each shared key group, inflating both measures. This is not an argument against two facts sharing a conformed dimension, which is legitimate drill-across. Aggregate each fact to the shared grain independently first, then join the two aggregates on the shared keys. Example: `FactTransaction` and `FactAccountBalanceMonthly` through `DimAccount`.

If the map marks an edge `UNRESOLVED` or `CONFLICTING`, that is the map telling you it does not know. Treat it as a question to ask, not a gap to fill with the most plausible-looking column.
