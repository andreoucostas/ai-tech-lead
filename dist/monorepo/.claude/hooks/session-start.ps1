# SessionStart hook -- format high-signal context when the script is invoked.
# PowerShell equivalent of session-start.sh, for Windows-only PowerShell teams.
# For Claude-shaped input this script emits plain stdout; for other JSON input it emits top-level
# and wrapped JSON additionalContext shapes. Emission and registration do not prove host firing or
# consumption; current VS Code session-hook lifecycles are unverified. See docs/enforcement-surfaces.md.
# Keep fast: no expensive scans. Targets git, CLAUDE.md, TECH_DEBT.md, and
# FRAMEWORK-CONTEXT.md only; the hazard table is capped at ~12 entries, so parsing stays cheap.

$ErrorActionPreference = 'SilentlyContinue'

# Best-effort proof that hook wiring actually invoked this script. Telemetry must never affect
# the preload: an unwritable or otherwise unavailable state path is deliberately ignored.
try {
    $stateDir = Join-Path (Get-Location) '.claude/.state'
    New-Item -ItemType Directory -Force -Path $stateDir -ErrorAction Stop | Out-Null
    [IO.File]::WriteAllText(
        (Join-Path $stateDir 'last-session-start'),
        [DateTime]::UtcNow.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", [Globalization.CultureInfo]::InvariantCulture),
        [Text.UTF8Encoding]::new($false)
    )
} catch { }

# Emit UTF-8 when captured: consuming harnesses read raw bytes, and the default
# [Console]::OutputEncoding (the OEM code page on Windows) would mangle ⚠/—/🔴 into '?'.
# Guarded so an interactive console's code page is never changed.
if ([Console]::IsOutputRedirected) {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
}

# Read stdin (when redirected) for surface detection; Claude Code events carry hook_event_name.
$stdinJson = ''
if ([Console]::IsInputRedirected) { $stdinJson = [Console]::In.ReadToEnd() }

# Weekly, offline-only version awareness. This does not know whether a newer version exists; it
# only names the installed stamp and points to the releases page. Claim the throttle record before
# emitting so an unwritable state directory cannot turn a low-noise nudge into every-session noise.
$versionNudge = $null
try {
    $versionFile = Join-Path (Get-Location) '.claude/framework-version.json'
    $installedVersion = (Get-Content -LiteralPath $versionFile -Raw -ErrorAction Stop | ConvertFrom-Json).version
    if ($installedVersion) {
        $nowEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $awarenessFile = Join-Path $stateDir 'last-version-awareness'
        $lastEpoch = 0L
        if (Test-Path -LiteralPath $awarenessFile) {
            [long]::TryParse([IO.File]::ReadAllText($awarenessFile).Trim(), [ref]$lastEpoch) | Out-Null
        }
        if ($lastEpoch -le 0 -or ($nowEpoch - $lastEpoch) -ge (7 * 86400)) {
            [IO.File]::WriteAllText($awarenessFile, $nowEpoch.ToString(), [Text.UTF8Encoding]::new($false))
            $versionNudge = "- **Framework version:** v$installedVersion installed; check for updates: https://github.com/andreoucostas/ai-tech-lead/releases"
        }
    }
} catch { }

