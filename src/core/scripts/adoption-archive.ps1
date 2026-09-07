<#
adoption-archive.ps1 — adoption-specific archive-integrity helper.

Headless /adopt and the brownfield installer both move pre-existing files into
docs/pre-adoption/. This helper preserves their exact pre-move bytes, records provenance evidence
that survives the move, and re-verifies the frozen inventory before and after the embedded
/bootstrap so a normalized or truncated archive can never reach an adoption completion report.

It is deliberately NOT a generic installer. It captures candidates, freezes a complete durable
inventory, moves only entries from that inventory, and verifies archived bytes against it.

Exactly one mode:
  -Capture   Read a candidate's raw bytes + provenance and print one evidence entry as JSON. No move.
  -Freeze    Capture every selected workflow candidate from -PlanPath into an existing durable
             marker before any source move.
  -MoveFrozen Move exactly one already-frozen marker entry and persist its byte verification.
  -Verify    Re-verify every entry in -EvidencePath against the archived bytes on disk and print a
             per-entry report ending in a single "RESULT: PASS|FAIL|CANT-VERIFY" line.

Exit codes:
  0  PASS / evidence emitted
  2  usage error
  3  refused before mutation (path escape, reparse-point ancestor, destination collision,
     unreadable source)
  5  CANT-VERIFY — the artifact could not be examined, or legacy evidence carries no pre-move digest
  6  FAIL — an archived candidate's bytes differ from the frozen digest, or a required frozen entry
     is missing

Raw SHA-256 over the actual filesystem bytes is the preservation oracle. The recorded Git revision
and original path are historical attribution only; never substitute one for the other. When
localModification is "modified", provenanceRevision attributes an OLDER committed version, not the
archived bytes — only the raw SHA-256 vouches for those.
#>
param(
    [switch]$Capture,
    [switch]$Freeze,
    [switch]$MoveFrozen,
    [switch]$Verify,
    [string]$RepoRoot = '.',
    [string]$OriginalPath,
    [string]$Destination,
    [ValidateSet('installer', 'workflow')][string]$Owner = 'workflow',
    [string]$EvidencePath,
    [string]$PlanPath
)
$ErrorActionPreference = 'Stop'

$SchemaVersion = 1

function Write-AaError {
    param([string]$Message)
    [Console]::Error.WriteLine($Message)
}

# Reject anything that is not a normalized forward-slash relative path contained by $Root. Mirrors
# the installer's Get-ContainedTargetPath so installer and workflow moves apply identical checks.
function Get-AaContainedPath {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Relative)
    if ([string]::IsNullOrWhiteSpace($Relative) -or $Relative.Contains('\') -or $Relative.Contains([char]0) -or
        $Relative.StartsWith('/') -or $Relative.StartsWith('//') -or $Relative -match '^[A-Za-z]:') {
        throw "unsafe or non-normalized path '$Relative'"
    }
    foreach ($segment in $Relative.Split('/')) {
        if ([string]::IsNullOrEmpty($segment) -or $segment -eq '.' -or $segment -eq '..') {
            throw "unsafe or non-normalized path '$Relative'"
        }
    }
    $full = [IO.Path]::GetFullPath((Join-Path $Root ($Relative -replace '/', [IO.Path]::DirectorySeparatorChar)))
    $prefix = $Root.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "path escapes the repository: '$Relative'" }
    return $full
}

# Evidence and plan arguments in shipped workflows are relative to the target repository, never
# the caller's ambient working directory. Absolute paths remain allowed only when contained by it.
function Resolve-AaRepositoryPath {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Path, [string]$Kind = 'path')
    if ([IO.Path]::IsPathRooted($Path)) { $full = [IO.Path]::GetFullPath($Path) }
    else { $full = [IO.Path]::GetFullPath((Join-Path $Root $Path)) }
    $prefix = $Root.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "$Kind path escapes the repository: '$Path'" }
    return $full
}

# A dangling link is visible to Get-Item -Force where Test-Path reports false; do not weaken this
# to a Test-Path guard.
function Get-AaReparseAncestor {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Path)
    $rootFull = [IO.Path]::GetFullPath($Root)
    $current = [IO.Path]::GetFullPath($Path)
    while ($true) {
        $item = Get-Item -Force -LiteralPath $current -ErrorAction SilentlyContinue
        if ($item -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { return $current }
        if ($current -eq $rootFull) { return $null }
        $parent = Split-Path -Parent $current
        if (-not $parent -or $parent -eq $current) { return $null }
        $current = $parent
    }
}

function Get-AaSha256Hex {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Bytes)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

# The inventory identity binds the complete pre-move set, independently of mutable move-progress
# fields such as verified and archivedOriginals.  Its sorted, encoded lines make the same identity
# portable across PS7 and PS5.1 without trusting JSON property order or host culture.
function ConvertTo-AaIdentitySegment {
    param([AllowNull()][string]$Value)
    return [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$Value))
}

