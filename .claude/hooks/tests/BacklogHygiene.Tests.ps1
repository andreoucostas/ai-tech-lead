param(
    [ValidateSet('', 'finished-heading', 'dangling-pointer', 'broken-index',
        'vacuous-headings', 'vacuous-pointers', 'vacuous-index')]
    [string]$RedTest = ''
)

. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

function Get-BacklogRecords {
    param([string]$Text)
    $matches = @([regex]::Matches($Text, '(?m)^### (B-[0-9]+(?:[A-Za-z-]*)?) · ([^\r\n]*)'))
    if ($matches.Count -eq 0) { throw 'BACKLOG.md yielded zero open headings -- heading check is vacuous' }
    $records = @()
    for ($i = 0; $i -lt $matches.Count; $i++) {
        $start = $matches[$i].Index
        $end = if ($i + 1 -lt $matches.Count) { $matches[$i + 1].Index } else { $Text.Length }
        $records += [pscustomobject]@{
            Id = $matches[$i].Groups[1].Value
            Heading = $matches[$i].Groups[2].Value
            Text = $Text.Substring($start, $end - $start)
        }
    }
    return $records
}

function Assert-OpenHeadings {
    param([string]$Text)
    foreach ($record in (Get-BacklogRecords $Text)) {
        if ($record.Heading -notmatch '(?i)\b(?:DONE|CLOSED|ABSORBED)\b') { continue }
        # The critical preservation exception: an explicitly unfinished part keeps the record live.
        if ($record.Heading -match '(?i)PARTIALLY DONE' -or
            $record.Text -match '(?i)PARTIALLY DONE|STILL OPEN') { continue }
        throw "finished marker remains in open heading $($record.Id): $($record.Heading)"
    }
}

function Get-ArchiveIds {
    param([string]$Text)
    return @([regex]::Matches($Text, '\bB-[0-9]+(?:[A-Za-z-]*)?\b') |
        ForEach-Object Value | Sort-Object -Unique)
}

function Assert-ArchivePointers {
    param([string]$BacklogText, [string]$ArchiveText)
    $archiveIds = @(Get-ArchiveIds $ArchiveText)
    $pointers = @([regex]::Matches($BacklogText, 'see\s+`?meta/BACKLOG-DONE\.md`?'))
    if ($pointers.Count -eq 0) { throw 'BACKLOG.md yielded zero archive pointers -- pointer check is vacuous' }
    foreach ($pointer in $pointers) {
        $prefix = $BacklogText.Substring(0, $pointer.Index)
        $boundaries = @([regex]::Matches($prefix, '[.!?]\*{0,2}\s+'))
        $start = if ($boundaries.Count -gt 0) { $boundaries[-1].Index + $boundaries[-1].Length } else { 0 }
        $clause = $BacklogText.Substring($start, ($pointer.Index + $pointer.Length) - $start)
        $ids = @([regex]::Matches($clause, '\bB-[0-9]+(?:[A-Za-z-]*)?\b') | ForEach-Object Value | Sort-Object -Unique)
        if ($ids.Count -eq 0) { throw 'archive pointer names zero backlog ids' }
        foreach ($id in $ids) {
            if ($archiveIds -notcontains $id) { throw "archive pointer names missing id $id" }
        }
    }
}

