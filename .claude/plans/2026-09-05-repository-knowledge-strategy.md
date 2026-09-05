# Repository knowledge as the framework's primary value proposition

**Date / baseline:** 2026-09-05; v0.83.0; repository commit
`87bfe1942b687a47c0f5d87cdfd992e24579ed22`.
**Authority:** WSD-074. Implementation work is in `meta/BACKLOG.md`.
**Status:** strategic contract; target-host outcome evidence remains outstanding. This is not
a product implementation, release approval, or authority to spend provider credits.

## 1. Outcome and product boundary

Make an ordinary developer's coding agent better at *this repository*: discovering consequential
local facts, recognizing the applicable implementation pattern, seeing the affected dependencies,
and choosing evidence-backed verification. The target is complex enterprise repositories used
through GitHub Copilot in VS Code or CLI on Windows, with local Bitbucket hosting. The user reports
Sonnet 5 and Terra as primary coding models; exact available provider model identifiers and host
versions must be recorded when tested, not inferred from those labels.

The model should look widely and discover useful knowledge without the developer naming every
workflow. Ingestion, report procedures, run selection, conversion rules and cancellation semantics
are motivating examples, **not a domain whitelist, initial mandatory taxonomy, or list of skills
to hard-code**. The same mechanism must find consequential knowledge elsewhere: orchestration,
state transitions, configuration, permissions, interfaces, failure recovery and UI behavior when
the repository supplies evidence. It must also notice boundaries it cannot examine.

This is a repository-local knowledge workflow, not a new agent runtime or enterprise search
platform. Start with files that travel through the team's existing Bitbucket review process and
are inherited by the next developer. No hosted index, vector database, always-running miner,
production database access, PR integration service, or new distribution is needed for the first
increment. An installed supported repository can contain other languages: inventory them and
declare analysis limits, without inventing supported build/test recipes or broadening installer
support to new stacks.

**Value hypothesis, not a result:** broad discovery plus selective task-time use will reduce
repository-specific mistakes and human rework more than generic instruction volume does. User
reports establish the problem to investigate; they do not establish that this treatment works.

## 2. What the current framework actually does

All source findings below were inspected at the baseline; historical outcomes are attributed to
their records. No private consumer repository or live developer task was examined in this review.

| Evidence | Implication |
|---|---|
| Stack `bootstrap.md` shared A8 already scans broadly, but admits recurring multi-step operations (three or more), proposes at most three to five, and its `bootstrap-pass.md` worker clusters names/paths and reads one cleanest instance | Extend A8; do not add another nominal whole-tree scan. Unique rules and indirect semantics are poorly served by this contract |
| `rebootstrap.md` shared A8 follows active areas/new clusters in a recent log window | A quiet caller's knowledge can need rechecking when its helper changes elsewhere |
| `src/core/docs/wiki/_template.md` and `remember-for-team/SKILL.md` already provide scope, evidence status, provenance, recheck, deduplication and draft-for-review behavior | Reuse these carriers and rules instead of inventing a knowledge registry |
| `map-warehouse/SKILL.md` already covers read-side joins, version resolution and dimensional semantics; it leaves indirect helper/CTE tracing off the default path | Reporting is not an absent capability. Selective deeper tracing needs an explicit amendment to its cost boundary |
| The map labels reporting usage as not proving correctness, but query rule 3 calls reporting views “known to answer correctly” | Remove the unsupported certainty; do not canonize legacy simply because it is in use |
| B-216 records the Unity report; `register-service` permits an equivalent pattern then prescribes MS.DI-specific registration | Repair contradictory recipe authority independently of discovery breadth |
| `/review` promises all uncommitted work; some auditors use unstaged-only Git selection and the test-weakening advisory defaults to staged-only | A bounded, concrete scope repair is justified; this does not prove five-auditor review is wasteful |
| Financial security-auditor bullets prescribe particular isolation/locking and classify floating-point Rate/Price names as critical | Replace technology/name-only verdicts with demonstrated invariants and scoped project evidence, preserving real security review |
| `meta/host-certification.md` has capability-specific gaps; the eval executor invokes Claude; B-216's Copilot Auto calibration stopped before trials | Generated artifacts, direct script tests and historical Claude results do not establish current Copilot reach or efficacy |

