#!/usr/bin/env bash
# PostToolUse hook — append every AI-assisted file write to .claude/ai-audit.log.
# Format: ISO-8601-UTC TAB git-branch TAB file-path
# Satisfies SR 11-7 / DORA traceability requirements for AI tooling in regulated environments.
# Handles three input formats (same as post-write.sh):
#   Claude Code          — tool_input.file_path  (snake_case, matcher filters tool)
#   VS Code Copilot      — tool_input.filePath   (camelCase, no matcher → name-filter in script)
#   Copilot cloud/CLI    — toolArgs JSON string  (toolName + toolArgs at top level)

set -u

# Parse file_path from stdin (mirrors post-write.sh parsing logic).
file_path=""
if [ ! -t 0 ]; then
  input=$(cat)
  if [ -n "$input" ]; then
    if command -v jq >/dev/null 2>&1; then
      # Tool name filter — Copilot has no matcher; Claude Code uses settings.json matcher.
      tool_name=$(printf '%s' "$input" | jq -r '.tool_name // .toolName // ""' 2>/dev/null)
      case "$tool_name" in
        Write|Edit|"") ;;
        *) exit 0 ;;
      esac
      # Claude Code: tool_input.file_path | VS Code Copilot: tool_input.filePath
      file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.filePath // ""' 2>/dev/null)
      # Copilot cloud/CLI: toolArgs is a JSON string containing filePath
      if [ -z "$file_path" ]; then
        file_path=$(printf '%s' "$input" | jq -r 'if .toolArgs then (.toolArgs | fromjson | .filePath // .file_path // "") else "" end' 2>/dev/null)
      fi
    elif command -v python3 >/dev/null 2>&1; then
      file_path=$(printf '%s' "$input" | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
    tn = d.get("tool_name") or d.get("toolName") or ""
    if tn and tn not in ("Write","Edit"):
        sys.exit(0)
    ti = d.get("tool_input") or {}
    fp = ti.get("file_path") or ti.get("filePath") or ""
    if not fp and d.get("toolArgs"):
        try:
            ta = json.loads(d["toolArgs"])
            fp = ta.get("filePath") or ta.get("file_path") or ""
        except Exception:
            pass
    print(fp or "")
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
