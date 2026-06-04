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
[pscustomobject]@{ stack = 'dotnet'; scope = ($paths -join ' '); metrics = $m } | ConvertTo-Json -Depth 4
