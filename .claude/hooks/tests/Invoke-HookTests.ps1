# Suite entry point (root meta-dev) -- runs every *.Tests.ps1 here as an isolated PowerShell process and
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
# -ShardCount N -ShardIndex I runs bin I of a longest-first partition of the manifest into N bins by
# $costHint; every file lands in exactly one bin (CI runs one job per bin, B-510).
[CmdletBinding()]
param(
    [string]$File,
    [switch]$Sequential,
    [switch]$FixtureDiscovery,
    [string]$CaseCountPath,
    [int]$ShardCount = 1,
    [int]$ShardIndex = 1
)
$ErrorActionPreference = 'Stop'
if ($CaseCountPath -and (Test-Path -LiteralPath $CaseCountPath)) {
    [Console]::Error.WriteLine("CASE CARDINALITY REFUSED: output path already exists: $CaseCountPath")
    exit 2
}
if ($ShardCount -lt 1 -or $ShardIndex -lt 1 -or $ShardIndex -gt $ShardCount -or ($File -and $ShardCount -gt 1)) {
    [Console]::Error.WriteLine("Invalid shard: -ShardIndex $ShardIndex of -ShardCount $ShardCount$(if ($File) { " with -File $File" })")
    exit 2
}
$invokingPsExe = (Get-Process -Id $PID).Path
$psExe = $invokingPsExe

# Prove the executable we hand to every suite really preserves this runner's host. This is a
# runtime assertion, not just a source-level assignment: no resolver or wrapper may run a suite under
# another PowerShell than the one this runner was started with.
$hostProbeOutput = @(& $psExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command '[Console]::Out.Write((Get-Process -Id $PID).Path)' 2>&1 |
    ForEach-Object { $_.ToString() })
$hostProbeExit = [int]$LASTEXITCODE
$childPsExe = ($hostProbeOutput -join '').Trim()
$pathComparison = if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
    [StringComparison]::OrdinalIgnoreCase
} else {
    [StringComparison]::Ordinal
}
if ($hostProbeExit -ne 0 -or [string]::IsNullOrWhiteSpace($childPsExe) -or
    -not [string]::Equals([IO.Path]::GetFullPath($invokingPsExe), [IO.Path]::GetFullPath($childPsExe), $pathComparison)) {
    [Console]::Error.WriteLine("PowerShell host-preservation probe failed: runner='$invokingPsExe'; child='$childPsExe'; exit=$hostProbeExit")
    exit 2
}
$files = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter *.Tests.ps1 | Sort-Object Name)
$expectedTestFiles = @(
    'AdoptionArchiveIntegrity.Tests.ps1',
    'AssertRedFirst.Tests.ps1',
    'B215OwnershipBoundary.Tests.ps1',
    'BacklogHygiene.Tests.ps1',
    'CiCaseParity.Tests.ps1',
    'ClaimTruth.Tests.ps1',
    'Composer.Tests.ps1',
    'ContextFootprint.Tests.ps1',
    'DocClaims.Tests.ps1',
    'DocsSyncCheck.Tests.ps1',
    'DocTruth.Tests.ps1',
    'FinancialCaseOracles.Tests.ps1',
    'GateBudgetConsistency.Tests.ps1',
    'GuardPatternErrors.Tests.ps1',
    'InstallerContract.Tests.ps1',
    'InstallerConvergence.Tests.ps1',
    'MetaHooks.Tests.ps1',
    'OutgoingCommits.Tests.ps1',
    'OperationSkillAuthority.Tests.ps1',
    'PowerShellTopology.Tests.ps1',
    'PushAndCheck.Tests.ps1',
    'ReleaseChangelogStamp.Tests.ps1',
    'ReleaseCiWatch.Tests.ps1',
    'ReleaseDistGateTiming.Tests.ps1',
    'ReleaseGateWaiver.Tests.ps1',
    'ReleaseStagingGuard.Tests.ps1',
    'RepositoryPrivacy.Tests.ps1',
    'RootInstallerWarehouse.Tests.ps1',
    'UpdateDelivery.Tests.ps1',
    'UpdateDelivery2.Tests.ps1',
    'ValidateDist.Tests.ps1',
    'VendorClaims.Tests.ps1',
    'WorkspaceBom.Tests.ps1'
)
if ($expectedTestFiles.Count -eq 0 -or $files.Count -eq 0) {
    [Console]::Error.WriteLine("Test-suite cardinality must be nonzero: manifest=$($expectedTestFiles.Count); discovered=$($files.Count)")
    exit 2
}
if (-not $FixtureDiscovery) {
    $actualNames = @($files.Name)
    $missing = @($expectedTestFiles | Where-Object { $_ -cnotin $actualNames })
    $unexpected = @($actualNames | Where-Object { $_ -cnotin $expectedTestFiles })
    if ($missing.Count -gt 0 -or $unexpected.Count -gt 0) {
        [Console]::Error.WriteLine("Test manifest drift: missing=[$($missing -join ', ')]; unexpected=[$($unexpected -join ', ')]")
        exit 2
    }
}
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

