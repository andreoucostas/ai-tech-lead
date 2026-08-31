#!/usr/bin/env bash
# AI Tech Lead Framework — root installer wrapper.
# Usage: bash install.sh [--stack dotnet|angular|monorepo] [--git-hooks] [--dry-run] [--allow-downgrade] /path/to/target-repo
#
# Thin dispatcher only: it selects a stack, then delegates to
# dist/<stack>/scripts/install.sh, which does all the real work (greenfield / brownfield /
# update detection, the copy, the pwsh->bash hook rewiring, ...). This wrapper adds NO install
# logic of its own — stack selection and delegation, nothing more.
#
# Stack resolution (first match wins):
#   1. --stack flag       explicit; always wins.
#   2. update stamp       target/.claude/framework-version.json exists -> use its "template".
#   3. auto-detect        *.csproj -> dotnet ; evidenced Angular config/package -> angular ;
#                         both, or Angular + warehouse SQL -> monorepo.
#                         Searched in the target root plus two directory levels below it.
#   4. warehouse-only     two or more independent warehouse signal categories -> dotnet
#                         delivery profile; /bootstrap selects warehouse-SQL from repo evidence.
#   5. nothing detected   error: pass --stack.
# Every error exits 2 with an actionable message.
set -euo pipefail

usage="Usage: bash install.sh [--stack dotnet|angular|monorepo] [--git-hooks] [--dry-run] [--allow-downgrade] /path/to/target-repo"
self_dir="$(cd "$(dirname "$0")" && pwd)"
find_cmd="find"
# Git Bash can inherit Windows' find.exe ahead of GNU find on PATH. Prefer the POSIX binary
# when available; /usr/bin/find is also the standard location on the supported Unix hosts.
[ -x /usr/bin/find ] && find_cmd="/usr/bin/find"

stack=""
git_hooks=0
dry_run=0
allow_downgrade=0
target=""
while [ $# -gt 0 ]; do
  case "$1" in
    --stack)   stack="${2:-}"; shift 2 ;;
    --stack=*) stack="${1#--stack=}"; shift ;;
    --git-hooks) git_hooks=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    --allow-downgrade) allow_downgrade=1; shift ;;
    -h|--help) echo "$usage"; exit 0 ;;
    -*)        echo "Unknown option: $1" >&2; echo "$usage" >&2; exit 2 ;;
    *)         if [ -z "$target" ]; then target="$1"; shift
               else echo "Unexpected extra argument: $1" >&2; echo "$usage" >&2; exit 2; fi ;;
  esac
done

if [ -z "$target" ]; then echo "$usage" >&2; exit 2; fi
[ -d "$target" ] || { echo "Target '$target' is not a directory." >&2; exit 2; }
tgt="$(cd "$target" && pwd)"

