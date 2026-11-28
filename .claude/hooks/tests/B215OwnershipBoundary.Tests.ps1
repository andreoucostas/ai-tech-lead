# B-215 regression contract: the framework hook suite remains in each composed distribution for
# template/release CI, but it is neither installed nor usable as application-command evidence.
# Does NOT ship.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$hostProcess = Get-Process -Id $PID -ErrorAction Stop
Write-Host ("HOST executable={0}; version={1}" -f $hostProcess.Path, $PSVersionTable.PSVersion)

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
        # Live inventory of the retained suite: 22 after the architecture generator's test retired
        # with it, 23 since BootstrapBaseline.Tests.ps1 joined, 24 since B-395's guard-patch-cases.ps1
        # fixture, 25 since B-421's SessionStartTestEntryPoints.Tests.ps1, 26 since B-510 split
        # Guard.Tests.ps1 in two with Guard2.Tests.ps1. Distinct from the frozen 23 below, which
        # counts what v0.80.0 actually installed.
        Assert ($suite.Count -eq 26) "$stack dist does not retain all 26 hook-test files"
        Assert (@($suite | Where-Object { $_.Name -ceq 'ReviewScope.Tests.ps1' }).Count -eq 1) "$stack dist omitted ReviewScope.Tests.ps1 from the retained hook-test inventory"
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
    $quoted = @('-C', $repoRoot) + $Arguments
    $argumentString = (($quoted | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join ' ')
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $git[0].Source
    $startInfo.Arguments = $argumentString
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    $stdout = New-Object IO.MemoryStream
    $stderrTask = $null
    $stdoutTask = $null
    try {
        [void]$process.Start()
        # Start both drains before waiting. Git's stdout may be binary, so never let PowerShell's
        # native-output adapter decode it; stderr remains text for actionable failure diagnostics.
        $stdoutTask = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        return [pscustomobject]@{
            Exit = [int]$process.ExitCode
            Bytes = $stdout.ToArray()
            Error = $stderr
        }
    } finally {
        $stdout.Dispose()
        $process.Dispose()
    }
}

function Get-RawSha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Get-TaggedObservations {
    param([string[]]$Paths, [version]$Through)
    $tagResult = Invoke-GitBytes @('tag','--list','v*')
    Assert ($tagResult.Exit -eq 0) "could not enumerate release tags: $($tagResult.Error)"
    $tags = @([Text.Encoding]::UTF8.GetString($tagResult.Bytes) -split "`r?`n" | Where-Object {
        $_ -match '^v(\d+\.\d+\.\d+)$' -and ([version]$Matches[1] -le $Through)
    })
    Assert ($tags.Count -gt 0) "release-tag enumeration through v$Through was empty"

    $observations = @()
    $wanted = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($path in $Paths) { [void]$wanted.Add($path) }
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
    $observations = @(Get-TaggedObservations -Paths $v083RetiredPaths -Through '0.82.0')
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

It '0.92.0 ledger contains every released digest of the seven retired recipe skills' {
    $paths = @('add-component', 'add-endpoint', 'add-entity', 'add-lazy-route', 'add-service', 'add-signal-store', 'register-service' |
        ForEach-Object { ".claude/skills/$_/SKILL.md" })
    $ledger = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes((Join-Path $repoRoot 'src/core/framework-retirements.json'))).TrimStart([char]0xFEFF) | ConvertFrom-Json
    foreach ($path in $paths) {
        Assert (@($ledger.retirements | Where-Object { $_.path -ceq $path -and $_.'retired-in' -ceq '0.92.0' }).Count -eq 1) "no 0.92.0 retirement entry for $path"
    }
    # Each recipe shipped from one stack and the monorepo union, never from all three dists.
    $observations = @(Get-TaggedObservations -Paths $paths -Through '0.91.0')
    foreach ($path in $paths) {
        Assert (@($observations | Where-Object Path -ceq $path).Count -gt 0) "no released blob was observed for $path"
    }
    Assert-TaggedDigestCompleteness $observations (Get-LedgerDigestMap $ledger)
}

It '0.94.0 ledger contains every released digest of the twelve retired prompt files' {
    $paths = @('adopt', 'bootstrap', 'debt', 'design', 'docs-sync', 'feature', 'fix', 'rebootstrap', 'refactor', 'review', 'security-review', 'test' |
        ForEach-Object { ".github/prompts/$_.prompt.md" })
    $ledger = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes((Join-Path $repoRoot 'src/core/framework-retirements.json'))).TrimStart([char]0xFEFF) | ConvertFrom-Json
    foreach ($path in $paths) {
        Assert (@($ledger.retirements | Where-Object { $_.path -ceq $path -and $_.'retired-in' -ceq '0.94.0' }).Count -eq 1) "no 0.94.0 retirement entry for $path"
    }
    # Each prompt shipped from all three dists.
    $observations = @(Get-TaggedObservations -Paths $paths -Through '0.93.0')
    foreach ($path in $paths) {
        foreach ($stack in @('dotnet', 'angular', 'monorepo')) {
            Assert (@($observations | Where-Object { $_.Path -ceq $path -and $_.Stack -ceq $stack }).Count -gt 0) "no released $stack blob was observed for $path"
        }
    }
    Assert-TaggedDigestCompleteness $observations (Get-LedgerDigestMap $ledger)
}

