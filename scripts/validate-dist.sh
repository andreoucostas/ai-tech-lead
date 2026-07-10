#!/usr/bin/env bash
# ai-tech-lead dist validator (bash twin; .ps1 twin is validate-dist.ps1). Validates an
# ALREADY-COMPOSED dist/<mode> tree — it does NOT rebuild it (see scripts/build.sh for that).
# Five checks, each with a clear OK/FAIL line:
#   1. no unresolved @stack:NAME markers survive anywhere in the dist (composer leftovers)
#   2. every *.json in the dist parses
#   3. `bash -n` passes on every *.sh in the dist
#   4. PowerShell AST parse is clean on every *.ps1 in the dist (invokes pwsh/powershell)
#   5. the dist's OWN template-checks suite passes, run from inside the dist dir
# Exit 0 = all checks passed. Exit 1 = at least one check failed. Exit 2 = usage error, missing
# dist, or a required tool (JSON parser / bash / PowerShell host) is unavailable — these are
# reported as FATAL and never silently skipped.
#   Usage: validate-dist.sh {dotnet|angular|monorepo} [dist-root]
#   dist-root defaults to "dist" resolved under the repo root (scripts/..). Pass an explicit path
#   to validate a scratch copy instead (e.g. to plant failure fixtures without touching dist/).
set -uo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-}"
case "$MODE" in dotnet|angular|monorepo) ;; *) echo "usage: validate-dist.sh {dotnet|angular|monorepo} [dist-root]" >&2; exit 2;; esac
DISTROOT="${2:-dist}"
DIST="$DISTROOT/$MODE"
[ -d "$DIST" ] || { echo "no $DIST — run scripts/build.sh $MODE first" >&2; exit 2; }

failed=0
fail() { echo "FAIL: $1"; failed=$((failed+1)); }
ok()   { echo "OK:   $1"; }

# --- 1. no unresolved @stack markers ------------------------------------------------------------
markers=$(grep -rIlE '@stack:[A-Za-z0-9_-]+' "$DIST" 2>/dev/null || true)
if [ -n "$markers" ]; then
  fail "unresolved @stack markers in:$(printf ' %s' $markers)"
else
  ok "no unresolved @stack markers in $DIST."
fi

# --- 2. every *.json parses -----------------------------------------------------------------------
# Prefer python3 (matches the .ps1 twin's ConvertFrom-Json more closely: full parse, not just
# lexing); fall back to jq. Neither present is a hard FATAL, not a silent skip.
JSON_TOOL=""
if python3 -c 'import json' >/dev/null 2>&1; then JSON_TOOL="python3"
elif command -v jq >/dev/null 2>&1; then JSON_TOOL="jq"
else
  echo "FATAL: neither python3 nor jq is available to validate *.json files — install one." >&2
  exit 2
fi
jsonfails=""
while IFS= read -r f; do
  if [ "$JSON_TOOL" = "python3" ]; then
    python3 -c 'import json,sys
json.load(open(sys.argv[1], encoding="utf-8"))' "$f" >/dev/null 2>&1 || jsonfails="$jsonfails $f"
  else
    jq empty "$f" >/dev/null 2>&1 || jsonfails="$jsonfails $f"
  fi
done < <(find "$DIST" -name '*.json' -type f)
if [ -n "$jsonfails" ]; then fail "invalid JSON ($JSON_TOOL):$jsonfails"; else ok "all *.json files parse ($JSON_TOOL)."; fi

# --- 3. bash -n on every *.sh ----------------------------------------------------------------------
command -v bash >/dev/null 2>&1 || { echo "FATAL: bash is not available to syntax-check *.sh files." >&2; exit 2; }
shfails=""
while IFS= read -r f; do
  bash -n "$f" 2>/dev/null || shfails="$shfails $f"
done < <(find "$DIST" -name '*.sh' -type f)
if [ -n "$shfails" ]; then fail "bash syntax errors in:$shfails"; else ok "all *.sh files parse cleanly (bash -n)."; fi

# --- 4. PowerShell AST parse on every *.ps1 ---------------------------------------------------------
PWSH=""
if command -v pwsh >/dev/null 2>&1; then PWSH="pwsh"
elif command -v powershell >/dev/null 2>&1; then PWSH="powershell"
elif command -v powershell.exe >/dev/null 2>&1; then PWSH="powershell.exe"
else
  echo "FATAL: neither pwsh nor powershell is available to parse *.ps1 files." >&2
  exit 2
fi
ps1fails=""
while IFS= read -r f; do
  # NOTE: positional args after `pwsh -Command '<script>'` do NOT bind to $args (they're silently
  # dropped) — pass the path via an env var instead so quoting/argument-passing is not a concern.
  VALIDATE_DIST_PS1_FILE="$f" "$PWSH" -NoProfile -NonInteractive -Command '
    $e = $null
    [System.Management.Automation.Language.Parser]::ParseFile($env:VALIDATE_DIST_PS1_FILE, [ref]$null, [ref]$e) | Out-Null
    if ($e) { exit 1 } else { exit 0 }
  ' >/dev/null 2>&1 || ps1fails="$ps1fails $f"
done < <(find "$DIST" -name '*.ps1' -type f)
if [ -n "$ps1fails" ]; then fail "PS syntax errors in:$ps1fails"; else ok "all *.ps1 files parse cleanly ($PWSH)."; fi

# --- 5. the dist's own template-checks suite --------------------------------------------------------
TC="$DIST/scripts/template-checks.sh"
if [ ! -f "$TC" ]; then
  fail "missing $TC — cannot run the dist's own template-checks suite."
else
  tcout=$(bash "$TC" 2>&1); tcstatus=$?
  echo "$tcout" | sed 's/^/  [template-checks] /'
  if [ "$tcstatus" -ne 0 ]; then
    fail "$DIST/scripts/template-checks.sh failed (exit $tcstatus) — see [template-checks] lines above."
  else
    ok "$DIST/scripts/template-checks.sh passed."
  fi
fi

echo ""
if [ "$failed" -gt 0 ]; then echo "$failed dist validation check(s) FAILED for $DIST."; exit 1; fi
echo "All dist validation checks passed for $DIST."
exit 0
