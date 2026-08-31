#!/usr/bin/env bash
# UserPromptSubmit router — classify natural-language prompts into a workflow
# and format the matching workflow's deterministic rails for hook output.
# For Claude-shaped input this script emits plain stdout; for other JSON input it emits top-level
# and wrapped JSON additionalContext shapes. Emission and registration do not prove host firing or
# consumption; current VS Code prompt-hook lifecycles are unverified. See docs/enforcement-surfaces.md.
# Skips when the user explicitly invoked a slash command (already deterministic).

set -u

input=$(cat)
is_claude=""
if printf '%s' "$input" | grep -q '"hook_event_name"'; then is_claude="1"; fi

# Extract the prompt field. Prefer jq (handles all JSON escapes correctly); if absent, resolve a
# working python (memoised in $pybin for reuse at the output-encode site below) and use it; if no
# working interpreter exists, fall back to a regex that handles escaped quotes as a last resort.
prompt=""
pybin=""
pybin_resolved=""
jq_working=""
if command -v jq >/dev/null 2>&1 && printf '{}' | jq -e . >/dev/null 2>&1; then jq_working="1"; fi
resolve_pybin() {
  [ -n "$pybin_resolved" ] && return
  pybin_resolved="1"
  for cand in python3 python py; do
    if command -v "$cand" >/dev/null 2>&1 &&
       [ "$(printf '{}' | "$cand" -c 'import json,sys; json.load(sys.stdin); sys.stdout.write("ok")' 2>/dev/null)" = "ok" ]; then
      pybin=$cand; return
    fi
  done
}
if [ -n "$jq_working" ]; then
  prompt=$(printf '%s' "$input" | jq -r '.prompt // ""' 2>/dev/null) || jq_working=""
