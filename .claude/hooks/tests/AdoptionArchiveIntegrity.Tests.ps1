# Executable coverage for the adoption archive-integrity mechanism (adoption-archive.ps1 + the
# brownfield installer's evidence capture). The real /adopt completion path is a workflow document
# a model executes, so the missing mechanical guard is reconstructed here at the helper boundary:
# a normalized/truncated/mutated archive must be rejected with a named candidate, and an
# examination failure must be reported as CANT-VERIFY, never as corruption or PASS.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
. (Join-Path $PSScriptRoot '_MutationHelper.ps1')

$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$script:DistRoot = Join-Path $script:RepoRoot 'dist/dotnet'
$script:Helper = Join-Path $script:DistRoot 'scripts/adoption-archive.ps1'
$script:Installer = Join-Path $script:DistRoot 'scripts/install.ps1'
$script:EmptySha = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'

function New-FixtureRepo {
    param([switch]$NoGit)
    $path = Join-Path ([IO.Path]::GetTempPath()) ('aa-fx-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $path | Out-Null
    if (-not $NoGit) {
        & git -C $path init -q
        & git -C $path config user.email 'fixture@example.invalid'
        & git -C $path config user.name 'Fixture'
    }
    return $path
}

function Add-Commit {
    param([string]$Repo, [string]$Message = 'fixture')
    & git -C $Repo add -A 2>&1 | Out-Null
    & git -C $Repo -c user.email=fixture@example.invalid -c user.name=Fixture commit -q -m $Message 2>&1 | Out-Null
    Assert ($LASTEXITCODE -eq 0) "could not commit fixture: $Message"
}

function Invoke-Aa {
    param([Parameter(Mandatory)][string[]]$AaArgs, [string]$HelperPath = $script:Helper)
    # Use the harness's raw process transport.  PS5.1 otherwise promotes native
    # stderr to an error record under Stop, hiding the helper's intentional
    # refusal exit and diagnostic from this assertion boundary.
    $result = Invoke-RawProcess -FileName (Get-PsExe) -Arguments (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $HelperPath) + $AaArgs)
    return [pscustomobject]@{ Exit = $result.Exit; Output = ($result.Out + $result.Err) }
}

function Get-FrozenEntry {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$OriginalPath, [Parameter(Mandatory)][string]$Destination)
        $marker = Join-Path $root '.claude/adoption-pending.json'
        if (Test-Path -LiteralPath $marker) {
            $existingMarker = Get-Content -Raw -LiteralPath $marker | ConvertFrom-Json
            if ($null -ne $existingMarker.archiveIntegrity.PSObject.Properties['frozenAt']) {
                # Test fixtures that independently archive several files need independent frozen
                # sessions now that production correctly refuses a second Freeze on one marker.
                $marker = Join-Path $root ('.claude/test-marker-' + [guid]::NewGuid().ToString('N') + '.json')
            }
        }
        if (-not (Test-Path -LiteralPath $marker)) {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $marker) | Out-Null
            [void](New-EvidenceFile -Path $marker -Entries @())
        }
        $plan = New-ArchivePlanFile -Path (Join-Path $root ('.claude/test-plan-' + [guid]::NewGuid().ToString('N') + '.json')) -Entries @([ordered]@{ originalPath = $OriginalPath; destination = $Destination })
        $freeze = Invoke-Aa @('-Freeze', '-RepoRoot', $root, '-EvidencePath', $marker, '-PlanPath', $plan)
        Assert ($freeze.Exit -eq 0) "freeze for test archive failed: $($freeze.Output)"
        $moved = Invoke-Aa @('-MoveFrozen', '-RepoRoot', $root, '-EvidencePath', $marker, '-OriginalPath', $OriginalPath, '-Destination', $Destination)
        Assert ($moved.Exit -eq 0) "frozen test archive failed: $($moved.Output)"
        return @((Get-Content -Raw -LiteralPath $marker | ConvertFrom-Json).archiveIntegrity.entries | Where-Object { $_.originalPath -eq $OriginalPath -and $_.destination -eq $Destination })[0]
}

function Get-Entry {
    param([Parameter(Mandatory)][string[]]$AaArgs)
    $r = Invoke-Aa -AaArgs $AaArgs
    Assert ($r.Exit -eq 0) "helper $($AaArgs -join ' ') exited $($r.Exit): $($r.Output)"
    return ($r.Output | ConvertFrom-Json)
}

function Invoke-Installer {
    param([Parameter(Mandatory)][string]$Target)
    $out = & (Get-PsExe) -NoProfile -File $script:Installer -Target $Target 2>&1 | Out-String
    return [pscustomobject]@{ Exit = [int]$LASTEXITCODE; Output = $out }
}

function Invoke-InstallerFrom {
    param([Parameter(Mandatory)][string]$InstallerPath, [Parameter(Mandatory)][string]$Target)
    $out = & (Get-PsExe) -NoProfile -File $InstallerPath -Target $Target 2>&1 | Out-String
    return [pscustomobject]@{ Exit = [int]$LASTEXITCODE; Output = $out }
}

function New-MutatedInstallerSource {
    param([Parameter(Mandatory)][string]$Find, [Parameter(Mandatory)][string]$Replacement)
    $source = Join-Path ([IO.Path]::GetTempPath()) ('aa-installer-source-' + [guid]::NewGuid().ToString('N'))
    Copy-Item -LiteralPath $script:DistRoot -Destination $source -Recurse -Force
    $installer = Join-Path $source 'scripts/install.ps1'
    $text = [IO.File]::ReadAllText($installer, [Text.Encoding]::UTF8)
    Assert ($text.Contains($Find)) "installer mutation anchor is absent: $Find"
    [IO.File]::WriteAllText($installer, $text.Replace($Find, $Replacement), [Text.UTF8Encoding]::new($true))
    return $source
}

function New-MutatedHelper {
    param([Parameter(Mandatory)][string]$Find, [Parameter(Mandatory)][string]$Replacement)
    $path = Join-Path ([IO.Path]::GetTempPath()) ('aa-helper-' + [guid]::NewGuid().ToString('N') + '.ps1')
    $text = [IO.File]::ReadAllText($script:Helper, [Text.Encoding]::UTF8)
    Assert ($text.Contains($Find)) "helper mutation anchor is absent: $Find"
    [IO.File]::WriteAllText($path, $text.Replace($Find, $Replacement), [Text.UTF8Encoding]::new($true))
    return $path
}

function New-EvidenceFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [object[]]$Entries = @(),
        [string]$Status = 'complete',
        [string]$Baseline = $null,
        [switch]$Legacy,
        [switch]$NoEntriesKey
    )
    if ($Legacy) {
        $doc = [ordered]@{
            installedAt       = '2026-09-07'
            detectedArtifacts = @('CLAUDE.md')
            archivedOriginals = @($Entries | ForEach-Object { [string]$_.destination })
        }
    } else {
        $integrity = [ordered]@{ schemaVersion = 1; inventoryStatus = $Status; baselineRevision = $Baseline; capturedAt = '2026-09-07'; inventoryIdentity = (New-TestInventoryIdentity -Entries $Entries) }
        if (-not $NoEntriesKey) { $integrity['entries'] = @($Entries) }
        $doc = [ordered]@{
            installedAt       = '2026-09-07'
            detectedArtifacts = @('CLAUDE.md')
            archivedOriginals = @($Entries | ForEach-Object { [string]$_.destination })
            archiveIntegrity  = $integrity
        }
    }
    [IO.File]::WriteAllText($Path, ($doc | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
    return $Path
}

function ConvertTo-TestIdentitySegment {
    param([AllowNull()][string]$Value)
    return [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$Value))
}

function New-TestInventoryIdentity {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Entries)
    $lines = New-Object 'System.Collections.Generic.List[string]'
    foreach ($entry in @($Entries)) {
        $line = @(
            ([int]$entry.schemaVersion).ToString([Globalization.CultureInfo]::InvariantCulture)
            (ConvertTo-TestIdentitySegment -Value ([string]$entry.originalPath))
            (ConvertTo-TestIdentitySegment -Value ([string]$entry.destination))
            ([string]$entry.sha256).ToLowerInvariant()
            ([int64]$entry.byteLength).ToString([Globalization.CultureInfo]::InvariantCulture)
            (ConvertTo-TestIdentitySegment -Value ([string]$entry.owner))
            (ConvertTo-TestIdentitySegment -Value ([string]$entry.provenanceRevision))
            (ConvertTo-TestIdentitySegment -Value ([string]$entry.provenance))
            (ConvertTo-TestIdentitySegment -Value ([string]$entry.historyDepth))
            (ConvertTo-TestIdentitySegment -Value ([string]$entry.localModification))
        ) -join '|'
        $lines.Add($line)
    }
    $lines.Sort([StringComparer]::Ordinal)
    $payload = "ai-tech-lead/archive-integrity/v1`n" + ($lines -join "`n")
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $digest = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($payload)))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
    return [ordered]@{ schemaVersion = 1; algorithm = 'SHA-256'; entryCount = [int]$lines.Count; sha256 = $digest }
}

function New-ArchivePlanFile {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][object[]]$Entries)
    $plan = [ordered]@{ entries = @($Entries) }
    [IO.File]::WriteAllText($Path, ($plan | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
    return $Path
}

function Read-ArchivePlanExample {
    param([Parameter(Mandatory)][string]$Path)
    try { $doc = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) }
    catch { throw "CANT-EXAMINE archive example document '$Path': $($_.Exception.Message)" }
    $label = '<!-- archive-plan-example -->'
    if ([regex]::Matches($doc, [regex]::Escape($label)).Count -ne 1) {
        throw 'DOC-DEFECT archive example: expected exactly one archive-plan-example label'
    }
    $block = [regex]::Match($doc, '(?m)^<!-- archive-plan-example -->\r?\n```json\r?\n(?<json>[\s\S]*?)\r?\n```[ \t]*\r?$')
    if (-not $block.Success) { throw 'DOC-DEFECT archive example: missing labelled JSON fence' }
    $json = $block.Groups['json'].Value
    try { $null = ConvertFrom-Json -InputObject $json -ErrorAction Stop }
    catch { throw "DOC-DEFECT archive example: invalid JSON: $($_.Exception.Message)" }
    # Return the captured text, never a re-serialized or schema-repaired object.
    return $json
}

