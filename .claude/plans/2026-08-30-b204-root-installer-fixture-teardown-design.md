# B-204 — RootInstallerWarehouse fixture teardown truth

**Date:** 2026-08-30
**Filed against:** v0.78.3
**Planned:** v0.78.4
**Status:** DESIGN AMENDED AFTER ADVERSARIAL REVIEW — implementation pending

## Value and proportionality decision

Do B-204 now and keep it P2/S/meta-only. During B-203's unchanged full maintainer battery,
`RootInstallerWarehouse.Tests.ps1` printed a `Remove-Item` sharing-violation error from fixture
teardown but still reported 12/0 and contributed a green file result. Seven GUID-scoped
`root-installer-dotnet-*` roots remain under the workspace parent across three dates: six empty
roots and one retained `.git` plus the exact `Nx prose` fixture. Their mixed provenance prevents
attributing every leak to B-203's run, but demonstrates recurrence. The installer assertions
themselves did not misreport; the false green is the suite's postcondition accounting and it leaks
workspace state.

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
local `Remove-TestFixtureTree` remover and one local `Invoke-WithTestFixture` lifecycle wrapper.
Route every recursive suite-owned tree lifecycle through the wrapper: the eleven `New-Target`
fixture sites and the adjacent `root-broken-jq-*` scratch site. Keep the deliberate non-recursive
`App.csproj` fixture mutation unchanged. Use wrapper-local names that cannot dynamically shadow the
fixture-body variables used by this PowerShell file.

The helper must:

1. Canonicalize the supplied path. Derive the one expected path from an exact allowlisted parent and
   a case-sensitive generated basename, then require `StringComparison.Ordinal` equality with that
   expected canonical path. Reject null, blank, or mismatched input before any removal. The only
   allowed basenames are exactly
   `root-installer-(warehouse|singlewarehouse|angularwarehouse|dotnet|mixed)-<32 lowercase hex>`
   beneath the workspace parent and `root-broken-jq-<32 lowercase hex>` beneath the OS temp root.
2. Treat `System.Management.Automation.ItemNotFoundException` from
   `Get-Item -Force -ErrorAction Stop` as unresolved, not automatically absent. On that outcome,
   non-recursively enumerate the exact trusted parent with `-Force -ErrorAction Stop` and select by
   ordinal basename equality. Return absent only when no such directory entry exists; inspect and
   reject a matching dangling link. Access, provider, and parent-inspection failures are not
   absence. On every attempt, use
   non-recursive breadth-first enumeration and reject the root or any child whose attributes or
   link metadata identify a reparse/symbolic link before enqueueing it. A present target must be a
   real directory. The GUID-owned fixture has no hostile concurrent actor; this is the bounded
   time-of-check/time-of-use assumption.
3. Return successfully when that typed oracle says the allowlisted target is absent. Otherwise make
   at most six removal attempts. Each uses literal-path recursive forced removal with
   `-ErrorAction Stop`; after success or a caught removal error, re-read the typed absence oracle.
4. After a failed non-final attempt, wait `100 * attempt` milliseconds before rescanning and
   retrying. This adds no delay on ordinary cleanup and caps deliberate failure-path waiting at 1.5
   seconds.
5. On the final failure or a surviving path, throw an actionable error naming the exact target,
   attempt count, and last failure. Never retry a containment or reparse-policy rejection.

The lifecycle wrapper must capture the fixture body and cleanup as two independent ErrorRecords.
When cleanup succeeds, rethrow the original body record unchanged. When only cleanup fails, throw
that record. When both fail, throw an `AggregateException` whose explicit outer message contains
the exact target and both messages (Windows PowerShell 5.1 does not render inner messages for us),
while retaining both underlying exceptions as inners. Thus cleanup truth cannot erase the product
assertion or let a mutation-red result pass for the wrong reason.

Preserve the current ordering that restores `$env:PATH` before cleaning the broken-jq fixture.
Do not suppress the terminal exception, delete pre-existing stale roots, or make cleanup best effort.
Preserve the PowerShell BOM and Windows PowerShell 5.1 syntax.

