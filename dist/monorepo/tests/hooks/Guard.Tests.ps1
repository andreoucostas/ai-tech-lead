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
$selectedCases = @($GuardCases)
if ($env:GUARD_TEST_POLICY) {
    $selectedCases = @($GuardCases | Where-Object { $_.policy -eq $env:GUARD_TEST_POLICY })
    if ($selectedCases.Count -eq 0) {
        # Exit 111, NOT 1. The mutation harness decides "the mutation was caught" from a non-zero
        # exit, and this suite's normal exit code is its failure COUNT -- so exiting 1 here is
        # byte-identical to "one case failed" and an untagged case would silently convert the red
        # test into a pass. Verified: with the 'secret' tag removed, GuardPatternErrors reported
        # 4 passed while testing nothing. 111 is outside any plausible failure count and the harness
        # rejects it explicitly.
        [Console]::Error.WriteLine("Guard.Tests: GUARD_TEST_POLICY '$($env:GUARD_TEST_POLICY)' matched no cases")
        exit 111
    }
}
foreach ($case in $selectedCases) {
    foreach ($surface in 'Claude','Copilot') {
        $evt = if ($surface -eq 'Claude') { New-ClaudeEvent $case.f $case.c } else { New-CopilotEvent $case.f $case.c }
        $expected = if (-not $case.block) { 'ALLOW' } elseif ($surface -eq 'Claude') { 'BLOCK' } else { 'DENY' }
        It "guard $expected ($surface): $($case.n)" {
            $rps = Invoke-Hook $guardPs $evt
            Assert-Decision $rps $expected $case.n
            # .sh twin: same expected decision, then byte-identical rendering. Self-skips when no bash
            # is present (reported once below) so a pure-Windows host still gets full guard.ps1 cover.
            if ($bash) {
                $rsh = Invoke-Hook $guardSh $evt
                Assert-Decision $rsh $expected $case.n
                Assert ($rps.Exit -eq $rsh.Exit) "guard.ps1 exit $($rps.Exit) but guard.sh exit $($rsh.Exit)"
                # Windows PowerShell 5.1's ConvertTo-Json renders an apostrophe as the equivalent
                # JSON escape \u0027; pwsh 7 and the bash twin render it literally. Normalise only
                # that semantics-preserving escape. Every other output byte remains strict.
                $psOut = "$($rps.Out)" -replace '\\u0027', "'"
                $shOut = "$($rsh.Out)" -replace '\\u0027', "'"
                Assert ([string]::Equals($psOut, $shOut, [StringComparison]::Ordinal)) `
                    "stdout differs: guard.ps1='$($rps.Out)' guard.sh='$($rsh.Out)'"
                Assert ([string]::Equals("$($rps.Err)", "$($rsh.Err)", [StringComparison]::Ordinal)) `
                    "stderr differs: guard.ps1='$($rps.Err)' guard.sh='$($rsh.Err)'"
            }
        }
    }
}
if (-not $bash) { Skip 'guard .sh twin parity (all cases)' 'no bash found -- cannot run .sh twin on this host' }

# Empty stdin and malformed JSON must degrade-safe to ALLOW (exit 0), never crash.
It 'guard.ps1 empty stdin -> allow'     { Assert-Decision (Invoke-Hook $guardPs '')             'ALLOW' 'empty' }
It 'guard parser edge cases degrade safely and a broken jq falls back to working Python' {
    Assert-Decision (Invoke-Hook $guardPs 'not json {') 'ALLOW' 'malformed'
    if ($bash -and (Resolve-HostPython)) {
        $evt = New-ClaudeEvent 'src/Secret.cs' 'const string token = "AKIA1234567890ABCDEF";'
        $r = Invoke-Sandboxed -Bash $bash -ScriptPath $guardSh -Utilities @('cat','grep','sed') `
            -FakeBins @{ jq = "#!/usr/bin/env bash`nexit 49`n" } -ExposeInterpreterAs python -Stdin $evt
        Assert-Decision $r 'BLOCK' 'broken jq with working Python fallback'
    }
}

exit (Write-TestSummary 'Guard.Tests (guard.ps1 + .sh twin parity)')
