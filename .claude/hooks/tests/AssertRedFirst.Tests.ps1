# Planted-defect tests for .claude/scripts/assert-red-first.ps1. Does NOT ship.
#
# Subject: the mechanical red-first checker itself. Hermetic -- builds its OWN scratch git repo
# (a stub harness, never a copy of the real _HookHarness.ps1/Invoke-HookTests.ps1) so this suite
# never depends on this repo's own history. The subject's own contract needs exactly three
# properties from whatever it runs: a plain PowerShell file printing `[ok]/[FAIL]/[skip] <name>`
# lines and exiting with the failing-case COUNT -- so the stub reproduces those three and nothing
# else (no manifest check, no parallelism).
#
# Fixture history (linear, four commits):
#   A "base"              -- _Stub.ps1 + Sample.Tests.ps1 with one always-passing case.
#   B "feature"           -- adds feature.ps1 + six more Sample.Tests.ps1 cases + OnlyDeclared.Tests.ps1;
#                             message carries a valid Red-first trailer for the genuine case.
#   C "malformed trailer"  -- trivial follow-up; message mentions "red-first" but doesn't parse.
#   D "no trailer"        -- empty commit; message says nothing about red-first at all.
#
#   pwsh -NoProfile -File .claude/hooks/tests/AssertRedFirst.Tests.ps1
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$subject  = Join-Path $repoRoot '.claude/scripts/assert-red-first.ps1'
Reset-Tests
$scratch = @()

