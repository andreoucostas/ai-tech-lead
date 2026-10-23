# Descriptive current-state codebase scorecard. Emits JSON to stdout. It is a snapshot, not a
# before/after measurement, and shows nothing about what caused a value to be what it is.
# Usage: pwsh -NoProfile -File scripts/metrics.ps1 [path ...]  (default: whole repo)
$ErrorActionPreference = 'SilentlyContinue'
# A relative scope is the caller's, so it resolves before the cd to the repository root; the whole repository is the default.
# Windows PowerShell 5.1 cannot start in a folder whose name has [ or ] and falls back to its own install folder; the process
# working directory still holds the real one.
$caller = (Get-Location).Path
if ($PSVersionTable.PSEdition -ne 'Core' -and $caller -eq $PSHOME -and [Environment]::CurrentDirectory -ne $PSHOME) { $caller = [Environment]::CurrentDirectory }
$root = (git -C $caller rev-parse --show-toplevel 2>$null); if (-not $root) { $root = $caller }
$scopeLabel = if ($args.Count -gt 0) { $args } else { @('.') }
$paths = @()
if ($args.Count -gt 0) {
    foreach ($arg in $args) {
        $full = if ([IO.Path]::IsPathRooted($arg)) { [string]$arg } else { Join-Path $caller $arg }
        if (-not (Test-Path -LiteralPath $full)) { [Console]::Error.WriteLine("metrics: path not found: $arg"); exit 2 }
        $paths += (Resolve-Path -LiteralPath $full).ProviderPath
    }
} else { $paths = @($root) }
Set-Location -LiteralPath $root

function Count([string]$rx, [switch]$CaseSensitive) {
    $files = Get-ChildItem -LiteralPath $paths -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @('.ts', '.html') } |
        Where-Object { $_.FullName -notmatch '[\\/](node_modules|dist|\.angular)[\\/]' }
    if (-not $files) { return 0 }
    ($files | Select-String -Pattern $rx -CaseSensitive:$CaseSensitive -ErrorAction SilentlyContinue | Measure-Object).Count
}

# The 2025 style guide drops the Service suffix (User, not UserService), so `new X(` also counts
# when the repository declares X with @Injectable or @Service.
$diNames = @(Get-ChildItem -LiteralPath . -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -eq '.ts' } |
    Where-Object { $_.FullName -notmatch '[\\/](node_modules|dist|\.angular)[\\/]' } |
    ForEach-Object { try { [regex]::Matches([IO.File]::ReadAllText($_.FullName), '@(?:Injectable|Service)\s*\((?:[^()]|\([^()]*\))*\)\s*(?:export\s+)?(?:default\s+)?(?:abstract\s+)?class\s+([A-Za-z_$][\w$]*)') } catch { } } |
    ForEach-Object { [regex]::Escape($_.Groups[1].Value) } | Sort-Object -Unique)
$newDi = 'new\s+([A-Za-z0-9_]+(Service|Store|Facade)'
if ($diNames.Count -gt 0) { $newDi += '|' + ($diNames -join '|') }
$newDi += ')\('

# Specs and their focus and skip forms in Jasmine and in Vitest/Jest; `.test(` is RegExp.test.
$m = [ordered]@{
    any_type                           = (Count ':\s*any\b|<any>')
    ts_ignore_nocheck                  = (Count '@ts-(ignore|nocheck)')
    eslint_disable                     = (Count 'eslint-disable')
    manual_subscribe                   = (Count '\.subscribe\(')
    bypass_security_trust              = (Count 'bypassSecurityTrust')
    console_log                        = (Count 'console\.(log|debug|warn|error)\(')
    todo_hack_fixme                    = (Count '(TODO|HACK|FIXME)' -CaseSensitive)
    not_implemented_throws             = (Count 'throw\s+new\s+Error\([''"]not implemented')
    concrete_service_instantiation_dip = (Count $newDi)
    test_specs                         = (Count '\b(it|describe|suite)\(|(?<![.\w$])test\(')
    tests_skipped_focused              = (Count '\b(fit|fdescribe|xit|xdescribe)\s*\(|\b(it|test|describe|suite)(\.(concurrent|sequential|fails|shuffle)){0,3}\.(only|skip|skipIf|runIf|todo)\s*[(.]')
    tautological_expect                = (Count 'expect\(\s*(true|false)\s*\)\.toBe\(\s*(true|false)\s*\)')
}

# --- Readiness signals: capability disclosure, NOT a gate ---
$ciPresent = (Test-Path 'bitbucket-pipelines.yml') -or (Test-Path 'bitbucket-pipelines.yaml') -or (Test-Path '.github/workflows') -or (Test-Path 'azure-pipelines.yml')
$covPct = $null
$covFile = Get-ChildItem -LiteralPath . -Recurse -File -Filter 'cobertura-coverage.xml' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/](node_modules|dist)[\\/]' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $covFile) {
    $covFile = Get-ChildItem -LiteralPath . -Recurse -File -Filter '*cobertura*.xml' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](node_modules|dist)[\\/]' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
if ($covFile) { try { $xml = [xml](Get-Content -LiteralPath $covFile.FullName -Raw); $lr = $xml.coverage.'line-rate'; if ($lr) { $covPct = [math]::Round([double]$lr * 100, 1) } } catch {} }
# ts_strict: a tsconfig's own "strict" decides. Without one, the default of the TypeScript major a simple
# package.json range names decides (strict from TypeScript 6, which Angular 22 requires, so a strict v22
# workspace omits the key). null when there is no tsconfig or no such range.
$tsConfigs = @(Get-ChildItem -LiteralPath . -Recurse -File -Filter 'tsconfig*.json' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/](node_modules|dist)[\\/]' })
$tsStrict = $null
if ($tsConfigs | Select-String -Pattern '"strict"\s*:\s*true' -ErrorAction SilentlyContinue | Select-Object -First 1) { $tsStrict = $true }
elseif ($tsConfigs | Select-String -Pattern '"strict"\s*:\s*false' -ErrorAction SilentlyContinue | Select-Object -First 1) { $tsStrict = $false }
elseif ($tsConfigs.Count -gt 0) {
    $tsMajors = @(Get-ChildItem -LiteralPath . -Recurse -File -Filter 'package.json' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](node_modules|dist)[\\/]' } |
        ForEach-Object { try { [regex]::Matches([IO.File]::ReadAllText($_.FullName), '"typescript"\s*:\s*"([^"]*)"') } catch { } } |
        ForEach-Object { if ($_.Groups[1].Value -match '^\s*[\^~]?\s*v?(\d+)(\.(\d+|[xX*])){0,2}\s*$') { [int]$Matches[1] } else { -1 } })
    if ($tsMajors.Count -gt 0 -and $tsMajors -notcontains -1) {
        $ts6 = @($tsMajors | Where-Object { $_ -ge 6 }).Count
        if ($ts6 -eq $tsMajors.Count) { $tsStrict = $true } elseif ($ts6 -eq 0) { $tsStrict = $false }
    }
}
$r = [ordered]@{
    ci_present   = $ciPresent
    coverage_pct = $covPct
    ts_strict    = $tsStrict
    has_tests    = ($m.test_specs -gt 0)
}
[pscustomobject]@{ stack = 'angular'; scope = ($scopeLabel -join ' '); metrics = $m; readiness = $r } | ConvertTo-Json -Depth 4
