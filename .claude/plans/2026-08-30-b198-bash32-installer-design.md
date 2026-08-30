# B-198 — shipped installer Bash 3.2 compatibility

**Date:** 2026-08-30  
**Filed against:** v0.78.3  
**Planned:** v0.78.4  
**Status:** IMPLEMENTED CANDIDATE — local newer-Bash evidence complete; immutable review, exact macOS, and final-candidate CI pending

## Value and proportionality decision

Do B-198 now. The three consumer READMEs direct macOS users without PowerShell to
`scripts/install.sh`, but v0.76 introduced two associative-array declarations and two lowercase
expansions that require Bash 4. Stock macOS still supplies `/bin/bash` 3.2, so every installer mode
can abort while validating the incoming manifest, before any target mutation. This is a reachable
P1 regression on a promised whole-platform delivery path, not speculative cleanup, and belongs in
the already-unreleased v0.78.4 rather than being deferred to v0.78.5.

Preserve the duplicate-path guard. Both installer twins use a case-insensitive key because a
framework-authored inventory with two spellings of one path is ambiguous on common consumer file
systems; dropping that protection would exchange a compatibility failure for unsafe reconciliation.
The current ownership inventories contain 165/161/175 paths and the retirement ledger contains five;
all are ASCII. The bounded portable contract is therefore ASCII case folding for framework-authored
inventory paths. Do not grow B-198 into a Unicode normalizer or claim byte-for-byte equivalence with
PowerShell's `OrdinalIgnoreCase` outside that authored ASCII domain.

Do not add another installer suite, result, three-distribution matrix, or broad syntax grep. The
existing convergence result already reaches previous-manifest duplicate validation and can be made
discriminating with a case-variant row and an exact duplicate diagnostic. Composition proves the
same authored installer reaches all three distributions. One provider-specific macOS smoke is the
smallest permanent instrument that can execute the compatibility claim existing Windows and Linux
jobs literally cannot observe.

## Locked implementation

Change only `src/core/scripts/install.sh` for product behavior. In each manifest validator, remove
the associative array and `${path,,}` expansion. After the existing parse/cardinality checks, reuse
the now-dead NUL-comparison temporary file for one guarded `LC_ALL=C awk` pass. The pass emits an
ASCII-folded first field, a `0`/`1` duplicate flag from awk's associative set, and the unchanged
original row. The existing Bash loop then validates the original fields in the existing order,
checks the flag at the current duplicate-check point, and writes the same normalized three- or
four-column output. Explicitly test the awk command's status: these functions are called in `if !`
conditions, where relying on `set -e` would be false safety.

Use one awk process per validator, not per row. Do not use per-entry `tr`/`grep`, `nocasematch`,
`sort -f`, a Bash indexed-array scan, new temporary files, or changes to the PowerShell twin. Keep
the current diagnostic text, validation precedence, target mutation boundary, and output shape.
Then compose all three distributions from source.

In `.claude/hooks/tests/InstallerConvergence.Tests.ps1`, change the existing forged previous
manifest's second exact duplicate to an ASCII case variant and require the emitted duplicate-path
diagnostic. Add no suite or `It`; retain the unsafe and out-of-root sentinels in that same result.

## Focused provider leg and first-evidence transition

Add one required `macos-portability` job on the explicit current GA `macos-26` image. It must invoke
the step through stock `/bin/bash`, assert the captured interpreter is 3.2.57, and run only a direct
greenfield smoke of the committed dotnet distribution. Require exit 0, the greenfield completion
message, an unchanged consumer sentinel, and the installed ownership/version files. It must not
compose, validate all distributions, run hook/meta suites, or substitute for Windows/Linux CI.

The first candidate temporarily checks out frozen pre-B-198 product tree
`82383666425b0916c23fe2475ee71ef48a9327db` and, under the same exact
interpreter and equivalent fixture, requires that old installer to fail with its Bash-4 diagnostic
and leave the target byte-stable before requiring the candidate to succeed. After that transitional
red/green run is observed, remove the history-dependent arm while retaining the current direct
smoke. The resulting stable candidate must then pass the required macOS job and the normal Windows
and Linux jobs before B-198 can complete or v0.78.4 can release.

