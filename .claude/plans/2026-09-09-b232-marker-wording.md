# B-232 marker overview correction

Status: LOCKED after Opus ACCEPT; implementation authorized by the user.
Baseline: `53e8e43adaf88cb89e97d15a07f31f481ac2a330` (v0.86.1).
Authority: the user requested Opus adversarial review followed by implementation.

## Contract and proportionality

The headless overview in each stack's `files/.claude/commands/adopt.md` says
either archive verification failure restores the marker. Phase 7 instead stops
with the existing marker present on pre-bootstrap failure; only after PASS does
it save the recovery copy and remove the marker. This is an observed source
inconsistency, not evidence of model execution failure or lost consumer data.

Change only that overview sentence in dotnet, angular and monorepo. Existing text:

> Headless carries the marker's `archiveIntegrity` evidence through this delete/restore exactly as interactive mode does, and runs the same Phase-7 pre-bootstrap and post-gate `adoption-archive.ps1 -Verify` checks; a `RESULT: FAIL` or `RESULT: CANT-VERIFY` from either restores the marker byte-for-byte and stops the run before any completion report or PR seed.

Proposed replacement:

> Headless carries the marker's `archiveIntegrity` evidence through this delete/restore exactly as interactive mode does, and runs the same Phase-7 pre-bootstrap and post-gate `adoption-archive.ps1 -Verify` checks. A `RESULT: FAIL` or `RESULT: CANT-VERIFY` before bootstrap leaves the existing marker present; after its removal, restore the marker byte-for-byte from `.claude/adoption-archive-recovery.json`. Either failure stops the run before any completion report or PR seed.

The smaller correction removes the contradiction without changing Phase 7,
helpers, guards, inventory, completion requirements or read-recovery guidance.
No new runner, persistent test or model-behavior experiment is warranted for
this bounded prose correction. Consider leaving the text alone versus aligning
the overview; changing lifecycle mechanics is disproportionate to the defect.

## Verification and delivery

Review the full headless and Phase-7 contexts in all three immutable source
files. Challenge pre-bootstrap failure with no recovery copy, post-removal
failure requiring the saved copy, non-PASS bootstrap, and successful completion.
The corrected summary must not imply that failure can proceed or that frozen
evidence may be regenerated. Compare all bytes outside the approved sentence
with the baseline; no unrelated source function may change.

Run the existing archive-integrity and installer contract suites directly on
PS7 and PS5.1 at CP437, retaining existing actual hostile/red and restored-clean
observations and matching nonzero case counts. These tests establish existing
mechanical contracts, not model comprehension. Independent implementation
review uses a frozen commit range and the contract before the implementation
narrative; record environment and unexecuted behavioral gaps explicitly.

Prepare v0.86.2 entries in all four changelogs, compose all three distributions,
and use the normal release script, local gates and required eight-context CI
before tagging. Record review, RCA and evidence in existing B-232 records;
B-232 stays partial because its separate read-recovery proposal is deferred.

## Design review and adjudication

Fresh Claude CLI 2.1.260 / `claude-opus-5`, high effort, Read-only safe/restricted
session `4a76e3e6-547a-460a-8261-c17bc6b77581` returned ACCEPT, no blockers;
result subtype success, reported list-price cost USD 0.6670275. Frozen proposed
contract SHA-256: `D85F6D9E8B5EF27424F07286B7BA84758B123ED6538C4A5C24F2CBCDB8985101`.
Packet: `C:/TEMP/b232-marker-wording-20260909/` (prompt, raw result and sources).

Reviewer stated a threat model before source inspection, then read all three
full workflows. Root rechecked the named pre-bootstrap no-copy hostile case
and post-removal restore branch against Phase 7. Accepted the optional indicative
wording: replace `after its removal, restore the marker` in the proposal above
with `after its removal, the marker is restored`. This is the locked candidate.
Declined redundant marker-path naming and expanding this verification summary
to enumerate the separate non-PASS bootstrap gate; Phase 7 already covers it.
The source sweep found the erroneous phrase in exactly the three named files.

Opus executed no tests and did not inspect Git or helpers. Its statement that
indicative wording cannot drift is not a guarantee; its broader assertion that
nothing here is testable by observing a model is not adopted. A model observation
could test adherence, but is unnecessary for this source consistency repair.
Existing parser/mechanical tests cannot detect this semantic contradiction:
the unfixed PS7 archive suite passed 34/0, including its actual negative controls.
The hostile lifecycle contrast is source-review evidence, not executed adoption.
