# PowerShell behavioral coverage formerly mixed into the cross-shell parity suite.
if (-not (Get-Command Invoke-Hook -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$hooks = (Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks')).Path

function Invoke-BoyScoutHook {
    param([string]$Path, [string]$Json, [string]$Mode = '')
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Path)
    if ($Mode) { $arguments += @('-Mode', $Mode) }
    Invoke-RawProcess -FileName (Get-PsExe) -Arguments $arguments -Stdin $Json
}

function New-BoyScoutFixture([string]$PowerShellHook) {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('boymode-' + [guid]::NewGuid().ToString('N'))
    $repo = Join-Path $dir 'repo'
    $installedHooks = Join-Path $repo '.claude\hooks'
    New-Item -ItemType Directory -Path $installedHooks -Force | Out-Null
    Copy-Item -LiteralPath $PowerShellHook -Destination (Join-Path $installedHooks 'boy-scout-check.ps1')
    git -C $repo init --quiet
    [IO.File]::WriteAllText(
        (Join-Path $repo 'EfQuery.cs'),
        "using Microsoft.EntityFrameworkCore;`nclass EfQuery { async Task Run(DbSet<string> rows) => await rows.ToListAsync(); }")
    [pscustomobject]@{ Dir = $dir; Repo = $repo; Hooks = $installedHooks }
}

Reset-Tests

# Every shipped PowerShell hook must degrade safely on empty and malformed input. Running from a
# throwaway directory also proves incidental relative writes do not depend on the framework source tree.
$subjects = @(Get-ChildItem -LiteralPath $hooks -Filter *.ps1 -File | Sort-Object Name)
if ($subjects.Count -eq 0) { throw 'PowerShell hook discovery returned zero subjects' }
$cwd = Join-Path ([IO.Path]::GetTempPath()) ('pshookcwd-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $cwd -Force | Out-Null
Push-Location $cwd
try {
    foreach ($subject in $subjects) {
        It "$($subject.Name) degrades safely on empty and malformed stdin" {
            foreach ($inputText in @('', 'not json {')) {
                $result = Invoke-Hook $subject.FullName $inputText
                Assert ($result.Exit -eq 0) "input '$inputText': $($subject.Name) exited $($result.Exit): $($result.Err)"
            }
        }
    }
} finally {
    Pop-Location
    Remove-Item -LiteralPath $cwd -Recurse -Force -ErrorAction SilentlyContinue
}

$boyScout = Join-Path $hooks 'boy-scout-check.ps1'
if (-not (Test-Path -LiteralPath $boyScout) -or -not ((Get-Content -Raw -LiteralPath $boyScout) -match 'read-style EF Core query')) {
    Skip 'boy-scout EF evidence gate' 'distribution does not carry the .NET boy-scout heuristic'
} else {
    $boyCases = @(
        @{ Name = 'Mongo ToListAsync has zero findings'; File = 'MongoQuery.cs'; Content = "using MongoDB.Driver;`nclass MongoQuery { async Task Run(IMongoCollection<string> c) => await c.Find(Builders<string>.Filter.Empty).ToListAsync(); }"; Expected = $false },
        @{ Name = 'EF ToListAsync without AsNoTracking flags'; File = 'EfQuery.cs'; Content = "using Microsoft.EntityFrameworkCore;`nclass EfQuery { async Task Run(DbSet<string> rows) => await rows.ToListAsync(); }"; Expected = $true }
    )
    if ($boyCases.Count -eq 0) { throw 'boy-scout case table is empty' }
    foreach ($case in $boyCases) {
        It "boy-scout scan: $($case.Name)" {
            $dir = Join-Path ([IO.Path]::GetTempPath()) ('boyfix-' + [guid]::NewGuid().ToString('N'))
            $repo = Join-Path $dir 'repo'
            $installedHooks = Join-Path $repo '.claude\hooks'
            New-Item -ItemType Directory -Path $installedHooks -Force | Out-Null
            Copy-Item -LiteralPath $boyScout -Destination (Join-Path $installedHooks 'boy-scout-check.ps1')
            git -C $repo init --quiet
            [IO.File]::WriteAllText((Join-Path $repo $case.File), $case.Content)
            Push-Location $dir
            try {
                $queue = Join-Path $repo '.claude\.state\boy-scout-queue'
                $result = Invoke-BoyScoutHook (Join-Path $installedHooks 'boy-scout-check.ps1') '{}' 'scan'
                $queueExists = Test-Path -LiteralPath $queue
                $deduplicated = Invoke-BoyScoutHook (Join-Path $installedHooks 'boy-scout-check.ps1') '{}' 'scan'
                $hasFinding = $result.Out -match 'read-style EF Core query'
                $emitted = -not [string]::IsNullOrWhiteSpace($result.Out)
                Assert ($result.Exit -eq 0) "scan failed: $($result.Err)"
                Assert ($hasFinding -eq $case.Expected) "finding expected=$($case.Expected), actual=$hasFinding, output='$($result.Out)'"
                Assert ($queueExists -eq $emitted) "queue presence must match emission: emitted=$emitted queue=$queueExists"
                Assert ($result.Out -notmatch 'decision') 'scan output contained forbidden decision property'
                if ($case.Expected) {
                    $json = $result.Out | ConvertFrom-Json
                    Assert ($json.additionalContext -match 'Boy Scout candidates') 'Copilot top-level additionalContext missing'
                    Assert ($json.hookSpecificOutput.hookEventName -eq 'UserPromptSubmit') 'Copilot hook event shape wrong'
                    Assert ([string]::IsNullOrWhiteSpace($deduplicated.Out)) "unchanged finding set was not deduplicated: '$($deduplicated.Out)'"
                }
            } finally { Pop-Location; Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    It 'boy-scout deliver emits queued Copilot context and consumes the queue' {
        $fixture = New-BoyScoutFixture $boyScout
        $queue = Join-Path $fixture.Repo '.claude\.state\boy-scout-queue'
        New-Item -ItemType Directory -Path (Split-Path -Parent $queue) -Force | Out-Null
        Push-Location $fixture.Dir
        try {
            [IO.File]::WriteAllText($queue, 'queued Boy Scout candidates')
            $result = Invoke-BoyScoutHook (Join-Path $fixture.Hooks 'boy-scout-check.ps1') '{}' 'deliver'
            $json = $result.Out | ConvertFrom-Json
            Assert ($result.Exit -eq 0) "deliver failed: $($result.Err)"
            Assert ($json.additionalContext -eq 'queued Boy Scout candidates') 'deliver additionalContext differs'
            Assert ($json.hookSpecificOutput.hookEventName -eq 'UserPromptSubmit') 'deliver event shape wrong'
            Assert (-not (Test-Path -LiteralPath $queue)) 'deliver did not consume the queue'
            Assert ($result.Out -notmatch 'decision') 'deliver output contained forbidden decision property'
        } finally { Pop-Location; Remove-Item -LiteralPath $fixture.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'boy-scout deliver with no queue never scans or speaks' {
        $fixture = New-BoyScoutFixture $boyScout
        Push-Location $fixture.Dir
        try {
            $result = Invoke-BoyScoutHook (Join-Path $fixture.Hooks 'boy-scout-check.ps1') '{}' 'deliver'
            Assert ($result.Exit -eq 0) "queue-less deliver exited $($result.Exit)"
            Assert ([string]::IsNullOrEmpty($result.Out)) "queue-less deliver scanned or spoke: '$($result.Out)'"
        } finally { Pop-Location; Remove-Item -LiteralPath $fixture.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'boy-scout Claude Stop payload emits Claude context' {
        $fixture = New-BoyScoutFixture $boyScout
        Push-Location $fixture.Dir
        try {
            $result = Invoke-BoyScoutHook (Join-Path $fixture.Hooks 'boy-scout-check.ps1') '{"hook_event_name":"Stop"}'
            $json = $result.Out | ConvertFrom-Json
            Assert ($result.Exit -eq 0) "Claude mode exited $($result.Exit)"
            Assert ($json.hookSpecificOutput.hookEventName -eq 'Stop') 'Claude event shape wrong'
            Assert (-not [string]::IsNullOrWhiteSpace($json.systemMessage)) 'Claude systemMessage missing'
            Assert ($result.Out -notmatch 'decision') 'Claude output contained forbidden decision property'
        } finally { Pop-Location; Remove-Item -LiteralPath $fixture.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

$sessionStart = Join-Path $hooks 'session-start.ps1'
$securityHeader = "| ID | Severity | Status | Found | Due | Issue |`n|---|---|---|---|---|---|"
$securityOpenLine = '- **Security:** 1 open finding(s) in SECURITY_FINDINGS.md.'
$securityOverdueLine = '- 🔴 **Security:** 1 overdue finding(s) in SECURITY_FINDINGS.md. Remediation SLA breached — review before starting new work.'
$securityCases = @(
    @{ Name = 'no open findings'; Rows = ''; Eof = $false; Line = $null },
    @{ Name = 'one open finding'; Rows = "`n| SF-1 | High | Open | 2026-01-01 | 2099-01-01 | x |"; Eof = $false; Line = $securityOpenLine },
    @{ Name = 'one overdue finding at EOF'; Rows = "`n| SF-EOF | High | Open | 2000-01-01 | 2000-01-02 | x |"; Eof = $true; Line = $securityOverdueLine }
)
if ($securityCases.Count -eq 0) { throw 'security-preload case table is empty' }
foreach ($case in $securityCases) {
    It "session-start security preload: $($case.Name), clean stderr" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ('ssfix-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Push-Location $dir
        try {
            $securityPath = Join-Path $dir 'SECURITY_FINDINGS.md'
            $suffix = if ($case.Eof) { '' } else { "`n" }
            [IO.File]::WriteAllText($securityPath, ($securityHeader + $case.Rows + $suffix), [Text.UTF8Encoding]::new($false))
            $bytes = [IO.File]::ReadAllBytes($securityPath)
            $result = Invoke-Hook $sessionStart '{"hook_event_name":"SessionStart"}'
            if ($case.Eof) { Assert ($bytes.Length -gt 0 -and $bytes[-1] -eq 124) 'overdue fixture did not end exactly at byte 0x7C' }
            Assert ($result.Exit -eq 0) "session-start exited $($result.Exit)"
            Assert ([string]::IsNullOrWhiteSpace($result.Err)) "stderr not clean: '$($result.Err)'"
            $lines = @(($result.Out -split "`n") | Where-Object { $_ -match '^- (?:🔴 )?\*\*Security:\*\*' })
            $expectedCount = if ($null -eq $case.Line) { 0 } else { 1 }
            Assert ($lines.Count -eq $expectedCount) "security line count mismatch: expected=$expectedCount actual=$($lines.Count)"
            if ($case.Line) { Assert ($lines[0] -eq $case.Line) "security class/text drift: $($lines[0])" }
        } finally { Pop-Location; Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

exit (Write-TestSummary 'PowerShellSemantics.Tests')
