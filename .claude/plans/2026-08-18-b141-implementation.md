# B-141 implementation report — DocTruth Windows PowerShell 5.1 parity

## Changes

Changed only `.claude/hooks/tests/DocTruth.Tests.ps1`:

- replaced recursive `-Include *.md` enumeration with `-Filter *.md`, so Windows PowerShell 5.1
  cannot return non-Markdown files to the phantom-marker test;
- replaced the backlog's implicit `Get-Content` decoding with
  `[IO.File]::ReadAllLines(..., [Text.Encoding]::UTF8)`, following the BOM-less UTF-8 precedent in
  `src/core/scripts/template-checks.ps1`;
- added a cross-host guard: when this suite is launched from pwsh on Windows, it also launches the
  same suite under Windows PowerShell 5.1 and requires exit 0. The 5.1 child does not recurse.

No assertion was weakened. The existing zero-ID vacuity assertion remains unchanged.

## Red evidence

Each requested fix was independently reverted in place, tested under Windows PowerShell 5.1, and
then restored.

### Markdown enumeration fix removed

Command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/tests/DocTruth.Tests.ps1
```

Observed:

```text
[FAIL] no doc documents the phantom marker ... documented in: .claude\hooks\tests\DocTruth.Tests.ps1
DocTruth.Tests (the authoring docs describe the repo that exists): 8 passed, 1 failed, 0 skipped
FILTER_REVERT_PS51_EXIT=1
```

This establishes that `-Filter *.md` is necessary on the affected host.

### Explicit UTF-8 decoding fix removed

Command: the same Windows PowerShell 5.1 invocation, after restoring `-Filter` and independently
reverting only `ReadAllLines(..., UTF8)` to `Get-Content`.

Observed:

```text
[FAIL] every live backlog item has a unique id -- BACKLOG.md yielded zero live item ids -- the heading grammar changed and this gate is blind
DocTruth.Tests (the authoring docs describe the repo that exists): 8 passed, 1 failed, 0 skipped
UTF8_REVERT_PS51_EXIT=1
```

This establishes that explicit UTF-8 decoding is independently necessary on the affected host.

## Final verification

The final two-host results are recorded after both fixes and the guard were restored:

```text
pwsh -NoProfile -File .claude/hooks/tests/DocTruth.Tests.ps1
DocTruth.Tests (the authoring docs describe the repo that exists): 9 passed, 0 failed, 0 skipped
exit 0

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/tests/DocTruth.Tests.ps1
DocTruth.Tests (the authoring docs describe the repo that exists): 9 passed, 0 failed, 0 skipped
exit 0
```

Additional observed file checks:

```text
PowerShell parser errors: 0
leading bytes: 239,187,191 (UTF-8 BOM preserved)
```

## Out-of-scope observation

`meta/BACKLOG.md` contains `### B-123b · ...` (observed at the current line 733), while the live-ID
regex remains `^### (B-[0-9]+) ·`. Consequently B-123b is omitted from the uniqueness population.
Per the task constraint, this was reported but not fixed.
