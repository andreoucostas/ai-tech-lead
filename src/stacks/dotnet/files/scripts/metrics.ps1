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
        Where-Object { $_.Extension -eq '.cs' } |
        Where-Object { $_.FullName -notmatch '[\\/](bin|obj|node_modules|dist)[\\/]' }
    if (-not $files) { return 0 }
    ($files | Select-String -Pattern $rx -CaseSensitive:$CaseSensitive -ErrorAction SilentlyContinue | Measure-Object).Count
}

# Whole-file match, for a signature that spans lines.
function CountText([string]$rx) {
    $files = Get-ChildItem -LiteralPath $paths -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -eq '.cs' } |
        Where-Object { $_.FullName -notmatch '[\\/](bin|obj|node_modules|dist)[\\/]' }
    $n = 0
    foreach ($f in $files) { try { $n += [regex]::Matches([IO.File]::ReadAllText($f.FullName), $rx, 'IgnoreCase').Count } catch { } }
    $n
}

$asyncTotal = CountText 'async\s+(Task|ValueTask)'
$asyncCt    = CountText 'async\s+(Task|ValueTask)[^)]*CancellationToken'
$missingCt  = [Math]::Max(0, $asyncTotal - $asyncCt)

$m = [ordered]@{
    async_missing_cancellationtoken    = $missingCt
    interpolated_logging               = (Count '_?[Ll]ogger\.(Log[A-Za-z]*)\(\s*\$"')
    pragma_warning_disable             = (Count '#pragma\s+warning\s+disable')
    console_writeline                  = (Count 'Console\.(Write|WriteLine)\(')
    todo_hack_fixme                    = (Count '(TODO|HACK|FIXME)' -CaseSensitive)
    not_implemented_throws             = (Count 'throw\s+new\s+(NotImplementedException|NotSupportedException)')
    concrete_service_instantiation_dip = (Count 'new\s+[A-Za-z0-9_]+(Service|Repository|Handler|Manager)\(')
    weak_crypto_md5_sha1               = (Count '\b(MD5|SHA1)\b')
    raw_sql                            = (Count '(FromSqlRaw|ExecuteSqlRaw)')
    money_double_float                 = (Count '(double|float)\s+[A-Za-z_]*(Amount|Balance|Price|Rate|Fee|Notional)')
    test_attributes                    = (Count '\[(Fact|Theory|Test|TestMethod|TestCase)\b')
    tests_skipped                      = (Count '\[(Fact|Theory)\([^)]*Skip\s*=')
    tautological_assert                = (Count 'Assert\.(True\(\s*true|False\(\s*false)\s*[),]')
}

# --- Readiness signals: capability disclosure, NOT a gate ---
$ciPresent = (Test-Path 'bitbucket-pipelines.yml') -or (Test-Path 'bitbucket-pipelines.yaml') -or (Test-Path '.github/workflows') -or (Test-Path 'azure-pipelines.yml')
$covPct = $null
$covFile = Get-ChildItem -LiteralPath . -Recurse -File -Filter 'coverage.cobertura.xml' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/](node_modules|bin|obj)[\\/]' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $covFile) {
    $covFile = Get-ChildItem -LiteralPath . -Recurse -File -Filter '*cobertura*.xml' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](node_modules|bin|obj)[\\/]' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
if ($covFile) { try { $xml = [xml](Get-Content -LiteralPath $covFile.FullName -Raw); $lr = $xml.coverage.'line-rate'; if ($lr) { $covPct = [math]::Round([double]$lr * 100, 1) } } catch {} }
$projFiles = Get-ChildItem -LiteralPath . -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -eq '.csproj' -or $_.Name -eq 'Directory.Build.props' } |
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
[pscustomobject]@{ stack = 'dotnet'; scope = ($scopeLabel -join ' '); metrics = $m; readiness = $r } | ConvertTo-Json -Depth 4
