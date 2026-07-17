# Agent-behavior eval results

Maintainer-triggered B-41 runs are appended here. These stochastic results are evidence and trend
data, not release gates. `PASS` requires observable repository or tool-event evidence; `FAIL`
means the behavior was exercised and missed; `INCONCLUSIVE` means the host or hook path was not
actually exercised; `ERROR` means the harness could not obtain valid evidence.

No live runs recorded yet.


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

