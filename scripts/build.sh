#!/usr/bin/env bash
# ai-tech-lead composer (bash twin of build.ps1). Composes src/ -> dist/<mode>.
# Modes: dotnet, angular, monorepo. Deterministic LF output.
#
# Mechanism (kept dumb — copy + marker substitution + file overlay, nothing else):
#   1. Copy src/core -> dist/<mode>, substituting named insertion markers:
#        markdown/text:  a line that is exactly   <!-- @stack:NAME -->
#        scripts:        a line that is exactly   # @stack:NAME
#      single-stack mode -> replaced by src/stacks/<mode>/snippets/<core-relpath>/<NAME>
#        (removed if that snippet file is absent for this stack).
#      monorepo mode     -> src/stacks/monorepo/snippets/<core-relpath>/<NAME> if it exists
#        (authored merged/sectioned content), else the dotnet snippet followed by the angular
#        snippet (raw concatenation — union semantics; either may be absent).
#   2. Overlay src/stacks/<mode>/files/<relpath> (whole-file per-stack overrides + stack-only
#      files). monorepo mode overlays dotnet, then angular, then monorepo files — and FAILS if
#      a path exists in both stacks' files/ without a monorepo override (no silent last-wins:
#      every whole-file collision must be an explicit authored decision).
#   3. Validate: no unresolved @stack: markers remain in dist.
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-}"
case "$MODE" in dotnet|angular|monorepo) ;; *) echo "usage: build.sh {dotnet|angular|monorepo}" >&2; exit 2;; esac

CORE="src/core"
DIST="dist/$MODE"

temp_files=""
new_temp_file() { new_temp=$(mktemp); temp_files="$temp_files $new_temp"; }
cleanup() { for f in $temp_files; do rm -f "$f"; done; }
trap cleanup EXIT

