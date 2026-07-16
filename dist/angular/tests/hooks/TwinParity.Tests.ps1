# WS-M3 (headline) -- prove each .ps1/.sh twin makes the SAME decision on the SAME input.
# The historic guard.sh regression (shipped missing guard.ps1's test-defeat blocks) would FAIL here.
# Deep parity on guard (decision-bearing); robustness parity (no-crash on empty/malformed) on every pair.
if (-not (Get-Command Invoke-Hook -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
. (Join-Path $PSScriptRoot 'fixtures\guard-cases.ps1')
$hooks   = (Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks')).Path
$guardPs = Join-Path $hooks 'guard.ps1'
$guardSh = Join-Path $hooks 'guard.sh'
$bash    = Get-BashPath

Reset-Tests

# --- Deep guard parity: identical decision from .ps1 and .sh, both surfaces ---
if (-not $bash) {
    Skip 'guard twin parity (all cases)' 'no bash found -- cannot run .sh twin on this host'
} else {
    foreach ($case in $GuardCases) {
        foreach ($surface in 'Claude','Copilot') {
            $evt = if ($surface -eq 'Claude') { New-ClaudeEvent $case.f $case.c } else { New-CopilotEvent $case.f $case.c }
            It "guard twins agree ($surface): $($case.n)" {
                $dps = Get-Decision (Invoke-Hook $guardPs $evt)
                $dsh = Get-Decision (Invoke-Hook $guardSh $evt)
                Assert ($dps -eq $dsh) "guard.ps1 -> $dps but guard.sh -> $dsh"
            }
        }
    }
}

# --- Robustness parity for every twin pair: empty + malformed stdin must agree (and not crash) ---
# Run from a throwaway CWD so any incidental relative writes (e.g. audit log) never touch the repo.
$pairs = Get-ChildItem -LiteralPath $hooks -Filter *.ps1 | Where-Object {
    Test-Path -LiteralPath (Join-Path $hooks ($_.BaseName + '.sh'))
} | ForEach-Object { $_.BaseName } | Sort-Object

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("twincwd-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
Push-Location $tmp
try {
    foreach ($name in $pairs) {
        $ps = Join-Path $hooks "$name.ps1"; $sh = Join-Path $hooks "$name.sh"
        if (-not $bash) { Skip "$name twins agree (empty/malformed)" 'no bash found'; continue }
        It "$name twins agree on empty + malformed stdin (no crash)" {
            foreach ($inp in @('', 'not json {')) {
                $rps = Invoke-Hook $ps $inp; $rsh = Invoke-Hook $sh $inp
                Assert ($rps.Exit -eq $rsh.Exit) "input '$inp': $name.ps1 exit $($rps.Exit) != $name.sh exit $($rsh.Exit)"
                Assert ($rps.Exit -eq 0) "input '$inp': $name should degrade-safe to exit 0, got $($rps.Exit)"
            }
        }
    }
} finally {
    Pop-Location
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

# --- boy-scout EF evidence gate: Mongo-shaped async queries stay silent; EF queries still flag ---
$boyPs = Join-Path $hooks 'boy-scout-check.ps1'; $boySh = Join-Path $hooks 'boy-scout-check.sh'
if (-not (Test-Path -LiteralPath $boyPs) -or -not ((Get-Content -Raw -LiteralPath $boyPs) -match 'read-style EF Core query')) {
    Skip 'boy-scout EF evidence gate (all cases)' 'distribution does not carry the .NET boy-scout heuristic'
} elseif (-not $bash) {
    Skip 'boy-scout EF evidence gate (all cases)' 'no bash found -- cannot run .sh twin on this host'
} else {
    $boyCases = @(
        @{ n = 'Mongo ToListAsync has zero findings'; file = 'MongoQuery.cs'; content = "using MongoDB.Driver;`nclass MongoQuery { async Task Run(IMongoCollection<string> c) => await c.Find(Builders<string>.Filter.Empty).ToListAsync(); }"; expect = $false },
        @{ n = 'EF ToListAsync without AsNoTracking flags'; file = 'EfQuery.cs'; content = "using Microsoft.EntityFrameworkCore;`nclass EfQuery { async Task Run(DbSet<string> rows) => await rows.ToListAsync(); }"; expect = $true }
    )
    foreach ($case in $boyCases) {
        It "boy-scout twins agree: $($case.n)" {
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("boyfix-" + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Push-Location $dir
            try {
                git init --quiet
                [IO.File]::WriteAllText((Join-Path $dir $case.file), $case.content)
                $rps = Invoke-Hook $boyPs '{}'
                Remove-Item -LiteralPath (Join-Path $dir '.claude') -Recurse -Force -ErrorAction SilentlyContinue
                $rsh = Invoke-Hook $boySh '{}'
                $hasPs = $rps.Out -match 'read-style EF Core query'
                $hasSh = $rsh.Out -match 'read-style EF Core query'
                Assert ($hasPs -eq $case.expect) "boy-scout.ps1 finding expected=$($case.expect), actual=$hasPs, output='$($rps.Out)'"
                Assert ($hasSh -eq $case.expect) "boy-scout.sh finding expected=$($case.expect), actual=$hasSh, output='$($rsh.Out)'"
            } finally { Pop-Location; Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}

# --- session-start security-findings preload: twins agree and emit clean stderr ---
# Regression for the `grep -c … || echo 0` bug (grep -c prints 0 AND exits 1 on no match, so the
# fallback produced "0\n0" and an integer-comparison error on stderr) and for the section existing
# in one twin but not the other. Fixture CWDs; the real repo is never touched.
$ssPs = Join-Path $hooks 'session-start.ps1'; $ssSh = Join-Path $hooks 'session-start.sh'
if (-not $bash) {
    Skip 'session-start security-preload twins' 'no bash found'
} else {
    $secHeader = "| ID | Severity | Status | Found | Due | Issue |`n|---|---|---|---|---|---|"
    $secCases = @(
        @{ n = 'no open findings'; rows = '';                                                         expect = $false },
        @{ n = 'one open finding'; rows = "`n| SF-1 | High | Open | 2026-01-01 | 2099-01-01 | x |";  expect = $true }
    )
    foreach ($case in $secCases) {
        It "session-start twins agree on security preload ($($case.n)), clean stderr" {
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("ssfix-" + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Push-Location $dir
            try {
                [IO.File]::WriteAllText((Join-Path $dir 'SECURITY_FINDINGS.md'), ($secHeader + $case.rows + "`n"))
                $rps = Invoke-Hook $ssPs '{}'; $rsh = Invoke-Hook $ssSh '{}'
                Assert ("$($rps.Err)".Trim() -eq '' -and "$($rsh.Err)".Trim() -eq '') "stderr not clean: ps1='$("$($rps.Err)".Trim())' sh='$("$($rsh.Err)".Trim())'"
                $hasPs = $rps.Out -match '\*\*Security:\*\*'; $hasSh = $rsh.Out -match '\*\*Security:\*\*'
                Assert (($hasPs -eq $case.expect) -and ($hasSh -eq $case.expect)) "security line present: expected=$($case.expect) ps1=$hasPs sh=$hasSh"
            } finally { Pop-Location; Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}

exit (Write-TestSummary 'TwinParity.Tests (.ps1 vs .sh)')
