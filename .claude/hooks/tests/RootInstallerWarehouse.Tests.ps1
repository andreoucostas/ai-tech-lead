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
        @{ Path = 'CLAUDE.md'; Patterns = @('delivery-profile superset', 'not evidence that'); Forbidden = @('What this application does', 'Missing unit tests for public methods') },
        @{ Path = 'AGENTS.md'; Patterns = @('delivery-profile superset', 'not evidence that'); Forbidden = @('Missing unit tests for public methods') },
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
        @{ Path = '.github/instructions/framework-rules.instructions.md'; Patterns = @('repository evidence', 'not available', 'manual/CI-only', 'non-mutating validation/dry-run'); Forbidden = @('Each subtask must leave the codebase compilable and test-passing.', 'Verify all tests pass') },
        @{ Path = '.github/PULL_REQUEST_TEMPLATE.md'; Patterns = @('applicable harness', 'Verification Commands', 'not available'); Forbidden = @('Tests added/updated for changed behaviour', 'dotnet build && dotnet test') },
        @{ Path = '.github/copilot-instructions.md'; Patterns = @('delivery-profile superset', 'not available'); Forbidden = @('No suite anywhere?', 'xUnit + NSubstitute') },
        @{ Path = '.github/prompts/fix.prompt.md'; Patterns = @('repository-evidenced', 'not available'); Forbidden = @('Never skip the test') },
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

function Invoke-RootInstaller([string]$Target, [string]$Stack = '', [switch]$DryRun, [switch]$AllowDowngrade) {
    $arguments = @('-NoProfile', '-File', (Join-Path $repo 'install.ps1'))
    if ($Stack) { $arguments += @('-Stack', $Stack) }
    if ($DryRun) { $arguments += '-WhatIf' }
    if ($AllowDowngrade) { $arguments += '-AllowDowngrade' }
    $arguments += $Target
    $out = @(& (Get-PsExe) @arguments 2>&1 | ForEach-Object { $_.ToString() })
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
