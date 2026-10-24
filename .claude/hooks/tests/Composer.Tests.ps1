# Composer executable red-tests and explicit ownership-policy pins.
. (Join-Path $PSScriptRoot '_MutationHelper.ps1')

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$psExe = (Get-Process -Id $PID).Path
$fixtureRoot = (Resolve-Path (Join-Path $PSScriptRoot 'fixtures')).Path

$expectedProtected = @(
    'CLAUDE.md', 'AGENTS.md', 'TECH_DEBT.md', 'SECURITY_FINDINGS.md', 'LEARNINGS.md',
    'FRAMEWORK-CONTEXT.md', '.github/copilot-instructions.md', 'docs/ARCHITECTURE.md',
    'docs/architecture-decisions.md', 'docs/wiki/INDEX.md'
)
$expectedPersistent = @('.claude/ai-audit.log')
$expectedMetadata = @('.git', '.template-repo', 'README.md', 'CHANGELOG.md', '.gitignore', '.gitattributes')
$expectedExcluded = @($expectedMetadata + @('scripts/install.ps1', '.github/workflows/template-ci.yml'))

function Get-SingleQuotedValues {
    param([string]$Text)
    return @([regex]::Matches($Text, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
}

function Assert-ExactSet {
    param([string]$Name, [string[]]$Actual, [string[]]$Expected)
    $actualSorted = [string[]]@($Actual)
    $expectedSorted = [string[]]@($Expected)
    [array]::Sort($actualSorted, [StringComparer]::Ordinal)
    [array]::Sort($expectedSorted, [StringComparer]::Ordinal)
    if (($actualSorted -join "`n") -cne ($expectedSorted -join "`n")) {
        throw "$Name drifted. actual={$($actualSorted -join ', ')} expected={$($expectedSorted -join ', ')}"
    }
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($value in $Actual) { if (-not $seen.Add($value)) { throw "$Name contains duplicate path: $value" } }
}

function Initialize-ComposerSubject {
    param([string]$SubjectRoot)
    New-Item -ItemType Directory -Path (Join-Path $SubjectRoot 'scripts') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $SubjectRoot 'src/core/scripts') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $SubjectRoot 'src/core/.claude') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $SubjectRoot 'src/core/docs') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $SubjectRoot 'meta') -Force | Out-Null
    foreach ($stack in @('dotnet','angular','monorepo')) {
        New-Item -ItemType Directory -Path (Join-Path $SubjectRoot "src/stacks/$stack/files") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $SubjectRoot "src/stacks/$stack/snippets") -Force | Out-Null
    }
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts/build.ps1') -Destination (Join-Path $SubjectRoot 'scripts') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'src/core/scripts/install.ps1') -Destination (Join-Path $SubjectRoot 'src/core/scripts') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'src/core/.claude/ai-audit.log') -Destination (Join-Path $SubjectRoot 'src/core/.claude') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'src/core/docs/architecture-decisions.md') -Destination (Join-Path $SubjectRoot 'src/core/docs') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'src/core/framework-retirements.json') -Destination (Join-Path $SubjectRoot 'src/core') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'meta/framework-retirements-baseline.json') -Destination (Join-Path $SubjectRoot 'meta') -Force
}

function Invoke-Composer {
    param([string]$SubjectRoot, [string]$Mode = 'dotnet', [string]$WorkingDirectory = $SubjectRoot, [string[]]$ExtraArguments = @())
    $process = Start-Process -FilePath $psExe -ArgumentList (@('-NoProfile','-File',(Join-Path $SubjectRoot 'scripts\build.ps1'),$Mode) + @($ExtraArguments | Where-Object { $_ })) `
        -WorkingDirectory $WorkingDirectory -Wait -PassThru -NoNewWindow
    return [int]$process.ExitCode
}

# Like Invoke-Composer, but also returns what the composer wrote to stderr.
function Invoke-ComposerCaptured {
    param([string]$SubjectRoot, [string]$Mode = 'dotnet')
    $errFile = Join-Path ([IO.Path]::GetTempPath()) ('composer-stderr-' + [guid]::NewGuid() + '.txt')
    $outFile = $errFile + '.out'
    try {
        $process = Start-Process -FilePath $psExe -ArgumentList @('-NoProfile','-File',(Join-Path $SubjectRoot 'scripts\build.ps1'),$Mode) `
            -WorkingDirectory $SubjectRoot -Wait -PassThru -NoNewWindow -RedirectStandardError $errFile -RedirectStandardOutput $outFile
        return [pscustomobject]@{ Exit = [int]$process.ExitCode; Stderr = [IO.File]::ReadAllText($errFile) }
    } finally {
        foreach ($f in @($errFile, $outFile)) { if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force } }
    }
}