$body = (& {

Write-Output "## Session preload"
if ($versionNudge) { Write-Output $versionNudge }

# 1. Git branch + last 3 commits
if (Test-Path .git) {
    $branch = git rev-parse --abbrev-ref HEAD
    if ($LASTEXITCODE -eq 0 -and $branch) {
        Write-Output "- **Branch:** ``$branch``"
    } else {
        Write-Output "- **Branch:** ``(unknown)``"
    }

    $recent = git log -3 --format='  - `%h` %s'
    if ($LASTEXITCODE -eq 0 -and $recent) {
        Write-Output "- **Recent commits:**"
        foreach ($line in $recent) { Write-Output $line }
    }
}

# 2. Adoption / bootstrap state warning
if (Test-Path .claude/adoption-pending.json) {
    Write-Output "- 🔴 **ADOPTION PENDING — this repo is not consolidated yet.** The installer detected pre-existing AI tooling; the originals it displaced are archived under ``docs/pre-adoption/`` and inventoried in ``.claude/adoption-pending.json``. The required next step is ``/adopt`` — NOT ``/bootstrap``, which would skip the archive/merge/provenance flow. ``/adopt`` is developer-initiated and cannot be invoked by the model: if you are an agent, stop and tell the developer to type ``/adopt``."
} elseif (Test-Path CLAUDE.md) {
    $claude = Get-Content CLAUDE.md -Raw
    if ($claude -and $claude -match 'BOOTSTRAP_PENDING') {
        Write-Output "- ⚠ **CLAUDE.md is unbootstrapped** (BOOTSTRAP_PENDING marker present). ``/bootstrap`` must run before non-trivial work — conventions are still placeholder. It is developer-initiated and cannot be invoked by the model: if you are an agent, tell the developer to type ``/bootstrap``."
    }
}

# 3. Framework-rules migration pointer. Existing consumers keep their protected CLAUDE.md on
# update, so the newly delivered carrier needs a one-time import. This is discovery, not delivery:
# do not duplicate the rules into hook output.
if (Test-Path CLAUDE.md) {
    $claude = Get-Content CLAUDE.md -Raw
    if ((Test-Path .github/instructions/framework-rules.instructions.md) -and
        $claude -and -not $claude.Contains('@.github/instructions/framework-rules.instructions.md')) {
        Write-Output '- ⚠ **Framework rules migration:** `.github/instructions/framework-rules.instructions.md` is the current framework ruleset and supersedes any identically-titled sections in `CLAUDE.md`. Read it now. To make this permanent, add `@.github/instructions/framework-rules.instructions.md` to `CLAUDE.md` where those sections are, and delete them.'
    }
}

# 4. Workflow-routing pointer. The script writes this into whichever output shape the surface
# dispatch selects below. The framework rules (`.github/instructions/framework-rules.instructions.md`
# › Agentic Workflow; `AGENTS.md` › Agentic Workflow on AGENTS.md-native tools) remain the canonical
# file-based routing definition. Hook firing and consumption are capability-specific; current VS Code
# session-hook lifecycles are unverified. The full intent->workflow vocabulary lives in section 1.
if (Test-Path CLAUDE.md) {
    Write-Output '- **Workflow routing:** when a prompt clearly matches a workflow and the developer did not type a `/command`, self-classify and apply that workflow''s rails from the framework rules (`.github/instructions/framework-rules.instructions.md` › Agentic Workflow; `AGENTS.md` › Agentic Workflow on AGENTS.md-native tools), section 1. State which workflow you concluded.'
}

# 5. TECH_DEBT items touching recently changed files
if ((Test-Path TECH_DEBT.md) -and (Test-Path .git)) {
    $recentFiles = git log --since="14 days ago" --name-only --format="" |
        Where-Object { $_ -and $_.Trim() } |
        Sort-Object -Unique |
        Select-Object -First 30

    if ($recentFiles) {
        $debt = Get-Content TECH_DEBT.md -Raw
        $hot = 0
        if ($debt) {
            foreach ($f in $recentFiles) {
                if ([string]::IsNullOrWhiteSpace($f)) { continue }
                if ($debt.Contains($f)) { $hot++ }
            }
        }
        if ($hot -gt 0) {
            Write-Output "- **Debt heat:** $hot TECH_DEBT entry(ies) touch files changed in the last 14 days. Consider ``/debt`` for trojan-horse opportunities."
        }
    }
}

# 6. Overdue security findings
if (Test-Path SECURITY_FINDINGS.md) {
    $secContent = Get-Content SECURITY_FINDINGS.md -Raw
    $openCount = ([regex]::Matches($secContent, '\| Open ')).Count
    if ($openCount -gt 0) {
        $today = (Get-Date).ToString('yyyy-MM-dd')
        $overdue = 0
        foreach ($line in (Get-Content SECURITY_FINDINGS.md)) {
            if ($line -match '\| Open ') {
                $dates = [regex]::Matches($line, '\d{4}-\d{2}-\d{2}')
                if ($dates.Count -ge 2) {
                    $due = $dates[1].Value
                    if ([string]::Compare($due, $today, $false) -lt 0) { $overdue++ }
                }
            }
        }
        if ($overdue -gt 0) {
            Write-Output "- 🔴 **Security:** $overdue overdue finding(s) in SECURITY_FINDINGS.md. Remediation SLA breached — review before starting new work."
        } else {
            Write-Output "- **Security:** $openCount open finding(s) in SECURITY_FINDINGS.md."
        }
    }
}

# 7. Team wiki index (cheap capped preload; staleness belongs to wiki-check)
if (Test-Path docs/wiki/INDEX.md) {
    $wikiIndex = Get-Content docs/wiki/INDEX.md -Raw
    $wikiCount = ([regex]::Matches($wikiIndex, '(?m)^- \[')).Count
    if ($wikiCount -le 30) { Write-Output $wikiIndex.TrimEnd() }
    else { Write-Output "$wikiCount wiki entries — read docs/wiki/INDEX.md" }
}

# 8. Hazard-area staleness
if (Test-Path FRAMEWORK-CONTEXT.md) {
    $frameworkContext = Get-Content FRAMEWORK-CONTEXT.md -Raw
    if ($frameworkContext -and $frameworkContext -notmatch 'KNOWN_HAZARD_AREAS_PENDING') {
        $inHazards = $false
        $openStale = 0
        $confirmedStale = 0
        $cutoff = (Get-Date).AddDays(-90)
        foreach ($line in (Get-Content FRAMEWORK-CONTEXT.md)) {
            if ($line -match '^## Known Hazard Areas\s*$') { $inHazards = $true; continue }
            if ($inHazards -and $line -match '^## ') { break }
            if (-not $inHazards -or $line -notmatch '^\|') { continue }
            $cells = $line.Split('|') | ForEach-Object { $_.Trim() }
            if ($cells.Count -lt 6) { continue }
            $area = $cells[1]; $hazard = $cells[2]; $status = $cells[3]; $rev = $cells[4]
            if (($area -eq '_(drafted by /bootstrap)_' -and $hazard -eq '_' -and $status -eq '_' -and $rev -eq '_') -or
                $status.StartsWith('[REVIEWED: not a hazard')) { continue }
            try {
                $reviewed = [datetime]::ParseExact($rev, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
                if ($reviewed -ge $cutoff) { continue }
            } catch { continue }
            if ($status -eq '[UNVERIFIED]' -or $status -eq '[SUSPECTED]') { $openStale++ }
            elseif ($status -eq '[VERIFIED]') { $confirmedStale++ }
        }
        if ($openStale -gt 0) {
            Write-Output "- ⚠ **Hazard areas:** $openStale hazard area(s) have waited over 90 days for a human answer — confirm each, or mark it 'not a hazard', in FRAMEWORK-CONTEXT.md > Known Hazard Areas."
        } elseif ($confirmedStale -gt 0) {
            Write-Output "- **Hazard areas:** $confirmedStale confirmed hazard area(s) are over 90 days old — a quick re-confirm in FRAMEWORK-CONTEXT.md keeps the map trustworthy."
        }
    }
}

}) -join "`n"

# Surface dispatch. Claude-shaped input selects plain stdout. Other JSON input selects top-level
# and hookSpecificOutput-wrapped SessionStart additionalContext JSON. These are script-emitted
# shapes only: registration and output do not prove that a host fired the event or consumed the
# result. Empty or non-JSON stdin selects plain stdout. Current VS Code session-hook lifecycles are
# unverified; dated CLI evidence is recorded in docs/enforcement-surfaces.md.
$isCopilot = ($stdinJson -and $stdinJson.TrimStart().StartsWith('{') -and ($stdinJson -notmatch '"hook_event_name"'))
if ($isCopilot) {
    $payload = @{
        additionalContext  = $body
        hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $body }
    }
    Write-Output ($payload | ConvertTo-Json -Compress -Depth 4)
} else {
    Write-Output $body
}

exit 0
