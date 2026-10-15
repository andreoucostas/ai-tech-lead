# apply_patch fixtures for Guard.Tests.ps1 (AuditTrail.Tests.ps1 and PostWriteRouting.Tests.ps1 reuse the envelopes). The two envelopes are the stdin Copilot CLI 1.0.95 gave its two
# preToolUse hooks for one gpt-6.1-sol apply_patch call on 2026-10-12 (the runtime VS Code 1.139.1 bundles sent
# the same): toolName apply_patch with the raw patch in toolArgs (.github/hooks/hooks.json), and tool_name Edit
# with it in tool_input (.claude/settings.json). Only the session id and cwd are replaced; {{PATCH}} stands where
# the patch's JSON string went. The two input shapes are the object with a string `input` that the CLI also
# accepts and VS Code's Local harness sends. Key-shaped values are assembled at run time, because the
# outgoing-commit guard and push protection refuse literal ones.
$PatchEnvelopes = [ordered]@{
    'hooks.json'            = '{"sessionId":"00000000-0000-4000-8000-000000000000","timestamp":1791770702536,"cwd":"C:\\work\\repo","toolName":"apply_patch","toolArgs":{{PATCH}}}'
    '.claude/settings.json' = '{"hook_event_name":"PreToolUse","session_id":"00000000-0000-4000-8000-000000000000","timestamp":"2026-10-12T02:05:02.536Z","cwd":"C:\\work\\repo","tool_name":"Edit","tool_input":{{PATCH}}}'
}
# The patch that call carried: an add, an update, a delete and an update that moves its file.
$CapturedPatch = "*** Begin Patch`n*** Add File: notes\a.txt`n+alpha`n*** Update File: notes\b.txt`n@@`n one`n-two`n+deux`n three`n*** Delete File: notes\c.txt`n*** Update File: notes\d.txt`n*** Move to: notes\e.txt`n@@`n-delta`n+DELTA`n*** End Patch`n"

function New-PatchEvent([string]$Shape, [string]$Patch) {
    switch ($Shape) {
        'toolArgs.input'   { return (@{ toolName = 'apply_patch'; toolArgs = @{ input = $Patch } } | ConvertTo-Json -Compress -Depth 6) }
        'tool_input.input' { return (@{ tool_name = 'apply_patch'; tool_input = @{ input = $Patch; explanation = 'apply the change' } } | ConvertTo-Json -Compress -Depth 6) }
        default {
            if (-not $PatchEnvelopes.Contains($Shape)) { throw "New-PatchEvent: unknown shape '$Shape'" }
            return $PatchEnvelopes[$Shape].Replace('{{PATCH}}', (ConvertTo-Json -InputObject $Patch -Compress))
        }
    }
}

$patchKey = 'AKIA' + 'ABCDEFGHIJKLMNOP'   # the value gpt-6.1-sol wrote for the doctor's write-guard canary
$canaryPatch = "*** Begin Patch`n*** Add File: tmp-doctor-canary.txt`n+$patchKey`n*** End Patch`n"
$allShapes = @('hooks.json', '.claude/settings.json', 'toolArgs.input', 'tool_input.input')
function New-SectionsPatch([int]$Count) {
    "*** Begin Patch`n" + (-join @(1..$Count | ForEach-Object { "*** Add File: notes/f$_.txt`n+line $_`n" })) + "*** End Patch`n"
}

