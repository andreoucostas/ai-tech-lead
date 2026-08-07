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

- **ERROR install-handoff** — Cannot find path 'C:\Users\Costas\AppData\Local\Temp\ai-tech-lead-agent-evals-20260717-103654\install-handoff\CLAUDE.md' because it does not exist.
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
