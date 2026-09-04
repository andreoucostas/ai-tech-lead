#!/usr/bin/env bash
# Install the AI Tech Lead Framework into a target repository.
# Usage: bash scripts/install.sh [--git-hooks] [--allow-dirty-tree] [--dry-run] [--allow-downgrade] /path/to/target-repo
#
# Copies the template's framework files into the target, EXCLUDING the .git directory, the
# .template-repo marker (which would disable the consumer's CI guardrail), the template repo's own
# meta files (README.md, CHANGELOG.md, .gitignore, .gitattributes), and the installer itself.
#
# Three modes, detected automatically:
#   greenfield — target has no AI tooling: plain copy; next step is /bootstrap.
#   brownfield — target already has AI tooling (CLAUDE.md, .cursorrules, Copilot instructions,
#                ADRs, ...): the originals this copy would overwrite are moved to docs/pre-adoption/
#                first, and .claude/adoption-pending.json is written so every later session (and CI)
#                steers to /adopt. Next step is /adopt.
#   update     — target already carries .claude/framework-version.json. Consumer-owned protected
#                paths are restored; framework-owned machinery is overwritten; mixed-ownership
#                .claude/settings.json is backed up, refreshed, and adapted to the host.
set -euo pipefail

git_hooks=0
allow_dirty_tree=0
dry_run=0
allow_downgrade=0
target=""
usage="Usage: bash scripts/install.sh [--git-hooks] [--allow-dirty-tree] [--dry-run] [--allow-downgrade] /path/to/target-repo"
while [ $# -gt 0 ]; do
  case "$1" in
    --git-hooks) git_hooks=1;;
    --allow-dirty-tree) allow_dirty_tree=1;;
    --dry-run) dry_run=1;;
    --allow-downgrade) allow_downgrade=1;;
    -*) echo "Unknown option: $1" >&2; echo "$usage" >&2; exit 2;;
    *) if [ -z "$target" ]; then target="$1"; else echo "Unexpected extra argument: $1" >&2; echo "$usage" >&2; exit 2; fi;;
  esac
  shift
done
if [ -z "$target" ]; then echo "$usage"; exit 2; fi
[ -d "$target" ] || { echo "Target '$target' is not a directory."; exit 2; }

src="$(cd "$(dirname "$0")/.." && pwd)"
tgt="$(cd "$target" && pwd)"
if [ "$tgt" = "$src" ]; then echo "Target is the template repo itself — choose a different target."; exit 2; fi
tgt_physical="$(cd "$target" && pwd -P)" || { echo "ERROR: Could not resolve the selected target physically." >&2; exit 3; }

temp_files=()
temp_file_count=0
new_temp=""
new_temp_index=-1
sort_cmd=sort
[ -x /usr/bin/sort ] && sort_cmd=/usr/bin/sort
find_cmd=find
[ -x /usr/bin/find ] && find_cmd=/usr/bin/find

temp_parent_is_inside_target() {
  local probe="$1" parent
  while :; do
    [ "$probe" -ef "$tgt_physical" ] && return 0
    [ "$probe" = / ] && return 1
    parent="${probe%/*}"; [ -n "$parent" ] || parent=/
    [ "$parent" != "$probe" ] || return 1
    probe="$parent"
  done
}

new_temp_file() {
  local candidate parent leaf physical_parent physical_file
  new_temp=""
  new_temp_index=-1
  if ! candidate=$(mktemp); then
    echo "ERROR: Could not allocate an installer temporary file. Check TMPDIR and available disk space." >&2
    return 1
  fi
  if [ -z "$candidate" ]; then
    echo "ERROR: The temporary-file provider returned an empty path." >&2
    return 1
  fi

  new_temp_index=$temp_file_count
  temp_files[$new_temp_index]="$candidate"
  temp_file_count=$((temp_file_count + 1))
  case "$candidate" in
    */*) parent="${candidate%/*}"; [ -n "$parent" ] || parent=/; leaf="${candidate##*/}";;
    *) parent=.; leaf="$candidate";;
  esac
  if [ -z "$leaf" ] || ! physical_parent=$(cd -- "$parent" 2>/dev/null && pwd -P); then
    echo "ERROR: Could not resolve the installer temporary file's physical parent." >&2
    return 1
  fi
  case "$physical_parent" in /) physical_file="/$leaf";; *) physical_file="$physical_parent/$leaf";; esac
  if [ ! "$physical_file" -ef "$candidate" ]; then
    echo "ERROR: Could not verify the installer temporary file's physical identity." >&2
    return 1
  fi
  temp_files[$new_temp_index]="$physical_file"
  new_temp="$physical_file"
  if temp_parent_is_inside_target "$physical_parent"; then
    echo "ERROR: Refusing temporary-file placement inside the selected target. Set TMPDIR outside the target, then re-run." >&2
    return 1
  fi
}

release_temp_file() {
  local index="$1"
  case "$index" in ''|*[!0-9]*) echo "ERROR: Invalid installer temporary-file registry index '$index'." >&2; return 1;; esac
  if [ "$index" -ge "$temp_file_count" ] || [ -z "${temp_files[$index]}" ]; then
    echo "ERROR: Installer temporary-file registry index '$index' is not owned." >&2
    return 1
  fi
  temp_files[$index]=""
}

cleanup_temp_files() {
  local body_status="$?" cleanup_failed=0 temp_index=0 temp_file
  trap - EXIT
  while [ "$temp_index" -lt "$temp_file_count" ]; do
    temp_file="${temp_files[$temp_index]}"
    if [ -n "$temp_file" ] && ! rm -f -- "$temp_file"; then
      cleanup_failed=1
      printf "ERROR: Could not remove installer temporary file '%s'.\n" "$temp_file" >&2 || :
    fi
    temp_index=$((temp_index + 1))
  done
  if [ "$cleanup_failed" -ne 0 ]; then
    if [ "$body_status" -eq 0 ]; then
      printf '%s\n' 'ERROR: Installer target work completed, but temporary-file cleanup failed; target changes were not rolled back.' >&2 || :
      exit 3
    fi
    printf "ERROR: Installer failed with exit %s and temporary-file cleanup also failed; preserving the original exit status.\n" "$body_status" >&2 || :
  fi
  exit "$body_status"
}
trap cleanup_temp_files EXIT

