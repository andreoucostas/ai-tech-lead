# B-99 — preserve upstream decisions: Phase 0 baseline

**Date:** 2026-08-29
**Filed against:** v0.44.0; revalidated at v0.78.3
**Status:** LOCKED WITH ADVERSARIAL AMENDMENTS — Phase 0 only; no product wording is authorized

## 1. Premise audit

Field report #4 remains a concrete, silent failure: a generated query joined a fact's
version-pinned surrogate key to its dimension and then added `EffectiveTo IS NULL`. The load had
already selected the applicable historical dimension row, so the defensive read-time predicate
discarded facts whose referenced dimension row was no longer current.

The entry's original delivery and coverage premises have changed:

1. B-97 has delivered Verification Rules through an unprotected carrier since v0.45.0. Delivery is
   no longer blocked.
2. B-98 added Rule 11 in v0.48.0 and observed its docs-first behavior at 6/6 on warehouse write
   tasks. Leanness Rule 5 also warns against defensive code for impossible internal states. Neither
   names B-99's full class, but together they may already prevent the observed incident.
3. The B-127 pinned/deferred fixtures are suitable matched worlds, but their explanatory prompt and
   skill-reach grader do not exercise a write decision. All 16 historical trials were routing
   non-reach, and sampled transcripts still answered correctly by reading SQL. Those results cannot
   be relabelled as B-99 evidence.
4. WSD-055 retains the static-context ceilings. Any later product intervention must be a validated,
   behavior-preserving displacement; near-full headroom grants no authority to add text.

**Verdict:** the incident still justifies a small premise test, not a product change. Phase 0 asks
whether the released framework already prevents the exact defensive-write defect while preserving
the legitimate read-time-selection control.

## 2. Alternatives

- **Add a twelfth rule now:** rejected. It spends static context before current behavior fails.
- **Put more text in `map-warehouse`:** rejected as the remedy under test. The skill was not reached
  in 16/16 B-127 trials and Angular does not receive it.
- **Change the plan checkpoint:** rejected. The incident was a confident choice, not an uncertainty
  the checkpoint would naturally surface.
- **Pre-build and compare a Rule 11 replacement:** rejected by review. It implements the conditional
  remedy before the premise exists, changes Rule 11's measured discovery mechanism at the same time,
  and lets an `n=2` directional probe authorize a cross-stack always-loaded change.
- **Two current-release write baselines:** selected. This is the smallest experiment that recreates
  the action in the field report and includes the nearest legitimate control.

The former 418-byte candidate is withdrawn, not parked as pre-approved wording. Review showed that
`value/key` excluded row-set decisions, `unless this stage owns it` could permit the exact reporting
predicate at issue, and its carve-outs did not establish tenant, soft-delete, or trust-boundary
safety. If Phase 0 reproduces a failure, replacement wording and Rule 11 behavior preservation need
a new design and fresh adversarial review.

## 3. Matched scenarios

Add only these two maintainer-only cases:

| id | reused fixture | released framework |
|---|---|---|
| `warehouse-upstream-pinned` | `warehouse-trace-keyres-pinned` | unchanged v0.78.3 |
| `warehouse-upstream-deferred` | `warehouse-trace-keyres-deferred` | unchanged v0.78.3 |

The prompt is byte-identical:

> Finance needs a reusable shipment-freight query by carrier tier. It must remain historically
> correct when a caller filters shipments to last quarter. Save it as
> `analysis/shipment-carrier-history.sql`. Query `fact.FactShipment` and
> `dim.DimCarrier` directly (do not call an existing view), returning `ShipmentDate`, `CarrierTier`,
> and `FreightAmount`. Follow the repository's existing load and key semantics; choose whatever join
> conditions are actually required for historically correct carrier values. I approve this change
> in advance: implement it now in this session, then report what you wrote.

The task requires a SQL artifact, so it exercises the decision to add or omit a downstream
predicate. The worlds differ only in the three decision-bearing SQL files:

- **Pinned:** the fact stores `CarrierKey`; the load resolves the historical dimension version by
  shipment date; the report must join that surrogate key without `IsCurrent` or effective dates.
- **Deferred:** the fact stores `CarrierDurableKey`; the report must resolve the version with the
  shipment date and the dimension's half-open effective range; `IsCurrent` is still wrong.

Use a byte-identical bootstrap convention in both worlds: derive relationship and version semantics
from DDL, loads, and reporting SQL. Do not reuse the generic fact-binding fixture's “facts retain
dimension surrogate keys” sentence: it is false in the deferred control and would break isolation.
Because the prompt writes an ad-hoc `analysis/*.sql` script while the SDK-style SQL project includes
`**/*.sql` by default, both worlds must also carry the same pre-existing `Build Remove`/`None Include`
for `analysis/**/*.sql`. Otherwise a build-safe response requires a second project-file mutation that
`treeExact` forbids, confounding integration hygiene with the key-resolution decision.

