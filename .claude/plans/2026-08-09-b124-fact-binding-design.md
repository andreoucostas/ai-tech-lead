# B-124 design — bind a warehouse change to the right fact shape before DDL (REJECTED 2026-08-09)

> Design gate for `meta/BACKLOG.md` B-124. Implementation is prohibited until this document has
> received the filed independent Claude Opus adversarial review, its findings have been verified
> against the repository, an old-skill baseline has demonstrated the premise, and the corrected
> revision has been re-reviewed and locked.

> **Historical interruption (2026-08-09, subsequently cleared):** Opus rev-2 review returned
> **REDESIGN** because the first
> baseline telegraphed its answers and used `n=1`. The fixture, prompts, and red worlds were
> corrected per that review. The pre-registered `n=2` non-telegraphing ambiguous-pair run then hit
> Claude's monthly spend limit (HTTP 429) during the first case and before the second. Both runs are
> invalid. Per B-124's filed gate, implementation is `WAITING — OPUS LIMIT`; do not substitute a
> different model. Resume by running both ambiguous scenarios twice on Sonnet, unchanged from the
> current checked-in instrument.

## 1. Observed harm and proportionality

`add-warehouse-load` makes dimension reuse explicit, but after its key-list gate it moves straight
to “Design the entity.” For a fact it asks only for a grain sentence. It never asks whether the
requested event or measure belongs in an existing transaction fact, a periodic snapshot, an
accumulating snapshot, or a new fact. The repository therefore contains a permitted instruction
path from “find a comparable load” to new-fact DDL without a fact-binding decision, and the inverse
path permits extending a similarly named fact without checking lifecycle, authority, or consumers.
This is an observed instruction gap, not yet an observed agent failure: the design cannot lock until
§4's old-skill-on-new-fixture baseline demonstrates at least one ambiguous-pair failure.

The proportionate fix is one bounded decision section in the write recipe that owns the choice,
plus a focused behavioral fixture/grader. A smaller gate — “state the grain, name one candidate,
and stop at the first incompatibility” — would catch obvious mixed grain cheaply, but would leave
same-grain facts with incompatible lifecycle, source authority, load semantics, or consumers
unprotected. The chosen comparison is bounded to facts for the named process and may be a compact
one-row note for one candidate; it does not require an eleven-column rendered table when prose
records every axis unambiguously. It adds no skill, second inventory, mandatory whole-warehouse
profiling, or B-125 modelling review.

## 2. Approaches considered

### A. Add a fact-binding gate to `add-warehouse-load` (chosen)

Insert a new step after dimension binding and before entity design. The model writes a short
fact-binding note from current warehouse evidence and live SQL before any DDL. This is the point of
decision and the smallest surface that prevents both unnecessary new facts and mixed-grain
extensions. `map-warehouse` remains the read-side evidence owner.

Cost: every fact change pays a small bounded analysis cost. Dimension-only work marks it not
applicable; candidate discovery is limited to the named business process.

### B. Put the decision only in `map-warehouse` (rejected)

The map can report existing fact shape but cannot know the proposed event or measure. Requiring a
fresh map for every change would contradict WSD-033: the document is optional while warehouse
evidence is mandatory as a write input. This observes the warehouse but does not intercept writes.

### C. Create a separate `choose-warehouse-fact` skill (rejected)

This splits one change across two selectively routed skills and creates a route that must fire before
`add-warehouse-load`. It adds no evidence source and violates B-124's no-second-workflow constraint.

## 3. Shipped instruction design

Change both byte-identical authored copies:

- `src/stacks/dotnet/files/.claude/skills/add-warehouse-load/SKILL.md`
- `src/stacks/dotnet/files/.github/skills/add-warehouse-load/SKILL.md`

The composer carries them into `dist/dotnet` and `dist/monorepo`; Angular receives only a release
note. The monorepo skill-list snippet and whole-file `AGENTS.md` sibling were reviewed: because the
description remains unchanged neither needs a source edit, but generated monorepo content must be
inspected after composition.

Add **“Bind the change to a fact shape — before DDL”** after current step 2. It applies to a new
fact, measure/business event, or existing-fact change; dimension-only work says `not applicable`.
It must:

