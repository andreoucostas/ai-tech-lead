#!/usr/bin/env bash
# PreToolUse guard — hard-block writes that introduce test-defeats, warning-suppressions, or hardcoded secrets.
# Enforces the framework rules (`.github/instructions/framework-rules.instructions.md` › Verification Rules; `AGENTS.md` › Verification Rules on AGENTS.md-native tools) #5/#7 ("failures are signals; never silence them"; "don't skip
# tests"), Test leanness #15 (no tautological assertions), and the no-secrets rule deterministically.
#
# Tool surfaces:
#   Claude Code  — tool_name in {Write,Edit}; new content at tool_input.content / tool_input.new_string.
#                  Block = exit code 2 with the reason on stderr (documented PreToolUse block contract).
#   GitHub Copilot (CLI + VS Code agent mode, preToolUse) — toolName lowercase/camelCase; content at toolArgs.*.
#                  Block = JSON {"permissionDecision":"deny",...} on stdout (superset incl. hookSpecificOutput).
#
# Allow = exit 0, no output. Degrades SAFE (allow) on parse failure; the high-confidence secret
# patterns FAIL CLOSED once content is extracted. If NO JSON parser exists (no jq, and no working
# python — python3, python, or py, each probed by execution) the guard cannot inspect anything —
# it allows with a loud stderr warning so the floor being OFF is never silent. To relax per-repo,
# edit the patterns below or remove the PreToolUse registration from .claude/settings.json and
# .github/hooks/hooks.json.
set -u

[ -t 0 ] && exit 0
input=$(cat)
[ -z "$input" ] && exit 0

SEP=$'\x1f'
tool=""; fp=""; content=""

if command -v jq >/dev/null 2>&1 && printf '{}' | jq -e . >/dev/null 2>&1; then
  tool=$(printf '%s' "$input" | jq -r '.tool_name // .toolName // ""' 2>/dev/null)
  fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.filePath // .tool_input.path // .toolArgs.filePath // .toolArgs.file_path // .toolArgs.path // ""' 2>/dev/null)
  # file_text / new_str cover VS Code agent mode's text-editor tools (create / str_replace / insert).
  content=$(printf '%s' "$input" | jq -r '
    [ .tool_input.content, .tool_input.new_string, .tool_input.newString, .tool_input.file_text, .tool_input.new_str,
      .toolArgs.content, .toolArgs.new_string, .toolArgs.newString, .toolArgs.file_text, .toolArgs.new_str,
      .tool_input.text, .toolArgs.text ] | map(select(. != null)) | join("\n")' 2>/dev/null)
else
  # Resolve a WORKING python, not merely a resolvable name. Two traps this must survive, both
  # measured on Windows -- the framework's primary target:
  #   1. A python.org install ships python.exe and NO python3.exe, so probing only `python3`
  #      guarantees this fallback can never engage there. That left the write floor OFF on any
  #      Windows box without jq, while docs/enforcement-surfaces.md promised a fallback.
  #   2. %LOCALAPPDATA%\Microsoft\WindowsApps\python.exe RESOLVES but is the Store alias stub: it
  #      prints "Python was not found" and exits 49. A name-only probe would select it, and the
  #      parse below would then yield empty output under 2>/dev/null -- turning a loud INACTIVE
  #      warning into a silent failure open, which is strictly worse.
  # So: execute each candidate and require it to actually round-trip JSON. This fallback runs
  # when jq is absent OR resolves by name but fails its own execution probe.
  pybin=""
  for cand in python3 python py; do
    if command -v "$cand" >/dev/null 2>&1 &&
       [ "$(printf '{}' | "$cand" -c 'import json,sys; json.load(sys.stdin); sys.stdout.write("ok")' 2>/dev/null)" = "ok" ]; then
      pybin=$cand; break
    fi
  done
  if [ -n "$pybin" ]; then
    parsed=$(printf '%s' "$input" | "$pybin" -c '
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
    # without one) but say so loudly: stderr surfaces in the hook logs on every surface.
    echo "guard: no jq, and no python interpreter that could parse JSON — write-guard INACTIVE (secret/test-defeat floor is OFF). Install jq to restore it." >&2
    exit 0
  fi
fi

# Gate on whether this is an inspectable write, independent of surface: known write tools
# (Claude Write/Edit, Copilot CLI edit/create) OR any tool carrying a file path + content
# (covers VS Code agent mode's camelCase tool names, which we can't fully enumerate).
case "$tool" in
  Write|Edit|edit|create|"") ;;
  *) { [ -n "$fp" ] && [ -n "$content" ]; } || exit 0 ;;
