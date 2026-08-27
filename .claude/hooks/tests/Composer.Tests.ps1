# B-149 executable red-tests: prove both composer twins reject the bad inputs they claim to reject.
. (Join-Path $PSScriptRoot '_MutationHelper.ps1')

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$fixtureRoot = (Resolve-Path (Join-Path $PSScriptRoot 'fixtures')).Path
$bashCommand = Get-Command bash -ErrorAction SilentlyContinue
$bash = if ($bashCommand) { $bashCommand.Source } else { $null }
$cases = @(
    @{ Name = 'PowerShell malformed marker'; Twin = 'ps1'; Kind = 'marker' }
    @{ Name = 'shell malformed marker'; Twin = 'sh'; Kind = 'marker' }
    @{ Name = 'PowerShell unapproved overlay collision'; Twin = 'ps1'; Kind = 'collision' }
    @{ Name = 'shell unapproved overlay collision'; Twin = 'sh'; Kind = 'collision' }
    @{ Name = 'PowerShell persistent-policy twin mismatch'; Twin = 'ps1'; Kind = 'persistent' }
    @{ Name = 'shell persistent-policy twin mismatch'; Twin = 'sh'; Kind = 'persistent' }
)

function Initialize-ComposerSubject {
    param([string]$SubjectRoot, [string]$Twin)
    New-Item -ItemType Directory -Path (Join-Path $SubjectRoot 'scripts') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $SubjectRoot 'src/core/scripts') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $SubjectRoot 'src/core/.claude') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $SubjectRoot 'src/core/docs') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $SubjectRoot 'meta') -Force | Out-Null
    foreach ($stack in @('dotnet','angular','monorepo')) {
        New-Item -ItemType Directory -Path (Join-Path $SubjectRoot "src/stacks/$stack/files") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $SubjectRoot "src/stacks/$stack/snippets") -Force | Out-Null
    }
    Copy-Item -LiteralPath (Join-Path $repoRoot "scripts/build.$Twin") -Destination (Join-Path $SubjectRoot 'scripts') -Force
    # The composer now reads installer policy. Supplying both real twins makes the marker/collision
    # fixtures reach their intended checks instead of going red merely because policy is absent.
    Copy-Item -LiteralPath (Join-Path $repoRoot 'src/core/scripts/install.ps1') -Destination (Join-Path $SubjectRoot 'src/core/scripts') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'src/core/scripts/install.sh') -Destination (Join-Path $SubjectRoot 'src/core/scripts') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'src/core/.claude/ai-audit.log') -Destination (Join-Path $SubjectRoot 'src/core/.claude') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'src/core/docs/architecture-decisions.md') -Destination (Join-Path $SubjectRoot 'src/core/docs') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'src/core/framework-retirements.json') -Destination (Join-Path $SubjectRoot 'src/core') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'meta/framework-retirements-baseline.json') -Destination (Join-Path $SubjectRoot 'meta') -Force
}

$failed = 0
foreach ($case in $cases) {
    if ($case.Twin -eq 'sh' -and -not $bash) { Write-Host "[skip] $($case.Name): no bash on this host"; continue }
    try {
        $policyInput = $null
        if ($case.Kind -eq 'persistent') {
            $policyInput = Join-Path ([IO.Path]::GetTempPath()) ('composer-policy-' + [guid]::NewGuid())
            Initialize-ComposerSubject -SubjectRoot $policyInput -Twin $case.Twin
            $target = Join-Path $policyInput 'src/core/scripts/install.sh'
            $scratchSourceRoot = $policyInput
            $find = 'persistent_copy_if_absent=".claude/ai-audit.log"'; $replacement = 'persistent_copy_if_absent=".claude/not-the-audit.log"'
        } elseif ($case.Kind -eq 'marker') {
            $target = Join-Path $fixtureRoot 'composer-input.txt'; $find = '<!-- @stack:fixture -->'; $replacement = '<!-- @stack:fixture -- >'
            $scratchSourceRoot = $fixtureRoot
        } else {
            $target = Join-Path $fixtureRoot 'composer-input.txt'; $find = '<!-- @stack:fixture -->'; $replacement = 'collision mutation'
            $scratchSourceRoot = $fixtureRoot
        }
        Invoke-MutationRedTest -TargetFile $target -ScratchSourceRoot $scratchSourceRoot -Find $find -Replacement $replacement -ExpectedExit 1 -Command {
            param($scratchTarget, $scratchRoot)
            $subjectRoot = if ($case.Kind -eq 'persistent') { $scratchRoot } else { Join-Path $scratchRoot 'composer-subject' }
            if ($case.Kind -ne 'persistent') {
                Initialize-ComposerSubject -SubjectRoot $subjectRoot -Twin $case.Twin
                if ($case.Kind -eq 'collision') {
                    Copy-Item -LiteralPath $scratchTarget -Destination (Join-Path $subjectRoot 'src/stacks/dotnet/files/collision.txt') -Force
                    Copy-Item -LiteralPath $scratchTarget -Destination (Join-Path $subjectRoot 'src/stacks/angular/files/collision.txt') -Force
                } else {
                    Copy-Item -LiteralPath $scratchTarget -Destination (Join-Path $subjectRoot 'src/core/marker.txt') -Force
                }
            }
            $mode = if ($case.Kind -eq 'marker') { 'dotnet' } else { 'monorepo' }
            if ($case.Twin -eq 'ps1') { $process = Start-Process -FilePath pwsh -ArgumentList @('-NoProfile','-File',(Join-Path $subjectRoot 'scripts\build.ps1'),$mode) -WorkingDirectory $subjectRoot -Wait -PassThru -NoNewWindow }
            else { $process = Start-Process -FilePath $bash -ArgumentList @((Join-Path $subjectRoot 'scripts/build.sh'),$mode) -WorkingDirectory $subjectRoot -Wait -PassThru -NoNewWindow }
            $global:LASTEXITCODE = $process.ExitCode
        } | Out-Null
        Write-Host "[ok] $($case.Name): composer went red"
    } catch { $failed++; [Console]::Error.WriteLine("[FAIL] $($case.Name): $($_.Exception.Message)") }
    finally { if ($policyInput -and (Test-Path -LiteralPath $policyInput)) { Remove-Item -Recurse -Force -LiteralPath $policyInput } }
}

