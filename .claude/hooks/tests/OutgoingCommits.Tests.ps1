# Recurrence tests for the PowerShell-only outgoing-commit guard (B-219). The subject is exercised
# against real local Git objects and a local bare remote: no transcript or worktree proxy stands in
# for the immutable commits that push-and-check/release are about to publish.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
Reset-Tests

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$checker = Join-Path $repoRoot '.claude\scripts\check-outgoing-commits.ps1'
$subjectRules = Join-Path $repoRoot '.claude\scripts\_commit-subject.ps1'
$guardSource = Join-Path $repoRoot 'src\core\.claude\hooks\guard.ps1'
$guardFixtureSource = Join-Path $repoRoot 'src\core\tests\hooks\fixtures\guard-cases.ps1'
$git = (Get-Command git -ErrorAction Stop).Source
$scratch = [Collections.Generic.List[string]]::new()
$previousXdgConfigHome = $env:XDG_CONFIG_HOME
$previousGitConfigGlobal = $env:GIT_CONFIG_GLOBAL
$previousGitConfigNoSystem = $env:GIT_CONFIG_NOSYSTEM
$isolatedXdgConfigHome = Join-Path ([IO.Path]::GetTempPath()) ('outgoing-xdg-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Force $isolatedXdgConfigHome
$scratch.Add($isolatedXdgConfigHome)
$env:XDG_CONFIG_HOME = $isolatedXdgConfigHome
$env:GIT_CONFIG_GLOBAL = 'NUL'
$env:GIT_CONFIG_NOSYSTEM = '1'

function Invoke-Git([string]$Directory, [string[]]$Arguments) {
    $output = @(& $git -C $Directory @Arguments 2>&1 | ForEach-Object { $_.ToString() })
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed: $($output -join "`n")" }
    return $output
}

function Set-Text([string]$Path, [string]$Text, [bool]$Bom = $false) {
    $parent = Split-Path -Parent $Path
    if ($parent) { $null = New-Item -ItemType Directory -Force $parent }
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($Bom))
}

function New-RepositoryFixture {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('outgoing-check-' + [guid]::NewGuid().ToString('N'))
    $work = Join-Path $root 'work'
    $remote = Join-Path $root 'remote.git'
    $script:scratch.Add($root)
    $null = New-Item -ItemType Directory -Force $work
    & $git init --bare -q $remote
    if ($LASTEXITCODE -ne 0) { throw 'could not initialize bare fixture remote' }
    & $git init -q -b master $work
    if ($LASTEXITCODE -ne 0) { throw 'could not initialize fixture worktree' }
    $null = Invoke-Git $work @('config','user.email','fixture@example.invalid')
    $null = Invoke-Git $work @('config','user.name','Fixture')
    $null = New-Item -ItemType Directory -Force (Join-Path $work 'src\core\.claude\hooks')
    Copy-Item -LiteralPath $guardSource -Destination (Join-Path $work 'src\core\.claude\hooks\guard.ps1')
    Set-Text (Join-Path $work 'README.md') "fixture`n"
    $null = Invoke-Git $work @('add','.')
    $null = Invoke-Git $work @('commit','-q','-m','Create fixture baseline')
    $null = Invoke-Git $work @('remote','add','origin',$remote)
    $null = Invoke-Git $work @('push','-q','-u','origin','master')
    return [pscustomobject]@{ Root=$root; Work=$work; Remote=$remote }
}

function Add-Commit($Fixture, [string]$Path, [string]$Text, [string]$Subject, [bool]$Bom = $false) {
    Set-Text (Join-Path $Fixture.Work $Path) $Text $Bom
    $null = Invoke-Git $Fixture.Work @('add','--',$Path)
    $null = Invoke-Git $Fixture.Work @('commit','-q','-m',$Subject)
}

function Invoke-Checker($Fixture, [switch]$AlwaysInspectRevision) {
    $errorFile = [IO.Path]::GetTempFileName()
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$checker,
            '-RepoRoot',$Fixture.Work,'-Remote','origin','-Revision','HEAD','-GitPath',$git)
        if ($AlwaysInspectRevision) { $arguments += '-AlwaysInspectRevision' }
        $output = @(& (Get-Process -Id $PID).Path @arguments 2>$errorFile |
            ForEach-Object { $_.ToString() })
        $code = [int]$LASTEXITCODE
        $errorText = [IO.File]::ReadAllText($errorFile)
        return [pscustomobject]@{ Exit=$code; Out=(($output -join "`n") + "`n" + $errorText) }
    } finally {
        $ErrorActionPreference = $previousPreference
        Remove-Item -LiteralPath $errorFile -Force -ErrorAction SilentlyContinue
    }
}

