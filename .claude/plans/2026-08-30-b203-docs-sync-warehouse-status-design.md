# B-203 — docs-sync warehouse status mapping

**Date:** 2026-08-30
**Filed against:** v0.78.3
**Planned:** v0.78.4
**Status:** DESIGN LOCKED — implementation not started

## Value and proportionality decision

Do B-203 now and keep it P2/S. Both `docs-sync-check` twins run `warehouse-map-check` as an
advisory branch. The child contract distinguishes content debt (exit 1) from inability to examine
the repository (exit 2), while the process host can also surface unexpected results outside that
defined 0/1/2 contract. The wrappers currently translate every observed nonzero result into the
exact “missing or stale” note. A controlled exit-2 child therefore emits an accurate
unable-to-inspect diagnostic on stderr, after which the wrapper emits contradictory content debt,
exits 0, and finishes with `All AI Tech Lead framework checks passed.`

The harm is false assurance and wrong remediation on a supported failure path, not a blocking or
data-loss defect. The smallest honest fix is one captured status and one case split in each existing
wrapper. No checker behavior, warehouse status, invocation site, or overall docs-sync hard-failure
policy changes. Silence for anything outside 0/1 is rejected: the child normally explains the
cause, but only the wrapper can explain why that failure remains advisory despite the final success
line. A second detailed diagnosis is also rejected; the wrapper states only the policy mapping.

## Locked behavior

The wrapper executes the checker exactly once and maps its observed status as follows:

| Checker status | Wrapper addition | Warehouse branch effect |
|---:|---|---|
| 0 | no note | unchanged; continue |
| 1 | existing missing/stale note, byte-for-byte | unchanged advisory; continue |
| anything other than 0 or 1 | `NOTE: warehouse map could not be verified; this is not evidence that the map is missing or stale. (advisory - not a failure)` | preserve child stdout/stderr; continue |

The existing exit-1 line remains byte-identical. Do not suppress, capture, reformat, or redirect the
child's stderr. Do not rerun the checker, convert the branch into a hard failure, change the final
docs-sync success line, or infer any warehouse-map content/status from an execution failure.

## Twin implementation

In `src/core/scripts/docs-sync-check.ps1`, invoke the child as today, immediately copy
`$LASTEXITCODE` to a dedicated variable, then use mutually exclusive branches: `if` it equals 1,
emit the existing note; `elseif` it is not 0, emit the new note. This deliberately includes negative
statuses: direct probes observed both PowerShell hosts preserve `exit -1` as
`$LASTEXITCODE = -1`, which an `-ge 2` branch would miss. Do not add stderr redirection or
error-preference juggling: direct child stderr was observed to survive while native Windows
PowerShell 5.1 with `$ErrorActionPreference = 'Stop'` continued and retained the exit code.

In `src/core/scripts/docs-sync-check.sh`, invoke the child as a simple command, immediately copy
`$?`, and use a Bash-3.2-safe `case`: 0 does nothing, 1 emits the existing note, and `*` emits the
new note. Do not use `if ! ...`; inversion loses the original child status. Do not add `set -e`, a
pipeline, or redirection.

Only those two authored product scripts change. The existing core test is strengthened, and the
plan, backlog/RCA/learning records, root maintainer changelog, and three consumer changelogs are
updated separately. No stack override or monorepo sibling exists; compose the product result into
dotnet, Angular, and monorepo.

## One existing, discriminating oracle

Strengthen only `docs-sync-check branches and advisory prose agree` in
`src/core/tests/hooks/ScriptTwinParity.Tests.ps1`; keep suite and `It` cardinality unchanged.

Keep the existing `.template-repo` arm and run it once unchanged. For the consumer arm, install
controlled PowerShell/Bash checker stubs before its initial run. Use that initial, deliberately
one-sided skills-mirror fixture as the status-0 world: both child stubs emit a unique stdout sentinel
exactly once per wrapper; require the missing-mirror-directory failure exactly once per wrapper,
overall exit 1, and neither warehouse note. Then add the matching
`.github/skills/my-skill/SKILL.md` and use that clean fixture for status 1, status 2, and the
unexpected-status world. This preserves the distinct missing-directory oracle without an extra
wrapper run; B-149's `.claude/hooks/tests/DocsSyncCheck.Tests.ps1` remains the dedicated
content-mutation red-test for an existing mirror pair.

