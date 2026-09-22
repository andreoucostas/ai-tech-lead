# Tech Debt Register

> One block per item. Sort by severity then effort. Reference items by ID in commit messages and PRs.

---

## DEBT-001: usp_LoadDimCustomer hardcodes surrogate key -1, breaking multi-row onboarding

- **Key**: dim.DimCustomer::hardcoded-surrogate-key
- **Category**: Data Access
- **Severity**: Critical
- **Effort**: S (<1hr)
- **Files**: `StoredProcedures/usp_LoadDimCustomer.sql:1`, `Tables/dim.DimCustomer.sql:2`

### Issue
`usp_LoadDimCustomer`'s `WHEN NOT MATCHED THEN INSERT` always inserts `CustomerKey = -1`. If a single batch contains more than one new `CustomerId`, the `MERGE` attempts to insert `-1` twice, violating the `CustomerKey` primary key and aborting the entire statement — confirmed hazard (`FRAMEWORK-CONTEXT.md > Known Hazard Areas`).

### Recommended fix
Generate a real surrogate key per new row (identity column, sequence, or `NEXT VALUE FOR`) instead of the literal `-1`. Low risk, high value — no callers depend on the current broken behavior.

---

## DEBT-002: Fact and region dimension loads are not idempotent / not safely re-runnable

- **Key**: loads::non-idempotent-rerun
- **Category**: Data Access
- **Severity**: Critical
- **Effort**: M (half day)
- **Files**: `StoredProcedures/usp_LoadFactSales.sql:1-7`, `StoredProcedures/usp_LoadDimRegion.sql:1`, `Tables/fact.FactSales.sql:2-3`, `Tables/dim.DimRegion.sql:1`

### Issue
`usp_LoadFactSales` does a blind `INSERT...SELECT` where `SalesKey` is a direct passthrough of `stg.StgSalesOrder.SalesId` — rerunning the same staging batch (e.g. after a partial failure or a manual retry) hits the `SalesKey` primary key and aborts the whole statement rather than being a no-op. `usp_LoadDimRegion` has the same problem: its `INSERT` always targets `RegionKey = -1`, so only the first run ever succeeds. Confirmed hazard.

### Recommended fix
Replace both blind inserts with `MERGE`/existence-checked upserts keyed on the real business key, so a rerun of the same batch is a safe no-op rather than a failure.

---

## DEBT-003: stg.StgSalesOrder has no primary key or unique constraint

- **Key**: stg.StgSalesOrder::no-unique-key
- **Category**: Data Access
- **Severity**: High
- **Effort**: S (<1hr)
- **Files**: `Tables/stg.StgSalesOrder.sql:1`

### Issue
The staging table declares no `PRIMARY KEY`/`UNIQUE` constraint on `SalesId` (or `SalesId, BatchId`), so duplicate staging rows for the same order can neither be prevented nor detected before they reach the fact load. Confirmed hazard.

### Recommended fix
Add a primary or unique key on `(SalesId)` or `(SalesId, BatchId)`, matching however the upstream feed guarantees (or fails to guarantee) row uniqueness.

---

## DEBT-004: usp_LoadFactSales silently drops rows with unmatched product/date dimension keys

- **Key**: fact.FactSales::silent-dimension-mismatch-drop
- **Category**: Data Access
- **Severity**: High
- **Effort**: M (half day)
- **Files**: `StoredProcedures/usp_LoadFactSales.sql:5-7`

### Issue
`usp_LoadFactSales` `INNER JOIN`s to `dim.DimProduct` and `dim.DimDate`. Any staging row whose `ProductId` or `OrderDate` doesn't already exist in those dimensions is silently excluded from the fact load — no reject table, no error, no row-count reconciliation to detect the loss. Confirmed hazard, independent of who populates `DimProduct`/`DimDate`.

### Recommended fix
Add a reject/exception table (or a row-count reconciliation check between `stg.StgSalesOrder` and the fact insert) so unmatched rows are visible instead of silently disappearing. Consider an "Unknown member" fallback key for the dimensions if losing rows is never acceptable.

---

## DEBT-005: No transaction wraps the dimension and fact load sequence

