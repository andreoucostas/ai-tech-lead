# B-98 step 1 design — does anything route a warehouse read-task to the framework's warehouse guidance?

> **Status: REVISION 2, ready for implementation.** Revision 1 was reviewed adversarially and the
> verdict was REDESIGN; §9 records the disposition of all 12 findings, including the three I did
> not accept as written and why.
> Owner item: `meta/BACKLOG.md` → B-98 step 1. Gates B-96 (LOCKED design at
> `.claude/plans/2026-08-05-b96-warehouse-schema-map-design.md`, acceptance criterion 6).
> Scope: **meta-only** — `.claude/evals/` and `meta/`. No `src/`, no `dist/`, no version bump,
> no release. Nothing here changes shipped behavior.

---

## 1. The question, stated so it can be answered wrongly

B-98: when a prompt matches no skill description, the framework emits nothing, and silence is
indistinguishable from success. `map-warehouse`'s USE FOR already contains *"what feeds this
report"* (`src/stacks/dotnet/files/.claude/skills/map-warehouse/SKILL.md:10`), so the skill was
**eligible** to fire on the field report's incident. No transcript exists, so nobody knows whether
it did. Both answers are findings with different owners:

| Observation | Owner | Consequence |
|---|---|---|
| Warehouse guidance entered context, and the answer was still wrong | B-96 | Content gap. B-96 proceeds. |
| Warehouse guidance never entered context | B-98 step 2 | Routing gap. B-96's content cannot reach the developer; §3.5's description tweak is insufficient. |

## 2. What this experiment can and cannot support

The single most important correction from review. A stochastic run is **not** symmetric evidence:

- **Routing observed** is an existence proof. One observation establishes that routing *can* happen
  on this task shape. That is genuinely decisive for B-96's premise.
- **Routing not observed** is weak at n=1 — indistinguishable from sampling noise.

So the design pre-registers a **decision rule over n runs, fixed before any run executes**. This is
the difference between a measurement and a story told after the fact.

### 2.1 Pre-registered decision rule

**n = 6**: three business-equivalent prompt paraphrases (§4), two runs each, arm A only, default
model, framework at the committed HEAD.

Let `r` = runs in which framework warehouse guidance demonstrably entered context (§6).

| Result | Reading | Consequence for B-96 |
|---|---|---|
| `r = 0` | Routing gap confirmed. Six runs across three paraphrases with zero hits is not noise. | **Blocked.** B-98 step 2 owns the remedy; B-96 does not proceed on content alone. |
| `1 ≤ r ≤ 4` | Routing is real but unreliable. Record the rate. | **Proceeds, with a stated ceiling** — B-96 must not claim delivery reliability it does not have, and step 2 remains warranted. |
| `r ≥ 5` | Routing works on this task shape. | **Unblocked.** The gap is content, which is what B-96 was designed for. |

This rule is binding. It is written here before the first run precisely so that it cannot be
adjusted to whatever the runs produce.

### 2.2 What it still cannot support

One model, one host, one fixture, arm A only. It cannot estimate the effect of B-96's proposed
pointer (that is a paired intervention test, deliberately cut — §9.8), and it cannot recover the
lost field transcript. The write-up must say so in its own words.

## 3. Fixture

A new `warehouse` fixture variant in `New-EvalRepo`. It is a **fixture shape**, not a dist: the
installed distribution stays `dotnet`, because that is where `map-warehouse` ships. §5 decouples the
two.

### 3.1 Shape

A SQL warehouse that clears `map-warehouse`'s step-0 gate (a `.sql` source tree plus ≥2 independent
warehouse signals — `SKILL.md:21-38`):

```
warehouse.sqlproj
Tables/dim.DimCustomer.sql   dim.DimRegion.sql   dim.DimDate.sql   dim.DimProduct.sql
Tables/fact.FactSales.sql
Tables/stg.StgSalesOrder.sql   ctl.LoadRun.sql
StoredProcedures/usp_LoadDimCustomer.sql  usp_LoadDimRegion.sql  usp_LoadFactSales.sql
Views/rpt.vwFinanceExtract.sql   rpt.vwExecutiveSummary.sql   rpt.vwOrderDetail.sql
analysis/                     (empty — the answer lands here)
```

Signal families that hit the shipped step-0 patterns, counted against the **exact** regexes:
layer schemas (`stg.`, `dim.`, `fact.` — note `ctl.` and `rpt.` are *not* in that alternation),
`Dim*`/`Fact*` naming, `usp_Load*`, `LoadRun`, and `EffectiveFrom`/`EffectiveTo`/`IsCurrent` on
`DimCustomer`. Five families, comfortably over the required two.

