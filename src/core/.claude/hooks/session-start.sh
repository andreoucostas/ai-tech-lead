#!/usr/bin/env bash
# SessionStart hook — preload high-signal context every new session.
# Output lands in the assistant's context as auxiliary data. Claude Code consumes plain stdout;
# Copilot (CLI, and VS Code agent mode with Preview agent-hooks) consumes stdout only as JSON
# additionalContext — see the surface dispatch at the bottom.
# Keep fast: no expensive scans. Targets git, CLAUDE.md, TECH_DEBT.md, and
# FRAMEWORK-CONTEXT.md only; the hazard table is capped at ~12 entries, so parsing stays cheap.

set -u

# Best-effort proof that hook wiring actually invoked this script. Telemetry must never affect
# the preload: an unwritable or otherwise unavailable state path is deliberately ignored.
{ mkdir -p .claude/.state && printf '%s' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > .claude/.state/last-session-start; } 2>/dev/null || true

# Read stdin (when piped) for surface detection; Claude Code events carry hook_event_name.
input=""
if [ ! -t 0 ]; then input=$(cat); fi

# Weekly, offline-only version awareness. This does not know whether a newer version exists; it
# only names the installed stamp and points to the releases page. Claim the throttle record before
# emitting so an unwritable state directory cannot turn a low-noise nudge into every-session noise.
version_nudge=""
installed_version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .claude/framework-version.json 2>/dev/null | head -1)
if [ -n "$installed_version" ]; then
  now_epoch=$(date -u +%s 2>/dev/null || true)
  awareness_file=.claude/.state/last-version-awareness
  last_epoch=""
  [ -f "$awareness_file" ] && last_epoch=$(cat "$awareness_file" 2>/dev/null || true)
  case "$last_epoch" in *[!0-9]*|'') last_epoch=0;; esac
  if [ -n "$now_epoch" ] && { [ "$last_epoch" -eq 0 ] || [ $((now_epoch - last_epoch)) -ge $((7 * 86400)) ]; }; then
    if { mkdir -p .claude/.state && printf '%s' "$now_epoch" > "$awareness_file"; } 2>/dev/null; then
      version_nudge="- **Framework version:** v$installed_version installed; check for updates: https://github.com/andreoucostas/ai-tech-lead/releases"
    fi
  fi
fi

