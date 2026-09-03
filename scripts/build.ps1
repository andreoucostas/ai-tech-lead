# ai-tech-lead composer (PowerShell twin of build.sh). Composes src/ -> dist/<mode>.
# Modes: dotnet, angular, monorepo. Deterministic LF output.
#
# Mechanism (kept dumb -- copy + marker substitution + file overlay, nothing else):
#   1. Copy src/core -> dist/<mode>, substituting named insertion markers:
#        markdown/text:  a line that is exactly   <!-- @stack:NAME -->
#        scripts:        a line that is exactly   # @stack:NAME
#      single-stack mode -> replaced by src/stacks/<mode>/snippets/<core-relpath>/<NAME>
#        (removed if that snippet file is absent for this stack).
#      monorepo mode     -> src/stacks/monorepo/snippets/<core-relpath>/<NAME> if it exists
#        (authored merged/sectioned content), else the dotnet snippet followed by the angular
#        snippet (raw concatenation -- union semantics; either may be absent).
#   2. Overlay src/stacks/<mode>/files/<relpath> (whole-file per-stack overrides + stack-only
#      files). monorepo mode overlays dotnet, then angular, then monorepo files -- and FAILS if
#      a path exists in both stacks' files/ without a monorepo override (no silent last-wins:
#      every whole-file collision must be an explicit authored decision).
#   3. Validate: no unresolved @stack: markers remain in dist.
# 5.1-safe: no pwsh-only syntax. Byte-faithful: preserves UTF-8 BOM per file, never re-encodes
# through Get-Content/Set-Content (which would mangle BOMs and append trailing newlines).
param(
    [Parameter(Position = 0)]
    [string]$Mode
)

$ErrorActionPreference = 'Stop'

if ($Mode -ne 'dotnet' -and $Mode -ne 'angular' -and $Mode -ne 'monorepo') {
    [Console]::Error.WriteLine('usage: build.ps1 {dotnet|angular|monorepo}')
    exit 2
}

# Anchor to the repo this script lives in (scripts/..), not the caller's cwd.
Set-Location (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))

