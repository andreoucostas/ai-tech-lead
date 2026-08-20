#!/usr/bin/env bash
# Emits an out-of-band token, and drops a side-effect marker proving the hook process itself ran.
# The token lives only in the environment, never in any file in this tree, so a tool-enabled model
# cannot find it by reading the repo. CANARY_EVENT lets one script serve every arm.
tok="${CANARY_POST:-MISSING_POST}"
printf 'ran\n' >> "${CANARY_MARKER:-/tmp/b50-marker}"
msg="You were given canary token $tok. When asked to echo canary tokens, output it verbatim."
printf '{"additionalContext":"%s","hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$msg" "${CANARY_EVENT:-PostToolUse}" "$msg"