# MEASURED COST, seconds: each file's median TIMING line over eight green master CI runs on
# windows-latest (4 vCPU, so 2 outer lanes x 2 inner), 2026-11-14/15. Re-measure from CI's TIMING
# lines, never from a serial pass: a serial pass runs each file at full internal width, so its costs
# cannot predict this parallel run (they mispredicted it twice). A HINT for launch order and shard
# bins, never correctness: a stale entry costs time, not a result. An unlisted file is priced as the
# dearest listed one, so it launches early; guessing cheap is what left UpdateDelivery.Tests.ps1
# priced at 83.7 s while it took 917 to 1,304 s (B-510). That file was then split in two at its
# cost midpoint; its two entries share its 979.0 s median by a local per-case timing (49.3 / 50.7%).
$costHint = @{
    'UpdateDelivery.Tests.ps1'           = 482.6
    'UpdateDelivery2.Tests.ps1'          = 496.4
    'ValidateDist.Tests.ps1'             = 234.7
    'GuardPatternErrors.Tests.ps1'       = 207.6
    'AdoptionArchiveIntegrity.Tests.ps1' = 162.9
    'InstallerConvergence.Tests.ps1'     = 159.3
    'ContextFootprint.Tests.ps1'         = 142.2
    'RootInstallerWarehouse.Tests.ps1'   = 105.6
    'PushAndCheck.Tests.ps1'             = 74.9
    'OutgoingCommits.Tests.ps1'          = 74.1
    'InstallerContract.Tests.ps1'        = 54.3
    'B215OwnershipBoundary.Tests.ps1'    = 51.8
    'Composer.Tests.ps1'                 = 44.5
    'ReleaseDistGateTiming.Tests.ps1'    = 42.4
    'RepositoryPrivacy.Tests.ps1'        = 30.3
    'AssertRedFirst.Tests.ps1'           = 22.5
    'ReleaseCiWatch.Tests.ps1'           = 20.9
    'DocsSyncCheck.Tests.ps1'            = 15.6
    'ReleaseStagingGuard.Tests.ps1'      = 15.6
    'MetaHooks.Tests.ps1'                = 12.3
    'DocTruth.Tests.ps1'                 = 12.0
    'CiCaseParity.Tests.ps1'             = 6.0
    'ReleaseGateWaiver.Tests.ps1'        = 5.2
    'FinancialCaseOracles.Tests.ps1'     = 5.1
    'VendorClaims.Tests.ps1'             = 2.9
    'PowerShellTopology.Tests.ps1'       = 1.8
    'DocClaims.Tests.ps1'                = 1.5
    'ReleaseChangelogStamp.Tests.ps1'    = 1.4
    'WorkspaceBom.Tests.ps1'             = 1.4
    'BacklogHygiene.Tests.ps1'           = 1.3
    'ClaimTruth.Tests.ps1'               = 1.0
    'GateBudgetConsistency.Tests.ps1'    = 1.0
    'OperationSkillAuthority.Tests.ps1'  = 1.0
}
$unlistedCost = [double](($costHint.Values | Measure-Object -Maximum).Maximum)
function Get-FileCost([string]$Name) { if ($costHint.ContainsKey($Name)) { [double]$costHint[$Name] } else { $unlistedCost } }
$byCost = @(
    @{ Expression = { Get-FileCost $_.Name }; Descending = $true },
    @{ Expression = { $_.Name }; Ascending = $true }
)
if ($ShardCount -gt 1) {
    # Longest-processing-time partition: dearest file first, each into the bin with the least cost so
    # far (ties to the lower bin), cost ties broken by name, so every job computes the same bins and
    # each file lands in exactly one. assert-ci-case-parity.ps1 checks the bins' union in CI.
    $load = New-Object double[] $ShardCount
    $binOf = @{}
    foreach ($f in @($files | Sort-Object $byCost)) {
        $target = 0
        for ($i = 1; $i -lt $ShardCount; $i++) { if ($load[$i] -lt $load[$target]) { $target = $i } }
        $binOf[$f.Name] = $target + 1
        $load[$target] += Get-FileCost $f.Name
    }
    $files = @($files | Where-Object { $binOf[$_.Name] -eq $ShardIndex })
    if ($files.Count -eq 0) {
        [Console]::Error.WriteLine("Shard $ShardIndex of $ShardCount holds no test file")
        exit 2
    }
    Write-Host ("SHARD {0}/{1}: {2} file(s), {3} s measured: {4}" -f $ShardIndex, $ShardCount, $files.Count,
        [math]::Round($load[$ShardIndex - 1]), (@($files.Name) -join ', '))
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
#
# F1 in the invariant culture, never N1 or `-f`: N1 groups thousands in every culture (CI printed
# `1,013.3`, B-510) and `-f` writes the current culture's decimal comma. Grammar: ^TIMING \S+ \d+\.\d$
function Write-FileTiming([string]$Name, $Begin, $End) {
    if ($null -eq $Begin -or $null -eq $End) { return }
    Write-Host ([string]::Format([cultureinfo]::InvariantCulture, 'TIMING {0} {1:F1}', $Name, ($End - $Begin).TotalSeconds))
}

function Read-CaseCount {
    param([Parameter(Mandatory)][string]$Name, [AllowEmptyString()][string]$Text)
    $matches = [regex]::Matches($Text, '(?m)^CASE_COUNT ([0-9]+)\r?$')
    if ($matches.Count -ne 1) {
        throw "$Name emitted $($matches.Count) CASE_COUNT markers; expected exactly one"
    }
    $count = [int]$matches[0].Groups[1].Value
    if ($count -le 0) { throw "$Name emitted a non-positive CASE_COUNT ($count)" }
    return $count
}

function Write-CaseCountManifest {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][hashtable]$Counts)
    if ($Counts.Count -eq 0) { throw 'case-count manifest would be empty' }
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $sum = 0
    foreach ($name in @($Counts.Keys | Sort-Object)) {
        $count = [int]$Counts[$name]
        if ($count -le 0) { throw "case-count manifest contains non-positive count for $name" }
        $lines.Add("$name`t$count") | Out-Null
        $sum += $count
    }
    if ($sum -le 0) { throw 'case-count manifest total would be zero' }
    $lines.Add("TOTAL`t$sum") | Out-Null
    $fullPath = [IO.Path]::GetFullPath($Path)
    $parent = [IO.Path]::GetDirectoryName($fullPath)
    if (-not [string]::IsNullOrWhiteSpace($parent)) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
    $stream = [IO.File]::Open($fullPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $writer = New-Object IO.StreamWriter($stream, (New-Object Text.UTF8Encoding($false)))
        try { $writer.Write(($lines -join "`n") + "`n") } finally { $writer.Dispose() }
    } finally { $stream.Dispose() }
}

