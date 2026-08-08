#!/usr/bin/env bash
# ai-tech-lead dist validator (bash twin; .ps1 twin is validate-dist.ps1). Validates an
# ALREADY-COMPOSED dist/<mode> tree — it does NOT rebuild it (see scripts/build.sh for that).
# Eleven checks, each with a clear OK/FAIL line:
#   1. no unresolved @stack:NAME markers survive anywhere in the dist (composer leftovers)
#   2. every *.json in the dist parses
#   3. `bash -n` passes on every *.sh in the dist
#   4. PowerShell AST parse is clean on every *.ps1 in the dist (invokes pwsh/powershell)
#   5. the dist's OWN template-checks suite passes, run from inside the dist dir
#   6. no meta-dev vocabulary leaks into shipped content (scripts/meta-denylist.txt)
#   7. every script a shipped *.md tells someone to RUN exists (no-dead-instruction)
#   8. every hook registration in settings*.json / hooks.json names a script that exists, with its
#      opposite-language twin (hook-registration)
#   9. every core @stack marker expands from a non-empty stack snippet into the composed file
#  10. section-path citations name a heading that exists in the cited shipped file
#  11. CLAUDE.md imports the shipped framework-rules carrier
# Exit 0 = all checks passed. Exit 1 = at least one check failed. Exit 2 = usage error, missing
# dist, or a required tool (JSON parser / bash / PowerShell host) is unavailable — these are
# reported as FATAL and never silently skipped.
#   Usage: validate-dist.sh {dotnet|angular|monorepo} [dist-root] [-Check name[,name...]]
#   dist-root defaults to "dist" resolved under the repo root (scripts/..). Pass an explicit path
#   to validate a scratch copy instead (e.g. to plant failure fixtures without touching dist/).
set -uo pipefail
cd "$(dirname "$0")/.."

# --content-only is an explicit ARGUMENT, not an environment variable — see the PowerShell twin: an
# ambient switch that narrows a gate's scope can be inherited by a shell that never asked for it.
CONTENT_ONLY=0
CHECK_ARG=
CHECK_SET=0
POSITIONAL=""
while [ "$#" -gt 0 ]; do
  arg=$1; shift
  if [ "$arg" = "--content-only" ]; then CONTENT_ONLY=1
  elif [ "$arg" = "-Check" ]; then
    [ "$#" -gt 0 ] || { echo "usage error: -Check requires one or more comma-separated check names." >&2; exit 2; }
    # CHECK_SET, not [ -n "$CHECK_ARG" ], is what marks the flag as supplied. Testing the VALUE
    # cannot tell "-Check was not passed" from "-Check '' was passed", and that gap silently turned
    # an empty selection into "run everything" while the PowerShell twin exited 2 on the same input.
    CHECK_SET=1
    CHECK_ARG=$1; shift
  else POSITIONAL="$POSITIONAL $arg"
  fi
done
# shellcheck disable=SC2086
set -- $POSITIONAL
MODE="${1:-}"
case "$MODE" in dotnet|angular|monorepo) ;; *) echo "usage: validate-dist.sh {dotnet|angular|monorepo} [dist-root] [--content-only] [-Check name[,name...]]" >&2; exit 2;; esac
DISTROOT="${2:-dist}"
DIST="$DISTROOT/$MODE"

VALID_CHECKS='markers json bash-syntax ps-syntax template-checks no-meta-leak no-dead-instruction hook-registration marker-expansion section-path carrier-import'
SELECTED_CHECKS=""
if [ "$CHECK_SET" = "1" ]; then
  _old_ifs=$IFS; IFS=,
  for _check in $CHECK_ARG; do
    IFS=$_old_ifs
    _check=$(printf '%s' "$_check" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    case " $VALID_CHECKS " in *" $_check "*) SELECTED_CHECKS="$SELECTED_CHECKS $_check";;
      *) echo "usage error: unknown check name(s): ${_check:-\(empty\)}. Valid names: $(printf '%s' "$VALID_CHECKS" | sed 's/ /, /g')." >&2; exit 2;; esac
    IFS=,
  done
  IFS=$_old_ifs
  [ -n "$SELECTED_CHECKS" ] || { echo "usage error: unknown check name(s): (empty). Valid names: $(printf '%s' "$VALID_CHECKS" | sed 's/ /, /g')." >&2; exit 2; }
fi
check_selected() {
  if [ "$CHECK_SET" = "1" ]; then case " $SELECTED_CHECKS " in *" $1 "*) return 0;; *) return 1;; esac; fi
  if [ "$CONTENT_ONLY" = "1" ]; then case "$1" in no-meta-leak|no-dead-instruction|hook-registration) return 0;; *) return 1;; esac; fi
  return 0
}
[ -d "$DIST" ] || { echo "no $DIST — run scripts/build.sh $MODE first" >&2; exit 2; }

failed=0
# Per-check elapsed time. Every check ends by calling ok() or fail() exactly once, so timing the
# interval between those calls attributes cost without annotating each check by hand.
#
# Why this exists: this validator's runtime was governed by nothing. A check regressed to the point
# where its bash twin could not finish AT ALL, and that was discovered only because a maintainer
# asked why a suite had been running for hours -- every correctness gate stayed green throughout.
# Correctness was gated; cost was not, so a 20x regression was invisible in the run that caused it.
# Timings go to stderr so stdout stays exactly the OK:/FAIL: stream every caller already parses.
_CHECK_CEILING_S=${VALIDATE_DIST_CHECK_CEILING_S:-25}
_timings=''
_t_last=$EPOCHREALTIME
_record_timing() {
  _t_now=$EPOCHREALTIME
  _t_delta=$(awk -v a="$_t_now" -v b="$_t_last" 'BEGIN{printf "%.1f", a-b}')
  _timings="$_timings$_t_delta $1"$'\n'
  _t_last=$_t_now
}
_report_timings() {
  [ -n "$_timings" ] || return 0
  printf '%s' "$_timings" | while IFS=' ' read -r _d _label; do
    [ -n "$_d" ] || continue
    printf 'TIMING %6ss  %s\n' "$_d" "$_label" >&2
    awk -v d="$_d" -v c="$_CHECK_CEILING_S" 'BEGIN{exit !(d>c)}' &&
      printf 'WARNING: check "%s" took %ss, over the %ss ceiling. Gate cost is a defect too -- profile it before it becomes a timeout.\n' "$_label" "$_d" "$_CHECK_CEILING_S" >&2
  done
}
fail() { _record_timing "${1:0:60}"; echo "FAIL: $1"; failed=$((failed+1)); }
ok()   { _record_timing "${1:0:60}"; echo "OK:   $1"; }

