# Install the AI Tech Lead Framework into a target repository.
# Usage: pwsh -NoProfile -File scripts/install.ps1 [-AllowDirtyTree] [-WhatIf] [-AllowDowngrade] [-AllowOutdated] C:\path\to\target-repo
#
# Before it changes anything, it asks the remote of the framework clone it runs from whether that
# clone is out of date: a newer vX.Y.Z release tag than this copy's version, or an upstream branch this
# checkout is behind, stops the install (exit 4) unless -AllowOutdated is passed. A copy that cannot be
# checked (no Git, not a tracked clone, no answer within 10 seconds) installs with a NOTE saying so;
# ATL_SOURCE_CHECK=off skips the check and says that instead.
#
# Copies the template's framework files into the target, EXCLUDING the .git directory, the
# .template-repo marker (which would disable the consumer's CI guardrail), the template repo's own
# meta files (README.md, CHANGELOG.md, .gitignore, .gitattributes), and the installer itself.
#
# Three modes, detected automatically:
#   greenfield — target has no AI tooling and no shipped path holding other bytes: plain copy;
#                next step is /bootstrap.
#   brownfield — target already has AI tooling (CLAUDE.md, .cursorrules, Copilot instructions,
#                ADRs, ...) or a shipped path holding other bytes (tracked, untracked, ignored or
#                outside Git): the originals this copy would overwrite are moved to docs/pre-adoption/
#                first, and .claude/adoption-pending.json is written so every later session (and CI)
#                steers to /adopt. Next step is /adopt.
#   update     — target already carries .claude/framework-version.json. Consumer-owned protected
#                paths are restored; framework-owned machinery is overwritten; mixed-ownership
#                .claude/settings.json is backed up, refreshed, and adapted to the host. An older
#                instruction layout (project text in CLAUDE.md) is moved once into AGENTS.md.
param(
    [Parameter(Mandatory = $true)][string]$Target,
    [switch]$AllowDirtyTree,
    [switch]$WhatIf,
    [switch]$AllowDowngrade,
    [switch]$AllowOutdated
)
$ErrorActionPreference = 'Stop'
$followUpPowerShell = if ($PSVersionTable.PSVersion.Major -ge 7) {
    'pwsh -NoProfile -File'
} else {
    'powershell.exe -NoProfile -ExecutionPolicy Bypass -File'
}
$pwshAvailable = $PSVersionTable.PSVersion.Major -ge 7 -or
    $null -ne (Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)

if (-not (Test-Path -LiteralPath $Target -PathType Container)) { Write-Error "Target '$Target' is not a directory."; exit 2 }

# -LiteralPath: read as a wildcard, 'repo[a]' resolves a sibling 'repoa' and the install lands there.
$src = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$tgt = (Resolve-Path -LiteralPath $Target).Path
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

# Windows PowerShell 5.1 returns nothing, instead of throwing ItemNotFound, for a missing path under a
# directory whose name holds brackets; each absence check below then read the gap as an entry and
# reported a phantom path. Throw the same error on both hosts; any other failure still escapes.
function Get-LiteralItem {
    param([Parameter(Mandatory = $true)][string]$Path)
    $item = Get-Item -Force -LiteralPath $Path -ErrorAction Stop
    if ($null -eq $item) { throw [Management.Automation.ItemNotFoundException]::new("Cannot find path '$Path' because it does not exist.") }
    return $item
}

# SHA-256 of the raw bytes with every CR LF pair turned into LF. Git for Windows checks text out with
# CRLF (core.autocrlf=true) while the retirement ledger records released LF blobs, so a retired file
# differing only in line endings holds no consumer content. Mixed endings pass for the same reason; a
# BOM, an edited line or a lone CR does not. Latin-1 maps every byte to one char and back unchanged.
function Get-LfSha256 {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Bytes)
    $latin1 = [Text.Encoding]::GetEncoding(28591)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($latin1.GetBytes($latin1.GetString($Bytes).Replace("`r`n", "`n"))))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
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
    # Previous ownership is untrusted deletion authority. Keep duplicate rejection
    # case-insensitive, but key lookups ordinal: `Scripts/X` must never authorize deleting
    # canonical `scripts/x` on Windows' case-insensitive filesystem.
    $byPath = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
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
    $byPath = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
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

# One git command in the framework clone, bounded by the check's shared deadline so that no remote can
# hold the install: stdin is closed, Git's own prompts are off (terminal, Git Credential Manager, askpass),
# and at the deadline the process tree is killed, prompt or not. $null means git could not be run.
function Invoke-SourceGit {
    param([Parameter(Mandatory = $true)][string]$GitPath, [Parameter(Mandatory = $true)][string]$Directory,
        [Parameter(Mandatory = $true)][datetime]$Deadline, [Parameter(Mandatory = $true)][string[]]$Arguments)
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $GitPath
        # Windows command-line quoting: a quote is escaped, and backslashes before a quote or at the end (a
        # drive-root clone, as a subst drive gives) are doubled, so no argument can split or run into another.
        $psi.Arguments = ((@('-C', $Directory) + $Arguments | ForEach-Object { '"' + (($_ -replace '(\\*)"', '$1$1\"') -replace '(\\+)$', '$1$1') + '"' }) -join ' ')
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
        $psi.EnvironmentVariables['GIT_TERMINAL_PROMPT'] = '0'
        $psi.EnvironmentVariables['GCM_INTERACTIVE'] = 'never'
        # Empty, not absent: git then also skips core.askPass and SSH_ASKPASS.
        $psi.EnvironmentVariables['GIT_ASKPASS'] = ''
        $psi.EnvironmentVariables['SSH_ASKPASS_REQUIRE'] = 'never'
        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.StandardInput.Close()
        $stdout = $proc.StandardOutput.ReadToEndAsync()
        $stderr = $proc.StandardError.ReadToEndAsync()
    } catch { return $null }
    # The stream reads share the deadline: a child git leaves behind can hold the pipes after git exits.
    try {
        $done = $proc.WaitForExit([int][Math]::Max(0, ($Deadline - [DateTime]::UtcNow).TotalMilliseconds)) -and
            [System.Threading.Tasks.Task]::WaitAll([System.Threading.Tasks.Task[]]@($stdout, $stderr),
                [int][Math]::Max(0, ($Deadline - [DateTime]::UtcNow).TotalMilliseconds))
    } catch { $done = $false }
    if (-not $done) {
        $ErrorActionPreference = 'Continue'
        try { & taskkill.exe /T /F /PID $proc.Id *> $null } catch { }
        try { if (-not $proc.HasExited) { $proc.Kill() } } catch { }
        return [pscustomobject]@{ TimedOut = $true; ExitCode = $null; Output = '' }
    }
    return [pscustomobject]@{ TimedOut = $false; ExitCode = $proc.ExitCode; Output = $stdout.Result.Trim() }
}

# Is the framework clone this copy sits in out of date? A clone left behind installs an old release,
# and nothing later says so. The remote is read with one ls-remote, no object is looked up that the
# clone may lack (in a partial clone that fetches it), and the whole check has 10 seconds.
# State is current, outdated, unchecked or skipped; only current is reported as checked.
function Get-SourceFreshness {
    $unchecked = { param([string]$Why) [pscustomobject]@{ State = 'unchecked'; Detail = $Why; Update = $null } }
    if ($env:ATL_SOURCE_CHECK -eq 'off') { return [pscustomobject]@{ State = 'skipped'; Detail = 'not checked (ATL_SOURCE_CHECK=off)'; Update = $null } }
    foreach ($name in @('GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR', 'GIT_INDEX_FILE')) {
        if (-not [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($name, 'Process'))) { return & $unchecked "Git routing variable $name is set" }
    }
    $git = @(Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($git.Count -eq 0) { return & $unchecked 'Git was not found' }
    $gitPath = [string]$git[0].Source
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    # Only a clone of the framework itself, which tracks this copy at dist/<stack>/ beside the root
    # dispatcher and the installer's source: a copy inside another repository would otherwise be judged
    # by that repository's tags and branches, and told to update that repository.
    $tracked = Invoke-SourceGit -GitPath $gitPath -Directory $src -Deadline $deadline -Arguments @('ls-files', '--full-name', '--error-unmatch', '--',
        'scripts/install.ps1', '../../install.ps1', '../../src/core/scripts/install.ps1')
    $top = Invoke-SourceGit -GitPath $gitPath -Directory $src -Deadline $deadline -Arguments @('rev-parse', '--show-toplevel')
    if (-not $tracked -or $tracked.ExitCode -ne 0 -or @($tracked.Output -split "`n")[0] -notmatch '^dist/[^/]+/scripts/install\.ps1$' -or
        -not $top -or $top.ExitCode -ne 0 -or -not $top.Output) {
        return & $unchecked "this copy is not tracked at dist/$(Split-Path -Leaf $src)/ of a Git clone of the framework"
    }
    # The clone as Git resolved it: a copy reached through a link or junction belongs to the clone it points into.
    $clone = [IO.Path]::GetFullPath($top.Output)
    $remote = 'origin'; $branch = $null
    $head = Invoke-SourceGit -GitPath $gitPath -Directory $clone -Deadline $deadline -Arguments @('symbolic-ref', '--quiet', 'HEAD')
    if ($head -and $head.ExitCode -eq 0 -and $head.Output -cmatch '^refs/heads/(.+)$') {
        $local = $Matches[1]
        $upstreamRemote = Invoke-SourceGit -GitPath $gitPath -Directory $clone -Deadline $deadline -Arguments @('config', '--get', "branch.$local.remote")
        $upstreamBranch = Invoke-SourceGit -GitPath $gitPath -Directory $clone -Deadline $deadline -Arguments @('config', '--get', "branch.$local.merge")
        # A remote name only: a URL configured here could carry a credential into the messages below.
        if ($upstreamRemote -and $upstreamRemote.ExitCode -eq 0 -and $upstreamRemote.Output -match '^[\w.-]+$' -and $upstreamRemote.Output -ne '.' -and
            $upstreamBranch -and $upstreamBranch.ExitCode -eq 0 -and $upstreamBranch.Output) {
            $remote = $upstreamRemote.Output; $branch = $upstreamBranch.Output
        }
    }
    $query = @('ls-remote', '--refs', $remote, 'refs/tags/v*')
    if ($branch) { $query += $branch }
    $listing = Invoke-SourceGit -GitPath $gitPath -Directory $clone -Deadline $deadline -Arguments $query
    if (-not $listing) { return & $unchecked 'Git could not be run' }
    if ($listing.TimedOut) { return & $unchecked "git ls-remote $remote did not finish within 10 seconds" }
    if ($listing.ExitCode -ne 0) { return & $unchecked "git ls-remote $remote failed (exit $($listing.ExitCode))" }
    $tips = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
    foreach ($line in ($listing.Output -split "`n")) {
        $fields = $line.Trim() -split "`t"
        if ($fields.Count -eq 2) { $tips[$fields[1]] = $fields[0] }
    }
    $newest = $null
    foreach ($ref in $tips.Keys) {
        if ($ref -cmatch '^refs/tags/v([0-9]+\.[0-9]+\.[0-9]+)$') {
            $release = $Matches[1]
            if (-not $newest -or (Compare-ReleaseVersion -Left $release -Right $newest) -gt 0) { $newest = $release }
        }
    }
    $stale = New-Object System.Collections.Generic.List[string]
    $fresh = New-Object System.Collections.Generic.List[string]
    $unknown = $null
    $update = "git -C `"$clone`" fetch --tags $remote, then git -C `"$clone`" checkout v$newest"
    if ($newest -and (Compare-ReleaseVersion -Left $newest -Right $incomingVersion) -gt 0) { $stale.Add("$remote has release v$newest and this copy is v$incomingVersion") }
    elseif ($newest) { $fresh.Add("no release newer than v$incomingVersion") }
    if ($branch -and $tips.ContainsKey($branch)) {
        $tracking = "$remote/$($branch -replace '^refs/heads/', '')"
        # The tip is looked up only when it is HEAD or the tip this clone last fetched: any other tip is new
        # to the clone, and looking it up would make a partial clone fetch it.
        $headTip = Invoke-SourceGit -GitPath $gitPath -Directory $clone -Deadline $deadline -Arguments @('rev-parse', '--verify', '--quiet', 'HEAD')
        $fetched = Invoke-SourceGit -GitPath $gitPath -Directory $clone -Deadline $deadline -Arguments @('rev-parse', '--verify', '--quiet', '@{upstream}')
        if (-not $headTip -or $headTip.TimedOut -or -not $fetched -or $fetched.TimedOut) { $unknown = "could not tell whether this checkout is behind $tracking" }
        elseif ($headTip.ExitCode -eq 0 -and $headTip.Output -eq $tips[$branch]) { $fresh.Add("not behind $tracking") }
        elseif ($fetched.ExitCode -ne 0 -or $fetched.Output -ne $tips[$branch]) {
            $stale.Add("$tracking has commits this checkout has not fetched"); $update = "git -C `"$clone`" pull"
        } else {
            $count = Invoke-SourceGit -GitPath $gitPath -Directory $clone -Deadline $deadline -Arguments @('rev-list', '--count', "HEAD..$($tips[$branch])")
            if (-not $count -or $count.ExitCode -ne 0 -or $count.Output -notmatch '^[0-9]+$') { $unknown = "could not tell whether this checkout is behind $tracking" }
            elseif ([int]$count.Output -eq 0) { $fresh.Add("not behind $tracking") }
            else { $stale.Add("this checkout is $($count.Output) commit$(if ([int]$count.Output -ne 1) { 's' }) behind $tracking"); $update = "git -C `"$clone`" pull" }
        }
    }
    if ($stale.Count -gt 0) { return [pscustomobject]@{ State = 'outdated'; Detail = ($stale -join '; '); Update = $update } }
    if ($unknown) { return & $unchecked $unknown }
    if ($fresh.Count -eq 0) { return & $unchecked "$remote has no vX.Y.Z release tag, and this checkout tracks none of its branches" }
    return [pscustomobject]@{ State = 'current'; Detail = "checked against ${remote}: $($fresh -join ', ')"; Update = $null }
}
# Template-repo meta files that must never land in (or overwrite their namesakes in) a consumer repo.
$metaFiles = @('.git', '.template-repo', 'README.md', 'CHANGELOG.md', '.gitignore', '.gitattributes')
# Composition reads this declarative set from the installer. It is intentionally explicit so
# install.ps1 remains the single ownership-policy authority while a test can pin the complete set.
$excludedFromInstall = @('.git', '.template-repo', 'README.md', 'CHANGELOG.md', '.gitignore', '.gitattributes',
    'scripts/install.ps1', '.github/workflows/template-ci.yml')

# Consumer files the copy below would otherwise clobber. Update skips them directly; brownfield
# archives them unless the copy-if-absent policy below keeps the live path for in-place screening.
$protected = @('CLAUDE.md', 'AGENTS.md', 'TECH_DEBT.md', 'SECURITY_FINDINGS.md', 'LEARNINGS.md',
    'FRAMEWORK-CONTEXT.md', '.github/copilot-instructions.md', 'docs/ARCHITECTURE.md',
    'docs/architecture-decisions.md', 'docs/wiki/INDEX.md')
# Persistent state is copied only when absent. The composer reads this policy from both installer
# PowerShell installer authority and emits it as consumer-owned/protected in framework-ownership.json.
$persistentCopyIfAbsent = @(
    '.claude/ai-audit.log'
)
# These are never bulk-replaced, so brownfield must not archive them merely because the incoming
# ownership manifest lists them. The audit entry remains the separately composer-verified
# persistent policy above.
$copyIfAbsent = $persistentCopyIfAbsent + @(
    'docs/wiki/INDEX.md', 'docs/ARCHITECTURE.md', 'docs/architecture-decisions.md'
)

# Signals that the target already has AI tooling and therefore needs /adopt, not /bootstrap. A shipped
# path that collides with an existing file selects brownfield as well.
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
# Before the downgrade check: an outdated clone is the likelier cause of a downgrade, and updating it
# answers both.
$sourceFreshness = Get-SourceFreshness
if ($sourceFreshness.State -eq 'outdated' -and -not $AllowOutdated) {
    [Console]::Error.WriteLine("ERROR: Refusing to install from an out-of-date framework copy: $($sourceFreshness.Detail). Update it ($($sourceFreshness.Update)), then re-run; pass -AllowOutdated only to install this older copy on purpose.")
    exit 4
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

# A shipped path already holding other bytes is consumer content the copy would overwrite, whether
# or not it looks like AI tooling and whether or not Git can see it (untracked, ignored, no
# repository), so it selects the brownfield archive. Identical bytes lose nothing and keep an
# interrupted greenfield re-run greenfield; compare them raw, never line-ending-normalized.
if (-not $updateMode) {
    foreach ($relative in $incomingPaths) {
        if ($relative -in $copyIfAbsent) { continue }
        $existing = Get-ContainedTargetPath -Relative $relative
        if (-not (Test-Path -LiteralPath $existing -PathType Leaf)) { continue }
        # Never read through a link; the brownfield preflight refuses it by name. A linked wrapper path
        # is no collision: the install keeps the link and leaves that wrapper out.
        if (Get-ReparsePointAncestor -Path $existing) {
            if ($relative -notmatch '^\.agents/skills/[a-z0-9-]+/SKILL\.md$') { $detected += $relative }
            continue
        }
        try {
            $same = [Convert]::ToBase64String([IO.File]::ReadAllBytes($existing)) -ceq
                [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $src $relative)))
        } catch {
            [Console]::Error.WriteLine("CANT-VERIFY: existing '$relative' could not be read to decide whether this install would overwrite it. Make it readable or move it aside, then re-run.")
            exit 4
        }
        if (-not $same) { $detected += $relative }
    }
}
# CLAUDE.md is both a signal and a collision: name each path once. Both lists hold fixed canonical
# names, so the case-sensitive Select-Object -Unique is enough.
$detected = @($detected | Select-Object -Unique)
$adoptMode = (-not $updateMode) -and ($detected.Count -gt 0)

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
                # Test-Path reports a dangling reparse point as absent. Resolve the directory
                # entry itself so only a true ItemNotFound result can mean that this retirement
                # candidate is absent; every other inspection failure is preservation evidence.
                try { $candidateEntry = Get-LiteralItem -Path $candidate }
                catch [Management.Automation.ItemNotFoundException] { continue }
                catch {
                    $reconciliationMessages.Add("CANT-VERIFY: retired path '$retiredPath' could not be examined; preserving it.")
                    $retirementPreserve.Add($retiredPath)
                    continue
                }
                $reparse = Get-ReparsePointAncestor -Path $candidate
                if ($reparse) {
                    $reconciliationMessages.Add("CANT-VERIFY: retired path '$retiredPath' traverses reparse/symlink '$reparse'; preserving it.")
                    $retirementPreserve.Add($retiredPath)
                    continue
                }
                if ($candidateEntry.PSIsContainer) {
                    $reconciliationMessages.Add("CANT-VERIFY: retired path '$retiredPath' is not a regular file; preserving it.")
                    $retirementPreserve.Add($retiredPath)
                    continue
                }
                try {
                    $digest = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLowerInvariant()
                    if ($digest -notin @($retirementLedger[$retiredPath].Hashes) -and $candidateEntry.Length -le 2097152) {
                        $digest = Get-LfSha256 -Bytes ([IO.File]::ReadAllBytes($candidate))
                    }
                }
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

