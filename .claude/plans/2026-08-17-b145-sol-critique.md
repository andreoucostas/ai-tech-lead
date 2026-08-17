# Adversarial critique — B-145 guidance-effect canary

## VERDICT — REJECT

Reject this design as a new Copilot canary rig and do not spend the proposed 12+ live runs. It
rebuilds most of B-41's harness around a second executor, has no pre-registered stopping or effect
rule, and at `N=6` per arm can distinguish only an enormous binary effect. More importantly, the two
decisions offered as proportionality evidence do not require this instrument: B-17 has already been
correctly rejected for lack of observed harm, while B-66 has an observed field report and can be
decided on engineering judgement with an honest statement that its causal model effect is unmeasured.

If a future, concrete hooks-off Copilot failure makes an A/B worth buying, add a Copilot executor and
host-evidence adapter to `run-agent-evals.ps1`; do not create another fixture/orchestration/results
system. First prove that Copilot CLI exposes reliable machine-readable tool outcomes. If it does not,
grade final repository state by commands run by the harness itself and drop the tool-event signal.

## BLOCKING findings

### 1. This is a second harness in substance; the existing harness already supplies about 6 of the 8 required capabilities

**Evidence.** The proposed shape is fresh disposable repositories, framework installation, scenario
fixtures, two conditions, repeated execution, typed grading, and recorded results
(`.claude/plans/2026-08-17-b145-guidance-effect-canary-design.md:23-45,47-71`). B-41 already creates
and initializes isolated repositories (`.claude/evals/run-agent-evals.ps1:724-742,3203-3223`), installs
the selected dist (`:744-748`), selects declarative scenarios (`:3199-3202`), applies scenario-specific
conditions (`:3225-3338`), grades evidence (`:1012-1822,3344-3359`), retains/cleans scratch and appends
versioned results (`:3362-3371`). Its self-test contains reachable positive and negative grader worlds,
including Angular form-control cases (`:1826-2041`). What is genuinely missing is only (7) a Copilot
process/executor and (8) a Copilot transcript/evidence adapter: the current executor invokes `claude`
with Claude `stream-json` (`:971-1009`) and its parser requires Claude event invariants
(`:894-956`). On a capability count, **6/8 = 75%** of the needed rig already exists. That is a coarse
but explicit estimate; fixture and grader code are necessarily scenario-specific under either option.

The existing Copilot canaries are intentionally small one-off drivers: for example Canary 2 creates
two temp arms, invokes `copilot -p ... --no-color`, and regexes plain combined output
(`.claude/scripts/canary-copilot-instructions.ps1:47-99`). It has no typed tool-event parser. The
backlog already instructs “Reuse the B-41 harness; do not build a second one”
(`meta/BACKLOG.md:1772`) and describes B-140's executor boundary explicitly
(`meta/BACKLOG.md:4868-4880`).

**Why it matters.** A new rig duplicates lifecycle, isolation, scenario selection, grading contracts,
error classification, result recording, and self-tests. Every defect then needs two fixes and two
histories. The design's claim that “the same rig answers all three items”
(`...b145-guidance-effect-canary-design.md:20-21`) omits that the repo already has that rig. Twin
parity is **not** an extra objection here: `.claude/scripts/` is maintainer-only and expressly
PowerShell-only (`CLAUDE.md:66-71`). Ongoing duplicate-harness parity is the real cost, not a mandatory
`.sh` twin.

**Recommendation.** Choose **(iii) neither now**. If later evidence justifies the experiment, choose
**(ii) extend B-41** behind an executor interface, preserving one fixture/grader/result pipeline.
Do not choose (i). Make the Copilot executor feasibility check its own investigation: prove structured
tool command plus exit-status evidence, timeout/error classification, model/version capture, and a
known successful and known failing transcript before designing an A/B on top.

### 2. The feasibility gate has no threshold, and six runs cannot establish “near-perfect”

**Evidence.** Step 2 says only “If Arm A already scores near-perfect, STOP” after six runs
(`...b145-guidance-effect-canary-design.md:54-57`); pre-registration again uses “near-perfect” without
a number (`:63-68`). For a truly 95%-successful process, observing 6/6 has probability only
`0.95^6 = 0.7351`; one miss is not surprising. Conversely, 6/6 gives a very wide exact uncertainty
interval and does not establish a stable near-perfect population rate. The repo's six-run precedent
was a sharply pre-registered routing observation—`0/6`, with stated limits—not a universal sample-size
warrant (`meta/BACKLOG.md:1835-1861`).