$failed = 0
$executed = 0
$cases = @(
    @{ Name = 'PowerShell malformed marker'; Kind = 'marker' },
    @{ Name = 'PowerShell marker with a capital S in @Stack'; Kind = 'marker'; Replacement = '<!-- @Stack:fixture -->' },
    @{ Name = 'PowerShell unapproved overlay collision'; Kind = 'collision' },
    @{ Name = 'protected policy drift'; Kind = 'policy'; Target = 'src/core/scripts/install.ps1'; Find = "'CLAUDE.md'"; Replacement = "'NOT-CLAUDE.md'" },
    @{ Name = 'persistent policy drift'; Kind = 'policy'; Target = 'src/core/scripts/install.ps1'; Find = "'.claude/ai-audit.log'"; Replacement = "'.claude/not-the-audit.log'" },
    @{ Name = 'metadata policy drift'; Kind = 'policy'; Target = 'src/core/scripts/install.ps1'; Find = "'.template-repo'"; Replacement = "'.not-template-repo'" },
    @{ Name = 'exclusion policy drift'; Kind = 'policy'; Target = 'src/core/scripts/install.ps1'; Find = "'scripts/install.ps1', '.github/workflows/template-ci.yml'"; Replacement = "'scripts/install.ps1'" }
)

foreach ($case in $cases) {
    $policyInput = $null
    try {
        if ($case.Kind -eq 'policy') {
            $policyInput = Join-Path ([IO.Path]::GetTempPath()) ('composer-policy-' + [guid]::NewGuid())
            Initialize-ComposerSubject $policyInput
            $target = Join-Path $policyInput $case.Target
            $scratchSourceRoot = $policyInput
            $find = $case.Find
            $replacement = $case.Replacement
        } elseif ($case.Kind -eq 'marker') {
            $target = Join-Path $fixtureRoot 'composer-input.txt'
            $scratchSourceRoot = $fixtureRoot
            $find = '<!-- @stack:fixture -->'
            $replacement = if ($case.Replacement) { $case.Replacement } else { '<!-- @stack:fixture -- >' }
        } else {
            $target = Join-Path $fixtureRoot 'composer-input.txt'
            $scratchSourceRoot = $fixtureRoot
            $find = '<!-- @stack:fixture -->'
            $replacement = 'collision mutation'
        }
        Invoke-MutationRedTest -TargetFile $target -ScratchSourceRoot $scratchSourceRoot -Find $find -Replacement $replacement -ExpectedExit 1 -Command {
            param($scratchTarget, $scratchRoot)
            $subjectRoot = if ($case.Kind -eq 'policy') { $scratchRoot } else { Join-Path $scratchRoot 'composer-subject' }
            if ($case.Kind -ne 'policy') {
                Initialize-ComposerSubject $subjectRoot
                if ($case.Kind -eq 'collision') {
                    Copy-Item -LiteralPath $scratchTarget -Destination (Join-Path $subjectRoot 'src/stacks/dotnet/files/collision.txt') -Force
                    Copy-Item -LiteralPath $scratchTarget -Destination (Join-Path $subjectRoot 'src/stacks/angular/files/collision.txt') -Force
                } else {
                    Copy-Item -LiteralPath $scratchTarget -Destination (Join-Path $subjectRoot 'src/core/marker.txt') -Force
                }
            }
            $mode = if ($case.Kind -eq 'marker') { 'dotnet' } else { 'monorepo' }
            $global:LASTEXITCODE = Invoke-Composer $subjectRoot $mode
        } | Out-Null
        $executed++
        Write-Host "[ok] $($case.Name): composer went red"
    } catch {
        $failed++
        [Console]::Error.WriteLine("[FAIL] $($case.Name): $($_.Exception.Message)")
    } finally {
        if ($policyInput -and (Test-Path -LiteralPath $policyInput)) { Remove-Item -Recurse -Force -LiteralPath $policyInput }
    }
}

