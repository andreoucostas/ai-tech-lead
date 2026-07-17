---
name: add-warehouse-load
description: >
  SQL data-warehouse repos only — verifies before scaffolding. Add a new fact or dimension
  load, or extend an existing one, following the repo's existing staging → warehouse patterns.
  Covers staging, the load procedure, batch/watermark control wiring, slowly-changing-dimension
  handling, load ordering, partition alignment, and the deployment path.
  USE FOR: a new fact or dimension table plus its load, a new source feeding an existing
  table, adding columns to a dimension or fact (including the history implications).
  DO NOT USE FOR: OLTP entities (use add-entity), one-off data corrections, understanding or
  mapping the warehouse (use map-warehouse), report/query tuning.
---

# Add or Extend a Warehouse Load

Match CLAUDE.md > Conventions > Data Access. The two rules that dominate everything below:
**follow the existing load pattern exactly, and never load the same data twice.**

0. **Confirm this repo is a SQL data warehouse.** Same gate as `map-warehouse`: a `.sql`
   source tree / SQL project (e.g. SSDT `.sqlproj`) / `dbt_project.yml`, **plus at least two**
   warehouse signals grepped inside SQL artifacts only — layer schemas
   (`\b(stg\|staging\|dim\|fact\|mart\|dw)\.`), `\bDim[A-Z][a-z]`/`\bFact[A-Z][a-z]` naming,
   load procs (`usp_Load`), batch/run control (`LoadRun\|BatchId\|Watermark`), change-tracking
   columns (`EffectiveFrom\|IsCurrent\|RowHash`), partition objects, or ETL pipeline artifacts.
   If the gate fails, STOP — this recipe does not apply. Find the repo's actual persistence
   pattern and mirror it, or use the project-specific skill `/bootstrap` created.

1. **Find the pattern to copy.** Read `docs/warehouse-map.md` if it exists (run
   `map-warehouse` to create it if the change is non-trivial). Locate 1–2 existing loads of
   the same kind — a dimension load for a new dimension, a fact load for a new fact — and
   mirror their structure exactly: naming, staging shape, procedure layout, error handling,
   logging, control-table calls. One warehouse, one loading pattern: never introduce a second
   style. If no comparable load exists, ask the developer before inventing one.

2. **Design the entity.**
   - Dimension: surrogate key; natural/business key with a unique constraint (scoped to the
     current row where history is kept); descriptive attributes; the repo's standard
     change-tracking columns.
   - Fact: write the grain statement first — one sentence saying what exactly one row
     represents. Foreign keys reference dimension surrogate keys (not natural keys, if the
     repo uses surrogates). Classify each measure: additive, semi-additive (e.g. balances —
     never summed across time), or non-additive (ratios — recompute, don't aggregate).

3. **Staging.** Land data the way sibling loads do — truncate-and-load or
   append-with-batch-id, whichever the repo uses. Staging columns stay loosely typed;
   enforcement happens in the warehouse load. Carry the batch/run ID from the first landing
   step so every downstream row is traceable to its run.

4. **Make the load idempotent — the non-negotiable step.** The same data must never be loaded
   twice, and a rerun after a mid-run failure must be safe. Use the repo's existing mechanism:
   - **Watermark**: only pull rows past the stored high-water mark; advance it transactionally
     with the load.
   - **Batch-ID dedup**: refuse or skip a batch already recorded as committed in the control
     table. Illustration only — follow the repo's actual control tables (T-SQL, applies where
     the repo evidences SQL Server):
     ```sql
     IF EXISTS (SELECT 1 FROM etl.LoadRun
                WHERE BatchId = @BatchId AND Status = 'Committed')
         RETURN;  -- batch already loaded
     ```
   - **Delete-then-insert window**: delete the target slice (date range or partition) before
     inserting, so a rerun replaces rather than duplicates.
   - **Merge/upsert**: match on business key (+ row hash to skip unchanged rows).
   - **Versioned runs**: a rerun IS a new version — each execution writes a new run/version
     ID, prior runs are superseded rather than deduplicated, and consumers select the current
     version. Here the guard is "no two runs both marked current", not "no second run".
   Wrap multi-statement loads in an explicit transaction, or make each statement independently
   re-runnable — match the sibling load.

5. **Slowly changing dimension (SCD) handling.** Apply the same SCD type the target or sibling
   dimensions already use. Type 1: overwrite in place, no history. Type 2: expire the current
   row (set `EffectiveTo`, clear `IsCurrent`), insert the new version with a new surrogate key
   — never update an existing surrogate key. For facts that change after load, do what the
   repo does: reversal/correction rows, in-place updates, or versioned snapshot runs.

6. **Ordering and orchestration.** Register the load in the orchestration at the right
   position: dimensions load before the facts that reference them. Update the master
   procedure, run-order configuration, or pipeline definition — a load that isn't orchestrated
   doesn't exist. Handle late-arriving dimension members the way the repo does (inferred/stub
   members updated later, or fail-and-retry).

7. **Partition alignment.** If the target table family is partitioned, the new table joins the
   existing partition function/scheme. If sibling loads use partition switch, create the
   switch-aligned staging table: same filegroup, same indexes, check constraint matching the
   target partition.

8. **Deployment.** Schema changes go through the repo's one existing vehicle — SQL project
   build, migration-scripts folder, or dbt — never ad-hoc scripts against the server. Review
   the generated/authored DDL before it ships.

9. **Review checklist (sign-off before merge).**
   - Rerun safety: running the load twice for the same batch yields identical target row
     counts (or, for versioned runs, exactly one run marked current).
   - No business-key duplicates in the current/active rows of the target.
   - Reconciliation: staging vs target row counts match or the difference is explained
     (rejected rows, dedup).
   - History spot-check: change one attribute on one record, rerun, verify the expected
     old/new row shape.
   - Orchestration order verified: the new load runs after every dimension it references.
