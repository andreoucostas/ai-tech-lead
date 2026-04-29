# Stop hook -- flag Boy Scout opportunities in modified .cs files.
# PowerShell equivalent of boy-scout-check.sh, for Windows-only PowerShell teams.
# Soft-warning by default (plain stdout).
#
# Patterns derived from the always-apply items in CLAUDE.md > Boy Scout Rule:
#   - missing CancellationToken on async methods (best-effort)
#   - string-interpolated logger calls
#   - missing .AsNoTracking() near .ToListAsync/.FirstOrDefaultAsync
#   - missing null guards at public boundaries (heuristic)

$ErrorActionPreference = 'SilentlyContinue'

if (-not (Test-Path .git)) { exit 0 }

$changed = @()
$changed += git diff --name-only -- '*.cs'
$changed += git diff --cached --name-only -- '*.cs'
$changed += git ls-files --others --exclude-standard -- '*.cs'

$files = $changed |
    Where-Object { $_ -and $_.Trim() } |
    Sort-Object -Unique |
    Select-Object -First 30

if (-not $files) { exit 0 }

$findings = New-Object System.Collections.Generic.List[string]
$checked = 0

foreach ($f in $files) {
    if ([string]::IsNullOrWhiteSpace($f)) { continue }
    if (-not (Test-Path $f)) { continue }

    # Skip test files, generated files, obj/bin trees
    if ($f -match '(?i)(Tests\.cs|Test\.cs|\.g\.cs|\.Designer\.cs)$') { continue }
    if ($f -match '(?i)(^|/)(obj|bin)/') { continue }

    $checked++

    $lines = Get-Content $f
    if (-not $lines) { continue }
    $content = $lines -join "`n"

    # 1. async Task signatures without CancellationToken in the parameter list
    $asyncNoCt = ($lines | Where-Object {
        $_ -match 'async\s+(Task|ValueTask)' -and
        $_ -match '\([^)]*\)' -and
        $_ -notmatch 'CancellationToken' -and
        $_ -notmatch '^\s*//'
    }).Count
    if ($asyncNoCt -gt 0) {
        $findings.Add("${f}: $asyncNoCt async method signature(s) without CancellationToken -- propagate per CLAUDE.md > Async")
    }

    # 2. String-interpolated logger calls (anti-pattern)
    $interpLog = ($lines | Where-Object {
        $_ -match '\b_?[Ll]ogger\.(Log|LogTrace|LogDebug|LogInformation|LogWarning|LogError|LogCritical)\(\s*\$"'
    }).Count
    if ($interpLog -gt 0) {
        $findings.Add("${f}: $interpLog interpolated logger call(s) -- switch to structured logging templates")
    }

    # 3. Read-style EF Core query without AsNoTracking in the same file (heuristic)
    if ($content -match '\.(ToListAsync|FirstOrDefaultAsync|SingleOrDefaultAsync|AnyAsync|CountAsync)\(' -and
        $content -notmatch 'AsNoTracking') {
        $findings.Add("${f}: read-style EF Core query without any AsNoTracking() in file -- review for read-only opportunities")
    }

    # 4. Null-suppression `!` without an adjacent comment -- weak proxy for missing null guards
    $bangHits = ($lines | Where-Object {
        $_ -match '[a-zA-Z_]+!' -and
        $_ -notmatch '^\s*//'
    }).Count
    if ($bangHits -ge 5) {
        $findings.Add("${f}: $bangHits null-forgiving (``!``) usage(s) -- confirm each is justified or add guard clauses")
    }

    # 5. Commented-out code blocks -- runs of 2+ contiguous code-like // lines
    $maxRun = 0
    $run = 0
    foreach ($line in $lines) {
        if ($line -match '^\s*//\s*(.*)$') {
            $stripped = $Matches[1]
            if ($stripped -match '[;{}=]' -or $stripped -match '[a-zA-Z_]+\(') {
                $run++
                if ($run -gt $maxRun) { $maxRun = $run }
            } else { $run = 0 }
        } else { $run = 0 }
    }
    if ($maxRun -ge 2) {
        $findings.Add("${f}: commented-out code block ($maxRun+ contiguous lines) -- delete; version control preserves history (CLAUDE.md > Boy Scout > Subtract)")
    }
}

if ($findings.Count -eq 0) { exit 0 }

# Dedup: skip output when this finding set matches the last fire's output.
$null = New-Item -ItemType Directory -Path .claude\.state -Force
$hashFile = '.claude\.state\last-boy-scout-hash'
$joined = ($findings | Sort-Object) -join "`n"
$sha1 = [System.Security.Cryptography.SHA1]::Create()
$bytes = [System.Text.Encoding]::UTF8.GetBytes($joined)
$currentHash = -join ($sha1.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') })
if (Test-Path $hashFile) {
    $prev = (Get-Content $hashFile -Raw)
    if ($prev) { $prev = $prev.Trim() }
    if ($prev -eq $currentHash) { exit 0 }
}
Set-Content -Path $hashFile -Value $currentHash -Encoding ASCII

Write-Output "## Boy Scout candidates ($checked file(s) scanned)"
Write-Output ''
foreach ($finding in $findings) { Write-Output "- $finding" }
Write-Output ''
Write-Output "_If these touch files you modified this turn, address them per CLAUDE.md > Boy Scout Rule before considering the work complete. Otherwise add a ``// TODO: Boy Scout skipped -- [reason]`` comment._"

exit 0
