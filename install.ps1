# AI Tech Lead Framework — root installer wrapper.
# Usage: pwsh install.ps1 [-Stack dotnet|angular|monorepo] [-GitHooks] [-WhatIf] [-AllowDowngrade] C:\path\to\target-repo
#
# Thin dispatcher only: it selects a stack, then delegates to
# dist/<stack>/scripts/install.ps1, which does all the real work (greenfield / brownfield /
# update detection, the copy, the pwsh->5.1 settings fallback, ...). This wrapper adds NO
# install logic of its own — stack selection and delegation, nothing more.
#
# Stack resolution (first match wins):
#   1. -Stack flag        explicit; always wins.
#   2. update stamp       target/.claude/framework-version.json exists -> use its "template".
#   3. auto-detect        *.csproj -> dotnet ; evidenced Angular config/package -> angular ;
#                         both, or Angular + warehouse SQL -> monorepo.
#                         Searched in the target root plus two directory levels below it.
#   4. warehouse-only     two or more independent warehouse signal categories -> dotnet
#                         delivery profile; /bootstrap selects warehouse-SQL from repo evidence.
#   5. nothing detected   error: pass -Stack.
# Every error exits 2 with an actionable message on stderr. -Stack / -Target are validated by
# hand (not via ValidateSet / Mandatory) so bad input also exits 2 — and the twin, not an
# interactive prompt — matching install.sh.
param(
    [Parameter()][string]$Stack,
    [Parameter()][switch]$GitHooks,
    [Parameter()][switch]$WhatIf,
    [Parameter()][switch]$AllowDowngrade,
    [Parameter(Position = 0)][string]$Target
)
$ErrorActionPreference = 'Stop'

$usage = 'Usage: pwsh install.ps1 [-Stack dotnet|angular|monorepo] [-GitHooks] [-WhatIf] [-AllowDowngrade] C:\path\to\target-repo'
# Exit 2 with an actionable message on stderr. Write-Error is avoided on purpose: under
# ErrorActionPreference=Stop it throws before the following exit runs, which -File maps to
# exit code 1 — this keeps every wrapper-level failure at the documented exit 2.
function Die([string]$msg) { [Console]::Error.WriteLine($msg); exit 2 }

