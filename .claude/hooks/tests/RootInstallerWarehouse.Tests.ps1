[CmdletBinding()]
param(
    [switch]$SkipRedTest,
    [ValidateSet('ps1', 'sh')][string]$OnlyTwin,
    [switch]$OnlyWarehouse
)

. (Join-Path $PSScriptRoot '_HookHarness.ps1')
. (Join-Path $PSScriptRoot '_MutationHelper.ps1')
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$bash = Get-BashPath

function ConvertTo-PosixPath([string]$Path) {
    if ($Path -match '^([A-Za-z]):[\\/](.*)$') { return '/' + $Matches[1].ToLowerInvariant() + '/' + $Matches[2].Replace('\', '/') }
    return $Path.Replace('\', '/')
}

function Resolve-HostPython {
    foreach ($candidate in @($env:ATL_TEST_PYTHON, 'python3', 'python', 'py')) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        $command = Get-Command $candidate -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $command -or -not $command.Source) { continue }
        try {
            $probe = '{}' | & $command.Source -c 'import json,sys; json.load(sys.stdin); sys.stdout.write("ok")' 2>$null
            if ($probe -eq 'ok') { return $command.Source }
        } catch { }
    }
    return $null
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
    # Keep the fixture beneath the workspace parent so both Windows PowerShell and Git Bash
    # resolve the same physical path rather than their distinct /tmp mounts.
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
        @{ Path = '.claude/hooks/route-prompt.sh'; Patterns = @('repository evidence', 'not available', 'manual/CI-only', 'non-mutating validation/dry-run'); Forbidden = @('2. Write a failing regression test BEFORE touching production code') },
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

function Invoke-RootInstaller([string]$Twin, [string]$Target, [string]$Stack = '', [switch]$DryRun, [switch]$AllowDowngrade) {
    if ($Twin -eq 'ps1') {
        $arguments = @('-NoProfile', '-File', (Join-Path $repo 'install.ps1'))
        if ($Stack) { $arguments += @('-Stack', $Stack) }
        if ($DryRun) { $arguments += '-WhatIf' }
        if ($AllowDowngrade) { $arguments += '-AllowDowngrade' }
        $arguments += $Target
        $out = @(& (Get-PsExe) @arguments 2>&1 | ForEach-Object { $_.ToString() })
    } else {
        $arguments = @((Join-Path $repo 'install.sh'))
        if ($Stack) { $arguments += @('--stack', $Stack) }
        if ($DryRun) { $arguments += '--dry-run' }
        if ($AllowDowngrade) { $arguments += '--allow-downgrade' }
        $arguments += $Target
        $out = @(& $bash @arguments 2>&1 | ForEach-Object { $_.ToString() })
    }
    return [pscustomobject]@{ Exit = [int]$LASTEXITCODE; Output = ($out -join "`n") }
}

Reset-Tests
foreach ($twin in @('ps1', 'sh')) {
    if ($OnlyTwin -and $twin -ne $OnlyTwin) { continue }
    if ($twin -eq 'sh' -and -not $bash) { Skip "warehouse-only lifecycle ($twin)" 'no bash'; continue }

    It "warehouse-only auto-detection completes greenfield install without a solution ($twin)" {
        $singleCategoryTarget = New-Target 'singlewarehouse'
        try {
            $before = Get-TargetFingerprint $singleCategoryTarget
            $singleCategory = Invoke-RootInstaller $twin $singleCategoryTarget
            Assert ($singleCategory.Exit -eq 2) "one warehouse category should not auto-route, exit $($singleCategory.Exit): $($singleCategory.Output)"
            Assert ($singleCategory.Output -match 'Could not determine the stack') "one warehouse category did not produce the ordinary explicit-stack refusal: $($singleCategory.Output)"
            Assert ($singleCategory.Output -notmatch 'Stack: dotnet') "repeated matches from one category incorrectly selected dotnet: $($singleCategory.Output)"
            Assert ((Get-TargetFingerprint $singleCategoryTarget) -ceq $before) 'one-category refusal changed target bytes'
        } finally { Remove-Item -LiteralPath $singleCategoryTarget -Recurse -Force }

        $target = New-Target 'warehouse'
        try {
            $result = Invoke-RootInstaller $twin $target
            Assert ($result.Exit -eq 0) "warehouse-only greenfield install exited $($result.Exit): $($result.Output)"
            Assert ($result.Output -match 'Stack: dotnet \(via auto-detected warehouse SQL profile \(found signals: layers, loads, control, history\)\)') "warehouse categories or their order diverged from the shared classifier: $($result.Output)"
            Assert ($result.Output -match '(?i)type:\s+/bootstrap') "greenfield handoff did not name /bootstrap: $($result.Output)"
            Assert (Test-Path -LiteralPath (Join-Path $target '.claude/commands/bootstrap.md') -PathType Leaf) 'greenfield install omitted /bootstrap'
            Assert-EvidenceBoundLifecycle $target
            Assert (-not (Test-Path -LiteralPath (Join-Path $target '.claude/adoption-pending.json'))) 'greenfield install incorrectly entered adoption mode'
            Assert (@(Get-ChildItem -LiteralPath $target -Recurse -File -Include *.sln,*.csproj).Count -eq 0) 'warehouse fixture unexpectedly acquired a .NET solution/project'
        } finally { Remove-Item -LiteralPath $target -Recurse -Force }

        $ssdtTarget = New-Target 'warehouse'
        try {
            [IO.File]::WriteAllText((Join-Path $ssdtTarget 'Warehouse.sln'), 'Microsoft Visual Studio Solution File, Format Version 12.00')
            [IO.File]::WriteAllText((Join-Path $ssdtTarget 'platform/data/domain/warehouse/Warehouse.sqlproj'), '<Project Sdk="Microsoft.Build.Sql" />')
            $result = Invoke-RootInstaller $twin $ssdtTarget -DryRun
            Assert ($result.Exit -eq 0) "SSDT warehouse auto-detection exited $($result.Exit): $($result.Output)"
            Assert ($result.Output -match 'Stack: dotnet \(via auto-detected warehouse SQL profile \(found signals:') "SSDT solution was misclassified as .NET application evidence: $($result.Output)"
        } finally { Remove-Item -LiteralPath $ssdtTarget -Recurse -Force }
    }

    if ($OnlyWarehouse) { continue }

    It "warehouse-only auto-detection completes brownfield install and adoption handoff without a solution ($twin)" {
        $target = New-Target 'warehouse'
        try {
            $legacy = "WAREHOUSE LEGACY SENTINEL`nUse the established ETL release flow.`n"
            [IO.File]::WriteAllText((Join-Path $target 'CLAUDE.md'), $legacy, [Text.UTF8Encoding]::new($false))
            & git -C $target add -A 2>$null | Out-Null
            & git -C $target -c user.name=fixture -c user.email=fixture@example.invalid commit -m baseline --quiet 2>$null | Out-Null
            Assert ($LASTEXITCODE -eq 0) 'could not commit the brownfield warehouse fixture'
            $result = Invoke-RootInstaller $twin $target
            Assert ($result.Exit -eq 0) "warehouse-only brownfield install exited $($result.Exit): $($result.Output)"
            Assert ($result.Output -match 'Stack: dotnet \(via auto-detected warehouse SQL profile \(found signals:') "warehouse evidence was not observable: $($result.Output)"
            Assert ($result.Output -match '(?i)type:\s+/adopt') "brownfield handoff did not name /adopt: $($result.Output)"
            $archive = Join-Path $target 'docs/pre-adoption/CLAUDE.md'
            Assert (Test-Path -LiteralPath $archive -PathType Leaf) 'brownfield warehouse instructions were not archived'
            Assert ([IO.File]::ReadAllText($archive) -ceq $legacy) 'brownfield warehouse instructions lost bytes in the archive'
            $marker = Get-Content -LiteralPath (Join-Path $target '.claude/adoption-pending.json') -Raw | ConvertFrom-Json
            Assert ($marker.archivedOriginals -contains 'docs/pre-adoption/CLAUDE.md') 'adoption marker omitted the archived warehouse instructions'
            Assert ((Get-Content -LiteralPath (Join-Path $target '.claude/commands/adopt.md') -Raw) -match '(?s)Phase 7.+/bootstrap') '/adopt does not retain its /bootstrap Phase-7 handoff'
            Assert (@(Get-ChildItem -LiteralPath $target -Recurse -File -Include *.sln,*.csproj).Count -eq 0) 'warehouse fixture unexpectedly acquired a .NET solution/project'
        } finally { Remove-Item -LiteralPath $target -Recurse -Force }
    }

    It "ordinary dotnet auto-detection remains available ($twin)" {
        $target = New-Target 'dotnet'
        try {
            $result = Invoke-RootInstaller $twin $target -DryRun
            Assert ($result.Exit -eq 0) "ordinary dotnet auto-detection exited $($result.Exit): $($result.Output)"
            Assert ($result.Output -match 'Stack: dotnet \(via auto-detected') "ordinary dotnet target did not select dotnet: $($result.Output)"
        } finally { Remove-Item -LiteralPath $target -Recurse -Force }
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
            try {
                Remove-Item -LiteralPath (Join-Path $caseSensitiveTarget 'App.csproj') -Force
                [IO.File]::WriteAllText((Join-Path $caseSensitiveTarget $markerCase.File), $markerCase.Content, [Text.UTF8Encoding]::new($false))
                $before = Get-TargetFingerprint $caseSensitiveTarget
                $result = Invoke-RootInstaller $twin $caseSensitiveTarget -DryRun
                Assert ($result.Exit -eq 2) "$($markerCase.Label) incorrectly routed, exit $($result.Exit): $($result.Output)"
                Assert ($result.Output -match $markerCase.Pattern) "$($markerCase.Label) did not fail at the expected evidence boundary: $($result.Output)"
                Assert ((Get-TargetFingerprint $caseSensitiveTarget) -ceq $before) "$($markerCase.Label) refusal changed target bytes"
            } finally { Remove-Item -LiteralPath $caseSensitiveTarget -Recurse -Force }
        }
    }

    It "mixed application and Angular-plus-warehouse profiles select monorepo ($twin)" {
        $target = New-Target 'mixed'
        try {
            $result = Invoke-RootInstaller $twin $target -DryRun
            Assert ($result.Exit -eq 0) "mixed auto-detection exited $($result.Exit): $($result.Output)"
            Assert ($result.Output -match 'Stack: monorepo \(via auto-detected') "mixed target did not select monorepo: $($result.Output)"
        } finally { Remove-Item -LiteralPath $target -Recurse -Force }

        $angularWarehouse = New-Target 'angularwarehouse'
        try {
            $result = Invoke-RootInstaller $twin $angularWarehouse
            Assert ($result.Exit -eq 0) "Angular-plus-warehouse auto-detection exited $($result.Exit): $($result.Output)"
            Assert ($result.Output -match 'Stack: monorepo \(via auto-detected mixed repo \(found Angular \+ warehouse SQL profiles: layers, loads, control, history\)\)') "Angular-plus-warehouse target did not select monorepo with observable categories: $($result.Output)"
            Assert-EvidenceBoundLifecycle $angularWarehouse
        } finally { Remove-Item -LiteralPath $angularWarehouse -Recurse -Force }
    }

    It "root dispatcher forwards deliberate downgrade and dry-run flags to every stack ($twin)" {
        foreach ($stack in @('dotnet','angular','monorepo')) {
            $target = New-Target 'dotnet'
            try {
                New-Item -ItemType Directory -Force -Path (Join-Path $target '.claude') | Out-Null
                [IO.File]::WriteAllText((Join-Path $target '.claude/framework-version.json'), "{`"version`":`"99.0.0`",`"template`":`"$stack`"}", [Text.UTF8Encoding]::new($false))
                $before = Get-TargetFingerprint $target
                $result = Invoke-RootInstaller $twin $target $stack -DryRun -AllowDowngrade
                Assert ($result.Exit -eq 0) "$stack flag forwarding exited $($result.Exit): $($result.Output)"
                Assert ($result.Output -match 'allow-downgrade accepted|AllowDowngrade accepted') "$stack did not observe the downgrade override"
                Assert ($result.Output -match 'Dry run complete; target was not modified') "$stack did not observe the dry-run flag"
                Assert ((Get-TargetFingerprint $target) -ceq $before) "$stack root dry-run changed target bytes"
            } finally { Remove-Item -LiteralPath $target -Recurse -Force }
        }
        $stampedTarget = New-Target 'dotnet'
        try {
            New-Item -ItemType Directory -Force -Path (Join-Path $stampedTarget '.claude') | Out-Null
            [IO.File]::WriteAllText((Join-Path $stampedTarget '.claude/framework-version.json'), '{"version":"99.0.0","template":"dotnet","decimal":0.01,"exponent":1e01,"negativeExponent":1e-01}', [Text.UTF8Encoding]::new($false))
            $before = Get-TargetFingerprint $stampedTarget
            $stamped = Invoke-RootInstaller $twin $stampedTarget -DryRun -AllowDowngrade
            Assert ($stamped.Exit -eq 0) "valid lowercase update stamp exited $($stamped.Exit): $($stamped.Output)"
            Assert ($stamped.Output -match 'Stack: dotnet \(via update stamp \(\.claude/framework-version\.json template=dotnet\)\)') "valid lowercase update stamp did not select its recorded stack: $($stamped.Output)"
            Assert ($stamped.Output -match 'allow-downgrade accepted|AllowDowngrade accepted') 'valid stamped update did not forward the downgrade override'
            Assert ($stamped.Output -match 'Dry run complete; target was not modified') 'valid stamped update did not forward dry-run'
            Assert ((Get-TargetFingerprint $stampedTarget) -ceq $before) 'valid stamped update changed target bytes'
            if ($twin -eq 'sh' -and (Resolve-HostPython)) {
                $brokenJqBin = Join-Path ([IO.Path]::GetTempPath()) ('root-broken-jq-' + [guid]::NewGuid().ToString('N'))
                $oldPath = $env:PATH
                try {
                    New-Item -ItemType Directory -Force -Path $brokenJqBin | Out-Null
                    [IO.File]::WriteAllText((Join-Path $brokenJqBin 'jq'), "#!/bin/sh`nexit 49`n", [Text.UTF8Encoding]::new($false))
                    $posixJq = ConvertTo-PosixPath (Join-Path $brokenJqBin 'jq')
                    $null = & $bash -c ('PATH="/usr/bin:/bin:/usr/local/bin:$PATH" chmod +x "{0}"' -f $posixJq) 2>$null
                    Assert ($LASTEXITCODE -eq 0) 'could not make broken jq fixture executable'
                    $env:PATH = $brokenJqBin + [IO.Path]::PathSeparator + $oldPath
                    $fallback = Invoke-RootInstaller $twin $stampedTarget -DryRun -AllowDowngrade
                    Assert ($fallback.Exit -eq 0) "broken jq suppressed the working Python fallback: $($fallback.Output)"
                    Assert ($fallback.Output -match 'Stack: dotnet \(via update stamp') "Python fallback did not select the valid stamped stack: $($fallback.Output)"
                    Assert ((Get-TargetFingerprint $stampedTarget) -ceq $before) 'broken-jq Python fallback changed target bytes'
                } finally {
                    $env:PATH = $oldPath
                    if (Test-Path -LiteralPath $brokenJqBin) { Remove-Item -LiteralPath $brokenJqBin -Recurse -Force }
                }
            }
        } finally { Remove-Item -LiteralPath $stampedTarget -Recurse -Force }
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
            try {
                if ($null -ne $case.Stamp) {
                    New-Item -ItemType Directory -Force -Path (Join-Path $target '.claude') | Out-Null
                    [IO.File]::WriteAllText((Join-Path $target '.claude/framework-version.json'), $case.Stamp, [Text.UTF8Encoding]::new($false))
                }
                $before = Get-TargetFingerprint $target
                $result = Invoke-RootInstaller $twin $target $case.Stack -DryRun
                Assert ($result.Exit -eq 2) "$($case.Name) exited $($result.Exit): $($result.Output)"
                Assert ($result.Output -match $case.Pattern) "$($case.Name) did not fail actionably: $($result.Output)"
                Assert ((Get-TargetFingerprint $target) -ceq $before) "$($case.Name) changed target bytes"
            } finally { Remove-Item -LiteralPath $target -Recurse -Force }
        }
    }
}

if (-not $SkipRedTest) {
    if (-not $OnlyTwin -or $OnlyTwin -eq 'ps1') {
        It 'a PowerShell mutation that removes warehouse auto-routing makes this suite red and restores bytes' {
            Invoke-MutationRedTest -TargetFile (Join-Path $repo 'install.ps1') -ScratchSourceRoot $repo `
                -Find ('$Stack = ''dotnet''' + "`n" + '                $reason = "auto-detected warehouse SQL profile (found signals: $($warehouseSignals -join '', ''))"') `
                -Replacement "Die 'mutated warehouse refusal'" -Command {
                    param($scratchTarget, $scratchRoot)
                    $test = Join-Path $scratchRoot '.claude/hooks/tests/RootInstallerWarehouse.Tests.ps1'
                    $process = Start-Process -FilePath (Get-PsExe) -ArgumentList @('-NoProfile', '-File', $test, '-SkipRedTest', '-OnlyTwin', 'ps1', '-OnlyWarehouse') -Wait -PassThru -NoNewWindow
                    $global:LASTEXITCODE = $process.ExitCode
                } | Out-Null
        }
    }
    if ($bash -and (-not $OnlyTwin -or $OnlyTwin -eq 'sh')) {
        It 'a shell mutation that removes warehouse auto-routing makes this suite red and restores bytes' {
            Invoke-MutationRedTest -TargetFile (Join-Path $repo 'install.sh') -ScratchSourceRoot $repo `
                -Find '      stack="dotnet"; reason="auto-detected warehouse SQL profile (found signals: $observed)"' `
                -Replacement '      echo "mutated warehouse refusal" >&2; exit 2' -Command {
                    param($scratchTarget, $scratchRoot)
                    $test = Join-Path $scratchRoot '.claude/hooks/tests/RootInstallerWarehouse.Tests.ps1'
                    $process = Start-Process -FilePath (Get-PsExe) -ArgumentList @('-NoProfile', '-File', $test, '-SkipRedTest', '-OnlyTwin', 'sh', '-OnlyWarehouse') -Wait -PassThru -NoNewWindow
                    $global:LASTEXITCODE = $process.ExitCode
                } | Out-Null
            }
        }
    }

exit (Write-TestSummary 'RootInstallerWarehouse.Tests')
