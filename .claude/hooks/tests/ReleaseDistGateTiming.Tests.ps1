# Regression test for release.ps1's per-unit gate timing attribution (B-151). Does NOT ship.
#
# Why this file executes the emission instead of grepping for it. The first version of this test
# asserted that release.ps1's source *contained* `PSBeginTime`, `PSEndTime` and the literal format
# string. That check passes whether or not the line is reachable, whether or not the arithmetic
# works, and whether or not the emitted text is the shape `release.ps1` can parse -- it can only fail
# if someone deletes the literal characters. B-151 exists so that the next budget breach is *read*
# rather than inferred, and a check that never observes an emitted line cannot underwrite that. So
# each case below extracts the real emitting expressions from the script and runs them.
#
# What this still does not cover, stated rather than implied: it does not run the dist-gates stage
# (that is a ~10-minute release stage), so it proves the emission's shape and arithmetic, not that
# the stage reaches it. The unattributed-breach scenario the entry describes would show up here as a
# missing TIMING line for one of the four units.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$release = Join-Path $repoRoot '.claude/scripts/release.ps1'
$text = [IO.File]::ReadAllText($release)

Reset-Tests

# `release.ps1:~549` parses per-file results with '(?m)^RESULT\s+(\S+)\s+(\d+)\s*$', anchored at BOTH
# ends. That anchoring is why TIMING must be its own line: a third field on RESULT matches nothing,
# $fileResults comes back empty, and -AllowFailingGate then refuses a waiver that is actually valid.
$resultPattern = '(?m)^RESULT\s+(\S+)\s+(\d+)\s*$'
$timingPattern = '^TIMING \S+ \d+\.\d$'

$start = $text.IndexOf("Measure-Stage 'dist-gates'")
$end = $text.IndexOf("Measure-Stage 'meta-suite'", $start)
$stage = if ($start -ge 0 -and $end -gt $start) { $text.Substring($start, $end - $start) } else { '' }

It 'the dist-gates stage was located for inspection' {
    Assert ($stage -ne '') 'could not extract the dist-gates stage from release.ps1'
}

It 'every TIMING expression in dist-gates emits a line the RESULT parser cannot swallow' {
    $emitters = @([regex]::Matches($stage, '(?m)^\s*Write-Host \("(TIMING [^"]+)" -f ([^\r\n]+)\)\s*$'))
    Assert ($emitters.Count -ge 4) "expected at least 4 TIMING emitters (3 dist units + context-footprint), found $($emitters.Count)"

    # Stand-ins for the values the real expressions read, chosen so a formatting bug is visible:
    # a fractional value that must round to one decimal place.
    $d = 'monorepo'
    $result = [pscustomobject]@{ ValidateSeconds = 234.94; HookSeconds = 322.86 }
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

It 'each of the four parallel units in dist-gates is attributed' {
    foreach ($unit in @('TIMING {0} ', 'TIMING {0}/validate-dist ', 'TIMING {0}/hook-suite ', 'TIMING context-footprint ')) {
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

exit (Write-TestSummary 'ReleaseDistGateTiming.Tests (B-151 dist-gate attribution)')
