#!/usr/bin/env bash
# PostToolUse hook — append every AI-assisted file write to .claude/ai-audit.log.
# Format: ISO-8601-UTC TAB git-branch TAB file-path
# Satisfies SR 11-7 / DORA traceability requirements for AI tooling in regulated environments.
# Tool surfaces handled:
#   Claude Code (CLI + VS Code extension)  — tool_name in {Write,Edit}; path at tool_input.file_path
#   GitHub Copilot (cloud agent + CLI)     — toolName  in {edit,create}; path at toolArgs.filePath (object)

set -u

# Parse file_path from stdin (mirrors post-write.sh parsing logic).
file_path=""
if [ ! -t 0 ]; then
  input=$(cat)
  if [ -n "$input" ]; then
    if command -v jq >/dev/null 2>&1; then
      tool_name=$(printf '%s' "$input" | jq -r '.tool_name // .toolName // ""' 2>/dev/null)
      case "$tool_name" in
        Write|Edit|edit|create|"") ;;
        *) exit 0 ;;
      esac
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

# Skip the audit log itself and build artefacts.
case "$file_path" in
  *ai-audit.log|*/obj/*|*/bin/*) exit 0 ;;
esac

branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Normalise to a repo-relative path so the committed log stays portable and does not leak
# local absolute paths. cwd is the repo root. GNU realpath has --relative-to (test it, since
# BSD/macOS realpath does not); fall back to python3 (no existence requirement), then to the
# original path so a non-existent/cross-fs path is never logged blank.
rel="$file_path"
if command -v realpath >/dev/null 2>&1 && realpath --relative-to=. "$file_path" >/dev/null 2>&1; then
  rel=$(realpath --relative-to=. "$file_path" 2>/dev/null) || rel="$file_path"
elif command -v python3 >/dev/null 2>&1; then
  rel=$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1]))' "$file_path" 2>/dev/null) || rel="$file_path"
fi
[ -z "$rel" ] && rel="$file_path"

printf "%s\t%s\t%s\n" "$timestamp" "$branch" "$rel" >> .claude/ai-audit.log

exit 0
