# Tech Debt Register

> One block per item. Sort by severity then effort. Reference items by ID in commit messages and PRs.
> Run `/debt [area]` to find and fix items. Run `/docs-sync` to check for staleness.

---

## DEBT-001: DimCustomer load inserts a fixed -1 key and never versions

- **Key**: dim-customer-load::fixed-key-no-scd
- **Category**: Data Access
- **Severity**: Critical
- **Effort**: M (half day)
- **Files**: `StoredProcedures/usp_LoadDimCustomer.sql:1`, `Tables/dim.DimCustomer.sql:3`

### Issue
The `MERGE` has only `WHEN NOT MATCHED` and inserts every new customer with `CustomerKey = -1`, `RegionKey = -1` and segment `'Unknown'`. `CustomerKey` is the primary key, so a second new customer fails; changes to existing customers are ignored and `EffectiveTo`/`IsCurrent` are never maintained.

### Recommended fix
Generate surrogate keys, take region/segment from source, and add `WHEN MATCHED` close-out plus new-version insert if SCD2 is intended (confirm intent first). Use the `add-warehouse-load` skill.

---

## DEBT-002: DimRegion load is non-rerunnable and loads no real regions

- **Key**: dim-region-load::constant-row-no-rerun
- **Category**: Data Access
- **Severity**: High
- **Effort**: S (<1hr)
- **Files**: `StoredProcedures/usp_LoadDimRegion.sql:1`, `Tables/dim.DimRegion.sql:1`

### Issue
`SELECT DISTINCT -1, 'Unknown'` inserts the same row on every run, violating the primary key on the second run, and no actual region is ever loaded.

### Recommended fix
Seed the unknown member once (guarded) and load real regions from source with a business-key match; needs a region source in staging.

---

## DEBT-003: FactSales load has no rerun guard and drops rows silently

- **Key**: fact-sales-load::no-idempotency-inner-joins
- **Category**: Data Access
- **Severity**: High
- **Effort**: M (half day)
- **Files**: `StoredProcedures/usp_LoadFactSales.sql:1`, `Tables/fact.FactSales.sql:14`

### Issue
A plain `INSERT … SELECT` from staging with no watermark, batch filter or de-duplication: a rerun fails on `SalesKey` or double-loads. Inner joins to the dimensions drop unmatched rows without any count or error. `RegionName`, `CategoryName` and `SegmentName` on the fact are never populated.

### Recommended fix
Make the load keyed by batch/watermark (see DEBT-007), reconcile staged vs loaded counts, route orphans to an unknown member or reject table, and drop or populate the denormalised columns.

---

## DEBT-004: No load for DimProduct or DimDate

- **Key**: dim-product-date::no-load-procedure
- **Category**: Architecture
- **Severity**: High
- **Effort**: M (half day)
- **Files**: `Tables/dim.DimProduct.sql:1`, `Tables/dim.DimDate.sql:1`, `Jobs/NightlyCore.sql:1`

### Issue
Neither dimension has a load procedure or job step, yet `usp_LoadFactSales` inner-joins both; with empty tables the fact load succeeds with zero rows and no error. Whether they are loaded outside this repo is unverified.

### Recommended fix
Confirm where they are populated; add loads (or a date-seed script) and job steps before the fact load.

---

## DEBT-005: Nightly job has no failure handling, schedule or run record

- **Key**: nightly-job::no-failure-handling
- **Category**: Architecture
- **Severity**: Medium
- **Effort**: S (<1hr)
- **Files**: `Jobs/NightlyCore.sql:1`

### Issue
Steps are defined without `on_fail_action`, retry settings, a schedule (`sp_add_jobschedule`) or any `ctl.LoadRun` entry, so a failed dimension step is not clearly distinguished from success for the fact step and nothing records the run.

### Recommended fix
Set explicit `on_success_action`/`on_fail_action` per step, add a schedule, and write a `ctl.LoadRun` row per run.

---

## DEBT-006: No warehouse tests or data-validation assets

- **Key**: warehouse-testing::no-validation-assets
- **Category**: Testing
- **Severity**: High
- **Effort**: L (1-2 days)
- **Files**: `warehouse.sqlproj`, `tests/evals/README.md`

### Issue
The repository has no SQL tests, data-quality checks, seed data, lint or build CI; `tests/evals` documents framework rules only. The defects in DEBT-001 to DEBT-003 would not be caught.

### Recommended fix
Add a rerunnable validation script per load (key uniqueness, orphan-free joins, rerun produces no change) against seed data, and a CI build of `warehouse.sqlproj` once a command is agreed.

---

## DEBT-007: ctl.LoadRun is unused

- **Key**: load-control::loadrun-unused
- **Category**: Architecture
- **Severity**: Medium
- **Effort**: M (half day)
- **Files**: `Tables/ctl.LoadRun.sql:1`, `StoredProcedures/usp_LoadFactSales.sql:1`

### Issue
`ctl.LoadRun` (with `Watermark`) is defined but no procedure or job step reads or writes it; `FactSales.LoadRunId` takes `stg.BatchId` with no relationship to it. The schemas (`stg`, `dim`, `fact`, `ctl`, `rpt`) also have no `CREATE SCHEMA` file in the repo.

### Recommended fix
Decide the control model (run row per batch, watermark advance on success), wire it into the loads and the job, and add schema DDL if the project does not otherwise create them.

---

## Dismissed proposals — do not re-propose without materially changed evidence

| Key | Affected paths / symbols | Evidence reviewed | Dismissed | Reason |
|-----|--------------------------|-------------------|-----------|--------|
| _(none)_ | _ | _ | _ | _ |

---

## Trojan Horse Opportunities

- **Customer / region dimensions**: DEBT-001, DEBT-002
- **Sales fact and load control**: DEBT-003, DEBT-007
- **Orchestration**: DEBT-004, DEBT-005
- **Validation**: DEBT-006
