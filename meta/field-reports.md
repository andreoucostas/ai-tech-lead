# Field reports

Improvement-only issue intake from people using the framework on real work, as opposed to
maintainer introspection. Created 2026-07-31 for **B-42**, which asks that field findings be recorded
here and used to re-order the backlog. This is deliberately not a balanced feedback or satisfaction
ledger; executed balanced studies live in `meta/field-study-results.md`.

> **Confidentiality rule — binding.** Reports arrive from client repositories. Record the
> *technical shape only*: stack, repo shape, what the model did, which framework surface was
> involved. Never record client names, repository names, file paths, domain vocabulary, or code.
> The eval fixtures derived from these reports are synthetic for the same reason.
>
> **Do not invent fields.** Anything the reporter did not say is recorded as **not captured** — an
> empty field is evidence about our intake, and guessing would turn one observation into a fake
> dataset. Most fields below are empty; that is the honest state, and it is itself a finding
> (see "Intake gaps").

## Numbering note

B-42 records the Angular report below as "field report #1", and B-66 calls it "the first field
report the framework has ever received". **Both are wrong.** The NUnit report that drove B-57 →
v0.36.0/v0.37.0 is also a field report from a real install, and it landed earlier in the shipping
record (`meta/BACKLOG.md:894`). It is recorded here as #1. The numbering in B-42/B-66 is left
as-is rather than rewritten, so the discrepancy stays visible; this file is the ledger.

---

## Report #1 — .NET brownfield, test framework assumed

| | |
|---|---|
| **Date received** | not captured (before v0.36.0, shipped 2026-07-31) |
| **Stack / repo shape** | .NET, brownfield, existing NUnit suite |
| **Framework installed** | yes — a real install |
| **What misfired** | The framework kept steering toward xUnit instead of following the test suite already in the repo. Six shipped surfaces stated xUnit as fact. |
| **What fired** | not captured |
| **What got ignored** | Verification Rule #10 and `bootstrap.md`'s Phase 3a synthesis guard both already forbade exactly this, and neither prevented it. |
| **Hook noise** | not captured |
| **Token pain** | not captured |
| **Reporter** | a reviewer on the receiving team (not the framework author) |

**Outcome:** B-57, shipped as **v0.36.0** (guidance: evidence-keyed Testing block, `add-tests` Step-1
evidence gate, `enforce-standards` branching across xUnit/MSTest/NUnit) and **v0.37.0**
(enforcement: the write guard blocked only `[Fact(Skip=…)]`, so NUnit and MSTest repos had a weaker
floor than xUnit ones). WSD-025.

**What this report taught that the defect itself did not:** a rule can be written down correctly and
still lose to a parenthetical. `add-tests` read "following project patterns **(xUnit +
`WebApplicationFactory`)**" — a sentence that argues with itself. See `meta/LEARNINGS.md`.

---

## Report #2 — Angular, custom form control

| | |
|---|---|
| **Date received** | 2026-07-31 |
| **Stack / repo shape** | Angular, brownfield (client repository) |
| **Framework installed** | not captured |
| **What misfired** | On a custom form control, the model used `@Input()` properties rather than making the component participate in the Angular forms API (injecting `NgControl` / implementing a value accessor). |
| **What fired** | not captured |
| **What got ignored** | Nothing — and that is the point. Unlike report #1, no framework surface said anything for the model to ignore. |
| **Hook noise** | not captured |
| **Token pain** | not captured |
| **Reporter** | an Angular developer (not the framework author) |

**Root cause:** the Angular stack ships **no forms guidance at all**. A case-sensitive grep for
`ControlValueAccessor`, `NgControl`, `FormControl`, `FormGroup`, `FormBuilder`, `Validators`,
`ngModel`, `NG_VALUE_ACCESSOR`, `formControlName` and `ReactiveFormsModule` returns zero hits across
`src/stacks/angular/`, `src/core/` **and** `dist/angular/`. The model was not disobeying the
framework; the framework was silent, so it fell back on training priors.

**Corroborated independently** (2026-07-31, commit `0598c6d`): in an `angular-form-control` eval run
against a synthetic fixture with the angular dist installed, the agent grepped for an existing
`ControlValueAccessor`/`NgControl` pattern to follow and reported finding none — because none ships.
The field report and the harness agree, from different directions.

**Outcome:** B-66.

---

## Report #3 — SQL data warehouse, attribute reached through a spurious column

| | |
|---|---|
| **Date received** | 2026-08-04 |
| **Stack / repo shape** | SQL data warehouse; consumer repo, onboarded and already mapped |
| **Framework installed** | yes |
| **What misfired** | Asked to replicate a report built in a *different* warehouse, the model reached a dimension attribute through a spurious column — declared in DDL, never populated — instead of following a fact key to the dimension built for that result. With no relationship model in reach, the only evidence available was the column's **name**. |
| **What fired** | unknown — no transcript exists, so whether `map-warehouse` fired was never established. That unknown is itself the trigger for B-98. |
| **What got ignored** | not captured |
| **Hook noise** | not captured |
| **Token pain** | not captured |
| **Reporter** | the maintainer |

**Root cause:** `map-warehouse` emits eight fields per entity, every one a *loading* property — no
schema inventory, no keys, no relationships. It is an ETL map wearing a warehouse map's name, so it
can say how a fact is loaded and not what it joins to.

**Outcome:** B-96 (design LOCKED), and two general defects found through the same symptom — B-97
(a conventions change cannot reach an already-bootstrapped consumer) and B-98 (a prompt matching no
skill description fails silently).

---

## Report #4 — SQL data warehouse, end-date predicates on dimension joins

