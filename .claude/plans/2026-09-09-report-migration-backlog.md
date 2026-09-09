# B-235: report migration between two warehouse repositories

**Filed against:** v0.86.3 (2026-09-09), `f67eb0312be5838bb17066fa9fdd2847785a812f`.
**Priority / size:** P3 / M provisional; first step is bounded discovery, not implementation.
**Status:** REVIEWED conditional backlog plan; Opus critique adjudicated before filing.
**Readiness:** conditional discovery; product design is not locked and implementation is not authorized.
**User-reported need.** The consumer installed the framework in two repositories, describing one
as a "slowly changing fact type DW" and the other as a "slowly changing dimension DW", and plans
to use AI to migrate reports between them. These labels do not establish either warehouse's grain,
keys, temporal semantics, correction strategy, migration direction, or intended business result. No consumer code,
data, query result, or framework-caused migration defect has been observed here.
The authorized work is an enhancement/backlog proposal and its Opus review, not a migration.

**Existing capability; source facts at the filed baseline.**

- `src/stacks/dotnet/files/.claude/skills/map-warehouse/SKILL.md:31-195` already covers layers,
  grain, business/surrogate keys, relationship evidence, conformance, additivity, fact types,
  per-edge version resolution, SCDs, corrections, late arrivals, and load/run controls.
- The same skill's read-side rules (`:257-298`) require grain and expected-result/tolerance
  definition, source-column -> target-concept mapping before cross-warehouse report SQL,
  evidence-qualified join paths, temporal resolution, and fan/chasm avoidance. This is not a
  request to add basic report, SCD, or warehouse support again.
- `src/stacks/dotnet/files/.claude/skills/add-warehouse-load/SKILL.md:17-43,146-170` already
  derives target-family patterns and history/reconciliation safeguards. Report-only work must
  not activate a load/schema change merely to fit that recipe.
- `src/stacks/dotnet/files/.claude/agents/security-auditor.md:61-65` already requires applicable
  financial invariants, tolerances, temporal predicates, and an expected-result oracle.
- `src/stacks/dotnet/files/.claude/commands/bootstrap.md:202-239` and
  `src/core/.claude/skills/remember-for-team/SKILL.md:9-16` already provide scoped project
  skills, wiki facts, maps, provenance, unresolved evidence, and human review boundaries.
- `src/stacks/dotnet/files/FRAMEWORK-CONTEXT.md:6` limits generated context to evidence from
  its own repository. `src/core/scripts/warehouse-map-check.ps1:47-56` reports timestamp
  freshness, not semantic correctness or comparable source/target data state.

**Plausible residue and proportionality.** The audited reporting rule presupposes evidence from the
other warehouse is already available; it does not specify a paired evidence handoff retaining each
repository's authority and provenance. The candidate gap is a report-specific handoff
combining repository/data provenance, business meaning, mapping, semantic differences and
reconciliation. This is a bounded documentation observation,
not an exhaustive claim that no shipped surface supports cross-repo work, nor proof that current models fail the user's task. First determine whether applying existing
rules and a normal project spec already solves one representative report. If it does, retain the
useful consumer-specific artifact and close without a framework change. Do not generalize one
pilot into reliability, productivity, or broad migration-coverage claims.

**Alternatives.** (A) Existing map/read-side rules plus a consumer-owned report spec: smallest and
preferred if sufficient. (B) A short on-demand reference reached from the existing map-warehouse
reporting rule: conditional choice if the pilot exposes a reusable missing obligation. (C) A new
report skill, mandatory mapping registry, cross-repository graph, migration engine or DW distro:
reject absent a materially different observed need; each adds machinery beyond this request.

**Discovery before product design lock — one named report only.** Once the consumer supplies the
needed scope and access authorization, perform a bounded artifact walkthrough using current
framework guidance. This is not authorization for a paid model study, SQL execution, or data access.

Before the walkthrough, record the decision rule: A is sufficient for this report when existing
rules and authorized evidence support a reviewable paired contract without an additional reusable
framework obligation. B is justified only by a concrete consequential omission left unresolved by
those existing rules; missing access, owner decisions, or absent target history alone do not justify B.
Record any supplied mappings/expected answers as assistance: they are valid operational inputs, but
success using them is not evidence the agent independently discovered that mapping. This is an
artifact assessment, not a controlled capability study; do not withhold useful consumer evidence.