# Git prints a path's bytes as UTF-8, but PowerShell decodes a captured native command with the console's code page, so
# at chcp 850 'zugänge.env' reads 'zug├ñnge.env', and Git quotes non-ASCII unless core.quotePath is false. Every path a
# leftover decision is built from is therefore read here: -z records, raw bytes decoded as UTF-8,
# stderr kept apart. Stdin is never redirected: Windows PowerShell's .NET writes the console's UTF-8 preamble into it.
# $null: Git did not start or exited outside SuccessCodes.
function ConvertTo-NativeArgument {
    param([string]$Value)
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
    return '"' + [regex]::Replace($Value, '(\\*)("|$)', [Text.RegularExpressions.MatchEvaluator]{ param($m) $m.Groups[1].Value * 2 + $(if ($m.Groups[2].Value) { '\"' } else { '' }) }) + '"'
}
function Invoke-GitRecords {
    param([Parameter(Mandatory = $true)][string]$GitPath, [Parameter(Mandatory = $true)][string[]]$Arguments, [int[]]$SuccessCodes = @(0))
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $GitPath
    $start.Arguments = @($Arguments | ForEach-Object { ConvertTo-NativeArgument -Value $_ }) -join ' '
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    try {
        $process = [Diagnostics.Process]::Start($start)
        $stderr = $process.StandardError.ReadToEndAsync()
        $bytes = New-Object IO.MemoryStream
        $process.StandardOutput.BaseStream.CopyTo($bytes)
        $process.WaitForExit()
        [void]$stderr.Result
        if ($SuccessCodes -notcontains $process.ExitCode) { return $null }
    } catch { return $null }
    return , @([Text.UTF8Encoding]::new($false).GetString($bytes.ToArray()).Split([char]0) | Where-Object { $_.Length -gt 0 })
}

# Every copy an update saves goes below .claude/framework-update-backup/, kept out of Git by a '*' line
# that ENDS that folder's .gitignore: the last matching line wins, so no team line before it can re-include a copy, and
# Git reads no .gitignore or .gitattributes below an excluded folder. Copies an earlier update left there where Git
# could commit them are untracked status records below the target's folder; Git prints status paths from the
# repository root, so a target in a subfolder strips its prefix first. The lists earlier updates wrote are not copies.
$script:BackupLists = @('.claude/framework-update-backup/.gitignore', '.claude/framework-update-backup/files/.gitignore', '.claude/framework-update-backup/agents-skills/.gitignore')
function Get-TargetStatus {
    param([Parameter(Mandatory = $true)][string]$GitPath)
    $prefix = Invoke-GitRecords -GitPath $GitPath -Arguments @('-C', $tgt, 'rev-parse', '--show-prefix')
    $records = Invoke-GitRecords -GitPath $GitPath -Arguments @('--no-optional-locks', '-C', $tgt, 'status', '--porcelain=v1', '-z', '--untracked-files=all')
    if ($null -eq $prefix -or $null -eq $records) { return $null }
    return [pscustomobject]@{ Records = @($records); Prefix = (@($prefix) -join '').TrimEnd([char]13, [char]10) }
}
function ConvertFrom-BackupRecord {
    param([string]$Record, [string]$Prefix)
    if (-not $Record.StartsWith('?? ', [StringComparison]::Ordinal)) { return $null }
    $path = $Record.Substring(3)
    if (-not $path.StartsWith($Prefix, [StringComparison]::OrdinalIgnoreCase)) { return $null }
    $path = $path.Substring($Prefix.Length)
    # Ignoring case: on Windows Git (core.ignorecase) a folder renamed in case is the same folder.
    if (-not $path.StartsWith('.claude/framework-update-backup/', [StringComparison]::OrdinalIgnoreCase)) { return $null }
    return $path
}
function Get-BackupResidue {
    param([Parameter(Mandatory = $true)]$Status)
    return , @($Status.Records | ForEach-Object { ConvertFrom-BackupRecord -Record $_ -Prefix $Status.Prefix } | Where-Object { $null -ne $_ -and $_ -notin $script:BackupLists })
}
# Git matches a plain pathspec by exact case, so a backup folder Git tracks as .claude/Framework-Update-Backup/ would
# slip past one; ':(icase)' matches it whatever its case.
$script:BackupPathspec = ':(icase).claude/framework-update-backup'
# The paths Git tracks below the backup folder, target-relative. '*' hides only what Git does not track, so no copy is
# ever written onto one of them: git add -A would take its new bytes. Compared ignoring case, since Windows writes either
# spelling to one file. Read once, as -z records decoded as UTF-8; empty without Git.
$script:BackupTrackedSet = $null
function Get-BackupTracked {
    if ($null -eq $script:BackupTrackedSet) {
        $script:BackupTrackedSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        $git = @(Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)
        $routed = @(@('GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR', 'GIT_INDEX_FILE') | Where-Object { [Environment]::GetEnvironmentVariable($_, 'Process') }).Count -gt 0
        if ($git.Count -gt 0 -and -not $routed) {
            $records = Invoke-GitRecords -GitPath ([string]$git[0].Source) -Arguments @('-C', $tgt, 'ls-files', '-z', '--', $script:BackupPathspec)
            if ($null -ne $records) { foreach ($record in $records) { [void]$script:BackupTrackedSet.Add($record) } }
        }
    }
    return , $script:BackupTrackedSet
}
# The list as Git must read it. 'kept': it already ends with '*'. 'write': Bytes is it with '*' appended, one saved as
# UTF-16 rewritten as UTF-8, which Git reads. 'blocked': a link, or not a readable file, is never read or written
# through (Git ignores a .gitignore that is a symbolic link, and a hard link's other names would change too).
# 'unwritable': it needs the '*' but cannot be opened for writing (read-only, say), found before any change.
function Get-BackupKeepOut {
    $path = Get-ContainedTargetPath -Relative '.claude/framework-update-backup/.gitignore'
    $item = Get-Item -Force -LiteralPath $path -ErrorAction SilentlyContinue
    $reason = $null
    if (Get-ReparsePointAncestor -Path $path) { $reason = 'is a symbolic link or junction, or lies below one' }
    elseif ($item -and $item.PSIsContainer) { $reason = 'is not a regular file' }
    elseif ($item -and [string]$item.LinkType -eq 'HardLink') { $reason = 'is a hard link' }
    $body = [byte[]]@()
    if (-not $reason -and $item) { try { $body = [IO.File]::ReadAllBytes($path) } catch { $reason = 'could not be read' } }
    if ($reason) { return [pscustomobject]@{ State = 'blocked'; Reason = $reason; Bytes = $null } }
    $wide = $body.Length -ge 2 -and (($body[0] -eq 0xFF -and $body[1] -eq 0xFE) -or ($body[0] -eq 0xFE -and $body[1] -eq 0xFF))
    $text = if ($wide) { [IO.File]::ReadAllText($path) } else { [Text.UTF8Encoding]::new($false).GetString($body).TrimStart([char]0xFEFF) }
    if ($wide) { $body = [Text.UTF8Encoding]::new($false).GetBytes($text) }
    $lines = @($text -split "`n" | ForEach-Object { $_.TrimEnd([char]13) } | Where-Object { $_.Trim().Length -gt 0 })
    if (-not $wide -and $lines.Count -gt 0 -and $lines[-1] -ceq '*') { return [pscustomobject]@{ State = 'kept'; Reason = $null; Bytes = $null } }
    if ($item) {
        # Opened for writing as Write-BackupKeepOut opens it, never written: FileMode.Open neither truncates nor changes the file.
        try { $probe = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::Read); $probe.Dispose() }
        catch {
            $marks = @(@('ReadOnly', 'Hidden', 'System') | Where-Object { ($item.Attributes -band [IO.FileAttributes]::$_) -ne 0 })
            $message = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $_.Exception.Message }
            $reason = if ($marks.Count -gt 0) { "it is marked $($marks -join ' and '): $message" } else { $message }
            return [pscustomobject]@{ State = 'unwritable'; Reason = $reason; Bytes = $null }
        }
    }
    $star = [Text.Encoding]::ASCII.GetBytes($(if ($body.Length -gt 0 -and $body[-1] -ne 0x0A) { "`n*`n" } else { "*`n" }))
    $bytes = New-Object byte[] ($body.Length + $star.Length)
    [Array]::Copy($body, 0, $bytes, 0, $body.Length)
    [Array]::Copy($star, 0, $bytes, $body.Length, $star.Length)
    return [pscustomobject]@{ State = 'write'; Reason = $null; Bytes = $bytes }
}
# Writes the list in place, opened as the planning probe opened it and truncated, so one checked out Hidden
# (core.hideDotFiles) is written and keeps its attributes: File.WriteAllBytes opens with FileMode.Create, which Windows
# refuses for an existing Hidden file.
function Write-BackupKeepOut {
    param([Parameter(Mandatory = $true)][byte[]]$Bytes)
    $path = Get-ContainedTargetPath -Relative '.claude/framework-update-backup/.gitignore'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
    $stream = [IO.File]::Open($path, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::Write, [IO.FileShare]::Read)
    try { $stream.SetLength(0); $stream.Write($Bytes, 0, $Bytes.Length) } finally { $stream.Dispose() }
}
# How many files below the backup folder Git could still commit: each untracked one Git does not ignore, and each path
# this run wrote ($Written, target-relative) that Git shows at all, modified, added or otherwise. A rename or copy
# record is followed by its source path, which is skipped. $null: Git could not say.
function Get-BackupVisibleCount {
    param([Parameter(Mandatory = $true)][string]$GitPath, [string]$Prefix = '', $Written = $null)
    $records = Invoke-GitRecords -GitPath $GitPath -Arguments @('--no-optional-locks', '-C', $tgt, 'status', '--porcelain=v1', '-z', '--untracked-files=all', '--', $script:BackupPathspec)
    if ($null -eq $records) { return $null }
    $records = @($records)
    $count = 0
    for ($i = 0; $i -lt $records.Count; $i++) {
        $record = [string]$records[$i]
        if ($record.Length -lt 4) { continue }
        $code = $record.Substring(0, 2)
        $path = $record.Substring(3)
        if ($code.IndexOfAny([char[]]'RC') -ge 0) { $i++ }
        if ($path.StartsWith($Prefix, [StringComparison]::OrdinalIgnoreCase)) { $path = $path.Substring($Prefix.Length) }
        if ($code -ceq '??' -or ($null -ne $Written -and $Written.Contains($path))) { $count++ }
    }
    return $count
}
# The dirty-tree refusal says "Commit", which would take an earlier update's leftovers too, so before it they are kept
# out of Git: the list's '*' is that refusal's one write, to the framework's own file. Returns the line it adds.
function Protect-BackupResidue {
    param([Parameter(Mandatory = $true)][string]$GitPath, [Parameter(Mandatory = $true)][int]$Count)
    $list = '.claude/framework-update-backup/.gitignore'
    $files = if ($Count -eq 1) { '1 file' } else { "$Count files" }
    $keepOut = Get-BackupKeepOut
    $why = $null; $wrote = $false; $visible = $Count
    if ($keepOut.State -eq 'blocked') { $why = "$list $($keepOut.Reason), which this update never writes through" }
    elseif ($keepOut.State -eq 'unwritable') { $why = "this update could not write $list ($($keepOut.Reason))" }
    elseif ($keepOut.State -eq 'write') {
        try { Write-BackupKeepOut -Bytes $keepOut.Bytes; $wrote = $true }
        catch { $why = "this update could not write $list ($($_.Exception.Message))" }
    }
    if (-not $why) { $visible = Get-BackupVisibleCount -GitPath $GitPath }
    if ($null -ne $visible -and $visible -eq 0) {
        $change = if ($wrote) { "Before refusing, this update made its one change: '*' is now the last line of $list, so Git ignores" } else { 'Git ignores' }
        # A list Git tracks now shows as changed, and the next run would refuse over it without this line.
        $listed = if ($wrote -and (Get-BackupTracked).Contains($list)) { " Git tracks $list, so that change shows in git status: commit it with your own changes; it only adds a line that keeps files out of Git." } else { '' }
        return "  $change the $files an earlier update left under that folder, which may hold copies of files you had gitignored; committing your own changes cannot take them.$listed Keep what you need from them under other paths, then delete the folder."
    }
    $done = if ($wrote) { "this update wrote '*' as the last line of $list, its one change, yet " } else { '' }
    $seen = "Git can still commit $(if ($visible -eq 1) { '1 file' } else { "$visible files" }) under .claude/framework-update-backup/"
    if ($null -eq $visible) { $seen = "Git could not say whether it ignores the $files an earlier update left under .claude/framework-update-backup/" }
    $because = if ($why) { " ($why)" } else { '' }
    return "  CANT-VERIFY: $done$seen$because, which may hold copies of files you had gitignored. Do not commit that folder: commit or stash only your own changes.$(if (-not $wrote) { ' Nothing was changed.' })"
}