1. State the proposed atomic row grain and business process/event. Similar table names discover
   candidates only; they never establish compatibility.
2. Inspect a current `docs/warehouse-map.md`, then verify candidates and loads in live SQL and
   orchestration. Extend step 1's no-map inventory to record candidate fact type/lifecycle, grain,
   dimensional roles, source and event cadence where evidenced, update/load semantics,
   measures/additivity, and directly evidenced consumers, in addition to its current table, key,
   relationship, and load-order fields. Unstated authority/frequency remains unresolved. Trace only
   candidate facts for the named process and directly evidenced consumers.
3. Compare each candidate on:
   `business process | atomic grain | fact type/lifecycle | dimensionality | event frequency |
   measure/additivity | source authority | update/load semantics | consumer contract | evidence |
   confidence`. Dimensionality means compatible roles and key resolution at the proposed grain.
   Consumer contract means evidenced views, marts, procedures, semantic definitions, or tests.
4. Produce exactly one evidenced outcome and trade-off:
   - **EXTEND EXISTING FACT** — compatible on every axis; name the fact and existing load.
   - **CREATE NEW TRANSACTION FACT** — distinct event or irreconcilable grain/lifecycle.
   - **CREATE PERIODIC SNAPSHOT** — regular state observation with semi-additive time behavior.
   - **CREATE/EXTEND ACCUMULATING SNAPSHOT** — one process-instance row updated across milestones;
     extension requires the same instance grain and lifecycle.
   - **ABSTAIN** — name the missing fact, how to obtain it, and stop before DDL.
5. Treat one incompatible/unresolved axis as disqualifying unless repository evidence establishes a
   deliberate conversion. Do not average a score. Additivity alone cannot bind a fact; a new source
   alone does not demand one if it is authoritative for the same event and obeys the existing grain
   and idempotency contract.

The dimension key list and fact decision must agree. For **EXTEND**, the existing fact's evidenced
dimension roles and surrogate-key resolution are authoritative: reconcile the proposed list to them
and abstain on an unexplained conflict; never transcribe a contradictory new role. For creation, the
key list defines the new fact as before.

Current “Design the entity” becomes the next numbered step and consumes the outcome. The review
checklist requires the note, no mixed atomic grain, and named consumer impact. The description and
`map-warehouse` remain unchanged: the map already covers fact type, additivity, load semantics,
consumption, evidence, and confidence. B-125 is not a prerequisite.

## 4. Behavioral evaluation design

Extend the maintainer-only B-41 harness; fixture and grader code do not ship.

### 4.1 Fixture and exact scenarios

Add a distinct `warehouse-fact-binding` fixture stack. It may reuse builders but neither mutates nor
inherits the frozen B-98 `warehouse` inputs. It contains no `FactSales`, which would be a second
order-line candidate. Its live SQL/map contains:

- `FactOrderLine`: transaction fact, one row per order line, authoritative order source, quantity
  and net amount, consumed by an evidenced sales view;
- `FactOrderPipeline`: accumulating snapshot, one row per order, milestones updated in place;
- no periodic fact; `stg.StgDailyInventory` is the authoritative product-day source with
  `ProductId`, `SnapshotDate`, `ClosingOnHandQuantity`, and `BatchId`.

The following were the rev-2 requests; **superseded by §8's non-leading prompts before the valid
baseline**:

1. **Existing:** `Add DiscountAmount from the authoritative order-line source.` Expected
   `EXTEND EXISTING FACT FactOrderLine`; a new fact fragments the process.
2. **New:** `Add one row per payment allocation; one order line can have many allocations.` Expected
   `CREATE NEW TRANSACTION FACT`; extending `FactOrderLine` mixes grain.
3. **Snapshot:** `Add the daily product on-hand closing balance from the authoritative
   stg.StgDailyInventory feed.` Expected
   `CREATE PERIODIC SNAPSHOT`; no compatible periodic fact exists.
4. **Abstain:** `Add forecast amount.` The fixture deliberately supplies neither authoritative
   source nor declared grain. Expected `ABSTAIN` naming both missing facts and writing no DDL.

Exact endings:

