# Tech Debt Register

> One block per item. Sort by severity then effort. Reference items by ID in commit messages and PRs.

---

## DEBT-001: No tests or validation for any SQL load

- **Key**: testing::no-sql-validation
- **Category**: Testing
- **Severity**: High
- **Effort**: XL (needs spike)
- **Files**: `warehouse.sqlproj`, `StoredProcedures/`

### Issue
No SQL unit, data-quality or reconciliation assets and no CI for the warehouse exist (W3). The 150 load procs are unverified.

### Recommended fix
Spike a SQL test harness (e.g. tSQLt or a SQL-project test step) starting with rerun, unmatched-dim and unknown-member cases; commit its command so Verification Commands can record it.

---

## DEBT-002: Dimension loads insert only an Unknown row

- **Key**: dim-load::unknown-only
- **Category**: Data Access
- **Severity**: High
- **Effort**: XL (needs spike)
- **Files**: `StoredProcedures/usp_LoadDimDepositBalance.sql:1`, `StoredProcedures/usp_LoadDimCustomer.sql:1`, `StoredProcedures/usp_LoadDimRegion.sql:1`

### Issue
All 85 `usp_LoadDim*` procs hard-code key `-1` and `'Unknown'`; real members and surrogate keys are never loaded, and a second distinct insert would violate the PK. Status: developer did not confirm (see hazard row).

### Recommended fix
Confirm whether these are stubs; if so, implement real member loads with surrogate-key generation and SCD handling per dimension.

---

## DEBT-003: Fact loads are not re-runnable and drop unmatched rows

- **Key**: fact-load::no-rerun-guard
- **Category**: Data Access
- **Severity**: High
- **Effort**: L (1-2 days)
- **Files**: `StoredProcedures/usp_LoadFactDepositBalanceMovement.sql:1-6`, `StoredProcedures/usp_LoadFactSales.sql:1-8`

### Issue
Plain INSERT from staging with no `NOT EXISTS`/batch guard and inner joins that silently drop rows lacking a dim match; a rerun fails on the PK or double-loads.

### Recommended fix
Add a batch/`ctl.LoadRun` guard and route unmatched rows to the Unknown member or a reject table; apply via the `add-warehouse-load` skill pattern.

---

## DEBT-004: Three competing FactSales loaders; incremental watermark is fragile

- **Key**: sales-load::duplicate-variants
- **Category**: Architecture
- **Severity**: Medium
- **Effort**: M (half day)
- **Files**: `StoredProcedures/usp_LoadFactSales.sql`, `StoredProcedures/usp_LoadFactSalesIncremental.sql:3-13`, `StoredProcedures/usp_LoadFactSales_v2.sql:3-4`

### Issue
Only `usp_LoadFactSales` is scheduled. The incremental proc computes `LoadRunId` as `MAX+1` without locking, sets the watermark to `MAX(OrderDate)` of all staging, and filters `OrderDate > @Watermark` (skips late same-date rows).

### Recommended fix
Retire the unused variants or fix and schedule one; use a sequence for `LoadRunId` and set the watermark from loaded rows.

---

## DEBT-005: Jobs have no schedule or failure handling

- **Key**: orchestration::no-schedule-no-failure-handling
- **Category**: Architecture
- **Severity**: Medium
- **Effort**: M (half day)
- **Files**: `Jobs/NightlyCore.sql:1-5`, `Jobs/TreasuryAccrualDaily.sql`

### Issue
None of the 43 job scripts calls `sp_add_jobschedule` or sets step failure behaviour, and no proc uses TRY/CATCH or a transaction, so a mid-job failure leaves partial loads. Scheduling may live outside the repo (unconfirmed).

### Recommended fix
Confirm where scheduling lives; add `@on_fail_action` and transactional proc bodies.

---

## DEBT-006: Unpopulated denormalized columns on FactSales

- **Key**: fact-sales::unused-columns
- **Category**: Architecture
- **Severity**: Low
- **Effort**: S (<1hr)
- **Files**: `Tables/fact.FactSales.sql`, `StoredProcedures/usp_LoadFactSales.sql:2`

### Issue
`RegionName`, `CategoryName`, `SegmentName` are nullable and omitted from every Sales load INSERT list.

### Recommended fix
Confirm they are unused and drop them, or populate them.

---

## Dismissed proposals — do not re-propose without materially changed evidence

> These are reviewed claims the team determined are not debt. Keep every row for auditability.
> A later scan may reopen one only by naming the concrete evidence delta in a new active item.

| Key | Affected paths / symbols | Evidence reviewed | Dismissed | Reason |
|-----|--------------------------|-------------------|-----------|--------|
| _(none)_ | _ | _ | _ | _ |

---

## Trojan Horse Opportunities

- **Sales**: DEBT-003, DEBT-004, DEBT-006
- **Dimensions**: DEBT-002
- **Orchestration/testing**: DEBT-001, DEBT-005
