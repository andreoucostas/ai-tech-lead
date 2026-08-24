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
stack_canary='through the actual agent, make and then revert a harmless deliberate compile/type error in a real build-relevant file after the post-write throttle has elapsed; pass = the hook output starts with "## dotnet build failed" or "## tsc --noEmit failed". Model diagnosis or a direct terminal build is not a pass.'
row() {
  printf '[%s] %s - %s\n' "$1" "$2" "$3"
  [ "$1" = OK ] && ok=$((ok + 1))
  if [ "$1" = MISSING ]; then missing=1; missing_rows=$((missing_rows + 1)); fi
}
has() { command -v "$1" >/dev/null 2>&1; }
# Git for Windows can resolve the Windows `sort.exe` before Git's POSIX sort, which treats `-u`
# as a bad filename and silently erases the registrations below. This tiny native equivalent is
# sufficient here: inputs are short newline-delimited command/path lists and only need de-duplication.
unique_lines() {
  unique_result=''
  while IFS= read -r unique_item; do
    [ -z "$unique_item" ] && continue
    case "
$unique_result
" in *"
$unique_item
"*) ;; *) unique_result="${unique_result}${unique_result:+
}$unique_item";; esac
  done
  [ -z "$unique_result" ] || printf '%s\n' "$unique_result"
}
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
_jq_working_resolved=0
_jq_working=0
has_working_jq() {
  if [ "$_jq_working_resolved" -eq 0 ]; then
    _jq_working_resolved=1
    if command -v jq >/dev/null 2>&1 && printf '{}' | jq -e . >/dev/null 2>&1; then _jq_working=1; fi
  fi
  [ "$_jq_working" -eq 1 ]
}
# jq deliberately accepts NaN, Infinity, and leading-zero integers. Reject those extensions outside
# strings before every jq decision so all doctor parser paths share the strict RFC JSON boundary.
strict_json_jq_lexemes() {
  local text="$1" i=0 length=${#1} quoted=0 escaped=0 c j token scan
  while [ "$i" -lt "$length" ]; do
    c=${text:$i:1}
    if [ "$quoted" -eq 1 ]; then
      if [ "$escaped" -eq 1 ]; then escaped=0; elif [ "$c" = '\' ]; then escaped=1; elif [ "$c" = '"' ]; then quoted=0; fi
    else
      case "$c" in
        '"') quoted=1 ;;
        ' '|$'\t'|$'\r'|$'\n'|'{'|'}'|'['|']'|','|':') ;;
        t) [ "${text:$i:4}" = true ] || return 1; i=$((i+4)); continue ;;
        f) [ "${text:$i:5}" = false ] || return 1; i=$((i+5)); continue ;;
        n) [ "${text:$i:4}" = null ] || return 1; i=$((i+4)); continue ;;
        -|[0-9])
          j=$i
          while [ "$j" -lt "$length" ]; do
            scan=${text:$j:1}
            case "$scan" in ' '|$'\t'|$'\r'|$'\n'|'{'|'}'|'['|']'|','|':') break ;; esac
            j=$((j+1))
          done
          token=${text:$i:$((j-i))}
          [[ "$token" =~ ^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$ ]] || return 1
          i=$j
          continue
          ;;
        *) return 1 ;;
      esac
    fi
    i=$((i+1))
  done
  [ "$quoted" -eq 0 ] && [ "$escaped" -eq 0 ]
}
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
angular_json_evidence() {
  local kind=$1 marker_file=$2 parsed='' json_text=''
  if has_working_jq; then
    json_text=$(<"$marker_file") || return 2; strict_json_jq_lexemes "$json_text" || return 2
    printf '%s' "$json_text" | jq -e 'type == "object" or error("Angular evidence root must be an object")' >/dev/null 2>&1 || return 2
    if [ "$kind" = workspace ]; then
      parsed=$(jq -r '# angular_workspace_evidence
        type == "object"' 2>/dev/null <<<"$json_text") || return 2
    elif [ "$kind" = package ]; then
      parsed=$(jq -r '# angular_package_evidence
        type == "object" and ([.dependencies?, .devDependencies?, .peerDependencies?, .optionalDependencies? | objects | has("@angular/core")] | any)' 2>/dev/null <<<"$json_text") || return 2
    else
      parsed=$(jq -r '# angular_nx_evidence
        def angular_token: type == "string" and test("^@(angular|nx/angular|angular-devkit|schematics/angular)(/[^\\s]+|:[^\\s]+)$");
        def named_map: type == "object" and any(keys[]; angular_token);
        def target_map($keys_are_tokens): type == "object" and any(to_entries[];
          (($keys_are_tokens and (.key | angular_token)) or
           (.value | type == "object" and ((.executor? | angular_token) or (.generator? | angular_token) or (.collection? | angular_token) or (.plugin? | angular_token)))));
        def nx_evidence:
          ((.plugins? | if type == "array" then any(.[]; (angular_token or (type == "object" and (.plugin? | angular_token)))) else false end) or
           (.generators? | named_map) or (.schematics? | named_map) or
           (.targets? | target_map(false)) or (.architect? | target_map(false)) or (.targetDefaults? | target_map(true)));
        type == "object" and nx_evidence' 2>/dev/null <<<"$json_text") || return 2
    fi
    [ "$parsed" = true ]; return
  fi
  resolve_pybin
  [ -n "$_pybin" ] || return 2
  "$_pybin" -c 'import json,re,sys
kind,path=sys.argv[1:]
try:
    with open(path,encoding="utf-8-sig") as f: root=json.load(f,parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))
except Exception:
    sys.exit(2)
if not isinstance(root,dict): sys.exit(2)
if kind=="workspace": sys.exit(0)
token=re.compile(r"^@(angular|nx/angular|angular-devkit|schematics/angular)(/[^\s]+|:[^\s]+)$")
def nx_evidence(root):
    plugins=root.get("plugins")
    if isinstance(plugins,list) and any((isinstance(p,str) and token.fullmatch(p)) or (isinstance(p,dict) and isinstance(p.get("plugin"),str) and token.fullmatch(p["plugin"])) for p in plugins): return True
    for name in ("generators","schematics"):
        value=root.get(name)
        if isinstance(value,dict) and any(token.fullmatch(str(k)) for k in value): return True
    for name in ("targets","architect","targetDefaults"):
        value=root.get(name)
        if not isinstance(value,dict): continue
        for key,entry in value.items():
            if name=="targetDefaults" and token.fullmatch(str(key)): return True
            if isinstance(entry,dict) and any(isinstance(entry.get(field),str) and token.fullmatch(entry[field]) for field in ("executor","generator","collection","plugin")): return True
    return False
if kind=="package": found=any(isinstance(root.get(s),dict) and "@angular/core" in root[s] for s in ("dependencies","devDependencies","peerDependencies","optionalDependencies"))
else: found=nx_evidence(root)
sys.exit(0 if found else 1)' "$kind" "$marker_file" 2>/dev/null
}
finish() {
  echo
  echo '[CANT-VERIFY] Claude hooks - start claude here and ask what the session preload contained; pass = the reply quotes a block that starts with "## Session preload". No preload usually means folder trust is pending.'
  echo '[CANT-VERIFY] Claude write guard - ask it to create tmp-doctor-canary.txt containing AKIA plus 16 uppercase letters/digits; pass = the hook says "Blocked write to". A polite refusal is not a pass; delete the file if it lands.'
  echo '[CANT-VERIFY] Copilot VS Code hooks - use the same canary in agent mode; pass = permissionDecisionReason says "Blocked write to". No deny means Preview agent hooks are disabled by you or your GitHub organization administrator.'
  echo '[CANT-VERIFY] Copilot CLI trust - use the same canary after opening and trusting this folder interactively; pass = permissionDecisionReason says "Blocked write to".'
  printf '[CANT-VERIFY] Agent-host stack toolchain - %s\n' "$stack_canary"
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
stamp_read_failed=0
stamp_text=$(<"$stamp") || stamp_read_failed=1
if [ "$stamp_read_failed" -eq 1 ]; then
  row CANT-VERIFY 'Install state' '.claude/framework-version.json exists but could not be read; its install state is unknown. Fix read access and rerun the doctor.'
  finish
fi
stamp_parsed=0
stamp_invalid=0
if has_working_jq; then
  if strict_json_jq_lexemes "$stamp_text" && printf '%s' "$stamp_text" | jq -e . >/dev/null 2>&1; then
    template=$(printf '%s' "$stamp_text" | jq -r 'if type == "object" and (.template | type) == "string" then .template else "" end' 2>/dev/null); template_status=$?
    version=$(printf '%s' "$stamp_text" | jq -r 'if type == "object" then (.version // "") else "" end' 2>/dev/null); version_status=$?
    applied=$(printf '%s' "$stamp_text" | jq -r 'if type == "object" then (.applied // "") else "" end' 2>/dev/null); applied_status=$?
    if [ "$template_status" -eq 0 ] && [ "$version_status" -eq 0 ] && [ "$applied_status" -eq 0 ]; then stamp_parsed=1; else stamp_invalid=1; fi
  else
    stamp_invalid=1
  fi
else
  resolve_pybin
  if [ -n "$_pybin" ]; then
    values=$(printf '%s' "$stamp_text" | "$_pybin" -c 'import json,sys; reject=lambda value: (_ for _ in ()).throw(ValueError(value)); d=json.load(sys.stdin,parse_constant=reject); t=d.get("template", "") if isinstance(d,dict) else ""; print(t if isinstance(t,str) else ""); print(d.get("version", "") if isinstance(d,dict) else ""); print(d.get("applied", "") if isinstance(d,dict) else "")' 2>/dev/null)
    if [ $? -eq 0 ]; then
      template=$(printf '%s\n' "$values" | sed -n '1p')
      version=$(printf '%s\n' "$values" | sed -n '2p')
      applied=$(printf '%s\n' "$values" | sed -n '3p')
      stamp_parsed=1
    else
      stamp_invalid=1
    fi
  fi
fi
if [ "$stamp_invalid" -eq 1 ]; then
  row MISSING 'Install state' '.claude/framework-version.json is invalid JSON. Fix: re-run the framework installer.'
  finish
fi
if [ "$stamp_parsed" -eq 0 ]; then
  template=unverified
  row CANT-VERIFY 'Install state' 'no working JSON parser (jq or python3/python/py) is available in this doctor process environment, so .claude/framework-version.json cannot be validated. Install one and rerun the doctor.'
elif case "$template" in *[![:space:]]*) false;; *) true;; esac; then
  row MISSING 'Install state' '.claude/framework-version.json is valid JSON but lacks the required non-empty string "template". Fix: re-run the framework installer.'
  finish
elif [ "$template" != dotnet ] && [ "$template" != angular ] && [ "$template" != monorepo ]; then
  row MISSING 'Install state' ".claude/framework-version.json names unsupported template \"$template\"; expected dotnet, angular, or monorepo. Fix: re-run the framework installer."
  finish
else
  row OK 'Install state' "template=$template; version=$version; applied=$applied"
fi

claude="$root/CLAUDE.md"
carrier="$root/.github/instructions/framework-rules.instructions.md"
import_line='@.github/instructions/framework-rules.instructions.md'
import_status=1
# An absent CLAUDE.md is a CONTENT fact, not a host failure. grep exits 2 for BOTH a missing file
# and a genuine execution failure, so the file has to be checked before that exit code can be read
# as "could not run". The .ps1 twin gets this for free from its Test-Path guard.
if [ -f "$carrier" ] && [ -f "$claude" ]; then grep -qF "$import_line" "$claude" 2>/dev/null; import_status=$?; fi
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
  # Same discrimination: no CLAUDE.md means nothing is pending, not that grep broke.
  if [ -f "$root/CLAUDE.md" ]; then
    grep -q 'BOOTSTRAP_PENDING' "$root/CLAUDE.md" 2>/dev/null
    pending_status=$?
  else
    pending_status=1
  fi
  if [ "$pending_status" -eq 0 ]; then
    row PENDING 'Bootstrap/adoption state' 'bootstrap pending. A developer must run /bootstrap.'; pending=1
  elif [ "$pending_status" -eq 1 ]; then
    row OK 'Bootstrap/adoption state' 'repository setup is complete.'
  else
    row CANT-VERIFY 'Bootstrap/adoption state' 'grep could not inspect CLAUDE.md; this is a host/resource problem, not evidence that repository setup is complete.'
  fi
fi

settings="$root/.claude/settings.json"
settings_read_failed=0
settings_invalid=0
settings_unknown=0
settings_parser=''
settings_text=''
if [ -f "$settings" ]; then settings_text=$(<"$settings") || settings_read_failed=1; fi
commands=''
if [ "$settings_read_failed" -eq 0 ]; then
  if [ -f "$settings" ]; then
    if has_working_jq; then strict_json_jq_lexemes "$settings_text" && printf '%s' "$settings_text" | jq empty >/dev/null 2>&1 && settings_parser=jq || settings_invalid=1
    else resolve_pybin; if [ -n "$_pybin" ]; then printf '%s' "$settings_text" | "$_pybin" -c 'import json,sys; json.load(sys.stdin,parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))' >/dev/null 2>&1 && settings_parser=python || settings_invalid=1; else settings_unknown=1; fi
    fi
  fi
  if [ "$settings_invalid" -eq 0 ] && [ "$settings_unknown" -eq 0 ]; then
    if [ "$settings_parser" = jq ]; then
      commands=$(printf '%s' "$settings_text" | jq -r '.. | objects | .command? // empty | select(type == "string")' 2>/dev/null) || settings_read_failed=1
    elif [ "$settings_parser" = python ]; then
      commands=$(printf '%s' "$settings_text" | "$_pybin" -c '
import json,sys
def walk(v):
    if isinstance(v,dict):
        for k,x in v.items():
            if k == "command" and isinstance(x,str): print(x)
            else: walk(x)
    elif isinstance(v,list):
        for x in v: walk(x)
walk(json.load(sys.stdin,parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value))))
' 2>/dev/null) || settings_read_failed=1
    fi
  fi
