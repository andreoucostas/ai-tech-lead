#requires -version 5.1
<#
Mechanically verifies that a commit's declared test case(s) failed on the commit's PARENT tree and
pass on the commit itself -- the "observed red before trusted green" evidence Maintenance model #4
asks a reviewer to personally record. Read-only against real git history: only `rev-parse`, `log`,
`ls-tree` and `clone` touch the CALLER's repository, and `clone`/`checkout` only ever run against an
isolated temp clone created and destroyed here. The caller's working tree, index and worktree list
are never touched.

Declared cases come from repeatable -Case '<repo-relative file>::<exact case name>' arguments, or
(when -Case is absent) from `Red-first: <file>::<name>` trailers in the commit message -- Case is an
explicit alternative, never merged with trailers.

Verdict is read ONLY from the harness's own per-case `[ok]/[FAIL]/[skip] <name>` lines (see
.claude/hooks/tests/_HookHarness.ps1), never from a wrapper's exit code (that is a failing-case COUNT,
not a verdict -- Maintenance model #4/#7's exit-domain-collision shape).

Exit codes:
  0  PASS            every declared case is [FAIL] on the parent and [ok] on the commit.
  1  WRONG           the artifact is examinable but at least one declared case did not behave that
                      way (inert on the parent, or still failing on the commit).
  2  CANNOT_EXAMINE  the check could not be run to a verdict at all (see the printed reason).

Final stdout line, always printed exactly once:
  RED_FIRST <PASS|WRONG|CANNOT_EXAMINE> declared=<n> red_on_parent=<m> green_on_commit=<k>
#>
[CmdletBinding()]
param(
    [string]$Commit = 'HEAD',
    [string]$RepoRoot,
    [string[]]$Case
)
$ErrorActionPreference = 'Stop'
# PS 7.4+ defaults $PSNativeCommandUseErrorActionPreference to $true, which would make a non-zero
# git exit throw instead of just setting $LASTEXITCODE -- git failing (bad commit, no parent, ...)
# is an ordinary CHECKED condition here, not an unexpected error. PS5.1 has no such variable;
# setting it is then a harmless no-op, so behaviour stays identical on both hosts.
$PSNativeCommandUseErrorActionPreference = $false

$script:declaredCount  = 0
$script:redOnParent    = 0
$script:greenOnCommit  = 0
$script:verdict        = $null
$script:verdictDetail  = $null
$script:cloneRoot      = $null

function New-Halt([string]$Verdict, [string]$Detail) {
    $script:verdict = $Verdict
    $script:verdictDetail = $Detail
    throw [System.Management.Automation.RuntimeException]::new('__RED_FIRST_HALT__')
}
function Stop-CannotExamine([string]$Message) { New-Halt 'CANNOT_EXAMINE' $Message }

function Invoke-Git {
    param([Parameter(Mandatory)][string[]]$GitArgs)
    # Windows PowerShell wraps a redirected native child's stderr lines into ErrorRecords as they
    # arrive, even when merged with 2>&1; under the script-wide $ErrorActionPreference='Stop' that
    # promotes an ORDINARY git failure (bad revision, no parent, ...) into a terminating exception
    # here instead of the checked, non-zero $LASTEXITCODE this function's callers expect. git's exit
    # code is the real signal; drop to 'Continue' only around the call itself.
    $savedEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $out = & git @GitArgs 2>&1
        return [pscustomobject]@{ Exit = [int]$LASTEXITCODE; Out = (($out | Out-String)) }
    } finally { $ErrorActionPreference = $savedEap }
}

function Get-DirEntries {
    param([string]$RepoPath, [string]$Rev, [string]$Dir)
    $r = Invoke-Git @('-C', $RepoPath, 'ls-tree', '-r', '--name-only', $Rev, '--', $Dir)
    if ($r.Exit -ne 0) { Stop-CannotExamine "could not list '$Dir' at $Rev in '$RepoPath': $($r.Out.Trim())" }
    return @(($r.Out -split "\r?\n") | Where-Object { $_ })
}

function Resolve-Mark {
    param([string]$Text, [string]$Name)
    if ($null -eq $Text) { return [System.Text.RegularExpressions.MatchCollection]$null }
    $escaped = [regex]::Escape($Name)
    $pattern = "(?m)^\[(ok|FAIL|skip)\] $escaped(?: -- .*)?`$"
    return [regex]::Matches($Text, $pattern)
}