# --content-only skips checks 1-5 (parse/marker/template-checks) and runs only the content checks
# 6, 7 and 8. See the PowerShell twin for the full rationale: those five re-parse every shipped file
# on every case, which made ValidateDist.Tests.ps1 a 9-minute suite in a file that runs in
# release.ps1 and on both CI legs. Neither release.ps1 nor CI passes it; the suite's green anchors
# still run the FULL validator. A restricted run announces itself — a subset must never read as a
# complete one.
if [ "$CONTENT_ONLY" = "1" ]; then
  echo "NOTE: --content-only — checks 1-5 were SKIPPED; this is NOT a full validation."
fi

# The JSON tool is resolved HERE, not inside check 2, because check 8 parses registrations with it
# too. Leaving it in check 2 meant a content-only run left $JSON_TOOL unset and `set -u` killed the
# script immediately after the NOTE — a prerequisite hidden inside an optional group.
# Prefer python3 (matches the .ps1 twin's ConvertFrom-Json more closely: full parse, not just
# lexing); fall back to jq. Neither present is a hard FATAL, not a silent skip.
JSON_TOOL=""
if check_selected json || check_selected hook-registration; then
if python3 -c 'import json' >/dev/null 2>&1; then JSON_TOOL="python3"
elif command -v jq >/dev/null 2>&1; then JSON_TOOL="jq"
else
  echo "FATAL: neither python3 nor jq is available to validate *.json files — install one." >&2
  exit 2
fi
# VALIDATE_DIST_JSON_TOOL pins the branch, and is applied HERE so it governs check 2 and check 8
# alike. Applied later (just before check 8) it left check 2 reporting the auto-detected tool while
# check 8 used the pinned one — two checks disagreeing about which parser ran, in the very variable
# that exists to make the branches distinguishable. An override naming an absent tool is FATAL,
# never a silent fallback.
if [ -n "${VALIDATE_DIST_JSON_TOOL:-}" ]; then
  case "$VALIDATE_DIST_JSON_TOOL" in
    python3) python3 -c 'import json' >/dev/null 2>&1 || { echo "FATAL: VALIDATE_DIST_JSON_TOOL=python3 but python3 is unavailable." >&2; exit 2; } ;;
    jq)      command -v jq >/dev/null 2>&1 || { echo "FATAL: VALIDATE_DIST_JSON_TOOL=jq but jq is unavailable." >&2; exit 2; } ;;
    *)       echo "FATAL: VALIDATE_DIST_JSON_TOOL must be python3 or jq, got '$VALIDATE_DIST_JSON_TOOL'." >&2; exit 2 ;;
  esac
  JSON_TOOL="$VALIDATE_DIST_JSON_TOOL"
fi
fi

if [ "$CONTENT_ONLY" != "1" ]; then
if check_selected markers; then
# --- 1. no unresolved @stack markers ------------------------------------------------------------
_marker_list=$(mktemp)
marker_enum_ok=1
find "$DIST" -type f > "$_marker_list" || marker_enum_ok=0
marker_count=$(wc -l < "$_marker_list" | tr -d ' ')
markers=""
marker_read_fails=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  grep -IlE '@stack:[A-Za-z0-9_-]+' "$f" >/dev/null 2>&1
  marker_status=$?
  if [ "$marker_status" -eq 0 ]; then markers="$markers $f"
  elif [ "$marker_status" -gt 1 ]; then marker_read_fails="$marker_read_fails $f"
  fi
done < "$_marker_list"
rm -f "$_marker_list"
if [ "$marker_enum_ok" -ne 1 ]; then
  fail "marker scan could not enumerate $DIST."
elif [ "$marker_count" -eq 0 ]; then
  fail "marker scan found zero files in $DIST."
elif [ -n "$marker_read_fails" ]; then
  fail "marker scan could not read:$marker_read_fails"
elif [ -n "$markers" ]; then
  fail "unresolved @stack markers in:$(printf ' %s' $markers)"
else
  ok "no unresolved @stack markers in $DIST ($marker_count files scanned)."
fi
fi

if check_selected marker-expansion; then
# --- 1a. every core marker expands from a non-empty snippet --------------------------------------
# A missing snippet is silently consumed by the composer. Derive this inventory from src/core so a
# marker added later is covered without maintaining a second list.
marker_count=0
expansion_problems=""
# ONE regex, used both to select which files to open and to extract markers from them. It is a
# single variable on purpose: the speedup below narrows the outer loop from every file in src/core
# to only the marker-bearing ones, and if the selecting pattern could drift from the extracting
# pattern the check would silently inspect fewer markers and still print OK — an inert check, which
# is worse than the slow one it replaces. Sharing the literal makes that divergence impossible.
_MARKER_LINE_RE='^[[:space:]]*(<!-- @stack:[A-Za-z0-9_-]+ -->|# @stack:[A-Za-z0-9_-]+)[[:space:]]*$'
while IFS= read -r core_file; do
  core_rel=${core_file#src/core/}
  dist_file="$DIST/$core_rel"
  # Read the composed file ONCE per file rather than once per marker. Files carry up to a dozen
  # markers each, so this was re-reading and re-normalising the same file a dozen times.
  dist_text=''
  [ -f "$dist_file" ] && dist_text=$(sed 's/\r$//' "$dist_file")
  while IFS= read -r marker; do
    [ -n "$marker" ] || continue
    marker_count=$((marker_count+1))
    name=${marker#@stack:}
    snippet_paths=""
    if [ "$MODE" = monorepo ]; then
      mono="src/stacks/monorepo/snippets/$core_rel/$name"
      if [ -f "$mono" ]; then snippet_paths=$mono
      else
        [ -f "src/stacks/dotnet/snippets/$core_rel/$name" ] && snippet_paths="src/stacks/dotnet/snippets/$core_rel/$name"
        [ -f "src/stacks/angular/snippets/$core_rel/$name" ] && snippet_paths="$snippet_paths src/stacks/angular/snippets/$core_rel/$name"
      fi
    else
      candidate="src/stacks/$MODE/snippets/$core_rel/$name"
      [ -f "$candidate" ] && snippet_paths=$candidate
      if [ -z "$snippet_paths" ]; then
        other_count=0
        for other_stack in dotnet angular monorepo; do
          [ "$other_stack" = "$MODE" ] && continue
          [ -f "src/stacks/$other_stack/snippets/$core_rel/$name" ] && other_count=$((other_count+1))
        done
        # One-stack snippets are intentional; two present siblings identify an accidental deletion.
        [ "$other_count" -lt 2 ] && continue
      fi
    fi
    snippet_text=""
    for snippet in $snippet_paths; do
      part=$(sed 's/\r$//' "$snippet")
      if [ -n "$snippet_text" ]; then snippet_text="$snippet_text
$part"; else snippet_text=$part; fi
    done
    # "is this blank?" as a bash pattern test, not a printf|grep pipeline. It runs once per marker,
    # and at 117 markers those two forks per marker were the single most expensive thing left in the
    # validator -- 14.7s of a 40s run, more than every parse check combined.
    if [[ ! "$snippet_text" =~ [^[:space:]] ]]; then
      expansion_problems="$expansion_problems
$MODE : $core_rel $marker resolves to an empty expansion"
    elif [ ! -f "$dist_file" ]; then
      expansion_problems="$expansion_problems
$MODE : $core_rel $marker cannot expand because the composed file is missing"
    else
      case "$dist_text" in
        *"$snippet_text"*) ;;
        *) expansion_problems="$expansion_problems
