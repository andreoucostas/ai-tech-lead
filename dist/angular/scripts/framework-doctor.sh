#!/usr/bin/env bash
# Developer-machine enforcement diagnostic. No jq/python dependency by design.
set +e
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
missing=0
missing_rows=0
ok=0
row() {
  printf '[%s] %s - %s\n' "$1" "$2" "$3"
  [ "$1" = OK ] && ok=$((ok + 1))
  if [ "$1" = MISSING ]; then missing=1; missing_rows=$((missing_rows + 1)); fi
}
has() { command -v "$1" >/dev/null 2>&1; }
finish() {
  echo
  echo '[CANT-VERIFY] Claude hooks - start claude here and ask what the session preload contained; pass = the reply quotes a block that starts with "## Session preload". No preload usually means folder trust is pending.'
  echo '[CANT-VERIFY] Claude write guard - ask it to create tmp-doctor-canary.txt containing AKIA plus 16 uppercase letters/digits; pass = the hook says "Blocked write to". A polite refusal is not a pass; delete the file if it lands.'
  echo '[CANT-VERIFY] Copilot VS Code hooks - use the same canary in agent mode; pass = permissionDecisionReason says "Blocked write to". No deny means Preview agent hooks are disabled by you or your GitHub organization administrator.'
  echo '[CANT-VERIFY] Copilot CLI trust - use the same canary after opening and trusting this folder interactively; pass = permissionDecisionReason says "Blocked write to".'
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
elif has python3; then
  values=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d.get("template", "")); print(d.get("version", "")); print(d.get("applied", ""))' "$stamp" 2>/dev/null)
  template=$(printf '%s\n' "$values" | sed -n '1p')
  version=$(printf '%s\n' "$values" | sed -n '2p')
  applied=$(printf '%s\n' "$values" | sed -n '3p')
