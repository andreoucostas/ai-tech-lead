# Suite entry point -- runs every *.Tests.ps1 in this directory as an isolated PowerShell process and
# exits with the TOTAL number of failures (0 = green).
# Usage:  pwsh -NoProfile -File tests/hooks/Invoke-HookTests.ps1 [-ShardCount N -ShardIndex I]
# -ShardCount N -ShardIndex I runs bin I of a longest-first partition of the files into N bins by
# $costHint; every file lands in exactly one bin, so N runs with I = 1..N together run each file once.
[CmdletBinding()]
param([switch]$FixtureDiscovery, [string]$CaseCountPath, [int]$ShardCount = 1, [int]$ShardIndex = 1)
$ErrorActionPreference = 'Stop'
if ($CaseCountPath -and (Test-Path -LiteralPath $CaseCountPath)) {
    [Console]::Error.WriteLine("CASE CARDINALITY REFUSED: output path already exists: $CaseCountPath")
    exit 2
}
if ($ShardCount -lt 1 -or $ShardIndex -lt 1 -or $ShardIndex -gt $ShardCount) {
    [Console]::Error.WriteLine("Invalid shard: -ShardIndex $ShardIndex of -ShardCount $ShardCount")
    exit 2
}
$invokingPsExe = (Get-Process -Id $PID).Path
$psExe = $invokingPsExe

# Prove the executable handed to every suite really preserves this runner's host, so no resolver or
# wrapper can run a suite under another PowerShell than the one this runner was started with.
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
    'AuditTrail.Tests.ps1',
    'BootstrapBaseline.Tests.ps1',
    'FrameworkDoctor.Tests.ps1',
    'Guard.Tests.ps1',
    'Guard2.Tests.ps1',
    'HarnessIntegrity.Tests.ps1',
    'HazardCheck.Tests.ps1',
    'PostWrite.Tests.ps1',
    'PostWriteRouting.Tests.ps1',
    'PowerShellSemantics.Tests.ps1',
    'ReviewScope.Tests.ps1',
    'RoutePrompt.Tests.ps1',
    'ScriptBehavior.Tests.ps1',
    'SecurityReviewContract.Tests.ps1',
    'SessionStartFrameworkRules.Tests.ps1',
    'SessionStartHazard.Tests.ps1',
    'SessionStartTestEntryPoints.Tests.ps1',
    'SessionStartVersionAwareness.Tests.ps1',
    'SessionStartWiki.Tests.ps1',
    'TestWeakeningScan.Tests.ps1',
    'WarehouseMapCheck.Tests.ps1',
    'WikiCheck.Tests.ps1'
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
# MEASURED COST, seconds: each file's TIMING line from one run of the whole monorepo suite at 4 lanes
# (HOOKTESTS_THROTTLE=4, as on a 4-vCPU CI runner), 2026-11-16; the two Guard files share that run's
# 553.0 s for Guard.Tests.ps1 by a per-case timing of its cases (50.4 / 49.6%). Re-measure from CI's
# TIMING lines (HOOKTESTS_TIMING) when they drift. A HINT for launch order and shard bins, never
# correctness: a stale entry costs time, not a result. An unlisted file is priced as the dearest
# listed one, so it launches early rather than last.
$costHint = @{
    'Guard.Tests.ps1'                       = 278.7
    'Guard2.Tests.ps1'                      = 274.3
    'FrameworkDoctor.Tests.ps1'             = 167.2
    'BootstrapBaseline.Tests.ps1'           = 142.0
    'HazardCheck.Tests.ps1'                 = 94.8
    'PostWriteRouting.Tests.ps1'            = 60.7
    'ReviewScope.Tests.ps1'                 = 51.0
    'TestWeakeningScan.Tests.ps1'           = 45.3
    'RoutePrompt.Tests.ps1'                 = 39.5
    'SessionStartTestEntryPoints.Tests.ps1' = 39.5
    'ScriptBehavior.Tests.ps1'              = 35.9
    'PowerShellSemantics.Tests.ps1'         = 21.9
    'WarehouseMapCheck.Tests.ps1'           = 21.2
    'AuditTrail.Tests.ps1'                  = 20.9
    'HarnessIntegrity.Tests.ps1'            = 19.0
    'SessionStartWiki.Tests.ps1'            = 16.6
    'SessionStartHazard.Tests.ps1'          = 12.1
    'WikiCheck.Tests.ps1'                   = 10.7
    'SessionStartFrameworkRules.Tests.ps1'  = 9.5
    'SessionStartVersionAwareness.Tests.ps1' = 4.3
    'PostWrite.Tests.ps1'                   = 0.9
    'SecurityReviewContract.Tests.ps1'      = 0.8
}
$unlistedCost = [double](($costHint.Values | Measure-Object -Maximum).Maximum)
function Get-FileCost([string]$Name) { if ($costHint.ContainsKey($Name)) { [double]$costHint[$Name] } else { $unlistedCost } }
$byCost = @(
    @{ Expression = { Get-FileCost $_.Name }; Descending = $true },
    @{ Expression = { $_.Name }; Ascending = $true }
)
if ($ShardCount -gt 1) {
    # Longest-processing-time partition: dearest file first, each into the bin with the least cost so
    # far (ties to the lower bin), cost ties broken by name, so every run computes the same bins and
    # each file lands in exactly one.
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
    Write-Host ([string]::Format([cultureinfo]::InvariantCulture, 'SHARD {0}/{1}: {2} file(s), {3:F0} s measured: {4}',
        $ShardIndex, $ShardCount, $files.Count, $load[$ShardIndex - 1], (@($files.Name) -join ', ')))
}
# LONGEST-FIRST launch, names breaking ties: a long file launched last runs alone at the tail while
# the other lanes idle. Output still prints in name order below.
$launchOrder = @($files | Sort-Object $byCost | ForEach-Object { [array]::IndexOf($files, $_) })
# Lane count. This suite is bound by process creation, not CPU: every assertion spawns a fresh
# PowerShell child so the hook is exercised as a real process with a real exit code. A fixed 4 left
# most of a modern box idle. HOOKTESTS_THROTTLE lets a caller that runs several suites at once
# hand each one a share instead of every suite assuming it owns the machine -- without it, three
# concurrent suites at 4 lanes each oversubscribe and every lane gets slower.
if ($env:HOOKTESTS_THROTTLE) { $throttle = [int]$env:HOOKTESTS_THROTTLE }
else { $throttle = [Environment]::ProcessorCount }
if ($throttle -lt 2) { $throttle = 2 } elseif ($throttle -gt 8) { $throttle = 8 }
$next = 0
$running = @()
$results = @{}

