# Tech Debt Register

> One block per item. Sort by severity then effort. Reference items by ID in commit messages and PRs.

---

## DEBT-001: Fact load depends on two dimensions that have no load procedure

- **Key**: factsales-load::missing-dim-loads
- **Category**: Architecture
- **Severity**: Critical
- **Effort**: L (needs a real source for Product/Date reference data, or confirmation of an external seeding process this repo doesn't own)
- **Files**: `StoredProcedures/usp_LoadFactSales.sql:4-6`, `Tables/dim.DimProduct.sql`, `Tables/dim.DimDate.sql`

### Issue
`usp_LoadFactSales` `INNER JOIN`s `dim.DimProduct` and `dim.DimDate` to resolve surrogate keys, but
no procedure anywhere in this repository (`StoredProcedures/` has only `usp_LoadDimCustomer`,
`usp_LoadDimRegion`, `usp_LoadFactSales`) loads either dimension. On a clean environment the fact
load will silently return zero or incomplete rows — no error, just missing data.

### Recommended fix
Either add `usp_LoadDimProduct` and `usp_LoadDimDate` following the warehouse's load pattern, or
document the external/manual process that populates these two dimensions if one genuinely exists
outside this SQL project.

---

## DEBT-002: `usp_LoadDimCustomer` is a non-functional stub, not a working SCD2 load

- **Key**: dimcustomer-load::hardcoded-stub-no-scd2
- **Category**: Data Access
- **Severity**: Critical
- **Effort**: L (needs real surrogate-key generation, a real source for RegionKey/SegmentName, and a WHEN MATCHED branch)
- **Files**: `StoredProcedures/usp_LoadDimCustomer.sql:1`, `Tables/dim.DimCustomer.sql:1-9`

### Issue
The procedure's only logic is `MERGE ... WHEN NOT MATCHED THEN INSERT (CustomerKey, CustomerId,
RegionKey, SegmentName, EffectiveFrom, IsCurrent) VALUES (-1, source.CustomerId, -1, 'Unknown',
SYSUTCDATETIME(), 1)`. `CustomerKey` and `RegionKey` are hardcoded literal `-1` (not a
generated/sequenced surrogate key) and `SegmentName` is hardcoded `'Unknown'`. Because `CustomerKey`
is the table's `PRIMARY KEY` and always `-1`, inserting a second distinct new `CustomerId` raises a
primary-key violation. There is no `WHEN MATCHED` branch, so the declared SCD Type-2 shape
(`EffectiveFrom`/`EffectiveTo`/`IsCurrent`) is never implemented — no customer is ever updated or
versioned.

### Recommended fix
Replace the stub with a real `MERGE` that assigns a generated surrogate key per new `CustomerId`,
sources `RegionKey`/`SegmentName` from wherever they actually originate (not present in
`stg.StgSalesOrder` today — may need a staging/schema change), and adds a `WHEN MATCHED AND
<changed>` branch that closes the prior row (`EffectiveTo`, `IsCurrent = 0`) before inserting the
new version.

---

## DEBT-003: `usp_LoadDimRegion` never loads real region data and isn't re-runnable

- **Key**: dimregion-load::stub-no-source-no-rerun
- **Category**: Data Access
- **Severity**: Critical
- **Effort**: M (add a natural/business key column, source real region data, rewrite as an upsert)
- **Files**: `StoredProcedures/usp_LoadDimRegion.sql:1`, `Tables/dim.DimRegion.sql:1`

### Issue
`INSERT INTO dim.DimRegion (RegionKey, RegionName) SELECT DISTINCT -1, 'Unknown' FROM
stg.StgSalesOrder` inserts only the literal `-1`/`'Unknown'` pair — `stg.StgSalesOrder` has no
region column at all, so no real region is ever sourced. `dim.DimRegion` also has no natural/business
key column (only `RegionKey` + `RegionName`), so there is no way to match "the same region" across
runs even with a correct upsert. `RegionKey` is `PRIMARY KEY`, so any rerun after the first
successful run raises a primary-key violation.

### Recommended fix
Add a natural/business key column to `dim.DimRegion`, source real region values from wherever they
actually originate (not present in `stg.StgSalesOrder` today), and rewrite the load as a keyed
upsert (`MERGE` or existence check).

---

## DEBT-004: `ctl.LoadRun` control/watermark table is completely unused

- **Key**: ctl-loadrun::orphaned-control-table
- **Category**: Data Access
- **Severity**: High
- **Effort**: M (wire an insert-at-start/watermark-read/update-on-completion flow into the three existing load procedures, or remove the table)
- **Files**: `Tables/ctl.LoadRun.sql`, `StoredProcedures/usp_LoadFactSales.sql:3`

### Issue
`ctl.LoadRun` (`LoadRunId`/`StartedAt`/`Watermark`) is never read or written by any stored
procedure. `fact.FactSales.LoadRunId` is populated from `stg.StgSalesOrder.BatchId` instead — a
different identifier from a different table — so the fact table's `LoadRunId` column does not
actually correlate to a row in the control table it is named after.

### Recommended fix
Either wire `ctl.LoadRun` into each load (insert a run row at start, use `Watermark` to bound the
staging read, update on completion) or remove the table if it is genuinely not needed.

---

## DEBT-005: No load has rerun/idempotency protection

- **Key**: warehouse-loads::no-rerun-guard
- **Category**: Data Access
- **Severity**: High
- **Effort**: M (add a MERGE/existence-check/batch-dedup guard to each load)
- **Files**: `StoredProcedures/usp_LoadFactSales.sql:1-7`, `StoredProcedures/usp_LoadDimRegion.sql:1`

### Issue
`usp_LoadFactSales` and `usp_LoadDimRegion` are unconditional `INSERT`s with no `WHERE` clause,
existence check, or `MERGE`. A rerun against unchanged staging content fails on a primary-key
violation rather than silently duplicating — but nothing prevents an already-loaded batch from
being picked up again if staging is only appended-to, and there is no evidenced watermark/batch-id
guard anywhere.

### Recommended fix
Add a batch-id dedup check (skip a `BatchId` already recorded as loaded) or a `MERGE`/upsert keyed
on business key, matching the control mechanism once `ctl.LoadRun` (DEBT-004) is actually wired in.

---

## DEBT-006: No warehouse test or data-validation asset exists

- **Key**: warehouse-testing::no-assets
- **Category**: Testing
- **Severity**: High
- **Effort**: M
- **Files**: _(repository-wide absence — no file to cite)_

### Issue
There is no tSQLt (or other SQL unit-test framework) reference, no `.testsettings` file, no
seed/reference-data script, and no SQL linter/formatter configuration anywhere in the repository.
The only CI workflow (`.github/workflows/docs-sync-check.yml`) runs exclusively the framework's own
documentation-sync check — no build, deploy, schema-validation, or data-quality step for the
warehouse exists. `tests/evals/` is the AI Tech Lead framework's own eval harness
(`framework-owned/overwritten`), not a warehouse test asset.

### Recommended fix
Introduce a lightweight reconciliation-check script (row-count/control-total comparison between
`stg` and `fact`/`dim` per load) or a tSQLt-based unit-test project, and wire it into CI alongside
the existing `docs-sync-check.ps1` workflow.

---

## DEBT-007: No orchestrator enforces dimension-before-fact load ordering

- **Key**: warehouse-loads::no-orchestration
- **Category**: Architecture
- **Severity**: Medium
- **Effort**: M (add an orchestrator procedure, e.g. `usp_LoadWarehouse`, that `EXEC`s loads in dependency order)
- **Files**: `StoredProcedures/*.sql` (absence)

### Issue
Load ordering (dimensions before the fact that references them) is implied only by
`usp_LoadFactSales`'s `INNER JOIN`s. None of the three procedures `EXEC`s another, so sequencing
correctness depends entirely on whoever invokes these procedures externally.

### Recommended fix
Add an explicit orchestrator procedure that calls dimension loads before `usp_LoadFactSales`, or
document the required external run order if orchestration genuinely lives outside this repo.

---

## DEBT-008: `fact.FactSales` denormalized columns are dead schema (always NULL)

- **Key**: factsales::dead-denormalized-columns
- **Category**: Data Access
- **Severity**: Medium
- **Effort**: S (either populate the columns in the load, or drop them)
- **Files**: `Tables/fact.FactSales.sql:7-9`, `StoredProcedures/usp_LoadFactSales.sql:2-3`, `Views/rpt.vwExecutiveSummary.sql:1`, `Views/rpt.vwFinanceExtract.sql:1-6`

### Issue
`fact.FactSales` declares `RegionName`, `CategoryName`, `SegmentName` as nullable denormalized
columns, but `usp_LoadFactSales`'s `INSERT` column list omits all three, so they are always `NULL`.
The `rpt.*` views instead re-derive the same attributes via live joins to
`dim.DimProduct`/`dim.DimRegion`, so no current consumer reads the denormalized columns. See
`docs/architecture-decisions.md#adr-003`.

### Recommended fix
Decide intent: populate the columns in the load (true denormalization) or drop them. Either is a
small, contained change — the risk is only in leaving the ambiguity in place for a future reader who
assumes the columns are live.

---

## DEBT-009: No `FOREIGN KEY` constraints anywhere in the schema

- **Key**: warehouse-schema::no-fk-constraints
- **Category**: Architecture
- **Severity**: Low
- **Effort**: M (add FK constraints, a natural key to `dim.DimRegion`, and a primary key to `stg.StgSalesOrder` — each is a schema migration)
- **Files**: `Tables/*.sql` (absence)

### Issue
No table in the project declares an actual `FOREIGN KEY`; referential integrity between fact and
dimension tables is enforced only by load-time joins. Additionally, `dim.DimRegion` has no
natural/business key column, and `stg.StgSalesOrder` has no declared `PRIMARY KEY`.

### Recommended fix
Add `FOREIGN KEY` constraints from `fact.FactSales` to its dimensions where the business accepts
the enforcement cost, add a natural key column to `dim.DimRegion`, and add a `PRIMARY KEY` (or at
minimum a uniqueness constraint) to `stg.StgSalesOrder`.

---

## DEBT-010: `rpt.vwFinanceExtract` doesn't filter `IsCurrent = 1` on `DimCustomer`

- **Key**: vwfinanceextract::missing-iscurrent-filter
- **Category**: Data Access
- **Severity**: Low
- **Effort**: S (add `AND c.IsCurrent = 1` to the join predicate)
- **Files**: `Views/rpt.vwFinanceExtract.sql:1-6`

### Issue
`rpt.vwFinanceExtract` joins `dim.DimCustomer` without an `IsCurrent = 1` filter, unlike
`usp_LoadFactSales`, which does filter. This is latent only while `usp_LoadDimCustomer` never
actually versions customers (DEBT-002) — if DimCustomer's SCD2 history is ever correctly
implemented, this view will double-count across historical customer versions.

### Recommended fix
Add `AND c.IsCurrent = 1` to the view's join predicate now, so the fix doesn't have to be
remembered later alongside DEBT-002.

---

## Dismissed proposals — do not re-propose without materially changed evidence

> These are reviewed claims the team determined are not debt. Keep every row for auditability.
> A later scan may reopen one only by naming the concrete evidence delta in a new active item.

| Key | Affected paths / symbols | Evidence reviewed | Dismissed | Reason |
|-----|--------------------------|-------------------|-----------|--------|
| _(none)_ | _ | _ | _ | _ |

---

## Trojan Horse Opportunities

- **Customer/Region dimension loads**: DEBT-002, DEBT-003
- **Load control & orchestration**: DEBT-001, DEBT-004, DEBT-005, DEBT-007
- **Fact & reporting schema**: DEBT-008, DEBT-010
- **Schema integrity**: DEBT-009
- **Testing & validation**: DEBT-006
