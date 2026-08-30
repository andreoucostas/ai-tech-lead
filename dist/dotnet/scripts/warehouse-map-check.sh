#!/usr/bin/env bash
set -u
root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"; here=$(cd "$(dirname "$0")" && pwd); signals="$here/warehouse-signals.tsv"
[ -f "$signals" ] && [ -r "$signals" ] || { echo 'warehouse-signals.tsv is missing or unreadable' >&2; exit 2; }
signal_text=$(<"$signals") || { echo 'Could not read warehouse-signals.tsv; warehouse applicability cannot be determined.' >&2; exit 2; }
find_cmd=find; [ -x /usr/bin/find ] && find_cmd=/usr/bin/find
all_files=$("$find_cmd" "$root" \( -type d \( -iname .git -o -iname node_modules -o -iname bower_components -o -iname vendor -o -iname bin -o -iname obj -o -iname dist -o -iname build -o -iname out -o -iname .next -o -iname .angular -o -iname .nx -o -iname coverage \) -prune \) -o \( -type f \( -iname '*.sql' -o -iname '*.sqlproj' -o -iname 'dbt_project.yml' -o -iname '*.yml' -o -iname '*.yaml' -o -iname '*.json' \) -print \) 2>/dev/null)
find_status=$?
if [ "$find_status" -ne 0 ]; then
  echo "Could not enumerate warehouse artifacts with find (exit $find_status) — this is a host/resource problem, so warehouse applicability cannot be determined." >&2
  exit 2
fi
files=$(printf '%s\n' "$all_files" | grep -Ei '\.sql(proj)?$|/dbt_project\.yml$|/(etl|pipelines?|warehouse|datafactory|synapse|dags?)/|/(pipeline|datafactory|synapse|dag)[^/]*\.(yml|yaml|json)$')
grep_status=$?
if [ "$grep_status" -gt 1 ]; then
  echo "Could not enumerate warehouse artifacts with grep (exit $grep_status) — this is a host/resource problem, so warehouse applicability cannot be determined." >&2
  exit 2
fi
hits=0
while IFS=$'\t' read -r category pattern; do
  case "$category" in ''|'#'*) continue ;; esac
  if [ -z "$pattern" ]; then echo "invalid warehouse signal: $category" >&2; exit 2; fi
  case "$pattern" in *$'\t'*) echo "invalid warehouse signal: $category" >&2; exit 2 ;; esac
  matched=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if ! content=$(cat "$f" 2>/dev/null); then
      echo "Could not read warehouse artifact '$f'; warehouse applicability cannot be determined." >&2
      exit 2
    fi
    { basename "$f"; printf '%s\n' "$content"; } | grep -Eiq "$pattern"
    match_status=$?
    if [ "$match_status" -eq 0 ]; then matched=1; break; fi
    if [ "$match_status" -gt 1 ]; then
      echo "Could not classify warehouse artifact '$f' with grep (exit $match_status); warehouse applicability cannot be determined." >&2
      exit 2
    fi
  done <<EOF
$files
EOF
  [ "$matched" -eq 1 ] && hits=$((hits+1))
done <<EOF
$signal_text
EOF
if [ "$hits" -lt 2 ]; then echo "WAREHOUSE_MAP not-applicable ($hits independent signal(s))"; exit 0; fi
map="$root/docs/warehouse-map.md"
if [ ! -f "$map" ]; then
  echo 'WAREHOUSE_MAP missing - run /map-warehouse or inspect the live schema before a warehouse write.'; exit 1
fi
newer=0
while IFS= read -r f; do [ -n "$f" ] && [ "$f" -nt "$map" ] && newer=$((newer+1)); done <<EOF
$files
EOF
if [ "$newer" -gt 0 ]; then echo "WAREHOUSE_MAP stale ($newer warehouse artifact(s) newer than the map)"; exit 1; fi
echo "WAREHOUSE_MAP current ($hits independent signal categories)"; exit 0
