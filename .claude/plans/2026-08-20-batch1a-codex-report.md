# Batch 1a implementer report — 2026-08-20

No commit, merge, push, release, full meta suite, or bash command was run.

## B-150 — post-release eval prompt

Changed `.claude/scripts/release.ps1:22-25,862-899`:

- Added `-NoEvals`.
- The prompt now requires `-NoEvals` to be absent, an interactive session, unredirected stdin, and
  unredirected stdout.
- An explicit `-NoEvals` prints `Agent evals skipped. Run later: ...`; an unattended stream prints
  the existing non-interactive reminder. The declined-prompt skip line remains.
- The interactive `Read-Host` prompt remains unchanged.

Added `.claude/hooks/tests/ReleasePostEvalPrompt.Tests.ps1:1-48`. It checks the real release source,
and its detached harness extracts and executes the real condition under `Start-Process` with stdout
redirected and stdin untouched.

Red command and output on the unfixed source:

```text
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File .claude/hooks/tests/ReleasePostEvalPrompt.Tests.ps1; Write-Output "EXIT=$LASTEXITCODE"
[FAIL] the optional-eval prompt requires an attended output stream and supports -NoEvals -- release.ps1 has no explicit -NoEvals switch
[FAIL] a detached prompt harness with stdout redirected exits and records the skipped evals -- detached harness parked at Read-Host with stdout redirected and stdin left alone
ReleasePostEvalPrompt.Tests (B-150 post-success prompt): 0 passed, 2 failed, 0 skipped
EXIT=2
```

Green command and output:

```text
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File .claude/hooks/tests/ReleasePostEvalPrompt.Tests.ps1; Write-Output "EXIT=$LASTEXITCODE"
[ok] the optional-eval prompt requires an attended output stream and supports -NoEvals
[ok] a detached prompt harness with stdout redirected exits and records the skipped evals
ReleasePostEvalPrompt.Tests (B-150 post-success prompt): 2 passed, 0 failed, 0 skipped
EXIT=0
```

Attended-console evidence (PTY, entered `n` when prompted):

```text
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -Command '$NoEvals=$false; if (-not $NoEvals -and [Environment]::UserInteractive -and -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected) { $answer=Read-Host "Release succeeded. Run optional B-41 live agent evals now? [y/N]"; Write-Output "ANSWER=$answer" } else { Write-Output "NO_PROMPT" }'
Release succeeded. Run optional B-41 live agent evals now? [y/N]: n
ANSWER=n
```

Could not show failing: the assertion that the interactive prompt remains cannot fail on the
unfixed source because that prompt already existed and deliberately remains. The attended PTY run
is preservation evidence, not red/green evidence. The explicit-skip-output assertion was not
separately isolated red; it is inside the case already observed red because `-NoEvals` was absent.

Sweep result:

```text
rg -n "Read-Host|UserInteractive" .claude/scripts -g "*.ps1"
.claude/scripts\release.ps1:862:if (-not $NoEvals -and [Environment]::UserInteractive -and -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected) {
.claude/scripts\release.ps1:863:    $runAgentEvals = Read-Host "Release succeeded. Run optional B-41 live agent evals now? [y/N]"
```

No other branch of this shape was found under `.claude/scripts/`.

## B-151 — dist-gate attribution

Changed `.claude/scripts/release.ps1:518-528` to print one standalone
`TIMING <distribution> <seconds>` line per completed dist job. It uses the job's real
`PSBeginTime`/`PSEndTime`, matching the meta runner's measurement shape. It does not alter or append
to any `RESULT` line.

Added `.claude/hooks/tests/ReleaseDistGateTiming.Tests.ps1:1-19`, which bounds the dist-gates stage
and asserts real-job timing plus a standalone `TIMING` format.

Red command and output with the final test pointed at the timing-less implementation:

```text
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File .claude/hooks/tests/ReleaseDistGateTiming.Tests.ps1; Write-Output "EXIT=$LASTEXITCODE"
[FAIL] dist-gates emits one standalone TIMING line per distribution job -- dist-gates does not measure each real job run
ReleaseDistGateTiming.Tests (B-151 dist-gate attribution): 0 passed, 1 failed, 0 skipped
EXIT=1
```

Green command and output:

```text
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File .claude/hooks/tests/ReleaseDistGateTiming.Tests.ps1; Write-Output "EXIT=$LASTEXITCODE"
[ok] dist-gates emits one standalone TIMING line per distribution job
ReleaseDistGateTiming.Tests (B-151 dist-gate attribution): 1 passed, 0 failed, 0 skipped
EXIT=0
```