Preserve composition, update ownership, verification against real repository commands, anti-
fabrication guidance, scoped hazards, and honest “cannot examine” outcomes. These are valuable
foundations. Do not use this review to reopen every closed proposal or rebuild the release system.

The checked-in static footprint records 39,963/40,000 for .NET, 38,486/40,000 for Angular, and
47,479/48,000 for monorepo on the Claude measurement. Its Copilot estimates are approximately
11,333, 11,558 and 13,282 respectively. These are byte-derived static estimates, **not measured
host context or task latency**. There is practically no .NET headroom: replace or shorten loaded
text when adding a retrieval rule; do not raise ceilings to accommodate the design.

## 3. Discovery contract — broad inventory, selective semantic exploration

Use existing `/bootstrap` and `/rebootstrap` shared A8 and its worker. Preserve the stack passes
for their existing questions. A8 becomes repository-knowledge discovery, not only skill discovery.

1. **Inventory the available first-party repository broadly.** Enumerate tracked source,
   configuration, migrations, orchestration, tests and authoritative project documentation across
   components, including quiet areas. Account for local untracked source when appropriate and mark
   its uncommitted provenance. Respect ignore/access boundaries; classify generated, vendored,
   framework-owned and inaccessible material explicitly. Do not use produced knowledge as
   independent corroboration. Do not stop the inventory merely because a nested area lacks a
   recognized stack profile. Report submodules, external services, database-only objects and other
   missing context as boundaries, not as inspected evidence.
2. **Choose exploration slices, not just filename clusters.** Use entrypoints, dependency edges,
   callers/callees, tests, configuration, data producers/consumers and exceptions to identify where
   an apparently simple change hides nonlocal obligations. Naming, repetition and recent changes
   are leads, not qualifying gates. Include quiet/atypical areas as well as obvious common paths.
   The first pass must be able to discover a one-off consequential rule.
3. **Read enough of each selected slice to support the claim.** Compare relevant implementations
   and exceptions when available. Follow helpers, predicates, transforms, configuration and tests
   when they can change the inferred meaning. One decisive implementation can support a scoped
   fact; three copied implementations cannot establish intended policy. Keep observed behavior,
   declared intent, inference and unresolved conflict distinct. Do not infer correctness from use.
4. **Bound cost and expose incompleteness.** At dispatch, state the selected effort budget, areas
   and continuation method. For the initial implementation, use a transparent default of up to
   40 distinct content files for shared A8, with at most two additional dependency hops per selected
   seed. Inventory is not subject to that content-read limit. These are initial cost controls, not
   empirically optimal values; the developer can request another bounded pass. Reuse already-read
   evidence and count distinct content files. Budget exhaustion is a partial result, not “nothing
   found.” Cycles stop at visited sources. An unresolved semantic dependency is retained with the
   next useful source to inspect, never silently treated as settled at the hop boundary.
5. **Return useful candidates and a concise coverage record.** For each inventoried area record
   inventory-only, semantically inspected, excluded, or inaccessible, plus inspected sources,
   selection reason, unresolved dependencies and continuation. An area marked inspected does not
   imply every rule in it was found. Summarize lower-priority candidates instead of losing them to
   the old three-to-five cap; that number may remain a presentation batch size, not an eligibility
   or repository completeness claim. Do not call coverage “recall.”

Default worker model remains inherited. Do not require a more expensive setup model, a fixed swarm
of specialist agents, a parser for every language, or an exhaustive call graph. Use existing host
delegation where available; execute the same bounded pass sequentially where it is not. No claims
that a prose budget is a hard runtime limit; record actual consumption when available.

Store at most 12 lines of latest coverage summary plus an on-demand link in consumer-owned
`FRAMEWORK-CONTEXT.md`, which is instructed reading on nontrivial tasks. Detailed area/source
coverage and continuation belong in an appropriate existing on-demand document or, if none fits,
one generated consumer-owned `docs/discovery-notes.md`. It is a current discovery note, not a
growing event ledger or readiness gate. Subsequent passes use that continuation to explore missed
areas, not repeatedly select the same obvious seeds. A8 can produce candidates without rewriting
already-owned project documentation. Retain existing “declined recipe” behavior;
reconsider a declined item only on changed evidence and explain why, not silently recreate it.