# ConvertFrom-Json accepts JavaScript extensions (comments, single quotes, unquoted keys, trailing
# commas, NaN/Infinity, and leading-zero numbers) that jq and Python reject. Validate the RFC JSON
# grammar first so stack selection is byte-for-byte parser-independent and remains PS 5.1-safe.
function ConvertFrom-StrictJson([string]$Text) {
    $state = [pscustomobject]@{ Text = $Text; Index = 0; Length = $Text.Length }
    function Fail-StrictJson { throw 'invalid strict JSON' }
    function Skip-JsonWhitespace { while ($state.Index -lt $state.Length -and ([int]$state.Text[$state.Index] -in @(0x20,0x09,0x0A,0x0D))) { $state.Index++ } }
    function Read-JsonString {
        if ($state.Index -ge $state.Length -or $state.Text[$state.Index] -ne '"') { Fail-StrictJson }; $state.Index++
        while ($state.Index -lt $state.Length) {
            $c = $state.Text[$state.Index]; $state.Index++
            if ($c -eq '"') { return }
            if ([int]$c -lt 0x20) { Fail-StrictJson }
            if ($c -eq '\') {
                if ($state.Index -ge $state.Length) { Fail-StrictJson }
                $escape = $state.Text[$state.Index]; $state.Index++
                if ('"\/bfnrt'.IndexOf($escape) -ge 0) { continue }
                if ($escape -ne 'u' -or $state.Index + 4 -gt $state.Length) { Fail-StrictJson }
                for ($h = 0; $h -lt 4; $h++) { if (-not [Uri]::IsHexDigit($state.Text[$state.Index + $h])) { Fail-StrictJson } }
                $state.Index += 4
            }
        }
        Fail-StrictJson
    }
    function Read-JsonNumber {
        if ($state.Text[$state.Index] -eq '-') { $state.Index++; if ($state.Index -ge $state.Length) { Fail-StrictJson } }
        $code = [int]$state.Text[$state.Index]
        if ($code -eq 0x30) { $state.Index++; if ($state.Index -lt $state.Length -and [int]$state.Text[$state.Index] -ge 0x30 -and [int]$state.Text[$state.Index] -le 0x39) { Fail-StrictJson } }
        elseif ($code -ge 0x31 -and $code -le 0x39) { do { $state.Index++ } while ($state.Index -lt $state.Length -and [int]$state.Text[$state.Index] -ge 0x30 -and [int]$state.Text[$state.Index] -le 0x39) }
        else { Fail-StrictJson }
        if ($state.Index -lt $state.Length -and $state.Text[$state.Index] -eq '.') {
            $state.Index++; $start = $state.Index
            while ($state.Index -lt $state.Length -and [int]$state.Text[$state.Index] -ge 0x30 -and [int]$state.Text[$state.Index] -le 0x39) { $state.Index++ }
            if ($state.Index -eq $start) { Fail-StrictJson }
        }
        if ($state.Index -lt $state.Length -and ($state.Text[$state.Index] -eq 'e' -or $state.Text[$state.Index] -eq 'E')) {
            $state.Index++; if ($state.Index -lt $state.Length -and ($state.Text[$state.Index] -eq '+' -or $state.Text[$state.Index] -eq '-')) { $state.Index++ }
            $start = $state.Index
            while ($state.Index -lt $state.Length -and [int]$state.Text[$state.Index] -ge 0x30 -and [int]$state.Text[$state.Index] -le 0x39) { $state.Index++ }
            if ($state.Index -eq $start) { Fail-StrictJson }
        }
    }
    function Read-JsonArray {
        $state.Index++; Skip-JsonWhitespace
        if ($state.Index -lt $state.Length -and $state.Text[$state.Index] -eq ']') { $state.Index++; return }
        while ($true) { Read-JsonValue; Skip-JsonWhitespace; if ($state.Index -ge $state.Length) { Fail-StrictJson }; $c=$state.Text[$state.Index];$state.Index++;if($c-eq']'){return};if($c-ne','){Fail-StrictJson};Skip-JsonWhitespace }
    }
    function Read-JsonObject {
        $state.Index++; Skip-JsonWhitespace
        if ($state.Index -lt $state.Length -and $state.Text[$state.Index] -eq '}') { $state.Index++; return }
        while ($true) { Read-JsonString;Skip-JsonWhitespace;if($state.Index-ge$state.Length-or$state.Text[$state.Index]-ne':'){Fail-StrictJson};$state.Index++;Read-JsonValue;Skip-JsonWhitespace;if($state.Index-ge$state.Length){Fail-StrictJson};$c=$state.Text[$state.Index];$state.Index++;if($c-eq'}'){return};if($c-ne','){Fail-StrictJson};Skip-JsonWhitespace }
    }
    function Read-JsonValue {
        Skip-JsonWhitespace; if ($state.Index -ge $state.Length) { Fail-StrictJson }; $c=$state.Text[$state.Index]
        if($c-eq'"'){Read-JsonString;return};if($c-eq'{'){Read-JsonObject;return};if($c-eq'['){Read-JsonArray;return}
        foreach($literal in @('true','false','null')){if($state.Index+$literal.Length-le$state.Length-and$state.Text.Substring($state.Index,$literal.Length)-ceq$literal){$state.Index+=$literal.Length;return}}
        if($c-eq'-'-or([int]$c-ge0x30-and[int]$c-le0x39)){Read-JsonNumber;return};Fail-StrictJson
    }
    Read-JsonValue; Skip-JsonWhitespace; if ($state.Index -ne $state.Length) { Fail-StrictJson }
    return ($Text | ConvertFrom-Json -ErrorAction Stop)
}