function Read-CaseCount {
    param([Parameter(Mandatory)][string]$Name, [AllowEmptyString()][string]$Text)
    $matches = [regex]::Matches($Text, '(?m)^CASE_COUNT ([0-9]+)\r?$')
    if ($matches.Count -ne 1) { throw "$Name emitted $($matches.Count) CASE_COUNT markers; expected exactly one" }
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

while ($next -lt $files.Count -or $running.Count -gt 0) {
    while ($next -lt $files.Count -and $running.Count -lt $throttle) {
        $index = $launchOrder[$next]
        $file = $files[$index]
        $running += Start-Job -ArgumentList $psExe, $file.FullName, $index, ([bool]$CaseCountPath) -ScriptBlock {
            param($exe, $path, $resultIndex, $emitCaseCount)
            $began = Get-Date
            $output = if ($emitCaseCount) {
                $env:ATL_CASE_TEST_PATH = $path
                @(& $exe -NoProfile -ExecutionPolicy Bypass -Command `
                    '$global:AtlEmitCaseCount=$true; & $env:ATL_CASE_TEST_PATH; exit $global:LASTEXITCODE' 2>&1 |
                    ForEach-Object { $_.ToString() })
            } else {
                @(& $exe -NoProfile -ExecutionPolicy Bypass -File $path 2>&1 |
                    ForEach-Object { $_.ToString() })
            }
            [pscustomobject]@{
                Index    = $resultIndex
                ExitCode = [int]$LASTEXITCODE
                Output   = $output
                Begin    = $began
                End      = Get-Date
            }
        }
        $next++
    }

    $done = $running | Wait-Job -Any
    $result = Receive-Job -Job $done
    $results[[int]$result.Index] = $result
    $running = @($running | Where-Object Id -ne $done.Id)
    Remove-Job -Job $done
}

$total = 0
$caseCounts = @{}
for ($i = 0; $i -lt $files.Count; $i++) {
    $f = $files[$i]
    $result = $results[$i]
    Write-Host ("--- {0} ---" -f $f.Name)
    foreach ($line in $result.Output) { Write-Host $line }
    if ($env:HOOKTESTS_TIMING) {
        # F1 in the invariant culture, never N1 or `-f`: N1 groups thousands in every culture and `-f`
        # writes the current culture's decimal comma. Grammar: ^TIMING \S+ \d+\.\d$
        Write-Host ([string]::Format([cultureinfo]::InvariantCulture, 'TIMING {0} {1:F1}', $f.Name, ($result.End - $result.Begin).TotalSeconds))
    }
    $total += [int]$result.ExitCode
    if ($CaseCountPath) {
        $text = ($result.Output -join "`n")
        try { $caseCounts[$f.Name] = Read-CaseCount -Name $f.Name -Text $text }
        catch { [Console]::Error.WriteLine("CASE CARDINALITY REFUSED: $($_.Exception.Message)"); $total++ }
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
Write-Host ("=== Hook test suite: {0} failure(s) across {1} file(s) ===" -f $total, $files.Count)
exit $total
