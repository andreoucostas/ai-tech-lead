# B-92 executable red-tests. These use real composed dists: synthetic JSON fixtures hid the prior
# false greens. The child is bound to THIS host, not Get-PsExe (B-90).
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
Reset-Tests
$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$validator = Join-Path $repo 'scripts\validate-dist.ps1'
$bashValidator = Join-Path $repo 'scripts/validate-dist.sh'
$bashExe = Get-BashPath
$scratch = @()

function New-DistCopy {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('validate-dist-' + [guid]::NewGuid().ToString('N'))
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
    param([string]$Root, [switch]$UseBash, [string]$JsonTool, [switch]$FullValidation, [string]$ExtraPathDir)
    # Checks 1-5 re-parse every shipped file, which dominates this suite's runtime. Red cases only
    # need checks 6-8; the green anchors run the full validator so the skipped group is still
    # exercised on both legs. See VALIDATE_DIST_CONTENT_ONLY in the validators.
    # Passed as an ARGUMENT, never an environment variable: an inherited ambient switch could
    # silently downgrade a run that asked for full validation (sol's review of this change).
    $contentOnly = -not $FullValidation
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
        # Invoked as `bash <script>`, never `./<script>`: the file is mode 644 in git, which Windows
        # ignores and Linux enforces, so `./` gave "Permission denied" on the CI linux leg only.
        # Every other caller in this repo (CI, DEVELOPING.md) spells it this way too.
        $command = "export PATH=$pathPrefix`:`$PATH; cd '$cwd'; ${override}bash scripts/validate-dist.sh dotnet '$dist'$flag"
        $out = & $bashExe -c $command 2>&1; $code = $LASTEXITCODE
    } else {
        $argv = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$validator,'dotnet',$Root)
        if ($contentOnly) { $argv += '--content-only' }
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
# The residual cost is checks 1-5 re-running for every case, which no subset fixes; see the backlog
# entry filed with this change.
function Assert-Case {
    param([string]$Name, [scriptblock]$Mutate, [string]$Finding, [switch]$Green, [switch]$PsOnly, [switch]$FullValidation)
    $legs = if ($PsOnly) { @('ps') } else { @('ps','bash') }
    foreach ($leg in $legs) {
        $root = New-DistCopy
        & $Mutate (Join-Path $root 'dotnet')
        $r = Invoke-Validator -Root $root -UseBash:($leg -eq 'bash') -FullValidation:$FullValidation
        Write-Host "[ValidateDist $leg $Name] EXIT=$($r.Exit)"; Write-Host $r.Out
        Assert ($r.Out -match '(?m)^(OK|FAIL):') "$Name/$leg did not reach a validator check: $($r.Out)"
        Assert ($r.Out -match [regex]::Escape($Finding)) "$Name/$leg did not emit its target finding '$Finding': $($r.Out)"
        if ($Green) { Assert ($r.Exit -eq 0) "$Name/$leg should be green, got EXIT=$($r.Exit)" }
        else { Assert ($r.Exit -ne 0) "$Name/$leg should be red, got EXIT=0" }
    }
}
function Replace-Text { param($Path,$Find,$Replace) $t=[IO.File]::ReadAllText($Path); [IO.File]::WriteAllText($Path,$t.Replace($Find,$Replace)) }

# Measured on a 12-core box: throttle 4 = 218s, 8 = 183s, 12 = 179s, sequential = 391s. The floor
# is the longest single case, so past ~8 there is nothing left to win. Capped at 8 and scaled to the
# host so a 2-core CI runner is not over-subscribed into being slower than sequential.
$throttle = if ($env:VALIDATE_DIST_TESTS_THROTTLE) { [int]$env:VALIDATE_DIST_TESTS_THROTTLE }
            else { [Math]::Max(2, [Math]::Min(8, [Environment]::ProcessorCount)) }
