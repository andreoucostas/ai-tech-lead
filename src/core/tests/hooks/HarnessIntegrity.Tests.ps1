# Proves the test harness itself can report failure.
#
# Every other file in this directory tests a hook. This one tests the scoreboard those files are
# scored on, and a defect here is the quietest kind there is: every suite still prints its results,
# and every exit code lies. That is not hypothetical. A version of `Write-TestSummary` returned
# `$null` instead of a failure count under Windows PowerShell 5.1, so `exit (Write-TestSummary ...)`
# became `exit 0` while the summary printed `[FAIL]` — and `Invoke-HookTests.ps1`, which sums child
# exit codes, scored the file green. It hid for an unknown number of versions.
#
# Two properties of that bug shape these tests:
#
#   * It only surfaced with EXACTLY ONE failing test in a file. Under Windows PowerShell 5.1 a
#     pipeline yielding a single object has no `.Count` and returns `$null`; two or more failures
#     returned a real integer and were caught. So the fixture below fails exactly once — a
#     two-failure fixture would have passed against the broken harness and proved nothing.
#   * It was invisible under PowerShell 7, which returns 1 for the same expression. **The red
#     observation for these tests exists only on Windows PowerShell 5.1.** Running them under
#     pwsh 7 confirms the green path and nothing more; do not record a pwsh-7 run as a red test.
#
# The fixtures run as child processes and their output is captured, never streamed. A suite that
# prints a bare `[FAIL]` during a passing run teaches people to ignore `[FAIL]`.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')

Reset-Tests

# Build a throwaway suite directory: real harness, real runner, planted fixtures. Copying the
# runner means discovery finds ONLY these fixtures, so this never re-enters the real suite.
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ("harnessintegrity-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $sandbox -Force | Out-Null

function New-Fixture {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][int]$Failures)
    # A fixture that also PASSES a test, so a harness that simply exits non-zero always would not
    # satisfy the green case below.
    $body = New-Object System.Text.StringBuilder
    [void]$body.AppendLine(". (Join-Path `$PSScriptRoot '_HookHarness.ps1')")
    [void]$body.AppendLine('Reset-Tests')
    [void]$body.AppendLine("It 'a test that passes' { Assert `$true 'always' }")
    for ($i = 1; $i -le $Failures; $i++) {
        [void]$body.AppendLine("It 'a test that fails ($i)' { Assert `$false 'planted failure' }")
    }
    [void]$body.AppendLine("exit (Write-TestSummary 'Fixture')")
    $path = Join-Path $sandbox "$Name.Tests.ps1"
    [IO.File]::WriteAllText($path, $body.ToString(), [Text.UTF8Encoding]::new($true))   # BOM required
    return $path
}

# Run the fixture under THIS host, not under a preferred one.
#
# The first cut of this file used the harness's `Get-PsExe`, which at the time preferred pwsh 7
# whenever it resolved. That made every fixture run under pwsh 7 even when the suite itself ran under
# Windows PowerShell 5.1 — so the one host where the defect exists was never the host under test,
# and the whole file passed with the defect planted. An integrity test that cannot observe the
# failure it was written for is worse than no test: it certifies the thing it never checked.
#
# `(Get-Process -Id $PID).Path` is the running host's own executable and works on both 5.1 and 7.
$script:SelfHost = (Get-Process -Id $PID).Path

function Invoke-Child {
    param([Parameter(Mandatory)][string]$Path, [string[]]$Arguments = @())
    $out  = & $script:SelfHost -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments 2>&1
    $code = $LASTEXITCODE
    return [pscustomobject]@{ Exit = $code; Out = (@($out) -join "`n") }
}

