# Scratch-only mutation helper for executable meta red-tests. Dot-source this file from a suite.

function Invoke-MutationRedTest {
    [CmdletBinding(DefaultParameterSetName = 'FindReplace')]
    param(
        [Parameter(Mandatory)][string]$TargetFile,
        [Parameter(Mandatory, ParameterSetName = 'Line')][int]$LineNumber,
        [Parameter(Mandatory, ParameterSetName = 'Line')][string]$LineReplacement,
        [Parameter(Mandatory, ParameterSetName = 'FindReplace')][string]$Find,
        [Parameter(Mandatory, ParameterSetName = 'FindReplace')][string]$Replacement,
        [Parameter(Mandatory)][scriptblock]$Command,
        [int]$ExpectedExit,
        [string]$ScratchSourceRoot
    )

    $sourceTarget = (Resolve-Path -LiteralPath $TargetFile).Path
    $sourceRoot = if ($ScratchSourceRoot) { (Resolve-Path -LiteralPath $ScratchSourceRoot).Path } else { Split-Path -Parent $sourceTarget }
    if (-not $sourceTarget.StartsWith($sourceRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and $sourceTarget -ne $sourceRoot) {
        throw "Target file is outside ScratchSourceRoot: $TargetFile"
    }

    $scratchParent = Join-Path ([IO.Path]::GetTempPath()) ('mutation-helper-' + [guid]::NewGuid().ToString('N'))
    $scratchRoot = Join-Path $scratchParent 'subject'
    New-Item -ItemType Directory -Path $scratchRoot -Force | Out-Null
    $relative = $sourceTarget.Substring($sourceRoot.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    try {
        Get-ChildItem -LiteralPath $sourceRoot -Force | Copy-Item -Destination $scratchRoot -Recurse -Force
        $scratchTarget = Join-Path $scratchRoot $relative
        $originalBytes = [IO.File]::ReadAllBytes($scratchTarget)
        $encoding = New-Object Text.UTF8Encoding($false, $true)
        $originalText = $encoding.GetString($originalBytes)
        $newline = if ($originalText.Contains("`r`n")) { "`r`n" } else { "`n" }
        $hadFinalNewline = $originalText.EndsWith("`n")
        $beforeLines = $originalText -split "`r?`n"
        if ($hadFinalNewline) { $beforeLines = $beforeLines[0..($beforeLines.Count - 2)] }

        if ($PSCmdlet.ParameterSetName -eq 'Line') {
            if ($LineNumber -lt 1 -or $LineNumber -gt $beforeLines.Count) { throw "the mutation did not apply: line $LineNumber does not exist" }
            $afterLines = @($beforeLines)
            $afterLines[$LineNumber - 1] = $LineReplacement
            $mutatedText = ($afterLines -join $newline) + $(if ($hadFinalNewline) { $newline } else { '' })
        } else {
            $mutatedText = $originalText.Replace($Find, $Replacement)
        }
        $mutatedBytes = $encoding.GetBytes($mutatedText)
        if ([Convert]::ToBase64String($mutatedBytes) -ceq [Convert]::ToBase64String($originalBytes)) {
            throw 'the mutation did not apply: scratch target is byte-identical to the original'
        }
        [IO.File]::WriteAllBytes($scratchTarget, $mutatedBytes)

        $afterText = $encoding.GetString($mutatedBytes)
        $afterLines = $afterText -split "`r?`n"
        if ($afterText.EndsWith("`n")) { $afterLines = $afterLines[0..($afterLines.Count - 2)] }
        Write-Host "Mutation diff: $relative"
        $max = [Math]::Max($beforeLines.Count, $afterLines.Count)
        for ($i = 0; $i -lt $max; $i++) {
            $before = if ($i -lt $beforeLines.Count) { $beforeLines[$i] } else { '<missing>' }
            $after = if ($i -lt $afterLines.Count) { $afterLines[$i] } else { '<missing>' }
            if ($before -cne $after) {
                Write-Host ("  line {0} before: {1}" -f ($i + 1), $before)
                Write-Host ("  line {0} after : {1}" -f ($i + 1), $after)
            }
        }
        Write-Host 'Reachability note: this diff proves the mutation applied; inspect it to confirm the changed line is on the executed path.'

        $global:LASTEXITCODE = 0
        & $Command $scratchTarget $scratchRoot
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) { $exitCode = 0 }
        if ($exitCode -eq 0) { throw 'mutation applied but command stayed GREEN (exit 0)' }
        if ($PSBoundParameters.ContainsKey('ExpectedExit') -and $exitCode -ne $ExpectedExit) {
            throw "command went red with exit $exitCode; expected exit $ExpectedExit"
        }
        Write-Host "RED confirmed: command exit $exitCode"
        return [pscustomobject]@{ Exit = $exitCode; ScratchTarget = $scratchTarget; ScratchRoot = $scratchRoot }
    } finally {
        if ($scratchTarget -and $originalBytes -and (Test-Path -LiteralPath $scratchTarget)) {
            [IO.File]::WriteAllBytes($scratchTarget, $originalBytes)
            $restored = [IO.File]::ReadAllBytes($scratchTarget)
            if ([Convert]::ToBase64String($restored) -cne [Convert]::ToBase64String($originalBytes)) {
                throw "scratch restore verification failed: $relative"
            }
            Write-Host "RESTORE verified byte-identical: $relative"
        }
        if (Test-Path -LiteralPath $scratchParent) { Remove-Item -LiteralPath $scratchParent -Recurse -Force }
    }
}

if ($args -contains '-SelfTest') {
    $selfRoot = Join-Path ([IO.Path]::GetTempPath()) ('mutation-helper-selftest-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $selfRoot -Force | Out-Null
    $selfFile = Join-Path $selfRoot 'subject.txt'
    $utf8 = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($selfFile, "alpha`nbeta`n", $utf8)
    $original = [IO.File]::ReadAllBytes($selfFile)
    $failed = 0
    try {
        try { Invoke-MutationRedTest -TargetFile $selfFile -Find 'absent' -Replacement 'changed' -Command { exit 1 }; throw 'no-match arm did not throw' }
        catch { if ($_.Exception.Message -notmatch 'did not apply') { throw }; Write-Host '[ok] no-match mutation threw "did not apply"' }

        Invoke-MutationRedTest -TargetFile $selfFile -LineNumber 2 -LineReplacement 'red' -ExpectedExit 7 -Command { param($target) if ([IO.File]::ReadAllText($target, [Text.Encoding]::UTF8) -match 'red') { $global:LASTEXITCODE = 7 } } | Out-Null
        Write-Host '[ok] applied mutation made the command go red'

        try { Invoke-MutationRedTest -TargetFile $selfFile -Find 'alpha' -Replacement 'green' -Command { $global:LASTEXITCODE = 0 }; throw 'green-command arm did not throw' }
        catch { if ($_.Exception.Message -notmatch 'stayed GREEN') { throw }; Write-Host '[ok] applied mutation with a green command was rejected' }

        $after = [IO.File]::ReadAllBytes($selfFile)
        if ([Convert]::ToBase64String($after) -cne [Convert]::ToBase64String($original)) { throw 'self-test source file was not byte-identical after restore' }
        Write-Host '[ok] source and restored scratch content were byte-identical'
    } catch { $failed = 1; [Console]::Error.WriteLine("[FAIL] $($_.Exception.Message)") }
    finally { if (Test-Path -LiteralPath $selfRoot) { Remove-Item -LiteralPath $selfRoot -Recurse -Force } }
    exit $failed
}
