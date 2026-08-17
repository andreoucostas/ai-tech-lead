# Backlog cleanup report — 2026-08-17

## Preservation result

- Before: `meta/BACKLOG.md` was 6,878 lines.
- After: `meta/BACKLOG.md` is 3,350 lines and `meta/BACKLOG-DONE.md` is 3,538 lines.
- The pre-change file contained 106 `### B-` heading occurrences representing 104 unique heading
  ids. The two post-change files contain the same 106 occurrences and the same 104-id set: no ids
  added and no ids lost.
- The complete former `## Done` payload occurs byte-for-byte in `meta/BACKLOG-DONE.md`.
- All 48 records removed from the open sections occur byte-for-byte in
  `meta/BACKLOG-DONE.md`. This includes the 21 records that already had a separate archive summary;
  retaining their original open-record text was necessary because those summaries were not
  byte-identical duplicates. No entry text was lost.
- The only intentional edits within surviving open text were the requested Done-pointer retargets
  and the added B-129 blocked-state paragraph.

## Archived records

The following 21 finished open records already had a separately headed archive record. They were
removed from the open tracker; their original text was also preserved in the archive because the
existing archive record was not byte-identical:

`B-33`, `B-61`, `B-62`, `B-65`, `B-67`, `B-71`, `B-74`, `B-80`, `B-81`, `B-86`, `B-88`,
`B-89`, `B-95`, `B-106`, `B-108`, `B-109`, `B-114`, `B-122`, `B-124`, `B-137`, `B-139`.

The following 27 finished records had no separately headed archive record and were moved there in
full:

`B-21`, `B-29`, `B-56`, `B-58`, `B-60`, `B-63`, `B-78`, `B-82`, `B-90`, `B-93`, `B-103`,
`B-104`, `B-105`, `B-107`, `B-110`, `B-113`, `B-115`, `B-116`, `B-118`, `B-119`, `B-120`,
`B-121`, `B-125`, `B-126`, `B-127`, `B-128`, `B-145`.

The classification reason in every case was an explicit finished marker in the heading: DONE,
CLOSED, ABSORBED, REJECTED, or a Done-archive pointer. No unmarked entry was reclassified.

## Conservatively left open

The audit's uncertain records left open were `B-50`, `B-64`, `B-66`, `B-70`, `B-72`, `B-96`,
`B-97`, `B-98`, `B-101`, `B-102`, `B-112`, and `B-117`. B-65 was the one audit-unclear record not
left open: its current heading and archive record explicitly close it in v0.56.0.

In addition, `B-46` stays open because version awareness is explicitly still open. `B-66` stays
open despite DONE in its heading because its body explicitly says PARTIALLY DONE and preserves the
forms-guidance half. The explicitly protected `B-97`, `B-98`, `B-101`, `B-102`, `B-112`, and
`B-117` were not touched. No other entry was left open because of classification uncertainty.

## B-129 and standing decisions

The external `CLAUDE-HANDOFF.md` was readable. B-129 now states directly that the harness is built,
the 2026-08-15 and 2026-08-16 live runs were voided by the account monthly spend limit, and work is
blocked on reset or an increased limit. The external file was not edited.

`meta/decisions-index.md` contains 21 one-line standing-constraint citations. It includes the B-98
constraint “Reuse the B-41 harness; do not build a second one,” the v0.51.0 no-router decision,
WSD-043's committed-team-settings decision, and WSD-005's PowerShell-only meta-script decision.

## Gate evidence

Clean results:

- `BacklogHygiene.Tests.ps1` under PowerShell 7: 4 passed, 0 failed, 0 skipped; exit 0.
- `BacklogHygiene.Tests.ps1` under Windows PowerShell 5.1: 4 passed, 0 failed, 0 skipped; exit 0.
- `DocTruth.Tests.ps1`: 8 passed, 0 failed, 0 skipped; exit 0.
- The new PowerShell file has a UTF-8 BOM.

Red observations, each exit 1:

- Finished heading: `finished marker remains in open heading B-900: Example — **DONE**`
- Dangling archive pointer: `archive pointer names missing id B-999`
- Broken indexed phrase: `quoted phrase not found near meta/BACKLOG.md:1 -- missing phrase`
- Zero headings: `BACKLOG.md yielded zero open headings -- heading check is vacuous`
- Zero pointers: `BACKLOG.md yielded zero archive pointers -- pointer check is vacuous`
- Zero index entries: `decisions-index.md yielded zero index entries -- citation check is vacuous`

The PARTIALLY DONE allowance has its own passing fixture. Nothing required by the red-test brief
was unable to be shown failing.

No file under `src/` or `dist/` changed. Nothing was staged or committed.
