# B-59 implementation report

Implemented REV 2 sections 3a–3d in the shared `src/core` guard twins and fixtures. Section 3e's
NUnit POSIX grep was left unchanged as required.

## Delivered

- All 20 counted shell content sites route through `matches`, which uses
  `grep -Eq -- "$1"` and distinguishes match/no-match/error. `path_matches_i` uses
  `grep -Eiq --` only for the three deliberately folded filename predicates.
- Secret-pattern errors identify the pattern/category and fail closed. Test-defeat/suppression
  errors identify the pattern/category, warn on stderr, and allow. PowerShell uses the same split.
- All 19 content patterns are case-sensitive. The three file-routing predicates fold explicitly in
  both twins. The generic credential detector retains explicit folding and remains deliberately
  fail-open; that policy is stated at the pipeline and in WSD-046.
- Added mixed-case filename, adversarial-content, whole-file C#/TS, and mid-file fixtures without
  removing the original one-line cases.
- Added `GuardPatternErrors.Tests.ps1`, using `_MutationHelper.ps1` for secret and suppression
  invalid-regex mutations in both twins.

## Evidence

Pre-change replay used `git archive HEAD`, replaced only the archived fixture library with the new
one, and ran its `Guard.Tests.ps1`. Real result: `72 passed, 10 failed`; all six mixed-case filename
surface cases failed because the old shell twin allowed, and all four adversarial-content surface
cases failed because the old PowerShell twin blocked.

`pwsh -NoProfile -File .claude/hooks/tests/GuardPatternErrors.Tests.ps1`:

```text
RED confirmed: command exit 80  # PowerShell secret
RED confirmed: command exit 80  # shell secret
RED confirmed: command exit 56  # PowerShell suppression
RED confirmed: command exit 56  # shell suppression
GuardPatternErrors.Tests: 4 passed, 0 failed
```

Each mutation printed the before/after line, asserted the direct runtime policy and stderr
pattern/category, and restored byte-identically. `bash -n src/core/.claude/hooks/guard.sh` exited 0;
PowerShell AST parsing reported 0 errors; BOM probes reported `True` for every edited `.ps1`.

`pwsh -NoProfile -File scripts/build.ps1 <dist>` produced dotnet 170, angular 166, monorepo 180
files. `pwsh -NoProfile -File scripts/validate-dist.ps1 <dist>` passed all 13 checks for all three
dists, exit 0.

Shipped hook suites, real aggregate results:

- dotnet: **2 failures across 18 files**; Task 1 suites were green (`Guard.Tests: 82/0/0`). Both
  failures are the pre-existing `TwinParity.Tests` boy-scout shell queue mismatch.
- angular: **0 failures across 18 files**.
- monorepo: **2 failures across 18 files**; the identical boy-scout mismatch.

The focused dotnet `TwinParity.Tests.ps1` rerun reproduced `11 passed, 2 failed, 0 skipped`. This was
not changed because it is unrelated to B-59 and outside the authorised design.

The full meta runner reported **1 failure across 22 files**: `RepositoryPrivacy.Tests` treated the
sandbox's Git warning about an inaccessible global ignore file as a repository-relative path.
Focused rerun reproduced `5 passed, 1 failed`. `GuardPatternErrors.Tests` itself was green.

Direct Windows PowerShell 5.1 verification: **NOT OBSERVED**, per the stated host constraint. Some
existing suites printed internal 5.1-labelled cases as green; this report does not substitute those
for the requested direct host leg.

## Scope and assertions not shown failing

No requested B-59 assertion was left without a red observation. No versions, changelogs, or NUnit
grep were changed. Generated `dist/` files changed only through the composer. The only extra product
record is WSD-046, required by the locked design's fail-closed policy decision.

Commit/push was attempted with `git add ...; git commit -m "Implement B-59 guard hardening and
parity reachability"`. It could not begin because this execution sandbox has read-only `.git`
access: `fatal: Unable to create '.git/index.lock': Permission denied`. No commit or push is claimed.
