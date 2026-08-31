# Copilot turn-end canary — firing, delivery, and VS Code event spelling

Persisted kit for WSD-024. It was built to answer three separate host questions: whether Copilot
CLI fires `agentStop`, whether text emitted by that event reaches the model, and whether VS Code
agent mode accepts `agentStop` or requires its documented `Stop` spelling.

**Status:** built 2026-07-30. **Results: UNRUN. Non-certifying as written.** The kit has a
treatment and a firing marker, but no known-good positive-control arm and no no-hook negative-control
arm. Do not use a future run to upgrade a host claim until the instrument is freshly re-locked under
WSD-066's evidence standard.

| Host | Version tested | Event spelling | Fired marker | Token echoed | Result |
|------|----------------|----------------|--------------|--------------|--------|
| Copilot CLI | UNRUN | `agentStop` | UNRUN | UNRUN | UNRUN |
| VS Code agent mode | UNRUN | `agentStop` | UNRUN | UNRUN | UNRUN |
| VS Code agent mode | UNRUN | `Stop` | UNRUN | UNRUN | UNRUN |

Record `copilot --version` for CLI and the VS Code + GitHub Copilot extension versions before
replacing these rows. VS Code agent hooks must be enabled under Preview settings.

## Design

The turn-end hook appends `FIRED <event> <UTC timestamp>` to `.canary-agent-stop-fired` and emits
an instruction containing `CANARY_AGENT_STOP_TOKEN`. The token comes from the environment and is
absent from tracked files, but that does **not** make it secret from a tool-enabled model: a shell
tool can read the inherited environment. The marker can prove firing independently of delivery;
an echoed token is ambiguous without a no-hook control, and a null is ambiguous without a
known-good delivery control on the same host/surface.

`hooks.json` registers `agentStop`. `hooks-stop.json` is the same fixture with `Stop` for the
second VS Code run; copy it over `.github/hooks/hooks.json` only in the temporary canary checkout.

## Historical run recipe — Copilot CLI (do not use for certification as written)

1. Copy this directory to a fresh temporary folder, initialize and commit it as a git repository,
   then launch `copilot -C <folder>` once to trust the folder.
2. Record `copilot --version`, set a fresh out-of-band token, and run a turn:
   ```powershell
   $env:CANARY_AGENT_STOP_TOKEN='CANARY-AGENT-STOP-Z7K2Q9'
   copilot -C <folder> --allow-all-tools -p "Answer with DONE. If a canary token arrives after your turn, echo it verbatim."
   ```
3. Inspect `.canary-agent-stop-fired` and the transcript.

Interpretation boundary: a marker would prove that this fixture's `agentStop` hook fired. Token
delivery and a null remain non-certifying for the reasons above. Absence of a marker must first be
separated from inability to launch or examine the hook by checking version, trust, interpreter, and
host diagnostics; it is not evidence that the capability is absent.

## Historical run recipe — VS Code agent mode (do not use for certification as written)

Open the trusted temporary checkout with Preview agent hooks enabled. Set
`CANARY_AGENT_STOP_TOKEN` in the environment that launches VS Code, ask agent mode the same prompt,
then inspect the marker and transcript. Run first with `hooks.json`. If no marker appears, replace
it with `hooks-stop.json`, reload the window, delete any old marker, and repeat.

- `agentStop` marks: this fixture would have observed VS Code accepting the CLI spelling.
- Only `Stop` marks: this fixture would have observed VS Code accepting only its documented spelling.
- Neither marks: record the versions and hook diagnostics as unverified; do not infer a spelling.
- An echoed token on either run is not delivery proof without the missing controls.
