# Batch 3 implementer report — 2026-08-20

No commit, merge, tag, or push was performed. No process was terminated.

## B-153 — MSYS dist-root paths

Changed `scripts/validate-dist.sh:459` to detect `/drive/...` paths in the generated `.ps1` file
inventory, require `cygpath`, translate each path with `cygpath -w` before invoking the Windows
PowerShell host, and emit a specific FATAL when `cygpath` is absent or fails. Relative and `C:/...`
spellings are left unchanged. Added regression case 39 at
`.claude/hooks/tests/ValidateDist.Tests.ps1:458`, with an independent `.ps1` population count.

Red/green evidence: **not observed**. The entire bash leg is unavailable in this sandbox. The
baseline commands under both PowerShell hosts reached Git Bash and returned repeated:

```text
bash.exe: *** fatal error - CreateFileMapping ... Win32 error 5. Terminating.
Guard.Tests (guard.ps1 + .sh twin parity): 2 passed, 80 failed, 0 skipped
```

Those counts are host-failure noise, not B-153 evidence. Case 39 was therefore neither shown red on
the unfixed code nor green on the fix, and neither CI leg has evidence for this modified case.

## B-154 — dated changelog/tag reconciliation

Added `DocTruth.Tests.ps1:36`: every dated root `## X.Y.Z — YYYY-MM-DD` head must resolve at
`refs/tags/vX.Y.Z`. The inline exception list contains only `0.48.0` and explains why. Added the
same explanation beside `CHANGELOG.md:610`; no tag was created. The check is in the meta suite, not
the release script.

Clean green, observed under both local PowerShell hosts through the suite's 5.1 arm:

```text
> & 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File .claude/hooks/tests/DocTruth.Tests.ps1
[ok] every dated root changelog release has a corresponding git tag or declared exception
[ok] the suite also passes under Windows PowerShell 5.1
DocTruth.Tests (the authoring docs describe the repo that exists): 10 passed, 0 failed, 0 skipped
GREEN_EXIT=0
```

Required scratch-clone red: **not observed**. Two `git clone --local` attempts failed before a clone
was created because Git's own `sh.exe` hit the same `CreateFileMapping ... error 5`. No real tag was
touched. Consequently the new assertion was not demonstrated failing here. The Windows execution
is green evidence only; the Linux meta-suite leg has no evidence.

## B-130(a) — Guard stderr capture under 5.1

Changed `src/core/tests/hooks/Guard.Tests.ps1:23` (composed into all three dists) to strip only a
line-leading `<command>.exe : ` native-error decoration from each twin's captured stderr, then keep
the existing ordinal equality assertion. Added an explicit Windows PowerShell 5.1 self-arm at line
61, following the existing DocTruth pattern: direct 5.1 runs skip recursion; missing 5.1 reports a
skip rather than a pass.

Before/after counts under pwsh 7 and Windows PowerShell 5.1: **not honestly measurable on this
host**. Both before runs became `2 passed / 80 failed` because every `.sh` invocation died before
guard behaviour ran. The after runs would fail for the same unrelated reason, so I did not present
them as green. The requested 36/30 versus 66/0 historical baseline and the expected repaired counts
need reviewer execution on the functioning-bash host. Neither the Windows nor Linux shipped-suite
CI leg has evidence for this modified case.

## B-130(b) — docs-sync-check exit mismatch

The brief's requested first diagnostic change is already present in the checked-out tree.
`ScriptTwinParity.Tests.ps1:20` defines `AssertExit` with both exit codes and both twins' stdout and
stderr, and the docs case uses it at line 105. I did not replace or duplicate it.

Observed command and result:

```text
> & 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -NoProfile -File src/core/tests/hooks/ScriptTwinParity.Tests.ps1
[FAIL] docs-sync-check branches and advisory prose agree -- docs-sync-check exit mismatch 0/256
PS OUT: Framework template repo ... All deterministic framework checks passed.
SH ERR: bash.exe: *** fatal error - CreateFileMapping ... Win32 error 5. Terminating.
ScriptTwinParity.Tests: 0 passed, 9 failed, 0 skipped
```

