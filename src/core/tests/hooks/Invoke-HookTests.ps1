# Suite entry point -- runs every *.Tests.ps1 in this directory as an isolated pwsh process and
# exits with the TOTAL number of failures (0 = green). Each test file degrades-safe: .sh twin tests
# self-skip when no bash is present, so this is safe to run on a pure-Windows or pure-*nix host.
# Usage:  pwsh -NoProfile -File tests/hooks/Invoke-HookTests.ps1
$ErrorActionPreference = 'Stop'
# Prefer pwsh (7+); fall back to Windows PowerShell 5.1 where pwsh is absent (5.1-safe if/else).
if (Get-Command pwsh -ErrorAction SilentlyContinue) { $psExe = 'pwsh' } else { $psExe = 'powershell' }
$files = Get-ChildItem -LiteralPath $PSScriptRoot -Filter *.Tests.ps1 | Sort-Object Name
$total = 0
foreach ($f in $files) {
    Write-Host ("--- {0} ---" -f $f.Name)
    & $psExe -NoProfile -ExecutionPolicy Bypass -File $f.FullName
    $total += [int]$LASTEXITCODE
}
Write-Host ("=== Hook test suite: {0} failure(s) across {1} file(s) ===" -f $total, $files.Count)
exit $total