| | |
|---|---|
| **Date received** | 2026-08-05 |
| **Stack / repo shape** | SQL data warehouse; staging populates dimensions, then facts, so keys and state are generated on load |
| **Framework installed** | not captured |
| **What misfired** | The model put end-date predicates on **dimension joins**. Unnecessary: the load had already resolved each business key to the dimension version that applied and stamped that surrogate key onto the fact, so the version was already pinned. Only the run dimension genuinely needed an end-date predicate — its current row is selected at read time. |
| **What fired** | not captured |
| **What got ignored** | Nothing warehouse-specific existed to ignore: all shipped DW guidance is write-side. The only place `EffectiveTo` appears is `add-warehouse-load` step 5, which says how to *set* it when expiring a row. |
| **Hook noise** | not captured |
| **Token pain** | not captured |
| **Reporter** | the maintainer |

**Root cause:** the framework states a rule and never its entailment. `add-warehouse-load` step 2
says facts carry foreign keys to *surrogate* keys, not natural keys — so the as-of join already
happened, once, at load. That the version is therefore already pinned, and a downstream temporal
predicate is wrong, is drawn nowhere. The model fell back on the textbook Kimball pattern, which is
correct for the load and wrong for the read.

The failure is silent and self-camouflaging: `AND d.EffectiveTo IS NULL` on a surrogate-key join
drops every fact pointing at a superseded row, surfacing only as a low row count — and in review a
join carrying effective-date predicates reads as *more* careful, not less.

**Corroborates report #3 from a second angle.** Both are read-side defects in the same warehouse;
#3 is attribute sourcing, #4 is temporal predicates. Two distinct defects, one cause — the read side
has no guidance at all. B-96's locked design §3.4 addresses #3's class and not #4's.

**Outcome:** B-96 amended (§3.4 gains the resolved-at-load vs deferred-to-read rule); B-99 for the
general class.

---

## Report #5 — mature brownfield onboarding, one-shot analysis and workflow routing

| | |
|---|---|
| **Date received** | 2026-08-25 |
| **Stack / repo shape** | Mature, well-documented brownfield repository; stack not captured |
| **Framework installed** | yes; version not captured |
| **What misfired** | Four related observations: bootstrap findings changed between runs and had no independent verification; a previously rejected debt proposal could be surfaced again; adoption archived existing architecture/ADR material and re-derived framework-shaped context; a discussion containing “tech debt” triggered the debt workflow, while compound requests such as fix + test can receive only one regex-selected intent. |
| **What fired** | Bootstrap/adoption analysis and the natural-language intent hook. Exact transcript/tool events were not retained. |
| **What got ignored** | Existing mature documentation as an authoritative source in place; the developer's prior disposition of a false debt proposal; compound workflow aspects after the first regex match. |
| **Hook noise** | Yes — an explanatory debt discussion was routed as debt cleanup. Reproduced later against both shipped hook twins with `Why is this tech debt?`. |
| **Token pain** | Not quantified. The reporter explicitly recognised that repeated discovery plus verification costs more; the maintainer identified current usage limits as the reason bootstrap had previously run on Sonnet rather than Opus. |
| **Reporter** | external senior developer |

**Epistemic status.** The magnitude of run-to-run bootstrap variance is reporter-observed but no raw
runs were retained, so it remains to be measured. The current tree independently corroborates the
mechanisms behind the other observations: no dismissed-debt memory; adopt moves `docs/adr/**`,
`docs/decisions/**`, and `docs/architecture/**`; bootstrap/rebootstrap derive Boy Scout priorities
from current debt; and the router is an exclusive priority chain. The exact debt-question false
positive was reproduced on both PowerShell and bash hooks on 2026-08-26.

**Outcome:** B-178 (three-run repeatability baseline), B-179 (debt-question escape), B-180
(dismissed-proposal memory), B-181 (mature-doc screen-in-place), and B-182 (stop debt-derived Boy
Scout augmentation). B-177 already owns deterministic bootstrap completion gating; B-44/B-159 own
the broader supported-host router experiment.

---

## Intake gaps (a finding in its own right)

Reports arrive as a sentence or two about one defect, and most table fields go uncaptured.

1. **"We only hear about defects" — CLARIFIED by maintainer, 2026-08-26. Deliberate selection, not
   sentiment evidence.** The maintainer acted on feedback that exposed something actionable and did
   not record the positive feedback that was also received. The negative distribution here is
   therefore an intake rule, not evidence that overall experience is negative. Nor can the
   unrecorded positive feedback support a value claim: its count, context, and denominator are
   unknown. Keep this ledger **deliberately improvement-only**; do not add testimonial fields to it.
   Capture benefit, harm, mixed effects, and no detectable difference symmetrically through
   `meta/field-study-kit.md` and record executed results in `meta/field-study-results.md`.
   `what fired` / `what got ignored` stay — they are diagnostic, not testimonial: report #1's cause
   was *the framework spoke and was ignored*, reports #2 and #4's was *the framework was silent*, and
   those demand opposite fixes.
2. **Arrival dates are not recorded at intake.** Report #1's is unrecoverable. Reports #3 and #4
   have them — treat that as the standard.
3. **Report #5 is the first workflow/mechanism report; the previous four were coverage defects.**
   Reports #2–#4 were silence in a stack/domain area and #1 was guidance overridden by a
   parenthetical. Report #5 instead concerns sampling, state preservation, document ownership, and
   routing. Do not generalise the earlier four-of-four pattern now that the intake population has
   changed; keep coverage and workflow failures as separate cuts of the improvement ledger.

Capture the table fields **at intake**, before the defect is diagnosed — by then attention has moved
to the fix and the context is lost.
