# Descriptive current-state codebase scorecard. Emits JSON to stdout. It is a snapshot, not a
# before/after measurement, and shows nothing about what caused a value to be what it is.
# Monorepo variant: counts both stacks' anti-patterns (.NET over
# *.cs, Angular over *.ts/*.html) in one flat metrics object; the three shared-name counters are
# the sum of both stacks' counts. Usage: pwsh -NoProfile -File scripts/metrics.ps1 [path ...]
# (default: whole repo)
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

function CountCs([string]$rx, [switch]$CaseSensitive) {
    $files = Get-ChildItem -LiteralPath $paths -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -eq '.cs' } |
        Where-Object { $_.FullName -notmatch '[\\/](bin|obj|node_modules|dist|\.angular)[\\/]' }
    if (-not $files) { return 0 }
    ($files | Select-String -Pattern $rx -CaseSensitive:$CaseSensitive -ErrorAction SilentlyContinue | Measure-Object).Count
}
function CountNg([string]$rx, [switch]$CaseSensitive) {
    $files = Get-ChildItem -LiteralPath $paths -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @('.ts', '.html') } |
        Where-Object { $_.FullName -notmatch '[\\/](bin|obj|node_modules|dist|\.angular)[\\/]' }
    if (-not $files) { return 0 }
    ($files | Select-String -Pattern $rx -CaseSensitive:$CaseSensitive -ErrorAction SilentlyContinue | Measure-Object).Count
}

# Whole-file match, for a signature that spans lines.
function CountText([string]$rx) {
    $files = Get-ChildItem -LiteralPath $paths -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -eq '.cs' } |
        Where-Object { $_.FullName -notmatch '[\\/](bin|obj|node_modules|dist|\.angular)[\\/]' }
    $n = 0
    foreach ($f in $files) { try { $n += [regex]::Matches([IO.File]::ReadAllText($f.FullName), $rx, 'IgnoreCase').Count } catch { } }
    $n
}

$asyncTotal = CountText 'async\s+(Task|ValueTask)'
$asyncCt    = CountText 'async\s+(Task|ValueTask)[^)]*CancellationToken'
$missingCt  = [Math]::Max(0, $asyncTotal - $asyncCt)

# The 2025 Angular style guide drops the Service suffix (User, not UserService), so `new X(` also
# counts when the repository declares X with @Injectable or @Service.
$diNames = @(Get-ChildItem -LiteralPath . -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -eq '.ts' } |
    Where-Object { $_.FullName -notmatch '[\\/](bin|obj|node_modules|dist|\.angular)[\\/]' } |
    ForEach-Object { try { [regex]::Matches([IO.File]::ReadAllText($_.FullName), '@(?:Injectable|Service)\s*\((?:[^()]|\([^()]*\))*\)\s*(?:export\s+)?(?:default\s+)?(?:abstract\s+)?class\s+([A-Za-z_$][\w$]*)') } catch { } } |
    ForEach-Object { [regex]::Escape($_.Groups[1].Value) } | Sort-Object -Unique)
$newDi = 'new\s+([A-Za-z0-9_]+(Service|Store|Facade)'
if ($diNames.Count -gt 0) { $newDi += '|' + ($diNames -join '|') }
$newDi += ')\('

