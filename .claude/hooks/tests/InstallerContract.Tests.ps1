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
                    Assert ($guidance -match [regex]::Escape($expectCmd)) `
                        "$label : never names $expectCmd -- the developer is left with a half-installed repo."
                    # The wrong populate command is worse than none: /bootstrap on a brownfield repo
                    # skips the archive/merge/provenance flow the installer just staged.
                    $wrongCmd = if ($mode -eq 'greenfield') { '/adopt' } else { '/bootstrap' }
                    if ($mode -eq 'greenfield') {
                        Assert (-not ($guidance -match [regex]::Escape($wrongCmd))) "$label : names $wrongCmd, which is the other mode's command"
                    }
                }
            }
            finally { Remove-Item -Recurse -Force $target -ErrorAction SilentlyContinue }
    }
}

It '-GitHooks remains a non-mutating exit-2 compatibility refusal at both PowerShell entrypoints' {
    $target = Join-Path ([IO.Path]::GetTempPath()) ('git-hooks-retired-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path (Join-Path $target '.git/hooks') | Out-Null
    $hook = Join-Path $target '.git/hooks/pre-commit'
    [IO.File]::WriteAllText($hook, "#!/bin/sh`nCONSUMER SENTINEL`n", [Text.UTF8Encoding]::new($false))
    $before = [Convert]::ToBase64String([IO.File]::ReadAllBytes($hook))
    try {
        foreach ($entrypoint in @(
            [pscustomobject]@{ Name = 'root'; Path = (Join-Path $repoRoot 'install.ps1'); Arguments = @('-GitHooks', $target) },
            [pscustomobject]@{ Name = 'direct'; Path = (Join-Path $repoRoot 'src/core/scripts/install.ps1'); Arguments = @('-Target', $target, '-GitHooks') }
        )) {
            $out = & (Get-PsExe) -NoProfile -File $entrypoint.Path @($entrypoint.Arguments) 2>&1 | Out-String
            $code = $LASTEXITCODE
            Assert ($code -eq 2) "$($entrypoint.Name) -GitHooks refusal exited $code, expected 2: $out"
            Assert ($out -match '-GitHooks was retired in v0\.83\.0') "$($entrypoint.Name) refusal lacks retirement guidance"
            Assert ($out -match 'No Git hook was changed') "$($entrypoint.Name) refusal does not state the mutation boundary"
            Assert ($out -match 'framework-doctor\.ps1') "$($entrypoint.Name) refusal lacks the diagnostic next step"
            $expectedDoctor = if ($PSVersionTable.PSVersion.Major -ge 7) {
                'pwsh -NoProfile -File scripts/framework-doctor.ps1'
            } else {
                'powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/framework-doctor.ps1'
            }
            $flatOut = ($out -replace '\s+', ' ').Trim()
            Assert ($flatOut.Contains($expectedDoctor)) "$($entrypoint.Name) refusal did not print the canonical host-specific doctor command: $out"
            Assert ($out -notmatch 'OPERATION-PLAN|Done') "$($entrypoint.Name) refusal printed plan/completion output"
            Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($hook)) -ceq $before) "$($entrypoint.Name) refusal changed consumer hook bytes"
        }
    } finally { Remove-Item -Recurse -Force -LiteralPath $target -ErrorAction SilentlyContinue }
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
