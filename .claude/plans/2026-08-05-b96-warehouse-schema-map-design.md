# B-96 design — `map-warehouse` maps the ETL, not the warehouse: add the schema/relationship model (LOCKED 2026-08-05)

> **Status: DESIGN LOCKED. Not implemented.** Deviations need a new entry in `meta/workspace-decisions.md`.
> Trigger: maintainer field report (2026-08-04) from a consumer warehouse, plus a structural reading
> of the shipped skill. Two earlier revisions of this design were rejected by independent adversarial
> review; §6 records the disposition. No WSD is consumed — WSD-021's no-execution property stands.

---

## 1. Problem

`map-warehouse` emits one row per entity over eight fields — `entity | layer | grain | load
proc/pipeline | orchestrated by | rerun protection | SCD | partitioning`
(`src/stacks/dotnet/files/.claude/skills/map-warehouse/SKILL.md:76-84`). Every one of those is a
**loading** property. The map contains no schema inventory, no columns, no primary keys, no foreign
keys, and no relationships. Columns appear only as table-classification signals (`EffectiveFrom`,
`IsCurrent`, `RowHash`, `:33`).

The skill is therefore an **ETL map, not a warehouse map**, and the gap shows the moment a developer
asks for help with the most common warehouse task there is: writing a report. The framework can say
how `FactSales` is loaded and whether that load is re-runnable. It cannot say what `FactSales` joins
to, or which dimension owns an attribute. For a framework whose role is tech lead, that is the wrong
half of the warehouse.

This is observable by reading the skill; it does not rest on the field report. The field report is
what the gap costs.

**Field report (2026-08-04).** A consumer warehouse, onboarded and already mapped, was asked to
replicate a report built in a *different* warehouse. The model reached a dimension attribute through
a spurious column — declared in DDL, never populated — instead of following a fact key to the
dimension purpose-built for that result. It could not have gone otherwise: with no relationship
model available, the only evidence in reach was the column's **name**. No transcript exists, so
whether the skill fired is unknown; §5 carries a cheap check rather than an assumption.

Note what the map *does* already have and discard: step 1 identifies the consumption surface — "the
reporting views/marts users actually query" (`:40-45`) — and step 7 records which views each entity
feeds (`:81-84`). Those views contain the correct joins. The skill opens them and extracts nothing
from them.

## 2. Locked decisions

1. **Extend `map-warehouse`; ship no new skill.** The content belongs to the skill that already owns
   warehouse discovery. A second selectively-routed skill adds a routing bet without removing one.
2. **Detail on demand, pointer in context** — the framework's existing pattern, stated in its own
   rationale comment at `src/core/CLAUDE.md:95-97`: *"CLAUDE.md loads on nearly every agent turn and
   anchors the prompt cache — keep it small; detail loads on demand."* The model goes in
   `docs/warehouse-map.md` (a consumer-repo artifact, never shipped static context); `CLAUDE.md >
   Conventions > Data Access` gets a one-line index entry, mirroring Architecture Decisions
   (`src/core/CLAUDE.md:92-100`).
3. **Confidence is explicit and abstention is the default.** Every relationship records how it was
   learned, with `UNRESOLVED`/`CONFLICTING` as first-class states. Naming convention alone is never
   sufficient to assert an edge.
4. **Cost is tiered by evidence source.** DDL-derived facts and consumption-view join predicates ride
   on scans the skill already performs. Dataflow tracing through load procedures does not, and stays
   off the default path.
5. **No execution.** WSD-021's grep-only property is preserved. An opt-in profiling tier was
   considered and rejected (§6).
6. **Dist scope unchanged from B-40**: dotnet-authored, flows to `dist/monorepo`, absent from
   `dist/angular`.

## 3. Design

### 3.1 What the map gains

Emitted into `docs/warehouse-map.md` alongside the existing load tables:

- **Table inventory** — every table with schema/layer, classification (fact / dimension / bridge /
  staging / control), and its **primary key**, recording a dimension's surrogate key and its
  natural/business key separately.
- **Relationship edge list — the primary artifact.** Per fact, one row per FK column:

  ```
  | fact | fk column | → dimension | role | evidence | confidence |
  ```

  This, not a matrix, is what answers "which dimension do I reach from this fact".
