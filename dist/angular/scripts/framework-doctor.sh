#!/usr/bin/env bash
# Developer-machine enforcement diagnostic. No jq/python dependency by design.
set +e
# Root resolution uses shell builtins only (no dirname): this script must run even on a
# machine whose PATH is broken — that is exactly the machine it exists to diagnose.
# Backslashes are normalized first: on Git bash the script path may arrive Windows-style.
p=${0//\\//}
case "$p" in
  */*) root=$(CDPATH= cd -- "${p%/*}/.." && pwd) ;;
  *)   root=$(CDPATH= cd -- .. && pwd) ;;
esac
missing=0
missing_rows=0
ok=0
row() {
  printf '[%s] %s - %s\n' "$1" "$2" "$3"
  [ "$1" = OK ] && ok=$((ok + 1))
  if [ "$1" = MISSING ]; then missing=1; missing_rows=$((missing_rows + 1)); fi
}
has() { command -v "$1" >/dev/null 2>&1; }
split_first_command_word() {
  value=$(printf '%s\n' "$1" | sed 's/^[[:space:]]*//')
  first_word=''; word_remainder=''
  case "$value" in
    \"*)
      first_word=$(printf '%s\n' "$value" | sed -n 's/^"\([^"]*\)"[[:space:]]*\(.*\)$/\1/p')
      word_remainder=$(printf '%s\n' "$value" | sed -n 's/^"\([^"]*\)"[[:space:]]*\(.*\)$/\2/p') ;;
    \'*)
      first_word=$(printf '%s\n' "$value" | sed -n "s/^'\\([^']*\\)'[[:space:]]*\\(.*\\)\$/\\1/p")
      word_remainder=$(printf '%s\n' "$value" | sed -n "s/^'\\([^']*\\)'[[:space:]]*\\(.*\\)\$/\\2/p") ;;
    *)
      first_word=$(printf '%s\n' "$value" | sed -n 's/^\([^[:space:]]*\)[[:space:]]*\(.*\)$/\1/p')
      word_remainder=$(printf '%s\n' "$value" | sed -n 's/^\([^[:space:]]*\)[[:space:]]*\(.*\)$/\2/p') ;;
  esac
  [ -n "$first_word" ]
}
is_guard_sh_target() {
  split_first_command_word "$1" || return 1
  normalized=$(printf '%s\n' "$first_word" | sed 's#\\\\#/#g;s#\\#/#g')
  case "$normalized" in .claude/hooks/guard.sh|./.claude/hooks/guard.sh) return 0;; *) return 1;; esac
}
is_bash_interpreter() {
  normalized=$(printf '%s\n' "$1" | sed 's#\\\\#/#g;s#\\#/#g')
  leaf=${normalized##*/}
  case "$leaf" in [Bb][Aa][Ss][Hh]|[Bb][Aa][Ss][Hh].[Ee][Xx][Ee]) return 0;; *) return 1;; esac
}
is_claude_bash_guard_command() {
  command=$1
  split_first_command_word "$command" || return 1
  shell=$first_word
  remainder=$word_remainder
  is_bash_interpreter "$shell" || return 1
  remainder=$(printf '%s\n' "$remainder" | sed ':again; s/^[[:space:]]*\(--noprofile\|--norc\|-File\|--\)[[:space:]][[:space:]]*//; t again')
  is_guard_sh_target "$remainder"
}
# Resolve a WORKING python once, by execution rather than by name (same grammar as guard.sh): a
# python.org install ships python.exe and no python3.exe, and the Microsoft Store alias stub
# resolves under the name `python` but is not an interpreter (it prints "Python was not found"
# and exits 49) -- a name-only probe would select it and then silently produce nothing. Memoised
# so the probe runs at most once even though this script asks the same question four times.
_pybin_resolved=0
_pybin=""
resolve_pybin() {
  [ "$_pybin_resolved" -eq 1 ] && return
  _pybin_resolved=1
  for cand in python3 python py; do
    if command -v "$cand" >/dev/null 2>&1 &&
       [ "$(printf '{}' | "$cand" -c 'import json,sys; json.load(sys.stdin); sys.stdout.write("ok")' 2>/dev/null)" = "ok" ]; then
      _pybin=$cand; return
    fi
  done
}
finish() {
  echo
  echo '[CANT-VERIFY] Claude hooks - start claude here and ask what the session preload contained; pass = the reply quotes a block that starts with "## Session preload". No preload usually means folder trust is pending.'
  echo '[CANT-VERIFY] Claude write guard - ask it to create tmp-doctor-canary.txt containing AKIA plus 16 uppercase letters/digits; pass = the hook says "Blocked write to". A polite refusal is not a pass; delete the file if it lands.'
  echo '[CANT-VERIFY] Copilot VS Code hooks - use the same canary in agent mode; pass = permissionDecisionReason says "Blocked write to". No deny means Preview agent hooks are disabled by you or your GitHub organization administrator.'
  echo '[CANT-VERIFY] Copilot CLI trust - use the same canary after opening and trusting this folder interactively; pass = permissionDecisionReason says "Blocked write to".'
  echo '[CANT-VERIFY] Agent-host stack toolchain - through the actual agent, make and then revert a harmless deliberate compile/type error in a real build-relevant file after the post-write throttle has elapsed; pass = the hook output starts with "## dotnet build failed" or "## tsc --noEmit failed". Model diagnosis or a direct terminal build is not a pass.'
  echo "Script-verifiable checks: $ok ok / $missing_rows missing."
  echo 'Enforcement is only FULL if the canaries above also pass; a script cannot see inside your agent.'
  exit "$missing"
}

