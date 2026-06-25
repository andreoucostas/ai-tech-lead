#!/usr/bin/env bash
# UserPromptSubmit router — classify natural-language prompts into a workflow
# and inject the matching workflow's deterministic rails before the model responds.
# Plain stdout is treated as additionalContext by Claude Code.
# Skips when the user explicitly invoked a slash command (already deterministic).

set -u

input=$(cat)

# Extract the prompt field. Prefer jq (handles all JSON escapes correctly),
# fall back to python3 (typically available on every dev box where bash runs),
# fall back to a regex that handles escaped quotes as a last resort.
prompt=""
if command -v jq >/dev/null 2>&1; then
  prompt=$(printf '%s' "$input" | jq -r '.prompt // ""' 2>/dev/null)
elif command -v python3 >/dev/null 2>&1; then
  prompt=$(printf '%s' "$input" | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
    print(d.get("prompt","") if isinstance(d, dict) else "")
except Exception:
    pass' 2>/dev/null)
elif command -v python >/dev/null 2>&1; then
  prompt=$(printf '%s' "$input" | python -c 'import json,sys
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
[ -z "$prompt" ] && exit 0

# Skip if the user already chose a workflow.
case "$prompt" in
  /*) exit 0 ;;
esac

lc=$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')

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
  fix|feature|refactor|test) [ -n "$isq" ] && [ -z "$imp" ] && intent="" ;;
esac

# Security overlay fires IN ADDITION to any workflow intent (DORA: AI amplifies
# weaknesses fastest on security-sensitive surfaces). Not an exclusive intent.
sensitive=""
if echo "$lc" | grep -qE '(\bauth\b|authenticat|authori[sz]|login|password|secret|token|credential|session|cookie|\bjwt\b|permission|\brole\b|\bpii\b|personal data|gdpr|encrypt|sanitiz|bypasssecuritytrust|innerhtml|\bxss\b|\bcsrf\b|payment|money|currency)'; then sensitive="1"; fi

[ -z "$intent" ] && [ -z "$sensitive" ] && exit 0

if [ -n "$intent" ]; then
cat <<EOF
## Routed intent: \`$intent\`

This natural-language prompt was classified as **$intent**. The rails below mirror \`CLAUDE.md > Agentic Workflow\` section 1 — the canonical definition, already in your context; they are repeated here for salience. Apply them before responding. If the actual intent differs, say so and proceed normally.

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
2. Write a failing regression test BEFORE touching production code; confirm it fails for the right reason.
3. Apply the minimal fix; do not refactor unrelated code.
4. Verify the regression test passes, the full related suite passes, build is clean, lint is clean.
5. Apply Boy Scout to BLAST RADIUS only — never boy-scout unrelated files in a fix.
6. Report root cause, fix, regression-test coverage, blast radius.
EOF
    ;;
  feature)
    cat <<'EOF'
1. Design check first — list affected layers, files to create/modify, failure modes, test strategy.
2. Decompose into ordered subtasks; run build + test + lint after each before continuing.
3. Apply Boy Scout to every file you touch.
4. Self-review against CLAUDE.md > Conventions; flag new patterns or resolved tech debt.
5. Present what was implemented and tested.

Leanness constraints (CLAUDE.md > Leanness):
- Prefer editing existing files over creating new ones.
- No new interface, abstract class, pipe, or directive unless a second consumer exists in this change-set. State the second consumer if you add one.
- Wrappers must add behavior. Inline shallow service methods that just call HttpClient.
- No defensive code for impossible states; no comments that restate code; no future-proofing.
EOF
    ;;
  refactor)
    cat <<'EOF'
1. Verify starting state — build and tests must pass BEFORE touching anything.
2. If no tests exist for the target code, write baseline tests FIRST.
3. Refactor incrementally; build + test after each meaningful change.
4. Apply Boy Scout to every file you touched.
5. Verify final state — no behavior should have changed.
6. Present a before/after summary INCLUDING net LOC delta.

Leanness constraints (CLAUDE.md > Leanness):
- Trend toward less code: delete dead branches, inline single-use abstractions, remove now-redundant types.
- A refactor that grows the codebase needs an explicit reason in the summary.
- Do not introduce new interfaces, helpers, pipes, or wrappers as part of a refactor unless they replace at least as much code as they add.
EOF
    ;;
  test)
    cat <<'EOF'
1. Match existing test structure, naming convention, framework, and mocking approach.
2. Cover happy path, edge cases, error paths, boundary conditions.
3. Do not test framework behavior — test public behavior only.
4. Verify all new tests pass.
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
1. Read TECH_DEBT.md and find items in the specified area.
2. Confirm each item still exists in the code (it may have been fixed already).
3. Recommend fix-now vs defer per item, with reason.
4. After fixes: update TECH_DEBT.md — remove resolved items, add newly discovered.
5. Apply Boy Scout to every file touched.
6. Report what was fixed/deferred plus the updated TECH_DEBT diff.
EOF
    ;;
  review)
    cat <<'EOF'
This is a quality gate, not a rubber stamp.
1. Check correctness and every CLAUDE.md > Conventions item per changed file.
2. Check test quality — behavior coverage, descriptive names, regression detection.
3. Run build + tests yourself — do not trust they pass.
4. Check architecture/debt trajectory and Boy Scout application.
Output: APPROVE or REQUEST CHANGES with a severity-tagged issues table.
EOF
    ;;
esac
fi

if [ -n "$sensitive" ]; then
cat <<'EOF'
## Security-sensitive surface detected

This prompt touches a security-sensitive area (auth, tokens, session, PII, output sanitisation). DORA's evidence is that AI amplifies existing weaknesses fastest here, so this overlay applies ON TOP OF any workflow rails above. Before presenting the change as complete:
1. Run /security-review on the diff (or invoke the security-auditor agent) — do not self-certify.
2. Never bypass Angular's sanitisation (bypassSecurityTrust*, direct innerHTML) without an explicit, reviewed reason; rely on the framework's escaping.
3. Keep tokens/secrets out of localStorage where an httpOnly cookie is viable; never log credentials or PII.
4. Validate and encode at trust boundaries (route params, HTTP responses, user input); guard against XSS/CSRF.
5. Record anything you could not fully verify in SECURITY_FINDINGS.md.
If this prompt does NOT actually touch a sensitive surface, say so and skip this overlay.
EOF
fi

exit 0