Could not show failing: none of this test case's substantive assertions lacked a red observation.
I did not run a real release merely to obtain a multi-minute sample `TIMING` value; the focused
test verifies the instrumentation wiring, not the full dist jobs' execution.

## B-94 — staged-set guard record and quoted paths

Changed:

- `.claude/scripts/release.ps1:657-669`: corrected the comment to say refusal empties the index and
  preserves worktree changes; added `-c core.quotepath=false` to the raw cached diff.
- `CHANGELOG.md:781-788`: narrowed the claim to paths outside known top-level locations and corrected
  the reset/worktree statement.
- `meta/BACKLOG-DONE.md:993-999`: corrected B-80's archived record to index reset plus untouched
  worktree.
- `.claude/hooks/tests/ReleaseStagingGuard.Tests.ps1:99-122`: the renamed reset test now starts with
  a genuinely pre-staged tracked change and proves both an empty index and surviving worktree
  content; a real `meta/café.txt` fixture covers default git quoting.

Red command and relevant output on the unfixed guard:

```text
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File .claude/hooks/tests/ReleaseStagingGuard.Tests.ps1; Write-Output "EXIT=$LASTEXITCODE"
[ok] the guard region can be extracted from release.ps1, and is neither too small nor too large
[ok] a release touching only tracked locations passes, and prints a manifest
[ok] a stray untracked file is refused, the index is reset, and the worktree is untouched
[FAIL] a staged non-ASCII path under meta is classified as expected -- expected EXIT=0, got 2:
Staged manifest (1 path(s)):
  "meta/caf\303\251.txt"
FATAL: 1 staged path(s) are outside where this repo keeps files -- refusing.
  "meta/caf\303\251.txt"
[ok] -AllowExtraStagedPaths proceeds on a stray file, but still warns
[ok] a worktree gitlink is refused, and -AllowExtraStagedPaths does NOT bypass it
[ok] the allowlist refuses none of the last 8 real releases
ReleaseStagingGuard.Tests (B-80 staged-set guard): 6 passed, 1 failed, 0 skipped
EXIT=1
```

Green command and output:

```text
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File .claude/hooks/tests/ReleaseStagingGuard.Tests.ps1; Write-Output "EXIT=$LASTEXITCODE"
[ok] the guard region can be extracted from release.ps1, and is neither too small nor too large
[ok] a release touching only tracked locations passes, and prints a manifest
[ok] a stray untracked file is refused, the index is reset, and the worktree is untouched
[ok] a staged non-ASCII path under meta is classified as expected
[ok] -AllowExtraStagedPaths proceeds on a stray file, but still warns
[ok] a worktree gitlink is refused, and -AllowExtraStagedPaths does NOT bypass it
[ok] the allowlist refuses none of the last 8 real releases
ReleaseStagingGuard.Tests (B-80 staged-set guard): 7 passed, 0 failed, 0 skipped
EXIT=0
```

Could not show failing: the new pre-staged-index removal and worktree-survival assertions pass on
the unfixed source because the guard behavior was already correct; the defect was the record and
the old fixture's inability to distinguish "left as found" from "reset." The changelog/comment/
archive corrections are prose truth fixes and have no behavioral red state. The non-ASCII case did
show red and green. Existing unmodified guard cases were rerun but were not independently mutated.

## Verification and limits

Final focused run: all three files passed (2 + 1 + 7 cases, zero failures). PowerShell AST parsing
reported `PARSE_ERRORS=0` for every touched `.ps1`. Byte checks reported `BOM=True` for all four:

```text
.claude/scripts/release.ps1 BOM=True
.claude/hooks/tests/ReleaseStagingGuard.Tests.ps1 BOM=True
.claude/hooks/tests/ReleasePostEvalPrompt.Tests.ps1 BOM=True
.claude/hooks/tests/ReleaseDistGateTiming.Tests.ps1 BOM=True
```

`git diff --check` produced no output. I did not run the whole meta suite or a real release, per the
brief's focused-test instruction and because a release would mutate git/remotes.

## Pushback / brief accuracy

I found no implementation-blocking error in the brief. Strictly, redirected stdout does not prove
that nobody is reading the output (a log may be tailed), but it does prove the prompt is not on the
attended console that could answer `Read-Host`, so it is the correct safety signal here.

No file other than `.ps1` or `.md` was touched.
