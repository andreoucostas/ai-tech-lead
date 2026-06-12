# Deterministic codebase scorecard for the impact before/after. Emits JSON to stdout.
# PowerShell twin of metrics.sh. Usage: pwsh scripts/metrics.ps1 [path ...]  (default: whole repo)
$ErrorActionPreference = 'SilentlyContinue'
$root = (git rev-parse --show-toplevel 2>$null); if (-not $root) { $root = (Get-Location).Path }
Set-Location $root
$paths = if ($args.Count -gt 0) { $args } else { @('.') }

function Count([string]$rx) {
    $files = Get-ChildItem -Path $paths -Recurse -File -Include *.cs -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](bin|obj|node_modules|dist)[\\/]' }
    if (-not $files) { return 0 }
    ($files | Select-String -Pattern $rx -ErrorAction SilentlyContinue | Measure-Object).Count
}

$asyncTotal = Count 'async\s+(Task|ValueTask)'
$asyncCt    = Count 'async\s+(Task|ValueTask)[^)]*CancellationToken'
$missingCt  = [Math]::Max(0, $asyncTotal - $asyncCt)

$m = [ordered]@{
    async_missing_cancellationtoken    = $missingCt
    interpolated_logging               = (Count '_?[Ll]ogger\.(Log[A-Za-z]*)\(\s*\$"')
    pragma_warning_disable             = (Count '#pragma\s+warning\s+disable')
    console_writeline                  = (Count 'Console\.(Write|WriteLine)\(')
    todo_hack_fixme                    = (Count '(TODO|HACK|FIXME)')
    not_implemented_throws             = (Count 'throw\s+new\s+(NotImplementedException|NotSupportedException)')
    concrete_service_instantiation_dip = (Count 'new\s+[A-Za-z0-9_]+(Service|Repository|Handler|Manager)\(')
    weak_crypto_md5_sha1               = (Count '\b(MD5|SHA1)\b')
    raw_sql                            = (Count '(FromSqlRaw|ExecuteSqlRaw)')
    money_double_float                 = (Count '(double|float)\s+[A-Za-z_]*(Amount|Balance|Price|Rate|Fee|Notional)')
    test_attributes                    = (Count '\[(Fact|Theory|Test|TestMethod)\]')
}

# --- Readiness signals: capability disclosure for /impact, NOT a gate ---
$ciPresent = (Test-Path 'bitbucket-pipelines.yml') -or (Test-Path 'bitbucket-pipelines.yaml') -or (Test-Path '.github/workflows') -or (Test-Path 'azure-pipelines.yml')
$covPct = $null
$covFile = Get-ChildItem -Path . -Recurse -File -Filter 'coverage.cobertura.xml' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/](node_modules|bin|obj)[\\/]' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $covFile) {
    $covFile = Get-ChildItem -Path . -Recurse -File -Filter '*cobertura*.xml' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](node_modules|bin|obj)[\\/]' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
if ($covFile) { try { $xml = [xml](Get-Content $covFile.FullName -Raw); $lr = $xml.coverage.'line-rate'; if ($lr) { $covPct = [math]::Round([double]$lr * 100, 1) } } catch {} }
$projFiles = Get-ChildItem -Path . -Recurse -File -Include *.csproj, Directory.Build.props -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' }
$nullable = [bool]($projFiles | Select-String -Pattern '<Nullable>\s*enable' -ErrorAction SilentlyContinue | Select-Object -First 1)
$warnErr  = [bool]($projFiles | Select-String -Pattern '<TreatWarningsAsErrors>\s*true' -ErrorAction SilentlyContinue | Select-Object -First 1)
$r = [ordered]@{
    ci_present         = $ciPresent
    coverage_pct       = $covPct
    nullable_enabled   = $nullable
    warnings_as_errors = $warnErr
    has_tests          = ($m.test_attributes -gt 0)
}
[pscustomobject]@{ stack = 'dotnet'; scope = ($paths -join ' '); metrics = $m; readiness = $r } | ConvertTo-Json -Depth 4