1. Identify source and target repositories, immutable revisions (plus any included uncommitted
   artifacts), migration direction, named report definition, relevant dependencies, dialects,
   installed framework profiles, permitted paths, and who decides intended report behavior.
   Existing maps are optional: accept the equivalent scoped live artifact inventory. Do not scan
   or map both whole warehouses merely to migrate one report.
2. Freeze the report's business meaning, output grain, measures/units, applicable filters,
   parameters, dimension roles, and intended historical/current interpretation. Distinguish
   business effective time, event/report time, and load/run/revision time only where evidenced.
   Establish expected business results and permitted differences: old output parity is an
   oracle only where the owner and independent evidence justify it, not because it exists.
3. Record source expression/concept -> target expression/concept with evidence on both sides,
   applicable grain/key/temporal transformations, and unresolved or deliberately different rows.
   Reuse existing maps and scoped facts; do not create another warehouse-wide edge matrix.
4. Record comparable data cuts/snapshot identifiers, relevant load completion and report parameters,
   population and time boundaries, and available expected-result evidence. Repository revisions
   alone do not freeze data. If comparable data/results cannot be provided within authority,
   finish the artifact assessment with that gap; do not claim executed migration equivalence.
5. Inspect the smallest applicable discriminating cases: for example a version boundary or
   correction, a duplicated/missing join, or different grouping/additivity. Select from the
   report's evidence, rather than imposing every case. A matching grand total alone is inadequate
   when wrong rows can compensate. Name a valid successful state and a consequential invalid
   alternative; use supplied evidence or an authorized existing check, never an invented engine.
6. Record what current guidance handled, the exact uncovered obligation if any, human decisions,
   and remaining limits. Choose A or justify B before locking a product design. No demonstrated reusable gap means no new framework surface; unavailable evidence means discovery remains open.

**Outcome vocabulary, scoped to the check actually performed.** Success means the named artifact
or authorized comparison satisfies its frozen business contract with evidenced accepted differences.
Failure means an examined artifact/result violates that contract; name the counterexample.
Unsupported means a known target capability or retained data cannot represent a required behavior;
seek an owner decision, never silently approximate. Asymmetric history retention may support an
evidenced accepted difference if the owner changes/clarifies the contract; it is not automatically
acceptable or a failed implementation. Cannot examine means necessary evidence/access
or execution is unavailable; it is neither failure nor success. Unresolved business intent remains
a question for its owner. A source walkthrough cannot certify runtime or business-result equivalence.

**Conditional enhancement, one item.** If B is justified, prefer a short body-only reference under
`src/stacks/dotnet/files/.claude/skills/map-warehouse/references/`, with a small pointer in existing
reporting guidance; it must compose into dotnet and monorepo. Reuse an existing per-report spec or
project document for the contract and existing wiki/map/project-skill carriers for durable facts or
an evidenced repeatable operation. Keep loaded context bounded; do not add a new always-on rule,
registry, parser, hook, bootstrap sweep or mandatory document. Links must resolve from both the
skill and any emitted `docs/warehouse-map.md`; copying one relative link between those locations
is not sufficient. Existing protected consumer maps/instructions do not migrate automatically. A future B lock must
specify the requested point-of-use entry and how actual retrieval distinguishes not reached from
reached-but-not-needed. WSD-032 measured map reading, not skill invocation, in its historic fixture;
frontmatter advertising report replication is not evidence the skill will be invoked. Reuse its
emitted-map delivery path when applicable and account for older/absent maps, without a new paid probe.

**Acceptance and dependencies.**

- Completed Opus critique challenges premise, sufficiency of option A, temporal assumptions, reach,
  authority and proposed oracles; root adjudication and source re-verification are recorded below.
- Consumer dependencies: a representative report, both scoped artifact sets and access, actual
  history/key semantics, business-result owner, permitted differences/tolerances, and available
  comparable data/results or an explicit not-examined limit. Their absence does not prevent
  planning, but prevents claiming a locked consumer implementation or a successful migration.
