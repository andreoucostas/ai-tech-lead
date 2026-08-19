# Suite entry point (root meta-dev) -- runs every *.Tests.ps1 here as an isolated pwsh process and
# exits with the TOTAL number of failures (0 = green). Mirrors ai-tech-lead-*/tests/hooks runner.
# Usage:  pwsh -NoProfile -File .claude/hooks/tests/Invoke-HookTests.ps1 [-File Name.Tests.ps1] [-Sequential]
#
# The files run CONCURRENTLY. Each was already an isolated child process mutating only its own temp
# tree, so independence was a property of the design long before it was exploited here -- this only
# stops paying for it serially. Measured on this box: serial 399s, and one file (ValidateDist.Tests,
# 259s) dominates, so the parallel floor is that file, not the sum. release.ps1 already uses exactly
# this Start-Job shape for the three per-dist gate suites.
#
# Output is buffered per file and printed in the deterministic Sort-Object Name order, NOT in
# completion order -- interleaved live output from nine children would be unreadable, and a suite
# whose transcript reorders itself between runs is one nobody can diff.
#
# -Sequential restores the old one-at-a-time behaviour for diagnosing a file that only fails under
# concurrency. -File runs a single file, which is what a targeted red-test needs.
[CmdletBinding()]
param(
    [string]$File,
    [switch]$Sequential
)
$ErrorActionPreference = 'Stop'
if (Get-Command pwsh -ErrorAction SilentlyContinue) { $psExe = 'pwsh' } else { $psExe = 'powershell' }
$files = Get-ChildItem -LiteralPath $PSScriptRoot -Filter *.Tests.ps1 | Sort-Object Name
if ($File) {
    $files = @($files | Where-Object { $_.Name -eq $File })
    # A -File that matches nothing must be a loud error, never an empty green run: a typo in a
    # targeted red-test would otherwise report "0 failures" and read as a pass.
    # Written straight to stderr rather than via Write-Error: $ErrorActionPreference = 'Stop' makes
    # Write-Error terminating, so the script would die with exit 1 before reaching `exit 2` and the
    # usage-vs-failure distinction would be lost.
    if ($files.Count -eq 0) {
        [Console]::Error.WriteLine("No test file named '$File' in $PSScriptRoot")
        exit 2
    }
}

# One machine-readable line per file, emitted in every mode. release.ps1 parses these so an
# operator waiver can name ONE failing file (-AllowFailingGate) instead of the all-or-nothing total.
# The failing file still RUNS and still reports -- a waiver changes what blocks the release, never
# what gets measured.
function Write-FileResult([string]$Name, [int]$Exit) { Write-Host ("RESULT {0} {1}" -f $Name, $Exit) }

# Per-file wall time, on its OWN line and never appended to RESULT: release.ps1:549 parses
# `^RESULT\s+(\S+)\s+(\d+)\s*$` anchored at BOTH ends, so a third field would not merely be ignored
# -- it would match nothing, and the -AllowFailingGate path would report "emitted no per-file RESULT
# lines" and refuse a waiver that is actually valid. A silent break, so: separate line.
#
# This exists because a gate-budget breach was diagnosed twice from a SERIAL per-file pass, and both
# diagnoses were wrong. A serial pass runs each file with the throttle env vars UNSET, i.e. at full
# internal width; the parallel run hands each file $innerLanes instead. The two numbers are not the
# same measurement, so serial costs can never predict the parallel makespan. Measure the run you
# actually ship.
function Write-FileTiming([string]$Name, $Begin, $End) {
    if ($null -eq $Begin -or $null -eq $End) { return }
    Write-Host ("TIMING {0} {1:N1}" -f $Name, ($End - $Begin).TotalSeconds)
}

