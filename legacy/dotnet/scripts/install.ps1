# Install the AI Tech Lead Framework into a target repository.
# Usage: pwsh scripts/install.ps1 C:\path\to\target-repo
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
param([Parameter(Mandatory = $true)][string]$Target)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Target -PathType Container)) { Write-Error "Target '$Target' is not a directory."; exit 2 }

$src = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$tgt = (Resolve-Path $Target).Path
if ($tgt -eq $src) { Write-Error "Target is the template repo itself — choose a different target."; exit 2 }

# Template-repo meta files that must never land in (or overwrite their namesakes in) a consumer repo.
$metaFiles = @('.git', '.template-repo', 'README.md', 'CHANGELOG.md', '.gitignore', '.gitattributes')

# Consumer files the copy below would otherwise clobber. Brownfield: archived so /adopt can merge
# them. Update: snapshotted and restored — after bootstrap/adopt the consumer owns their content.
$protected = @('CLAUDE.md', 'AGENTS.md', 'TECH_DEBT.md', 'SECURITY_FINDINGS.md', 'LEARNINGS.md',
    'FRAMEWORK-CONTEXT.md', '.github/copilot-instructions.md', 'docs/ARCHITECTURE.md')

# Signals that the target already has AI tooling and therefore needs /adopt, not /bootstrap
# (mirrors /adopt Phase 1 discovery).
$adoptionSignals = @('CLAUDE.md', 'AGENTS.md', 'GEMINI.md', '.cursorrules', '.cursor/rules',
    '.clinerules', '.windsurfrules', '.roomodes', '.aider.conf.yml', '.continue',
    '.github/copilot-instructions.md', '.github/instructions', '.github/chatmodes',
    'docs/adr', 'docs/decisions', 'ARCHITECTURE.md', 'docs/ARCHITECTURE.md', 'CODEMAP.md',
    'CONVENTIONS.md', 'docs/CONVENTIONS.md', 'TECH_DEBT.md', 'TODO.md', 'BACKLOG.md')

$updateMode = Test-Path -LiteralPath (Join-Path $tgt '.claude/framework-version.json')
$detected = @()
if (-not $updateMode) {
    $detected = @($adoptionSignals | Where-Object { Test-Path -LiteralPath (Join-Path $tgt $_) })
}
$adoptMode = (-not $updateMode) -and ($detected.Count -gt 0)

Write-Output "Installing AI Tech Lead Framework"
Write-Output "  from: $src"
Write-Output "  into: $tgt"
if ($updateMode)    { Write-Output "  mode: update (existing install detected via .claude/framework-version.json)" }
elseif ($adoptMode) { Write-Output "  mode: brownfield (pre-existing AI tooling detected: $($detected -join ', '))" }
else                { Write-Output "  mode: greenfield" }

$archived = @()
if ($adoptMode) {
    # Move originals out of the copy's way so /adopt can merge them later — without this they
    # would be overwritten by the template versions and lost from the working tree.
    foreach ($f in $protected) {
        $orig = Join-Path $tgt $f
        if (Test-Path -LiteralPath $orig -PathType Leaf) {
            $rel  = 'docs/pre-adoption/' + $f.TrimStart('.')
            $dest = Join-Path $tgt $rel
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
            Move-Item -Force -LiteralPath $orig -Destination $dest
            $archived += $rel
            Write-Output "  archived: $f -> $rel"
        }
    }
}

$snapshot = $null
if ($updateMode) {
    # Snapshot consumer-owned content files; restored after the copy.
    $snapshot = Join-Path ([IO.Path]::GetTempPath()) ('ai-tech-lead-update-' + [IO.Path]::GetRandomFileName())
    foreach ($f in $protected) {
        $orig = Join-Path $tgt $f
        if (Test-Path -LiteralPath $orig -PathType Leaf) {
            $dest = Join-Path $snapshot $f
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
            Copy-Item -Force -LiteralPath $orig -Destination $dest
        }
    }
}

Get-ChildItem -Force -LiteralPath $src |
    Where-Object { $_.Name -notin $metaFiles } |
    ForEach-Object { Copy-Item -Recurse -Force -LiteralPath $_.FullName -Destination $tgt }

# The installer is meta — don't ship it into the consumer repo.
foreach ($f in @('scripts/install.sh', 'scripts/install.ps1')) {
    Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath (Join-Path $tgt $f)
}

