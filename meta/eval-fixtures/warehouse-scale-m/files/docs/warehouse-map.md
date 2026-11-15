<!-- warehouse-map full pass: 2026-11-15T11:45Z -->
# Warehouse map

SQL Server warehouse (`warehouse.sqlproj`, `Microsoft.Build.Sql/0.2.0`). Grep-based reading of the repository's own SQL; nothing was executed and no live catalog was read. See **Coverage** for what was and was not read.

Layers: `stg` (63 tables) → `dim` (87) / `fact` (63) → `rpt` (88 views); `ctl` (1 table, `ctl.LoadRun`). Loads: 85 `usp_LoadDim*`, 65 `usp_LoadFact*`; 43 SQL Agent job scripts in `Jobs/`.

## 1. Table inventory

### stg (63 tables)
One `stg.Stg<Domain><Entity><Event|Movement|Snapshot>` per fact, plus `stg.StgSalesOrder`. Loose landing shape: source row id (`SourceId`, or `SalesId` for sales), business ids/codes, `BusinessDate` (`OrderDate` for sales), measure, `CurrencyCode` (not on sales), `BatchId`. Not individually inspected beyond samples (`StgDepositBalanceMovement`, `StgSalesOrder`). Feeds into `stg` are outside this repo.

### ctl
| entity | layer | classification | grain | primary key | natural/business key |
|--------|-------|----------------|-------|-------------|----------------------|
| ctl.LoadRun | ctl | control | one row per Sales load run (written only by the unscheduled `usp_LoadFactSales_v2` / `usp_LoadFactSalesIncremental`) | LoadRunId | — |

### dim (87 tables)
Surrogate key `<X>Key INT` is the primary key in every dim; no `UNIQUE` or foreign key is declared anywhere in `Tables/`.

| entity | layer | classification | grain | primary key | natural/business key |
|--------|-------|----------------|-------|-------------|----------------------|
| DimCustomer | dim | dimension, history columns (EffectiveFrom/To, IsCurrent) | one row per customer version (intended) | CustomerKey | CustomerId (+ RegionKey, SegmentName) |
| DimDate | dim | dimension | one row per calendar date | DateKey | CalendarDate (+ CalendarMonth) |
| DimProduct | dim | dimension, no history columns | one row per product | ProductKey | ProductId (+ CategoryName) |
| DimRegion | dim | dimension, no history columns | one row per region | RegionKey | none (RegionName only) |
| 25 domain entity dims with history columns: DimBrokerageTransfer, DimCardFacility, DimCardJournal, DimCustodyReconciliation, DimDepositBalance, DimEscrowAccrual, DimEscrowDrawdown, DimEscrowProvision, DimFactoringFacility, DimFactoringProvision, DimPayrollGuarantee, DimPayrollLedger, DimPayrollOverdraft, DimPayrollPosition, DimPensionBalance, DimRemittanceFee, DimRemittanceOverdraft, DimRemittanceProvision, DimRetailFee, DimRetailHolding, DimRetailMandate, DimTradeMargin, DimTreasuryAccount, DimWealthReconciliation, DimWealthTransfer | dim | dimension, history columns | one row per entity version (intended) | `<X>Key` | `<X>Id NVARCHAR(50)` |
| 17 domain entity dims without history columns, as evidenced by fact joins: DimBrokerageDrawdown, DimBrokerageRepayment, DimClearingJournal, DimCorporateBalance, DimCorporateSettlement, DimCustodyJournal, DimDepositLimit, DimDepositSettlement, DimEscrowJournal, DimFactoringDrawdown, DimLendingLimit, DimPensionMandate, DimPensionOverdraft, DimRemittanceLimit, DimTradeTransfer, DimTreasuryAccrual, DimTreasuryJournal | dim | dimension | one row per entity | `<X>Key` | `<X>Id` |
| ~40 lookup dims (`Dim<Entity>{Type,Channel,Status,Segment}`), e.g. DimBrokerageRepaymentChannel, DimTreasuryAccrualType | dim | dimension (small lookup), no history | one row per code | `<X>Key` | `<X>Code NVARCHAR(20)` |

The count of lookup dims and the no-history entity dims is derived from file counts (87 dims = 26 with history + DimDate + DimProduct + DimRegion + the rest); one dim in that remainder is not named by any fact join I read, so the 17 / ~40 split is approximate.

### fact (63 tables)
Every fact: PK = the staging `SourceId` (`SalesId` for FactSales), `BusinessDateKey` (or `OrderDateKey`), measure(s), `CurrencyCode CHAR(3)` (except FactSales), `LoadRunId`. **Business grain is not stated in any fact DDL**; each fact is "one row per staged source record". Fact type below follows the name suffix only (Event = transaction, Movement = transaction/flow, Snapshot = periodic snapshot) and is not confirmed from load logic.