### 3.2 The planted trap — the field report, reproduced

The field report: *the model reached a dimension attribute through a spurious column (declared in
DDL, never populated) instead of following a fact key to the dimension built for that result.*

- `fact.FactSales` declares `RegionName NVARCHAR(100) NULL` — **and no load procedure writes it.**
  `usp_LoadFactSales` has an explicit column list that omits it. The evidence that the column is
  dead is in the repo and is greppable. It is not a trick.
- The correct path is `fact.FactSales.CustomerKey → dim.DimCustomer.RegionKey → dim.DimRegion.RegionName`.
- **Exactly one** of the three consumption views contains that join, and none of the three is named
  after the task. `rpt.vwFinanceExtract` carries it; `vwExecutiveSummary` aggregates by product;
  `vwOrderDetail` is line-grain with no region. The model must establish provenance instead of
  pattern-matching a filename — revision 1 named the view `vwSalesByRegion`, which made the probe a
  retrieval toy.

The fixture must *contain* the answer somewhere reachable, or a failure is uninformative: we would
only have proved the information was absent. The B-96 design's §1 observation — that consumption
views already hold the right joins and the skill extracts nothing from them — is what makes this
placement faithful rather than generous.

### 3.3 Already-bootstrapped state

The field report came from a consumer already onboarded and mapped, and per B-97 that is the only
population that matters. So the fixture is bootstrapped-looking, as `haiku-convention-check`, the
`docs-tier-*` cases and `angular-form-control` all already do: `BOOTSTRAP_PENDING` →
`EVAL_BOOTSTRAPPED`, `CLAUDE.md > Conventions` carrying plausible observed conventions.

`docs/warehouse-map.md` is present and is the **current** skill's output shape: the eight ETL
columns, no schema inventory, no keys, no relationships. A consumer who ran `map-warehouse` before
B-96 has precisely this file.

### 3.4 The population this constructs — and the two it does not

What `/bootstrap` A2 writes into `Conventions > Data Access` is model-dependent. Its instruction
ends *"…these become Conventions; the `map-warehouse` skill deep-dives on demand"*
(`dist/dotnet/.claude/commands/bootstrap.md:56`); whether the bootstrapping model copies that
pointer into the consumer's `CLAUDE.md` is not determined by the template.

| Population | **Conventions** content | Covered |
|---|---|---|
| A | Warehouse essentials, no pointer to skill or map | **this experiment** |
| B | Warehouse essentials + a `docs/warehouse-map.md` index line | no — B-96 §3.6's proposal, cut (§9.8) |
| C | Warehouse essentials + a `map-warehouse` mention written by A2 | no |

Arm A is an **intentionally constructed** population, not a measured field baseline — its real-world
prevalence is unknown, and revision 1 called it "the conservative worst case", which claimed more
than the evidence supports. If C is common in the field, arm A understates real routing. Say this in
the result.

### 3.4.1 Correction — every population already carries a pointer (found in implementation)

Revision 2 asserted arm A had "no pointer to the skill". **That is false and the assertion built to
enforce it caught it**: `dist/dotnet/CLAUDE.md:132` lists

```
- `map-warehouse` — map a SQL data-warehouse repo: layers (staging → warehouse → marts), …
```

in **Common Tasks** — an always-loaded section that `/bootstrap` does not touch, because it rewrites
*Conventions*, not the skills list. So a dotnet consumer with no pointer at all **cannot exist**, and
the table above varies only in the Conventions section. The skills-list line is a **constant across
all three populations**, and the model has `map-warehouse` named, with a one-line description, in
static context on every turn.

Two consequences, both of which must appear in the write-up:

1. **This experiment cannot measure "routing from skill descriptions alone".** It measures routing
   given an always-loaded skills-list entry. That is the real consumer condition, so it is the right
   thing to measure — but it is not what revision 2 claimed to be measuring.
2. **It sharpens what a negative result would mean.** If `map-warehouse` is named in always-loaded
   context, its USE FOR already covers *"what feeds this report"*, and it still does not fire, then
   the routing gap is considerably worse than B-98 assumed — the failure is not "the description was
   not matched", it is "a named, described, in-context skill was not reached". Conversely a positive
   result may be attributable to the skills list rather than to description matching, and cannot be
   used to argue the description is well-tuned.

