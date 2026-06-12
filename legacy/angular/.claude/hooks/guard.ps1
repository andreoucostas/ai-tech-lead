# PreToolUse guard — hard-block writes that introduce warning-suppressions or hardcoded secrets.
# Enforces CLAUDE.md > Verification Rule #7 and the no-secrets rule deterministically.
# Claude Code block = exit 2 + reason on stderr. Copilot block = JSON deny on stdout.
# Allow = exit 0. Degrades safe on parse failure (except high-confidence secrets, which fail closed).
$ErrorActionPreference = 'SilentlyContinue'

$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $d = $raw | ConvertFrom-Json } catch { exit 0 }

$tool = $d.tool_name; if (-not $tool) { $tool = $d.toolName }
$ti = $d.tool_input
$ta = $d.toolArgs
if ($ta -is [string]) { try { $ta = $ta | ConvertFrom-Json } catch { $ta = $null } }

$fp = $null
foreach ($v in @($ti.file_path, $ti.filePath, $ta.filePath, $ta.file_path, $ta.path)) { if ($v) { $fp = $v; break } }
$parts = @($ti.content, $ti.new_string, $ti.newString, $ta.content, $ta.new_string, $ta.newString, $ti.text, $ta.text) | Where-Object { $_ }
$content = ($parts -join "`n")

switch ($tool) { 'Write' {} 'Edit' {} 'edit' {} 'create' {} '' {} default { exit 0 } }
if (-not $content) { exit 0 }

$reasons = @()

if ($fp -match '\.cs$') {
    if ($content -match '#pragma\s+warning\s+disable') { $reasons += "adds '#pragma warning disable' — Verification Rule #7: failures are signals, fix the cause" }
}
if ($fp -match '\.(ts|tsx|js|jsx|mts|cts|mjs|cjs)$') {
    if ($content -match 'eslint-disable') { $reasons += "adds an 'eslint-disable' directive — fix the lint cause, don't silence it" }
    if ($content -match '@ts-(ignore|nocheck)') { $reasons += "adds '@ts-ignore'/'@ts-nocheck' — fix the type error, don't suppress it" }
}

$secret = $null
if     ($content -match '-----BEGIN [A-Z ]*PRIVATE KEY-----')   { $secret = 'a private key block' }
elseif ($content -match 'AKIA[0-9A-Z]{16}')                     { $secret = 'an AWS access key id (AKIA...)' }
elseif ($content -match 'ghp_[A-Za-z0-9]{36}')                  { $secret = 'a GitHub token (ghp_...)' }
elseif ($content -match 'xox[baprs]-[A-Za-z0-9-]{10,}')         { $secret = 'a Slack token (xox...)' }
elseif ($content -match 'sk-[A-Za-z0-9_-]{20,}')                { $secret = 'an API secret key (sk-...)' }
elseif ($content -match 'AIza[0-9A-Za-z_-]{35}')               { $secret = 'a Google API key (AIza...)' }
if ($secret) { $reasons += "contains $secret — secrets must not be committed; use user-secrets / env vars / a vault" }

if ($fp -notmatch '(?i)(test|spec|Development|example|sample|mock|fixture)') {
    $m = [regex]::Match($content, '(?i)(password|passwd|pwd|secret|api[_-]?key|access[_-]?key|client[_-]?secret|connectionstring)["'' ]*[:=]\s*["''][^"'']{8,}["'']')
    if ($m.Success -and $m.Value -notmatch '(?i)(changeme|placeholder|your[_-]|example|dummy|<[^>]+>|\$\{|process\.env|%[A-Z_]+%)') {
        $reasons += "assigns a hardcoded credential literal — move it to user-secrets / env vars / a vault"
    }
}

if ($reasons.Count -eq 0) { exit 0 }

$target = if ($fp) { $fp } else { 'the target file' }
$msg = "Blocked write to ${target}: it " + ($reasons -join '; ') + "."

# -ceq: Copilot's tool names are lowercase; case-insensitive -eq would route Claude's 'Edit'
# to the Copilot JSON-deny path (exit 0), which Claude Code does not honor as a block.
if ($tool -ceq 'edit' -or $tool -ceq 'create') {
    (@{ decision = 'deny'; reason = $msg } | ConvertTo-Json -Compress)
    exit 0
}

[Console]::Error.WriteLine($msg)
exit 2
