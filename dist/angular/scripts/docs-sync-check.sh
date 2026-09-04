#!/usr/bin/env bash
# AI Tech Lead framework-state guardrail — host-agnostic.
# Exit 0 = pass, 1 = fail. Runs anywhere: GitHub Actions, Bitbucket Pipelines, Bamboo, Jenkins,
# a Bitbucket Data Center pre-receive hook, or locally. GitHub Actions calls this from
# .github/workflows/docs-sync-check.yml. For Bitbucket Data Center, invoke it from your CI/hook and
# optionally publish the result to the PR via the Code Insights API (see README "Running on
# Bitbucket Data Center").
set -u
# Anchor to the repo this script lives in (scripts/..), not the caller's cwd — running from
# elsewhere must never silently audit the wrong directory. Resolve $0 to an absolute path
# BEFORE cd (a relative $0 stops resolving once the cwd changes).
here=$(cd "$(dirname "$0")" && pwd)
cd "$here/.." || exit 1

# In the framework template repo the consumer-state checks (bootstrap markers, adoption pending)
# don't apply — but the deterministic framework checks DO. Skipping everything here is how
# version-stamp and mirror drift shipped unnoticed; run template-checks instead of going silent.
if [ -f ".template-repo" ]; then
  echo "Framework template repo (.template-repo present) — consumer-state checks don't apply;"
  echo "running the deterministic framework checks (scripts/template-checks.sh) instead."
  if bash "$here/template-checks.sh"; then
    template_status=0
  else
    template_status=$?
  fi
  if [ "$template_status" -eq 0 ]; then
    exit 0
  fi
  exit 1
fi

FAILED=0
fail() { echo "FAIL: $1"; FAILED=1; }
ok()   { echo "OK:   $1"; }

# 0. Install completeness. The enforcement matrix is load-bearing: CLAUDE.md points to it for
# the honest host guarantees. ci-integration.md is advisory and may be intentionally removed.
if [ ! -f "docs/enforcement-surfaces.md" ]; then
  fail "framework install incomplete: docs/enforcement-surfaces.md missing — reinstall from the template."
else
  ok "framework enforcement matrix present."
fi
if [ ! -f "docs/ci-integration.md" ]; then
  echo "NOTE: docs/ci-integration.md is missing — restore it from the template if you need the portable required-build recipe. (advisory — not a failure)"
fi

# 1. Adoption-pending marker — the installer detected pre-existing AI tooling that /adopt must consolidate.
if [ -f ".claude/adoption-pending.json" ]; then
  fail "adoption pending (.claude/adoption-pending.json present) — the installer detected pre-existing AI tooling. A developer must run /adopt (it cannot be model-invoked) to consolidate it; /adopt removes this marker in its Phase 3."
else
  ok "no adoption-pending marker."
fi

# 1. CLAUDE.md present, non-empty, bootstrapped.
if [ ! -s "CLAUDE.md" ]; then
  fail "CLAUDE.md is missing or empty."
elif grep -q "BOOTSTRAP_PENDING" "CLAUDE.md" 2>/dev/null; then
  if [ -f ".claude/adoption-pending.json" ]; then
    fail "CLAUDE.md still contains the BOOTSTRAP_PENDING marker — populated by /adopt (adoption pending, see check 0); do not run /bootstrap directly."
  else
    fail "CLAUDE.md still contains the BOOTSTRAP_PENDING marker — run /bootstrap."
  fi
else
  ok "CLAUDE.md present and bootstrapped."
fi

# 1b. CLAUDE.md size budget (advisory — CLAUDE.md loads on nearly every agent turn and is part of the
#     prompt-cache prefix; a smaller base is a cheaper turn).
if [ -f "CLAUDE.md" ]; then
  cl_lines=$(wc -l < "CLAUDE.md")
  if [ "$cl_lines" -gt 400 ]; then
    echo "NOTE: CLAUDE.md is $cl_lines lines (soft budget 400). Push verbose Architecture Decisions / Repository Structure detail into on-demand files (docs/, skills) to cut per-turn token cost. (advisory — not a failure)"
  fi
fi

# 2. AGENTS.md present AND is the generated mirror (banner + portable-rule headers), not a stale pointer.
if [ ! -f "AGENTS.md" ]; then
  fail "AGENTS.md is missing — run /generate-copilot."
else
  # Maintenance rule 7: an unrunnable grep is not evidence that the banner or a heading is absent.
  # The file exists (checked above), so exit 2+ here means grep itself could not run -- and reporting
  # that as "AGENTS.md is not a current generated mirror" sends someone to regenerate a file that was
  # never inspected. 0 found, 1 genuinely absent, anything else a host condition.
  missing=""
  probe_failed=""
  if grep -q "GENERATED FILE" "AGENTS.md" 2>/dev/null; then
    probe_status=0
  else
    probe_status=$?
  fi
  case "$probe_status" in 0) ;; 1) missing="banner";; *) probe_failed=1;; esac
  for h in "## Verification Rules" "## Leanness" "## Boy Scout Rule" "## Agentic Workflow"; do
    if grep -qF "$h" "AGENTS.md" 2>/dev/null; then
      probe_status=0
    else
      probe_status=$?
    fi
    case "$probe_status" in 0) ;; 1) missing="$missing '$h'";; *) probe_failed=1;; esac
  done
  if [ -n "$probe_failed" ]; then
    fail "grep could not inspect AGENTS.md — this is a host/resource problem, so mirror currency cannot be verified. It is not evidence that AGENTS.md has drifted."
  elif [ -n "$missing" ]; then
    fail "AGENTS.md is not a current generated mirror (missing:$missing) — run /generate-copilot."
  else
    ok "AGENTS.md is a generated mirror of CLAUDE.md's portable rules."
  fi
