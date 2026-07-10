#!/usr/bin/env bash
# Deterministic codebase scorecard for the impact before/after. Emits JSON to stdout.
# Monorepo variant: counts both stacks' anti-patterns (.NET over *.cs, Angular over *.ts/*.html)
# in one flat metrics object; the three shared-name counters are the sum of both stacks' counts.
# Counts the framework's own anti-patterns so a pre-adoption baseline can be contrasted with a later
# scan (or with the diff produced by an A/B run). No build, no install — just grep over source.
#
# Usage:
#   bash scripts/metrics.sh                 # scan the whole repo
#   bash scripts/metrics.sh file1 file2 …   # scan only these paths (e.g. an A/B run's changed files)
set -u
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

paths=("$@"); [ ${#paths[@]} -eq 0 ] && paths=(.)
EX=(--exclude-dir=.git --exclude-dir=bin --exclude-dir=obj --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=.angular)
ccs() { grep -rEI "${EX[@]}" --include='*.cs' "$1" "${paths[@]}" 2>/dev/null | wc -l | tr -d ' '; }
cng() { grep -rEI "${EX[@]}" --include='*.ts' --include='*.html' "$1" "${paths[@]}" 2>/dev/null | wc -l | tr -d ' '; }

async_total=$(ccs 'async[[:space:]]+(Task|ValueTask)')
async_ct=$(ccs 'async[[:space:]]+(Task|ValueTask)[^)]*CancellationToken')
missing_ct=$(( async_total - async_ct )); [ "$missing_ct" -lt 0 ] && missing_ct=0

# Shared-name counters: each stack has its own pattern; the monorepo value is the sum.
todo=$(( $(ccs '(TODO|HACK|FIXME)') + $(cng '(TODO|HACK|FIXME)') ))
notimpl=$(( $(ccs 'throw[[:space:]]+new[[:space:]]+(NotImplementedException|NotSupportedException)') + $(cng "throw[[:space:]]+new[[:space:]]+Error\([\"']not implemented") ))
concrete=$(( $(ccs 'new[[:space:]]+[A-Za-z0-9_]+(Service|Repository|Handler|Manager)\(') + $(cng 'new[[:space:]]+[A-Za-z0-9_]+(Service|Store|Facade)\(') ))

# --- Readiness signals: capability disclosure for /impact, NOT a gate ---
ci_present=false
{ [ -f bitbucket-pipelines.yml ] || [ -f bitbucket-pipelines.yaml ] || [ -d .github/workflows ] || [ -f azure-pipelines.yml ]; } && ci_present=true
cov="null"
covfile=$(find . -name 'coverage.cobertura.xml' -not -path '*/node_modules/*' -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null | head -1)
[ -z "$covfile" ] && covfile=$(find . -name 'cobertura-coverage.xml' -not -path '*/node_modules/*' -not -path '*/dist/*' 2>/dev/null | head -1)
[ -z "$covfile" ] && covfile=$(find . -name '*cobertura*.xml' -not -path '*/node_modules/*' -not -path '*/bin/*' -not -path '*/obj/*' -not -path '*/dist/*' 2>/dev/null | head -1)
if [ -n "$covfile" ]; then
  lr=$(grep -oE 'line-rate="[0-9.]+"' "$covfile" 2>/dev/null | head -1 | grep -oE '[0-9.]+')
  [ -n "$lr" ] && cov=$(awk "BEGIN{printf \"%.1f\", $lr*100}")
fi
nullable=false; warnerr=false
grep -rqsI --include='*.csproj' --include='Directory.Build.props' '<Nullable>[[:space:]]*enable' . 2>/dev/null && nullable=true
grep -rqsI --include='*.csproj' --include='Directory.Build.props' '<TreatWarningsAsErrors>[[:space:]]*true' . 2>/dev/null && warnerr=true
ts_strict=false
grep -rqsI --include='tsconfig*.json' '"strict"[[:space:]]*:[[:space:]]*true' . 2>/dev/null && ts_strict=true
has_tests=false
{ [ "$(ccs '\[(Fact|Theory|Test|TestMethod)\]')" -gt 0 ] || [ "$(cng '\b(it|describe)\(')" -gt 0 ]; } && has_tests=true

cat <<JSON
{
  "stack": "monorepo",
  "scope": "${paths[*]}",
  "metrics": {
    "async_missing_cancellationtoken": ${missing_ct},
    "interpolated_logging": $(ccs '_?[Ll]ogger\.(Log[A-Za-z]*)\([[:space:]]*\$"'),
    "pragma_warning_disable": $(ccs '#pragma[[:space:]]+warning[[:space:]]+disable'),
    "console_writeline": $(ccs 'Console\.(Write|WriteLine)\('),
    "weak_crypto_md5_sha1": $(ccs '\b(MD5|SHA1)\b'),
    "raw_sql": $(ccs '(FromSqlRaw|ExecuteSqlRaw)'),
    "money_double_float": $(ccs '(double|float)[[:space:]]+[A-Za-z_]*(Amount|Balance|Price|Rate|Fee|Notional)'),
    "test_attributes": $(ccs '\[(Fact|Theory|Test|TestMethod)\]'),
    "any_type": $(cng ':[[:space:]]*any\b|<any>'),
    "ts_ignore_nocheck": $(cng '@ts-(ignore|nocheck)'),
    "eslint_disable": $(cng 'eslint-disable'),
    "manual_subscribe": $(cng '\.subscribe\('),
    "bypass_security_trust": $(cng 'bypassSecurityTrust'),
    "console_log": $(cng 'console\.(log|debug|warn|error)\('),
    "test_specs": $(cng '\b(it|describe)\('),
    "todo_hack_fixme": ${todo},
    "not_implemented_throws": ${notimpl},
    "concrete_service_instantiation_dip": ${concrete}
  },
  "readiness": {
    "ci_present": ${ci_present},
    "coverage_pct": ${cov},
    "nullable_enabled": ${nullable},
    "warnings_as_errors": ${warnerr},
    "ts_strict": ${ts_strict},
    "has_tests": ${has_tests}
  }
}
JSON
