# Asserts that every .ps1 in the repo carries a UTF-8 BOM (repo-wide sweep: src/, scripts/,
# .claude/, dist/). Invariant #4: Windows PowerShell 5.1 mis-parses BOM-less UTF-8; this gate
# catches .ps1 files that escape the bom-fix hook (hand-created outside a hooked session) or
# land in dirs no per-dist template-checks sweep covers (scripts/, .claude/, src/ fragments).
# Wired into release.ps1 via Invoke-HookTests.ps1 auto-discovery. Does NOT ship.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path   # the ai-tech-lead repo root

function Test-HasBom { param($path) $b=[IO.File]::ReadAllBytes($path); ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) }

Reset-Tests

It 'every .ps1 in the repo carries a UTF-8 BOM (invariant #4)' {
    # -File matters: snippet DIRECTORIES are named after their target file (e.g.
    # src/stacks/<s>/snippets/.claude/hooks/audit-trail.ps1/ is a dir of marker snippets).
    $all     = Get-ChildItem -LiteralPath $repoRoot -Recurse -File -Filter *.ps1 | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }
    Assert ($all.Count -gt 0) "enumeration found no .ps1 under $repoRoot — sweep is broken (vacuous pass)"
    $missing = $all | Where-Object { -not (Test-HasBom $_.FullName) }
    if ($missing) {
        $rel = $missing | ForEach-Object { $_.FullName.Substring($repoRoot.Length).TrimStart('\','/') }
        Assert $false ("BOM missing in: " + ($rel -join ', '))
    } else {
        Assert $true 'all files have BOMs'
    }
}

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("workspacebom-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    It 'Test-HasBom returns $false for a BOM-less .ps1 (positive control)' {
        $f = Join-Path $tmp 'nobom.ps1'
        [IO.File]::WriteAllText($f, "exit 0`n", (New-Object System.Text.UTF8Encoding($false)))
        Assert (-not (Test-HasBom $f)) 'Test-HasBom should return $false for a BOM-less file'
    }
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Write-TestSummary 'WorkspaceBom.Tests (repo-wide BOM gate)')