valid_repo_path() {
  local path="$1" segment
  [ -n "$path" ] || return 1
  case "$path" in /*|\\*|//*|[A-Za-z]:*|*\\*) return 1;; esac
  IFS='/' read -r -a path_segments <<< "$path"
  for segment in "${path_segments[@]}"; do [ -n "$segment" ] && [ "$segment" != . ] && [ "$segment" != .. ] || return 1; done
}

validate_ownership_manifest() {
  local file="$1" label="$2" output="$3" stripped parsed expected path ownership folded duplicate
  [ -f "$file" ] || { echo "missing $label" >&2; return 1; }
  [ "$(grep -Ec '^[[:space:]]*"schema-version"[[:space:]]*:[[:space:]]*1,?[[:space:]]*$' "$file")" -eq 1 ] || { echo "$label has an unsupported or missing schema" >&2; return 1; }
  new_temp_file || return 2; stripped=$new_temp; tr -d '\000' < "$file" > "$stripped"; cmp -s "$file" "$stripped" || { echo "$label contains NUL bytes" >&2; return 1; }
  new_temp_file || return 2; parsed=$new_temp
  sed -n 's/^[[:space:]]*{ "path": "\([^"]*\)", "ownership": "\([^"]*\)" }[,]\{0,1\}[[:space:]]*$/\1\	\2/p' "$file" > "$parsed"
  expected=$(grep -c '"path"' "$file" || true)
  [ "$expected" -gt 0 ] && [ "$expected" -eq "$(wc -l < "$parsed" | tr -d ' ')" ] || { echo "$label contains malformed path entries" >&2; return 1; }
  if ! LC_ALL=C awk -F $'\t' 'BEGIN { OFS = FS } { folded = tolower($1); print folded, (seen[folded]++ ? 1 : 0), $0 }' "$parsed" > "$stripped"; then
    echo "$label could not be case-folded for duplicate validation" >&2
    return 1
  fi
  : > "$output"
  while IFS=$'\t' read -r folded duplicate path ownership; do
    valid_repo_path "$path" || { echo "$label contains unsafe or non-normalized path '$path'" >&2; return 1; }
    case "$ownership" in framework-owned/overwritten|consumer-owned/protected|mixed) ;; *) echo "$label has unsupported ownership '$ownership' for '$path'" >&2; return 1;; esac
    [ "$duplicate" -eq 0 ] || { echo "$label contains duplicate path '$path'" >&2; return 1; }
    printf '%s\t%s\t%s\n' "$folded" "$path" "$ownership" >> "$output"
  done < "$stripped"
}

validate_retirement_ledger() {
  local file="$1" label="$2" output="$3" stripped parsed expected path version hashes hash folded previous_hash duplicate
  [ -f "$file" ] || { echo "missing $label" >&2; return 1; }
  [ "$(grep -Ec '^[[:space:]]*"schema-version"[[:space:]]*:[[:space:]]*1,?[[:space:]]*$' "$file")" -eq 1 ] || { echo "$label has an unsupported or missing schema" >&2; return 1; }
  new_temp_file || return 2; stripped=$new_temp; tr -d '\000' < "$file" > "$stripped"; cmp -s "$file" "$stripped" || { echo "$label contains NUL bytes" >&2; return 1; }
  new_temp_file || return 2; parsed=$new_temp
  sed -n 's/^[[:space:]]*{ "path": "\([^"]*\)", "retired-in": "\([^"]*\)", "known-content-sha256": \[\(.*\)\] }[,]\{0,1\}[[:space:]]*$/\1\	\2\	\3/p' "$file" > "$parsed"
  expected=$(grep -c '"retired-in"' "$file" || true)
  [ "$expected" -eq "$(wc -l < "$parsed" | tr -d ' ')" ] || { echo "$label contains a malformed retirement entry" >&2; return 1; }
  if ! LC_ALL=C awk -F $'\t' 'BEGIN { OFS = FS } { folded = tolower($1); print folded, (seen[folded]++ ? 1 : 0), $0 }' "$parsed" > "$stripped"; then
    echo "$label could not be case-folded for duplicate validation" >&2
    return 1
  fi
  : > "$output"
  while IFS=$'\t' read -r folded duplicate path version hashes; do
    valid_repo_path "$path" || { echo "$label contains unsafe or non-normalized path '$path'" >&2; return 1; }
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "$label has invalid retired-in version '$version' for '$path'" >&2; return 1; }
    [ "$duplicate" -eq 0 ] || { echo "$label contains duplicate path '$path'" >&2; return 1; }
    hashes=$(printf '%s' "$hashes" | sed 's/",[[:space:]]*"/ /g; s/"//g')
    [ -n "$hashes" ] || { echo "$label has no known-content-sha256 values for '$path'" >&2; return 1; }
    previous_hash=""
    for hash in $hashes; do
      [[ "$hash" =~ ^[0-9a-f]{64}$ ]] || { echo "$label has invalid SHA-256 '$hash' for '$path'" >&2; return 1; }
      if [ -n "$previous_hash" ] && [[ ! "$previous_hash" < "$hash" ]]; then echo "$label hashes are not unique ordinal values for '$path'" >&2; return 1; fi
      printf '%s\t%s\t%s\t%s\n' "$folded" "$path" "$version" "$hash" >> "$output"
      previous_hash="$hash"
    done
  done < "$stripped"
}

version_is_greater() {
  local left="$1" right="$2" i a b
  [[ "$left" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ "$right" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 2
  IFS=. read -r -a left_parts <<< "$left"; IFS=. read -r -a right_parts <<< "$right"
  for i in 0 1 2; do
    a=$(printf '%s' "${left_parts[$i]}" | sed 's/^0*//'); b=$(printf '%s' "${right_parts[$i]}" | sed 's/^0*//'); [ -n "$a" ] || a=0; [ -n "$b" ] || b=0
    [ "${#a}" -gt "${#b}" ] && return 0; [ "${#a}" -lt "${#b}" ] && return 1
    [[ "$a" > "$b" ]] && return 0; [[ "$a" < "$b" ]] && return 1
  done
  return 1
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print tolower($1)}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print tolower($1)}'
  elif command -v openssl >/dev/null 2>&1; then openssl dgst -sha256 "$1" | sed 's/^.*= //' | tr '[:upper:]' '[:lower:]'
  else return 1; fi
}

# A brownfield archive must stay inside the target. Check every existing source/destination
# ancestor: a symlink/junction below the target root otherwise redirects mv outside the repo.
find_reparse_ancestor() {
  probe="$1"
  while :; do
    if [ -L "$probe" ]; then printf '%s' "$probe"; return 0; fi
    [ "$probe" = "$tgt" ] && return 1
    parent="${probe%/*}"; [ -n "$parent" ] || parent=/
    [ "$parent" = "$probe" ] && return 1
    probe="$parent"
  done
}

# Print exists, absent, or cant-verify for one literal path without collapsing an unreadable
# ancestor into absence. The residual-retirement diagnostic is read-only, but Rule 7 still applies:
# a path we could not examine must never be silently treated as a path that is not there.
classify_path_entry() {
  local path="$1" parent name parent_state listing status
  if [ -e "$path" ] || [ -L "$path" ]; then printf '%s' exists; return 0; fi
  # The recursion ends only at a verified filesystem root. Treat an unreadable/unrecognised root
  # as CANT-VERIFY rather than absence; Git-for-Windows may preserve a drive-root spelling here.
  case "$path" in
    /|[A-Za-z]:/)
      if [ -d "$path" ]; then printf '%s' exists; else printf '%s' cant-verify; fi
      return 0
      ;;
  esac
  parent="${path%/*}"; name="${path##*/}"
  case "$parent" in [A-Za-z]:) parent="$parent/";; esac
  if [ -z "$parent" ] || [ "$parent" = "$path" ]; then printf '%s' cant-verify; return 0; fi
  parent_state=$(classify_path_entry "$parent")
  case "$parent_state" in
    absent) printf '%s' absent; return 0;;
    cant-verify) printf '%s' cant-verify; return 0;;
  esac
  if [ -L "$parent" ]; then printf '%s' cant-verify; return 0; fi
  if [ ! -d "$parent" ]; then printf '%s' absent; return 0; fi
  listing=$("$find_cmd" "$parent" -mindepth 1 -maxdepth 1 -name "$name" -print -quit 2>/dev/null); status=$?
  if [ "$status" -ne 0 ]; then printf '%s' cant-verify
  elif [ -n "$listing" ]; then printf '%s' exists
  else printf '%s' absent
  fi
}

