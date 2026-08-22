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
# unmodified extraction reaches manifest generation with audit protected and without accidentally
# absorbing the following copy-if-absent wiki policy line.
$greenChecks = 0
foreach ($twin in @('ps1','sh')) {
    if ($twin -eq 'sh' -and -not $bash) { Write-Host "[skip] $twin persistent-policy extraction: no bash on this host"; continue }
    $normalRoot = Join-Path ([IO.Path]::GetTempPath()) ('composer-policy-green-' + [guid]::NewGuid())
    try {
        Initialize-ComposerSubject -SubjectRoot $normalRoot -Twin $twin
        if ($twin -eq 'ps1') { $process = Start-Process -FilePath pwsh -ArgumentList @('-NoProfile','-File',(Join-Path $normalRoot 'scripts\build.ps1'),'dotnet') -WorkingDirectory $normalRoot -Wait -PassThru -NoNewWindow }
        else { $process = Start-Process -FilePath $bash -ArgumentList @((Join-Path $normalRoot 'scripts/build.sh'),'dotnet') -WorkingDirectory $normalRoot -Wait -PassThru -NoNewWindow }
        if ($process.ExitCode -ne 0) { throw "unmodified $twin composer exited $($process.ExitCode)" }
        $manifest = Get-Content -Raw -LiteralPath (Join-Path $normalRoot 'dist/dotnet/framework-ownership.json') | ConvertFrom-Json
        $audit = @($manifest.paths | Where-Object path -eq '.claude/ai-audit.log')
        if ($audit.Count -ne 1 -or $audit[0].ownership -cne 'consumer-owned/protected') { throw "unmodified $twin composer did not emit protected audit ownership" }
        $greenChecks++
        Write-Host "[ok] $twin persistent-policy extraction: composer stayed green"
    } catch { $failed++; [Console]::Error.WriteLine("[FAIL] $twin persistent-policy extraction: $($_.Exception.Message)") }
    finally { if (Test-Path -LiteralPath $normalRoot) { Remove-Item -Recurse -Force -LiteralPath $normalRoot } }
}
$total = $cases.Count + $greenChecks
if ($failed -eq 0) { Write-Host "Composer.Tests: $total passed, 0 failed" }
else { [Console]::Error.WriteLine("Composer.Tests: $($total - $failed) passed, $failed failed") }
exit ([int]($failed -gt 0))
