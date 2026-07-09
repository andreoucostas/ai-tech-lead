#!/usr/bin/env bash
# PreToolUse guard — hard-block writes that introduce test-defeats, warning-suppressions, or hardcoded secrets.
# Enforces CLAUDE.md > Verification Rules #5/#7 ("failures are signals; never silence them"; "don't skip
# tests"), Test leanness #15 (no tautological assertions), and the no-secrets rule deterministically.
#
# Tool surfaces:
#   Claude Code  — tool_name in {Write,Edit}; new content at tool_input.content / tool_input.new_string.
#                  Block = exit code 2 with the reason on stderr (documented PreToolUse block contract).
#   GitHub Copilot (CLI + VS Code agent mode, preToolUse) — toolName lowercase/camelCase; content at toolArgs.*.
#                  Block = JSON {"permissionDecision":"deny",...} on stdout (superset incl. hookSpecificOutput).
#
# Allow = exit 0, no output. Degrades SAFE (allow) on parse failure; the high-confidence secret
# patterns FAIL CLOSED once content is extracted. If NO JSON parser exists (no jq, no python3) the
# guard cannot inspect anything — it allows with a loud stderr warning so the floor being OFF is
# never silent. To relax per-repo, edit the patterns below or remove the PreToolUse registration
# from .claude/settings.json and .github/hooks/hooks.json.
set -u

[ -t 0 ] && exit 0
input=$(cat)
[ -z "$input" ] && exit 0

SEP=$'\x1f'
tool=""; fp=""; content=""

if command -v jq >/dev/null 2>&1; then
  tool=$(printf '%s' "$input" | jq -r '.tool_name // .toolName // ""' 2>/dev/null)
  fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.filePath // .tool_input.path // .toolArgs.filePath // .toolArgs.file_path // .toolArgs.path // ""' 2>/dev/null)
  # file_text / new_str cover VS Code agent mode's text-editor tools (create / str_replace / insert).
  content=$(printf '%s' "$input" | jq -r '
    [ .tool_input.content, .tool_input.new_string, .tool_input.newString, .tool_input.file_text, .tool_input.new_str,
      .toolArgs.content, .toolArgs.new_string, .toolArgs.newString, .toolArgs.file_text, .toolArgs.new_str,
      .tool_input.text, .toolArgs.text ] | map(select(. != null)) | join("\n")' 2>/dev/null)
elif command -v python3 >/dev/null 2>&1; then
  parsed=$(printf '%s' "$input" | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(0)
tool=d.get("tool_name") or d.get("toolName") or ""
ti=d.get("tool_input") or {}
ta=d.get("toolArgs") or {}
if isinstance(ta,str):
    try: ta=json.loads(ta)
    except Exception: ta={}
fp=ti.get("file_path") or ti.get("filePath") or ti.get("path") or ta.get("filePath") or ta.get("file_path") or ta.get("path") or ""
parts=[ti.get("content"),ti.get("new_string"),ti.get("newString"),ti.get("file_text"),ti.get("new_str"),ta.get("content"),ta.get("new_string"),ta.get("newString"),ta.get("file_text"),ta.get("new_str"),ti.get("text"),ta.get("text")]
content="\n".join([p for p in parts if p])
sys.stdout.write(tool+"\x1f"+fp+"\x1f"+content)
' 2>/dev/null)
  tool=${parsed%%"$SEP"*}; rest=${parsed#*"$SEP"}; fp=${rest%%"$SEP"*}; content=${rest#*"$SEP"}
else
  # No parser -> nothing can be inspected. Allow (blocking would brick every write on boxes
  # without jq/python3) but say so loudly: stderr surfaces in the hook logs on every surface.
  echo "guard: no jq or python3 on PATH — write-guard INACTIVE (secret/test-defeat floor is OFF). Install jq to restore it." >&2
  exit 0
fi

# Gate on whether this is an inspectable write, independent of surface: known write tools
# (Claude Write/Edit, Copilot CLI edit/create) OR any tool carrying a file path + content
# (covers VS Code agent mode's camelCase tool names, which we can't fully enumerate).
case "$tool" in
  Write|Edit|edit|create|"") ;;
  *) { [ -n "$fp" ] && [ -n "$content" ]; } || exit 0 ;;
esac
[ -z "$content" ] && exit 0

reasons=()

# --- Test-defeats + warning/type suppressions (scoped by file extension) ---
case "$fp" in
  *.cs)
    printf '%s' "$content" | grep -Eq '#pragma[[:space:]]+warning[[:space:]]+disable' \
      && reasons+=("adds '#pragma warning disable' — Verification Rule #7: failures are signals, fix the cause")
    printf '%s' "$content" | grep -Eq '\[(Fact|Theory)\([^)]*Skip[[:space:]]*=' \
      && reasons+=("skips a test via [Fact/Theory(Skip=...)] — don't skip; fix the test or record it in TECH_DEBT.md (Verification Rule #5)")
    { printf '%s' "$content" | grep -Eq 'Assert\.True\([[:space:]]*true[[:space:]]*[),]' \
      || printf '%s' "$content" | grep -Eq 'Assert\.False\([[:space:]]*false[[:space:]]*[),]'; } \
      && reasons+=("adds a tautological assertion (Assert.True(true) / Assert.False(false)) — assert observable behaviour, not a constant (Test leanness #15)")
    ;;
  *.ts|*.tsx|*.js|*.jsx|*.mts|*.cts|*.mjs|*.cjs)
    printf '%s' "$content" | grep -Eq 'eslint-disable' \
      && reasons+=("adds an 'eslint-disable' directive — fix the lint cause, don't silence it")
    printf '%s' "$content" | grep -Eq '@ts-(ignore|nocheck)' \
      && reasons+=("adds '@ts-ignore'/'@ts-nocheck' — fix the type error, don't suppress it")
    ;;
