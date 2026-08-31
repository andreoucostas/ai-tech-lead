# Dependency-free hook test harness (no Pester required).
# Why not Pester: corporate Windows boxes ship only Pester 3.x, and mandating a Pester 5 install
# breaks the framework's air-gapped/on-prem stance (the same reason we roll our own elsewhere).
# This harness runs a hook by piping a JSON event to its stdin and capturing exit code + stdout +
# stderr -- and it drives BOTH twins: .ps1 directly via pwsh, .sh via Git's bin\bash.exe wrapper.
#
# CRITICAL fidelity note: a .sh hook MUST be run through a bash whose PATH includes /usr/bin
# (cat/grep/sed/jq). The raw usr\bin\bash.exe launched from Windows lacks /usr/bin, so `input=$(cat)`
# yields nothing and the hook degrades-safe to exit 0 -- a FALSE PASS. Git's bin\bash.exe wrapper
# sets the full MSYS environment, matching how the hook runs in production on Unix. We resolve that.

$script:HarnessBash = '__unset__'
$script:PsExe = $null

# Resolve the suite's own PowerShell host. Subject children must not silently upgrade a direct
# Windows PowerShell 5.1 run to pwsh 7, where a 5.1-only defect cannot exist. The aggregate runner
# may still choose pwsh; this helper preserves whichever supported host actually launched the suite.
function Get-PsExe {
    if ($script:PsExe) { return $script:PsExe }
    $script:PsExe = (Get-Process -Id $PID).Path
    return $script:PsExe
}

function Get-BashPath {
    if ($script:HarnessBash -ne '__unset__') { return $script:HarnessBash }
    # Build candidates null-safe: $env:ProgramFiles / (x86) are null on non-Windows pwsh (and (x86)
    # can be unset on Windows), and Join-Path on a null/empty Path THROWS -- which would crash before
    # the bash-on-PATH fallback below. Only add a Git path when its env var is actually set.
    $cands = @()
    if ($env:ProgramFiles)        { $cands += (Join-Path $env:ProgramFiles 'Git\bin\bash.exe') }
    if (${env:ProgramFiles(x86)}) { $cands += (Join-Path ${env:ProgramFiles(x86)} 'Git\bin\bash.exe') }
    # Then a `bash` on PATH (Linux CI, or a user who put Git's bin on PATH) -- the path that
    # makes the .sh twin tests actually run on Unix.
    $onPath = (Get-Command bash -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if ($onPath) { $cands += $onPath }
    foreach ($p in $cands) { if ($p -and (Test-Path -LiteralPath $p)) { $script:HarnessBash = $p; return $p } }
    $script:HarnessBash = $null
    return $null
}

# Invoke a native child without routing either output stream through PowerShell's native-command
# adapter. Windows PowerShell 5.1 turns redirected stderr into ErrorRecords and then renders those
# records into the target file, adding the executable name and this harness's call site. Reading the
# process streams directly observes the child's output instead, identically under Desktop and Core.
function Invoke-RawProcess {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments,
        [string]$Stdin = ''
    )
    # ProcessStartInfo.Arguments is one command-line string on .NET Framework. These harness paths
    # cannot contain a literal quote; quoting every argument preserves spaces without a shell.
    foreach ($arg in $Arguments) {
        if ($arg -match '"') { throw "Cannot invoke a harness argument containing a quote: $arg" }
    }
    $stdinFile = [IO.Path]::GetTempFileName()
    $stdoutFile = [IO.Path]::GetTempFileName()
    $stderrFile = [IO.Path]::GetTempFileName()
    try {
        [IO.File]::WriteAllText($stdinFile, $Stdin, (New-Object System.Text.UTF8Encoding($false)))
        $argumentString = (($Arguments | ForEach-Object { '"' + $_ + '"' }) -join ' ')
        $p = Start-Process -FilePath $FileName -ArgumentList $argumentString -NoNewWindow -Wait -PassThru `
            -RedirectStandardInput $stdinFile -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
        return [pscustomobject]@{
            Exit = $p.ExitCode
            # Normalise the LINE ENDING, nothing else. Reading the streams raw (which is the point of
            # this function) also stops hiding that a PowerShell child terminates lines with CRLF
            # while a bash child uses LF: measured on the same guard message, stderr ended 13,10
            # against 10. That is a host convention, in the same class as the ErrorRecord decoration
            # this function exists to avoid, and the twins are compared byte-for-byte -- so without
            # this every stderr comparison fails on both hosts. Content differences survive intact.
            Out = [IO.File]::ReadAllText($stdoutFile).Replace("`r`n", "`n").TrimEnd("`n")
            Err = [IO.File]::ReadAllText($stderrFile).Replace("`r`n", "`n")
        }
    } finally {
        foreach ($tempFile in $stdinFile,$stdoutFile,$stderrFile) {
            if (Test-Path -LiteralPath $tempFile) { [IO.File]::Delete($tempFile) }
        }
    }
}

