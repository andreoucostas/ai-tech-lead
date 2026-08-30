#!/usr/bin/env bash
# AI Tech Lead deterministic framework checks — bash twin of template-checks.ps1.
# Exit 0 = verified clean, 3 = verified finding(s), 2 = required input could not be inspected.
# Any other nonzero is an abnormal/incomplete run. Runs in the template repo (CI) and in consumer
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
v_claude=""; v_json=""; v_log=""; v_log_line=""; changelog_heads=""; is_template_repo=0
[ -f .template-repo ] && is_template_repo=1
[ -f CLAUDE.md ] && v_claude=$(head -10 CLAUDE.md | sed -n 's/^[[:space:]]*version:[[:space:]]*\([^[:space:]]*\).*/\1/p' | head -1)
[ -f .claude/framework-version.json ] && v_json=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .claude/framework-version.json | head -1)
if [ "$is_template_repo" -eq 1 ] && [ -f CHANGELOG.md ]; then
  changelog_heads=$(grep -E '^## [0-9]+\.[0-9]+\.[0-9]+ — (Unreleased|[0-9]{4}-[0-9]{2}-[0-9]{2})$' CHANGELOG.md)
  grep_status=$?
  if [ "$grep_status" -gt 1 ]; then
    echo 'CANT-VERIFY: template-checks could not inspect CHANGELOG.md; changelog headings remain UNKNOWN. Fix the host/resource read problem and rerun.'
    exit 2
  fi
  v_log_line=$(sed -n '/^## /{p;q;}' CHANGELOG.md)
  stamped_dated=$(printf '%s\n' "$changelog_heads" | grep -E "^## $v_json — [0-9]{4}-[0-9]{2}-[0-9]{2}$" | head -1)
  if [ -n "$stamped_dated" ]; then
    v_log=$v_json
  elif printf '%s\n' "$v_log_line" | grep -Eq '^## [0-9]+\.[0-9]+\.[0-9]+ — [0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    v_log=$(printf '%s' "$v_log_line" | sed -E 's/^## ([0-9]+\.[0-9]+\.[0-9]+) — [0-9]{4}-[0-9]{2}-[0-9]{2}$/\1/')
  fi
fi
if [ -z "$v_claude" ]; then fail "CLAUDE.md has no version stamp in its header comment."
elif [ -z "$v_json" ]; then fail ".claude/framework-version.json missing or unparsable."
elif [ "$v_claude" != "$v_json" ]; then fail "version-stamp drift: CLAUDE.md says $v_claude, framework-version.json says $v_json."
elif [ "$is_template_repo" -eq 1 ] && [ ! -f CHANGELOG.md ]; then fail "marked template repo has no CHANGELOG.md."
# The version number alone is not proof the entry is released: the marked template's literal first
# H2 must use the same dated whole-line grammar the release preflight accepts after stamping. Unmarked
# consumers own their changelog convention, so their CHANGELOG.md is deliberately not parsed.
# Keep the placeholder case as its OWN finding rather than folding it into the grammar message
# below. The generic "expected '## X.Y.Z — YYYY-MM-DD'" is true but unhelpful here, and this exact
# defect -- the literal word Unreleased shipping to consumers as their release date -- reached a
# release twice (v0.35.0, v0.46.0) and both times was caught only by a human noticing.
elif [ "$is_template_repo" -eq 1 ] && [ -z "$v_log" ] && printf '%s' "$v_log_line" | grep -Eq -- "^## $v_json — Unreleased$"; then
  fail "CHANGELOG.md head entry for the current version $v_json still reads '$v_log_line' — stamp it with a real release date before shipping."
elif [ "$is_template_repo" -eq 1 ] && [ -z "$v_log" ]; then fail "marked template repo CHANGELOG.md literal first '## ' line is '$v_log_line' — expected '## X.Y.Z — YYYY-MM-DD'."
elif [ -n "$v_log" ] && [ "$v_log" != "$v_json" ]; then fail "version-stamp drift: CHANGELOG.md head entry is $v_log, framework-version.json says $v_json."
else
  extra=""; [ "$is_template_repo" -eq 0 ] && extra=" (consumer repo — CHANGELOG.md ignored, pair-check only)"
  ok "version stamps in sync ($v_claude)$extra."
fi

