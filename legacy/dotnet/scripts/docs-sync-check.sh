#!/usr/bin/env bash
# AI Tech Lead framework-state guardrail — host-agnostic.
# Exit 0 = pass, 1 = fail. Runs anywhere: GitHub Actions, Bitbucket Pipelines, Bamboo, Jenkins,
# a Bitbucket Data Center pre-receive hook, or locally. GitHub Actions calls this from
# .github/workflows/docs-sync-check.yml. For Bitbucket Data Center, invoke it from your CI/hook and
# optionally publish the result to the PR via the Code Insights API (see README "Running on
# Bitbucket Data Center").
set -u
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Skip in the framework template repo itself (consumer repos never copy this marker).
if [ -f ".template-repo" ]; then
  echo "Framework template repo (.template-repo present) — skipping framework-state checks."
  exit 0
fi

FAILED=0
fail() { echo "FAIL: $1"; FAILED=1; }
ok()   { echo "OK:   $1"; }

# 1. CLAUDE.md present, non-empty, bootstrapped.
if [ ! -s "CLAUDE.md" ]; then
  fail "CLAUDE.md is missing or empty."
elif grep -q "BOOTSTRAP_PENDING" "CLAUDE.md" 2>/dev/null; then
  fail "CLAUDE.md still contains the BOOTSTRAP_PENDING marker — run /bootstrap."
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
  missing=""
  grep -q "GENERATED FILE" "AGENTS.md" 2>/dev/null || missing="banner"
  for h in "## Verification Rules" "## Leanness" "## Boy Scout Rule" "## Agentic Workflow"; do
    grep -qF "$h" "AGENTS.md" 2>/dev/null || missing="$missing '$h'"
  done
  if [ -n "$missing" ]; then
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

# 5. Skills mirror parity: .github/skills must match .claude/skills (run scripts/sync-agent-files).
if [ -d ".claude/skills" ]; then
  if [ ! -d ".github/skills" ]; then
    fail ".github/skills is missing — run scripts/sync-agent-files.sh."
  elif ! diff -rq ".claude/skills" ".github/skills" >/dev/null 2>&1; then
    fail ".github/skills is out of sync with .claude/skills — run scripts/sync-agent-files.sh."
  else
    ok ".github/skills mirrors .claude/skills."
  fi
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