**Warehouse amendment:** during an explicitly requested bootstrap/rebootstrap discovery pass,
indirect tracing may use the same bounded A8 budget without a second request naming one fact.
Standalone map work retains its existing cheap default and honest unresolved edges. Avoid duplicate
tracing between passes. The existing warehouse map remains authoritative for its structured edges;
knowledge entries link it rather than creating another independently maintained edge list.

## 4. Capture contract — knowledge is not all skills

| Discovery | Destination |
|---|---|
| Scoped behavior, domain meaning, gotcha, constraint or failed approach | Existing `docs/wiki/` claim, or link/update the existing authoritative project document |
| Repeatable end-to-end operation with evidenced steps, integration points and verification | Consumer-owned project skill under `.claude/skills/`, with focused references |
| Adaptation of an existing framework operation | B-216's consumer-owned scoped reference beside the existing skill; no competing skill with the same purpose |
| Repo-wide convention, architecture decision, risky area, security finding or delivery debt | Existing CLAUDE/ADR/hazard/security/debt destination through current triage |
| Incomplete exploration and next sources | Concise coverage/continuation section, not an invented instruction |

A candidate records: the actual claim/operation; applicability and explicit non-applicability;
supporting repository-relative paths and symbols; the repository revision when available;
counterevidence and exceptions; known dependency sources; what is observed versus inferred; the
cheapest meaningful recheck and its observed result if executed; and any question only a domain
owner can settle. Use current wiki frontmatter statuses (`verified`, `suspected`, `unverified`);
put extra evidence detail in the body. One narrow schema amendment is necessary: the current
checker requires a real date even for never-checked entries. Permit `last-verified: never` only
for never-checked `suspected`/`unverified` entries; reject it for `verified`. Preserve actual historic
verification dates when later downgrading an entry, and change the template, drafting instructions,
checker and existing tests together. Do not add a confidence score, evidence counter, promotion
receipt, or new registry. For path-only evidence say what was actually read; existence alone is not
a semantic recheck. Do not equate a source-read check with execution of a business test.

Capture automatically as **drafts in the working tree** during the requested discovery workflow,
with a concise review summary. Routine factual recording must not wait for the developer to
nominate or individually approve each discovery. Drafts are not team-approved policy: normal team
PR review is the approval mechanism. Intended exceptions and conflicting business meaning require
a targeted question or unresolved status. Do not invent unavailable owner intent, auto-approve an
ADR, upgrade warehouse-map status, or overwrite protected consumer content. No automatic commits,
pushes, external memory writes or production queries are introduced into consumer workflows.

This explicitly amends rebootstrap Phase 3's per-change confirmation for **new non-overwriting
draft capture only**. Preserve confirmation when changing owner-authored content, policy/ADRs,
deleting artifacts or resolving authority. Existing draft near-matches can be proposed as edits
without an extra per-new-candidate approval queue. Do not call a draft safely inactive: generated
`SKILL.md` files are immediately discoverable in the working tree. Their loaded bodies must identify
candidate status, applicable evidence and unresolved steps, so consultation cannot silently turn
an unreviewed or unsupported step into an unconditional procedure. Exercise that hostile case.

For draft procedural skills, make evidence limits and applicability explicit; do not output an
abstract implementation recipe when no source supports its steps. Skill descriptions identify
operations in the team's language, not a giant keyword list. Put details in referenced resources
and cite more than the “cleanest” exemplar when meaningful variants exist. A bare model should not
need financial terminology hard-coded into the framework to find a local financial rule.

Deduplicate against existing claims, skills, maps and mature project documentation before writing.
Preserve owner edits and provenance across adopt/update. Model-written knowledge is a navigation
aid, never fresh independent proof for another model-written claim. A consumed factual claim must
remain verifiable against underlying evidence; a draft inference must not become an unconditional
instruction merely by being indexed or invoked as a skill.

## 5. Task-time use and refresh — inherit the useful part

Add one concise rule to the existing update-owned framework rules carrier: before planning a
nontrivial change, identify relevant project knowledge and implementation examples; read only the
matching claim/map/skill sections; recheck evidence material to correctness; name unresolved
constraints that could change the solution. Preserve mirror/composition rules. Use the existing wiki
index, scope and skill descriptions for navigation, enriched with short scope cues where needed.
No new hook-based/no-match router and no giant always-loaded catalog. A task mentioning a feature
but no paths must still discover likely areas before selecting knowledge; file globs alone are
insufficient. If knowledge is absent or inaccessible, inspect source or ask; do not invent a rule.

