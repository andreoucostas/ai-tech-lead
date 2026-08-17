# Round 3 implementation report — B-82 and v0.53.0 changelog heads

## Red: heading added to root CLAUDE.md only

After adding the exact line `## Planted` beneath `## Status` in root `CLAUDE.md`, I ran:

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File .claude/hooks/tests/DocTruth.Tests.ps1; "exit=$LASTEXITCODE"
```

Observed output:

```text
[ok] all three dists carry the SAME version stamp
[ok] the root README version stamp matches what is actually shipped
[ok] no doc documents `&#64;&#64;INCLUDE` -- the composer has never implemented it
[ok] the marker syntax the docs teach is the one the composer implements
[ok] every script path named in a root doc exists
[ok] every script CI invokes actually exists
[ok] every live backlog item has a unique id
[FAIL] root CLAUDE.md and AGENTS.md headings have an explicit mirror mapping -- CLAUDE.md heading 'Planted' has no mapping -- decide its mirror target and add it to the table
DocTruth.Tests (the authoring docs describe the repo that exists): 7 passed, 1 failed, 0 skipped
exit=1
```

This failure gives the required action: decide the heading's mirror target and add the mapping.
The planted line was then removed.

## Red: heading added to root AGENTS.md only

After adding the exact line `## Planted` beneath `## Status` in root `AGENTS.md`, I ran:

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File .claude/hooks/tests/DocTruth.Tests.ps1; "exit=$LASTEXITCODE"
```

Observed output:

```text
[ok] all three dists carry the SAME version stamp
[ok] the root README version stamp matches what is actually shipped
[ok] no doc documents `&#64;&#64;INCLUDE` -- the composer has never implemented it
[ok] the marker syntax the docs teach is the one the composer implements
[ok] every script path named in a root doc exists
[ok] every script CI invokes actually exists
[ok] every live backlog item has a unique id
[FAIL] root CLAUDE.md and AGENTS.md headings have an explicit mirror mapping -- AGENTS.md heading 'Planted' is not the target of any CLAUDE.md heading mapping
DocTruth.Tests (the authoring docs describe the repo that exists): 7 passed, 1 failed, 0 skipped
exit=1
```

The planted line was then removed.

## Green: clean tree under PowerShell 7

Command:

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File .claude/hooks/tests/DocTruth.Tests.ps1; "pwsh_exit=$LASTEXITCODE"
```

Observed output:

```text
[ok] all three dists carry the SAME version stamp
[ok] the root README version stamp matches what is actually shipped
[ok] no doc documents `&#64;&#64;INCLUDE` -- the composer has never implemented it
[ok] the marker syntax the docs teach is the one the composer implements
[ok] every script path named in a root doc exists
[ok] every script CI invokes actually exists
[ok] every live backlog item has a unique id
[ok] root CLAUDE.md and AGENTS.md headings have an explicit mirror mapping
DocTruth.Tests (the authoring docs describe the repo that exists): 8 passed, 0 failed, 0 skipped
pwsh_exit=0
```

## Windows PowerShell 5.1

The literal `-NoProfile -File` invocation was blocked before the test loaded by this machine's
execution policy:

```powershell
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -File .claude/hooks/tests/DocTruth.Tests.ps1; "powershell51_exit=$LASTEXITCODE"
```

```text
File C:\TEMP\AIdrivenDev\ai-tech-lead\.claude\hooks\tests\DocTruth.Tests.ps1 cannot be loaded because running scripts
is disabled on this system.
powershell51_exit=1
```

I therefore used a process-scoped bypass to execute the required host without changing machine
policy:

```powershell
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/tests/DocTruth.Tests.ps1; "powershell51_exit=$LASTEXITCODE"
```

Observed output:

```text
[ok] all three dists carry the SAME version stamp
[ok] the root README version stamp matches what is actually shipped
[FAIL] no doc documents `&#64;&#64;INCLUDE` -- the composer has never implemented it -- phantom marker syntax &#64;&#64;INCLUDE documented in: .claude\hooks\tests\DocTruth.Tests.ps1. The composer reads <!-- @stack:NAME -->.
[ok] the marker syntax the docs teach is the one the composer implements
[ok] every script path named in a root doc exists
[ok] every script CI invokes actually exists
[FAIL] every live backlog item has a unique id -- BACKLOG.md yielded zero live item ids -- the heading grammar changed and this gate is blind
[ok] root CLAUDE.md and AGENTS.md headings have an explicit mirror mapping
DocTruth.Tests (the authoring docs describe the repo that exists): 6 passed, 2 failed, 0 skipped
powershell51_exit=2
```

The new B-82 assertion is green on 5.1, including its exact em-dash mappings and `@($table).Count`
guard. The file as a whole is not green on 5.1 because two pre-existing tests fail there: the
recursive `Get-ChildItem -Include` scan includes the `.ps1` test itself, and BOM-less
`meta/BACKLOG.md` is decoded with the 5.1 default rather than UTF-8 so its em-dash heading grammar
does not match. Those tests are outside the B-82-only scope and were not changed. In the captured
output above, the forbidden phantom-marker token is HTML-escaped so this report does not itself
become a DocTruth violation; rendered text is otherwise unchanged.

## Assertions not demonstrated red

- Assertion 1, the non-empty table guard, was not demonstrated red because doing so requires
  editing the test instrument itself rather than planting document drift.
- Assertion 3, mapped targets must exist in AGENTS.md, was not separately demonstrated red because
  it requires deleting or renaming an existing mapped target; the required one-sided additions do
  not remove a target.
- Assertion 5, both documents yield at least one level-two heading, was not demonstrated red because
  it requires removing or changing the grammar of every level-two heading in a root document.

Assertions 2 and 4 were demonstrated red by the two required planted-heading cases above.

## Additional targeted checks

```powershell
$bytes = [IO.File]::ReadAllBytes((Resolve-Path '.claude/hooks/tests/DocTruth.Tests.ps1')); "BOM=$($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)"
git diff --check
```

Observed output:

```text
BOM=True
```

`git diff --check` produced no output and exited 0. Neither `dist/dotnet/scripts/validate-dist.ps1`
nor `dist/dotnet/scripts/validate-dist.sh` exists, confirming that validator check 12 is not a
consumer-facing changelog item.
