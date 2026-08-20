# Validates the first line of a Git commit message for the opt-in maintainer commit-msg hook.
param([Parameter(Mandatory)][string]$MessageFile)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_commit-subject.ps1')

$subject = [IO.File]::ReadLines((Resolve-Path -LiteralPath $MessageFile)).GetEnumerator()
try { $null = $subject.MoveNext(); $subjectLine = [string]$subject.Current }
finally { $subject.Dispose() }

$reason = $null
if ($subjectLine.Length -lt 10) { $reason = 'the subject is shorter than 10 characters (degenerate)' }
elseif ($subjectLine -notmatch '[\p{L}\p{N}]') { $reason = 'the subject consists only of punctuation' }
elseif (Test-MsysMangledSubject $subjectLine) { $reason = 'the subject matches the MSYS path-conversion signature' }

if ($reason) {
    [Console]::Error.WriteLine("COMMIT REFUSED: $reason.`nSubject: $subjectLine")
    exit 1
}
