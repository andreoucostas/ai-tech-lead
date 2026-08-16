# B-58 implementation report — round 1 of 3

Date: 2026-08-16

Scope: B-58 only. B-60 and B-82 were not touched.

## Natural red and green — authoring-only code-span parity (§1.5)

The new test was created and run before the Angular source line was changed.

Command:

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File .claude/hooks/tests/SkillListParity.Tests.ps1; Write-Output "exit=$LASTEXITCODE"
```

Output on the unfixed tree:

```text
[FAIL] stock Common Tasks descriptions keep code spans aligned per shared slug -- Common Tasks code-span drift: angular/add-tests (CLAUDE-only: HttpTestingController; AGENTS-only: )
SkillListParity.Tests (stock authoring mirrors only): 0 passed, 1 failed, 0 skipped
exit=1
```

After changing `src/stacks/angular/files/AGENTS.md` and rebuilding, the same command produced:

```text
[ok] stock Common Tasks descriptions keep code spans aligned per shared slug
SkillListParity.Tests (stock authoring mirrors only): 1 passed, 0 failed, 0 skipped
exit=0
```

## Shipped check red tests (§1.4)

I copied `dist/dotnet` into three fixed workspace scratch directories, planted each defect, and
ran both twins from inside each scratch dist. The fixture-creation command was:

```powershell
New-Item -ItemType Directory -Path '.scratch-b58' | Out-Null
foreach($case in 'one-sided','duplicate','zero-extraction'){Copy-Item -LiteralPath 'dist/dotnet' -Destination ".scratch-b58/$case" -Recurse}
# one-sided: insert `zz-planted` before `create-adr` in CLAUDE.md
# duplicate: insert a second `create-adr` in CLAUDE.md
# zero-extraction: change every Common Tasks list prefix from "- `" to "* `" in both files
```

The literal execution/comparison command was:

```powershell
$pwsh='C:\Program Files\PowerShell\7\pwsh.exe'; $bash='C:\Program Files\Git\bin\bash.exe'
foreach($case in 'one-sided','duplicate','zero-extraction'){
  Push-Location ".scratch-b58/$case"
  try{
    $po=& $pwsh -NoProfile -File scripts/template-checks.ps1 2>&1;$pe=$LASTEXITCODE
    $so=& $bash scripts/template-checks.sh 2>&1;$se=$LASTEXITCODE
  }finally{Pop-Location}
  $pf=@($po|Where-Object{"$_"-like'FAIL: Common Tasks*'})
  $sf=@($so|Where-Object{"$_"-like'FAIL: Common Tasks*'})
  Write-Output "===== $case =====";Write-Output "PS exit=$pe";$pf
  Write-Output "SH exit=$se";$sf
  Write-Output "same-exit=$($pe-eq$se) same-failure-text=$((($pf-join"`n")-ceq($sf-join"`n")))"
}
```

Real output:

```text
===== one-sided =====
PS exit=1
FAIL: Common Tasks skill inventory differs: missing from AGENTS.md: zz-planted.
SH exit=1
FAIL: Common Tasks skill inventory differs: missing from AGENTS.md: zz-planted.
same-exit=True same-failure-text=True
===== duplicate =====
PS exit=1
FAIL: Common Tasks skill inventory has duplicate slug in CLAUDE.md: create-adr.
SH exit=1
FAIL: Common Tasks skill inventory has duplicate slug in CLAUDE.md: create-adr.
same-exit=True same-failure-text=True
===== zero-extraction =====
PS exit=1
FAIL: Common Tasks sections yielded zero skill slugs — the list grammar changed and this check is now blind.
SH exit=1
FAIL: Common Tasks sections yielded zero skill slugs — the list grammar changed and this check is now blind.
same-exit=True same-failure-text=True
```

`ScriptTwinParity.Tests.ps1` additionally plants and observes the one-sided-section presence
failure, a case variant, a single-slug list, and the absent-from-both explicit OK branch. Its
Common Tasks test compares the twins' ordered stable records, not merely their exit codes.

## Builds and generated-tree observation

Command:

```powershell
foreach($d in 'dotnet','angular','monorepo'){
  & 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File scripts/build.ps1 $d
  Write-Output "$d exit=$LASTEXITCODE"
}
```

Final output:

```text
composed dist/dotnet (164 files)
dotnet exit=0
composed dist/angular (160 files)
angular exit=0
composed dist/monorepo (174 files)
monorepo exit=0
```

Command and output:

```text
> git status --porcelain dist/
 M dist/angular/AGENTS.md
 M dist/angular/scripts/template-checks.ps1
 M dist/angular/scripts/template-checks.sh
 M dist/angular/tests/hooks/ScriptTwinParity.Tests.ps1
 M dist/dotnet/scripts/template-checks.ps1
 M dist/dotnet/scripts/template-checks.sh
 M dist/dotnet/tests/hooks/ScriptTwinParity.Tests.ps1
 M dist/monorepo/scripts/template-checks.ps1
 M dist/monorepo/scripts/template-checks.sh
 M dist/monorepo/tests/hooks/ScriptTwinParity.Tests.ps1
