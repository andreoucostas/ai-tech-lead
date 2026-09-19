# PostToolUse hook -- incremental tsc --noEmit after a write/edit on build-relevant files
# (.ts sources under src/ + tsconfig*.json anywhere).
# Tool surfaces handled:
#   Claude Code (CLI + VS Code extension)  -- tool_name in {Write,Edit}; path at tool_input.file_path
#   GitHub Copilot (cloud agent + CLI)     -- toolName  in {edit,create}; path at toolArgs.filePath
# Throttled to one type-check per 5 seconds to avoid burst-write duplication.

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
        # keeps read-style tools from triggering a type-check.
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
# Trigger on what `tsc --noEmit` can actually validate: .ts sources under src/, plus any
# tsconfig*.json (it drives the type-check and typically lives OUTSIDE src/, so it bypasses the
# src/ gate). Deliberately NOT angular.json/package.json: tsc cannot validate those -- a trigger
# there would run a check that cannot catch the breakage.
$normalized = $filePath -replace '\\', '/'
if ($normalized -notmatch '(^|/)tsconfig[^/]*\.json$') {
    if ($filePath -notlike '*.ts') { exit 0 }
    # Limit the hook's scope to .ts files under src/.
    if ($normalized -notmatch '/src/') { exit 0 }
}

# Discover the workspace root: walk up from the written file to the nearest ancestor holding
# an Angular tsconfig. Supports root, ClientApp/, and Nx apps/* layouts -- the old root-cwd
# assumption silently skipped the type-check for anything but a workspace at the repo root.
$fileDir = Split-Path -Parent $filePath
if ([string]::IsNullOrEmpty($fileDir)) { $fileDir = '.' }
try { $dir = (Resolve-Path -LiteralPath $fileDir -ErrorAction Stop).Path } catch { exit 0 }

$workspace = $null
$probe = $dir
while ($probe) {
    if ((Test-Path (Join-Path $probe 'tsconfig.app.json')) -or (Test-Path (Join-Path $probe 'tsconfig.json'))) {
        $workspace = $probe; break
    }
    $parent = Split-Path -Parent $probe
    if ($parent -eq $probe) { break }
    $probe = $parent
}
if (-not $workspace) { exit 0 }

# Prefer tsconfig.app.json: an Nx/CLI app's tsconfig.json is solution-style (files:[], include:[],
# references), and `tsc -p` against it compiles nothing and exits 0 -- a silent false pass.
# tsconfig.app.json carries the real files/include, so the type-check actually runs.
$project = if (Test-Path (Join-Path $workspace 'tsconfig.app.json')) { 'tsconfig.app.json' } else { 'tsconfig.json' }

# Resolve tsc: node_modules may sit in the workspace or be hoisted to a monorepo root above it.
$hasModules = $false
$mp = $workspace
while ($mp) {
    if (Test-Path (Join-Path $mp 'node_modules')) { $hasModules = $true; break }
    $parent = Split-Path -Parent $mp
    if ($parent -eq $mp) { break }
    $mp = $parent
}
if (-not $hasModules) { exit 0 }

# Per-workspace state (absolute, under the repo-root .state) so multiple apps in a monorepo
# neither clobber each other's incremental tsbuildinfo nor cross-suppress each other's throttle.
$repoState = Join-Path (Get-Location).Path '.claude\.state'
$null = New-Item -ItemType Directory -Path $repoState -Force
$wsRel = try { [string](Resolve-Path -LiteralPath $workspace -Relative -ErrorAction Stop) } catch { $workspace }
$key = ($wsRel -replace '[^A-Za-z0-9]', '_') -replace '_+$', ''
if ([string]::IsNullOrEmpty($key)) { $key = 'root' }
$stamp = Join-Path $repoState "last-build-$key"
$buildInfo = Join-Path $repoState "tsbuildinfo-$key"

# Throttle: skip if a check was started within the last 5 seconds.
# UTC integer epoch. NOT Get-Date -UFormat %s: under Windows PowerShell 5.1 that returns a
# fractional local-time string, and [double]::Parse is culture-sensitive -- in comma-decimal
# locales (de-DE/el-GR/fr-FR) the dot is a group separator, so the value overflows Int32 and
# throws on every write. This form is culture-free, integer, and UTC.
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
if (Test-Path $stamp) {
    $lastRaw = Get-Content $stamp -Raw
    if ($lastRaw) {
        $last = 0
        if ([int]::TryParse($lastRaw.Trim(), [ref]$last) -and ($now - $last) -lt 5) {
            exit 0
        }
    }
}
Set-Content -Path $stamp -Value $now -Encoding ASCII

# Only surface output on failure — emitting type-check output every successful write wastes context tokens.
# Run from the workspace dir (npx resolves tsc by walking up to the monorepo node_modules);
# the tsBuildInfoFile is an absolute repo-root path so it is unaffected by the working directory.
$run = Invoke-BoundedTool 'npx' @('--no-install', 'tsc', '--noEmit', '-p', $project, '--incremental', '--tsBuildInfoFile', $buildInfo) $workspace
if ($null -eq $run) {
    # Not verified (budget exceeded or no launch): back off for 300 s so a type-check that cannot
    # finish inside the budget does not cost the agent another full budget on the next write.
    Set-Content -Path $stamp -Value ($now + 300 - 5) -Encoding ASCII
    exit 0
}
if ($run.Code -eq 0) { exit 0 }

# Clear the throttle stamp so the next write re-checks instead of skipping a known-broken type-check.
Remove-Item $stamp -Force

$msg = "## tsc --noEmit failed -- fix before continuing:`n" + ($run.Lines -join "`n")

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