function Assert-ArchivePlanExample {
    param([Parameter(Mandatory)][string]$DocPath, [Parameter(Mandatory)][string]$HelperPath)
    $json = Read-ArchivePlanExample -Path $DocPath
    $fx = New-FixtureRepo -NoGit
    try {
        New-Item -ItemType Directory -Path (Join-Path $fx '.claude') | Out-Null
        $source = Join-Path $fx '.cursorrules'
        $destination = Join-Path $fx 'docs/pre-adoption/.cursorrules'
        $bytes = [byte[]]@(0xEF, 0xBB, 0xBF, 0x61, 0x0D, 0x0A, 0x62, 0x0A, 0x00, 0xFF)
        [IO.File]::WriteAllBytes($source, $bytes)
        $marker = New-EvidenceFile -Path (Join-Path $fx '.claude/adoption-pending.json') -Entries @()
        $before = [Convert]::ToBase64String([IO.File]::ReadAllBytes($marker))
        $plan = Join-Path $fx '.claude/adoption-archive-plan.json'
        [IO.File]::WriteAllText($plan, $json, [Text.UTF8Encoding]::new($false))
        try {
            if (-not (Test-Path -LiteralPath $HelperPath -PathType Leaf)) { throw "helper unavailable: $HelperPath" }
            $frozen = Invoke-Aa -HelperPath $HelperPath -AaArgs @('-Freeze', '-RepoRoot', $fx, '-EvidencePath', $marker, '-PlanPath', $plan)
        } catch { throw "CANT-EXAMINE archive example execution: $($_.Exception.Message)" }
        if ($frozen.Exit -notin @(0, 3)) { throw "CANT-EXAMINE archive example: unexpected Freeze exit=$($frozen.Exit): $($frozen.Output)" }
        if ($frozen.Exit -ne 0) {
            Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($source)) -ceq [Convert]::ToBase64String($bytes)) 'failed Freeze changed source bytes'
            Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($marker)) -ceq $before) 'failed Freeze changed marker bytes'
            Assert (-not (Test-Path -LiteralPath $destination)) 'failed Freeze created destination'
            throw "EXAMPLE-FREEZE exit=$($frozen.Exit); unchanged source/marker; no destination: $($frozen.Output)"
        }
        $inventory = Get-Content -Raw -LiteralPath $marker | ConvertFrom-Json
        $entries = @($inventory.archiveIntegrity.entries)
        Assert ($entries.Count -eq 1) 'example did not freeze exactly one candidate'
        $entry = $entries[0]
        Assert ($entry.originalPath -ceq '.cursorrules' -and $entry.destination -ceq 'docs/pre-adoption/.cursorrules') 'example froze a different pair'
        Assert (-not $entry.verified -and $entry.byteLength -eq $bytes.Length -and $inventory.archiveIntegrity.frozenAt) 'example did not capture an unverified pre-move identity'
        Assert ((Test-Path -LiteralPath $source) -and -not (Test-Path -LiteralPath $destination)) 'Freeze moved source prematurely'
        $moved = Invoke-Aa -HelperPath $HelperPath -AaArgs @('-MoveFrozen', '-RepoRoot', $fx, '-EvidencePath', $marker, '-OriginalPath', '.cursorrules', '-Destination', 'docs/pre-adoption/.cursorrules')
        Assert ($moved.Exit -eq 0) "example MoveFrozen failed: $($moved.Output)"
        $verified = Invoke-Aa -HelperPath $HelperPath -AaArgs @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $marker)
        Assert ($verified.Exit -eq 0 -and $verified.Output -match 'RESULT: PASS') "example Verify failed: $($verified.Output)"
        Assert (-not (Test-Path -LiteralPath $source)) 'MoveFrozen left source behind'
        Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($destination)) -ceq [Convert]::ToBase64String($bytes)) 'example archive bytes differ'
    } finally { Remove-Fixture $fx }
}

function Write-Lines {
    param([string]$Path, [int]$Count, [string]$Prefix)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [IO.File]::WriteAllText($Path, ((1..$Count | ForEach-Object { "$Prefix $_" }) -join "`n"), [Text.UTF8Encoding]::new($false))
}

function Remove-Fixture {
    param([string]$Path)
    if ($Path -and (Test-Path -LiteralPath $Path) -and $Path.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase)) {
        try { Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop } catch { }
    }
}

Reset-Tests

foreach ($exampleStack in 'dotnet', 'angular', 'monorepo') {
    It "$exampleStack published archive-plan example freezes, moves and verifies exact bytes" {
        Assert-ArchivePlanExample -DocPath (Join-Path $script:RepoRoot "dist/$exampleStack/.claude/commands/adopt.md") -HelperPath (Join-Path $script:RepoRoot "dist/$exampleStack/scripts/adoption-archive.ps1")
    }
    It "$exampleStack bare-array example mutation makes the same instrument RED without mutation" {
        $docPath = Join-Path $script:RepoRoot "dist/$exampleStack/.claude/commands/adopt.md"
        $json = Read-ArchivePlanExample -Path $docPath
        $fx = New-FixtureRepo -NoGit
        try {
            # Mutate only the example in a scratch document; never repair its shape in the test.
            $doc = [IO.File]::ReadAllText($docPath)
            $bare = '[{ "originalPath": ".cursorrules", "destination": "docs/pre-adoption/.cursorrules" }]'
            $mutated = Join-Path $fx 'adopt.md'
            [IO.File]::WriteAllText($mutated, $doc.Replace($json, $bare))
            $failure = ''
            try { Assert-ArchivePlanExample -DocPath $mutated -HelperPath (Join-Path $script:RepoRoot "dist/$exampleStack/scripts/adoption-archive.ps1") }
            catch { $failure = $_.Exception.Message }
            Assert ($failure -match 'EXAMPLE-FREEZE exit=3; unchanged source/marker; no destination:' -and $failure -match 'has no entries array') "bare-array example did not cause the expected RED: $failure"
            Write-Host "OBSERVED RED $exampleStack bare array: Freeze exit=3; missing entries; unchanged source/marker; no destination"
            Assert-ArchivePlanExample -DocPath $docPath -HelperPath (Join-Path $script:RepoRoot "dist/$exampleStack/scripts/adoption-archive.ps1")
        } finally { Remove-Fixture $fx }
    }
}

It 'archive example extraction distinguishes document defects from inability to examine and ignores unrelated fences' {
    $fx = New-FixtureRepo -NoGit
    try {
        $path = Join-Path $fx 'adopt.md'
        $labelled = '<!-- archive-plan-example -->' + "`n" + '```json' + "`n{} `n" + '```'
        foreach ($bad in @('no example', ($labelled + "`n" + $labelled), '<!-- archive-plan-example -->', $labelled.Replace('{}', '{broken'))) {
            [IO.File]::WriteAllText($path, $bad)
            $failure = ''
            try { $null = Read-ArchivePlanExample -Path $path } catch { $failure = $_.Exception.Message }
            Assert ($failure -like 'DOC-DEFECT*') "malformed example not identified as document defect: $failure"
        }
        [IO.File]::WriteAllText($path, ('```json' + "`n[1]`n" + '```' + "`n" + $labelled + "`n" + '```text' + "`nunrelated`n" + '```'))
        Assert ((Read-ArchivePlanExample -Path $path) -ceq '{} ') 'unrelated fences changed extracted text'
        foreach ($unreadable in @((Join-Path $fx 'absent.md'), $fx)) {
            $failure = ''
            try { $null = Read-ArchivePlanExample -Path $unreadable } catch { $failure = $_.Exception.Message }
            Assert ($failure -like 'CANT-EXAMINE*') "unreadable document was conflated with bad content: $failure"
        }
    } finally { Remove-Fixture $fx }
}

It 'an unavailable archive helper is an examination failure, not a malformed example' {
    $failure = ''
    try { Assert-ArchivePlanExample -DocPath (Join-Path $script:DistRoot '.claude/commands/adopt.md') -HelperPath (Join-Path $script:DistRoot 'scripts/absent-archive-helper.ps1') }
    catch { $failure = $_.Exception.Message }
    Assert ($failure -like 'CANT-EXAMINE archive example execution:*helper unavailable:*') "missing helper misdiagnosed: $failure"
}

It 'the three shipped dist copies of the helper are byte-identical' {
    $dotnet = [IO.File]::ReadAllBytes($script:Helper)
    foreach ($stack in 'angular', 'monorepo') {
        $other = [IO.File]::ReadAllBytes((Join-Path $script:RepoRoot "dist/$stack/scripts/adoption-archive.ps1"))
        Assert ([Convert]::ToBase64String($other) -ceq [Convert]::ToBase64String($dotnet)) "dist/$stack helper differs from dist/dotnet"
    }
}