fi
shells=$(printf '%s\n' "$commands" | sed -n 's/^[[:space:]]*"\([^"]*\)".*/\1/p; t; s/^[[:space:]]*\([^[:space:]]*\)[[:space:]].*/\1/p' | unique_lines)
bash_guard_registered=0
while IFS= read -r command; do
  [ -z "$command" ] && continue
  if is_claude_bash_guard_command "$command"; then bash_guard_registered=1; fi
done <<EOF
$commands
EOF
if [ "$settings_read_failed" -eq 1 ]; then
  row CANT-VERIFY 'Wired hook shell' '.claude/settings.json exists but could not be read; the wired interpreter is unknown. Fix read access and rerun the doctor.'
elif [ "$settings_unknown" -eq 1 ]; then
  row CANT-VERIFY 'Wired hook shell' '.claude/settings.json exists, but JSON validity and the wired interpreter cannot be checked without jq or a working python interpreter. Install one and rerun the doctor.'
elif [ -z "$shells" ]; then
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
last_session_start=''
if [ -r "$liveness" ] && last_session_start=$(<"$liveness"); then
  last_session_start=$(printf '%s' "$last_session_start" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
fi
if [ -n "$last_session_start" ]; then
  row OK 'Hook liveness' "hooks have demonstrably run in this repo, most recently at '$last_session_start'."
else
  row CANT-VERIFY 'Hook liveness' 'no hook has recorded a run here; if you have already started a Claude Code session in this repo, your hooks are not firing -- check the wired interpreter above, and see docs/enforcement-surfaces.md.'
fi

copilot_json="$root/.github/hooks/hooks.json"
copilot_exists=0
copilot_read_failed=0
copilot_text=''
if [ -f "$copilot_json" ]; then copilot_exists=1; copilot_text=$(<"$copilot_json") || copilot_read_failed=1; fi
copilot_valid=0
copilot_invalid=0
copilot_unknown=0
if [ "$copilot_exists" -eq 1 ]; then
  if [ "$copilot_read_failed" -eq 1 ]; then :
  elif has_working_jq; then
    if strict_json_jq_lexemes "$copilot_text" && printf '%s' "$copilot_text" | jq empty >/dev/null 2>&1; then copilot_valid=1; else copilot_invalid=1; fi
  else
    resolve_pybin
    if [ -n "$_pybin" ]; then
      if printf '%s' "$copilot_text" | "$_pybin" -c 'import json,sys; json.load(sys.stdin,parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))' >/dev/null 2>&1; then copilot_valid=1; else copilot_invalid=1; fi
    else
      copilot_unknown=1
    fi
  fi
fi
copilot_hook_commands=''
copilot_bash_commands=''
if [ "$copilot_valid" -eq 1 ]; then
  copilot_hook_commands=$(printf '%s' "$copilot_text" | grep -oE '"(bash|powershell)"[[:space:]]*:[[:space:]]*"[^"]*"' 2>/dev/null | sed -n 's/^"[^"]*"[[:space:]]*:[[:space:]]*"\([^"]*\)"$/\1/p')
  copilot_bash_commands=$(printf '%s' "$copilot_text" | grep -oE '"bash"[[:space:]]*:[[:space:]]*"[^"]*"' 2>/dev/null | sed -n 's/^"bash"[[:space:]]*:[[:space:]]*"\([^"]*\)"$/\1/p')
fi
paths=$( { printf '%s\n' "$commands" | grep -oE '[^ ]*\.claude[\\/]hooks[\\/][^ ]+'; printf '%s\n' "$copilot_hook_commands" | sed 's/[[:space:]].*$//'; } | sed -e 's#\\\\#/#g' -e 's#\\#/#g' -e 's#^"##' -e 's#"$##' -e "s#^'##" -e "s#'\$##" -e 's#^\./##' | unique_lines)
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
if [ "$copilot_invalid" -eq 1 ]; then
  row MISSING 'Hook files' '.github/hooks/hooks.json is malformed, so its apparent registrations are not active. Fix: re-run the installer or correct the file.'
elif [ -n "$missing_paths" ]; then
  row MISSING 'Hook files' "registration points at a missing file; hooks are silently dead. Fix: re-run the installer. Missing: ${missing_paths:-<no registrations>}"
elif [ "$settings_read_failed" -eq 1 ] || [ "$settings_unknown" -eq 1 ] || [ "$copilot_read_failed" -eq 1 ] || [ "$copilot_unknown" -eq 1 ]; then
  row CANT-VERIFY 'Hook files' 'hook registrations could not be completely read from .claude/settings.json and .github/hooks/hooks.json; file presence cannot be certified. Fix read access and rerun the doctor.'
elif [ "$count" -eq 0 ]; then
  row MISSING 'Hook files' 'registration points at a missing file; hooks are silently dead. Fix: re-run the installer. Missing: <no registrations>'
else row OK 'Hook files' "$count registered files are present."
fi

if [ "$copilot_invalid" -eq 1 ]; then
  row MISSING 'Guard JSON parser' '.github/hooks/hooks.json is malformed, so no parser requirement can be inferred from its apparent commands. Fix: re-run the installer or correct the file.'
elif [ "$settings_read_failed" -eq 1 ] || [ "$settings_unknown" -eq 1 ] || [ "$copilot_read_failed" -eq 1 ] || [ "$copilot_unknown" -eq 1 ]; then
  row CANT-VERIFY 'Guard JSON parser' 'hook registrations could not be completely read, so whether a Bash guard parser is required cannot be verified. Fix read access and rerun the doctor.'
elif [ "$bash_guard_registered" -eq 1 ]; then
  if has_working_jq; then row OK 'Guard JSON parser' 'jq or a working python interpreter is available in this Bash environment.'
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
  needs_dotnet=0; needs_angular=0
  # Application manifests live at the root or within two project-container levels in the
  # supported layouts. Keep this bounded and do not mistake generated/dependency artifacts for
  # source applications; an incomplete walk is not evidence that no application exists.
  marker_scan_depth=2
  marker_scan_failed=0
  marker_dirs=("$root")
  marker_nocaseglob_was_set=0
  marker_dotglob_was_set=0
  marker_nocasematch_was_set=0
  shopt -q nocaseglob && marker_nocaseglob_was_set=1
  shopt -q dotglob && marker_dotglob_was_set=1
  shopt -q nocasematch && marker_nocasematch_was_set=1
  shopt -s nocaseglob
  shopt -s dotglob
  shopt -s nocasematch
  for depth in 0 1 2; do
    next_marker_dirs=()
    for marker_dir in "${marker_dirs[@]}"; do
      if [ ! -r "$marker_dir" ] || [ ! -x "$marker_dir" ]; then marker_scan_failed=1; continue; fi
      # A solution alone can contain only SSDT/sqlproj projects. Require an actual C# project
      # before treating this repository as a .NET application.
      for marker in "$marker_dir"/*.csproj; do
        if [ -L "$marker" ]; then marker_scan_failed=1; continue; fi
        if [ -e "$marker" ]; then
          if [ -f "$marker" ]; then needs_dotnet=1; else marker_scan_failed=1; fi
        elif [ -L "$marker" ]; then marker_scan_failed=1; fi
      done
      for marker in "$marker_dir"/angular.json "$marker_dir"/package.json "$marker_dir"/nx.json "$marker_dir"/project.json; do
        if [ -L "$marker" ]; then marker_scan_failed=1; continue; fi
        if [ ! -e "$marker" ]; then [ -L "$marker" ] && marker_scan_failed=1; continue; fi
        if [ ! -f "$marker" ]; then marker_scan_failed=1; continue; fi
        marker_name=${marker##*/}
        case "$marker_name" in
          angular.json)
            if [ ! -r "$marker" ]; then marker_scan_failed=1; continue; fi
            angular_json_evidence workspace "$marker"; marker_status=$?
            if [ "$marker_status" -eq 0 ]; then needs_angular=1; else marker_scan_failed=1; fi;;
          package.json)
            if [ ! -r "$marker" ]; then marker_scan_failed=1; continue; fi
            angular_json_evidence package "$marker"; marker_status=$?
            if [ "$marker_status" -eq 0 ]; then needs_angular=1; elif [ "$marker_status" -ne 1 ]; then marker_scan_failed=1; fi;;
          nx.json|project.json)
            if [ ! -r "$marker" ]; then marker_scan_failed=1; continue; fi
            angular_json_evidence nx "$marker"; marker_status=$?
            if [ "$marker_status" -eq 0 ]; then needs_angular=1; elif [ "$marker_status" -ne 1 ]; then marker_scan_failed=1; fi;;
        esac
      done
      if [ "$depth" -lt "$marker_scan_depth" ]; then
        for child in "$marker_dir"/*; do
          [ -d "$child" ] || continue
          child_name=${child##*/}
          case "$child_name" in .git|node_modules|bower_components|vendor|bin|obj|dist|build|out|.next|.angular|.nx|coverage) continue;; esac
          if [ -L "$child" ]; then marker_scan_failed=1; continue; fi
          next_marker_dirs+=("$child")
        done
      fi
    done
    marker_dirs=("${next_marker_dirs[@]}")
  done
  [ "$marker_nocaseglob_was_set" -eq 1 ] || shopt -u nocaseglob
  [ "$marker_dotglob_was_set" -eq 1 ] || shopt -u dotglob
  [ "$marker_nocasematch_was_set" -eq 1 ] || shopt -u nocasematch
  [ "$needs_dotnet" -eq 0 ] || has dotnet || missing_tools=dotnet
  if [ "$needs_angular" -eq 1 ]; then has node || missing_tools="${missing_tools}${missing_tools:+,}node"; has npx || missing_tools="${missing_tools}${missing_tools:+,}npx"; fi
  if [ "$marker_scan_failed" -eq 1 ]; then
    row CANT-VERIFY 'Stack toolchain' 'repository application markers could not be completely enumerated or read within two directory levels; generated/dependency directories (.git, node_modules, bower_components, vendor, bin, obj, dist, build, out, .next, .angular, .nx, coverage) are intentionally excluded. No toolchain conclusion was inferred. Fix: restore read/list access and rerun framework doctor.'
    stack_canary='repository application markers could not be completely enumerated or read, so whether a compile/type-error canary applies cannot be verified. Fix the marker access issue, then use the actual agent rather than a direct terminal build.'
  elif [ -n "$missing_tools" ]; then row MISSING 'Stack toolchain' "the required toolchain commands are absent from this doctor process environment: $missing_tools; this does not prove the agent host's post-write environment. Fix: install them on this machine if the actual-host canary also fails."
  elif [ "$needs_dotnet" -eq 0 ] && [ "$needs_angular" -eq 0 ]; then row OK 'Stack toolchain' "not applicable: no repository-evidenced .NET or Angular application markers were found; no command was inferred from template '$template'."
    stack_canary='not applicable: no repository-evidenced .NET or Angular application markers were found, so this repository has no compile/type-error canary to run.'
  else
    if [ "$needs_dotnet" -eq 1 ] && [ "$needs_angular" -eq 1 ]; then toolchain_label='.NET and Angular'; elif [ "$needs_dotnet" -eq 1 ]; then toolchain_label='.NET'; else toolchain_label='Angular'; fi
    row OK 'Stack toolchain' "required repository-evidenced $toolchain_label toolchain commands are available in this doctor process environment; this does not prove the agent host's post-write environment."
    if [ "$needs_dotnet" -eq 1 ] && [ "$needs_angular" -eq 1 ]; then stack_canary='through the actual agent, make and then revert a harmless deliberate compile/type error in one selected real build-relevant .NET or Angular file after the post-write throttle has elapsed; pass = the hook output starts with "## dotnet build failed" or "## tsc --noEmit failed". Model diagnosis or a direct terminal build is not a pass.'
    elif [ "$needs_dotnet" -eq 1 ]; then stack_canary='through the actual agent, make and then revert a harmless deliberate compile/type error in a selected real build-relevant .NET file after the post-write throttle has elapsed; pass = the hook output starts with "## dotnet build failed". Model diagnosis or a direct terminal build is not a pass.'
    else stack_canary='through the actual agent, make and then revert a harmless deliberate type error in a selected real build-relevant Angular file after the post-write throttle has elapsed; pass = the hook output starts with "## tsc --noEmit failed". Model diagnosis or a direct terminal build is not a pass.'; fi
  fi