if [ "$is_template_repo" -eq 1 ] && [ -n "$v_json" ]; then
  duplicates=$(printf '%s\n' "$changelog_heads" | sed -E 's/^## ([0-9]+\.[0-9]+\.[0-9]+) — .*/\1/' | sort | uniq -d)
  while IFS= read -r version; do
    [ -n "$version" ] && fail "CHANGELOG.md has duplicate release headings for version $version."
  done <<EOF
$duplicates
EOF
  stale_unreleased=$(printf '%s\n' "$changelog_heads" | awk -v current="$v_json" '
    function leq(a, b, aa, bb, i) {
      split(a, aa, "."); split(b, bb, ".")
      for (i=1; i<=3; i++) { if ((aa[i]+0) < (bb[i]+0)) return 1; if ((aa[i]+0) > (bb[i]+0)) return 0 }
      return 1
    }
    / — Unreleased$/ { version=$2; if (leq(version, current)) print version }
  ')
  while IFS= read -r version; do
    [ -n "$version" ] && fail "CHANGELOG.md has an Unreleased heading for shipped version $version (current stamped version: $v_json)."
  done <<EOF
$stale_unreleased
EOF
  # Restores coverage that reading only the FIRST '## ' line used to provide. That read had to go,
  # because the intended pre-stamp state puts the next version's Unreleased head on top -- but it was
  # also the only thing rejecting a DATED head for a version above the stamped one, which is B-152's
  # defect one notch over. There is no legitimate case for it: after a release the top dated head IS
  # the stamped version, and during authoring the top head is Unreleased.
  future_dated=$(printf '%s\n' "$changelog_heads" | awk -v current="$v_json" '
    function gt(a, b, aa, bb, i) {
      split(a, aa, "."); split(b, bb, ".")
      for (i=1; i<=3; i++) { if ((aa[i]+0) > (bb[i]+0)) return 1; if ((aa[i]+0) < (bb[i]+0)) return 0 }
      return 0
    }
    / — [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ { version=$2; if (gt(version, current)) print version }
  ')
  while IFS= read -r version; do
    [ -n "$version" ] && fail "CHANGELOG.md has a dated heading for version $version, which is above the stamped version $v_json -- a release that was dated but never stamped, or a stray head."
  done <<EOF
$future_dated
EOF
fi

# --- 2. Framework-rules source <-> AGENTS.md verbatim mirror ------------------------------------
# Section body: lines after the exact "## <name>" heading up to the next "## ", minus blank/--- lines
# and trailing whitespace.
# CR is stripped on EVERY line before anything else, because the heading test below is an exact
# string compare: on a CRLF checkout `## Leanness\r` != `## Leanness`, so the section is reported
# MISSING and the mirror check fails four times over on a repo that is perfectly fine. The body rule
# always stripped trailing CR; the heading compare did not, and that asymmetry is the whole bug.
# It was invisible on Windows for as long as it existed -- MSYS opens files in text mode, so under
# Git Bash awk never receives the CR. Only a linux run can see it (found by CI, v0.53.0).
# Octal \015 rather than \r: awk implementations differ on which C escapes they honour in a regex,
# and an unrecognised escape degrades to a literal `r` -- which would silently restore this bug.
section() { # $1=file $2=heading
  awk -v h="$2" '
    { sub(/\015$/,"") }
    $0==h {flag=1; next}
    flag && /^## / {exit}
    flag { sub(/[ \t]+$/,""); if ($0!="" && $0!="---") print }
  ' "$1"
}
section1() { # $1=file
  awk '
    { sub(/\015$/,"") }
    /^### 1\. Classify the intent/ {flag=1; next}
    flag && /^### / {exit}
    flag { sub(/[ \t]+$/,""); if ($0!="") print }
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
# Both strips use OCTAL escapes (\357\273\277, \015) rather than \r and friends: awk implementations
# differ on which C escapes they honour inside a regex, and this file runs under whatever `awk` the
# consumer's box provides -- gawk on Git Bash, mawk on a stock Debian/Ubuntu. An unrecognised \r
# degrades to a literal `r`, which would leave the CR in place and make a CRLF checkout parse as if
# the section were absent -- i.e. it would read as a pass. Octal is honoured everywhere.
common_tasks() { # $1=file; emits existence marker followed by slugs in document order
  awk '
    NR==1 { sub(/^\357\273\277/, "") }
    { sub(/\015$/, "") }
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
if [ "$failed" -gt 0 ]; then echo "$failed framework check(s) FAILED."; exit 3; fi
echo "All deterministic framework checks passed."
exit 0
