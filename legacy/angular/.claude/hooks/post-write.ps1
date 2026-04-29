# PostToolUse hook -- incremental tsc --noEmit after Write/Edit on .ts files in src/.
# PowerShell equivalent of post-write.sh. Reads tool input JSON from stdin,
# extracts the file path, and runs tsc only when a .ts file under src/ was just
# written/edited. Throttled to one type-check per 5 seconds to avoid burst-write
# duplication.

$ErrorActionPreference = 'SilentlyContinue'

$null = New-Item -ItemType Directory -Path .claude\.state -Force

$inputJson = [Console]::In.ReadToEnd()
$filePath = ''

if (-not [string]::IsNullOrEmpty($inputJson)) {
    try {
        $obj = $inputJson | ConvertFrom-Json
        if ($obj.tool_input -and $obj.tool_input.file_path) {
            $filePath = [string]$obj.tool_input.file_path
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

$out = npx --no-install tsc --noEmit --incremental --tsBuildInfoFile .claude-tsbuildinfo 2>&1
if ($out) {
    $out | Select-Object -Last 20 | ForEach-Object { Write-Output $_ }
}

exit 0
