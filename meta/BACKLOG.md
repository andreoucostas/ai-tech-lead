# Framework backlog

Current work only. Reconciled 2026-09-06 after v0.84.0 and WSD-074. Read root `CLAUDE.md`,
`DEVELOPING.md` and `meta/decisions-index.md` before implementation. Effort: S <= half a session,
M about one session, L multiple sessions; live observation time is separate from implementation.

Strategic contract: `.claude/plans/2026-09-05-repository-knowledge-strategy.md`. The objective is
broad discovery of repository-specific knowledge and better ordinary Copilot outcomes, not
hard-coded reporting or ingestion skills. This file does not authorize provider spend, private-code
export, production queries, or external participant contact.

## Execution order and common delivery contract

| Order | Item | Current readiness |
|---|---|---|
| 1 | B-222 broad discovery | Released in v0.84.0; representative semantic coverage remains |
| 1 alongside it | B-225 value protocol | Offline protocol/controls ready; live arms need explicit prerequisites |
| 2 | B-223 capture and refresh | Released in v0.84.0; semantic refresh and retained forward misses remain |
| 3 | B-224 ordinary-task Copilot use | Released carrier; live Copilot/VS Code application remains unobserved |
| Independent repairs | B-216 instance skills; B-226 review scope | Released in v0.84.0; named semantic/host gaps remain explicit |
| When a participant exists | B-42 independent FS2 | Existing packet ready; independent run outstanding |
| Deferred | B-49 drill and consumer self-assessment | Old instrument invalid; no execution authority |

Accepted focused source checkpoints for v0.84.0 are immutable at: B-222 PK-1
`e9d5f1d58489013ba629906064774f801ce551c6`, B-223 PK-2
`66a7921c909f71fb4a52a3f720ced17724d69ea6`, B-224 PK-3
`441c384ae6660c27ee6ff379aff6285bec044c42`, B-228
`7de3754a1f210b9270889125c63f02eeff38867a`, B-229
`43cb40d01169a3f9e9fe3a944a23dd90c52badd4`, B-216
`7ea1788b42dbd0a82047da4425bae3996608ad25`, B-220
`45b7a28f67510f2b5a3432613e9b4cf5edbc524c`, B-226
`7957d8734c58efbe281a58ce77612ad27740ff09`, and B-227
`16eb5c08f9d848eb24e3ffc6c035834b254bba12`. These are review anchors, not outcome verdicts. The
combined delivery shipped as v0.84.0 at `a3986c207fe336abc5967652a021625c2a17ed75`: the authoritative
local meta aggregate reported 35 files and zero failures, and GitHub Actions run `34012239352` passed
all eight native execution contexts plus the required parity decision. The parity job read eight
nonempty valid artifacts and found four byte-identical PS7/PS5.1 pairs. This proves the release
boundary, not the open semantic, target-host, or value-study outcomes below.

B-222–B-224 are one coherent product increment unless an intermediate delivery is useful and
reachable on its own. They are not three required releases. Do not require every independent repair
before trying discovery. Sol should assign Terra one named package and immutable baseline at a
time; do not have simultaneous writers edit the same bootstrap/rebootstrap sources.

For every shipped item: freeze the concrete contract, obtain nonimplementer critique proportionate
to risk, edit `src/` only, review stack/monorepo siblings, compose all distributions, keep existing
static ceilings, demonstrate hostile/red then valid/clean checks on direct PS7 and PS5.1, run all
existing gates and CI, update all four changelogs, release, and move the completed entry to the
archive with its RCA. Parser tests do not certify business truth, model behavior or host consumption.
Report semantic evidence and unexecuted host/model arms separately. Meta-only protocol work does
not require a product version bump. WSD-016 remains: no new general live-eval release gate.

**CP1 preparation, 2026-09-06.** The user's reviewed ABP / Copilot CLI contract separately
authorizes a maintainer whole-product pair and bounded diagnostics after readiness, billed-total
confirmation and calibration. It supersedes earlier absence-of-authority statements below only
for that named campaign; RK1/B-225 stays preparation-only and VS Code is deferred. WSD-076 and
`.claude/plans/2026-09-06-cp1-abp-copilot-campaign.md` preserve the prospective contract. Preparation
stopped **NOT READY**: no usable disposable Windows guest was established, and the first 100
integrations yielded 84 initial exclusions and 16 unresolved candidates, with no certified task.
No paid call, setup, application baseline or outcome was run. Sanitized evidence and remaining
caps are in `meta/field-study-results.md`; raw records remain outside this repository. All named
semantic/value entries remain open, including B-42's independent FS2 requirement.

