# PostToolUse hook -- incremental tsc --noEmit after a file write/edit on .ts files in src/.
# Tool surfaces handled:
#   Claude Code (CLI + VS Code extension)  -- tool_name in {Write,Edit}; path at tool_input.file_path
#   GitHub Copilot (cloud agent + CLI)     -- toolName  in {edit,create}; path at toolArgs.filePath
# Throttled to one type-check per 5 seconds to avoid burst-write duplication.

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
if ($filePath -notlike '*.ts') { exit 0 }

# Match the bash hook's scope: only files under src/.
$normalized = $filePath -replace '\\', '/'
if ($normalized -notmatch '/src/') { exit 0 }

# Bail out cleanly if the workspace isn't installed yet.
if (-not (Test-Path node_modules)) { exit 0 }

# Throttle: skip if a check was started within the last 5 seconds.
$stamp = '.claude\.state\last-build-ts'
$now = [int][double]::Parse((Get-Date -UFormat %s))
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
$out = npx --no-install tsc --noEmit --incremental --tsBuildInfoFile .claude\.state\tsbuildinfo 2>&1
if ($LASTEXITCODE -eq 0) { exit 0 }

# Clear the throttle stamp so the next write re-checks instead of skipping a known-broken type-check.
Remove-Item $stamp -Force

$msg = "## tsc --noEmit failed -- fix before continuing:`n" + (($out | Select-Object -Last 20 | ForEach-Object { "$_" }) -join "`n")

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