# The mutation cases prove a mismatch goes red. This companion green check proves the normal,
# unmodified extraction reaches manifest generation with persistent audit state and the append-only
# ADR log protected, without accidentally absorbing unrelated framework scaffolds.
$greenChecks = 0
foreach ($twin in @('ps1','sh')) {
    if ($twin -eq 'sh' -and -not $bash) { Write-Host "[skip] $twin ownership-policy extraction: no bash on this host"; continue }
    $normalRoot = Join-Path ([IO.Path]::GetTempPath()) ('composer-policy-green-' + [guid]::NewGuid())
    try {
        Initialize-ComposerSubject -SubjectRoot $normalRoot -Twin $twin
        if ($twin -eq 'ps1') { $process = Start-Process -FilePath pwsh -ArgumentList @('-NoProfile','-File',(Join-Path $normalRoot 'scripts\build.ps1'),'dotnet') -WorkingDirectory $normalRoot -Wait -PassThru -NoNewWindow }
        else { $process = Start-Process -FilePath $bash -ArgumentList @((Join-Path $normalRoot 'scripts/build.sh'),'dotnet') -WorkingDirectory $normalRoot -Wait -PassThru -NoNewWindow }
        if ($process.ExitCode -ne 0) { throw "unmodified $twin composer exited $($process.ExitCode)" }
        $manifest = Get-Content -Raw -LiteralPath (Join-Path $normalRoot 'dist/dotnet/framework-ownership.json') | ConvertFrom-Json
        $audit = @($manifest.paths | Where-Object path -eq '.claude/ai-audit.log')
        if ($audit.Count -ne 1 -or $audit[0].ownership -cne 'consumer-owned/protected') { throw "unmodified $twin composer did not emit protected audit ownership" }
        $adr = @($manifest.paths | Where-Object path -eq 'docs/architecture-decisions.md')
        if ($adr.Count -ne 1 -or $adr[0].ownership -cne 'consumer-owned/protected') { throw "unmodified $twin composer did not emit protected append-only ADR ownership" }
        $greenChecks++
        Write-Host "[ok] $twin ownership-policy extraction: composer stayed green"
    } catch { $failed++; [Console]::Error.WriteLine("[FAIL] $twin ownership-policy extraction: $($_.Exception.Message)") }
    finally { if (Test-Path -LiteralPath $normalRoot) { Remove-Item -Recurse -Force -LiteralPath $normalRoot } }
}

