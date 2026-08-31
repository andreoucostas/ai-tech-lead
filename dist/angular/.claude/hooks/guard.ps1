# PreToolUse guard — inspect writes for warning-suppressions, hardcoded secrets, or test-defeats and emit a block response.
# Implements deterministic checks for the framework rules (`.github/instructions/framework-rules.instructions.md` › Verification Rules; `AGENTS.md` › Verification Rules on AGENTS.md-native tools) #5/#7 and the no-secrets rule.
# Claude-shaped writes emit exit 2 plus a reason on stderr. Other write shapes emit a documented
# Copilot-compatible permissionDecision JSON deny on stdout (exit 0). Whether a client fires this
# hook or honors its output is capability-specific; see docs/enforcement-surfaces.md.
# Allow = exit 0. Degrades safe on parse failure (except high-confidence secrets, which fail closed).
$ErrorActionPreference = 'SilentlyContinue'

$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $d = $raw | ConvertFrom-Json } catch { exit 0 }

$tool = $d.tool_name; if (-not $tool) { $tool = $d.toolName }
$ti = $d.tool_input
$ta = $d.toolArgs
if ($ta -is [string]) { try { $ta = $ta | ConvertFrom-Json } catch { $ta = $null } }

# Field names vary by surface: Claude (file_path/content/new_string), Copilot CLI (filePath/
# newString), and VS Code agent mode's text-editor tools (path + file_text on `create`, new_str
# on `str_replace`/`insert`) -- Task 0 confirmed the VS Code shapes, so they are covered here.
$fp = $null
foreach ($v in @($ti.file_path, $ti.filePath, $ti.path, $ta.filePath, $ta.file_path, $ta.path)) { if ($v) { $fp = $v; break } }
$parts = @($ti.content, $ti.new_string, $ti.newString, $ti.file_text, $ti.new_str, $ti.text,
           $ta.content, $ta.new_string, $ta.newString, $ta.file_text, $ta.new_str, $ta.text) | Where-Object { $_ }
$content = ($parts -join "`n")

# Gate on whether this is an inspectable write, independent of surface: Claude sends
# Write/Edit (PascalCase), Copilot CLI sends edit/create (lowercase), VS Code agent mode
# sends camelCase tool names we can't fully enumerate -- so also accept any tool that
# carries a file path + content (the real signal). $fp/$content were extracted above.
$knownWrite = (@('Write','Edit','edit','create') -contains $tool) -or ($tool -eq '')
if (-not ($knownWrite -or ($fp -and $content))) { exit 0 }
if (-not $content) { exit 0 }

$reasons = @()

function Test-GuardPattern {
    param([string]$Pattern, [ValidateSet('secret','test-defeat/suppression')][string]$Category)
    try { return ($content -cmatch $Pattern) }
    catch {
        [Console]::Error.WriteLine("guard: regex error in $Category pattern '$Pattern'")
        if ($Category -eq 'secret') {
            $script:reasons += "cannot evaluate secret pattern '$Pattern' — blocking because the high-confidence secret floor is unavailable"
        }
        return $false
    }
}

if ($fp -cmatch '(?i)\.cs$') {
    if (Test-GuardPattern '#pragma\s+warning\s+disable' 'test-defeat/suppression') { $reasons += "adds '#pragma warning disable' — Verification Rule #7: failures are signals, fix the cause" }
    if (Test-GuardPattern '\[(Fact|Theory)\([^)]*Skip\s*=' 'test-defeat/suppression') { $reasons += "skips a test via [Fact/Theory(Skip=...)] — don't skip; fix the test or record it in TECH_DEBT.md (Verification Rule #5)" }
    if (Test-GuardPattern '(?m)^\s*\[([^]]*[,\s])?(Ignore)(Attribute)?\s*[\](,=]' 'test-defeat/suppression') { $reasons += "skips a test via [Ignore] — don't skip; fix the test or record it in TECH_DEBT.md (Verification Rule #5)" }
    if ((Test-GuardPattern 'Assert\.True\(\s*true\s*[),]' 'test-defeat/suppression') -or (Test-GuardPattern 'Assert\.False\(\s*false\s*[),]' 'test-defeat/suppression')) { $reasons += "adds a tautological assertion (Assert.True(true) / Assert.False(false)) — assert observable behaviour, not a constant (Test leanness #15)" }
}
if ($fp -cmatch '(?i)\.(ts|tsx|js|jsx|mts|cts|mjs|cjs)$') {
    if (Test-GuardPattern 'eslint-disable' 'test-defeat/suppression') { $reasons += "adds an 'eslint-disable' directive — fix the lint cause, don't silence it" }
    if (Test-GuardPattern '@ts-(ignore|nocheck)' 'test-defeat/suppression') { $reasons += "adds '@ts-ignore'/'@ts-nocheck' — fix the type error, don't suppress it" }
}
if ($fp -cmatch '(?i)\.spec\.(ts|tsx|js|jsx|mts|cts)$') {
    if ((Test-GuardPattern '(?m)^\s*f(it|describe)\s*\(' 'test-defeat/suppression') -or (Test-GuardPattern '\b(it|describe)\.only\s*\(' 'test-defeat/suppression')) { $reasons += "adds a focused test (fit/fdescribe/.only) — it silently skips the rest of the suite; remove it before committing" }
    if ((Test-GuardPattern '(?m)^\s*x(it|describe)\s*\(' 'test-defeat/suppression') -or (Test-GuardPattern '\b(it|describe)\.skip\s*\(' 'test-defeat/suppression')) { $reasons += "skips a test (xit/xdescribe/.skip) — don't skip; fix the test or record it in TECH_DEBT.md (Verification Rule #5)" }
    if ((Test-GuardPattern 'expect\(\s*true\s*\)\.toBe\(\s*true\s*\)' 'test-defeat/suppression') -or (Test-GuardPattern 'expect\(\s*false\s*\)\.toBe\(\s*false\s*\)' 'test-defeat/suppression')) { $reasons += "adds a tautological assertion (expect(true).toBe(true)) — assert observable behaviour, not a constant (Test leanness #15)" }
}

