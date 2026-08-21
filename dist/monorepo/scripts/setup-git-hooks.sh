#!/usr/bin/env bash
# Installs or runs the opt-in consumer pre-commit convenience net. Bypassable with --no-verify;
# this is not enforcement. Scan mode invokes the shipped guard so its patterns cannot drift.
set -euo pipefail

target="."
mode="install"
while [ $# -gt 0 ]; do
  case "$1" in
    --scan) mode="scan"; shift ;;
    --check-only) mode="check"; shift ;;
    --target) target="${2:-}"; shift 2 ;;
    -h|--help) echo "Usage: bash scripts/setup-git-hooks.sh [--target PATH] [--check-only|--scan]"; exit 0 ;;
    *) target="$1"; shift ;;
  esac
done
[ -d "$target" ] || { echo "Git-hook setup refused: target '$target' is not a directory." >&2; exit 2; }
repo_root=$(git -C "$target" rev-parse --show-toplevel 2>/dev/null) || {
  echo "Git-hook setup refused: git could not examine '$target' as a repository." >&2; exit 2;
}

scan_staged() {
  guard="$repo_root/.claude/hooks/guard.sh"
  [ -f "$guard" ] || { echo 'COMMIT REFUSED: the shipped guard.sh was not found.' >&2; exit 1; }
  names_file=$(mktemp) || { echo 'COMMIT REFUSED: could not create a staged-path snapshot.' >&2; exit 1; }
  trap 'rm -f "$names_file"' EXIT
  git -C "$repo_root" diff --cached --name-only --diff-filter=ACMR -z -- > "$names_file" || {
    echo 'COMMIT REFUSED: git could not list staged paths.' >&2; exit 1;
  }
  refused=0
  while IFS= read -r -d '' name; do
    additions=$(git -C "$repo_root" diff --cached --no-ext-diff --no-color --unified=0 -- "$name" |
      awk 'BEGIN{h=0} /^@@/{h=1;next} h && /^\+/ && !/^\+\+\+/{sub(/^\+/,"");print}') || {
        echo "COMMIT REFUSED: git could not read staged additions for '$name'." >&2; refused=1; continue;
      }
    [ -n "$additions" ] || continue
    if command -v jq >/dev/null 2>&1; then
      event=$(jq -cn --arg fp "$name" --arg content "$additions" '{tool_name:"Write",tool_input:{file_path:$fp,content:$content}}')
    else
      python_host=""
      for candidate in python3 python py; do
        if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import json' >/dev/null 2>&1; then python_host="$candidate"; break; fi
      done
      if [ -z "$python_host" ]; then
        echo 'COMMIT REFUSED: jq or a working Python is required to pass staged additions to the shipped guard.' >&2; refused=1; continue
      fi
      event=$(printf '%s' "$additions" | "$python_host" -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1],"content":sys.stdin.read()}}))' "$name")
    fi
    if ! output=$(printf '%s' "$event" | bash "$guard" 2>&1); then
      printf '%s\n' "$output" >&2
      refused=1
    fi
  done < "$names_file"
  [ "$refused" -eq 0 ] || exit 1
}

if [ "$mode" = scan ]; then scan_staged; exit 0; fi

found=""
if hooks_path=$(git -C "$repo_root" config --get core.hooksPath); then found="core.hooksPath=$hooks_path"; else
  code=$?; [ "$code" -eq 1 ] || { echo 'Git-hook setup refused: git could not examine core.hooksPath.' >&2; exit 2; }
fi
git_dir=$(git -C "$repo_root" rev-parse --git-dir) || { echo 'Git-hook setup refused: git could not resolve the git directory.' >&2; exit 2; }
case "$git_dir" in /*) ;; *) git_dir="$repo_root/$git_dir" ;; esac
hook_path="$git_dir/hooks/pre-commit"
[ ! -e "$hook_path" ] || found="${found:+$found; }existing pre-commit hook at $hook_path"
[ ! -d "$repo_root/.husky" ] || found="${found:+$found; }husky directory at $repo_root/.husky"
if [ -n "$found" ]; then echo "Git-hook setup refused: $found. Nothing was written." >&2; exit 3; fi
[ "$mode" != check ] || { echo 'Git-hook setup preflight passed; nothing was written.'; exit 0; }

mkdir -p "$(dirname "$hook_path")"
cat > "$hook_path" <<'HOOK'
#!/bin/sh
# AI Tech Lead opt-in convenience net. Bypassable with git commit --no-verify; not enforcement.
repo_root=$(git rev-parse --show-toplevel) || exit 1
exec bash "$repo_root/scripts/setup-git-hooks.sh" --target "$repo_root" --scan
HOOK
chmod +x "$hook_path"
echo "Installed opt-in pre-commit convenience net at $hook_path. It is bypassable with --no-verify and is not enforcement."