| entity | layer | classification | grain | primary key | natural/business key |
|--------|-------|----------------|-------|-------------|----------------------|
| FactSales | fact | transaction | one row per stg.StgSalesOrder row | SalesKey (= SalesId) | none declared |
| 62 domain facts: one per `usp_LoadFact<Domain><Entity><Event\|Movement\|Snapshot>` listed in the Loading and Edge sections | fact | transaction (Event/Movement) or periodic snapshot (Snapshot) by name | one row per staged source record (business grain unstated) | `<Fact>Key BIGINT` (= SourceId) | none declared |

## 2. Relationship edge list

Derived from each `usp_LoadFact*` join (all 65 procs read). 217 edges; the proc join count (223, minus 6 duplicated in the two unscheduled Sales variants) equals the count of `…Key INT` columns in the 63 fact DDLs, so every FK column pairs to a join. No declared foreign keys exist, so none is `Declared`. Reporting-view joins were read only for FactSales, DepositBalance and a few samples; other edges are not confirmed `In use`. **No edge is UNRESOLVED or CONFLICTING.**

Notation: fact names omit `Fact`, dim names omit `Dim`; the FK column is `<dim name>Key` on the fact. All rows: evidence = load-proc join, confidence = **Load-derived**.
- **P1** = Pinned at load; the join filters `IsCurrent = 1`, so the key is the version current *at load time*, not at the fact's business date.
- **P0** = Pinned at load; the dim has no history columns, so the key identifies the one row.
- Because every dim load inserts only key `-1` (finding F1), the pinned key is in practice always `-1`.

**Date edges (63):** `BusinessDateKey → DimDate` (role: business date; P0, joined on `CalendarDate = BusinessDate`) for all 62 domain facts; `OrderDateKey → DimDate` (role: order date) for FactSales. Grouped here to avoid 63 identical rows.

**Non-date edges (154):**

