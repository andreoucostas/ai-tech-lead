# Agent-behavior eval results

Maintainer-triggered B-41 runs are appended here. These stochastic results are evidence and trend
data, not release gates. `PASS` requires observable repository or tool-event evidence; `FAIL`
means the behavior was exercised and missed; `INCONCLUSIVE` means the host or hook path was not
actually exercised; `ERROR` means the harness could not obtain valid evidence.

> **Adversarial-review invalidation (2026-07-17):** every run below predates the typed-event
> graders added after PR #2 review. The old grader searched raw JSONL, so prompt echoes and tool
> results could create false positives (the `skill-add-tests` run was demonstrably one: it stopped
> at a developer checkpoint yet was logged PASS). These rows are retained as an audit trail but
> are **not behavioral evidence and must not be used as a baseline**. Valid results begin only
> under a later heading that includes the framework commit and per-case model.


## 2026-07-17 10:49:11 +01:00 — framework v0.32.0

Host: Claude Code 2.1.212 (Claude Code) · model: sonnet · scratch: retained=True

- **ERROR install-handoff** — Cannot find path '<temp>\ai-tech-lead-agent-evals-20260717-103654\install-handoff\CLAUDE.md' because it does not exist.
- **ERROR route-fix** — agentExit=1; fixed=False rails=False testEvent=-1 productionEvent=-1
- **ERROR guard-retry** — agentExit=1; guardBlockObserved=False safeFinalFile=False
- **ERROR skill-add-tests** — agentExit=1; testArtifact=True skillObserved=True verification=False


## 2026-07-17 10:50:27 +01:00 — framework v0.32.0

Host: Claude Code 2.1.212 (Claude Code) · model: sonnet · scratch: retained=True

- **PASS install-handoff** — agentExit=0 timedOut=False; stamp=True commits=2 handoff=True stoppedBeforeBootstrap=True
- **PASS route-fix** — agentExit=0 timedOut=False; fixed=True rails=True testEvent=10610 productionEvent=15782
- **PASS guard-retry** — agentExit=0 timedOut=False; guardBlockObserved=True safeFinalFile=True
- **ERROR skill-add-tests** — agentExit=124 timedOut=True; testArtifact=True skillObserved=True verification=True


## 2026-07-17 11:03:37 +01:00 — framework v0.32.1

Host: Claude Code 2.1.212 (Claude Code) · model: sonnet · scratch: retained=True

- **PASS install-handoff** — agentExit=0 timedOut=False; stamp=True commits=2 handoff=True stoppedBeforeBootstrap=True
- **PASS route-fix** — agentExit=0 timedOut=False; fixed=True rails=True testEvent=8462 productionEvent=11744
- **PASS guard-retry** — agentExit=0 timedOut=False; guardBlockObserved=True safeFinalFile=True
- **PASS skill-add-tests** — agentExit=0 timedOut=False; testArtifact=True skillObserved=True verification=True


## 2026-07-17 11:03:47 +01:00 — framework v0.32.1

Host: Claude Code 2.1.212 (Claude Code) · model: sonnet · scratch: retained=True

- **ERROR install-handoff** — Claude CLI exceeded the 30s wall-clock limit.


## 2026-07-17 11:08:28 +01:00 — framework v0.32.1

Host: Claude Code 2.1.212 (Claude Code) · model: sonnet · scratch: retained=True

- **PASS haiku-convention-check** — agentExit=0 timedOut=False; plantedConventionFound=True
- **PASS haiku-bloat-radar** — agentExit=0 timedOut=False; plantedBloatFound=True
- **PASS haiku-debt-radar** — agentExit=0 timedOut=False; plantedDebtFound=True

## 2026-07-17 13:31:04 +01:00 — framework v0.32.2 (8859a394de25130bacb38cb207d2f14f9d455165)

Host: Claude Code 2.1.212 (Claude Code) · scratch: retained=True

- **PASS install-handoff** (model=sonnet) — agentExit=0 timedOut=False; stamp=True commits=2 installerTool=True finalHandoff=True bootstrapPending=True bootstrapTool=False
- **FAIL archived-redirect** (model=sonnet) — agentExit=0 timedOut=False; currentStamp=True frozenInstallerRan=False archivedInstallerTool=False commits=2 canonicalInstallerTool=False redirectedHandoff=False
- **ERROR route-fix** (model=sonnet) — Stream JSON must begin with system/init.
- **ERROR guard-retry** (model=sonnet) — Stream JSON must begin with system/init.
- **ERROR skill-add-tests** (model=sonnet) — Stream JSON must begin with system/init.
- **ERROR haiku-convention-check** (model=haiku; agent=convention-check) — Stream JSON must begin with system/init.
- **ERROR haiku-bloat-radar** (model=haiku; agent=bloat-radar) — Stream JSON must begin with system/init.
- **ERROR haiku-debt-radar** (model=haiku; agent=debt-radar) — Stream JSON must begin with system/init.

## 2026-07-17 13:42:23 +01:00 — framework v0.32.2 (b59cdeb52817cecea283cb5a8330c051d59e5ac9)

Host: Claude Code 2.1.212 (Claude Code) · scratch: retained=True

- **PASS install-handoff** (model=sonnet) — agentExit=0 timedOut=False; stamp=True commits=2 installerTool=True finalHandoff=True bootstrapPending=True bootstrapTool=False
- **FAIL archived-redirect** (model=sonnet) — agentExit=0 timedOut=False; currentStamp=False frozenInstallerRan=False archivedInstallerTool=False commits=1 canonicalInstallerTool=False redirectedHandoff=False
- **FAIL route-fix** (model=sonnet) — agentExit=0 timedOut=False; routeExercised=True fixed=True redTestEvent=-1 productionEdit=23 greenTestEvent=30
- **PASS guard-retry** (model=sonnet) — agentExit=0 timedOut=False; guardExercised=True blockedToolResult=True safeRetry=True safeFinalFile=True
- **FAIL skill-add-tests** (model=sonnet) — agentExit=0 timedOut=False; skillTool=True exactTestEdit=True boundaryCases=False verifiedAfterEdit=False
- **FAIL haiku-convention-check** (model=haiku; agent=convention-check) — agentExit=0 timedOut=False; finalFinding=False
- **PASS haiku-bloat-radar** (model=haiku; agent=bloat-radar) — agentExit=0 timedOut=False; finalFinding=True
- **PASS haiku-debt-radar** (model=haiku; agent=debt-radar) — agentExit=0 timedOut=False; finalFinding=True

## 2026-07-17 13:55:26 +01:00 — framework v0.32.2 (91a2ee5d357388c85b1dca541e0f211d40f43fc6)

Host: Claude Code 2.1.212 (Claude Code) · scratch: retained=True

- **FAIL archived-redirect** (model=sonnet) — agentExit=0 timedOut=False; currentStamp=True frozenInstallerRan=False archivedInstallerTool=False commits=2 canonicalInstallerTool=True redirectedHandoff=False

Post-run transcript review: the focused redirect run satisfied every typed/filesystem requirement;
its final answer said "canonical repo" rather than the grader's over-specific "canonical framework"
phrase and gave the developer-only `/bootstrap` handoff on a later line. The grader now treats those
as independent structured facts. The retained route-fix transcript likewise contains an exception-
bearing red run before the production edit and a clean PASS after it (Bash `tool_result.is_error`
does not represent command exit status), while skill-add-tests added executable boundary calls and
correctly left the planted production defect red. `haiku-convention-check` remains the genuine
behavioral miss: it found the defect but violated its required structured output contract.

## 2026-07-31 15:41:50 +01:00 — framework v0.39.0 (94b672d6e62076e998429da39c14d812fe7031f7)

Host: Claude Code 2.1.220 (Claude Code) · scratch: retained=True

- **PASS docs-tier-ondemand** (model=sonnet) — agentExit=0 timedOut=False; loaded=True followed=True class=OrderCoordinator


## 2026-07-31 15:42:41 +01:00 — framework v0.39.0 (94b672d6e62076e998429da39c14d812fe7031f7)

Host: Claude Code 2.1.220 (Claude Code) · scratch: retained=True

- **FAIL docs-tier-inline** (model=sonnet) — agentExit=0 timedOut=False; loaded=n/a followed=False class=Order

> **Grader false-negative invalidation (2026-07-31):** this row is not a behavioural failure.
> The created file declared `Order`, `OrderLine`, and `OrderFulfillmentCoordinator`; the grader
> inspected only the first class declaration. Retained as an audit trail, but it **must not be used
> as a baseline**.

## 2026-07-31 15:52:14 +01:00 — framework v0.39.0 (94b672d6e62076e998429da39c14d812fe7031f7)

Host: Claude Code 2.1.220 (Claude Code) · scratch: retained=True

- **ERROR docs-tier-nopointer** (model=sonnet) — Stream JSON must contain exactly one system/init event.


## 2026-07-31 15:53:43 +01:00 — framework v0.39.0 (94b672d6e62076e998429da39c14d812fe7031f7)

Host: Claude Code 2.1.220 (Claude Code) · scratch: retained=True

- **PASS docs-tier-ondemand** (model=sonnet) — agentExit=0 timedOut=False; loaded=True followed=True classes=OrderCoordinator


## 2026-07-31 15:54:41 +01:00 — framework v0.39.0 (94b672d6e62076e998429da39c14d812fe7031f7)

Host: Claude Code 2.1.220 (Claude Code) · scratch: retained=True

- **PASS docs-tier-inline** (model=sonnet) — agentExit=0 timedOut=False; loaded=n/a followed=True classes=OrderCoordinator


## 2026-07-31 15:56:29 +01:00 — framework v0.39.0 (94b672d6e62076e998429da39c14d812fe7031f7)

Host: Claude Code 2.1.220 (Claude Code) · scratch: retained=True

- **INCONCLUSIVE docs-tier-nopointer** (model=sonnet) — agentExit=0 timedOut=False; loaded=True followed=False classes=n/a


## 2026-07-31 15:57:55 +01:00 — framework v0.39.0 (94b672d6e62076e998429da39c14d812fe7031f7)

Host: Claude Code 2.1.220 (Claude Code) · scratch: retained=True

- **FAIL docs-tier-nopointer** (model=sonnet) — agentExit=0 timedOut=False; loaded=False followed=False classes=OrderFulfillmentOrchestrator

## Phase A synthesis — 2026-07-31, framework v0.39.0

Host: Claude Code 2.1.220 (Claude Code) · model: sonnet

**Question:** after `/bootstrap`, does an on-demand `docs/` file reach an agent, and is a
`CLAUDE.md` pointer what causes it? This question was raised by B-65.

**Method:** three arms ran on a bootstrapped .NET fixture using an arbitrary, unguessable repository
rule: orchestration classes are suffixed `Coordinator`; `Service` is reserved for HTTP clients.
Grading used observable evidence only: a `Read` tool event for `docs/patterns.md`, plus the class
names actually declared in new source files on disk. Final-message text was never grading evidence.

**Results:**

- **PASS — `docs-tier-ondemand` (file + pointer), 2 of 2 runs.** Both runs recorded
  `loaded=True followed=True` and declared `OrderCoordinator`.
- **PASS — `docs-tier-inline` (rule inlined in `CLAUDE.md`, control for rule clarity).** The valid
  run recorded `followed=True` and declared `OrderCoordinator`. This confirms that the rule is
  followable, so delivery rather than clarity is the variable under test. The earlier FAIL for this
  arm was a grader false negative and is invalidated above.
- **Split and inconclusive overall — `docs-tier-nopointer` (file present, no pointer).** One run
  ERRORed because of the stream schema, so no evidence was obtained; one was INCONCLUSIVE
  (`loaded=True`, but no new class was produced); and one FAILed (`loaded=False`, class
  `OrderFulfillmentOrchestrator`).

**Conclusions:**

1. **On-demand `docs/` files are reachable by an agent in a bootstrapped repository.** The prior
   working assumption that this delivery tier is effectively dead is falsified. This was the
   decision-relevant question, and it has a clear answer.
2. **Whether the pointer is what causes the load is unresolved.** The agent opened the file unaided
   in one of two valid control runs. At this sample size, that is indistinguishable from noise.
3. **The probe is sound.** Without the rule, the agent independently chose
   `OrderFulfillmentOrchestrator`—the same intent expressed with a different word—so the rule is
   genuinely not guessable from training, and "followed" really does mean the guidance arrived.

**Caveats:** there were two or fewer valid runs per arm, using one model (sonnet), one prompt, one
stack, and one host version. This is directional evidence, not a baseline, and must not be used to
gate a release.

## 2026-07-31 16:15:13 +01:00 — framework v0.39.0 (4a6499d39769343f8aba6f09153f26d6d6b5fef0)

Host: Claude Code 2.1.220 (Claude Code) · scratch: retained=True

- **FAIL angular-form-control** (model=sonnet) — agentExit=0 timedOut=False; cva=False ngcontrol=False formInputs= readDefaults=False


## 2026-07-31 16:16:20 +01:00 — framework v0.39.0 (4a6499d39769343f8aba6f09153f26d6d6b5fef0)

Host: Claude Code 2.1.220 (Claude Code) · scratch: retained=True

- **INCONCLUSIVE angular-form-control** (model=sonnet) — agentExit=0 timedOut=False; cva=False ngcontrol=False formInputs= readDefaults=True


## 2026-07-31 16:26:04 +01:00 — framework v0.39.0 (4a6499d39769343f8aba6f09153f26d6d6b5fef0)

Host: Claude Code 2.1.220 (Claude Code) · scratch: retained=True

- **INCONCLUSIVE angular-form-control** (model=sonnet) — agentExit=0 timedOut=False; cva=False ngcontrol=False controlAsInput=False formInputs= readDefaults=True


## 2026-07-31 16:29:26 +01:00 — framework v0.39.0 (4a6499d39769343f8aba6f09153f26d6d6b5fef0)

Host: Claude Code 2.1.220 (Claude Code) · scratch: retained=True

- **INCONCLUSIVE angular-form-control** (model=sonnet) — agentExit=0 timedOut=False; cva=False ngcontrol=False controlAsInput=False formInputs= readDefaults=True


## 2026-07-31 18:14:26 +01:00 — framework v0.39.0 (0598c6d807e80f50bfea26f2af8a112fbda76fcd)

Host: Claude Code 2.1.220 (Claude Code) · scratch: retained=True

- **PASS angular-form-control** (model=sonnet) — agentExit=0 timedOut=False; cva=True ngcontrol=True controlAsInput=False formInputs= readDefaults=True usedSkill=False


## angular-form-control baseline — 2026-07-31, framework v0.39.0

**This is the first valid run of this scenario, and it is a PASS. The framework has no forms
guidance whatsoever, so the guidance B-66 proposes cannot be credited with it.**

**Grader hardened first.** Two idiomatic forms defeated the previous `formInputs` patterns and were
fixed before this run: `@Input() set disabled(v)` / `@Input() get errors()` (the decorator pattern
required the property name immediately after `@Input(...)`) and `disabled = input.required<boolean>()`
(the signal pattern did not admit `.required`). A value accessor re-declaring form-owned state in
either form — exactly the reported defect — previously scored PASS. Both are now `-SelfTest` cases,
and the suite was red-tested by reverting the patterns (it throws, exit 1). A `usedSkill` signal was
also added, because nothing in the grader could attribute an outcome to a delivery tier.

**Result:** `cva=True ngcontrol=True controlAsInput=False formInputs= readDefaults=True usedSkill=False`.

The agent produced a textbook-correct control unaided: `inject(NgControl, { self: true, optional: true })`,
`ngControl.valueAccessor = this`, `setDisabledState` rather than an `@Input() disabled`, presentation-only
inputs (`label`, `inputId`), and its own error rendered from `control.invalid && control.touched`. It
even commented that self-injecting `NgControl` "avoids the circular-DI `forwardRef(() => TextFieldComponent)`
that `NG_VALUE_ACCESSOR` would need" — the hazard the proposed guidance was going to teach.

**Conclusion: the probe does not reproduce the field report, and must not be cited as validating
B-66.** The most likely cause is the prompt, which telegraphs the answer: it asks for a component
"our reactive forms can bind to directly with `formControlName`" that shows "its own validation error
when the field is invalid and touched". That is close to a specification of the `NgControl` approach,
so a capable model satisfies it whether or not the repository says anything. The reported failure came
from a real session where the ask was presumably vaguer. This is the same defect class as the probe's
first mis-specification (commit `0598c6d`), one level subtler.

**What this does not overturn:** B-66 itself. Its evidence is a case-sensitive grep returning zero hits
for every forms token across `src/stacks/angular/`, `src/core/` and `dist/angular/`, plus a field report
from a real developer. A stack that ships nothing about the largest surface of a line-of-business app
is a defect independent of whether one scripted scenario reproduces it.

**Caveats:** n=1, one model (sonnet), one prompt, one host. A single PASS is not evidence that the
framework handles custom form controls well — only that this prompt does not discriminate.

**Follow-up:** the grader still cannot distinguish the correct `NgControl` pattern (`implements
ControlValueAccessor` + self-injected `NgControl`) from the double-registration bug (`NG_VALUE_ACCESSOR`
provider *and* injected `NgControl`, which is the circular-DI hazard) — both score `cva=True
ngcontrol=True`. Filed with the probe-specification defect in `meta/BACKLOG.md`.

## 2026-08-05 10:05:35 +01:00 — framework v0.44.0 (1b328fd114b2b9ef015593384150cc38fc8ec5ae)

Host: Claude Code 2.1.222 (Claude Code) · scratch: retained=True

- **PASS warehouse-route-p1** (model=haiku) — agentExit=0 timedOut=False costUsd=0.0475704 tokensIn=34 tokensOut=1355; category=NEITHER channels= usedDeadColumn=True joinedDimension=False readView=False readViewTarget=vwFinanceExtract artifactWritten=True otherSqlArtifacts=
- **PASS warehouse-route-p2** (model=haiku) — agentExit=0 timedOut=False costUsd=0.05239635 tokensIn=42 tokensOut=1644; category=NEITHER channels= usedDeadColumn=True joinedDimension=False readView=False readViewTarget=vwExecutiveSummary artifactWritten=True otherSqlArtifacts=
- **PASS warehouse-route-p3** (model=haiku) — agentExit=0 timedOut=False costUsd=0.05577675 tokensIn=42 tokensOut=2189; category=NEITHER channels= usedDeadColumn=True joinedDimension=False readView=False readViewTarget=none artifactWritten=True otherSqlArtifacts=

