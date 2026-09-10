# B-235 amendment: qualify report knowledge through the existing workflow

Baseline: v0.86.4, d64d3c356914399b0f9b770b4393ce72ba3e8190 (2026-09-10).
Status: Opus-reviewed backlog amendment, adjudicated before filing; no product design or model run locked.

## Decision and proportionality

Do not add a migration contract, report skill, or procedure catalogue. Consolidate B-235 into
B-222/B-223/B-224 as one reporting acceptance scenario for their already-shipped repository-knowledge
workflow. The useful unit is a scoped explanation of how an observable result is produced and what
could invalidate that explanation. Reports motivate this case; they are not a new eligibility filter.

The user reported two framework-installed warehouse repos and possible AI-assisted report migration.
We have no consumer artifacts or data. Neither warehouse label establishes its actual design.
The observed planning defect is that the earlier B-235 made progress depend on a consumer pilot and
selected a migration-specific artifact before establishing a missing capability. The observed product
concerns are the retained B-222/B-223 grounding/capture/refresh misses, not a consumer migration failure.
More instructions may leave those misses unchanged. Current capability should be exercised first.

Independent documentation on each side is useful preparation, but cannot establish semantic equivalence
or recover missing business intent. A procedure list or call graph is insufficient: parameter flow,
filters, state, time selection, output grain/measures and consequential side effects can change results.
A later migration must still reconcile requirements, representation differences and available evidence.
That downstream task is not this framework-planning item and does not require an authoring-side copy
of consumer data.

## Alternatives

1. Existing workflow plus one bounded reporting case: recommended. It tests a relevant uncertainty
   without creating competing knowledge or assuming a prose addition is the remedy. Its limitation is
   narrow diagnostic evidence; a synthetic component success is not consumer or host efficacy.
2. Add an on-demand reporting example now: plausible, but current guidance already requires most
   obligations. Choose only after identifying a consequential omission or evidenced delivery problem.
3. Introduce a procedure catalogue/graph or separate report-generation workflow: not justified.
   Cataloguing all objects is expensive, stale-prone and does not establish result meaning.
4. Retain the paired migration contract: appropriate to a particular migration after its requirements
   are known, too specific for this reusable framework capability and unnecessary at this stage.

## Verified existing coverage and limits

- All three bootstrap and bootstrap-pass sources already require finite semantic slices through
  entrypoints, callers/callees, helpers, producers/consumers, configuration and tests; actual scoped
  claims, provenance, counterevidence and unresolved dependencies. The pass is A8 in dotnet/monorepo,
  A7 in Angular. Existing bounds are 40 distinct content files and two further hops per selected seed.
- Bootstrap Phase 3a-bis, remember-for-team and the wiki template already route facts to scoped wiki
  drafts, evidenced operations to project skills/references, and existing map facts to their owner.
  Rebootstrap follows changed dependencies and retains uncertainty/ownership boundaries.
- map-warehouse already covers grain, keys, additivity, history and report join pitfalls. Its existing rule 5 requires source-column -> target-concept mapping before cross-warehouse report SQL; this rule owns that downstream mapping obligation, not a proof of full equivalence. Its procedure
  orchestration section emphasizes loads, but absence of a report-specific example is not proof of a
  missing general discovery obligation or model failure.
- B-224's shipped task rule already requires selective knowledge reads and decisive source rechecks.
  Existing records disclose unsupported claims, missed capture/reference paths, refresh errors and
  incomplete conforming target-host evidence. Those records justify finishing the chain; their model
  self-reports do not become fresh root observations in this amendment.

## B-235 obligations and their owners after consolidation

The original entry remains in Git history and the superseded 2026-09-09 plan. The quoted fragments
below are from its current backlog text, inspected by root before transfer; this is a scope transfer,
not a claim that its proposed pilot ran or that all underlying knowledge work is done.

