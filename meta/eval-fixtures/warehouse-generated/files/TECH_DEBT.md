# Tech Debt Register

> One block per item. Sort by severity then effort. Reference items by ID in commit messages and PRs.

---

## DEBT-001: usp_LoadDimCustomer hardcodes the surrogate key for new customers

- **Key**: warehouse-load::dimcustomer-key-collision
- **Category**: Load Correctness
- **Severity**: Critical
- **Effort**: M (half day)
- **Files**: `StoredProcedures/usp_LoadDimCustomer.sql:1`, `Tables/dim.DimCustomer.sql:2`

### Issue
`usp_LoadDimCustomer`'s `MERGE ... WHEN NOT MATCHED THEN INSERT` inserts the literal constant `CustomerKey = -1` for every unmatched customer. `CustomerKey` is `dim.DimCustomer`'s `PRIMARY KEY`, so a staging batch containing more than one distinct new `CustomerId` would attempt two inserts with the same key and fail with a primary-key violation on the second.

### Recommended fix
Derive a real surrogate key (identity column, sequence, or `MAX(CustomerKey)+1` pattern) instead of the literal `-1`, and add a `WHEN MATCHED` branch that closes the prior row (`EffectiveTo`, `IsCurrent = 0`) and inserts a new version when a tracked attribute changes — the table's `EffectiveFrom`/`EffectiveTo`/`IsCurrent` columns already imply SCD2, but no update path exists today.

---

## DEBT-002: usp_LoadFactSales has no idempotency or watermark guard

- **Key**: warehouse-load::factsales-no-watermark
- **Category**: Load Correctness
- **Severity**: Critical
- **Effort**: M (half day)
- **Files**: `StoredProcedures/usp_LoadFactSales.sql:1-7`, `Tables/ctl.LoadRun.sql:1`, `Tables/fact.FactSales.sql:3`

### Issue
`usp_LoadFactSales` is a plain `INSERT ... SELECT` with no existence check, watermark filter, or batch guard. `ctl.LoadRun` declares `LoadRunId`/`StartedAt`/`Watermark` columns that imply incremental-load control, but no procedure in the repo reads or writes `ctl.LoadRun` — confirmed dead by repo-wide grep. Re-running the load over a staging batch that was already loaded (e.g., after a partial failure) reinserts the same `SalesKey` values and violates `fact.FactSales`'s `PRIMARY KEY`.

### Recommended fix
Either wire `ctl.LoadRun` into the load (write a row per run, filter staging by a watermark/batch id not yet processed) or add a simpler guard (`WHERE NOT EXISTS` against `fact.FactSales.SalesKey`, or `MERGE`) so a rerun is safe. Pick one mechanism — `AGENTS.md > Conventions` should name whichever is adopted, so it isn't selected ad hoc the next time a load is added.

---

## DEBT-003: usp_LoadDimRegion is not idempotent and has no real region source

- **Key**: warehouse-load::dimregion-not-idempotent
- **Category**: Load Correctness
- **Severity**: Critical
- **Effort**: XL (needs spike)

### Issue
`usp_LoadDimRegion` is `INSERT INTO dim.DimRegion (RegionKey, RegionName) SELECT DISTINCT -1, 'Unknown' FROM stg.StgSalesOrder` — no existence guard, so running it twice violates the `PRIMARY KEY` on `RegionKey`. More fundamentally, `stg.StgSalesOrder` carries no region attribute at all (confirmed by reading its full column list), so there is currently no path to load a real region — every run can only ever produce the same placeholder row. This blocks `dim.DimCustomer.RegionKey` (also hardcoded `-1` in DEBT-001) and therefore `rpt.vwFinanceExtract`'s region breakdown from ever reflecting real data.

### Recommended fix
This needs a source decision, not just a guard: identify where real region data should come from (a customer master/reference feed, most likely, since region is a customer attribute in this model) before the load logic can be fixed. Add the idempotency guard regardless, but treat "no region source exists" as the primary blocker — a spike to locate or define that source should come first.

---

## DEBT-004: dim.DimProduct has no load procedure

- **Key**: warehouse-load::dimproduct-missing-load
- **Category**: Load Correctness
- **Severity**: High
- **Effort**: M (half day)
- **Files**: `Tables/dim.DimProduct.sql`, `StoredProcedures/usp_LoadFactSales.sql:6`

### Issue
`usp_LoadFactSales` inner-joins `dim.DimProduct` on `ProductId`, but no `usp_LoadDimProduct` (or equivalent) exists anywhere in the repository to populate that table. Confirmed by globbing `StoredProcedures/**` — only three procedures exist, none for `DimProduct` or `DimDate`. Until `dim.DimProduct` is populated by some other, unevidenced mechanism, the fact load's `INNER JOIN` silently drops every staging row with no error.

