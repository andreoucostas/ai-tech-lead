---
name: map-warehouse
description: >
  SQL data-warehouse repos only — verifies before scanning. Map a warehouse codebase:
  layers (staging → warehouse → marts), tables with their keys and the fact → dimension
  relationships, entity grain, load orchestration and ordering, batch/watermark control,
  slowly-changing-dimension strategy, partitioning, and the reporting views on top.
  USE FOR: onboarding to a data-warehouse repo, seeing where an entity is loaded before
  changing it, refreshing docs/warehouse-map.md, writing or replicating a report or
  analytical query, answering "which loads touch table X", "what feeds this report", or
  "which dimension owns this attribute".
  DO NOT USE FOR: OLTP/application databases (EF Core or Dapper CRUD — follow the repo's
  data-access conventions), adding or modifying a load (use add-warehouse-load), tuning a
  single slow query.
---

# Map a SQL Data Warehouse

Match CLAUDE.md > Conventions > Data Access. Produces a structural map of the warehouse —
layers, entities, keys, relationships, loads, controls — so changes follow the patterns that are
already there, and so a report can be written against the joins the warehouse actually has.

0. **Confirm this repo is a SQL data warehouse with the shared classifier.** Run
   `pwsh -NoProfile -File scripts/warehouse-map-check.ps1`. The command
   and `scripts/warehouse-signals.tsv` are the authoritative applicability gate used by bootstrap.
   Continue when it reports `WAREHOUSE_MAP missing`, `stale`, or `current`: each means
   at least two independent warehouse signal categories were found. If it reports
   `WAREHOUSE_MAP not-applicable`, STOP — this recipe does not apply. If it exits 2, do not guess;
   report that applicability could not be determined. The richer patterns below are mapping
   guidance only, never a second activation threshold.

1. **Layers.** Identify each database/schema and its role: staging/raw (landing), ODS,
   warehouse core (dims + facts), marts, and the consumption surface — the reporting
   views/marts users actually query, and which core tables feed them (this is where grain
   mistakes and double-counting surface). Evidence: schema prefixes on `CREATE TABLE`/`CREATE
   PROC`/`CREATE VIEW`, database references in deployment scripts, and the direction of
   cross-schema `INSERT INTO ... SELECT` statements.

2. **Entities, grain, and keys.** Classify every table: dimension (surrogate key + natural/business
   key + descriptive attributes), fact (foreign keys to dimensions, date keys, measures),
   bridge (resolves a many-to-many between a fact and a dimension), staging (loose types, batch
   columns), control (run/audit metadata). For every fact, state its grain in one sentence — the
   grain is what exactly one row represents (e.g. "one row per order line per day"). A fact whose
   grain cannot be stated from its keys is a finding.

   From the same DDL you are already reading, record per table: its **primary key**, and for a
   dimension the **surrogate key and the natural/business key separately** — they are different
   keys with different join meanings, and conflating them is how a join silently changes grain.
   Record the column list too; you need it for step 3 and you will not get it more cheaply later.