# B-561: the texts an update may remove from a team's own instruction file, one list in the source ledger, its maintainer
# baseline and the three dists, checked against the shipped installer's own digest of the .NET template's v0.25.5 CLAUDE.md
# (.claude/hooks/tests/fixtures/legacy-dotnet-instructions-v0.25.5.txt).
It 'B-561 the ledger lists the superseded rule sections and Boy Scout items, and the installer digest of the old text matches them' {
    $copies = @('src/core/framework-retirements.json', 'meta/framework-retirements-baseline.json', 'dist/dotnet/framework-retirements.json', 'dist/angular/framework-retirements.json', 'dist/monorepo/framework-retirements.json')
    $source = ([IO.File]::ReadAllText((Join-Path $repoRoot $copies[0])) | ConvertFrom-Json).'superseded-instruction-text'
    Assert ($null -ne $source) 'the source ledger has no superseded-instruction-text key'
    $expectedCounts = [ordered]@{ 'Verification Rules' = 30; 'Leanness' = 16; 'SOLID' = 13; 'Agentic Workflow' = 60 }
    Assert (@($source.sections).Count -eq 4) "expected 4 section entries, got $(@($source.sections).Count)"
    foreach ($name in $expectedCounts.Keys) {
        $entry = @($source.sections | Where-Object { $_.heading -ceq $name })
        Assert ($entry.Count -eq 1 -and @($entry[0].'known-content-sha256').Count -eq $expectedCounts[$name]) "the $name entry does not carry $($expectedCounts[$name]) digests"
    }
    Assert (@($source.lines).Count -eq 3) "expected 3 line entries, got $(@($source.lines).Count)"
    $sourceJson = $source | ConvertTo-Json -Depth 8 -Compress
    foreach ($copy in $copies) {
        $other = ([IO.File]::ReadAllText((Join-Path $repoRoot $copy)) | ConvertFrom-Json).'superseded-instruction-text' | ConvertTo-Json -Depth 8 -Compress
        Assert ($other -ceq $sourceJson) "$copy carries a different superseded-instruction-text"
    }
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1'), [ref]$null, [ref]$null)
    $wanted = @('Read-SupersededInstructionText', 'Get-InstructionLineCore', 'Get-InstructionDigest', 'Get-InstructionFences', 'Get-InstructionSections', 'Test-BoyScoutLedgerLine', 'Get-SupersededCleanup')
    $functions = @($ast.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $wanted -ccontains $_.Name })
    Assert ($functions.Count -eq $wanted.Count) "the shipped installer defines $($functions.Count) of $($wanted -join ', ')"
    . ([scriptblock]::Create((@($functions | ForEach-Object { $_.Extent.Text }) -join "`n")))
    $fixture = [Text.UTF8Encoding]::new($false).GetString([IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'fixtures/legacy-dotnet-instructions-v0.25.5.txt')))
    $parsed = Get-InstructionSections -Text $fixture
    foreach ($name in $expectedCounts.Keys) {
        $section = @($parsed.Sections | Where-Object { $_.Heading -ceq "## $name" })
        $listed = @(($source.sections | Where-Object { $_.heading -ceq $name }).'known-content-sha256')
        Assert ($section.Count -eq 1 -and $listed -ccontains $section[0].Digest) "the installer's digest of the old $name section is not listed"
    }
    $item = @($fixture.Split([char]10) | Where-Object { $_.StartsWith('10. Inline single-consumer', [StringComparison]::Ordinal) })[0]
    Assert (@($source.lines | ForEach-Object { $_.'known-line-sha256' }) -ccontains (Get-InstructionDigest -Text ($item -replace '^\d+\.\s+', ''))) "the old Boy Scout item's digest is not listed"
    $superseded = Read-SupersededInstructionText -Path (Join-Path $repoRoot 'dist/dotnet/framework-retirements.json')
    $cleanup = Get-SupersededCleanup -Text $fixture -Superseded $superseded
    Assert ((@($cleanup.Removed) -join ', ') -ceq 'Verification Rules, Leanness, SOLID, Agentic Workflow' -and $cleanup.Replaced.Count -eq 1 -and $cleanup.Differs.Count -eq 0) "the installer would not remove the four old sections and replace one item: removed $(@($cleanup.Removed) -join ', '); replaced $($cleanup.Replaced.Count); differs $(@($cleanup.Differs) -join ', ')"
}

