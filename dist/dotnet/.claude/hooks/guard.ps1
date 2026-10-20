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
# shape alone.
$ErrorActionPreference = 'SilentlyContinue'
# Case-insensitive patterns fold case culture-invariantly ($ci) and string comparisons are ordinal:
# under tr-TR the current culture folds 'I' to a dotless i (U+0131), so a culture-following (?i)
# api[_-]?key missed API_KEY and let its literal through. -match and inline (?i) follow the culture.
$ci = [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::CultureInvariant
$ordinal = [StringComparison]::Ordinal
$ordinalIgnoreCase = [StringComparison]::OrdinalIgnoreCase

$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $d = $raw | ConvertFrom-Json } catch { exit 0 }

$tool = $d.tool_name; if (-not $tool) { $tool = $d.toolName }
$emptyTool = $tool -is [string] -and $tool.Length -eq 0   # a missing ($null) tool name is not the empty one
$ti = $d.tool_input
$ta = $d.toolArgs
$taText = $ta
if ($ta -is [string]) { try { $ta = $ta | ConvertFrom-Json } catch { $ta = $null } }

# Field names vary by surface: Claude (file_path/content/new_string), Copilot CLI (filePath/
# newString), and VS Code agent mode's text-editor tools (path + file_text on `create`, new_str
# on `str_replace`/`insert`) -- Task 0 confirmed the VS Code shapes, so they are covered here.
$fp = $null
foreach ($v in @($ti.file_path, $ti.filePath, $ti.path, $ta.filePath, $ta.file_path, $ta.path)) { if ($v) { $fp = $v; break } }
$parts = @($ti.content, $ti.new_string, $ti.newString, $ti.file_text, $ti.new_str, $ti.text,
           $ta.content, $ta.new_string, $ta.newString, $ta.file_text, $ta.new_str, $ta.text) | Where-Object { $_ }
$content = ($parts -join "`n")