3. **Relationships — the fact → dimension edge list.** This is the primary artifact of the map:
   it is what answers "which dimension do I reach from this fact, and how".

   | fact | fk column | → dimension | role | version resolution | evidence | confidence |
   |------|-----------|-------------|------|--------------------|---------|------------|

   **Enumerate candidates, not just constraints.** For every fact, emit one row for every declared
   foreign key **and** every column that looks like a dimension reference in its DDL or in a
   consumption-view join — key-suffixed columns, columns matching a dimension's surrogate or
   natural key, anything a reporting view joins on. Most warehouses declare few or no `FOREIGN
   KEY` constraints, so an edge list built only from constraints is usually empty and always
   useless. A candidate you cannot confirm is emitted as an `UNRESOLVED` row; it is never
   dropped for lack of proof.

   `role` is what the key means when one dimension is reached by several keys (e.g.
   `OrderDateKey` and `ShipDateKey` both → `DimDate`; the roles are "order date" and "ship date").

   `version resolution` belongs on the **edge**, not on the dimension — two facts can reach the
   same Type 2 dimension differently. Record one of:
   - **`Pinned at load`** — the key identifies exactly one dimension-version row, because the load
     selected the version that applied and stamped its surrogate key onto the fact.
   - **`Deferred to query`** — the key does not identify a single version: a natural/business key,
     or a *durable* key that every version row of the entity shares. The reader must select the
     version at query time.
   - **`UNRESOLVED`** — not determinable from the evidence in hand. Say so; do not guess, and see
     the cost note below before going looking.

   This column is what read-side rule 6 consults, so a wrong value here produces a wrong query.
   Prefer `UNRESOLVED` over a plausible guess.

   **Confidence is not optional, and abstention is the default.** Label every edge from what you
   actually saw:

   | Evidence | Confidence | What it does and does not prove |
   |----------|------------|---------------------------------|
   | `FOREIGN KEY ... REFERENCES`, a dbt `relationships` test, a Data Vault link | **Declared** | Strongest. Note where the constraint is disabled or `NOCHECK` — a declared-but-untrusted key still describes intent, not enforced data |
   | A join predicate in an existing reporting view or proc | **In use** | The path this repo actually queries. Usage, not proof of correctness |
   | The load procedure's surrogate-key resolution | **Load-derived** | Proves where the key value came from during that load. Does **not** prove which dimension owns a business attribute |
   | Column naming convention only | **UNRESOLVED** | **Never assertable.** Record the candidate, mark it `UNRESOLVED`, and say what evidence would settle it |
   | Two sources disagree | **CONFLICTING** | Record both readings and say so. Do not pick one |

   An `UNRESOLVED` edge is a **correct output**, not a gap in your work. A guess labelled
   `Declared` is worse than no label at all: it suppresses exactly the scepticism that would send
   the next reader to the reporting view to check.

   **Cost discipline.** Declared keys and column lists come from DDL step 2 already opened; join
   predicates come from the consumption views step 1 already identified; a load procedure's own
   insert/`MERGE` join is visible in the files step 5 opens anyway. All three are nearly free — do
   them by default. What is **not** free, and stays off the default path, is *tracing* a key's
   resolution through a load procedure's CTEs, temp tables and helper procs when it is not plain
   from the statement in front of you: that is a second semantic pass over different files. Leave
   the edge `UNRESOLVED` and offer the trace on request, scoped to one named fact.

   Do not attempt a whole-warehouse fact × dimension matrix. At 60 facts and 120 dimensions that is
   7,200 cells nobody reads, and it answers no question the edge list has not already answered.
   Emit a matrix only for a scoped subset the developer asks for, or a genuinely small model.

4. **Dimensional semantics a report depends on.** From the keys and measures already in hand:
   - **Fact type** per fact — transaction (one row per event), periodic snapshot (one row per
     entity per period), or accumulating snapshot (one row per process instance, updated as it
     progresses). Fact type constrains how rows may be combined across time; it does not by itself
     settle additivity, which is a property of each measure — classify the two separately.
   - **Role-playing dimensions** — one physical dimension reached through several keys (step 3's
     `role` column). A report that joins it once and filters on the wrong role is wrong silently.
   - **Conformed dimensions** — dimensions whose meaning, keys, values and grain are compatible
     across the facts that share them. That compatibility, not mere sharing of a name or a table,
     is what makes drill-across legitimate — and each fact must still be aggregated to the shared
     grain independently before the results are combined.
   - **Degenerate dimensions** — dimension-like attributes carried on the fact itself with no
     dimension table (order number, invoice number). Note them, because they look like the
     "attribute already on the fact" trap and are not.
   - **Measure additivity** where the load reveals it, per measure: fully additive; semi-additive
     (additive across some dimensions but not others — balances and levels commonly cannot be
     summed across time); or non-additive (ratios, percentages — sum the numerator and the
     denominator, then divide).

   Apply this evidence-gated modelling-health checklist to the artifacts already opened. Put each
   supported defect in its own **Findings** row, not only in this semantics section:
   - **Likely or Confirmed, according to evidence:** incompatible row identities coexist in one
     fact (for example event rows unioned with periodic summaries). Different measure additivity on
     one atomic row grain is not mixed grain.
   - **Likely:** repository structure implies a semi-additive measure may be summed along a
     non-additive dimension. **Confirmed:** an inspected consumer directly performs that unsafe
     aggregation. Inspect the measure's load and consumer in the same pass.
   - **Confirmed:** an evidenced fact-to-dimension relationship uses the dimension's business key
     where repository convention requires its surrogate key. A copied source identifier or
     name-only candidate edge is not enough; keep that `UNRESOLVED`.
   - **Confirmed:** repository identity rules and DDL directly disagree about whether dimensions
     have compatible meaning, keys, values, or grain.
   - **Confirmed:** seeded special-member keys have distinct governed states but expose the same
     consumer-facing label, making those states indistinguishable in reports.

   Never create an SCD finding merely because history markers or a change path were not found:
   cite the complete load statement that proves the declared strategy is contradicted, or record
   the unread/uncertain load under **Coverage**.

   **Modelling health deepening (on request).** When the developer names a fact or consumer, inspect
   only its immediately relevant allocation and consumption artifacts, then record what was and
   was not checked under **Coverage**:
   - **Confirmed:** repository cardinality rules require several dimension members per fact row,
     but one scalar key cannot represent them and no bridge or allocation owner exists. If a
     correct bridge/allocation owner already represents that relationship, do not flag it.
   - **Confirmed:** a named consumer multiplies two fact streams by combining them before it can
     pre-aggregate each independently to their common dimensional grain.
   Do not run this deepening by default or infer either defect from names or keys alone.

