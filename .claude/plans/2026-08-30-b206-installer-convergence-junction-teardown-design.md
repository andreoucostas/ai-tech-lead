# B-206 — InstallerConvergence junction teardown design

**Status:** IMPLEMENTED CANDIDATE · **Date:** 2026-08-30 · **Scope:** maintainer test only

## Value decision

Implement this item as a narrow P2/S repair. The existing reparse-retirement result protects a
distinct WSD-051 destructive boundary: successful update retirement/reconciliation must preserve a
consumer-modified path and must not follow a directory link into out-of-root bytes. The later
side-write reparse result tests pre-mutation refusal, so it is not a substitute. Deleting or
skipping this result would remove useful safety evidence.

The observed harm is current and deterministic, not a hypothetical cleanup nicety. In a headless
native Windows PowerShell 5.1 run the unchanged six-case/twelve-result file returns 10/2: only this
result fails for its two installer twins, `Remove-Item -Force` enters `PromptForChoice`, the host
throws `NullReferenceException`, the product verdict is masked, and two target plus two outside
roots remain. `$ConfirmPreference='None'` and `-Confirm:$false` do not repair it. Combined
disposable probes, including primary-agent two-argument runs under PowerShell 7 and Windows
PowerShell 5.1, show that the non-recursive `[IO.Directory]::Delete` primitive removes only the
populated junction and preserves the outside sentinel.

## Locked implementation

Change only the existing `consumer-modified and reparse retirement paths survive while verified
bytes converge` body in `.claude/hooks/tests/InstallerConvergence.Tests.ps1`.

1. Capture the body `ErrorRecord` so teardown cannot replace the installer assertion that failed.
2. Before teardown, make the result explicitly prove that the installer left the expected exact
   path present as a reparse/link entry. This makes the titled preservation contract observable and
   proves the unlink path is exercised.
3. During cleanup, reread that exact entry. On Windows, unlink the verified junction with guarded
   `[IO.Directory]::Delete($linkItem.FullName, $false)`; on POSIX, retain the existing non-recursive
   `Remove-Item -Force -ErrorAction Stop` symlink unlink. Do not use recursive link deletion.
4. Prove the link is absent and the outside fingerprint is still unchanged before recursively
   deleting either exact generated root. If a present entry is not a link or unlink absence cannot
   be proved, report cleanup failure and do not recurse the target or delete the outside tree.
5. Remove only the two exact generated roots with terminating operations and verify both are absent.
   Capture cleanup failure independently. Report body-only or cleanup-only failure unchanged in
   substance; on dual failure, throw one explicit message containing both exception messages because
   the tiny harness retains only the outer `Exception.Message`.

Keep six syntactic `It` blocks and twelve runtime results. Preserve the PowerShell BOM. Add no
suite, `It`, retry policy, stale-root sweeper, shared cleanup framework, product/source/dist change,
or prose-search assertion. Do not reuse B-204's remover: that helper deliberately rejects reparse
children and solves a broader root-tree lifecycle.

## Adversarial review and proportionality

Two independent reviews returned IMPLEMENT only with the failure-preservation and verified-absence
amendments above. Both rejected a one-line unlink substitution because the remaining
`SilentlyContinue` root removals could still false-green leaked state and `finally` could still mask
a body failure. They also rejected prompt configuration, `cmd rmdir`, recursive link removal, a
general cleanup abstraction, and deleting the result. The chosen inline lifecycle is the smallest
change that fixes the observed provider failure while making the existing result's teardown verdict
honest.

One reviewer reproduced the full native 5.1 shape in an isolated TEMP: 10/2 and exactly four leaked
roots. Across the two reviews and primary-agent probes, the non-recursive `.NET` unlink preserved a
nonempty outside sentinel under PowerShell 7 and Windows PowerShell 5.1. No reviewer had a native
POSIX host; Git Bash is not a substitute.

## Acceptance boundary

- Preserve the current native Windows PowerShell 5.1 10/2 plus residue observation as the old-red
  oracle; do not turn it into a permanent new case.
- Candidate file passes 12/0 under PowerShell 7 and isolated native Windows PowerShell 5.1/CP437,
  with no generated fixture entries remaining after either run.
