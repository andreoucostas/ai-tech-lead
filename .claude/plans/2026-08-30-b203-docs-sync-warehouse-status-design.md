# B-203 — docs-sync warehouse status mapping

**Date:** 2026-08-30
**Filed against:** v0.78.3
**Planned:** v0.78.4
**Status:** AMENDED IMPLEMENTATION CANDIDATE — release-range product/test commit `16dbd95743163f5a92e9aacb23a946e056421a40` is locally green; corrected-record rereview and first provider CI pending

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
worlds, split stderr into physical lines on CRLF, LF, or CR; trim each line; and require exactly one
line whose text ends with the applicable sentinel using ordinal comparison. Require the new note
literally exactly once per wrapper, the missing/stale note absent, and each clean wrapper to exit 0.
`RunArg` decorates redirected native stderr with `NativeCommandError` under Windows PowerShell 5.1
and repeats the sentinel literal inside `CategoryInfo`, so raw literal cardinality and absence of
that harness decoration are explicitly invalid oracles. Retain a separate direct, no-redirection
Windows PowerShell 5.1 probe as implementation evidence.

Capture every template/consumer world and both twin results before making assertions, then assert
exit behavior, normalized stdout agreement, stdout/note literal cardinality, and the stderr
terminal-line cardinality per wrapper. This prevents the first failing unable world from hiding
whether the unexpected-status world also went red. Run the changed test against the unchanged
wrappers first: both unable worlds must be observed failing because the old note appears and the new
note does not. The corrected wrappers must make the same result green. This direct old-tree red is
sufficient; do not add a ceremonial post-green mutation, another wrapper run, or a new result.

## Design-lock review

Independent reviewers `/root/b203_design` and `/root/b199_adversary` blocked the first draft before
implementation. Their hostile probes established that both PowerShell hosts preserve child
`exit -1` as `$LASTEXITCODE = -1`, while Windows PowerShell 5.1's `RunArg` redirection can itself
decorate stderr with `NativeCommandError`. The corrected design therefore maps every observed
status outside 0/1, uses the negative unexpected-status oracle, and tests only sentinel survival
through the permanent harness. It also retains the existing missing-mirror branch in the status-0
world, captures all worlds before assertions, and makes every cardinality per wrapper. Both
reviewers approved that pre-implementation contract; the maintainer independently reproduced the
negative exit behavior under PowerShell 7 and Windows PowerShell 5.1.

## Implementation-time oracle amendment

The changed result against the unchanged wrappers was red exactly in both unable worlds for both
twins: each lacked the new note and emitted the contradictory old note. After the minimal product
branches, PowerShell 7 passed 10/10. Native Windows PowerShell 5.1 runs, including code page 437,
then falsified only the planned raw stderr-substring count: one child emission appeared twice
literally, first in the primary ErrorRecord line and again in `CategoryInfo`; wrapper notes and exits
were correct. Reviewers `/root/b199_adversary`, `/root/b203_design`, and `/root/b199_value`
approved the physical-terminal-line oracle above. It remains exact for one logical diagnostic and
still fails on two child emissions, without changing `RunArg`, adding a run, or weakening note/status
coverage.

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

## Local candidate evidence

Baseline source ScriptTwinParity passed 10/0. With only the existing result changed, the unchanged
wrappers passed 9/10 and the aggregate failure named status 2 and unexpected for both twins: each
unable world lacked the new note and emitted the contradictory old one. The two minimal product
branches made the suite pass 10/0 under PowerShell 7. After the evidence-driven stderr-oracle
amendment, the same source result passed 10/0 under PowerShell 7 and native Windows PowerShell 5.1,
both at code page 437 with Git Bash observed. A direct, no-redirection 5.1 fixture printed the child
sentinel, the new note, and final success line, omitted the old note and harness decoration, and
exited 0.

PowerShell and login-shell Bash composers each produced the same 525-file aggregate
(173/169/183), with zero hash differences. Both validator twins passed all three distributions.
Each distribution's standard hook runner passed 20 files with zero failures, including its composed
ScriptTwinParity 10/0 and warehouse checker 4/0; the maintainer runner passed 31 files with zero
failures, including Composer 16/0, BacklogHygiene 10/0, DocTruth 13/0, DocClaims 8/0, and release-head
8/0. All 12 changed source-to-dist carriers are byte-identical; both PowerShell files retain their
BOM and parse with zero AST errors, and the Bash product twin passes `bash -n`.

These are local Windows/Git Bash results, not native Linux or Bash 3.2 evidence. Because the existing
test changed, the exact candidate remains open until its first Windows/Linux CI is green.

## Immutable candidate review

Independent reviewer `/root/b203_immutable` began with this frozen contract and immutable range
`76cde44aa5cd0f0504267561fc0ae9795b4343e9..4e847b422f0267f65c474bb2091301905f956650`
in an isolated no-hardlinks clone. Replacing only the two authored product wrappers with their exact
contract blobs made the candidate test pass 9/10 and enumerate all eight expected failures: both
twins, both unable worlds, the missing new note, and the contradictory old note. Restoring the exact
candidate blobs returned the source result to 10/0 under PowerShell 7 and native Windows PowerShell
5.1 at code page 437; all three composed results also passed 10/0.

The review independently reproduced the Windows PowerShell renderer boundary (two raw sentinel
occurrences but one logical terminal diagnostic line) and a direct unredirected exit-2 run that
preserved the child diagnostic, emitted the exact new note and final success line, omitted the old
note, and exited 0. It also reconfirmed 12 source/dist hash pairs, eight BOM-bearing zero-AST-error
PowerShell carriers under both hosts, four `bash -n`-clean Bash carriers, unchanged suite/result
cardinality, both composers, both three-distribution validator twins, and the focused warehouse,
backlog, document, claim, and release-head gates. No native Linux or Bash 3.2 runtime was available;
approval is local-candidate evidence only, and first Windows/Linux CI still gates completion.

