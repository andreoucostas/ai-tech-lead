# B-217 executable hostile case: both docs-sync-check twins must reject a legacy GitHub skill
# path, name the canonical location, and return green again once the shadow path is gone.

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$bashCommand = Get-Command bash -ErrorAction SilentlyContinue
$bash = if ($bashCommand) { $bashCommand.Source } else { $null }
$cases = @(@{ Name = 'PowerShell docs sync'; Twin = 'ps1' }, @{ Name = 'shell docs sync'; Twin = 'sh' })
$failed = 0

function Invoke-DocsSyncCandidate {
    param([string]$Twin, [string]$Root)
    $script = Join-Path $Root "scripts/docs-sync-check.$Twin"
    $output = if ($Twin -eq 'ps1') {
        & pwsh -NoProfile -File $script 2>&1 | Out-String
    } else {
        & $bash -e $script 2>&1 | Out-String
    }
    return [pscustomobject]@{ Exit = [int]$LASTEXITCODE; Output = $output }
}

foreach ($case in $cases) {
    if ($case.Twin -eq 'sh' -and -not $bash) { Write-Host "[skip] $($case.Name): no bash on this host"; continue }
    $scratch = Join-Path ([IO.Path]::GetTempPath()) ('docs-sync-b217-' + [guid]::NewGuid().ToString('N'))
    try {
        Copy-Item -LiteralPath (Join-Path $repoRoot 'dist/dotnet') -Destination $scratch -Recurse -Force

        $cleanBefore = Invoke-DocsSyncCandidate -Twin $case.Twin -Root $scratch
        if ($cleanBefore.Exit -ne 0) { throw "clean candidate exited $($cleanBefore.Exit): $($cleanBefore.Output)" }

        $legacySkill = Join-Path $scratch '.github/skills/legacy/SKILL.md'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $legacySkill) | Out-Null
        [IO.File]::WriteAllText($legacySkill, "---`nname: legacy`ndescription: planted shadow`n---`n", [Text.UTF8Encoding]::new($false))
        $hostile = Invoke-DocsSyncCandidate -Twin $case.Twin -Root $scratch
        if ($hostile.Exit -ne 1) { throw "planted GitHub skill exited $($hostile.Exit), expected 1: $($hostile.Output)" }
        # Start-Job's redirected stream can render the Unicode separator as an ASCII hyphen or as
        # mojibake under the inherited Windows code page. Pin the two semantic halves, not that
        # presentation byte, so the aggregate runner measures the finding rather than its encoding.
        if ($hostile.Output -notmatch '\.github/skills exists .*migrate its contents to \.claude/skills, then remove the GitHub path\.') {
            throw "planted GitHub skill did not emit the canonical-location finding: $($hostile.Output)"
        }

        Remove-Item -LiteralPath (Join-Path $scratch '.github/skills') -Recurse -Force
        $cleanAfter = Invoke-DocsSyncCandidate -Twin $case.Twin -Root $scratch
        if ($cleanAfter.Exit -ne 0) { throw "restored candidate exited $($cleanAfter.Exit): $($cleanAfter.Output)" }
        Write-Host "[ok] $($case.Name): clean green, planted shadow red, restored green"
    } catch {
        $failed++
        [Console]::Error.WriteLine("[FAIL] $($case.Name): $($_.Exception.Message)")
    } finally {
        if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
    }
}

if ($failed -eq 0) { Write-Host "DocsSyncCheck.Tests: $($cases.Count) passed, 0 failed" }
else { [Console]::Error.WriteLine("DocsSyncCheck.Tests: $($cases.Count - $failed) passed, $failed failed") }
exit ([int]($failed -gt 0))
