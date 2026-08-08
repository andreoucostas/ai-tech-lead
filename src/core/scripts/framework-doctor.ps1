# Developer-machine enforcement diagnostic. Windows PowerShell 5.1 compatible.
$ErrorActionPreference = 'SilentlyContinue'
$root = Split-Path -Parent $PSScriptRoot
$script:missing = 0
$script:missingRows = 0
$script:ok = 0

function Row($State, $Name, $Detail) {
    Write-Output ("[{0}] {1} - {2}" -f $State, $Name, $Detail)
    if ($State -eq 'OK') { $script:ok++ }
    if ($State -eq 'MISSING') { $script:missing = 1; $script:missingRows++ }
}
function Has($Name) { [bool](Get-Command $Name -ErrorAction SilentlyContinue) }
function Test-GuardShTarget($Command) {
    $normalized = [string]$Command -replace '\\\\','/' -replace '\\','/'
    return [bool]($normalized -match '(?i)^\s*(?:"(?:\./)?\.claude/hooks/guard\.sh"|''(?:\./)?\.claude/hooks/guard\.sh''|(?:\./)?\.claude/hooks/guard\.sh)(?=$|\s)')
}
function Test-ClaudeBashGuardCommand($Command) {
    $executable = $null; $remainder = $null
    if ($Command -match '^\s*"([^"]+)"\s*(.*)$') { $executable = $matches[1]; $remainder = $matches[2] }
    elseif ($Command -match "^\s*'([^']+)'\s*(.*)$") { $executable = $matches[1]; $remainder = $matches[2] }
    elseif ($Command -match '^\s*([^\s]+)\s*(.*)$') { $executable = $matches[1]; $remainder = $matches[2] }
    if (-not $executable) { return $false }
    $leaf = [IO.Path]::GetFileName(($executable -replace '\\','/'))
    if ($leaf -notmatch '(?i)^bash(?:\.exe)?$') { return $false }
    $remainder = $remainder -replace '^\s*(?:(?:--noprofile|--norc|-File|--)\s+)*',''
    return (Test-GuardShTarget $remainder)
}
function Finish {
    Write-Output ''
    Write-Output '[CANT-VERIFY] Claude hooks - start claude here and ask what the session preload contained; pass = the reply quotes a block that starts with "## Session preload". No preload usually means folder trust is pending.'
    Write-Output '[CANT-VERIFY] Claude write guard - ask it to create tmp-doctor-canary.txt containing AKIA plus 16 uppercase letters/digits; pass = the hook says "Blocked write to". A polite refusal is not a pass; delete the file if it lands.'
    Write-Output '[CANT-VERIFY] Copilot VS Code hooks - use the same canary in agent mode; pass = permissionDecisionReason says "Blocked write to". No deny means Preview agent hooks are disabled by you or your GitHub organization administrator.'
    Write-Output '[CANT-VERIFY] Copilot CLI trust - use the same canary after opening and trusting this folder interactively; pass = permissionDecisionReason says "Blocked write to".'
    Write-Output '[CANT-VERIFY] Agent-host stack toolchain - through the actual agent, make and then revert a harmless deliberate compile/type error in a real build-relevant file after the post-write throttle has elapsed; pass = the hook output starts with "## dotnet build failed" or "## tsc --noEmit failed". Model diagnosis or a direct terminal build is not a pass.'
    Write-Output ("Script-verifiable checks: {0} ok / {1} missing." -f $script:ok, $script:missingRows)
    Write-Output 'Enforcement is only FULL if the canaries above also pass; a script cannot see inside your agent.'
    exit $script:missing
}

