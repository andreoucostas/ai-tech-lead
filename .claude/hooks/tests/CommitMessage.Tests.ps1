# Recurrence tests for the opt-in maintainer commit-msg hook (B-87).
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
Reset-Tests

$repo = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$validator = Join-Path $repo '.claude\scripts\check-commit-subject.ps1'
$scratch = @()

function Invoke-SubjectCheck {
    param([string]$Subject)
    $message = Join-Path ([IO.Path]::GetTempPath()) ('commit-message-' + [guid]::NewGuid().ToString('N'))
    $script:scratch += $message
    [IO.File]::WriteAllText($message, "$Subject`n", (New-Object Text.UTF8Encoding($false)))
    $out = & (Get-Process -Id $PID).Path -NoProfile -File $validator $message 2>&1
    [pscustomobject]@{ Exit = $LASTEXITCODE; Out = ($out -join "`n") }
}

try {
    It 'rejects the observed literal-at corruption' {
        $r = Invoke-SubjectCheck '@'
        Assert ($r.Exit -ne 0) "literal @ unexpectedly passed: $($r.Out)"
        Assert ($r.Out -match 'degenerate') "literal @ did not explain the rejection: $($r.Out)"
    }
    It 'rejects a punctuation-only subject longer than the minimum' {
        $r = Invoke-SubjectCheck '--- !!! ???'
        Assert ($r.Exit -ne 0) "punctuation-only subject unexpectedly passed: $($r.Out)"
        Assert ($r.Out -match 'punctuation') "punctuation-only rejection was not identified: $($r.Out)"
    }
    It 'rejects a short alphanumeric subject' {
        $r = Invoke-SubjectCheck 'Fix typo'
        Assert ($r.Exit -ne 0) "short subject unexpectedly passed: $($r.Out)"
        Assert ($r.Out -match '10 characters') "short-subject rejection was not identified: $($r.Out)"
    }
    It 'rejects the release MSYS-path corruption signature' {
        $r = Invoke-SubjectCheck 'C:/Program Files/Git/bootstrap and /adopt docs'
        Assert ($r.Exit -ne 0) "MSYS-mangled subject unexpectedly passed: $($r.Out)"
        Assert ($r.Out -match 'MSYS') "MSYS rejection was not identified: $($r.Out)"
    }
    It 'accepts a realistic subject from this repository history' {
        $r = Invoke-SubjectCheck 'B-55: a superseded vendor claim can no longer survive in a composed dist'
        Assert ($r.Exit -eq 0) "realistic subject was rejected: $($r.Out)"
    }
} finally {
    foreach ($path in $scratch) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
}

exit (Write-TestSummary 'CommitMessage.Tests (B-87 commit subject guard)')
