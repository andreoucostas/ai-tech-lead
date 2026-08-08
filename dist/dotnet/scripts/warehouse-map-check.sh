#!/usr/bin/env bash
set -u
root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"; here=$(cd "$(dirname "$0")" && pwd); signals="$here/warehouse-signals.tsv"
[ -f "$signals" ] || { echo 'warehouse-signals.tsv is missing' >&2; exit 2; }
files=$(find "$root" -type f \( -name '*.sql' -o -name '*.sqlproj' -o -name 'dbt_project.yml' -o -name '*.yml' -o -name '*.yaml' -o -name '*.json' \) ! -path '*/.git/*' ! -path '*/node_modules/*' ! -path '*/bin/*' ! -path '*/obj/*' ! -path '*/dist/*' 2>/dev/null | grep -Ei '\.sql(proj)?$|/dbt_project\.yml$|/(etl|pipelines?|warehouse|datafactory|synapse|dags?)/|/(pipeline|datafactory|synapse|dag)[^/]*\.(yml|yaml|json)$' || true)
hits=0
while IFS=$'\t' read -r category pattern; do
  case "$category" in ''|'#'*) continue ;; esac
  matched=0
  while IFS= read -r f; do [ -n "$f" ] || continue; if { basename "$f"; cat "$f"; } | grep -Eiq "$pattern"; then matched=1; break; fi; done <<EOF
$files
EOF
  [ "$matched" -eq 1 ] && hits=$((hits+1))
done < "$signals"
if [ "$hits" -lt 2 ]; then echo "WAREHOUSE_MAP not-applicable ($hits independent signal(s))"; exit 0; fi
map="$root/docs/warehouse-map.md"
if [ ! -f "$map" ]; then
  if [ -f "$root/LEARNINGS.md" ] && grep -Eq '^## Declined artifact: warehouse-map[[:space:]]*$' "$root/LEARNINGS.md"; then echo 'WAREHOUSE_MAP declined (recorded in LEARNINGS.md)'; exit 0; fi
  echo 'WAREHOUSE_MAP missing - run /map-warehouse or inspect the live schema before a warehouse write.'; exit 1
fi
newer=0
while IFS= read -r f; do [ -n "$f" ] && [ "$f" -nt "$map" ] && newer=$((newer+1)); done <<EOF
$files
EOF
if [ "$newer" -gt 0 ]; then echo "WAREHOUSE_MAP stale ($newer warehouse artifact(s) newer than the map)"; exit 1; fi
echo "WAREHOUSE_MAP current ($hits independent signal categories)"; exit 0
