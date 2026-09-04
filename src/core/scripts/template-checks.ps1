# AI Tech Lead deterministic framework checks.
# Exit 0 = verified clean, 3 = verified finding(s), 2 = required input could not be inspected.
# Any other nonzero is an abnormal/incomplete run. Runs in BOTH contexts:
#   - the template repo itself (wired into .github/workflows/template-ci.yml) — this is the gate
#     that keeps the framework honest about its own invariants;
#   - a consumer repo (invoked by docs-sync-check) — the same invariants hold after install.
# Checks: version-stamp sync (CLAUDE.md header == framework-version.json == CHANGELOG head),
# CLAUDE.md ↔ AGENTS.md verbatim mirror (rule sections + Agentic Workflow §1),
# copilot-instructions.md present and <= 80 lines, UTF-8 BOM on framework .ps1 files,
# required PowerShell hook set, PS syntax of framework scripts, skills-directory policy, and
# Common Tasks skill inventory parity.
# 5.1-safe: no pwsh-only syntax.
$ErrorActionPreference = 'Stop'

# Anchor to the repo this script lives in (scripts/..), not the caller's cwd — running from
# elsewhere must never silently audit the wrong directory.
Set-Location (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))

$failed = 0
function Fail($m) { Write-Output "FAIL: $m"; $script:failed++ }
function OK($m)   { Write-Output "OK:   $m" }

# --- 1. Version-stamp sync -------------------------------------------------------------------
$vClaude = $null; $vJson = $null; $vLog = $null; $vLogLine = $null; $changelogHeads = @()
$isTemplateRepo = Test-Path -LiteralPath '.template-repo' -PathType Leaf
if (Test-Path 'CLAUDE.md') {
    $head = Get-Content 'CLAUDE.md' -TotalCount 10
    foreach ($l in $head) { if ($l -match '^\s*version:\s*(\S+)') { $vClaude = $Matches[1]; break } }
}
if (Test-Path '.claude/framework-version.json') {
    try { $vJson = (Get-Content '.claude/framework-version.json' -Raw | ConvertFrom-Json).version } catch {}
}
if ($isTemplateRepo -and (Test-Path -LiteralPath 'CHANGELOG.md' -PathType Leaf)) {
    # Get-Content has no explicit -Encoding here, so on Windows PowerShell 5.1 a BOM-less file (this
    # one deliberately has none) decodes against the system codepage, not UTF-8 -- mangling a
    # non-ASCII em dash in the head line. Read the bytes directly via an absolute path: Set-Location
    # above updates the PowerShell provider location but not the .NET process CWD, so a relative
    # [IO.File] path would resolve against the wrong directory.
    try { $clText = [IO.File]::ReadAllText((Resolve-Path -LiteralPath 'CHANGELOG.md').Path) }
    catch {
        Write-Output 'CANT-VERIFY: template-checks could not inspect CHANGELOG.md; changelog headings remain UNKNOWN. Fix the host/resource read problem and rerun.'
        exit 2
    }
    foreach ($l in ($clText -split "`r?`n")) {
        if (-not $vLogLine -and $l -cmatch '^## ') { $vLogLine = $l }
        if ($l -cmatch '^## ([0-9]+\.[0-9]+\.[0-9]+) — (Unreleased|[0-9]{4}-[0-9]{2}-[0-9]{2})$') {
            $changelogHeads += [pscustomobject]@{ Version = $Matches[1]; Suffix = $Matches[2]; Line = $l }
        }
    }
    # A normal pre-stamp tree has the next Unreleased head first and the stamped version dated
    # below it. Select the stamped version's dated entry from the whole file, not merely the first H2.
    $stampedHead = @($changelogHeads | Where-Object { $_.Version -eq $vJson -and $_.Suffix -match '^\d{4}-\d{2}-\d{2}$' }) | Select-Object -First 1
    if ($stampedHead) { $vLog = $stampedHead.Version }
    elseif ($vLogLine -cmatch '^## ([0-9]+\.[0-9]+\.[0-9]+) — ([0-9]{4}-[0-9]{2}-[0-9]{2})$') { $vLog = $Matches[1] }
}
if (-not $vClaude) { Fail 'CLAUDE.md has no version stamp in its header comment.' }
elseif (-not $vJson) { Fail '.claude/framework-version.json missing or unparsable.' }
elseif ($vClaude -ne $vJson) { Fail "version-stamp drift: CLAUDE.md says $vClaude, framework-version.json says $vJson." }
elseif ($isTemplateRepo -and -not (Test-Path -LiteralPath 'CHANGELOG.md' -PathType Leaf)) { Fail 'marked template repo has no CHANGELOG.md.' }
# The version number alone is not proof the entry is released: the marked template's literal first
# H2 must use the same dated whole-line grammar the release preflight accepts after stamping. Unmarked
# consumers own their changelog convention, so their CHANGELOG.md is deliberately not parsed.
# Keep the placeholder case as its OWN finding rather than folding it into the grammar message
# below. The generic "expected '## X.Y.Z — YYYY-MM-DD'" is true but unhelpful here, and this exact
# defect -- the literal word Unreleased shipping to consumers as their release date -- reached a
# release twice (v0.35.0, v0.46.0) and both times was caught only by a human noticing.
elseif ($isTemplateRepo -and -not $vLog -and $vLogLine -cmatch ("^## " + [regex]::Escape($vJson) + " — Unreleased$")) {
    Fail "CHANGELOG.md head entry for the current version $vJson still reads '$vLogLine' — stamp it with a real release date before shipping."
}
elseif ($isTemplateRepo -and -not $vLog) { Fail "marked template repo CHANGELOG.md literal first '## ' line is '$vLogLine' — expected '## X.Y.Z — YYYY-MM-DD'." }
elseif ($vLog -and $vLog -ne $vJson) { Fail "version-stamp drift: CHANGELOG.md head entry is $vLog, framework-version.json says $vJson." }
else { OK "version stamps in sync ($vClaude)$(if (-not $isTemplateRepo) { ' (consumer repo — CHANGELOG.md ignored, pair-check only)' })." }

