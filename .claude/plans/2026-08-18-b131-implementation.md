# B-131 implementation — marked-template changelog grammar

## Outcome

The release grammar now wins in both shipped `template-checks` twins, but only when the dist root
contains the `.template-repo` marker. A marked template requires `CHANGELOG.md` and requires its
literal first column-zero `## ` line to match `## X.Y.Z — YYYY-MM-DD`; the extracted version must
match `framework-version.json`. An unmarked consumer ignores `CHANGELOG.md` completely and retains
the CLAUDE/JSON pair check.

Changed only:

- `src/core/scripts/template-checks.ps1` and `.sh`, plus composed copies in all three dists.
- `ValidateDist.Tests.ps1`, adding one two-leg ownership/grammar case.
- This report and the required backlog RCA.

No version or changelog entry was written, per instruction. No unrelated code was reformatted.

The first full `validate-dist` run found a real authoring defect in my new comments: naming the
maintainer-only release script leaked denylisted meta vocabulary into both shipped twins. All three
dists reported the same two `no-meta-leak` findings. I replaced that comment-only name with
“release preflight,” recomposed, and the three validators then exited 0. This was changed within the
requested B-131 files and was not a sandbox-local RepositoryPrivacy/TwinParity result.

## RED observation

Before rebuilding the dists, command:

```text
pwsh -NoProfile -File .claude/hooks/tests/ValidateDist.Tests.ps1 -Only 'case 37: changelog-head grammar applies only to marked template repos on both twins'
```

Observed on the unfixed composed artifact:

```text
[ValidateDist ps marked-template-bad-changelog-head] EXIT=0
[FAIL] ... did not emit its target finding ...
ValidateDist.Tests (B-92): 0 passed, 1 failed, 0 skipped
EXIT=1
```

The harness stopped at its first failed assertion, so the pre-fix bash arm was **NOT OBSERVED**.
The assertion was nevertheless shown red for the precise defect: a marked malformed head passed.

## Post-fix two-direction, two-twin observation

After composing all three dists, the same command observed:

```text
[ValidateDist ps marked-template-bad-changelog-head] EXIT=1
FAIL: marked template repo CHANGELOG.md literal first '## ' line is '## Unreleased' ...
[ValidateDist bash marked-template-bad-changelog-head] EXIT=1
FAIL: marked template repo CHANGELOG.md literal first '## ' line is '## Unreleased' ...
[ValidateDist ps consumer-bad-changelog-head-ignored] EXIT=0
OK: version stamps in sync (0.60.0) (consumer repo — CHANGELOG.md ignored, pair-check only).
[ValidateDist bash consumer-bad-changelog-head-ignored] EXIT=0
OK: version stamps in sync (0.60.0) (consumer repo — CHANGELOG.md ignored, pair-check only).
ValidateDist.Tests (B-92): 1 passed, 0 failed, 0 skipped
EXIT=0
```

This observes both required directions on both twins. The marker distinction is a literal leaf-file
test, not a heuristic.

## Host coverage

PowerShell 7 was observed. Windows PowerShell 5.1 is absent and **NOT OBSERVED**. Bash was observed
through the repository's resolved bash host. BOM verification is covered by template-checks and the
workspace sweep; the authored PowerShell twin retained its UTF-8 BOM.

Final compose/validation command and output:

```text
pwsh -NoProfile -File scripts/build.ps1 <dist>                 # each of three dists
pwsh -NoProfile -File scripts/validate-dist.ps1 <dist>         # each of three dists
composed dist/dotnet (170 files)
composed dist/angular (166 files)
composed dist/monorepo (180 files)
BUILD=3xOK VALIDATE_EXIT dotnet=0 angular=0 monorepo=0
```

## Assertions not shown failing

The persistent test's pre-fix bash assertion and consumer-pass assertion were not reached on the
unfixed artifact because the first PowerShell assertion stopped the case. Both were observed in the
post-fix run. No claim is made that the pre-fix bash arm was independently red-tested.

The full meta-suite command
`pwsh -NoProfile -File .claude/hooks/tests/Invoke-HookTests.ps1` was attempted, but the execution
wrapper terminated it at 120 seconds before the buffered suite emitted results (`EXIT=124`). It is
therefore **NOT OBSERVED**, not green and not a repository failure. No RepositoryPrivacy or
TwinParity result was emitted during that attempt.