## Adversarial and verification contract

Before implementation, independently challenge path containment, symlink/reparse behavior,
case/path normalization, partial deletion between attempts, Windows PowerShell 5.1 compatibility,
exception truth, retry cost, and whether this should instead be closed as housekeeping. Reject any
design that could recurse outside the two exact generated-name namespaces or turn a terminal cleanup
failure back into a warning.

Use disposable, uniquely named paths only. The old boundary has been replayed under PowerShell 7
and Windows PowerShell 5.1: direct locked-file cleanup emitted non-terminating errors, left the path,
and the tiny harness stayed `PASS`/exit 0. Against the candidate, a persistently locked valid fixture
must throw after exactly six attempts and five sleeps totalling 1.5 seconds; a handle released
during backoff must let a later attempt remove the tree, and a second call must return absent. A
body `BODY_SENTINEL` plus the persistent lock must expose both body and cleanup messages and the
exact target. Repo-root, uppercase/case-different, and escaped-parent lookalikes must be rejected
without byte changes. Root and interior junction/symlink fixtures pointing to an outside sentinel
must be rejected without touching either side; the same contract applies to a dangling root link.
A disposable partial-deletion mutation must throw from removal after deleting the final entry, then
prove the post-error reinspection accepts only genuine root absence. The broken-jq dual-failure
probe must show `PATH` restored before the cleanup failure escapes. These are one-off probes, not
permanent test results.

Require the existing file to retain exactly 12 `It` results and its existing red mutations. Amend
each existing mutation callback to capture and re-emit its nested transcript, then deliberately
return green to `Invoke-MutationRedTest` unless the transcript contains that mutation's intended
warehouse assertion and sentinel. This makes a cleanup-only child failure fail the outer oracle
rather than count as the expected red. Its
normal matrix executes 79 cleanups, and the two nested mutation-red worlds add six more; measure the
focused runtime so safety scanning does not silently create material cost. Require each mutation-red
transcript to retain its intended warehouse assertion. Run the file focused under PowerShell 7 and
native Windows PowerShell 5.1, then run the standard concurrent meta runner once. The full runner
already contains the maintainer gates; rerun only record-sensitive focused gates after later record
edits. Compare isolated and concurrent results, but do not claim concurrency caused the original
lock unless reproduced discriminatively. Require BOM and zero AST errors under both PowerShell
hosts plus `git diff --check` and clean restore checks. The first Linux CI remains the ordinary
committed suite; it cannot execute an uncommitted one-off. Separately recorded native-Linux
dangling-root symlink/typed-absence execution of the exact candidate helper gates full safety
approval. If no such vantage is available, retain that explicit coverage gap and keep B-204 open;
local Windows link evidence and ordinary Linux CI do not satisfy it.

Because a test file changes, the exact implementation remains a candidate until its first Windows
and Linux CI runs are green. This meta-only change is not composed into `dist/`; do not run or claim
distribution composition as evidence. Do not push or release without separate authorization.

## RCA boundary

The root installer suite correctly put fixture deletion in `finally`, but treated execution of the
cleanup statement as equivalent to verified absence. PowerShell's default non-terminating error
semantics broke that equivalence, while the tiny harness catches only thrown exceptions. Simply
making cleanup terminating would introduce the inverse truth defect by masking an already-thrown
assertion, hence the lifecycle wrapper.

A bounded meta-test census found 62 lexical recursive `Remove-Item` sites across 18 files: 24 use
default error semantics, 37 explicitly choose `SilentlyContinue`, and one uses `Stop` for B-162's
best-effort stale sweep. RootInstallerWarehouse owns 12 of the 24 default sites. The other 12 mix
different verdict contracts, two deliberate mutation-body deletes, and B-162-mitigated scratch;
there is no evidence for changing them now. The exposed class is teardown or restore code whose
postcondition affects test isolation but whose errors cannot reach the result counter. B-204 fixes
only the twelve sites in the one observed file.
