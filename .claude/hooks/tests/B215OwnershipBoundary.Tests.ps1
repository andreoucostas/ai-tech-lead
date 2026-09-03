# B-215 regression contract: the framework hook suite remains in each composed distribution for
# template/release CI, but it is neither installed nor usable as application-command evidence.
# Does NOT ship.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$bash = Get-BashPath
$prefix = 'tests/hooks/'

function Invoke-B215Installer {
    param([ValidateSet('ps1','sh')][string]$Twin, [string]$Target)
    $installer = Join-Path $repoRoot "dist/dotnet/scripts/install.$Twin"
    if ($Twin -eq 'ps1') { $out = & (Get-PsExe) -NoProfile -File $installer -Target $Target 2>&1 | Out-String }
    else { $out = & $bash $installer $Target 2>&1 | Out-String }
    [pscustomobject]@{ Exit = $LASTEXITCODE; Output = $out }
}

function New-B215Target {
    param([switch]$Historical)
    $target = Join-Path ([IO.Path]::GetTempPath()) ('b215-target-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    if (-not $Historical) { return $target }

    $stage = Join-Path ([IO.Path]::GetTempPath()) ('b215-stage-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $stage | Out-Null
    try {
        & git -C $repoRoot archive --format=tar v0.80.0 `
            dist/dotnet/framework-ownership.json dist/dotnet/tests/hooks | & tar -xf - -C $stage
        Assert ($LASTEXITCODE -eq 0) 'could not archive and extract the v0.80.0 hook-test fixture'

        Copy-Item -LiteralPath (Join-Path $stage 'dist/dotnet/framework-ownership.json') `
            -Destination (Join-Path $target 'framework-ownership.json') -Force
        New-Item -ItemType Directory -Force -Path (Join-Path $target 'tests') | Out-Null
        Copy-Item -LiteralPath (Join-Path $stage 'dist/dotnet/tests/hooks') `
            -Destination (Join-Path $target 'tests') -Recurse -Force
        New-Item -ItemType Directory -Force -Path (Join-Path $target '.claude') | Out-Null
        [IO.File]::WriteAllText(
            (Join-Path $target '.claude/framework-version.json'),
            '{"version":"0.80.0","template":"dotnet"}',
            [Text.UTF8Encoding]::new($false))
        return $target
    } finally {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Reset-Tests

It 'all distributions retain the suite but exclude it from consumer ownership' {
    foreach ($stack in @('dotnet','angular','monorepo')) {
        $dist = Join-Path $repoRoot "dist/$stack"
        $suite = @(Get-ChildItem -LiteralPath (Join-Path $dist 'tests/hooks') -File -Recurse)
        Assert ($suite.Count -eq 23) "$stack dist does not retain all 23 hook-test files"
        $manifest = Get-Content -Raw -LiteralPath (Join-Path $dist 'framework-ownership.json') | ConvertFrom-Json
        $installed = @($manifest.paths | Where-Object { $_.path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) })
        Assert ($installed.Count -eq 0) "$stack ownership manifest still installs tests/hooks"
        $templateCi = [IO.File]::ReadAllText((Join-Path $dist '.github/workflows/template-ci.yml'))
        Assert ($templateCi -match 'tests/hooks/Invoke-HookTests\.ps1') "$stack template CI lost its dist-local hook suite"
    }
}

It 'the cumulative retirement ledger exactly covers the last installed hook-test set' {
    $sourceBytes = [IO.File]::ReadAllBytes((Join-Path $repoRoot 'src/core/framework-retirements.json'))
    $baselineBytes = [IO.File]::ReadAllBytes((Join-Path $repoRoot 'meta/framework-retirements-baseline.json'))
    Assert ([Convert]::ToBase64String($sourceBytes) -ceq [Convert]::ToBase64String($baselineBytes)) `
        'source and maintainer retirement ledgers differ'

    $oldText = (& git -C $repoRoot show 'v0.80.0:dist/dotnet/framework-ownership.json' 2>$null) -join "`n"
    Assert ($LASTEXITCODE -eq 0 -and $oldText) 'could not read the v0.80.0 ownership manifest'
    $old = $oldText | ConvertFrom-Json
    $expected = @($old.paths | Where-Object { $_.path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) } | ForEach-Object path | Sort-Object)
    $ledger = ([Text.Encoding]::UTF8.GetString($sourceBytes).TrimStart([char]0xFEFF) | ConvertFrom-Json)
    $actual = @($ledger.retirements | Where-Object { $_.path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) } | ForEach-Object path | Sort-Object)
    Assert ($expected.Count -eq 23) "v0.80.0 installed $($expected.Count) hook-test paths, expected 23"
    Assert (($expected -join "`n") -ceq ($actual -join "`n")) 'retirement paths do not exactly match the final installed hook-test set'
}

foreach ($twin in @('ps1','sh')) {
    if ($twin -eq 'sh' -and -not $bash) { Skip "consumer install boundary ($twin)" 'no bash on this host'; continue }

    It "greenfield consumer omits hook tests but retains consumer eval documentation ($twin)" {
        $target = New-B215Target
        try {
            $result = Invoke-B215Installer -Twin $twin -Target $target
            Assert ($result.Exit -eq 0) "$twin greenfield installer exited $($result.Exit): $($result.Output)"
            Assert (-not (Test-Path -LiteralPath (Join-Path $target 'tests/hooks'))) "$twin installed framework hook tests"
            Assert (Test-Path -LiteralPath (Join-Path $target 'tests/evals/cases.yaml') -PathType Leaf) "$twin removed the consumer eval documentation with the hook suite"
        } finally { Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "update retires every known-clean historical hook-test file ($twin)" {
        $target = New-B215Target -Historical
        try {
            $result = Invoke-B215Installer -Twin $twin -Target $target
            Assert ($result.Exit -eq 0) "$twin clean update exited $($result.Exit): $($result.Output)"
            $remaining = @(Get-ChildItem -LiteralPath (Join-Path $target 'tests/hooks') -File -Recurse -ErrorAction SilentlyContinue)
            Assert ($remaining.Count -eq 0) "$twin left $($remaining.Count) clean retired hook-test files installed"
            $deletes = @(($result.Output -split "`r?`n") | Where-Object { $_ -match '^PLAN delete tests/hooks/' })
            Assert ($deletes.Count -eq 23) "$twin planned $($deletes.Count) hook-test retirements, expected 23"
        } finally { Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "update preserves a consumer-modified retired hook test and discloses why ($twin)" {
        $target = New-B215Target -Historical
        $custom = Join-Path $target 'tests/hooks/Invoke-HookTests.ps1'
        try {
            [IO.File]::WriteAllText($custom, 'CONSUMER CUSTOM TEST RUNNER', [Text.UTF8Encoding]::new($false))
            $result = Invoke-B215Installer -Twin $twin -Target $target
            Assert ($result.Exit -eq 0) "$twin modified update exited $($result.Exit): $($result.Output)"
            Assert (Test-Path -LiteralPath $custom -PathType Leaf) "$twin deleted the consumer-modified retired runner"
            Assert ([IO.File]::ReadAllText($custom) -ceq 'CONSUMER CUSTOM TEST RUNNER') "$twin changed the preserved consumer runner"
            $remaining = @(Get-ChildItem -LiteralPath (Join-Path $target 'tests/hooks') -File -Recurse)
            Assert ($remaining.Count -eq 1) "$twin left $($remaining.Count) retired hook-test files, expected only the modified runner"
            Assert ($result.Output -match "CANT-VERIFY: retired path 'tests/hooks/Invoke-HookTests\.ps1'.*consumer-modified or unknown content") `
                "$twin did not disclose preservation of consumer-modified content"
        } finally { Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

exit (Write-TestSummary 'B215OwnershipBoundary.Tests')
