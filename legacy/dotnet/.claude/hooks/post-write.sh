#!/usr/bin/env bash
# PostToolUse hook — incremental dotnet build after a write/edit on build-relevant files
# (.cs sources + MSBuild/Razor inputs: .csproj/.sln/.props/.targets/.razor/.cshtml — B-19a).
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
    SEP=$'\x1f'
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
      # Self-filter -- Copilot's hooks.json has no matcher, so gate here. Mirror guard.*: known write
      # tools OR any tool carrying a file path + content (covers VS Code agent mode's camelCase tools;
      # requiring content, not just a path, excludes read-style tools).
      case "$tool_name" in
        Write|Edit|edit|create|"") ;;
        *) { [ -n "$file_path" ] && [ -n "$content" ]; } || exit 0 ;;
      esac
    elif command -v python3 >/dev/null 2>&1; then
      parsed=$(printf '%s' "$input" | python3 -c 'import json,sys
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
sys.stdout.write(tn + "\x1f" + (fp or ""))' 2>/dev/null)
      if [ -n "$parsed" ]; then
        tool_name=${parsed%%"$SEP"*}
        file_path=${parsed#*"$SEP"}
      fi
    fi
  fi
fi
[ -z "$file_path" ] && file_path="${CLAUDE_FILE_PATH:-}"
[ -z "$file_path" ] && exit 0

# Trigger on what `dotnet build` actually consumes (B-19a): sources plus MSBuild/Razor inputs.
# A broken .csproj/.sln/.props/.targets edit breaks the build as surely as a .cs edit; extensions
# the build doesn't read stay excluded -- a build cannot catch their breakage.
case "$file_path" in
  *.cs|*.csproj|*.sln|*.props|*.targets|*.razor|*.cshtml) ;;
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

# Surface per surface (mirror guard.sh). Claude Code is the only surface consuming exit 2 + stderr;
# its tools are PascalCase Edit/Write (and the ambiguous empty case routes here too, since its
# PostToolUse matcher only fires on Write|Edit).
case "$tool_name" in
  Edit|Write|"")
    printf '%s\n' "$msg" >&2
    exit 2
    ;;
esac

# Everything else -- Copilot CLI (lowercase edit/create) AND VS Code agent mode (camelCase
# str_replace/insert/etc.) -- is sent the JSON additionalContext shape below, but a live sentinel
# canary (Copilot CLI 1.0.68, 2026-07-04) found the CLI model does NOT consume postToolUse stdout;
# this branch is emit-for-forward-compat only (see docs/enforcement-surfaces.md). VS Code unverified.
if command -v jq >/dev/null 2>&1; then
  printf '%s' "$msg" | jq -Rs '{additionalContext: .}'
elif command -v python3 >/dev/null 2>&1; then
  printf '%s' "$msg" | python3 -c 'import json,sys; print(json.dumps({"additionalContext": sys.stdin.read()}))'
fi
exit 0