function Stop-UnverifiableGitPreflight {
    [Console]::Error.WriteLine('CANT-VERIFY: Git state for this update/brownfield target could not be verified safely. Unset Git routing variables, install or repair Git, or repair/remove corrupt repository metadata, then re-run the installer.')
    exit 4
}

# The opt-in pre-commit convenience net was never installer-owned: it lives under .git, outside the
# ownership manifest. A v0.83+ update therefore diagnoses it but never writes or deletes it. When a
# safely contained default hook still calls a retired helper, keep that helper's complete executable
# closure even if ordinary retirement rules would otherwise authorize deletion. Ambiguous routing is non-authority:
# preserve every possible retired helper rather than following a custom or external hook path.
$legacyGitHookRetiredDependencies = @(
    'scripts/setup-git-hooks.ps1',
    'scripts/setup-git-hooks.sh',
    '.claude/hooks/guard.sh'
)

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Bytes)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

# Bind the complete pre-move inventory independently of mutable per-move progress.  This is kept
# byte-for-byte compatible with adoption-archive.ps1 so workflow Freeze can extend the installer
# inventory before any workflow move without accepting a regenerated, reduced marker.
function ConvertTo-AdoptionIdentitySegment {
    param([AllowNull()][string]$Value)
    return [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$Value))
}

function New-AdoptionInventoryIdentity {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Entries)
    $lines = New-Object 'System.Collections.Generic.List[string]'
    foreach ($entry in @($Entries)) {
        $line = @(
            ([int]$entry.schemaVersion).ToString([Globalization.CultureInfo]::InvariantCulture)
            (ConvertTo-AdoptionIdentitySegment -Value ([string]$entry.originalPath))
            (ConvertTo-AdoptionIdentitySegment -Value ([string]$entry.destination))
            ([string]$entry.sha256).ToLowerInvariant()
            ([int64]$entry.byteLength).ToString([Globalization.CultureInfo]::InvariantCulture)
            (ConvertTo-AdoptionIdentitySegment -Value ([string]$entry.owner))
            (ConvertTo-AdoptionIdentitySegment -Value ([string]$entry.provenanceRevision))
            (ConvertTo-AdoptionIdentitySegment -Value ([string]$entry.provenance))
            (ConvertTo-AdoptionIdentitySegment -Value ([string]$entry.historyDepth))
            (ConvertTo-AdoptionIdentitySegment -Value ([string]$entry.localModification))
        ) -join '|'
        $lines.Add($line)
    }
    $lines.Sort([StringComparer]::Ordinal)
    $payload = "ai-tech-lead/archive-integrity/v1`n" + ($lines -join "`n")
    return [pscustomobject][ordered]@{
        schemaVersion = 1
        algorithm     = 'SHA-256'
        entryCount    = [int]$lines.Count
        sha256        = Get-Sha256Hex -Bytes ([Text.Encoding]::UTF8.GetBytes($payload))
    }
}

# Brownfield archives must retain their exact pre-move bytes and an examinable original-path
# provenance record. Raw SHA-256 over the actual filesystem bytes is the preservation oracle; the
# recorded Git revision/path is historical attribution only and never substitutes for it. Unknown
# history is a named state ('unavailable'/'untracked'), not a fabricated author or a trust finding.
function Resolve-AdoptionGit {
    foreach ($name in @('GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR', 'GIT_INDEX_FILE')) {
        if (-not [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($name, 'Process'))) { return $null }
    }
    $command = @(Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($command.Count -eq 0) { return $null }
    return [string]$command[0].Source
}

function Get-AdoptionArchiveBaselineRevision {
    $gitPath = Resolve-AdoptionGit
    if (-not $gitPath) { return $null }
    $head = Invoke-GitText -GitPath $gitPath -Arguments @('-C', $tgt, 'rev-parse', 'HEAD')
    if ($head.Started -and $head.ExitCode -eq 0 -and $head.Output -match '^[0-9a-f]{40}$') { return $head.Output }
    return $null
}

# The spelling the disk holds for a path found ignoring case: in each folder, its one entry of that
# name, or the exact name where a case-sensitive folder (WSL, fsutil setCaseSensitiveInfo) holds
# several. $null when a folder cannot be listed.
function Get-DiskSpelling {
    param([Parameter(Mandatory = $true)][string]$Relative)
    $directory = $tgt
    $segments = New-Object System.Collections.Generic.List[string]
    foreach ($segment in $Relative.Split('/')) {
        try { $names = @([IO.Directory]::GetFileSystemEntries($directory) | ForEach-Object { [IO.Path]::GetFileName($_) }) }
        catch { return $null }
        $sameName = @($names | Where-Object { $_.Equals($segment, [StringComparison]::OrdinalIgnoreCase) })
        if ($sameName.Count -eq 1) { $name = $sameName[0] }
        elseif ($sameName -ccontains $segment) { $name = $segment }
        else { return $null }
        $segments.Add($name)
        $directory = [IO.Path]::Combine($directory, $name)
    }
    return ($segments -join '/')
}

function New-AdoptionArchiveEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$OriginalRelative,
        [Parameter(Mandatory = $true)][string]$DestinationRelative
    )
    $sourceFull = Get-ContainedTargetPath -Relative $OriginalRelative
    $bytes = [IO.File]::ReadAllBytes($sourceFull)
    $revision = $null; $provenance = 'unavailable'; $historyDepth = 'unavailable'; $localModification = 'unknown'
    $gitPath = Resolve-AdoptionGit
    if ($gitPath) {
        $inside = Invoke-GitText -GitPath $gitPath -Arguments @('-C', $tgt, 'rev-parse', '--is-inside-work-tree')
        if ($inside.Started -and $inside.ExitCode -eq 0 -and $inside.Output -ceq 'true') {
            $shallow = Invoke-GitText -GitPath $gitPath -Arguments @('-C', $tgt, 'rev-parse', '--is-shallow-repository')
            if ($shallow.Started -and $shallow.ExitCode -eq 0) { $historyDepth = if ($shallow.Output -ceq 'true') { 'shallow' } else { 'full' } }
            # The disk matched the shipped name ignoring case; Git's pathspecs do not. A file Git tracks
            # under the spelling the disk holds is recorded under that spelling, so its history reads.
            # An untracked one keeps the shipped spelling that docs/pre-adoption/.gitignore and /adopt's
            # personal-file check use.
            $diskSpelling = Get-DiskSpelling -Relative $OriginalRelative
            if ($diskSpelling -and $diskSpelling -cne $OriginalRelative) {
                $listed = Invoke-GitText -GitPath $gitPath -Arguments @('-C', $tgt, 'ls-files', '--', ":(literal)$diskSpelling")
                if ($listed.Started -and $listed.ExitCode -eq 0 -and @($listed.Output -split "`n") -ccontains $diskSpelling) { $OriginalRelative = $diskSpelling }
            }
            $tracked = Invoke-GitText -GitPath $gitPath -Arguments @('-C', $tgt, 'ls-files', '--error-unmatch', '--', $OriginalRelative)
            if ($tracked.Started -and $tracked.ExitCode -eq 0) {
                $provenance = 'tracked'
                $log = Invoke-GitText -GitPath $gitPath -Arguments @('-C', $tgt, 'log', '-1', '--format=%H', '--', $OriginalRelative)
                if ($log.Started -and $log.ExitCode -eq 0 -and $log.Output -match '^[0-9a-f]{40}$') { $revision = $log.Output }
                $st = Invoke-GitText -GitPath $gitPath -Arguments @('-C', $tgt, 'status', '--porcelain', '--', $OriginalRelative)
                if ($st.Started -and $st.ExitCode -eq 0) { $localModification = if ($st.RecordCount -gt 0) { 'modified' } else { 'clean' } }
            } elseif ($tracked.Started -and $tracked.ExitCode -eq 1) {
                # Only Git's explicit "not in the index" result is untracked. A failed query is
                # unavailable examination, never a fabricated provenance finding.
                $provenance = 'untracked'
            }
        }
    }
    return [ordered]@{
        schemaVersion      = 1
        originalPath        = $OriginalRelative
        destination         = $DestinationRelative
        sha256              = Get-Sha256Hex -Bytes $bytes
        byteLength          = [int64]$bytes.LongLength
        owner               = 'installer'
        provenanceRevision  = $revision
        provenance          = $provenance
        historyDepth        = $historyDepth
        localModification   = $localModification
        verified            = $false
    }
}

function New-LegacyGitHookInspection {
    param([string]$Kind, [string]$Detail, [string[]]$Dependencies = @())
    return [pscustomobject]@{ Kind = $Kind; Detail = $Detail; Dependencies = @($Dependencies) }
}

