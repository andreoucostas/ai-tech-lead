# B-209 — withdraw macOS from the supported and tested platform contract

**Date:** 2026-08-30
**Filed against:** unreleased v0.78.4 candidate
**Planned:** v0.79.0
**Status:** COMPLETE 2026-08-30 — design and implementation independently reviewed; exact supported
Windows/Linux run `33333912064` at `dbdc38f508463c3c2fa7cb3d55d830deb7cd014b` green; planned
v0.79.0

## Supported-host completion evidence

Both main jobs and all six distribution hook jobs passed. The main jobs completed native
composition, distribution freshness, context-footprint, all-distribution validation, and the root
meta suite. This supplies only the previously pending supported-host gate; the earlier topology red,
public-contract review, and no-replacement-test review remain the behavioral evidence. No macOS job
or evidence was required or produced under WSD-064, and this is not tag/publication proof. Any
pending-CI statements below are historical.

## Value and proportionality decision

Do this as a real support-boundary change, not as deletion of one failing CI job. The framework's
root positioning targets Windows teams, and the maintainer record contains no macOS consumer or
field evidence. In contrast, supporting stock macOS Bash 3.2 and BSD providers has created repeated
special-case design, verification, and CI work. The owner has confirmed that macOS is not needed.
That makes the recurring cost concrete and the expected platform value absent.

The current shipped READMEs nevertheless promise that macOS works out of the box. Removing only the
provider job would leave a false public contract. The smallest coherent change is therefore to make
Windows and Linux the supported/tested hosts and state explicitly that macOS, BSD-provider behavior,
and stock Bash 3.2 are unsupported and untested. Incidental compatibility is welcome but carries no
release gate or maintenance promise.

This is a breaking support change, so retarget the unreleased release head from `0.78.4` to
`0.79.0`. Do not rewrite historical released changelogs. Do not remove technical portability code
or comments merely because they mention BSD/macOS when they still make supported behavior safer.

## Locked implementation

1. Remove the `macos-portability` job from `.github/workflows/ci.yml`, remove it from
   `watch-ci.ps1`'s exact expected jobs and the `PushAndCheck` stub, and delete only the macOS
   topology helper/assertions from the existing `ReleaseDistGateTiming` result. Keep that result and
   its Windows/Linux matrix and root-meta assertions. Add no negative “macOS job must be absent”
   test, suite, result, fixture, matrix, or replacement runner.
2. State the platform boundary in the root README and all three consumer READMEs. Split the current
   combined macOS/Linux rows: Linux remains supported; macOS is unsupported and untested. Remove
   macOS from active command examples in `generate-copilot`, all three bootstrap/rebootstrap pairs,
   and all three CI-integration documents. Update the harness comment that incorrectly names macOS
   CI. Do not scrub released changelog history or implementation comments describing real provider
   differences.
3. Lead the root and all three consumer `0.79.0 — Unreleased` changelog heads with the support
   withdrawal. Reframe the current B-198/B-205 notes as best-effort Bash portability and remove
   stock-macOS/Bash-3.2 completion claims.
4. Add WSD-064 and the standing-decision index entry. WSD-064 supersedes WSD-061's active macOS
   provider decision without deleting its history or run `33328114479`'s useful false-green
   observation.
5. Move B-200 to `BACKLOG-DONE` as scope-closed without implementation. Retain B-197, B-198, B-205,
   B-175, B-193, B-203, and B-208 where their path safety, test truth, simplification, or general
   Bash/Linux value remains; remove only macOS/Bash-3.2 evidence blockers. B-198's reviewed awk
   implementation remains best-effort portability because it preserves duplicate-path safety and
   uses an existing installer dependency. B-205's decorative-count deletion remains valuable
   simplification independent of macOS.
6. Compose all three distributions from `src`; never edit generated `dist` files directly.

## Evidence and review contract