Write-Output 'AI Tech Lead framework doctor'
Write-Output '============================'
$stampPath = Join-Path $root '.claude/framework-version.json'
if (-not (Test-Path -LiteralPath $stampPath)) {
    Row MISSING 'Install state' 'not a framework install. Fix: run the framework installer for this repository.'
    Finish
}
try { $stamp = Get-Content -Raw -LiteralPath $stampPath | ConvertFrom-Json } catch { $stamp = $null }
if (-not $stamp) {
    Row MISSING 'Install state' '.claude/framework-version.json is invalid JSON. Fix: re-run the framework installer.'
    Finish
}
$template = [string]$stamp.template
if (-not $template) { $template = 'unknown' }
Row OK 'Install state' ("template={0}; version={1}; applied={2}" -f $template, $stamp.version, $stamp.applied)

$claudePath = Join-Path $root 'CLAUDE.md'
$carrierPath = Join-Path $root '.github/instructions/framework-rules.instructions.md'
$importLine = '@.github/instructions/framework-rules.instructions.md'
$claudeContent = $null
if (Test-Path -LiteralPath $claudePath) {
    try { $claudeContent = Get-Content -Raw -LiteralPath $claudePath -ErrorAction Stop } catch { }
}
if ((Test-Path -LiteralPath $carrierPath) -and $claudeContent -and $claudeContent.Contains($importLine)) {
    Row OK 'Framework rules delivery' 'CLAUDE.md imports the current framework rules carrier.'
} elseif (Test-Path -LiteralPath $carrierPath) {
    Row MISSING 'Framework rules delivery' ('the carrier is installed but CLAUDE.md does not import it. Fix: add {0} where the Verification Rules, Leanness, SOLID, and Agentic Workflow sections belong.' -f $importLine)
} else {
    Row MISSING 'Framework rules delivery' 'the framework rules carrier is absent. Fix: re-run the framework installer.'
}

$claudeVersion = $null
if ($claudeContent -and $claudeContent -match '(?m)^\s*version:\s*([^\s]+)\s*$') { $claudeVersion = $matches[1] }
if ($claudeVersion -and ([string]$stamp.version -eq $claudeVersion)) {
    Row OK 'Protected-file sync' ("CLAUDE.md version {0} matches installed machinery." -f $claudeVersion)
} else {
    Row MISSING 'Protected-file sync' 'DIVERGED — protected file not synchronized with installed machinery; review required'
}

$adoption = Test-Path -LiteralPath (Join-Path $root '.claude/adoption-pending.json')
$bootstrap = $false
if (Test-Path -LiteralPath $claudePath) {
    $bootstrap = [bool](Select-String -Quiet -SimpleMatch 'BOOTSTRAP_PENDING' -LiteralPath $claudePath)
}
$pending = $adoption -or $bootstrap
if ($adoption) { Row PENDING 'Bootstrap/adoption state' 'adoption pending. A developer must run /adopt.' }
elseif ($bootstrap) { Row PENDING 'Bootstrap/adoption state' 'bootstrap pending. A developer must run /bootstrap.' }
else { Row OK 'Bootstrap/adoption state' 'repository setup is complete.' }

$commands = @()
$settingsPath = Join-Path $root '.claude/settings.json'
if (Test-Path -LiteralPath $settingsPath) {
    try {
        $settings = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json
        function Walk($Value) {
            if ($null -eq $Value -or $Value -is [string]) { return }
            if ($Value -is [System.Collections.IEnumerable]) { foreach ($v in $Value) { Walk $v }; return }
            foreach ($p in $Value.PSObject.Properties) {
                if ($p.Name -eq 'command' -and $p.Value -is [string]) { $script:commands += [string]$p.Value }
                else { Walk $p.Value }
            }
        }
        Walk $settings
    } catch { }
}
$shells = @($commands | ForEach-Object {
    if ($_ -match '^\s*"([^"]+)"') { $matches[1] }
    elseif ($_ -match '^\s*([^\s]+)') { $matches[1] }
} | Select-Object -Unique)
if ($shells.Count -eq 0) {
    Row MISSING 'Wired hook shell' 'no hook interpreter could be read from .claude/settings.json. Fix: re-run the installer to rewire hooks.'
} else {
    $missingShells = @()
    $bareShells = @()
    $existingShells = @()
    foreach ($shell in $shells) {
        if ($shell -match '^(?:[A-Za-z]:[\\/]|/)') {
            if (Test-Path -LiteralPath $shell -PathType Leaf) { $existingShells += $shell }
            else { $missingShells += $shell }
        } else { $bareShells += $shell }
    }
    if ($missingShells.Count) {
        Row MISSING 'Wired hook shell' ("the configured machine-specific interpreter path is absent on this machine: {0}. Fix: re-run the installer to restore portable bare-name wiring." -f ($missingShells -join ','))
    } elseif ($bareShells.Count) {
        Row CANT-VERIFY 'Wired hook shell' ("hooks use the portable bare interpreter name {0}; this doctor cannot observe the agent host's PATH. Use Hook liveness and the host canaries below." -f ($bareShells -join ','))
    } else { Row OK 'Wired hook shell' ("wired interpreter paths exist on this machine: {0}." -f ($existingShells -join ',')) }
}

