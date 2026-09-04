# Install the AI Tech Lead Framework into a target repository.
# Usage: pwsh scripts/install.ps1 [-GitHooks] [-AllowDirtyTree] [-WhatIf] [-AllowDowngrade] C:\path\to\target-repo
#
# Copies the template's framework files into the target, EXCLUDING the .git directory, the
# .template-repo marker (which would disable the consumer's CI guardrail), the template repo's own
# meta files (README.md, CHANGELOG.md, .gitignore, .gitattributes), and the installer itself.
#
# Three modes, detected automatically:
#   greenfield — target has no AI tooling: plain copy; next step is /bootstrap.
#   brownfield — target already has AI tooling (CLAUDE.md, .cursorrules, Copilot instructions,
#                ADRs, ...): the originals this copy would overwrite are moved to docs/pre-adoption/
#                first, and .claude/adoption-pending.json is written so every later session (and CI)
#                steers to /adopt. Next step is /adopt.
#   update     — target already carries .claude/framework-version.json. Consumer-owned protected
#                paths are restored; framework-owned machinery is overwritten; mixed-ownership
#                .claude/settings.json is backed up, refreshed, and adapted to the host.
param(
    [Parameter(Mandatory = $true)][string]$Target,
    [switch]$GitHooks,
    [switch]$AllowDirtyTree,
    [switch]$WhatIf,
    [switch]$AllowDowngrade
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Target -PathType Container)) { Write-Error "Target '$Target' is not a directory."; exit 2 }

$src = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$tgt = (Resolve-Path $Target).Path
if ($tgt -eq $src) { Write-Error "Target is the template repo itself — choose a different target."; exit 2 }

# Brownfield archive paths must never traverse a reparse point. Resolving a target path is not
# enough: a junction/symlink below it can redirect either the collision source or the archive
# destination outside the consumer repository before Move-Item gets a chance to report anything.
function Get-ReparsePointAncestor {
    param([Parameter(Mandatory = $true)][string]$Path)
    $current = $Path
    while ($true) {
        # Get-Item -Force sees a dangling link where Test-Path reports false. Do not replace this
        # with a Test-Path guard: that was the route by which a broken link escaped preflight.
        $item = Get-Item -Force -LiteralPath $current -ErrorAction SilentlyContinue
        if ($item -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { return $current }
        if ($current -eq $tgt) { return $null }
        $parent = Split-Path -Parent $current
        if (-not $parent -or $parent -eq $current) { return $null }
        $current = $parent
    }
}

function Get-ContainedTargetPath {
    param([Parameter(Mandatory = $true)][string]$Relative)
    if ([string]::IsNullOrWhiteSpace($Relative) -or $Relative.Contains('\') -or $Relative.Contains([char]0) -or
        $Relative.StartsWith('/') -or $Relative.StartsWith('//') -or $Relative -match '^[A-Za-z]:' ) {
        throw "unsafe or non-normalized path '$Relative'"
    }
    foreach ($segment in $Relative.Split('/')) {
        if ([string]::IsNullOrEmpty($segment) -or $segment -eq '.' -or $segment -eq '..') {
            throw "unsafe or non-normalized path '$Relative'"
        }
    }
    $full = [IO.Path]::GetFullPath((Join-Path $tgt ($Relative -replace '/', [IO.Path]::DirectorySeparatorChar)))
    $prefix = $tgt.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "path escapes the target: '$Relative'" }
    return $full
}

function Assert-SafeTargetMutation {
    param([Parameter(Mandatory = $true)][string]$Relative, [switch]$AllowTree)
    $destination = Get-ContainedTargetPath -Relative $Relative
    $reparse = Get-ReparsePointAncestor -Path $destination
    if ($reparse) {
        [Console]::Error.WriteLine("ERROR: Refusing install mutation '$Relative': target path traverses reparse/symlink '$reparse'. Remove the link, then re-run.")
        exit 3
    }
    $item = Get-Item -Force -LiteralPath $destination -ErrorAction SilentlyContinue
    if ($item -and -not $AllowTree -and -not (Test-Path -LiteralPath $destination -PathType Leaf)) {
        [Console]::Error.WriteLine("ERROR: Refusing install mutation '$Relative': existing target is not a regular file.")
        exit 3
    }
    $parent = Split-Path -Parent $destination
    while ($parent -and $parent.StartsWith($tgt, [StringComparison]::OrdinalIgnoreCase)) {
        $parentItem = Get-Item -Force -LiteralPath $parent -ErrorAction SilentlyContinue
        if ($parentItem -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
            [Console]::Error.WriteLine("ERROR: Refusing install mutation '$Relative': parent '$parent' is not a directory.")
            exit 3
        }
        if ($parent -eq $tgt) { break }
        $parent = Split-Path -Parent $parent
    }
    return $destination
}

function Read-OwnershipManifest {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Label)
    $document = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    if ([int]$document.'schema-version' -ne 1 -or $null -eq $document.paths) { throw "$Label has an unsupported or missing schema" }
    $entries = @($document.paths)
    if ($entries.Count -eq 0) { throw "$Label contains no paths" }
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $byPath = @{}
    foreach ($entry in $entries) {
        $relative = [string]$entry.path
        $ownership = [string]$entry.ownership
        [void](Get-ContainedTargetPath -Relative $relative)
        if (-not $seen.Add($relative)) { throw "$Label contains duplicate path '$relative'" }
        if ($ownership -notin @('framework-owned/overwritten', 'consumer-owned/protected', 'mixed')) {
            throw "$Label has unsupported ownership '$ownership' for '$relative'"
        }
        $byPath[$relative] = $ownership
    }
    return [pscustomobject]@{ Entries = $entries; ByPath = $byPath }
}

