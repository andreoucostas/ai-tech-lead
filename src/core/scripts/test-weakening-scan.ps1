# Reports assertion-shaped removals from one immutable review-scope bundle.
# Usage:
#   pwsh -NoProfile -File scripts/test-weakening-scan.ps1 -ScopePath <bundle>
#   pwsh -NoProfile -File scripts/test-weakening-scan.ps1 [<A..B|A...B>]
# With no argument, captures and scans one private snapshot of all uncommitted layers. Findings and
# valid no-signal remain advisory exit 0; invalid bundles exit 2; inability to examine exits 3.
# LIMIT: this counts assertion-shaped lines. It cannot distinguish a weakened assertion from a
# legitimate refactor and is not enforcement.
[CmdletBinding()]
param(
    [string]$ScopePath,
    [string]$PathFile,
    [Parameter(Position = 0)][string]$LegacyRange
)
$ErrorActionPreference = 'Stop'
$assertionShape = 'Assert|expect\s*\(|Should|\.Verify\s*\(|\[(Fact|Test)\b|\bit\s*\(|\bdescribe\s*\('

function Read-ReviewScopeBundle {
    param([string]$BundlePath)
    if ([string]::IsNullOrWhiteSpace($BundlePath)) { throw 'INVALID: -ScopePath cannot be empty.' }
    $bundleFull = [IO.Path]::GetFullPath($BundlePath).TrimEnd('\','/')
    try { $bundleEntry = Get-Item -Force -LiteralPath $bundleFull -ErrorAction Stop }
    catch [System.Management.Automation.ItemNotFoundException] { $bundleEntry = $null }
    catch { throw "CANNOT EXAMINE: could not inspect review scope '$BundlePath': $($_.Exception.Message)" }
    if (-not $bundleEntry -or -not $bundleEntry.PSIsContainer -or (($bundleEntry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
        throw "INVALID: review scope is not a regular directory: '$BundlePath'."
    }
    $manifestPath = Join-Path $bundleFull 'manifest.json'
    try { $manifestEntry = Get-Item -Force -LiteralPath $manifestPath -ErrorAction Stop }
    catch [System.Management.Automation.ItemNotFoundException] { $manifestEntry = $null }
    catch { throw "CANNOT EXAMINE: could not inspect review manifest: $($_.Exception.Message)" }
    if (-not $manifestEntry -or $manifestEntry.PSIsContainer -or (($manifestEntry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
        throw 'INVALID: review scope has no regular manifest.json.'
    }
    try { $manifestText = [IO.File]::ReadAllText($manifestPath, [Text.Encoding]::UTF8) }
    catch { throw "CANNOT EXAMINE: could not read review manifest: $($_.Exception.Message)" }
    try { $manifest = $manifestText.TrimStart([char]0xFEFF) | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "INVALID: review manifest is not valid JSON: $($_.Exception.Message)" }
    if ($manifest.formatVersion -ne 1 -or $manifest.mode -notin @('Uncommitted','Range','WholeFile') -or
        $null -eq $manifest.artifacts -or $null -eq $manifest.layers -or $null -eq $manifest.selection) {
        throw 'INVALID: review manifest has an unsupported or incomplete shape.'
    }
    $artifacts = New-Object 'System.Collections.Generic.List[object]'
    $declared = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($record in @($manifest.artifacts)) {
        $relative = [string]$record.path
        $expectedHash = [string]$record.sha256
        if ([string]::IsNullOrWhiteSpace($relative) -or $relative.Contains('\') -or $relative.Contains([char]0) -or
            $relative.StartsWith('/') -or $relative -match '^[A-Za-z]:' -or $relative.Contains('"') -or
            $expectedHash -notmatch '^[0-9a-f]{64}$') {
            throw "INVALID: review manifest contains an unsafe artifact record '$relative'."
        }
        $segments = @($relative.Split('/'))
        if (@($segments | Where-Object { [string]::IsNullOrEmpty($_) -or $_ -eq '.' -or $_ -eq '..' }).Count -gt 0) {
            throw "INVALID: review manifest artifact escapes its bundle: '$relative'."
        }
        if (-not $declared.Add($relative)) { throw "INVALID: duplicate review artifact '$relative'." }
        $full = [IO.Path]::GetFullPath((Join-Path $bundleFull ($relative -replace '/', [IO.Path]::DirectorySeparatorChar)))
        $prefix = $bundleFull + [IO.Path]::DirectorySeparatorChar
        if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "INVALID: review artifact escapes its bundle: '$relative'."
        }
        $cursor = $full
        while (-not [string]::Equals($cursor, $bundleFull, [StringComparison]::OrdinalIgnoreCase)) {
            try { $entry = Get-Item -Force -LiteralPath $cursor -ErrorAction Stop }
            catch [System.Management.Automation.ItemNotFoundException] { $entry = $null }
            catch { throw "CANNOT EXAMINE: could not inspect review artifact '$relative': $($_.Exception.Message)" }
            if ($entry -and (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
                throw "INVALID: review artifact traverses a reparse point: '$relative'."
            }
            $cursor = Split-Path -Parent $cursor
        }
        try { $entry = Get-Item -Force -LiteralPath $full -ErrorAction Stop }
        catch [System.Management.Automation.ItemNotFoundException] { $entry = $null }
        catch { throw "CANNOT EXAMINE: could not inspect review artifact '$relative': $($_.Exception.Message)" }
        if (-not $entry -or $entry.PSIsContainer) { throw "INVALID: declared review artifact is missing or not a regular file: '$relative'." }
        try {
            $bytes = [IO.File]::ReadAllBytes($full)
            $sha = [Security.Cryptography.SHA256]::Create()
            try { $actualHash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() }
            finally { $sha.Dispose() }
            if ($actualHash -cne $expectedHash -or [int64]$bytes.Length -ne [int64]$record.size) {
                throw "INVALID: review artifact hash or size does not match manifest: '$relative'."
            }
        } catch {
            if ($_.Exception.Message.StartsWith('INVALID:', [StringComparison]::Ordinal)) { throw }
            throw "CANNOT EXAMINE: could not read or hash review artifact '$relative': $($_.Exception.Message)"
        }
        $artifacts.Add([pscustomobject]@{ Path = $relative; Bytes = $bytes }) | Out-Null
    }
    try {
        $actualFiles = @(Get-ChildItem -Force -LiteralPath $bundleFull -File -Recurse -ErrorAction Stop | ForEach-Object {
            $_.FullName.Substring($bundleFull.Length + 1).Replace('\','/')
        } | Sort-Object)
    } catch { throw "CANNOT EXAMINE: could not enumerate review bundle: $($_.Exception.Message)" }
    $expectedFiles = @('manifest.json') + @($declared | Sort-Object)
    $unexpected = @($actualFiles | Where-Object { $_ -cnotin $expectedFiles })
    $missing = @($expectedFiles | Where-Object { $_ -cnotin $actualFiles })
    if ($unexpected.Count -gt 0 -or $missing.Count -gt 0) {
        throw "INVALID: review bundle file inventory differs from its manifest; missing=[$($missing -join ', ')]; unexpected=[$($unexpected -join ', ')]."
    }
    $layerNames = @($manifest.layers | ForEach-Object { [string]$_.name })
    if (@($layerNames | Sort-Object -Unique).Count -ne $layerNames.Count) { throw 'INVALID: review manifest has duplicate layer names.' }
    $expectedLayers = if ($manifest.mode -eq 'Uncommitted') { @('staged','unstaged','untracked') } elseif ($manifest.mode -eq 'Range') { @('range') } else { @('whole') }
    if (($layerNames -join ',') -cne ($expectedLayers -join ',')) {
        throw "INVALID: review manifest layers do not match mode '$($manifest.mode)'."
    }
    if ($manifest.mode -eq 'Range') {
        if ($manifest.rangeKind -notin @('TwoDot','ThreeDot') -or [string]$manifest.resolvedBase -notmatch '^(?:[0-9a-f]{40}|[0-9a-f]{64})$' -or
            [string]$manifest.resolvedHead -notmatch '^(?:[0-9a-f]{40}|[0-9a-f]{64})$' -or [string]$manifest.effectiveBase -notmatch '^(?:[0-9a-f]{40}|[0-9a-f]{64})$') {
            throw 'INVALID: range review manifest has incomplete endpoint evidence.'
        }
    } elseif ([string]$manifest.resolvedHead -notmatch '^(?:[0-9a-f]{40}|[0-9a-f]{64})$') {
        throw 'INVALID: review manifest has no resolved HEAD evidence.'
    }
    foreach ($layer in @($manifest.layers)) {
        if ($layer.name -in @('staged','unstaged','range')) {
            $expectedArtifact = "$($layer.name).patch"
            if ([string]$layer.artifact -cne $expectedArtifact -or -not $declared.Contains($expectedArtifact)) {
                throw "INVALID: patch layer '$($layer.name)' does not identify its required artifact."
            }
        }
        if ($null -eq $layer.paths) { throw "INVALID: layer '$($layer.name)' has no path inventory." }
    }
    foreach ($selected in @($manifest.selection)) {
        $selectionPath = [string]$selected.path
        $selectionLayer = [string]$selected.layer
        if ([string]::IsNullOrWhiteSpace($selectionPath) -or $selectionLayer -notin $expectedLayers) {
            throw 'INVALID: review manifest contains an unsupported selection record.'
        }
        if ($selectionLayer -in @('untracked','whole')) {
            $prefix = if ($selectionLayer -eq 'untracked') { 'untracked/' } else { 'whole/' }
            if ([string]$selected.artifact -cne "$prefix$selectionPath" -or -not $declared.Contains([string]$selected.artifact)) {
                throw "INVALID: copied selection '$selectionPath' has no matching declared artifact."
            }
        }
    }
    return [pscustomobject]@{ Manifest = $manifest; Artifacts = $artifacts.ToArray() }
}

$privateScope = $null
try {
    if ($ScopePath -and $LegacyRange) { throw 'INVALID: -ScopePath cannot be combined with a positional range.' }
    if ($ScopePath -and $PathFile) { throw 'INVALID: -PathFile applies only while creating a private compatibility scope.' }
    if (-not $ScopePath) {
        $privateScope = Join-Path ([IO.Path]::GetTempPath()) ('review-scope-' + [guid]::NewGuid().ToString('N'))
        $builder = Join-Path $PSScriptRoot 'review-scope.ps1'
        if (-not (Test-Path -LiteralPath $builder -PathType Leaf)) { throw 'CANNOT EXAMINE: review-scope.ps1 is unavailable.' }
        $hostPath = (Get-Process -Id $PID).Path
        $builderArguments = @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$builder)
        if (-not $LegacyRange) {
            $builderArguments += @('-Mode','Uncommitted','-OutputPath',$privateScope)
        } else {
            $range = $LegacyRange
            if ($range -match '^(.+)\.\.\.(.+)$') {
                $builderArguments += @('-Mode','Range','-RangeKind','ThreeDot','-Base',$Matches[1],'-Head',$Matches[2],'-OutputPath',$privateScope)
            } elseif ($range -match '^(.+)\.\.(.+)$') {
                $builderArguments += @('-Mode','Range','-RangeKind','TwoDot','-Base',$Matches[1],'-Head',$Matches[2],'-OutputPath',$privateScope)
            } else { throw 'INVALID: positional range must have exact A..B or A...B syntax.' }
        }
        if ($PathFile) { $builderArguments += @('-PathFile',$PathFile) }
        $builderOutput = @(& $hostPath @builderArguments 2>&1 | ForEach-Object { "$_" })
        $builderExit = [int]$LASTEXITCODE
        if ($builderExit -ne 0) {
            $builderText = ($builderOutput -join "`n").Trim()
            if ($builderExit -eq 2) { throw "INVALID: private review-scope capture failed: $builderText" }
            throw "CANNOT EXAMINE: private review-scope capture failed: $builderText"
        }
        $ScopePath = $privateScope
    }

    $scope = Read-ReviewScopeBundle -BundlePath $ScopePath
    $signals = New-Object 'System.Collections.Generic.List[object]'
    foreach ($layer in @($scope.Manifest.layers | Where-Object { $_.name -in @('staged','unstaged','range') })) {
        $artifact = @($scope.Artifacts | Where-Object { $_.Path -ceq [string]$layer.artifact })
        if ($artifact.Count -ne 1) { throw "INVALID: patch layer '$($layer.name)' has no unique artifact." }
        $text = [Text.Encoding]::UTF8.GetString($artifact[0].Bytes)
        $currentPath = $null
        $oldPath = $null
        $removed = 0
        $added = 0
        $flush = {
            if ($currentPath) {
                $normalized = $currentPath -replace '\\', '/'
                if ($normalized -cnotin @($layer.paths)) {
                    throw "INVALID: patch path '$normalized' is absent from the '$($layer.name)' manifest inventory."
                }
                $isTest = $normalized -match '(?i)(Tests\.cs$|\.spec\.ts$|\.Tests\.ps1$|(^|/)tests/)'
                $net = $added - $removed
                if ($isTest -and $net -lt 0) {
                    $signals.Add([pscustomobject]@{ Layer = [string]$layer.name; Path = $normalized; Removed = $removed; Added = $added; Net = $net }) | Out-Null
                }
            }
        }
        foreach ($line in ($text -split "`n")) {
            $line = $line.TrimEnd("`r")
            if ($line.StartsWith('diff --git ')) {
                & $flush
                $currentPath = $null; $oldPath = $null; $removed = 0; $added = 0
            } elseif ($line.StartsWith('--- ')) {
                $oldPath = $line.Substring(4)
                $separator = $oldPath.IndexOf("`t")
                if ($separator -ge 0) { $oldPath = $oldPath.Substring(0, $separator) }
                if ($oldPath.StartsWith('a/')) { $oldPath = $oldPath.Substring(2) }
            } elseif ($line.StartsWith('+++ ')) {
                $currentPath = $line.Substring(4)
                $separator = $currentPath.IndexOf("`t")
                if ($separator -ge 0) { $currentPath = $currentPath.Substring(0, $separator) }
                if ($currentPath.StartsWith('"') -or $currentPath.EndsWith('"')) {
                    throw "INVALID: patch contains a quoted path unsupported by the normalized bundle contract: '$currentPath'."
                }
                if ($currentPath -eq '/dev/null') { $currentPath = $oldPath }
                elseif ($currentPath.StartsWith('b/')) { $currentPath = $currentPath.Substring(2) }
            } elseif ($line.StartsWith('-') -and -not $line.StartsWith('---') -and $line.Substring(1) -match $assertionShape) {
                $removed++
            } elseif ($line.StartsWith('+') -and -not $line.StartsWith('+++') -and $line.Substring(1) -match $assertionShape) {
                $added++
            }
        }
        & $flush
    }

    if ($signals.Count -eq 0) {
        Write-Output 'Test-weakening advisory: nothing qualifies.'
    } else {
        Write-Output 'Test-weakening advisory - review assertion-shaped removals:'
        foreach ($signal in @($signals.ToArray() | Sort-Object Layer, Path)) {
            Write-Output ("  {0}/{1}: removed {2}, added {3}, net {4}" -f $signal.Layer, $signal.Path, $signal.Removed, $signal.Added, $signal.Net)
        }
        Write-Output 'This reviewable signal can be defeated by ignoring it; it is not enforcement.'
    }
    exit 0
} catch {
    $message = $_.Exception.Message
    if ($message.StartsWith('INVALID:', [StringComparison]::Ordinal)) {
        [Console]::Error.WriteLine($message)
        exit 2
    }
    if (-not $message.StartsWith('CANNOT EXAMINE:', [StringComparison]::Ordinal)) { $message = "CANNOT EXAMINE: $message" }
    [Console]::Error.WriteLine($message)
    exit 3
} finally {
    if ($privateScope -and (Test-Path -LiteralPath $privateScope)) {
        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/')
        $privateFull = [IO.Path]::GetFullPath($privateScope)
        if ($privateFull.StartsWith($tempRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and
            (Split-Path -Leaf $privateFull).StartsWith('review-scope-', [StringComparison]::Ordinal)) {
            Remove-Item -LiteralPath $privateFull -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
