# CI-only semantic case-count decision: every PowerShell 7 suite leg published a well-formed manifest with a nonzero
# count for each suite, the meta suite's shards together ran each of its test files exactly once, and each dist's hook
# shards together ran each of that dist's shipped hook test files exactly once. Maintainer-only; does not ship.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ArtifactRoot,
    # The meta suite's test files; the shards' manifests must name each exactly once. Case counts alone cannot see a
    # file that ran in no shard (B-510).
    [string]$MetaTestRoot = (Join-Path $PSScriptRoot '..\hooks\tests'),
    # The composed dists; each dist's tests/hooks files must be named exactly once by that dist's hook shards.
    [string]$DistRoot = (Join-Path $PSScriptRoot '..\..\dist')
)

$ErrorActionPreference = 'Stop'
$EXIT_WRONG = 1
$EXIT_CANT = 3

function Stop-Wrong {
    param([string]$Message)
    Write-Host "CI CASE PARITY WRONG: $Message"
    exit $EXIT_WRONG
}

function Stop-CantVerify {
    param([string]$Message)
    [Console]::Error.WriteLine("CI CASE PARITY CANT-VERIFY: $Message")
    exit $EXIT_CANT
}

# The shard counts ci.yml's two matrices run; a leg either side adds or drops is an artifact set that differs.
$metaShardCount = 4
$hookShardCount = 2
$dists = @('dotnet', 'angular', 'monorepo')
# Each group is one suite whose shards must together name each of its test files once.
$groups = [ordered]@{ meta = [pscustomobject]@{ Label = 'meta'; Root = $MetaTestRoot } }
foreach ($dist in $dists) {
    $groups[$dist] = [pscustomobject]@{ Label = "$dist hook"; Root = (Join-Path (Join-Path $DistRoot $dist) 'tests\hooks') }
}
$legs = @(
    foreach ($i in 1..$metaShardCount) {
        [pscustomobject]@{ Name = "meta-$i"; Artifact = "b219-case-counts-windows-meta-$i"; File = "windows-meta-$i-case-counts.txt"; Group = 'meta' }
    }
    foreach ($dist in $dists) {
        foreach ($i in 1..$hookShardCount) {
            [pscustomobject]@{ Name = "$dist-$i"; Artifact = "b219-case-counts-windows-hooks-$dist-$i"; File = "windows-hooks-$dist-$i-case-counts.txt"; Group = $dist }
        }
    }
)

# Returns the suite names the manifest lists.
function Get-ManifestSuites {
    param([string]$ArtifactName, [string]$FileName)

    $artifactPath = Join-Path $ArtifactRoot $ArtifactName
    try {
        $entries = @([IO.Directory]::GetFileSystemEntries($artifactPath))
    } catch [IO.DirectoryNotFoundException] {
        Stop-Wrong "required artifact '$ArtifactName' is missing"
    } catch {
        Stop-CantVerify "could not enumerate artifact '$ArtifactName': $($_.Exception.Message)"
    }
    if ($entries.Count -ne 1 -or [IO.Path]::GetFileName($entries[0]) -cne $FileName) {
        Stop-Wrong "artifact '$ArtifactName' must contain exactly '$FileName'; found $($entries.Count) entry/entries"
    }

    $filePath = Join-Path $artifactPath $FileName
    try { $attributes = [IO.File]::GetAttributes($filePath) }
    catch { Stop-CantVerify "could not inspect '$ArtifactName/$FileName': $($_.Exception.Message)" }
    if (($attributes -band [IO.FileAttributes]::Directory) -ne 0) {
        Stop-Wrong "artifact '$ArtifactName' contains a directory where manifest '$FileName' is required"
    }
    try { $bytes = [IO.File]::ReadAllBytes($filePath) }
    catch { Stop-CantVerify "could not read '$ArtifactName/$FileName': $($_.Exception.Message)" }
    if ($bytes.Length -eq 0) { Stop-Wrong "manifest '$ArtifactName/$FileName' is empty" }

    try { $text = (New-Object Text.UTF8Encoding($false, $true)).GetString($bytes) }
    catch { Stop-Wrong "manifest '$ArtifactName/$FileName' is not valid UTF-8" }
    $lines = @($text -split "`r?`n")
    if ($lines.Count -gt 0 -and $lines[-1] -eq '') { $lines = @($lines[0..($lines.Count - 2)]) }
    if ($lines.Count -lt 2) { Stop-Wrong "manifest '$ArtifactName/$FileName' has no suite rows and TOTAL" }

    $names = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    [long]$sum = 0
    for ($i = 0; $i -lt $lines.Count - 1; $i++) {
        $m = [regex]::Match($lines[$i], '^(?<name>[^\t]+\.Tests\.ps1)\t(?<count>[1-9]\d*)$')
        if (-not $m.Success) { Stop-Wrong "manifest '$ArtifactName/$FileName' has malformed suite row $($i + 1)" }
        if (-not $names.Add($m.Groups['name'].Value)) { Stop-Wrong "manifest '$ArtifactName/$FileName' repeats suite '$($m.Groups['name'].Value)'" }
        [long]$count = 0
        if (-not [long]::TryParse($m.Groups['count'].Value, [ref]$count) -or $count -le 0 -or $sum -gt ([long]::MaxValue - $count)) {
            Stop-Wrong "manifest '$ArtifactName/$FileName' has an invalid suite count"
        }
        $sum += $count
    }
    $totalMatch = [regex]::Match($lines[-1], '^TOTAL\t(?<total>[1-9]\d*)$')
    [long]$total = 0
    if (-not $totalMatch.Success -or -not [long]::TryParse($totalMatch.Groups['total'].Value, [ref]$total) -or $total -ne $sum) {
        Stop-Wrong "manifest '$ArtifactName/$FileName' has a missing, non-positive, or incorrect TOTAL"
    }
    return ,([string[]]@($names))
}