It 'every shipped adoption workflow freezes queued quarantines only in Phase 3 and carries the final guards' {
    foreach ($stack in 'dotnet', 'angular', 'monorepo') {
        $dist = Join-Path $script:RepoRoot "dist/$stack"
        $adopt = [IO.File]::ReadAllText((Join-Path $dist '.claude/commands/adopt.md'), [Text.Encoding]::UTF8)
        $prompt = [IO.File]::ReadAllText((Join-Path $dist '.github/prompts/adopt.prompt.md'), [Text.Encoding]::UTF8)
        $ownership = [IO.File]::ReadAllText((Join-Path $dist 'framework-ownership.json'), [Text.Encoding]::UTF8)
        $installer = [IO.File]::ReadAllText((Join-Path $dist 'scripts/install.ps1'), [Text.Encoding]::UTF8)
        foreach ($needle in @('archiveIntegrity', 'Pre-bootstrap archive verification', 'post-gate archive verification', 'RESULT: PASS', 'frozen complete inventory')) {
            Assert ($adopt.Contains($needle)) "dist/$stack /adopt does not carry archive-completion requirement: $needle"
        }
        $wikiQueue = $adopt.IndexOf('Queue flagged entry files for the Phase-3 frozen archive plan')
        $architectureQueue = $adopt.IndexOf('Queue a flagged file for the Phase-3 frozen archive plan')
        $phase3 = $adopt.IndexOf('## Phase 3 — Archive originals')
        $freeze = $adopt.IndexOf('-Freeze -RepoRoot .')
        Assert ($wikiQueue -ge 0 -and $architectureQueue -ge 0 -and $phase3 -gt $wikiQueue -and $phase3 -gt $architectureQueue -and $freeze -gt $phase3) "dist/$stack permits a Phase-1 quarantine move before Phase-3 Freeze"
        Assert ($adopt.Contains('Do not move a quarantined file during Phase 1') -and $adopt.Contains('do not move it during Phase 1')) "dist/$stack does not explicitly prohibit Phase-1 quarantine moves"
        Assert ($adopt.Contains('- `.cursorrules` → `docs/pre-adoption/.cursorrules`')) "dist/$stack does not preserve the live .cursorrules archive destination"
        Assert ($adopt -notmatch '(?m)^- `\.cursorrules` → `docs/pre-adoption/cursorrules\.md`') "dist/$stack presents a renamed .cursorrules destination as a new archive move"
        Assert ($installer -notmatch '(?i)/adopt deletes this file in its Phase 3|deleted in /adopt Phase 3') "dist/$stack installer retains the obsolete Phase-3 marker deletion lifecycle"
        Assert ($installer.Contains('deletes it only immediately before the Phase-7 bootstrap')) "dist/$stack installer does not state the Phase-7 marker lifecycle"
        foreach ($needle in @('.claude/adoption-archive-recovery.json', 'retain both `.claude/adoption-archive-plan.json`', 'verify both are absent before Phase 8')) {
            Assert ($adopt.Contains($needle)) "dist/$stack does not retain temporary archive evidence on failure and remove it on successful completion: $needle"
        }
        Assert ($prompt.Contains('scripts/adoption-archive.ps1') -and $prompt.Contains('frozen inventory')) "dist/$stack Copilot adapter omits archive-integrity completion guard"
        Assert ($ownership.Contains('scripts/adoption-archive.ps1')) "dist/$stack ownership manifest omits adoption-archive.ps1"
    }
}

It 'exact-copy, zero-byte and validated-empty inventories all verify PASS' {
    $fx = New-FixtureRepo
    try {
        [IO.File]::WriteAllText((Join-Path $fx 'a.txt'), 'ordinary content here')
        [IO.File]::WriteAllBytes((Join-Path $fx 'z.txt'), ([byte[]]::new(0)))
        Add-Commit -Repo $fx
        $e1 = Get-FrozenEntry -Root $fx -OriginalPath 'a.txt' -Destination 'docs/pre-adoption/a.txt'
        $e2 = Get-FrozenEntry -Root $fx -OriginalPath 'z.txt' -Destination 'docs/pre-adoption/z.txt'
        Assert ($e2.byteLength -eq 0) 'zero-byte candidate recorded a non-zero length'
        Assert ($e2.sha256 -ceq $script:EmptySha) 'zero-byte SHA-256 is wrong'
        $mp = New-EvidenceFile -Path (Join-Path $fx 'marker.json') -Entries @($e1, $e2)
        $v = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $mp)
        Assert ($v.Exit -eq 0 -and $v.Output -match 'RESULT: PASS') "exact/zero-byte verify not PASS: $($v.Output)"

        $empty = New-EvidenceFile -Path (Join-Path $fx 'empty.json') -Entries @()
        $ve = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $empty)
        Assert ($ve.Exit -eq 0 -and $ve.Output -match 'zero archived candidates') "validated empty inventory not explicit PASS: $($ve.Output)"
    } finally { Remove-Fixture $fx }
}

It 'workflow freezes its complete plan before any move, then only moves and verifies exact frozen pairs' {
    $fx = New-FixtureRepo
    try {
        [IO.File]::WriteAllText((Join-Path $fx 'legacy.md'), 'legacy merge candidate')
        [IO.File]::WriteAllText((Join-Path $fx 'docs-wiki.md'), 'flagged wiki candidate')
        Add-Commit -Repo $fx
        New-Item -ItemType Directory -Force -Path (Join-Path $fx '.claude') | Out-Null
        $marker = New-EvidenceFile -Path (Join-Path $fx '.claude/adoption-pending.json') -Entries @()
        $plan = New-ArchivePlanFile -Path (Join-Path $fx '.claude/adoption-archive-plan.json') -Entries @(
            [ordered]@{ originalPath = 'legacy.md'; destination = 'docs/pre-adoption/legacy.md' },
            [ordered]@{ originalPath = 'docs-wiki.md'; destination = 'docs/pre-adoption/quarantine/docs-wiki.md' }
        )
        $frozen = Invoke-Aa @('-Freeze', '-RepoRoot', $fx, '-EvidencePath', $marker, '-PlanPath', $plan)
        Assert ($frozen.Exit -eq 0 -and $frozen.Output -match 'FROZEN: 2') "workflow inventory did not freeze: $($frozen.Output)"
        $beforeMove = Get-Content -Raw -LiteralPath $marker | ConvertFrom-Json
        Assert (@($beforeMove.archiveIntegrity.entries).Count -eq 2 -and @($beforeMove.archivedOriginals).Count -eq 0) 'complete workflow inventory or pre-move legacy mapping state was not durable before the first move'
        Assert (@($beforeMove.archiveIntegrity.entries | Where-Object { $_.verified }).Count -eq 0) 'pre-move workflow entries were falsely marked verified'
        Assert (Test-Path -LiteralPath (Join-Path $fx 'legacy.md')) 'freeze moved a source before durable inventory capture'

        $m1 = Invoke-Aa @('-MoveFrozen', '-RepoRoot', $fx, '-EvidencePath', $marker, '-OriginalPath', 'legacy.md', '-Destination', 'docs/pre-adoption/legacy.md')
        $m2 = Invoke-Aa @('-MoveFrozen', '-RepoRoot', $fx, '-EvidencePath', $marker, '-OriginalPath', 'docs-wiki.md', '-Destination', 'docs/pre-adoption/quarantine/docs-wiki.md')
        Assert ($m1.Exit -eq 0 -and $m2.Exit -eq 0 -and $m2.Output -match 'MOVED') "frozen workflow moves failed: $($m1.Output) $($m2.Output)"
        $verified = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $marker)
        Assert ($verified.Exit -eq 0 -and $verified.Output -match 'RESULT: PASS') "complete frozen workflow inventory did not verify: $($verified.Output)"
    } finally { Remove-Fixture $fx }
}

It 'workflow Freeze extends an installer inventory and refreshes its identity before any workflow move' {
    $fx = New-FixtureRepo
    try {
        [IO.File]::WriteAllText((Join-Path $fx 'installer.txt'), 'installer original')
        [IO.File]::WriteAllText((Join-Path $fx 'workflow.txt'), 'workflow original')
        Add-Commit -Repo $fx
        $installerEntry = Get-Entry @('-Capture', '-RepoRoot', $fx, '-OriginalPath', 'installer.txt', '-Destination', 'docs/pre-adoption/installer.txt', '-Owner', 'installer')
        $installerEntry | Add-Member -NotePropertyName verified -NotePropertyValue $true
        New-Item -ItemType Directory -Force -Path (Join-Path $fx 'docs/pre-adoption') | Out-Null
        Move-Item -LiteralPath (Join-Path $fx 'installer.txt') -Destination (Join-Path $fx 'docs/pre-adoption/installer.txt')
        New-Item -ItemType Directory -Force -Path (Join-Path $fx '.claude') | Out-Null
        $marker = New-EvidenceFile -Path (Join-Path $fx '.claude/adoption-pending.json') -Entries @($installerEntry)
        $before = (Get-Content -Raw -LiteralPath $marker | ConvertFrom-Json).archiveIntegrity.inventoryIdentity.sha256
        $plan = New-ArchivePlanFile -Path (Join-Path $fx 'workflow-plan.json') -Entries @([ordered]@{ originalPath = 'workflow.txt'; destination = 'docs/pre-adoption/workflow.txt' })
        $freeze = Invoke-Aa @('-Freeze', '-RepoRoot', $fx, '-EvidencePath', $marker, '-PlanPath', $plan)
        Assert ($freeze.Exit -eq 0 -and (Test-Path -LiteralPath (Join-Path $fx 'workflow.txt'))) "Freeze moved a workflow source or refused the installer inventory: $($freeze.Output)"
        $afterMarker = Get-Content -Raw -LiteralPath $marker | ConvertFrom-Json
        Assert (@($afterMarker.archiveIntegrity.entries).Count -eq 2 -and $afterMarker.archiveIntegrity.inventoryIdentity.entryCount -eq 2 -and $afterMarker.archiveIntegrity.inventoryIdentity.sha256 -ne $before) 'workflow Freeze did not refresh the combined pre-move inventory identity'
        $move = Invoke-Aa @('-MoveFrozen', '-RepoRoot', $fx, '-EvidencePath', $marker, '-OriginalPath', 'workflow.txt', '-Destination', 'docs/pre-adoption/workflow.txt')
        Assert ($move.Exit -eq 0) "combined inventory workflow move failed: $($move.Output)"
        $verify = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $marker)
        Assert ($verify.Exit -eq 0 -and $verify.Output -match 'RESULT: PASS') "combined inventory no longer verifies: $($verify.Output)"
    } finally { Remove-Fixture $fx }
}