function New-AaInventoryIdentity {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Entries)
    $lines = New-Object 'System.Collections.Generic.List[string]'
    foreach ($entry in @($Entries)) {
        $line = @(
            ([int]$entry.schemaVersion).ToString([Globalization.CultureInfo]::InvariantCulture)
            (ConvertTo-AaIdentitySegment -Value ([string]$entry.originalPath))
            (ConvertTo-AaIdentitySegment -Value ([string]$entry.destination))
            ([string]$entry.sha256).ToLowerInvariant()
            ([int64]$entry.byteLength).ToString([Globalization.CultureInfo]::InvariantCulture)
            (ConvertTo-AaIdentitySegment -Value ([string]$entry.owner))
            (ConvertTo-AaIdentitySegment -Value ([string]$entry.provenanceRevision))
            (ConvertTo-AaIdentitySegment -Value ([string]$entry.provenance))
            (ConvertTo-AaIdentitySegment -Value ([string]$entry.historyDepth))
            (ConvertTo-AaIdentitySegment -Value ([string]$entry.localModification))
        ) -join '|'
        $lines.Add($line)
    }
    $lines.Sort([StringComparer]::Ordinal)
    $payload = "ai-tech-lead/archive-integrity/v1`n" + ($lines -join "`n")
    return [pscustomobject][ordered]@{
        schemaVersion = 1
        algorithm     = 'SHA-256'
        entryCount    = [int]$lines.Count
        sha256        = Get-AaSha256Hex -Bytes ([Text.Encoding]::UTF8.GetBytes($payload))
    }
}

$script:AaGitPath = $null
$script:AaGitResolved = $false
function Get-AaGitPath {
    if ($script:AaGitResolved) { return $script:AaGitPath }
    $script:AaGitResolved = $true
    $command = @(Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($command.Count -gt 0) { $script:AaGitPath = [string]$command[0].Source }
    return $script:AaGitPath
}

# Nullable exit code so a launch failure is never mistaken for a clean run. Returns a null Output
# only when git never started.
function Invoke-AaGit {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string[]]$GitArgs)
    $gitPath = Get-AaGitPath
    if (-not $gitPath) { return [pscustomobject]@{ Started = $false; ExitCode = $null; Output = $null; RecordCount = 0 } }
    foreach ($name in @('GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR', 'GIT_INDEX_FILE')) {
        $value = [Environment]::GetEnvironmentVariable($name, 'Process')
        if ($null -ne $value -and $value.Length -gt 0) {
            return [pscustomobject]@{ Started = $false; ExitCode = $null; Output = $null; RecordCount = 0 }
        }
    }
    $priorPreference = $ErrorActionPreference
    $stdout = @()
    $exitCode = $null
    try {
        $ErrorActionPreference = 'Continue'
        $global:LASTEXITCODE = $null
        try {
            $stdout = @(& $gitPath '-C' $Root @GitArgs 2>$null)
            $exitCode = $global:LASTEXITCODE
        } catch {
            $stdout = @()
            $exitCode = $null
        }
    } finally {
        $ErrorActionPreference = $priorPreference
    }
    $normalized = (@($stdout | ForEach-Object { ([string]$_).TrimEnd("`r") }) -join "`n")
    return [pscustomobject]@{
        Started     = ($null -ne $exitCode)
        ExitCode    = $exitCode
        Output      = $normalized
        RecordCount = $stdout.Count
    }
}

# Historical attribution, kept strictly separate from the raw-byte oracle. "unavailable" means Git
# could not answer; it is never a trust verdict and never a corruption finding.
function Get-AaProvenance {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Relative)
    $result = [ordered]@{
        provenanceRevision = $null
        provenance         = 'unavailable'
        historyDepth       = 'unavailable'
        localModification  = 'unknown'
    }
    $insideWorkTree = Invoke-AaGit -Root $Root -GitArgs @('rev-parse', '--is-inside-work-tree')
    if (-not $insideWorkTree.Started -or $insideWorkTree.ExitCode -ne 0 -or $insideWorkTree.Output -cne 'true') {
        return [pscustomobject]$result
    }
    $shallow = Invoke-AaGit -Root $Root -GitArgs @('rev-parse', '--is-shallow-repository')
    if ($shallow.Started -and $shallow.ExitCode -eq 0) {
        $result.historyDepth = if ($shallow.Output -ceq 'true') { 'shallow' } else { 'full' }
    }
    $tracked = Invoke-AaGit -Root $Root -GitArgs @('ls-files', '--error-unmatch', '--', $Relative)
    if ($tracked.Started -and $tracked.ExitCode -eq 0) {
        $result.provenance = 'tracked'
        $lastCommit = Invoke-AaGit -Root $Root -GitArgs @('log', '-1', '--format=%H', '--', $Relative)
        if ($lastCommit.Started -and $lastCommit.ExitCode -eq 0 -and $lastCommit.Output -match '^[0-9a-f]{40}$') {
            $result.provenanceRevision = $lastCommit.Output
        }
        $status = Invoke-AaGit -Root $Root -GitArgs @('status', '--porcelain', '--', $Relative)
        if ($status.Started -and $status.ExitCode -eq 0) {
            $result.localModification = if ($status.RecordCount -gt 0) { 'modified' } else { 'clean' }
        }
    } elseif ($tracked.Started -and $tracked.ExitCode -eq 1) {
        # Git's documented "not in the index" result is factual untracked input. A launch or
        # repository failure stays unavailable so a host problem is never reported as provenance.
        $result.provenance = 'untracked'
    }
    return [pscustomobject]$result
}

