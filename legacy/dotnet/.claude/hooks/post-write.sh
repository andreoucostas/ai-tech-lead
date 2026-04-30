#!/usr/bin/env bash
# PostToolUse hook — incremental dotnet build after Write/Edit on .cs files.
# Handles three input formats:
#   Claude Code          — tool_input.file_path  (snake_case, matcher filters tool)
#   VS Code Copilot      — tool_input.filePath   (camelCase, no matcher → name-filter in script)
#   Copilot cloud/CLI    — toolArgs JSON string  (toolName + toolArgs at top level)
# Adds a 5-second throttle so a burst of writes triggers one build rather than one per file.

set -u

mkdir -p .claude/.state 2>/dev/null

# Resolve file path: stdin tool_input first, env var fallback.
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

# Only build for .cs files.
case "$file_path" in
  *.cs) ;;
  *) exit 0 ;;
esac

# Throttle: skip if a build was started within the last 5 seconds.
stamp=.claude/.state/last-build-ts
if [ -f "$stamp" ]; then
  last=$(cat "$stamp" 2>/dev/null)
  now=$(date +%s 2>/dev/null || echo 0)
  if [ -n "$last" ] && [ "$now" -gt 0 ]; then
    delta=$((now - last))
    if [ "$delta" -lt 5 ]; then
      exit 0
    fi
  fi
fi
date +%s > "$stamp" 2>/dev/null

dotnet build --no-restore --verbosity quiet 2>&1 | tail -20

exit 0