function Read-RetirementLedger {
    param([Parameter(Mandatory = $true)][string]$Path)
    $document = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    if ([int]$document.'schema-version' -ne 1 -or $null -eq $document.retirements) { throw 'retirement ledger has an unsupported or missing schema' }
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $byPath = @{}
    foreach ($entry in @($document.retirements)) {
        $relative = [string]$entry.path
        $version = [string]$entry.'retired-in'
        $hashes = @($entry.'known-content-sha256' | ForEach-Object { [string]$_ })
        [void](Get-ContainedTargetPath -Relative $relative)
        if (-not $seen.Add($relative)) { throw "retirement ledger contains duplicate path '$relative'" }
        if ($version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { throw "retirement ledger has invalid retired-in version '$version' for '$relative'" }
        if ($hashes.Count -eq 0 -or @($hashes | Where-Object { $_ -cnotmatch '^[0-9a-f]{64}$' }).Count -gt 0 -or @($hashes | Select-Object -Unique).Count -ne $hashes.Count) {
            throw "retirement ledger has invalid or duplicate known-content-sha256 values for '$relative'"
        }
        $byPath[$relative] = [pscustomobject]@{ Version = $version; Hashes = $hashes }
    }
    return $byPath
}

function Compare-ReleaseVersion {
    param([string]$Left, [string]$Right)
    if ($Left -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$' -or $Right -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
        throw "versions must use release SemVer form X.Y.Z (installed='$Left', incoming='$Right')"
    }
    $a = $Left.Split('.'); $b = $Right.Split('.')
    for ($i = 0; $i -lt 3; $i++) {
        $an = $a[$i].TrimStart('0'); if ($an.Length -eq 0) { $an = '0' }
        $bn = $b[$i].TrimStart('0'); if ($bn.Length -eq 0) { $bn = '0' }
        if ($an.Length -lt $bn.Length) { return -1 }
        if ($an.Length -gt $bn.Length) { return 1 }
        $cmp = [StringComparer]::Ordinal.Compare($an, $bn)
        if ($cmp -lt 0) { return -1 }; if ($cmp -gt 0) { return 1 }
    }
    return 0
}

$gitHookRelative = $null
if ($GitHooks) {
    & (Join-Path $src 'scripts/setup-git-hooks.ps1') -Target $tgt -CheckOnly
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $gitRoot = [string]((& git -C $tgt rev-parse --show-toplevel 2>$null) -join "`n").Trim()
    $gitDir = [string]((& git -C $tgt rev-parse --git-dir 2>$null) -join "`n").Trim()
    if ($LASTEXITCODE -ne 0 -or -not $gitRoot -or -not $gitDir) {
        [Console]::Error.WriteLine('ERROR: Git-hook setup passed its check but the installer could not resolve its mutation target.')
        exit 3
    }
    if (-not [IO.Path]::IsPathRooted($gitDir)) { $gitDir = Join-Path $gitRoot $gitDir }
    $gitHookPath = [IO.Path]::GetFullPath((Join-Path $gitDir 'hooks/pre-commit'))
    $targetPrefix = $tgt.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $gitHookPath.StartsWith($targetPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        [Console]::Error.WriteLine("ERROR: Git-hook setup would write outside the selected target ('$gitHookPath'). Linked/external Git directories are not supported by installer planning.")
        exit 3
    }
    $gitHookRelative = $gitHookPath.Substring($targetPrefix.Length) -replace '\\', '/'
}

# Template-repo meta files that must never land in (or overwrite their namesakes in) a consumer repo.
$metaFiles = @('.git', '.template-repo', 'README.md', 'CHANGELOG.md', '.gitignore', '.gitattributes')

# Consumer files the copy below would otherwise clobber. Update skips them directly; brownfield
# archives them unless the copy-if-absent policy below keeps the live path for in-place screening.
$protected = @('CLAUDE.md', 'AGENTS.md', 'TECH_DEBT.md', 'SECURITY_FINDINGS.md', 'LEARNINGS.md',
    'FRAMEWORK-CONTEXT.md', '.github/copilot-instructions.md', 'docs/ARCHITECTURE.md',
    'docs/architecture-decisions.md')
# Persistent state is copied only when absent. The composer reads this policy from both installer
# twins and emits it as consumer-owned/protected in framework-ownership.json.
$persistentCopyIfAbsent = @(
    '.claude/ai-audit.log'
)
# These are never bulk-replaced, so brownfield must not archive them merely because the incoming
# ownership manifest lists them. The audit entry remains the separately composer-verified
# persistent policy above.
$copyIfAbsent = $persistentCopyIfAbsent + @(
    'docs/wiki/INDEX.md', 'docs/ARCHITECTURE.md', 'docs/architecture-decisions.md'
)

# Signals that the target already has AI tooling and therefore needs /adopt, not /bootstrap
# (mirrors /adopt Phase 1 discovery).
$adoptionSignals = @('CLAUDE.md', 'AGENTS.md', 'GEMINI.md', '.cursorrules', '.cursor/rules',
    '.clinerules', '.windsurfrules', '.roomodes', '.aider.conf.yml', '.continue',
    '.github/copilot-instructions.md', '.github/instructions', '.github/chatmodes',
    '.github/skills',
    'docs/adr', 'docs/decisions', 'ARCHITECTURE.md', 'docs/ARCHITECTURE.md', 'CODEMAP.md',
    'CONVENTIONS.md', 'docs/CONVENTIONS.md', 'TECH_DEBT.md', 'TODO.md', 'BACKLOG.md',
    'docs/wiki/INDEX.md')

$updateMode = Test-Path -LiteralPath (Join-Path $tgt '.claude/framework-version.json')
$detected = @()
if (-not $updateMode) {
    $detected = @($adoptionSignals | Where-Object { Test-Path -LiteralPath (Join-Path $tgt $_) })
}
$adoptMode = (-not $updateMode) -and ($detected.Count -gt 0)

# The incoming manifest inventories installed files; the separately authored retirement ledger is
# the only stale-path deletion authority. Validate both before any target mutation.
$incomingManifest = Join-Path $src 'framework-ownership.json'
try {
    $incoming = Read-OwnershipManifest -Path $incomingManifest -Label 'incoming framework ownership manifest'
    $incomingPaths = @($incoming.Entries | ForEach-Object { [string]$_.path })
    foreach ($relative in $incomingPaths) {
        if (-not (Test-Path -LiteralPath (Join-Path $src $relative) -PathType Leaf)) { throw "incoming manifest path '$relative' is not a shipped file" }
    }
    $retirementLedger = Read-RetirementLedger -Path (Join-Path $src 'framework-retirements.json')
    foreach ($retiredPath in $retirementLedger.Keys) {
        if ($incoming.ByPath.ContainsKey($retiredPath)) { throw "retirement '$retiredPath' is still present in the incoming ownership manifest" }
    }
} catch {
    [Console]::Error.WriteLine("ERROR: Cannot validate incoming framework metadata: $($_.Exception.Message)")
    exit 3
}

$incomingVersionPath = Join-Path $src '.claude/framework-version.json'
try {
    $incomingVersion = [string](Get-Content -Raw -LiteralPath $incomingVersionPath | ConvertFrom-Json).version
    [void](Compare-ReleaseVersion -Left $incomingVersion -Right $incomingVersion)
} catch {
    [Console]::Error.WriteLine("ERROR: Cannot validate incoming framework version: $($_.Exception.Message)")
    exit 3
}
if ($updateMode) {
    try {
        $installedVersion = [string](Get-Content -Raw -LiteralPath (Join-Path $tgt '.claude/framework-version.json') | ConvertFrom-Json).version
        $versionComparison = Compare-ReleaseVersion -Left $installedVersion -Right $incomingVersion
    } catch {
        [Console]::Error.WriteLine("CANT-VERIFY: Installed framework version cannot be compared safely: $($_.Exception.Message)")
        exit 4
    }
    if ($versionComparison -gt 0 -and -not $AllowDowngrade) {
        [Console]::Error.WriteLine("ERROR: Refusing framework downgrade from $installedVersion to $incomingVersion before mutation. Re-run with -AllowDowngrade only after reviewing the older release.")
        exit 4
    }
}

# These legal files are neither protected nor ordinary framework files. Protection would freeze a
# stale framework-owned notice; bulk copying would silently clobber consumer files. Preflight their
# explicit ownership policy before this installer mutates the target, then copy them after the bulk.
$legalLicense = 'LICENSES/ai-tech-lead-MIT.txt'
$legalNotice = 'NOTICE-ai-tech-lead.md'
$sourceLicense = Join-Path $src $legalLicense
$targetLicense = Join-Path $tgt $legalLicense
$targetNotice = Join-Path $tgt $legalNotice
$copyLegalLicense = $true
if (Test-Path -LiteralPath $targetLicense -PathType Leaf) {
    $sourceText = [IO.File]::ReadAllText($sourceLicense) -replace "`r`n", "`n" -replace "`r", "`n"
    $targetText = [IO.File]::ReadAllText($targetLicense) -replace "`r`n", "`n" -replace "`r", "`n"
    if ($sourceText -cne $targetText) {
        [Console]::Error.WriteLine("ERROR: Refusing to overwrite '$legalLicense': the existing file is not identical to the framework licence.")
        exit 3
    }
    $copyLegalLicense = $false
}
if ((Test-Path -LiteralPath $targetNotice -PathType Leaf) -and
    -not ([IO.File]::ReadAllText($targetNotice).Contains('FRAMEWORK-OWNED'))) {
    [Console]::Error.WriteLine("ERROR: Refusing to overwrite '$legalNotice': the existing file is not marked FRAMEWORK-OWNED.")
    exit 3
}

# Previous ownership is consumer-mutable evidence, never deletion authority. Reconciliation is
# enabled only when the whole previous manifest is valid, and every candidate also matches bytes
# named by the incoming framework-authored ledger.
$deletePlan = New-Object System.Collections.Generic.List[string]
$retirementPreserve = New-Object System.Collections.Generic.List[string]
$reconciliationMessages = New-Object System.Collections.Generic.List[string]
if ($updateMode) {
    $previousManifestPath = Join-Path $tgt 'framework-ownership.json'
    if (-not (Test-Path -LiteralPath $previousManifestPath -PathType Leaf)) {
        $reconciliationMessages.Add('CANT-VERIFY: previous framework-ownership.json is missing; additive compatibility mode will perform no stale deletion.')
    } elseif (Get-ReparsePointAncestor -Path $previousManifestPath) {
        $reconciliationMessages.Add('CANT-VERIFY: previous framework-ownership.json traverses a reparse/symlink; additive compatibility mode will perform no stale deletion.')
    } else {
        try {
            $previous = Read-OwnershipManifest -Path $previousManifestPath -Label 'previous framework ownership manifest'
        } catch {
            $previous = $null
            $reconciliationMessages.Add("CANT-VERIFY: previous framework-ownership.json is malformed or unsafe; additive compatibility mode will perform no stale deletion. $($_.Exception.Message)")
        }
        if ($previous) {
            foreach ($retiredPath in @($retirementLedger.Keys | Sort-Object)) {
                if (-not $previous.ByPath.ContainsKey($retiredPath) -or
                    $previous.ByPath[$retiredPath] -ne 'framework-owned/overwritten' -or
                    $incoming.ByPath.ContainsKey($retiredPath) -or $retiredPath -in $persistentCopyIfAbsent) { continue }
                $candidate = Get-ContainedTargetPath -Relative $retiredPath
                if (-not (Test-Path -LiteralPath $candidate)) { continue }
                $reparse = Get-ReparsePointAncestor -Path $candidate
                if ($reparse) {
                    $reconciliationMessages.Add("CANT-VERIFY: retired path '$retiredPath' traverses reparse/symlink '$reparse'; preserving it.")
                    $retirementPreserve.Add($retiredPath)
                    continue
                }
                if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                    $reconciliationMessages.Add("CANT-VERIFY: retired path '$retiredPath' is not a regular file; preserving it.")
                    $retirementPreserve.Add($retiredPath)
                    continue
                }
                try { $digest = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLowerInvariant() }
                catch {
                    $reconciliationMessages.Add("CANT-VERIFY: retired path '$retiredPath' could not be hashed; preserving it.")
                    $retirementPreserve.Add($retiredPath)
                    continue
                }
                if ($digest -notin @($retirementLedger[$retiredPath].Hashes)) {
                    $reconciliationMessages.Add("CANT-VERIFY: retired path '$retiredPath' has consumer-modified or unknown content; preserving it.")
                    $retirementPreserve.Add($retiredPath)
                    continue
                }
                $deletePlan.Add($retiredPath)
            }
        }
    }
}

