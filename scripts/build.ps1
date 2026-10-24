# ai-tech-lead PowerShell composer. Composes src/ -> dist/<mode>.
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
#   Markers are exact: case-sensitive `@stack:`, only spaces and tabs around the line. validate-dist
#   inventories them the same way, so a line that looks like a marker but is not exact is refused (exit 1).
#   The composer writes into dist/<mode>.build-tmp and swaps it in last: a failed build leaves the
#   previous dist/<mode> in place.
# 5.1-safe: no pwsh-only syntax. Byte-faithful: preserves UTF-8 BOM per file, never re-encodes
# through Get-Content/Set-Content (which would mangle BOMs and append trailing newlines). A source that
# is not valid UTF-8 is refused (exit 1) rather than rewritten with U+FFFD.
param(
    [Parameter(Position = 0)]
    [string]$Mode,

    # Git refs whose src/core/framework-retirements.json must stay a subset of the tree's (append-only
    # check). Comma-separated or an array. Absent: the build checks repository content only.
    [string[]]$RetirementBaselineRef = @()
)

$ErrorActionPreference = 'Stop'

if ($Mode -ne 'dotnet' -and $Mode -ne 'angular' -and $Mode -ne 'monorepo') {
    [Console]::Error.WriteLine('usage: build.ps1 {dotnet|angular|monorepo}')
    exit 2
}

# Anchor to the repo this script lives in (scripts/..), not the caller's cwd.
Set-Location -LiteralPath (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
# Set-Location leaves the .NET process directory alone; the [System.IO.File] calls below resolve against it.
[Environment]::CurrentDirectory = (Get-Location).ProviderPath

# Every read and write goes through an absolute path: Windows PowerShell 5.1 misreads a relative
# -LiteralPath while the current location holds [ or ]. $DistLabel is the repo-relative name for messages.
$Root = (Get-Location).ProviderPath
$CORE = Join-Path $Root 'src/core'
$SNIP = Join-Path $Root "src/stacks/$Mode/snippets"
$DIST = Join-Path $Root "dist/$Mode"
$DistLabel = "dist/$Mode"
if ($Mode -eq 'monorepo') {
    $OVERLAYS = @((Join-Path $Root 'src/stacks/dotnet/files'), (Join-Path $Root 'src/stacks/angular/files'), (Join-Path $Root 'src/stacks/monorepo/files'))
} else {
    $OVERLAYS = @((Join-Path $Root "src/stacks/$Mode/files"))
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false, $true)
$Bom = [byte[]](0xEF, 0xBB, 0xBF)
$AnyMarker = '@stack:[A-Za-z0-9_-]+'
# One marker grammar, matched with -cmatch (validate-dist check 1a uses the same one): a line is a
# marker only if it is exactly this. $LooseMarker catches the look-alikes the exact form rejects.
$HtmlMarker = '^[ \t]*<!-- @stack:([A-Za-z0-9_-]+) -->[ \t]*$'
$HashMarker = '^[ \t]*# @stack:([A-Za-z0-9_-]+)[ \t]*$'
$LooseMarker = '(?i)^\s*(<!--\s*@stack:|#\s*@stack:)'

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
    if ($body.Length -eq 0) { $text = '' } else {
        try { $text = $Utf8NoBom.GetString($body) }
        catch {
            [Console]::Error.WriteLine("ERROR: not valid UTF-8: $($Path -replace '\\', '/') -- fix the bytes in the source; the composer will not rewrite them as U+FFFD")
            exit 1
        }
    }
    return @{ HasBom = $hasBom; Text = $text }
}

