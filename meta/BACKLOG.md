# Framework backlog

Current work only. Reconciled 2026-09-08 after v0.86.0 and WSD-079. Read root `CLAUDE.md`,
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
| 3 | B-224 ordinary-task Copilot use | Released carrier; ordinary CLI navigation/application observed on a nonconforming synthetic wiki, conforming CLI/VS Code acceptance remains open |
| Independent repairs | B-216 instance skills; B-226 review scope | Released in v0.84.0; named semantic/host gaps remain explicit |
| Independent product repair | B-232 adoption instruction contracts | Schema fix released in v0.86.1; retrieval succeeded, acceptance overconstrained; paging proposal deferred, marker wording follow-up recorded |
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
No paid Copilot call, setup, application baseline or outcome was run. Sanitized evidence and remaining
caps are in `meta/field-study-results.md`; raw records remain outside this repository. All named
semantic/value entries remain open, including B-42's independent FS2 requirement.

**CP1 container follow-up, 2026-09-06.** WSD-077 records the user-authorized, Sol-reviewed
Hyper-V-isolated Windows-container feasibility alternative. Hyper-V and Containers now report
Enabled after native UAC execution with restart disabled; Windows requires a manual restart.
Docker's signed installer is downloaded, but installation/image/application/Copilot execution
remains NOT RUN. The initial feature helper omitted dependency-delta evidence and ran before
helper-specific feedback arrived; both facts are retained. The reviewed resume helper and exact
handoff remain outside authoring Git. This advances host preparation, not a task outcome.

**CP1 offline container checkpoint, 2026-09-07.** Docker Desktop 4.89.0 now responds through its
Windows engine. The pinned toolchain image built, and root observed separate native PS7 7.6.4
and PS5.1 5.1.26100.33296 processes running as ContainerUser with Hyper-V isolation, no mounts,
network none, and requested 8 GiB / 100G resources. Each generic .NET smoke executed three tests:
3 passed initially, a production-source mutation produced 2 failures / 1 pass and exit 1, then
byte-exact restoration returned 3 passed and exit 0. Copilot 1.0.83 version/help ran without a
prompt or authentication. Sonnet 5 authored the disposable files; root reviewed, corrected and
executed them. Earlier helper/build failures remain in the external evidence. This proves bounded
offline toolchain feasibility, not ABP acceptance or Copilot task efficacy.

Next: certify the first eligible retained candidate in the original order, freeze/review its
oracles, and execute its ABP baseline. The 100-candidate inventory remains unchanged. Selective
egress, supported setup, account-specific purchase confirmation and paid calibration remain
outstanding. Charge one further preparation hour conservatively for today's installation follow-up,
toolchain work and records: **three of eight hours charged, five remain**. The container attempt's
two-hour checkpoint is consumed; additional container engineering needs a newly bounded review.
Detailed observations and limits are in `meta/field-study-results.md`.

**CP1 account confirmation, 2026-09-07.** The user reports Pro+ purchased at USD 39/month and
transcribes 0 / 7,000 included credits used, reset 2026-10-01, and additional usage disabled at
USD 0 / USD 0. The existing campaign ceiling is therefore Q = 7,000, subject to remaining balance
before calibration; the reported purchase does not establish task or execution readiness. Root
did not inspect a signed-in dashboard or invoice. No paid Copilot study call was made. The full
allocation and attribution are in `meta/field-study-results.md`.

**CP1 selection checkpoint, 2026-09-07 — STOPPED AT CANDIDATE CAP.** Terra reviewed the 16
retained unresolved candidates in their frozen order and excluded all 16. Sol independently
reviewed the four ambiguous semantic cases from the contract and source, supporting exclusion
because they lack the required independent nonlocal decisions; absent runtime evidence was not
the rejection basis. Root checked all 16 commit/first-parent references and the unchanged input
ledger, re-read the closest file-count case and selected source deltas, and retained the earlier
84 exclusions. Result: **no qualified task at 100**, not a Copilot or framework task outcome.

One promising code portion sat inside a nine-file integration. Root caught an initial count that
omitted two authored documents; Terra corrected it before selection. The complete integration
cannot be trimmed to meet the frozen limit. No candidate 101, task cards, application baseline,
adoption or paid study call followed. Charge another half-hour conservatively: **3.5 of eight
preparation hours charged, 4.5 remain**; remaining time does not reopen the candidate cap. Further
selection needs a separately reviewed prospective sampling contract. Existing semantic/value
entries remain open; raw evidence and the current external handoff remain outside authoring Git.

**CP2 proposal, 2026-09-07 — AWAITING SCOPE APPROVAL.** The user's "so now what?" follow-up
prompted a concrete alternative to restarting selection: one purposively curated application task
from the known near-miss, preserving the complete pre-change repository. This explicitly changes
the task unit and question; it does not make the whole nine-file integration eligible or reopen
CP1. Sol proposed the initial route; Sonnet 5 critiqued it; root replaced the paper-only checkpoint
and whole-integration replay with the bounded proposal in
`.claude/plans/2026-09-07-cp2-curated-replay.md`. WSD-078 records the alternatives and limits.

