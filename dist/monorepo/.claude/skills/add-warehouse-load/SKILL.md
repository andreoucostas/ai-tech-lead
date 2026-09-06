---
name: add-warehouse-load
description: >
  SQL data-warehouse repos only — verifies before scaffolding. Add a new fact or dimension
  load, or extend an existing one, deriving only the applicable staging → warehouse pattern from
  first-party evidence; conflicting evidence and correctness-material gaps remain unresolved.
  Covers staging, the load procedure, batch/watermark control wiring, slowly-changing-dimension
  handling, load ordering, partition alignment, and the deployment path.
  USE FOR: a new fact or dimension table plus its load, a new source feeding an existing
  table, adding columns to a dimension or fact (including the history implications).
  DO NOT USE FOR: OLTP entities (use add-entity), one-off data corrections, understanding or
  mapping the warehouse (use map-warehouse), report/query tuning.
---

# Add or Extend a Warehouse Load

Match CLAUDE.md > Conventions > Data Access. Derive the applicable target-family pattern before
choosing a mechanism; preserve its evidenced rerun, grain, and reconciliation safety.

## Project-derived pattern authority

Derive this operation's shape from first-party implementation, configuration, tests, and owner documentation. If this skill's consumer-owned `references/project-pattern.md` exists, read it on demand as scoped evidence. Generated recipes are leads only. Exclude irrelevant scope, investigate conflicting applicable evidence, and ask or retain only correctness-material uncertainty. The generic steps below are conditional fallbacks: they never authorize a container, library, layer, interface, or token the project does not evidence.

0. **Confirm this repo is a SQL data warehouse with the shared classifier.** Run
   `pwsh -NoProfile -File scripts/warehouse-map-check.ps1`. The command
   and `scripts/warehouse-signals.tsv` are the authoritative applicability gate used by bootstrap.
   Continue when it reports `WAREHOUSE_MAP missing`, `stale`, or `current`. If it
   reports `WAREHOUSE_MAP not-applicable`, STOP and follow the repo's actual persistence pattern
   or a project-specific skill. If it exits 2, do not guess; report that applicability could not
   be determined. Do not recreate a second warehouse-signal threshold in this skill.

1. **Establish current warehouse evidence, then find the pattern to copy.** A current
   `docs/warehouse-map.md` is preferred, but the artifact is optional: if the check above reports
   it missing or stale, inspect the live SQL/schema/view and orchestration definitions and
   write down the equivalent table, business-key, relationship, and load-order inventory before
   continuing. **Do not design a dimension from absent or stale evidence.** The map is a snapshot, not a
   live view** — nothing refreshes it when the warehouse changes. Before copying a pattern out
   of it, confirm the entities and load procs it names still exist in the SQL tree; where the
   map and the code disagree the code wins — re-run `map-warehouse` rather than trusting it
   further. Locate 1–2 existing loads in the same target family and derive their applicable
   naming, staging, procedure, error-handling, logging, and control conventions. Do not impose
   one warehouse-wide style or copy an irrelevant family. If no comparable load exists, ask the
   developer before inventing one.

2. **When the evidenced target family uses dimensions, bind to the existing model before designing anything.** Most such loads need
   **no new dimension**. A duplicate dimension can split one business entity across distinct key spaces,
   leaving reports inconsistent without a load failure.

   Take every source column that is not a measure and put it in exactly one of three buckets:
   - **Reaches an existing dimension.** Match on the **concept and its business key, not the column
     name** — a source's `cust_ref` and `DimCustomer.CustomerCode` are one key under two names, and
     a same-named column in two systems is routinely not the same thing. The table inventory in
     A current `docs/warehouse-map.md`, or the live inventory produced in step 1, lists each
     dimension's natural/business key; that is the list to search.
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
   governs the warehouse target family evidenced in the SQL tree. A table backed by the application's
   persistence model belongs to that project's applicable OLTP entity/persistence route, which must
   be derived from its own evidence.

3. **Design the target from its evidenced family.**
   - Where the family uses dimensions, follow its established natural/business-key, constraint,
     history, and key strategy; use surrogate keys only where that family evidences them.
   - Write the grain statement before changing a fact-like target — one sentence saying what one
     row represents. Preserve the evidenced relationship-key strategy rather than re-deciding it.
     A column with no established owner remains unresolved until its role is evidenced. Classify
     measures when the family uses measures, preserving its additive/semi-additive/non-additive
     semantics.

4. **Staging, where the target family uses it.** Follow the sibling landing and typing strategy —
   truncate-and-load, append-with-batch-id, or another evidenced mechanism. Do not require loosely
   typed staging; preserve the family’s validation and traceability controls, including a run/batch
   identifier where it evidences one.

5. **Preserve rerun safety through the target family’s evidenced mechanism.** For a target that
   appends, merges, or otherwise can duplicate data, the same input must not create an unintended
   second result and a rerun after mid-run failure must remain safe. Use the repo's existing mechanism:
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

   **Where the target family resolves dimension keys, use its evidenced lookup and miss handling.**
   Follow its relationship-key and as-of rules rather than assuming business-to-surrogate lookup.

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

   Do not silently drop unmatched rows or default every miss to one member. An evidenced
   reject/quarantine path is valid when it preserves the target family’s reconciled counts and
   makes the loss and reason visible; otherwise retain the miss as unresolved rather than hiding it.

6. **Slowly changing dimension (SCD) handling, where evidenced.** Apply the target family’s
   established history strategy; do not select Type 1, Type 2, columns, or keys from this recipe.
   For facts that change after load, follow the repo’s evidenced correction strategy.

7. **Ordering and orchestration, where the target family has dependencies.** Register the load
   through the evidenced orchestration and preserve its dependency order. Handle late arrivals
   through the project’s established policy; do not infer inferred members or fail-and-retry.

8. **Partition alignment.** If the target table family is partitioned, the new table joins the
   existing partition function/scheme. If sibling loads use partition switch, create the
   switch-aligned staging table: same filegroup, same indexes, check constraint matching the
   target partition.

9. **Deployment.** Use the applicable target-family deployment vehicle evidenced by the repo
   (for example SQL project build, migration-scripts folder, or dbt); do not choose one or run
   ad-hoc scripts against a server from this recipe. Review generated/authored DDL when that
   vehicle produces it.

10. **Review checklist (sign-off before merge).** Apply the checks the target family evidences:
   - Rerun safety: a repeated input preserves the family’s intended result, including after a
     recoverable mid-run failure where that scenario applies.
   - Grain/cardinality: target counts and relationship cardinality match the documented grain.
   - Reconciliation: source/staging and target differences are explained through the project’s
     control mechanism (for example rejected rows or deduplication).
   - History and orchestration: exercise the applicable change-history and dependency-order paths.
   - For dimension/fact targets, justify new dimensions and report unresolved relationship-key
     rows through the project’s established policy rather than assuming zero.