- The one-report record distinguishes all outcomes above and identifies whether a reusable gap
  exists. Any future product lock names the minimal source/reference changes and its delivery
  path, accepts valid alternatives, and states explicit verification/host gaps.
- Future implementation follows normal source composition, install/link verification, independent
  review, native-host gates and release obligations; no permanent prose-only test or new generic
  live-eval gate is required by this proposal. Record RCA: why existing guidance was insufficient,
  or why no product change was justified, and which same-class scope remains unexamined.

**Preserved decisions and authority.** WSD-020: derive technology from evidence. WSD-021: existing
warehouse skills, dotnet/monorepo delivery, no DW distro or automatic full mapping. WSD-027: expensive
semantic work belongs at its authorized point of use; automation does not promote epistemic status.
WSD-033: map document optional, equivalent evidence mandatory before a warehouse write. WSD-037:
no fact-binding matrix or new procedure merely despite a sufficient baseline. WSD-042: do not reopen
the closed report-publication experiment or pretend static SQL proves executed results. WSD-057:
historical constraints are rebuttable through recorded evidence; review is independent and evidence-bound. WSD-074 (preserved by WSD-079): existing scoped knowledge carriers, bounded reads,
honest grounding/access/outcomes, no new platform or inferred study authority.

No SQL execution, data movement, schema/load change, cutover, new engine/distro, consumer-code/data export or new paid study is authorized by this entry; each needs its own scope and authority.
## Opus critique and root adjudication — 2026-09-09

Fresh Read-only claude-opus-5 session `6b6d7deb-9d7d-41cf-9ccb-45d4fb96115f` returned REVISE;
process exit 0 and is_error false. Original external proposal SHA256
`DFCEDB6363BD504482128AEF35085A58AD7B181735C9899E8400AB72B9720ABF`. Model-reported cost
USD0.7116805. Threat model preceded source inspection; no implementation, consumer access or tests.

1. Accept explicit A/B decision criteria and disclosure of answer-key assistance. Reject treating
   this requested artifact walkthrough as a new blinded model experiment: supplied mappings remain
   useful inputs; no independent-discovery/efficacy claim follows from using them. No n>=2 study.
2. Accept reachability risk. Root read WSD-032: historic evidence was map opened 6/6, Skill 0/6;
   frontmatter already mentioning report replication did not cause invocation. Thus reject the
   review's suggestion that current frontmatter is partly evidenced reach. Future delivery must
   state actual consumption versus absence and account for generated-map links and old maps.
3. Accept a concrete paired evidence/authority handoff hypothesis; reject the absolute claim that
   no shipped surface tells an agent how to hold another repository's evidence. Only the audited
   reporting/checker/context surfaces establish this bounded observation. Per-repo authority is
   retained; current general permissions are not retroactively declared broken.
4. Root verified the previously unsupplied security-auditor and bootstrap citations, read both
   current passages, and observed no diff from the immutable baseline across all seven cited
   source files. Reviewer absence was a packet gap, not a source defect. Future reference install
   and consumer reach remain implementation acceptance, not claimed completed behavior.

Accept explicit owner-approved history differences, without silently accepting loss of required
history. Root verified a narrow index citation drift: WSD-020 rejects a separate testing skill and
unevidenced technology defaults; WSD-021 rejects the DW distro. Split the existing combined index
entry to point at the actual decisions; no standing policy changes.

No observed consumer failure, runtime parity, productivity improvement or successful migration is
claimed. Read-only Opus review supports filing a conditional item, not locking product design.

## Technical background (not consumer evidence)

Dimension history and fact history are separate design choices. Kimball's [Type 2 dimension](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/type-2/)
and [timespan fact](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/timespan-fact-table/)
patterns explain why labels alone cannot choose a migration join. Report [grain](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/grain/)
and [measure additivity](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/additive-semi-additive-non-additive-fact/)
constrain valid comparisons: balances and ratios, for example, cannot always be summed across time
or groups. These references justify questions to ask, not assumptions about this consumer.