# Pin every install.ps1-derived policy set independently of the composer's own expectation.
try {
    $installer = [IO.File]::ReadAllText((Join-Path $repoRoot 'src/core/scripts/install.ps1'))
    $protectedMatch = [regex]::Match($installer, '(?ms)^\$protected\s*=\s*@\((.*?)\)')
    $persistentMatch = [regex]::Match($installer, '(?ms)^\$persistentCopyIfAbsent\s*=\s*@\((.*?)\)')
    $metadataMatch = [regex]::Match($installer, '(?m)^\$metaFiles\s*=\s*@\(([^\r\n]+)\)')
    $excludedMatch = [regex]::Match($installer, '(?ms)^\$excludedFromInstall\s*=\s*@\((.*?)\)')
    if (-not $protectedMatch.Success -or -not $persistentMatch.Success -or -not $metadataMatch.Success -or -not $excludedMatch.Success) { throw 'could not extract all install.ps1 ownership policy sets' }
    Assert-ExactSet 'protected policy' @(Get-SingleQuotedValues $protectedMatch.Groups[1].Value) $expectedProtected
    Assert-ExactSet 'persistent policy' @(Get-SingleQuotedValues $persistentMatch.Groups[1].Value) $expectedPersistent
    Assert-ExactSet 'metadata policy' @(Get-SingleQuotedValues $metadataMatch.Groups[1].Value) $expectedMetadata
    Assert-ExactSet 'excluded policy' @(Get-SingleQuotedValues $excludedMatch.Groups[1].Value) $expectedExcluded
    $executed += 4
    Write-Host '[ok] ownership policy sets match all four explicit installer pins'
} catch {
    $failed++
    [Console]::Error.WriteLine("[FAIL] ownership policy pins: $($_.Exception.Message)")
}

# Normal extraction must classify every protected path and omit every install-excluded path.
$normalRoot = Join-Path ([IO.Path]::GetTempPath()) ('composer-policy-green-' + [guid]::NewGuid())
try {
    Initialize-ComposerSubject $normalRoot
    foreach ($relative in $expectedProtected) {
        $path = Join-Path $normalRoot "src/core/$relative"
        New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
        if (-not (Test-Path -LiteralPath $path)) { [IO.File]::WriteAllText($path, 'policy canary', [Text.UTF8Encoding]::new($false)) }
    }
    $templateCi = Join-Path $normalRoot 'src/core/.github/workflows/template-ci.yml'
    New-Item -ItemType Directory -Path (Split-Path -Parent $templateCi) -Force | Out-Null
    [IO.File]::WriteAllText($templateCi, 'excluded canary', [Text.UTF8Encoding]::new($false))
    $exit = Invoke-Composer $normalRoot
    if ($exit -ne 0) { throw "unmodified PowerShell composer exited $exit" }
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $normalRoot 'dist/dotnet/framework-ownership.json') | ConvertFrom-Json
    foreach ($relative in $expectedProtected + $expectedPersistent) {
        $entry = @($manifest.paths | Where-Object path -ceq $relative)
        if ($entry.Count -ne 1 -or $entry[0].ownership -cne 'consumer-owned/protected') { throw "composer did not emit protected ownership for $relative" }
    }
    foreach ($relative in @('scripts/install.ps1', '.github/workflows/template-ci.yml')) {
        if (@($manifest.paths | Where-Object path -ceq $relative).Count -ne 0) { throw "composer emitted excluded path $relative" }
    }
    $executed++
    Write-Host '[ok] ownership-policy extraction and manifest classification stayed green'
} catch {
    $failed++
    [Console]::Error.WriteLine("[FAIL] ownership-policy extraction: $($_.Exception.Message)")
} finally {
    if (Test-Path -LiteralPath $normalRoot) { Remove-Item -Recurse -Force -LiteralPath $normalRoot }
}