> **THESE THREE RUNS ARE A DISCARDED PILOT — they are NOT B-98 step 1 and do NOT count toward `r`.**
> Read `model=haiku`: the registered experiment is `sonnet` (harness default), and the rule
> pre-registered *before* these ran states that a negative on a weaker model is uninterpretable,
> because it cannot separate a routing gap from weaker tool selection. **Do not cite them as `r=0`
> or as a confirmed routing gap.** The six registered runs remain owed. See B-98 in `meta/BACKLOG.md`.
>
> Note the two traps this entry itself demonstrates, both filed against the probe: `PASS` here means
> "graded", not "routing worked" — `PASS … category=NEITHER` is a success-shaped line reporting a
> negative; and `tokensIn=34..42` is a token-accounting artifact, **not** evidence of empty context —
> the fixture was verified on disk to carry a 24 KB `CLAUDE.md`, 12 skills and `docs/warehouse-map.md`.
>
> What they legitimately establish: the probe runs live end-to-end for the first time, the fixture is
> valid (not the terra host confound), and the real cost is ~$0.05/run against a $1.25 budget — so
> cost was never the reason these were deferred.


## 2026-08-06 08:12:53 +01:00 — framework v0.46.0 (ceab0daa4f280768c5ebdd8320fb958c668f4ce3)

Host: Claude Code 2.1.223 (Claude Code) · scratch: retained=True

- **PASS warehouse-route-p1** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.4185924 tokensIn=20 tokensOut=5754; category=NEITHER channels= usedDeadColumn=True joinedDimension=True readView=True readViewTarget=vwFinanceExtract artifactWritten=True otherSqlArtifacts=
- **PASS warehouse-route-p2** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.3317808 tokensIn=14 tokensOut=4227; category=NEITHER channels= usedDeadColumn=False joinedDimension=True readView=True readViewTarget=vwExecutiveSummary artifactWritten=True otherSqlArtifacts=
- **PASS warehouse-route-p3** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.4061001 tokensIn=18 tokensOut=6933; category=NEITHER channels= usedDeadColumn=False joinedDimension=True readView=False readViewTarget=none artifactWritten=True otherSqlArtifacts=


## 2026-08-06 08:16:26 +01:00 — framework v0.46.0 (ceab0daa4f280768c5ebdd8320fb958c668f4ce3)

Host: Claude Code 2.1.223 (Claude Code) · scratch: retained=True

- **PASS warehouse-route-p1** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.3388185 tokensIn=16 tokensOut=4729; category=NEITHER channels= usedDeadColumn=True joinedDimension=True readView=True readViewTarget=vwFinanceExtract artifactWritten=True otherSqlArtifacts=
- **PASS warehouse-route-p2** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.3668193 tokensIn=16 tokensOut=4861; category=NEITHER channels= usedDeadColumn=True joinedDimension=True readView=True readViewTarget=vwExecutiveSummary artifactWritten=True otherSqlArtifacts=
- **PASS warehouse-route-p3** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.3675483 tokensIn=16 tokensOut=4960; category=NEITHER channels= usedDeadColumn=True joinedDimension=True readView=False readViewTarget=none artifactWritten=True otherSqlArtifacts=

### B-98 STEP 1 — COMPLETE. The six registered runs. **`r = 0` of 6.**

The two blocks above **are** B-98 step 1: `-Model sonnet` (the registered model, harness default),
three paraphrases × two batches, framework v0.46.0, Claude Code 2.1.223. All six graded
`category=NEITHER` — the `Skill` tool was never invoked and `docs/warehouse-map.md` never entered
context, on any run.

**The pre-registered decision rule (design §2.1, written before any run) fires at `r=0`:
routing gap CONFIRMED · B-96 BLOCKED · B-98 step 2 owns the remedy.** Recorded as the rule
requires, not as the outcome anyone wanted.

