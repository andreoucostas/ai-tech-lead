# CI-only same-platform semantic case-count decision. Maintainer-only; does not ship.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ArtifactRoot)

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

$pairs = @(
    [pscustomobject]@{ Name = 'root'; Ps7Artifact = 'b219-case-counts-windows'; Ps7File = 'windows-case-counts.txt'; Ps51Artifact = 'b219-case-counts-windows-ps51'; Ps51File = 'windows-ps51-case-counts.txt' }
    [pscustomobject]@{ Name = 'dotnet'; Ps7Artifact = 'b219-case-counts-windows-hooks-dotnet'; Ps7File = 'windows-hooks-dotnet-case-counts.txt'; Ps51Artifact = 'b219-case-counts-windows-hooks-ps51-dotnet'; Ps51File = 'windows-hooks-ps51-dotnet-case-counts.txt' }
    [pscustomobject]@{ Name = 'angular'; Ps7Artifact = 'b219-case-counts-windows-hooks-angular'; Ps7File = 'windows-hooks-angular-case-counts.txt'; Ps51Artifact = 'b219-case-counts-windows-hooks-ps51-angular'; Ps51File = 'windows-hooks-ps51-angular-case-counts.txt' }
    [pscustomobject]@{ Name = 'monorepo'; Ps7Artifact = 'b219-case-counts-windows-hooks-monorepo'; Ps7File = 'windows-hooks-monorepo-case-counts.txt'; Ps51Artifact = 'b219-case-counts-windows-hooks-ps51-monorepo'; Ps51File = 'windows-hooks-ps51-monorepo-case-counts.txt' }
)

function Get-ManifestBytes {
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
    return ,$bytes
}

try { $artifactRootPath = [IO.Path]::GetFullPath($ArtifactRoot) }
catch { Stop-CantVerify "could not resolve artifact root '$ArtifactRoot': $($_.Exception.Message)" }
$ArtifactRoot = $artifactRootPath
try { $rootEntries = @([IO.Directory]::GetFileSystemEntries($ArtifactRoot)) }
catch [IO.DirectoryNotFoundException] { Stop-Wrong "artifact root '$ArtifactRoot' is missing" }
catch { Stop-CantVerify "could not enumerate artifact root '$ArtifactRoot': $($_.Exception.Message)" }
$actualArtifacts = @($rootEntries | ForEach-Object { [IO.Path]::GetFileName($_) } | Sort-Object)
$expectedArtifacts = @($pairs | ForEach-Object { $_.Ps7Artifact; $_.Ps51Artifact } | Sort-Object)
if (($actualArtifacts -join "`n") -cne ($expectedArtifacts -join "`n")) {
    Stop-Wrong "expected exactly eight case-count artifacts. expected=[$($expectedArtifacts -join ', ')]; actual=[$($actualArtifacts -join ', ')]"
}
foreach ($artifact in $expectedArtifacts) {
    $artifactPath = Join-Path $ArtifactRoot $artifact
    try { $attributes = [IO.File]::GetAttributes($artifactPath) }
    catch { Stop-CantVerify "could not inspect artifact '$artifact': $($_.Exception.Message)" }
    if (($attributes -band [IO.FileAttributes]::Directory) -eq 0) {
        Stop-Wrong "artifact '$artifact' is not a directory"
    }
}

foreach ($pair in $pairs) {
    $ps7 = Get-ManifestBytes $pair.Ps7Artifact $pair.Ps7File
    $ps51 = Get-ManifestBytes $pair.Ps51Artifact $pair.Ps51File
    if ([Convert]::ToBase64String($ps7) -cne [Convert]::ToBase64String($ps51)) {
        Stop-Wrong "PS7 and PS5.1 '$($pair.Name)' semantic case cardinality differ"
    }
}

Write-Host 'CI CASE PARITY GREEN: four nonempty, valid PS7/PS5.1 manifest pairs are byte-identical.'
exit 0