- **Key**: loads::no-transaction-wrap
- **Category**: Data Access
- **Severity**: High
- **Effort**: M (half day)
- **Files**: `StoredProcedures/usp_LoadDimCustomer.sql:1`, `StoredProcedures/usp_LoadDimRegion.sql:1`, `StoredProcedures/usp_LoadFactSales.sql:1-7`

### Issue
None of the three load procedures contain `BEGIN TRANSACTION`/`TRY`/`CATCH`, and nothing in the repo ties them together. If `usp_LoadFactSales` fails after the dimension loads succeeded, there is no rollback or compensation — dimensions and facts can end up inconsistent. Confirmed hazard.

### Recommended fix
Wrap the dimension loads and fact load in an explicit transaction (or have an orchestrator do so) with `TRY`/`CATCH`/`ROLLBACK` on failure.

---

## DEBT-006: SCD Type 2 declared on DimCustomer but not implemented

- **Key**: dim.DimCustomer::scd2-unimplemented
- **Category**: Data Access
- **Severity**: High
- **Effort**: M (half day)
- **Files**: `Tables/dim.DimCustomer.sql:6-8`, `StoredProcedures/usp_LoadDimCustomer.sql:1`

### Issue
`dim.DimCustomer` declares `EffectiveFrom`/`EffectiveTo`/`IsCurrent`, but `usp_LoadDimCustomer` has only a `WHEN NOT MATCHED THEN INSERT` branch — an existing customer's `SegmentName`/`RegionKey` change is never captured, `EffectiveTo` is never set, and no new version row is ever inserted. Confirmed as the intended design, not vestigial (see `docs/architecture-decisions.md#adr-002-dimcustomer-uses-scd-type-2`).

### Recommended fix
Add a `WHEN MATCHED AND <attributes changed> THEN` branch that closes out the current row (`EffectiveTo = SYSUTCDATETIME(), IsCurrent = 0`) and inserts a new current version. `usp_LoadFactSales` already joins on `IsCurrent = 1`, so the fact load needs no change once this lands.

---

## DEBT-007: No warehouse test or validation assets exist

- **Key**: warehouse-testing::no-test-assets
- **Category**: Testing
- **Severity**: High
- **Effort**: M (half day)
- **Files**: repo-wide (no `Tests/`, no `*.test.sql`, no tSQLt objects, no data-quality config)

### Issue
No tSQLt (or equivalent) test suite, no data-quality checks, no seed/fixture data, and no SQL lint/format configuration exist anywhere in this repo. None of the load/idempotency behavior identified above (DEBT-001, 002, 004, 005, 006) is protected by any executable check. `tests/evals/cases.yaml` and `tests/evals/README.md` are the AI Tech Lead framework's own eval fixtures (framework-owned per `framework-ownership.json`), not warehouse test coverage.

### Recommended fix
Introduce a tSQLt-based unit test suite covering each load procedure's upsert/idempotency behavior (rerun-safety in particular) and the three reporting views. This is a suite-bootstrap task — there is no existing warehouse test harness to extend, so the first tests establish the baseline harness. Surface this in the top-3 quick wins.

---

## DEBT-008: No CI/build pipeline evidenced for warehouse.sqlproj

- **Key**: warehouse.sqlproj::no-ci-pipeline
- **Category**: Architecture
- **Severity**: Medium
- **Effort**: M (half day)
- **Files**: `warehouse.sqlproj`, `.github/workflows/`

### Issue
`warehouse.sqlproj` sets no `<SqlServerVersion>`/target platform, no publish profile, and no `SqlCmdVariables`. No CI workflow builds, deploys, or validates it — the repo's only workflow (`docs-sync-check.yml`) is framework tooling and never touches the SQL project.

### Recommended fix
Add a CI step that builds the SQL project (`dotnet build warehouse.sqlproj`, once a target platform is set) so schema errors are caught before merge; add a publish profile once a deploy target is agreed.

---

## DEBT-009: ctl.LoadRun watermark control table declared but unused

- **Key**: ctl.LoadRun::unused-watermark-control
- **Category**: Data Access
- **Severity**: Medium
- **Effort**: L (1-2 days)
- **Files**: `Tables/ctl.LoadRun.sql:1`, `StoredProcedures/usp_LoadFactSales.sql:2-3`