The proposal requests one approval for the staged attempt: 90 minutes for scope/source baseline,
60 for concrete acceptance, 60 for reviewed network controls, 30 for final preparation, then
original capped paid work only after all readiness/calibration gates. Passed stages advance without
another user-approval request; failed prerequisites and timeouts stop. Charge 0.5 hours for this
proposal/review/record checkpoint: **four of eight preparation hours charged, four remain**.
No CP2 task, oracle, application build, network change or paid Copilot prompt has run. Plan review
is not execution readiness; the changed task unit awaits explicit user approval.

**CP2 Opus review, 2026-09-07 — SCOPE APPROVAL STILL PENDING.** At the user's request, Claude
Opus 5 adversarially reviewed the frozen proposal and external pre/post source packet. Initial
verdict REVISE; root checked the source and Opus explicitly retracted its offline-impossibility,
strong decision-overlap and test-count claims. The corrected critique retains useful construction
obligations: each decision independently red, positive warning-capture control plus behavioral
assertions, alternative-tolerant grading, and honest limits on retrieval probes. Source-level
feasibility is not an executed baseline or oracle. The plan incorporates these obligations; it
does not adopt the suggested two-decision fallback, drop a required stage, or relax network controls.
See `.claude/plans/2026-09-07-cp2-opus-critique.md` for provenance and adjudication.
The final Opus check accepted the revised frozen proposal with no remaining correction required
before approval. A preceding failed packet delivery was correctly classified cannot-examine and
retained separately; it is not counted as acceptance. Neither verdict supplies execution evidence.

Charge a further **0.5 preparation hours** for this review/source-check/record checkpoint:
**4.5 of eight hours charged, 3.5 remain**. Each stage is now explicitly bounded by the lesser of
its original ceiling and the remaining global budget; the four-hour sum of nominal ceilings is
not an extension or a promised runtime. No CP2 execution or paid Copilot study call followed.

**Opus review RCA.** Earlier design acceptance left instrumentation obligations too implicit;
it did not establish that the future oracle distinguishes independent decisions, working warning
capture or supported alternatives. Parser gates cannot establish those behavioral facts. The
adversarial review also produced confident source errors, caught by direct source checks and a
corrective follow-up. This exposes any review summary used as execution evidence or an unverified
verdict: preserve retractions and require concrete red/green evidence within the existing stages.
No new generic gate or product change is warranted by this proposal-only checkpoint.

**CP2 authorized execution, 2026-09-07 — STOPPED AT NETWORK PREPARATION.** The user's
"ok go ahead and work through it" approves the reviewed bounded attempt, including automatic
progression after passed stages. Independent Sonnet 5 scope review accepted the three-decision
contract before build work. Root verified the complete pre-change export against all 21,867 Git
blob hashes and observed actual application tests under Hyper-V isolation, ContainerUser, no mounts
and network none. Direct PS7 and PS5.1 each passed 372 tests across the four relevant projects.
The first broader run failed because a repository-defined runtime plug-in had not been built;
building that existing fixture offline made all 326 MVC tests pass without source edits or filters.
A temporary checkout-source mutation produced three Timing failures, then restoration returned
8/8 on both hosts, with matching original/restored source hashes. Stage 1 charged 55 minutes,
bringing preparation to 325 of 480 minutes. The 60-minute acceptance stage began at 13:19 London;
no network implementation, adoption or paid Copilot study call has followed this checkpoint.

Stage 2 subsequently passed independent Opus 5 review: the full valid, alternative and restored
clean states passed 390/390 on each host, and targeted controls separated all three decisions.
Root checked raw results and parent/restored source hashes. A stale routing exit was excluded from
scoring in favor of a source-bound corrected control; the summarizer rejected mismatched control
sources before accepting the corrected records on both hosts. The non-overwriting candidate grader
and any unfamiliar supported-shape binding remain preparation obligations. Stage 2 charged 57
minutes, reaching 382 of 480; Stage 3 began at 14:16 London with its existing 60-minute ceiling.

Stage 3 stopped before endpoint/egress testing. The reviewed private-network probe successfully
created and removed its network through Docker, but an overbroad adapter-difference predicate
flagged the expected switch-extension class as an unclassified host change. Root and Opus rejected
that as evidence of a host vNIC hazard or impossible isolation. Pre-existing adapter rows and IPv4
routes were unchanged; final captured network/adapter/route views match before. Per-interface IP
addresses were not captured. Selective transport, retrieval controls and all deny probes remain
unestablished. Stage 3 charged 27 minutes; records/checks/commit/push/CI conservatively charge 20,
reaching **429/480 minutes** with 51 unallocated. Stage 4, calibration, adoption and both study arms
remain not run, with zero paid Copilot study calls. No automatic retry, substitute or waiver follows
this stop; the full evidence limits are in `meta/field-study-results.md`.

