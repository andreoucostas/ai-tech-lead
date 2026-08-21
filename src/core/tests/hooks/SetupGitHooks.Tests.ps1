# The opt-in pre-commit convenience net: its SETUP contract.
#
# What this covers and why it is the half worth a test file: the scan itself is the shipped guard,
# which Guard.Tests already exercises against 40 cases on both surfaces and both twins. What is
# unique here is the refusal logic — setup must never take ownership of a repository that already
# has a hook owner. A framework that silently disables a team's existing checks has done real harm,
# and the failure would be invisible: their hooks simply stop running.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$setup = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\scripts')).Path 'setup-git-hooks.ps1'

function New-ScratchRepo {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ("setup-git-hooks-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    & git -C $dir init -q 2>&1 | Out-Null
    return $dir
}

function Invoke-Setup {
    param([string]$Target)
    $out = & (Get-Process -Id $PID).Path -NoProfile -File $setup -Target $Target 2>&1
    return [pscustomobject]@{ Exit = $LASTEXITCODE; Text = ($out | ForEach-Object { "$_" }) -join "`n" }
}

Reset-Tests

It 'installs the hook into a clean repository' {
    $repo = New-ScratchRepo
    try {
        $r = Invoke-Setup $repo
        Assert (Test-Path -LiteralPath (Join-Path $repo '.git/hooks/pre-commit')) "no pre-commit hook was written: $($r.Text)"
    } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
}

# The three refusal arms. Each asserts BOTH that setup refused and that it wrote nothing -- refusing
# loudly while still clobbering would pass a weaker assertion.
It 'refuses when the repository already has a pre-commit hook' {
    $repo = New-ScratchRepo
    try {
        $hook = Join-Path $repo '.git/hooks/pre-commit'
        [IO.File]::WriteAllText($hook, "#!/bin/sh`nexit 0`n")
        $before = [IO.File]::ReadAllText($hook)
        $r = Invoke-Setup $repo
        Assert ($r.Text -match '(?i)refus') "expected a refusal, got: $($r.Text)"
        Assert ([IO.File]::ReadAllText($hook) -eq $before) 'the existing pre-commit hook was overwritten'
    } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'refuses when core.hooksPath points elsewhere' {
    $repo = New-ScratchRepo
    try {
        & git -C $repo config core.hooksPath .githooks 2>&1 | Out-Null
        $r = Invoke-Setup $repo
        Assert ($r.Text -match '(?i)refus') "expected a refusal, got: $($r.Text)"
        Assert (-not (Test-Path -LiteralPath (Join-Path $repo '.git/hooks/pre-commit'))) 'a hook was written despite core.hooksPath naming another owner'
    } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'refuses when husky owns the hooks' {
    $repo = New-ScratchRepo
    try {
        New-Item -ItemType Directory -Path (Join-Path $repo '.husky') -Force | Out-Null
        $r = Invoke-Setup $repo
        Assert ($r.Text -match '(?i)refus') "expected a refusal, got: $($r.Text)"
        Assert (-not (Test-Path -LiteralPath (Join-Path $repo '.git/hooks/pre-commit'))) 'a hook was written despite husky owning the hooks'
    } finally { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
}

exit (Write-TestSummary 'SetupGitHooks.Tests (setup refusal contract)')
