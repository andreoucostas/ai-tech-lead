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

# 2. Bootstrap state warning
if (Test-Path CLAUDE.md) {
    $claude = Get-Content CLAUDE.md -Raw
    if ($claude -and $claude -match 'BOOTSTRAP_PENDING') {
        Write-Output "- WARNING: **CLAUDE.md is unbootstrapped** (BOOTSTRAP_PENDING marker present). Run ``/bootstrap`` before non-trivial work -- conventions are still placeholder."
    }
}

# 3. TECH_DEBT items touching recently changed files
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

# 4. Overdue security findings
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

exit 0