esac
[ -z "$content" ] && exit 0

# grep evaluates one physical line at a time, while the PowerShell twin's regexes evaluate the
# whole string. Fold only newlines inside bracketed attribute lists so both twins inspect the same
# logical construct. Newlines at bracket depth zero are preserved, so line-anchored patterns cannot
# be made to match text that did not begin a physical line.
normalize_bracket_lines() {
  local text=$1 out="" line ch
  local depth=0 first=1 i
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$first" -eq 0 ]; then
      if [ "$depth" -gt 0 ]; then out+=" "; else out+=$'\n'; fi
    fi
    first=0
    out+="$line"
    for ((i=0; i<${#line}; i++)); do
      ch=${line:i:1}
      if [ "$ch" = "[" ]; then
        depth=$((depth + 1))
      elif [ "$ch" = "]" ] && [ "$depth" -gt 0 ]; then
        depth=$((depth - 1))
      fi
    done
  done <<< "$text"
  printf '%s' "$out"
}
content=$(normalize_bracket_lines "$content")

reasons=()

# 0 = matched, 1 = no match, 2+ = grep could not answer (bad regex or another operational error).
# Pattern errors are never silently folded into "no match". Secret checks fail closed; the lower-
# confidence test-defeat/suppression checks warn and allow so our bad regex cannot brick a refactor.
matches() {
  printf '%s' "$content" | grep -Eq -- "$1"
  rc=$?
  case "$rc" in
    0) return 0 ;;
    1) return 1 ;;
    *)
      printf "guard: regex error in %s pattern '%s'\n" "$2" "$1" >&2
      if [ "$2" = "secret" ]; then
        reasons+=("cannot evaluate secret pattern '$1' — blocking because the high-confidence secret floor is unavailable")
      fi
      return 2
      ;;
  esac
}

# Deliberately folded file routing: extensions decide whether content is inspected at all.
path_matches_i() {
  printf '%s' "$fp" | grep -Eiq -- "$1"
}

# --- Test-defeats + warning/type suppressions (scoped by file extension) ---
if path_matches_i '\.cs$'; then
    matches '#pragma[[:space:]]+warning[[:space:]]+disable' 'test-defeat/suppression' \
      && reasons+=("adds '#pragma warning disable' — Verification Rule #7: failures are signals, fix the cause")
    matches '\[(Fact|Theory)\([^)]*Skip[[:space:]]*=' 'test-defeat/suppression' \
      && reasons+=("skips a test via [Fact/Theory(Skip=...)] — don't skip; fix the test or record it in TECH_DEBT.md (Verification Rule #5)")
    matches '^[[:space:]]*\[([^]]*[,[:space:]])?(Ignore)(Attribute)?[[:space:]]*[](,=]' 'test-defeat/suppression' \
      && reasons+=("skips a test via [Ignore] — don't skip; fix the test or record it in TECH_DEBT.md (Verification Rule #5)")
    { matches 'Assert\.True\([[:space:]]*true[[:space:]]*[),]' 'test-defeat/suppression' \
      || matches 'Assert\.False\([[:space:]]*false[[:space:]]*[),]' 'test-defeat/suppression'; } \
      && reasons+=("adds a tautological assertion (Assert.True(true) / Assert.False(false)) — assert observable behaviour, not a constant (Test leanness #15)")
