# B-205 — Bash 3.2-safe skill-mirror sync

**Status:** COMPLETE — immutable candidate approved, macOS/Bash-3.2 support premise superseded by
B-209/WSD-064, and exact supported-host run `33333912064` at
`dbdc38f508463c3c2fa7cb3d55d830deb7cd014b` green · **Date:** 2026-08-30 · **Planned:** v0.79.0

Any pending-CI statements below preserve the chronology before the final supported-host run.

## Value decision

Original pre-B-209 decision: implement B-205 as P2/S for v0.78.4. The documented macOS command reaches a Bash-4-only
`shopt -s globstar` after `.github/skills` has already been replaced, so stock `/bin/bash` 3.2 can
leave a correct mirror behind while returning a false-red result and withholding completion. This
is a reachable shipped-provider defect, not a syntax-style preference.

The item was filed for no earlier than v0.78.5, but that target is superseded. The still-unreleased
v0.78.4 candidate already carries the one focused stock-Bash-3.2 job required by B-198, and WSD-061
allows another equally narrow proof in that same provider leg. Shipping the known false-red one
release later would weaken the macOS contract and require no less CI; inclusion adds no job or
matrix and is the lower-risk choice.

## Count decision

Remove the informational skill count from both twins instead of replacing its provider. The useful
contract is byte-identical mirroring plus an honest completion verdict; no documentation or caller
parses the number. Only one test literal names it. The count has already caused two post-mutation
cross-host failures: bare `find` resolved to Windows FIND.EXE, then its Bash-native replacement used
Bash-4-only `globstar`.

A new recursive provider would add PATH, traversal, symlink, unreadable-directory, newline, and
zero-match semantics only to retain decorative output. Absolute `/usr/bin/find | /usr/bin/wc` can be
made fail-honest with `pipefail`, but newline-bearing ancestors still distort a line count; fixing
that is disproportionate. A recursive shell function adds its own unreadable-directory and symlink
contract. A one-level glob is smaller but silently changes the PowerShell twin's recursive meaning.
Delete both count implementations and emit one exact shared verdict:

`Synced skills: .claude/skills -> .github/skills`

Do not replace the number with another metric or claim the success line proves byte equality. The
copy commands perform the work; tests and docs-sync enforce the mirror contract.

## Locked implementation

1. In `src/core/scripts/sync-agent-files.sh`, remove the `globstar`/`nullglob` option, array, and
   count. In the PowerShell twin, remove the recursive count provider. Change only their final
   success text to the exact count-free verdict above. Missing-source behavior, Git-root fallback,
   recursive replacement/copy behavior, exit semantics, and paths remain unchanged.
2. Strengthen the existing `sync-agent-files recursively produces identical trees` result without
   adding a suite or `It`. Require each twin independently to exit 0, emit the exact success line,
   and keep stderr empty. Fingerprint the canonical source fixture by relative path plus SHA-256 and
   require each mirror independently to equal it; comparing only the two mirrors allows identical
   omission or corruption to pass. Retain the nested supporting file so recursive copy remains
   observed.
3. Update the existing non-Git fallback result's exact stdout literal to the count-free verdict.
   Keep its per-twin exit, stderr, fallback calibration, and nested-byte assertions. Do not add a
   zero-skill or count case: the removed behavior no longer warrants coverage.
4. Compose both twins to all three distributions. Strengthen the existing macOS-topology assertion
   only enough to require that the focused job directly executes committed dotnet
   `sync-agent-files.sh`; do not permit a generic hook suite, composer, validator, matrix, or pwsh.
5. Add two small steps to the existing `macos-portability` job. A transitional frozen-tree step
   runs the exact pre-fix dotnet sync script under asserted `/bin/bash` 3.2, requires nonzero status,
   the `globstar` diagnostic, empty success stdout, and source/mirror byte equality after the false
   red. A current-tree step requires exit 0, exact count-free stdout, empty stderr, and source/mirror
   equality. After the first observed red/green run, remove the frozen-history step and retain the
   current direct smoke.

## Proportional evidence

