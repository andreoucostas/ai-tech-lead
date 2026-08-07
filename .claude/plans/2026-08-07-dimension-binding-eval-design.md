# Dimension-binding: eval design + skill change — LOCKED 2026-08-07

Design spec for the `add-warehouse-load` dimension-binding gap. Adversarially critiqued before
implementation (codex `sol`, read-only, against the tree): 6 blocking findings, 5 accepted. The
sixth (pure-SQL installability) was retired when the maintainer corrected the target repo shape —
**all target repos have a .NET back end alongside the SQL warehouse.**

---

## 1. The gap

`add-warehouse-load` goes from step 1 (find a load pattern to copy, `SKILL.md:28`) straight to step 2
"Design the entity" (`:39`) and never asks *whether the business concept already has a compatible
dimension*. Adjacent guidance exists — FKs use surrogate keys (`:43`), follow existing SCD (`:74`),
dimensions before facts with the repo's late-arrival behaviour (`:80`), checklist verifies load order
(`:103`) — but the **reuse decision itself** is absent. The only mentions of conformed dimensions or
reuse anywhere in the product are in `map-warehouse`, i.e. the read side.

Verification Rule 11 routes the model to `docs/warehouse-map.md`, which since B-96 carries an
inventory with business keys and a fact→dimension edge list. Reading evidence does not force a
decision.

## 2. What the current measurement cannot see

Every warehouse scenario runs against `Initialize-WarehouseScenario` (`run-agent-evals.ps1:25-80`):
a bare SQL tree with a `.sqlproj`, **no `.csproj`, no EF Core, no C#**. In that fixture `add-entity`
is not a plausible competitor. In the target repos it is — its trigger is "a new entity backed by a
new database table", which is what "implement a new import" looks like from outside. The
disambiguation exists in both skills' `DO NOT USE FOR` lines, but that is **frontmatter**, the
channel measured firing 0/6 in v0.48/v0.49. Asserted, never tested, in the configuration that matters.

## 3. The feed (fixture input)

`supplier_invoice_line`, landed as `stg.StgSupplierInvoice`, target `fact.FactSupplierInvoice`.
Chosen so that **no new dimension is required** — the maintainer's stated reality ("most new loads
wouldn't need new dimensions") — and so each named failure mode is separately observable.

| source column | correct binding | what it discriminates |
|---|---|---|
| `invoice_no` | **degenerate** — stays on the fact | creating `DimInvoice` is a false-new-dimension |
| `line_no` | part of the grain | — |
| `cust_ref` | existing `dim.DimCustomer` via `CustomerId` | concept-not-name matching; duplicate-dimension risk |
| `prod_ref` | existing `dim.DimProduct` via `ProductId` | concept-not-name matching |
| `invoice_date` | existing `dim.DimDate` via `CalendarDate` | plain reuse |
| `region_name` | **snowflake** — reached via `DimCustomer.RegionKey`, NOT a fact FK | the trap sol identified; `rpt.vwFinanceExtract` joins `FactSales → DimCustomer → DimRegion` |
| `net_amount`, `tax_amount` | additive measures | — |

**Grain:** one row per supplier invoice line.

## 4. Allowed-correct set (what must NOT be failed)

A correct implementation may:

- name the staging/fact tables differently, or place them in any `.sql` file — the grader scans the
  whole SQL tree for `CREATE TABLE … fact.<name>`, it does not require exact paths;
- extend existing DDL rather than create new files;
- use any schema qualification style (`fact.X`, `[fact].[X]`, unqualified);
- resolve `DimDate` by `DateKey` in either `yyyymmdd` or lookup form;
- omit `region_name` from the fact entirely (correct), **or** carry it as a degenerate descriptive
  column explicitly justified as denormalised — but *not* as a `RegionKey` foreign key.

A correct implementation must **not**: create any new `dim.*` table; put `cust_ref`/`prod_ref`
natural keys on the fact in place of surrogate keys; add `RegionKey` as a fact FK.

## 5. Grader — `warehouseDimensionBinding`

Reuses the `warehouse-route-*` channel machinery (`run-agent-evals.ps1:496-528`) rather than
inventing a second scheme. Four **independent** outcomes, per the approved plan:

| key | outcome | source |
|---|---|---|
| `category` | map/skill reach: `BOTH`/`SKILL_ROUTED`/`SKILL_READ`/`MAP_DISCOVERED`/`DELEGATED_UNKNOWN`/`NEITHER` | C1–C5, retargeted to `add-warehouse-load` |
| `reachedAddEntity` | did `add-entity` fire or get read **instead** | `Skill` tool `skill=add-entity`, or Read of `.{claude,github}/skills/add-entity/SKILL.md` |
| `newDimensions` | `CREATE TABLE dim.*` absent from the root commit — the duplicate-dimension detector | git diff vs root commit over the SQL tree |
| `boundCustomer` / `boundProduct` / `boundDate` | fact carries the surrogate key, not the natural key | fact DDL + load proc join |
| `regionOnFact` | `RegionKey` added as a fact FK — the snowflake violation | fact DDL |
| `naturalKeyOnFact` | `cust_ref`/`prod_ref` stored on the fact | fact DDL |

`Pass` = all three bound **and** `newDimensions` empty **and** not `regionOnFact` **and** not
`naturalKeyOnFact`.
`Status` = `INCONCLUSIVE` when no new/changed `.sql` exists and no warehouse-tree tool call was made
— matching the existing `artifactWritten`/`warehouseTreeCall` convention so a non-engaging run is not
scored as a failure.

