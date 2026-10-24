# Tests for scripts/context-footprint.ps1 (B-464 B3/B7/B8/B10 halves). Every case runs the real script
# against a scratch copy of the subset it needs (scripts/, meta/context-footprint.json, dist/), so the
# repo's own dist/ and baseline are never touched. Does NOT ship.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path
$subject  = Join-Path $repoRoot 'scripts/context-footprint.ps1'
$utf8     = New-Object System.Text.UTF8Encoding($false)
$lf       = [string][char]10

function Copy-Tree([string]$Src, [string]$Dst) {
    [void][IO.Directory]::CreateDirectory($Dst)
    foreach ($f in Get-ChildItem -LiteralPath $Src -Recurse -File -Force) {
        $rel = $f.FullName.Substring($Src.Length).TrimStart('\', '/')
        $target = Join-Path $Dst $rel
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $target))
        [IO.File]::Copy($f.FullName, $target, $true)
    }
}

# A scratch "repo": the script, the committed baseline and the three dists.
function New-Scratch([string]$Parent, [string]$Name) {
    $dir = Join-Path $Parent $Name
    [void][IO.Directory]::CreateDirectory((Join-Path $dir 'scripts'))
    [void][IO.Directory]::CreateDirectory((Join-Path $dir 'meta'))
    [IO.File]::Copy($subject, (Join-Path $dir 'scripts/context-footprint.ps1'), $true)
    [IO.File]::Copy((Join-Path $repoRoot 'meta/context-footprint.json'), (Join-Path $dir 'meta/context-footprint.json'), $true)
    foreach ($d in 'dotnet', 'angular', 'monorepo') { Copy-Tree (Join-Path $repoRoot "dist/$d") (Join-Path $dir "dist/$d") }
    return $dir
}

function Write-Text([string]$Path, [string]$Text) {
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}

function Invoke-Footprint([string]$Script, [string[]]$Arguments) {
    return Invoke-RawProcess -FileName (Get-PsExe) -Arguments (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Script) + $Arguments)
}

function Get-DotnetUsed($Result) {
    if ($Result.Out -notmatch 'HEADROOM dotnet\s+static\.claude (\d+) / 40000') {
        throw "no dotnet HEADROOM line (exit=$($Result.Exit)); out=[$($Result.Out)] err=[$($Result.Err)]"
    }
    return [int]$Matches[1]
}

function Get-FileBytes([string]$Path) {
    return $utf8.GetByteCount(([IO.File]::ReadAllText($Path)).Replace("`r`n", $lf))
}