| fact | fk column | → dimension | role | version resolution |
|------|-----------|-------------|------|--------------------|
| BrokerageRepaymentEvent | BrokerageRepaymentKey | BrokerageRepayment | entity | P0 |
| BrokerageRepaymentEvent | BrokerageRepaymentChannelKey | BrokerageRepaymentChannel | lookup by Code | P0 |
| BrokerageRepaymentEvent | BrokerageRepaymentStatusKey | BrokerageRepaymentStatus | lookup by Code | P0 |
| BrokerageRepaymentMovement | BrokerageRepaymentKey | BrokerageRepayment | entity | P0 |
| BrokerageRepaymentMovement | BrokerageRepaymentChannelKey | BrokerageRepaymentChannel | lookup by Code | P0 |
| BrokerageRepaymentMovement | BrokerageRepaymentStatusKey | BrokerageRepaymentStatus | lookup by Code | P0 |
| BrokerageDrawdownSnapshot | BrokerageDrawdownKey | BrokerageDrawdown | entity | P0 |
| BrokerageDrawdownSnapshot | BrokerageDrawdownSegmentKey | BrokerageDrawdownSegment | lookup by Code | P0 |
| BrokerageTransferMovement | BrokerageTransferKey | BrokerageTransfer | entity | P1 |
| BrokerageTransferMovement | BrokerageTransferSegmentKey | BrokerageTransferSegment | lookup by Code | P0 |
| BrokerageTransferMovement | CustomerKey | Customer | customer | P1 |
| CardJournalSnapshot | CardJournalKey | CardJournal | entity | P1 |
| CardJournalSnapshot | CardJournalSegmentKey | CardJournalSegment | lookup by Code | P0 |
| CardJournalSnapshot | CustomerKey | Customer | customer | P1 |
| CardFacilitySnapshot | CardFacilityKey | CardFacility | entity | P1 |
| CardFacilitySnapshot | CardFacilityStatusKey | CardFacilityStatus | lookup by Code | P0 |
| CardFacilityMovement | CardFacilityKey | CardFacility | entity | P1 |
| CardFacilityMovement | CardFacilityStatusKey | CardFacilityStatus | lookup by Code | P0 |
| ClearingJournalMovement | ClearingJournalKey | ClearingJournal | entity | P0 |
| ClearingJournalMovement | ClearingJournalSegmentKey | ClearingJournalSegment | lookup by Code | P0 |
| ClearingJournalMovement | ClearingJournalStatusKey | ClearingJournalStatus | lookup by Code | P0 |
| ClearingJournalMovement | CustomerKey | Customer | customer | P1 |
| ClearingJournalEvent | ClearingJournalKey | ClearingJournal | entity | P0 |
| ClearingJournalEvent | ClearingJournalSegmentKey | ClearingJournalSegment | lookup by Code | P0 |
| ClearingJournalEvent | ClearingJournalStatusKey | ClearingJournalStatus | lookup by Code | P0 |
| ClearingJournalEvent | CustomerKey | Customer | customer | P1 |
| CustodyJournalEvent | CustodyJournalKey | CustodyJournal | entity | P0 |
| CustodyJournalEvent | CustomerKey | Customer | customer | P1 |
| CustodyReconciliationSnapshot | CustodyReconciliationKey | CustodyReconciliation | entity | P1 |
| CustodyReconciliationSnapshot | CustodyReconciliationSegmentKey | CustodyReconciliationSegment | lookup by Code | P0 |
| CustodyReconciliationSnapshot | CustomerKey | Customer | customer | P1 |
| CustodyReconciliationMovement | CustodyReconciliationKey | CustodyReconciliation | entity | P1 |
| CustodyReconciliationMovement | CustodyReconciliationSegmentKey | CustodyReconciliationSegment | lookup by Code | P0 |
| CustodyReconciliationMovement | CustomerKey | Customer | customer | P1 |
| CorporateBalanceSnapshot | CorporateBalanceKey | CorporateBalance | entity | P0 |
| CorporateBalanceEvent | CorporateBalanceKey | CorporateBalance | entity | P0 |
| CorporateSettlementMovement | CorporateSettlementKey | CorporateSettlement | entity | P0 |
| CorporateSettlementMovement | CorporateSettlementTypeKey | CorporateSettlementType | lookup by Code | P0 |
| CorporateSettlementMovement | CorporateSettlementChannelKey | CorporateSettlementChannel | lookup by Code | P0 |
| DepositBalanceMovement | DepositBalanceKey | DepositBalance | entity | P1 |
| DepositBalanceSnapshot | DepositBalanceKey | DepositBalance | entity | P1 |
| DepositSettlementMovement | DepositSettlementKey | DepositSettlement | entity | P0 |
| DepositSettlementEvent | DepositSettlementKey | DepositSettlement | entity | P0 |
| DepositLimitEvent | DepositLimitKey | DepositLimit | entity | P0 |
| DepositLimitEvent | DepositLimitStatusKey | DepositLimitStatus | lookup by Code | P0 |
| DepositLimitEvent | DepositLimitSegmentKey | DepositLimitSegment | lookup by Code | P0 |
| DepositLimitEvent | CustomerKey | Customer | customer | P1 |
| EscrowJournalEvent | EscrowJournalKey | EscrowJournal | entity | P0 |
| EscrowJournalEvent | EscrowJournalSegmentKey | EscrowJournalSegment | lookup by Code | P0 |
| EscrowJournalEvent | CustomerKey | Customer | customer | P1 |
| EscrowJournalMovement | EscrowJournalKey | EscrowJournal | entity | P0 |
| EscrowJournalMovement | EscrowJournalSegmentKey | EscrowJournalSegment | lookup by Code | P0 |
| EscrowJournalMovement | CustomerKey | Customer | customer | P1 |
| EscrowDrawdownSnapshot | EscrowDrawdownKey | EscrowDrawdown | entity | P1 |
| EscrowDrawdownSnapshot | EscrowDrawdownChannelKey | EscrowDrawdownChannel | lookup by Code | P0 |
| EscrowAccrualSnapshot | EscrowAccrualKey | EscrowAccrual | entity | P1 |
| EscrowAccrualSnapshot | EscrowAccrualTypeKey | EscrowAccrualType | lookup by Code | P0 |
| EscrowAccrualSnapshot | EscrowAccrualChannelKey | EscrowAccrualChannel | lookup by Code | P0 |
| EscrowAccrualSnapshot | CustomerKey | Customer | customer | P1 |
| EscrowProvisionSnapshot | EscrowProvisionKey | EscrowProvision | entity | P1 |
| EscrowProvisionSnapshot | CustomerKey | Customer | customer | P1 |
| FactoringProvisionEvent | FactoringProvisionKey | FactoringProvision | entity | P1 |
| FactoringProvisionEvent | FactoringProvisionChannelKey | FactoringProvisionChannel | lookup by Code | P0 |
| FactoringDrawdownMovement | FactoringDrawdownKey | FactoringDrawdown | entity | P0 |
| FactoringDrawdownMovement | FactoringDrawdownTypeKey | FactoringDrawdownType | lookup by Code | P0 |
| FactoringDrawdownMovement | CustomerKey | Customer | customer | P1 |
| FactoringDrawdownSnapshot | FactoringDrawdownKey | FactoringDrawdown | entity | P0 |
| FactoringDrawdownSnapshot | FactoringDrawdownTypeKey | FactoringDrawdownType | lookup by Code | P0 |
| FactoringDrawdownSnapshot | CustomerKey | Customer | customer | P1 |
| FactoringFacilityEvent | FactoringFacilityKey | FactoringFacility | entity | P1 |
| FactoringFacilityEvent | FactoringFacilityTypeKey | FactoringFacilityType | lookup by Code | P0 |
| FactoringFacilityEvent | FactoringFacilityChannelKey | FactoringFacilityChannel | lookup by Code | P0 |
| FactoringFacilityMovement | FactoringFacilityKey | FactoringFacility | entity | P1 |
| FactoringFacilityMovement | FactoringFacilityTypeKey | FactoringFacilityType | lookup by Code | P0 |
| FactoringFacilityMovement | FactoringFacilityChannelKey | FactoringFacilityChannel | lookup by Code | P0 |
| LendingLimitEvent | LendingLimitKey | LendingLimit | entity | P0 |
| LendingLimitEvent | LendingLimitStatusKey | LendingLimitStatus | lookup by Code | P0 |
| LendingLimitEvent | CustomerKey | Customer | customer | P1 |
| LendingLimitMovement | LendingLimitKey | LendingLimit | entity | P0 |
| LendingLimitMovement | LendingLimitStatusKey | LendingLimitStatus | lookup by Code | P0 |
| LendingLimitMovement | CustomerKey | Customer | customer | P1 |
| PayrollGuaranteeEvent | PayrollGuaranteeKey | PayrollGuarantee | entity | P1 |
| PayrollGuaranteeEvent | CustomerKey | Customer | customer | P1 |
| PayrollLedgerMovement | PayrollLedgerKey | PayrollLedger | entity | P1 |
| PayrollLedgerMovement | PayrollLedgerTypeKey | PayrollLedgerType | lookup by Code | P0 |
| PayrollLedgerMovement | PayrollLedgerChannelKey | PayrollLedgerChannel | lookup by Code | P0 |
| PayrollLedgerMovement | CustomerKey | Customer | customer | P1 |
| PayrollOverdraftSnapshot | PayrollOverdraftKey | PayrollOverdraft | entity | P1 |
| PayrollOverdraftSnapshot | PayrollOverdraftSegmentKey | PayrollOverdraftSegment | lookup by Code | P0 |
| PayrollOverdraftSnapshot | PayrollOverdraftStatusKey | PayrollOverdraftStatus | lookup by Code | P0 |
| PayrollOverdraftEvent | PayrollOverdraftKey | PayrollOverdraft | entity | P1 |
| PayrollOverdraftEvent | PayrollOverdraftSegmentKey | PayrollOverdraftSegment | lookup by Code | P0 |
| PayrollOverdraftEvent | PayrollOverdraftStatusKey | PayrollOverdraftStatus | lookup by Code | P0 |
| PayrollPositionSnapshot | PayrollPositionKey | PayrollPosition | entity | P1 |
| PayrollPositionMovement | PayrollPositionKey | PayrollPosition | entity | P1 |
| PensionBalanceEvent | PensionBalanceKey | PensionBalance | entity | P1 |
| PensionBalanceEvent | CustomerKey | Customer | customer | P1 |
| PensionBalanceMovement | PensionBalanceKey | PensionBalance | entity | P1 |
| PensionBalanceMovement | CustomerKey | Customer | customer | P1 |
| PensionMandateEvent | PensionMandateKey | PensionMandate | entity | P0 |
| PensionMandateEvent | CustomerKey | Customer | customer | P1 |
| PensionOverdraftSnapshot | PensionOverdraftKey | PensionOverdraft | entity | P0 |
| PensionOverdraftSnapshot | CustomerKey | Customer | customer | P1 |
| RemittanceOverdraftEvent | RemittanceOverdraftKey | RemittanceOverdraft | entity | P1 |
| RemittanceOverdraftEvent | RemittanceOverdraftChannelKey | RemittanceOverdraftChannel | lookup by Code | P0 |
| RemittanceOverdraftEvent | RemittanceOverdraftStatusKey | RemittanceOverdraftStatus | lookup by Code | P0 |
| RemittanceOverdraftSnapshot | RemittanceOverdraftKey | RemittanceOverdraft | entity | P1 |
| RemittanceOverdraftSnapshot | RemittanceOverdraftChannelKey | RemittanceOverdraftChannel | lookup by Code | P0 |
| RemittanceOverdraftSnapshot | RemittanceOverdraftStatusKey | RemittanceOverdraftStatus | lookup by Code | P0 |
| RemittanceLimitMovement | RemittanceLimitKey | RemittanceLimit | entity | P0 |
| RemittanceLimitMovement | RemittanceLimitStatusKey | RemittanceLimitStatus | lookup by Code | P0 |
| RemittanceLimitMovement | RemittanceLimitSegmentKey | RemittanceLimitSegment | lookup by Code | P0 |
| RemittanceFeeEvent | RemittanceFeeKey | RemittanceFee | entity | P1 |
| RemittanceFeeEvent | RemittanceFeeStatusKey | RemittanceFeeStatus | lookup by Code | P0 |
| RemittanceFeeEvent | RemittanceFeeChannelKey | RemittanceFeeChannel | lookup by Code | P0 |
| RemittanceProvisionEvent | RemittanceProvisionKey | RemittanceProvision | entity | P1 |
| RemittanceProvisionEvent | RemittanceProvisionTypeKey | RemittanceProvisionType | lookup by Code | P0 |
| RemittanceProvisionEvent | CustomerKey | Customer | customer | P1 |
| RemittanceProvisionMovement | RemittanceProvisionKey | RemittanceProvision | entity | P1 |
| RemittanceProvisionMovement | RemittanceProvisionTypeKey | RemittanceProvisionType | lookup by Code | P0 |
| RemittanceProvisionMovement | CustomerKey | Customer | customer | P1 |
| RetailHoldingMovement | RetailHoldingKey | RetailHolding | entity | P1 |
| RetailHoldingMovement | CustomerKey | Customer | customer | P1 |
| RetailHoldingSnapshot | RetailHoldingKey | RetailHolding | entity | P1 |
| RetailHoldingSnapshot | CustomerKey | Customer | customer | P1 |
| RetailFeeMovement | RetailFeeKey | RetailFee | entity | P1 |
| RetailFeeMovement | RetailFeeChannelKey | RetailFeeChannel | lookup by Code | P0 |
| RetailFeeMovement | RetailFeeStatusKey | RetailFeeStatus | lookup by Code | P0 |
| RetailFeeSnapshot | RetailFeeKey | RetailFee | entity | P1 |
| RetailFeeSnapshot | RetailFeeChannelKey | RetailFeeChannel | lookup by Code | P0 |
| RetailFeeSnapshot | RetailFeeStatusKey | RetailFeeStatus | lookup by Code | P0 |
| RetailMandateSnapshot | RetailMandateKey | RetailMandate | entity | P1 |
| RetailMandateSnapshot | RetailMandateStatusKey | RetailMandateStatus | lookup by Code | P0 |
| RetailMandateSnapshot | RetailMandateSegmentKey | RetailMandateSegment | lookup by Code | P0 |
| RetailMandateSnapshot | CustomerKey | Customer | customer | P1 |
| TradeTransferEvent | TradeTransferKey | TradeTransfer | entity | P0 |
| TradeTransferEvent | TradeTransferSegmentKey | TradeTransferSegment | lookup by Code | P0 |
| TradeTransferEvent | TradeTransferChannelKey | TradeTransferChannel | lookup by Code | P0 |
| TradeTransferEvent | CustomerKey | Customer | customer | P1 |
| TradeMarginEvent | TradeMarginKey | TradeMargin | entity | P1 |
| TradeMarginEvent | CustomerKey | Customer | customer | P1 |
| TreasuryAccountSnapshot | TreasuryAccountKey | TreasuryAccount | entity | P1 |
| TreasuryAccountMovement | TreasuryAccountKey | TreasuryAccount | entity | P1 |
| TreasuryAccrualEvent | TreasuryAccrualKey | TreasuryAccrual | entity | P0 |
| TreasuryAccrualEvent | TreasuryAccrualTypeKey | TreasuryAccrualType | lookup by Code | P0 |
| TreasuryAccrualMovement | TreasuryAccrualKey | TreasuryAccrual | entity | P0 |
| TreasuryAccrualMovement | TreasuryAccrualTypeKey | TreasuryAccrualType | lookup by Code | P0 |
| TreasuryJournalSnapshot | TreasuryJournalKey | TreasuryJournal | entity | P0 |
| TreasuryJournalSnapshot | CustomerKey | Customer | customer | P1 |
| WealthReconciliationSnapshot | WealthReconciliationKey | WealthReconciliation | entity | P1 |
| WealthTransferSnapshot | WealthTransferKey | WealthTransfer | entity | P1 |
| WealthTransferSnapshot | WealthTransferChannelKey | WealthTransferChannel | lookup by Code | P0 |
| Sales | CustomerKey | Customer | customer | P1 |
| Sales | ProductKey | Product (joined on ProductId) | product | P0 |

