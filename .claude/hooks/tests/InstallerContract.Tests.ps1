# Asserts the shipped PowerShell installer prints the agent-handoff contract in every dist and mode.
# Does not ship.
#
# Why this exists: the installer's closing message is the one surface an installing AI agent is
# guaranteed to see (it fires at the moment the agent acts, whatever doc it did or didn't read).
# Its text was therefore load-bearing -- and nothing tested it. The greenfield branch had quietly
# drifted weaker than the brownfield one: it omitted "or replicate it by hand", and never warned
# that docs-sync-check fails BY DESIGN until /bootstrap runs. A real agent duly copied the files
# and walked away without committing them, and a red docs-sync-check reads to an agent as a bug to
# fix. Fixed in v0.26.3; this is the gate that keeps it fixed (meta/LEARNINGS.md, 2026-07-12).
#
# The contract is asserted as BEHAVIOR (run the installer, read stdout), not as prose in a source
# file -- which is the only way to catch a mode branch that silently stops printing it.
[CmdletBinding()]
param([switch]$SkipRedTest)
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
. (Join-Path $PSScriptRoot '_MutationHelper.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

# Every mode must state ALL of these. They are the things an agent gets wrong without them:
# leaves files uncommitted / thinks it may finish / hand-rolls the populate step / "fixes" a red check.
$contract = @(
    @{ Name = 'tells the agent to COMMIT the copied files'; Pattern = 'commit the copied files' },
    @{ Name = 'tells the agent its task is NOT complete until it hands off'; Pattern = 'NOT complete until' },
    @{ Name = 'forbids hand-replicating the populate command'; Pattern = 'replicate it by hand' },
    @{ Name = 'warns docs-sync-check is red BY DESIGN until populate runs'; Pattern = 'by design|until /(bootstrap|adopt) has run' }
    @{ Name = 'tells every developer to run framework-doctor locally'; Pattern = 'Each developer should run.+framework-doctor' }
    @{ Name = 'tells the agent what the developer must type'; Pattern = 'told the developer,?(?:\s+explicitly,)?\s+to\s+start\s+a\s+Claude\s+Code\s+or\s+(?:an\s+)?interactive\s+Copilot\s+CLI\s+session\s+in\s+the\s+target\s+repo\s+and\s+type\s+/(bootstrap|adopt)' }
    @{ Name = 'points the developer at the installed tutorial'; Pattern = 'docs/getting-started\.md' }
)

function New-Target {
    param([ValidateSet('greenfield', 'brownfield')][string]$Mode, [string]$Stack)
    $t = Join-Path ([IO.Path]::GetTempPath()) "instcontract-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $t | Out-Null
    if ($Stack -in @('dotnet', 'monorepo')) {
        New-Item -ItemType Directory -Force -Path (Join-Path $t 'api') | Out-Null
        Set-Content (Join-Path $t 'api/Api.csproj') '<Project Sdk="Microsoft.NET.Sdk.Web"></Project>' -Encoding utf8
    }
    if ($Stack -in @('angular', 'monorepo')) {
        New-Item -ItemType Directory -Force -Path (Join-Path $t 'web') | Out-Null
        Set-Content (Join-Path $t 'web/angular.json') '{"version":1}' -Encoding utf8
    }
    # An adoption signal is what flips greenfield -> brownfield. TECH_DEBT.md is one of them, so its
    # mere presence selects the /adopt branch; greenfield targets must carry NONE of them.
    if ($Mode -eq 'brownfield') { Set-Content (Join-Path $t 'TECH_DEBT.md') '# debt' -Encoding utf8 }
    $t
}

Reset-Tests

foreach ($dist in @('dotnet', 'angular', 'monorepo')) {
    foreach ($mode in @('greenfield', 'brownfield')) {
        $expectCmd = if ($mode -eq 'greenfield') { '/bootstrap' } else { '/adopt' }

            $label = "$dist/$mode/ps1"
            $target = New-Target -Mode $mode -Stack $dist
            $inst = Join-Path $repoRoot "dist/$dist/scripts/install.ps1"
            try {
                $out = & (Get-PsExe) -NoProfile -File $inst $target 2>&1 | Out-String
                $code = $LASTEXITCODE
                # The operation plan names every shipped command file. It is machine-readable
                # deployment data, not user guidance; otherwise PLAN create .../adopt.md makes a
                # correct greenfield /bootstrap handoff look like it recommends both workflows.
                $guidance = (($out -split "\r?\n") | Where-Object { $_ -notmatch '^PLAN ' }) -join [Environment]::NewLine

                It "installer states the whole agent contract: $label" {
                    # Exit first: this suite asserted stdout only, so an installer that printed the
                    # whole contract and THEN aborted was indistinguishable from a clean run. That is
                    # not hypothetical: an installer once aborted after copying files while suites
                    # that asserted only stdout stayed green (B-144).
                    Assert ($code -eq 0) `
                        "$label : installer exited $code. Output can be complete on a run that failed."
                    Assert ($guidance -match 'IF YOU ARE AN AI AGENT') `
                        "$label : no agent-addressed block at all. An installing agent is the primary reader of this output."
                    foreach ($c in $contract) {
                        Assert ($guidance -match $c.Pattern) `
                            "$label : installer never $($c.Name) (no match for /$($c.Pattern)/). Agents get this wrong without being told."
                    }
                    # Tool output that demands a sentence be repeated "word for word" read to an eval agent as an
                    # injection, and it declined the commit the same paragraph asked for (consumer-docs arm A).
                    Assert (-not ($guidance -match '(?i)word for word')) `
                        "$label : asks the agent to recite text word for word, which agents treat as untrusted tool output"
                    # Claude Code commits only when the user asks. Tool output pushing past that ("do not stop to ask")
                    # read as injection, and fewer eval agents committed, not more (consumer-docs arms A, A2).
                    Assert (-not ($guidance -match '(?i)do not stop to ask|part of the install you were asked')) `
                        "$label : tells the agent to commit without asking, which agents treat as prompt injection"
                    Assert ($guidance -match [regex]::Escape($expectCmd)) `
                        "$label : never names $expectCmd -- the developer is left with a half-installed repo."
                    # The wrong populate command is worse than none: /bootstrap on a brownfield repo
                    # skips the archive/merge/provenance flow the installer just staged.
                    $wrongCmd = if ($mode -eq 'greenfield') { '/adopt' } else { '/bootstrap' }
                    if ($mode -eq 'greenfield') {
                        Assert (-not ($guidance -match [regex]::Escape($wrongCmd))) "$label : names $wrongCmd, which is the other mode's command"
                    }
                    if ($mode -eq 'brownfield') {
                        # Every archived original must be reported as byte-verified against its frozen
                        # pre-move digest; a mode branch that stops doing this is the B-230 regression.
                        Assert ($out -match 'archived: .+ -> docs/pre-adoption/.+ \(pre/post-move bytes verified\)') `
                            "$label : brownfield install did not report a byte-verified archive move"
                        # An agent asked only to install must stop at the hand-off. Unattended adoption
                        # is offered only when the developer asked for it, never as an equal way to finish.
                        Assert (-not ($guidance -match '(?im)^\s*OR run headless')) `
                            "$label : offers the installing agent headless adoption as an alternative to handing off"
                        Assert ($guidance -match 'Only if the developer asked') `
                            "$label : does not limit headless adoption to a developer's request"
                    }
                }
            }
            finally { Remove-Item -Recurse -Force $target -ErrorAction SilentlyContinue }
    }
}

function Get-B220TreeFingerprint {
    param([Parameter(Mandatory)][string]$Root)
    $rootPath = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\', '/')
    return (@(Get-ChildItem -LiteralPath $rootPath -Recurse -Force | Sort-Object FullName | ForEach-Object {
        $relative = $_.FullName.Substring($rootPath.Length).TrimStart('\', '/') -replace '\\', '/'
        if ($_.PSIsContainer) { "D|$relative" }
        else { "F|$relative|$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" }
    }) -join "`n")
}

It '-GitHooks is rejected by native parameter binding before either entrypoint can mutate' {
    $target = Join-Path ([IO.Path]::GetTempPath()) ('git-hooks-retired-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path (Join-Path $target '.git/hooks') | Out-Null
    $hook = Join-Path $target '.git/hooks/pre-commit'
    [IO.File]::WriteAllText($hook, "#!/bin/sh`nCONSUMER SENTINEL`n", [Text.UTF8Encoding]::new($false))
    try {
        foreach ($entrypoint in @(
            [pscustomobject]@{ Name = 'root'; Path = (Join-Path $repoRoot 'install.ps1'); Arguments = @('-GitHooks', $target) },
            [pscustomobject]@{ Name = 'direct'; Path = (Join-Path $repoRoot 'src/core/scripts/install.ps1'); Arguments = @('-Target', $target, '-GitHooks') }
        )) {
            $before = Get-B220TreeFingerprint -Root $target
            $out = & (Get-PsExe) -NoProfile -File $entrypoint.Path @($entrypoint.Arguments) 2>&1 | Out-String
            $code = $LASTEXITCODE
            $after = Get-B220TreeFingerprint -Root $target
            Assert ($code -ne 0) "$($entrypoint.Name) unknown -GitHooks argument unexpectedly succeeded: $out"
            Assert ($out -match '(?i)(ParameterBindingException|NamedParameterNotFound|parameter cannot be found)' -and $out -match '(?i)GitHooks') "$($entrypoint.Name) did not report a native named-parameter binding error for GitHooks: $out"
            Assert ($out -notmatch 'was retired in v0\.83\.0|No Git hook was changed') "$($entrypoint.Name) reached the retired compatibility refusal: $out"
            Assert ($out -notmatch 'OPERATION-PLAN|Done') "$($entrypoint.Name) printed plan/completion output"
            Assert ($after -ceq $before) "$($entrypoint.Name) binding failure changed the target tree"
        }
    } finally { Remove-Item -Recurse -Force -LiteralPath $target -ErrorAction SilentlyContinue }
}

It 'a usage error (target not a directory, target is the template itself) exits exactly 2 with the message on stderr' {
    $inst = Join-Path $repoRoot 'src/core/scripts/install.ps1'
    $errFile = Join-Path ([IO.Path]::GetTempPath()) ('usage-exit-' + [guid]::NewGuid().ToString('N') + '.err')
    $rootInst = Join-Path $repoRoot 'install.ps1'
    # A cmd line `-Target "C:\x\dist\dotnet\"` reaches the script as `C:\x\dist\dotnet"` (the CRT reads \" as a quote).
    # Test-Path cannot evaluate that path; under ErrorActionPreference Stop it threw before the usage exit ran on Windows PowerShell 5.1.
    $quoteTail = '"' + (Join-Path $repoRoot 'dist') + '\"'
    try {
        foreach ($case in @(
            [pscustomobject]@{ Name = 'nonexistent target'; Script = $inst; Prefix = @('-Target'); Target = ('"' + (Join-Path $repoRoot ('nope-' + [guid]::NewGuid().ToString('N'))) + '"'); Pattern = 'is not a directory' },
            [pscustomobject]@{ Name = 'target is the template itself'; Script = $inst; Prefix = @('-Target'); Target = ('"' + (Join-Path $repoRoot 'src/core') + '"'); Pattern = 'template repo itself' },
            [pscustomobject]@{ Name = 'inner installer, target with a quote'; Script = $inst; Prefix = @('-Target'); Target = $quoteTail; Pattern = 'is not a directory' },
            [pscustomobject]@{ Name = 'root installer, target with a quote'; Script = $rootInst; Prefix = @(); Target = $quoteTail; Pattern = 'is not a directory' }
        )) {
            # Start-Process: Windows PowerShell 5.1 wraps native stderr piped through a redirection in an error record.
            $proc = Start-Process -FilePath (Get-PsExe) -ArgumentList (@('-NoProfile', '-File', ('"' + $case.Script + '"')) + $case.Prefix + @($case.Target)) `
                -Wait -PassThru -NoNewWindow -RedirectStandardError $errFile
            $code = $proc.ExitCode
            $err = [IO.File]::ReadAllText($errFile)
            Assert ($code -eq 2) "$($case.Name) exited $code, not the documented 2: $err"
            Assert ($err -match $case.Pattern) "$($case.Name) did not print its message on stderr: $err"
            Assert ($err -notmatch 'CategoryInfo|FullyQualifiedErrorId|WriteErrorException|Illegal characters') "$($case.Name) leaked a PowerShell error record: $err"
        }
    } finally { Remove-Item -Force -LiteralPath $errFile -ErrorAction SilentlyContinue }
}

if (-not $SkipRedTest) {
    It 'a missing contract line makes this suite fail' {
        $target = Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1'
        Invoke-MutationRedTest -TargetFile $target -ScratchSourceRoot $repoRoot `
            -Find 'Review and commit the copied files' -Replacement 'Review the copied files' `
            -Command {
                param($scratchTarget, $scratchRoot)
                $process = Start-Process -FilePath (Get-PsExe) -ArgumentList @('-NoProfile','-File',(Join-Path $scratchRoot '.claude/hooks/tests/InstallerContract.Tests.ps1'),'-SkipRedTest') -Wait -PassThru -NoNewWindow
                $global:LASTEXITCODE = $process.ExitCode
            } | Out-Null
    }
}

exit (Write-TestSummary 'InstallerContract.Tests (shipped PowerShell installer contract)')
