# Tech Debt Register

> One block per item. Sort by severity then effort. Reference items by ID in commit messages and PRs.

---

## DEBT-001: usp_LoadDimRegion is not rerunnable

- **Key**: warehouse-load::region-load-not-idempotent
- **Category**: Load Correctness
- **Severity**: Critical
- **Effort**: S (<1hr)
- **Files**: `StoredProcedures/usp_LoadDimRegion.sql`, `Tables/dim.DimRegion.sql`

### Issue
`dbo.usp_LoadDimRegion` is a bare `INSERT INTO dim.DimRegion (RegionKey, RegionName) SELECT
DISTINCT -1, 'Unknown' FROM stg.StgSalesOrder` — no `MERGE`, no `NOT EXISTS` guard. `RegionKey` is
`dim.DimRegion`'s primary key and the literal value is always `-1`, so a second execution while
`stg.StgSalesOrder` has ≥1 row throws a primary-key violation. The load is not safely rerunnable.

### Recommended fix
Replace the `INSERT` with a `MERGE ... WHEN NOT MATCHED THEN INSERT` (or an existence check) keyed
on `RegionKey`/`RegionName`, matching the idempotency pattern the repo's `add-warehouse-load` skill
expects. Low risk — single-statement change, no schema impact.

---

## DEBT-002: usp_LoadDimCustomer has no update path and colliding hardcoded surrogate keys

- **Key**: warehouse-load::customer-load-no-scd-update
- **Category**: Load Correctness
- **Severity**: Critical
- **Effort**: M (half day)
- **Files**: `StoredProcedures/usp_LoadDimCustomer.sql`, `Tables/dim.DimCustomer.sql`

### Issue
`dim.DimCustomer` declares `EffectiveFrom`/`EffectiveTo`/`IsCurrent` — an SCD Type-2 shape — but
`usp_LoadDimCustomer`'s `MERGE` has only a `WHEN NOT MATCHED THEN INSERT` branch: it never closes or
versions an existing customer row. Worse, every newly-inserted row hardcodes
`CustomerKey = -1, RegionKey = -1` regardless of source data, so a batch with two or more distinct
new `CustomerId` values collides on `dim.DimCustomer`'s primary key (`CustomerKey`) within the same
`MERGE` statement.

### Recommended fix
Generate a real surrogate key (`IDENTITY`/sequence) instead of the literal `-1`, and add a
`WHEN MATCHED AND <attribute changed>` branch that closes the current row (`EffectiveTo =
SYSUTCDATETIME(), IsCurrent = 0`) and inserts a new one — the standard Type-2 pattern the schema
already implies. Depends on resolving region attribution (DEBT-004) for a correct `RegionKey`.

---

## DEBT-003: No warehouse test or validation assets exist

- **Key**: warehouse-testing::no-test-harness
- **Category**: Testing
- **Severity**: High
- **Effort**: M (half day)
- **Files**: repo-wide (`Tables/`, `Views/`, `StoredProcedures/`)

### Issue
No tSQLt (or equivalent SQL-native) test project, no data-quality/reconciliation checks, no SQL
lint/format configuration, and no CI step builds or validates `warehouse.sqlproj` exist anywhere in
this repo. `tests/evals/` is the AI Tech Lead framework's own eval harness (`framework-owned` per
`framework-ownership.json`), not a warehouse test asset. The load-correctness defects in DEBT-001,
DEBT-002, and DEBT-009 would all have been caught by a rerun/idempotency test.

### Recommended fix
Stand up a tSQLt (or equivalent) test project alongside `Tables/`/`Views/`/`StoredProcedures/`.
Start with the smallest risk-first set: rerun each load procedure twice against the same staging
fixture and assert no error and no duplicate rows — this alone would catch DEBT-001, DEBT-002, and
DEBT-009. Add a CI step that builds `warehouse.sqlproj` (DEBT-007) as a prerequisite.

---

## DEBT-004: Region attribution is non-functional end-to-end

- **Key**: warehouse-data-quality::region-always-unknown
- **Category**: Data Quality
- **Severity**: High
- **Effort**: L (1-2 days)
- **Files**: `StoredProcedures/usp_LoadDimRegion.sql`, `StoredProcedures/usp_LoadDimCustomer.sql`, `Tables/stg.StgSalesOrder.sql`, `Views/rpt.vwFinanceExtract.sql`

### Issue
`stg.StgSalesOrder` has no region column at all. `usp_LoadDimRegion` only ever inserts one
hardcoded row (`RegionKey = -1, RegionName = 'Unknown'`), and `usp_LoadDimCustomer` assigns
`RegionKey = -1` to every customer unconditionally. The result: `Views/rpt.vwFinanceExtract.sql` —
a finance reporting extract — always resolves `RegionName` to the literal `'Unknown'` for every row,
regardless of the source order's actual region. This is silent: the view runs without error and
returns data, just with a non-functional grouping dimension.

