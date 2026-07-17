---
name: map-warehouse
description: >
  SQL data-warehouse repos only — verifies before scanning. Map a warehouse codebase:
  layers (staging → warehouse → marts), fact/dimension entities and their grain, load
  orchestration and ordering, batch/watermark control, slowly-changing-dimension strategy,
  partitioning, and the reporting views that consume it all.
  USE FOR: onboarding to a data-warehouse repo, understanding where an entity is loaded
  before designing a change, refreshing docs/warehouse-map.md, answering "which loads
  touch table X" or "what feeds this report".
  DO NOT USE FOR: OLTP/application databases (EF Core or Dapper CRUD — follow the repo's
  data-access conventions), adding or modifying a load (use add-warehouse-load), tuning a
  single slow query.
---

# Map a SQL Data Warehouse

Match CLAUDE.md > Conventions > Data Access. Produces a structural map of the warehouse —
layers, entities, loads, controls — so changes can follow the patterns that are already there.

0. **Confirm this repo is a SQL data warehouse.** Two checks, both required:
   - It is a SQL codebase: a `.sql` source tree (e.g. `Tables/`, `StoredProcedures/`, `Views/`,
     migration-script folders), a SQL project (e.g. SSDT `.sqlproj`/DACPAC), or `dbt_project.yml`.
   - Warehouse signals — grep **inside the SQL artifacts only** (`*.sql`, project files, pipeline
     definitions), never the whole tree, and require **at least two** independent hits:

     | Signal | Grep (in `*.sql` / project files) |
     |--------|-----------------------------------|
     | Layer schemas | `\b(stg\|staging\|raw\|ods\|dim\|fact\|mart\|dw)\.` |
     | Dimensional naming | `\bDim[A-Z][a-z]` or `\bFact[A-Z][a-z]` |
     | Load/orchestration procs | `usp_Load\|usp_Process\|EXEC.*Load` |
     | Batch/run control | `LoadRun\|BatchId\|LoadId\|Watermark` |
     | Change-tracking columns | `EffectiveFrom\|EffectiveTo\|IsCurrent\|RowHash` |
     | Partitioning | `PARTITION FUNCTION\|PARTITION SCHEME\|SWITCH PARTITION` |
     | ETL pipeline artifacts | `*.dtsx`, ADF/Synapse pipeline JSON, dbt models |

   If either check fails, STOP — this recipe does not apply. This repo's data access follows a
   different pattern; see `docs/defaults.md` > Data Access.

1. **Layers.** Identify each database/schema and its role: staging/raw (landing), ODS,
   warehouse core (dims + facts), marts, and the consumption surface — the reporting
   views/marts users actually query, and which core tables feed them (this is where grain
   mistakes and double-counting surface). Evidence: schema prefixes on `CREATE TABLE`/`CREATE
   PROC`/`CREATE VIEW`, database references in deployment scripts, and the direction of
   cross-schema `INSERT INTO ... SELECT` statements.

2. **Entities and grain.** Classify every table: dimension (surrogate key + natural/business
   key + descriptive attributes), fact (foreign keys to dimensions, date keys, measures),
   staging (loose types, batch columns), control (run/audit metadata). For every fact, state
   its grain in one sentence — the grain is what exactly one row represents (e.g. "one row per
   order line per day"). A fact whose grain cannot be stated from its keys is a finding.

3. **Load flow and ordering.** Find the orchestration entry points: master procs that `EXEC` a
   chain, job/schedule scripts, `.dtsx` packages, pipeline JSON, or the dbt DAG. Trace each
   entity staging → warehouse. Record the load order — dimensions before the facts that
   reference them — and which loads run together in one batch/run.

4. **Control and idempotency mechanics.** For each load, find how a rerun of the same data is
   prevented or made safe: batch/run control tables, load IDs, watermarks/high-water marks,
   row-hash comparison, delete-and-reload windows, partition switch, or versioned runs (each
   execution writes a new run/version ID and supersedes the previous; consumers select the
   current version). State the mechanism per load. A load with no discernible rerun protection
   is a finding — it can load the same data twice.

5. **Slowly changing dimension (SCD) strategy.** Per dimension, determine how history is kept:
   Type 1 (overwrite, no history), Type 2 (new row per change with `EffectiveFrom`/
   `EffectiveTo`/`IsCurrent`), or mixed per-column. Also note how facts change after load:
   corrections as reversal rows, in-place updates, versioned snapshot runs, and how
   late-arriving facts (rows for an earlier period arriving after that period loaded) are handled.

6. **Partitioning and retention.** Where the repo evidences SQL Server, look for
   `CREATE PARTITION FUNCTION`/`SCHEME`, `SWITCH PARTITION` in load procs, sliding-window
   maintenance, columnstore indexes, and archive/purge jobs. In other dialects, look for the
   equivalent (native partitioning clauses, date-suffixed tables).

7. **Report.** One table per layer:

   | entity | layer | grain | load proc/pipeline | orchestrated by | rerun protection | SCD | partitioning |
   |--------|-------|-------|--------------------|-----------------|------------------|-----|--------------|

   plus the views/marts each entity feeds, and findings (unstated grain, loads without rerun
   protection, inconsistent SCD handling). Offer to write or refresh `docs/warehouse-map.md`
   with the same tables — offer, don't force. If CLAUDE.md > Conventions describes the
   warehouse and the code disagrees, flag the drift; do not silently edit either.

Results are grep-based structure detection, not execution — confirm against a load run or the
team before relying on them for a destructive change.
