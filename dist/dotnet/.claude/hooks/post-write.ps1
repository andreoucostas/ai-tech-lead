# PostToolUse hook -- incremental dotnet build after a write/edit on build-relevant files
# (.cs sources + MSBuild/Razor inputs: .csproj/.sln/.props/.targets/.razor/.cshtml).
# Tool surfaces handled:
#   Claude Code (CLI + VS Code extension)  -- tool_name in {Write,Edit}; path at tool_input.file_path
#   GitHub Copilot (cloud agent + CLI)     -- toolName  in {edit,create}; path at toolArgs.filePath
# Throttled to one build per 60 seconds to avoid stomping on a long-running compile.

$ErrorActionPreference = 'SilentlyContinue'

# Bounded build/type-check. The agent host waits for this hook (Claude Code's default hook timeout is
# 600 s), so the tool runs as a child process for at most the budget: 45 s, or
# ATL_POSTWRITE_BUDGET_SEC (whole seconds, 1-600) when set in the hook's environment. On expiry the
# whole process tree is killed. Returns $null when the result is unknown -- no launchable tool, a
# failed launch, or an exceeded budget -- so an unverified build is never reported as broken.
function Invoke-BoundedTool([string]$Name, [string[]]$Arguments, [string]$WorkDir) {
    $budget = 45
    $requested = 0
    if ([int]::TryParse([string]$env:ATL_POSTWRITE_BUDGET_SEC, [ref]$requested) -and $requested -ge 1 -and $requested -le 600) {
        $budget = $requested
    }
    $deadline = [DateTime]::UtcNow.AddSeconds($budget)
    # Only files CreateProcess starts directly: `npx` also resolves to an extensionless shell script
    # and to npx.ps1, neither of which Process.Start can launch.
    $exe = @(Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue |
        Where-Object { $_.Source -match '\.(exe|cmd|bat)$' } | Select-Object -First 1)
    if ($exe.Count -eq 0) { return $null }
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $exe[0].Source
        $psi.Arguments = (($Arguments | ForEach-Object { '"' + $_ + '"' }) -join ' ')
        $psi.WorkingDirectory = $WorkDir
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.StandardInput.Close()
        $stdout = $proc.StandardOutput.ReadToEndAsync()
        $stderr = $proc.StandardError.ReadToEndAsync()
    } catch { return $null }
    # The stream reads share the deadline: a tool that exits while a server it spawned still holds
    # the output pipe must not stall the turn either.
    $done = $proc.WaitForExit([int][Math]::Max(0, ($deadline - [DateTime]::UtcNow).TotalMilliseconds))
    if ($done) {
        $done = [System.Threading.Tasks.Task]::WaitAll([System.Threading.Tasks.Task[]]@($stdout, $stderr),
            [int][Math]::Max(0, ($deadline - [DateTime]::UtcNow).TotalMilliseconds))
    }
    if (-not $done) {
        & taskkill.exe /T /F /PID $proc.Id *> $null
        return $null
    }
    # The compiler reports its errors on stdout; keep its tail, then a short stderr tail.
    $outLines = @($stdout.Result -split "\r?\n" | Where-Object { $_ -ne '' } | Select-Object -Last 20)
    $errLines = @($stderr.Result -split "\r?\n" | Where-Object { $_ -ne '' } | Select-Object -Last 5)
    return [pscustomobject]@{ Code = $proc.ExitCode; Lines = @($outLines + $errLines) }
}

$null = New-Item -ItemType Directory -Path .claude\.state -Force

$inputJson = [Console]::In.ReadToEnd()
$filePath = ''
# Pre-declare so a malformed/empty payload leaves $tn = '' (not $null): the surface-routing at the
# end uses `$tn -eq ''` for Claude's empty-case exit-2 path, and $null -eq '' is False in PowerShell
# -- which would misroute a build failure to the Copilot exit-0 branch. Keeping it '' preserves the
# intended Claude empty-payload branch.
$tn = ''

if (-not [string]::IsNullOrEmpty($inputJson)) {
    try {
        $obj = $inputJson | ConvertFrom-Json
        $tn = if ($obj.tool_name) { [string]$obj.tool_name } elseif ($obj.toolName) { [string]$obj.toolName } else { '' }

        # Claude Code: tool_input.file_path
        if ($obj.tool_input) {
            if ($obj.tool_input.file_path) { $filePath = [string]$obj.tool_input.file_path }
            elseif ($obj.tool_input.filePath) { $filePath = [string]$obj.tool_input.filePath }
        }
        # Copilot: toolArgs is a parsed object (per spec), not a JSON string. Try object access first,
        # fall back to string parse for older payload shapes.
        $ta = $obj.toolArgs
        if ($ta -is [string]) { try { $ta = $ta | ConvertFrom-Json } catch { $ta = $null } }
        if ([string]::IsNullOrEmpty($filePath) -and $ta) {
            if ($ta.filePath) { $filePath = [string]$ta.filePath }
            elseif ($ta.file_path) { $filePath = [string]$ta.file_path }
            elseif ($ta.path) { $filePath = [string]$ta.path }
        }

        # Self-filter -- Copilot's hooks.json has no matcher, so gate here. Mirror guard.*: accept
        # known write tools (Claude Write/Edit, Copilot CLI edit/create) OR any tool carrying a file
        # path + content. The path+content arm covers VS Code agent mode's camelCase write tools
        # (str_replace/insert/create), which can't be enumerated; requiring content (not just a path)
        # keeps read-style tools from triggering a build.
        $contentParts = @($obj.tool_input.content, $obj.tool_input.new_string, $obj.tool_input.newString,
                          $obj.tool_input.file_text, $obj.tool_input.new_str, $obj.tool_input.text,
                          $ta.content, $ta.new_string, $ta.newString, $ta.file_text, $ta.new_str, $ta.text) |
                         Where-Object { $_ }
        $knownWrite = (@('Write','Edit','edit','create') -contains $tn) -or ($tn -eq '')
        if (-not ($knownWrite -or ($filePath -and $contentParts))) { exit 0 }
    } catch { }
}