- A disposable dual-failure mutation makes the existing result report both a unique body sentinel
  and a unique cleanup sentinel; restore the file byte-identically and rerun clean.
- Retain six syntactic `It` blocks / twelve runtime results, UTF-8 BOM, zero AST errors, and a clean
  diff check. Run the focused record gates for the plan/backlog evidence.
- Native Linux CI must execute the unchanged POSIX symlink unlink and pass the same result before
  B-206 can complete. Local Windows evidence creates only an implemented candidate.

No push, tag, release, or B-198 scope expansion is authorized by this plan.

## Candidate evidence (2026-08-30)

The existing result now captures body and cleanup `ErrorRecord`s independently, proves the
post-installer path is still a reparse/link, uses the non-recursive `.NET` unlink only on Windows,
retains the POSIX `Remove-Item` unlink, rechecks exact link absence and outside bytes before root
recursion, and makes both exact-root removals terminating with absent postconditions. A direct
`Get-Item` miss is reconciled through non-recursive parent enumeration and ordinal leaf matching;
access failure or ambiguity propagates instead of becoming false absence. Six syntactic
`It` blocks and twelve runtime results remain unchanged; no product, source, dist, suite, retry, or
shared cleanup framework changed.

The focused file passed 12/0 under PowerShell 7 and an isolated native Windows PowerShell
5.1/CP437 host, replacing the preserved 5.1 old-red observation of 10/2. Neither candidate run left
an `installer-convergence-*`, `installer-outside-*`, or `installer-history-*` entry dated today;
41 older convergence roots and one older history root predate this work and remain untouched. A
temporary mutation thrown only after the normal body assertions and after successful cleanup made
the two twin results fail 10/2, with each outer message containing both `BODY_SENTINEL_B206` and
`CLEANUP_SENTINEL_B206`. Reversing those two lines restored exact SHA-256
`9043008F28577221DE69159B76719216B5933BA867ECA1555DB4F459176CEA6A` and Git blob
`1ee8331e56851b4c105b110d97b629820a71c564`; the restored file then passed 12/0 again.

The first implementation review rejected treating a direct provider `ItemNotFoundException` as
proof of absence. The corrected reader now reconciles that result against exact parent enumeration;
both independent reviewers approved the amended blob. One reran that exact file 12/0 under isolated
Windows PowerShell 5.1 with zero residue and AST-executed the actual result under missing-link,
non-link replacement, and outside-byte mutation worlds. The hostile worlds either cleaned only
after proven absence or retained both roots/sentinel and surfaced both failure causes.

The same-class census found one other generated junction cleanup in this file's side-write result.
It targets an invariantly empty outside directory, passed in the exact native 5.1 10/2 baseline and
all candidate runs, and has no observed masked verdict or residue; widening B-206 to it would be
mechanism-driven scope without consequence evidence.

## Immutable review (2026-08-30)

A detached no-hardlinks review approved exact candidate
`aa374fdd7c17f641021adc58b1db00609fe1efb1`, tree
`e573c69d3e30c4e2f94493f4367c7d5cd2ca6fd8`, from sole design parent
`bf1bd24788fb70973a4c601a3010548ff787688e`. Native Windows PowerShell 5.1/CP437 independently
reproduced the parent at 10/2 with exactly four residues, then ran the candidate at 12/0 with an
empty isolated temp directory. PowerShell 7/Git Bash also passed 12/0 with no residue. Six syntactic
`It` blocks/twelve results, the recorded blob/SHA, BOM, AST, exact five-file scope, and record gates
were reconfirmed.

The dual-failure mutation produced 10/2 with both body and cleanup sentinels in both twin messages
before exact-byte restoration. Hostile non-link replacement, ambiguous exact-parent enumeration,
access failure, and outside-byte mutation each failed the targeted twin and retained both roots;
none authorized recursion. Normal cleanup exercised the direct-miss fallback after unlink, while
only `ItemNotFoundException` could enter non-recursive parent enumeration and ordinal leaf matching.
All review mutations, isolated clones, and generated review roots were removed safely.

No native POSIX/Linux, CI, push, tag, or release evidence exists. B-206 therefore remains an
implemented candidate until the unchanged POSIX symlink branch and exact candidate pass required CI.
