# SessionStart hook -- preload high-signal context every new session.
# PowerShell equivalent of session-start.sh, for Windows-only PowerShell teams.
# Output goes to the assistant's context as auxiliary data.
# Keep fast: no expensive scans. Targets git, CLAUDE.md, TECH_DEBT.md only.

$ErrorActionPreference = 'SilentlyContinue'

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

# 3. Workflow-routing primer.
# In Claude Code, route-prompt.ps1 injects rails per-prompt. In GitHub Copilot the
# userPromptSubmitted hook is fire-and-forget (stdout is discarded by spec), so the
# only place to surface the routing vocabulary is here -- once per session. Top-tier
# models will self-classify against this list and apply the corresponding workflow.
if (Test-Path CLAUDE.md) {
    Write-Output '- **Workflow routing:** when the user''s prompt clearly matches one of the workflows below and they did not type an explicit `/command`, apply that workflow''s rails from `CLAUDE.md > Agentic Workflow` before responding. State which workflow you concluded.'
    Write-Output '  - `feature` -- add, implement, create, build new ...'
    Write-Output '  - `fix` -- broken, bug, crash, failing, regression, not working'
    Write-Output '  - `refactor` -- cleanup, extract, rename, simplify, restructure'
    Write-Output '  - `test` -- write/add tests, increase coverage'
    Write-Output '  - `design` -- design X, approach for, trade-offs, how should I architect'
    Write-Output '  - `debt` -- tech debt, technical debt, cleanup debt'
    Write-Output '  - `review` -- review this PR/changes/code, quality gate'
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

exit 0
