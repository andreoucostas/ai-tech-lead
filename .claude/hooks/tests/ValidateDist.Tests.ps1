# B-92 executable red-tests. These use real composed dists: synthetic JSON fixtures hid the prior
# false greens. The child is bound explicitly to THIS host; Get-PsExe now has the same self-hosting
# contract, after its former preference for pwsh caused B-90.
#
# -Only runs a SINGLE case by name. It exists so this file can dispatch itself: with no -Only the
# script becomes a driver that runs one child process per case, several at a time, and aggregates.
# Every case already builds its own temp dist copy and cleans it up, so the cases were independent
# long before they were run that way -- this parallelises them without changing what any of them do.
# A child process rather than a runspace is deliberate: each case shells out to pwsh and bash and
# mutates its own tree, so process isolation is the property that makes "independent" true rather
# than hoped-for. Startup is ~265 ms per child against a suite that took 391 s.
# Set VALIDATE_DIST_TESTS_THROTTLE=1 to force the old sequential behaviour when diagnosing.
param([string]$Only)
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
. (Join-Path $PSScriptRoot '_MutationHelper.ps1')
Reset-Tests
$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$validator = Join-Path $repo 'scripts\validate-dist.ps1'
$bashValidator = Join-Path $repo 'scripts/validate-dist.sh'
$bashExe = Get-BashPath
$scratch = @()
Remove-StaleTestScratchTrees

