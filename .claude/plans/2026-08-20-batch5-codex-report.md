# Batch 5 implementer report — B-100 and B-83

Implementation is ready for independent review. I did not commit, merge, push, stage, or kill any
process. This report contains no machine-local home path.

## What changed and why

- `.claude/git-hooks/pre-commit:1` adds the opt-in Git entry point beside the existing
  `commit-msg` hook. It resolves PowerShell 7 and invokes the maintainer-only staged scanner.
- `.claude/scripts/check-staged-content.ps1:5` reads NUL-delimited staged names and index blobs with
  Git, not worktree files. Lines 36–40 reject a staged `.ps1` without the mandatory BOM. Lines
  43–49 send each staged blob to `src/core/.claude/hooks/guard.ps1`; there is no copied pattern set.
- `.claude/hooks/tests/StagedContent.Tests.ps1:49` covers BOM refusal, canonical-guard refusal,
  index-versus-worktree selection, and a clean staged set. Its four mutation modes make each new
  assertion fail independently.
- `DEVELOPING.md:25` documents both local hooks as opt-in, bypassable convenience nets and says
  plainly that they are not enforcement or server-side policy.
- `src/core/docs/enforcement-surfaces.md:49` now says explicitly that shell-authored and externally
  written content has no guard floor. The composed copies are the same line in each distribution.
- `.claude/hooks/tests/BacklogHygiene.Tests.ps1:64` correlates explicit `B-n` ids in the maintainer
  changelog and red-test ledger with open headings. Lines 223–249 print advisory findings, prove an
  open delivered fixture is detected, prove an archived-only fixture is excluded, and report
  missing filed-against stamps. These findings never fail the suite and never auto-close an item.
- `meta/BACKLOG.md:79` and the other 20 open headings now carry a filed-against release and date.
  The versions were derived from each entry's introduction commit and preceding release tag.
  Lines 423 and 1077 record implementation state and the required RCA for B-83 and B-100.
- `CHANGELOG.md:14` and each `src/stacks/*/files/CHANGELOG.md:7` add the required `0.63.0 —
  Unreleased` heads. B-83 is identified as meta-only; only the honest B-100 capability correction
  is consumer-facing.

Exactly six generated files changed: `dist/{dotnet,angular,monorepo}/CHANGELOG.md` and
`dist/{dotnet,angular,monorepo}/docs/enforcement-surfaces.md`. No maintainer hook, test, backlog
content, or runbook content reached `dist/`.

## Red and green evidence

### B-100 staged scan

Command, repeated with `bom`, `guard`, `staged`, and `clean`:

```text
pwsh -NoProfile -File .claude/hooks/tests/StagedContent.Tests.ps1 -RedTest <arm>
```

Observed red results:

```text
[FAIL] rejects a staged BOM-less PowerShell file -- BOM-less staged file passed
3 passed, 1 failed; EXIT=1

[FAIL] rejects a staged guard pattern through the canonical guard -- guard pattern passed
3 passed, 1 failed; EXIT=1

[FAIL] reads the staged blob rather than an unsafe worktree replacement -- worktree content leaked
3 passed, 1 failed; EXIT=1

[FAIL] allows clean staged content -- clean staged content failed
0 passed, 4 failed; EXIT=4
```

The clean-arm mutation replaces the checker with an unconditional refusal, so it also makes the
three refusal assertions fail for missing explanations. The named clean assertion itself is the
relevant red observation. An earlier first attempt at these mutation modes produced a PowerShell
parser error in the test harness; I corrected the quoting and do not count that attempt as red-test
evidence.

Clean command and result:

```text
pwsh -NoProfile -File .claude/hooks/tests/StagedContent.Tests.ps1
[ok] rejects a staged BOM-less PowerShell file
[ok] rejects a staged guard pattern through the canonical guard
[ok] reads the staged blob rather than an unsafe worktree replacement
[ok] allows clean staged content
StagedContent.Tests (B-100 staged snapshot scan): 4 passed, 0 failed, 0 skipped
EXIT=0
```

### B-83 ledger and stamp findings

Commands and observed planted findings:

```text
pwsh -NoProfile -File .claude/hooks/tests/BacklogHygiene.Tests.ps1 -RedTest stale-ledger
candidate stale heading: B-900
EXIT=1

pwsh -NoProfile -File .claude/hooks/tests/BacklogHygiene.Tests.ps1 -RedTest missing-filed-stamp
missing filed-against stamp: B-900
EXIT=1

pwsh -NoProfile -File .claude/hooks/tests/BacklogHygiene.Tests.ps1 -RedTest archived-ledger
archived id was reported: B-901
EXIT=1
```

The archived arm deliberately mutates candidate selection to include non-open ledger ids. The
clean control then proved that the same archived-only `B-901` fixture is not reported:

```text
[ok] an explicit delivery id is detected while its heading remains open
[ok] an archived ledger id is not a candidate stale open heading
[ok] every open entry records the version and date it was filed against
[ok] a fixture without a filed-against stamp is detected
BacklogHygiene.Tests: 10 passed, 0 failed, 0 skipped
EXIT=0
```

The live advisory output named 12 candidate open headings and reported no missing stamps. That
candidate set includes partial deliveries, which is expected and is the reason the check reports
for human resolution instead of blocking or closing.

The filed-against stamp would not have caught B-98, B-117, or B-148 on 2026-08-20: their deliverables
shipped and nobody returned to the heading. It addresses aged or refuted premises, not that
walk-back failure. The ledger correlation is the part that would have surfaced those three.

## Other verification observed

```text
pwsh -NoProfile -File scripts/build.ps1 <dist>   # dotnet, angular, monorepo
composed: 170 / 166 / 180 files; all three EXIT=0

pwsh -NoProfile -File dist/<dist>/scripts/template-checks.ps1
All deterministic framework checks passed; all three EXIT=0

pwsh -NoProfile -File .claude/hooks/tests/Invoke-HookTests.ps1 -File WorkspaceBom.Tests.ps1
4 passed, 0 failed, 0 skipped; EXIT=0

PowerShell parser/BOM probe
check-staged-content.ps1: BOM=True, PARSE_ERRORS=0
StagedContent.Tests.ps1: BOM=True, PARSE_ERRORS=0
BacklogHygiene.Tests.ps1: BOM=True, PARSE_ERRORS=0

git diff --check
no output; EXIT=0
```

All three `scripts/validate-dist.ps1` runs reached the bash-syntax phase and then printed `FATAL: no
working bash found` and exited 2. These are not green validator results. A dotnet hook-suite attempt
found Git Bash but every bash process failed at startup with a `CreateFileMapping` access error;
the suite finished with 161 failures. Those failures are environmental and broad, but the run is
red and provides no passing evidence for this change. Angular and monorepo hook suites produced no
completed result in that command, so they have no evidence.

## Assertions and legs I could not demonstrate

- I could not execute the extensionless `pre-commit` wrapper end to end because bash is unusable.
  The PowerShell checker behind it was exercised directly; the wrapper's bash behavior has no
  evidence here.
- I could not execute any bash leg, including validator bash syntax, shipped hook twins, or Linux
  file-mode behavior. There is no proxy claim for those legs.
- Windows PowerShell 5.1 is not installed or resolvable. The command-not-found attempt left a stale
  zero in `$LASTEXITCODE`; I explicitly reject that zero as evidence.
- `cmd.exe` is also unavailable, so I could not establish a hostile code-page run. Its
  command-not-found attempt likewise left a stale zero that is not evidence.
- Therefore the new/modified test-carrying change is not done under the repository's fifth
  Definition-of-done bullet until the reviewer runs every CI leg, especially bash/Linux. I did not
  run or claim the full meta suite green.
- I did not independently make the repository-wide BOM/parser sweeps fail; their existing positive
  controls did run and pass, while the new staged-BOM assertion itself was observed red and green.
- I did not mutate generated-file freshness after the final build. Recomposition succeeded and the
  generated diff is exactly the six expected shipped files, but the unavailable validator legs mean
  this is not full release evidence.

## Pushback / brief corrections

The brief's core premises are supported by the tree and the observed behavior. One wording needs a
qualification: the ledger signal does not identify only stale headings. It also names legitimate
partial deliveries (the live run did so), so calling every output row stale would be false. The
implementation labels them **candidate** stale headings and requires human review.

I also did not mark B-83 or B-100 done or move them to the archive. B-100 has not passed the required
bash/Linux review legs. B-83's original entry additionally contains older revalidation and sweep
work beyond the two locked deliverables in this brief. Closing either heading now would reproduce
the record-integrity error this batch is meant to reduce.