**CP1 preparation RCA.** No shipped defect was reproduced. Parser/release gates did not establish
Windows guest availability, application buildability, independent oracle reachability or actual
Copilot use because those are study execution obligations. The same exposure applies to B-216,
B-222–B-225 and B-42: a reviewed packet or released carrier can be mistaken for observed value.
The sweep retained those gaps and separate series instead of closing entries or adding a generic
gate. The bounded response is provisioning and concrete evidence, not more evaluation machinery.

Original detailed open-entry history is preserved at Git baseline
`87bfe1942b687a47c0f5d87cdfd992e24579ed22:meta/BACKLOG.md` and linked plans. Superseded commands,
deadlines and incorrect absence-of-production-use claims are no longer execution instructions.
B-219 and B-221 — see `meta/BACKLOG-DONE.md`.

## Primary value increment

### B-222 · Discover repository knowledge broadly, not only recurring recipes
**Filed against:** v0.83.0 (2026-09-05)
**Priority:** P1 · **Effort:** L · **Invariants:** #1 #2 #3 #6 #7
**Status:** PARTIALLY DONE. The three-stack implementation shipped in v0.84.0 and its aggregate/CI
release boundary passed. The retained semantic observation is narrow and did not exercise budget
exhaustion or representative enterprise/target-host behavior. Does not depend on a registry or a
private warehouse.

**Problem / evidence.** Shared A8 already inventories naming clusters, but requires three recurring
implementations, reads one cleanest instance and caps proposals at three to five. This excludes
unique consequential facts and poorly serves helper-derived semantics. These are source
observations, not a measured recall estimate. The user's examples motivate broader discovery;
they are not its eligibility filter.

**Implementation surface.** `src/stacks/{dotnet,angular,monorepo}/files/.claude/commands/bootstrap.md`,
their `rebootstrap.md` and `.claude/agents/bootstrap-pass.md` siblings; related shared-pass/profile
handoff wording. Reuse existing workers and inspect existing bootstrap/rebootstrap assertions
before adding narrowly scoped fixtures.

**Do.** Implement plan sections 3–4: broad first-party inventory, quiet/atypical-area selection,
evidence-led semantic slices, bounded helper tracing, facts plus operations, counterexamples,
scope, unavailable context and continuation. Inventory is not restricted to recognized nested
profiles; never invent commands for unsupported ones. Initially budget 40 distinct content files
and two additional dependency hops per seed; report actual reads and partial coverage, and allow
another explicitly bounded pass. Continue from prior uncovered areas instead of repeatedly mining
the same obvious paths. Remove universal recurrence and single-exemplar rules. Three-to-five may
remain a presentation batch size, not a discovery cap. Preserve declined-recipe intent and classify
generated/vendor/framework exclusions explicitly. Workers return candidates without writing; the
parent owns B-223 capture. Amend map-warehouse's request-only tracing boundary only for this bounded
discovery path; preserve unresolved outcomes and reuse its map.

**Acceptance / hostile cases.** A fixed offline fixture contains a quiet unique rule, a helper-
dependent rule, repeated but conflicting scoped patterns, a reusable cross-component operation,
a generated decoy and an inaccessible dependency. These must not all be warehouse examples.
Candidate/coverage output must represent every case, cite actual sources and distinguish inventory
from semantic inspection. Conflicts cannot become one global convention. Hardcoded supplied
answers, invented evidence, “no knowledge exists” from exhausted budget, and exhaustive-coverage
claims are invalid. Fixtures validate shape/controls; independently inspected model runs provide
separate behavioral evidence, not something a regex test can establish.

**Done when.** All three stack paths have one consistent contract; finite slices/continuation and
unsupported-area handling are explicit; old contradictory limits are gone; fixtures have valid and
targeted invalid worlds; B-223/B-224 consume the contract before the combined feature is claimed
usable. General shipped checks apply. Record what was not explored.