Executed local calculation (no agent run):

```text
P(6 successes | p=.95)=0.735091890625
P(at least 5/6 | p=.90)=0.885735
```

**Why it matters.** Under the current prose, 4/6, 5/6, and 6/6 can all be called “near-perfect” after
the fact. A split 4/6 baseline has both material apparent headroom and severe uncertainty; stopping or
continuing can be selected to suit the desired answer. B-129 shows why incomplete/split observations
must not receive a disposition: its 4/6 diagnostic was explicitly non-scoreable
(`meta/eval-results.md:1366-1371`).

**Recommendation.** If revived as an explicitly exploratory canary, use this concrete gate:

- `6/6`: **NO OBSERVED HEADROOM; STOP**, without claiming the true process is near-perfect.
- `0/6` through `4/6`: **HEADROOM OBSERVED; continue** only if the effect-size rule in finding 5 was
  pre-registered and the experiment remains worth its cost.
- `5/6`: **INCONCLUSIVE feasibility gate**; do not choose a direction from these six. Either stop with
  no decision or pre-register an additional batch before seeing results. Do not adaptively add runs.
- Tool, build, timeout, or infrastructure errors are invalid trials with a pre-declared replacement
  cap; exceeding it voids the batch.

That rule answers the requested 4/6 case: continue, but only as a coarse large-effect probe; never
describe 4/6 as near-perfect.

### 3. Three of the four proposed signals are weak or gameable, and the strongest one is underspecified

**Evidence.** The four signals appear at design lines 40-45. B-72 already demonstrates that pattern
graders missed setter/getter and `input.required` forms recommended by the guidance, allowing the
reported defect to score PASS (`meta/BACKLOG.md:673-681`), and that a combined `cva` signal scored a
correct implementation and a runtime-broken double registration identically (`:692-696`).

Signal-by-signal:

1. **“Produced test FAILS on unfixed code.”** This is the right primary concept, but a non-compiling
   test, missing dependency, unrelated pre-existing failure, or deliberate `throw` also exits nonzero.
   It is cheaply observable only if the fixture has a real build/test command and the harness—not the
   model—runs it after the agent exits. The existing toy fixture is not such a test project: its
   `tests/Test-Calculator.ps1` scans production source text (`run-agent-evals.ps1:724-736`). A candidate
   test must fail on the planted defect **and pass after a harness-owned oracle patch fixes only that
   defect**. That two-state mutation check is the constructible green world required by rule 4
   (`CLAUDE.md:149-159`).
2. **“No tautological assertion.”** A finite byte-pattern blacklist is trivially evaded with helper
   methods, aliases, computed expected values, snapshots, or a different assertion library. Guidance
   can itself steer output outside enumerated patterns, exactly B-72 finding 1. It can remain a
   diagnostic for known idioms, not an outcome.
3. **“Does not mock the type under test.”** The same weakness applies: wrapper interfaces, aliases,
   partial substitutes, reflection, hand-written fakes, and mocking owned collaborators can evade or
   falsely trip a pattern scan. It also confuses a syntactic technique with whether the test detects
   the planted behavior. Cut it as a scored signal.
4. **“Agent ran the suite.”** A typed invocation proves activity, not integrity: the agent can run an
   irrelevant filter, run before writing the test, or ignore a failure. It is also not presently
   available from the plain Copilot canary output, whose “ToolUsed” is a prose regex
   (`canary-copilot-instructions.ps1:89-98`). Guidance explicitly telling the model to run tests can
   improve this process signal without improving the produced test. Keep it as telemetry only if the
   host exposes reliable structured evidence.

**Why it matters.** Selecting any of signals 2-4 as the pre-registered primary would recreate B-72:
the guidance can change the scored syntax or ceremony while behavior remains unchanged. Even signal 1
produces a false positive unless failure attribution and the fixed-code success world are enforced.