### Recommended fix
Add a real region source column to `stg.StgSalesOrder` (or the upstream feed producing it), load
`dim.DimRegion` from that source instead of a hardcoded row, and assign each customer's real
`RegionKey` in `usp_LoadDimCustomer`. Requires a decision on where region data originates —
raise with whoever owns the staging feed before implementing.

---

## DEBT-005: ctl.LoadRun control table is dead — no incremental/watermark loading

- **Key**: warehouse-load::control-table-unused
- **Category**: Load Correctness
- **Severity**: High
- **Effort**: L (1-2 days)
- **Files**: `Tables/ctl.LoadRun.sql`, `StoredProcedures/usp_LoadFactSales.sql`

### Issue
`ctl.LoadRun (LoadRunId, StartedAt, Watermark)` is declared but no procedure in the repo inserts
into it or reads its `Watermark` column. `usp_LoadFactSales` populates `fact.FactSales.LoadRunId`
directly from `stg.StgSalesOrder.BatchId` — a different value with no FK or join tying it back to
`ctl.LoadRun`. Every execution does a full, unfiltered scan of `stg.StgSalesOrder`; there is no
run tracking and no watermark-based incremental filtering.

### Recommended fix
Either wire `ctl.LoadRun` into the load (insert a run row per execution, use `Watermark` to filter
incremental staging rows) or remove the table if incremental loading is genuinely out of scope.
Leaving a schema element that looks load-bearing but is dead is worse than either alternative.

---

## DEBT-006: No load/ingestion procedure exists for DimProduct, DimDate, or staging

- **Key**: warehouse-load::missing-loaders
- **Category**: Load Correctness
- **Severity**: High
- **Effort**: XL (needs spike)
- **Files**: `Tables/dim.DimProduct.sql`, `Tables/dim.DimDate.sql`, `Tables/stg.StgSalesOrder.sql`

### Issue
`StoredProcedures/` contains exactly three files (`usp_LoadDimCustomer`, `usp_LoadDimRegion`,
`usp_LoadFactSales`). No procedure populates `dim.DimProduct` or `dim.DimDate`, and no procedure
ingests `stg.StgSalesOrder` from any source. `usp_LoadFactSales` inner-joins both `dim.DimProduct`
and `dim.DimDate`, presupposing they are already populated. Whether this is intentionally out of
this repo's scope (an external seed/reference-data or ingestion process) was raised in `/bootstrap`
Phase 2b and left unresolved by the developer.

### Recommended fix
Spike to confirm with the team whether an external process owns these three objects. If yes,
document that integration boundary in `docs/architecture-decisions.md` / the warehouse map. If no,
scope and build the missing loaders following whichever pattern DEBT-001/DEBT-002 leave behind once
fixed — do not add a fourth broken loader to match the existing three.

---

## DEBT-007: No CI validation of the warehouse.sqlproj build

- **Key**: warehouse-delivery::no-ci-build
- **Category**: Deployment
- **Severity**: Medium
- **Effort**: S (<1hr)
- **Files**: `warehouse.sqlproj`, `.github/workflows/docs-sync-check.yml`

### Issue
The repo's one CI workflow (`.github/workflows/docs-sync-check.yml`) only runs the framework's own
documentation-sync checker — it never builds or publishes `warehouse.sqlproj`. There is also no
publish profile (`*.publish.xml`) or deploy script committed. Schema errors in `Tables/`, `Views/`,
or `StoredProcedures/` would only surface at manual/deploy time, not in CI.