esac

# --- Test-defeats in spec files (focused/skipped tests, tautological expects) ---
case "$fp" in
  *.spec.ts|*.spec.tsx|*.spec.js|*.spec.jsx|*.spec.mts|*.spec.cts)
    { printf '%s' "$content" | grep -Eq '^[[:space:]]*f(it|describe)[[:space:]]*\(' \
      || printf '%s' "$content" | grep -Eq '\b(it|describe)\.only[[:space:]]*\('; } \
      && reasons+=("adds a focused test (fit/fdescribe/.only) — it silently skips the rest of the suite; remove it before committing")
    { printf '%s' "$content" | grep -Eq '^[[:space:]]*x(it|describe)[[:space:]]*\(' \
      || printf '%s' "$content" | grep -Eq '\b(it|describe)\.skip[[:space:]]*\('; } \
      && reasons+=("skips a test (xit/xdescribe/.skip) — don't skip; fix the test or record it in TECH_DEBT.md (Verification Rule #5)")
    { printf '%s' "$content" | grep -Eq 'expect\([[:space:]]*true[[:space:]]*\)\.toBe\([[:space:]]*true[[:space:]]*\)' \
      || printf '%s' "$content" | grep -Eq 'expect\([[:space:]]*false[[:space:]]*\)\.toBe\([[:space:]]*false[[:space:]]*\)'; } \
      && reasons+=("adds a tautological assertion (expect(true).toBe(true)) — assert observable behaviour, not a constant (Test leanness #15)")
    ;;
esac

# --- High-confidence secrets (any file, fail closed) ---
secret=""
printf '%s' "$content" | grep -Eq -- '-----BEGIN [A-Z ]*PRIVATE KEY-----' && secret="a private key block"
[ -z "$secret" ] && printf '%s' "$content" | grep -Eq 'AKIA[0-9A-Z]{16}'        && secret="an AWS access key id (AKIA…)"
[ -z "$secret" ] && printf '%s' "$content" | grep -Eq 'ghp_[A-Za-z0-9]{36}'      && secret="a GitHub token (ghp_…)"
[ -z "$secret" ] && printf '%s' "$content" | grep -Eq 'xox[baprs]-[A-Za-z0-9-]{10,}' && secret="a Slack token (xox…)"
[ -z "$secret" ] && printf '%s' "$content" | grep -Eq 'sk-[A-Za-z0-9_-]{20,}'    && secret="an API secret key (sk-…)"
[ -z "$secret" ] && printf '%s' "$content" | grep -Eq 'AIza[0-9A-Za-z_-]{35}'    && secret="a Google API key (AIza…)"
[ -n "$secret" ] && reasons+=("contains $secret — secrets must not be committed; use user-secrets / env vars / a vault")

# --- Generic credential assignment (skip test / sample / Development files & placeholders) ---
case "$fp" in
  *[Tt]est*|*spec*|*Development*|*example*|*sample*|*mock*|*fixture*) ;;
  *)
    cred=$(printf '%s' "$content" \
      | grep -Ei '(password|passwd|pwd|secret|api[_-]?key|access[_-]?key|client[_-]?secret|connectionstring)["'"'"' ]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,}["'"'"']' 2>/dev/null \
      | grep -Eiv '(changeme|placeholder|your[_-]|example|dummy|<[^>]+>|\$\{|process\.env|%[A-Z_]+%)' | head -1)
    [ -n "$cred" ] && reasons+=("assigns a hardcoded credential literal — move it to user-secrets / env vars / a vault")
    ;;
esac

[ ${#reasons[@]} -eq 0 ] && exit 0

joined=$(printf '%s; ' "${reasons[@]}"); joined="${joined%; }"
msg="Blocked write to ${fp:-the target file}: it ${joined}."

# Block per surface. Claude Code honors exit 2 + stderr; Copilot (CLI + VS Code agent mode)
# honor a permissionDecision JSON deny on stdout. Claude tools are PascalCase (Edit/Write) — and
# the ambiguous empty case routes to Claude too (its PreToolUse matcher only fires on Write|Edit);
# everything else (Copilot CLI lowercase edit/create, VS Code camelCase) gets a SUPERSET JSON
# carrying both the top-level (CLI shape) and hookSpecificOutput-nested (VS Code shape) decision.
# Replaces the prior {decision,reason} shape, which no longer matches the Copilot spec (the old
# Copilot deny had silently become a no-op). Task 0 confirms VS Code honors this.
case "$tool" in
  Edit|Write|"")
    printf '%s\n' "$msg" >&2
    exit 2
    ;;
esac

esc=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g')
printf '{"permissionDecision":"deny","permissionDecisionReason":"%s","hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$esc" "$esc"
exit 0