# A retirement can delete only where the immediately previous manifest grants authority. That
# limitation must not hide a retained high-priority GitHub skill or the old sync script on a later
# update: inspect these exact ledger paths read-only, without granting deletion authority.
if ($updateMode) {
    foreach ($retiredPath in @($retirementLedger.Keys | Sort-Object)) {
        $isGitHubSkill = $retiredPath -match '^\.github/skills/([^/]+)/'
        $slug = if ($isGitHubSkill) { $Matches[1] } else { $null }
        $isRetiredSyncScript = $retiredPath -in @('scripts/sync-agent-files.ps1', 'scripts/sync-agent-files.sh')
        if ((-not $isGitHubSkill -and -not $isRetiredSyncScript) -or $deletePlan.Contains($retiredPath)) { continue }
        $candidate = Get-ContainedTargetPath -Relative $retiredPath
        try { $entry = Get-Item -Force -LiteralPath $candidate -ErrorAction Stop }
        catch [Management.Automation.ItemNotFoundException] { continue }
        catch {
            $reconciliationMessages.Add("CANT-VERIFY: retained retired path '$retiredPath' could not be examined; preserving it without inspection.")
            continue
        }
        $reparse = Get-ReparsePointAncestor -Path $candidate
        if ($reparse) {
            $reconciliationMessages.Add("CANT-VERIFY: retained retired path '$retiredPath' traverses reparse/symlink '$reparse'; preserving it without inspection.")
            continue
        }
        if ($isGitHubSkill) {
            $reconciliationMessages.Add("CANT-VERIFY: retained retired path '$retiredPath' was not deleted; it may shadow canonical .claude/skills/$slug. Move intentional customization to .claude/skills/$slug and remove the retained GitHub copy after review.")
        } else {
            $reconciliationMessages.Add("CANT-VERIFY: retained retired path '$retiredPath' was not deleted; running it may recreate higher-priority .github/skills shadows. Do not run it; migrate or retire it after review.")
        }
    }
}