**Reachability (Maintenance model #4, both directions).** The world in which this registers success is
constructible and is written down as fixture `positive`: a fact with `CustomerKey`/`ProductKey`/
`InvoiceDateKey` FKs, `InvoiceNo` degenerate, no new `dim.*`, no `RegionKey`. The world in which it
registers failure is fixture `mutant`: identical but with `CREATE TABLE dim.DimInvoiceCustomer` and
`RegionKey INT` on the fact. Both are asserted in the harness self-test, so the grader is proven to go
red **and** green before any live run.

## 6. Fixtures

- **`warehouse`** (existing) — **left byte-identical.** Its `docs/warehouse-map.md` is pre-B-96
  ETL-only (no inventory, no business keys, no edge list), which v0.48.0 recorded as unable to carry
  what a binding measure needs. The obvious move is to regenerate it — **do not.**
  `meta/eval-results.md:374` ties the recorded `0/6 → 6/6` (`p≈0.002`) result to "same scenarios,
  grader, **fixture**, model and host; only the rule differs". Changing the shared map silently
  retires the comparability of the framework's only pre-registered behavioural result.
  Instead: `Initialize-WarehouseScenario` gains an opt-in **`-EnrichedMap`** switch emitting the B-96
  seven-heading map, used only by the new fixture. `-OmitMap` and the default path are unchanged, so
  `warehouse-map-quality` and `warehouse-route-p1..p3` keep their exact current inputs.
- **`warehouse-mixed`** (new) — the same SQL tree plus a minimal but genuine .NET side: `.sln`, an API
  `.csproj`, a `DbContext` with two EF Core entities and an `IEntityTypeConfiguration`, a migrations
  folder. This is what makes `add-entity` a live competitor. Running both isolates whether any
  mis-route is caused by the .NET side's presence.

**The fixture map carries evidence, never conclusions — added 2026-08-07 after this rule was broken
and a live run had to be voided.** The first `-EnrichedMap` draft said, in bold under the edge list,
*"Region is not a direct fact dimension. There is no RegionKey on fact.FactSales."* `regionOnFact` is
one of the four things the grader scores, so the fixture stated the answer and the run measured the
map's helpfulness rather than the model's binding discipline. `run-agent-evals.ps1:429-431` already
warned about precisely this for the fixture's `CLAUDE.md`; the defect was reproduced one artifact
over. The map may contain the edge-list row `dim.DimCustomer | RegionKey | dim.DimRegion` — that is
what a real `map-warehouse` run emits and it is evidence — but no sentence that resolves what a *new*
fact should do with it. Enforced by a red-tested guard in the harness self-test.

## 7. Skill change (Stage B — body only)

Budget: monorepo `static.claude` is 47,884 of a hard 48,000 ceiling (116 chars). Skill **bodies** go
to `ondemand-info` and are free; **frontmatter counts**. Therefore: no frontmatter edits, which also
means the `add-entity`/`add-warehouse-load` disambiguation cannot be strengthened where it currently
lives. Hence B2 below.

- **B1 — new step 2, "Bind to existing dimensions."** Default stated first (most loads need no new
  dimension). Three-way classification of every non-measure source column: reaches an existing
  dimension / degenerate / genuinely new. Match on concept and business key, not column name. Three
  checks a name match misses: **snowflake/indirect reach**, **grain compatibility**, **conformed use**.
  "Genuinely new" must name what was searched. Output artifact: the fact's key list, written before
  any DDL — one line per FK giving dimension, path (direct or through which dimension), business key,
  existing or new.
- **B2 — mixed-repo boundary line.** One line in the body: this recipe governs warehouse tables in the
  SQL tree; an application table backed by the `DbContext` is `add-entity`'s. Addresses the
  `reachedAddEntity` failure mode without spending frontmatter budget.
- **B3 — fact branch + load step.** Fact branch consumes the key list rather than re-deciding. Load
  step gains surrogate-key resolution by lookup (Type 2 → the version that applied, copying the repo's
  as-of rule from a sibling load) and an explicit **miss behaviour** decision: inferred/stub member,
  `Unknown`/`-1`, or fail-and-retry. Silently dropping unmatched rows is how a fact's totals go wrong.
- **B4 — two review-checklist lines.** No duplicate dimension; every FK resolves, with the
  unknown/inferred count reported rather than assumed zero.

## 8. Sequencing (non-negotiable)

The Stage A baseline must be captured **against the unmodified dist**. Shipping Stage B first
contaminates it. Order: build fixtures + grader → self-test the grader red and green → pre-register
thresholds in `meta/eval-results.md` → capture baseline → Stage B → re-measure.

## 9. Deliberately excluded

- **Stage D** (write-side guidance copied into the emitted `docs/warehouse-map.md`) is **conditional**
  on the baseline showing map-opened-but-skill-not. `add-warehouse-load:28-32` already declares the map
  a snapshot where code wins; putting normative procedure into a one-time discovery artifact creates an
  authority conflict. If built: durable facts only, snapshot-labelled, skill and code normative, no
  frozen "dimensions to reuse" list.
- A `validate-dist` skill-mirror check — that gate already exists (`template-checks.ps1:144`, B-07).
- Repairing skill routing generally (B-98's open general question).
- Execution against a live database (WSD-021).
