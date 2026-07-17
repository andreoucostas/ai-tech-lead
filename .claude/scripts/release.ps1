# Meta release automation (maintainer-only, does NOT ship) — single-repo edition (WSD-012 D7,
# retargeted at B-25-EXEC Phase 5 from the dual-repo original, whose manual predecessor shipped
# stamp drift twice). Stamps, rebuilds, gates, commits, and pushes THIS repo, refusing to finish
# if any deterministic gate fails.
#
# Usage:  pwsh -NoProfile -File .claude/scripts/release.ps1 -Version 0.26.0 -Summary "one-line topic" [-NoPush]
# Precondition: the ROOT CHANGELOG.md already carries a "## <Version>" head entry (writing the
# entry is authoring work, not automation; a trailing "Unreleased" on that line is stamped with
# today's date) and the working tree contains exactly the release changes.
#
# Gates (in order): compose all three dists -> validate-dist ×3 -> hook suites ×3 -> meta suite.
# fidelity-check is deliberately NOT run here: it is the migration-era gate pinned to the
# freeze-v0.25.5 tags, and the first release that changes shipped content must consciously
# retire/re-baseline it (and the CI fidelity legs) in the same change — see WSD-016.
#
# PowerShell-only by decision (see meta/workspace-decisions.md): meta scripts run only on the
# maintainer's box; invariant #3 twin parity applies to shipped hooks/scripts and scripts/.
param(
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$Summary,
    [switch]$NoPush
)
$ErrorActionPreference = 'Stop'

$repo  = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$dists = @('dotnet', 'angular', 'monorepo')
$today = Get-Date -Format 'yyyy-MM-dd'
$fatal = $false
function Gate($ok, $what) { if ($ok) { Write-Host "GATE ok:   $what" } else { Write-Host "GATE FAIL: $what"; $script:fatal = $true } }

# ---- 1. Root CHANGELOG head entry must already exist ----
$clPath = Join-Path $repo 'CHANGELOG.md'
$head = $null; $headLine = $null
foreach ($l in (Get-Content $clPath)) { if ($l -match '^## (\d+\.\d+\.\d+)') { $head = $Matches[1]; $headLine = $l; break } }
Gate ($head -eq $Version) "root CHANGELOG head entry is ## $Version (found: $head)"
if ($fatal) { Write-Host "`nWrite the CHANGELOG entry first, then re-run."; exit 1 }

if ($headLine -match 'Unreleased') {
    $txt = [System.IO.File]::ReadAllText($clPath)
    $txt = $txt.Replace($headLine, ($headLine -replace 'Unreleased', $today))
    [System.IO.File]::WriteAllText($clPath, $txt)
    Write-Host "Stamped CHANGELOG head entry Unreleased -> $today."
}

