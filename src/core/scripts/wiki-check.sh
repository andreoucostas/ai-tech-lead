#!/usr/bin/env bash
set -u
root="${1:-}"; if [ -z "$root" ]; then IFS= read -r root || true; fi
[ -n "$root" ] || root="$(cd "$(dirname "$0")/.." && pwd)"
root="${root//\\//}"
if command -v cygpath >/dev/null 2>&1 && [[ "$root" =~ ^[A-Za-z]:/ ]]; then root="$(cygpath -u "$root")"; fi
wiki="$root/docs/wiki"; index="$wiki/INDEX.md"; fails=0
fail(){ echo "FAIL: $*"; fails=$((fails+1)); }; warn(){ echo "WARN: $*"; }
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
sort "$tmp/slugs" > "$tmp/sorted"; cmp -s "$tmp/slugs" "$tmp/sorted" || fail 'INDEX entries are not sorted by slug'
count=0
for file in "$wiki"/*.md; do [ -e "$file" ] || continue; base="$(basename "$file")"; [ "$base" = INDEX.md ]&&continue; [ "$base" = _template.md ]&&continue; count=$((count+1)); slug="${base%.md}"; grep -Fxq "$slug" "$tmp/slugs" || fail "entry file has no INDEX line: $slug"
 sed '1s/^﻿//;s/\r$//' "$file" > "$tmp/entry"; lines=$(wc -l < "$tmp/entry"); [ "$lines" -le 80 ]||warn "$base exceeds 80 lines"
 first=$(sed -n '1p' "$tmp/entry"); end=$(awk 'NR>1&&$0=="---"{print NR;exit}' "$tmp/entry"); if [ "$first" != '---' ]||[ -z "$end" ];then fail "$base: malformed frontmatter";continue;fi
 for key in name description type scope status last-verified;do hits=$(sed -n "2,$((end-1))p" "$tmp/entry"|grep -c "^$key: "||true);[ "$hits" -eq 1 ]||fail "$base: missing or duplicate $key";done
 name=$(sed -n "2,$((end-1))p" "$tmp/entry"|sed -n 's/^name: //p'); description=$(sed -n "2,$((end-1))p" "$tmp/entry"|sed -n 's/^description: //p'); type=$(sed -n "2,$((end-1))p" "$tmp/entry"|sed -n 's/^type: //p'); status=$(sed -n "2,$((end-1))p" "$tmp/entry"|sed -n 's/^status: //p'); last_verified=$(sed -n "2,$((end-1))p" "$tmp/entry"|sed -n 's/^last-verified: //p')
 [ "${name:-}" = "$slug" ]||fail "$base: name must equal filename stem"; case "${type:-}" in gotcha|context|recipe|failed-approach);;*)fail "$base: invalid type";;esac;case "${status:-}" in verified|suspected|unverified);;*)fail "$base: invalid status";;esac
 if [[ "${last_verified:-}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]&&date -d "$last_verified" +%s >/dev/null 2>&1;then cutoff=$(date -d '90 days ago' +%s);[ "$(date -d "$last_verified" +%s)" -ge "$cutoff" ]||warn "$base last verified $last_verified";else fail "$base: invalid last-verified";fi
 echo "${description:-}"|LC_ALL=C grep -Eqi "$signal"&&fail "$base: injection marker in description";tail -n "+$((end+1))" "$tmp/entry"|LC_ALL=C grep -Eqi "$signal"&&warn "$base: injection marker in body"
done
[ "$count" -le 100 ] || warn "$count entries exceeds 100"
while IFS= read -r slug; do
  [ -f "$wiki/$slug.md" ] || fail "INDEX entry has no file: $slug"
done < "$tmp/slugs"
if [ "$fails" -gt 0 ];then echo "$fails wiki-check failure(s).";exit 1;fi;echo 'wiki-check passed.';exit 0
