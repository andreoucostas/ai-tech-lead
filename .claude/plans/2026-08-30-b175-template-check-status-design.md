# B-175 · Template-check status contract — locked design

**Status: IMPLEMENTED CANDIDATE 2026-08-30 — two immutable reviews approved; first candidate CI
pending.** Two independent exact-record reviews approved after narrowing the reach claim,
preserving Bash transport, making both doctor messages causally generic, and requiring independent
`2`/`3` boundary mutations.

**Pre-implementation evidence correction.** The first captured red run disproved both reviewers'
claim that the existing `9.9.9` fixture alone creates two findings: it creates one because the
version checks are one `if`/`elseif` chain. The contract is unchanged; the locked fixture now pairs
that version drift with an independently missing `copilot-instructions.md` to construct exactly two
verified findings rather than assuming them.

**Decision record:** `meta/workspace-decisions.md` WSD-063 · **Backlog entry:** B-175

## Premise and value

The premise still holds against v0.78.4. Both `template-checks` twins use exit `2` for a required
CHANGELOG read failure and otherwise exit with the number of verified findings. Two ordinary
findings therefore collide with “could not verify.” Both doctor twins classify that collision as
verified drift and recommend documentation repair. The B-156 review ledger records a forced
`grep`-2 resource world for the Bash checker; the current source preserves that reachable branch.

The demonstrated harm is a false, specific remediation when the doctor runs in a marked template or
self-host context whose required CHANGELOG cannot be inspected. That branch does not ship as a
consumer state because installers exclude `.template-repo`; installed consumers are statically
exposed to the same false `MISSING` classification if the checker terminates abnormally, but no such
consumer failure is claimed as observed here. The defect is uncommon and remains P3, but it violates
the framework's gate-truth rule. The bounded fix below is
proportionate: four small product branches and extensions to two existing results; no new file
format, dependency, abstraction, test file, or `It`.

## Contract

`template-checks.ps1` and `.sh` use one fixed protocol:

- `0` — verification completed and found no issue.
- `3` — verification completed and found one or more artifact findings. The exact count remains in
  the human-readable `N framework check(s) FAILED.` summary.
- `2` — the checker explicitly could not examine required input.
- any other nonzero status — abnormal or undocumented termination; it is not drift evidence.

The checker resource branch emits the same ASCII diagnostic in both twins:

`CANT-VERIFY: template-checks could not inspect CHANGELOG.md; changelog headings remain UNKNOWN. Fix the host/resource read problem and rerun.`

`framework-doctor.ps1` and `.sh` map `0` to `OK`, only `3` to `MISSING`, and every other nonzero
status to `CANT-VERIFY`. Status `3` says only that template-checks reported integrity findings and
tells the user to run it directly and follow its exact findings; it does not guess which artifact or
recommend `/generate-copilot`. Status `2` says generically that the checker did not complete, names
its exit, and leaves integrity unknown because Bash itself can also use `2` for parse/usage failure.
Bash retains its more specific `126`/`127` launch explanation. A missing checker file remains a
verified `MISSING` artifact. `CANT-VERIFY` does not increment the doctor's missing count or make its
process fail.

PowerShell captures `$LASTEXITCODE` immediately inside the existing guarded child invocation;
launch failure or a null status remains `CANT-VERIFY`. Bash preserves the existing bare-`bash`
invocation and combined-output capture, then captures `$?` immediately. This deliberately preserves
the current truthful `127` launch failure when `PATH` cannot resolve Bash instead of entering a
utility-dependent checker under that damaged `PATH`. Both remain PowerShell 5.1 and Bash 3.2
compatible.

## Existing-result verification

No result is added.

1. Extend `ScriptTwinParity.Tests.ps1`'s existing clean/planted-drift result. Pair its `9.9.9`
   version mutation with an independently missing `.github/copilot-instructions.md` to construct
   exactly two findings; require the preserved `2 framework check(s) FAILED.` summary and fixed
   exit `3` from both twins. In the same result, mutate disposable checker copies through asserted
   unique anchors that change only the real CHANGELOG input operand to an asserted absent path;
   require exit `2` and the exact shared diagnostic. Do not synthesize the status.