# Find one named directory entry without dereferencing it. Get-Item -Force sees a dangling link
# where Test-Path reports false. A direct lookup also works when an ancestor grants traversal but
# not directory-list permission; only ItemNotFound means absence, while any other failure escapes.
function Get-GitChildEntry {
    param([Parameter(Mandatory = $true)][string]$Directory, [Parameter(Mandatory = $true)][string]$Name)
    try { return (Get-Item -Force -LiteralPath (Join-Path $Directory $Name) -ErrorAction Stop).FullName }
    catch [Management.Automation.ItemNotFoundException] { return $null }
}

function Test-GitRepositoryEvidence {
    param([Parameter(Mandatory = $true)][string]$Path)
    $current = [IO.DirectoryInfo]::new([IO.Path]::GetFullPath($Path))
    while ($null -ne $current) {
        if (Get-GitChildEntry -Directory $current.FullName -Name '.git') { return $true }
        $current = $current.Parent
    }

    # Bare repositories have no .git entry. Keep this signature deliberately strict: weakening it
    # makes ordinary directories look repository-like and turns optional Git into a prerequisite.
    $head = Get-GitChildEntry -Directory $Path -Name 'HEAD'
    $objects = Get-GitChildEntry -Directory $Path -Name 'objects'
    $refs = Get-GitChildEntry -Directory $Path -Name 'refs'
    if (-not $head -or -not $objects -or -not $refs) { return $false }
    $directory = [IO.FileAttributes]::Directory
    $headAttributes = [IO.File]::GetAttributes($head)
    $objectAttributes = [IO.File]::GetAttributes($objects)
    $refAttributes = [IO.File]::GetAttributes($refs)
    return (($headAttributes -band $directory) -eq 0 -and
        ($objectAttributes -band $directory) -ne 0 -and ($refAttributes -band $directory) -ne 0)
}

