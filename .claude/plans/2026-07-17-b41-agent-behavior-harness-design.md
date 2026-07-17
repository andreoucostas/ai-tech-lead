# B-41 · Agent-behavior eval harness — design (LOCKED)

**Status: LOCKED 2026-07-17 after adversarial self-critique.** Implementation may refine
fixtures and assertions, but must not turn this into a general eval platform.

## Decision

Add a maintainer-only PowerShell harness under `.claude/evals/`. It drives the locally installed
`claude -p` CLI in disposable repositories made from the checked-out committed distribution
(whose version must match the root changelog) and grades
observable filesystem, git, hook, and tool-order evidence from stream-JSON transcripts. It does
not replace the shipped `tests/evals/` response-quality probes and does not run in CI.

Five core scenarios encode the behavior classes named by B-41:

1. `install-handoff`: an agent installs the framework into a separate target, commits there,
   prints the installer handoff, and stops before bootstrap.
2. `archived-redirect`: an archived source's agent-addressed STOP redirects installation to the
   canonical tree; its frozen installer never runs.
3. `route-fix`: a natural-language bug prompt receives `/fix` rails and demonstrates a planted
   regression test red before changing production code, then green after.
4. `guard-retry`: an attempted fixture-shaped secret is blocked and the eventual file contains a
   safe placeholder, proving recovery rather than mere refusal.
5. `skill-add-tests`: the installed `add-tests` skill is followed end-to-end and verification is
   shown after a test artifact is created.

Three small planted-defect cases provide the evidence needed to close absorbed item B-29: run `convention-check`, `bloat-radar`,
and `debt-radar` explicitly at their shipped Haiku tier and require the planted finding in the
observable final output.

Each scenario has a per-run USD ceiling and a hard wall-clock timeout. Results append to
`meta/eval-results.md`; a single miss is
reported honestly but is not a release gate. The release script gives an interactive prompt when
possible and otherwise prints the exact run command.

## Shape

- `.claude/evals/run-agent-evals.ps1`: fixture creation, CLI invocation, assertions, result log.
- `.claude/evals/scenarios.json`: the eight prompts, budgets, and assertion metadata.
- `.claude/evals/tests/AgentEvals.Tests.ps1`: no-network tests using synthetic transcripts and
  fixture setup; also proves failures return non-zero.
- `meta/eval-results.md`: append-only per-version summary, including host/model and inconclusive
  results.

The runner requires an explicit `-Live` switch. Without it, it explains cost/scope and exits 2;
`-SelfTest` is free. Scratch directories are made under the OS temp directory, have no remotes,
and are retained on failure unless `-KeepScratch:$false` is explicitly selected.

## Adversarial critique folded

- **False behavioral evidence from transcript prose:** assertions parse typed assistant
  `tool_use`, matched user `tool_result`, terminal `result`, git state, and file bytes. Prompt,
  thinking, and arbitrary tool-output keyword echoes cannot earn a pass; a planted echo-only
  transcript proves that negative.
- **Agent avoids the guard, so no hook was tested:** require a blocked hook event plus a safe final
  file; refusal alone is inconclusive.
- **Test-first ordering is not durable:** grade ordered command/edit events and their matched tool
  results; require red test evidence before the production edit and green evidence after it.
- **Dirty authoring tree contaminates results:** refuse an uncommitted distribution diff, require
  dist version = root changelog version, and record the exact framework commit.
- **Accidental CI/API spend:** explicit `-Live`, no workflow wiring, budget per scenario.
- **API retries can hang despite a budget cap:** kill the complete CLI process tree at the
  configurable per-scenario timeout and record an `ERROR`, never a behavioral failure.
- **Stochastic hard gate:** thresholds live in the results log; release only prompts.
- **CLI/schema drift makes every scenario look red:** validate stream JSON first and distinguish
  `ERROR`/`INCONCLUSIVE` from a behavioral `FAIL`.
- **Windows-only maintainer runner hides portability claims:** this is meta tooling, already
  PowerShell-only by WSD-012; it makes no consumer portability claim.

## Post-review scope correction

The first PR is the Claude phase only. B-41 remains open until a Copilot CLI executor handles its
trusted-folder prerequisite and Copilot-specific deny/additionalContext evidence, and B-23's
consumer-shipping question is decided. No pre-review live row counts as evidence; B-29 closes only
after the typed graders are rerun successfully.