if ($isTemplateRepo -and $vJson) {
    foreach ($group in @($changelogHeads | Group-Object Version | Where-Object Count -gt 1)) {
        Fail "CHANGELOG.md has duplicate release headings for version $($group.Name)."
    }
    foreach ($headEntry in @($changelogHeads | Where-Object Suffix -eq 'Unreleased')) {
        if ([version]$headEntry.Version -le [version]$vJson) {
            Fail "CHANGELOG.md has an Unreleased heading for shipped version $($headEntry.Version) (current stamped version: $vJson)."
        }
    }
    # Restores coverage that reading only the FIRST '## ' line used to provide. That read had to go,
    # because the intended pre-stamp state puts the next version's Unreleased head on top -- but it
    # was also the only thing rejecting a DATED head for a version above the stamped one, which is
    # B-152's defect one notch over. There is no legitimate case for it: after a release the top
    # dated head IS the stamped version, and during authoring the top head is Unreleased.
    foreach ($headEntry in @($changelogHeads | Where-Object { $_.Suffix -cmatch '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' })) {
        if ([version]$headEntry.Version -gt [version]$vJson) {
            Fail "CHANGELOG.md has a dated heading for version $($headEntry.Version), which is above the stamped version $vJson -- a release that was dated but never stamped, or a stray head."
        }
    }
}