function Write-TextFile {
    param([string]$Path, [bool]$HasBom, [string]$Text)
    $dir = Split-Path -Parent $Path
    if ($dir) { [void][System.IO.Directory]::CreateDirectory($dir) }
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

# Query Git without letting Windows PowerShell 5.1 turn expected native stderr into a terminating
# ErrorRecord under the script-wide Stop preference. These calls are optional history discovery:
# their exit code and stdout are data, while stderr is intentionally suppressed on both hosts.
function Invoke-GitQuery {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $savedErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& git @Arguments 2>$null)
        $exitCode = [int]$LASTEXITCODE
    } finally {
        $ErrorActionPreference = $savedErrorActionPreference
    }
    return [pscustomobject]@{ Output = $output; Exit = $exitCode }
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
# (union semantics; either may be absent).
function Get-MarkerLines {
    param([string]$Rel, [string]$Name)
    if ($Mode -eq 'monorepo') {
        $monoDir = Join-Path (Join-Path $Root 'src/stacks/monorepo/snippets') $Rel
        if (Test-Path -LiteralPath (Join-Path $monoDir $Name) -PathType Leaf) {
            return , (Get-SnippetLines -SnipDir $monoDir -Name $Name)
        }
        $result = New-Object System.Collections.Generic.List[string]
        foreach ($sl in (Get-SnippetLines -SnipDir (Join-Path (Join-Path $Root 'src/stacks/dotnet/snippets') $Rel) -Name $Name)) { $result.Add($sl) }
        foreach ($sl in (Get-SnippetLines -SnipDir (Join-Path (Join-Path $Root 'src/stacks/angular/snippets') $Rel) -Name $Name)) { $result.Add($sl) }
        return , $result.ToArray()
    }
    return , (Get-SnippetLines -SnipDir (Join-Path $SNIP $Rel) -Name $Name)
}

