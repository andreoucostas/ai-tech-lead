# B-149 executable red-test: prove both docs-sync-check twins reject a planted skills-mirror drift.
. (Join-Path $PSScriptRoot '_MutationHelper.ps1')

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$bashCommand = Get-Command bash -ErrorAction SilentlyContinue
$bash = if ($bashCommand) { $bashCommand.Source } else { $null }
$cases = @(@{ Name = 'PowerShell docs sync'; Twin = 'ps1' }, @{ Name = 'shell docs sync'; Twin = 'sh' })
$failed = 0
foreach ($case in $cases) {
    if ($case.Twin -eq 'sh' -and -not $bash) { Write-Host "[skip] $($case.Name): no bash on this host"; continue }
    try {
        $target = Join-Path $repoRoot 'dist\dotnet\.claude\skills\add-tests\SKILL.md'
        Invoke-MutationRedTest -TargetFile $target -ScratchSourceRoot $repoRoot -Find 'name: add-tests' -Replacement 'name: add-tests-planted-drift' -ExpectedExit 1 -Command {
            param($scratchTarget, $scratchRoot)
            $script = Join-Path $scratchRoot "dist/dotnet/scripts/docs-sync-check.$($case.Twin)"
            if ($case.Twin -eq 'ps1') { $process = Start-Process -FilePath pwsh -ArgumentList @('-NoProfile','-File',$script) -Wait -PassThru -NoNewWindow }
            else { $process = Start-Process -FilePath $bash -ArgumentList @('-e',$script) -Wait -PassThru -NoNewWindow }
            $global:LASTEXITCODE = $process.ExitCode
        } | Out-Null
        Write-Host "[ok] $($case.Name): planted drift went red"
    } catch { $failed++; [Console]::Error.WriteLine("[FAIL] $($case.Name): $($_.Exception.Message)") }
}
if ($failed -eq 0) { Write-Host "DocsSyncCheck.Tests: $($cases.Count) passed, 0 failed" }
else { [Console]::Error.WriteLine("DocsSyncCheck.Tests: $($cases.Count - $failed) passed, $failed failed") }
exit ([int]($failed -gt 0))
