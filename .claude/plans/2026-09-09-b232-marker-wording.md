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

## Implementation review and native verification

Frozen implementation range:
`53e8e43adaf88cb89e97d15a07f31f481ac2a330..8bf3fa9ca174702c09be7918b7b493f052bf32d7`.
Authored diff SHA-256: `E444582F8348875E72AA22F7D7533132ED312060B6824FB89030C0C997893524`.
Root checked Git's complete range: three source sentences, four changelog heads,
their generated distributions and this plan. Exact reverse replacement reproduced
every original workflow byte, including encoding and line endings; no helper,
guard, test or other workflow section changed.

Fresh Claude CLI 2.1.260 / `claude-opus-5`, high effort, safe/restricted Read-only
session `c342eca3-a7d9-46aa-8afd-46fa3ff16146` returned ACCEPT without blockers;
result subtype success, reported list-price cost USD 0.8397225. No implementation
participation. Root inspected the session's actual ordered text/tool events:
contract read, independent threat model, baseline reads, diff/final reads, verdict.
The reviewer did not read the design verdict or implementer narrative. Its source
analysis rejected the old no-copy restore and accepted the corrected retention,
post-removal restore and unchanged completion branches. Readable review SHA-256:
`F948391D55D0C4429E1AD0AEC0AA79DCC80409F33282455A70818FF1ACD06345`.

Root then observed direct PS7 7.6.5 and PS5.1 5.1.26100.9278 at CP437:
`AdoptionArchiveIntegrity.Tests.ps1` 34/0 and `InstallerContract.Tests.ps1` 8/0
on each host, all four suite exits 0. Installer coverage includes greenfield and
brownfield for all three distributions. Both hosts observed actual bare-array
Freeze exit 3 with unchanged source/marker and no destination for each stack,
then valid original examples; the digest-comparison mutation remained detected.
Installer's intentional removed-contract-line run failed 6/1, followed by the
restored outer suite's 8/0. These are existing mechanical controls, not an
automated detector of the corrected prose or a model-comprehension claim.

Retained receipt SHA-256:
- `final-ps7.log`: `9635C80713BA6F11416FBE549818420B83F1D634F70C56E17D0CD2081EB24229`.
- `final-ps51.log`: `148C3AF03F963B0D6F65D45F66917FADF344BB1FDA917B62199796E4106DE494`.

Reviewer executed no tests, could not independently verify Git completeness and
spot-read final contexts rather than comparing raw bytes. Those checks above are
root-observed. No adoption/model outcome was run. Normal release stamping,
aggregate gates and eight-context CI are subsequent promotion obligations; their
results belong to the release record and CI, not this frozen source verdict.
