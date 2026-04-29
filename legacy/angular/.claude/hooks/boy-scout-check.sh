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

  # 5. Commented-out code blocks — runs of 2+ contiguous lines starting with //
  # whose content looks code-like (contains ;, {, }, =, or a function-call pattern).
  commented_run=$(awk '
    BEGIN { run = 0; max = 0 }
    /^[[:space:]]*\/\// {
      stripped = $0
      sub(/^[[:space:]]*\/\/[[:space:]]*/, "", stripped)
      if (stripped ~ /[;{}=]/ || stripped ~ /[a-zA-Z_]+\(/) {
        run++
        if (run > max) max = run
      } else { run = 0 }
      next
    }
    { run = 0 }
    END { print max }
  ' "$f" 2>/dev/null)
  if [ -n "$commented_run" ] && [ "$commented_run" -ge 2 ]; then
    findings+=("$f: commented-out code block ($commented_run+ contiguous lines) — delete; version control preserves history (CLAUDE.md > Boy Scout > Subtract)")
  fi
done <<< "$files"

[ "${#findings[@]}" -eq 0 ] && exit 0

# Dedup: skip output when this finding set matches the last fire's output.
# Avoids re-emitting the same warnings on every turn while the user iterates.
mkdir -p .claude/.state 2>/dev/null
hash_file=.claude/.state/last-boy-scout-hash
joined=$(printf '%s\n' "${findings[@]}" | LC_ALL=C sort)
if command -v sha1sum >/dev/null 2>&1; then
  current_hash=$(printf '%s' "$joined" | sha1sum | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
  current_hash=$(printf '%s' "$joined" | shasum | awk '{print $1}')
else
  current_hash=$(printf '%s' "$joined" | wc -c)
fi
if [ -f "$hash_file" ] && [ "$(cat "$hash_file" 2>/dev/null)" = "$current_hash" ]; then
  exit 0
fi
printf '%s' "$current_hash" > "$hash_file" 2>/dev/null

echo "## Boy Scout candidates ($checked file(s) scanned)"
echo
for f in "${findings[@]}"; do
  echo "- $f"
done
echo
echo "_If these touch files you modified this turn, address them per CLAUDE.md > Boy Scout Rule before considering the work complete. Otherwise add a \`// TODO: Boy Scout skipped — [reason]\` comment._"

exit 0
