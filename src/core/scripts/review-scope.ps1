# Captures one immutable, bounded set of review bytes without changing the repository.
# Usage examples:
#   pwsh -NoProfile -File scripts/review-scope.ps1 -Mode Uncommitted -OutputPath <fresh-temp-path>
#   pwsh -NoProfile -File scripts/review-scope.ps1 -Mode Range -Base main -Head HEAD -OutputPath <fresh-temp-path>
#   pwsh -NoProfile -File scripts/review-scope.ps1 -Mode WholeFile -PathFile <paths.json> -OutputPath <fresh-temp-path>
[CmdletBinding()]
param(
    [string]$Mode,
    [string]$OutputPath,
    [string]$Base,
    [string]$Head,
    [string]$PathFile,
    [string]$RangeKind = 'TwoDot'
)
$ErrorActionPreference = 'Stop'
$script:RepoRoot = $null
$script:PathFilterSupplied = -not [string]::IsNullOrWhiteSpace($PathFile)
$script:PerFileLimit = 16MB
$script:TotalFileLimit = 64MB
$script:PrivateIndexPath = $null

function Invoke-GitBytes {
    param([string[]]$Arguments)
    $git = @(Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($git.Count -ne 1) { throw 'CANNOT EXAMINE: git executable is unavailable.' }
    # These are command-scoped: review capture must neither refresh the repository index nor fetch
    # a missing promisor object. A Git version that cannot honour them fails as inability to examine.
    $allArguments = @('--no-optional-locks','--no-lazy-fetch')
    if ($script:RepoRoot) { $allArguments += @('-C', $script:RepoRoot) }
    $allArguments += @('-c','core.quotePath=false')
    $allArguments += $Arguments
    foreach ($argument in $allArguments) {
        if ($null -eq $argument -or $argument.IndexOf([char]0) -ge 0 -or $argument -match '[\r\n"]') {
            throw 'INVALID: a Git argument contains an unsupported control or quote character.'
        }
    }
    $argumentString = (($allArguments | ForEach-Object { '"' + $_ + '"' }) -join ' ')
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $git[0].Source
    $startInfo.Arguments = $argumentString
    $startInfo.WorkingDirectory = (Get-Location).Path
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.EnvironmentVariables['GIT_OPTIONAL_LOCKS'] = '0'
    $startInfo.EnvironmentVariables['GIT_NO_LAZY_FETCH'] = '1'
    if ($script:PrivateIndexPath) { $startInfo.EnvironmentVariables['GIT_INDEX_FILE'] = $script:PrivateIndexPath }
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    $stdout = New-Object IO.MemoryStream
    try {
        [void]$process.Start()
        $stdoutTask = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        return [pscustomobject]@{ Exit = [int]$process.ExitCode; Bytes = $stdout.ToArray(); Error = $stderr }
    } catch {
        throw "CANNOT EXAMINE: could not execute git: $($_.Exception.Message)"
    } finally {
        $stdout.Dispose()
        $process.Dispose()
    }
}

function Get-SelectedPaths {
    param([string]$InputPath)
    if (-not $script:PathFilterSupplied) { return @() }
    try { $pathEntry = Get-Item -Force -LiteralPath $InputPath -ErrorAction Stop }
    catch [System.Management.Automation.ItemNotFoundException] { $pathEntry = $null }
    catch { throw "CANNOT EXAMINE: could not inspect path list '$InputPath': $($_.Exception.Message)" }
    if (-not $pathEntry -or $pathEntry.PSIsContainer -or (($pathEntry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
        throw "INVALID: path list is not a regular file: '$InputPath'."
    }
    $pathCursor = $pathEntry.FullName
    while ($pathCursor) {
        try { $pathAncestor = Get-Item -Force -LiteralPath $pathCursor -ErrorAction Stop }
        catch { throw "CANNOT EXAMINE: could not inspect path-list ancestry '$InputPath': $($_.Exception.Message)" }
        if (($pathAncestor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "INVALID: path list traverses a reparse point: '$InputPath'."
        }
        $pathParent = Split-Path -Parent $pathCursor
        if (-not $pathParent -or $pathParent -eq $pathCursor) { break }
        $pathCursor = $pathParent
    }
    try { $raw = [IO.File]::ReadAllText($pathEntry.FullName, [Text.Encoding]::UTF8) }
    catch { throw "CANNOT EXAMINE: could not read path list '$InputPath': $($_.Exception.Message)" }
    $trimmed = $raw.Trim().TrimStart([char]0xFEFF)
    if (-not $trimmed.StartsWith('[') -or -not $trimmed.EndsWith(']')) {
        throw 'INVALID: path list must be a UTF-8 JSON array of repository-relative strings.'
    }
    try { $null = $trimmed | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "INVALID: path list is not valid JSON: $($_.Exception.Message)" }
    $wrapper = ('{"values":' + $trimmed + '}') | ConvertFrom-Json -ErrorAction Stop
    $parsed = $wrapper.values
    if ($null -eq $parsed -or $parsed -isnot [System.Array]) {
        throw 'INVALID: path list must be a JSON array of strings.'
    }
    $selected = New-Object 'System.Collections.Generic.List[string]'
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($value in $parsed) {
        if ($value -isnot [string]) { throw 'INVALID: every path-list entry must be a string.' }
        $path = [string]$value
        if ([string]::IsNullOrWhiteSpace($path) -or $path.Contains('\') -or $path.Contains([char]0) -or
            $path.StartsWith('/') -or $path.StartsWith('//') -or $path -match '^[A-Za-z]:' -or $path.Contains('"')) {
            throw "INVALID: unsafe or non-normalized repository path '$path'."
        }
        $segments = @($path.Split('/'))
        if (@($segments | Where-Object { [string]::IsNullOrEmpty($_) -or $_ -eq '.' -or $_ -eq '..' }).Count -gt 0 -or
            $segments[0] -eq '.git') {
            throw "INVALID: unsafe or non-normalized repository path '$path'."
        }
        $full = [IO.Path]::GetFullPath((Join-Path $script:RepoRoot ($path -replace '/', [IO.Path]::DirectorySeparatorChar)))
        $prefix = $script:RepoRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
        if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "INVALID: repository path escapes the selected repository: '$path'."
        }
        $cursor = $full
        while ($cursor -and -not [string]::Equals($cursor, $script:RepoRoot, [StringComparison]::OrdinalIgnoreCase)) {
            try { $item = Get-Item -Force -LiteralPath $cursor -ErrorAction Stop }
            catch [System.Management.Automation.ItemNotFoundException] { $item = $null }
            catch { throw "CANNOT EXAMINE: could not inspect repository path '$path': $($_.Exception.Message)" }
            if ($item -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
                throw "INVALID: repository path traverses a reparse point: '$path'."
            }
            $cursor = Split-Path -Parent $cursor
        }
        if ($seen.Add($path)) { $selected.Add($path) | Out-Null }
    }
    return @($selected.ToArray() | Sort-Object)
}

function Write-ReviewScopeBundle {
    param([string[]]$SelectedPaths)
    $artifacts = New-Object 'System.Collections.Generic.List[object]'
    $layers = New-Object 'System.Collections.Generic.List[object]'
    $selectedRecords = New-Object 'System.Collections.Generic.List[object]'
    $totalCopied = [int64]0

    $pathSpecs = @($SelectedPaths | ForEach-Object { ":(literal)$_" })
    $emptySelection = $script:PathFilterSupplied -and $SelectedPaths.Count -eq 0
    $initialState = $null
    if ($Mode -eq 'Uncommitted') {
        $indexResult = Invoke-GitBytes @('rev-parse','--git-path','index')
        $gitDirResult = Invoke-GitBytes @('rev-parse','--absolute-git-dir')
        if ($indexResult.Exit -ne 0 -or $gitDirResult.Exit -ne 0) {
            throw "CANNOT EXAMINE: could not resolve Git index metadata: $($indexResult.Error.Trim()) $($gitDirResult.Error.Trim())"
        }
        $indexText = [Text.Encoding]::UTF8.GetString($indexResult.Bytes).Trim()
        $gitDirText = [Text.Encoding]::UTF8.GetString($gitDirResult.Bytes).Trim()
        $realIndexPath = if ([IO.Path]::IsPathRooted($indexText)) { [IO.Path]::GetFullPath($indexText) } else { [IO.Path]::GetFullPath((Join-Path $script:RepoRoot $indexText)) }
        $gitDirPath = [IO.Path]::GetFullPath($gitDirText).TrimEnd('\','/')
        if (-not ($realIndexPath.StartsWith($gitDirPath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase))) {
            throw 'CANNOT EXAMINE: resolved Git index is outside the selected worktree metadata.'
        }
        try { $indexBytes = [IO.File]::ReadAllBytes($realIndexPath) }
        catch { throw "CANNOT EXAMINE: could not read Git index: $($_.Exception.Message)" }
        $script:PrivateIndexPath = Join-Path $OutputPath '.review-index'
        try { [IO.File]::WriteAllBytes($script:PrivateIndexPath, $indexBytes) }
        catch { throw "CANNOT EXAMINE: could not create private review index: $($_.Exception.Message)" }
        $initialState = Invoke-GitBytes @('status','--porcelain=v1','-z','--untracked-files=all')
        if ($initialState.Exit -ne 0) { throw "CANNOT EXAMINE: initial repository-state read failed: $($initialState.Error.Trim())" }
    }
    $writeArtifact = {
        param([string]$Relative, [byte[]]$Bytes)
        if ($null -eq $Bytes) { $Bytes = New-Object byte[] 0 }
        $destination = Join-Path $OutputPath ($Relative -replace '/', [IO.Path]::DirectorySeparatorChar)
        $parent = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        [IO.File]::WriteAllBytes($destination, $Bytes)
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $digest = ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
        finally { $sha.Dispose() }
        $record = [pscustomobject][ordered]@{ path = $Relative; sha256 = $digest; size = [int64]$Bytes.Length }
        $artifacts.Add($record) | Out-Null
        return $record
    }
    $readNames = {
        param([string[]]$GitArguments)
        if ($emptySelection) { return @() }
        $result = Invoke-GitBytes $GitArguments
        if ($result.Exit -ne 0) { throw "CANNOT EXAMINE: git path enumeration failed: $($result.Error.Trim())" }
        if ($result.Bytes.Length -eq 0) { return @() }
        return @([Text.Encoding]::UTF8.GetString($result.Bytes).TrimEnd([char]0) -split ([string][char]0) | Where-Object { $_ })
    }
    $capturePatch = {
        param([string]$Name, [string[]]$DiffArguments)
        $patch = if ($emptySelection) { [pscustomobject]@{ Exit = 0; Bytes = [byte[]]@(); Error = '' } } else { Invoke-GitBytes $DiffArguments }
        if ($patch.Exit -ne 0) { throw "CANNOT EXAMINE: git $Name patch failed: $($patch.Error.Trim())" }
        # Rebuild the name command explicitly because the patch and name outputs have different formats.
        if ($Name -eq 'staged') { $nameArgs = @('diff','--cached','--name-only','-z','--find-renames','--diff-filter=ACDMRTUXB','--') + $pathSpecs }
        elseif ($Name -eq 'unstaged') { $nameArgs = @('diff','--name-only','-z','--find-renames','--diff-filter=ACDMRTUXB','--') + $pathSpecs }
        else { $nameArgs = @('diff',$script:RangeExpression,'--name-only','-z','--find-renames','--diff-filter=ACDMRTUXB','--') + $pathSpecs }
        $paths = @(& $readNames $nameArgs | Sort-Object -Unique)
        $deletedArgs = @($nameArgs)
        $filterIndex = [Array]::IndexOf($deletedArgs, '--diff-filter=ACDMRTUXB')
        $deletedArgs[$filterIndex] = '--diff-filter=D'
        $renamedArgs = @($nameArgs)
        $renamedArgs[$filterIndex] = '--diff-filter=R'
        $deletions = @(& $readNames $deletedArgs | Sort-Object -Unique)
        $renames = @(& $readNames $renamedArgs | Sort-Object -Unique)
        foreach ($capturedPath in @($paths + $deletions + $renames)) {
            if ($capturedPath -match '[\x00-\x1f"]') {
                throw "CANNOT EXAMINE: Git path contains an unsupported control or quote character: '$capturedPath'."
            }
        }
        $patchCheck = if ($emptySelection) { [pscustomobject]@{ Exit = 0; Bytes = [byte[]]@(); Error = '' } } else { Invoke-GitBytes $DiffArguments }
        if ($patchCheck.Exit -ne 0) { throw "CANNOT EXAMINE: git $Name stability read failed: $($patchCheck.Error.Trim())" }
        $pathsCheck = @(& $readNames $nameArgs | Sort-Object -Unique)
        $deletionsCheck = @(& $readNames $deletedArgs | Sort-Object -Unique)
        $renamesCheck = @(& $readNames $renamedArgs | Sort-Object -Unique)
        $patch64 = [Convert]::ToBase64String([byte[]]@($patch.Bytes))
        $patchCheck64 = [Convert]::ToBase64String([byte[]]@($patchCheck.Bytes))
        if ($patch64 -cne $patchCheck64 -or ($paths -join "`0") -cne ($pathsCheck -join "`0") -or
            ($deletions -join "`0") -cne ($deletionsCheck -join "`0") -or ($renames -join "`0") -cne ($renamesCheck -join "`0")) {
            throw "CANNOT EXAMINE: repository changed while capturing the $Name patch and metadata; retry with a fresh scope."
        }
        $artifact = & $writeArtifact "$Name.patch" ([byte[]]@($patch.Bytes))
        $layer = [pscustomobject][ordered]@{
            name = $Name
            artifact = $artifact.path
            paths = $paths
            deletions = $deletions
            renames = $renames
        }
        $layers.Add($layer) | Out-Null
        foreach ($path in $paths) { $selectedRecords.Add([pscustomobject][ordered]@{ path = $path; layer = $Name }) | Out-Null }
    }

    if ($Mode -eq 'Uncommitted') {
        & $capturePatch 'staged' (@('diff','--cached','--binary','--full-index','--unified=0','--find-renames','--no-ext-diff','--no-textconv','--no-color','--src-prefix=a/','--dst-prefix=b/','--') + $pathSpecs)
        & $capturePatch 'unstaged' (@('diff','--binary','--full-index','--unified=0','--find-renames','--no-ext-diff','--no-textconv','--no-color','--src-prefix=a/','--dst-prefix=b/','--') + $pathSpecs)
        $untrackedArgs = @('ls-files','--others','--exclude-standard','-z','--') + $pathSpecs
        $untracked = @(& $readNames $untrackedArgs | Sort-Object -Unique)
        foreach ($relative in $untracked) {
            $source = Join-Path $script:RepoRoot ($relative -replace '/', [IO.Path]::DirectorySeparatorChar)
            try { $entry = Get-Item -Force -LiteralPath $source -ErrorAction Stop }
            catch { throw "CANNOT EXAMINE: could not inspect untracked path '$relative': $($_.Exception.Message)" }
            if ($entry.PSIsContainer -or (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
                throw "CANNOT EXAMINE: untracked path is not a readable regular file: '$relative'."
            }
            $cursor = $entry.FullName
            while (-not [string]::Equals($cursor, $script:RepoRoot, [StringComparison]::OrdinalIgnoreCase)) {
                try { $ancestor = Get-Item -Force -LiteralPath $cursor -ErrorAction Stop }
                catch { throw "CANNOT EXAMINE: could not inspect untracked path '$relative': $($_.Exception.Message)" }
                if ($ancestor -and (($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
                    throw "CANNOT EXAMINE: untracked path traverses a reparse point: '$relative'."
                }
                $cursor = Split-Path -Parent $cursor
            }
            if ($entry.Length -gt $script:PerFileLimit -or ($totalCopied + $entry.Length) -gt $script:TotalFileLimit) {
                throw "CANNOT EXAMINE: untracked path exceeds the review capture limit: '$relative'."
            }
            try { $bytes = [IO.File]::ReadAllBytes($entry.FullName) }
            catch { throw "CANNOT EXAMINE: could not read untracked path '$relative': $($_.Exception.Message)" }
            $totalCopied += $bytes.Length
            $artifact = & $writeArtifact "untracked/$relative" $bytes
            $selectedRecords.Add([pscustomobject][ordered]@{ path = $relative; layer = 'untracked'; artifact = $artifact.path }) | Out-Null
        }
        $layers.Add([pscustomobject][ordered]@{ name = 'untracked'; paths = $untracked }) | Out-Null
    } elseif ($Mode -eq 'Range') {
        & $capturePatch 'range' (@('diff',$script:RangeExpression,'--binary','--full-index','--unified=0','--find-renames','--no-ext-diff','--no-textconv','--no-color','--src-prefix=a/','--dst-prefix=b/','--') + $pathSpecs)
    } else {
        if (-not $script:PathFilterSupplied -or $SelectedPaths.Count -eq 0) {
            throw 'INVALID: WholeFile mode requires a nonempty -PathFile selection.'
        }
        foreach ($relative in $SelectedPaths) {
            $source = Join-Path $script:RepoRoot ($relative -replace '/', [IO.Path]::DirectorySeparatorChar)
            try { $entry = Get-Item -Force -LiteralPath $source -ErrorAction Stop }
            catch { throw "CANNOT EXAMINE: could not inspect selected whole-file path '$relative': $($_.Exception.Message)" }
            if ($entry.PSIsContainer -or (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
                throw "CANNOT EXAMINE: selected whole-file path is not a readable regular file: '$relative'."
            }
            $cursor = $entry.FullName
            while (-not [string]::Equals($cursor, $script:RepoRoot, [StringComparison]::OrdinalIgnoreCase)) {
                try { $ancestor = Get-Item -Force -LiteralPath $cursor -ErrorAction Stop }
                catch { throw "CANNOT EXAMINE: could not inspect selected whole-file path '$relative': $($_.Exception.Message)" }
                if ($ancestor -and (($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
                    throw "CANNOT EXAMINE: selected whole-file path traverses a reparse point: '$relative'."
                }
                $cursor = Split-Path -Parent $cursor
            }
            if ($entry.Length -gt $script:PerFileLimit -or ($totalCopied + $entry.Length) -gt $script:TotalFileLimit) {
                throw "CANNOT EXAMINE: selected whole-file path exceeds the review capture limit: '$relative'."
            }
            try { $bytes = [IO.File]::ReadAllBytes($entry.FullName) }
            catch { throw "CANNOT EXAMINE: could not read selected whole-file path '$relative': $($_.Exception.Message)" }
            $totalCopied += $bytes.Length
            $artifact = & $writeArtifact "whole/$relative" $bytes
            $selectedRecords.Add([pscustomobject][ordered]@{ path = $relative; layer = 'whole'; artifact = $artifact.path }) | Out-Null
        }
        $layers.Add([pscustomobject][ordered]@{ name = 'whole'; paths = @($SelectedPaths) }) | Out-Null
    }

    if ($Mode -eq 'Uncommitted') {
        $finalState = Invoke-GitBytes @('status','--porcelain=v1','-z','--untracked-files=all')
        if ($finalState.Exit -ne 0) { throw "CANNOT EXAMINE: final repository-state read failed: $($finalState.Error.Trim())" }
        if ([Convert]::ToBase64String([byte[]]@($initialState.Bytes)) -cne [Convert]::ToBase64String([byte[]]@($finalState.Bytes))) {
            throw 'CANNOT EXAMINE: repository changed while capturing the review scope; retry with a fresh scope.'
        }
        try { [IO.File]::Delete($script:PrivateIndexPath); $script:PrivateIndexPath = $null }
        catch { throw "CANNOT EXAMINE: could not dispose private review index: $($_.Exception.Message)" }
    }

    $manifest = [pscustomobject][ordered]@{
        formatVersion = 1
        mode = $Mode
        rangeKind = if ($Mode -eq 'Range') { $RangeKind } else { $null }
        suppliedBase = if ($Mode -eq 'Range') { $Base } else { $null }
        suppliedHead = if ($Mode -eq 'Range') { $Head } else { $null }
        resolvedBase = $script:ResolvedBase
        resolvedHead = $script:ResolvedHead
        effectiveBase = $script:EffectiveBase
        pathFilter = @($SelectedPaths)
        selection = @($selectedRecords.ToArray() | Sort-Object path, layer)
        layers = @($layers.ToArray())
        artifacts = @($artifacts.ToArray() | Sort-Object path)
        limits = [pscustomobject][ordered]@{ perFileBytes = [int64]$script:PerFileLimit; totalFileBytes = [int64]$script:TotalFileLimit }
    }
    $json = ($manifest | ConvertTo-Json -Depth 8 -Compress) + "`n"
    [IO.File]::WriteAllText((Join-Path $OutputPath 'manifest.json'), $json, [Text.UTF8Encoding]::new($false))
}

$created = $false
try {
    if ($Mode -notin @('Uncommitted','Range','WholeFile')) { throw 'INVALID: -Mode must be Uncommitted, Range, or WholeFile.' }
    if ([string]::IsNullOrWhiteSpace($OutputPath)) { throw 'INVALID: -OutputPath is required.' }
    if ($Mode -eq 'Range') {
        if ([string]::IsNullOrWhiteSpace($Base) -or [string]::IsNullOrWhiteSpace($Head)) { throw 'INVALID: Range mode requires -Base and -Head.' }
        if ($RangeKind -notin @('TwoDot','ThreeDot')) { throw 'INVALID: -RangeKind must be TwoDot or ThreeDot.' }
    } elseif ($Base -or $Head -or $RangeKind -ne 'TwoDot') {
        throw 'INVALID: -Base, -Head, and non-default -RangeKind are valid only in Range mode.'
    }

    $rootResult = Invoke-GitBytes @('rev-parse','--show-toplevel')
    if ($rootResult.Exit -ne 0) { throw "CANNOT EXAMINE: current directory is not an inspectable Git repository: $($rootResult.Error.Trim())" }
    $rootText = [Text.Encoding]::UTF8.GetString($rootResult.Bytes).Trim()
    if ([string]::IsNullOrWhiteSpace($rootText)) { throw 'CANNOT EXAMINE: Git returned an empty repository root.' }
    $script:RepoRoot = (Resolve-Path -LiteralPath $rootText).Path.TrimEnd('\','/')

    $outputFull = [IO.Path]::GetFullPath($OutputPath)
    $repoPrefix = $script:RepoRoot + [IO.Path]::DirectorySeparatorChar
    if ([string]::Equals($outputFull.TrimEnd('\','/'), $script:RepoRoot, [StringComparison]::OrdinalIgnoreCase) -or
        $outputFull.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'INVALID: -OutputPath must be outside the selected repository.'
    }
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/')
    $tempPrefix = $tempRoot + [IO.Path]::DirectorySeparatorChar
    if (-not $outputFull.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'INVALID: -OutputPath must be a fresh path beneath the system temporary directory.'
    }
    try { $existingOutput = Get-Item -Force -LiteralPath $outputFull -ErrorAction Stop }
    catch [System.Management.Automation.ItemNotFoundException] { $existingOutput = $null }
    catch { throw "CANNOT EXAMINE: could not inspect output path '$outputFull': $($_.Exception.Message)" }
    if ($existingOutput) { throw "CANNOT EXAMINE: output path already exists: '$outputFull'." }
    $parent = Split-Path -Parent $outputFull
    try { $parentEntry = Get-Item -Force -LiteralPath $parent -ErrorAction Stop }
    catch [System.Management.Automation.ItemNotFoundException] { $parentEntry = $null }
    catch { throw "CANNOT EXAMINE: could not inspect output parent '$parent': $($_.Exception.Message)" }
    if (-not $parentEntry -or -not $parentEntry.PSIsContainer) { throw "CANNOT EXAMINE: output parent does not exist or is not a directory: '$parent'." }
    $cursor = $parent
    while ($cursor -and $cursor.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        $entry = Get-Item -Force -LiteralPath $cursor -ErrorAction Stop
        if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "INVALID: output path traverses a reparse point: '$cursor'." }
        if ([string]::Equals($cursor, $tempRoot, [StringComparison]::OrdinalIgnoreCase)) { break }
        $cursor = Split-Path -Parent $cursor
    }

    $headResult = Invoke-GitBytes @('rev-parse','--verify','HEAD^{commit}')
    if ($headResult.Exit -ne 0) { throw "CANNOT EXAMINE: repository has no resolvable HEAD commit: $($headResult.Error.Trim())" }
    $headOid = [Text.Encoding]::UTF8.GetString($headResult.Bytes).Trim()
    if ($headOid -notmatch '^(?:[0-9a-f]{40}|[0-9a-f]{64})$') { throw 'CANNOT EXAMINE: Git returned an unsupported HEAD object ID.' }
    $script:ResolvedBase = $null
    $script:ResolvedHead = $headOid
    $script:EffectiveBase = $null
    $script:RangeExpression = $null
    if ($Mode -eq 'Range') {
        $baseResult = Invoke-GitBytes @('rev-parse','--verify',"$Base^{commit}")
        if ($baseResult.Exit -ne 0) { throw "CANNOT EXAMINE: base ref '$Base' is not a commit: $($baseResult.Error.Trim())" }
        $rangeHeadResult = Invoke-GitBytes @('rev-parse','--verify',"$Head^{commit}")
        if ($rangeHeadResult.Exit -ne 0) { throw "CANNOT EXAMINE: head ref '$Head' is not a commit: $($rangeHeadResult.Error.Trim())" }
        $script:ResolvedBase = [Text.Encoding]::UTF8.GetString($baseResult.Bytes).Trim()
        $script:ResolvedHead = [Text.Encoding]::UTF8.GetString($rangeHeadResult.Bytes).Trim()
        if ($script:ResolvedBase -notmatch '^(?:[0-9a-f]{40}|[0-9a-f]{64})$' -or
            $script:ResolvedHead -notmatch '^(?:[0-9a-f]{40}|[0-9a-f]{64})$') {
            throw 'CANNOT EXAMINE: Git returned an unsupported range object ID.'
        }
        $script:EffectiveBase = $script:ResolvedBase
        if ($RangeKind -eq 'ThreeDot') {
            $mergeBase = Invoke-GitBytes @('merge-base',$script:ResolvedBase,$script:ResolvedHead)
            if ($mergeBase.Exit -ne 0) { throw "CANNOT EXAMINE: refs do not have an inspectable merge base: $($mergeBase.Error.Trim())" }
            $script:EffectiveBase = [Text.Encoding]::UTF8.GetString($mergeBase.Bytes).Trim()
            if ($script:EffectiveBase -notmatch '^(?:[0-9a-f]{40}|[0-9a-f]{64})$') { throw 'CANNOT EXAMINE: Git returned an unsupported merge-base object ID.' }
        }
        $script:RangeExpression = "$($script:EffectiveBase)..$($script:ResolvedHead)"
    }

    $selected = @(Get-SelectedPaths -InputPath $PathFile)
    New-Item -ItemType Directory -Path $outputFull | Out-Null
    $created = $true
    $OutputPath = $outputFull
    Write-ReviewScopeBundle -SelectedPaths $selected
    Write-Output ("Review scope captured: {0}" -f (Join-Path $OutputPath 'manifest.json'))
    exit 0
} catch {
    if ($created -and (Test-Path -LiteralPath $OutputPath)) {
        Remove-Item -LiteralPath $OutputPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    $message = $_.Exception.Message
    if ($message.StartsWith('INVALID:', [StringComparison]::Ordinal)) {
        [Console]::Error.WriteLine($message)
        exit 2
    }
    if (-not $message.StartsWith('CANNOT EXAMINE:', [StringComparison]::Ordinal)) { $message = "CANNOT EXAMINE: $message" }
    [Console]::Error.WriteLine($message)
    exit 3
}
