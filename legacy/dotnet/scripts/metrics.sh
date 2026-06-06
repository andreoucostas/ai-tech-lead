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
EX=(--exclude-dir=.git --exclude-dir=bin --exclude-dir=obj --exclude-dir=node_modules --exclude-dir=dist)
c() { grep -rEI "${EX[@]}" --include='*.cs' "$1" "${paths[@]}" 2>/dev/null | wc -l | tr -d ' '; }

async_total=$(c 'async[[:space:]]+(Task|ValueTask)')
async_ct=$(c 'async[[:space:]]+(Task|ValueTask)[^)]*CancellationToken')
missing_ct=$(( async_total - async_ct )); [ "$missing_ct" -lt 0 ] && missing_ct=0

# --- Readiness signals: capability disclosure for /impact, NOT a gate ---
ci_present=false
{ [ -f bitbucket-pipelines.yml ] || [ -f bitbucket-pipelines.yaml ] || [ -d .github/workflows ] || [ -f azure-pipelines.yml ]; } && ci_present=true
cov="null"
covfile=$(find . -name 'coverage.cobertura.xml' -not -path '*/node_modules/*' -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null | head -1)
[ -z "$covfile" ] && covfile=$(find . -name '*cobertura*.xml' -not -path '*/node_modules/*' -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null | head -1)
if [ -n "$covfile" ]; then
  lr=$(grep -oE 'line-rate="[0-9.]+"' "$covfile" 2>/dev/null | head -1 | grep -oE '[0-9.]+')
  [ -n "$lr" ] && cov=$(awk "BEGIN{printf \"%.1f\", $lr*100}")
fi
nullable=false; warnerr=false
grep -rqsI --include='*.csproj' --include='Directory.Build.props' '<Nullable>[[:space:]]*enable' . 2>/dev/null && nullable=true
grep -rqsI --include='*.csproj' --include='Directory.Build.props' '<TreatWarningsAsErrors>[[:space:]]*true' . 2>/dev/null && warnerr=true
has_tests=false; [ "$(c '\[(Fact|Theory|Test|TestMethod)\]')" -gt 0 ] && has_tests=true

cat <<JSON
{
  "stack": "dotnet",
  "scope": "${paths[*]}",
  "metrics": {
    "async_missing_cancellationtoken": ${missing_ct},
    "interpolated_logging": $(c '_?[Ll]ogger\.(Log[A-Za-z]*)\([[:space:]]*\$"'),
    "pragma_warning_disable": $(c '#pragma[[:space:]]+warning[[:space:]]+disable'),
    "console_writeline": $(c 'Console\.(Write|WriteLine)\('),
    "todo_hack_fixme": $(c '(TODO|HACK|FIXME)'),
    "not_implemented_throws": $(c 'throw[[:space:]]+new[[:space:]]+(NotImplementedException|NotSupportedException)'),
    "concrete_service_instantiation_dip": $(c 'new[[:space:]]+[A-Za-z0-9_]+(Service|Repository|Handler|Manager)\('),
    "weak_crypto_md5_sha1": $(c '\b(MD5|SHA1)\b'),
    "raw_sql": $(c '(FromSqlRaw|ExecuteSqlRaw)'),
    "money_double_float": $(c '(double|float)[[:space:]]+[A-Za-z_]*(Amount|Balance|Price|Rate|Fee|Notional)'),
    "test_attributes": $(c '\[(Fact|Theory|Test|TestMethod)\]')
  },
  "readiness": {
    "ci_present": ${ci_present},
    "coverage_pct": ${cov},
    "nullable_enabled": ${nullable},
    "warnings_as_errors": ${warnerr},
    "has_tests": ${has_tests}
  }
}
JSON
