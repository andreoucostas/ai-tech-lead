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
tool_name=""
if [ ! -t 0 ]; then
  input=$(cat)
  if [ -n "$input" ]; then
    SEP=$'\x1f'
    if command -v jq >/dev/null 2>&1; then
      tool_name=$(printf '%s' "$input" | jq -r '.tool_name // .toolName // ""' 2>/dev/null)
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
      content=$(printf '%s' "$input" | jq -r '
        [ .tool_input.content, .tool_input.new_string, .tool_input.newString, .tool_input.file_text, .tool_input.new_str, .tool_input.text,
          .toolArgs.content, .toolArgs.new_string, .toolArgs.newString, .toolArgs.file_text, .toolArgs.new_str, .toolArgs.text ]
        | map(select(. != null)) | join("\n")' 2>/dev/null)
      # Self-filter — Copilot's hooks.json has no matcher, so gate here. Mirror guard.*: known write
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

# Only check .ts files inside src/.
case "$file_path" in
  *.ts) ;;
  *) exit 0 ;;
esac
case "$file_path" in
  */src/*) ;;
  *) exit 0 ;;
esac

# Discover the workspace root: nearest ancestor holding an Angular tsconfig. Supports root,
# ClientApp/, and Nx apps/* layouts (the old root-cwd assumption silently skipped non-root ones).
dir=$(CDPATH= cd -- "$(dirname -- "$file_path")" 2>/dev/null && pwd) || exit 0
workspace=""
probe="$dir"
while [ -n "$probe" ]; do
  if [ -f "$probe/tsconfig.app.json" ] || [ -f "$probe/tsconfig.json" ]; then
    workspace="$probe"; break
  fi
  parent=$(dirname -- "$probe")
  [ "$parent" = "$probe" ] && break
  probe="$parent"
done
[ -z "$workspace" ] && exit 0

# Prefer tsconfig.app.json: a solution-style tsconfig.json (files:[], include:[], references)
# compiles nothing and exits 0 -- a silent false pass. tsconfig.app.json has the real sources.
if [ -f "$workspace/tsconfig.app.json" ]; then
  project=tsconfig.app.json
else
  project=tsconfig.json
fi

# Resolve tsc: node_modules in the workspace or hoisted to a monorepo root above it.
has_modules=""
mp="$workspace"
while [ -n "$mp" ]; do
  if [ -d "$mp/node_modules" ]; then has_modules=1; break; fi
  parent=$(dirname -- "$mp")
  [ "$parent" = "$mp" ] && break
  mp="$parent"
done
[ -z "$has_modules" ] && exit 0

# Per-workspace absolute state under the repo-root .state so monorepo apps neither clobber each
# other's incremental tsbuildinfo nor cross-suppress each other's throttle.
repo_root=$(pwd)
repo_state="$repo_root/.claude/.state"
mkdir -p "$repo_state" 2>/dev/null
rel="${workspace#"$repo_root"}"; rel="${rel#/}"
key=$(printf '%s' "$rel" | tr -c 'A-Za-z0-9' '_' | sed 's/_*$//')
[ -z "$key" ] && key=root
stamp="$repo_state/last-build-$key"
build_info="$repo_state/tsbuildinfo-$key"

# Throttle: skip if a check was started within the last 5 seconds.
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

# On success: stay silent — emitting type-check output every successful write wastes context tokens.
# Run from the workspace dir; the tsBuildInfoFile is an absolute repo-root path.
tsc_output=$( cd "$workspace" && npx --no-install tsc --noEmit -p "$project" --incremental --tsBuildInfoFile "$build_info" 2>&1 )
[ $? -eq 0 ] && exit 0

# Clear the throttle stamp so the next write re-checks instead of skipping a known-broken type-check.
rm -f "$stamp" 2>/dev/null

msg="## tsc --noEmit failed — fix before continuing:
$(printf '%s\n' "$tsc_output" | tail -20)"

# Surface per surface (mirror guard.sh). Claude Code is the only surface consuming exit 2 + stderr;
# its tools are PascalCase Edit/Write (and the ambiguous empty case routes here too, since its
# PostToolUse matcher only fires on Write|Edit).
case "$tool_name" in
  Edit|Write|"")
    printf '%s\n' "$msg" >&2
    exit 2
    ;;
esac

# Everything else — Copilot CLI (lowercase edit/create) AND VS Code agent mode (camelCase
# str_replace/insert/etc.) -- is sent the JSON additionalContext shape below, but a live sentinel
# canary (Copilot CLI 1.0.68, 2026-07-04) found the CLI model does NOT consume postToolUse stdout;
# this branch is emit-for-forward-compat only (see docs/enforcement-surfaces.md). VS Code unverified.
if command -v jq >/dev/null 2>&1; then
  printf '%s' "$msg" | jq -Rs '{additionalContext: .}'
elif command -v python3 >/dev/null 2>&1; then
  printf '%s' "$msg" | python3 -c 'import json,sys; print(json.dumps({"additionalContext": sys.stdin.read()}))'
fi
exit 0