# Each case: n = name, p = patch, block = expected decision, names = paths the block reason must name,
# notNames = paths it must not name, shapes = event shapes (default hooks.json), policy as in guard-cases.ps1.
$GuardPatchCases = @(
    @{ n='the captured patch: an add, an update, a delete and a move (allow)'; p=$CapturedPatch; block=$false; shapes=$allShapes }
    @{ n='the doctor canary as gpt-6.1-sol wrote it'; p=$canaryPatch; block=$true; names=@('tmp-doctor-canary.txt'); shapes=$allShapes }
    @{ n='a key in the second file names that file only'; p="*** Begin Patch`n*** Add File: notes\a.txt`n+alpha`n*** Update File: config\app.env`n@@`n-AWS_ACCESS_KEY_ID=`n+AWS_ACCESS_KEY_ID=$patchKey`n*** End Patch`n"; block=$true; names=@('config\app.env'); notNames=@('notes\a.txt') }
    @{ n='a key added to a file that the update moves names both paths'; p="*** Begin Patch`n*** Update File: notes\d.txt`n*** Move to: config\e.env`n@@`n-delta`n+$patchKey`n*** End Patch`n"; block=$true; names=@('notes\d.txt', 'config\e.env') }
    @{ n='a C# suppression added by an update'; p="*** Begin Patch`n*** Update File: src\Foo.cs`n@@ public class Foo`n+#pragma warning disable CS8602`n*** End Patch`n"; block=$true; names=@('src\Foo.cs'); policy='test-defeat/suppression' }
    @{ n='a focused spec added by an add'; p="*** Begin Patch`n*** Add File: src\app.spec.ts`n+fit('x', () => { expect(1).toBe(1); });`n*** End Patch`n"; block=$true; names=@('src\app.spec.ts') }
    @{ n='a credential literal added to a test file (allow)'; p="*** Begin Patch`n*** Add File: tests\AuthServiceTests.cs`n+var password = `"hunter2hunter2`";`n*** End Patch`n"; block=$false }
    @{ n='a credential literal moved out of a test file'; p="*** Begin Patch`n*** Update File: tests\AuthServiceTests.cs`n*** Move to: src\AuthService.cs`n@@`n-var x = 1;`n+var password = `"hunter2hunter2`";`n*** End Patch`n"; block=$true; names=@('src\AuthService.cs'); notNames=@('tests\AuthServiceTests.cs') }
    @{ n='CRLF line endings'; p=$canaryPatch.Replace("`n", "`r`n"); block=$true; names=@('tmp-doctor-canary.txt'); shapes=@('hooks.json', '.claude/settings.json') }
    @{ n='a lone CR does not end an added line'; p="*** Begin Patch`n*** Add File: notes.txt`n+x`r-$patchKey`n*** End Patch`n"; block=$true; names=@('notes.txt') }
    @{ n='a lone CR does not start a new section'; p="*** Begin Patch`n*** Update File: src\Foo.cs`n@@`n+x`r*** Add File: notes.txt`n+#pragma warning disable CS8602`n*** End Patch`n"; block=$true; names=@('src\Foo.cs'); notNames=@('notes.txt') }
    @{ n='an indented section header';p="*** Begin Patch`n  *** Add File: sample.env`n+$patchKey`n*** End Patch`n"; block=$true; names=@('sample.env') }
    @{ n='a patch wrapped in a heredoc'; p="<<'EOF'`n*** Begin Patch`n*** Add File: sample.env`n+$patchKey`n*** End Patch`nEOF`n"; block=$true; names=@('sample.env') }
    @{ n='a key only on a removed line (allow)'; p="*** Begin Patch`n*** Update File: sample.env`n@@`n-AWS_ACCESS_KEY_ID=$patchKey`n+AWS_ACCESS_KEY_ID=`n*** End Patch`n"; block=$false }
    @{ n='a key only on a context line (allow)'; p="*** Begin Patch`n*** Update File: sample.env`n@@`n AWS_ACCESS_KEY_ID=$patchKey`n+REGION=eu-west-1`n*** End Patch`n"; block=$false }
    @{ n='an indented header inside an update stays a context line of that file'; p="*** Begin Patch`n*** Update File: src\Foo.cs`n@@`n *** Add File: notes.txt`n+#pragma warning disable CS8602`n*** End Patch`n"; block=$true; names=@('src\Foo.cs'); notNames=@('notes.txt') }
    @{ n='a delete-only patch (allow)'; p="*** Begin Patch`n*** Delete File: sample.env`n*** End Patch`n"; block=$false }
    @{ n='a patch with no file section'; p="*** Begin Patch`n*** End Patch`n"; block=$true; shapes=@('hooks.json', 'toolArgs.input', 'tool_input.input') }
    @{ n='an argument that is not a patch'; p='please apply my change'; block=$true }
    @{ n='a line that is not patch syntax is still checked'; p="*** Begin Patch`n*** Add File: notes.txt`n+alpha`n$patchKey`n*** End Patch`n"; block=$true; names=@('notes.txt') }
    @{ n='a soft hyphen does not make a line a context line'; p="*** Begin Patch`n*** Update File: notes.txt`n@@`n alpha`n$([char]0x00AD) $patchKey`n*** End Patch`n"; block=$true; names=@('notes.txt') }
    @{ n='more than 200 file sections'; p=(New-SectionsPatch 201); block=$true }
    @{ n='200 file sections (allow)'; p=(New-SectionsPatch 200); block=$false }
)