# The old Boy Scout Rule lines and retired skills' Common Tasks lines an update may change: 13 items, 5 whole lines (2 of
# them removals), 7 skill lines. Each old text is a line a release from 0.76.0 shipped in that section, each successor a
# line of today's section, each skill one the ledger retired; the shipped reader takes the key and refuses a malformed one.
It 'old Boy Scout and retired skill lines: the ledger lists texts releases shipped, each with a successor today ships' {
    $source = ([IO.File]::ReadAllText((Join-Path $repoRoot 'src/core/framework-retirements.json')) | ConvertFrom-Json)
    $data = $source.'superseded-instruction-text'
    Assert (@($data.'boy-scout-items').Count -eq 13 -and @($data.'boy-scout-lines').Count -eq 5 -and @($data.'retired-skill-lines').Count -eq 7) "expected 13 items, 5 lines and 7 skill lines, got $(@($data.'boy-scout-items').Count), $(@($data.'boy-scout-lines').Count) and $(@($data.'retired-skill-lines').Count)"
    Assert (@($data.'boy-scout-lines' | Where-Object { $null -eq $_.replacement }).Count -eq 2) 'expected two whole lines mapped to removal'
    $digest = { param([string]$Text) $sha = [Security.Cryptography.SHA256]::Create(); try { ([BitConverter]::ToString($sha.ComputeHash([Text.UTF8Encoding]::new($false).GetBytes($Text)))).Replace('-', '').ToLowerInvariant() } finally { $sha.Dispose() } }
    $sectionLines = {
        param([string]$Ref, [string]$Product)
        $show = { param([string]$Spec) $r = Invoke-GitBytes @('cat-file', 'blob', $Spec); if ($r.Exit -ne 0) { throw "could not read $Spec" }; [Text.UTF8Encoding]::new($false).GetString($r.Bytes) }
        $claude = & $show "${Ref}:dist/$Product/CLAUDE.md"
        $file = if ($claude -match '(?m)^@AGENTS\.md') { 'AGENTS.md' } else { 'CLAUDE.md' }
        $in = $false; $lines = @(); $tasks = $false; $task = @()
        foreach ($l in (& $show "${Ref}:dist/$Product/$file").Split([char]10)) {
            $c = $l.TrimEnd("`r").TrimEnd(' ', "`t")
            if ($c.StartsWith('## ')) { $in = $c -ceq '## Boy Scout Rule'; $tasks = $c -ceq '## Common Tasks'; continue }
            if ($in -and $c.Length -gt 0) { $lines += $c }
            if ($tasks -and $c.StartsWith('- `')) { $task += $c }
        }
        return [pscustomobject]@{ Lines = $lines; Tasks = $task }
    }
    $oldItems = @{}; $oldLines = @{}; $oldTasks = @{}
    $tags = @(& git -C $repoRoot tag --list 'v*' | Where-Object { $_ -match '^v(\d+\.\d+\.\d+)$' -and [version]$Matches[1] -ge [version]'0.76.0' })
    foreach ($tag in $tags) { foreach ($p in 'dotnet', 'angular', 'monorepo') {
        $read = & $sectionLines $tag $p
        foreach ($c in $read.Lines) { $oldLines[(& $digest $c)] = $true; if ($c -cmatch '^\d+\.\s+(.*)$') { $oldItems[(& $digest $Matches[1])] = $true } }
        foreach ($c in $read.Tasks) { $oldTasks[(& $digest $c)] = $true }
    } }
    $headItems = @{}; $headLines = @{}
    foreach ($p in 'dotnet', 'angular', 'monorepo') { foreach ($c in (& $sectionLines 'HEAD' $p).Lines) { $headLines[$c] = $true; if ($c -cmatch '^\d+\.\s+(.*)$') { $headItems[$Matches[1]] = $true } } }
    foreach ($entry in $data.'boy-scout-items') {
        Assert $oldItems.ContainsKey($entry.'known-line-sha256') "boy-scout-items digest $($entry.'known-line-sha256') is no item a release from 0.76.0 shipped"
        Assert $headItems.ContainsKey($entry.replacement) "boy-scout-items successor '$($entry.replacement)' is no item of today's section"
    }
    foreach ($entry in $data.'boy-scout-lines') {
        Assert $oldLines.ContainsKey($entry.'known-line-sha256') "boy-scout-lines digest $($entry.'known-line-sha256') is no line a release from 0.76.0 shipped"
        Assert ($null -eq $entry.replacement -or $headLines.ContainsKey($entry.replacement)) "boy-scout-lines successor '$($entry.replacement)' is no line of today's section"
    }
    $retiredSkills = @($source.retirements | Where-Object { $_.path -match '^\.claude/skills/([^/]+)/SKILL\.md$' } | ForEach-Object { ($_.path -split '/')[2] })
    foreach ($entry in $data.'retired-skill-lines') {
        Assert ($retiredSkills -ccontains $entry.skill) "retired-skill-lines names $($entry.skill), which the ledger does not retire"
        foreach ($hash in $entry.'known-line-sha256') { Assert $oldTasks.ContainsKey($hash) "retired-skill-lines digest $hash under $($entry.skill) is no Common Tasks line a release from 0.76.0 shipped" }
    }
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1'), [ref]$null, [ref]$null)
    $function = @($ast.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -ceq 'Read-SupersededInstructionText' })
    Assert ($function.Count -eq 1) 'the shipped installer has no Read-SupersededInstructionText'
    . ([scriptblock]::Create($function[0].Extent.Text))
    $read = Read-SupersededInstructionText -Path (Join-Path $repoRoot 'dist/dotnet/framework-retirements.json')
    Assert ($read.BoyScoutItems.Count -eq 13 -and $read.BoyScoutLines.Count -eq 5 -and $read.RetiredSkillLines.Count -eq 7) 'the shipped reader did not read the three new lists'
    Assert (@($read.BoyScoutLines.Values | Where-Object { $null -eq $_ }).Count -eq 2) 'the shipped reader did not keep the two removals as removals (an empty successor would leave an empty line)'
    $scratch = Join-Path ([IO.Path]::GetTempPath()) ('superseded-ledger-' + [guid]::NewGuid().ToString('N') + '.json')
    try {
        $good = [IO.File]::ReadAllText((Join-Path $repoRoot 'dist/dotnet/framework-retirements.json'))
        $mutations = [ordered]@{
            'a missing boy-scout-items list' = { param($d) $d.'superseded-instruction-text'.PSObject.Properties.Remove('boy-scout-items') }
            'an empty item successor' = { param($d) $d.'superseded-instruction-text'.'boy-scout-items'[0].replacement = ' ' }
            'a line with no replacement key' = { param($d) $d.'superseded-instruction-text'.'boy-scout-lines'[0].PSObject.Properties.Remove('replacement') }
            'a two-line successor' = { param($d) $d.'superseded-instruction-text'.'boy-scout-lines'[0].replacement = "a`nb" }
            'an item digest also in lines' = { param($d) $d.'superseded-instruction-text'.'boy-scout-items'[0].'known-line-sha256' = $d.'superseded-instruction-text'.lines[0].'known-line-sha256' }
            'a bad skill slug' = { param($d) $d.'superseded-instruction-text'.'retired-skill-lines'[0].skill = 'Add Endpoint' }
            'a skill without digests' = { param($d) $d.'superseded-instruction-text'.'retired-skill-lines'[0].'known-line-sha256' = @() }
        }
        foreach ($name in $mutations.Keys) {
            $doc = $good | ConvertFrom-Json
            & $mutations[$name] $doc
            [IO.File]::WriteAllText($scratch, ($doc | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
            $refused = $false
            try { [void](Read-SupersededInstructionText -Path $scratch) } catch { $refused = $_.Exception.Message -match 'malformed superseded-instruction-text' }
            Assert $refused "the reader accepted a superseded-instruction-text with $name"
        }
    } finally { Remove-Item -LiteralPath $scratch -Force -ErrorAction SilentlyContinue }
}

# The retired .github/copilot-instructions.md (0.26.0 through 0.89.2, 291 blobs, 18 texts): one key in the source ledger,
# its maintainer baseline and the three dists; the shipped installer's own digest of every released blob is listed, its
# reader takes the key and refuses a malformed one, and each released text reads as 'released'.
It 'retired copilot file: the ledger lists every released copilot-instructions text and the shipped installer reads it strictly' {
    $copies = @('src/core/framework-retirements.json', 'meta/framework-retirements-baseline.json', 'dist/dotnet/framework-retirements.json', 'dist/angular/framework-retirements.json', 'dist/monorepo/framework-retirements.json')
    $source = ([IO.File]::ReadAllText((Join-Path $repoRoot $copies[0])) | ConvertFrom-Json).'retired-copilot-instructions'
    Assert ($null -ne $source) 'the source ledger has no retired-copilot-instructions key'
    $sourceJson = $source | ConvertTo-Json -Depth 8 -Compress
    foreach ($copy in $copies) {
        $other = ([IO.File]::ReadAllText((Join-Path $repoRoot $copy)) | ConvertFrom-Json).'retired-copilot-instructions' | ConvertTo-Json -Depth 8 -Compress
        Assert ($other -ceq $sourceJson) "$copy carries a different retired-copilot-instructions"
    }
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1'), [ref]$null, [ref]$null)
    $wanted = @('Get-LfSha256', 'Read-RetiredCopilotInstructions', 'Get-RetiredCopilotKind')
    $functions = @($ast.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $wanted -ccontains $_.Name })
    Assert ($functions.Count -eq $wanted.Count) "the shipped installer defines $($functions.Count) of $($wanted -join ', ')"
    . ([scriptblock]::Create((@($functions | ForEach-Object { $_.Extent.Text }) -join "`n")))
    $retired = Read-RetiredCopilotInstructions -Path (Join-Path $repoRoot 'dist/dotnet/framework-retirements.json')
    Assert ($retired.Version -ceq '0.90.0' -and $retired.Hashes.Count -eq 18) "the reader returned version $($retired.Version) and $($retired.Hashes.Count) digests, expected 0.90.0 and 18"
    $observations = @(Get-TaggedObservations -Paths @('.github/copilot-instructions.md') -Through '0.89.2')
    Assert ($observations.Count -eq 291) "observed $($observations.Count) released copilot-instructions blobs, expected 291"
    $byOid = @{}
    foreach ($observation in $observations) {
        if ($byOid.ContainsKey($observation.Oid)) { continue }
        $blob = Invoke-GitBytes @('cat-file', 'blob', $observation.Oid)
        Assert ($blob.Exit -eq 0) "could not read blob $($observation.Oid)"
        $byOid[$observation.Oid] = $true
        $text = [Text.UTF8Encoding]::new($false).GetString($blob.Bytes)
        $kind = Get-RetiredCopilotKind -Bytes $blob.Bytes -Text $text -Retired $retired
        Assert ($kind -ceq 'released') "missing tagged digest: $($observation.Tag) dist/$($observation.Stack)/.github/copilot-instructions.md reads as $kind"
        $first = @($text.Split([char]10) | Where-Object { $_.Trim().Length -gt 0 })[0].TrimEnd()
        Assert ($retired.OpeningLines.Contains($first)) "$($observation.Tag) dist/$($observation.Stack) does not open with one of the ledger's opening lines"
    }
    Assert ($byOid.Count -eq 18) "observed $($byOid.Count) distinct released texts, expected 18"
    $scratch = Join-Path ([IO.Path]::GetTempPath()) ('copilot-ledger-' + [guid]::NewGuid().ToString('N') + '.json')
    try {
        $good = [IO.File]::ReadAllText((Join-Path $repoRoot 'dist/dotnet/framework-retirements.json')) | ConvertFrom-Json
        $mutations = [ordered]@{
            'another path' = { param($d) $d.'retired-copilot-instructions'.path = '.github/other.md' }
            'a bad version' = { param($d) $d.'retired-copilot-instructions'.'retired-in' = '0.90' }
            'an empty opening line' = { param($d) $d.'retired-copilot-instructions'.'opening-lines' = @(' ') }
            'no opening line' = { param($d) $d.'retired-copilot-instructions'.'opening-lines' = @() }
            'no marker' = { param($d) $d.'retired-copilot-instructions'.'generated-marker' = $null }
            'an upper-case digest' = { param($d) $d.'retired-copilot-instructions'.'known-content-sha256'[0] = $d.'retired-copilot-instructions'.'known-content-sha256'[0].ToUpperInvariant() }
            'a repeated digest' = { param($d) $d.'retired-copilot-instructions'.'known-content-sha256' = @($d.'retired-copilot-instructions'.'known-content-sha256') + @($d.'retired-copilot-instructions'.'known-content-sha256'[0]) }
            'no digest' = { param($d) $d.'retired-copilot-instructions'.'known-content-sha256' = @() }
            'a string for the key' = { param($d) $d.'retired-copilot-instructions' = 'x' }
        }
        foreach ($name in $mutations.Keys) {
            $doc = $good | ConvertTo-Json -Depth 8 | ConvertFrom-Json
            & $mutations[$name] $doc
            [IO.File]::WriteAllText($scratch, ($doc | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
            $refused = $false
            try { [void](Read-RetiredCopilotInstructions -Path $scratch) } catch { $refused = $_.Exception.Message -match 'malformed retired-copilot-instructions' }
            Assert $refused "the reader accepted a retired-copilot-instructions key with $name"
        }
    } finally { Remove-Item -LiteralPath $scratch -Force -ErrorAction SilentlyContinue }
}

# The eight seeded team files an update may replace while they hold a released text (B-573): one key in the source ledger,
# its maintainer baseline and the three dists, listing the shipped installer's Get-LfSha256 of every blob a tag v0.26.0 to
# v0.99.1 held at the path in any dist, and of today's composed seed.
$seedFilePaths = @('TECH_DEBT.md', 'SECURITY_FINDINGS.md', 'LEARNINGS.md', 'FRAMEWORK-CONTEXT.md', 'docs/ARCHITECTURE.md',
    'docs/architecture-decisions.md', 'docs/wiki/INDEX.md', '.claude/guard-allowlist.txt')

It 'old seed files: the ledger lists every released text of the eight seeded team files and today''s seeds' {
    $copies = @('src/core/framework-retirements.json', 'meta/framework-retirements-baseline.json', 'dist/dotnet/framework-retirements.json', 'dist/angular/framework-retirements.json', 'dist/monorepo/framework-retirements.json')
    $source = ([IO.File]::ReadAllText((Join-Path $repoRoot $copies[0])) | ConvertFrom-Json).'superseded-seed-files'
    Assert ($null -ne $source) 'the source ledger has no superseded-seed-files key'
    Assert ((@($source | ForEach-Object path) -join ', ') -ceq ($seedFilePaths -join ', ')) "superseded-seed-files lists $(@($source | ForEach-Object path) -join ', ')"
    $sourceJson = $source | ConvertTo-Json -Depth 8 -Compress
    foreach ($copy in $copies) {
        $other = ([IO.File]::ReadAllText((Join-Path $repoRoot $copy)) | ConvertFrom-Json).'superseded-seed-files' | ConvertTo-Json -Depth 8 -Compress
        Assert ($other -ceq $sourceJson) "$copy carries a different superseded-seed-files"
    }
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1'), [ref]$null, [ref]$null)
    $function = @($ast.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -ceq 'Get-LfSha256' })
    Assert ($function.Count -eq 1) 'the shipped installer has no Get-LfSha256'
    . ([scriptblock]::Create($function[0].Extent.Text))
    $listed = @{}
    foreach ($entry in $source) {
        $set = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        foreach ($hash in @($entry.'known-content-sha256')) { [void]$set.Add([string]$hash) }
        $listed[[string]$entry.path] = $set
    }
    $observations = @(Get-TaggedObservations -Paths $seedFilePaths -Through '0.99.1' | Where-Object { [version]$_.Tag.Substring(1) -ge [version]'0.26.0' })
    foreach ($path in $seedFilePaths) { Assert (@($observations | Where-Object Path -ceq $path).Count -gt 0) "no released blob was observed for $path" }
    $digestByOid = @{}
    foreach ($observation in $observations) {
        if (-not $digestByOid.ContainsKey($observation.Oid)) {
            $blob = Invoke-GitBytes @('cat-file', 'blob', $observation.Oid)
            Assert ($blob.Exit -eq 0) "could not read blob $($observation.Oid)"
            $digestByOid[$observation.Oid] = Get-LfSha256 -Bytes $blob.Bytes
        }
    }
    $check = {
        param($Map)
        foreach ($observation in $observations) {
            $hash = [string]$digestByOid[$observation.Oid]
            if (-not $Map[$observation.Path].Contains($hash)) { throw "missing tagged digest: $($observation.Tag) dist/$($observation.Stack)/$($observation.Path) sha256=$hash" }
        }
        foreach ($stack in 'dotnet', 'angular', 'monorepo') { foreach ($path in $seedFilePaths) {
            $file = Join-Path $repoRoot "dist/$stack/$path"
            if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }
            $hash = Get-LfSha256 -Bytes ([IO.File]::ReadAllBytes($file))
            if (-not $Map[$path].Contains($hash)) { throw "missing seed digest: dist/$stack/$path sha256=$hash" }
        } }
    }
    & $check $listed
    $total = 0; foreach ($set in $listed.Values) { $total += $set.Count }
    Assert ($listed['docs/ARCHITECTURE.md'].Count -eq 57 -and $total -eq 96) "expected 57 docs/ARCHITECTURE.md texts and 96 in all, got $($listed['docs/ARCHITECTURE.md'].Count) and $total"
    # Hostile calibration: drop one observed digest from a copy; the same check must go red.
    $first = $observations | Where-Object Path -ceq 'docs/ARCHITECTURE.md' | Select-Object -First 1
    $bad = @{}; foreach ($key in $listed.Keys) { $bad[$key] = New-Object 'System.Collections.Generic.HashSet[string]' ($listed[$key], [StringComparer]::Ordinal) }
    Assert ($bad['docs/ARCHITECTURE.md'].Remove([string]$digestByOid[$first.Oid])) 'could not plant the missing-digest mutation'
    $caught = $false
    try { & $check $bad } catch { $caught = $_.Exception.Message -match 'missing tagged digest' }
    Assert $caught 'removing a released seed digest did not make the completeness check go red'
}

