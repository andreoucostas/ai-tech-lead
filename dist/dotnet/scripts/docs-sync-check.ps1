# AI Tech Lead framework-state guardrail for native Windows PowerShell hosts.
# Exit 0 = pass, 1 = fail. Use from Bamboo/Jenkins on Windows agents, or locally. See README
# "Running on Bitbucket Data Center" for wiring options.
$ErrorActionPreference = 'Stop'

# Anchor to the repo this script lives in (scripts/..), not the caller's cwd — running from
# elsewhere must never silently audit the wrong directory.
Set-Location (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))

# In the framework template repo the consumer-state checks (bootstrap markers, adoption pending)
# don't apply — but the deterministic framework checks DO. Skipping everything here is how
# version-stamp and mirror drift shipped unnoticed; run template-checks instead of going silent.
$here  = Split-Path -Parent $MyInvocation.MyCommand.Path
try { $psExe = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName } catch { $psExe = $null }
if ([string]::IsNullOrWhiteSpace($psExe) -or -not (Test-Path -LiteralPath $psExe -PathType Leaf)) {
    Write-Output 'CANT-VERIFY: docs-sync-check could not resolve the current PowerShell executable; child checks were not run.'
    exit 2
}
if (Test-Path ".template-repo") {
    Write-Output "Framework template repo (.template-repo present) — consumer-state checks don't apply;"
    Write-Output "running the deterministic framework checks (scripts/template-checks.ps1) instead."
    & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'template-checks.ps1')
    $templateStatus = $LASTEXITCODE
    if ($templateStatus -eq 0) { exit 0 }
    exit 1
}

$failed = $false
function Fail($m) { Write-Output "FAIL: $m"; $script:failed = $true }
function OK($m)   { Write-Output "OK:   $m" }

# 0. Install completeness. The enforcement matrix is load-bearing: AGENTS.md points to it for
# the honest host guarantees. ci-integration.md is advisory and may be intentionally removed.
if (-not (Test-Path "docs/enforcement-surfaces.md")) {
    Fail "framework install incomplete: docs/enforcement-surfaces.md missing — reinstall from the template."
} else { OK "framework enforcement matrix present." }
if (-not (Test-Path "docs/ci-integration.md")) {
    Write-Output "NOTE: docs/ci-integration.md is missing — restore it from the template if you need the Windows required-build recipe. (advisory — not a failure)"
}

# 1. Adoption-pending marker — the installer detected pre-existing AI tooling that /adopt must consolidate.
if (Test-Path ".claude/adoption-pending.json") {
    Fail "adoption pending (.claude/adoption-pending.json present) — the installer detected pre-existing AI tooling. A developer must run /adopt (it cannot be model-invoked) to consolidate it; /adopt removes this marker in its Phase 3."
} else { OK "no adoption-pending marker." }

# 1. AGENTS.md (the project instruction file) present, non-empty, bootstrapped. CLAUDE.md's
#    stub shape is checked by template-checks (6b).
if (-not (Test-Path "AGENTS.md") -or ((Get-Item "AGENTS.md").Length -eq 0)) {
    Fail "AGENTS.md is missing or empty."
} elseif (Select-String -Path "AGENTS.md" -Pattern "BOOTSTRAP_PENDING" -Quiet) {
    if (Test-Path ".claude/adoption-pending.json") {
        Fail "AGENTS.md still contains the BOOTSTRAP_PENDING marker — populated by /adopt (adoption pending, see check 0); do not run /bootstrap directly."
    } else {
        Fail "AGENTS.md still contains the BOOTSTRAP_PENDING marker — run /bootstrap."
    }
} else { OK "AGENTS.md present and bootstrapped." }

# 1b. AGENTS.md size budget (advisory — AGENTS.md loads on nearly every agent turn).
if (Test-Path "AGENTS.md") {
    # @().Count includes blank lines; Measure-Object -Line does not.
    $clLines = @(Get-Content "AGENTS.md").Count
    if ($clLines -gt 400) {
        Write-Output "NOTE: AGENTS.md is $clLines lines (soft budget 400). Push verbose Architecture Decisions / Repository Structure detail into on-demand files (docs/, skills) to cut per-turn token cost. (advisory — not a failure)"
    }
}

