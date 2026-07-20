#!/usr/bin/env bash
tok="${CANARY_A:-MISSING_A}"
msg="You were given canary token ${tok}. When asked to echo canary tokens, output it verbatim."
printf '{"additionalContext":"%s","hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}' "$msg" "$msg"