$total = 0
if ($Sequential -or $files.Count -eq 1) {
    foreach ($f in $files) {
        Write-Host ("--- {0} ---" -f $f.Name)
        $began = Get-Date
        & $psExe -NoProfile -ExecutionPolicy Bypass -File $f.FullName
        $exit = [int]$LASTEXITCODE
        Write-FileResult $f.Name $exit
        Write-FileTiming $f.Name $began (Get-Date)
        $total += $exit
    }
} else {
    # THROTTLED on purpose, and the number is not a guess. The first cut of this launched all ten
    # files at once and measured 1,335s against a 399s serial baseline -- 3.3x SLOWER. These suites
    # are bound by process creation, not CPU (every assertion spawns a fresh pwsh or bash), so
    # unthrottled concurrency just oversubscribes and every lane crawls. release.ps1's dist-gate
    # comment already said exactly this; this runner had to learn it again by measurement.
    #
    # Worse, the nesting is invisible: ValidateDist.Tests.ps1 parallelises its own 20 cases, so ten
    # outer jobs became ten x N children. VALIDATE_DIST_TESTS_THROTTLE is set below to hand that file
    # a share rather than let it assume it owns the box.
    # LONGEST-FIRST SCHEDULING. The lanes were never the problem -- the launch ORDER was.
    # Files were launched in `Sort-Object Name` order, chosen for determinism, which is the worst
    # possible schedule for makespan: a long job that starts last runs alone at the tail while every
    # other lane sits idle. Measured serially on the maintainer box (12 cores, idle, 2026-08-19,
    # 923.6s total across 25 files):
    #
    #   GuardPatternErrors.Tests.ps1   418.5s   <- 45% of the entire serial cost, alphabetically 8th
    #   ValidateDist.Tests.ps1         234.9s   <- alphabetically 23rd, i.e. launched in the LAST wave
    #   UpdateDelivery.Tests.ps1        83.7s   <- 22nd
    #   InstallerContract.Tests.ps1     51.3s
    #   DocsSyncCheck.Tests.ps1         38.6s
    #   ...every remaining file is under 27s, and 17 of 25 are under 3s.
    #
    # MEASURED OUTCOME: this ordering change bought NOTHING. Modelled makespan at 4 lanes was
    # alphabetical ~(505/4)+418 = 545s vs longest-first ~max(418, 505/4) = 418s. The actual timed
    # run after the change was 689.2s (0 failures), against 671.5s before it. The model was wrong,
    # not the arithmetic: it fed SERIAL per-file costs into a PARALLEL schedule, and a serial pass
    # runs each file with VALIDATE_DIST_TESTS_THROTTLE / HOOKTESTS_THROTTLE unset -- i.e. at full
    # internal width -- while this loop hands each file only $innerLanes. Files that parallelise
    # internally are therefore much more expensive here than the serial table says, so the table
    # cannot predict the makespan and the "floor is the heaviest file" conclusion does not follow.
    # The TIMING lines above exist so the next diagnosis reads the real per-file parallel cost
    # instead of re-deriving it from the wrong pass a third time.
    #
    # The ordering is KEPT because longest-first is still the correct schedule shape and costs
    # nothing -- but it is not a fix for the budget, and must not be cited as one.
    #
    # The table is a scheduling HINT, never correctness: an unlisted file is scheduled first (a new
    # file's cost is unknown, and guessing "cheap" is the mistake that created this bug), and ties
    # break by name so the order stays deterministic and reproducible. A stale entry costs some
    # runtime, never a wrong result. Re-measure with a serial pass when the suite's shape changes.
    $costHint = @{
        'GuardPatternErrors.Tests.ps1'    = 418.5
        'ValidateDist.Tests.ps1'          = 234.9
        'UpdateDelivery.Tests.ps1'        = 83.7
        'InstallerContract.Tests.ps1'     = 51.3
        'DocsSyncCheck.Tests.ps1'         = 38.6
        'RootInstallerWarehouse.Tests.ps1'= 26.6
        'LicenseDelivery.Tests.ps1'       = 24.5
        'ReleaseCiWatch.Tests.ps1'        = 12.9
    }
    $files = @($files | Sort-Object `
        @{ Expression = { if ($costHint.ContainsKey($_.Name)) { $costHint[$_.Name] } else { [double]::MaxValue } }; Descending = $true }, `
        @{ Expression = { $_.Name }; Ascending = $true })
    $outerLanes = [math]::Max(2, [math]::Min(4, [int]([Environment]::ProcessorCount / 3)))
    $innerLanes = [math]::Max(2, [int]([Environment]::ProcessorCount / $outerLanes))
    $jobs = @()
    try {
        foreach ($f in $files) {
            # Block until a lane frees up rather than queueing every file at once.
            while (@($jobs | Where-Object { $_.Job.State -eq 'Running' }).Count -ge $outerLanes) {
                Start-Sleep -Milliseconds 200
            }
            $log = [IO.Path]::GetTempFileName()
            $job = Start-Job -ArgumentList $psExe, $f.FullName, $log, $innerLanes -ScriptBlock {
                param($psExe, $path, $log, $innerLanes)
                $env:VALIDATE_DIST_TESTS_THROTTLE = "$innerLanes"
                $env:HOOKTESTS_THROTTLE = "$innerLanes"
                & $psExe -NoProfile -ExecutionPolicy Bypass -File $path *> $log
                $LASTEXITCODE
            }
            $jobs += [pscustomobject]@{ Name = $f.Name; Log = $log; Job = $job }
        }
        $jobs.Job | Wait-Job | Out-Null
        foreach ($entry in $jobs) {
            Write-Host ("--- {0} ---" -f $entry.Name)
            Write-Host -NoNewline ([IO.File]::ReadAllText($entry.Log))
            $exit = Receive-Job $entry.Job
            # A child that died without producing an exit code must count as a failure, not as zero.
            if ($null -eq $exit) { $exit = 1 }
            Write-FileResult $entry.Name ([int]$exit)
            Write-FileTiming $entry.Name $entry.Job.PSBeginTime $entry.Job.PSEndTime
            $total += [int]$exit
        }
    } finally {
        if ($jobs) {
            $jobs.Job | Remove-Job -Force -ErrorAction SilentlyContinue
            $jobs.Log | Where-Object { Test-Path -LiteralPath $_ } | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
}
Write-Host ("=== Meta-hook test suite: {0} failure(s) across {1} file(s) ===" -f $total, $files.Count)
exit $total
