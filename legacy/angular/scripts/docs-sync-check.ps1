# AI Tech Lead framework-state guardrail — host-agnostic (PowerShell twin of docs-sync-check.sh).
# Exit 0 = pass, 1 = fail. Use from Bamboo/Jenkins on Windows agents, or locally. See README
# "Running on Bitbucket Data Center" for wiring options.
$ErrorActionPreference = 'Stop'

$root = (git rev-parse --show-toplevel 2>$null)
if (-not $root) { $root = (Get-Location).Path }
Set-Location $root

if (Test-Path ".template-repo") {
    Write-Output "Framework template repo (.template-repo present) — skipping framework-state checks."
    exit 0
}

$failed = $false
function Fail($m) { Write-Output "FAIL: $m"; $script:failed = $true }
function OK($m)   { Write-Output "OK:   $m" }

# 1. CLAUDE.md present, non-empty, bootstrapped.
if (-not (Test-Path "CLAUDE.md") -or ((Get-Item "CLAUDE.md").Length -eq 0)) {
    Fail "CLAUDE.md is missing or empty."
} elseif (Select-String -Path "CLAUDE.md" -Pattern "BOOTSTRAP_PENDING" -Quiet) {
    Fail "CLAUDE.md still contains the BOOTSTRAP_PENDING marker — run /bootstrap."
} else { OK "CLAUDE.md present and bootstrapped." }

# 1b. CLAUDE.md size budget (advisory — CLAUDE.md loads on nearly every agent turn).
if (Test-Path "CLAUDE.md") {
    $clLines = (Get-Content "CLAUDE.md" | Measure-Object -Line).Lines
    if ($clLines -gt 400) {
        Write-Output "NOTE: CLAUDE.md is $clLines lines (soft budget 400). Push verbose detail into on-demand files (docs/, skills) to cut per-turn token cost. (advisory -- not a failure)"
    }
}

# 2. AGENTS.md present AND is the generated mirror.
if (-not (Test-Path "AGENTS.md")) {
    Fail "AGENTS.md is missing — run /generate-copilot."
} else {
    $missing = @()
    if (-not (Select-String -Path "AGENTS.md" -Pattern "GENERATED FILE" -Quiet)) { $missing += "banner" }
    foreach ($h in @("## Verification Rules","## Leanness","## Boy Scout Rule","## Agentic Workflow")) {
        if (-not (Select-String -Path "AGENTS.md" -SimpleMatch -Pattern $h -Quiet)) { $missing += $h }
    }
    if ($missing.Count -gt 0) { Fail ("AGENTS.md is not a current generated mirror (missing: " + ($missing -join ', ') + ") — run /generate-copilot.") }
    else { OK "AGENTS.md is a generated mirror of CLAUDE.md's portable rules." }
}

# 3. copilot-instructions.md present and <= 80 lines.
if (-not (Test-Path ".github/copilot-instructions.md")) {
    Fail ".github/copilot-instructions.md is missing — run /generate-copilot."
} else {
    $n = (Get-Content ".github/copilot-instructions.md" | Measure-Object -Line).Lines
    if ($n -gt 80) { Fail ".github/copilot-instructions.md is $n lines (limit: 80) — regenerate slimmer with /generate-copilot." }
    else { OK ".github/copilot-instructions.md present ($n lines <= 80)." }
}

# 4. TECH_DEBT.md present.
if (Test-Path "TECH_DEBT.md") { OK "TECH_DEBT.md present." } else { Fail "TECH_DEBT.md is missing — run /bootstrap." }

# 4b. FRAMEWORK-CONTEXT.md present and populated.
if (-not (Test-Path "FRAMEWORK-CONTEXT.md")) {
    Fail "FRAMEWORK-CONTEXT.md is missing — copy it from the template."
} elseif (Select-String -Path "FRAMEWORK-CONTEXT.md" -Pattern "DETECTED_FRAMEWORK_PACKAGES_PENDING" -Quiet) {
    Fail "FRAMEWORK-CONTEXT.md still contains DETECTED_FRAMEWORK_PACKAGES_PENDING — run /bootstrap."
} else { OK "FRAMEWORK-CONTEXT.md present and populated." }

# 5. Skills mirror parity.
if (Test-Path ".claude/skills") {
    if (-not (Test-Path ".github/skills")) {
        Fail ".github/skills is missing — run scripts/sync-agent-files.ps1."
    } else {
        $hash = {
            param($dir)
            Get-ChildItem -Recurse -File $dir | Sort-Object FullName | ForEach-Object {
                $rel = $_.FullName.Substring((Resolve-Path $dir).Path.Length)
                $rel + ':' + (Get-FileHash $_.FullName -Algorithm SHA1).Hash
            }
        }
        $a = & $hash ".claude/skills"
        $b = & $hash ".github/skills"
        if (Compare-Object $a $b) {
            Fail ".github/skills is out of sync with .claude/skills — run scripts/sync-agent-files.ps1."
        } else { OK ".github/skills mirrors .claude/skills." }
    }
}

if ($failed) {
    Write-Output ""
    Write-Output "One or more AI Tech Lead framework checks failed (see above)."
    exit 1
}

Write-Output ""
Write-Output "All AI Tech Lead framework checks passed."