$secret = $null
if     (Test-GuardPattern '-----BEGIN [A-Z ]*PRIVATE KEY-----' 'secret')   { $secret = 'a private key block' }
elseif (Test-GuardPattern 'AKIA[0-9A-Z]{16}' 'secret')                     { $secret = 'an AWS access key id (AKIA…)' }
elseif (Test-GuardPattern 'gh[oprsu]_[A-Za-z0-9]{36}' 'secret')            { $secret = 'a classic GitHub token (gh*_…)' }
elseif (Test-GuardPattern 'github_pat_[0-9A-Za-z]{22}_[0-9A-Za-z]{59,}' 'secret') { $secret = 'a fine-grained GitHub token (github_pat_…)' }
elseif (Test-GuardPattern 'xox[baprs]-[A-Za-z0-9-]{10,}' 'secret')         { $secret = 'a Slack token (xox…)' }
elseif (Test-GuardPattern 'sk-[A-Za-z0-9_-]{20,}' 'secret')                { $secret = 'an API secret key (sk-…)' }
elseif (Test-GuardPattern 'AIza[0-9A-Za-z_-]{35}' 'secret')               { $secret = 'a Google API key (AIza…)' }
if ($secret) { $reasons += "contains $secret — secrets must not be committed; use user-secrets / env vars / a vault" }

if ($fp -notmatch '(?i)(test|spec|Development|example|sample|mock|fixture)') {
    $m = [regex]::Match($content, '(?i)(password|passwd|pwd|secret|api[_-]?key|access[_-]?key|client[_-]?secret)["'' ]*[:=]\s*["''][^"'']{8,}["'']|connectionstring["'' ]*[:=]\s*["''][^"'']*(?:password|pwd)\s*=\s*[^;"'']{4,}[^"'']*["'']|connectionstring["'' ]*[:=]\s*["''][^"'']*://[^/\s:@]+:[^/\s@]+@[^"'']*["'']')
    if ($m.Success -and $m.Value -notmatch '(?i)(changeme|placeholder|your[_-]|example|dummy|<[^>]+>|\$\{|process\.env|%[A-Z_]+%)') {
        $reasons += "assigns a hardcoded credential literal — move it to user-secrets / env vars / a vault"
    }
}

if ($reasons.Count -eq 0) { exit 0 }

$target = if ($fp) { $fp } else { 'the target file' }
$msg = "Blocked write to ${target}: it " + ($reasons -join '; ') + "."

# Emit a block response by detected input shape. PascalCase Edit/Write (and the ambiguous empty
# tool) emit the Claude-shaped signal: reason on stderr plus exit 2. Other shapes emit a documented
# Copilot-compatible superset deny: top-level `permissionDecision` plus the same decision nested in
# `hookSpecificOutput`. These emitted shapes and registration do not prove that a client fired the
# hook or honored the denial; client behavior is capability-specific. See
# docs/enforcement-surfaces.md.
if ($tool -ceq 'Edit' -or $tool -ceq 'Write' -or $tool -eq '') {
    [Console]::Error.WriteLine($msg)
    exit 2
}

[ordered]@{
    permissionDecision       = 'deny'
    permissionDecisionReason = $msg
    hookSpecificOutput       = [ordered]@{ permissionDecision = 'deny'; permissionDecisionReason = $msg }
} | ConvertTo-Json -Compress -Depth 6
exit 0
