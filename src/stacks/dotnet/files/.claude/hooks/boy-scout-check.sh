#!/usr/bin/env bash
# Stop hook — flag Boy Scout opportunities in modified .cs files.
# Soft-warning by default. Findings reach the model via hookSpecificOutput.additionalContext — a
# Stop hook's additionalContext is injected as a system reminder the model reads next turn — but
# that text is invisible in the terminal, so a one-line systemMessage is emitted alongside it so the
# developer also sees that candidates were flagged. Note: a Stop hook's {"decision":"block","reason"}
# is NOT a stricter variant — `reason` is shown only to the user, never fed to the model.
#
# Patterns derived from the always-apply items in CLAUDE.md > Boy Scout Rule:
#   - missing CancellationToken on async methods (best-effort)
#   - string-interpolated logger calls
#   - missing .AsNoTracking() near .ToListAsync/.FirstOrDefaultAsync
#   - missing null guards at public boundaries (heuristic)

set -u
if [ -t 0 ]; then input=""; else input=$(cat); fi

hook_dir=$(cd "$(dirname "$0")" && pwd)
candidate_root=$(cd "$hook_dir/../.." && pwd)
repo_root=$(git -C "$candidate_root" rev-parse --show-toplevel 2>/dev/null) || exit 0

files=$(
  { git -C "$repo_root" diff --name-only -- '*.cs' 2>/dev/null
    git -C "$repo_root" diff --cached --name-only -- '*.cs' 2>/dev/null
    git -C "$repo_root" ls-files --others --exclude-standard -- '*.cs' 2>/dev/null
  } | sort -u | head -30
)
[ -z "$files" ] && exit 0

declare -a findings=()
checked=0

while IFS= read -r f; do
  [ -z "$f" ] || [ ! -f "$repo_root/$f" ] && continue
  # Skip test files, generated files, and obj/bin trees
  case "$f" in
    *Tests.cs|*Test.cs|*.g.cs|*.Designer.cs|*/obj/*|*/bin/*) continue ;;
  esac
  checked=$((checked + 1))

  # 1. async Task signatures without CancellationToken in the parameter list
  # Best-effort grep — false positives are possible on overloads that intentionally omit it.
  async_no_ct=$(grep -E 'async[[:space:]]+(Task|ValueTask)' "$repo_root/$f" 2>/dev/null \
    | grep -E '\([^)]*\)' \
    | grep -vE 'CancellationToken' \
    | grep -vE '^\s*//' \
    | wc -l)
  if [ "$async_no_ct" -gt 0 ]; then
    findings+=("$f: $async_no_ct async method signature(s) without CancellationToken — propagate per CLAUDE.md > Async")
  fi

  # 2. String-interpolated logger calls (anti-pattern)
  interp_log=$(grep -E '\b_?[Ll]ogger\.(Log|LogTrace|LogDebug|LogInformation|LogWarning|LogError|LogCritical)\([[:space:]]*\$"' "$repo_root/$f" 2>/dev/null | wc -l)
  if [ "$interp_log" -gt 0 ]; then
    findings+=("$f: $interp_log interpolated logger call(s) — switch to structured logging templates")
  fi

  # 3. ToListAsync / FirstOrDefaultAsync without AsNoTracking in the same file (heuristic)
  if grep -qE 'using[[:space:]]+Microsoft\.EntityFrameworkCore|DbContext|DbSet<' "$repo_root/$f" 2>/dev/null \
    && grep -qE '\.(ToListAsync|FirstOrDefaultAsync|SingleOrDefaultAsync|AnyAsync|CountAsync)\(' "$repo_root/$f" 2>/dev/null; then
    if ! grep -q 'AsNoTracking' "$repo_root/$f" 2>/dev/null; then
      findings+=("$f: read-style EF Core query without any AsNoTracking() in file — review for read-only opportunities")
    fi
  fi

  # 4. Null-suppression `!` without an adjacent comment — weak proxy for missing null guards.
  # Require the `!` to be in postfix-operator position (followed by `.`, `;`, `,`, `)`, `]`,
  # whitespace, or end of line) so `disposed!=true` and similar `!=` writings don't false-positive.
  bang_hits=$(grep -E '[a-zA-Z_)\]]+!([.;,)\] ]|$)' "$repo_root/$f" 2>/dev/null | grep -vE '^\s*//' | wc -l)
  if [ "$bang_hits" -ge 5 ]; then
    findings+=("$f: $bang_hits null-forgiving (\`!\`) usage(s) — confirm each is justified or add guard clauses")
  fi

  # 5. Commented-out code blocks — runs of 2+ contiguous lines starting with //
  # whose content looks code-like (contains ;, {, }, =, or a method-call pattern).
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
  ' "$repo_root/$f" 2>/dev/null)
  if [ -n "$commented_run" ] && [ "$commented_run" -ge 2 ]; then
    findings+=("$f: commented-out code block ($commented_run+ contiguous lines) — delete; version control preserves history (CLAUDE.md > Boy Scout > Subtract)")
  fi
done <<< "$files"

[ "${#findings[@]}" -eq 0 ] && exit 0

# Dedup: skip output when this finding set matches the last fire's output.
# Avoids re-emitting the same warnings on every turn while the user iterates.
mkdir -p "$repo_root/.claude/.state" 2>/dev/null
hash_file="$repo_root/.claude/.state/last-boy-scout-hash"
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

text="## Boy Scout candidates ($checked file(s) scanned)

$(printf -- '- %s\n' "${findings[@]}")

_If these touch files you modified this turn, address them per CLAUDE.md > Boy Scout Rule before considering the work complete. Otherwise add a \`// TODO: Boy Scout skipped — [reason]\` comment._"

# additionalContext (above) reaches the model but is invisible in the terminal; emit a short
# systemMessage so the developer also sees that candidates were flagged.
summary="Boy Scout: ${#findings[@]} candidate(s) flagged to the model across $checked file(s) (see CLAUDE.md > Boy Scout Rule)."

if command -v jq >/dev/null 2>&1; then
  if printf '%s' "$input" | grep -q '"hook_event_name"'; then
    printf '%s' "$text" | jq -Rs --arg sm "$summary" '{systemMessage: $sm, hookSpecificOutput: {hookEventName: "Stop", additionalContext: .}}'
  else
    printf '%s' "$text" | jq -Rs '{additionalContext: ., hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: .}}'
  fi
elif command -v python3 >/dev/null 2>&1; then
  printf '%s' "$text" | SUMMARY="$summary" SURFACE="$(printf '%s' "$input" | grep -q '"hook_event_name"' && printf claude || printf copilot)" python3 -c 'import json,os,sys; t=sys.stdin.read(); print(json.dumps({"systemMessage": os.environ["SUMMARY"], "hookSpecificOutput": {"hookEventName": "Stop", "additionalContext": t}} if os.environ["SURFACE"] == "claude" else {"additionalContext": t, "hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": t}}))'
else
  # No JSON tool available — plain stdout lands in the debug log only, but is better than nothing.
  printf '%s\n' "$text"
fi

exit 0
