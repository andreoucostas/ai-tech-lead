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