**Delivery RCA.** Existing checks encoded the old recurring-cluster/output shape but never exercised
quiet unique facts, helper-derived meaning, scoped conflicts, or bounded continuation, so well-formed
instructions could omit the knowledge now in scope. The same gap applies to every semantic
eligibility rule in bootstrap/rebootstrap; parser success cannot establish discovery coverage.

### B-223 · Capture and refresh grounded knowledge in existing project-owned artifacts
**Filed against:** v0.83.0 (2026-09-05)
**Priority:** P1 · **Effort:** L · **Invariants:** #1 #2 #3 #6 #7
**Status:** PARTIALLY DONE. B-222 output is integrated into the three-stack capture/refresh source
shipped in v0.84.0, and aggregate/CI release checks passed. Retained forward runs include their
observed misses and do not establish broad recall or target-host efficacy. No registry, graph
service or promotion system.

**Problem / evidence.** Wiki, skills, maps and reconciliation exist, but A8 promotes only recipes.
Rebootstrap favors recent activity over dependencies of quiet claims and requires confirmation
before each proposed edit. Wiki checking requires a real last-verified date even for never-checked
drafts. These existing contracts need explicit, bounded amendments, not invented verification.

**Implementation surface.** All three bootstrap/rebootstrap sources, FRAMEWORK-CONTEXT templates,
`src/core/docs/wiki/_template.md`, wiki index guidance,
`src/core/.claude/skills/remember-for-team/SKILL.md`, `src/core/scripts/wiki-check.ps1`, existing
wiki/session-start/docs-sync tests. Inspect `src/core/scripts/install.ps1` ownership/adoption;
change policy only if preservation fixtures expose an actual gap.

**Do.** Automatically draft selected findings during requested discovery, deduplicating and routing
to existing authorities: scoped fact -> wiki; evidenced operation -> project skill; map fact ->
map/link; convention/ADR/hazard/security/debt -> current triage. Capture scope, source revision/
paths/symbols, exceptions, known dependencies, observed/inferred distinction, recheck and actual
result. Keep FRAMEWORK-CONTEXT coverage to at most 12 lines plus an on-demand link. Put detailed
coverage/continuation in an appropriate existing document or generated `docs/discovery-notes.md`,
consumer-owned and not required reading on every task. Do not create an event ledger.

Explicitly amend rebootstrap's per-change confirmation only for new, non-overwriting draft capture;
preserve checkpoints for changing owner content, policy, ADRs, deletion and authority. Normal PR
review approves drafts; do not add a per-entry approval queue. Draft SKILL.md files are immediately
discoverable in the working tree, so their loaded bodies must state candidate status, scope and
unresolved steps. Invocation/indexing cannot approve a recipe. Do not generate abstract procedures
without evidence or use generated knowledge as independent corroboration. Preserve mature docs.

Keep current statuses; permit `last-verified: never` only for never-checked suspected/unverified
entries. `verified` requires a real date and actual recheck. Failed/unavailable checks never advance
dates; preserve an existing actual date when downgrading a previously checked claim. Change the
existing template/check/tests narrowly. Evidence status is not PR approval; reading source is not
executing a business test. Unavailable intent remains a question/unresolved outcome.

Rebootstrap compares changed evidence and known dependency sources against retained claims,
including quiet callers. Renames/deletions, unavailable history, external state and failed checks
trigger honest recheck-needed/unresolved outcomes. Automation never upgrades warehouse-map status.
No per-edit rediscovery hook. Unknown dependencies remain a limitation; existence alone is not
freshness.

**Acceptance / hostile cases.** No fake initial date; `never`+`verified` invalid, completed recheck+
date valid. A changed helper invalidates reliance on a quiet caller's claim; a path lookup cannot
refresh it. Duplicates link/update authority rather than fork it; conflicting scopes remain distinct.
Never overwrite consumer edits. Prove preservation through ordinary update/adopt/disable flows.
Generated evidence cannot confirm itself. An unresolved unreviewed skill must not become an
unconditional procedure. Index text cannot label every draft PR-reviewed. Exercise both hosts and
existing freshness/index consumers, plus installed-project context cost (not only dist footprint).

