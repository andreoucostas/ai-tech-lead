# Architecture Decisions

Append-only ADR log. Entries are added by the `create-adr` skill (format: `## ADR-NNN: <title>` with Date / Status / Decision / Context / Alternatives considered / Consequences). The one-line index lives in `AGENTS.md > Architecture Decisions`.

---

## ADR-001: Schema-per-layer naming as the warehouse's layering boundary

- **Date**: 2026-10-01
- **Status**: Accepted (observed convention, recorded by `/bootstrap`)

### Decision
Every object is schema-qualified by its layer: `stg` (staging), `dim`/`fact` (warehouse core),
`rpt` (reporting/consumption), `ctl` (ETL control). No object crosses layers under the wrong schema
prefix.

### Context
All 13 SQL objects (`Tables/`, `StoredProcedures/`, `Views/`) consistently follow this prefix with
no exceptions or mixed-schema objects found.

### Alternatives considered
| Approach | Pros | Cons | Effort |
|----------|------|------|--------|
| Single `dbo` schema with naming prefixes (`DimCustomer`, `FactSales`) | Simpler permission model | No schema-level access control per layer; harder to spot a layer violation at a glance | — |

### Consequences
A new object's schema prefix is load-bearing documentation of its layer — do not place a new table
or view in `dbo` or an existing layer's schema if it belongs to a different layer.

### Review notes
Recorded from observed structure only; no team discussion evidenced. Revisit if the warehouse grows
a second mart or landing zone that doesn't fit the four-schema split.

---

## ADR-002: SSDT (Microsoft.Build.Sql SDK) as the sole schema-deployment vehicle

- **Date**: 2026-10-01
- **Status**: Accepted (observed convention, recorded by `/bootstrap`)

### Decision
Schema is deployed exclusively through `warehouse.sqlproj`, a single-line SDK-style SSDT project
(`Microsoft.Build.Sql/0.2.0`), with no further MSBuild configuration.

### Context
No `.sln`, publish profile, pre/post-deployment script, dbt project, SSIS package, or pipeline
config exists anywhere in the repository — `warehouse.sqlproj` is the only deployment artifact
found.

### Alternatives considered
| Approach | Pros | Cons | Effort |
|----------|------|------|--------|
| Plain migration-script folder | No SDK dependency | Loses SSDT's build-time schema validation | — |
| dbt | Strong testing/lineage tooling | Not evidenced anywhere in this repo; would be a new stack | — |

### Consequences
Any schema change must go through this project to be deployable; there is no alternate path to
target. Build/test/deploy commands for it are currently `not available (no evidenced command)` —
see `AGENTS.md > Conventions > Verification Commands`.

### Review notes
Recorded from observed structure only; the project has no further settings (no target database,
no publish profile) to confirm an actual deployment target.

---

## ADR-003: `fact.FactSales` denormalized columns declared but never populated (accidental)

- **Date**: 2026-10-01
- **Status**: Unresolved — flagged as debt (see `TECH_DEBT.md` DEBT-007)

### Decision (as currently implemented)
`fact.FactSales` carries `RegionName`, `CategoryName`, `SegmentName` as nullable denormalized
columns, apparently intended to let reporting read attributes directly off the fact row without a
dimension join.

### Context
`usp_LoadFactSales`'s `INSERT` column list omits all three columns, so they are always `NULL`. The
`rpt.*` views instead re-derive the same attributes via live joins to `dim.DimProduct`/`dim.DimRegion`,
so no current consumer reads the denormalized columns. This looks like an incomplete rollout of a
denormalization decision, not an intentional hybrid — it became an accidental convention (dead
columns) rather than a deliberate one.

### Alternatives considered
| Approach | Pros | Cons | Effort |
|----------|------|------|--------|
| Populate the columns in the load | Reporting could skip a dimension join | Requires deciding how/when they get refreshed if the dimension changes after load | M |
| Drop the columns | Removes dead/misleading schema | Loses the (currently unused) option of fact-level denormalization | S |

### Consequences
Until resolved, any new consumer that reads these columns directly will silently get `NULL`
instead of an error.

### Review notes
Needs a human decision (populate vs. drop) — tracked as `TECH_DEBT.md` DEBT-007, not resolved here.

---

## ADR-004: `ctl.LoadRun` control table declared but never wired into any load (accidental)

- **Date**: 2026-10-01
- **Status**: Unresolved — flagged as debt (see `TECH_DEBT.md` DEBT-004)

### Decision (as currently implemented)
`ctl.LoadRun` (`LoadRunId`, `StartedAt`, `Watermark`) exists as the apparent rerun/idempotency
control mechanism for the warehouse's loads.

### Context
None of the three stored procedures reads or writes `ctl.LoadRun`. `fact.FactSales.LoadRunId` is
instead populated from `stg.StgSalesOrder.BatchId` — a different identifier from a different table —
so the column named `LoadRunId` on the fact table does not actually trace back to a row in
`ctl.LoadRun`. The control table is orphaned.

### Alternatives considered
| Approach | Pros | Cons | Effort |
|----------|------|------|--------|
| Wire `ctl.LoadRun` into each load (insert a run row, use `Watermark` to bound the staging read) | Gives the warehouse a real rerun/idempotency mechanism | Requires redesigning all three load procedures | M |
| Remove `ctl.LoadRun` if truly not needed | Removes dead/misleading schema | Loses a structure already in place for future idempotency work | S |

### Consequences
Until resolved, nothing in this repo prevents a load from being safely rerun or from double-loading
staged data.

### Review notes
Needs a human decision (wire vs. remove) — tracked as `TECH_DEBT.md` DEBT-004, not resolved here.
