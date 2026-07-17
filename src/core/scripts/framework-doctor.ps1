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
function Finish {
    Write-Output ''
    Write-Output '[CANT-VERIFY] Claude hooks - start claude here; pass = hook output starts with "## AI Tech Lead - Session Context". No banner usually means folder trust is pending.'
    Write-Output '[CANT-VERIFY] Claude write guard - ask it to create tmp-doctor-canary.txt containing AKIA plus 16 uppercase letters/digits; pass = the hook says "Blocked write to". A polite refusal is not a pass; delete the file if it lands.'
    Write-Output '[CANT-VERIFY] Copilot VS Code hooks - use the same canary in agent mode; pass = permissionDecisionReason says "Blocked write to". No deny means Preview agent hooks are disabled by you or your GitHub organization administrator.'
    Write-Output '[CANT-VERIFY] Copilot CLI trust - use the same canary after opening and trusting this folder interactively; pass = permissionDecisionReason says "Blocked write to".'
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

$adoption = Test-Path -LiteralPath (Join-Path $root '.claude/adoption-pending.json')
$bootstrap = $false
$claudePath = Join-Path $root 'CLAUDE.md'
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
    if ($_ -match '^\s*([^\s]+)') { $matches[1] }
} | Select-Object -Unique)
if ($shells.Count -eq 0) {
    Row MISSING 'Wired hook shell' 'no hook interpreter could be read from .claude/settings.json. Fix: re-run the installer to rewire hooks.'
} else {
    $absent = @($shells | Where-Object { -not (Has $_) })
    if ($absent.Count) {
        $names = $absent -join ','
        Row MISSING 'Wired hook shell' ("committed hooks use {0}, which this machine does not have: no write guard, build feedback, or audit trail. Fix: install {0}, or re-run the installer to rewire hooks." -f $names)
    } else { Row OK 'Wired hook shell' ("available: {0}." -f ($shells -join ',')) }
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
if (Test-Path -LiteralPath $copilotPath) {
    try {
        $null = Get-Content -Raw -LiteralPath $copilotPath | ConvertFrom-Json
        $copilotValid = $true
        $rawCopilot = Get-Content -Raw -LiteralPath $copilotPath
        [regex]::Matches($rawCopilot, '"(?:bash|powershell)"\s*:\s*"([^" ]+)"') | ForEach-Object {
            $path = $_.Groups[1].Value -replace '\\\\','/'
            if ($path.StartsWith('./')) { $path = $path.Substring(2) }
            $hookPaths += $path
        }
    } catch { }
}
$hookPaths = @($hookPaths | Select-Object -Unique)
$missingHooks = @($hookPaths | Where-Object { -not (Test-Path -LiteralPath (Join-Path $root $_)) })
if ($hookPaths.Count -eq 0 -or $missingHooks.Count) {
    $names = if ($missingHooks.Count) { $missingHooks -join ',' } else { '<no registrations>' }
    Row MISSING 'Hook files' ("registration points at a missing file; hooks are silently dead. Fix: re-run the installer. Missing: {0}" -f $names)
} else { Row OK 'Hook files' ("{0} registered files are present." -f $hookPaths.Count) }

$bashWired = @($shells | Where-Object { $_ -eq 'bash' }).Count -gt 0
if ($bashWired) {
    if ((Has jq) -or (Has python3)) { Row OK 'Guard JSON parser' 'jq or python3 is available.' }
    else { Row MISSING 'Guard JSON parser' 'the bash write guard is INACTIVE and allows writes with only a warning. Fix: install jq.' }
} else { Row OK 'Guard JSON parser' 'not required by the wired PowerShell hooks.' }

if ($pending) { Row PENDING 'Stack toolchain' 'not checked until /bootstrap or /adopt completes.' }
else {
    $missingTools = @()
    if ($template -match 'dotnet|monorepo') { if (-not (Has dotnet)) { $missingTools += 'dotnet' } }
    if ($template -match 'angular|monorepo') {
        if (-not (Has node)) { $missingTools += 'node' }
        if (-not (Has npx)) { $missingTools += 'npx' }
    }
    if ($missingTools.Count) {
        Row MISSING 'Stack toolchain' ("compile checks after writes cannot run; errors surface at CI instead. Fix: install {0}." -f ($missingTools -join ','))
    } else { Row OK 'Stack toolchain' ("required {0} toolchain commands are available." -f $template) }
}

if ($copilotValid) {
    if (Has copilot) { Row OK 'Copilot surface' 'hooks.json is valid and the Copilot CLI is present.' }
    else { Row OK 'Copilot surface' 'hooks.json is valid; Copilot CLI is absent (Claude-only teams need no action). If your team uses Copilot, the GA CLI is the cheapest real enforcement path.' }
} else { Row MISSING 'Copilot surface' '.github/hooks/hooks.json is missing or invalid. Fix: re-run the installer.' }

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