**Done when.** B-222 output reaches correct durable destinations; refresh/preservation checks pass
after meaningful red controls; no fake certainty/date/approval; no new registry. B-224 makes knowledge
reachable before the combined feature is complete. General shipped checks apply.

**Delivery RCA.** Wiki and installer checks validated syntax and ownership mechanics but did not
exercise automatic draft authority, linked skill references, semantic refresh, or generated-text
self-corroboration. The retained forward runs exposed missed links and a duplicate destination; this
class remains relevant to every generated knowledge artifact, not only wiki entries.

### B-224 · Make ordinary Copilot tasks consult relevant project knowledge
**Filed against:** v0.83.0 (2026-09-05)
**Priority:** P1 · **Effort:** M · **Invariants:** #1 #2 #5 #6 #7
**Status:** PARTIALLY DONE. The carrier/source work shipped in v0.84.0 and aggregate/CI release
checks passed. Actual Copilot CLI and VS Code
discovery, access, semantic application, and generated-project context cost remain unobserved; host
inventory alone is not efficacy. No live target-host route, study budget, or private fixture was
selected or authorized for this study; that is distinct from the authorized Sol/Terra/Luna
authoring delegation used for this delivery.

**Problem / evidence.** A generated claim or registered skill is not proof of reading/application.
WSD-032's old Claude observations do not certify current Copilot. Host-certification gaps remain;
session-start wiki loading has an index-size boundary. Ordinary tasks cannot depend solely on that
hook or on developers naming skills.

**Implementation surface.** `src/core/.github/instructions/framework-rules.instructions.md` and
stack snippets; existing wiki/index/skill navigation; applicable `.github/prompts/` and
`.github/agents/` adapters; session-start wiki tests and `meta/host-certification.md`. Respect one
update-owned carrier and one `.claude/skills` tree; do not overwrite protected consumer instructions.

**Do.** Replace/shorten loaded text to add one concise task-time rule: find task areas, consult
relevant scoped knowledge/examples, recheck correctness-critical evidence, retain uncertainty and
run evidenced verification. Index descriptions give scope cues, not full bodies. Resolve feature-
only prompts without assuming a path. Conflicting applicable claims require investigation/question,
not arbitrary precedence. Copilot adapters use actual delegation or sequential fallback, not
assumed Claude Task support. No no-match hook, global keyword expansion or always-loaded catalog.
Durable knowledge remains repository-local; model processing still follows the team's Copilot
configuration. This is not a claim that provider-bound prompts remain on the workstation.

**Acceptance / hostile cases.** Ordinary feature/fix prompts must not name the skill, oracle or
missing rule. Observe discovery, content access, scoped application and task verification separately
in each tested host. Include irrelevant claims, opposing scopes, unresolved draft recipes,
missing/stale evidence, an index above the inline threshold and absent hooks. Positive/negative
observer controls distinguish absence from a broken instrument. Local Bitbucket must not require
GitHub PR APIs. Do not infer inline-completion behavior or efficacy from skill registration.
Measure installed consumer loaded context/skill descriptions before and after discovery; the
distribution-only footprint gate cannot prove generated-content cost. Detailed discovery stays
on demand and default task loading must remain selective.

**Done when.** Carrier changes/static budgets pass normal gates; exact host/model observations and
gaps are recorded. A required unexercised host leaves PARTIALLY DONE status and narrowed claims,
not inferred parity. B-225 owns outcome comparison; host access does not substitute for it.

**Delivery RCA.** Carrier parity and footprint checks proved text delivery, not that an ordinary
feature-only task discovers, reads, and semantically applies the right scoped knowledge. That
evidence gap applies to every host-specific native instruction/skill route and remains open rather
than being converted into a parser gate.

### B-225 · Measure broad discovery's marginal value on the actual coding surfaces
**Filed against:** v0.83.0 (2026-09-05)
**Priority:** P1 · **Effort:** M protocol, execution depends on tasks/seats · **Invariants:** #3 #6
**Status:** PARTIALLY DONE. Offline protocol reviewed in
`meta/repository-knowledge-component-study.md`; its targeted controls are proposed, not observed.
LIVE EXECUTION NOT AUTHORIZED by this entry.