try {
    It 'accepts an empty outgoing range' {
        $fixture = New-RepositoryFixture
        $result = Invoke-Checker $fixture
        Assert ($result.Exit -eq 0) "empty range failed: $($result.Out)"
        Assert ($result.Out -match 'no commits absent') "empty-range evidence missing: $($result.Out)"
    }

    It 'checks and accepts clean immutable commit content' {
        $fixture = New-RepositoryFixture
        Add-Commit $fixture 'clean.ps1' "Write-Host 'clean'`n" 'Add clean PowerShell fixture' $true
        Set-Text (Join-Path $fixture.Work 'clean.ps1') "#pragma warning disable`n" $true
        $result = Invoke-Checker $fixture
        Assert ($result.Exit -eq 0) "clean committed blob was replaced by worktree bytes: $($result.Out)"
        Assert ($result.Out -match '1 commit\(s\)') "checked-commit cardinality missing: $($result.Out)"
    }

    It 'enumerates a new branch with no destination remote ref' {
        $fixture = New-RepositoryFixture
        $null = Invoke-Git $fixture.Work @('checkout','-q','-b','feature/new-branch')
        Add-Commit $fixture 'branch.txt' "new branch`n" 'Add clean new-branch fixture'
        $result = Invoke-Checker $fixture
        Assert ($result.Exit -eq 0) "new branch could not be checked: $($result.Out)"
        Assert ($result.Out -match '1 commit\(s\)') "new-branch range was not enumerated: $($result.Out)"
    }

    It 'prunes a deleted remote branch before computing the outgoing range' {
        $fixture = New-RepositoryFixture
        $null = Invoke-Git $fixture.Work @('checkout','-q','-b','stale-remote-branch')
        Add-Commit $fixture 'stale.txt' "stale remote ref`n" '@'
        $null = Invoke-Git $fixture.Work @('push','-q','-u','origin','stale-remote-branch')
        $null = Invoke-Git $fixture.Remote @('update-ref','-d','refs/heads/stale-remote-branch')
        $null = Invoke-Git $fixture.Work @('show-ref','--verify','refs/remotes/origin/stale-remote-branch')
        $result = Invoke-Checker $fixture
        Assert ($result.Exit -eq 1) "stale tracking ref hid the outgoing bad subject: $($result.Out)"
        Assert ($result.Out -match '(?s)subject rejected.*degenerate') "pruned-range subject reason missing: $($result.Out)"
        $tracking = @(Invoke-Git $fixture.Work @('for-each-ref','--format=%(refname)','refs/remotes/origin'))
        Assert ('refs/remotes/origin/stale-remote-branch' -cnotin $tracking) `
            "outgoing check did not prune the stale tracking ref: $($tracking -join ' ')"
    }

    It 'rejects each preserved commit-subject recurrence' {
        . $subjectRules
        $cases = @(
            @{ Subject='@'; Match='degenerate' },
            @{ Subject='--- !!! ???'; Match='punctuation' },
            @{ Subject='Fix typo'; Match='10 characters' },
            @{ Subject='C:/Program Files/Git/bootstrap and /adopt docs'; Match='MSYS' }
        )
        Assert ($cases.Count -eq 4) 'subject recurrence table is empty or incomplete'
        foreach ($case in $cases) {
            $reason = Get-CommitSubjectRejection $case.Subject
            Assert ($reason -match $case.Match) "subject '$($case.Subject)' was not rejected as $($case.Match): $reason"
        }
        Assert (-not (Get-CommitSubjectRejection 'Describe a realistic repository change')) 'realistic subject was rejected'
    }

    It 'rejects a bad subject from an actual outgoing commit' {
        $fixture = New-RepositoryFixture
        Add-Commit $fixture 'subject.txt' "bad subject`n" '@'
        $result = Invoke-Checker $fixture
        Assert ($result.Exit -eq 1) "bad subject exit was $($result.Exit): $($result.Out)"
        Assert ($result.Out -match '(?s)subject rejected.*degenerate') "subject reason missing: $($result.Out)"
    }

    It 'rejects a BOM-less PowerShell blob' {
        $fixture = New-RepositoryFixture
        Add-Commit $fixture 'bomless.ps1' "Write-Host 'fixture'`n" 'Add BOM regression fixture'
        $result = Invoke-Checker $fixture
        Assert ($result.Exit -eq 1) "BOM-less blob exit was $($result.Exit): $($result.Out)"
        Assert ($result.Out -match 'without\s+UTF-8 BOM:\s*bomless\.ps1') "BOM finding missing: $($result.Out)"
    }

    It 'inspects the destination blob of a pure rename' {
        $fixture = New-RepositoryFixture
        Add-Commit $fixture 'before.ps1' "Write-Host 'fixture'`n" 'Add pre-existing rename fixture'
        $null = Invoke-Git $fixture.Work @('push','-q','origin','master')
        $null = Invoke-Git $fixture.Work @('mv','before.ps1','after.ps1')
        $null = Invoke-Git $fixture.Work @('commit','-q','-m','Rename PowerShell fixture')
        $result = Invoke-Checker $fixture
        Assert ($result.Exit -eq 1) "renamed BOM-less blob exit was $($result.Exit): $($result.Out)"
        Assert ($result.Out -match 'without\s+UTF-8 BOM:\s*after\.ps1') "renamed destination was not inspected: $($result.Out)"
    }

    It 'rejects a canonical guard pattern in a committed blob' {
        $fixture = New-RepositoryFixture
        Add-Commit $fixture 'unsafe.cs' "#pragma warning disable`n" 'Add unsafe committed fixture'
        Set-Text (Join-Path $fixture.Work 'unsafe.cs') "public class Safe { }`n"
        $result = Invoke-Checker $fixture
        Assert ($result.Exit -eq 1) "unsafe committed blob exit was $($result.Exit): $($result.Out)"
        Assert ($result.Out -match '#pragma\s+warning\s+disable') "canonical guard reason missing: $($result.Out)"
    }

    It 'permits only the exact content-qualified canonical guard fixture' {
        $fixture = New-RepositoryFixture
        $target = Join-Path $fixture.Work 'src\core\tests\hooks\fixtures\guard-cases.ps1'
        $null = New-Item -ItemType Directory -Force (Split-Path -Parent $target)
        Copy-Item -LiteralPath $guardFixtureSource -Destination $target
        $null = Invoke-Git $fixture.Work @('add','--','src/core/tests/hooks/fixtures/guard-cases.ps1')
        $null = Invoke-Git $fixture.Work @('commit','-q','-m','Add exact canonical guard fixture')
        $result = Invoke-Checker $fixture
        Assert ($result.Exit -eq 0) "exact guard fixture was not excepted: $($result.Out)"
        Assert ($result.Out -match 'OUTGOING EXCEPTION:') "exception use was not reported: $($result.Out)"

        Add-Content -LiteralPath $target -Value '# digest-changing fixture edit'
        $null = Invoke-Git $fixture.Work @('add','--','src/core/tests/hooks/fixtures/guard-cases.ps1')
        $null = Invoke-Git $fixture.Work @('commit','-q','-m','Change canonical guard fixture digest')
        $result = Invoke-Checker $fixture
        Assert ($result.Exit -eq 1) "changed guard fixture bypassed its content-qualified exception: $($result.Out)"
        Assert ($result.Out -match 'guard rejected') "changed guard fixture rejection is missing: $($result.Out)"
    }

    It 'reports and skips a binary blob without weakening PowerShell BOM checks' {
        $fixture = New-RepositoryFixture
        Add-Commit $fixture 'image.bin' ("binary`0payload") 'Add binary fixture payload'
        $result = Invoke-Checker $fixture
        Assert ($result.Exit -eq 0) "binary blob blocked the push: $($result.Out)"
        Assert ($result.Out -match "skipped binary blob 'image\.bin'") "binary skip was not explicit: $($result.Out)"
    }

    It 'can inspect a revision already present on the remote for tag pushes' {
        $fixture = New-RepositoryFixture
        Add-Commit $fixture 'tagged.txt' "tag target`n" '@'
        $null = Invoke-Git $fixture.Work @('push','-q','origin','master')
        $empty = Invoke-Checker $fixture
        Assert ($empty.Exit -eq 0 -and $empty.Out -match 'no commits absent') "default range was not empty after push: $($empty.Out)"
        $result = Invoke-Checker $fixture -AlwaysInspectRevision
        Assert ($result.Exit -eq 1) "tag-target inspection did not reject the already-pushed bad subject: $($result.Out)"
        Assert ($result.Out -match 'subject rejected') "tag-target rejection reason missing: $($result.Out)"
    }

    It 'checks the merge result against every parent' {
        $fixture = New-RepositoryFixture
        $null = Invoke-Git $fixture.Work @('checkout','-q','-b','side')
        Add-Commit $fixture 'side.txt' "side`n" 'Add side branch fixture'
        $null = Invoke-Git $fixture.Work @('checkout','-q','master')
        Add-Commit $fixture 'main.txt' "main`n" 'Add main branch fixture'
        $null = Invoke-Git $fixture.Work @('merge','-q','--no-ff','side','-m','Merge fixture branches')
        Set-Text (Join-Path $fixture.Work 'merge.cs') "#pragma warning disable`n"
        $null = Invoke-Git $fixture.Work @('add','merge.cs')
        $null = Invoke-Git $fixture.Work @('commit','-q','--amend','--no-edit')
        $result = Invoke-Checker $fixture
        Assert ($result.Exit -eq 1) "unsafe merge result exit was $($result.Exit): $($result.Out)"
        Assert ($result.Out -match "guard rejected 'merge.cs'") "merge blob was not checked: $($result.Out)"
    }

    It 'returns CANT-VERIFY when the remote cannot be refreshed' {
        $fixture = New-RepositoryFixture
        Add-Commit $fixture 'pending.txt' "pending`n" 'Add unreachable remote fixture'
        $null = Invoke-Git $fixture.Work @('remote','set-url','origin',(Join-Path $fixture.Root 'missing.git'))
        $result = Invoke-Checker $fixture
        Assert ($result.Exit -eq 3) "unreachable remote exit was $($result.Exit): $($result.Out)"
        Assert ($result.Out -match 'CANT-VERIFY') "cannot-verify verdict missing: $($result.Out)"
    }

    It 'every release and eval push is preceded by the outgoing-commit guard' {
        $release = [IO.File]::ReadAllText((Join-Path $repoRoot '.claude/scripts/release.ps1'))
        $pushes = @(
            'git -C $repo push origin "${releaseCommit}:refs/heads/master"',
            'git -C $repo push origin "refs/tags/$tagName"',
            'git -C $repo push origin "${evalCommit}:refs/heads/master"'
        )
        Assert ($pushes.Count -eq 3) 'release push contract table is incomplete'
        $previousPush = -1
        foreach ($push in $pushes) {
            $pushIndex = $release.IndexOf($push, [StringComparison]::Ordinal)
            Assert ($pushIndex -gt $previousPush) "release push missing or out of order: $push"
            $checkIndex = $release.LastIndexOf('check-outgoing-commits.ps1', $pushIndex, [StringComparison]::Ordinal)
            Assert ($checkIndex -gt $previousPush) "release push has no outgoing check in its own phase: $push"
            $previousPush = $pushIndex
        }
    }
} finally {
    if ($null -eq $previousXdgConfigHome) { Remove-Item Env:XDG_CONFIG_HOME -ErrorAction SilentlyContinue }
    else { $env:XDG_CONFIG_HOME = $previousXdgConfigHome }
    if ($null -eq $previousGitConfigGlobal) { Remove-Item Env:GIT_CONFIG_GLOBAL -ErrorAction SilentlyContinue }
    else { $env:GIT_CONFIG_GLOBAL = $previousGitConfigGlobal }
    if ($null -eq $previousGitConfigNoSystem) { Remove-Item Env:GIT_CONFIG_NOSYSTEM -ErrorAction SilentlyContinue }
    else { $env:GIT_CONFIG_NOSYSTEM = $previousGitConfigNoSystem }
    foreach ($path in $scratch) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

exit (Write-TestSummary 'OutgoingCommits.Tests (B-219 outgoing commit guard)')