fi
if [ -z "$jq_working" ]; then
  # Resolve a WORKING python, not merely a resolvable name -- same grammar as guard.sh, on which
  # this is modelled: a python.org install ships python.exe and no python3.exe, so probing only
  # `python3` guarantees this fallback never engages on Windows; and the Microsoft Store alias
  # stub resolves under the name `python` but is not an interpreter (it prints "Python was not
  # found" and exits 49) -- a name-only probe would select it and then silently produce nothing.
  # So: execute each candidate and require it to actually round-trip JSON. Resolved lazily here
  # (only when jq is absent) and at most once per run, so the common jq path costs nothing extra.
  resolve_pybin
  if [ -n "$pybin" ]; then
    prompt=$(printf '%s' "$input" | "$pybin" -c 'import json,sys
try:
    d = json.load(sys.stdin)
    print(d.get("prompt","") if isinstance(d, dict) else "")
except Exception:
    pass' 2>/dev/null)
  else
    # Last-resort regex: allow backslash-escaped chars inside the captured value.
    if [[ "$input" =~ \"prompt\"[[:space:]]*:[[:space:]]*\"((\\.|[^\"\\])*)\" ]]; then
      prompt="${BASH_REMATCH[1]}"
      # Decode the most common JSON string escapes.
      prompt="${prompt//\\\"/\"}"
      prompt="${prompt//\\\\/\\}"
      prompt="${prompt//\\n/$'\n'}"
      prompt="${prompt//\\t/$'\t'}"
    fi
  fi
fi
[ -z "$prompt" ] && [ -n "$is_claude" ] && exit 0

# Skip if the user already chose a workflow.
case "$prompt" in
  /*) [ -n "$is_claude" ] && exit 0 ; route_eligible="" ;;
  *) route_eligible="1" ;;
esac
[ -z "$prompt" ] && route_eligible=""

if [ -n "$route_eligible" ]; then lc=$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]'); else lc=""; fi

intent=""
# Priority order: review > debt > design > test > fix > refactor > feature
if   echo "$lc" | grep -qE '(review this|review the|review my (changes|pr|code)|quality gate)'; then intent="review"
elif echo "$lc" | grep -qE '(tech debt|technical debt|cleanup debt|debt (in|register))'; then intent="debt"
elif echo "$lc" | grep -qE "(how should i|what'?s the best way|design (a|the)|approach (for|to)|how would you|trade.?offs?)"; then intent="design"
elif echo "$lc" | grep -qE '(write tests?|add tests?|test coverage|increase coverage|generate tests?)'; then intent="test"
elif echo "$lc" | grep -qE '(\bfix\b|\bbug\b|\bbroken\b|\bcrash|\bfails?\b|\bfailing\b|\bthrows?\b|\bthrowing\b|\bregression\b|not working)'; then intent="fix"
elif echo "$lc" | grep -qE '(\brefactor\b|cleanup|clean up|\bextract\b|\brename\b|simplify|reorganis[ez]|restructure|\btidy\b)'; then intent="refactor"
elif echo "$lc" | grep -qE '(\badd\b|\bimplement\b|\bcreate\b|\bbuild\b|new (feature|endpoint|component|service|screen|route))'; then intent="feature"
fi

# Answer-only carve-out (CLAUDE.md section 1): a question-shaped prompt with no
# imperative verb asks for an explanation, not a code change — don't impose workflow
# ceremony. Clearing intent suppresses the rails + plan-gate; the security overlay
# below still fires if the question touches a sensitive surface.
isq=""; imp=""
if echo "$lc" | grep -qE "^[[:space:]]*(why|what|what'?s|how come|when|where|which|who|is|are|does|do|can|could|would|should)\b" || printf '%s' "$prompt" | grep -qE '\?[[:space:]]*$'; then isq="1"; fi
if echo "$lc" | grep -qE '\b(add|fix|implement|create|build|make|change|update|modify|remove|delete|refactor|rename|extract|write|test|review|clean ?up|migrate|wire|integrate|introduce)\b'; then imp="1"; fi
case "$intent" in
  fix|feature|refactor|test|debt) [ -n "$isq" ] && [ -z "$imp" ] && intent="" ;;
esac

# Security overlay fires IN ADDITION to any workflow intent (DORA: AI amplifies
# weaknesses fastest on security/money-sensitive surfaces). Not an exclusive intent.
sensitive=""
if echo "$lc" | grep -qE '(payment|balance|ledger|transaction|transfer|\bdebit\b|\bcredit\b|refund|settle|idempotenc|reconcil|\bauth\b|authenticat|authori[sz]|login|password|secret|token|credential|permission|\brole\b|encrypt|decrypt|money|currency)'; then sensitive="1"; fi

[ -z "$intent" ] && [ -z "$sensitive" ] && [ -n "$is_claude" ] && exit 0

emit_body() {
if [ -n "$intent" ]; then
cat <<EOF
## Routed intent: \`$intent\`

This natural-language prompt was classified as **$intent**. The rails below mirror the framework rules (\`.github/instructions/framework-rules.instructions.md\` › Agentic Workflow; \`AGENTS.md\` › Agentic Workflow on AGENTS.md-native tools) section 1 — the canonical definition, already in your context; they are repeated here for salience. Apply them before responding. If the actual intent differs, say so and proceed normally.

## Verification execution boundary
Derive all six command categories, but run only safely executable verification. A recorded migration/deploy command is manual/CI-only unless repository evidence identifies that exact invocation as non-mutating validation/dry-run, or the developer explicitly authorizes execution against a known target. Otherwise report it as recorded but not run.

EOF

case "$intent" in
  fix|feature|refactor|test)
    cat <<'EOF'
## Plan gate (present -> clarify -> confirm)
Before writing code: post a short plan (files to change, order of operations, how you'll verify) AND any clarifying questions for whatever is underspecified — do not guess past a material ambiguity to seem helpful. Then WAIT for the developer's explicit go-ahead before editing code. Skip the wait only for a trivial, unambiguous change (typo, one-liner), and say that you're skipping it and why.
EOF
    ;;
esac

case "$intent" in
  fix)
    cat <<'EOF'
1. Diagnose root cause first; state it before writing any code.
2. When the repository evidences an applicable test harness, write a failing regression test BEFORE touching production code; otherwise reproduce with the strongest evidenced validation and report tests as not available — never introduce a foreign harness solely for this fix.
3. Apply the minimal fix; do not refactor unrelated code.
4. Derive exact regression and suite commands plus applicable build, test, format, lint, migration/deploy, and data-validation commands from repository evidence; run only safely executable applicable commands under the execution boundary above and report each unsupported category as not available.
5. Apply Boy Scout to BLAST RADIUS only — never boy-scout unrelated files in a fix.
6. Report root cause, fix, regression-test coverage, blast radius.
EOF
    ;;
  feature)
    cat <<'EOF'
1. Design check first — list affected layers, files to create/modify, failure modes, test strategy.
2. Decompose into ordered subtasks; derive exact build, test, format, lint, migration/deploy, and data-validation commands from repository evidence, then run only safely executable applicable commands under the execution boundary above after each before continuing (report unsupported categories as not available).
3. Apply Boy Scout to every file you touch.
4. Self-review against CLAUDE.md > Conventions; flag new patterns or resolved tech debt.
5. Present what was implemented and tested.

Leanness constraints (the framework rules (`.github/instructions/framework-rules.instructions.md` › Leanness; `AGENTS.md` › Leanness on AGENTS.md-native tools)):
- Prefer editing existing files over creating new ones.
- No new interface, abstract class, or generic helper unless a second consumer exists in this change-set. State the second consumer if you add one.
- Wrappers must add behavior. Inline shallow delegates.
- No defensive code for impossible states; no comments that restate code; no future-proofing.
EOF
    ;;
  refactor)
    cat <<'EOF'
1. Derive exact build, test, format, lint, migration/deploy, and data-validation commands from repository evidence and establish a green baseline BEFORE touching anything; report unsupported categories as not available.
2. If the repository has an applicable test harness but the target lacks coverage, write baseline tests FIRST; otherwise report tests as not available, use the strongest evidenced validation, and never introduce a foreign harness solely for this refactor.
3. Refactor incrementally; run applicable checks after each meaningful change.
4. Apply Boy Scout to every file you touched.
5. Verify final state — no behavior should have changed.
6. Present a before/after summary INCLUDING net LOC delta.

Leanness constraints (the framework rules (`.github/instructions/framework-rules.instructions.md` › Leanness; `AGENTS.md` › Leanness on AGENTS.md-native tools)):
- Trend toward less code: delete dead branches, inline single-use abstractions, remove now-redundant types.
- A refactor that grows the codebase needs an explicit reason in the summary.
- Do not introduce new interfaces, helpers, or wrappers as part of a refactor unless they replace at least as much code as they add.
EOF
    ;;
  test)
    cat <<'EOF'
1. Match existing test structure, naming convention, framework, and mocking approach.
2. Choose the smallest risk-relevant set: the principal behavior plus only consequential error, edge, or boundary cases; do not build a case matrix for its own sake.
3. Do not test framework behavior — test public behavior only.
4. Derive exact applicable build, test, format, lint, migration/deploy, and data-validation commands from repository evidence; run only safely executable applicable commands under the execution boundary above and report every unsupported category as not available.
5. Report what was tested and what's still uncovered.
EOF
    ;;
  design)
    cat <<'EOF'
**DO NOT WRITE ANY CODE.** Produce a design document only.
1. Understand the requirement — goal, users, acceptance criteria, scope boundary.
2. Analyse impact — layers affected, files changing, patterns to reuse.
3. Consider at least two approaches with pros/cons and effort estimates.
4. Recommend, with specifics — component structure, state, services, tests.
5. Surface open questions for the developer to answer before /feature.
EOF
    ;;
  debt)
    cat <<'EOF'
1. Read TECH_DEBT.md, including dismissed-proposal decision memory, and find active items in the specified area.
2. Confirm each item still exists in the code (it may have been fixed already).
3. Derive applicable tests and other validation from repository evidence; when no test harness exists, report tests as not available and use the strongest evidenced validation — never introduce a foreign harness solely for debt cleanup.
4. Recommend fix-now vs defer per item, with reason.
5. After fixes: update TECH_DEBT.md — remove resolved items, preserve dismissals, and do not re-propose one without naming materially changed evidence.
6. Apply Boy Scout to every file touched.
7. Report what was fixed/deferred plus the validation results and updated TECH_DEBT diff.
EOF
    ;;
  review)
    cat <<'EOF'
This is a quality gate, not a rubber stamp.
1. Check correctness and every CLAUDE.md > Conventions item per changed file.
2. Check test quality — behavior coverage, descriptive names, regression detection.
3. Derive and run only safely executable build, test, format, lint, migration/deploy, and data-validation commands supported by repository evidence yourself, subject to the execution boundary above; do not trust they pass, and report unsupported categories as not available.
4. Check architecture/debt trajectory and Boy Scout application.
Output: APPROVE or REQUEST CHANGES with a severity-tagged issues table.
EOF
    ;;
esac
fi

if [ -n "$sensitive" ]; then
cat <<'EOF'
## Security-sensitive surface detected

This prompt touches a security- or money-sensitive area (auth, payments, balances, ledgers, idempotency, secrets). DORA's evidence is that AI amplifies existing weaknesses fastest here, so this overlay applies ON TOP OF any workflow rails above. Before presenting the change as complete:
1. Run /security-review on the diff (or invoke the security-auditor agent) — do not self-certify.
2. Monetary logic: use decimal (never double); guard negative amounts, duplicate transaction IDs, precision loss, and timestamp ordering; make state-changing operations idempotent.
3. Check-then-act on balances/state: ensure read-decide-write is atomic/serialised — no TOCTOU race.
4. Record anything you could not fully verify in SECURITY_FINDINGS.md.
If this prompt does NOT actually touch a sensitive surface, say so and skip this overlay.
EOF
fi
}

body=$(emit_body)

# Surface dispatch. `hook_event_name` selects plain stdout. Other input selects top-level and
# hookSpecificOutput-wrapped UserPromptSubmit additionalContext JSON after queued Boy Scout text is
# merged. These are script-emitted shapes only: registration and output do not prove that a host
# fired the event or consumed the result. Current VS Code prompt-hook lifecycles are unverified;
# dated CLI evidence is recorded in docs/enforcement-surfaces.md.
# JSON encoding needs jq or the working Python resolved above; with neither, emit plain stdout as a
# fallback. That emitted fallback says nothing about client behavior.
if printf '%s' "$input" | grep -q '"hook_event_name"'; then
  printf '%s\n' "$body"
else
  hook_dir=$(cd "$(dirname "$0")" && pwd)
  candidate_root=$(cd "$hook_dir/../.." && pwd)
  queued_text=""
  if repo_root=$(git -C "$candidate_root" rev-parse --show-toplevel 2>/dev/null); then
    queue_file="$repo_root/.claude/.state/boy-scout-queue"
    if [ -e "$queue_file" ]; then
      queued_text=$(cat "$queue_file")
      rm -f "$queue_file"
    fi
  fi
  if [ -n "${queued_text//[[:space:]]/}" ]; then
    if [ -n "$body" ]; then body="$body
$queued_text"; else body=$queued_text; fi
  fi
  [ -z "$body" ] && exit 0
  if [ -n "$jq_working" ]; then
    encoded=$(printf '%s' "$body" | jq -Rs '{additionalContext: ., hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: .}}' 2>/dev/null) || encoded=""
    if [ -n "$encoded" ]; then printf '%s\n' "$encoded"; exit 0; fi
    jq_working=""
  fi
  resolve_pybin
  if [ -n "$pybin" ]; then
  printf '%s' "$body" | "$pybin" -c 'import json,sys
b = sys.stdin.read()
print(json.dumps({"additionalContext": b, "hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": b}}))'
  else
  printf '%s\n' "$body"
  fi
fi

exit 0