`rpt.vwFinanceExtract` additionally reaches `DimRegion` through `DimCustomer.RegionKey` (In use; the region is the one on the customer version the fact pinned). `DimCustomer.RegionKey` is declared; the join is in the view only.

## 3. Loading

| entity | load proc/pipeline | orchestrated by | rerun protection | SCD | partitioning |
|--------|--------------------|-----------------|------------------|-----|--------------|
| 62 domain facts | `usp_LoadFact<X>`: one `INSERT … SELECT` from `stg` with inner joins to dims and DimDate; `LoadRunId` = `stg.BatchId` | `Jobs/<Domain>Daily.sql`, dim steps before fact steps; no schedule defined | none; a rerun fails on the PK (`SourceId`), it does not double-load. No transaction around the job steps | n/a; dim version pinned at load | none found |
| FactSales | `usp_LoadFactSales` (scheduled) | `Jobs/NightlyCore.sql` (steps: DimCustomer, DimRegion, FactSales) | none (PK on SalesKey) | n/a | none found |
| FactSales (variants) | `usp_LoadFactSales_v2`, `usp_LoadFactSalesIncremental` | not in any job | v2: new `ctl.LoadRun` row per run, no guard. Incremental: `ctl.LoadRun` watermark; `LoadRunId` = MAX+1 without lock; filter `OrderDate > @Watermark` | n/a | none found |
| 25 domain history dims + DimCustomer | `usp_LoadDim<X>`: `MERGE … WHEN NOT MATCHED INSERT (-1, id, 'Unknown', …)`; 44 MERGE loads in total | the domain job's dim steps; DimCustomer only in `NightlyCore` | insert-if-not-matched on the business id | history columns exist; no load statement closes a version (see Coverage) | none found |
| ~40 lookup dims | `INSERT … SELECT DISTINCT -1, <code>, 'Unknown' … WHERE NOT EXISTS` | the domain job's dim steps | `NOT EXISTS` on the code | none | none found |
| DimRegion | `usp_LoadDimRegion`: `INSERT … SELECT DISTINCT -1,'Unknown' FROM stg.StgSalesOrder` | `NightlyCore` | none; second run violates the PK | none | none found |
| DimDate, DimProduct | **no load proc in this repo** | none | n/a | n/a | n/a |