emit_body() {

# Run from project root (hook is invoked from there by the harness).
echo "## Session preload"
[ -n "$version_nudge" ] && echo "$version_nudge"

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

# 3. Framework-rules migration pointer. Existing consumers keep their protected CLAUDE.md on
# update, so the newly delivered carrier needs a one-time import. This is discovery, not delivery:
# do not duplicate the rules into hook output.
if [ -f CLAUDE.md ] && [ -f .github/instructions/framework-rules.instructions.md ] && ! grep -qF '@.github/instructions/framework-rules.instructions.md' CLAUDE.md 2>/dev/null; then
  cat <<'EOF'
- ⚠ **Framework rules migration:** `.github/instructions/framework-rules.instructions.md` is the current framework ruleset and supersedes any identically-titled sections in `CLAUDE.md`. Read it now. To make this permanent, add `@.github/instructions/framework-rules.instructions.md` to `CLAUDE.md` where those sections are, and delete them.
EOF
fi

# 4. Workflow-routing pointer. Claude Code consumes this as plain stdout; on Copilot it lands
# only via the JSON additionalContext shape emitted below (CLI, and VS Code agent mode with
# Preview agent-hooks — older Copilot versions drop it, and routing there rests on
# the framework rules (`.github/instructions/framework-rules.instructions.md` › Agentic Workflow;
# `AGENTS.md` › Agentic Workflow on AGENTS.md-native tools), the always-on instruction surface). The full
# intent->workflow vocabulary lives in section 1 (canonical); we do not re-list it here.
if [ -f CLAUDE.md ]; then
  cat <<'EOF'
- **Workflow routing:** when a prompt clearly matches a workflow and the developer did not type a `/command`, self-classify and apply that workflow's rails from the framework rules (`.github/instructions/framework-rules.instructions.md` › Agentic Workflow; `AGENTS.md` › Agentic Workflow on AGENTS.md-native tools), section 1. State which workflow you concluded.
EOF
fi

# 5. TECH_DEBT items touching recently changed files
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

# 6. Overdue security findings
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

# 7. Team wiki index (cheap capped preload; staleness belongs to wiki-check)
if [ -f docs/wiki/INDEX.md ]; then
  wiki_count=$(grep -c '^- \[' docs/wiki/INDEX.md 2>/dev/null || true)
  [ -n "$wiki_count" ] || wiki_count=0
  if [ "$wiki_count" -le 30 ]; then cat docs/wiki/INDEX.md; else echo "$wiki_count wiki entries — read docs/wiki/INDEX.md"; fi
fi

# 8. Hazard-area staleness
if [ -f FRAMEWORK-CONTEXT.md ] && ! grep -q 'KNOWN_HAZARD_AREAS_PENDING' FRAMEWORK-CONTEXT.md 2>/dev/null; then
  cutoff=$(date -d '90 days ago' +%F 2>/dev/null || true)
  if [ -n "$cutoff" ]; then
    open_stale=0
    confirmed_stale=0
    in_hazards=0
    while IFS= read -r line; do
      if [ "$line" = '## Known Hazard Areas' ]; then in_hazards=1; continue; fi
      if [ "$in_hazards" -eq 1 ] && case "$line" in '## '*) true;; *) false;; esac; then break; fi
      [ "$in_hazards" -eq 1 ] || continue
      case "$line" in \|*) ;; *) continue;; esac
      area=$(printf '%s' "$line" | cut -d '|' -f 2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      hazard=$(printf '%s' "$line" | cut -d '|' -f 3 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      status=$(printf '%s' "$line" | cut -d '|' -f 4 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      rev=$(printf '%s' "$line" | cut -d '|' -f 5 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      if [ "$area" = '_(drafted by /bootstrap)_' ] && [ "$hazard" = '_' ] && [ "$status" = '_' ] && [ "$rev" = '_' ]; then continue; fi
      case "$status" in '[REVIEWED: not a hazard'* ) continue;; esac
      case "$rev" in ????-??-??) ;; *) continue;; esac
      [ "$rev" \< "$cutoff" ] || continue
      case "$status" in
        '[UNVERIFIED]'|'[SUSPECTED]') open_stale=$((open_stale + 1));;
        '[VERIFIED]') confirmed_stale=$((confirmed_stale + 1));;
      esac
    done < FRAMEWORK-CONTEXT.md
    if [ "$open_stale" -gt 0 ]; then
      echo "- ⚠ **Hazard areas:** $open_stale hazard area(s) have waited over 90 days for a human answer — confirm each, or mark it 'not a hazard', in FRAMEWORK-CONTEXT.md > Known Hazard Areas."
    elif [ "$confirmed_stale" -gt 0 ]; then
      echo "- **Hazard areas:** $confirmed_stale confirmed hazard area(s) are over 90 days old — a quick re-confirm in FRAMEWORK-CONTEXT.md keeps the map trustworthy."
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
# JSON-encoding needs jq or a working python (same dependency posture as guard.sh); with neither,
# fall back to plain stdout — Copilot drops it, which is exactly the pre-port behavior.
is_copilot=""
case "$input" in
  \{*) printf '%s' "$input" | grep -q '"hook_event_name"' || is_copilot="1" ;;
esac

if [ -z "$is_copilot" ]; then
  printf '%s\n' "$body"
elif command -v jq >/dev/null 2>&1; then
  printf '%s' "$body" | jq -Rs '{additionalContext: ., hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: .}}'
# Resolve a python that actually WORKS, by execution rather than by name: a Windows install
# ships python.exe and no python3.exe, and the Store alias stub resolves but is not an
# interpreter -- probing the name alone would select it and then silently produce nothing.
elif _pybin=$(for c in python3 python py; do command -v "$c" >/dev/null 2>&1 && [ "$(printf '{}' | "$c" -c 'import json,sys;json.load(sys.stdin);sys.stdout.write("ok")' 2>/dev/null)" = ok ] && { printf '%s' "$c"; break; }; done); [ -n "$_pybin" ]; then
  printf '%s' "$body" | "$_pybin" -c 'import json,sys
b = sys.stdin.read()
print(json.dumps({"additionalContext": b, "hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": b}}))'
else
  printf '%s\n' "$body"
fi

exit 0
