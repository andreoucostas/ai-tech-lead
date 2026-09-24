# Tests for the ordinary-push CI wrapper (B-137). Maintainer-only; does not ship.
#
# Subject: .claude/scripts/push-and-check.ps1.
# Proved here: failed pushes preserve git's exit and never start the watcher; unwatched pushes skip
# cleanly; watched pushes propagate watch-ci.ps1's 0/1/3 contract; omitted -Branch is resolved by
# git; an invalid -GitPath is reported distinctly; a records-only range (what the push adds to
# origin/<branch>, even commits already on another origin branch) skips the watch while any other
# or unclassifiable range is watched; and the light-path rule matches ci.yml's
# push `paths:` filter. Every push is handled by a generated fake
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
    # -Commits: one entry per outgoing commit, each a string of '|'-separated changed paths. Absent,
    # the range is empty -- the shape every case before WP2 relies on. -OnOtherRemoteBranch: how many
    # of the leading commits are already on another origin branch, so `--not --remotes=origin` omits
    # them while `--not refs/remotes/origin/master` does not, as real git answers.
    param([int]$PushExit = 0, [string]$CurrentBranch = 'master', [switch]$BadOutgoingSubject,
        [string[]]$Commits = @(), [switch]$DiffTreeFails, [int]$OnOtherRemoteBranch = 0)
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('pushcheck-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $script:scratch += $dir
    $body = @'
$dir = '__DIR__'
$cmd = ($args -join ' ')
Add-Content -LiteralPath (Join-Path $dir 'git-calls.log') -Value $cmd
if ($cmd -like '* rev-parse --abbrev-ref HEAD') { Write-Output '__BRANCH__'; exit 0 }
if ($cmd -like '* rev-parse --verify *^{commit}') { Write-Output '__SHA__'; exit 0 }
if ($cmd -like '* fetch --quiet --prune --no-tags origin') { exit 0 }
__OUTGOING__
if ($cmd -like '* rev-list --reverse --topo-order *') { if (__BADOUTGOING__) { Write-Output '__SHA__' }; exit 0 }
if ($cmd -like '* show -s --format=%s __SHA__') { Write-Output '@'; exit 0 }
if ($cmd -like '* rev-list --parents -n 1 __SHA__') { Write-Output '__SHA__'; exit 0 }
if ($cmd -like '* diff-tree --root *') { exit 0 }
if ($cmd -like '* rev-parse HEAD') { Write-Output '__SHA__'; exit 0 }
if ($cmd -like '* push origin *') {
    Write-Output 'push stdout'
    [Console]::Error.WriteLine('push stderr')
    exit __PUSHEXIT__
}
[Console]::Error.WriteLine("unexpected git call: $cmd")
exit 91
'@
    $outgoing = New-Object System.Collections.Generic.List[string]
    $shas = @()
    for ($i = 0; $i -lt $Commits.Count; $i++) {
        $c = ('{0:x}' -f ($i + 1)) * 40
        $shas += $c
        $lines = if ($DiffTreeFails) { "[Console]::Error.WriteLine('fatal: bad object'); exit 128" } else {
            (@($Commits[$i] -split '\|' | Where-Object { $_ } | ForEach-Object { "Write-Output '$_'" }) + 'exit 0') -join '; ' }
        $outgoing.Add("if (`$cmd -like '* diff-tree --root --no-commit-id --name-only -r -m $c') { $lines }")
    }
    if ($shas.Count -gt 0) {
        $unpublished = @($shas | Select-Object -Skip $OnOtherRemoteBranch)
        $outgoing.Insert(0, "if (`$cmd -like '* rev-list --reverse --topo-order master --not --remotes=origin') { " +
            ((@($unpublished | ForEach-Object { "Write-Output '$_'" }) + 'exit 0') -join '; ') + ' }')
        $outgoing.Insert(0, "if (`$cmd -like '* rev-list --reverse --topo-order master --not refs/remotes/origin/master') { " +
            ((@($shas | ForEach-Object { "Write-Output '$_'" }) + 'exit 0') -join '; ') + ' }')
    }
    $body = $body.Replace('__OUTGOING__', ($outgoing -join "`n"))
    $body = $body.Replace('__DIR__', $dir).Replace('__BRANCH__', $CurrentBranch).Replace('__SHA__', $SHA).Replace('__PUSHEXIT__', "$PushExit").Replace('__BADOUTGOING__', $(if ($BadOutgoingSubject) { '$true' } else { '$false' }))
    $path = Join-Path $dir 'git-stub.ps1'
    [IO.File]::WriteAllText($path, $body, [Text.UTF8Encoding]::new($true))
    return [pscustomobject]@{ Dir=$dir; Path=$path; Log=(Join-Path $dir 'git-calls.log') }
}