**CP2 execution RCA.** Shipped parser gates cannot establish external application preparation or
network measurement truth. The existing source and red/green obligations exposed newline export,
a missing runtime fixture, stale native exits and mismatched control-source records; those were
corrected before acceptance passed. The network critiques then accepted an adapter-delta predicate
without distinguishing switch-extension objects from host vNICs, so it could stop without measuring
the intended hazard. Root and the follow-up Opus review caught that interpretation error; the
bounded candidate ended without endpoint evidence. The same class exposes the route/network-list
deltas and temporary CLI evidence lifecycle: raw differences and vanished inspect objects cannot
certify isolation. The sweep retains those gaps, rejected records and unknown-shape grading debt;
no new general gate, shipped behavior change or efficacy conclusion is warranted.

**CP2 retirement decision, 2026-09-07 — CLOSED WITHOUT PAID EXECUTION.** At the user's request, a
fresh read-only Claude Opus 5 xhigh review assessed the stopped attempt and recommended retirement;
root accepted that conclusion while treating stage ceilings as maxima rather than proof of
arithmetic impossibility. The user then authorized the closure. A credible network redesign and
independent control pass is disproportionate to the descriptive value of one curated maintainer
case, which would close neither B-42 nor B-225. CP2 is retired for low decision value, not network
impossibility. Preserve its offline application/oracle evidence and explicit grader gaps. No
network retry, calibration, adoption, paid task arm, product change or efficacy claim follows.
Reopening requires a fresh decision triggered by an independent participant, an otherwise-observed
isolation capability, or a named decision that materially depends on the result. Closure work
brings the conservative preparation ledger to **449/480 minutes**, with 31 unused and zero Copilot
study credits spent.

**CP1 preparation RCA.** No shipped defect was reproduced. Parser/release gates did not establish
Windows guest availability, application buildability, independent oracle reachability or actual
Copilot use because those are study execution obligations. The same exposure applies to B-216,
B-222–B-225 and B-42: a reviewed packet or released carrier can be mistaken for observed value.
The sweep retained those gaps and separate series instead of closing entries or adding a generic
gate. The bounded response is provisioning and concrete evidence, not more evaluation machinery.
The container follow-up exposed the same evidence boundary in a one-off provisioning helper:
root-feature states did not enumerate dependency changes. Sol caught it; the resume helper now
captures full snapshots and attempts post-state even after failure. The original missing delta
remains missing. No shipped gate covers external host provisioning, and no new generic gate is added.
The resumed smoke also exposed validly parsed observer defects: a read-only PowerShell variable,
an exit-code scope error introduced during root's correction, and a version matcher rejecting
sentence punctuation. Native ACL account-name resolution failed separately. Parser gates cannot
establish these runtime facts. Root retained the failures, verified the account SID, demonstrated
native exits 7 and 0 on both hosts, and inspected the final TRX nodes and restored source bytes.
The same exposure applies to other command-output observers and provisioning helpers; this is
bounded execution evidence, not a new general gate or a framework defect finding.
Candidate qualification exposed another instance of the same boundary: a source-file subset was
mistaken for the whole integration, and test cases or preservation obligations could inflate the
independent-decision count. Root corrected the count; Sol's source review separated required
decisions from downstream checks. The sweep covered all retained unresolved entries and the
earlier over-limit inventories. Parser gates cannot certify task suitability, so the response is
the frozen stopping rule and retained review evidence, with no generic selection gate added.
The follow-up proposal exposed a proportionality problem: another paper-only hour or replay of
unrelated editorial work would consume preparation without establishing an application baseline.
Independent critique rejected the implied prospective-selection claim and unsupported causal
language. The revised proposal explicitly changes the task unit, discloses curated selection, and
puts a short scope check and actual source execution first. The same exposure applies to future
historical replays; document the chosen unit and claim limits rather than silently trimming it or
adding another gate. Model-dependent retrieval controls must be exercised during capped calibration,
with the external policy in place first; requiring a model probe before permitting any calibration
would create a circular readiness condition.

Original detailed open-entry history is preserved at Git baseline
`87bfe1942b687a47c0f5d87cdfd992e24579ed22:meta/BACKLOG.md` and linked plans. Superseded commands,
deadlines and incorrect absence-of-production-use claims are no longer execution instructions.
B-219 and B-221 — see `meta/BACKLOG-DONE.md`.

## Primary value increment