# Emit a block response by detected input shape. PascalCase Edit/Write (and the ambiguous empty
# tool) emit the Claude-shaped signal: reason on stderr plus exit 2. Other shapes emit a documented
# Copilot-compatible superset deny: top-level `permissionDecision` plus the same decision nested in
# `hookSpecificOutput`. These emitted shapes and registration do not prove that a client fired the
# hook or honored the denial; client behavior is capability-specific. See
# docs/enforcement-surfaces.md.
function Exit-Blocked([string]$Message) {
    if ([string]::Equals($tool, 'Edit', $ordinal) -or [string]::Equals($tool, 'Write', $ordinal) -or $emptyTool) {
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
# characters such as a soft hyphen. Returns $null past $Max sections.
function Get-PatchSections([string]$Patch, [int]$Max) {
    # Self-contained: audit-trail.ps1 and post-write.ps1 load this function alone from this file.
    $ordinal = [StringComparison]::Ordinal
    $ci = [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::CultureInvariant
    $sections = New-Object System.Collections.Generic.List[object]
    $current = [pscustomobject]@{ Kind = ''; Paths = New-Object System.Collections.Generic.List[string]; Moved = $false; Lines = New-Object System.Collections.Generic.List[string] }
    $sections.Add($current)
    # Lines end at LF only, as both hosts split them; a lone CR stays inside its line.
    foreach ($line in ($Patch -split '\r?\n')) {
        $marker = $line.Trim()
        if (($header = [regex]::Match($marker, '^\*\*\* (Add|Update|Delete) File:\s*(.+)$', $ci)).Success -and
            -not ([string]::Equals($current.Kind, 'update', $ordinal) -and [char]::IsWhiteSpace($line, 0))) {
            if ($sections.Count -gt $Max) { return $null }
            $current = [pscustomobject]@{ Kind = $header.Groups[1].Value.ToLowerInvariant(); Paths = New-Object System.Collections.Generic.List[string]; Moved = $false; Lines = New-Object System.Collections.Generic.List[string] }
            $current.Paths.Add($header.Groups[2].Value.Trim())
            $sections.Add($current)
        } elseif (($move = [regex]::Match($marker, '^\*\*\* Move to:\s*(.+)$', $ci)).Success -and $current.Paths.Count -gt 0 -and -not $current.Moved) {
            $current.Paths.Add($move.Groups[1].Value.Trim())
            $current.Moved = $true
        } elseif ($line.StartsWith('+', $ordinal)) {
            $current.Lines.Add($line.Substring(1))
        } elseif ($line.Length -gt 0 -and -not $line.StartsWith('-', $ordinal) -and -not $line.StartsWith(' ', $ordinal) -and
                  -not $line.StartsWith('@@', $ordinal) -and -not [regex]::IsMatch($marker, '^\*\*\* (?:Begin Patch|End Patch|End of File)$', $ci)) {
            $current.Lines.Add($line)
        }
    }
    return ,$sections
}

if ($isPatch) {
    $sections = Get-PatchSections ([string]$patchText) $maxPatchSections
    if ($null -eq $sections) {
        Exit-Blocked "Blocked write to every file in this apply_patch call: it has more than $maxPatchSections file sections, more than the write guard checks in one call, so it checked none of them. Split it into patches of at most $maxPatchSections files."
    }
    if (-not ($sections | Where-Object { $_.Paths.Count -gt 0 })) {
        if (-not $namedPatch) { exit 0 }
        Exit-Blocked "Blocked write to every file in this apply_patch call: the write guard cannot read it as a patch (no '*** Add File:', '*** Update File:' or '*** Delete File:' line), so it checked none of it. Send the change as one patch: '*** Begin Patch', the file sections, then '*** End Patch'."
    }
    $writes = @(foreach ($section in $sections) {
        if ($section.Lines.Count -eq 0) { continue }
        $text = $section.Lines -join "`n"
        if ($section.Paths.Count -eq 0) { [pscustomobject]@{ Path = $null; Content = $text } }
        foreach ($path in $section.Paths) { [pscustomobject]@{ Path = $path; Content = $text } }
    })
} else {
    # Gate on whether this is an inspectable write, independent of surface: Claude sends
    # Write/Edit (PascalCase), Copilot CLI sends edit/create (lowercase), VS Code agent mode
    # sends camelCase tool names we can't fully enumerate -- so also accept any tool that
    # carries a file path + content (the real signal). $fp/$content were extracted above.
    $knownWrite = [string]::Equals($tool, 'Write', $ordinalIgnoreCase) -or [string]::Equals($tool, 'Edit', $ordinalIgnoreCase) -or
                  [string]::Equals($tool, 'create', $ordinalIgnoreCase) -or $emptyTool
    if (-not ($knownWrite -or ($fp -and $content))) { exit 0 }
    if (-not $content) { exit 0 }
    $writes = @([pscustomobject]@{ Path = $fp; Content = $content })
}

function Test-GuardPattern {
    param([string]$Pattern, [ValidateSet('secret','test-defeat/suppression')][string]$Category)
    # Case-sensitive, as -cmatch was; CultureInvariant also folds any inline (?i) the invariant way.
    try { return [regex]::IsMatch([string]$content, $Pattern, [Text.RegularExpressions.RegexOptions]::CultureInvariant) }
    catch {
        [Console]::Error.WriteLine("guard: regex error in $Category pattern '$Pattern'")
        if ([string]::Equals($Category, 'secret', $ordinal)) {
            $script:reasons += "cannot evaluate secret pattern '$Pattern' — blocking because the high-confidence secret floor is unavailable"
        }
        return $false
    }
}

$blocked = New-Object System.Collections.Generic.List[object]
foreach ($write in $writes) {
    $fp = $write.Path
    $content = $write.Content
    $reasons = @()

    if ([regex]::IsMatch([string]$fp, '\.cs$', $ci)) {
        if (Test-GuardPattern '#pragma\s+warning\s+disable' 'test-defeat/suppression') { $reasons += "adds '#pragma warning disable' — Verification Rule #7: failures are signals, fix the cause" }
        if (Test-GuardPattern '\[(Fact|Theory)\([^)]*Skip\s*=' 'test-defeat/suppression') { $reasons += "skips a test via [Fact/Theory(Skip=...)] — don't skip; fix the test or record it in TECH_DEBT.md (Verification Rule #5)" }
        if (Test-GuardPattern '(?m)^\s*\[([^]]*[,\s])?(Ignore)(Attribute)?\s*[\](,=]' 'test-defeat/suppression') { $reasons += "skips a test via [Ignore] — don't skip; fix the test or record it in TECH_DEBT.md (Verification Rule #5)" }
        if ((Test-GuardPattern 'Assert\.True\(\s*true\s*[),]' 'test-defeat/suppression') -or (Test-GuardPattern 'Assert\.False\(\s*false\s*[),]' 'test-defeat/suppression')) { $reasons += "adds a tautological assertion (Assert.True(true) / Assert.False(false)) — assert observable behaviour, not a constant (Test leanness #15)" }
    }
    if ([regex]::IsMatch([string]$fp, '\.(ts|tsx|js|jsx|mts|cts|mjs|cjs)$', $ci)) {
        if (Test-GuardPattern 'eslint-disable' 'test-defeat/suppression') { $reasons += "adds an 'eslint-disable' directive — fix the lint cause, don't silence it" }
        if (Test-GuardPattern '@ts-(ignore|nocheck)' 'test-defeat/suppression') { $reasons += "adds '@ts-ignore'/'@ts-nocheck' — fix the type error, don't suppress it" }
    }
    # Test files: *.spec.* (Jasmine/Karma, Jest, Vitest, Playwright), *.test.* (Vitest and Jest; the Angular
    # unit-test builder runs both) and Cypress *.cy.*, in any JS or TS extension. The focus and skip forms
    # those runners document, chained ones included (it.concurrent.only, it.fails.skip, test.only.each,
    # test.concurrent.fails.only, describe.shuffle.skip, test.skip.concurrent, test.describe.serial.only,
    # test.fail.only, test.describe.fixme), and Mocha's specify, xcontext and xspecify, which Cypress ships.
    # Leading whitespace is [^\S\r\n]* (whitespace that cannot cross a line), never \s*: \s spans newlines,
    # which makes the scan quadratic on a long run of blank lines and stalls the hook. For the same reason a
    # modifier chain is bounded at three ({0,3}), never *: an open chain rescans a long run of chained names
    # from every name in it.
    if ([regex]::IsMatch([string]$fp, '\.(spec|test|cy)\.(ts|tsx|js|jsx|mts|cts|mjs|cjs)$', $ci)) {
        if ((Test-GuardPattern '(?m)^[^\S\r\n]*f(it|describe)\s*(\(|\.each\b)' 'test-defeat/suppression') -or (Test-GuardPattern '\b(it|test|describe|suite|context|specify)(\.(concurrent|sequential|fails|shuffle|fail|describe(\.(serial|parallel))?)){0,3}\.only\s*[(.`]' 'test-defeat/suppression')) { $reasons += "adds a focused test (fit/fdescribe/.only) — it silently skips the rest of the suite; remove it before committing" }
        # On test.skip, test.fixme and Vitest's context.skip only declaration forms count: a title (string,
        # template or X.name) followed by the body, a literal true, or a chained form such as test.skip.each.
        # Playwright's test.skip(condition, reason) and test.skip(), and Vitest's context.skip(), run at test time.
        # A title is read for at most 200 characters: an open read rescans a long line of unclosed calls from
        # every call in it.
        if ((Test-GuardPattern '(?m)^[^\S\r\n]*x(it|describe|test|context|specify)\s*(\(|\.each\b)' 'test-defeat/suppression') -or
            (Test-GuardPattern '\b(it|describe|suite|specify)(\.(concurrent|sequential|fails|shuffle)){0,3}\.skip\s*[(.`]' 'test-defeat/suppression') -or
            (Test-GuardPattern '\btest(\.(concurrent|sequential|fails|describe)){1,3}\.(skip|fixme)\s*[(.`]' 'test-defeat/suppression') -or
            (Test-GuardPattern '\b(test\.(skip|fixme)|context\.skip)\s*(\.[A-Za-z_$]|\(\s*([''"`][^\n]{0,200}?[''"`]\s*,|true\b\s*[,)]|[A-Za-z_$][\w$]*\.name\s*,))' 'test-defeat/suppression')) { $reasons += "skips a test (xit/xdescribe/.skip) — don't skip; fix the test or record it in TECH_DEBT.md (Verification Rule #5)" }
        if ((Test-GuardPattern 'expect\(\s*true\s*\)\.toBe\(\s*true\s*\)' 'test-defeat/suppression') -or (Test-GuardPattern 'expect\(\s*false\s*\)\.toBe\(\s*false\s*\)' 'test-defeat/suppression')) { $reasons += "adds a tautological assertion (expect(true).toBe(true)) — assert observable behaviour, not a constant (Test leanness #15)" }
    }

    $secretKind = $null
    if     (Test-GuardPattern '-----BEGIN [A-Z ]*PRIVATE KEY-----' 'secret')   { $secretKind = 'a private key block' }
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
    elseif (Test-GuardPattern '\bsv=\d{4}-\d{2}-\d{2}&[^\s"'']*?\bsig=[A-Za-z0-9%+/]{40,}|\bsig=[A-Za-z0-9%+/]{40,}[^\s"'']*?&sv=\d{4}-\d{2}-\d{2}' 'secret') { $secretKind = 'an Azure SAS token signature (sv=…&sig=…)' }
    if ($secretKind) { $reasons += "contains $secretKind — secrets must not be committed; use user-secrets / env vars / a vault" }

    # Test and sample paths are exempt from the credential heuristic only when a path segment carries
    # the marker as a whole token: delimited by . _ - or the segment edge (folded, like the routing
    # predicates), or as a PascalCase affix (case-sensitive: the capital is the only word boundary, so
    # Latest and Specification do not qualify but AuthServiceTests and Api.UnitTests do).
    $credentialExempt = $false
    if ($fp) {
        $segments = @($fp -split '[\\/]' | Where-Object { $_ })
        for ($i = 0; $i -lt $segments.Count; $i++) {
            $segment = $segments[$i]
            $stem = if ($i -eq $segments.Count - 1) { $segment -replace '\.[^.]*$', '' } else { $segment }
            if ([regex]::IsMatch($segment, '(^|[._-])(tests?|specs?|mocks?|fixtures?|examples?|samples?|development)([._-]|$)', $ci) -or
                $stem -cmatch '(^|[a-z0-9])(Tests?|Specs?|Mocks?|Fixtures?)$|^(Tests?|Specs?|Mocks?|Fixtures?)[A-Z]') {
                $credentialExempt = $true; break
            }
        }
    }
    if (-not $credentialExempt) {
        # A placeholder word anywhere in the matched text exempts it, as it always has.
        $placeholder = '(changeme|placeholder|your[_-]|example|dummy|<[^>]+>|\$\{|process\.env|%[A-Z_]+%)'
        # A release-pipeline token (#{X}#, __X__, $(X), {{X}}) is replaced at deploy time, so it exempts the
        # credential value it stands in for, and only that value: a token elsewhere must not hide a literal.
        $token = '^\s*(?:#\{[^}]{1,200}\}#|__[A-Za-z0-9_.:-]{1,200}__|\$\([A-Za-z0-9_.:-]{1,200}\)|\{\{[^}]{1,200}\}\}|replace[_-]?me|\*{6,200})\s*$'
        # A connection string can carry several passwords (CertificatePassword=, SSL Password=, Proxy
        # Password=), so every password and userinfo value in the match must be a token to exempt it.
        function Test-CredentialMatch($Match) {
            if ([regex]::IsMatch($Match.Value, $placeholder, $ci)) { return $false }
            $values = @($Match.Groups['v'].Value)
            foreach ($inner in [regex]::Matches($Match.Value, '(?:password|pwd)\s*=\s*(?<v>(?>[^;"'']{4,}))|://[^/\s:@"'']+:(?<v>[^/\s@"'']+)@', $ci)) { $values += $inner.Groups['v'].Value }
            foreach ($value in $values) { if ($value -and -not [regex]::IsMatch($value, $token, $ci)) { return $true } }
            return $false
        }
        # Every credential-shaped match is checked, so an earlier placeholder cannot hide a later literal.
        $credentialHit = $false
        foreach ($m in [regex]::Matches($content, '(password|passwd|pwd|secret|api[_-]?key|access[_-]?key|client[_-]?secret)["'' ]*[:=]\s*["''](?<v>[^"'']{8,})["'']|connectionstring["'' ]*[:=]\s*["''][^"'']*(?:password|pwd)\s*=\s*(?<v>(?>[^;"'']{4,}))[^"'']*["'']|connectionstring["'' ]*[:=]\s*["''][^"'']*://[^/\s:@]+:(?<v>[^/\s@]+)@[^"'']*["'']', $ci)) {
            if (Test-CredentialMatch $m) { $credentialHit = $true; break }
        }
        # appsettings.json's standard layout names each connection string inside a ConnectionStrings
        # object, so no connectionString key sits beside the value; check every entry of each section.
        # The section capture skips whole strings, so a brace inside a value (ODBC Driver={...}) does not
        # end it; atomic groups keep both patterns linear on Windows PowerShell 5.1.
        if (-not $credentialHit) {
            foreach ($section in [regex]::Matches($content, '"connectionstrings"\s*:\s*\{((?:(?>"(?:[^"\\]|\\.)*")|[^{}"])*)', $ci)) {
                foreach ($entry in [regex]::Matches($section.Groups[1].Value, '"[^"]*"\s*:\s*"[^"]*(?:(?:password|pwd)\s*=\s*(?<v>(?>[^;"]{4,}))|://[^/\s:@"]+:(?<v>[^/\s@"]+)@)[^"]*"', $ci)) {
                    if (Test-CredentialMatch $entry) { $credentialHit = $true; break }
                }
                if ($credentialHit) { break }
            }
        }
        if ($credentialHit) {
            $reasons += "assigns a hardcoded credential literal — move it to user-secrets / env vars / a vault"
        }
    }

    if ($reasons.Count -gt 0) { $blocked.Add([pscustomobject]@{ Path = $fp; Reasons = $reasons }) }
}
if ($blocked.Count -eq 0) { exit 0 }

$msg = @($blocked | ForEach-Object {
    $target = if ($_.Path) { $_.Path } else { 'the target file' }
    "Blocked write to ${target}: it " + ($_.Reasons -join '; ') + '.'
}) -join ' '
Exit-Blocked $msg
