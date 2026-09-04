# Reports assertion-shaped removals in test-file diffs for review.
# Usage: pwsh -NoProfile -File scripts/test-weakening-scan.ps1 [<git-ref-range>]
# With no range, inspects staged changes. This is an advisory signal and always exits 0.
# LIMIT, stated because someone will otherwise read this as a detector: it counts assertion-shaped
# LINES, so three assertions collapsed onto one line and then deleted register as a single removal,
# and a rewrite that keeps the line count while gutting what is asserted registers as nothing at all.
# That is inherent to a diff-line heuristic, not a bug to fix -- distinguishing a weakened assertion
# from a legitimately refactored one needs intent, which no rule available here can read.
$ErrorActionPreference = 'Continue'

$range = if ($args.Count -gt 0) { $args[0] } else { $null }
$assertionShape = 'Assert|expect\s*\(|Should|\.Verify\s*\(|\[(Fact|Test)\b|\bit\s*\(|\bdescribe\s*\('

function Get-DiffNames {
    if ($null -eq $range) { return @(& git diff --cached --name-only --diff-filter=ACDMRTUXB -- 2>$null) }
    return @(& git diff $range --name-only --diff-filter=ACDMRTUXB -- 2>$null)
}

function Get-FileDiff([string]$path) {
    if ($null -eq $range) { return @(& git diff --cached --unified=0 --no-ext-diff --no-color -- $path 2>$null) }
    return @(& git diff $range --unified=0 --no-ext-diff --no-color -- $path 2>$null)
}

$signals = @()
foreach ($path in (Get-DiffNames)) {
    $normalized = $path -replace '\\', '/'
    $isTest = $normalized -match '(?i)(Tests\.cs$|\.spec\.ts$|\.Tests\.ps1$|(^|/)tests/)'
    if (-not $isTest) { continue }

    $removed = 0
    $added = 0
    foreach ($line in (Get-FileDiff $path)) {
        if ($line.StartsWith('---') -or $line.StartsWith('+++')) { continue }
        if ($line.StartsWith('-') -and $line.Substring(1) -match $assertionShape) { $removed++ }
        elseif ($line.StartsWith('+') -and $line.Substring(1) -match $assertionShape) { $added++ }
    }

    $net = $added - $removed
    if ($net -lt 0) {
        $signals += [pscustomobject]@{ Path = $normalized; Removed = $removed; Added = $added; Net = $net }
    }
}

if ($signals.Count -eq 0) {
    Write-Output 'Test-weakening advisory: nothing qualifies.'
} else {
    Write-Output 'Test-weakening advisory - review assertion-shaped removals:'
    foreach ($signal in $signals) {
        Write-Output ("  {0}: removed {1}, added {2}, net {3}" -f $signal.Path, $signal.Removed, $signal.Added, $signal.Net)
    }
    Write-Output 'This reviewable signal can be defeated by ignoring it; it is not enforcement.'
}

exit 0