It 'a workflow inventory cannot be frozen again after a move, and its marker stays byte-identical' {
    $fx = New-FixtureRepo
    try {
        [IO.File]::WriteAllText((Join-Path $fx 'first.txt'), 'first frozen source')
        [IO.File]::WriteAllText((Join-Path $fx 'later.txt'), 'later source must not enter a refreshed inventory')
        Add-Commit -Repo $fx
        New-Item -ItemType Directory -Force -Path (Join-Path $fx '.claude') | Out-Null
        $marker = New-EvidenceFile -Path (Join-Path $fx '.claude/adoption-pending.json') -Entries @()
        $firstPlan = New-ArchivePlanFile -Path (Join-Path $fx '.claude/first-plan.json') -Entries @([ordered]@{ originalPath = 'first.txt'; destination = 'docs/pre-adoption/first.txt' })
        Assert ((Invoke-Aa @('-Freeze', '-RepoRoot', $fx, '-EvidencePath', $marker, '-PlanPath', $firstPlan)).Exit -eq 0) 'initial workflow Freeze failed'
        Assert ((Invoke-Aa @('-MoveFrozen', '-RepoRoot', $fx, '-EvidencePath', $marker, '-OriginalPath', 'first.txt', '-Destination', 'docs/pre-adoption/first.txt')).Exit -eq 0) 'initial frozen move failed'
        $before = [IO.File]::ReadAllBytes($marker)
        $secondPlan = New-ArchivePlanFile -Path (Join-Path $fx '.claude/second-plan.json') -Entries @([ordered]@{ originalPath = 'later.txt'; destination = 'docs/pre-adoption/later.txt' })
        $again = Invoke-Aa @('-Freeze', '-RepoRoot', $fx, '-EvidencePath', $marker, '-PlanPath', $secondPlan)
        Assert ($again.Exit -eq 3 -and $again.Output -match 'already frozen') "second workflow Freeze was not refused: $($again.Output)"
        Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($marker)) -ceq [Convert]::ToBase64String($before)) 'second Freeze changed the existing frozen marker'
        Assert ((Test-Path -LiteralPath (Join-Path $fx 'later.txt')) -and -not (Test-Path -LiteralPath (Join-Path $fx 'docs/pre-adoption/later.txt'))) 'second Freeze changed a later source or destination'
    } finally { Remove-Fixture $fx }
}

It 'relative evidence and plan paths resolve under RepoRoot rather than the caller working directory' {
    $fx = New-FixtureRepo
    $outside = Join-Path ([IO.Path]::GetTempPath()) ('aa-cwd-' + [guid]::NewGuid().ToString('N'))
    try {
        [IO.File]::WriteAllText((Join-Path $fx 'cwd.txt'), 'rooted evidence source')
        Add-Commit -Repo $fx
        New-Item -ItemType Directory -Force -Path (Join-Path $fx '.claude') | Out-Null
        [void](New-EvidenceFile -Path (Join-Path $fx '.claude/adoption-pending.json') -Entries @())
        [void](New-ArchivePlanFile -Path (Join-Path $fx '.claude/cwd-plan.json') -Entries @([ordered]@{ originalPath = 'cwd.txt'; destination = 'docs/pre-adoption/cwd.txt' }))
        New-Item -ItemType Directory -Force -Path $outside | Out-Null
        Push-Location $outside
        try {
            $freeze = Invoke-Aa @('-Freeze', '-RepoRoot', $fx, '-EvidencePath', '.claude/adoption-pending.json', '-PlanPath', '.claude/cwd-plan.json')
            Assert ($freeze.Exit -eq 0) "relative Freeze used the ambient cwd: $($freeze.Output)"
            $move = Invoke-Aa @('-MoveFrozen', '-RepoRoot', $fx, '-EvidencePath', '.claude/adoption-pending.json', '-OriginalPath', 'cwd.txt', '-Destination', 'docs/pre-adoption/cwd.txt')
            Assert ($move.Exit -eq 0) "relative MoveFrozen used the ambient cwd: $($move.Output)"
            $verify = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', '.claude/adoption-pending.json')
            Assert ($verify.Exit -eq 0 -and $verify.Output -match 'RESULT: PASS') "relative Verify used the ambient cwd: $($verify.Output)"
        } finally { Pop-Location }
    } finally { Remove-Fixture $fx; Remove-Fixture $outside }
}

It 'workflow refuses an absent or reduced marker instead of capturing an already-moved archive' {
    $fx = New-FixtureRepo
    try {
        [IO.File]::WriteAllText((Join-Path $fx 'candidate.md'), 'candidate bytes')
        Add-Commit -Repo $fx
        New-Item -ItemType Directory -Force -Path (Join-Path $fx 'docs/pre-adoption') | Out-Null
        [IO.File]::Move((Join-Path $fx 'candidate.md'), (Join-Path $fx 'docs/pre-adoption/candidate.md'))
        $plan = New-ArchivePlanFile -Path (Join-Path $fx 'plan.json') -Entries @([ordered]@{ originalPath = 'candidate.md'; destination = 'docs/pre-adoption/candidate.md' })
        $absent = Invoke-Aa @('-Freeze', '-RepoRoot', $fx, '-EvidencePath', (Join-Path $fx '.claude/adoption-pending.json'), '-PlanPath', $plan)
        Assert ($absent.Exit -eq 3 -and $absent.Output -match 'missing or not a regular file') "absent marker did not stop before a false baseline: $($absent.Output)"

        New-Item -ItemType Directory -Force -Path (Join-Path $fx '.claude') | Out-Null
        $marker = New-EvidenceFile -Path (Join-Path $fx '.claude/adoption-pending.json') -Entries @()
        $reduced = Invoke-Aa @('-MoveFrozen', '-RepoRoot', $fx, '-EvidencePath', $marker, '-OriginalPath', 'candidate.md', '-Destination', 'docs/pre-adoption/candidate.md')
        Assert ($reduced.Exit -eq 3 -and $reduced.Output -match 'no exact unique entry') "reduced marker was accepted as a workflow completion authority: $($reduced.Output)"
        Assert ([IO.File]::ReadAllText((Join-Path $fx 'docs/pre-adoption/candidate.md')) -eq 'candidate bytes') 'reduced-marker refusal changed the already moved archive'
    } finally { Remove-Fixture $fx }
}

It 'an interrupted frozen move recovers only an exact pre-frozen destination without rebaselining' {
    $fx = New-FixtureRepo
    try {
        [IO.File]::WriteAllText((Join-Path $fx 'resume.md'), 'frozen resume bytes')
        Add-Commit -Repo $fx
        New-Item -ItemType Directory -Force -Path (Join-Path $fx '.claude') | Out-Null
        $marker = New-EvidenceFile -Path (Join-Path $fx '.claude/adoption-pending.json') -Entries @()
        $plan = New-ArchivePlanFile -Path (Join-Path $fx 'resume-plan.json') -Entries @([ordered]@{ originalPath = 'resume.md'; destination = 'docs/pre-adoption/resume.md' })
        Assert ((Invoke-Aa @('-Freeze', '-RepoRoot', $fx, '-EvidencePath', $marker, '-PlanPath', $plan)).Exit -eq 0) 'could not freeze resume fixture'
        New-Item -ItemType Directory -Force -Path (Join-Path $fx 'docs/pre-adoption') | Out-Null
        [IO.File]::Move((Join-Path $fx 'resume.md'), (Join-Path $fx 'docs/pre-adoption/resume.md'))
        $recovered = Invoke-Aa @('-MoveFrozen', '-RepoRoot', $fx, '-EvidencePath', $marker, '-OriginalPath', 'resume.md', '-Destination', 'docs/pre-adoption/resume.md')
        Assert ($recovered.Exit -eq 0 -and $recovered.Output -match 'RECOVERED') "exact interrupted move did not recover: $($recovered.Output)"
        $markerAfter = Get-Content -Raw -LiteralPath $marker | ConvertFrom-Json
        Assert ($markerAfter.archiveIntegrity.entries[0].verified -eq $true -and @($markerAfter.archivedOriginals).Count -eq 1) 'recovery did not persist verified progress'
    } finally { Remove-Fixture $fx }
}

