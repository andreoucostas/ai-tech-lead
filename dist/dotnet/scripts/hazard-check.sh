#!/usr/bin/env bash
set -u
# Read-only validation of Known Hazard Areas. Wildcards validate only their longest leading
# wildcard-free directory prefix; matching the wildcard expression itself is deliberately out of scope.
# Root comes from the argument (docs-sync-check passes it) or self-anchors to scripts/.., never stdin.
root="${1:-}"; [ -n "$root" ] || root="$(cd "$(dirname "$0")/.." && pwd)"
root="${root//\\//}"; if command -v cygpath >/dev/null 2>&1 && [[ "$root" =~ ^[A-Za-z]:/ ]]; then root="$(cygpath -u "$root")"; fi
# Git Bash can inherit a PATH where Windows find.exe wins over POSIX find. The Windows command
# treats the root/options as text-search arguments, producing an empty filename index.
find_cmd=find
[ -x /usr/bin/find ] && find_cmd=/usr/bin/find
context="$root/FRAMEWORK-CONTEXT.md"; fails=0
fail(){ echo "FAIL: $*"; fails=$((fails+1)); }
# Portable calendar validation. BSD/macOS `date` has no GNU `-d <datestring>` and BSD strptime is
# lenient, so reject non-calendar dates (e.g. 2026-02-30) with a pure-shell month-length + leap-year
# check that is deterministic on every platform. Input is already ^\d{4}-\d{2}-\d{2}$; 10# forces
# base-10 so 08/09 don't parse as invalid octal.
valid_cal(){ local y=$((10#${1:0:4})) m=$((10#${1:5:2})) d=$((10#${1:8:2})) dim; [ "$m" -ge 1 ]&&[ "$m" -le 12 ]||return 1; [ "$d" -ge 1 ]||return 1; case "$m" in 1|3|5|7|8|10|12)dim=31;;4|6|9|11)dim=30;;2)if [ $((y%4)) -eq 0 ]&&{ [ $((y%100)) -ne 0 ]||[ $((y%400)) -eq 0 ]; };then dim=29;else dim=28;fi;;esac; [ "$d" -le "$dim" ]; }
[ -f "$context" ] || { echo 'hazard-check skipped (no FRAMEWORK-CONTEXT.md).'; exit 0; }
tmp="${TMPDIR:-/tmp}/hazard-check-$$"; trap 'rm -rf "$tmp"' EXIT; mkdir -p "$tmp"
sed '1s/^﻿//;s/\r$//' "$context" > "$tmp/context"
pending=0;has_section=0
while IFS= read -r scan;do case "$scan" in *KNOWN_HAZARD_AREAS_PENDING*)pending=1;;esac;if [[ "$scan" =~ ^##\ Known\ Hazard\ Areas[[:space:]]*$ ]];then has_section=1;fi;done < "$tmp/context"
[ "$pending" -eq 0 ]||{ echo 'hazard-check skipped (hazard table not yet drafted).';exit 0; }
[ "$has_section" -eq 1 ]||{ echo 'hazard-check skipped (no Known Hazard Areas section).';exit 0; }
in_hazards=0
while IFS= read -r line; do
 if [[ "$line" =~ ^##\ Known\ Hazard\ Areas[[:space:]]*$ ]];then in_hazards=1;continue;fi
 if [ "$in_hazards" -eq 1 ];then case "$line" in '## '*)break;;esac;fi
 [ "$in_hazards" -eq 1 ]||continue;case "$line" in \|*);;*)continue;;esac
 pipes=${line//[^|]/}; count=$((${#pipes}+1))
 area=$(printf '%s' "$line"|cut -d '|' -f 2|sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
 [ "$area" = 'Area / file(s)' ]&&continue
 # Separator row = at least one non-empty cell, and every non-empty cell is only '-' and ':'.
 # The "at least one" half is load-bearing: deleting -/: unconditionally also swallowed a row whose
 # cells are ALL empty, which the .ps1 twin reports. That divergence passed a green bash run.
 bare=$(printf '%s' "$line"|tr -d '|[:space:]')
 if [ -n "$bare" ];then compact=$(printf '%s' "$bare"|tr -d ':-');[ -z "$compact" ]&&continue;fi
 [ "$area" = '_(drafted by /bootstrap)_' ]&&continue
 if [ "$count" -ne 6 ];then fail "hazard row does not have 4 cells: $line";continue;fi
 status=$(printf '%s' "$line"|cut -d '|' -f 4|sed 's/^[[:space:]]*//;s/[[:space:]]*$//');reviewed=$(printf '%s' "$line"|cut -d '|' -f 5|sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
 case "$status" in '[VERIFIED]'|'[SUSPECTED]'|'[UNVERIFIED]'|'[REVIEWED: not a hazard'*) ;; *)fail "hazard row has an unrecognised Status '$status' (expected [VERIFIED], [SUSPECTED], [UNVERIFIED], or [REVIEWED: not a hazard ...]): $area";;esac
 if [[ "$reviewed" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]&&valid_cal "$reviewed";then :;else fail "hazard row has an invalid Reviewed date '$reviewed' (expected YYYY-MM-DD): $area";fi
 : > "$tmp/candidates";rest="$area"
 while [[ "$rest" =~ \`([^\`]*)\` ]];do printf '%s\n' "${BASH_REMATCH[1]}" >> "$tmp/candidates";rest="${rest/\`${BASH_REMATCH[1]}\`/ }";done
 printf '%s\n' "$rest"|tr ',[:space:]' '\n' >> "$tmp/candidates"
 while IFS= read -r candidate;do
  candidate=$(printf '%s' "$candidate"|sed "s/^[()\"']*//;s/[()\"']*$//;s/[,.;:]*$//")
  if [[ "$candidate" != */* ]]&&! [[ "$candidate" =~ \.[A-Za-z0-9]{1,10}$ ]];then continue;fi
  if [[ "$candidate" =~ ^[A-Za-z][A-Za-z0-9+.-]*:// ]]||[[ "$candidate" = www.* ]]||[ -z "$candidate" ];then continue;fi
  candidate="${candidate//\\//}";candidate="${candidate#./}"
  # Longest leading wildcard-free directory prefix, via parameter expansion only. An earlier
  # `for part in $candidate` with IFS=/ left $candidate unquoted, so bash PATHNAME-EXPANDED the
  # wildcard against the cwd before splitting -- `src/app/**/*.component.ts` became the cwd's own
  # file list joined by '/'. Never word-split a value that may contain a glob.
  # Resolution mode is decided BEFORE wildcard truncation: 'src/ap*p/x' truncates to 'src', which has
  # no '/' left but is still a directory path, not a bare filename.
  case "$candidate" in */*)rooted=1;;*)rooted=0;;esac
  if [[ "$candidate" = *'*'* ]]||[[ "$candidate" = *'?'* ]];then prefix="${candidate%%[*?]*}"
   case "$prefix" in */)prefix="${prefix%/}";;*/*)prefix="${prefix%/*}";;*)prefix="";;esac
   candidate="$prefix";[ -n "$candidate" ]||continue;fi
  # A candidate with no '/' is a bare filename -- see the .ps1 twin's comment for why those resolve
  # tree-wide rather than against the root. `find -printf` is GNU-only, so strip directories with sed.
  if [ "$rooted" -eq 1 ];then [ -e "$root/$candidate" ]||fail "hazard row names a path that does not exist: $candidate (row: $area)";continue;fi
  if [ ! -f "$tmp/names" ];then "$find_cmd" "$root" -type f ! -path '*/.git/*' ! -path '*/node_modules/*' ! -path '*/bin/*' ! -path '*/obj/*' ! -path '*/dist/*' -print 2>/dev/null|sed 's|.*/||' > "$tmp/names";fi
  if ! grep -Fxq -- "$candidate" "$tmp/names";then fail "hazard row names a path that does not exist: $candidate (row: $area)";fi
 done < "$tmp/candidates"
done < "$tmp/context"
if [ "$fails" -gt 0 ];then echo "$fails hazard-check failure(s).";exit 1;fi;echo 'hazard-check passed.';exit 0