# Windows PowerShell 5.1 promotes redirected native stderr to NativeCommandError when the caller's
# preference is Stop. Keep the suppression function-local, capture stdout separately, and retain a
# nullable exit so a launch failure can never be mistaken for exit 0. Preserve the record count as
# well: a blank native stdout line normalizes to an empty string but is still non-empty status.
function Invoke-GitText {
    param([Parameter(Mandatory = $true)][string]$GitPath, [Parameter(Mandatory = $true)][string[]]$Arguments)
    $priorPreference = $ErrorActionPreference
    $stdout = @()
    $exitCode = $null
    try {
        $ErrorActionPreference = 'Continue'
        # LASTEXITCODE is maintained in the runspace's global scope. Creating a local variable here
        # shadows the value the native adapter updates and makes a successful launch look absent.
        $global:LASTEXITCODE = $null
        try {
            $stdout = @(& $GitPath @Arguments 2>$null)
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
        Started = ($null -ne $exitCode)
        ExitCode = $exitCode
        Output = $normalized
        RecordCount = $stdout.Count
    }
}

function Stop-UnverifiableGitPreflight {
    [Console]::Error.WriteLine('CANT-VERIFY: Git state for this update/brownfield target could not be verified safely. Unset Git routing variables, install or repair Git, or repair/remove corrupt repository metadata, then re-run the installer.')
    exit 4
}

# Git is optional for a plain target, but repository evidence or redirected Git state must never be
# reinterpreted as non-Git. Refuse before mutation unless Git authoritatively identifies the target
# and its porcelain status can be read through the selected target path.
if (-not $WhatIf -and ($adoptMode -or $updateMode)) {
    foreach ($name in @('GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR', 'GIT_INDEX_FILE')) {
        $value = [Environment]::GetEnvironmentVariable($name, 'Process')
        if ($null -ne $value -and $value.Length -gt 0) { Stop-UnverifiableGitPreflight }
    }

    try { $repositoryEvidence = Test-GitRepositoryEvidence -Path $tgt }
    catch { Stop-UnverifiableGitPreflight }

    $gitCommands = @(Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($gitCommands.Count -eq 0) {
        if ($repositoryEvidence) { Stop-UnverifiableGitPreflight }
    } else {
        $gitPath = [string]$gitCommands[0].Source
        $probe = Invoke-GitText -GitPath $gitPath -Arguments @('-C', $tgt, 'rev-parse', '--is-inside-work-tree')
        if ($probe.Started -and $probe.ExitCode -eq 0) {
            if ($probe.Output -cne 'true') { Stop-UnverifiableGitPreflight }
            $status = Invoke-GitText -GitPath $gitPath -Arguments @('--no-optional-locks', '-C', $tgt, 'status', '--porcelain=v1', '--untracked-files=all')
            if (-not $status.Started -or $status.ExitCode -ne 0) {
                [Console]::Error.WriteLine('CANT-VERIFY: Git identified this target as a worktree, but its status could not be read. Commit, stash, or copy local changes, then repair Git and re-run the installer.')
                exit 4
            }
            if ($status.RecordCount -gt 0) {
                if (-not $AllowDirtyTree) {
                    [Console]::Error.WriteLine('ERROR: Refusing to mutate a dirty Git target. Commit, stash, or copy local changes, then re-run; use -AllowDirtyTree only after doing so deliberately.')
                    exit 4
                }
                Write-Output '  override: -AllowDirtyTree (--allow-dirty-tree) accepted for this dirty Git target.'
            }
        } elseif ($repositoryEvidence) {
            Stop-UnverifiableGitPreflight
        }
    }
}

Write-Output "Installing AI Tech Lead Framework"
Write-Output "  from: $src"
Write-Output "  into: $tgt"
if ($updateMode)    { Write-Output "  mode: update (existing install detected via .claude/framework-version.json)" }
elseif ($adoptMode) { Write-Output "  mode: brownfield (pre-existing AI tooling detected: $($detected -join ', '))" }
else                { Write-Output "  mode: greenfield" }
if ($updateMode -and $versionComparison -gt 0 -and $AllowDowngrade) {
    Write-Output "  override: -AllowDowngrade accepted for downgrade $installedVersion -> $incomingVersion."
}
foreach ($message in $reconciliationMessages) { Write-Output "  $message" }

if ($updateMode) {
    Write-Output "  UPDATE PREFLIGHT: This update replaces framework-owned files, including .claude/settings.json."
    Write-Output "  Ensure any local edits to those files were committed, stashed, or copied first."
    Write-Output "  Review the resulting diff before committing."
}

$archived = @()
$archivePlan = New-Object System.Collections.Generic.List[object]
if ($adoptMode) {
    # Screen-in-place carriers remain at their consumer-owned paths, but only regular in-repo
    # files qualify. Refuse links/non-files before the broad collision loop skips them.
    foreach ($f in $copyIfAbsent) {
        $candidate = Join-Path $tgt $f
        $sourceReparse = Get-ReparsePointAncestor -Path $candidate
        if ($sourceReparse) {
            [Console]::Error.WriteLine("ERROR: Refusing screen-in-place path '$f': source path traverses reparse/symlink '$sourceReparse'. Remove the link or copy the original into the repository, then re-run.")
            exit 3
        }
        if ((Test-Path -LiteralPath $candidate) -and -not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            [Console]::Error.WriteLine("ERROR: Refusing screen-in-place path '$f': the target path is not a regular file.")
            exit 3
        }
    }
    $archivePaths = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    foreach ($f in $incomingPaths) {
        if ($f -in $copyIfAbsent -or $f -in @($legalLicense, $legalNotice)) { continue }
        $orig = Join-Path $tgt $f
        $sourceReparse = Get-ReparsePointAncestor -Path $orig
        if ($sourceReparse) {
            [Console]::Error.WriteLine("ERROR: Refusing brownfield collision '$f': source path traverses reparse/symlink '$sourceReparse'. Remove the link or copy the original into the repository, then re-run.")
            exit 3
        }
        if (-not (Test-Path -LiteralPath $orig)) { continue }
        if (-not (Test-Path -LiteralPath $orig -PathType Leaf)) {
            [Console]::Error.WriteLine("ERROR: Refusing brownfield collision '$f': the target path is not a file and cannot be archived safely.")
            exit 3
        }
        $rel = 'docs/pre-adoption/' + $f
        $dest = Join-Path $tgt $rel
        $destinationReparse = Get-ReparsePointAncestor -Path $dest
        if ($destinationReparse) {
            [Console]::Error.WriteLine("ERROR: Refusing brownfield install: archive destination traverses reparse/symlink '$destinationReparse'. Remove the link, then re-run.")
            exit 3
        }
        if (-not $archivePaths.Add($rel) -or (Test-Path -LiteralPath $dest)) {
            [Console]::Error.WriteLine("ERROR: Refusing brownfield install: archive destination already exists or is ambiguous: '$rel'.")
            exit 3
        }
        $parent = Split-Path -Parent $dest
        while ($parent -and $parent.StartsWith($tgt, [StringComparison]::OrdinalIgnoreCase)) {
            if ((Test-Path -LiteralPath $parent) -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
                [Console]::Error.WriteLine("ERROR: Refusing brownfield install: archive destination parent is not a directory: '$parent'.")
                exit 3
            }
            if ($parent -eq $tgt) { break }
            $parent = Split-Path -Parent $parent
        }
        $archivePlan.Add([pscustomobject]@{ Original = $orig; Relative = $rel; Destination = $dest })
    }
}

# Compute the complete deployment/reconciliation plan before the first target mutation. Legacy
# snapshot/restore writes are gone: protected files are skipped directly, and every skill backup
# and disable leaf is planned and preflighted before execution.
$createPlan = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
$replacePlan = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
$preservePlan = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
$archiveSources = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
$ordinaryApplyPaths = New-Object System.Collections.Generic.List[string]
$skillBackupPlan = New-Object System.Collections.Generic.List[object]
$disabledCarryPlan = New-Object System.Collections.Generic.List[object]
$disabledIncomingPlan = New-Object System.Collections.Generic.List[object]
$skillDeletePlan = New-Object System.Collections.Generic.List[string]
foreach ($entry in $archivePlan) { [void]$archiveSources.Add($entry.Relative.Substring('docs/pre-adoption/'.Length)) }

function Add-PlannedWrite {
    param([string]$Relative, [switch]$ForceCreate)
    $destination = Assert-SafeTargetMutation -Relative $Relative
    [void]$preservePlan.Remove($Relative)
    if ($ForceCreate -or -not (Test-Path -LiteralPath $destination)) {
        [void]$replacePlan.Remove($Relative); [void]$createPlan.Add($Relative)
    } else {
        [void]$createPlan.Remove($Relative); [void]$replacePlan.Add($Relative)
    }
    return $destination
}

$disabledSkillNames = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$discoveredSkillNames = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$skillExemplars = @{}
$incomingFrameworkSkillNames = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$incoming.Entries | ForEach-Object {
    $frameworkSkill = [regex]::Match([string]$_.path, '^\.claude/skills/([^/]+)/')
    if ($frameworkSkill.Success -and [string]$_.ownership -eq 'framework-owned/overwritten') {
        [void]$incomingFrameworkSkillNames.Add($frameworkSkill.Groups[1].Value)
    }
}
$activeSkillsRoot = Join-Path $tgt '.claude/skills'
if ($updateMode) {
    $learnings = Join-Path $tgt 'LEARNINGS.md'
    if (Test-Path -LiteralPath $learnings -PathType Leaf) {
        foreach ($m in [regex]::Matches((Get-Content -Raw -LiteralPath $learnings), '(?m)^## Disabled framework skill:\s*([a-z0-9-]+)\s*$')) { [void]$disabledSkillNames.Add($m.Groups[1].Value) }
    }
    if (Test-Path -LiteralPath $activeSkillsRoot -PathType Container) {
        foreach ($item in Get-ChildItem -LiteralPath $activeSkillsRoot -Recurse -Force) {
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                [Console]::Error.WriteLine("ERROR: Refusing update skill reconciliation: '$($item.FullName)' is a reparse/symlink."); exit 3
            }
        }
        foreach ($skillDir in Get-ChildItem -LiteralPath $activeSkillsRoot -Directory) {
            $skillFile = Join-Path $skillDir.FullName 'SKILL.md'
            if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) { continue }
            $oldText = Get-Content -Raw -LiteralPath $skillFile
            if ($oldText -match '(?m)^origin:\s*discovered\s*$') { [void]$discoveredSkillNames.Add($skillDir.Name); continue }
            # An exemplar belongs to a framework skill only when this incoming manifest still
            # carries that skill. Rewriting an unknown consumer skill just to re-append the same
            # line changes its bytes despite the framework having no ownership of that path.
            if (-not $incomingFrameworkSkillNames.Contains($skillDir.Name)) { continue }
            $exemplar = [regex]::Match($oldText, '(?m)^For a concrete current instance in this repo, see .+$')
            if ($exemplar.Success) { $skillExemplars[$skillDir.Name] = $exemplar.Value }
        }
    }
}