Add `macos-portability` to the release watcher's exact expected-job list and update only dependent
stubs. Strengthen the existing CI-topology result to require the explicit macOS runner, exact stock
interpreter assertion, direct dotnet smoke, and absence of a matrix/full-suite expansion. Add no
topology result. This narrowly supersedes B-70's absolute wording under WSD-061; its rejection of a
generic third test leg remains standing.

## Verification and completion boundary

- Before composition, run disposable ownership and retirement ledger worlds with independent ASCII
  case variants (including glob metacharacters as data). Each must exit 3 with the duplicate
  diagnostic and leave a consumer target byte-stable.
- Run the modified InstallerConvergence file under PowerShell 7 and native Windows PowerShell 5.1,
  observing the strengthened case for both installer twins with unchanged result cardinality.
- Run Bash syntax, both composers for all three distributions, exact source/dist hash checks, both
  distribution-validator twins, and the focused watcher/topology/record gates. Preserve mandatory
  PowerShell BOMs and AST validity.
- Freeze the implementation candidate and obtain an independent immutable review with an applied
  mutation that makes the strengthened duplicate assertion fail before exact-byte restoration.
- Local Git Bash is newer-Bash preservation evidence only. `BASH_COMPAT=3.2`, syntax search, and a
  generic macOS label are not Bash 3.2 evidence. B-198 remains open until the transitional macOS
  red/green, removal of its old-history arm, and final Windows/Linux/macOS CI are all observed.

## Explicit exclusions and follow-through

B-200 owns the separate BSD `date` provider defect and may later reuse the same focused macOS job;
it is not implemented here. B-205 owns the separately discovered Bash-4-only `globstar` use in
`sync-agent-files.sh`; it also may reuse the provider but is not B-198 scope. B-197's temporary-file
registry, root installer routing, PowerShell behavior, manifests, retirement contents, and release
mechanics are unchanged. No push, tag, or release is authorized by this plan.

## Candidate evidence (2026-08-30)

The authored installer now uses the locked two-pass total awk mechanism and all three composed
copies are byte-identical. Disposable current-dist probes passed one greenfield install and
independent ownership/retirement ASCII-case collisions containing `[`/`]`/`*` as data; each hostile
world exited 3 with its exact duplicate diagnostic and left the target byte-stable. Both composers
agreed on all 525 generated files. PowerShell and correctly provisioned Bash validator twins passed
173/169/183-file distributions; the first Bash-validator attempt deliberately does not count because
an over-narrow operator PATH hid both JSON providers and the validator failed closed before product
checks. A disposable PATH shim then made `awk` exit 91; the guarded validator surfaced its dedicated
diagnostic, exited 3, and left the one-file target unchanged.

The 12-result InstallerConvergence surface passed 12/0 under PowerShell 7/Git Bash
5.2.37, including the strengthened result for both twins. Native Windows PowerShell 5.1/CP437
returned 10/2: both strengthened forged-manifest results passed, while the two unchanged
reparse-retirement results failed in `finally`. A temporary detailed transcript located both at
line 144's `Remove-Item -Force` of a directory junction: the headless 5.1 host entered
`PromptForChoice` and threw `NullReferenceException`. The diagnostic harness change was restored
byte-identically and the 12 generated roots from these diagnostic runs were safely removed. B-206
owns that separate test-cleanup defect; it is not reported as a B-198 product regression or silently
fixed here.

Focused CI-topology, push watcher, and release watcher files passed 9/0 (after their intended
planted 7/1 red), 7/0, and 18/0. Workflow YAML parses; edited PowerShell files retain BOMs and parse;
all Bash installer copies pass syntax. No macOS job has run, so stock Bash 3.2, transitional
old-red/current-green, final stable macOS, and normal candidate Windows/Linux CI remain explicit
gaps. No push, tag, or release occurred.
