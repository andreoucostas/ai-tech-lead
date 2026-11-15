# Direct contract tests for the CI-only case-count parity decision. Does not ship.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')

$subject = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path '.claude/scripts/assert-ci-case-parity.ps1'
$pairs = @(
    ,@('b219-case-counts-windows-meta-1', 'windows-meta-1-case-counts.txt')
    ,@('b219-case-counts-windows-meta-2', 'windows-meta-2-case-counts.txt')
    ,@('b219-case-counts-windows-meta-3', 'windows-meta-3-case-counts.txt')
    ,@('b219-case-counts-windows-hooks-dotnet', 'windows-hooks-dotnet-case-counts.txt')
    ,@('b219-case-counts-windows-hooks-angular', 'windows-hooks-angular-case-counts.txt')
    ,@('b219-case-counts-windows-hooks-monorepo', 'windows-hooks-monorepo-case-counts.txt')
)
$good = "Alpha.Tests.ps1`t2`nBeta.Tests.ps1`t3`nTOTAL`t5`n"
# The meta shards split the fixture's meta test directory (Alpha, Beta, Gamma) between them.
$metaGood = @("Alpha.Tests.ps1`t2`nTOTAL`t2`n", "Beta.Tests.ps1`t3`nTOTAL`t3`n", "Gamma.Tests.ps1`t1`nTOTAL`t1`n")

function New-ParityFixture {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('ci-case-parity-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($root) | Out-Null
    for ($i = 0; $i -lt $pairs.Count; $i++) {
        $dir = Join-Path $root $pairs[$i][0]
        [IO.Directory]::CreateDirectory($dir) | Out-Null
        $text = if ($i -lt $metaGood.Count) { $metaGood[$i] } else { $good }
        [IO.File]::WriteAllText((Join-Path $dir $pairs[$i][1]), $text, (New-Object Text.UTF8Encoding($false)))
    }
    # Outside the artifact root: the decision must not mistake it for an artifact.
    $meta = "$root-meta"
    [IO.Directory]::CreateDirectory($meta) | Out-Null
    foreach ($name in 'Alpha.Tests.ps1', 'Beta.Tests.ps1', 'Gamma.Tests.ps1', '_HookHarness.ps1') {
        [IO.File]::WriteAllText((Join-Path $meta $name), "exit 0`n", (New-Object Text.UTF8Encoding($true)))
    }
    return $root
}

function Remove-ParityFixture {
    param([string]$Root)
    Remove-Item -LiteralPath $Root, "$Root-meta" -Recurse -Force -ErrorAction SilentlyContinue
}

function Invoke-Decision {
    param([string]$Root)
    Invoke-RawProcess -FileName (Get-Process -Id $PID).Path -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $subject, '-ArtifactRoot', $Root, '-MetaTestRoot', "$Root-meta")
}

Reset-Tests

It 'six valid nonempty artifacts whose meta shards cover the meta test files pass' {
    $root = New-ParityFixture
    try {
        $r = Invoke-Decision $root
        Assert ($r.Exit -eq 0) "valid decision exit $($r.Exit): $($r.Out) $($r.Err)"
        Assert ($r.Out -match 'six nonempty, valid') 'valid decision omitted its checked cardinality'
        Assert ($r.Out -match 'each of the 3 meta test files exactly once') 'valid decision omitted its shard coverage'
    } finally { Remove-ParityFixture $root }
}

It 'a meta test file that ran in no shard is wrong' {
    $root = New-ParityFixture
    try {
        [IO.File]::WriteAllText((Join-Path "$root-meta" 'Delta.Tests.ps1'), "exit 0`n", (New-Object Text.UTF8Encoding($true)))
        $r = Invoke-Decision $root
        Assert ($r.Exit -eq 1) "unsharded meta file exit $($r.Exit): $($r.Out) $($r.Err)"
        Assert ($r.Out -match 'ran in no shard: Delta\.Tests\.ps1') 'unsharded meta file diagnostic did not name the file'
    } finally { Remove-ParityFixture $root }
}

It 'a meta test file that ran in two shards is wrong' {
    $root = New-ParityFixture
    try {
        [IO.File]::WriteAllText((Join-Path (Join-Path $root $pairs[1][0]) $pairs[1][1]), "Alpha.Tests.ps1`t2`nBeta.Tests.ps1`t3`nTOTAL`t5`n", (New-Object Text.UTF8Encoding($false)))
        $r = Invoke-Decision $root
        Assert ($r.Exit -eq 1) "twice-run meta file exit $($r.Exit): $($r.Out) $($r.Err)"
        Assert ($r.Out -match "meta suite 'Alpha\.Tests\.ps1' ran in both meta-1 and meta-2") 'twice-run diagnostic did not name the file and both shards'
    } finally { Remove-ParityFixture $root }
}

It 'a meta shard suite absent from the meta test files is wrong' {
    $root = New-ParityFixture
    try {
        Remove-Item -LiteralPath (Join-Path "$root-meta" 'Gamma.Tests.ps1') -Force
        $r = Invoke-Decision $root
        Assert ($r.Exit -eq 1) "foreign meta suite exit $($r.Exit): $($r.Out) $($r.Err)"
        Assert ($r.Out -match 'not in .*: Gamma\.Tests\.ps1') 'foreign meta suite diagnostic did not name the suite'
    } finally { Remove-ParityFixture $root }
}