### Issue
`ctl.LoadRun` exists to support future batch/watermark-driven incremental loading (confirmed intent, see `docs/architecture-decisions.md#adr-003-ctlloadrun-reserved-for-incremental-loading`), but no procedure reads or writes it. Every run reprocesses the entire staging table with no parameterized batch/watermark scoping. `fact.FactSales.LoadRunId` is populated from `stg.StgSalesOrder.BatchId` instead, an unrelated value.

### Recommended fix
When incremental loading is prioritized: have each load procedure insert a `LoadRunId`/`StartedAt` row into `ctl.LoadRun` at the start of a run, scope the staging read by `Watermark`, and use the real `ctl.LoadRun.LoadRunId` (not `BatchId`) to populate `fact.FactSales.LoadRunId`.

---

## DEBT-010: FactSales denormalized reporting columns never populated

- **Key**: fact.FactSales::unpopulated-denormalized-columns
- **Category**: Data Access
- **Severity**: Low
- **Effort**: S (<1hr)
- **Files**: `Tables/fact.FactSales.sql:7-9`, `StoredProcedures/usp_LoadFactSales.sql:2-3`

### Issue
`fact.FactSales` declares nullable `RegionName`, `CategoryName`, `SegmentName` columns, but `usp_LoadFactSales`'s `INSERT` column list omits them — they are always `NULL`. `rpt.vwFinanceExtract` already works around this by re-deriving `RegionName` via a join instead of reading the fact column, so no consumer is currently broken by the gap, but it is dead schema surface a future query could silently rely on and get `NULL`s from.

### Recommended fix
Either populate the three columns in `usp_LoadFactSales` from the already-joined dimensions (`DimRegion` would need to be joined too, since it currently is not), or drop the columns if the denormalized-column strategy is not intended.

---

## DEBT-011: No foreign key constraints declared on any warehouse table

- **Key**: warehouse-schema::no-foreign-keys
- **Category**: Data Access
- **Severity**: Low
- **Effort**: S (<1hr)
- **Files**: `Tables/fact.FactSales.sql`, `Tables/dim.DimCustomer.sql`

### Issue
None of the six tables declare a `FOREIGN KEY` — relationship integrity between `fact.FactSales` and its dimensions (and between `dim.DimCustomer` and `dim.DimRegion`) is enforced only by the load procedures' join logic, not by the schema itself.

### Recommended fix
Add `FOREIGN KEY` constraints from `fact.FactSales` to `DimCustomer`/`DimProduct`/`DimDate`, and from `DimCustomer` to `DimRegion`, once the surrogate-key generation issues (DEBT-001, DEBT-002) are fixed (constraints would currently be violated by the placeholder `-1` keys).

---

## DEBT-012: DimRegion sourced from a hardcoded placeholder pending a real region feed

- **Key**: dim.DimRegion::hardcoded-placeholder-region
- **Category**: Data Access
- **Severity**: Low
- **Effort**: M (half day)
- **Files**: `StoredProcedures/usp_LoadDimRegion.sql:1`, `StoredProcedures/usp_LoadDimCustomer.sql:1`, `Tables/stg.StgSalesOrder.sql:1`

### Issue
`stg.StgSalesOrder` carries no region attribute at all, so `usp_LoadDimRegion` and `usp_LoadDimCustomer` both hardcode region to `-1`/`'Unknown'`. Confirmed as a known, expected-for-now placeholder (a real region source is planned but not yet wired into staging) — not an oversight to silently "fix" by inventing a region source.

### Recommended fix
When a real region source is identified, add the column to `stg.StgSalesOrder` (or a mapping table) and replace the hardcoded values in both procedures. Track readiness against the upstream feed, not against this repo alone.

---

## Dismissed proposals — do not re-propose without materially changed evidence

| Key | Affected paths / symbols | Evidence reviewed | Dismissed | Reason |
|-----|--------------------------|-------------------|-----------|--------|
| _(none)_ | _ | _ | _ | _ |

---

## Trojan Horse Opportunities

Group DEBT IDs by feature area so developers can bundle cleanup into feature work:

- **Sales load pipeline**: DEBT-001, DEBT-002, DEBT-003, DEBT-004, DEBT-005, DEBT-006
- **Warehouse tooling**: DEBT-007, DEBT-008, DEBT-011
- **Incremental loading**: DEBT-009
- **Reporting/enrichment**: DEBT-010, DEBT-012
