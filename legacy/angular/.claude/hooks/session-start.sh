#!/usr/bin/env bash
# SessionStart hook — preload high-signal context every new session.
# Output lands in the assistant's context as auxiliary data.
# Keep fast: no expensive scans. Targets git, CLAUDE.md, TECH_DEBT.md only.

set -u

# Run from project root (hook is invoked from there by Claude Code).
echo "## Session preload"

# 1. Git branch + last 3 commits
if [ -d .git ]; then
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "(unknown)")
  echo "- **Branch:** \`$branch\`"

  recent=$(git log -3 --format="  - \`%h\` %s" 2>/dev/null || true)
  if [ -n "$recent" ]; then
    echo "- **Recent commits:**"
    echo "$recent"
  fi
fi

# 2. Adoption / bootstrap state warning
if [ -f .claude/adoption-pending.json ]; then
  echo "- 🔴 **ADOPTION PENDING — this repo is not consolidated yet.** The installer detected pre-existing AI tooling; the originals it displaced are archived under \`docs/pre-adoption/\` and inventoried in \`.claude/adoption-pending.json\`. The required next step is \`/adopt\` — NOT \`/bootstrap\`, which would skip the archive/merge/provenance flow and the impact baseline. \`/adopt\` is developer-initiated and cannot be invoked by the model: if you are an agent, stop and tell the developer to type \`/adopt\`."
elif [ -f CLAUDE.md ] && grep -q "BOOTSTRAP_PENDING" CLAUDE.md 2>/dev/null; then
  echo "- ⚠ **CLAUDE.md is unbootstrapped** (BOOTSTRAP_PENDING marker present). \`/bootstrap\` must run before non-trivial work — conventions are still placeholder. It is developer-initiated and cannot be invoked by the model: if you are an agent, tell the developer to type \`/bootstrap\`."
fi

# 3. Workflow-routing primer.
# In Claude Code, route-prompt.sh injects rails per-prompt. In GitHub Copilot the
# userPromptSubmitted hook is fire-and-forget (stdout is discarded by spec), so the
# only place to surface the routing vocabulary is here — once per session. Top-tier
# models will self-classify against this list and apply the corresponding workflow.
if [ -f CLAUDE.md ]; then
  cat <<'EOF'
- **Workflow routing:** when the user's prompt clearly matches one of the workflows below and they did not type an explicit `/command`, apply that workflow's rails from `CLAUDE.md > Agentic Workflow` before responding. State which workflow you concluded.
  - `feature` — add, implement, create, build new ...
  - `fix` — broken, bug, crash, failing, regression, not working
  - `refactor` — cleanup, extract, rename, simplify, restructure
  - `test` — write/add tests, increase coverage
  - `design` — design X, approach for, trade-offs, how should I architect
  - `debt` — tech debt, technical debt, cleanup debt
  - `review` — review this PR/changes/code, quality gate
EOF
fi

# 4. TECH_DEBT items touching recently changed files
if [ -f TECH_DEBT.md ] && [ -d .git ]; then
  # Look at files touched in the last 14 days, capped at 30 to bound work.
  recent_files=$(git log --since="14 days ago" --name-only --format="" 2>/dev/null | grep -v '^$' | sort -u | head -30)
  if [ -n "$recent_files" ]; then
    hot=0
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      grep -qF "$f" TECH_DEBT.md 2>/dev/null && hot=$((hot + 1))
    done <<< "$recent_files"
    if [ "$hot" -gt 0 ]; then
      echo "- **Debt heat:** $hot TECH_DEBT entry(ies) touch files changed in the last 14 days. Consider \`/debt\` for trojan-horse opportunities."
    fi
  fi
fi

exit 0