**B-222/B-223 acceptance planning, 2026-09-08.** The user requested an executable plan and two
adversarial design reviews, including a new-context review and Opus. The bounded proposal is
`.claude/plans/2026-09-08-b222-b223-semantic-acceptance.md`; its companion
`2026-09-08-b222-b223-adversarial-reviews.md` retains review provenance and corrections. It selects
monorepo component observations for discovery, grounded capture, confirmed dependency refresh,
and deliberate budget/continuation boundaries. The retained PK-2 input commit and output hash were
checked; the deleted PK-1 fixture must not be represented as recovered. The bounded execution is
now recorded in `meta/repository-knowledge-semantic-acceptance.md`; current statuses stay partial.
This does not reopen CP2 or authorize B-224/B-225 live work.
The proposal uses restricted-tool Claude authoring calls on the monorepo component. A pass would
show no reproduced defect in that case, not carrier causation, full shipped-worker compliance,
other-stack semantic parity, or Copilot/value evidence. WSD-080 records the bounded decision.

**Planning RCA.** Source review found the draft fixture lacked the ownership inventory required
by the subject, and the draft write/scoring rules omitted permitted discovery-note/summary writes.
The existing model launcher also discards partial output on timeout. Parser gates do not evaluate
an ad hoc experiment's input validity, permissions or evidence retention. The correction names
complete component prerequisites, one allowed-delta list and retained partial logs; the sibling
sweep distinguishes Angular A7 from .NET/monorepo A8. Actual fixture/observer calibration remains
an execution obligation, with no new general gate or product defect claimed from this review.
Final delta review also caught a wrong `DocClaims -DistRoot` target and ordinary-file-only write
calibration. The corrected recipe uses a single .NET copy (observed named red then restored clean
on both native hosts at CP437); write controls include the actual skill path class and classify a
denied route separately from a product miss. Other restricted configuration writes remain exposed
to that distinction. Both reviews and final source adjudication are recorded in the companion.
**Delivery correction.** First CI rejected an account-qualified launcher path in the plan; this
was root's documentation defect, not a host failure. The existing privacy gate caught it, but the
local planning checks had omitted that scan, and the outgoing guard is not the same instrument.
Replaced the literal with environment-based resolution plus an unavailable-route stop; observed
the named privacy red then clean on both native hosts at CP437. Other copied CLI examples and local
evidence references share the exposure. No gate weakening or published-history rewrite followed.

**B-222/B-223 semantic acceptance execution, 2026-09-08.** Six restricted Sonnet calls used
USD2.4739664 in reported CLI list-price accounting and completed inside the 80-minute actor-stage
limit. Corrected D passed the quiet tombstone equality and required helper/config plus scoped-UI
targets, while retaining semantic, read-count and dependency-hop misses. B reached exactly 40
successful distinct content reads and B-continue read every previously unread eligible source;
both retained eligibility/hop reporting errors. C's ordinary/docs writes worked but the required
`.claude/skills` write control was denied, so C1/C2 and the dependent R-confirm are CANNOT-EXAMINE
for this route. Read-only R correctly proposed the 3-to-5 owner refresh without applying it; its
missing-helper case proposed the right downgrade shape but falsely reported the whole caller file
absent. The full dispositions, hashes, fixture-review corrections and scope limits are in the
result record. No Copilot, target-host, value or other-stack semantic claim follows.

**Execution RCA.** Parser and document gates establish carrier shape, not semantic model adherence
or the validity of an ad hoc evaluation world. Independent review caught an unbound D source, an
invalid `$15` R JSON construction and line-ending-divergent base histories; typed-event and byte
observers caught model overclaims, incorrect read/hop totals and the destination-specific write
denial. The current carriers already state the missed obligations, so no louder duplicate product
instruction or generic gate was added. The same terminal-success-versus-semantic-success exposure
remains for every prose-directed workflow and is retained as an evidence limit.

**Targeted safe-write follow-up, 2026-09-08.** A direct MCP permission handler could not coexist
with the frozen safe-mode route; no-safe calibration/C/R-confirm attempts were retained as route
development and rejected for acceptance. The official Agent SDK host callback then preserved
safe/restricted mode and passed both ordinary and `.claude/skills` write controls. On that valid
route, C changed exactly ten allowed paths and preserved every other byte. C1 remained NOT
EXERCISED because no defensible operation skill/reference was minted; C2 missed because the parent
did not re-ground factual output, repeated unsupported retry/lease/generated claims and wrote 13
summary lines against a cap of 12. R-confirm reread the decisive caller/helper/config sources
correctly but refused the exact owner-approved patch and both control writes, so confirmed
application is a semantic MISS rather than CANNOT-EXAMINE. The full hashes, costs and reviewer
evidence are appended to `meta/repository-knowledge-semantic-acceptance.md`.

**Follow-up RCA.** Static gates could not reveal that safe mode suppressed the proposed MCP
permission extension, that a terminally successful capture relied on unread evidence, or that the
actor would ignore current user-level exact approval. A calibrated host write callback plus raw
event and byte comparison distinguished route availability from semantic adherence. The current
carrier/request already states grounding, bounded-summary and confirmation obligations, so no
duplicate product wording or generic evaluation harness was added. Other host permission channels
and prose workflows remain exposed to the same route-versus-behaviour ambiguity.

