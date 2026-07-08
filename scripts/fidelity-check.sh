#!/usr/bin/env bash
# Phase 2/3 fidelity gate (bash): compare dist/<mode> to the FROZEN baseline, EOL-normalized.
# The baseline is the full 138-file legacy/<mode> tree captured at the `pre-restructure` tag
# (== the freeze-v0.25.5 content) — NOT the working legacy/ dir, which shrinks as files are
# extracted during Phase 2. Reports match / mismatch / missing-in-dist / extra-in-dist; this is
# the live Phase-2 progress meter and becomes the Phase-3 zero-behaviour-change proof.
#   Usage: fidelity-check.sh {dotnet|angular} [baseline-ref]   (baseline-ref default: pre-restructure)
set -uo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-}"; REFSPEC="${2:-pre-restructure}"
case "$MODE" in dotnet|angular) ;; *) echo "usage: fidelity-check.sh {dotnet|angular} [ref]" >&2; exit 2;; esac
DIST="dist/$MODE"
[ -d "$DIST" ] || { echo "no $DIST — run scripts/build.sh $MODE first" >&2; exit 2; }

# Materialise the frozen baseline for this stack from git.
REF="$(mktemp -d)"; trap 'rm -rf "$REF"' EXIT
if ! git archive "$REFSPEC" "legacy/$MODE" 2>/dev/null | tar -x -C "$REF" 2>/dev/null; then
  echo "could not archive legacy/$MODE from $REFSPEC" >&2; exit 2
fi
BASE="$REF/legacy/$MODE"
[ -d "$BASE" ] || { echo "baseline legacy/$MODE not found at $REFSPEC" >&2; exit 2; }

match=0; mism=0; missing=0; extra=0
while IFS= read -r rel; do
  d="$DIST/$rel"; b="$BASE/$rel"
  if [ ! -f "$d" ]; then missing=$((missing+1)); continue; fi
  if diff -q <(tr -d '\r' < "$b") <(tr -d '\r' < "$d") >/dev/null 2>&1; then
    match=$((match+1))
  else
    mism=$((mism+1)); echo "MISMATCH $rel"
  fi
done < <(cd "$BASE" && find . -type f | sed 's#^\./##')

while IFS= read -r rel; do
  [ -f "$BASE/$rel" ] || { extra=$((extra+1)); echo "EXTRA    $rel"; }
done < <(cd "$DIST" && find . -type f | sed 's#^\./##')

total=$(cd "$BASE" && find . -type f | wc -l)
echo "--- $MODE @ $REFSPEC: match=$match mismatch=$mism missing=$missing extra=$extra (of $total)"
# Non-zero only on real drift (mismatch/extra). During Phase 2, missing = not-yet-extracted.
[ "$mism" -eq 0 ] && [ "$extra" -eq 0 ]
