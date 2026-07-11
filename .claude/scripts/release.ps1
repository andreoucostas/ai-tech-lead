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
# (The migration-era fidelity gate was retired at v0.26.0 with a final 138/138 pass — WSD-018.)
#
# PowerShell-only by decision (see docs/workspace-decisions.md): meta scripts run only on the
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
Write-Host "Stamped src -> $Version ($today)."

# ---- 3. Rebuild all three dists (the stamp must flow src -> dist in this same commit) ----
foreach ($d in $dists) {
    & pwsh -NoProfile -File (Join-Path $repo 'scripts/build.ps1') $d
    Gate ($LASTEXITCODE -eq 0) "compose dist/$d"
}
if ($fatal) { Write-Host "`nRelease REFUSED: the composer failed. Nothing was committed."; exit 1 }

# ---- 4. Deterministic gates: validate-dist + hook suite per dist, then the meta suite ----
foreach ($d in $dists) {
    & pwsh -NoProfile -File (Join-Path $repo 'scripts/validate-dist.ps1') $d
    Gate ($LASTEXITCODE -eq 0) "validate-dist $d"
    & pwsh -NoProfile -File (Join-Path $repo "dist/$d/tests/hooks/Invoke-HookTests.ps1")
    Gate ($LASTEXITCODE -eq 0) "dist/$d hook test suite"
}
& pwsh -NoProfile -File (Join-Path $repo '.claude/hooks/tests/Invoke-HookTests.ps1')
Gate ($LASTEXITCODE -eq 0) 'meta-hook test suite'

if ($fatal) { Write-Host "`nRelease REFUSED: fix the failing gate(s) and re-run. Nothing was committed."; exit 1 }

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
Write-Host "`nRelease $Version complete$(if ($NoPush) { ' (not pushed: -NoPush)' })."
exit 0