It 'a failed helper progress replacement leaves the original complete frozen marker readable' {
    $fx = New-FixtureRepo
    $mutatedHelper = $null
    try {
        [IO.File]::WriteAllText((Join-Path $fx 'write.txt'), 'progress-write source')
        Add-Commit -Repo $fx
        New-Item -ItemType Directory -Force -Path (Join-Path $fx '.claude') | Out-Null
        $marker = New-EvidenceFile -Path (Join-Path $fx '.claude/adoption-pending.json') -Entries @()
        $plan = New-ArchivePlanFile -Path (Join-Path $fx 'write-plan.json') -Entries @([ordered]@{ originalPath = 'write.txt'; destination = 'docs/pre-adoption/write.txt' })
        $freeze = Invoke-Aa @('-Freeze', '-RepoRoot', $fx, '-EvidencePath', $marker, '-PlanPath', $plan)
        Assert ($freeze.Exit -eq 0) "could not establish frozen marker for progress replacement test: $($freeze.Output)"
        $before = [IO.File]::ReadAllBytes($marker)
        $mutatedHelper = New-MutatedHelper -Find '[IO.File]::Replace($temporary, $full, $backup)' -Replacement "throw 'INJECTED-HELPER-PROGRESS-WRITE-FAILURE'"
        $move = Invoke-Aa -HelperPath $mutatedHelper -AaArgs @('-MoveFrozen', '-RepoRoot', $fx, '-EvidencePath', $marker, '-OriginalPath', 'write.txt', '-Destination', 'docs/pre-adoption/write.txt')
        Assert ($move.Exit -eq 3 -and $move.Output -match 'INJECTED-HELPER-PROGRESS-WRITE-FAILURE') "injected helper progress replacement did not stop move: $($move.Output)"
        $after = [IO.File]::ReadAllBytes($marker)
        Assert ([Convert]::ToBase64String($after) -ceq [Convert]::ToBase64String($before)) 'failed helper progress replacement changed the earlier frozen marker'
        $verify = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $marker)
        Assert ($verify.Exit -eq 5 -and $verify.Output -match 'unverified') "earlier helper marker is not readable with its original frozen identity: $($verify.Output)"
    } finally { Remove-Fixture $fx; Remove-Fixture $mutatedHelper }
}

It 'raw bytes survive Git CRLF conversion and non-ASCII; no blob comparison masquerades as byte equality' {
    $fx = New-FixtureRepo
    try {
        & git -C $fx config core.autocrlf true
        $raw = [Text.Encoding]::UTF8.GetBytes("sean cafe EUR`r`n" + (1..20 | ForEach-Object { "line $_`r`n" } | Out-String))
        [IO.File]::WriteAllBytes((Join-Path $fx 'crlf.txt'), $raw)
        Add-Commit -Repo $fx
        $rawSha = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($raw)).Replace('-', '').ToLowerInvariant()
        $blobSha = (& git -C $fx rev-parse 'HEAD:crlf.txt').Trim()
        $e = Get-FrozenEntry -Root $fx -OriginalPath 'crlf.txt' -Destination 'docs/pre-adoption/crlf.txt'
        Assert ($e.sha256 -ceq $rawSha) 'recorded SHA-256 is not the raw filesystem-byte digest'
        Assert ($e.sha256 -cne $blobSha) 'recorded SHA-256 equals the Git blob id (blob comparison masquerading as byte equality)'
        $archivedBytes = [IO.File]::ReadAllBytes((Join-Path $fx 'docs/pre-adoption/crlf.txt'))
        Assert ([Convert]::ToBase64String($archivedBytes) -ceq [Convert]::ToBase64String($raw)) 'archived bytes are not byte-identical to the pre-move raw bytes'
        $mp = New-EvidenceFile -Path (Join-Path $fx 'm.json') -Entries @($e)
        $v = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $mp)
        Assert ($v.Exit -eq 0 -and $v.Output -match 'RESULT: PASS') "CRLF/non-ASCII verify not PASS: $($v.Output)"
    } finally { Remove-Fixture $fx }
}

It 'normalization, one-byte same-length corruption and deletion each FAIL naming the candidate' {
    $fx = New-FixtureRepo
    try {
        foreach ($n in 'norm', 'flip', 'gone') { Write-Lines -Path (Join-Path $fx "$n.txt") -Count 30 -Prefix 'source line' }
        Add-Commit -Repo $fx
        $entries = foreach ($n in 'norm', 'flip', 'gone') {
            Get-FrozenEntry -Root $fx -OriginalPath "$n.txt" -Destination "docs/pre-adoption/$n.txt"
        }
        $mp = New-EvidenceFile -Path (Join-Path $fx 'm.json') -Entries $entries
        $clean = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $mp)
        Assert ($clean.Exit -eq 0) "freshly archived inventory did not verify PASS: $($clean.Output)"

        Write-Lines -Path (Join-Path $fx 'docs/pre-adoption/norm.txt') -Count 8 -Prefix 'normalized'
        $v1 = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $mp)
        Assert ($v1.Exit -eq 6 -and $v1.Output -match "FAIL: 'norm\.txt'" -and $v1.Output -match 'RESULT: FAIL') "normalization not rejected: $($v1.Output)"

        Write-Lines -Path (Join-Path $fx 'docs/pre-adoption/norm.txt') -Count 30 -Prefix 'source line'
        $b = [IO.File]::ReadAllBytes((Join-Path $fx 'docs/pre-adoption/flip.txt')); $b[5] = $b[5] -bxor 8
        [IO.File]::WriteAllBytes((Join-Path $fx 'docs/pre-adoption/flip.txt'), $b)
        $v2 = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $mp)
        Assert ($v2.Exit -eq 6 -and $v2.Output -match "FAIL: 'flip\.txt'.*SHA-256 changed") "same-length corruption not rejected: $($v2.Output)"

        Write-Lines -Path (Join-Path $fx 'docs/pre-adoption/flip.txt') -Count 30 -Prefix 'source line'
        [IO.File]::Delete((Join-Path $fx 'docs/pre-adoption/gone.txt'))
        $v3 = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $mp)
        Assert ($v3.Exit -eq 6 -and $v3.Output -match "FAIL: 'gone\.txt'.*missing") "deleted archive not rejected: $($v3.Output)"

        Write-Lines -Path (Join-Path $fx 'docs/pre-adoption/gone.txt') -Count 30 -Prefix 'source line'
        $v4 = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $mp)
        Assert ($v4.Exit -eq 0 -and $v4.Output -match 'RESULT: PASS') "fully-restored archives did not return to PASS: $($v4.Output)"
    } finally { Remove-Fixture $fx }
}

It 'a reduced marker is rejected by the initial frozen inventory identity, while a proper zero inventory can pass' {
    $fx = New-FixtureRepo
    try {
        foreach ($n in 'k1', 'k2') { Write-Lines -Path (Join-Path $fx "$n.txt") -Count 12 -Prefix 'x' }
        Add-Commit -Repo $fx
        $entries = foreach ($n in 'k1', 'k2') {
            Get-FrozenEntry -Root $fx -OriginalPath "$n.txt" -Destination "docs/pre-adoption/$n.txt"
        }
        $frozen = New-EvidenceFile -Path (Join-Path $fx 'frozen.json') -Entries $entries
        [IO.File]::Delete((Join-Path $fx 'docs/pre-adoption/k2.txt'))
        # A "helpful" regeneration drops the now-missing entry but does not possess the original
        # complete-set identity. It must not become a new completion authority.
        $regen = Join-Path $fx 'regen.json'
        $regenDocument = Get-Content -Raw -LiteralPath $frozen | ConvertFrom-Json
        $regenDocument.archiveIntegrity.entries = @($entries[0])
        $regenDocument.archivedOriginals = @($entries[0].destination)
        [IO.File]::WriteAllText($regen, ($regenDocument | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
        $vRegen = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $regen)
        Assert ($vRegen.Exit -eq 5 -and $vRegen.Output -match 'inventoryIdentity') "reduced marker became a verification authority: $($vRegen.Output)"
        $vFrozen = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $frozen)
        Assert ($vFrozen.Exit -eq 6 -and $vFrozen.Output -match "FAIL: 'k2\.txt'") "verifying against the frozen copy did not still require k2: $($vFrozen.Output)"

        $zero = New-EvidenceFile -Path (Join-Path $fx 'zero.json') -Entries @()
        $vZero = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $zero)
        Assert ($vZero.Exit -eq 0 -and $vZero.Output -match 'zero archived candidates') "proper zero inventory did not pass: $($vZero.Output)"
    } finally { Remove-Fixture $fx }
}

It 'a resumed/partial run does not rebaseline: an already verified frozen entry cannot move again and a failed inventory is CANT-VERIFY' {
    $fx = New-FixtureRepo
    try {
        [IO.File]::WriteAllText((Join-Path $fx 'r.txt'), 'original thirty-line content stand-in')
        Add-Commit -Repo $fx
        $e = Get-FrozenEntry -Root $fx -OriginalPath 'r.txt' -Destination 'docs/pre-adoption/r.txt'
        [IO.File]::WriteAllText((Join-Path $fx 'r.txt'), 'DIFFERENT CONTENT AFTER A CRASH')
        $again = Invoke-Aa @('-MoveFrozen', '-RepoRoot', $fx, '-EvidencePath', (Join-Path $fx '.claude/adoption-pending.json'), '-OriginalPath', 'r.txt', '-Destination', 'docs/pre-adoption/r.txt')
        Assert ($again.Exit -eq 3 -and $again.Output -match 'already verified') "re-move did not refuse: $($again.Output)"
        Assert ([IO.File]::ReadAllText((Join-Path $fx 'docs/pre-adoption/r.txt')) -eq 'original thirty-line content stand-in') 'the existing archive was overwritten by a resumed run'

        $failed = New-EvidenceFile -Path (Join-Path $fx 'failed.json') -Entries @($e) -Status 'failed'
        $vf = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $failed)
        Assert ($vf.Exit -eq 5 -and $vf.Output -match 'did not complete' -and $vf.Output -match 'RESULT: CANT-VERIFY') "failed inventory not CANT-VERIFY: $($vf.Output)"
    } finally { Remove-Fixture $fx }
}