- Before editing product twins, change only the two existing result assertions and run the exact
  Git Bash suite through an expected-red wrapper. Both results must reject the old count-bearing
  output; the main result must also prove its new non-vacuous exit/stderr/source comparisons execute.
- After implementation, require ScriptTwinParity to return the same 10/0/0 cardinality under
  PowerShell 7 and native Windows PowerShell 5.1 with Git Bash. Use a temporary equal-nonzero twin
  mutation to prove the strengthened main result rejects matching failures, then restore exact
  bytes and rerun green. Add no permanent result.
- Require source/dist byte parity, PowerShell BOM/AST and Bash syntax, both composers, all three
  distribution validators, the focused CI-topology/watch suites, and maintainer record gates.
- Exact stock macOS `/bin/bash` 3.2 old-red/new-green and final Windows/Linux/macOS candidate CI are
  mandatory before completion or release. Local Git Bash and `bash -n` are not substitutes.

## Adversarial review

Two independent read-only reviews approved IMPLEMENT and independently preferred count removal.
They rejected a replacement provider as disproportionate and found the existing main result could
pass matching nonzero exits, matching empty output, uninspected stderr, and identically wrong mirror
trees. The locked test strengthening incorporates those findings without growing cardinality.

No push, tag, or release is authorized by this plan.

## Implementation evidence — 2026-08-30

The two count providers are removed and the exact shared success verdict is implemented. Before
product editing, the two changed existing results alone failed 8/2 against the old count-bearing
output. After implementation they passed 10/0/0 under PowerShell 7 and native Windows PowerShell
5.1. A disposable mutation then forced both twins to copy successfully and exit 47 with matching
stderr; the same suite rejected the false parity 8/2. Exact candidate hashes were restored and the
source plus composed dotnet suite each returned 10/0/0 on both PowerShell hosts.

PowerShell and Bash composers independently converged at 173/169/183 files. Source and all three
generated copies share each script/test SHA-256, all PowerShell copies retain BOM and parse, and all
Bash copies pass syntax. Both validator twins passed dotnet, angular, and monorepo. The workflow
parses as YAML; ReleaseDistGateTiming passed 9/0/0 on both PowerShell hosts, PushAndCheck 7/0/0,
ReleaseCiWatch 18/0/0, and DocTruth 13/0/0. The permanent suite/result/job/matrix cardinalities are
unchanged.

The existing `macos-portability` job now carries the locked transitional frozen-tree oracle and
current committed-dotnet smoke. Their exact execution under stock `/bin/bash` 3.2, followed by
normal final-candidate Windows/Linux/macOS CI, remains pending and is not inferred from Git Bash.

Two independent read-only implementation reviews approved the stable diff with no findings. One
focused on evidence value and confirmed cardinality remains 10 `It` blocks, seven CI jobs, and two
matrices; the other independently reran ScriptTwinParity 10/0/0 and ReleaseDistGateTiming 9/0/0 on
both PowerShell hosts and checked Bash-3.2 syntax/quoting, the reachable frozen tree, and generated
hash/BOM parity. Neither review substitutes for the unobserved native provider or final CI.

The same portability reviewer then approved immutable candidate
`49bcbe9ecc39d987045e98d7b8d68c8709b1a372`, tree
`ae45d5129e0599f5db0444ee6a5fde9ff6bab0da`, from sole design parent
`f766e87b7165b89ddf8d5be682aa2e1ae6c22981`. It verified exact 24-file scope, functional blob
identity with the stable reviewed diff, authored/generated parity, and no worktree residue. The
review explicitly leaves stock macOS evidence, frozen-arm retirement, and final CI pending.

## Scope supersession (2026-08-30)

B-209/WSD-064 withdraws macOS and stock Bash 3.2 from the supported/tested host contract. The
provider steps and frozen-history completion gate are therefore removed rather than rerun. Retain
the implemented count deletion: removing decorative traversal and requiring an exact actionable
verdict remains a smaller, better contract on supported Windows/Linux hosts independent of macOS.
Do not claim Bash-3.2 compatibility. Retain the simplification in v0.79.0; completion now requires
the shared exact-candidate Windows/Linux CI only.