function New-AaEvidenceEntry {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$OriginalRelative,
        [Parameter(Mandatory = $true)][string]$DestinationRelative,
        [Parameter(Mandatory = $true)][ValidateSet('installer', 'workflow')][string]$EntryOwner
    )
    $sourceFull = Get-AaContainedPath -Root $Root -Relative $OriginalRelative
    if (Get-AaReparseAncestor -Root $Root -Path $sourceFull) { throw "REFUSE source '$OriginalRelative' traverses a reparse point" }
    $item = Get-Item -Force -LiteralPath $sourceFull -ErrorAction SilentlyContinue
    if (-not $item) { throw "REFUSE source '$OriginalRelative' does not exist" }
    if ($item.PSIsContainer) { throw "REFUSE source '$OriginalRelative' is not a regular file" }
    try { $bytes = [IO.File]::ReadAllBytes($sourceFull) }
    catch { throw "REFUSE source '$OriginalRelative' could not be read: $($_.Exception.Message)" }
    $provenance = Get-AaProvenance -Root $Root -Relative $OriginalRelative
    return [ordered]@{
        schemaVersion      = $SchemaVersion
        originalPath        = $OriginalRelative
        destination         = $DestinationRelative
        sha256              = Get-AaSha256Hex -Bytes $bytes
        byteLength          = [int64]$bytes.LongLength
        owner               = $EntryOwner
        provenanceRevision  = $provenance.provenanceRevision
        provenance          = $provenance.provenance
        historyDepth        = $provenance.historyDepth
        localModification   = $provenance.localModification
    }
}

# Returns 'PASS' (bytes match frozen digest), 'CORRUPTION' (read succeeded, bytes differ) or
# 'CANT-VERIFY' (could not examine). Length is compared before the digest so a truncation is named
# as corruption, not as an examination failure.
function Test-AaArchivedBytes {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$DestinationRelative,
        [Parameter(Mandatory = $true)][string]$ExpectedSha,
        [Parameter(Mandatory = $true)][int64]$ExpectedLength,
        [ref]$Detail
    )
    if ($Detail) { $Detail.Value = '' }
    try { $full = Get-AaContainedPath -Root $Root -Relative $DestinationRelative }
    catch { if ($Detail) { $Detail.Value = $_.Exception.Message }; return 'CANT-VERIFY' }
    if (Get-AaReparseAncestor -Root $Root -Path $full) {
        if ($Detail) { $Detail.Value = 'archive path traverses a reparse point' }
        return 'CANT-VERIFY'
    }
    $item = Get-Item -Force -LiteralPath $full -ErrorAction SilentlyContinue
    if (-not $item) { if ($Detail) { $Detail.Value = 'archived candidate is missing' }; return 'CORRUPTION' }
    if ($item.PSIsContainer) { if ($Detail) { $Detail.Value = 'archived candidate is not a regular file' }; return 'CANT-VERIFY' }
    try { $bytes = [IO.File]::ReadAllBytes($full) }
    catch { if ($Detail) { $Detail.Value = "archived candidate could not be read: $($_.Exception.Message)" }; return 'CANT-VERIFY' }
    if ([int64]$bytes.LongLength -ne $ExpectedLength) {
        if ($Detail) { $Detail.Value = "byte length changed (expected $ExpectedLength, found $($bytes.LongLength))" }
        return 'CORRUPTION'
    }
    $actualSha = Get-AaSha256Hex -Bytes $bytes
    if ($actualSha -cne $ExpectedSha.ToLowerInvariant()) {
        if ($Detail) { $Detail.Value = "SHA-256 changed (expected $ExpectedSha, found $actualSha)" }
        return 'CORRUPTION'
    }
    return 'PASS'
}

function Get-AaIntegrityBlock {
    param([Parameter(Mandatory = $true)]$Document)
    if ($null -ne $Document.PSObject.Properties['archiveIntegrity']) { return $Document.archiveIntegrity }
    if ($null -ne $Document.PSObject.Properties['entries']) { return $Document }
    return $null
}

function Read-AaJsonDocument {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "evidence file '$Path' is missing or not a regular file" }
    try { return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json) }
    catch { throw "evidence file '$Path' is not valid JSON: $($_.Exception.Message)" }
}