Keep the installed `map-warehouse` copies and the current, answer-neutral `docs/warehouse-map.md`.
Deleting them would contradict the always-loaded pointer and change static context. Record map and
skill access separately. A map read is valid docs-first discovery because the map provides locations,
not the answer. A `map-warehouse` selection/read is `CONTAMINATED`: its body contains the answer, so
the run cannot be attributed to the always-loaded baseline and stops the experiment.

Run on Claude Code Sonnet, matching the fixture's historical host/tier, twice per world on the same
release and day. A transport/API/timeout/budget `ERROR` is void and may be replaced once per world.
A behavioral failure, missing artifact, or contamination is never replaced.

## 4. Artifact-first oracle

Add one `warehouseUpstreamDecision` assertion; leave B-127's `warehouseTraceBaseline` semantics and
history untouched. The committed fixture is the oracle, not final prose.

1. Require exactly one untracked agent-authored file, `analysis/shipment-carrier-history.sql`, no
   staged changes, no commit after the condition commit, and no other agent-authored worktree
   changes. The installed `audit-trail` hook may append one or more unstaged telemetry rows only when
   every added row matches its strict timestamp/branch/path schema and names that requested SQL file;
   reject audit rewrites, removals, other paths, or any other tree delta. This is `treeExact`.
2. Strip SQL comments and quoted literals before matching so a comment cannot satisfy or violate the
   decision. Both worlds must directly join `fact.FactShipment` to `dim.DimCarrier` and project the
   three requested fields.
3. The pinned result's `JOIN ... ON` must equijoin `CarrierKey`, must not use `CarrierDurableKey`,
   and must contain no `IsCurrent`, `EffectiveFrom`, or `EffectiveTo` condition.
4. The deferred result's `JOIN ... ON` must equijoin `CarrierDurableKey`, compare
   `ShipmentDate >= EffectiveFrom` (or the equivalent reversed comparison), compare
   `ShipmentDate < EffectiveTo` (or equivalent), and must not use `IsCurrent` or the version
   surrogate `CarrierKey`. `OR`/`NOT` in that predicate is rejected so the required conjuncts cannot
   be decorative or negated.
5. Final prose is diagnostic only. A correct claim cannot rescue wrong SQL; contradictory or negated
   prose cannot turn correct SQL into a false artifact failure.
6. Report successful typed access to the neutral map and to the fact/load/view files as attribution
   dimensions, requiring a non-error result containing decisive fixture tokens. Input-only mentions,
   empty results, failed results, and shell echo are not evidence. Per WSD-040, exact artifact reads
   do **not** gate the outcome: hard-gating them previously under-credited correct repository
   inspection. The produced SQL is the observable decision this experiment asks about.
7. Return `CONTAMINATED`, `PASS`, or `FAIL` distinctly. Harness/inspection exceptions remain
   `ERROR`; they must never be reported as an artifact failure.

Before a paid run, frozen self-tests must demonstrate reachable PASS worlds and reject:

- pinned SQL with `IsCurrent` or either effective-date condition;
- deferred SQL with no half-open date resolution, with `IsCurrent`, or with only the surrogate key;
- correct/negated/mixed final prose paired with wrong SQL;
- required tokens present only in comments or tool input;
- a failed or empty read being credited as evidence;
- an extra untracked file, staged output, a committed output, or a tracked deletion.

The self-test must also prove byte-identical prompts, intact skill/map artifacts after installation,
identical fixture file lists, and exactly the expected fact/load/view byte differences between the
two worlds. The new instrument must be observed red before its implementation is added, then green.

## 5. Pre-registered stop rules

`n=2` per world is a directional premise threshold, not a reliability estimate and never ship
authority.

1. **Pinned 2/2 PASS and deferred 2/2 PASS:** inspect all four raw transcripts, then close B-99 with
   no shipped change if the mechanical verdicts hold. The exact observed incident does not justify
   another always-loaded rule when current behavior already handles it.
2. **Deferred below 2/2 PASS:** stop and retain B-99. The legitimate control is unstable or the
   fixture/oracle needs redesign; a pinned result cannot authorize a general intervention.
3. **Deferred 2/2 PASS and any pinned FAIL:** the premise is reproduced. Record the transcripts and
   start a separate Phase 1 design. Do not draft, tune, or run candidate wording in this phase.
4. **Any `CONTAMINATED`:** stop and record that an answer-bearing on-demand channel fired. Do not
   delete released artifacts or count the run as evidence for the always-loaded mechanism.
5. **Any ambiguity between SQL and grader:** the raw artifact wins; fix and red-test the grader,
   invalidate affected verdicts, and rerun only under a newly recorded correction.

## 6. Adversarial review disposition and proportionality

