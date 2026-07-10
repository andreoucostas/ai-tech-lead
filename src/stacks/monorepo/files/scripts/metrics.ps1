# Deterministic codebase scorecard for the impact before/after. Emits JSON to stdout.
# PowerShell twin of metrics.sh. Monorepo variant: counts both stacks' anti-patterns (.NET over
# *.cs, Angular over *.ts/*.html) in one flat metrics object; the three shared-name counters are
# the sum of both stacks' counts. Usage: pwsh scripts/metrics.ps1 [path ...]  (default: whole repo)
$ErrorActionPreference = 'SilentlyContinue'
$root = (git rev-parse --show-toplevel 2>$null); if (-not $root) { $root = (Get-Location).Path }
Set-Location $root
$paths = if ($args.Count -gt 0) { $args } else { @('.') }

function CountCs([string]$rx) {
    $files = Get-ChildItem -Path $paths -Recurse -File -Include *.cs -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](bin|obj|node_modules|dist|\.angular)[\\/]' }
    if (-not $files) { return 0 }
    ($files | Select-String -Pattern $rx -ErrorAction SilentlyContinue | Measure-Object).Count
}
function CountNg([string]$rx) {
    $files = Get-ChildItem -Path $paths -Recurse -File -Include *.ts, *.html -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](bin|obj|node_modules|dist|\.angular)[\\/]' }
    if (-not $files) { return 0 }
    ($files | Select-String -Pattern $rx -ErrorAction SilentlyContinue | Measure-Object).Count
}

$asyncTotal = CountCs 'async\s+(Task|ValueTask)'
$asyncCt    = CountCs 'async\s+(Task|ValueTask)[^)]*CancellationToken'
$missingCt  = [Math]::Max(0, $asyncTotal - $asyncCt)

$m = [ordered]@{
    async_missing_cancellationtoken    = $missingCt
    interpolated_logging               = (CountCs '_?[Ll]ogger\.(Log[A-Za-z]*)\(\s*\$"')
    pragma_warning_disable             = (CountCs '#pragma\s+warning\s+disable')
    console_writeline                  = (CountCs 'Console\.(Write|WriteLine)\(')
    weak_crypto_md5_sha1               = (CountCs '\b(MD5|SHA1)\b')
    raw_sql                            = (CountCs '(FromSqlRaw|ExecuteSqlRaw)')
    money_double_float                 = (CountCs '(double|float)\s+[A-Za-z_]*(Amount|Balance|Price|Rate|Fee|Notional)')
    test_attributes                    = (CountCs '\[(Fact|Theory|Test|TestMethod)\]')
    tests_skipped                      = (CountCs '\[(Fact|Theory)\([^)]*Skip\s*=')
    tautological_assert                = (CountCs 'Assert\.(True\(\s*true|False\(\s*false)\s*[),]')
    any_type                           = (CountNg ':\s*any\b|<any>')
    ts_ignore_nocheck                  = (CountNg '@ts-(ignore|nocheck)')
    eslint_disable                     = (CountNg 'eslint-disable')
    manual_subscribe                   = (CountNg '\.subscribe\(')
    bypass_security_trust              = (CountNg 'bypassSecurityTrust')
    console_log                        = (CountNg 'console\.(log|debug|warn|error)\(')
    test_specs                         = (CountNg '\b(it|describe)\(')
    tests_skipped_focused              = (CountNg '\b(fit|fdescribe|xit|xdescribe)\s*\(|\b(it|describe)\.(only|skip)\s*\(')
    tautological_expect                = (CountNg 'expect\(\s*(true|false)\s*\)\.toBe\(\s*(true|false)\s*\)')
    todo_hack_fixme                    = ((CountCs '(TODO|HACK|FIXME)') + (CountNg '(TODO|HACK|FIXME)'))
    not_implemented_throws             = ((CountCs 'throw\s+new\s+(NotImplementedException|NotSupportedException)') + (CountNg 'throw\s+new\s+Error\([''"]not implemented'))
    concrete_service_instantiation_dip = ((CountCs 'new\s+[A-Za-z0-9_]+(Service|Repository|Handler|Manager)\(') + (CountNg 'new\s+[A-Za-z0-9_]+(Service|Store|Facade)\('))
}

# --- Readiness signals: capability disclosure for /impact, NOT a gate ---
$ciPresent = (Test-Path 'bitbucket-pipelines.yml') -or (Test-Path 'bitbucket-pipelines.yaml') -or (Test-Path '.github/workflows') -or (Test-Path 'azure-pipelines.yml')
$covPct = $null
$covFile = Get-ChildItem -Path . -Recurse -File -Filter 'coverage.cobertura.xml' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/](node_modules|bin|obj|dist)[\\/]' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $covFile) {
    $covFile = Get-ChildItem -Path . -Recurse -File -Filter 'cobertura-coverage.xml' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](node_modules|bin|obj|dist)[\\/]' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
if (-not $covFile) {
    $covFile = Get-ChildItem -Path . -Recurse -File -Filter '*cobertura*.xml' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](node_modules|bin|obj|dist)[\\/]' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
if ($covFile) { try { $xml = [xml](Get-Content $covFile.FullName -Raw); $lr = $xml.coverage.'line-rate'; if ($lr) { $covPct = [math]::Round([double]$lr * 100, 1) } } catch {} }
$projFiles = Get-ChildItem -Path . -Recurse -File -Include *.csproj, Directory.Build.props -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' }
$nullable = [bool]($projFiles | Select-String -Pattern '<Nullable>\s*enable' -ErrorAction SilentlyContinue | Select-Object -First 1)
$warnErr  = [bool]($projFiles | Select-String -Pattern '<TreatWarningsAsErrors>\s*true' -ErrorAction SilentlyContinue | Select-Object -First 1)
$tsStrict = [bool](Get-ChildItem -Path . -Recurse -File -Filter 'tsconfig*.json' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/](node_modules|dist)[\\/]' } | Select-String -Pattern '"strict"\s*:\s*true' -ErrorAction SilentlyContinue | Select-Object -First 1)
$r = [ordered]@{
    ci_present         = $ciPresent
    coverage_pct       = $covPct
    nullable_enabled   = $nullable
    warnings_as_errors = $warnErr
    ts_strict          = $tsStrict
    has_tests          = (($m.test_attributes -gt 0) -or ($m.test_specs -gt 0))
}
[pscustomobject]@{ stack = 'monorepo'; scope = ($paths -join ' '); metrics = $m; readiness = $r } | ConvertTo-Json -Depth 4