**Recommendation.** Make the sole primary endpoint a harness-owned mutation score: the newly produced
test is discovered, builds, **fails for the intended assertion on unfixed production code, and passes
after only the oracle production fix**. Add guards that production and pre-existing tests were not
changed, the new test actually ran, and the suite passes in the fixed world. Cut “no mock” and “no
tautology” from decision scoring; retain narrow lint diagnostics only. Treat agent-run evidence as
secondary telemetry, never a substitute for the harness's post-run execution.

### 4. The promised one-variable comparison is not yet demonstrated

**Evidence.** The design says Arm B is byte-identical “plus the candidate guidance file”
(`...b145-guidance-effect-canary-design.md:28-30`), but does not name the exact file, bytes, `applyTo`,
model, Copilot mode/flags, trust state, tool permissions, run order, or whether the current broad
carrier already contains semantically identical rules. The earlier critique established that the
existing carrier already carries the red-test and test-integrity rules
(`.claude/plans/2026-08-17-b17-b81-sol-critique.md:21-30`). Thus the likely B-17 comparison is
“existing guidance” versus “existing guidance plus a more salient duplicate,” not guidance absent
versus present. Copilot trust state is a known behavioral variable: fresh untrusted and trusted
fixtures behaved differently (`meta/host-certification.md:13`).

**Why it matters.** Independent stochastic arms do not pair observations merely because the fixture
bytes began equal. Sequential execution confounds arm with time, host/model drift, quota state, and
run order. If delivery of the conditional file is not verified per run, a null can mean “not loaded,”
not “loaded but ineffective.” If the broad carrier already says the same thing, a positive result
measures marginal repetition/salience only.

**Recommendation.** Any revival must freeze and hash the exact arm delta, name the estimand as
**marginal effect of the added carrier/restatement**, alternate or randomized-block arm order, record
CLI/model/version/trust/permissions, and distinguish delivery from adherence. Do not claim literal
pairing unless matched seeds or another real coupling mechanism exists; call these two independent
samples from matched fixture conditions.

### 5. At N=6 per arm, the comparison detects only an enormous binary effect; the document currently invites a false null

**Evidence.** The design calls this a “trend instrument” but declares no success margin
(`...b145-guidance-effect-canary-design.md:63-71`). Exact two-sided Fisher calculations for 6+6
binary trials gave:

```text
0/6 vs 4/6: two-sided Fisher p=0.0606
0/6 vs 5/6: two-sided Fisher p=0.0152
0/6 vs 6/6: two-sided Fisher p=0.0022
1/6 vs 5/6: two-sided Fisher p=0.0801
1/6 vs 6/6: two-sided Fisher p=0.0152
2/6 vs 6/6: two-sided Fisher p=0.0606
```

Therefore the smallest observed separation reaching conventional two-sided 0.05 is five successes
(0/6 vs 5/6 or 1/6 vs 6/6). A plausible large-looking 0/6→4/6 or 1/6→5/6 does not clear it. The
design's phrase “no material difference” (`:66`) supplies neither a margin nor an equivalence test;
failure to detect is not evidence of no effect.

**Why it matters.** With this sample, a null result mostly says “no near-total transformation was
observed.” Acting on it as “guidance does not work” is statistically dishonest, while acting on a
visually attractive but non-pre-registered gap is post-hoc judgement dressed as measurement.

**Recommendation.** If the cheap exploratory run is ever justified, insert this sentence verbatim:

> With six independent runs per arm, this canary is capable only of detecting a very large behavioral
> effect; failure to meet the pre-registered margin is inconclusive about small or moderate effects and
> must not be reported as evidence that guidance generally does not work.

Pre-register a decision rule appropriate to that limitation—for example, authorize further study
only for `B-A >= 4/6` with no invalid trials, but do **not** call that statistical proof. If an actual
ship/no-ship causal claim is required, choose sample size from a stated minimum effect and error rates
before any run; `N=6` inherited from B-98 is not a power analysis.

### 6. Rule 6 points to deciding B-66 on judgement and dropping B-17, not building this instrument

