#!/usr/bin/env bash
# Install the AI Tech Lead Framework into a target repository.
# Usage: bash scripts/install.sh /path/to/target-repo
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
#   update     — target already carries .claude/framework-version.json: framework machinery is
#                refreshed; consumer-owned content files are left untouched. Safe to re-run.
set -euo pipefail

target="${1:-}"
if [ -z "$target" ]; then echo "Usage: bash scripts/install.sh /path/to/target-repo"; exit 2; fi
[ -d "$target" ] || { echo "Target '$target' is not a directory."; exit 2; }

src="$(cd "$(dirname "$0")/.." && pwd)"
tgt="$(cd "$target" && pwd)"
if [ "$tgt" = "$src" ]; then echo "Target is the template repo itself — choose a different target."; exit 2; fi

# Consumer files the copy below would otherwise clobber. Brownfield: archived so /adopt can merge
# them. Update: snapshotted and restored — after bootstrap/adopt the consumer owns their content.
protected="CLAUDE.md AGENTS.md TECH_DEBT.md SECURITY_FINDINGS.md LEARNINGS.md FRAMEWORK-CONTEXT.md .github/copilot-instructions.md docs/ARCHITECTURE.md"

# Signals that the target already has AI tooling and therefore needs /adopt, not /bootstrap
# (mirrors /adopt Phase 1 discovery).
adoption_signals="CLAUDE.md AGENTS.md GEMINI.md .cursorrules .cursor/rules .clinerules .windsurfrules .roomodes .aider.conf.yml .continue .github/copilot-instructions.md .github/instructions .github/chatmodes docs/adr docs/decisions ARCHITECTURE.md docs/ARCHITECTURE.md CODEMAP.md CONVENTIONS.md docs/CONVENTIONS.md TECH_DEBT.md TODO.md BACKLOG.md"

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

echo "Installing AI Tech Lead Framework"
echo "  from: $src"
echo "  into: $tgt"
if [ "$update_mode" -eq 1 ]; then echo "  mode: update (existing install detected via .claude/framework-version.json)"
elif [ "$adopt_mode" -eq 1 ]; then echo "  mode: brownfield (pre-existing AI tooling detected: $detected)"
else echo "  mode: greenfield"; fi

archived=""
if [ "$adopt_mode" -eq 1 ]; then
  # Move originals out of the copy's way so /adopt can merge them later — without this they
  # would be overwritten by the template versions and lost from the working tree.
  for f in $protected; do
    if [ -f "$tgt/$f" ]; then
      rel="docs/pre-adoption/${f#.}"
      mkdir -p "$(dirname "$tgt/$rel")"
      mv -f "$tgt/$f" "$tgt/$rel"
      archived="$archived $rel"
      echo "  archived: $f -> $rel"
    fi
  done
  archived="${archived# }"
fi

snapshot=""
if [ "$update_mode" -eq 1 ]; then
  # Snapshot consumer-owned content files; restored after the copy.
  snapshot="$(mktemp -d)"
  for f in $protected; do
    if [ -f "$tgt/$f" ]; then
      mkdir -p "$snapshot/$(dirname "$f")"
      cp -p "$tgt/$f" "$snapshot/$f"
    fi
  done
fi

shopt -s dotglob nullglob 2>/dev/null || true
for entry in "$src"/*; do
  name="$(basename "$entry")"
  case "$name" in
    # Template-repo meta files that must never land in (or overwrite their namesakes in) a consumer repo.
    .git|.template-repo|README.md|CHANGELOG.md|.gitignore|.gitattributes) continue ;;
  esac
  cp -r "$entry" "$tgt"/
done
# The installer is meta — don't ship it into the consumer repo.
rm -f "$tgt/scripts/install.sh" "$tgt/scripts/install.ps1"

if [ "$update_mode" -eq 1 ] && [ -n "$snapshot" ]; then
  for f in $protected; do
    if [ -f "$snapshot/$f" ]; then cp -p "$snapshot/$f" "$tgt/$f"; fi
  done
  rm -rf "$snapshot"
  echo "  consumer-owned content files left untouched ($protected)."
fi

if [ "$adopt_mode" -eq 1 ]; then
  # Durable adoption marker: the SessionStart hook warns every new session, and docs-sync-check
  # fails CI, until /adopt consumes it (deleted in /adopt Phase 3).
  json_list() { local out="" item; for item in $1; do out="$out\"$item\", "; done; printf '%s' "${out%, }"; }
  cat > "$tgt/.claude/adoption-pending.json" <<EOF
{
  "installedAt": "$(date +%Y-%m-%d)",
  "detectedArtifacts": [$(json_list "$detected")],
  "archivedOriginals": [$(json_list "$archived")],
  "nextStep": "/adopt (developer-initiated; the model cannot invoke it)",
  "_comment": "Written by the framework installer because pre-existing AI tooling was detected. Consolidate it with /adopt - NOT /bootstrap. /adopt deletes this file in its Phase 3."
}
EOF
fi

# Claude Code hooks default to pwsh (PowerShell 7). If this box doesn't have it, switch them to the
# bash twins (bash is the Unix prerequisite anyway) so the hooks still fire.
sj="$tgt/.claude/settings.json"
if [ -f "$sj" ] && ! command -v pwsh >/dev/null 2>&1; then
  tmp="$(mktemp)"
  sed -E 's#pwsh -NoProfile -ExecutionPolicy Bypass -File \.claude/hooks/([A-Za-z-]+)\.ps1#bash .claude/hooks/\1.sh#g' "$sj" > "$tmp" && mv "$tmp" "$sj"
  echo "  pwsh not found - switched Claude Code hooks to the bash twins."
fi

echo
if [ "$update_mode" -eq 1 ]; then
  echo "Done (update). Framework machinery refreshed; consumer-owned content files untouched."
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
  echo "     - Do NOT run /bootstrap instead - it would skip the archive/merge/provenance flow"
  echo "       and the impact baseline. The SessionStart hook and docs-sync-check flag this"
  echo "       repo until /adopt has run."
  echo
  echo "  IF YOU ARE AN AI AGENT running this installer: your task is NOT complete until you"
  echo "  have done step 1 and then told the developer, explicitly, to start a Claude Code"
  echo "  session in the target repo and type /adopt. Report that as the required manual next"
  echo "  step in your final summary. Do not attempt /adopt yourself or replicate it by hand."
else
  echo "Done. Next steps in the target repo:"
  echo "  1. Review and commit the copied files (they are team-shared config, not local settings)."
  echo "  2. A DEVELOPER must start a Claude Code session in the target repo and type:  /bootstrap"
  echo "     (developer-initiated: AI agents and the model CANNOT invoke it. If you are an AI"
  echo "     agent running this installer, report that as the required manual next step in your"
  echo "     final summary - do not attempt /bootstrap yourself.)"
  echo "  3. After /bootstrap, verify:  bash scripts/docs-sync-check.sh"
  echo "  4. Review the generated CLAUDE.md - it is the source of truth that drives every tool."
fi