5. **Load flow and ordering.** Find the orchestration entry points: master procs that `EXEC` a
   chain, job/schedule scripts, `.dtsx` packages, pipeline JSON, or the dbt DAG. Trace each
   entity staging → warehouse. Record the load order — dimensions before the facts that
   reference them — and which loads run together in one batch/run.

6. **Control and idempotency mechanics.** For each load, find how a rerun of the same data is
   prevented or made safe: batch/run control tables, load IDs, watermarks/high-water marks,
   row-hash comparison, delete-and-reload windows, partition switch, or versioned runs (each
   execution writes a new run/version ID and supersedes the previous; consumers select the
   current version). State the mechanism per load. A load with no discernible rerun protection
   is a finding — it can load the same data twice.

7. **Slowly changing dimension (SCD) strategy.** Per dimension, determine how history is kept:
   Type 1 (overwrite, no history), Type 2 (new row per change with `EffectiveFrom`/
   `EffectiveTo`/`IsCurrent`), or mixed per-column. Note also whether the dimension carries a
   **durable key** that all version rows of one entity share, alongside the per-version surrogate
   key — that is what makes a `Deferred to query` edge possible, and step 3's `version resolution`
   column is where it gets recorded per edge. Where the load statement you are already reading
   makes the resolution plain, fill that column in now; where it does not, leave it `UNRESOLVED`
   rather than tracing for it. Also note how facts change after load: corrections as reversal
   rows, in-place updates, versioned snapshot runs, and how late-arriving facts (rows for an
   earlier period arriving after that period loaded) are handled.

8. **Partitioning and retention.** Where the repo evidences SQL Server, look for
   `CREATE PARTITION FUNCTION`/`SCHEME`, `SWITCH PARTITION` in load procs, sliding-window
   maintenance, columnstore indexes, and archive/purge jobs. In other dialects, look for the
   equivalent (native partitioning clauses, date-suffixed tables).

9. **Report.** Offer to write or refresh `docs/warehouse-map.md` with everything below — offer,
   don't force. If CLAUDE.md > Conventions describes the warehouse and the code disagrees, flag the
   drift; do not silently edit either. Use these seven headings verbatim, in this order, so the
   document is predictable to the next reader and to anything that checks it:

   1. **Table inventory**, one table per layer:

      | entity | layer | classification | grain | primary key | natural/business key |
      |--------|-------|----------------|-------|-------------|----------------------|

   2. **Relationship edge list** from step 3, with the `version resolution`, `evidence` and
      `confidence` columns intact — read-side rule 6 is unusable without the first, and the other
      two are what stop a candidate being read as a fact. Do not drop the `UNRESOLVED` rows when
      writing the document; they are the most useful rows in it.
   3. **Loading**, the existing per-entity view:

      | entity | load proc/pipeline | orchestrated by | rerun protection | SCD | partitioning |
      |--------|--------------------|-----------------|------------------|-----|--------------|

   4. **Dimensional semantics** from step 4, and the views/marts each entity feeds.
   5. **Coverage** — state plainly what you could not read (`.dtsx` binaries, dynamic SQL,
      externally-held pipelines, procs not in this repo), how many facts carry `UNRESOLVED` edges,
      and which. A map that is silent about its own blind spots is what lets a naming guess look
      like knowledge.
   6. **Findings** — evaluate the checks established above: unstated or mixed grain, incorrect
      measure additivity, evidenced natural-key relationships, incompatible conformance, ambiguous special members, loads without rerun
      protection, evidenced SCD inconsistency, disabled declared keys, and conflicting join paths.
      Include allocation gaps and fact-stream multiplication only when modelling-health deepening
      was requested. Report each finding as:

      | finding | entity | evidence | finding confidence | severity if confirmed | consequence | remediation |
      |---------|--------|----------|--------------------|-----------------------|-------------|-------------|

      Finding confidence is separate from relationship-edge provenance: use **Confirmed** only
      where the cited repository evidence proves the defect without an interpretation gap,
      **Likely** for a strong structural signal that still needs repository context, and
      **Possible** for a weak signal that needs developer confirmation. Severity describes impact
      *if the finding is correct*: **blocking** for silently wrong or double-counted numbers,
      **significant** where a report author would be misled without totals necessarily being wrong,
      and **advisory** for a convention preference with no demonstrated numeric consequence.
      Always cite the concrete file/table/column or conflicting paths, state the consequence, and
      suggest the smallest remediation. If remediation changes schema, say that impact analysis is
      required first; do not invent migration cost or downstream consumers. If `CLAUDE.md` >
      Conventions > Data Access or `docs/defaults.md` explicitly and coherently permits the pattern,
      record the convention instead of calling it a defect. Do not emit an empty placeholder row.
   7. **Querying this warehouse** — the section at the end of this file, copied into the document,
      adjusted to name the facts and dimensions you actually found. It belongs in
      `docs/warehouse-map.md` rather than staying here: the person about to write a report opens
      the map, not this recipe, and these rules are only useful to whoever is holding it. Do not
      summarise it away; rule 6 in particular is unusable without its three cases.