function Get-RelativeFiles {
    param([string]$Root)
    $rootFull = (Resolve-Path -LiteralPath $Root).ProviderPath.TrimEnd('\', '/')
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
    foreach ($rel in (Get-RelativeFiles (Join-Path $Root 'src/stacks/dotnet/files'))) {
        if ((Test-Path -LiteralPath (Join-Path $Root "src/stacks/angular/files/$rel") -PathType Leaf) -and
            -not (Test-Path -LiteralPath (Join-Path $Root "src/stacks/monorepo/files/$rel") -PathType Leaf)) {
            [Console]::Error.WriteLine("ERROR: '$rel' exists in both src/stacks/dotnet/files and src/stacks/angular/files but has no src/stacks/monorepo/files override")
            $collide = $true
        }
    }
    if ($collide) { exit 1 }
}

$retirementBaselines = New-Object System.Collections.Generic.List[object]
$maintainerLedgerPath = 'meta/framework-retirements-baseline.json'
$maintainerLedgerFile = Join-Path $Root $maintainerLedgerPath
try {
    if (-not (Test-Path -LiteralPath $maintainerLedgerFile -PathType Leaf)) {
        throw "missing retirement ledger: $maintainerLedgerPath"
    }
    $maintainerLedger = (Read-TextFile $maintainerLedgerFile).Text | ConvertFrom-Json
    $maintainerRetirements = Get-ValidatedRetirements -Document $maintainerLedger -Label $maintainerLedgerPath
    foreach ($entry in $maintainerRetirements) { $retirementBaselines.Add($entry) }
} catch {
    [Console]::Error.WriteLine("ERROR: $($_.Exception.Message)")
    exit 1
}

# The committed maintainer baseline is the in-repo authority (it provides bootstrap authority even
# though v0.75 and earlier have no ledger). The build decides from repository content and explicit
# inputs only: it never reads a previous dist, HEAD, or whichever tag git happens to find. History is
# consulted only for refs the caller names with -RetirementBaselineRef (CI and the release script do).
# Under -File a list arrives as one comma-joined string, so refs are split on commas. A ref git cannot resolve is a result of "cannot examine" (exit 2), never a silent skip.
$baselineRefNames = @($RetirementBaselineRef | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($PSBoundParameters.ContainsKey('RetirementBaselineRef') -and $baselineRefNames.Count -eq 0) {
    [Console]::Error.WriteLine("ERROR: -RetirementBaselineRef was given but names no ref; pass a ref such as the previous release tag, or omit the parameter")
    exit 2
}
foreach ($ref in $baselineRefNames) {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        [Console]::Error.WriteLine("ERROR: -RetirementBaselineRef '$ref' was named but git is not on PATH; cannot examine it")
        exit 2
    }
    $commitQuery = Invoke-GitQuery -Arguments @('rev-parse', '--verify', '--quiet', "${ref}^{commit}")
    if ($commitQuery.Exit -ne 0) {
        [Console]::Error.WriteLine("ERROR: -RetirementBaselineRef '$ref' does not resolve to a commit in this repository; cannot examine it")
        exit 2
    }
    $presentQuery = Invoke-GitQuery -Arguments @('cat-file', '-e', "${ref}:src/core/framework-retirements.json")
    if ($presentQuery.Exit -ne 0) {
        # A release before the ledger existed has no retirements to protect.
        Write-Host "note: $ref has no src/core/framework-retirements.json; it contributes no baseline entries"
        continue
    }
    $ledgerQuery = Invoke-GitQuery -Arguments @('show', "${ref}:src/core/framework-retirements.json")
    if ($ledgerQuery.Exit -ne 0) {
        [Console]::Error.WriteLine("ERROR: could not read src/core/framework-retirements.json at '$ref'; cannot examine it")
        exit 2
    }
    try {
        $document = ((@($ledgerQuery.Output) -join "`n") + "`n") | ConvertFrom-Json
        foreach ($entry in (Get-ValidatedRetirements -Document $document -Label "${ref}:src/core/framework-retirements.json")) { $retirementBaselines.Add($entry) }
    } catch {
        [Console]::Error.WriteLine("ERROR: $($_.Exception.Message)")
        exit 1
    }
}

# Each dist path is written once: the last overlay carrying a path supplies it, and core skips a path
# an overlay replaces. A host scanner may map a file between two writes, and truncating a mapped file
# fails (0x800704C8 refused four 0.96.0 releases at compose dist/monorepo).
$overlaySource = [ordered]@{}
foreach ($FILES in $OVERLAYS) {
    if (Test-Path -LiteralPath $FILES) {
        foreach ($rel in (Get-RelativeFiles $FILES)) { $overlaySource[$rel] = Join-Path $FILES $rel }
    }
}

# Enumerate and read every core input, and refuse a marker look-alike, before any output exists.
$coreFiles = Get-RelativeFiles $CORE
$coreRead = @{}
$markerProblems = New-Object System.Collections.Generic.List[string]
foreach ($rel in $coreFiles) {
    if ($overlaySource.Contains($rel)) { continue }
    $r = Read-TextFile (Join-Path $CORE $rel)
    $coreRead[$rel] = $r
    $lineNo = 0
    foreach ($rawLine in (Get-Lines $r.Text)) {
        $lineNo++
        $s = Strip-CR $rawLine
        if (($s -match $LooseMarker) -and ($s -cnotmatch $HtmlMarker) -and ($s -cnotmatch $HashMarker)) {
            $markerProblems.Add("src/core/${rel}:${lineNo}: not an exact @stack marker (case-sensitive, spaces and tabs only around it): $s")
        }
    }
}
if ($markerProblems.Count -gt 0) {
    foreach ($problem in $markerProblems) { [Console]::Error.WriteLine("ERROR: $problem") }
    exit 1
}

# Compose into a sibling directory and swap it in last: a build that fails anywhere below leaves the
# previous $DistLabel in place. $StageDir is the composed tree until the swap.
$StageDir = "$DIST.build-tmp"
$PrevDir = "$DIST.old"
foreach ($leftover in @($StageDir, $PrevDir)) {
    if (Test-Path -LiteralPath $leftover) { Remove-Item -LiteralPath $leftover -Recurse -Force }
}
[void][System.IO.Directory]::CreateDirectory($StageDir)
try {

# 1. core, with marker substitution; normalize to LF
foreach ($rel in $coreFiles) {
    if ($overlaySource.Contains($rel)) { continue }
    $dstPath = Join-Path $StageDir $rel
    $r = $coreRead[$rel]

    if ($r.Text -match $AnyMarker) {
        $lines = Get-Lines $r.Text
        $out = New-Object System.Collections.Generic.List[string]
        foreach ($rawLine in $lines) {
            $s = Strip-CR $rawLine
            if ($s -cmatch $HtmlMarker) {
                foreach ($sl in (Get-MarkerLines -Rel $rel -Name $Matches[1])) { $out.Add($sl) }
            } elseif ($s -cmatch $HashMarker) {
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
foreach ($rel in $overlaySource.Keys) {
    $r = Read-TextFile $overlaySource[$rel]
    $stripped = [regex]::Replace($r.Text, '(?m)\r$', '')
    Write-TextFile -Path (Join-Path $StageDir $rel) -HasBom $r.HasBom -Text $stripped
}

# 3. Generate the installed-path ownership manifest. The path inventory comes from the composed
# dist; install.ps1 is the sole supported installer and therefore the sole ownership-policy source.
function Get-SingleQuotedValues {
    param([string]$Text)
    $values = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($Text, "'([^']+)'")) { $values.Add($m.Groups[1].Value) }
    return $values.ToArray()
}

$psInstaller = (Read-TextFile (Join-Path $StageDir 'scripts/install.ps1')).Text
$psProtectedMatch = [regex]::Match($psInstaller, '(?ms)^\$protected\s*=\s*@\((.*?)\)')
$psPersistentMatch = [regex]::Match($psInstaller, '(?ms)^\$persistentCopyIfAbsent\s*=\s*@\((.*?)\)')
$psMetaMatch = [regex]::Match($psInstaller, '(?m)^\$metaFiles\s*=\s*@\(([^\r\n]+)\)')
$psExcludedMatch = [regex]::Match($psInstaller, '(?ms)^\$excludedFromInstall\s*=\s*@\((.*?)\)')
if (-not $psProtectedMatch.Success -or -not $psPersistentMatch.Success -or -not $psMetaMatch.Success -or
    -not $psExcludedMatch.Success) {
    [Console]::Error.WriteLine('ERROR: ownership manifest could not read protected/persistent/excluded/meta policy from install.ps1')
    exit 1
}
$psProtected = @(Get-SingleQuotedValues $psProtectedMatch.Groups[1].Value)
$psPersistent = @(Get-SingleQuotedValues $psPersistentMatch.Groups[1].Value)
$psMeta = @(Get-SingleQuotedValues $psMetaMatch.Groups[1].Value)
$psExcluded = @(Get-SingleQuotedValues $psExcludedMatch.Groups[1].Value)

# These explicit pins replace the retired Bash differential oracle. install.ps1 remains the
# executable authority, but a policy edit must be deliberate in both the installer and composer
# contract rather than silently changing ownership classification in every generated dist.
$expectedProtected = @(
    'CLAUDE.md', 'AGENTS.md', 'TECH_DEBT.md', 'SECURITY_FINDINGS.md', 'LEARNINGS.md',
    'FRAMEWORK-CONTEXT.md', '.github/copilot-instructions.md', 'docs/ARCHITECTURE.md',
    'docs/architecture-decisions.md', 'docs/wiki/INDEX.md'
)
$expectedPersistent = @('.claude/ai-audit.log')
$expectedMetadata = @('.git', '.template-repo', 'README.md', 'CHANGELOG.md', '.gitignore', '.gitattributes')
$expectedExcluded = @($expectedMetadata + @('scripts/install.ps1', '.github/workflows/template-ci.yml'))

function Add-PolicySetProblems {
    param(
        [string]$Name,
        [string[]]$Actual,
        [string[]]$Expected,
        [System.Collections.Generic.List[string]]$Problems
    )
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($value in $Actual) {
        if (-not $seen.Add($value)) { $Problems.Add("$Name contains duplicate path: $value") }
        if (-not ($Expected -ccontains $value)) { $Problems.Add("$Name contains unexpected path: $value") }
    }
    foreach ($value in $Expected) {
        if (-not ($Actual -ccontains $value)) { $Problems.Add("$Name is missing expected path: $value") }
    }
}

$notInstalled = $psExcluded
$policyProblems = New-Object System.Collections.Generic.List[string]
Add-PolicySetProblems -Name 'install.ps1 protected policy' -Actual $psProtected -Expected $expectedProtected -Problems $policyProblems
Add-PolicySetProblems -Name 'install.ps1 persistent policy' -Actual $psPersistent -Expected $expectedPersistent -Problems $policyProblems
Add-PolicySetProblems -Name 'install.ps1 metadata policy' -Actual $psMeta -Expected $expectedMetadata -Problems $policyProblems
Add-PolicySetProblems -Name 'install.ps1 exclusion policy' -Actual $psExcluded -Expected $expectedExcluded -Problems $policyProblems
if ($policyProblems.Count -gt 0) {
    foreach ($problem in $policyProblems) { [Console]::Error.WriteLine("ERROR: ownership policy drift: $problem") }
    exit 1
}

$extraProtected = $psPersistent
$manifestPath = Join-Path $StageDir 'framework-ownership.json'
$paths = New-Object System.Collections.Generic.List[object]
foreach ($rel in @((Get-RelativeFiles $StageDir) | Sort-Object)) {
    if ($rel -in $notInstalled) { continue }
    # tests/hooks/** stays in every composed dist for maintainer and template CI, but is not a
    # consumer artifact: it must never enter framework-ownership.json, so installers never copy it
    # and its historical bytes are retired via framework-retirements.json (B-215 Slice A).
    if ($rel -eq 'tests/hooks' -or $rel.StartsWith('tests/hooks/')) { continue }
    # presentation/** (the briefing decks and their talking points) stays in the framework checkout for
    # whoever presents the framework; installers never copy it, and its old docs/presentation/ copies
    # are retired via framework-retirements.json.
    if ($rel -eq 'presentation' -or $rel.StartsWith('presentation/')) { continue }
    if ($rel -eq '.claude/settings.json') { $ownership = 'mixed' }
    elseif ($rel -in $psProtected -or $rel -in $extraProtected) { $ownership = 'consumer-owned/protected' }
    else { $ownership = 'framework-owned/overwritten' }
    $paths.Add([ordered]@{ path = $rel; ownership = $ownership })
}
$paths.Add([ordered]@{ path = 'framework-ownership.json'; ownership = 'framework-owned/overwritten' })
# Ordinal, not culture-aware. PowerShell's default Sort-Object is case-insensitive and
# culture-sensitive, which makes generated bytes depend on the host culture. The explicit comparer
# keeps manifest ordering deterministic (`.github/PULL_REQUEST_TEMPLATE.md` and upper-case root
# files are the regression canaries).
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
# comes from the committed maintainer baseline plus the Git refs named with -RetirementBaselineRef,
# both read before composition; the previous dist is not consulted. A retired path may never also
# be an incoming installed path.
$ledgerPath = "$DistLabel/framework-retirements.json"
try {
    $ledger = (Read-TextFile (Join-Path $StageDir 'framework-retirements.json')).Text | ConvertFrom-Json
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
$outFull = (Resolve-Path -LiteralPath $StageDir).ProviderPath.TrimEnd('\', '/')
foreach ($f in (Get-ChildItem -LiteralPath $StageDir -Recurse -File -Force)) {
    $r = Read-TextFile $f.FullName
    if ($r.Text -match $AnyMarker) { $badFiles.Add("$DistLabel/" + ($f.FullName.Substring($outFull.Length).TrimStart('\', '/') -replace '\\', '/')) }
}
if ($badFiles.Count -gt 0) {
    foreach ($bf in $badFiles) { Write-Output $bf }
    [Console]::Error.WriteLine("ERROR: unresolved @stack markers in $DistLabel (files listed above)")
    exit 1
}

$fileCount = (Get-ChildItem -LiteralPath $StageDir -Recurse -File -Force).Count

# 6. swap the composed tree in. The old dist is renamed aside first, so a refused rename leaves it.
if (Test-Path -LiteralPath $DIST) { [System.IO.Directory]::Move($DIST, $PrevDir) }
try { [System.IO.Directory]::Move($StageDir, $DIST) }
catch {
    $swapError = $_.Exception.Message
    if (Test-Path -LiteralPath $PrevDir) { [System.IO.Directory]::Move($PrevDir, $DIST) }
    [Console]::Error.WriteLine("ERROR: could not move the composed tree into $DistLabel ($swapError); the previous $DistLabel is unchanged")
    exit 1
}
if (Test-Path -LiteralPath $PrevDir) {
    try { Remove-Item -LiteralPath $PrevDir -Recurse -Force } catch { [Console]::Error.WriteLine("note: could not remove $PrevDir ($($_.Exception.Message)); delete it by hand") }
}
Write-Output "composed $DistLabel ($fileCount files)"

} finally {
    if (Test-Path -LiteralPath $StageDir) { Remove-Item -LiteralPath $StageDir -Recurse -Force -ErrorAction SilentlyContinue }
}