if ($updateMode -and $snapshot -and (Test-Path -LiteralPath $snapshot)) {
    foreach ($f in $protected) {
        $saved = Join-Path $snapshot $f
        if (Test-Path -LiteralPath $saved -PathType Leaf) {
            Copy-Item -Force -LiteralPath $saved -Destination (Join-Path $tgt $f)
        }
    }
    Remove-Item -Recurse -Force -LiteralPath $snapshot
    Write-Output "  consumer-owned content files left untouched ($($protected -join ', '))."
}

if ($adoptMode) {
    # Durable adoption marker: the SessionStart hook warns every new session, and docs-sync-check
    # fails CI, until /adopt consumes it (deleted in /adopt Phase 3).
    $marker = [ordered]@{
        installedAt       = (Get-Date).ToString('yyyy-MM-dd')
        detectedArtifacts = $detected
        archivedOriginals = $archived
        nextStep          = '/adopt (developer-initiated; the model cannot invoke it)'
        _comment          = 'Written by the framework installer because pre-existing AI tooling was detected. Consolidate it with /adopt - NOT /bootstrap. /adopt deletes this file in its Phase 3.'
    }
    $marker | ConvertTo-Json | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $tgt '.claude/adoption-pending.json')
}

# Claude Code hooks default to pwsh (PowerShell 7). If it isn't installed, fall back to the Windows
# PowerShell 5.1 variant (preinstalled on every Windows box) so the hooks still fire.
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    $sj  = Join-Path $tgt '.claude/settings.json'
    $sjw = Join-Path $tgt '.claude/settings.windows.json'
    if ((Test-Path $sjw) -and (Test-Path $sj)) {
        Copy-Item -Force -LiteralPath $sjw -Destination $sj
        Write-Output "  pwsh not found - activated Windows PowerShell 5.1 hooks (settings.windows.json -> settings.json)."
    }
}

Write-Output ""
if ($updateMode) {
    Write-Output "Done (update). Framework machinery refreshed; consumer-owned content files untouched."
    Write-Output "  Next: review the diff, run  pwsh scripts/docs-sync-check.ps1 , then commit."
} elseif ($adoptMode) {
    Write-Output "Done - but this repo is NOT ready for AI-assisted work yet: it has pre-existing AI"
    Write-Output "tooling that must be consolidated with /adopt. The originals this install displaced"
    Write-Output "are under docs/pre-adoption/; .claude/adoption-pending.json records the inventory."
    Write-Output ""
    Write-Output "Next steps in the target repo:"
    Write-Output "  1. Review and commit the copied files (they are team-shared config, not local settings)."
    Write-Output "  2. A DEVELOPER must start a Claude Code session in the target repo and type:  /adopt"
    Write-Output "     - /adopt is developer-initiated: AI agents and the model CANNOT invoke it, and it"
    Write-Output "       only exists inside a session started in the target repo."
    Write-Output "     - Do NOT run /bootstrap instead - it would skip the archive/merge/provenance flow"
    Write-Output "       and the impact baseline. The SessionStart hook and docs-sync-check flag this"
    Write-Output "       repo until /adopt has run."
    Write-Output ""
    Write-Output "  IF YOU ARE AN AI AGENT running this installer: your task is NOT complete until you"
    Write-Output "  have done step 1 and then told the developer, explicitly, to start a Claude Code"
    Write-Output "  session in the target repo and type /adopt. Report that as the required manual next"
    Write-Output "  step in your final summary. Do not attempt /adopt yourself or replicate it by hand."
} else {
    Write-Output "Done. Next steps in the target repo:"
    Write-Output "  1. Review and commit the copied files (they are team-shared config, not local settings)."
    Write-Output "  2. A DEVELOPER must start a Claude Code session in the target repo and type:  /bootstrap"
    Write-Output "     (developer-initiated: AI agents and the model CANNOT invoke it. If you are an AI"
    Write-Output "     agent running this installer, report that as the required manual next step in your"
    Write-Output "     final summary - do not attempt /bootstrap yourself.)"
    Write-Output "  3. After /bootstrap, verify:  pwsh scripts/docs-sync-check.ps1"
    Write-Output "  4. Review the generated CLAUDE.md - it is the source of truth that drives every tool."
}
