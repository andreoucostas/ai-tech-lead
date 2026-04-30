# PostToolUse hook -- incremental dotnet build after Write/Edit on .cs files.
# PowerShell equivalent of post-write.sh. Reads tool input JSON from stdin,
# extracts the file path, and runs dotnet build only when a .cs file was just
# written/edited. Throttled to one build per 5 seconds to avoid burst-write
# duplication.

$ErrorActionPreference = 'SilentlyContinue'

$null = New-Item -ItemType Directory -Path .claude\.state -Force

$inputJson = [Console]::In.ReadToEnd()
$filePath = ''

if (-not [string]::IsNullOrEmpty($inputJson)) {
    try {
        $obj = $inputJson | ConvertFrom-Json
        # Tool name filter — Copilot has no matcher; Claude Code uses settings.json matcher.
        $tn = if ($obj.tool_name) { [string]$obj.tool_name } elseif ($obj.toolName) { [string]$obj.toolName } else { '' }
        if ($tn -and $tn -notin @('Write','Edit')) { exit 0 }
        # Claude Code: tool_input.file_path | VS Code Copilot: tool_input.filePath
        if ($obj.tool_input) {
            if ($obj.tool_input.file_path) { $filePath = [string]$obj.tool_input.file_path }
            elseif ($obj.tool_input.filePath) { $filePath = [string]$obj.tool_input.filePath }
        }
        # Copilot cloud/CLI: toolArgs is a JSON string containing filePath
        if ([string]::IsNullOrEmpty($filePath) -and $obj.toolArgs) {
            try {
                $ta = [string]$obj.toolArgs | ConvertFrom-Json
                if ($ta.filePath) { $filePath = [string]$ta.filePath }
                elseif ($ta.file_path) { $filePath = [string]$ta.file_path }
            } catch { }
        }
    } catch { }
}

if ([string]::IsNullOrEmpty($filePath) -and $env:CLAUDE_FILE_PATH) {
    $filePath = $env:CLAUDE_FILE_PATH
}

if ([string]::IsNullOrEmpty($filePath)) { exit 0 }
if ($filePath -notlike '*.cs') { exit 0 }

# Throttle: skip if a build was started within the last 5 seconds.
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

$out = dotnet build --no-restore --verbosity quiet 2>&1
if ($out) {
    $out | Select-Object -Last 20 | ForEach-Object { Write-Output $_ }
}

exit 0
