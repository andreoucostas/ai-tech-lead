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
      file_path=$(printf '%s' "$input" | jq -r '
        .tool_input.file_path
        // .tool_input.filePath
        // .toolArgs.filePath
        // .toolArgs.file_path
        // .toolArgs.path
        // ""
      ' 2>/dev/null)
      content=$(printf '%s' "$input" | jq -r '
        [ .tool_input.content, .tool_input.new_string, .tool_input.newString, .tool_input.file_text, .tool_input.new_str, .tool_input.text,
          .toolArgs.content, .toolArgs.new_string, .toolArgs.newString, .toolArgs.file_text, .toolArgs.new_str, .toolArgs.text ]
        | map(select(. != null)) | join("\n")' 2>/dev/null)
      # Self-filter — Copilot's hooks.json has no matcher, so gate here. Mirror guard.*: known write
      # tools OR any tool carrying a file path + content (covers VS Code agent mode's camelCase tools,
      # which otherwise go unlogged; requiring content, not just a path, excludes read-style tools).
      case "$tool_name" in
        Write|Edit|edit|create|"") ;;
        *) { [ -n "$file_path" ] && [ -n "$content" ]; } || exit 0 ;;
      esac
    elif command -v python3 >/dev/null 2>&1; then
      file_path=$(printf '%s' "$input" | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
tn = d.get("tool_name") or d.get("toolName") or ""
ti = d.get("tool_input") or {}
ta = d.get("toolArgs") or {}
if isinstance(ta, str):
    try: ta = json.loads(ta)
    except Exception: ta = {}
fp = ti.get("file_path") or ti.get("filePath") or ta.get("filePath") or ta.get("file_path") or ta.get("path") or ""
parts = [ti.get("content"),ti.get("new_string"),ti.get("newString"),ti.get("file_text"),ti.get("new_str"),ti.get("text"),ta.get("content"),ta.get("new_string"),ta.get("newString"),ta.get("file_text"),ta.get("new_str"),ta.get("text")]
if tn and tn not in ("Write","Edit","edit","create") and not (fp and any(parts)):
    sys.exit(0)
print(fp or "")' 2>/dev/null)
    fi
  fi
fi
[ -z "$file_path" ] && file_path="${CLAUDE_FILE_PATH:-}"
[ -z "$file_path" ] && exit 0

# Skip the audit log itself and build artefacts.
case "$file_path" in
  *ai-audit.log|*/node_modules/*|*/dist/*|*/.angular/*|*/coverage/*) exit 0 ;;
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