**Evidence.** Rule 6 requires concrete observed harm and the materially smaller remedy
(`CLAUDE.md:163-176`). B-17 has no field report and was already rejected on precisely that ground;
the prior critique recommends reopening only after a real hooks-off failure
(`...b17-b81-sol-critique.md:258-272`). B-66 is different: it records the first framework field report,
an absent forms surface, and a narrowly reviewed technical remedy (`meta/BACKLOG.md:533-547,562-574`).
It has remained blocked because the old probe passed unfixed (`:564-569`), not because the underlying
Angular advice is unknown.

The real cost is not “six cheap runs.” Before live use it requires a runnable defect fixture, package
restore/build stability, an oracle fix, a mutation grader with adversarial self-tests, a Copilot
executor/evidence investigation, arm/delivery controls, pre-registration and aggregation, then 6
baseline plus up to 6 treatment runs and replacements. Maintenance continues across Copilot output
and CLI changes. The repo's recent live-eval record shows the operational tax: one B-129 attempt
produced no trials due to PATH, later attempts consumed roughly $9 before a spend cap and hit separate
per-trial budget ceilings (`meta/eval-results.md:1334-1358,1375-1433`). Copilot quota differs, but
fixture, host drift, truncation, and void-run risk remain.

**Why it matters.** The proposed instrument removes no currently observed consumer harm. It may
produce evidence about one toy task on one host version. Meanwhile it turns a bounded content
judgement into a new maintained subsystem. “The product is prose” does not imply every prose edit
needs causal A/B proof; it requires honest evidence labels and proportional scope.

**Recommendation.** **Decide B-66 on judgement and skip this instrument.** Ship only the narrow,
technically verified forms guidance justified by its field report, labeling its behavioral steering
effect unmeasured; use ordinary content review and technical example tests. Keep B-17 rejected. Close
B-145 as disproportionate. Reopen an executor extension only after a concrete Copilot-output failure
creates an estimand that matters enough to pay for.

### 7. The design overclaims general guidance effectiveness from one narrow test-writing task

**Evidence.** The stated ambition is to convert “the framework's central claim” into measurement and
to answer B-66, B-17, and B-72 with one rig (`...b145-guidance-effect-canary-design.md:73-79`). Yet
the only specified outcome is a test-integrity fixture (`:37-45`). B-66 concerns Angular architecture
and runtime double registration; B-17 concerns marginal salience/delivery; B-72 concerns probe
validity. These are different mechanisms and outcomes.

**Why it matters.** This design cannot see guidance effects on planning, clarification, abstention,
architecture choices, security, maintainability, review quality, or error recovery. It also misses
effects in large/dirty repositories, long conversations, repeated sessions, interactive VS Code,
Claude Code, hooks-on Copilot, different languages/test frameworks, other models/versions, and human
developer response. Binary mutation success misses partial improvements, regressions elsewhere,
refusals, latency/cost, context displacement, and false-positive over-application. A result on a toy
fixture cannot validate or invalidate framework prose generally.

**Recommendation.** If revived, title and claims must name the exact population and endpoint:
“marginal effect of one Copilot instruction delta on mutation-detecting tests in one fixture under
Copilot CLI `<version>`, hooks off.” List the exclusions above and prohibit extrapolation to B-66 or
the framework's overall value proposition without separate scenarios.

### 8. The design omits operational and decision details required before any live run

**Evidence.** The document does not specify: exact candidate bytes/path/frontmatter; fixture stack,
dependency lock and offline/cache behavior; exact Copilot invocation/model/permissions/trust; whether
machine-readable tool events exist; primary endpoint; success margin; headroom threshold; arm order;
invalid/error/replacement rules; stopping for 5/6; production/test-file mutation boundaries; oracle
fix; build-versus-assertion failure attribution; delivery verification; result schema; retained raw
artifacts; privacy/secrets sweep; quota/budget/time ceiling; or what backlog decision each possible
outcome triggers. It promises these will be pre-registered later (`:61-68`) even though several decide
whether the design is feasible at all.

**Why it matters.** Those are not implementation trivia. They define the experiment, its reachable
green/red worlds, its cost, and whether a null is interpretable. B-129's record shows that missing or
mis-sized operational boundaries can void a full paid batch (`meta/eval-results.md:1400-1433`).

