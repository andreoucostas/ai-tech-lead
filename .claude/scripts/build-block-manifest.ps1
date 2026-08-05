#requires -Version 7.0
<#
.SYNOPSIS
  Builds the framework-owned block fingerprint manifest from git history (B-97).

.DESCRIPTION
  The installer protects CLAUDE.md and AGENTS.md on update (scripts/install.ps1 $protected), so a
  consumer keeps their own copy and never receives framework-owned block changes. Nothing on disk
  can currently tell whether their copy is old or deliberately edited.

  This walks the release tags, extracts each framework-owned block from the shipped files at that
  release, normalises and hashes it, and emits a manifest mapping every historical hash to the
  release range it was current for. A consumer-side check can then classify their file as
  CURRENT / BEHIND (naming the release) / DIVERGED, instead of guessing.

  Only blocks that /bootstrap is documented NOT to rewrite are fingerprinted. Bootstrap replaces
  Codebase Context, Repository Structure, Conventions, Architecture Decisions, Common Tasks and
  Boy Scout Rule with observed findings (bootstrap.md Phase 3a), and preserves Agentic Workflow
  as-is. Fingerprinting a bootstrap-populated block would report DIVERGED for every consumer and
  mean nothing.

  Meta script: PowerShell-only by decision (WSD-005). Never ships.

.PARAMETER OutFile
  Where to write the manifest. Defaults to meta/block-manifest.json.

.PARAMETER Dist
  Which dists to cover. Defaults to all three.

.PARAMETER SelfTest
  Red-tests the instrument instead of building. Proves the two properties the manifest depends on:
  formatting-only edits must NOT move a hash (or every Windows consumer reports DIVERGED), and a
  content edit MUST move it (or the check cannot detect staleness at all). Exits non-zero on
  failure. Per CLAUDE.md Maintenance model #4, a green manifest means nothing unless this has been
  seen to go red.
#>
[CmdletBinding()]
param(
    [string]$OutFile = (Join-Path $PSScriptRoot '..\..\meta\block-manifest.json'),
    [string[]]$Dist  = @('dotnet', 'angular', 'monorepo'),
    [string[]]$File  = @('CLAUDE.md', 'AGENTS.md'),
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'

# Blocks /bootstrap does not rewrite. Keep this list in step with bootstrap.md Phase 3a — if a
# block moves into bootstrap's remit, drop it here or the manifest starts lying.
$frameworkBlocks = @('Verification Rules', 'Leanness', 'SOLID', 'Agentic Workflow')

# git show decodes through the console encoding; without this, non-ASCII (em dashes, arrows) is
# mangled and every hash is wrong in a way that still looks like a clean run.
$prevEncoding = [Console]::OutputEncoding
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

function Get-NormalizedBlock {
    <#
      Extracts one '## <Name>' section, up to the next '## ' or EOF, and normalises it so that
      formatting-only differences (line endings, BOM, trailing whitespace) do not change the hash.
      Returns $null when the heading is absent — that is a real answer, not an error: a consumer
      who renamed or deleted a heading classifies as DIVERGED.
    #>
    param([string]$Text, [string]$BlockName)

    if ([string]::IsNullOrEmpty($Text)) { return $null }

    $normalized = $Text -replace "`r`n", "`n" -replace "`r", "`n"
    $normalized = $normalized.TrimStart([char]0xFEFF)
    $lines = $normalized -split "`n"

    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].TrimEnd() -eq "## $BlockName") { $start = $i; break }
    }
    if ($start -lt 0) { return $null }

    $end = $lines.Count
    for ($i = $start + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^## ') { $end = $i; break }
    }

    $body = $lines[$start..($end - 1)] | ForEach-Object { $_.TrimEnd() }
    return (($body -join "`n").Trim())
}