# 4. TECH_DEBT.md present.
if (Test-Path "TECH_DEBT.md") { OK "TECH_DEBT.md present." } else { Fail "TECH_DEBT.md is missing — run /bootstrap." }

# 4b. FRAMEWORK-CONTEXT.md present and populated.
if (-not (Test-Path "FRAMEWORK-CONTEXT.md")) {
    Fail "FRAMEWORK-CONTEXT.md is missing — copy it from the template."
} elseif (Select-String -Path "FRAMEWORK-CONTEXT.md" -Pattern "DETECTED_FRAMEWORK_PACKAGES_PENDING" -Quiet) {
    Fail "FRAMEWORK-CONTEXT.md still contains DETECTED_FRAMEWORK_PACKAGES_PENDING — run /bootstrap."
} else { OK "FRAMEWORK-CONTEXT.md present and populated." }

# 5. Canonical project-skill location.
if (Test-Path -LiteralPath ".github/skills") {
    Fail ".github/skills exists — migrate its contents to .claude/skills, then remove the GitHub path."
} else {
    OK "canonical project skills use .claude/skills (.github/skills absent)."
}

# 6. README mentions each skill and agent (advisory) -- keep the reference tables current.
if (Test-Path 'README.md') {
    $readme = Get-Content 'README.md' -Raw
    $missingDoc = @()
    Get-ChildItem -Directory '.claude/skills' -ErrorAction SilentlyContinue | ForEach-Object { if ($readme -notmatch [regex]::Escape($_.Name)) { $missingDoc += "skill:$($_.Name)" } }
    Get-ChildItem -File '.claude/agents' -Filter *.md -ErrorAction SilentlyContinue | ForEach-Object { $n = [IO.Path]::GetFileNameWithoutExtension($_.Name); if ($readme -notmatch [regex]::Escape($n)) { $missingDoc += "agent:$n" } }
    if ($missingDoc.Count -gt 0) { Write-Output ("NOTE: README.md does not mention: " + ($missingDoc -join ' ') + " — update the What's-in-the-box / subagents tables (they may have drifted). (advisory — not a failure)") }
}

# 6b. Deterministic framework checks (version-stamp sync, CLAUDE.md -> AGENTS.md instruction layout,
#     PowerShell hook/BOM checks) -- the same gate the template repo's CI runs after install.
# Child process: template-checks.ps1 ends with `exit`, which would terminate this script if dot-run.
$tc = Join-Path $here 'template-checks.ps1'
if (Test-Path $tc) {
    & $psExe -NoProfile -ExecutionPolicy Bypass -File $tc
    if ($LASTEXITCODE -ne 0) { Fail "deterministic framework checks failed (see above)." }
}
$wc = Join-Path $here 'wiki-check.ps1'
if (Test-Path $wc) {
    # Pass the repo root explicitly — wiki-check must never read it from stdin here (an interactive
    # docs-sync-check run would otherwise block waiting for a stdin line).
    & $psExe -NoProfile -ExecutionPolicy Bypass -File $wc (Split-Path -Parent $here)
    if ($LASTEXITCODE -ne 0) { Fail "team wiki checks failed (see above)." }
}
$hc = Join-Path $here 'hazard-check.ps1'
if (Test-Path $hc) {
    & $psExe -NoProfile -ExecutionPolicy Bypass -File $hc (Split-Path -Parent $here)
    if ($LASTEXITCODE -ne 0) { Fail "hazard map checks failed (see above)." }
}
$wmc = Join-Path $here 'warehouse-map-check.ps1'
if (Test-Path $wmc) {
    & $psExe -NoProfile -ExecutionPolicy Bypass -File $wmc (Split-Path -Parent $here)
    $warehouseStatus = $LASTEXITCODE
    if ($warehouseStatus -eq 1) { Write-Output 'NOTE: warehouse map is missing or stale; refresh it before a warehouse write. (advisory - not a failure)' }
    elseif ($warehouseStatus -ne 0) { Write-Output 'NOTE: warehouse map could not be verified; this is not evidence that the map is missing or stale. (advisory - not a failure)' }
}

if ($failed) {
    Write-Output ""
    Write-Output "One or more AI Tech Lead framework checks failed (see above)."
    exit 1
}

Write-Output ""
Write-Output "All AI Tech Lead framework checks passed."