### B-232 · Repair adoption instruction delivery and archive-plan documentation

**Filed against:** v0.86.0 (2026-09-09).
**Priority / effort:** P2 / M. **Status:** PARTIALLY DONE. Delivery A released in v0.86.1. Delivery B's read-only observation retrieved the full source but did not pass an overconstrained frozen acceptance test; comprehension/execution failure is not established. No candidate paragraph shipped; B remains deferred.

**Observed problem.** A standalone ABP preparation attempt produced a bare-array
archive plan; the actual helper requires an object with an `entries` array and
correctly rejected it before movement. All three adoption documents omit that
explicit wrapper/example; existing tests construct the wrapper themselves.
Native Copilot also returned a too-large message instead of the 39.4 KB adoption
workflow, while reporting tool success. Sonnet later corrected the plan and
preserved archived bytes but did not complete adoption. These observations do
not establish model superiority, product efficacy, or a conforming headless run.

**Plan / review.** `.claude/plans/2026-09-09-adoption-execution-repair.md` and its
`-review.md` sibling; WSD-082. Two fresh Read-only Opus 5 sessions returned REVISE.
Root incorporated concrete schema/test/fixture corrections. First product delivery:
correct prose plus a labelled executable example in all three stacks, exercised
through the real helper by the existing integrity suite on PS7 and PS5.1. Keep
the helper's strict contract. Second proposal: bounded complete-workflow read
recovery in the existing rules carrier; exact placement and native behavioral
evidence are required before delivery. No operator tooling workstream or new
generic parser/runner, and no guard/provenance/ownership relaxation.

**Done when.** The first delivery has observed missing-example RED, valid-example
GREEN, bare-array rejection RED with unchanged inputs, and restored GREEN on both
hosts; normal source composition, installation, changelogs, release and independent
implementation review complete. Track the second proposal explicitly as deferred
or delivered with its own narrow evidence, never infer comprehension from parser
presence. The subsequent user request authorized implementation and an Opus handoff
for delivery A, but did not authorize the deferred live probe. The later "ok let's do it"
authorized the separately frozen bounded observation recorded below, with no retries.

**Delivery A evidence.** Frozen implementation `afd3486`; fresh Opus 5 source
review ACCEPT, with CLI budget-error termination and an inaccurate host-receipt
claim explicitly adjudicated in the review record. Root-observed native PS7 and
PS5.1, code page 437: 34 archive cases and 8 installer cases each, all final PASS.
Missing-example RED, actual bare-array Freeze exit 3 without mutation, and restored
GREEN are retained. Source helper unchanged; no further Copilot/ABP run.

**RCA.** Fixture code supplied a correct schema without testing the instructions
that asked a model to produce it. The bounded source sweep found the same omission
in exactly the three stack adoption commands; all three are repaired together.
Tool-result success, checkpoint commits and
byte-integrity PASS do not establish instruction consumption or adoption completion.
Prior launch/receipt mistakes and unmet headless restricted-surface proof remain
confounders. RK1 and the application bug remain unrun; this item does not close
B-225 or authorize more model spend.

**Delivery B observation, 2026-09-09.** The subsequently authorized one-session
read-only probe used public released docs plus the candidate in an isolated local
fixture. Independent blind-first critique corrected the trigger, credit-threshold
wording, host configuration and semantic oracle before dispatch. Native Copilot
1.0.83 / Sonnet 5 medium received the exact candidate before a real oversized read,
then retrieved the complete 395-line source with `forceReadLargeFiles`, not the
required contiguous ranges. No fixture bytes changed. The final answer omitted
material frozen-plan/marker/headless obligations and supplied wrong line references;
a separate result reviewer confirmed the failed acceptance. Receipt: 13.3659 credits,
20.034 seconds, no paid retry. No product paragraph or release follows; B remains
deferred. Full evidence and claim limits: `meta/b232-read-recovery-observation.md`.

**Observation RCA.** Parser gates and tool-success flags cannot establish complete
instruction delivery or comprehension. Source equality proved full delivery through
the unexpected native option; frozen criteria caught the missed read method and
semantic/source-reference defects. Other long prose workflows share this exposure,
but the existing evidence/uncertainty rules already address it. Retain this bounded
result rather than adding duplicate prose, a generic gate or another model attempt.

**Interpretation correction, 2026-09-09.** The user's harness challenge exposed an
overclaim in the preceding adjudication. Native full retrieval met the practical
objective; the frozen paging method was unnecessarily restrictive. The prompt asked
for a concise summary, so omissions against a detailed private scoring checklist do
not establish failed comprehension. Incorrect numeric references and the overbroad
headless-completion statement remain answer defects; their cause and impact on actual
execution are unknown. Preserve historical scores/reviews without treating them as
product efficacy or execution evidence. Future justified observations should grade
complete content independent of read method, make scored questions explicit, and
provide calibrated citation support. No new run or general harness is authorized.

