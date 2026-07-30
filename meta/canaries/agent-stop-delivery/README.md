# Copilot turn-end canary — firing, delivery, and VS Code event spelling

Persisted kit for WSD-024. It answers three separate host questions: whether Copilot CLI fires
`agentStop`, whether text emitted by that event reaches the model, and whether VS Code agent mode
accepts `agentStop` or requires its documented `Stop` spelling.

**Status:** built 2026-07-30. **Results: UNRUN.**

| Host | Version tested | Event spelling | Fired marker | Token echoed | Result |
|------|----------------|----------------|--------------|--------------|--------|
| Copilot CLI | UNRUN | `agentStop` | UNRUN | UNRUN | UNRUN |
| VS Code agent mode | UNRUN | `agentStop` | UNRUN | UNRUN | UNRUN |
| VS Code agent mode | UNRUN | `Stop` | UNRUN | UNRUN | UNRUN |

Record `copilot --version` for CLI and the VS Code + GitHub Copilot extension versions before
replacing these rows. VS Code agent hooks must be enabled under Preview settings.

## Design

The turn-end hook appends `FIRED <event> <UTC timestamp>` to `.canary-agent-stop-fired` and emits
an instruction containing `CANARY_AGENT_STOP_TOKEN`. The token comes only from the environment,
so the model cannot discover it by reading the checkout. The marker proves firing independently
of delivery; an echoed token proves the event's output reached the model.

`hooks.json` registers `agentStop`. `hooks-stop.json` is the same fixture with `Stop` for the
second VS Code run; copy it over `.github/hooks/hooks.json` only in the temporary canary checkout.

## Run against Copilot CLI

1. Copy this directory to a fresh temporary folder, initialize and commit it as a git repository,
   then launch `copilot -C <folder>` once to trust the folder.
2. Record `copilot --version`, set a fresh out-of-band token, and run a turn:
   ```powershell
   $env:CANARY_AGENT_STOP_TOKEN='CANARY-AGENT-STOP-Z7K2Q9'
   copilot -C <folder> --allow-all-tools -p "Answer with DONE. If a canary token arrives after your turn, echo it verbatim."
   ```
3. Inspect `.canary-agent-stop-fired` and the transcript.

Interpretation: a marker proves `agentStop` fired. The token echoed by the model proves its output
is injected and the production queue hop may be reconsidered. A marker without an echo proves the
current split timing/delivery design remains necessary. Neither means this CLI does not support or
did not load the event; first re-check version, trust, and hook diagnostics.

## Run against VS Code agent mode

Open the trusted temporary checkout with Preview agent hooks enabled. Set
`CANARY_AGENT_STOP_TOKEN` in the environment that launches VS Code, ask agent mode the same prompt,
then inspect the marker and transcript. Run first with `hooks.json`. If no marker appears, replace
it with `hooks-stop.json`, reload the window, delete any old marker, and repeat.

- `agentStop` marks: VS Code accepts the CLI spelling.
- Only `Stop` marks: VS Code requires its documented spelling.
- Neither marks: record the versions and hook diagnostics as unverified; do not infer a spelling.
- An echoed token on either run: that event is also a model delivery channel on that host.
