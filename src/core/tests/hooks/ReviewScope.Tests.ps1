# Immutable review-scope bundle contract. These are real process-boundary checks against a scratch
# Git repository; they do not treat manifest prose or a copied implementation as proof.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$scripts = (Resolve-Path (Join-Path $PSScriptRoot '..\..\scripts')).Path
$builder = Join-Path $scripts 'review-scope.ps1'
$scanner = Join-Path $scripts 'test-weakening-scan.ps1'

function New-ReviewRepo {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('review-scope-repo-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $root 'tests') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root 'src') -Force | Out-Null
    & git -C $root init -q 2>&1 | Out-Null
    & git -C $root config user.email 'review-scope@example.invalid' 2>&1 | Out-Null
    & git -C $root config user.name 'review-scope' 2>&1 | Out-Null
    [IO.File]::WriteAllText((Join-Path $root '.gitignore'), "*.ignored`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $root 'tests/Foo.Tests.ps1'), "Assert 1`nAssert 2`nAssert 3`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $root 'tests/Delete.Tests.ps1'), "Assert 'delete'`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $root 'src/Other.cs'), "public class Other {}`n", [Text.UTF8Encoding]::new($false))
    & git -C $root add -A 2>&1 | Out-Null
    & git -C $root commit -qm base 2>&1 | Out-Null
    return $root
}

function New-BundlePath {
    return (Join-Path ([IO.Path]::GetTempPath()) ('review-scope-bundle-' + [guid]::NewGuid().ToString('N')))
}

function Invoke-AtRepo {
    param([string]$Repo, [string]$Script, [string[]]$Arguments)
    Push-Location $Repo
    try {
        $output = @(& (Get-PsExe) -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Script @Arguments 2>&1 | ForEach-Object { "$_" })
        return [pscustomobject]@{ Exit = [int]$LASTEXITCODE; Text = ($output -join "`n") }
    } finally { Pop-Location }
}