Jobs: 43 scripts, 148 steps = 85 dim + 63 fact. `Jobs/*.sql` contain no `sp_add_jobschedule`, so no run order across jobs is defined.

## 4. Dimensional semantics

- **Fact type** (by name, unconfirmed from loads): Event/Movement = transaction, Snapshot = periodic snapshot. Several entities carry two or three facts at different types (e.g. DepositBalance Movement + Snapshot) with separate staging tables; they are not unioned.
- **Role-playing dimension:** `DimDate`, reached as business date (domain facts) and order date (FactSales). Each fact reaches it once.
- **Conformed dimension candidates:** `DimCustomer` is shared by 31 facts as the same current-version join, so drill-across through it is plausible, but each fact must be aggregated to the customer grain separately first. Its meaning is only as good as the load (finding F1).
- **Degenerate dimensions:** none seen.
- **Measure additivity:** not determined per measure. Snapshot-typed facts (by name) with `…Amount` measures are treated as potentially semi-additive; see F4.
- **Views fed:** 88 `rpt.vw*` views. 62 aggregate with `SUM`/`GROUP BY`/`UNION`. FactSales feeds `vwOrderDetail`, `vwExecutiveSummary` (by `DimProduct.CategoryName`), `vwFinanceExtract` (region via customer), `vwLoadRunRevenue` (joins `ctl.LoadRun`). Domain facts feed the `Detail`/`Summary`/`Trend`/`ByMonth` views of the same domain.