Results are grep-based structure detection, not execution — confirm against a load run or the
team before relying on them for a destructive change.

---

## Querying this warehouse

> Everything from this heading to the end of the file is what step 9.7 copies into
> `docs/warehouse-map.md` — heading included, this blockquote excluded. Adjust the wording to
> what you actually found (name the real facts and dimensions); do not drop a rule.

Rules for reading the warehouse, not loading it. They address the ways a report goes wrong
quietly — producing a number, not an error.

1. **Start at the fact and state its grain** in one sentence before writing any SQL. If the
   grain is not clear, that is the first thing to resolve.
2. **Reach an attribute by following a fact key to the dimension that owns it.** Never read it
   off a column that merely happens to sit on a table already in the join. A column that is
   declared in DDL but never populated by any load looks identical to a real one in a `SELECT`
   list — and returns `NULL`s or blanks, not an error.
3. **Copy an existing reporting view's join path before inventing one.** The consumption views
   are the joins this warehouse is known to answer correctly. If two views disagree, that
   conflict is in the map's edge list; raise it rather than picking.
4. **Treat a same-named column on an already-joined table as suspect** until you know which table
   populates it. Same name is not same meaning, and it is not evidence of a relationship.
5. **Replicating a report from another warehouse: write the source-column → target-concept
   mapping before any SQL.** Same-named columns across two warehouses are the trap this rule
   exists for. Name what is unresolved and ask — do not substitute the nearest-looking column.
6. **Add an effective-date predicate only when the key does not already identify one version.**
   The discriminator is a property of the *edge*, and the map's edge list records it as
   `version resolution`:
   - **`Pinned at load`** — the load found the dimension version that applied and stamped that
     version's surrogate key onto the fact. The version is already chosen, so adding
     `EffectiveFrom`/`EffectiveTo`/`IsCurrent` to that join **silently drops every fact pointing
     at a superseded row.** This is the dangerous case: it yields a low row count, not an error,
     and in review the extra predicate reads as *more* careful rather than less.
   - **`Deferred to query`** — the key does not pick a version on its own: a natural/business key,
     a durable key shared by every version row of the entity, or a run/version/snapshot register
     where several rows are live and exactly one is current. Here the temporal predicate is
     **required**, and omitting it multiplies or mis-selects rows. Use the warehouse's own
     as-of rule, copied from a reporting view rather than invented.
   - **`UNRESOLVED`** — do not choose. Copy an existing view's join for that edge, or ask.

Two named path hazards:

- **Fan trap** — joining a chained one-to-many below the fact multiplies the fact rows and
  double-counts the measure. Aggregate at the fact's own grain, or aggregate the many-side
  separately before joining.
- **Chasm trap** — joining two facts directly through a shared dimension multiplies their rows
  within each shared key group, inflating both measures. This is *not* an argument against two
  facts sharing a conformed dimension, which is legitimate drill-across: aggregate each fact to
  the shared grain independently first, then join the two aggregates on the shared keys.

If the map marks an edge `UNRESOLVED` or `CONFLICTING`, that is the map telling you it does not
know — treat it as a question to ask, not a gap to fill with the most plausible-looking column.
