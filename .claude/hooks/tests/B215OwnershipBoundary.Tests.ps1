# B-215 regression contract: the framework hook suite remains in each composed distribution for
# template/release CI, but it is neither installed nor usable as application-command evidence.
# Does NOT ship.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$prefix = 'tests/hooks/'

function Invoke-B215Installer {
    param([string]$Target)
    $installer = Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1'
    $out = & (Get-PsExe) -NoProfile -File $installer -Target $Target 2>&1 | Out-String
    [pscustomobject]@{ Exit = $LASTEXITCODE; Output = $out }
}

function New-B215Target {
    param([switch]$Historical)
    $target = Join-Path ([IO.Path]::GetTempPath()) ('b215-target-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    if (-not $Historical) { return $target }

    $stage = Join-Path ([IO.Path]::GetTempPath()) ('b215-stage-' + [guid]::NewGuid().ToString('N'))
    $archive = Join-Path ([IO.Path]::GetTempPath()) ('b215-archive-' + [guid]::NewGuid().ToString('N') + '.tar')
    New-Item -ItemType Directory -Force -Path $stage | Out-Null
    try {
        & git -C $repoRoot archive --format=tar "--output=$archive" v0.80.0 -- `
            dist/dotnet/framework-ownership.json dist/dotnet/tests/hooks
        Assert ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $archive -PathType Leaf)) `
            'could not create the v0.80.0 hook-test fixture archive'
        & tar -xf $archive -C $stage
        Assert ($LASTEXITCODE -eq 0) 'could not extract the v0.80.0 hook-test fixture archive'

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
        Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Reset-Tests

It 'all distributions retain the suite but exclude it from consumer ownership' {
    foreach ($stack in @('dotnet','angular','monorepo')) {
        $dist = Join-Path $repoRoot "dist/$stack"
        $suite = @(Get-ChildItem -LiteralPath (Join-Path $dist 'tests/hooks') -File -Recurse)
        Assert ($suite.Count -eq 22) "$stack dist does not retain all 22 hook-test files"
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

It 'greenfield consumer omits hook tests but retains consumer eval documentation' {
        $target = New-B215Target
        try {
            $result = Invoke-B215Installer -Target $target
            Assert ($result.Exit -eq 0) "greenfield installer exited $($result.Exit): $($result.Output)"
            Assert (-not (Test-Path -LiteralPath (Join-Path $target 'tests/hooks'))) 'installer copied framework hook tests'
            Assert (Test-Path -LiteralPath (Join-Path $target 'tests/evals/cases.yaml') -PathType Leaf) 'installer removed the consumer eval documentation with the hook suite'
        } finally { Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'update retires every known-clean historical hook-test file' {
        $target = New-B215Target -Historical
        try {
            $result = Invoke-B215Installer -Target $target
            Assert ($result.Exit -eq 0) "clean update exited $($result.Exit): $($result.Output)"
            $remaining = @(Get-ChildItem -LiteralPath (Join-Path $target 'tests/hooks') -File -Recurse -ErrorAction SilentlyContinue)
            Assert ($remaining.Count -eq 0) "installer left $($remaining.Count) clean retired hook-test files installed"
            $deletes = @(($result.Output -split "`r?`n") | Where-Object { $_ -match '^PLAN delete tests/hooks/' })
            Assert ($deletes.Count -eq 23) "installer planned $($deletes.Count) hook-test retirements, expected 23"
        } finally { Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'update preserves a consumer-modified retired hook test and discloses why' {
        $target = New-B215Target -Historical
        $custom = Join-Path $target 'tests/hooks/Invoke-HookTests.ps1'
        try {
            [IO.File]::WriteAllText($custom, 'CONSUMER CUSTOM TEST RUNNER', [Text.UTF8Encoding]::new($false))
            $result = Invoke-B215Installer -Target $target
            Assert ($result.Exit -eq 0) "modified update exited $($result.Exit): $($result.Output)"
            Assert (Test-Path -LiteralPath $custom -PathType Leaf) 'installer deleted the consumer-modified retired runner'
            Assert ([IO.File]::ReadAllText($custom) -ceq 'CONSUMER CUSTOM TEST RUNNER') 'installer changed the preserved consumer runner'
            $remaining = @(Get-ChildItem -LiteralPath (Join-Path $target 'tests/hooks') -File -Recurse)
            Assert ($remaining.Count -eq 1) "installer left $($remaining.Count) retired hook-test files, expected only the modified runner"
            Assert ($result.Output -match "CANT-VERIFY: retired path 'tests/hooks/Invoke-HookTests\.ps1'.*consumer-modified or unknown content") `
                'installer did not disclose preservation of consumer-modified content'
        } finally { Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue }
}

# v0.83 retirement authority is cumulative. Prove it against every released raw blob through
# v0.82 rather than against only the latest tag: a byte that shipped once remains deletable only
# when its path-specific digest is still present in both authoritative ledgers.
$v083RetiredPaths = @(
    '.claude/hooks/audit-trail.sh',
    '.claude/hooks/boy-scout-check.sh',
    '.claude/hooks/guard.sh',
    '.claude/hooks/post-write.sh',
    '.claude/hooks/route-prompt.sh',
    '.claude/hooks/session-start.sh',
    'scripts/build-architecture-html.sh',
    'scripts/ci/bitbucket-pipelines.example.yml',
    'scripts/docs-sync-check.sh',
    'scripts/framework-doctor.sh',
    'scripts/hazard-check.sh',
    'scripts/metrics.sh',
    'scripts/setup-git-hooks.ps1',
    'scripts/setup-git-hooks.sh',
    'scripts/template-checks.sh',
    'scripts/test-weakening-scan.sh',
    'scripts/warehouse-map-check.sh',
    'scripts/wiki-check.sh'
)

function Invoke-GitBytes {
    param([string[]]$Arguments)
    $git = @(Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)
    Assert ($git.Count -eq 1) 'git executable is unavailable'
    $stdout = [IO.Path]::GetTempFileName()
    $stderr = [IO.Path]::GetTempFileName()
    try {
        $quoted = @('-C', $repoRoot) + $Arguments
        $argumentString = (($quoted | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join ' ')
        $process = Start-Process -FilePath $git[0].Source -ArgumentList $argumentString -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        return [pscustomobject]@{
            Exit = [int]$process.ExitCode
            Bytes = [IO.File]::ReadAllBytes($stdout)
            Error = [IO.File]::ReadAllText($stderr)
        }
    } finally {
        Remove-Item -Force -LiteralPath $stdout,$stderr -ErrorAction SilentlyContinue
    }
}

function Get-RawSha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Get-V083TaggedObservations {
    $tagResult = Invoke-GitBytes @('tag','--list','v*')
    Assert ($tagResult.Exit -eq 0) "could not enumerate release tags: $($tagResult.Error)"
    $tags = @([Text.Encoding]::UTF8.GetString($tagResult.Bytes) -split "`r?`n" | Where-Object {
        $_ -match '^v(\d+\.\d+\.\d+)$' -and ([version]$Matches[1] -le [version]'0.82.0')
    })
    Assert ($tags.Count -gt 0) 'release-tag enumeration through v0.82 was empty'

    $observations = @()
    $wanted = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($path in $v083RetiredPaths) { [void]$wanted.Add($path) }
    foreach ($tag in $tags) {
        $tree = Invoke-GitBytes @('ls-tree','-r',$tag,'--','dist/dotnet','dist/angular','dist/monorepo')
        Assert ($tree.Exit -eq 0) "could not enumerate $tag distribution trees: $($tree.Error)"
        foreach ($line in ([Text.Encoding]::UTF8.GetString($tree.Bytes) -split "`r?`n")) {
            if ($line -notmatch '^[0-9]+ blob ([0-9a-f]{40})\t(dist/(dotnet|angular|monorepo)/(.+))$') { continue }
            $oid = $Matches[1]; $stack = $Matches[3]; $relative = $Matches[4]
            if ($wanted.Contains($relative)) {
                $observations += [pscustomobject]@{ Tag=$tag; Stack=$stack; Path=$relative; Oid=$oid }
            }
        }
    }
    Assert ($observations.Count -gt 0) 'tagged retirement observation set was empty'
    return $observations
}

function Get-LedgerDigestMap($Ledger) {
    $map = @{}
    foreach ($entry in @($Ledger.retirements)) {
        $set = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        foreach ($hash in @($entry.'known-content-sha256')) { [void]$set.Add([string]$hash) }
        $map[[string]$entry.path] = $set
    }
    return $map
}

function Assert-TaggedDigestCompleteness($Observations, $DigestMap) {
    $hashByOid = @{}
    foreach ($observation in $Observations) {
        if (-not $hashByOid.ContainsKey($observation.Oid)) {
            $blob = Invoke-GitBytes @('cat-file','blob',$observation.Oid)
            Assert ($blob.Exit -eq 0) "could not read raw blob $($observation.Oid): $($blob.Error)"
            $hashByOid[$observation.Oid] = Get-RawSha256 $blob.Bytes
        }
        Assert ($DigestMap.ContainsKey($observation.Path)) "retirement ledger has no entry for $($observation.Path)"
        $hash = [string]$hashByOid[$observation.Oid]
        Assert ($DigestMap[$observation.Path].Contains($hash)) `
            "missing tagged digest: $($observation.Tag) dist/$($observation.Stack)/$($observation.Path) sha256=$hash"
    }
}

It 'v0.83 ledger contains every raw path-specific digest released through v0.82 in all three dists' {
    Assert ($v083RetiredPaths.Count -eq 18) "retired-path pin drifted to $($v083RetiredPaths.Count), expected 18"
    $sourceBytes = [IO.File]::ReadAllBytes((Join-Path $repoRoot 'src/core/framework-retirements.json'))
    $baselineBytes = [IO.File]::ReadAllBytes((Join-Path $repoRoot 'meta/framework-retirements-baseline.json'))
    Assert ([Convert]::ToBase64String($sourceBytes) -ceq [Convert]::ToBase64String($baselineBytes)) 'retirement authorities are not byte-identical'
    $ledger = [Text.Encoding]::UTF8.GetString($sourceBytes).TrimStart([char]0xFEFF) | ConvertFrom-Json
    $actualV083 = @($ledger.retirements | Where-Object { $_.'retired-in' -ceq '0.83.0' } | ForEach-Object path)
    Assert (($actualV083 -join "`n") -ceq ($v083RetiredPaths -join "`n")) 'v0.83 retirement paths differ from the explicit 18-path contract'
    $observations = @(Get-V083TaggedObservations)
    foreach ($path in $v083RetiredPaths) {
        Assert (@($observations | Where-Object Path -ceq $path).Count -gt 0) "no released blob was observed for $path"
        foreach ($stack in @('dotnet','angular','monorepo')) {
            Assert (@($observations | Where-Object { $_.Path -ceq $path -and $_.Stack -ceq $stack }).Count -gt 0) `
                "no released $stack blob was observed for $path"
        }
    }
    Assert-TaggedDigestCompleteness $observations (Get-LedgerDigestMap $ledger)

    # Hostile calibration: remove one genuinely observed digest from an in-memory copy. The same
    # checker must go red before its clean result is accepted.
    $badMap = Get-LedgerDigestMap $ledger
    $first = $observations[0]
    $blob = Invoke-GitBytes @('cat-file','blob',$first.Oid)
    $removedHash = Get-RawSha256 $blob.Bytes
    Assert ($badMap[$first.Path].Remove($removedHash)) 'could not plant the missing-digest mutation'
    $caught = $false
    try { Assert-TaggedDigestCompleteness $observations $badMap }
    catch { $caught = $_.Exception.Message -match 'missing tagged digest' }
    Assert $caught 'removing a released digest did not make the completeness checker go red'
}

It 'install.sh remains historical staging data, never an installed retirement entry' {
    $ledger = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'src/core/framework-retirements.json') | ConvertFrom-Json
    Assert (@($ledger.retirements | Where-Object path -ceq 'install.sh').Count -eq 0) 'install.sh was incorrectly added as an installed retirement'
    $release = [IO.File]::ReadAllText((Join-Path $repoRoot '.claude/scripts/release.ps1'))
    Assert ($release -match '\|install\\\.sh') 'historical release staging allowlist no longer retains install.sh'
}

exit (Write-TestSummary 'B215OwnershipBoundary.Tests')