$MODE : $core_rel $marker snippet content is absent from the composed file" ;;
      esac
    fi
    # BOTH marker forms, anchored to the whole line exactly as the composer anchors them
    # (build.sh's html/hash marker regexes): markdown `<!-- @stack:NAME -->`, scripts `# @stack:NAME`.
    # Unanchored matching would also count a prose mention of the syntax as a marker.
  done < <(grep -hoE "$_MARKER_LINE_RE" "$core_file" 2>/dev/null |
           grep -oE '@stack:[A-Za-z0-9_-]+' || true)
  # Only files that actually contain a marker, selected with the SAME regex used to extract them
  # above. `find src/core -type f` opened all 109 files to find markers in 40 of them.
done < <(grep -rlE "$_MARKER_LINE_RE" src/core 2>/dev/null || true)
expansion_count=$(printf '%s\n' "$expansion_problems" | grep -c . || true)
if [ "$marker_count" -eq 0 ]; then
  fail "marker-expansion inventory found zero core @stack markers -- the inventory is broken, not the dist."
elif [ "$expansion_count" -gt 0 ]; then
  fail "marker expansion failed for $expansion_count core marker(s) in $MODE."
  printf '%s\n' "$expansion_problems" | grep . | sort -u | sed 's/^/  [marker-expansion] /'
else
  ok "all $marker_count core @stack markers expand from non-empty $MODE snippets into composed files."
fi
fi

if check_selected section-path; then
# --- 1b. section-path references resolve ---------------------------------------------------------
# The finite file/heading registry avoids treating prose after a citation as part of the heading.
# CHANGELOG.md is historical text and is excluded by path. grep -Iq supplies the existing textual
# classification semantics: binary files are skipped, while every textual extension is scanned.
citation_files="CLAUDE.md AGENTS.md .github/instructions/framework-rules.instructions.md"
# Separator registry matches the PowerShell twin exactly: ONLY ">" or "›". The first draft accepted
# any non-alphanumeric character, which is a looser grammar than the twin's and would have made the
# two disagree about what counts as a citation.
citation_sep='[[:space:]]*(>|›)[[:space:]]*'
citation_headings="Architecture Decisions|Verification Rules|Repository Structure|Agentic Workflow|Codebase Context|What We've Learned|Boy Scout Rule|Common Tasks|Conventions|Leanness|SOLID"
citation_problems=""

# Batched, not per-line. The first draft ran a `sed` plus a `grep` for every (line x cited file x
# heading) triple -- up to 66 subprocesses per line across ~160 shipped files. On Git-for-Windows
# that exhausted the process table ("dofork: ... Resource temporarily unavailable") and never
# finished; the PowerShell twin completed the same work in ~10s. Here one grep pass per cited file
# finds the candidate lines, and only those few lines are examined individually.
text_list_file=$(mktemp)
find "$DIST" -type f ! -name CHANGELOG.md -print0 | xargs -0 grep -Il . > "$text_list_file" 2>/dev/null || true
text_files_scanned=$(grep -c . "$text_list_file" || true)

