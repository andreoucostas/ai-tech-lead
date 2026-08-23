#!/usr/bin/env bash
# AI Tech Lead Framework — root installer wrapper.
# Usage: bash install.sh [--stack dotnet|angular|monorepo] [--git-hooks] [--dry-run] [--allow-downgrade] /path/to/target-repo
#
# Thin dispatcher only: it selects a stack, then delegates to
# dist/<stack>/scripts/install.sh, which does all the real work (greenfield / brownfield /
# update detection, the copy, the pwsh->bash hook rewiring, ...). This wrapper adds NO install
# logic of its own — stack selection and delegation, nothing more.
#
# Stack resolution (first match wins):
#   1. --stack flag       explicit; always wins.
#   2. update stamp       target/.claude/framework-version.json exists -> use its "template".
#   3. auto-detect        *.csproj or *.sln -> dotnet ; angular.json -> angular ;
#                         both -> monorepo (mixed repo: both stacks' rails install together).
#                         Searched in the target root plus two directory levels below it.
#   4. warehouse-only     refuse: this release does not certify solution-free adoption;
#                          --stack dotnet remains an informed override.
#   5. nothing detected   error: pass --stack.
# Every error exits 2 with an actionable message.
set -euo pipefail

usage="Usage: bash install.sh [--stack dotnet|angular|monorepo] [--git-hooks] [--dry-run] [--allow-downgrade] /path/to/target-repo"
self_dir="$(cd "$(dirname "$0")" && pwd)"
find_cmd="find"
# Git Bash can inherit Windows' find.exe ahead of GNU find on PATH. Prefer the POSIX binary
# when available; /usr/bin/find is also the standard location on the supported Unix hosts.
[ -x /usr/bin/find ] && find_cmd="/usr/bin/find"

stack=""
git_hooks=0
dry_run=0
allow_downgrade=0
target=""
while [ $# -gt 0 ]; do
  case "$1" in
    --stack)   stack="${2:-}"; shift 2 ;;
    --stack=*) stack="${1#--stack=}"; shift ;;
    --git-hooks) git_hooks=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    --allow-downgrade) allow_downgrade=1; shift ;;
    -h|--help) echo "$usage"; exit 0 ;;
    -*)        echo "Unknown option: $1" >&2; echo "$usage" >&2; exit 2 ;;
    *)         if [ -z "$target" ]; then target="$1"; shift
               else echo "Unexpected extra argument: $1" >&2; echo "$usage" >&2; exit 2; fi ;;
  esac
done

if [ -z "$target" ]; then echo "$usage" >&2; exit 2; fi
[ -d "$target" ] || { echo "Target '$target' is not a directory." >&2; exit 2; }
tgt="$(cd "$target" && pwd)"

valid_stack() { [ "$1" = "dotnet" ] || [ "$1" = "angular" ] || [ "$1" = "monorepo" ]; }
warehouse_signals=()
get_warehouse_signals() {
  local signals category pattern matched f
  signals="$self_dir/dist/dotnet/scripts/warehouse-signals.tsv"; [ -f "$signals" ] || return 1; warehouse_signals=()
  files=$("$find_cmd" "$tgt" -type f \( -name '*.sql' -o -name '*.sqlproj' -o -name 'dbt_project.yml' -o -name '*.yml' -o -name '*.yaml' -o -name '*.json' \) ! -path '*/.git/*' ! -path '*/node_modules/*' ! -path '*/bin/*' ! -path '*/obj/*' ! -path '*/dist/*' 2>/dev/null | grep -Ei '\.sql(proj)?$|/dbt_project\.yml$|/(etl|pipelines?|warehouse|datafactory|synapse|dags?)/|/(pipeline|datafactory|synapse|dag)[^/]*\.(yml|yaml|json)$' || true)
  while IFS=$'\t' read -r category pattern; do case "$category" in ''|'#'*) continue;; esac; matched=0; while IFS= read -r f; do [ -n "$f" ]||continue; if { basename "$f"; cat "$f"; }|grep -Eiq "$pattern";then matched=1;break;fi; done <<EOF