# The one-time backup is a set of leaf copies, not an opaque recursive directory mutation.
$backupSkillsRoot = Join-Path $tgt '.claude/framework-update-backup/skills'
if ($updateMode -and (Test-Path -LiteralPath $activeSkillsRoot -PathType Container) -and -not (Test-Path -LiteralPath $backupSkillsRoot)) {
    foreach ($file in Get-ChildItem -LiteralPath $activeSkillsRoot -Recurse -File -Force) {
        $underSkills = $file.FullName.Substring($activeSkillsRoot.Length).TrimStart('\', '/') -replace '\\', '/'
        $relative = ".claude/framework-update-backup/skills/$underSkills"
        [void](Add-PlannedWrite -Relative $relative -ForceCreate)
        $skillBackupPlan.Add([pscustomobject]@{ Source = $file.FullName; Relative = $relative })
    }
}

# Preserve every existing leaf of a disabled skill in its inactive location, then overlay the
# incoming framework version. Active copies are removed as explicit tree operations.
foreach ($name in $disabledSkillNames) {
    $activeRoot = Join-Path $activeSkillsRoot $name
    if (Test-Path -LiteralPath $activeRoot -PathType Container) {
        foreach ($file in Get-ChildItem -LiteralPath $activeRoot -Recurse -File -Force) {
            $underSkill = $file.FullName.Substring($activeRoot.Length).TrimStart('\', '/') -replace '\\', '/'
            $relative = ".claude/disabled-skills/$name/$underSkill"
            [void](Add-PlannedWrite -Relative $relative)
            $disabledCarryPlan.Add([pscustomobject]@{ Source = $file.FullName; Relative = $relative })
        }
        [void](Assert-SafeTargetMutation -Relative ".claude/skills/$name" -AllowTree)
        $skillDeletePlan.Add(".claude/skills/$name")
    }
}

foreach ($relative in $incomingPaths) {
    $claudeSkill = [regex]::Match($relative, '^\.claude/skills/([^/]+)/(.*)$')
    if ($updateMode -and $claudeSkill.Success -and $disabledSkillNames.Contains($claudeSkill.Groups[1].Value)) {
        $inactive = ".claude/disabled-skills/$($claudeSkill.Groups[1].Value)/$($claudeSkill.Groups[2].Value)"
        [void](Add-PlannedWrite -Relative $inactive)
        $disabledIncomingPlan.Add([pscustomobject]@{ Source = $relative; Relative = $inactive })
        continue
    }
    $destination = Get-ContainedTargetPath -Relative $relative
    $exists = $null -ne (Get-Item -Force -LiteralPath $destination -ErrorAction SilentlyContinue)
    $preserveDiscovered = $claudeSkill.Success -and $discoveredSkillNames.Contains($claudeSkill.Groups[1].Value)
    $preserve = $exists -and ($relative -in $copyIfAbsent -or
        ($updateMode -and $relative -in $protected) -or
        ($relative -eq $legalLicense -and -not $copyLegalLicense) -or $preserveDiscovered)
    if ($preserve) { [void]$preservePlan.Add($relative); continue }
    [void](Add-PlannedWrite -Relative $relative -ForceCreate:$archiveSources.Contains($relative))
    $ordinaryApplyPaths.Add($relative)
}
foreach ($relative in $retirementPreserve) { [void]$preservePlan.Add($relative) }

$settingsBackupRelative = $null
if ($updateMode -and (Test-Path -LiteralPath (Join-Path $tgt '.claude/settings.json') -PathType Leaf)) {
    $settingsBackupRelative = '.claude/.state/settings.json.pre-update'
    [void](Add-PlannedWrite -Relative $settingsBackupRelative)
}

$adoptionMarkerRelative = $null
if ($adoptMode) { $adoptionMarkerRelative = '.claude/adoption-pending.json'; [void](Add-PlannedWrite -Relative $adoptionMarkerRelative) }
if ($GitHooks) { [void](Add-PlannedWrite -Relative $gitHookRelative -ForceCreate) }

$modeName = if ($updateMode) { 'update' } elseif ($adoptMode) { 'brownfield' } else { 'greenfield' }
Write-Output "OPERATION-PLAN schema=1 mode=$modeName"
foreach ($category in @(
    [pscustomobject]@{ Name = 'create'; Values = $createPlan },
    [pscustomobject]@{ Name = 'replace'; Values = $replacePlan },
    [pscustomobject]@{ Name = 'preserve'; Values = $preservePlan },
    [pscustomobject]@{ Name = 'archive'; Values = @($archivePlan | ForEach-Object { $_.Relative }) },
    [pscustomobject]@{ Name = 'delete'; Values = @($deletePlan) + @($skillDeletePlan) }
)) {
    foreach ($relative in @($category.Values | Sort-Object -Unique)) { Write-Output "PLAN $($category.Name) $relative" }
}
if ($WhatIf) { Write-Output 'Dry run complete; target was not modified.'; exit 0 }

foreach ($entry in $archivePlan) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $entry.Destination) | Out-Null
    Move-Item -LiteralPath $entry.Original -Destination $entry.Destination
    $archived += $entry.Relative
    Write-Output "  archived: $($entry.Relative.Substring('docs/pre-adoption/'.Length)) -> $($entry.Relative)"
}
foreach ($relative in $deletePlan) {
    Remove-Item -Force -LiteralPath (Get-ContainedTargetPath -Relative $relative)
    Write-Output "  retired: $relative"
}
if ($settingsBackupRelative) {
    $settingsBackup = Get-ContainedTargetPath -Relative $settingsBackupRelative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $settingsBackup) | Out-Null
    Copy-Item -Force -LiteralPath (Join-Path $tgt '.claude/settings.json') -Destination $settingsBackup
    Write-Output "  saved pre-update settings: $settingsBackupRelative"
}
foreach ($entry in $skillBackupPlan) {
    $destination = Get-ContainedTargetPath -Relative $entry.Relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    Copy-Item -Force -LiteralPath $entry.Source -Destination $destination
}
foreach ($entry in $disabledCarryPlan) {
    $destination = Get-ContainedTargetPath -Relative $entry.Relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    Copy-Item -Force -LiteralPath $entry.Source -Destination $destination
}
foreach ($relative in $ordinaryApplyPaths) {
    $destination = Get-ContainedTargetPath -Relative $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    Copy-Item -Force -LiteralPath (Join-Path $src $relative) -Destination $destination
}
foreach ($entry in $disabledIncomingPlan) {
    $destination = Get-ContainedTargetPath -Relative $entry.Relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    Copy-Item -Force -LiteralPath (Join-Path $src $entry.Source) -Destination $destination
}
foreach ($name in $skillExemplars.Keys) {
    $base = if ($disabledSkillNames.Contains($name)) { ".claude/disabled-skills/$name" } else { ".claude/skills/$name" }
    $newFile = Join-Path $tgt "$base/SKILL.md"
    if (Test-Path -LiteralPath $newFile -PathType Leaf) {
        $newText = Get-Content -LiteralPath $newFile -Raw
        $newText = [regex]::Replace($newText, '(?m)^For a concrete current instance in this repo, see .+\r?\n?', '')
        Set-Content -LiteralPath $newFile -Value ($newText.TrimEnd() + "`n`n" + $skillExemplars[$name] + "`n") -Encoding UTF8
    }
}
foreach ($relative in $skillDeletePlan) {
    $path = Get-ContainedTargetPath -Relative $relative
    if (Test-Path -LiteralPath $path) { Remove-Item -Recurse -Force -LiteralPath $path }
}
if ($updateMode) { Write-Output "  consumer-owned content files left untouched ($($protected -join ', '))." }