if (-not $Only) {
    # ---- driver: one child per case, $throttle at a time -------------------------------------
    # Case names are read back out of this file rather than kept in a second list, so a case can
    # never be added and silently not dispatched -- the failure mode would be a green run that
    # tested less, which is the whole class this suite exists to prevent.
    $caseNames = [regex]::Matches((Get-Content $PSCommandPath -Raw), "(?m)^\s*It\s+'([^']+)'") |
                 ForEach-Object { $_.Groups[1].Value }
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
function Skip { param([string]$Name, [string]$Why, [switch]$Invariant) if ($Name -ne $Only) { return }; & $__origSkip @PSBoundParameters }

try {
    It 'case 1: settings.json with zero handlers fails check 8' { Assert-Case 'zero-settings' { param($d) $p=Join-Path $d '.claude\settings.json'; $t=[IO.File]::ReadAllText($p); [IO.File]::WriteAllText($p,[regex]::Replace($t,'"command"','"commandX"',6)) } 'settings.json : registration file yields zero handlers' }
    It 'case 2: settings.windows.json with zero handlers fails check 8' { Assert-Case 'zero-windows' { param($d) $p=Join-Path $d '.claude\settings.windows.json'; $t=[IO.File]::ReadAllText($p); [IO.File]::WriteAllText($p,[regex]::Replace($t,'"command"','"commandX"',6)) } 'settings.windows.json : registration file yields zero handlers' -PsOnly }   # bash path identical to case 1
    It 'case 3: an absolute registration fails check 8' { Assert-Case 'absolute' { param($d) Replace-Text (Join-Path $d '.claude\settings.json') '.claude/hooks/session-start.ps1' 'C:/definitely-missing/session-start.ps1' } 'is an absolute path' }
    It 'case 4: a quoted missing -File target fails check 8' { Assert-Case 'quoted-missing' { param($d) Replace-Text (Join-Path $d '.claude\settings.json') '.claude/hooks/session-start.ps1' '\".claude/hooks/definitely missing.ps1\"' } 'does not exist in this dist' }
    It 'case 5: a quoted real -File target stays green' { Assert-Case 'quoted-real' { param($d) Replace-Text (Join-Path $d '.claude\settings.json') '.claude/hooks/session-start.ps1' '\".claude/hooks/session-start.ps1\"' } 'all 26 hook registrations resolve' -Green -FullValidation }
    It 'case 6: a single Copilot leg fails check 8' { Assert-Case 'single-leg' { param($d) $p=Join-Path $d '.github\hooks\hooks.json'; $t=[IO.File]::ReadAllText($p); $t=[regex]::Replace($t,'\s*"powershell":\s*"[^"]+",?','',1); [IO.File]::WriteAllText($p,$t) } 'has only one bash/powershell leg' -PsOnly }   # bash path: same parser branch as case 13
    It 'case 7: an unrelated command object does not change registration scoping' { Assert-Case 'unrelated-command' { param($d) $p=Join-Path $d '.claude\settings.json'; $t=[IO.File]::ReadAllText($p); [IO.File]::WriteAllText($p,$t.Replace('"hooks": {','"unrelated": { "type": "command" },' + [Environment]::NewLine + '  "hooks": {')) } 'all 26 hook registrations resolve' -Green -PsOnly }   # bash green path: case 12
    It 'case 8: a missing hook twin fails check 8' { Assert-Case 'missing-twin' { param($d) Remove-Item -LiteralPath (Join-Path $d '.claude\hooks\audit-trail.sh') -Force } 'exists but its twin' }
    It 'case 9: a dead documented command fails check 7' { Assert-Case 'dead-doc' { param($d) Replace-Text (Join-Path $d 'README.md') 'scripts/install.ps1' 'scripts/definitely-missing.ps1' } 'dead instructions in shipped docs' }
    # -Force: on Linux, PowerShell treats dot-directories as hidden, so without it this mutation left
    # every .md under .claude/ and .github/ in place and the case failed on the CI linux leg only.
    # The validator had the same blind spot, which is what this case ended up exposing.
    It 'case 10: no markdown files fails check 7' { Assert-Case 'no-docs' { param($d) Get-ChildItem -LiteralPath $d -Recurse -Filter *.md -Force | Remove-Item -Force } 'no-dead-instruction scanned zero documentation files' }
    It 'case 11: an empty tree fails check 6' { Assert-Case 'empty-tree' { param($d) Get-ChildItem -LiteralPath $d -Force | Remove-Item -Recurse -Force } 'no-meta-leak scanned zero files' }
    # The green anchors run the FULL validator (checks 1-8) on both legs, so the group the red cases
    # skip for speed is still exercised here — and so an over-strict check 6/7/8 cannot hide behind
    # a partial run.
    It 'case 12: an unmutated dist stays green under the FULL validator' { Assert-Case 'clean' { param($d) } 'all 26 hook registrations resolve' -Green -FullValidation }
    # Case 13 and 14 are the structural guards, and both exist because all three parsers (PowerShell
    # ConvertFrom-Json, python3, jq) disagreed about malformed input the first time round: an event
    # whose value was an object reported "no bash/powershell leg" on two legs and "not an object" on
    # the third. The assertion is one message every leg must produce.
    It 'case 13: an event whose value is not an array fails check 8 on every parser' { Assert-Case 'bad-event-shape' { param($d) $p=Join-Path $d '.github\hooks\hooks.json'; $t=[IO.File]::ReadAllText($p); [IO.File]::WriteAllText($p,$t.Replace('"sessionStart": [','"sessionStart": {"invalid":"not-an-array"}, "sessionStartX": [')) } "hook event 'sessionStart' must be an array" }
    # Case 14 is the guard for a parser that dies mid-stream: without checking the parser's exit
    # status, the records emitted before it died left handlers > 0 and the per-file guard satisfied.
    It 'case 14: an unparseable registration file fails check 8 rather than yielding a short stream' { Assert-Case 'unparseable' { param($d) [IO.File]::WriteAllText((Join-Path $d '.claude\settings.json'), '{"hooks": {"SessionStart": [ THIS IS NOT JSON') } 'registration file is unparseable' }
    # Case 15 proves the base64 record framing: a tab or a backslash inside a command value must not
    # be able to shift a field. Spelling records as plain TSV made jq escape backslashes while
    # python3 printed them raw, which desynchronised the two branches on real shipped data.
    # Case 16 is a PLATFORM divergence, not a code one: Windows resolves `.PS1` to the shipped
    # `.ps1` and Linux does not, so this registration passed here and would have failed a consumer's
    # Linux CI. Both twins now resolve case-exactly, so both must call it missing.
    It 'case 16: a registration whose casing differs from the shipped file fails check 8' { Assert-Case 'case-mismatch' { param($d) Replace-Text (Join-Path $d '.claude\settings.json') '.claude/hooks/session-start.ps1' '.claude/hooks/session-start.PS1' } 'does not exist in this dist' }
    It 'case 15: a tab and a backslash in a command value cannot break the record framing' { Assert-Case 'framing' { param($d) Replace-Text (Join-Path $d '.claude\settings.json') '-File .claude/hooks/session-start.ps1' '-File .claude\\hooks\\definitely\tmissing.ps1' } 'does not exist in this dist' }

    It 'case 17: a missing framework-rules import fails the full validator' { Assert-Case 'missing-framework-import' { param($d) $p=Join-Path $d 'CLAUDE.md'; $t=[IO.File]::ReadAllText($p); [IO.File]::WriteAllText($p,$t.Replace('@.github/instructions/framework-rules.instructions.md','')) } 'CLAUDE.md is missing required import @.github/instructions/framework-rules.instructions.md.' -FullValidation }
    It 'case 18: a citation to a moved CLAUDE.md section fails the full validator' { Assert-Case 'moved-section-citation' { param($d) $p=Join-Path $d 'README.md'; [IO.File]::AppendAllText($p,"`nPlant: ``CLAUDE.md > SOLID```n") } 'cites CLAUDE.md > SOLID, but that heading does not exist' -FullValidation }
    It 'case 19: prose after valid finite-registry citations does not become a heading' { Assert-Case 'citation-prose' { param($d) $p=Join-Path $d 'README.md'; [IO.File]::AppendAllText($p,"`nCLAUDE.md > Conventions wins on any conflict.`nCLAUDE.md > Boy Scout Rule before considering the work complete.`n[CLAUDE.md](./CLAUDE.md) > Conventions.`n") } 'all registered section-path references resolve' -Green -FullValidation }
    It 'case 20: a missing stack snippet fails marker expansion without touching the live source tree' {
        foreach ($leg in @('ps','bash')) {
            $isolated = New-ValidatorRepoCopy
            $snippet = Join-Path $isolated 'src\stacks\dotnet\snippets\.github\instructions\framework-rules.instructions.md\lean-test'
            Remove-Item -LiteralPath $snippet -Force
            if ($leg -eq 'ps') {
                $out = & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File (Join-Path $isolated 'scripts\validate-dist.ps1') dotnet (Join-Path $isolated 'dist') 2>&1
                $code = $LASTEXITCODE
            } else {
                $rootPath = Convert-ToBashPath $isolated
                $out = & $bashExe -c "cd '$rootPath'; bash scripts/validate-dist.sh dotnet dist" 2>&1
                $code = $LASTEXITCODE
            }
            $text = $out -join "`n"
            Write-Host "[ValidateDist $leg missing-marker-expansion] EXIT=$code"; Write-Host $text
            Assert ($code -ne 0) "missing-marker-expansion/$leg should be red"
            Assert ($text.Contains('dotnet : .github/instructions/framework-rules.instructions.md @stack:lean-test resolves to an empty expansion')) "missing-marker-expansion/$leg did not name relpath, marker and stack: $text"
        }
    }

    # B-106/F3: this skip used to be false -- "python3 is unavailable" read as "no python here", but
    # a python.org install ships python.exe and no python3.exe, so Get-Command python3 alone can miss
    # a perfectly working interpreter. Resolve by EXECUTION across python3/python/py (Resolve-HostPython
    # in _HookHarness.ps1) and, if the real name isn't literally "python3", expose it under that name
    # via a shim dir prepended to Invoke-Validator's bash PATH -- validate-dist.sh's own
    # VALIDATE_DIST_JSON_TOOL=python3 override still calls the literal name "python3".
    $python3Direct = Get-Command python3 -ErrorAction SilentlyContinue
    $py3ShimDir = ''
    if (-not $python3Direct) {
        $resolvedPython = Resolve-HostPython
        if ($resolvedPython) {
            $py3ShimDir = Join-Path ([IO.Path]::GetTempPath()) ('py3shim-' + [guid]::NewGuid())
            New-Item -ItemType Directory -Force $py3ShimDir | Out-Null
            [IO.File]::WriteAllText((Join-Path $py3ShimDir 'python3'), (New-ExecShim $resolvedPython))
            if ($bashExe -and $bashExe -match '\\Git\\bin\\bash\.exe$') {
                $git = Split-Path (Split-Path $bashExe -Parent) -Parent
                & (Join-Path $git 'usr/bin/bash.exe') -c ('chmod +x "{0}"/*' -f (ConvertTo-PosixPath $py3ShimDir)) 2>$null | Out-Null
            }
            $script:scratch += $py3ShimDir
        }
    }
    if (-not $python3Direct -and -not $py3ShimDir) {
        if ($Only -eq 'the jq and python3 normalized record streams are byte-identical when both tools exist') {
            Write-Host '[COVERAGE GAP] python3 JSON branch was NOT exercised on this host; CI linux must exercise it.'
        }
        Skip 'the jq and python3 normalized record streams are byte-identical when both tools exist' 'no working python interpreter (python3/python/py, execution-probed) found on this host; CI linux must exercise this branch.' -Invariant
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
                $r = Invoke-Validator -Root $root -UseBash -JsonTool $pair.Tool -ExtraPathDir $py3ShimDir
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
