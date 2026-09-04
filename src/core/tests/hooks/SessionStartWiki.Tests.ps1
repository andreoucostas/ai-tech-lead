if (-not (Get-Command Invoke-Hook -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$hooks = (Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks')).Path
$subject = Join-Path $hooks 'session-start.ps1'

function Invoke-SessionStartAt($root, $json) {
    Push-Location $root
    try { Invoke-Hook $subject $json } finally { Pop-Location }
}

function New-WikiRoot([int]$count) {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('session-wiki-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Force (Join-Path $root 'docs/wiki') | Out-Null
    if ($count -ge 0) {
        $entries = 1..$count | ForEach-Object { "- [gotcha] [entry-$_](./entry-$_.md) — fact $_" }
        [IO.File]::WriteAllText(
            (Join-Path $root 'docs/wiki/INDEX.md'),
            "# Team Wiki Index`n$($entries -join "`n")",
            [Text.UTF8Encoding]::new($false))
    }
    $root
}

$claude = '{"hook_event_name":"SessionStart"}'
$copilot = '{"timestamp":1}'
Reset-Tests

It 'writes a parseable ISO-8601 UTC liveness record' {
    $root = New-WikiRoot -1
    try {
        $result = Invoke-SessionStartAt $root $claude
        $record = Join-Path $root '.claude/.state/last-session-start'
        Assert ($result.Exit -eq 0) 'hook crashed'
        Assert (Test-Path -LiteralPath $record) 'liveness record absent'
        $stamp = [IO.File]::ReadAllText($record)
        $parsed = [datetimeoffset]::MinValue
        $valid = [datetimeoffset]::TryParse($stamp, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed)
        Assert $valid "not parseable ISO-8601: $stamp"
        Assert ($stamp -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$') "not ISO-8601 UTC: $stamp"
        Assert ($parsed.Offset -eq [TimeSpan]::Zero) "not UTC: $stamp"
    } finally { Remove-Item -Recurse -Force $root }
}

It 'soft-fails when the liveness path is unwritable' {
    $root = New-WikiRoot -1
    try {
        New-Item -ItemType Directory -Force (Join-Path $root '.claude') | Out-Null
        [IO.File]::WriteAllText((Join-Path $root '.claude/.state'), 'path collision', [Text.UTF8Encoding]::new($false))
        $result = Invoke-SessionStartAt $root $claude
        Assert ($result.Exit -eq 0) "hook failed: $($result.Err)"
        Assert ($result.Out -match '## Session preload') 'normal preload output absent'
    } finally { Remove-Item -Recurse -Force $root }
}

It 'small index is inlined' {
    $root = New-WikiRoot 2
    try { Assert ((Invoke-SessionStartAt $root $claude).Out -match 'entry-2') 'small index absent' }
    finally { Remove-Item -Recurse -Force $root }
}

It 'large index is summarized' {
    $root = New-WikiRoot 31
    try {
        $result = Invoke-SessionStartAt $root $claude
        Assert ($result.Out -match '31 wiki entries — read docs/wiki/INDEX.md') 'summary absent'
        Assert ($result.Out -notmatch 'entry-31') 'large index leaked'
    } finally { Remove-Item -Recurse -Force $root }
}

It 'missing index is silent' {
    $root = New-WikiRoot -1
    try {
        $missingResult = Invoke-SessionStartAt $root $claude
        Assert ($missingResult.Out -notmatch 'entry-|wiki entries|Team Wiki Index') "wiki output present: [$($missingResult.Out)]"
    }
    finally { Remove-Item -Recurse -Force $root }
}

It 'Copilot JSON contains a small wiki in both additionalContext shapes' {
    $root = New-WikiRoot 2
    try {
        $json = (Invoke-SessionStartAt $root $copilot).Out | ConvertFrom-Json
        Assert ($json.additionalContext -match 'entry-2') 'top-level missing'
        Assert ($json.hookSpecificOutput.additionalContext -match 'entry-2') 'wrapped missing'
    } finally { Remove-Item -Recurse -Force $root }
}

It 'Copilot JSON contains a large summary in both additionalContext shapes' {
    $root = New-WikiRoot 31
    try {
        $json = (Invoke-SessionStartAt $root $copilot).Out | ConvertFrom-Json
        Assert ($json.additionalContext -match '31 wiki entries') 'top-level missing'
        Assert ($json.hookSpecificOutput.additionalContext -match '31 wiki entries') 'wrapped missing'
    } finally { Remove-Item -Recurse -Force $root }
}

exit (Write-TestSummary 'SessionStartWiki.Tests')