valid_stack() { [ "$1" = "dotnet" ] || [ "$1" = "angular" ] || [ "$1" = "monorepo" ]; }
# jq accepts non-RFC numeric spellings such as NaN, Infinity, and leading-zero integers. Its parser
# handles the rest of the grammar; this lexical preflight closes only those known extensions while
# respecting quoted strings, so the preferred jq path matches strict PowerShell/Python decisions.
strict_json_jq_lexemes() {
  local text="$1" i=0 length=${#1} quoted=0 escaped=0 c j token scan
  while [ "$i" -lt "$length" ]; do
    c=${text:$i:1}
    if [ "$quoted" -eq 1 ]; then
      if [ "$escaped" -eq 1 ]; then escaped=0
      elif [ "$c" = '\' ]; then escaped=1
      elif [ "$c" = '"' ]; then quoted=0
      fi
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
read_stamp_template() {
  local stamp_path="$1" parsed cand probe stamp_text
  stamp_template=""
  if command -v jq >/dev/null 2>&1 && printf '{}' | jq -e . >/dev/null 2>&1; then
    stamp_text=$(<"$stamp_path") || return 1; strict_json_jq_lexemes "$stamp_text" || return 1
    parsed=$(printf '%s' "$stamp_text" | jq -er 'if type == "object" and (.template | type) == "string" and (.template | test("[^[:space:]]")) then .template else empty end' 2>/dev/null) || return 1
    stamp_template="$parsed"
    return 0
  fi
  for cand in python3 python py; do
    if command -v "$cand" >/dev/null 2>&1; then
      probe=$(printf '{}' | "$cand" -c 'import json,sys; json.load(sys.stdin); sys.stdout.write("ok")' 2>/dev/null) || probe=""
      if [ "$probe" = "ok" ]; then
        parsed=$("$cand" -c 'import json,sys; reject=lambda value: (_ for _ in ()).throw(ValueError(value)); d=json.load(open(sys.argv[1], encoding="utf-8-sig"),parse_constant=reject); v=d.get("template") if isinstance(d,dict) else None; isinstance(v,str) and v.strip() or sys.exit(2); sys.stdout.write(v)' "$stamp_path" 2>/dev/null) || return 1
        stamp_template="$parsed"
        return 0
      fi
    fi
  done
  return 2
}
warehouse_signals=()
get_warehouse_signals() {
  local signals category pattern matched f grep_status all_files files
  signals="$self_dir/dist/dotnet/scripts/warehouse-signals.tsv"; [ -r "$signals" ] || return 2; warehouse_signals=()
  all_files=$("$find_cmd" "$tgt" \( -type d \( -iname .git -o -iname node_modules -o -iname bower_components -o -iname vendor -o -iname bin -o -iname obj -o -iname dist -o -iname build -o -iname out -o -iname .next -o -iname .angular -o -iname .nx -o -iname coverage \) -prune \) -o \( -type f \( -iname '*.sql' -o -iname '*.sqlproj' -o -iname 'dbt_project.yml' -o -iname '*.yml' -o -iname '*.yaml' -o -iname '*.json' \) -print \) 2>/dev/null) || return 2
  files=$(printf '%s\n' "$all_files" | grep -Ei '\.sql(proj)?$|/dbt_project\.yml$|/(etl|pipelines?|warehouse|datafactory|synapse|dags?)/|/(pipeline|datafactory|synapse|dag)[^/]*\.(yml|yaml|json)$') || { grep_status=$?; [ "$grep_status" -eq 1 ] || return 2; files=''; }
  while IFS=$'\t' read -r category pattern; do case "$category" in ''|'#'*) continue;; esac; matched=0; while IFS= read -r f; do [ -n "$f" ]||continue; if grep -Eiq "$pattern" <<<"$(basename "$f")"; then matched=1;break; elif grep -Eiq "$pattern" "$f" 2>/dev/null; then matched=1;break; else grep_status=$?; [ "$grep_status" -eq 1 ] || return 2; fi; done <<EOF
$files
EOF
  [ "$matched" -eq 1 ] && warehouse_signals+=("$category"); done < "$signals"; [ "${#warehouse_signals[@]}" -ge 2 ]
}
angular_json_evidence() {
  local kind="$1" file="$2" parsed cand probe json_text
  if command -v jq >/dev/null 2>&1 && printf '{}' | jq -e . >/dev/null 2>&1; then
    json_text=$(<"$file") || return 2; strict_json_jq_lexemes "$json_text" || return 2
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
  for cand in python3 python py; do
    if command -v "$cand" >/dev/null 2>&1; then
      probe=$(printf '{}' | "$cand" -c 'import json,sys; json.load(sys.stdin); sys.stdout.write("ok")' 2>/dev/null) || probe=""
      if [ "$probe" = ok ]; then
        "$cand" -c 'import json,re,sys
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
sys.exit(0 if found else 1)' "$kind" "$file" 2>/dev/null
        return $?
      fi
    fi
  done
  return 2
}
has_angular_evidence() {
  local marker base base_lc evidence_status markers
  markers=$("$find_cmd" "$tgt" -maxdepth 3 \( -type d \( -iname .git -o -iname node_modules -o -iname bower_components -o -iname vendor -o -iname bin -o -iname obj -o -iname dist -o -iname build -o -iname out -o -iname .next -o -iname .angular -o -iname .nx -o -iname coverage \) -prune \) -o \( -type f \( -iname 'angular.json' -o -iname 'package.json' -o -iname 'nx.json' -o -iname 'project.json' \) -print \) 2>/dev/null) || return 2
  while IFS= read -r marker; do
    [ -n "$marker" ] || continue
    base=${marker##*/}
    base_lc=$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')
    case "$base_lc" in
      angular.json) angular_json_evidence workspace "$marker" && return 0; evidence_status=$?; [ "$evidence_status" -eq 1 ] || return 2;;
      package.json) angular_json_evidence package "$marker" && return 0; evidence_status=$?; [ "$evidence_status" -eq 1 ] || return 2;;
      nx.json|project.json) angular_json_evidence nx "$marker" && return 0; evidence_status=$?; [ "$evidence_status" -eq 1 ] || return 2;;
    esac
  done <<EOF
$markers
EOF
  return 1
}
reason=""
if [ -n "$stack" ]; then
  valid_stack "$stack" || { echo "Unknown stack '$stack' (expected: dotnet, angular, or monorepo)." >&2; exit 2; }
  reason="--stack flag"
