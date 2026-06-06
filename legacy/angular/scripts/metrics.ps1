# Deterministic codebase scorecard for the impact before/after. Emits JSON to stdout.
# PowerShell twin of metrics.sh. Usage: pwsh scripts/metrics.ps1 [path ...]  (default: whole repo)
$ErrorActionPreference = 'SilentlyContinue'
$root = (git rev-parse --show-toplevel 2>$null); if (-not $root) { $root = (Get-Location).Path }
Set-Location $root
$paths = if ($args.Count -gt 0) { $args } else { @('.') }

function Count([string]$rx) {
    $files = Get-ChildItem -Path $paths -Recurse -File -Include *.ts, *.html -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](node_modules|dist|\.angular)[\\/]' }
    if (-not $files) { return 0 }
    ($files | Select-String -Pattern $rx -ErrorAction SilentlyContinue | Measure-Object).Count
}

$m = [ordered]@{
    any_type                           = (Count ':\s*any\b|<any>')
    ts_ignore_nocheck                  = (Count '@ts-(ignore|nocheck)')
    eslint_disable                     = (Count 'eslint-disable')
    manual_subscribe                   = (Count '\.subscribe\(')
    bypass_security_trust              = (Count 'bypassSecurityTrust')
    console_log                        = (Count 'console\.(log|debug|warn|error)\(')
    todo_hack_fixme                    = (Count '(TODO|HACK|FIXME)')
    not_implemented_throws             = (Count 'throw\s+new\s+Error\([''"]not implemented')
    concrete_service_instantiation_dip = (Count 'new\s+[A-Za-z0-9_]+(Service|Store|Facade)\(')
    test_specs                         = (Count '\b(it|describe)\(')
}

# --- Readiness signals: capability disclosure for /impact, NOT a gate ---
$ciPresent = (Test-Path 'bitbucket-pipelines.yml') -or (Test-Path 'bitbucket-pipelines.yaml') -or (Test-Path '.github/workflows') -or (Test-Path 'azure-pipelines.yml')
$covPct = $null
$covFile = Get-ChildItem -Path . -Recurse -File -Filter 'cobertura-coverage.xml' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/](node_modules|dist)[\\/]' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $covFile) {
    $covFile = Get-ChildItem -Path . -Recurse -File -Filter '*cobertura*.xml' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](node_modules|dist)[\\/]' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
if ($covFile) { try { $xml = [xml](Get-Content $covFile.FullName -Raw); $lr = $xml.coverage.'line-rate'; if ($lr) { $covPct = [math]::Round([double]$lr * 100, 1) } } catch {} }
$tsStrict = [bool](Get-ChildItem -Path . -Recurse -File -Filter 'tsconfig*.json' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/](node_modules|dist)[\\/]' } | Select-String -Pattern '"strict"\s*:\s*true' -ErrorAction SilentlyContinue | Select-Object -First 1)
$r = [ordered]@{
    ci_present   = $ciPresent
    coverage_pct = $covPct
    ts_strict    = $tsStrict
    has_tests    = ($m.test_specs -gt 0)
}
[pscustomobject]@{ stack = 'angular'; scope = ($paths -join ' '); metrics = $m; readiness = $r } | ConvertTo-Json -Depth 4