valid_repo_path() {
  local path="$1" segment
  [ -n "$path" ] || return 1
  case "$path" in /*|\\*|//*|[A-Za-z]:*|*\\*) return 1;; esac
  IFS='/' read -r -a segments <<< "$path"
  for segment in "${segments[@]}"; do [ -n "$segment" ] && [ "$segment" != . ] && [ "$segment" != .. ] || return 1; done
}

# Emit path<TAB>retired-in<TAB>hash rows after validating the deliberately narrow canonical JSON
# form shipped by this repo. Refusing a reformatted file is safe: composer metadata is authored,
# generated and reviewed here rather than accepted as a general-purpose JSON interchange format.
validate_ledger() {
  local file="$1" label="$2" output="$3" stripped parsed expected path version hashes hash previous_path="" previous_hash
  [ -f "$file" ] || { echo "ERROR: missing retirement ledger: $label" >&2; return 1; }
  [ "$(grep -Ec '^[[:space:]]*"schema-version"[[:space:]]*:[[:space:]]*1,?[[:space:]]*$' "$file")" -eq 1 ] || { echo "ERROR: $label has an unsupported or missing retirement schema" >&2; return 1; }
  new_temp_file; stripped=$new_temp; tr -d '\000' < "$file" > "$stripped"; cmp -s "$file" "$stripped" || { echo "ERROR: $label contains NUL bytes" >&2; return 1; }
  new_temp_file; parsed=$new_temp
  sed -n 's/^[[:space:]]*{ "path": "\([^"]*\)", "retired-in": "\([^"]*\)", "known-content-sha256": \[\(.*\)\] }[,]\{0,1\}[[:space:]]*$/\1\	\2\	\3/p' "$file" > "$parsed"
  expected=$(grep -c '"retired-in"' "$file" || true)
  [ "$expected" -eq "$(wc -l < "$parsed" | tr -d ' ')" ] || { echo "ERROR: $label contains a malformed retirement entry" >&2; return 1; }
  : > "$output"
  while IFS=$'\t' read -r path version hashes; do
    valid_repo_path "$path" || { echo "ERROR: $label contains unsafe or non-normalized path '$path'" >&2; return 1; }
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "ERROR: $label has invalid retired-in version '$version' for '$path'" >&2; return 1; }
    if [ -n "$previous_path" ] && [[ ! "$previous_path" < "$path" ]]; then echo "ERROR: $label paths are not unique ordinal values at '$path'" >&2; return 1; fi
    hashes=$(printf '%s' "$hashes" | sed 's/",[[:space:]]*"/ /g; s/"//g')
    [ -n "$hashes" ] || { echo "ERROR: $label has no known-content-sha256 values for '$path'" >&2; return 1; }
    previous_hash=""
    for hash in $hashes; do
      [[ "$hash" =~ ^[0-9a-f]{64}$ ]] || { echo "ERROR: $label has invalid SHA-256 '$hash' for '$path'" >&2; return 1; }
      if [ -n "$previous_hash" ] && [[ ! "$previous_hash" < "$hash" ]]; then echo "ERROR: $label hashes are not unique ordinal values for '$path'" >&2; return 1; fi
      printf '%s\t%s\t%s\n' "$path" "$version" "$hash" >> "$output"
      previous_hash="$hash"
    done
    previous_path="$path"
  done < "$parsed"
}

if [ "$MODE" = "monorepo" ]; then
  # In monorepo mode the file collision check must pass before anything is composed.
  collide=0
  while IFS= read -r rel; do
    if [ -f "src/stacks/angular/files/$rel" ] && [ ! -f "src/stacks/monorepo/files/$rel" ]; then
      echo "ERROR: '$rel' exists in both src/stacks/dotnet/files and src/stacks/angular/files but has no src/stacks/monorepo/files override" >&2
      collide=1
    fi
  done < <(cd src/stacks/dotnet/files && find . -type f | sed 's#^\./##')
  [ "$collide" -eq 0 ] || exit 1
fi

new_temp_file; retirement_baselines=$new_temp; : > "$retirement_baselines"
maintainer_ledger="meta/framework-retirements-baseline.json"
new_temp_file; maintainer_retirements=$new_temp
validate_ledger "$maintainer_ledger" "$maintainer_ledger" "$maintainer_retirements" || exit 1
cat "$maintainer_retirements" >> "$retirement_baselines"

if [ -f "$DIST/framework-retirements.json" ]; then
  new_temp_file; previous_retirements=$new_temp
  validate_ledger "$DIST/framework-retirements.json" "existing $DIST/framework-retirements.json" "$previous_retirements" || exit 1
  cat "$previous_retirements" >> "$retirement_baselines"
fi

# The maintainer baseline provides bootstrap authority even though v0.75 and earlier have no ledger.
# Keep the generated dist as an archive snapshot. Add HEAD and the nearest tag only when this source
# root is itself the Git worktree root; an archive nested below an unrelated repo must ignore it.
composer_root=$(pwd -P)
git_root=""
if command -v git >/dev/null 2>&1; then
  candidate_git_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$candidate_git_root" ]; then git_root=$(cd "$candidate_git_root" 2>/dev/null && pwd -P || true); fi
fi
if [ -n "$git_root" ] && [ "$git_root" = "$composer_root" ]; then
  baseline_refs="HEAD"
  nearest_tag=$(git describe --tags --abbrev=0 --match 'v[0-9]*' HEAD 2>/dev/null || true)
  [ -z "$nearest_tag" ] || baseline_refs="$baseline_refs $nearest_tag"
  for ref in $baseline_refs; do
    new_temp_file; historical_ledger=$new_temp
    if git show "$ref:src/core/framework-retirements.json" > "$historical_ledger" 2>/dev/null; then
      new_temp_file; historical_retirements=$new_temp
      validate_ledger "$historical_ledger" "$ref:src/core/framework-retirements.json" "$historical_retirements" || exit 1
      cat "$historical_retirements" >> "$retirement_baselines"
    fi
  done
fi

rm -rf "$DIST"; mkdir -p "$DIST"

# 1. core, with marker substitution; normalize to LF
while IFS= read -r rel; do
  src="$CORE/$rel"; dst="$DIST/$rel"; mkdir -p "$(dirname "$dst")"
  if grep -qE '@stack:[A-Za-z0-9_-]+' "$src" 2>/dev/null; then
    awk -v mode="$MODE" \
        -v snipdir="src/stacks/$MODE/snippets/$rel" \
        -v monodir="src/stacks/monorepo/snippets/$rel" \
        -v dndir="src/stacks/dotnet/snippets/$rel" \
        -v angdir="src/stacks/angular/snippets/$rel" '
      function fexists(path,   line, r) { r = (getline line < path); close(path); return r >= 0 }
      function emit_snip(path,   line) {
        while ((getline line < path) > 0) { sub(/\r$/,"",line); print line }
        close(path)
      }
      function emit_marker(name) {
        if (mode == "monorepo") {
          if (fexists(monodir "/" name)) { emit_snip(monodir "/" name) }
          else { emit_snip(dndir "/" name); emit_snip(angdir "/" name) }
        } else { emit_snip(snipdir "/" name) }
      }
      {
        s=$0; sub(/\r$/,"",s)
        if (s ~ /^[[:space:]]*<!-- @stack:[A-Za-z0-9_-]+ -->[[:space:]]*$/) {
          name=s; sub(/^[[:space:]]*<!-- @stack:/,"",name); sub(/ -->[[:space:]]*$/,"",name); emit_marker(name)
        } else if (s ~ /^[[:space:]]*# @stack:[A-Za-z0-9_-]+[[:space:]]*$/) {
          name=s; sub(/^[[:space:]]*# @stack:/,"",name); sub(/[[:space:]]*$/,"",name); emit_marker(name)
        } else { print s }
      }
    ' "$src" > "$dst"
  else
    sed 's/\r$//' "$src" > "$dst"
  fi
done < <(cd "$CORE" && find . -type f | sed 's#^\./##')

# 2. overlay per-stack files (whole-file overrides + stack-only), normalized LF.
# monorepo = union of both stacks plus monorepo overrides (collisions already vetted above).
case "$MODE" in
  monorepo) OVERLAYS="src/stacks/dotnet/files src/stacks/angular/files src/stacks/monorepo/files" ;;
  *)        OVERLAYS="src/stacks/$MODE/files" ;;
esac
for FILES in $OVERLAYS; do
  if [ -d "$FILES" ]; then
    while IFS= read -r rel; do
      dst="$DIST/$rel"; mkdir -p "$(dirname "$dst")"
      sed 's/\r$//' "$FILES/$rel" > "$dst"
    done < <(cd "$FILES" && find . -type f | sed 's#^\./##')
  fi
done

# 3. Generate the installed-path ownership manifest. Both installer twins are read so a policy
# change in only one leg fails composition instead of silently producing a misleading manifest.
ps_protected=$(sed -n '/^\$protected[[:space:]]*=/,/)/p' "$DIST/scripts/install.ps1" | grep -o "'[^']*'" | tr -d "'" | tr '\n' ' ' | sed 's/ $//')
sh_protected=$(sed -n 's/^protected="\([^"]*\)"/\1/p' "$DIST/scripts/install.sh")
ps_persistent=$(sed -n '/^\$persistentCopyIfAbsent[[:space:]]*=/,/)/p' "$DIST/scripts/install.ps1" | grep -o "'[^']*'" | tr -d "'" | tr '\n' ' ' | sed 's/ $//')
sh_persistent=$(sed -n 's/^persistent_copy_if_absent="\([^"]*\)"/\1/p' "$DIST/scripts/install.sh")
if [ -z "$ps_protected" ] || [ -z "$sh_protected" ] || [ -z "$ps_persistent" ] || [ -z "$sh_persistent" ]; then
  echo "ERROR: ownership manifest could not read protected/persistent policy from both installers" >&2; exit 1
fi
for p in $ps_protected; do case " $sh_protected " in *" $p "*) ;; *) echo "ERROR: ownership policy disagreement: consumer-owned/protected in install.ps1 but not install.sh: $p" >&2; exit 1;; esac; done
for p in $sh_protected; do case " $ps_protected " in *" $p "*) ;; *) echo "ERROR: ownership policy disagreement: consumer-owned/protected in install.sh but not install.ps1: $p" >&2; exit 1;; esac; done
for p in $ps_persistent; do case " $sh_persistent " in *" $p "*) ;; *) echo "ERROR: ownership policy disagreement: persistent/copy-if-absent in install.ps1 but not install.sh: $p" >&2; exit 1;; esac; done
for p in $sh_persistent; do case " $ps_persistent " in *" $p "*) ;; *) echo "ERROR: ownership policy disagreement: persistent/copy-if-absent in install.sh but not install.ps1: $p" >&2; exit 1;; esac; done

ps_meta=$(sed -n 's/^\$metaFiles[[:space:]]*=[[:space:]]*@\((.*)\)/\1/p' "$DIST/scripts/install.ps1" | grep -o "'[^']*'" | tr -d "'" | tr '\n' ' ' | sed 's/ $//')
[ -n "$ps_meta" ] || { echo "ERROR: ownership manifest could not read meta policy from install.ps1" >&2; exit 1; }
for p in $ps_meta; do grep -Fq "$p" "$DIST/scripts/install.sh" || { echo "ERROR: ownership policy disagreement: excluded by install.ps1 but not install.sh: $p" >&2; exit 1; }; done

manifest="$DIST/framework-ownership.json"
new_temp_file; tmp_paths=$new_temp
# LC_ALL=C so this collates by byte, matching the ordinal comparison the .ps1 twin uses. Without it
# the two composers order an identical path set differently and emit byte-different manifests.
(cd "$DIST" && find . -type f | sed 's#^\./##' | LC_ALL=C sort) | while IFS= read -r rel; do
  case " $ps_meta scripts/install.ps1 scripts/install.sh .github/workflows/template-ci.yml " in *" $rel "*) continue;; esac
  # tests/hooks/** stays in every composed dist for maintainer and template CI, but is not a
  # consumer artifact: it must never enter framework-ownership.json, so installers never copy it
  # and its historical bytes are retired via framework-retirements.json (B-215 Slice A).
  case "$rel" in tests/hooks/*) continue;; esac
  if [ "$rel" = '.claude/settings.json' ]; then ownership='mixed'
  else
    case " $ps_protected $ps_persistent docs/wiki/INDEX.md LICENSES/ai-tech-lead-MIT.txt " in
      *" $rel "*) ownership='consumer-owned/protected';;
      *) ownership='framework-owned/overwritten';;
    esac
  fi
  printf '%s\t%s\n' "$rel" "$ownership"
done > "$tmp_paths"
printf '%s\t%s\n' 'framework-ownership.json' 'framework-owned/overwritten' >> "$tmp_paths"
sort -o "$tmp_paths" "$tmp_paths"
{
  printf '{\n  "schema-version": 1,\n  "paths": [\n'
  first=1
  while IFS="$(printf '\t')" read -r rel ownership; do
    [ "$first" -eq 1 ] || printf ',\n'; first=0
    printf '    { "path": "%s", "ownership": "%s" }' "$rel" "$ownership"
  done < "$tmp_paths"
  printf '\n  ]\n}\n'
} > "$manifest"

# 4. The incoming ledger is the only shipped deletion authority. Compare it with every captured
# maintainer/archive/Git baseline, then reject an active path.
new_temp_file; current_retirements=$new_temp
validate_ledger "$DIST/framework-retirements.json" "$DIST/framework-retirements.json" "$current_retirements" || exit 1
cmp -s "$maintainer_retirements" "$current_retirements" || { echo "ERROR: $DIST/framework-retirements.json and $maintainer_ledger must contain the same cumulative retirement entries" >&2; exit 1; }
LC_ALL=C sort -u "$retirement_baselines" | while IFS= read -r old; do
  [ -z "$old" ] || grep -Fqx "$old" "$current_retirements" || { echo "ERROR: cumulative retirement entry or historical digest disappeared: $old" >&2; exit 1; }
done
while IFS=$'\t' read -r retired_path _; do
  if awk -F '\t' -v p="$retired_path" '$1 == p { found=1 } END { exit !found }' "$tmp_paths"; then
    echo "ERROR: retirement '$retired_path' is still present in the incoming ownership manifest" >&2; exit 1
  fi
done < "$current_retirements"

# 5. validate: no unresolved markers
if grep -rIlE '@stack:[A-Za-z0-9_-]+' "$DIST" 2>/dev/null; then
  echo "ERROR: unresolved @stack markers in $DIST (files listed above)" >&2; exit 1
fi

echo "composed $DIST ($(find "$DIST" -type f | wc -l) files)"
