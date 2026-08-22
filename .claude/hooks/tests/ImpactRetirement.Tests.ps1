[CmdletBinding()]
param([switch]$SkipMutation)

# Regression coverage for Increment 2's intentionally inert compatibility path. The runners are
# exercised from each composed dist, because source-only success would not prove what ships.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
. (Join-Path $PSScriptRoot '_MutationHelper.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$bash = Get-BashPath
$expected = 'Impact runner retired: the former pre/post baseline was captured after installation, so it cannot support a comparative claim. No agent, tool, or worktree was invoked. This compatibility tombstone exits non-zero and will be removed by a future framework update.'
$dists = @('dotnet', 'angular', 'monorepo')

function Invoke-Tombstone {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$InvocationArgs,
        [string]$WorkingDirectory = ''
    )
    $stderr = [IO.Path]::GetTempFileName()
    try {
        if ($WorkingDirectory) { Push-Location -LiteralPath $WorkingDirectory }
        try {
            if ($Path -match '\.ps1$') {
                $out = & (Get-PsExe) -NoProfile -ExecutionPolicy Bypass -File $Path @InvocationArgs 2>$stderr | Out-String
            } else {
                if (-not $bash) { return $null }
                $out = & $bash $Path @InvocationArgs 2>$stderr | Out-String
            }
            return [pscustomobject]@{ Exit = [int]$LASTEXITCODE; Out = $out.Trim(); Err = [IO.File]::ReadAllText($stderr).Trim() }
        } finally {
            if ($WorkingDirectory) { Pop-Location }
        }
    } finally {
        if (Test-Path -LiteralPath $stderr) { Remove-Item -LiteralPath $stderr -Force }
    }
}