function New-GhStub {
    param([ValidateSet('green','red','absent')][string]$State)
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('pushcheck-gh-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $script:scratch += $dir
    $jobs = @('windows','windows-ps51','windows-hooks (dotnet)','windows-hooks (angular)','windows-hooks (monorepo)','windows-hooks-ps51 (dotnet)','windows-hooks-ps51 (angular)','windows-hooks-ps51 (monorepo)','windows-case-parity' |
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
    It 'an outgoing-check refusal prevents git push' {
        $g=New-GitStub -BadOutgoingSubject; $h=New-GhStub green; $r=Invoke-Subject $g $h
        Assert ($r.Exit -eq 1) "expected outgoing refusal exit 1, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'subject rejected') "outgoing subject-rejection evidence missing: $($r.Out)"
        Assert ($r.Out -match 'PUSH REFUSED') "caller refusal evidence missing: $($r.Out)"
        Assert (@(Get-Content $g.Log | Where-Object { $_ -like '* push origin *' }).Count -eq 0) 'git push ran after the outgoing check refused'
        Assert (-not (Test-Path -LiteralPath $h.Log)) 'CI watch ran after the outgoing check refused'
    }
    It 'a failed push preserves git exit and never invokes CI watch' {
        $g=New-GitStub -PushExit 7; $h=New-GhStub green; $r=Invoke-Subject $g $h
        Assert ($r.Exit -eq 7) "expected 7, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'PUSH FAILED') 'missing PUSH FAILED'
        Assert (-not (Test-Path -LiteralPath $h.Log)) 'watch-ci was invoked after a failed push'
        $calls = @(Get-Content -LiteralPath $g.Log)
        $fetchIndex = [Array]::FindIndex([string[]]$calls, [Predicate[string]]{ param($line) $line -like '* fetch --quiet --prune --no-tags origin' })
        $pushIndex = [Array]::FindIndex([string[]]$calls, [Predicate[string]]{ param($line) $line -like '* push origin master' })
        Assert ($fetchIndex -ge 0 -and $pushIndex -gt $fetchIndex) 'outgoing range was not checked before git push'
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
    $skipLine = 'CI_WATCH SKIPPED records-only'
    It 'WP2 (a): a records-only outgoing range pushes and skips the CI watch' {
        $g=New-GitStub -Commits @('meta/BACKLOG.md|.claude/plans/2026-09-19-x.md', 'meta/BACKLOG-DONE.md'); $h=New-GhStub absent; $r=Invoke-Subject $g $h
        Assert ($r.Exit -eq 0) "expected 0: $($r.Out)"
        Assert ($r.Out -match [regex]::Escape($skipLine)) "skip line missing: $($r.Out)"
        Assert (@(Get-Content $g.Log | Where-Object { $_ -like '* push origin master' }).Count -eq 1) 'records-only range was not pushed'
        Assert (-not (Test-Path -LiteralPath $h.Log)) 'watch-ci ran for a records-only range'
    }
    It 'WP2 (b): a mixed outgoing range is watched' {
        $g=New-GitStub -Commits @('meta/BACKLOG.md', '.claude/scripts/push-and-check.ps1'); $h=New-GhStub green; $r=Invoke-Subject $g $h
        Assert ($r.Exit -eq 0) "expected 0: $($r.Out)"
        Assert ($r.Out -notmatch [regex]::Escape($skipLine)) "mixed range was classified records-only: $($r.Out)"
        Assert (Test-Path -LiteralPath $h.Log) 'watch-ci did not run for a mixed range'
    }
    foreach ($heavy in 'meta/eval-results.md', 'meta/review-ledger.md', 'meta/gate-budget.json', 'meta/eval-fixtures/x/README.md') {
        It "WP2 (c): a range touching $heavy is watched" {
            $g=New-GitStub -Commits @("meta/BACKLOG.md|$heavy"); $h=New-GhStub green; $r=Invoke-Subject $g $h
            Assert ($r.Out -notmatch [regex]::Escape($skipLine)) "$heavy was classified records-only: $($r.Out)"
            Assert (Test-Path -LiteralPath $h.Log) "watch-ci did not run for $heavy"
        }
    }
    It 'a range already on another origin branch is classified by what it adds to origin/master' {
        # B-283: a cloud session's branch fast-forwarded into master brought src/dist commits that were
        # on origin but not on origin/master; ci.yml's push filter saw them and ran, the watch skipped.
        $g=New-GitStub -Commits @('src/stacks/dotnet/files/README.md|dist/dotnet/README.md', 'meta/BACKLOG.md') -OnOtherRemoteBranch 1
        $h=New-GhStub green; $r=Invoke-Subject $g $h
        Assert ($r.Exit -eq 0) "expected 0: $($r.Out)"
        Assert ($r.Out -notmatch [regex]::Escape($skipLine)) "a range with src/dist commits was classified records-only: $($r.Out)"
        Assert (Test-Path -LiteralPath $h.Log) 'watch-ci did not run for commits new to origin/master'
    }
    It 'WP2 (e): an unreadable path list is watched, never records-only' {
        $g=New-GitStub -Commits @('meta/BACKLOG.md') -DiffTreeFails; $h=New-GhStub green; $r=Invoke-Subject $g $h
        Assert ($r.Out -notmatch [regex]::Escape($skipLine)) "unreadable paths were classified records-only: $($r.Out)"
        Assert (Test-Path -LiteralPath $h.Log) 'watch-ci did not run when the path list was unreadable'
    }
    It 'WP2 (e): an empty outgoing range is watched' {
        $g=New-GitStub; $h=New-GhStub green; $r=Invoke-Subject $g $h
        Assert ($r.Out -notmatch [regex]::Escape($skipLine)) "an empty range was classified records-only: $($r.Out)"
        Assert (Test-Path -LiteralPath $h.Log) 'watch-ci did not run for an empty range'
    }

    # (d) Drift guard. Test-LightChangePath is lifted out of the subject by AST and compared, path by
    # path, with an evaluator of ci.yml's push `paths:` list written from GitHub's documented rules:
    # `*` stops at `/`, `**` crosses it, patterns apply in order and the last match wins.
    $lightError = $null
    $subjectAst = [System.Management.Automation.Language.Parser]::ParseFile($subject, [ref]$null, [ref]$null)
    $lightFn = $subjectAst.FindAll({ param($n)
        $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Test-LightChangePath'
    }, $true) | Select-Object -First 1
    if ($null -eq $lightFn) { $lightError = 'push-and-check.ps1 no longer defines Test-LightChangePath' }
    else { . ([scriptblock]::Create($lightFn.Extent.Text)) }
    $ciText = [IO.File]::ReadAllText((Join-Path $repoRoot '.github/workflows/ci.yml'))
    $pathsBlock = [regex]::Match($ciText, '(?m)^  push:\r?\n(?:    .*\r?\n)*?    paths:\r?\n((?:      - .*\r?\n)+)')
    $patterns = @([regex]::Matches($pathsBlock.Groups[1].Value, "(?m)^      - '([^']+)'") | ForEach-Object { $_.Groups[1].Value })
    function Test-CiIncludes([string]$Path) {
        $included = $false
        foreach ($p in $patterns) {
            $neg = $p.StartsWith('!')
            $glob = if ($neg) { $p.Substring(1) } else { $p }
            $rx = '^' + (([regex]::Escape($glob) -replace '\\\*\\\*', '.*' -replace '\\\*', '[^/]*')) + '$'
            if ($Path -cmatch $rx) { $included = -not $neg }
        }
        return $included
    }
    It 'WP2 (d): ci.yml push paths and Test-LightChangePath classify every probe path alike' {
        Assert ($null -eq $lightError) $lightError
        Assert ($patterns.Count -ge 2 -and $patterns[0] -eq '**') "ci.yml push paths not parsed or not led by '**': [$($patterns -join ', ')]"
        Assert ($ciText -match '(?m)^  pull_request:\r?\n  push:') 'pull_request trigger is no longer bare (unfiltered)'
        $probes = @('meta/BACKLOG.md', 'meta/eval-results.md', 'meta/review-ledger.md', 'meta/gate-budget.json',
            'meta/eval-fixtures/x/README.md', 'meta/a/b.md', '.claude/plans/x.md', '.claude/plans/inbox/y.md',
            '.claude/scripts/push-and-check.ps1', '.github/workflows/ci.yml', 'README.md', 'AGENTS.md',
            'CHANGELOG.md', 'src/core/CLAUDE.md', 'dist/dotnet/CLAUDE.md', 'meta.md', 'xmeta/a.md')
        foreach ($p in $patterns) {
            $g = $p.TrimStart('!')
            $probes += ($g -replace '\*\*', 'a/b' -replace '\*', 'x')
            $probes += ($g -replace '\*\*', 'q' -replace '\*', 'x')
        }
        foreach ($probe in ($probes | Select-Object -Unique)) {
            $ci = Test-CiIncludes $probe
            $light = Test-LightChangePath $probe
            Assert ($ci -ne $light) "drift on '$probe': ci.yml includes=$ci, Test-LightChangePath=$light"
        }
    }
} finally { foreach ($p in $scratch) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue } }

exit (Write-TestSummary 'PushAndCheck.Tests (B-137 ordinary push CI watch)')
