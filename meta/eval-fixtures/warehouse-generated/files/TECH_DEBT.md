# Tech Debt Register

> One block per item. Sort by severity then effort. Reference items by ID in commit messages and PRs.

---

## DEBT-001: Customer and region loads are not re-runnable and cannot load real data

- **Key**: load::dim-loads-placeholder
- **Category**: Data Access
- **Severity**: High
- **Effort**: L (1-2 days)
- **Files**: `StoredProcedures/usp_LoadDimCustomer.sql:1`, `StoredProcedures/usp_LoadDimRegion.sql:1`

### Issue
Both procs insert the constants `-1` / `'Unknown'` as the surrogate key and attributes. A second new customer (or a second region run) violates the primary key. `usp_LoadDimCustomer` handles only `WHEN NOT MATCHED`, so changed attributes never close out `EffectiveTo`/`IsCurrent` and SCD2 history cannot form. Staging has no region or segment columns, so real values cannot flow either.

### Recommended fix
Confirm intended source of region/segment, generate real surrogate keys, make the loads idempotent, and implement SCD2 close-and-insert for `DimCustomer`. Use `add-warehouse-load` once the pattern is agreed.

---

## DEBT-002: No rerun or double-load protection; control table unused

- **Key**: load::no-idempotency-control
- **Category**: Data Access
- **Severity**: High
- **Effort**: M (half day)
- **Files**: `StoredProcedures/usp_LoadFactSales.sql:2-7`, `Tables/ctl.LoadRun.sql:1`, `Tables/stg.StgSalesOrder.sql:1`

### Issue
`usp_LoadFactSales` has no `NOT EXISTS`, batch, or watermark guard, so a rerun of the same staging data fails on the `SalesKey` primary key. `ctl.LoadRun` (`LoadRunId`, `Watermark`) is never read or written, and `FactSales.LoadRunId` is taken straight from staging `BatchId` without validation.

### Recommended fix
Decide the rerun mechanism (batch id vs watermark), register each run in `ctl.LoadRun`, and make loads skip or replace already-loaded batches.

---

## DEBT-003: Fact load silently drops unmatched rows; Product and Date have no loader

- **Key**: load::fact-inner-join-drops-rows
- **Category**: Data Access
- **Severity**: High
- **Effort**: M (half day)
- **Files**: `StoredProcedures/usp_LoadFactSales.sql:5-7`, `Tables/dim.DimProduct.sql:1`, `Tables/dim.DimDate.sql:1`

### Issue
The fact load uses inner joins to customer, product and date, so any staged row without a matching dimension row disappears with no error or reject record. No proc in the repo loads `DimProduct` or `DimDate`, so the fact load depends on loads that are not here.

### Recommended fix
Add (or locate) the Product/Date loads, and route unmatched rows to a reject/unknown-member path with a row-count reconciliation.

---

## DEBT-004: No tests, validation or build/CI for the warehouse

- **Key**: testing::no-warehouse-validation
- **Category**: Testing
- **Severity**: High
- **Effort**: XL (needs spike)
- **Files**: `warehouse.sqlproj`

### Issue
No SQL tests, data-quality or reconciliation checks, lint/format config, or SQL build/deploy pipeline are committed. The only workflow is the framework's docs-sync check, so none of the load defects above are caught automatically.

### Recommended fix
Choose a validation approach (for example a build of the SQL project in CI plus load/reconcile checks against a scratch database), then record the commands in `AGENTS.md > Verification Commands`.

---

## DEBT-005: Fact denormalized columns never populated; finance extract region is always Unknown

- **Key**: reporting::fact-denorm-unpopulated
- **Category**: Architecture
- **Severity**: Medium
- **Effort**: M (half day)
- **Files**: `Tables/fact.FactSales.sql:6-8`, `StoredProcedures/usp_LoadFactSales.sql:2`, `Views/rpt.vwFinanceExtract.sql:2-6`

### Issue
`RegionName`, `CategoryName` and `SegmentName` on `FactSales` are nullable and never written by the load. `rpt.vwFinanceExtract` derives region through `DimCustomer.RegionKey`, which the current customer load always sets to `-1`, so every row reports the Unknown region.

### Recommended fix
Decide whether the denormalized columns stay (and populate them) or are dropped; fix after the customer/region loads (DEBT-001).

---

## DEBT-006: Procs live in `dbo`; no foreign keys or staging uniqueness

- **Key**: schema::missing-constraints
- **Category**: Architecture
- **Severity**: Low
- **Effort**: M (half day)
- **Files**: `Tables/fact.FactSales.sql:1-10`, `Tables/stg.StgSalesOrder.sql:1`

### Issue
No foreign keys link `FactSales` to dimensions or `DimCustomer` to `DimRegion`, and `StgSalesOrder.SalesId` has no uniqueness, so duplicate staged rows surface only as primary-key failures at fact load. Load procs are in `dbo` rather than a layer schema. Whether this is deliberate (warehouse convention) was not confirmed.

### Recommended fix
Confirm intent; if unintended, add constraints (or documented NOCHECK ones) and move procs to a `ctl`/`etl` schema.

---

## Dismissed proposals — do not re-propose without materially changed evidence

| Key | Affected paths / symbols | Evidence reviewed | Dismissed | Reason |
|-----|--------------------------|-------------------|-----------|--------|
| _(none)_ | _ | _ | _ | _ |

---

## Trojan Horse Opportunities

- **Customer / region dimensions**: DEBT-001, DEBT-005, DEBT-006
- **Fact load**: DEBT-002, DEBT-003
- **Validation / CI**: DEBT-004
