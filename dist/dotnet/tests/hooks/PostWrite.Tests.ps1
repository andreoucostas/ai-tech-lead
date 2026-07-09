# B-02 regression -- the post-write throttle epoch must be culture-invariant and never overflow Int32.
# Historic bug: `$now = [int][double]::Parse((Get-Date -UFormat %s))`. Under Windows PowerShell 5.1,
# -UFormat %s returns a FRACTIONAL LOCAL-TIME string (e.g. 1783162609.9606); [double]::Parse is
# culture-sensitive, so in comma-decimal locales (de-DE/el-GR/fr-FR) the dots are group separators,
# the value overflows Int32, and the [int] cast THROWS on every .cs/.ts write -- a terminating error
# that $ErrorActionPreference='SilentlyContinue' does not swallow. Fix: culture-free integer UTC epoch
# via [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(), which also matches the .sh twin's `date +%s` (UTC).
# These tests are host-independent: they do not rely on 5.1's -UFormat quirk, so they run identically
# on pwsh 7 and 5.1, and both go RED against the pre-fix hook.
if (-not (Get-Command Reset-Tests -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$hookPs = (Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks\post-write.ps1')).Path
$src = [System.IO.File]::ReadAllText($hookPs)

Reset-Tests

# --- Static guard, tied to the actual shipped hook: the antipattern is gone, the safe form present.
# RED against the pre-fix file (which contains [double]::Parse((Get-Date -UFormat %s))); GREEN after.
It 'post-write.ps1 no longer parses Get-Date -UFormat %s (culture-sensitive; overflows in de-DE)' {
    Assert ($src -notmatch '\[double\]::Parse\(\(?\s*Get-Date\s+-UFormat') `
        'post-write.ps1 still computes the epoch via the culture-sensitive [double]::Parse((Get-Date -UFormat %s))'
}
It 'post-write.ps1 computes the throttle epoch via culture-free UTC ToUnixTimeSeconds()' {
    Assert ($src -match 'ToUnixTimeSeconds\(\)') `
        'post-write.ps1 epoch is not [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()'
}

# --- Behavioral proof of the mechanism, culture-forced. Simulates 5.1's fractional -UFormat %s output
# so it is deterministic on any host: the OLD approach overflows under de-DE, the NEW approach does not.
It 'old epoch approach overflows under a comma-decimal culture; new approach yields an integer UTC epoch' {
    $prev = [System.Threading.Thread]::CurrentThread.CurrentCulture
    try {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')
        $ps51Sample = '1783162609.9606'   # a fractional local-time string, exactly as PS 5.1 emits
        $threw = $false
        try { $null = [int][double]::Parse($ps51Sample) } catch { $threw = $true }
        Assert $threw 'expected the old [int][double]::Parse(...) to overflow Int32 under de-DE, but it did not'
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        Assert (($now -is [long]) -or ($now -is [int])) "new epoch is not an integer (got $($now.GetType().Name))"
        Assert ($now -gt 1700000000) "new epoch $now is not a plausible UTC unix timestamp"
    } finally {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $prev
    }
}

exit (Write-TestSummary 'PostWrite.Tests (B-02 epoch)')