- 1–3: `Implement this warehouse change in the repository. I approve the change in advance: do not
  stop for a plan or ask for confirmation; make the fact-binding decision and then implement the
  compatible DDL and load in this session.`
- 4: `Assess and implement this warehouse change only if repository evidence is enough to bind it
  safely. I approve any compatible change in advance: do not stop for a plan or ask for
  confirmation. If a required fact is missing, name it and abstain before DDL.`

The abstention ending differs deliberately because unconditional implementation makes success
unreachable. The first two are the required ambiguous pair; the others prove outcome reachability.

### 4.2 Grader

Add `warehouseFactBinding`, reusing existing routing channels. Report:

`status | category/channels | outcome | targetFact | grainStatement | ddlWritten | mixedGrain |
missingFacts | evidence`.

Scenario-specific pass conditions:

- existing: alter `FactOrderLine` and its load, create no second fact, preserve order-line grain;
- new: create a fact/load at payment-allocation grain; place no allocation keys/measures on any
  existing fact;
- snapshot: create a periodic product-day fact/load and classify balance semi-additive over time;
- abstain: after successful warehouse-tree reads, write no fact DDL/load, explicitly decide
  `ABSTAIN`, and name missing source authority and grain evidenced as absent by the fixture.

For scenarios 1–3, engaged-but-no-output remains `INCONCLUSIVE`, matching the existing convention.
For abstention only, engaged/no-DDL can pass under the conditions above; no engagement is
`INCONCLUSIVE`. This rule must not change `warehouseDimensionBinding`. Keywords alone cannot pass.

### 4.3 Instrument red/green proof

Build only the maintainer fixture/grader, then run the **old shipped skill on the completed new
fixture**. Record the baseline in `meta/eval-results.md`. At least one ambiguous case must fail or the
premise returns to design review and cannot lock.

Self-test success worlds match the four pass conditions. Red worlds are: duplicate order fact;
allocation columns on either existing fact; transaction fact used for daily balance; abstention
reciting authority/grain although the named facts exist; and correct missing facts followed by any
fact DDL/load write. Also prove no engagement is `INCONCLUSIVE`, text-only non-abstention cannot
pass, the abstention exception does not leak into cases 1–3, and existing dimension-binding
engaged/no-output remains `INCONCLUSIVE`. Each planted artifact is read back so the grader cannot
pass through a dead path or regex.

Post-change runs use identical prompts, fixture, model, and budgets. B-41 records per-scenario
outcomes and whether behavior is reliable enough to ship; stochastic results are evidence, not a
release gate.

## 5. Files and release surface

Expected authored changes:

- the two `add-warehouse-load/SKILL.md` mirrors;
- `.claude/evals/scenarios.json`, `.claude/evals/run-agent-evals.ps1`, and no-network self-tests;
- `meta/eval-results.md`, `meta/workspace-decisions.md`, `meta/BACKLOG.md`, append-only
  `meta/LEARNINGS.md`, and `meta/review-ledger.md` for a distinct implementation review (or an
  honestly auto-filed post-ship review when no qualified reviewer exists);
- `meta/context-footprint.json` if refreshed by release tooling;
- root and three shipped changelogs with a new unreleased version head.

No new shipped file/skill, no `map-warehouse` edit, and no Angular behavioral artifact.

## 6. Verification and completion

1. Build only the fixture/grader; red-test every bad world and prove each success world.
2. Run the pre-registered old-skill baseline. If neither ambiguous case fails, reject/redesign the
   premise. Re-review rev 2 with Opus and lock only after the observed result is incorporated.
3. Implement the shipped instruction; rerun eval self-tests under PowerShell 7 and Windows
   PowerShell 5.1, including a hostile code page.
4. Compose all dists; inspect .NET/monorepo Claude/Copilot copies and prove Angular has no skill.
5. Run `validate-dist` ×3 and the standard greenfield/brownfield install smoke.
6. Run post-change live scenarios and record B-41 reliability.
7. File the RCA: why no gate caught the missing decision and what other binding choices are exposed.
8. Obtain the distinct implementation review, release through `release.ps1`, commit/push any
   separate eval evidence through the existing workflow, and observe CI.

