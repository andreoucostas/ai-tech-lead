# Batch 1b implementation report — 2026-08-20

Branch: `codex/batch1-release-tooling`. No commit, merge, or push was performed.

## B-87 — opt-in maintainer commit-subject guard

### Change

- `.claude/git-hooks/commit-msg:1` is the opt-in Git launcher. It resolves PowerShell 7 from `PATH`,
  the MSI location, or a version-globbed MSIX location and invokes the validator with Git's message
  file. It is maintainer-only and is not under `src/` or `dist/`.
- `.claude/scripts/check-commit-subject.ps1:1` reads the first subject line and rejects fewer than
  10 characters, punctuation-only text, and the existing MSYS signature.
- `.claude/scripts/_commit-subject.ps1:1` owns that signature. `.claude/scripts/release.ps1:175`
  dot-sources it, so the release and ordinary-commit callers cannot drift.
- `.claude/hooks/tests/CommitMessage.Tests.ps1:1` covers literal `@`, punctuation-only, too-short,
  MSYS-mangled, and a passing subject copied verbatim from repository history.
- `DEVELOPING.md:24` documents the one-line opt-in command:
  `git config core.hooksPath .claude/git-hooks`.

Factoring was safer than duplication here: both consumers are PowerShell validators. The shell hook
contains no copy of the signature; it only resolves a PS7 host and hands off the message-file path.

### Red evidence

Command on the unfixed tree after adding the recurrence test, before adding its subject validator:

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File .claude/hooks/tests/CommitMessage.Tests.ps1
```

Output (the missing validator made every direction demonstrably red):

```text
[FAIL] rejects the observed literal-at corruption -- literal @ did not explain the rejection: The argument '...check-commit-subject.ps1' is not recognized as the name of a script file.
[FAIL] rejects a punctuation-only subject longer than the minimum -- punctuation-only rejection was not identified: ...
[FAIL] rejects a short alphanumeric subject -- short-subject rejection was not identified: ...
[FAIL] rejects the release MSYS-path corruption signature -- MSYS rejection was not identified: ...
[FAIL] accepts a realistic subject from this repository history -- realistic subject was rejected: ...
CommitMessage.Tests (B-87 commit subject guard): 0 passed, 5 failed, 0 skipped
COMMIT_TEST_RED_EXIT=5
```

### Green evidence

Same command after implementation:

```text
[ok] rejects the observed literal-at corruption
[ok] rejects a punctuation-only subject longer than the minimum
[ok] rejects a short alphanumeric subject
[ok] rejects the release MSYS-path corruption signature
[ok] accepts a realistic subject from this repository history
CommitMessage.Tests (B-87 commit subject guard): 5 passed, 0 failed, 0 skipped
COMMIT_TEST_GREEN_EXIT=0
```

### Not observed

The Git launcher itself is a POSIX shell file. Bash cannot start in this sandbox, so I could not
install/invoke the actual `commit-msg` launcher. The PowerShell validator behavior is observed; the
shell handoff and executable-mode behavior have no runtime evidence and need reviewer execution.

## B-132 — explicit PowerShell 7 agent-eval boundary

### Change

- `.claude/evals/run-agent-evals.ps1:1` now declares `#Requires -Version 7.0`.
- `.claude/evals/tests/AgentEvals.Tests.ps1:7` retains the explicit `pwsh` self-test, then on Windows
  directly probes Windows PowerShell 5.1. It requires the version-prerequisite error and rejects
  `CannotConvertArgumentNoMessage` and `utf8NoBOM`.
- `.claude/scripts/release.ps1:595` invokes the canonical wrapper through an explicit `pwsh` outer
  host instead of invoking the runner directly.
- `DEVELOPING.md:288` distinguishes the PS7-only eval harness from the repository-level
  representative dual-host obligation and names `ReleaseCiWatch.Tests.ps1 -SelfTest` for that leg.
  Root `CLAUDE.md` and `AGENTS.md` were not changed.

### Red evidence

The direct unfixed baseline was:

```powershell
& 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -NoProfile -File .claude/evals/run-agent-evals.ps1 -SelfTest
```

```text
Cannot bind parameter 'Encoding'. Cannot convert value "utf8NoBOM" ...
FullyQualifiedErrorId : CannotConvertArgumentNoMessage,run-agent-evals.ps1
PS5_AGENT_EXIT=1
```

I also ran the new wrapper against a full temporary `git archive HEAD` (unfixed runner), with the
working-tree wrapper copied over it:

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File $scratch/.claude/evals/tests/AgentEvals.Tests.ps1
```

```text
Windows PowerShell 5.1 did not report the declared version prerequisite:
Cannot bind parameter 'Encoding'. Cannot convert value "utf8NoBOM" ...
FullyQualifiedErrorId : CannotConvertArgumentNoMessage,run-agent-evals.ps1
AGENT_WRAPPER_UNFIXED_EXIT=1
```

This distinguishes the fix from the old failure rather than merely requiring any non-zero exit.

### Green evidence

Canonical recurrence wrapper:

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File .claude/evals/tests/AgentEvals.Tests.ps1
```

```text
PASS: fixture creation
...
PASS: PowerShell UTF-8 BOM
AGENT_WRAPPER_GREEN_EXIT=0
```

Direct PS7 self-test stayed green with the same first/last PASS lines and
`DIRECT_PS7_SELFTEST_EXIT=0`.

Direct PS5 boundary after the fix:

