# B-59 executable red-test: prove each guard twin makes the suite fail when a regex becomes inert,
# and prove both runtime policies (secret fail-closed; test-defeat/suppression warn + allow).
. (Join-Path $PSScriptRoot '..\..\..\src\core\tests\hooks\_HookHarness.ps1')
. (Join-Path $PSScriptRoot '_MutationHelper.ps1')

$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\src\core')).Path
$cases = @(
    @{ Name = 'PowerShell secret pattern'; File = '.claude\hooks\guard.ps1'; Find = "Test-GuardPattern '-----BEGIN [A-Z ]*PRIVATE KEY-----' 'secret'"; Replace = "Test-GuardPattern '[' 'secret'"; Policy = 'secret' }
    @{ Name = 'shell secret pattern';      File = '.claude\hooks\guard.sh';  Find = "matches '-----BEGIN [A-Z ]*PRIVATE KEY-----' 'secret'"; Replace = "matches '[' 'secret'"; Policy = 'secret' }
    @{ Name = 'PowerShell suppression pattern'; File = '.claude\hooks\guard.ps1'; Find = "Test-GuardPattern '#pragma\s+warning\s+disable' 'test-defeat/suppression'"; Replace = "Test-GuardPattern '[' 'test-defeat/suppression'"; Policy = 'test-defeat/suppression' }
    @{ Name = 'shell suppression pattern';      File = '.claude\hooks\guard.sh';  Find = "matches '#pragma[[:space:]]+warning[[:space:]]+disable' 'test-defeat/suppression'"; Replace = "matches '[' 'test-defeat/suppression'"; Policy = 'test-defeat/suppression' }
)

# PARALLELISED 2026-08-19, because this file WAS the meta suite: measured 651.1s of a 677.6s
# parallel wall clock (96%) -- every other file, ValidateDist included, finished inside its shadow.
# The four cases are independent BY CONSTRUCTION, not by luck: Invoke-MutationRedTest copies the
# subject tree into its own `mutation-helper-<guid>` scratch parent per invocation and removes it in
# a finally, so no two cases share a path, a file, or any state. They were serial only because of a
# foreach.
#
# Two measurements worth keeping, because both refuted a plausible theory:
#   - Serial cost 418.5s vs parallel 651.1s: a 1.56x CONTENTION inflation on a file with no internal
#     parallelism at all. So a serial per-file pass cannot be used to predict a parallel makespan --
#     see the note in Invoke-HookTests.ps1, where doing exactly that produced a wrong diagnosis twice.
#   - Longest-first launch ordering was tried first and bought nothing (689.2s vs 671.5s). You cannot
#     reorder your way out of one job that outlasts the entire schedule.
#
# THROTTLED, and the number is not a guess. This file runs INSIDE Invoke-HookTests.ps1's outer
# parallel loop, which exports HOOKTESTS_THROTTLE precisely so a nested suite takes a share of the
# box rather than assuming it owns it. Honouring it is what keeps the 2026-08-07 mistake recorded in
# meta/gate-budget.json ("launched all ten at once ... 3.3x SLOWER") from being repeated one level
# down -- each case spawns a full Guard.Tests run plus hook probes, so unthrottled this multiplies.
# Standalone (env unset) it falls back to the case count, which is what a targeted red-test wants.
#
# Output is buffered per case and printed in DECLARED order, never completion order, so the
# transcript stays diffable between runs.
$throttle = if ($env:HOOKTESTS_THROTTLE) { [int]$env:HOOKTESTS_THROTTLE } else { $cases.Count }
if ($throttle -lt 1) { $throttle = 1 }