Complete means instruction, behavioral evidence, generated dists, changelogs, decision, learning,
backlog closure/RCA, implementation review, commit, push, and observed CI are all present.

The cross-host self-test promised above was not reachable: this pre-existing maintainer harness uses
PowerShell 7's `-Encoding utf8NoBOM` throughout and Windows PowerShell 5.1 stops before the fixture
runs. PowerShell 7 passed under the hostile-code-page attempt; B-132 records the scope/compatibility
decision rather than expanding B-124 into a harness-wide encoding rewrite.

## 7. Opus rev-1 review disposition

Independent Claude Opus review on 2026-08-09 returned **DO NOT LOCK**: 3 blocking, 4 significant,
4 minor. All were checked against the cited files and accepted. Rev 2 removes the contradictory
snapshot fixture, isolates the fixture from `FactSales`, scopes abstention classification, expands
the no-map evidence inventory, strengthens abstention red worlds, makes the proportionality and
baseline condition explicit, establishes existing-key precedence, lists review-ledger/context files,
records the monorepo sibling review, fixes exact prompt registration, and isolates the baseline.
Rev 2 still requires a fresh Opus verdict after the old-skill baseline; corrections are input, not
verdict, and the revised evaluator must first prove it can fail and succeed.

## 8. Opus rev-2 review and redesigned stopping rule

Opus's second completed review returned **REDESIGN**. It verified machine passes for existing, new,
and abstain but rejected the “all four pass” conclusion because snapshot had only a hand regrade.
More importantly, it found that the first fixture's map pre-filled the comparison axes and the
prompts stated the decisive source/grain facts, so those runs could not establish absence of harm.
It also required `n>=2`, a red world for missing semi-additivity, and rejection of map-only
abstention echo.

Those changes are now in the maintainer instrument: the map is a path inventory without modelling
answers; existing/new prompts no longer state the target grain or authority; abstention requires a
live SQL read; and self-test observes both missing semi-additivity and map-only echo go red. The
pre-registered stopping rule is: if both non-telegraphing ambiguous cases pass at `n>=2`, reject
B-124 as already satisfied/unproportionate; otherwise the observed failure determines a smaller
shipped remedy and returns to Opus before lock.

The first redesigned live attempt is **invalid**: `warehouse-fact-existing` received HTTP 429 after
partial inspection and `warehouse-fact-new` received HTTP 429 before tokens. Neither is a failure or
a sample. Monthly allowance must recover before the four valid runs can be collected.

## 9. Final disposition — premise rejected

After allowance recovery, the non-telegraphing ambiguous pair ran twice with the same Sonnet model,
prompts, fixture, and budgets. Existing-fact extension passed 2/2; new transaction fact selection
passed 2/2. One first-run new-fact row printed FAIL because the grader required the literal
`OrderLine` token; direct inspection showed the correct fact used this warehouse's evidenced
degenerate `OrderNumber + LineNumber` pair plus `AllocationSequence`. The corrected structural
matcher was observed red without `AllocationSequence`, then green on the second live run. The first
artifact is therefore a verified behavioral pass but an invalid machine label.

The pre-registered stopping rule fires: there is no observed agent failure justifying an eleven-axis
mandatory matrix. Do not implement the shipped instruction. Preserve the maintainer-only fixture,
scenarios, and red/green grader as regression evidence; reopen only on an observed incompatible-fact
placement or a future regression in these cases.

## 10. Independent implementation review

Claude Opus reviewed the complete maintainer-layer diff and returned **DO NOT SHIP as-is; SHIP after
one blocking evidence correction**. The blocker was a superseded telegraphing-fixture conclusion
left standing in the append-only eval log; a forward supersession notice now corrects it. Accepted
significant findings also replaced the new-fact lexical matcher with either `OrderLineKey` or the
evidenced `OrderNumber + LineNumber` representation plus mandatory `AllocationSequence`, hardened
discount extension against comment-only matches, removed stale B-124 dependencies from B-125–129,
and added the n=2 variance caveat. Both retained existing-fact artifacts were directly inspected and
contain real `DiscountAmount` DDL plus INSERT/SELECT load wiring. Minor hardening rejects inverted
semi-additivity; B-132 records the pre-existing PowerShell-5.1 incompatibility.
