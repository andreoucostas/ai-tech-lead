#!/usr/bin/env bash
# AI Tech Lead Framework — root installer wrapper.
# Usage: bash install.sh [--stack dotnet|angular|monorepo] /path/to/target-repo
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
#   4. nothing detected   error: pass --stack.
# Every error exits 2 with an actionable message.
set -euo pipefail

usage="Usage: bash install.sh [--stack dotnet|angular|monorepo] /path/to/target-repo"
self_dir="$(cd "$(dirname "$0")" && pwd)"

stack=""
target=""
while [ $# -gt 0 ]; do
  case "$1" in
    --stack)   stack="${2:-}"; shift 2 ;;
    --stack=*) stack="${1#--stack=}"; shift ;;
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
    if [ -n "$(find "$tgt" -maxdepth 3 \( -name '*.csproj' -o -name '*.sln' \) -print -quit 2>/dev/null)" ]; then has_dotnet=1; fi
    if [ -n "$(find "$tgt" -maxdepth 3 -name 'angular.json' -print -quit 2>/dev/null)" ]; then has_angular=1; fi
    if [ "$has_dotnet" -eq 1 ] && [ "$has_angular" -eq 1 ]; then
      stack="monorepo"; reason="auto-detected (found both *.csproj/*.sln and angular.json — mixed repo)"
    elif [ "$has_dotnet" -eq 1 ]; then stack="dotnet";  reason="auto-detected (found *.csproj/*.sln)"
    elif [ "$has_angular" -eq 1 ]; then stack="angular"; reason="auto-detected (found angular.json)"
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
exec bash "$delegate" "$tgt"
