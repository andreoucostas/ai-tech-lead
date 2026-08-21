# Recurrence tests for B-100's opt-in staged-content convenience net.
param([ValidateSet('', 'bom', 'guard', 'staged', 'clean')][string]$RedTest = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
Reset-Tests

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$checkerSource = Join-Path $repoRoot '.claude\scripts\check-staged-content.ps1'
$guardSource = Join-Path $repoRoot 'src\core\.claude\hooks\guard.ps1'
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('staged-content-' + [guid]::NewGuid().ToString('N'))

function Set-Bytes([string]$Path, [string]$Text, [bool]$Bom) {
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($Bom))
}

function Invoke-Check {
    Push-Location $scratch
    try {
        $out = & (Get-Process -Id $PID).Path -NoProfile -File '.claude/scripts/check-staged-content.ps1' 2>&1
        return [pscustomobject]@{ Exit=$LASTEXITCODE; Out=($out -join "`n") }
    } finally { Pop-Location }
}

try {
    $null = New-Item -ItemType Directory -Force (Join-Path $scratch '.claude\scripts')
    $null = New-Item -ItemType Directory -Force (Join-Path $scratch 'src\core\.claude\hooks')
    Copy-Item -LiteralPath $checkerSource -Destination (Join-Path $scratch '.claude\scripts\check-staged-content.ps1')
    Copy-Item -LiteralPath $guardSource -Destination (Join-Path $scratch 'src\core\.claude\hooks\guard.ps1')
    $scratchChecker = Join-Path $scratch '.claude\scripts\check-staged-content.ps1'
    if ($RedTest -eq 'bom') {
        $text = [IO.File]::ReadAllText($scratchChecker)
        $text = $text.Replace("if (`$name -match '(?i)\.ps1$' -and", "if (`$false -and `$name -match '(?i)\.ps1$' -and")
        [IO.File]::WriteAllText($scratchChecker, $text, [Text.UTF8Encoding]::new($true))
    } elseif ($RedTest -eq 'guard') {
        [IO.File]::WriteAllText((Join-Path $scratch 'src\core\.claude\hooks\guard.ps1'), 'exit 0', [Text.UTF8Encoding]::new($true))
    } elseif ($RedTest -eq 'staged') {
        $text = [IO.File]::ReadAllText($scratchChecker)
        $text = $text -replace '(?m)^\s*\$bytes = Invoke-GitBytes .+$',
            '    $bytes = [IO.File]::ReadAllBytes((Join-Path $repoRoot $name))'
        [IO.File]::WriteAllText($scratchChecker, $text, [Text.UTF8Encoding]::new($true))
    } elseif ($RedTest -eq 'clean') {
        [IO.File]::WriteAllText($scratchChecker, 'exit 1', [Text.UTF8Encoding]::new($true))
    }
    Push-Location $scratch
    try {
        & git init -q
        & git config user.email 'fixture@example.invalid'
        & git config user.name 'Fixture'
    } finally { Pop-Location }

    It 'rejects a staged BOM-less PowerShell file' {
        $path = Join-Path $scratch 'bomless.ps1'
        Set-Bytes $path "Write-Host 'fixture'`n" $false
        Push-Location $scratch; try { & git add -- bomless.ps1 } finally { Pop-Location }
        $r = Invoke-Check
        Assert ($r.Exit -ne 0) "BOM-less staged file passed: $($r.Out)"
        Assert ($r.Out -match 'no UTF-8 BOM: bomless.ps1') "finding did not name BOM-less file: $($r.Out)"
    }

    It 'rejects a staged guard pattern through the canonical guard' {
        Push-Location $scratch; try { & git reset -q } finally { Pop-Location }
        $path = Join-Path $scratch 'unsafe.cs'
        Set-Bytes $path "#pragma warning disable`n" $false
        Push-Location $scratch; try { & git add -- unsafe.cs } finally { Pop-Location }
        $r = Invoke-Check
        Assert ($r.Exit -ne 0) "guard pattern passed: $($r.Out)"
        Assert ($r.Out -match "#pragma warning disable") "canonical guard reason absent: $($r.Out)"
    }

    It 'reads the staged blob rather than an unsafe worktree replacement' {
        Push-Location $scratch; try { & git reset -q } finally { Pop-Location }
        $path = Join-Path $scratch 'staged.cs'
        Set-Bytes $path "public class Safe { }`n" $false
        Push-Location $scratch; try { & git add -- staged.cs } finally { Pop-Location }
        Set-Bytes $path "#pragma warning disable`n" $false
        $r = Invoke-Check
        Assert ($r.Exit -eq 0) "worktree content leaked into staged scan: $($r.Out)"
    }

    It 'allows clean staged content' {
        Push-Location $scratch; try { & git reset -q } finally { Pop-Location }
        $path = Join-Path $scratch 'clean.ps1'
        Set-Bytes $path "Write-Host 'clean'`n" $true
        Push-Location $scratch; try { & git add -- clean.ps1 } finally { Pop-Location }
        $r = Invoke-Check
        Assert ($r.Exit -eq 0) "clean staged content failed: $($r.Out)"
    }
} finally {
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}

exit (Write-TestSummary 'StagedContent.Tests (B-100 staged snapshot scan)')