The old topology test must be observed red after the macOS job is removed and before its obsolete
macOS assertion is deleted. The amended existing result must then pass with unchanged result
cardinality and continue proving both Windows/Linux hook matrices and both root meta-suite jobs.
Run `PushAndCheck`, `ReleaseCiWatch`, record/document gates, both composers, exact source/dist parity,
all validators, and the relevant full suites. No macOS run is required or claimed.

The first candidate CI run `33328114479` is retained as evidence that the exact provider invalidated
the temporary historical exit-code oracle. It is not current-product macOS evidence. The same run's
Windows leg found a separate current-Git-for-Windows B-194 routing defect; B-209 does not waive or
absorb it. The supported Windows/Linux candidate must be green after B-194 is separately amended.

## Adversarial review disposition

Two independent read-only reviews accepted the withdrawal only if it changes the public support
contract, not merely CI. Both found the three shipped “works out of the box” promises and rejected
leaving them behind. Both recommended retaining B-198/B-205's already-reviewed useful code,
scope-closing B-200, preserving released history, adding no replacement test, and making the
breaking boundary conspicuous in the next release. Those findings are incorporated here.

## Implementation-candidate evidence

The implementation removes only the focused macOS job and its watcher/stub/topology dependencies;
the workflow retains four Windows/Linux job definitions expanding to the eight required watched
jobs. The topology result remains nine `It` blocks and its ordinary mutation was red before exact
restoration; PushAndCheck remains seven results. Public source and all generated READMEs now state
the Windows/Linux boundary, active command examples and CI docs no longer promise macOS, all seven
Unreleased changelog heads are v0.79.0, B-200 is scope-closed without implementation, and retained
items name only supported Windows/Linux CI as their active completion gate.

PowerShell and login-shell Bash composition each produced 173/169/183 files and the same binary dist
diff hash. Both validator twins passed all three distributions. ReleaseDistGateTiming 9/0,
PushAndCheck 7/0, ReleaseCiWatch 18/0, DocTruth 13/0, BacklogHygiene 10/0, and ClaimTruth 3/0 are
green. The full 31-file maintainer suite was green before the final reviewer-requested corrections;
the only executable correction was a case-sensitive match inside the existing UpdateDelivery
result. The directly affected record/truth gates and UpdateDelivery 51/0 were rerun green afterward.
All touched PowerShell files retain BOMs.

Two independent read-only implementation reviews found no public/CI scope defect after requesting
bounded corrections to active v0.78.4 plan targets, one lingering Bash-3.2 maintenance phrase, and
the staged B-194 evidence wording. Those corrections are incorporated. Exact supported
Windows/Linux CI remains mandatory because tests changed; no macOS evidence is required or claimed.

The first exact candidate run after this implementation, `33331472488` at
`aac420fddca414b6392feb3500f8af7ef52c4925`, made all six Windows/Linux hook-matrix jobs green. Both
main jobs stopped at the context-footprint gate: the committed generated distributions contained
the intended B-209 documentation changes, while their measured per-file baseline still described
the preceding tree. Distribution validation and the root meta suite were consequently skipped.
The run reached neither B-194's modern-provider product child nor the remaining gates and supplies
neither provider-red nor product-green evidence.

Regenerating the baseline changed only `chars`/`tok` for the same four altered carriers in each of
the three distributions (`docs/ci-integration.md` and the bodies of `bootstrap`,
`generate-copilot`, and `rebootstrap`). The static totals and ceilings remain unchanged at
39,582/40,000 for dotnet, 38,105/40,000 for Angular, and 47,098/48,000 for monorepo. Both the
PowerShell and login-shell Bash context-footprint checks pass with that exact baseline. A new exact
candidate run `33332160632` then reached B-194's expected unchanged-product provider red: native
Linux and all six per-distribution hook jobs were green, while Windows had exactly the one
UpdateDelivery failure. After the bounded B-194 product correction, a later all-green supported
Windows/Linux candidate remains mandatory for release.
