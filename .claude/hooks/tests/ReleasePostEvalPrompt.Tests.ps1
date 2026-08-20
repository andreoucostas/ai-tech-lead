# Regression tests for release.ps1's post-success optional-eval prompt (B-150). Does NOT ship.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$release = Join-Path $repoRoot '.claude/scripts/release.ps1'
$text = [IO.File]::ReadAllText($release)

Reset-Tests

It 'the optional-eval prompt requires an attended output stream and supports -NoEvals' {
    Assert ($text -match '(?m)^\s*\[switch\]\$NoEvals(?:,)?\s*$') 'release.ps1 has no explicit -NoEvals switch'
    Assert ($text -match 'if \(-not \$NoEvals -and \[Environment\]::UserInteractive -and -not \[Console\]::IsInputRedirected -and -not \[Console\]::IsOutputRedirected\)') 'eval prompt guard does not require -NoEvals plus attended input and output'
    Assert ($text -match 'Read-Host "Release succeeded\. Run optional B-41 live agent evals now\? \[y/N\]"') 'interactive optional-eval prompt was removed'
    Assert ($text -match '} elseif \(\$NoEvals\) \{ Write-Host "Agent evals skipped\. Run later: \$agentEvalCommand" \}') '-NoEvals does not record the explicit skip'
}

It 'a detached prompt harness with stdout redirected exits and records the skipped evals' {
    $condition = [regex]::Match($text, '(?m)^if \(([^\r\n]+)\) \{\r?\n\s*\$runAgentEvals = Read-Host "Release succeeded\. Run optional B-41 live agent evals now\? \[y/N\]"').Groups[1].Value
    Assert (-not [string]::IsNullOrWhiteSpace($condition)) 'could not extract the real eval-prompt condition'

    $harness = Join-Path ([IO.Path]::GetTempPath()) ("eval-prompt-" + [guid]::NewGuid().ToString('N') + '.ps1')
    $stdout = "$harness.stdout"
    $stderr = "$harness.stderr"
    $body = @"
param([switch]`$NoEvals)
`$agentEvalCommand = 'pwsh -NoProfile -File .claude/evals/run-agent-evals.ps1 -Live'
if ($condition) {
    `$null = Read-Host 'PROMPT REACHED'
    Write-Host 'Agent evals skipped. Run later'
} else { Write-Host "Agent eval reminder (non-interactive; not run): `$agentEvalCommand" }
"@
    [IO.File]::WriteAllText($harness, $body, [Text.UTF8Encoding]::new($true))
    try {
        $p = Start-Process -FilePath (Get-PsExe) -ArgumentList @('-NoProfile', '-File', $harness) -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
        $exited = $p.WaitForExit(3000)
        if (-not $exited) { $p.Kill(); $p.WaitForExit() }
        Assert $exited 'detached harness parked at Read-Host with stdout redirected and stdin left alone'
        $out = if (Test-Path $stdout) { [IO.File]::ReadAllText($stdout) } else { '' }
        Assert ($out -match 'Agent eval reminder \(non-interactive; not run\)') "skip reminder missing: '$out'"
    } finally {
        Remove-Item -LiteralPath $harness, $stdout, $stderr -Force -ErrorAction SilentlyContinue
    }
}

exit (Write-TestSummary 'ReleasePostEvalPrompt.Tests (B-150 post-success prompt)')
