#!/usr/bin/env bash
set -u
# Read-only validation of Known Hazard Areas. Only literal repository-root-relative paths satisfy
# row evidence; URLs, symbols, and wildcard expressions may be ancillary but prove no path exists.
# Root comes from the argument (docs-sync-check passes it) or self-anchors to scripts/.., never stdin.
root="${1:-}"; [ -n "$root" ] || root="$(cd "$(dirname "$0")/.." && pwd)"
root="${root//\\//}"; if command -v cygpath >/dev/null 2>&1 && [[ "$root" =~ ^[A-Za-z]:/ ]]; then root="$(cygpath -u "$root")"; fi
context="$root/FRAMEWORK-CONTEXT.md"; fails=0
fail(){ echo "FAIL: $*"; fails=$((fails+1)); }
# Portable calendar validation. BSD/macOS `date` has no GNU `-d <datestring>` and BSD strptime is
# lenient, so reject non-calendar dates (e.g. 2026-02-30) with a pure-shell month-length + leap-year
# check that is deterministic on every platform. Input is already ^\d{4}-\d{2}-\d{2}$; 10# forces
# base-10 so 08/09 don't parse as invalid octal.
valid_cal(){ local y=$((10#${1:0:4})) m=$((10#${1:5:2})) d=$((10#${1:8:2})) dim; [ "$y" -ge 1 ]||return 1; [ "$m" -ge 1 ]&&[ "$m" -le 12 ]||return 1; [ "$d" -ge 1 ]||return 1; case "$m" in 1|3|5|7|8|10|12)dim=31;;4|6|9|11)dim=30;;2)if [ $((y%4)) -eq 0 ]&&{ [ $((y%100)) -ne 0 ]||[ $((y%400)) -eq 0 ]; };then dim=29;else dim=28;fi;;esac; [ "$d" -le "$dim" ]; }
reviewed_status_re='^\[REVIEWED: not a hazard — ([0-9]{4}-[0-9]{2}-[0-9]{2})\]$'
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
 status_date=''
 case "$status" in '[VERIFIED]'|'[SUSPECTED]'|'[UNVERIFIED]') ;;
  *)if [[ "$status" =~ $reviewed_status_re ]];then embedded_date="${BASH_REMATCH[1]}";if valid_cal "$embedded_date";then status_date="$embedded_date";else fail "hazard row has an invalid reviewed Status date '$embedded_date' (expected a calendar-valid YYYY-MM-DD): $area";fi
    else fail "hazard row has an unrecognised Status '$status' (expected [VERIFIED], [SUSPECTED], [UNVERIFIED], or [REVIEWED: not a hazard — YYYY-MM-DD]): $area";fi;;esac
 reviewed_ok=0;if [[ "$reviewed" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]&&valid_cal "$reviewed";then reviewed_ok=1;else fail "hazard row has an invalid Reviewed date '$reviewed' (expected YYYY-MM-DD): $area";fi
 if [ -n "$status_date" ]&&[ "$reviewed_ok" -eq 1 ]&&[ "$status_date" != "$reviewed" ];then fail "hazard row reviewed Status date '$status_date' does not match Reviewed column '$reviewed': $area";fi
 : > "$tmp/candidates";rest="$area"
 while [[ "$rest" =~ \`([^\`]*)\` ]];do printf '%s\n' "${BASH_REMATCH[1]}" >> "$tmp/candidates";rest="${rest/\`${BASH_REMATCH[1]}\`/ }";done
 printf '%s\n' "$rest"|tr ',[:space:]' '\n' >> "$tmp/candidates"
 literal_candidates=0;invalid_path=0
 while IFS= read -r candidate;do
  candidate=$(printf '%s' "$candidate"|sed "s/^[()\"']*//;s/[()\"']*$//;s/[,.;:]*$//")
  if [[ "$candidate" =~ ^[A-Za-z][A-Za-z0-9+.-]*:// ]]||[[ "$candidate" = www.* ]]||[ -z "$candidate" ];then continue;fi
  if [[ "$candidate" = *'*'* ]]||[[ "$candidate" = *'?'* ]];then continue;fi
  candidate="${candidate//\\//}";candidate="${candidate#./}"
  if [[ "$candidate" != */* ]]&&! [[ "$candidate" =~ \.[A-Za-z0-9]{1,10}$ ]];then continue;fi
  if [[ "$candidate" = /* ]]||[[ "$candidate" =~ ^[A-Za-z]:/ ]]||[[ "$candidate" = *'//'* ]]||[[ "/$candidate/" = *'/../'* ]]||[[ "/$candidate/" = *'/./'* ]];then fail "hazard row names a path that is not a safe repository-root-relative path: $candidate (row: $area)";invalid_path=1;continue;fi
  literal_candidates=$((literal_candidates+1))
  [ -e "$root/$candidate" ]||fail "hazard row names a path that does not exist: $candidate (row: $area)"
 done < "$tmp/candidates"
 if [ "$literal_candidates" -eq 0 ]&&[ "$invalid_path" -eq 0 ];then fail "hazard row must include at least one exact resolving repository-root-relative path: $area";fi
done < "$tmp/context"
if [ "$fails" -gt 0 ];then echo "$fails hazard-check failure(s).";exit 1;fi;echo 'hazard-check passed.';exit 0
