# PostToolUse hook -- incremental dotnet build after a file write/edit on .cs files.
# Tool surfaces handled:
#   Claude Code (CLI + VS Code extension)  -- tool_name in {Write,Edit}; path at tool_input.file_path
#   GitHub Copilot (cloud agent + CLI)     -- toolName  in {edit,create}; path at toolArgs.filePath
# Throttled to one build per 60 seconds to avoid stomping on a long-running compile.

$ErrorActionPreference = 'SilentlyContinue'

$null = New-Item -ItemType Directory -Path .claude\.state -Force

$inputJson = [Console]::In.ReadToEnd()
$filePath = ''

if (-not [string]::IsNullOrEmpty($inputJson)) {
    try {
        $obj = $inputJson | ConvertFrom-Json
        $tn = if ($obj.tool_name) { [string]$obj.tool_name } elseif ($obj.toolName) { [string]$obj.toolName } else { '' }
        if ($tn -and $tn -notin @('Write','Edit','edit','create')) { exit 0 }

        # Claude Code: tool_input.file_path
        if ($obj.tool_input) {
            if ($obj.tool_input.file_path) { $filePath = [string]$obj.tool_input.file_path }
            elseif ($obj.tool_input.filePath) { $filePath = [string]$obj.tool_input.filePath }
        }
        # Copilot: toolArgs is a parsed object (per spec), not a JSON string. Try object access first,
        # fall back to string parse for older payload shapes.
        if ([string]::IsNullOrEmpty($filePath) -and $obj.toolArgs) {
            $ta = $obj.toolArgs
            if ($ta -is [string]) {
                try { $ta = $ta | ConvertFrom-Json } catch { $ta = $null }
            }
            if ($ta) {
                if ($ta.filePath) { $filePath = [string]$ta.filePath }
                elseif ($ta.file_path) { $filePath = [string]$ta.file_path }
                elseif ($ta.path) { $filePath = [string]$ta.path }
            }
        }
    } catch { }
}

if ([string]::IsNullOrEmpty($filePath) -and $env:CLAUDE_FILE_PATH) {
    $filePath = $env:CLAUDE_FILE_PATH
}

if ([string]::IsNullOrEmpty($filePath)) { exit 0 }
if ($filePath -notlike '*.cs') { exit 0 }

# Bail cleanly if no dotnet CLI on PATH.
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { exit 0 }

# Discover the build target: walk up from the written file to the nearest .sln so the whole
# solution is built and cross-project breaks are caught; fall back to the nearest .csproj if no
# solution exists up the tree. The old root-cwd `dotnet build` silently built nothing when the
# solution lived in a subdirectory.
$fileDir = Split-Path -Parent $filePath
if ([string]::IsNullOrEmpty($fileDir)) { $fileDir = '.' }
try { $dir = (Resolve-Path -LiteralPath $fileDir -ErrorAction Stop).Path } catch { exit 0 }

$target = $null
$probe = $dir
while ($probe) {
    $sln = Get-ChildItem -LiteralPath $probe -Filter *.sln -File -ErrorAction SilentlyContinue | Select-Object -First 1
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
$now = [int][double]::Parse((Get-Date -UFormat %s))
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
$out = dotnet build $target --no-restore --verbosity quiet 2>&1
if ($LASTEXITCODE -eq 0) { exit 0 }

# Clear the throttle stamp so the next write rebuilds instead of skipping a known-broken build.
Remove-Item $stamp -Force

$msg = "## dotnet build failed -- fix before continuing:`n" + (($out | Select-Object -Last 20 | ForEach-Object { "$_" }) -join "`n")

# Copilot consumes postToolUse feedback as JSON additionalContext on stdout (exit 0).
# -ceq: Copilot's tool names are lowercase; case-insensitive -eq would swallow Claude's 'Edit'.
if ($tn -ceq 'edit' -or $tn -ceq 'create') {
    (@{ additionalContext = $msg } | ConvertTo-Json -Compress)
    exit 0
}

# Claude Code feeds PostToolUse output to the model only via exit 2 + stderr;
# exit-0 stdout goes to the debug log, so a plain echo here is silently dropped.
[Console]::Error.WriteLine($msg)
exit 2
