# High-value destructive-boundary coverage for convergent installer updates. This replaces the
# retired runner's argument/permutation suite: once the runner is gone, the meaningful contract is
# whether an old installation converges without deleting consumer or out-of-root bytes.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$bash = Get-BashPath
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
    param([string]$Twin, [string]$Target, [string]$SourceRoot, [switch]$DryRun, [switch]$AllowDowngrade)
    $root = if ($SourceRoot) { $SourceRoot } else { Join-Path $repoRoot 'dist/dotnet' }
    $installer = Join-Path $root "scripts/install.$Twin"
    if ($Twin -eq 'ps1') {
        $arguments = @('-NoProfile','-File',$installer,'-Target',$Target)
        if ($DryRun) { $arguments += '-WhatIf' }
        if ($AllowDowngrade) { $arguments += '-AllowDowngrade' }
        $output = & (Get-PsExe) @arguments 2>&1 | Out-String
    } else {
        $arguments = @($installer)
        if ($DryRun) { $arguments += '--dry-run' }
        if ($AllowDowngrade) { $arguments += '--allow-downgrade' }
        $arguments += ($Target -replace '\\', '/')
        $output = & $bash @arguments 2>&1 | Out-String
    }
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
    Copy-Item -LiteralPath (Join-Path $repoRoot 'src/core/scripts/install.sh') -Destination (Join-Path $candidate 'scripts/install.sh') -Force

    $ownershipPath = Join-Path $candidate 'framework-ownership.json'
    $ownershipLines = Get-Content -LiteralPath $ownershipPath | Where-Object { $_ -notmatch '"path": "\.github/skills/' -and $_ -notmatch '"path": "scripts/sync-agent-files\.' }
    [IO.File]::WriteAllLines($ownershipPath, [string[]]$ownershipLines, [Text.UTF8Encoding]::new($false))

    $stock = '.github/skills/perf/SKILL.md'
    $ledgerPath = Join-Path $candidate 'framework-retirements.json'
    Copy-Item -LiteralPath (Join-Path $repoRoot 'src/core/framework-retirements.json') -Destination $ledgerPath -Force
    $ledger = Get-Content -LiteralPath $ledgerPath -Raw
    Assert ($ledger -match [regex]::Escape(('"path": "' + $stock + '"'))) "B-217 source retirement ledger does not name the stock mirror leaf $stock"
    Assert ($ledger -match '"path": "scripts/sync-agent-files\.ps1"') 'B-217 source retirement ledger does not name sync-agent-files.ps1'
    $futureRows = '    { "path": ".github/skills/perf/modified.md", "retired-in": "0.82.0", "known-content-sha256": ["a3f4826b6bdf6da3ff876197e4bc386a6a4e66c0bd3c79d90c6bdc29a6de88f1"] }'
    $ledger = $ledger.TrimEnd() -replace '\r?\n  \]\r?\n\}$', ''
    $ledger = $ledger + ",`n" + $futureRows + "`n  ]`n}`n"
    [IO.File]::WriteAllText($ledgerPath, $ledger, [Text.UTF8Encoding]::new($false))
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
    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        & cmd /c mklink /J $Link $Destination *> $null
    } else {
        & ln -s $Destination $Link
    }
    return ($LASTEXITCODE -eq 0 -or (Test-Path -LiteralPath $Link))
}

Reset-Tests