# The composer must act on the repo its script lives in, not on the process working directory it was
# launched from (B-371: a build.ps1 launched from another repo rewrote that repo's dist/).
$anchorSubject = Join-Path ([IO.Path]::GetTempPath()) ('composer-anchor-subject-' + [guid]::NewGuid())
$anchorDecoy = Join-Path ([IO.Path]::GetTempPath()) ('composer-anchor-decoy-' + [guid]::NewGuid())
try {
    Initialize-ComposerSubject $anchorSubject
    Initialize-ComposerSubject $anchorDecoy
    # A decoy that already holds the composer's output root, as the real repository did.
    New-Item -ItemType Directory -Path (Join-Path $anchorDecoy 'dist/dotnet') -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $anchorDecoy 'dist/dotnet/framework-retirements.json'), '[]')
    $decoyBefore = @(Get-ChildItem -LiteralPath $anchorDecoy -Recurse -Force -File | ForEach-Object { $_.FullName.Substring($anchorDecoy.Length) + '|' + $_.Length + '|' + $_.LastWriteTimeUtc.Ticks } | Sort-Object)
    $exit = Invoke-Composer $anchorSubject 'dotnet' $anchorDecoy
    if ($exit -ne 0) { throw "composer launched from a foreign working directory exited $exit" }
    $decoyAfter = @(Get-ChildItem -LiteralPath $anchorDecoy -Recurse -Force -File | ForEach-Object { $_.FullName.Substring($anchorDecoy.Length) + '|' + $_.Length + '|' + $_.LastWriteTimeUtc.Ticks } | Sort-Object)
    if (($decoyBefore -join "`n") -cne ($decoyAfter -join "`n")) { throw 'composer touched the foreign working directory instead of its own repo' }
    if (-not (Test-Path -LiteralPath (Join-Path $anchorSubject 'dist/dotnet/framework-ownership.json') -PathType Leaf)) { throw 'composer did not produce dist/dotnet in its own repo' }
    $executed++
    Write-Host '[ok] composer anchors to its own repo when launched from another working directory'
} catch {
    $failed++
    [Console]::Error.WriteLine("[FAIL] composer anchors to its own repo when launched from another working directory -- $($_.Exception.Message)")
} finally {
    foreach ($dir in @($anchorSubject, $anchorDecoy)) { if (Test-Path -LiteralPath $dir) { Remove-Item -Recurse -Force -LiteralPath $dir } }
}