function Read-Manifest {
    param([string]$Bundle)
    return ([IO.File]::ReadAllText((Join-Path $Bundle 'manifest.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json)
}

function New-PathFile {
    param([string[]]$Paths)
    $path = Join-Path ([IO.Path]::GetTempPath()) ('review-scope-paths-' + [guid]::NewGuid().ToString('N') + '.json')
    [IO.File]::WriteAllText($path, (ConvertTo-Json -InputObject @($Paths) -Compress), [Text.UTF8Encoding]::new($false))
    return $path
}

Reset-Tests

It 'captures cancelling staged and unstaged layers plus nonignored untracked bytes separately' {
    $repo = New-ReviewRepo; $bundle = New-BundlePath
    try {
        [IO.File]::WriteAllText((Join-Path $repo 'tests/Foo.Tests.ps1'), "Assert 1`nAssert 3`n", [Text.UTF8Encoding]::new($false))
        & git -C $repo add -- 'tests/Foo.Tests.ps1' 2>&1 | Out-Null
        [IO.File]::WriteAllText((Join-Path $repo 'tests/Foo.Tests.ps1'), "Assert 1`nAssert 2`nAssert 3`n", [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $repo 'tests/New Tests.ps1'), "Assert 'new'`n", [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $repo 'secret.ignored'), 'ignored', [Text.UTF8Encoding]::new($false))
        $result = Invoke-AtRepo $repo $builder @('-Mode','Uncommitted','-OutputPath',$bundle)
        Assert ($result.Exit -eq 0) "capture failed: $($result.Text)"
        $manifest = Read-Manifest $bundle
        Assert ((@($manifest.selection | Where-Object { $_.path -eq 'tests/Foo.Tests.ps1' }).layer -join ',') -eq 'staged,unstaged') 'cancelling tracked layers were collapsed'
        Assert (@($manifest.selection | Where-Object { $_.path -eq 'tests/New Tests.ps1' -and $_.layer -eq 'untracked' }).Count -eq 1) 'nonignored untracked file was not captured'
        Assert (@($manifest.selection | Where-Object { $_.path -eq 'secret.ignored' }).Count -eq 0) 'ignored file entered the bundle'
        Assert ([IO.File]::ReadAllText((Join-Path $bundle 'staged.patch')).Contains('-Assert 2')) 'staged removal bytes absent'
        Assert ([IO.File]::ReadAllText((Join-Path $bundle 'unstaged.patch')).Contains('+Assert 2')) 'unstaged restoration bytes absent'
        Assert ([IO.File]::ReadAllText((Join-Path $bundle 'untracked/tests/New Tests.ps1')).Contains("Assert 'new'")) 'untracked bytes changed'
    } finally {
        Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $bundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'records rename and deletion layers without losing their patch bytes' {
    $repo = New-ReviewRepo; $bundle = New-BundlePath
    try {
        & git -C $repo mv -- 'tests/Foo.Tests.ps1' 'tests/Renamed Tests.ps1' 2>&1 | Out-Null
        Remove-Item -LiteralPath (Join-Path $repo 'tests/Delete.Tests.ps1') -Force
        & git -C $repo add -A 2>&1 | Out-Null
        $result = Invoke-AtRepo $repo $builder @('-Mode','Uncommitted','-OutputPath',$bundle)
        Assert ($result.Exit -eq 0) "rename/delete capture failed: $($result.Text)"
        $staged = @(Read-Manifest $bundle).layers | Where-Object name -eq staged
        Assert (@($staged.renames).Count -gt 0) 'rename layer was not recorded'
        Assert (@($staged.deletions) -contains 'tests/Delete.Tests.ps1') 'deletion layer was not recorded'
        $patch = [IO.File]::ReadAllText((Join-Path $bundle 'staged.patch'))
        Assert ($patch.Contains('similarity index') -and $patch.Contains('deleted file mode')) 'rename/delete patch bytes absent'
    } finally {
        Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $bundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'applies a literal JSON path filter including spaces and produces identical repeat snapshots' {
    $repo = New-ReviewRepo; $one = New-BundlePath; $two = New-BundlePath; $paths = $null
    try {
        [IO.File]::WriteAllText((Join-Path $repo 'tests/Space Tests.ps1'), "Assert 1`n", [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $repo 'src/Other.cs'), "changed`n", [Text.UTF8Encoding]::new($false))
        $paths = New-PathFile @('tests/Space Tests.ps1')
        $r1 = Invoke-AtRepo $repo $builder @('-Mode','Uncommitted','-OutputPath',$one,'-PathFile',$paths)
        $r2 = Invoke-AtRepo $repo $builder @('-Mode','Uncommitted','-OutputPath',$two,'-PathFile',$paths)
        Assert ($r1.Exit -eq 0 -and $r2.Exit -eq 0) "filtered captures failed: $($r1.Text) / $($r2.Text)"
        Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $one 'manifest.json'))) -ceq [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $two 'manifest.json')))) 'unchanged manifests differ by ambient path/time'
        foreach ($artifact in @(Read-Manifest $one).artifacts) {
            $left = [IO.File]::ReadAllBytes((Join-Path $one $artifact.path))
            $right = [IO.File]::ReadAllBytes((Join-Path $two $artifact.path))
            Assert ([Convert]::ToBase64String($left) -ceq [Convert]::ToBase64String($right)) "repeat artifact differs: $($artifact.path)"
        }
        Assert (@((Read-Manifest $one).selection | Where-Object { $_.path -eq 'src/Other.cs' }).Count -eq 0) 'literal filter included another changed path'
    } finally {
        Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $one -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $two -Recurse -Force -ErrorAction SilentlyContinue
        if ($paths) { Remove-Item -LiteralPath $paths -Force -ErrorAction SilentlyContinue }
    }
}

It 'does not refresh or rewrite the Git index for a timestamp-only worktree observation' {
    $repo = New-ReviewRepo; $bundle = New-BundlePath
    try {
        $tracked = Join-Path $repo 'tests/Foo.Tests.ps1'
        [IO.File]::SetLastWriteTimeUtc($tracked, [DateTime]::UtcNow.AddMinutes(2))
        $indexPath = Join-Path $repo '.git/index'
        $before = [Convert]::ToBase64String([IO.File]::ReadAllBytes($indexPath))
        $result = Invoke-AtRepo $repo $builder @('-Mode','Uncommitted','-OutputPath',$bundle)
        $after = [Convert]::ToBase64String([IO.File]::ReadAllBytes($indexPath))
        Assert ($result.Exit -eq 0) "timestamp-only capture failed: $($result.Text)"
        Assert ($after -ceq $before) 'review capture refreshed or rewrote the repository index'
    } finally {
        Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $bundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'freezes two-dot and three-dot endpoint semantics and rejects a bad ref' {
    $repo = New-ReviewRepo; $two = New-BundlePath; $three = New-BundlePath; $bad = New-BundlePath
    try {
        [IO.File]::WriteAllText((Join-Path $repo 'tests/Foo.Tests.ps1'), "Assert 1`n", [Text.UTF8Encoding]::new($false))
        & git -C $repo add -A 2>&1 | Out-Null; & git -C $repo commit -qm head 2>&1 | Out-Null
        $r2 = Invoke-AtRepo $repo $builder @('-Mode','Range','-RangeKind','TwoDot','-Base','HEAD~1','-Head','HEAD','-OutputPath',$two)
        $r3 = Invoke-AtRepo $repo $builder @('-Mode','Range','-RangeKind','ThreeDot','-Base','HEAD~1','-Head','HEAD','-OutputPath',$three)
        Assert ($r2.Exit -eq 0 -and $r3.Exit -eq 0) "range captures failed: $($r2.Text) / $($r3.Text)"
        $m2 = Read-Manifest $two; $m3 = Read-Manifest $three
        Assert ($m2.rangeKind -eq 'TwoDot' -and $m3.rangeKind -eq 'ThreeDot') 'range kind not frozen'
        Assert ($m2.resolvedBase -match '^[0-9a-f]{40}$' -and $m2.resolvedHead -match '^[0-9a-f]{40}$') 'resolved endpoints absent'
        Assert ($m3.effectiveBase -eq $m3.resolvedBase) 'ancestor three-dot merge base is wrong'
        $invalid = Invoke-AtRepo $repo $builder @('-Mode','Range','-Base','not-a-ref','-Head','HEAD','-OutputPath',$bad)
        Assert ($invalid.Exit -eq 3 -and $invalid.Text -match 'CANNOT EXAMINE') "bad ref was not inability: $($invalid.Exit) $($invalid.Text)"
    } finally {
        Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $two -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $three -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $bad -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'copies explicit whole-file binary bytes and refuses an over-budget file by name' {
    $repo = New-ReviewRepo; $bundle = New-BundlePath; $tooLargeBundle = New-BundlePath; $paths = $null; $largePaths = $null
    try {
        $binary = [byte[]]@(0,1,2,127,128,255)
        [IO.File]::WriteAllBytes((Join-Path $repo 'src/raw.bin'), $binary)
        $paths = New-PathFile @('src/raw.bin')
        $result = Invoke-AtRepo $repo $builder @('-Mode','WholeFile','-OutputPath',$bundle,'-PathFile',$paths)
        Assert ($result.Exit -eq 0) "whole-file capture failed: $($result.Text)"
        Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $bundle 'whole/src/raw.bin'))) -ceq [Convert]::ToBase64String($binary)) 'binary whole-file bytes changed'
        $stream = [IO.File]::Open((Join-Path $repo 'src/large.bin'), [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { $stream.SetLength(16MB + 1) } finally { $stream.Dispose() }
        $largePaths = New-PathFile @('src/large.bin')
        $large = Invoke-AtRepo $repo $builder @('-Mode','WholeFile','-OutputPath',$tooLargeBundle,'-PathFile',$largePaths)
        Assert ($large.Exit -eq 3 -and $large.Text -match 'large\.bin' -and $large.Text -match 'capture limit') "over-budget file was omitted or misclassified: $($large.Exit) $($large.Text)"
        Assert (-not (Test-Path -LiteralPath $tooLargeBundle)) 'failed over-budget capture left a partial bundle'
    } finally {
        Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $bundle -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $tooLargeBundle -Recurse -Force -ErrorAction SilentlyContinue
        if ($paths) { Remove-Item -LiteralPath $paths -Force -ErrorAction SilentlyContinue }
        if ($largePaths) { Remove-Item -LiteralPath $largePaths -Force -ErrorAction SilentlyContinue }
    }
}

It 'separates unsafe arguments, unborn repositories, and occupied outputs' {
    $repo = New-ReviewRepo; $inside = Join-Path $repo 'bundle'; $occupied = New-BundlePath; $unborn = Join-Path ([IO.Path]::GetTempPath()) ('review-unborn-' + [guid]::NewGuid().ToString('N')); $unbornBundle = New-BundlePath; $paths = $null
    try {
        $paths = New-PathFile @('../escape')
        $unsafe = Invoke-AtRepo $repo $builder @('-Mode','WholeFile','-OutputPath',(New-BundlePath),'-PathFile',$paths)
        Assert ($unsafe.Exit -eq 2 -and $unsafe.Text -match 'INVALID') "traversal was not invalid input: $($unsafe.Exit) $($unsafe.Text)"
        $insideResult = Invoke-AtRepo $repo $builder @('-Mode','Uncommitted','-OutputPath',$inside)
        Assert ($insideResult.Exit -eq 2 -and $insideResult.Text -match 'outside') "repository-contained output was accepted: $($insideResult.Exit) $($insideResult.Text)"
        New-Item -ItemType Directory -Path $occupied | Out-Null
        $occupiedResult = Invoke-AtRepo $repo $builder @('-Mode','Uncommitted','-OutputPath',$occupied)
        Assert ($occupiedResult.Exit -eq 3 -and $occupiedResult.Text -match 'already exists') "occupied output was not inability: $($occupiedResult.Exit) $($occupiedResult.Text)"
        New-Item -ItemType Directory -Path $unborn | Out-Null; & git -C $unborn init -q 2>&1 | Out-Null
        $unbornResult = Invoke-AtRepo $unborn $builder @('-Mode','Uncommitted','-OutputPath',$unbornBundle)
        Assert ($unbornResult.Exit -eq 3 -and $unbornResult.Text -match 'no resolvable HEAD') "unborn repository became an empty bundle: $($unbornResult.Exit) $($unbornResult.Text)"
    } finally {
        Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $occupied -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $unborn -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $unbornBundle -Recurse -Force -ErrorAction SilentlyContinue
        if ($paths) { Remove-Item -LiteralPath $paths -Force -ErrorAction SilentlyContinue }
    }
}

It 'refuses path-list and Git-enumerated content through a directory reparse point' {
    $repo = New-ReviewRepo; $outside = Join-Path ([IO.Path]::GetTempPath()) ('review-outside-' + [guid]::NewGuid().ToString('N')); $bundle = New-BundlePath; $filteredBundle = New-BundlePath
    try {
        New-Item -ItemType Directory -Path $outside | Out-Null
        [IO.File]::WriteAllText((Join-Path $outside 'External.Tests.ps1'), "Assert 'outside'`n", [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $outside 'paths.json'), '["tests/Foo.Tests.ps1"]', [Text.UTF8Encoding]::new($false))
        New-Item -ItemType Junction -Path (Join-Path $repo 'linked-tests') -Target $outside -Force | Out-Null
        $filtered = Invoke-AtRepo $repo $builder @('-Mode','Uncommitted','-OutputPath',$filteredBundle,'-PathFile',(Join-Path $repo 'linked-tests/paths.json'))
        Assert ($filtered.Exit -eq 2 -and $filtered.Text -match 'INVALID.*path list traverses a reparse point') "path-list ancestor reparse was not invalid input: $($filtered.Exit) $($filtered.Text)"
        $result = Invoke-AtRepo $repo $builder @('-Mode','Uncommitted','-OutputPath',$bundle)
        Assert ($result.Exit -eq 3 -and $result.Text -match 'CANNOT EXAMINE.*(reparse|regular file)') "untracked reparse content was not refused: $($result.Exit) $($result.Text)"
        Assert (-not (Test-Path -LiteralPath (Join-Path $bundle 'untracked/linked-tests/External.Tests.ps1'))) 'builder copied bytes through an untracked directory reparse point'
    } finally {
        $link = Join-Path $repo 'linked-tests'
        if (Test-Path -LiteralPath $link) { try { [IO.Directory]::Delete($link) } catch { } }
        Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $outside -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $bundle -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $filteredBundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'scanner rejects tampered bytes but classifies an actual read lock as CANNOT EXAMINE' {
    $repo = New-ReviewRepo; $bundle = New-BundlePath
    try {
        [IO.File]::WriteAllText((Join-Path $repo 'tests/Foo.Tests.ps1'), "Assert 1`n", [Text.UTF8Encoding]::new($false))
        & git -C $repo add -A 2>&1 | Out-Null; & git -C $repo commit -qm head 2>&1 | Out-Null
        $capture = Invoke-AtRepo $repo $builder @('-Mode','Range','-Base','HEAD~1','-Head','HEAD','-OutputPath',$bundle)
        Assert ($capture.Exit -eq 0) "range capture failed: $($capture.Text)"
        $patchPath = Join-Path $bundle 'range.patch'
        $clean = Invoke-AtRepo $repo $scanner @('-ScopePath',$bundle)
        Assert ($clean.Exit -eq 0 -and $clean.Text -match 'Foo\.Tests\.ps1') "valid range scope was not constructibly scannable: $($clean.Exit) $($clean.Text)"
        $manifestPath = Join-Path $bundle 'manifest.json'
        $manifestBytes = [IO.File]::ReadAllBytes($manifestPath)
        $manifest = Read-Manifest $bundle
        $manifest.mode = 'WholeFile'
        [IO.File]::WriteAllText($manifestPath, (($manifest | ConvertTo-Json -Depth 8 -Compress) + "`n"), [Text.UTF8Encoding]::new($false))
        $wrongLayers = Invoke-AtRepo $repo $scanner @('-ScopePath',$bundle)
        Assert ($wrongLayers.Exit -eq 2 -and $wrongLayers.Text -match 'INVALID.*layers do not match mode') "malformed mode/layer relationship was accepted: $($wrongLayers.Exit) $($wrongLayers.Text)"
        [IO.File]::WriteAllBytes($manifestPath, $manifestBytes)
        $lock = [IO.File]::Open($patchPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        try {
            $locked = Invoke-AtRepo $repo $scanner @('-ScopePath',$bundle)
            Assert ($locked.Exit -eq 3 -and $locked.Text -match 'CANNOT EXAMINE') "read lock was not inability: $($locked.Exit) $($locked.Text)"
        } finally { $lock.Dispose() }
        [IO.File]::AppendAllText($patchPath, "tamper`n", [Text.UTF8Encoding]::new($false))
        $tampered = Invoke-AtRepo $repo $scanner @('-ScopePath',$bundle)
        Assert ($tampered.Exit -eq 2 -and $tampered.Text -match 'INVALID.*hash or size') "tampered bytes were not invalid: $($tampered.Exit) $($tampered.Text)"
    } finally {
        Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $bundle -Recurse -Force -ErrorAction SilentlyContinue
    }
}

exit (Write-TestSummary 'ReviewScope.Tests')