try { $artifactRootPath = [IO.Path]::GetFullPath($ArtifactRoot) }
catch { Stop-CantVerify "could not resolve artifact root '$ArtifactRoot': $($_.Exception.Message)" }
$ArtifactRoot = $artifactRootPath
try { $rootEntries = @([IO.Directory]::GetFileSystemEntries($ArtifactRoot)) }
catch [IO.DirectoryNotFoundException] { Stop-Wrong "artifact root '$ArtifactRoot' is missing" }
catch { Stop-CantVerify "could not enumerate artifact root '$ArtifactRoot': $($_.Exception.Message)" }
$actualArtifacts = @($rootEntries | ForEach-Object { [IO.Path]::GetFileName($_) } | Sort-Object)
$expectedArtifacts = @($legs | ForEach-Object { $_.Artifact } | Sort-Object)
if (($actualArtifacts -join "`n") -cne ($expectedArtifacts -join "`n")) {
    Stop-Wrong "expected exactly $($legs.Count) case-count artifacts. expected=[$($expectedArtifacts -join ', ')]; actual=[$($actualArtifacts -join ', ')]"
}
foreach ($artifact in $expectedArtifacts) {
    $artifactPath = Join-Path $ArtifactRoot $artifact
    try { $attributes = [IO.File]::GetAttributes($artifactPath) }
    catch { Stop-CantVerify "could not inspect artifact '$artifact': $($_.Exception.Message)" }
    if (($attributes -band [IO.FileAttributes]::Directory) -eq 0) {
        Stop-Wrong "artifact '$artifact' is not a directory"
    }
}

$shardOf = @{}
foreach ($groupName in $groups.Keys) { $shardOf[$groupName] = @{} }
foreach ($leg in $legs) {
    $suites = Get-ManifestSuites $leg.Artifact $leg.File
    $seen = $shardOf[$leg.Group]
    foreach ($suite in $suites) {
        if ($seen.ContainsKey($suite)) { Stop-Wrong "$($groups[$leg.Group].Label) suite '$suite' ran in both $($seen[$suite]) and $($leg.Name)" }
        $seen[$suite] = $leg.Name
    }
}

$covered = @()
foreach ($groupName in $groups.Keys) {
    $group = $groups[$groupName]
    $seen = $shardOf[$groupName]
    try {
        $testFiles = @([IO.Directory]::GetFiles([IO.Path]::GetFullPath($group.Root)) | ForEach-Object { [IO.Path]::GetFileName($_) } |
            Where-Object { $_.EndsWith('.Tests.ps1', [StringComparison]::Ordinal) } | Sort-Object)
    } catch { Stop-CantVerify "could not list the $($group.Label) test files in '$($group.Root)': $($_.Exception.Message)" }
    if ($testFiles.Count -eq 0) { Stop-CantVerify "no $($group.Label) test files in '$($group.Root)' to compare the shards with" }
    $inNoShard = @($testFiles | Where-Object { -not $seen.ContainsKey($_) })
    if ($inNoShard.Count -gt 0) { Stop-Wrong "$($group.Label) test file(s) ran in no shard: $($inNoShard -join ', ')" }
    $notInRoot = @($seen.Keys | Where-Object { $testFiles -cnotcontains $_ } | Sort-Object)
    if ($notInRoot.Count -gt 0) { Stop-Wrong "$($group.Label) shards ran suite(s) that are not in '$($group.Root)': $($notInRoot -join ', ')" }
    $covered += "$($testFiles.Count) $($group.Label)"
}

Write-Host "CI CASE PARITY GREEN: $($legs.Count) nonempty, valid PowerShell 7 case-count manifests; each suite's shards ran each of its test files exactly once ($($covered -join ', '))."
exit 0