function New-Fixture {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('red-first-fixture-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $script:scratch += $dir
    git -C $dir init -q
    git -C $dir config user.email 'test@example.invalid'
    git -C $dir config user.name 'test'
    git -C $dir config commit.gpgsign false
    git -C $dir config tag.gpgsign false

    $testsDir = Join-Path $dir '.claude/hooks/tests'
    New-Item -ItemType Directory -Path $testsDir -Force | Out-Null

    # A minimal STUB harness -- not the real one -- matching only the three contract properties
    # assert-red-first.ps1 depends on: It/Assert/Reset-Tests, and Write-TestSummary printing
    # `[ok]/[FAIL]/[skip] <name>` lines and returning the failing-case count.
    $stub = @'
$script:Tests = [System.Collections.Generic.List[object]]::new()
function Reset-Tests { $script:Tests.Clear() }
function It { param([string]$Name,[scriptblock]$Body)
    try { & $Body; $script:Tests.Add([pscustomobject]@{Name=$Name;State='PASS';Msg=''}) }
    catch { $script:Tests.Add([pscustomobject]@{Name=$Name;State='FAIL';Msg=$_.Exception.Message}) } }
function Skip { param([string]$Name,[string]$Why) $script:Tests.Add([pscustomobject]@{Name=$Name;State='SKIP';Msg=$Why}) }
function Assert { param([bool]$Cond,[string]$Msg) if (-not $Cond) { throw $Msg } }
function Write-TestSummary { param([string]$Title)
    $fail = 0
    foreach ($t in $script:Tests) {
        $mark = switch ($t.State) { 'PASS' {'[ok]'} 'FAIL' {'[FAIL]'; $fail++} 'SKIP' {'[skip]'} }
        Write-Host ("{0} {1}{2}" -f $mark, $t.Name, $(if ($t.Msg) {" -- $($t.Msg)"} else {''}))
    }
    return $fail
}
'@
    [IO.File]::WriteAllText((Join-Path $testsDir '_Stub.ps1'), $stub, [Text.UTF8Encoding]::new($true))

    [IO.File]::WriteAllText((Join-Path $testsDir 'Sample.Tests.ps1'), @'
. (Join-Path $PSScriptRoot '_Stub.ps1')
Reset-Tests
It 'the baseline case is unaffected' { Assert $true 'unreachable' }
exit (Write-TestSummary 'Sample')
'@, [Text.UTF8Encoding]::new($true))

    git -C $dir add -A | Out-Null
    git -C $dir commit -qm 'base' | Out-Null
    $a = (git -C $dir rev-parse HEAD).Trim()

    # ---- commit B: "feature" -----------------------------------------------------------------
    [IO.File]::WriteAllText((Join-Path $dir 'feature.ps1'), "function Get-FeatureValue { 'the-documented-value' }`n", [Text.UTF8Encoding]::new($true))
    [IO.File]::WriteAllText((Join-Path $testsDir 'Sample.Tests.ps1'), @'
. (Join-Path $PSScriptRoot '_Stub.ps1')
. (Join-Path $PSScriptRoot '..\..\..\feature.ps1')
Reset-Tests
It 'the baseline case is unaffected' { Assert $true 'unreachable' }
It 'the feature returns the documented value' { Assert ((Get-FeatureValue) -eq 'the-documented-value') 'feature.ps1 missing or wrong' }
It 'the feature returns the documented value under load' { Assert $true 'trivial, does not depend on the feature' }
It 'an unrelated case that always fails' { Assert $false 'always fails, by design' }
It 'an UNWAIVED failure still blocks -- the mechanism must not fail open by default' { Assert ((Get-FeatureValue) -eq 'the-documented-value') 'feature.ps1 missing or wrong' }
It 'the shared outcome' { Assert $true 'dup A' }
It 'the shared outcome' { Assert $true 'dup B' }
exit (Write-TestSummary 'Sample')
'@, [Text.UTF8Encoding]::new($true))
    [IO.File]::WriteAllText((Join-Path $testsDir 'OnlyDeclared.Tests.ps1'), @'
. (Join-Path $PSScriptRoot '_Stub.ps1')
. (Join-Path $PSScriptRoot '..\..\..\feature.ps1')
Reset-Tests
It 'the only declared case in this file' { Assert ((Get-FeatureValue) -eq 'the-documented-value') 'feature.ps1 missing or wrong' }
exit (Write-TestSummary 'OnlyDeclared')
'@, [Text.UTF8Encoding]::new($true))
    git -C $dir add -A | Out-Null
    $msgB = Join-Path $dir '.msgB.txt'
    [IO.File]::WriteAllText($msgB, "feature`n`nRed-first: .claude/hooks/tests/Sample.Tests.ps1::the feature returns the documented value`n", [Text.UTF8Encoding]::new($false))
    git -C $dir commit -qF $msgB | Out-Null
    Remove-Item -LiteralPath $msgB -Force
    $b = (git -C $dir rev-parse HEAD).Trim()

    # ---- commit C: mentions "red-first" but does not parse -----------------------------------
    Add-Content -LiteralPath (Join-Path $testsDir 'Sample.Tests.ps1') -Value '# trivial, behaviour-inert comment'
    git -C $dir add -A | Out-Null
    $msgC = Join-Path $dir '.msgC.txt'
    [IO.File]::WriteAllText($msgC, "malformed trailer`n`nred-first oops no colon or case name`n", [Text.UTF8Encoding]::new($false))
    git -C $dir commit -qF $msgC | Out-Null
    Remove-Item -LiteralPath $msgC -Force
    $c = (git -C $dir rev-parse HEAD).Trim()

    # ---- commit D: no mention of red-first at all ---------------------------------------------
    git -C $dir commit -q --allow-empty -m 'chore: no-op, nothing declared here' | Out-Null
    $dd = (git -C $dir rev-parse HEAD).Trim()

    return [pscustomobject]@{ Dir = $dir; A = $a; B = $b; C = $c; D = $dd }
}

function Invoke-Subject {
    param([string]$RepoDir, [string]$Commit, [string[]]$CaseArgs)
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $subject, '-RepoRoot', $RepoDir, '-Commit', $Commit)
    foreach ($c in $CaseArgs) { $argList += @('-Case', $c) }
    $ef = [IO.Path]::GetTempFileName()
    try {
        $out = & (Get-Process -Id $PID).Path @argList 2>$ef
        $code = $LASTEXITCODE
        $err = [IO.File]::ReadAllText($ef)
        return [pscustomobject]@{ Exit = $code; Out = (($out -join "`n") + "`n" + $err) }
    } finally { if (Test-Path -LiteralPath $ef) { Remove-Item -LiteralPath $ef -Force } }
}

try {
    $fx = New-Fixture

    It 'the fixture builds a linear four-commit history with the declared scenarios present' {
        # Liveness/control case for THIS file's own dogfooding: it must stay [ok] on a parent tree
        # where assert-red-first.ps1 itself does not exist yet, so it never calls the subject.
        foreach ($sha in @($fx.A, $fx.B, $fx.C, $fx.D)) {
            Assert ($sha -match '^[0-9a-f]{40}$') "fixture commit sha looks wrong: $sha"
        }
        Assert ($fx.A -ne $fx.B -and $fx.B -ne $fx.C -and $fx.C -ne $fx.D) 'fixture commits collapsed'
    }

    It 'a genuine red-first case exits 0 via the commit-message trailer, and prints the parent failure reason' {
        $r = Invoke-Subject -RepoDir $fx.Dir -Commit $fx.B -CaseArgs @()
        Assert ($r.Exit -eq 0) "expected EXIT=0, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'RED_FIRST PASS declared=1 red_on_parent=1 green_on_commit=1') "verdict line missing/wrong: $($r.Out)"
        Assert ($r.Out -match '\[FAIL\] the feature returns the documented value') "parent-side failure reason not printed verbatim: $($r.Out)"
    }

    It 'a case name containing " -- " is matched exactly, not truncated' {
        $r = Invoke-Subject -RepoDir $fx.Dir -Commit $fx.B -CaseArgs @('.claude/hooks/tests/Sample.Tests.ps1::an UNWAIVED failure still blocks -- the mechanism must not fail open by default')
        Assert ($r.Exit -eq 0) "expected EXIT=0, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'RED_FIRST PASS declared=1') "dash-named case not resolved correctly: $($r.Out)"
    }

    It 'a planted inert case that also passes on the parent is reported WRONG, naming it' {
        $r = Invoke-Subject -RepoDir $fx.Dir -Commit $fx.B -CaseArgs @('.claude/hooks/tests/Sample.Tests.ps1::the feature returns the documented value under load')
        Assert ($r.Exit -eq 1) "expected EXIT=1, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'passed on the parent \(inert, not red-first\)') "inert case not named as such: $($r.Out)"
        Assert ($r.Out -match 'RED_FIRST WRONG') "verdict line missing: $($r.Out)"
    }

    It 'declaring only the genuine case still exits 0 although an unrelated case fails on both trees (exit-domain collision)' {
        # Sample.Tests.ps1's OWN exit code (Write-TestSummary's failing-case count) is non-zero on
        # BOTH trees here (the always-failing case, plus the still-undeclared dash-named case fails
        # on the parent too) -- proving the verdict comes from the parsed line, not that count.
        $r = Invoke-Subject -RepoDir $fx.Dir -Commit $fx.B -CaseArgs @('.claude/hooks/tests/Sample.Tests.ps1::the feature returns the documented value')
        Assert ($r.Exit -eq 0) "expected EXIT=0 despite the wrapped file's own non-zero exit code, got $($r.Exit): $($r.Out)"
    }

    It 'a duplicate case name is refused as ambiguous' {
        $r = Invoke-Subject -RepoDir $fx.Dir -Commit $fx.B -CaseArgs @('.claude/hooks/tests/Sample.Tests.ps1::the shared outcome')
        Assert ($r.Exit -eq 2) "expected EXIT=2, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'ambiguous \(duplicate case name\?\)') "duplicate name not flagged as ambiguous: $($r.Out)"
    }

    It 'a file with only the declared case fails the liveness control' {
        $r = Invoke-Subject -RepoDir $fx.Dir -Commit $fx.B -CaseArgs @('.claude/hooks/tests/OnlyDeclared.Tests.ps1::the only declared case in this file')
        Assert ($r.Exit -eq 2) "expected EXIT=2, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'no live non-declared case is \[ok\] on the parent') "liveness refusal not reported: $($r.Out)"
    }

    It 'a declared case name absent from either tree is refused' {
        $r = Invoke-Subject -RepoDir $fx.Dir -Commit $fx.B -CaseArgs @('.claude/hooks/tests/Sample.Tests.ps1::this case does not exist')
        Assert ($r.Exit -eq 2) "expected EXIT=2, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match "not found in .claude/hooks/tests/Sample.Tests.ps1") "not-found case not reported: $($r.Out)"
    }

    It 'an unparsable Red-first-like trailer line is refused, quoting it' {
        $r = Invoke-Subject -RepoDir $fx.Dir -Commit $fx.C -CaseArgs @()
        Assert ($r.Exit -eq 2) "expected EXIT=2, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'unparsable Red-first trailer line') "malformed trailer not refused: $($r.Out)"
        Assert ($r.Out -match 'red-first oops no colon or case name') "the offending line was not quoted: $($r.Out)"
    }

    It 'no Red-first trailers and no -Case is refused' {
        $r = Invoke-Subject -RepoDir $fx.Dir -Commit $fx.D -CaseArgs @()
        Assert ($r.Exit -eq 2) "expected EXIT=2, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'no Red-first trailers and no -Case given') "empty-declaration refusal not reported: $($r.Out)"
    }

    It 'a root commit with no parent is refused' {
        $r = Invoke-Subject -RepoDir $fx.Dir -Commit $fx.A -CaseArgs @('.claude/hooks/tests/Sample.Tests.ps1::the baseline case is unaffected')
        Assert ($r.Exit -eq 2) "expected EXIT=2, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'no resolvable parent') "root-commit refusal not reported: $($r.Out)"
    }
} finally {
    foreach ($p in $scratch) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue }
}

exit (Write-TestSummary 'AssertRedFirst.Tests (mechanical red-first checker)')