# --- 2. Framework-rules source <-> AGENTS.md verbatim mirror ------------------------------------
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
    # Updated consumers receive the framework-owned carrier outside protected CLAUDE.md. Consumers
    # that have not migrated yet legitimately retain these sections inline, so prefer the carrier
    # when present and fall back section-by-section to CLAUDE.md.
    $cl = Get-Content 'CLAUDE.md'
    $carrierPath = '.github/instructions/framework-rules.instructions.md'
    $carrier = if (Test-Path $carrierPath) { @(Get-Content $carrierPath) } else { @() }
    $ag = Get-Content 'AGENTS.md'
    foreach ($sec in @('## Verification Rules','## Leanness','## SOLID')) {
        $a = Get-Section $carrier $sec
        $source = $carrierPath
        if (-not $a) { $a = Get-Section $cl $sec; $source = 'CLAUDE.md' }
        $b = Get-Section $ag $sec
        if (-not $a) { Fail "section '$sec' is missing from both $carrierPath and CLAUDE.md." }
        elseif ($a -ne $b) { Fail "AGENTS.md section '$sec' is not a verbatim mirror of $source — run /generate-copilot." }
        else { OK "'$sec' mirrored verbatim." }
    }
    # Boy Scout remains consumer-owned in CLAUDE.md and is intentionally not carried separately.
    $boyClaude = Get-Section $cl '## Boy Scout Rule'
    $boyAgents = Get-Section $ag '## Boy Scout Rule'
    if (-not $boyClaude) { Fail "CLAUDE.md is missing section '## Boy Scout Rule'." }
    elseif ($boyClaude -ne $boyAgents) { Fail "AGENTS.md section '## Boy Scout Rule' is not a verbatim mirror of CLAUDE.md — run /generate-copilot." }
    else { OK "'## Boy Scout Rule' mirrored verbatim." }

    $s1c = Get-Section1 $carrier
    $workflowSource = $carrierPath
    if (-not $s1c) { $s1c = Get-Section1 $cl; $workflowSource = 'CLAUDE.md' }
    $s1a = Get-Section1 $ag
    if (-not $s1c) { Fail "Agentic Workflow §1 is missing from both $carrierPath and CLAUDE.md." }
    elseif ($s1c -ne $s1a) { Fail "AGENTS.md Agentic Workflow §1 is not verbatim with $workflowSource (this is the only compared routing block) — run /generate-copilot." }
    else { OK 'Agentic Workflow §1 mirrored verbatim.' }
} else {
    Fail 'CLAUDE.md or AGENTS.md missing — cannot check mirror parity.'
}

# --- 3. copilot-instructions.md present and slim ----------------------------------------------
if (-not (Test-Path '.github/copilot-instructions.md')) {
    Fail '.github/copilot-instructions.md is missing — run /generate-copilot.'
} else {
    # @().Count includes blank lines; Measure-Object -Line does not.
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

# --- 5. Framework PowerShell hook set ----------------------------------------------------------
if (Test-Path '.claude/hooks') {
    $requiredHooks = @(
        'audit-trail.ps1',
        'boy-scout-check.ps1',
        'guard.ps1',
        'post-write.ps1',
        'route-prompt.ps1',
        'session-start.ps1'
    )
    $missingHooks = @($requiredHooks | Where-Object {
        -not (Test-Path -LiteralPath (Join-Path '.claude/hooks' $_) -PathType Leaf)
    })
    if ($missingHooks.Count -gt 0) {
        Fail ("required framework PowerShell hooks missing: " + ($missingHooks -join ', ') + '.')
    } else {
        OK 'required framework PowerShell hook set present (6).'
    }
} else {
    Fail 'required framework PowerShell hooks missing: .claude/hooks directory is absent.'
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

# --- 7. Canonical project-skill location ------------------------------------------------------
# GitHub Copilot documents .claude/skills as a project-skill location. A second .github/skills
# tree is therefore a higher-priority shadow and a migration defect, not a mirror to repair.
if (Test-Path -LiteralPath '.github/skills') {
    Fail '.github/skills exists — migrate its contents to .claude/skills, then remove the GitHub path.'
} else {
    OK 'canonical project skills use .claude/skills (.github/skills absent).'
}
$retiredSkillSync = @('scripts/sync-agent-files.ps1') |
    Where-Object { Test-Path -LiteralPath $_ }
if ($retiredSkillSync.Count -gt 0) {
    Fail ("retired skill-mirror sync scripts exist: " + ($retiredSkillSync -join ', ') + ' — remove these framework leftovers.')
} else {
    OK 'retired skill-mirror sync scripts are absent.'
}

# --- 8. Common Tasks skill inventory: CLAUDE.md <-> AGENTS.md ---------------------------------
# The descriptions are intentionally allowed to be condensed in AGENTS.md. The slug inventory is
# contractual on both surfaces, though: /generate-copilot promises Common Tasks is "the skills
# list". Normalize BOM/CRLF before parsing so checkout encoding cannot split the input.
function Get-CommonTaskInventory($Path) {
    $text = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path) -replace "`r`n", "`n"
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    $exists = $false
    $inSection = $false
    $slugs = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($text -split "`n")) {
        if ($line -eq '## Common Tasks') { $exists = $true; $inSection = $true; continue }
        if ($inSection -and $line -match '^## ') { break }
        if ($inSection -and $line -cmatch '^- `(?<slug>[a-z0-9][a-z0-9-]*)` (?:—|-) ') {
            $slugs.Add($Matches.slug)
        }
    }
    return [pscustomobject]@{ Exists = $exists; Slugs = @($slugs) }
}

