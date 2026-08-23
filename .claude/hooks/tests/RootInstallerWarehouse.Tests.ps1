[CmdletBinding()]
param(
    [switch]$SkipRedTest,
    [ValidateSet('ps1', 'sh')][string]$OnlyTwin,
    [switch]$OnlyWarehouse
)

. (Join-Path $PSScriptRoot '_HookHarness.ps1')
. (Join-Path $PSScriptRoot '_MutationHelper.ps1')
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$bash = Get-BashPath

function Add-WarehouseSignals([string]$Target) {
    $warehouse = Join-Path $Target 'warehouse'
    New-Item -ItemType Directory -Force -Path $warehouse | Out-Null
    [IO.File]::WriteAllText((Join-Path $warehouse 'DimCustomer.sql'), 'CREATE TABLE dw.DimCustomer (CustomerKey int, EffectiveFrom date, IsCurrent bit);')
    [IO.File]::WriteAllText((Join-Path $warehouse 'usp_LoadCustomer.sql'), 'CREATE PROC etl.usp_LoadCustomer @BatchId int AS SELECT 1;')
}

function New-Target([ValidateSet('warehouse', 'dotnet', 'mixed')][string]$Kind) {
    # Keep the fixture beneath the workspace parent so both Windows PowerShell and Git Bash
    # resolve the same physical path rather than their distinct /tmp mounts.
    $target = Join-Path (Split-Path -Parent $repo) ("root-installer-$Kind-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    if ($Kind -eq 'warehouse' -or $Kind -eq 'mixed') { Add-WarehouseSignals $target }
    if ($Kind -eq 'dotnet' -or $Kind -eq 'mixed') { [IO.File]::WriteAllText((Join-Path $target 'App.sln'), 'Microsoft Visual Studio Solution File, Format Version 12.00') }
    if ($Kind -eq 'mixed') { [IO.File]::WriteAllText((Join-Path $target 'angular.json'), '{"version":1}') }
    & git -C $target init --quiet 2>$null | Out-Null
    return $target
}

function Get-TargetFingerprint([string]$Target) {
    $parts = foreach ($file in Get-ChildItem -LiteralPath $Target -Recurse -Force -File | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } | Sort-Object FullName) {
        $relative = $file.FullName.Substring($Target.Length).TrimStart('\', '/') -replace '\\', '/'
        "${relative}:$((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash)"
    }
    return ($parts -join "`n")
}

function Get-GitState([string]$Target) {
    return ((& git -C $Target status --porcelain=v1 2>$null) -join "`n")
}

function Get-GitWorktrees([string]$Target) {
    return ((& git -C $Target worktree list --porcelain 2>$null) -join "`n")
}

function Invoke-RootInstaller([string]$Twin, [string]$Target, [string]$Stack = '') {
    if ($Twin -eq 'ps1') {
        $arguments = @('-NoProfile', '-File', (Join-Path $repo 'install.ps1'))
        if ($Stack) { $arguments += @('-Stack', $Stack) }
        $arguments += $Target
        $out = @(& (Get-PsExe) @arguments 2>&1 | ForEach-Object { $_.ToString() })
    } else {
        $arguments = @((Join-Path $repo 'install.sh'))
        if ($Stack) { $arguments += @('--stack', $Stack) }
        $arguments += $Target
        $out = @(& $bash @arguments 2>&1 | ForEach-Object { $_.ToString() })
    }
    return [pscustomobject]@{ Exit = [int]$LASTEXITCODE; Output = ($out -join "`n") }
}

function Get-OverrideFlag([string]$Twin) { if ($Twin -eq 'ps1') { return '-Stack dotnet' }; return '--stack dotnet' }

Reset-Tests
foreach ($twin in @('ps1', 'sh')) {
    if ($OnlyTwin -and $twin -ne $OnlyTwin) { continue }
    if ($twin -eq 'sh' -and -not $bash) { Skip "warehouse-only refusal ($twin)" 'no bash'; continue }

    It "warehouse-only auto-detection refuses before target mutation ($twin)" {
        $target = New-Target 'warehouse'
        try {
            $beforeTree = Get-TargetFingerprint $target
            $beforeGit = Get-GitState $target
            $beforeWorktrees = Get-GitWorktrees $target
            $result = Invoke-RootInstaller $twin $target
            Assert ($result.Exit -eq 2) "warehouse-only auto-detection exited $($result.Exit), expected 2: $($result.Output)"
            Assert ($result.Output -match 'Warehouse-only auto-detection refused: found warehouse signals:') "refusal did not name warehouse signals: $($result.Output)"
            Assert ($result.Output -match '(?i)found warehouse signals: (?:layers|loads|control|history)(?:, (?:layers|loads|control|history))+') "refusal did not report multiple detected signal categories: $($result.Output)"
            Assert ($result.Output -match '(?i)this release does not certify solution-free adoption') "refusal did not state the unsupported lifecycle boundary: $($result.Output)"
            Assert ($result.Output -match [regex]::Escape((Get-OverrideFlag $twin))) "refusal did not provide the explicit dotnet override: $($result.Output)"
            Assert ((Get-TargetFingerprint $target) -ceq $beforeTree) 'warehouse refusal changed target bytes before delegation'
            Assert ((Get-GitState $target) -ceq $beforeGit) 'warehouse refusal changed git state before delegation'
            Assert ((Get-GitWorktrees $target) -ceq $beforeWorktrees) 'warehouse refusal changed the target worktree list before delegation'
        } finally { Remove-Item -LiteralPath $target -Recurse -Force }
    }

    if ($OnlyWarehouse) { continue }

    It "explicit dotnet override remains observable for warehouse-only target ($twin)" {
        $target = New-Target 'warehouse'
        try {
            $result = Invoke-RootInstaller $twin $target 'dotnet'
            Assert ($result.Exit -eq 0) "explicit dotnet override exited $($result.Exit): $($result.Output)"
            Assert ($result.Output -match 'Stack: dotnet \(via (?:-Stack|--stack) flag\)') "explicit dotnet override was not observable: $($result.Output)"
            Assert (Test-Path -LiteralPath (Join-Path $target '.claude/commands/adopt.md')) 'explicit override did not delegate to the dotnet installer'
        } finally { Remove-Item -LiteralPath $target -Recurse -Force }
    }

    It "ordinary dotnet auto-detection remains available ($twin)" {
        $target = New-Target 'dotnet'
        try {
            $result = Invoke-RootInstaller $twin $target
            Assert ($result.Exit -eq 0) "ordinary dotnet auto-detection exited $($result.Exit): $($result.Output)"
            Assert ($result.Output -match 'Stack: dotnet \(via auto-detected') "ordinary dotnet target did not select dotnet: $($result.Output)"
        } finally { Remove-Item -LiteralPath $target -Recurse -Force }
    }

    It "mixed auto-detection remains monorepo rather than warehouse refusal ($twin)" {
        $target = New-Target 'mixed'
        try {
            $result = Invoke-RootInstaller $twin $target
            Assert ($result.Exit -eq 0) "mixed auto-detection exited $($result.Exit): $($result.Output)"
            Assert ($result.Output -match 'Stack: monorepo \(via auto-detected') "mixed target did not select monorepo: $($result.Output)"
            Assert ($result.Output -notmatch 'Warehouse-only auto-detection refused') "mixed target reached the warehouse-only refusal: $($result.Output)"
        } finally { Remove-Item -LiteralPath $target -Recurse -Force }
}
}

if (-not $SkipRedTest) {
    It 'a PowerShell mutation that restores the warehouse fallback makes this suite red and restores bytes' {
        Invoke-MutationRedTest -TargetFile (Join-Path $repo 'install.ps1') -ScratchSourceRoot $repo `
            -Find 'Die (Get-WarehouseRefusal -Signals $warehouseSignals)' `
            -Replacement "`$Stack = 'dotnet'; `$reason = 'broken warehouse fallback'" -Command {
                param($scratchTarget, $scratchRoot)
                $test = Join-Path $scratchRoot '.claude/hooks/tests/RootInstallerWarehouse.Tests.ps1'
                $process = Start-Process -FilePath (Get-PsExe) -ArgumentList @('-NoProfile', '-File', $test, '-SkipRedTest', '-OnlyTwin', 'ps1', '-OnlyWarehouse') -Wait -PassThru -NoNewWindow
                $global:LASTEXITCODE = $process.ExitCode
            } | Out-Null
    }
    if ($bash) {
        It 'a shell mutation that restores the warehouse fallback makes this suite red and restores bytes' {
            Invoke-MutationRedTest -TargetFile (Join-Path $repo 'install.sh') -ScratchSourceRoot $repo `
                -Find '      warehouse_only_refusal' `
                -Replacement '      stack="dotnet"; reason="broken warehouse fallback"' -Command {
                    param($scratchTarget, $scratchRoot)
                    $test = Join-Path $scratchRoot '.claude/hooks/tests/RootInstallerWarehouse.Tests.ps1'
                    $process = Start-Process -FilePath (Get-PsExe) -ArgumentList @('-NoProfile', '-File', $test, '-SkipRedTest', '-OnlyTwin', 'sh', '-OnlyWarehouse') -Wait -PassThru -NoNewWindow
                    $global:LASTEXITCODE = $process.ExitCode
                } | Out-Null
            }
        }
    }

exit (Write-TestSummary 'RootInstallerWarehouse.Tests')
