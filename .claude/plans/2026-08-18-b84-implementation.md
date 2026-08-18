# B-84 implementation report — mutation helper

## Outcome

Added `.claude/hooks/tests/_MutationHelper.ps1`, a dot-sourceable, meta-only PowerShell helper. It copies a source root to a temporary scratch root, mutates only the scratch target, rejects a byte-identical mutation before invoking the command, prints changed line numbers with before/after text, requires a non-zero command exit (optionally one exact exit), restores the scratch target in `finally`, verifies byte identity, and removes the scratch copy.

The helper supports literal find/replace and line-addressed replacement. It deliberately does not claim reachability: every run prints `Reachability note: this diff proves the mutation applied; inspect it to confirm the changed line is on the executed path.` This directly exposes the B-144 failure class without pretending it can be solved generally.

No existing suite was retrofitted; the requested kit and its own proof are the entire change.

## Evidence

Command (pwsh 7):

```powershell
pwsh -NoProfile -File .claude/hooks/tests/_MutationHelper.ps1 -SelfTest
```

Observed output (exit 0):

```text
RESTORE verified byte-identical: subject.txt
[ok] no-match mutation threw "did not apply"
Mutation diff: subject.txt
  line 2 before: beta
  line 2 after : red
Reachability note: this diff proves the mutation applied; inspect it to confirm the changed line is on the executed path.
RED confirmed: command exit 7
RESTORE verified byte-identical: subject.txt
[ok] applied mutation made the command go red
Mutation diff: subject.txt
  line 1 before: alpha
  line 1 after : green
Reachability note: this diff proves the mutation applied; inspect it to confirm the changed line is on the executed path.
RESTORE verified byte-identical: subject.txt
[ok] applied mutation with a green command was rejected
[ok] source and restored scratch content were byte-identical
SELFTEST_EXIT=0
```

Command (Windows PowerShell 5.1):

```powershell
<windows>\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/tests/_MutationHelper.ps1 -SelfTest
```

Observed: the same four `[ok]` arms and diffs shown above; `PS51_SELFTEST_EXIT=0`.

Parser/BOM check observed `PARSE OK` and `BOM ...=True` for the helper under pwsh 7.

## Assertions not shown failing

None of the requested negative arms is missing: no-match and green-command paths both threw. The restore-corruption guard itself was not forcibly sabotaged; the self-test proves the normal restore is byte-identical.

## RCA

No existing gate caught unverifiable red-test rituals because mutations were disposable shell history rather than repository artifacts. Every meta gate red-test is exposed to the same no-op and unreachable-edit ambiguity until it adopts this helper or an equivalent change-and-diff discipline.