It 'bootstrap changing an archive after capture makes the post-gate verify against the frozen preserved copy FAIL' {
    $fx = New-FixtureRepo
    try {
        Write-Lines -Path (Join-Path $fx 'c.txt') -Count 30 -Prefix 'line'
        Add-Commit -Repo $fx
        $e = Get-FrozenEntry -Root $fx -OriginalPath 'c.txt' -Destination 'docs/pre-adoption/c.txt'
        $preserved = New-EvidenceFile -Path (Join-Path $fx 'preserved-marker.json') -Entries @($e)
        $pre = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $preserved)
        Assert ($pre.Exit -eq 0) "pre-bootstrap verify should PASS: $($pre.Output)"
        [IO.File]::WriteAllText((Join-Path $fx 'docs/pre-adoption/c.txt'), 'bootstrap touched this archive')
        $post = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $preserved)
        Assert ($post.Exit -eq 6 -and $post.Output -match 'RESULT: FAIL') "post-gate verify against the frozen copy should FAIL: $($post.Output)"
    } finally { Remove-Fixture $fx }
}

It 'untracked input, missing/malformed/entryless evidence and a digest-less entry are distinct diagnostics, never PASS or corruption' {
    $fx = New-FixtureRepo
    try {
        [IO.File]::WriteAllText((Join-Path $fx 'u.txt'), 'never added to git')
        $cap = Get-Entry @('-Capture', '-RepoRoot', $fx, '-OriginalPath', 'u.txt', '-Destination', 'docs/pre-adoption/u.txt', '-Owner', 'workflow')
        Assert ($cap.provenance -eq 'untracked' -and $null -eq $cap.provenanceRevision -and $cap.localModification -eq 'unknown') "untracked provenance wrong: $($cap | ConvertTo-Json -Compress)"

        $missing = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', (Join-Path $fx 'nope.json'))
        Assert ($missing.Exit -eq 5 -and $missing.Output -match 'missing or not a regular file') "missing evidence not CANT-VERIFY: $($missing.Output)"

        $bad = Join-Path $fx 'bad.json'; [IO.File]::WriteAllText($bad, '{ not valid json ]')
        $vb = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $bad)
        Assert ($vb.Exit -eq 5 -and $vb.Output -match 'not valid JSON') "malformed evidence not CANT-VERIFY: $($vb.Output)"

        $noEntries = New-EvidenceFile -Path (Join-Path $fx 'noentries.json') -Entries @() -NoEntriesKey
        $vn = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $noEntries)
        Assert ($vn.Exit -eq 5 -and $vn.Output -match 'malformed') "integrity block without entries not CANT-VERIFY: $($vn.Output)"

        $shortSha = New-EvidenceFile -Path (Join-Path $fx 'nosha.json') -Entries @([pscustomobject]@{ originalPath = 'x'; destination = 'docs/pre-adoption/x'; owner = 'workflow' })
        $vs = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $shortSha)
        Assert ($vs.Exit -eq 5 -and $vs.Output -match 'required schemaVersion or owner|pre-move digest') "entry without a digest not CANT-VERIFY: $($vs.Output)"

        [IO.File]::WriteAllText((Join-Path $fx 'strict.txt'), 'strict verified state')
        Add-Commit -Repo $fx
        $strictEntry = Get-FrozenEntry -Root $fx -OriginalPath 'strict.txt' -Destination 'docs/pre-adoption/strict.txt'

        $provenanceMarker = New-EvidenceFile -Path (Join-Path $fx 'provenance-altered.json') -Entries @($strictEntry)
        $provenanceDocument = Get-Content -Raw -LiteralPath $provenanceMarker | ConvertFrom-Json
        $provenanceDocument.archiveIntegrity.entries[0].provenance = 'unavailable'
        [IO.File]::WriteAllText($provenanceMarker, ($provenanceDocument | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
        $vProvenance = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $provenanceMarker)
        Assert ($vProvenance.Exit -eq 5 -and $vProvenance.Output -match 'inventoryIdentity') "altered immutable provenance evidence was accepted: $($vProvenance.Output)"

        $removedProvenance = New-EvidenceFile -Path (Join-Path $fx 'provenance-removed.json') -Entries @($strictEntry)
        $removedDocument = Get-Content -Raw -LiteralPath $removedProvenance | ConvertFrom-Json
        [void]$removedDocument.archiveIntegrity.entries[0].PSObject.Properties.Remove('historyDepth')
        [IO.File]::WriteAllText($removedProvenance, ($removedDocument | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
        $vRemovedProvenance = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $removedProvenance)
        Assert ($vRemovedProvenance.Exit -eq 5 -and $vRemovedProvenance.Output -match 'provenance') "removed immutable provenance evidence was accepted: $($vRemovedProvenance.Output)"

        $wrongType = New-EvidenceFile -Path (Join-Path $fx 'wrong-type.json') -Entries @($strictEntry)
        $wrongTypeDocument = Get-Content -Raw -LiteralPath $wrongType | ConvertFrom-Json
        $wrongTypeDocument.archiveIntegrity.entries[0].byteLength = 'not-an-int64'
        [IO.File]::WriteAllText($wrongType, ($wrongTypeDocument | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
        $vWrongType = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $wrongType)
        Assert ($vWrongType.Exit -eq 5 -and $vWrongType.Output -match 'could not be structurally examined' -and $vWrongType.Output -match 'RESULT: CANT-VERIFY') "wrong JSON type escaped the CANT-VERIFY boundary: $($vWrongType.Output)"

        $strictEntry.verified = 'false'
        $stringVerified = New-EvidenceFile -Path (Join-Path $fx 'string-verified.json') -Entries @($strictEntry)
        $vStringVerified = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $stringVerified)
        Assert ($vStringVerified.Exit -eq 5 -and $vStringVerified.Output -match 'verified') "string verified state was accepted as evidence: $($vStringVerified.Output)"

        $locked = New-EvidenceFile -Path (Join-Path $fx 'locked.json') -Entries @()
        $lock = [IO.File]::Open($locked, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
        try {
            $vl = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $locked)
            Assert ($vl.Exit -eq 5 -and $vl.Output -match 'CANT-VERIFY') "unreadable evidence was not CANT-VERIFY: $($vl.Output)"
        } finally { $lock.Dispose() }
    } finally { Remove-Fixture $fx }
}

It 'path escape and an absolute destination are refused before any mutation' {
    $fx = New-FixtureRepo
    try {
        [IO.File]::WriteAllText((Join-Path $fx 'e.txt'), 'x')
        Add-Commit -Repo $fx
        $before = [IO.File]::ReadAllText((Join-Path $fx 'e.txt'))
        New-Item -ItemType Directory -Force -Path (Join-Path $fx '.claude') | Out-Null
        $marker = New-EvidenceFile -Path (Join-Path $fx '.claude/adoption-pending.json') -Entries @()
        $escapePlan = New-ArchivePlanFile -Path (Join-Path $fx 'escape.json') -Entries @([ordered]@{ originalPath = 'e.txt'; destination = '../escape.txt' })
        $esc = Invoke-Aa @('-Freeze', '-RepoRoot', $fx, '-EvidencePath', $marker, '-PlanPath', $escapePlan)
        Assert ($esc.Exit -eq 3 -and $esc.Output -match 'unsafe or non-normalized path|escapes the repository') "path escape not refused: $($esc.Output)"
        Assert ([IO.File]::ReadAllText((Join-Path $fx 'e.txt')) -eq $before) 'source mutated despite refusal'
        $absolutePlan = New-ArchivePlanFile -Path (Join-Path $fx 'absolute.json') -Entries @([ordered]@{ originalPath = 'e.txt'; destination = 'C:/Windows/Temp/x.txt' })
        $abs = Invoke-Aa @('-Freeze', '-RepoRoot', $fx, '-EvidencePath', $marker, '-PlanPath', $absolutePlan)
        Assert ($abs.Exit -eq 3) 'absolute destination not refused'
        Assert (-not (Test-Path -LiteralPath (Join-Path $fx 'docs/pre-adoption'))) 'archive dir created despite refusal'

        New-Item -ItemType Directory -Force -Path (Join-Path $fx 'docs/pre-adoption') | Out-Null
        [IO.File]::WriteAllText((Join-Path $fx 'docs/pre-adoption/already.txt'), 'existing archive must never be captured again')
        $archiveSourcePlan = New-ArchivePlanFile -Path (Join-Path $fx 'archive-source.json') -Entries @([ordered]@{ originalPath = 'docs/pre-adoption/already.txt'; destination = 'docs/pre-adoption/deeper/already.txt' })
        $archiveSource = Invoke-Aa @('-Freeze', '-RepoRoot', $fx, '-EvidencePath', $marker, '-PlanPath', $archiveSourcePlan)
        Assert ($archiveSource.Exit -eq 3 -and $archiveSource.Output -match 'already an archive path') "existing archive source was eligible for rebaselining: $($archiveSource.Output)"
        Assert ([IO.File]::ReadAllText((Join-Path $fx 'docs/pre-adoption/already.txt')) -eq 'existing archive must never be captured again') 'existing archive changed despite source rejection'
    } finally { Remove-Fixture $fx }
}

