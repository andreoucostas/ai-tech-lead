# B-149 implementation report

## Scope and proportionality

This meta-only change closes four already-observed happy-path-only gaps with focused mutations in
existing gate subjects. No shipped source, generated distribution, version, or changelog changed.
The smaller fix is the implemented one: retain executable negative cases rather than alter any gate.

## Composer

Command: `pwsh -NoProfile -File .claude/hooks/tests/Composer.Tests.ps1`

Observed output (exit 0):

```text
Mutation diff: composer-input.txt
  line 1 before: <!-- @stack:fixture -->
  line 1 after : <!-- @stack:fixture -- >
RED confirmed: command exit 1
RESTORE verified byte-identical: composer-input.txt
[ok] PowerShell malformed marker: composer went red
[ok] shell malformed marker: composer went red
[ok] PowerShell unapproved overlay collision: composer went red
[ok] shell unapproved overlay collision: composer went red
Composer.Tests: 4 passed, 0 failed
```

Both twins claim and demonstrate rejection of unresolved/malformed markers and unapproved
dotnet/angular whole-file collisions. They do not claim to reject a missing snippet: the composer
comments and implementation define an absent snippet as an empty expansion. That requested
assertion could not honestly be shown failing without changing shipped behavior, so it was not
invented.

## docs-sync-check

Command: `pwsh -NoProfile -File .claude/hooks/tests/DocsSyncCheck.Tests.ps1`

Observed output (exit 0):

```text
Mutation diff: dist\dotnet\.claude\skills\add-tests\SKILL.md
  line 2 before: name: add-tests
  line 2 after : name: add-tests-planted-drift
FAIL: skills mirror drift (.claude/skills vs .github/skills ...): add-tests\SKILL.md differs
RED confirmed: command exit 1
RESTORE verified byte-identical: dist\dotnet\.claude\skills\add-tests\SKILL.md
[ok] PowerShell docs sync: planted drift went red
FAIL: skills mirror drift (.claude/skills vs .github/skills ...)
RED confirmed: command exit 1
RESTORE verified byte-identical: dist\dotnet\.claude\skills\add-tests\SKILL.md
[ok] shell docs sync: planted drift went red
DocsSyncCheck.Tests: 2 passed, 0 failed
```

## InstallerContract

Command: `pwsh -NoProfile -File .claude/hooks/tests/InstallerContract.Tests.ps1`

Observed output (exit 0):

```text
Mutation diff: dist\dotnet\scripts\install.ps1
  line 215 before: Review and commit the copied files ...
  line 215 after : Review the copied files ...
[FAIL] installer states the whole agent contract: dotnet/greenfield/ps1 -- ... no match for /commit the copied files/
InstallerContract.Tests ...: 11 passed, 1 failed, 0 skipped
RED confirmed: command exit 1
RESTORE verified byte-identical: dist\dotnet\scripts\install.ps1
[ok] a missing contract line makes this suite fail
InstallerContract.Tests ...: 13 passed, 0 failed, 0 skipped
```

## RootInstallerWarehouse

Command: `pwsh -NoProfile -File .claude/hooks/tests/RootInstallerWarehouse.Tests.ps1`

Observed output (exit 0):

```text
Mutation diff: install.ps1
  line 71 before: ... reason='warehouse SQL fallback (at least two independent signals)'
  line 71 after : ... reason='broken warehouse selection'
[FAIL] pure SQL repo selects dotnet without a solution (ps1) -- wrong root selection: Stack: dotnet (via broken warehouse selection)
RootInstallerWarehouse.Tests: 1 passed, 1 failed, 0 skipped
RED confirmed: command exit 1
RESTORE verified byte-identical: install.ps1
[ok] a broken warehouse install makes this suite fail
RootInstallerWarehouse.Tests: 3 passed, 0 failed, 0 skipped
```

## Host coverage and full suite

Windows PowerShell 5.1: **NOT OBSERVED** (genuinely absent in this environment). PowerShell 7 is
the observed host.

Command: `pwsh -NoProfile -File .claude/hooks/tests/Invoke-HookTests.ps1`

First observation: the command reached its 600-second command ceiling before the buffered runner
returned any aggregate, so no count was inferred. Re-run with a 900-second ceiling completed in
654.7 seconds with:

```text
=== Meta-hook test suite: 1 failure(s) across 24 file(s) ===
```

The one result was isolated with:
`pwsh -NoProfile -File .claude/hooks/tests/Invoke-HookTests.ps1 -File RepositoryPrivacy.Tests.ps1`.
It reported `5 passed, 1 failed, 0 skipped`; the failure was the known sandbox-local condition in
which git's denied access to `<home>/.config/git/ignore` is misread as a repository path. Per the
standing correction, this is recorded as sandbox-local, not as a repository failure; it has twice
been verified not to reproduce on the real tree. A targeted
`ScriptTwinCoverage.Tests.ps1` run reported `1 passed, 0 failed, 0 skipped`; the previously known
TwinParity Boy Scout sandbox-local failure did not recur in this run.

## RCA

No gate caught these gaps because each suite asserted only successful subprocess behavior; none
mutated the subject and proved the assertion path could reject it. The same class remains exposed
only in the rows still marked `HAPPY-PATH-ONLY` in `meta/gate-redtest-coverage.md`; the nine
`UNKNOWN` observations were deliberately not treated as missing tests.
