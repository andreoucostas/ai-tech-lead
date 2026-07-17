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