It 'an existing archive destination and reparse-point source or destination are refused before mutation' {
    $fx = New-FixtureRepo
    $outside = Join-Path ([IO.Path]::GetTempPath()) ('aa-outside-' + [guid]::NewGuid().ToString('N'))
    try {
        [IO.File]::WriteAllText((Join-Path $fx 'e.txt'), 'source sentinel')
        Add-Commit -Repo $fx
        New-Item -ItemType Directory -Force -Path (Join-Path $fx 'docs/pre-adoption') | Out-Null
        [IO.File]::WriteAllText((Join-Path $fx 'docs/pre-adoption/e.txt'), 'existing archive sentinel')
        New-Item -ItemType Directory -Force -Path (Join-Path $fx '.claude') | Out-Null
        $marker = New-EvidenceFile -Path (Join-Path $fx '.claude/adoption-pending.json') -Entries @()
        $collisionPlan = New-ArchivePlanFile -Path (Join-Path $fx 'collision.json') -Entries @([ordered]@{ originalPath = 'e.txt'; destination = 'docs/pre-adoption/e.txt' })
        $collision = Invoke-Aa @('-Freeze', '-RepoRoot', $fx, '-EvidencePath', $marker, '-PlanPath', $collisionPlan)
        Assert ($collision.Exit -eq 3 -and $collision.Output -match 'destination already exists') "archive collision not refused: $($collision.Output)"
        Assert ([IO.File]::ReadAllText((Join-Path $fx 'e.txt')) -eq 'source sentinel') 'source moved despite archive-destination collision'
        Assert ([IO.File]::ReadAllText((Join-Path $fx 'docs/pre-adoption/e.txt')) -eq 'existing archive sentinel') 'existing archive changed despite collision refusal'

        Remove-Item -LiteralPath (Join-Path $fx 'docs/pre-adoption') -Recurse -Force
        New-Item -ItemType Directory -Force -Path $outside | Out-Null
        New-Item -ItemType Junction -Path (Join-Path $fx 'docs/pre-adoption') -Target $outside | Out-Null
        $linkPlan = New-ArchivePlanFile -Path (Join-Path $fx 'link.json') -Entries @([ordered]@{ originalPath = 'e.txt'; destination = 'docs/pre-adoption/e.txt' })
        $destinationLink = Invoke-Aa @('-Freeze', '-RepoRoot', $fx, '-EvidencePath', $marker, '-PlanPath', $linkPlan)
        Assert ($destinationLink.Exit -eq 3 -and $destinationLink.Output -match 'reparse point') "destination reparse not refused: $($destinationLink.Output)"
        Assert ([IO.File]::ReadAllText((Join-Path $fx 'e.txt')) -eq 'source sentinel') 'source moved through destination reparse point'
        Assert (@(Get-ChildItem -LiteralPath $outside -Force -ErrorAction SilentlyContinue).Count -eq 0) 'destination reparse wrote outside the fixture repository'
        Remove-Item -LiteralPath (Join-Path $fx 'docs/pre-adoption') -Force
        New-Item -ItemType Directory -Force -Path (Join-Path $outside 'source-link') | Out-Null
        [IO.File]::WriteAllText((Join-Path $outside 'source-link/e.txt'), 'outside source sentinel')
        New-Item -ItemType Junction -Path (Join-Path $fx 'linked') -Target (Join-Path $outside 'source-link') | Out-Null
        $sourcePlan = New-ArchivePlanFile -Path (Join-Path $fx 'source-link.json') -Entries @([ordered]@{ originalPath = 'linked/e.txt'; destination = 'docs/pre-adoption/linked/e.txt' })
        $sourceLink = Invoke-Aa @('-Freeze', '-RepoRoot', $fx, '-EvidencePath', $marker, '-PlanPath', $sourcePlan)
        Assert ($sourceLink.Exit -eq 3 -and $sourceLink.Output -match 'reparse point') "source reparse not refused: $($sourceLink.Output)"
        Assert ([IO.File]::ReadAllText((Join-Path $outside 'source-link/e.txt')) -eq 'outside source sentinel') 'source reparse was followed or changed'
    } finally { Remove-Fixture $fx; Remove-Fixture $outside }
}

It 'modified, shallow and unavailable Git examination remain distinct provenance states' {
    $fx = New-FixtureRepo
    $shallow = Join-Path ([IO.Path]::GetTempPath()) ('aa-shallow-' + [guid]::NewGuid().ToString('N'))
    $priorGitDir = [Environment]::GetEnvironmentVariable('GIT_DIR', 'Process')
    try {
        [IO.File]::WriteAllText((Join-Path $fx 'tracked.txt'), 'committed bytes')
        Add-Commit -Repo $fx
        $commit = (& git -C $fx rev-parse HEAD).Trim()
        [IO.File]::WriteAllText((Join-Path $fx 'tracked.txt'), 'locally modified raw bytes')
        $modified = Get-Entry @('-Capture', '-RepoRoot', $fx, '-OriginalPath', 'tracked.txt', '-Destination', 'docs/pre-adoption/tracked.txt', '-Owner', 'workflow')
        Assert ($modified.provenance -eq 'tracked' -and $modified.localModification -eq 'modified' -and $modified.provenanceRevision -eq $commit) "modified tracked provenance wrong: $($modified | ConvertTo-Json -Compress)"

        & git clone -q --depth 1 (('file:///' + ($fx -replace '\\', '/'))) $shallow
        Assert ($LASTEXITCODE -eq 0) 'could not create shallow local fixture'
        $shallowEntry = Get-Entry @('-Capture', '-RepoRoot', $shallow, '-OriginalPath', 'tracked.txt', '-Destination', 'docs/pre-adoption/tracked.txt', '-Owner', 'workflow')
        Assert ($shallowEntry.provenance -eq 'tracked' -and $shallowEntry.historyDepth -eq 'shallow') "shallow history was not disclosed: $($shallowEntry | ConvertTo-Json -Compress)"

        $env:GIT_DIR = Join-Path $fx 'not-a-git-dir'
        $unavailable = Get-Entry @('-Capture', '-RepoRoot', $fx, '-OriginalPath', 'tracked.txt', '-Destination', 'docs/pre-adoption/unavailable.txt', '-Owner', 'workflow')
        Assert ($unavailable.provenance -eq 'unavailable' -and $unavailable.historyDepth -eq 'unavailable' -and $unavailable.localModification -eq 'unknown') "unavailable Git was misreported as a provenance fact: $($unavailable | ConvertTo-Json -Compress)"
    } finally {
        if ([string]::IsNullOrEmpty($priorGitDir)) {
            Remove-Item -LiteralPath Env:GIT_DIR -ErrorAction SilentlyContinue
        } else {
            $env:GIT_DIR = $priorGitDir
        }
        Remove-Fixture $fx
        Remove-Fixture $shallow
    }
}

It 'the brownfield installer freezes provenance at the pre-install revision and greenfield writes no archiveIntegrity' {
    $bf = New-FixtureRepo
    $gf = New-FixtureRepo
    try {
        New-Item -ItemType Directory -Force -Path (Join-Path $bf '.github') | Out-Null
        [IO.File]::WriteAllText((Join-Path $bf 'CLAUDE.md'), "# consumer claude`n" + ((1..25 | ForEach-Object { "rule $_" }) -join "`n"))
        [IO.File]::WriteAllText((Join-Path $bf '.github/copilot-instructions.md'), "consumer copilot`n")
        [IO.File]::WriteAllText((Join-Path $bf 'Smoke.csproj'), '<Project />')
        Add-Commit -Repo $bf
        $preInstall = (& git -C $bf rev-parse HEAD).Trim()
        $r = Invoke-Installer -Target $bf
        Assert ($r.Exit -eq 0) "brownfield install failed: $($r.Output)"
        $marker = Get-Content -Raw -LiteralPath (Join-Path $bf '.claude/adoption-pending.json') | ConvertFrom-Json
        Assert ($marker.archiveIntegrity.inventoryStatus -eq 'complete') 'installer marker inventory not complete'
        Assert ($marker.archiveIntegrity.inventoryIdentity.entryCount -eq @($marker.archiveIntegrity.entries).Count -and $marker.archiveIntegrity.inventoryIdentity.sha256 -match '^[0-9a-f]{64}$') 'installer did not persist its complete frozen inventory identity'
        Assert ($marker.archiveIntegrity.baselineRevision -eq $preInstall) 'baselineRevision is not the committed pre-install HEAD'
        $claude = @($marker.archiveIntegrity.entries | Where-Object { $_.originalPath -eq 'CLAUDE.md' })[0]
        Assert ($null -ne $claude) 'installer did not record a CLAUDE.md integrity entry'
        Assert ($claude.owner -eq 'installer' -and $claude.provenance -eq 'tracked') 'installer entry provenance is not tracked'
        Assert ($claude.provenanceRevision -eq $preInstall) 'provenanceRevision is not the pre-install commit that last touched CLAUDE.md'
        Assert ($claude.verified -eq $true -and $claude.sha256 -match '^[0-9a-f]{64}$') 'installer did not verify the archived bytes'
        Assert (@($marker.archivedOriginals).Count -eq @($marker.archiveIntegrity.entries).Count) 'legacy archivedOriginals array diverged from the integrity entries'
        [IO.File]::WriteAllText((Join-Path $bf 'CLAUDE.md'), '# framework template placeholder')
        Add-Commit -Repo $bf 'framework install'
        $v = Invoke-Aa @('-Verify', '-RepoRoot', $bf, '-EvidencePath', (Join-Path $bf '.claude/adoption-pending.json'))
        Assert ($v.Exit -eq 0 -and $v.Output -match 'RESULT: PASS') "verify after framework replacement not PASS: $($v.Output)"

        [IO.File]::WriteAllText((Join-Path $gf 'Smoke.csproj'), '<Project />')
        Add-Commit -Repo $gf
        $rg = Invoke-Installer -Target $gf
        Assert ($rg.Exit -eq 0) "greenfield install failed: $($rg.Output)"
        Assert (-not (Test-Path -LiteralPath (Join-Path $gf '.claude/adoption-pending.json'))) 'greenfield install wrote an adoption marker'
    } finally { Remove-Fixture $bf; Remove-Fixture $gf }
}