$failed = 0
$running = @()
try {
    foreach ($case in $cases) {
        while (@($running | Where-Object { $_.Job.State -eq 'Running' }).Count -ge $throttle) {
            Start-Sleep -Milliseconds 200
        }
        $log = [IO.Path]::GetTempFileName()
        $job = Start-Job -ArgumentList $PSScriptRoot, $sourceRoot, $case, $log -ScriptBlock {
            param($scriptRoot, $sourceRoot, $case, $log)
            # A job runspace inherits no dot-sourced functions, so the harness and the mutation
            # helper are re-sourced here. $scriptRoot is passed in because $PSScriptRoot inside a job
            # is not this file's directory.
            # $verdict is a hashtable on purpose: it is mutated from the child scope of the & { }
            # capture block below, and a reference type carries that out without $script: scoping.
            $verdict = @{ Failed = 0; Error = '' }
            $text = & {
                try {
                    . (Join-Path $scriptRoot '..\..\..\src\core\tests\hooks\_HookHarness.ps1')
                    . (Join-Path $scriptRoot '_MutationHelper.ps1')
                    $target = Join-Path $sourceRoot $case.File
                    Invoke-MutationRedTest -TargetFile $target -ScratchSourceRoot $sourceRoot -Find $case.Find -Replacement $case.Replace -Command {
                        param($scratchTarget, $scratchRoot)
                        $suite = Join-Path $scratchRoot 'tests\hooks\Guard.Tests.ps1'
                        & pwsh -NoProfile -File $suite
                        $suiteExit = $LASTEXITCODE
                        if ($suiteExit -eq 0) { throw 'mutated Guard.Tests suite stayed green' }

                        # $evt, not $event: $Event is a PowerShell automatic variable, and this now
                        # runs inside a job rather than at script scope.
                        $evt = New-ClaudeEvent 'src/Foo.cs' 'public class Foo { }'
                        $probe = Invoke-Hook $scratchTarget $evt
                        if ($case.Policy -eq 'secret') {
                            Assert ($probe.Exit -eq 2) "$($case.Name): invalid secret regex did not fail closed"
                        } else {
                            Assert ($probe.Exit -eq 0) "$($case.Name): invalid suppression regex did not allow"
                        }
                        Assert ("$($probe.Err)" -match [regex]::Escape($case.Policy)) "$($case.Name): stderr omitted category '$($case.Policy)'"
                        Assert ("$($probe.Err)" -match "pattern '\['") "$($case.Name): stderr omitted the invalid pattern"
                        $global:LASTEXITCODE = $suiteExit
                    } | Out-Null
                    Write-Host "[ok] $($case.Name): suite went red and $($case.Policy) policy was observed"
                } catch {
                    $verdict.Failed = 1
                    $verdict.Error = $_.Exception.Message
                }
            } *>&1 | Out-String
            [IO.File]::WriteAllText($log, $text)
            [pscustomobject]$verdict
        }
        $running += [pscustomobject]@{ Name = $case.Name; Log = $log; Job = $job }
    }
    $running.Job | Wait-Job | Out-Null
    foreach ($entry in $running) {
        if (Test-Path -LiteralPath $entry.Log) { Write-Host -NoNewline ([IO.File]::ReadAllText($entry.Log)) }
        $verdict = @(Receive-Job $entry.Job) | Where-Object { $_ -is [psobject] -and $null -ne $_.Failed } | Select-Object -First 1
        # A case whose job died without returning a verdict must count as a FAILURE, never silently
        # as zero. A red-test file that reports success because its own machinery crashed is the
        # inert-instrument class this entire file exists to catch [Maintenance model #4].
        if ($null -eq $verdict) {
            $failed++
            [Console]::Error.WriteLine("[FAIL] $($entry.Name): case job produced no verdict (crashed or was terminated)")
        } elseif ([int]$verdict.Failed -ne 0) {
            $failed++
            [Console]::Error.WriteLine("[FAIL] $($entry.Name): $($verdict.Error)")
        }
    }
} finally {
    if ($running) {
        $running.Job | Remove-Job -Force -ErrorAction SilentlyContinue
        $running.Log | Where-Object { Test-Path -LiteralPath $_ } | Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

if ($failed -eq 0) { Write-Host "GuardPatternErrors.Tests: $($cases.Count) passed, 0 failed" }
else { [Console]::Error.WriteLine("GuardPatternErrors.Tests: $($cases.Count - $failed) passed, $failed failed") }
exit ([int]($failed -gt 0))