# Writes the complete document only after it has been fully serialized. Existing evidence is
# replaced in-place from a same-directory temporary file; a write failure before replacement leaves
# the earlier frozen inventory readable. This is bounded write-failure protection, not a claim about
# filesystem crash durability. Evidence mutation is restricted to a file inside the repository.
function Write-AaJsonDocument {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)]$Document)
    $full = [IO.Path]::GetFullPath($Path)
    $prefix = $Root.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "evidence mutation path escapes the repository: '$Path'" }
    $parent = Split-Path -Parent $full
    if (Get-AaReparseAncestor -Root $Root -Path $full) { throw "evidence mutation path traverses a reparse point: '$Path'" }
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw "evidence parent does not exist: '$parent'" }
    $temporary = Join-Path $parent ('.adoption-archive-' + [guid]::NewGuid().ToString('N') + '.tmp')
    $backup = Join-Path $parent ('.adoption-archive-' + [guid]::NewGuid().ToString('N') + '.bak')
    try {
        [IO.File]::WriteAllText($temporary, ($Document | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
        if (Test-Path -LiteralPath $full -PathType Leaf) {
            [IO.File]::Replace($temporary, $full, $backup)
        } else {
            Move-Item -LiteralPath $temporary -Destination $full
        }
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue }
    }
}

function Test-AaIntegrityStructure {
    param([Parameter(Mandatory = $true)]$Document, [switch]$AllowUnverified)
    $block = Get-AaIntegrityBlock -Document $Document
    if ($null -eq $block) { return [pscustomobject]@{ Valid = $false; Detail = 'has no archiveIntegrity block'; Block = $null; Entries = @() } }
    if ($null -eq $block.PSObject.Properties['schemaVersion'] -or [int]$block.schemaVersion -ne $SchemaVersion) { return [pscustomobject]@{ Valid = $false; Detail = 'has an unsupported or missing schemaVersion'; Block = $block; Entries = @() } }
    if ($null -eq $block.PSObject.Properties['inventoryStatus'] -or $null -eq $block.PSObject.Properties['entries']) { return [pscustomobject]@{ Valid = $false; Detail = 'is malformed (missing inventoryStatus or entries)'; Block = $block; Entries = @() } }
    if ([string]$block.inventoryStatus -ne 'complete') { return [pscustomobject]@{ Valid = $false; Detail = "did not complete (inventoryStatus='$($block.inventoryStatus)')"; Block = $block; Entries = @() } }
    $entries = @($block.entries)
    $originals = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $destinations = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $entries) {
        if ($null -eq $entry -or [string]::IsNullOrWhiteSpace([string]$entry.originalPath) -or [string]::IsNullOrWhiteSpace([string]$entry.destination)) { return [pscustomobject]@{ Valid = $false; Detail = 'contains an entry without originalPath or destination'; Block = $block; Entries = $entries } }
        if ($null -eq $entry.PSObject.Properties['schemaVersion'] -or [int]$entry.schemaVersion -ne $SchemaVersion -or [string]$entry.owner -notin @('installer', 'workflow')) { return [pscustomobject]@{ Valid = $false; Detail = 'contains an entry without the required schemaVersion or owner'; Block = $block; Entries = $entries } }
        if ($null -eq $entry.PSObject.Properties['verified'] -or -not ($entry.verified -is [bool])) { return [pscustomobject]@{ Valid = $false; Detail = 'contains an entry with a missing or non-boolean verified state'; Block = $block; Entries = $entries } }
        try { [void](Get-AaContainedPath -Root $script:AaValidationRoot -Relative ([string]$entry.originalPath)); [void](Get-AaContainedPath -Root $script:AaValidationRoot -Relative ([string]$entry.destination)) }
        catch { return [pscustomobject]@{ Valid = $false; Detail = "contains an unsafe path: $($_.Exception.Message)"; Block = $block; Entries = $entries } }
        if (-not ([string]$entry.destination).StartsWith('docs/pre-adoption/', [StringComparison]::Ordinal)) { return [pscustomobject]@{ Valid = $false; Detail = "contains a destination outside docs/pre-adoption: '$($entry.destination)'"; Block = $block; Entries = $entries } }
        if (-not $originals.Add([string]$entry.originalPath) -or -not $destinations.Add([string]$entry.destination)) { return [pscustomobject]@{ Valid = $false; Detail = 'contains duplicate original or destination paths'; Block = $block; Entries = $entries } }
        if ([string]$entry.sha256 -notmatch '^[0-9a-fA-F]{64}$' -or $null -eq $entry.PSObject.Properties['byteLength'] -or [int64]$entry.byteLength -lt 0) { return [pscustomobject]@{ Valid = $false; Detail = "contains an entry without a valid pre-move digest and byte length"; Block = $block; Entries = $entries } }
        if ($null -eq $entry.PSObject.Properties['provenanceRevision'] -or $null -eq $entry.PSObject.Properties['provenance'] -or $null -eq $entry.PSObject.Properties['historyDepth'] -or $null -eq $entry.PSObject.Properties['localModification'] -or
            (-not [string]::IsNullOrWhiteSpace([string]$entry.provenanceRevision) -and [string]$entry.provenanceRevision -notmatch '^[0-9a-fA-F]{40}$') -or
            [string]$entry.provenance -notin @('tracked', 'untracked', 'unavailable') -or [string]$entry.historyDepth -notin @('full', 'shallow', 'unavailable') -or [string]$entry.localModification -notin @('clean', 'modified', 'unknown')) {
            return [pscustomobject]@{ Valid = $false; Detail = 'contains missing or unsupported provenance evidence'; Block = $block; Entries = $entries }
        }
        if (-not $AllowUnverified -and ($null -eq $entry.PSObject.Properties['verified'] -or -not [bool]$entry.verified)) { return [pscustomobject]@{ Valid = $false; Detail = "contains an unverified frozen entry '$($entry.originalPath)'"; Block = $block; Entries = $entries } }
    }
    if ($null -eq $block.PSObject.Properties['inventoryIdentity']) { return [pscustomobject]@{ Valid = $false; Detail = 'has no frozen inventoryIdentity'; Block = $block; Entries = $entries } }
    $identity = $block.inventoryIdentity
    if ($null -eq $identity -or $null -eq $identity.PSObject.Properties['schemaVersion'] -or [int]$identity.schemaVersion -ne 1 -or
        [string]$identity.algorithm -cne 'SHA-256' -or $null -eq $identity.PSObject.Properties['entryCount'] -or
        [int]$identity.entryCount -ne $entries.Count -or [string]$identity.sha256 -notmatch '^[0-9a-fA-F]{64}$') {
        return [pscustomobject]@{ Valid = $false; Detail = 'has a malformed frozen inventoryIdentity'; Block = $block; Entries = $entries }
    }
    $expectedIdentity = New-AaInventoryIdentity -Entries $entries
    if ([string]$identity.sha256 -cne $expectedIdentity.sha256) {
        return [pscustomobject]@{ Valid = $false; Detail = 'frozen inventoryIdentity does not match the complete immutable entry set (do not regenerate from current archives)'; Block = $block; Entries = $entries }
    }
    if ($null -ne $Document.PSObject.Properties['archivedOriginals']) {
        $mapped = @($Document.archivedOriginals)
        $verifiedDestinations = @($entries | Where-Object { $_.PSObject.Properties['verified'] -and $_.verified } | ForEach-Object { [string]$_.destination })
        if ($mapped.Count -ne $verifiedDestinations.Count) { return [pscustomobject]@{ Valid = $false; Detail = 'archivedOriginals does not have exactly one mapping for every verified integrity entry'; Block = $block; Entries = $entries } }
        $mappedSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach ($value in $mapped) { if (-not $mappedSet.Add([string]$value) -or -not ($verifiedDestinations -contains [string]$value)) { return [pscustomobject]@{ Valid = $false; Detail = 'archivedOriginals disagrees with verified integrity-entry destinations'; Block = $block; Entries = $entries } } }
    }
    return [pscustomobject]@{ Valid = $true; Detail = ''; Block = $block; Entries = $entries }
}

