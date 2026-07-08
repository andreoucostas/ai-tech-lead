#!/usr/bin/env bash
# ai-tech-lead composer (bash twin; .ps1 twin lands in Phase 3). Composes src/ -> dist/<mode>.
# Modes: dotnet, angular  (monorepo added in Phase 4). Deterministic LF output.
#
# Mechanism (kept dumb — copy + marker substitution + file overlay, nothing else):
#   1. Copy src/core -> dist/<mode>, substituting named insertion markers:
#        markdown/text:  a line that is exactly   <!-- @stack:NAME -->
#        scripts:        a line that is exactly   # @stack:NAME
#      -> replaced by src/stacks/<mode>/snippets/<core-relpath>/<NAME> (removed if that snippet
#         file is absent for this stack).
#   2. Overlay src/stacks/<mode>/files/<relpath> (whole-file per-stack overrides + stack-only files).
#   3. Validate: no unresolved @stack: markers remain in dist.
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-}"
case "$MODE" in dotnet|angular) ;; *) echo "usage: build.sh {dotnet|angular}" >&2; exit 2;; esac

CORE="src/core"
SNIP="src/stacks/$MODE/snippets"
FILES="src/stacks/$MODE/files"
DIST="dist/$MODE"

rm -rf "$DIST"; mkdir -p "$DIST"

# 1. core, with marker substitution; normalize to LF
while IFS= read -r rel; do
  src="$CORE/$rel"; dst="$DIST/$rel"; mkdir -p "$(dirname "$dst")"
  if grep -qE '@stack:[A-Za-z0-9_-]+' "$src" 2>/dev/null; then
    awk -v snipdir="$SNIP/$rel" '
      function emit_snip(name,   line, path) {
        path = snipdir "/" name
        while ((getline line < path) > 0) { sub(/\r$/,"",line); print line }
        close(path)
      }
      {
        s=$0; sub(/\r$/,"",s)
        if (s ~ /^[[:space:]]*<!-- @stack:[A-Za-z0-9_-]+ -->[[:space:]]*$/) {
          name=s; sub(/^[[:space:]]*<!-- @stack:/,"",name); sub(/ -->[[:space:]]*$/,"",name); emit_snip(name)
        } else if (s ~ /^[[:space:]]*# @stack:[A-Za-z0-9_-]+[[:space:]]*$/) {
          name=s; sub(/^[[:space:]]*# @stack:/,"",name); sub(/[[:space:]]*$/,"",name); emit_snip(name)
        } else { print s }
      }
    ' "$src" > "$dst"
  else
    sed 's/\r$//' "$src" > "$dst"
  fi
done < <(cd "$CORE" && find . -type f | sed 's#^\./##')

# 2. overlay per-stack files (whole-file overrides + stack-only), normalized LF
if [ -d "$FILES" ]; then
  while IFS= read -r rel; do
    dst="$DIST/$rel"; mkdir -p "$(dirname "$dst")"
    sed 's/\r$//' "$FILES/$rel" > "$dst"
  done < <(cd "$FILES" && find . -type f | sed 's#^\./##')
fi

# 3. validate: no unresolved markers
if grep -rIlE '@stack:[A-Za-z0-9_-]+' "$DIST" 2>/dev/null; then
  echo "ERROR: unresolved @stack markers in $DIST (files listed above)" >&2; exit 1
fi

echo "composed $DIST ($(find "$DIST" -type f | wc -l) files)"
