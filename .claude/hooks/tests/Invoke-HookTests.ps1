# Suite entry point (root meta-dev) -- runs every *.Tests.ps1 here as an isolated pwsh process and
# exits with the TOTAL number of failures (0 = green). Mirrors the dist tests/hooks runner.
# Carries: MetaHooks (bom-fix) + WorkspaceBom, and the B-33 gates -- ComposerFixtures,
# SiblingDrift, SrcHygiene, RoutePromptUnion.
# Usage:  pwsh -NoProfile -File .claude/hooks/tests/Invoke-HookTests.ps1
$ErrorActionPreference = 'Stop'
if (Get-Command pwsh -ErrorAction SilentlyContinue) { $psExe = 'pwsh' } else { $psExe = 'powershell' }
$files = Get-ChildItem -LiteralPath $PSScriptRoot -Filter *.Tests.ps1 | Sort-Object Name
$total = 0
foreach ($f in $files) {
    Write-Host ("--- {0} ---" -f $f.Name)
    & $psExe -NoProfile -ExecutionPolicy Bypass -File $f.FullName
    $total += [int]$LASTEXITCODE
}
Write-Host ("=== Meta-hook test suite: {0} failure(s) across {1} file(s) ===" -f $total, $files.Count)
exit $total
