# post-write.ps1 surface routing and self-filter behavior.
if (-not (Get-Command Reset-Tests -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$hooks = (Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks')).Path
$postWrite = Join-Path $hooks 'post-write.ps1'
Reset-Tests

$cases = @(
    @{ n='read-style payload (path, no content) self-filters to exit 0'; claude='{"tool_name":"Read","tool_input":{"file_path":"notes.txt"}}'; copilot='{"toolName":"view","toolArgs":{"path":"notes.txt"}}' },
    @{ n='write payload on a non-source path exits 0 before any build'; claude='{"tool_name":"Write","tool_input":{"file_path":"notes.txt","content":"hello world"}}'; copilot='{"toolName":"create","toolArgs":{"path":"notes.txt","file_text":"hello world"}}' }
)
Assert ($cases.Count -gt 0) 'post-write routing case table is empty'

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('pwroute-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
Push-Location $tmp
try {
    foreach ($surface in 'claude','copilot') {
        It "post-write allows build-free routing worlds ($surface)" {
            foreach ($case in $cases) {
                $decision = Get-Decision (Invoke-Hook $postWrite $case[$surface])
                Assert ($decision -eq 'ALLOW') "$($case.n): expected ALLOW, got $decision"
            }
        }
    }

    It 'missing Claude tool_name routes a real build failure to exit 2' {
        $failBin = Join-Path $tmp 'fail-bin'
        New-Item -ItemType Directory -Path $failBin -Force | Out-Null
        $dotnetHook = [IO.File]::ReadAllText($postWrite) -match 'dotnet build'
        $probeFile = if ($dotnetHook) { 'Probe.cs' } else { 'tsconfig.json' }
        if ($dotnetHook) {
            [IO.File]::WriteAllText((Join-Path $tmp 'App.csproj'), '<Project Sdk="Microsoft.NET.Sdk" />')
            [IO.File]::WriteAllText((Join-Path $tmp $probeFile), 'class Probe {}')
        } else {
            $localBin = Join-Path $tmp 'node_modules/.bin'
            New-Item -ItemType Directory -Path $localBin -Force | Out-Null
            [IO.File]::WriteAllText((Join-Path $localBin 'tsc.cmd'), "@echo simulated type failure 1>&2`r`n@exit /b 1`r`n")
            [IO.File]::WriteAllText((Join-Path $tmp 'angular.json'), '{"version":1}')
            [IO.File]::WriteAllText((Join-Path $tmp $probeFile), '{ broken json')
        }
        [IO.File]::WriteAllText((Join-Path $failBin 'dotnet.cmd'), "@echo simulated build failure 1>&2`r`n@exit /b 1`r`n")
        [IO.File]::WriteAllText((Join-Path $failBin 'npx.cmd'), "@echo simulated type failure 1>&2`r`n@exit /b 1`r`n")
        $oldPath = $env:PATH
        try {
            $env:PATH = $failBin + [IO.Path]::PathSeparator + $oldPath
            Remove-Item -LiteralPath (Join-Path $tmp '.claude/.state') -Recurse -Force -ErrorAction SilentlyContinue
            $event = '{"tool_input":{"file_path":"' + $probeFile + '","content":"broken"}}'
            Assert ((Get-Decision (Invoke-Hook $postWrite $event)) -eq 'BLOCK') 'empty-tool-name build failure did not use Claude exit-2 semantics'
        } finally { $env:PATH = $oldPath }
    }

    It 'SSDT-only solution never invokes dotnet' {
        foreach ($artifact in 'App.csproj','Probe.cs','angular.json','tsconfig.json','src','node_modules','fail-bin') {
            Remove-Item -LiteralPath (Join-Path $tmp $artifact) -Recurse -Force -ErrorAction SilentlyContinue
        }
        Remove-Item -LiteralPath (Join-Path $tmp '.claude/.state') -Recurse -Force -ErrorAction SilentlyContinue
        $bin = Join-Path $tmp 'bin'; $warehouse = Join-Path $tmp 'warehouse'; $sentinel = Join-Path $tmp 'dotnet-invoked'
        New-Item -ItemType Directory -Path $bin,$warehouse -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $tmp 'Warehouse.sln'), 'Microsoft Visual Studio Solution File`nProject = "Warehouse.sqlproj"')
        [IO.File]::WriteAllText((Join-Path $warehouse 'Warehouse.sqlproj'), '<Project Sdk="Microsoft.Build.Sql" />')
        [IO.File]::WriteAllText((Join-Path $bin 'dotnet.cmd'), "@echo invoked> `"%POSTWRITE_DOTNET_SENTINEL%`"`r`n@exit /b 0`r`n")
        $oldPath = $env:PATH; $oldSentinel = $env:POSTWRITE_DOTNET_SENTINEL
        try {
            $env:PATH = $bin + [IO.Path]::PathSeparator + $oldPath
            $env:POSTWRITE_DOTNET_SENTINEL = $sentinel
            foreach ($event in @(
                '{"tool_name":"Write","tool_input":{"file_path":"Warehouse.sln","content":"SQL-only solution"}}',
                '{"toolName":"create","toolArgs":{"path":"Warehouse.sln","file_text":"SQL-only solution"}}'
            )) {
                Remove-Item -LiteralPath $sentinel -Force -ErrorAction SilentlyContinue
                Assert ((Get-Decision (Invoke-Hook $postWrite $event)) -eq 'ALLOW') 'SSDT-only solution was blocked'
                Assert (-not (Test-Path -LiteralPath $sentinel)) 'SSDT-only solution invoked dotnet'
            }
        } finally { $env:PATH=$oldPath; $env:POSTWRITE_DOTNET_SENTINEL=$oldSentinel }
    }

    # Build-tool worlds for the throttle and budget cases: each tool branch the hook carries (dotnet
    # build, tsc --noEmit via npx; the monorepo hook carries both) runs against a shim on PATH.
    $hookText = [IO.File]::ReadAllText($postWrite)
    $worlds = @()
    if ($hookText -match 'dotnet build') { $worlds += @{ Name = 'dotnet'; Shim = 'dotnet.cmd'; Probe = 'Probe.cs' } }
    if ($hookText -match 'tsc --noEmit') { $worlds += @{ Name = 'tsc'; Shim = 'npx.cmd'; Probe = 'tsconfig.json' } }
    Assert ($worlds.Count -gt 0) 'post-write carries neither a dotnet build nor a tsc --noEmit branch'
    function Reset-BuildWorld($World, [string]$ShimBody) {
        foreach ($artifact in 'Warehouse.sln','warehouse','bin','shim','.claude','App.csproj','Probe.cs','tsconfig.json','node_modules') {
            Remove-Item -LiteralPath (Join-Path $tmp $artifact) -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path (Join-Path $tmp 'shim') -Force | Out-Null
        if ($World.Name -eq 'dotnet') {
            [IO.File]::WriteAllText((Join-Path $tmp 'App.csproj'), '<Project Sdk="Microsoft.NET.Sdk" />')
        } else {
            New-Item -ItemType Directory -Path (Join-Path $tmp 'node_modules') -Force | Out-Null
        }
        [IO.File]::WriteAllText((Join-Path $tmp $World.Probe), 'probe')
        [IO.File]::WriteAllText((Join-Path $tmp "shim/$($World.Shim)"), $ShimBody)
        return '{"tool_name":"Write","tool_input":{"file_path":"' + $World.Probe + '","content":"probe"}}'
    }

    It 'a second write inside the throttle window does not start another build' {
        foreach ($world in $worlds) {
            $counter = Join-Path $tmp 'build-count'
            Remove-Item -LiteralPath $counter -Force -ErrorAction SilentlyContinue
            $writeEvent = Reset-BuildWorld $world "@echo run>> `"%POSTWRITE_COUNTER%`"`r`n@exit /b 0`r`n"
            $oldPath = $env:PATH; $oldCounter = $env:POSTWRITE_COUNTER
            try {
                $env:PATH = (Join-Path $tmp 'shim') + [IO.Path]::PathSeparator + $oldPath
                $env:POSTWRITE_COUNTER = $counter
                foreach ($attempt in 1, 2) {
                    Assert ((Get-Decision (Invoke-Hook $postWrite $writeEvent)) -eq 'ALLOW') "$($world.Name): write $attempt was not allowed"
                }
                $runs = if (Test-Path -LiteralPath $counter) { @(Get-Content -LiteralPath $counter).Count } else { 0 }
                Assert ($runs -eq 1) "$($world.Name): expected exactly one run across two writes inside the window, got $runs"
            } finally { $env:PATH = $oldPath; $env:POSTWRITE_COUNTER = $oldCounter }
        }
    }

    # The harness waits for every process holding the hook's output pipe, so the elapsed bound also
    # proves the tool's process tree was killed rather than orphaned.
    It 'a build that outlives its budget is killed with its process tree and never blocks' {
        foreach ($world in $worlds) {
            # Sleeps about 30 s, then reports a failure the hook must never see.
            $writeEvent = Reset-BuildWorld $world "@ping -n 31 127.0.0.1 >nul`r`n@echo simulated build failure 1>&2`r`n@exit /b 1`r`n"
            $oldPath = $env:PATH; $oldBudget = $env:ATL_POSTWRITE_BUDGET_SEC
            try {
                $env:PATH = (Join-Path $tmp 'shim') + [IO.Path]::PathSeparator + $oldPath
                $env:ATL_POSTWRITE_BUDGET_SEC = '2'
                $clock = [Diagnostics.Stopwatch]::StartNew()
                $decision = Get-Decision (Invoke-Hook $postWrite $writeEvent)
                $elapsed = $clock.Elapsed.TotalSeconds
                Assert ($elapsed -lt 15) ("{0}: hook returned after {1:n1}s; the 2 s budget did not bound the run" -f $world.Name, $elapsed)
                Assert ($decision -eq 'ALLOW') "$($world.Name): a timed-out run must not block, got $decision"
            } finally { $env:PATH = $oldPath; $env:ATL_POSTWRITE_BUDGET_SEC = $oldBudget }
        }
    }

    # Every case above invokes post-write.ps1 directly. The agent host does not: the registration
    # carries "shell": "powershell", so the whole command STRING runs inside an outer PowerShell, and
    # `-Command` collapses a failing native command's exit code to 1 -- the build failure is then a
    # non-blocking hook error and never reaches the agent. Read the command registered for THIS host
    # and launch it as the host does, over a fixture repo holding the shipped hook and a failing
    # build tool. The registered path is repo-root-relative, so the fixture carries the hook.
    $registrationRelative = if ($PSVersionTable.PSVersion.Major -ge 6) { '.claude/settings.json' } else { '.claude/settings.windows.json' }
    $expectedInterpreter = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'powershell' }
    It "registered post-write command reports a build failure with exit 2 through the host's outer -Command shell ($registrationRelative)" {
        $registrationPath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path $registrationRelative
        Assert (Test-Path -LiteralPath $registrationPath -PathType Leaf) "registration file not found: $registrationRelative"
        $registration = [IO.File]::ReadAllText($registrationPath) | ConvertFrom-Json
        $registered = @(foreach ($group in @($registration.hooks.PostToolUse)) {
            foreach ($entry in @($group.hooks)) { if ([string]$entry.command -match 'post-write\.ps1') { [string]$entry.command } }
        })
        Assert ($registered.Count -eq 1) "expected exactly one registered post-write command in $registrationRelative, found $($registered.Count)"
        $command = $registered[0]
        Assert ((($command -split '\s+')[0]) -ceq $expectedInterpreter) "$registrationRelative registers '$((($command -split '\s+')[0]))', not '$expectedInterpreter'; this leg would relaunch the other PowerShell host"
        foreach ($world in $worlds) {
            $writeEvent = Reset-BuildWorld $world "@echo simulated build failure 1>&2`r`n@exit /b 1`r`n"
            New-Item -ItemType Directory -Path (Join-Path $tmp '.claude/hooks') -Force | Out-Null
            Copy-Item -LiteralPath $postWrite -Destination (Join-Path $tmp '.claude/hooks/post-write.ps1') -Force
            $oldPath = $env:PATH
            try {
                $env:PATH = (Join-Path $tmp 'shim') + [IO.Path]::PathSeparator + $oldPath
                $result = Invoke-RawProcess -FileName (Get-PsExe) -Arguments @('-NoProfile', '-Command', $command) -Stdin $writeEvent
                Assert ($result.Exit -eq 2) "$($world.Name): failing build exited $($result.Exit) through the outer -Command shell, not 2; the host reads anything but 2 as a non-blocking error and the agent is never told. stderr: $($result.Err.Trim())"
                Assert ($result.Err -match 'fix before continuing') "$($world.Name): the outer -Command shell lost the failure report on stderr: $($result.Err.Trim())"
            } finally { $env:PATH = $oldPath }
        }
    }
} finally {
    Pop-Location
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Write-TestSummary 'PostWriteRouting.Tests')
