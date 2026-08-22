# Install the AI Tech Lead Framework into a target repository.
# Usage: pwsh scripts/install.ps1 [-GitHooks] [-AllowDirtyTree] C:\path\to\target-repo
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
    [switch]$AllowDirtyTree
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

if ($GitHooks) {
    & (Join-Path $src 'scripts/setup-git-hooks.ps1') -Target $tgt -CheckOnly
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

# Template-repo meta files that must never land in (or overwrite their namesakes in) a consumer repo.
$metaFiles = @('.git', '.template-repo', 'README.md', 'CHANGELOG.md', '.gitignore', '.gitattributes')

# Consumer files the copy below would otherwise clobber. Brownfield: archived so /adopt can merge
# them. Update: snapshotted and restored — after bootstrap/adopt the consumer owns their content.
$protected = @('CLAUDE.md', 'AGENTS.md', 'TECH_DEBT.md', 'SECURITY_FINDINGS.md', 'LEARNINGS.md',
    'FRAMEWORK-CONTEXT.md', '.github/copilot-instructions.md', 'docs/ARCHITECTURE.md')
# Persistent state is copied only when absent. The composer reads this policy from both installer
# twins and emits it as consumer-owned/protected in framework-ownership.json.
$persistentCopyIfAbsent = @(
    '.claude/ai-audit.log'
)
# These are never bulk-replaced, so brownfield must not archive them merely because the incoming
# ownership manifest lists them. The audit entry remains the separately composer-verified
# persistent policy above.
$copyIfAbsent = $persistentCopyIfAbsent + @('docs/wiki/INDEX.md')

# Signals that the target already has AI tooling and therefore needs /adopt, not /bootstrap
# (mirrors /adopt Phase 1 discovery).
$adoptionSignals = @('CLAUDE.md', 'AGENTS.md', 'GEMINI.md', '.cursorrules', '.cursor/rules',
    '.clinerules', '.windsurfrules', '.roomodes', '.aider.conf.yml', '.continue',
    '.github/copilot-instructions.md', '.github/instructions', '.github/chatmodes',
    'docs/adr', 'docs/decisions', 'ARCHITECTURE.md', 'docs/ARCHITECTURE.md', 'CODEMAP.md',
    'CONVENTIONS.md', 'docs/CONVENTIONS.md', 'TECH_DEBT.md', 'TODO.md', 'BACKLOG.md',
    'docs/wiki/INDEX.md')

$updateMode = Test-Path -LiteralPath (Join-Path $tgt '.claude/framework-version.json')
$detected = @()
if (-not $updateMode) {
    $detected = @($adoptionSignals | Where-Object { Test-Path -LiteralPath (Join-Path $tgt $_) })
}
$adoptMode = (-not $updateMode) -and ($detected.Count -gt 0)

# The incoming manifest is the sole brownfield collision inventory. Read and validate the complete
# archive plan before the first target mutation: an archive collision must refuse, never overwrite.
$incomingManifest = Join-Path $src 'framework-ownership.json'
try {
    $incomingPaths = @((Get-Content -Raw -LiteralPath $incomingManifest | ConvertFrom-Json).paths | ForEach-Object { [string]$_.path })
} catch {
    [Console]::Error.WriteLine("ERROR: Cannot read incoming framework ownership manifest '$incomingManifest': $($_.Exception.Message)")
    exit 3
}
if ($incomingPaths.Count -eq 0) {
    [Console]::Error.WriteLine("ERROR: Incoming framework ownership manifest '$incomingManifest' contains no paths.")
    exit 3
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

# Refuse a dirty Git target before any installer mutation. This does not make Git a prerequisite:
# greenfield/non-Git targets remain valid. An override is intentionally noisy and never implicit.
if (($adoptMode -or $updateMode) -and (Get-Command git -ErrorAction SilentlyContinue)) {
    & git -C $tgt rev-parse --is-inside-work-tree *> $null
    if ($LASTEXITCODE -eq 0) {
        $dirty = @(& git -C $tgt status --porcelain=v1 --untracked-files=all)
        if ($LASTEXITCODE -ne 0) {
            [Console]::Error.WriteLine('CANT-VERIFY: Git identified this target as a worktree, but its status could not be read. Commit, stash, or copy local changes, then repair Git and re-run the installer.')
            exit 4
        }
        if ($dirty.Count -gt 0) {
            if (-not $AllowDirtyTree) {
                [Console]::Error.WriteLine('ERROR: Refusing to mutate a dirty Git target. Commit, stash, or copy local changes, then re-run; use -AllowDirtyTree only after doing so deliberately.')
                exit 4
            }
            Write-Output '  override: -AllowDirtyTree (--allow-dirty-tree) accepted for this dirty Git target.'
        }
    }
}

Write-Output "Installing AI Tech Lead Framework"
Write-Output "  from: $src"
Write-Output "  into: $tgt"
if ($updateMode)    { Write-Output "  mode: update (existing install detected via .claude/framework-version.json)" }
elseif ($adoptMode) { Write-Output "  mode: brownfield (pre-existing AI tooling detected: $($detected -join ', '))" }
else                { Write-Output "  mode: greenfield" }

if ($updateMode) {
    Write-Output "  UPDATE PREFLIGHT: This update replaces framework-owned files, including .claude/settings.json."
    Write-Output "  Ensure any local edits to those files were committed, stashed, or copied first."
    Write-Output "  Review the resulting diff before committing."
}

$archived = @()
$archivePlan = New-Object System.Collections.Generic.List[object]
if ($adoptMode) {
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
    foreach ($entry in $archivePlan) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $entry.Destination) | Out-Null
        Move-Item -LiteralPath $entry.Original -Destination $entry.Destination
        $archived += $entry.Relative
        Write-Output "  archived: $($entry.Relative.Substring('docs/pre-adoption/'.Length)) -> $($entry.Relative)"
    }
}

