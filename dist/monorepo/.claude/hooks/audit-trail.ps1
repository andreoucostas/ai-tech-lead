# PostToolUse hook — append local, mutable telemetry for supported hooked editor/file-write events.
# Format: ISO-8601-UTC TAB git-branch TAB file-path
# Shell/external writes and unavailable hooks are blind spots; this is not compliance evidence.
# Tool surfaces handled:
#   Claude Code (CLI + VS Code extension)  — tool_name in {Write,Edit}; path at tool_input.file_path
#   GitHub Copilot CLI (dated evidence)    — toolName in {edit,create}; path at toolArgs.filePath
#   Copilot VS Code Preview hooks          — path + content payload; org policy may disable hooks
#   apply_patch (GPT models on Copilot)    — one line per file its patch names, read by guard.ps1's split

$ErrorActionPreference = 'SilentlyContinue'

$inputJson = [Console]::In.ReadToEnd()
$filePath = ''
$patchPaths = @()

if (-not [string]::IsNullOrEmpty($inputJson)) {
    try {
        $obj = $inputJson | ConvertFrom-Json
        $tn = if ($obj.tool_name) { [string]$obj.tool_name } elseif ($obj.toolName) { [string]$obj.toolName } else { '' }

        # Claude Code: tool_input.file_path
        if ($obj.tool_input) {
            if ($obj.tool_input.file_path) { $filePath = [string]$obj.tool_input.file_path }
            elseif ($obj.tool_input.filePath) { $filePath = [string]$obj.tool_input.filePath }
        }
        # Copilot: toolArgs is a parsed object (per spec). Try object access first, fall back to
        # string parse for older payload shapes.
        $ta = $obj.toolArgs
        if ($ta -is [string]) { try { $ta = $ta | ConvertFrom-Json } catch { $ta = $null } }
        if ([string]::IsNullOrEmpty($filePath) -and $ta) {
            if ($ta.filePath) { $filePath = [string]$ta.filePath }
            elseif ($ta.file_path) { $filePath = [string]$ta.file_path }
            elseif ($ta.path) { $filePath = [string]$ta.path }
        }

        # Self-filter — Copilot's hooks.json has no matcher, so gate here. Mirror guard.*: accept
        # known write tools (Claude Write/Edit, Copilot CLI edit/create) OR any tool carrying a file
        # path + content. The path+content arm covers VS Code agent mode's camelCase write tools
        # (str_replace/insert/create), which can't be enumerated — without it the audit log silently
        # under-records that surface; requiring content (not just a path) keeps read-style tools out.
        $contentParts = @($obj.tool_input.content, $obj.tool_input.new_string, $obj.tool_input.newString,
                          $obj.tool_input.file_text, $obj.tool_input.new_str, $obj.tool_input.text,
                          $ta.content, $ta.new_string, $ta.newString, $ta.file_text, $ta.new_str, $ta.text) |
                         Where-Object { $_ }
        # apply_patch, the file tool GPT models use on Copilot, sends one V4A patch string instead of a
        # path and content: as toolArgs (.github/hooks/hooks.json, toolName apply_patch) or tool_input
        # (.claude/settings.json, tool_name Edit), or as the `input` of either. Its paths -- each
        # section's, and its new one when it moves -- come from guard.ps1's own section split, loaded
        # from that file, so this hook and the guard never read one patch differently.
        $patchText = $null
        foreach ($v in @($ta.input, $obj.tool_input.input, $ta, $obj.tool_input)) { if ($v -is [string]) { $patchText = $v; break } }
        if ($null -eq $patchText -and $obj.toolArgs -is [string] -and $null -eq $ta) { $patchText = $obj.toolArgs }
        if ($tn -eq 'apply_patch' -or (-not ($filePath -or $contentParts) -and $patchText -match '\*\*\* (?:Add|Update|Delete) File:')) {
            $guardAst = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'guard.ps1'), [ref]$null, [ref]$null)
            $split = $guardAst.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-PatchSections' }, $true)
            . ([scriptblock]::Create($split.Extent.Text))
            $patchPaths = @(foreach ($section in (Get-PatchSections ([string]$patchText) ([int]::MaxValue))) { $section.Paths })
        }
        $knownWrite = (@('Write','Edit','edit','create') -contains $tn) -or ($tn -eq '')
        if (-not ($knownWrite -or ($filePath -and $contentParts) -or $patchPaths)) { exit 0 }
    } catch { }
}

if ([string]::IsNullOrEmpty($filePath) -and $patchPaths.Count -eq 0 -and $env:CLAUDE_FILE_PATH) {
    $filePath = $env:CLAUDE_FILE_PATH
}