# Retirement metadata authorizes deletion in consumers, so its three composer boundaries are worth
# direct behavioral coverage. Keep these in this existing composer suite rather than creating a
# second gate with another full subject setup.
$retirementChecks = 0
foreach ($twin in @('ps1','sh')) {
    if ($twin -eq 'sh' -and -not $bash) { Write-Host "[skip] $twin retirement composer checks: no bash on this host"; continue }
    foreach ($kind in @('unsafe-path','still-shipped','disappeared','synchronized-disappearance')) {
        $container = Join-Path ([IO.Path]::GetTempPath()) ('composer-retirement-' + [guid]::NewGuid())
        $subject = if ($kind -eq 'synchronized-disappearance') { Join-Path $container 'nested-subject' } else { $container }
        try {
            Initialize-ComposerSubject -SubjectRoot $subject -Twin $twin
            $ledgerPath = Join-Path $subject 'src/core/framework-retirements.json'
            $maintainerLedgerPath = Join-Path $subject 'meta/framework-retirements-baseline.json'
            if ($kind -eq 'unsafe-path') {
                $text = [IO.File]::ReadAllText($ledgerPath).Replace('scripts/impact-run.ps1', '../outside')
                [IO.File]::WriteAllText($ledgerPath, $text, [Text.UTF8Encoding]::new($false))
            } elseif ($kind -eq 'still-shipped') {
                [IO.File]::WriteAllText((Join-Path $subject 'src/core/scripts/impact-run.ps1'), 'retired path must not ship', [Text.UTF8Encoding]::new($false))
            }
            $invoke = {
                if ($twin -eq 'ps1') { $process = Start-Process -FilePath pwsh -ArgumentList @('-NoProfile','-File',(Join-Path $subject 'scripts/build.ps1'),'dotnet') -WorkingDirectory $subject -Wait -PassThru -NoNewWindow }
                else { $process = Start-Process -FilePath $bash -ArgumentList @((Join-Path $subject 'scripts/build.sh'),'dotnet') -WorkingDirectory $subject -Wait -PassThru -NoNewWindow }
                return [pscustomobject]@{ Exit = [int]$process.ExitCode; Output = '' }
            }
            if ($kind -in @('disappeared','synchronized-disappearance')) {
                if ($kind -eq 'synchronized-disappearance') {
                    # An archive may be unpacked beneath an unrelated worktree. A malformed ledger
                    # in that parent must not contaminate this composer's authority chain.
                    New-Item -ItemType Directory -Path (Join-Path $container 'src/core') -Force | Out-Null
                    [IO.File]::WriteAllText((Join-Path $container 'src/core/framework-retirements.json'), "{}`n", [Text.UTF8Encoding]::new($false))
                    & git -C $container init --quiet
                    & git -C $container config user.email 'composer-parent@example.invalid'
                    & git -C $container config user.name 'Unrelated Parent'
                    & git -C $container add src/core/framework-retirements.json
                    & git -C $container commit --quiet -m 'unrelated parent ledger'
                    if ($LASTEXITCODE -ne 0) { throw 'could not establish unrelated parent worktree fixture' }
                }
                $first = & $invoke
                if ($first.Exit -ne 0) { throw "initial cumulative-ledger build exited $($first.Exit): $($first.Output)" }
                if ($kind -eq 'synchronized-disappearance') {
                    & git -C $subject init --quiet
                    & git -C $subject config user.email 'composer-test@example.invalid'
                    & git -C $subject config user.name 'Composer Test'
                    & git -C $subject add --all
                    & git -C $subject commit --quiet -m 'retirement baseline'
                    & git -C $subject tag v0.76.0
                    if ($LASTEXITCODE -ne 0) { throw 'could not establish independent committed retirement baseline' }
                }
                $remaining = @(Get-Content -LiteralPath $ledgerPath | Where-Object { $_ -notmatch '"path": "scripts/impact-run\.ps1"' })
                [IO.File]::WriteAllText($ledgerPath, (($remaining -join "`n") + "`n"), [Text.UTF8Encoding]::new($false))
                $distLedger = Join-Path $subject 'dist/dotnet/framework-retirements.json'
                [IO.File]::WriteAllText($distLedger, (($remaining -join "`n") + "`n"), [Text.UTF8Encoding]::new($false))
                if ($kind -eq 'synchronized-disappearance') { [IO.File]::WriteAllText($maintainerLedgerPath, (($remaining -join "`n") + "`n"), [Text.UTF8Encoding]::new($false)) }
            }
            $result = & $invoke
            if ($result.Exit -eq 0) { throw "$kind retirement mutation stayed green. Output: $($result.Output)" }
            $retirementChecks++
            Write-Host "[ok] $twin retirement ${kind}: composer went red"
        } catch { $failed++; [Console]::Error.WriteLine("[FAIL] $twin retirement ${kind}: $($_.Exception.Message)") }
        finally { if (Test-Path -LiteralPath $container) { Remove-Item -Recurse -Force -LiteralPath $container } }
    }
}

$total = $cases.Count + $greenChecks + $retirementChecks
if ($failed -eq 0) { Write-Host "Composer.Tests: $total passed, 0 failed" }
else { [Console]::Error.WriteLine("Composer.Tests: $($total - $failed) passed, $failed failed") }
exit ([int]($failed -gt 0))
