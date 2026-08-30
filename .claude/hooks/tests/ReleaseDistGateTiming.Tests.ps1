# Regression test for release.ps1's per-unit gate timing attribution (B-151). Does NOT ship.
# B-170 also prevents the release runner from quietly reintroducing even one local shipped hook
# suite after the measured representative sequential attempt was rejected. It proves structure from
# the real release source, then mutates that source in scratch and re-runs itself so the assertion
# has a reachable red world.
#
# Why this file executes the emission instead of grepping for it. The first version of this test
# asserted that release.ps1's source *contained* `PSBeginTime`, `PSEndTime` and the literal format
# string. That check passes whether or not the line is reachable, whether or not the arithmetic
# works, and whether or not the emitted text is the shape `release.ps1` can parse -- it can only fail
# if someone deletes the literal characters. B-151 exists so that the next budget breach is *read*
# rather than inferred, and a check that never observes an emitted line cannot underwrite that. So
# each case below extracts the real emitting expressions from the script and runs them.
#
# It deliberately does not run the release stage. It proves the emitted shape and the bounded gate
# topology, while the controlled scratch mutation proves the new topology check can actually fail.
[CmdletBinding()]
param([switch]$SkipRedTest)

. (Join-Path $PSScriptRoot '_HookHarness.ps1')
. (Join-Path $PSScriptRoot '_MutationHelper.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$release = Join-Path $repoRoot '.claude/scripts/release.ps1'
$text = [IO.File]::ReadAllText($release)
$ci = [IO.File]::ReadAllText((Join-Path $repoRoot '.github/workflows/ci.yml'))
$metaRunner = [IO.File]::ReadAllText((Join-Path $repoRoot '.claude/hooks/tests/Invoke-HookTests.ps1'))

Reset-Tests

# `release.ps1:~549` parses per-file results with '(?m)^RESULT\s+(\S+)\s+(\d+)\s*$', anchored at BOTH
# ends. That anchoring is why TIMING must be its own line: a third field on RESULT matches nothing,
# $fileResults comes back empty, and -AllowFailingGate then refuses a waiver that is actually valid.
$resultPattern = '(?m)^RESULT\s+(\S+)\s+(\d+)\s*$'
$timingPattern = '^TIMING \S+ \d+\.\d$'

$start = $text.IndexOf("Measure-Stage 'dist-gates'")
$end = $text.IndexOf("Measure-Stage 'meta-suite'", $start)
$stage = if ($start -ge 0 -and $end -gt $start) { $text.Substring($start, $end - $start) } else { '' }
$metaEnd = $text.IndexOf("Measure-Stage 'eval-selftest'", $end)
$metaStage = if ($end -ge 0 -and $metaEnd -gt $end) { $text.Substring($end, $metaEnd - $end) } else { '' }

function Get-CiJob([string]$Name) {
    $job = [regex]::Match($ci, "(?ms)^  $([regex]::Escape($Name)):\r?\n.*?(?=^  [A-Za-z0-9_-]+:|\z)")
    Assert ($job.Success) "CI job '$Name' is missing"
    return $job.Value
}

function Assert-CiHookMatrix([string]$Name) {
    $job = Get-CiJob $Name
    Assert ($job -match '(?ms)matrix:\s*\r?\n\s*dist:\s*\[dotnet, angular, monorepo\]') "CI job '$Name' no longer declares the complete dotnet/angular/monorepo matrix"
    Assert ($job -match 'dist/\$\{\{ matrix\.dist \}\}/tests/hooks/Invoke-HookTests\.ps1') "CI job '$Name' no longer invokes the selected shipped hook suite"
}

function Assert-CiRootMetaSuite([string]$Name) {
    $job = Get-CiJob $Name
    Assert ($job -match '(?m)^\s*run:\s*pwsh -NoProfile -File \.claude/hooks/tests/Invoke-HookTests\.ps1\s*$') "CI job '$Name' no longer invokes the root meta suite"
}

function Assert-CiMacosPortability {
    $job = Get-CiJob 'macos-portability'
    Assert ($job -match '(?m)^\s*runs-on:\s*macos-26\s*$') 'macos-portability no longer pins the current GA macOS provider'
    Assert ($job -match '(?m)^\s*shell:\s*/bin/bash\b.*\{0\}\s*$') 'macos-portability no longer invokes run steps through stock /bin/bash'
    Assert ($job -match 'BASH_VERSION' -and $job -match '3\.2\.57') 'macos-portability no longer asserts the claimed Bash 3.2.57 runtime'
    Assert ($job -match '/bin/bash dist/dotnet/scripts/install\.sh') 'macos-portability no longer executes the committed dotnet installer directly'
    Assert ($job -match 'dist/dotnet/\.claude/framework-version\.json') 'macos-portability no longer verifies the installed version stamp'
    Assert ($job -match 'dist/dotnet/framework-ownership\.json') 'macos-portability no longer verifies the installed ownership manifest'
    Assert ($job -notmatch '(?m)^\s*matrix:') 'macos-portability expanded into a matrix'
    Assert ($job -notmatch 'Invoke-HookTests\.ps1|\bpwsh\b|scripts/(?:build|validate-dist)\.(?:ps1|sh)') 'macos-portability expanded into generic composition, validation, or test work'
}

It 'the dist-gates stage was located for inspection' {
    Assert ($stage -ne '') 'could not extract the dist-gates stage from release.ps1'
}

It 'local dist-gates validate all three dists but invoke zero shipped hook suites' {
    Assert ($text -match '(?m)^\$dists\s*=\s*@\(''dotnet'', ''angular'', ''monorepo''\)') 'release.ps1 no longer declares the three required dist names'
    Assert ($stage -match 'foreach\s*\(\$d\s+in\s+\$dists\)') 'dist-gates no longer iterates every declared dist'
    $validators = @([regex]::Matches($stage, 'validate-dist\.ps1'))
    Assert ($validators.Count -eq 1) "expected one validator invocation inside the all-dist loop, found $($validators.Count)"
    Assert ($stage -match 'validate-dist\.ps1''\) \$dist') 'the validator no longer receives the loop dist'

    $hookInvocations = @([regex]::Matches($stage, 'Invoke-HookTests\.ps1'))
    Assert ($hookInvocations.Count -eq 0) "expected zero local shipped hook-suite invocations, found $($hookInvocations.Count)"
    $allShippedHookInvocations = @([regex]::Matches($text, 'dist/[^\s''""\)]+/tests/hooks/Invoke-HookTests\.ps1'))
    Assert ($allShippedHookInvocations.Count -eq 0) "release.ps1 contains $($allShippedHookInvocations.Count) shipped hook-suite invocation(s) outside dist-gates"
    Assert ($stage -notmatch 'TIMING \{0\}/hook-suite ') 'dist-gates still attributes a retired local hook-suite run'
}

It 'the full root meta suite remains on its existing default throttled runner with RESULT and waiver parsing' {
    Assert ($metaStage -ne '') 'could not extract the meta-suite stage from release.ps1'
    Assert ($metaStage -match 'Invoke-HookTests\.ps1''\) \*> \$metaLog') 'the root meta suite no longer receives its default invocation'
    Assert ($metaStage -notmatch "Invoke-HookTests\.ps1'\) -Sequential") 'release.ps1 forces the root meta suite into sequential mode'
    Assert ($metaRunner -match '\$outerLanes\s*=') 'the root meta runner no longer contains its measured throttled default branch'
    Assert ($metaStage -match 'Resolve-GateWaiverOutcome') 'the default meta invocation bypassed waiver parsing'
    Assert ($metaStage.Contains('(?m)^RESULT\s+(\S+)\s+(\d+)\s*$')) 'the default meta invocation no longer parses per-file RESULT lines'
}

It 'CI retains Windows/Linux coverage plus one bounded stock-macOS provider before a normal tag' {
    Assert-CiHookMatrix 'windows-hooks'
    Assert-CiHookMatrix 'linux-hooks'
    Assert-CiRootMetaSuite 'windows'
    Assert-CiRootMetaSuite 'linux'
    Assert-CiMacosPortability
}

It 'every TIMING expression in dist-gates emits a line the RESULT parser cannot swallow' {
    $emitters = @([regex]::Matches($stage, '(?m)^\s*Write-Host \("(TIMING [^"]+)" -f ([^\r\n]+)\)\s*$'))
    Assert ($emitters.Count -ge 3) "expected at least 3 TIMING emitters (dist job, validator, and context-footprint), found $($emitters.Count)"

    # Stand-ins for the values the real expressions read, chosen so a formatting bug is visible:
    # a fractional value that must round to one decimal place.
    $d = 'monorepo'
    $result = [pscustomobject]@{ ValidateSeconds = 234.94 }
    $jobSeconds = 557.81
    $footprintSeconds = 12.25

    foreach ($emitter in $emitters) {
        $format = $emitter.Groups[1].Value
        $argExpr = $emitter.Groups[2].Value
        $line = & ([scriptblock]::Create("`"$format`" -f $argExpr"))
        Assert ($line -match $timingPattern) "emitted line is not a parseable TIMING line: '$line'"
        Assert (-not ($line -match $resultPattern)) "emitted TIMING line is also matched by the RESULT parser: '$line'"
    }
}

It 'a TIMING value appended to a RESULT line would be swallowed -- the reason for the separate line' {
    # The failure mode this design avoids, demonstrated rather than asserted in prose: a third field
    # on RESULT does not degrade to "ignored", it stops matching at all.
    Assert (("RESULT ValidateDist.Tests.ps1 0" -match $resultPattern)) 'the two-field RESULT line should parse'
    Assert (-not ("RESULT ValidateDist.Tests.ps1 0 234.9" -match $resultPattern)) 'a three-field RESULT line must NOT parse -- if it does, this entire design is unnecessary'
}

It 'each distinct local dist-gate unit is attributed' {
    foreach ($unit in @('TIMING {0} ', 'TIMING {0}/validate-dist ', 'TIMING context-footprint ')) {
        Assert ($stage.Contains($unit)) "no TIMING emitter for unit '$unit' -- a breach in it could only be inferred"
    }
}

It 'the job wall-clock emitter survives a job whose times were never set' {
    # Receive-Job on a job that never ran leaves PSBeginTime/PSEndTime null; a bare subtraction there
    # throws inside the release's own gate stage, after the gates have passed.
    $job = [pscustomobject]@{ PSBeginTime = $null; PSEndTime = $null }
    $seconds = if ($job.PSEndTime -and $job.PSBeginTime) { ($job.PSEndTime - $job.PSBeginTime).TotalSeconds } else { 0 }
    Assert ($seconds -eq 0) "null job times should yield 0, got '$seconds'"
    Assert ((("TIMING {0} {1:N1}" -f 'dotnet', $seconds)) -match $timingPattern) 'the null-time fallback does not format as a TIMING line'
}

if (-not $SkipRedTest) {
    It 'one local shipped hook suite makes this suite fail and restores release.ps1 byte-identically' {
        Invoke-MutationRedTest -TargetFile $release -ScratchSourceRoot $repoRoot `
            -Find "    Gate (`$footprintExit -eq 0) 'update context-footprint baseline'" `
            -Replacement "    & pwsh -NoProfile -File (Join-Path `$repo 'dist/monorepo/tests/hooks/Invoke-HookTests.ps1') *> `$footprintLog; Gate (`$footprintExit -eq 0) 'update context-footprint baseline'" -Command {
                param($scratchTarget, $scratchRoot)
                $test = Join-Path $scratchRoot '.claude/hooks/tests/ReleaseDistGateTiming.Tests.ps1'
                $process = Start-Process -FilePath (Get-PsExe) -ArgumentList @('-NoProfile','-File',$test,'-SkipRedTest') -Wait -PassThru -NoNewWindow
                $global:LASTEXITCODE = $process.ExitCode
            } | Out-Null
    }
}

exit (Write-TestSummary 'ReleaseDistGateTiming.Tests (B-151/B-170 local gate attribution)')