Exact claim meaning matters: “this helper excludes these states” can be source-verified while
“all future products must use it” remains unsupported. Conflicting scoped facts are not resolved by
last write, popularity, model confidence, or a universal priority between equally applicable
scopes. Ask about the ambiguity or retain a bounded unresolved result. Cite which project evidence
affected the implementation and the checks actually run, without adding ceremonial reports to
every trivial edit. Do not load the entire wiki before every task.

Copilot CLI and VS Code must each demonstrate entry discovery, resource reading and application.
Skill registration is not invocation; invocation is not correct application. A missing hook event
must not make ordinary knowledge access disappear. Native instruction/skill support is the primary
delivery route; adapters explain the same contract without Claude-only `Task` syntax as an assumed
Copilot capability. Inline completion is not claimed to have agent-level instruction/skill behavior.
Durable knowledge stays in repository files and no new external knowledge store is introduced;
model processing still follows the team's Copilot/provider configuration. Repository-local
persistence is not a claim that prompts remain on the workstation. No GitHub-hosted repository is
required.

Rebootstrap starts by comparing changed sources with the explicit evidence/dependency references
of retained knowledge, **including quiet callers outside the recent activity selection**. Recheck
affected entries before presenting them as fresh. Changed dependencies establish a need to recheck,
not a new truth. Renames, deletions, unavailable history, external state and failed checks remain
visible; preserve the previous verification date when no meaningful recheck ran. Reuse the existing
`remember-for-team` date/status rules and warehouse status boundary. The first implementation is
agent-driven rechecking over explicit references; it does not need reverse-index infrastructure or
an automatic per-edit rediscovery hook. A bounded continuation can be developer-initiated.

## 6. Existing instance skills — B-216 re-lock

Retain B-216 as one delivery covering derive-first skill bodies and consumer-owned scoped
`references/project-pattern.md` content for its eight named operations. This preserves the prior
single-delivery choice, not the obsolete mirror/Bash topology. Project-specific instructions must
be conditional on evidenced scope; generic examples are fallback illustrations, not mandates to
add a competing framework, container, layer or library. Reconcile carriers that would override the
same local choice, including the unconditional interface-per-injected-service wording.

The earlier machine registry/strict-parser design is **not a prerequisite** for knowledge discovery.
Before implementing B-216, compare that mechanism against ordinary scoped Markdown using existing
ownership/verification flows. Prefer the latter unless a concrete lifecycle failure cannot be
addressed there. Keep “cannot examine” distinct from invalid content. A machine can check a
reference shape; it cannot certify that the referenced recipe represents team intent.

The old plan remains historical evidence, including the stopped Copilot calibration and previous
critiques. Its exact registry grammar, budget figures, Bash/mirror work and Claude-only efficacy
substitute are not current execution authority. This is an explicit prospective re-lock, not a
claim that the sidecar trial succeeded. B-216's implementation-specific contract still needs a
bounded critique of its final carrier/ownership choice. That work must not block B-222–B-224.

## 7. Demonstrate value before expanding the machinery

Keep three different questions separate:

- **Artifact quality:** did broad discovery find grounded, useful, properly scoped knowledge and
  report missing coverage? Deterministic fixtures can reject invented paths and invalid lifecycle
  behavior. Independent inspection judges semantics; “a skill file exists” does not pass.
- **Delivery/application:** did this exact Copilot host/model load the relevant content and use it
  correctly on an ordinary task without the prompt naming the skill or supplying the missing rule?
- **Outcome:** did defects and active human review/rework decrease enough to repay setup, refresh,
  context and execution cost? Issue counts, generated artifacts and rubric compliance alone do not
  answer this question.

B-225 starts with protocol and offline controls, not provider spending. Reuse appropriate existing
B-41/field-study isolation and artifacts; the Claude executor is not already a Copilot runner.
A small explicit host adapter or a reproducible manual VS Code observation is permissible when
needed for a named observation, not as a second general eval framework.

