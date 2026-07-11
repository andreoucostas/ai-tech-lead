# PostToolUse hook (Write|Edit) -- meta-invariant #4: every .ps1 must have a UTF-8 BOM so
# Windows PowerShell 5.1 parses it correctly. This invariant is binary and auto-fixable, so we
# DON'T warn -- we fix it: if a just-written .ps1 under this repo lacks a BOM, prepend one
# in place. Deterministic, zero friction, can't be ignored. Scoped to ai-tech-lead/ paths so it
# never rewrites unrelated files. Soft-fails on any error (never blocks the write).
#
# Stdin handling mirrors the sibling hooks: [Console]::In.ReadToEnd(), guard empty, try/catch JSON.
$ErrorActionPreference = 'SilentlyContinue'

$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $obj = $raw | ConvertFrom-Json } catch { exit 0 }

$filePath = ''
if ($obj.tool_input) {
    if     ($obj.tool_input.file_path) { $filePath = [string]$obj.tool_input.file_path }
    elseif ($obj.tool_input.filePath)  { $filePath = [string]$obj.tool_input.filePath }
}
if ([string]::IsNullOrEmpty($filePath)) { exit 0 }

# Only .ps1 files, only under this repo (the don't-ship boundary works the other way here:
# we only touch framework files, never the maintainer's own files elsewhere).
if ($filePath -notmatch '\.ps1$') { exit 0 }
if ($filePath -notmatch 'ai-tech-lead[\\/]') { exit 0 }
if (-not (Test-Path -LiteralPath $filePath)) { exit 0 }

try {
    $bytes = [System.IO.File]::ReadAllBytes($filePath)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        exit 0  # already has a BOM
    }
    # Re-read as UTF-8 (no-BOM UTF-8 decodes cleanly) and rewrite with a BOM, content unchanged.
    $text = [System.IO.File]::ReadAllText($filePath, (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText($filePath, $text, (New-Object System.Text.UTF8Encoding($true)))
} catch { exit 0 }
exit 0
