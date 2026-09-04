# Checks the actual commits about to leave this repository. This replaces the optional shell-based
# pre-commit and commit-msg launchers: detection moves later, but every supported push path runs the
# same PowerShell check over immutable Git objects rather than an often-empty working-tree index.
# Exit 0 = checked and clean; 1 = content/subject rejected; 2 = usage/setup error;
# exit 3 = CANT-VERIFY the remote range or an object, so pushing is refused.
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$Remote = 'origin',
    [string]$Revision = 'HEAD',
    [string]$GitPath,
    [switch]$AlwaysInspectRevision
)
$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
try { $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot -ErrorAction Stop).Path }
catch { [Console]::Error.WriteLine("OUTGOING CHECK FAILED: repository root cannot be resolved: $RepoRoot"); exit 2 }

function Get-GitCandidates {
    $candidates = @()
    if ($env:ProgramFiles) { $candidates += (Join-Path $env:ProgramFiles 'Git\cmd\git.exe') }
    if (${env:ProgramFiles(x86)}) { $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Git\cmd\git.exe') }
    if ($env:LOCALAPPDATA) { $candidates += (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe') }
    return @($candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
}

function Resolve-Git([string]$Explicit) {
    if ($Explicit) {
        if (Test-Path -LiteralPath $Explicit -PathType Leaf) { return (Resolve-Path -LiteralPath $Explicit).Path }
        [Console]::Error.WriteLine("OUTGOING CHECK FAILED: -GitPath '$Explicit' does not name a file.")
        exit 2
    }
    $command = Get-Command git -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command -and $command.Source) { return $command.Source }
    $fallback = @(Get-GitCandidates)
    if ($fallback.Count -gt 0) { return $fallback[0] }
    [Console]::Error.WriteLine('OUTGOING CHECK FAILED: git is unavailable.')
    exit 2
}

$git = Resolve-Git $GitPath
$gitExecutable = $git
$gitPrefixArguments = @()
if ([IO.Path]::GetExtension($git) -ieq '.ps1') {
    # Test and diagnostic stubs are PowerShell scripts, which ProcessStartInfo cannot execute as a
    # native image on Windows. Real use still resolves git.exe; this explicit path keeps -GitPath's
    # existing script-stub contract without involving a shell association.
    $gitExecutable = (Get-Process -Id $PID).Path
    $gitPrefixArguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$git)
}
$utf8 = [Text.UTF8Encoding]::new($false, $true)

function Join-NativeArguments {
    param([Parameter(Mandatory = $true)][string[]]$Values)
    $quoted = foreach ($value in $Values) {
        if ([string]::IsNullOrEmpty($value)) { '""' }
        elseif ($value -notmatch '[\s"]') { $value }
        else { '"' + $value.Replace('"', '\"') + '"' }
    }
    return ($quoted -join ' ')
}

function Invoke-GitBytes {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $gitExecutable
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Arguments = Join-NativeArguments -Values ([string[]](@($gitPrefixArguments) + $Arguments))
    try { $process = [Diagnostics.Process]::Start($start) }
    catch { return [pscustomobject]@{ Exit=$null; Bytes=$null; Error=$_.Exception.Message } }
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $errorText = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        return [pscustomobject]@{ Exit=[int]$process.ExitCode; Bytes=$memory.ToArray(); Error=$errorText }
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Invoke-GitText {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $result = Invoke-GitBytes $Arguments
    if ($null -eq $result.Exit -or $result.Exit -ne 0) { return $result }
    try { $decoded = $utf8.GetString($result.Bytes) }
    catch { return [pscustomobject]@{ Exit=$null; Text=$null; Error="git output is not valid UTF-8: $($_.Exception.Message)" } }
    return [pscustomobject]@{ Exit=0; Text=$decoded; Error=$result.Error }
}

function Stop-CantVerify([string]$Reason) {
    [Console]::Error.WriteLine("CANT-VERIFY: outgoing commits were not checked; $Reason")
    exit 3
}

function Get-Sha256Hex([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '') }
    finally { $sha.Dispose() }
}

$exceptionPath = Join-Path $PSScriptRoot 'outgoing-guard-exceptions.json'
try {
    $exceptionRaw = [IO.File]::ReadAllText($exceptionPath, $utf8)
    $exceptionDocument = $exceptionRaw | ConvertFrom-Json
} catch { Stop-CantVerify "guard exceptions could not be read: $($_.Exception.Message)" }
if ([int]$exceptionDocument.'schema-version' -ne 1 -or $null -eq $exceptionDocument.exceptions) {
    Stop-CantVerify 'guard exceptions have an unsupported or missing schema.'
}
$guardExceptions = @{}
foreach ($entry in @($exceptionDocument.exceptions)) {
    $path = [string]$entry.path
    $sha256 = ([string]$entry.sha256).ToUpperInvariant()
    $reason = [string]$entry.reason
    if ([string]::IsNullOrWhiteSpace($path) -or $path -match '^[\\/]|(^|[\\/])\.\.([\\/]|$)' -or
        $sha256 -notmatch '^[A-F0-9]{64}$' -or [string]::IsNullOrWhiteSpace($reason)) {
        Stop-CantVerify "guard exception is malformed: '$path'."
    }
    $key = "$path|$sha256"
    if ($guardExceptions.ContainsKey($key)) { Stop-CantVerify "duplicate guard exception: '$path' / $sha256." }
    $guardExceptions[$key] = $reason
}

$verified = Invoke-GitText @('-C',$RepoRoot,'rev-parse','--verify',"$Revision^{commit}")
if ($null -eq $verified.Exit -or $verified.Exit -ne 0 -or -not $verified.Text.Trim()) {
    Stop-CantVerify "revision '$Revision' could not be resolved. $($verified.Error.Trim())"
}
$tip = $verified.Text.Trim()

$fetch = Invoke-GitText @('-C',$RepoRoot,'fetch','--quiet','--prune','--no-tags',$Remote)
if ($null -eq $fetch.Exit -or $fetch.Exit -ne 0) {
    Stop-CantVerify "remote '$Remote' could not be refreshed. $($fetch.Error.Trim())"
}
$commits = @()
if ($AlwaysInspectRevision) {
    $commits = @($tip)
} else {
    $range = Invoke-GitText @('-C',$RepoRoot,'rev-list','--reverse','--topo-order',$tip,'--not',"--remotes=$Remote")
    if ($null -eq $range.Exit -or $range.Exit -ne 0) {
        Stop-CantVerify "the commit range relative to '$Remote' could not be enumerated. $($range.Error.Trim())"
    }
    $commits = @($range.Text -split "`r?`n" | Where-Object { $_ })
}
if ($commits.Count -eq 0) {
    Write-Host "OUTGOING CHECK: no commits absent from '$Remote'; nothing to inspect."
    exit 0
}

. (Join-Path $PSScriptRoot '_commit-subject.ps1')
$guard = Join-Path $RepoRoot 'src\core\.claude\hooks\guard.ps1'
if (-not (Test-Path -LiteralPath $guard -PathType Leaf)) {
    Stop-CantVerify "the canonical guard is missing: $guard"
}

function Invoke-Guard([string]$Path, [string]$Content) {
    $event = @{ tool_name='Write'; tool_input=@{ file_path=$Path; content=$Content } } |
        ConvertTo-Json -Compress -Depth 5
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = (Get-Process -Id $PID).Path
    $start.UseShellExecute = $false
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Arguments = Join-NativeArguments -Values @('-NoProfile','-ExecutionPolicy','Bypass','-File',$guard)
    try { $process = [Diagnostics.Process]::Start($start) }
    catch { return [pscustomobject]@{ Exit=$null; Out=''; Err=$_.Exception.Message } }
    try {
        $process.StandardInput.Write($event)
        $process.StandardInput.Close()
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        return [pscustomobject]@{ Exit=[int]$process.ExitCode; Out=$stdout; Err=$stderr }
    } finally { $process.Dispose() }
}

$violations = [Collections.Generic.List[string]]::new()
$checkedBlobs = 0
foreach ($commit in $commits) {
    $subjectResult = Invoke-GitText @('-C',$RepoRoot,'show','-s','--format=%s',$commit)
    if ($null -eq $subjectResult.Exit -or $subjectResult.Exit -ne 0) {
        Stop-CantVerify "subject for commit $commit could not be read. $($subjectResult.Error.Trim())"
    }
    $subject = $subjectResult.Text.TrimEnd("`r","`n")
    $reason = Get-CommitSubjectRejection $subject
    if ($reason) { $violations.Add("commit $commit subject rejected: $reason. Subject: $subject") }

    $parentResult = Invoke-GitText @('-C',$RepoRoot,'rev-list','--parents','-n','1',$commit)
    if ($null -eq $parentResult.Exit -or $parentResult.Exit -ne 0) {
        Stop-CantVerify "parents for commit $commit could not be read. $($parentResult.Error.Trim())"
    }
    $parts = @($parentResult.Text.Trim() -split ' ' | Where-Object { $_ })
    $parents = if ($parts.Count -gt 1) { @($parts[1..($parts.Count - 1)]) } else { @() }
    $paths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $diffs = [Collections.Generic.List[object]]::new()
    if ($parents.Count -eq 0) {
        $diffs.Add([string[]]@('diff-tree','--root','--no-commit-id','--name-only','-r','-z','--no-renames','--diff-filter=ACMR',$commit))
    } else {
        foreach ($parent in $parents) {
            $diffs.Add([string[]]@('diff','--name-only','-z','--no-renames','--diff-filter=ACMR',$parent,$commit,'--'))
        }
    }
    foreach ($argumentSet in $diffs) {
        [string[]]$arguments = $argumentSet
        $changed = Invoke-GitBytes (@('-C',$RepoRoot) + $arguments)
        if ($null -eq $changed.Exit -or $changed.Exit -ne 0) {
            Stop-CantVerify "changed paths for commit $commit could not be read. $($changed.Error.Trim())"
        }
        try { $pathText = $utf8.GetString($changed.Bytes) }
        catch { Stop-CantVerify "changed paths for commit $commit are not valid UTF-8." }
        foreach ($path in @($pathText -split [char]0 | Where-Object { $_ })) { $null = $paths.Add($path) }
    }

    foreach ($path in $paths) {
        $blob = Invoke-GitBytes @('-C',$RepoRoot,'show',"$commit`:$path")
        if ($null -eq $blob.Exit -or $blob.Exit -ne 0) {
            Stop-CantVerify "blob '$path' at commit $commit could not be read. $($blob.Error.Trim())"
        }
        $checkedBlobs++
        if ($path -match '(?i)\.ps1$' -and ($blob.Bytes.Length -lt 3 -or
            $blob.Bytes[0] -ne 0xEF -or $blob.Bytes[1] -ne 0xBB -or $blob.Bytes[2] -ne 0xBF)) {
            $violations.Add("commit $commit contains a PowerShell file without UTF-8 BOM: $path")
        }
        if ($blob.Bytes -contains 0) {
            Write-Host "OUTGOING CHECK: skipped binary blob '$path' at commit $commit."
            continue
        }
        try { $content = $utf8.GetString($blob.Bytes) }
        catch {
            if ($path -match '(?i)\.ps1$') { Stop-CantVerify "PowerShell blob '$path' at commit $commit is not valid UTF-8." }
            Write-Host "OUTGOING CHECK: skipped non-UTF-8 binary blob '$path' at commit $commit."
            continue
        }
        $guardResult = Invoke-Guard $path $content
        if ($null -eq $guardResult.Exit) { Stop-CantVerify "guard launch failed for '$path': $($guardResult.Err.Trim())" }
        if ($guardResult.Exit -ne 0) {
            $digest = Get-Sha256Hex -Bytes $blob.Bytes
            $exceptionKey = "$path|$digest"
            if ($guardExceptions.ContainsKey($exceptionKey)) {
                Write-Host "OUTGOING EXCEPTION: '$path' at $digest — $($guardExceptions[$exceptionKey])"
            } else {
                $detail = @($guardResult.Err.Trim(), $guardResult.Out.Trim() | Where-Object { $_ }) -join ' '
                $violations.Add("commit $commit guard rejected '$path': $detail")
            }
        }
    }
}

if ($violations.Count -gt 0) {
    foreach ($violation in $violations) { [Console]::Error.WriteLine("PUSH REFUSED: $violation") }
    exit 1
}
Write-Host "OUTGOING CHECK: $($commits.Count) commit(s), $checkedBlobs changed blob(s), all clean."
exit 0
