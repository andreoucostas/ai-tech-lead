# Tech Debt Register

> One block per item. Sort by severity then effort. Reference items by ID in commit messages and PRs.
> Run `/debt [area]` to find and fix items. Run `/docs-sync` to check for staleness.

---

## DEBT-005: `usp_LoadDimRegion` inserts one `-1` row per staging row

- **Key**: warehouse-dim-load::region-duplicate-key
- **Category**: Data Access
- **Severity**: High
- **Effort**: S (<1hr)
- **Files**: `StoredProcedures/usp_LoadDimRegion.sql:1`

### Issue
`INSERT … SELECT DISTINCT -1, 'Unknown' FROM stg.StgSalesOrder` has no existence guard and a literal key. Every rerun, and any run with a row in staging after the first, violates the `DimRegion` primary key. This breaks step 2 of `Jobs/NightlyCore.sql`.

### Recommended fix
Decide the region key source and guard by business key (`NOT EXISTS` or `MERGE`). Needs the intended dimension design from DEBT-001.

---

## DEBT-001: Dimension loads are placeholder inserts; no SCD is implemented

- **Key**: warehouse-dim-load::literal-key-no-scd
- **Category**: Data Access
- **Severity**: High
- **Effort**: XL (needs spike)
- **Files**: `StoredProcedures/usp_LoadDimCustomer.sql:1`, `Tables/dim.DimCustomer.sql:2-8`, `StoredProcedures/usp_LoadDimCardFacility.sql:1`

### Issue
About 430 `usp_LoadDim*` procedures `MERGE … WHEN NOT MATCHED` and insert surrogate key `-1` with `'Unknown'` attributes. Dimension keys are `INT PRIMARY KEY` with no IDENTITY or SEQUENCE, so a second new member collides. There is no `WHEN MATCHED` branch, so `EffectiveTo` and `IsCurrent` are never maintained despite SCD2-shaped columns, and facts join `IsCurrent = 1`.

### Recommended fix
Spike first: confirm the intended strategy per dimension (SCD1/SCD2), then add key generation and a matched branch. Do not copy the current shape into new loads. Large blast radius: ~430 procedures.

---

## DEBT-002: Fact loads have no rerun guard, run record, or drop accounting

- **Key**: warehouse-fact-load::no-idempotency
- **Category**: Data Access
- **Severity**: High
- **Effort**: XL (needs spike)
- **Files**: `StoredProcedures/usp_LoadFactSales.sql:2-7`, `StoredProcedures/usp_LoadFactPayrollOverdraftSnapshot.sql:2-8`, `StoredProcedures/usp_LoadFactCardFacilityMovement.sql`

### Issue
Subject-area fact loads (about 1,100 by W2's grep count) are bare `INSERT…SELECT` keyed on the source id. A rerun fails on the primary key. Inner joins drop staging rows with no dimension match without a count or log, and `LoadRunId` is copied from `s.BatchId` with no `ctl.LoadRun` row. Staging is read in full on every run (no `BatchId` filter).

### Recommended fix
Define the rerun contract (staging cleared externally vs. watermark/batch-scoped loads), then add a guard and an unmatched-row count. Needs the staging process, which is outside this repo.

---

## DEBT-004: No tests, data-quality checks, lint, or CI for the warehouse

- **Key**: warehouse-testing::no-validation-assets
- **Category**: Testing
- **Severity**: High
- **Effort**: XL (needs spike)
- **Files**: `warehouse.sqlproj`

### Issue
W3 found no SQL unit tests, reconciliation or data-quality scripts, fixtures, seed data, lint/format config, or consumer CI. `warehouse.sqlproj` is the only build artifact and no committed command builds it. No check detects a broken load.

### Recommended fix
Choose a SQL test/validation approach and a build command, record them in `AGENTS.md > Verification Commands`, and start with row-count and rerun checks on `NightlyCore`. Do not assume a tool before the team picks one.

---

## DEBT-003: `usp_LoadFactSales_*` variant sprawl and racy run-id allocation

- **Key**: warehouse-fact-load::factsales-variants
- **Category**: Architecture
- **Severity**: Medium
- **Effort**: M (half day)
- **Files**: `StoredProcedures/usp_LoadFactSales_v3.sql:3-4`, `StoredProcedures/usp_LoadFactSales_Merge.sql`, `StoredProcedures/usp_LoadFactSales_Restartable.sql`, `Jobs/NightlyCore.sql:4`, `Tables/ctl.LoadRun.sql:1`

### Issue
About 23 near-duplicate variants of one load exist (several byte-identical, e.g. `_2019` and `_Restartable`; `_Reload`/`_Retry` reload and retry nothing). Only `usp_LoadFactSales` is referenced by a job. Variants allocate `MAX(LoadRunId)+1` against a plain primary key (concurrent runs collide), `_Merge` mixes `SYSDATETIME()` with `SYSUTCDATETIME()`, and the watermark compares `DATE` to `DATETIME2` and advances to the staging maximum. `fact.FactSales` has `RegionName`, `CategoryName`, `SegmentName` that no loader populates.

### Recommended fix
Confirm no external caller exists, keep one variant, delete the rest, and allocate run ids with a sequence or identity.

---

## Dismissed proposals — do not re-propose without materially changed evidence

| Key | Affected paths / symbols | Evidence reviewed | Dismissed | Reason |
|-----|--------------------------|-------------------|-----------|--------|
| _(none)_ | _ | _ | _ | _ |

---

## Trojan Horse Opportunities

- **Sales core (`NightlyCore`)**: DEBT-001, DEBT-002, DEBT-003, DEBT-005
- **Any subject-area load change**: DEBT-001, DEBT-002
- **Tooling / CI**: DEBT-004