Overwrite both stubs explicitly before each status invocation and remove the fixture in `finally`,
so no result can inherit a previous world's stub. Status 1 emits a unique child stdout sentinel and
the existing missing/stale note exactly once, never the new note. Status 2 emits one unique stderr
sentinel per wrapper. The unexpected world uses a different world-specific sentinel from status 2,
identical only between its PowerShell stub that exits -1 and Bash stub that exits 7. In both unable
worlds, require the applicable sentinel and new note exactly once per wrapper, the missing/stale note
absent, and each clean wrapper to exit 0.
`RunArg` may decorate redirected native stderr with `NativeCommandError` under Windows PowerShell
5.1, so the permanent oracle must not assert that this harness decoration is absent; retain a
separate direct, no-redirection Windows PowerShell 5.1 probe as implementation evidence.

Capture every template/consumer world and both twin results before making assertions, then assert
exit behavior, normalized stdout agreement, and every sentinel/note cardinality per wrapper. This
prevents the first failing unable world from hiding whether the unexpected-status world also went
red. Run the changed test against the unchanged wrappers first: both unable worlds must be observed
failing because the old note appears and the new note does not. The corrected wrappers must make the
same result green. This direct old-tree red is sufficient; do not add a ceremonial post-green
mutation, another wrapper run, or a new result.

## Design-lock review

Independent reviewers `/root/b203_design` and `/root/b199_adversary` blocked the first draft before
implementation. Their hostile probes established that both PowerShell hosts preserve child
`exit -1` as `$LASTEXITCODE = -1`, while Windows PowerShell 5.1's `RunArg` redirection can itself
decorate stderr with `NativeCommandError`. The corrected design therefore maps every observed
status outside 0/1, uses the negative unexpected-status oracle, and tests only sentinel survival
through the permanent harness. It also retains the existing missing-mirror branch in the status-0
world, captures all worlds before assertions, and makes every cardinality per wrapper. Both
reviewers approved this exact corrected contract; the maintainer independently reproduced the
negative exit behavior under PowerShell 7 and Windows PowerShell 5.1.

## Verification and completion boundary

Preserve the UTF-8 BOM on both modified PowerShell files and require zero AST errors plus `bash -n`.
Run the focused source result under PowerShell 7 and native Windows PowerShell 5.1 with Git Bash
observed, including one code-page-437 run, then all composed ScriptTwinParity suites. Run both
composers and compare the complete trees, both validator twins for all three distributions, the
standard hook suites (`dist/<d>/tests/hooks/Invoke-HookTests.ps1` for all three distributions and
`.claude/hooks/tests/Invoke-HookTests.ps1`), and the
BacklogHygiene/DocTruth/DocClaims/release-head gates. Write the root `CHANGELOG.md` entry in the
maintainer/framework voice and the three `src/stacks/*/files/CHANGELOG.md` entries in consumer
voice. Record the implementation and RCA evidence on B-203 and append the applicable learning.

Because the test changes, B-203 remains an implemented candidate until its exact candidate's first
Windows and Linux CI runs are green. Git Bash is not Linux or Bash 3.2 evidence. Do not push or
release without separate authorization.

## RCA boundary

The direct warehouse checker suite distinguishes exits 1 and 2, but the wrapper parity fixture did
not install either checker, so the translation branch never executed. B-164's bounded sweep looked
for scripts that themselves exited nonzero after an external-tool failure; this branch deliberately
converts its child's nonzero status into advisory exit 0, so it fell outside that sweep predicate.
Twin agreement therefore said nothing about the child-status contract. The exposed class is any
wrapper that turns a multi-state child exit into a more specific content diagnosis; B-203 fixes only
this observed warehouse branch, while B-175 owns the distinct template-checker/doctor ambiguity.
