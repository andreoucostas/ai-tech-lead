# B-217 executable hostile case: docs-sync-check.ps1 must reject a legacy GitHub skill
# path, name the canonical location, and return green again once the shadow path is gone.

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$psExe = (Get-Process -Id $PID).Path
$cases = @('PowerShell docs sync', 'AGENTS.md byte budget', 'bracketed repository path')
$failed = 0

function Invoke-DocsSyncCandidate {
    param([string]$Root)
    $script = Join-Path $Root 'scripts/docs-sync-check.ps1'
    $output = & $psExe -NoProfile -File $script 2>&1 | Out-String
    return [pscustomobject]@{ Exit = [int]$LASTEXITCODE; Output = $output }
}

foreach ($case in $cases) {
    $scratch = Join-Path ([IO.Path]::GetTempPath()) ('docs-sync-b217-' + [guid]::NewGuid().ToString('N'))
    if ($case -eq 'bracketed repository path') {
        # Set-Location without -LiteralPath read the repository path as a wildcard and died with "does not exist" before any check ran.
        $plain = $scratch; $bracketed = $scratch + '-[1]'
        try {
            foreach ($root in @($plain, $bracketed)) {
                Copy-Item -LiteralPath (Join-Path $repoRoot 'dist/dotnet') -Destination $root -Recurse -Force
                [IO.File]::Delete((Join-Path $root '.template-repo'))
            }
            $expected = Invoke-DocsSyncCandidate -Root $plain
            $actual = Invoke-DocsSyncCandidate -Root $bracketed
            if ($actual.Output -match 'does not exist') { throw "the bracketed path was read as a wildcard: $($actual.Output)" }
            if ($actual.Exit -ne $expected.Exit) { throw "bracketed path exited $($actual.Exit), the same tree at a plain path $($expected.Exit): $($actual.Output)" }
            Write-Host "[ok] ${case}: the same checks run at a path with [ ] as at a plain one (exit $($actual.Exit))"
        } catch {
            $failed++
            [Console]::Error.WriteLine("[FAIL] ${case}: $($_.Exception.Message)")
        } finally {
            foreach ($root in @($plain, $bracketed)) { if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force } }
        }
        continue
    }
    if ($case -eq 'AGENTS.md byte budget') {
        try {
            Copy-Item -LiteralPath (Join-Path $repoRoot 'dist/dotnet') -Destination $scratch -Recurse -Force
            # An installed repository has no template marker; with it, the consumer checks are skipped.
            [IO.File]::Delete((Join-Path $scratch '.template-repo'))
            $template = Invoke-DocsSyncCandidate -Root $scratch
            if ($template.Output -match 'NOTE: AGENTS\.md is') { throw "the shipped template tripped the size note: $($template.Output)" }
            # About 240 lines and 20 KB: under the old 400-line budget, over the byte budget.
            $agents = Join-Path $scratch 'AGENTS.md'
            $pad = (1..120 | ForEach-Object { '- ' + ('x' * 110) }) -join "`n"
            [IO.File]::WriteAllText($agents, [IO.File]::ReadAllText($agents) + "`n" + $pad + "`n", [Text.UTF8Encoding]::new($false))
            $long = Invoke-DocsSyncCandidate -Root $scratch
            if ($long.Output -notmatch 'NOTE: AGENTS\.md is \d+ bytes \(soft budget 16000\)') { throw "a 20 KB AGENTS.md did not get the size note: $($long.Output)" }
            Write-Host "[ok] ${case}: the template is under it, a 20 KB file of 240 lines is over it"
        } catch {
            $failed++
            [Console]::Error.WriteLine("[FAIL] ${case}: $($_.Exception.Message)")
        } finally {
            if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
        }
        continue
    }
    try {
        Copy-Item -LiteralPath (Join-Path $repoRoot 'dist/dotnet') -Destination $scratch -Recurse -Force

        $cleanBefore = Invoke-DocsSyncCandidate -Root $scratch
        if ($cleanBefore.Exit -ne 0) { throw "clean candidate exited $($cleanBefore.Exit): $($cleanBefore.Output)" }

        $legacySkill = Join-Path $scratch '.github/skills/legacy/SKILL.md'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $legacySkill) | Out-Null
        [IO.File]::WriteAllText($legacySkill, "---`nname: legacy`ndescription: planted shadow`n---`n", [Text.UTF8Encoding]::new($false))
        $hostile = Invoke-DocsSyncCandidate -Root $scratch
        if ($hostile.Exit -ne 1) { throw "planted GitHub skill exited $($hostile.Exit), expected 1: $($hostile.Output)" }
        # Start-Job's redirected stream can render the Unicode separator as an ASCII hyphen or as
        # mojibake under the inherited Windows code page. Pin the two semantic halves, not that
        # presentation byte, so the aggregate runner measures the finding rather than its encoding.
        if ($hostile.Output -notmatch '\.github/skills exists .*migrate its contents to \.claude/skills, then remove the GitHub path\.') {
            throw "planted GitHub skill did not emit the canonical-location finding: $($hostile.Output)"
        }

        Remove-Item -LiteralPath (Join-Path $scratch '.github/skills') -Recurse -Force
        $cleanAfter = Invoke-DocsSyncCandidate -Root $scratch
        if ($cleanAfter.Exit -ne 0) { throw "restored candidate exited $($cleanAfter.Exit): $($cleanAfter.Output)" }
        Write-Host "[ok] ${case}: clean green, planted shadow red, restored green"
    } catch {
        $failed++
        [Console]::Error.WriteLine("[FAIL] ${case}: $($_.Exception.Message)")
    } finally {
        if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
    }
}

if ($global:AtlEmitCaseCount) { Write-Host ("CASE_COUNT {0}" -f $cases.Count) }
if ($failed -eq 0) { Write-Host "DocsSyncCheck.Tests: $($cases.Count) passed, 0 failed" }
else { [Console]::Error.WriteLine("DocsSyncCheck.Tests: $($cases.Count - $failed) passed, $failed failed") }
exit ([int]($failed -gt 0))
