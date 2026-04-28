#!/usr/bin/env bash
# Stop hook — flag Boy Scout opportunities in modified .ts files.
# Soft-warning by default (plain stdout). Switch to {"decision":"block","reason":...}
# JSON output if the team wants strict enforcement.
#
# Patterns derived from the always-apply items in CLAUDE.md > Boy Scout Rule:
#   - manual ngOnDestroy subscription cleanup
#   - missing ChangeDetectionStrategy.OnPush on components
#   - nested .subscribe()
#   - explicit `any` / `as any`

set -u

[ ! -d .git ] && exit 0

# Modified + staged + untracked .ts files (bounded to keep this fast)
files=$(
  { git diff --name-only -- '*.ts' 2>/dev/null
    git diff --cached --name-only -- '*.ts' 2>/dev/null
    git ls-files --others --exclude-standard -- '*.ts' 2>/dev/null
  } | sort -u | head -30
)
[ -z "$files" ] && exit 0

declare -a findings=()
checked=0

while IFS= read -r f; do
  [ -z "$f" ] || [ ! -f "$f" ] && continue
  # Skip test files and generated files
  case "$f" in
    *.spec.ts|*.test.ts|*.d.ts) continue ;;
  esac
  checked=$((checked + 1))

  # 1. ngOnDestroy + manual .subscribe — likely a candidate for takeUntilDestroyed
  if grep -q 'ngOnDestroy' "$f" 2>/dev/null && grep -q '\.subscribe(' "$f" 2>/dev/null; then
    findings+=("$f: manual ngOnDestroy with .subscribe — consider takeUntilDestroyed()")
  fi

  # 2. Component without OnPush
  if [[ "$f" == *.component.ts ]]; then
    if grep -q '@Component(' "$f" 2>/dev/null && ! grep -q 'ChangeDetectionStrategy.OnPush' "$f" 2>/dev/null; then
      findings+=("$f: @Component without ChangeDetectionStrategy.OnPush")
    fi
  fi

  # 3. Multiple .subscribe( calls — possible nested subscribe (count occurrences, not lines)
  sub_count=$(grep -oE '\.subscribe\(' "$f" 2>/dev/null | wc -l)
  if [ "$sub_count" -ge 3 ]; then
    findings+=("$f: $sub_count .subscribe() calls — review for nested subscribes (use switchMap/mergeMap/concatMap/exhaustMap)")
  fi

  # 4. Explicit `any` (not in comments)
  any_hits=$(grep -E '(:[[:space:]]*any\b|\bas[[:space:]]+any\b)' "$f" 2>/dev/null | grep -v '^[[:space:]]*//' | wc -l)
  if [ "$any_hits" -gt 0 ]; then
    findings+=("$f: $any_hits explicit \`any\` usage(s) — replace with proper types or unknown+narrowing")
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
