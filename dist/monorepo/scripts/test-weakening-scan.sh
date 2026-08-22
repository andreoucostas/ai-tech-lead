#!/usr/bin/env bash
# Reports assertion-shaped removals in test-file diffs for review.
# Usage: bash scripts/test-weakening-scan.sh [<git-ref-range>]
# With no range, inspects staged changes. This is an advisory signal and always exits 0.
# LIMIT, stated because someone will otherwise read this as a detector: it counts assertion-shaped
# LINES, so three assertions collapsed onto one line and then deleted register as a single removal,
# and a rewrite that keeps the line count while gutting what is asserted registers as nothing at all.
# That is inherent to a diff-line heuristic, not a bug to fix -- distinguishing a weakened assertion
# from a legitimately refactored one needs intent, which no rule available here can read.
set -u

range=${1:-}
tmp_names=${TMPDIR:-/tmp}/test-weakening-names.$$
tmp_counts=${TMPDIR:-/tmp}/test-weakening-counts.$$
trap 'rm -f "$tmp_names" "$tmp_counts"' EXIT HUP INT TERM

if [ -n "$range" ]; then
  git diff "$range" --name-only --diff-filter=ACDMRTUXB -- >"$tmp_names" 2>/dev/null
else
  git diff --cached --name-only --diff-filter=ACDMRTUXB -- >"$tmp_names" 2>/dev/null
fi

signals=""
if [ -f "$tmp_names" ]; then
  while IFS= read -r path; do
    case "$path" in
      *Tests.cs|*.spec.ts|*.Tests.ps1|tests/*|*/tests/*) ;;
      *) continue ;;
    esac

    if [ -n "$range" ]; then
      git diff "$range" --unified=0 --no-ext-diff --no-color -- "$path" 2>/dev/null
    else
      git diff --cached --unified=0 --no-ext-diff --no-color -- "$path" 2>/dev/null
    fi | awk '
      /^---/ || /^\+\+\+/ { next }
      /^-/ && substr($0,2) ~ /Assert|expect[[:space:]]*\(|Should|\.Verify[[:space:]]*\(|\[(Fact|Test)([^[:alnum:]_]]|$)|(^|[^[:alnum:]_]])it[[:space:]]*\(|(^|[^[:alnum:]_]])describe[[:space:]]*\(/ { removed++ }
      /^\+/ && substr($0,2) ~ /Assert|expect[[:space:]]*\(|Should|\.Verify[[:space:]]*\(|\[(Fact|Test)([^[:alnum:]_]]|$)|(^|[^[:alnum:]_]])it[[:space:]]*\(|(^|[^[:alnum:]_]])describe[[:space:]]*\(/ { added++ }
      END { print removed + 0, added + 0 }
    ' >"$tmp_counts"

    if read removed added <"$tmp_counts"; then
      net=$((added - removed))
      if [ "$net" -lt 0 ]; then
        signals="${signals}  ${path}: removed ${removed}, added ${added}, net ${net}
"
      fi
    fi
  done <"$tmp_names"
fi

if [ -z "$signals" ]; then
  echo 'Test-weakening advisory: nothing qualifies.'
else
  echo 'Test-weakening advisory - review assertion-shaped removals:'
  printf '%s' "$signals"
  echo 'This reviewable signal can be defeated by ignoring it; it is not enforcement.'
fi

exit 0
