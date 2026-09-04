# B-92 executable red-tests. These use real composed dists: synthetic JSON fixtures hid the prior
# false greens. Every child is bound explicitly to THIS PowerShell host so a native Windows
# PowerShell 5.1 run cannot silently upgrade its evidence to pwsh.
#
# -Only runs a SINGLE case by name. It exists so this file can dispatch itself: with no -Only the
# script becomes a driver that runs one child process per case, several at a time, and aggregates.
# Every case already builds its own temp dist copy and cleans it up, so the cases were independent
# long before they were run that way. A child process rather than a runspace is deliberate: each
# case invokes the validator and mutates its own tree, so process isolation makes "independent"
# true rather than hoped-for.
# Set VALIDATE_DIST_TESTS_THROTTLE=1 to force the old sequential behaviour when diagnosing.
param([string]$Only)
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
. (Join-Path $PSScriptRoot '_MutationHelper.ps1')
Reset-Tests
$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$validator = Join-Path $repo 'scripts\validate-dist.ps1'
$scratch = @()
Remove-StaleTestScratchTrees

function New-DistCopy {
    param([string]$Prefix = 'validate-dist-', [switch]$PowerShellOnly)
    $root = Join-Path ([IO.Path]::GetTempPath()) ($Prefix + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo 'dist\dotnet') -Destination $root -Recurse
    $script:scratch += $root
    $dist = Join-Path $root 'dotnet'

    # dist/ is deliberately not rebuilt by this source-only test change. Overlay the three current
    # registration sources so focused check-8 fixtures exercise the new 18-handler contract rather
    # than the previous released twin schema. The final release rebuild proves normal composition.
    Copy-Item -LiteralPath (Join-Path $repo 'src\stacks\dotnet\files\.claude\settings.json') -Destination (Join-Path $dist '.claude\settings.json') -Force
    Copy-Item -LiteralPath (Join-Path $repo 'src\core\.claude\settings.windows.json') -Destination (Join-Path $dist '.claude\settings.windows.json') -Force
    Copy-Item -LiteralPath (Join-Path $repo 'src\core\.github\hooks\hooks.json') -Destination (Join-Path $dist '.github\hooks\hooks.json') -Force

    if ($PowerShellOnly) {
        # Build the post-retirement topology in scratch without mutating generated dist/. The
        # released dist remains the input for every check that does not depend on shell retirement.
        Get-ChildItem -LiteralPath $dist -Recurse -Force -File -Filter *.sh | Remove-Item -Force
        foreach ($workflow in @('docs-sync-check.yml','template-ci.yml')) {
            Copy-Item -LiteralPath (Join-Path $repo "src\core\.github\workflows\$workflow") -Destination (Join-Path $dist ".github\workflows\$workflow") -Force
        }
    }
    return $root
}
function New-ValidatorRepoCopy {
    # Marker inventory derives from authoring src/, so its red fixture needs an isolated source tree
    # as well as an isolated dist. Never mutate the live shared snippets during a test run.
    $root = Join-Path ([IO.Path]::GetTempPath()) ('validate-dist-repo-' + [guid]::NewGuid().ToString('N'))
    foreach ($dir in @('scripts','src','dist')) { New-Item -ItemType Directory -Path (Join-Path $root $dir) -Force | Out-Null }
    Copy-Item -LiteralPath (Join-Path $repo 'scripts\validate-dist.ps1') -Destination (Join-Path $root 'scripts')
    Copy-Item -LiteralPath (Join-Path $repo 'scripts\meta-denylist.txt') -Destination (Join-Path $root 'scripts')
    Copy-Item -LiteralPath (Join-Path $repo 'src\core') -Destination (Join-Path $root 'src') -Recurse
    foreach ($stack in @('dotnet','angular','monorepo')) {
        $target = Join-Path $root "src\stacks\$stack"
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $repo "src\stacks\$stack\snippets") -Destination $target -Recurse
    }
    Copy-Item -LiteralPath (Join-Path $repo 'dist\dotnet') -Destination (Join-Path $root 'dist') -Recurse
    $script:scratch += $root
    return $root
}
function Invoke-Validator {
    param(
        [string]$Root,
        [string]$Check,
        [switch]$CombineSelectors
    )
    # Each focused case names the check that owns its planted defect.
    # Passed as an ARGUMENT, never an environment variable: an inherited ambient switch could
    # silently downgrade a run that asked for full validation (sol's review of this change).
    $argv = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$validator,'dotnet',$Root)
    if ($CombineSelectors) { $argv += '--content-only' }
    if ($Check) { $argv += @('-Check',$Check) }
    $out = & (Get-Process -Id $PID).Path @argv 2>&1; $code = $LASTEXITCODE
    return [pscustomobject]@{ Exit=$code; Out=($out -join "`n") }
}
function Assert-Case {
    param([string]$Name, [scriptblock]$Mutate, [string]$Finding, [string]$Check, [switch]$Green, [switch]$PowerShellOnly, [string[]]$AlsoPattern=@())
    $root = New-DistCopy -PowerShellOnly:$PowerShellOnly
    & $Mutate (Join-Path $root 'dotnet')
    $r = Invoke-Validator -Root $root -Check $Check
    Write-Host "[ValidateDist powershell $Name] EXIT=$($r.Exit)"; Write-Host $r.Out
    Assert ($r.Out -match '(?m)^(OK|FAIL):') "$Name did not reach a validator check: $($r.Out)"
    Assert ($r.Out -match [regex]::Escape($Finding)) "$Name did not emit its target finding '$Finding': $($r.Out)"
    foreach($pattern in $AlsoPattern){ Assert ($r.Out -match $pattern) "$Name did not match additional evidence '$pattern': $($r.Out)" }
    if ($Green) { Assert ($r.Exit -eq 0) "$Name should be green, got EXIT=$($r.Exit)" }
    else { Assert ($r.Exit -ne 0) "$Name should be red, got EXIT=0" }
}
function Replace-Text { param($Path,$Find,$Replace) $t=[IO.File]::ReadAllText($Path); [IO.File]::WriteAllText($Path,$t.Replace($Find,$Replace)) }

