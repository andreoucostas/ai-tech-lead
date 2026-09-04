# Suite entry point -- runs every *.Tests.ps1 in this directory as an isolated PowerShell process and
# exits with the TOTAL number of failures (0 = green).
# Usage:  pwsh -NoProfile -File tests/hooks/Invoke-HookTests.ps1
[CmdletBinding()]
param([switch]$FixtureDiscovery, [string]$CaseCountPath)
$ErrorActionPreference = 'Stop'
if ($CaseCountPath -and (Test-Path -LiteralPath $CaseCountPath)) {
    [Console]::Error.WriteLine("CASE CARDINALITY REFUSED: output path already exists: $CaseCountPath")
    exit 2
}
$invokingPsExe = (Get-Process -Id $PID).Path
$psExe = $invokingPsExe

# Prove the executable handed to every suite really preserves this runner's host. This runtime
# assertion prevents a future resolver or wrapper from turning an explicit Windows PowerShell 5.1
# run into pwsh 7 and silently erasing 5.1-only coverage.
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
    'BuildArchitectureHtml.Tests.ps1',
    'FrameworkDoctor.Tests.ps1',
    'Guard.Tests.ps1',
    'HarnessIntegrity.Tests.ps1',
    'HazardCheck.Tests.ps1',
    'PostWrite.Tests.ps1',
    'PostWriteRouting.Tests.ps1',
    'PowerShellSemantics.Tests.ps1',
    'RoutePrompt.Tests.ps1',
    'ScriptBehavior.Tests.ps1',
    'SecurityReviewContract.Tests.ps1',
    'SessionStartFrameworkRules.Tests.ps1',
    'SessionStartHazard.Tests.ps1',
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
# Lane count. This suite is bound by process creation, not CPU: every assertion spawns a fresh
# PowerShell child so the hook is exercised as a real process with a real exit code. A fixed 4 left
# most of a modern box idle. HOOKTESTS_THROTTLE lets a caller that runs several suites at once
# hand each one a share instead of every suite assuming it owns the machine -- without it, three
# concurrent suites at 4 lanes each oversubscribe and every lane gets slower.
# ([Environment]::ProcessorCount and this if/else chain are 5.1-safe.)
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
        $index = $next
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
        Write-Host ("TIMING {0} {1:N1}" -f $f.Name, ($result.End - $result.Begin).TotalSeconds)
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
