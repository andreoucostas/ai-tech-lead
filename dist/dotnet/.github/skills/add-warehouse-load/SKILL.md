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
   `map-warehouse` to create it if the change is non-trivial). **That map is a snapshot, not a
   live view** — nothing refreshes it when the warehouse changes. Before copying a pattern out
   of it, confirm the entities and load procs it names still exist in the SQL tree; where the
   map and the code disagree the code wins — re-run `map-warehouse` rather than trusting it
   further. Locate 1–2 existing loads of the same kind — a dimension load for a new dimension,
   a fact load for a new fact — and mirror their structure exactly: naming, staging shape,
   procedure layout, error handling, logging, control-table calls. One warehouse, one loading
   pattern: never introduce a second style. If no comparable load exists, ask the developer
   before inventing one.

2. **Bind to the dimensions that already exist — before designing anything.** Most new loads need
   **no new dimension**. A duplicate dimension is the expensive mistake here: it splits one business
   entity across two surrogate-key spaces, and nothing in the load will fail to tell you — the
   numbers just stop agreeing between two reports months later.

   Take every source column that is not a measure and put it in exactly one of three buckets:
   - **Reaches an existing dimension.** Match on the **concept and its business key, not the column
     name** — a source's `cust_ref` and `DimCustomer.CustomerCode` are one key under two names, and
     a same-named column in two systems is routinely not the same thing. The table inventory in
     `docs/warehouse-map.md` lists each dimension's natural/business key; that is the list to search.
   - **Degenerate.** An identifier with no dimension table behind it — order number, invoice number.
     It stays on the fact. Check how sibling facts carry theirs before inventing a table for it.
   - **Genuinely new.** No existing dimension covers the concept. Say so explicitly and name what you
     searched, because this is the branch that has to be justified. A new dimension is its own load:
     it needs the SCD decision below, and it must be orchestrated *before* this fact.

   Three checks a name match will not catch:
   - **Indirect reach (snowflake).** An attribute may be owned by a dimension reached *through*
     another dimension rather than from the fact. Before adding a direct key, check how this
     warehouse already reaches it: if region hangs off `DimCustomer.RegionKey` and the existing
     views join it that way, a `RegionKey` on your fact is a **second path to the same dimension**,
     and the two can disagree. A direct key is right only when it means something the indirect path
     does not — a **different role** (ship-to versus bill-to region), or the value **as at the
     transaction**, which must not follow later changes to the customer. If that is the case, say
     which it is and name the role. If you cannot, use the path that already exists.
   - **Grain compatibility.** A dimension coarser than the fact is the *normal* case — many fact
     rows to one dimension row, nothing lost. What matters is whether it is coarser than the
     **attribute you need**: a fact at variant level joined to a product-level dimension cannot
     tell variants apart. The opposite error is joining on a key finer than the fact's grain, which
     multiplies fact rows and double-counts the measures. Either way, the right entity at the wrong
     grain is a conversation with the developer, not grounds for a second dimension.
   - **Conformed use.** If another fact already reaches this dimension, you are on a drill-across
     path: reach it by the same **mechanism** — the same kind of key, resolved the same way — so the
     two facts can each be aggregated to the shared grain and then compared. The **role** may
     legitimately differ: one dimension reached by several keys is role-playing, not duplication
     (`OrderDateKey` and `ShipDateKey` both → `DimDate`). Name the role your key plays rather than
     assuming it matches the other fact's.

   **Write the key list before any DDL.** One line per foreign key: which dimension it reaches, by
   what path (direct, or through which dimension), via which business key, and existing or new. That
   list is the input to the next step; if you cannot write it, you are not ready to create a table.

   In a repo that **also** has an application database, keep the boundary straight: this recipe
   governs warehouse tables — staging, dimension, fact — in the SQL tree. A table backed by the
   application's ORM model or its migrations is not a warehouse entity; use the repo's OLTP entity
   recipe (`add-entity` where the repo evidences EF Core) instead.

