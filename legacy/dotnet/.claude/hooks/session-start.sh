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

# 2. Bootstrap state warning
if [ -f CLAUDE.md ] && grep -q "BOOTSTRAP_PENDING" CLAUDE.md 2>/dev/null; then
  echo "- ⚠ **CLAUDE.md is unbootstrapped** (BOOTSTRAP_PENDING marker present). Run \`/bootstrap\` before non-trivial work — conventions are still placeholder."
fi

# 3. TECH_DEBT items touching recently changed files
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

# 4. Overdue security findings
if [ -f SECURITY_FINDINGS.md ]; then
  today=$(date -u +"%Y-%m-%d")
  overdue=0
  while IFS= read -r line; do
    # Rows with status Open and a due date in the past
    if echo "$line" | grep -qi "| Open " 2>/dev/null; then
      due=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | sed -n '2p')
      if [ -n "$due" ] && [ "$due" \< "$today" ]; then
        overdue=$((overdue + 1))
      fi
    fi
  done < SECURITY_FINDINGS.md
  open_count=$(grep -c "| Open " SECURITY_FINDINGS.md 2>/dev/null || echo 0)
  if [ "$open_count" -gt 0 ]; then
    if [ "$overdue" -gt 0 ]; then
      echo "- 🔴 **Security:** $overdue overdue finding(s) in SECURITY_FINDINGS.md. Remediation SLA breached — review before starting new work."
    else
      echo "- **Security:** $open_count open finding(s) in SECURITY_FINDINGS.md."
    fi
  fi
fi

exit 0