| Original clause | Disposition and owner |
|---|---|
| "both artifact scopes" / "Consumer supplies a representative report" | Drop as dependencies of framework requirements or verification. Synthetic source is sufficient for the bounded framework case; access remains task-specific for any actual consumer work. |
| "sources, business-result owner, report grain/measures" | B-222/B-223 retain provenance, source/intent distinction and ownership; existing map query rules own grain and measure interpretation. |
| "per-edge history/key mapping" | Existing map edge/version rules and cross-warehouse query rule 5. No new mapping registry. Cross-repo application of these rules remains unobserved in this case. |
| "paired evidence/authority handoff" with "source and target revisions" and "comparable data cuts/parameters" | Retire the preselected reusable handoff as a framework deliverable. Revision pairs, comparable parameters and semantic differences remain task-specific inputs to a later authorized comparison, owned by that migration's specification; B-222/B-223 and this scenario do not establish them. |
| "comparable snapshots/results" and "data cuts" | Retain as requirements of an actual authorized comparison when needed, not a framework-planning gate or an outcome this case establishes. |
| "permitted differences/tolerances" and "matching grand total alone is insufficient" | Retain as downstream comparison considerations under existing report expected-result guidance; exact accepted meaning remains owner-decided. This case does not claim to verify those comparisons. |
| "short on-demand reference" / "skill/emitted-map links and actual retrieval" | Drop the preselected reference and its installation work because no content gap is demonstrated. B-224 owns actual retrieval; future source changes must justify and verify their real delivery path. |
| "Distinguish preserved meaning, accepted difference, mismatch, unsupported required history, and unavailable examination" | Keep the distinctions for actual report comparison; B-222/B-223 separately own honest scoped facts, intent and unavailable-evidence states. Do not treat one generic discovery pass as equivalent to a migration check. |
| "new locked minimal design, independent review and normal native verification" | Standard future product delivery remains; this amendment is meta-only and claims no product or model acceptance. |

## One bounded case, carried by B-222/B-223/B-224

Priority: address already-recorded B-222/B-223 misses in their existing work, without rerunning them
merely under report names. Retain those misses as failures and state which exact cause/change a replay
would examine; do not relabel them expected passes. Reuse an existing fixture wherever it covers the
requirement. The distinct B-224 question is ordinary retrieval from a conforming knowledge artifact.
Do not delay a justified generic repair until a new reporting fixture has been built.

The discovery entry is the existing explicitly requested bootstrap/rebootstrap knowledge pass, and
refresh uses rebootstrap. This case deliberately exercises profile-independent discovery (A8 or A7),
not warehouse-classifier selection or standalone map-warehouse deep tracing. Report source can also
include checked-in client/BI definitions or scheduler/configuration evidence where relevant; stored
procedures are not the eligibility boundary. Missing external report semantics remain unknown.

The frozen fixture must satisfy the selected bootstrap/rebootstrap entry preconditions using an
evidenced supported profile; this does not require warehouse classification or restrict discovery
to that profile. Rebootstrap also needs an already populated project context and valid ownership inputs.

Reuse existing semantic-acceptance methods and observer controls; do not launch a parallel campaign,
add an eval engine, run production SQL or request consumer artifacts. Use a small fictional repository
with one checked-in report caller, a wrapper and a helper. Keep the decisive path within the existing
read/hop limits. Additional partial/dynamic branches may legitimately remain unresolved.

The case should ask how the report result is produced and which gotchas matter. Keep expected claims
outside actor inputs. The actor receives current framework guidance and actual fixture source, not a
handwritten answer. Code-derived facts, attributed declarations, inference and unknown intent stay
separate. Unsupported business rationale is a failure even if the call chain is correct.

- B-222 discovery: an explicit caller overrides a helper default; caller-established session/temp
  state changes the selected rows; a filter/time predicate affects output. Record concrete parameters,
  state dependency, result grain and the causal effect, with decisive source paths/symbols. Distinguish
  procedure calls, data reads and evidenced writes. Include one unresolved dynamic/external branch;
  describe its known mechanism and missing evidence rather than inventing a callee or claiming safety.
- B-223 capture/refresh: persist selected findings through existing wiki/owner-document/map routes.
  A factual explanation need not become an executable skill. Preserve an existing owner document and
  reuse map-owned grain/edge facts through links. Change the helper predicate while its caller stays
  unchanged: the retained behavior claim must be rechecked, narrowed or flagged as conflicting, with
  honest status/date and actual result. Missing evidence remains unresolved, not a false empty result.
  Reuse the existing changed/missing-helper acceptance shape rather than inventing a second suite.
