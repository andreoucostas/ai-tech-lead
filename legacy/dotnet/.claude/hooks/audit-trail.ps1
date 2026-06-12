# PostToolUse hook -- append every AI-assisted file write to .claude\ai-audit.log.
# Format: ISO-8601-UTC TAB git-branch TAB file-path
# Tool surfaces handled:
#   Claude Code (CLI + VS Code extension)  -- tool_name in {Write,Edit}; path at tool_input.file_path
#   GitHub Copilot (cloud agent + CLI)     -- toolName  in {edit,create}; path at toolArgs.filePath

$ErrorActionPreference = 'SilentlyContinue'

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
        # Copilot: toolArgs is a parsed object (per spec). Try object access first, fall back to
        # string parse for older payload shapes.
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
if ($filePath -match 'ai-audit\.log|[\\/]obj[\\/]|[\\/]bin[\\/]') { exit 0 }

$branch = git rev-parse --abbrev-ref HEAD 2>$null
if (-not $branch) { $branch = 'unknown' }

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

"$timestamp`t$branch`t$filePath" | Out-File -FilePath '.claude\ai-audit.log' -Append -Encoding utf8

exit 0
