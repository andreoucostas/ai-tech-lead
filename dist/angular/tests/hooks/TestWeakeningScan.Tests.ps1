# The test-weakening advisory's contract.
#
# Two properties matter here and they pull against each other. It must REPORT when assertion-shaped
# lines are removed from a test file — an advisory that silently stops advising is worse than none,
# because nobody notices. Findings and valid no-signal scans exit 0; malformed input and inability
# to examine an immutable bundle are nonzero, so a host problem cannot become a false green.
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
        [IO.File]::WriteAllText((Join-Path $repo 'tests/Métric Test.Tests.ps1'), "Assert 1`n")
        & git -C $repo add -A 2>&1 | Out-Null
        $unfiltered = Invoke-Scan $repo
        Assert ($unfiltered.Exit -eq 0 -and $unfiltered.Text -match 'Métric Test\.Tests\.ps1') "unfiltered control did not report the other qualifying assertion removal: $($unfiltered.Exit) $($unfiltered.Text)"
        [IO.File]::WriteAllText($pathFile, '["tests/FooTests.cs"]', [Text.UTF8Encoding]::new($false))
        $r = Invoke-Scan $repo @('-PathFile',$pathFile)
        Assert ($r.Exit -eq 0 -and $r.Text -match 'FooTests\.cs') "PathFile scan missed selected test: $($r.Exit) $($r.Text)"
        Assert ($r.Text -notmatch 'Métric Test\.Tests\.ps1') "PathFile scan broadened into another qualifying assertion-removal test: $($r.Text)"
    } finally {
        Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $pathFile -Force -ErrorAction SilentlyContinue
    }
}

It 'requires pathFilter to be a string array and accepts an explicit empty array' {
    $repo = New-ScanRepo
    $bundle = Join-Path ([IO.Path]::GetTempPath()) ('tw-path-filter-schema-' + [guid]::NewGuid().ToString('N'))
    try {
        $builder = Join-Path (Split-Path -Parent $scan) 'review-scope.ps1'
        Push-Location $repo
        try { $buildOut = & (Get-Process -Id $PID).Path -NoProfile -File $builder -Mode Uncommitted -OutputPath $bundle 2>&1 | Out-String; $buildExit = $LASTEXITCODE }
        finally { Pop-Location }
        Assert ($buildExit -eq 0) "could not build schema fixture: $buildOut"
        $manifestPath = Join-Path $bundle 'manifest.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $manifest.pathFilter = $null
        [IO.File]::WriteAllText($manifestPath, (($manifest | ConvertTo-Json -Depth 8 -Compress) + "`n"), [Text.UTF8Encoding]::new($false))
        $nullFilter = Invoke-Scan $repo @('-ScopePath',$bundle)
        Assert ($nullFilter.Exit -eq 2 -and $nullFilter.Text -match '(?i)pathFilter|string array') "null pathFilter was not invalid input: $($nullFilter.Exit) $($nullFilter.Text)"
        $manifest.pathFilter = 'tests/FooTests.cs'
        [IO.File]::WriteAllText($manifestPath, (($manifest | ConvertTo-Json -Depth 8 -Compress) + "`n"), [Text.UTF8Encoding]::new($false))
        $scalarFilter = Invoke-Scan $repo @('-ScopePath',$bundle)
        Assert ($scalarFilter.Exit -eq 2 -and $scalarFilter.Text -match '(?i)pathFilter|string array|incomplete shape') "scalar pathFilter was accepted: $($scalarFilter.Exit) $($scalarFilter.Text)"
        $manifest.pathFilter = @()
        [IO.File]::WriteAllText($manifestPath, (($manifest | ConvertTo-Json -Depth 8 -Compress) + "`n"), [Text.UTF8Encoding]::new($false))
        $emptyFilter = Invoke-Scan $repo @('-ScopePath',$bundle)
        Assert ($emptyFilter.Exit -eq 0) "explicit empty pathFilter was rejected: $($emptyFilter.Exit) $($emptyFilter.Text)"
    } finally { Remove-Item -LiteralPath $repo,$bundle -Recurse -Force -ErrorAction SilentlyContinue }
}

exit (Write-TestSummary 'TestWeakeningScan.Tests (advisory contract)')