**Problem.** Current source and user reports justify a hypothesis, not a productivity claim. Skill
count, framework-test success and Claude execution do not establish Copilot task outcomes. B-41's
executor invokes Claude; do not rename it a Copilot runner. B-42 answers a different whole-product
question.

**Implementation surface.** Reuse applicable `meta/field-study-kit.md` and existing
`run-agent-evals.ps1` harness/fixture controls; one meta-only component-protocol/report artifact if
needed. Do not alter FS2's frozen primary contract or build a second general harness. Add a small
host adapter only for a named observation current tools cannot make honestly.

**Do first, without live spend.** Detail plan section 7 and offline valid/invalid controls. Freeze
task selection before discovery; withhold task requests, future solutions and grading keys from
setup. Discover broadly, not targeted to test answers. Compare current framework vs enhanced
discovery, paired on the same observed model/host, counterbalanced and isolated from history,
global instructions, generated artifacts and prior sessions. Permit supported correct alternatives.
Include quiet, unique, helper-derived, recurring and conflicting-scope decisions across different
areas. Measure acceptance/severe errors, knowledge application, active human review/rework,
setup/refresh, elapsed time and observable usage. Small samples remain bounded observations;
retain nulls/regressions and never tune tasks/thresholds after results.

**Live prerequisites.** Frozen representative snapshot/privacy boundary; independent task oracles
with observed valid/invalid worlds; independent domain review where needed; exact installed Copilot
host/model identifiers and calibrated observers; predeclared materiality thresholds and explicit
model/time/credit authority. Missing stable routing -> NOT RUN/NOT COMPARABLE for that arm. No
substituting Claude efficacy or averaging changed Auto routes. VS Code may require a manual seat;
CLI is not its substitute. Request prerequisites when execution is due, not a speculative data dump.

**Done when.** Record protocol delivery separately from live execution. Close the outcome item only
after the authorized component comparison/decision, or an explicit reviewed premise-retirement
decision. A win justifies the measured increment, not a platform; a null does not justify more
machinery. B-42 separately compares framework vs bare AI; do not pool with FS1/FS2/B-49. Report all
unrun intended host/model arms.

## Bounded correctness and maintenance work

### B-216 · Project-adapt instance-shaped skills instead of imposing framework defaults
**Filed against:** v0.81.0 (2026-09-03)
**Priority:** P1 · **Effort:** L · **Invariants:** #1 #2 #3 #6 #7
**Status:** PARTIALLY DONE under the accepted WSD-074 re-lock. The implementation shipped in v0.84.0
and aggregate/CI release checks passed; source, lifecycle preservation, and one narrow Unity
composition-root observation are accepted. Alternative .NET/Angular, conflicting/unreadable
sidecar, and target-host semantic behavior remain unobserved.
Obsolete mirror/Bash/registry/pretrial mechanics are not execution instructions.

**Problem / evidence.** `register-service` permits an equivalent DI pattern then prescribes
IServiceCollection/AddXxxServices/lifetimes. The Unity report describes a different composition
root. Other recipes prescribe libraries/layers without establishing applicability. The stopped Auto
calibration produced no sidecar efficacy result.

**Scope.** Eight existing skills: .NET `add-endpoint`, `add-entity`, `register-service`,
`add-warehouse-load`; Angular `add-component`, `add-service`, `add-lazy-route`, `add-signal-store`.
Review stack/monorepo sources and rules/adapters overriding their local choice, including literal
interface-per-injected-service guidance. Reuse `.claude/skills` only.

**Do.** Re-lock one delivery: derive-first framework bodies and consumer-owned scoped
`references/project-pattern.md`. Compare ordinary Markdown/existing ownership flows against the
old registry/parser; add machinery only for a demonstrated gap. Freeze scope matching, conflicts,
stale/unreadable evidence, fallback and disable/update. Generic examples cannot override evidenced
project practice or introduce parallel containers/libraries. Unavailable intent means ask or
unresolved, not treating the newest/most frequent implementation as policy.

**Acceptance.** The Unity oracle registers only through the evidenced composition root/lifetime,
with no MS.DI artifacts. Other recipes accept scoped alternatives and reject unsupported libraries.
Evidence is first-party implementation, not generated recipes; ownership survives update/adopt/
disable; conflicts/cannot-examine differ from invalid records. Critique the concrete smaller
mechanism and hostile/clean fixtures before implementation. Target-host outcomes belong in B-225
or a separately frozen authorized trial; the old pretrial no-go is not efficacy evidence.