### Recommended fix
Add a CI step that runs `dotnet build warehouse.sqlproj` (or the SDK's equivalent) on every PR
touching `Tables/`, `Views/`, or `StoredProcedures/`. This is schema-validation only — do not wire a
publish/deploy step without an explicit target environment and developer authorization.

---

## DEBT-008: No transaction or error handling in any load procedure

- **Key**: warehouse-load::no-transaction-wrapping
- **Category**: Load Correctness
- **Severity**: Medium
- **Effort**: M (half day)
- **Files**: `StoredProcedures/usp_LoadDimCustomer.sql`, `StoredProcedures/usp_LoadDimRegion.sql`, `StoredProcedures/usp_LoadFactSales.sql`

### Issue
None of the three load procedures contain `BEGIN TRANSACTION`, `COMMIT`, `ROLLBACK`, or
`TRY/CATCH`. A failure partway through a multi-row load (e.g. a constraint violation on row N of a
staging batch) leaves whatever rows already committed in place, with no clean way to retry without
manual staging cleanup.

### Recommended fix
Wrap each procedure's body in `BEGIN TRY ... BEGIN TRAN ... COMMIT ... END TRY BEGIN CATCH ...
ROLLBACK ... THROW ... END CATCH`. Do this alongside DEBT-001/DEBT-002/DEBT-009 rather than as a
separate pass, since fixing rerun-safety and transaction-wrapping together avoids re-touching the
same procedures twice.

---

## DEBT-009: usp_LoadFactSales has no rerun guard or batch scoping

- **Key**: warehouse-load::fact-load-no-rerun-guard
- **Category**: Load Correctness
- **Severity**: Medium
- **Effort**: M (half day)
- **Files**: `StoredProcedures/usp_LoadFactSales.sql`

### Issue
`usp_LoadFactSales` is a bare `INSERT ... SELECT` with no anti-join/`NOT EXISTS` filter against
existing `fact.FactSales.SalesKey`, and no `@BatchId` parameter to scope the load to one staging
batch. The only thing preventing a duplicate row on rerun is the `SalesKey` primary key throwing an
error — "safe" in that it doesn't silently duplicate, but not a designed idempotent rerun, and it
also means every execution scans the entirety of `stg.StgSalesOrder`.

### Recommended fix
Add a `@BatchId BIGINT` parameter and scope the `SELECT` to `s.BatchId = @BatchId`; add a
`NOT EXISTS`/anti-join against `fact.FactSales.SalesKey` so a rerun of the same batch is a no-op
rather than an error.

---

## DEBT-010: No FOREIGN KEY or business-key UNIQUE constraints anywhere in the schema

- **Key**: warehouse-schema::no-referential-integrity
- **Category**: Load Correctness
- **Severity**: Medium
- **Effort**: L (1-2 days)
- **Files**: `Tables/fact.FactSales.sql`, `Tables/dim.DimCustomer.sql`, `Tables/dim.DimProduct.sql`, `Tables/dim.DimRegion.sql`

### Issue
No table declares a `FOREIGN KEY`. `fact.FactSales` references dimensions via bare integer columns
(`CustomerKey`, `ProductKey`, `OrderDateKey`) with no engine-enforced link. Additionally,
`dim.DimCustomer.CustomerId` and `dim.DimProduct.ProductId` (the natural/business keys) have no
`UNIQUE` constraint, so `usp_LoadDimCustomer`'s `MERGE ... ON target.CustomerId = source.CustomerId`
relies entirely on application logic to prevent duplicate business-key rows. See `docs/architecture-decisions.md` ADR-003.

### Recommended fix
Add `FOREIGN KEY` constraints from `fact.FactSales` to each dimension, and `UNIQUE` constraints on
each dimension's business key. Sequence this after DEBT-001/DEBT-002 are fixed, since the current
loaders would violate a `UNIQUE` constraint on `CustomerId` immediately.

---

## DEBT-011: fact.FactSales.RegionName/CategoryName/SegmentName are dead denormalized columns

- **Key**: warehouse-schema::factsales-dead-columns
- **Category**: Load Correctness
- **Severity**: Low
- **Effort**: S (<1hr)
- **Files**: `Tables/fact.FactSales.sql`, `StoredProcedures/usp_LoadFactSales.sql`

### Issue
`fact.FactSales` declares `RegionName`, `CategoryName`, `SegmentName` (nullable denormalized
columns). `usp_LoadFactSales`'s `INSERT` column list omits all three, so they stay `NULL` forever.
None of the three reporting views (`rpt.vwExecutiveSummary`, `rpt.vwFinanceExtract`,
`rpt.vwOrderDetail`) read them either — each re-joins back to the owning dimension instead.

### Recommended fix
Either populate the three columns at load time from the joined dimensions (if denormalization for
read performance is actually wanted) or drop them from the table — carrying dead nullable columns
invites a future reader to assume they're populated.

---

## DEBT-012: Stored procedures use dbo schema while tables/views use layer-named schemas

- **Key**: warehouse-schema::proc-schema-inconsistency
- **Category**: Load Correctness
- **Severity**: Low
- **Effort**: S (<1hr)
- **Files**: `StoredProcedures/usp_LoadDimCustomer.sql`, `StoredProcedures/usp_LoadDimRegion.sql`, `StoredProcedures/usp_LoadFactSales.sql`

### Issue
See `docs/architecture-decisions.md` ADR-001. Tables/views consistently use `ctl`/`stg`/`dim`/
`fact`/`rpt` schemas; all three stored procedures are created in `dbo`. Raised with the developer
during `/bootstrap` Phase 2b and left unresolved — intent (dbo-for-procs as convention, vs. drift)
is not yet confirmed.

### Recommended fix
Get a team decision on whether `dbo` is the intended home for load procedures or whether they
should move to a layer-aligned schema; document the answer as an ADR review-notes update once
decided.

---

## Dismissed proposals — do not re-propose without materially changed evidence

| Key | Affected paths / symbols | Evidence reviewed | Dismissed | Reason |
|-----|--------------------------|-------------------|-----------|--------|
| _(none)_ | _ | _ | _ | _ |

---

## Trojan Horse Opportunities

Group DEBT IDs by feature area so developers can bundle cleanup into feature work:

- **Customer/Region dimension loading**: DEBT-001, DEBT-002, DEBT-004, DEBT-010
- **Fact load pipeline**: DEBT-005, DEBT-006, DEBT-008, DEBT-009, DEBT-011
- **Delivery & validation**: DEBT-003, DEBT-007
- **Schema conventions**: DEBT-012