3. **Design the entity.**
   - Dimension: surrogate key; natural/business key with a unique constraint (scoped to the
     current row where history is kept); descriptive attributes; the repo's standard
     change-tracking columns.
   - Fact: write the grain statement first — one sentence saying what exactly one row
     represents. **The foreign keys are the key list you just wrote — transcribe it, do not
     re-decide it here**, and reference dimension surrogate keys (not natural keys, if the repo
     uses surrogates). A column that appeared in no bucket belongs on neither the fact nor a new
     table until you can say which dimension owns it. Classify each measure: additive,
     semi-additive (e.g. balances — never summed across time), or non-additive (ratios —
     recompute, don't aggregate).

4. **Staging.** Land data the way sibling loads do — truncate-and-load or
   append-with-batch-id, whichever the repo uses. Staging columns stay loosely typed;
   enforcement happens in the warehouse load. Carry the batch/run ID from the first landing
   step so every downstream row is traceable to its run.

5. **Make the load idempotent — the non-negotiable step.** The same data must never be loaded
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

   **Resolve each dimension key by lookup, and decide what a miss does.** For every foreign key on
   the key list, the load joins staging's business key to the dimension's business key to obtain the
   surrogate key — and where the dimension keeps history, to the version that applied, using the
   repo's own as-of rule copied from a sibling load rather than one you invent.

   **Classify a lookup miss before handling it** — only one of these is a late-arriving member, and
   the right response differs:
   - the member exists upstream but has not loaded yet → **late arrival**: an inferred/stub row
     completed by a later dimension load, or fail-and-retry once ordering is fixed;
   - the source key is invalid or unmappable → the reserved `Unknown`/`-1` member, with the count
     surfaced in the load's reconciliation rather than absorbed silently;
   - the relationship is legitimately absent → a reserved "not applicable" member, which is **not**
     the same fact as unknown and should not share its key;
   - the load ran before a dimension it depends on → fix the orchestration; a stub here hides a
     sequencing bug that will recur every run.

   What is never right is dropping unmatched rows, or defaulting every miss to one member: that
   makes the fact's totals wrong in a way that reconciles against nothing and surfaces months later.

6. **Slowly changing dimension (SCD) handling.** Apply the same SCD type the target or sibling
   dimensions already use. Type 1: overwrite in place, no history. Type 2: expire the current
   row (set `EffectiveTo`, clear `IsCurrent`), insert the new version with a new surrogate key
   — never update an existing surrogate key. For facts that change after load, do what the
   repo does: reversal/correction rows, in-place updates, or versioned snapshot runs.

7. **Ordering and orchestration.** Register the load in the orchestration at the right
   position: dimensions load before the facts that reference them. Update the master
   procedure, run-order configuration, or pipeline definition — a load that isn't orchestrated
   doesn't exist. Handle late-arriving dimension members the way the repo does (inferred/stub
   members updated later, or fail-and-retry).

8. **Partition alignment.** If the target table family is partitioned, the new table joins the
   existing partition function/scheme. If sibling loads use partition switch, create the
   switch-aligned staging table: same filegroup, same indexes, check constraint matching the
   target partition.

9. **Deployment.** Schema changes go through the repo's one existing vehicle — SQL project
   build, migration-scripts folder, or dbt — never ad-hoc scripts against the server. Review
   the generated/authored DDL before it ships.

10. **Review checklist (sign-off before merge).**
   - Rerun safety: running the load twice for the same batch yields identical target row
     counts (or, for versioned runs, exactly one run marked current).
   - No business-key duplicates in the current/active rows of the target.
   - Reconciliation: staging vs target row counts match or the difference is explained
     (rejected rows, dedup).
   - History spot-check: change one attribute on one record, rerun, verify the expected
     old/new row shape.
   - Orchestration order verified: the new load runs after every dimension it references.
   - No dimension was created that duplicates one already in the warehouse: every foreign key on the
     key list names an existing dimension, an indirect path through one, or a new dimension with the
     search that justified it.
   - Every fact foreign key resolves to a dimension row, and the count routed to the
     unknown/inferred member is **reported** — not assumed to be zero.