# Verify the FROZEN inventory in $EvidenceFile against the archives on disk. The frozen file is the
# only source of expected identities: a regenerated live marker with fewer entries cannot make this
# pass, because omitted entries are simply still checked here.
function Invoke-AaVerify {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$EvidenceFile)
    $lines = New-Object System.Collections.Generic.List[string]
    try { $document = Read-AaJsonDocument -Path $EvidenceFile }
    catch { $lines.Add("CANT-VERIFY: $($_.Exception.Message)."); return [pscustomobject]@{ Result = 'CANT-VERIFY'; Lines = $lines } }
    $legacyMarker = ($null -ne $document.PSObject.Properties['archivedOriginals']) -and ($null -eq $document.PSObject.Properties['archiveIntegrity'])
    $block = Get-AaIntegrityBlock -Document $document
    if ($null -eq $block) {
        if ($legacyMarker) {
            $lines.Add('CANT-VERIFY: legacy adoption marker — no pre-move digests were recorded, so original-byte preservation cannot be proved.')
            $lines.Add('  A human must recover the original bytes (e.g. from Git history at the pre-install revision) or record an explicit disposition.')
            $lines.Add('  Do NOT re-hash the current archive and treat that as a verified-integrity result.')
        } else {
            $lines.Add("CANT-VERIFY: evidence file '$EvidenceFile' has no archiveIntegrity block.")
        }
        return [pscustomobject]@{ Result = 'CANT-VERIFY'; Lines = $lines }
    }
    $script:AaValidationRoot = $Root
    try { $shape = Test-AaIntegrityStructure -Document $document }
    catch {
        $lines.Add("CANT-VERIFY: archiveIntegrity block in '$EvidenceFile' could not be structurally examined: $($_.Exception.Message).")
        return [pscustomobject]@{ Result = 'CANT-VERIFY'; Lines = $lines }
    }
    if (-not $shape.Valid) { $lines.Add("CANT-VERIFY: archiveIntegrity block in '$EvidenceFile' $($shape.Detail)."); return [pscustomobject]@{ Result = 'CANT-VERIFY'; Lines = $lines } }
    $entries = $shape.Entries
    if ($entries.Count -eq 0) {
        $lines.Add('PASS: inventory complete with zero archived candidates; nothing to verify.')
        return [pscustomobject]@{ Result = 'PASS'; Lines = $lines }
    }
    $sawFail = $false
    $sawCantVerify = $false
    foreach ($entry in $entries) {
        $original = [string]$entry.originalPath
        $dest = [string]$entry.destination
        $sha = [string]$entry.sha256
        if ([string]::IsNullOrWhiteSpace($sha) -or $null -eq $entry.PSObject.Properties['byteLength']) {
            $lines.Add("CANT-VERIFY: entry for '$original' -> '$dest' carries no pre-move digest; human recovery/disposition required.")
            $sawCantVerify = $true
            continue
        }
        $detail = ''
        $verdict = Test-AaArchivedBytes -Root $Root -DestinationRelative $dest -ExpectedSha $sha -ExpectedLength ([int64]$entry.byteLength) -Detail ([ref]$detail)
        switch ($verdict) {
            'PASS'        { $lines.Add("PASS: '$original' -> '$dest' bytes match the frozen digest.") }
            'CORRUPTION'  { $lines.Add("FAIL: '$original' -> '$dest' $detail."); $sawFail = $true }
            'CANT-VERIFY' { $lines.Add("CANT-VERIFY: '$original' -> '$dest' $detail."); $sawCantVerify = $true }
        }
    }
    $result = if ($sawFail) { 'FAIL' } elseif ($sawCantVerify) { 'CANT-VERIFY' } else { 'PASS' }
    return [pscustomobject]@{ Result = $result; Lines = $lines }
}