- **Dimensional semantics reporting depends on** — fact type (transaction / periodic snapshot /
  accumulating snapshot), role-playing dimensions (one physical dimension reached by several FKs,
  e.g. `OrderDateKey` and `ShipDateKey` both → `DimDate`), conformed dimensions (shared across
  facts), degenerate dimensions (dimension-like attributes carried on the fact), and measure
  additivity where the load reveals it.
- **Coverage statement** — what could not be read (`.dtsx` binaries, dynamic SQL, externally-held
  pipelines) and how many facts carry unresolved edges. A map silent about its own blind spots is
  what let a naming guess look like knowledge.

### 3.2 Evidence and confidence (locked decision 3)

| Evidence | Confidence | Note |
|---|---|---|
| `FOREIGN KEY … REFERENCES`; dbt `relationships` test; Data Vault link | **Declared** | Strongest, but constraints can be disabled or untrusted — say so where visible |
| Join predicate in an existing reporting view/proc | **In use** | Shows the path the repo actually queries; usage, not proof of correctness |
| Load proc's surrogate-key resolution | **Load-derived** | Proves where the key value came from during that load — not which dimension owns a business attribute |
| Column naming convention only | **Unresolved** | **Never assertable.** Record the candidate and mark it unresolved |
| Two sources disagree | **Conflicting** | Record both and say so; do not pick |

The skill must instruct abstention explicitly: an unresolved edge is a correct output, and a wrong
confidence label is worse than no label — a guess presented as declared suppresses exactly the
scepticism that would send the agent to the reporting view. This is the field report's mechanism.

### 3.3 Cost (locked decision 4)

Primary keys, FK constraints and column lists come from DDL that step 2's *"Classify every table"*
(`:47-51`) already opens. Join predicates come from the consumption views step 1 (`:40-45`) already
identifies. Both are close to marginal — extraction from files already in hand.

Tracing a surrogate key's resolution through a load procedure's CTEs, temp tables, helper procs and
`MERGE` statements is a **second semantic pass**. It stays off the default path and is offered
scoped to a single fact on request.

No whole-warehouse bus matrix as a default artifact: at 60 facts × 120 dimensions that is 7,200
cells and nothing reads it. Kimball's *enterprise* bus matrix is a planning artifact over business
processes; the fact-level form is his *detailed implementation bus matrix*. Emit a matrix view only
for scoped subsets or small models.

### 3.4 Read-side guidance (in the skill, not in static context)

The rules that address the failure directly:

1. Start at the fact and state the grain before writing SQL.
2. Reach an attribute through a fact key to the dimension that owns it — never off a column that
   happens to sit on an already-joined table.
3. Copy an existing reporting view's join path before inventing one.
4. Treat a same-named column on an already-joined table as suspect until its provenance is known.
5. Replicating a report from another warehouse: write the source-column → target-concept mapping
   *before* any SQL; never assume same-named columns mean the same thing; name what is unresolved
   and ask rather than substitute.

Plus the two named path hazards: the **fan trap** (a chained one-to-many fans a measure and
double-counts) and the **chasm trap** (the many-sides of two facts joined at the wrong grain —
*not* merely two facts sharing a dimension, which is legitimate drill-across).

### 3.5 Routing

Broaden the skill's `description` to name writing or replicating a warehouse report. It already
advertises *"what feeds this report"* (`:10`), so it was eligible to fire — this makes the read-side
case explicit rather than adjacent.

### 3.6 The index line

When A2 finds warehouse signals, `CLAUDE.md > Conventions > Data Access` gains a one-line pointer to
`docs/warehouse-map.md`. `/bootstrap` A2 already writes warehouse essentials into that section
(`dist/dotnet/.claude/commands/bootstrap.md:56`).

**Known limitation, not solvable here:** `/bootstrap` replaces the entire Conventions section with
observed conventions (`src/core/CLAUDE.md:83-88`) and is `disable-model-invocation: true`
(`bootstrap.md:3`), so it is not re-run. A template edit therefore reaches **greenfield installs
only** — not the already-bootstrapped repos this is for. Filed as **B-97**; B-96 must not claim
delivery it does not have.

## 4. Files touched (at implementation)

- `src/stacks/dotnet/files/{.claude,.github}/skills/map-warehouse/SKILL.md` — byte-identical pair;
  steps 1–2 (extraction), a new relationship step, step 7 (report shape), the description, and the
  read-side section.
