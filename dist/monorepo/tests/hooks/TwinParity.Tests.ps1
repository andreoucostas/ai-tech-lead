# WS-M3 (headline) -- prove each .ps1/.sh twin makes the SAME decision on the SAME input.
# The historic guard.sh regression (shipped missing guard.ps1's test-defeat blocks) would FAIL here.
# Deep parity on guard (decision-bearing); robustness parity (no-crash on empty/malformed) on every pair.
if (-not (Get-Command Invoke-Hook -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
. (Join-Path $PSScriptRoot 'fixtures\guard-cases.ps1')
$hooks   = (Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks')).Path
$guardPs = Join-Path $hooks 'guard.ps1'
$guardSh = Join-Path $hooks 'guard.sh'
$bash    = Get-BashPath

Reset-Tests

# --- Deep guard parity: identical decision and rendered streams from .ps1 and .sh, both surfaces ---
if (-not $bash) {
    Skip 'guard twin parity (all cases)' 'no bash found -- cannot run .sh twin on this host'
} else {
    foreach ($case in $GuardCases) {
        foreach ($surface in 'Claude','Copilot') {
            $evt = if ($surface -eq 'Claude') { New-ClaudeEvent $case.f $case.c } else { New-CopilotEvent $case.f $case.c }
            It "guard twins agree ($surface): $($case.n)" {
                $rps = Invoke-Hook $guardPs $evt
                $rsh = Invoke-Hook $guardSh $evt
                $dps = Get-Decision $rps
                $dsh = Get-Decision $rsh
                Assert ($dps -eq $dsh) "guard.ps1 -> $dps but guard.sh -> $dsh"
                Assert ($rps.Exit -eq $rsh.Exit) "guard.ps1 exit $($rps.Exit) but guard.sh exit $($rsh.Exit)"
                Assert ([string]::Equals("$($rps.Out)", "$($rsh.Out)", [StringComparison]::Ordinal)) `
                    "stdout differs: guard.ps1='$($rps.Out)' guard.sh='$($rsh.Out)'"
                Assert ([string]::Equals("$($rps.Err)", "$($rsh.Err)", [StringComparison]::Ordinal)) `
                    "stderr differs: guard.ps1='$($rps.Err)' guard.sh='$($rsh.Err)'"
            }
        }
    }
}

# --- Robustness parity for every twin pair: empty + malformed stdin must agree (and not crash) ---
# Run from a throwaway CWD so any incidental relative writes (e.g. audit log) never touch the repo.
$pairs = Get-ChildItem -LiteralPath $hooks -Filter *.ps1 | Where-Object {
    Test-Path -LiteralPath (Join-Path $hooks ($_.BaseName + '.sh'))
} | ForEach-Object { $_.BaseName } | Sort-Object

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("twincwd-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
Push-Location $tmp
try {
    foreach ($name in $pairs) {
        $ps = Join-Path $hooks "$name.ps1"; $sh = Join-Path $hooks "$name.sh"
        if (-not $bash) { Skip "$name twins agree (empty/malformed)" 'no bash found'; continue }
        It "$name twins agree on empty + malformed stdin (no crash)" {
            foreach ($inp in @('', 'not json {')) {
                $rps = Invoke-Hook $ps $inp; $rsh = Invoke-Hook $sh $inp
                Assert ($rps.Exit -eq $rsh.Exit) "input '$inp': $name.ps1 exit $($rps.Exit) != $name.sh exit $($rsh.Exit)"
                Assert ($rps.Exit -eq 0) "input '$inp': $name should degrade-safe to exit 0, got $($rps.Exit)"
            }
        }
    }
} finally {
    Pop-Location
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

# Boy Scout modes use different argument syntax across twins; keep the shared harness unchanged.
function Invoke-BoyScoutHook {
    param([string]$Path, [string]$Json, [string]$Mode = '')
    $ef = [IO.Path]::GetTempFileName()
    try {
        if ($Path -match '\.ps1$') {
            if ($Mode) {
                $out = $Json | & (Get-PsExe) -NoProfile -ExecutionPolicy Bypass -File $Path -Mode $Mode 2>$ef
            } else {
                $out = $Json | & (Get-PsExe) -NoProfile -ExecutionPolicy Bypass -File $Path 2>$ef
            }
        } else {
            $boyBash = Get-BashPath
            if (-not $boyBash) { return $null }
            if ($Mode) {
                $out = $Json | & $boyBash $Path --mode $Mode 2>$ef
            } else {
                $out = $Json | & $boyBash $Path 2>$ef
            }
        }
        return [pscustomobject]@{
            Exit = $LASTEXITCODE
            Out = ($out -join "`n")
            Err = [IO.File]::ReadAllText($ef)
        }
    } finally {
        if (Test-Path -LiteralPath $ef) { [IO.File]::Delete($ef) }
    }
}

function New-BoyScoutFixture {
    param([string]$PowerShellHook, [string]$ShellHook)
    $dir = Join-Path ([IO.Path]::GetTempPath()) ("boymode-" + [guid]::NewGuid().ToString('N'))
    $repo = Join-Path $dir 'repo'
    $installedHooks = Join-Path $repo '.claude\hooks'
    New-Item -ItemType Directory -Path $installedHooks -Force | Out-Null
    Copy-Item -LiteralPath $PowerShellHook -Destination (Join-Path $installedHooks 'boy-scout-check.ps1')
    Copy-Item -LiteralPath $ShellHook -Destination (Join-Path $installedHooks 'boy-scout-check.sh')
    git -C $repo init --quiet
    [IO.File]::WriteAllText(
        (Join-Path $repo 'EfQuery.cs'),
        "using Microsoft.EntityFrameworkCore;`nclass EfQuery { async Task Run(DbSet<string> rows) => await rows.ToListAsync(); }"
    )
    return [pscustomobject]@{ Dir = $dir; Repo = $repo; Hooks = $installedHooks }
}

# --- boy-scout EF evidence gate: Mongo-shaped async queries stay silent; EF queries still flag ---
$boyPs = Join-Path $hooks 'boy-scout-check.ps1'; $boySh = Join-Path $hooks 'boy-scout-check.sh'
if (-not (Test-Path -LiteralPath $boyPs) -or -not ((Get-Content -Raw -LiteralPath $boyPs) -match 'read-style EF Core query')) {
    Skip 'boy-scout EF evidence gate (all cases)' 'distribution does not carry the .NET boy-scout heuristic'
} elseif (-not $bash) {
    Skip 'boy-scout EF evidence gate (all cases)' 'no bash found -- cannot run .sh twin on this host'
} else {
    $boyCases = @(
        @{ n = 'Mongo ToListAsync has zero findings'; file = 'MongoQuery.cs'; content = "using MongoDB.Driver;`nclass MongoQuery { async Task Run(IMongoCollection<string> c) => await c.Find(Builders<string>.Filter.Empty).ToListAsync(); }"; expect = $false },
        @{ n = 'EF ToListAsync without AsNoTracking flags'; file = 'EfQuery.cs'; content = "using Microsoft.EntityFrameworkCore;`nclass EfQuery { async Task Run(DbSet<string> rows) => await rows.ToListAsync(); }"; expect = $true }
    )
    foreach ($case in $boyCases) {
        It "boy-scout twins agree: $($case.n)" {
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("boyfix-" + [guid]::NewGuid().ToString('N'))
            $repo = Join-Path $dir 'repo'
            $installedHooks = Join-Path $repo '.claude\hooks'
            New-Item -ItemType Directory -Path $installedHooks -Force | Out-Null
            Copy-Item -LiteralPath $boyPs -Destination (Join-Path $installedHooks 'boy-scout-check.ps1')
            Copy-Item -LiteralPath $boySh -Destination (Join-Path $installedHooks 'boy-scout-check.sh')
            git -C $repo init --quiet
            [IO.File]::WriteAllText((Join-Path $repo $case.file), $case.content)
            Push-Location $dir
            try {
                $state = Join-Path $repo '.claude\.state'
                $queue = Join-Path $state 'boy-scout-queue'
                $rps = Invoke-BoyScoutHook (Join-Path $installedHooks 'boy-scout-check.ps1') '{}' 'scan'
                $queuePs = Test-Path -LiteralPath $queue
                $dedup = Invoke-BoyScoutHook (Join-Path $installedHooks 'boy-scout-check.ps1') '{}' 'scan'
                Remove-Item -LiteralPath (Join-Path $repo '.claude\.state') -Recurse -Force -ErrorAction SilentlyContinue
                $rsh = Invoke-BoyScoutHook (Join-Path $installedHooks 'boy-scout-check.sh') '{}' 'scan'
                $queueSh = Test-Path -LiteralPath $queue
                $dedupSh = Invoke-BoyScoutHook (Join-Path $installedHooks 'boy-scout-check.sh') '{}' 'scan'
                $hasPs = $rps.Out -match 'read-style EF Core query'
                $hasSh = $rsh.Out -match 'read-style EF Core query'
                $emittedPs = -not [string]::IsNullOrWhiteSpace($rps.Out)
                $emittedSh = -not [string]::IsNullOrWhiteSpace($rsh.Out)
                Assert ($hasPs -eq $case.expect) "boy-scout.ps1 finding expected=$($case.expect), actual=$hasPs, output='$($rps.Out)'"
                Assert ($hasSh -eq $case.expect) "boy-scout.sh finding expected=$($case.expect), actual=$hasSh, output='$($rsh.Out)'"
                Assert ($queuePs -eq $emittedPs -and $queueSh -eq $emittedSh) `
                    "scan queue presence must match emission: ps1 emitted=$emittedPs queue=$queuePs; sh emitted=$emittedSh queue=$queueSh"
                Assert ($rps.Out -notmatch 'decision' -and $rsh.Out -notmatch 'decision') 'scan output contained forbidden decision property'
                if ($case.expect) {
                    $json = $rps.Out | ConvertFrom-Json
                    Assert ($json.additionalContext -match 'Boy Scout candidates') 'Copilot top-level additionalContext missing'
                    Assert ($json.hookSpecificOutput.hookEventName -eq 'UserPromptSubmit') 'Copilot hook event shape wrong'
                    Assert ($dedup.Out.Trim() -eq '' -and $dedupSh.Out.Trim() -eq '') `
                        "unchanged finding set was not deduplicated in scan mode: ps1='$($dedup.Out)' sh='$($dedupSh.Out)'"
                }
            } finally { Pop-Location; Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    It 'boy-scout twins agree: deliver emits queued Copilot context and consumes the queue' {
        $fixture = New-BoyScoutFixture $boyPs $boySh
        $queue = Join-Path $fixture.Repo '.claude\.state\boy-scout-queue'
        New-Item -ItemType Directory -Path (Split-Path -Parent $queue) -Force | Out-Null
        Push-Location $fixture.Dir
        try {
            [IO.File]::WriteAllText($queue, 'queued Boy Scout candidates')
            $rps = Invoke-BoyScoutHook (Join-Path $fixture.Hooks 'boy-scout-check.ps1') '{}' 'deliver'
            $gonePs = -not (Test-Path -LiteralPath $queue)
            [IO.File]::WriteAllText($queue, 'queued Boy Scout candidates')
            $rsh = Invoke-BoyScoutHook (Join-Path $fixture.Hooks 'boy-scout-check.sh') '{}' 'deliver'
            $goneSh = -not (Test-Path -LiteralPath $queue)
            Assert ($rps.Exit -eq $rsh.Exit -and $rps.Exit -eq 0) 'deliver exits differ or are non-zero'
            $jps = $rps.Out | ConvertFrom-Json; $jsh = $rsh.Out | ConvertFrom-Json
            Assert ($jps.additionalContext -eq $jsh.additionalContext) 'deliver additionalContext differs'
            Assert ($jps.hookSpecificOutput.hookEventName -eq 'UserPromptSubmit') 'PowerShell deliver event shape wrong'
            Assert ($jsh.hookSpecificOutput.hookEventName -eq 'UserPromptSubmit') 'shell deliver event shape wrong'
            Assert ($gonePs -and $goneSh) "deliver did not consume both queues: ps1=$gonePs sh=$goneSh"
            Assert ($rps.Out -notmatch 'decision' -and $rsh.Out -notmatch 'decision') 'deliver output contained forbidden decision property'
        } finally { Pop-Location; Remove-Item -LiteralPath $fixture.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'boy-scout regression: deliver with no queue never scans or speaks on a read-only prompt' {
        $fixture = New-BoyScoutFixture $boyPs $boySh
        $queue = Join-Path $fixture.Repo '.claude\.state\boy-scout-queue'
        Remove-Item -LiteralPath $queue -Force -ErrorAction SilentlyContinue
        Push-Location $fixture.Dir
        try {
            $rps = Invoke-BoyScoutHook (Join-Path $fixture.Hooks 'boy-scout-check.ps1') '{}' 'deliver'
            $rsh = Invoke-BoyScoutHook (Join-Path $fixture.Hooks 'boy-scout-check.sh') '{}' 'deliver'
            Assert ($rps.Exit -eq 0 -and $rsh.Exit -eq 0) `
                "REGRESSION: queue-less deliver must exit 0: ps1=$($rps.Exit) sh=$($rsh.Exit)"
            Assert ([string]::IsNullOrEmpty($rps.Out) -and [string]::IsNullOrEmpty($rsh.Out)) `
                "REGRESSION: queue-less deliver scanned or spoke on a read-only prompt: ps1='$($rps.Out)' sh='$($rsh.Out)'"
            Assert ($rps.Out -notmatch 'decision' -and $rsh.Out -notmatch 'decision') 'queue-less deliver output contained forbidden decision property'
        } finally { Pop-Location; Remove-Item -LiteralPath $fixture.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'boy-scout twins agree: Claude Stop payload emits Claude context' {
        $fixture = New-BoyScoutFixture $boyPs $boySh
        $state = Join-Path $fixture.Repo '.claude\.state'
        Push-Location $fixture.Dir
        try {
            $payload = '{"hook_event_name":"Stop"}'
            $rps = Invoke-BoyScoutHook (Join-Path $fixture.Hooks 'boy-scout-check.ps1') $payload
            Remove-Item -LiteralPath $state -Recurse -Force -ErrorAction SilentlyContinue
            $rsh = Invoke-BoyScoutHook (Join-Path $fixture.Hooks 'boy-scout-check.sh') $payload
            Assert ($rps.Exit -eq $rsh.Exit -and $rps.Exit -eq 0) 'Claude-mode exits differ or are non-zero'
            $jps = $rps.Out | ConvertFrom-Json; $jsh = $rsh.Out | ConvertFrom-Json
            Assert ($jps.hookSpecificOutput.hookEventName -eq 'Stop') 'PowerShell Claude event shape wrong'
            Assert ($jsh.hookSpecificOutput.hookEventName -eq 'Stop') 'shell Claude event shape wrong'
            Assert (-not [string]::IsNullOrWhiteSpace($jps.systemMessage)) 'PowerShell Claude systemMessage missing'
            Assert (-not [string]::IsNullOrWhiteSpace($jsh.systemMessage)) 'shell Claude systemMessage missing'
            Assert ($rps.Out -notmatch 'decision' -and $rsh.Out -notmatch 'decision') 'Claude output contained forbidden decision property'
        } finally { Pop-Location; Remove-Item -LiteralPath $fixture.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# --- session-start security-findings preload: twins agree and emit clean stderr ---
# Regression for the `grep -c … || echo 0` bug (grep -c prints 0 AND exits 1 on no match, so the
# fallback produced "0\n0" and an integer-comparison error on stderr) and for the section existing
# in one twin but not the other. Fixture CWDs; the real repo is never touched.
$ssPs = Join-Path $hooks 'session-start.ps1'; $ssSh = Join-Path $hooks 'session-start.sh'
if (-not $bash) {
    Skip 'session-start security-preload twins' 'no bash found'
} else {
    $secHeader = "| ID | Severity | Status | Found | Due | Issue |`n|---|---|---|---|---|---|"
    $secCases = @(
        @{ n = 'no open findings'; rows = '';                                                         expect = $false },
        @{ n = 'one open finding'; rows = "`n| SF-1 | High | Open | 2026-01-01 | 2099-01-01 | x |";  expect = $true }
    )
    foreach ($case in $secCases) {
        It "session-start twins agree on security preload ($($case.n)), clean stderr" {
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("ssfix-" + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Push-Location $dir
            try {
                [IO.File]::WriteAllText((Join-Path $dir 'SECURITY_FINDINGS.md'), ($secHeader + $case.rows + "`n"))
                $rps = Invoke-Hook $ssPs '{}'; $rsh = Invoke-Hook $ssSh '{}'
                Assert ("$($rps.Err)".Trim() -eq '' -and "$($rsh.Err)".Trim() -eq '') "stderr not clean: ps1='$("$($rps.Err)".Trim())' sh='$("$($rsh.Err)".Trim())'"
                $hasPs = $rps.Out -match '\*\*Security:\*\*'; $hasSh = $rsh.Out -match '\*\*Security:\*\*'
                Assert (($hasPs -eq $case.expect) -and ($hasSh -eq $case.expect)) "security line present: expected=$($case.expect) ps1=$hasPs sh=$hasSh"
            } finally { Pop-Location; Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}

exit (Write-TestSummary 'TwinParity.Tests (.ps1 vs .sh)')
