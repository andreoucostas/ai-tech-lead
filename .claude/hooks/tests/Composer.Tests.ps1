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
)

$failed = 0
foreach ($case in $cases) {
    if ($case.Twin -eq 'sh' -and -not $bash) { Write-Host "[skip] $($case.Name): no bash on this host"; continue }
    try {
        if ($case.Kind -eq 'marker') {
            $target = Join-Path $fixtureRoot 'composer-input.txt'; $find = '<!-- @stack:fixture -->'; $replacement = '<!-- @stack:fixture -- >'
        } else {
            $target = Join-Path $fixtureRoot 'composer-input.txt'; $find = '<!-- @stack:fixture -->'; $replacement = 'collision mutation'
        }
        Invoke-MutationRedTest -TargetFile $target -ScratchSourceRoot $fixtureRoot -Find $find -Replacement $replacement -ExpectedExit 1 -Command {
            param($scratchTarget, $scratchRoot)
            $subjectRoot = Join-Path $scratchRoot 'composer-subject'
            New-Item -ItemType Directory -Path (Join-Path $subjectRoot 'scripts') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $subjectRoot 'src/core') -Force | Out-Null
            foreach ($stack in @('dotnet','angular','monorepo')) {
                New-Item -ItemType Directory -Path (Join-Path $subjectRoot "src/stacks/$stack/files") -Force | Out-Null
                New-Item -ItemType Directory -Path (Join-Path $subjectRoot "src/stacks/$stack/snippets") -Force | Out-Null
            }
            Copy-Item -LiteralPath (Join-Path $repoRoot "scripts/build.$($case.Twin)") -Destination (Join-Path $subjectRoot 'scripts') -Force
            if ($case.Kind -eq 'collision') {
                Copy-Item -LiteralPath $scratchTarget -Destination (Join-Path $subjectRoot 'src/stacks/dotnet/files/collision.txt') -Force
                Copy-Item -LiteralPath $scratchTarget -Destination (Join-Path $subjectRoot 'src/stacks/angular/files/collision.txt') -Force
            } else {
                Copy-Item -LiteralPath $scratchTarget -Destination (Join-Path $subjectRoot 'src/core/marker.txt') -Force
            }
            $mode = if ($case.Kind -eq 'marker') { 'dotnet' } else { 'monorepo' }
            if ($case.Twin -eq 'ps1') { $process = Start-Process -FilePath pwsh -ArgumentList @('-NoProfile','-File',(Join-Path $subjectRoot 'scripts\build.ps1'),$mode) -WorkingDirectory $subjectRoot -Wait -PassThru -NoNewWindow }
            else { $process = Start-Process -FilePath $bash -ArgumentList @((Join-Path $subjectRoot 'scripts/build.sh'),$mode) -WorkingDirectory $subjectRoot -Wait -PassThru -NoNewWindow }
            $global:LASTEXITCODE = $process.ExitCode
        } | Out-Null
        Write-Host "[ok] $($case.Name): composer went red"
    } catch { $failed++; [Console]::Error.WriteLine("[FAIL] $($case.Name): $($_.Exception.Message)") }
}
if ($failed -eq 0) { Write-Host "Composer.Tests: $($cases.Count) passed, 0 failed" }
else { [Console]::Error.WriteLine("Composer.Tests: $($cases.Count - $failed) passed, $failed failed") }
exit ([int]($failed -gt 0))