$selfDir = $PSScriptRoot
function Get-RepositoryFiles([string]$Path, [int]$MaxDepth = -1) {
    $excluded = @('.git','node_modules','bower_components','vendor','bin','obj','dist','build','out','.next','.angular','.nx','coverage')
    $files = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    $queue = [System.Collections.Generic.Queue[object]]::new()
    $queue.Enqueue([pscustomobject]@{ Directory = (Get-Item -LiteralPath $Path -Force -ErrorAction Stop); Depth = 0 })
    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        foreach ($item in Get-ChildItem -LiteralPath $current.Directory.FullName -Force -ErrorAction Stop) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
            if ($item.PSIsContainer) {
                if ($item.Name -in $excluded) { continue }
                if ($MaxDepth -lt 0 -or $current.Depth -lt $MaxDepth) {
                    $queue.Enqueue([pscustomobject]@{ Directory = $item; Depth = $current.Depth + 1 })
                }
            }
            elseif ($current.Depth -le $MaxDepth -or $MaxDepth -lt 0) { $files.Add($item) }
        }
    }
    return $files.ToArray()
}
function Get-WarehouseSignals([string]$Path) {
    $signals = Join-Path $selfDir 'dist/dotnet/scripts/warehouse-signals.tsv'
    if (-not (Test-Path -LiteralPath $signals -PathType Leaf)) { throw "Shared warehouse classifier not found at '$signals'." }
    $files = @(Get-RepositoryFiles -Path $Path | Where-Object { $_.Extension -in @('.sql','.sqlproj') -or $_.Name -eq 'dbt_project.yml' -or ($_.Extension -in @('.yml','.yaml','.json') -and $_.FullName -match '(?i)[\\/](etl|pipelines?|warehouse|datafactory|synapse|dags?)[\\/]|(pipeline|datafactory|synapse|dag)[^\\/]*\.(yml|yaml|json)$') })
    $hits = [System.Collections.Generic.List[string]]::new()
    foreach($line in Get-Content -LiteralPath $signals -ErrorAction Stop){if($line.StartsWith('#')-or[string]::IsNullOrWhiteSpace($line)){continue};$parts=$line-split"`t",2;foreach($file in $files){if($file.Name-match$parts[1]-or(Select-String -LiteralPath $file.FullName -Pattern $parts[1] -Quiet -ErrorAction Stop)){$hits.Add($parts[0]);break}}}
    return $hits.ToArray()
}
function Get-BoundedRepositoryFiles([string]$Path) {
    return @(Get-RepositoryFiles -Path $Path -MaxDepth 2)
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
    foreach ($mapName in @('generators','schematics')) {
        $map = $Node.PSObject.Properties | Where-Object Name -ceq $mapName | Select-Object -First 1
        if ($map.Value -is [System.Management.Automation.PSCustomObject]) { foreach ($candidate in $map.Value.PSObject.Properties.Name) { if (Test-ExactAngularPackageToken $candidate) { return $true } } }
    }
    foreach ($mapName in @('targets','architect','targetDefaults')) {
        $map = $Node.PSObject.Properties | Where-Object Name -ceq $mapName | Select-Object -First 1
        if (-not ($map.Value -is [System.Management.Automation.PSCustomObject])) { continue }
        foreach ($entry in $map.Value.PSObject.Properties) {
            if ($mapName -ceq 'targetDefaults' -and (Test-ExactAngularPackageToken $entry.Name)) { return $true }
            if ($entry.Value -is [System.Management.Automation.PSCustomObject]) { foreach ($field in @('executor','generator','collection','plugin')) { if (Test-ExactAngularPackageToken (Get-ExactJsonPropertyValue $entry.Value $field)) { return $true } } }
        }
    }
    return $false
}
function Test-AngularEvidence([System.IO.FileInfo[]]$Files) {
    foreach ($file in $Files) {
        if ($file.Name -notin @('angular.json', 'package.json', 'nx.json', 'project.json')) { continue }
        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
        if ($content -notmatch '^\s*\{') { throw "Angular evidence file '$($file.FullName)' must contain a JSON object." }
        $json = ConvertFrom-StrictJson $content
        if (($file.Name -eq 'angular.json') -or
            ($file.Name -eq 'package.json' -and (Test-PackageAngularCore $json)) -or
            ($file.Name -in @('nx.json', 'project.json') -and (Test-NxAngularEvidence $json))) { return $true }
    }
    return $false
}
if (-not $Target) { Die $usage }
if (-not (Test-Path -LiteralPath $Target -PathType Container)) { Die "Target '$Target' is not a directory." }
$tgt = (Resolve-Path -LiteralPath $Target).Path