if ($adoptMode) {
    # Durable adoption marker: the SessionStart hook warns every new session, and docs-sync-check
    # fails CI, until /adopt consumes it (deleted in /adopt Phase 3).
    $marker = [ordered]@{
        installedAt       = (Get-Date).ToString('yyyy-MM-dd')
        detectedArtifacts = $detected
        archivedOriginals = $archived
        nextStep          = '/adopt - a developer types it in a session, OR an agent runs it headless (read .claude/commands/adopt.md and follow its Headless mode, or use .github/prompts/adopt.prompt.md with a --headless directive). Headless prepares an adopt-ai-framework PR branch for human review; it does not auto-merge discovered content.'
        _comment          = 'Written by the framework installer because pre-existing AI tooling was detected. Consolidate it with /adopt - NOT /bootstrap. /adopt deletes this file in its Phase 3.'
    }
    $marker | ConvertTo-Json | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $tgt '.claude/adoption-pending.json')
}

# Claude Code hooks default to pwsh (PowerShell 7). If it isn't installed, fall back to the Windows
# PowerShell 5.1 variant (preinstalled on every Windows box) so the hooks still fire.
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    $sj  = Join-Path $tgt '.claude/settings.json'
    $sjw = Join-Path $tgt '.claude/settings.windows.json'
    if ((Test-Path $sjw) -and (Test-Path $sj)) {
        Copy-Item -Force -LiteralPath $sjw -Destination $sj
        Write-Output "  pwsh not found - activated Windows PowerShell 5.1 hooks (settings.windows.json -> settings.json)."
    }
}