$snapshot = $null
if ($updateMode) {
    $settings = Join-Path $tgt '.claude/settings.json'
    if (Test-Path -LiteralPath $settings -PathType Leaf) {
        $settingsBackup = Join-Path $tgt '.claude/.state/settings.json.pre-update'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $settingsBackup) | Out-Null
        Copy-Item -Force -LiteralPath $settings -Destination $settingsBackup
        Write-Output "  saved pre-update settings: .claude/.state/settings.json.pre-update"
    }
    # Snapshot consumer-owned content files; restored after the copy.
    $snapshot = Join-Path ([IO.Path]::GetTempPath()) ('ai-tech-lead-update-' + [IO.Path]::GetRandomFileName())
    foreach ($f in $protected) {
        $orig = Join-Path $tgt $f
        if (Test-Path -LiteralPath $orig -PathType Leaf) {
            $dest = Join-Path $snapshot $f
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
            Copy-Item -Force -LiteralPath $orig -Destination $dest
        }
    }
    $skillState = Join-Path $snapshot 'skill-state/.claude'
    foreach ($rel in @('skills','disabled-skills')) { $orig=Join-Path $tgt ".claude/$rel"; if(Test-Path -LiteralPath $orig -PathType Container){New-Item -ItemType Directory -Force -Path $skillState|Out-Null;Copy-Item -Recurse -Force -LiteralPath $orig -Destination $skillState} }
    $backup=Join-Path $tgt '.claude/framework-update-backup/skills'
    if(-not(Test-Path -LiteralPath $backup)-and(Test-Path -LiteralPath (Join-Path $tgt '.claude/skills'))){New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backup)|Out-Null;Copy-Item -Recurse -Force -LiteralPath (Join-Path $tgt '.claude/skills') -Destination $backup}
}

Get-ChildItem -Force -LiteralPath $src |
    Where-Object { $_.Name -notin $metaFiles -and $_.Name -notin @('docs', 'LICENSES', $legalNotice, '.claude') } |
    ForEach-Object { Copy-Item -Recurse -Force -LiteralPath $_.FullName -Destination $tgt }

# Preserve the append-only audit log byte-for-byte. All other .claude content remains normal
# framework machinery and is refreshed by the bulk copy.
$sourceClaude = Join-Path $src '.claude'
if (Test-Path -LiteralPath $sourceClaude -PathType Container) {
    $targetClaude = New-Item -ItemType Directory -Force -Path (Join-Path $tgt '.claude')
    Get-ChildItem -Force -LiteralPath $sourceClaude | ForEach-Object {
        $rel = '.claude/' + $_.Name
        $dest = Join-Path $targetClaude.FullName $_.Name
        if ($rel -in $persistentCopyIfAbsent -and (Test-Path -LiteralPath $dest)) { return }
        Copy-Item -Recurse -Force -LiteralPath $_.FullName -Destination $targetClaude.FullName
    }
}

# Copy docs normally except for the consumer-owned wiki index, which is copy-if-absent.
$sourceDocs = Join-Path $src 'docs'
if (Test-Path -LiteralPath $sourceDocs -PathType Container) {
    $targetDocs = New-Item -ItemType Directory -Force -Path (Join-Path $tgt 'docs')
    Get-ChildItem -Force -LiteralPath $sourceDocs |
        Where-Object { $_.Name -ne 'wiki' } |
        ForEach-Object { Copy-Item -Recurse -Force -LiteralPath $_.FullName -Destination $targetDocs.FullName }
    $sourceWiki = Join-Path $sourceDocs 'wiki'
    if (Test-Path -LiteralPath $sourceWiki -PathType Container) {
        $targetWiki = New-Item -ItemType Directory -Force -Path (Join-Path $targetDocs.FullName 'wiki')
        Get-ChildItem -Force -LiteralPath $sourceWiki | ForEach-Object {
            if ($_.Name -eq 'INDEX.md' -and (Test-Path -LiteralPath (Join-Path $targetWiki.FullName 'INDEX.md'))) { return }
            Copy-Item -Recurse -Force -LiteralPath $_.FullName -Destination $targetWiki.FullName
        }
    }
}

