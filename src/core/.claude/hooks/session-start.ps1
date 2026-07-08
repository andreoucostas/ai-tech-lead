# SessionStart hook -- preload high-signal context every new session.
# PowerShell equivalent of session-start.sh, for Windows-only PowerShell teams.
# Output goes to the assistant's context as auxiliary data. Claude Code consumes plain stdout;
# Copilot (CLI, and VS Code agent mode with Preview agent-hooks) consumes stdout only as JSON
# additionalContext -- see the surface dispatch at the bottom.
# Keep fast: no expensive scans. Targets git, CLAUDE.md, TECH_DEBT.md only.

$ErrorActionPreference = 'SilentlyContinue'

# Read stdin (when redirected) for surface detection; Claude Code events carry hook_event_name.
$stdinJson = ''
if ([Console]::IsInputRedirected) { $stdinJson = [Console]::In.ReadToEnd() }

$body = (& {

Write-Output "## Session preload"

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
    Write-Output "- 🔴 **ADOPTION PENDING -- this repo is not consolidated yet.** The installer detected pre-existing AI tooling; the originals it displaced are archived under ``docs/pre-adoption/`` and inventoried in ``.claude/adoption-pending.json``. The required next step is ``/adopt`` -- NOT ``/bootstrap``, which would skip the archive/merge/provenance flow and the impact baseline. ``/adopt`` is developer-initiated and cannot be invoked by the model: if you are an agent, stop and tell the developer to type ``/adopt``."
} elseif (Test-Path CLAUDE.md) {
    $claude = Get-Content CLAUDE.md -Raw
    if ($claude -and $claude -match 'BOOTSTRAP_PENDING') {
        Write-Output "- WARNING: **CLAUDE.md is unbootstrapped** (BOOTSTRAP_PENDING marker present). ``/bootstrap`` must run before non-trivial work -- conventions are still placeholder. It is developer-initiated and cannot be invoked by the model: if you are an agent, tell the developer to type ``/bootstrap``."
    }
}

# 3. Workflow-routing pointer. Claude Code consumes this as plain stdout; on Copilot it lands
# only via the JSON additionalContext shape emitted below (CLI, and VS Code agent mode with
# Preview agent-hooks -- older Copilot versions drop it, and routing there rests on
# AGENTS.md > Agentic Workflow section 1, the always-on instruction surface). The full
# intent->workflow vocabulary lives in section 1 (canonical); we do not re-list it here.
if (Test-Path CLAUDE.md) {
    Write-Output '- **Workflow routing:** when a prompt clearly matches a workflow and the developer did not type a `/command`, self-classify and apply that workflow''s rails from `CLAUDE.md > Agentic Workflow` (section 1). State which workflow you concluded.'
}

# 4. TECH_DEBT items touching recently changed files
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

# 5. Overdue security findings
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
            Write-Output "- 🔴 **Security:** $overdue overdue finding(s) in SECURITY_FINDINGS.md. Remediation SLA breached -- review before starting new work."
        } else {
            Write-Output "- **Security:** $openCount open finding(s) in SECURITY_FINDINGS.md."
        }
    }
}

}) -join "`n"

# Surface dispatch. Claude Code includes hook_event_name in the event payload and treats plain
# stdout as context. Copilot parses stdout only as JSON additionalContext (CLI, and VS Code agent
# mode with Preview agent-hooks) -- emit both the top-level and wrapped shapes, mirroring
# guard.ps1's dual-shape approach. Older Copilot versions ignore the JSON: harmless no-op, same
# as pre-port behavior. Empty or non-JSON stdin defaults to plain stdout (Claude-compatible).
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
