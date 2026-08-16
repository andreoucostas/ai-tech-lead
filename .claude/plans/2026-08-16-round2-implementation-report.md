# Round 2 implementation report — Part 1 remediation and B-60

Date: 2026-08-16. No commit or staging operation was performed.

## Part 1 — remediation

Implemented the Bash-3.2-safe Common Tasks inventory using `while read` and the repository's
space-delimited membership idiom. The load-bearing slug grammar is documented. Both twins now skip
inventory comparison when either section is absent. The PowerShell comparison documents that the
lowercase grammar makes case drift unparseable. The authoring-only description test now guards both
populations and the shared population, and duplicate slugs overwrite in the helper rather than
throwing. All stale WindowsApps PowerShell paths in `DEVELOPING.md` now use
`C:\Program Files\PowerShell\7\pwsh.exe` / `/c/Program Files/PowerShell/7`.

The round-1 `case-variant` fixture proves that the grammar excludes `Alpha`; it does not prove that
the comparison itself detects case drift.

### Green evidence

Command:

```powershell
$ps5="$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
& $ps5 -NoProfile -ExecutionPolicy Bypass -File src/core/tests/hooks/ScriptTwinParity.Tests.ps1
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File src/core/tests/hooks/ScriptTwinParity.Tests.ps1
```

Real output from each host:

```text
[ok] template-checks clean and planted drift agree in order
[ok] template-checks Common Tasks twins agree on planted inventory failures and edge fixtures
[ok] template-checks accepts both layouts and rejects missing or divergent framework sections
[ok] template-checks rejects an Unreleased head at the stamped version but accepts a dated one
[ok] docs-sync-check branches and advisories agree
[ok] sync-agent-files recursively produces identical trees
[ok] sync-agent-files twins fall back to the current directory outside Git
[ok] metrics twins agree on every non-zero counter
ScriptTwinParity.Tests: 8 passed, 0 failed, 0 skipped
PS5_EXIT=0 PS7_EXIT=0
```

### Red observations

For the reviewer's list-prefix probe, all six stock Common Tasks sections were changed from `- ` to
`* `, the test was run, and all dists were then rebuilt:

```text
[FAIL] stock Common Tasks descriptions keep code spans aligned per shared slug -- dotnet/CLAUDE.md yielded zero Common Tasks slugs; the parser is blind
SkillListParity.Tests (stock authoring mirrors only): 0 passed, 1 failed, 0 skipped
exit=1
```

The other two new population assertions were independently made reachable by applying the same
prefix mutation to AGENTS only, then by prefixing every parsed AGENTS slug with `z-`:

```text
[FAIL] ... dotnet/AGENTS.md yielded zero Common Tasks slugs; the parser is blind
AGENTS_ZERO_EXIT=1
[FAIL] ... dotnet Common Tasks inventories share zero slugs; no descriptions were compared
NO_OVERLAP_EXIT=1
```

The existing batched `absent-one` twin fixture was strengthened to reject the misleading inventory
message; both hosts' green run above therefore observes that one-sided sections emit only the real
missing-section finding.

Assertions not shown failing: **none**. Runtime execution on an actual stock macOS Bash 3.2 host was
not available; compatibility was instead checked by `bash -n` plus removal of every cited Bash-4
construct. That compatibility property is not represented as a new pass/fail assertion.

## Part 2 — B-60

Added check 12, `step-references`, to both validators and every registry specified by §4.2. It reads
each in-scope Markdown file once, blanks fences before both scans, applies the run-based contiguity
rule, excludes headings from prose-reference extraction, resolves file-scoped list/heading
definitions, reports coverage, and fails on zero files or zero prose references. The test batches
all fixtures through one scratch dist per validator leg.

### Red and green assertion evidence

Command:

```powershell
$env:PATH='C:\Program Files\PowerShell\7;'+$env:PATH
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File .claude/hooks/tests/ValidateDist.Tests.ps1 -Only 'case 35: step-reference grammar, vacuity guards and allowances agree on both validators'
```

Real result, identically exercised on `ps` and `bash` legs:

```text
step-zero-files             EXIT=1  step-reference scan found zero Markdown files
step-zero-references        EXIT=1  step-reference scan found zero prose references
step-heading-not-reference  EXIT=1  step-reference scan found zero prose references
step-broken-run             EXIT=1  ordered-list run starts at 3 (expected 0 or 1)
step-dead-reference         EXIT=1  prose step 9 has no ordered-list label or Step 9 heading
step-fenced-labels          EXIT=0  1 files scanned; 1 labels; 1 prose reference
step-heading-definition     EXIT=0  1 files scanned; 0 labels; 1 prose reference
step-multiple-lists         EXIT=0  1 files scanned; 4 labels; 1 prose reference
[ok] case 35: step-reference grammar, vacuity guards and allowances agree on both validators
ValidateDist.Tests (B-92): 1 passed, 0 failed, 0 skipped
EXIT=0
```

Thus every new B-60 assertion was observed red, while each required allowance was observed green.
Assertions not shown failing: **none**.

### Measured inventories

An independent read-only inventory using the same declared fence and heading exclusions produced:

```text
dotnet files=33 opens0=6 refFiles=6
angular files=31 opens0=5 refFiles=3
monorepo files=37 opens0=10 refFiles=6
```

These exactly match the locked spec.

### Targeted clean runs

Commands:

```powershell
foreach($d in 'dotnet','angular','monorepo') {
  pwsh -NoProfile -File scripts/validate-dist.ps1 $d dist -Check step-references
  bash scripts/validate-dist.sh $d dist -Check step-references
}
```

Real output (both twins agreed for each dist, all exits 0):

```text
dotnet:   33 files scanned; 175 labels found; 15 prose references found
angular:  31 files scanned; 149 labels found; 3 prose references found
monorepo: 37 files scanned; 208 labels found; 15 prose references found
PS/dotnet EXIT=0  SH/dotnet EXIT=0
PS/angular EXIT=0 SH/angular EXIT=0
PS/monorepo EXIT=0 SH/monorepo EXIT=0
```

Per instruction, no full hook suite and no full all-check validator run was performed.
