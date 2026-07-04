# AI Tech Lead deterministic framework checks — PowerShell twin of template-checks.sh.
# Exit 0 = pass, otherwise the failure count. Runs in BOTH contexts:
#   - the template repo itself (wired into .github/workflows/template-ci.yml) — this is the gate
#     that keeps the framework honest about its own invariants;
#   - a consumer repo (invoked by docs-sync-check) — the same invariants hold after install.
# Checks: version-stamp sync (CLAUDE.md header == framework-version.json == CHANGELOG head),
# CLAUDE.md ↔ AGENTS.md verbatim mirror (rule sections + Agentic Workflow §1),
# copilot-instructions.md present and <= 80 lines, UTF-8 BOM on framework .ps1 files,
# .ps1/.sh hook twin existence, and PS syntax of framework scripts.
# 5.1-safe: no pwsh-only syntax.
$ErrorActionPreference = 'Stop'

# Anchor to the repo this script lives in (scripts/..), not the caller's cwd — running from
# elsewhere must never silently audit the wrong directory.
Set-Location (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))

$failed = 0
function Fail($m) { Write-Output "FAIL: $m"; $script:failed++ }
function OK($m)   { Write-Output "OK:   $m" }

# --- 1. Version-stamp sync -------------------------------------------------------------------
$vClaude = $null; $vJson = $null; $vLog = $null
if (Test-Path 'CLAUDE.md') {
    $head = Get-Content 'CLAUDE.md' -TotalCount 10
    foreach ($l in $head) { if ($l -match '^\s*version:\s*(\S+)') { $vClaude = $Matches[1]; break } }
}
if (Test-Path '.claude/framework-version.json') {
    try { $vJson = (Get-Content '.claude/framework-version.json' -Raw | ConvertFrom-Json).version } catch {}
}
if (Test-Path 'CHANGELOG.md') {
    foreach ($l in (Get-Content 'CHANGELOG.md')) { if ($l -match '^## (\d+\.\d+\.\d+)') { $vLog = $Matches[1]; break } }
}
if (-not $vClaude) { Fail 'CLAUDE.md has no version stamp in its header comment.' }
elseif (-not $vJson) { Fail '.claude/framework-version.json missing or unparsable.' }
elseif ($vClaude -ne $vJson) { Fail "version-stamp drift: CLAUDE.md says $vClaude, framework-version.json says $vJson." }
elseif ($vLog -and $vLog -ne $vJson) { Fail "version-stamp drift: CHANGELOG.md head entry is $vLog, framework-version.json says $vJson." }
else { OK "version stamps in sync ($vClaude)$(if (-not $vLog) { ' (no CHANGELOG.md — consumer repo, pair-check only)' })." }

# --- 2. CLAUDE.md <-> AGENTS.md verbatim mirror ------------------------------------------------
function Get-Section {
    param([string[]]$Lines, [string]$Heading)
    $out = New-Object System.Collections.Generic.List[string]
    $in = $false
    foreach ($l in $Lines) {
        if ($l -eq $Heading) { $in = $true; continue }
        if ($in -and $l -match '^## ') { break }
        if ($in) {
            $t = $l.TrimEnd()
            if ($t -ne '' -and $t -ne '---') { $out.Add($t) }
        }
    }
    return ($out -join "`n")
}
function Get-Section1 {
    param([string[]]$Lines)
    $out = New-Object System.Collections.Generic.List[string]
    $in = $false
    foreach ($l in $Lines) {
        if ($l -match '^### 1\. Classify the intent') { $in = $true; continue }
        if ($in -and $l -match '^### ') { break }
        if ($in) { $t = $l.TrimEnd(); if ($t -ne '') { $out.Add($t) } }
    }
    return ($out -join "`n")
}
if ((Test-Path 'CLAUDE.md') -and (Test-Path 'AGENTS.md')) {
    $cl = Get-Content 'CLAUDE.md'
    $ag = Get-Content 'AGENTS.md'
    foreach ($sec in @('## Verification Rules','## Leanness','## SOLID','## Boy Scout Rule')) {
        $a = Get-Section $cl $sec
        $b = Get-Section $ag $sec
        if (-not $a) { Fail "CLAUDE.md is missing section '$sec'." }
        elseif ($a -ne $b) { Fail "AGENTS.md section '$sec' is not a verbatim mirror of CLAUDE.md — run /generate-copilot." }
        else { OK "'$sec' mirrored verbatim." }
    }
    $s1c = Get-Section1 $cl
    $s1a = Get-Section1 $ag
    if (-not $s1c) { Fail 'CLAUDE.md has no "### 1. Classify the intent" block.' }
    elseif ($s1c -ne $s1a) { Fail 'AGENTS.md Agentic Workflow §1 is not verbatim (this is the only routing surface Copilot has) — run /generate-copilot.' }
    else { OK 'Agentic Workflow §1 mirrored verbatim.' }
} else {
    Fail 'CLAUDE.md or AGENTS.md missing — cannot check mirror parity.'
}