**Bounded source follow-up, implemented for v0.86.2.** The user authorized Opus
adversarial review followed by implementation. Both fresh Opus design and frozen
implementation reviews returned ACCEPT. All three stack overviews now distinguish
retaining the existing marker on pre-bootstrap verification failure from restoring
saved bytes after removal. Root verified every other workflow byte unchanged;
Phase 7, helpers, guards and frozen inventory are intact. Direct PS7 and PS5.1 at
CP437 each passed 34 archive-integrity and 8 installer cases, including observed
negative controls and clean reruns. Frozen range, review identities, hashes and
limits: `.claude/plans/2026-09-09-b232-marker-wording.md`. Normal release/CI promotion
is recorded separately; the read-recovery proposal remains deferred.

**Wording delivery RCA.** The overview collapsed two lifecycle states into one
restore instruction; Phase 7 already handled them correctly. Parser gates and
helper tests accept both versions because they do not compare the meaning of a
summary with its detailed steps: the unfixed archive suite passed 34/0. Source
review exposed the inconsistency, and the bounded sweep found exactly the same
phrase in the three stack overviews. Other lifecycle summaries share this class
of exposure, but the inspected Phase-7, installer and adapter contracts supplied
no additional defect requiring changes. No model-failure causation or new generic
gate follows from this prose repair.

**Correction RCA.** Reviewers enforced a frozen checklist without adequately checking
whether its method and answer requirements matched the practical task. Parser gates
cannot judge that mismatch. The same exposure applies to other protocol-based model
observations; assess the measurement premise, accept supported equivalent outcomes,
and separate omissions from wrong claims and observed actions. The original review
and receipts remain intact in `meta/b232-read-recovery-observation.md`.

### B-222 · Discover repository knowledge broadly, not only recurring recipes
**Filed against:** v0.83.0 (2026-09-05)
**Priority:** P1 · **Effort:** L · **Invariants:** #1 #2 #3 #6 #7
**Status:** PARTIALLY DONE. The three-stack implementation shipped in v0.84.0 and its aggregate/CI
release boundary passed. The 2026-09-08 synthetic monorepo observation exercised quiet facts,
exact 40-file exhaustion and continuation. Its safe-write follow-up exercised capture routing but
retained source-grounding, summary-bound and report-fidelity misses; representative enterprise and
target-host behavior remain unobserved. Does not depend on a registry or a private warehouse.

**Reporting coverage.** The [B-235 amendment](../.claude/plans/2026-09-10-reporting-knowledge-coverage.md)
adds one bounded reporting case to the existing A8/A7 discovery pass: trace a checked-in caller,
wrapper and helper through parameters, state, filters and result grain, while leaving a dynamic or
external branch honestly unresolved. Retain and address the known generic grounding failures; do
not rerun them merely under reporting names.

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
shipped in v0.84.0, and aggregate/CI release checks passed. The 2026-09-08 safe/restricted follow-up
proved the skill-path write route, but no substantive operation skill/reference was exercised and
factual capture retained grounding/truth misses. Refresh reread the changed caller/helper/config
correctly, then refused the exact owner-approved application; the separate missing-helper source
state also remains missed. Retained forward runs do not establish broad recall or target-host
efficacy. No registry, graph service or promotion system.

**Reporting coverage.** See the
[B-235 amendment](../.claude/plans/2026-09-10-reporting-knowledge-coverage.md). Reuse existing capture
and changed/missing-helper checks for report findings through the wiki, owner-document and map routes.
Refresh must recheck, narrow or conflict a retained claim after its helper predicate changes, without
overwriting owner content or inventing intent.

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
checks passed. The 2026-09-07 assisted run recorded cost and no direct scoped-knowledge read. A
2026-09-09 ordinary CLI run did directly navigate wiki content, read decisive source, implement the
scoped rule and pass hidden grading, but post-review found its synthetic wiki failed the shipped
validity check. A conforming ordinary fixture, VS Code, enterprise scale, generated-context growth
and outcome comparison remain unobserved. Host inventory and synthetic behavior are not efficacy.

**Reporting coverage.** The [B-235 amendment](../.claude/plans/2026-09-10-reporting-knowledge-coverage.md)
requires a fresh ordinary report-maintenance question to find a conforming retained artifact,
inspect decisive source and preserve unresolved intent. Retrieval is observed separately from an
answer reconstructed from source; an unread or invalid artifact cannot establish knowledge reuse.

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

**Bounded Copilot CLI observation (2026-09-07).** A user-authorized application ran on Windows with
Copilot CLI 1.0.80, GPT-5.4 at medium reasoning, and a 200-credit cap against an adopted ABP
Framework 10.6.0 worktree (`efc830c95f0e...`). The single prompt explicitly required the installed
`CLAUDE.md` bug-fix workflow and supplied the issue contract, so it was not the unnamed ordinary
feature/fix prompt required above. The trace recorded 21 model calls and 69 tool executions. It
directly inspected the affected Docs source, Razor page, localization, test fixtures, project file,
and `global.json`; it issued zero `skill` calls and no direct read of `FRAMEWORK-CONTEXT.md`,
`docs/wiki/INDEX.md`, an applicable `.claude/skills/*/SKILL.md`, or another generated knowledge map.
That is an observed access miss, not proof that no custom instruction was delivered: the final
request's host usage checkpoint reported 17,801 `custom_instructions` tokens, but did not attribute
them to individual files.

