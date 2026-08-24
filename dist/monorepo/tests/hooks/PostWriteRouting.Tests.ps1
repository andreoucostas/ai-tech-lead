# post-write surface routing + self-filter agreement between the .ps1 and .sh twins.
# Behavioral surface agreement: build-free self-filter worlds, an ambiguous empty-tool-name build
# failure, and an SSDT solution that must never invoke dotnet. Fake tool binaries make the routing
# observable without pinning implementation-shaped variable initialization or shell case text.
if (-not (Get-Command Reset-Tests -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$hooks = (Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks')).Path
$pwPs  = Join-Path $hooks 'post-write.ps1'
$pwSh  = Join-Path $hooks 'post-write.sh'
$bash  = Get-BashPath

Reset-Tests

$cases = @(
    @{ n = 'read-style payload (path, no content) self-filters to exit 0';
       claude = '{"tool_name":"Read","tool_input":{"file_path":"notes.txt"}}';
       copilot = '{"toolName":"view","toolArgs":{"path":"notes.txt"}}' },
    @{ n = 'write payload on a non-source path (.txt) exits 0 before any build';
       claude = '{"tool_name":"Write","tool_input":{"file_path":"notes.txt","content":"hello world"}}';
       copilot = '{"toolName":"create","toolArgs":{"path":"notes.txt","file_text":"hello world"}}' }
)
if (-not $bash) {
    foreach ($surface in 'claude','copilot') { Skip "post-write twins agree ($surface): build-free routing worlds" 'no bash found -- cannot run .sh twin' }
} else {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("pwroute-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    Push-Location $tmp
    try {
        foreach ($surface in 'claude','copilot') {
            It "post-write twins agree ($surface): build-free routing worlds" {
                foreach ($c in $cases) {
                    $evt = $c[$surface]
                    $dps = Get-Decision (Invoke-Hook $pwPs $evt)
                    $dsh = Get-Decision (Invoke-Hook $pwSh $evt)
                    Assert ($dps -eq $dsh) "$($c.n): post-write.ps1 -> $dps but post-write.sh -> $dsh"
                    Assert ($dps -eq 'ALLOW') "$($c.n): expected ALLOW (exit 0), got $dps"
                }

                if($surface-eq'claude'){
                    # Missing tool_name is ambiguous on Claude's matcher. A real failing build must
                    # route to Claude's exit-2 contract on both twins, not Copilot JSON/exit 0.
                    $failBin=Join-Path $tmp 'fail-bin';New-Item -ItemType Directory -Force $failBin|Out-Null
                    $dotnetHook=[IO.File]::ReadAllText($pwPs)-match'dotnet build';$probeFile=if($dotnetHook){'Probe.cs'}else{'tsconfig.json'}
                    if($dotnetHook){[IO.File]::WriteAllText((Join-Path $tmp 'App.csproj'),'<Project Sdk="Microsoft.NET.Sdk" />');[IO.File]::WriteAllText((Join-Path $tmp $probeFile),'class Probe {}')}
                    else{
                        $localBin=Join-Path $tmp 'node_modules/.bin';New-Item -ItemType Directory -Path $localBin -Force|Out-Null
                        [IO.File]::WriteAllText((Join-Path $localBin 'tsc'),"#!/bin/sh`necho simulated type failure >&2`nexit 1`n")
                        [IO.File]::WriteAllText((Join-Path $localBin 'tsc.cmd'),"@echo simulated type failure 1>&2`r`n@exit /b 1`r`n")
                        $posixTsc=ConvertTo-PosixPath(Join-Path $localBin 'tsc');$null=&$bash -c ('chmod +x "{0}"'-f$posixTsc);Assert($LASTEXITCODE-eq0)'could not make local tsc executable'
                        [IO.File]::WriteAllText((Join-Path $tmp 'angular.json'),'{"version":1}');[IO.File]::WriteAllText((Join-Path $tmp $probeFile),'{ broken json')
                    }
                    [IO.File]::WriteAllText((Join-Path $failBin 'dotnet'),"#!/bin/sh`necho simulated build failure >&2`nexit 1`n")
                    [IO.File]::WriteAllText((Join-Path $failBin 'dotnet.cmd'),"@echo simulated build failure 1>&2`r`n@exit /b 1`r`n")
                    [IO.File]::WriteAllText((Join-Path $failBin 'npx'),"#!/bin/sh`necho simulated type failure >&2`nexit 1`n")
                    [IO.File]::WriteAllText((Join-Path $failBin 'npx.cmd'),"@echo simulated type failure 1>&2`r`n@exit /b 1`r`n")
                    foreach($tool in 'dotnet','npx'){$posixTool=ConvertTo-PosixPath(Join-Path $failBin $tool);$null=&$bash -c ('chmod +x "{0}"'-f$posixTool);Assert($LASTEXITCODE-eq0)"could not make failing $tool executable"}
                    $oldPath=$env:PATH;try{$env:PATH=$failBin+[IO.Path]::PathSeparator+$oldPath;$ambiguous='{"tool_input":{"file_path":"'+$probeFile+'","content":"broken"}}';foreach($hook in $pwPs,$pwSh){Remove-Item -LiteralPath (Join-Path $tmp '.claude/.state') -Recurse -Force -ErrorAction SilentlyContinue;$decision=Get-Decision(Invoke-Hook $hook $ambiguous);Assert($decision-eq'BLOCK') "empty-tool-name build failure decision=$decision for $(Split-Path $hook -Leaf)"}}finally{$env:PATH=$oldPath}
                }

                # A warehouse SSDT solution is a build-relevant-looking file but not a .NET
                # application. A fake dotnet sentinel makes the absence of invocation observable.
                foreach($artifact in 'App.csproj','Probe.cs','angular.json','tsconfig.json','src','node_modules','fail-bin'){
                    Remove-Item -LiteralPath (Join-Path $tmp $artifact) -Recurse -Force -ErrorAction SilentlyContinue
                }
                Remove-Item -LiteralPath (Join-Path $tmp '.claude/.state') -Recurse -Force -ErrorAction SilentlyContinue
                $bin=Join-Path $tmp 'bin';$warehouse=Join-Path $tmp 'warehouse';$sentinel=Join-Path $tmp 'dotnet-invoked'
                New-Item -ItemType Directory -Path $bin,$warehouse -Force|Out-Null
                [IO.File]::WriteAllText((Join-Path $tmp 'Warehouse.sln'),'Microsoft Visual Studio Solution File`nProject = "Warehouse.sqlproj"')
                [IO.File]::WriteAllText((Join-Path $warehouse 'Warehouse.sqlproj'),'<Project Sdk="Microsoft.Build.Sql" />')
                [IO.File]::WriteAllText((Join-Path $bin 'dotnet'),"#!/bin/sh`nprintf invoked > `"`$POSTWRITE_DOTNET_SENTINEL`"`n")
                [IO.File]::WriteAllText((Join-Path $bin 'dotnet.cmd'),"@echo invoked> `"%POSTWRITE_DOTNET_SENTINEL%`"`r`n@exit /b 0`r`n")
                $posixDotnet=ConvertTo-PosixPath (Join-Path $bin 'dotnet');$null=& $bash -c ('chmod +x "{0}"' -f $posixDotnet)
                Assert ($LASTEXITCODE-eq 0) 'could not make fake dotnet executable'
                $oldPath=$env:PATH;$oldSentinel=$env:POSTWRITE_DOTNET_SENTINEL
                try {
                    $env:PATH=$bin+[IO.Path]::PathSeparator+$oldPath;$env:POSTWRITE_DOTNET_SENTINEL=$sentinel
                    $evt=if($surface-eq'claude'){'{"tool_name":"Write","tool_input":{"file_path":"Warehouse.sln","content":"SQL-only solution"}}'}else{'{"toolName":"create","toolArgs":{"path":"Warehouse.sln","file_text":"SQL-only solution"}}'}
                    foreach($hook in $pwPs,$pwSh){Remove-Item -LiteralPath $sentinel -Force -ErrorAction SilentlyContinue;$decision=Get-Decision (Invoke-Hook $hook $evt);Assert ($decision-eq'ALLOW') "SSDT solution decision=$decision for $(Split-Path $hook -Leaf)";Assert (-not(Test-Path -LiteralPath $sentinel)) "SSDT-only solution invoked dotnet in $(Split-Path $hook -Leaf)"}
                } finally {$env:PATH=$oldPath;$env:POSTWRITE_DOTNET_SENTINEL=$oldSentinel}
            }
        }
    } finally {
        Pop-Location
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

exit (Write-TestSummary 'PostWriteRouting.Tests (surface routing)')