assert_target_mutation() {
  local relative="$1" kind="${2:-file}" destination="$tgt/$relative" probe parent physical
  valid_repo_path "$relative" || { echo "ERROR: Refusing install mutation: unsafe or non-normalized path '$relative'." >&2; return 1; }
  if reparse=$(find_reparse_ancestor "$destination"); then
    echo "ERROR: Refusing install mutation '$relative': target path traverses reparse/symlink '$reparse'. Remove the link, then re-run." >&2
    return 1
  fi
  if { [ -e "$destination" ] || [ -L "$destination" ]; } && [ "$kind" = file ] && [ ! -f "$destination" ]; then
    echo "ERROR: Refusing install mutation '$relative': existing target is not a regular file." >&2
    return 1
  fi
  probe="$destination"
  while [ ! -e "$probe" ] && [ ! -L "$probe" ]; do parent="${probe%/*}"; [ "$parent" != "$probe" ] || break; probe="$parent"; done
  if [ "$probe" != "$destination" ] && [ ! -d "$probe" ]; then
    echo "ERROR: Refusing install mutation '$relative': existing parent '$probe' is not a directory." >&2
    return 1
  fi
  if [ -d "$probe" ]; then physical=$(cd "$probe" 2>/dev/null && pwd -P) || return 1
  else physical=$(cd "${probe%/*}" 2>/dev/null && pwd -P) || return 1
  fi
  case "$physical" in "$tgt"|"$tgt"/*) return 0;;
    *) echo "ERROR: Refusing install mutation '$relative': physical parent escapes the target through '$physical'." >&2; return 1;;
  esac
}
git_hook_relative=""
if [ "$git_hooks" -eq 1 ]; then
  bash "$src/scripts/setup-git-hooks.sh" --target "$tgt" --check-only
  git_root=$(git -C "$tgt" rev-parse --show-toplevel 2>/dev/null) || { echo 'ERROR: Git-hook setup target could not be resolved.' >&2; exit 3; }
  git_dir=$(git -C "$tgt" rev-parse --git-dir 2>/dev/null) || { echo 'ERROR: Git-hook directory could not be resolved.' >&2; exit 3; }
  case "$git_dir" in /*) ;; *) git_dir="$git_root/$git_dir";; esac
  git_dir_physical=$(cd "$git_dir" 2>/dev/null && pwd -P) || { echo 'ERROR: Git-hook directory could not be resolved physically.' >&2; exit 3; }
  case "$git_dir_physical/hooks/pre-commit" in "$tgt"/*) git_hook_relative="${git_dir_physical#"$tgt"/}/hooks/pre-commit";;
    *) echo "ERROR: Git-hook setup would write outside the selected target ('$git_dir_physical/hooks/pre-commit'). Linked/external Git directories are not supported by installer planning." >&2; exit 3;;
  esac
fi

# Consumer files the copy below would otherwise clobber. Update skips them directly; brownfield
# archives them unless the copy-if-absent policy below keeps the live path for in-place screening.
protected="CLAUDE.md AGENTS.md TECH_DEBT.md SECURITY_FINDINGS.md LEARNINGS.md FRAMEWORK-CONTEXT.md .github/copilot-instructions.md docs/ARCHITECTURE.md docs/architecture-decisions.md"
# Persistent state is copy-if-absent. The composer verifies this policy against the PowerShell
# twin and records it as consumer-owned/protected in framework-ownership.json.
persistent_copy_if_absent=".claude/ai-audit.log"
# These paths are copied only when absent and so are not brownfield bulk-copy collisions. The
# audit entry remains the separately composer-verified persistent policy above.
copy_if_absent="$persistent_copy_if_absent docs/wiki/INDEX.md docs/ARCHITECTURE.md docs/architecture-decisions.md"

# Signals that the target already has AI tooling and therefore needs /adopt, not /bootstrap
# (mirrors /adopt Phase 1 discovery).
adoption_signals="CLAUDE.md AGENTS.md GEMINI.md .cursorrules .cursor/rules .clinerules .windsurfrules .roomodes .aider.conf.yml .continue .github/copilot-instructions.md .github/instructions .github/chatmodes .github/skills docs/adr docs/decisions ARCHITECTURE.md docs/ARCHITECTURE.md CODEMAP.md CONVENTIONS.md docs/CONVENTIONS.md TECH_DEBT.md TODO.md BACKLOG.md docs/wiki/INDEX.md"

update_mode=0
if [ -f "$tgt/.claude/framework-version.json" ]; then update_mode=1; fi

detected=""
if [ "$update_mode" -eq 0 ]; then
  for s in $adoption_signals; do
    if [ -e "$tgt/$s" ]; then detected="$detected $s"; fi
  done
  detected="${detected# }"
fi

adopt_mode=0
if [ "$update_mode" -eq 0 ] && [ -n "$detected" ]; then adopt_mode=1; fi

# Validate the incoming installed-path inventory and the separate, framework-authored retirement
# authority before planning any target mutation.
incoming_manifest="$src/framework-ownership.json"
new_temp_file || exit 3; incoming_entries=$new_temp
if ! validate_ownership_manifest "$incoming_manifest" 'incoming framework ownership manifest' "$incoming_entries"; then echo 'ERROR: Cannot validate incoming framework ownership manifest.' >&2; exit 3; fi
incoming_paths=$(cut -f2 "$incoming_entries")
while IFS= read -r incoming_path; do [ -f "$src/$incoming_path" ] || { echo "ERROR: Incoming manifest path '$incoming_path' is not a shipped file." >&2; exit 3; }; done <<EOF
$incoming_paths
EOF
new_temp_file || exit 3; retirement_entries=$new_temp
if ! validate_retirement_ledger "$src/framework-retirements.json" 'incoming framework retirement ledger' "$retirement_entries"; then echo 'ERROR: Cannot validate incoming framework retirement ledger.' >&2; exit 3; fi
while IFS=$'\t' read -r _ retired_path _; do
  if awk -F '\t' -v p="$retired_path" '$2 == p { found=1 } END { exit !found }' "$incoming_entries"; then echo "ERROR: Retirement '$retired_path' is still present in the incoming ownership manifest." >&2; exit 3; fi
done < "$retirement_entries"

incoming_version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$src/.claude/framework-version.json" | head -1)
[[ "$incoming_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "ERROR: Incoming framework version must use release SemVer form X.Y.Z (found '$incoming_version')." >&2; exit 3; }
version_comparison=0
installed_version=""
if [ "$update_mode" -eq 1 ]; then
  installed_version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$tgt/.claude/framework-version.json" | head -1)
  [[ "$installed_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "CANT-VERIFY: Installed framework version must use release SemVer form X.Y.Z (found '$installed_version')." >&2; exit 4; }
  if version_is_greater "$installed_version" "$incoming_version"; then version_comparison=1; fi
  if [ "$version_comparison" -eq 1 ] && [ "$allow_downgrade" -ne 1 ]; then
    echo "ERROR: Refusing framework downgrade from $installed_version to $incoming_version before mutation. Re-run with --allow-downgrade only after reviewing the older release." >&2; exit 4
  fi
fi

# These legal files are neither protected nor ordinary framework files. Protection would freeze a
# stale framework-owned notice; bulk copying would silently clobber consumer files. Preflight their
# explicit ownership policy before this installer mutates the target, then copy them after the bulk.
legal_license="LICENSES/ai-tech-lead-MIT.txt"
legal_notice="NOTICE-ai-tech-lead.md"
copy_legal_license=1
if [ -f "$tgt/$legal_license" ]; then
  new_temp_file || exit 3; source_lf=$new_temp
  new_temp_file || exit 3; target_lf=$new_temp
  awk '{ sub(/\015$/, ""); print }' "$src/$legal_license" > "$source_lf"
  awk '{ sub(/\015$/, ""); print }' "$tgt/$legal_license" > "$target_lf"
  if ! cmp -s "$source_lf" "$target_lf"; then
    echo "ERROR: Refusing to overwrite '$legal_license': the existing file is not identical to the framework licence." >&2
    exit 3
  fi
  copy_legal_license=0
fi
if [ -f "$tgt/$legal_notice" ] && ! grep -Fq 'FRAMEWORK-OWNED' "$tgt/$legal_notice"; then
  echo "ERROR: Refusing to overwrite '$legal_notice': the existing file is not marked FRAMEWORK-OWNED." >&2
  exit 3
fi

delete_paths=""
retirement_preserve=""
reconciliation_messages=""
add_reconciliation_message() { reconciliation_messages="${reconciliation_messages}${reconciliation_messages:+
}$1"; }
if [ "$update_mode" -eq 1 ]; then
  previous_manifest="$tgt/framework-ownership.json"
  if [ ! -f "$previous_manifest" ]; then
    add_reconciliation_message 'CANT-VERIFY: previous framework-ownership.json is missing; additive compatibility mode will perform no stale deletion.'
  elif previous_manifest_reparse=$(find_reparse_ancestor "$previous_manifest"); then
    add_reconciliation_message 'CANT-VERIFY: previous framework-ownership.json traverses a reparse/symlink; additive compatibility mode will perform no stale deletion.'
  else
    new_temp_file || exit 3; previous_entries=$new_temp
    new_temp_file || exit 3; previous_errors=$new_temp
    previous_manifest_status=0
    validate_ownership_manifest "$previous_manifest" 'previous framework ownership manifest' "$previous_entries" 2>"$previous_errors" || previous_manifest_status=$?
    if [ "$previous_manifest_status" -eq 1 ]; then
      add_reconciliation_message "CANT-VERIFY: previous framework-ownership.json is malformed or unsafe; additive compatibility mode will perform no stale deletion. $(tr '\n' ' ' < "$previous_errors")"
    elif [ "$previous_manifest_status" -eq 2 ]; then
      cat "$previous_errors" >&2
      echo 'ERROR: Cannot validate previous framework ownership manifest because installer temporary storage is unavailable.' >&2
      exit 3
    elif [ "$previous_manifest_status" -ne 0 ]; then
      cat "$previous_errors" >&2
      echo "ERROR: Previous framework ownership validator returned unexpected status '$previous_manifest_status'." >&2
      exit 3
    else
      while IFS= read -r retired_path; do
        previous_ownership=$(awk -F '\t' -v p="$retired_path" '$2 == p { print $3; exit }' "$previous_entries")
        [ "$previous_ownership" = 'framework-owned/overwritten' ] || continue
        if awk -F '\t' -v p="$retired_path" '$2 == p { found=1 } END { exit !found }' "$incoming_entries"; then continue; fi
        case " $persistent_copy_if_absent " in *" $retired_path "*) continue;; esac
        candidate="$tgt/$retired_path"
        if [ ! -e "$candidate" ] && [ ! -L "$candidate" ]; then continue; fi
        if candidate_reparse=$(find_reparse_ancestor "$candidate"); then
          add_reconciliation_message "CANT-VERIFY: retired path '$retired_path' traverses reparse/symlink '$candidate_reparse'; preserving it."
          retirement_preserve="${retirement_preserve}${retirement_preserve:+
}$retired_path"
          continue
        fi
        if [ ! -f "$candidate" ]; then
          add_reconciliation_message "CANT-VERIFY: retired path '$retired_path' is not a regular file; preserving it."
          retirement_preserve="${retirement_preserve}${retirement_preserve:+
}$retired_path"
          continue
        fi
        if ! digest=$(sha256_file "$candidate"); then
          add_reconciliation_message "CANT-VERIFY: retired path '$retired_path' could not be hashed; preserving it."
          retirement_preserve="${retirement_preserve}${retirement_preserve:+
}$retired_path"
          continue
        fi
        if ! awk -F '\t' -v p="$retired_path" -v h="$digest" '$2 == p && $4 == h { found=1 } END { exit !found }' "$retirement_entries"; then
          add_reconciliation_message "CANT-VERIFY: retired path '$retired_path' has consumer-modified or unknown content; preserving it."
          retirement_preserve="${retirement_preserve}${retirement_preserve:+
}$retired_path"
          continue
        fi
        delete_paths="${delete_paths}${delete_paths:+
}$retired_path"
      done < <(awk -F '\t' '!seen[$2]++ { print $2 }' "$retirement_entries")
    fi
  fi
fi

# A retirement can delete only where the immediately previous manifest grants authority. That
# limitation must not hide a retained high-priority GitHub skill or the old sync script on a later
# update: inspect these exact ledger paths read-only, without granting deletion authority.
if [ "$update_mode" -eq 1 ]; then
  while IFS=$'\t' read -r _ retired_path _ _; do
    case "$retired_path" in
      .github/skills/*) slug_rest="${retired_path#.github/skills/}"; slug="${slug_rest%%/*}"; kind=github-skill;;
      scripts/sync-agent-files.ps1|scripts/sync-agent-files.sh) kind=sync-script;;
      *) continue;;
    esac
    if [ -n "$delete_paths" ] && printf '%s\n' "$delete_paths" | grep -Fqx "$retired_path"; then continue; fi
    candidate="$tgt/$retired_path"
    candidate_state=$(classify_path_entry "$candidate")
    if [ "$candidate_state" = absent ]; then continue; fi
    if [ "$candidate_state" = cant-verify ]; then
      add_reconciliation_message "CANT-VERIFY: retained retired path '$retired_path' could not be examined; preserving it without inspection."
      continue
    fi
    if candidate_reparse=$(find_reparse_ancestor "$candidate"); then
      add_reconciliation_message "CANT-VERIFY: retained retired path '$retired_path' traverses reparse/symlink '$candidate_reparse'; preserving it without inspection."
    elif [ "$kind" = github-skill ]; then
      add_reconciliation_message "CANT-VERIFY: retained retired path '$retired_path' was not deleted; it may shadow canonical .claude/skills/$slug. Move intentional customization to .claude/skills/$slug and remove the retained GitHub copy after review."
    else
      add_reconciliation_message "CANT-VERIFY: retained retired path '$retired_path' was not deleted; running it may recreate higher-priority .github/skills shadows. Do not run it; migrate or retire it after review."
    fi
  done < <(awk -F '\t' '!seen[$2]++ { print }' "$retirement_entries")
fi

git_preflight_cant_verify() {
  echo 'CANT-VERIFY: Git state for this update/brownfield target could not be verified safely. Unset Git routing variables, install or repair Git, or repair/remove corrupt repository metadata, then re-run the installer.' >&2
  exit 4
}

git_windows_namespace=0
git_windows_cursor=""
git_windows_scan_root=""
git_windows_scan_kind=""

# Classify the Git-for-Windows Bash host once before either repository discovery or ambient Git
# routing inspection. Modern Git for Windows reports cygwin OSTYPE with a finite MSYSTEM identity;
# an unknown non-empty identity fails closed rather than silently receiving generic POSIX handling.
git_preflight_host_initialize() {
  local ostype_value="${OSTYPE:-}" msystem_value="${MSYSTEM:-}"
  local remainder server share_and_rest share

  git_windows_namespace=0
  git_windows_cursor=""
  git_windows_scan_root=""
  git_windows_scan_kind=""

  if [ "${ostype_value#msys}" != "$ostype_value" ]; then
    git_windows_namespace=1
  elif [ "${ostype_value#cygwin}" != "$ostype_value" ]; then
    if [ -z "$msystem_value" ]; then
      return 0
    fi
    if [ "$msystem_value" = "MINGW32" ] || [ "$msystem_value" = "MINGW64" ] ||
       [ "$msystem_value" = "UCRT64" ] || [ "$msystem_value" = "CLANGARM64" ]; then
      git_windows_namespace=1
    else
      return 2
    fi
  else
    return 0
  fi

  git_windows_cursor=$(cd "$tgt" 2>/dev/null && builtin pwd -W 2>/dev/null) || return 2
  case "$git_windows_cursor" in
    [A-Za-z]:/*)
      git_windows_scan_root="${git_windows_cursor%%/*}/"
      git_windows_scan_kind=drive
      ;;
    //?*/?*)
      remainder=${git_windows_cursor#//}
      server=${remainder%%/*}
      share_and_rest=${remainder#*/}
      share=${share_and_rest%%/*}
      [ -n "$server" ] && [ -n "$share" ] || return 2
      git_windows_scan_root="//$server/$share"
      case "$git_windows_cursor" in
        "$git_windows_scan_root"|"$git_windows_scan_root"/*) ;;
        *) return 2 ;;
      esac
      git_windows_scan_kind=unc
      ;;
    *) return 2 ;;
  esac
}

# Return 0 for repository evidence, 1 for none, and 2 when an ancestor cannot be inspected. The
# explicit -L arm is the lstat-equivalent that keeps a dangling .git link from disappearing. Git
# Bash needs its real Windows namespace root; MSYS / and //server are virtual parents that Git for
# Windows would never inspect while discovering from a drive or UNC share.
git_repository_evidence() {
  local cursor="$tgt" parent scan_root="" scan_kind=""
  if [ "$git_windows_namespace" -eq 1 ]; then
    cursor="$git_windows_cursor"
    scan_root="$git_windows_scan_root"
    scan_kind="$git_windows_scan_kind"
  fi
  while :; do
    [ -x "$cursor" ] || return 2
    if [ -e "$cursor/.git" ] || [ -L "$cursor/.git" ]; then return 0; fi
    if [ -n "$scan_root" ]; then
      [ "$cursor" = "$scan_root" ] && break
    else
      [ "$cursor" = / ] && break
    fi
    parent=${cursor%/*}; [ -n "$parent" ] || parent=/
    case "$scan_kind" in
      drive)
        [ "$parent" = "${scan_root%/}" ] && parent=$scan_root
        case "$parent" in "$scan_root"*) ;; *) return 2;; esac
        ;;
      unc)
        case "$parent" in "$scan_root"|"$scan_root"/*) ;; *) return 2;; esac
        ;;
    esac
    [ "$parent" != "$cursor" ] || break
    cursor="$parent"
  done
  if [ -f "$tgt/HEAD" ] && [ -d "$tgt/objects" ] && [ -d "$tgt/refs" ]; then return 0; fi
  return 1
}

# Allocate classifier output through the shared guarded registry; this safety-boundary caller maps
# a later allocation failure to the Git preflight's existing CANT-VERIFY disposition.
new_git_preflight_temp() {
  git_preflight_temp=""
  new_temp_file || return 1
  git_preflight_temp=$new_temp
}

git_ambient_routing_present() {
  if [ -n "${GIT_DIR:-}" ] || [ -n "${GIT_WORK_TREE:-}" ] || [ -n "${GIT_COMMON_DIR:-}" ] || [ -n "${GIT_INDEX_FILE:-}" ]; then
    return 0
  fi
  if [ "$git_windows_namespace" -eq 1 ]; then
    while IFS= read -r git_env_name; do
      case "$git_env_name" in
        [Gg][Ii][Tt]_[Dd][Ii][Rr]|[Gg][Ii][Tt]_[Ww][Oo][Rr][Kk]_[Tt][Rr][Ee][Ee]|[Gg][Ii][Tt]_[Cc][Oo][Mm][Mm][Oo][Nn]_[Dd][Ii][Rr]|[Gg][Ii][Tt]_[Ii][Nn][Dd][Ee][Xx]_[Ff][Ii][Ll][Ee]) ;;
        *) continue ;;
      esac
      [ -n "${!git_env_name}" ] && return 0
    done < <(compgen -e)
  fi
  return 1
}

# Git is optional for a plain target, but repository evidence or redirected Git state must never be
# reinterpreted as non-Git. This helper block introduces no syntax newer than Bash 3.2.
if [ "$dry_run" -ne 1 ] && { [ "$adopt_mode" -eq 1 ] || [ "$update_mode" -eq 1 ]; }; then
  git_preflight_host_initialize || git_preflight_cant_verify

  if git_ambient_routing_present; then
    git_preflight_cant_verify
  fi

  repository_evidence=0
  if git_repository_evidence; then
    repository_evidence=1
  else
    evidence_exit=$?
    [ "$evidence_exit" -eq 1 ] || git_preflight_cant_verify
  fi

  git_path=$(type -P git 2>/dev/null || true)
  if [ -z "$git_path" ]; then
    [ "$repository_evidence" -eq 0 ] || git_preflight_cant_verify
  else
    new_git_preflight_temp || git_preflight_cant_verify
    git_probe_output=$git_preflight_temp
    if "$git_path" -C "$tgt" rev-parse --is-inside-work-tree > "$git_probe_output" 2>/dev/null; then
      if printf 'true' | cmp -s - "$git_probe_output"; then :
      elif printf 'true\r' | cmp -s - "$git_probe_output"; then :
      elif printf 'true\n' | cmp -s - "$git_probe_output"; then :
      elif printf 'true\r\n' | cmp -s - "$git_probe_output"; then :
      else git_preflight_cant_verify
      fi

      new_git_preflight_temp || git_preflight_cant_verify
      git_status_output=$git_preflight_temp
      if "$git_path" --no-optional-locks -C "$tgt" status --porcelain=v1 --untracked-files=all > "$git_status_output" 2>/dev/null; then
        if [ -s "$git_status_output" ]; then
          if [ "$allow_dirty_tree" -ne 1 ]; then
            echo 'ERROR: Refusing to mutate a dirty Git target. Commit, stash, or copy local changes, then re-run; use --allow-dirty-tree only after doing so deliberately.' >&2
            exit 4
          fi
          echo '  override: --allow-dirty-tree accepted for this dirty Git target.'
        fi
      else
        git_status_exit=$?
        echo 'CANT-VERIFY: Git identified this target as a worktree, but its status could not be read. Commit, stash, or copy local changes, then repair Git and re-run the installer.' >&2
        exit 4
      fi
    else
      git_probe_exit=$?
      [ "$repository_evidence" -eq 0 ] || git_preflight_cant_verify
    fi
  fi
fi

echo "Installing AI Tech Lead Framework"
echo "  from: $src"
echo "  into: $tgt"
if [ "$update_mode" -eq 1 ]; then echo "  mode: update (existing install detected via .claude/framework-version.json)"
elif [ "$adopt_mode" -eq 1 ]; then echo "  mode: brownfield (pre-existing AI tooling detected: $detected)"
else echo "  mode: greenfield"; fi
if [ "$update_mode" -eq 1 ] && [ "$version_comparison" -eq 1 ] && [ "$allow_downgrade" -eq 1 ]; then
  echo "  override: --allow-downgrade accepted for downgrade $installed_version -> $incoming_version."
fi
if [ -n "$reconciliation_messages" ]; then while IFS= read -r message; do echo "  $message"; done <<EOF
$reconciliation_messages
EOF
fi

if [ "$update_mode" -eq 1 ]; then
  echo "  UPDATE PREFLIGHT: This update replaces framework-owned files, including .claude/settings.json."
  echo "  Ensure any local edits to those files were committed, stashed, or copied first."
  echo "  Review the resulting diff before committing."
fi

archived=""
if [ "$adopt_mode" -eq 1 ]; then
  # Screen-in-place carriers remain at their consumer-owned paths, but only regular in-repo
  # files qualify. Refuse links/non-files before the broad collision loop skips them.
  for f in $copy_if_absent; do
    if source_reparse=$(find_reparse_ancestor "$tgt/$f"); then
      echo "ERROR: Refusing screen-in-place path '$f': source path traverses reparse/symlink '$source_reparse'. Remove the link or copy the original into the repository, then re-run." >&2
      exit 3
    fi
    if [ -e "$tgt/$f" ] && [ ! -f "$tgt/$f" ]; then
      echo "ERROR: Refusing screen-in-place path '$f': the target path is not a regular file." >&2
      exit 3
    fi
  done
  archive_files=""
  archive_relatives=""
  # Complete preflight: validate every original, destination, and parent before moving anything.
  for f in $incoming_paths; do
    case " $copy_if_absent $legal_license $legal_notice " in *" $f "*) continue;; esac
    if source_reparse=$(find_reparse_ancestor "$tgt/$f"); then
      echo "ERROR: Refusing brownfield collision '$f': source path traverses reparse/symlink '$source_reparse'. Remove the link or copy the original into the repository, then re-run." >&2
      exit 3
    fi
    [ ! -e "$tgt/$f" ] && continue
    if [ ! -f "$tgt/$f" ]; then
      echo "ERROR: Refusing brownfield collision '$f': the target path is not a file and cannot be archived safely." >&2
      exit 3
    fi
    rel="docs/pre-adoption/$f"
    if destination_reparse=$(find_reparse_ancestor "$tgt/$rel"); then
      echo "ERROR: Refusing brownfield install: archive destination traverses reparse/symlink '$destination_reparse'. Remove the link, then re-run." >&2
      exit 3
    fi
    case " $archive_relatives " in *" $rel "*) echo "ERROR: Refusing brownfield install: archive destination already exists or is ambiguous: '$rel'." >&2; exit 3;; esac
    if [ -e "$tgt/$rel" ]; then
      echo "ERROR: Refusing brownfield install: archive destination already exists or is ambiguous: '$rel'." >&2
      exit 3
    fi
    parent=$(dirname "$tgt/$rel")
    while [ "$parent" != "$tgt" ]; do
      if [ -e "$parent" ] && [ ! -d "$parent" ]; then
        echo "ERROR: Refusing brownfield install: archive destination parent is not a directory: '$parent'." >&2
        exit 3
      fi
      parent=$(dirname "$parent")
    done
    archive_files="$archive_files $f"
    archive_relatives="$archive_relatives $rel"
  done
  archive_files="${archive_files# }"
fi

# Compute a deterministic, complete plan before the first target mutation. Protected files are
# skipped directly; skill backup and disable operations are represented leaf-by-leaf.
new_temp_file || exit 3; operation_plan=$new_temp; : > "$operation_plan"
new_temp_file || exit 3; apply_paths=$new_temp; : > "$apply_paths"
new_temp_file || exit 3; backup_pairs=$new_temp; : > "$backup_pairs"
new_temp_file || exit 3; disabled_carry_pairs=$new_temp; : > "$disabled_carry_pairs"
new_temp_file || exit 3; disabled_incoming_pairs=$new_temp; : > "$disabled_incoming_pairs"
new_temp_file || exit 3; skill_delete_paths=$new_temp; : > "$skill_delete_paths"
new_temp_file || exit 3; disabled_names=$new_temp; : > "$disabled_names"
new_temp_file || exit 3; skill_exemplars=$new_temp; : > "$skill_exemplars"
new_temp_file || exit 3; incoming_framework_skill_names=$new_temp; : > "$incoming_framework_skill_names"
command -v tar >/dev/null 2>&1 || { echo 'ERROR: tar is required to apply the manifest-driven install.' >&2; exit 3; }

is_disabled_skill() { grep -Fqx "$1" "$disabled_names"; }
is_incoming_framework_skill() { grep -Fqx "$1" "$incoming_framework_skill_names"; }
is_discovered_claude_skill() {
  local relative="$1" rest name skill_file
  case "$relative" in .claude/skills/*) rest="${relative#.claude/skills/}";; *) return 1;; esac
  name="${rest%%/*}"; skill_file="$tgt/.claude/skills/$name/SKILL.md"
  [ -f "$skill_file" ] && grep -Eq '^origin:[[:space:]]*discovered[[:space:]]*$' "$skill_file"
}
plan_write() {
  local relative="$1" force_create="${2:-0}"
  assert_target_mutation "$relative" file || exit 3
  if [ "$force_create" -eq 1 ] || { [ ! -e "$tgt/$relative" ] && [ ! -L "$tgt/$relative" ]; }; then printf 'create\t%s\n' "$relative" >> "$operation_plan"
  else printf 'replace\t%s\n' "$relative" >> "$operation_plan"; fi
}

if [ "$update_mode" -eq 1 ]; then
  if [ -f "$tgt/LEARNINGS.md" ]; then
    LC_ALL=C sed $'1s/^\357\273\277//' "$tgt/LEARNINGS.md" |
      sed -n -E 's/^## Disabled framework skill:[[:space:]]*([a-z0-9-]+)[[:space:]]*$/\1/p' |
      LC_ALL=C "$sort_cmd" -u > "$disabled_names"
  fi
  while IFS=$'\t' read -r _ incoming_path ownership; do
    case "$incoming_path" in
      .claude/skills/*/*)
        [ "$ownership" = 'framework-owned/overwritten' ] || continue
        incoming_rest="${incoming_path#.claude/skills/}"
        printf '%s\n' "${incoming_rest%%/*}" >> "$incoming_framework_skill_names"
        ;;
    esac
  done < "$incoming_entries"
  LC_ALL=C "$sort_cmd" -u "$incoming_framework_skill_names" -o "$incoming_framework_skill_names"
  if [ -d "$tgt/.claude/skills" ]; then
    while IFS= read -r item; do
      relative="${item#"$tgt"/}"
      assert_target_mutation "$relative" tree || { echo "ERROR: Refusing update skill reconciliation at '$relative'." >&2; exit 3; }
    done < <("$find_cmd" "$tgt/.claude/skills" -mindepth 1 -print)
    for skill_dir in "$tgt/.claude/skills"/*; do
      [ -d "$skill_dir" ] || continue; name="${skill_dir##*/}"; skill_file="$skill_dir/SKILL.md"; [ -f "$skill_file" ] || continue
      if ! grep -Eq '^origin:[[:space:]]*discovered[[:space:]]*$' "$skill_file" && is_incoming_framework_skill "$name"; then
        exemplar=$(grep -E '^For a concrete current instance in this repo, see .+$' "$skill_file" | head -1 || true)
        [ -z "$exemplar" ] || printf '%s\t%s\n' "$name" "$exemplar" >> "$skill_exemplars"
      fi
    done
  fi