function ConvertTo-AaJson {
    param([Parameter(Mandatory = $true)]$Value)
    return ($Value | ConvertTo-Json -Depth 6)
}

function Stop-AaFrozenMove {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$MarkerPath, $Document, [string]$Message, [int]$ExitCode = 3)
    if ($null -eq $Document) { Write-AaError "ERROR: $Message No readable frozen marker was available to update."; exit 3 }
    try {
        $Document.archiveIntegrity.inventoryStatus = 'failed'
        Write-AaJsonDocument -Root $Root -Path $MarkerPath -Document $Document
    } catch {
        Write-AaError "ERROR: $Message The earlier frozen inventory could not be marked failed: $($_.Exception.Message)"
        exit 3
    }
    Write-AaError "ERROR: $Message"
    exit $ExitCode
}

function Invoke-AaFreeze {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$MarkerPath, [Parameter(Mandatory = $true)][string]$InventoryPlanPath)
    try {
        $document = Read-AaJsonDocument -Path $MarkerPath
        $script:AaValidationRoot = $Root
        $existing = Test-AaIntegrityStructure -Document $document
        if (-not $existing.Valid) { throw "existing marker $($existing.Detail)" }
        if ($null -ne $document.archiveIntegrity.PSObject.Properties['frozenAt']) {
            throw 'workflow inventory was already frozen; resume only with -MoveFrozen and do not refresh its identity'
        }
        $plan = Read-AaJsonDocument -Path $InventoryPlanPath
        if ($null -eq $plan.PSObject.Properties['entries']) { throw "archive plan '$InventoryPlanPath' has no entries array" }
        $newEntries = @()
        $seenOriginals = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        $seenDestinations = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach ($entry in $existing.Entries) { [void]$seenOriginals.Add([string]$entry.originalPath); [void]$seenDestinations.Add([string]$entry.destination) }
        foreach ($planned in @($plan.entries)) {
            $original = [string]$planned.originalPath
            $destination = [string]$planned.destination
            if ([string]::IsNullOrWhiteSpace($original) -or [string]::IsNullOrWhiteSpace($destination)) { throw 'archive plan contains an entry without originalPath or destination' }
            if ($original.StartsWith('docs/pre-adoption/', [StringComparison]::Ordinal)) { throw "archive plan source is already an archive path: '$original'" }
            [void](Get-AaContainedPath -Root $Root -Relative $original)
            $destinationFull = Get-AaContainedPath -Root $Root -Relative $destination
            if (-not $destination.StartsWith('docs/pre-adoption/', [StringComparison]::Ordinal)) { throw "archive plan destination is outside docs/pre-adoption: '$destination'" }
            if (Get-AaReparseAncestor -Root $Root -Path $destinationFull) { throw "archive plan destination traverses a reparse point: '$destination'" }
            if (Test-Path -LiteralPath $destinationFull) { throw "archive plan destination already exists: '$destination'" }
            if (-not $seenOriginals.Add($original) -or -not $seenDestinations.Add($destination)) { throw "archive plan duplicates an existing original or destination: '$original' -> '$destination'" }
            $captured = New-AaEvidenceEntry -Root $Root -OriginalRelative $original -DestinationRelative $destination -EntryOwner 'workflow'
            $captured['verified'] = $false
            $newEntries += [pscustomobject]$captured
        }
        $document.archiveIntegrity.entries = @($existing.Entries) + @($newEntries)
        # This is the one permitted identity refresh: all newly selected workflow sources have just
        # been captured and no workflow move has begun. Progress writes thereafter retain it.
        $document.archiveIntegrity.inventoryIdentity = New-AaInventoryIdentity -Entries @($document.archiveIntegrity.entries)
        $document.archivedOriginals = @($document.archiveIntegrity.entries | Where-Object { $_.verified } | ForEach-Object { [string]$_.destination })
        $document.archiveIntegrity | Add-Member -NotePropertyName frozenAt -NotePropertyValue (Get-Date).ToString('o') -Force
        Write-AaJsonDocument -Root $Root -Path $MarkerPath -Document $document
        Write-Output "FROZEN: $($newEntries.Count) workflow archive candidate(s); complete inventory now has $(@($document.archiveIntegrity.entries).Count) entry(ies)."
    } catch {
        Write-AaError "ERROR: could not freeze workflow archive inventory before any move: $($_.Exception.Message)"
        exit 3
    }
}