function Assert-DecisionIndex {
    param([string]$IndexText, [string]$Root)
    $entries = @($IndexText -split '\r?\n' | Where-Object { $_ -match '^- .+ — `meta/' })
    if ($entries.Count -eq 0) { throw 'decisions-index.md yielded zero index entries -- citation check is vacuous' }
    foreach ($entry in $entries) {
        if ($entry -notmatch '`(meta/[^`:]+)(?::([0-9]+)| (WSD-[0-9]{3})| (B-[0-9]+[a-z]?))`') {
            throw "decision index entry has no resolvable source: $entry"
        }
        $relative = $Matches[1]
        $lineNumber = $Matches[2]
        $wsd = $Matches[3]
        $entryId = $Matches[4]
        $path = Join-Path $Root ($relative -replace '/', [IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "decision source file does not exist: $relative" }
        $sourceLines = @([IO.File]::ReadAllLines($path, [Text.Encoding]::UTF8))
        if ($wsd) {
            if (-not ($sourceLines -match ('^## ' + [regex]::Escape($wsd) + ':'))) {
                throw "decision source id does not resolve: $relative $wsd"
            }
            continue
        }
        # An ENTRY-ID citation is the preferred form: entry ids are stable, line numbers move on
        # every edit above them. This gate caught exactly that -- a single entry moved during the
        # 2026-08-17 restructure and invalidated a line citation that was correct when written.
        if ($entryId) {
            $startIdx = -1
            for ($i = 0; $i -lt $sourceLines.Count; $i++) {
                if ($sourceLines[$i] -match ('^### ' + [regex]::Escape($entryId) + '[ ]')) { $startIdx = $i; break }
            }
            if ($startIdx -lt 0) { throw "decision source entry does not resolve: $relative $entryId" }
            $endIdx = $sourceLines.Count - 1
            for ($i = $startIdx + 1; $i -lt $sourceLines.Count; $i++) {
                if ($sourceLines[$i] -match '^### B-') { $endIdx = $i - 1; break }
            }
            if ($entry -notmatch '“([^”]+)”') { throw "entry-cited decision has no quoted phrase: $entry" }
            $phrase = $Matches[1]
            $span = ($sourceLines[$startIdx..$endIdx] -join "`n")
            if ($span.IndexOf($phrase, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                throw "quoted phrase not found inside $relative $entryId -- $phrase"
            }
            continue
        }
        $n = [int]$lineNumber
        if ($n -lt 1 -or $n -gt $sourceLines.Count) { throw "decision source line is outside file: ${relative}:$n" }
        if ($entry -notmatch '“([^”]+)”') { throw "line-cited decision has no quoted phrase: $entry" }
        $phrase = $Matches[1]
        $first = [Math]::Max(0, $n - 4)
        $last = [Math]::Min($sourceLines.Count - 1, $n + 2)
        $near = ($sourceLines[$first..$last] -join "`n")
        if ($near.IndexOf($phrase, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw "quoted phrase not found near ${relative}:$n -- $phrase"
        }
    }
}

if ($RedTest) {
    try {
        switch ($RedTest) {
            'finished-heading' { Assert-OpenHeadings "### B-900 · Example — **DONE**`nBody.`n" }
            'dangling-pointer' {
                Assert-ArchivePointers "### B-1 · Open`n`nB-999 — see ``meta/BACKLOG-DONE.md``.`n" "- **B-1** — archived`n"
            }
            'broken-index' {
                Assert-DecisionIndex ('- “missing phrase” — `meta/BACKLOG.md:1`' + "`n") $repoRoot
            }
            'vacuous-headings' { Assert-OpenHeadings "no headings`n" }
            'vacuous-pointers' { Assert-ArchivePointers "no pointers`n" "- **B-1** — archived`n" }
            'vacuous-index' { Assert-DecisionIndex "# no entries`n" $repoRoot }
        }
        Write-Error "red test '$RedTest' unexpectedly passed"
        exit 1
    } catch {
        [Console]::Error.WriteLine($_.Exception.Message)
        exit 1
    }
}

Reset-Tests

It 'open backlog headings contain no completed records' {
    Assert-OpenHeadings ([IO.File]::ReadAllText((Join-Path $repoRoot 'meta/BACKLOG.md'), [Text.Encoding]::UTF8))
}

It 'PARTIALLY DONE headings remain valid open records' {
    Assert-OpenHeadings "### B-900 · Example — **PARTIALLY DONE; REMAINDER STILL OPEN**`nBody.`n"
}

It 'archive pointers resolve to archived ids' {
    Assert-ArchivePointers `
        ([IO.File]::ReadAllText((Join-Path $repoRoot 'meta/BACKLOG.md'), [Text.Encoding]::UTF8)) `
        ([IO.File]::ReadAllText((Join-Path $repoRoot 'meta/BACKLOG-DONE.md'), [Text.Encoding]::UTF8))
}

It 'decision-index sources and quoted phrases resolve' {
    Assert-DecisionIndex `
        ([IO.File]::ReadAllText((Join-Path $repoRoot 'meta/decisions-index.md'), [Text.Encoding]::UTF8)) `
        $repoRoot
}

exit (Write-TestSummary 'BacklogHygiene.Tests')
