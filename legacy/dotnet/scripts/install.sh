#!/usr/bin/env bash
# Install the AI Tech Lead Framework into a target repository.
# Usage: bash scripts/install.sh /path/to/target-repo
#
# Copies the template's framework files into the target, EXCLUDING the .git directory, the
# .template-repo marker (which would disable the consumer's CI guardrail), and the installer itself.
# Safe to re-run to update an existing install (it overwrites framework files, merges directories).
set -euo pipefail

target="${1:-}"
if [ -z "$target" ]; then echo "Usage: bash scripts/install.sh /path/to/target-repo"; exit 2; fi
[ -d "$target" ] || { echo "Target '$target' is not a directory."; exit 2; }

src="$(cd "$(dirname "$0")/.." && pwd)"
if [ "$(cd "$target" && pwd)" = "$src" ]; then echo "Target is the template repo itself — choose a different target."; exit 2; fi

echo "Installing AI Tech Lead Framework"
echo "  from: $src"
echo "  into: $target"

shopt -s dotglob nullglob 2>/dev/null || true
for entry in "$src"/*; do
  name="$(basename "$entry")"
  case "$name" in
    .git|.template-repo) continue ;;
  esac
  cp -r "$entry" "$target"/
done
# The installer is meta — don't ship it into the consumer repo.
rm -f "$target/scripts/install.sh" "$target/scripts/install.ps1"

# Claude Code hooks default to pwsh (PowerShell 7). If this box doesn't have it, switch them to the
# bash twins (bash is the Unix prerequisite anyway) so the hooks still fire.
sj="$target/.claude/settings.json"
if [ -f "$sj" ] && ! command -v pwsh >/dev/null 2>&1; then
  tmp="$(mktemp)"
  sed -E 's#pwsh -NoProfile -ExecutionPolicy Bypass -File \.claude/hooks/([A-Za-z-]+)\.ps1#bash .claude/hooks/\1.sh#g' "$sj" > "$tmp" && mv "$tmp" "$sj"
  echo "  pwsh not found - switched Claude Code hooks to the bash twins."
fi

echo
echo "Done. Next steps in the target repo:"
echo "  1. Review the copied files (commit them — they are team-shared config, not local settings)."
echo "  2. Existing AI tooling (CLAUDE.md / .cursorrules / Copilot instructions / ADRs)?  run  /adopt"
echo "     Greenfield (nothing AI-related yet)?                                            run  /bootstrap"
echo "  3. Verify the install:  bash scripts/docs-sync-check.sh"
echo "  4. Review the generated CLAUDE.md — it is the source of truth that drives every tool."
