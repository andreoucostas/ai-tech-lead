[CmdletBinding()]
param(
    [switch]$SkipRedTest,
    [switch]$OnlyWarehouse
)

. (Join-Path $PSScriptRoot '_HookHarness.ps1')
. (Join-Path $PSScriptRoot '_MutationHelper.ps1')
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

function Remove-TestFixtureTree([string]$AtlFixturePath) {
    if ([string]::IsNullOrWhiteSpace($AtlFixturePath)) {
        throw [System.Security.SecurityException]::new('fixture cleanup rejected a null or blank path')
    }

    $atlTrimChars = [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    try {
        $atlCanonicalPath = [IO.Path]::GetFullPath($AtlFixturePath).TrimEnd($atlTrimChars)
    } catch {
        throw [System.Security.SecurityException]::new("fixture cleanup could not canonicalize '$AtlFixturePath'", $_.Exception)
    }

    $atlLeaf = [IO.Path]::GetFileName($atlCanonicalPath)
    $atlWorkspaceParent = [IO.Path]::GetFullPath((Split-Path -Parent $repo)).TrimEnd($atlTrimChars)
    $atlTempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd($atlTrimChars)
    $atlTrustedParent = $null
    if ($atlLeaf -cmatch '^root-installer-(?:warehouse|singlewarehouse|angularwarehouse|dotnet|mixed)-[0-9a-f]{32}$') {
        $atlTrustedParent = $atlWorkspaceParent
    } elseif ($atlLeaf -cmatch '^root-broken-jq-[0-9a-f]{32}$') {
        $atlTrustedParent = $atlTempParent
    }
    if ($null -eq $atlTrustedParent) {
        throw [System.Security.SecurityException]::new("fixture cleanup rejected non-allowlisted path '$atlCanonicalPath'")
    }

    $atlExpectedPath = [IO.Path]::GetFullPath((Join-Path $atlTrustedParent $atlLeaf)).TrimEnd($atlTrimChars)
    if (-not [string]::Equals($atlCanonicalPath, $atlExpectedPath, [StringComparison]::Ordinal)) {
        throw [System.Security.SecurityException]::new("fixture cleanup rejected path outside its exact parent: '$atlCanonicalPath'")
    }

    $atlPolicyMarker = 'B204FixtureCleanupPolicy'
    $atlNewPolicyFailure = {
        param([string]$AtlPolicyMessage)
        $atlPolicyException = [System.Security.SecurityException]::new($AtlPolicyMessage)
        $atlPolicyException.Data[$atlPolicyMarker] = $true
        return $atlPolicyException
    }
    $atlValidateExpectedEntry = {
        param($AtlEntry, [string]$AtlLookupPath, [string]$AtlLookupLeaf)
        $atlEntryPath = [IO.Path]::GetFullPath($AtlEntry.FullName).TrimEnd($atlTrimChars)
        if (-not [string]::Equals([string]$AtlEntry.Name, $AtlLookupLeaf, [StringComparison]::Ordinal) -or
            -not [string]::Equals($atlEntryPath, $AtlLookupPath, [StringComparison]::Ordinal)) {
            throw (& $atlNewPolicyFailure "fixture cleanup resolved a case/path alias instead of exact entry '$AtlLookupPath': '$($AtlEntry.FullName)'")
        }
        return $AtlEntry
    }

    $atlReadEntry = {
        param([string]$AtlLookupPath, [string]$AtlLookupParent, [string]$AtlLookupLeaf)
        $atlDirectResolved = $false
        try {
            $null = Get-Item -LiteralPath $AtlLookupPath -Force -ErrorAction Stop
            $atlDirectResolved = $true
        } catch [System.Management.Automation.ItemNotFoundException] {
            # A missing target and a dangling link can both reach this branch. Parent enumeration
            # below distinguishes no directory entry from an unresolved reparse entry.
        }
        $atlOrdinalMatches = @(
            Get-ChildItem -LiteralPath $AtlLookupParent -Force -ErrorAction Stop |
                Where-Object { [string]::Equals([string]$_.Name, $AtlLookupLeaf, [StringComparison]::Ordinal) }
        )
        if ($atlOrdinalMatches.Count -eq 0) {
            if ($atlDirectResolved) {
                throw (& $atlNewPolicyFailure "fixture cleanup resolved '$AtlLookupPath' only through a case/path alias")
            }
            return $null
        }
        if ($atlOrdinalMatches.Count -ne 1) {
            throw (& $atlNewPolicyFailure "fixture cleanup found multiple ordinal entries named '$AtlLookupLeaf' beneath '$AtlLookupParent'")
        }
        return (& $atlValidateExpectedEntry $atlOrdinalMatches[0] $AtlLookupPath $AtlLookupLeaf)
    }

    $atlLastFailure = $null
    $atlLastDetail = 'target remained present'
    for ($atlAttempt = 1; $atlAttempt -le 6; $atlAttempt++) {
        $atlAttemptFailure = $null
        $atlEntry = $null
        try {
            $atlEntry = & $atlReadEntry $atlCanonicalPath $atlTrustedParent $atlLeaf
            if ($null -eq $atlEntry) { return }

            $atlRootLink = (($atlEntry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) -or
                ($atlEntry.PSObject.Properties['LinkType'] -and -not [string]::IsNullOrWhiteSpace([string]$atlEntry.LinkType))
            if ($atlRootLink) {
                throw (& $atlNewPolicyFailure "fixture cleanup rejected reparse/link root '$($atlEntry.FullName)'")
            }
            if (-not $atlEntry.PSIsContainer) {
                throw (& $atlNewPolicyFailure "fixture cleanup expected a directory but found '$($atlEntry.FullName)'")
            }

            $atlPending = New-Object 'System.Collections.Generic.Queue[string]'
            $atlPending.Enqueue($atlCanonicalPath)
            while ($atlPending.Count -gt 0) {
                $atlDirectoryPath = $atlPending.Dequeue()
                $atlDirectory = Get-Item -LiteralPath $atlDirectoryPath -Force -ErrorAction Stop
                $atlDirectoryLink = (($atlDirectory.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) -or
                    ($atlDirectory.PSObject.Properties['LinkType'] -and -not [string]::IsNullOrWhiteSpace([string]$atlDirectory.LinkType))
                if ($atlDirectoryLink) {
                    throw (& $atlNewPolicyFailure "fixture cleanup rejected reparse/link directory '$($atlDirectory.FullName)'")
                }
                if (-not $atlDirectory.PSIsContainer) {
                    throw (& $atlNewPolicyFailure "fixture cleanup expected a directory but found '$($atlDirectory.FullName)'")
                }

                foreach ($atlChild in @(Get-ChildItem -LiteralPath $atlDirectory.FullName -Force -ErrorAction Stop)) {
                    $atlChildLink = (($atlChild.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) -or
                        ($atlChild.PSObject.Properties['LinkType'] -and -not [string]::IsNullOrWhiteSpace([string]$atlChild.LinkType))
                    if ($atlChildLink) {
                        throw (& $atlNewPolicyFailure "fixture cleanup rejected reparse/link entry '$($atlChild.FullName)'")
                    }
                    if ($atlChild.PSIsContainer) { $atlPending.Enqueue($atlChild.FullName) }
                }
            }

            Remove-Item -LiteralPath $atlCanonicalPath -Recurse -Force -ErrorAction Stop
        } catch {
            if ($_.Exception.Data -and $_.Exception.Data.Contains($atlPolicyMarker)) { throw }
            $atlAttemptFailure = $_
        }

        $atlPostEntry = $null
        $atlPostInspectionFailed = $false
        try {
            $atlPostEntry = & $atlReadEntry $atlCanonicalPath $atlTrustedParent $atlLeaf
        } catch {
            if ($_.Exception.Data -and $_.Exception.Data.Contains($atlPolicyMarker)) { throw }
            $atlPostInspectionFailed = $true
            # This later failure is decisive: we could not establish whether the preceding removal
            # error nevertheless left the required absent state.
            $atlAttemptFailure = $_
        }
        if (-not $atlPostInspectionFailed -and $null -eq $atlPostEntry) { return }

        $atlLastFailure = $atlAttemptFailure
        $atlLastDetail = if ($atlAttemptFailure) { $atlAttemptFailure.Exception.Message } else { 'target remained present after removal returned' }
        if ($atlAttempt -lt 6) { Start-Sleep -Milliseconds (100 * $atlAttempt) }
    }

    $atlFailureMessage = "fixture cleanup failed for '$atlCanonicalPath' after 6 attempts: $atlLastDetail"
    if ($atlLastFailure) { throw [IO.IOException]::new($atlFailureMessage, $atlLastFailure.Exception) }
    throw [IO.IOException]::new($atlFailureMessage)
}

function Invoke-WithTestFixture(
    [string]$AtlFixturePath,
    [scriptblock]$AtlFixtureBody,
    [object[]]$AtlFixtureBodyArguments = @()
) {
    $atlBodyFailure = $null
    $atlBodyInvocationArguments = @($AtlFixturePath) + @($AtlFixtureBodyArguments)
    try { & $AtlFixtureBody @atlBodyInvocationArguments } catch { $atlBodyFailure = $_ }

    $atlCleanupFailure = $null
    try { Remove-TestFixtureTree $AtlFixturePath } catch { $atlCleanupFailure = $_ }

    if ($atlBodyFailure -and $atlCleanupFailure) {
        $atlAggregateMessage = "fixture body failed for '$AtlFixturePath': $($atlBodyFailure.Exception.Message)`nfixture cleanup also failed for '$AtlFixturePath': $($atlCleanupFailure.Exception.Message)"
        $atlInnerExceptions = [Exception[]]@($atlBodyFailure.Exception, $atlCleanupFailure.Exception)
        throw [AggregateException]::new($atlAggregateMessage, $atlInnerExceptions)
    }
    if ($atlBodyFailure) { throw $atlBodyFailure }
    if ($atlCleanupFailure) { throw $atlCleanupFailure }
}

function Add-WarehouseSignals([string]$Target) {
    $warehouse = Join-Path $Target 'warehouse'
    New-Item -ItemType Directory -Force -Path $warehouse | Out-Null
    [IO.File]::WriteAllText((Join-Path $warehouse 'DimCustomer.sql'), 'CREATE TABLE dw.DimCustomer (CustomerKey int, EffectiveFrom date, IsCurrent bit);')
    [IO.File]::WriteAllText((Join-Path $warehouse 'usp_LoadCustomer.sql'), 'CREATE PROC etl.usp_LoadCustomer @BatchId int AS SELECT 1;')
}

function Add-OneWarehouseCategory([string]$Target) {
    $warehouse = Join-Path $Target 'warehouse'
    New-Item -ItemType Directory -Force -Path $warehouse | Out-Null
    # Two matching files still count as one independent category. This distinguishes the shared
    # category threshold from a raw match count.
    [IO.File]::WriteAllText((Join-Path $warehouse 'DimCustomer.sql'), 'CREATE TABLE dbo.DimCustomer (CustomerKey int);')
    [IO.File]::WriteAllText((Join-Path $warehouse 'FactSales.sql'), 'CREATE TABLE dbo.FactSales (SalesKey int);')
}

function New-Target([ValidateSet('warehouse', 'singlewarehouse', 'angularwarehouse', 'dotnet', 'mixed')][string]$Kind) {
    # Keep the fixture beneath the workspace parent so both supported PowerShell hosts resolve the
    # same physical Windows path.
    $target = Join-Path (Split-Path -Parent $repo) ("root-installer-$Kind-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    if ($Kind -eq 'warehouse') { Add-WarehouseSignals (Join-Path $target 'platform/data/domain') }
    if ($Kind -in @('angularwarehouse', 'mixed')) { Add-WarehouseSignals $target }
    if ($Kind -eq 'singlewarehouse') {
        Add-OneWarehouseCategory $target
        New-Item -ItemType Directory -Force -Path (Join-Path $target 'NODE_MODULES/generated'), (Join-Path $target 'OBJ') | Out-Null
        [IO.File]::WriteAllText((Join-Path $target 'NODE_MODULES/generated/angular.json'), '{"version":1}')
        [IO.File]::WriteAllText((Join-Path $target 'OBJ/Generated.csproj'), '<Project />')
        Add-WarehouseSignals (Join-Path $target 'VENDOR/generated')
    }
    if ($Kind -eq 'dotnet' -or $Kind -eq 'mixed') { [IO.File]::WriteAllText((Join-Path $target 'App.csproj'), '<Project Sdk="Microsoft.NET.Sdk" />') }
    if ($Kind -eq 'mixed') { [IO.File]::WriteAllText((Join-Path $target 'project.json'), '{"targets":{"build":{"executor":"@angular-devkit/build-angular:browser"}}}') }
    if ($Kind -eq 'angularwarehouse') { [IO.File]::WriteAllText((Join-Path $target 'package.json'), '{"dependencies":{"@angular/core":"20.0.0"},"decimal":0.01,"exponent":1e01,"negativeExponent":1e-01}') }
    & git -C $target init --quiet 2>$null | Out-Null
    return $target
}

function Get-TargetFingerprint([string]$Target) {
    $parts = @(
        foreach ($directory in Get-ChildItem -LiteralPath $Target -Recurse -Force -Directory | Where-Object { $_.FullName -notmatch '[\\/]\.git(?:[\\/]|$)' }) {
            $relative = $directory.FullName.Substring($Target.Length).TrimStart('\', '/') -replace '\\', '/'
            "D:$relative"
        }
        foreach ($file in Get-ChildItem -LiteralPath $Target -Recurse -Force -File | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }) {
            $relative = $file.FullName.Substring($Target.Length).TrimStart('\', '/') -replace '\\', '/'
            "F:${relative}:$((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash)"
        }
    ) | Sort-Object
    return ($parts -join "`n")
}

function Assert-EvidenceBoundLifecycle([string]$Target) {
    $carriers = @(
        @{ Path = 'CLAUDE.md'; Patterns = @('@AGENTS.md', '@.github/instructions/framework-rules.instructions.md'); Forbidden = @('What this application does', 'Missing unit tests for public methods') },
        @{ Path = 'AGENTS.md'; Patterns = @('delivery-profile superset', 'not evidence that'); Forbidden = @('What this application does', 'Missing unit tests for public methods') },
        @{ Path = '.claude/commands/bootstrap.md'; Patterns = @('warehouse-SQL', 'scripts/warehouse-signals.tsv', 'repository-wide', 'not available', 'remaining Phase 2b', '--headless', 'applicability-gated delivery-profile superset', 'Never append repository-specific evidence to a framework-shipped skill'); Forbidden = @('what this app does', 'What this application does', 'skip this phase entirely', "delete defaults that don't apply", 'delete or replace `add-entity`', 'otherwise delete both', 'retain application-only skills', 'append one prose line to the skill file') },
        @{ Path = '.claude/commands/adopt.md'; Patterns = @('Phase 7', '/bootstrap', 'selected profile(s)', 'framework-ownership.json', 'Never archive, move, or delete current stamp-owned/shipped framework state', 'immediately before invoking `/bootstrap`'); Forbidden = @('what the app does') },
        @{ Path = '.claude/commands/rebootstrap.md'; Patterns = @('build/test/format/lint/migration/deploy/data-validation', 'not available', 'manual/CI-only', 'non-mutating validation/dry-run'); Forbidden = @('migration-deploy') },
        @{ Path = '.claude/commands/docs-sync.md'; Patterns = @('repository/system does', 'consumers', 'domain'); Forbidden = @('what the app does') },
        @{ Path = '.claude/commands/feature.md'; Patterns = @('repository evidence', 'not available'); Forbidden = @('this .NET codebase', 'Integration test — WebApplicationFactory') },
        @{ Path = '.claude/commands/fix.md'; Patterns = @('repository evidence', 'not available'); Forbidden = @('Write the failing test BEFORE any production code') },
        @{ Path = '.claude/commands/debt.md'; Patterns = @('repository evidence', 'not available'); Forbidden = @('Verify existing tests pass before touching anything', 'If no tests exist for the affected code, write baseline tests first') },
        @{ Path = '.claude/commands/review.md'; Patterns = @('commands supported by that evidence', 'not available'); Forbidden = @() },
        @{ Path = '.claude/commands/refactor.md'; Patterns = @('repository-evidenced', 'not available'); Forbidden = @() },
        @{ Path = '.claude/commands/test.md'; Patterns = @('repository evidence', 'not available'); Forbidden = @() },
        @{ Path = '.claude/workflow.md'; Patterns = @('migration/deploy', 'data-validation', 'not available', 'manual/CI-only', 'non-mutating validation/dry-run'); Forbidden = @('Verify build, tests, and lint pass.') },
        @{ Path = '.claude/hooks/route-prompt.ps1'; Patterns = @('repository evidence', 'not available', 'manual/CI-only', 'non-mutating validation/dry-run'); Forbidden = @('2. Write a failing regression test BEFORE touching production code') },
        @{ Path = '.github/instructions/framework-rules.instructions.md'; Patterns = @('repository-evidenced commands', 'not available', 'manual/CI-only', 'non-mutating validation/dry-run'); Forbidden = @('Each subtask must leave the codebase compilable and test-passing.', 'Verify all tests pass') },
        @{ Path = '.github/PULL_REQUEST_TEMPLATE.md'; Patterns = @('applicable harness', 'Verification Commands', 'not available'); Forbidden = @('Tests added/updated for changed behaviour', 'dotnet build && dotnet test') },
        @{ Path = '.agents/skills/fix/SKILL.md'; Patterns = @('repository-evidenced', 'not available'); Forbidden = @('Never skip the test') },
        @{ Path = '.claude/skills/add-tests/SKILL.md'; Patterns = @('Applicability gate', 'solution-free'); Forbidden = @('dotnet sln add', 'this mixed') },
        @{ Path = 'docs/ci-integration.md'; Patterns = @('migration/deploy', 'data-validation', 'not available', 'manual/CI-only', 'non-mutating validation/dry-run'); Forbidden = @('Use the exact build, test, format, and lint commands') }
    )
    foreach ($carrier in $carriers) {
        $path = Join-Path $Target $carrier.Path
        Assert (Test-Path -LiteralPath $path -PathType Leaf) "installed lifecycle carrier is missing: $($carrier.Path)"
        $raw = Get-Content -LiteralPath $path -Raw
        foreach ($pattern in $carrier.Patterns) {
            Assert ($raw -match [regex]::Escape($pattern)) "installed lifecycle carrier $($carrier.Path) omitted '$pattern'"
        }
        foreach ($pattern in $carrier.Forbidden) {
            Assert ($raw -notmatch [regex]::Escape($pattern)) "installed lifecycle carrier $($carrier.Path) retains known solution-only instruction '$pattern'"
        }
    }

}

function Invoke-RootInstaller([string]$Target, [string]$Stack = '', [switch]$DryRun, [switch]$AllowDowngrade, [switch]$AllowDirtyTree) {
    $arguments = @('-NoProfile', '-File', (Join-Path $repo 'install.ps1'))
    if ($Stack) { $arguments += @('-Stack', $Stack) }
    if ($DryRun) { $arguments += '-WhatIf' }
    if ($AllowDowngrade) { $arguments += '-AllowDowngrade' }
    if ($AllowDirtyTree) { $arguments += '-AllowDirtyTree' }
    $arguments += $Target
    $out = @(& (Get-PsExe) @arguments 2>&1 | ForEach-Object { $_.ToString() })
    return [pscustomobject]@{ Exit = [int]$LASTEXITCODE; Output = ($out -join "`n") }
}

function Invoke-B324Git([string]$Repository, [string[]]$Arguments) {
    $out = @(& git -C $Repository -c user.name=atl-test -c user.email=atl-test@invalid.local -c core.autocrlf=false @Arguments 2>&1 | ForEach-Object { $_.ToString() })
    Assert ($LASTEXITCODE -eq 0) "fixture git $($Arguments -join ' ') failed: $($out -join ' ')"
}

# B-324: a framework clone pushed to a local bare repository, with this checkout's root dispatcher, dotnet
# dist and installer source where a real clone has them, and a .NET target. Nothing in it reads the network.
function New-B324Clone([string]$Parent) {
    $fw = [pscustomobject]@{ Clone = (Join-Path $Parent 'fw'); Remote = (Join-Path $Parent 'remote.git'); Target = (Join-Path $Parent 'target'); Version = $null }
    [void][IO.Directory]::CreateDirectory((Join-Path $fw.Clone 'dist'))
    [void][IO.Directory]::CreateDirectory($fw.Target)
    Copy-Item -LiteralPath (Join-Path $repo 'dist/dotnet') -Destination (Join-Path $fw.Clone 'dist/dotnet') -Recurse
    Copy-Item -LiteralPath (Join-Path $repo 'install.ps1') -Destination (Join-Path $fw.Clone 'install.ps1')
    [void][IO.Directory]::CreateDirectory((Join-Path $fw.Clone 'src/core/scripts'))
    Copy-Item -LiteralPath (Join-Path $repo 'src/core/scripts/install.ps1') -Destination (Join-Path $fw.Clone 'src/core/scripts/install.ps1')
    [IO.File]::WriteAllText((Join-Path $fw.Target 'App.csproj'), '<Project Sdk="Microsoft.NET.Sdk" />')
    $fw.Version = [string](Get-Content -Raw -LiteralPath (Join-Path $fw.Clone 'dist/dotnet/.claude/framework-version.json') | ConvertFrom-Json).version
    & git init -q --bare $fw.Remote 2>&1 | Out-Null
    Assert ($LASTEXITCODE -eq 0) 'could not create the fixture remote'
    # -f: the real repository tracks framework files the dist's own ignore rules would hide.
    foreach ($step in @(@('init', '-q', '-b', 'master'), @('add', '-A', '-f'), @('commit', '-q', '-m', 'release'), @('tag', "v$($fw.Version)"),
            @('remote', 'add', 'origin', $fw.Remote), @('push', '-q', '-u', 'origin', 'master', "v$($fw.Version)"))) {
        Invoke-B324Git $fw.Clone $step
    }
    return $fw
}

function Invoke-B324Installer([string]$Clone, [string]$Target, [switch]$DryRun, [switch]$AllowOutdated) {
    $arguments = @('-NoProfile', '-File', (Join-Path $Clone 'install.ps1'), '-Stack', 'dotnet')
    if ($DryRun) { $arguments += '-WhatIf' }
    if ($AllowOutdated) { $arguments += '-AllowOutdated' }
    $out = @(& (Get-PsExe) @arguments $Target 2>&1 | ForEach-Object { $_.ToString() })
    return [pscustomobject]@{ Exit = [int]$LASTEXITCODE; Output = ($out -join "`n") }
}

Reset-Tests

    It 'warehouse-only auto-detection completes greenfield install without a solution' {
        $singleCategoryTarget = New-Target 'singlewarehouse'
        Invoke-WithTestFixture $singleCategoryTarget ({
            $before = Get-TargetFingerprint $singleCategoryTarget
            $singleCategory = Invoke-RootInstaller $singleCategoryTarget
            Assert ($singleCategory.Exit -eq 2) "one warehouse category should not auto-route, exit $($singleCategory.Exit): $($singleCategory.Output)"
            Assert ($singleCategory.Output -match 'Could not determine the stack') "one warehouse category did not produce the ordinary explicit-stack refusal: $($singleCategory.Output)"
            Assert ($singleCategory.Output -notmatch 'Stack: dotnet') "repeated matches from one category incorrectly selected dotnet: $($singleCategory.Output)"
            Assert ((Get-TargetFingerprint $singleCategoryTarget) -ceq $before) 'one-category refusal changed target bytes'
        })

        $target = New-Target 'warehouse'
        Invoke-WithTestFixture $target ({
            $result = Invoke-RootInstaller $target
            Assert ($result.Exit -eq 0) "warehouse-only greenfield install exited $($result.Exit): $($result.Output)"
            Assert ($result.Output -match 'Stack: dotnet \(via auto-detected warehouse SQL profile \(found signals: layers, loads, control, history\)\)') "warehouse categories or their order diverged from the shared classifier: $($result.Output)"
            Assert ($result.Output -match '(?i)type:\s+/bootstrap') "greenfield handoff did not name /bootstrap: $($result.Output)"
            Assert (Test-Path -LiteralPath (Join-Path $target '.claude/commands/bootstrap.md') -PathType Leaf) 'greenfield install omitted /bootstrap'
            Assert-EvidenceBoundLifecycle $target
            Assert (-not (Test-Path -LiteralPath (Join-Path $target '.claude/adoption-pending.json'))) 'greenfield install incorrectly entered adoption mode'
            Assert (@(Get-ChildItem -LiteralPath $target -Recurse -File | Where-Object { $_.Extension -in @('.sln', '.csproj') }).Count -eq 0) 'warehouse fixture unexpectedly acquired a .NET solution/project'
        })

        $ssdtTarget = New-Target 'warehouse'
        Invoke-WithTestFixture $ssdtTarget ({
            [IO.File]::WriteAllText((Join-Path $ssdtTarget 'Warehouse.sln'), 'Microsoft Visual Studio Solution File, Format Version 12.00')
            [IO.File]::WriteAllText((Join-Path $ssdtTarget 'platform/data/domain/warehouse/Warehouse.sqlproj'), '<Project Sdk="Microsoft.Build.Sql" />')
            $result = Invoke-RootInstaller $ssdtTarget -DryRun
            Assert ($result.Exit -eq 0) "SSDT warehouse auto-detection exited $($result.Exit): $($result.Output)"
            Assert ($result.Output -match 'Stack: dotnet \(via auto-detected warehouse SQL profile \(found signals:') "SSDT solution was misclassified as .NET application evidence: $($result.Output)"
        })
    }

    if ($OnlyWarehouse) { exit (Write-TestSummary 'RootInstallerWarehouse.Tests') }

    It 'warehouse-only auto-detection completes brownfield install and adoption handoff without a solution' {
        $target = New-Target 'warehouse'
        Invoke-WithTestFixture $target ({
            $legacy = "WAREHOUSE LEGACY SENTINEL`nUse the established ETL release flow.`n"
            [IO.File]::WriteAllText((Join-Path $target 'CLAUDE.md'), $legacy, [Text.UTF8Encoding]::new($false))
            & git -C $target add -A 2>$null | Out-Null
            & git -C $target -c user.name=fixture -c user.email=fixture@example.invalid commit -m baseline --quiet 2>$null | Out-Null
            Assert ($LASTEXITCODE -eq 0) 'could not commit the brownfield warehouse fixture'
            $result = Invoke-RootInstaller $target
            Assert ($result.Exit -eq 0) "warehouse-only brownfield install exited $($result.Exit): $($result.Output)"
            Assert ($result.Output -match 'Stack: dotnet \(via auto-detected warehouse SQL profile \(found signals:') "warehouse evidence was not observable: $($result.Output)"
            Assert ($result.Output -match '(?i)type:\s+/adopt') "brownfield handoff did not name /adopt: $($result.Output)"
            $archive = Join-Path $target 'docs/pre-adoption/CLAUDE.md'
            Assert (Test-Path -LiteralPath $archive -PathType Leaf) 'brownfield warehouse instructions were not archived'
            Assert ([IO.File]::ReadAllText($archive) -ceq $legacy) 'brownfield warehouse instructions lost bytes in the archive'
            $marker = Get-Content -LiteralPath (Join-Path $target '.claude/adoption-pending.json') -Raw | ConvertFrom-Json
            Assert ($marker.archivedOriginals -contains 'docs/pre-adoption/CLAUDE.md') 'adoption marker omitted the archived warehouse instructions'
            Assert ((Get-Content -LiteralPath (Join-Path $target '.claude/commands/adopt.md') -Raw) -match '(?s)Phase 7.+/bootstrap') '/adopt does not retain its /bootstrap Phase-7 handoff'
            Assert (@(Get-ChildItem -LiteralPath $target -Recurse -File | Where-Object { $_.Extension -in @('.sln', '.csproj') }).Count -eq 0) 'warehouse fixture unexpectedly acquired a .NET solution/project'
        })
    }

    It 'ordinary dotnet auto-detection remains available' {
        $target = New-Target 'dotnet'
        Invoke-WithTestFixture $target ({
            $result = Invoke-RootInstaller $target -DryRun
            Assert ($result.Exit -eq 0) "ordinary dotnet auto-detection exited $($result.Exit): $($result.Output)"
            Assert ($result.Output -match 'Stack: dotnet \(via auto-detected') "ordinary dotnet target did not select dotnet: $($result.Output)"
        })
        foreach($markerCase in @(
            @{File='package.json';Content='{"dependencies":{"@ANGULAR/CORE":"20.0.0"}}';Label='uppercase package identifier';Pattern='Could not determine the stack'},
            @{File='package.json';Content='{"scripts":{"probe":"echo \"@angular/core\": fake"}}';Label='escaped property-shaped script string';Pattern='Could not determine the stack'},
            @{File='package.json';Content='{"scripts":{"@angular/core":"echo fake"}}';Label='non-dependency package key';Pattern='Could not determine the stack'},
            @{File='nx.json';Content='{"notes":"do not use angular-devkit"}';Label='Nx prose';Pattern='Could not determine the stack'},
            @{File='nx.json';Content='{"notes":"@nx/angular/plugin is not enabled"}';Label='Nx package-prefix prose';Pattern='Could not determine the stack'},
            @{File='nx.json';Content='{"notes":{"plugin":"@nx/angular/plugin"}}';Label='nested notes plugin field';Pattern='Could not determine the stack'},
            @{File='nx.json';Content='{"plugins":["@nx/angular"]}';Label='bare Nx token';Pattern='Could not determine the stack'},
            @{File='nx.json';Content='{"plugins":[{"Plugin":"@nx/angular/plugin"}]}';Label='uppercase Nx plugin field';Pattern='Could not determine the stack'},
            @{File='project.json';Content='{"targets":{"build":{"Executor":"@angular-devkit/build-angular:browser"}}}';Label='uppercase Nx executor field';Pattern='Could not determine the stack'},
            @{File='package.json';Content='{"dependencies":{"@angular/core":"20.0.0"} junk';Label='malformed plausible package';Pattern='Could not inspect repository evidence'},
            @{File='angular.json';Content='{"version":1 junk';Label='malformed Angular workspace';Pattern='Could not inspect repository evidence'},
            @{File='angular.json';Content='[]';Label='array Angular workspace';Pattern='Could not inspect repository evidence'},
            @{File='package.json';Content='"@angular/core"';Label='scalar package marker';Pattern='Could not inspect repository evidence'},
            @{File='angular.json';Content='{"version":1,}';Label='trailing-comma Angular workspace';Pattern='Could not inspect repository evidence'},
            @{File='package.json';Content="{'dependencies':{'@angular/core':'20.0.0'}}";Label='single-quoted package marker';Pattern='Could not inspect repository evidence'},
            @{File='nx.json';Content='{plugin:"@nx/angular"}';Label='unquoted-key Nx marker';Pattern='Could not inspect repository evidence'},
            @{File='package.json';Content='{"dependencies":{"@angular/core":"20.0.0"},"probe":NaN}';Label='non-finite package constant';Pattern='Could not inspect repository evidence'},
            @{File='package.json';Content='{"dependencies":{"@angular/core":"20.0.0"},"probe":01}';Label='leading-zero package number';Pattern='Could not inspect repository evidence'}
        )){
            $caseSensitiveTarget = New-Target 'dotnet'
            Invoke-WithTestFixture $caseSensitiveTarget ({
                Remove-Item -LiteralPath (Join-Path $caseSensitiveTarget 'App.csproj') -Force
                [IO.File]::WriteAllText((Join-Path $caseSensitiveTarget $markerCase.File), $markerCase.Content, [Text.UTF8Encoding]::new($false))
                $before = Get-TargetFingerprint $caseSensitiveTarget
                $result = Invoke-RootInstaller $caseSensitiveTarget -DryRun
                Assert ($result.Exit -eq 2) "$($markerCase.Label) incorrectly routed, exit $($result.Exit): $($result.Output)"
                Assert ($result.Output -match $markerCase.Pattern) "$($markerCase.Label) did not fail at the expected evidence boundary: $($result.Output)"
                Assert ((Get-TargetFingerprint $caseSensitiveTarget) -ceq $before) "$($markerCase.Label) refusal changed target bytes"
            })
        }
    }

    It 'mixed application and Angular-plus-warehouse profiles select monorepo' {
        $target = New-Target 'mixed'
        Invoke-WithTestFixture $target ({
            $result = Invoke-RootInstaller $target -DryRun
            Assert ($result.Exit -eq 0) "mixed auto-detection exited $($result.Exit): $($result.Output)"
            Assert ($result.Output -match 'Stack: monorepo \(via auto-detected') "mixed target did not select monorepo: $($result.Output)"
        })

        $angularWarehouse = New-Target 'angularwarehouse'
        Invoke-WithTestFixture $angularWarehouse ({
            $result = Invoke-RootInstaller $angularWarehouse
            Assert ($result.Exit -eq 0) "Angular-plus-warehouse auto-detection exited $($result.Exit): $($result.Output)"
            Assert ($result.Output -match 'Stack: monorepo \(via auto-detected mixed repo \(found Angular \+ warehouse SQL profiles: layers, loads, control, history\)\)') "Angular-plus-warehouse target did not select monorepo with observable categories: $($result.Output)"
            Assert-EvidenceBoundLifecycle $angularWarehouse
        })
    }

    It 'root dispatcher forwards deliberate downgrade and dry-run flags to every stack' {
        foreach ($stack in @('dotnet','angular','monorepo')) {
            $target = New-Target 'dotnet'
            Invoke-WithTestFixture $target ({
                New-Item -ItemType Directory -Force -Path (Join-Path $target '.claude') | Out-Null
                [IO.File]::WriteAllText((Join-Path $target '.claude/framework-version.json'), "{`"version`":`"99.0.0`",`"template`":`"$stack`"}", [Text.UTF8Encoding]::new($false))
                $before = Get-TargetFingerprint $target
                $result = Invoke-RootInstaller $target $stack -DryRun -AllowDowngrade
                Assert ($result.Exit -eq 0) "$stack flag forwarding exited $($result.Exit): $($result.Output)"
                Assert ($result.Output -match 'allow-downgrade accepted|AllowDowngrade accepted') "$stack did not observe the downgrade override"
                Assert ($result.Output -match 'Dry run complete; target was not modified') "$stack did not observe the dry-run flag"
                Assert ((Get-TargetFingerprint $target) -ceq $before) "$stack root dry-run changed target bytes"
            })
        }
        $stampedTarget = New-Target 'dotnet'
        Invoke-WithTestFixture $stampedTarget ({
            New-Item -ItemType Directory -Force -Path (Join-Path $stampedTarget '.claude') | Out-Null
            [IO.File]::WriteAllText((Join-Path $stampedTarget '.claude/framework-version.json'), '{"version":"99.0.0","template":"dotnet","decimal":0.01,"exponent":1e01,"negativeExponent":1e-01}', [Text.UTF8Encoding]::new($false))
            $before = Get-TargetFingerprint $stampedTarget
            $stamped = Invoke-RootInstaller $stampedTarget -DryRun -AllowDowngrade
            Assert ($stamped.Exit -eq 0) "valid lowercase update stamp exited $($stamped.Exit): $($stamped.Output)"
            Assert ($stamped.Output -match 'Stack: dotnet \(via update stamp \(\.claude/framework-version\.json template=dotnet\)\)') "valid lowercase update stamp did not select its recorded stack: $($stamped.Output)"
            Assert ($stamped.Output -match 'allow-downgrade accepted|AllowDowngrade accepted') 'valid stamped update did not forward the downgrade override'
            Assert ($stamped.Output -match 'Dry run complete; target was not modified') 'valid stamped update did not forward dry-run'
            Assert ((Get-TargetFingerprint $stampedTarget) -ceq $before) 'valid stamped update changed target bytes'
        })
        foreach ($case in @(
            @{ Name='uppercase explicit stack'; Stack='DOTNET'; Stamp=$null; Pattern='Unknown stack' },
            @{ Name='uppercase stamped stack'; Stack=''; Stamp='{"version":"99.0.0","template":"DOTNET"}'; Pattern='unknown stack' },
            @{ Name='malformed stamped JSON containing a plausible template'; Stack=''; Stamp='junk {"version":"99.0.0","template":"dotnet"}'; Pattern='invalid JSON|cannot be verified' },
            @{ Name='trailing-comma stamped JSON'; Stack=''; Stamp='{"version":"99.0.0","template":"dotnet",}'; Pattern='invalid JSON|cannot be verified' },
            @{ Name='commented stamped JSON'; Stack=''; Stamp='{/*comment*/"version":"99.0.0","template":"dotnet"}'; Pattern='invalid JSON|cannot be verified' },
            @{ Name='leading-zero stamped JSON'; Stack=''; Stamp='{"version":"99.0.0","template":"dotnet","probe":01}'; Pattern='invalid JSON|cannot be verified' },
            @{ Name='uppercase template property'; Stack=''; Stamp='{"version":"99.0.0","Template":"dotnet"}'; Pattern='no non-empty string|cannot be verified' },
            @{ Name='valid stamped JSON without a template'; Stack=''; Stamp='{"version":"99.0.0"}'; Pattern='no non-empty string' },
            @{ Name='valid stamped JSON with a whitespace-only template'; Stack=''; Stamp='{"version":"99.0.0","template":"   "}'; Pattern='no non-empty string' },
            @{ Name='valid stamped one-object JSON array'; Stack=''; Stamp='[{"version":"99.0.0","template":"dotnet"}]'; Pattern='invalid JSON|no non-empty string' }
        )) {
            $target = New-Target 'dotnet'
            Invoke-WithTestFixture $target ({
                if ($null -ne $case.Stamp) {
                    New-Item -ItemType Directory -Force -Path (Join-Path $target '.claude') | Out-Null
                    [IO.File]::WriteAllText((Join-Path $target '.claude/framework-version.json'), $case.Stamp, [Text.UTF8Encoding]::new($false))
                }
                $before = Get-TargetFingerprint $target
                $result = Invoke-RootInstaller $target $case.Stack -DryRun
                Assert ($result.Exit -eq 2) "$($case.Name) exited $($result.Exit): $($result.Output)"
                Assert ($result.Output -match $case.Pattern) "$($case.Name) did not fail actionably: $($result.Output)"
                Assert ((Get-TargetFingerprint $target) -ceq $before) "$($case.Name) changed target bytes"
            })
        }
    }

    It 'B-298 root dispatcher forwards -AllowDirtyTree to the stack installer' {
        $target = New-Target 'dotnet'
        Invoke-WithTestFixture $target ({
            # The untracked App.csproj and CLAUDE.md make a dirty brownfield Git target. The stack
            # installer's refusal names -AllowDirtyTree, and the root dispatcher rejected that switch.
            [IO.File]::WriteAllText((Join-Path $target 'CLAUDE.md'), "# consumer instructions`n", [Text.UTF8Encoding]::new($false))
            $before = Get-TargetFingerprint $target
            $refused = Invoke-RootInstaller $target
            Assert ($refused.Exit -eq 4 -and $refused.Output -match 'use -AllowDirtyTree') "the dirty brownfield target was not refused with the override named, exit $($refused.Exit): $($refused.Output)"
            Assert ((Get-TargetFingerprint $target) -ceq $before) 'the dirty-tree refusal changed target bytes'
            $override = Invoke-RootInstaller $target -AllowDirtyTree
            Assert ($override.Exit -eq 0 -and $override.Output -match 'override: -AllowDirtyTree accepted') "the root dispatcher did not forward -AllowDirtyTree, exit $($override.Exit): $($override.Output)"
            Assert (Test-Path -LiteralPath (Join-Path $target 'docs/pre-adoption/CLAUDE.md') -PathType Leaf) "the forwarded override did not archive the collision: $($override.Output)"
        })
    }

    # One case on both hosts keeps the CI case-count parity: only Windows PowerShell 5.1 reads the
    # call operator's path as a wildcard, and PowerShell 7 must go on running the literal path.
    It 'B-302 the root dispatcher in a bracketed clone calls its own stack installer, never a sibling''s' {
        $parent = Join-Path ([IO.Path]::GetTempPath()) ('b302-' + [guid]::NewGuid().ToString('N'))
        try {
            # Read as a wildcard, 'fw[s]' matches sibling 'fws': a 5.1 console user who changed into
            # the clone and typed .\install.ps1 got this dispatcher and the sibling's stack installer.
            # Escaping the path for 5.1 then broke a clone named 'fw`[t]' there (command not found).
            $target = Join-Path $parent 'target'
            [void][IO.Directory]::CreateDirectory($target)
            foreach ($name in @('fw[s]', 'fws', 'fw`[t]')) {
                $root = Join-Path $parent $name
                [void][IO.Directory]::CreateDirectory((Join-Path $root 'dist/dotnet/scripts'))
                Copy-Item -LiteralPath (Join-Path $repo 'install.ps1') -Destination (Join-Path $root 'install.ps1')
                $stub = "param([string]`$Target, [switch]`$WhatIf, [switch]`$AllowDowngrade, [switch]`$AllowDirtyTree, [switch]`$AllowOutdated)`nWrite-Output 'DELEGATE: $name'`nWrite-Output ('CWD: ' + (Get-Location).ProviderPath)`nexit 0`n"
                [IO.File]::WriteAllText((Join-Path $root 'dist/dotnet/scripts/install.ps1'), $stub, [Text.UTF8Encoding]::new($true))
            }
            foreach ($clone in @('fw[s]', 'fw`[t]')) {
                $clonePath = Join-Path $parent $clone
                $command = "Set-Location -LiteralPath '$clonePath'; .\install.ps1 -Stack dotnet '$target'; 'LOCATION: ' + (Get-Location).ProviderPath"
                $out = @(& (Get-PsExe) -NoProfile -ExecutionPolicy Bypass -Command $command 2>&1 | ForEach-Object { $_.ToString() }) -join "`n"
                $exit = $LASTEXITCODE
                Assert ($exit -eq 0 -and $out.Contains("DELEGATE: $clone")) "the dispatcher in clone '$clone' did not call its own stack installer (exit $exit): $out"
                Assert ($out -notmatch 'DELEGATE: fws') "the dispatcher in clone '$clone' called the sibling's stack installer: $out"
                # The stack installer runs from the caller's location, as it always did: started from the
                # clone's scripts folder, git could not start once that path passed 260 characters.
                Assert ($out -match ('(?m)^CWD: ' + [regex]::Escape($clonePath) + '\r?$')) "the stack installer did not run from the caller's location in clone '$clone': $out"
                # An interactive console shares the location, so the dispatcher must hand it back.
                Assert ($out -match ('(?m)^LOCATION: ' + [regex]::Escape($clonePath) + '\r?$')) "the dispatcher did not restore the caller's location in clone '$clone': $out"
            }
            # Returning to a caller's folder that no longer exists must not cost the install. (The
            # plain clone keeps 5.1's wildcard reading of an absolute path out of this fixture.)
            $gone = Join-Path $parent 'gone'
            [void][IO.Directory]::CreateDirectory($gone)
            $command = "Set-Location -LiteralPath '$gone'; [IO.Directory]::Delete('$gone'); & '$(Join-Path $parent 'fws\install.ps1')' -Stack dotnet '$target'"
            $out = @(& (Get-PsExe) -NoProfile -ExecutionPolicy Bypass -Command $command 2>&1 | ForEach-Object { $_.ToString() }) -join "`n"
            $exit = $LASTEXITCODE
            Assert ($exit -eq 0 -and $out.Contains('DELEGATE: fws')) "a caller whose folder was deleted lost the install (exit $exit): $out"
        } finally { Remove-Item -LiteralPath $parent -Recurse -Force -ErrorAction SilentlyContinue }
    }

    # A clone left 68 commits behind master installed an old release, and nothing said so until after
    # /bootstrap had run on it.
    It 'B-324 an install from a framework clone behind its remote stops until the clone is updated or -AllowOutdated is passed' {
        $parent = Join-Path ([IO.Path]::GetTempPath()) ('b324-' + [guid]::NewGuid().ToString('N'))
        $savedCheck = $env:ATL_SOURCE_CHECK
        try {
            $env:ATL_SOURCE_CHECK = $null
            $fw = New-B324Clone $parent
            $parts = $fw.Version.Split('.')
            $newer = "$($parts[0]).$($parts[1]).$([int]$parts[2] + 1)"
            # A partial clone taken now fetches missing objects on demand. Counting to a tip it never
            # fetched made git fetch that tip: slowly from a slow remote, and past the time limit.
            $partial = Join-Path $parent 'partial'
            Invoke-B324Git $fw.Remote @('config', 'uploadpack.allowFilter', 'true')
            Invoke-B324Git $parent @('clone', '-q', '--no-local', '--filter=blob:none', $fw.Remote, $partial)
            # The remote gains a release commit and tag that this clone then drops again.
            foreach ($step in @(@('commit', '-q', '--allow-empty', '-m', 'next release'), @('tag', "v$newer"),
                    @('push', '-q', 'origin', 'master', "v$newer"), @('reset', '-q', '--hard', 'HEAD~1'), @('tag', '-d', "v$newer"))) {
                Invoke-B324Git $fw.Clone $step
            }
            $before = Get-TargetFingerprint $fw.Target
            $refused = Invoke-B324Installer $fw.Clone $fw.Target
            Assert ($refused.Exit -eq 4) "an install from a clone behind its remote was not refused, exit $($refused.Exit): $($refused.Output)"
            Assert ($refused.Output -match ('origin has release v' + [regex]::Escape($newer) + ' and this copy is v' + [regex]::Escape($fw.Version))) "the refusal does not name the newer release: $($refused.Output)"
            Assert ($refused.Output -match '1 commit behind origin/master' -and $refused.Output -match ' pull\b' -and $refused.Output -match '-AllowOutdated') "the refusal does not say how far behind, how to update, or how to override: $($refused.Output)"
            Assert ((Get-TargetFingerprint $fw.Target) -ceq $before) 'the refusal changed target bytes'
            $override = Invoke-B324Installer $fw.Clone $fw.Target -DryRun -AllowOutdated
            Assert ($override.Exit -eq 0 -and $override.Output -match 'override: -AllowOutdated accepted: origin has release') "the root dispatcher did not forward -AllowOutdated, exit $($override.Exit): $($override.Output)"
            $objects = @(Get-ChildItem -LiteralPath (Join-Path $partial '.git/objects') -Recurse -File -Force | ForEach-Object { $_.FullName } | Sort-Object) -join "`n"
            $unfetched = Invoke-B324Installer $partial $fw.Target -DryRun
            Assert ($unfetched.Exit -eq 4 -and $unfetched.Output -match 'origin/master has commits this checkout has not fetched') "a partial clone whose upstream moved on was not refused as unfetched, exit $($unfetched.Exit): $($unfetched.Output)"
            Assert ((@(Get-ChildItem -LiteralPath (Join-Path $partial '.git/objects') -Recurse -File -Force | ForEach-Object { $_.FullName } | Sort-Object) -join "`n") -ceq $objects) 'the check fetched objects into the partial clone'
            # The README's route: a release-tag checkout, told which newer tag to check out.
            Invoke-B324Git $fw.Clone @('checkout', '-q', "v$($fw.Version)")
            $detached = Invoke-B324Installer $fw.Clone $fw.Target -DryRun
            Assert ($detached.Exit -eq 4 -and $detached.Output -match ('checkout v' + [regex]::Escape($newer))) "an older release-tag checkout was not refused with the newer tag named, exit $($detached.Exit): $($detached.Output)"
        } finally {
            $env:ATL_SOURCE_CHECK = $savedCheck
            Remove-Item -LiteralPath $parent -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'B-324 a current clone installs saying so; a vendored copy, an unreachable remote or a silent one is reported unchecked and does not hold the install' {
        $parent = Join-Path ([IO.Path]::GetTempPath()) ('b324-' + [guid]::NewGuid().ToString('N'))
        $savedCheck = $env:ATL_SOURCE_CHECK
        $savedSsh = $env:GIT_SSH_COMMAND
        try {
            $env:ATL_SOURCE_CHECK = $null
            $fw = New-B324Clone $parent
            $current = Invoke-B324Installer $fw.Clone $fw.Target -DryRun
            Assert ($current.Exit -eq 0 -and $current.Output -match ('source: checked against origin: no release newer than v' + [regex]::Escape($fw.Version) + ', not behind origin/master')) "a current clone was not reported current, exit $($current.Exit): $($current.Output)"
            # A clone that took the remote's tip by URL, which leaves its tracking ref behind, is current too.
            $other = Join-Path $parent 'other'
            Invoke-B324Git $parent @('clone', '-q', $fw.Remote, $other)
            foreach ($step in @(@('commit', '-q', '--allow-empty', '-m', 'unreleased'), @('push', '-q', 'origin', 'master'))) { Invoke-B324Git $other $step }
            foreach ($step in @(@('fetch', '-q', $fw.Remote, 'master'), @('merge', '-q', '--ff-only', 'FETCH_HEAD'))) { Invoke-B324Git $fw.Clone $step }
            $byUrl = Invoke-B324Installer $fw.Clone $fw.Target -DryRun
            Assert ($byUrl.Exit -eq 0 -and $byUrl.Output -match 'source: checked against origin: .*not behind origin/master') "a clone at the remote's tip with a stale tracking ref was not reported current, exit $($byUrl.Exit): $($byUrl.Output)"
            # A copy inside another repository is not that repository's clone: its tags must not refuse the
            # copy, nor its update advice move the host. One copy is committed below the host's root; the
            # other is committed where a clone keeps its dist, with the root dispatcher beside it.
            $consumer = Join-Path $parent 'consumer'
            foreach ($root in @((Join-Path $consumer 'vendor/fw'), $consumer)) {
                [void][IO.Directory]::CreateDirectory((Join-Path $root 'dist'))
                Copy-Item -LiteralPath (Join-Path $fw.Clone 'dist/dotnet') -Destination (Join-Path $root 'dist/dotnet') -Recurse
                Copy-Item -LiteralPath (Join-Path $fw.Clone 'install.ps1') -Destination (Join-Path $root 'install.ps1')
            }
            & git init -q --bare (Join-Path $parent 'consumer.git') 2>&1 | Out-Null
            foreach ($step in @(@('init', '-q', '-b', 'main'), @('add', '-A', '-f'), @('commit', '-q', '-m', 'vendored'), @('tag', 'v99.0.0'),
                    @('remote', 'add', 'origin', (Join-Path $parent 'consumer.git')), @('push', '-q', '-u', 'origin', 'main', 'v99.0.0'))) {
                Invoke-B324Git $consumer $step
            }
            foreach ($copy in @((Join-Path $consumer 'vendor/fw'), $consumer)) {
                $vendored = Invoke-B324Installer $copy $fw.Target -DryRun
                Assert ($vendored.Exit -eq 0 -and $vendored.Output -match 'NOTE: could not check that this framework copy is up to date: this copy is not tracked at dist/dotnet/ of a Git clone of the framework') "a copy inside another repository ($copy) was judged by that repository, exit $($vendored.Exit): $($vendored.Output)"
            }
            Invoke-B324Git $fw.Clone @('remote', 'set-url', 'origin', (Join-Path $parent 'missing.git'))
            $unreachable = Invoke-B324Installer $fw.Clone $fw.Target -DryRun
            Assert ($unreachable.Exit -eq 0 -and $unreachable.Output -match 'NOTE: could not check that this framework copy is up to date: git ls-remote origin failed') "an unreachable remote was not reported unchecked, exit $($unreachable.Exit): $($unreachable.Output)"
            Assert ($unreachable.Output -notmatch 'source: checked') "an unreachable remote was reported as checked: $($unreachable.Output)"
            # A transport that never answers, as a black-holed network or a waiting prompt would.
            Invoke-B324Git $fw.Clone @('remote', 'set-url', 'origin', 'ssh://atl-b324.invalid/fw.git')
            $env:GIT_SSH_COMMAND = "sh -c 'sleep 60'"
            $clock = [Diagnostics.Stopwatch]::StartNew()
            $silent = Invoke-B324Installer $fw.Clone $fw.Target -DryRun
            $clock.Stop()
            Assert ($silent.Exit -eq 0 -and $silent.Output -match 'NOTE: could not check .*origin did not finish within 10 seconds') "a silent remote was not reported unchecked, exit $($silent.Exit): $($silent.Output)"
            Assert ($clock.Elapsed.TotalSeconds -lt 45) "a silent remote held the install for $([int]$clock.Elapsed.TotalSeconds) s"
        } finally {
            $env:ATL_SOURCE_CHECK = $savedCheck
            $env:GIT_SSH_COMMAND = $savedSsh
            Remove-Item -LiteralPath $parent -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
if (-not $SkipRedTest) {
    It 'a PowerShell mutation that removes warehouse auto-routing makes this suite red and restores bytes' {
            Invoke-MutationRedTest -TargetFile (Join-Path $repo 'install.ps1') -ScratchSourceRoot $repo `
                -Find ('$Stack = ''dotnet''' + "`n" + '                $reason = "auto-detected warehouse SQL profile (found signals: $($warehouseSignals -join '', ''))"') `
                -Replacement "Die 'mutated warehouse refusal'" -Command {
                    param($scratchTarget, $scratchRoot)
                    $test = Join-Path $scratchRoot '.claude/hooks/tests/RootInstallerWarehouse.Tests.ps1'
                    $atlMutationTranscript = @(& (Get-PsExe) -NoProfile -File $test -SkipRedTest -OnlyWarehouse 2>&1 | ForEach-Object { $_.ToString() })
                    $atlMutationExit = [int]$LASTEXITCODE
                    $atlMutationTranscript | ForEach-Object { Write-Host $_ }
                    $atlMutationText = $atlMutationTranscript -join "`n"
                    $atlIntendedRed = $atlMutationExit -ne 0 -and
                        $atlMutationText.Contains('warehouse-only greenfield install exited 2') -and
                        $atlMutationText.Contains('mutated warehouse refusal')
                    if (-not $atlIntendedRed) {
                        [Console]::Error.WriteLine('PowerShell mutation went red without its intended warehouse assertion and sentinel')
                        $global:LASTEXITCODE = 0
                    } else {
                        $global:LASTEXITCODE = $atlMutationExit
                    }
                } | Out-Null
    }
}

exit (Write-TestSummary 'RootInstallerWarehouse.Tests')