foreach ($twin in @('ps1','sh')) {
    if ($twin -eq 'sh' -and -not $bash) { Skip "installer convergence ($twin)" 'no bash on this host'; continue }

    It "dry-run is byte-stable and its plan matches the convergent apply ($twin)" {
        $target = New-LegacyRetirementTarget
        try {
            $before = Get-TreeFingerprint $target
            $dry = Invoke-CurrentInstaller -Twin $twin -Target $target -DryRun
            Assert ($dry.Exit -eq 0) "dry-run exited $($dry.Exit): $($dry.Output)"
            Assert ((Get-TreeFingerprint $target) -ceq $before) 'dry-run changed target bytes'
            $apply = Invoke-CurrentInstaller -Twin $twin -Target $target
            Assert ($apply.Exit -eq 0) "apply exited $($apply.Exit): $($apply.Output)"
            $dryPlan = @(($dry.Output -split "`r?`n") | Where-Object { $_ -match '^PLAN ' })
            $applyPlan = @(($apply.Output -split "`r?`n") | Where-Object { $_ -match '^PLAN ' })
            Assert (($dryPlan -join "`n") -ceq ($applyPlan -join "`n")) 'dry-run and apply emitted different operation sets'
            foreach ($relative in $retiredPaths) { Assert (-not (Test-Path -LiteralPath (Join-Path $target $relative))) "retired framework path survived: $relative" }
            Assert (@($applyPlan | Where-Object { $_ -match '^PLAN delete ' }).Count -eq 5) 'apply did not plan exactly the five authorized retirements'
        } finally { Remove-Item -Recurse -Force -LiteralPath $target -ErrorAction SilentlyContinue }
    }

    It "consumer-modified and reparse retirement paths survive while verified bytes converge ($twin)" {
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
                $result = Invoke-CurrentInstaller -Twin $twin -Target $target
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
                    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
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

    It "a forged previous manifest enters additive compatibility and deletes nothing ($twin)" {
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
            $result = Invoke-CurrentInstaller -Twin $twin -Target $target
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

    It "retires only qualified mirror leaves, never recreates mirrors, and keeps residual warnings durable ($twin)" {
        $candidate = New-B217CandidateSource
        $target = New-B217ResidualTarget -StockPath $candidate.Stock
        try {
            $first = Invoke-CurrentInstaller -Twin $twin -Target $target -SourceRoot $candidate.Root
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

            $second = Invoke-CurrentInstaller -Twin $twin -Target $target -SourceRoot $candidate.Root
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

    It "distinguishes an uninspectable retained retirement from an absent path ($twin)" {
        $candidate = New-B217CandidateSource
        $target = New-B217ResidualTarget -StockPath $candidate.Stock
        $savedPsFailure = $env:B217_UNREADABLE_PATH
        $savedShFind = $env:B217_TEST_FIND_CMD
        try {
            $retainedPath = 'scripts/sync-agent-files.ps1'
            $retained = Join-Path $target $retainedPath
            if ($twin -eq 'ps1') {
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
            } else {
                $wrapper = Join-Path $candidate.Root '.b217-find-wrapper.sh'
                [IO.File]::WriteAllText($wrapper, @'
#!/usr/bin/env bash
for arg in "$@"; do
  [ "$arg" = 'sync-agent-files.ps1' ] && exit 2
done
exec /usr/bin/find "$@"
'@, [Text.UTF8Encoding]::new($false))
                $wrapperForBash = $wrapper -replace '\\', '/'
                & $bash -c 'chmod +x "$1"' bash $wrapperForBash
                Assert ($LASTEXITCODE -eq 0) 'could not make the planted find wrapper executable'
                $installerPath = Join-Path $candidate.Root 'scripts/install.sh'
                $installer = [IO.File]::ReadAllText($installerPath)
                $needle = '[ -x /usr/bin/find ] && find_cmd=/usr/bin/find'
                $replacement = '[ -x /usr/bin/find ] && find_cmd="${B217_TEST_FIND_CMD:-/usr/bin/find}"'
                Assert ($installer.Contains($needle)) 'could not locate the shell inspection-failure injection point'
                $mock = @'
function [ {
  if test "$#" -eq 3 && test "$1" = '-e'; then
    case "$2" in */scripts/sync-agent-files.ps1) return 1;; esac
  fi
  builtin [ "$@"
}
'@
                $installer = $installer.Replace($needle, $replacement + "`n" + $mock)
                [IO.File]::WriteAllText($installerPath, $installer, [Text.UTF8Encoding]::new($false))
                $env:B217_TEST_FIND_CMD = $wrapperForBash
                $env:B217_UNREADABLE_PATH = ($retained -replace '\\', '/')
            }

            $before = (Get-FileHash -LiteralPath $retained -Algorithm SHA256).Hash
            $result = Invoke-CurrentInstaller -Twin $twin -Target $target -SourceRoot $candidate.Root
            Assert ($result.Exit -eq 0) "inspection-failure update exited $($result.Exit): $($result.Output)"
            Assert ($result.Output -match "CANT-VERIFY: retained retired path 'scripts/sync-agent-files\.ps1' could not be examined") 'inspection failure was silently treated as absence'
            Assert ((Get-FileHash -LiteralPath $retained -Algorithm SHA256).Hash -ceq $before) 'uninspectable retained path changed'
        } finally {
            if ($null -eq $savedPsFailure) { Remove-Item Env:B217_UNREADABLE_PATH -ErrorAction SilentlyContinue }
            else { $env:B217_UNREADABLE_PATH = $savedPsFailure }
            if ($null -eq $savedShFind) { Remove-Item Env:B217_TEST_FIND_CMD -ErrorAction SilentlyContinue }
            else { $env:B217_TEST_FIND_CMD = $savedShFind }
            Remove-Item -Recurse -Force -LiteralPath $target, $candidate.Root -ErrorAction SilentlyContinue
        }
    }

    It "preserves pre-manifest and malformed-manifest mirrors with durable manual-migration warnings ($twin)" {
        $candidate = New-B217CandidateSource
        try {
            foreach ($shape in @('missing', 'malformed')) {
                $target = New-B217LegacyManifestTarget -StockPath $candidate.Stock -ManifestShape $shape
                try {
                    $before = (Get-FileHash -LiteralPath (Join-Path $target $candidate.Stock) -Algorithm SHA256).Hash
                    $first = Invoke-CurrentInstaller -Twin $twin -Target $target -SourceRoot $candidate.Root
                    Assert ($first.Exit -eq 0) "B-217 $shape-manifest update exited $($first.Exit): $($first.Output)"
                    Assert (Test-Path -LiteralPath (Join-Path $target $candidate.Stock) -PathType Leaf) "$shape-manifest update deleted the unqualified stock mirror"
                    Assert ((Get-FileHash -LiteralPath (Join-Path $target $candidate.Stock) -Algorithm SHA256).Hash -ceq $before) "$shape-manifest update changed the unqualified stock mirror"
                    Assert (@(($first.Output -split "`r?`n") | Where-Object { $_ -eq "PLAN delete $($candidate.Stock)" }).Count -eq 0) "$shape-manifest update planned an unauthorized stock deletion"
                    Assert ($first.Output -match "CANT-VERIFY: previous framework-ownership\.json is $shape") "$shape-manifest update did not name the lost deletion authority"
                    Assert ($first.Output -match "CANT-VERIFY: retained retired path '\.github/skills/perf/SKILL\.md'.*may shadow") "$shape-manifest update lacked the exact manual-migration warning"

                    $second = Invoke-CurrentInstaller -Twin $twin -Target $target -SourceRoot $candidate.Root
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

    It "downgrade refusal is pre-mutation and the deliberate override is observable ($twin)" {
        $target = New-LegacyRetirementTarget
        try {
            [IO.File]::WriteAllText((Join-Path $target '.claude/framework-version.json'), '{"version":"99.0.0","template":"dotnet"}', [Text.UTF8Encoding]::new($false))
            $before = Get-TreeFingerprint $target
            $refused = Invoke-CurrentInstaller -Twin $twin -Target $target
            Assert ($refused.Exit -eq 4) "downgrade refusal exited $($refused.Exit), expected 4: $($refused.Output)"
            Assert ($refused.Output -match 'Refusing framework downgrade') 'downgrade refusal was not actionable'
            Assert ((Get-TreeFingerprint $target) -ceq $before) 'downgrade refusal changed target bytes'
            $allowed = Invoke-CurrentInstaller -Twin $twin -Target $target -DryRun -AllowDowngrade
            Assert ($allowed.Exit -eq 0) "allowed downgrade dry-run exited $($allowed.Exit): $($allowed.Output)"
            Assert ($allowed.Output -match 'allow-downgrade accepted|AllowDowngrade accepted') 'downgrade override was not observable'
            Assert ((Get-TreeFingerprint $target) -ceq $before) 'allowed downgrade dry-run changed target bytes'
        } finally { Remove-Item -Recurse -Force -LiteralPath $target -ErrorAction SilentlyContinue }
    }

    It "the rich update plan accounts for every observable skill and backup mutation ($twin)" {
        $target = New-RichUpdateTarget
        try {
            $before = Get-FileState $target
            $discoveredBefore = $before['.claude/skills/local-release/SKILL.md']
            $unknownBefore = $before['.claude/skills/consumer-local/SKILL.md']
            $legacyDiscoveredBefore = $before['.github/skills/local-release/SKILL.md']
            $legacyDisabledBefore = $before['.github/skills/perf/SKILL.md']
            $dry = Invoke-CurrentInstaller -Twin $twin -Target $target -DryRun
            Assert ($dry.Exit -eq 0) "rich dry-run exited $($dry.Exit): $($dry.Output)"
            $dryPlan = @(($dry.Output -split "`r?`n") | Where-Object { $_ -match '^PLAN ' })
            Assert ($dryPlan -contains 'PLAN create .claude/framework-update-backup/skills/local-release/SKILL.md') 'skill backup leaf was hidden behind an opaque directory plan'
            Assert (@($dryPlan | Where-Object { $_ -match '^PLAN (create|replace) \.claude/disabled-skills/perf/SKILL\.md$' }).Count -eq 1) 'disabled-skill destination was absent or contradictory'
            Assert ($dryPlan -contains 'PLAN delete .claude/skills/perf') 'disabled active skill deletion was not planned'
            Assert (@($dryPlan | Where-Object { $_ -match '^PLAN (create|replace) \.claude/skills/perf/' }).Count -eq 0) 'plan claimed the disabled skill would remain active'
            Assert (@($dryPlan | Where-Object { $_ -match '^PLAN (?:create|replace|delete) \.github/skills(?:/|$)' }).Count -eq 0) 'retired GitHub skill tree still had installer mutation plans'
            Assert ($dry.Output -match "CANT-VERIFY: retained retired path '\.github/skills/perf/SKILL\.md'.*may shadow") 'modified disabled mirror lacked a durable exact-path warning'

            $apply = Invoke-CurrentInstaller -Twin $twin -Target $target
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

    It "installer-owned side-write parents refuse reparse escape before mutation ($twin)" {
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
                $result = Invoke-CurrentInstaller -Twin $twin -Target $target
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
}

exit (Write-TestSummary 'InstallerConvergence.Tests')