else
  vf="$tgt/.claude/framework-version.json"
  if [ -f "$vf" ]; then
    # Existing install: honour the stack it was installed with (update mode). The stamp's
    # "template" value already matches the dist mode names (dotnet / angular / monorepo).
    if read_stamp_template "$vf"; then tmpl="$stamp_template"; else
      stamp_status=$?
      if [ "$stamp_status" -eq 2 ]; then
        echo "Existing install at '$tgt', but .claude/framework-version.json cannot be verified without jq or a working Python interpreter — install one or pass --stack dotnet|angular|monorepo explicitly." >&2; exit 2
      fi
      echo "Existing install at '$tgt', but .claude/framework-version.json is invalid JSON or has no non-empty string \"template\" value — pass --stack dotnet|angular|monorepo." >&2; exit 2
    fi
    valid_stack "$tmpl" || { echo "Existing install names an unknown stack \"$tmpl\" in .claude/framework-version.json — pass --stack dotnet|angular|monorepo." >&2; exit 2; }
    stack="$tmpl"
    reason="update stamp (.claude/framework-version.json template=$tmpl)"
  else
    # Auto-detect from build markers in the target root + two levels below (maxdepth 3:
    # depth 1 = root files, depth 3 = two subdirectory levels down).
    has_dotnet=0; has_angular=0
    # A solution alone can be an SSDT/SQL-only container. A C# project is the bounded
    # application marker; solution files become locators only after that evidence exists.
    application_markers=$("$find_cmd" "$tgt" -maxdepth 3 \( -type d \( -iname .git -o -iname node_modules -o -iname bower_components -o -iname vendor -o -iname bin -o -iname obj -o -iname dist -o -iname build -o -iname out -o -iname .next -o -iname .angular -o -iname .nx -o -iname coverage \) -prune \) -o \( -type f -iname '*.csproj' -print -quit \) 2>/dev/null) || { echo "Could not inspect repository evidence under '$tgt'. Fix read/list access and retry, or pass --stack dotnet|angular|monorepo explicitly." >&2; exit 2; }
    if [ -n "$application_markers" ]; then has_dotnet=1; fi
    if has_angular_evidence; then has_angular=1; else evidence_status=$?; [ "$evidence_status" -eq 1 ] || { echo "Could not inspect repository evidence under '$tgt'. Fix read/list access and retry, or pass --stack dotnet|angular|monorepo explicitly." >&2; exit 2; }; fi
    warehouse_detected=0; observed=''
    if [ "$has_dotnet" -eq 0 ]; then
      if get_warehouse_signals; then
        warehouse_detected=1; observed="${warehouse_signals[0]}"
        for category in "${warehouse_signals[@]:1}"; do observed+=", $category"; done
      else
        evidence_status=$?
        [ "$evidence_status" -eq 1 ] || { echo "Could not inspect repository evidence under '$tgt'. Fix read/list access and retry, or pass --stack dotnet|angular|monorepo explicitly." >&2; exit 2; }
      fi
    fi
    if [ "$has_dotnet" -eq 1 ] && [ "$has_angular" -eq 1 ]; then
      stack="monorepo"; reason="auto-detected (found both *.csproj and Angular repository evidence — mixed repo)"
    elif [ "$has_dotnet" -eq 1 ]; then stack="dotnet";  reason="auto-detected (found *.csproj)"
    elif [ "$has_angular" -eq 1 ] && [ "$warehouse_detected" -eq 1 ]; then stack="monorepo"; reason="auto-detected mixed repo (found Angular + warehouse SQL profiles: $observed)"
    elif [ "$has_angular" -eq 1 ]; then stack="angular"; reason="auto-detected (found Angular repository evidence)"
    elif [ "$warehouse_detected" -eq 1 ]; then
      stack="dotnet"; reason="auto-detected warehouse SQL profile (found signals: $observed)"
    else
      echo "Could not determine the stack for '$tgt': no *.csproj and no Angular repository evidence in the target root or two levels below." >&2
      echo "Pass it explicitly: --stack dotnet|angular|monorepo." >&2
      exit 2
    fi
  fi
fi

delegate="$self_dir/dist/$stack/scripts/install.sh"
[ -f "$delegate" ] || { echo "Internal error: expected installer not found at $delegate" >&2; exit 2; }

echo "Stack: $stack (via $reason)"
echo "Delegating to dist/$stack/scripts/install.sh ..."
echo
delegate_args=()
[ "$git_hooks" -eq 1 ] && delegate_args+=(--git-hooks)
[ "$dry_run" -eq 1 ] && delegate_args+=(--dry-run)
[ "$allow_downgrade" -eq 1 ] && delegate_args+=(--allow-downgrade)
exec bash "$delegate" "${delegate_args[@]}" "$tgt"