function Get-BlockHash {
    param([string]$Content)
    $bytes  = [Text.UTF8Encoding]::new($false).GetBytes($Content)
    $sha    = [Security.Cryptography.SHA256]::Create()
    try   { return ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').Substring(0, 16).ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Invoke-SelfTest {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
    $live     = Join-Path $repoRoot 'dist/dotnet/CLAUDE.md'
    if (-not (Test-Path -LiteralPath $live)) { throw "Fixture missing: $live" }
    $text = [IO.File]::ReadAllText($live)

    $fail = 0
    function Assert([bool]$Cond, [string]$Name, [string]$Detail) {
        if ($Cond) { Write-Host "  [PASS] $Name" }
        else       { Write-Host "  [FAIL] $Name -- $Detail"; $script:selfTestFailures++ }
    }
    $script:selfTestFailures = 0

    Write-Host 'Self-test: block extraction and hashing'

    # 1. Every fingerprinted block must actually be found in the shipped file. If a heading is
    #    renamed upstream this silently yields an empty manifest, which looks like a clean run.
    foreach ($b in $frameworkBlocks) {
        $block = Get-NormalizedBlock -Text $text -BlockName $b
        Assert ($null -ne $block -and $block.Length -gt 40) "block present and non-trivial: $b" `
               "extracted $(if ($null -eq $block) { '<null>' } else { "$($block.Length) chars" })"
    }

    # 2. A block must not bleed into the next section.
    $vr = Get-NormalizedBlock -Text $text -BlockName 'Verification Rules'
    Assert (-not ($vr -match '(?m)^## Leanness')) 'block stops at the next heading' 'Verification Rules swallowed the following section'

    # 3. Formatting-only mutation must NOT move the hash. This is the property that stops the
    #    check crying wolf at every CRLF consumer.
    $baseline  = Get-BlockHash (Get-NormalizedBlock -Text $text -BlockName 'SOLID')
    $crlf      = $text -replace "`n", "`r`n"
    $trailing  = ($text -split "`n" | ForEach-Object { $_ + '   ' }) -join "`n"
    $bom       = [string][char]0xFEFF + $text
    foreach ($case in @(@{n='CRLF line endings';t=$crlf}, @{n='trailing whitespace';t=$trailing}, @{n='leading BOM';t=$bom})) {
        $h = Get-BlockHash (Get-NormalizedBlock -Text $case.t -BlockName 'SOLID')
        Assert ($h -eq $baseline) "formatting-only edit keeps hash stable: $($case.n)" "$h != $baseline"
    }

    # 4. A CONTENT mutation MUST move the hash. This is the defect class the manifest exists to
    #    catch -- without it the check reports CURRENT for a stale file.
    $mutated = $text -replace 'every injected service', 'every injected widget'
    Assert ($mutated -ne $text) 'content mutation actually applied' 'the planted string was not found -- test is inert'
    $h = Get-BlockHash (Get-NormalizedBlock -Text $mutated -BlockName 'SOLID')
    Assert ($h -ne $baseline) 'content edit moves the hash' "hash unchanged at $h -- the instrument cannot detect staleness"

    # 4b. "The two hashes differ" is far too weak on its own: collapsing the digest to a single hex
    #     character still passes it ~15 times in 16, so a catastrophically weakened hash reads as
    #     green. Found by red-testing this very suite. Pin the shape and a golden vector so any
    #     change to the digest, its truncation, or its casing fails deterministically.
    Assert ($baseline -match '^[0-9a-f]{16}$') 'hash shape is 16 lowercase hex chars' "got '$baseline'"
    $golden = Get-BlockHash "## X`n`nab"
    Assert ($golden -eq '7f4cd4af5efff780') 'golden vector matches' "got '$golden' -- the hash algorithm or normalisation changed"

    # 5. A missing heading must return null, not throw and not silently hash empty.
    $absent = Get-NormalizedBlock -Text $text -BlockName 'No Such Section'
    Assert ($null -eq $absent) 'absent heading returns null' "got '$absent'"

    if ($script:selfTestFailures -gt 0) {
        Write-Host "SELF-TEST FAILED: $($script:selfTestFailures) assertion(s)"
        return 1
    }
    Write-Host 'SELF-TEST PASSED'
    return 0
}

try {
    if ($SelfTest) { exit (Invoke-SelfTest) }

    # Version tags only, ordered oldest-first. 'pre-restructure' and any non-version tag is skipped.
    $tags = @(git tag --list 'v*' |
        Where-Object { $_ -match '^v\d+\.\d+\.\d+$' } |
        Sort-Object { [version]($_.Substring(1)) })

    if ($tags.Count -eq 0) { throw 'No version tags found — cannot build a historical manifest.' }

    Write-Host "Fingerprinting $($frameworkBlocks.Count) blocks across $($tags.Count) releases: $($tags[0]) .. $($tags[-1])"

    # entries[dist][file][block] = ordered list of @{ hash; first; last }
    $entries = [ordered]@{}
    $missing = [System.Collections.Generic.List[string]]::new()

    foreach ($d in $Dist) {
        $entries[$d] = [ordered]@{}
        foreach ($f in $File) {
            $entries[$d][$f] = [ordered]@{}
            foreach ($b in $frameworkBlocks) { $entries[$d][$f][$b] = [System.Collections.Generic.List[object]]::new() }

            foreach ($tag in $tags) {
                $path = "dist/$d/$f"
                $text = & git show "${tag}:${path}" 2>$null
                if ($LASTEXITCODE -ne 0 -or $null -eq $text) {
                    # Expected for tags predating a dist. Recorded, not guessed at.
                    $missing.Add("$tag`:$path")
                    continue
                }
                $joined = ($text -join "`n")

                foreach ($b in $frameworkBlocks) {
                    $block = Get-NormalizedBlock -Text $joined -BlockName $b
                    if ($null -eq $block) { $missing.Add("$tag`:$path#$b"); continue }

                    $hash = Get-BlockHash -Content $block
                    $list = $entries[$d][$f][$b]
                    if ($list.Count -gt 0 -and $list[-1].hash -eq $hash) {
                        $list[-1].last = $tag      # unchanged — extend the current range
                    } else {
                        $list.Add([ordered]@{ hash = $hash; first = $tag; last = $tag })
                    }
                }
            }
        }
    }

    $manifest = [ordered]@{
        'schema-version'  = 1
        'generated-by'    = '.claude/scripts/build-block-manifest.ps1'
        'purpose'         = 'Classify a consumer protected file as CURRENT / BEHIND / DIVERGED. See B-97.'
        'counting-rule'   = 'Block = "## <name>" to next "## " or EOF; LF-normalized, BOM-stripped, per-line trailing whitespace removed, outer whitespace trimmed; sha256, first 16 hex chars.'
        'blocks'          = $frameworkBlocks
        'coverage'        = [ordered]@{
            'earliest-release' = $tags[0]
            'latest-release'   = $tags[-1]
            'release-count'    = $tags.Count
            'limitation'       = 'Tags in this repo begin at the monorepo merge. Releases before that shipped from the two archived legacy repos, so a consumer installed before the earliest release above cannot be fingerprinted here and must classify as UNKNOWN, never as CURRENT.'
        }
        'unavailable'     = @($missing)
        'fingerprints'    = $entries
    }

    $json = $manifest | ConvertTo-Json -Depth 12
    $dir  = Split-Path -Parent $OutFile
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    [IO.File]::WriteAllText($OutFile, $json + "`n", [Text.UTF8Encoding]::new($false))

    $total = 0
    foreach ($d in $Dist) { foreach ($f in $File) { foreach ($b in $frameworkBlocks) { $total += $entries[$d][$f][$b].Count } } }
    Write-Host "Wrote $OutFile"
    Write-Host "  distinct block versions: $total"
    Write-Host "  unavailable (tag/dist/block absent): $($missing.Count)"
}
finally {
    [Console]::OutputEncoding = $prevEncoding
}