Freeze an available repository revision, allowed local dependencies, exploration budget, task
selection window, oracles, model/host versions, equal per-arm task caps and materiality thresholds
**before** discovering or running the held-out tasks. Tasks must have discoverable pre-change
evidence, but their requested changes, solutions and grading keys must be withheld from discovery.
Use history-free isolated roots and prevent cross-arm contamination by generated skills, parent
instructions, global memory, Git history, credentials or prior sessions. Do not send private code
to a new provider or export traces beyond existing authorization.

The initial component experiment compares **current framework vs enhanced discovery**, on the same
host and observed same model, paired over the frozen tasks and counterbalanced. For each task,
record independent acceptance, severe errors, whether each required nonlocal decision was right,
knowledge access/application, active human intervention/review time, elapsed time and usage when
observable. Record setup and refresh cost separately. Valid alternative solutions must pass; each
executable oracle needs an observed valid world and a targeted invalid world. A hidden intended
policy with no accessible evidence cannot be a correctness key: asking/unresolved is valid there.
Include a quiet unique rule, a helper-derived rule, a reusable cross-component operation and
conflicting legitimate scopes; distribute them across different repository areas, not just the
user's illustrations. These are minimum adversarial shapes, not a closed mining taxonomy.

No stable model route, unavailable VS Code seat, absent domain oracle, insufficient access or
missing spend authorization means that arm is **not run / not comparable**, not failed efficacy
and not evidence for the other model/host. No swapping Auto models and averaging results. Small
samples support bounded observations, not a claim of general banking productivity gains. Hold
thresholds/tasks fixed after results; preserve nulls and regressions.

B-42's independent FS2 pair remains the separate **complete framework vs bare agent** outcome
study. It can use the delivered framework with its version pinned but must not mix FS1, FS2 and
component results. A component win alone cannot support “better than bare AI.” Retain the balanced
three-task diary for practical friction. Exact thresholds and spend caps for a new component trial
must be predeclared for the selected repository; the strategy does not fabricate their values.

**Decision after evidence:** useful captured claims with missed retrieval -> fix the delivery
route; correct use with no outcome improvement -> do not expand extraction machinery; false rules
or high review cost -> narrow capture/deepen evidence rather than generate more; material outcome
gain -> expand discovery slices and refresh only as the observed bottleneck requires. Retire a
carrier or step when a smaller alternative supplies the same measured benefit. Do not make live
provider trials a new general release gate (WSD-016), or make an unexecuted pilot look complete.

## 8. Keep, change, defer

- **Keep:** single-source distributions, local project ownership, native skill support, scoped
  hazards, evidenced verification, team review, and the existing field-outcome controls.
- **Change now in the planned product increment:** A8's recurrence/single-example limits; automatic
  drafting into the right existing carriers; bounded dependency tracing and explicit coverage;
  selective task-time use and refresh; unsupported “in use therefore correct” claims.
- **Repair separately:** B-216's conflicting implementation prescriptions; review scope divergence
  (B-226); context-free financial/security verdicts (B-227). Each has a narrower contract than a
  framework redesign and must retain valid defect detection.
- **Do not add now:** registry/cache/graph services, background mining, promotion counters,
  universal skill generation, new distributed orchestration, a new testing framework or a
  warehouse-only product. Their existence is not needed to test the value proposition.
- **Do not delete on speculation:** all generic guidance, security overlays, the router, five-
  auditor explicit review, or throttled post-write checks. Measure a concrete cost/failure and
  compare a smaller alternative before reopening those decisions. Existing post-write throttles
  are 60 seconds for .NET and five seconds for TypeScript, not a build after every edit.

## 9. Delivery order and Sol/Terra execution contract

Start B-222's discovery fixtures/contract and B-225's offline protocol controls. Implement B-222,
B-223 and B-224 as one coherent discovery increment unless an intermediate release demonstrably
has its own useful, reachable behavior. They are work packages, not three mandatory releases.
B-223 follows B-222; B-224 follows B-223. B-216, B-226 and B-227 are independently bounded repairs;
do not require them all before observing the discovery increment. B-220 remains the small v0.84+
retirement chore. Run B-225 live only when its prerequisites exist; seek B-42's independent outcome
when a participant exists. B-49 remains deferred and its old execution kit stays invalid.