$exitCode = 2
try {
    if (-not $RepoRoot) {
        $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    } else {
        $RepoRoot = (Resolve-Path $RepoRoot).Path
    }

    $topLevel = Invoke-Git @('-C', $RepoRoot, 'rev-parse', '--show-toplevel')
    if ($topLevel.Exit -ne 0) { Stop-CannotExamine "RepoRoot '$RepoRoot' is not a git repository: $($topLevel.Out.Trim())" }

    $commitRes = Invoke-Git @('-C', $RepoRoot, 'rev-parse', $Commit)
    if ($commitRes.Exit -ne 0) { Stop-CannotExamine "commit '$Commit' does not resolve in '$RepoRoot': $($commitRes.Out.Trim())" }
    $sha = $commitRes.Out.Trim()

    $parentRes = Invoke-Git @('-C', $RepoRoot, 'rev-parse', "$sha^")
    if ($parentRes.Exit -ne 0) { Stop-CannotExamine "commit $sha has no resolvable parent (root commit or shallow clone) -- cannot examine" }
    $parentSha = $parentRes.Out.Trim()

    # ---- declared cases -----------------------------------------------------------------------
    $declared = New-Object System.Collections.Generic.List[object]
    if ($Case -and @($Case).Count -gt 0) {
        foreach ($c in $Case) {
            $idx = $c.IndexOf('::')
            if ($idx -lt 0) { Stop-CannotExamine "malformed -Case value (expected '<file>::<name>'): '$c'" }
            $file = $c.Substring(0, $idx).Trim()
            $name = $c.Substring($idx + 2).Trim()
            if (-not $file -or -not $name) { Stop-CannotExamine "malformed -Case value (empty file or name): '$c'" }
            $declared.Add([pscustomobject]@{ File = $file; Name = $name })
        }
    } else {
        $msgRes = Invoke-Git @('-C', $RepoRoot, 'log', '-1', '--format=%B', $sha)
        if ($msgRes.Exit -ne 0) { Stop-CannotExamine "could not read the commit message for $sha" }
        $lines = ($msgRes.Out -split "\r?\n")
        foreach ($rawLine in $lines) {
            $t = $rawLine.Trim()
            if (-not $t) { continue }
            # A trailer ATTEMPT is a line that starts with the word "red-first" -- not merely a line
            # that mentions it in prose. A bare substring trigger refused this very script's own
            # commit subject ("...mechanical red-first check...") and every ordinary mention of
            # assert-red-first.ps1 (which itself contains "red-first"), found by dogfooding this
            # script against its own shipping commit.
            if ($t -notmatch '(?i)^red-first\b') { continue }
            if ($t -notmatch '(?i)^red-first\s*:\s*(?<rest>.+)$') {
                Stop-CannotExamine "unparsable Red-first trailer line (starts with 'red-first' but not 'Red-first: <file>::<name>'): '$t'"
            }
            $rest = $Matches['rest'].Trim()
            $sepIdx = $rest.IndexOf('::')
            if ($sepIdx -lt 0) { Stop-CannotExamine "unparsable Red-first trailer line (no '::' separator): '$t'" }
            $file = $rest.Substring(0, $sepIdx).Trim()
            $name = $rest.Substring($sepIdx + 2).Trim()
            if (-not $file -or -not $name) { Stop-CannotExamine "unparsable Red-first trailer line (empty file or name): '$t'" }
            $declared.Add([pscustomobject]@{ File = $file; Name = $name })
        }
        if ($declared.Count -eq 0) { Stop-CannotExamine "no Red-first trailers and no -Case given -- cannot examine" }
    }
    $script:declaredCount = $declared.Count
    $uniqueFiles = @($declared.File | Select-Object -Unique)
    $byDir = $uniqueFiles | Group-Object -Property { (Split-Path -Parent $_).Replace('\', '/') }

    # ---- isolated clone (O3): tests shell out to git against their own computed $repoRoot, so a
    # bare `git archive` export (no .git) would make roughly half the meta suite fail for the wrong
    # reason. Only this temp clone is ever checked out; the caller's repo is read-only throughout. --
    $cloneRoot = Join-Path ([IO.Path]::GetTempPath()) ('assert-red-first-' + [guid]::NewGuid().ToString('N'))
    $hostExe = (Get-Process -Id $PID).Path

    $script:cloneRoot = $cloneRoot
    $cloneRes = Invoke-Git @('clone', '--no-hardlinks', '--quiet', '--', $RepoRoot, $cloneRoot)
    if ($cloneRes.Exit -ne 0) { Stop-CannotExamine "could not create an isolated clone of '$RepoRoot': $($cloneRes.Out.Trim())" }

    function Set-ClonedCommit {
        param([string]$Rev)
        $r = Invoke-Git @('-C', $cloneRoot, 'checkout', '--detach', '--force', '--quiet', $Rev)
        if ($r.Exit -ne 0) { Stop-CannotExamine "could not check out $Rev in the isolated clone: $($r.Out.Trim())" }
    }

    function Invoke-DeclaredFile {
        param([string]$RelPath)
        $full = Join-Path $cloneRoot $RelPath
        if (-not (Test-Path -LiteralPath $full)) { return $null }
        $errFile = [IO.Path]::GetTempFileName()
        # Windows PowerShell wraps a native child's stderr LINES into ErrorRecords as they are
        # redirected; under $ErrorActionPreference='Stop' (set globally above) that promotes them to
        # a terminating error in THIS process, even though the child's own exit code is the real
        # verdict here. Drop to 'Continue' for just this call so a case's parent-side stderr chatter
        # (e.g. a top-level dot-source failing because the feature file is genuinely absent there)
        # lands in $errFile as text, exactly as intended, instead of aborting the checker itself.
        $savedEap = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $out = & $hostExe -NoProfile -ExecutionPolicy Bypass -File $full 2>$errFile
            $text = (($out | Out-String)) + "`n" + [IO.File]::ReadAllText($errFile)
            # Normalise to LF: Out-String/console capture on Windows joins lines with CRLF, and the
            # `(?m)^...$` anchors below match `$` right before `\n` -- a stray `\r` there would sit
            # between the case name and the anchor and silently defeat every exact-line match.
            return $text.Replace("`r`n", "`n")
        } finally {
            $ErrorActionPreference = $savedEap
            Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
        }
    }

    # ---- parent side: check out the parent, then overlay each declared directory with the
    # commit's version of it (adds/updates every path the commit carries there, removes every path
    # the parent had there that the commit no longer has) -- everything OUTSIDE a declared
    # directory stays exactly at the parent's state. --------------------------------------------
    Set-ClonedCommit $parentSha
    foreach ($grp in $byDir) {
        $dir = $grp.Name
        $ov = Invoke-Git @('-C', $cloneRoot, 'checkout', $sha, '--', $dir)
        if ($ov.Exit -ne 0) { Stop-CannotExamine "could not overlay '$dir' from $sha onto the parent checkout: $($ov.Out.Trim())" }
        $parentEntries = Get-DirEntries -RepoPath $RepoRoot -Rev $parentSha -Dir $dir
        $commitEntries = Get-DirEntries -RepoPath $RepoRoot -Rev $sha -Dir $dir
        foreach ($rel in @($parentEntries | Where-Object { $commitEntries -cnotcontains $_ })) {
            $p = Join-Path $cloneRoot $rel
            if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }
        }
    }
    $parentOutputs = @{}
    foreach ($file in $uniqueFiles) {
        $parentOutputs[$file] = Invoke-DeclaredFile $file
        if ($null -eq $parentOutputs[$file]) { Stop-CannotExamine "declared test file '$file' is absent from the parent checkout (after overlay)" }
    }

    # ---- commit side ----------------------------------------------------------------------------
    Set-ClonedCommit $sha
    $commitOutputs = @{}
    foreach ($file in $uniqueFiles) {
        $commitOutputs[$file] = Invoke-DeclaredFile $file
        if ($null -eq $commitOutputs[$file]) { Stop-CannotExamine "declared test file '$file' is absent from the commit checkout" }
    }

    # ---- liveness control (R3b): a declared case's [FAIL] on the parent must mean the FEATURE is
    # absent, not that the whole file/harness is broken there for an unrelated reason. Require at
    # least one NON-declared case to be [ok] on the parent, in the same file. -------------------
    foreach ($file in $uniqueFiles) {
        $namesForFile = @($declared | Where-Object { $_.File -eq $file } | ForEach-Object { $_.Name })
        $okNames = @([regex]::Matches($parentOutputs[$file], '(?m)^\[ok\] (.+)$') | ForEach-Object { $_.Groups[1].Value })
        $liveNonDeclared = @($okNames | Where-Object { $namesForFile -cnotcontains $_ })
        if (@($liveNonDeclared).Count -eq 0) {
            Stop-CannotExamine "no live non-declared case is [ok] on the parent for '$file' -- cannot examine (the file may be broken there for an unrelated reason, or every case in it is declared)"
        }
    }

    # ---- exact-match resolution (R1): match the FULL declared name as a literal, anchored line --
    # not a split on ' -- ', which truncates any name that itself contains ' -- ' (four real cases
    # in this repo's own suites do). Requires EXACTLY one match per tree; zero or several -> refuse.
    $offenders = New-Object System.Collections.Generic.List[string]
    $parentLines = New-Object System.Collections.Generic.List[string]
    foreach ($d in $declared) {
        $pm = Resolve-Mark $parentOutputs[$d.File] $d.Name
        $cm = Resolve-Mark $commitOutputs[$d.File] $d.Name
        if ($pm.Count -eq 0) { Stop-CannotExamine "declared case '$($d.Name)' not found in $($d.File) on the parent" }
        if ($pm.Count -gt 1) { Stop-CannotExamine "declared case '$($d.Name)' matched $($pm.Count) lines in $($d.File) on the parent -- ambiguous (duplicate case name?)" }
        if ($cm.Count -eq 0) { Stop-CannotExamine "declared case '$($d.Name)' not found in $($d.File) on the commit" }
        if ($cm.Count -gt 1) { Stop-CannotExamine "declared case '$($d.Name)' matched $($cm.Count) lines in $($d.File) on the commit -- ambiguous (duplicate case name?)" }
        $pMark = $pm[0].Groups[1].Value
        $cMark = $cm[0].Groups[1].Value
        $parentLines.Add($pm[0].Value)
        if ($pMark -eq 'skip') { Stop-CannotExamine "declared case '$($d.Name)' was skipped on the parent -- cannot examine" }
        if ($cMark -eq 'skip') { Stop-CannotExamine "declared case '$($d.Name)' was skipped on the commit -- cannot examine" }
        if ($pMark -eq 'FAIL') { $script:redOnParent++ } else { $offenders.Add("'$($d.Name)' passed on the parent (inert, not red-first)") }
        if ($cMark -eq 'ok') { $script:greenOnCommit++ } else { $offenders.Add("'$($d.Name)' did not pass on the commit") }
    }

    Write-Host '-- parent-side result for each declared case (R3a: printed even on PASS) --'
    foreach ($l in $parentLines) { Write-Host $l }

    if ($offenders.Count -eq 0) {
        $script:verdict = 'PASS'
    } else {
        $script:verdict = 'WRONG'
        $script:verdictDetail = ($offenders -join '; ')
    }
} catch {
    if ($_.Exception.Message -ne '__RED_FIRST_HALT__') {
        $script:verdict = 'CANNOT_EXAMINE'
        $script:verdictDetail = "unexpected error: $($_.Exception.Message)"
    }
} finally {
    if ($script:cloneRoot -and (Test-Path -LiteralPath $script:cloneRoot)) {
        Remove-Item -LiteralPath $script:cloneRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Printed on stdout, not stderr: Windows PowerShell wraps a redirected NATIVE child's stderr lines
# into ErrorRecords and, depending on the caller's own $ErrorActionPreference, may both write them
# to the redirection target AND still surface a formatted copy -- a caller capturing this script's
# own stderr could see a garbled/duplicated message. The exit code plus this stdout line are the
# real contract; keep the diagnostic text on the stream every host reports identically.
switch ($script:verdict) {
    'PASS'  { $exitCode = 0 }
    'WRONG' { Write-Host "WRONG: $script:verdictDetail"; $exitCode = 1 }
    default { Write-Host "CANNOT_EXAMINE: $script:verdictDetail"; $exitCode = 2 }
}
Write-Host ("RED_FIRST {0} declared={1} red_on_parent={2} green_on_commit={3}" -f $script:verdict, $script:declaredCount, $script:redOnParent, $script:greenOnCommit)
exit $exitCode