It 'old seed files: the build refuses a seed the ledger does not list and a baseline digest that went missing' {
    $subject = Join-Path ([IO.Path]::GetTempPath()) ('seed-build-' + [guid]::NewGuid().ToString('N'))
    try {
        foreach ($dir in 'scripts', 'src/core/scripts', 'src/core/.claude', 'src/core/docs', 'meta', 'src/stacks/dotnet/files', 'src/stacks/dotnet/snippets') {
            New-Item -ItemType Directory -Force -Path (Join-Path $subject $dir) | Out-Null
        }
        foreach ($file in 'scripts/build.ps1', 'src/core/scripts/install.ps1', 'src/core/.claude/ai-audit.log', 'src/core/docs/architecture-decisions.md', 'src/core/framework-retirements.json', 'meta/framework-retirements-baseline.json') {
            Copy-Item -LiteralPath (Join-Path $repoRoot $file) -Destination (Join-Path $subject $file) -Force
        }
        $build = {
            $out = & (Get-PsExe) -NoProfile -File (Join-Path $subject 'scripts/build.ps1') dotnet 2>&1 | Out-String
            [pscustomobject]@{ Exit = $LASTEXITCODE; Output = $out }
        }
        $clean = & $build
        Assert ($clean.Exit -eq 0) "the unmutated subject did not build: exit $($clean.Exit) $($clean.Output)"
        $seed = Join-Path $subject 'src/core/docs/architecture-decisions.md'
        [IO.File]::AppendAllText($seed, "one extra line`n", [Text.UTF8Encoding]::new($false))
        $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1'), [ref]$null, [ref]$null)
        . ([scriptblock]::Create(@($ast.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -ceq 'Get-LfSha256' })[0].Extent.Text))
        $digest = Get-LfSha256 -Bytes ([IO.File]::ReadAllBytes($seed))
        $refused = & $build
        Assert ($refused.Exit -eq 1 -and $refused.Output -match [regex]::Escape("dist/dotnet/docs/architecture-decisions.md is a seed text") -and $refused.Output.Contains("add $digest")) "the build did not refuse an unlisted seed by path and digest: exit $($refused.Exit) $($refused.Output)"
        Copy-Item -LiteralPath (Join-Path $repoRoot 'src/core/docs/architecture-decisions.md') -Destination $seed -Force
        $ledgerFile = Join-Path $subject 'src/core/framework-retirements.json'
        $doc = [IO.File]::ReadAllText($ledgerFile) | ConvertFrom-Json
        $entry = @($doc.'superseded-seed-files' | Where-Object path -ceq 'docs/ARCHITECTURE.md')[0]
        # An old text, not the seed this subject composes (the subject has no docs/ARCHITECTURE.md seed at all).
        $dropped = [string]$entry.'known-content-sha256'[0]
        $entry.'known-content-sha256' = @($entry.'known-content-sha256' | Where-Object { $_ -cne $dropped })
        [IO.File]::WriteAllText($ledgerFile, ($doc | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
        $gone = & $build
        Assert ($gone.Exit -eq 1 -and $gone.Output.Contains("known seed digest $dropped for 'docs/ARCHITECTURE.md'")) "the build did not refuse a dropped baseline digest: exit $($gone.Exit) $($gone.Output)"
    } finally { Remove-Item -LiteralPath $subject -Recurse -Force -ErrorAction SilentlyContinue }
}

# The shipped installer reads the key strictly: a malformed one throws, and the installer reads the ledger before it changes
# anything, so such a ledger stops an update first.
It 'old seed files: the shipped installer reads superseded-seed-files strictly' {
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1'), [ref]$null, [ref]$null)
    $function = @($ast.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -ceq 'Read-SupersededSeedFiles' })
    Assert ($function.Count -eq 1) 'the shipped installer has no Read-SupersededSeedFiles'
    . ([scriptblock]::Create($function[0].Extent.Text))
    $read = Read-SupersededSeedFiles -Path (Join-Path $repoRoot 'dist/dotnet/framework-retirements.json') -Allowed $seedFilePaths
    Assert ($read.Count -eq 8 -and (@($read | ForEach-Object Path) -join ', ') -ceq ($seedFilePaths -join ', ')) "the reader returned $($read.Count) entries"
    $scratch = Join-Path ([IO.Path]::GetTempPath()) ('seed-ledger-' + [guid]::NewGuid().ToString('N') + '.json')
    try {
        $good = [IO.File]::ReadAllText((Join-Path $repoRoot 'dist/dotnet/framework-retirements.json'))
        $mutations = [ordered]@{
            'an upper-case digest' = { param($d) $d.'superseded-seed-files'[0].'known-content-sha256'[0] = $d.'superseded-seed-files'[0].'known-content-sha256'[0].ToUpperInvariant() }
            'a 63-character digest' = { param($d) $d.'superseded-seed-files'[0].'known-content-sha256'[0] = $d.'superseded-seed-files'[0].'known-content-sha256'[0].Substring(1) }
            'a repeated digest' = { param($d) $d.'superseded-seed-files'[0].'known-content-sha256' = @($d.'superseded-seed-files'[0].'known-content-sha256') + @($d.'superseded-seed-files'[0].'known-content-sha256'[0]) }
            'a path that is not one of the eight' = { param($d) $d.'superseded-seed-files'[0].path = 'README.md' }
            'a repeated path' = { param($d) $d.'superseded-seed-files'[1].path = $d.'superseded-seed-files'[0].path }
            'a missing known-content-sha256' = { param($d) $d.'superseded-seed-files'[0].PSObject.Properties.Remove('known-content-sha256') }
            'no digest' = { param($d) $d.'superseded-seed-files'[0].'known-content-sha256' = @() }
            'no entry' = { param($d) $d.'superseded-seed-files' = @() }
            'a string for the key' = { param($d) $d.'superseded-seed-files' = 'x' }
        }
        foreach ($name in $mutations.Keys) {
            $doc = $good | ConvertFrom-Json
            & $mutations[$name] $doc
            [IO.File]::WriteAllText($scratch, ($doc | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
            $refused = $false
            try { [void](Read-SupersededSeedFiles -Path $scratch -Allowed $seedFilePaths) } catch { $refused = $_.Exception.Message -match 'malformed superseded-seed-files' }
            Assert $refused "the reader accepted a superseded-seed-files key with $name"
        }
    } finally { Remove-Item -LiteralPath $scratch -Force -ErrorAction SilentlyContinue }
}

# B-573: the single old seed lines an update rewords (superseded-seed-lines), one key in the source ledger, its maintainer
# baseline and the three dists. Each listed line is one a release from 0.76.0 shipped at its file and place (AGENTS.md read in
# CLAUDE.md before the layout moved); each successor's lines stand, in that order, in today's seed at that place for some
# product; and every distinct old text of each listed slot (found by its opening words) that no product ships there today is
# listed. The shipped reader takes the key and refuses a malformed one.
It 'old seed lines: the ledger lists every old text of each listed slot releases from 0.76.0 shipped, each with a successor today ships' {
    $copies = @('src/core/framework-retirements.json', 'meta/framework-retirements-baseline.json', 'dist/dotnet/framework-retirements.json', 'dist/angular/framework-retirements.json', 'dist/monorepo/framework-retirements.json')
    $source = ([IO.File]::ReadAllText((Join-Path $repoRoot $copies[0])) | ConvertFrom-Json).'superseded-seed-lines'
    Assert ($null -ne $source) 'the source ledger has no superseded-seed-lines key'
    $sourceJson = $source | ConvertTo-Json -Depth 8 -Compress
    foreach ($copy in $copies) {
        $other = ([IO.File]::ReadAllText((Join-Path $repoRoot $copy)) | ConvertFrom-Json).'superseded-seed-lines' | ConvertTo-Json -Depth 8 -Compress
        Assert ($other -ceq $sourceJson) "$copy carries a different superseded-seed-lines"
    }
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1'), [ref]$null, [ref]$null)
    $wanted = @('Read-SupersededSeedLines', 'Get-InstructionLineCore', 'Get-InstructionDigest', 'Get-InstructionFences', 'Get-InstructionSections')
    $functions = @($ast.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $wanted -ccontains $_.Name })
    Assert ($functions.Count -eq $wanted.Count) "the shipped installer defines $($functions.Count) of $($wanted -join ', ')"
    . ([scriptblock]::Create((@($functions | ForEach-Object { $_.Extent.Text }) -join "`n")))
    # The slots the ledger covers, each found in its place by the opening words every text of it shared.
    $slots = @(
        @{ File = 'SECURITY_FINDINGS.md'; Place = ''; Opening = '^> Managed by ' },
        @{ File = 'SECURITY_FINDINGS.md'; Place = ''; Opening = '^> Run `/security-' },
        @{ File = 'SECURITY_FINDINGS.md'; Place = '## Findings'; Opening = '^\| _  \| _ ' },
        @{ File = 'FRAMEWORK-CONTEXT.md'; Place = ''; Opening = '^> \*\*Precedence\*\*: ' },
        @{ File = 'docs/architecture-decisions.md'; Place = ''; Opening = '^Append-only ADR log\. ' },
        @{ File = 'AGENTS.md'; Place = '## Common Tasks'; Opening = '^(Recipes live as |Skills are a delivery-profile superset|evidence satisfies the gate)' },
        @{ File = 'AGENTS.md'; Place = '## Common Tasks'; Opening = '^`/bootstrap` ' },
        @{ File = 'AGENTS.md'; Place = '## Common Tasks'; Opening = '^\*\*Registers\*\*: ' },
        @{ File = 'AGENTS.md'; Place = '## Architecture Decisions'; Opening = '^\s+added by the create-adr skill\. ' }
    )
    $files = @($slots | ForEach-Object { $_.File } | Select-Object -Unique)
    # The non-fenced lines of each place of a text, as the installer reads them.
    $places = {
        param([string]$Text)
        $parsed = Get-InstructionSections -Text $Text.TrimStart([char]0xFEFF)
        $map = @{}
        $first = if ($parsed.Sections.Count -gt 0) { $parsed.Sections[0].Start } else { $parsed.Lines.Length }
        $map[''] = @(for ($i = 0; $i -lt $first; $i++) { if (-not $parsed.Fenced[$i]) { Get-InstructionLineCore -Line $parsed.Lines[$i] } })
        foreach ($section in $parsed.Sections) { $map[$section.Heading] = @(for ($i = $section.Start + 1; $i -lt $section.End; $i++) { if (-not $parsed.Fenced[$i]) { Get-InstructionLineCore -Line $parsed.Lines[$i] } }) }
        return $map
    }
    $show = { param([string]$Spec) $r = Invoke-GitBytes @('cat-file', 'blob', $Spec); if ($r.Exit -ne 0) { return $null }; [Text.UTF8Encoding]::new($false).GetString($r.Bytes) }
    $shipped = @{}   # file|place|digest -> text, every line a release shipped there
    $old = @{}       # file|place|digest -> 'tag/product', the slot texts
    $tags = @(& git -C $repoRoot tag --list 'v*' | Where-Object { $_ -match '^v(\d+\.\d+\.\d+)$' -and [version]$Matches[1] -ge [version]'0.76.0' })
    Assert ($tags.Count -ge 48) "expected at least 48 tags from v0.76.0, got $($tags.Count)"
    foreach ($tag in $tags) { foreach ($p in 'dotnet', 'angular', 'monorepo') {
        $claude = & $show "${tag}:dist/$p/CLAUDE.md"
        $instruction = if ($claude -match '(?m)^@AGENTS\.md') { 'AGENTS.md' } else { 'CLAUDE.md' }
        foreach ($file in $files) {
            $text = & $show "${tag}:dist/$p/$(if ($file -ceq 'AGENTS.md') { $instruction } else { $file })"
            Assert ($null -ne $text) "could not read $tag dist/$p/$file"
            $map = & $places $text
            foreach ($place in $map.Keys) { foreach ($line in $map[$place]) { $shipped["$file|$place|$(Get-InstructionDigest -Text $line)"] = $line } }
            foreach ($slot in @($slots | Where-Object { $_.File -ceq $file })) {
                foreach ($line in @($map[$slot.Place] | Where-Object { $_ -cmatch $slot.Opening })) { $old["$file|$($slot.Place)|$(Get-InstructionDigest -Text $line)"] = "$tag/$p" }
            }
        }
    } }
    $today = @{}     # file|place -> the lines of each product's seed there
    foreach ($p in 'dotnet', 'angular', 'monorepo') { foreach ($file in $files) {
        $map = & $places ([Text.UTF8Encoding]::new($false).GetString([IO.File]::ReadAllBytes((Join-Path $repoRoot "dist/$p/$file"))))
        foreach ($place in $map.Keys) { if (-not $today.ContainsKey("$file|$place")) { $today["$file|$place"] = @() }; $today["$file|$place"] += , @($map[$place]) }
    } }
    $todayHas = { param([string]$Key, [string]$Line) @($today[$Key] | Where-Object { $_ -ccontains $Line }).Count -gt 0 }
    $check = {
        param($Entries)
        $listed = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        foreach ($entry in $Entries) {
            $key = "$($entry.file)|$($entry.place)|$($entry.'known-line-sha256')"
            [void]$listed.Add($key)
            if (-not $shipped.ContainsKey($key)) { throw "listed line $key is no line a release from 0.76.0 shipped at that file and place" }
            if ($null -ne $entry.replacement) {
                $want = @($entry.replacement.Split([char]10))
                $found = $false
                foreach ($lines in @($today["$($entry.file)|$($entry.place)"])) {
                    for ($i = 0; $i + $want.Count -le $lines.Count -and -not $found; $i++) { $found = (@($lines[$i..($i + $want.Count - 1)]) -join "`n") -ceq ($want -join "`n") }
                }
                if (-not $found) { throw "successor of $key is not in today's seed at that place: $($entry.replacement)" }
            }
        }
        foreach ($key in $old.Keys) {
            $parts = $key.Split('|')
            if (& $todayHas "$($parts[0])|$($parts[1])" $shipped[$key]) { continue }
            if (-not $listed.Contains($key)) { throw "missing old seed line: $($parts[0]) '$($parts[1])' '$($shipped[$key])' ($($old[$key]))" }
        }
    }
    & $check @($source)
    Assert (@($source).Count -eq 10) "expected 10 old seed lines, got $(@($source).Count)"
    # Hostile calibration: drop one entry; the same check must go red.
    $caught = $false
    try { & $check @($source | Select-Object -Skip 1) } catch { $caught = $_.Exception.Message -match 'missing old seed line' }
    Assert $caught 'dropping a listed old seed line did not make the completeness check go red'
    $read = Read-SupersededSeedLines -Path (Join-Path $repoRoot 'dist/dotnet/framework-retirements.json') -Allowed @('AGENTS.md', 'SECURITY_FINDINGS.md', 'FRAMEWORK-CONTEXT.md', 'docs/architecture-decisions.md')
    Assert ($read.Count -eq 4 -and $read['AGENTS.md'].Count -eq 5) "the shipped reader returned $($read.Count) files and $($read['AGENTS.md'].Count) AGENTS.md lines, expected 4 and 5"
    $scratch = Join-Path ([IO.Path]::GetTempPath()) ('seed-lines-' + [guid]::NewGuid().ToString('N') + '.json')
    try {
        $good = [IO.File]::ReadAllText((Join-Path $repoRoot 'dist/dotnet/framework-retirements.json'))
        $mutations = [ordered]@{
            'a file not allowed' = { param($d) $d.'superseded-seed-lines'[0].file = 'README.md' }
            'a place that is no level-2 heading' = { param($d) $d.'superseded-seed-lines'[0].place = '# Top' }
            'an upper-case digest' = { param($d) $d.'superseded-seed-lines'[0].'known-line-sha256' = $d.'superseded-seed-lines'[0].'known-line-sha256'.ToUpperInvariant() }
            'a repeated line' = { param($d) $d.'superseded-seed-lines'[1].'known-line-sha256' = $d.'superseded-seed-lines'[0].'known-line-sha256' }
            'no replacement key' = { param($d) $d.'superseded-seed-lines'[0].PSObject.Properties.Remove('replacement') }
            'a CR in a successor' = { param($d) $d.'superseded-seed-lines'[0].replacement = "a`r`nb" }
            'an empty successor line' = { param($d) $d.'superseded-seed-lines'[0].replacement = "a`n " }
            'a guard that is not true or false' = { param($d) $d.'superseded-seed-lines'[0].'hanging-line-guard' = 'yes' }
            'no needs-instructions-in-agents key' = { param($d) $d.'superseded-seed-lines'[2].PSObject.Properties.Remove('needs-instructions-in-agents') }
            'a needs-instructions-in-agents that is not true or false' = { param($d) $d.'superseded-seed-lines'[0].'needs-instructions-in-agents' = 1 }
            'an empty about' = { param($d) $d.'superseded-seed-lines'[0].about = ' ' }
            'a successor that is itself listed' = { param($d) $d.'superseded-seed-lines'[0].replacement = $d.'superseded-seed-lines'[0].replacement; $d.'superseded-seed-lines'[1].'known-line-sha256' = (Get-InstructionDigest -Text $d.'superseded-seed-lines'[0].replacement) }
            'no entry' = { param($d) $d.'superseded-seed-lines' = @() }
        }
        foreach ($name in $mutations.Keys) {
            $doc = $good | ConvertFrom-Json
            & $mutations[$name] $doc
            [IO.File]::WriteAllText($scratch, ($doc | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
            $refused = $false
            try { [void](Read-SupersededSeedLines -Path $scratch -Allowed @('AGENTS.md', 'SECURITY_FINDINGS.md', 'FRAMEWORK-CONTEXT.md', 'docs/architecture-decisions.md')) } catch { $refused = $_.Exception.Message -match 'malformed superseded-seed-lines' }
            Assert $refused "the reader accepted a superseded-seed-lines key with $name"
        }
    } finally { Remove-Item -LiteralPath $scratch -Force -ErrorAction SilentlyContinue }
}

It '0.95.0 ledger contains every released digest of the renamed security-review command and its wrapper' {
    # B-388: renamed to security-gate, so both installed paths join the ledger.
    $paths = @('.claude/commands/security-review.md', '.agents/skills/security-review/SKILL.md')
    $ledger = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes((Join-Path $repoRoot 'src/core/framework-retirements.json'))).TrimStart([char]0xFEFF) | ConvertFrom-Json
    foreach ($path in $paths) {
        Assert (@($ledger.retirements | Where-Object { $_.path -ceq $path -and $_.'retired-in' -ceq '0.95.0' }).Count -eq 1) "no 0.95.0 retirement entry for $path"
    }
    # The command shipped from all three dists since the merge; its .agents/skills wrapper in 0.94.0 only.
    $observations = @(Get-TaggedObservations -Paths $paths -Through '0.94.0')
    foreach ($path in $paths) {
        foreach ($stack in @('dotnet', 'angular', 'monorepo')) {
            Assert (@($observations | Where-Object { $_.Path -ceq $path -and $_.Stack -ceq $stack }).Count -gt 0) "no released $stack blob was observed for $path"
        }
    }
    Assert-TaggedDigestCompleteness $observations (Get-LedgerDigestMap $ledger)
}

It 'raw Git capture preserves binary bytes and nonzero stderr' {
    $objects = Join-Path ([IO.Path]::GetTempPath()) ('b215-objects-' + [guid]::NewGuid().ToString('N'))
    $blobPath = Join-Path ([IO.Path]::GetTempPath()) ('b215-binary-' + [guid]::NewGuid().ToString('N') + '.bin')
    $previousObjects = $env:GIT_OBJECT_DIRECTORY
    try {
        New-Item -ItemType Directory -Force -Path $objects | Out-Null
        [byte[]]$expected = 0x00, 0x80, 0xFF, 0x0A, 0xC3, 0xA9
        [IO.File]::WriteAllBytes($blobPath, $expected)
        $env:GIT_OBJECT_DIRECTORY = $objects
        $oid = (& git -C $repoRoot hash-object -w -t blob $blobPath | Out-String).Trim()
        Assert ($LASTEXITCODE -eq 0 -and $oid -match '^[0-9a-f]{40}$') 'could not create the isolated binary Git object'

        $binary = Invoke-GitBytes @('cat-file','blob',$oid)
        Assert ($binary.Exit -eq 0) "binary Git read failed: $($binary.Error)"
        Assert ([Convert]::ToBase64String([byte[]]$binary.Bytes) -ceq [Convert]::ToBase64String($expected)) `
            'binary Git stdout was decoded, normalized, or truncated'

        $missing = Invoke-GitBytes @('cat-file','blob',('0' * 40))
        Assert ($missing.Exit -ne 0) 'missing Git object unexpectedly exited zero'
        Assert (-not [string]::IsNullOrWhiteSpace($missing.Error)) 'nonzero Git stderr was lost'
    } finally {
        if ($null -eq $previousObjects) { Remove-Item Env:GIT_OBJECT_DIRECTORY -ErrorAction SilentlyContinue }
        else { $env:GIT_OBJECT_DIRECTORY = $previousObjects }
        Remove-Item -LiteralPath $blobPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $objects -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'install.sh remains historical staging data, never an installed retirement entry' {
    $ledger = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'src/core/framework-retirements.json') | ConvertFrom-Json
    Assert (@($ledger.retirements | Where-Object path -ceq 'install.sh').Count -eq 0) 'install.sh was incorrectly added as an installed retirement'
    $release = [IO.File]::ReadAllText((Join-Path $repoRoot '.claude/scripts/release.ps1'))
    Assert ($release -match '\|install\\\.sh') 'historical release staging allowlist no longer retains install.sh'
}

exit (Write-TestSummary 'B215OwnershipBoundary.Tests')
