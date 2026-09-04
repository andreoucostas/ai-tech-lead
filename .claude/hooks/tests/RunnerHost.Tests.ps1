# Protect the aggregate runners' host-preservation contract. A direct powershell.exe run must not
# silently move its test files to pwsh 7, because that turns every 5.1-only failure into a false
# green. Both runner copies are exercised from isolated one-file suites so discovery cannot recurse.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')

Reset-Tests

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$runnerSources = @(
    [pscustomobject]@{ Name = 'root meta runner'; Path = Join-Path $PSScriptRoot 'Invoke-HookTests.ps1' }
    [pscustomobject]@{ Name = 'shipped runner'; Path = Join-Path $repoRoot 'src/core/tests/hooks/Invoke-HookTests.ps1' }
)
$isWindowsHost = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
$pathComparison = if ($isWindowsHost) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
$scratchRoot = Join-Path ([IO.Path]::GetTempPath()) ('runner-host-' + [guid]::NewGuid().ToString('N'))

function Test-SameExecutable {
    param([string]$Left, [string]$Right)
    if ([string]::IsNullOrWhiteSpace($Left) -or [string]::IsNullOrWhiteSpace($Right)) { return $false }
    return [string]::Equals([IO.Path]::GetFullPath($Left), [IO.Path]::GetFullPath($Right), $pathComparison)
}

function Resolve-ProcessExecutable {
    param([Parameter(Mandatory)][string]$Launcher)
    $output = @(& $Launcher -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command '[Console]::Out.Write((Get-Process -Id $PID).Path)' 2>&1 |
        ForEach-Object { $_.ToString() })
    if ($LASTEXITCODE -ne 0) { throw "could not resolve PowerShell host '$Launcher': $($output -join '')" }
    return ($output -join '').Trim()
}

function New-RunnerFixture {
    param([Parameter(Mandatory)]$RunnerSource, [Parameter(Mandatory)][string]$Suffix)
    $directory = Join-Path $scratchRoot ($RunnerSource.Name.Replace(' ', '-') + '-' + $Suffix)
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $runner = Join-Path $directory 'Invoke-HookTests.ps1'
    Copy-Item -LiteralPath $RunnerSource.Path -Destination $runner -Force
    $probe = @'
$actual = (Get-Process -Id $PID).Path
Write-Host ("CHILD_HOST {0}" -f $actual)
exit 0
'@
    [IO.File]::WriteAllText((Join-Path $directory 'HostIdentity.Tests.ps1'), $probe, [Text.UTF8Encoding]::new($true))
    return $runner
}

function Invoke-Runner {
    param([Parameter(Mandatory)][string]$Launcher, [Parameter(Mandatory)][string]$Runner)
    $output = @(& $Launcher -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Runner -FixtureDiscovery 2>&1 |
        ForEach-Object { $_.ToString() })
    return [pscustomobject]@{ Exit = [int]$LASTEXITCODE; Output = ($output -join "`n") }
}

$currentHostPath = (Get-Process -Id $PID).Path
$hostCandidates = @([pscustomobject]@{
    Name = 'current host'
    Launcher = $currentHostPath
    Expected = $currentHostPath
})

$windowsPowerShell = $null
$pwshCommand = $null
$resolvedPwsh = $null
if ($isWindowsHost) {
    $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (Test-Path -LiteralPath $windowsPowerShell) {
        $alreadyPresent = @($hostCandidates | Where-Object { Test-SameExecutable $_.Expected $windowsPowerShell }).Count -gt 0
        if (-not $alreadyPresent) {
            $hostCandidates += [pscustomobject]@{ Name = 'Windows PowerShell 5.1'; Launcher = $windowsPowerShell; Expected = $windowsPowerShell }
        }
    }
    $pwshCommand = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pwshCommand) {
        $resolvedPwsh = Resolve-ProcessExecutable -Launcher $pwshCommand.Source
        $alreadyPresent = @($hostCandidates | Where-Object { Test-SameExecutable $_.Expected $resolvedPwsh }).Count -gt 0
        if (-not $alreadyPresent) {
            $hostCandidates += [pscustomobject]@{ Name = 'PowerShell 7'; Launcher = $pwshCommand.Source; Expected = $resolvedPwsh }
        }
    }
}

