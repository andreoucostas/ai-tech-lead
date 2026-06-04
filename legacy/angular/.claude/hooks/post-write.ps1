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

$out = npx --no-install tsc --noEmit --incremental --tsBuildInfoFile .claude\.state\tsbuildinfo 2>&1
# Only surface output on failure — emitting type-check output every successful write wastes context tokens.
if ($LASTEXITCODE -ne 0) {
    Write-Output "## tsc --noEmit failed -- fix before continuing:"
    $out | Select-Object -Last 20 | ForEach-Object { Write-Output $_ }
}

exit 0