```

These are the generated consequences of the three intended source changes: the shared shipped
check twins, their shared shipped parity test, and the Angular-only AGENTS correction. No dist file
was hand-edited.

## Targeted green gates

Both template-check twins were run from inside every dist:

```powershell
$pwsh='C:\Program Files\PowerShell\7\pwsh.exe';$bash='C:\Program Files\Git\bin\bash.exe'
foreach($d in 'dotnet','angular','monorepo'){
  Push-Location "dist/$d"
  try{
    $po=& $pwsh -NoProfile -File scripts/template-checks.ps1;$pe=$LASTEXITCODE
    $so=& $bash scripts/template-checks.sh;$se=$LASTEXITCODE
  }finally{Pop-Location}
  Write-Output "$d ps=$pe sh=$se ps-last=$($po[-1]) sh-last=$($so[-1])"
}
```

Output:

```text
dotnet ps=0 sh=0 ps-last=All deterministic framework checks passed. sh-last=All deterministic framework checks passed.
angular ps=0 sh=0 ps-last=All deterministic framework checks passed. sh-last=All deterministic framework checks passed.
monorepo ps=0 sh=0 ps-last=All deterministic framework checks passed. sh-last=All deterministic framework checks passed.
```

The final PowerShell 7 twin-suite command and output:

```text
> & 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File src/core/tests/hooks/ScriptTwinParity.Tests.ps1
[ok] template-checks clean and planted drift agree in order
[ok] template-checks Common Tasks twins agree on planted inventory failures and edge fixtures
[ok] template-checks accepts both layouts and rejects missing or divergent framework sections
[ok] template-checks rejects an Unreleased head at the stamped version but accepts a dated one
[ok] docs-sync-check branches and advisory prose agree
[ok] sync-agent-files recursively produces identical trees
[ok] sync-agent-files twins fall back to the current directory outside Git
[ok] metrics twins agree on every non-zero counter
ScriptTwinParity.Tests: 8 passed, 0 failed, 0 skipped
suite-exit=0
```

Windows PowerShell 5.1 command and output:

```text
> & 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -NoProfile -ExecutionPolicy Bypass -File src/core/tests/hooks/ScriptTwinParity.Tests.ps1
[ok] template-checks clean and planted drift agree in order
[ok] template-checks Common Tasks twins agree on planted inventory failures and edge fixtures
[ok] template-checks accepts both layouts and rejects missing or divergent framework sections
[ok] template-checks rejects an Unreleased head at the stamped version but accepts a dated one
[ok] docs-sync-check branches and advisory prose agree
[ok] sync-agent-files recursively produces identical trees
[ok] sync-agent-files twins fall back to the current directory outside Git
[ok] metrics twins agree on every non-zero counter
ScriptTwinParity.Tests: 8 passed, 0 failed, 0 skipped
ps5-exit=0
```

Hostile-code-page PowerShell 7 command and output:

```text
> & 'C:\Windows\System32\cmd.exe' /d /c 'C:\Windows\System32\chcp.com 437 >nul && "C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -File src\core\tests\hooks\ScriptTwinParity.Tests.ps1'
[ok] template-checks clean and planted drift agree in order
[ok] template-checks Common Tasks twins agree on planted inventory failures and edge fixtures
[ok] template-checks accepts both layouts and rejects missing or divergent framework sections
[ok] template-checks rejects an Unreleased head at the stamped version but accepts a dated one
[ok] docs-sync-check branches and advisory prose agree
[ok] sync-agent-files recursively produces identical trees
[ok] sync-agent-files twins fall back to the current directory outside Git
[ok] metrics twins agree on every non-zero counter
ScriptTwinParity.Tests: 8 passed, 0 failed, 0 skipped
ps7-cp437-exit=0
```

The PS 5.1 + CP437 attempt passed both B-58 template-check cases but the overall suite reported
7 passed / 1 failed because `Get-FileHash` was unavailable to the unrelated recursive-sync case in
that particular launch. Normal PS 5.1 and hostile-code-page PS 7 are green above; I did not alter
the unrelated test to manufacture a green result.

Final hygiene commands and output:

```text
> git diff --check
diff-check-exit=0

> # inspect the first three bytes of every created/edited source .ps1
.claude/hooks/tests/SkillListParity.Tests.ps1 bom=efbbbf
src/core/scripts/template-checks.ps1 bom=efbbbf
src/core/tests/hooks/ScriptTwinParity.Tests.ps1 bom=efbbbf
```

The requested full `validate-dist` and full hook suites were not run.

## Assertions not shown failing

None of the new failure assertions were left without a red observation:

- duplicate detection: planted duplicate, both twins exit 1 with identical text;
- ordinal inventory equality: planted one-sided slug and case variant;
- zero-extraction guard: grammar break in both files, both twins exit 1 with identical text;
- one-sided section presence: planted by `ScriptTwinParity.Tests.ps1` for both twins;
- code-span parity: natural Angular `add-tests` red before the source correction.

The absent-from-both branch is a required success/skip-reporting branch rather than a failure
assertion; it was reached and its explicit `OK:` text is asserted by the twin suite.

## Spec concerns after implementation

I followed the locked design where my judgement differed.

The verification wording that `git status --porcelain dist/` "must show ONLY your intended angular
AGENTS.md change" is inconsistent with implementing a shared shipped script and shared shipped
test under `src/core`: a correct rebuild necessarily changes those generated files in all three
dists, as the observed output shows. Treating only Angular AGENTS as allowable would require either
hand-editing dist or failing to compose the new gate, both contrary to meta-invariant #1.

The supplied WindowsApps `pwsh` path was not executable from the active PowerShell environment.
The installed host resolved to `C:\Program Files\PowerShell\7\pwsh.exe`, which was used for the
real runs. This is an environment-path discrepancy, not a design change.
