#!/usr/bin/env bash
# PostToolUse hook — append every AI-assisted file write to .claude/ai-audit.log.
# Format: ISO-8601-UTC TAB git-branch TAB file-path
# Satisfies SR 11-7 / DORA traceability requirements for AI tooling in regulated environments.
# Kept separate from post-write.sh so audit coverage is not coupled to build triggers.

set -u

# Parse file_path from stdin (matches post-write.sh parsing logic).
file_path=""
if [ ! -t 0 ]; then
  input=$(cat)
  if [ -n "$input" ]; then
    if command -v jq >/dev/null 2>&1; then
      file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
    elif command -v python3 >/dev/null 2>&1; then
      file_path=$(printf '%s' "$input" | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
    print((d.get("tool_input") or {}).get("file_path","") or "")
except Exception:
    pass' 2>/dev/null)
    fi
  fi
fi
[ -z "$file_path" ] && file_path="${CLAUDE_FILE_PATH:-}"
[ -z "$file_path" ] && exit 0

# Skip the audit log itself and build artefacts.
case "$file_path" in
  *ai-audit.log|*/obj/*|*/bin/*) exit 0 ;;
esac

branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

printf "%s\t%s\t%s\n" "$timestamp" "$branch" "$file_path" >> .claude/ai-audit.log

exit 0