# Angular specs and their focus and skip forms in Jasmine and in Vitest/Jest; `.test(` is RegExp.test.
$m = [ordered]@{
    async_missing_cancellationtoken    = $missingCt
    interpolated_logging               = (CountCs '_?[Ll]ogger\.(Log[A-Za-z]*)\(\s*\$"')
    pragma_warning_disable             = (CountCs '#pragma\s+warning\s+disable')
    console_writeline                  = (CountCs 'Console\.(Write|WriteLine)\(')
    weak_crypto_md5_sha1               = (CountCs '\b(MD5|SHA1)\b')
    raw_sql                            = (CountCs '(FromSqlRaw|ExecuteSqlRaw)')
    money_double_float                 = (CountCs '(double|float)\s+[A-Za-z_]*(Amount|Balance|Price|Rate|Fee|Notional)')
    test_attributes                    = (CountCs '\[(Fact|Theory|Test|TestMethod|TestCase)\b')
    tests_skipped                      = (CountCs '\[(Fact|Theory)\([^)]*Skip\s*=')
    tautological_assert                = (CountCs 'Assert\.(True\(\s*true|False\(\s*false)\s*[),]')
    any_type                           = (CountNg ':\s*any\b|<any>')
    ts_ignore_nocheck                  = (CountNg '@ts-(ignore|nocheck)')
    eslint_disable                     = (CountNg 'eslint-disable')
    manual_subscribe                   = (CountNg '\.subscribe\(')
    bypass_security_trust              = (CountNg 'bypassSecurityTrust')
    console_log                        = (CountNg 'console\.(log|debug|warn|error)\(')
    test_specs                         = (CountNg '\b(it|describe|suite)\(|(?<![.\w$])test\(')
    tests_skipped_focused              = (CountNg '\b(fit|fdescribe|xit|xdescribe)\s*\(|\b(it|test|describe|suite)(\.(concurrent|sequential|fails|shuffle)){0,3}\.(only|skip|skipIf|runIf|todo)\s*[(.]')
    tautological_expect                = (CountNg 'expect\(\s*(true|false)\s*\)\.toBe\(\s*(true|false)\s*\)')
    todo_hack_fixme                    = ((CountCs '(TODO|HACK|FIXME)' -CaseSensitive) + (CountNg '(TODO|HACK|FIXME)' -CaseSensitive))
    not_implemented_throws             = ((CountCs 'throw\s+new\s+(NotImplementedException|NotSupportedException)') + (CountNg 'throw\s+new\s+Error\([''"]not implemented'))
    concrete_service_instantiation_dip = ((CountCs 'new\s+[A-Za-z0-9_]+(Service|Repository|Handler|Manager)\(') + (CountNg $newDi))
}

# --- Readiness signals: capability disclosure, NOT a gate ---
$ciPresent = (Test-Path 'bitbucket-pipelines.yml') -or (Test-Path 'bitbucket-pipelines.yaml') -or (Test-Path '.github/workflows') -or (Test-Path 'azure-pipelines.yml')
$covPct = $null
$covFile = Get-ChildItem -LiteralPath . -Recurse -File -Filter 'coverage.cobertura.xml' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/](node_modules|bin|obj|dist)[\\/]' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $covFile) {
    $covFile = Get-ChildItem -LiteralPath . -Recurse -File -Filter 'cobertura-coverage.xml' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](node_modules|bin|obj|dist)[\\/]' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
if (-not $covFile) {
    $covFile = Get-ChildItem -LiteralPath . -Recurse -File -Filter '*cobertura*.xml' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](node_modules|bin|obj|dist)[\\/]' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
if ($covFile) { try { $xml = [xml](Get-Content -LiteralPath $covFile.FullName -Raw); $lr = $xml.coverage.'line-rate'; if ($lr) { $covPct = [math]::Round([double]$lr * 100, 1) } } catch {} }
$projFiles = Get-ChildItem -LiteralPath . -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -eq '.csproj' -or $_.Name -eq 'Directory.Build.props' } |
    Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' }
$nullable = [bool]($projFiles | Select-String -Pattern '<Nullable>\s*enable' -ErrorAction SilentlyContinue | Select-Object -First 1)
$warnErr  = [bool]($projFiles | Select-String -Pattern '<TreatWarningsAsErrors>\s*true' -ErrorAction SilentlyContinue | Select-Object -First 1)
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
    ci_present         = $ciPresent
    coverage_pct       = $covPct
    nullable_enabled   = $nullable
    warnings_as_errors = $warnErr
    ts_strict          = $tsStrict
    has_tests          = (($m.test_attributes -gt 0) -or ($m.test_specs -gt 0))
}
[pscustomobject]@{ stack = 'monorepo'; scope = ($scopeLabel -join ' '); metrics = $m; readiness = $r } | ConvertTo-Json -Depth 4