## 5. Coverage

**Read in full:** `usp_LoadFactSales`, `_v2`, `Incremental`; `usp_LoadDimDepositBalance`, `usp_LoadDimCustomer`, `usp_LoadDimRegion`, `usp_LoadDimBrokerageRepaymentChannel`, `usp_LoadFactDepositBalanceMovement`, `usp_LoadFactCardFacilityMovement`; DDL for FactSales, FactDepositBalanceMovement, DimDepositBalance, DimCustomer, DimProduct, DimDate, DimRegion, StgSalesOrder, StgDepositBalanceMovement, ctl.LoadRun, one lookup dim; `Jobs/NightlyCore.sql`, `Jobs/TreasuryAccrualDaily.sql`; views `vwExecutiveSummary`, `vwFinanceExtract`, `vwLoadRunRevenue`, `vwOrderDetail`, `vwDepositBalanceDetail`, `vwCardFacilityTrend`, `vwEscrowAccrualByMonth`, `vwPayrollPositionSummary`.

**Read by grep or count only:** the FROM/JOIN lines of all 65 fact procs; fact FK column counts (217) against join counts; dim proc shape across 85 procs (MERGE vs `SELECT DISTINCT -1` vs `NOT EXISTS`); `IsCurrent` presence across 87 dim DDLs (26); `SUM/GROUP BY/UNION` presence across 88 views (62 files); snapshot-fact-with-`SUM` pattern (22 views); step counts across 43 jobs.

