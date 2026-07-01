#!/usr/bin/env bash
# AI Tech Lead deterministic framework checks — bash twin of template-checks.ps1.
# Exit 0 = pass, otherwise the failure count. Runs in the template repo (CI) and in consumer
# repos (invoked by docs-sync-check). Same checks as the .ps1 twin, minus the PS-syntax parse
# (no PowerShell host assumed here; the CI windows leg covers it).
set -u

# Anchor to the repo this script lives in (scripts/..), not the caller's cwd — running from
# elsewhere must never silently audit the wrong directory.
cd "$(dirname "$0")/.." || exit 1

failed=0
fail() { echo "FAIL: $1"; failed=$((failed+1)); }
ok()   { echo "OK:   $1"; }

# --- 1. Version-stamp sync -------------------------------------------------------------------
v_claude=""; v_json=""; v_log=""
[ -f CLAUDE.md ] && v_claude=$(head -10 CLAUDE.md | sed -n 's/^[[:space:]]*version:[[:space:]]*\([^[:space:]]*\).*/\1/p' | head -1)
[ -f .claude/framework-version.json ] && v_json=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .claude/framework-version.json | head -1)
[ -f CHANGELOG.md ] && v_log=$(grep -m1 -E '^## [0-9]+\.[0-9]+\.[0-9]+' CHANGELOG.md | sed -E 's/^## ([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
if [ -z "$v_claude" ]; then fail "CLAUDE.md has no version stamp in its header comment."
elif [ -z "$v_json" ]; then fail ".claude/framework-version.json missing or unparsable."
elif [ "$v_claude" != "$v_json" ]; then fail "version-stamp drift: CLAUDE.md says $v_claude, framework-version.json says $v_json."
elif [ -n "$v_log" ] && [ "$v_log" != "$v_json" ]; then fail "version-stamp drift: CHANGELOG.md head entry is $v_log, framework-version.json says $v_json."
else
  extra=""; [ -z "$v_log" ] && extra=" (no CHANGELOG.md — consumer repo, pair-check only)"
  ok "version stamps in sync ($v_claude)$extra."
fi

# --- 2. CLAUDE.md <-> AGENTS.md verbatim mirror ------------------------------------------------
# Section body: lines after the exact "## <name>" heading up to the next "## ", minus blank/--- lines
# and trailing whitespace.
section() { # $1=file $2=heading
  awk -v h="$2" '
    $0==h {flag=1; next}
    flag && /^## / {exit}
    flag { sub(/[ \t\r]+$/,""); if ($0!="" && $0!="---") print }
  ' "$1"
}
section1() { # $1=file
  awk '
    /^### 1\. Classify the intent/ {flag=1; next}
    flag && /^### / {exit}
    flag { sub(/[ \t\r]+$/,""); if ($0!="") print }
  ' "$1"
}
if [ -f CLAUDE.md ] && [ -f AGENTS.md ]; then
  for sec in "## Verification Rules" "## Leanness" "## SOLID" "## Boy Scout Rule"; do
    a=$(section CLAUDE.md "$sec"); b=$(section AGENTS.md "$sec")
    if [ -z "$a" ]; then fail "CLAUDE.md is missing section '$sec'."
    elif [ "$a" != "$b" ]; then fail "AGENTS.md section '$sec' is not a verbatim mirror of CLAUDE.md — run /generate-copilot."
    else ok "'$sec' mirrored verbatim."
    fi
  done
  s1c=$(section1 CLAUDE.md); s1a=$(section1 AGENTS.md)
  if [ -z "$s1c" ]; then fail 'CLAUDE.md has no "### 1. Classify the intent" block.'
  elif [ "$s1c" != "$s1a" ]; then fail "AGENTS.md Agentic Workflow §1 is not verbatim (this is the only routing surface Copilot has) — run /generate-copilot."
  else ok "Agentic Workflow §1 mirrored verbatim."
  fi
else
  fail "CLAUDE.md or AGENTS.md missing — cannot check mirror parity."
fi

# --- 3. copilot-instructions.md present and slim ----------------------------------------------
if [ ! -f .github/copilot-instructions.md ]; then
  fail ".github/copilot-instructions.md is missing — run /generate-copilot."
else
  n=$(wc -l < .github/copilot-instructions.md | tr -d ' ')
  if [ "$n" -gt 80 ]; then fail ".github/copilot-instructions.md is $n lines (limit 80) — regenerate slimmer."
  else ok ".github/copilot-instructions.md present ($n lines <= 80)."
  fi
fi

# --- 4. Framework .ps1 files carry a UTF-8 BOM -------------------------------------------------
nobom=""
for d in .claude/hooks scripts tests/hooks; do
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    first3=$(head -c3 "$f" | od -An -tx1 | tr -d ' \n')
    [ "$first3" = "efbbbf" ] || nobom="$nobom $f"
  done < <(find "$d" -name '*.ps1' -type f)
done
if [ -n "$nobom" ]; then fail "BOM missing on:$nobom"; else ok "all framework .ps1 files carry a UTF-8 BOM."; fi

# --- 5. Hook twin existence (.ps1 <-> .sh) -----------------------------------------------------
if [ -d .claude/hooks ]; then
  orphans=""
  for f in .claude/hooks/*.ps1; do [ -e "$f" ] || continue; [ -f "${f%.ps1}.sh" ] || orphans="$orphans $(basename "$f")"; done
  for f in .claude/hooks/*.sh;  do [ -e "$f" ] || continue; [ -f "${f%.sh}.ps1" ] || orphans="$orphans $(basename "$f")"; done
  if [ -n "$orphans" ]; then fail "hook twin missing for:$orphans"; else ok "every hook has its .ps1/.sh twin."; fi
fi

# --- 6. Bash syntax of framework .sh scripts ---------------------------------------------------
shfails=""
for d in .claude/hooks scripts tests/hooks; do
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    bash -n "$f" 2>/dev/null || shfails="$shfails $f"
  done < <(find "$d" -name '*.sh' -type f)
done
if [ -n "$shfails" ]; then fail "bash syntax errors in:$shfails"; else ok "all framework .sh files parse cleanly."; fi

echo ""
if [ "$failed" -gt 0 ]; then echo "$failed framework check(s) FAILED."; exit "$failed"; fi
echo "All deterministic framework checks passed."
exit 0