- B-224 use: a fresh ordinary report maintenance question naming neither a wiki path nor a skill
  should find applicable retained knowledge, inspect its decisive evidence and answer within scope.
  Check the fixture wiki with the existing validity check before dispatch, and observe retrieval separately from a correct answer independently reconstructed from source. If capture produced an invalid artifact, record that capture failure; a repaired or independently supplied artifact creates a separately labelled retrieval-only check. If an
  artifact is never read, do not call that successful knowledge reuse. Preserve unresolved intent.

These are requirements for a future bounded acceptance application, not cases executed or dispatched by this
amendment. At execution, freeze exact fixture bytes and valid/invalid answer criteria before dispatch;
verify observer controls and keep raw outputs. Do not extend it into enterprise coverage, platform
comparison or a new paid study. Current B-222/B-223/B-224 execution authority and host limits remain.
No extra data or migration access is a dependency for completing framework requirements or this case.
This amendment supplies no spend authorization. Before any later model dispatch, the owning task must
freeze its entrypoint, exact inputs, known failures, valid/invalid oracle, host/tool limits, explicit
call/time/credit ceilings and stop rules within its actual authority. Stop on broken access/observers,
nonconforming inputs or the first exhausted ceiling; preserve partial results and do not silently retry.
Do not borrow the historic 200-credit budget or restart RK1/CP2. This is not a new model campaign.

## Decision after the case

- If current guidance yields grounded capture and useful re-use with honest refresh, no defect was reproduced in that case; keep product
  source unchanged for this use case. One success does not close broader B-222/B-223/B-224 evidence.
- If an obligation is already present but the actor misses it, classify where discovery, capture,
  retrieval or refresh failed. Fix only an evidenced instruction conflict, delivery problem or other
  supported cause; do not equate a model miss with permission to add another checklist. An unexplained
  model miss remains a recorded limitation, not an invented diagnosis.
- If the source actually lacks a necessary reusable obligation, lock the smallest amendment to its
  existing owner. Generic discovery changes require all three bootstrap/rebootstrap/worker siblings;
  warehouse-specific rule changes use map-warehouse and compose dotnet/monorepo. Do not preselect a
  reference until its ownership, reach and incremental content are justified.
- Unavailable evidence/host execution is cannot-examine, not success or a content defect. A valid
  partial chain under the budget is not a reason to enlarge the budget or trace the whole warehouse.

Any future product change follows plan, independent Opus critique, Sol implementation, focused
red/clean verification and normal composition/native-host release checks. Source inspection and
synthetic reasoning do not prove SQL execution, business acceptance or migration equivalence.

## This amendment's delivery

Sol makes the following meta-only changes after Opus critique and root adjudication:
1. Add this amended plan with the critique/adjudication record; banner the 2026-09-09 plan as
   superseded so its consumer-pilot prerequisite and speculative carrier are historical only.
2. Move B-235 from BACKLOG to BACKLOG-DONE as SUPERSEDED into B-222/B-223/B-224, explicitly saying
   no report feature or behavioral acceptance was completed. Add one linked reporting-case bullet
   to each owning entry; retain their priorities, statuses and existing evidence gaps.
3. Append a dated WSD-085 amendment preserving its original reasoning/history, and one concise
   LEARNINGS entry: validate capability gaps before selecting a user-suggested abstraction or making
   framework planning depend on private artifacts. Existing WSD-074/079/081 and study boundaries stand.
4. Run existing BacklogHygiene on direct PS7 and PS5.1, diff/ownership checks, commit and push master
   through push-and-check; observe CI. No src/dist/version/gate change or paid model acceptance run.

RCA: parser/freshness checks cannot reject an over-specific work item or establish semantic usefulness.
The same planning error could duplicate existing discovery/capture/retrieval work for other domains.
The correction is to attach a discriminating use case to the existing obligations, not add a registry,
mandatory knowledge schema, approval queue, classifier or reporting whitelist.