function New-ControlledGitRepository {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('impact-retirement-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    git -C $root init --quiet
    Assert ($LASTEXITCODE -eq 0) "could not initialise controlled Git repository: $root"
    git -C $root config user.email 'impact-retirement@example.invalid'
    git -C $root config user.name 'impact retirement test'
    [IO.File]::WriteAllText((Join-Path $root 'sentinel.txt'), 'unchanged', [Text.UTF8Encoding]::new($false))
    git -C $root add sentinel.txt
    git -C $root commit --quiet -m baseline
    Assert ($LASTEXITCODE -eq 0) "could not commit controlled Git repository: $root"
    return $root
}

function Get-TreeFingerprint {
    param([Parameter(Mandatory)][string]$Root)
    $rows = @(Get-ChildItem -LiteralPath $Root -Recurse -Force | Sort-Object FullName | ForEach-Object {
        $relative = $_.FullName.Substring($Root.Length).TrimStart('\', '/') -replace '\\', '/'
        if ($_.PSIsContainer) { "D|$relative" }
        else { "F|$relative|$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" }
    })
    return $rows -join "`n"
}

function Get-GitWorktreeList {
    param([Parameter(Mandatory)][string]$Root)
    $out = @(git -C $Root worktree list --porcelain 2>&1)
    Assert ($LASTEXITCODE -eq 0) "could not list controlled Git worktrees: $($out -join ' ')"
    return $out -join "`n"
}

function Assert-TombstoneResult {
    param($Result, [string]$Label)
    Assert ($null -ne $Result) "$Label did not run"
    Assert ($Result.Exit -ne 0) "$Label exited zero -- a retired runner must fail closed"
    Assert ($Result.Exit -eq 2) "$Label exit changed to $($Result.Exit); expected stable exit 2"
    Assert ($Result.Out -ceq $expected) "$Label explanatory output drifted: $($Result.Out)"
    Assert ([string]::IsNullOrEmpty($Result.Err)) "$Label wrote unexpected stderr: $($Result.Err)"
}

Reset-Tests

It 'every composed dist retains exactly the five retired compatibility paths' {
    foreach ($dist in $dists) {
        $root = Join-Path $repoRoot "dist/$dist"
        foreach ($relative in @('scripts/impact-run.ps1', 'scripts/impact-run.sh', 'tests/impact/README.md', 'tests/impact/config.json', 'tests/impact/tasks.json')) {
            Assert (Test-Path -LiteralPath (Join-Path $root $relative) -PathType Leaf) "$dist is missing retired compatibility path $relative"
        }
    }
}

It 'both tombstones reject varied and hostile arguments with stable output and no observable side effects' {
    $argumentSets = @(
        @(),
        @('--smoke', '--allow-all-tools'),
        @('$(whoami)', '; exit 0; #', '"quoted value"')
    )
    $controlled = New-ControlledGitRepository
    try {
        foreach ($dist in $dists) {
            foreach ($extension in @('ps1', 'sh')) {
                if ($extension -eq 'sh' -and -not $bash) { continue }
                $runner = Join-Path $repoRoot "dist/$dist/scripts/impact-run.$extension"
                foreach ($argumentSet in $argumentSets) {
                    $beforeTree = Get-TreeFingerprint $controlled
                    $beforeWorktrees = Get-GitWorktreeList $controlled
                    Assert-TombstoneResult (Invoke-Tombstone -Path $runner -InvocationArgs $argumentSet -WorkingDirectory $controlled) "$dist/$extension args=[$($argumentSet -join '|')]"
                    Assert ((Get-TreeFingerprint $controlled) -ceq $beforeTree) "$dist/$extension changed the controlled working-directory tree"
                    Assert ((Get-GitWorktreeList $controlled) -ceq $beforeWorktrees) "$dist/$extension changed the controlled Git worktree list"
                }
            }
        }
    } finally {
        if (Test-Path -LiteralPath $controlled) { Remove-Item -LiteralPath $controlled -Recurse -Force }
    }
}

It 'retired runner and compatibility artifacts contain no execution machinery' {
    $forbidden = @('(?i)\bcopilot(?:\.cmd|\.exe)?\b', '--allow-all-tools', '(?i)Invoke-Expression', '(?i)\bbash\s+-c\b', '(?i)\bgit\s+worktree\b', '(?i)\bRemove-Item\b', '(?i)\brm\s+-rf\b', '(?i)agent_cmd')
    foreach ($dist in $dists) {
        foreach ($relative in @('scripts/impact-run.ps1', 'scripts/impact-run.sh', 'tests/impact/README.md', 'tests/impact/config.json')) {
            $path = Join-Path $repoRoot "dist/$dist/$relative"
            $text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
            foreach ($pattern in $forbidden) {
                Assert ($text -notmatch $pattern) "$dist/$relative retains forbidden execution machinery '$pattern'"
            }
        }
        $config = Get-Content -LiteralPath (Join-Path $repoRoot "dist/$dist/tests/impact/config.json") -Raw | ConvertFrom-Json
        Assert ($config.status -ceq 'retired') "$dist compatibility config is not explicitly retired"
    }
}

It 'composed active carriers contain no stale baseline, mandatory-runner claim, or runner call' {
    $forbidden = @('(?i)impact-run', '(?i)Tier 2', '(?i)Phase 9.{0,80}mandatory', '(?i)old\s+framework\s+arm', '(?i)only\s+the\s+framework\s+differs', '(?i)capture\s+the\s+impact\s+baseline', '(?i)\bimpact\s+baseline\b')
    $carriers = @('.claude/commands/adopt.md', '.claude/commands/bootstrap.md', '.claude/commands/impact.md', '.github/prompts/impact.prompt.md', '.claude/hooks/session-start.ps1', '.claude/hooks/session-start.sh', 'scripts/install.ps1', 'scripts/install.sh')
    foreach ($dist in $dists) {
        foreach ($relative in $carriers) {
            $text = [IO.File]::ReadAllText((Join-Path $repoRoot "dist/$dist/$relative"), [Text.Encoding]::UTF8)
            foreach ($pattern in $forbidden) {
                Assert ($text -notmatch $pattern) "$dist/$relative retains stale impact claim or call '$pattern'"
            }
        }
    }
}

if (-not $SkipMutation) {
    It 'a stale baseline restored to bootstrap makes this suite fail' {
        Invoke-MutationRedTest -TargetFile (Join-Path $repoRoot 'dist/dotnet/.claude/commands/bootstrap.md') -ScratchSourceRoot $repoRoot -Find 'archive, provenance screen, and merge' -Replacement 'archive, provenance screen, merge, impact baseline' -Command {
            param($scratchTarget, $scratchRoot)
            $test = Join-Path $scratchRoot '.claude/hooks/tests/ImpactRetirement.Tests.ps1'
            $process = Start-Process -FilePath (Get-PsExe) -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $test, '-SkipMutation') -Wait -PassThru -NoNewWindow
            $global:LASTEXITCODE = $process.ExitCode
        } | Out-Null
    }
}

exit (Write-TestSummary 'ImpactRetirement.Tests')