Reset-Tests

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('ctxfoot-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($tmp)
try {
    # --- control: the scratch copy is a faithful stand-in for the repo ---------------------------
    $plain = New-Scratch $tmp 'plain'
    $control = $null
    $baseUsed = 0
    It 'control: -Check on an unmodified scratch copy is OK' {
        $script:control = Invoke-Footprint (Join-Path $plain 'scripts/context-footprint.ps1') @('-Check')
        Assert ($control.Exit -eq 0 -and $control.Out -match 'OK: context footprint matches') "scratch control: exit=$($control.Exit) out=[$($control.Out)] err=[$($control.Err)]"
        $script:baseUsed = Get-DotnetUsed $control
    }

    # --- B3: what CLAUDE.md imports is counted --------------------------------------------------
    It 'B3: an @-imported file is counted in static.claude, not just the import line' {
        $dir = New-Scratch $tmp 'import'
        $ref = 'x' * 2999 + $lf
        Write-Text (Join-Path $dir 'dist/dotnet/docs/zz-imported-fixture.md') $ref
        $claude = Join-Path $dir 'dist/dotnet/CLAUDE.md'
        $line = '@docs/zz-imported-fixture.md' + $lf
        Write-Text $claude ([IO.File]::ReadAllText($claude) + $line)
        $r = Invoke-Footprint (Join-Path $dir 'scripts/context-footprint.ps1') @('-Check')
        $used = Get-DotnetUsed $r
        $want = $baseUsed + $utf8.GetByteCount($line) + $utf8.GetByteCount($ref)
        Assert ($used -eq $want) "dotnet static.claude is $used, want $want ($baseUsed + the $($utf8.GetByteCount($line))-byte import line + the $($utf8.GetByteCount($ref))-byte imported file): the imported file is not counted"
        Assert ($r.Exit -eq 1) "an added import must read as drift (exit 1), got exit=$($r.Exit)"
    }

    It 'B3: nested and cyclic imports count each file once; code spans and fences are not imports' {
        $dir = New-Scratch $tmp 'nested'
        # An import is relative to the file that holds it, so the pair names each other bare.
        $a = '@zz-b.md' + $lf + ('a' * 999) + $lf
        $b = 'see @zz-a.md for more' + $lf + ('b' * 499) + $lf
        $code = ('c' * 700) + $lf
        Write-Text (Join-Path $dir 'dist/dotnet/docs/zz-a.md') $a
        Write-Text (Join-Path $dir 'dist/dotnet/docs/zz-b.md') $b
        Write-Text (Join-Path $dir 'dist/dotnet/docs/zz-code.md') $code
        $claude = Join-Path $dir 'dist/dotnet/CLAUDE.md'
        $add = '@docs/zz-a.md' + $lf + '@docs/zz-a.md' + $lf + 'inline `@docs/zz-code.md` and mail me@docs/zz-code.md' + $lf +
            '```' + $lf + '@docs/zz-code.md' + $lf + '```' + $lf
        Write-Text $claude ([IO.File]::ReadAllText($claude) + $add)
        $r = Invoke-Footprint (Join-Path $dir 'scripts/context-footprint.ps1') @('-Check')
        $used = Get-DotnetUsed $r
        $want = $baseUsed + $utf8.GetByteCount($add) + $utf8.GetByteCount($a) + $utf8.GetByteCount($b)
        Assert ($used -eq $want) "dotnet static.claude is $used, want $want (added lines + zz-a + zz-b once each, zz-code never)"
    }

    # --- B3: always-loaded files that are not imports -------------------------------------------
    $rules = $null
    try {
        $dir = New-Scratch $tmp 'autoload'
        Write-Text (Join-Path $dir 'dist/dotnet/.claude/rules/team.md') (('r' * 1999) + $lf)
        $inst = '---' + $lf + 'applyTo: "**"' + $lf + '---' + $lf + ('i' * 1500) + $lf
        $scoped = '---' + $lf + 'applyTo: "src/**"' + $lf + '---' + $lf + ('s' * 900) + $lf
        $cop = ('p' * 1199) + $lf
        Write-Text (Join-Path $dir 'dist/dotnet/.github/instructions/zz-always.instructions.md') $inst
        Write-Text (Join-Path $dir 'dist/dotnet/.github/instructions/zz-scoped.instructions.md') $scoped
        Write-Text (Join-Path $dir 'dist/dotnet/.github/copilot-instructions.md') $cop
        $u = Invoke-Footprint (Join-Path $dir 'scripts/context-footprint.ps1') @('-Update')
        $doc = [IO.File]::ReadAllText((Join-Path $dir 'meta/context-footprint.json')) | ConvertFrom-Json
        $rules = [pscustomobject]@{
            Exit    = $u.Exit
            Claude  = [int]$doc.derived.dotnet.'static.claude.chars'
            Copilot = [int]$doc.derived.dotnet.'static.copilot.chars'
            WantRules   = 2000
            WantCopilot = $utf8.GetByteCount($inst) + $utf8.GetByteCount($cop)
        }
    } catch { $rules = [pscustomobject]@{ Exit = -1; Err = $_.Exception.Message } }
    $baseCopilot = 0
    try {
        $baseDoc = [IO.File]::ReadAllText((Join-Path $repoRoot 'meta/context-footprint.json')) | ConvertFrom-Json
        $baseCopilot = [int]$baseDoc.derived.dotnet.'static.copilot.chars'
    } catch { }

    It 'B3: a .claude/rules/*.md file is counted in static.claude' {
        Assert ($rules.Exit -eq 0) "scratch -Update failed: exit=$($rules.Exit) $($rules.Err)"
        $want = $baseUsed + $rules.WantRules
        Assert ($rules.Claude -eq $want) "dotnet static.claude is $($rules.Claude), want $want (baseline $baseUsed + the 2000-byte .claude/rules/team.md)"
    }

    It 'B3: an applyTo "**" instruction file and copilot-instructions.md are counted in static.copilot, a scoped one is not' {
        Assert ($rules.Exit -eq 0) "scratch -Update failed: exit=$($rules.Exit) $($rules.Err)"
        $want = $baseCopilot + $rules.WantCopilot
        Assert ($rules.Copilot -eq $want) "dotnet static.copilot is $($rules.Copilot), want $want (baseline $baseCopilot + always-applied instruction file + copilot-instructions.md)"
    }

    # --- B3: -DistRoot points the script at a dist copy -----------------------------------------
    It 'B3: -DistRoot measures the given dist root, not the repo dist' {
        # Fails on the unfixed script only because -DistRoot is not a parameter there: it lands in
        # $args and the run measures the repo's own dist.
        $dir = New-Scratch $tmp 'distroot'
        $line = '@docs/zz-distroot.md' + $lf
        Write-Text (Join-Path $dir 'dist/dotnet/docs/zz-distroot.md') (('d' * 1000) + $lf)
        $claude = Join-Path $dir 'dist/dotnet/CLAUDE.md'
        Write-Text $claude ([IO.File]::ReadAllText($claude) + $line)
        $r = Invoke-Footprint $subject @('-Check', '-DistRoot', (Join-Path $dir 'dist'))
        $used = Get-DotnetUsed $r
        $want = $baseUsed + $utf8.GetByteCount($line) + 1001
        Assert ($used -eq $want) "dotnet static.claude is $used, want $want (the copied dist plus its import): -DistRoot was ignored (exit=$($r.Exit))"
        $u = Invoke-Footprint $subject @('-Update', '-DistRoot', (Join-Path $dir 'dist'))
        Assert ($u.Exit -eq 2) "-Update with -DistRoot must be refused (exit 2), got exit=$($u.Exit)"
    }

    # --- B7: an unreadable file is "could not examine" (exit 2), not a drift FAIL ---------------
    It 'B7: a locked AGENTS.md exits 2 with FATAL, not 1 with a raw I/O error' {
        $dir = New-Scratch $tmp 'locked'
        $lock = [IO.File]::Open((Join-Path $dir 'dist/dotnet/AGENTS.md'), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
        try {
            $r = Invoke-Footprint (Join-Path $dir 'scripts/context-footprint.ps1') @('-Check')
        } finally { $lock.Dispose() }
        Assert ($r.Exit -eq 2 -and $r.Err -match 'FATAL:') "locked file: exit=$($r.Exit), want 2 with FATAL; err=[$($r.Err.Trim())]"
    }

    # --- B8: a path holding [ is a path, not a wildcard -----------------------------------------
    It 'B8: a checkout under a folder named with [1] gives the same -Check verdict as a plain one' {
        $dir = Join-Path $tmp 'grp[1]'
        Copy-Tree $plain (Join-Path $dir 'repo')
        $r = Invoke-Footprint (Join-Path $dir 'repo/scripts/context-footprint.ps1') @('-Check')
        Assert ($r.Exit -eq $control.Exit -and $r.Out -ceq $control.Out) "bracket path: exit=$($r.Exit) out=[$($r.Out)] err=[$($r.Err.Trim())]; plain: exit=$($control.Exit) out=[$($control.Out)]"
    }

    # --- B10: an unknown switch is refused, not run as a default -Check -------------------------
    It 'B10: a misspelt switch (-Chek) is refused, not run as a default -Check' {
        $r = Invoke-Footprint (Join-Path $plain 'scripts/context-footprint.ps1') @('-Chek')
        Assert ($r.Exit -ne 0 -and $r.Out -notmatch 'OK: context footprint matches') "-Chek: exit=$($r.Exit) out=[$($r.Out)]"
    }
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Write-TestSummary 'ContextFootprint.Tests (scripts/context-footprint.ps1)')