function New-DistCopy {
    param([string]$Prefix = 'validate-dist-')
    $root = Join-Path ([IO.Path]::GetTempPath()) ($Prefix + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo 'dist\dotnet') -Destination $root -Recurse
    $script:scratch += $root
    return $root
}
function New-ValidatorRepoCopy {
    # Marker inventory derives from authoring src/, so its red fixture needs an isolated source tree
    # as well as an isolated dist. Never mutate the live shared snippets during a test run.
    $root = Join-Path ([IO.Path]::GetTempPath()) ('validate-dist-repo-' + [guid]::NewGuid().ToString('N'))
    foreach ($dir in @('scripts','src','dist')) { New-Item -ItemType Directory -Path (Join-Path $root $dir) -Force | Out-Null }
    Copy-Item -LiteralPath (Join-Path $repo 'scripts\validate-dist.ps1') -Destination (Join-Path $root 'scripts')
    Copy-Item -LiteralPath (Join-Path $repo 'scripts\validate-dist.sh') -Destination (Join-Path $root 'scripts')
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
function Convert-ToBashPath {
    param([string]$Path)
    if ($Path -match '^([A-Za-z]):[\\/](.*)$') { return '/' + $Matches[1].ToLowerInvariant() + '/' + $Matches[2].Replace('\', '/') }
    return $Path.Replace('\', '/')
}
function Invoke-Validator {
    param(
        [string]$Root,
        [switch]$UseBash,
        [string]$JsonTool,
        [switch]$FullValidation,
        [string]$ExtraPathDir,
        [string]$Check,
        [switch]$CombineSelectors
    )
    # Each focused case names the one check that owns its planted defect. The clean anchor still
    # runs the full validator so every check remains exercised on both legs.
    # Passed as an ARGUMENT, never an environment variable: an inherited ambient switch could
    # silently downgrade a run that asked for full validation (sol's review of this change).
    $contentOnly = $CombineSelectors -or (-not $FullValidation -and -not $Check)
    if ($UseBash) {
        if (-not $bashExe) { throw 'Bash is unavailable; the bash validator was not exercised.' }
        $cwd = $repo.Replace('\', '/')
        $dist = $Root.Replace('\', '/')
        # B-85: Git Bash does not inherit the host PowerShell directory on this box.
        # Resolve tool directories from this host; preserve the inherited PATH for CI/non-Windows.
        $toolDirs = @((Split-Path -Parent (Get-Process -Id $PID).Path))
        foreach ($toolName in @('jq', 'python3')) {
            $tool = Get-Command $toolName -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($tool -and $tool.Source) { $toolDirs += (Split-Path -Parent $tool.Source) }
        }
        # B-106/F3: lets a case expose a shim ahead of everything else -- e.g. a real interpreter
        # that only resolves under a name other than "python3" -- without changing what every other
        # case here sees.
        if ($ExtraPathDir) { $toolDirs = @($ExtraPathDir) + $toolDirs }
        $pathPrefix = (@($toolDirs | Select-Object -Unique | ForEach-Object { "'$(Convert-ToBashPath $_)'" }) -join ':')
        $override = if ($JsonTool) { "VALIDATE_DIST_JSON_TOOL='$JsonTool' " } else { '' }
        $flag = if ($contentOnly) { ' --content-only' } else { '' }
        if ($Check) { $flag += " -Check '$Check'" }
        # Invoked as `bash <script>`, never `./<script>`: the file is mode 644 in git, which Windows
        # ignores and Linux enforces, so `./` gave "Permission denied" on the CI linux leg only.
        # Every other caller in this repo (CI, DEVELOPING.md) spells it this way too.
        $command = "export PATH=$pathPrefix`:`$PATH; cd '$cwd'; ${override}bash scripts/validate-dist.sh dotnet '$dist'$flag"
        $out = & $bashExe -c $command 2>&1; $code = $LASTEXITCODE
    } else {
        $argv = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$validator,'dotnet',$Root)
        if ($contentOnly) { $argv += '--content-only' }
        if ($Check) { $argv += @('-Check',$Check) }
        $out = & (Get-Process -Id $PID).Path @argv 2>&1; $code = $LASTEXITCODE
    }
    return [pscustomobject]@{ Exit=$code; Out=($out -join "`n") }
}
# -PsOnly runs a case on the PowerShell leg alone. Every case ran on BOTH legs while this suite was
# being built — that is how the bash-only false greens were found — but a full bash leg costs ~40s
# per case, because each run re-parses every shipped *.ps1 in a fresh PowerShell process (checks 3
# and 4), and this file runs in release.ps1's meta suite AND on both CI legs. The cases marked
# -PsOnly are the ones whose bash-side code path is already exercised by another case in this file;
# each one names that case. Nothing bash-specific is covered only by a PsOnly case.
# The residual cost is the selected check plus each case's dist copy and process startup.
function Assert-Case {
    param([string]$Name, [scriptblock]$Mutate, [string]$Finding, [string]$Check, [switch]$Green, [switch]$PsOnly, [switch]$FullValidation, [string[]]$AlsoPattern=@())
    $legs = if ($PsOnly) { @('ps') } else { @('ps','bash') }
    foreach ($leg in $legs) {
        $root = New-DistCopy
        & $Mutate (Join-Path $root 'dotnet')
        $r = Invoke-Validator -Root $root -UseBash:($leg -eq 'bash') -FullValidation:$FullValidation -Check $Check
        Write-Host "[ValidateDist $leg $Name] EXIT=$($r.Exit)"; Write-Host $r.Out
        Assert ($r.Out -match '(?m)^(OK|FAIL):') "$Name/$leg did not reach a validator check: $($r.Out)"
        Assert ($r.Out -match [regex]::Escape($Finding)) "$Name/$leg did not emit its target finding '$Finding': $($r.Out)"
        foreach($pattern in $AlsoPattern){ Assert ($r.Out -match $pattern) "$Name/$leg did not match additional evidence '$pattern': $($r.Out)" }
        if ($Green) { Assert ($r.Exit -eq 0) "$Name/$leg should be green, got EXIT=$($r.Exit)" }
        else { Assert ($r.Exit -ne 0) "$Name/$leg should be red, got EXIT=0" }
    }
}
function Replace-Text { param($Path,$Find,$Replace) $t=[IO.File]::ReadAllText($Path); [IO.File]::WriteAllText($Path,$t.Replace($Find,$Replace)) }

# Build the dispatch list from PowerShell's own AST, not a line-shaped regex. A case registration
# may sit after a conditional on the same line (the python/jq branch below does), and the old
# `^\s*It` regex silently omitted it from the driver. Every registration must have a literal name;
# every Skip must be the platform-alternate of a real It; and two It blocks may not share a name.
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
            $node.GetCommandName() -in @('It','Skip')
    }, $true))
    $allNames = @(); $itNames = @(); $skipNames = @()
    foreach ($call in $calls) {
        if ($call.CommandElements.Count -lt 2 -or
            $call.CommandElements[1] -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) {
            throw "dispatcher found a non-literal $($call.GetCommandName()) registration at line $($call.Extent.StartLineNumber)"
        }
        $name = $call.CommandElements[1].Value
        $allNames += $name
        if ($call.GetCommandName() -eq 'It') { $itNames += $name } else { $skipNames += $name }
    }
    $duplicateIts = @($itNames | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)
    if ($duplicateIts.Count -gt 0) {
        throw "dispatcher found duplicate It registration(s): $($duplicateIts -join ', ')"
    }
    $orphanSkips = @($skipNames | Where-Object { $itNames -notcontains $_ } | Select-Object -Unique)
    if ($orphanSkips.Count -gt 0) {
        throw "dispatcher found Skip registration(s) with no matching It: $($orphanSkips -join ', ')"
    }
    return @($allNames | Select-Object -Unique)
}

# Windows can make a file genuinely unreadable to child processes with a deny-sharing handle.
# POSIX permissions are capability-probed because a privileged CI user can still read chmod 000;
# that world must be an invariant-guarding skip, not a fixture that claims to deny reads but does not.
function Test-CanDenyFileReads {
    if ($env:OS -eq 'Windows_NT') { return $true }
    if (-not $bashExe) { return $false }
    $path = Join-Path ([IO.Path]::GetTempPath()) ('vd-unreadable-probe-' + [guid]::NewGuid().ToString('N'))
    [IO.File]::WriteAllText($path, 'probe')
    $posix = Convert-ToBashPath $path
    try {
        & $bashExe -c "chmod 000 '$posix'" 2>$null
        if ($LASTEXITCODE -ne 0) { return $false }
        try { $stream = [IO.File]::OpenRead($path); $stream.Dispose(); return $false }
        catch { return $true }
    } finally {
        & $bashExe -c "chmod 600 '$posix'" 2>$null
        Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    }
}

# Measured on a 12-core box: throttle 4 = 218s, 8 = 183s, 12 = 179s, sequential = 391s. The floor
# is the longest single case, so past ~8 there is nothing left to win. Capped at 8 and scaled to the
# host so a 2-core CI runner is not over-subscribed into being slower than sequential.
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
    Write-Host ("ValidateDist.Tests (B-92): {0} passed, {1} failed, {2} skipped" -f $pass, $fail, $skip)
    exit $fail
}
# ---- child: run exactly the one case named by -Only ------------------------------------------
$__origIt = ${function:It}
$__origSkip = ${function:Skip}
function It { param([string]$Name, [scriptblock]$Body) if ($Name -ne $Only) { return }; & $__origIt $Name $Body }
# Skip is shadowed for the same reason as It: it registers a result, so an unguarded Skip would
# record itself once per child and the aggregate would report 20 skips for one skipped case.
# It shares its case NAME with the It it alternates with, so the dispatcher still schedules it.
function Skip {
    param([string]$Name, [string]$Why, [switch]$Invariant)
    if ($Name -ne $Only) { return }
    # -Invariant documents a capability-conditioned skip in this suite; the tiny shared registry's
    # Skip function accepts only name/reason, so do not forward that local metadata switch.
    & $__origSkip $Name $Why
}