if ($GitHooks) {
    & (Join-Path $tgt 'scripts/setup-git-hooks.ps1') -Target $tgt
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Output ""
Write-Output "Each developer should run  pwsh scripts/framework-doctor.ps1  once on their own machine."
if ($updateMode) {
    Write-Output "Done (update). Framework-owned machinery refreshed; the listed protected paths were left untouched; .claude/settings.json was backed up and refreshed."
    Write-Output "  Next: review the diff, run  pwsh scripts/docs-sync-check.ps1 , then commit."
} elseif ($adoptMode) {
    Write-Output "Done - but this repo is NOT ready for AI-assisted work yet: it has pre-existing AI"
    Write-Output "tooling that must be consolidated with /adopt. The originals this install displaced"
    Write-Output "are under docs/pre-adoption/; .claude/adoption-pending.json records the inventory."
    Write-Output ""
    Write-Output "Next steps in the target repo:"
    Write-Output "  1. Review and commit the copied files (they are team-shared config, not local settings)."
    Write-Output "  2. A DEVELOPER must start a Claude Code session in the target repo and type:  /adopt"
    Write-Output "     - /adopt is developer-initiated: AI agents and the model CANNOT invoke it, and it"
    Write-Output "       only exists inside a session started in the target repo."
    Write-Output "     - Do NOT run /bootstrap instead - it would skip the archive/merge/provenance flow."
    Write-Output "       The SessionStart hook and docs-sync-check flag this"
    Write-Output "       repo until /adopt has run."
    Write-Output ""
    Write-Output "  IF YOU ARE AN AI AGENT running this installer: your task is NOT complete until you"
    Write-Output "  have done step 1 (commit the copied files) and then EITHER told the developer to start a"
    Write-Output "  Claude Code session in the target repo and type /adopt, OR run headless adoption yourself:"
    Write-Output "  invoke the adopt workflow with a --headless directive (use .github/prompts/adopt.prompt.md,"
    Write-Output "  or read .claude/commands/adopt.md and follow its 'Headless mode'). Headless adoption"
    Write-Output "  PREPARES a PR: it creates the adopt-ai-framework branch, archives and screens the"
    Write-Output "  originals, and STAGES every CLAUDE.md/TECH_DEBT merge for a human to review - it does NOT"
    Write-Output "  apply untrusted discovered content and does NOT open or merge the PR, so a person still"
    Write-Output "  approves the staged changes. Do not replicate it by hand - run the real workflow (headless)"
    Write-Output "  or hand off to a developer. Report whichever you did as the next step in your final summary."
} else {
    Write-Output "Done. Next steps in the target repo:"
    Write-Output "  1. Review and commit the copied files (they are team-shared config, not local settings)."
    Write-Output "  2. A DEVELOPER must start a Claude Code session in the target repo and type:  /bootstrap"
    Write-Output "     - /bootstrap is developer-initiated: AI agents and the model CANNOT invoke it, and it"
    Write-Output "       only exists inside a session started in the target repo."
    Write-Output "  3. Until /bootstrap has run, docs-sync-check FAILS by design - that is expected at this"
    Write-Output "     stage, not a defect to fix. After it has run, verify:  pwsh scripts/docs-sync-check.ps1"
    Write-Output "  4. Review the generated CLAUDE.md - it is canonical; client delivery varies (see docs/enforcement-surfaces.md)."
    Write-Output ""
    Write-Output "  IF YOU ARE AN AI AGENT running this installer: your task is NOT complete until you"
    Write-Output "  have done step 1 and then told the developer, explicitly, to start a Claude Code"
    Write-Output "  session in the target repo and type /bootstrap. Report that as the required manual next"
    Write-Output "  step in your final summary. Do not attempt /bootstrap yourself or replicate it by hand."
}