$livenessPath = Join-Path $root '.claude/.state/last-session-start'
try { $lastSessionStart = Get-Content -Raw -LiteralPath $livenessPath -ErrorAction Stop } catch { $lastSessionStart = $null }
if ($null -ne $lastSessionStart) {
    Row OK 'Hook liveness' ("hooks have demonstrably run in this repo, most recently at '{0}'." -f $lastSessionStart.Trim())
} else {
    Row CANT-VERIFY 'Hook liveness' 'no hook has recorded a run here; if you have already started a Claude Code session in this repo, your hooks are not firing -- check the wired interpreter above, and see docs/enforcement-surfaces.md.'
}

$hookPaths = @()
foreach ($command in $commands) {
    if ($command -match '([^\s"'']*\.claude[\\/]hooks[\\/][^\s"'']+)') {
        $path = $matches[1] -replace '\\','/'
        if ($path.StartsWith('./')) { $path = $path.Substring(2) }
        $hookPaths += $path
    }
}
$copilotPath = Join-Path $root '.github/hooks/hooks.json'
$copilotValid = $false
$copilotExists = Test-Path -LiteralPath $copilotPath
$copilotBashCommands = @()
if ($copilotExists) {
    try { $rawCopilot = Get-Content -Raw -LiteralPath $copilotPath -ErrorAction Stop } catch { $rawCopilot = $null }
    if ($rawCopilot) {
        try { $null = $rawCopilot | ConvertFrom-Json; $copilotValid = $true } catch { }
        [regex]::Matches($rawCopilot, '"(?:bash|powershell)"\s*:\s*"([^" ]+)[^"]*"') | ForEach-Object {
            $path = $_.Groups[1].Value -replace '\\\\','/'
            if ($path.StartsWith('./')) { $path = $path.Substring(2) }
            $hookPaths += $path
        }
        [regex]::Matches($rawCopilot, '"bash"\s*:\s*"([^"]*)"') | ForEach-Object {
            $copilotBashCommands += $_.Groups[1].Value
        }
    }
}
$hookPaths = @($hookPaths | Select-Object -Unique)
$missingHooks = @($hookPaths | Where-Object { -not (Test-Path -LiteralPath (Join-Path $root $_)) })
if ($hookPaths.Count -eq 0 -or $missingHooks.Count) {
    $names = if ($missingHooks.Count) { $missingHooks -join ',' } else { '<no registrations>' }
    Row MISSING 'Hook files' ("registration points at a missing file; hooks are silently dead. Fix: re-run the installer. Missing: {0}" -f $names)
} else { Row OK 'Hook files' ("{0} registered files are present." -f $hookPaths.Count) }