# Build the dispatch list from PowerShell's own AST, not a line-shaped regex. A case registration
# may sit after a conditional on the same line, and the old `^\s*It` regex silently omitted it from
# the driver. Every registration must have a literal name, and two It blocks may not share a name.
# Those constraints make "every registered case was dispatched once" a checked property rather
# than an assumption about source formatting.
function Get-RegisteredCaseNames {
    $tokens = $null; $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $PSCommandPath, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        throw "dispatcher cannot parse its own suite: $($parseErrors[0].Message)"
    }
    $calls = @($ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -eq 'It'
    }, $true))
    $itNames = @()
    foreach ($call in $calls) {
        if ($call.CommandElements.Count -lt 2 -or
            $call.CommandElements[1] -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) {
            throw "dispatcher found a non-literal $($call.GetCommandName()) registration at line $($call.Extent.StartLineNumber)"
        }
        $name = $call.CommandElements[1].Value
        $itNames += $name
    }
    $duplicateIts = @($itNames | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)
    if ($duplicateIts.Count -gt 0) {
        throw "dispatcher found duplicate It registration(s): $($duplicateIts -join ', ')"
    }
    return @($itNames | Select-Object -Unique)
}

# Child-process startup and dist copying dominate the remaining cost. Cap concurrency at eight and
# scale to the host so a small Windows runner is not over-subscribed into slower-than-sequential work.
$throttle = if ($env:VALIDATE_DIST_TESTS_THROTTLE) { [int]$env:VALIDATE_DIST_TESTS_THROTTLE }
            else { [Math]::Max(2, [Math]::Min(8, [Environment]::ProcessorCount)) }
if (-not $Only) {
    # ---- driver: one child per case, $throttle at a time -------------------------------------
    # Case names are read back out of the AST rather than kept in a second list, so a case can
    # never be added and silently not dispatched -- including registrations that are not the first
    # token on their source line.
    try { $caseNames = @(Get-RegisteredCaseNames) }
    catch { [Console]::Error.WriteLine("ValidateDist.Tests: $($_.Exception.Message)"); exit 1 }
    if ($caseNames.Count -eq 0) { Write-Host 'ValidateDist.Tests: dispatcher found ZERO cases -- the suite is broken, not clean.'; exit 1 }
    $self = $PSCommandPath
    $exe  = (Get-Process -Id $PID).Path
    $queue = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))
    $caseNames | ForEach-Object { $queue.Enqueue($_) }
    $running = @(); $results = @{}
    while ($queue.Count -gt 0 -or $running.Count -gt 0) {
        while ($queue.Count -gt 0 -and $running.Count -lt $throttle) {
            $name = $queue.Dequeue()
            $out  = Join-Path ([IO.Path]::GetTempPath()) ('vdcase-' + [guid]::NewGuid().ToString('N') + '.txt')
            # Every case name contains spaces and colons, and Start-Process joins ArgumentList with
            # spaces WITHOUT quoting -- unquoted, the name arrived as a dozen separate arguments,
            # -Only bound to the first word, no case matched, and the suite reported 0 passed /
            # 0 failed in 8 seconds. It looked like a 50x speedup and was a total loss of coverage.
            $p = Start-Process -FilePath $exe -ArgumentList @('-NoProfile','-File',"`"$self`"",'-Only',"`"$name`"") `
                    -RedirectStandardOutput $out -RedirectStandardError "$out.err" -PassThru -NoNewWindow
            $running += [pscustomobject]@{ Name=$name; Proc=$p; Out=$out }
        }
        Start-Sleep -Milliseconds 200
        foreach ($r in @($running | Where-Object { $_.Proc.HasExited })) {
            $results[$r.Name] = $r; $running = @($running | Where-Object { $_ -ne $r })
        }
    }
    # Replay in declaration order so output is deterministic regardless of completion order.
    $pass=0; $fail=0; $skip=0
    foreach ($name in $caseNames) {
        $r = $results[$name]
        $text = if (Test-Path $r.Out) { Get-Content $r.Out -Raw } else { '' }
        $err  = if (Test-Path "$($r.Out).err") { Get-Content "$($r.Out).err" -Raw } else { '' }
        # Strip the child's own summary line; this driver prints one aggregate summary instead.
        $lines = @($text -split "`r?`n" | Where-Object { $_ -notmatch '^ValidateDist\.Tests \(B-92\):' })
        $lines | Where-Object { $_ -ne '' } | ForEach-Object { Write-Host $_ }
        if ($text -match 'ValidateDist\.Tests \(B-92\): (\d+) passed, (\d+) failed, (\d+) skipped') {
            $cp = [int]$Matches[1]; $cf = [int]$Matches[2]; $cs = [int]$Matches[3]
            if (($cp + $cf + $cs) -eq 0) {
                # A child that reported NO result for the case it was handed did not pass it. This
                # guard is here because the dispatcher shipped with exactly that bug for one run:
                # a quoting error meant no case ever matched, and every child returned a clean
                # 0 passed / 0 failed. Without this the suite would have gone green having tested
                # nothing -- the precise failure mode every case in this file exists to catch.
                Write-Host ("[FAIL] {0} -- child reported no result for its case (exit {1})" -f $name, $r.Proc.ExitCode)
                $fail++
            } else { $pass += $cp; $fail += $cf; $skip += $cs }
        } else {
            # A child that produced no summary did not report a verdict. That is a failure, not a
            # pass -- an unreported case is exactly the silent-coverage-loss this suite guards.
            Write-Host ("[FAIL] {0} -- child produced no summary (exit {1}). stderr: {2}" -f $name, $r.Proc.ExitCode, $err.Trim())
            $fail++
        }
        Remove-Item -Force -ErrorAction SilentlyContinue $r.Out, "$($r.Out).err"
    }
    if ($global:AtlEmitCaseCount) { Write-Host ("CASE_COUNT {0}" -f ($pass + $fail)) }
    Write-Host ("ValidateDist.Tests (B-92): {0} passed, {1} failed, {2} skipped" -f $pass, $fail, $skip)
    exit $fail
}
# ---- child: run exactly the one case named by -Only ------------------------------------------
$__origIt = ${function:It}
function It { param([string]$Name, [scriptblock]$Body) if ($Name -ne $Only) { return }; & $__origIt $Name $Body }