## Opus critique and root adjudication — 2026-09-10

Fresh read-only claude-opus-5 session `09df32fa-b770-446b-bf74-a47b2e6e0981` returned REVISE;
process exit 0, is_error false. Frozen candidate SHA256
`341BCF7A76EA0AF19553BFD24A8340E14D88D1FDCADBBD80CDF0C9E98851DC6E`;
model-reported cost USD1.164315. The review began from the problem and an independent threat model.
It inspected the candidate, dotnet bootstrap/worker/rebootstrap, remember-for-team, map-warehouse and
backlog excerpts. It ran no tests and supplied no consumer/runtime/model-efficacy evidence.

1. Accept explicit ownership of existing cross-warehouse mapping rule 5. Root re-read the current
   rule and keeps its limited scope: concept mapping is covered; complete migration equivalence is
   not thereby established. Add the clause-to-owner table so superseding B-235 leaves no silent residue.
2. Accept that known B-222/B-223 misses must not be re-observed merely to create a reporting result.
   Prioritize their existing repairs and distinguish the B-224 conforming ordinary retrieval gap.
   Carry forward known misses as failures, not revised passing criteria. The
   existing records report those misses, and this amendment neither reruns nor independently regrades
   the original model traces.
3. Accept an explicit requested entrypoint and fixture validity. Reject a warehouse-classifier
   prerequisite: the chosen discovery pass is deliberately profile-independent. The standalone map's
   request-only deepening rule is preserved; source absence cannot be scored as false lack of knowledge.
4. Accept future execution ceilings and stop rules. Reject importing the earlier 200-credit allowance:
   this amendment dispatches no model acceptance run and authorizes no spend. A future execution lock
   must use the owning task's actual authority and disclose its limits; no implicit RK1/CP2 restart.
5. Reject a second warehouse lineage at this stage. It broadens the case back into migration before a
   report-knowledge gap has been found. Name cross-repo rule application as unobserved instead; synthetic
   knowledge success alone supports no migration-success or framework-causality claim.
6. Review packet discovery was incomplete: several supplied files used aliases the reviewer did not
   find, while Angular/monorepo sources were not supplied. Root directly inspected the current B-235
   entry, all-three discovery headings/contracts, the shipped selective-knowledge rule, wiki envelope,
   original plan and standing decisions. These root checks close source-citation gaps, not independent
   behavioral evidence. The reviewer correctly disclosed what it did not inspect.

The original 2026-09-09 review remains with its now-superseded plan. A separate 2026-09-10 draft had
still preselected a migration reference (SHA256
`C54B0750982CA5C8C4783559B7E356DB18DB965D96A69D9DD4EDBC4018C48FE4`, Opus session
`f3195fc1-d292-4c58-b882-05a4d2fe7039`, REVISE). It was never filed or implemented and is superseded
by the user's scope clarification and this independent capability assessment. Its proposed fixture
arithmetic was not a model, SQL or consumer test.

Root's additional source check preserved supported-profile and preflight eligibility and explicitly
retired the paired-handoff deliverable. It added no warehouse-classifier prerequisite or paired
migration fixture.

External source/review packet: `$env:TEMP/ai-tech-lead-report-knowledge-20260910`.
Automatic approval initially classified the source as private; GitHub metadata established that the
repository is public and the packet's source paths match published baseline `d64d3c3`. The authorized
read-only review then ran. No consumer artifacts were provided.

## Amendment verification

Sol (gpt-5.6-sol) applied the six metadata changes; root reviewed the final diff and checked that
the original plan body and append-only histories remain intact, B-235 has one archived heading,
and source/distribution files are unchanged. Existing BacklogHygiene ran directly under PS7 7.6.5
and PS5.1 5.1.26100.9444 at CP437: each reported 10 passed, 0 failed, 0 skipped, exit 0. On both
native hosts its existing dangling-pointer control identified missing B-999 with exit 1 and the
subsequent clean rerun again passed 10/10. The existing advisory stale-item list remains advisory;
partially completed work was not auto-closed. These checks establish metadata consistency, not
report discovery, knowledge reuse or migration behavior. Normal push/CI observation follows.