**Not read (properties unresolved):** the 63 `stg` DDLs individually; measure columns of most facts; the bodies of ~80 domain views (join paths and `In use` status for those edges); any live database; how `stg` is fed and truncated; whether `DimDate`/`DimProduct` are populated externally; SQL Agent schedules or alerts outside this repo.

**Edges:** 217 total, all `Load-derived`, 0 `UNRESOLVED`. The next useful source for any edge is the reporting view that joins it.

**SCD:** no load statement that updates `EffectiveTo`/`IsCurrent` was found among the dim procs I read; the other 85-proc scan was by shape only. Not recorded as a finding because the loads insert only the `-1` member (F1).

## 6. Findings

| finding | entity | evidence | finding confidence | severity if confirmed | consequence | remediation |
|---------|--------|----------|--------------------|-----------------------|-------------|-------------|
| F1 Every dim load inserts surrogate key `-1` with name `'Unknown'`; real members and keys are never loaded | all 85 `usp_LoadDim*`, e.g. `usp_LoadDimDepositBalance`, `usp_LoadDimBrokerageRepaymentChannel`, `usp_LoadDimRegion`, `usp_LoadDimCustomer`; each dim's PK is the surrogate key | Confirmed (DEBT-002) | blocking | A dim holds at most one member; a second distinct id or code fails on the PK. Any member that loads is "Unknown", so facts attribute to `-1` | Impact analysis first, then load real members with generated surrogate keys; keep one reserved `-1` row |
| F2 `DimDate` and `DimProduct` have no load proc, yet all fact loads inner join `DimDate` (and FactSales `DimProduct`) | `Tables/dim.DimDate.sql`, `Tables/dim.DimProduct.sql`, no matching file in `StoredProcedures/`, every `usp_LoadFact*` | Possible (external population unreadable) | blocking | If nothing external fills them, every fact load inserts zero rows | Confirm with the team how they are populated; document in the map |
| F3 `LoadRunId` has two meanings: scheduled `usp_LoadFactSales` stamps `stg.BatchId`, but `rpt.vwLoadRunRevenue` inner joins `ctl.LoadRun`, which only the unscheduled Sales variants write | `usp_LoadFactSales.sql`, `Jobs/NightlyCore.sql`, `rpt.vwLoadRunRevenue.sql`, `usp_LoadFactSales_v2.sql` | Confirmed on the code paths | blocking | Revenue loaded by the scheduled proc drops out of the view, or attaches to an unrelated run if a `BatchId` equals a `ctl.LoadRun` id | Use one meaning for `LoadRunId`; impact analysis on `vwLoadRunRevenue` consumers first |
| F4 22 views `SUM` a Snapshot-typed fact with no date restriction, e.g. `rpt.vwEscrowAccrualByMonth` (`GrossAmount` by month), `rpt.vwPayrollPositionSummary` (`AccruedAmount`, no date) | the 22 views found by the pattern search; two read in full | Likely (measure additivity not shown) | blocking | If a measure is a balance or level, summing across snapshot dates overstates it | Confirm each measure's additivity; restrict to one snapshot date or average/last-value |
| F5 `FactSales.RegionName`, `CategoryName`, `SegmentName` are declared nullable but no Sales load writes them | `Tables/fact.FactSales.sql`; all three Sales procs | Confirmed | significant | Reading them returns NULLs, not an error. No view reads them today | Read attributes through the dims, or drop the columns after impact analysis |
| F6 All fact loads inner join dims and `DimDate` | every `usp_LoadFact*` | Confirmed | significant | Staged rows with an unmatched id, code or date vanish silently | Route unmatched rows to the Unknown member or a reject table |
| F7 Domain facts join `DimCustomer`, which only `Jobs/NightlyCore.sql` loads; no schedules define order across jobs | `Jobs/*.sql`, `usp_LoadDimCustomer` | Possible | significant | A domain fact load can run before customers are loaded and drop rows | Define the schedule/dependency; record it in the map |
| F8 Rerun of a fact load fails on the PK rather than being guarded; `usp_LoadFactSales_v2` writes its `ctl.LoadRun` row before the insert with no transaction | `usp_LoadFact*`, `usp_LoadFactSales_v2.sql` | Confirmed | significant | A rerun with the same staged rows errors; new rows in the same batch are blocked until staging is cleared; failed v2 reruns leave orphan run rows | Add an explicit guard; note this corrects the "double-load" wording in `FRAMEWORK-CONTEXT.md` |
| F9 `FactSales` has no `CurrencyCode`, unlike the repo's money convention, and `rpt.vwExecutiveSummary` sums `NetAmount` without a currency | `Tables/fact.FactSales.sql`, `rpt.vwExecutiveSummary.sql` | Possible | advisory | Mixed currencies could be summed if sales are multi-currency | Confirm Sales is single-currency |
| F10 Business grain is not stated in any fact DDL; row identity is only the staged `SourceId` and no unique business key is declared | the 63 `Tables/fact.*.sql` | Confirmed | advisory | A report author cannot tell whether two rows can describe the same business event | State each fact's grain in the map/DDL comments once confirmed with the team |

