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
  }
}
JSON