function Invoke-AaMoveFrozen {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$MarkerPath, [Parameter(Mandatory = $true)][string]$OriginalRelative, [Parameter(Mandatory = $true)][string]$DestinationRelative)
    $document = $null
    try {
        $document = Read-AaJsonDocument -Path $MarkerPath
        $script:AaValidationRoot = $Root
        $shape = Test-AaIntegrityStructure -Document $document -AllowUnverified
        if (-not $shape.Valid) { throw "marker $($shape.Detail)" }
        $matches = @($shape.Entries | Where-Object { ([string]$_.originalPath -ceq $OriginalRelative) -and ([string]$_.destination -ceq $DestinationRelative) })
        if ($matches.Count -ne 1) { throw "frozen marker has no exact unique entry for '$OriginalRelative' -> '$DestinationRelative'" }
        $entry = $matches[0]
        if ($entry.verified) { throw "frozen entry '$OriginalRelative' -> '$DestinationRelative' is already verified; refusing to rebaseline or move it again" }
        $source = Get-AaContainedPath -Root $Root -Relative $OriginalRelative
        $destination = Get-AaContainedPath -Root $Root -Relative $DestinationRelative
        if (Get-AaReparseAncestor -Root $Root -Path $source) { throw "source '$OriginalRelative' traverses a reparse point" }
        if (Get-AaReparseAncestor -Root $Root -Path $destination) { throw "destination '$DestinationRelative' traverses a reparse point" }
        $sourceItem = Get-Item -Force -LiteralPath $source -ErrorAction SilentlyContinue
        $destinationItem = Get-Item -Force -LiteralPath $destination -ErrorAction SilentlyContinue
        if (-not $sourceItem -and $destinationItem) {
            $detail = ''
            $recovery = Test-AaArchivedBytes -Root $Root -DestinationRelative $DestinationRelative -ExpectedSha ([string]$entry.sha256) -ExpectedLength ([int64]$entry.byteLength) -Detail ([ref]$detail)
            if ($recovery -eq 'PASS') {
                $entry.verified = $true
                $document.archivedOriginals = @($document.archiveIntegrity.entries | Where-Object { $_.verified } | ForEach-Object { [string]$_.destination })
                Write-AaJsonDocument -Root $Root -Path $MarkerPath -Document $document
                Write-Output "RECOVERED: '$OriginalRelative' -> '$DestinationRelative' already matches the pre-frozen digest."
                return
            }
            Stop-AaFrozenMove -Root $Root -MarkerPath $MarkerPath -Document $document -Message "frozen source '$OriginalRelative' is absent and existing destination '$DestinationRelative' is ${recovery}: $detail" -ExitCode $(if ($recovery -eq 'CORRUPTION') { 6 } else { 5 })
        }
        if (-not $sourceItem) { throw "source '$OriginalRelative' is missing" }
        if ($destinationItem) { throw "destination already exists: '$DestinationRelative' (refusing to rebaseline an existing archive)" }
        $sourceBytes = [IO.File]::ReadAllBytes($source)
        if ([int64]$sourceBytes.LongLength -ne [int64]$entry.byteLength -or (Get-AaSha256Hex -Bytes $sourceBytes) -cne ([string]$entry.sha256).ToLowerInvariant()) {
            Stop-AaFrozenMove -Root $Root -MarkerPath $MarkerPath -Document $document -Message "frozen source '$OriginalRelative' changed before its archive move; it was not moved or re-hashed." -ExitCode 6
        }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
        Move-Item -LiteralPath $source -Destination $destination
    } catch {
        Stop-AaFrozenMove -Root $Root -MarkerPath $MarkerPath -Document $document -Message "frozen archive move '$OriginalRelative' -> '$DestinationRelative' failed: $($_.Exception.Message)" -ExitCode 3
    }
    $detail = ''
    $verdict = Test-AaArchivedBytes -Root $Root -DestinationRelative $DestinationRelative -ExpectedSha ([string]$entry.sha256) -ExpectedLength ([int64]$entry.byteLength) -Detail ([ref]$detail)
    if ($verdict -ne 'PASS') {
        Stop-AaFrozenMove -Root $Root -MarkerPath $MarkerPath -Document $document -Message "post-move verification of '$DestinationRelative' returned ${verdict}: $detail" -ExitCode $(if ($verdict -eq 'CORRUPTION') { 6 } else { 5 })
    }
    try {
        $entry.verified = $true
        $document.archivedOriginals = @($document.archiveIntegrity.entries | Where-Object { $_.verified } | ForEach-Object { [string]$_.destination })
        Write-AaJsonDocument -Root $Root -Path $MarkerPath -Document $document
    } catch {
        Write-AaError "ERROR: archive bytes for '$DestinationRelative' passed, but verified progress could not be persisted: $($_.Exception.Message)"
        exit 3
    }
    Write-Output "MOVED: '$OriginalRelative' -> '$DestinationRelative' bytes match the pre-frozen digest."
}

