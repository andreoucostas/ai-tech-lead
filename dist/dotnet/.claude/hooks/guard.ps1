# PreToolUse guard — inspect writes for warning-suppressions, hardcoded secrets, or test-defeats and emit a block response.
# Implements deterministic checks for the framework rules (`.github/instructions/framework-rules.instructions.md` › Verification Rules) #5/#7 and the no-secrets rule.
# Claude-shaped writes emit exit 2 plus a reason on stderr. Other write shapes emit a documented
# Copilot-compatible permissionDecision JSON deny on stdout (exit 0). Whether a client fires this
# hook or honors its output is capability-specific; see docs/enforcement-surfaces.md.
# Allow = exit 0. Degrades safe on parse failure (except high-confidence secrets, which fail closed,
# and an apply_patch call the guard cannot read, which it blocks).
# Scope: the scanned text is the write payload -- a whole file's content, an edit's replacement
# text, or the lines a patch adds to each file -- never the file that edit produces. A value whose
# key sits in the surrounding line, and a secret split across two edits, are therefore not seen.
# Stated as a limit in docs/enforcement-surfaces.md rather than fixed: scanning the pre-edit file
# alongside the new text refuses the edit that REMOVES a leaked key, and reconstructing the
# post-edit file needs edit semantics this hook cannot know for the file-write tools it accepts by
# shape alone. The one exception is a suppression or a skipped test: it is compared with the text the
# write replaces (an edit's old text, the lines a patch section removes, the file on disk under a whole-file
# write). A directive is the matched text plus the rest of its line, up to a closing */ and trimmed
# (disable CS0618, CS8602 / eslint-disable @angular-eslint/component-selector); one inside a block comment (a /*
# before it within 8 lines with no */ between) runs to the */ or to the end of a window of 8 lines, 1 KB a line.
# The write is blocked when any such text occurs more often in what it writes than in what it replaces, or, when it
# still holds a #pragma warning disable or a block eslint-disable (not -line or -next-line), when it leaves more of
# them unclosed than that text did: a write that keeps a disable but drops the restore or eslint-enable closing it
# is blocked. A directive kept or moved unchanged passes; one added, or widened (@ts-ignore to @ts-nocheck,
# disable CS0618 to a bare disable, a rule or a rule list changed, xit to xdescribe), does not. Stated limits: an
# unchanged directive moved to other code (an [Ignore] from a method to its class) or across the hunks of one patch
# section, a commented-out one un-commented, rules added past the first 8 lines or 1 KB of a line of a comment that
# does not close within them, rules written after a */ in a line comment, a write that only removes a closer, a closer moved to later code, any text that
# matches a closer pattern (a string included) counting as a closer, and, because the key runs to the end of the
# line, an edit to the code after a directive on the same line counting as a new directive. Old text the guard
# cannot get counts as none, so the write is read as it always was.
# Team waiver: a path listed in .claude/guard-allowlist.txt skips the secret and credential checks only, when every path
# field of the event is listed; every agent write to that list through any of them, an empty edit and a deletion
# included, is blocked (see Test-AllowlistTarget).
# Hook wiring: every agent write to a hook script (.claude/hooks/*.ps1) or the Copilot hook file (.github/hooks/hooks.json), in
# any folder, is blocked, an empty write, a deletion, a move, an 8.3 short name and a folder's stream spelling included; so is a write to
# .claude/settings.json or .claude/settings.local.json whose resulting file drops or changes a PreToolUse entry naming guard.ps1
# that the file holds now (its group's matcher included) or newly sets "disableAllHooks": true, and one whose resulting file
# the guard cannot work out (see Test-SettingsWrite). A shell command is not read, as for every rule here.
$ErrorActionPreference = 'SilentlyContinue'
# Case-insensitive patterns fold case culture-invariantly ($ci) and string comparisons are ordinal:
# under tr-TR the current culture folds 'I' to a dotless i (U+0131), so a culture-following (?i)
# api[_-]?key missed API_KEY and let its literal through. -match and inline (?i) follow the culture. The invariant
# fold does not equate i with what tr-TR makes of it, a dotted capital I (U+0130) upper-cased or a dotless i (U+0131)
# lower-cased, so a credential key name spells each i as [i\u0130\u0131].
$ci = [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::CultureInvariant
$ordinal = [StringComparison]::Ordinal
$ordinalIgnoreCase = [StringComparison]::OrdinalIgnoreCase

# The agents send UTF-8. [Console]::In decodes with the console's input code page (437, 850, 1252), which turns
# a non-ASCII path or a no-break space in the text into other characters, so the stream is read as UTF-8 here
# (not by setting [Console]::InputEncoding, which would change the user's console).
$stdin = New-Object IO.StreamReader([Console]::OpenStandardInput(), (New-Object Text.UTF8Encoding($false)))
$raw = $stdin.ReadToEnd()
if (-not $raw) { exit 0 }
# What a tool call that will not parse is classified by (below). A call is a write when it would be one if it were read
# normally: a write tool's name (str_replace_editor only through the commands that write), a field that carries the
# text a write puts in a file, a `text` field beside a path, or a patch. A bare path is not a write (a view carries one).
# Names compare ignoring case, ordinally, by set lookup: a call can hold tens of thousands of keys.
function New-NameSet([string[]]$Names) {
    $set = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($n in $Names) { [void]$set.Add($n) }
    return ,$set
}
$guardWriteTools = New-NameSet @('Write', 'Edit', 'create', 'MultiEdit', 'NotebookEdit', 'str_replace', 'insert', 'apply_patch')
$guardPathKeys = New-NameSet @('file_path', 'filePath', 'path', 'notebook_path')
$guardContentKeys = New-NameSet @('content', 'new_string', 'newString', 'file_text', 'new_str', 'new_source', 'edits', 'old_string', 'oldString', 'old_str', 'replacements')
$guardEditorCommands = New-NameSet @('create', 'str_replace', 'insert', 'undo_edit')
$guardToolKeys = New-NameSet @('tool_name', 'toolName')
$guardInsertTools = New-NameSet @('insert_edit_into_file', 'copilot_insertEdit', 'insertEdit')
$guardArgKeys = New-NameSet @('tool_input', 'toolArgs')
$guardPatchLike = '\*\*\* (?:Add|Update|Delete) File:'
# Whether a call's arguments (a table parsed with -AsHashtable, or a string that is one as JSON text or else a patch)
# make it a write. $Editor: the tool is str_replace_editor; $InsertTool: it is insert_edit_into_file, whose `code` beside a path
# is its text (any other tool's `code` counts only beside an `explanation` field).
function Test-WriteArgs($ArgsValue, [bool]$Editor, [bool]$InsertTool = $false) {
    if ($ArgsValue -is [string]) {
        $inner = $null
        try { $inner = ConvertFrom-Json -InputObject $ArgsValue -AsHashtable -ErrorAction Stop } catch { }
        if ($inner -isnot [System.Collections.IDictionary]) { return [regex]::IsMatch($ArgsValue, $guardPatchLike, $ci) }
        $ArgsValue = $inner
    }
    if ($ArgsValue -isnot [System.Collections.IDictionary]) { return $false }
    $hasPath = $false; $hasText = $false; $hasCode = $false; $hasNewCode = $false; $hasExplanation = $false; $patchInput = $false
    foreach ($k in @($ArgsValue.Keys)) {
        $key = [string]$k
        if ($guardContentKeys.Contains($key)) { return $true }
        if ($guardPathKeys.Contains($key)) { $hasPath = $true }
        elseif ([string]::Equals($key, 'text', $ordinalIgnoreCase)) { $hasText = $true }
        elseif ([string]::Equals($key, 'code', $ordinalIgnoreCase)) { $hasCode = $true }
        elseif ([string]::Equals($key, 'newCode', $ordinalIgnoreCase)) { $hasNewCode = $true }
        elseif ([string]::Equals($key, 'explanation', $ordinalIgnoreCase)) { $hasExplanation = $true }
        elseif ($Editor -and [string]::Equals($key, 'command', $ordinalIgnoreCase) -and $guardEditorCommands.Contains([string]$ArgsValue[$k])) { return $true }
        elseif ([string]::Equals($key, 'input', $ordinalIgnoreCase) -and $ArgsValue[$k] -is [string] -and [regex]::IsMatch($ArgsValue[$k], $guardPatchLike, $ci)) { $patchInput = $true }
    }
    return (($hasText -or $hasNewCode -or ($hasCode -and ($hasExplanation -or $InsertTool))) -and $hasPath) -or ($patchInput -and -not $hasPath)
}
# ConvertFrom-Json refuses JSON whose keys differ only in case, or that has an empty key, and a call it cannot parse
# would be let through unread. Such a call is re-read with -AsHashtable, only to classify it: the tool name it names (the
# first write tool's, else the first name) and whether it is a write. $null when it cannot be read that way either, or is
# no write.
function Get-UnreadableCall([string]$Json) {
    $table = $null
    try { $table = ConvertFrom-Json -InputObject $Json -AsHashtable -ErrorAction Stop } catch { return $null }
    if ($table -isnot [System.Collections.IDictionary]) { return $null }
    $names = @(); $write = $false; $editor = $false; $hasInput = $false; $inputs = @()
    foreach ($k in @($table.Keys)) {
        $v = $table[$k]
        if ($guardToolKeys.Contains([string]$k)) {
            if ($v -is [string]) {
                $names += $v
                if ($guardWriteTools.Contains($v)) { $write = $true }
                if ([string]::Equals($v, 'str_replace_editor', $ordinalIgnoreCase)) { $editor = $true }
            }
        } elseif ($guardArgKeys.Contains([string]$k)) { $hasInput = $true; $inputs += , $v }
    }
    $name = @($names | Where-Object { $guardWriteTools.Contains($_) })[0]
    if ($null -eq $name) { $name = $names[0] }
    foreach ($v in $inputs) { if (-not $write -and (Test-WriteArgs $v $editor ($name -is [string] -and $guardInsertTools.Contains($name)))) { $write = $true } }
    if (-not $write) { return $null }
    if ($null -eq $name -and $hasInput) { $name = '' }
    return [pscustomobject]@{ Tool = $name }
}
$unreadableMessage = 'Blocked write: the write guard cannot read this tool call (its JSON repeats a key in a different letter case, or has an empty key), so it checked none of it. Resend the call without duplicate or empty keys.'
$unreadable = $false
try { $d = $raw | ConvertFrom-Json } catch {
    $call = Get-UnreadableCall $raw
    if ($null -eq $call) { exit 0 }
    $unreadable = $true
    $d = [pscustomobject]@{ tool_name = $call.Tool }
}

$tool = $d.tool_name; if (-not $tool) { $tool = $d.toolName }
$emptyTool = $tool -is [string] -and $tool.Length -eq 0   # a missing ($null) tool name is not the empty one
$ti = $d.tool_input
$ta = $d.toolArgs
$taText = $ta
if ($ta -is [string]) {
    try { $ta = $ta | ConvertFrom-Json } catch {
        $ta = $null
        # An object that will not parse as one is unreadable; a string that is no JSON object is a patch, read below.
        $inner = $null
        try { $inner = ConvertFrom-Json -InputObject $taText -AsHashtable -ErrorAction Stop } catch { }
        if ($inner -is [System.Collections.IDictionary] -and (($tool -is [string] -and $guardWriteTools.Contains($tool)) -or (Test-WriteArgs $inner ([string]::Equals([string]$tool, 'str_replace_editor', $ordinalIgnoreCase)) ($tool -is [string] -and $guardInsertTools.Contains($tool))))) { $unreadable = $true }
    }
}

# Field names vary by surface: Claude (file_path/content/new_string), Copilot CLI (filePath/
# newString), and VS Code agent mode's text-editor tools (path + file_text on `create`, new_str
# on `str_replace`/`insert`) -- Task 0 confirmed the VS Code shapes, so they are covered here.
# Claude Code's NotebookEdit (2.1.312) sends notebook_path and the cell's new_source; a delete
# writes no source, so its new_source is not read.
$fp = $null
foreach ($v in @($ti.file_path, $ti.filePath, $ti.path, $ti.notebook_path, $ta.filePath, $ta.file_path, $ta.path)) { if ($v) { $fp = $v; break } }
# Every path the event names, in any of those fields on either object: a tool may write the one the guard did not pick
# for $fp, so each is checked as a write to the guard allowlist, and the allowlist waives the event only when it lists
# every one of them.
$pathFields = @(@(foreach ($o in @($ti, $ta)) {
    if ($null -eq $o -or $o -is [string]) { continue }
    foreach ($field in 'file_path', 'filePath', 'path', 'notebook_path') { $v = $o.$field; if ($null -ne $v -and [string]$v) { [string]$v } }
}) | Select-Object -Unique)
# The working directory the event says the tool runs in (Claude Code's and Copilot CLI's top-level cwd), which a tool
# resolves a relative path against; $null unless it is an absolute path.
$eventCwd = $null
if ($d.cwd -is [string] -and [regex]::IsMatch($d.cwd, '^(?:[A-Za-z]:[\\/]|[\\/]{2}[^\\/])')) { $eventCwd = $d.cwd.Replace('/', '\').TrimEnd('\') + '\' }
$cellSource = if (-not [string]::Equals([string]$ti.edit_mode, 'delete', $ordinalIgnoreCase)) { $ti.new_source }
# Each text the event writes, beside the text it replaces, which the suppression and skip checks below read
# (Test-GuardPattern -Adds): an edit's old_string, oldString or old_str beside its new_string, newString or
# new_str, one pair per field and never pooled. A whole-file text (Write's or create's content, file_text) has
# the file on disk as its old text, read only for a path that names the same file to Windows and to Node
# (Get-ExistingText). Any other text (an insert's new_str, text, a notebook cell) replaces nothing the event
# names, so it has no old text.
function New-WriteUnit($New, $Old, [bool]$Whole) { [pscustomobject]@{ New = $New; Old = $Old; Whole = $Whole } }
$wholeFileTool = [string]::Equals($tool, 'Write', $ordinalIgnoreCase) -or [string]::Equals($tool, 'create', $ordinalIgnoreCase)
$units = @(
    New-WriteUnit $ti.content $null $wholeFileTool
    New-WriteUnit $ti.new_string $ti.old_string $false
    New-WriteUnit $ti.newString $ti.oldString $false
    New-WriteUnit $ti.file_text $null $true
    New-WriteUnit $ti.new_str $ti.old_str $false
    New-WriteUnit $ti.text $null $false
    New-WriteUnit $cellSource $null $false
    New-WriteUnit $ta.content $null $wholeFileTool
    New-WriteUnit $ta.new_string $ta.old_string $false
    New-WriteUnit $ta.newString $ta.oldString $false
    New-WriteUnit $ta.file_text $null $true
    New-WriteUnit $ta.new_str $ta.old_str $false
    New-WriteUnit $ta.text $null $false
)
# Edit tools whose text sits in other fields, recognised by field shape because the name the hook receives is not
# verified: VS Code's insert_edit_into_file (`code` beside a path), edit_notebook_file (`newCode`, a string or an array
# of strings, none for editType delete), multi_replace_string_in_file (`replacements`, each item an edit to its own
# file) and Claude Code's MultiEdit (`edits`, each item old_string/new_string of the event's file). The first two join
# the units above; each item is a write of its own to its own path ($itemWrites), and every such path joins $pathFields.
$maxWriteItems = 200
$itemWrites = New-Object System.Collections.Generic.List[object]
$itemPaths = New-Object System.Collections.Generic.List[string]
$itemOverflow = $false
# Every path field an object names (not only the first): a tool may write the one the guard did not pick.
function Get-OwnPaths($Object) {
    if ($null -eq $Object -or $Object -is [string]) { return @() }
    return @(foreach ($field in 'file_path', 'filePath', 'path', 'notebook_path') { $v = $Object.$field; if ($null -ne $v -and [string]$v) { [string]$v } })
}
# A text field's string, an array of strings (nested arrays included) joined by newlines.
function Join-Text($Value) {
    if ($null -eq $Value) { return '' }
    if ($Value -is [string]) { return $Value }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [System.Collections.IDictionary]) {
        # An array of plain strings (the usual one) is joined at once; only a nested value is recursed into, so a
        # 1,000-line array costs one call, not one per line.
        $plain = $true
        foreach ($element in $Value) { if ($element -isnot [string]) { $plain = $false; break } }
        if ($plain) { return [string]::Join("`n", [string[]]$Value) }
        $parts = New-Object System.Collections.Generic.List[string]
        foreach ($element in $Value) { $parts.Add($(if ($element -is [string]) { $element } else { Join-Text $element })) }
        return [string]::Join("`n", $parts)
    }
    return [string]$Value
}
# `code` is read as a write only beside a path and either insert_edit_into_file's `explanation` field or its tool name; an
# MCP or terminal tool that merely carries a `code` field is not a write. editType alone never makes a call a write, and
# only the exact string 'delete' skips newCode.
$codeShaped = $false
$extraUnits = @()
foreach ($o in @($ti, $ta)) {
    if ($null -eq $o -or $o -is [string]) { continue }
    if (@(Get-OwnPaths $o).Count -gt 0) {
        $insertShaped = ($tool -is [string] -and $guardInsertTools.Contains($tool)) -or (@($o.PSObject.Properties.Name) -contains 'explanation')
        if ($insertShaped -and $null -ne $o.code) { $codeShaped = $true; $extraUnits += New-WriteUnit (Join-Text $o.code) $null $false }
        if ($null -ne $o.newCode -and -not ($o.editType -is [string] -and [string]::Equals($o.editType, 'delete', $ordinal))) {
            $extraUnits += New-WriteUnit (Join-Text $o.newCode) $null $false
        }
    }
    foreach ($collection in 'replacements', 'edits') {
        $n = 0
        foreach ($item in @($o.$collection)) {
            if ($null -eq $item -or $item -is [string]) { continue }
            if (++$n -gt $maxWriteItems) { $itemOverflow = $true; break }
            $own = @(Get-OwnPaths $item)
            foreach ($path in $own) { $itemPaths.Add($path) }
            $new = $null; $old = $null
            foreach ($f in 'newString', 'new_string', 'new_str') { if ($null -ne $item.$f) { $text = Join-Text $item.$f; if ($text) { $new = $text; break } } }
            foreach ($f in 'oldString', 'old_string', 'old_str') { if ($null -ne $item.$f) { $text = Join-Text $item.$f; if ($text) { $old = $text; break } } }
            if ($new) { $itemWrites.Add([pscustomobject]@{ Path = $(if ($own.Count -gt 0) { $own[0] } else { $fp }); Unit = (New-WriteUnit $new $old $false) }) }
        }
    }
}
$units = @($units + $extraUnits) | Where-Object { $_.New }
if ($itemPaths.Count -gt 0) { $pathFields = @(@($pathFields) + @($itemPaths) | Select-Object -Unique) }
$content = (@($units | ForEach-Object { $_.New }) -join "`n")

# Emit a block response by detected input shape. PascalCase Edit/Write/NotebookEdit (and the ambiguous
# empty tool) emit the Claude-shaped signal: reason on stderr plus exit 2. Other shapes emit a documented
# Copilot-compatible superset deny: top-level `permissionDecision` plus the same decision nested in
# `hookSpecificOutput`. These emitted shapes and registration do not prove that a client fired the
# hook or honored the denial; client behavior is capability-specific. See
# docs/enforcement-surfaces.md.
function Exit-Blocked([string]$Message) {
    if ([string]::Equals($tool, 'Edit', $ordinal) -or [string]::Equals($tool, 'Write', $ordinal) -or
        [string]::Equals($tool, 'NotebookEdit', $ordinal) -or [string]::Equals($tool, 'MultiEdit', $ordinal) -or $emptyTool) {
        [Console]::Error.WriteLine($Message)
        exit 2
    }
    [ordered]@{
        permissionDecision       = 'deny'
        permissionDecisionReason = $Message
        hookSpecificOutput       = [ordered]@{ permissionDecision = 'deny'; permissionDecisionReason = $Message }
    } | ConvertTo-Json -Compress -Depth 6
    exit 0
}

if ($unreadable) { Exit-Blocked $unreadableMessage }
if ($itemOverflow) {
    Exit-Blocked "Blocked write: it holds more than $maxWriteItems replacements or edits in one call, more than the write guard checks within its time limit, so it checked none of them. Split it into calls of at most $maxWriteItems."
}

# apply_patch, the file tool GPT models use on Copilot CLI and in VS Code, carries one V4A patch:
# '*** Begin Patch', then sections '*** Add File: <path>', '*** Update File: <path>' (optionally
# moved by '*** Move to: <path>') and '*** Delete File: <path>', then '*** End Patch'. Copilot CLI
# 1.0.95 and the runtime VS Code 1.139.1 bundles send it as a raw string, in toolArgs to
# .github/hooks/hooks.json (toolName apply_patch) and in tool_input to .claude/settings.json
# (tool_name Edit); the CLI also accepts an object whose string `input` carries it, the shape VS
# Code's Local harness sends. Each section's added lines are checked as a write to its path, and to
# its new path when it moves. An apply_patch call the guard cannot read, or one with more sections
# than it checks within its time limit, is blocked rather than passed.
$maxPatchSections = 200
$maxPatchPaths = 2 * $maxPatchSections
$patchText = $null
foreach ($v in @($ta.input, $ti.input, $ta, $ti)) { if ($v -is [string]) { $patchText = $v; break } }
if ($null -eq $patchText -and $taText -is [string] -and $null -eq $ta) { $patchText = $taText }
$namedPatch = [string]::Equals($tool, 'apply_patch', $ordinalIgnoreCase)
$isPatch = $namedPatch -or (-not ($fp -or $content) -and [regex]::IsMatch([string]$patchText, '\*\*\* (?:Add|Update|Delete) File:', $ci))

# Read line by line and never more strictly than the hosts' parsers: a '+' line, and any line that
# is not patch syntax at all (a host rejects such a patch, or may read it as added, so checking it
# costs nothing), belongs to the section above it. Removed ('-') and context (' ') lines, '@@'
# anchors and the patch markers are not new content, and inside an update an indented header is a
# context line to both hosts. Comparisons are ordinal: a culture-aware StartsWith skips ignorable
# characters such as a soft hyphen. Returns $null past $Max sections or $MaxPaths paths (a section's own path and each
# different 'Move to:' target; a target repeated within a section is one path) or 20 times $MaxPaths 'Move to:' lines, so a patch cannot hold the hook past its time limit.
function Get-PatchSections([string]$Patch, [int]$Max, [int]$MaxPaths = [int]::MaxValue) {
    # Self-contained: audit-trail.ps1 and post-write.ps1 load this function alone from this file.
    $ordinal = [StringComparison]::Ordinal
    $ci = [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::CultureInvariant
    # Removed: every line the section removes, all its hunks together, beside Lines, every line it adds. The
    # suppression and skip checks compare the one against the other, a section at a time, not a hunk at a time:
    # a patch can hold tens of thousands of hunks, and each text is counted once per pattern.
    $sections = New-Object System.Collections.Generic.List[object]
    $current = [pscustomobject]@{ Kind = ''; Paths = New-Object System.Collections.Generic.List[string]; Moved = $false; Lines = New-Object System.Collections.Generic.List[string]; Removed = New-Object System.Collections.Generic.List[string] }
    $sections.Add($current)
    $pathCount = 0; $moveLines = 0
    # Lines end at LF only, as both hosts split them; a lone CR stays inside its line.
    foreach ($line in ($Patch -split '\r?\n')) {
        # Trimmed as JavaScript's trim() does, which drops a byte-order mark (U+FEFF) too; .NET's Trim() keeps it.
        $marker = [regex]::Replace($line, '^[\s\uFEFF]+|[\s\uFEFF]+$', '')
        if (($header = [regex]::Match($marker, '^\*\*\* (Add|Update|Delete) File:\s*(.+)$', $ci)).Success -and
            -not ([string]::Equals($current.Kind, 'update', $ordinal) -and [char]::IsWhiteSpace($line, 0))) {
            if ($sections.Count -gt $Max) { return $null }
            $current = [pscustomobject]@{ Kind = $header.Groups[1].Value.ToLowerInvariant(); Paths = New-Object System.Collections.Generic.List[string]; Moved = $false; Lines = New-Object System.Collections.Generic.List[string]; Removed = New-Object System.Collections.Generic.List[string] }
            $current.Paths.Add($header.Groups[2].Value.Trim())
            if (++$pathCount -gt $MaxPaths) { return $null }
            $sections.Add($current)
        } elseif (($move = [regex]::Match($marker, '^\*\*\* Move to:\s*(.+)$', $ci)).Success -and $current.Paths.Count -gt 0) {
            if ($MaxPaths -lt [int]::MaxValue -and ++$moveLines -gt 20 * $MaxPaths) { return $null }
            $target = $move.Groups[1].Value.Trim()
            if (-not $current.Paths.Contains($target)) {
                if (++$pathCount -gt $MaxPaths) { return $null }
                $current.Paths.Add($target)
            }
            $current.Moved = $true
        } elseif ($line.StartsWith('+', $ordinal)) {
            $current.Lines.Add($line.Substring(1))
        } elseif ($line.StartsWith('-', $ordinal)) {
            $current.Removed.Add($line.Substring(1))
        } elseif ($line.Length -gt 0 -and -not $line.StartsWith(' ', $ordinal) -and -not $line.StartsWith('@@', $ordinal) -and
                  -not [regex]::IsMatch($marker, '^\*\*\* (?:Begin Patch|End Patch|End of File)$', $ci)) {
            $current.Lines.Add($line)
        }
    }
    return ,$sections
}

if ($isPatch) {
    $sections = Get-PatchSections ([string]$patchText) $maxPatchSections $maxPatchPaths
    if ($null -eq $sections) {
        Exit-Blocked "Blocked write to every file in this apply_patch call: it has more than $maxPatchSections file sections or more than $maxPatchPaths file paths (each section's own and each different '*** Move to:' target) or more than $(20 * $maxPatchPaths) '*** Move to:' lines, more than the write guard checks in one call, so it checked none of them. Split it into patches of at most $maxPatchSections files."
    }
    if (-not ($sections | Where-Object { $_.Paths.Count -gt 0 })) {
        if (-not $namedPatch) { exit 0 }
        Exit-Blocked "Blocked write to every file in this apply_patch call: the write guard cannot read it as a patch (no '*** Add File:', '*** Update File:' or '*** Delete File:' line), so it checked none of it. Send the change as one patch: '*** Begin Patch', the file sections, then '*** End Patch'."
    }
    # An update's old text is the lines it removes, all its hunks together, against all the lines it adds; an added
    # file's is the file on disk, if it exists. A section that moves its file has none: its removed lines belong to
    # the source file, not to the path it writes.
    # A section that adds no line is not checked for content. Every section's paths, a deletion's, a move's and one
    # that only removes lines included, are checked against the guard allowlist ($targets).
    $targets = @(foreach ($section in $sections) { foreach ($path in $section.Paths) { $path } })
    $groupId = 0
    $writes = @(foreach ($section in $sections) {
        $groupId++
        if ($section.Lines.Count -eq 0) { continue }
        $text = $section.Lines -join "`n"
        $sectionUnits = if ($section.Moved) {
            @(New-WriteUnit $text $null $false)
        } elseif ([string]::Equals($section.Kind, 'update', $ordinal)) {
            @(New-WriteUnit $text ($section.Removed -join "`n") $false)
        } else { @(New-WriteUnit $text $null ([string]::Equals($section.Kind, 'add', $ordinal))) }
        if ($section.Paths.Count -eq 0) { [pscustomobject]@{ Group = $groupId; Path = $null; Content = $text; Units = $sectionUnits; Paths = @() } }
        foreach ($path in $section.Paths) { [pscustomobject]@{ Group = $groupId; Path = $path; Content = $text; Units = $sectionUnits; Paths = @($path) } }
    })
} else {
    # Gate on whether this is an inspectable write, independent of surface: Claude sends
    # Write/Edit (PascalCase), Copilot CLI sends edit/create (lowercase), VS Code agent mode
    # sends camelCase tool names we can't fully enumerate -- so also accept any tool that
    # carries a file path + content (the real signal). $fp/$content were extracted above.
    $knownWrite = [string]::Equals($tool, 'Write', $ordinalIgnoreCase) -or [string]::Equals($tool, 'Edit', $ordinalIgnoreCase) -or
                  [string]::Equals($tool, 'create', $ordinalIgnoreCase) -or $emptyTool
    # The path of any write-shaped event is checked against the guard allowlist before its text is: a write that
    # empties a file, an edit whose new text is empty and a deleted notebook cell change the list as surely as one
    # that adds text. Write-shaped is a known file-writing tool name or any field that carries a write's text; a
    # read (Copilot's view) carries neither.
    $writeFields = @('content', 'new_string', 'newString', 'file_text', 'new_str', 'text', 'new_source', 'edits', 'old_string', 'oldString', 'old_str', 'newCode', 'replacements')
    # str_replace_editor writes only through its create, str_replace, insert and undo_edit commands; its view reads.
    $writeTools = @('MultiEdit', 'NotebookEdit', 'str_replace', 'insert')
    $editorWrite = [string]::Equals([string]$tool, 'str_replace_editor', $ordinalIgnoreCase) -and
                   @(foreach ($o in @($ti, $ta)) { if ($null -ne $o -and $o -isnot [string]) { foreach ($c in 'create', 'str_replace', 'insert', 'undo_edit') { if ([string]::Equals([string]$o.command, $c, $ordinalIgnoreCase)) { $c } } } }).Count -gt 0
    $writeShaped = $knownWrite -or $editorWrite -or @($writeTools | Where-Object { [string]::Equals([string]$tool, $_, $ordinalIgnoreCase) }).Count -gt 0 -or $codeShaped -or
                   @(foreach ($o in @($ti, $ta)) { if ($null -ne $o -and $o -isnot [string]) { @($o.PSObject.Properties.Name) | Where-Object { $writeFields -contains $_ } } }).Count -gt 0
    $targets = if ($writeShaped) { @($pathFields) } else { @() }
    $writes = if (($knownWrite -or ($fp -and $content)) -and $content) { @([pscustomobject]@{ Group = 0; Path = $fp; Content = $content; Units = $units; Paths = @($pathFields) }) } else { @() }
    $itemGroup = 0
    $writes = @($writes) + @(foreach ($item in $itemWrites) {
        $itemGroup++
        [pscustomobject]@{ Group = 1000 + $itemGroup; Path = $item.Path; Content = $item.Unit.New; Units = @($item.Unit); Paths = @($pathFields) }
    })
}

# The text of the file at $Path on disk, '' when it cannot be read as the file the write replaces: a path that
# is not absolute and local (a relative path is the tool's to resolve, and a UNC path may be an unreachable host
# that outlasts the hook's time limit); one that Windows and Node resolve to different files, because Windows
# drops a trailing dot or space from every segment ('Dir.\Legacy.cs' is Dir\Legacy.cs) and reads 'Legacy.cs::$DATA'
# as Legacy.cs while Node writes the literal name, so a path with a ':' or such a segment (other than '.' and '..')
# names no file here, nor does a reserved device name (CON, NUL, COM1) or, after '\\?\', a '.' or '..' segment; a
# file that is absent, a directory, larger than $maxExistingBytes, locked, or past the $diskBudget this event may
# read in all; or any error. Each path is read once per event, by its exact spelling: a folder can be case-sensitive
# ('Legacy.cs' and 'legacy.cs' two files), so no case is folded. '' is no old text, which leaves the write read as it
# always was.
$maxExistingBytes = 2MB
$diskBudget = 4MB
$script:diskBytesRead = 0
$script:diskTexts = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
function Get-ExistingText([string]$Path) {
    if ($script:diskTexts.ContainsKey($Path)) { return $script:diskTexts[$Path] }
    $text = ''
    try {
        $m = [regex]::Match($Path, '^(?<raw>\\\\\?\\)?[A-Za-z]:[\\/](?<rest>.*)$', [Text.RegularExpressions.RegexOptions]::Singleline)
        $readable = $m.Success -and $m.Groups['rest'].Value.IndexOf(':') -lt 0
        if ($readable) {
            foreach ($segment in $m.Groups['rest'].Value.Split([char[]]@('\', '/'))) {
                $dots = [string]::Equals($segment, '.', $ordinal) -or [string]::Equals($segment, '..', $ordinal)
                if (($dots -and $m.Groups['raw'].Success) -or (-not $dots -and ($segment.EndsWith('.', $ordinal) -or $segment.EndsWith(' ', $ordinal))) -or
                    [regex]::IsMatch($segment, '^(?:CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9]|CONIN\$|CONOUT\$) *(?:\..*)?$', $ci)) { $readable = $false; break }
            }
        }
        if ($readable) {
            $file = New-Object IO.FileInfo($Path)
            if ($file.Exists -and $file.Length -le $maxExistingBytes -and $script:diskBytesRead + $file.Length -le $diskBudget) {
                $script:diskBytesRead += $file.Length
                $text = [string][IO.File]::ReadAllText($file.FullName)
            }
        }
    } catch { $text = '' }
    $script:diskTexts[$Path] = $text
    return $text
}

# The directives of $Pattern in $Text, counted by text: each match with the rest of its line (its own arguments:
# disable CS0618, CS8602 / eslint-disable-line no-console / eslint-disable @angular-eslint/component-selector),
# up to a closing */ and trimmed. A directive inside a block comment (a /* before it, within 8 lines and 1 KB a line,
# with no */ between) runs to the */ or to the end of that window: 8 lines, 1 KB a line. The key starts at the match, so
# editing the code before a directive leaves its text alone; it runs to the end of the line, so editing the code after
# one on the same line is a new directive. One regex finds every key, so the cost is the text's size, however many
# directives it holds; a directive is not counted again inside the window of the one before it.
# Balance: the directives that stay in force until they are closed ($Opener, else $Pattern) less the closers
# ($Closer): #pragma warning disable less restore, block eslint-disable less eslint-enable.
$directiveBehind = '/\*(?:(?!\*/)[^\n]){0,1024}(?:\n(?:(?!\*/)[^\n]){0,1024}){0,8}'
$directiveWindow = '(?:(?!\*/)[^\n]){0,1024}(?:\n(?:(?!\*/)[^\n]){0,1024}){0,7}'
$directiveLine = '(?:(?!\*/)[^\r\n])*'
function Get-DirectiveInfo([string]$Text, [string]$Pattern, [string]$Closer, [string]$Opener, $Options) {
    # An ordinal Hashtable and an indexed loop: [ref] arguments and foreach over a MatchCollection cost several
    # times as much per match under PowerShell 7, and a 2 MB text can hold 100,000 matches.
    $counts = New-Object Collections.Hashtable([StringComparer]::Ordinal)
    if ($Text.Contains("`r")) { $Text = $Text.Replace("`r`n", "`n") }
    $found = [regex]::Matches($Text, '(?:' + $Pattern + ')(?:(?<=' + $directiveBehind + ')' + $directiveWindow + '|' + $directiveLine + ')', $Options)
    $total = $found.Count
    for ($i = 0; $i -lt $total; $i++) {
        $key = $found[$i].Value.Trim()
        $counts[$key] = 1 + $counts[$key]
    }
    $balance = 0
    if ($Closer) {
        if (-not $Opener) { $Opener = $Pattern }
        $balance = [regex]::Matches($Text, $Opener, $Options).Count - [regex]::Matches($Text, $Closer, $Options).Count
    }
    return [pscustomobject]@{ Counts = $counts; Balance = $balance }
}

# The directives of the text a unit replaces: the file on disk for a whole-file text (counted once per pattern and
# path for the whole event), else the unit's old text. $null when there is none.
$script:diskInfo = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
function Get-OldDirectiveInfo($Unit, [string]$Pattern, [string]$Closer, [string]$Opener, $Options) {
    if ($Unit.Whole) {
        $cacheKey = $Pattern + "`0" + [string]$fp
        if (-not $script:diskInfo.ContainsKey($cacheKey)) {
            $old = Get-ExistingText ([string]$fp)
            $script:diskInfo[$cacheKey] = $(if ($old) { Get-DirectiveInfo $old $Pattern $Closer $Opener $Options } else { $null })
        }
        return $script:diskInfo[$cacheKey]
    }
    $old = [string]$Unit.Old
    if (-not $old) { return $null }
    return Get-DirectiveInfo $old $Pattern $Closer $Opener $Options
}

function Test-GuardPattern {
    param([string]$Pattern, [ValidateSet('secret','test-defeat/suppression')][string]$Category, [switch]$Adds, [string]$Closer, [string]$Opener)
    # Case-sensitive, as -cmatch was; CultureInvariant also folds any inline (?i) the invariant way.
    $options = [Text.RegularExpressions.RegexOptions]::CultureInvariant
    try {
        if (-not [regex]::IsMatch([string]$content, $Pattern, $options)) { return $false }
        if (-not $Adds) { return $true }
        # -Adds: the write must ADD a directive, not keep one. Each text is compared with the text it replaces, by
        # directive text (Get-DirectiveInfo): it is blocked when any directive occurs more often in it than in
        # that text, so an edit that carries an existing suppression through unchanged passes, and one that adds
        # another, or widens one, does not. With -Closer it is also blocked when it leaves more directives unclosed
        # than the text it replaces, so dropping a #pragma warning restore or an eslint-enable widens nothing unseen.
        # No old text (nothing to compare with, or none that could be read) is no directive there. A match that
        # spans two of the event's texts is read as a match, as it was when they were pooled.
        $matchedAUnit = $false
        foreach ($unit in $writeUnits) {
            $new = [string]$unit.New
            if ($writeUnits.Count -gt 1 -and -not [regex]::IsMatch($new, $Pattern, $options)) { continue }
            $matchedAUnit = $true
            $oldInfo = Get-OldDirectiveInfo $unit $Pattern $Closer $Opener $options
            if ($null -eq $oldInfo -or $oldInfo.Counts.Count -eq 0) { return $true }
            $newInfo = Get-DirectiveInfo $new $Pattern $Closer $Opener $options
            foreach ($directive in $newInfo.Counts.Keys) {
                if ($newInfo.Counts[$directive] -gt [int]$oldInfo.Counts[$directive]) { return $true }
            }
            if ($Closer -and $newInfo.Balance -gt $oldInfo.Balance) { return $true }
        }
        return -not $matchedAUnit
    }
    catch {
        [Console]::Error.WriteLine("guard: regex error in $Category pattern '$Pattern'")
        if ([string]::Equals($Category, 'secret', $ordinal)) {
            $script:reasons += "cannot evaluate secret pattern '$Pattern' — blocking because the high-confidence secret floor is unavailable"
        }
        return $false
    }
}

# The repository is this hook's own ..\.. (the registrations run it from the project root, as the audit
# and routing hooks assume). $null when that path cannot be read, which leaves every path non-exempt.
$repoRoot = $null
try { $repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar } catch { }

# A written path read under the repository, by its text alone: nothing here asks the file system. A path with
# a '~' makes GetFullPath expand an 8.3 short name through the file system, and for an unreachable UNC host
# that waited ~21 s per path, past the hosts' time limits. '/' is '\'; a relative path is taken under the
# repository; '.' and '..' collapse here (a '..' above the repository leaves it); a drive path is cut at the
# repository's root, ordinal-ignore-case, so the folders a checkout sits in decide nothing; '\\?\C:\...'
# is 'C:\...', and a UNC path's '\\server\share\' is its drive part (a repository opened as \\server\share\repo
# or \\wsl.localhost\Ubuntu\...). A path that cannot be read this way is never under the repository:
# drive-relative (C:src), rooted without a drive (\x), \\.\, \\?\UNC\, a leading '~', a URI (file:), or a ':'
# anywhere past the drive (a stream suffix). $null for those and for a path outside the repository.
function Get-RepositoryRelativePath([string]$Path) {
    if (-not $repoRoot) { return $null }
    $p = $Path.Replace('/', '\')
    if ([regex]::IsMatch($p, '^\\\\\?\\[A-Za-z]:\\')) { $p = $p.Substring(4) }
    $drive = ''
    if ([regex]::IsMatch($p, '^[A-Za-z]:\\')) { $drive = $p.Substring(0, 3); $p = $p.Substring(3) }
    elseif (($unc = [regex]::Match($p, '^\\\\[^\\.?:][^\\:]*\\[^\\:]+\\')).Success) { $drive = $unc.Value; $p = $p.Substring($drive.Length) }
    elseif ($p.StartsWith('\', $ordinal) -or $p.StartsWith('~', $ordinal)) { return $null }
    if ($p.IndexOf(':') -ge 0) { return $null }
    $kept = New-Object System.Collections.Generic.List[string]
    foreach ($segment in $p.Split([char]'\')) {
        if ($segment.Length -eq 0 -or [string]::Equals($segment, '.', $ordinal)) { continue }
        if ([string]::Equals($segment, '..', $ordinal)) {
            if ($kept.Count -eq 0) { return $null }
            $kept.RemoveAt($kept.Count - 1)
            continue
        }
        $kept.Add($segment)
    }
    $rest = $kept -join '\'
    if (-not $drive) { return $rest }
    $full = $drive + $rest
    if ($rest) { $full += '\' }
    if (-not $full.StartsWith($repoRoot, $ordinalIgnoreCase)) { return $null }
    return $full.Substring($repoRoot.Length).TrimEnd('\')
}

# The working directory's place under the repository ('' at its root), or $null when the event names none or it lies
# outside the repository.
$cwdRelative = if ($eventCwd) { Get-RepositoryRelativePath $eventCwd }

# The path the allowlist is matched against: a relative path is the tool's to resolve against the event's working
# directory, so it is read under that folder, and gets no waiver when the event names no working directory inside the
# repository (a host may run the tool anywhere, and a path read from the repository's root could name another file).
function Get-WaiverRelativePath([string]$Path) {
    if (-not $Path) { return $null }
    $p = $Path.Replace('/', '\')
    if ([regex]::IsMatch($p, '^(?:\\\\|[A-Za-z]:)')) { return Get-RepositoryRelativePath $Path }
    if ($p.StartsWith('\', $ordinal) -or $p.StartsWith('~', $ordinal) -or $null -eq $cwdRelative) { return $null }
    if ($cwdRelative) { $p = $cwdRelative + '\' + $p }
    return Get-RepositoryRelativePath $p
}

# The name the extension checks read: the last segment left once '.' and '..' collapse and empty segments drop,
# as Node, which the hosts run on, resolves a path before it writes (Foo.cs\, Foo.cs\. and Foo.cs\x\.. all write
# Foo.cs). .NET and PowerShell resolve 'Foo.cs ' and 'Foo.cs.' to Foo.cs, so a trailing space or dot is cut (Node
# keeps the literal name, so these checks may read a .cs rule onto a file that is not one, the safe side for the
# extension rules; Get-ExistingText, which compares the file with the one on disk, cannot rely on that and
# refuses such a path). Windows also writes 'Foo.cs::$DATA' (an NTFS stream suffix, ':name[:type]' on the last
# segment) into Foo.cs itself, so everything from the segment's first ':' is cut first. A drive designator
# ('C:Foo.cs') is not a stream.
function Get-CheckedFileName([string]$Path) {
    if ([regex]::IsMatch($Path, '^[A-Za-z]:')) { $Path = $Path.Substring(2) }
    $kept = New-Object System.Collections.Generic.List[string]
    foreach ($segment in $Path.Split([char[]]@('\', '/'))) {
        if ($segment.Length -eq 0 -or [string]::Equals($segment, '.', $ordinal)) { continue }
        if ([string]::Equals($segment, '..', $ordinal)) { if ($kept.Count -gt 0) { $kept.RemoveAt($kept.Count - 1) }; continue }
        $kept.Add($segment)
    }
    if ($kept.Count -eq 0) { return '' }
    $name = $kept[$kept.Count - 1]
    $colon = $name.IndexOf(':')
    if ($colon -ge 0) { $name = $name.Substring(0, $colon) }
    return $name.TrimEnd(' ', '.')
}

# The team's waiver for the secret checks: .claude/guard-allowlist.txt under the repository, one repository-root path
# or glob per line (/ between folders; * within one folder name, ** across folders, ? one character; a line ending in
# / covers that folder; a line starting with # is a comment, and a # after a path is part of it). A write to a path it
# lists is not checked for a key format or a credential literal; every other check still applies. The file is the
# team's, changed by hand and reviewed in a pull request, so every agent write to it is blocked, an empty edit and a
# deletion included (Test-AllowlistTarget). A missing, unreadable or oversized file, or a line naming a drive, a ':' or
# a '..' segment, waives nothing.
# A glob is matched by a regex built without backtracking (RegexOptions.NonBacktracking: linear in the path, however
# the line nests its **), with a match timeout of $allowlistMatchTimeout; a runtime without that option backtracks
# within the same timeout. A match that times out waives nothing, and once $allowlistBudgetMs is spent on the list no
# further path is waived, so no list line can hold the guard past the hosts' 10 s limit: it only leaves the checks on.
$allowlistName = 'guard-allowlist.txt'
$maxAllowlistBytes = 64KB
$allowlistMatchTimeout = [TimeSpan]::FromMilliseconds(100)
$allowlistBudgetMs = 2000
$allowlistOptions = $ci
if ([enum]::GetNames([Text.RegularExpressions.RegexOptions]) -contains 'NonBacktracking') {
    $allowlistOptions = $ci -bor [Text.RegularExpressions.RegexOptions]'NonBacktracking'
}
$script:allowlistClock = $null
$script:allowlistPatterns = $null
function Test-AllowlistBudgetSpent {
    if ($null -eq $script:allowlistClock) { $script:allowlistClock = [Diagnostics.Stopwatch]::StartNew() }
    return $script:allowlistClock.ElapsedMilliseconds -ge $allowlistBudgetMs
}
function Get-AllowlistPatterns {
    if ($null -ne $script:allowlistPatterns) { return ,$script:allowlistPatterns }
    $patterns = New-Object System.Collections.Generic.List[regex]
    try {
        $file = if ($repoRoot) { New-Object IO.FileInfo((Join-Path $repoRoot ".claude\$allowlistName")) }
        if ($file -and $file.Exists -and $file.Length -le $maxAllowlistBytes) {
            foreach ($line in [IO.File]::ReadAllLines($file.FullName)) {
                if (Test-AllowlistBudgetSpent) { $patterns.Clear(); break }
                $entry = $line.Trim().Replace('\', '/')
                if ($entry.Length -eq 0 -or $entry.StartsWith('#', $ordinal)) { continue }
                while ($entry.StartsWith('./', $ordinal)) { $entry = $entry.Substring(2) }
                $entry = $entry.TrimStart('/')
                if ($entry.EndsWith('/', $ordinal)) { $entry += '**' }
                if ($entry.Length -eq 0 -or $entry.IndexOf(':') -ge 0 -or [regex]::IsMatch($entry, '(^|/)\.\.(/|$)')) { continue }
                $builder = New-Object System.Text.StringBuilder '^'
                for ($i = 0; $i -lt $entry.Length; $i++) {
                    $ch = $entry[$i]
                    if ($ch -eq '*' -and $i + 1 -lt $entry.Length -and $entry[$i + 1] -eq '*') {
                        if ($i + 2 -lt $entry.Length -and $entry[$i + 2] -eq '/') { [void]$builder.Append('(?:[^/]*/)*'); $i += 2 }
                        else { [void]$builder.Append('.*'); $i += 1 }
                    } elseif ($ch -eq '*') { [void]$builder.Append('[^/]*') }
                    elseif ($ch -eq '?') { [void]$builder.Append('[^/]') }
                    else { [void]$builder.Append([regex]::Escape([string]$ch)) }
                }
                [void]$builder.Append('$')
                $patterns.Add((New-Object regex($builder.ToString(), $allowlistOptions, $allowlistMatchTimeout)))
            }
        }
    } catch { $patterns.Clear() }
    $script:allowlistPatterns = $patterns
    return ,$patterns
}
function Test-AllowlistedPath([string]$Relative) {
    if (-not $Relative) { return $false }
    $path = $Relative.Replace('\', '/')
    foreach ($pattern in (Get-AllowlistPatterns)) {
        if (Test-AllowlistBudgetSpent) { return $false }
        try { if ($pattern.IsMatch($path)) { return $true } } catch { }
    }
    return $false
}
function Test-AllowlistFileName([string]$Name) {
    return [string]::Equals($Name, $allowlistName, $ordinalIgnoreCase) -or [regex]::IsMatch($Name, '^GUARD-~[0-9]+\.TXT$', $ci)
}
# Whether $Name could be an 8.3 short name Windows gives the list: TXT, and before the '~' either a prefix of GUARD-
# (GUARD-~1, GUAR~100) or the two letters and four hex digits of a hash-style alias (GUC529~1), ignoring case.
function Test-AllowlistAliasName([string]$Name) {
    $m = [regex]::Match($Name, '^(?<stem>[^~]{1,6})~[0-9]+\.TXT$', $ci)
    if (-not $m.Success) { return $false }
    $stem = $m.Groups['stem'].Value
    return 'GUARD-'.StartsWith($stem, $ordinalIgnoreCase) -or [regex]::IsMatch($stem, '^GU[0-9A-F]{4}$', $ci)
}
# Whether a write to $Path changes the guard allowlist. By name: the list's name in any folder, or GUARD-~N.TXT. By
# what Windows resolves it to: an 8.3 short name need not look like the list's (GUC529~1.TXT once four guard-*.txt
# files share the folder), so a path with a '~' is resolved to its long name (GetFullPath expands each existing 8.3
# segment through the file system) and compared, ignoring case, with the list's path; when its last segment names no
# file, could be an alias of the list's name (Test-AllowlistAliasName) and its folder resolved is the list's folder, it
# is refused too. A relative path is resolved against the event's working directory when that lies in the repository,
# and against both that directory and the repository otherwise; when the event names none, against the repository, and
# it is refused whenever its name could be an alias of the list's, since its folder is unknown. A path
# that resolves outside the repository on the repository's drive is never the list. One that cannot be resolved here
# (another drive or a UNC host, which may be unreachable and outlast the hook's time limit, a drive-relative or rooted
# path, a leading '~') is refused when its name could be an alias of the list's. Any error while resolving refuses the write.
function Test-AllowlistTarget([string]$Path) {
    if (-not $Path) { return $false }
    $name = Get-CheckedFileName $Path
    if (Test-AllowlistFileName $name) { return $true }
    if ($Path.IndexOf('~') -lt 0) { return $false }
    try {
        if (-not $repoRoot) { return [regex]::IsMatch($name, '~[0-9]') }
        $p = $Path.Replace('/', '\')
        if ([regex]::IsMatch($p, '^(?:\\\\|[A-Za-z]:)')) { return Test-AllowlistResolvedTarget $p $name }
        if ($p.StartsWith('\', $ordinal) -or $p.StartsWith('~', $ordinal)) { return Test-AllowlistAliasName $name }
        if (-not $eventCwd -and (Test-AllowlistAliasName $name)) { return $true }
        $bases = if ($null -ne $cwdRelative) { @($eventCwd) } elseif ($eventCwd) { @($eventCwd, $repoRoot) } else { @($repoRoot) }
        foreach ($base in $bases) { if (Test-AllowlistResolvedTarget ($base + $p) $name) { return $true } }
        return $false
    } catch { return $true }
}
function Test-AllowlistResolvedTarget([string]$p, [string]$name) {
    if ([regex]::IsMatch($p, '^\\\\\?\\[A-Za-z]:\\')) { $p = $p.Substring(4) }
    $local = [regex]::IsMatch($p, '^[A-Za-z]:\\') -and [string]::Equals($p.Substring(0, 2), $repoRoot.Substring(0, 2), $ordinalIgnoreCase)
    if (-not ($local -or $p.StartsWith($repoRoot, $ordinalIgnoreCase))) { return Test-AllowlistAliasName $name }
    # As Windows opens it: a stream suffix on the last segment and a trailing dot or space on any segment drop.
    $segments = $p.Split([char]'\')
    $last = $segments.Length - 1
    $colon = $segments[$last].IndexOf(':')
    if ($colon -ge 0 -and $last -gt 0) { $segments[$last] = $segments[$last].Substring(0, $colon) }
    for ($i = 1; $i -lt $segments.Length; $i++) {
        if (-not ([string]::Equals($segments[$i], '.', $ordinal) -or [string]::Equals($segments[$i], '..', $ordinal))) { $segments[$i] = $segments[$i].TrimEnd(' ', '.') }
    }
    $full = [IO.Path]::GetFullPath(($segments -join '\')).TrimEnd('\')
    $listFolder = [IO.Path]::GetFullPath($repoRoot + '.claude').TrimEnd('\')
    if ([string]::Equals($full, $listFolder + '\' + $allowlistName, $ordinalIgnoreCase)) { return $true }
    return (Test-AllowlistAliasName $name) -and -not ([IO.File]::Exists($full) -or [IO.Directory]::Exists($full)) -and
        [string]::Equals([IO.Path]::GetDirectoryName($full), $listFolder, $ordinalIgnoreCase)
}

foreach ($target in $targets) {
    if (Test-AllowlistTarget ([string]$target)) {
        Exit-Blocked "Blocked write to ${target}: it changes the guard allowlist (.claude/$allowlistName), the team's list of paths the secret checks skip. An agent may not write, edit or delete it, not even to remove a line; a teammate edits it by hand and the change is reviewed in a pull request."
    }
}

# Hook wiring (see the header). A path is read as Windows opens it: '/' is '\', a '\\?\' or '\\.\' prefix and the drive or UNC
# root drop, a stream suffix is cut from every segment (a file's '::$DATA', and a folder's '::$INDEX_ALLOCATION' or
# ':$I30:$INDEX_ALLOCATION', which Windows and Node open as the folder itself) and so is a trailing dot or space, and '.', '..' and
# empty segments collapse. Its last segments, ignoring case and in any folder, name a hook file (.claude\hooks\<name>.ps1,
# .github\hooks\hooks.json) or a settings file (.claude\settings.json, .claude\settings.local.json).
function Get-OpenedSegments([string]$Path) {
    $p = $Path.Replace('/', '\')
    if ($p.StartsWith('\\?\UNC\', $ordinalIgnoreCase) -or $p.StartsWith('\\.\UNC\', $ordinalIgnoreCase)) { $p = '\\' + $p.Substring(8) }
    elseif ($p.StartsWith('\\?\', $ordinal) -or $p.StartsWith('\\.\', $ordinal)) { $p = $p.Substring(4) }
    $p = [regex]::Replace($p, '^(?:[A-Za-z]:|\\\\[^\\]*\\[^\\]*)', '')
    $raw = $p.Split([char]'\')
    $kept = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $raw.Length; $i++) {
        $segment = $raw[$i]
        $colon = $segment.IndexOf(':'); if ($colon -ge 0) { $segment = $segment.Substring(0, $colon) }
        if (-not ([string]::Equals($segment, '.', $ordinal) -or [string]::Equals($segment, '..', $ordinal))) { $segment = $segment.TrimEnd(' ', '.') }
        if ($segment.Length -eq 0 -or [string]::Equals($segment, '.', $ordinal)) { continue }
        if ([string]::Equals($segment, '..', $ordinal)) { if ($kept.Count -gt 0) { $kept.RemoveAt($kept.Count - 1) }; continue }
        $kept.Add($segment)
    }
    return ,$kept
}
function Get-SegmentKind($Segments) {
    $n = $Segments.Count
    if ($n -ge 2 -and [string]::Equals($Segments[$n - 2], '.claude', $ordinalIgnoreCase) -and
        ([string]::Equals($Segments[$n - 1], 'settings.json', $ordinalIgnoreCase) -or [string]::Equals($Segments[$n - 1], 'settings.local.json', $ordinalIgnoreCase))) { return 'settings' }
    if ($n -ge 3 -and [string]::Equals($Segments[$n - 2], 'hooks', $ordinalIgnoreCase) -and
        (([string]::Equals($Segments[$n - 3], '.claude', $ordinalIgnoreCase) -and $Segments[$n - 1].EndsWith('.ps1', $ordinalIgnoreCase)) -or
         ([string]::Equals($Segments[$n - 3], '.github', $ordinalIgnoreCase) -and [string]::Equals($Segments[$n - 1], 'hooks.json', $ordinalIgnoreCase)))) { return 'hooks' }
    return ''
}
# The long path Windows opens for $Path: a relative path under the event's working directory, else the repository, and each
# existing 8.3 segment expanded by GetFullPath through the file system (a segment that does not exist is nobody's alias and
# stays as written). Only a local drive path, or a network path under a repository opened through one, whose host this hook runs
# from: another network host may be unreachable and outlast the hook's time limit. $null when it cannot be resolved here.
function Resolve-LongPath([string]$Path) {
    $p = $Path.Replace('/', '\')
    if ([regex]::IsMatch($p, '^\\\\\?\\[A-Za-z]:\\')) { $p = $p.Substring(4) }
    if (-not [regex]::IsMatch($p, '^(?:[A-Za-z]:|\\)')) {
        $base = if ($eventCwd) { $eventCwd } else { $repoRoot }
        if (-not $base) { return $null }
        $p = $base.TrimEnd('\') + '\' + $p
    }
    try {
        if ([regex]::IsMatch($p, '^[A-Za-z]:\\')) { return [IO.Path]::GetFullPath($p.Substring(0, 2) + '\' + ((Get-OpenedSegments $p) -join '\')) }
        if ($repoRoot -and $repoRoot.StartsWith('\\', $ordinal) -and $p.StartsWith($repoRoot, $ordinalIgnoreCase)) {
            # Collapsed from the share root, so a '..' that climbs out of the repository and back is followed; the result must
            # still lie under the repository.
            $full = [IO.Path]::GetFullPath([regex]::Match($p, '^\\\\[^\\]+\\[^\\]+').Value + '\' + ((Get-OpenedSegments $p) -join '\'))
            if ($full.StartsWith($repoRoot, $ordinalIgnoreCase)) { return $full }
        }
    } catch { }
    return $null
}
# 'hooks', 'settings', 'unresolved' or ''. A relative path is also read under the event's working directory and under the
# repository. A spelling with an 8.3 short name (~N) in its last three segments is read as Resolve-LongPath expands it; one that
# cannot be resolved here (a network path outside the repository, an error) is 'unresolved' when its name ends .ps1, .json or .jso (Windows cuts a short
# name's extension to three letters), since it may be any of them.
function Get-WiringKind([string]$Path) {
    $ErrorActionPreference = 'Stop'
    if (-not $Path) { return '' }
    $p = $Path.Replace('/', '\')
    $spellings = New-Object System.Collections.Generic.List[string]
    $spellings.Add($p)
    if (-not [regex]::IsMatch($p, '^(?:[A-Za-z]:|\\)')) {
        if ($eventCwd) { $spellings.Add($eventCwd + $p) }
        if ($repoRoot) { $spellings.Add($repoRoot + $p) }
    }
    foreach ($spelling in $spellings) {
        $segments = Get-OpenedSegments $spelling
        $kind = Get-SegmentKind $segments
        if ($kind) { return $kind }
        $n = $segments.Count
        $aliased = $false
        for ($i = [Math]::Max(0, $n - 3); $i -lt $n; $i++) { if ([regex]::IsMatch($segments[$i], '~[0-9]')) { $aliased = $true } }
        if (-not $aliased) { continue }
        $long = Resolve-LongPath $spelling
        if ($long) { $kind = Get-SegmentKind (Get-OpenedSegments $long); if ($kind) { return $kind }; continue }
        if ([regex]::IsMatch($segments[$n - 1], '\.(?:ps1|jso|json)$', $ci)) { return 'unresolved' }
    }
    return ''
}
# The settings file on disk: State 'text' (with Text), 'missing' or 'unreadable'. A network path is read only when it lies under
# the repository, whose host the hook itself runs from.
$maxSettingsBytes = 2MB
function Get-SettingsDisk([string]$Path) {
    $unreadable = [pscustomobject]@{ State = 'unreadable'; Text = $null }
    $long = Resolve-LongPath $Path
    if (-not $long -and $repoRoot -and $repoRoot.StartsWith('\\', $ordinal)) {
        $relative = Get-WaiverRelativePath $Path
        if ($null -ne $relative) { $long = $repoRoot + $relative }
    }
    if (-not $long) { return $unreadable }
    try {
        $file = New-Object IO.FileInfo($long)
        if (-not $file.Exists) {
            if ([IO.Directory]::Exists($long)) { return $unreadable }
            return [pscustomobject]@{ State = 'missing'; Text = $null }
        }
        if ($file.Length -gt $maxSettingsBytes) { return $unreadable }
        return [pscustomobject]@{ State = 'text'; Text = [IO.File]::ReadAllText($file.FullName) }
    } catch { return $unreadable }
}
# The root object of $Text read as strict JSON, as Claude Code reads settings and the installer reads them: no comment, trailing
# comma, single quote or byte-order mark, and no name twice in one object, ignoring case (an escaped spelling included). $null
# otherwise. The documents are kept so that their elements stay readable.
$script:settingsDocuments = New-Object System.Collections.Generic.List[object]
function Read-StrictJsonObject([string]$Text) {
    $doc = $null
    try { $doc = [System.Text.Json.JsonDocument]::Parse($Text, (New-Object System.Text.Json.JsonDocumentOptions)) } catch { return $null }
    $script:settingsDocuments.Add($doc)
    $root = $doc.RootElement
    if ($root.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) { return $null }
    $stack = New-Object 'System.Collections.Generic.Stack[System.Text.Json.JsonElement]'
    $stack.Push($root)
    while ($stack.Count -gt 0) {
        $element = $stack.Pop()
        if ($element.ValueKind -eq [System.Text.Json.JsonValueKind]::Object) {
            $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
            foreach ($property in $element.EnumerateObject()) {
                if (-not $seen.Add($property.Name)) { return $null }
                $stack.Push($property.Value)
            }
        } elseif ($element.ValueKind -eq [System.Text.Json.JsonValueKind]::Array) {
            foreach ($item in $element.EnumerateArray()) { $stack.Push($item) }
        }
    }
    return $root
}
# A member of a JSON object by its exact name, as Claude Code reads keys; $null when absent.
function Get-JsonProperty($Element, [string]$Name) {
    if ($null -eq $Element -or $Element.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) { return $null }
    foreach ($property in $Element.EnumerateObject()) { if ([string]::Equals($property.Name, $Name, $ordinal)) { return $property.Value } }
    return $null
}
# A JSON value as a string equal for equal values however it is laid out: members sorted by name, every string length-prefixed.
function ConvertTo-CanonicalJson($Element, [string]$Skip = '') {
    switch ($Element.ValueKind) {
        'Object' {
            $members = New-Object System.Collections.Generic.List[string]
            foreach ($property in $Element.EnumerateObject()) {
                if ($Skip -and [string]::Equals($property.Name, $Skip, $ordinal)) { continue }
                $members.Add([string]$property.Name.Length + ':' + $property.Name + '=' + (ConvertTo-CanonicalJson $property.Value))
            }
            $members.Sort([StringComparer]::Ordinal)
            return '{' + ($members -join ',') + '}'
        }
        'Array' { return '[' + (@(foreach ($item in $Element.EnumerateArray()) { ConvertTo-CanonicalJson $item }) -join ',') + ']' }
        'String' { $s = $Element.GetString(); return 's' + $s.Length + ':' + $s }
        default { return $Element.GetRawText() }
    }
}
# Each PreToolUse entry that names guard.ps1, with the other keys of its group (the matcher), as one canonical string.
function Get-GuardEntries($Root) {
    $entries = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $groups = Get-JsonProperty (Get-JsonProperty $Root 'hooks') 'PreToolUse'
    if ($null -eq $groups -or $groups.ValueKind -ne [System.Text.Json.JsonValueKind]::Array) { return ,$entries }
    foreach ($group in $groups.EnumerateArray()) {
        $handlers = Get-JsonProperty $group 'hooks'
        if ($null -eq $handlers -or $handlers.ValueKind -ne [System.Text.Json.JsonValueKind]::Array) { continue }
        $groupKey = $null
        foreach ($handler in $handlers.EnumerateArray()) {
            $text = ConvertTo-CanonicalJson $handler
            if ($text.IndexOf('guard.ps1', $ordinalIgnoreCase) -lt 0) { continue }
            if ($null -eq $groupKey) { $groupKey = ConvertTo-CanonicalJson $group 'hooks' }
            [void]$entries.Add($groupKey + "`0" + $text)
        }
    }
    return ,$entries
}
function Test-HooksOff($Root) {
    $value = Get-JsonProperty $Root 'disableAllHooks'
    return $null -ne $value -and $value.ValueKind -eq [System.Text.Json.JsonValueKind]::True
}
# $Text with each replace applied in order, line ends read as LF as the edit tools match them: the old text must occur exactly
# once, or at least once for a replace-all. $null otherwise.
function Get-ReplacedText([string]$Text, $Pairs) {
    $result = $Text.Replace("`r`n", "`n")
    foreach ($pair in $Pairs) {
        $old = ([string]$pair.Old).Replace("`r`n", "`n")
        $new = ([string]$pair.New).Replace("`r`n", "`n")
        if ($old.Length -eq 0) { return $null }
        $at = $result.IndexOf($old, $ordinal)
        if ($at -lt 0) { return $null }
        if ($pair.All) { $result = $result.Replace($old, $new); continue }
        if ($result.IndexOf($old, $at + 1, $ordinal) -ge 0) { return $null }
        $result = $result.Substring(0, $at) + $new + $result.Substring($at + $old.Length)
    }
    return $result
}
$settingsDroppedMessage = 'Blocked write to {0}: the file it would leave drops or changes the write guard''s entry (.claude/hooks/guard.ps1 under PreToolUse, with its matcher), or sets "disableAllHooks": true, so the guard could stop running. Other settings changes are fine: keep that entry and its group exactly as they are and resend, or have a teammate make this change by hand.'
$settingsUnknownMessage = 'Blocked write to {0}: the write guard cannot work out the file this write would leave (it is not strict JSON, the text to replace is not in the file exactly once, the file cannot be read, or the change is one the guard does not compute, such as an insert at a line), so it cannot confirm the guard stays registered. Resend it as a whole-file write or a single replace that keeps the guard''s entry, or have a teammate make the change by hand.'
$settingsPatchMessage = 'Blocked write to {0}: the write guard does not work out the file a patch leaves when it updates, moves or deletes a settings file, so it cannot confirm the guard stays registered. A teammate makes this change by hand.'
# $null when the write to the settings file $Target keeps every guard entry the file holds now, unchanged, and does not newly set
# disableAllHooks; else the message that refuses it. Each text the event could leave in the file is checked: a whole-file text
# (content, file_text, a patch's added file), and each replace (old and new text, or the edits and replacements items for this
# file, in order) applied to the file on disk. Anything else naming the file (an insert, undo_edit, code, newCode, text, a cell,
# a patch that updates, moves or deletes it) cannot be worked out and is refused. When the file on disk is not strict JSON (a merge
# conflict, say) a whole-file text or a replace may repair it, but must leave at least one guard entry if the disk text names
# guard.ps1.
function Test-SettingsWrite([string]$Target) {
    $ErrorActionPreference = 'Stop'
    $cannot = $settingsUnknownMessage -f $Target
    $candidates = New-Object System.Collections.Generic.List[object]
    if ($isPatch) {
        foreach ($section in $sections) {
            if (-not $section.Paths.Contains($Target)) { continue }
            if (-not ([string]::Equals($section.Kind, 'add', $ordinal) -and -not $section.Moved)) { return ($settingsPatchMessage -f $Target) }
            $candidates.Add([pscustomobject]@{ Whole = ($section.Lines -join "`n"); Pairs = $null })
        }
    } else {
        foreach ($o in @($ti, $ta)) {
            if ($null -eq $o -or $o -is [string]) { continue }
            $names = @($o.PSObject.Properties.Name)
            foreach ($field in 'text', 'code', 'newCode', 'new_source', 'insert_line') { if ($names -contains $field) { return $cannot } }
            foreach ($command in 'insert', 'undo_edit') { if ([string]::Equals([string]$o.command, $command, $ordinalIgnoreCase)) { return $cannot } }
            foreach ($field in 'content', 'file_text') {
                if ($names -contains $field) {
                    if ($null -ne $o.$field -and $o.$field -isnot [string]) { return $cannot }
                    $candidates.Add([pscustomobject]@{ Whole = [string]$o.$field; Pairs = $null })
                }
            }
            $all = ($o.replace_all -eq $true) -or ($o.replaceAll -eq $true)
            foreach ($pair in @(@('old_string', 'new_string'), @('oldString', 'newString'), @('old_str', 'new_str'))) {
                if ($names -contains $pair[0]) { $candidates.Add([pscustomobject]@{ Whole = $null; Pairs = @([pscustomobject]@{ Old = $o.($pair[0]); New = $o.($pair[1]); All = $all }) }) }
                elseif ($names -contains $pair[1]) { return $cannot }
            }
            $ownPaths = @(Get-OwnPaths $o)
            foreach ($collection in 'replacements', 'edits') {
                $itemPairs = New-Object System.Collections.Generic.List[object]
                foreach ($item in @($o.$collection)) {
                    if ($null -eq $item -or $item -is [string]) { continue }
                    $itemPaths = @(Get-OwnPaths $item)
                    if (-not $(if ($itemPaths.Count -gt 0) { $itemPaths -ccontains $Target } else { $ownPaths -ccontains $Target })) { continue }
                    $itemNames = @($item.PSObject.Properties.Name)
                    $old = $null; $new = $null
                    foreach ($pair in @(@('old_string', 'new_string'), @('oldString', 'newString'), @('old_str', 'new_str'))) {
                        if ($itemNames -contains $pair[0]) { $old = $item.($pair[0]); $new = $item.($pair[1]); break }
                    }
                    if ($null -eq $old) { return $cannot }
                    $itemPairs.Add([pscustomobject]@{ Old = $old; New = $new; All = (($item.replace_all -eq $true) -or ($item.replaceAll -eq $true)) })
                }
                if ($itemPairs.Count -gt 0) { $candidates.Add([pscustomobject]@{ Whole = $null; Pairs = $itemPairs }) }
            }
        }
    }
    if ($candidates.Count -eq 0) { return $cannot }
    $disk = Get-SettingsDisk $Target
    if ([string]::Equals($disk.State, 'unreadable', $ordinal)) { return $cannot }
    $diskRoot = if ([string]::Equals($disk.State, 'text', $ordinal)) { Read-StrictJsonObject $disk.Text }
    $diskEntries = if ($null -ne $diskRoot) { Get-GuardEntries $diskRoot }
    $diskOff = $null -ne $diskRoot -and (Test-HooksOff $diskRoot)
    $needEntry = $null -eq $diskRoot -and [string]::Equals($disk.State, 'text', $ordinal) -and $disk.Text.IndexOf('guard.ps1', $ordinalIgnoreCase) -ge 0
    foreach ($candidate in $candidates) {
        $result = $candidate.Whole
        if ($null -ne $candidate.Pairs) {
            if (-not [string]::Equals($disk.State, 'text', $ordinal)) { return $cannot }
            $result = Get-ReplacedText $disk.Text $candidate.Pairs
            if ($null -eq $result) { return $cannot }
        }
        if ($result.Length -gt $maxSettingsBytes) { return $cannot }
        $root = Read-StrictJsonObject $result
        if ($null -eq $root) { return $cannot }
        if ((Test-HooksOff $root) -and -not $diskOff) { return ($settingsDroppedMessage -f $Target) }
        $entries = Get-GuardEntries $root
        if ($null -ne $diskEntries) { foreach ($entry in $diskEntries) { if (-not $entries.Contains($entry)) { return ($settingsDroppedMessage -f $Target) } } }
        elseif ($needEntry -and $entries.Count -eq 0) { return ($settingsDroppedMessage -f $Target) }
    }
    return $null
}
$hookFileMessage = 'Blocked write to {0}: it changes a hook file of the framework (.claude/hooks/*.ps1 or .github/hooks/hooks.json), the scripts and registrations that make the write guard and the other hooks run. An agent may not write, edit, move or delete them; a teammate makes the change by hand and it is reviewed in a pull request.'
$shortNameMessage = 'Blocked write to {0}: the write guard cannot tell whether this 8.3 short name is one of the framework''s hook files or settings, because the path cannot be resolved here (a network path outside the repository, a path with no drive letter, or an error), so it checked none of it. Resend the write with the full long path; if this is the file''s real name, a teammate writes it by hand.'
foreach ($target in $targets) {
    $verdict = $null
    try {
        switch (Get-WiringKind ([string]$target)) {
            'hooks' { $verdict = $hookFileMessage -f $target }
            'unresolved' { $verdict = $shortNameMessage -f $target }
            'settings' { $verdict = Test-SettingsWrite ([string]$target) }
        }
    } catch { $verdict = $settingsUnknownMessage -f $target }
    if ($verdict) { Exit-Blocked $verdict }
}
if ($writes.Count -eq 0) { exit 0 }

# A write that holds more password values than this is blocked, not checked: each one costs about 0.1 ms in
# Test-CredentialMatch, so an unbounded count outlasts the hook's time limit. The unit is a password value, counted once
# for the whole event wherever it is read: a value that two passes reach, or a match reaches again through its pairs, is
# counted at the first reading only (it is told by where it ends in the text), so 500 values fit, and a value read a
# second time is read again but not counted again.
$maxCredentialMatches = 500
$credentialExamined = 0
$blocked = New-Object System.Collections.Generic.List[object]
# A section's added text is scanned once, however many paths it names (its own and each 'Move to:' target): what the scans
# decide depends on the text and on the path only through the extension rules, the waiver and the test-path exemption, so
# each result is kept by section and by those path facts (a whole-file text is read against its own path's file on disk).
$scanCache = New-Object Collections.Hashtable([StringComparer]::Ordinal)
$script:waiverSets = New-Object Collections.Hashtable([StringComparer]::Ordinal)
$script:waiverPaths = New-Object Collections.Hashtable([StringComparer]::Ordinal)
$reportedReasons = New-Object Collections.Hashtable([StringComparer]::Ordinal)
foreach ($write in $writes) {
    $fp = $write.Path
    $content = $write.Content
    $writeUnits = @($write.Units)
    $reasons = @()
    $fileName = Get-CheckedFileName ([string]$fp)
    $relativePath = if ($fp) { Get-RepositoryRelativePath ([string]$fp) }
    # An 8.3 short name under the repository is read as the long name Windows opens (TEST_C~1.JSO is test+cfg.json, not a test
    # file); one that cannot be resolved here gets no test exemption.
    if ($relativePath -and [regex]::IsMatch($relativePath, '~[0-9]')) {
        $longPath = Resolve-LongPath ([string]$fp)
        $relativePath = if ($longPath) { Get-RepositoryRelativePath $longPath }
    }
    # Waived only when the list matches every path the write names, each read from the event's working directory.
    # Each distinct path is tested once for the whole event, and so is each distinct set of paths (every item of a
    # replacements call names the same set).
    $waiverKey = @($write.Paths) -join "`0"
    if (-not $script:waiverSets.ContainsKey($waiverKey)) {
        $setWaived = @($write.Paths).Count -gt 0
        foreach ($path in @($write.Paths)) {
            if (-not $script:waiverPaths.ContainsKey([string]$path)) { $script:waiverPaths[[string]$path] = [bool](Test-AllowlistedPath (Get-WaiverRelativePath ([string]$path))) }
            if (-not $script:waiverPaths[[string]$path]) { $setWaived = $false; break }
        }
        $script:waiverSets[$waiverKey] = $setWaived
    }
    $waived = $script:waiverSets[$waiverKey]
    $diskPath = if (@($writeUnits | Where-Object { $_.Whole }).Count -gt 0) { [string]$fp } else { '' }
    $extKey = 'ext|' + $write.Group + '|' + [regex]::IsMatch($fileName, '\.cs$', $ci) + '|' + [regex]::IsMatch($fileName, '\.(ts|tsx|js|jsx|mts|cts|mjs|cjs)$', $ci) + '|' +
        [regex]::IsMatch($fileName, '(\.(spec|test|cy)|~[0-9]+)\.(ts|tsx|js|jsx|mts|cts|mjs|cjs)$', $ci) + '|' + $diskPath
    $extStart = @($reasons).Count
    if ($scanCache.ContainsKey($extKey)) { $reasons += $scanCache[$extKey] } else {

    if ([regex]::IsMatch($fileName, '\.cs$', $ci)) {
        if (Test-GuardPattern '#pragma\s+warning\s+disable' 'test-defeat/suppression' -Adds -Closer '#pragma\s+warning\s+restore') { $reasons += "adds '#pragma warning disable' — Verification Rule #7: failures are signals, fix the cause" }
        # The attribute's argument text may not hold another [Fact( or [Theory( opening: the match then starts
        # at the last one before the Skip, so the same writes match, and an open run of openings is read once,
        # not rescanned from every opening.
        if (Test-GuardPattern '\[(Fact|Theory)\((?:(?!\[(?:Fact|Theory)\()[^)])*Skip\s*=' 'test-defeat/suppression' -Adds) { $reasons += "skips a test via [Fact/Theory(Skip=...)] — don't skip; fix the test or record it in TECH_DEBT.md (Verification Rule #5)" }
        # [Ignore] opens a line: only horizontal whitespace may precede it ([^\S\n]*, which finds the same openings as
        # \s* did, since the last newline of a whitespace run is a line start, and does not scan a run of blank lines
        # from every line in it). The attribute's list text may not hold another opening that starts a line: the match
        # then starts at that one, so the same writes match, and a run of unclosed openings is read once, not rescanned
        # to the end from each.
        if (Test-GuardPattern '(?m)^[^\S\n]*\[(?:(?:(?!\n[^\S\n]*\[)[^]])*[,\s])?(Ignore)(Attribute)?\s*[\](,=]' 'test-defeat/suppression' -Adds) { $reasons += "skips a test via [Ignore] — don't skip; fix the test or record it in TECH_DEBT.md (Verification Rule #5)" }
        if ((Test-GuardPattern 'Assert\.True\(\s*true\s*[),]' 'test-defeat/suppression') -or (Test-GuardPattern 'Assert\.False\(\s*false\s*[),]' 'test-defeat/suppression')) { $reasons += "adds a tautological assertion (Assert.True(true) / Assert.False(false)) — assert observable behaviour, not a constant (Test leanness #15)" }
    }
    if ([regex]::IsMatch($fileName, '\.(ts|tsx|js|jsx|mts|cts|mjs|cjs)$', $ci)) {
        if (Test-GuardPattern 'eslint-disable' 'test-defeat/suppression' -Adds -Closer 'eslint-enable' -Opener 'eslint-disable(?!-(?:next-)?line)') { $reasons += "adds an 'eslint-disable' directive — fix the lint cause, don't silence it" }
        if (Test-GuardPattern '@ts-(ignore|nocheck)' 'test-defeat/suppression' -Adds) { $reasons += "adds '@ts-ignore'/'@ts-nocheck' — fix the type error, don't suppress it" }
    }
    # Test files: *.spec.* (Jasmine/Karma, Jest, Vitest, Playwright), *.test.* (Vitest and Jest; the Angular
    # unit-test builder runs both) and Cypress *.cy.*, in any JS or TS extension. The focus and skip forms
    # those runners document, chained ones included (it.concurrent.only, it.fails.skip, test.only.each,
    # test.concurrent.fails.only, describe.shuffle.skip, test.skip.concurrent, test.describe.serial.only,
    # test.fail.only, test.describe.fixme), and Mocha's specify, xcontext and xspecify, which Cypress ships.
    # Leading whitespace is [^\S\r\n]* (whitespace that cannot cross a line), never \s*: \s spans newlines,
    # which makes the scan quadratic on a long run of blank lines and stalls the hook. For the same reason a
    # modifier chain is bounded at three ({0,3}), never *: an open chain rescans a long run of chained names
    # from every name in it. An 8.3 short name such as APPSPE~1.TS, which Windows opens as app.spec.ts, has lost the
    # infix, so a ~N name in those extensions is read as a test file too.
    if ([regex]::IsMatch($fileName, '(\.(spec|test|cy)|~[0-9]+)\.(ts|tsx|js|jsx|mts|cts|mjs|cjs)$', $ci)) {
        if ((Test-GuardPattern '(?m)^[^\S\r\n]*f(it|describe)\s*(\(|\.each\b)' 'test-defeat/suppression') -or (Test-GuardPattern '\b(it|test|describe|suite|context|specify)(\.(concurrent|sequential|fails|shuffle|fail|describe(\.(serial|parallel))?)){0,3}\.only\s*[(.`]' 'test-defeat/suppression')) { $reasons += "adds a focused test (fit/fdescribe/.only) — it silently skips the rest of the suite; remove it before committing" }
        # On test.skip, test.fixme and Vitest's context.skip only declaration forms count: a title (string,
        # template or X.name) followed by the body, a literal true, or a chained form such as test.skip.each.
        # Playwright's test.skip(condition, reason) and test.skip(), and Vitest's context.skip(), run at test time.
        # A title is read for at most 200 characters: an open read rescans a long line of unclosed calls from
        # every call in it.
        if ((Test-GuardPattern '(?m)^[^\S\r\n]*x(it|describe|test|context|specify)\s*(\(|\.each\b)' 'test-defeat/suppression' -Adds) -or
            (Test-GuardPattern '\b(it|describe|suite|specify)(\.(concurrent|sequential|fails|shuffle)){0,3}\.skip\s*[(.`]' 'test-defeat/suppression' -Adds) -or
            (Test-GuardPattern '\btest(\.(concurrent|sequential|fails|describe)){1,3}\.(skip|fixme)\s*[(.`]' 'test-defeat/suppression' -Adds) -or
            (Test-GuardPattern '\b(test\.(skip|fixme)|context\.skip)\s*(\.[A-Za-z_$]|\(\s*([''"`][^\n]{0,200}?[''"`]\s*,|true\b\s*[,)]|[A-Za-z_$][\w$]*\.name\s*,))' 'test-defeat/suppression' -Adds)) { $reasons += "skips a test (xit/xdescribe/.skip) — don't skip; fix the test or record it in TECH_DEBT.md (Verification Rule #5)" }
        if ((Test-GuardPattern 'expect\(\s*true\s*\)\.toBe\(\s*true\s*\)' 'test-defeat/suppression') -or (Test-GuardPattern 'expect\(\s*false\s*\)\.toBe\(\s*false\s*\)' 'test-defeat/suppression')) { $reasons += "adds a tautological assertion (expect(true).toBe(true)) — assert observable behaviour, not a constant (Test leanness #15)" }
    }
    $scanCache[$extKey] = @($reasons | Select-Object -Skip $extStart)
    }

    $secretKey = 'secret|' + $write.Group + '|' + $waived + '|' + $diskPath
    $secretKind = $null
    if     ($scanCache.ContainsKey($secretKey)) { $secretKind = $scanCache[$secretKey] }
    elseif ($waived) { }
    elseif (Test-GuardPattern '-----BEGIN [A-Z ]*PRIVATE KEY-----' 'secret')   { $secretKind = 'a private key block' }
    elseif (Test-GuardPattern 'AKIA[0-9A-Z]{16}' 'secret')                     { $secretKind = 'an AWS access key id (AKIA…)' }
    elseif (Test-GuardPattern 'gh[oprsu]_[A-Za-z0-9]{36}' 'secret')            { $secretKind = 'a classic GitHub token (gh*_…)' }
    elseif (Test-GuardPattern 'github_pat_[0-9A-Za-z]{22}_[0-9A-Za-z]{59,}' 'secret') { $secretKind = 'a fine-grained GitHub token (github_pat_…)' }
    elseif (Test-GuardPattern 'xox[baprs]-[A-Za-z0-9-]{10,}' 'secret')         { $secretKind = 'a Slack token (xox…)' }
    # An sk- key starts a token, or follows an escape that ends in a letter or digit (\n \r \t, \uXXXX as
    # System.Text.Json writes a quote, \xXX, PowerShell `n `r `t, URL-encoded %XX). Inside a kebab-case
    # name such as task-list-item-renderer it is not a key. A key glued to any other letter or digit passes.
    elseif (Test-GuardPattern '(?:(?<![A-Za-z0-9])|(?<=\\[nrt]|\\u[0-9A-Fa-f]{4}|\\x[0-9A-Fa-f]{2}|`[nrt]|%[0-9A-Fa-f]{2}))sk-[A-Za-z0-9_-]{20,}' 'secret') { $secretKind = 'an API secret key (sk-…)' }
    elseif (Test-GuardPattern 'AIza[0-9A-Za-z_-]{35}' 'secret')               { $secretKind = 'a Google API key (AIza…)' }
    # The Azurite emulator's published development key is excluded: it is not a secret.
    elseif (Test-GuardPattern 'AccountKey=(?!Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==)[A-Za-z0-9+/]{86}==' 'secret') { $secretKind = 'an Azure storage account key (AccountKey=…)' }
    # The SAS signature, either order. The text between the two parts may not hold another opening of the same kind
    # (sv=…& in the first form, sig= and 40 signature characters in the second): the match then starts at that one,
    # so the same writes match, and a run of openings is read once, not rescanned to its end from each. The second
    # form's signature run is atomic: the text after it accepts the same characters, so giving some back only
    # rescanned that text from every shorter length.
    elseif (Test-GuardPattern '\bsv=\d{4}-\d{2}-\d{2}&(?:(?!\bsv=\d{4}-\d{2}-\d{2}&)[^\s"''])*?\bsig=[A-Za-z0-9%+/]{40,}|\bsig=(?>[A-Za-z0-9%+/]{40,})(?:(?!\bsig=[A-Za-z0-9%+/]{40,})[^\s"''])*?&sv=\d{4}-\d{2}-\d{2}' 'secret') { $secretKind = 'an Azure SAS token signature (sv=…&sig=…)' }
    $scanCache[$secretKey] = $secretKind
    if ($secretKind) { $reasons += "contains $secretKind — secrets must not be committed; use user-secrets / env vars / a vault" }

    # Test and sample paths are exempt from the credential heuristic only when a path segment carries
    # the marker as a whole token: delimited by . _ - or the segment edge (folded, like the routing
    # predicates), or as a PascalCase affix (case-sensitive: the capital is the only word boundary, so
    # Latest and Specification do not qualify but AuthServiceTests and Api.UnitTests do). Only the path under
    # the repository is read (see Get-RepositoryRelativePath): the folders a checkout sits in, such as
    # C:\Projects\test\repo, and a '..' that leaves a test folder decide nothing, and a path outside the
    # repository is never exempt.
    $credentialExempt = $waived
    if ($relativePath -and -not $credentialExempt) {
        $segments = @($relativePath -split '[\\/]' | Where-Object { $_ })
        for ($i = 0; $i -lt $segments.Count; $i++) {
            $segment = $segments[$i]
            $stem = if ($i -eq $segments.Count - 1) { $segment -replace '\.[^.]*$', '' } else { $segment }
            if ([regex]::IsMatch($segment, '(^|[._-])(tests?|specs?|mocks?|fixtures?|examples?|samples?|development)([._-]|$)', $ci) -or
                $stem -cmatch '(^|[a-z0-9])(Tests?|Specs?|Mocks?|Fixtures?)$|^(Tests?|Specs?|Mocks?|Fixtures?)[A-Z]') {
                $credentialExempt = $true; break
            }
        }
    }
    $credKey = 'credential|' + $write.Group + '|' + $diskPath
    if (-not $credentialExempt -and $scanCache.ContainsKey($credKey)) { $reasons += $scanCache[$credKey] }
    elseif (-not $credentialExempt) {
        $credStart = @($reasons).Count
        # A placeholder word anywhere in the matched text exempts it, as it always has. <...> is written so that its
        # content holds no '<' except as its last character: that finds the same matches (a '<' inside the content
        # starts a match of its own, except one right before the '>'), and a long run of '<' is no longer rescanned
        # to its end from every '<' (80,000 of them took 125 s on Windows PowerShell 5.1).
        $placeholder = '(changeme|placeholder|your[_-]|example|dummy|<(?:[^<>]+|[^<>]*<)>|\$\{|process\.env|%[A-Z_]+%)'
        # A release-pipeline token (#{X}#, __X__, $(X), {{X}}) is replaced at deploy time, so it exempts the
        # credential value it stands in for, and only that value: a token elsewhere must not hide a literal. The Service Bus
        # emulator's published key value SAS_KEY_VALUE (exact case) is not a secret and is never read as one, wherever it stands.
        $token = '^\s*(?:#\{[^}]{1,200}\}#|__[A-Za-z0-9_.:-]{1,200}__|\$\([A-Za-z0-9_.:-]{1,200}\)|\{\{[^}]{1,200}\}\}|replace[_-]?me|\*{3,200}|(?-i:x{3,200}|X{3,200})|null|redacted|hidden|\[(?:redacted|hidden)\]|(?-i:SAS_KEY_VALUE))\s*$'
        # Counts a password value once for the whole write, told by where it ends, and returns false once the cap is passed.
        $script:valueSeen = New-Object 'System.Collections.Generic.HashSet[int]'
        function Add-ExaminedValue([int]$End) {
            if ($script:valueSeen.Add($End)) {
                $script:credentialExamined++
                if ($script:credentialExamined -gt $maxCredentialMatches) { $script:tooManyValues = $true }
            }
            return -not $script:tooManyValues
        }
        # A connection string can carry several passwords (CertificatePassword=, SSL Password=, Proxy
        # Password=), so every password and userinfo value in the match must be a token to exempt it. The first
        # value that is not a token decides, and the rest are not read: collecting them all first (an array grown
        # with +=) took 27 s on a literal of 30,000 password keys. $Shift is where the text $Match was matched in
        # starts in the write, so that each value is counted by its place in the write.
        function Test-CredentialMatch($Match, [int]$Shift) {
            $v = $Match.Groups['v']
            if (-not (Add-ExaminedValue ($Shift + $v.Index + $v.Length))) { return $false }
            # The two forms that need no credential name (NetworkCredential, a URL) judge the password value alone: a
            # placeholder word in the user name or the host ("noreply@example.com") excuses nothing, and a password that
            # only illustrates (pass, password, secret) or repeats the user name (guest:guest, a published default) is no secret.
            if ($Match.Groups['strict'].Success) {
                $value = $v.Value
                if ([regex]::IsMatch($value, $placeholder, $ci) -or [regex]::IsMatch($value, $token, $ci) -or
                    [regex]::IsMatch($value, '^(?:pass(?:w(?:or)?d)?|pwd|pw|secret|\.{2,}|…+)$', $ci)) { return $false }
                $u = $Match.Groups['u']
                return -not ($u.Success -and $u.Value -ieq $value)
            }
            if ([regex]::IsMatch($Match.Value, $placeholder, $ci)) { return $false }
            $value = $v.Value
            if ($value -and -not [regex]::IsMatch($value, $token, $ci)) { return $true }
            $inner = [regex]::Match($Match.Value, '(?:password|pwd)\s*=\s*(?<v>(?>[^;"'']{4,}))|://[^/\s:@"'']+:(?<v>[^/\s@"'']+)@', $ci)
            while ($inner.Success) {
                $v = $inner.Groups['v']
                if (-not (Add-ExaminedValue ($Shift + $Match.Index + $v.Index + $v.Length))) { return $false }
                $value = $v.Value
                if ($value -and -not [regex]::IsMatch($value, $token, $ci)) { return $true }
                $inner = $inner.NextMatch()
            }
            return $false
        }
        # Every credential-shaped match is checked, so an earlier placeholder cannot hide a later literal.
        # A connection string must close its quote, so the (?=...) asks once whether the quote-free run ends
        # in one: without it each password= in a literal that never closes rescanned the run to its end, so a
        # long enough write outlasted the hook's time limit. The same writes match as before.
        $credentialHit = $false
        # Two passes. The first reads the keyed forms: a quoted value assigned to a credential name -- between the name
        # and the "=" or ":" it also reads the "]" that ends an indexer key (config["Password"] = "..."; only "=" may
        # follow that "]", so a ternary is not an assignment) and a type annotation, one type name or a union of them
        # (password: string | null = "..."), which prose after a colon is not; an "@" may stand before the quote (a
        # verbatim string) -- and the two connection-string forms under a connectionString key. The runs between the
        # name and the "=" are atomic or disjoint, so a long run of spaces or quotes cannot be re-split.
        $type = '[A-Za-z_$][\w$.]*(?:\[\])*'
        # The value after the "=": a quoted string of 8 or more characters, opened by a plain quote, a verbatim @"...", an
        # interpolated $"..." (not one that holds only {holes}), a C# raw """...""" or, in a .ts or .js file only (a Markdown
        # code span uses backticks), a backtick template. The name may also be followed by a C# accessor block
        # (Password { get; set; } = "...") or a TypeScript "?" (password?: "..."). Two forms need no name: the second argument
        # of new NetworkCredential(user, "...") when it is a literal of 4 or more characters, and a quoted URL that starts
        # with a scheme and holds user:password@ ("amqp://svc:...@host"). A URL password that opens with $, {, < or %, and a
        # NetworkCredential password that opens with {, is a variable, an interpolation hole or a placeholder, not a literal;
        # a URL password that is only pass, password, passwd, pwd, pw, secret, dots or an ellipsis is a README's illustration, not a credential.
        $valueHoles = '(?!(?:\{[^{}"'']*\})+["''])'
        $unionGuard = if ([regex]::IsMatch($fileName, '\.(ts|tsx|js|jsx|mts|cts|mjs|cjs)$', $ci)) { '(?![^\S\r\n]*\|(?!\|))' } else { '' }
        $valueOpener = '(?:@?["''](?<v>[^"'']{8,})["'']' + $unionGuard +
            '|(?:\$@?|@\$)["'']' + $valueHoles + '(?<v>[^"'']{8,})["'']' +
            '|"""\s*(?<v>[^"\s][^"]{7,})"""' +
            $(if ([regex]::IsMatch($fileName, '\.(ts|tsx|js|jsx|mts|cts|mjs|cjs)$', $ci)) { '|`(?<v>(?=[^`\s]{8})(?>(?:(?!\$\{)[^`\s])+))`' } else { '' }) + ')'
        # The first argument of NetworkCredential is anything up to the first comma (a quoted string, one level of brackets
        # or any other character, 200 items at most, all disjoint and atomic, so a long run of blanks cannot be re-split).
        $ncArg = '(?:[^,"''()\r\n;]|"[^"\r\n]{0,200}"|''[^''\r\n]{0,200}''|\([^()\r\n]{0,60}\))'
        $urlOpen = if ([regex]::IsMatch($fileName, '\.(ts|tsx|js|jsx|mts|cts|mjs|cjs)$', $ci)) { '["''`]' } else { '["'']' }
        $credName = '(?:password|passwd|pwd|secret|ap[i\u0130\u0131][_-]?key|access[_-]?key|client[_-]?secret)'
        $keyedPattern = '(?:(?<=[\w>?\]][^\S\r\n]+)' + $credName + '(?>["'' ]*)(?>\??)=>|' + $credName + '(?>["'' ]*)(?>\??)(?:(?>\][^\S\r\n]*)=|(?>\{[^{}\r\n]{0,80}\}[^\S\r\n]*)=|(?::[^\S\r\n]*' + $type + '(?:[^\S\r\n]*\|[^\S\r\n]*' + $type + ')*[^\S\r\n]*)?[:=]))\s*' + $valueOpener +
            '|connect[i\u0130\u0131]onstr[i\u0130\u0131]ng["'' ]*[:=]\s*["''](?=[^"'']*["''])[^"'']*(?:password|pwd)\s*=\s*(?<v>(?>[^;"'']{4,}))[^"'']*["'']' +
            '|connect[i\u0130\u0131]onstr[i\u0130\u0131]ng["'' ]*[:=]\s*["''](?=[^"'']*["''])[^"'']*://[^/\s:@]+:(?<v>[^/\s@]+)@[^"'']*["'']' +
            '|NetworkCredential\s*\((?>\s*)(?>' + $ncArg + '{0,200})' + ',\s*[$@]{0,2}["''](?!\{)(?<strict>)(?<v>[^"''\r\n]{4,})["'']' +
            '|' + $urlOpen + '[A-Za-z][A-Za-z0-9+.\-]{0,20}://(?>(?<u>[^/\s:@"''`?#]+)):(?![${<%])(?<strict>)(?<v>[^/\s@"''`?#]+)@'
        $tooManyValues = $false
        foreach ($m in [regex]::Matches($content, $keyedPattern, $ci)) {
            if (Test-CredentialMatch $m 0) { $credentialHit = $true; break }
            if ($tooManyValues) { break }
        }
        # The second pass reads a connection string with no key before it (UseSqlServer("..."), new SqlConnection("..."),
        # var connStr = "...") and runs only when nothing above was found, so it can never use up a quote a keyed form
        # needs. It matches no text: from each quote it looks ahead for a closed one-line literal that holds a Password=,
        # Pwd= or SharedAccessKey= pair, and reads it as a connection string in three cases: it holds at least two
        # ";"-separated key=value pairs, one of them that pair; or it holds that one pair (with or without a trailing ";")
        # and is the argument of .Append( or .AppendLine(; or it holds that one pair and a "+" (blanks and newlines
        # allowed) joins it to the next or the previous quoted literal, when that literal holds a key=value pair (a
        # long string written as "Data Source=...;" + "User ID=...;" + "Password=..."); or it opens, after a "+", "=", "(" or ",", with ";"
        # and then holds that one pair (";Password=...", the piece after a variable in "Server=" + host + ";Password=..."). Any other literal with one pair
        # ("Password=****;", "UPDATE Users SET Password=NULL;", a log or exception message) is not read. A key may carry a
        # prefix of letters, digits, ".", "_", "-" and blanks (Db2Password, Proxy.Password); "=" touches the key and the
        # value; a value that opens with "{" or "$" is an interpolation hole or a variable, and one that opens with "@"
        # a SQL parameter (Password=@Password;), not a literal. The placeholder and release-token exemptions read each
        # password's value only, not the whole literal, so a placeholder word elsewhere in the literal excuses nothing.
        # The look-ahead for a pair in the joined literal is atomic, so a long literal of "k=v" pieces is read once.
        if (-not $credentialHit -and -not $tooManyValues -and [regex]::IsMatch($content, '(?:password|pwd|SharedAccessKey)=', $ci)) {
            $k = '[A-Za-z0-9_.\- \t]'
            $quote = '["'']'
            $credentialPair = $k + '*?(?:password|pwd|SharedAccessKey)=[^;{$@"''\r\n][^;"''\r\n]{3,}'
            $otherPair = $k + '+=[^\s;="''][^;"''\r\n]*'
            $anyPair = $k + '=[^\s;="'']'
            $onePair = '(?<lit>' + $credentialPair + ';?)' + $quote
            $joinTo = '\s*\+\s*[$@]{0,2}' + $quote
            $literalPattern = $quote + '(?:' +
                '(?=(?<lit>[^"''\r\n]*)' + $quote + ')(?=(?:[^"''\r\n]*;)?(?:' + $credentialPair + ';' + $otherPair + '|' + $otherPair + ';' + $credentialPair + '))' +
                '|(?<=\.Append(?:Line)?\(\s*[$@]{0,2}' + $quote + ')(?=' + $onePair + ')' +
                '|(?=' + $onePair + $joinTo + '(?>[^"''\r\n]*?' + $anyPair + '))' +
                '|(?=(?>[^"''\r\n]*?' + $anyPair + ')[^"''\r\n]*' + $quote + $joinTo + $onePair + ')' +
                '|(?<=[+=(,]\s*[$@]{0,2}' + $quote + ')(?=(?<lit>;' + $credentialPair + ';?)' + $quote + ')' +
                ')'
            $pairPattern = '(?:^|;)' + $k + '*?(?:password|pwd|SharedAccessKey)=(?<v>[^;{$@][^;]{3,})'
            foreach ($m in [regex]::Matches($content, $literalPattern, $ci)) {
                $lit = $m.Groups['lit']
                foreach ($pair in [regex]::Matches($lit.Value, $pairPattern, $ci)) {
                    $v = $pair.Groups['v']
                    if (-not (Add-ExaminedValue ($lit.Index + $v.Index + $v.Length))) { break }
                    $value = $v.Value
                    if (-not [regex]::IsMatch($value, $placeholder, $ci) -and -not [regex]::IsMatch($value, $token, $ci)) { $credentialHit = $true; break }
                }
                if ($credentialHit -or $tooManyValues) { break }
            }
        }
        # appsettings.json's standard layout names each connection string inside a ConnectionStrings
        # object, so no connectionString key sits beside the value; check every entry of each section.
        # The section capture skips whole strings, so a brace inside a value (ODBC Driver={...}) does not
        # end it; atomic groups keep both patterns linear on Windows PowerShell 5.1.
        if (-not $credentialHit -and -not $tooManyValues) {
            foreach ($section in [regex]::Matches($content, '"connect[i\u0130\u0131]onstr[i\u0130\u0131]ngs"\s*:\s*\{((?:(?>"(?:[^"\\]|\\.)*")|[^{}"])*)', $ci)) {
                foreach ($entry in [regex]::Matches($section.Groups[1].Value, '"[^"]*"\s*:\s*"[^"]*(?:(?:password|pwd)\s*=\s*(?<v>(?>[^;"]{4,}))|://[^/\s:@"]+:(?<v>[^/\s@"]+)@)[^"]*"', $ci)) {
                    if (Test-CredentialMatch $entry $section.Groups[1].Index) { $credentialHit = $true; break }
                    if ($tooManyValues) { break }
                }
                if ($credentialHit -or $tooManyValues) { break }
            }
        }
        if ($tooManyValues -and -not $credentialHit) {
            $reasons += "holds more than $maxCredentialMatches credential-shaped values, too many to check inside the hook's time limit; write it in parts of fewer values"
        }
        if ($credentialHit) {
            $reasons += "assigns a hardcoded credential literal — move it to user-secrets / env vars / a vault"
        }
        $scanCache[$credKey] = @($reasons | Select-Object -Skip $credStart)
    }

    # Paths of one section that fail for the same reasons are reported together, in one sentence naming each.
    if ($reasons.Count -gt 0) {
        $reportKey = [string]$write.Group + '|' + ($reasons -join '|')
        if ($reportedReasons.ContainsKey($reportKey)) { $reportedReasons[$reportKey].Paths.Add([string]$fp) }
        else {
            $entry = [pscustomobject]@{ Paths = (New-Object System.Collections.Generic.List[string]); Reasons = $reasons }
            $entry.Paths.Add([string]$fp)
            $reportedReasons[$reportKey] = $entry
            $blocked.Add($entry)
        }
    }
}
if ($blocked.Count -eq 0) { exit 0 }

# One sentence per path, as each is a write the agent may need to fix; the paths of one section that fail alike past the first
# 20 are counted, not listed, so a section with hundreds of move targets does not make a message of hundreds of sentences.
$msg = @($blocked | ForEach-Object {
    $entry = $_
    $named = @($entry.Paths | Where-Object { $_ } | Select-Object -Unique)
    if ($named.Count -eq 0) { $named = @('the target file') }
    $sentences = @($named | Select-Object -First 20 | ForEach-Object { "Blocked write to ${_}: it " + ($entry.Reasons -join '; ') + '.' })
    if ($named.Count -gt 20) { $sentences += "The other $($named.Count - 20) paths of that patch section fail the same way." }
    $sentences
}) -join ' '
Exit-Blocked $msg
