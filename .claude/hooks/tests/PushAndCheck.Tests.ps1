# Tests for the ordinary-push CI wrapper (B-137). Maintainer-only; does not ship.
#
# Subject: .claude/scripts/push-and-check.ps1.
# Proved here: failed pushes preserve git's exit and never start the watcher; unwatched pushes skip
# cleanly; watched pushes propagate watch-ci.ps1's 0/1/3 contract; omitted -Branch is resolved by
# git; and an invalid -GitPath is reported distinctly. Every push is handled by a generated fake
# git process. NOT proved here: that a real remote accepts a push or that GitHub Actions runs.
#
# The fake executables have no param block deliberately. Declared parameters would bind native-tool
# flags and mangle the argument vector; with no param block every token reaches $args intact.

. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$subject = Join-Path $repoRoot '.claude/scripts/push-and-check.ps1'
Reset-Tests

$SHA = 'a41ab8d090bc7d2927290cf99a8f6c0cab1810b6'
$scratch = @()

function New-GitStub {
    param([int]$PushExit = 0, [string]$CurrentBranch = 'master')
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('pushcheck-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $script:scratch += $dir
    $body = @'
$dir = '__DIR__'
$cmd = ($args -join ' ')
Add-Content -LiteralPath (Join-Path $dir 'git-calls.log') -Value $cmd
if ($cmd -like '* rev-parse --abbrev-ref HEAD') { Write-Output '__BRANCH__'; exit 0 }
if ($cmd -like '* rev-parse HEAD') { Write-Output '__SHA__'; exit 0 }
if ($cmd -like '* push origin *') {
    Write-Output 'push stdout'
    [Console]::Error.WriteLine('push stderr')
    exit __PUSHEXIT__
}
[Console]::Error.WriteLine("unexpected git call: $cmd")
exit 91
'@
    $body = $body.Replace('__DIR__', $dir).Replace('__BRANCH__', $CurrentBranch).Replace('__SHA__', $SHA).Replace('__PUSHEXIT__', "$PushExit")
    $path = Join-Path $dir 'git-stub.ps1'
    [IO.File]::WriteAllText($path, $body, [Text.UTF8Encoding]::new($true))
    return [pscustomobject]@{ Dir=$dir; Path=$path; Log=(Join-Path $dir 'git-calls.log') }
}

function New-GhStub {
    param([ValidateSet('green','red','absent')][string]$State)
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('pushcheck-gh-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $script:scratch += $dir
    $jobs = @('windows','linux','macos-portability','windows-hooks (dotnet)','windows-hooks (angular)','windows-hooks (monorepo)','linux-hooks (dotnet)','linux-hooks (angular)','linux-hooks (monorepo)' |
        ForEach-Object { '{"name":"' + $_ + '","conclusion":"success","status":"completed"}' }) -join ','
    $conclusion = if ($State -eq 'red') { 'failure' } else { 'success' }
    $row = '[{"conclusion":"' + $conclusion + '","databaseId":123,"event":"push","headSha":"' + $SHA + '","status":"completed","url":"https://github.com/owner/repo/actions/runs/123","workflowName":"CI"}]'
    $body = @'
$dir = '__DIR__'
$cmd = ($args -join ' ')
Add-Content -LiteralPath (Join-Path $dir 'watch-calls.log') -Value $cmd
if ($cmd -like 'repo view*') { Write-Output '{"nameWithOwner":"owner/repo"}'; exit 0 }
if ($cmd -like 'run view*') { Write-Output '{"jobs":[__JOBS__]}'; exit 0 }
if ('__STATE__' -eq 'absent') { Write-Output '[]'; exit 0 }
Write-Output '__ROW__'
exit 0
'@
    $body = $body.Replace('__DIR__',$dir).Replace('__JOBS__',$jobs).Replace('__STATE__',$State).Replace('__ROW__',$row)
    $path = Join-Path $dir 'gh-stub.ps1'
    [IO.File]::WriteAllText($path, $body, [Text.UTF8Encoding]::new($true))
    return [pscustomobject]@{ Dir=$dir; Path=$path; Log=(Join-Path $dir 'watch-calls.log') }
}

function Invoke-Subject {
    param($Git, $Gh, [string]$Branch = 'master', [switch]$OmitBranch, [string[]]$Watched = @('master'), [string]$GitPath)
    if (-not $GitPath) { $GitPath = $Git.Path }
    $argsList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$subject,'-GitPath',$GitPath,
        '-RepoRoot',$repoRoot,'-TimeoutSeconds','5','-AppearSeconds','1','-PollSeconds','0',
        '-WatchedBranches') + $Watched
    if (-not $OmitBranch) { $argsList += @('-Branch',$Branch) }
    if ($Gh) { $argsList += @('-GhPath',$Gh.Path) }
    $ef = [IO.Path]::GetTempFileName()
    try {
        $out = & (Get-Process -Id $PID).Path @argsList 2>$ef
        return [pscustomobject]@{ Exit=$LASTEXITCODE; Out=(($out -join "`n") + "`n" + [IO.File]::ReadAllText($ef)) }
    } finally { Remove-Item -LiteralPath $ef -Force -ErrorAction SilentlyContinue }
}

try {
    It 'a failed push preserves git exit and never invokes CI watch' {
        $g=New-GitStub -PushExit 7; $h=New-GhStub green; $r=Invoke-Subject $g $h
        Assert ($r.Exit -eq 7) "expected 7, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'PUSH FAILED') 'missing PUSH FAILED'
        Assert (-not (Test-Path -LiteralPath $h.Log)) 'watch-ci was invoked after a failed push'
    }
    It 'an unwatched branch pushes, skips watching, and exits 0' {
        $g=New-GitStub; $h=New-GhStub green; $r=Invoke-Subject $g $h -Branch feature/x
        Assert ($r.Exit -eq 0) "expected 0: $($r.Out)"
        Assert ($r.Out -match 'skipp') 'skip note missing'
        Assert (-not (Test-Path -LiteralPath $h.Log)) 'watch-ci ran for an unwatched branch'
    }
    It 'a watched green run exits 0' { $g=New-GitStub; $h=New-GhStub green; $r=Invoke-Subject $g $h; Assert ($r.Exit -eq 0) "expected 0: $($r.Out)"; Assert ($r.Out -match 'CI GREEN') 'green verdict missing' }
    It 'a watched red run exits 1' { $g=New-GitStub; $h=New-GhStub red; $r=Invoke-Subject $g $h; Assert ($r.Exit -eq 1) "expected 1: $($r.Out)"; Assert ($r.Out -match 'CI RED') 'red verdict missing' }
    It 'a watched absent run exits 3' { $g=New-GitStub; $h=New-GhStub absent; $r=Invoke-Subject $g $h; Assert ($r.Exit -eq 3) "expected 3: $($r.Out)"; Assert ($r.Out -match 'CANT-VERIFY') 'cannot-verify verdict missing' }
    It 'omitted Branch resolves the current branch through git' {
        $g=New-GitStub -CurrentBranch feature/from-git; $h=New-GhStub green; $r=Invoke-Subject $g $h -OmitBranch
        Assert ($r.Exit -eq 0) "expected 0: $($r.Out)"
        Assert (@(Get-Content $g.Log | Where-Object { $_ -like '* rev-parse --abbrev-ref HEAD' }).Count -eq 1) 'current branch was not queried'
        Assert (@(Get-Content $g.Log | Where-Object { $_ -like '* push origin feature/from-git' }).Count -eq 1) 'resolved branch was not pushed'
        Assert (-not (Test-Path -LiteralPath $h.Log)) 'resolved unwatched branch started CI watch'
    }
    It 'an invalid GitPath reports whether another git is available' {
        $g=New-GitStub; $r=Invoke-Subject $g $null -GitPath (Join-Path $g.Dir 'missing-git.exe')
        Assert ($r.Exit -ne 0) 'invalid GitPath exited 0'
        Assert ($r.Out -match '(?s)git IS installed at|No Git found at any well-known location') "distinguishing git error missing: $($r.Out)"
    }
} finally { foreach ($p in $scratch) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue } }

exit (Write-TestSummary 'PushAndCheck.Tests (B-137 ordinary push CI watch)')