- `src/stacks/{dotnet,monorepo}/files/.claude/commands/bootstrap.md` — A2 index line (+ monorepo
  sibling, meta-invariant #1 / WSD-015).
- `src/stacks/dotnet/files/docs/defaults.md` — DW evidence block gains the pointer convention.
- Rebuild `dist/{dotnet,monorepo}`; `dist/angular` unchanged except the version-stamp changelog entry.
- Root `CHANGELOG.md` + shipped changelogs ×3; release via `.claude/scripts/release.ps1`.

## 5. Acceptance criteria

1. No `dist/*` artifact instructs a SQL technology unconditionally; the Step-0 evidence gate is
   unchanged and still passes/fails as B-40 specified.
2. Both `.claude`/`.github` copies byte-identical; present in `dist/dotnet` and `dist/monorepo`,
   absent from `dist/angular`.
3. `validate-dist` ×3, hook suites ×3, meta suite green; `no-meta-leak` passes on the new content.
4. **The skill emits `UNRESOLVED` where evidence is naming-only.** Verify on a fixture, not by
   reading the prose.
5. **Behavioural validation before ship** — run an incident-shaped prompt ("replicate this report,
   here is the source SQL") against a warehouse fixture with a labelled answer key containing: a
   declared FK; a key resolved via CTE; one via `MERGE`; a deliberately misleading column name (the
   field report's shape); two conflicting consumption joins; and dynamic SQL. Measure **abstention as
   well as precision** — the design question is whether the agent correctly says "unknown". Reuse the
   B-41 eval harness; do not build a second one.
6. **B-98 step 1 is a prerequisite, not a criterion.** Whether `map-warehouse` fires at all on an
   incident-shaped prompt must be settled *before* implementation begins: if it does not fire, this
   content work never reaches the developer however good it is, and §3.5's description change is
   insufficient. Filing it as an acceptance criterion here was wrong — it would only ever run once
   the work it gates was already underway.
7. Context footprint: `meta/context-footprint.json` static totals must not regress past their
   ceilings (dotnet 40,000; monorepo 48,000). Headroom is thin — dotnet was 38,571 at design time.

## 6. Review disposition

Two independent adversarial reviews rejected earlier revisions. Accepted:

- **"Nearly free" was overstated** — corrected into locked decision 4 and §3.3. DDL and consumption
  views ride on existing scans; load-proc dataflow does not, and is now off the default path.
- **A mislabelled confidence tier is worse than none** — the strongest finding. Drove locked decision
  3, the `UNRESOLVED`/`CONFLICTING` states, and acceptance criterion 4.
- **The bus matrix does not scale and was misappropriated** — Kimball's enterprise matrix is a
  planning tool over business processes. Edge list is now primary (§3.3).
- **Static-context budget** — resolved by locked decision 2 (index line, not content); criterion 7
  guards it.
- **Delivery cannot reach bootstrapped consumers** — accepted and *not* solved here; §3.6 states the
  limitation and B-97 owns it.
- **Sequencing: prove the skill fires before designing content** — accepted. The content gap is
  established structurally rather than inferred, so *designing* it proceeds; but the routing check is
  a **prerequisite to implementation**, filed as B-98 step 1 (criterion 6). The first cut of this
  design demoted it to a ship gate, which inverted the dependency — the check would only run once the
  work it gates was underway. The reviewer's framing ("not a downstream side investigation; it is the
  prerequisite that determines whether B-96 addresses the incident at all") was right as written.

**Rejected alternatives.** *A new `query-warehouse` skill* — adds a routing dependency without
removing one; the content belongs where warehouse discovery already lives. *An opt-in profiling tier
executing `COUNT`/`COUNT(DISTINCT)` against a live connection* — declared constraints plus
consumption evidence recover most of its value; execution introduces a production-connection hazard
the framework has no mechanism to bound, and "the developer confirms" is weak when the model authors
the statement. WSD-021 stands. *Whole-warehouse attribute-authority and frequency analysis* — the
cost objection is correct; scoped to one fact or one report, on request.

## 7. Out of scope

No angular content change; no new hooks; no `src/core` behavioural edits beyond the Conventions index
line; no SQL-Server assumption made unconditional; no query *tuning* guidance; no new dist; no
execution against a database; no fix for B-97's delivery gap.