for cited_file in $citation_files; do
  escaped_file=$(printf '%s' "$cited_file" | sed 's/[.[\*^$()+?{|\\]/\\&/g')
  plain_pattern='`'"$escaped_file$citation_sep($citation_headings)"'`'
  link_pattern='\['"$escaped_file"'\]\([^)]*\)'"$citation_sep($citation_headings)"'($|[`;,.):]])'
  target="$DIST/$cited_file"
  target_headings=''
  [ -f "$target" ] && target_headings=$(grep -E '^#+[[:space:]]+' "$target" || true)
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    hit_file=${hit%%:*}; rest=${hit#*:}; line_no=${rest%%:*}; line=${rest#*:}
    # Mirrors the twin's `break` after the first heading match on a line.
    heading=$(printf '%s\n' "$line" | grep -oE "$citation_sep($citation_headings)" | head -1 |
              sed -E "s/^$citation_sep//")
    [ -n "$heading" ] || continue
    if [ ! -f "$target" ]; then
      citation_problems="$citation_problems
${hit_file#"$DIST/"}:$line_no cites $cited_file > $heading, but $cited_file is missing"
    elif ! printf '%s\n' "$target_headings" | grep -qE "^#+[[:space:]]+$heading[[:space:]]*$"; then
      citation_problems="$citation_problems
${hit_file#"$DIST/"}:$line_no cites $cited_file > $heading, but that heading does not exist"
    fi
  done < <(tr '\n' '\0' < "$text_list_file" | xargs -0 grep -nHE "$plain_pattern|$link_pattern" 2>/dev/null || true)
done
rm -f "$text_list_file"
citation_count=$(printf '%s\n' "$citation_problems" | grep -c . || true)
if [ "$text_files_scanned" -eq 0 ]; then
  fail "section-path reference check scanned zero textual files in $DIST -- the input is empty or unreadable."
elif [ "$citation_count" -gt 0 ]; then
  fail "unresolved section-path references in shipped content -- $citation_count."
  printf '%s\n' "$citation_problems" | grep . | sort -u | sed 's/^/  [section-path-reference] /'
else
  ok "all registered section-path references resolve ($text_files_scanned textual file(s) scanned; CHANGELOG.md excluded)."
fi
fi

if check_selected carrier-import; then
# --- 1c. CLAUDE.md imports the delivered framework-rules carrier --------------------------------
import_line='@.github/instructions/framework-rules.instructions.md'
if [ ! -f "$DIST/CLAUDE.md" ]; then
  fail "framework-rules import cannot be checked because CLAUDE.md is missing from $DIST."
elif ! grep -Fq "$import_line" "$DIST/CLAUDE.md"; then
  fail "CLAUDE.md is missing required import $import_line."
elif [ ! -f "$DIST/.github/instructions/framework-rules.instructions.md" ]; then
  fail "CLAUDE.md imports $import_line but the carrier file is missing from $DIST."
else
  ok "CLAUDE.md imports the delivered framework-rules carrier."
fi
fi

if check_selected json; then
# --- 2. every *.json parses -----------------------------------------------------------------------
_json_list=$(mktemp)
json_enum_ok=1
find "$DIST" -name '*.json' -type f > "$_json_list" || json_enum_ok=0
json_count=$(wc -l < "$_json_list" | tr -d ' ')
jsonfails=""
json_read_fails=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  cat "$f" >/dev/null 2>&1 || { json_read_fails="$json_read_fails $f"; continue; }
  if [ "$JSON_TOOL" = "python3" ]; then
    python3 -c 'import json,sys
json.load(open(sys.argv[1], encoding="utf-8"))' "$f" >/dev/null 2>&1 || jsonfails="$jsonfails $f"
  else
    jq empty "$f" >/dev/null 2>&1 || jsonfails="$jsonfails $f"
  fi
done < "$_json_list"
rm -f "$_json_list"
if [ "$json_enum_ok" -ne 1 ]; then fail "JSON scan could not enumerate $DIST."
elif [ "$json_count" -eq 0 ]; then fail "JSON scan found zero files in $DIST."
elif [ -n "$json_read_fails" ]; then fail "JSON scan could not read:$json_read_fails"
elif [ -n "$jsonfails" ]; then fail "invalid JSON ($JSON_TOOL):$jsonfails"
else ok "all $json_count *.json files parse ($JSON_TOOL)."; fi
fi

if check_selected bash-syntax; then
# --- 3. bash -n on every *.sh ----------------------------------------------------------------------
command -v bash >/dev/null 2>&1 || { echo "FATAL: bash is not available to syntax-check *.sh files." >&2; exit 2; }
_sh_list=$(mktemp)
sh_enum_ok=1
find "$DIST" -name '*.sh' -type f > "$_sh_list" || sh_enum_ok=0
sh_count=$(wc -l < "$_sh_list" | tr -d ' ')
shfails=""
sh_read_fails=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  cat "$f" >/dev/null 2>&1 || { sh_read_fails="$sh_read_fails $f"; continue; }
  bash -n "$f" 2>/dev/null || shfails="$shfails $f"
done < "$_sh_list"
rm -f "$_sh_list"
if [ "$sh_enum_ok" -ne 1 ]; then fail "shell scan could not enumerate $DIST."
elif [ "$sh_count" -eq 0 ]; then fail "shell scan found zero files in $DIST."
elif [ -n "$sh_read_fails" ]; then fail "shell scan could not read:$sh_read_fails"
elif [ -n "$shfails" ]; then fail "bash syntax errors in:$shfails"
else ok "all $sh_count *.sh files parse cleanly (bash -n)."; fi
fi

if check_selected ps-syntax; then
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
# ONE PowerShell process for the whole tree, not one per file. Starting pwsh costs ~265 ms on this
# box (it is the MSIX build), so the old per-file loop spent ~8.5 s of a run purely on process
# startup for ~32 files, and every one of those parses is identical work the runtime could do
# back-to-back. The parse itself is unchanged: same Parser::ParseFile, same per-file verdict.
# NOTE: positional args after `pwsh -Command '<script>'` do NOT bind to $args (they're silently
# dropped) — the file list travels via an env var pointing at a temp file, so no quoting concerns.
_ps1_list=$(mktemp)
_ps1_read_fails=$(mktemp)
_ps1_parse_fails=$(mktemp)
ps1_enum_ok=1
find "$DIST" -name '*.ps1' -type f > "$_ps1_list" || ps1_enum_ok=0
ps1_count=$(wc -l < "$_ps1_list" | tr -d ' ')
ps1_tool_ok=1
if [ "$ps1_count" -gt 0 ]; then
  VALIDATE_DIST_PS1_LIST="$_ps1_list" VALIDATE_DIST_PS1_READ_FAILS="$_ps1_read_fails" VALIDATE_DIST_PS1_PARSE_FAILS="$_ps1_parse_fails" "$PWSH" -NoProfile -NonInteractive -Command '
    $bad = @()
    foreach ($p in [IO.File]::ReadAllLines($env:VALIDATE_DIST_PS1_LIST)) {
      if ([string]::IsNullOrWhiteSpace($p)) { continue }
      $e = $null
      try { [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$e) | Out-Null }
      catch { [IO.File]::AppendAllText($env:VALIDATE_DIST_PS1_READ_FAILS, " " + $p); continue }
      if ($e) { [IO.File]::AppendAllText($env:VALIDATE_DIST_PS1_PARSE_FAILS, " " + $p) }
    }
  ' 2>/dev/null || ps1_tool_ok=0
fi
ps1_read_fails=$(cat "$_ps1_read_fails")
ps1fails=$(cat "$_ps1_parse_fails")
rm -f "$_ps1_list" "$_ps1_read_fails" "$_ps1_parse_fails"
if [ "$ps1_enum_ok" -ne 1 ]; then fail "PowerShell scan could not enumerate $DIST."
elif [ "$ps1_count" -eq 0 ]; then fail "PowerShell scan found zero files in $DIST."
elif [ "$ps1_tool_ok" -ne 1 ]; then fail "PowerShell parser process failed while scanning $Dist."
elif [ -n "$ps1_read_fails" ]; then fail "PowerShell scan could not read:$ps1_read_fails"
elif [ -n "$ps1fails" ]; then fail "PS syntax errors in:$ps1fails"
else ok "all $ps1_count *.ps1 files parse cleanly ($PWSH)."; fi
fi

if check_selected template-checks; then
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
fi
fi   # end of the checks 1-5 group (VALIDATE_DIST_CONTENT_ONLY)

if check_selected no-meta-leak; then
# --- 6. no meta-dev vocabulary in shipped content ---------------------------------------------------
# The don't-ship boundary (invariant #6) made deterministic. Everything under dist/ lands in a
# consumer's repo, so the framework's own development vocabulary — tracking ids, the two-repo
# authoring past, maintainer-only tooling — must not appear there. Patterns live in
# scripts/meta-denylist.txt and are read by BOTH twins, so the denylist itself cannot drift between
# the bash and PowerShell legs (invariant #3).
DENYFILE="scripts/meta-denylist.txt"
[ -f "$DENYFILE" ] || { echo "FATAL: missing $DENYFILE — cannot run the no-meta-leak check." >&2; exit 2; }
denypats=$(grep -E '^DENY[[:space:]]+' "$DENYFILE" | sed -E 's/^DENY[[:space:]]+//' || true)
allowpaths=$(grep -E '^ALLOW[[:space:]]+' "$DENYFILE" | sed -E 's/^ALLOW[[:space:]]+//' || true)
[ -n "$denypats" ] || { echo "FATAL: $DENYFILE defines no DENY patterns." >&2; exit 2; }
leaks=""
greperrs=""
# Anti-vacuity: guard the INPUT, not just the findings. An empty tree, or a grep that errored on
# every pattern, produces no leaks and used to report a clean dist exactly as a genuinely clean one
# did (B-92). Count what was actually scanned and say so on the OK line.
patcount=$(printf '%s\n' "$denypats" | grep -c . || true)
filesscanned=$(find "$DIST" -type f | grep -c . || true)
while IFS= read -r p; do
  [ -n "$p" ] || continue
  # -I skips binary files; -i matches the .ps1 twin's case-insensitive Select-String.
  # grep exits 0 = matched, 1 = no match, >1 = ERROR (bad regex, unreadable input). The `|| true`
  # idiom this replaced collapsed the error case into "no match", which is B-59's fail-open: a
  # pattern that stopped working looked exactly like a pattern that found nothing.
  hits=$(grep -rIiEn -- "$p" "$DIST" 2>/dev/null); gstatus=$?
  if [ "$gstatus" -gt 1 ]; then greperrs="$greperrs$p"$'\n'; continue; fi
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    f="${hit%%:*}"; rest="${hit#*:}"; ln="${rest%%:*}"
    rel="${f#"$DIST"/}"
    skip=0
    while IFS= read -r a; do
      [ -n "$a" ] || continue
      case "$rel" in *"$a"*) skip=1;; esac
    done <<< "$allowpaths"
    [ "$skip" -eq 1 ] && continue
    leaks="$leaks$rel:$ln: $p"$'\n'
  done <<< "$hits"
done <<< "$denypats"
leaks=$(printf '%s' "$leaks" | sed '/^[[:space:]]*$/d' | sort || true)
leakcount=$(printf '%s' "$leaks" | grep -c . || true)
greperrcount=$(printf '%s' "$greperrs" | grep -c . || true)
if [ "$greperrcount" -gt 0 ]; then
  fail "no-meta-leak: grep failed (exit > 1) on $greperrcount pattern(s) in $DIST — the scan is broken, not the dist."
  printf '%s' "$greperrs" | grep . | sed 's/^/  [no-meta-leak] errored pattern: /'
elif [ "$filesscanned" -eq 0 ]; then
  fail "no-meta-leak scanned zero files in $DIST — the input tree is empty, not clean."
elif [ "$leakcount" -gt 0 ]; then
  fail "meta vocabulary in shipped content — $leakcount line(s). These reach a consumer repo; fix in src/, not dist/."
  printf '%s\n' "$leaks" | head -20 | sed 's/^/  [no-meta-leak] /'
  [ "$leakcount" -gt 20 ] && echo "  [no-meta-leak] ... and $((leakcount - 20)) more line(s)."
else
  ok "no meta-dev vocabulary in $DIST (no-meta-leak; $patcount pattern(s) over $filesscanned file(s))."
fi
fi

if check_selected no-dead-instruction; then
# --- 7. no dead instructions ------------------------------------------------------------------
# Every script a shipped doc tells someone to RUN must actually exist. no-meta-leak (check 6)
# proves shipped files don't say the wrong *words*; nothing proved they don't give the wrong
# *commands*. They did: dist/monorepo's README told installing agents to run `pwsh install.ps1`,
# which exists nowhere in that dist — root-installer wording copied into a dist doc. An agent that
# followed it verbatim got "No such file or directory" (v0.26.3; meta/LEARNINGS.md).
#
# Resolution base is the DIST ROOT, not the doc's own directory — the framework documents every
# command as run from the repo root (`bash scripts/docs-sync-check.sh` in docs/ci-integration.md
# means from the consumer's root, not from docs/).
#
# CHANGELOG.md is skipped by design: release notes quote commands that WERE wrong in order to say
# they are now fixed. It is the one shipped doc whose job is to describe the past.
# Anti-vacuity, as in check 6: this check used to report a clean dist whenever its findings list was
# empty, so an extractor that stopped matching — or a tree with no docs at all — read as success.
# It now counts what it scanned and what it extracted, and fails when either is zero (B-92).
#
# An absolute path in a DOC may legitimately be a placeholder example, so it is not resolved — but it
# is counted and listed, because "every documented command resolves" was a claim the check could not
# support. Check 8 treats an absolute path in a REGISTRATION as a defect instead: that is machine
# wiring, not prose, and there it is always wrong.
deadrefs=""
absrefs=""
docgreperrs=""
docsscanned=0
refsextracted=0
cmdre='(pwsh|bash|powershell)( -[A-Za-z]+( [A-Za-z]+)?)* [A-Za-z0-9_./-]+\.(ps1|sh)'
# ONE grep over every shipped doc, instead of one grep PER doc. At ~90 docs that was ~90 forks per
# run, 7.5s of a 34s run, and it ran on every invocation including the cheap --content-only ones.
# The batched pass emits `path:line:content`, so nothing about the extraction below changes.
#
# The per-file loop is NOT deleted: it survives as the error path. `grep -r` reports exit 2 if ANY
# input was unreadable but does not say WHICH, and "a doc that could not be read is not a doc that
# contained nothing" is the anti-fail-open property this check was given deliberately. So the fast
# path runs first, and only when it reports an error do we re-walk file by file to name the culprit.
# Fast when healthy, precise when broken.
_batch=$(grep -rnE --include='*.md' "$cmdre" "$DIST" 2>/dev/null); _bstatus=$?
if [ "$_bstatus" -gt 1 ]; then
  while IFS= read -r f; do
    case "${f##*/}" in CHANGELOG.md) continue;; esac
    rel="${f#"$DIST"/}"
    grep -nE "$cmdre" "$f" >/dev/null 2>&1
    [ $? -gt 1 ] && docgreperrs="$docgreperrs$rel"$'\n'
  done < <(find "$DIST" -type f -name '*.md')
fi
# Scanned-count is its own cheap pass; the batched grep only reports files that MATCHED, and the
# vacuity floor below needs to know how many docs were actually looked at.
docsscanned=$(find "$DIST" -type f -name '*.md' ! -name 'CHANGELOG.md' | grep -c . || true)
while IFS= read -r _bline; do
  [ -n "$_bline" ] || continue
  f="${_bline%%:*}"; _rest="${_bline#*:}"
  case "${f##*/}" in CHANGELOG.md) continue;; esac
  rel="${f#"$DIST"/}"
  matches="$_rest"
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    ln="${hit%%:*}"; content="${hit#*:}"
    while IFS= read -r script; do
      [ -n "$script" ] || continue
      refsextracted=$((refsextracted+1))
      case "$script" in
        /*) absrefs="$absrefs$rel:$ln: absolute example \`$script\` out of scope"$'\n'; continue;;
      esac
      [ -f "$DIST/$script" ] || deadrefs="$deadrefs$rel:$ln: \`$script\` does not exist in this dist"$'\n'
    done <<< "$(printf '%s\n' "$content" | grep -oE "$cmdre" | grep -oE '[A-Za-z0-9_./-]+\.(ps1|sh)$')"
  done <<< "$matches"
done <<< "$_batch"
deadrefs=$(printf '%s' "$deadrefs" | sed '/^[[:space:]]*$/d' | sort -u || true)
absrefs=$(printf '%s' "$absrefs" | sed '/^[[:space:]]*$/d' | sort -u || true)
deadcount=$(printf '%s' "$deadrefs" | grep -c . || true)
abscount=$(printf '%s' "$absrefs" | grep -c . || true)
docgreperrcount=$(printf '%s' "$docgreperrs" | grep -c . || true)
if [ "$docgreperrcount" -gt 0 ]; then
  fail "no-dead-instruction: grep failed (exit > 1) on $docgreperrcount doc(s) in $DIST — the scan is broken, not the dist."
  printf '%s' "$docgreperrs" | grep . | sed 's/^/  [no-dead-instruction] unreadable doc: /'
elif [ "$docsscanned" -eq 0 ]; then
  fail "no-dead-instruction scanned zero documentation files in $DIST — the input tree is empty, not clean."
elif [ "$refsextracted" -eq 0 ]; then
  fail "no-dead-instruction extracted zero script references from $docsscanned doc(s) in $DIST — the inline-command extractor is broken, not the dist."
elif [ "$deadcount" -gt 0 ]; then
  fail "dead instructions in shipped docs — $deadcount. A consumer (or their agent) following these gets 'No such file or directory'. Fix in src/, not dist/."
  printf '%s\n' "$deadrefs" | sed 's/^/  [no-dead-instruction] /'
else
  [ "$abscount" -eq 0 ] || printf '%s\n' "$absrefs" | sed 's/^/  [no-dead-instruction] /'
  ok "all $((refsextracted - abscount)) resolvable documented script references exist in $DIST ($docsscanned doc(s) scanned; $abscount absolute example(s) out of scope)."
fi
fi

if check_selected hook-registration; then
# --- 8. hook registrations point at hooks that exist ---------------------------------------------
# Twin of check 8 in validate-dist.ps1 — see that file for the full rationale. In short: nothing
# read the registration files at all (check 2 only proves they are valid JSON, check 7 only scans
# *.md), so a registration naming a script absent from the dist shipped silently, and the symptom
# on the consumer's side is a hook that never runs and never complains.
#
# This deliberately does NOT fail on a bare interpreter name — that is the correct shipped value
# (pinning absolute paths was tried and reverted in v0.38.1, because settings.json is committed
# team configuration). Whether a bare name resolves is a runtime property; the doctor's
# `Hook liveness` row reports that from the consumer's machine.
#
# Registrations are PARSED as JSON (WSD-030), not matched textually. The textual extractor this
# replaced is what made checks 1 and 3 of B-92 possible: its vacuity floor was a second regex over
# the same bytes, and a quoted -File value defeated it outright. The cost of parsing is that bash
# has two parser branches (python3 or jq, whichever the box has); VALIDATE_DIST_JSON_TOOL exists so
# both can be exercised and diffed rather than one rotting unexercised.
# Case-EXACT existence test, matching the PowerShell twin's Test-CaseExactPath. `[ -f ]` is
# case-insensitive under Git Bash on Windows and case-sensitive on Linux, so a `.PS1` registration
# naming a `.ps1` file passed on the maintainer's box and failed on Linux CI: a twin divergence
# caused by the PLATFORM, invisible to any amount of testing on one OS. Walk the real entries.
#
# COST: this used to walk the tree per call, spawning `ls | grep` for EVERY path segment — 6
# processes per lookup, ~52 lookups, ~312 forks. Under Git for Windows that was the single most
# expensive thing in the whole validator: measured 26s for a run, and `--content-only` (which skips
# checks 1-5 entirely) came out SLOWER than a full run because this check dominated both. The
# inventory is now built ONCE with a single `find`, and each lookup is a pure-bash membership test
# with no subprocess at all.
#
# Fidelity is unchanged, and that is the point — this is a speedup, not a relaxation:
#   * `find -type f` reports the REAL on-disk names, exactly as `ls` did, so the comparison stays
#     case-exact. A `.PS1` registration naming a `.ps1` file still fails here and still fails on
#     Linux, which is the platform divergence this function exists to catch.
#   * `-type f` also preserves the old trailing `[ -f ]`: a directory whose name matches is still
#     not a resolved script.
_DIST_FILE_INDEX=''
build_dist_file_index() {   # $1 = root
  # Leading/trailing newlines make the membership test below unambiguous for the first and last
  # entries without special-casing them.
  _DIST_FILE_INDEX=$'\n'$(cd "$1" 2>/dev/null && find . -type f 2>/dev/null | sed 's#^\./##')$'\n'
}
case_exact_path() {   # $1 = root, $2 = relative path
  [ -n "$_DIST_FILE_INDEX" ] || build_dist_file_index "$1"
  case "$_DIST_FILE_INDEX" in
    *$'\n'"$2"$'\n'*) return 0 ;;
    *) return 1 ;;
  esac
}

check_hook_ref() {   # $1 = registration file (dist-relative), $2 = referenced script
  # hooks.json writes Windows paths with backslashes, and JSON escaping doubles them, so the decoded
  # value holds ".claude\hooks\guard.ps1". Collapse any RUN of backslashes to ONE separator — doing
  # it in that order matters: translating each backslash separately yields ".claude//hooks//guard.ps1",
  # which resolves on both Windows and POSIX and so would hide the sloppiness rather than fail on it.
  # This is the pure-bash equivalent of the `printf | sed -E 's#\\+#/#g'` it replaced, which forked
  # twice for every one of the ~52 references checked here.
  _rel="$2"
  while [ "${_rel}" != "${_rel//\\\\/\\}" ]; do _rel="${_rel//\\\\/\\}"; done
  _rel="${_rel//\\//}"
  # An absolute registration is NOT exempt (B-92). It is a dead hook on every machine but the one it
  # was written on — the exact "silently never runs" symptom this check exists to remove — and the
  # old early `return` made a missing absolute target report as resolved. Check 7 still skips
  # absolute paths, because a doc may show one as a placeholder; machine wiring may not.
  case "$_rel" in
    /*|[A-Za-z]:*) echo "$1 : \"$_rel\" is an absolute path — a committed absolute registration is a dead hook on every machine but the one it was written on"; return 0;;
  esac
  if ! case_exact_path "$DIST" "$_rel"; then
    echo "$1 : \"$_rel\" does not exist in this dist"
    return 0
  fi
  # Suffix tests are case-insensitive in BOTH twins: PowerShell's -match is case-insensitive by
  # default while bash `case` is not, so a `.PS1` registration used to be judged differently by each
  # leg (B-59's case-sensitivity class).
  # ${var,,} rather than a printf|tr pipeline: two fewer forks per reference, same ASCII result.
  _lower="${_rel,,}"
  case "$_lower" in
    *.ps1) _twin="${_rel%????}.sh" ;;
    *.sh)  _twin="${_rel%???}.ps1" ;;
    *)     return 0 ;;
  esac
  # Invariant #3: a .ps1 registration whose .sh sibling is missing is a half-shipped hook.
  case_exact_path "$DIST" "$_twin" || echo "$1 : \"$_rel\" exists but its twin \"$_twin\" does not"
}

# Registration records are emitted as: <kind><TAB><base64 of the value>
# kind is PROBLEM (value = the finding) or command/bash/powershell (value = the registration string).
#
# The value is BASE64 so the framing cannot collide with the content. Spelling the records as plain
# tab-separated text failed twice in one afternoon: jq's @tsv escapes tabs, newlines and
# BACKSLASHES while python3 prints them raw, so the two branches disagreed on 14 of every dist's 26
# records (all the hooks.json Windows paths), and a hand-spelled "PROBLEM\t" emitted a literal
# backslash-t under jq, which made every problem record parse as a valid handler and print a false
# green. Base64 removes the class rather than patching the instances.
emit_records() {   # $1 = registration file (dist-relative)
  _rf=$1
  if [ "$JSON_TOOL" = python3 ]; then
    python3 - "$_rf" "$DIST/$_rf" <<'PY'
import base64, json, sys
rf, path = sys.argv[1:]
def emit(kind, value):
    print('%s\t%s' % (kind, base64.b64encode(value.encode('utf-8')).decode('ascii')))
try:
    doc = json.load(open(path, encoding='utf-8'))
except Exception as exc:
    emit('PROBLEM', '%s : registration file is unparseable (%s)' % (rf, exc)); raise SystemExit(0)
hooks = doc.get('hooks')
if not isinstance(hooks, dict):
    emit('PROBLEM', '%s : registration file has no hooks object' % rf); raise SystemExit(0)
if rf.startswith('.claude/'):
    for ev, groups in hooks.items():
        if not isinstance(groups, list):
            emit('PROBLEM', "%s : hook event '%s' must be an array" % (rf, ev)); continue
        for group in groups:
            if not isinstance(group, dict) or not isinstance(group.get('hooks'), list):
                emit('PROBLEM', "%s : hook group in event '%s' has no hooks array" % (rf, ev)); continue
            for entry in group['hooks']:
                if not isinstance(entry, dict) or entry.get('type') != 'command' or not entry.get('command'):
                    emit('PROBLEM', "%s : hook entry must have type 'command' and a non-empty command" % rf)
                else:
                    emit('command', entry['command'])
else:
    for ev, entries in hooks.items():
        if not isinstance(entries, list):
            emit('PROBLEM', "%s : hook event '%s' must be an array" % (rf, ev)); continue
        for entry in entries:
            if not isinstance(entry, dict):
                emit('PROBLEM', "%s : hook entry in event '%s' is not an object" % (rf, ev)); continue
            b, p = entry.get('bash'), entry.get('powershell')
            if not b and not p:
                emit('PROBLEM', '%s : hook entry must have at least one bash/powershell leg; a deliberate single-leg entry requires updating this check on purpose' % rf); continue
            if not b or not p:
                emit('PROBLEM', '%s : hook entry has only one bash/powershell leg; a deliberate single-leg entry requires updating this check on purpose' % rf)
            if b: emit('bash', b)
            if p: emit('powershell', p)
PY
  else
    jq -r --arg rf "$_rf" '
      def rec(kind; value): kind + "\t" + (value | @base64);
      def problem(msg): rec("PROBLEM"; $rf + " : " + msg);
      if (.hooks | type) != "object" then problem("registration file has no hooks object")
      elif ($rf | startswith(".claude/")) then
        .hooks | to_entries[] | . as $e
        | if ($e.value | type) != "array" then problem("hook event '\''" + $e.key + "'\'' must be an array")
          else $e.value[]
          | if (type != "object") or ((.hooks | type) != "array")
            then problem("hook group in event '\''" + $e.key + "'\'' has no hooks array")
            else .hooks[]
            | if (type != "object") or (.type != "command") or ((.command // "") == "")
              then problem("hook entry must have type '\''command'\'' and a non-empty command")
              else rec("command"; .command) end
            end
          end
      else
        .hooks | to_entries[] | . as $e
        | if ($e.value | type) != "array" then problem("hook event '\''" + $e.key + "'\'' must be an array")
          else $e.value[]
          | if type != "object" then problem("hook entry in event '\''" + $e.key + "'\'' is not an object")
          elif ((.bash // "") == "") and ((.powershell // "") == "")
          then problem("hook entry must have at least one bash/powershell leg; a deliberate single-leg entry requires updating this check on purpose")
          else
            (if ((.bash // "") == "") or ((.powershell // "") == "")
             then problem("hook entry has only one bash/powershell leg; a deliberate single-leg entry requires updating this check on purpose")
             else empty end),
            (if ((.bash // "") != "") then rec("bash"; .bash) else empty end),
            (if ((.powershell // "") != "") then rec("powershell"; .powershell) else empty end)
          end
          end
      end' "$DIST/$_rf"
  fi
}

# GNU coreutils spells it -d, BSD/macOS -D. Probe rather than assume, and FATAL rather than let a
# failed decode look like an empty registration file.
if printf 'eA==' | base64 -d >/dev/null 2>&1; then B64D='base64 -d'
elif printf 'eA==' | base64 -D >/dev/null 2>&1; then B64D='base64 -D'
else echo "FATAL: no usable base64 decoder (tried -d and -D)." >&2; exit 2
fi

regproblems=""
regcount=0
settingscount=0
windowscount=0
hookentries=0
for rf in .claude/settings.json .claude/settings.windows.json .github/hooks/hooks.json; do
  if [ ! -f "$DIST/$rf" ]; then
    regproblems="$regproblems
$rf : registration file missing from this dist"
    continue
  fi
  # Materialize the record stream so the PARSER'S EXIT STATUS can be inspected. Reading it straight
  # from a process substitution discards that status, so a parser that emitted three records and
  # then died left handlers > 0 and the per-file guard satisfied — B-92's own defect, recreated
  # inside its fix.
  recfile=$(mktemp "${TMPDIR:-/tmp}/validate-dist-records.XXXXXX") || { echo "FATAL: cannot create a temporary file for the record stream." >&2; exit 2; }
  emit_records "$rf" > "$recfile" 2>/dev/null
  parserstatus=$?
  if [ "$parserstatus" -ne 0 ]; then
    # Same wording as the PowerShell twin's ConvertFrom-Json catch and python3's own guard, so all
    # three legs report one substring for "we could not read this file's registrations". jq cannot
    # distinguish invalid JSON from an internal error, and for this check the consequence is the same.
    regproblems="$regproblems
$rf : registration file is unparseable (parser $JSON_TOOL exited $parserstatus; its records are incomplete)"
    rm -f "$recfile"
    continue
  fi
  handlers=0
  while IFS=$'\t' read -r kind encoded; do
    # jq on Windows writes CRLF, so the trailing CR would ride along into the base64 and break the
    # decode. Strip it at the boundary so both parser branches yield the same fields.
    kind=${kind%$'\r'}; encoded=${encoded%$'\r'}
    [ -n "$kind" ] || continue
    # A decode failure must be a FINDING, not an empty value: silently substituting '' would report
    # "no -File argument" for a registration that is in fact fine, or hide one that is not.
    if ! value=$(printf '%s' "$encoded" | $B64D 2>/dev/null); then
      regproblems="$regproblems
$rf : registration record could not be decoded (kind '$kind')"
      continue
    fi
    if [ "$kind" = PROBLEM ]; then
      regproblems="$regproblems
$value"
      continue
    fi
    # A record whose kind is not one we emit means the stream shape changed under us. Counting it as
    # a handler is what let a malformed record restore the total and print a false green.
    case "$kind" in
      command|bash|powershell) ;;
      *) regproblems="$regproblems
$rf : unparseable registration record (kind '$kind')"; continue ;;
    esac
    handlers=$((handlers+1)); regcount=$((regcount+1))
    if [ "$kind" = command ]; then
      interp=$(printf '%s' "$value" | awk '{print tolower($1)}')
      case "$interp" in
        pwsh|powershell|bash) ;;
        *) regproblems="$regproblems
$rf : unrecognised interpreter '$interp' in: $value" ;;
      esac
      # -File accepts a quoted value: "-File \"a b.ps1\"" is valid JSON and the required spelling for
      # a path containing a space. The old textual regex truncated it to a lone backslash, which the
      # absolute-path exemption then swallowed (B-92 mechanism 3).
      script=$(printf '%s' "$value" | sed -nE 's/.*[[:space:]]-[Ff][Ii][Ll][Ee][[:space:]]+("([^"]+)"|([^[:space:]]+)).*/\2\3/p')
      if [ -z "$script" ]; then
        regproblems="$regproblems