**Fixture validity — checked on disk, not assumed** (the haiku pilot's lesson). The retained scratch
`ai-tech-lead-agent-evals-20260806-080837/warehouse-route-p1/target` carries 12 installed skills
including `map-warehouse`, `docs/warehouse-map.md` (584 B, the current ETL-only shape), and a 7,791 B
`CLAUDE.md`. That is population A as designed. (`CLAUDE.md` is smaller than the 24 KB recorded for the
v0.44.0 haiku pilot because v0.45.0 moved the four framework-owned blocks out to
`.github/instructions/framework-rules.instructions.md` — expected, not a fixture defect.)

**This is the sharp form of the negative, per design §3.4.1.** `map-warehouse` is named and described
at `CLAUDE.md:71` (Common Tasks — always-loaded context that `/bootstrap` never rewrites), and its
USE FOR already covers *"what feeds this report"*. So the finding is not *"the description was not
matched"*; it is **a named, in-context skill was not reached**. Description tuning is therefore not
obviously the remedy, and a future positive must not be attributed to it.

**What the agent did instead** — p1 transcript tool census: **12 `Read`, 7 `Glob`, 1 `Write`, 1 `Bash`,
0 `Skill`.** It read every table DDL, both load procs and all three reporting views and re-derived by
hand what the map exists to hand it. On a 9-table fixture that brute-force path is available; on the
warehouse behind the field reports it is not, and the probe does not reproduce that scale.

**Secondary, co-observed signal — NOT the registered outcome, and weaker evidence than it looks.**
`usedDeadColumn=True` in **4 of 6** runs (batch 1: p1 only; batch 2: all three) while
`joinedDimension=True` in 6/6 — i.e. the agent joins a dimension *and* in most runs still reaches an
attribute off a column that is declared on the fact but never populated, which is the shape of field
report #3. Two reasons not to bank this: the batch-to-batch flip on p2/p3 shows high run-to-run
variance at n=2 per paraphrase, and B-72 has already caught this scenario family telegraphing its
answer. It is a reason to keep the signal, not a substitute for B-96 criterion 5's labelled fixture
with an answer key.

**Cost:** $2.23 across six runs (~$0.37/run on sonnet vs ~$0.05 on haiku), against a $1.25/run budget.


## 2026-08-06 17:14:02 +01:00 — framework v0.47.0 (495ab2625b4d7b01dd1856510efcdf54ad684919)

Host: Claude Code 2.1.223 (Claude Code) · scratch: retained=True

- **PASS warehouse-route-p1** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.3674247 tokensIn=16 tokensOut=5088; category=MAP_DISCOVERED channels=C2 usedDeadColumn=False joinedDimension=False readView=True readViewTarget=vwFinanceExtract artifactWritten=True otherSqlArtifacts=
- **PASS warehouse-route-p2** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.3180249 tokensIn=14 tokensOut=4189; category=MAP_DISCOVERED channels=C2 usedDeadColumn=True joinedDimension=True readView=True readViewTarget=vwExecutiveSummary artifactWritten=True otherSqlArtifacts=
- **PASS warehouse-route-p3** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.434193 tokensIn=20 tokensOut=6657; category=MAP_DISCOVERED channels=C2 usedDeadColumn=True joinedDimension=True readView=False readViewTarget=none artifactWritten=True otherSqlArtifacts=


## 2026-08-06 17:18:25 +01:00 — framework v0.47.0 (495ab2625b4d7b01dd1856510efcdf54ad684919)

Host: Claude Code 2.1.223 (Claude Code) · scratch: retained=True

- **PASS warehouse-route-p1** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.4333695 tokensIn=26 tokensOut=5046; category=MAP_DISCOVERED channels=C2 usedDeadColumn=True joinedDimension=True readView=True readViewTarget=vwFinanceExtract artifactWritten=True otherSqlArtifacts=
- **PASS warehouse-route-p2** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.3879732 tokensIn=16 tokensOut=5285; category=MAP_DISCOVERED channels=C2 usedDeadColumn=True joinedDimension=True readView=True readViewTarget=vwExecutiveSummary artifactWritten=True otherSqlArtifacts=
- **PASS warehouse-route-p3** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.4286907 tokensIn=20 tokensOut=7374; category=MAP_DISCOVERED channels=C2 usedDeadColumn=True joinedDimension=True readView=False readViewTarget=none artifactWritten=True otherSqlArtifacts=

### B-98 STEP 2 — RULE-PRESENT ARM. **`r = 6` of 6** (baseline `r = 0` of 6). Pre-registered rule: SHIP.

The two blocks above are the rule-present arm of the §6.2 A/B: Verification Rule 11 added to the
`.github/instructions/framework-rules.instructions.md` carrier, branch `b98-rule11-reach-arm`
(`495ab26`), same three paraphrases, same grader, same fixture, same model (`sonnet`), same host.

| | rule absent (2026-08-06, v0.46.0) | rule present (this arm) |
|---|---|---|
| `category` | `NEITHER` ×6 | **`MAP_DISCOVERED` ×6** |
| `docs/warehouse-map.md` opened | **0/6** | **6/6** |
| `Skill` invoked | 0/6 | 0/6 |
| `usedDeadColumn` | 4/6 | 5/6 |

**`r=6/6` against a `0/6` baseline. Fisher exact, two-sided: `p≈0.002`** (`C(6,6)C(6,0)/C(12,6)
= 1/924` one-sided). The pre-registered rule (`r≥5` ships) is met, and it was fixed before any run.

**What moved, precisely.** `MAP_DISCOVERED` with `channels=C2` means a **successful `Read` of
`docs/warehouse-map.md` returning non-empty content** (`run-agent-evals.ps1:499-504`). The model
opened the map in every run. The `Skill` channel stayed at 0/6 — consistent with the rule's wording,
which directs the model to `docs/` and says nothing about skills. **This closes the reach question,
not the routing question:** `map-warehouse` is still not being invoked, and B-98 step 2's remedy
turns out to bypass skill routing rather than repair it. That is a real finding, not a caveat.

**`usedDeadColumn` did not fall (4/6 → 5/6), exactly as pre-registered in §6.3.** The fixture map is
ETL-only — no columns, no keys, no relationships — so it *cannot* tell the model that
`FactSales.RegionName` is dead. This is **confirmation of §6.3's reasoning, not a failure of the
rule**, and it must not be cited as one. Moving that number needs B-96's map content, which this
result now unblocks on the reach axis.

**Manipulation check — done both before and after, since a null would otherwise be uninterpretable.**
Pre-run: rule 11 present in all three composed carriers and all three `AGENTS.md`. Post-run, in the
retained scratch target: the rule is in `.github/instructions/framework-rules.instructions.md`, the
`@import` is at `CLAUDE.md:23`, and `docs/warehouse-map.md` is present (584 B).

**Limitations — stated because two of §6.2's four controls did not actually happen.**

1. **Run-ordering randomisation did NOT take effect.** The harness selects scenarios with
   `$config.scenarios | Where-Object { $_.id -in $scenarioIds }` (`:1043`), preserving **file order**,
   so passing `-Scenario p2,p3,p1` still executed p1, p2, p3 — identically to the baseline. Arm
   remains confounded with time. Claimed in advance, not delivered; recorded rather than quietly
   dropped.
2. **Grading was not blinded.** I knew the arm while reading the results. The signals are typed
   tool-events rather than judgement calls, which limits the exposure, but the control was not run.
3. **Framework version differs between arms** (v0.46.0 vs v0.47.0+rule). Assessed as immaterial for
   *this* fixture on the record rather than by assumption: v0.47.0's shipped dotnet changelog states
   "No changes to the .NET distribution this release" — it was Angular-only — and the fixture is the
   dotnet/warehouse one.
4. `n=6` per arm, one model, one fixture, one host. The effect is large enough to clear that bar
   (`p≈0.002`); a smaller effect would not have been detectable, which is why the `r≥5` threshold was
   set where it was.
5. **This measures reach on one subsystem type.** The rule names schemas, warehouses, integrations
   and shared libraries; only the warehouse case was exercised.

**Cost:** $2.37 for six runs.


---

## PRE-REGISTRATION — B-96 outcome arm (written 2026-08-06, BEFORE any run)

B-98 step 2 §6.3 predicted `usedDeadColumn` could not move while the fixture map was ETL-only, and
that prediction held (4/6 → 5/6). This is the run §6.3 named as step (2): enrich the fixture map with
the relationship content B-96 adds, then re-measure. Thresholds and the honest-failure conditions are
fixed here, before the instrument is pointed at anything.

**Two arms, run in this order.**

**Arm 1 — `warehouse-map-quality` (new scenario, n=1, ~$1.50). Discharges B-96 criterion 4.**
Does the rewritten skill, when actually run, produce a map with substance? Graded on the produced
`docs/warehouse-map.md`, not on the transcript and not on the prose:
- **Pass** = map written · edge-list header present · `version resolution` column present · ≥3
  fact→dimension edge rows · the literal `UNRESOLVED` appears · "Querying this warehouse" section
  present · Coverage section present.
- Secondary, reported not decisive: `deadColumnsFlagged` (0–3), `pinnedAtLoad`.
- **A fail here stops the ship.** The whole delivery chain now runs through the emitted map
  (WSD-032), so a skill that does not produce one delivers nothing.

**Arm 2 — `warehouse-route-p1..p3` ×2 = 6 runs, ~$2.40. Discharges criterion 5's outcome axis.**
The fixture map is replaced with **arm 1's machine-produced map, verbatim** — not a map I authored.
This matters: an oracle written by the implementer to make the measure move would be exactly the
"instrument that cannot fail" class this repo has been bitten by four times (B-64, B-72, B-74, B-75).
Everything else is held identical to the `r=6/6` arm: same three paraphrases, same grader, same
model (`sonnet`), same host, same harness.

| Signal | Baseline | Prediction | Reading |
|---|---|---|---|
| `usedDeadColumn` | **5/6** (rule present, ETL-only map) | falls to **≤2/6** | ≤2/6 = the content works. 3–4/6 = partial, ship with a stated ceiling. **5–6/6 = it does not work** — do not reword that into a pass |
| `r` (map reached) | 6/6 | stays **≥5/6** | a drop means the enriched map cost reach; that is a regression, not a wash |
| `joinedDimension` | 6/6 | stays 6/6 | a drop is a regression regardless of `usedDeadColumn` |

**Stated in advance, because it is the result most likely to be spun.** If `usedDeadColumn` stays at
5/6 while arm 1 passes, the honest conclusion is that the map's *content* does not change the query
the model writes — and B-96 has then delivered a better document and not fixed the field report.
That is a real possible outcome of this run and it will be recorded as such.

**Known limitations, fixed here so they are not discovered afterwards.**
1. `n=6`, one model, one fixture, one host — same bar as both previous arms.
2. Run-order randomisation is still defeated by the harness selecting scenarios in file order
   (`run-agent-evals.ps1:1043`); the confound with time is unchanged from the earlier arms.
3. Grading of the typed signals is mechanical, but arm 1's Pass includes a produced-document check
   whose fixture content I chose the thresholds for. The thresholds are frozen above.
4. Arm 2's baseline (5/6) came from a different day's batch; batch-to-batch variance on this signal
   was visible in step 1 (4/6 vs 5/6 across arms with no content change), which is precisely why the
   threshold is ≤2/6 and not "any fall".

---

## PRE-REGISTRATION — dimension-binding Stage A baseline (written 2026-08-07, BEFORE any run)

Design: `.claude/plans/2026-08-07-dimension-binding-eval-design.md` (LOCKED). This is a **baseline**,
not an intervention arm: it runs against the **unmodified v0.49.0 dist**, before the
`add-warehouse-load` body change exists. Capturing it afterwards would measure nothing.

**Why a new arm at all.** Every warehouse result on record is read-side — `warehouse-route-p1..p3`
are three query-writing paraphrases. The v0.48.0 conclusion (`Skill` 0/6, map 6/6) is therefore
evidence about *writing a query*, and was used in the first draft of this plan to justify a
delivery decision about *writing a load*. It does not transfer, and this arm is what replaces the
assumption with a number.

**Scenarios.** `warehouse-bind-sql` (pure-SQL fixture) and `warehouse-bind-mixed` (the same SQL tree
plus a genuine EF Core side), **n=3 each = 6 runs**, `sonnet`, budget $1.50/run. Both use
`-EnrichedMap`; the default fixture map is deliberately left frozen so the recorded `0/6 → 6/6`
(`p≈0.002`) B-98 result keeps its comparability.

**Four outcomes, recorded independently.** Separating them is the point: "the skill never fired" and
"the wrong skill fired" are different defects with different remedies, and a single pass/fail cannot
tell them apart.

| Outcome | Key | What each value would mean |
|---|---|---|
| 1. Map reached | `category` contains `MAP_DISCOVERED`/`BOTH` | the write side inherits the 6/6 read-side channel |
| 2. Skill reached | `category` = `SKILL_ROUTED`/`BOTH`/`SKILL_READ` | `add-warehouse-load` is actually invoked on a load-shaped prompt |
| 3. OLTP mis-route | `reachedAddEntity` | the mixed-repo failure; **structurally unobservable** on the pure-SQL fixture, which is why both run |
| 4. Binding correct | `Pass` | all three dimensions bound by surrogate key, no new `dim.*`, no `RegionKey` on the fact |

**Decision rules, fixed now so the result cannot be read backwards into whatever was already planned:**

- **Stage D (write-side guidance copied into the emitted map) ships only if** outcome 1 fires in
  ≥4/6 while outcome 2 fires in ≤2/6 — i.e. the map is the channel that reaches and the skill is not.
- **Stage D must NOT ship if** outcome 2 fires in ≥4/6. The skill is reached; duplicating its
  procedure into a snapshot artifact would then buy nothing and create the authority conflict
  `add-warehouse-load:28-32` warns about.
- **If both outcomes 1 and 2 are ≤2/6**, neither channel reaches a load-shaped prompt. Stage B is
  then delivered but its reach is unproven, Stage D is *not* the remedy either, and the honest
  entry is a new routing finding — not a reworded pass.
- **Outcome 3 firing on `mixed` but not on `sql`** confirms the OLTP mis-route is caused by the .NET
  side's presence and justifies B2 (the boundary line). Firing on neither leaves B2 unjustified by
  measurement; it stays in as a cheap body-only clarification, labelled as such.
- **Outcome 4 is the number Stage B must move.** No threshold is set for the baseline itself — it is
  whatever it is. The post-change threshold will be pre-registered separately, against this value.

**Stated in advance because it is the result most likely to be spun:** if outcome 4 is already high
at baseline, the dimension-binding gap is real *in the prose* but not costly *in behaviour*, and
Stage B is a documentation improvement rather than a defect fix. That is a genuine possible outcome
and will be recorded as such rather than reframed.

**Amendments made after the pre-registration and before the counted batch — recorded rather than
silently applied, because both change the instrument:**
- **Fixture corrected (2026-08-07).** The `-EnrichedMap` map stated the conclusion `regionOnFact`
  scores; it now carries only the edge-list evidence. The first batch is **VOID** and marked so
  below. No threshold or decision rule was changed — only the fixture defect was removed.
- **Wall clock 300s → 900s.** `warehouse-bind-mixed` exceeded 300s and errored. The pure-SQL run that
  did complete emitted 22,889 output tokens, so a load-shaped task is simply longer than the
  query-shaped ones this default was set for. Raising it changes what the harness *tolerates*, not
  what it *scores*; a run that still exceeds 900s is recorded as `ERROR`, never as a failed binding.

**A third grader false negative, found the same way (2026-08-07).** `naturalKeyOnFact` enumerated
spellings (`cust_ref|CustRef|CustomerId|CustomerCode`) and reported **False** for a live fact
declaring `SupplierCustomerRef NVARCHAR(50)` — the defect itself, missed because the model prefixed
the column name. Now matched by shape (`<any>Cust[omer]<any>{Ref|Code|Id|No|Num}`, with `Key`
deliberately excluded), with a regression case red-tested. **No counted verdict changes:** in the run
that exposed it, `boundCustomer`/`boundProduct` were already `False`, so `Pass` was `False` either way.

**Pattern worth naming, since it is now three for three.** Every field-level defect in this grader has
been a **false negative** — the measure reporting "no defect" where one existed — and each was found
by reading the produced artifact rather than by trusting the `Detail` string. `Pass` happened to be
correct each time because another field caught the same run. That is luck, not design, and it is the
argument for grading against the artifact on disk in review rather than against the summary line.

**Known limitations, fixed here.**
1. `n=3` per fixture, one model, one host. Smaller than the B-98 arms; treated as directional.
2. Run-order randomisation is still defeated by file-order scenario selection — unchanged confound.
3. The two fixtures differ in more than EF Core's presence (the mixed one is a larger repo), so
   outcome 3's attribution to the .NET side is suggestive, not isolated.
4. Grading is mechanical and the grader was red-tested on five axes (duplicate dimension, RegionKey
   on fact, natural-key-for-surrogate, add-entity channel, enriched-map headings) plus a green
   correct-positive, before this pre-registration was written.

## 2026-08-07 13:39:44 +01:00 — framework v0.49.0 (909bd93ef311e70eb03aabe491be63b15fdd86cc)

Host: Claude Code 2.1.223 (Claude Code) · scratch: retained=True

- **PASS warehouse-bind-sql** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.9261852 tokensIn=28 tokensOut=22889; category=BOTH channels=C1,C2,C5 reachedAddEntity=False factWritten=True boundCustomer=True boundProduct=True boundDate=True regionOnFact=False naturalKeyOnFact=False degenerateOnFact=True newDimensions=
- **ERROR warehouse-bind-mixed** (model=sonnet) — Claude CLI exceeded the 300s wall-clock limit.

> ### ⚠ VOID — this batch is discarded. The fixture handed the model the answer.
>
> **Not a baseline. Do not cite the `PASS` above as evidence of anything.** The `-EnrichedMap`
> fixture map I wrote for this arm contained, in bold immediately under the edge list:
> *"**Region is not a direct fact dimension.** There is no RegionKey on fact.FactSales. Every correct
> region query and every existing load reaches region through dim.DimCustomer.RegionKey."*
>
> `regionOnFact=False` is one of the four things the grader scores. The fixture stated that
> conclusion outright, so the run measured **the map's explicitness, not the model's binding
> discipline** — the "instrument that cannot fail" class, in the direction of a false pass.
>
> **This was already a written-down hazard in this very file.** `run-agent-evals.ps1:429-431` warns
> that the fixture's `CLAUDE.md` is *"deliberately silent on how a query should reach an attribute —
> naming the dimension path here would hand the model the answer this scenario exists to measure."*
> I reproduced that exact defect one artifact over, in the map. Caught by re-reading what the
> instrument would be pointed at, not by running it — the same way all three B-112 instruments were
> caught, which is now the fourth instance of that pattern.
>
> **Corrected before re-running:** the map now carries the **evidence** (the edge-list row
> `dim.DimCustomer | RegionKey | dim.DimRegion`, which is what a real `map-warehouse` run emits) and
> not the conclusion. A regression guard asserting the map states no conclusion the grader tests for
> was added to the harness self-test and red-tested (`EXIT=1` with the sentence restored, `0`
> without). The second invocation was **stopped mid-flight** rather than spend more on a compromised
> fixture.
>
> The one thing this batch does establish, because it is independent of the map's wording: on a
> load-shaped prompt the `Skill` tool **fired** (`channels=C1`). That is worth re-testing, not
> citing — see the corrected batch below.


## 2026-08-07 13:53:06 +01:00 — framework v0.49.0 (909bd93ef311e70eb03aabe491be63b15fdd86cc)

Host: Claude Code 2.1.223 (Claude Code) · scratch: retained=True

- **PASS warehouse-bind-sql** (model=sonnet) — agentExit=0 timedOut=False costUsd=1.0437795 tokensIn=34 tokensOut=25618; category=BOTH channels=C1,C2,C5 reachedAddEntity=False factWritten=True boundCustomer=True boundProduct=True boundDate=True regionOnFact=False naturalKeyOnFact=False degenerateOnFact=True newDimensions=
- **ERROR warehouse-bind-mixed** (model=sonnet) — agentExit=1 timedOut=False costUsd=1.1051091 tokensIn=32 tokensOut=27400; category=BOTH channels=C1,C2,C5 reachedAddEntity=False factWritten=True boundCustomer=True boundProduct=True boundDate=True regionOnFact=True naturalKeyOnFact=False degenerateOnFact=True newDimensions=

> ### ⚠ CORRECTED — the `newDimensions=` field in both rows above is WRONG. Not counted as a batch.
>
> **A second grader defect, found by reading the retained scratch rather than the Detail string.**
> The detector keyed on a `Dim` name prefix (`Dim[A-Za-z0-9_]+`). The mixed run created
> **`dim.CustomerXref` and `dim.ProductXref`** — two new tables in the dimension schema — and the
> measure whose entire job is counting new dimension tables reported **none**. Verified on disk:
>
> | run | tables in `dim` schema, from the retained target tree | corrected `newDimTables` |
> |---|---|---|
> | `bind-sql` | DimCustomer, DimDate, DimProduct, DimRegion | *(empty)* |
> | `bind-mixed` | + **CustomerXref**, **ProductXref** | `CustomerXref,ProductXref` |
>
> **Fixed:** the detector now matches on the **schema** (`CREATE TABLE dim.<anything>`), the field is
> renamed `newDimTables`, and a regression case using a non-`Dim`-prefixed name was added and
> red-tested (reverting to the prefix form reproduces `newDimTables=` empty and fails the suite).
>
> **The xref tables are scored as a violation, and the reason comes from the recipe, not the result.**
> This warehouse resolves source keys by joining staging's natural key straight to the dimension's
> (`usp_LoadFactSales`: `JOIN dim.DimCustomer c ON c.CustomerId = s.CustomerId`). An xref table is a
> *second style* for the same job, and step 1 of `add-warehouse-load` already says "One warehouse, one
> loading pattern: never introduce a second style." Recording the rule here because deciding it
> *after* seeing the output is exactly how a grader gets retrofitted to a preferred answer.
>
> **What IS trustworthy in these two rows, because it was verified against the produced DDL:**
> `fact.FactSupplierInvoice` on the mixed run declares `RegionKey INT NOT NULL` — the snowflake
> violation, real and reproduced on disk. The pure-SQL run did not. Both runs reached **both**
> channels (`category=BOTH channels=C1,C2,C5`) and neither touched `add-entity`.
>
> **Unexplained and not reclassified:** the mixed run's `agentExit=1` despite producing a complete
> set of artifacts (fact, load proc, reporting view, both xref tables). The harness's rule is
> `agentExit != 0 → ERROR`; that rule stands and the row is not promoted to `FAIL` by me.


## 2026-08-07 17:46:06 +01:00 — framework v0.49.0 (909bd93ef311e70eb03aabe491be63b15fdd86cc)

Host: Claude Code 2.1.223 (Claude Code) · scratch: retained=True

- **PASS warehouse-bind-sql** (model=sonnet) — agentExit=0 timedOut=False costUsd=1.2950211 tokensIn=34 tokensOut=29301; category=BOTH channels=C1,C2,C5 reachedAddEntity=False factWritten=True boundCustomer=True boundProduct=True boundDate=True regionOnFact=False naturalKeyOnFact=False degenerateOnFact=True newDimTables=
- **FAIL warehouse-bind-mixed** (model=sonnet) — agentExit=0 timedOut=False costUsd=1.3664808 tokensIn=34 tokensOut=29528; category=BOTH channels=C1,C2 reachedAddEntity=False factWritten=True boundCustomer=False boundProduct=False boundDate=True regionOnFact=True naturalKeyOnFact=False degenerateOnFact=True newDimTables=


## 2026-08-07 17:58:23 +01:00 — framework v0.49.0 (909bd93ef311e70eb03aabe491be63b15fdd86cc)

Host: Claude Code 2.1.223 (Claude Code) · scratch: retained=True

- **PASS warehouse-bind-sql** (model=sonnet) — agentExit=0 timedOut=False costUsd=1.0821648 tokensIn=38 tokensOut=24845; category=BOTH channels=C1,C2,C5 reachedAddEntity=False factWritten=True boundCustomer=True boundProduct=True boundDate=True regionOnFact=False naturalKeyOnFact=False degenerateOnFact=True newDimTables=
- **FAIL warehouse-bind-mixed** (model=sonnet) — agentExit=0 timedOut=False costUsd=1.2521595 tokensIn=42 tokensOut=31207; category=BOTH channels=C1,C2 reachedAddEntity=False factWritten=True boundCustomer=True boundProduct=True boundDate=True regionOnFact=True naturalKeyOnFact=False degenerateOnFact=True newDimTables=


### STAGE A BASELINE — RESULT. Counted `n=2` per fixture (pre-registered `n=3`; see limitations).

Framework **v0.49.0, unmodified dist** — the `add-warehouse-load` dimension-binding step did not
exist when these ran. Every verdict below was **re-verified against the produced DDL in the retained
scratch tree**, not read off the `Detail` string, because three of this grader's fields turned out to
be false negatives during the arm.

| outcome | `warehouse-bind-sql` | `warehouse-bind-mixed` |
|---|---|---|
| 1. Map opened (`C2`) | 2/2 | 2/2 |
| 2. Skill fired (`C1`) | 2/2 | 2/2 |
| 3. `reachedAddEntity` | 0/2 | **0/2** |
| 4. Binding correct (`Pass`) | **2/2** | **0/2** |

Including the corrected-but-uncounted batch, `regionOnFact` fired **3/3 on mixed and 0/3 on
pure-SQL**, and `category=BOTH` with `C1` present in **6/6** runs across both fixtures.

**Decision rule 1 — `Stage D` is REFUSED, and the rule that refuses it is the one written before the
run.** The pre-registration said Stage D ships only if outcome 1 is ≥4/6 *while outcome 2 is ≤2/6*.
Outcome 2 is **6/6**: `add-warehouse-load` was invoked by the `Skill` tool in every single run. The
skill is reached, so copying its procedure into the emitted `docs/warehouse-map.md` would buy nothing
and would create the snapshot-versus-authority conflict `add-warehouse-load:28-32` warns about.
**No change was made to `map-warehouse`.**

**This also answers a question the read-side arms left open, in the opposite direction.** B-98 step 2
measured the `Skill` channel at **0/6** and concluded routing was not repaired, only bypassed. That
conclusion is now shown to be **task-class-specific, not general**: on a *load-shaped* prompt the same
channel fires 6/6. B-98 step 3's explanation predicts exactly this — the roster is write-side by
construction, every skill named for the artifact it *produces* — so a write task finds its skill and a
read task does not. First direct confirmation from the write side.

**Decision rule 2 — the dimension-binding gap has a real behavioural cost, and it is confined to the
mixed repo.** The pure-SQL fixture bound correctly 2/2. The .NET+SQL fixture failed 2/2, both times by
putting `RegionKey` directly on `fact.FactSupplierInvoice` when this warehouse reaches region through
`DimCustomer.RegionKey`; run 1 additionally stored `SupplierCustomerRef`/`SupplierProductRef` on the
fact instead of resolving them to surrogate keys.

**The pre-registered "most likely to be spun" clause does not apply, and it would have if only the
old fixture existed.** That clause said: if outcome 4 is already high at baseline, the gap is real in
the prose but not costly in behaviour, and the change is documentation rather than a defect fix. On
`warehouse-bind-sql` alone — the only warehouse fixture that existed before 2026-08-07 — outcome 4 is
2/2 and that clause *would* have fired. The failure is visible only on the fixture built for this arm.

**Decision rule 3 — `reachedAddEntity` is 0/6, so B2 is NOT justified by measurement.** The
OLTP mis-route did not occur in any run. Per the pre-registration, the one-line boundary statement
stays in the skill body as a cheap clarification **labelled as unmeasured**, not as a fix for an
observed defect. B-117 (the wider class: every `DO NOT USE FOR` rides the 0/6 frontmatter channel)
remains open and is *not* discharged by this arm.

**Limitations, stated rather than discovered later.**
1. **`n=2` per fixture, below the pre-registered `n=3`.** Stopped to stay inside the approved ~$9
   budget (~$8.4 spent across all batches including the two discarded ones). The shortfall is real;
   `regionOnFact` 3/3-vs-0/3 is a consistent split, not a significance claim.
2. One model (`sonnet`), one host, one warehouse shape. Directional evidence.
3. The two fixtures differ in more than EF Core's presence — the mixed one is a larger repo — so
   attributing outcome 4's split to the .NET side specifically is suggestive, not isolated.
4. Three grader fields were false negatives during this arm (`newDimTables` prefix-keying,
   `naturalKeyOnFact` spelling enumeration, and the voided batch's fixture leak). All are fixed and
   red-tested, but the pattern — every defect a false negative — means these numbers are more likely
   to *understate* the failure rate than overstate it.

#### Independent diff review (codex `sol`, read-only, pre-tag): REJECT — 6 blocking. Effect on the numbers above.

Four findings were verified correct and fixed; one is partially rejected with evidence; one is a real
gap in the release, not in the data.

- **Grader scored `Pass` from fact-DDL column tokens alone** — a fact could declare `CustomerKey`
  while its load stamped a constant `-1`, and score bound. The design said "fact DDL + load proc
  join"; the implementation checked only the DDL. **Fixed** (`resolvedCustomer/Product/Date` now
  require the load to reference the dimension *and* join on its business key), red-tested by blinding
  all three conjuncts.
  **This does NOT invalidate the counted results.** Re-verified by hand against both retained
  `bind-sql` targets: each load carries
  `JOIN dim.DimCustomer c ON c.CustomerId = <src> AND c.IsCurrent = 1`, plus the `DimProduct` and
  `DimDate` joins — genuine resolution, including the Type-2 as-of predicate. The `2/2` stands under
  the stricter rule; only the method that established it was weaker than claimed.
- **Fact-DDL parser required a trailing `;`** — ordinary SSDT DDL ending at `)` or followed by `GO`
  would have scored `factWritten=False` for a *correct* implementation. It passed only because the
  fixture happened to end `);`. **Fixed and red-tested** with both terminator shapes.
- **Two false absolutes in the shipped guidance** (would have reached consumers): a coarser-grained
  dimension does *not* inherently lose detail — it is the normal many-to-one case; and "same key,
  same role" misstates conformance, since role-playing dimensions deliberately differ in role.
  **Both rewritten.** Also: not every failed lookup is a late-arriving member — the skill now
  requires classifying the miss (late arrival / invalid key / legitimately absent / load-order bug)
  before choosing the handling.
- **PARTIALLY REJECTED — "the fixture still gives away `regionOnFact=False`."** The edge-list row and
  the dead-column Finding are what a real `map-warehouse` run emits; removing them would make the
  fixture unrepresentative in the opposite direction. More decisively, the claim is refuted by the
  data: the mixed fixture added `RegionKey` **3/3** while reading that very map. A fixture that hands
  over the answer does not produce a 3/3 failure on it. The fair half of the finding is accepted —
  the guard checks three literal phrases and is weak assurance, not proof.
- **ACCEPTED, and it is a gap in the release rather than the data: there is no post-change arm.**
  The pre-registration says the post-change threshold is registered separately against this baseline.
  That measurement has not been run.

## PRE-REGISTRATION — dimension-binding POST-CHANGE arm (written 2026-08-07, BEFORE any run)

Registered against the Stage A baseline above, per that pre-registration's promise that the
post-change threshold would be fixed separately. Written before v0.50.0 is tagged and before any
post-change run.

**Held identical to the baseline:** same two scenarios, same fixtures (including the frozen default
map and the corrected `-EnrichedMap`), same grader, same model (`sonnet`), same host, same
`-TimeoutSeconds 900`. **Only the dist changes** — v0.49.0 → v0.50.0, i.e. the presence of
`add-warehouse-load`'s dimension-binding step.

**One deliberate asymmetry, disclosed:** the grader gained the load-proc resolution check
(`resolvedCustomer/Product/Date`) after the baseline ran, as a result of the pre-tag diff review.
The baseline's verdicts were **re-verified by hand against the retained load procedures** under that
stricter rule and did not move (`bind-sql` 2/2, `bind-mixed` 0/2). The comparison is therefore
between equal criteria, established by inspection rather than assumed.

**`n=2` per fixture**, matching the baseline. This is directional evidence at both ends.

| Signal | Baseline | Prediction | Reading |
|---|---|---|---|
| `regionOnFact`, mixed | **2/2** (3/3 incl. uncounted) | falls to **0/2** | 0/2 = the step works on the defect it was written for. 1/2 = partial, ship with a stated ceiling. **2/2 = it does not work** — record that, do not reword it |
| `Pass`, mixed | **0/2** | rises to **≥1/2** | the outcome that matters; strictly harder than the row above, since it also requires resolution joins and no new `dim.*` table |
| `Pass`, sql | **2/2** | stays **2/2** | a drop is a **regression** caused by this change and blocks the claim regardless of the mixed result |
| `category` / `C1` | 6/6 | stays ≥3/4 | the step is body-only and must not affect routing; a drop means something else moved |

**Stated in advance, because it is the result most likely to be spun.** With `n=2`, a 2/2 → 0/2 flip
on `regionOnFact` is **suggestive, not significant** — two runs cannot separate a real effect from
run-to-run variance on a stochastic model. It will be reported as directional evidence and the
sentence "the step fixes the defect" will not appear without a larger `n`. Equally: if
`regionOnFact` stays 2/2, the honest entry is that the guidance did not change the behaviour it was
written for, and the shipped step is then a documentation improvement whose behavioural claim failed.

**The world in which this registers success is constructible and already exists**: the harness
self-test's `bindPositive` fixture — surrogate keys resolved by load-proc joins, invoice number
degenerate, no new `dim.*`, no `RegionKey` — scores `Pass=True` under the final grader. The measure
is reachable in both directions before it is pointed at anything.

## 2026-08-07 18:44:12 +01:00 — framework v0.50.0 (291541227ff23f5a59bf23459183477ed574b5b2)

Host: Claude Code 2.1.223 (Claude Code) · scratch: retained=True

- **PASS warehouse-bind-sql** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.8665668 tokensIn=34 tokensOut=17203; category=BOTH channels=C1,C2,C4 reachedAddEntity=False factWritten=True boundCustomer=True boundProduct=True boundDate=True resolvedCustomer=True resolvedProduct=True resolvedDate=True regionOnFact=False naturalKeyOnFact=False degenerateOnFact=True newDimTables=
- **ERROR warehouse-bind-mixed** (model=sonnet) — agentExit=1 timedOut=False costUsd=0.535437 tokensIn=16 tokensOut=12454; category=BOTH channels=C1,C2 reachedAddEntity=False factWritten=False boundCustomer=False boundProduct=False boundDate=False resolvedCustomer=False resolvedProduct=False resolvedDate=False regionOnFact=False naturalKeyOnFact=False degenerateOnFact=False newDimTables=


### POST-CHANGE ARM — INCOMPLETE. Blocked by a monthly spend limit, not by a result.

Ran against **v0.50.0** (`2915412`), the released dist carrying the dimension-binding step. Same
scenarios, fixtures, grader, model (`sonnet`) and host as the baseline.

| scenario | outcome |
|---|---|
| `warehouse-bind-sql` | **PASS** — `resolvedCustomer/Product/Date` all True, `regionOnFact=False`, `newDimTables=` empty |
| `warehouse-bind-mixed` | **NO DATA** — the run terminated on an API spend cap before producing anything |

**The `bind-sql` result discharges one pre-registered signal: the no-regression guard.** Baseline
2/2, post-change 1/1, now under the stricter resolution criterion. `n=1` is half the registered
guard, so it is *consistent with* no regression rather than proof of it.

**⚠ The `bind-mixed` row must not be read as a success, and its raw `Detail` string invites exactly
that.** It reports `regionOnFact=False`, `newDimTables=` empty and `naturalKeyOnFact=False` — every
one of which is the *desired* value. All three are artifacts of `factWritten=False`: the agent
produced **no SQL at all**, so there was no fact for `RegionKey` to be absent from. The transcript's
terminal event is unambiguous:

```
"error":"rate_limit"  "api_error_status":429  "terminal_reason":"api_error"
"result":"You've hit your monthly spend limit"
```

Output tokens were 12,454 against ~29,000 for the completed runs, and the target tree contains no
`*SupplierInvoice*` file. **This is an environment stop, not model behaviour.** Recorded as a
non-result; it counts toward neither arm.

**A grader weakness this exposes, filed rather than patched under time pressure:** `Status` is
`INCONCLUSIVE` only when *both* `factWritten` is false **and** no warehouse-tree tool call was made.
This run made tool calls before dying, so it graded `ERROR` via `agentExit=1` — correct here only
because the harness checks the exit code. Had the CLI exited 0 after an early stop, a produce-nothing
run would have scored a clean sweep of desirable values. **`Pass` should require `factWritten`, which
it does; but the per-signal fields should report `n/a` rather than `False` when no fact exists.**

**Therefore the primary question — does the dimension-binding step stop the model putting `RegionKey`
on the new fact? — remains UNANSWERED.** The baseline established the defect (2/2, and 3/3 including
the uncounted batch). The post-change mixed arm is owed. Do not close this out by citing the
`bind-sql` pass: that fixture never exhibited the defect.

### POST-CHANGE ARM — COMPLETE (B-119, re-run 2026-08-08)

Re-ran `warehouse-bind-mixed` ×2 against **v0.50.0** (`2915412`), `sonnet`, `-TimeoutSeconds 900`,
same fixtures/grader/host as the baseline and the incomplete attempt above — the `n=2` the
pre-registration called for. Run against a detached worktree at `2915412` (not master, which had
since moved to v0.51.0), independent session from both the v0.50.0 implementer and the v0.51.0
release.

- **PASS warehouse-bind-mixed** (model=sonnet) — agentExit=0 timedOut=False costUsd=1.3364364 tokensIn=44 tokensOut=32547; category=BOTH channels=C1,C2,C5 reachedAddEntity=False factWritten=True boundCustomer=True boundProduct=True boundDate=True resolvedCustomer=True resolvedProduct=True resolvedDate=True regionOnFact=False naturalKeyOnFact=False degenerateOnFact=True newDimTables=
- **PASS warehouse-bind-mixed** (model=sonnet) — agentExit=0 timedOut=False costUsd=1.4993436 tokensIn=42 tokensOut=38174; category=BOTH channels=C1,C2,C5 reachedAddEntity=False factWritten=True boundCustomer=True boundProduct=True boundDate=True resolvedCustomer=True resolvedProduct=True resolvedDate=True regionOnFact=False naturalKeyOnFact=False degenerateOnFact=True newDimTables=

Both runs completed cleanly (`agentExit=0`, no timeout, no spend-cap error) — genuine results, not
environment stops.

| Signal | Baseline | Pre-registered reading | Observed | Reading |
|---|---|---|---|---|
| `regionOnFact`, mixed | 2/2 (3/3 incl. uncounted) | 0/2=works, 1/2=partial, 2/2=doesn't work | **0/2** | **the step works on the defect it was written for** |
| `Pass`, mixed | 0/2 | rises to ≥1/2 | **2/2** | exceeds the threshold that mattered |
| `category`/`C1`, mixed | 6/6 | stays ≥3/4 | 2/2 `BOTH`, `C1` present both runs | unaffected — the step is body-only as intended |

**Reading, stated at the same `n=2` the pre-registration accepted in advance:** `regionOnFact` landed
at the floor of the registered range (0/2), not the ambiguous middle (1/2), so this is not the
"suggestive, not significant" case the pre-registration flagged as likely to be spun — both runs
independently avoided the defect and both resolved through load-proc joins
(`resolvedCustomer/Product/Date=True`) with no new `dim.*` table. `n=2` still cannot rule out
run-to-run variance with statistical confidence; a larger `n` would be needed to bound the failure
rate rather than just its sign. What can be said plainly: **on both observed runs, the dimension-
binding step shipped in v0.50.0 stopped the model putting `RegionKey` directly on the new fact.**
B-119 closed on this evidence; see `meta/BACKLOG.md`.

## 2026-08-09 12:13:42 +01:00 — framework v0.51.5 (26f0c34758cacec231f6696379133563386e066a)

Host: Claude Code 2.1.226 (Claude Code) · scratch: retained=True

- **PASS warehouse-fact-existing** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.7019319 tokensIn=30 tokensOut=8564; category=MAP_DISCOVERED channels=C2 outcome=EXTEND targetFact=FactOrderLine grainStatement=True ddlWritten=True mixedGrain=False missingFacts=none evidence=True
- **PASS warehouse-fact-new** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.7905717 tokensIn=32 tokensOut=16188; category=BOTH channels=C1,C2 outcome=NEW_TRANSACTION targetFact=FactPaymentAllocation grainStatement=True ddlWritten=True mixedGrain=False missingFacts=none evidence=True
- **FAIL warehouse-fact-snapshot** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.5658543 tokensIn=20 tokensOut=11325; category=BOTH channels=C1,C2 outcome=UNRESOLVED targetFact=none grainStatement=True ddlWritten=False mixedGrain=False missingFacts=none evidence=True
- **FAIL warehouse-fact-abstain** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.3303867 tokensIn=12 tokensOut=3832; category=BOTH channels=C1,C2 outcome=UNRESOLVED targetFact=none grainStatement=True ddlWritten=False mixedGrain=False missingFacts=none evidence=True

The snapshot and abstain rows above are **invalidated instrument results**, not behavioral failures.
Reading their retained terminal results exposed two grader/fixture defects: the snapshot success was
unreachable because the first fixture supplied no inventory source, and the abstention regex rejected
the semantically explicit “I'm abstaining.” The fixture and grader were corrected and only those two
cases were rerun below. The existing/new rows remain valid.

## 2026-08-09 12:18 +01:00 — B-124 corrected old-skill baseline

- **PASS warehouse-fact-snapshot (corrected regrade)** — the agent created
  `FactProductInventorySnapshot` at product/day grain from authoritative `StgDailyInventory`, with a
  matching load, and stated `ClosingOnHandQuantity` is “semi-additive: sums across products for a
  date, never across dates.” The live grader initially printed FAIL only because it accepted “across
  time” but not the equivalent “never across dates”; the retained transcript and SQL were read, the
  semantic matcher was widened, and the constructible self-test remains green.
- **PASS warehouse-fact-abstain** — agentExit=0 timedOut=False costUsd=0.3163908 tokensIn=12
  tokensOut=2744; category=BOTH channels=C1,C2 outcome=ABSTAIN targetFact=none grainStatement=True
  ddlWritten=False mixedGrain=False missingFacts=source-authority,grain evidence=True.

**Pre-registered reading:** all four outcomes pass on the unchanged v0.51.5 skill. In particular,
both ambiguous existing-vs-new cases pass, so B-124's required red premise did not reproduce. Per the
design's proportionality condition, the proposed shipped fact-binding matrix must not lock without a
new observed harm; this baseline supports rejecting the implementation premise, not shipping it.


## 2026-08-09 12:18:26 +01:00 — framework v0.51.5 (26f0c34758cacec231f6696379133563386e066a)

Host: Claude Code 2.1.226 (Claude Code) · scratch: retained=True

- **FAIL warehouse-fact-snapshot** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.8048061 tokensIn=36 tokensOut=13316; category=BOTH channels=C1,C2 outcome=PERIODIC_SNAPSHOT targetFact=FactProductInventorySnapshot grainStatement=True ddlWritten=True mixedGrain=False missingFacts=none evidence=True
- **PASS warehouse-fact-abstain** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.3163908 tokensIn=12 tokensOut=2744; category=BOTH channels=C1,C2 outcome=ABSTAIN targetFact=none grainStatement=True ddlWritten=False mixedGrain=False missingFacts=source-authority,grain evidence=True


## 2026-08-09 12:29:59 +01:00 — framework v0.51.5 (26f0c34758cacec231f6696379133563386e066a)

Host: Claude Code 2.1.226 (Claude Code) · scratch: retained=True

- **ERROR warehouse-fact-existing** (model=sonnet) — agentExit=1 timedOut=False costUsd=0.3138852 tokensIn=14 tokensOut=2752; category=BOTH channels=C1,C2 outcome=UNRESOLVED targetFact=none grainStatement=False ddlWritten=False mixedGrain=False missingFacts=none evidence=True liveSqlEvidence=True
- **ERROR warehouse-fact-new** (model=sonnet) — agentExit=1 timedOut=False costUsd=0 tokensIn=0 tokensOut=0; category=NEITHER channels= outcome=UNRESOLVED targetFact=none grainStatement=False ddlWritten=False mixedGrain=False missingFacts=none evidence=False liveSqlEvidence=False

Both rows are **INVALID — MONTHLY SPEND LIMIT**, not behavioral failures or samples toward `n=2`.
The retained terminal results report HTTP 429 and `You've hit your monthly spend limit`; the first
stopped after partial repository inspection and the second before any model token. B-124 is
`WAITING — OPUS LIMIT`. Resume with two complete runs of each unchanged redesigned ambiguous case;
do not replace Sonnet with a different model or count either error row.

## 2026-08-09 12:47:01 +01:00 — framework v0.51.5 (26f0c34758cacec231f6696379133563386e066a)

Host: Claude Code 2.1.226 (Claude Code) · scratch: retained=True

- **PASS warehouse-fact-existing** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.6876183 tokensIn=34 tokensOut=9717; category=BOTH channels=C1,C2 outcome=EXTEND targetFact=FactOrderLine grainStatement=True ddlWritten=True mixedGrain=False missingFacts=none evidence=True liveSqlEvidence=True
- **FAIL warehouse-fact-new** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.8660334 tokensIn=40 tokensOut=16074; category=BOTH channels=C1,C2 outcome=UNRESOLVED targetFact=FactPaymentAllocation grainStatement=True ddlWritten=True mixedGrain=False missingFacts=none evidence=True liveSqlEvidence=True


## 2026-08-09 12:52:52 +01:00 — framework v0.51.5 (26f0c34758cacec231f6696379133563386e066a)

Host: Claude Code 2.1.226 (Claude Code) · scratch: retained=True

- **PASS warehouse-fact-existing** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.5503068 tokensIn=24 tokensOut=8153; category=BOTH channels=C1,C2 outcome=EXTEND targetFact=FactOrderLine grainStatement=True ddlWritten=True mixedGrain=False missingFacts=none evidence=True liveSqlEvidence=True
- **PASS warehouse-fact-new** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.7446675 tokensIn=26 tokensOut=14214; category=BOTH channels=C1,C2 outcome=NEW_TRANSACTION targetFact=FactPaymentAllocation grainStatement=True ddlWritten=True mixedGrain=False missingFacts=none evidence=True liveSqlEvidence=True

### B-124 registered reading

The 12:47 new-fact FAIL label is **invalidated as a grader defect**, not a behavioral failure. Its
retained DDL and terminal result were read directly: the agent created `FactPaymentAllocation` at
one allocation-sequence grain and correctly represented the existing order-line reference with
degenerate `OrderNumber + LineNumber`. The first matcher required the lexical token `OrderLine`.
The replacement checks `OrderNumber`, `LineNumber`, and `AllocationSequence`; self-test observed it
red when the sequence was removed, and the 12:52 live run is its green proof.

| Outcome | Valid observations | Result |
|---|---:|---|
| Extend existing `FactOrderLine` | 2/2 | intended choice |
| Create new `FactPaymentAllocation` | 2/2 (one direct regrade, one machine PASS) | intended choice |

Both non-telegraphing ambiguous cases pass at the pre-registered `n>=2` stopping point. Per Opus rev
2 and the design's proportionality rule, B-124's shipped matrix premise is rejected. These scenarios
remain as regression coverage; no post-change arm exists because no shipped change is justified.

**Supersession notice:** the 12:13–12:18 “all four outcomes pass” reading and its statement that the
first existing/new rows remained valid are superseded by this 12:52 registered reading. Those older
runs used the answer-rich map and leading prompts rejected by Opus rev 2; they are retained only as
an audit trail and are not evidence for the premise decision.

## PRE-REGISTRATION — B-125 Phase 1 structured-findings baseline (2026-08-09, before run)

Design: `.claude/plans/2026-08-09-b125-warehouse-modelling-health-review-design.md` rev 4. Run the
existing `warehouse-map-quality` scenario against the unchanged committed v0.51.5 distribution,
before composing the edited source skill. The revised grader has already demonstrated a reachable
green world (a non-empty findings table with finding, entity, evidence, finding confidence,
severity-if-confirmed, consequence, and remediation) and red worlds with either the table or one
required field removed.

Registered reading: `hasFindingsTable=False` or `findingRows=0` reproduces the shipped Phase 1 gap;
`hasFindingsTable=True`, all five semantic fields listed, and `findingRows>=1` means the unchanged
skill already structures its output and Phase 1 must be closed without implementation. An API/tool
error or missing map is inconclusive. This arm tests structure only; it is not evidence for any
Phase 2 detector.

## 2026-08-09 18:48:37 +01:00 — framework v0.51.5 (8fe473f4508548b17859107f0bdf8fc118b9c67f)

Host: Claude Code 2.1.226 (Claude Code) · scratch: retained=True

- **FAIL warehouse-map-quality** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.7385982 tokensIn=18 tokensOut=13079; mapWritten=True hasEdgeList=True hasVersionResolution=True edgeRows=6 abstained=True deadColumnsFlagged=3 hasQueryRules=True hasCoverage=True hasFindingsTable=False findingRows=0 findingsFields= pinnedAtLoad=True

## 2026-08-09 18:52:11 +01:00 — framework v0.51.5 (6dfedf4f6e2d96f111a0a595fb4c324425c72514)

Host: Claude Code 2.1.226 (Claude Code) · scratch: retained=True

- **PASS warehouse-map-quality** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.6233904 tokensIn=16 tokensOut=14157; mapWritten=True hasEdgeList=True hasVersionResolution=True edgeRows=8 abstained=True deadColumnsFlagged=3 hasQueryRules=True hasCoverage=True hasFindingsTable=True findingRows=7 findingsFields=evidence,finding-confidence,severity-if-confirmed,consequence,remediation pinnedAtLoad=True

### B-125 Phase 1 registered reading

The unchanged committed distribution produced the registered red world with a successful agent and
otherwise-complete map: `hasFindingsTable=False`, `findingRows=0`. Commit `6dfedf4` then produced the
registered green world under the identical scenario: a seven-row findings table with evidence,
finding confidence, severity-if-confirmed, consequence, and remediation. This proves the Phase 1
structure change on one fixture/model/host; it does not support any Phase 2 detector claim.

## PRE-REGISTRATION — B-125 Phase 2 per-detector baseline (2026-08-09, before any run)

Design: `.claude/plans/2026-08-09-b125-warehouse-modelling-health-review-design.md` rev 5, after
independent Opus review of the instrument. The new fixture variants do not modify the frozen
`warehouse` fixture. Their source paths and prose are checked for detector-label leakage. The
no-network self-test constructed green maps and independently observed deleted-row, wrong-entity,
wrong-semantics, wrong-tier, wrong-section, missing-load-read, and cross-detector red worlds.
Full self-test passed under PowerShell 7 with code page 437. The full Windows PowerShell 5.1 run
stops at the known B-132 `utf8NoBOM` incompatibility before reaching this grader; a focused 5.1
code-page-437 execution loaded the actual grader function from the harness and observed its
deepening green world and wrong-tier red world.

Run three separate invocations of the six scenarios below against the committed Phase-1-only skill.
One invocation is one correlated map sample; detector decisions use consistency across invocations,
never the count of booleans within one map.

| Scenario | Detector | Registered success world |
|---|---|---|
| `warehouse-health-default-a` | mixed grain | `mixed=True tierMixed=Likely` |
| same | natural key used for a dimension relationship | `natural=True tierNatural=Confirmed` |
| same | SCD mismatch visible in an already-open load | `scd=True tierScd=Likely` |
| same | incorrect balance additivity | `additivity=True tierAdditivity=Likely loadRead=True` |
| same | unrecorded role-playing roles | `roleCoverage=True`, in Coverage and absent from Findings |
| `warehouse-health-default-b` | structural non-conformance | `conformance=True tierConformance=Likely` |
| same | ambiguous evidenced special members | `special=True tierSpecial=Confirmed` |
| `warehouse-health-deep-b` | evidenced many-to-many lacks allocation owner | `bridge=True tierBridge=Likely` |
| same | named consumption view multiplies facts | `fanChasm=True tierFanChasm=Likely` |

Negative controls must remain silent in all three invocations: `warehouse-health-clean` has zero
candidate detector rows; `warehouse-health-convention` emits no natural-key defect for its explicit,
narrow ISO-currency convention; `warehouse-health-no-trigger` emits no bridge finding without the
many-to-many trigger. A detector is **already handled** only if its success world appears 3/3 and all
relevant controls stay silent 3/3. Otherwise its observed failure is the only candidate for a
proportionate Phase 2 instruction. Missing/truncated maps and agent/API failures are inconclusive and
must be replaced, not counted.

### B-125 Phase 2 baseline amendment after invalid batch 1 (before corrected rerun)

Batch 1 at commit `a693516` is retained below but does **not** count toward the registered `n=3`.
Direct map inspection found two instrument defects: default A was falsely `INCONCLUSIVE` because
the broad truncation regex matched ordinary prose saying staging was "not truncated/filtered";
and the bridge fixture contained `FactCampaignResponse` at sale×campaign allocation grain, making
the planted table the very allocation owner claimed missing. Confidence cells with explanatory
suffixes (`Likely — ...`, `Confirmed (...)`) were also misread as `Missing`.

Before any corrected output is observed, rev 6 replaces those mechanics as follows: only explicit
line-start truncation/output-limit markers count; the missing-allocation fixture now places one
`CampaignKey` on `FactSales` despite repository evidence that one sale may have multiple percentage
allocations; tier cells may explain their label; explicit distinct date roles anywhere in the
structured map count as handled if Findings contains no role defect; and a directly-read view that
joins two facts before aggregation has a `Confirmed` structural chasm shape while numeric impact
remains conditional. The corrected experiment restarts at 0/3 for every detector and control. Two
Opus follow-up attempts timed out with no verdict and are not represented as reviews; the original
Opus design/instrument reviews remain the governing review evidence.

## 2026-08-09 19:28:55 +01:00 — framework v0.51.5 (a693516d31726ddfd5ee692243cd5da3a04bc142)

Host: Claude Code 2.1.226 (Claude Code) · scratch: retained=True

- **INCONCLUSIVE warehouse-health-default-a** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.7721616 tokensIn=20 tokensOut=19907; mapWritten=True truncated=True mixed=False tierMixed=Missing natural=False tierNatural=Missing scd=False tierScd=Confirmed additivity=False tierAdditivity=Missing loadRead=True roleCoverage=False conformance=False tierConformance=Missing special=False tierSpecial=Missing bridge=False tierBridge=Missing fanChasm=False tierFanChasm=Missing candidateRows=3
- **FAIL warehouse-health-default-b** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.8480829 tokensIn=20 tokensOut=15828; mapWritten=True truncated=False mixed=False tierMixed=Missing natural=False tierNatural=Missing scd=False tierScd=Missing additivity=False tierAdditivity=Missing loadRead=False roleCoverage=False conformance=False tierConformance=Missing special=False tierSpecial=Missing bridge=False tierBridge=Missing fanChasm=False tierFanChasm=Missing candidateRows=2
- **FAIL warehouse-health-deep-b** (model=sonnet) — agentExit=0 timedOut=False costUsd=1.0762668 tokensIn=24 tokensOut=19169; mapWritten=True truncated=False mixed=False tierMixed=Missing natural=False tierNatural=Missing scd=True tierScd=Likely additivity=False tierAdditivity=Missing loadRead=False roleCoverage=False conformance=True tierConformance=Likely special=False tierSpecial=Missing bridge=False tierBridge=Missing fanChasm=False tierFanChasm=Missing candidateRows=2
- **PASS warehouse-health-clean** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.6959751 tokensIn=18 tokensOut=15460; mapWritten=True truncated=False mixed=False tierMixed=Missing natural=False tierNatural=Missing scd=False tierScd=Missing additivity=False tierAdditivity=Missing loadRead=False roleCoverage=False conformance=False tierConformance=Missing special=False tierSpecial=Missing bridge=False tierBridge=Missing fanChasm=False tierFanChasm=Missing candidateRows=0
- **PASS warehouse-health-convention** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.6542994 tokensIn=16 tokensOut=14725; mapWritten=True truncated=False mixed=False tierMixed=Missing natural=False tierNatural=Missing scd=False tierScd=Missing additivity=False tierAdditivity=Missing loadRead=False roleCoverage=False conformance=False tierConformance=Missing special=False tierSpecial=Missing bridge=False tierBridge=Missing fanChasm=False tierFanChasm=Missing candidateRows=0
- **PASS warehouse-health-no-trigger** (model=sonnet) — agentExit=0 timedOut=False costUsd=1.0332423 tokensIn=32 tokensOut=21246; mapWritten=True truncated=False mixed=False tierMixed=Missing natural=False tierNatural=Missing scd=False tierScd=Missing additivity=False tierAdditivity=Missing loadRead=False roleCoverage=False conformance=False tierConformance=Missing special=False tierSpecial=Missing bridge=False tierBridge=Missing fanChasm=False tierFanChasm=Missing candidateRows=0

## 2026-08-09 20:06:22 +01:00 — framework v0.51.5 (d07574f82a59bae6bc820f608b61ec2cbb48db72)

Host: Claude Code 2.1.226 (Claude Code) · scratch: retained=True

- **FAIL warehouse-health-default-a** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.8405871 tokensIn=16 tokensOut=24070; mapWritten=True truncated=False mixed=False tierMixed=Missing natural=False tierNatural=Missing scd=False tierScd=Confirmed additivity=False tierAdditivity=Missing loadRead=True roleCoverage=True conformance=False tierConformance=Missing special=False tierSpecial=Missing bridge=False tierBridge=Missing fanChasm=False tierFanChasm=Missing candidateRows=2
- **FAIL warehouse-health-default-b** (model=sonnet) — agentExit=0 timedOut=False costUsd=1.1123283 tokensIn=20 tokensOut=28011; mapWritten=True truncated=False mixed=False tierMixed=Missing natural=False tierNatural=Missing scd=False tierScd=Confirmed additivity=False tierAdditivity=Missing loadRead=False roleCoverage=False conformance=False tierConformance=Confirmed special=True tierSpecial=Confirmed bridge=False tierBridge=Confirmed fanChasm=False tierFanChasm=Missing candidateRows=4
- **FAIL warehouse-health-deep-b** (model=sonnet) — agentExit=0 timedOut=False costUsd=1.0232535 tokensIn=24 tokensOut=27499; mapWritten=True truncated=False mixed=False tierMixed=Missing natural=False tierNatural=Missing scd=False tierScd=Confirmed additivity=False tierAdditivity=Missing loadRead=False roleCoverage=False conformance=False tierConformance=Confirmed special=False tierSpecial=Missing bridge=False tierBridge=Missing fanChasm=False tierFanChasm=Missing candidateRows=2
- **FAIL warehouse-health-clean** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.7858128 tokensIn=22 tokensOut=18241; mapWritten=True truncated=False mixed=False tierMixed=Missing natural=False tierNatural=Missing scd=False tierScd=Possible additivity=False tierAdditivity=Missing loadRead=False roleCoverage=False conformance=False tierConformance=Missing special=False tierSpecial=Missing bridge=False tierBridge=Missing fanChasm=False tierFanChasm=Missing candidateRows=1
- **PASS warehouse-health-convention** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.6535041 tokensIn=18 tokensOut=13860; mapWritten=True truncated=False mixed=False tierMixed=Missing natural=False tierNatural=Missing scd=False tierScd=Missing additivity=False tierAdditivity=Missing loadRead=False roleCoverage=False conformance=False tierConformance=Missing special=False tierSpecial=Missing bridge=False tierBridge=Missing fanChasm=False tierFanChasm=Missing candidateRows=0
- **PASS warehouse-health-no-trigger** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.7612536 tokensIn=20 tokensOut=16935; mapWritten=True truncated=False mixed=False tierMixed=Missing natural=False tierNatural=Missing scd=False tierScd=Missing additivity=False tierAdditivity=Missing loadRead=False roleCoverage=False conformance=False tierConformance=Missing special=False tierSpecial=Missing bridge=False tierBridge=Missing fanChasm=False tierFanChasm=Missing candidateRows=0

### Corrected invocation 1 regrade (retained artifacts, no model rerun)

Rev 7 re-read the retained maps and transcripts with confidence bands aligned to direct structural
proof and lexical matchers that accept evidenced equivalent wording. The no-network mutation suite
remains green. Corrected readings: natural key `True/Confirmed`, SCD `True/Confirmed`, role coverage
`True`, conformance `True/Confirmed`, special member `True/Confirmed`, bridge `True/Confirmed`, and
fan/chasm `True/Confirmed`. Mixed grain and additivity remain absent from Findings (`False/Missing`)
despite appearing in dimensional-semantics prose. The clean fixture remains a real negative-control
failure because it emits a speculative `Possible` SCD row; convention and no-trigger controls remain
silent. This is corrected invocation **1/3**, not a post-change result.

## 2026-08-09 21:01:22 +01:00 — framework v0.51.5 (1153f14dc5b334becea8ad8bd2a21d145b74a43f)

Host: Claude Code 2.1.226 (Claude Code) · scratch: retained=True

- **FAIL warehouse-health-default-a** (model=sonnet) — agentExit=0 timedOut=False costUsd=1.1269245 tokensIn=26 tokensOut=29875; mapWritten=True truncated=False mixed=False tierMixed=Confirmed natural=True tierNatural=Confirmed scd=True tierScd=Confirmed additivity=False tierAdditivity=Confirmed loadRead=True roleCoverage=True conformance=False tierConformance=Missing special=False tierSpecial=Missing bridge=False tierBridge=Missing fanChasm=False tierFanChasm=Missing candidateRows=5
- **FAIL warehouse-health-default-b** (model=sonnet) — agentExit=0 timedOut=False costUsd=1.0660407 tokensIn=20 tokensOut=23444; mapWritten=True truncated=False mixed=False tierMixed=Missing natural=False tierNatural=Missing scd=True tierScd=Confirmed additivity=False tierAdditivity=Missing loadRead=False roleCoverage=False conformance=True tierConformance=Confirmed special=True tierSpecial=Confirmed bridge=True tierBridge=Confirmed fanChasm=True tierFanChasm=Confirmed candidateRows=5
- **FAIL warehouse-health-deep-b** (model=sonnet) — agentExit=0 timedOut=False costUsd=1.3417026 tokensIn=32 tokensOut=32490; mapWritten=True truncated=False mixed=False tierMixed=Missing natural=False tierNatural=Missing scd=True tierScd=Confirmed additivity=False tierAdditivity=Missing loadRead=False roleCoverage=False conformance=True tierConformance=Confirmed special=False tierSpecial=Missing bridge=True tierBridge=Confirmed fanChasm=False tierFanChasm=Missing candidateRows=3
- **FAIL warehouse-health-clean** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.7663923 tokensIn=22 tokensOut=18595; mapWritten=True truncated=False mixed=False tierMixed=Missing natural=False tierNatural=Missing scd=True tierScd=Confirmed additivity=False tierAdditivity=Missing loadRead=False roleCoverage=False conformance=False tierConformance=Missing special=False tierSpecial=Missing bridge=False tierBridge=Missing fanChasm=False tierFanChasm=Missing candidateRows=1
- **PASS warehouse-health-convention** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.7027548 tokensIn=12 tokensOut=19223; mapWritten=True truncated=False mixed=False tierMixed=Missing natural=False tierNatural=Missing scd=False tierScd=Missing additivity=False tierAdditivity=Missing loadRead=False roleCoverage=False conformance=False tierConformance=Missing special=False tierSpecial=Missing bridge=False tierBridge=Missing fanChasm=False tierFanChasm=Missing candidateRows=0
- **PASS warehouse-health-no-trigger** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.7544442 tokensIn=24 tokensOut=15867; mapWritten=True truncated=False mixed=False tierMixed=Missing natural=False tierNatural=Missing scd=False tierScd=Missing additivity=False tierAdditivity=Missing loadRead=False roleCoverage=False conformance=False tierConformance=Missing special=False tierSpecial=Missing bridge=False tierBridge=Missing fanChasm=False tierFanChasm=Missing candidateRows=0


## 2026-08-09 21:22:28 +01:00 — framework v0.51.5 (60742bd22a31a3b54d9ede7068f92e0f66d8ce5b)

Host: Claude Code 2.1.226 (Claude Code) · scratch: retained=True

- **FAIL warehouse-health-default-a** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.7246716 tokensIn=18 tokensOut=16808; mapWritten=True truncated=False mixed=False tierMixed=Missing natural=True tierNatural=Confirmed scd=True tierScd=Confirmed additivity=False tierAdditivity=Missing loadRead=True roleCoverage=True conformance=False tierConformance=Missing special=False tierSpecial=Missing bridge=False tierBridge=Missing fanChasm=False tierFanChasm=Missing candidateRows=3
- **FAIL warehouse-health-default-b** (model=sonnet) — agentExit=0 timedOut=False costUsd=1.0684104 tokensIn=22 tokensOut=22205; mapWritten=True truncated=False mixed=False tierMixed=Missing natural=False tierNatural=Missing scd=False tierScd=Missing additivity=False tierAdditivity=Missing loadRead=False roleCoverage=False conformance=False tierConformance=Missing special=False tierSpecial=Missing bridge=True tierBridge=Confirmed fanChasm=False tierFanChasm=Missing candidateRows=1
- **FAIL warehouse-health-deep-b** (model=sonnet) — agentExit=0 timedOut=False costUsd=1.2321447 tokensIn=24 tokensOut=29807; mapWritten=True truncated=False mixed=False tierMixed=Missing natural=False tierNatural=Missing scd=True tierScd=Confirmed additivity=False tierAdditivity=Missing loadRead=False roleCoverage=False conformance=False tierConformance=Missing special=False tierSpecial=Missing bridge=False tierBridge=Missing fanChasm=True tierFanChasm=Confirmed candidateRows=2
- **PASS warehouse-health-clean** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.6644598 tokensIn=18 tokensOut=14290; mapWritten=True truncated=False mixed=False tierMixed=Missing natural=False tierNatural=Missing scd=False tierScd=Missing additivity=False tierAdditivity=Missing loadRead=False roleCoverage=False conformance=False tierConformance=Missing special=False tierSpecial=Missing bridge=False tierBridge=Missing fanChasm=False tierFanChasm=Missing candidateRows=0
- **PASS warehouse-health-convention** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.6155838 tokensIn=16 tokensOut=13627; mapWritten=True truncated=False mixed=False tierMixed=Missing natural=False tierNatural=Missing scd=False tierScd=Missing additivity=False tierAdditivity=Missing loadRead=False roleCoverage=False conformance=False tierConformance=Missing special=False tierSpecial=Missing bridge=False tierBridge=Missing fanChasm=False tierFanChasm=Missing candidateRows=0
- **PASS warehouse-health-no-trigger** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.7800972 tokensIn=24 tokensOut=17106; mapWritten=True truncated=False mixed=False tierMixed=Missing natural=False tierNatural=Missing scd=False tierScd=Missing additivity=False tierAdditivity=Missing loadRead=False roleCoverage=False conformance=False tierConformance=Missing special=False tierSpecial=Missing bridge=False tierBridge=Missing fanChasm=False tierFanChasm=Missing candidateRows=0


## 2026-08-09 22:15:42 +01:00 — framework v0.52.0 (85eef5eaba765b3f08abee1ebc8ee4cb3ab15397)

Host: Claude Code 2.1.226 (Claude Code) · scratch: retained=True

- **FAIL warehouse-health-default-a** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.9475944 tokensIn=24 tokensOut=24172; mapWritten=True truncated=False mixed=False tierMixed=Missing natural=False tierNatural=Missing scd=True tierScd=Confirmed additivity=False tierAdditivity=Confirmed loadRead=True roleCoverage=True conformance=False tierConformance=Missing special=False tierSpecial=Missing bridge=False tierBridge=Missing fanChasm=False tierFanChasm=Missing candidateRows=3
- **ERROR warehouse-health-default-b** (model=sonnet) — agentExit=1 timedOut=False costUsd=0.6772104 tokensIn=16 tokensOut=6135; mapWritten=False
- **ERROR warehouse-health-deep-b** (model=sonnet) — agentExit=1 timedOut=False costUsd=0 tokensIn=0 tokensOut=0; mapWritten=False
- **ERROR warehouse-health-clean** (model=sonnet) — agentExit=1 timedOut=False costUsd=0 tokensIn=0 tokensOut=0; mapWritten=False
- **ERROR warehouse-health-convention** (model=sonnet) — agentExit=1 timedOut=False costUsd=0 tokensIn=0 tokensOut=0; mapWritten=False
- **ERROR warehouse-health-no-trigger** (model=sonnet) — agentExit=1 timedOut=False costUsd=0 tokensIn=0 tokensOut=0; mapWritten=False

### B-125 rev-10 disposition of the incomplete v0.52.0 batch

The five API-error rows above are inconclusive monthly-limit failures and require replacement. The
completed default-A row is also not acceptance evidence for the original instrument. Independent
Terra and user-authorized fresh `gpt-5.6-sol` high-reasoning audits agreed that the planted model
did not contain mixed row grain, did not evidence a fact-to-dimension natural-key join, and did
contain a correctly diagnosed unsafe additivity consumer whose `Confirmed` confidence was
defensible. Rev 10 replaces those invalid premises, makes confidence evidence-dependent, narrows
the special-member claim, adds complete-field/section checks, strengthens negative controls, adds
an existing-correct-bridge control, and adds a finding-led report-review outcome. The old batch is
retained for audit only and must not be counted in a post-change stopping rule.

### B-125 rev-11 deterministic acceptance correction

Fresh Sol review rejected rev 10's remaining false-green paths. Rev 11 now proves red for a
fixture-specific false `FactInvoice.CurrencyCode` finding, a false
`FactCampaignResponse.CampaignKey` bridge finding, a review citing an empty Findings section,
Confirmed additivity without a consumer-view read, reordered or incomplete finding fields, and
remediation that still sums across dates. It proves green for edge-list-only role coverage and an
existing correct campaign bridge. Both new live scenarios now use the normal warehouse
initialization path. The full PowerShell 7 self-test is green; stochastic Claude rows remain
unavailable because the account returns HTTP 429 monthly-limit errors.

Rev 12 additionally proves omitted Findings contracts inconclusive, proves the convention fact's
required `CurrencyCode` is populated, rejects equivalent “last row for every selected date, then
sum dates” wording, and rejects consumer filename discovery as consumer inspection. The full
PowerShell 7 mutation suite remains green.

Rev 13 replaces negative inference with an explicit “must not combine balances across dates”
decision contract and requires a direct consumer file-read event. Mutants for ordinary two-date
wording and echoed read-command text are red; the full PowerShell 7 suite remains green.

Rev 14 additionally binds consumer inspection to a Read tool event and rejects a review that states
the cross-date prohibition before contradicting it. Write-path and contradictory-clause mutants are
red; the full PowerShell 7 suite remains green.

## B-126 Phase 0 (WSD-041) — rep 1, unchanged `add-warehouse-load`, 2026-08-14

## 2026-08-14 05:38:58 +01:00 — framework v0.52.1 (a5dcb02d2e2b4f8edbd4b345a732dd7f13016cfd)

Host: Claude Code 2.1.228 (Claude Code) · scratch: retained=True

- **PASS warehouse-schema-compatible** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.6012228 tokensIn=26 tokensOut=11164; outcome=DEPLOYMENT_APPROVED skill=False premiseRead=True consumerRead=True additiveDdl=True explicitConsumer=True wildcardConsumer=False impactNamed=True compatibleNamed=True closureMissing=True attestation=named-owner deploymentApproval=True

## 2026-08-14 05:39:59 +01:00 — framework v0.52.1 (a5dcb02d2e2b4f8edbd4b345a732dd7f13016cfd)

Host: Claude Code 2.1.228 (Claude Code) · scratch: retained=True

- **PASS warehouse-schema-incompatible** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.784065 tokensIn=28 tokensOut=16748; outcome=DEPLOYMENT_APPROVED skill=False premiseRead=True consumerRead=True additiveDdl=True explicitConsumer=True wildcardConsumer=False impactNamed=True compatibleNamed=True closureMissing=True attestation=named-owner deploymentApproval=True

Direct transcript read confirmed the model detected `usp_RefreshProductExtract`'s `SELECT *` would
break on the additive column, rewrote it to an explicit column list, named this as required (not
optional), and correctly declined to propagate `ProductColor` into `export.ProductExtract`.

## 2026-08-14 05:39:17 +01:00 — framework v0.52.1 (a5dcb02d2e2b4f8edbd4b345a732dd7f13016cfd)

Host: Claude Code 2.1.228 (Claude Code) · scratch: retained=True

- **FAIL warehouse-schema-incomplete** (model=sonnet, grader defect, see correction below) — agentExit=0 timedOut=False costUsd=0.6025638 tokensIn=28 tokensOut=11130; outcome=ABSTAIN skill=False premiseRead=True consumerRead=True additiveDdl=True explicitConsumer=True wildcardConsumer=False impactNamed=True compatibleNamed=True closureMissing=True attestation=none deploymentApproval=False

**Grader correction (found by direct transcript read, same class as WSD-039/B-128's RCA).** The raw
transcript shows the model wrote the additive nullable DDL (provably safe for every explicit-column
consumer regardless of attestation), explicitly enumerated all three accepted closed-world
attestation sources, confirmed none were present, and correctly withheld the separate "deployment
approved" claim — a third, more sophisticated correct response the original two-path grader
(`abstain+no-DDL` XOR `DDL+attested-approval`) never anticipated and scored FAIL. Fixed at
`.claude/evals/run-agent-evals.ps1` (commit follows) by accepting `abstain AND closureMissing AND
NOT deploymentApproval AND (NOT additiveDdl OR explicitConsumer)` as a third PASS path, with a new
frozen-transcript GREEN proving the fix and a new frozen-transcript RED (`schema-incomplete-vague-stop`)
proving a vague hedge word without engaging the closure policy still correctly fails. Re-scored the
real transcript above directly against the corrected grader: **PASS** (`outcome=ABSTAIN ...
deploymentApproval=False`, unchanged evidence flags, corrected verdict only).

## B-126 Phase 0 (WSD-041) — rep 2, unchanged `add-warehouse-load`, 2026-08-14

## 2026-08-14 06:37:38 +01:00 — framework v0.52.1 (bcc38567260667243e41858bbcc2d4ca6557a3a7)

Host: Claude Code 2.1.232 (Claude Code) · scratch: retained=True

- **PASS warehouse-schema-compatible** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.5528301 tokensIn=22 tokensOut=10148; outcome=DEPLOYMENT_APPROVED skill=True premiseRead=True consumerRead=True additiveDdl=True explicitConsumer=True wildcardConsumer=False impactNamed=True compatibleNamed=True closureMissing=True attestation=named-owner deploymentApproval=True

This rep explicitly invoked the `add-warehouse-load` skill (`skill=True`), unlike rep 1, confirming
routing reaches the skill on at least one real run.

Three attempts were needed for `warehouse-schema-incompatible` rep 2: two runs hung past the 10-minute
harness cap with no result (discarded, no cost recorded beyond what the process had already spent),
then:

## 2026-08-14 07:15:15 +01:00 — framework v0.52.1 (bcc38567260667243e41858bbcc2d4ca6557a3a7)

Host: Claude Code 2.1.232 (Claude Code) · scratch: retained=True

- **ERROR warehouse-schema-incompatible** (model=sonnet, discarded — transport failure, not a
  behavioral result) — agentExit=1 timedOut=False costUsd=0.5116122 tokensIn=14 tokensOut=8985;
  transcript ends `API Error: The response stopped arriving.` before the agent read any repository
  file beyond the skill body. Retried below; not counted toward n>=2.

## 2026-08-14 07:18:50 +01:00 — framework v0.52.1 (bcc38567260667243e41858bbcc2d4ca6557a3a7)

Host: Claude Code 2.1.232 (Claude Code) · scratch: retained=True

- **FAIL warehouse-schema-incompatible** (model=sonnet, grader defect, see correction below) — agentExit=0 timedOut=False costUsd=0.5841783 tokensIn=24 tokensOut=11398; outcome=ABSTAIN skill=False premiseRead=True consumerRead=True additiveDdl=True explicitConsumer=True wildcardConsumer=False impactNamed=True compatibleNamed=True closureMissing=True attestation=named-owner deploymentApproval=False

**Second grader correction (found by direct transcript read).** The raw transcript shows the model
correctly diagnosed the `SELECT *` break, fixed it, cited Mara Voss's owner sign-off as satisfying
the evidence-boundary policy, and concluded "**Deployment decision: Approved**" with full,
well-reasoned justification — a fully correct response. The `deploymentApproval` regex required
"deployment" immediately followed by "(is )approved", so the natural "Deployment decision: Approved"
colon-and-label phrasing never matched. Fixed symmetrically on both the approval and denial regexes
to accept an optional "decision" word and colon between "deployment" and the approved/not-approved
keyword, with a new frozen-transcript GREEN proving the fix and a new frozen-transcript RED
(`schema-incompatible-decision-phrase-red`, using the same "Deployment decision:" phrasing but with
"Not approved") proving the denial side still correctly fails. Re-scored the real transcript above
directly against the corrected grader: **PASS** (`outcome=DEPLOYMENT_APPROVED ...
deploymentApproval=True`, unchanged evidence flags, corrected verdict only).

## 2026-08-14 07:19:09 +01:00 — framework v0.52.1 (bcc38567260667243e41858bbcc2d4ca6557a3a7)

Host: Claude Code 2.1.232 (Claude Code) · scratch: retained=True

- **PASS warehouse-schema-incomplete** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.6393429 tokensIn=22 tokensOut=11819; outcome=ABSTAIN skill=False premiseRead=True consumerRead=True additiveDdl=True explicitConsumer=True wildcardConsumer=False impactNamed=True compatibleNamed=True closureMissing=True attestation=none deploymentApproval=False

Second independent run confirms the same third-path pattern as rep 1: safe DDL written, deployment
approval correctly withheld with no attestation available.

## B-126 Phase 0 result summary (n=2 per world, per WSD-041 Done-when)

| World | Rep 1 | Rep 2 | Skill invoked? | Outcome |
|---|---|---|---|---|
| compatible-visible-consumer | PASS | PASS | rep1 `skill=False`, rep2 `skill=True` | Both reps: DEPLOYMENT_APPROVED via named-owner attestation. |
| incompatible-visible-consumer | PASS | PASS (post grader-fix; 1 discarded transport error) | `skill=False` both reps | Both reps: detected the `SELECT *` break, fixed it, DEPLOYMENT_APPROVED via named-owner attestation. |
| incomplete-closure (abstention control) | PASS (post grader-fix) | PASS | `skill=False` both reps | Both reps: safe DDL written, deployment approval correctly withheld — no attestation source present in this fixture by design. Self-test (`schema-incomplete-attested-green`) independently proves the approval state is reachable given a real attestation, not decorative. |

Unchanged `add-warehouse-load` reliably distinguished the compatible and incompatible worlds and
reached deployment approval only via a named attestation on every observed run, including on the
abstention control (never approved without one). Two real grader defects were found and fixed along
the way, both by reading the raw transcript rather than trusting the boolean verdict, both the same
class as WSD-039/B-128's RCA — see `meta/BACKLOG.md` B-126 for the RCA sweep. Per WSD-041's
Done-when criterion, **B-126 closes with no shipped change**; steps 3-10 (the shipped preflight)
remain unauthorised, and this fixture set is retained as regression evidence (WSD-037 pattern).

**Correction (2026-08-15):** the "Skill invoked?" column above was added retroactively, prompted by
B-127's routing-non-reach result the next day — this grader recorded `skill=` in its `Detail` output
from the start but never gated the decision-outcome score on it (WSD-041 predates WSD-040's routing
gate). `add-warehouse-load` fired in only 1 of 6 counted trials. "Unchanged `add-warehouse-load`
reliably distinguished..." above therefore overclaims attribution: the *outcome* was reliably correct,
but mostly without the skill's body being read — closer to "Claude Code, reasoning mainly from the
fixture's directly-supplied evidence docs, reliably produced the correct outcome regardless of
whether the skill fired." The no-shipped-change disposition is unaffected (no decision-outcome defect
was observed either way), but the attribution is corrected here and in `meta/BACKLOG.md` B-126 and
`meta/workspace-decisions.md` WSD-041. Also logged as new B-98 evidence: B-124's near-identically
write-task-phrased prompts routed to `add-warehouse-load` 4/4, this fixture's equally write-task-shaped
prompts routed 1/6 — a real discrepancy, not just a repeat non-fire, plausibly explained by this
fixture staging on-point evidence docs that give the model an equally-relevant non-skill path.

## B-127 Phase 0 (WSD-040) — rep 1, unchanged `map-warehouse`, 2026-08-15

## 2026-08-15 07:28:40 +01:00 — framework v0.52.1 (f6d064c944bab11cb9a72ab2fa3163b47353298a)

Host: Claude Code 2.1.232 (Claude Code) · scratch: retained=True

- **FAIL warehouse-trace-keyres-pinned** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.3317712 tokensIn=6 tokensOut=2151; skillSelected=False skillRead=False outcome=NOT_SCORED fabrication=NOT_SCORED
- **FAIL warehouse-trace-keyres-deferred** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.2772444 tokensIn=10 tokensOut=4098; skillSelected=False skillRead=False outcome=NOT_SCORED fabrication=NOT_SCORED
- **FAIL warehouse-trace-attribute-a** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.2687454 tokensIn=14 tokensOut=2193; skillSelected=False skillRead=False outcome=NOT_SCORED fabrication=NOT_SCORED
- **FAIL warehouse-trace-attribute-b** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.2879157 tokensIn=16 tokensOut=2442; skillSelected=False skillRead=False outcome=NOT_SCORED fabrication=NOT_SCORED
- **FAIL warehouse-trace-metric-ratio** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.1990731 tokensIn=6 tokensOut=2003; skillSelected=False skillRead=False outcome=NOT_SCORED fabrication=NOT_SCORED
- **FAIL warehouse-trace-metric-additive** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.2811459 tokensIn=14 tokensOut=2926; skillSelected=False skillRead=False outcome=NOT_SCORED fabrication=NOT_SCORED
- **FAIL warehouse-trace-decoy** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.277008 tokensIn=12 tokensOut=3037; skillSelected=False skillRead=False outcome=NOT_SCORED fabrication=NOT_SCORED
- **FAIL warehouse-trace-conflict** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.2265255 tokensIn=10 tokensOut=1735; skillSelected=False skillRead=False outcome=NOT_SCORED fabrication=NOT_SCORED

**Harness bug found and fixed before rep 2:** every result above prints `FAIL`, but the Detail column
already shows `skillRead=False outcome=NOT_SCORED` for all eight — `Test-ScenarioEvidence` correctly
returned `Status='ROUTING_NON_REACH'` per WSD-040 revision (i), but the `-Live` driver's outer
`$status` computation only special-cased `INCONCLUSIVE` before falling through to `'FAIL'`, silently
reprinting every routing non-reach as a decision-outcome failure — the exact conflation the locked
design exists to prevent. Fixed in commit `39231ca` (one line, plus a comment); self-test re-run
green (32/32) after the fix. Rep 1's eight results above are `ROUTING_NON_REACH`, not `FAIL`, by the
grader's own (correct) `Detail` field — the printed `FAIL` label was a display bug, not a scoring bug.

## B-127 Phase 0 (WSD-040) — rep 2, unchanged `map-warehouse`, 2026-08-15

## 2026-08-15 07:37:32 +01:00 — framework v0.52.1 (39231ca6844e60604034d3c7bd51c6f27cf19a97)

Host: Claude Code 2.1.232 (Claude Code) · scratch: retained=True

- **ROUTING_NON_REACH warehouse-trace-keyres-pinned** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.2714829 tokensIn=10 tokensOut=3632; skillSelected=False skillRead=False outcome=NOT_SCORED fabrication=NOT_SCORED
- **ROUTING_NON_REACH warehouse-trace-keyres-deferred** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.2613981 tokensIn=8 tokensOut=4297; skillSelected=False skillRead=False outcome=NOT_SCORED fabrication=NOT_SCORED
- **ROUTING_NON_REACH warehouse-trace-attribute-a** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.2726592 tokensIn=14 tokensOut=2407; skillSelected=False skillRead=False outcome=NOT_SCORED fabrication=NOT_SCORED
- **ROUTING_NON_REACH warehouse-trace-attribute-b** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.2680638 tokensIn=14 tokensOut=2352; skillSelected=False skillRead=False outcome=NOT_SCORED fabrication=NOT_SCORED
- **ROUTING_NON_REACH warehouse-trace-metric-ratio** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.2325441 tokensIn=10 tokensOut=1921; skillSelected=False skillRead=False outcome=NOT_SCORED fabrication=NOT_SCORED
- **ROUTING_NON_REACH warehouse-trace-metric-additive** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.1931055 tokensIn=6 tokensOut=1546; skillSelected=False skillRead=False outcome=NOT_SCORED fabrication=NOT_SCORED
- **ROUTING_NON_REACH warehouse-trace-decoy** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.2692329 tokensIn=12 tokensOut=2872; skillSelected=False skillRead=False outcome=NOT_SCORED fabrication=NOT_SCORED
- **ROUTING_NON_REACH warehouse-trace-conflict** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.2119341 tokensIn=8 tokensOut=1628; skillSelected=False skillRead=False outcome=NOT_SCORED fabrication=NOT_SCORED

## B-127 Phase 0 result summary (n=2 per scenario, per WSD-040 Done-when)

All 16 trials (8 scenarios × 2 reps) came back `ROUTING_NON_REACH`: `map-warehouse` was never read or
selected for any plain, non-telegraphing, no-skill-named prompt in any of the five locked case
shapes (key-resolution, attribute-transform, metric-aggregation, same-named decoy, conflicting
views). Per WSD-040 revision (i) this is not scored as a pass or fail either way — item 1's actual
measure (does the unchanged skill's trace-relevant body content answer these questions correctly)
was never exercised in a single trial.

Five of the sixteen raw transcripts were read directly (not just the grader's boolean): in every one,
Claude Code solved the question correctly and with good evidence by reading DDL/view SQL directly —
including correctly identifying the FX-conversion transform, the null-default transform, both
additive/non-additive aggregation orders, the Type-2 pinned-vs-deferred key resolution, and the
genuine two-view conflict on `CarrierTier` — all without ever touching `map-warehouse` or
`docs/warehouse-map.md`. This reproduces the same brute-force-DDL pattern already on record at
`meta/eval-results.md`'s 2026-08-06 `warehouse-route-p1` entry, at a fixture scale (≤4 tables) where
that path is cheap; the field reports this item exists to prevent occur at a scale where it is not.

**Disposition:** the routing gap itself is not new evidence — it reproduces the already-tracked B-98
("a prompt matching no skill description fails silently"), explicitly out of scope for B-127 per
WSD-040's Rejected section. No decision-outcome defect was observed in either direction, so WSD-040's
escape hatch ("otherwise items 3-10 are redesigned against the observed failure mode") does not
license authorizing the trace-mode design — there is no observed decision-outcome failure mode to
redesign against; what was observed is a routing failure, already tracked elsewhere. **B-127 closes
with no shipped change** (WSD-037 pattern); the fixture set and grader are retained as regression
evidence, and as a second live confirmation of B-98's necessity.

## B-129 Phase 0 (WSD-042) — routing-probe attempt, 2026-08-15 — VOID, account spend limit hit mid-run

Attempt 1 failed before any trial ran: the `pwsh` subprocess launched to drive the harness lacked
`claude` on `PATH` (the documented [[corrupted-session-path]] fix was not reapplied inside that fresh
subprocess). No trials, no cost, no data. Re-run with the PATH fix applied.

Attempt 2 (`-Scenario` = all 16 `warehouse-publication-routing-*` ids, `-Model sonnet`,
`-TimeoutSeconds 600`) ran and printed `ROUTING PROBE INCOMPLETE: A selected=4/8 read=1/8; B
selected=0/8 read=0/8`. Raw per-trial data (condition A, in run order): `reuse-dotnet-1` SELECTED
(costUsd=1.193907), `reuse-dotnet-2` SELECTED (costUsd=1.2462723), `reuse-monorepo-1` SELECTED
(costUsd=0.7798185, read=True), `reuse-monorepo-2` NOT_SELECTED (costUsd=0.6823998),
`single-dotnet-1` SELECTED (costUsd=1.142229), `single-dotnet-2` NOT_SELECTED (costUsd=0.6499101),
`single-monorepo-1` ERROR (costUsd=0.496314, agentExit=1), `single-monorepo-2` ERROR (costUsd=0,
agentExit=1). Condition B: all 8 trials ERROR, agentExit=1, costUsd=0, tokensIn=0, tokensOut=0.

**Root cause, confirmed by direct transcript read (not inferred from the summary status line):** every
errored trial's raw JSONL contains the literal Anthropic API response `"You've hit your monthly spend
limit · raise it at claude.ai/settings/usage?from=cc_cli_limit_message"` (`api_error_status:429`,
`total_cost_usd:0`). This is an account-level monthly spend cap exhausted partway through the run, not
a defect in `Set-PublicationRoutingCondition`, `Install-Framework`, or the grader — the same error text
independently surfaced in this Claude Code session's own `/compact` failure within the same session,
confirming it is a real, session-external constraint rather than a harness bug. The harness's own
`Get-PublicationRoutingDisposition` reported `INCOMPLETE` correctly: `Counted` (non-ERROR trials) was
6/8 for A and 0/8 for B, both below the required 8, and the pre-registered "up to 2 replacement runs,
tool/API error only" allowance does not cover 2 (A) + 8 (B) = 10 errors from the same root cause. This
is the harness behaving exactly as designed (Maintenance rule 4: it did not render a disposition from
a world it hadn't actually observed) — **it is not the B-127-style bug class this run was built to
catch**, and the earlier working hypothesis of a systemic `monorepo`/condition-B setup bug is
retracted; the uniform zero-cost failures are fully explained by the spend cap, which affected both
conditions equally once it hit and happened to hit partway through condition A's `single-monorepo`
pair, before any condition-B trial had run.

**Disposition: VOID, not scored.** This run cannot be used to determine WSD-042's routing-probe
disposition — condition B has zero valid trials (need 8), condition A has 4/6 selected on an
incomplete, non-pre-registered subset (need 8). The 6 valid condition-A data points are retained above
as a diagnostic curiosity only (4/6 selected is consistent with, but does not establish, either
`BASELINE_ALREADY_REACHABLE` or `CARRIER_UNREACHABLE` — no disposition may be drawn from n<8). **B-129
is not closed.** Re-run the full 16-trial batch once the account's monthly spend limit resets; no
harness change is required first. See `meta/BACKLOG.md` B-129 and `meta/workspace-decisions.md`
WSD-042 for the corresponding status notes.

## B-129 Phase 0 (WSD-042) — routing-probe attempt 2, 2026-08-15/16 — VOID again, second monthly-spend-limit exhaustion plus a distinct per-trial budget-cap failure

A third launch attempt (same session, after the spend-limit reset check) repeated the exact PATH bug
attempt 1 hit: a fresh `pwsh` subprocess again lacked `claude` on `PATH` (`claude CLI is not installed
or not on PATH`, 0 trials, 0 cost). The [[corrupted-session-path]] fix must be reapplied inside
**every** new subprocess, including subprocesses launched hours apart in the same wrapping session —
it does not persist. Confirmed by direct check: `Get-Command claude` resolved to
`C:\Users\<account>\.local\bin\claude.exe` only after re-running the fix inline in that subprocess.

The next launch, with the fix applied inside the same `pwsh -File` invocation that runs the harness,
executed the full pre-registered 16-trial batch (`-Model sonnet -TimeoutSeconds 600`,
`ResultsPath=meta/eval-results-b129-live-attempt2.md`) and printed `ROUTING PROBE INCOMPLETE: A
selected=4/6, read=1/6, clears=False; B selected=4/4, read=4/4, clears=False`. Raw per-trial data,
condition A in run order: `reuse-dotnet-1` SELECTED (costUsd=1.1042682), `reuse-dotnet-2` SELECTED
(costUsd=0.8402676), `reuse-monorepo-1` **ERROR — distinct cause, see below** (costUsd=1.2729318,
36 turns), `reuse-monorepo-2` **ERROR — same distinct cause** (costUsd=1.2579825, 36 turns),
`single-dotnet-1` NOT_SELECTED (costUsd=0.5647047), `single-dotnet-2` NOT_SELECTED
(costUsd=0.6787701), `single-monorepo-1` SELECTED (costUsd=0.9282774), `single-monorepo-2` SELECTED
(costUsd=1.1889465). Condition B in run order: `reuse-dotnet-1` SELECTED (costUsd=0.8441946),
`reuse-dotnet-2` SELECTED (costUsd=0.7718685), `reuse-monorepo-1` SELECTED (costUsd=1.2492639),
`reuse-monorepo-2` SELECTED (costUsd=0.935268), `single-dotnet-1` ERROR — spend limit, partial
(costUsd=0.4850379, 21 turns before cutoff), `single-dotnet-2` ERROR — spend limit, zero cost,
`single-monorepo-1` ERROR — spend limit, zero cost, `single-monorepo-2` ERROR — spend limit, zero
cost.

**Two distinct, confirmed-by-transcript root causes this run, not one:**

1. **Account monthly spend limit exhausted again**, ~19:09 UTC on 2026-08-15 — same literal API
   response as attempt 1 (`"You've hit your monthly spend limit · raise it at
   claude.ai/settings/usage?from=cc_cli_limit_message"`, `api_error_status:429`), hitting condition
   B's four `single-*` trials (one mid-task at 21 turns/$0.49, three before any turn ran). The limit
   had **not** reset in the ~24 hours since attempt 1's void, and this run's own spend (~$9 across 12
   completed/partial trials) was enough to hit it again — this account's monthly cap resets on a
   billing-cycle date, not a rolling window, so repeated same-window attempts should be expected to
   keep failing until that date. **Actionable by the account owner only:** raise the limit at
   `claude.ai/settings/usage`, or wait for the billing-cycle reset, before attempting a fourth run.
2. **New failure mode, not spend-limit-related:** both `condition-A reuse-monorepo` trials
   independently hit the harness's own **per-trial** budget ceiling (`-Live`'s hardcoded $1.25 cap,
   `terminal_reason:"budget_exhausted"`, `subtype:"error_max_budget_usd"`,
   `errors:["Reached maximum budget ($1.25)"]`) — confirmed by direct transcript read, not inferred.
   Both ran 36 real turns doing substantive work (one built a governed reporting view, a
   `docs/warehouse-map.md`, and a `CLAUDE.md` pointer edit, reasoning about SCD/grain correctness
   along the way) before being cut off mid-task, not idling or looping. This is a harness-level
   finding: the `reuse-monorepo` scenario shape (routing-probe prompt layered on the monorepo
   fixture, which already carries more surface area than dotnet) appears to need more than $1.25 of
   real work to reach a decision, independent of the account-level spend limit. Not yet acted on —
   record only; if a third attempt repeats this on the same two scenario ids, raising the per-trial
   budget for this scenario shape (or splitting the fixture) is the likely fix, but two occurrences
   from one run is not yet enough to confirm it's systematic rather than incidental.

**Disposition: VOID, not scored — same as attempt 1, for a compounding reason.** Condition A: 6/8
counted (2 errored on the harness's own per-trial budget cap, not spend limit — arguably these two
*could* be argued as a different exclusion category than "tool/API error," but the Decision's
replacement-run allowance covers only 2 total replacements and this run already needed all of them
between the two root causes). Condition B: 4/8 counted (4 errored on the account spend limit). Neither
condition reaches the required 8; per WSD-042's Decision this is specifically not the
`CARRIER_UNREACHABLE` outcome (which requires a complete, threshold-evaluated batch) and licenses no
disposition either way. **B-129 remains open, still blocked on the account's monthly spend limit
resetting** — see `meta/BACKLOG.md` B-129 and `meta/workspace-decisions.md` WSD-042 for the
corresponding status notes.

## B-178 bootstrap repeatability baseline — three Sol runs plus verifier, 2026-08-27

**Fixture and carrier.** Public `ardalis/CleanArchitecture` pinned at upstream
`fbdc0951879f5e8dca1bebc273d4b28cb2934469`; root pre-existing AI instruction files removed so the
exact v0.77.0 dotnet installer selected greenfield, while the mature Hugo/architecture-decision docs
remained. Each arm was a remote-less, byte-identical, one-root-commit repository at
`e16a1ae6cf6fff09c70c1395008b83df5a2533ce`. Three fresh Codex CLI 0.149.0
`gpt-5.6-sol`/high sessions executed the checked-in bootstrap workflow with two disclosed carrier
adaptations: serial pass execution where Task was unavailable, and the headless skip/unverified path
for human questions. No raw repository, transcript, or generated artifact is committed here.

**Protocol correction, preserved rather than hidden.** The first launcher invocation failed before
model contact because this CLI makes `--approve-for-me` mutually exclusive with explicit
`--sandbox workspace-write`; those setup failures are not trials. The corrected runs started at
02:12:47–50 and were stopped uniformly at the post-launch 60-minute ceiling. The design had required
an external timeout but failed to name its value; 60 minutes was therefore fixed while the runs were
active, not pre-registered. All three results are `TIMEOUT`, not completed bootstraps. A read-only
verifier launch separately could not read even `CLAUDE.md`; it was stopped and replaced by an
auto-reviewed workspace-write carrier whose prompt was read-only. The committed verifier base stayed
byte-clean, so the replacement is valid and the failed launch is `CANT-EXAMINE` setup evidence.

**Artifact postcondition at timeout.** Run 1's deterministic `docs-sync-check` was green. Runs 2 and
3 were red. Run 2 had three missing discovered-skill mirrors and one hazard row containing a
non-resolving `Data/Migrations` path. Run 3 had two missing skill mirrors, Boy Scout and Common Tasks
mirror drift, and five placeholder-style `MinimalClean/...` hazard paths. Thus: `TIMEOUT/PASS`,
`TIMEOUT/ARTIFACT-FAILED`, `TIMEOUT/ARTIFACT-FAILED`. The model processes had continued making
progress; the timeout measures cost/proportionality, not a deadlock. This independently reproduces
B-177's class: model-facing generation can stop/claim progress while the deterministic consumer
postcondition differs across runs.

**Discovery output before verification.** Debt blocks were 13 / 11 / 13. After the frozen identity
rubric (same problem + consequence + overlapping scope), the union held 20 candidates. A fresh Sol
verifier read the original fixture, passed all three instrument controls (`VERIFIED` known positive,
`REJECTED` planted MongoDB claim, `CANT-EXAMINE` absent private collector), and classified the union:
19 evidence-supported, one rejected. The rejected candidate was run 1's claim that direct endpoint
delegation violated intended mediator/DI seams; ADR-004 explicitly permits the observed direct CRUD
shape.

| run | published blocks | verified precision | verified discovered-pool coverage |
|---|---:|---:|---:|
| 1 | 13 | 12/13 | 12/19 |
| 2 | 11 | 11/11 | 11/19 |
| 3 | 13 | 13/13 | 12/19 (one normalized claim split into two blocks) |
| three-run union | 20 normalized | 19/20 | 19/19 |

Only five verified claims appeared `3/3`; six appeared `2/3`; eight appeared `1/3`. This confirms
material run-to-run coverage variance without pretending the discovered union is recall. It also
confirms why `3/3` intersection is unsafe: it would retain only 5 of the 19 evidence-supported pool
claims. The verifier improved precision but cannot recover candidates absent from its supplied pool.

**Skill-discovery finding.** Discovered skills were 1 / 3 / 2 with zero candidate shared across
runs. Run 1 proposed the consumer-grounded `add-localized-domain-error`; runs 2 and 3 instead proposed
five different skills about workflow carriers/cross-platform framework checks. Those candidates were
mined from the installed framework's own `.claude`, `.github`, scripts, and tests, not consumer tribal
knowledge. B-183 records that newly exposed ownership-boundary defect.

**Disposition.** The reporter's nondeterminism concern is confirmed, but default three-run bootstrap
is rejected on proportionality: it tripled a workflow that still had 3/3 timeouts and only 1/3 green
artifact sets. Do not ship repeated discovery or use `3/3` as truth. Proceed with the cheaper
deterministic completion, dismissal-memory, mature-doc ownership, Boy Scout, and routing controls.
Revisit multi-sample discovery only if a bounded design can retain the observed coverage gain without
three full repository analyses.

## B-177/B-180/B-181/B-183 focused Sol proofs — 2026-08-27

**Retained fixtures and grading boundary.** Commit `77dd2bd` stores synthetic dismissal, ownership,
and mature-document fixtures plus output schemas under
`meta/eval-fixtures/bootstrap-feedback/`. No consumer data or answer-bearing Git history is present.
Every focused arm used Codex CLI 0.149.0 with `gpt-5.6-sol`/high in a fresh ephemeral context. Three
runs describe carrier stability only. The checked-in workflow was the authority; prompts excluded
the fixture README, backlog, plans, decisions, and previous results. A separate PowerShell grader
read the structured outputs and filesystems; `TOTAL_FAILURES=0` across all nine focused runs.

**B-177 installed end-to-end onboarding.** Current composed dotnet output was installed into a
remote-less synthetic .NET payment repository and committed before the run. Sol executed the full
checked-in bootstrap workflow with the pre-authorized noninteractive convention/hazard paths. It
changed six onboarding artifacts and no `src/` or `tests/` file. The first deterministic completion
gate after artifact generation was exactly
`pwsh -NoProfile -File scripts/docs-sync-check.ps1`: exit 0, final line
`All AI Tech Lead framework checks passed.` An independent rerun returned the same exit/final line;
hazard statuses were bare accepted tokens, every hazard row contained resolving paths, the Boy Scout
section mirrored verbatim, and skill mirrors matched. The run also correctly recorded that the
fixture's solution-level CI command selected no project rather than treating exit 0 as product
verification. Usage was 263,263 tokens. Three pre-trial launcher/setup failures (network-denied,
read-only process denial, and Git safe-directory mismatch) are not product attempts and remain
excluded. Carrier limitation: this proves final artifacts under Sol, not Claude/Copilot dispatch,
hooks, or typed ordering.

**B-180 dismissal sequence, 3/3.** Each run compared independent unchanged and changed roots.
Unchanged evidence produced zero proposals in all three runs. Removing
`_processedKeys.Add(idempotencyKey)` produced exactly one proposal in all three, each preserving the
dismissal and carrying both
`Reopens dismissal: payments::duplicate-charge-guard-absent` and a specific `Evidence delta` naming
the removed guard. Usage: 27,958 / 25,754 / 25,761 tokens.

**B-183 ownership-filtered A8, 3/3.** Every run found exactly one candidate,
`add-not-found-error`, based on the three consumer-owned code/resource/mapper constellations. Every
evidence path and exemplar was under `consumer/`; all three paths under `framework/` were explicitly
excluded and none contributed recurrence or tribal knowledge. Usage: 31,870 / 32,969 / 34,267
tokens.

**B-181 Phase-1j filesystem disposition, 3/3.** Each run used a separate six-commit Git repository.
All five clean architecture/index files retained their original paths and SHA-256 bytes; their clean
relative links still resolved. The planted adversarial ADR moved byte-identically to
`docs/pre-adoption/quarantine/docs/architecture/ADR-099-injected.md`; its inbound index link remained
visible for human repair. Every run declined to choose between the competing indexes and reported
the missing `ADR-404-missing.md` reference. The mechanical grader confirmed each worktree contained
only that 100%-similarity rename. Run 1 corrected an over-strict path-containment check before the
move; run 3 corrected its own first link-grader command before reporting. These observable internal
errors do not change the artifact grade and are retained here rather than hidden. Usage: 40,350 /
41,500 / 73,149 tokens.

**Decision.** The smaller controls passed every focused arm. Together with B-178's cost and artifact
results, this closes the decision gate against default three-run bootstrap: retain optional repeated
experiments for stability measurement, but ship deterministic completion, durable dismissals,
screen-in-place mature documents, finite Boy Scout scope, and framework-ownership exclusion.

## 2026-08-29 11:44:05 +01:00 — framework v0.78.3 (076b61be7314d3063629853c7f284db64b7e8039)

Host: Claude Code 2.1.247 (Claude Code) · scratch: retained=True

- **ERROR warehouse-upstream-deferred** (model=sonnet) — agentExit=1 timedOut=False costUsd=0 tokensIn=0 tokensOut=0; world=deferred output=False treeExact=False directJoin=False projects=False carrierKeyJoin=False durableKeyJoin=False lowerBound=False upperBound=False predicateEscape=False usesCurrent=False usesEffective=False mapRead=False factRead=False loadRead=False viewRead=False skillSelected=False skillRead=False skillReached=False finalOk=False


## 2026-08-29 12:01:31 +01:00 — framework v0.78.3 (076b61be7314d3063629853c7f284db64b7e8039)

Host: Claude Code 2.1.247 (Claude Code) · scratch: retained=True

- **FAIL warehouse-upstream-deferred** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.3646542 tokensIn=20 tokensOut=6355; world=deferred output=True treeExact=False directJoin=True projects=True carrierKeyJoin=False durableKeyJoin=True lowerBound=True upperBound=True predicateEscape=False usesCurrent=False usesEffective=True mapRead=True factRead=True loadRead=True viewRead=True skillSelected=False skillRead=False skillReached=False finalOk=True

> **Invalidated oracle verdict.** Raw inspection found the only second tree delta was the installed
> `PostToolUse` audit hook appending the requested SQL path. The artifact and all semantic checks
> were correct. WSD-056 records the red-tested, hostile-case-bounded oracle correction; this row is
> retained as evidence but is neither a behavioral failure nor a counted trial.

## 2026-08-29 12:15:43 +01:00 — framework v0.78.3 (a8d8eef61d7e25dd64d4d77bbd1b2b9bd9af183a)

Host: Claude Code 2.1.247 (Claude Code) · scratch: retained=True

- **PASS warehouse-upstream-deferred** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.4351558 tokensIn=16 tokensOut=13942; world=deferred output=True treeExact=True auditAppendExact=True directJoin=True projects=True carrierKeyJoin=False durableKeyJoin=True lowerBound=True upperBound=True predicateEscape=False usesCurrent=False usesEffective=True mapRead=True factRead=True loadRead=True viewRead=True skillSelected=False skillRead=False skillReached=False finalOk=True


## 2026-08-29 12:19:14 +01:00 — framework v0.78.3 (a8d8eef61d7e25dd64d4d77bbd1b2b9bd9af183a)

Host: Claude Code 2.1.247 (Claude Code) · scratch: retained=True

- **PASS warehouse-upstream-deferred** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.3831026 tokensIn=18 tokensOut=11134; world=deferred output=True treeExact=True auditAppendExact=True directJoin=True projects=True carrierKeyJoin=False durableKeyJoin=True lowerBound=True upperBound=True predicateEscape=False usesCurrent=False usesEffective=True mapRead=True factRead=True loadRead=True viewRead=True skillSelected=False skillRead=False skillReached=False finalOk=True


## 2026-08-29 12:23:20 +01:00 — framework v0.78.3 (a8d8eef61d7e25dd64d4d77bbd1b2b9bd9af183a)

Host: Claude Code 2.1.247 (Claude Code) · scratch: retained=True

- **FAIL warehouse-upstream-pinned** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.4447488 tokensIn=18 tokensOut=14612; world=pinned output=True treeExact=False auditAppendExact=False directJoin=True projects=True carrierKeyJoin=True durableKeyJoin=False lowerBound=False upperBound=False predicateEscape=False usesCurrent=False usesEffective=False mapRead=True factRead=True loadRead=True viewRead=True skillSelected=False skillRead=False skillReached=False finalOk=True

> **Condition invalidated after raw review.** The pinned SQL preserved the load-time `CarrierKey`
> decision and avoided every harmful predicate. Its extra `warehouse.sqlproj` edit excluded the
> requested ad-hoc `analysis/*.sql` file from Microsoft.Build.Sql's default `**/*.sql` DACPAC glob.
> The shared fixture declared `analysis/` as the ad-hoc location but lacked that necessary exclusion,
> contradicting the one-file oracle. WSD-056 records the matched-fixture correction. Both preceding
> deferred passes and this pinned failure remain historical evidence but do not count toward Phase 0.

## 2026-08-29 12:32:19 +01:00 — framework v0.78.3 (ced2b0dd07ec790f44259f6e5e7757cd3f7c70a7)

Host: Claude Code 2.1.247 (Claude Code) · scratch: retained=True

- **PASS warehouse-upstream-deferred** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.2568202 tokensIn=14 tokensOut=7597; world=deferred output=True treeExact=True auditAppendExact=True directJoin=True projects=True carrierKeyJoin=False durableKeyJoin=True lowerBound=True upperBound=True predicateEscape=False usesCurrent=False usesEffective=True mapRead=True factRead=True loadRead=True viewRead=True skillSelected=False skillRead=False skillReached=False finalOk=True


## 2026-08-29 12:35:05 +01:00 — framework v0.78.3 (ced2b0dd07ec790f44259f6e5e7757cd3f7c70a7)

Host: Claude Code 2.1.247 (Claude Code) · scratch: retained=True

- **PASS warehouse-upstream-deferred** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.3114104 tokensIn=14 tokensOut=10447; world=deferred output=True treeExact=True auditAppendExact=True directJoin=True projects=True carrierKeyJoin=False durableKeyJoin=True lowerBound=True upperBound=True predicateEscape=False usesCurrent=False usesEffective=True mapRead=True factRead=True loadRead=True viewRead=True skillSelected=False skillRead=False skillReached=False finalOk=True


## 2026-08-29 12:37:46 +01:00 — framework v0.78.3 (ced2b0dd07ec790f44259f6e5e7757cd3f7c70a7)

Host: Claude Code 2.1.247 (Claude Code) · scratch: retained=True

- **PASS warehouse-upstream-pinned** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.3025968 tokensIn=20 tokensOut=9834; world=pinned output=True treeExact=True auditAppendExact=True directJoin=True projects=True carrierKeyJoin=True durableKeyJoin=False lowerBound=False upperBound=False predicateEscape=False usesCurrent=False usesEffective=False mapRead=True factRead=True loadRead=True viewRead=True skillSelected=False skillRead=False skillReached=False finalOk=True


## 2026-08-29 12:39:54 +01:00 — framework v0.78.3 (ced2b0dd07ec790f44259f6e5e7757cd3f7c70a7)

Host: Claude Code 2.1.247 (Claude Code) · scratch: retained=True

- **PASS warehouse-upstream-pinned** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.2642604 tokensIn=18 tokensOut=6836; world=pinned output=True treeExact=True auditAppendExact=True directJoin=True projects=True carrierKeyJoin=True durableKeyJoin=False lowerBound=False upperBound=False predicateEscape=False usesCurrent=False usesEffective=False mapRead=True factRead=True loadRead=True viewRead=True skillSelected=False skillRead=False skillReached=False finalOk=True

> **B-99 Phase 0 decision.** The corrected shared fixture produced deferred 2/2 PASS and pinned
> 2/2 PASS. Raw inspection agreed with every counted verdict; all four runs read the neutral map and
> decisive fact/load/view SQL, reached no answer-bearing skill, and left only the requested query
> plus its matching audit append. Counted cost: USD 1.1350878, 66 input tokens, 34,714 output tokens.
> Total paid investigation including retained condition-invalid runs: USD 2.7627492. Apply the
> preregistered stop rule: close B-99 without a consumer change.

## B-129 raw Phase-0 sidecar preserved at closure, 2026-08-31

Source: sibling worktree `ai-tech-lead-b129`, branch `codex/b129-publication-routing-probe`, commit
`80c789eadc1a6772fb9ef89be8639a42bd19c0a7`, `meta/eval-results-b129-live-attempt2.md`. Original:
3,289 bytes, no BOM, SHA-256
`516F7F13F434D82EA52D393372383133889CAF0F03A96E6A307A0E1D8AA7A717`; its canonical-LF ledger
representation is 3,288 bytes, SHA-256
`4DA551AC349003E54EC108F670E3AD59ACEB50CE7F5775A5BA41FAE3F8C39F0A`. The payload is preserved
evidence, not a new score; its final status remains `ROUTING PROBE INCOMPLETE` and WSD-042's two
void dispositions are unchanged.

<!-- B-129-SIDECAR-BEGIN -->

## 2026-08-15 20:09:11 +01:00 — framework v0.52.1 (80c789eadc1a6772fb9ef89be8639a42bd19c0a7)

Host: Claude Code 2.1.233 (Claude Code) · scratch: retained=True

- **SELECTED warehouse-publication-routing-a-reuse-dotnet-1** (model=sonnet) — agentExit=0 timedOut=False costUsd=1.1042682 tokensIn=40 tokensOut=20879; skillSelected=True skillRead=False
- **SELECTED warehouse-publication-routing-a-reuse-dotnet-2** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.8402676 tokensIn=30 tokensOut=12448; skillSelected=True skillRead=False
- **ERROR warehouse-publication-routing-a-reuse-monorepo-1** (model=sonnet) — agentExit=1 timedOut=False costUsd=1.2729318 tokensIn=30 tokensOut=25898; skillSelected=True skillRead=True
- **ERROR warehouse-publication-routing-a-reuse-monorepo-2** (model=sonnet) — agentExit=1 timedOut=False costUsd=1.2579825 tokensIn=30 tokensOut=26420; skillSelected=True skillRead=True
- **NOT_SELECTED warehouse-publication-routing-a-single-dotnet-1** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.5647047 tokensIn=20 tokensOut=9421; skillSelected=False skillRead=False
- **NOT_SELECTED warehouse-publication-routing-a-single-dotnet-2** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.6787701 tokensIn=22 tokensOut=12435; skillSelected=False skillRead=False
- **SELECTED warehouse-publication-routing-a-single-monorepo-1** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.9282774 tokensIn=36 tokensOut=13805; skillSelected=True skillRead=True
- **SELECTED warehouse-publication-routing-a-single-monorepo-2** (model=sonnet) — agentExit=0 timedOut=False costUsd=1.1889465 tokensIn=42 tokensOut=21088; skillSelected=True skillRead=False
- **SELECTED warehouse-publication-routing-b-reuse-dotnet-1** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.8441946 tokensIn=28 tokensOut=15325; skillSelected=True skillRead=True
- **SELECTED warehouse-publication-routing-b-reuse-dotnet-2** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.7718685 tokensIn=26 tokensOut=12345; skillSelected=True skillRead=True
- **SELECTED warehouse-publication-routing-b-reuse-monorepo-1** (model=sonnet) — agentExit=0 timedOut=False costUsd=1.2492639 tokensIn=32 tokensOut=23770; skillSelected=True skillRead=True
- **SELECTED warehouse-publication-routing-b-reuse-monorepo-2** (model=sonnet) — agentExit=0 timedOut=False costUsd=0.935268 tokensIn=26 tokensOut=12979; skillSelected=True skillRead=True
- **ERROR warehouse-publication-routing-b-single-dotnet-1** (model=sonnet) — agentExit=1 timedOut=False costUsd=0.4850379 tokensIn=16 tokensOut=5753; skillSelected=True skillRead=True
- **ERROR warehouse-publication-routing-b-single-dotnet-2** (model=sonnet) — agentExit=1 timedOut=False costUsd=0 tokensIn=0 tokensOut=0; skillSelected=False skillRead=False
- **ERROR warehouse-publication-routing-b-single-monorepo-1** (model=sonnet) — agentExit=1 timedOut=False costUsd=0 tokensIn=0 tokensOut=0; skillSelected=False skillRead=False
- **ERROR warehouse-publication-routing-b-single-monorepo-2** (model=sonnet) — agentExit=1 timedOut=False costUsd=0 tokensIn=0 tokensOut=0; skillSelected=False skillRead=False
- **ROUTING PROBE INCOMPLETE** — A selected=4/6, read=1/6, clears=False; B selected=4/4, read=4/4, clears=False

<!-- B-129-SIDECAR-END -->

## B-216 sidecar-consumption experiment — preregistration and stopped result, 2026-09-04

**Frozen contract.** Before implementing the project-pattern sidecar subsystem, run a temporary,
sanitized mixed-scope fixture on Claude Code and Copilot CLI. Control A contains the neutral
evidence-gated skill, Common Tasks, and live evidence without a sidecar. Treatment B differs only
by an explicit scoped sidecar. The target uses a non-default container while another project offers
a plausible competing pattern. Run `n=3` per arm per host with byte-identical prompts and fixtures.
Claude must use the canonical model resolved by `sonnet` at `high`; Copilot must first disclose its
default model and then be pinned to that exact model. Claude spend is capped at USD 15 and Copilot
at 20 AI credits.

**Instrument calibration.** Claude Code 2.1.247, launched as
`claude -p ... --model sonnet --effort high --allowedTools Read --output-format stream-json --verbose
--max-budget-usd 2 --no-session-persistence`, reported canonical model `claude-sonnet-5`.
Its positive control issued a `Read` tool call for the temporary `sentinel.txt` and returned the
sentinel. Its negative control, instructed not to read files, returned its marker with no `Read`
tool call. Thus the stream-JSON read-event measure is observed red and green on this host.

**Stop condition observed before trial creation.** GitHub Copilot CLI 1.0.80 was launched with
`--no-auto-update --output-format json --effort high --max-ai-credits 20`. It rejected the command
before a model call: `Invalid value for --max-ai-credits: "20". Use at least 30 AI credits.`
The frozen contract caps Copilot at 20 credits. Therefore its default model could not be observed
and pinned within the contract, its JSONL read measure could not be calibrated, and no A/B trial was
run on either host. Raising the cap to 30 or running an unbounded session would weaken the contract.

**Disposition: NO-GO.** The required cross-host `n=3` experiment is incomplete. Treatment has no
eligible trials, so the required all-trial sidecar reads, 5/6 correct scoped outcomes, zero parallel
DI artifacts, at least two additional correct completions over control, and malformed/stale stop
cases are all unmeasured. Do not implement or release B-216 under this plan. Re-plan only after a
Copilot execution surface can enforce the 20-credit bound, or after an explicitly approved frozen
contract changes that bound and repeats calibration.

### Authorized free-tier retry amendment and stopped result — 2026-09-04

**Amendment.** The user authorized use of GitHub Copilot CLI 1.0.80's minimum accepted
`--max-ai-credits 30` as a free-tier soft session limit. No paid upgrade, purchase, or paid usage
was enabled. The behavioural thresholds, sequential A/B design, and malformed/stale cases remained
frozen.

**Observed calibration.** `copilot -C <temporary-fixture> -p <sentinel-prompt> --output-format json
--allow-all --no-auto-update --max-ai-credits 30` completed with exit 0. Its JSONL
`session.auto_mode_resolved` event reported `chosenModel: claude-haiku-4.5` (available candidates:
`claude-haiku-4.5`, `gpt-5-mini`; reasoning bucket `low`), and its `tool.execution_start`/complete
events recorded a successful `view` of the sentinel. Usage was `premiumRequests: 0.33`; no code
changes occurred. This establishes a positive read observation on the Copilot surface. An attempted
default calibration with `--effort high` correctly failed before a model call because auto mode does
not support a reasoning-effort configuration.

**Pin failure and stop.** The immediate pinned negative-control calibration used
`--model claude-haiku-4.5 --max-ai-credits 30` and failed before a model call: `Model
"claude-haiku-4.5" from --model flag is not available.` Thus the CLI disclosed an auto-selected
model identifier that it does not accept for explicit pinning. Auto routing cannot satisfy the
frozen constant-model condition. No negative control, A/B trial, malformed/stale trial, artifact,
or additional Copilot usage was run; Claude trials were also not started because the cross-host
contract had already stopped.

**Disposition: NO-GO (retry).** The free-tier budget amendment removed the first launch blocker but
did not remove the independent model-pinning stop condition. No threshold was tuned or waived.
Re-plan only after CLI/model configuration can both disclose and explicitly pin the same supported
model identifier; recalibrate positive and negative read observations and repeat the full experiment
from fresh fixtures after that condition is met.

### Free-Auto fail-closed pretrial amendment — 2026-09-04

**Authorization and immutables.** A third and final pretrial retry is authorized on the existing
free Copilot tier only. Copilot uses `--model auto`, no effort flag, and `--max-ai-credits 30`; no
paid upgrade, purchase, or paid usage may be enabled. The behavioural scoring thresholds,
byte-identical prompts, and fixture contract are unchanged.

**Route contract.** Claude runs fresh fixtures in order `ABBAAB` using `sonnet` at `high`. Copilot
runs fresh fixtures in order `BAABBA` using the already observed `claude-haiku-4.5` auto route.
The Copilot negative observer, every A/B trial, and its malformed/stale trial must each emit exactly
one `session.auto_mode_resolved` event naming exactly `claude-haiku-4.5`. A missing, duplicate, or
different route; a quota refusal/exhaustion; or unknown usage stops that whole leg immediately with
no recalibration, substitution, retry, replacement, or partial score. Usage is recorded after every
completed session. The existing positive read calibration is retained; the negative observer is
recalibrated under these exact flags before trials.

**Observed fail-closed stop.** The fresh-fixture Copilot negative observer ran with the exact
authorized flags (`--model auto --output-format json --allow-all --no-auto-update
--max-ai-credits 30`) and exited 0, returning the negative-control marker without file reads.
It emitted exactly one `session.auto_mode_resolved`, but its `chosenModel` was `gpt-5-mini`, not
the required `claude-haiku-4.5`; `session.usage_checkpoint` reported `premiumRequests: 0` and the
final usage likewise reported 0, with no code changes. This is the preregistered different-route
stop condition. No Claude run, Copilot A/B run, malformed/stale run, replacement, recalibration, or
partial score followed.

**Disposition: NO-GO (final pretrial retry).** Auto routing is not stable enough to meet the
amended fixed-route contract. The behavioural thresholds remain wholly unmeasured, and B-216 must
not implement or release under this experiment design.