$CORE = "src/core"
$SNIP = "src/stacks/$Mode/snippets"
$DIST = "dist/$Mode"
if ($Mode -eq 'monorepo') {
    $OVERLAYS = @('src/stacks/dotnet/files', 'src/stacks/angular/files', 'src/stacks/monorepo/files')
} else {
    $OVERLAYS = @("src/stacks/$Mode/files")
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Bom = [byte[]](0xEF, 0xBB, 0xBF)
$AnyMarker = '@stack:[A-Za-z0-9_-]+'
$HtmlMarker = '^\s*<!-- @stack:([A-Za-z0-9_-]+) -->\s*$'
$HashMarker = '^\s*# @stack:([A-Za-z0-9_-]+)\s*$'

# Read a file as (HasBom, Text) without letting .NET's encoding-detecting overloads touch it --
# ReadAllBytes + manual BOM strip is the only way to know for certain whether a BOM was present.
function Read-TextFile {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $hasBom = ($bytes.Length -ge 3) -and ($bytes[0] -eq 0xEF) -and ($bytes[1] -eq 0xBB) -and ($bytes[2] -eq 0xBF)
    if ($hasBom) {
        if ($bytes.Length -gt 3) { $body = $bytes[3..($bytes.Length - 1)] } else { $body = [byte[]]@() }
    } else {
        $body = $bytes
    }
    if ($body.Length -eq 0) { $text = '' } else { $text = $Utf8NoBom.GetString($body) }
    return @{ HasBom = $hasBom; Text = $text }
}

function Write-TextFile {
    param([string]$Path, [bool]$HasBom, [string]$Text)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $bytes = $Utf8NoBom.GetBytes($Text)
    if ($HasBom) { $out = $Bom + $bytes } else { $out = $bytes }
    [System.IO.File]::WriteAllBytes($Path, $out)
}

# Split text into awk-style records (RS="\n"): a trailing "\n" does NOT produce an extra empty
# record, but a final line with no trailing "\n" still is one. Uses .NET String.Split (keeps
# empty entries; identical on 5.1 and pwsh) — NOT the -split operator with a negative limit,
# whose meaning changed in pwsh 7.3 (negative = split from the RIGHT, so -1 returns the whole
# string as one part and every snippet silently vanished).
function Get-Lines {
    param([string]$Text)
    if ($Text.Length -eq 0) { return @() }
    $parts = $Text.Split([char]10)
    if ($Text.EndsWith("`n")) {
        if ($parts.Length -le 1) { return @() }
        return $parts[0..($parts.Length - 2)]
    }
    return $parts
}

function Strip-CR {
    param([string]$Line)
    if ($Line.Length -gt 0 -and $Line[$Line.Length - 1] -eq "`r") { return $Line.Substring(0, $Line.Length - 1) }
    return $Line
}

# Mirrors awk's emit_snip: each snippet line is CR-stripped and becomes one output record,
# regardless of whether the snippet file itself ends with a trailing newline.
function Get-SnippetLines {
    param([string]$SnipDir, [string]$Name)
    $path = Join-Path $SnipDir $Name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    $r = Read-TextFile $path
    $lines = Get-Lines $r.Text
    $result = New-Object System.Collections.Generic.List[string]
    foreach ($l in $lines) { $result.Add((Strip-CR $l)) }
    return , $result.ToArray()
}

# Resolve what a marker expands to. Single-stack: that stack's snippet (or nothing).
# monorepo: the authored monorepo snippet if present, else dotnet then angular concatenated
# (union semantics; either may be absent). Mirrors build.sh's emit_marker().
function Get-MarkerLines {
    param([string]$Rel, [string]$Name)
    if ($Mode -eq 'monorepo') {
        $monoDir = Join-Path 'src/stacks/monorepo/snippets' $Rel
        if (Test-Path -LiteralPath (Join-Path $monoDir $Name) -PathType Leaf) {
            return , (Get-SnippetLines -SnipDir $monoDir -Name $Name)
        }
        $result = New-Object System.Collections.Generic.List[string]
        foreach ($sl in (Get-SnippetLines -SnipDir (Join-Path 'src/stacks/dotnet/snippets' $Rel) -Name $Name)) { $result.Add($sl) }
        foreach ($sl in (Get-SnippetLines -SnipDir (Join-Path 'src/stacks/angular/snippets' $Rel) -Name $Name)) { $result.Add($sl) }
        return , $result.ToArray()
    }
    return , (Get-SnippetLines -SnipDir (Join-Path $SNIP $Rel) -Name $Name)
}

function Get-RelativeFiles {
    param([string]$Root)
    $rootFull = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\', '/')
    $items = Get-ChildItem -LiteralPath $Root -Recurse -File -Force
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($it in $items) {
        $rel = $it.FullName.Substring($rootFull.Length).TrimStart('\', '/')
        $out.Add(($rel -replace '\\', '/'))
    }
    return , $out.ToArray()
}

function Test-NormalizedRepoPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path.Contains('\') -or $Path.Contains([char]0) -or
        $Path.StartsWith('/') -or $Path.StartsWith('//') -or $Path -match '^[A-Za-z]:' ) { return $false }
    foreach ($segment in $Path.Split('/')) {
        if ([string]::IsNullOrEmpty($segment) -or $segment -eq '.' -or $segment -eq '..') { return $false }
    }
    return $true
}

function Get-ValidatedRetirements {
    param([object]$Document, [string]$Label)
    if (-not $Document -or [int]$Document.'schema-version' -ne 1 -or $null -eq $Document.retirements) {
        throw "$Label has an unsupported or missing retirement schema"
    }
    $entries = @($Document.retirements)
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $previousPath = $null
    foreach ($entry in $entries) {
        $path = [string]$entry.path
        $version = [string]$entry.'retired-in'
        $hashes = @($entry.'known-content-sha256' | ForEach-Object { [string]$_ })
        if (-not (Test-NormalizedRepoPath $path)) { throw "$Label contains unsafe or non-normalized path '$path'" }
        if (-not $seen.Add($path)) { throw "$Label contains duplicate path '$path'" }
        if ($previousPath -and [StringComparer]::Ordinal.Compare($previousPath, $path) -ge 0) { throw "$Label paths are not in ordinal order at '$path'" }
        if ($version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { throw "$Label has invalid retired-in version '$version' for '$path'" }
        if ($hashes.Count -eq 0) { throw "$Label has no known-content-sha256 values for '$path'" }
        $previousHash = $null
        foreach ($hash in $hashes) {
            if ($hash -cnotmatch '^[0-9a-f]{64}$') { throw "$Label has invalid SHA-256 '$hash' for '$path'" }
            if ($previousHash -and [StringComparer]::Ordinal.Compare($previousHash, $hash) -ge 0) { throw "$Label hashes are not unique ordinal values for '$path'" }
            $previousHash = $hash
        }
        $previousPath = $path
    }
    return , $entries
}

if ($Mode -eq 'monorepo') {
    # In monorepo mode the file collision check must pass before anything is composed.
    $collide = $false
    foreach ($rel in (Get-RelativeFiles 'src/stacks/dotnet/files')) {
        if ((Test-Path -LiteralPath "src/stacks/angular/files/$rel" -PathType Leaf) -and
            -not (Test-Path -LiteralPath "src/stacks/monorepo/files/$rel" -PathType Leaf)) {
            [Console]::Error.WriteLine("ERROR: '$rel' exists in both src/stacks/dotnet/files and src/stacks/angular/files but has no src/stacks/monorepo/files override")
            $collide = $true
        }
    }
    if ($collide) { exit 1 }
}

$retirementBaselines = New-Object System.Collections.Generic.List[object]
$maintainerLedgerPath = 'meta/framework-retirements-baseline.json'
try {
    if (-not (Test-Path -LiteralPath $maintainerLedgerPath -PathType Leaf)) {
        throw "missing retirement ledger: $maintainerLedgerPath"
    }
    $maintainerLedger = (Read-TextFile $maintainerLedgerPath).Text | ConvertFrom-Json
    $maintainerRetirements = Get-ValidatedRetirements -Document $maintainerLedger -Label $maintainerLedgerPath
    foreach ($entry in $maintainerRetirements) { $retirementBaselines.Add($entry) }
} catch {
    [Console]::Error.WriteLine("ERROR: $($_.Exception.Message)")
    exit 1
}

$previousLedgerPath = Join-Path $DIST 'framework-retirements.json'
if (Test-Path -LiteralPath $previousLedgerPath -PathType Leaf) {
    try {
        $previousLedger = (Read-TextFile $previousLedgerPath).Text | ConvertFrom-Json
        foreach ($entry in (Get-ValidatedRetirements -Document $previousLedger -Label "existing $previousLedgerPath")) { $retirementBaselines.Add($entry) }
    } catch {
        [Console]::Error.WriteLine("ERROR: $($_.Exception.Message)")
        exit 1
    }
}

# The maintainer baseline provides bootstrap authority even though v0.75 and earlier have no ledger.
# The generated dist remains a useful archive snapshot. In this repository's own Git worktree, add
# HEAD and the nearest release tag so later releases retain committed history too. Merely being
# nested beneath some unrelated worktree must not make an unpacked source archive consult that repo.
if (Get-Command git -ErrorAction SilentlyContinue) {
    $gitTopLevel = @(& git rev-parse --show-toplevel 2>$null)
    $gitTopLevelExit = $LASTEXITCODE
    $composerRoot = [IO.Path]::GetFullPath((Get-Location).Path).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $gitRoot = if ($gitTopLevelExit -eq 0 -and $gitTopLevel.Count -eq 1 -and $gitTopLevel[0]) {
        [IO.Path]::GetFullPath([string]$gitTopLevel[0]).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    } else { $null }
    if ($gitRoot -and [StringComparer]::OrdinalIgnoreCase.Equals($gitRoot, $composerRoot)) {
        $baselineRefs = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        [void]$baselineRefs.Add('HEAD')
        $nearestTag = @(& git describe --tags --abbrev=0 --match 'v[0-9]*' HEAD 2>$null)
        $nearestTagExit = $LASTEXITCODE
        if ($nearestTagExit -eq 0 -and $nearestTag.Count -eq 1 -and $nearestTag[0]) { [void]$baselineRefs.Add([string]$nearestTag[0]) }
        foreach ($ref in $baselineRefs) {
            $ledgerLines = @(& git show "${ref}:src/core/framework-retirements.json" 2>$null)
            if ($LASTEXITCODE -ne 0) { continue }
            try {
                $document = (($ledgerLines -join "`n") + "`n") | ConvertFrom-Json
                foreach ($entry in (Get-ValidatedRetirements -Document $document -Label "$ref`:src/core/framework-retirements.json")) { $retirementBaselines.Add($entry) }
            } catch {
                [Console]::Error.WriteLine("ERROR: $($_.Exception.Message)")
                exit 1
            }
        }
    }
}

if (Test-Path $DIST) { Remove-Item -Recurse -Force $DIST }
New-Item -ItemType Directory -Force -Path $DIST | Out-Null

# 1. core, with marker substitution; normalize to LF
$coreFiles = Get-RelativeFiles $CORE
foreach ($rel in $coreFiles) {
    $srcPath = Join-Path $CORE $rel
    $dstPath = Join-Path $DIST $rel
    $r = Read-TextFile $srcPath

    if ($r.Text -match $AnyMarker) {
        $lines = Get-Lines $r.Text
        $out = New-Object System.Collections.Generic.List[string]
        foreach ($rawLine in $lines) {
            $s = Strip-CR $rawLine
            if ($s -match $HtmlMarker) {
                foreach ($sl in (Get-MarkerLines -Rel $rel -Name $Matches[1])) { $out.Add($sl) }
            } elseif ($s -match $HashMarker) {
                foreach ($sl in (Get-MarkerLines -Rel $rel -Name $Matches[1])) { $out.Add($sl) }
            } else {
                $out.Add($s)
            }
        }
        if ($out.Count -eq 0) { $result = '' } else { $result = ($out -join "`n") + "`n" }
        Write-TextFile -Path $dstPath -HasBom $r.HasBom -Text $result
    } else {
        # byte-copy semantics (sed 's/\r$//'): strip only a CR immediately before each line's
        # end (or at absolute EOF); preserves BOM and preserves a missing trailing newline.
        $stripped = [regex]::Replace($r.Text, '(?m)\r$', '')
        Write-TextFile -Path $dstPath -HasBom $r.HasBom -Text $stripped
    }
}

# 2. overlay per-stack files (whole-file overrides + stack-only), normalized LF.
# monorepo = union of both stacks plus monorepo overrides (collisions already vetted above).
foreach ($FILES in $OVERLAYS) {
    if (Test-Path $FILES) {
        $overlayFiles = Get-RelativeFiles $FILES
        foreach ($rel in $overlayFiles) {
            $srcPath = Join-Path $FILES $rel
            $dstPath = Join-Path $DIST $rel
            $r = Read-TextFile $srcPath
            $stripped = [regex]::Replace($r.Text, '(?m)\r$', '')
            Write-TextFile -Path $dstPath -HasBom $r.HasBom -Text $stripped
        }
    }
}

# 3. Generate the installed-path ownership manifest. The path inventory comes from the composed
# dist; installer policy is read from both twins so changing either installer cannot silently make
# the manifest describe behavior that the other twin does not implement.
function Get-SingleQuotedValues {
    param([string]$Text)
    $values = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($Text, "'([^']+)'")) { $values.Add($m.Groups[1].Value) }
    return $values.ToArray()
}

$psInstaller = (Read-TextFile (Join-Path $DIST 'scripts/install.ps1')).Text
$shInstaller = (Read-TextFile (Join-Path $DIST 'scripts/install.sh')).Text
$psProtectedMatch = [regex]::Match($psInstaller, '(?ms)^\$protected\s*=\s*@\((.*?)\)')
$psPersistentMatch = [regex]::Match($psInstaller, '(?ms)^\$persistentCopyIfAbsent\s*=\s*@\((.*?)\)')
$psMetaMatch = [regex]::Match($psInstaller, '(?m)^\$metaFiles\s*=\s*@\(([^\r\n]+)\)')
$shProtectedMatch = [regex]::Match($shInstaller, '(?m)^protected="([^"]+)"')
$shPersistentMatch = [regex]::Match($shInstaller, '(?m)^persistent_copy_if_absent="([^"]+)"')
if (-not $psProtectedMatch.Success -or -not $psPersistentMatch.Success -or -not $psMetaMatch.Success -or -not $shProtectedMatch.Success -or -not $shPersistentMatch.Success) {
    [Console]::Error.WriteLine('ERROR: ownership manifest could not read protected/persistent/meta policy from both installers')
    exit 1
}
$psProtected = @(Get-SingleQuotedValues $psProtectedMatch.Groups[1].Value)
$psPersistent = @(Get-SingleQuotedValues $psPersistentMatch.Groups[1].Value)
$psMeta = @(Get-SingleQuotedValues $psMetaMatch.Groups[1].Value)
$shProtected = @($shProtectedMatch.Groups[1].Value -split ' ' | Where-Object { $_ })
$shPersistent = @($shPersistentMatch.Groups[1].Value -split ' ' | Where-Object { $_ })
$policyProblems = New-Object System.Collections.Generic.List[string]
foreach ($p in $psProtected) { if ($p -notin $shProtected) { $policyProblems.Add("consumer-owned/protected in install.ps1 but not install.sh: $p") } }
foreach ($p in $shProtected) { if ($p -notin $psProtected) { $policyProblems.Add("consumer-owned/protected in install.sh but not install.ps1: $p") } }
foreach ($p in $psPersistent) { if ($p -notin $shPersistent) { $policyProblems.Add("persistent/copy-if-absent in install.ps1 but not install.sh: $p") } }
foreach ($p in $shPersistent) { if ($p -notin $psPersistent) { $policyProblems.Add("persistent/copy-if-absent in install.sh but not install.ps1: $p") } }
foreach ($p in $psMeta) {
    if ($shInstaller -notmatch [regex]::Escape($p)) { $policyProblems.Add("excluded by install.ps1 but not install.sh: $p") }
}
if ($policyProblems.Count -gt 0) {
    foreach ($problem in $policyProblems) { [Console]::Error.WriteLine("ERROR: ownership policy disagreement: $problem") }
    exit 1
}

$notInstalled = @($psMeta + @('scripts/install.ps1', 'scripts/install.sh', '.github/workflows/template-ci.yml'))
$extraProtected = @('docs/wiki/INDEX.md', 'LICENSES/ai-tech-lead-MIT.txt') + $psPersistent
$manifestPath = Join-Path $DIST 'framework-ownership.json'
$paths = New-Object System.Collections.Generic.List[object]
foreach ($rel in @((Get-RelativeFiles $DIST) | Sort-Object)) {
    if ($rel -in $notInstalled) { continue }
    # tests/hooks/** stays in every composed dist for maintainer and template CI, but is not a
    # consumer artifact: it must never enter framework-ownership.json, so installers never copy it
    # and its historical bytes are retired via framework-retirements.json (B-215 Slice A).
    if ($rel -eq 'tests/hooks' -or $rel.StartsWith('tests/hooks/')) { continue }
    if ($rel -eq '.claude/settings.json') { $ownership = 'mixed' }
    elseif ($rel -in $psProtected -or $rel -in $extraProtected) { $ownership = 'consumer-owned/protected' }
    else { $ownership = 'framework-owned/overwritten' }
    $paths.Add([ordered]@{ path = $rel; ownership = $ownership })
}
$paths.Add([ordered]@{ path = 'framework-ownership.json'; ownership = 'framework-owned/overwritten' })
# Ordinal, not culture-aware. PowerShell's default Sort-Object is case-insensitive and
# culture-sensitive while `sort` in the .sh twin collates by locale, so the two composers emitted
# byte-different manifests for an identical set of 163 paths (`.github/PULL_REQUEST_TEMPLATE.md` and
# the upper-case root files landed in different places). Same content, different bytes, from a file
# that SHIPS -- an invariant #3 break that only appears when both twins are actually run. The .sh
# twin pins `LC_ALL=C` for the same reason.
$byPath = @{}
foreach ($entry in $paths) { $byPath[[string]$entry.path] = $entry }
$orderedKeys = [string[]]@($byPath.Keys)
[array]::Sort($orderedKeys, [System.StringComparer]::Ordinal)
$sortedPaths = @($orderedKeys | ForEach-Object { $byPath[$_] })
$jsonLines = New-Object System.Collections.Generic.List[string]
$jsonLines.Add('{')
$jsonLines.Add('  "schema-version": 1,')
$jsonLines.Add('  "paths": [')
for ($i = 0; $i -lt $sortedPaths.Count; $i++) {
    $comma = if ($i -lt $sortedPaths.Count - 1) { ',' } else { '' }
    $pathJson = $sortedPaths[$i].path.Replace('\', '\\').Replace('"', '\"')
    $jsonLines.Add(('    {{ "path": "{0}", "ownership": "{1}" }}{2}' -f $pathJson, $sortedPaths[$i].ownership, $comma))
}
$jsonLines.Add('  ]')
$jsonLines.Add('}')
Write-TextFile -Path $manifestPath -HasBom $false -Text (($jsonLines -join "`n") + "`n")

# 4. Validate the framework-authored, cumulative retirement authority. Historical authority comes
# from the existing dist plus independent Git baselines captured before composition. A retired path
# may never also be an incoming installed path.
$ledgerPath = Join-Path $DIST 'framework-retirements.json'
try {
    $ledger = (Read-TextFile $ledgerPath).Text | ConvertFrom-Json
    $retirements = Get-ValidatedRetirements -Document $ledger -Label $ledgerPath
} catch {
    [Console]::Error.WriteLine("ERROR: $($_.Exception.Message)")
    exit 1
}
$retirementsByPath = @{}
foreach ($entry in $retirements) {
    $path = [string]$entry.path
    if ($byPath.ContainsKey($path)) {
        [Console]::Error.WriteLine("ERROR: retirement '$path' is still present in the incoming ownership manifest")
        exit 1
    }
    $retirementsByPath[$path] = $entry
}
if ($retirements.Count -ne $maintainerRetirements.Count) {
    [Console]::Error.WriteLine("ERROR: $ledgerPath and $maintainerLedgerPath must contain the same cumulative retirement entries")
    exit 1
}
for ($i = 0; $i -lt $retirements.Count; $i++) {
    $current = $retirements[$i]
    $maintained = $maintainerRetirements[$i]
    $currentHashes = @($current.'known-content-sha256' | ForEach-Object { [string]$_ })
    $maintainedHashes = @($maintained.'known-content-sha256' | ForEach-Object { [string]$_ })
    if ([string]$current.path -cne [string]$maintained.path -or
        [string]$current.'retired-in' -cne [string]$maintained.'retired-in' -or
        $currentHashes.Count -ne $maintainedHashes.Count -or
        (Compare-Object -ReferenceObject $maintainedHashes -DifferenceObject $currentHashes -CaseSensitive)) {
        [Console]::Error.WriteLine("ERROR: $ledgerPath and $maintainerLedgerPath must contain the same cumulative retirement entries")
        exit 1
    }
}
foreach ($old in $retirementBaselines) {
    $path = [string]$old.path
    if (-not $retirementsByPath.ContainsKey($path)) {
        [Console]::Error.WriteLine("ERROR: cumulative retirement '$path' disappeared from $ledgerPath")
        exit 1
    }
    $current = $retirementsByPath[$path]
    if ([string]$current.'retired-in' -cne [string]$old.'retired-in') {
        [Console]::Error.WriteLine("ERROR: retirement version changed for '$path'")
        exit 1
    }
    foreach ($hash in @($old.'known-content-sha256')) {
        if ([string]$hash -notin @($current.'known-content-sha256' | ForEach-Object { [string]$_ })) {
            [Console]::Error.WriteLine("ERROR: known historical digest disappeared for retirement '$path'")
            exit 1
        }
    }
}

# 5. validate: no unresolved markers
$badFiles = New-Object System.Collections.Generic.List[string]
if (Test-Path $DIST) {
    foreach ($f in (Get-ChildItem -LiteralPath $DIST -Recurse -File -Force)) {
        $r = Read-TextFile $f.FullName
        if ($r.Text -match $AnyMarker) { $badFiles.Add($f.FullName) }
    }
}
if ($badFiles.Count -gt 0) {
    foreach ($bf in $badFiles) { Write-Output $bf }
    [Console]::Error.WriteLine("ERROR: unresolved @stack markers in $DIST (files listed above)")
    exit 1
}

$fileCount = (Get-ChildItem -LiteralPath $DIST -Recurse -File -Force).Count
Write-Output "composed $DIST ($fileCount files)"