try {
    It 'case 1: settings.json with zero handlers fails check 8' { Assert-Case 'zero-settings' { param($d) $p=Join-Path $d '.claude\settings.json'; $t=[IO.File]::ReadAllText($p); [IO.File]::WriteAllText($p,[regex]::Replace($t,'"command"','"commandX"',6)) } 'settings.json : registration file yields zero handlers' 'hook-registration' }
    It 'case 2: settings.windows.json with zero handlers fails check 8' { Assert-Case 'zero-windows' { param($d) $p=Join-Path $d '.claude\settings.windows.json'; $t=[IO.File]::ReadAllText($p); [IO.File]::WriteAllText($p,[regex]::Replace($t,'"command"','"commandX"',6)) } 'settings.windows.json : registration file yields zero handlers' 'hook-registration' }
    It 'case 3: an absolute registration fails check 8' { Assert-Case 'absolute' { param($d) Replace-Text (Join-Path $d '.claude\settings.json') '.claude/hooks/session-start.ps1' 'C:/definitely-missing/session-start.ps1' } 'is an absolute path' 'hook-registration' }
    It 'case 4: a quoted missing -File target fails check 8' { Assert-Case 'quoted-missing' { param($d) Replace-Text (Join-Path $d '.claude\settings.json') '.claude/hooks/session-start.ps1' '\".claude/hooks/definitely missing.ps1\"' } 'does not exist in this dist' 'hook-registration' }
    It 'case 5: a quoted real -File target stays green' { Assert-Case 'quoted-real' { param($d) Replace-Text (Join-Path $d '.claude\settings.json') '.claude/hooks/session-start.ps1' '\".claude/hooks/session-start.ps1\"' } 'exactly 18 PowerShell hook registrations resolve' 'hook-registration' -Green }
    It 'case 6: a Copilot entry without its PowerShell command fails check 8' { Assert-Case 'missing-copilot-powershell' { param($d) $p=Join-Path $d '.github\hooks\hooks.json'; $t=[IO.File]::ReadAllText($p); $t=(New-Object regex('\s*"powershell":\s*"[^"]+",?')).Replace($t,'',1); [IO.File]::WriteAllText($p,$t) } 'hook entry must have one non-empty powershell command' 'hook-registration' -AlsoPattern @('expected exactly 6 PowerShell entries, found 5','expected exactly 18 PowerShell handlers, found 17') }
    It 'case 7: an unrelated command object does not change registration scoping' { Assert-Case 'unrelated-command' { param($d) $p=Join-Path $d '.claude\settings.json'; $t=[IO.File]::ReadAllText($p); [IO.File]::WriteAllText($p,$t.Replace('"hooks": {','"unrelated": { "type": "command" },' + [Environment]::NewLine + '  "hooks": {')) } 'exactly 18 PowerShell hook registrations resolve' 'hook-registration' -Green }
    It 'case 8: a Bash key in a Copilot hook fails check 8' {
        Assert-Case 'copilot-bash-key' {
            param($d)
            $path = Join-Path $d '.github\hooks\hooks.json'
            $doc = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json
            @($doc.hooks.sessionStart)[0] | Add-Member -NotePropertyName bash -NotePropertyValue 'bash .claude/hooks/session-start.sh'
            [IO.File]::WriteAllText($path, ($doc | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding($false)))
        } 'Bash hook key remains in PowerShell-only configuration' 'hook-registration'
    }
    It 'case 8b: an extra Copilot PowerShell entry fails exact cardinality' {
        Assert-Case 'extra-copilot-entry' {
            param($d)
            $path = Join-Path $d '.github\hooks\hooks.json'
            $doc = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json
            $entry = @($doc.hooks.sessionStart)[0]
            $doc.hooks.sessionStart = @($entry, $entry)
            [IO.File]::WriteAllText($path, ($doc | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding($false)))
        } 'expected exactly 6 PowerShell entries, found 7' 'hook-registration' -AlsoPattern 'expected exactly 18 PowerShell handlers, found 19'
    }
    It 'case 8c: removing Claude defaultShell fails the PowerShell contract' {
        Assert-Case 'missing-default-shell' {
            param($d)
            $path = Join-Path $d '.claude\settings.json'
            $doc = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json
            $doc.PSObject.Properties.Remove('defaultShell')
            [IO.File]::WriteAllText($path, ($doc | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding($false)))
        } "defaultShell must be exactly 'powershell'" 'hook-registration'
    }
    It 'case 8d: removing a Claude command hook shell fails the PowerShell contract' {
        Assert-Case 'missing-command-shell' {
            param($d)
            $path = Join-Path $d '.claude\settings.json'
            $doc = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json
            $firstEvent = @($doc.hooks.PSObject.Properties)[0]
            $firstEvent.Value[0].hooks[0].PSObject.Properties.Remove('shell')
            [IO.File]::WriteAllText($path, ($doc | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding($false)))
        } "command hook shell must be exactly 'powershell'" 'hook-registration'
    }
    It 'case 9: a dead documented command fails check 7' { Assert-Case 'dead-doc' { param($d) Replace-Text (Join-Path $d 'README.md') 'scripts/install.ps1' 'scripts/definitely-missing.ps1' } 'dead instructions in shipped docs' 'no-dead-instruction' }
    # -Force is load-bearing: most shipped Markdown lives below dot-directories.
    It 'case 10: no markdown files fails check 7' { Assert-Case 'no-docs' { param($d) Get-ChildItem -LiteralPath $d -Recurse -Filter *.md -Force | Remove-Item -Force } 'no-dead-instruction scanned zero documentation files' 'no-dead-instruction' }
    It 'case 11: an empty tree fails check 6' { Assert-Case 'empty-tree' { param($d) Get-ChildItem -LiteralPath $d -Force | Remove-Item -Recurse -Force } 'no-meta-leak scanned zero files' 'no-meta-leak' }
    It 'case 21: machine-local user paths fail check 6' {
        $fixtures = @(
            @{ Text=('C:' + '\Users\' + 'ExamplePerson\private.txt'); Pattern='[A-Za-z]:[\\/]Users[\\/]' },
            @{ Text=('/ho' + 'me/example-person/private.txt'); Pattern='/home/[^/ \t]+/' },
            @{ Text=('/Us' + 'ers/ExamplePerson/private.txt'); Pattern='/Users/[^/ \t]+/' }
        )
        foreach ($fixture in $fixtures) {
            Assert-Case ('machine-path-' + ($fixture.Text -replace '[^A-Za-z]','-')) {
                param($d) [IO.File]::AppendAllText((Join-Path $d 'README.md'), "`nB109 path fixture: $($fixture.Text)`n")
            } $fixture.Pattern 'no-meta-leak'
        }
    }
    It 'case 12: clean PowerShell topology and registrations stay green together' {
        Assert-Case 'clean-powershell-contract' { param($d) } 'exactly 18 PowerShell hook registrations resolve' 'powershell-topology,hook-registration' -Green -PowerShellOnly -AlsoPattern 'PowerShell-only topology: \d+ files scanned'
    }
    It 'case 13: an event whose value is not an array fails check 8' { Assert-Case 'bad-event-shape' { param($d) $p=Join-Path $d '.github\hooks\hooks.json'; $t=[IO.File]::ReadAllText($p); [IO.File]::WriteAllText($p,$t.Replace('"sessionStart": [','"sessionStart": {"invalid":"not-an-array"}, "sessionStartX": [')) } "hook event 'sessionStart' must be an array" 'hook-registration' }
    It 'case 14: an unparseable registration file fails check 8 rather than yielding zero handlers' { Assert-Case 'unparseable' { param($d) [IO.File]::WriteAllText((Join-Path $d '.claude\settings.json'), '{"hooks": {"SessionStart": [ THIS IS NOT JSON') } 'registration file is unreadable or unparseable' 'hook-registration' }
    # Windows resolves `.PS1` case-insensitively. The validator deliberately compares every path
    # segment ordinally so a wrong-case registration cannot pass locally and fail after checkout.
    It 'case 16: a registration whose casing differs from the shipped file fails check 8' { Assert-Case 'case-mismatch' { param($d) Replace-Text (Join-Path $d '.claude\settings.json') '.claude/hooks/session-start.ps1' '.claude/hooks/session-start.PS1' } 'does not exist in this dist' 'hook-registration' }

    It 'case 17: a missing framework-rules import fails the full validator' { Assert-Case 'missing-framework-import' { param($d) $p=Join-Path $d 'CLAUDE.md'; $t=[IO.File]::ReadAllText($p); [IO.File]::WriteAllText($p,$t.Replace('@.github/instructions/framework-rules.instructions.md','')) } 'CLAUDE.md is missing required import @.github/instructions/framework-rules.instructions.md.' 'carrier-import' }
    It 'case 18: a citation to a moved CLAUDE.md section fails the full validator' { Assert-Case 'moved-section-citation' { param($d) $p=Join-Path $d 'README.md'; [IO.File]::AppendAllText($p,"`nPlant: ``CLAUDE.md > SOLID```n") } 'cites CLAUDE.md > SOLID, but that heading does not exist' 'section-path' }
    It 'case 19: prose after valid finite-registry citations does not become a heading' { Assert-Case 'citation-prose' { param($d) $p=Join-Path $d 'README.md'; [IO.File]::AppendAllText($p,"`nCLAUDE.md > Conventions wins on any conflict.`nCLAUDE.md > Boy Scout Rule before considering the work complete.`n[CLAUDE.md](./CLAUDE.md) > Conventions.`n") } 'all registered section-path references resolve' 'section-path' -Green }
    It 'case 20: a missing stack snippet fails marker expansion without touching the live source tree' {
        $isolated = New-ValidatorRepoCopy
        $snippet = Join-Path $isolated 'src\stacks\dotnet\snippets\.github\instructions\framework-rules.instructions.md\lean-test'
        Remove-Item -LiteralPath $snippet -Force
        $out = & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File (Join-Path $isolated 'scripts\validate-dist.ps1') dotnet (Join-Path $isolated 'dist') -Check marker-expansion 2>&1
        $code = $LASTEXITCODE
        $text = $out -join "`n"
        Write-Host "[ValidateDist powershell missing-marker-expansion] EXIT=$code"; Write-Host $text
        Assert ($code -ne 0) 'missing-marker-expansion should be red'
        Assert ($text.Contains('dotnet : .github/instructions/framework-rules.instructions.md @stack:lean-test resolves to an empty expansion')) "missing-marker-expansion did not name relpath, marker and stack: $text"
    }

    It 'case 22: an empty dist fails the marker scan instead of reporting a vacuous pass' { Assert-Case 'zero-marker-files' { param($d) Get-ChildItem -LiteralPath $d -Force | Remove-Item -Recurse -Force } 'marker scan found zero files' 'markers' }
    It 'case 23: a dist with zero JSON files fails the JSON check' { Assert-Case 'zero-json' { param($d) Get-ChildItem -LiteralPath $d -Recurse -Force -File -Filter *.json | Remove-Item -Force } 'JSON scan found zero files' 'json' }
    It 'case 24: a dist with zero files fails the PowerShell topology scan' { Assert-Case 'zero-topology-files' { param($d) Get-ChildItem -LiteralPath $d -Force | Remove-Item -Recurse -Force } 'PowerShell topology scan found zero files' 'powershell-topology' }
    It 'case 25: a dist with zero PowerShell files fails the PowerShell syntax check' { Assert-Case 'zero-powershell' { param($d) Get-ChildItem -LiteralPath $d -Recurse -Force -File -Filter *.ps1 | Remove-Item -Force } 'PowerShell scan found zero files' 'ps-syntax' }
    It 'case 25a: an active .sh file fails the PowerShell topology check' {
        Assert-Case 'active-sh' {
            param($d)
            [IO.File]::WriteAllText((Join-Path $d 'scripts\planted-active.sh'), "#!/bin/sh`nexit 0`n")
        } 'scripts/planted-active.sh : active .sh implementation' 'powershell-topology' -PowerShellOnly
    }
    It 'case 25b: a shell shebang in an extensionless file fails the PowerShell topology check' {
        Assert-Case 'shell-shebang' {
            param($d)
            [IO.File]::WriteAllText((Join-Path $d 'scripts\planted-shell'), "#!/usr/bin/env bash`nexit 0`n")
        } 'scripts/planted-shell : active shell shebang' 'powershell-topology' -PowerShellOnly
    }
    It 'case 25c: a Linux GitHub runner fails the PowerShell topology check' {
        Assert-Case 'linux-runner' {
            param($d)
            $path = Join-Path $d '.github\workflows\template-ci.yml'
            $text = [IO.File]::ReadAllText($path)
            [IO.File]::WriteAllText($path, [regex]::Replace($text, 'runs-on:\s*windows-latest', 'runs-on: ubuntu-latest', 1))
        } '.github/workflows/template-ci.yml : unsupported non-Windows runner' 'powershell-topology' -PowerShellOnly
    }
    It 'case 25d: a matrix-selected Linux runner fails the PowerShell topology check' {
        Assert-Case 'matrix-linux-runner' {
            param($d)
            $path = Join-Path $d '.github\workflows\template-ci.yml'
            $text = [IO.File]::ReadAllText($path)
            $text = "# ubuntu-latest in this comment is inert`n" + $text
            $replacement = "strategy:`n      matrix:`n        os: [windows-latest, ubuntu-latest]`n    runs-on: `${{ matrix.os }}"
            [IO.File]::WriteAllText($path, [regex]::Replace($text, 'runs-on:\s*windows-latest', $replacement, 1))
        } '.github/workflows/template-ci.yml : unsupported non-Windows runner' 'powershell-topology' -PowerShellOnly
    }
    It 'case 25e: a container job fails the PowerShell topology check' {
        Assert-Case 'container-job' {
            param($d)
            $path = Join-Path $d '.github\workflows\template-ci.yml'
            $text = [IO.File]::ReadAllText($path)
            [IO.File]::WriteAllText($path, [regex]::Replace($text, '(runs-on:\s*windows-latest)', "`$1`n    container: example/image:latest", 1))
        } '.github/workflows/template-ci.yml : unsupported container job' 'powershell-topology' -PowerShellOnly
    }
    It 'case 26: unreadable inputs in checks 1 through 4 are named distinctly from content defects' {
        $fixtures = @(
            @{ Check='markers';     Relative='README.md';                       Finding='marker scan could not read:' },
            @{ Check='json';        Relative='.claude/settings.json';           Finding='JSON scan could not read:' },
            @{ Check='powershell-topology'; Relative='README.md';                Finding='PowerShell topology scan could not read' },
            @{ Check='ps-syntax';   Relative='.claude/hooks/audit-trail.ps1';    Finding='PowerShell scan could not read:' }
        )
        foreach ($fixture in $fixtures) {
            $root = New-DistCopy -PowerShellOnly:($fixture.Check -eq 'powershell-topology')
            $target = Join-Path (Join-Path $root 'dotnet') $fixture.Relative
            $handle = [IO.File]::Open($target,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
            try { $r = Invoke-Validator -Root $root -Check $fixture.Check }
            finally { $handle.Dispose() }
            Write-Host "[ValidateDist powershell unreadable-$($fixture.Check)] EXIT=$($r.Exit)"; Write-Host $r.Out
            Assert ($r.Exit -ne 0) "unreadable-$($fixture.Check) should be red"
            Assert ($r.Out -match [regex]::Escape($fixture.Finding)) "unreadable-$($fixture.Check) did not identify a read failure: $($r.Out)"
            Assert ($r.Out -match [regex]::Escape((Split-Path $fixture.Relative -Leaf))) "unreadable-$($fixture.Check) did not name the unreadable file: $($r.Out)"
        }
    }

    It 'case 27: clean checks 1 through 4 report exact independently counted populations' {
        foreach ($check in @('markers','json','powershell-topology','ps-syntax')) {
            $root = New-DistCopy -PowerShellOnly:($check -eq 'powershell-topology')
            $dist = Join-Path $root 'dotnet'
            $expected = switch ($check) {
                'markers'     { @(Get-ChildItem -LiteralPath $dist -Recurse -Force -File).Count }
                'json'        { @(Get-ChildItem -LiteralPath $dist -Recurse -Force -File -Filter *.json).Count }
                'powershell-topology' { @(Get-ChildItem -LiteralPath $dist -Recurse -Force -File).Count }
                'ps-syntax'   { @(Get-ChildItem -LiteralPath $dist -Recurse -Force -File -Filter *.ps1).Count }
            }
            Assert ($expected -gt 0) "independent $check inventory is empty; the clean control would be vacuous"
            $r = Invoke-Validator -Root $root -Check $check
            Write-Host "[ValidateDist powershell exact-count-$check] EXIT=$($r.Exit)"; Write-Host $r.Out
            Assert ($r.Exit -eq 0) "exact-count-$check should be green"
            $countText = switch ($check) {
                'markers' { "($expected files scanned)" }
                'json' { "all $expected *.json files" }
                'powershell-topology' { "PowerShell-only topology: $expected files scanned" }
                'ps-syntax' { "all $expected *.ps1 files" }
            }
            Assert ($r.Out.Contains($countText)) "exact-count-$check did not report independent count ${expected}: $($r.Out)"
        }
    }

    It 'case 28: content-only and named-check selectors are rejected together' {
        $root = New-DistCopy
        $r = Invoke-Validator -Root $root -Check markers -CombineSelectors
        Write-Host "[ValidateDist powershell conflicting-selectors] EXIT=$($r.Exit)"; Write-Host $r.Out
        Assert ($r.Exit -eq 2) 'conflicting-selectors should be a usage error (EXIT=2)'
        Assert ($r.Out -match '--content-only and -Check cannot be combined') "conflicting-selectors did not explain the conflict: $($r.Out)"
        Assert ($r.Out -notmatch '(?m)^(OK|FAIL):') 'conflicting-selectors ran a check before rejecting its scope'
    }

    It 'case 29: a dist root containing spaces is preserved' {
        $root = New-DistCopy -Prefix 'validate dist spaced root '
        $expected = @(Get-ChildItem -LiteralPath (Join-Path $root 'dotnet') -Recurse -Force -File).Count
        $r = Invoke-Validator -Root $root -Check markers
        Write-Host "[ValidateDist powershell spaced-root] EXIT=$($r.Exit)"; Write-Host $r.Out
        Assert ($r.Exit -eq 0) 'spaced-root should be green'
        Assert ($r.Out.Contains("($expected files scanned)")) "spaced-root lost or split the dist-root argument: $($r.Out)"
    }

    It 'case 30: syntax mutants in content and PowerShell checks fail for their intended reason' {
        $fixtures = @(
            @{ Check='markers'; Relative='README.md';                    Text="`n@stack:planted-review-mutant`n"; Finding='unresolved @stack markers in:' },
            @{ Check='json'; Relative='.claude/settings.json';           Text="`nTHIS IS NOT JSON`n"; Finding='invalid JSON' },
            @{ Check='ps-syntax'; Relative='.claude/hooks/guard.ps1';     Text="`nfunction ReviewMutant {`n"; Finding='PS syntax errors' }
        )
        foreach ($fixture in $fixtures) {
            $root = New-DistCopy
            $target = Join-Path (Join-Path $root 'dotnet') $fixture.Relative
            [IO.File]::AppendAllText($target, $fixture.Text)
            $r = Invoke-Validator -Root $root -Check $fixture.Check
            Write-Host "[ValidateDist powershell syntax-mutant-$($fixture.Check)] EXIT=$($r.Exit)"; Write-Host $r.Out
            Assert ($r.Exit -ne 0) "syntax-mutant-$($fixture.Check) should be red"
            Assert ($r.Out -match [regex]::Escape($fixture.Finding)) "syntax-mutant-$($fixture.Check) failed for the wrong reason: $($r.Out)"
            Assert ($r.Out -match [regex]::Escape((Split-Path $fixture.Relative -Leaf))) "syntax-mutant-$($fixture.Check) did not name its mutant: $($r.Out)"
        }
    }
    It 'case 32: a dangling rendered markdown link fails while code examples stay out of scope' {
        Assert-Case 'dangling-markdown-link' {
            param($d)
            [IO.File]::AppendAllText((Join-Path $d 'README.md'), "`n[B67 planted](./docs/definitely-missing-b67.md)`n")
        } 'dangling markdown links in shipped docs' 'no-dead-instruction' -AlsoPattern @('README\.md:\d+:','definitely-missing-b67\.md')

        Assert-Case 'markdown-code-examples' {
            param($d)
            [IO.File]::WriteAllText((Join-Path $d 'docs/link target.md'),'# valid spaced target')
            [IO.File]::AppendAllText((Join-Path $d 'README.md'), "`n[angle target](<./docs/link target.md>)`n``````markdown`n[example](./does-not-exist.md)`n```````nLiteral ``[placeholder](./also-missing.md)``.`n")
        } 'relative inline Markdown links and' 'no-dead-instruction' -Green
    }
    It 'case 33: zero rendered local links fails instead of making a broken extractor look clean' {
        Assert-Case 'zero-markdown-links' {
            param($d)
            foreach ($f in (Get-ChildItem -LiteralPath $d -Recurse -Force -File -Filter *.md)) {
                $text=[IO.File]::ReadAllText($f.FullName)
                $text=[regex]::Replace($text,'(?<!!)\[([^\]]+)\]\((?!https?:|mailto:|#)([^\)]+)\)','`$1`')
                [IO.File]::WriteAllText($f.FullName,$text)
            }
        } 'extracted zero relative inline Markdown links' 'no-dead-instruction'
    }
    It 'case 34: link edge grammar and stale Bash command diagnostics remain intact' {
        Assert-Case 'fenced-dead-command' {
            param($d)
            [IO.File]::AppendAllText((Join-Path $d 'README.md'),"`n``````bash`nbash scripts/definitely-missing-b67.sh`n```````n")
        } 'dead instructions in shipped docs' 'no-dead-instruction' -AlsoPattern 'definitely-missing-b67\.sh'

        Assert-Case 'malformed-percent-link' {
            param($d)
            [IO.File]::WriteAllText((Join-Path $d 'docs/foo%ZZ.md'),'literal percent filename')
            [IO.File]::AppendAllText((Join-Path $d 'README.md'),"`n[bad percent](./docs/foo%ZZ.md)`n")
        } 'is not a valid relative link target' 'no-dead-instruction' -AlsoPattern 'foo%ZZ\.md'

        Assert-Case 'nul-percent-link' {
            param($d)
            [IO.File]::AppendAllText((Join-Path $d 'README.md'),"`n[nul](%00)`n")
        } 'is not a valid relative link target' 'no-dead-instruction' -AlsoPattern '%00'

        Assert-Case 'newline-percent-link' {
            param($d)
            [IO.File]::AppendAllText((Join-Path $d 'README.md'),"`n[newline](%0A)`n")
        } 'is not a valid relative link target' 'no-dead-instruction' -AlsoPattern '%0A'

        Assert-Case 'encoded-link-escape' {
            param($d)
            [IO.File]::AppendAllText((Join-Path $d 'docs/playbook.md'),"`n[escape](%2e%2e/%2e%2e/outside.md)`n")
        } 'escapes this dist' 'no-dead-instruction' -AlsoPattern '%2e%2e'

        Assert-Case 'root-directory-links' {
            param($d)
            [IO.File]::AppendAllText((Join-Path $d 'README.md'),"`n[root](./)`n")
            [IO.File]::AppendAllText((Join-Path $d 'docs/playbook.md'),"`n[root](../)`n")
        } 'relative inline Markdown links and' 'no-dead-instruction' -Green

        Assert-Case 'command-source-lines' {
            param($d)
            [IO.File]::AppendAllText((Join-Path $d 'README.md'),"`nbash scripts/definitely-missing-with-line-b67.sh`n")
        } 'dead instructions in shipped docs' 'no-dead-instruction' -AlsoPattern @('README\.md:\d+:','definitely-missing-with-line-b67\.sh')
    }

    It 'case 35: step-reference grammar, vacuity guards and allowances remain intact' {
        $fixtures = @(
            @{ Name='zero-files'; Text=$null; Green=$false; Finding='step-reference scan found zero Markdown files' },
            @{ Name='zero-references'; Text="# fixture`n1. one`n2. two`n"; Green=$false; Finding='step-reference scan found zero prose references' },
            @{ Name='heading-not-reference'; Text="# fixture`n### Step 7 — definition`n"; Green=$false; Finding='step-reference scan found zero prose references' },
            @{ Name='broken-run'; Text="# fixture`n1. one`n3. three`nSee step 1.`n"; Green=$false; Finding='ordered-list run starts at 3 (expected 0 or 1)' },
            @{ Name='dead-reference'; Text="# fixture`n1. one`nSee step **9**.`n"; Green=$false; Finding='prose step 9 has no ordered-list label or Step 9 heading' },
            @{ Name='fenced-labels'; Text="# fixture`n``````text`n1. example`n3. example`n```````n1. real`nSee step 1.`n"; Green=$true; Finding='ordered-list runs are contiguous and prose step references resolve' },
            @{ Name='heading-definition'; Text="# fixture`n### Step 7 — definition`nUse Step 7 here.`n"; Green=$true; Finding='ordered-list runs are contiguous and prose step references resolve' },
            @{ Name='multiple-lists'; Text="# fixture`n1. first`n2. second`n`nText between procedures.`n`n1. another`n2. finish`nSee step 2 above.`n"; Green=$true; Finding='ordered-list runs are contiguous and prose step references resolve' }
        )
        $root = New-DistCopy
        $dist = Join-Path $root 'dotnet'
        foreach ($scope in '.claude/skills','.claude/commands','.claude/agents') {
            Get-ChildItem -LiteralPath (Join-Path $dist $scope) -Recurse -Force -File -Filter *.md -ErrorAction SilentlyContinue | Remove-Item -Force
        }
        $fixturePath = Join-Path $dist '.claude/skills/step-fixture/SKILL.md'
        New-Item -ItemType Directory -Path (Split-Path $fixturePath -Parent) -Force | Out-Null
        foreach ($fixture in $fixtures) {
            if ($null -eq $fixture.Text) { Remove-Item -LiteralPath $fixturePath -Force -ErrorAction SilentlyContinue }
            else { [IO.File]::WriteAllText($fixturePath,$fixture.Text) }
            $r = Invoke-Validator -Root $root -Check step-references
            Write-Host "[ValidateDist powershell step-$($fixture.Name)] EXIT=$($r.Exit)"; Write-Host $r.Out
            Assert ($r.Out.Contains($fixture.Finding)) "step-$($fixture.Name) missed '$($fixture.Finding)': $($r.Out)"
            if ($fixture.Green) { Assert ($r.Exit -eq 0) "step-$($fixture.Name) should be green" }
            else { Assert ($r.Exit -ne 0) "step-$($fixture.Name) should be red" }
        }
    }

    It 'case 36: a second userPromptSubmitted entry fails its delivery cardinality check' {
        Assert-Case 'duplicate-user-prompt-hook' {
            param($d)
            $path = Join-Path $d '.github/hooks/hooks.json'
            $doc = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json
            $entries = @($doc.hooks.userPromptSubmitted)
            Assert ($entries.Count -eq 1) "fixture expected exactly one userPromptSubmitted entry, found $($entries.Count)"
            $doc.hooks.userPromptSubmitted = @($entries[0], $entries[0])
            [IO.File]::WriteAllText($path, ($doc | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding($false)))
            $mutated = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json
            Assert (@($mutated.hooks.userPromptSubmitted).Count -eq 2) 'mutation did not create a second userPromptSubmitted entry'
        } 'Only the last userPromptSubmitted entry is delivered by Copilot CLI 1.0.80' 'prompt-hook-cardinality' -AlsoPattern 'compose into one hook instead'
    }

    It 'case 37: changelog-head grammar applies only to marked template repos' {
        $badHead = "## Unreleased`n`n## 0.60.0 — 2026-08-18`n"
        Assert-Case 'marked-template-bad-changelog-head' {
            param($d)
            [IO.File]::WriteAllText((Join-Path $d 'CHANGELOG.md'),$badHead,(New-Object Text.UTF8Encoding($false)))
        } "marked template repo CHANGELOG.md literal first '## ' line" 'template-checks'
        Assert-Case 'consumer-bad-changelog-head-ignored' {
            param($d)
            Remove-Item -LiteralPath (Join-Path $d '.template-repo') -Force
            [IO.File]::WriteAllText((Join-Path $d 'CHANGELOG.md'),$badHead,(New-Object Text.UTF8Encoding($false)))
            # ASCII-only substring on purpose: the real OK line contains an em dash, and the child
            # process's stdout does not round-trip it under every console code page, so asserting on
            # the dash tests the typography rather than the behaviour and fails on a correct run.
        } 'CHANGELOG.md ignored, pair-check only' 'template-checks' -Green
    }

} finally { foreach($p in $scratch) { if(Test-Path $p){ Remove-Item -LiteralPath $p -Recurse -Force } } }
exit (Write-TestSummary 'ValidateDist.Tests (B-92)')
