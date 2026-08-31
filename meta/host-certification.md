# Host compatibility certification

Maintainer live-fire evidence for claims in the shipped enforcement matrix. Evidence is
capability-specific: a date or host version on one row never certifies another event or a chain that
contains it. `Direct fixture` proves hook output, not host consumption. Native
`.github/instructions/` delivery is separate from Preview-hook lifecycle evidence. Blank cells are
forbidden; unavailable or unexamined surfaces say so.

Re-certification is evidence-triggered under WSD-066, not calendar-driven. Before a row can be
upgraded or re-dated, its canary needs: (1) the treatment; (2) a positive control already known to
deliver on the same host/surface; (3) a no-hook negative control with the same model/tool exposure,
which invalidates the instrument if the token arrives by an alternative route; and (4) an
independent side-effect marker that distinguishes "hook did not fire" from "hook fired but output
was not consumed". An environment variable is not secret from a tool-enabled model, so environment-
only token placement is not a valid no-leak control. Failure to launch or observe a canary is
recorded as inability to examine, not as a capability failure.

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
| Copilot CLI | userPromptSubmitted single-entry delivery | Four controlled runs established that only the last registered entry reaches the model: two entries, swapped tokens, three entries, and three structurally distinct entries | 1.0.79/1.0.80 | 2026-08-18 |
| Copilot CLI | PreToolUse deny honored | First model refusal re-instructed per protocol; guard denied the fixture key and the agent retried with `REPLACE_ME` | 1.0.70 | 2026-07-17 |
| Copilot CLI | postToolUse context consumed | **Changed since 1.0.68:** after a real write, sentinel `B49_POST_TOOL_4MV2` returned verbatim; B-50 filed | 1.0.70 | 2026-07-17 |
| Copilot CLI | postToolUse context consumed | **CONFIRMED in an isolated three-arm canary (B-50).** Treatment (`postToolUse`) echoed `B50-POSTTOOL-Q7R4X2` verbatim after a real `create` tool call, and its hook-ran marker fired. Positive control (the same script on `userPromptSubmitted`, a channel already verified on this CLI) also echoed, making a null readable. Negative control (no `hooks.json`) echoed nothing and its marker never fired, ruling out an observed alternative token route under the same prompt; environment-only placement would not have done so by itself. Kit: `meta/canaries/b50-copilot-posttooluse/` | 1.0.80 | 2026-08-20 |
| Copilot CLI | agentStop firing and Boy Scout queue write | No live run. The event is registered and vendor-documented, but `meta/canaries/agent-stop-delivery/` remains UNRUN and non-certifying as written | not tested | not certified — unrun |
| Copilot VS Code agent mode | PreToolUse guard deny honored | The legacy v0.23.0 changelog records one end-to-end Preview-hook denial on 2026-06-25; host and extension versions were not recorded | not recorded | historical observation — not current certification |
| Copilot VS Code agent mode | userPromptSubmitted context consumed | No current live run; no interactive VS Code/Copilot seat available | unavailable | not certified — no seat |
| Copilot VS Code agent mode | postToolUse context consumed | No current live run; no interactive VS Code/Copilot seat available | unavailable | not certified — no seat |
| Copilot VS Code agent mode | Stop/agentStop firing and Boy Scout delivery | Event spelling, firing, and output consumption have not been observed; no interactive VS Code/Copilot seat available | unavailable | not certified — no seat |