# A host scanner (antivirus, indexer) may map a dist file the moment it appears, and truncating a
# mapped file fails (0x800704C8: four of five 0.96.0 releases refused at compose dist/monorepo).
# The composer must write each dist path once; here a watcher maps a path that three overlays carry.
$mapSubject = Join-Path ([IO.Path]::GetTempPath()) ('composer-mapped-' + [guid]::NewGuid())
$mapSync = [hashtable]::Synchronized(@{ Armed = $false; Mapped = $false; Stop = $false; Error = $null })
$mapShell = $null
try {
    Initialize-ComposerSubject $mapSubject
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    foreach ($stack in @('dotnet','angular','monorepo')) {
        [IO.File]::WriteAllText((Join-Path $mapSubject "src/stacks/$stack/files/a-mapped.md"), "$stack overlay`n", $utf8)
    }
    # Writes that fall between the first and the last overlay of a-mapped.md, giving the watcher time.
    for ($i = 0; $i -lt 300; $i++) { [IO.File]::WriteAllText((Join-Path $mapSubject "src/stacks/dotnet/files/z-filler-$i.md"), "filler`n", $utf8) }
    $mapShell = [powershell]::Create()
    [void]$mapShell.AddScript({
        param($Path, $Sync)
        $deadline = [DateTime]::UtcNow.AddSeconds(60)
        $fs = $null; $mmf = $null; $view = $null
        $Sync.Armed = $true
        try {
            while (-not $view -and -not $Sync.Stop -and [DateTime]::UtcNow -lt $deadline) {
                try {
                    $fs = New-Object System.IO.FileStream($Path, 'Open', 'Read', 'ReadWrite, Delete')
                    if ($fs.Length -gt 0) {
                        if ($PSVersionTable.PSEdition -eq 'Desktop') {
                            $mmf = [System.IO.MemoryMappedFiles.MemoryMappedFile]::CreateFromFile($fs, [NullString]::Value, 0, 'Read', $null, 'None', $true)
                        } else {
                            $mmf = [System.IO.MemoryMappedFiles.MemoryMappedFile]::CreateFromFile($fs, [NullString]::Value, 0, 'Read', 'None', $true)
                        }
                        $view = $mmf.CreateViewAccessor(0, 0, 'Read')
                        $Sync.Mapped = $true
                    } else { $fs.Dispose(); $fs = $null }
                } catch {
                    $Sync.Error = $_.Exception.Message
                    if ($mmf) { $mmf.Dispose(); $mmf = $null }
                    if ($fs) { $fs.Dispose(); $fs = $null }
                }
                if (-not $view) { Start-Sleep -Milliseconds 1 }
            }
            while (-not $Sync.Stop -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 20 }
        } finally {
            if ($view) { $view.Dispose() }
            if ($mmf) { $mmf.Dispose() }
            if ($fs) { $fs.Dispose() }
        }
    }).AddArgument((Join-Path $mapSubject 'dist/monorepo/a-mapped.md')).AddArgument($mapSync)
    $mapAsync = $mapShell.BeginInvoke()
    $armDeadline = [DateTime]::UtcNow.AddSeconds(10)
    while (-not $mapSync.Armed -and [DateTime]::UtcNow -lt $armDeadline) { Start-Sleep -Milliseconds 20 }
    if (-not $mapSync.Armed) { throw 'watcher never started; case cannot examine the composer' }
    $exit = Invoke-Composer $mapSubject 'monorepo'
    if (-not $mapSync.Mapped) { throw "watcher never mapped dist/monorepo/a-mapped.md ($($mapSync.Error)); case cannot examine the composer" }
    if ($exit -ne 0) { throw "composer exited $exit after a scanner mapped a dist file it had already written" }
    $mapped = [IO.File]::ReadAllText((Join-Path $mapSubject 'dist/monorepo/a-mapped.md'))
    if ($mapped -cne "monorepo overlay`n") { throw "dist/monorepo/a-mapped.md is not the monorepo overlay: $mapped" }
    $executed++
    Write-Host '[ok] composer writes each dist path once while a scanner maps it'
} catch {
    $failed++
    [Console]::Error.WriteLine("[FAIL] composer writes each dist path once while a scanner maps it -- $($_.Exception.Message)")
} finally {
    $mapSync.Stop = $true
    if ($mapShell) { try { [void]$mapShell.EndInvoke($mapAsync) } catch { }; $mapShell.Dispose() }
    if (Test-Path -LiteralPath $mapSubject) { Remove-Item -Recurse -Force -LiteralPath $mapSubject }
}