Drift from other docs: `FRAMEWORK-CONTEXT.md` hazard row 2 says fact loads risk "PK failure or double-load"; the PK makes a rerun fail (F8). `AGENTS.md` and ADR-001 otherwise agree with the code (85 dim and 65 fact procs; 64 of 65 fact loads use `stg.BatchId`).

## 7. Querying this warehouse

Rules for reading the warehouse, not loading it. They address the ways a report goes wrong quietly — producing a number, not an error.

1. **Start at the fact and state its grain** in one sentence before writing any SQL. If the grain is not clear (F10: no fact states it), that is the first thing to resolve.
2. **Reach an attribute by following a fact key to the dimension that owns it.** Never read it off a column that merely happens to sit on a table already in the join. A column that is declared in DDL but never populated by any load looks identical to a real one in a `SELECT` list and returns `NULL`s or blanks, not an error. Example here: `FactSales.RegionName`, `CategoryName`, `SegmentName` are never populated (F5); use `DimCustomer` (via `RegionKey` → `DimRegion`) and `DimProduct.CategoryName` instead.
3. **Use an existing reporting view's join path as a usage lead before inventing one.** It shows the path this warehouse uses, not that the result is correct. Freeze the report's applicable grain, temporal predicate, expected result, and tolerances before claiming correctness. If two views disagree, record that conflict in the edge list rather than picking one.
4. **Treat a same-named column on an already-joined table as suspect** until you know which table populates it. Same name is not same meaning, and it is not evidence of a relationship. Example: `CategoryName` exists on both `FactSales` and `DimProduct`; only the dim is populated by a load.
5. **Replicating a report from another warehouse: write the source-column → target-concept mapping before any SQL.** Same-named columns across two warehouses are the trap this rule exists for. Name what is unresolved and ask; do not substitute the nearest-looking column.
6. **Add an effective-date predicate only when the key does not already identify one version.** The discriminator is a property of the edge; the edge list records it as `version resolution`:
   - **`Pinned at load`** (every edge in this map): the load found the dimension version that applied and stamped that version's surrogate key onto the fact. Adding `EffectiveFrom`/`EffectiveTo`/`IsCurrent` to that join **silently drops every fact pointing at a superseded row.** The dangerous case: it yields a low row count, not an error, and in review the extra predicate reads as more careful rather than less. Note that "pinned" here means the version current at load time (`IsCurrent = 1`), not the version at the fact's business date.
   - **`Deferred to query`** (none in this map): the key does not pick a version on its own: a natural/business key, a durable key shared by every version row, or a run/version/snapshot register where several rows are live. The temporal predicate is then **required**; use the warehouse's own as-of rule, copied from a reporting view.
   - **`UNRESOLVED`** (none in this map): do not choose. Copy an existing view's join for that edge, or ask.
7. **Snapshot facts are not summed across dates.** Facts with the `Snapshot` suffix are periodic snapshots by name; aggregate a balance or level measure over one snapshot date (or take the last value per period), not with `SUM` over many dates (F4).

Two named path hazards:

- **Fan trap** — joining a chained one-to-many below the fact multiplies the fact rows and double-counts the measure. Aggregate at the fact's own grain, or aggregate the many-side separately before joining. No dim here declares a unique business key, so a dim with two rows for one id would fan a join out.
- **Chasm trap** — joining two facts directly through a shared dimension (e.g. DepositBalance Movement and Snapshot through `DimDepositBalance`, or any two facts through `DimCustomer` or `DimDate`) multiplies their rows within each shared key group and inflates both measures. Sharing a conformed dimension is legitimate drill-across: aggregate each fact to the shared grain independently first, then join the two aggregates on the shared keys.

If the map marks an edge `UNRESOLVED` or `CONFLICTING`, that is the map telling you it does not know — treat it as a question to ask, not a gap to fill with the most plausible-looking column.