**Done when.** Eight operations follow the re-locked authority, all reintroducing rules are
reconciled, ownership/budgets/general shipped checks pass, and independent review/RCA exist.
B-222–B-224 do not wait for the registry decision. Historical evidence:
`.claude/plans/2026-09-03-b216-project-adapted-instance-skills-design.md`.

**Delivery RCA.** Shape/parity checks saw valid Markdown while skills, defaults, rules, and review
carriers independently imposed unevidenced libraries, layers, interfaces, and recipes. The defect
class is conflicting semantic authority across active carriers; the accepted sweep and lifecycle
fixtures address the named operations, while unrun alternative/conflict worlds remain explicit.
The update test's old phrase-presence oracle could not detect a corrupted replacement body. Its
exact body-and-exemplar comparison exposed that two default-encoding reads turned BOM-less UTF-8
into mojibake on Windows PowerShell 5.1; the owned skill round trip now decodes both inputs explicitly
as strict UTF-8 and retains a BOM-less, non-ASCII regression.

**Focused acceptance observed 2026-09-05.** Root ran the authoring authority contract at 6/0 on
both native hosts and selected update/collision lifecycle cases at 1/0 on each. Replacing the
consumer sidecar after update made the actual preservation assertion red on both hosts; restored
bytes returned it to 1/0. One fresh authoring evaluator selected the fixture's Unity registration
and lifetime without introducing MS.DI, while withholding an edit for missing evidence. Its hashes,
the earlier mismatched/blocked attempt, quick-validation 7/8 then cleanup result, and unexercised
alternative/conflict cases are recorded in `meta/repository-knowledge-forward-evidence.md`.

### B-226 · Give every review participant the same explicit change scope
**Filed against:** v0.83.0 (2026-09-05)
**Priority:** P1 · **Effort:** M · **Invariants:** #1 #3 #5 #6 #7
**Status:** PARTIALLY DONE under the accepted bounded contract. Snapshot/scanner mechanics and all
39 parent/auditor/adapter carrier changes shipped in v0.84.0 and aggregate/CI release checks passed.
Actual model Task/sequential dispatch and installed-host end-to-end behavior remain unobserved.
Independent of discovery.

**Problem / evidence.** `/review` promises staged+unstaged; convention/solid snippets use bare
`git diff --name-only`; others use HEAD; `test-weakening-scan.ps1` defaults to --cached and hides
Git failures before saying nothing qualifies. File/PR inputs lack one propagated scope. Positive
results can describe different artifacts or failed examination.

**Implementation surface.** `src/core/.claude/commands/review.md`, all auditor scope snippets/
whole-file agents including conditional security review, Copilot review adapter, test-weakening
script and `TestWeakeningScan.Tests.ps1`/review contract tests. Inspect every participant. No
auditor-count or heuristic redesign here.

**Do.** Resolve once and propagate: default union of staged and unstaged tracked changes plus
untracked nonignored source, retaining each layer's diff even when they cancel in the net worktree;
file selection restricts that set or requests explicitly labeled whole-file review; supplied
base/head ranges use immutable revisions. Preserve staged/unstaged visibility,
deletions and rename identities. Unborn HEAD, missing refs/PR details and unreadable files are
unavailable-scope outcomes, not empty clean review. Local Bitbucket accepts an evidenced local
range/patch; never assume GitHub PR APIs or guess the base. Freeze exact arguments and advisory
exit/output domains before implementation. Keep assertion-count heuristics advisory with limits.

**Acceptance.** Independently stage/unstage/change the same file, add untracked files, rename/delete,
use spaces, select files and valid/invalid ranges. Every applicable participant receives the same
artifact; ignored files do not leak. Git/inaccessible-scope failures cannot yield APPROVE/nothing
qualifies. Valid empty and no-signal scopes are reachable distinct outcomes. Test both native hosts.

**Done when.** End-to-end propagation and negative controls demonstrate previous omissions;
diagnostics are honest; advisory semantics remain non-enforcing; general shipped checks pass.
RCA examines sibling partial-diff consumers, not just the first auditor.

