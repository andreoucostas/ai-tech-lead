# regression -- the post-write throttle epoch must be culture-invariant and never overflow Int32.
# Historic bug: `$now = [int][double]::Parse((Get-Date -UFormat %s))`. Under Windows PowerShell 5.1,
# -UFormat %s returns a FRACTIONAL LOCAL-TIME string (e.g. 1783162609.9606); [double]::Parse is
# culture-sensitive, so in comma-decimal locales (de-DE/el-GR/fr-FR) the dots are group separators,
# the value overflows Int32, and the [int] cast THROWS on every .cs/.ts write -- a terminating error
# that $ErrorActionPreference='SilentlyContinue' does not swallow. Fix: culture-free integer UTC epoch
# via [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().
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

# --- The bounded tool's budget is read by Get-PostWriteBudget, lifted out of the shipped hook by its AST.
# The host kills the hook at 90 s (Claude Code) / 120 s (Copilot): a larger knob value would be cut by the
# host before the hook's own kill, so it is clamped to 80. Exactly one bounded tool call runs per hook run,
# so the per-call clamp is the clamp for the run.
It 'ATL_POSTWRITE_BUDGET_SEC above 80 is clamped to 80, and the default and non-numbers keep 45' {
    $ast = [Management.Automation.Language.Parser]::ParseFile($hookPs, [ref]$null, [ref]$null)
    $fn = $ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-PostWriteBudget' }, $true)
    Assert ($null -ne $fn) 'post-write.ps1 has no Get-PostWriteBudget: the accepted ATL_POSTWRITE_BUDGET_SEC range cannot be observed or bounded'
    . ([scriptblock]::Create($fn.Extent.Text))
    $old = $env:ATL_POSTWRITE_BUDGET_SEC
    try {
        foreach ($case in @(@('300', 80), @('600', 80), @('81', 80), @('80', 80), @('30', 30), @('1', 1), @('0', 45), @('601', 80), @('-5', 45), @('abc', 45), @('', 45))) {
            $env:ATL_POSTWRITE_BUDGET_SEC = $case[0]
            $got = Get-PostWriteBudget
            Assert ($got -eq $case[1]) "ATL_POSTWRITE_BUDGET_SEC='$($case[0])': expected an effective budget of $($case[1]), got $got"
        }
    } finally { $env:ATL_POSTWRITE_BUDGET_SEC = $old }
}

exit (Write-TestSummary 'PostWrite.Tests (epoch)')