# Retirement metadata authorizes deletion in consumers; keep its four composer boundaries under
# the supported PowerShell implementation.
foreach ($kind in @('unsafe-path','still-shipped','disappeared','synchronized-disappearance')) {
    $container = Join-Path ([IO.Path]::GetTempPath()) ('composer-retirement-' + [guid]::NewGuid())
    $subject = if ($kind -eq 'synchronized-disappearance') { Join-Path $container 'nested-subject' } else { $container }
    try {
        Initialize-ComposerSubject $subject
        $ledgerPath = Join-Path $subject 'src/core/framework-retirements.json'
        $maintainerLedgerPath = Join-Path $subject 'meta/framework-retirements-baseline.json'
        if ($kind -eq 'unsafe-path') {
            [IO.File]::WriteAllText($ledgerPath, ([IO.File]::ReadAllText($ledgerPath).Replace('scripts/impact-run.ps1', '../outside')), [Text.UTF8Encoding]::new($false))
        } elseif ($kind -eq 'still-shipped') {
            [IO.File]::WriteAllText((Join-Path $subject 'src/core/scripts/impact-run.ps1'), 'retired path must not ship', [Text.UTF8Encoding]::new($false))
        }
        if ($kind -in @('disappeared','synchronized-disappearance')) {
            if ((Invoke-Composer $subject) -ne 0) { throw 'initial cumulative-ledger build failed' }
            if ($kind -eq 'synchronized-disappearance') {
                New-Item -ItemType Directory -Path (Join-Path $container 'src/core') -Force | Out-Null
                [IO.File]::WriteAllText((Join-Path $container 'src/core/framework-retirements.json'), "{}`n", [Text.UTF8Encoding]::new($false))
                & git -C $container init --quiet
                & git -C $container config user.email 'composer-parent@example.invalid'
                & git -C $container config user.name 'Unrelated Parent'
                & git -C $container add src/core/framework-retirements.json
                & git -C $container commit --quiet -m 'unrelated parent ledger'
                & git -C $subject init --quiet
                & git -C $subject config user.email 'composer-test@example.invalid'
                & git -C $subject config user.name 'Composer Test'
                & git -C $subject add --all
                & git -C $subject commit --quiet -m 'retirement baseline'
                & git -C $subject tag v0.76.0
                if ($LASTEXITCODE -ne 0) { throw 'could not establish independent committed retirement baseline' }
            }
            $remaining = @(Get-Content -LiteralPath $ledgerPath | Where-Object { $_ -notmatch '"path"\s*:\s*"scripts/impact-run\.ps1"' })
            [IO.File]::WriteAllText($ledgerPath, (($remaining -join "`n") + "`n"), [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText((Join-Path $subject 'dist/dotnet/framework-retirements.json'), (($remaining -join "`n") + "`n"), [Text.UTF8Encoding]::new($false))
            if ($kind -eq 'synchronized-disappearance') { [IO.File]::WriteAllText($maintainerLedgerPath, (($remaining -join "`n") + "`n"), [Text.UTF8Encoding]::new($false)) }
        }
        $refArguments = if ($kind -eq 'synchronized-disappearance') { @('-RetirementBaselineRef','v0.76.0') } else { @() }
        $exit = Invoke-Composer $subject -ExtraArguments $refArguments
        if ($exit -eq 0) { throw "$kind retirement mutation stayed green" }
        $executed++
        Write-Host "[ok] PowerShell retirement ${kind}: composer went red"
    } catch {
        $failed++
        [Console]::Error.WriteLine("[FAIL] PowerShell retirement ${kind}: $($_.Exception.Message)")
    } finally {
        if (Test-Path -LiteralPath $container) { Remove-Item -Recurse -Force -LiteralPath $container }
    }
}

# The cumulative-retirement check decides from repository content and explicit inputs only: a stale
# dist, a git history or a tag nobody named must not change a build's verdict (AGENTS.md: gates are hermetic).
foreach ($caseName in @('retirement baseline ignores a stale dist', 'retirement baseline ref catches a synchronized removal', 'retirement baseline ref that does not resolve exits 2', 'retirement baseline ref that names no ref exits 2')) {
    $container = Join-Path ([IO.Path]::GetTempPath()) ('composer-hermetic-' + [guid]::NewGuid())
    try {
        Initialize-ComposerSubject $container
        $ledgerPath = Join-Path $container 'src/core/framework-retirements.json'
        $maintainerLedgerPath = Join-Path $container 'meta/framework-retirements-baseline.json'
        $utf8 = [Text.UTF8Encoding]::new($false)
        if ($caseName -eq 'retirement baseline ignores a stale dist') {
            if ((Invoke-Composer $container) -ne 0) { throw 'initial build failed' }
            $distLedger = Join-Path $container 'dist/dotnet/framework-retirements.json'
            $before = [IO.File]::ReadAllText($distLedger)
            $stale = [regex]::Replace($before, '\]\}\s*\]\s*\}\s*$',
                (']},' + "`n" + '    {"path":"zzz-stale-entry.md","retired-in":"0.1.0","known-content-sha256":["' + ('a' * 64) + '"]}' + "`n  ]`n}`n"))
            if ($stale -ceq $before) { throw 'could not plant the stale entry; case cannot examine the composer' }
            [IO.File]::WriteAllText($distLedger, $stale, $utf8)
            $exit = Invoke-Composer $container
            if ($exit -ne 0) { throw "a stale dist ledger entry changed the verdict (exit $exit)" }
        } else {
            & git -C $container init --quiet
            & git -C $container config user.email 'composer-test@example.invalid'
            & git -C $container config user.name 'Composer Test'
            if ($caseName -eq 'retirement baseline ref catches a synchronized removal') {
                & git -C $container add --all
                & git -C $container commit --quiet -m 'baseline'
                if ($LASTEXITCODE -ne 0) { throw 'could not commit the baseline; case cannot examine the composer' }
                $remaining = @(Get-Content -LiteralPath $ledgerPath | Where-Object { $_ -notmatch '"path"\s*:\s*"scripts/impact-run\.ps1"' })
                $text = (($remaining -join "`n") + "`n")
                [IO.File]::WriteAllText($ledgerPath, $text, $utf8)
                [IO.File]::WriteAllText($maintainerLedgerPath, $text, $utf8)
                $exit = Invoke-Composer $container
                if ($exit -ne 0) { throw "without a ref the synchronized removal should build from repository content alone (exit $exit)" }
                $exit = Invoke-Composer $container -ExtraArguments @('-RetirementBaselineRef','HEAD')
                if ($exit -eq 0) { throw 'the named ref held a retirement the tree removed, yet the build stayed green' }
            } elseif ($caseName -eq 'retirement baseline ref that names no ref exits 2') {
                # '""' reaches the script as an empty argument; ',' splits into nothing.
                foreach ($empty in @('""', ',')) {
                    $exit = Invoke-Composer $container -ExtraArguments @('-RetirementBaselineRef',$empty)
                    if ($exit -ne 2) { throw "-RetirementBaselineRef naming no ref ($empty) exited $exit, expected 2" }
                }
            } else {
                $exit = Invoke-Composer $container -ExtraArguments @('-RetirementBaselineRef','no-such-ref')
                if ($exit -ne 2) { throw "an unresolvable ref exited $exit, expected 2" }
            }
        }
        $executed++
        Write-Host "[ok] $caseName"
    } catch {
        $failed++
        [Console]::Error.WriteLine("[FAIL] $caseName -- $($_.Exception.Message)")
    } finally {
        if (Test-Path -LiteralPath $container) { Remove-Item -Recurse -Force -LiteralPath $container }
    }
}

# One marker grammar: a line that looks like a marker but is not exact (other case, no-break space, a
# vertical tab before it) used to be consumed silently by the composer and then unseen by validate-dist.
$lookAlikeRoot = Join-Path ([IO.Path]::GetTempPath()) ('composer-lookalike-' + [guid]::NewGuid())
try {
    Initialize-ComposerSubject $lookAlikeRoot
    $utf8 = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText((Join-Path $lookAlikeRoot 'src/core/marker.txt'),
        ("first`n<!-- @stack:fixture -->" + [char]0xA0 + "`nthird`n" + [char]0x0B + "# @stack:fixture`n<!-- @Stack:fixture -->`n"), $utf8)
    $result = Invoke-ComposerCaptured $lookAlikeRoot
    if ($result.Exit -ne 1) { throw "composer exited $($result.Exit) on three marker look-alikes, expected 1" }
    foreach ($line in 2, 4, 5) {
        if ($result.Stderr -notmatch [regex]::Escape("src/core/marker.txt:${line}:")) { throw "stderr does not name src/core/marker.txt line ${line}: $($result.Stderr)" }
    }
    $executed++
    Write-Host '[ok] composer refuses marker look-alikes naming file and line'
} catch {
    $failed++
    [Console]::Error.WriteLine("[FAIL] composer refuses marker look-alikes naming file and line -- $($_.Exception.Message)")
} finally {
    if (Test-Path -LiteralPath $lookAlikeRoot) { Remove-Item -Recurse -Force -LiteralPath $lookAlikeRoot }
}

# Byte-faithful: a source that is not valid UTF-8 used to be rewritten with U+FFFD in every dist.
$badByteRoot = Join-Path ([IO.Path]::GetTempPath()) ('composer-badbyte-' + [guid]::NewGuid())
try {
    Initialize-ComposerSubject $badByteRoot
    [IO.File]::WriteAllBytes((Join-Path $badByteRoot 'src/core/docs/notes.md'), [byte[]](0x63, 0x61, 0x66, 0xE9, 0x20, 0x97, 0x20, 0x6F, 0x6B, 0x0A))
    $result = Invoke-ComposerCaptured $badByteRoot
    if ($result.Exit -ne 1) { throw "composer exited $($result.Exit) on a source holding bytes that are not UTF-8, expected 1" }
    if ($result.Stderr -notmatch [regex]::Escape('docs/notes.md')) { throw "stderr does not name docs/notes.md: $($result.Stderr)" }
    if (Test-Path -LiteralPath (Join-Path $badByteRoot 'dist/dotnet/docs/notes.md')) { throw 'dist/dotnet/docs/notes.md was written from invalid bytes' }
    $executed++
    Write-Host '[ok] composer refuses a source that is not valid UTF-8 naming the file'
} catch {
    $failed++
    [Console]::Error.WriteLine("[FAIL] composer refuses a source that is not valid UTF-8 naming the file -- $($_.Exception.Message)")
} finally {
    if (Test-Path -LiteralPath $badByteRoot) { Remove-Item -Recurse -Force -LiteralPath $badByteRoot }
}

# A build that fails after it has started composing must leave the previous dist/<mode> in place.
$intactRoot = Join-Path ([IO.Path]::GetTempPath()) ('composer-intact-' + [guid]::NewGuid())
try {
    Initialize-ComposerSubject $intactRoot
    if ((Invoke-Composer $intactRoot) -ne 0) { throw 'initial build failed; case cannot examine the composer' }
    $sentinel = Join-Path $intactRoot 'dist/dotnet/zz-previous-build.txt'
    $manifest = Join-Path $intactRoot 'dist/dotnet/framework-ownership.json'
    [IO.File]::WriteAllText($sentinel, "previous`n")
    $manifestBefore = [IO.File]::ReadAllText($manifest)
    $installer = Join-Path $intactRoot 'src/core/scripts/install.ps1'
    [IO.File]::WriteAllText($installer, ([IO.File]::ReadAllText($installer).Replace("'.template-repo'", "'.not-template-repo'")), [Text.UTF8Encoding]::new($false))
    $result = Invoke-ComposerCaptured $intactRoot
    if ($result.Exit -ne 1) { throw "composer exited $($result.Exit) on a policy drift, expected 1" }
    if (-not (Test-Path -LiteralPath $sentinel -PathType Leaf)) { throw 'the failed build removed the previous dist/dotnet' }
    if ([IO.File]::ReadAllText($manifest) -cne $manifestBefore) { throw 'the failed build changed the previous framework-ownership.json' }
    if (Test-Path -LiteralPath (Join-Path $intactRoot 'dist/dotnet.build-tmp')) { throw 'the failed build left its staging directory behind' }
    $executed++
    Write-Host '[ok] a failed build leaves the previous dist in place'
} catch {
    $failed++
    [Console]::Error.WriteLine("[FAIL] a failed build leaves the previous dist in place -- $($_.Exception.Message)")
} finally {
    if (Test-Path -LiteralPath $intactRoot) { Remove-Item -Recurse -Force -LiteralPath $intactRoot }
}

# A checkout whose path holds [ and ] must build like any other (the path was treated as a wildcard).
$bracketContainer = Join-Path ([IO.Path]::GetTempPath()) ('composer-brackets-' + [guid]::NewGuid())
try {
    $bracketSubject = Join-Path $bracketContainer 'repo-[1]'
    Initialize-ComposerSubject $bracketSubject
    # Start-Process reads -WorkingDirectory as a wildcard, so launch from a plain folder; the composer
    # anchors itself to the folder its script lives in.
    $exit = Invoke-Composer $bracketSubject 'dotnet' ([IO.Path]::GetTempPath())
    if ($exit -ne 0) { throw "composer exited $exit from a folder whose name holds brackets" }
    if (-not (Test-Path -LiteralPath (Join-Path $bracketSubject 'dist/dotnet/framework-ownership.json') -PathType Leaf)) { throw 'no dist/dotnet was composed in the bracketed folder' }
    $executed++
    Write-Host '[ok] composer builds from a folder whose name holds brackets'
} catch {
    $failed++
    [Console]::Error.WriteLine("[FAIL] composer builds from a folder whose name holds brackets -- $($_.Exception.Message)")
} finally {
    if (Test-Path -LiteralPath $bracketContainer) { Remove-Item -Recurse -Force -LiteralPath $bracketContainer }
}

if ($executed -le 0) { [Console]::Error.WriteLine('[FAIL] Composer.Tests executed zero checks'); exit 2 }
if ($global:AtlEmitCaseCount) { Write-Host ("CASE_COUNT {0}" -f $executed) }
if ($failed -eq 0) { Write-Host "Composer.Tests: $executed passed, 0 failed" }
else { [Console]::Error.WriteLine("Composer.Tests: $($executed - $failed) passed, $failed failed") }
exit ([int]($failed -gt 0))
