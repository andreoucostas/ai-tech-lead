#!/usr/bin/env bash
set -u
root="${1:-}"
# Root comes from the argument (docs-sync-check passes it) or self-anchors to scripts/.. — never
# from stdin. Reading stdin here made an interactive docs-sync-check run block waiting for a line.
[ -n "$root" ] || root="$(cd "$(dirname "$0")/.." && pwd)"
root="${root//\\//}"
if command -v cygpath >/dev/null 2>&1 && [[ "$root" =~ ^[A-Za-z]:/ ]]; then root="$(cygpath -u "$root")"; fi
wiki="$root/docs/wiki"; index="$wiki/INDEX.md"; fails=0
fail(){ echo "FAIL: $*"; fails=$((fails+1)); }; warn(){ echo "WARN: $*"; }
# Portable calendar validation. BSD/macOS `date` has no GNU `-d <datestring>` and BSD strptime is
# lenient, so reject non-calendar dates (e.g. 2026-02-30) with a pure-shell month-length + leap-year
# check that is deterministic on every platform. Input is already ^\d{4}-\d{2}-\d{2}$; 10# forces
# base-10 so 08/09 don't parse as invalid octal.
valid_cal(){ local y=$((10#${1:0:4})) m=$((10#${1:5:2})) d=$((10#${1:8:2})) dim; [ "$m" -ge 1 ]&&[ "$m" -le 12 ]||return 1; [ "$d" -ge 1 ]||return 1; case "$m" in 1|3|5|7|8|10|12)dim=31;;4|6|9|11)dim=30;;2)if [ $((y%4)) -eq 0 ]&&{ [ $((y%100)) -ne 0 ]||[ $((y%400)) -eq 0 ]; };then dim=29;else dim=28;fi;;esac; [ "$d" -le "$dim" ]; }
invisible=$'(\xe2\x80[\x8b-\x8f]|\xe2\x80[\xaa-\xae]|\xe2\x81[\xa0-\xaf])'
signal="(ignore|disregard|override|forget|instead of|regardless of|do not tell|system prompt|you are|you must|<!--[^>]*(do|run|execute|ignore|must)|[A-Za-z0-9+/]{80,}={0,2}|$invisible|https?://[^ ]*(exfil|webhook|collect|upload))"
index_re='^- \[(gotcha|context|recipe|failed-approach)\] \[([a-z0-9]+(-[a-z0-9]+)*)\]\(\./([a-z0-9]+(-[a-z0-9]+)*)\.md\) — (.+)$'
[ -f "$index" ] || { fail 'docs/wiki/INDEX.md is missing'; echo "$fails wiki-check failure(s)."; exit 1; }
tmp="${TMPDIR:-/tmp}/wiki-check-$$"; trap 'rm -rf "$tmp"' EXIT; mkdir -p "$tmp"
sed '1s/^﻿//;s/\r$//' "$index" > "$tmp/index"; grep '^- \[' "$tmp/index" > "$tmp/lines" || true; : > "$tmp/slugs"
while IFS= read -r line; do
 if [[ "$line" =~ $index_re ]] && [ "${BASH_REMATCH[2]}" = "${BASH_REMATCH[4]}" ]; then echo "${BASH_REMATCH[2]}" >> "$tmp/slugs"; else fail "invalid INDEX line: $line"; fi
 echo "$line" | LC_ALL=C grep -Eqi "$signal" && fail "injection marker in INDEX line: $line"
done < "$tmp/lines"
LC_ALL=C sort "$tmp/slugs" > "$tmp/sorted"; cmp -s "$tmp/slugs" "$tmp/sorted" || fail 'INDEX entries are not sorted by slug'
# Staleness cutoff (90 days ago) as a YYYY-MM-DD string, computed once. Zero-padded ISO dates compare
# correctly as plain strings, so the per-entry check is a lexical compare. Feature-detect GNU
# `date -d` then BSD `date -v`; if neither yields a valid date, leave cutoff empty and skip the
# staleness WARN rather than failing valid entries.
cutoff=$(date -d '90 days ago' +%Y-%m-%d 2>/dev/null)
case "$cutoff" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]);;*)cutoff=$(date -v-90d +%Y-%m-%d 2>/dev/null);;esac
case "$cutoff" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]);;*)cutoff="";;esac
count=0
for file in "$wiki"/*.md; do [ -e "$file" ] || continue; base="$(basename "$file")"; [ "$base" = INDEX.md ]&&continue; [ "$base" = _template.md ]&&continue; count=$((count+1)); slug="${base%.md}"; grep -Fxq "$slug" "$tmp/slugs" || fail "entry file has no INDEX line: $slug"
 sed '1s/^﻿//;s/\r$//' "$file" > "$tmp/entry"; lines=$(wc -l < "$tmp/entry"); [ "$lines" -le 80 ]||warn "$base exceeds 80 lines"
 first=$(sed -n '1p' "$tmp/entry"); end=$(awk 'NR>1&&$0=="---"{print NR;exit}' "$tmp/entry"); if [ "$first" != '---' ]||[ -z "$end" ];then fail "$base: malformed frontmatter";continue;fi
 for key in name description type scope status last-verified;do hits=$(sed -n "2,$((end-1))p" "$tmp/entry"|grep -c "^$key: "||true);[ "$hits" -eq 1 ]||fail "$base: missing or duplicate $key";done
 name=$(sed -n "2,$((end-1))p" "$tmp/entry"|sed -n 's/^name: //p'); description=$(sed -n "2,$((end-1))p" "$tmp/entry"|sed -n 's/^description: //p'); type=$(sed -n "2,$((end-1))p" "$tmp/entry"|sed -n 's/^type: //p'); status=$(sed -n "2,$((end-1))p" "$tmp/entry"|sed -n 's/^status: //p'); last_verified=$(sed -n "2,$((end-1))p" "$tmp/entry"|sed -n 's/^last-verified: //p')
 [ "${name:-}" = "$slug" ]||fail "$base: name must equal filename stem"; case "${type:-}" in gotcha|context|recipe|failed-approach);;*)fail "$base: invalid type";;esac;case "${status:-}" in verified|suspected|unverified);;*)fail "$base: invalid status";;esac
 if [[ "${last_verified:-}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]&&valid_cal "$last_verified";then [ -n "$cutoff" ]&&[[ "$last_verified" < "$cutoff" ]]&&warn "$base last verified $last_verified";else fail "$base: invalid last-verified";fi
 echo "${description:-}"|LC_ALL=C grep -Eqi "$signal"&&fail "$base: injection marker in description";tail -n "+$((end+1))" "$tmp/entry"|LC_ALL=C grep -Eqi "$signal"&&warn "$base: injection marker in body"
done
[ "$count" -le 100 ] || warn "$count entries exceeds 100"
while IFS= read -r slug; do
  [ -f "$wiki/$slug.md" ] || fail "INDEX entry has no file: $slug"
done < "$tmp/slugs"
if [ "$fails" -gt 0 ];then echo "$fails wiki-check failure(s).";exit 1;fi;echo 'wiki-check passed.';exit 0
