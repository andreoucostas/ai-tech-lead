# PostToolUse hook -- append every AI-assisted file write to .claude\ai-audit.log.
# Format: ISO-8601-UTC TAB git-branch TAB file-path
# PowerShell equivalent of audit-trail.sh.

$ErrorActionPreference = 'SilentlyContinue'

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
if ($filePath -match 'ai-audit\.log|\\obj\\|\\bin\\') { exit 0 }

$branch = git rev-parse --abbrev-ref HEAD 2>$null
if (-not $branch) { $branch = 'unknown' }

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

"$timestamp`t$branch`t$filePath" | Out-File -FilePath '.claude\ai-audit.log' -Append -Encoding utf8

exit 0