It 'a missing artifact is wrong rather than CANT-VERIFY' {
    $root = New-ParityFixture
    try {
        Remove-Item -LiteralPath (Join-Path $root $pairs[5][0]) -Recurse -Force
        $r = Invoke-Decision $root
        Assert ($r.Exit -eq 1) "missing artifact exit $($r.Exit): $($r.Out) $($r.Err)"
        Assert ($r.Out -match 'expected exactly six') 'missing artifact diagnostic omitted exact cardinality'
    } finally { Remove-ParityFixture $root }
}

It 'an absent artifact root is reported as missing rather than unreadable' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('absent-ci-case-parity-' + [guid]::NewGuid().ToString('N'))
    $r = Invoke-Decision $root
    Assert ($r.Exit -eq 1) "absent root exit $($r.Exit): $($r.Out) $($r.Err)"
    Assert ($r.Out -match 'artifact root.*is missing') 'absent-root diagnostic did not say missing'
    Assert ($r.Err -notmatch 'CANT-VERIFY') 'absent root was misclassified as an IO failure'
}

It 'an extra artifact is rejected' {
    $root = New-ParityFixture
    try {
        [IO.Directory]::CreateDirectory((Join-Path $root 'b219-case-counts-extra')) | Out-Null
        $r = Invoke-Decision $root
        Assert ($r.Exit -eq 1) "extra artifact exit $($r.Exit): $($r.Out) $($r.Err)"
    } finally { Remove-ParityFixture $root }
}

It 'a zero-count manifest is rejected' {
    $root = New-ParityFixture
    try {
        $bad = "Alpha.Tests.ps1`t0`nTOTAL`t0`n"
        [IO.File]::WriteAllText((Join-Path (Join-Path $root $pairs[0][0]) $pairs[0][1]), $bad, (New-Object Text.UTF8Encoding($false)))
        $r = Invoke-Decision $root
        Assert ($r.Exit -eq 1) "zero-count manifest exit $($r.Exit): $($r.Out) $($r.Err)"
        Assert ($r.Out -match 'malformed suite row') 'zero-count diagnostic was not a manifest-shape failure'
    } finally { Remove-ParityFixture $root }
}

It 'an incorrect total is rejected' {
    $root = New-ParityFixture
    try {
        $bad = "Alpha.Tests.ps1`t2`nBeta.Tests.ps1`t3`nTOTAL`t4`n"
        [IO.File]::WriteAllText((Join-Path (Join-Path $root $pairs[1][0]) $pairs[1][1]), $bad, (New-Object Text.UTF8Encoding($false)))
        $r = Invoke-Decision $root
        Assert ($r.Exit -eq 1) "incorrect total exit $($r.Exit): $($r.Out) $($r.Err)"
        Assert ($r.Out -match 'incorrect TOTAL') 'incorrect-total diagnostic missing'
    } finally { Remove-ParityFixture $root }
}

It 'a readable empty manifest is wrong' {
    $root = New-ParityFixture
    try {
        [IO.File]::WriteAllBytes((Join-Path (Join-Path $root $pairs[3][0]) $pairs[3][1]), [byte[]]@())
        $r = Invoke-Decision $root
        Assert ($r.Exit -eq 1) "empty manifest exit $($r.Exit): $($r.Out) $($r.Err)"
        Assert ($r.Out -match 'is empty') 'empty diagnostic missing'
    } finally { Remove-ParityFixture $root }
}

It 'a directory occupying the manifest leaf is wrong rather than CANT-VERIFY' {
    $root = New-ParityFixture
    $path = Join-Path (Join-Path $root $pairs[3][0]) $pairs[3][1]
    try {
        Remove-Item -LiteralPath $path -Force
        [IO.Directory]::CreateDirectory($path) | Out-Null
        $r = Invoke-Decision $root
        Assert ($r.Exit -eq 1) "manifest-directory exit $($r.Exit): $($r.Out) $($r.Err)"
        Assert ($r.Out -match 'contains a directory where manifest') 'manifest-directory diagnostic omitted the wrong type'
        Assert ($r.Err -notmatch 'CANT-VERIFY') 'manifest-directory was misclassified as unreadable'
    } finally { Remove-ParityFixture $root }
}

It 'an unreadable manifest is CANT-VERIFY rather than wrong or empty' {
    $root = New-ParityFixture
    $path = Join-Path (Join-Path $root $pairs[0][0]) $pairs[0][1]
    $lock = $null
    try {
        $lock = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        $r = Invoke-Decision $root
        Assert ($r.Exit -eq 3) "unreadable manifest exit $($r.Exit): $($r.Out) $($r.Err)"
        Assert ($r.Err -match 'CANT-VERIFY.*could not read') 'unreadable diagnostic did not say CANT-VERIFY'
        Assert ($r.Out -notmatch 'WRONG|empty|differ') 'unreadable input was misclassified as artifact content'
    } finally {
        if ($lock) { $lock.Dispose() }
        Remove-ParityFixture $root
    }
}

exit (Write-TestSummary 'CiCaseParity.Tests')