Diagnosis: **the historical divergence is not determined here**. The enhanced assertion proves only
that this sandbox cannot start bash (PowerShell exit 0, bash-wrapper exit 256). It rules out neither
the historical encoding hypothesis nor a product defect on a host where bash runs. I stopped rather
than guessing, as requested.

## B-155 — grep execution failure versus no match

Changed `scripts/validate-dist.sh:280-346`. The textual-file inventory, target-heading read,
batched citation read, and per-heading match now capture grep status: 0 continues, 1 is an ordinary
empty/no-match result, and >1 exits 2 with:

```text
FATAL: could not execute grep while resolving section-path citations — this is a host/resource problem, not a content problem.
```

The batched reads remain batched through bash arrays; no retry, waiver, or parallelism reduction was
added. The PowerShell twin was inspected and not edited because it uses in-process .NET reads and
regex/hash lookups. Added case 38 at `ValidateDist.Tests.ps1:314`; existing case 18 remains the
ordinary missing-heading control and case 12 the full clean control.

Red/green evidence for the new bash case: **not observed**, because bash cannot start. Case 38 was
not shown failing on unfixed code or passing on fixed code. The ordinary absent-heading bash path
and bash clean pass are likewise unobserved here. Neither CI leg has evidence for the modified case.

Sweep results (reported, not broadened into speculative fixes):

- `src/core/scripts/docs-sync-check.sh`: several `grep -q`/`|| missing=...` content verdicts conflate
  execution error with absence (banner, mirrored headings, README skill/agent mentions, architecture
  hash). These require coordinated twin/test work, not a one-line batch edit.
- `src/core/scripts/framework-doctor.sh`: import, heading, and pending-marker `grep -q` branches also
  conflate execution error with product state; this is the same reporting-risk family.
- `src/core/scripts/impact-run.sh`: the project-detection `grep -q .` can turn execution failure into
  a routing decision; the later `|| true` sites intentionally absorb optional command failure.
- `warehouse-map-check.sh`, `template-checks.sh`, and `wiki-check.sh` contain extractor-shaped
  `|| true` uses where no match is expected, but execution failure is also swallowed. Each needs a
  separate contract decision before editing.
- Count/normalisation `grep -c ... || true` and `sort || true` sites in `validate-dist.sh` are not
  direct content predicates; some can still hide tool failure, but they are not the same one-line
  heading-verdict shape. The no-meta-leak scan already distinguishes grep errors explicitly.

## Other verification

PowerShell BOM and parser sweep:

```text
.claude/hooks/tests/DocTruth.Tests.ps1 BOM=True PARSE_ERRORS=0
.claude/hooks/tests/ValidateDist.Tests.ps1 BOM=True PARSE_ERRORS=0
src/core/tests/hooks/Guard.Tests.ps1 BOM=True PARSE_ERRORS=0
dist/dotnet/tests/hooks/Guard.Tests.ps1 BOM=True PARSE_ERRORS=0
dist/angular/tests/hooks/Guard.Tests.ps1 BOM=True PARSE_ERRORS=0
dist/monorepo/tests/hooks/Guard.Tests.ps1 BOM=True PARSE_ERRORS=0
```

All three builds completed (`170`, `166`, `180` files). Focused PowerShell validation passed for
`ps-syntax,template-checks` on all three dists, including `all 38 *.ps1 files parse cleanly` and
`All dist validation checks passed`. Full validation on each dist stopped at the unavailable bash
syntax host with `FATAL: no working bash found`; those are not green gate runs. `git diff --check`
produced no output.

## Pushback / known gaps

The brief is stale only on B-130(b)'s diagnostic assertion: the requested code already exists and
is better than the quoted bare message. I found no basis to disagree with the other locked designs.
The required red evidence is absent for B-153, B-154, B-130(a), and B-155 for the reasons above;
those cases are not done under the repository's fifth Definition-of-done bullet until the reviewer
runs them on the missing legs and the first CI run is green.