The smoke test now pins the shipped baseline at exactly one such reference and fails if it changes,
so B-96 §3.6 shipping a `warehouse-map.md` index line into the template will fail this test loudly
rather than silently redefining the population under measurement.

## 4. The prompts

Three business-equivalent paraphrases, run twice each. Constraints: business framing; no skill name;
no `docs/` path; none of the description's phrases (`what feeds this report`, `which loads touch
table X`); and — the `angular-form-control` lesson — **no join strategy implied by the example SQL**.
The source system is flat in every paraphrase, so there is no join pattern available to copy.

The output path is `analysis/`, not `Reports/`: the task is inherently about a report and pretending
otherwise would make the prompt unnatural, but the *directory name* need not add a second nudge
toward the skill's "reporting views" vocabulary.

**P1 — replication framing**

> Finance want the regional revenue breakdown we already produce in the Contoso warehouse, but
> against this warehouse instead. This is the query that produces it over there:
> ```sql
> SELECT RegionName, SUM(NetAmount) AS Revenue FROM SalesLedger
> WHERE OrderDate >= '2026-01-01' GROUP BY RegionName ORDER BY Revenue DESC;
> ```
> `SalesLedger` does not exist here. Write the equivalent query for this repository and save it as
> `analysis/finance-regional-revenue.sql`. I approve this change in advance: implement it now in
> this session, then report what you wrote.

**P2 — no source query, product-line attribute**

> Sales ops need total net revenue for 2026 broken down by product category. Write that query
> against this warehouse and save it as `analysis/revenue-by-category.sql`. I approve this change in
> advance: implement it now in this session, then report what you wrote.

**P3 — ticket framing, customer segment attribute**

> Ticket FIN-4471: "monthly net revenue by customer segment, 2026 to date, highest first". Write the
> query and save it as `analysis/fin-4471.sql`. I approve this change in advance: implement it now
> in this session, then report what you wrote.

P2 and P3 carry the same structural trap on different attributes (`fact.FactSales` also declares
dead `CategoryName` and `SegmentName` columns; the live paths run through `DimProduct` and
`DimCustomer`). Varying the attribute is what stops a single lucky or unlucky string match from
being the whole result.

The trailing approval sentence copies `angular-form-control`'s. Without it a plan-first rail can
stop the session at a checkpoint and the run measures nothing.

## 5. Harness changes

`.claude/evals/run-agent-evals.ps1`:

1. `New-EvalRepo` — add `warehouse` to the `ValidateSet` and build the §3 tree; git-init and commit
   the baseline as the other variants do.
2. **Decouple fixture shape from installed dist.** Scenarios gain an optional `fixture` key. Use the
   file's existing explicit idiom — `$caseFixture = if ($case.fixture) { [string]$case.fixture }
   else { $caseStack }` — **not** `??`, matching `run-agent-evals.ps1:710` and keeping the script off
   the PowerShell-7-only operator (the B-89/B-90 host-divergence class). Backward compatible: every
   existing scenario omits `fixture`.
3. Scenario setup in the `switch` (which runs after install — verified at `:711`/`:715`) writes
   `docs/warehouse-map.md`, rewrites the Conventions block, and commits.
4. A `warehouseRouting` grader — §6.

`.claude/evals/scenarios.json`: three scenarios `warehouse-route-p1|p2|p3`, `budgetUsd` 1.25 each,
default model. Each is run twice (`-Scenario` accepts a repeated invocation).

## 6. Grader — `warehouseRouting`

### 6.1 Detection channels

A model can put framework warehouse guidance into context by several routes. Grading only the
`Skill` tool and three read-tool names would produce **false FAILs** on every other route, so all of
these are detected, and **every channel requires a corresponding successful `tool_result`** — an
attempted-but-failed read or a rejected skill invocation is not context entry:

| Ch | What it observes |
|---|---|
| C1 | `tool_use` `name == 'Skill'`, `input.skill == 'map-warehouse'`, successful result |
| C2 | read-family tool (`Read`/`ReadFile`/`read_file`) on `docs/warehouse-map.md`, separator-normalised, successful non-empty result |
| C3 | read-family tool on the installed `**/skills/map-warehouse/SKILL.md` (either `.claude` or `.github` copy), successful result |
| C4 | `Bash`/`PowerShell` command text referencing `warehouse-map.md` or `map-warehouse` (`cat`, `type`, `Get-Content`, `rg`, `grep`, `sed`…), successful result with non-empty output |
| C5 | `Grep`/`Glob` whose pattern or path references either, with a non-empty successful result |

Path normalisation is mandatory: the runner is Windows and the CLI emits both separators.

### 6.2 Reported category, not a bare pass

`Skill` firing and file discovery are different mechanisms and B-98 asks about them separately, so
the primary recorded value is categorical:

| Category | Condition |
|---|---|
| `SKILL_ROUTED` | C1 |
| `SKILL_READ` | C3 without C1 — the skill's content reached context, but not by routing |
| `MAP_DISCOVERED` | C2/C4/C5 on the map, without C1 |
| `BOTH` | C1 and any map channel |
| `NEITHER` | no channel hit |
| `DELEGATED_UNKNOWN` | no channel hit **and** a `Task` tool_use is present |

`DELEGATED_UNKNOWN` exists because a subagent's inner tool calls do not appear in the parent
transcript: the evidence could be inside the delegation, where this instrument cannot see. Reporting
that as `NEITHER` would be a false negative dressed as a measurement — the B-63 vantage-point
discipline applied to a transcript. It counts toward neither `r` nor the denominator; the run is
re-executed.

The aggregate `r` (§2.1) counts any category other than `NEITHER`/`DELEGATED_UNKNOWN`. That
aggregate is defensible because B-98 step 1's operative question is whether framework warehouse
guidance reached the working context *at all* — but the category is what gets recorded, so the
distinction is never lost. `channels=` lists every channel that hit.

### 6.3 Recorded, ungraded — B-96's pre-fix baseline

- `usedDeadColumn` — the emitted SQL references the attribute off the fact table.
- `joinedDimension` — it joins through the dimension to reach the attribute.
- `readView` — it opened the consumption view that carries the correct join.
- `artifactWritten` — the requested `analysis/*.sql` exists.

These belong to B-96 and are deliberately not graded here. Merging them would recreate, one level
down, exactly the inverted dependency B-98 was filed to correct.

### 6.4 Status

`INCONCLUSIVE` when the model neither wrote the artifact **nor** made any tool call against the
warehouse tree — i.e. it never engaged the task, so nothing was measured. Otherwise the routing
category stands even if the artifact is missing: an abandoned run that nonetheless routed is a valid
routing observation, and discarding it would throw away the datum the experiment exists to collect.
This is a deliberate, narrower departure from the `docs-tier-*` probes (`:341`), where the artifact
*was* the measurement.

## 7. Red-testing the instrument (Maintenance model #4)

Synthetic events prove Boolean plumbing; they do not prove the grader recognises the tool names,
input schemas and result semantics a **real** transcript carries. That gap is this repo's signature
defect (B-59, B-64, B-72, B-74, B-75). So implementation is sequenced:

**Phase 1** — fixture, grader, synthetic `-SelfTest` cases:

| Fixture | Expectation |
|---|---|
| `Skill` `map-warehouse` + successful result | `SKILL_ROUTED` |
| `Skill` `map-warehouse` with `is_error` result | `NEITHER` — attempts are not context entry |
| `Read` of `docs/warehouse-map.md`, Windows `\` separators | `MAP_DISCOVERED` |
| `Bash` `cat docs/warehouse-map.md`, non-empty result | `MAP_DISCOVERED` (C4) |
| `Grep` for `map-warehouse`, zero matches | `NEITHER` — empty result is not context entry |
| `Read` of `docs/defaults.md` only | `NEITHER` |
| Final text "I used the map-warehouse skill and read the warehouse map", no tool events | `NEITHER` — keyword echo |
| `Skill` for a different skill | `NEITHER` |
| No channel + a `Task` event | `DELEGATED_UNKNOWN` |
| SQL selecting `f.RegionName` | `usedDeadColumn=True joinedDimension=False` |
| SQL joining `DimCustomer`→`DimRegion` | `usedDeadColumn=False joinedDimension=True` |

Plus a **fixture self-check** implementing the *exact* shipped step-0 regexes (not a paraphrase):
assert the built fixture satisfies the gate, and assert no load procedure writes the dead columns.
If the fixture silently stops being a warehouse, or the trap column starts being populated, the
probe measures nothing while reporting cleanly.

**Phase 2** — one live run (P1). Retain the transcript.

**Phase 3** — build a **real-transcript red-test** from that retained transcript: delete the routing
event and assert the grader flips to `NEITHER`; flip its `tool_result` to `is_error` and assert the
same; rewrite the read as a shell `cat` and assert C4 still catches it. This is the step that proves
the instrument works on the shapes the host actually emits, and it cannot be written before phase 2
exists. Sanitise the transcript fixture (absolute temp paths → placeholders) before committing.

**Phase 4** — the remaining 5 runs, then §8.

## 8. Acceptance criteria

1. `-SelfTest` green, and demonstrated **red** under each inverted assertion in phase 1.
2. The phase-3 real-transcript red-test committed and demonstrated red.
3. Six runs executed (or more, if `DELEGATED_UNKNOWN` forces re-runs), transcripts retained.
4. Results appended to `meta/eval-results.md`: framework version, commit, host version, model, and
   per run the category, `channels=`, and all four ungraded signals.
5. The §2.1 decision rule applied **as written**, and the consequence recorded in B-98 and B-96.
6. The write-up states in its own words: one model, one host, arm A only; populations B and C
   unmeasured; the pointer's effect not estimated; and that the rule was pre-registered.

## 9. Review disposition (revision 1 → 2)

Twelve findings, verdict REDESIGN. Nine accepted, three accepted only in part — and the partial ones
matter, because a reviewer's corrections are input, not verdict (root `CLAUDE.md`, Maintenance
model #1).

**Accepted in full:** (2) categorical reporting replaces the bare `firedSkill -or readMap` — §6.2.
(3) false-FAIL paths: shell reads, `Grep`/`Glob` and direct `SKILL.md` reads now detected — §6.1.
(4) attempts are not context entry; every channel requires a successful result — §6.1.
(6) the semantic view filename was a giveaway; three neutrally-named views, one carrying the join —
§3.2. (8) arm B cut — it is a future-intervention test that cannot be estimated at this n, and it
doubled an S item. (9) synthetic red-tests do not prove real-transcript recognition; phases 2–3 add
the real-transcript mutation test — §7. (10) the `ctl.`/`rpt.` schemas are not in the step-0
alternation (verified at `SKILL.md:29`); accounting corrected and the self-check now uses the exact
shipped patterns — §3.1, §7. (11) `??` avoided in favour of the file's existing explicit idiom
(verified: the harness uses `if ($case.stack) {...} else {...}` at `:710` and no `??` anywhere) —
§5.2. (12) population A relabelled as constructed, prevalence unknown — §3.4.

**Accepted in part:**

- **(1) "n=1 cannot gate B-96."** The premise is right and it is the review's strongest finding, but
  the proposed remedy — demote to a baseline that can never discharge the gate — leaves B-96 blocked
  permanently, which is a worse outcome than the flaw. The evidence is also asymmetric in a way the
  finding does not use: one positive observation is an existence proof, one negative is noise. Fixed
  by raising n and pre-registering a decision rule with an asymmetric threshold (§2.1) rather than by
  abandoning the gate.
- **(5) "the prompt is contaminated because `RegionName` appears everywhere and `rg RegionName`
  exposes the answer."** Rejected as stated. `rg RegionName` returns *both* the dead fact column and
  the correct dimension column — that is the discrimination the experiment is for, not a giveaway,
  and a shared attribute name between source and target is exactly how cross-warehouse replication
  works. Removing it would make the prompt unfaithful to the incident. What *was* accepted from this
  finding: multiple paraphrases (§4, and they were needed for n>1 anyway) and a neutral output
  directory (`analysis/`, not `Reports/`).
- **(7) "mark the run INCONCLUSIVE when the artifact is absent."** Accepted only for the case where
  the model never engaged the task at all (§6.4). Applying it whenever the artifact is missing would
  discard valid routing observations from runs that routed and then abandoned — which is the datum
  the experiment exists to collect. The manipulation check the finding wants is preserved by the
  narrower condition.

## 10. Explicitly out of scope

- B-98 step 2 (is silence acceptable generally) and step 3 (the write-side-only sweep).
- Any change to `map-warehouse`'s description or content — that is B-96.
- Arm B, the pointer intervention: a paired test needing its own n, for step 2 if that mechanism is
  chosen.
- The Copilot leg. B-41 still owes it; adding it here would make an S item an L.

## 11. Cost and consent

Six live runs, 1.25 USD budget cap each (caps, not expected spend), sonnet, `-TimeoutSeconds 420`
because a warehouse scan is read-heavy. The harness refuses to run without `-Live`. **Do not run
without the maintainer's explicit go-ahead.**