# Explicit legal-file policy above owns these paths; keeping them out of both $protected and the
# bulk copy lets the notice travel on update without asserting ownership over consumer collisions.
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetLicense) | Out-Null
if ($copyLegalLicense) { Copy-Item -Force -LiteralPath $sourceLicense -Destination $targetLicense }
Copy-Item -Force -LiteralPath (Join-Path $src $legalNotice) -Destination $targetNotice

# The installer is meta — don't ship it into the consumer repo. template-ci.yml is the TEMPLATE
# repo's own CI (hook suite + framework checks on push); consumers get the same framework checks
# via docs-sync-check -> template-checks, wired into their own CI.
foreach ($f in @('scripts/install.sh', 'scripts/install.ps1', '.github/workflows/template-ci.yml')) {
    Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath (Join-Path $tgt $f)
}

if ($updateMode -and $snapshot -and (Test-Path -LiteralPath $snapshot)) {
    foreach ($f in $protected) {
        $saved = Join-Path $snapshot $f
        if (Test-Path -LiteralPath $saved -PathType Leaf) {
            Copy-Item -Force -LiteralPath $saved -Destination (Join-Path $tgt $f)
        }
    }
    $oldSkills=Join-Path $snapshot 'skill-state/.claude/skills'
    if(Test-Path -LiteralPath $oldSkills){foreach($dir in Get-ChildItem -LiteralPath $oldSkills -Directory){$oldFile=Join-Path $dir.FullName 'SKILL.md';if(-not(Test-Path -LiteralPath $oldFile)){continue};$oldText=Get-Content -LiteralPath $oldFile -Raw;$dest=Join-Path $tgt ".claude/skills/$($dir.Name)";if($oldText-match'(?m)^origin:\s*discovered\s*$'){if(Test-Path -LiteralPath $dest){Remove-Item -Recurse -Force -LiteralPath $dest};Copy-Item -Recurse -Force -LiteralPath $dir.FullName -Destination $dest;continue};$ex=[regex]::Match($oldText,'(?m)^For a concrete current instance in this repo, see .+$');$newFile=Join-Path $dest 'SKILL.md';if($ex.Success-and(Test-Path -LiteralPath $newFile)){$newText=Get-Content -LiteralPath $newFile -Raw;$newText=[regex]::Replace($newText,'(?m)^For a concrete current instance in this repo, see .+\r?\n?','');Set-Content -LiteralPath $newFile -Value($newText.TrimEnd()+"`n`n"+$ex.Value+"`n") -Encoding UTF8}}}
    $savedLearnings=Join-Path $snapshot 'LEARNINGS.md'
    if(Test-Path -LiteralPath $savedLearnings){foreach($m in [regex]::Matches((Get-Content -LiteralPath $savedLearnings -Raw),'(?m)^## Disabled framework skill:\s*([a-z0-9-]+)\s*$')){$name=$m.Groups[1].Value;$active=Join-Path $tgt ".claude/skills/$name";$inactive=Join-Path $tgt ".claude/disabled-skills/$name";if(Test-Path -LiteralPath $active){New-Item -ItemType Directory -Force -Path(Split-Path -Parent $inactive)|Out-Null;if(Test-Path -LiteralPath $inactive){Remove-Item -Recurse -Force -LiteralPath $inactive};Move-Item -LiteralPath $active -Destination $inactive}}}
    $githubSkills=New-Item -ItemType Directory -Force -Path (Join-Path $tgt '.github/skills');Get-ChildItem -LiteralPath(Join-Path $tgt '.claude/skills') -Directory -ErrorAction SilentlyContinue|ForEach-Object{Copy-Item -Recurse -Force -LiteralPath $_.FullName -Destination $githubSkills.FullName}
    Remove-Item -Recurse -Force -LiteralPath $snapshot
    Write-Output "  consumer-owned content files left untouched ($($protected -join ', '))."
}

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
    Write-Output "Done (update). Framework-owned machinery refreshed; the listed protected paths were restored; .claude/settings.json was backed up and refreshed."
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
    Write-Output "  4. Review the generated CLAUDE.md - it is the source of truth that drives every tool."
    Write-Output ""
    Write-Output "  IF YOU ARE AN AI AGENT running this installer: your task is NOT complete until you"
    Write-Output "  have done step 1 and then told the developer, explicitly, to start a Claude Code"
    Write-Output "  session in the target repo and type /bootstrap. Report that as the required manual next"
    Write-Output "  step in your final summary. Do not attempt /bootstrap yourself or replicate it by hand."
}