# Run a hook with $Json on stdin. Returns @{Exit;Out;Err} -- or $null for a .sh when no bash exists
# (caller treats $null as "skip", never as pass/fail).
function Invoke-Hook {
    param([Parameter(Mandatory)][string]$Path, [string]$Json = '')
    # The child inherits the attached console's output encoding even though its streams are pipes.
    # Pin that inherited encoding so UTF-8 hook text is not replaced before raw capture can read it.
    $prevOut = [Console]::OutputEncoding; $encChanged = $false
    try {
        try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false); $encChanged = $true } catch { }
        if ($Path -match '\.ps1$') {
            return Invoke-RawProcess -FileName (Get-PsExe) `
                -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Path) -Stdin $Json
        }
        $bash = Get-BashPath
        if (-not $bash) { return $null }
        return Invoke-RawProcess -FileName $bash -Arguments @($Path) -Stdin $Json
    } finally {
        if ($encChanged) { try { [Console]::OutputEncoding = $prevOut } catch { } }
    }
}

# Run a script with zero or more arguments. Returns $null for a .sh when bash is unavailable.
function RunArg {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string[]]$Arguments = @(),
        [string[]]$BashOptions = @()
    )
    # Deliberately NOT Invoke-RawProcess. That exists for Invoke-Hook, where 5.1's ErrorRecord
    # rendering corrupted a byte-for-byte TWIN COMPARISON. RunArg's callers assert on exit codes and
    # on stdout text, never on stderr equality, so they never needed it -- and routing them through
    # it regressed CI on linux/monorepo with "[FAIL] missing context skips -- Broken pipe":
    # Start-Process redirecting stdin for a child that never reads it raises EPIPE there, a platform
    # difference invisible on Windows where both hosts were verified. Narrow the fix to what needed
    # fixing.
    $ef = [IO.Path]::GetTempFileName()
    # PowerShell decodes a native child's stdout bytes using [Console]::OutputEncoding. On a non-UTF-8
    # console code page the child's UTF-8 output arrives mangled and -match silently misses.
    $prevOut = [Console]::OutputEncoding; $encChanged = $false
    try {
        try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false); $encChanged = $true } catch { }
        if ($Path -match '\.ps1$') { $out = & (Get-PsExe) -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments 2>$ef }
        else { $bash = Get-BashPath; if (-not $bash) { return $null }; $out = & $bash @BashOptions $Path @Arguments 2>$ef }
        return [pscustomobject]@{ Exit=$LASTEXITCODE; Out=($out -join "`n"); Err=[IO.File]::ReadAllText($ef) }
    } finally {
        if ($encChanged) { try { [Console]::OutputEncoding = $prevOut } catch { } }
        if (Test-Path -LiteralPath $ef) { [IO.File]::Delete($ef) }
    }
}
# Normalise a hook result to a decision: BLOCK (Claude exit 2), DENY (Copilot JSON), ALLOW (exit 0,
# no deny), SKIP (no bash), or EXITn for anything unexpected.
function Get-Decision {
    param($Result)
    if ($null -eq $Result) { return 'SKIP' }
    if ($Result.Exit -eq 2) { return 'BLOCK' }
    if ($Result.Exit -eq 0 -and $Result.Out -match '"permissionDecision"\s*:\s*"deny"') { return 'DENY' }
    if ($Result.Exit -eq 0) { return 'ALLOW' }
    return "EXIT$($Result.Exit)"
}