```text
The script 'run-agent-evals.ps1' cannot be run because it contained a "#requires" statement for Windows PowerShell 7.0.
FullyQualifiedErrorId : ScriptRequiresUnmatchedPSVersion
PS5_BOUNDARY_EXIT=1
```

Representative hostile-code-page runs:

```powershell
& 'C:\Windows\System32\chcp.com' 437
& 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -NoProfile -Command '"HOST=$($PSVersionTable.PSVersion) CODEPAGE=$([Console]::OutputEncoding.CodePage)"; & .claude/hooks/tests/ReleaseCiWatch.Tests.ps1 -SelfTest; exit $LASTEXITCODE'
& 'C:\Windows\System32\chcp.com' 437
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -Command '"HOST=$($PSVersionTable.PSVersion) CODEPAGE=$([Console]::OutputEncoding.CodePage)"; & .claude/hooks/tests/ReleaseCiWatch.Tests.ps1 -SelfTest; exit $LASTEXITCODE'
```

```text
HOST=5.1.26100.9168 CODEPAGE=437
ReleaseCiWatch.Tests (B-88 CI watch): 21 passed, 0 failed, 0 skipped
PS5_CP437_EXIT=0
HOST=7.6.5 CODEPAGE=437
ReleaseCiWatch.Tests (B-88 CI watch): 21 passed, 0 failed, 0 skipped
PS7_CP437_EXIT=0
```

The `-SelfTest` output included all four planted-mutation assertions (`red`, `legs`, `unknown`, and
`event`) as `[ok]`, establishing the suite's red reachability in each host run.

### Encoding-operation evidence and limitation

```powershell
$base=(git show HEAD:.claude/evals/run-agent-evals.ps1 | Select-String -AllMatches 'utf8NoBOM' | ForEach-Object Matches | Measure-Object).Count
$work=(Select-String -Path .claude/evals/run-agent-evals.ps1 -AllMatches 'utf8NoBOM' | ForEach-Object Matches | Measure-Object).Count
git diff -U0 -- .claude/evals/run-agent-evals.ps1 | Select-String 'utf8NoBOM'
```

```text
ENCODING_COUNT_HEAD=232 WORKTREE=232
```

The diff search emitted no lines. Thus this branch currently has 232 matching encoding operations,
not the historical 200, and this change modifies none of them. No fixture-byte oracle exists, so I
do not claim the self-test proves BOMless fixture bytes.

### Not observed

I did not execute a full `release.ps1` release recurrence: it is destructive/external and the brief
forbids commit/push. The release binding is inspected and the wrapper itself is executed, but the
complete release path remains unobserved.

## B-85 — PowerShell-host recovery for the bash validator

### Change

- `scripts/validate-dist.sh:384` still prefers `pwsh`, `powershell`, and `powershell.exe` from
  `PATH`, then probes the MSI path, a version-globbed MSIX package directory, and Windows PowerShell
  5.1 before staying FATAL.
- Its final diagnostic now says no host was found on `PATH` or at known locations and explicitly
  identifies a host/PATH problem, not a dist problem.
- `scripts/validate-dist.sh:404` keeps the one-process timing rationale and removes only the refuted
  MSIX-causation parenthetical.
- `scripts/validate-dist.ps1:426` mirrors the host/PATH diagnostic contract while deliberately
  retaining its in-process AST parser. That twin is already executing inside a resolved PowerShell
  host; spawning a different absolute host would silently upgrade a deliberate 5.1 validation and
  change existing behavior.

### Green evidence (PowerShell twin only)

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File scripts/validate-dist.ps1 dotnet -Check ps-syntax
```

```text
OK:   all 38 *.ps1 files parse cleanly.
TIMING    0.1s  all 38 *.ps1 files parse cleanly.
All dist validation checks passed for dist\dotnet.
VALIDATE_PS_SYNTAX_EXIT=0
```

### Not observed

The entire bash leg is unobserved: no syntax parse, no clean run, no broken-PATH MSI recovery, no
MSIX-glob arm, no Windows PowerShell fallback, and no all-locations-missing FATAL arm. Bash cannot
start in this sandbox, as stated in the brief, so none of those assertions could be shown failing
or passing. The PowerShell-twin run above is not a proxy for them. No new B-85 automated test was
added because any locally runnable PowerShell-only/static test would falsely imply evidence about
the bash resolver; reviewer execution is required.

## Common checks

All seven touched/new `.ps1` files reported `PARSE_ERRORS=0` and `BOM=True`:

```text
.claude/evals/run-agent-evals.ps1
.claude/evals/tests/AgentEvals.Tests.ps1
.claude/hooks/tests/CommitMessage.Tests.ps1
.claude/scripts/_commit-subject.ps1
.claude/scripts/check-commit-subject.ps1
.claude/scripts/release.ps1
scripts/validate-dist.ps1
```

`git diff --check` emitted no output. No `dist/` file was changed. No absolute user-home path was
written to repository files.

## Pushback / brief corrections

1. The brief's “200 encoding operations” is historical, not current on this already-modified
   branch. The measured HEAD and worktree count is 232; the relevant invariant still holds because
   the counts are equal and the zero-context diff contains no `utf8NoBOM` line.
2. Literal mirroring of bash's absolute-host resolver into `validate-dist.ps1` would be mistaken:
   that script necessarily already has a host and intentionally supports direct 5.1 execution.
   I mirrored the diagnostic/intent in the twin but did not add dead candidate code or replace the
   in-process parser with a host-spawning implementation.
3. I found no other incorrect requirement. The only material verification gaps are the shell legs
   and full release recurrence stated above.
