# Stop hook -- flag Boy Scout opportunities in modified .cs and .ts files (monorepo variant:
# each file gets its own stack's checks).
# PowerShell equivalent of boy-scout-check.sh, for Windows-only PowerShell teams.
# Soft-warning by default. Findings reach the model via hookSpecificOutput.additionalContext (a Stop
# hook's additionalContext is injected as a system reminder the model reads next turn) -- but that
# text is invisible in the terminal, so a one-line systemMessage is emitted alongside it so the
# developer also sees that candidates were flagged. Note: a Stop hook's @{ decision='block'; reason }
# is NOT a stricter variant of this -- `reason` is shown only to the user, never fed to the model.
#
# Patterns derived from the always-apply items in CLAUDE.md > Boy Scout Rule:
#   .cs -- missing CancellationToken on async methods (best-effort)
#       -- string-interpolated logger calls
#       -- missing .AsNoTracking() near .ToListAsync/.FirstOrDefaultAsync
#       -- missing null guards at public boundaries (heuristic)
#   .ts -- manual ngOnDestroy subscription cleanup
#       -- nested .subscribe()
#       -- explicit `any` / `as any`
# OnPush is intentionally NOT scanned: switching a component to OnPush is a
# semantic change, not a drive-by cleanup -- see CLAUDE.md > Boy Scout Rule.

$ErrorActionPreference = 'SilentlyContinue'

if (-not (Test-Path .git)) { exit 0 }

$changed = @()
$changed += git diff --name-only -- '*.cs' '*.ts'
$changed += git diff --cached --name-only -- '*.cs' '*.ts'
$changed += git ls-files --others --exclude-standard -- '*.cs' '*.ts'

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

    # Skip test files, generated files, obj/bin trees, type declarations (per stack)
    if ($f -match '(?i)(Tests\.cs|Test\.cs|\.g\.cs|\.Designer\.cs)$') { continue }
    if ($f -match '(?i)(^|/)(obj|bin)/') { continue }
    if ($f -match '\.(spec|test)\.ts$' -or $f -match '\.d\.ts$') { continue }

    $checked++

    $lines = Get-Content $f
    if (-not $lines) { continue }
    $content = $lines -join "`n"

    if ($f -match '\.cs$') {
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
        if ($content -match '(using\s+Microsoft\.EntityFrameworkCore|DbContext|DbSet<)' -and
            $content -match '\.(ToListAsync|FirstOrDefaultAsync|SingleOrDefaultAsync|AnyAsync|CountAsync)\(' -and
            $content -notmatch 'AsNoTracking') {
            $findings.Add("${f}: read-style EF Core query without any AsNoTracking() in file -- review for read-only opportunities")
        }

        # 4. Null-suppression `!` without an adjacent comment -- weak proxy for missing null guards.
        # Require `!` to be in postfix-operator position so `x!=y` (no spaces) doesn't false-positive.
        $bangHits = ($lines | Where-Object {
            $_ -match '[a-zA-Z_)\]]+!([.;,)\] ]|$)' -and
            $_ -notmatch '^\s*//'
        }).Count
        if ($bangHits -ge 5) {
            $findings.Add("${f}: $bangHits null-forgiving (``!``) usage(s) -- confirm each is justified or add guard clauses")
        }
    }
    else {
        # 1. ngOnDestroy + manual .subscribe -- likely a candidate for takeUntilDestroyed
        if ($content -match 'ngOnDestroy' -and $content -match '\.subscribe\(') {
            $findings.Add("${f}: manual ngOnDestroy with .subscribe -- consider takeUntilDestroyed()")
        }

        # 2. Multiple .subscribe( calls -- possible nested subscribe
        $subMatches = [regex]::Matches($content, '\.subscribe\(')
        if ($subMatches.Count -ge 3) {
            $findings.Add("${f}: $($subMatches.Count) .subscribe() calls -- review for nested subscribes (use switchMap/mergeMap/concatMap/exhaustMap)")
        }

        # 3. Explicit `any` (not in comments)
        $anyHits = ($lines | Where-Object {
            ($_ -match ':\s*any\b' -or $_ -match '\bas\s+any\b') -and
            $_ -notmatch '^\s*//'
        }).Count
        if ($anyHits -gt 0) {
            $findings.Add("${f}: $anyHits explicit ``any`` usage(s) -- replace with proper types or unknown+narrowing")
        }
    }

    # Commented-out code blocks -- runs of 2+ contiguous code-like // lines (both stacks)
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

$outLines = @("## Boy Scout candidates ($checked file(s) scanned)", '')
foreach ($finding in $findings) { $outLines += "- $finding" }
$outLines += ''
$outLines += "_If these touch files you modified this turn, address them per CLAUDE.md > Boy Scout Rule before considering the work complete. Otherwise add a ``// TODO: Boy Scout skipped -- [reason]`` comment._"
$text = $outLines -join "`n"

# additionalContext (above) reaches the model but is invisible in the terminal; emit a short
# systemMessage so the developer also sees that candidates were flagged.
$summary = "Boy Scout: $($findings.Count) candidate(s) flagged to the model across $checked file(s) (see CLAUDE.md > Boy Scout Rule)."

(@{ systemMessage = $summary; hookSpecificOutput = @{ hookEventName = 'Stop'; additionalContext = $text } } | ConvertTo-Json -Compress)

exit 0