# Event-shape builders: same logical write, expressed in each surface's field names. Used to feed
# identical content to both twins and to exercise the Claude (PascalCase) vs Copilot (camelCase) paths.
function New-ClaudeEvent  { param($File,$Content) (@{ tool_name='Write'; tool_input=@{ file_path=$File; content=$Content } } | ConvertTo-Json -Compress -Depth 6) }
function New-CopilotEvent { param($File,$Content) (@{ toolName='create'; toolArgs=@{ path=$File; file_text=$Content } } | ConvertTo-Json -Compress -Depth 6) }

# --- Sandbox helpers: reproduce "no jq / no working python" without an empty PATH breaking the
# script's own plumbing and without an inherited PATH accidentally exposing a real jq/python on
# either CI leg. Originally an inline block in FrameworkDoctor.Tests.ps1's sandboxed case; pulled
# up here so every hook test file that needs the same sandbox shares one grammar instead of
# reimplementing the Git-Bash-copy / POSIX-symlink-inside-bash split per file.
function ConvertTo-PosixPath {
    param([string]$Path)
    if ($Path -match '^([A-Za-z]):[\\/](.*)$') { return '/' + $Matches[1].ToLowerInvariant() + '/' + $Matches[2].Replace('\', '/') }
    return $Path.Replace('\', '/')
}

# Resolve a WORKING python on this host, by execution rather than by name -- same grammar as
# guard.sh/route-prompt.sh/session-start.sh/framework-doctor.sh. Used only to locate a real
# interpreter's file path for test fixtures. $env:ATL_TEST_PYTHON is an escape hatch for a host
# whose normal command resolution hides a real interpreter (e.g. a broken session PATH) -- set it
# to an absolute interpreter path rather than hardcoding one here. Returns $null, never a guess,
# when no working interpreter can be found; callers must treat that as a real "cannot exercise
# this branch on this host" and take an invariant-guarding skip rather than failing.
function Resolve-HostPython {
    if ($env:ATL_TEST_PYTHON -and (Test-Path -LiteralPath $env:ATL_TEST_PYTHON)) {
        $ok = $null
        try { $ok = '{}' | & $env:ATL_TEST_PYTHON -c 'import json,sys; json.load(sys.stdin); sys.stdout.write(chr(111)+chr(107))' 2>$null } catch { }
        if ($ok -eq 'ok') { return $env:ATL_TEST_PYTHON }
    }
    foreach ($cand in 'python3', 'python', 'py') {
        $cmd = Get-Command $cand -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $cmd -or -not $cmd.Source) { continue }
        $ok = $null
        try { $ok = '{}' | & $cmd.Source -c 'import json,sys; json.load(sys.stdin); sys.stdout.write(chr(111)+chr(107))' 2>$null } catch { }
        if ($ok -eq 'ok') { return $cmd.Source }
    }
    return $null
}

# Same idea as Resolve-HostPython, for jq control cases. $env:ATL_TEST_JQ is the equivalent escape
# hatch for a host whose normal command resolution hides a real jq.
function Resolve-HostJq {
    if ($env:ATL_TEST_JQ -and (Test-Path -LiteralPath $env:ATL_TEST_JQ)) { return $env:ATL_TEST_JQ }
    $cmd = Get-Command jq -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    return $null
}

# Build a bash shim script (exec-wrapper) that runs $RealExePath under its own real location --
# needed so a sandboxed PATH can expose a real interpreter/tool under an alternate or bare name
# without copying the exe itself (a copy can lose sibling-DLL resolution, e.g. python.exe). Uses
# env to find bash so it does not depend on bash living at one fixed path across hosts; the caller
# is responsible for making sure "bash" itself resolves inside the sandbox this shim runs in.
function New-ExecShim {
    param([Parameter(Mandatory)][string]$RealExePath)
    return "#!/usr/bin/env bash`nexec " + (ConvertTo-PosixPath $RealExePath) + " `"`$@`"`n"
}

# Run $ScriptPath under bash with PATH restricted to ONLY $Utilities (+ $FakeBins, + a real
# interpreter aliased as $ExposeInterpreterAs if requested). Platform split matches
# FrameworkDoctor.Tests.ps1's original sandbox: Git Bash (MSYS) needs its exes COPIED alongside
# their DLLs (symlinks are unreliable there); POSIX hosts build the sandbox's symlinks INSIDE bash,
# because pwsh-created symlinks resolved as "command not found" on the linux CI runner. Setup runs
# with the full inherited PATH; only the script invocation itself sees the restricted one. The
# script is always run AS AN ARGUMENT TO bash, never executed directly: shipped hooks are tracked
# without the executable bit (Windows ignores that, Linux enforces it), so a direct exec would be
# "Permission denied" on a Linux leg while working by accident on Windows.
function Invoke-Sandboxed {
    param(
        [Parameter(Mandatory)][string]$Bash,
        [Parameter(Mandatory)][string]$ScriptPath,
        [string[]]$Utilities = @('cat', 'grep', 'sed', 'sort', 'head'),
        [hashtable]$FakeBins = @{},
        [string]$ExposeInterpreterAs = '',
        $Stdin = $null
    )
    $r = Join-Path ([IO.Path]::GetTempPath()) ('sandbox-' + [guid]::NewGuid())
    $bin = Join-Path $r 'bin'; New-Item -ItemType Directory -Force $bin | Out-Null
    $ef = [IO.Path]::GetTempFileName()
    # A fake bin's own shim shebang (`env bash`) needs "bash" resolvable inside the restricted
    # sandbox PATH -- add it to the copied/symlinked utility set whenever a shim might run.
    $needsBash = ($FakeBins.Count -gt 0) -or $ExposeInterpreterAs
    $effectiveUtilities = if ($needsBash -and ($Utilities -notcontains 'bash')) { $Utilities + @('bash') } else { $Utilities }
    try {
        foreach ($name in $FakeBins.Keys) { [IO.File]::WriteAllText((Join-Path $bin $name), $FakeBins[$name]) }
        if ($Bash -match '\\Git\\bin\\bash\.exe$') {
            $git = Split-Path (Split-Path $Bash -Parent) -Parent; $usr = Join-Path $git 'usr/bin'
            foreach ($n in $effectiveUtilities) { $exe = Join-Path $usr "$n.exe"; if (Test-Path -LiteralPath $exe) { Copy-Item $exe $bin } }
            Get-ChildItem $usr -Filter '*.dll' | Copy-Item -Destination $bin
            if ($ExposeInterpreterAs) {
                $real = Resolve-HostPython
                if ($real) { [IO.File]::WriteAllText((Join-Path $bin $ExposeInterpreterAs), (New-ExecShim $real)) }
            }
            $runner = Join-Path $usr 'bash.exe'
            & $runner -c ('chmod +x "{0}"/*' -f (ConvertTo-PosixPath $bin)) 2>$null | Out-Null
            $old = $env:PATH
            try {
                $env:PATH = $bin
                if ($null -ne $Stdin) { $out = $Stdin | & $runner $ScriptPath 2>$ef } else { $out = & $runner $ScriptPath 2>$ef }
            } finally { $env:PATH = $old }
        } else {
            $bashBin = ConvertTo-PosixPath $bin
            $bashExePosix = ConvertTo-PosixPath $Bash
            $utilList = ($effectiveUtilities -join ' ')
            $exposeCmd = ''
            if ($ExposeInterpreterAs) {
                $exposeCmd = "; ln -sf `"`$(command -v python3 2>/dev/null || command -v python 2>/dev/null || command -v py 2>/dev/null)`" `"$bashBin/$ExposeInterpreterAs`""
            }
            $setup = "for t in $utilList; do ln -sf `"`$(command -v `$t)`" `"$bashBin/`$t`"; done$exposeCmd; chmod +x `"$bashBin`"/* 2>/dev/null; PATH=`"$bashBin`" `"$bashExePosix`" `"$ScriptPath`""
            if ($null -ne $Stdin) { $out = $Stdin | & $Bash -c $setup 2>$ef } else { $out = & $Bash -c $setup 2>$ef }
        }
        [pscustomobject]@{ Exit = $LASTEXITCODE; Out = ($out -join "`n"); Err = [IO.File]::ReadAllText($ef) }
    } finally {
        Remove-Item -Force -ErrorAction SilentlyContinue $ef
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $r
    }
}

# --- tiny test registry / assertions (no external framework) ---
$script:Tests = [System.Collections.Generic.List[object]]::new()
function It      { param([string]$Name,[scriptblock]$Body)
    try { & $Body; $script:Tests.Add([pscustomobject]@{ Name=$Name; State='PASS'; Msg=''; Invariant=$false }) }
    catch { $script:Tests.Add([pscustomobject]@{ Name=$Name; State='FAIL'; Msg=$_.Exception.Message; Invariant=$false }) } }
# -Invariant marks a skip as invariant-guarding: the host genuinely lacks a required capability,
# not a bug in the fixture. Write-TestSummary calls these out in a named block so they cannot
# scroll past unnoticed inside an otherwise-green summary.
function Skip    { param([string]$Name,[string]$Why,[switch]$Invariant) $script:Tests.Add([pscustomobject]@{ Name=$Name; State='SKIP'; Msg=$Why; Invariant=[bool]$Invariant }) }
function Assert  { param([bool]$Cond,[string]$Msg) if (-not $Cond) { throw $Msg } }
function Assert-Decision { param($Result,[string]$Expected,[string]$Ctx)
    $got = Get-Decision $Result
    if ($got -ne $Expected) { throw "$Ctx : expected $Expected, got $got (exit=$($Result.Exit))" } }

function Reset-Tests { $script:Tests.Clear() }
function Write-TestSummary {
    param([string]$Title)
    # @() is load-bearing, not style. Under Windows PowerShell 5.1 a pipeline yielding exactly ONE
    # object has no .Count, so `(... | Where-Object ...).Count` returns $null -- and `return $fail`
    # then makes `exit (Write-TestSummary ...)` exit 0 while the summary prints [FAIL]. The runner
    # sums child exit codes, so a single failing test in a file scored as green. Two or more
    # failures returned an int and were caught, which is why this only ever hid a lone regression.
    # pwsh 7 returns 1 for the same expression, so CI and pwsh boxes never saw it.
    $pass = @($script:Tests | Where-Object State -eq 'PASS').Count
    $fail = @($script:Tests | Where-Object State -eq 'FAIL').Count
    $skip = @($script:Tests | Where-Object State -eq 'SKIP').Count
    foreach ($t in $script:Tests) {
        $mark = switch ($t.State) { 'PASS' {'[ok]'} 'FAIL' {'[FAIL]'} 'SKIP' {'[skip]'} }
        Write-Host ("{0} {1}{2}" -f $mark, $t.Name, $(if ($t.Msg) { " -- $($t.Msg)" } else { '' }))
    }
    Write-Host ("{0}: {1} passed, {2} failed, {3} skipped" -f $Title, $pass, $fail, $skip)
    # A skip buried inline in a green summary reads as coverage. Call out invariant-guarding
    # skips (host genuinely lacks a required capability) by name, separately.
    $invariantSkips = @($script:Tests | Where-Object { $_.State -eq 'SKIP' -and $_.Invariant })
    if ($invariantSkips.Count -gt 0) {
        Write-Host ("INVARIANT-GUARDING SKIPS ({0}) -- this host lacks a capability these cases require; they are NOT passing and NOT covering their branch on this run:" -f $invariantSkips.Count)
        foreach ($s in $invariantSkips) { Write-Host ("  - {0}: {1}" -f $s.Name, $s.Msg) }
    }
    return $fail
}