$bashGuardRegistered = @($commands | Where-Object { Test-ClaudeBashGuardCommand $_ }).Count -gt 0
if (-not $bashGuardRegistered) { $bashGuardRegistered = @($copilotBashCommands | Where-Object { Test-GuardShTarget $_ }).Count -gt 0 }
# PARSER-VANTAGE-BRANCH-BEGIN
if ($bashGuardRegistered) {
    Row CANT-VERIFY 'Guard JSON parser' 'PowerShell cannot observe the runtime PATH supplied to guard.sh. Run framework-doctor.sh to inspect this Bash environment; only the write-guard canary below proves the actual agent host.'
} else { Row OK 'Guard JSON parser' 'not required by the registered PowerShell guards.' }
# PARSER-VANTAGE-BRANCH-END

if ($pending) { Row PENDING 'Stack toolchain' 'not checked until /bootstrap or /adopt completes.' }
else {
    $missingTools = @()
    if ($template -match 'dotnet|monorepo') { if (-not (Has dotnet)) { $missingTools += 'dotnet' } }
    if ($template -match 'angular|monorepo') {
        if (-not (Has node)) { $missingTools += 'node' }
        if (-not (Has npx)) { $missingTools += 'npx' }
    }
    if ($missingTools.Count) {
        Row MISSING 'Stack toolchain' ("the required toolchain commands are absent from this doctor process environment: {0}; this does not prove the agent host's post-write environment. Fix: install them on this machine if the actual-host canary also fails." -f ($missingTools -join ','))
    } else { Row OK 'Stack toolchain' ("required {0} toolchain commands are available in this doctor process environment; this does not prove the agent host's post-write environment." -f $template) }
}

# Twin divergence by design: the .sh twin adds a CANT-VERIFY branch here for "hooks.json exists
# but no JSON parser to validate it" — PowerShell parses JSON natively, so this twin cannot hit it.
if ($copilotValid) {
    if (Has copilot) { Row OK 'Copilot surface' 'hooks.json is valid and Copilot CLI is available in this doctor process environment.' }
    else { Row OK 'Copilot surface' 'hooks.json is valid; Copilot CLI is absent from this doctor process environment. Claude-only teams need no action; Copilot teams must use the actual-surface canaries below.' }
} elseif ($copilotExists) { Row MISSING 'Copilot surface' '.github/hooks/hooks.json exists but is not valid JSON. Fix: re-run the installer or correct the file.' }
else { Row MISSING 'Copilot surface' '.github/hooks/hooks.json is missing. Fix: re-run the installer.' }

if ($pending) { Row PENDING 'Mirror and version integrity' 'not checked until /bootstrap or /adopt completes.' }
else {
    $check = Join-Path $root 'scripts/template-checks.ps1'
    if (Test-Path -LiteralPath $check) {
        $hostExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
        & $hostExe -NoProfile -ExecutionPolicy Bypass -File $check *> $null
        if ($LASTEXITCODE -eq 0) { Row OK 'Mirror and version integrity' 'template-checks passed.' }
        else { Row MISSING 'Mirror and version integrity' 'CLAUDE.md and AGENTS.md or version stamps have drifted. Fix: run /generate-copilot, then scripts/docs-sync-check.ps1.' }
    } else { Row MISSING 'Mirror and version integrity' 'template-checks is missing. Fix: re-run the installer.' }
}

$audit = Join-Path $root '.claude/ai-audit.log'
if ($pending) { Row PENDING 'Audit trail substrate' 'not checked until /bootstrap or /adopt completes.' }
elseif (-not (Test-Path -LiteralPath $audit)) {
    Row MISSING 'Audit trail substrate' '.claude/ai-audit.log is missing, so regulated-environment changes are not being captured. Fix: create the file and ensure developers can append to it.'
} else {
    try {
        $stream = [IO.File]::Open($audit, 'Append', 'Write', 'ReadWrite'); $stream.Close()
        Row OK 'Audit trail substrate' 'audit log exists and is appendable.'
    } catch { Row MISSING 'Audit trail substrate' 'audit log is not appendable. Fix: grant the developer write access to .claude/ai-audit.log.' }
}
Finish