## Release-range amendment — errexit-safe manual status capture

The v0.78.4 whole-range review invalidated one implementation assumption before release. The
locked Bash design said to invoke the warehouse checker as a standalone simple command and capture
`$?` on the next line. When a caller explicitly adds `-e` before the documented script path, a
warehouse child status `1`, `2`, or `7` terminates the wrapper before that capture. Direct `-e` is
not a published general strict-mode contract. This amendment guarantees only that the wrapper's
three intentionally interpreted child-status branches remain reachable when a caller adds it. That
is worth preserving because B-203 and maintenance rule 7 deliberately distinguish content findings
from host/resource failures; bypassing those decisions loses the diagnostics the branches exist to
provide. Immutable candidate `e1cdb23` passes the normal source result 10/0, while the same
five-world matrix with explicit interpreter `-e` makes the B-203 result fail: the Bash twin leaks
each child status, omits the applicable advisory note, and never reaches the final success line.
The PowerShell twin retains the locked exit-0 behavior.

A bounded census found the same unreachable-capture shape in the wrapper's two AGENTS.md `grep`
probes. Status `1` can bypass the intended missing-content classification and status `2+` can leak
outside the documented wrapper `0/1` contract. Amend all three wrapper sites, and no others, to
errexit-safe conditionals: assign status `0` in the success arm and capture `$?` in the failure
arm. For the two `grep` probes, change the `case` selector from `$?` to that captured status while
retaining every case arm and message byte-for-byte; retain the warehouse `case` byte-for-byte.
Each child still runs exactly once; streams, status distinctions, accumulated-failure policy, and
final exit contract remain unchanged. Do not add `set +e`, change the PowerShell twin, suppress
output, or change any nested checker.

Strengthen only `docs-sync-check branches and advisory prose agree`: append a backwards-compatible
optional Bash-interpreter-options parameter to the existing `RunArg` harness. It defaults empty,
is prepended only in the Bash branch before `$Path`, and leaves existing script arguments,
positional callers, and PowerShell calls unchanged. Pass `-e` before the docs-sync Bash script path
in its five existing worlds. Keep the same processes, assertions, `It`, suite, result, fixtures,
and execution cardinalities. Evidence order is: recorded pre-amendment normal baseline 10/0;
changed-result/old-product explicit-`-e` with one existing `It` red; corrected-product explicit-`-e`
10/0; then one disposable ordinary-mode five-world rerun against corrected product, restored
afterward. Independently probe banner-missing and heading-missing AGENTS worlds red/green without
making either a permanent run. Exit `1` is not discriminating because both old and fixed worlds
return it: require the applicable `missing:banner` or missing-heading diagnosis and the terminal
aggregate failure line to be absent before the fix and present exactly once after it. Two probes
are justified because the banner failure prevents the old wrapper from reaching the loop site;
growing the permanent matrix would add less value than this direct evidence and bounded census.

The first design review correctly rejected exported `SHELLOPTS=errexit` as the B-203 oracle. Unlike
direct interpreter `-e`, exported shell options propagate into `template-checks.sh`,
`warehouse-map-check.sh`, `wiki-check.sh`, and any further Bash descendants. Concrete probes exposed
separate template-checks and warehouse-checker failures; the bounded source census identified the
additional candidates. That broader strict-mode contract is not documented and is not silently
claimed here. B-208 owns the evidence-first decision and full shipped-script census; it is
explicitly not a v0.78.4 gate.

## Release-range amendment implementation evidence

The existing result with only the `-e` interpreter option changed failed 9/1 against the exact
pre-amendment product: Bash leaked warehouse statuses 1, 2, and 7, omitted the applicable note, and
never printed the terminal verdict. The corrected product returned the result to 10/0 under
PowerShell 7, native Windows PowerShell 5.1, and code page 437. Removing only the three `-e` options
for one disposable ordinary-mode run also passed 10/0; restoring them reproduced the exact prior
test hash. Independent banner-missing and heading-missing probes made both products exit 1, but the
old product emitted neither the applicable diagnosis nor the aggregate failure line, while the
correction emitted each exactly once.

PowerShell and login-shell Bash composers produced the same 525-file aggregate at 173/169/183.
Both validator twins passed all three distributions. The three shipped hook batteries each passed
20 files with zero failures; the maintainer battery passed 31 files with zero failures. All 12
authored/generated carriers are byte-identical, both changed PowerShell sources retain their BOM
and parse with zero AST errors, and all four Bash carriers pass `bash -n`. Test/result/fixture and
execution cardinalities are unchanged. Three independent read-only reviews approved the design,
implementation, records, and test value.

The first immutable review of exact product/test commit
`16dbd95743163f5a92e9aacb23a946e056421a40`, tree
`da597fefcdf83626addb781632be9b08cd14116e`, reproduced the 9/1 old-product red and 10/0 candidate
green under both PowerShell hosts, plus both discriminating AGENTS probes. It rejected only stale
authoritative record text: this plan and B-203 still named the pre-amendment candidate, and the RCA
described the rejected raw-process reroute too broadly as any `RunArg` change. The current record
correction fixes that semantic defect without changing product or test bytes. Native Linux, stock
macOS Bash 3.2, the transitional frozen-parent run, and exact provider CI remain unclaimed gates.