# ---- 2. Stamp src: core CLAUDE.md header + the three framework-version.json overlays ----
$cl  = Join-Path $repo 'src/core/CLAUDE.md'
$txt = [System.IO.File]::ReadAllText($cl)
$txt = [regex]::Replace($txt, '(?m)^(\s*version:\s*)\S+', "`${1}$Version", 1)
$txt = [regex]::Replace($txt, '(?m)^(\s*applied:\s*)\S+', "`${1}$today", 1)
[System.IO.File]::WriteAllText($cl, $txt)
foreach ($d in $dists) {
    $fv = Join-Path $repo "src/stacks/$d/files/.claude/framework-version.json"
    $jt = [System.IO.File]::ReadAllText($fv)
    $jt = [regex]::Replace($jt, '"version"\s*:\s*"[^"]*"', "`"version`": `"$Version`"")
    $jt = [regex]::Replace($jt, '"applied"\s*:\s*"[^"]*"', "`"applied`": `"$today`"")
    [System.IO.File]::WriteAllText($fv, $jt)
}
# The root README states the shipped version in prose. It was hand-maintained, so it drifted (it
# claimed v0.26.1 against a shipped v0.26.2). DocTruth.Tests now fails the release on that drift --
# which would make every release trip a gate the maintainer then hand-fixes. Stamp it here instead:
# the only durable fix for a stamp that drifts is to stop maintaining it by hand.
$rm = Join-Path $repo 'README.md'
$rt = [System.IO.File]::ReadAllText($rm)
$versionLinePattern = '(Current shipped version is \*\*v)([0-9]+\.[0-9]+\.[0-9]+)(\*\*)'
$versionLine = [regex]::Match($rt, $versionLinePattern)
if (-not $versionLine.Success) {
    [Console]::Error.WriteLine("FATAL: README.md has no 'Current shipped version is **vX.Y.Z**' line to stamp -- it was reworded, so the stamp (and DocTruth's check of it) is now blind. Restore the line or update both.")
    exit 2
}
if ($versionLine.Groups[2].Value -eq $Version) {
    Write-Host "README already stamped $Version (retry after a refused release)."
} else {
    $stamped = [regex]::Replace($rt, $versionLinePattern, "`${1}$Version`${3}", 1)
    [System.IO.File]::WriteAllText($rm, $stamped)
    Write-Host "Stamped src + root README -> $Version ($today)."
}

# ---- 3. Rebuild all three dists (the stamp must flow src -> dist in this same commit) ----
foreach ($d in $dists) {
    & pwsh -NoProfile -File (Join-Path $repo 'scripts/build.ps1') $d
    Gate ($LASTEXITCODE -eq 0) "compose dist/$d"
}
if ($fatal) {
    Write-Host "`nRelease REFUSED: the composer failed. Nothing was committed."
    Write-Host 'Fix the failing gate, then re-run the same release command as-is.'
    exit 1
}

# Re-measure after version stamps have flowed into dist; the baseline lands in the release commit.
& pwsh -NoProfile -File (Join-Path $repo 'scripts/context-footprint.ps1') -Update
Gate ($LASTEXITCODE -eq 0) 'update context-footprint baseline'
if ($fatal) {
    Write-Host "`nRelease REFUSED: context-footprint measurement failed. Nothing was committed."
    Write-Host 'Fix the failing gate, then re-run the same release command as-is.'
    exit 1
}

# ---- 4. Deterministic gates: validate-dist + hook suite per dist, then the meta suite ----
try {
    $distGateJobs = foreach ($d in $dists) {
        $log = [System.IO.Path]::GetTempFileName()
        $job = Start-Job -ArgumentList $repo, $d, $log -ScriptBlock {
            param($repo, $dist, $log)
            & pwsh -NoProfile -File (Join-Path $repo 'scripts/validate-dist.ps1') $dist *> $log
            $validateExit = $LASTEXITCODE
            & pwsh -NoProfile -File (Join-Path $repo "dist/$dist/tests/hooks/Invoke-HookTests.ps1") *>> $log
            [pscustomobject]@{
                ValidateExit = $validateExit
                HookExit     = $LASTEXITCODE
            }
        }
        [pscustomobject]@{ Dist = $d; Log = $log; Job = $job }
    }
    $distGateJobs.Job | Wait-Job | Out-Null
    foreach ($distGateJob in $distGateJobs) {
        $result = Receive-Job $distGateJob.Job
        Write-Host -NoNewline ([System.IO.File]::ReadAllText($distGateJob.Log))
        $d = $distGateJob.Dist
        Gate ($result.ValidateExit -eq 0) "validate-dist $d"
        Gate ($result.HookExit -eq 0) "dist/$d hook test suite"
    }
} finally {
    if ($distGateJobs) {
        $distGateJobs.Job | Remove-Job -Force
        $distGateJobs.Log | Remove-Item -Force
    }
}
& pwsh -NoProfile -File (Join-Path $repo '.claude/hooks/tests/Invoke-HookTests.ps1')
Gate ($LASTEXITCODE -eq 0) 'meta-hook test suite'
& pwsh -NoProfile -File (Join-Path $repo '.claude/evals/run-agent-evals.ps1') -SelfTest
Gate ($LASTEXITCODE -eq 0) 'agent-eval harness self-test (no network)'

if ($fatal) {
    Write-Host "`nRelease REFUSED: fix the failing gate(s) and re-run. Nothing was committed."
    Write-Host 'Once fixed, re-run the same release command as-is.'
    exit 1
}

# ---- 5. Commit + push ----
git -C $repo add -A
$staged = git -C $repo diff --cached --name-only
if (-not $staged) { Write-Host 'Nothing to commit (already released?).'; exit 0 }
git -C $repo commit -m "v${Version}: $Summary" -m "Released via .claude/scripts/release.ps1 — all deterministic gates green (compose ×3, validate-dist ×3, hook suites ×3, meta suite)."
if ($LASTEXITCODE -ne 0) { Write-Host 'Commit FAILED.'; exit 1 }
if (-not $NoPush) {
    git -C $repo push origin master
    if ($LASTEXITCODE -ne 0) { Write-Host 'Push FAILED.'; exit 1 }
}

# B-41 behavioral evals are stochastic and consume model budget, so they run only after the
# deterministic release succeeded and are never a release gate. At this point the runner sees the
# just-committed distribution, not the previous release or a dirty pre-gate build.
$agentEvalCommand = 'pwsh -NoProfile -File .claude/evals/run-agent-evals.ps1 -Live'
if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
    $runAgentEvals = Read-Host "Release succeeded. Run optional B-41 live agent evals now? [y/N]"
    if ($runAgentEvals -match '^(?i)y(?:es)?$') {
        & pwsh -NoProfile -File (Join-Path $repo '.claude/evals/run-agent-evals.ps1') -Live
        Write-Host "Agent eval exit: $LASTEXITCODE (recorded, never changes release status)."
        $evalResultsPath = 'meta/eval-results.md'
        if (git -C $repo status --porcelain -- $evalResultsPath) {
            git -C $repo add $evalResultsPath
            git -C $repo commit -m "meta: record v${Version} agent eval results"
            if ($LASTEXITCODE -ne 0) { Write-Host 'Eval-results commit FAILED; release is shipped but evidence is not persisted.'; exit 1 }
            if (-not $NoPush) {
                git -C $repo push origin master
                if ($LASTEXITCODE -ne 0) { Write-Host 'Eval-results push FAILED; release is shipped but evidence is only local.'; exit 1 }
            }
            $persisted = if ($NoPush) { 'locally (-NoPush)' } else { 'and pushed' }
            Write-Host "Agent eval evidence committed $persisted."
        }
    } else { Write-Host "Agent evals skipped. Run later: $agentEvalCommand" }
} else { Write-Host "Agent eval reminder (non-interactive; not run): $agentEvalCommand" }
Write-Host "`nRelease $Version complete$(if ($NoPush) { ' (not pushed: -NoPush)' })."
exit 0