if ((Test-Path 'CLAUDE.md') -and (Test-Path 'AGENTS.md')) {
    $commonClaude = Get-CommonTaskInventory 'CLAUDE.md'
    $commonAgents = Get-CommonTaskInventory 'AGENTS.md'

    # Duplicates must be diagnosed before set equality, because a set comparison hides them.
    foreach ($side in @(@('CLAUDE.md',$commonClaude), @('AGENTS.md',$commonAgents))) {
        $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        $reported = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        foreach ($slug in $side[1].Slugs) {
            if (-not $seen.Add($slug) -and $reported.Add($slug)) {
                Fail "Common Tasks skill inventory has duplicate slug in $($side[0]): $slug."
            }
        }
    }

    # Compare ordinally without sorting; the lowercase-only slug grammar makes case drift unparseable.
    $missingAgents = @()
    $missingClaude = @()
    if ($commonClaude.Exists -and $commonAgents.Exists) {
        $missingAgents = @($commonClaude.Slugs | Where-Object { -not ($commonAgents.Slugs -ccontains $_) })
        $missingClaude = @($commonAgents.Slugs | Where-Object { -not ($commonClaude.Slugs -ccontains $_) })
    }
    if ($commonClaude.Exists -and $commonAgents.Exists -and
        ($missingAgents.Count -gt 0 -or $missingClaude.Count -gt 0)) {
        $parts = @()
        if ($missingAgents.Count -gt 0) { $parts += "missing from AGENTS.md: $($missingAgents -join ', ')" }
        if ($missingClaude.Count -gt 0) { $parts += "missing from CLAUDE.md: $($missingClaude -join ', ')" }
        Fail ("Common Tasks skill inventory differs: " + ($parts -join '; ') + '.')
    }

    # A present section yielding no slugs means the list grammar changed and the check is blind.
    if (($commonClaude.Exists -or $commonAgents.Exists) -and
        (@($commonClaude.Slugs).Count -eq 0 -and @($commonAgents.Slugs).Count -eq 0)) {
        Fail 'Common Tasks sections yielded zero skill slugs — the list grammar changed and this check is now blind.'
    }

    if (-not $commonClaude.Exists -and -not $commonAgents.Exists) {
        OK 'Common Tasks section is absent from both CLAUDE.md and AGENTS.md; skill inventory check did not run.'
    } elseif ($commonClaude.Exists -ne $commonAgents.Exists) {
        $missingSide = if ($commonClaude.Exists) { 'AGENTS.md' } else { 'CLAUDE.md' }
        Fail "Common Tasks section is missing from $missingSide."
    } elseif ($missingAgents.Count -eq 0 -and $missingClaude.Count -eq 0 -and
              @($commonClaude.Slugs).Count -gt 0 -and @($commonAgents.Slugs).Count -gt 0) {
        OK 'Common Tasks skill inventory matches between CLAUDE.md and AGENTS.md.'
    }
}

Write-Output ''
if ($failed -gt 0) { Write-Output "$failed framework check(s) FAILED."; exit 3 }
Write-Output 'All deterministic framework checks passed.'
exit 0
