# Developer-machine enforcement diagnostic. Windows PowerShell 5.1 compatible.
$ErrorActionPreference = 'SilentlyContinue'
$root = Split-Path -Parent $PSScriptRoot
$script:missing = 0
$script:missingRows = 0
$script:ok = 0
$script:stackCanary = 'through the actual agent, make and then revert a harmless deliberate compile/type error in a real build-relevant file after the post-write throttle has elapsed; pass = the hook output starts with "## dotnet build failed" or "## tsc --noEmit failed". Model diagnosis or a direct terminal build is not a pass.'

function Row($State, $Name, $Detail) {
    Write-Output ("[{0}] {1} - {2}" -f $State, $Name, $Detail)
    if ($State -eq 'OK') { $script:ok++ }
    if ($State -eq 'MISSING') { $script:missing = 1; $script:missingRows++ }
}
function Has($Name) { [bool](Get-Command $Name -ErrorAction SilentlyContinue) }
# Keep every doctor JSON decision on the strict jq/Python grammar. ConvertFrom-Json alone accepts
# JavaScript extensions under PowerShell 5.1/7 (comments, single quotes, unquoted keys, trailing
# commas, NaN/Infinity, and leading-zero numbers).
function ConvertFrom-StrictJson([string]$Text) {
    $state = [pscustomobject]@{ Text = $Text; Index = 0; Length = $Text.Length }
    function Fail-StrictJson { throw 'invalid strict JSON' }
    function Skip-JsonWhitespace { while ($state.Index -lt $state.Length -and ([int]$state.Text[$state.Index] -in @(0x20,0x09,0x0A,0x0D))) { $state.Index++ } }
    function Read-JsonString { if($state.Index-ge$state.Length-or$state.Text[$state.Index]-ne'"'){Fail-StrictJson};$state.Index++;while($state.Index-lt$state.Length){$c=$state.Text[$state.Index];$state.Index++;if($c-eq'"'){return};if([int]$c-lt0x20){Fail-StrictJson};if($c-eq'\'){if($state.Index-ge$state.Length){Fail-StrictJson};$escape=$state.Text[$state.Index];$state.Index++;if('"\/bfnrt'.IndexOf($escape)-ge0){continue};if($escape-ne'u'-or$state.Index+4-gt$state.Length){Fail-StrictJson};for($h=0;$h-lt4;$h++){if(-not[Uri]::IsHexDigit($state.Text[$state.Index+$h])){Fail-StrictJson}};$state.Index+=4}};Fail-StrictJson }
    function Read-JsonNumber { if($state.Text[$state.Index]-eq'-'){$state.Index++;if($state.Index-ge$state.Length){Fail-StrictJson}};$code=[int]$state.Text[$state.Index];if($code-eq0x30){$state.Index++;if($state.Index-lt$state.Length-and[int]$state.Text[$state.Index]-ge0x30-and[int]$state.Text[$state.Index]-le0x39){Fail-StrictJson}}elseif($code-ge0x31-and$code-le0x39){do{$state.Index++}while($state.Index-lt$state.Length-and[int]$state.Text[$state.Index]-ge0x30-and[int]$state.Text[$state.Index]-le0x39)}else{Fail-StrictJson};if($state.Index-lt$state.Length-and$state.Text[$state.Index]-eq'.'){$state.Index++;$start=$state.Index;while($state.Index-lt$state.Length-and[int]$state.Text[$state.Index]-ge0x30-and[int]$state.Text[$state.Index]-le0x39){$state.Index++};if($state.Index-eq$start){Fail-StrictJson}};if($state.Index-lt$state.Length-and($state.Text[$state.Index]-eq'e'-or$state.Text[$state.Index]-eq'E')){$state.Index++;if($state.Index-lt$state.Length-and($state.Text[$state.Index]-eq'+'-or$state.Text[$state.Index]-eq'-')){$state.Index++};$start=$state.Index;while($state.Index-lt$state.Length-and[int]$state.Text[$state.Index]-ge0x30-and[int]$state.Text[$state.Index]-le0x39){$state.Index++};if($state.Index-eq$start){Fail-StrictJson}} }
    function Read-JsonArray { $state.Index++;Skip-JsonWhitespace;if($state.Index-lt$state.Length-and$state.Text[$state.Index]-eq']'){$state.Index++;return};while($true){Read-JsonValue;Skip-JsonWhitespace;if($state.Index-ge$state.Length){Fail-StrictJson};$c=$state.Text[$state.Index];$state.Index++;if($c-eq']'){return};if($c-ne','){Fail-StrictJson};Skip-JsonWhitespace} }
    function Read-JsonObject { $state.Index++;Skip-JsonWhitespace;if($state.Index-lt$state.Length-and$state.Text[$state.Index]-eq'}'){$state.Index++;return};while($true){Read-JsonString;Skip-JsonWhitespace;if($state.Index-ge$state.Length-or$state.Text[$state.Index]-ne':'){Fail-StrictJson};$state.Index++;Read-JsonValue;Skip-JsonWhitespace;if($state.Index-ge$state.Length){Fail-StrictJson};$c=$state.Text[$state.Index];$state.Index++;if($c-eq'}'){return};if($c-ne','){Fail-StrictJson};Skip-JsonWhitespace} }
    function Read-JsonValue { Skip-JsonWhitespace;if($state.Index-ge$state.Length){Fail-StrictJson};$c=$state.Text[$state.Index];if($c-eq'"'){Read-JsonString;return};if($c-eq'{'){Read-JsonObject;return};if($c-eq'['){Read-JsonArray;return};foreach($literal in @('true','false','null')){if($state.Index+$literal.Length-le$state.Length-and$state.Text.Substring($state.Index,$literal.Length)-ceq$literal){$state.Index+=$literal.Length;return}};if($c-eq'-'-or([int]$c-ge0x30-and[int]$c-le0x39)){Read-JsonNumber;return};Fail-StrictJson }
    Read-JsonValue;Skip-JsonWhitespace;if($state.Index-ne$state.Length){Fail-StrictJson};return($Text|ConvertFrom-Json -ErrorAction Stop)
}
function Test-PackageAngularCore($Root) {
    if (-not ($Root -is [System.Management.Automation.PSCustomObject])) { return $false }
    foreach ($sectionName in @('dependencies','devDependencies','peerDependencies','optionalDependencies')) {
        $section = $Root.PSObject.Properties | Where-Object { $_.Name -ceq $sectionName } | Select-Object -First 1
        if ($section -and $section.Value -is [System.Management.Automation.PSCustomObject] -and
            ($section.Value.PSObject.Properties.Name -ccontains '@angular/core')) { return $true }
    }
    return $false
}
function Test-ExactAngularPackageToken($Value) {
    return $Value -is [string] -and $Value -cmatch '^@(angular|nx/angular|angular-devkit|schematics/angular)(/[^\s]+|:[^\s]+)$'
}
function Get-ExactJsonPropertyValue($Object, [string]$Name) {
    if (-not ($Object -is [System.Management.Automation.PSCustomObject])) { return $null }
    $property = $Object.PSObject.Properties | Where-Object { $_.Name -ceq $Name } | Select-Object -First 1
    if ($property) { return $property.Value }
    return $null
}
function Test-NxAngularEvidence($Node) {
    if (-not ($Node -is [System.Management.Automation.PSCustomObject])) { return $false }
    $plugins = $Node.PSObject.Properties | Where-Object Name -ceq 'plugins' | Select-Object -First 1
    foreach ($plugin in @($plugins.Value)) { if ((Test-ExactAngularPackageToken $plugin) -or ($plugin -is [System.Management.Automation.PSCustomObject] -and (Test-ExactAngularPackageToken (Get-ExactJsonPropertyValue $plugin 'plugin')))) { return $true } }
    foreach ($mapName in @('generators','schematics')) { $map=$Node.PSObject.Properties|Where-Object Name -ceq $mapName|Select-Object -First 1;if($map.Value-is[System.Management.Automation.PSCustomObject]){foreach($candidate in $map.Value.PSObject.Properties.Name){if(Test-ExactAngularPackageToken $candidate){return $true}}} }
    foreach ($mapName in @('targets','architect','targetDefaults')) { $map=$Node.PSObject.Properties|Where-Object Name -ceq $mapName|Select-Object -First 1;if(-not($map.Value-is[System.Management.Automation.PSCustomObject])){continue};foreach($entry in $map.Value.PSObject.Properties){if($mapName-ceq'targetDefaults'-and(Test-ExactAngularPackageToken $entry.Name)){return $true};if($entry.Value-is[System.Management.Automation.PSCustomObject]){foreach($field in @('executor','generator','collection','plugin')){if(Test-ExactAngularPackageToken (Get-ExactJsonPropertyValue $entry.Value $field)){return $true}}}} }
    return $false
}
function Get-DoctorGitChildEntry([string]$Directory, [string]$Name) {
    try { return Get-Item -Force -LiteralPath (Join-Path $Directory $Name) -ErrorAction Stop }
    catch [Management.Automation.ItemNotFoundException] { return $null }
}
function Test-DoctorExternalRepositoryEvidence([string]$Path) {
    $current = [IO.DirectoryInfo]::new([IO.Path]::GetFullPath($Path)).Parent
    while ($null -ne $current) {
        if (Get-DoctorGitChildEntry $current.FullName '.git') { return $true }
        $current = $current.Parent
    }

    # A bare repository has no .git child. Keep the signature strict so an ordinary directory is
    # not classified as repository evidence merely because it contains one Git-like filename.
    $head = Get-DoctorGitChildEntry $Path 'HEAD'
    $objects = Get-DoctorGitChildEntry $Path 'objects'
    $refs = Get-DoctorGitChildEntry $Path 'refs'
    return ($null -ne $head -and -not $head.PSIsContainer -and
        $null -ne $objects -and $objects.PSIsContainer -and
        $null -ne $refs -and $refs.PSIsContainer)
}
function Get-DoctorReparseAncestor([string]$Path) {
    $current = $Path
    while ($true) {
        $entry = Get-Item -Force -LiteralPath $current -ErrorAction SilentlyContinue
        if ($entry -and (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { return $current }
        if ($current -eq $root) { return $null }
        $parent = Split-Path -Parent $current
        if (-not $parent -or $parent -eq $current -or -not $parent.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { return $null }
        $current = $parent
    }
}
function Get-DoctorSha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function New-LegacyHookDoctorResult([string]$State, [string]$Detail) {
    [pscustomobject]@{ State = $State; Detail = $Detail }
}
function Get-LegacyHookDoctorResult {
    $retiredHelpers = @('scripts/setup-git-hooks.ps1', 'scripts/setup-git-hooks.sh', '.claude/hooks/guard.sh')
    foreach ($name in @('GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR', 'GIT_INDEX_FILE')) {
        $value = [Environment]::GetEnvironmentVariable($name, 'Process')
        if ($null -ne $value -and $value.Length -gt 0) {
            return New-LegacyHookDoctorResult CANT-VERIFY "Git routing variable $name is set; routed hook state was not inspected."
        }
    }

    try { $gitEntry = Get-DoctorGitChildEntry $root '.git' }
    catch { return New-LegacyHookDoctorResult CANT-VERIFY 'the target .git entry could not be examined; no hook path was followed.' }
    if (-not $gitEntry) {
        try { $repositoryOutsideTarget = Test-DoctorExternalRepositoryEvidence $root }
        catch { return New-LegacyHookDoctorResult CANT-VERIFY 'repository evidence could not be examined; no hook path was followed.' }
        if ($repositoryOutsideTarget) {
            return New-LegacyHookDoctorResult CANT-VERIFY 'Git metadata is not a default .git directory contained by this target; nested, bare, or external hook state was not inspected.'
        }
        return New-LegacyHookDoctorResult OK 'not applicable: no default .git directory exists in this repository root.'
    }
    if (($gitEntry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or -not $gitEntry.PSIsContainer) {
        return New-LegacyHookDoctorResult CANT-VERIFY 'Git metadata is linked, external, or non-directory state; no hook path was followed.'
    }

    try { $huskyEntry = Get-DoctorGitChildEntry $root '.husky' }
    catch { return New-LegacyHookDoctorResult CANT-VERIFY 'the .husky routing surface could not be examined.' }
    if ($huskyEntry) {
        return New-LegacyHookDoctorResult CANT-VERIFY 'a consumer-owned .husky hook surface exists and was not traversed; inspect it manually for retired framework helper references.'
    }

    $gitCommands = @(Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($gitCommands.Count -eq 0) {
        return New-LegacyHookDoctorResult CANT-VERIFY 'Git is unavailable, so core.hooksPath cannot be checked; no hook path was followed.'
    }
    $global:LASTEXITCODE = $null
    try { $hooksPathOutput = @(& ([string]$gitCommands[0].Source) -C $root config --get core.hooksPath 2>$null); $hooksPathExit = $global:LASTEXITCODE }
    catch { $hooksPathExit = $null; $hooksPathOutput = @() }
    if ($null -eq $hooksPathExit -or $hooksPathExit -notin @(0, 1)) {
        return New-LegacyHookDoctorResult CANT-VERIFY 'core.hooksPath could not be examined; no custom hook path was followed.'
    }
    if ($hooksPathExit -eq 0) {
        return New-LegacyHookDoctorResult CANT-VERIFY ("core.hooksPath is configured as '{0}'; this consumer-owned path was not followed. Inspect it manually for retired framework helper references." -f (($hooksPathOutput -join "`n").Trim()))
    }

    $helperStates = @{}
    foreach ($relative in $retiredHelpers + @('.claude/hooks/guard.ps1')) {
        $path = Join-Path $root $relative
        if (Get-DoctorReparseAncestor $path) { $helperStates[$relative] = 'unverifiable'; continue }
        try { $entry = Get-Item -Force -LiteralPath $path -ErrorAction Stop }
        catch [Management.Automation.ItemNotFoundException] { $helperStates[$relative] = 'absent'; continue }
        catch { $helperStates[$relative] = 'unverifiable'; continue }
        if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $entry.PSIsContainer) { $helperStates[$relative] = 'unverifiable' }
        else { $helperStates[$relative] = 'present' }
    }
    $unverifiableHelpers = @($helperStates.Keys | Where-Object { $helperStates[$_] -eq 'unverifiable' } | Sort-Object)
    if ($unverifiableHelpers.Count) {
        return New-LegacyHookDoctorResult CANT-VERIFY ("retired hook helper state could not be examined safely: {0}." -f ($unverifiableHelpers -join ', '))
    }

    $hookPath = Join-Path $root '.git/hooks/pre-commit'
    if (Get-DoctorReparseAncestor $hookPath) {
        return New-LegacyHookDoctorResult CANT-VERIFY 'the default pre-commit path traverses a reparse/symlink and was not followed.'
    }
    try { $hookEntry = Get-Item -Force -LiteralPath $hookPath -ErrorAction Stop }
    catch [Management.Automation.ItemNotFoundException] { $hookEntry = $null }
    catch { return New-LegacyHookDoctorResult CANT-VERIFY 'the default pre-commit hook could not be examined.' }
    $residualHelpers = @($retiredHelpers | Where-Object { $helperStates[$_] -eq 'present' })
    if (-not $hookEntry) {
        if ($residualHelpers.Count) {
            return New-LegacyHookDoctorResult PENDING ("retired Git-hook helpers remain without a default hook reference: {0}. Confirm no custom hook depends on them, then remove them manually." -f ($residualHelpers -join ', '))
        }
        return New-LegacyHookDoctorResult OK 'no default pre-commit hook or retired Git-hook helper remains.'
    }
    if (($hookEntry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $hookEntry.PSIsContainer -or $hookEntry.Length -gt 1048576) {
        return New-LegacyHookDoctorResult CANT-VERIFY 'the default pre-commit hook is linked or is not a regular bounded text file; it was not read.'
    }
    try {
        $hookBytes = [IO.File]::ReadAllBytes($hookPath)
        $hookText = [Text.UTF8Encoding]::new($false, $true).GetString($hookBytes)
        $hookDigest = Get-DoctorSha256 $hookBytes
    } catch { return New-LegacyHookDoctorResult CANT-VERIFY 'the default pre-commit hook could not be read as UTF-8 text.' }

    $powerShellBody = $hookDigest -ceq 'd13676bfffea2c3199894f4a610b8931273e161ddbfcfcdc7628bf40e6ca9fb8'
    $bashBody = $hookDigest -ceq '25da45aa780126e4d2b0a2b1bdf759462bf3fd92be01e6414ed496253c817357'
    $powerShellReference = $hookText -match '(?i)(?:^|[\s"''\\/])(?:\./)?scripts[\\/]setup-git-hooks\.ps1(?=$|[\s"''`(){}\[\],;:])'
    $bashSetupReference = $hookText -match '(?i)(?:^|[\s"''\\/])(?:\./)?scripts[\\/]setup-git-hooks\.sh(?=$|[\s"''`(){}\[\],;:])'
    $bashGuardReference = $hookText -match '(?i)(?:^|[\s"''\\/])(?:\./)?\.claude[\\/]hooks[\\/]guard\.sh(?=$|[\s"''`(){}\[\],;:])'
    $needed = New-Object System.Collections.Generic.List[string]
    if ($powerShellBody -or $powerShellReference) {
        $needed.Add('scripts/setup-git-hooks.ps1'); $needed.Add('.claude/hooks/guard.ps1')
    }
    if ($bashBody -or $bashSetupReference -or $bashGuardReference) {
        $needed.Add('scripts/setup-git-hooks.sh'); $needed.Add('.claude/hooks/guard.sh')
    }
    $needed = @($needed | Sort-Object -Unique)
    if ($needed.Count -eq 0) {
        if ($residualHelpers.Count) {
            return New-LegacyHookDoctorResult PENDING ("an unrelated consumer-owned pre-commit hook is present, and retired helpers also remain: {0}. Confirm the hook does not call them, then remove the helpers manually." -f ($residualHelpers -join ', '))
        }
        return New-LegacyHookDoctorResult OK 'the consumer-owned default pre-commit hook has no retired framework helper reference.'
    }
    $missingNeeded = @($needed | Where-Object { $helperStates[$_] -ne 'present' })
    if ($missingNeeded.Count) {
        return New-LegacyHookDoctorResult MISSING ("the consumer-owned pre-commit hook references missing framework helpers, so commits may fail: {0}. Remove or replace the hook manually." -f ($missingNeeded -join ', '))
    }
    $flavour = if ($bashBody -or $bashSetupReference -or $bashGuardReference) { 'Bash/degraded and unmaintained' } else { 'PowerShell legacy' }
    return New-LegacyHookDoctorResult PENDING ("$flavour pre-commit hook and its dependency closure remain. The installer will not modify consumer-owned Git hooks; remove or replace it manually.")
}
function Get-RetiredFrameworkResidueResult {
    $retiredPaths = @(
        '.claude/hooks/audit-trail.sh',
        '.claude/hooks/boy-scout-check.sh',
        '.claude/hooks/guard.sh',
        '.claude/hooks/post-write.sh',
        '.claude/hooks/route-prompt.sh',
        '.claude/hooks/session-start.sh',
        'scripts/build-architecture-html.sh',
        'scripts/ci/bitbucket-pipelines.example.yml',
        'scripts/docs-sync-check.sh',
        'scripts/framework-doctor.sh',
        'scripts/hazard-check.sh',
        'scripts/metrics.sh',
        'scripts/setup-git-hooks.ps1',
        'scripts/setup-git-hooks.sh',
        'scripts/template-checks.sh',
        'scripts/test-weakening-scan.sh',
        'scripts/warehouse-map-check.sh',
        'scripts/wiki-check.sh'
    )
    $present = New-Object System.Collections.Generic.List[string]
    $unverifiable = New-Object System.Collections.Generic.List[string]
    foreach ($relative in $retiredPaths) {
        $candidate = Join-Path $root $relative
        if (Get-DoctorReparseAncestor $candidate) { $unverifiable.Add($relative); continue }
        try { $entry = Get-Item -Force -LiteralPath $candidate -ErrorAction Stop }
        catch [Management.Automation.ItemNotFoundException] { continue }
        catch { $unverifiable.Add($relative); continue }
        if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $entry.PSIsContainer) {
            $unverifiable.Add($relative)
            continue
        }
        try {
            $stream = [IO.File]::Open($candidate, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
            try { $null = $stream.ReadByte() } finally { $stream.Dispose() }
            $present.Add($relative)
        } catch { $unverifiable.Add($relative) }
    }
    if ($unverifiable.Count) {
        $detail = "retired path state could not be read safely: {0}." -f ((@($unverifiable) | Sort-Object) -join ', ')
        if ($present.Count) { $detail += " Verified residue also remains: {0}." -f ((@($present) | Sort-Object) -join ', ') }
        return New-LegacyHookDoctorResult CANT-VERIFY $detail
    }
    if ($present.Count) {
        return New-LegacyHookDoctorResult PENDING ("retired framework files remain: {0}. Do not execute them; review protected references and remove only confirmed consumer-owned residue manually." -f ((@($present) | Sort-Object) -join ', '))
    }
    return New-LegacyHookDoctorResult OK 'none of the 18 v0.83 retired framework paths remains.'
}
function Finish {
    Write-Output ''
    Write-Output '[CANT-VERIFY] Claude hooks - start claude here and ask what the session preload contained; pass = the reply quotes a block that starts with "## Session preload". No preload usually means folder trust is pending.'
    Write-Output '[CANT-VERIFY] Claude write guard - ask it to create tmp-doctor-canary.txt containing AKIA plus 16 uppercase letters/digits; pass = the hook says "Blocked write to". A polite refusal is not a pass; delete the file if it lands.'
    Write-Output '[CANT-VERIFY] Copilot VS Code hooks - use the same canary in agent mode; pass = permissionDecisionReason says "Blocked write to". A visible deny is positive only for that run. No deny is inconclusive: trust, launch, interpreter, event, payload, consumption, model compliance, or observation may have failed. Before assigning a cause, compare the treatment with a positive same-surface control, a no-hook negative, and an independent firing marker; see docs/enforcement-surfaces.md.'
    Write-Output '[CANT-VERIFY] Copilot CLI trust - use the same canary after opening and trusting this folder interactively; pass = permissionDecisionReason says "Blocked write to".'
    Write-Output ("[CANT-VERIFY] Agent-host stack toolchain - {0}" -f $script:stackCanary)
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
$stampReadFailed = $false
try { $stampContent = Get-Content -Raw -LiteralPath $stampPath -ErrorAction Stop } catch { $stampReadFailed = $true }
if ($stampReadFailed) {
    Row CANT-VERIFY 'Install state' '.claude/framework-version.json exists but could not be read; its install state is unknown. Fix read access and rerun the doctor.'
    Finish
}
try { $stamp = ConvertFrom-StrictJson $stampContent } catch { $stamp = $null }
if ($null -eq $stamp) {
    Row MISSING 'Install state' '.claude/framework-version.json is invalid JSON. Fix: re-run the framework installer.'
    Finish
}
if ($stampContent -notmatch '^\s*\{') {
    Row MISSING 'Install state' '.claude/framework-version.json is valid JSON but lacks the required non-empty string "template". Fix: re-run the framework installer.'
    Finish
}
$template = Get-ExactJsonPropertyValue $stamp 'template'
if (-not ($template -is [string]) -or [string]::IsNullOrWhiteSpace($template)) {
    Row MISSING 'Install state' '.claude/framework-version.json is valid JSON but lacks the required non-empty string "template". Fix: re-run the framework installer.'
    Finish
}
if ($template -cne 'dotnet' -and $template -cne 'angular' -and $template -cne 'monorepo') {
    Row MISSING 'Install state' ('.claude/framework-version.json names unsupported template "{0}"; expected dotnet, angular, or monorepo. Fix: re-run the framework installer.' -f $template)
    Finish
}
Row OK 'Install state' ("template={0}; version={1}; applied={2}" -f $template, (Get-ExactJsonPropertyValue $stamp 'version'), (Get-ExactJsonPropertyValue $stamp 'applied'))

$claudePath = Join-Path $root 'CLAUDE.md'
$carrierPath = Join-Path $root '.github/instructions/framework-rules.instructions.md'
$importLine = '@.github/instructions/framework-rules.instructions.md'
$claudeContent = $null
$claudeReadFailed = $false
if (Test-Path -LiteralPath $claudePath) {
    try { $claudeContent = Get-Content -Raw -LiteralPath $claudePath -ErrorAction Stop } catch { $claudeReadFailed = $true }
}
if ((Test-Path -LiteralPath $carrierPath) -and $claudeReadFailed) {
    Row CANT-VERIFY 'Framework rules delivery' 'PowerShell could not inspect CLAUDE.md; this is a host/resource problem, not evidence that the framework rules import is absent.'
} elseif ((Test-Path -LiteralPath $carrierPath) -and $claudeContent -and $claudeContent.Contains($importLine)) {
    Row OK 'Framework rules delivery' 'CLAUDE.md imports the current framework rules carrier.'
} elseif (Test-Path -LiteralPath $carrierPath) {
    Row MISSING 'Framework rules delivery' ('the carrier is installed but CLAUDE.md does not import it. Fix: add {0} where the Verification Rules, Leanness, SOLID, and Agentic Workflow sections belong.' -f $importLine)
} else {
    Row MISSING 'Framework rules delivery' 'the framework rules carrier is absent. Fix: re-run the framework installer.'
}

$frameworkHeadings = @('Verification Rules', 'Leanness', 'SOLID', 'Agentic Workflow')
if (-not (Test-Path -LiteralPath $claudePath -PathType Leaf)) {
    Row MISSING 'Protected-file sync' 'CLAUDE.md is absent; protected-file migration state cannot be inspected.'
} elseif ($claudeReadFailed) {
    Row CANT-VERIFY 'Protected-file sync' 'PowerShell could not inspect CLAUDE.md; this is a host/resource problem, so protected-file migration state cannot be verified.'
} elseif (-not ((Test-Path -LiteralPath $carrierPath -PathType Leaf) -and $claudeContent -and $claudeContent.Contains($importLine))) {
    # $claudeContent is null for an EMPTY or unreadable CLAUDE.md (Get-Content -Raw returns null, not '').
    # Without the null guard this row threw and vanished from the report entirely -- an inert
    # diagnostic reading as a clean run instead of reporting the protected sync as deferred.
    Row OK 'Protected-file sync' 'deferred to Framework rules delivery.'
} elseif ($frameworkHeadings.Count -ne 4) {
    Row MISSING 'Protected-file sync' 'framework heading inspection is incomplete; protected-file migration state cannot be verified.'
} else {
    $inlineHeadings = @($frameworkHeadings | Where-Object { $claudeContent -match ('(?m)^##\s+{0}\s*$' -f [regex]::Escape($_)) })
    if ($inlineHeadings.Count -eq 0) {
        Row OK 'Protected-file sync' 'migrated - the carrier is authoritative.'
    } else {
        Row PENDING 'Protected-file sync' ('migration incomplete - these sections duplicate the carrier and may conflict: {0}. Fix: delete them from CLAUDE.md.' -f ($inlineHeadings -join ', '))
    }
}

$adoption = Test-Path -LiteralPath (Join-Path $root '.claude/adoption-pending.json')
$bootstrap = $false
$bootstrapReadFailed = $false
if (Test-Path -LiteralPath $claudePath) {
    try { $bootstrap = [bool](Select-String -Quiet -SimpleMatch 'BOOTSTRAP_PENDING' -LiteralPath $claudePath -ErrorAction Stop) }
    catch { $bootstrapReadFailed = $true }
}
$pending = $adoption -or $bootstrap
if ($adoption) { Row PENDING 'Bootstrap/adoption state' 'adoption pending. A developer must run /adopt.' }
elseif ($bootstrapReadFailed) { Row CANT-VERIFY 'Bootstrap/adoption state' 'PowerShell could not inspect CLAUDE.md; this is a host/resource problem, not evidence that repository setup is complete.' }
elseif ($bootstrap) { Row PENDING 'Bootstrap/adoption state' 'bootstrap pending. A developer must run /bootstrap.' }
else { Row OK 'Bootstrap/adoption state' 'repository setup is complete.' }

$commands = @()
$settingsPath = Join-Path $root '.claude/settings.json'
$settingsExists = Test-Path -LiteralPath $settingsPath
$settingsReadFailed = $false
$settingsInvalid = $false
if ($settingsExists) {
    try {
        $rawSettings = Get-Content -Raw -LiteralPath $settingsPath -ErrorAction Stop
    } catch { $settingsReadFailed = $true }
    if (-not $settingsReadFailed) {
        try { $settings = ConvertFrom-StrictJson $rawSettings } catch { $settingsInvalid = $true }
    }
    if (-not $settingsReadFailed -and -not $settingsInvalid) {
        try {
        function Walk($Value) {
            if ($null -eq $Value -or $Value -is [string]) { return }
            if ($Value -is [System.Collections.IEnumerable]) { foreach ($v in $Value) { Walk $v }; return }
            foreach ($p in $Value.PSObject.Properties) {
                if ($p.Name -ceq 'command' -and $p.Value -is [string]) { $script:commands += [string]$p.Value }
                else { Walk $p.Value }
            }
        }
        Walk $settings
        } catch { $settingsInvalid = $true; $commands = @() }
    }
}
$shells = @($commands | ForEach-Object {
    if ($_ -match '^\s*"([^"]+)"') { $matches[1] }
    elseif ($_ -match '^\s*([^\s]+)') { $matches[1] }
} | Select-Object -Unique)
if ($settingsReadFailed) {
    Row CANT-VERIFY 'Wired hook shell' '.claude/settings.json exists but could not be read; the wired interpreter is unknown. Fix read access and rerun the doctor.'
} elseif ($shells.Count -eq 0) {
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
if (-not [string]::IsNullOrWhiteSpace($lastSessionStart)) {
    Row OK 'Hook liveness' ("hooks have demonstrably run in this repo, most recently at '{0}'." -f $lastSessionStart.Trim())
} else {
    Row CANT-VERIFY 'Hook liveness' 'no hook has recorded a run here; if you have already started a Claude Code session in this repo, your hooks are not firing -- check the wired interpreter above, and see docs/enforcement-surfaces.md.'
}

$legacyHookRetirement = Get-LegacyHookDoctorResult
Row $legacyHookRetirement.State 'Legacy Git-hook retirement' $legacyHookRetirement.Detail
$retiredFrameworkResidue = Get-RetiredFrameworkResidueResult
Row $retiredFrameworkResidue.State 'Retired framework residue' $retiredFrameworkResidue.Detail

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
$copilotInvalid = $false
$copilotExists = Test-Path -LiteralPath $copilotPath
$copilotReadFailed = $false
if ($copilotExists) {
    try { $rawCopilot = Get-Content -Raw -LiteralPath $copilotPath -ErrorAction Stop } catch { $rawCopilot = $null; $copilotReadFailed = $true }
    if (-not $copilotReadFailed -and $rawCopilot) {
        try { $null = ConvertFrom-StrictJson $rawCopilot; $copilotValid = $true } catch { }
    }
    if (-not $copilotReadFailed -and -not $copilotValid) { $copilotInvalid = $true }
    if ($copilotValid) {
        [regex]::Matches($rawCopilot, '"(?:bash|powershell)"\s*:\s*"([^"]*)"') | ForEach-Object {
            $registeredCommand = $_.Groups[1].Value -replace '\\\\','/'
            if ($registeredCommand -match '([^\s"'']*\.claude/hooks/[^\s"'']+)') {
                $path = $Matches[1]
                if ($path.StartsWith('./')) { $path = $path.Substring(2) }
                $hookPaths += $path
            }
        }
    }
}
$hookPaths = @($hookPaths | Select-Object -Unique)
$missingHooks = @($hookPaths | Where-Object { -not (Test-Path -LiteralPath (Join-Path $root $_)) })
if ($copilotInvalid) {
    Row MISSING 'Hook files' '.github/hooks/hooks.json is malformed, so its apparent registrations are not active. Fix: re-run the installer or correct the file.'
} elseif ($missingHooks.Count) {
    $names = if ($missingHooks.Count) { $missingHooks -join ',' } else { '<no registrations>' }
    Row MISSING 'Hook files' ("registration points at a missing file; hooks are silently dead. Fix: re-run the installer. Missing: {0}" -f $names)
} elseif ($settingsReadFailed -or $copilotReadFailed) {
    Row CANT-VERIFY 'Hook files' 'hook registrations could not be completely read from .claude/settings.json and .github/hooks/hooks.json; file presence cannot be certified. Fix read access and rerun the doctor.'
} elseif ($hookPaths.Count -eq 0) {
    Row MISSING 'Hook files' 'registration points at a missing file; hooks are silently dead. Fix: re-run the installer. Missing: <no registrations>'
} else { Row OK 'Hook files' ("{0} registered files are present." -f $hookPaths.Count) }

$retiredBashRegistration = @($commands | Where-Object {
    $_ -match '(?i)(?:^|[\s"''])bash(?:\.exe)?(?=$|[\s"''])|\.sh(?=$|[\s"''])'
}).Count -gt 0
if (-not $retiredBashRegistration -and $copilotValid) {
    $retiredBashRegistration = $rawCopilot -match '(?i)"bash"\s*:|\.sh(?:\s|"|$)'
}
if ($copilotInvalid) {
    Row MISSING 'Hook registration topology' '.github/hooks/hooks.json is malformed, so the supported PowerShell registration set cannot be verified. Fix: re-run the installer or correct the file.'
} elseif ($settingsReadFailed -or $copilotReadFailed) {
    Row CANT-VERIFY 'Hook registration topology' 'hook registrations could not be completely read, so PowerShell-only registration cannot be verified. Fix read access and rerun the doctor.'
} elseif ($retiredBashRegistration) {
    Row MISSING 'Hook registration topology' 'a retired Bash hook registration remains. Preserve consumer-owned configuration, replace the obsolete entry with the supported PowerShell registration, and rerun the doctor.'
} else { Row OK 'Hook registration topology' 'registered framework hooks use the supported PowerShell surface.' }

if ($pending) { Row PENDING 'Stack toolchain' 'not checked until /bootstrap or /adopt completes.' }
else {
    $missingTools = @()
    # Application manifests live at the root or within two project-container levels in the
    # supported layouts. Keep this bounded and do not mistake generated/dependency artifacts for
    # source applications; an incomplete walk is not evidence that no application exists.
    $markerScanDepth = 2
    $markerExcludedDirectories = @('.git', 'node_modules', 'bower_components', 'vendor', 'bin', 'obj', 'dist', 'build', 'out', '.next', '.angular', '.nx', 'coverage')
    $markerNames = @('angular.json', 'nx.json', 'project.json', 'package.json')
    $markerScanFailed = $false
    $applicationMarkers = @()
    $markerDirectories = @([IO.DirectoryInfo]$root)
    for ($depth = 0; $depth -le $markerScanDepth; $depth++) {
        $nextMarkerDirectories = @()
        foreach ($markerDirectory in $markerDirectories) {
            try { $entries = @(Get-ChildItem -LiteralPath $markerDirectory.FullName -Force -ErrorAction Stop) }
            catch { $markerScanFailed = $true; continue }
            foreach ($entry in $entries) {
                # A solution alone can contain only SSDT/sqlproj projects. Require an actual C#
                # project before treating this repository as a .NET application.
                $isMarker = $entry.Extension -eq '.csproj' -or $entry.Name -in $markerNames
                $isReparsePoint = ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
                if ($isReparsePoint) {
                    if (($entry.PSIsContainer -and $markerExcludedDirectories -notcontains $entry.Name) -or $isMarker) { $markerScanFailed = $true }
                    continue
                }
                if ($entry.PSIsContainer) {
                    if ($isMarker) { $markerScanFailed = $true }
                    elseif ($depth -lt $markerScanDepth -and $markerExcludedDirectories -notcontains $entry.Name) { $nextMarkerDirectories += $entry }
                } elseif ($isMarker) { $applicationMarkers += $entry }
            }
        }
        $markerDirectories = $nextMarkerDirectories
    }
    $needsDotnet = @($applicationMarkers | Where-Object { $_.Extension -eq '.csproj' }).Count -gt 0
    $needsAngular = $false
    foreach ($marker in $applicationMarkers) {
        if ($marker.Name -notin $markerNames) { continue }
        try { $content = Get-Content -LiteralPath $marker.FullName -Raw -ErrorAction Stop }
        catch { $markerScanFailed = $true; continue }
        try {
            if ($content -notmatch '^\s*\{') { throw 'marker root is not an object' }
            $markerJson = ConvertFrom-StrictJson $content
        } catch { $markerScanFailed = $true; continue }
        if (($marker.Name -eq 'angular.json') -or
            ($marker.Name -eq 'package.json' -and (Test-PackageAngularCore $markerJson)) -or
            ($marker.Name -in @('nx.json', 'project.json') -and (Test-NxAngularEvidence $markerJson))) {
            $needsAngular = $true
        }
    }
    if ($needsDotnet) { if (-not (Has dotnet)) { $missingTools += 'dotnet' } }
    if ($needsAngular) {
        if (-not (Has node)) { $missingTools += 'node' }
        if (-not (Has npx)) { $missingTools += 'npx' }
    }
    if ($markerScanFailed) {
        Row CANT-VERIFY 'Stack toolchain' 'repository application markers could not be completely enumerated or read within two directory levels; generated/dependency directories (.git, node_modules, bower_components, vendor, bin, obj, dist, build, out, .next, .angular, .nx, coverage) are intentionally excluded. No toolchain conclusion was inferred. Fix: restore read/list access and rerun framework doctor.'
        $script:stackCanary = 'repository application markers could not be completely enumerated or read, so whether a compile/type-error canary applies cannot be verified. Fix the marker access issue, then use the actual agent rather than a direct terminal build.'
    } elseif ($missingTools.Count) {
        Row MISSING 'Stack toolchain' ("the required toolchain commands are absent from this doctor process environment: {0}; this does not prove the agent host's post-write environment. Fix: install them on this machine if the actual-host canary also fails." -f ($missingTools -join ','))
    } elseif (-not $needsDotnet -and -not $needsAngular) {
        Row OK 'Stack toolchain' ("not applicable: no repository-evidenced .NET or Angular application markers were found; no command was inferred from template '{0}'." -f $template)
        $script:stackCanary = 'not applicable: no repository-evidenced .NET or Angular application markers were found, so this repository has no compile/type-error canary to run.'
    } else {
        $toolchainLabel = if ($needsDotnet -and $needsAngular) { '.NET and Angular' } elseif ($needsDotnet) { '.NET' } else { 'Angular' }
        Row OK 'Stack toolchain' ("required repository-evidenced {0} toolchain commands are available in this doctor process environment; this does not prove the agent host's post-write environment." -f $toolchainLabel)
        if ($needsDotnet -and $needsAngular) { $script:stackCanary = 'through the actual agent, make and then revert a harmless deliberate compile/type error in one selected real build-relevant .NET or Angular file after the post-write throttle has elapsed; pass = the hook output starts with "## dotnet build failed" or "## tsc --noEmit failed". Model diagnosis or a direct terminal build is not a pass.' }
        elseif ($needsDotnet) { $script:stackCanary = 'through the actual agent, make and then revert a harmless deliberate compile/type error in a selected real build-relevant .NET file after the post-write throttle has elapsed; pass = the hook output starts with "## dotnet build failed". Model diagnosis or a direct terminal build is not a pass.' }
        else { $script:stackCanary = 'through the actual agent, make and then revert a harmless deliberate type error in a selected real build-relevant Angular file after the post-write throttle has elapsed; pass = the hook output starts with "## tsc --noEmit failed". Model diagnosis or a direct terminal build is not a pass.' }
    }
}

if ($copilotValid) {
    if (Has copilot) { Row OK 'Copilot surface' 'hooks.json is valid and Copilot CLI is available in this doctor process environment.' }
    else { Row OK 'Copilot surface' 'hooks.json is valid; Copilot CLI is absent from this doctor process environment. Claude-only teams need no action; Copilot teams must use the actual-surface canaries below.' }
} elseif ($copilotReadFailed) { Row CANT-VERIFY 'Copilot surface' '.github/hooks/hooks.json exists but could not be read; its validity and Copilot hook surface are unknown. Fix read access and rerun the doctor.' }
elseif ($copilotExists) { Row MISSING 'Copilot surface' '.github/hooks/hooks.json exists but is not valid JSON. Fix: re-run the installer or correct the file.' }
else { Row MISSING 'Copilot surface' '.github/hooks/hooks.json is missing. Fix: re-run the installer.' }

if ($pending) { Row PENDING 'Mirror and version integrity' 'not checked until /bootstrap or /adopt completes.' }
else {
    $check = Join-Path $root 'scripts/template-checks.ps1'
    if (Test-Path -LiteralPath $check) {
        # Self-host: run template-checks with THIS process's own interpreter, resolved by path.
        # A bare name ('pwsh'/'powershell') is only as good as the PATH the agent host happens to
        # hand us, and when it does not resolve the failure is indistinguishable from a real drift
        # finding -- so the doctor told you "CLAUDE.md and AGENTS.md have drifted, run
        # /generate-copilot" when the truth was "I could not start an interpreter". Observed: a
        # session whose PATH contained a literal unexpanded ${PATH}, leaving System32 off it, so
        # 'powershell' did not resolve under Windows PowerShell 5.1. A failure caused by the PATH is
        # not the same fact as the thing being diagnosed, and reporting them identically is what
        # lets the gap persist.
        $hostExe = $null
        try { $hostExe = (Get-Process -Id $PID).Path } catch { $hostExe = $null }
        if ([string]::IsNullOrEmpty($hostExe)) {
            $hostExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
        }
        $checkRan = $true
        $checkStatus = $null
        try {
            & $hostExe -NoProfile -ExecutionPolicy Bypass -File $check *> $null
            $checkStatus = $LASTEXITCODE
        }
        catch { $checkRan = $false }
        if (-not $checkRan -or $null -eq $checkStatus) {
            Row CANT-VERIFY 'Mirror and version integrity' 'could not start a PowerShell host to run template-checks, so drift is UNKNOWN rather than found. This is a host/PATH problem, not a documentation problem. Fix: run scripts/template-checks.ps1 yourself and act on what it says.'
        }
        elseif ($checkStatus -eq 0) { Row OK 'Mirror and version integrity' 'template-checks passed.' }
        elseif ($checkStatus -eq 3) { Row MISSING 'Mirror and version integrity' 'template-checks reported integrity findings. Run it directly and follow its exact findings.' }
        else { Row CANT-VERIFY 'Mirror and version integrity' ("template-checks did not complete (exit {0}), so integrity is UNKNOWN rather than missing. Run template-checks directly and inspect its output before changing framework files." -f $checkStatus) }
    } else { Row MISSING 'Mirror and version integrity' 'template-checks is missing. Fix: re-run the installer.' }
}

$audit = Join-Path $root '.claude/ai-audit.log'
if ($pending) { Row PENDING 'Audit trail substrate' 'not checked until /bootstrap or /adopt completes.' }
elseif (-not (Test-Path -LiteralPath $audit)) {
    Row MISSING 'Audit trail substrate' '.claude/ai-audit.log is missing, so local hook telemetry cannot be appended. Fix: create the file and ensure developers can append to it.'
} else {
    try {
        $stream = [IO.File]::Open($audit, 'Append', 'Write', 'ReadWrite'); $stream.Close()
        Row OK 'Audit trail substrate' 'audit log exists and is appendable.'
    } catch { Row MISSING 'Audit trail substrate' 'audit log is not appendable. Fix: grant the developer write access to .claude/ai-audit.log.' }
}
Finish