if ([string]::IsNullOrEmpty($filePath) -and $env:CLAUDE_FILE_PATH) {
    $filePath = $env:CLAUDE_FILE_PATH
}

if ([string]::IsNullOrEmpty($filePath)) { exit 0 }
# Trigger on what `dotnet build` actually consumes: sources plus MSBuild/Razor inputs.
# A broken .csproj/.sln/.props/.targets edit breaks the build as surely as a .cs edit; extensions
# the build doesn't read stay excluded -- a build cannot catch their breakage.
if ($filePath -notmatch '\.(cs|csproj|sln|props|targets|razor|cshtml)$') { exit 0 }

# Bail cleanly if no dotnet CLI on PATH.
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { exit 0 }

# Discover the build target: walk up from the written file to the nearest solution that actually
# references a C# project, so an SSDT-only .sln is not mistaken for a .NET application. Build that
# whole solution for cross-project breaks; fall back to the nearest .csproj. The old root-cwd
# `dotnet build` silently built nothing when the solution lived in a subdirectory.
$fileDir = Split-Path -Parent $filePath
if ([string]::IsNullOrEmpty($fileDir)) { $fileDir = '.' }
try { $dir = (Resolve-Path -LiteralPath $fileDir -ErrorAction Stop).Path } catch { exit 0 }

$target = $null
$probe = $dir
while ($probe) {
    $sln = $null
    foreach ($candidate in @(Get-ChildItem -LiteralPath $probe -Filter *.sln -File -ErrorAction SilentlyContinue)) {
        try { $solutionText = Get-Content -LiteralPath $candidate.FullName -Raw -ErrorAction Stop } catch { continue }
        if ($solutionText -match '(?i)\.csproj') { $sln = $candidate; break }
    }
    if ($sln) { $target = $sln.FullName; break }
    $parent = Split-Path -Parent $probe
    if ($parent -eq $probe) { break }
    $probe = $parent
}
if (-not $target) {
    $probe = $dir
    while ($probe) {
        $proj = Get-ChildItem -LiteralPath $probe -Filter *.csproj -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($proj) { $target = $proj.FullName; break }
        $parent = Split-Path -Parent $probe
        if ($parent -eq $probe) { break }
        $probe = $parent
    }
}
if (-not $target) { exit 0 }

# Throttle: skip if a build was started within the last 60 seconds.
$stamp = '.claude\.state\last-build-ts'
# UTC integer epoch. NOT Get-Date -UFormat %s: under Windows PowerShell 5.1 that returns a
# fractional local-time string, and [double]::Parse is culture-sensitive -- in comma-decimal
# locales (de-DE/el-GR/fr-FR) the dot is a group separator, so the value overflows Int32 and
# throws on every write. This form is culture-free, integer, and UTC.
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
if (Test-Path $stamp) {
    $lastRaw = Get-Content $stamp -Raw
    if ($lastRaw) {
        $last = 0
        if ([int]::TryParse($lastRaw.Trim(), [ref]$last) -and ($now - $last) -lt 60) {
            exit 0
        }
    }
}
Set-Content -Path $stamp -Value $now -Encoding ASCII

# Only surface output on failure — emitting the build summary every successful write wastes context tokens.
$run = Invoke-BoundedTool 'dotnet' @('build', $target, '--no-restore', '--verbosity', 'quiet') (Get-Location).Path
if ($null -eq $run) {
    # Not verified (budget exceeded or no launch): back off for 300 s so a build that cannot finish
    # inside the budget does not cost the agent another full budget on the next write.
    Set-Content -Path $stamp -Value ($now + 300 - 60) -Encoding ASCII
    exit 0
}
if ($run.Code -eq 0) { exit 0 }

# Clear the throttle stamp so the next write rebuilds instead of skipping a known-broken build.
Remove-Item $stamp -Force

$msg = "## dotnet build failed -- fix before continuing:`n" + ($run.Lines -join "`n")

# Surface per surface, discriminating by tool-name casing (mirror guard.ps1). Claude Code is the
# only surface consuming exit 2 + stderr; its tools are PascalCase Edit/Write -- and the ambiguous
# empty case routes here too, since its PostToolUse matcher only fires on Write|Edit.
# -ceq is required: case-insensitive -eq would route Copilot's lowercase 'edit' here by mistake.
if ($tn -ceq 'Edit' -or $tn -ceq 'Write' -or $tn -eq '') {
    [Console]::Error.WriteLine($msg)
    exit 2
}

# Everything else -- Copilot CLI (lowercase edit/create) AND VS Code agent mode (camelCase
# str_replace/insert/etc.) -- is sent the JSON additionalContext shape below, but a live sentinel
# canary (Copilot CLI 1.0.68, 2026-07-04) found the CLI model does NOT consume postToolUse stdout;
# this branch is emit-for-forward-compat only (see docs/enforcement-surfaces.md). VS Code unverified.
(@{ additionalContext = $msg } | ConvertTo-Json -Compress)
exit 0