The completed implementation session used 88.84465 AI credits (87,379 uncached input, 1,261,056
cache-read, and 23,649 output tokens) in 21 requests. Two earlier launcher attempts were stopped and
emitted no usage checkpoint, so their additional cost is unknown. The completed session wrote the
regression first and reused the existing fixture/network seam, but the installed SDK could not
execute the repository's .NET 10 test project; the agent proceeded to production edits and returned
an unverified six-file result. Maintainer follow-up installed the official SDK in a disposable
location, used Hyper-V isolation around a host code-integrity block, observed the release-specific
mutation fail exactly the fallback assertion, repaired the test DI environment and extension seam,
passed all six application tests plus the Docs web build, and committed the seven-file result as
`d85e4c597649...`. A separate frozen-bundle Claude Opus 4.7 xhigh review returned APPROVE. These
later repairs and checks establish the delivered patch, not the task model's independent knowledge
application.

Local raw evidence at recording time: implementation JSONL SHA-256
`1716A228A3247D80272C6464557004029715E1293CE6908D8578C7D68C98F3B9`; usage JSON SHA-256
`6CB1BC719BF5C4C81383BB1A3F2A1A49D4423DD8FA5209CD79BA85729853635D`. No observer
positive/negative calibration, feature-only prompt, VS Code arm, pre-adoption context measurement,
or paired treatment ran. B-225 live execution remains NOT RUN; this observation must not be pooled
into RK1.

**Ordinary Copilot CLI observation and correction (2026-09-09).** B224-CLI-01 used one feature-only
prompt with no workflow, skill, path, rule or grader hint. Typed events show direct index, applicable
wiki-body, decisive retail-policy and opposing admin-policy reads; the actor added a regression,
observed the expected compile red, delegated to the retail policy, passed 4/0 visible checks and a
solution build, and its post-state passed the calibrated hidden grader at 7/0. The task reported
10.9919 AI credits; all three controls plus the task reported 24.9080. It missed the separate
classification/plan/wait rail. BEFORE/AFTER host totals were both 8,817 custom-instruction and
26,942 prompt tokens, but both already held the same populated context carrier, so broader
discovery/capture context growth remains CANNOT-EXAMINE.

Independent Astra xhigh review found the material boundary: AFTER's installed `wiki-check.ps1`
reports 37 failures because all 31 synthetic index rows are noncanonical and general-notes
frontmatter is malformed; BEFORE passes. The overlay contains the defects before actor dispatch.
This is construction failure, not actor/product failure: the direct reads and correct patch remain
observed, but conforming-framework acceptance is still open. Disabled hooks also mean 31 rows do
not exercise the 30-entry threshold transition. Exact launch/isolation flags lack a retained argv
receipt and remain operator reports. The full hashes, adjudication, review and stop guidance are in
`meta/b224-copilot-ordinary-acceptance.md`.

Do not repair and relabel this historical run or buy another tiny pass merely to replace it. Keep
the shipped mechanism, retire this fixture as an acceptance instrument, and let the next eligible
preselected independent FS2/B-225 field task drive strategy. Reopen focused synthetic work only for
a named decision such as a repeated field failure, missing/conflicting instruction, relevant host
change or destructive workflow. No product source change follows from this observation.

**Done when.** Carrier changes/static budgets pass normal gates; exact host/model observations and
gaps are recorded. A required unexercised host leaves PARTIALLY DONE status and narrowed claims,
not inferred parity. B-225 owns outcome comparison; host access does not substitute for it.

**Delivery RCA.** Carrier parity and footprint checks proved text delivery, not that an ordinary
feature-only task discovers, reads, and semantically applies the right scoped knowledge. That
evidence gap applies to every host-specific native instruction/skill route and remains open rather
than being converted into a parser gate. The B224-CLI-01 helper also calibrated application tests
but omitted the already-existing wiki check, allowing an invalid synthetic knowledge world to reach
the actor. Future fixtures must pass existing product validators before dispatch; one construction
miss does not justify a new generic gate.