2. Keep `FrameworkDoctor.Tests.ps1`'s existing mirror-pass result. Expand its existing
   mirror-failure result into a stub-status matrix: `3 -> MISSING`, `2 -> CANT-VERIFY`, and
   representative abnormal `1 -> CANT-VERIFY`. Twin comparison already proves summary counts and
   process exit from the row states; all three non-clean details must omit `/generate-copilot`, and
   status `3` must use the generic direct-checker remediation.
3. Before product editing, both strengthened results must fail against the unchanged scripts, but
   the outer diagnostic command must exit `0` after proving the expected red so a deliberate
   negative control cannot trip the workspace safeguard.
4. After implementation, apply four temporary mutations independently: restore numeric finding
   exit; map doctor status `2` to `MISSING`; map doctor status `3` to `CANT-VERIFY`; and restore the
   old resource diagnostic. Each existing result must reject its mutation; restore exact bytes and
   rerun clean.

Run the focused source suites under PowerShell 7 and native Windows PowerShell 5.1, including a
hostile code page. Compose all three distributions with both composers; prove generated freshness,
run both validator twins for all distributions, and rerun the focused composed suites. Parse all
PowerShell/Bash files and verify BOMs. Native Bash 3.2 and first Windows/Linux candidate CI remain
required release evidence; local Git Bash is not a substitute.

## Compatibility and rejected approaches

Repository callers were inspected and consume only zero/nonzero, so their behavior is preserved.
An external caller that interpreted the old numeric exit as a finding count must instead read the
unchanged printed count; the consumer changelog will state this explicitly.

Rejected: parsing a textual marker in the doctor (encoding, stream, and spoofing surface); reserving
a high status while retaining an unbounded count (future collision); using status `1` for findings
(ordinary shell/PowerShell failures commonly use it); a sidecar file (new cleanup/resource failure
surface); a new suite, result, or general checker exception taxonomy.

## Candidate evidence

With only the two existing results changed, the corrected two-finding world failed 9/1 on the
unchanged checker (`2`, expected fixed `3`) and the unchanged doctor failed 32/1 by retaining guessed
remediation. The candidate passed 10/0 and 33/0 under PowerShell 7. Four independent temporary
mutations were rejected: numeric finding exits (9/1), old resource diagnostics (9/1), doctor
`2 -> MISSING` (32/1), and doctor `3 -> CANT-VERIFY` (32/1); exact restoration returned 10/0 and
33/0. Native Windows PowerShell 5.1/code page 437 passed ScriptTwinParity 10/0. Its full doctor suite
ran the changed matrix green but remained 31/1/1 on an unrelated pre-existing Copilot-visibility
setup transport defect, now B-207; this candidate does not claim that full suite green.

PowerShell and Bash composers converged at 173/169/183 files with one identical 525-file SHA-256
manifest. Both validator twins passed all three distributions. The composed dotnet focused suites
passed 10/0 and 33/0, and all six source core files match their eighteen generated counterparts by
SHA-256. PowerShell parsing, Bash syntax, stack changelog parity, and generated BOM checks passed.
Native Linux and first exact-candidate Windows/Linux CI remain unavailable local evidence.

Two independent read-only reviews approved exact candidate
`22f7a08b79097068acde9664bc05ed5071b52139`, tree
`7630b2f9d7f763fc4e48a3b2ff64ce92a1aff5fe`, from sole design parent
`0ba2ed284336a238c67813cc891f88fc41be9a2e`. They reconfirmed the 34-path scope, unchanged
10/24 `It` cardinality, six-source/eighteen-generated blob parity, stack changelog parity, generic
remediation, and the fixed `0/3/2` boundary. Independent execution passed the source suites 10/0
and 33/0, a space-containing `0/3/2/4` plus missing-checker matrix, native Windows PowerShell 5.1
focused mappings, and a disposable `2 -> MISSING` mutation before exact restoration. Neither
reviewer found an actionable defect. Native POSIX/Bash 3.2 and exact-candidate provider CI remain
release evidence rather than locally claimed proof.