$reason = ''
if ($Stack) {
    if ($Stack -cne 'dotnet' -and $Stack -cne 'angular' -and $Stack -cne 'monorepo') { Die "Unknown stack '$Stack' (expected: dotnet, angular, or monorepo)." }
    $reason = '-Stack flag'
}
else {
    $vf = Join-Path $tgt '.claude/framework-version.json'
    if (Test-Path -LiteralPath $vf -PathType Leaf) {
        # Existing install: honour the stack it was installed with (update mode). The stamp's
        # "template" value already matches the dist mode names (dotnet / angular / monorepo).
        try {
            $stampContent = Get-Content -Raw -LiteralPath $vf -ErrorAction Stop
            $stampObject = ConvertFrom-StrictJson $stampContent
            if ($stampContent -notmatch '^\s*\{') { throw 'framework-version root must be a JSON object' }
            $tmpl = Get-ExactJsonPropertyValue $stampObject 'template'
        }
        catch { Die "Existing install at '$tgt', but .claude/framework-version.json is invalid JSON or has no non-empty string ""template"" value — pass -Stack dotnet|angular|monorepo." }
        if (-not ($tmpl -is [string]) -or [string]::IsNullOrWhiteSpace($tmpl)) { Die "Existing install at '$tgt', but .claude/framework-version.json is invalid JSON or has no non-empty string ""template"" value — pass -Stack dotnet|angular|monorepo." }
        if ($tmpl -cne 'dotnet' -and $tmpl -cne 'angular' -and $tmpl -cne 'monorepo') { Die "Existing install names an unknown stack ""$tmpl"" in .claude/framework-version.json — pass -Stack dotnet|angular|monorepo." }
        $Stack = $tmpl
        $reason = "update stamp (.claude/framework-version.json template=$tmpl)"
    }
    else {
        # Auto-detect from build markers in the target root + two levels below (-Depth 2 walks
        # the root plus two subdirectory levels).
        try {
            $repositoryFiles = @(Get-BoundedRepositoryFiles $tgt)
            # A solution alone can be an SSDT/SQL-only container. A C# project is the bounded
            # application marker; solution files become locators only after that evidence exists.
            $hasDotnet = [bool]($repositoryFiles | Where-Object { $_.Extension -eq '.csproj' } | Select-Object -First 1)
            $hasAngular = Test-AngularEvidence $repositoryFiles
            $warehouseSignals = if (-not $hasDotnet) { @(Get-WarehouseSignals $tgt) } else { @() }
        }
        catch {
            Die "Could not inspect repository evidence under '$tgt': $($_.Exception.Message) Fix read/list access and retry, or pass -Stack dotnet|angular|monorepo explicitly."
        }
        if ($hasDotnet -and $hasAngular) {
            $Stack = 'monorepo'; $reason = 'auto-detected (found both *.csproj and Angular repository evidence — mixed repo)'
        }
        elseif ($hasDotnet) { $Stack = 'dotnet'; $reason = 'auto-detected (found *.csproj)' }
        elseif ($hasAngular -and $warehouseSignals.Count -ge 2) {
            $Stack = 'monorepo'
            $reason = "auto-detected mixed repo (found Angular + warehouse SQL profiles: $($warehouseSignals -join ', '))"
        }
        elseif ($hasAngular) { $Stack = 'angular'; $reason = 'auto-detected (found Angular repository evidence)' }
        else {
            if ($warehouseSignals.Count -ge 2) {
                $Stack = 'dotnet'
                $reason = "auto-detected warehouse SQL profile (found signals: $($warehouseSignals -join ', '))"
            }
            else {
                Die ("Could not determine the stack for '$tgt': no *.csproj and no Angular repository evidence in the target root or two levels below.`n" +
                    'Pass it explicitly: -Stack dotnet|angular|monorepo.')
            }
        }
    }
}

$delegate = Join-Path $selfDir "dist/$Stack/scripts/install.ps1"
if (-not (Test-Path -LiteralPath $delegate -PathType Leaf)) { Die "Internal error: expected installer not found at $delegate" }

Write-Output "Stack: $Stack (via $reason)"
Write-Output "Delegating to dist/$Stack/scripts/install.ps1 ..."
Write-Output ""
& $delegate -Target $tgt -GitHooks:$GitHooks -WhatIf:$WhatIf -AllowDowngrade:$AllowDowngrade
exit $LASTEXITCODE