# --- 3. copilot-instructions.md present and slim ----------------------------------------------
if (-not (Test-Path '.github/copilot-instructions.md')) {
    Fail '.github/copilot-instructions.md is missing — run /generate-copilot.'
} else {
    # @().Count matches wc -l in the .sh twin; Measure-Object -Line skips blank lines and diverges.
    $n = @(Get-Content '.github/copilot-instructions.md').Count
    if ($n -gt 80) { Fail ".github/copilot-instructions.md is $n lines (limit 80) — regenerate slimmer." }
    else { OK ".github/copilot-instructions.md present ($n lines <= 80)." }
}

# --- 4. Framework .ps1 files carry a UTF-8 BOM (Windows PowerShell 5.1 requirement) -----------
$scanDirs = @('.claude/hooks','scripts','tests/hooks') | Where-Object { Test-Path $_ }
$noBom = @()
foreach ($d in $scanDirs) {
    foreach ($f in (Get-ChildItem -Recurse -Filter *.ps1 -Path $d)) {
        $b = [System.IO.File]::ReadAllBytes($f.FullName)
        if (-not ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)) { $noBom += $f.FullName }
    }
}
if ($noBom.Count -gt 0) { Fail ("BOM missing on: " + ($noBom -join ', ')) } else { OK 'all framework .ps1 files carry a UTF-8 BOM.' }

# --- 5. Hook twin existence (.ps1 <-> .sh) -----------------------------------------------------
if (Test-Path '.claude/hooks') {
    $orphans = @()
    foreach ($f in (Get-ChildItem '.claude/hooks' -Filter *.ps1)) {
        if (-not (Test-Path ($f.FullName -replace '\.ps1$','.sh'))) { $orphans += $f.Name }
    }
    foreach ($f in (Get-ChildItem '.claude/hooks' -Filter *.sh)) {
        if (-not (Test-Path ($f.FullName -replace '\.sh$','.ps1'))) { $orphans += $f.Name }
    }
    if ($orphans.Count -gt 0) { Fail ("hook twin missing for: " + ($orphans -join ', ')) } else { OK 'every hook has its .ps1/.sh twin.' }
}

# --- 6. PS syntax of framework scripts ---------------------------------------------------------
$parseFails = @()
foreach ($d in $scanDirs) {
    foreach ($f in (Get-ChildItem -Recurse -Filter *.ps1 -Path $d)) {
        $e = $null
        [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$e) | Out-Null
        if ($e) { $parseFails += "$($f.FullName): $($e[0].Message)" }
    }
}
if ($parseFails.Count -gt 0) { Fail ("PS syntax errors: " + ($parseFails -join '; ')) } else { OK 'all framework .ps1 files parse cleanly.' }

# --- 7. Skills mirror: .claude/skills must match .github/skills (EOL-normalized) --------------
# Skills ship twice per repo (Claude reads .claude/skills, Copilot reads .github/skills). They are
# mirrored by /generate-copilot + scripts/sync-agent-files; without a gate, editing one and
# forgetting the other ships stale guidance to Copilot with every other check green (B-07).
# Compare CRLF-normalized (matches the .sh twin's `diff --strip-trailing-cr`): with core.autocrlf
# on Windows the two copies can differ only in line endings in a working tree yet be identical in a
# clean checkout -- an EOL-only diff must not fail the gate. Use ABSOLUTE paths: [IO.File]::ReadAllText
# resolves a relative path against the .NET process CWD, which Set-Location does NOT update -- a
# relative path silently breaks when this script is invoked from another directory (e.g. release.ps1).
function Get-SkillText($p) { ([System.IO.File]::ReadAllText($p)) -replace "`r`n", "`n" }
$claudeSkills = if (Test-Path '.claude/skills') { (Resolve-Path '.claude/skills').Path } else { $null }
$githubSkills = if (Test-Path '.github/skills') { (Resolve-Path '.github/skills').Path } else { $null }
if ($claudeSkills -or $githubSkills) {
    $mism = @()
    if ($claudeSkills) {
        foreach ($f in (Get-ChildItem $claudeSkills -Recurse -File)) {
            $rel = $f.FullName.Substring($claudeSkills.Length).TrimStart('\', '/')
            $gh  = if ($githubSkills) { Join-Path $githubSkills $rel } else { $null }
            if (-not $gh -or -not (Test-Path $gh)) { $mism += ".github/skills/$rel missing" }
            elseif ((Get-SkillText $f.FullName) -ne (Get-SkillText $gh)) { $mism += "$rel differs" }
        }
    }
    if ($githubSkills) {
        foreach ($f in (Get-ChildItem $githubSkills -Recurse -File)) {
            $rel = $f.FullName.Substring($githubSkills.Length).TrimStart('\', '/')
            if (-not $claudeSkills -or -not (Test-Path (Join-Path $claudeSkills $rel))) { $mism += ".claude/skills/$rel missing (extra under .github/skills)" }
        }
    }
    if ($mism.Count -gt 0) { Fail ("skills mirror drift (.claude/skills vs .github/skills -- run /generate-copilot): " + ($mism -join '; ')) }
    else { OK ".claude/skills and .github/skills are in sync." }
}

Write-Output ''
if ($failed -gt 0) { Write-Output "$failed framework check(s) FAILED."; exit $failed }
Write-Output 'All deterministic framework checks passed.'
exit 0