$files
EOF
  [ "$matched" -eq 1 ] && warehouse_signals+=("$category"); done < "$signals"; [ "${#warehouse_signals[@]}" -ge 2 ]
}
warehouse_only_refusal() {
  local observed="${warehouse_signals[0]}" category
  for category in "${warehouse_signals[@]:1}"; do observed+=", $category"; done
  echo "Warehouse-only auto-detection refused: found warehouse signals: $observed" >&2
  echo "No *.csproj/*.sln or angular.json was found. This release does not certify solution-free adoption." >&2
  echo "Use --stack dotnet only as an informed override after confirming that the .NET lifecycle is appropriate." >&2
  exit 2
}

reason=""
if [ -n "$stack" ]; then
  valid_stack "$stack" || { echo "Unknown stack '$stack' (expected: dotnet, angular, or monorepo)." >&2; exit 2; }
  reason="--stack flag"
else
  vf="$tgt/.claude/framework-version.json"
  if [ -f "$vf" ]; then
    # Existing install: honour the stack it was installed with (update mode). The stamp's
    # "template" value already matches the dist mode names (dotnet / angular).
    tmpl="$(grep -o '"template"[[:space:]]*:[[:space:]]*"[^"]*"' "$vf" | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)".*/\1/')"
    if [ -z "$tmpl" ]; then
      echo "Existing install at '$tgt', but .claude/framework-version.json has no readable \"template\" value — pass --stack dotnet|angular|monorepo." >&2; exit 2
    fi
    valid_stack "$tmpl" || { echo "Existing install names an unknown stack \"$tmpl\" in .claude/framework-version.json — pass --stack dotnet|angular|monorepo." >&2; exit 2; }
    stack="$tmpl"
    reason="update stamp (.claude/framework-version.json template=$tmpl)"
  else
    # Auto-detect from build markers in the target root + two levels below (maxdepth 3:
    # depth 1 = root files, depth 3 = two subdirectory levels down).
    has_dotnet=0; has_angular=0
    if [ -n "$("$find_cmd" "$tgt" -maxdepth 3 \( -name '*.csproj' -o -name '*.sln' \) -print -quit 2>/dev/null)" ]; then has_dotnet=1; fi
    if [ -n "$("$find_cmd" "$tgt" -maxdepth 3 -name 'angular.json' -print -quit 2>/dev/null)" ]; then has_angular=1; fi
    if [ "$has_dotnet" -eq 1 ] && [ "$has_angular" -eq 1 ]; then
      stack="monorepo"; reason="auto-detected (found both *.csproj/*.sln and angular.json — mixed repo)"
    elif [ "$has_dotnet" -eq 1 ]; then stack="dotnet";  reason="auto-detected (found *.csproj/*.sln)"
    elif [ "$has_angular" -eq 1 ]; then stack="angular"; reason="auto-detected (found angular.json)"
    elif get_warehouse_signals; then
      warehouse_only_refusal
    else
      echo "Could not determine the stack for '$tgt': no *.csproj/*.sln and no angular.json in the target root or two levels below." >&2
      echo "Pass it explicitly: --stack dotnet|angular|monorepo." >&2
      exit 2
    fi
  fi
fi

delegate="$self_dir/dist/$stack/scripts/install.sh"
[ -f "$delegate" ] || { echo "Internal error: expected installer not found at $delegate" >&2; exit 2; }

echo "Stack: $stack (via $reason)"
echo "Delegating to dist/$stack/scripts/install.sh ..."
echo
delegate_args=()
[ "$git_hooks" -eq 1 ] && delegate_args+=(--git-hooks)
[ "$dry_run" -eq 1 ] && delegate_args+=(--dry-run)
[ "$allow_downgrade" -eq 1 ] && delegate_args+=(--allow-downgrade)
exec bash "$delegate" "${delegate_args[@]}" "$tgt"
