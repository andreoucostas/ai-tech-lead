# Composer executable red-tests and explicit ownership-policy pins.
. (Join-Path $PSScriptRoot '_MutationHelper.ps1')

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$psExe = (Get-Process -Id $PID).Path
$fixtureRoot = (Resolve-Path (Join-Path $PSScriptRoot 'fixtures')).Path

$expectedProtected = @(
    'CLAUDE.md', 'AGENTS.md', 'TECH_DEBT.md', 'SECURITY_FINDINGS.md', 'LEARNINGS.md',
    'FRAMEWORK-CONTEXT.md', '.github/copilot-instructions.md', 'docs/ARCHITECTURE.md',
    'docs/architecture-decisions.md', 'docs/wiki/INDEX.md', 'LICENSES/ai-tech-lead-MIT.txt'
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
    param([string]$SubjectRoot, [string]$Mode = 'dotnet')
    $process = Start-Process -FilePath $psExe -ArgumentList @('-NoProfile','-File',(Join-Path $SubjectRoot 'scripts\build.ps1'),$Mode) `
        -WorkingDirectory $SubjectRoot -Wait -PassThru -NoNewWindow
    return [int]$process.ExitCode
}

$failed = 0
$executed = 0
$cases = @(
    @{ Name = 'PowerShell malformed marker'; Kind = 'marker' },
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
            $replacement = '<!-- @stack:fixture -- >'
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
        $exit = Invoke-Composer $subject
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

if ($executed -le 0) { [Console]::Error.WriteLine('[FAIL] Composer.Tests executed zero checks'); exit 2 }
if ($global:AtlEmitCaseCount) { Write-Host ("CASE_COUNT {0}" -f $executed) }
if ($failed -eq 0) { Write-Host "Composer.Tests: $executed passed, 0 failed" }
else { [Console]::Error.WriteLine("Composer.Tests: $($executed - $failed) passed, $failed failed") }
exit ([int]($failed -gt 0))
