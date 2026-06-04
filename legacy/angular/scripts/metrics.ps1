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
[pscustomobject]@{ stack = 'angular'; scope = ($paths -join ' '); metrics = $m } | ConvertTo-Json -Depth 4
