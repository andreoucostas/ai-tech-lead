# High-value destructive-boundary coverage for convergent installer updates. This replaces the
# retired runner's argument/permutation suite: once the runner is gone, the meaningful contract is
# whether an old installation converges without deleting consumer or out-of-root bytes.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$script:IsWindowsHost = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
$retiredPaths = @(
    'scripts/impact-run.ps1',
    'scripts/impact-run.sh',
    'tests/impact/README.md',
    'tests/impact/config.json',
    'tests/impact/tasks.json'
)

function Get-TreeFingerprint {
    param([string]$Root)
    return (@(Get-ChildItem -LiteralPath $Root -Recurse -Force | Sort-Object FullName | ForEach-Object {
        $relative = $_.FullName.Substring($Root.Length).TrimStart('\', '/') -replace '\\', '/'
        if ($_.PSIsContainer) { "D|$relative" } else { "F|$relative|$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" }
    }) -join "`n")
}

function Get-FileState {
    param([string]$Root)
    $state = @{}
    foreach ($file in Get-ChildItem -LiteralPath $Root -Recurse -File -Force) {
        $relative = $file.FullName.Substring($Root.Length).TrimStart('\', '/') -replace '\\', '/'
        $state[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    }
    return $state
}

function New-LegacyRetirementTarget {
    $target = Join-Path ([IO.Path]::GetTempPath()) ('installer-convergence-' + [guid]::NewGuid().ToString('N'))
    $stage = Join-Path ([IO.Path]::GetTempPath()) ('installer-history-' + [guid]::NewGuid().ToString('N'))
    $archive = Join-Path ([IO.Path]::GetTempPath()) ('installer-history-' + [guid]::NewGuid().ToString('N') + '.tar')
    New-Item -ItemType Directory -Force -Path $target, $stage | Out-Null
    try {
        $historical = @('dist/dotnet/framework-ownership.json') + @($retiredPaths | ForEach-Object { "dist/dotnet/$_" })
        & git -C $repoRoot archive --format=tar "--output=$archive" v0.75.0 @historical
        Assert ($LASTEXITCODE -eq 0) 'could not archive the v0.75.0 retirement fixture'
        & tar -xf $archive -C $stage
        Assert ($LASTEXITCODE -eq 0) 'could not extract the v0.75.0 retirement fixture'
        foreach ($relative in @('framework-ownership.json') + $retiredPaths) {
            $source = Join-Path $stage "dist/dotnet/$relative"
            $destination = Join-Path $target $relative
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
            Copy-Item -LiteralPath $source -Destination $destination -Force
        }
        New-Item -ItemType Directory -Force -Path (Join-Path $target '.claude') | Out-Null
        [IO.File]::WriteAllText((Join-Path $target '.claude/framework-version.json'), '{"version":"0.75.0","template":"dotnet"}', [Text.UTF8Encoding]::new($false))
        return $target
    } finally {
        Remove-Item -Recurse -Force -LiteralPath $stage -ErrorAction SilentlyContinue
        Remove-Item -Force -LiteralPath $archive -ErrorAction SilentlyContinue
    }
}

function New-RichUpdateTarget {
    $target = New-LegacyRetirementTarget
    New-Item -ItemType Directory -Force -Path (Join-Path $target '.claude/skills/add-warehouse-load'), (Join-Path $target '.claude/skills/local-release'), (Join-Path $target '.claude/skills/consumer-local'), (Join-Path $target '.claude/skills/perf'), (Join-Path $target '.github/skills/local-release'), (Join-Path $target '.github/skills/perf') | Out-Null
    [IO.File]::WriteAllText((Join-Path $target '.claude/settings.json'), '{"consumerEdit":"recover me"}', [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $target 'LEARNINGS.md'), "# Learnings`n`n## Disabled framework skill: perf`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $target '.claude/skills/add-warehouse-load/SKILL.md'), "---`nname: add-warehouse-load`n---`nOLD BODY`nFor a concrete current instance in this repo, see ``warehouse/LoadSales.sql``.`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $target '.claude/skills/local-release/SKILL.md'), "---`nname: local-release`norigin: discovered`n---`nConsumer recipe`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $target '.claude/skills/local-release/notes.md'), "consumer notes`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $target '.claude/skills/consumer-local/SKILL.md'), "---`nname: consumer-local`n---`nLOCAL BODY`nFor a concrete current instance in this repo, see ``warehouse/ConsumerOnly.sql``.`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $target '.claude/skills/perf/SKILL.md'), "---`nname: perf`n---`nold inactive policy`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $target '.github/skills/local-release/SKILL.md'), "STALE MIRROR`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $target '.github/skills/perf/SKILL.md'), "STALE ACTIVE MIRROR`n", [Text.UTF8Encoding]::new($false))
    return $target
}

function Invoke-CurrentInstaller {
    param([string]$Target, [string]$SourceRoot, [switch]$DryRun, [switch]$AllowDowngrade, [switch]$AllowDirtyTree)
    $root = if ($SourceRoot) { $SourceRoot } else { Join-Path $repoRoot 'dist/dotnet' }
    $installer = Join-Path $root 'scripts/install.ps1'
    $arguments = @('-NoProfile','-File',$installer,'-Target',$Target)
    if ($DryRun) { $arguments += '-WhatIf' }
    if ($AllowDowngrade) { $arguments += '-AllowDowngrade' }
    if ($AllowDirtyTree) { $arguments += '-AllowDirtyTree' }
    $output = & (Get-PsExe) @arguments 2>&1 | Out-String
    return [pscustomobject]@{ Exit = [int]$LASTEXITCODE; Output = $output }
}

# B-217 needs a source-candidate fixture: it removes the incoming mirror, uses the authored
# cumulative retirement ledger, and adds one test-only modified leaf. This let the test observe the
# unfixed installer red before the coordinated source/ledger change was composed into dist.
function New-B217CandidateSource {
    $candidate = Join-Path ([IO.Path]::GetTempPath()) ('b217-installer-source-' + [guid]::NewGuid().ToString('N'))
    Copy-Item -LiteralPath (Join-Path $repoRoot 'dist/dotnet') -Destination $candidate -Recurse -Force
    if (Test-Path -LiteralPath (Join-Path $candidate '.github/skills')) {
        Remove-Item -LiteralPath (Join-Path $candidate '.github/skills') -Recurse -Force
    }
    Copy-Item -LiteralPath (Join-Path $repoRoot 'src/core/scripts/install.ps1') -Destination (Join-Path $candidate 'scripts/install.ps1') -Force

    $stock = '.github/skills/perf/SKILL.md'
    $ledgerPath = Join-Path $candidate 'framework-retirements.json'
    Copy-Item -LiteralPath (Join-Path $repoRoot 'src/core/framework-retirements.json') -Destination $ledgerPath -Force
    $ledger = Get-Content -LiteralPath $ledgerPath -Raw | ConvertFrom-Json
    $ledgerPaths = @($ledger.retirements | ForEach-Object { [string]$_.path })
    Assert ($ledgerPaths -ccontains $stock) "B-217 source retirement ledger does not name the stock mirror leaf $stock"
    Assert ($ledgerPaths -ccontains 'scripts/sync-agent-files.ps1') 'B-217 source retirement ledger does not name sync-agent-files.ps1'
    $ledger.retirements = @($ledger.retirements) + [pscustomobject]@{
        path = '.github/skills/perf/modified.md'
        'retired-in' = '0.82.0'
        'known-content-sha256' = @('a3f4826b6bdf6da3ff876197e4bc386a6a4e66c0bd3c79d90c6bdc29a6de88f1')
    }
    [IO.File]::WriteAllText($ledgerPath, ($ledger | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))

    # dist can legitimately lag the authored retirement ledger while this meta test runs. Preserve
    # its one-entry-per-line formatting while removing every path the candidate ledger retires
    # instead of naming only the B-217 subset.
    $retiredSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in @($ledger.retirements)) { [void]$retiredSet.Add([string]$entry.path) }
    $ownershipPath = Join-Path $candidate 'framework-ownership.json'
    $ownershipLines = foreach ($line in Get-Content -LiteralPath $ownershipPath) {
        $match = [regex]::Match($line, '"path"\s*:\s*"([^"]+)"')
        if (-not $match.Success -or -not $retiredSet.Contains($match.Groups[1].Value)) { $line }
    }
    [IO.File]::WriteAllLines($ownershipPath, [string[]]$ownershipLines, [Text.UTF8Encoding]::new($false))
    return [pscustomobject]@{ Root = $candidate; Stock = $stock }
}

