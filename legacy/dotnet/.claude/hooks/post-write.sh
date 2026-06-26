#!/usr/bin/env bash
# PostToolUse hook — incremental dotnet build after a file write/edit on .cs files.
# Tool surfaces handled:
#   Claude Code (CLI + VS Code extension)  — tool_name in {Write,Edit}; path at tool_input.file_path
#   GitHub Copilot (cloud agent + CLI)     — toolName  in {edit,create}; path at toolArgs.filePath (object, not JSON string)
# Throttled to one build per 60 s to avoid stomping on a long-running compile.

set -u

mkdir -p .claude/.state 2>/dev/null

# Resolve file path: stdin tool input first, env var fallback.
file_path=""
tool_name=""
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

# Only build for .cs files.
case "$file_path" in
  *.cs) ;;
  *) exit 0 ;;
esac

# Bail cleanly if no dotnet CLI on PATH.
command -v dotnet >/dev/null 2>&1 || exit 0

# Discover the build target: nearest .sln up the tree (build the whole solution so cross-project
# breaks are caught), falling back to the nearest .csproj. The old root-cwd build silently built
# nothing when the solution lived in a subdirectory.
dir=$(CDPATH= cd -- "$(dirname -- "$file_path")" 2>/dev/null && pwd) || exit 0
target=""
probe="$dir"
while [ -n "$probe" ]; do
  sln=$(find "$probe" -maxdepth 1 -name '*.sln' -type f 2>/dev/null | head -n1)
  if [ -n "$sln" ]; then target="$sln"; break; fi
  parent=$(dirname -- "$probe")
  [ "$parent" = "$probe" ] && break
  probe="$parent"
done
if [ -z "$target" ]; then
  probe="$dir"
  while [ -n "$probe" ]; do
    proj=$(find "$probe" -maxdepth 1 -name '*.csproj' -type f 2>/dev/null | head -n1)
    if [ -n "$proj" ]; then target="$proj"; break; fi
    parent=$(dirname -- "$probe")
    [ "$parent" = "$probe" ] && break
    probe="$parent"
  done
fi
[ -z "$target" ] && exit 0

# Throttle: skip if a build was started within the last 60 seconds (dotnet build is slow; tighter
# throttle just stomps on the in-flight build with a duplicate).
stamp=.claude/.state/last-build-ts
if [ -f "$stamp" ]; then
  last=$(cat "$stamp" 2>/dev/null)
  now=$(date +%s 2>/dev/null || echo 0)
  if [ -n "$last" ] && [ "$now" -gt 0 ]; then
    delta=$((now - last))
    if [ "$delta" -lt 60 ]; then
      exit 0
    fi
  fi
fi
date +%s > "$stamp" 2>/dev/null

# On success: stay silent — emitting the build summary every successful write wastes context tokens.
build_output=$(dotnet build "$target" --no-restore --verbosity quiet 2>&1)
[ $? -eq 0 ] && exit 0

# Clear the throttle stamp so the next write rebuilds instead of skipping a known-broken build.
rm -f "$stamp" 2>/dev/null

msg="## dotnet build failed — fix before continuing:
$(printf '%s\n' "$build_output" | tail -20)"

# Copilot consumes postToolUse feedback as JSON additionalContext on stdout (exit 0).
case "$tool_name" in
  edit|create)
    if command -v jq >/dev/null 2>&1; then
      printf '%s' "$msg" | jq -Rs '{additionalContext: .}'
    elif command -v python3 >/dev/null 2>&1; then
      printf '%s' "$msg" | python3 -c 'import json,sys; print(json.dumps({"additionalContext": sys.stdin.read()}))'
    fi
    exit 0
    ;;
esac

# Claude Code feeds PostToolUse output to the model only via exit 2 + stderr;
# exit-0 stdout goes to the debug log, so a plain echo here is silently dropped.
printf '%s\n' "$msg" >&2
exit 2
