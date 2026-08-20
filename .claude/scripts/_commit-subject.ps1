# Shared by release.ps1 and the opt-in maintainer commit-msg hook. Keep the MSYS corruption
# signature here so the release path and ordinary-commit path cannot drift.
$gitRootPattern = '(?i)(Program Files[\\/]+Git|Git[\\/]+usr[\\/]+bin|[A-Za-z]:[\\/]+.*[\\/]+(?:bootstrap|adopt|review|fix|feature|design|debt|map-warehouse)\b)'

function Test-MsysMangledSubject {
    param([string]$Subject)
    return $Subject -match $gitRootPattern
}
