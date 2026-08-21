#!/usr/bin/env bash
# Install the AI Tech Lead Framework into a target repository.
# Usage: bash scripts/install.sh [--git-hooks] /path/to/target-repo
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
if [ "${1:-}" = "--git-hooks" ]; then git_hooks=1; shift; fi
target="${1:-}"
if [ -z "$target" ]; then echo "Usage: bash scripts/install.sh [--git-hooks] /path/to/target-repo"; exit 2; fi
[ -d "$target" ] || { echo "Target '$target' is not a directory."; exit 2; }

src="$(cd "$(dirname "$0")/.." && pwd)"
tgt="$(cd "$target" && pwd)"
if [ "$tgt" = "$src" ]; then echo "Target is the template repo itself — choose a different target."; exit 2; fi
if [ "$git_hooks" -eq 1 ]; then bash "$src/scripts/setup-git-hooks.sh" --target "$tgt" --check-only; fi

# Consumer files the copy below would otherwise clobber. Brownfield: archived so /adopt can merge
# them. Update: snapshotted and restored — after bootstrap/adopt the consumer owns their content.
protected="CLAUDE.md AGENTS.md TECH_DEBT.md SECURITY_FINDINGS.md LEARNINGS.md FRAMEWORK-CONTEXT.md .github/copilot-instructions.md docs/ARCHITECTURE.md"
brownfield_collisions="$protected .github/instructions/framework-rules.instructions.md"

# Signals that the target already has AI tooling and therefore needs /adopt, not /bootstrap
# (mirrors /adopt Phase 1 discovery).
adoption_signals="CLAUDE.md AGENTS.md GEMINI.md .cursorrules .cursor/rules .clinerules .windsurfrules .roomodes .aider.conf.yml .continue .github/copilot-instructions.md .github/instructions .github/chatmodes docs/adr docs/decisions ARCHITECTURE.md docs/ARCHITECTURE.md CODEMAP.md CONVENTIONS.md docs/CONVENTIONS.md TECH_DEBT.md TODO.md BACKLOG.md docs/wiki/INDEX.md"

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

# These legal files are neither protected nor ordinary framework files. Protection would freeze a
# stale framework-owned notice; bulk copying would silently clobber consumer files. Preflight their
# explicit ownership policy before this installer mutates the target, then copy them after the bulk.
legal_license="LICENSES/ai-tech-lead-MIT.txt"
legal_notice="NOTICE-ai-tech-lead.md"
copy_legal_license=1
if [ -f "$tgt/$legal_license" ]; then
  source_lf="$(mktemp)"
  target_lf="$(mktemp)"
  awk '{ sub(/\015$/, ""); print }' "$src/$legal_license" > "$source_lf"
  awk '{ sub(/\015$/, ""); print }' "$tgt/$legal_license" > "$target_lf"
  if ! cmp -s "$source_lf" "$target_lf"; then
    rm -f "$source_lf" "$target_lf"
    echo "ERROR: Refusing to overwrite '$legal_license': the existing file is not identical to the framework licence." >&2
    exit 3
  fi
  rm -f "$source_lf" "$target_lf"
  copy_legal_license=0
fi
if [ -f "$tgt/$legal_notice" ] && ! grep -Fq 'FRAMEWORK-OWNED' "$tgt/$legal_notice"; then
  echo "ERROR: Refusing to overwrite '$legal_notice': the existing file is not marked FRAMEWORK-OWNED." >&2
  exit 3
fi

echo "Installing AI Tech Lead Framework"
echo "  from: $src"
echo "  into: $tgt"
if [ "$update_mode" -eq 1 ]; then echo "  mode: update (existing install detected via .claude/framework-version.json)"
elif [ "$adopt_mode" -eq 1 ]; then echo "  mode: brownfield (pre-existing AI tooling detected: $detected)"
else echo "  mode: greenfield"; fi

if [ "$update_mode" -eq 1 ]; then
  echo "  UPDATE PREFLIGHT: This update replaces framework-owned files, including .claude/settings.json."
  echo "  Ensure any local edits to those files were committed, stashed, or copied first."
  echo "  Review the resulting diff before committing."
fi

archived=""
if [ "$adopt_mode" -eq 1 ]; then
  # Move originals out of the copy's way so /adopt can merge them later — without this they
  # would be overwritten by the template versions and lost from the working tree.
  for f in $brownfield_collisions; do
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
  if [ -f "$tgt/.claude/settings.json" ]; then
    mkdir -p "$tgt/.claude/.state"
    cp "$tgt/.claude/settings.json" "$tgt/.claude/.state/settings.json.pre-update"
    echo "  saved pre-update settings: .claude/.state/settings.json.pre-update"
  fi
  # Snapshot consumer-owned content files; restored after the copy.
  snapshot="$(mktemp -d)"
  for f in $protected; do
    if [ -f "$tgt/$f" ]; then
      mkdir -p "$snapshot/$(dirname "$f")"
      cp -p "$tgt/$f" "$snapshot/$f"
    fi
  done
  mkdir -p "$snapshot/skill-state/.claude"
  [ -d "$tgt/.claude/skills" ] && cp -r "$tgt/.claude/skills" "$snapshot/skill-state/.claude/"
  [ -d "$tgt/.claude/disabled-skills" ] && cp -r "$tgt/.claude/disabled-skills" "$snapshot/skill-state/.claude/"
  if [ ! -d "$tgt/.claude/framework-update-backup/skills" ] && [ -d "$tgt/.claude/skills" ]; then mkdir -p "$tgt/.claude/framework-update-backup"; cp -r "$tgt/.claude/skills" "$tgt/.claude/framework-update-backup/"; fi