**Recommendation.** Do not approve a placeholder promise to pre-register. If the item is reopened,
the replacement design must contain every item above before code, including a complete outcome table:
`NO_OBSERVED_HEADROOM`, `LARGE_EFFECT_CANDIDATE`, `NO_LARGE_EFFECT_DETECTED`, `INCONCLUSIVE`, and
`VOID`, each mapped to an authorized action and explicitly excluding claims it cannot support.

## NON-BLOCKING findings

### 9. “Hooks OFF” is a legitimate population choice, but it narrows rather than strengthens the claim

**Evidence.** The design explicitly selects hooks-off Copilot (`...b145-guidance-effect-canary-design.md:25-26`).
Host certification shows hook behavior and instruction delivery are separate capabilities, and even
Copilot host behavior changed between versions (`meta/host-certification.md:13-17`).

**Why it matters.** This is internally coherent for B-17's concern, but cannot support claims about
the installed default experience where hooks may be enabled, nor VS Code where no live seat is
certified (`meta/host-certification.md:18`).

**Recommendation.** Retain hooks-off if revived, but state it in the estimand and exclusions. Do not
call it “the Copilot surface” without qualification.

### 10. Offline red-testing needs adversarial breadth, not merely one hand-written good and bad artifact

**Evidence.** Step 1 proposes one good and one bad test (`...b145-guidance-effect-canary-design.md:49-52`).
B-72's grader self-test was green while missing multiple common syntactic forms
(`meta/BACKLOG.md:673-681`). The failure was coverage, not absence of a nominal negative case.

**Why it matters.** A single positive/negative pair proves reachability but not resistance to the exact
guidance-driven transformations likely in live output.

**Recommendation.** If revived, use a small adversarial corpus: compile failure, unconditional throw,
irrelevant failing test, test filtered out, helper-hidden tautology, alias/fake/mock variants, changed
production code, weakened existing test, valid mutation-killing test, and valid differently styled
test. Require every claimed signal to have both a constructible pass and fail case.

## CHECKED AND FOUND CORRECT

### 11. The design correctly treats a green-before-change baseline as a void causal instrument

**Evidence.** It proposes stopping when the baseline leaves no observed headroom
(`...b145-guidance-effect-canary-design.md:54-57,68`). B-66's original baseline passed without forms
guidance (`meta/BACKLOG.md:562-569`), and B-72 records why that scenario could not red-test the change
(`meta/BACKLOG.md:683-690`).

**Why it matters.** Adding guidance after an already-green baseline cannot demonstrate improvement on
that endpoint.

**Recommendation.** Preserve the early-exit principle, but use the explicit, modest wording and rule
in finding 2 rather than “near-perfect.”

### 12. The prompt should state the business goal without naming the mechanism

**Evidence.** The design correctly identifies `formControlName`/validation wording as close to a
specification of the desired `NgControl` solution (`...b145-guidance-effect-canary-design.md:32-35`).
B-72 independently records the same prompt-telegraphing defect (`meta/BACKLOG.md:683-701`).

**Why it matters.** A mechanism-naming prompt measures prompt compliance, not marginal guidance
effect.

**Recommendation.** Keep this constraint and add an independent prompt review before fixture or
grader authors see live results.

### 13. Pre-registration, raw host version capture, and a non-release-gate role are correct safeguards

**Evidence.** The design requires pre-registration before live runs, records Copilot version, and
states the result is not a release gate (`...b145-guidance-effect-canary-design.md:61-71,88-89`). The
existing harness likewise captures commit, framework version, host version and results
(`run-agent-evals.ps1:3205-3210,3362-3367`).

**Why it matters.** These controls reduce post-hoc selection and make host drift visible.

**Recommendation.** Preserve them in any future extension, adding the missing thresholds, invalid-run
rules, exact model identifier, trust state, raw artifacts, and arm-order randomization described
above.

### 14. The design correctly insists on observable artifacts rather than transcript claims

**Evidence.** It rejects “the transcript mentions the rule” in favor of typed or executed evidence
(`...b145-guidance-effect-canary-design.md:37-45`). The existing harness similarly rejects keyword-only
evidence in self-test (`run-agent-evals.ps1:1872-1879,3157-3166`).

**Why it matters.** Models can narrate compliance without producing it.

**Recommendation.** Keep the principle, strengthen it to harness-owned post-run build/mutation
execution, and do not assume Copilot plain output is typed evidence.
