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
} finally {
    Pop-Location
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Write-TestSummary 'PostWriteRouting.Tests')
