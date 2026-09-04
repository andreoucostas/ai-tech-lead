# Shared by release.ps1 and check-outgoing-commits.ps1. Keep the MSYS corruption signature here so
# release commits and ordinary pushes cannot drift.
$gitRootPattern = '(?i)(Program Files[\\/]+Git|Git[\\/]+usr[\\/]+bin|[A-Za-z]:[\\/]+.*[\\/]+(?:bootstrap|adopt|review|fix|feature|design|debt|map-warehouse)\b)'

function Test-MsysMangledSubject {
    param([string]$Subject)
    return $Subject -match $gitRootPattern
}

function Get-CommitSubjectRejection {
    param([AllowEmptyString()][string]$Subject)
    if ($Subject.Length -lt 10) { return 'the subject is shorter than 10 characters (degenerate)' }
    if ($Subject -notmatch '[\p{L}\p{N}]') { return 'the subject consists only of punctuation' }
    if (Test-MsysMangledSubject $Subject) { return 'the subject matches the MSYS path-conversion signature' }
    return $null
}
