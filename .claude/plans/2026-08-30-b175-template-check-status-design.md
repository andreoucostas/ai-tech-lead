# B-175 · Template-check status contract — locked design

**Status: COMPLETE 2026-08-30 — exact supported-host run `33333912064` at
`dbdc38f508463c3c2fa7cb3d55d830deb7cd014b` green; planned v0.79.0.** Final
local preflight rejected the first checker/doctor candidate's docs-sync wrapper compatibility, and
immutable review later rejected wrapper candidate `d3e19c5c24b8f8e3e789191bf873bcde5413f252`
under Bash errexit. The approved checker/doctor core remains intact.

Any pending-CI statements below preserve the chronology before the final supported-host run.

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
the framework's gate-truth rule. The bounded fix below is proportionate: six small product branches,
extensions to two existing results, and reuse of one existing wrapper-contract result; no new file
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
PowerShell/Bash files and verify BOMs. First Windows/Linux candidate CI remains required release
evidence; local Git Bash is not a substitute for native Linux.

## Compatibility and rejected approaches

Validators, CI, and the consumer branch of docs-sync consume only zero/nonzero. Final local preflight
disproved the broader original census claim: the template-repo docs-sync branch republishes its
child status through a script whose documented public contract is `0` pass / `1` fail. Normalize
that one delegation boundary to `0/1` after preserving the child's output. An external caller that
invokes template-checks directly and interpreted the old numeric exit as a finding count must
instead read the unchanged printed count. A template-repo docs-sync caller that relied on the
undocumented, contract-inconsistent child-status pass-through will now receive documented wrapper
status `1` instead of child
`2` or `3`; the consumer changelog will state both compatibility boundaries explicitly.

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
reviewer found an actionable defect. Native Linux and exact-candidate Windows/Linux CI remain
release evidence rather than locally claimed proof.

## Final-preflight correction and bounded amendment

The first full-root preflight after immutable review finished with one attributed failure across 31
meta files: `DocsSyncCheck.Tests.ps1` rejected both wrapper twins (`0/2`) because the planted
template-repo drift returned the checker's new status `3`, not the wrappers' required public failure
status `1`. This is a real compatibility gap, not a stale test: both shipped docs-sync headers say
`Exit 0 = pass, 1 = fail`, the existing B-149 mutation result predates B-175 and intentionally
asserts `1`, and the consumer path already normalizes checker nonzero to its own final `1`.

Amend only the `.template-repo` branch in `docs-sync-check.ps1` and `.sh`: run the existing checker
unchanged, preserve its stdout/stderr, capture its status immediately, return `0` only for child `0`,
and return `1` for every child nonzero. The Bash child invocation must be inside an errexit-safe
conditional so `bash -e` and inherited exported `SHELLOPTS` cannot terminate before normalization.
Do not parse output, distinguish `2` from `3` at this wrapper, change the ordinary consumer branch,
change checker/doctor behavior, or add a result. Strengthen only the existing B-149 Bash arm to use
`bash -e` for its same planted-drift invocation; keep its PowerShell arm, mutation, expected status,
fixture, result, and execution cardinality unchanged. The already-captured 0/2 preflight is the
original red; after implementation require that exact existing result 2/0, ScriptTwinParity 10/0,
the full meta suite green, both composers and all generated copies converged, and the normal
distribution/provider gates. Because ScriptTwinParity proves only clean-world twin equality rather
than the documented numeric success status, also run one disposable clean marked-template probe
that requires exact wrapper exit `0` from both twins.

Two independent read-only amendment reviews approved this scope. The transport review required an
explicit disclosure that callers relying on the wrapper's exact child status will observe a change.
The value review corrected unsupported “accidental” language to “undocumented,
contract-inconsistent” and required the disposable exact-`0` clean probe above. Both rejected a new
permanent test or weakening the existing B-149 wrapper contract.

Immutable implementation review supplied new evidence and narrowly supersedes only the decision to
leave B-149 byte-unchanged. Candidate `d3e19c5c24b8f8e3e789191bf873bcde5413f252`
passed ordinary invocation but leaked checker status `3` when launched with `bash -e`: the shell
exited on the child simple command before `$?` capture. Corrected product candidate
`ae5d0c0522f34e1967805b9d27a5d5e2920423df` puts the child in an errexit-safe conditional and
passed normal, `bash -e`, and inherited-`SHELLOPTS` clean/finding probes with child streams intact.
Both implementation reviewers approved that product and independently judged a one-argument
strengthening of B-149's existing Bash invocation high-value: it is red on `d3e19c5`, green on
`ae5d0c0`, and adds no test, `It`, result, fixture, or additional execution pass. Exact final-
candidate Windows/Linux CI remains release evidence.

## Final immutable candidate and evidence

Two independent read-only reviews approved exact candidate
`b36c6e99b61daf099ba227e8a566a342f5efd625`, tree
`6bb2fdbb895164373ccbd18e6f0dd03806c95c77`, over the full corrective range from initial
wrapper-design base `581ee3da8fb1bac336a2142378592ee3635e17fb`, with no actionable finding.
The exact 19-path range is
14 product/consumer-changelog paths, four locked record paths, and one existing maintainer result;
the final commit changes only B-149's Bash argument list from `@($script)` to
`@('-e',$script)`. No test, `It`, result, fixture, invocation, or backlog item was added.

Reviewers `b175_impl_transport` and `b175_impl_value` were separate read-only Codex subagents that
did not implement or edit the candidate. Both inherited the primary session's model with no
override; the exact backend model identifier is not exposed. Both used this same Windows workspace
with PowerShell 7,
Windows PowerShell 5.1, and Git Bash 5.2, so their model/host correlation is explicit rather than
mistaken for an orthogonal provider vantage. The hostile cases, clean reruns, and remaining native
Linux/provider gap below bound that correlation.

The exact candidate passed B-149 2/0 under PowerShell 7 and native Windows PowerShell 5.1, including
the Bash `-e` arm and byte-identical scratch restoration. Normal, caller-`-e`, and inherited exported
`SHELLOPTS` probes mapped clean to `0` and finding/inability/abnormal/missing-child worlds to `1`
while retaining child stdout/stderr. Both composers produced the same binary diff; both validator
twins passed all three distributions; source/generated script and changelog blobs converge; syntax,
BOM, and both context-footprint twins are green. The full root meta suite passed with zero failures
across all 31 files on the exact final candidate. Exact-candidate Windows/Linux CI remains required
release evidence rather than locally claimed proof. B-209/WSD-064 subsequently withdrew stock
Bash 3.2 and macOS/BSD-provider behavior from the supported and tested host contract; earlier
Bash-3.2 gap statements above are preserved as historical review bounds, not active release gates.
