# post-write.ps1 surface routing and self-filter behavior.
if (-not (Get-Command Reset-Tests -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$hooks = (Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks')).Path
. (Join-Path $PSScriptRoot 'fixtures\guard-patch-cases.ps1')
Reset-Tests

$cases = @(
    @{ n='read-style payload (path, no content) self-filters to exit 0'; claude='{"tool_name":"Read","tool_input":{"file_path":"notes.txt"}}'; copilot='{"toolName":"view","toolArgs":{"path":"notes.txt"}}' },
    @{ n='write payload on a non-source path exits 0 before any build'; claude='{"tool_name":"Write","tool_input":{"file_path":"notes.txt","content":"hello world"}}'; copilot='{"toolName":"create","toolArgs":{"path":"notes.txt","file_text":"hello world"}}' }
)
Assert ($cases.Count -gt 0) 'post-write routing case table is empty'

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('pwroute-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
# The hook finds its repository from its own path, so each case runs a copy installed in its fixture
# (with guard.ps1, whose patch split it loads for apply_patch).
$postWrite = Copy-HookInto (Join-Path $hooks 'post-write.ps1') $tmp
$null = Copy-HookInto (Join-Path $hooks 'guard.ps1') $tmp
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
    # build, tsc --noEmit via npx; the monorepo hook carries both; ngc --noEmit via npx for an Angular
    # template) runs against a shim on PATH.
    $hookText = [IO.File]::ReadAllText($postWrite)
    $worlds = @()
    if ($hookText -match 'dotnet build') { $worlds += @{ Name = 'dotnet'; Shim = 'dotnet.cmd'; Probe = 'Probe.cs' } }
    if ($hookText -match 'tsc --noEmit') { $worlds += @{ Name = 'tsc'; Shim = 'npx.cmd'; Probe = 'tsconfig.json' } }
    $templateWorld = @{ Name = 'ngc'; Shim = 'npx.cmd'; Probe = './src/app/probe.component.html' }
    if ($hookText -match 'ngc --noEmit') { $worlds += $templateWorld }
    Assert ($worlds.Count -gt 0) 'post-write carries neither a dotnet build nor a tsc --noEmit branch'
    function Reset-BuildWorld($World, [string]$ShimBody, [string]$Root = $tmp) {
        foreach ($artifact in 'Warehouse.sln','warehouse','bin','shim','.claude/.state','App.csproj','Probe.cs','tsconfig.json','node_modules','src') {
            Remove-Item -LiteralPath (Join-Path $Root $artifact) -Recurse -Force -ErrorAction SilentlyContinue
        }
        [void][IO.Directory]::CreateDirectory((Join-Path $Root 'shim'))
        if ($World.Name -eq 'dotnet') {
            [IO.File]::WriteAllText((Join-Path $Root 'App.csproj'), '<Project Sdk="Microsoft.NET.Sdk" />')
        } else {
            [void][IO.Directory]::CreateDirectory((Join-Path $Root 'node_modules'))
        }
        if ($World.Name -eq 'ngc') {
            # An Angular workspace: a tsconfig above the template and the Angular compiler installed.
            foreach ($folder in 'node_modules/@angular/compiler-cli', 'src/app') { [void][IO.Directory]::CreateDirectory((Join-Path $Root $folder)) }
            [IO.File]::WriteAllText((Join-Path $Root 'node_modules/@angular/compiler-cli/package.json'), '{"name":"@angular/compiler-cli"}')
            [IO.File]::WriteAllText((Join-Path $Root 'tsconfig.json'), '{}')
        }
        [IO.File]::WriteAllText((Join-Path $Root $World.Probe), 'probe')
        [IO.File]::WriteAllText((Join-Path $Root "shim/$($World.Shim)"), $ShimBody)
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

    # The hook runs from the repository that holds it, wherever the host starts it (a sandboxed host may start
    # it at the drive root), and names every path literally: a folder name such as 'Dev [App]' is a wildcard
    # pattern to a non-literal Test-Path, which then finds no workspace and checks nothing. Either way one
    # check runs per throttle window and its state stays in that repository.
    foreach ($place in 'another folder', 'a folder named with brackets') {
        It "a write runs one check per throttle window and keeps its state in its repository, started from $place" {
            foreach ($world in $worlds) {
                $repo = Join-Path $tmp $(if ($place -eq 'another folder') { 'placed-repo' } else { 'Dev [App]' })
                $elsewhere = Join-Path $tmp 'elsewhere'
                $shimDir = Join-Path $tmp 'placed-shim'
                $counter = Join-Path $tmp 'build-count'
                Remove-Item -LiteralPath $repo, $elsewhere, $shimDir, $counter -Recurse -Force -ErrorAction SilentlyContinue
                foreach ($folder in $elsewhere, $shimDir) { [void][IO.Directory]::CreateDirectory($folder) }
                $hook = Copy-HookInto (Join-Path $hooks 'post-write.ps1') $repo
                $shimBody = "@echo run>> `"%POSTWRITE_COUNTER%`"`r`n@exit /b 0`r`n"
                $null = Reset-BuildWorld $world $shimBody $repo
                [IO.File]::WriteAllText((Join-Path $shimDir $world.Shim), $shimBody)
                $writeEvent = @{ tool_name = 'Write'; tool_input = @{ file_path = [IO.Path]::GetFullPath((Join-Path $repo $world.Probe)); content = 'probe' } } | ConvertTo-Json -Compress
                # Windows PowerShell 5.1's Start-Process cannot launch from a bracketed location, so the
                # bracketed repository is reached from the folder above it.
                $start = if ($place -eq 'another folder') { $elsewhere } else { $tmp }
                $oldPath = $env:PATH; $oldCounter = $env:POSTWRITE_COUNTER
                Push-Location -LiteralPath $start
                try {
                    $env:PATH = $shimDir + [IO.Path]::PathSeparator + $oldPath
                    $env:POSTWRITE_COUNTER = $counter
                    foreach ($attempt in 1, 2) {
                        $result = Invoke-Hook $hook $writeEvent
                        Assert ((Get-Decision $result) -eq 'ALLOW') "$($world.Name): write $attempt was not allowed: exit $($result.Exit), stderr $($result.Err.Trim())"
                    }
                    $runs = if (Test-Path -LiteralPath $counter) { @(Get-Content -LiteralPath $counter).Count } else { 0 }
                    Assert ($runs -eq 1) "$($world.Name): expected exactly one check across two writes inside the window, got $runs"
                    $state = @(Get-ChildItem -LiteralPath (Join-Path $repo '.claude\.state') -Filter 'last-*' -File -ErrorAction SilentlyContinue)
                    Assert ($state.Count -gt 0) "$($world.Name): no throttle stamp in the repository's .claude\.state"
                    Assert (-not (Test-Path -LiteralPath (Join-Path $elsewhere '.claude'))) "$($world.Name): the hook wrote .claude into the folder it was started from"
                } finally { Pop-Location; $env:PATH = $oldPath; $env:POSTWRITE_COUNTER = $oldCounter }
            }
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

    # NETSDK1004/1005 mean the packages were never restored (or the target framework changed since): the
    # build examined nothing, so the hook must say "not verified", never "fix before continuing".
    if (@($worlds | Where-Object { $_.Name -eq 'dotnet' }).Count -eq 0) {
        Skip 'an unrestored .NET project is reported as not verified, never as a failed build' 'this post-write carries no dotnet build branch' -Invariant
    } else {
        It 'an unrestored .NET project is reported as not verified, never as a failed build' {
            $world = @($worlds | Where-Object { $_.Name -eq 'dotnet' })[0]
            $writeEvent = Reset-BuildWorld $world "@echo App.csproj : error NETSDK1004: Assets file 'obj\project.assets.json' not found. Run a NuGet package restore to generate this file.`r`n@exit /b 1`r`n"
            $oldPath = $env:PATH
            try {
                $env:PATH = (Join-Path $tmp 'shim') + [IO.Path]::PathSeparator + $oldPath
                $first = Invoke-Hook $postWrite $writeEvent
                Assert ((Get-Decision $first) -eq 'ALLOW') "an unrestored project blocked the write as a failed build: $($first.Err.Trim())"
                Assert ($first.Out -match 'Build not verified' -and $first.Out -match 'dotnet restore') "the hook did not say the build was not verified: $($first.Out.Trim())"
                $second = Invoke-Hook $postWrite $writeEvent
                Assert ((Get-Decision $second) -eq 'ALLOW' -and $second.Out -notmatch 'Build not verified') "the unverified build was retried inside the back-off: $($second.Out.Trim())"
            } finally { $env:PATH = $oldPath }
        }
    }

    # A component template write runs ngc --noEmit. ngc reports only on stderr, in color, in source order;
    # extended-diagnostic warnings after the error push the stderr past 20 lines.
    if ($hookText -notmatch 'tsc --noEmit') {
        Skip 'a template write with a failing template check is reported on both surfaces' 'this post-write carries no Angular branch' -Invariant
        Skip 'a template write outside an Angular workspace never runs a check' 'this post-write carries no Angular branch' -Invariant
    } else {
        It 'a template write with a failing template check is reported on both surfaces' {
            $shim = (@(
                '@echo %*> "%POSTWRITE_ARGS%"',
                '@echo <E>[96msrc/app/probe.component.html<E>[0m:<E>[93m1<E>[0m:<E>[93m4<E>[0m - <E>[91merror<E>[0m<E>[90m TS2339: <E>[0mProperty ''b329Missing'' does not exist on type ''ProbeComponent''. 1>&2',
                '@echo. 1>&2',
                '@echo <E>[7m1<E>[0m {{ b329Missing() }} 1>&2',
                '@echo <E>[7m <E>[0m <E>[91m   ~~~~~~~~~~~<E>[0m 1>&2',
                '@echo. 1>&2',
                '@echo   <E>[96msrc/app/probe.component.ts<E>[0m:<E>[93m4<E>[0m:<E>[93m16<E>[0m 1>&2',
                '@echo     <E>[7m4<E>[0m   templateUrl: ''./probe.component.html'', 1>&2',
                '@echo     <E>[7m <E>[0m <E>[96m               ~~~~~~~~~~~~~~~~~~~~~~~~<E>[0m 1>&2',
                '@echo     Error occurs in the template of component ProbeComponent. 1>&2'
            ) + @(foreach ($line in 2, 3) { @(
                "@echo <E>[96msrc/app/probe.component.html<E>[0m:<E>[93m$line<E>[0m:<E>[93m10<E>[0m - <E>[93mwarning<E>[0m<E>[90m NG8107: <E>[0mThe left side of this optional chain operation does not include 'null' or 'undefined' in its type. 1>&2",
                "@echo <E>[7m$line<E>[0m {{ title()?.length }} 1>&2",
                '@echo <E>[7m <E>[0m <E>[93m          ~~~~~~<E>[0m 1>&2',
                '@echo   <E>[96msrc/app/probe.component.ts<E>[0m:<E>[93m4<E>[0m:<E>[93m16<E>[0m 1>&2',
                '@echo     <E>[7m4<E>[0m   templateUrl: ''./probe.component.html'', 1>&2',
                '@echo     <E>[7m <E>[0m <E>[96m               ~~~~~~~~~~~~~~~~~~~~~~~~<E>[0m 1>&2',
                '@echo     Warning occurs in the template of component ProbeComponent. 1>&2'
            ) }) + @('@exit /b 1') -join "`r`n").Replace('<E>', [string][char]27) + "`r`n"
            $claudePayload = Reset-BuildWorld $templateWorld $shim
            $copilotPayload = '{"toolName":"create","toolArgs":{"path":"./src/app/probe.component.html","file_text":"{{ b329Missing() }}"}}'
            $argsFile = Join-Path $tmp 'npx-args'
            $oldPath = $env:PATH; $oldArgs = $env:POSTWRITE_ARGS
            try {
                $env:PATH = (Join-Path $tmp 'shim') + [IO.Path]::PathSeparator + $oldPath
                $env:POSTWRITE_ARGS = $argsFile
                $claude = Invoke-Hook $postWrite $claudePayload
                $copilot = Invoke-Hook $postWrite $copilotPayload
                $claudeDecision = Get-Decision $claude
                $copilotReported = ((Get-Decision $copilot) -eq 'ALLOW') -and ($copilot.Out -match 'additionalContext') -and ($copilot.Out -match 'b329Missing')
                Assert ($claudeDecision -eq 'BLOCK' -and $copilotReported) "a failing template check was not reported on both surfaces: Claude $claudeDecision (exit $($claude.Exit)), Copilot additionalContext $copilotReported"
                Assert ($claude.Err -match '## ngc --noEmit failed -- fix before continuing') "the Claude report lacks the ngc header: $($claude.Err.Trim())"
                Assert ($claude.Err -match "TS2339: Property 'b329Missing'") "the stderr tail lost the compiler error line: $($claude.Err.Trim())"
                Assert ($claude.Err.IndexOf([char]27) -lt 0) 'the report still carries ANSI color codes'
                $argText = [IO.File]::ReadAllText($argsFile)
                Assert ($argText -match '"ngc"' -and $argText -match '"--noEmit"' -and $argText -notmatch '"tsc"') "the template write did not run ngc --noEmit: $argText"
            } finally { $env:PATH = $oldPath; $env:POSTWRITE_ARGS = $oldArgs }
        }
        It 'a template write outside an Angular workspace never runs a check' {
            $sentinel = Join-Path $tmp 'npx-invoked'
            $null = Reset-BuildWorld $templateWorld "@echo invoked> `"%POSTWRITE_NPX_SENTINEL%`"`r`n@exit /b 1`r`n"
            Remove-Item -LiteralPath (Join-Path $tmp 'node_modules/@angular') -Recurse -Force
            $oldPath = $env:PATH; $oldSentinel = $env:POSTWRITE_NPX_SENTINEL
            try {
                $env:PATH = (Join-Path $tmp 'shim') + [IO.Path]::PathSeparator + $oldPath
                $env:POSTWRITE_NPX_SENTINEL = $sentinel
                foreach ($payload in @(
                    '{"tool_name":"Write","tool_input":{"file_path":"./src/app/probe.component.html","content":"<p>static page</p>"}}',
                    '{"toolName":"create","toolArgs":{"path":"./src/app/probe.component.html","file_text":"<p>static page</p>"}}'
                )) {
                    Remove-Item -LiteralPath $sentinel -Force -ErrorAction SilentlyContinue
                    $decision = Get-Decision (Invoke-Hook $postWrite $payload)
                    Assert ($decision -eq 'ALLOW' -and -not (Test-Path -LiteralPath $sentinel)) "a template write without @angular/compiler-cli ran a check: decision $decision, npx invoked $(Test-Path -LiteralPath $sentinel)"
                }
            } finally { $env:PATH = $oldPath; $env:POSTWRITE_NPX_SENTINEL = $oldSentinel }
        }
    }

    # Since Angular CLI 20 the root tsconfig.json is solution-style ("files": [] plus "references"). In a
    # workspace with no tsconfig.app.json, such as a library-only one, tsc or ngc against it checks nothing
    # and exits 0: the hook must say the write was not verified instead of passing it.
    if ($hookText -notmatch 'tsc --noEmit') {
        Skip 'a solution-style tsconfig is never checked and the write is reported as not verified on both surfaces' 'this post-write carries no Angular branch' -Invariant
    } else {
        # The CLI's application layout keeps the same root tsconfig.json beside a tsconfig.app.json, which is checked.
        It 'a solution-style tsconfig is never checked and the write is reported as not verified on both surfaces' {
            $null = Reset-BuildWorld $templateWorld "@echo %*> `"%POSTWRITE_ARGS%`"`r`n@exit /b 0`r`n"
            Remove-Item -LiteralPath (Join-Path $tmp 'src') -Recurse -Force
            [IO.File]::WriteAllText((Join-Path $tmp 'tsconfig.json'), "/* To learn more about Typescript configuration file: https://www.typescriptlang.org/docs/handbook/tsconfig-json.html. */`n{`n  `"compileOnSave`": false,`n  `"compilerOptions`": { `"strict`": true },`n  `"files`": [],`n  `"references`": [`n    { `"path`": `"./projects/lib/tsconfig.lib.json`" },`n    { `"path`": `"./projects/lib/tsconfig.spec.json`" }`n  ]`n}`n")
            New-Item -ItemType Directory -Path (Join-Path $tmp 'projects/lib/src/lib') -Force | Out-Null
            [IO.File]::WriteAllText((Join-Path $tmp 'projects/lib/tsconfig.lib.json'), '{ "extends": "../../tsconfig.json", "include": ["src/**/*.ts"], "exclude": ["src/**/*.spec.ts"] }')
            $argsFile = Join-Path $tmp 'npx-args'
            $oldPath = $env:PATH; $oldArgs = $env:POSTWRITE_ARGS
            try {
                $env:PATH = (Join-Path $tmp 'shim') + [IO.Path]::PathSeparator + $oldPath
                $env:POSTWRITE_ARGS = $argsFile
                foreach ($probe in './projects/lib/src/lib/probe.ts', './projects/lib/src/lib/probe.component.html') {
                    [IO.File]::WriteAllText((Join-Path $tmp $probe), 'probe')
                    foreach ($payload in @(
                        ('{"tool_name":"Write","tool_input":{"file_path":"' + $probe + '","content":"probe"}}'),
                        ('{"toolName":"create","toolArgs":{"path":"' + $probe + '","file_text":"probe"}}')
                    )) {
                        Remove-Item -LiteralPath (Join-Path $tmp '.claude/.state'), $argsFile -Recurse -Force -ErrorAction SilentlyContinue
                        $result = Invoke-Hook $postWrite $payload
                        $ran = if (Test-Path -LiteralPath $argsFile) { [IO.File]::ReadAllText($argsFile).Trim() } else { '' }
                        Assert ($ran -eq '') "${probe}: a check ran against the solution-style tsconfig.json and passed: npx $ran"
                        Assert ((Get-Decision $result) -eq 'ALLOW' -and $result.Out -match 'additionalContext' -and $result.Out -match 'Type-check not verified: tsconfig\.json is solution-style') "${probe}: the write was not reported as not verified, naming tsconfig.json from the repository root: exit $($result.Exit), stdout $($result.Out.Trim()), stderr $($result.Err.Trim())"
                    }
                }
                [IO.File]::WriteAllText((Join-Path $tmp 'tsconfig.app.json'), '{ "extends": "./tsconfig.json", "include": ["src/**/*.ts"], "exclude": ["src/**/*.spec.ts"] }')
                New-Item -ItemType Directory -Path (Join-Path $tmp 'src/app') -Force | Out-Null
                [IO.File]::WriteAllText((Join-Path $tmp 'src/app/probe.ts'), 'probe')
                Remove-Item -LiteralPath (Join-Path $tmp '.claude/.state'), $argsFile -Recurse -Force -ErrorAction SilentlyContinue
                $result = Invoke-Hook $postWrite '{"tool_name":"Write","tool_input":{"file_path":"./src/app/probe.ts","content":"probe"}}'
                $ran = if (Test-Path -LiteralPath $argsFile) { [IO.File]::ReadAllText($argsFile).Trim() } else { '' }
                Assert ($ran -match '"tsc"' -and $ran -match '"-p" "tsconfig\.app\.json"' -and $result.Out -notmatch 'not verified') "an application write beside the solution-style tsconfig.json was not checked against tsconfig.app.json: npx $ran, stdout $($result.Out.Trim())"
            } finally {
                $env:PATH = $oldPath; $env:POSTWRITE_ARGS = $oldArgs
                Remove-Item -LiteralPath (Join-Path $tmp 'projects'), (Join-Path $tmp 'tsconfig.app.json') -Recurse -Force -ErrorAction SilentlyContinue
            }
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
            $oldPath = $env:PATH
            try {
                $env:PATH = (Join-Path $tmp 'shim') + [IO.Path]::PathSeparator + $oldPath
                $result = Invoke-RawProcess -FileName (Get-PsExe) -Arguments @('-NoProfile', '-Command', $command) -Stdin $writeEvent
                Assert ($result.Exit -eq 2) "$($world.Name): failing build exited $($result.Exit) through the outer -Command shell, not 2; the host reads anything but 2 as a non-blocking error and the agent is never told. stderr: $($result.Err.Trim())"
                Assert ($result.Err -match 'fix before continuing') "$($world.Name): the outer -Command shell lost the failure report on stderr: $($result.Err.Trim())"
            } finally { $env:PATH = $oldPath }
        }
    }

    # apply_patch, in the envelopes Copilot CLI 1.0.95 sent its two hook files (fixtures/guard-patch-cases.ps1):
    # toolName apply_patch from .github/hooks/hooks.json gets the additionalContext JSON, tool_name Edit from
    # .claude/settings.json the exit 2. The patch's first file is one no check reads, so the checked file
    # must come from its second section.
    foreach ($shape in 'hooks.json', '.claude/settings.json') {
        It "an apply_patch write with a failing build or type-check is reported ($shape)" {
            foreach ($world in $worlds) {
                $null = Reset-BuildWorld $world "@echo simulated build failure 1>&2`r`n@exit /b 1`r`n"
                $patch = "*** Begin Patch`n*** Add File: notes.txt`n+hello`n*** Update File: $($world.Probe)`n@@`n-probe`n+probe 2`n*** End Patch`n"
                $oldPath = $env:PATH
                try {
                    $env:PATH = (Join-Path $tmp 'shim') + [IO.Path]::PathSeparator + $oldPath
                    $result = Invoke-Hook $postWrite (New-PatchEvent $shape $patch)
                    if ($shape -eq 'hooks.json') {
                        Assert ($result.Exit -eq 0 -and $result.Out -match '"additionalContext"' -and $result.Out -match 'fix before continuing') "$($world.Name): expected exit 0 with the failure as additionalContext, got exit $($result.Exit), stdout: $($result.Out.Trim())"
                    } else {
                        Assert ($result.Exit -eq 2 -and $result.Err -match 'fix before continuing') "$($world.Name): expected exit 2 with the failure on stderr, got exit $($result.Exit), stderr: $($result.Err.Trim())"
                    }
                } finally { $env:PATH = $oldPath }
            }
        }
    }

    # A V4A patch and Copilot's edit name files repository-relative, with no './' in front: a bare
    # 'src/app/probe.ts' has no character before 'src', so a gate that wants '/src/' drops it unchecked.
    if ($hookText -notmatch 'tsc --noEmit') {
        Skip 'a repository-relative src path with no ./ is type-checked on every write shape' 'this post-write carries no Angular branch' -Invariant
    } else {
        It 'a repository-relative src path with no ./ is type-checked on every write shape' {
            foreach ($probe in 'src/app/probe.ts', 'src/app/probe.component.html') {
                $relWorld = @{ Name = 'ngc'; Shim = 'npx.cmd'; Probe = $probe }
                $null = Reset-BuildWorld $relWorld "@echo simulated type failure 1>&2`r`n@exit /b 1`r`n"
                $patch = "*** Begin Patch`n*** Add File: notes.txt`n+hello`n*** Update File: $probe`n@@`n-probe`n+probe 2`n*** End Patch`n"
                $oldPath = $env:PATH
                try {
                    $env:PATH = (Join-Path $tmp 'shim') + [IO.Path]::PathSeparator + $oldPath
                    foreach ($shape in 'hooks.json', '.claude/settings.json') {
                        Remove-Item -LiteralPath (Join-Path $tmp '.claude/.state') -Recurse -Force -ErrorAction SilentlyContinue
                        $result = Invoke-Hook $postWrite (New-PatchEvent $shape $patch)
                        if ($shape -eq 'hooks.json') {
                            Assert ($result.Exit -eq 0 -and $result.Out -match '"additionalContext"' -and $result.Out -match 'failed -- fix before continuing') "${probe} apply_patch ($shape): expected exit 0 with the failure as additionalContext, got exit $($result.Exit), stdout: $($result.Out.Trim())"
                        } else {
                            Assert ($result.Exit -eq 2 -and $result.Err -match 'failed -- fix before continuing') "${probe} apply_patch ($shape): expected exit 2 with the failure on stderr, got exit $($result.Exit), stderr: $($result.Err.Trim())"
                        }
                    }
                    Remove-Item -LiteralPath (Join-Path $tmp '.claude/.state') -Recurse -Force -ErrorAction SilentlyContinue
                    $copilot = Invoke-Hook $postWrite ('{"toolName":"edit","toolArgs":{"path":"' + $probe + '","new_str":"probe 2"}}')
                    Assert ($copilot.Exit -eq 0 -and $copilot.Out -match '"additionalContext"' -and $copilot.Out -match 'failed -- fix before continuing') "${probe} Copilot edit: expected exit 0 with the failure as additionalContext, got exit $($copilot.Exit), stdout: $($copilot.Out.Trim())"
                } finally { $env:PATH = $oldPath }
            }
        }
    }

    # The repository is the folder that holds the hook. A solution, tsconfig or node_modules in a folder
    # above it belongs to something else: the walk from the written file stops at the repository root.
    $outerRoot = Join-Path $tmp 'umbrella'
    function Reset-Umbrella {
        Remove-Item -LiteralPath $outerRoot -Recurse -Force -ErrorAction SilentlyContinue
        foreach ($folder in 'shop', 'shim') { [void][IO.Directory]::CreateDirectory((Join-Path $outerRoot $folder)) }
    }
    if ($hookText -notmatch 'dotnet build') {
        Skip 'a project walk stops at the repository root, so an umbrella solution above it is never built' 'this post-write carries no dotnet branch' -Invariant
    } else {
        It 'a project walk stops at the repository root, so an umbrella solution above it is never built' {
            Reset-Umbrella
            $repo = Join-Path $outerRoot 'shop'
            [void][IO.Directory]::CreateDirectory((Join-Path $repo 'src/Api'))
            [IO.File]::WriteAllText((Join-Path $repo 'src/Api/Api.csproj'), '<Project Sdk="Microsoft.NET.Sdk" />')
            [IO.File]::WriteAllText((Join-Path $repo 'src/Api/Foo.cs'), 'class Foo {}')
            [IO.File]::WriteAllText((Join-Path $outerRoot 'All.sln'), 'Microsoft Visual Studio Solution File`nProject = "Other\Other.csproj"')
            $argsFile = Join-Path $outerRoot 'dotnet-args'
            [IO.File]::WriteAllText((Join-Path $outerRoot 'shim/dotnet.cmd'), "@echo %*> `"%POSTWRITE_ARGS%`"`r`n@echo simulated build failure 1>&2`r`n@exit /b 1`r`n")
            $hook = Copy-HookInto (Join-Path $hooks 'post-write.ps1') $repo
            $oldPath = $env:PATH; $oldArgs = $env:POSTWRITE_ARGS
            try {
                $env:PATH = (Join-Path $outerRoot 'shim') + [IO.Path]::PathSeparator + $oldPath
                $env:POSTWRITE_ARGS = $argsFile
                $writeEvent = @{ tool_name = 'Edit'; tool_input = @{ file_path = (Join-Path $repo 'src\Api\Foo.cs'); old_string = 'Foo'; new_string = 'Bar' } } | ConvertTo-Json -Compress
                $result = Invoke-Hook $hook $writeEvent
                $ran = if (Test-Path -LiteralPath $argsFile) { [IO.File]::ReadAllText($argsFile).Trim() } else { '' }
                Assert ($ran -match 'Api\.csproj' -and $ran -notmatch 'All\.sln') "the build did not target the repository's own project: dotnet $ran"
                Assert ($result.Exit -eq 2) "the failing build of the repository's project was not reported: exit $($result.Exit), stderr $($result.Err.Trim())"
            } finally { $env:PATH = $oldPath; $env:POSTWRITE_ARGS = $oldArgs }
        }
    }
    if ($hookText -notmatch 'tsc --noEmit') {
        Skip 'a workspace walk stops at the repository root, so a tsconfig or node_modules above it is never used' 'this post-write carries no Angular branch' -Invariant
    } else {
        It 'a workspace walk stops at the repository root, so a tsconfig or node_modules above it is never used' {
            foreach ($above in 'tsconfig', 'node_modules') {
                Reset-Umbrella
                $repo = Join-Path $outerRoot 'shop'
                [void][IO.Directory]::CreateDirectory((Join-Path $repo 'src/app'))
                [IO.File]::WriteAllText((Join-Path $repo 'src/app/probe.ts'), 'probe')
                if ($above -eq 'tsconfig') {
                    [void][IO.Directory]::CreateDirectory((Join-Path $outerRoot 'node_modules'))
                    [IO.File]::WriteAllText((Join-Path $outerRoot 'tsconfig.json'), '{}')
                } else {
                    [IO.File]::WriteAllText((Join-Path $repo 'tsconfig.json'), '{}')
                    [void][IO.Directory]::CreateDirectory((Join-Path $outerRoot 'node_modules'))
                }
                $sentinel = Join-Path $outerRoot 'npx-invoked'
                [IO.File]::WriteAllText((Join-Path $outerRoot 'shim/npx.cmd'), "@echo invoked> `"%POSTWRITE_NPX_SENTINEL%`"`r`n@echo simulated type failure 1>&2`r`n@exit /b 1`r`n")
                $hook = Copy-HookInto (Join-Path $hooks 'post-write.ps1') $repo
                $oldPath = $env:PATH; $oldSentinel = $env:POSTWRITE_NPX_SENTINEL
                try {
                    $env:PATH = (Join-Path $outerRoot 'shim') + [IO.Path]::PathSeparator + $oldPath
                    $env:POSTWRITE_NPX_SENTINEL = $sentinel
                    $writeEvent = @{ tool_name = 'Write'; tool_input = @{ file_path = (Join-Path $repo 'src\app\probe.ts'); content = 'probe' } } | ConvertTo-Json -Compress
                    $result = Invoke-Hook $hook $writeEvent
                    Assert (-not (Test-Path -LiteralPath $sentinel)) "a $above above the repository was used: the type-check ran (exit $($result.Exit))"
                    Assert ((Get-Decision $result) -eq 'ALLOW') "a $above above the repository blocked the write: $($result.Err.Trim())"
                } finally { $env:PATH = $oldPath; $env:POSTWRITE_NPX_SENTINEL = $oldSentinel }
            }
        }
    }
} finally {
    Pop-Location
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Write-TestSummary 'PostWriteRouting.Tests')