function Get-LegacyGitHookInspection {
    foreach ($name in @('GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR', 'GIT_INDEX_FILE')) {
        $value = [Environment]::GetEnvironmentVariable($name, 'Process')
        if ($null -ne $value -and $value.Length -gt 0) {
            return New-LegacyGitHookInspection -Kind 'CANT-VERIFY' -Dependencies $legacyGitHookRetiredDependencies `
                -Detail "Git routing variable $name is set; the installer did not inspect or modify routed hook state."
        }
    }

    try { $gitEntryPath = Get-GitChildEntry -Directory $tgt -Name '.git' }
    catch {
        return New-LegacyGitHookInspection -Kind 'CANT-VERIFY' -Dependencies $legacyGitHookRetiredDependencies `
            -Detail 'the target .git entry could not be examined; no hook path was followed or modified.'
    }
    if (-not $gitEntryPath) {
        try { $repositoryOutsideTarget = Test-GitRepositoryEvidence -Path $tgt }
        catch {
            return New-LegacyGitHookInspection -Kind 'CANT-VERIFY' -Dependencies $legacyGitHookRetiredDependencies `
                -Detail 'repository evidence could not be examined; no hook path was followed or modified.'
        }
        if ($repositoryOutsideTarget) {
            return New-LegacyGitHookInspection -Kind 'CANT-VERIFY' -Dependencies $legacyGitHookRetiredDependencies `
                -Detail 'Git metadata is not a default .git directory contained by the selected target; linked, nested, bare, or external hook state was not inspected or modified.'
        }
        return New-LegacyGitHookInspection -Kind 'NONE' -Detail 'the target has no contained default Git hook.'
    }

    try { $gitEntry = Get-Item -Force -LiteralPath $gitEntryPath -ErrorAction Stop }
    catch {
        return New-LegacyGitHookInspection -Kind 'CANT-VERIFY' -Dependencies $legacyGitHookRetiredDependencies `
            -Detail 'the target .git entry could not be examined; no hook path was followed or modified.'
    }
    if ((Get-ReparsePointAncestor -Path $gitEntryPath) -or -not $gitEntry.PSIsContainer) {
        return New-LegacyGitHookInspection -Kind 'CANT-VERIFY' -Dependencies $legacyGitHookRetiredDependencies `
            -Detail 'Git metadata is linked, external, or non-directory state; no hook path was followed or modified.'
    }

    try { $huskyEntry = Get-GitChildEntry -Directory $tgt -Name '.husky' }
    catch {
        return New-LegacyGitHookInspection -Kind 'CANT-VERIFY' -Dependencies $legacyGitHookRetiredDependencies `
            -Detail 'the .husky routing surface could not be examined; no hook path was followed or modified.'
    }
    if ($huskyEntry) {
        return New-LegacyGitHookInspection -Kind 'CANT-VERIFY' -Dependencies $legacyGitHookRetiredDependencies `
            -Detail 'a .husky hook surface exists; it remains consumer-owned and was not inspected or modified.'
    }

    $gitCommands = @(Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($gitCommands.Count -eq 0) {
        return New-LegacyGitHookInspection -Kind 'CANT-VERIFY' -Dependencies $legacyGitHookRetiredDependencies `
            -Detail 'Git is unavailable, so core.hooksPath cannot be checked; no hook path was followed or modified.'
    }
    $hooksPath = Invoke-GitText -GitPath ([string]$gitCommands[0].Source) -Arguments @('-C', $tgt, 'config', '--get', 'core.hooksPath')
    if (-not $hooksPath.Started -or $hooksPath.ExitCode -notin @(0, 1)) {
        return New-LegacyGitHookInspection -Kind 'CANT-VERIFY' -Dependencies $legacyGitHookRetiredDependencies `
            -Detail 'core.hooksPath could not be examined; no custom hook path was followed or modified.'
    }
    if ($hooksPath.ExitCode -eq 0) {
        return New-LegacyGitHookInspection -Kind 'CANT-VERIFY' -Dependencies $legacyGitHookRetiredDependencies `
            -Detail "core.hooksPath is configured as '$($hooksPath.Output)'; it remains consumer-owned and was not inspected or modified."
    }

    $hookRelative = '.git/hooks/pre-commit'
    $hookPath = Get-ContainedTargetPath -Relative $hookRelative
    $hookReparse = Get-ReparsePointAncestor -Path $hookPath
    if ($hookReparse) {
        return New-LegacyGitHookInspection -Kind 'CANT-VERIFY' -Dependencies $legacyGitHookRetiredDependencies `
            -Detail "the default pre-commit path traverses reparse/symlink '$hookReparse'; it was not followed or modified."
    }
    try { $hookEntry = Get-LiteralItem -Path $hookPath }
    catch [Management.Automation.ItemNotFoundException] {
        return New-LegacyGitHookInspection -Kind 'NONE' -Detail 'the target has no default pre-commit hook.'
    }
    catch {
        return New-LegacyGitHookInspection -Kind 'CANT-VERIFY' -Dependencies $legacyGitHookRetiredDependencies `
            -Detail 'the default pre-commit hook could not be examined; it was not modified.'
    }
    if ($hookEntry.PSIsContainer -or $hookEntry.Length -gt 1048576) {
        return New-LegacyGitHookInspection -Kind 'CANT-VERIFY' -Dependencies $legacyGitHookRetiredDependencies `
            -Detail 'the default pre-commit hook is not a regular bounded text file; it was not modified.'
    }

    try {
        $hookBytes = [IO.File]::ReadAllBytes($hookPath)
        $hookText = [Text.UTF8Encoding]::new($false, $true).GetString($hookBytes)
        $hookDigest = Get-Sha256Hex -Bytes $hookBytes
    } catch {
        return New-LegacyGitHookInspection -Kind 'CANT-VERIFY' -Dependencies $legacyGitHookRetiredDependencies `
            -Detail 'the default pre-commit hook could not be read as UTF-8 text; it was not modified.'
    }

    $powerShellBody = $hookDigest -ceq 'd13676bfffea2c3199894f4a610b8931273e161ddbfcfcdc7628bf40e6ca9fb8'
    $bashBody = $hookDigest -ceq '25da45aa780126e4d2b0a2b1bdf759462bf3fd92be01e6414ed496253c817357'
    $powerShellReference = $hookText -match '(?i)(?:^|[\s"''\\/])(?:\./)?scripts[\\/]setup-git-hooks\.ps1(?=$|[\s"''`(){}\[\],;:])'
    $bashSetupReference = $hookText -match '(?i)(?:^|[\s"''\\/])(?:\./)?scripts[\\/]setup-git-hooks\.sh(?=$|[\s"''`(){}\[\],;:])'
    $bashGuardReference = $hookText -match '(?i)(?:^|[\s"''\\/])(?:\./)?\.claude[\\/]hooks[\\/]guard\.sh(?=$|[\s"''`(){}\[\],;:])'
    $dependencies = New-Object System.Collections.Generic.List[string]
    if ($powerShellBody -or $powerShellReference) { $dependencies.Add('scripts/setup-git-hooks.ps1') }
    if ($bashBody -or $bashSetupReference -or $bashGuardReference) {
        $dependencies.Add('scripts/setup-git-hooks.sh')
        $dependencies.Add('.claude/hooks/guard.sh')
    }
    if ($dependencies.Count -gt 0) {
        $flavour = if ($bashBody -or $bashSetupReference -or $bashGuardReference) { 'Bash/degraded and unmaintained' } else { 'PowerShell' }
        return New-LegacyGitHookInspection -Kind 'LEGACY' -Dependencies @($dependencies | Sort-Object -Unique) `
            -Detail "$flavour legacy pre-commit references retired framework helpers."
    }
    return New-LegacyGitHookInspection -Kind 'CUSTOM' -Detail 'an unrelated custom default pre-commit hook exists; it remains consumer-owned and was not modified.'
}

function Add-LegacyDependencyPreserve {
    param([Parameter(Mandatory = $true)][string]$Relative)
    if (-not $retirementLedger.ContainsKey($Relative)) { return }
    $wasPlannedForDeletion = $deletePlan.Remove($Relative)
    $candidate = Get-ContainedTargetPath -Relative $Relative
    $entryExists = $false
    try { $entryExists = $null -ne (Get-Item -Force -LiteralPath $candidate -ErrorAction Stop) }
    catch [Management.Automation.ItemNotFoundException] { $entryExists = $false }
    catch { $entryExists = $true }
    if (($wasPlannedForDeletion -or $entryExists) -and -not $retirementPreserve.Contains($Relative)) {
        $retirementPreserve.Add($Relative)
    }
}

$legacyGitHookInspection = if ($updateMode) { Get-LegacyGitHookInspection } else { New-LegacyGitHookInspection -Kind 'NONE' -Detail 'legacy hook inspection applies only to updates.' }
if ($legacyGitHookInspection.Kind -eq 'LEGACY') {
    foreach ($relative in $legacyGitHookInspection.Dependencies) { Add-LegacyDependencyPreserve -Relative $relative }
    $reconciliationMessages.Add("MIGRATION: $($legacyGitHookInspection.Detail) The consumer-owned .git/hooks/pre-commit was not changed; preserving present dependency files from $($legacyGitHookInspection.Dependencies -join ', '). Remove or replace the hook manually before deleting those helpers.")
} elseif ($legacyGitHookInspection.Kind -eq 'CANT-VERIFY') {
    foreach ($relative in $legacyGitHookInspection.Dependencies) { Add-LegacyDependencyPreserve -Relative $relative }
    $reconciliationMessages.Add("CANT-VERIFY: Legacy Git-hook retirement could not be classified safely because $($legacyGitHookInspection.Detail) Potential retired helper dependencies were preserved.")
} elseif ($legacyGitHookInspection.Kind -eq 'CUSTOM') {
    $reconciliationMessages.Add("NOTICE: $($legacyGitHookInspection.Detail)")
}

# .agents/skills is shared with other agents, so a team's own skill can sit at a workflow wrapper's
# path. A link or a file where the wrapper needs a folder is the team's in every mode: kept, since the
# installer never writes through a link. Otherwise a fresh install archives a colliding file, and an
# update decides by content and history: a file without the sentence naming its command as the single
# source of truth is the team's, kept on every update; one with it repeats the framework's prompt or
# wrapper and is replaced, but saved first when the previous manifest did not own the path. A kept
# path stays out of the manifest this run writes, so an owned path is one the framework wrote.
$teamSkillPaths = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
# Every file this update saves before replacing it: wrappers below, other files the framework did not write further down.
$updateBackups = New-Object System.Collections.Generic.List[object]
$priorManifest = if (Test-Path -LiteralPath 'variable:previous') { $previous } else { $null }
$runName = if ($updateMode) { 'update' } else { 'install' }
# A link at the backup path, symbolic or hard, may be the file itself, so it never counts as a save.
function Test-HeldBytes {
    param([string]$Relative, [byte[]]$Bytes)
    $held = $null
    $heldItem = Get-Item -Force -LiteralPath (Get-ContainedTargetPath -Relative $Relative) -ErrorAction SilentlyContinue
    if ($null -eq $heldItem -or ($heldItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -or [string]$heldItem.LinkType -eq 'HardLink') { return $false }
    try { $held = [IO.File]::ReadAllBytes($heldItem.FullName) } catch { return $false }
    return [string]::Equals([Convert]::ToBase64String($held), [Convert]::ToBase64String($Bytes), [StringComparison]::Ordinal)
}
# A saved copy must never load as a live skill, command, agent, instruction, ignore or attribute file, nor be a live
# repository: agents read a .claude, .agents or .github folder nested anywhere, and Git a nested .gitignore,
# .gitattributes or .git. So below a save root a name starting with '.' gains a leading '_', and so does one already
# starting with '_', which keeps two paths from ever saving to one name.
function ConvertTo-SavedRelative {
    param([string]$Relative)
    return (@($Relative.Split('/') | ForEach-Object { if ($_ -match '^[._]') { "_$_" } else { $_ } }) -join '/')
}
# The name beside $Relative for content $Bytes: its SHA-256 (16 hex digits) before the extension.
function ConvertTo-DigestRelative {
    param([string]$Relative, [byte[]]$Bytes)
    $folder = $Relative.Substring(0, $Relative.LastIndexOf('/') + 1)
    $leaf = $Relative.Substring($folder.Length)
    $digest = (Get-Sha256Hex -Bytes $Bytes).Substring(0, 16)
    $dot = $leaf.LastIndexOf('.')
    return $folder + $(if ($dot -gt 0) { $leaf.Substring(0, $dot) + ".$digest" + $leaf.Substring($dot) } else { "$leaf.$digest" })
}
# Where an update saves a file before replacing it. An earlier run's copy (a re-run after a failed save) counts as
# saved. A different file at $Preferred, or a path Git tracks there, is never written: this copy goes beside it, named
# by its own SHA-256, and State 'taken' means that name holds other content or is tracked too. A link on the save path
# is refused, never read through.
function Find-UpdateBackup {
    param([string]$Preferred, [byte[]]$Bytes)
    if (Get-ReparsePointAncestor -Path (Get-ContainedTargetPath -Relative $Preferred)) { [void](Assert-SafeTargetMutation -Relative $Preferred) }
    $tracked = Get-BackupTracked
    $relative = $Preferred
    if (-not (Test-HeldBytes -Relative $relative -Bytes $Bytes) -and
        ($tracked.Contains($relative) -or $null -ne (Get-Item -Force -LiteralPath (Get-ContainedTargetPath -Relative $relative) -ErrorAction SilentlyContinue))) {
        $relative = ConvertTo-DigestRelative -Relative $relative -Bytes $Bytes
    }
    $state = 'taken'
    if (Test-HeldBytes -Relative $relative -Bytes $Bytes) { $state = 'saved' }
    elseif (-not $tracked.Contains($relative) -and $null -eq (Get-Item -Force -LiteralPath (Get-ContainedTargetPath -Relative $relative) -ErrorAction SilentlyContinue)) { $state = 'free' }
    return [pscustomobject]@{ Relative = $relative; State = $state }
}
# A copy the skill backup or the layout move saves never goes onto a path Git tracks: it goes beside it under its
# SHA-256 name, untracked and so kept out by '*'. Refuses before any change when that name is tracked too.
function Get-UntrackedSaveRelative {
    param([string]$Relative, [string]$Source)
    $tracked = Get-BackupTracked
    if (-not $tracked.Contains($Relative)) { return $Relative }
    $beside = $null
    try { $beside = ConvertTo-DigestRelative -Relative $Relative -Bytes ([IO.File]::ReadAllBytes($Source)) } catch { $beside = $null }
    if ($null -eq $beside -or $tracked.Contains($beside)) {
        [Console]::Error.WriteLine("ERROR: Refusing update: Git tracks $Relative, where this update must save a copy of a file of yours, and its name beside it is tracked too or the file could not be read; '*' hides only what Git does not track. Untrack the folder (git rm -r --cached .claude/framework-update-backup, then commit), then re-run the update. Nothing was changed.")
        exit 3
    }
    return $beside
}
foreach ($relative in $incomingPaths) {
    $agentsSkill = [regex]::Match($relative, '^\.agents/skills/([a-z0-9-]+)/SKILL\.md$')
    if (-not $agentsSkill.Success) { continue }
    $workflow = $agentsSkill.Groups[1].Value
    $blocker = $null
    $blockerIsLink = $false
    foreach ($onPath in '.agents', '.agents/skills', ".agents/skills/$workflow", $relative) {
        $item = Get-Item -Force -LiteralPath (Get-ContainedTargetPath -Relative $onPath) -ErrorAction SilentlyContinue
        if ($null -eq $item) { break }
        $blockerIsLink = ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
        if ($blockerIsLink -or ($onPath -cne $relative -and -not $item.PSIsContainer)) { $blocker = $onPath; break }
    }
    if ($blocker) {
        [void]$teamSkillPaths.Add($relative)
        if ($blockerIsLink) {
            $reconciliationMessages.Add("CANT-VERIFY: '$blocker' is a link, which the $runName never writes through, so it kept the link and did not install $relative. To get the framework's /$workflow in VS Code, copy that wrapper from the framework to where the link leads, or replace the link with a folder, then re-run the $runName.")
        } else {
            $reconciliationMessages.Add("CANT-VERIFY: '$blocker' is a file where the framework's /$workflow wrapper needs a folder, so the $runName kept it and did not install $relative. To get the framework's /$workflow in VS Code, move that file elsewhere, then re-run the $runName.")
        }
        continue
    }
    if (-not $updateMode) { continue }
    $destination = Get-ContainedTargetPath -Relative $relative
    if ($null -eq (Get-Item -Force -LiteralPath $destination -ErrorAction SilentlyContinue)) { continue }
    $existingBytes = $null
    $existingText = $null
    try {
        $existingBytes = [IO.File]::ReadAllBytes($destination)
        $existingText = [Text.UTF8Encoding]::new($false, $true).GetString($existingBytes)
    } catch { $existingText = $null }
    if ($null -eq $existingText -or -not $existingText.Contains('`.claude/commands/' + $workflow + '.md` is the single source of truth')) {
        [void]$teamSkillPaths.Add($relative)
        $reconciliationMessages.Add("CANT-VERIFY: '$relative' is not the framework's /$workflow wrapper, so the update kept it and did not install the wrapper there. To get the framework's /$workflow in VS Code, move your skill to another folder, then re-run the update.")
        continue
    }
    $incomingText = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes((Join-Path $src $relative)))
    if ([string]::Equals($existingText.Replace("`r`n", "`n"), $incomingText.Replace("`r`n", "`n"), [StringComparison]::Ordinal)) { continue }
    if ($null -ne $priorManifest -and $priorManifest.ByPath.ContainsKey($relative)) { continue }
    $backup = Find-UpdateBackup -Preferred ".claude/framework-update-backup/agents-skills/$workflow/SKILL.md" -Bytes $existingBytes
    if ($backup.State -eq 'saved') {
        $reconciliationMessages.Add("NOTICE: '$relative' is already saved at $($backup.Relative), so the update installs the framework's /$workflow wrapper there. Keep any change you need in AGENTS.md or a project skill.")
        continue
    }
    if ($backup.State -eq 'taken') {
        [Console]::Error.WriteLine("ERROR: Refusing update: '$relative' must be saved before the framework's /$workflow wrapper replaces it, and both $(".claude/framework-update-backup/agents-skills/$workflow/SKILL.md") and $($backup.Relative) already hold other content. Move them out of .claude/framework-update-backup/agents-skills/$workflow/, then re-run the update. Nothing was changed.")
        exit 3
    }
    $updateBackups.Add([pscustomobject]@{ Source = $destination; Relative = $backup.Relative; SourceRelative = $relative })
    $unowned = if ($null -eq $priorManifest) { 'there is no usable previous framework-ownership.json' } else { 'the previous framework-ownership.json does not list it' }
    $reconciliationMessages.Add("NOTICE: '$relative' holds the framework's /$workflow text, but $unowned, so the update saves it to $($backup.Relative), then installs the wrapper. Keep any change you need in AGENTS.md or a project skill.")
}

# A retirement can delete only where the immediately previous manifest grants authority. That
# limitation must not hide high-risk residuals on later updates after the new manifest no longer
# owns them. Inspect exact ledger paths read-only; this diagnostic grants no deletion authority.
if ($updateMode) {
    foreach ($retiredPath in @($retirementLedger.Keys | Sort-Object)) {
        $isGitHubSkill = $retiredPath -match '^\.github/skills/([^/]+)/'
        $slug = if ($isGitHubSkill) { $Matches[1] } else { $null }
        $isRetiredClaudeSkill = $retiredPath -match '^\.claude/skills/([^/]+)/SKILL\.md$'
        $claudeSkillSlug = if ($isRetiredClaudeSkill) { $Matches[1] } else { $null }
        $isRetiredSyncScript = $retiredPath -in @('scripts/sync-agent-files.ps1', 'scripts/sync-agent-files.sh')
        $isRetiredGitHookHelper = $retiredPath -in $legacyGitHookRetiredDependencies
        $isRetiredPrompt = $retiredPath -match '^\.github/prompts/([a-z0-9-]+)\.prompt\.md$'
        $promptWorkflow = if ($isRetiredPrompt) { $Matches[1] } else { $null }
        # Renamed, not dropped: Copilot CLI and Claude Code each ship a built-in /security-review.
        $isRenamedSecurityReview = $retiredPath -cin @('.claude/commands/security-review.md', '.agents/skills/security-review/SKILL.md')
        # Its prompt file, retired in 0.94.0, now names the renamed wrapper in the two prompt arms below.
        if ($promptWorkflow -ceq 'security-review') { $promptWorkflow = 'security-gate' }
        # Every retained retired path is reported. This was an allow-list of five categories, so a
        # path retired in any later release was preserved in silence -- and each new retirement had
        # to remember to add itself, which is the same shape of defect the list was added to fix.
        # Specific advice below still wins where it exists; the generic arm covers the rest.
        if ($deletePlan.Contains($retiredPath)) {
            # A retired skill's folder can hold consumer files and protected AGENTS.md can still name it;
            # neither is the installer's to change, so say what remains. A plain /rebootstrap stops when only
            # framework-owned paths changed, so name the forced run.
            if ($isRetiredClaudeSkill) {
                $reconciliationMessages.Add("NOTICE: framework skill '$claudeSkillSlug' was retired in $($retirementLedger[$retiredPath].Version); this update removes its unmodified SKILL.md. Other files in .claude/skills/$claudeSkillSlug/ are yours: they stay, or move to .claude/disabled-skills/$claudeSkillSlug/ when LEARNINGS.md disables that skill, and /rebootstrap full reads a references/project-pattern.md that stays there as a lead for a project skill. Remove the '$claudeSkillSlug' line from AGENTS.md > Common Tasks, or run /rebootstrap full to reconcile it.")
            }
            if ($isRenamedSecurityReview) {
                $reconciliationMessages.Add("NOTICE: this update removes the unmodified '$retiredPath': this framework's /security-review is now /security-gate (.claude/commands/security-gate.md). Type /security-gate; in Copilot CLI and Claude Code, /security-review now runs the host's own built-in security review.")
            }
            continue
        }
        $candidate = Get-ContainedTargetPath -Relative $retiredPath
        try { $entry = Get-LiteralItem -Path $candidate }
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
        } elseif ($isRetiredClaudeSkill) {
            # The ledger is shared by every stack, so a file here may be a team's own skill at a generic name.
            # A /bootstrap draft says so in its frontmatter; anything else may be the former framework recipe.
            $isDiscoveredSkill = $false
            if (-not $entry.PSIsContainer) {
                try { $isDiscoveredSkill = [Text.UTF8Encoding]::new($false, $true).GetString([IO.File]::ReadAllBytes($candidate)) -match '(?m)^origin:\s*discovered\s*$' }
                catch { $isDiscoveredSkill = $false }
            }
            if (-not $isDiscoveredSkill) {
                $reconciliationMessages.Add("CANT-VERIFY: '$retiredPath' sits at the slug of a framework skill retired in $($retirementLedger[$retiredPath].Version) and loads as a skill, unless LEARNINGS.md disables '$claudeSkillSlug', in which case this update moves .claude/skills/$claudeSkillSlug/ to .claude/disabled-skills/$claudeSkillSlug/. If it is that former framework recipe, remove it after review together with the '$claudeSkillSlug' line in AGENTS.md > Common Tasks; a skill your team wrote can stay, with its line. Other files in that folder are yours.")
            }
        } elseif ($isRetiredSyncScript) {
            $reconciliationMessages.Add("CANT-VERIFY: retained retired path '$retiredPath' was not deleted; running it may recreate higher-priority .github/skills shadows. Do not run it; migrate or retire it after review.")
        } elseif ($isRetiredGitHookHelper) {
            $reconciliationMessages.Add("CANT-VERIFY: retained retired Git-hook helper '$retiredPath' remains. Remove it only after confirming no consumer-owned hook depends on it; run $followUpPowerShell scripts/framework-doctor.ps1 for the current classification.")
        } elseif ($retiredPath -eq 'scripts/ci/bitbucket-pipelines.example.yml') {
            $reconciliationMessages.Add("CANT-VERIFY: retained retired sample '$retiredPath' remains. It targets an unsupported Linux container; remove it after review and use a Windows/PowerShell CI example instead.")
        } elseif ($retiredPath -in @('scripts/build-architecture-html.ps1', 'scripts/build-architecture-html.sh')) {
            $reconciliationMessages.Add("CANT-VERIFY: retained retired generator '$retiredPath' remains. The generated architecture view is retired and has no replacement command; its output loaded third-party script from the network each time it was opened. Read docs/ARCHITECTURE.md directly, then remove this generator and any page it produced after review.")
        } elseif ($retiredPath.StartsWith('docs/presentation/', [StringComparison]::Ordinal)) {
            $reconciliationMessages.Add("CANT-VERIFY: retained retired presentation file '$retiredPath' remains. The deck is no longer installed; the current copy is in '$(Join-Path $src 'presentation')'. Delete '$retiredPath' after review.")
        } elseif ($isRetiredPrompt -and $teamSkillPaths.Contains(".agents/skills/$promptWorkflow/SKILL.md")) {
            $reconciliationMessages.Add("CANT-VERIFY: retained retired prompt file '$retiredPath' remains, and the update kept your own skill, file or link at .agents/skills/$promptWorkflow or above it, so the framework's wrapper for /$promptWorkflow is not installed there; VS Code's Copilot harness does not load prompt files. Keep any change you need in AGENTS.md or a project skill, then delete the prompt file after review.")
        } elseif ($isRetiredPrompt -and $incoming.ByPath.ContainsKey(".agents/skills/$promptWorkflow/SKILL.md")) {
            # These prompts were replaced, not dropped: the generic arm below would say there is no replacement.
            $reconciliationMessages.Add("CANT-VERIFY: retained retired prompt file '$retiredPath' remains. Its workflow now ships as the skill .agents/skills/$promptWorkflow/SKILL.md, which runs .claude/commands/$promptWorkflow.md, and VS Code's Copilot harness does not load prompt files. Keep any change you need in AGENTS.md or a project skill, because an update replaces framework files, then delete the prompt file after review; a prompt your team wrote itself, rather than edited, can stay.")
        } elseif ($retiredPath -eq 'NOTICE-ai-tech-lead.md') {
            # Not a command: a notice the team edited or wrote is theirs, so the generic remove-it advice does not fit.
            $reconciliationMessages.Add("NOTICE: '$retiredPath' remains because it differs from every notice this framework shipped. The framework no longer ships a notice; the file is yours to keep or delete.")
        } elseif ($isRenamedSecurityReview) {
            $reconciliationMessages.Add("CANT-VERIFY: retained retired path '$retiredPath' remains. This framework's /security-review is now /security-gate (.claude/commands/security-gate.md); the old command file and its Copilot wrapper are both retired, and an update removes each unmodified copy, so a kept wrapper can point at a command file that is gone. On Copilot CLI a skill kept under the old name also shares that name with the CLI's built-in security agent, which the agent may run instead. If this is the framework's former file with your edits, keep any change you need in AGENTS.md or a project skill, then delete it after review; a skill your team wrote itself can stay under another name.")
        } else {
            $twin = if ($retiredPath.EndsWith('.sh', [StringComparison]::OrdinalIgnoreCase)) {
                $retiredPath.Substring(0, $retiredPath.Length - 3) + '.ps1'
            } else { $null }
            # Naming a twin that is itself retired sends the consumer to another dead path.
            if ($twin -and -not $retirementLedger.ContainsKey($twin)) {
                $reconciliationMessages.Add("CANT-VERIFY: retained retired framework path '$retiredPath' remains. Do not execute it; migrate references to '$twin' and remove the retired file after review.")
            } else {
                $reconciliationMessages.Add("CANT-VERIFY: retained retired framework path '$retiredPath' remains. It is retired with no replacement command; remove the file and any reference to it after review.")
            }
        }
    }
}

# Protected carriers and consumer CI are not overwritten merely to repair stale commands. Report
# exact current-release retirements and a concrete replacement before the WhatIf boundary so dry-run
# and apply classify the same bytes. Enumeration is bounded and never follows reparse points.
$retiredReferenceReplacements = @{}
$retiredReferenceNotes = @{}
if ($updateMode -and (Compare-ReleaseVersion -Left $incomingVersion -Right '0.83.0') -ge 0) {
    $retiredReferenceReplacements['install.sh'] = "$followUpPowerShell install.ps1"
    $retiredReferenceReplacements['scripts/install.sh'] = "$followUpPowerShell scripts/install.ps1"
}
if ($updateMode) {
    # Renamed, not dropped. Not gated on the incoming version like the ledger loop below: once
    # this installer replaces the framework's files, the old name reaches only a host's built-in command.
    # The successor is bare: a replacement that still held the old name would be reported again once applied.
    $retiredReferenceReplacements['/security-review'] = '/security-gate'
    $retiredReferenceReplacements['.claude/commands/security-review.md'] = '.claude/commands/security-gate.md'
    $retiredReferenceNotes['/security-review'] = ' Leave a dated history entry, or a mention that deliberately names the host''s own built-in command of the old name, as it is.'
}
foreach ($retiredPath in $(if ($updateMode) { @($retirementLedger.Keys) } else { @() })) {
    # Keep diagnostics cumulative: a consumer may skip the release that first retired the path.
    if ((Compare-ReleaseVersion -Left $retirementLedger[$retiredPath].Version -Right $incomingVersion) -gt 0) { continue }
    if ($retiredPath -in @('scripts/setup-git-hooks.ps1', 'scripts/setup-git-hooks.sh')) {
        $retiredReferenceReplacements[$retiredPath] = "the setup feature is retired; inspect .git/hooks/pre-commit, remove or replace the old convenience hook manually, then run $followUpPowerShell scripts/framework-doctor.ps1"
    } elseif ($retiredPath -eq 'scripts/ci/bitbucket-pipelines.example.yml') {
        $retiredReferenceReplacements[$retiredPath] = "the Linux container sample is retired; use a Windows runner with $followUpPowerShell scripts/docs-sync-check.ps1"
    } elseif ($retiredPath -in @('scripts/build-architecture-html.ps1', 'scripts/build-architecture-html.sh')) {
        # Both twins retire with no successor command. The generic .sh arm below would name a .ps1
        # that is itself retired, and would stop emitting entirely once that .ps1 left the incoming
        # manifest -- silently dropping a migration message the consumer already relied on.
        $retiredReferenceReplacements[$retiredPath] = 'the generated architecture view is retired; read docs/ARCHITECTURE.md directly'
    } elseif ($retiredPath.EndsWith('.sh', [StringComparison]::OrdinalIgnoreCase)) {
        $powerShellPath = $retiredPath.Substring(0, $retiredPath.Length - 3) + '.ps1'
        if ($incoming.ByPath.ContainsKey($powerShellPath)) {
            $retiredReferenceReplacements[$retiredPath] = "$followUpPowerShell $powerShellPath"
        } else {
            # The twin is retired or gone, so there is no successor to name. Emitting nothing here
            # is how a stale reference survives with no diagnostic at all.
            $retiredReferenceReplacements[$retiredPath] = 'that feature is retired and has no replacement command; remove the reference'
        }
    }
}

$protectedReferenceCandidates = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($relative in $protected + @('.claude/settings.local.json', '.gitlab-ci.yml', '.gitlab-ci.yaml',
    'azure-pipelines.yml', 'azure-pipelines.yaml', 'bitbucket-pipelines.yml', 'bitbucket-pipelines.yaml',
    'Jenkinsfile')) { [void]$protectedReferenceCandidates.Add($relative) }

function Add-BoundedReferenceDirectory {
    param([string]$Relative, [int]$MaxDepth, [string[]]$Extensions)
    $directory = Get-ContainedTargetPath -Relative $Relative
    $rootReparse = Get-ReparsePointAncestor -Path $directory
    if ($rootReparse) {
        $reconciliationMessages.Add("CANT-VERIFY: protected reference directory '$Relative' traverses reparse/symlink '$rootReparse'; it was not followed.")
        return
    }
    try { $rootEntry = Get-LiteralItem -Path $directory }
    catch [Management.Automation.ItemNotFoundException] { return }
    catch { $reconciliationMessages.Add("CANT-VERIFY: protected reference directory '$Relative' could not be examined; no stale-command conclusion was inferred."); return }
    if (($rootEntry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or -not $rootEntry.PSIsContainer) {
        $reconciliationMessages.Add("CANT-VERIFY: protected reference directory '$Relative' is linked or not a directory; it was not traversed.")
        return
    }
    $queue = New-Object System.Collections.Generic.Queue[object]
    $queue.Enqueue([pscustomobject]@{ Directory = $rootEntry; Depth = 0 })
    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        try { $children = @(Get-ChildItem -Force -LiteralPath $current.Directory.FullName -ErrorAction Stop) }
        catch {
            $underTarget = $current.Directory.FullName.Substring($tgt.Length).TrimStart('\', '/') -replace '\\', '/'
            $reconciliationMessages.Add("CANT-VERIFY: protected reference directory '$underTarget' could not be enumerated; no stale-command conclusion was inferred.")
            continue
        }
        foreach ($child in $children) {
            $childRelative = $child.FullName.Substring($tgt.Length).TrimStart('\', '/') -replace '\\', '/'
            if (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                $reconciliationMessages.Add("CANT-VERIFY: protected reference candidate '$childRelative' is a reparse/symlink and was not followed.")
                continue
            }
            if ($child.PSIsContainer) {
                if ($current.Depth -lt $MaxDepth) { $queue.Enqueue([pscustomobject]@{ Directory = $child; Depth = $current.Depth + 1 }) }
            } elseif ($Extensions -contains $child.Extension) {
                [void]$protectedReferenceCandidates.Add($childRelative)
            }
        }
    }
}

Add-BoundedReferenceDirectory -Relative '.github/workflows' -MaxDepth 0 -Extensions @('.yml', '.yaml')
Add-BoundedReferenceDirectory -Relative 'bamboo-specs' -MaxDepth 3 -Extensions @('.yml', '.yaml', '.xml', '.java')

foreach ($relative in @($protectedReferenceCandidates | Sort-Object)) {
    if ($incoming.ByPath.ContainsKey($relative) -and $incoming.ByPath[$relative] -eq 'framework-owned/overwritten') { continue }
    $candidate = Get-ContainedTargetPath -Relative $relative
    $reparse = Get-ReparsePointAncestor -Path $candidate
    if ($reparse) {
        $reconciliationMessages.Add("CANT-VERIFY: protected reference candidate '$relative' traverses reparse/symlink '$reparse' and was not read.")
        continue
    }
    try { $entry = Get-LiteralItem -Path $candidate }
    catch [Management.Automation.ItemNotFoundException] { continue }
    catch { $reconciliationMessages.Add("CANT-VERIFY: protected reference candidate '$relative' could not be examined; no stale-command conclusion was inferred."); continue }
    if ($entry.PSIsContainer -or $entry.Length -gt 2097152) {
        $reconciliationMessages.Add("CANT-VERIFY: protected reference candidate '$relative' is not a regular bounded file and was not read.")
        continue
    }
    try { $content = [Text.UTF8Encoding]::new($false, $true).GetString([IO.File]::ReadAllBytes($candidate)) -replace '\\', '/' }
    catch { $reconciliationMessages.Add("CANT-VERIFY: protected reference candidate '$relative' could not be read as UTF-8; no stale-command conclusion was inferred."); continue }
    foreach ($retiredPath in @($retiredReferenceReplacements.Keys | Sort-Object)) {
        $pattern = '(?i)(?<![A-Za-z0-9_./-])(?:\./)?' + [regex]::Escape($retiredPath) + '(?=$|[\s"''`(){}\[\],;:])'
        if ($content -match $pattern) {
            $reconciliationMessages.Add("MIGRATION: protected consumer carrier '$relative' names retired framework path '$retiredPath'. It was not overwritten; replace that reference with: $($retiredReferenceReplacements[$retiredPath]).$($retiredReferenceNotes[$retiredPath])")
        }
    }
}