$total = 0
$caseCounts = @{}
if ($Sequential -or $files.Count -eq 1) {
    foreach ($f in $files) {
        Write-Host ("--- {0} ---" -f $f.Name)
        $began = Get-Date
        if ($CaseCountPath) {
            $log = [IO.Path]::GetTempFileName()
            $savedErrorActionPreference = $ErrorActionPreference
            $savedCaseTestPath = $env:ATL_CASE_TEST_PATH
            try {
                $ErrorActionPreference = 'Continue'
                $env:ATL_CASE_TEST_PATH = $f.FullName
                & $psExe -NoProfile -ExecutionPolicy Bypass -Command `
                    '$global:AtlEmitCaseCount=$true; & $env:ATL_CASE_TEST_PATH; exit $global:LASTEXITCODE' *> $log
                $exit = [int]$LASTEXITCODE
                $text = [IO.File]::ReadAllText($log)
                Write-Host -NoNewline $text
                try { $caseCounts[$f.Name] = Read-CaseCount -Name $f.Name -Text $text }
                catch { [Console]::Error.WriteLine("CASE CARDINALITY REFUSED: $($_.Exception.Message)"); $total++ }
            } finally {
                $ErrorActionPreference = $savedErrorActionPreference
                $env:ATL_CASE_TEST_PATH = $savedCaseTestPath
                Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue
            }
        } else {
            & $psExe -NoProfile -ExecutionPolicy Bypass -File $f.FullName
            $exit = [int]$LASTEXITCODE
        }
        Write-FileResult $f.Name $exit
        Write-FileTiming $f.Name $began (Get-Date)
        $total += $exit
    }
} else {
    # THROTTLED on purpose, and the number is not a guess. The first cut of this launched all ten
    # files at once and measured 1,335s against a 399s serial baseline -- 3.3x SLOWER. These suites
    # are bound by process creation, not CPU (many assertions spawn a fresh PowerShell), so
    # unthrottled concurrency just oversubscribes and every lane crawls. release.ps1's dist-gate
    # comment already said exactly this; this runner had to learn it again by measurement.
    #
    # Worse, the nesting is invisible: ValidateDist.Tests.ps1 parallelises its own 20 cases, so ten
    # outer jobs became ten x N children. VALIDATE_DIST_TESTS_THROTTLE is set below to hand that file
    # a share rather than let it assume it owns the box.
    # LONGEST-FIRST by $costHint, names breaking ties: a long file launched last runs alone at the
    # tail while the other lanes idle. That is how UpdateDelivery.Tests.ps1, priced at a stale 83.7 s,
    # started near last and set the CI makespan (B-510).
    $files = @($files | Sort-Object $byCost)
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
            $job = Start-Job -ArgumentList $psExe, $f.FullName, $log, $innerLanes, ([bool]$CaseCountPath) -ScriptBlock {
                param($psExe, $path, $log, $innerLanes, $emitCaseCount)
                $env:VALIDATE_DIST_TESTS_THROTTLE = "$innerLanes"
                $env:HOOKTESTS_THROTTLE = "$innerLanes"
                if ($emitCaseCount) {
                    $env:ATL_CASE_TEST_PATH = $path
                    & $psExe -NoProfile -ExecutionPolicy Bypass -Command `
                        '$global:AtlEmitCaseCount=$true; & $env:ATL_CASE_TEST_PATH; exit $global:LASTEXITCODE' *> $log
                } else {
                    & $psExe -NoProfile -ExecutionPolicy Bypass -File $path *> $log
                }
                $LASTEXITCODE
            }
            $jobs += [pscustomobject]@{ Name = $f.Name; Log = $log; Job = $job }
        }
        $jobs.Job | Wait-Job | Out-Null
        foreach ($entry in $jobs) {
            Write-Host ("--- {0} ---" -f $entry.Name)
            $text = [IO.File]::ReadAllText($entry.Log)
            Write-Host -NoNewline $text
            $exit = Receive-Job $entry.Job
            # A child that died without producing an exit code must count as a failure, not as zero.
            if ($null -eq $exit) { $exit = 1 }
            Write-FileResult $entry.Name ([int]$exit)
            Write-FileTiming $entry.Name $entry.Job.PSBeginTime $entry.Job.PSEndTime
            $total += [int]$exit
            if ($CaseCountPath) {
                try { $caseCounts[$entry.Name] = Read-CaseCount -Name $entry.Name -Text $text }
                catch { [Console]::Error.WriteLine("CASE CARDINALITY REFUSED: $($_.Exception.Message)"); $total++ }
            }
        }
    } finally {
        if ($jobs) {
            $jobs.Job | Remove-Job -Force -ErrorAction SilentlyContinue
            $jobs.Log | Where-Object { Test-Path -LiteralPath $_ } | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
}
if ($CaseCountPath) {
    if ($caseCounts.Count -ne $files.Count) {
        [Console]::Error.WriteLine("CASE CARDINALITY REFUSED: collected $($caseCounts.Count) of $($files.Count) per-file counts")
        $total++
    } else {
        try { Write-CaseCountManifest -Path $CaseCountPath -Counts $caseCounts }
        catch { [Console]::Error.WriteLine("CASE CARDINALITY REFUSED: $($_.Exception.Message)"); $total++ }
    }
}
Write-Host ("=== Meta-hook test suite: {0} failure(s) across {1} file(s) ===" -f $total, $files.Count)
exit $total
