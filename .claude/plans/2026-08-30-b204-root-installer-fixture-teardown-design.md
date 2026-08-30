# B-204 — RootInstallerWarehouse fixture teardown truth

**Date:** 2026-08-30
**Filed against:** v0.78.3
**Planned:** v0.78.4
**Status:** DESIGN LOCKED — implementation pending adversarial review

## Value and proportionality decision

Do B-204 now and keep it P2/S/meta-only. During B-203's unchanged full maintainer battery,
`RootInstallerWarehouse.Tests.ps1` printed a `Remove-Item` sharing-violation error from fixture
teardown but still reported 12/0 and contributed a green file result. Seven GUID-scoped
`root-installer-dotnet-*` roots remain under the workspace parent: six empty roots and one retained
`.git` plus the exact `Nx prose` fixture. The installer assertions themselves did not misreport;
the false green is the suite's postcondition accounting and it leaks workspace state.

The existing harness records failure only when an `It` body throws. The file's recursive cleanup
calls omit `-ErrorAction Stop`, so a Windows sharing violation is non-terminating and the body can
still return successfully. GUID paths exclude cross-test collisions, installer children are
synchronous, and no matching child remained after the observed run. A transient Git/Bash,
antivirus, or indexer handle is the leading explanation; process-heavy suite concurrency may amplify
it but is not yet proved causal.

This is distinct from B-162. That item best-effort sweeps old `validate-dist-*` and
`mutation-helper-*` trees under the OS temp root and intentionally cannot affect a product verdict.
B-204 concerns immediate teardown of this live suite's own workspace-parent fixture. Failed
teardown must make this test result fail after a short allowance for transient handle release.

Do not create a general cleanup framework, a stale workspace-parent sweeper, a new suite, or a new
`It`. The observed error plus one disposable locked-handle probe establishes the missing verdict
boundary. Normal existing worlds exercise successful cleanup repeatedly.

## Locked implementation

Change only `.claude/hooks/tests/RootInstallerWarehouse.Tests.ps1` plus maintainer records. Add one
local `Remove-TestFixtureTree` helper and route every recursive suite-owned tree cleanup through it:
the eleven `New-Target` fixture sites and the adjacent `root-broken-jq-*` scratch site. Keep the
deliberate non-recursive `App.csproj` fixture mutation unchanged.

The helper must:

1. Canonicalize the supplied path and reject null, blank, or non-allowlisted targets before any
   removal. The only allowed shapes are an immediate child of the workspace parent named exactly
   `root-installer-(warehouse|singlewarehouse|angularwarehouse|dotnet|mixed)-<32 lowercase hex>` or
   an immediate child of the OS temp root named exactly `root-broken-jq-<32 lowercase hex>`. On
   every attempt, a present target must still be a real directory rather than a root reparse point;
   otherwise throw without recursing.
2. Return successfully when the allowlisted target is already absent.
3. Make at most six removal attempts. Each attempt uses literal-path recursive forced removal with
   `-ErrorAction Stop`, then verifies the path is absent.
4. After a failed non-final attempt, wait `100 * attempt` milliseconds before retrying. This adds no
   delay on ordinary cleanup and caps failure-path waiting at 1.5 seconds.
5. On the final failure or a surviving path, throw an actionable error naming the exact target and
   attempt count. The existing `It` boundary must therefore record `FAIL`.

Preserve the current ordering that restores `$env:PATH` before cleaning the broken-jq fixture.
Do not suppress the terminal exception, delete pre-existing stale roots, or make cleanup best effort.
Preserve the PowerShell BOM and Windows PowerShell 5.1 syntax.

## Adversarial and verification contract

Before implementation, independently challenge path containment, symlink/reparse behavior,
case/path normalization, partial deletion between attempts, Windows PowerShell 5.1 compatibility,
exception truth, retry cost, and whether this should instead be closed as housekeeping. Reject any
design that could recurse outside the two exact generated-name namespaces or turn a terminal cleanup
failure back into a warning.

Use disposable, uniquely named paths only. First replay the old boundary with a locked file: the
direct cleanup emits a non-terminating error, leaves the path, and the tiny harness result stays
green. Against the candidate helper, a persistently locked valid fixture must throw after the bound;
after releasing the handle, the same helper must remove it. Also prove a repo-root/non-allowlisted
path is rejected without byte changes. These are one-off probes, not permanent test results.

Require the existing file to retain exactly 12 `It` results and its existing red mutations. Run it
focused under PowerShell 7 and native Windows PowerShell 5.1, then run the standard concurrent meta
runner once. Compare an isolated focused run with the concurrent result; do not claim concurrency
caused the original lock unless it is reproduced discriminatively. Run BacklogHygiene, DocTruth,
DocClaims, ClaimTruth, and release-head gates; require BOM and zero AST errors under both PowerShell
hosts plus `git diff --check` and clean restore checks.

Because a test file changes, the exact implementation remains a candidate until its first Windows
and Linux CI runs are green. This meta-only change is not composed into `dist/`; do not run or claim
distribution composition as evidence. Do not push or release without separate authorization.

## RCA boundary

The root installer suite correctly put fixture deletion in `finally`, but treated execution of the
cleanup statement as equivalent to verified absence. PowerShell's default non-terminating error
semantics broke that equivalence, while the tiny harness catches only thrown exceptions. The exposed
class is teardown or restore code whose postcondition affects test isolation but whose errors cannot
reach the result counter. B-204 fixes only the twelve recursive cleanup sites in the one observed
file; a wider sweep is unjustified without another measured instance.
