# Install the AI Tech Lead Framework into a target repository.
# Usage: pwsh scripts/install.ps1 C:\path\to\target-repo
#
# Copies the template's framework files into the target, EXCLUDING the .git directory, the
# .template-repo marker (which would disable the consumer's CI guardrail), and the installer itself.
# Safe to re-run to update an existing install.
param([Parameter(Mandatory = $true)][string]$Target)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Target -PathType Container)) { Write-Error "Target '$Target' is not a directory."; exit 2 }

$src = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$tgt = (Resolve-Path $Target).Path
if ($tgt -eq $src) { Write-Error "Target is the template repo itself — choose a different target."; exit 2 }

Write-Output "Installing AI Tech Lead Framework"
Write-Output "  from: $src"
Write-Output "  into: $tgt"

Get-ChildItem -Force -LiteralPath $src |
    Where-Object { $_.Name -notin @('.git', '.template-repo') } |
    ForEach-Object { Copy-Item -Recurse -Force -LiteralPath $_.FullName -Destination $tgt }

# The installer is meta — don't ship it into the consumer repo.
foreach ($f in @('scripts/install.sh', 'scripts/install.ps1')) {
    Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath (Join-Path $tgt $f)
}

Write-Output ""
Write-Output "Done. Next steps in the target repo:"
Write-Output "  1. Review the copied files (commit them — they are team-shared config, not local settings)."
Write-Output "  2. Existing AI tooling (CLAUDE.md / .cursorrules / Copilot instructions / ADRs)?  run  /adopt"
Write-Output "     Greenfield (nothing AI-related yet)?                                            run  /bootstrap"
Write-Output "  3. Verify the install:  pwsh scripts/docs-sync-check.ps1"
Write-Output "  4. Review the generated CLAUDE.md — it is the source of truth that drives every tool."
