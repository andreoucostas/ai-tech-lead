# WS-M2 -- guard behavioural tests AND .ps1/.sh twin parity, in one pass over the case table.
# For each BLOCKING case: Claude-shaped event must BLOCK (exit 2), Copilot-shaped event must DENY
# (JSON). For each CLEAN case: both shapes must ALLOW. Cases are generated into both surface shapes
# from one content string, so the same input drives both.
#
# Both twins are checked against the EXPECTED decision, then against each other. This used to be
# split across two files -- Guard.Tests asserted only guard.ps1 against expected, and
# TwinParity.Tests asserted guard.sh only against guard.ps1. A fault present in BOTH twins therefore
# passed: they agreed with each other, and the .sh twin was never compared against the truth. Running
# both twins from one loop closes that hole and halves the guard invocations, since the .ps1 leg is
# no longer executed a second time against the same fixture.
if (-not (Get-Command Invoke-Hook -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
. (Join-Path $PSScriptRoot 'fixtures\guard-cases.ps1')
$hooks   = (Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks')).Path
$guardPs = Join-Path $hooks 'guard.ps1'
$guardSh = Join-Path $hooks 'guard.sh'
$bash    = Get-BashPath

Reset-Tests
# Each case is independent and owns its two surface invocations. Run cases concurrently, but keep
# the width bounded because the aggregate runner already parallelises test files and exports its
# lane allocation through HOOKTESTS_THROTTLE. Standalone runs use the same processor-count default
# and eight-lane ceiling as that runner. Each job writes a private result log; the parent replays
# those logs in declared case order so the public test names and transcript remain deterministic.
if ($env:HOOKTESTS_THROTTLE) { $throttle = [int]$env:HOOKTESTS_THROTTLE }
else { $throttle = [Environment]::ProcessorCount }
if ($throttle -lt 1) { $throttle = 1 } elseif ($throttle -gt 8) { $throttle = 8 }

$running = @()
try {
    foreach ($case in $GuardCases) {
        while (@($running | Where-Object { $_.Job.State -in 'NotStarted','Running' }).Count -ge $throttle) {
            Start-Sleep -Milliseconds 200
        }
        $log = [IO.Path]::GetTempFileName()
        $job = Start-Job -ArgumentList $PSScriptRoot, $guardPs, $guardSh, $bash, $case, $log -ScriptBlock {
            param($scriptRoot, $guardPs, $guardSh, $bash, $case, $log)
            . (Join-Path $scriptRoot '_HookHarness.ps1')
            # Prevent every job from probing independently, and preserve the parent's no-bash
            # decision: null means the .sh legs do no work and the parent reports one suite skip.
            $script:HarnessBash = $bash
            Reset-Tests
            foreach ($surface in 'Claude','Copilot') {
                $evt = if ($surface -eq 'Claude') { New-ClaudeEvent $case.f $case.c } else { New-CopilotEvent $case.f $case.c }
                $expected = if (-not $case.block) { 'ALLOW' } elseif ($surface -eq 'Claude') { 'BLOCK' } else { 'DENY' }
                It "guard $expected ($surface): $($case.n)" {
                    $rps = Invoke-Hook $guardPs $evt
                    Assert-Decision $rps $expected $case.n
                    # Both twins still consume the same event and are each checked against truth
                    # before they are compared with one another.
                    if ($bash) {
                        $rsh = Invoke-Hook $guardSh $evt
                        Assert-Decision $rsh $expected $case.n
                        Assert ($rps.Exit -eq $rsh.Exit) "guard.ps1 exit $($rps.Exit) but guard.sh exit $($rsh.Exit)"
                        Assert ([string]::Equals("$($rps.Out)", "$($rsh.Out)", [StringComparison]::Ordinal)) `
                            "stdout differs: guard.ps1='$($rps.Out)' guard.sh='$($rsh.Out)'"
                        Assert ([string]::Equals("$($rps.Err)", "$($rsh.Err)", [StringComparison]::Ordinal)) `
                            "stderr differs: guard.ps1='$($rps.Err)' guard.sh='$($rsh.Err)'"
                    }
                }
            }
            $script:Tests | Export-Clixml -LiteralPath $log
        }
        $running += [pscustomobject]@{ Case = $case; Log = $log; Job = $job }
    }
    $running.Job | Wait-Job | Out-Null
    foreach ($entry in $running) {
        $caseResults = @()
        if ($entry.Job.State -eq 'Completed' -and (Test-Path -LiteralPath $entry.Log)) {
            try { $caseResults = @(Import-Clixml -LiteralPath $entry.Log -ErrorAction Stop) } catch { }
        }
        if ($caseResults.Count -eq 2) {
            foreach ($result in $caseResults) { $script:Tests.Add($result) }
        } else {
            foreach ($surface in 'Claude','Copilot') {
                $expected = if (-not $entry.Case.block) { 'ALLOW' } elseif ($surface -eq 'Claude') { 'BLOCK' } else { 'DENY' }
                $script:Tests.Add([pscustomobject]@{
                    Name = "guard $expected ($surface): $($entry.Case.n)"
                    State = 'FAIL'; Msg = 'case job produced no result (crashed or was terminated)'; Invariant = $false
                })
            }
        }
        Receive-Job $entry.Job -ErrorAction SilentlyContinue | Out-Null
    }
} finally {
    if ($running) {
        $running.Job | Remove-Job -Force -ErrorAction SilentlyContinue
        $running.Log | Where-Object { Test-Path -LiteralPath $_ } | Remove-Item -Force -ErrorAction SilentlyContinue
    }
}
if (-not $bash) { Skip 'guard .sh twin parity (all cases)' 'no bash found -- cannot run .sh twin on this host' }

# Empty stdin and malformed JSON must degrade-safe to ALLOW (exit 0), never crash.
It 'guard.ps1 empty stdin -> allow'     { Assert-Decision (Invoke-Hook $guardPs '')             'ALLOW' 'empty' }
It 'guard.ps1 malformed json -> allow'  { Assert-Decision (Invoke-Hook $guardPs 'not json {')   'ALLOW' 'malformed' }

exit (Write-TestSummary 'Guard.Tests (guard.ps1 + .sh twin parity)')