It 'installer move failure retains the complete frozen inventory before any archive evidence can be lost' {
    $fx = New-FixtureRepo
    $source = $null
    try {
        [IO.File]::WriteAllText((Join-Path $fx 'CLAUDE.md'), 'consumer archive source')
        [IO.File]::WriteAllText((Join-Path $fx 'Smoke.csproj'), '<Project />')
        Add-Commit -Repo $fx
        $source = New-MutatedInstallerSource -Find 'Move-Item -LiteralPath $entry.Original -Destination $entry.Destination' -Replacement "throw 'INJECTED-MOVE-FAILURE'"
        $result = Invoke-InstallerFrom -InstallerPath (Join-Path $source 'scripts/install.ps1') -Target $fx
        Assert ($result.Exit -ne 0 -and $result.Output -match 'INJECTED-MOVE-FAILURE') "injected move failure did not stop installer: $($result.Output)"
        $markerPath = Join-Path $fx '.claude/adoption-pending.json'
        Assert (Test-Path -LiteralPath $markerPath) 'move failure lost the pre-move marker'
        $marker = Get-Content -Raw -LiteralPath $markerPath | ConvertFrom-Json
        Assert ($marker.archiveIntegrity.inventoryStatus -eq 'failed' -and @($marker.archiveIntegrity.entries).Count -gt 0) 'move failure did not retain complete frozen entries as failed state'
        Assert (@($marker.archiveIntegrity.entries | Where-Object { -not $_.verified }).Count -gt 0 -and @($marker.archivedOriginals).Count -eq 0) 'move failure falsely recorded a completed archive mapping'
    } finally { Remove-Fixture $fx; Remove-Fixture $source }
}

It 'a failed installer progress replacement leaves the earlier complete frozen marker readable' {
    $fx = New-FixtureRepo
    $source = $null
    try {
        [IO.File]::WriteAllText((Join-Path $fx 'CLAUDE.md'), 'consumer archive source')
        [IO.File]::WriteAllText((Join-Path $fx 'Smoke.csproj'), '<Project />')
        Add-Commit -Repo $fx
        $replacement = @'
if (@($archiveEvidence | Where-Object { $_.verified }).Count -gt 0) { throw 'INJECTED-PROGRESS-WRITE-FAILURE' }
            [IO.File]::Replace($temporary, $markerPath, $backup)
'@
        $source = New-MutatedInstallerSource -Find '[IO.File]::Replace($temporary, $markerPath, $backup)' -Replacement $replacement
        $result = Invoke-InstallerFrom -InstallerPath (Join-Path $source 'scripts/install.ps1') -Target $fx
        Assert ($result.Exit -ne 0 -and $result.Output -match 'INJECTED-PROGRESS-WRITE-FAILURE') "injected progress-write failure did not stop installer: $($result.Output)"
        $markerPath = Join-Path $fx '.claude/adoption-pending.json'
        $marker = Get-Content -Raw -LiteralPath $markerPath | ConvertFrom-Json
        Assert ($marker.archiveIntegrity.inventoryStatus -eq 'complete' -and @($marker.archiveIntegrity.entries).Count -gt 0 -and @($marker.archiveIntegrity.entries | Where-Object { -not $_.verified }).Count -eq @($marker.archiveIntegrity.entries).Count) 'failed progress replacement did not leave the earlier full frozen marker intact'
        $verify = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $markerPath)
        Assert ($verify.Exit -eq 5 -and $verify.Output -match 'unverified') "earlier frozen marker was not readable/structurally valid after progress replacement failure: $($verify.Output)"
    } finally { Remove-Fixture $fx; Remove-Fixture $source }
}

It 'a failure after archive moves retains verified complete evidence for human recovery' {
    $fx = New-FixtureRepo
    $source = $null
    try {
        [IO.File]::WriteAllText((Join-Path $fx 'CLAUDE.md'), 'consumer archive source')
        [IO.File]::WriteAllText((Join-Path $fx 'Smoke.csproj'), '<Project />')
        Add-Commit -Repo $fx
        $source = New-MutatedInstallerSource -Find 'Copy-Item -Force -LiteralPath (Join-Path $src $relative) -Destination $destination' -Replacement "throw 'INJECTED-POST-ARCHIVE-FAILURE'"
        $result = Invoke-InstallerFrom -InstallerPath (Join-Path $source 'scripts/install.ps1') -Target $fx
        Assert ($result.Exit -ne 0 -and $result.Output -match 'INJECTED-POST-ARCHIVE-FAILURE') "injected post-archive failure did not stop installer: $($result.Output)"
        $markerPath = Join-Path $fx '.claude/adoption-pending.json'
        Assert (Test-Path -LiteralPath $markerPath) 'post-archive failure lost the frozen marker'
        $marker = Get-Content -Raw -LiteralPath $markerPath | ConvertFrom-Json
        Assert ($marker.archiveIntegrity.inventoryStatus -eq 'complete' -and @($marker.archiveIntegrity.entries).Count -gt 0) 'post-archive failure did not retain complete frozen evidence'
        Assert (@($marker.archiveIntegrity.entries | Where-Object { -not $_.verified }).Count -eq 0 -and @($marker.archivedOriginals).Count -eq @($marker.archiveIntegrity.entries).Count) 'post-archive failure did not retain every verified mapping'
    } finally { Remove-Fixture $fx; Remove-Fixture $source }
}

It 'a legacy marker with archivedOriginals but no archiveIntegrity is CANT-VERIFY and is never re-hashed' {
    $fx = New-FixtureRepo
    try {
        New-Item -ItemType Directory -Force -Path (Join-Path $fx 'docs/pre-adoption') | Out-Null
        [IO.File]::WriteAllText((Join-Path $fx 'docs/pre-adoption/CLAUDE.md'), 'archived long ago, provenance unknown')
        $legacy = New-EvidenceFile -Path (Join-Path $fx 'legacy.json') -Entries @([pscustomobject]@{ destination = 'docs/pre-adoption/CLAUDE.md' }) -Legacy
        $v = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $legacy)
        Assert ($v.Exit -eq 5 -and $v.Output -match 'legacy adoption marker' -and $v.Output -match 'Do NOT re-hash') "legacy marker not CANT-VERIFY: $($v.Output)"
        Assert ($v.Output -notmatch 'RESULT: PASS') 'legacy marker produced a PASS'
    } finally { Remove-Fixture $fx }
}

It 'usage errors are exit 2 and exactly one mode is enforced' {
    $none = Invoke-Aa @('-RepoRoot', $script:RepoRoot)
    Assert ($none.Exit -eq 2 -and $none.Output -match 'exactly one of') 'missing mode not a usage error'
    $two = Invoke-Aa @('-Capture', '-Verify', '-RepoRoot', $script:RepoRoot, '-EvidencePath', 'x')
    Assert ($two.Exit -eq 2) 'two modes not a usage error'
    $noEv = Invoke-Aa @('-Verify', '-RepoRoot', $script:RepoRoot)
    Assert ($noEv.Exit -eq 2 -and $noEv.Output -match 'requires -EvidencePath') 'verify without evidence not a usage error'
    $fx = New-FixtureRepo
    try {
        [IO.File]::WriteAllText((Join-Path $fx 'x'), 'legacy-mode-candidate')
        $removedArchive = Invoke-Aa @('-Archive', '-RepoRoot', $fx, '-OriginalPath', 'x', '-Destination', 'docs/pre-adoption/x')
        Assert ($removedArchive.Exit -eq 2 -and $removedArchive.Output -match 'exactly one of') 'the unsafe legacy Archive mode is still callable'
        Assert ((Test-Path -LiteralPath (Join-Path $fx 'x')) -and -not (Test-Path -LiteralPath (Join-Path $fx 'docs/pre-adoption/x'))) 'the removed Archive mode mutated a candidate'
    } finally { Remove-Fixture $fx }
}

if (-not $env:AA_SKIP_MUTATION) {
    It 'RELEASE RED: disabling the SHA-256 comparison lets a same-length corruption pass, and this suite catches that' {
        $fx = New-FixtureRepo
        try {
            [IO.File]::WriteAllText((Join-Path $fx 'm.txt'), 'exactly this many bytes of stand-in content!!')
            Add-Commit -Repo $fx
            $entry = Get-FrozenEntry -Root $fx -OriginalPath 'm.txt' -Destination 'docs/pre-adoption/m.txt'
            $mp = New-EvidenceFile -Path (Join-Path $fx 'm.json') -Entries @($entry)
            $arch = Join-Path $fx 'docs/pre-adoption/m.txt'
            $bytes = [IO.File]::ReadAllBytes($arch); $bytes[4] = $bytes[4] -bxor 1; [IO.File]::WriteAllBytes($arch, $bytes)
            $clean = Invoke-Aa @('-Verify', '-RepoRoot', $fx, '-EvidencePath', $mp)
            Assert ($clean.Exit -eq 6) "clean verifier failed to reject a same-length corruption: $($clean.Output)"
            $capturedFx = $fx
            $capturedMp = $mp
            $currentPsExe = Get-PsExe
            $redBlock = {
                param($scratchTarget, $scratchRoot)
                $o = & $currentPsExe -NoProfile -File $scratchTarget -Verify -RepoRoot $capturedFx -EvidencePath $capturedMp 2>&1 | Out-String
                $mutatedExit = [int]$LASTEXITCODE
                if ($mutatedExit -eq 6) { $global:LASTEXITCODE = 0 } else { $global:LASTEXITCODE = 42 }
            }.GetNewClosure()
            Invoke-MutationRedTest -TargetFile $script:Helper -ScratchSourceRoot $script:DistRoot `
                -Find 'if ($actualSha -cne $ExpectedSha.ToLowerInvariant()) {' -Replacement 'if ($false) {' `
                -ExpectedExit 42 -Command $redBlock | Out-Null
        } finally { Remove-Fixture $fx }
    }
} else {
    Skip 'RELEASE RED: disabling the SHA-256 comparison lets a same-length corruption pass, and this suite catches that' 'AA_SKIP_MUTATION set'
}

exit (Write-TestSummary 'AdoptionArchiveIntegrity.Tests')