fi
if path_matches_i '\.(ts|tsx|js|jsx|mts|cts|mjs|cjs)$'; then
    matches 'eslint-disable' 'test-defeat/suppression' \
      && reasons+=("adds an 'eslint-disable' directive — fix the lint cause, don't silence it")
    matches '@ts-(ignore|nocheck)' 'test-defeat/suppression' \
      && reasons+=("adds '@ts-ignore'/'@ts-nocheck' — fix the type error, don't suppress it")
fi

# --- Test-defeats in spec files (focused/skipped tests, tautological expects) ---
if path_matches_i '\.spec\.(ts|tsx|js|jsx|mts|cts)$'; then
    { matches '^[[:space:]]*f(it|describe)[[:space:]]*\(' 'test-defeat/suppression' \
      || matches '\b(it|describe)\.only[[:space:]]*\(' 'test-defeat/suppression'; } \
      && reasons+=("adds a focused test (fit/fdescribe/.only) — it silently skips the rest of the suite; remove it before committing")
    { matches '^[[:space:]]*x(it|describe)[[:space:]]*\(' 'test-defeat/suppression' \
      || matches '\b(it|describe)\.skip[[:space:]]*\(' 'test-defeat/suppression'; } \
      && reasons+=("skips a test (xit/xdescribe/.skip) — don't skip; fix the test or record it in TECH_DEBT.md (Verification Rule #5)")
    { matches 'expect\([[:space:]]*true[[:space:]]*\)\.toBe\([[:space:]]*true[[:space:]]*\)' 'test-defeat/suppression' \
      || matches 'expect\([[:space:]]*false[[:space:]]*\)\.toBe\([[:space:]]*false[[:space:]]*\)' 'test-defeat/suppression'; } \
      && reasons+=("adds a tautological assertion (expect(true).toBe(true)) — assert observable behaviour, not a constant (Test leanness #15)")
fi

# --- High-confidence secrets (any file, fail closed) ---
secret=""
matches '-----BEGIN [A-Z ]*PRIVATE KEY-----' 'secret' && secret="a private key block"
[ -z "$secret" ] && matches 'AKIA[0-9A-Z]{16}' 'secret'        && secret="an AWS access key id (AKIA…)"
[ -z "$secret" ] && matches 'gh[oprsu]_[A-Za-z0-9]{36}' 'secret' && secret="a classic GitHub token (gh*_…)"
[ -z "$secret" ] && matches 'github_pat_[0-9A-Za-z]{22}_[0-9A-Za-z]{59,}' 'secret' && secret="a fine-grained GitHub token (github_pat_…)"
[ -z "$secret" ] && matches 'xox[baprs]-[A-Za-z0-9-]{10,}' 'secret' && secret="a Slack token (xox…)"
[ -z "$secret" ] && matches 'sk-[A-Za-z0-9_-]{20,}' 'secret'    && secret="an API secret key (sk-…)"
[ -z "$secret" ] && matches 'AIza[0-9A-Za-z_-]{35}' 'secret'    && secret="a Google API key (AIza…)"
[ -n "$secret" ] && reasons+=("contains $secret — secrets must not be committed; use user-secrets / env vars / a vault")

# --- Generic credential assignment (skip test / sample / Development files & placeholders) ---
# This heuristic deliberately remains fail-open: its two-stage pipeline is outside the typed
# high-confidence patterns above, and an operational grep error must not brick an ordinary write.
case "$fp" in
  *[Tt]est*|*spec*|*Development*|*example*|*sample*|*mock*|*fixture*) ;;
  *)
    cred=$(printf '%s' "$content" \
      | grep -Ei '(password|passwd|pwd|secret|api[_-]?key|access[_-]?key|client[_-]?secret)["'"'"' ]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,}["'"'"']|connectionstring["'"'"' ]*[:=][[:space:]]*["'"'"'][^"'"'"']*(password|pwd)[[:space:]]*=[[:space:]]*[^;"'"'"']{4,}[^"'"'"']*["'"'"']|connectionstring["'"'"' ]*[:=][[:space:]]*["'"'"'][^"'"'"']*://[^/[:space:]:@]+:[^/[:space:]@]+@[^"'"'"']*["'"'"']' 2>/dev/null \
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
