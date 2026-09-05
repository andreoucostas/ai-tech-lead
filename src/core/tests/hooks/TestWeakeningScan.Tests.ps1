# The test-weakening advisory's contract.
#
# Two properties matter here and they pull against each other. It must REPORT when assertion-shaped
# lines are removed from a test file — an advisory that silently stops advising is worse than none,
# because nobody notices. And it must ALWAYS exit 0, on every path: the moment it can fail a run, a
# false positive on a legitimate refactor teaches people to bypass it, and the reason it is advisory
# in the first place is that a weakened assertion and a refactored one cannot be told apart by rule.
#
# The exit-code assertions below are therefore not ceremony. They are the property.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$scan = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\scripts')).Path 'test-weakening-scan.ps1'

function New-ScanRepo {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ("tw-scan-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $dir 'tests') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir 'src') -Force | Out-Null
    & git -C $dir init -q 2>&1 | Out-Null
    & git -C $dir config user.email 'test@example.invalid' 2>&1 | Out-Null
    & git -C $dir config user.name 'test' 2>&1 | Out-Null
    $body = "public class FooTests {`n  public void A(){`n    Assert.Equal(1,1);`n    Assert.True(true);`n    Assert.NotNull(this);`n  }`n}`n"
    [IO.File]::WriteAllText((Join-Path $dir 'tests/FooTests.cs'), $body)
    [IO.File]::WriteAllText((Join-Path $dir 'tests/Métric Test.Tests.ps1'), "Assert 1`nAssert 2`nAssert 3`n")
    [IO.File]::WriteAllText((Join-Path $dir 'src/Foo.cs'), "public class Foo {}`n")
    & git -C $dir add -A 2>&1 | Out-Null
    & git -C $dir commit -qm base 2>&1 | Out-Null
    return $dir
}

function Invoke-Scan {
    param([string]$Repo, [string[]]$Arguments = @())
    Push-Location $Repo
    try {
        $out = & (Get-Process -Id $PID).Path -NoProfile -File $scan @Arguments 2>&1
        return [pscustomobject]@{ Exit = $LASTEXITCODE; Text = ($out | ForEach-Object { "$_" }) -join "`n" }
    } finally { Pop-Location }
}

Reset-Tests

It 'reports when assertion-shaped lines are removed from a test file, and still exits 0' {
    $repo = New-ScanRepo
    try {
        [IO.File]::WriteAllText((Join-Path $repo 'tests/FooTests.cs'), "public class FooTests {`n  public void A(){`n    Assert.Equal(1,1);`n  }`n}`n")
        & git -C $repo add -A 2>&1 | Out-Null
        $r = Invoke-Scan $repo
        Assert ($r.Text -match 'FooTests\.cs') "the weakened file was not named: $($r.Text)"
        Assert ($r.Text -match 'net -2') "the net removal count was not reported: $($r.Text)"
        Assert ($r.Exit -eq 0) "an advisory must never fail a run, got exit $($r.Exit)"
    } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'stays silent when assertions are added' {
    $repo = New-ScanRepo
    try {
        [IO.File]::WriteAllText((Join-Path $repo 'tests/FooTests.cs'), "public class FooTests {`n  public void A(){`n    Assert.Equal(1,1);`n    Assert.True(true);`n    Assert.NotNull(this);`n    Assert.False(false);`n  }`n}`n")
        & git -C $repo add -A 2>&1 | Out-Null
        $r = Invoke-Scan $repo
        Assert ($r.Text -notmatch 'FooTests\.cs') "adding assertions must not be reported: $($r.Text)"
        Assert ($r.Exit -eq 0) "expected exit 0, got $($r.Exit)"
    } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'ignores non-test files' {
    $repo = New-ScanRepo
    try {
        [IO.File]::WriteAllText((Join-Path $repo 'src/Foo.cs'), "public class Foo { public int X; }`n")
        & git -C $repo add -A 2>&1 | Out-Null
        $r = Invoke-Scan $repo
        Assert ($r.Text -notmatch 'Foo\.cs') "a non-test file must not be reported: $($r.Text)"
        Assert ($r.Exit -eq 0) "expected exit 0, got $($r.Exit)"
    } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'says so plainly when nothing qualifies, and exits 0' {
    $repo = New-ScanRepo
    try {
        $r = Invoke-Scan $repo
        Assert ($r.Text -match 'nothing qualifies') "expected the no-signal line: $($r.Text)"
        Assert ($r.Exit -eq 0) "expected exit 0, got $($r.Exit)"
    } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'never describes itself as enforcement' {
    $text = [IO.File]::ReadAllText($scan, [Text.Encoding]::UTF8)
    Assert ($text -match 'not enforcement') 'the advisory must state that it is not enforcement'
    foreach ($claim in @('guarantees', 'prevents', 'blocks the commit')) {
        Assert ($text -notmatch [regex]::Escape($claim)) "the advisory overclaims with '$claim'"
    }
}

It 'scans a caller bundle without deleting it and rejects a mixed range shape' {
    $repo = New-ScanRepo
    $bundle = Join-Path ([IO.Path]::GetTempPath()) ('tw-bundle-' + [guid]::NewGuid().ToString('N'))
    try {
        [IO.File]::WriteAllText((Join-Path $repo 'tests/Métric Test.Tests.ps1'), "Assert 1`n")
        & git -C $repo add -A 2>&1 | Out-Null
        $builder = Join-Path (Split-Path -Parent $scan) 'review-scope.ps1'
        Push-Location $repo
        try { $buildOut = & (Get-Process -Id $PID).Path -NoProfile -File $builder -Mode Uncommitted -OutputPath $bundle 2>&1 | Out-String; $buildExit = $LASTEXITCODE }
        finally { Pop-Location }
        Assert ($buildExit -eq 0) "could not build caller scope: $buildOut"
        $r = Invoke-Scan $repo @('-ScopePath',$bundle)
        Assert ($r.Exit -eq 0 -and $r.Text -match 'Métric Test\.Tests\.ps1') "caller scope did not parse the non-ASCII spaced patch path: $($r.Exit) $($r.Text)"
        Assert (Test-Path -LiteralPath (Join-Path $bundle 'manifest.json') -PathType Leaf) 'scanner deleted caller-supplied bundle'
        $mixed = Invoke-Scan $repo @('-ScopePath',$bundle,'HEAD~1..HEAD')
        Assert ($mixed.Exit -eq 2 -and $mixed.Text -match 'INVALID.*cannot be combined') "mixed scope/range shape was accepted: $($mixed.Exit) $($mixed.Text)"
    } finally {
        Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $bundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'preserves exact two-dot and three-dot positional range behavior' {
    $repo = New-ScanRepo
    try {
        [IO.File]::WriteAllText((Join-Path $repo 'tests/FooTests.cs'), "public class FooTests {`n  public void A(){`n    Assert.Equal(1,1);`n  }`n}`n")
        & git -C $repo add -A 2>&1 | Out-Null
        & git -C $repo commit -qm weakened 2>&1 | Out-Null
        foreach ($range in @('HEAD~1..HEAD','HEAD~1...HEAD')) {
            $r = Invoke-Scan $repo @($range)
            Assert ($r.Exit -eq 0 -and $r.Text -match 'FooTests\.cs' -and $r.Text -match 'net -2') "positional $range did not inspect its frozen endpoints: $($r.Exit) $($r.Text)"
        }
    } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'passes a literal PathFile through private capture without broadening scope' {
    $repo = New-ScanRepo
    $pathFile = Join-Path ([IO.Path]::GetTempPath()) ('tw-paths-' + [guid]::NewGuid().ToString('N') + '.json')
    try {
        [IO.File]::WriteAllText((Join-Path $repo 'tests/FooTests.cs'), "public class FooTests {`n  public void A(){`n    Assert.Equal(1,1);`n  }`n}`n")
        [IO.File]::WriteAllText((Join-Path $repo 'src/Foo.cs'), "Assert.False(false);`n")
        & git -C $repo add -A 2>&1 | Out-Null
        [IO.File]::WriteAllText($pathFile, '["tests/FooTests.cs"]', [Text.UTF8Encoding]::new($false))
        $r = Invoke-Scan $repo @('-PathFile',$pathFile)
        Assert ($r.Exit -eq 0 -and $r.Text -match 'FooTests\.cs') "PathFile scan missed selected test: $($r.Exit) $($r.Text)"
        Assert ($r.Text -notmatch 'src/Foo\.cs') "PathFile scan broadened into unselected source: $($r.Text)"
    } finally {
        Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $pathFile -Force -ErrorAction SilentlyContinue
    }
}

exit (Write-TestSummary 'TestWeakeningScan.Tests (advisory contract)')
