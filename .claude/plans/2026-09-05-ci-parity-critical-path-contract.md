# CI native-host parity critical-path contract

**Status:** ACCEPTED WITH CONDITIONS — implementation authorized after the conditions recorded in
this frozen contract; immutable-range independent review remains required.

## Proportionality and boundary

The baseline GitHub run `33980347537` completed all eight required Windows contexts in 16m12s, but
`windows-ps51` waits for the whole PS7 root job and every `windows-hooks-ps51` matrix leg waits for
the whole PS7 dist matrix solely so each PS5.1 job can download and compare one case-count manifest.
Move only that comparison to one downstream decision. Keep the eight native execution contexts and
their commands unchanged; do not add a platform/provider leg, path skipping, cache, ceiling increase,
or test-content reduction. No runtime improvement may be claimed until a comparable stable candidate
CI run is observed.

## Frozen implementation surface

- `.github/workflows/ci.yml`: remove only the two PS7→PS5.1 `needs` edges; make all four execution
  job definitions publish their own manifests; add one Windows parity job that runs after all four
  definitions, even when an upstream job did not succeed.
- `.claude/scripts/assert-ci-case-parity.ps1` (new): a PS7/PS5.1-compatible, CI-only decision that
  requires the exact eight named artifact directories and files, validates the existing
  `Suite.Tests.ps1<TAB>positiveInt` rows plus a unique positive matching `TOTAL`, rejects
  missing/extra/empty/malformed inputs, and byte-compares the four root/dist PS7↔PS5.1 pairs. It
  does not deserialize untrusted objects or infer ambient release state. Read/enumeration failures
  are explicit CANT-VERIFY diagnostics with nonzero exit, not reported as mismatch or empty data.
- `.claude/hooks/tests/CiCaseParity.Tests.ps1` (new): execute that exact decision against bounded
  artifact fixtures. No generic mutation/checker framework.
- `.claude/hooks/tests/Invoke-HookTests.ps1`: add exactly `CiCaseParity.Tests.ps1` to its explicit
  expected-file list; do not change runner scheduling or execution mechanics.
- `.claude/hooks/tests/ReleaseDistGateTiming.Tests.ps1`: update the real-workflow topology contract
  from four to five job definitions; retain all eight direct-host/matrix assertions and require four
  publishers, no execution-job dependency, and the one downstream decision with exact `needs`,
  Windows runner, `always()` condition, download, and decision-script call.
- `.claude/scripts/watch-ci.ps1` and `.claude/hooks/tests/ReleaseCiWatch.Tests.ps1`: require the
  parity decision in addition to the same eight execution contexts. Missing stays CANT-VERIFY;
  skipped/failed is RED; only all eight contexts plus parity success is GREEN.
- `DEVELOPING.md`, `meta/workspace-decisions.md`, and `meta/decisions-index.md`: describe the
  prospective topology as eight native execution contexts plus one required same-platform comparison;
  preserve WSD-073 rather than silently rewriting its historical decision.
- `.claude/hooks/tests/PowerShellTopology.Tests.ps1` is reviewed but need not change: its existing
  active-workflow scan already rejects a non-Windows runner or container for the new job.

No release/product/dist/installer files or the three B-228 test files are in this contract.

## Acceptance and hostile controls

1. The four existing execution definitions still expand to exactly eight native Windows contexts,
   each writes and publishes exactly one non-optional manifest, and none waits for another execution
   definition. The parity job alone needs all four definitions.
2. A clean fixture with eight nonempty manifests and four byte-equal pairs exits 0. Independently,
   a missing artifact/file, an empty or malformed/zero-count manifest, an incorrect/duplicate total,
   or one unequal pair exits nonzero and names the pair or input. An unreadable directory/file is
   diagnosed as CANT-VERIFY, not mismatch/empty. Download completes before the decision;
   directory/file cardinality is checked.
3. Workflow mutations deleting/skipping the parity job, deleting one native-host definition or one
   publisher, weakening `always()`/`needs`, or bypassing the decision call make focused structural
   checks red. The actual decision step must propagate its exit and may not use `continue-on-error`,
   a conditional skip, or a bare token-presence-only invocation. Watcher fixtures separately show
   parity absent→CANT-VERIFY and parity skipped/failed→RED.
4. Direct PS7 and native PS5.1 focused runs cover the parity decision, workflow topology, watcher,
   and existing PowerShell-only topology; PS1 BOM and exact host/version evidence are retained.
5. After all writers freeze, the ordinary full same-tree aggregates establish correctness. The first
   immutable candidate GitHub run must show all eight contexts plus the required parity decision;
   its wall time is reported as observed rather than attributed solely to this change.

## Deferred prerequisites

GitHub scheduling/runtime improvement, artifact-service behavior, and watcher observation are not
closed by offline fixtures. They require the immutable reviewed candidate run. This contract does
not alter B-224/B-225 host/value evidence, B-216/B-226 product authority, or release authorization.