Sol can delegate a named ready package to Terra after reading its backlog contract, source,
standing decisions and this plan. Freeze the concrete implementation contract and baseline, have a
nonimplementing clean-context reviewer challenge it, then implement and verify. Do not delegate
overlapping bootstrap/rebootstrap/skill files to simultaneous writers. A reviewer should challenge
grounding, cost and missing coverage, not just schema. Delivery reviews must use the actual immutable
range; this strategy critique does not qualify as independent review of future code.

Also measure the installed repository before and after discovery: the existing footprint script
measures composed distributions, not the consumer's generated skill descriptions or expanded
context. Record loaded-summary/index/skill-description size separately from on-demand bodies and
actual observed host usage. A green distribution footprint cannot certify post-discovery cost.

Each shipped package requires source-only authoring, monorepo sibling review, composed output,
relevant hostile/clean tests on direct PS7 and PS5.1, all existing gates and CI, bounded static
footprint, changelogs/release, and an RCA. Semantic acceptance and target-host evidence are reported
separately from parser tests. Do not add generic CI or loosen thresholds to erase an unavailable
environment. Meta-only protocol/design work does not require a product version bump.

## 10. Clean-context adversarial review and disposition

Reviewer: `/root/adversarial_strategy`, an independent read-only agent context with no inherited
conversation (`fork_turns=none`), reviewing immutable baseline `87bfe194...`. It received the user
objective, a separately labeled proposal, and the instruction to form its threat model first. It
did not implement the framework or this plan; it is not an orthogonal model/host execution claim.
No provider tasks, mutation runs or private consumer examples were used in that strategy review.

Its blind-first threat model was missed quiet/unique knowledge; repeated legacy defects mistaken
for policy; wrong-scope or stale claims; unconsumed artifacts; and discovery/review cost exceeding
value. Verdict: **REVISE**. Repository claims were rechecked in the named sources before adoption.

| Critique | Disposition in this contract |
|---|---|
| A8 is already whole-tree; its semantic selection is the defect | Extend the existing pass, remove recurrence as a universal gate, compare exceptions and disclose coverage |
| Stored-procedure anecdotes cannot justify a knowledge platform | Reuse wiki/skills/maps and bounded agent-driven exploration; no service/registry prerequisite |
| Existing code does not reveal unavailable intended policy | Scoped observations and counterevidence; unresolved/asking is legitimate; no automatic policy approval |
| Reporting guidance exists and deeper tracing was deliberately restricted | Preserve the map, amend only bounded discovery tracing and remove the contradictory correctness claim |
| Historical Claude reads and generated skill counts are not Copilot value evidence | Separate artifact, reach/application and outcome observations; exact host/model arms and honest gaps |
| Recent file selection misses changed dependencies of quiet callers | Explicit referenced-source recheck in rebootstrap, without an automatic truth-upgrading hook |
| B-216 and review scope are real but different defects | Keep separate bounded work; explicitly re-lock obsolete B-216 mechanics and add B-226 |
| Broad thinning misstates mandatory fan-out and throttling | No blanket deletion; preserve the precise source behavior and evidence-triggered reconsideration |

The reviewer then read the entire concrete draft at SHA-256
`2A68FF79B3126605A66CD94AD0C0F4394BDFD61DDC443B9D959CA279A4136370`, verifying the hash before
and after. Verdict: **ACCEPT WITH CONDITIONS**. Four verified corrections are incorporated above:
honest never-verified dates; a bounded loaded summary with on-demand detailed coverage and installed-
project cost measurement; explicit rebootstrap approval amendment plus immediately discoverable
draft-skill limits; and repository-local persistence distinguished from provider model processing.
The reviewer accepted the 40-file/two-hop controls as provisional bounds, not adequate-coverage
evidence, and required continuation to reach new areas. This was strategy review, not runtime
certification or independent review of the future implementation.

The backlog cleanup preserves the four previously open outcomes and their original filed-against
dates. Historic detailed wording is recoverable from the baseline Git objects and linked plans;
obsolete execution instructions are not copied into the current work list. B-129's old reporting
experiment and B-133's rejected routine-promotion machinery remain closed: the new discovery
objective does not retroactively satisfy their old reopen triggers or resurrect their instruments.