**Delivery RCA.** Each reviewer independently selected repository state, and the advisory swallowed
Git failure, so valid prose could compare different bytes or report no signal after failed
examination. Every partial-diff consumer was therefore exposed. One hashed captured subject plus a
pre-synthesis recapture closes the bounded workflow; supporting repository context remains readable
without enlarging the subject.

**Focused acceptance observed 2026-09-06.** Root independently ran `ReviewScope.Tests.ps1` and
`TestWeakeningScan.Tests.ps1` at the frozen mechanical checkpoint under native PS7 7.6.5 and PS5.1
5.1.26100.9278: each reported 9/0 and exit 0. Root also ran the corrected real PathFile case alone
under PS7 CP65001 and PS5.1 CP437: each reported 1/0 and exit 0 after an unfiltered control proved
the excluded test was otherwise reportable. An extra PS7 CP437 extraction failed its non-ASCII name
predicate despite output naming the path; that instrument/encoding gap is unresolved and is not
reported as a product defect or verified host combination. The 39 carrier review and recapture
contrast are source/static evidence; no model dispatch or sequential-fallback efficacy was run.

## Independent evidence and deferred work

### B-42 · Obtain balanced independent field outcomes using FS2
**Filed against:** v0.31.0 (2026-07-17)
**Priority:** P1 when a participant exists · **Effort:** M setup plus diary time · **Invariants:** #6
**Status:** PARTIALLY DONE. Production use and maintainer replay exist; the missing outcome is a
balanced non-author FS2 Module A pair and associated independent friction evidence.

**Evidence correction.** The author actively uses the framework; three non-author issue reporters
are recorded. The complaint-selected ledger establishes defects, not sentiment/total adoption.
The valid 2026-08-26 maintainer replay had byte-identical acceptable fixes and a +1 delta below its
frozen +2 threshold: no detectable difference on that task, not proof of no value. Older onboarding
defects are not assumed current. FS1 remains history; WSD-058 starts FS2 for the next independent pair.

**Do.** Use `meta/field-study-kit.md`, response template and results ledger under WSD-053/WSD-058.
Contact participants only when authorized. Select the first eligible change in a frozen historical
window: 3–8 files, two areas, three independent pre-change-grounded decisions, valid alternatives,
executable acceptance and targeted invalid controls. Preserve isolation, equal caps, privacy,
balanced onboarding and consecutive-task diary. Pin the framework/model/host; do not aim discovery
at hidden task answers. Do not reinstall to satisfy the superseded zero-use premise.

**Done when.** Record a valid independent pair and balanced returned evidence, including nulls,
regressions and cost; reprioritize the backlog from it. Never pool FS1, FS2, B-225 or B-49. An absent
participant is an external prerequisite, not grounds to call another maintainer replay independent.

### B-49 · Re-design the live-fire drill and consumer self-assessment when justified
**Filed against:** v0.31.0 (2026-07-17)
**Priority:** P3 · **Effort:** M redesign, execution separately authorized · **Invariants:** #3 #5 #6
**Status:** DEFERRED; instrument INVALID under WSD-062. The value outcome remains open. No automatic
quarterly execution or general host recertification is required by this entry.

**Evidence.** July had a real quota-stopped partial, not no run; it yields no comparable A/B result.
Later audits found stale/archived targets, dead script references, missing controls and inadequate
isolation. The old plan/kit are historical, not instructions to resume. WSD-066 replaces calendar
host recertification with capability-specific triggers.

**Reopen execution only when.** A concrete remaining question is not answered adequately by B-42/
B-225; current target/release, isolated executable valid/invalid oracles, ordered relevant canaries,
and explicit model/time/credit authority are freshly locked and independently critiqued. Preserve
the desired consumer-runnable “is this worthwhile here?” assessment, but design privacy, cost
disclosure, selection and bare-agent isolation instead of shipping the invalid maintainer kit.
Do not replace FS2 with the old shared-composite requirement. No scheduler/reminder is changed here.

**Done when.** The newly justified drill and separately designed consumer self-assessment have
valid execution/delivery evidence, or a reviewed decision retires their remaining premises.
A polished protocol alone does not complete the value question.