fi

# Twin divergence by design: only this twin can hit the CANT-VERIFY branch below — the .ps1 twin
# always has a JSON parser (PowerShell native), so it reports valid/invalid directly.
if [ "$copilot_valid" -eq 1 ]; then
  if has copilot; then row OK 'Copilot surface' 'hooks.json is valid and Copilot CLI is available in this doctor process environment.'
  else row OK 'Copilot surface' 'hooks.json is valid; Copilot CLI is absent from this doctor process environment. Claude-only teams need no action; Copilot teams must use the actual-surface canaries below.'; fi
elif [ "$copilot_read_failed" -eq 1 ]; then row CANT-VERIFY 'Copilot surface' '.github/hooks/hooks.json exists but could not be read; its validity and Copilot hook surface are unknown. Fix read access and rerun the doctor.'
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
    row CANT-VERIFY 'Mirror and version integrity' 'could not execute template-checks, so drift is UNKNOWN rather than found. This is a host problem, not a documentation problem. Fix: run scripts/template-checks.sh yourself and act on what it says.'
  else row MISSING 'Mirror and version integrity' 'CLAUDE.md and AGENTS.md or version stamps have drifted. Fix: run /generate-copilot, then scripts/docs-sync-check.sh.'
  fi
fi

audit="$root/.claude/ai-audit.log"
if [ "$pending" -eq 1 ]; then row PENDING 'Audit trail substrate' 'not checked until /bootstrap or /adopt completes.'
elif [ ! -f "$audit" ]; then row MISSING 'Audit trail substrate' '.claude/ai-audit.log is missing, so local hook telemetry cannot be appended. Fix: create the file and ensure developers can append to it.'
elif [ -w "$audit" ]; then row OK 'Audit trail substrate' 'audit log exists and is appendable.'
else row MISSING 'Audit trail substrate' 'audit log is not appendable. Fix: grant the developer write access to .claude/ai-audit.log.'
fi
finish
