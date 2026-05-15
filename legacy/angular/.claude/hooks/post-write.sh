#!/usr/bin/env bash
# PostToolUse hook — incremental tsc --noEmit after a file write/edit on .ts files in src/.
# Tool surfaces handled:
#   Claude Code (CLI + VS Code extension)  — tool_name in {Write,Edit}; path at tool_input.file_path
#   GitHub Copilot (cloud agent + CLI)     — toolName  in {edit,create}; path at toolArgs.filePath (object, not JSON string)
# Adds a 5-second throttle so a burst of writes triggers one type-check rather than one per file.

set -u

mkdir -p .claude/.state 2>/dev/null

# Resolve file path: stdin tool input first, env var fallback.
file_path=""
if [ ! -t 0 ]; then
  input=$(cat)
  if [ -n "$input" ]; then
    if command -v jq >/dev/null 2>&1; then
      # Tool-name filter — Claude Code uses settings.json matcher; Copilot does not, so filter here.
      # Accept lowercase Copilot names plus empty (older payloads).
      tool_name=$(printf '%s' "$input" | jq -r '.tool_name // .toolName // ""' 2>/dev/null)
      case "$tool_name" in
        Write|Edit|edit|create|"") ;;
        *) exit 0 ;;
      esac
      # Try Claude Code's tool_input.file_path, then Copilot's toolArgs.* (which is a parsed object,
      # not a JSON string — do not use fromjson).
      file_path=$(printf '%s' "$input" | jq -r '
        .tool_input.file_path
        // .tool_input.filePath
        // .toolArgs.filePath
        // .toolArgs.file_path
        // .toolArgs.path
        // ""
      ' 2>/dev/null)
    elif command -v python3 >/dev/null 2>&1; then
      file_path=$(printf '%s' "$input" | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
    tn = d.get("tool_name") or d.get("toolName") or ""
    if tn and tn not in ("Write","Edit","edit","create"):
        sys.exit(0)
    ti = d.get("tool_input") or {}
    fp = ti.get("file_path") or ti.get("filePath") or ""
    if not fp:
        ta = d.get("toolArgs") or {}
        if isinstance(ta, str):
            try: ta = json.loads(ta)
            except Exception: ta = {}
        fp = ta.get("filePath") or ta.get("file_path") or ta.get("path") or ""
    print(fp or "")
except Exception:
    pass' 2>/dev/null)
    fi
  fi
fi
[ -z "$file_path" ] && file_path="${CLAUDE_FILE_PATH:-}"
[ -z "$file_path" ] && exit 0

# Only check .ts files inside src/.
case "$file_path" in
  *.ts) ;;
  *) exit 0 ;;
esac
case "$file_path" in
  */src/*) ;;
  *) exit 0 ;;
esac

# Bail out cleanly if the workspace isn't installed yet.
[ -d node_modules ] || exit 0

# Throttle: skip if a check was started within the last 5 seconds.
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

npx --no-install tsc --noEmit --incremental --tsBuildInfoFile .claude/.state/tsbuildinfo 2>&1 | tail -20

exit 0