function Invoke-CardinalityRunnerFixture {
    param([Parameter(Mandatory)][string]$Body, [Parameter(Mandatory)][string]$Name)
    $root = Join-Path $sandbox ('cardinality-' + $Name)
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Invoke-HookTests.ps1') -Destination $root
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '_HookHarness.ps1') -Destination $root
    [IO.File]::WriteAllText((Join-Path $root 'Probe.Tests.ps1'), $Body, (New-Object Text.UTF8Encoding($true)))
    $manifest = Join-Path $root 'case-counts.txt'
    $savedErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $out = & $script:SelfHost -NoProfile -ExecutionPolicy Bypass -File `
            (Join-Path $root 'Invoke-HookTests.ps1') -FixtureDiscovery -CaseCountPath $manifest 2>&1
        $exit = [int]$LASTEXITCODE
    } finally {
        $ErrorActionPreference = $savedErrorActionPreference
    }
    return [pscustomobject]@{ Exit=$exit; Out=(@($out) -join "`n"); Manifest=$manifest }
}

try {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '_HookHarness.ps1')      -Destination $sandbox
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Invoke-HookTests.ps1')  -Destination $sandbox

    It 'a suite file with exactly ONE failing test exits non-zero' {
        $f = New-Fixture -Name 'OneFailure' -Failures 1
        $r = Invoke-Child -Path $f
        # Assert the fixture actually ran and actually failed. Without this a fixture that died on a
        # syntax error would also exit non-zero, and this test would pass for the wrong reason.
        Assert ($r.Out -match '\[FAIL\]')            "the fixture did not report a failure -- it may not have run: $($r.Out)"
        Assert ($r.Out -match '1 passed, 1 failed')  "unexpected fixture summary -- the fixture is not shaped as intended: $($r.Out)"
        Assert ($r.Exit -ne 0)                       "a suite file with one failing test exited $($r.Exit); the failure count is not reaching the exit code"
    }

    It 'a suite file with no failing tests exits zero (control)' {
        # Without this, a harness hard-wired to exit non-zero would satisfy the test above.
        $f = New-Fixture -Name 'NoFailure' -Failures 0
        $r = Invoke-Child -Path $f
        Assert ($r.Out -match '1 passed, 0 failed') "unexpected fixture summary: $($r.Out)"
        Assert ($r.Exit -eq 0)                      "a passing suite file exited $($r.Exit), expected 0"
    }

    It 'the runner exits non-zero when a suite file fails' {
        # The level above: a file can report its own failure correctly while the runner still sums
        # to zero. Both halves have to hold for a red result to reach the caller.
        $r = Invoke-Child -Path (Join-Path $sandbox 'Invoke-HookTests.ps1') -Arguments @('-FixtureDiscovery')
        Assert ($r.Out -match 'OneFailure\.Tests\.ps1') "the runner did not discover the planted fixtures: $($r.Out)"
        Assert ($r.Out -match 'failure\(s\) across')    "the runner did not print its summary: $($r.Out)"
        Assert ($r.Exit -ne 0)                          "the runner exited $($r.Exit) with a failing suite file present"
    }

    It 'the runner exits zero when every suite file passes (control)' {
        Remove-Item -LiteralPath (Join-Path $sandbox 'OneFailure.Tests.ps1') -Force
        $r = Invoke-Child -Path (Join-Path $sandbox 'Invoke-HookTests.ps1') -Arguments @('-FixtureDiscovery')
        Assert ($r.Out -match 'NoFailure\.Tests\.ps1') "the runner did not discover the remaining fixture: $($r.Out)"
        Assert ($r.Exit -eq 0)                         "the runner exited $($r.Exit) with only passing suite files"
    }

    It 'the runner rejects a child with no semantic case marker' {
        $r = Invoke-CardinalityRunnerFixture -Body "exit 0`n" -Name 'missing'
        Assert ($r.Exit -ne 0) "missing marker stayed green: $($r.Out)"
        Assert ($r.Out -match 'emitted 0 CASE_COUNT markers') "missing marker was not diagnosed: $($r.Out)"
        Assert (-not (Test-Path -LiteralPath $r.Manifest)) 'missing marker produced a manifest'
    }

    It 'the runner rejects a zero semantic case marker' {
        $r = Invoke-CardinalityRunnerFixture -Body "Write-Host 'CASE_COUNT 0'`nexit 0`n" -Name 'zero'
        Assert ($r.Exit -ne 0) "zero marker stayed green: $($r.Out)"
        Assert ($r.Out -match 'non-positive CASE_COUNT') "zero marker was not diagnosed: $($r.Out)"
        Assert (-not (Test-Path -LiteralPath $r.Manifest)) 'zero marker produced a manifest'
    }

    It 'the runner rejects a suite whose only semantic case was skipped' {
        $body = @'
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
Reset-Tests
Skip 'Windows case' 'fixture deliberately did not execute'
exit (Write-TestSummary 'skip-only fixture')
'@
        $r = Invoke-CardinalityRunnerFixture -Body $body -Name 'skip-only'
        Assert ($r.Exit -ne 0) "skip-only suite stayed green: $($r.Out)"
        Assert ($r.Out -match 'CASE_COUNT 0' -and $r.Out -match 'non-positive CASE_COUNT') `
            "skip-only suite was not classified as zero executed cases: $($r.Out)"
        Assert (-not (Test-Path -LiteralPath $r.Manifest)) 'skip-only suite produced a manifest'
    }

    It 'the runner rejects duplicate semantic case markers' {
        $r = Invoke-CardinalityRunnerFixture -Body "Write-Host 'CASE_COUNT 1'`nWrite-Host 'CASE_COUNT 2'`nexit 0`n" -Name 'duplicate'
        Assert ($r.Exit -ne 0) "duplicate markers stayed green: $($r.Out)"
        Assert ($r.Out -match 'emitted 2 CASE_COUNT markers') "duplicate markers were not diagnosed: $($r.Out)"
        Assert (-not (Test-Path -LiteralPath $r.Manifest)) 'duplicate markers produced a manifest'
    }

    It 'the semantic case manifest is deterministic UTF-8 without BOM' {
        $body = "Write-Host 'CASE_COUNT 3'`nexit 0`n"
        $first = Invoke-CardinalityRunnerFixture -Body $body -Name 'valid-first'
        $second = Invoke-CardinalityRunnerFixture -Body $body -Name 'valid-second'
        Assert ($first.Exit -eq 0 -and $second.Exit -eq 0) "valid marker failed: $($first.Out)`n$($second.Out)"
        $a = [IO.File]::ReadAllBytes($first.Manifest)
        $b = [IO.File]::ReadAllBytes($second.Manifest)
        Assert ($a.Length -gt 0 -and $b.Length -gt 0) 'valid marker produced an empty manifest'
        Assert (-not ($a.Length -ge 3 -and $a[0] -eq 0xEF -and $a[1] -eq 0xBB -and $a[2] -eq 0xBF)) 'manifest unexpectedly has a UTF-8 BOM'
        Assert ([Convert]::ToBase64String($a) -ceq [Convert]::ToBase64String($b)) 'identical runs produced different manifest bytes'
        Assert ([Text.Encoding]::UTF8.GetString($a) -ceq "Probe.Tests.ps1`t3`nTOTAL`t3`n") 'manifest format/content differs from its canonical form'
    }
} finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

# Print the summary through the harness (so this file reads like every other suite), but do NOT let
# the harness score it.
#
# Every other file here can trust `Write-TestSummary`'s return value. This one cannot: it is scored
# by the component it exists to test, and that is circular exactly when it matters. Observed with the
# `@()` fix reverted under Windows PowerShell 5.1 — this file correctly printed `[FAIL]` for the
# planted defect and then exited 0, because the summary it used to score itself was the broken one.
# A gate that goes quiet precisely when its subject is broken is the failure mode this file exists
# to remove, so the exit code is computed here, from the recorded results, independently.
[void](Write-TestSummary 'HarnessIntegrity.Tests (the harness can report failure)')
$failed = @($script:Tests | Where-Object { $_.State -eq 'FAIL' }).Count
if ($failed -gt 0) { Write-Host ("HarnessIntegrity: exiting {0} (counted independently of the harness)" -f $failed) }
exit ([int]$failed)
