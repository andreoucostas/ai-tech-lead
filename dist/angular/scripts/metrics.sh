#!/usr/bin/env bash
# Deterministic codebase scorecard for the impact before/after. Emits JSON to stdout.
# Counts the framework's own anti-patterns so a pre-adoption baseline can be contrasted with a later
# scan (or with the diff produced by an A/B run). No build, no install — just grep over source.
#
# Usage:
#   bash scripts/metrics.sh                 # scan the whole repo
#   bash scripts/metrics.sh file1 file2 …   # scan only these paths (e.g. an A/B run's changed files)
set -u
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

paths=("$@"); [ ${#paths[@]} -eq 0 ] && paths=(.)
EX=(--exclude-dir=.git --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=.angular)
c() { grep -rEI "${EX[@]}" --include='*.ts' --include='*.html' "$1" "${paths[@]}" 2>/dev/null | wc -l | tr -d ' '; }

# --- Readiness signals: capability disclosure for /impact, NOT a gate ---
ci_present=false
{ [ -f bitbucket-pipelines.yml ] || [ -f bitbucket-pipelines.yaml ] || [ -d .github/workflows ] || [ -f azure-pipelines.yml ]; } && ci_present=true
cov="null"
covfile=$(find . -name 'cobertura-coverage.xml' -not -path '*/node_modules/*' -not -path '*/dist/*' 2>/dev/null | head -1)
[ -z "$covfile" ] && covfile=$(find . -name '*cobertura*.xml' -not -path '*/node_modules/*' -not -path '*/dist/*' 2>/dev/null | head -1)
if [ -n "$covfile" ]; then
  lr=$(grep -oE 'line-rate="[0-9.]+"' "$covfile" 2>/dev/null | head -1 | grep -oE '[0-9.]+')
  [ -n "$lr" ] && cov=$(awk "BEGIN{printf \"%.1f\", $lr*100}")
fi
ts_strict=false
grep -rqsI --include='tsconfig*.json' '"strict"[[:space:]]*:[[:space:]]*true' . 2>/dev/null && ts_strict=true
has_tests=false; [ "$(c '\b(it|describe)\(')" -gt 0 ] && has_tests=true

cat <<JSON
{
  "stack": "angular",
  "scope": "${paths[*]}",
  "metrics": {
    "any_type": $(c ':[[:space:]]*any\b|<any>'),
    "ts_ignore_nocheck": $(c '@ts-(ignore|nocheck)'),
    "eslint_disable": $(c 'eslint-disable'),
    "manual_subscribe": $(c '\.subscribe\('),
    "bypass_security_trust": $(c 'bypassSecurityTrust'),
    "console_log": $(c 'console\.(log|debug|warn|error)\('),
    "todo_hack_fixme": $(c '(TODO|HACK|FIXME)'),
    "not_implemented_throws": $(c "throw[[:space:]]+new[[:space:]]+Error\([\"']not implemented"),
    "concrete_service_instantiation_dip": $(c 'new[[:space:]]+[A-Za-z0-9_]+(Service|Store|Facade)\('),
    "test_specs": $(c '\b(it|describe)\(')
  },
  "readiness": {
    "ci_present": ${ci_present},
    "coverage_pct": ${cov},
    "ts_strict": ${ts_strict},
    "has_tests": ${has_tests}
  }
}
JSON
