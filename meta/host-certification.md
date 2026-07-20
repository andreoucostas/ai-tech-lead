# Host compatibility certification

Maintainer live-fire evidence for claims in the shipped enforcement matrix. `Direct fixture`
proves hook output, not host consumption. Blank cells are forbidden; unavailable surfaces say so.

| Surface | Capability | Observed | Host version | Certified |
|---|---|---|---|---|
| Claude Code | SessionStart context | Direct fixture emitted the unbootstrapped warning; end-to-end recert blocked by host session limit | 2.1.212 | not certified — quota |
| Claude Code | UserPromptSubmit route rails | Direct fixture emitted `/fix` rails for the target prompt; end-to-end recert blocked by host session limit | 2.1.212 | not certified — quota |
| Claude Code | PreToolUse guard | Direct fixture exited 2 and blocked `AKIAIOSFODNN7EXAMPLE`; end-to-end recert blocked by host session limit | 2.1.212 | not certified — quota |
| Claude Code | PostToolUse feedback consumed | Not run — host session limit | 2.1.212 | not certified — quota |
| Claude Code | Stop Boy-Scout nudge | Not run — host session limit | 2.1.212 | not certified — quota |
| Copilot CLI | Folder-trust prerequisite | Fresh untrusted clone ran no hooks and wrote the fixture key; the already-trusted disposable canary path ran hooks | 1.0.70 | 2026-07-17 |
| Copilot CLI | SessionStart context consumed | Out-of-band sentinel `B49_SESSION_START_8KP3` returned verbatim | 1.0.70 | 2026-07-17 |
| Copilot CLI | userPromptSubmitted context consumed | Out-of-band sentinel `B49_OUT_OF_BAND_7QX9` returned verbatim without tools | 1.0.70 | 2026-07-17 |
| Copilot CLI | PreToolUse deny honored | First model refusal re-instructed per protocol; guard denied the fixture key and the agent retried with `REPLACE_ME` | 1.0.70 | 2026-07-17 |
| Copilot CLI | postToolUse context consumed | **Changed since 1.0.68:** after a real write, sentinel `B49_POST_TOOL_4MV2` returned verbatim; B-50 filed | 1.0.70 | 2026-07-17 |
| Copilot VS Code agent mode | Preview agent-hooks | No interactive VS Code/Copilot seat available in this drill session | unavailable | not certified — no seat |

