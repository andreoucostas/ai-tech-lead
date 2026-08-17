# Authoring-repo-only drift gate: the shipped licence source must remain byte-identical to the root
# LICENSE after LF normalisation. This deliberately lives in the META suite, not template-checks:
# template-checks runs inside every CONSUMER repo, where the authoring repo's root LICENSE does not
# exist, so putting this condition there would make consumers fail a check only maintainers can
# satisfy. Does NOT ship.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

function Get-LfBytes([string]$Path) {
    $text = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($Path))
    return [Text.Encoding]::UTF8.GetBytes(($text -replace "`r`n", "`n" -replace "`r", "`n"))
}

Reset-Tests
It 'src/core licence is LF-normalised byte-identical to root LICENSE' {
    $root = Get-LfBytes (Join-Path $repoRoot 'LICENSE')
    $shipped = Get-LfBytes (Join-Path $repoRoot 'src/core/LICENSES/ai-tech-lead-MIT.txt')
    Assert ([Convert]::ToBase64String($root) -eq [Convert]::ToBase64String($shipped)) 'src/core/LICENSES/ai-tech-lead-MIT.txt differs from root LICENSE after LF normalisation'
}

exit (Write-TestSummary 'LicenseDrift.Tests')