### B-225 · Measure broad discovery's marginal value on the actual coding surfaces
**Filed against:** v0.83.0 (2026-09-05)
**Priority:** P1 · **Effort:** M protocol, execution depends on tasks/seats · **Invariants:** #3 #6
**Status:** PARTIALLY DONE. Offline protocol reviewed in
`meta/repository-knowledge-component-study.md`. The user authorized revision 1 execution on
2026-09-09; preparation stopped when Copilot 1.0.83 refused the required native sandbox policy.
Four provisional source task cards exist; executable eligibility, CONTROL construction and the
paired study remain unrun. No Copilot model call occurred at that initial stop. Controls are not
collectively observed; the named campaign, not this backlog entry alone, supplies execution authority.
The user-requested Sonnet follow-up demonstrated offline outer-container execution and provider
endpoint reachability, independently checked by root. Selective connected isolation remains
unproved; the next network-probe draft was rejected before execution for unsafe cleanup and
unchecked exits. See the packet's outer-container checkpoint; RK1 is not retired.
The subsequently authorized corrected checkpoint demonstrated a private peer path and a fixed,
credential-free provider relay with allowed/denied requests. Authenticated native Copilot transport
and comprehensive isolation were then unrun. Its original closed-port-refusal condition was unmet
and remains recorded separately; no effectiveness claim follows from the successful relay.
The next authorized checkpoint obtained one exact-nonce response from native Copilot 1.0.83,
gpt-5.4 medium, through relay-mediated auth and HTTP fallback (not BYOK), with a calibration-only
256-output-token clamp and no tools. Complete transport/access readiness remains unmet: the
post-paid second-request control missed the relay lifetime, and ordinary tool/observer controls,
CONTROL and task oracles remain unrun. The paired study is still NOT RUN.

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

**Execution checkpoint / RCA (2026-09-09).** Opus 5 xhigh reviewed the prospective v0.86-based
ablation and campaign (REVISE, then ACCEPT for preparation), reporting USD 0.9840065 combined
list-price cost. Native capability queries passed, but two offline CLI environments refused the
required policy; root independently reproduced it through the installed SDK, exit 3. Emitted
system-volume read access makes removal of the denials unsafe for the study. Actual network
policy says deny despite a conflicting UI label; no network leak or missing BaseContainer was
established. Release/capability checks cannot prove policy execution, and picker filtering cannot
prove file containment. The same class exposes online transport and zero-test discovery; the
latter is an explicit gap in one provisional card. Required isolation caught this before study
dispatch. Preserve selection/receipts and resume after a compatible route is demonstrated; no
generic gate, host reconfiguration or product release followed.

**Network follow-up / RCA (2026-09-09).** Root replaced the unsafe blanket cleanup with checked
owned-ID operations and obtained Opus contract critique. Peer nonce and fixed-provider relay
responses succeeded; direct actor/provider TCP timed out while matched controls connected. The
closed peer port timed out rather than refusing, so the original conjunction was not backfilled
as green. A separate relay observation records allowed/denied requests and measured forwarding.
All checkpoint-created containers/networks were removed; captured final host state matched the
baseline. Mechanism-specific refusals and over-specific control expectations must not become
universal impossibility claims. The same class affects diagnostic error classification and
evidence-file handling; no new generic gate or shipped change is justified.

**Native transport / RCA (2026-09-09).** Direct API-token authentication required an alternate-
provider flag but yielded an empty model list and a native "No supported model available" stop.
A reviewed normal-token-shaped bootstrap through fixed metadata routes then carried the native
non-BYOK HTTP request and exact fresh reply; actor direct provider-IP attempts still timed out
against successful proxy controls. Parser/CLI flags alone missed the minimum credit cap and the
fact that empty tool lists retain defaults; actual rejected preflights exposed both before spend.
The same class affects SDK auth status, complete response evidence and lifecycle controls. Ten
hostile cases plus metadata success ran on both client hosts. The late retry probe was cannot-
examine, not a deny; no relay restart regained a paid slot. Both containers/network were removed
and captured host fields matched baseline. Keep this narrow result and the remaining debts in the
existing packet; no general proxy platform, efficacy claim or product release follows.

**Resumption review / RCA (2026-09-09).** The user requested Opus adversarial review,
not renewed live execution. Fresh Opus 5 xhigh returned REVISE on the proposed four-hour
preparation extension: CONTROL construction was unallocated, candidate inspection and executed
eligibility were blurred, and oracle/transport/review work lacked a credible bounded allocation.
Root retains these findings, but corrected the review's fixed-body-relay premise, credit-minimum
interpretation, mandatory intermediate approvals and unsupported shortened-time arithmetic.
The next proposed step is only a 30-minute read-only retained-candidate/coverage audit; it cannot
produce READY or automatically launch another workstream. No revised design is locked.
Parser gates cannot detect omitted construction work or establish time feasibility; the same
exposure affects oracle review, CONTROL purity and host-readiness summaries. The independent
critique caught these omissions before execution. Full disposition and receipts:
`.claude/plans/2026-09-09-rk1-resumption-review.md`. Review reported USD 0.8299065; conservative
RK1 Claude total USD 7.920006 of USD 10. No Copilot run, container change or product release.

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

B-235 — see [`meta/BACKLOG-DONE.md`](BACKLOG-DONE.md). Its remaining reporting acceptance belongs
to B-222/B-223/B-224.
