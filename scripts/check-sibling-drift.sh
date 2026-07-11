#!/usr/bin/env bash
# WSD-015 sibling-drift gate (bash twin; .ps1 twin: check-sibling-drift.ps1). Diff-scoped: for
# every src/stacks/{dotnet,angular}/{snippets,files}/<rest> path touched since <base-ref>, checks
# whether its src/stacks/monorepo/<kind>/<rest> sibling exists on disk and was NOT touched in the
# same range (and isn't covered by a 'Sibling-Reviewed:' commit trailer) -- meta-invariant #1's
# WSD-015 discipline: a stack snippet/file change with a monorepo sibling must review that sibling
# in the same task, not silently skip it. Core edits, one-sided snippets (no sibling on disk), and
# monorepo-only edits are unaffected -- this only fires on a two-file drift.
#
# Usage: check-sibling-drift.sh [base-ref]   (default base-ref: HEAD~1)
#
# Base resolution is deliberately loud-fail-open: if <base-ref> doesn't resolve to a commit
# (unknown/empty ref, an all-zeros SHA as GitHub sends on a force-push/branch-create push event,
# or HEAD~1 on a repo's root commit), the range is unknowable -- print a NOTICE to stdout and
# exit 0 rather than blocking every branch-create push.
#
# Override: any commit message body line in <range-start>..HEAD matching `Sibling-Reviewed: <val>`
# suppresses a violation when <val> is '*' (everything in-range is reviewed) or a substring of
# either the stack path or its sibling path. Reviewable in git history, unlike a warning nobody
# reads.
#
# Exit codes: 0 = no drift (including the loud-fail-open NOTICE case); 1 = drift found (one or
# more FAIL lines printed to stdout).
set -uo pipefail
cd "$(dirname "$0")/.."

BASE="${1-HEAD~1}"

BASE_SHA="$(git rev-parse --verify --quiet "${BASE}^{commit}" 2>/dev/null)"
if [ -z "$BASE_SHA" ]; then
  echo "NOTICE: sibling-drift check skipped (base '$BASE' unresolvable)"
  exit 0
fi

RANGE_START="$(git merge-base "$BASE_SHA" HEAD 2>/dev/null)"
[ -n "$RANGE_START" ] || RANGE_START="$BASE_SHA"

TOUCHED="$(git diff --name-only "$RANGE_START" HEAD)"
TRAILERS="$(git log "$RANGE_START..HEAD" --format=%B 2>/dev/null | sed -n 's/^Sibling-Reviewed:[[:space:]]*\(.\{1,\}\)$/\1/p')"

is_touched() {
  # exact-line membership test against $TOUCHED. No -q: under pipefail, grep -q's early exit
  # can SIGPIPE the printf on a large diff and turn a found match into pipeline status 141
  # (LEARNINGS 2026-07-09) -- reading to EOF keeps the exit code honest.
  printf '%s\n' "$TOUCHED" | grep -xF "$1" >/dev/null
}

is_suppressed() {
  # $1=stack path  $2=sibling path
  [ -n "$TRAILERS" ] || return 1
  while IFS= read -r trailer; do
    [ -n "$trailer" ] || continue
    [ "$trailer" = "*" ] && return 0
    case "$1" in *"$trailer"*) return 0 ;; esac
    case "$2" in *"$trailer"*) return 0 ;; esac
  done <<TRAILEREOF
$TRAILERS
TRAILEREOF
  return 1
}

fail=0
touched_count=0
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  case "$rel" in
    src/stacks/dotnet/snippets/?*|src/stacks/dotnet/files/?*|src/stacks/angular/snippets/?*|src/stacks/angular/files/?*)
      ;;
    *) continue ;;
  esac
  touched_count=$((touched_count + 1))

  stack="${rel#src/stacks/}"               # e.g. dotnet/snippets/<rest>
  kind="${stack#*/}"; kind="${kind%%/*}"    # snippets|files
  rest="${stack#*/*/}"                      # <rest>
  sibling="src/stacks/monorepo/$kind/$rest"

  [ -f "$sibling" ] || continue
  is_touched "$sibling" && continue
  is_suppressed "$rel" "$sibling" && continue

  # ASCII-only runtime output: the meta suite byte-compares this line across twins, and the
  # .sh twin's stdout crosses a console-codepage decode on Windows PS 5.1 hosts.
  echo "FAIL: $rel changed but its monorepo sibling $sibling was not touched in the same range (WSD-015 -- update the sibling or add a 'Sibling-Reviewed: <path-or-*>' commit trailer)"
  fail=1
done <<TOUCHEDEOF
$TOUCHED
TOUCHEDEOF

if [ "$fail" -eq 1 ]; then
  exit 1
fi

if [ "$touched_count" -eq 0 ]; then
  echo "OK: no src/stacks/{dotnet,angular} paths touched."
else
  echo "OK: no monorepo-sibling drift in $touched_count touched src/stacks path(s)."
fi
exit 0