### Recommended fix
Add `usp_LoadDimProduct`, following whichever key-generation and rerun-safety fix is adopted for DEBT-001/DEBT-003, so the pattern is consistent across all dimension loads.

---

## DEBT-005: No warehouse test or validation assets exist

- **Key**: warehouse-testing::no-validation-assets
- **Category**: Testing
- **Severity**: High
- **Effort**: L (1-2 days)

### Issue
The repository has no tSQLt tests, dbt tests, data-quality scripts, or any other validation tooling for the warehouse objects (confirmed by glob/grep — no test folder, no `tSQLt`/`dbt_project.yml` reference anywhere). Given the correctness issues in DEBT-001–004, there is currently no automated way to catch a regression in any load procedure.

### Recommended fix
Introduce a minimal SQL validation harness appropriate to this stack — for example tSQLt unit tests around each load procedure's merge/insert logic, or a lighter-weight data-quality script that checks referential integrity (every fact row resolves to a current dimension row) and row-count reconciliation between `stg` and `fact` per run. Do not reach for a .NET test framework or tool — nothing in this repository evidences one.

---

## DEBT-006: fact.FactSales carries denormalized columns that nothing populates or reads

- **Key**: warehouse-model::factsales-dead-columns
- **Category**: Data Modeling
- **Severity**: Medium
- **Effort**: S (<1hr)
- **Files**: `Tables/fact.FactSales.sql:7-9`, `StoredProcedures/usp_LoadFactSales.sql:2-3`

### Issue
`fact.FactSales` declares `RegionName`, `CategoryName`, and `SegmentName` as nullable denormalized columns, but `usp_LoadFactSales`'s `INSERT` column list omits all three, so they are permanently `NULL`. All three reporting views (`rpt.vwExecutiveSummary`, `rpt.vwFinanceExtract`, `rpt.vwOrderDetail`) independently re-derive the same attributes by joining the dimension tables directly rather than reading these columns — confirmed by reading every view. The columns have zero producers and zero consumers.

### Recommended fix
Drop the three columns unless there's a specific reporting-performance reason to denormalize them (in which case wire them into `usp_LoadFactSales`'s `INSERT` and have the views read them instead of re-joining). Carrying unused nullable columns invites a future reader to assume they're populated.

---

## DEBT-007: dim.DimDate has no evidenced generation mechanism

- **Key**: warehouse-load::dimdate-no-generation
- **Category**: Load Correctness
- **Severity**: Medium
- **Effort**: S (<1hr)
- **Files**: `Tables/dim.DimDate.sql`

### Issue
Like `dim.DimProduct`, `dim.DimDate` has no corresponding load/generation procedure in the repo. Date dimensions are often seeded once by a static generation script rather than an incremental load, but no such script exists here either (confirmed by glob) — it's unclear whether this table is expected to be seeded externally or is simply unpopulated.

### Recommended fix
Add a date-dimension generation script (a one-time or idempotent calendar-row generator) under the repo's own load pattern, or document where/how it is actually seeded if that happens outside this repository.

---

## DEBT-008: No evidenced build, test, lint, or deploy command for the warehouse project

- **Key**: warehouse-deploy::no-evidenced-commands
- **Category**: Deployment
- **Severity**: Medium
- **Effort**: S (<1hr)
- **Files**: `warehouse.sqlproj`

### Issue
No committed CI workflow, script, or documented command builds, tests, lints, or deploys `warehouse.sqlproj` (confirmed by glob/grep — no `*.publish.xml`, no `Scripts/` pre/post-deployment folder, no `sqlpackage`/`dacpac` reference, no warehouse-specific CI workflow). See `AGENTS.md > Conventions > Verification Commands`, which records all six categories as not available for this reason.

### Recommended fix
Add a CI step that at minimum builds the project (the `Microsoft.Build.Sql` SDK supports a standard `dotnet build` once a build command is actually wired into committed CI) and, once DEBT-005 adds a validation harness, runs it. Until a command is committed, treat any build/deploy as manual/CI-only.

---

## Dismissed proposals — do not re-propose without materially changed evidence

> These are reviewed claims the team determined are not debt. Keep every row for auditability.
> A later scan may reopen one only by naming the concrete evidence delta in a new active item.

| Key | Affected paths / symbols | Evidence reviewed | Dismissed | Reason |
|-----|--------------------------|-------------------|-----------|--------|
| _(none)_ | _ | _ | _ | _ |

---

## Trojan Horse Opportunities

Group DEBT IDs by feature area so developers can bundle cleanup into feature work:

- **Customer & Region Dimension Loads**: DEBT-001, DEBT-003
- **Fact Load & Rerun Safety**: DEBT-002, DEBT-004
- **Warehouse Delivery & Validation**: DEBT-005, DEBT-007, DEBT-008
- **Data Modeling**: DEBT-006
