#!/usr/bin/env bash
# AI Tech Lead deterministic framework checks — bash twin of template-checks.ps1.
# Exit 0 = pass, otherwise the failure count. Runs in the template repo (CI) and in consumer
# repos (invoked by docs-sync-check). Checks cover version/mirror/BOM/twin/skills-directory/Common
# Tasks inventory parity, minus the PS-syntax parse (the CI windows leg covers it).
set -u

# Anchor to the repo this script lives in (scripts/..), not the caller's cwd — running from
# elsewhere must never silently audit the wrong directory.
cd "$(dirname "$0")/.." || exit 1

failed=0
fail() { echo "FAIL: $1"; failed=$((failed+1)); }
ok()   { echo "OK:   $1"; }

# --- 1. Version-stamp sync -------------------------------------------------------------------
v_claude=""; v_json=""; v_log=""; v_log_line=""
[ -f CLAUDE.md ] && v_claude=$(head -10 CLAUDE.md | sed -n 's/^[[:space:]]*version:[[:space:]]*\([^[:space:]]*\).*/\1/p' | head -1)
[ -f .claude/framework-version.json ] && v_json=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .claude/framework-version.json | head -1)
if [ -f CHANGELOG.md ]; then
  v_log_line=$(grep -m1 -E '^## [0-9]+\.[0-9]+\.[0-9]+' CHANGELOG.md)
  v_log=$(printf '%s' "$v_log_line" | sed -E 's/^## ([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
fi
if [ -z "$v_claude" ]; then fail "CLAUDE.md has no version stamp in its header comment."
elif [ -z "$v_json" ]; then fail ".claude/framework-version.json missing or unparsable."
elif [ "$v_claude" != "$v_json" ]; then fail "version-stamp drift: CLAUDE.md says $v_claude, framework-version.json says $v_json."
elif [ -n "$v_log" ] && [ "$v_log" != "$v_json" ]; then fail "version-stamp drift: CHANGELOG.md head entry is $v_log, framework-version.json says $v_json."
# The version number alone isn't proof the entry is released: a head line whose version already
# matches framework-version.json but still reads "Unreleased" is the literal placeholder shipping
# to consumers as their release date (v0.35.0, v0.46.0 both caught this only by a human noticing).
elif [ -n "$v_log" ] && [ "$v_log" = "$v_json" ] && printf '%s' "$v_log_line" | grep -qw 'Unreleased'; then
  fail "CHANGELOG.md head entry for the current version $v_json still reads '$v_log_line' — stamp it with a real release date before shipping."
else
  extra=""; [ -z "$v_log" ] && extra=" (no CHANGELOG.md — consumer repo, pair-check only)"
  ok "version stamps in sync ($v_claude)$extra."
fi

# --- 2. Framework-rules source <-> AGENTS.md verbatim mirror ------------------------------------
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
  carrier=.github/instructions/framework-rules.instructions.md
  # Updated consumers have the carrier; un-migrated consumers legitimately retain inline sections.
  for sec in "## Verification Rules" "## Leanness" "## SOLID"; do
    a=""; source=$carrier
    [ -f "$carrier" ] && a=$(section "$carrier" "$sec")
    if [ -z "$a" ]; then a=$(section CLAUDE.md "$sec"); source=CLAUDE.md; fi
    b=$(section AGENTS.md "$sec")
    if [ -z "$a" ]; then fail "section '$sec' is missing from both $carrier and CLAUDE.md."
    elif [ "$a" != "$b" ]; then fail "AGENTS.md section '$sec' is not a verbatim mirror of $source — run /generate-copilot."
    else ok "'$sec' mirrored verbatim."
    fi
  done
  boy_claude=$(section CLAUDE.md "## Boy Scout Rule"); boy_agents=$(section AGENTS.md "## Boy Scout Rule")
  if [ -z "$boy_claude" ]; then fail "CLAUDE.md is missing section '## Boy Scout Rule'."
  elif [ "$boy_claude" != "$boy_agents" ]; then fail "AGENTS.md section '## Boy Scout Rule' is not a verbatim mirror of CLAUDE.md — run /generate-copilot."
  else ok "'## Boy Scout Rule' mirrored verbatim."
  fi
  s1c=""; workflow_source=$carrier
  [ -f "$carrier" ] && s1c=$(section1 "$carrier")
  if [ -z "$s1c" ]; then s1c=$(section1 CLAUDE.md); workflow_source=CLAUDE.md; fi
  s1a=$(section1 AGENTS.md)
  if [ -z "$s1c" ]; then fail "Agentic Workflow §1 is missing from both $carrier and CLAUDE.md."
  elif [ "$s1c" != "$s1a" ]; then fail "AGENTS.md Agentic Workflow §1 is not verbatim with $workflow_source (this is the only compared routing block) — run /generate-copilot."
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

# --- 7. Skills mirror: .claude/skills must byte-match .github/skills ---------------------------
# Skills ship twice per repo (Claude reads .claude/skills, Copilot reads .github/skills). They are
# mirrored by /generate-copilot + scripts/sync-agent-files; without a gate, editing one and
# forgetting the other ships stale guidance to Copilot with every other check green.
# CRLF-normalized (--strip-trailing-cr): with core.autocrlf on Windows the two copies can differ
# only in line endings in a working tree yet be identical in a clean checkout -- ignore EOL-only diffs.
if [ -d .claude/skills ] || [ -d .github/skills ]; then
  if diff -rq --strip-trailing-cr .claude/skills .github/skills >/dev/null 2>&1; then
    ok ".claude/skills and .github/skills are in sync."
  else
    details=$(diff -rq --strip-trailing-cr .claude/skills .github/skills 2>&1 | tr '\n' ';')
    fail "skills mirror drift (.claude/skills vs .github/skills — run /generate-copilot): $details"
  fi
fi

# --- 8. Common Tasks skill inventory: CLAUDE.md <-> AGENTS.md ---------------------------------
# Descriptions may be condensed in AGENTS.md, but /generate-copilot promises this remains the same
# skills list. awk strips a UTF-8 BOM and CR before parsing; punctuation tests avoid non-ASCII
# bracket expressions, which have corrupted UTF-8 differently across shell environments before.
common_tasks() { # $1=file; emits existence marker followed by slugs in document order
  awk '
    NR==1 { sub(/^\357\273\277/, "") }
    { sub(/\r$/, "") }
    $0=="## Common Tasks" { print "EXISTS"; section=1; next }
    section && /^## / { exit }
    section && /^- `[a-z0-9][a-z0-9-]*` / {
      line=$0; sub(/^- `/, "", line); slug=line; sub(/`.*/, "", slug)
      rest=line; sub(/^[a-z0-9][a-z0-9-]*`/, "", rest)
      if (index(rest, " — ")==1 || index(rest, " - ")==1) print slug
    }
  ' "$1"
}

if [ -f CLAUDE.md ] && [ -f AGENTS.md ]; then
  common_claude=''; common_agents=''
  claude_exists=0; agents_exists=0
  while IFS= read -r line; do
    if [ "$line" = EXISTS ]; then claude_exists=1
    else common_claude="$common_claude $line"
    fi
  done < <(common_tasks CLAUDE.md)
  while IFS= read -r line; do
    if [ "$line" = EXISTS ]; then agents_exists=1
    else common_agents="$common_agents $line"
    fi
  done < <(common_tasks AGENTS.md)

  # Duplicates first: a set comparison would otherwise hide this defect.
  # Slugs cannot contain spaces by grammar, so space-delimited membership is exact and Bash 3.2-safe.
  seen_common=''; reported_common=''
  for slug in $common_claude; do
    case " $seen_common " in *" $slug "*)
      case " $reported_common " in *" $slug "*) ;; *)
      fail "Common Tasks skill inventory has duplicate slug in CLAUDE.md: $slug."
      reported_common="$reported_common $slug";; esac;;
      *) seen_common="$seen_common $slug";;
    esac
  done
  seen_common=''; reported_common=''
  for slug in $common_agents; do
    case " $seen_common " in *" $slug "*)
      case " $reported_common " in *" $slug "*) ;; *)
      fail "Common Tasks skill inventory has duplicate slug in AGENTS.md: $slug."
      reported_common="$reported_common $slug";; esac;;
      *) seen_common="$seen_common $slug";;
    esac
  done

  missing_agents=''; missing_claude=''
  if [ "$claude_exists" -eq 1 ] && [ "$agents_exists" -eq 1 ]; then
    for slug in $common_claude; do case " $common_agents " in *" $slug "*) ;; *) missing_agents="$missing_agents $slug";; esac; done
    for slug in $common_agents; do case " $common_claude " in *" $slug "*) ;; *) missing_claude="$missing_claude $slug";; esac; done
    if [ -n "$missing_agents" ] || [ -n "$missing_claude" ]; then
      detail=''
      [ -n "$missing_agents" ] && detail="missing from AGENTS.md: $(printf '%s' "${missing_agents# }" | sed 's/ /, /g')"
      if [ -n "$missing_claude" ]; then
        [ -n "$detail" ] && detail="$detail; "
        detail="$detail""missing from CLAUDE.md: $(printf '%s' "${missing_claude# }" | sed 's/ /, /g')"
      fi
      fail "Common Tasks skill inventory differs: $detail."
    fi
  fi

  if { [ "$claude_exists" -eq 1 ] || [ "$agents_exists" -eq 1 ]; } &&
     [ -z "$common_claude" ] && [ -z "$common_agents" ]; then
    fail "Common Tasks sections yielded zero skill slugs — the list grammar changed and this check is now blind."
  fi

  if [ "$claude_exists" -eq 0 ] && [ "$agents_exists" -eq 0 ]; then
    ok "Common Tasks section is absent from both CLAUDE.md and AGENTS.md; skill inventory check did not run."
  elif [ "$claude_exists" -ne "$agents_exists" ]; then
    missing_side=CLAUDE.md; [ "$claude_exists" -eq 1 ] && missing_side=AGENTS.md
    fail "Common Tasks section is missing from $missing_side."
  elif [ -z "$missing_agents" ] && [ -z "$missing_claude" ] &&
       [ -n "$common_claude" ] && [ -n "$common_agents" ]; then
    ok "Common Tasks skill inventory matches between CLAUDE.md and AGENTS.md."
  fi
fi

echo ""
if [ "$failed" -gt 0 ]; then echo "$failed framework check(s) FAILED."; exit "$failed"; fi
echo "All deterministic framework checks passed."
exit 0