# Git is optional for a plain target, but repository evidence or redirected Git state must never be
# reinterpreted as non-Git. Refuse before mutation unless Git authoritatively identifies the target
# and its porcelain status can be read through the selected target path.
$script:TargetStatus = $null
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
            $status = Get-TargetStatus -GitPath $gitPath
            if ($null -eq $status) {
                [Console]::Error.WriteLine('CANT-VERIFY: Git identified this target as a worktree, but its status could not be read. Commit, stash, or copy local changes, then repair Git and re-run the installer.')
                exit 4
            }
            # An untracked file below the target's .claude/framework-update-backup/ is an earlier update's own copy, not the
            # team's change; refusing for it would steer the team to commit it. The same records are counted in the keep-out line.
            $script:TargetStatus = $status
            $dirt = @($status.Records | Where-Object { -not ($updateMode -and $null -ne (ConvertFrom-BackupRecord -Record $_ -Prefix $status.Prefix)) })
            if ($dirt.Count -gt 0) {
                if (-not $AllowDirtyTree) {
                    [Console]::Error.WriteLine('ERROR: Refusing to mutate a dirty Git target. Commit, stash, or copy local changes, then re-run; use -AllowDirtyTree only after doing so deliberately.')
                    $residue = if ($updateMode) { Get-BackupResidue -Status $status } else { @() }
                    if ($residue.Count -gt 0) { [Console]::Error.WriteLine((Protect-BackupResidue -GitPath $gitPath -Count $residue.Count)) }
                    exit 4
                }
                Write-Output '  override: -AllowDirtyTree accepted for this dirty Git target.'
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
elseif ($adoptMode) { Write-Output "  mode: brownfield (pre-existing AI tooling, or files this install would overwrite: $($detected -join ', '))" }
else                { Write-Output "  mode: greenfield" }
if ($updateMode -and $versionComparison -gt 0 -and $AllowDowngrade) {
    Write-Output "  override: -AllowDowngrade accepted for downgrade $installedVersion -> $incomingVersion."
}
if ($sourceFreshness.State -in @('current', 'skipped')) { Write-Output "  source: $($sourceFreshness.Detail)." }
elseif ($sourceFreshness.State -eq 'outdated') { Write-Output "  override: -AllowOutdated accepted: $($sourceFreshness.Detail)." }
else { Write-Output "  NOTE: could not check that this framework copy is up to date: $($sourceFreshness.Detail). Confirm it is the newest release before you rely on this install." }
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
        if ($f -in $copyIfAbsent -or $teamSkillPaths.Contains($f)) { continue }
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
        $archivePlan.Add([pscustomobject]@{ Original = $orig; OriginalRelative = $f; Relative = $rel; Destination = $dest })
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
            $oldText = [Text.UTF8Encoding]::new($false, $true).GetString([IO.File]::ReadAllBytes($skillFile))
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

# The one-time backup is a set of leaf copies, not an opaque recursive directory mutation. It is taken
# while its folder is absent, or again while the marker beside it exists: written before the folder is
# created and deleted after the last copy, so a held file or an interruption never leaves a partial
# backup that later runs mistake for the whole one.
$backupSkillsRoot = Join-Path $tgt '.claude/framework-update-backup/skills'
$backupIncompleteRelative = '.claude/framework-update-backup/skills-backup-incomplete'
# Each copy's path is mapped by ConvertTo-SavedRelative, so no copy loads as a live skill or is a live repository, and
# moved beside a path Git tracks (Get-UntrackedSaveRelative).
if ($updateMode -and (Test-Path -LiteralPath $activeSkillsRoot -PathType Container) -and
    (-not (Test-Path -LiteralPath $backupSkillsRoot) -or (Test-Path -LiteralPath (Join-Path $tgt $backupIncompleteRelative) -PathType Leaf))) {
    [void](Assert-SafeTargetMutation -Relative $backupIncompleteRelative)
    foreach ($file in Get-ChildItem -LiteralPath $activeSkillsRoot -Recurse -File -Force) {
        $underSkills = $file.FullName.Substring($activeSkillsRoot.Length).TrimStart('\', '/') -replace '\\', '/'
        # A retired skill file is known framework content that the retirement loop deletes first.
        if ($deletePlan -contains ".claude/skills/$underSkills") { continue }
        $relative = Get-UntrackedSaveRelative -Relative ('.claude/framework-update-backup/skills/' + (ConvertTo-SavedRelative -Relative $underSkills)) -Source $file.FullName
        [void](Add-PlannedWrite -Relative $relative -ForceCreate)
        $skillBackupPlan.Add([pscustomobject]@{ Source = $file.FullName; Relative = $relative; SourceRelative = ".claude/skills/$underSkills" })
    }
}

foreach ($entry in $updateBackups) { [void](Add-PlannedWrite -Relative $entry.Relative -ForceCreate) }

# Preserve every existing leaf of a disabled skill in its inactive location, then overlay the
# incoming framework version. Active copies are removed as explicit tree operations.
foreach ($name in $disabledSkillNames) {
    $activeRoot = Join-Path $activeSkillsRoot $name
    if (Test-Path -LiteralPath $activeRoot -PathType Container) {
        foreach ($file in Get-ChildItem -LiteralPath $activeRoot -Recurse -File -Force) {
            $underSkill = $file.FullName.Substring($activeRoot.Length).TrimStart('\', '/') -replace '\\', '/'
            # A retired skill file is known framework content that the retirement loop deletes first.
            if ($deletePlan -contains ".claude/skills/$name/$underSkill") { continue }
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
        ($updateMode -and $relative -in $protected) -or $preserveDiscovered -or
        $teamSkillPaths.Contains($relative))
    if ($preserve) { [void]$preservePlan.Add($relative); continue }
    if ($teamSkillPaths.Contains($relative)) { continue }
    [void](Add-PlannedWrite -Relative $relative -ForceCreate:$archiveSources.Contains($relative))
    $ordinaryApplyPaths.Add($relative)
}
foreach ($relative in $retirementPreserve) { [void]$preservePlan.Add($relative) }

# The same save, as for the wrappers above, for every other file this update replaces that the previous
# framework-ownership.json does not list: a team's own file at a path a release ships for the first time, as
# 0.95.0's .claude/commands/security-gate.md was, is otherwise lost. With no usable previous manifest no path can be
# called new, so every file that differs from this release is saved, summed up in one line instead of one each.
# Settings and the skills this run backs up already have their own save. Below files/ each path is mapped by
# ConvertTo-SavedRelative, so no saved copy is live.
$saveMessages = New-Object System.Collections.Generic.List[string]
$savesRelative = '.claude/framework-update-backup/files'
if ($updateMode) {
    $savedElsewhere = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    [void]$savedElsewhere.Add('.claude/settings.json')
    foreach ($entry in $skillBackupPlan) { [void]$savedElsewhere.Add($entry.SourceRelative) }
    $additiveSaves = 0; $additiveAlready = 0
    foreach ($relative in $ordinaryApplyPaths) {
        if ($savedElsewhere.Contains($relative) -or $relative -match '^\.agents/skills/[a-z0-9-]+/SKILL\.md$' -or
            ($null -ne $priorManifest -and $priorManifest.ByPath.ContainsKey($relative))) { continue }
        # Add-PlannedWrite above has already refused a link on this path and a folder at it.
        $destination = Get-ContainedTargetPath -Relative $relative
        if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) { continue }
        try { $existingBytes = [IO.File]::ReadAllBytes($destination) }
        catch {
            [Console]::Error.WriteLine("CANT-VERIFY: '$relative' could not be read to decide whether this update must save it before replacing it. Make it readable or move it aside, then re-run. Nothing was changed.")
            exit 4
        }
        if ((Get-LfSha256 -Bytes $existingBytes) -ceq (Get-LfSha256 -Bytes ([IO.File]::ReadAllBytes((Join-Path $src $relative))))) { continue }
        $preferred = "$savesRelative/" + (ConvertTo-SavedRelative -Relative $relative)
        $backup = Find-UpdateBackup -Preferred $preferred -Bytes $existingBytes
        if ($backup.State -eq 'taken') {
            [Console]::Error.WriteLine("ERROR: Refusing update: '$relative' must be saved before the framework's file replaces it, and both $preferred and $($backup.Relative) already hold other content. Move them out of $savesRelative/, then re-run the update. Nothing was changed.")
            exit 3
        }
        if ($null -eq $priorManifest) {
            if ($backup.State -eq 'saved') { $additiveAlready++ } else { $additiveSaves++ }
        } elseif ($backup.State -eq 'saved') {
            $saveMessages.Add("NOTICE: '$relative' is already saved at $($backup.Relative), so the update installs the framework's file there. Keep what you need from the saved copy under another path.")
        } else {
            $saveMessages.Add("NOTICE: '$relative' is not a file the framework wrote (the previous framework-ownership.json does not list it), so the update saves it to $($backup.Relative), then installs the framework's file there. Keep what you need from the saved copy under another path.")
        }
        if ($backup.State -eq 'saved') { continue }
        [void](Add-PlannedWrite -Relative $backup.Relative -ForceCreate)
        $updateBackups.Add([pscustomobject]@{ Source = $destination; Relative = $backup.Relative; SourceRelative = $relative })
    }
    $additiveTotal = $additiveSaves + $additiveAlready
    if ($additiveTotal -gt 0) {
        $differ = if ($additiveTotal -eq 1) { '1 file that differs' } else { "$additiveTotal files that differ" }
        $already = if ($additiveAlready -gt 0) { " $additiveAlready of them $(if ($additiveAlready -eq 1) { 'was' } else { 'were' }) already saved there by an earlier run." } else { '' }
        $saveMessages.Add("NOTICE: there is no usable previous framework-ownership.json, so the update cannot tell which files the framework wrote: it saves the $differ from this release under $savesRelative/, each at its own path (a name starting with '.' or '_' gains a leading '_', and a SHA-256 suffix where an older save holds that name), then replaces them.$already Keep what you need from the saved copies under other paths, then delete them.")
    }
}

# One-time instruction-layout move. The older layout kept the project instructions in
# CLAUDE.md and a generated mirror in AGENTS.md; now AGENTS.md holds them and CLAUDE.md is a stub
# importing it and the framework rules. Both stay protected, so only this block moves them, and
# only when nothing can be lost: CLAUDE.md does not import AGENTS.md yet, and AGENTS.md is absent
# or carries the retired GENERATED FILE banner (derived text). Both originals are backed up
# first. A hand-written AGENTS.md is left alone; session-start and template-checks then ask the
# consumer to merge by hand.
function ConvertTo-AgentsInstructionText {
    param([Parameter(Mandatory = $true)][string]$Text)
    # Split on LF only, so each line keeps its own CR and untouched lines round-trip byte-for-byte.
    $out = New-Object System.Collections.Generic.List[string]
    $dropBlank = $false
    $inFence = $false
    $inHeader = $true
    foreach ($line in $Text.Split([char]10)) {
        $core = $line.TrimEnd([char]13)
        $cr = $line.Substring($core.Length)
        if ($dropBlank) { $dropBlank = $false; if ($core.Trim() -eq '') { continue } }
        if ($core -match '^\s*(```|~~~)') { $inFence = -not $inFence; $out.Add($line); continue }
        if ($inFence) { $out.Add($line); continue }
        if ($core.StartsWith('## ')) { $inHeader = $false }
        if ($core.Trim() -cin @('@.github/instructions/framework-rules.instructions.md', '@./.github/instructions/framework-rules.instructions.md')) {
            # The import moves to the stub, together with the shipped comment that labelled it: one
            # or two lines directly above, opening with FRAMEWORK-OWNED. Nothing else is removed.
            $end = $out.Count - 1
            if ($end -ge 0 -and $out[$end].TrimEnd().EndsWith('-->')) {
                if ($out[$end].TrimStart().StartsWith('<!-- FRAMEWORK-OWNED')) { $out.RemoveAt($end) }
                elseif ($end -ge 1 -and $out[$end - 1].TrimStart().StartsWith('<!-- FRAMEWORK-OWNED') -and -not $out[$end - 1].Contains('-->')) { $out.RemoveRange($end - 1, 2) }
            }
            $dropBlank = $true
            continue
        }
        # Only the opening blockquote, above the first section, carries the template's description
        # of the old layout; a consumer's own quotes further down are left alone.
        if (-not ($inHeader -and $core.StartsWith('>'))) { $out.Add($line); continue }
        if ($core.Contains('never in AGENTS.md') -and $core.Contains('mirror')) {
            $out.Add('> **Framework rules** (Verification Rules, Leanness, SOLID, Agentic Workflow) are in [.github/instructions/framework-rules.instructions.md](./.github/instructions/framework-rules.instructions.md). If your agent has not already loaded that file, read it before planning or editing.' + $cr)
            continue
        }
        $out.Add($core.Replace(' and imports the framework rules below.', '. Edit it here; `CLAUDE.md` only imports it for Claude Code.').Replace('CLAUDE.md wins on any conflict', 'AGENTS.md wins on any conflict').Replace('CLAUDE.md is for repo-shared conventions only', 'AGENTS.md is for repo-shared conventions only') + $cr)
    }
    return ($out -join [string][char]10)
}

# Claude Code honours `@AGENTS.md` inline as well as on its own line. Any such mention counts as
# already migrated: declining the move can never lose text, and the checks still flag a banner.
$agentsImportPattern = '(?<![\w/.@-])@(\./)?AGENTS\.md(?![\w-])'

# The retired mirror always opened with this banner line; prose elsewhere that mentions generated
# files is a consumer's own text, not the mirror.
function Test-RetiredMirrorText {
    param([string]$Text)
    $first = @(($Text.TrimStart([char]0xFEFF)) -split '\r?\n' | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1)
    return ($first.Count -eq 1 -and $first[0].StartsWith('<!-- GENERATED FILE', [StringComparison]::Ordinal))
}

$layoutMove = $null
$layoutMessage = $null
if ($updateMode) {
    $claudeTarget = Get-ContainedTargetPath -Relative 'CLAUDE.md'
    $agentsTarget = Get-ContainedTargetPath -Relative 'AGENTS.md'
    $claudeEntry = Get-Item -Force -LiteralPath $claudeTarget -ErrorAction SilentlyContinue
    if ($claudeEntry -and -not $claudeEntry.PSIsContainer -and -not (Get-ReparsePointAncestor -Path $claudeTarget)) {
        try {
            $claudeBytes = [IO.File]::ReadAllBytes($claudeTarget)
            $claudeHasBom = $claudeBytes.Length -ge 3 -and $claudeBytes[0] -eq 0xEF -and $claudeBytes[1] -eq 0xBB -and $claudeBytes[2] -eq 0xBF
            $claudeText = [Text.UTF8Encoding]::new($false, $true).GetString($claudeBytes)
            if ($claudeHasBom) { $claudeText = $claudeText.Substring(1) }
        } catch { $claudeText = $null }
        if ($null -eq $claudeText) {
            $layoutMessage = 'LAYOUT: CLAUDE.md could not be read as UTF-8, so the instruction-layout move was not attempted. Move its content into AGENTS.md by hand (docs/upgrade-checklist.md).'
        } elseif ($claudeText -cnotmatch $agentsImportPattern) {
            $agentsEntry = Get-Item -Force -LiteralPath $agentsTarget -ErrorAction SilentlyContinue
            $agentsIsMirror = $false
            if ($agentsEntry -and -not $agentsEntry.PSIsContainer -and -not (Get-ReparsePointAncestor -Path $agentsTarget)) {
                try { $agentsIsMirror = Test-RetiredMirrorText -Text ([IO.File]::ReadAllText($agentsTarget)) } catch { $agentsIsMirror = $false }
            }
            if (-not $agentsEntry -or $agentsIsMirror) {
                $layoutMove = [pscustomobject]@{
                    AgentsText = ConvertTo-AgentsInstructionText -Text $claudeText
                    HasBom = $claudeHasBom
                    BackupAgents = [bool]$agentsEntry
                    ClaudeBackup = Get-UntrackedSaveRelative -Relative '.claude/framework-update-backup/instruction-files/CLAUDE.md' -Source $claudeTarget
                    AgentsBackup = $(if ($agentsEntry) { Get-UntrackedSaveRelative -Relative '.claude/framework-update-backup/instruction-files/AGENTS.md' -Source $agentsTarget } else { $null })
                }
                foreach ($relative in @($layoutMove.ClaudeBackup, 'CLAUDE.md', 'AGENTS.md')) { [void](Add-PlannedWrite -Relative $relative) }
                if ($layoutMove.BackupAgents) { [void](Add-PlannedWrite -Relative $layoutMove.AgentsBackup) }
                $layoutMessage = 'LAYOUT: moving the project instructions from CLAUDE.md into AGENTS.md (replacing the generated mirror) and writing the CLAUDE.md import stub; both originals, including any hand edits to the mirror, go to .claude/framework-update-backup/instruction-files/. Review AGENTS.md before committing.'
            } else {
                $layoutMessage = 'LAYOUT: AGENTS.md is not the retired generated mirror, so CLAUDE.md and AGENTS.md were left as they are. Merge CLAUDE.md into AGENTS.md by hand and make CLAUDE.md the two-import stub (docs/upgrade-checklist.md).'
            }
        }
    }
}

$settingsBackupRelative = $null
$settingsBackupKept = $false
if ($updateMode -and (Test-Path -LiteralPath (Join-Path $tgt '.claude/settings.json') -PathType Leaf)) {
    # Settings equal to one of this framework's own variants (line endings aside: a core.autocrlf checkout
    # rewrites them) were written by an earlier run of this update; saving them again would replace the
    # consumer's settings in the existing backup. Unreadable settings are backed up as before.
    try { $currentSettings = Get-LfSha256 -Bytes ([IO.File]::ReadAllBytes((Join-Path $tgt '.claude/settings.json'))) }
    catch { $currentSettings = $null }
    $shippedSettings = @(foreach ($variant in '.claude/settings.json', '.claude/settings.windows.json') {
        $shippedPath = Join-Path $src $variant
        if (Test-Path -LiteralPath $shippedPath -PathType Leaf) { Get-LfSha256 -Bytes ([IO.File]::ReadAllBytes($shippedPath)) }
    })
    if ($currentSettings -and ($shippedSettings -ccontains $currentSettings) -and
        (Test-Path -LiteralPath (Join-Path $tgt '.claude/.state/settings.json.pre-update') -PathType Leaf)) {
        $settingsBackupKept = $true
    } else {
        $settingsBackupRelative = '.claude/.state/settings.json.pre-update'
        [void](Add-PlannedWrite -Relative $settingsBackupRelative)
    }
}

# Which shipped paths do the target's own ignore rules hide? A plain check-ignore never reports a
# tracked path, and shipped paths hold no glob characters, so it reads them literally. Paths go as
# arguments: Windows PowerShell appends a CR to lines piped to --stdin. $null: Git could not answer;
# $script:IgnoreUnanswered then says whether that happened inside a work tree.
$script:IgnoreUnanswered = $false
function Get-IgnoredShippedPaths {
    $git = @(Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)
    $routed = @(@('GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR', 'GIT_INDEX_FILE') | Where-Object { [Environment]::GetEnvironmentVariable($_, 'Process') }).Count -gt 0
    if ($git.Count -eq 0 -or $routed) { return $null }
    $gitPath = [string]$git[0].Source
    $inside = Invoke-GitText -GitPath $gitPath -Arguments @('-C', $tgt, 'rev-parse', '--is-inside-work-tree')
    if (-not ($inside.Started -and $inside.ExitCode -eq 0 -and $inside.Output -ceq 'true')) { return $null }
    $query = $null
    if (@($incomingPaths | Where-Object { $_ -match '[\[\]*?]' }).Count -eq 0) {
        $query = Invoke-GitText -GitPath $gitPath -Arguments (@('-C', $tgt, 'check-ignore', '--') + $incomingPaths)
    }
    if ($null -eq $query -or -not $query.Started -or $query.ExitCode -notin @(0, 1)) { $script:IgnoreUnanswered = $true; return $null }
    # The comma keeps "nothing ignored" an empty array; returned bare it would arrive as $null.
    return , @($query.Output -split "`n" | Where-Object { $_ -cin $incomingPaths })
}
$ignoredShippedPaths = Get-IgnoredShippedPaths
# A colliding original the consumer had gitignored is one developer's file and may hold a key. Its
# archive stays out of Git through docs/pre-adoption/.gitignore, written before the first move.
$keptOutEntries = @()
if ($adoptMode -and $null -ne $ignoredShippedPaths) {
    $keptOutEntries = @($archivePlan | Where-Object { $_.OriginalRelative -cin $ignoredShippedPaths })
}
$archiveIgnoreRelative = 'docs/pre-adoption/.gitignore'
if ($keptOutEntries.Count -gt 0) { [void](Add-PlannedWrite -Relative $archiveIgnoreRelative) }
# Every copy an update saves goes below .claude/framework-update-backup/, and none needs committing: a tracked original
# is in history already, and an ignored one must not leak. Deciding per copy what Git may see lost three times (a
# copied '!' rule, the console's code page, an attribute filter), so the folder's .gitignore ends with '*' (Get-BackupKeepOut),
# and Git is asked after the last copy whether anything there is still committable. A file Git already tracks there stays
# tracked, so it is counted on every update. The copies an earlier update left where Git could commit them are the
# status records the dirty-tree check passed over, which -WhatIf reads here instead.
$backupRelative = '.claude/framework-update-backup'
$backupIgnoreRelative = "$backupRelative/.gitignore"
$backupResidue = @(); $backupTracked = 0; $backupKeepOut = $null; $savesIntoBackup = $false; $statusGitPath = $null
if ($updateMode) {
    $statusGit = @(Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($statusGit.Count -gt 0) { $statusGitPath = [string]$statusGit[0].Source }
    $statusRouted = @(@('GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR', 'GIT_INDEX_FILE') | Where-Object { [Environment]::GetEnvironmentVariable($_, 'Process') }).Count -gt 0
    if ($WhatIf -and $statusGitPath -and -not $statusRouted) { $script:TargetStatus = Get-TargetStatus -GitPath $statusGitPath }
    if ($null -ne $script:TargetStatus) { $backupResidue = Get-BackupResidue -Status $script:TargetStatus }
    # The list is the keep-out, not a copy.
    $trackedSet = Get-BackupTracked
    $backupTracked = @($trackedSet | Where-Object { $_ -ine $backupIgnoreRelative }).Count
    $savesIntoBackup = ($updateBackups.Count + $skillBackupPlan.Count + $backupResidue.Count) -gt 0 -or $null -ne $layoutMove
    if ($savesIntoBackup) {
        $backupKeepOut = Get-BackupKeepOut
        # Found here, before any change, so this refusal's "Nothing was changed" is true.
        if ($backupKeepOut.State -eq 'unwritable') {
            [Console]::Error.WriteLine("ERROR: Refusing update: $backupIgnoreRelative cannot be written ($($backupKeepOut.Reason)), and this update must end it with '*' before saving any copy below it. Make it writable (clear its read-only attribute, for one), then re-run the update. Nothing was changed.")
            exit 3
        }
        if ($backupKeepOut.State -eq 'write') { [void](Add-PlannedWrite -Relative $backupIgnoreRelative) }
    }
}

$adoptionMarkerRelative = $null
if ($adoptMode) { $adoptionMarkerRelative = '.claude/adoption-pending.json'; [void](Add-PlannedWrite -Relative $adoptionMarkerRelative) }
$modeName = if ($updateMode) { 'update' } elseif ($adoptMode) { 'brownfield' } else { 'greenfield' }
if ($layoutMessage) { Write-Output "  $layoutMessage" }
foreach ($message in $saveMessages) { Write-Output "  $message" }
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

# Freeze every brownfield candidate's raw pre-move identity and provenance BEFORE the first move.
# A read failure here is an examination failure, not an empty inventory: stop before mutating.
$archiveEvidence = New-Object System.Collections.Generic.List[object]
$archiveBaselineRevision = $null
$archiveInventoryIdentity = $null
$archiveInventoryComplete = $true
if ($adoptMode) {
    $archiveBaselineRevision = Get-AdoptionArchiveBaselineRevision
    foreach ($entry in $archivePlan) {
        try {
            $archiveEvidence.Add((New-AdoptionArchiveEvidence -OriginalRelative $entry.OriginalRelative -DestinationRelative $entry.Relative))
        } catch {
            [Console]::Error.WriteLine("ERROR: Refusing brownfield install: could not capture pre-move evidence for '$($entry.OriginalRelative)': $($_.Exception.Message)")
            exit 3
        }
    }
    $archiveInventoryIdentity = New-AdoptionInventoryIdentity -Entries $archiveEvidence.ToArray()
}

function Write-AdoptionMarker {
    param([Parameter(Mandatory = $true)][bool]$InventoryComplete)
    $marker = [ordered]@{
        installedAt       = (Get-Date).ToString('yyyy-MM-dd')
        detectedArtifacts = $detected
        # Legacy readers see only completed moves. The complete frozen inventory lives in
        # archiveIntegrity.entries from before the first mutation.
        archivedOriginals = @($archiveEvidence | Where-Object { $_.verified } | ForEach-Object { [string]$_.destination })
        archiveIntegrity  = [ordered]@{
            schemaVersion   = 1
            inventoryStatus = $(if ($InventoryComplete) { 'complete' } else { 'failed' })
            # baselineRevision is the committed-install HEAD (the pre-install revision) — an
            # immutable anchor for the whole inventory. Each entry's own provenanceRevision is the
            # commit that last touched THAT original path, used to attribute its author/history.
            baselineRevision = $archiveBaselineRevision
            capturedAt      = (Get-Date).ToString('yyyy-MM-dd')
            entries         = @($archiveEvidence | ForEach-Object { [pscustomobject]$_ })
            inventoryIdentity = $archiveInventoryIdentity
        }
        nextStep          = '/adopt - a developer types it in a session, OR an agent runs it headless (read .claude/commands/adopt.md and follow its Headless mode with a --headless directive). Headless prepares an adopt-ai-framework PR branch for human review; it does not auto-merge discovered content.'
        _comment          = 'Written by the framework installer because pre-existing AI tooling was detected. Consolidate it with /adopt - NOT /bootstrap. /adopt keeps this marker through archive and merge work, verifies and copies it for recovery, deletes it only immediately before the Phase-7 bootstrap, and restores it if completion fails.'
    }
    $markerPath = Join-Path $tgt '.claude/adoption-pending.json'
    $markerParent = Split-Path -Parent $markerPath
    New-Item -ItemType Directory -Force -Path $markerParent | Out-Null
    $temporary = Join-Path $markerParent ('.adoption-pending-' + [guid]::NewGuid().ToString('N') + '.tmp')
    $backup = Join-Path $markerParent ('.adoption-pending-' + [guid]::NewGuid().ToString('N') + '.bak')
    try {
        [IO.File]::WriteAllText($temporary, ($marker | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
        if (Test-Path -LiteralPath $markerPath -PathType Leaf) {
            [IO.File]::Replace($temporary, $markerPath, $backup)
        } else {
            Move-Item -LiteralPath $temporary -Destination $markerPath
        }
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue }
    }
}

$archiveEvidenceByDest = @{}
foreach ($ev in $archiveEvidence) { $archiveEvidenceByDest[[string]$ev.destination] = $ev }
if ($adoptMode) {
    # Persist the complete frozen inventory before the first source/archive mutation. If this
    # write cannot happen, do not begin a move whose provenance receipt could be lost.
    try {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent (Join-Path $tgt '.claude/adoption-pending.json')) | Out-Null
        Write-AdoptionMarker -InventoryComplete $true
    } catch {
        [Console]::Error.WriteLine("ERROR: Refusing brownfield install: could not persist the complete pre-move archive inventory: $($_.Exception.Message)")
        exit 3
    }
}
if ($keptOutEntries.Count -gt 0) {
    # Written before any move, so an interrupted run never leaves a committable archive behind.
    try {
        $archiveIgnorePath = Get-ContainedTargetPath -Relative $archiveIgnoreRelative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $archiveIgnorePath) | Out-Null
        $archiveIgnoreText = if (Test-Path -LiteralPath $archiveIgnorePath -PathType Leaf) { [IO.File]::ReadAllText($archiveIgnorePath) } else { '' }
        $archiveIgnoreLines = @($archiveIgnoreText -split '\r?\n')
        $archiveIgnoreNew = @($keptOutEntries | ForEach-Object { '/' + $_.OriginalRelative } | Where-Object { $_ -cnotin $archiveIgnoreLines })
        if ($archiveIgnoreNew.Count -gt 0) {
            $separator = if ($archiveIgnoreText.Length -gt 0 -and -not $archiveIgnoreText.EndsWith("`n")) { "`n" } else { '' }
            [IO.File]::AppendAllText($archiveIgnorePath, $separator + ($archiveIgnoreNew -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
        }
    } catch {
        [Console]::Error.WriteLine("ERROR: Refusing brownfield install: could not write $archiveIgnoreRelative before archiving gitignored originals: $($_.Exception.Message)")
        exit 3
    }
}
foreach ($entry in $archivePlan) {
    try {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $entry.Destination) | Out-Null
        Move-Item -LiteralPath $entry.Original -Destination $entry.Destination
    } catch {
        $archiveInventoryComplete = $false
        try { if ($adoptMode) { Write-AdoptionMarker -InventoryComplete $false } } catch { [Console]::Error.WriteLine("ERROR: Could not update the frozen archive inventory after move failure: $($_.Exception.Message)") }
        [Console]::Error.WriteLine("ERROR: Brownfield archive move failed for '$($entry.OriginalRelative)' -> '$($entry.Relative)': $($_.Exception.Message)")
        [Console]::Error.WriteLine('  The complete pre-move inventory was written before archive mutation; originals not yet moved are untouched. Recover manually, then re-run.')
        exit 3
    }
    $ev = $archiveEvidenceByDest[[string]$entry.Relative]
    $movedBytes = $null
    try { $movedBytes = [IO.File]::ReadAllBytes($entry.Destination) } catch { $movedBytes = $null }
    $verdict = 'CANT-VERIFY'
    if ($null -ne $movedBytes) {
        $verdict = if ([int64]$movedBytes.LongLength -eq [int64]$ev.byteLength -and (Get-Sha256Hex -Bytes $movedBytes) -ceq [string]$ev.sha256) { 'PASS' } else { 'CORRUPTION' }
    }
    if ($verdict -eq 'PASS') {
        $ev.verified = $true
        $archived += $entry.Relative
        try { if ($adoptMode) { Write-AdoptionMarker -InventoryComplete $true } } catch {
            [Console]::Error.WriteLine("ERROR: Archive '$($entry.OriginalRelative)' passed byte verification but progress could not be persisted: $($_.Exception.Message)")
            [Console]::Error.WriteLine('  The earlier frozen inventory remains on disk with this entry unverified; do not continue or rebaseline it.')
            exit 3
        }
        Write-Output "  archived: $($entry.OriginalRelative) -> $($entry.Relative) (pre/post-move bytes verified)"
    } else {
        $archiveInventoryComplete = $false
        if ($adoptMode) { Write-AdoptionMarker -InventoryComplete $false }
        [Console]::Error.WriteLine("ERROR: Brownfield archive integrity check failed for '$($entry.OriginalRelative)' -> '$($entry.Relative)': $verdict.")
        [Console]::Error.WriteLine("  Verified moves before the failure: $(if ($archived.Count) { $archived -join ', ' } else { '(none)' }).")
        [Console]::Error.WriteLine('  Nothing was rolled back, re-hashed, or overwritten; originals not yet moved are untouched. Recover the archives manually, then re-run.')
        exit 3
    }
}
# Stop at the first failed delete, before any copy, and put back what this run already deleted: the
# tree is then unchanged (a Git target stays clean) and the old ownership manifest, the deletion
# authority, is still there, so a plain re-run finishes the job.
$retiredDeleted = New-Object System.Collections.Generic.List[object]
foreach ($relative in $deletePlan) {
    $retiredPath = Get-ContainedTargetPath -Relative $relative
    try {
        $retiredBytes = [IO.File]::ReadAllBytes($retiredPath)
        Remove-Item -Force -LiteralPath $retiredPath -ErrorAction Stop
    } catch {
        [Console]::Error.WriteLine("ERROR: Could not delete retired framework file '$relative': $($_.Exception.Message)")
        $notRestored = 0
        foreach ($done in $retiredDeleted) {
            try { [IO.File]::WriteAllBytes($done.Path, $done.Bytes) }
            catch {
                $notRestored++
                [Console]::Error.WriteLine("  Deleted and could not be put back: '$($done.Relative)': $($_.Exception.Message). Restore it from Git (git checkout -- <path>) before re-running.")
            }
        }
        if (-not $notRestored) { [Console]::Error.WriteLine('  Any retired file this run had already deleted was put back with its original content.') }
        [Console]::Error.WriteLine('  Resolve the cause above, then re-run the installer.')
        exit 3
    }
    $retiredDeleted.Add([pscustomobject]@{ Relative = $relative; Path = $retiredPath; Bytes = $retiredBytes })
}
foreach ($done in $retiredDeleted) { Write-Output "  retired: $($done.Relative)" }
if ($settingsBackupRelative) {
    $settingsBackup = Get-ContainedTargetPath -Relative $settingsBackupRelative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $settingsBackup) | Out-Null
    Copy-Item -Force -LiteralPath (Join-Path $tgt '.claude/settings.json') -Destination $settingsBackup
    Write-Output "  saved pre-update settings: $settingsBackupRelative"
} elseif ($settingsBackupKept) {
    Write-Output '  kept the earlier pre-update settings backup: .claude/.state/settings.json.pre-update (.claude/settings.json is already this framework''s own).'
}
# The folder's '*' is written before the first copy into it, the skill backup's included; a linked list never is.
if ($savesIntoBackup -and $backupKeepOut.State -eq 'write') {
    try { Write-BackupKeepOut -Bytes $backupKeepOut.Bytes } catch {
        [Console]::Error.WriteLine("ERROR: Could not write $backupIgnoreRelative before saving any copy below it: $($_.Exception.Message)")
        [Console]::Error.WriteLine('  No file this update saves first was saved or overwritten. Resolve the cause above, then re-run the installer; in a Git target add -AllowDirtyTree, since the changes Git now shows are this run''s own.')
        exit 3
    }
}
if ($skillBackupPlan.Count -gt 0) {
    $backupIncomplete = Get-ContainedTargetPath -Relative $backupIncompleteRelative
    $backupAt = $backupIncompleteRelative
    try {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backupIncomplete) | Out-Null
        [IO.File]::WriteAllText($backupIncomplete, "This skill backup is unfinished; the next framework update takes it again.`n")
        foreach ($entry in $skillBackupPlan) {
            $backupAt = $entry.SourceRelative
            $destination = Get-ContainedTargetPath -Relative $entry.Relative
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
            Copy-Item -Force -LiteralPath $entry.Source -Destination $destination -ErrorAction Stop
        }
        $backupAt = $backupIncompleteRelative
        Remove-Item -Force -LiteralPath $backupIncomplete -ErrorAction Stop
    } catch {
        [Console]::Error.WriteLine("ERROR: Could not finish the one-time skill backup at '$backupAt': $($_.Exception.Message)")
        [Console]::Error.WriteLine('  No skill was overwritten, and the next run takes the backup again. Resolve the cause above (usually a program holding a file open), then re-run the installer; in a Git target add -AllowDirtyTree, since the changes Git now shows are this run''s own.')
        exit 3
    }
}
foreach ($entry in $updateBackups) {
    try {
        $destination = Get-ContainedTargetPath -Relative $entry.Relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
        Copy-Item -LiteralPath $entry.Source -Destination $destination -ErrorAction Stop
    } catch {
        [Console]::Error.WriteLine("ERROR: Could not save '$($entry.Relative)' before replacing the file it copies: $($_.Exception.Message)")
        [Console]::Error.WriteLine('  That file was not overwritten. Resolve the cause above, then re-run the installer; in a Git target add -AllowDirtyTree, since the changes Git now shows are this run''s own.')
        exit 3
    }
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
# A kept team file is not the framework's, so the manifest leaves it out, written as build.ps1 writes
# it: a later update then finds the path unowned and saves the file before any wrapper replaces it.
if ($teamSkillPaths.Count -gt 0 -and $ordinaryApplyPaths.Contains('framework-ownership.json')) {
    $ownedEntries = @($incoming.Entries | Where-Object { -not $teamSkillPaths.Contains([string]$_.path) })
    $manifestLines = New-Object System.Collections.Generic.List[string]
    $manifestLines.Add('{'); $manifestLines.Add('  "schema-version": 1,'); $manifestLines.Add('  "paths": [')
    for ($i = 0; $i -lt $ownedEntries.Count; $i++) {
        $comma = if ($i -lt $ownedEntries.Count - 1) { ',' } else { '' }
        $pathJson = ([string]$ownedEntries[$i].path).Replace('\', '\\').Replace('"', '\"')
        $manifestLines.Add(('    {{ "path": "{0}", "ownership": "{1}" }}{2}' -f $pathJson, $ownedEntries[$i].ownership, $comma))
    }
    $manifestLines.Add('  ]'); $manifestLines.Add('}')
    [IO.File]::WriteAllText((Get-ContainedTargetPath -Relative 'framework-ownership.json'), (($manifestLines -join "`n") + "`n"), [Text.UTF8Encoding]::new($false))
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
        $newText = [Text.UTF8Encoding]::new($false, $true).GetString([IO.File]::ReadAllBytes($newFile))
        $newText = [regex]::Replace($newText, '(?m)^For a concrete current instance in this repo, see .+\r?\n?', '')
        Set-Content -LiteralPath $newFile -Value ($newText.TrimEnd() + "`n`n" + $skillExemplars[$name] + "`n") -Encoding UTF8
    }
}
# A disabled skill's files are already carried to .claude/disabled-skills, so a folder that cannot be
# removed leaves only its active copy to delete by hand. The steps after this one still run and the
# update stops at the end; a re-run is no remedy, since a Git target is dirty by then and refuses it.
$skillsLeftActive = New-Object System.Collections.Generic.List[string]
foreach ($relative in $skillDeletePlan) {
    $path = Get-ContainedTargetPath -Relative $relative
    if (-not (Test-Path -LiteralPath $path)) { continue }
    try { Remove-Item -Recurse -Force -LiteralPath $path -ErrorAction Stop }
    catch {
        [Console]::Error.WriteLine("ERROR: Could not remove the active copy of disabled skill '$relative': $($_.Exception.Message)")
        [Console]::Error.WriteLine("  Its files are kept under .claude/disabled-skills/$(Split-Path -Leaf $relative); resolve the cause above (usually a program holding a file open), then delete $relative by hand.")
        $skillsLeftActive.Add($relative)
    }
}
if ($layoutMove) {
    # Backups first, byte-for-byte; then AGENTS.md; the stub last, so an interrupted run leaves
    # CLAUDE.md un-migrated and a re-run finds AGENTS.md no longer a mirror and stops.
    $backupRoot = '.claude/framework-update-backup/instruction-files'
    $backupDestination = Get-ContainedTargetPath -Relative $layoutMove.ClaudeBackup
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backupDestination) | Out-Null
    Copy-Item -Force -LiteralPath (Get-ContainedTargetPath -Relative 'CLAUDE.md') -Destination $backupDestination
    if ($layoutMove.BackupAgents) {
        Copy-Item -Force -LiteralPath (Get-ContainedTargetPath -Relative 'AGENTS.md') -Destination (Get-ContainedTargetPath -Relative $layoutMove.AgentsBackup)
    }
    [IO.File]::WriteAllText((Get-ContainedTargetPath -Relative 'AGENTS.md'), $layoutMove.AgentsText, [Text.UTF8Encoding]::new($layoutMove.HasBom))
    Copy-Item -Force -LiteralPath (Join-Path $src 'CLAUDE.md') -Destination (Get-ContainedTargetPath -Relative 'CLAUDE.md')
    Write-Output "  moved: CLAUDE.md -> AGENTS.md; CLAUDE.md is now the import stub (originals in $backupRoot/)."
}
# Asked after the last copy: only Git can say none is committable. A target without Git has no commit to keep them from.
if ($savesIntoBackup) {
    # Every path this run wrote a copy to: Git must show none of them, whatever their status code.
    $backupWritten = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $updateBackups) { [void]$backupWritten.Add([string]$entry.Relative) }
    foreach ($entry in $skillBackupPlan) { [void]$backupWritten.Add([string]$entry.Relative) }
    if ($layoutMove) { foreach ($relative in @($layoutMove.ClaudeBackup, $layoutMove.AgentsBackup)) { if ($relative) { [void]$backupWritten.Add($relative) } } }
    $visible = 0
    if ($null -ne $script:TargetStatus) { $visible = Get-BackupVisibleCount -GitPath $statusGitPath -Prefix $script:TargetStatus.Prefix -Written $backupWritten }
    elseif ($backupKeepOut.State -eq 'blocked') { $visible = $null }
    if ($backupKeepOut.State -ne 'blocked' -and $null -ne $visible -and $visible -eq 0) {
        $left = if ($backupResidue.Count -gt 0) { " That covers the $(if ($backupResidue.Count -eq 1) { '1 file' } else { "$($backupResidue.Count) files" }) an earlier update left there where Git could commit $(if ($backupResidue.Count -eq 1) { 'it' } else { 'them' }), which may hold copies of files you had gitignored." } else { '' }
        Write-Output "  kept out of Git: every copy this update saves goes under $backupRelative/, whose .gitignore ends with '*', so Git ignores the whole folder.$left Keep what you need under other paths, then delete the folder."
    } else {
        $why = if ($backupKeepOut.State -eq 'blocked') { "but its .gitignore $($backupKeepOut.Reason), which this update never writes through, so it could not end that list with '*'." } else { "whose .gitignore ends with '*', but" }
        $seen = if ($null -eq $visible) { 'Git could not say what it would commit there.' } else { "Git can still commit $(if ($visible -eq 1) { '1 file' } else { "$visible files" }) there." }
        Write-Output "  CANT-VERIFY: every copy this update saves goes under $backupRelative/, $why $seen Copies there may hold files you had gitignored: do not commit that folder. Keep what you need under other paths, then delete it."
    }
}
if ($backupTracked -gt 0) {
    Write-Output "  NOTICE: Git tracks $(if ($backupTracked -eq 1) { '1 file' } else { "$backupTracked files" }) under $backupRelative/, which may hold copies of files you had gitignored; '*' hides only what Git does not track yet. Review them, then untrack them with  git rm -r --cached $backupRelative  and commit that. A secret once committed there stays in your Git history: rotate it, or rewrite that history."
}
if ($updateMode) {
    $untouchedContent = @($protected | Where-Object { -not ($layoutMove -and $_ -in @('CLAUDE.md', 'AGENTS.md')) })
    Write-Output "  consumer-owned content files left untouched ($($untouchedContent -join ', '))."
}

if ($adoptMode) {
    # Durable adoption marker: the SessionStart hook warns every new session, and docs-sync-check
    # fails CI, until /adopt completes. It remains through archive and merge work, is verified and
    # copied for recovery, then is removed only immediately before the Phase-7 bootstrap and
    # restored if completion fails. Its archiveIntegrity block carries the frozen raw pre-move
    # digests and provenance /adopt re-verifies across Phase 7.
    Write-AdoptionMarker -InventoryComplete $archiveInventoryComplete
}

# Claude Code hooks default to pwsh (PowerShell 7). If it isn't installed, fall back to the Windows
# PowerShell 5.1 variant (preinstalled on every Windows box) so the hooks still fire. Reuse that
# resolved host in the printed follow-up commands; guidance must not name an unavailable executable.
if (-not $pwshAvailable) {
    $sj  = Join-Path $tgt '.claude/settings.json'
    $sjw = Join-Path $tgt '.claude/settings.windows.json'
    if ((Test-Path -LiteralPath $sjw) -and (Test-Path -LiteralPath $sj)) {
        Copy-Item -Force -LiteralPath $sjw -Destination $sj
        Write-Output "  pwsh not found - activated Windows PowerShell 5.1 hooks (settings.windows.json -> settings.json)."
    }
}

Write-Output ""
Write-Output "Each developer should run  $followUpPowerShell scripts/framework-doctor.ps1  once on their own machine."
# Framework files the consumer's own rules ignore would be left out of the commit, so teammates would
# never get them. Asked again now: the install may have replaced the rule (a consumer .claude/.gitignore).
# The audit log is ignored on purpose (it is per-machine state).
$script:IgnoreUnanswered = $false
$ignoredAfterCopy = Get-IgnoredShippedPaths
$hiddenShipped = @($ignoredAfterCopy | Where-Object { $_ -and $_ -notin $persistentCopyIfAbsent -and -not $teamSkillPaths.Contains($_) })
if ($hiddenShipped.Count -gt 0) {
    $hiddenSummary = @($hiddenShipped | Group-Object { if ($_.Contains('/')) { $_.Split('/')[0] + '/' } else { $_ } } | Sort-Object Name |
        ForEach-Object { if ($_.Count -gt 1) { "$($_.Name) ($($_.Count) files)" } else { $_.Group[0] } }) -join ', '
    Write-Output "WARNING: your ignore rules hide $($hiddenShipped.Count) of the framework's own files, so committing this install leaves them out and teammates will not get them: $hiddenSummary. Add exceptions for them to .gitignore before committing."
} elseif ($script:IgnoreUnanswered) {
    Write-Output "NOTE: Git could not say whether your ignore rules hide any of the framework's files; check git status --ignored before committing."
}
if ($skillsLeftActive.Count -gt 0) {
    [Console]::Error.WriteLine('  Every other step of this update is done. After deleting what is named above, continue with docs/upgrade-checklist.md.')
    exit 3
}
if ($updateMode) {
    Write-Output "Done (update). Framework-owned machinery refreshed; the listed protected paths were left untouched; .claude/settings.json was backed up and refreshed."
    Write-Output "  Reconcile protected rules and verify the update with docs/upgrade-checklist.md."
    Write-Output "  Next: review the diff, run  $followUpPowerShell scripts/docs-sync-check.ps1 , then commit."
} elseif ($adoptMode) {
    # Say what the consumer will find: only colliding files move; other tooling stays in place.
    $moved = @($archivePlan | ForEach-Object { $_.OriginalRelative })
    $leftInPlace = @($detected | Where-Object { $_ -notin $moved })
    Write-Output "Done - but this repo is NOT ready for AI-assisted work yet: it has pre-existing AI"
    Write-Output "tooling that must be consolidated with /adopt; .claude/adoption-pending.json records the inventory."
    if ($moved.Count -gt 0) { Write-Output "Moved to docs/pre-adoption/ (this install would have overwritten them): $($moved -join ', ')" }
    if ($leftInPlace.Count -gt 0) { Write-Output "Left where they were: $($leftInPlace -join ', ')" }
    if ($keptOutEntries.Count -gt 0) { Write-Output "Kept out of Git - you had gitignored these, and they may hold secrets: $(@($keptOutEntries | ForEach-Object { $_.OriginalRelative }) -join ', '). $archiveIgnoreRelative lists their archives; keep per-developer settings in files Git ignores, such as .claude/settings.local.json." }
    # Without Git's answer an archived original may still be one you had gitignored.
    if ($moved.Count -gt 0 -and $null -eq $ignoredShippedPaths) { Write-Output "Some may be files you had gitignored: check docs/pre-adoption/ for secrets before committing." }
    Write-Output ""
    Write-Output "Next steps in the target repo:"
    Write-Output "  1. Review and commit the copied files (they are team-shared config, not local settings)."
    Write-Output "  2. A developer starts a Claude Code session, or an interactive Copilot CLI session, in the"
    Write-Output "     target repo and must type:  /adopt"
    Write-Output "     It merges the earlier material into AGENTS.md, then runs /bootstrap. Only a developer can"
    Write-Output "     start it. Do NOT run /bootstrap instead: it would skip the archive, merge and provenance steps."
    Write-Output "  3. docs/getting-started.md walks the developer from here to a first reviewed fix."
    Write-Output "  Until /adopt has run, new sessions show a reminder and docs-sync-check fails by design;"
    Write-Output "  neither is a defect to fix."
    Write-Output ""
    Write-Output "  IF YOU ARE AN AI AGENT running this installer: your task is NOT complete until you"
    Write-Output "  have done step 1 (commit the copied files) and then told the developer to start a"
    Write-Output "  Claude Code or interactive Copilot CLI session in the target repo and type /adopt."
    Write-Output "  Report that as the required next step in your final summary. Do not run /adopt yourself or"
    Write-Output "  replicate it by hand. Only if the developer asked you for unattended adoption, follow"
    Write-Output "  'Headless mode' in .claude/commands/adopt.md instead: it prepares a branch with every merge"
    Write-Output "  staged for a person to review, and opens or merges nothing."
} else {
    Write-Output "Done. Next steps in the target repo:"
    Write-Output "  1. Review and commit the copied files (they are team-shared config, not local settings)."
    Write-Output "  2. A developer starts a Claude Code session, or an interactive Copilot CLI session, in the"
    Write-Output "     target repo and must type:  /bootstrap"
    Write-Output "     It reads the code and writes AGENTS.md, which every AI tool in the repo follows; review it"
    Write-Output "     afterwards. Only a developer can start it."
    Write-Output "  3. docs/getting-started.md walks the developer from here to a first reviewed fix."
    Write-Output "  Until /bootstrap has run, new sessions show a reminder and docs-sync-check fails by design;"
    Write-Output "  neither is a defect to fix. After it has run, verify:  $followUpPowerShell scripts/docs-sync-check.ps1"
    Write-Output ""
    Write-Output "  IF YOU ARE AN AI AGENT running this installer: your task is NOT complete until you"
    Write-Output "  have done step 1 and then told the developer, explicitly, to start a Claude Code or an"
    Write-Output "  interactive Copilot CLI session in the target repo and type /bootstrap. Report that as the"
    Write-Output "  required manual next step in your final summary."
    Write-Output "  Do not attempt /bootstrap yourself or replicate it by hand."
}
exit 0