try {
    It 'case 1: settings.json with zero handlers fails check 8' { Assert-Case 'zero-settings' { param($d) $p=Join-Path $d '.claude\settings.json'; $t=[IO.File]::ReadAllText($p); [IO.File]::WriteAllText($p,[regex]::Replace($t,'"command"','"commandX"',6)) } 'settings.json : registration file yields zero handlers' 'hook-registration' }
    It 'case 2: settings.windows.json with zero handlers fails check 8' { Assert-Case 'zero-windows' { param($d) $p=Join-Path $d '.claude\settings.windows.json'; $t=[IO.File]::ReadAllText($p); [IO.File]::WriteAllText($p,[regex]::Replace($t,'"command"','"commandX"',6)) } 'settings.windows.json : registration file yields zero handlers' 'hook-registration' -PsOnly }   # bash path identical to case 1
    It 'case 3: an absolute registration fails check 8' { Assert-Case 'absolute' { param($d) Replace-Text (Join-Path $d '.claude\settings.json') '.claude/hooks/session-start.ps1' 'C:/definitely-missing/session-start.ps1' } 'is an absolute path' 'hook-registration' }
    It 'case 4: a quoted missing -File target fails check 8' { Assert-Case 'quoted-missing' { param($d) Replace-Text (Join-Path $d '.claude\settings.json') '.claude/hooks/session-start.ps1' '\".claude/hooks/definitely missing.ps1\"' } 'does not exist in this dist' 'hook-registration' }
    It 'case 5: a quoted real -File target stays green' { Assert-Case 'quoted-real' { param($d) Replace-Text (Join-Path $d '.claude\settings.json') '.claude/hooks/session-start.ps1' '\".claude/hooks/session-start.ps1\"' } 'all 24 hook registrations resolve' 'hook-registration' -Green }
    It 'case 6: a single Copilot leg fails check 8' { Assert-Case 'single-leg' { param($d) $p=Join-Path $d '.github\hooks\hooks.json'; $t=[IO.File]::ReadAllText($p); $t=[regex]::Replace($t,'\s*"powershell":\s*"[^"]+",?','',1); [IO.File]::WriteAllText($p,$t) } 'has only one bash/powershell leg' 'hook-registration' -PsOnly }   # bash path: same parser branch as case 13
    It 'case 7: an unrelated command object does not change registration scoping' { Assert-Case 'unrelated-command' { param($d) $p=Join-Path $d '.claude\settings.json'; $t=[IO.File]::ReadAllText($p); [IO.File]::WriteAllText($p,$t.Replace('"hooks": {','"unrelated": { "type": "command" },' + [Environment]::NewLine + '  "hooks": {')) } 'all 24 hook registrations resolve' 'hook-registration' -Green -PsOnly }   # bash green path: case 12
    It 'case 8: a missing hook twin fails check 8' { Assert-Case 'missing-twin' { param($d) Remove-Item -LiteralPath (Join-Path $d '.claude\hooks\audit-trail.sh') -Force } 'exists but its twin' 'hook-registration' }
    It 'case 9: a dead documented command fails check 7' { Assert-Case 'dead-doc' { param($d) Replace-Text (Join-Path $d 'README.md') 'scripts/install.ps1' 'scripts/definitely-missing.ps1' } 'dead instructions in shipped docs' 'no-dead-instruction' }
    # -Force: on Linux, PowerShell treats dot-directories as hidden, so without it this mutation left
    # every .md under .claude/ and .github/ in place and the case failed on the CI linux leg only.
    # The validator had the same blind spot, which is what this case ended up exposing.
    It 'case 10: no markdown files fails check 7' { Assert-Case 'no-docs' { param($d) Get-ChildItem -LiteralPath $d -Recurse -Filter *.md -Force | Remove-Item -Force } 'no-dead-instruction scanned zero documentation files' 'no-dead-instruction' }
    It 'case 11: an empty tree fails check 6' { Assert-Case 'empty-tree' { param($d) Get-ChildItem -LiteralPath $d -Force | Remove-Item -Recurse -Force } 'no-meta-leak scanned zero files' 'no-meta-leak' }
    It 'case 21: machine-local user paths fail check 6 on both validators' {
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
    # This unmutated anchor deliberately runs the FULL validator on both legs, so every check is
    # still exercised together and an interaction cannot hide behind focused runs.
    It 'case 12: an unmutated dist stays green under the FULL validator' { Assert-Case 'clean' { param($d) } 'all 24 hook registrations resolve' -Green -FullValidation }
    # Case 13 and 14 are the structural guards, and both exist because all three parsers (PowerShell
    # ConvertFrom-Json, python3, jq) disagreed about malformed input the first time round: an event
    # whose value was an object reported "no bash/powershell leg" on two legs and "not an object" on
    # the third. The assertion is one message every leg must produce.
    It 'case 13: an event whose value is not an array fails check 8 on every parser' { Assert-Case 'bad-event-shape' { param($d) $p=Join-Path $d '.github\hooks\hooks.json'; $t=[IO.File]::ReadAllText($p); [IO.File]::WriteAllText($p,$t.Replace('"sessionStart": [','"sessionStart": {"invalid":"not-an-array"}, "sessionStartX": [')) } "hook event 'sessionStart' must be an array" 'hook-registration' }
    # Case 14 is the guard for a parser that dies mid-stream: without checking the parser's exit
    # status, the records emitted before it died left handlers > 0 and the per-file guard satisfied.
    It 'case 14: an unparseable registration file fails check 8 rather than yielding a short stream' { Assert-Case 'unparseable' { param($d) [IO.File]::WriteAllText((Join-Path $d '.claude\settings.json'), '{"hooks": {"SessionStart": [ THIS IS NOT JSON') } 'registration file is unparseable' 'hook-registration' }
    # Case 15 proves the base64 record framing: a tab or a backslash inside a command value must not
    # be able to shift a field. Spelling records as plain TSV made jq escape backslashes while
    # python3 printed them raw, which desynchronised the two branches on real shipped data.
    # Case 16 is a PLATFORM divergence, not a code one: Windows resolves `.PS1` to the shipped
    # `.ps1` and Linux does not, so this registration passed here and would have failed a consumer's
    # Linux CI. Both twins now resolve case-exactly, so both must call it missing.
    It 'case 16: a registration whose casing differs from the shipped file fails check 8' { Assert-Case 'case-mismatch' { param($d) Replace-Text (Join-Path $d '.claude\settings.json') '.claude/hooks/session-start.ps1' '.claude/hooks/session-start.PS1' } 'does not exist in this dist' 'hook-registration' }
    It 'case 15: a tab and a backslash in a command value cannot break the record framing' { Assert-Case 'framing' { param($d) Replace-Text (Join-Path $d '.claude\settings.json') '-File .claude/hooks/session-start.ps1' '-File .claude\\hooks\\definitely\tmissing.ps1' } 'does not exist in this dist' 'hook-registration' }

    It 'case 17: a missing framework-rules import fails the full validator' { Assert-Case 'missing-framework-import' { param($d) $p=Join-Path $d 'CLAUDE.md'; $t=[IO.File]::ReadAllText($p); [IO.File]::WriteAllText($p,$t.Replace('@.github/instructions/framework-rules.instructions.md','')) } 'CLAUDE.md is missing required import @.github/instructions/framework-rules.instructions.md.' 'carrier-import' }
    It 'case 18: a citation to a moved CLAUDE.md section fails the full validator' { Assert-Case 'moved-section-citation' { param($d) $p=Join-Path $d 'README.md'; [IO.File]::AppendAllText($p,"`nPlant: ``CLAUDE.md > SOLID```n") } 'cites CLAUDE.md > SOLID, but that heading does not exist' 'section-path' }
    It 'case 19: prose after valid finite-registry citations does not become a heading' { Assert-Case 'citation-prose' { param($d) $p=Join-Path $d 'README.md'; [IO.File]::AppendAllText($p,"`nCLAUDE.md > Conventions wins on any conflict.`nCLAUDE.md > Boy Scout Rule before considering the work complete.`n[CLAUDE.md](./CLAUDE.md) > Conventions.`n") } 'all registered section-path references resolve' 'section-path' -Green }
    It 'case 38: a grep execution failure is a host FATAL, not a missing-heading finding' {
        $root = New-DistCopy
        $shim = Join-Path ([IO.Path]::GetTempPath()) ('vd-dead-grep-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $shim -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $shim 'grep'), "#!/usr/bin/env bash`nexit 2`n")
        & $bashExe -c "chmod +x '$(Convert-ToBashPath (Join-Path $shim 'grep'))'" 2>$null
        Assert ($LASTEXITCODE -eq 0) 'could not make the grep shim executable'
        $script:scratch += $shim
        $r = Invoke-Validator -Root $root -UseBash -ExtraPathDir $shim -Check section-path
        Write-Host "[ValidateDist bash failed-grep] EXIT=$($r.Exit)"; Write-Host $r.Out
        Assert ($r.Exit -eq 2) "failed-grep/bash should be a host FATAL (EXIT=2), got $($r.Exit)"
        Assert ($r.Out -match 'could not execute grep while resolving section-path citations') "failed-grep/bash did not name grep execution: $($r.Out)"
        Assert ($r.Out -match 'host/resource problem, not a content problem') "failed-grep/bash misclassified the host failure: $($r.Out)"
        Assert ($r.Out -notmatch 'heading does not exist') "failed-grep/bash emitted a false content finding: $($r.Out)"
    }
    It 'case 20: a missing stack snippet fails marker expansion without touching the live source tree' {
        foreach ($leg in @('ps','bash')) {
            $isolated = New-ValidatorRepoCopy
            $snippet = Join-Path $isolated 'src\stacks\dotnet\snippets\.github\instructions\framework-rules.instructions.md\lean-test'
            Remove-Item -LiteralPath $snippet -Force
            if ($leg -eq 'ps') {
                $out = & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File (Join-Path $isolated 'scripts\validate-dist.ps1') dotnet (Join-Path $isolated 'dist') -Check marker-expansion 2>&1
                $code = $LASTEXITCODE
            } else {
                $rootPath = Convert-ToBashPath $isolated
                $out = & $bashExe -c "cd '$rootPath'; bash scripts/validate-dist.sh dotnet dist -Check marker-expansion" 2>&1
                $code = $LASTEXITCODE
            }
            $text = $out -join "`n"
            Write-Host "[ValidateDist $leg missing-marker-expansion] EXIT=$code"; Write-Host $text
            Assert ($code -ne 0) "missing-marker-expansion/$leg should be red"
            Assert ($text.Contains('dotnet : .github/instructions/framework-rules.instructions.md @stack:lean-test resolves to an empty expansion')) "missing-marker-expansion/$leg did not name relpath, marker and stack: $text"
        }
    }

    It 'case 22: an empty dist fails the marker scan instead of reporting a vacuous pass' { Assert-Case 'zero-marker-files' { param($d) Get-ChildItem -LiteralPath $d -Force | Remove-Item -Recurse -Force } 'marker scan found zero files' 'markers' }
    It 'case 23: a dist with zero JSON files fails the JSON check' { Assert-Case 'zero-json' { param($d) Get-ChildItem -LiteralPath $d -Recurse -Force -File -Filter *.json | Remove-Item -Force } 'JSON scan found zero files' 'json' }
    It 'case 24: a dist with zero shell files fails the bash syntax check' { Assert-Case 'zero-shell' { param($d) Get-ChildItem -LiteralPath $d -Recurse -Force -File -Filter *.sh | Remove-Item -Force } 'shell scan found zero files' 'bash-syntax' }
    It 'case 25: a dist with zero PowerShell files fails the PowerShell syntax check' { Assert-Case 'zero-powershell' { param($d) Get-ChildItem -LiteralPath $d -Recurse -Force -File -Filter *.ps1 | Remove-Item -Force } 'PowerShell scan found zero files' 'ps-syntax' }
    $canDenyReads = Test-CanDenyFileReads
    if ($canDenyReads) {
    It 'case 26: unreadable inputs in checks 1 through 4 are named on both validators' {
        $fixtures = @(
            @{ Check='markers';     Relative='README.md';                       Finding='marker scan could not read:' },
            @{ Check='json';        Relative='.claude/settings.json';           Finding='JSON scan could not read:' },
            @{ Check='bash-syntax'; Relative='.claude/hooks/audit-trail.sh';     Finding='shell scan could not read:' },
            @{ Check='ps-syntax';   Relative='.claude/hooks/audit-trail.ps1';    Finding='PowerShell scan could not read:' }
        )
        foreach ($leg in @('ps','bash')) { foreach ($fixture in $fixtures) {
            $root = New-DistCopy
            $target = Join-Path (Join-Path $root 'dotnet') $fixture.Relative
            $handle = $null
            if ($env:OS -eq 'Windows_NT') {
                $handle = [IO.File]::Open($target,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
            } else {
                & $bashExe -c "chmod 000 '$(Convert-ToBashPath $target)'" 2>$null
                Assert ($LASTEXITCODE -eq 0) "could not deny reads to $target"
            }
            try { $r = Invoke-Validator -Root $root -UseBash:($leg -eq 'bash') -Check $fixture.Check }
            finally {
                if ($handle) { $handle.Dispose() }
                else { & $bashExe -c "chmod 600 '$(Convert-ToBashPath $target)'" 2>$null }
            }
            Write-Host "[ValidateDist $leg unreadable-$($fixture.Check)] EXIT=$($r.Exit)"; Write-Host $r.Out
            Assert ($r.Exit -ne 0) "unreadable-$($fixture.Check)/$leg should be red"
            Assert ($r.Out -match [regex]::Escape($fixture.Finding)) "unreadable-$($fixture.Check)/$leg did not identify a read failure: $($r.Out)"
            Assert ($r.Out -match [regex]::Escape((Split-Path $fixture.Relative -Leaf))) "unreadable-$($fixture.Check)/$leg did not name the unreadable file: $($r.Out)"
        }}
    }
    } else { Skip 'case 26: unreadable inputs in checks 1 through 4 are named on both validators' 'this host cannot make a file unreadable to its validator processes (chmod 000 remains readable)' -Invariant }

    It 'case 27: clean checks 1 through 4 report exact independently counted populations on both validators' {
        foreach ($leg in @('ps','bash')) { foreach ($check in @('markers','json','bash-syntax','ps-syntax')) {
            $root = New-DistCopy
            $dist = Join-Path $root 'dotnet'
            $expected = switch ($check) {
                'markers'     { @(Get-ChildItem -LiteralPath $dist -Recurse -Force -File).Count }
                'json'        { @(Get-ChildItem -LiteralPath $dist -Recurse -Force -File -Filter *.json).Count }
                'bash-syntax' { @(Get-ChildItem -LiteralPath $dist -Recurse -Force -File -Filter *.sh).Count }
                'ps-syntax'   { @(Get-ChildItem -LiteralPath $dist -Recurse -Force -File -Filter *.ps1).Count }
            }
            Assert ($expected -gt 0) "independent $check inventory is empty; the clean control would be vacuous"
            $r = Invoke-Validator -Root $root -UseBash:($leg -eq 'bash') -Check $check
            Write-Host "[ValidateDist $leg exact-count-$check] EXIT=$($r.Exit)"; Write-Host $r.Out
            Assert ($r.Exit -eq 0) "exact-count-$check/$leg should be green"
            $countText = if ($check -eq 'markers') { "($expected files scanned)" } else { "all $expected *.$(if($check-eq'json'){'json'}elseif($check-eq'bash-syntax'){'sh'}else{'ps1'}) files" }
            Assert ($r.Out.Contains($countText)) "exact-count-$check/$leg did not report independent count ${expected}: $($r.Out)"
        }}
    }

    It 'case 28: content-only and named-check selectors are rejected together by both validators' {
        foreach ($leg in @('ps','bash')) {
            $root = New-DistCopy
            $r = Invoke-Validator -Root $root -UseBash:($leg -eq 'bash') -Check markers -CombineSelectors
            Write-Host "[ValidateDist $leg conflicting-selectors] EXIT=$($r.Exit)"; Write-Host $r.Out
            Assert ($r.Exit -eq 2) "conflicting-selectors/$leg should be a usage error (EXIT=2)"
            Assert ($r.Out -match '--content-only and -Check cannot be combined') "conflicting-selectors/$leg did not explain the conflict: $($r.Out)"
            Assert ($r.Out -notmatch '(?m)^(OK|FAIL):') "conflicting-selectors/$leg ran a check before rejecting its scope"
        }
    }

    It 'case 29: a dist root containing spaces is preserved by both validators' {
        foreach ($leg in @('ps','bash')) {
            $root = New-DistCopy -Prefix 'validate dist spaced root '
            $expected = @(Get-ChildItem -LiteralPath (Join-Path $root 'dotnet') -Recurse -Force -File).Count
            $r = Invoke-Validator -Root $root -UseBash:($leg -eq 'bash') -Check markers
            Write-Host "[ValidateDist $leg spaced-root] EXIT=$($r.Exit)"; Write-Host $r.Out
            Assert ($r.Exit -eq 0) "spaced-root/$leg should be green"
            Assert ($r.Out.Contains("($expected files scanned)")) "spaced-root/$leg lost or split the dist-root argument: $($r.Out)"
        }
    }

    It 'case 30: syntax mutants in checks 1 through 4 fail for their intended reason on both validators' {
        $fixtures = @(
            @{ Check='markers'; Relative='README.md';                    Text="`n@stack:planted-review-mutant`n"; Finding='unresolved @stack markers in:' },
            @{ Check='json'; Relative='.claude/settings.json';           Text="`nTHIS IS NOT JSON`n"; Finding='invalid JSON' },
            @{ Check='bash-syntax'; Relative='.claude/hooks/guard.sh';    Text="`nif true; then`n"; Finding='bash syntax errors in:' },
            @{ Check='ps-syntax'; Relative='.claude/hooks/guard.ps1';     Text="`nfunction ReviewMutant {`n"; Finding='PS syntax errors' }
        )
        foreach ($leg in @('ps','bash')) { foreach ($fixture in $fixtures) {
            $root = New-DistCopy
            $target = Join-Path (Join-Path $root 'dotnet') $fixture.Relative
            [IO.File]::AppendAllText($target, $fixture.Text)
            $r = Invoke-Validator -Root $root -UseBash:($leg -eq 'bash') -Check $fixture.Check
            Write-Host "[ValidateDist $leg syntax-mutant-$($fixture.Check)] EXIT=$($r.Exit)"; Write-Host $r.Out
            Assert ($r.Exit -ne 0) "syntax-mutant-$($fixture.Check)/$leg should be red"
            Assert ($r.Out -match [regex]::Escape($fixture.Finding)) "syntax-mutant-$($fixture.Check)/$leg failed for the wrong reason: $($r.Out)"
            Assert ($r.Out -match [regex]::Escape((Split-Path $fixture.Relative -Leaf))) "syntax-mutant-$($fixture.Check)/$leg did not name its mutant: $($r.Out)"
        }}
    }

    It 'case 31: a failed bash-leg PowerShell parser child is a named failure' {
        $root = New-DistCopy
        $shim = Join-Path ([IO.Path]::GetTempPath()) ('vd-dead-pwsh-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $shim -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $shim 'pwsh'), "#!/usr/bin/env bash`nexit 17`n")
        & $bashExe -c "chmod +x '$(Convert-ToBashPath (Join-Path $shim 'pwsh'))'" 2>$null
        Assert ($LASTEXITCODE -eq 0) 'could not make the parser-child shim executable'
        $script:scratch += $shim
        $r = Invoke-Validator -Root $root -UseBash -ExtraPathDir $shim -Check ps-syntax
        Write-Host "[ValidateDist bash failed-parser-child] EXIT=$($r.Exit)"; Write-Host $r.Out
        Assert ($r.Exit -ne 0) 'failed-parser-child/bash should be red'
        Assert ($r.Out -match 'PowerShell parser process failed while scanning') "failed-parser-child/bash did not name the child-process failure: $($r.Out)"
    }
    It 'case 39: the bash PowerShell scan accepts an MSYS-style absolute dist root' {
        $root = New-DistCopy
        $expected = @(Get-ChildItem -LiteralPath (Join-Path $root 'dotnet') -Recurse -Force -File -Filter *.ps1).Count
        Assert ($expected -gt 0) 'MSYS-root PowerShell inventory is empty; the control would be vacuous'
        $msysRoot = Convert-ToBashPath $root
        $r = Invoke-Validator -Root $msysRoot -UseBash -Check ps-syntax
        Write-Host "[ValidateDist bash msys-root-ps-syntax] EXIT=$($r.Exit)"; Write-Host $r.Out
        Assert ($r.Exit -eq 0) "MSYS-root ps-syntax/bash should be green, got EXIT=$($r.Exit)"
        Assert ($r.Out.Contains("all $expected *.ps1 files parse cleanly")) "MSYS-root ps-syntax/bash did not report the independent count ${expected}: $($r.Out)"
    }
    It 'case 32: a dangling rendered markdown link fails both validators while code examples stay out of scope' {
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
    It 'case 34: link edge grammar and fenced command parity hold on both validators' {
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

    It 'case 35: step-reference grammar, vacuity guards and allowances agree on both validators' {
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
        foreach ($leg in @('ps','bash')) {
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
                $r = Invoke-Validator -Root $root -UseBash:($leg -eq 'bash') -Check step-references
                Write-Host "[ValidateDist $leg step-$($fixture.Name)] EXIT=$($r.Exit)"; Write-Host $r.Out
                Assert ($r.Out.Contains($fixture.Finding)) "step-$($fixture.Name)/$leg missed '$($fixture.Finding)': $($r.Out)"
                if ($fixture.Green) { Assert ($r.Exit -eq 0) "step-$($fixture.Name)/$leg should be green" }
                else { Assert ($r.Exit -ne 0) "step-$($fixture.Name)/$leg should be red" }
            }
        }
    }

    It 'case 36: a second userPromptSubmitted entry fails both validators' {
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

    It 'case 37: changelog-head grammar applies only to marked template repos on both twins' {
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

    # B-106/F3: this skip used to be false -- "python3 is unavailable" read as "no python here", but
    # a python.org install ships python.exe and no working python3.exe (the Windows Store alias may
    # still resolve by name). Resolve by EXECUTION across python3/python/py and, if the real name
    # isn't literally "python3", expose it under that name via a shim dir prepended to
    # Invoke-Validator's bash PATH -- validate-dist.sh's own
    # VALIDATE_DIST_JSON_TOOL=python3 override still calls the literal name "python3".
    # Get-Command alone is not a capability probe on Windows: the Microsoft Store app-execution
    # alias resolves as python3.exe but exits 9009. Execute the same tiny JSON program the product
    # needs before deciding either that literal python3 works or that an alternate needs a shim.
    $python3Direct = $null
    $resolvedPython = $null
    foreach ($candidate in @('python3','python','py')) {
        $command = Get-Command $candidate -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $command -or -not $command.Source) { continue }
        $probe = $null
        try { $probe = '{}' | & $command.Source -c 'import json,sys; json.load(sys.stdin); sys.stdout.write("ok")' 2>$null } catch { }
        if ($probe -ne 'ok') { continue }
        if ($candidate -eq 'python3') { $python3Direct = $command.Source }
        else { $resolvedPython = $command.Source }
        break
    }
    $py3ShimDir = ''
    if (-not $python3Direct) {
        if ($resolvedPython) {
            $py3ShimDir = Join-Path ([IO.Path]::GetTempPath()) ('py3shim-' + [guid]::NewGuid())
            New-Item -ItemType Directory -Force $py3ShimDir | Out-Null
            $quotedPython = "'" + (Convert-ToBashPath $resolvedPython).Replace("'", "'\''") + "'"
            $shimPath = Join-Path $py3ShimDir 'python3'
            [IO.File]::WriteAllText($shimPath, "#!/usr/bin/env bash`nexec $quotedPython `"`$@`"`n")
            & $bashExe -c "chmod +x '$(Convert-ToBashPath $shimPath)'" 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'could not make the python3 capability shim executable' }
            $script:scratch += $py3ShimDir
        }
    }
    $jq = Get-Command jq -ErrorAction SilentlyContinue | Select-Object -First 1
    $jqWorks = $false
    if ($jq -and $jq.Source) {
        try { & $jq.Source --version 2>$null | Out-Null; $jqWorks = ($LASTEXITCODE -eq 0) } catch { }
    }
    if ((-not $python3Direct -and -not $py3ShimDir) -or -not $jqWorks) {
        if ($Only -eq 'the jq and python3 normalized record streams are byte-identical when both tools exist') {
            Write-Host '[COVERAGE GAP] jq/python3 parser parity was NOT exercised on this host; CI linux must exercise it.'
        }
        Skip 'the jq and python3 normalized record streams are byte-identical when both tools exist' 'no working jq or python interpreter (execution-probed) found on this host; CI linux must exercise this branch.' -Invariant
    } else { It 'the jq and python3 normalized record streams are byte-identical when both tools exist' {
        # This case had never actually executed anywhere before CI ran it: skipped here for want of
        # python3, and on CI it asserted on check 2's output while running --content-only, where
        # checks 1-5 never print. It now asserts the check-8 line, which every run emits and which
        # names the parser that actually ran -- the whole point of pinning the branch.
        $root = New-DistCopy
        $a = Join-Path $root 'python.records'; $b = Join-Path $root 'jq.records'
        try {
            foreach ($pair in @(@{ Tool='python3'; File=$a }, @{ Tool='jq'; File=$b })) {
                # bash writes this path, so it must be a POSIX path even on Windows.
                $env:VALIDATE_DIST_RECORD_STREAM = (Convert-ToBashPath $pair.File)
                $r = Invoke-Validator -Root $root -UseBash -JsonTool $pair.Tool -ExtraPathDir $py3ShimDir -Check hook-registration
                Assert ($r.Out -match "parsed by $($pair.Tool)") "$($pair.Tool) branch did not run: $($r.Out)"
                Assert ($r.Exit -eq 0) "$($pair.Tool) stream setup failed: $($r.Out)"
                Assert (Test-Path -LiteralPath $pair.File) "$($pair.Tool) wrote no record stream"
            }
            # Guard against a vacuous comparison: two empty files are also byte-identical.
            $pyRecords = [IO.File]::ReadAllText($a)
            Assert ($pyRecords.Trim().Length -gt 0) 'the captured record stream is empty; the comparison would be vacuous'
            Assert ($pyRecords -eq [IO.File]::ReadAllText($b)) 'python3 and jq record streams differ'
        } finally { Remove-Item Env:VALIDATE_DIST_RECORD_STREAM -ErrorAction SilentlyContinue }
    } }
} finally { foreach($p in $scratch) { if(Test-Path $p){ Remove-Item -LiteralPath $p -Recurse -Force } } }
exit (Write-TestSummary 'ValidateDist.Tests (B-92)')