# ---- CLI dispatch ---------------------------------------------------------------------------------
$modeCount = @($Capture, $Freeze, $MoveFrozen, $Verify | Where-Object { $_ }).Count
if ($modeCount -ne 1) {
    Write-AaError 'ERROR: pass exactly one of -Capture, -Freeze, -MoveFrozen or -Verify.'
    exit 2
}
try { $repoFull = (Resolve-Path -LiteralPath $RepoRoot -ErrorAction Stop).Path }
catch { Write-AaError "ERROR: -RepoRoot '$RepoRoot' does not exist."; exit 2 }

if ($Verify) {
    if ([string]::IsNullOrWhiteSpace($EvidencePath)) { Write-AaError 'ERROR: -Verify requires -EvidencePath.'; exit 2 }
    try { $evidenceFull = Resolve-AaRepositoryPath -Root $repoFull -Path $EvidencePath -Kind 'evidence' }
    catch { Write-AaError "ERROR: $($_.Exception.Message)"; exit 2 }
    $report = Invoke-AaVerify -Root $repoFull -EvidenceFile $evidenceFull
    foreach ($line in $report.Lines) { Write-Output $line }
    Write-Output "RESULT: $($report.Result)"
    switch ($report.Result) {
        'PASS'        { exit 0 }
        'CANT-VERIFY' { exit 5 }
        'FAIL'        { exit 6 }
    }
}

if ($Freeze) {
    if ([string]::IsNullOrWhiteSpace($EvidencePath) -or [string]::IsNullOrWhiteSpace($PlanPath)) { Write-AaError 'ERROR: -Freeze requires -EvidencePath and -PlanPath.'; exit 2 }
    try {
        $evidenceFull = Resolve-AaRepositoryPath -Root $repoFull -Path $EvidencePath -Kind 'evidence'
        $planFull = Resolve-AaRepositoryPath -Root $repoFull -Path $PlanPath -Kind 'plan'
    } catch { Write-AaError "ERROR: $($_.Exception.Message)"; exit 2 }
    Invoke-AaFreeze -Root $repoFull -MarkerPath $evidenceFull -InventoryPlanPath $planFull
    exit 0
}

if ($MoveFrozen) {
    if ([string]::IsNullOrWhiteSpace($EvidencePath) -or [string]::IsNullOrWhiteSpace($OriginalPath) -or [string]::IsNullOrWhiteSpace($Destination)) { Write-AaError 'ERROR: -MoveFrozen requires -EvidencePath, -OriginalPath and -Destination.'; exit 2 }
    try { $evidenceFull = Resolve-AaRepositoryPath -Root $repoFull -Path $EvidencePath -Kind 'evidence' }
    catch { Write-AaError "ERROR: $($_.Exception.Message)"; exit 2 }
    Invoke-AaMoveFrozen -Root $repoFull -MarkerPath $evidenceFull -OriginalRelative $OriginalPath -DestinationRelative $Destination
    exit 0
}

if ([string]::IsNullOrWhiteSpace($OriginalPath) -or [string]::IsNullOrWhiteSpace($Destination)) {
    Write-AaError 'ERROR: -Capture requires -OriginalPath and -Destination.'
    exit 2
}

try { $entry = New-AaEvidenceEntry -Root $repoFull -OriginalRelative $OriginalPath -DestinationRelative $Destination -EntryOwner $Owner }
catch {
    Write-AaError "ERROR: $($_.Exception.Message)"
    exit 3
}

if ($Capture) {
    Write-Output (ConvertTo-AaJson -Value ([pscustomobject]$entry))
    exit 0
}
