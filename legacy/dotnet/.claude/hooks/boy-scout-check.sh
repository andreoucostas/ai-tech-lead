#!/usr/bin/env bash
# Stop hook — flag Boy Scout opportunities in modified .cs files.
# Soft-warning by default (plain stdout). Switch to {"decision":"block","reason":...}
# JSON output if the team wants strict enforcement.
#
# Patterns derived from the always-apply items in CLAUDE.md > Boy Scout Rule:
#   - missing CancellationToken on async methods (best-effort)
#   - string-interpolated logger calls
#   - missing .AsNoTracking() near .ToListAsync/.FirstOrDefaultAsync
#   - missing null guards at public boundaries (heuristic)

set -u

[ ! -d .git ] && exit 0

files=$(
  { git diff --name-only -- '*.cs' 2>/dev/null
    git diff --cached --name-only -- '*.cs' 2>/dev/null
    git ls-files --others --exclude-standard -- '*.cs' 2>/dev/null
  } | sort -u | head -30
)
[ -z "$files" ] && exit 0

declare -a findings=()
checked=0

while IFS= read -r f; do
  [ -z "$f" ] || [ ! -f "$f" ] && continue
  # Skip test files, generated files, and obj/bin trees
  case "$f" in
    *Tests.cs|*Test.cs|*.g.cs|*.Designer.cs|*/obj/*|*/bin/*) continue ;;
  esac
  checked=$((checked + 1))

  # 1. async Task signatures without CancellationToken in the parameter list
  # Best-effort grep — false positives are possible on overloads that intentionally omit it.
  async_no_ct=$(grep -E 'async[[:space:]]+(Task|ValueTask)' "$f" 2>/dev/null \
    | grep -E '\([^)]*\)' \
    | grep -vE 'CancellationToken' \
    | grep -vE '^\s*//' \
    | wc -l)
  if [ "$async_no_ct" -gt 0 ]; then
    findings+=("$f: $async_no_ct async method signature(s) without CancellationToken — propagate per CLAUDE.md > Async")
  fi

  # 2. String-interpolated logger calls (anti-pattern)
  interp_log=$(grep -E '\b_?[Ll]ogger\.(Log|LogTrace|LogDebug|LogInformation|LogWarning|LogError|LogCritical)\([[:space:]]*\$"' "$f" 2>/dev/null | wc -l)
  if [ "$interp_log" -gt 0 ]; then
    findings+=("$f: $interp_log interpolated logger call(s) — switch to structured logging templates")
  fi

  # 3. ToListAsync / FirstOrDefaultAsync without AsNoTracking in the same file (heuristic)
  if grep -qE '\.(ToListAsync|FirstOrDefaultAsync|SingleOrDefaultAsync|AnyAsync|CountAsync)\(' "$f" 2>/dev/null; then
    if ! grep -q 'AsNoTracking' "$f" 2>/dev/null; then
      findings+=("$f: read-style EF Core query without any AsNoTracking() in file — review for read-only opportunities")
    fi
  fi

  # 4. Null-suppression `!` without an adjacent comment — weak proxy for missing null guards
  bang_hits=$(grep -E '[a-zA-Z_]+!' "$f" 2>/dev/null | grep -vE '^\s*//' | wc -l)
  if [ "$bang_hits" -ge 5 ]; then
    findings+=("$f: $bang_hits null-forgiving (\`!\`) usage(s) — confirm each is justified or add guard clauses")
  fi
done <<< "$files"

[ "${#findings[@]}" -eq 0 ] && exit 0

echo "## Boy Scout candidates ($checked file(s) scanned)"
echo
for f in "${findings[@]}"; do
  echo "- $f"
done
echo
echo "_If these touch files you modified this turn, address them per CLAUDE.md > Boy Scout Rule before considering the work complete. Otherwise add a \`// TODO: Boy Scout skipped — [reason]\` comment._"

exit 0
