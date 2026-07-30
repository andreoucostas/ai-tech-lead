#!/usr/bin/env bash
token="${CANARY_AGENT_STOP_TOKEN:-MISSING_AGENT_STOP_TOKEN}"
timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'FIRED turn-end %s\n' "$timestamp" >> .canary-agent-stop-fired
message="Turn-end canary token: ${token}. Echo this token verbatim if you receive it."
printf '{"additionalContext":"%s","hookSpecificOutput":{"hookEventName":"agentStop","additionalContext":"%s"}}' \
  "$message" "$message"
