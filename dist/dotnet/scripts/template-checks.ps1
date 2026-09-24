# AI Tech Lead deterministic framework checks.
# Exit 0 = verified clean, 3 = verified finding(s), 2 = required input could not be inspected.
# Any other nonzero is an abnormal/incomplete run. Runs in BOTH contexts:
#   - the template repo itself (wired into .github/workflows/template-ci.yml) — this is the gate
#     that keeps the framework honest about its own invariants;
#   - a consumer repo (invoked by docs-sync-check) — the same invariants hold after install.
# Checks: version-stamp sync (AGENTS.md header == framework-version.json == CHANGELOG head),
# instruction layout (CLAUDE.md is the stub importing AGENTS.md and the framework rules),
# copilot-instructions.md present and <= 80 lines, UTF-8 BOM on framework .ps1 files,
# required PowerShell hook set, PS syntax of framework scripts, and skills-directory policy.
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
if (Test-Path 'AGENTS.md') {
    $head = Get-Content 'AGENTS.md' -TotalCount 10
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
if (-not $vClaude) { Fail 'AGENTS.md has no version stamp in its header comment.' }
elseif (-not $vJson) { Fail '.claude/framework-version.json missing or unparsable.' }
elseif ($vClaude -ne $vJson) { Fail "version-stamp drift: AGENTS.md says $vClaude, framework-version.json says $vJson." }
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
    # the stale-Unreleased-head defect one notch over. There is no legitimate case for it: after a
    # release the top dated head IS the stamped version, and during authoring the top head is Unreleased.
    foreach ($headEntry in @($changelogHeads | Where-Object { $_.Suffix -cmatch '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' })) {
        if ([version]$headEntry.Version -gt [version]$vJson) {
            Fail "CHANGELOG.md has a dated heading for version $($headEntry.Version), which is above the stamped version $vJson -- a release that was dated but never stamped, or a stray head."
        }
    }
}

# --- 2. Instruction layout: AGENTS.md holds the instructions, CLAUDE.md imports it ------------
# Claude Code reads AGENTS.md itself only when no CLAUDE.md exists, and not on every host
# configuration, so CLAUDE.md stays as a stub whose two imports are what deliver both files.
function Test-ImportLine($Lines, [string[]]$Import) {
    return [bool](@($Lines) | Where-Object { $Import -ccontains $_.Trim() } | Select-Object -First 1)
}
$layoutHelp = 'Move the project instructions into AGENTS.md and make CLAUDE.md the two-import stub (docs/upgrade-checklist.md).'
if (-not (Test-Path -LiteralPath 'AGENTS.md' -PathType Leaf)) {
    Fail "AGENTS.md is missing. $layoutHelp"
} elseif (-not (Test-Path -LiteralPath 'CLAUDE.md' -PathType Leaf)) {
    Fail 'CLAUDE.md is missing - Claude Code needs it to import AGENTS.md and the framework rules.'
} else {
    $cl = @(Get-Content 'CLAUDE.md')
    $ag = @(Get-Content 'AGENTS.md')
    # Any @AGENTS.md mention counts, as in the installer and session-start: Claude Code honours
    # inline imports too, and a false "older layout" finding would send a migrated repo backwards.
    if (-not (($cl -join "`n") -cmatch '(?<![\w/.@-])@(\./)?AGENTS\.md(?![\w-])')) {
        Fail "CLAUDE.md does not import AGENTS.md - this repo still uses the older layout. $layoutHelp"
    } else { OK 'CLAUDE.md imports AGENTS.md.' }
    if (-not (Test-ImportLine $cl '@.github/instructions/framework-rules.instructions.md')) {
        Fail 'CLAUDE.md does not import .github/instructions/framework-rules.instructions.md - Claude Code would run without the framework rules.'
    } else { OK 'CLAUDE.md imports the framework rules.' }
    # The retired mirror always opened with this banner; prose about generated files is the consumer's.
    $firstLine = @($ag | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1)
    if ($firstLine.Count -eq 1 -and $firstLine[0].TrimStart([char]0xFEFF).StartsWith('<!-- GENERATED FILE', [StringComparison]::Ordinal)) {
        Fail "AGENTS.md still carries the retired generated-mirror banner. If it is the old mirror: $layoutHelp If you wrote this file, delete that first line."
    } elseif (-not ($ag -ccontains '## Boy Scout Rule')) {
        Fail "AGENTS.md is missing section '## Boy Scout Rule'."
    } else { OK 'AGENTS.md is the project instruction file.' }
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

Write-Output ''
if ($failed -gt 0) { Write-Output "$failed framework check(s) FAILED."; exit 3 }
Write-Output 'All deterministic framework checks passed.'
exit 0
