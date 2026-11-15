# CI-only semantic case-count decision: every PowerShell 7 suite leg published a well-formed manifest with a nonzero
# count for each suite, and the meta suite's shards together ran each of its test files exactly once. Maintainer-only;
# does not ship.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ArtifactRoot,
    # The meta suite's test files; the shards' manifests must name each exactly once. Case counts alone cannot see a
    # file that ran in no shard (B-510).
    [string]$MetaTestRoot = (Join-Path $PSScriptRoot '..\hooks\tests')
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

$legs = @(
    [pscustomobject]@{ Name = 'meta-1'; Artifact = 'b219-case-counts-windows-meta-1'; File = 'windows-meta-1-case-counts.txt'; Meta = $true }
    [pscustomobject]@{ Name = 'meta-2'; Artifact = 'b219-case-counts-windows-meta-2'; File = 'windows-meta-2-case-counts.txt'; Meta = $true }
    [pscustomobject]@{ Name = 'meta-3'; Artifact = 'b219-case-counts-windows-meta-3'; File = 'windows-meta-3-case-counts.txt'; Meta = $true }
    [pscustomobject]@{ Name = 'dotnet'; Artifact = 'b219-case-counts-windows-hooks-dotnet'; File = 'windows-hooks-dotnet-case-counts.txt'; Meta = $false }
    [pscustomobject]@{ Name = 'angular'; Artifact = 'b219-case-counts-windows-hooks-angular'; File = 'windows-hooks-angular-case-counts.txt'; Meta = $false }
    [pscustomobject]@{ Name = 'monorepo'; Artifact = 'b219-case-counts-windows-hooks-monorepo'; File = 'windows-hooks-monorepo-case-counts.txt'; Meta = $false }
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
    Stop-Wrong "expected exactly six case-count artifacts. expected=[$($expectedArtifacts -join ', ')]; actual=[$($actualArtifacts -join ', ')]"
}
foreach ($artifact in $expectedArtifacts) {
    $artifactPath = Join-Path $ArtifactRoot $artifact
    try { $attributes = [IO.File]::GetAttributes($artifactPath) }
    catch { Stop-CantVerify "could not inspect artifact '$artifact': $($_.Exception.Message)" }
    if (($attributes -band [IO.FileAttributes]::Directory) -eq 0) {
        Stop-Wrong "artifact '$artifact' is not a directory"
    }
}

$metaShardOf = @{}
foreach ($leg in $legs) {
    $suites = Get-ManifestSuites $leg.Artifact $leg.File
    if (-not $leg.Meta) { continue }
    foreach ($suite in $suites) {
        if ($metaShardOf.ContainsKey($suite)) { Stop-Wrong "meta suite '$suite' ran in both $($metaShardOf[$suite]) and $($leg.Name)" }
        $metaShardOf[$suite] = $leg.Name
    }
}

try {
    $metaFiles = @([IO.Directory]::GetFiles([IO.Path]::GetFullPath($MetaTestRoot)) | ForEach-Object { [IO.Path]::GetFileName($_) } |
        Where-Object { $_.EndsWith('.Tests.ps1', [StringComparison]::Ordinal) } | Sort-Object)
} catch { Stop-CantVerify "could not list the meta test files in '$MetaTestRoot': $($_.Exception.Message)" }
if ($metaFiles.Count -eq 0) { Stop-CantVerify "no meta test files in '$MetaTestRoot' to compare the shards with" }
$inNoShard = @($metaFiles | Where-Object { -not $metaShardOf.ContainsKey($_) })
if ($inNoShard.Count -gt 0) { Stop-Wrong "meta test file(s) ran in no shard: $($inNoShard -join ', ')" }
$notInRoot = @($metaShardOf.Keys | Where-Object { $metaFiles -cnotcontains $_ } | Sort-Object)
if ($notInRoot.Count -gt 0) { Stop-Wrong "meta shards ran suite(s) that are not in '$MetaTestRoot': $($notInRoot -join ', ')" }

Write-Host "CI CASE PARITY GREEN: six nonempty, valid PowerShell 7 case-count manifests; the meta shards ran each of the $($metaFiles.Count) meta test files exactly once."
exit 0