function New-B217ResidualTarget {
    param([string]$StockPath)
    $target = Join-Path ([IO.Path]::GetTempPath()) ('b217-installer-target-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path (Join-Path $target '.claude'), (Join-Path $target '.github/skills/perf'), (Join-Path $target '.github/skills/local-only'), (Join-Path $target 'scripts') | Out-Null
    [IO.File]::WriteAllText((Join-Path $target '.claude/framework-version.json'), '{"version":"0.81.0","template":"dotnet"}', [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $target 'framework-ownership.json'), @"
{
  "schema-version": 1,
  "paths": [
    { "path": "$StockPath", "ownership": "framework-owned/overwritten" },
    { "path": ".github/skills/perf/modified.md", "ownership": "framework-owned/overwritten" }
  ]
}
"@, [Text.UTF8Encoding]::new($false))
    $canonicalStock = $StockPath -replace '^\.github/skills/', '.claude/skills/'
    [IO.File]::WriteAllBytes((Join-Path $target $StockPath), [IO.File]::ReadAllBytes((Join-Path $repoRoot ('dist/dotnet/' + $canonicalStock))))
    [IO.File]::WriteAllText((Join-Path $target '.github/skills/perf/modified.md'), 'CONSUMER-MODIFIED MIRROR', [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $target '.github/skills/local-only/SKILL.md'), 'UNKNOWN GITHUB-ONLY SKILL', [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $target 'scripts/sync-agent-files.ps1'), @"
# CONSUMER-MODIFIED SYNC SCRIPT
param([string]`$Target)
`$destination = Join-Path `$Target '$StockPath'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent `$destination) | Out-Null
[IO.File]::WriteAllText(`$destination, 'RECREATED BY CONSUMER SYNC SCRIPT', [Text.UTF8Encoding]::new(`$false))
"@, [Text.UTF8Encoding]::new($false))
    return $target
}

function New-B217LegacyManifestTarget {
    param([string]$StockPath, [ValidateSet('missing', 'malformed')][string]$ManifestShape)
    $target = Join-Path ([IO.Path]::GetTempPath()) ('b217-legacy-manifest-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path (Join-Path $target '.claude'), (Split-Path -Parent (Join-Path $target $StockPath)) | Out-Null
    [IO.File]::WriteAllText((Join-Path $target '.claude/framework-version.json'), '{"version":"0.64.0","template":"dotnet"}', [Text.UTF8Encoding]::new($false))
    $canonicalStock = $StockPath -replace '^\.github/skills/', '.claude/skills/'
    [IO.File]::WriteAllBytes((Join-Path $target $StockPath), [IO.File]::ReadAllBytes((Join-Path $repoRoot ('dist/dotnet/' + $canonicalStock))))
    if ($ManifestShape -eq 'malformed') {
        [IO.File]::WriteAllText((Join-Path $target 'framework-ownership.json'), '{"schema-version":1,"paths":[BROKEN]}', [Text.UTF8Encoding]::new($false))
    }
    return $target
}

function New-DirectoryLink {
    param([string]$Link, [string]$Destination)
    if ($script:IsWindowsHost) {
        & cmd /c mklink /J $Link $Destination *> $null
    } else {
        & ln -s $Destination $Link
    }
    return ($LASTEXITCODE -eq 0 -or (Test-Path -LiteralPath $Link))
}

$legacyGitHookRetiredPaths = @('scripts/setup-git-hooks.ps1', 'scripts/setup-git-hooks.sh', '.claude/hooks/guard.sh')
$legacyGitHookHelperContent = @{
    'scripts/setup-git-hooks.ps1' = "# historical PowerShell setup helper fixture`r`n"
    'scripts/setup-git-hooks.sh' = "#!/usr/bin/env bash`n# historical Bash setup helper fixture`n"
    '.claude/hooks/guard.sh' = "#!/usr/bin/env bash`n# historical Bash guard fixture`n"
}
$legacyPowerShellPreCommit = @'
#!/bin/sh
# AI Tech Lead opt-in convenience net. Bypassable with git commit --no-verify; not enforcement.
repo_root=$(git rev-parse --show-toplevel) || exit 1
command -v pwsh >/dev/null 2>&1 || { echo 'COMMIT REFUSED: pwsh is required by the installed pre-commit convenience net.' >&2; exit 1; }
exec pwsh -NoProfile -File "$repo_root/scripts/setup-git-hooks.ps1" -Target "$repo_root" -Scan
'@
$legacyBashPreCommit = @'
#!/bin/sh
# AI Tech Lead opt-in convenience net. Bypassable with git commit --no-verify; not enforcement.
repo_root=$(git rev-parse --show-toplevel) || exit 1
exec bash "$repo_root/scripts/setup-git-hooks.sh" --target "$repo_root" --scan
'@

function Write-LegacyGitHookHelperFixtures {
    param([string]$Root)
    foreach ($relative in $legacyGitHookRetiredPaths) {
        $path = Join-Path $Root $relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
        $encoding = [Text.UTF8Encoding]::new($relative.EndsWith('.ps1'))
        [IO.File]::WriteAllText($path, $legacyGitHookHelperContent[$relative], $encoding)
    }
}

function New-LegacyGitHookCandidateSource {
    $candidate = Join-Path ([IO.Path]::GetTempPath()) ('legacy-hook-candidate-' + [guid]::NewGuid().ToString('N'))
    Copy-Item -LiteralPath (Join-Path $repoRoot 'dist/dotnet') -Destination $candidate -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'src/core/scripts/install.ps1') -Destination (Join-Path $candidate 'scripts/install.ps1') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'src/core/scripts/framework-doctor.ps1') -Destination (Join-Path $candidate 'scripts/framework-doctor.ps1') -Force

    Write-LegacyGitHookHelperFixtures -Root $candidate
    $digests = @{}
    foreach ($relative in $legacyGitHookRetiredPaths) {
        $digests[$relative] = (Get-FileHash -LiteralPath (Join-Path $candidate $relative) -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $manifestPath = Join-Path $candidate 'framework-ownership.json'
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    $manifest.paths = @($manifest.paths | Where-Object { $_.path -notin $legacyGitHookRetiredPaths })
    [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))

    $ledgerPath = Join-Path $candidate 'framework-retirements.json'
    $ledger = Get-Content -Raw -LiteralPath $ledgerPath | ConvertFrom-Json
    foreach ($relative in $legacyGitHookRetiredPaths) {
        $ledger.retirements = @($ledger.retirements | Where-Object { $_.path -ne $relative }) +
            [pscustomobject]@{ path = $relative; 'retired-in' = '0.83.0'; 'known-content-sha256' = @($digests[$relative]) }
        Remove-Item -Force -LiteralPath (Join-Path $candidate $relative)
    }
    [IO.File]::WriteAllText($ledgerPath, ($ledger | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))

    $stampPath = Join-Path $candidate '.claude/framework-version.json'
    $stamp = Get-Content -Raw -LiteralPath $stampPath | ConvertFrom-Json
    $stamp.version = '0.83.0'
    [IO.File]::WriteAllText($stampPath, ($stamp | ConvertTo-Json -Depth 4), [Text.UTF8Encoding]::new($false))
    return $candidate
}

function New-LegacyGitHookTarget {
    $target = Join-Path ([IO.Path]::GetTempPath()) ('legacy-hook-target-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path (Join-Path $target '.claude/hooks'), (Join-Path $target 'scripts') | Out-Null
    [IO.File]::WriteAllText((Join-Path $target '.claude/framework-version.json'), '{"version":"0.82.0","template":"dotnet"}', [Text.UTF8Encoding]::new($false))
    $entries = @($legacyGitHookRetiredPaths | ForEach-Object { [pscustomobject]@{ path = $_; ownership = 'framework-owned/overwritten' } })
    $manifest = [ordered]@{ 'schema-version' = 1; paths = $entries }
    [IO.File]::WriteAllText((Join-Path $target 'framework-ownership.json'), ($manifest | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
    Write-LegacyGitHookHelperFixtures -Root $target
    Copy-Item -Force -LiteralPath (Join-Path $repoRoot 'dist/dotnet/.claude/hooks/guard.ps1') -Destination (Join-Path $target '.claude/hooks/guard.ps1')
    & git -C $target init -q
    Assert ($LASTEXITCODE -eq 0) 'could not initialize legacy Git-hook target'
    & git -C $target config user.name 'Installer Test'
    & git -C $target config user.email 'installer@example.invalid'
    & git -C $target add -- .
    & git -C $target commit -q -m 'fixture'
    Assert ($LASTEXITCODE -eq 0) 'could not commit legacy Git-hook target fixture'
    return $target
}

function Set-LegacyDefaultPreCommit {
    param([string]$Target, [string]$Content)
    $path = Join-Path $Target '.git/hooks/pre-commit'
    [IO.File]::WriteAllText($path, $Content, [Text.UTF8Encoding]::new($false))
    return $path
}

Reset-Tests

    It 'dry-run is byte-stable and its plan matches the convergent apply' {
        $target = New-LegacyRetirementTarget
        try {
            $before = Get-TreeFingerprint $target
            $dry = Invoke-CurrentInstaller -Target $target -DryRun
            Assert ($dry.Exit -eq 0) "dry-run exited $($dry.Exit): $($dry.Output)"
            Assert ((Get-TreeFingerprint $target) -ceq $before) 'dry-run changed target bytes'
            $apply = Invoke-CurrentInstaller -Target $target
            Assert ($apply.Exit -eq 0) "apply exited $($apply.Exit): $($apply.Output)"
            $dryPlan = @(($dry.Output -split "`r?`n") | Where-Object { $_ -match '^PLAN ' })
            $applyPlan = @(($apply.Output -split "`r?`n") | Where-Object { $_ -match '^PLAN ' })
            Assert (($dryPlan -join "`n") -ceq ($applyPlan -join "`n")) 'dry-run and apply emitted different operation sets'
            foreach ($relative in $retiredPaths) { Assert (-not (Test-Path -LiteralPath (Join-Path $target $relative))) "retired framework path survived: $relative" }
            Assert (@($applyPlan | Where-Object { $_ -match '^PLAN delete ' }).Count -eq 5) 'apply did not plan exactly the five authorized retirements'
        } finally { Remove-Item -Recurse -Force -LiteralPath $target -ErrorAction SilentlyContinue }
    }

    It 'consumer-modified and reparse retirement paths survive while verified bytes converge' {
        $target = New-LegacyRetirementTarget
        $outside = Join-Path ([IO.Path]::GetTempPath()) ('installer-outside-' + [guid]::NewGuid().ToString('N'))
        $link = Join-Path $target 'tests/impact'
        $outsideBefore = $null
        $bodyFailure = $null
        $cleanupFailure = $null
        $readEntry = {
            param([string]$Path)
            try { return Get-Item -Force -LiteralPath $Path -ErrorAction Stop }
            catch [System.Management.Automation.ItemNotFoundException] {
                $parent = [IO.Path]::GetDirectoryName($Path)
                $leaf = [IO.Path]::GetFileName($Path)
                $parentItem = Get-Item -Force -LiteralPath $parent -ErrorAction Stop
                if (-not $parentItem.PSIsContainer) { throw "fixture entry parent is not a directory: '$parent'" }
                $stored = @(Get-ChildItem -Force -LiteralPath $parentItem.FullName -ErrorAction Stop |
                    Where-Object { $_.Name -ceq $leaf })
                if ($stored.Count -gt 1) { throw "fixture entry lookup is ambiguous: '$Path'" }
                if ($stored.Count -eq 1) { return $stored[0] }
                return $null
            }
        }
        try {
            try {
                [IO.File]::WriteAllText((Join-Path $target 'scripts/impact-run.ps1'), 'CONSUMER CUSTOM RUNNER', [Text.UTF8Encoding]::new($false))
                New-Item -ItemType Directory -Force -Path $outside | Out-Null
                Move-Item -LiteralPath $link -Destination (Join-Path $outside 'impact')
                Assert (New-DirectoryLink -Link $link -Destination (Join-Path $outside 'impact')) 'could not construct retirement reparse fixture'
                $outsideBefore = Get-TreeFingerprint $outside
                $result = Invoke-CurrentInstaller -Target $target
                Assert ($result.Exit -eq 0) "safe reconciliation exited $($result.Exit): $($result.Output)"
                $linkAfter = & $readEntry $link
                $linkSurvived = $linkAfter -and ((($linkAfter.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) -or
                    ($linkAfter.PSObject.Properties['LinkType'] -and -not [string]::IsNullOrWhiteSpace([string]$linkAfter.LinkType)))
                Assert $linkSurvived 'installer removed or replaced the reparse retirement path'
                Assert ([IO.File]::ReadAllText((Join-Path $target 'scripts/impact-run.ps1')).Contains('CONSUMER CUSTOM RUNNER')) 'consumer-modified retired path was deleted or overwritten'
                Assert (-not (Test-Path -LiteralPath (Join-Path $target 'scripts/impact-run.sh'))) 'verified framework runner was not retired'
                Assert ((Get-TreeFingerprint $outside) -ceq $outsideBefore) 'reparse retirement changed out-of-root bytes'
                Assert ($result.Output -match 'consumer-modified or unknown content') 'custom-content preservation was not disclosed'
                Assert ($result.Output -match 'reparse/symlink') 'reparse preservation was not disclosed'
            } catch { $bodyFailure = $_ }
        } finally {
            try {
                $linkItem = & $readEntry $link
                if ($linkItem) {
                    $isLink = (($linkItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) -or
                        ($linkItem.PSObject.Properties['LinkType'] -and -not [string]::IsNullOrWhiteSpace([string]$linkItem.LinkType))
                    if (-not $isLink) { throw "fixture cleanup refused non-link entry '$($linkItem.FullName)'" }
                    if ($script:IsWindowsHost) {
                        [IO.Directory]::Delete($linkItem.FullName, $false)
                    } else {
                        Remove-Item -Force -LiteralPath $linkItem.FullName -ErrorAction Stop
                    }
                }
                if (& $readEntry $link) { throw "fixture cleanup left link '$link'" }
                if ($null -ne $outsideBefore) {
                    if (-not (& $readEntry $outside)) { throw "fixture cleanup lost outside root '$outside' before removal" }
                    if ((Get-TreeFingerprint $outside) -cne $outsideBefore) { throw 'fixture unlink changed out-of-root bytes' }
                }
                if (& $readEntry $target) { Remove-Item -Recurse -Force -LiteralPath $target -ErrorAction Stop }
                if (& $readEntry $outside) { Remove-Item -Recurse -Force -LiteralPath $outside -ErrorAction Stop }
                if (& $readEntry $target) { throw "fixture cleanup left target root '$target'" }
                if (& $readEntry $outside) { throw "fixture cleanup left outside root '$outside'" }
            } catch { $cleanupFailure = $_ }
        }
        if ($bodyFailure -and $cleanupFailure) {
            throw "BODY: $($bodyFailure.Exception.Message)`nCLEANUP: $($cleanupFailure.Exception.Message)"
        }
        if ($bodyFailure) { throw $bodyFailure }
        if ($cleanupFailure) { throw $cleanupFailure }
    }

    It 'a forged previous manifest enters additive compatibility and deletes nothing' {
        $target = New-LegacyRetirementTarget
        $outside = Join-Path ([IO.Path]::GetTempPath()) ('outside-sentinel-' + [guid]::NewGuid().ToString('N'))
        try {
            [IO.File]::WriteAllText((Join-Path $target 'consumer.txt'), 'CONSUMER SENTINEL', [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText($outside, 'OUTSIDE SENTINEL', [Text.UTF8Encoding]::new($false))
            $forged = @"
{
  "schema-version": 1,
  "paths": [
    { "path": "scripts/impact-run.ps1", "ownership": "framework-owned/overwritten" },
    { "path": "Scripts/Impact-Run.ps1", "ownership": "framework-owned/overwritten" },
    { "path": "../outside", "ownership": "framework-owned/overwritten" },
    { "path": "C:/outside", "ownership": "framework-owned/overwritten" },
    { "path": "consumer.txt", "ownership": "consumer-owned/protected" }
  ]
}
"@
            [IO.File]::WriteAllText((Join-Path $target 'framework-ownership.json'), $forged, [Text.UTF8Encoding]::new($false))
            $result = Invoke-CurrentInstaller -Target $target
            Assert ($result.Exit -eq 0) "additive compatibility install exited $($result.Exit): $($result.Output)"
            foreach ($relative in $retiredPaths) { Assert (Test-Path -LiteralPath (Join-Path $target $relative)) "forged manifest deleted $relative" }
            Assert ([IO.File]::ReadAllText((Join-Path $target 'consumer.txt')).Contains('CONSUMER SENTINEL')) 'consumer-owned sentinel changed'
            Assert ([IO.File]::ReadAllText($outside).Contains('OUTSIDE SENTINEL')) 'out-of-root sentinel changed'
            Assert ($result.Output -match 'CANT-VERIFY: previous framework-ownership.json is malformed or unsafe') 'additive compatibility was not explicit'
            Assert ($result.Output.Contains("duplicate path 'Scripts/Impact-Run.ps1'")) 'ASCII case-variant duplicate was not the decisive manifest failure'
        } finally {
            Remove-Item -Recurse -Force -LiteralPath $target -ErrorAction SilentlyContinue
            Remove-Item -Force -LiteralPath $outside -ErrorAction SilentlyContinue
        }
    }

    It 'retires only qualified mirror leaves, never recreates mirrors, and keeps residual warnings durable' {
        $candidate = New-B217CandidateSource
        $target = New-B217ResidualTarget -StockPath $candidate.Stock
        try {
            $first = Invoke-CurrentInstaller -Target $target -SourceRoot $candidate.Root
            Assert ($first.Exit -eq 0) "B-217 first update exited $($first.Exit): $($first.Output)"
            Assert (-not (Test-Path -LiteralPath (Join-Path $target $candidate.Stock))) "known stock mirror leaf was not retired: $($first.Output)"
            Assert ((Get-Content -LiteralPath (Join-Path $target '.github/skills/perf/modified.md') -Raw) -match 'CONSUMER-MODIFIED') 'modified mirror leaf was deleted or overwritten'
            Assert ((Get-Content -LiteralPath (Join-Path $target '.github/skills/local-only/SKILL.md') -Raw) -match 'UNKNOWN GITHUB-ONLY') 'unknown GitHub-only skill was deleted or overwritten'
            Assert ((Get-Content -LiteralPath (Join-Path $target 'scripts/sync-agent-files.ps1') -Raw) -match 'CONSUMER-MODIFIED') 'modified sync script was deleted or overwritten'
            Assert ($first.Output -match "CANT-VERIFY: retired path '\.github/skills/perf/modified\.md' has consumer-modified or unknown content") 'modified mirror preservation lacked CANT-VERIFY'
            Assert ($first.Output -match "CANT-VERIFY: retained retired path 'scripts/sync-agent-files\.ps1'.*may recreate") 'modified sync-script shadow risk lacked an exact-path warning'
            Assert (@(($first.Output -split "`r?`n") | Where-Object { $_ -match '^PLAN (?:create|replace) \.github/skills/' }).Count -eq 0) 'installer recreated a GitHub skill mirror'
            Assert (-not (Test-Path -LiteralPath (Join-Path $target '.github/skills/add-warehouse-load/SKILL.md'))) 'installer wrote a canonical skill into the retired GitHub path'

            & (Get-PsExe) -NoProfile -File (Join-Path $target 'scripts/sync-agent-files.ps1') -Target $target
            Assert ($LASTEXITCODE -eq 0) 'test-owned modified sync script did not run outside the installer'
            Assert ((Get-Content -LiteralPath (Join-Path $target $candidate.Stock) -Raw) -match 'RECREATED BY CONSUMER') 'modified sync script did not recreate the retired higher-priority mirror'

            $second = Invoke-CurrentInstaller -Target $target -SourceRoot $candidate.Root
            Assert ($second.Exit -eq 0) "B-217 subsequent update exited $($second.Exit): $($second.Output)"
            Assert ($second.Output -match "CANT-VERIFY: retained retired path 'scripts/sync-agent-files\.ps1'.*may recreate") 'sync-script warning disappeared after the new ownership manifest arrived'
            Assert ($second.Output -match "CANT-VERIFY: retained retired path '\.github/skills/perf/SKILL\.md'.*may shadow") 'recreated mirror warning disappeared after the new ownership manifest arrived'
            Assert ((Get-Content -LiteralPath (Join-Path $target 'scripts/sync-agent-files.ps1') -Raw) -match 'CONSUMER-MODIFIED') 'later update deleted the modified sync script'
            Assert ((Get-Content -LiteralPath (Join-Path $target $candidate.Stock) -Raw) -match 'RECREATED BY CONSUMER') 'later update deleted or overwrote the recreated consumer mirror'
        } finally {
            Remove-Item -Recurse -Force -LiteralPath $target -ErrorAction SilentlyContinue
            Remove-Item -Recurse -Force -LiteralPath $candidate.Root -ErrorAction SilentlyContinue
        }
    }

    It 'distinguishes an uninspectable retained retirement from an absent path' {
        $candidate = New-B217CandidateSource
        $target = New-B217ResidualTarget -StockPath $candidate.Stock
        $savedPsFailure = $env:B217_UNREADABLE_PATH
        try {
            $retainedPath = 'scripts/sync-agent-files.ps1'
            $retained = Join-Path $target $retainedPath
                $installerPath = Join-Path $candidate.Root 'scripts/install.ps1'
                $installer = [IO.File]::ReadAllText($installerPath)
                $needle = "`$ErrorActionPreference = 'Stop'"
                Assert ($installer.Contains($needle)) 'could not locate the PowerShell inspection-failure injection point'
                $mock = @'
function Get-Item {
    [CmdletBinding()]
    param([string]$LiteralPath, [string]$Path, [switch]$Force)
    $selected = if ($PSBoundParameters.ContainsKey('LiteralPath')) { $LiteralPath } else { $Path }
    if ($selected -eq $env:B217_UNREADABLE_PATH) {
        throw [UnauthorizedAccessException]::new('planted retained-path inspection failure')
    }
    Microsoft.PowerShell.Management\Get-Item @PSBoundParameters
}
'@
                $installer = $installer.Replace($needle, $needle + "`r`n" + $mock)
                [IO.File]::WriteAllText($installerPath, $installer, [Text.UTF8Encoding]::new($true))
                $env:B217_UNREADABLE_PATH = $retained

            $before = (Get-FileHash -LiteralPath $retained -Algorithm SHA256).Hash
            $result = Invoke-CurrentInstaller -Target $target -SourceRoot $candidate.Root
            Assert ($result.Exit -eq 0) "inspection-failure update exited $($result.Exit): $($result.Output)"
            Assert ($result.Output -match "CANT-VERIFY: retained retired path 'scripts/sync-agent-files\.ps1' could not be examined") 'inspection failure was silently treated as absence'
            Assert ((Get-FileHash -LiteralPath $retained -Algorithm SHA256).Hash -ceq $before) 'uninspectable retained path changed'
        } finally {
            if ($null -eq $savedPsFailure) { Remove-Item Env:B217_UNREADABLE_PATH -ErrorAction SilentlyContinue }
            else { $env:B217_UNREADABLE_PATH = $savedPsFailure }
            Remove-Item -Recurse -Force -LiteralPath $target, $candidate.Root -ErrorAction SilentlyContinue
        }
    }

    It 'preserves pre-manifest and malformed-manifest mirrors with durable manual-migration warnings' {
        $candidate = New-B217CandidateSource
        try {
            foreach ($shape in @('missing', 'malformed')) {
                $target = New-B217LegacyManifestTarget -StockPath $candidate.Stock -ManifestShape $shape
                try {
                    $before = (Get-FileHash -LiteralPath (Join-Path $target $candidate.Stock) -Algorithm SHA256).Hash
                    $first = Invoke-CurrentInstaller -Target $target -SourceRoot $candidate.Root
                    Assert ($first.Exit -eq 0) "B-217 $shape-manifest update exited $($first.Exit): $($first.Output)"
                    Assert (Test-Path -LiteralPath (Join-Path $target $candidate.Stock) -PathType Leaf) "$shape-manifest update deleted the unqualified stock mirror"
                    Assert ((Get-FileHash -LiteralPath (Join-Path $target $candidate.Stock) -Algorithm SHA256).Hash -ceq $before) "$shape-manifest update changed the unqualified stock mirror"
                    Assert (@(($first.Output -split "`r?`n") | Where-Object { $_ -eq "PLAN delete $($candidate.Stock)" }).Count -eq 0) "$shape-manifest update planned an unauthorized stock deletion"
                    Assert ($first.Output -match "CANT-VERIFY: previous framework-ownership\.json is $shape") "$shape-manifest update did not name the lost deletion authority"
                    Assert ($first.Output -match "CANT-VERIFY: retained retired path '\.github/skills/perf/SKILL\.md'.*may shadow") "$shape-manifest update lacked the exact manual-migration warning"

                    $second = Invoke-CurrentInstaller -Target $target -SourceRoot $candidate.Root
                    Assert ($second.Exit -eq 0) "B-217 later $shape-manifest update exited $($second.Exit): $($second.Output)"
                    Assert ((Get-FileHash -LiteralPath (Join-Path $target $candidate.Stock) -Algorithm SHA256).Hash -ceq $before) "later $shape-manifest update changed the preserved mirror"
                    Assert ($second.Output -match "CANT-VERIFY: retained retired path '\.github/skills/perf/SKILL\.md'.*may shadow") "later $shape-manifest update lost the durable exact-path warning"
                } finally {
                    Remove-Item -Recurse -Force -LiteralPath $target -ErrorAction SilentlyContinue
                }
            }
        } finally {
            Remove-Item -Recurse -Force -LiteralPath $candidate.Root -ErrorAction SilentlyContinue
        }
    }

    It 'downgrade refusal is pre-mutation and the deliberate override is observable' {
        $target = New-LegacyRetirementTarget
        try {
            [IO.File]::WriteAllText((Join-Path $target '.claude/framework-version.json'), '{"version":"99.0.0","template":"dotnet"}', [Text.UTF8Encoding]::new($false))
            $before = Get-TreeFingerprint $target
            $refused = Invoke-CurrentInstaller -Target $target
            Assert ($refused.Exit -eq 4) "downgrade refusal exited $($refused.Exit), expected 4: $($refused.Output)"
            Assert ($refused.Output -match 'Refusing framework downgrade') 'downgrade refusal was not actionable'
            Assert ((Get-TreeFingerprint $target) -ceq $before) 'downgrade refusal changed target bytes'
            $allowed = Invoke-CurrentInstaller -Target $target -DryRun -AllowDowngrade
            Assert ($allowed.Exit -eq 0) "allowed downgrade dry-run exited $($allowed.Exit): $($allowed.Output)"
            Assert ($allowed.Output -match 'allow-downgrade accepted|AllowDowngrade accepted') 'downgrade override was not observable'
            Assert ((Get-TreeFingerprint $target) -ceq $before) 'allowed downgrade dry-run changed target bytes'
        } finally { Remove-Item -Recurse -Force -LiteralPath $target -ErrorAction SilentlyContinue }
    }

    It 'the rich update plan accounts for every observable skill and backup mutation' {
        $target = New-RichUpdateTarget
        try {
            $before = Get-FileState $target
            $discoveredBefore = $before['.claude/skills/local-release/SKILL.md']
            $unknownBefore = $before['.claude/skills/consumer-local/SKILL.md']
            $legacyDiscoveredBefore = $before['.github/skills/local-release/SKILL.md']
            $legacyDisabledBefore = $before['.github/skills/perf/SKILL.md']
            $dry = Invoke-CurrentInstaller -Target $target -DryRun
            Assert ($dry.Exit -eq 0) "rich dry-run exited $($dry.Exit): $($dry.Output)"
            $dryPlan = @(($dry.Output -split "`r?`n") | Where-Object { $_ -match '^PLAN ' })
            Assert ($dryPlan -contains 'PLAN create .claude/framework-update-backup/skills/local-release/SKILL.md') 'skill backup leaf was hidden behind an opaque directory plan'
            Assert (@($dryPlan | Where-Object { $_ -match '^PLAN (create|replace) \.claude/disabled-skills/perf/SKILL\.md$' }).Count -eq 1) 'disabled-skill destination was absent or contradictory'
            Assert ($dryPlan -contains 'PLAN delete .claude/skills/perf') 'disabled active skill deletion was not planned'
            Assert (@($dryPlan | Where-Object { $_ -match '^PLAN (create|replace) \.claude/skills/perf/' }).Count -eq 0) 'plan claimed the disabled skill would remain active'
            Assert (@($dryPlan | Where-Object { $_ -match '^PLAN (?:create|replace|delete) \.github/skills(?:/|$)' }).Count -eq 0) 'retired GitHub skill tree still had installer mutation plans'
            Assert ($dry.Output -match "CANT-VERIFY: retained retired path '\.github/skills/perf/SKILL\.md'.*may shadow") 'modified disabled mirror lacked a durable exact-path warning'

            $apply = Invoke-CurrentInstaller -Target $target
            Assert ($apply.Exit -eq 0) "rich apply exited $($apply.Exit): $($apply.Output)"
            $applyPlan = @(($apply.Output -split "`r?`n") | Where-Object { $_ -match '^PLAN ' })
            Assert (($dryPlan -join "`n") -ceq ($applyPlan -join "`n")) 'rich dry-run and apply plans differed'
            $after = Get-FileState $target
            $changed = New-Object System.Collections.Generic.List[string]
            foreach ($relative in @($before.Keys + $after.Keys | Sort-Object -Unique)) {
                if (-not $before.ContainsKey($relative) -or -not $after.ContainsKey($relative) -or $before[$relative] -cne $after[$relative]) { $changed.Add($relative) }
            }
            $writePlan = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
            $deleteRoots = New-Object System.Collections.Generic.List[string]
            foreach ($line in $applyPlan) {
                if ($line -match '^PLAN (?:create|replace) (.+)$') { [void]$writePlan.Add($Matches[1]) }
                elseif ($line -match '^PLAN delete (.+)$') { $deleteRoots.Add($Matches[1]) }
            }
            foreach ($relative in $changed) {
                $coveredByDelete = @($deleteRoots | Where-Object { $relative -eq $_ -or $relative.StartsWith($_ + '/', [StringComparison]::Ordinal) }).Count -gt 0
                Assert ($writePlan.Contains($relative) -or $coveredByDelete) "actual mutation was absent from the plan: $relative"
            }
            Assert ($after['.claude/skills/local-release/SKILL.md'] -ceq $discoveredBefore) 'discovered Claude skill changed'
            Assert ($after['.github/skills/local-release/SKILL.md'] -ceq $legacyDiscoveredBefore) 'unknown GitHub-only skill bytes changed'
            Assert ($after['.claude/skills/consumer-local/SKILL.md'] -ceq $unknownBefore) 'unknown consumer skill bytes changed during exemplar carry-forward'
            Assert (-not $after.ContainsKey('.github/skills/consumer-local/SKILL.md')) 'installer created a GitHub mirror for a canonical consumer skill'
            $frameworkSkill = Get-Content -LiteralPath (Join-Path $target '.claude/skills/add-warehouse-load/SKILL.md') -Raw
            Assert ($frameworkSkill -notmatch 'OLD BODY') 'framework skill was not refreshed before carrying its exemplar forward'
            Assert ($frameworkSkill -match [regex]::Escape('For a concrete current instance in this repo, see `warehouse/LoadSales.sql`.')) 'framework skill lost its prior exemplar'
            Assert (-not $after.ContainsKey('.claude/skills/perf/SKILL.md')) 'disabled skill remained active'
            Assert ($after['.github/skills/perf/SKILL.md'] -ceq $legacyDisabledBefore) 'consumer-modified legacy GitHub skill was deleted or overwritten'
        } finally { Remove-Item -Recurse -Force -LiteralPath $target -ErrorAction SilentlyContinue }
    }

    It 'installer-owned side-write parents refuse reparse escape before mutation' {
        foreach ($relative in @('.claude/.state', '.claude/framework-update-backup', '.claude/disabled-skills')) {
            $target = New-RichUpdateTarget
            $outside = Join-Path ([IO.Path]::GetTempPath()) ('installer-side-outside-' + [guid]::NewGuid().ToString('N'))
            try {
                New-Item -ItemType Directory -Force -Path $outside | Out-Null
                $link = Join-Path $target $relative
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $link) | Out-Null
                Assert (New-DirectoryLink -Link $link -Destination $outside) "could not create side-write reparse fixture at $relative"
                $targetBefore = Get-TreeFingerprint $target
                $outsideBefore = Get-TreeFingerprint $outside
                $result = Invoke-CurrentInstaller -Target $target
                Assert ($result.Exit -eq 3) "$relative reparse refusal exited $($result.Exit), expected 3: $($result.Output)"
                Assert ($result.Output -match 'reparse/symlink|physical parent escapes') "$relative refusal did not name the containment boundary"
                Assert ((Get-TreeFingerprint $target) -ceq $targetBefore) "$relative refusal changed target bytes"
                Assert ((Get-TreeFingerprint $outside) -ceq $outsideBefore) "$relative refusal changed out-of-root bytes"
            } finally {
                $linkItem = Get-Item -Force -LiteralPath (Join-Path $target $relative) -ErrorAction SilentlyContinue
                if ($linkItem -and (($linkItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { Remove-Item -Force -LiteralPath $linkItem.FullName -ErrorAction SilentlyContinue }
                Remove-Item -Recurse -Force -LiteralPath $target -ErrorAction SilentlyContinue
                Remove-Item -Recurse -Force -LiteralPath $outside -ErrorAction SilentlyContinue
            }
        }
    }
It 'PowerShell legacy pre-commit is untouched and keeps only its retired dependency' {
    $candidate = New-LegacyGitHookCandidateSource
    $target = New-LegacyGitHookTarget
    try {
        $hook = Set-LegacyDefaultPreCommit -Target $target -Content $legacyPowerShellPreCommit
        $hookBefore = (Get-FileHash -LiteralPath $hook -Algorithm SHA256).Hash
        $dry = Invoke-CurrentInstaller -Target $target -SourceRoot $candidate -DryRun
        Assert ($dry.Exit -eq 0) "legacy PowerShell dry-run exited $($dry.Exit): $($dry.Output)"
        $apply = Invoke-CurrentInstaller -Target $target -SourceRoot $candidate
        Assert ($apply.Exit -eq 0) "legacy PowerShell apply exited $($apply.Exit): $($apply.Output)"
        $dryMigration = @(($dry.Output -split "`r?`n") | Where-Object { $_ -match '^(?:PLAN |  CANT-VERIFY:|  NOTICE:|  MIGRATION:)' })
        $applyMigration = @(($apply.Output -split "`r?`n") | Where-Object { $_ -match '^(?:PLAN |  CANT-VERIFY:|  NOTICE:|  MIGRATION:)' })
        Assert (($dryMigration -join "`n") -ceq ($applyMigration -join "`n")) 'WhatIf and apply classified legacy PowerShell state differently'
        Assert ((Get-FileHash -LiteralPath $hook -Algorithm SHA256).Hash -ceq $hookBefore) 'installer changed consumer-owned pre-commit bytes'
        Assert (Test-Path -LiteralPath (Join-Path $target 'scripts/setup-git-hooks.ps1') -PathType Leaf) 'PowerShell hook dependency was retired'
        Assert (-not (Test-Path -LiteralPath (Join-Path $target 'scripts/setup-git-hooks.sh'))) 'unneeded Bash setup helper survived'
        Assert (-not (Test-Path -LiteralPath (Join-Path $target '.claude/hooks/guard.sh'))) 'unneeded Bash guard survived'
        Assert ($apply.Output -match 'PLAN preserve scripts/setup-git-hooks\.ps1') 'preserved dependency was absent from operation plan'
        Assert ($apply.Output -notmatch 'PLAN (?:replace|delete) \.git/hooks/pre-commit') 'consumer-owned hook entered a mutation plan'

        & git -C $target add -- .
        & git -C $target commit -q -m 'preserved PowerShell hook remains runnable'
        Assert ($LASTEXITCODE -eq 0) 'the preserved PowerShell legacy hook prevented a post-upgrade commit'

        $second = Invoke-CurrentInstaller -Target $target -SourceRoot $candidate
        Assert ($second.Exit -eq 0) "second legacy PowerShell update exited $($second.Exit): $($second.Output)"
        Assert ($second.Output -match "retained retired Git-hook helper 'scripts/setup-git-hooks\.ps1'") 'helper warning disappeared after ownership authority rolled forward'
        Assert (Test-Path -LiteralPath (Join-Path $target 'scripts/setup-git-hooks.ps1') -PathType Leaf) 'second update deleted the preserved helper'
    } finally {
        Remove-Item -Recurse -Force -LiteralPath $target, $candidate -ErrorAction SilentlyContinue
    }
}

It 'Bash legacy pre-commit keeps both retired Bash helpers and is marked degraded' {
    $candidate = New-LegacyGitHookCandidateSource
    $target = New-LegacyGitHookTarget
    try {
        $hook = Set-LegacyDefaultPreCommit -Target $target -Content $legacyBashPreCommit
        $hookBefore = (Get-FileHash -LiteralPath $hook -Algorithm SHA256).Hash
        $apply = Invoke-CurrentInstaller -Target $target -SourceRoot $candidate
        Assert ($apply.Exit -eq 0) "legacy Bash apply exited $($apply.Exit): $($apply.Output)"
        Assert ((Get-FileHash -LiteralPath $hook -Algorithm SHA256).Hash -ceq $hookBefore) 'installer changed Bash pre-commit bytes'
        Assert (-not (Test-Path -LiteralPath (Join-Path $target 'scripts/setup-git-hooks.ps1'))) 'unneeded PowerShell setup helper survived'
        Assert (Test-Path -LiteralPath (Join-Path $target 'scripts/setup-git-hooks.sh') -PathType Leaf) 'Bash setup dependency was retired'
        Assert (Test-Path -LiteralPath (Join-Path $target '.claude/hooks/guard.sh') -PathType Leaf) 'Bash guard dependency was retired'
        Assert ($apply.Output -match 'Bash/degraded and unmaintained legacy pre-commit') 'Bash hook was not reported as degraded and unmaintained'
        Assert ($apply.Output -match 'PLAN preserve \.claude/hooks/guard\.sh') 'Bash guard preservation was absent from plan'
        Assert ($apply.Output -match 'PLAN preserve scripts/setup-git-hooks\.sh') 'Bash setup preservation was absent from plan'
        & git -C $target add -- .
        & git -C $target commit -q -m 'preserved Bash hook remains runnable'
        Assert ($LASTEXITCODE -eq 0) 'the preserved Bash legacy hook prevented a post-upgrade commit'
    } finally {
        Remove-Item -Recurse -Force -LiteralPath $target, $candidate -ErrorAction SilentlyContinue
    }
}

It 'modified legacy pre-commit is recognized by its exact retired helper reference' {
    $candidate = New-LegacyGitHookCandidateSource
    $target = New-LegacyGitHookTarget
    try {
        $modifiedHook = $legacyPowerShellPreCommit + "`n# consumer-added note changes the historical digest`n"
        $hook = Set-LegacyDefaultPreCommit -Target $target -Content $modifiedHook
        Assert ((Get-FileHash -LiteralPath $hook -Algorithm SHA256).Hash.ToLowerInvariant() -cne '56d2a687f489ffd95519dc56a34179526b175cc56d3b770cb45c0f243fabba1c') 'modified-hook fixture accidentally retained the historical digest'
        $apply = Invoke-CurrentInstaller -Target $target -SourceRoot $candidate
        Assert ($apply.Exit -eq 0) "modified legacy-hook apply exited $($apply.Exit): $($apply.Output)"
        Assert (Test-Path -LiteralPath (Join-Path $target 'scripts/setup-git-hooks.ps1') -PathType Leaf) 'modified legacy hook lost its referenced helper'
        Assert ($apply.Output -match 'PowerShell legacy pre-commit references retired framework helpers') 'modified helper reference was not classified as legacy'
        Assert ([IO.File]::ReadAllText($hook) -ceq $modifiedHook) 'installer changed the modified consumer-owned hook'
    } finally {
        Remove-Item -Recurse -Force -LiteralPath $target, $candidate -ErrorAction SilentlyContinue
    }
}

It 'unreadable default hook is CANT-VERIFY and preserves every possible retired dependency' {
    $candidate = New-LegacyGitHookCandidateSource
    $target = New-LegacyGitHookTarget
    $lock = $null
    try {
        $hook = Set-LegacyDefaultPreCommit -Target $target -Content $legacyPowerShellPreCommit
        $before = (Get-FileHash -LiteralPath $hook -Algorithm SHA256).Hash
        $lock = [IO.File]::Open($hook, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
        $dry = Invoke-CurrentInstaller -Target $target -SourceRoot $candidate -DryRun
        Assert ($dry.Exit -eq 0) "unreadable-hook dry-run exited $($dry.Exit): $($dry.Output)"
        $apply = Invoke-CurrentInstaller -Target $target -SourceRoot $candidate
        Assert ($apply.Exit -eq 0) "unreadable-hook apply exited $($apply.Exit): $($apply.Output)"
        Assert ($dry.Output -match 'default pre-commit hook could not be read as UTF-8 text') 'dry-run did not distinguish unreadable hook state'
        Assert ($apply.Output -match 'default pre-commit hook could not be read as UTF-8 text') 'apply did not distinguish unreadable hook state'
        foreach ($relative in $legacyGitHookRetiredPaths) { Assert (Test-Path -LiteralPath (Join-Path $target $relative) -PathType Leaf) "unreadable hook did not preserve $relative" }
        $lock.Dispose(); $lock = $null
        Assert ((Get-FileHash -LiteralPath $hook -Algorithm SHA256).Hash -ceq $before) 'installer changed the unreadable consumer-owned hook'
    } finally {
        if ($lock) { $lock.Dispose() }
        Remove-Item -Recurse -Force -LiteralPath $target, $candidate -ErrorAction SilentlyContinue
    }
}

It 'unrelated custom pre-commit is untouched and does not retain obsolete helpers' {
    $candidate = New-LegacyGitHookCandidateSource
    $target = New-LegacyGitHookTarget
    try {
        $hook = Set-LegacyDefaultPreCommit -Target $target -Content "#!/bin/sh`necho consumer hook`n"
        $hookBefore = [IO.File]::ReadAllBytes($hook)
        $apply = Invoke-CurrentInstaller -Target $target -SourceRoot $candidate
        Assert ($apply.Exit -eq 0) "custom-hook apply exited $($apply.Exit): $($apply.Output)"
        Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($hook)) -ceq [Convert]::ToBase64String($hookBefore)) 'custom pre-commit bytes changed'
        foreach ($relative in $legacyGitHookRetiredPaths) { Assert (-not (Test-Path -LiteralPath (Join-Path $target $relative))) "unneeded retired helper survived: $relative" }
        Assert ($apply.Output -match 'NOTICE: an unrelated custom default pre-commit hook exists') 'custom hook was not reported'
    } finally {
        Remove-Item -Recurse -Force -LiteralPath $target, $candidate -ErrorAction SilentlyContinue
    }
}

It 'custom hook routing is not followed and conservatively preserves possible dependencies' {
    $candidate = New-LegacyGitHookCandidateSource
    $target = New-LegacyGitHookTarget
    $outside = Join-Path ([IO.Path]::GetTempPath()) ('external-hooks-' + [guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Force -Path $outside | Out-Null
        $outsideHook = Join-Path $outside 'pre-commit'
        [IO.File]::WriteAllText($outsideHook, 'EXTERNAL SENTINEL', [Text.UTF8Encoding]::new($false))
        & git -C $target config core.hooksPath $outside
        Assert ($LASTEXITCODE -eq 0) 'could not configure external hooks path'
        $before = (Get-FileHash -LiteralPath $outsideHook -Algorithm SHA256).Hash
        $apply = Invoke-CurrentInstaller -Target $target -SourceRoot $candidate
        Assert ($apply.Exit -eq 0) "custom-routing apply exited $($apply.Exit): $($apply.Output)"
        Assert ((Get-FileHash -LiteralPath $outsideHook -Algorithm SHA256).Hash -ceq $before) 'installer followed or changed external hook bytes'
        foreach ($relative in $legacyGitHookRetiredPaths) { Assert (Test-Path -LiteralPath (Join-Path $target $relative) -PathType Leaf) "ambiguous routing did not preserve $relative" }
        Assert ($apply.Output -match 'core\.hooksPath.*was not inspected or modified') 'custom routing boundary was not disclosed'
    } finally {
        Remove-Item -Recurse -Force -LiteralPath $target, $candidate, $outside -ErrorAction SilentlyContinue
    }
}

It 'reparse Git metadata is report-only and its external hook is never inspected or changed' {
    $candidate = New-LegacyGitHookCandidateSource
    $target = New-LegacyGitHookTarget
    $outside = Join-Path ([IO.Path]::GetTempPath()) ('external-git-dir-' + [guid]::NewGuid().ToString('N'))
    $gitLink = Join-Path $target '.git'
    try {
        New-Item -ItemType Directory -Force -Path $outside | Out-Null
        $externalGitDirectory = Join-Path $outside 'gitdir'
        Move-Item -LiteralPath $gitLink -Destination $externalGitDirectory
        Assert (New-DirectoryLink -Link $gitLink -Destination $externalGitDirectory) 'could not construct reparse Git metadata fixture'
        $outsideHook = Join-Path $externalGitDirectory 'hooks/pre-commit'
        [IO.File]::WriteAllText($outsideHook, $legacyPowerShellPreCommit, [Text.UTF8Encoding]::new($false))
        $before = (Get-FileHash -LiteralPath $outsideHook -Algorithm SHA256).Hash

        $apply = Invoke-CurrentInstaller -Target $target -SourceRoot $candidate
        Assert ($apply.Exit -eq 0) "reparse-Git update exited $($apply.Exit): $($apply.Output)"
        Assert ($apply.Output -match 'Git metadata is linked, external, or non-directory state; no hook path was followed or modified') 'reparse Git metadata was not classified as report-only'
        Assert ($apply.Output -notmatch 'PowerShell legacy pre-commit references retired framework helpers') 'installer followed and classified the external hook'
        Assert ((Get-FileHash -LiteralPath $outsideHook -Algorithm SHA256).Hash -ceq $before) 'installer changed the external hook'
        foreach ($relative in $legacyGitHookRetiredPaths) { Assert (Test-Path -LiteralPath (Join-Path $target $relative) -PathType Leaf) "reparse metadata did not conservatively preserve $relative" }
    } finally {
        try {
            $linkEntry = Get-Item -Force -LiteralPath $gitLink -ErrorAction Stop
            Assert (($linkEntry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) 'cleanup refused a non-reparse .git entry'
            [IO.Directory]::Delete($gitLink, $false)
        } catch [Management.Automation.ItemNotFoundException] { }
        Remove-Item -Recurse -Force -LiteralPath $target, $candidate, $outside -ErrorAction SilentlyContinue
    }
}

It 'protected stale command reporting is byte-stable and identical in WhatIf and apply' {
    $candidate = New-LegacyGitHookCandidateSource
    $target = New-LegacyGitHookTarget
    try {
        [IO.File]::WriteAllText((Join-Path $target 'CLAUDE.md'), "Run bash scripts/setup-git-hooks.sh --scan.`n", [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $target 'bitbucket-pipelines.yml'), "script: ./scripts/setup-git-hooks.sh --scan`n", [Text.UTF8Encoding]::new($false))
        & git -C $target add -- CLAUDE.md bitbucket-pipelines.yml
        & git -C $target commit -q -m 'stale protected commands'
        Assert ($LASTEXITCODE -eq 0) 'could not commit protected-reference fixture'
        $claudeBefore = (Get-FileHash -LiteralPath (Join-Path $target 'CLAUDE.md') -Algorithm SHA256).Hash
        $ciBefore = (Get-FileHash -LiteralPath (Join-Path $target 'bitbucket-pipelines.yml') -Algorithm SHA256).Hash
        $dry = Invoke-CurrentInstaller -Target $target -SourceRoot $candidate -DryRun
        Assert ($dry.Exit -eq 0) "protected-reference dry-run exited $($dry.Exit): $($dry.Output)"
        $apply = Invoke-CurrentInstaller -Target $target -SourceRoot $candidate
        Assert ($apply.Exit -eq 0) "protected-reference apply exited $($apply.Exit): $($apply.Output)"
        $dryMessages = @(($dry.Output -split "`r?`n") | Where-Object { $_ -match '^  MIGRATION:' })
        $applyMessages = @(($apply.Output -split "`r?`n") | Where-Object { $_ -match '^  MIGRATION:' })
        Assert ($dryMessages.Count -eq 2) "expected two protected-reference messages, got $($dryMessages.Count): $($dry.Output)"
        Assert (($dryMessages -join "`n") -ceq ($applyMessages -join "`n")) 'WhatIf and apply stale-command classifications differ'
        Assert ((Get-FileHash -LiteralPath (Join-Path $target 'CLAUDE.md') -Algorithm SHA256).Hash -ceq $claudeBefore) 'protected CLAUDE.md was overwritten'
        Assert ((Get-FileHash -LiteralPath (Join-Path $target 'bitbucket-pipelines.yml') -Algorithm SHA256).Hash -ceq $ciBefore) 'consumer CI carrier was overwritten'

        $futureStampPath = Join-Path $candidate '.claude/framework-version.json'
        $futureStamp = Get-Content -Raw -LiteralPath $futureStampPath | ConvertFrom-Json
        $futureStamp.version = '0.84.0'
        [IO.File]::WriteAllText($futureStampPath, ($futureStamp | ConvertTo-Json -Depth 4), [Text.UTF8Encoding]::new($false))
        $later = Invoke-CurrentInstaller -Target $target -SourceRoot $candidate -AllowDirtyTree
        Assert ($later.Exit -eq 0) "later-release protected-reference update exited $($later.Exit): $($later.Output)"
        $laterMigrations = @(($later.Output -split "`r?`n") | Where-Object { $_ -match '^  MIGRATION:' })
        Assert (@($laterMigrations | Where-Object { $_ -match "carrier 'CLAUDE\.md'.*'scripts/setup-git-hooks\.sh'" }).Count -eq 1) "CLAUDE.md retired-command diagnostic disappeared after its retirement release: $($later.Output)"
        Assert (@($laterMigrations | Where-Object { $_ -match "carrier 'bitbucket-pipelines\.yml'.*'scripts/setup-git-hooks\.sh'" }).Count -eq 1) "Bitbucket retired-command diagnostic disappeared after its retirement release: $($later.Output)"
    } finally {
        Remove-Item -Recurse -Force -LiteralPath $target, $candidate -ErrorAction SilentlyContinue
    }
}

exit (Write-TestSummary 'InstallerConvergence.Tests')