It 'the runner and host matrices are nonempty' {
    Assert ($runnerSources.Count -eq 2) "expected two runner sources, found $($runnerSources.Count)"
    Assert ($hostCandidates.Count -gt 0) 'no PowerShell host case was constructed'
    if ($isWindowsHost) {
        Assert (Test-Path -LiteralPath $windowsPowerShell) 'Windows PowerShell 5.1 host case is unavailable'
        Assert ($null -ne $pwshCommand) 'PowerShell 7 host case is unavailable'
        Assert ($hostCandidates.Count -eq 2) "expected exactly the PS7 and PS5.1 host cases, found $($hostCandidates.Count)"
    }
}

$hostCaseCount = 0
try {
    foreach ($runnerSource in $runnerSources) {
        foreach ($hostCandidate in $hostCandidates) {
            $runner = New-RunnerFixture -RunnerSource $runnerSource -Suffix ("host-{0}" -f $hostCaseCount)
            It "$($runnerSource.Name) preserves $($hostCandidate.Name) for its child" {
                $result = Invoke-Runner -Launcher $hostCandidate.Launcher -Runner $runner
                Assert ($result.Exit -eq 0) "runner exited $($result.Exit): $($result.Output)"
                $markers = @(($result.Output -split "`r?`n") | Where-Object { $_ -match '^CHILD_HOST .+' })
                Assert ($markers.Count -eq 1) "expected one child-host marker, found $($markers.Count): $($result.Output)"
                $childHost = $markers[0].Substring('CHILD_HOST '.Length).Trim()
                Assert (Test-SameExecutable $childHost $hostCandidate.Expected) "top-level host '$($hostCandidate.Expected)' launched child '$childHost'"
            }
            $hostCaseCount++
        }
    }

    It 'every declared runner/host case executed' {
        $expectedCases = $runnerSources.Count * $hostCandidates.Count
        Assert ($expectedCases -gt 0) 'runner/host matrix unexpectedly has zero cases'
        Assert ($hostCaseCount -eq $expectedCases) "executed $hostCaseCount of $expectedCases declared runner/host cases"
    }

    $mutationCaseCount = 0
    if ($isWindowsHost -and (Test-Path -LiteralPath $windowsPowerShell) -and $pwshCommand) {
        if (-not (Test-SameExecutable $resolvedPwsh $windowsPowerShell)) {
            foreach ($runnerSource in $runnerSources) {
                $runner = New-RunnerFixture -RunnerSource $runnerSource -Suffix ("mutation-{0}" -f $mutationCaseCount)
                $original = [IO.File]::ReadAllText($runner)
                $anchor = '$psExe = $invokingPsExe'
                $replacement = "if (Get-Command pwsh -ErrorAction SilentlyContinue) { `$psExe = 'pwsh' } else { `$psExe = 'powershell' }"
                $mutated = $original.Replace($anchor, $replacement)
                It "$($runnerSource.Name) rejects the old prefer-pwsh substitution" {
                    $anchorCount = [regex]::Matches($original, [regex]::Escape($anchor)).Count
                    Assert ($anchorCount -eq 1) "expected one host-assignment mutation site, found $anchorCount"
                    Assert ($mutated -cne $original) 'host-substitution mutation did not apply'
                    [IO.File]::WriteAllText($runner, $mutated, [Text.UTF8Encoding]::new($true))
                    $result = Invoke-Runner -Launcher $windowsPowerShell -Runner $runner
                    Assert ($result.Exit -ne 0) "mutated runner stayed green: $($result.Output)"
                    Assert ($result.Output -match 'host-preservation probe failed') "mutated runner failed without naming the host-preservation probe: $($result.Output)"
                    Assert ($result.Output -notmatch '(?m)^CHILD_HOST ') "mutated runner reached its test file despite the failed host probe: $($result.Output)"
                }
                $mutationCaseCount++
            }
        }
    }

    if ($mutationCaseCount -eq 0) {
        Skip 'prefer-pwsh mutation goes red under Windows PowerShell 5.1' 'requires distinct powershell.exe and pwsh executables'
    } else {
        It 'the hostile host-substitution matrix is nonempty' {
            Assert ($mutationCaseCount -eq $runnerSources.Count) "executed $mutationCaseCount of $($runnerSources.Count) declared mutation cases"
        }
    }
} finally {
    Remove-Item -LiteralPath $scratchRoot -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Write-TestSummary 'RunnerHost.Tests')
