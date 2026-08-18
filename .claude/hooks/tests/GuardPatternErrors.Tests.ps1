# B-59 executable red-test: prove each guard twin makes the suite fail when a regex becomes inert,
# and prove both runtime policies (secret fail-closed; test-defeat/suppression warn + allow).
. (Join-Path $PSScriptRoot '..\..\..\src\core\tests\hooks\_HookHarness.ps1')
. (Join-Path $PSScriptRoot '_MutationHelper.ps1')

$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\src\core')).Path
$cases = @(
    @{ Name = 'PowerShell secret pattern'; File = '.claude\hooks\guard.ps1'; Find = "Test-GuardPattern '-----BEGIN [A-Z ]*PRIVATE KEY-----' 'secret'"; Replace = "Test-GuardPattern '[' 'secret'"; Policy = 'secret' }
    @{ Name = 'shell secret pattern';      File = '.claude\hooks\guard.sh';  Find = "matches '-----BEGIN [A-Z ]*PRIVATE KEY-----' 'secret'"; Replace = "matches '[' 'secret'"; Policy = 'secret' }
    @{ Name = 'PowerShell suppression pattern'; File = '.claude\hooks\guard.ps1'; Find = "Test-GuardPattern '#pragma\s+warning\s+disable' 'test-defeat/suppression'"; Replace = "Test-GuardPattern '[' 'test-defeat/suppression'"; Policy = 'test-defeat/suppression' }
    @{ Name = 'shell suppression pattern';      File = '.claude\hooks\guard.sh';  Find = "matches '#pragma[[:space:]]+warning[[:space:]]+disable' 'test-defeat/suppression'"; Replace = "matches '[' 'test-defeat/suppression'"; Policy = 'test-defeat/suppression' }
)

$failed = 0
foreach ($case in $cases) {
    try {
        $target = Join-Path $sourceRoot $case.File
        Invoke-MutationRedTest -TargetFile $target -ScratchSourceRoot $sourceRoot -Find $case.Find -Replacement $case.Replace -Command {
            param($scratchTarget, $scratchRoot)
            $suite = Join-Path $scratchRoot 'tests\hooks\Guard.Tests.ps1'
            & pwsh -NoProfile -File $suite
            $suiteExit = $LASTEXITCODE
            if ($suiteExit -eq 0) { throw 'mutated Guard.Tests suite stayed green' }

            $event = New-ClaudeEvent 'src/Foo.cs' 'public class Foo { }'
            $probe = Invoke-Hook $scratchTarget $event
            if ($case.Policy -eq 'secret') {
                Assert ($probe.Exit -eq 2) "$($case.Name): invalid secret regex did not fail closed"
            } else {
                Assert ($probe.Exit -eq 0) "$($case.Name): invalid suppression regex did not allow"
            }
            Assert ("$($probe.Err)" -match [regex]::Escape($case.Policy)) "$($case.Name): stderr omitted category '$($case.Policy)'"
            Assert ("$($probe.Err)" -match "pattern '\['") "$($case.Name): stderr omitted the invalid pattern"
            $global:LASTEXITCODE = $suiteExit
        } | Out-Null
        Write-Host "[ok] $($case.Name): suite went red and $($case.Policy) policy was observed"
    } catch {
        $failed++
        [Console]::Error.WriteLine("[FAIL] $($case.Name): $($_.Exception.Message)")
    }
}

if ($failed -eq 0) { Write-Host "GuardPatternErrors.Tests: $($cases.Count) passed, 0 failed" }
else { [Console]::Error.WriteLine("GuardPatternErrors.Tests: $($cases.Count - $failed) passed, $failed failed") }
exit ([int]($failed -gt 0))