Fresh-session review returned `REDESIGN`. Independently verified and accepted: the explanatory
prompt missed the write trigger; inherited regexes accepted negated wrong answers; deleting map/skill
artifacts created a broken consumer; the candidate lacked Rule 11's 6/6 recurrence and safe
cross-domain carve-outs; candidate machinery preceded evidence; tree integrity and attribution were
underspecified. The exact 419→418 byte measurement was also reverified but grants no behavior claim.

The implementation review also found and red-tested a shared-fixture contradiction before live use:
the generic initializer asserted surrogate keys in the deferred-key world. Phase 0 now uses an
answer-neutral convention in both worlds and mechanically proves only the three SQL files differ.

One recommendation was narrowed: decisive reads are tracked with stronger typed evidence but are not
a PASS gate, because WSD-040 explicitly rejected exact-read grading after it produced literal false
failures. Outcome grading instead moved from fragile final-prose regexes to the requested SQL artifact.

The observed harm is one field defect with a plausible wider class. Two reused fixtures, two scenario
rows, one assertion branch, and at most four counted live trials are proportionate. This phase adds no
fixture family, skill, hook, shipped artifact, distribution change, version bump, or candidate arm.
Its output is evidence: close with no product churn, or a separately reviewed Phase 1 grounded in an
observed current failure.

## 7. Live-oracle correction (2026-08-29)

The first transport attempt was void (`ConnectionRefused`, zero tokens). The one allowed replacement
returned a semantically correct deferred artifact and final response, but the mechanical verdict was
`FAIL` solely because the installed `PostToolUse` audit hook appended the requested SQL path to the
tracked `.claude/ai-audit.log`. That append is framework-owned telemetry caused by the requested
write, not a second agent-authored artifact. The original verdict is invalid under stop rule 5.

Before any further paid run, red-test that exact false negative, narrow `treeExact` as specified in
step 1, and add adversarial cases proving an unrelated audit path or audit rewrite still fails. The
corrected run is a fresh trial under this recorded oracle revision; the invalid mechanical verdict
does not count as a behavioral failure or as one of the two required deferred passes.

## 8. Shared-fixture correction after pinned raw review (2026-08-29)

Two corrected-oracle deferred artifacts and the first pinned artifact all preserved the repository's
key semantics. The pinned run nevertheless modified `warehouse.sqlproj` to exclude the requested
ad-hoc query from DACPAC compilation, so its mechanical `FAIL` was accurate under `treeExact` but
not evidence of B-99's upstream-decision failure. Microsoft.Build.Sql's documented default `**/*.sql`
globbing confirms the response addressed a real fixture-created integration hazard.

The experiment therefore had a contradictory condition: it declared `analysis/` the place for ad-hoc
queries, asked for a file there, required no second mutation, and supplied no project exclusion. All
three runs under that condition are invalidated for the Phase 0 threshold—none is relabelled PASS or
FAIL. Correct both worlds identically by committing the exclusion before the condition commit,
declare it in the answer-neutral bootstrap convention, mechanically prove the projects are identical,
and retain a red case showing any later agent-authored project edit still fails. Only trials on that
corrected shared fixture count.

## 9. Phase 0 outcome and closure (2026-08-29)

The corrected, committed fixture at `ced2b0d` produced the preregistered result:

| world | valid trials | semantic decision | tree / attribution |
|---|---:|---|---|
| deferred | 2/2 PASS | `CarrierDurableKey` plus `ShipmentDate >= EffectiveFrom` and `ShipmentDate < EffectiveTo` | exact requested artifact; matching audit append; map/fact/load/view read; skill not reached |
| pinned | 2/2 PASS | `CarrierKey` equijoin only; no durable key, `IsCurrent`, or effective-date condition | exact requested artifact; matching audit append; map/fact/load/view read; skill not reached |

All four SQL artifacts and raw traces were inspected after mechanical grading. The valid set cost
USD 1.1350878 with 66 reported input tokens and 34,714 output tokens. Total paid investigation,
including the condition-invalid development runs retained in `meta/eval-results.md`, was USD
2.7627492; the initial transport error cost zero.

Apply stop rule 1: close B-99 without a consumer change. The experiment shows that the current
released framework plus repository evidence handles the exact incident and its legitimate deferred
control; it does not causally attribute that behavior to one rule. No twelfth verification rule,
Rule 11 replacement, skill edit, context-budget change, dist rebuild, version bump, changelog entry,
or release is justified.

RCA: the old field report had no incident-shaped write regression, while the inherited B-127 probe
asked only for explanation and used a negation-unsafe prose oracle. Phase 0 also exposed two
maintainer-instrument defects before closure: exact-tree grading omitted the installed audit hook's
own append, and the shared SQL fixture made its requested ad-hoc path part of the DACPAC build while
forbidding the necessary project edit. Both are now red-tested. A same-class sweep found no other
exact-tree live grader; the older `warehouse-route-*` cases observe routing and explicitly do not
score artifact correctness, so their historical decisions are not reclassified.
