# B-148 implementation report

## Outcome

Added validator check 13, `prompt-hook-cardinality`, to both root validator twins and registered it
for focused selection and `--content-only`. It scans shipped `hooks.json` files, fails if
`userPromptSubmitted` has more than one entry, and has vacuity failures for zero `hooks.json` files
or zero parsed events. It is deliberately scoped to `userPromptSubmitted`; no other Copilot event
was included. `postToolUse` remains unrestricted.

The diagnostic states the observed delivery reason: Copilot CLI 1.0.80 delivers only the last
entry, so model-facing context must be composed into one hook. It also records that this is a
delivery constraint, not a design preference, and that a future vendor fix would leave the composed
hook valid and make the check a harmless anachronism.

Files changed:

- `scripts/validate-dist.ps1`
- `scripts/validate-dist.sh`
- `.claude/hooks/tests/ValidateDist.Tests.ps1`
- `meta/BACKLOG.md` (required delivery RCA)
- this report

The separately requested B-59 critique is in
`.claude/plans/2026-08-18-b59-sol-critique.md`; no B-59 guard code was written.

## Red and green evidence

Focused clean check:

```text
pwsh -NoProfile -File scripts/validate-dist.ps1 dotnet dist -Check prompt-hook-cardinality
OK:   Copilot userPromptSubmitted cardinality is delivery-safe (1 hooks.json file(s), 5 events; at most one entry per userPromptSubmitted).
All dist validation checks passed for dist\dotnet.
EXIT=0

bash scripts/validate-dist.sh dotnet dist -Check prompt-hook-cardinality
OK:   Copilot userPromptSubmitted cardinality is delivery-safe (1 hooks.json file(s), 5 events; at most one entry per userPromptSubmitted).
All dist validation checks passed for dist/dotnet.
EXIT=0
```

The added `Assert-Case` mutation parses the scratch dist's real `.github/hooks/hooks.json`, asserts
the clean fixture has exactly one entry, duplicates it, and asserts the mutated file has two before
running either validator:

```text
pwsh -NoProfile -File .claude/hooks/tests/ValidateDist.Tests.ps1 -Only 'case 36: a second userPromptSubmitted entry fails both validators'
[ValidateDist ps duplicate-user-prompt-hook] EXIT=1
FAIL: Copilot prompt-hook delivery constraint violated -- 1 finding(s). Only the last userPromptSubmitted entry is delivered by Copilot CLI 1.0.80, so compose into one hook instead; if Copilot later honours every entry, the composed hook remains valid and this check is a harmless anachronism.
  [prompt-hook-cardinality] .github/hooks/hooks.json : userPromptSubmitted has 2 entries; Copilot CLI 1.0.80 delivers only the last entry, so compose model-facing additionalContext into one hook instead
[ValidateDist bash duplicate-user-prompt-hook] EXIT=1
FAIL: Copilot prompt-hook delivery constraint violated -- 1 finding(s). Only the last userPromptSubmitted entry is delivered by Copilot CLI 1.0.80, so compose into one hook instead; if Copilot later honours every entry, the composed hook remains valid and this check is a harmless anachronism.
  [prompt-hook-cardinality] .github/hooks/hooks.json : userPromptSubmitted has 2 entries; Copilot CLI 1.0.80 delivers only the last entry, so compose model-facing additionalContext into one hook instead
[ok] case 36: a second userPromptSubmitted entry fails both validators
ValidateDist.Tests (B-92): 1 passed, 0 failed, 0 skipped
EXIT=0
```

The first bash red-test run exposed a CRLF bug in the new Python record stream:

```text
scripts/validate-dist.sh: line 1035: 5\r: syntax error: invalid arithmetic operator
ValidateDist.Tests (B-92): 0 passed, 1 failed, 0 skipped
EXIT=1
```

I fixed that executed-path defect by stripping the trailing carriage return from the parsed record
value, then reran the case to the green result above. This was part of making the requested bash
implementation work, not an unrelated change.

## Full validation — both twins, all three dists

Command: loop over `dotnet angular monorepo`, first with
`pwsh -NoProfile -File scripts/validate-dist.ps1 <mode> dist`, then with
`bash scripts/validate-dist.sh <mode> dist`.

```text
PS dotnet EXIT=0 :: All dist validation checks passed for dist\dotnet.
PS angular EXIT=0 :: All dist validation checks passed for dist\angular.
PS monorepo EXIT=0 :: All dist validation checks passed for dist\monorepo.
SH dotnet EXIT=0 :: All dist validation checks passed for dist/dotnet.
SH angular EXIT=0 :: All dist validation checks passed for dist/angular.
SH monorepo EXIT=0 :: All dist validation checks passed for dist/monorepo.
```

## Static and host evidence

Commands and observed outputs:

```text
bash -n scripts/validate-dist.sh
EXIT=0

[Management.Automation.Language.Parser]::ParseFile(...scripts/validate-dist.ps1...)
parse errors: 0

git diff --check
EXIT=0

BOM byte check
scripts/validate-dist.ps1 BOM=True
.claude/hooks/tests/ValidateDist.Tests.ps1 BOM=True

git diff -U0 -- <changed files> | rg 'Users[/\\][^/\\]+'
added-lines-machine-path-sweep=clean
```

Available PowerShell hosts:

```text
pwsh.exe 7.6.5.0
```

Windows PowerShell 5.1 was **NOT OBSERVED** because `powershell.exe` is absent on this host. I do
not infer 5.1 compatibility from the pwsh run.

## Unobserved assertions and scope

- The requested duplicate-entry assertion was observed red on both validator twins and green on the
  unmodified dist.
- The zero-`hooks.json` and zero-event vacuity branches were implemented but were **not separately
  planted and observed red** in this turn; no test for those branches was requested.
- The bash check's Python parser branch was observed. Its jq alternative was **not separately
  pinned and observed** for this new check.
- The complete `ValidateDist.Tests.ps1` suite was not run; the new case was run directly on both
  twins. Full validators themselves were run six times as recorded above.
- No other Copilot event was added. I see no evidence supporting inclusion of another event;
  `postToolUse` must remain out of scope.
- No shipped distribution or source artifact was edited, so there was no composer rebuild or
  shipped changelog/version change.
- I added the required delivery RCA to B-148 in `meta/BACKLOG.md`. This was not an implementation
  surface requested in the task, but root `CLAUDE.md` maintenance rule 5 requires it.
- Commit and push were attempted but **NOT OBSERVED**: this sandbox denied creation of
  `.git/index.lock`, and outbound access to GitHub was unavailable. Real output was
  `fatal: Unable to create '.git/index.lock': Permission denied` followed by
  `Failed to connect to github.com port 443`. The working-tree changes therefore remain uncommitted.