fi

shopt -s dotglob nullglob 2>/dev/null || true
for entry in "$src"/*; do
  name="$(basename "$entry")"
  case "$name" in
    # Template-repo meta files that must never land in (or overwrite their namesakes in) a consumer repo.
    .git|.template-repo|README.md|CHANGELOG.md|.gitignore|.gitattributes|LICENSES|NOTICE-ai-tech-lead.md) continue ;;
  esac
  if [ "$name" != docs ]; then cp -r "$entry" "$tgt"/; fi
done
# Copy docs normally except for the consumer-owned wiki index, which is copy-if-absent.
if [ -d "$src/docs" ]; then
  mkdir -p "$tgt/docs"
  for entry in "$src/docs"/*; do
    name="$(basename "$entry")"
    if [ "$name" != wiki ]; then cp -r "$entry" "$tgt/docs"/; fi
  done
  if [ -d "$src/docs/wiki" ]; then
    mkdir -p "$tgt/docs/wiki"
    for entry in "$src/docs/wiki"/*; do
      name="$(basename "$entry")"
      if [ "$name" = INDEX.md ] && [ -e "$tgt/docs/wiki/INDEX.md" ]; then continue; fi
      cp -r "$entry" "$tgt/docs/wiki"/
    done
  fi
fi
# Explicit legal-file policy above owns these paths; keeping them out of both protected and the bulk
# copy lets the notice travel on update without asserting ownership over consumer collisions.
mkdir -p "$tgt/$(dirname "$legal_license")"
if [ "$copy_legal_license" -eq 1 ]; then cp "$src/$legal_license" "$tgt/$legal_license"; fi
cp "$src/$legal_notice" "$tgt/$legal_notice"
# The installer is meta — don't ship it into the consumer repo. template-ci.yml is the TEMPLATE
# repo's own CI (hook suite + framework checks on push); consumers get the same framework checks
# via docs-sync-check -> template-checks, wired into their own CI.
rm -f "$tgt/scripts/install.sh" "$tgt/scripts/install.ps1" "$tgt/.github/workflows/template-ci.yml"

if [ "$update_mode" -eq 1 ] && [ -n "$snapshot" ]; then
  for f in $protected; do
    if [ -f "$snapshot/$f" ]; then cp -p "$snapshot/$f" "$tgt/$f"; fi
  done
  if [ -d "$snapshot/skill-state/.claude/skills" ]; then
    for old in "$snapshot/skill-state/.claude/skills"/*; do [ -d "$old" ]||continue;name=$(basename "$old");old_file="$old/SKILL.md";dest="$tgt/.claude/skills/$name";[ -f "$old_file" ]||continue;if grep -Eq '^origin:[[:space:]]*discovered[[:space:]]*$' "$old_file";then rm -rf "$dest";cp -r "$old" "$dest";continue;fi;exemplar=$(grep -E '^For a concrete current instance in this repo, see .+$' "$old_file"|head -1||true);if [ -n "$exemplar" ]&&[ -f "$dest/SKILL.md" ];then sed -i.bak '/^For a concrete current instance in this repo, see .\+$/d' "$dest/SKILL.md";rm -f "$dest/SKILL.md.bak";printf '\n%s\n' "$exemplar">>"$dest/SKILL.md";fi;done
  fi
  # `|| true` is load-bearing under `set -euo pipefail`: NO disabled-skill heading is the normal
  # case, and a no-match grep returns 1, which pipefail promotes to a pipeline failure and -e turns
  # into an abort of the whole installer. That aborted every UPDATE here -- past the file copy but
  # before the "Done (update)" banner -- so consumers saw a silent exit 1 on a good install while
  # the .ps1 twin exited 0. Do not remove it to "simplify".
  if [ -f "$snapshot/LEARNINGS.md" ]; then { grep -E '^## Disabled framework skill:[[:space:]]*[a-z0-9-]+[[:space:]]*$' "$snapshot/LEARNINGS.md" || true; }|sed -E 's/^## Disabled framework skill:[[:space:]]*//'|while read -r name;do active="$tgt/.claude/skills/$name";inactive="$tgt/.claude/disabled-skills/$name";if [ -d "$active" ];then mkdir -p "$(dirname "$inactive")";rm -rf "$inactive";mv "$active" "$inactive";fi;done;fi
  # Same -e hazard: a bare `[ -d ... ] && cp` is a STATEMENT, so a false test is a non-zero status
  # and aborts. Written as an if, it is a condition and cannot.
  rm -rf "$tgt/.github/skills";mkdir -p "$tgt/.github/skills";if [ -d "$tgt/.claude/skills" ];then cp -r "$tgt/.claude/skills"/* "$tgt/.github/skills/";fi
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
  "nextStep": "/adopt - a developer types it in a session, OR an agent runs it headless (read .claude/commands/adopt.md and follow its Headless mode, or use .github/prompts/adopt.prompt.md with a --headless directive). Headless prepares an adopt-ai-framework PR branch for human review; it does not auto-merge discovered content.",
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
if [ "$git_hooks" -eq 1 ]; then bash "$tgt/scripts/setup-git-hooks.sh" --target "$tgt"; fi
echo
echo "Each developer should run  bash scripts/framework-doctor.sh  once on their own machine."
if [ "$update_mode" -eq 1 ]; then
  echo "Done (update). Framework-owned machinery refreshed; the listed protected paths were restored; .claude/settings.json was backed up and refreshed."
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
  echo "  4. Review the generated CLAUDE.md - it is the source of truth that drives every tool."
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