else
  template=$(sed -n 's/.*"template"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$stamp" | head -1)
  version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$stamp" | head -1)
  applied=$(sed -n 's/.*"applied"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$stamp" | head -1)
fi
if [ -z "$template" ]; then
  row MISSING 'Install state' '.claude/framework-version.json is invalid JSON. Fix: re-run the framework installer.'
  finish
fi
row OK 'Install state' "template=$template; version=$version; applied=$applied"

pending=0
if [ -f "$root/.claude/adoption-pending.json" ]; then
  row PENDING 'Bootstrap/adoption state' 'adoption pending. A developer must run /adopt.'; pending=1
elif grep -q 'BOOTSTRAP_PENDING' "$root/CLAUDE.md" 2>/dev/null; then
  row PENDING 'Bootstrap/adoption state' 'bootstrap pending. A developer must run /bootstrap.'; pending=1
else row OK 'Bootstrap/adoption state' 'repository setup is complete.'
fi

settings="$root/.claude/settings.json"
commands=$(sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$settings" 2>/dev/null)
shells=$(printf '%s\n' "$commands" | sed -n 's/^[[:space:]]*\([^[:space:]]*\)[[:space:]].*/\1/p' | sort -u)
if [ -z "$shells" ]; then
  row MISSING 'Wired hook shell' 'no hook interpreter could be read from .claude/settings.json. Fix: re-run the installer to rewire hooks.'
else
  absent=''
  while IFS= read -r shell; do
    [ -n "$shell" ] && ! has "$shell" && absent="${absent}${absent:+,}$shell"
  done <<EOF
$shells
EOF
  if [ -n "$absent" ]; then
    row MISSING 'Wired hook shell' "committed hooks use $absent, which this machine does not have: no write guard, build feedback, or audit trail. Fix: install $absent, or re-run the installer to rewire hooks."
  else row OK 'Wired hook shell' "available: $(printf '%s\n' "$shells" | paste -sd, -)."
  fi
fi

paths=$( { printf '%s\n' "$commands" | grep -oE '[^ ]*\.claude[\\/]hooks[\\/][^ ]+'; sed -n 's/.*"\(bash\|powershell\)"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\2/p' "$root/.github/hooks/hooks.json" 2>/dev/null; } | sed 's#\\\\#/#g;s#^\./##' | sort -u)
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

if printf '%s\n' "$shells" | grep -qx bash; then
  if has jq || has python3; then row OK 'Guard JSON parser' 'jq or python3 is available.'
  else row MISSING 'Guard JSON parser' 'the bash write guard is INACTIVE and allows writes with only a warning. Fix: install jq.'; fi
else row OK 'Guard JSON parser' 'not required by the wired PowerShell hooks.'
fi

if [ "$pending" -eq 1 ]; then row PENDING 'Stack toolchain' 'not checked until /bootstrap or /adopt completes.'
else
  missing_tools=''
  case "$template" in *dotnet*|*monorepo*) has dotnet || missing_tools=dotnet;; esac
  case "$template" in *angular*|*monorepo*) has node || missing_tools="${missing_tools}${missing_tools:+,}node"; has npx || missing_tools="${missing_tools}${missing_tools:+,}npx";; esac
  if [ -n "$missing_tools" ]; then row MISSING 'Stack toolchain' "compile checks after writes cannot run; errors surface at CI instead. Fix: install $missing_tools."
  else row OK 'Stack toolchain' "required $template toolchain commands are available."; fi
fi

copilot_json="$root/.github/hooks/hooks.json"
copilot_valid=0
copilot_unknown=0
if [ -f "$copilot_json" ]; then
  if has jq && jq empty "$copilot_json" >/dev/null 2>&1; then copilot_valid=1
  elif has python3 && python3 -m json.tool "$copilot_json" >/dev/null 2>&1; then copilot_valid=1
  else copilot_unknown=1
  fi
fi
# Twin divergence by design: only this twin can hit the CANT-VERIFY branch below — the .ps1 twin
# always has a JSON parser (PowerShell native), so it reports valid/invalid directly.
if [ "$copilot_valid" -eq 1 ]; then
  if has copilot; then row OK 'Copilot surface' 'hooks.json is valid and the Copilot CLI is present.'
  else row OK 'Copilot surface' 'hooks.json is valid; Copilot CLI is absent (Claude-only teams need no action). If your team uses Copilot, the GA CLI is the cheapest real enforcement path.'; fi
elif [ "$copilot_unknown" -eq 1 ]; then row CANT-VERIFY 'Copilot surface' 'hooks.json exists, but JSON validity cannot be checked without jq or python3. Install jq, then rerun the doctor.'
else row MISSING 'Copilot surface' '.github/hooks/hooks.json is missing or invalid. Fix: re-run the installer.'
fi

if [ "$pending" -eq 1 ]; then row PENDING 'Mirror and version integrity' 'not checked until /bootstrap or /adopt completes.'
elif [ -f "$root/scripts/template-checks.sh" ] && bash "$root/scripts/template-checks.sh" >/dev/null 2>&1; then row OK 'Mirror and version integrity' 'template-checks passed.'
else row MISSING 'Mirror and version integrity' 'CLAUDE.md and AGENTS.md or version stamps have drifted. Fix: run /generate-copilot, then scripts/docs-sync-check.sh.'
fi

audit="$root/.claude/ai-audit.log"
if [ "$pending" -eq 1 ]; then row PENDING 'Audit trail substrate' 'not checked until /bootstrap or /adopt completes.'
elif [ ! -f "$audit" ]; then row MISSING 'Audit trail substrate' '.claude/ai-audit.log is missing, so regulated-environment changes are not being captured. Fix: create the file and ensure developers can append to it.'
elif [ -w "$audit" ]; then row OK 'Audit trail substrate' 'audit log exists and is appendable.'
else row MISSING 'Audit trail substrate' 'audit log is not appendable. Fix: grant the developer write access to .claude/ai-audit.log.'
fi
finish