echo 'AI Tech Lead framework doctor'
echo '============================'
stamp="$root/.claude/framework-version.json"
if [ ! -f "$stamp" ]; then
  row MISSING 'Install state' 'not a framework install. Fix: run the framework installer for this repository.'
  finish
fi
if has jq; then
  template=$(jq -r '.template // ""' "$stamp" 2>/dev/null)
  version=$(jq -r '.version // ""' "$stamp" 2>/dev/null)
  applied=$(jq -r '.applied // ""' "$stamp" 2>/dev/null)
else
  resolve_pybin
  if [ -n "$_pybin" ]; then
    values=$("$_pybin" -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d.get("template", "")); print(d.get("version", "")); print(d.get("applied", ""))' "$stamp" 2>/dev/null)
    template=$(printf '%s\n' "$values" | sed -n '1p')
    version=$(printf '%s\n' "$values" | sed -n '2p')
    applied=$(printf '%s\n' "$values" | sed -n '3p')
  else
    template=$(sed -n 's/.*"template"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$stamp" | head -1)
    version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$stamp" | head -1)
    applied=$(sed -n 's/.*"applied"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$stamp" | head -1)
  fi
fi
if [ -z "$template" ]; then
  row MISSING 'Install state' '.claude/framework-version.json is invalid JSON. Fix: re-run the framework installer.'
  finish
fi
row OK 'Install state' "template=$template; version=$version; applied=$applied"

claude="$root/CLAUDE.md"
carrier="$root/.github/instructions/framework-rules.instructions.md"
import_line='@.github/instructions/framework-rules.instructions.md'
import_status=1
if [ -f "$carrier" ]; then grep -qF "$import_line" "$claude" 2>/dev/null; import_status=$?; fi
if [ -f "$carrier" ] && [ "$import_status" -eq 0 ]; then
  row OK 'Framework rules delivery' 'CLAUDE.md imports the current framework rules carrier.'
elif [ -f "$carrier" ] && [ "$import_status" -eq 1 ]; then
  row MISSING 'Framework rules delivery' "the carrier is installed but CLAUDE.md does not import it. Fix: add $import_line where the Verification Rules, Leanness, SOLID, and Agentic Workflow sections belong."
elif [ -f "$carrier" ]; then
  row CANT-VERIFY 'Framework rules delivery' 'grep could not inspect CLAUDE.md; this is a host/resource problem, not evidence that the framework rules import is absent.'
else
  row MISSING 'Framework rules delivery' 'the framework rules carrier is absent. Fix: re-run the framework installer.'
fi

framework_headings='Verification Rules
Leanness
SOLID
Agentic Workflow'
if [ ! -f "$claude" ]; then
  row MISSING 'Protected-file sync' 'CLAUDE.md is absent; protected-file migration state cannot be inspected.'
elif [ ! -f "$carrier" ] || [ "$import_status" -eq 1 ]; then
  row OK 'Protected-file sync' 'deferred to Framework rules delivery.'
elif [ "$import_status" -ne 0 ]; then
  row CANT-VERIFY 'Protected-file sync' 'grep could not inspect CLAUDE.md; this is a host/resource problem, so protected-file migration state cannot be verified.'
else
  heading_count=0
  inline_headings=''
  heading_probe_failed=0
  while IFS= read -r heading; do
    [ -z "$heading" ] && continue
    heading_count=$((heading_count + 1))
    grep -q "^##[[:space:]][[:space:]]*$heading[[:space:]]*$" "$claude" 2>/dev/null
    heading_status=$?
    if [ "$heading_status" -eq 0 ]; then
      if [ -n "$inline_headings" ]; then inline_headings="$inline_headings, $heading"; else inline_headings=$heading; fi
    elif [ "$heading_status" -ne 1 ]; then
      heading_probe_failed=1
    fi
  done <<EOF
$framework_headings
EOF
  if [ "$heading_probe_failed" -eq 1 ]; then
    row CANT-VERIFY 'Protected-file sync' 'grep could not inspect CLAUDE.md headings; this is a host/resource problem, so protected-file migration state cannot be verified.'
  elif [ "$heading_count" -ne 4 ]; then
    row MISSING 'Protected-file sync' 'framework heading inspection is incomplete; protected-file migration state cannot be verified.'
  elif [ -z "$inline_headings" ]; then
    row OK 'Protected-file sync' 'migrated - the carrier is authoritative.'
  else
    row PENDING 'Protected-file sync' "migration incomplete - these sections duplicate the carrier and may conflict: $inline_headings. Fix: delete them from CLAUDE.md."
  fi
fi

pending=0
if [ -f "$root/.claude/adoption-pending.json" ]; then
  row PENDING 'Bootstrap/adoption state' 'adoption pending. A developer must run /adopt.'; pending=1
else
  grep -q 'BOOTSTRAP_PENDING' "$root/CLAUDE.md" 2>/dev/null
  pending_status=$?
  if [ "$pending_status" -eq 0 ]; then
    row PENDING 'Bootstrap/adoption state' 'bootstrap pending. A developer must run /bootstrap.'; pending=1
  elif [ "$pending_status" -eq 1 ]; then
    row OK 'Bootstrap/adoption state' 'repository setup is complete.'
  else
    row CANT-VERIFY 'Bootstrap/adoption state' 'grep could not inspect CLAUDE.md; this is a host/resource problem, not evidence that repository setup is complete.'
  fi
fi

settings="$root/.claude/settings.json"
commands=$(sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\\"\([^"]*\)\\"\(.*\)".*/"\1"\2/p; t; s/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$settings" 2>/dev/null)
shells=$(printf '%s\n' "$commands" | sed -n 's/^[[:space:]]*"\([^"]*\)".*/\1/p; t; s/^[[:space:]]*\([^[:space:]]*\)[[:space:]].*/\1/p' | sort -u)
bash_guard_registered=0
while IFS= read -r command; do
  [ -z "$command" ] && continue
  if is_claude_bash_guard_command "$command"; then bash_guard_registered=1; fi
done <<EOF
$commands
EOF
if [ -z "$shells" ]; then
  row MISSING 'Wired hook shell' 'no hook interpreter could be read from .claude/settings.json. Fix: re-run the installer to rewire hooks.'
else
  missing_shells=''; bare_shells=''; existing_shells=''
  while IFS= read -r shell; do
    [ -z "$shell" ] && continue
    case "$shell" in
      /*|[A-Za-z]:[\\/]*)
        if [ -f "$shell" ]; then existing_shells="${existing_shells}${existing_shells:+,}$shell"
        else missing_shells="${missing_shells}${missing_shells:+,}$shell"; fi ;;
      *) bare_shells="${bare_shells}${bare_shells:+,}$shell" ;;
    esac
  done <<EOF
$shells
EOF
  if [ -n "$missing_shells" ]; then
    row MISSING 'Wired hook shell' "the configured machine-specific interpreter path is absent on this machine: $missing_shells. Fix: re-run the installer to restore portable bare-name wiring."
  elif [ -n "$bare_shells" ]; then
    row CANT-VERIFY 'Wired hook shell' "hooks use the portable bare interpreter name $bare_shells; this doctor cannot observe the agent host's PATH. Use Hook liveness and the host canaries below."
  else row OK 'Wired hook shell' "wired interpreter paths exist on this machine: $existing_shells."
  fi
fi

liveness="$root/.claude/.state/last-session-start"
if [ -r "$liveness" ]; then
  last_session_start=$(cat "$liveness" 2>/dev/null)
  row OK 'Hook liveness' "hooks have demonstrably run in this repo, most recently at '$last_session_start'."
else
  row CANT-VERIFY 'Hook liveness' 'no hook has recorded a run here; if you have already started a Claude Code session in this repo, your hooks are not firing -- check the wired interpreter above, and see docs/enforcement-surfaces.md.'
fi

copilot_hook_commands=$(grep -oE '"(bash|powershell)"[[:space:]]*:[[:space:]]*"[^"]*"' "$root/.github/hooks/hooks.json" 2>/dev/null | sed -n 's/^"[^"]*"[[:space:]]*:[[:space:]]*"\([^"]*\)"$/\1/p')
paths=$( { printf '%s\n' "$commands" | grep -oE '[^ ]*\.claude[\\/]hooks[\\/][^ ]+'; printf '%s\n' "$copilot_hook_commands" | sed 's/[[:space:]].*$//'; } | sed -e 's#\\\\#/#g' -e 's#\\#/#g' -e 's#^"##' -e 's#"$##' -e "s#^'##" -e "s#'\$##" -e 's#^\./##' | sort -u)
copilot_bash_commands=$(grep -oE '"bash"[[:space:]]*:[[:space:]]*"[^"]*"' "$root/.github/hooks/hooks.json" 2>/dev/null | sed -n 's/^"bash"[[:space:]]*:[[:space:]]*"\([^"]*\)"$/\1/p')
while IFS= read -r command; do
  [ -z "$command" ] && continue
  if is_guard_sh_target "$command"; then bash_guard_registered=1; fi
done <<EOF
$copilot_bash_commands
EOF
missing_paths=''; count=0
while IFS= read -r path; do
  [ -z "$path" ] && continue
  count=$((count + 1))
  [ ! -f "$root/$path" ] && missing_paths="${missing_paths}${missing_paths:+,}$path"
done <<EOF
$paths
EOF
if [ "$count" -eq 0 ] || [ -n "$missing_paths" ]; then
  row MISSING 'Hook files' "registration points at a missing file; hooks are silently dead. Fix: re-run the installer. Missing: ${missing_paths:-<no registrations>}"
else row OK 'Hook files' "$count registered files are present."
fi

if [ "$bash_guard_registered" -eq 1 ]; then
  if has jq; then row OK 'Guard JSON parser' 'jq or a working python interpreter is available in this Bash environment.'
  else
    resolve_pybin
    if [ -n "$_pybin" ]; then row OK 'Guard JSON parser' 'jq or a working python interpreter is available in this Bash environment.'
    else row MISSING 'Guard JSON parser' 'this Bash environment has no working JSON parser, so guard.sh is INACTIVE and allows writes with only a warning. Fix: install jq.'; fi
  fi
else row OK 'Guard JSON parser' 'not required by the registered PowerShell guards.'
fi

if [ "$pending" -eq 1 ]; then row PENDING 'Stack toolchain' 'not checked until /bootstrap or /adopt completes.'
else
  missing_tools=''
  case "$template" in *dotnet*|*monorepo*) has dotnet || missing_tools=dotnet;; esac
  case "$template" in *angular*|*monorepo*) has node || missing_tools="${missing_tools}${missing_tools:+,}node"; has npx || missing_tools="${missing_tools}${missing_tools:+,}npx";; esac
  if [ -n "$missing_tools" ]; then row MISSING 'Stack toolchain' "the required toolchain commands are absent from this doctor process environment: $missing_tools; this does not prove the agent host's post-write environment. Fix: install them on this machine if the actual-host canary also fails."
  else row OK 'Stack toolchain' "required $template toolchain commands are available in this doctor process environment; this does not prove the agent host's post-write environment."; fi
fi

copilot_json="$root/.github/hooks/hooks.json"
copilot_valid=0
copilot_invalid=0
copilot_unknown=0
if [ -f "$copilot_json" ]; then
  if has jq; then
    if jq empty "$copilot_json" >/dev/null 2>&1; then copilot_valid=1; else copilot_invalid=1; fi
  else
    resolve_pybin
    if [ -n "$_pybin" ]; then
      if "$_pybin" -m json.tool "$copilot_json" >/dev/null 2>&1; then copilot_valid=1; else copilot_invalid=1; fi
    else
      copilot_unknown=1
    fi
  fi
fi
# Twin divergence by design: only this twin can hit the CANT-VERIFY branch below — the .ps1 twin
# always has a JSON parser (PowerShell native), so it reports valid/invalid directly.
if [ "$copilot_valid" -eq 1 ]; then
  if has copilot; then row OK 'Copilot surface' 'hooks.json is valid and Copilot CLI is available in this doctor process environment.'
  else row OK 'Copilot surface' 'hooks.json is valid; Copilot CLI is absent from this doctor process environment. Claude-only teams need no action; Copilot teams must use the actual-surface canaries below.'; fi
elif [ "$copilot_invalid" -eq 1 ]; then row MISSING 'Copilot surface' '.github/hooks/hooks.json exists but is not valid JSON. Fix: re-run the installer or correct the file.'
elif [ "$copilot_unknown" -eq 1 ]; then row CANT-VERIFY 'Copilot surface' 'hooks.json exists, but JSON validity cannot be checked without jq or a working python interpreter. Install jq, then rerun the doctor.'
else row MISSING 'Copilot surface' '.github/hooks/hooks.json is missing. Fix: re-run the installer.'
fi

if [ "$pending" -eq 1 ]; then row PENDING 'Mirror and version integrity' 'not checked until /bootstrap or /adopt completes.'
elif [ ! -f "$root/scripts/template-checks.sh" ]; then row MISSING 'Mirror and version integrity' 'template-checks is missing. Fix: re-run the installer.'
else
  # Separate "the checker could not run" from "the checker found drift". Collapsing them told the
  # user their docs had drifted whenever the checker merely failed to start -- a specific, false,
  # actionable diagnosis. Exit 127 is the shell's "command not found"; 126 is "found but not
  # executable" (the exec bit, which Windows does not carry and Linux enforces).
  template_checks_out=$(bash "$root/scripts/template-checks.sh" 2>&1); template_checks_rc=$?
  if [ "$template_checks_rc" -eq 0 ]; then row OK 'Mirror and version integrity' 'template-checks passed.'
  elif [ "$template_checks_rc" -eq 126 ] || [ "$template_checks_rc" -eq 127 ]; then
    row MISSING 'Mirror and version integrity' 'could not execute template-checks, so drift is UNKNOWN rather than found. This is a host problem, not a documentation problem. Fix: run scripts/template-checks.sh yourself and act on what it says.'
  else row MISSING 'Mirror and version integrity' 'CLAUDE.md and AGENTS.md or version stamps have drifted. Fix: run /generate-copilot, then scripts/docs-sync-check.sh.'
  fi
fi

audit="$root/.claude/ai-audit.log"
if [ "$pending" -eq 1 ]; then row PENDING 'Audit trail substrate' 'not checked until /bootstrap or /adopt completes.'
elif [ ! -f "$audit" ]; then row MISSING 'Audit trail substrate' '.claude/ai-audit.log is missing, so regulated-environment changes are not being captured. Fix: create the file and ensure developers can append to it.'
elif [ -w "$audit" ]; then row OK 'Audit trail substrate' 'audit log exists and is appendable.'
else row MISSING 'Audit trail substrate' 'audit log is not appendable. Fix: grant the developer write access to .claude/ai-audit.log.'
fi
finish
