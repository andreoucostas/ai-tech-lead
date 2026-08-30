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
    param([string]$Twin, [string]$Target, [switch]$DryRun, [switch]$AllowDowngrade)
    $installer = Join-Path $repoRoot "dist/dotnet/scripts/install.$Twin"
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
        try {
            [IO.File]::WriteAllText((Join-Path $target 'scripts/impact-run.ps1'), 'CONSUMER CUSTOM RUNNER', [Text.UTF8Encoding]::new($false))
            New-Item -ItemType Directory -Force -Path $outside | Out-Null
            Move-Item -LiteralPath (Join-Path $target 'tests/impact') -Destination (Join-Path $outside 'impact')
            Assert (New-DirectoryLink -Link (Join-Path $target 'tests/impact') -Destination (Join-Path $outside 'impact')) 'could not construct retirement reparse fixture'
            $outsideBefore = Get-TreeFingerprint $outside
            $result = Invoke-CurrentInstaller -Twin $twin -Target $target
            Assert ($result.Exit -eq 0) "safe reconciliation exited $($result.Exit): $($result.Output)"
            Assert ([IO.File]::ReadAllText((Join-Path $target 'scripts/impact-run.ps1')).Contains('CONSUMER CUSTOM RUNNER')) 'consumer-modified retired path was deleted or overwritten'
            Assert (-not (Test-Path -LiteralPath (Join-Path $target 'scripts/impact-run.sh'))) 'verified framework runner was not retired'
            Assert ((Get-TreeFingerprint $outside) -ceq $outsideBefore) 'reparse retirement changed out-of-root bytes'
            Assert ($result.Output -match 'consumer-modified or unknown content') 'custom-content preservation was not disclosed'
            Assert ($result.Output -match 'reparse/symlink') 'reparse preservation was not disclosed'
        } finally {
            $link = Join-Path $target 'tests/impact'
            $linkItem = Get-Item -Force -LiteralPath $link -ErrorAction SilentlyContinue
            if ($linkItem -and (($linkItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { Remove-Item -Force -LiteralPath $link -ErrorAction SilentlyContinue }
            if (Test-Path -LiteralPath $target) { Remove-Item -Recurse -Force -LiteralPath $target -ErrorAction SilentlyContinue }
            if (Test-Path -LiteralPath $outside) { Remove-Item -Recurse -Force -LiteralPath $outside -ErrorAction SilentlyContinue }
        }
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
            $dry = Invoke-CurrentInstaller -Twin $twin -Target $target -DryRun
            Assert ($dry.Exit -eq 0) "rich dry-run exited $($dry.Exit): $($dry.Output)"
            $dryPlan = @(($dry.Output -split "`r?`n") | Where-Object { $_ -match '^PLAN ' })
            Assert ($dryPlan -contains 'PLAN create .claude/framework-update-backup/skills/local-release/SKILL.md') 'skill backup leaf was hidden behind an opaque directory plan'
            Assert (@($dryPlan | Where-Object { $_ -match '^PLAN (create|replace) \.claude/disabled-skills/perf/SKILL\.md$' }).Count -eq 1) 'disabled-skill destination was absent or contradictory'
            Assert ($dryPlan -contains 'PLAN delete .claude/skills/perf') 'disabled active skill deletion was not planned'
            Assert ($dryPlan -contains 'PLAN delete .github/skills/perf') 'disabled GitHub mirror deletion was not planned'
            Assert (@($dryPlan | Where-Object { $_ -match '^PLAN (create|replace) \.claude/skills/perf/' }).Count -eq 0) 'plan claimed the disabled skill would remain active'
            Assert (@($dryPlan | Where-Object { $_ -match '^PLAN (create|replace) \.github/skills/local-release/(SKILL\.md|notes\.md)$' }).Count -eq 2) 'discovered skill mirror leaves were not planned'

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
            Assert ($after['.github/skills/local-release/SKILL.md'] -ceq $discoveredBefore) 'discovered GitHub mirror did not converge to the preserved Claude skill'
            Assert ($after['.claude/skills/consumer-local/SKILL.md'] -ceq $unknownBefore) 'unknown consumer skill bytes changed during exemplar carry-forward'
            Assert ($after['.github/skills/consumer-local/SKILL.md'] -ceq $unknownBefore) 'unknown consumer skill mirror did not use the preserved consumer bytes'
            $frameworkSkill = Get-Content -LiteralPath (Join-Path $target '.claude/skills/add-warehouse-load/SKILL.md') -Raw
            Assert ($frameworkSkill -notmatch 'OLD BODY') 'framework skill was not refreshed before carrying its exemplar forward'
            Assert ($frameworkSkill -match [regex]::Escape('For a concrete current instance in this repo, see `warehouse/LoadSales.sql`.')) 'framework skill lost its prior exemplar'
            Assert (-not $after.ContainsKey('.claude/skills/perf/SKILL.md')) 'disabled skill remained active'
            Assert (-not $after.ContainsKey('.github/skills/perf/SKILL.md')) 'disabled skill remained active on GitHub'
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
