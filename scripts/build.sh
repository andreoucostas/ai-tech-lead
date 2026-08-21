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
if [ -z "$ps_protected" ] || [ -z "$sh_protected" ]; then
  echo "ERROR: ownership manifest could not read protected policy from both installers" >&2; exit 1
fi
for p in $ps_protected; do case " $sh_protected " in *" $p "*) ;; *) echo "ERROR: ownership policy disagreement: consumer-owned/protected in install.ps1 but not install.sh: $p" >&2; exit 1;; esac; done
for p in $sh_protected; do case " $ps_protected " in *" $p "*) ;; *) echo "ERROR: ownership policy disagreement: consumer-owned/protected in install.sh but not install.ps1: $p" >&2; exit 1;; esac; done

ps_meta=$(sed -n 's/^\$metaFiles[[:space:]]*=[[:space:]]*@\((.*)\)/\1/p' "$DIST/scripts/install.ps1" | grep -o "'[^']*'" | tr -d "'" | tr '\n' ' ' | sed 's/ $//')
[ -n "$ps_meta" ] || { echo "ERROR: ownership manifest could not read meta policy from install.ps1" >&2; exit 1; }
for p in $ps_meta; do grep -Fq "$p" "$DIST/scripts/install.sh" || { echo "ERROR: ownership policy disagreement: excluded by install.ps1 but not install.sh: $p" >&2; exit 1; }; done

manifest="$DIST/framework-ownership.json"
tmp_paths=$(mktemp); trap 'rm -f "$tmp_paths"' EXIT
# LC_ALL=C so this collates by byte, matching the ordinal comparison the .ps1 twin uses. Without it
# the two composers order an identical path set differently and emit byte-different manifests.
(cd "$DIST" && find . -type f | sed 's#^\./##' | LC_ALL=C sort) | while IFS= read -r rel; do
  case " $ps_meta scripts/install.ps1 scripts/install.sh .github/workflows/template-ci.yml " in *" $rel "*) continue;; esac
  if [ "$rel" = '.claude/settings.json' ]; then ownership='mixed'
  else
    case " $ps_protected docs/wiki/INDEX.md LICENSES/ai-tech-lead-MIT.txt " in
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

# 4. validate: no unresolved markers
if grep -rIlE '@stack:[A-Za-z0-9_-]+' "$DIST" 2>/dev/null; then
  echo "ERROR: unresolved @stack markers in $DIST (files listed above)" >&2; exit 1
fi

echo "composed $DIST ($(find "$DIST" -type f | wc -l) files)"
