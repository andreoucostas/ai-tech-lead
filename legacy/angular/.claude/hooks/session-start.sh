#!/usr/bin/env bash
# SessionStart hook — preload high-signal context every new session.
# Output lands in the assistant's context as auxiliary data. Claude Code consumes plain stdout;
# Copilot (CLI, and VS Code agent mode with Preview agent-hooks) consumes stdout only as JSON
# additionalContext — see the surface dispatch at the bottom.
# Keep fast: no expensive scans. Targets git, CLAUDE.md, TECH_DEBT.md only.

set -u

# Read stdin (when piped) for surface detection; Claude Code events carry hook_event_name.
input=""
if [ ! -t 0 ]; then input=$(cat); fi

emit_body() {

# Run from project root (hook is invoked from there by the harness).
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

# 3. Workflow-routing pointer. Claude Code consumes this as plain stdout; on Copilot it lands
# only via the JSON additionalContext shape emitted below (CLI, and VS Code agent mode with
# Preview agent-hooks — older Copilot versions drop it, and routing there rests on
# AGENTS.md > Agentic Workflow section 1, the always-on instruction surface). The full
# intent->workflow vocabulary lives in section 1 (canonical); we do not re-list it here.
if [ -f CLAUDE.md ]; then
  cat <<'EOF'
- **Workflow routing:** when a prompt clearly matches a workflow and the developer did not type a `/command`, self-classify and apply that workflow's rails from `CLAUDE.md > Agentic Workflow` (section 1). State which workflow you concluded.
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

# 5. Overdue security findings
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
  # grep -c prints the count even on no match (exit 1), so no `|| echo 0` — that produced "0\n0".
  open_count=$(grep -c "| Open " SECURITY_FINDINGS.md 2>/dev/null || true)
  [ -n "$open_count" ] || open_count=0
  if [ "$open_count" -gt 0 ]; then
    if [ "$overdue" -gt 0 ]; then
      echo "- 🔴 **Security:** $overdue overdue finding(s) in SECURITY_FINDINGS.md. Remediation SLA breached — review before starting new work."
    else
      echo "- **Security:** $open_count open finding(s) in SECURITY_FINDINGS.md."
    fi
  fi
fi

}

body=$(emit_body)

# Surface dispatch. Claude Code includes hook_event_name in the event payload and treats plain
# stdout as context. Copilot parses stdout only as JSON additionalContext (CLI, and VS Code agent
# mode with Preview agent-hooks) — emit both the top-level and wrapped shapes, mirroring
# guard.sh's dual-shape approach. Older Copilot versions ignore the JSON: harmless no-op, same
# as pre-port behavior. Empty or non-JSON stdin defaults to plain stdout (Claude-compatible).
# JSON-encoding needs jq or python3 (same dependency posture as guard.sh); with neither, fall
# back to plain stdout — Copilot drops it, which is exactly the pre-port behavior.
is_copilot=""
case "$input" in
  \{*) printf '%s' "$input" | grep -q '"hook_event_name"' || is_copilot="1" ;;
esac

if [ -z "$is_copilot" ]; then
  printf '%s\n' "$body"
elif command -v jq >/dev/null 2>&1; then
  printf '%s' "$body" | jq -Rs '{additionalContext: ., hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: .}}'
elif command -v python3 >/dev/null 2>&1; then
  printf '%s' "$body" | python3 -c 'import json,sys
b = sys.stdin.read()
print(json.dumps({"additionalContext": b, "hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": b}}))'
else
  printf '%s\n' "$body"
fi

exit 0