fi

# 3. copilot-instructions.md present and <= 80 lines.
if [ ! -f ".github/copilot-instructions.md" ]; then
  fail ".github/copilot-instructions.md is missing — run /generate-copilot."
else
  n=$(wc -l < ".github/copilot-instructions.md")
  if [ "$n" -gt 80 ]; then
    fail ".github/copilot-instructions.md is $n lines (limit: 80) — regenerate slimmer with /generate-copilot."
  else
    ok ".github/copilot-instructions.md present ($n lines <= 80)."
  fi
fi

# 4. TECH_DEBT.md present.
if [ -f "TECH_DEBT.md" ]; then ok "TECH_DEBT.md present."; else fail "TECH_DEBT.md is missing — run /bootstrap."; fi

# 4b. FRAMEWORK-CONTEXT.md present and populated.
if [ ! -f "FRAMEWORK-CONTEXT.md" ]; then
  fail "FRAMEWORK-CONTEXT.md is missing — copy it from the template."
elif grep -q "DETECTED_FRAMEWORK_PACKAGES_PENDING" "FRAMEWORK-CONTEXT.md" 2>/dev/null; then
  fail "FRAMEWORK-CONTEXT.md still contains DETECTED_FRAMEWORK_PACKAGES_PENDING — run /bootstrap."
else
  ok "FRAMEWORK-CONTEXT.md present and populated."
fi

# 5. Canonical project-skill location.
if [ -e ".github/skills" ] || [ -L ".github/skills" ]; then
  fail ".github/skills exists — migrate its contents to .claude/skills, then remove the GitHub path."
else
  ok "canonical project skills use .claude/skills (.github/skills absent)."
fi

# 6. README mentions each skill and agent (advisory) — keep the reference tables current.
if [ -f "README.md" ]; then
  missing_doc=""
  for d in .claude/skills/*/; do
    [ -d "$d" ] || continue
    n=$(basename "$d")
    grep -qF "$n" README.md 2>/dev/null || missing_doc="$missing_doc skill:$n"
  done
  for f in .claude/agents/*.md; do
    [ -f "$f" ] || continue
    n=$(basename "$f" .md)
    grep -qF "$n" README.md 2>/dev/null || missing_doc="$missing_doc agent:$n"
  done
  if [ -n "$missing_doc" ]; then
    echo "NOTE: README.md does not mention:$missing_doc — update the What's-in-the-box / subagents tables (they may have drifted). (advisory — not a failure)"
  fi
fi

# 6b. Deterministic framework checks (version-stamp sync, verbatim CLAUDE.md<->AGENTS.md mirror,
#     BOM/twin sweeps) — the same gate the template repo's CI runs; the invariants hold after install.
if [ -f "$here/template-checks.sh" ]; then
  bash "$here/template-checks.sh" || fail "deterministic framework checks failed (see above)."
fi
if [ -f "$here/wiki-check.sh" ]; then
  # Pass the repo root explicitly — wiki-check must never read it from stdin here (an interactive
  # docs-sync-check run would otherwise block waiting for a stdin line).
  bash "$here/wiki-check.sh" "$(cd "$here/.." && pwd)" || fail "team wiki checks failed (see above)."
fi
if [ -f "$here/hazard-check.sh" ]; then
  bash "$here/hazard-check.sh" "$(cd "$here/.." && pwd)" || fail "hazard map checks failed (see above)."
fi
if [ -f "$here/warehouse-map-check.sh" ]; then
  if bash "$here/warehouse-map-check.sh" "$(cd "$here/.." && pwd)"; then
    warehouse_status=0
  else
    warehouse_status=$?
  fi
  case "$warehouse_status" in
    0) ;;
    1) echo 'NOTE: warehouse map is missing or stale; refresh it before a warehouse write. (advisory - not a failure)' ;;
    *) echo 'NOTE: warehouse map could not be verified; this is not evidence that the map is missing or stale. (advisory - not a failure)' ;;
  esac
fi

# 7. architecture.html freshness (advisory) — regenerate after editing ARCHITECTURE.md.
if [ -f "docs/ARCHITECTURE.md" ] && [ -f "docs/architecture.html" ]; then
  if command -v sha1sum >/dev/null 2>&1; then a_sha=$(tr -d '\r' < docs/ARCHITECTURE.md | sha1sum | awk '{print $1}')
  elif command -v shasum  >/dev/null 2>&1; then a_sha=$(tr -d '\r' < docs/ARCHITECTURE.md | shasum  | awk '{print $1}')
  else a_sha=""; fi
  if [ -n "$a_sha" ] && ! grep -q "src-sha1: $a_sha" docs/architecture.html 2>/dev/null; then
    echo "NOTE: docs/architecture.html is stale vs docs/ARCHITECTURE.md — run scripts/build-architecture-html.sh. (advisory — not a failure)"
  fi
fi

if [ "$FAILED" -ne 0 ]; then
  echo
  echo "One or more AI Tech Lead framework checks failed (see above)."
  exit 1
fi

echo
echo "All AI Tech Lead framework checks passed."