fi

if [ "$update_mode" -eq 1 ] && [ -d "$tgt/.claude/skills" ] && [ ! -e "$tgt/.claude/framework-update-backup/skills" ]; then
  while IFS= read -r source; do
    under_skills="${source#"$tgt/.claude/skills/"}"; relative=".claude/framework-update-backup/skills/$under_skills"
    plan_write "$relative" 1; printf '%s\t%s\n' "$source" "$relative" >> "$backup_pairs"
  done < <("$find_cmd" "$tgt/.claude/skills" -type f -print)
fi

while IFS= read -r name; do
  [ -n "$name" ] || continue
  active="$tgt/.claude/skills/$name"
  if [ -d "$active" ]; then
    while IFS= read -r source; do
      under_skill="${source#"$active/"}"; relative=".claude/disabled-skills/$name/$under_skill"
      plan_write "$relative"; printf '%s\t%s\n' "$source" "$relative" >> "$disabled_carry_pairs"
    done < <("$find_cmd" "$active" -type f -print)
    assert_target_mutation ".claude/skills/$name" tree || exit 3
    printf '%s\n' ".claude/skills/$name" >> "$skill_delete_paths"
  fi
done < "$disabled_names"

while IFS= read -r relative; do
  case "$relative" in
    .claude/skills/*)
      rest="${relative#.claude/skills/}"; name="${rest%%/*}"
      if [ "$update_mode" -eq 1 ] && is_disabled_skill "$name"; then inactive=".claude/disabled-skills/$rest"; plan_write "$inactive"; printf '%s\t%s\n' "$relative" "$inactive" >> "$disabled_incoming_pairs"; continue; fi;;
  esac
  destination="$tgt/$relative"; exists=0; if [ -e "$destination" ] || [ -L "$destination" ]; then exists=1; fi
  preserve=0
  if [ "$exists" -eq 1 ]; then
    case " $copy_if_absent " in *" $relative "*) preserve=1;; esac
    if [ "$update_mode" -eq 1 ]; then case " $protected " in *" $relative "*) preserve=1;; esac; fi
    if [ "$relative" = "$legal_license" ] && [ "$copy_legal_license" -eq 0 ]; then preserve=1; fi
    if is_discovered_claude_skill "$relative"; then preserve=1; fi
  fi
  if [ "$preserve" -eq 1 ]; then printf 'preserve\t%s\n' "$relative" >> "$operation_plan"; continue; fi
  force_create=0; case " ${archive_files:-} " in *" $relative "*) force_create=1;; esac
  plan_write "$relative" "$force_create"; printf './%s\n' "$relative" >> "$apply_paths"
done <<EOF
$incoming_paths
EOF
if [ -n "$retirement_preserve" ]; then while IFS= read -r relative; do printf 'preserve\t%s\n' "$relative" >> "$operation_plan"; done <<EOF
$retirement_preserve
EOF
fi

settings_backup_relative=""
if [ "$update_mode" -eq 1 ] && [ -f "$tgt/.claude/settings.json" ]; then settings_backup_relative='.claude/.state/settings.json.pre-update'; plan_write "$settings_backup_relative"; fi

if [ "$adopt_mode" -eq 1 ]; then plan_write '.claude/adoption-pending.json'; fi
if [ "$git_hooks" -eq 1 ]; then plan_write "$git_hook_relative" 1; fi
for f in ${archive_files:-}; do printf 'archive\tdocs/pre-adoption/%s\n' "$f" >> "$operation_plan"; done
if [ -n "$delete_paths" ]; then while IFS= read -r relative; do printf 'delete\t%s\n' "$relative" >> "$operation_plan"; done <<EOF
$delete_paths
EOF
fi
while IFS= read -r relative; do [ -z "$relative" ] || printf 'delete\t%s\n' "$relative" >> "$operation_plan"; done < "$skill_delete_paths"
if [ "$update_mode" -eq 1 ]; then mode_name=update; elif [ "$adopt_mode" -eq 1 ]; then mode_name=brownfield; else mode_name=greenfield; fi
echo "OPERATION-PLAN schema=1 mode=$mode_name"
for category in create replace preserve archive delete; do LC_ALL=C "$sort_cmd" -u "$operation_plan" | awk -F '\t' -v c="$category" '$1 == c { print "PLAN " $1 " " $2 }'; done
if [ "$dry_run" -eq 1 ]; then echo 'Dry run complete; target was not modified.'; exit 0; fi

for f in ${archive_files:-}; do rel="docs/pre-adoption/$f"; mkdir -p "$(dirname "$tgt/$rel")"; mv "$tgt/$f" "$tgt/$rel"; archived="$archived $rel"; echo "  archived: $f -> $rel"; done
archived="${archived# }"
if [ -n "$delete_paths" ]; then while IFS= read -r relative; do rm -f "$tgt/$relative"; echo "  retired: $relative"; done <<EOF
$delete_paths
EOF
fi
if [ -n "$settings_backup_relative" ]; then mkdir -p "$(dirname "$tgt/$settings_backup_relative")"; cp "$tgt/.claude/settings.json" "$tgt/$settings_backup_relative"; echo "  saved pre-update settings: $settings_backup_relative"; fi
while IFS=$'\t' read -r source relative; do [ -n "$source" ] || continue; mkdir -p "$(dirname "$tgt/$relative")"; cp -p "$source" "$tgt/$relative"; done < "$backup_pairs"
while IFS=$'\t' read -r source relative; do [ -n "$source" ] || continue; mkdir -p "$(dirname "$tgt/$relative")"; cp -p "$source" "$tgt/$relative"; done < "$disabled_carry_pairs"

# The main manifest payload remains one archive stream; skill side writes are small planned copies.
(cd "$src" && tar -cf - -T "$apply_paths") | tar -xf - -C "$tgt"
while IFS=$'\t' read -r source_relative relative; do [ -n "$source_relative" ] || continue; mkdir -p "$(dirname "$tgt/$relative")"; cp -p "$src/$source_relative" "$tgt/$relative"; done < "$disabled_incoming_pairs"
while IFS=$'\t' read -r name exemplar; do
  [ -n "$name" ] || continue; if is_disabled_skill "$name"; then new_file="$tgt/.claude/disabled-skills/$name/SKILL.md"; else new_file="$tgt/.claude/skills/$name/SKILL.md"; fi
  if [ -f "$new_file" ]; then sed -i.bak '/^For a concrete current instance in this repo, see .\+$/d' "$new_file"; rm -f "$new_file.bak"; printf '\n%s\n' "$exemplar" >> "$new_file"; fi
done < "$skill_exemplars"
while IFS= read -r relative; do [ -z "$relative" ] || rm -rf "$tgt/$relative"; done < "$skill_delete_paths"
if [ "$update_mode" -eq 1 ]; then echo "  consumer-owned content files left untouched ($protected)."; fi

if [ "$adopt_mode" -eq 1 ]; then
  # Durable adoption marker: the SessionStart hook warns every new session, and docs-sync-check
  # fails CI, until /adopt consumes it (deleted in /adopt Phase 3).
  json_list() { local out="" item; for item in $1; do out="$out\"$item\", "; done; printf '%s' "${out%, }"; }
  cat > "$tgt/.claude/adoption-pending.json" <<EOF
{
  "installedAt": "$(date +%Y-%m-%d)",
  "detectedArtifacts": [$(json_list "$detected")],
  "archivedOriginals": [$(json_list "$archived")],
  "nextStep": "/adopt - a developer types it in a session, OR an agent runs it headless (read .claude/commands/adopt.md and follow its Headless mode, or use .github/prompts/adopt.prompt.md with a --headless directive). Headless prepares an adopt-ai-framework PR branch for human review; it does not auto-merge discovered content.",
  "_comment": "Written by the framework installer because pre-existing AI tooling was detected. Consolidate it with /adopt - NOT /bootstrap. /adopt deletes this file in its Phase 3."
}
EOF
fi

# Claude Code hooks default to pwsh (PowerShell 7). If this box doesn't have it, switch them to the
# bash twins (bash is the Unix prerequisite anyway) so the hooks still fire.
sj="$tgt/.claude/settings.json"
if [ -f "$sj" ] && ! command -v pwsh >/dev/null 2>&1; then
  new_temp_file || exit 3; tmp=$new_temp; tmp_index=$new_temp_index
  if sed -E 's#pwsh -NoProfile -ExecutionPolicy Bypass -File \.claude/hooks/([A-Za-z-]+)\.ps1#bash .claude/hooks/\1.sh#g' "$sj" > "$tmp" && mv "$tmp" "$sj"; then
    release_temp_file "$tmp_index" || exit 3
    echo "  pwsh not found - switched Claude Code hooks to the bash twins."
  else
    echo "ERROR: Could not adapt Claude Code hook settings to the Bash twins." >&2
    exit 3
  fi
fi
if [ "$git_hooks" -eq 1 ]; then bash "$tgt/scripts/setup-git-hooks.sh" --target "$tgt"; fi
echo
echo "Each developer should run  bash scripts/framework-doctor.sh  once on their own machine."
if [ "$update_mode" -eq 1 ]; then
  echo "Done (update). Framework-owned machinery refreshed; the listed protected paths were left untouched; .claude/settings.json was backed up and refreshed."
  echo "  Next: review the diff, run  bash scripts/docs-sync-check.sh , then commit."
elif [ "$adopt_mode" -eq 1 ]; then
  echo "Done - but this repo is NOT ready for AI-assisted work yet: it has pre-existing AI"
  echo "tooling that must be consolidated with /adopt. The originals this install displaced"
  echo "are under docs/pre-adoption/; .claude/adoption-pending.json records the inventory."
  echo
  echo "Next steps in the target repo:"
  echo "  1. Review and commit the copied files (they are team-shared config, not local settings)."
  echo "  2. A DEVELOPER must start a Claude Code session in the target repo and type:  /adopt"
  echo "     - /adopt is developer-initiated: AI agents and the model CANNOT invoke it, and it"
  echo "       only exists inside a session started in the target repo."
  echo "     - Do NOT run /bootstrap instead - it would skip the archive/merge/provenance flow."
  echo "       The SessionStart hook and docs-sync-check flag this"
  echo "       repo until /adopt has run."
  echo
  echo "  IF YOU ARE AN AI AGENT running this installer: your task is NOT complete until you"
  echo "  have done step 1 (commit the copied files) and then EITHER told the developer to start a"
  echo "  Claude Code session in the target repo and type /adopt, OR run headless adoption yourself:"
  echo "  invoke the adopt workflow with a --headless directive (use .github/prompts/adopt.prompt.md,"
  echo "  or read .claude/commands/adopt.md and follow its 'Headless mode'). Headless adoption"
  echo "  PREPARES a PR: it creates the adopt-ai-framework branch, archives and screens the"
  echo "  originals, and STAGES every CLAUDE.md/TECH_DEBT merge for a human to review - it does NOT"
  echo "  apply untrusted discovered content and does NOT open or merge the PR, so a person still"
  echo "  approves the staged changes. Do not replicate it by hand - run the real workflow (headless)"
  echo "  or hand off to a developer. Report whichever you did as the next step in your final summary."
else
  echo "Done. Next steps in the target repo:"
  echo "  1. Review and commit the copied files (they are team-shared config, not local settings)."
  echo "  2. A DEVELOPER must start a Claude Code session in the target repo and type:  /bootstrap"
  echo "     - /bootstrap is developer-initiated: AI agents and the model CANNOT invoke it, and it"
  echo "       only exists inside a session started in the target repo."
  echo "  3. Until /bootstrap has run, docs-sync-check FAILS by design - that is expected at this"
  echo "     stage, not a defect to fix. After it has run, verify:  bash scripts/docs-sync-check.sh"
  echo "  4. Review the generated CLAUDE.md - it is canonical; client delivery varies (see docs/enforcement-surfaces.md)."
  echo
  echo "  IF YOU ARE AN AI AGENT running this installer: your task is NOT complete until you"
  echo "  have done step 1 and then told the developer, explicitly, to start a Claude Code"
  echo "  session in the target repo and type /bootstrap. Report that as the required manual next"
  echo "  step in your final summary. Do not attempt /bootstrap yourself or replicate it by hand."
fi

# The script's exit code must not be whatever the last conditional happened to leave. Without this,
# an ordinary UPDATE exited 1 with no error message -- the final `if` on that path ends on a
# non-match -- while the .ps1 twin exited 0, so the twins disagreed on a successful install and a
# consumer wiring this into CI would see a red pipeline on a good run. Greenfield masked it because
# a different branch ran last. Any failure above exits explicitly and non-zero before reaching here.
exit 0
