# Direct contract tests for the CI-only case-count parity decision. Does not ship.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')

$subject = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path '.claude/scripts/assert-ci-case-parity.ps1'
$pairs = @(
    ,@('b219-case-counts-windows', 'windows-case-counts.txt', 'b219-case-counts-windows-ps51', 'windows-ps51-case-counts.txt')
    ,@('b219-case-counts-windows-hooks-dotnet', 'windows-hooks-dotnet-case-counts.txt', 'b219-case-counts-windows-hooks-ps51-dotnet', 'windows-hooks-ps51-dotnet-case-counts.txt')
    ,@('b219-case-counts-windows-hooks-angular', 'windows-hooks-angular-case-counts.txt', 'b219-case-counts-windows-hooks-ps51-angular', 'windows-hooks-ps51-angular-case-counts.txt')
    ,@('b219-case-counts-windows-hooks-monorepo', 'windows-hooks-monorepo-case-counts.txt', 'b219-case-counts-windows-hooks-ps51-monorepo', 'windows-hooks-ps51-monorepo-case-counts.txt')
)
$good = "Alpha.Tests.ps1`t2`nBeta.Tests.ps1`t3`nTOTAL`t5`n"

function New-ParityFixture {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('ci-case-parity-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($root) | Out-Null
    foreach ($pair in $pairs) {
        foreach ($offset in 0, 2) {
            $dir = Join-Path $root $pair[$offset]
            [IO.Directory]::CreateDirectory($dir) | Out-Null
            [IO.File]::WriteAllText((Join-Path $dir $pair[$offset + 1]), $good, (New-Object Text.UTF8Encoding($false)))
        }
    }
    return $root
}

function Invoke-Decision {
    param([string]$Root)
    Invoke-RawProcess -FileName (Get-Process -Id $PID).Path -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $subject, '-ArtifactRoot', $Root)
}

Reset-Tests

It 'eight valid nonempty artifacts and four byte-equal pairs pass' {
    $root = New-ParityFixture
    try {
        $r = Invoke-Decision $root
        Assert ($r.Exit -eq 0) "valid decision exit $($r.Exit): $($r.Out) $($r.Err)"
        Assert ($r.Out -match 'four nonempty, valid') 'valid decision omitted its checked cardinality'
    } finally { Remove-Item -LiteralPath $root -Recurse -Force }
}

It 'a missing artifact is wrong rather than CANT-VERIFY' {
    $root = New-ParityFixture
    try {
        Remove-Item -LiteralPath (Join-Path $root $pairs[3][2]) -Recurse -Force
        $r = Invoke-Decision $root
        Assert ($r.Exit -eq 1) "missing artifact exit $($r.Exit): $($r.Out) $($r.Err)"
        Assert ($r.Out -match 'expected exactly eight') 'missing artifact diagnostic omitted exact cardinality'
    } finally { Remove-Item -LiteralPath $root -Recurse -Force }
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
    } finally { Remove-Item -LiteralPath $root -Recurse -Force }
}

It 'two identical zero-count manifests cannot pass by equality' {
    $root = New-ParityFixture
    try {
        $bad = "Alpha.Tests.ps1`t0`nTOTAL`t0`n"
        [IO.File]::WriteAllText((Join-Path (Join-Path $root $pairs[0][0]) $pairs[0][1]), $bad, (New-Object Text.UTF8Encoding($false)))
        [IO.File]::WriteAllText((Join-Path (Join-Path $root $pairs[0][2]) $pairs[0][3]), $bad, (New-Object Text.UTF8Encoding($false)))
        $r = Invoke-Decision $root
        Assert ($r.Exit -eq 1) "identical malformed manifests exit $($r.Exit): $($r.Out) $($r.Err)"
        Assert ($r.Out -match 'malformed suite row') 'zero-count diagnostic was not a manifest-shape failure'
    } finally { Remove-Item -LiteralPath $root -Recurse -Force }
}

It 'an incorrect total is rejected' {
    $root = New-ParityFixture
    try {
        $bad = "Alpha.Tests.ps1`t2`nBeta.Tests.ps1`t3`nTOTAL`t4`n"
        [IO.File]::WriteAllText((Join-Path (Join-Path $root $pairs[1][0]) $pairs[1][1]), $bad, (New-Object Text.UTF8Encoding($false)))
        $r = Invoke-Decision $root
        Assert ($r.Exit -eq 1) "incorrect total exit $($r.Exit): $($r.Out) $($r.Err)"
        Assert ($r.Out -match 'incorrect TOTAL') 'incorrect-total diagnostic missing'
    } finally { Remove-Item -LiteralPath $root -Recurse -Force }
}

It 'a valid but unequal host pair is rejected' {
    $root = New-ParityFixture
    try {
        $different = "Alpha.Tests.ps1`t2`nBeta.Tests.ps1`t4`nTOTAL`t6`n"
        [IO.File]::WriteAllText((Join-Path (Join-Path $root $pairs[2][2]) $pairs[2][3]), $different, (New-Object Text.UTF8Encoding($false)))
        $r = Invoke-Decision $root
        Assert ($r.Exit -eq 1) "unequal pair exit $($r.Exit): $($r.Out) $($r.Err)"
        Assert ($r.Out -match "'angular'.*differ") 'unequal-pair diagnostic omitted the pair'
    } finally { Remove-Item -LiteralPath $root -Recurse -Force }
}

It 'a readable empty manifest is wrong' {
    $root = New-ParityFixture
    try {
        [IO.File]::WriteAllBytes((Join-Path (Join-Path $root $pairs[3][0]) $pairs[3][1]), [byte[]]@())
        $r = Invoke-Decision $root
        Assert ($r.Exit -eq 1) "empty manifest exit $($r.Exit): $($r.Out) $($r.Err)"
        Assert ($r.Out -match 'is empty') 'empty diagnostic missing'
    } finally { Remove-Item -LiteralPath $root -Recurse -Force }
}

It 'a directory occupying the manifest leaf is wrong rather than CANT-VERIFY' {
    $root = New-ParityFixture
    $path = Join-Path (Join-Path $root $pairs[3][2]) $pairs[3][3]
    try {
        Remove-Item -LiteralPath $path -Force
        [IO.Directory]::CreateDirectory($path) | Out-Null
        $r = Invoke-Decision $root
        Assert ($r.Exit -eq 1) "manifest-directory exit $($r.Exit): $($r.Out) $($r.Err)"
        Assert ($r.Out -match 'contains a directory where manifest') 'manifest-directory diagnostic omitted the wrong type'
        Assert ($r.Err -notmatch 'CANT-VERIFY') 'manifest-directory was misclassified as unreadable'
    } finally { Remove-Item -LiteralPath $root -Recurse -Force }
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
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}

exit (Write-TestSummary 'CiCaseParity.Tests')