$filePaths = @(@($filePath) + $patchPaths | Where-Object { $_ })
if ($filePaths.Count -eq 0) { exit 0 }

# The repository is the folder that holds this hook's .claude\hooks folder, found from the hook's own
# path as route-prompt.ps1 finds it. PowerShell's location need not be the repository (in a sandbox on a
# host without filesystem enumeration it may be the drive root), so the log, the branch and each
# repository-relative path are taken from $repoRoot, and a relative written path is read as the repository's.
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))

$branch = git -C $repoRoot rev-parse --abbrev-ref HEAD 2>$null
if (-not $branch) { $branch = 'unknown' }

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture)

# Parallel tool calls fire this hook together. Out-File -Append opens the log in a share mode a second appender
# cannot join, and under SilentlyContinue the loser dropped its line without a word. The log is opened for append
# with other processes allowed only to read it, so one appender at a time holds it; a busy log is retried for up to
# 3 s (Copilot gives the hook 10 s), then the line is given up with one stderr line and the exit stays 0. The line is
# UTF-8 without a BOM and ends in CRLF, as Out-File wrote it on PowerShell 7.
$logPath = Join-Path $repoRoot '.claude\ai-audit.log'
$utf8NoBom = [Text.UTF8Encoding]::new($false)
function Add-AuditLine([string]$Line) {
    $bytes = $utf8NoBom.GetBytes($Line + "`r`n")
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $reason = ''
    do {
        $stream = $null
        try {
            $stream = [IO.FileStream]::new($logPath, [IO.FileMode]::Append, [IO.FileAccess]::Write, [IO.FileShare]::Read)
            $stream.Write($bytes, 0, $bytes.Length)
            return
        } catch {
            $reason = $_.Exception.GetType().Name
            if ($_.Exception -is [IO.DirectoryNotFoundException]) { break }
        } finally { if ($stream) { $stream.Dispose() } }
        Start-Sleep -Milliseconds (Get-Random -Minimum 10 -Maximum 50)
    } while ($clock.ElapsedMilliseconds -lt 3000)
    [Console]::Error.WriteLine("audit-trail: a line was not written to .claude\ai-audit.log ($reason)")
}

# One line per path; a skipped path (the stack's skip line, which ends in `continue`) drops only its own.
foreach ($filePath in $filePaths) {
    # Normalise to a repo-relative path so the local log stays portable and does not leak
    # local absolute paths (usernames, drive layout). It is what Resolve-Path -Relative writes from
    # the repository root: the same normalisation against $repoRoot, then its .\ prefix.
    # Note: $ErrorActionPreference is SilentlyContinue, under which Resolve-Path on a missing
    # path returns $null *without throwing* — force a terminating error and guard the result
    # so a non-existent/cross-drive path records a constant sentinel rather than leaking the original.
    $rel = '[path-normalisation-failed]'
    try {
        $full = $filePath
        if (-not [IO.Path]::IsPathRooted($full)) { $full = Join-Path $repoRoot $full }
        $r = $ExecutionContext.SessionState.Path.NormalizeRelativePath((Resolve-Path -LiteralPath $full -ErrorAction Stop).Path, $repoRoot)
        if (-not $r.StartsWith('.') -and -not [IO.Path]::IsPathRooted($r)) { $r = '.\' + $r }
        if ($r) {
            $candidate = [string]$r
            $portable = $candidate.Replace('\', '/')
            if ($portable -ne '..' -and -not $portable.StartsWith('../') -and -not [IO.Path]::IsPathRooted($candidate)) {
                $rel = $candidate
            }
        }
    } catch { $rel = '[path-normalisation-failed]' }

    # The stack's skip line tests the repository-relative path, so a repository whose own folder is named like a
    # skipped one (bin, dist, ...) still records; a path that could not be made relative is tested as written. The
    # skip patterns want a separator before the folder name, which a top-level `.angular\...` lacks, so one is added.
    $skipSubject = if ($rel -ceq '[path-normalisation-failed]') { $filePath } else { '\' + $rel }
    if ($skipSubject -match 'ai-audit\.log|[\\/]obj[\\/]|[\\/]bin[\\/]') { continue }
    if ($skipSubject -match 'ai-audit\.log|[\\/]node_modules[\\/]|[\\/]dist[\\/]|[\\/]\.angular[\\/]|[\\/]coverage[\\/]') { continue }

    Add-AuditLine "$timestamp`t$branch`t$rel"
}

exit 0