$rf : no -File argument in: $value"
        continue
      fi
    else
      script=$(printf '%s' "$value" | awk '{print $1}')
    fi
    out=$(check_hook_ref "$rf" "$script")
    [ -z "$out" ] || regproblems="$regproblems
$out"
  done < "$recfile"
  rm -f "$recfile"
  # Per-FILE guard. The old floor was a single total across all three files (15 of a real 26), so
  # losing every registration in one file still cleared it (B-92 mechanism 1).
  [ "$handlers" -gt 0 ] || regproblems="$regproblems
$rf : registration file yields zero handlers"
  case "$rf" in
    .claude/settings.json)         settingscount=$handlers ;;
    .claude/settings.windows.json) windowscount=$handlers ;;
    *)                             hookentries=$((handlers / 2)) ;;
  esac
done
# ValidateDist.Tests.ps1 sets this to capture the raw record stream and diff the two parser branches
# against each other. Without it, whichever tool a box has decides which branch is ever executed.
if [ -n "${VALIDATE_DIST_RECORD_STREAM:-}" ]; then
  for rf in .claude/settings.json .claude/settings.windows.json .github/hooks/hooks.json; do
    [ -f "$DIST/$rf" ] || continue
    emit_records "$rf" | sed 's/\r$//'
  done > "$VALIDATE_DIST_RECORD_STREAM"
fi
regprobcount=$(printf '%s\n' "$regproblems" | grep -c . || true)
if [ "$regprobcount" -gt 0 ]; then
  fail "hook registrations reference $regprobcount missing or invalid target(s) in $DIST. A registration that cannot start is a hook that silently never runs."
  printf '%s\n' "$regproblems" | grep . | sort -u | sed 's/^/  [hook-registration] /'
else
  # The parser is named so a caller can assert WHICH branch ran; a comparison of two streams that
  # cannot tell the branches apart proves nothing.
  ok "all $regcount hook registrations resolve (settings.json $settingscount, settings.windows.json $windowscount, hooks.json $hookentries entries × 2 legs; parsed by $JSON_TOOL)"
fi
fi

_report_timings
echo ""
if [ "$failed" -gt 0 ]; then echo "$failed dist validation check(s) FAILED for $DIST."; exit 1; fi
echo "All dist validation checks passed for $DIST."
exit 0
