# Framework field study results

Balanced study evidence from the protocol in `meta/field-study-kit.md`.

This ledger is deliberately separate from `meta/field-reports.md`:

- `field-reports.md` is improvement-only issue intake and is expected to skew negative;
- this file records every executed study outcome: benefit, harm, mixed, no detectable difference,
  or void.

Raw repositories, prompts, transcripts, diffs, command output, client vocabulary, and identifying
details never belong here. Each entry is copied from the sanitised summary in
`meta/field-study-response-template.md`. Missing values remain `not captured`.

## Aggregation rules

1. Keep `maintainer` and `independent` results separate.
2. Never count an anecdotal positive comment as an executed study result. It may be recorded in the
   response wrap-up only when attached to an executed protocol.
3. Never average away task acceptability, a safety failure, or a void arm.
4. Publish raw counts and directions before any total or average.
5. Do not make a team-value claim from maintainer runs alone.
6. Before three complete independent replays exist, describe each result individually. At three or
   more, aggregate descriptively; do not imply statistical significance.
7. A protocol failure is a result: record it and fix the packet before inviting another participant.

## Runs

## FS-20260826-DRY-01 — 2026-08-26 — maintainer

Profile: .NET; brownfield codebase receiving its first framework install; 200–499 source files;
Claude Code 2.1.241/Claude Sonnet 5; framework v0.77.0.

Onboarding: completed; installer 0.04 minutes, total participant time not captured (artifact writes
spanned 12.4 minutes); one required developer initiation; primary friction: the packet prescribed
`/adopt`, while the installed lifecycle selected `/bootstrap`.

Replay: completed but void; direction void. Raw non-causal measures: acceptability F/B `2/2`;
rubric F/B `9/6`; wall minutes F/B `6.43/1.23`; active minutes F/B `<1/<1`; interventions F/B
`1/0`. Both final diffs passed the same private acceptance probe; applicable suites passed `45/45`
and `44/44`. A broader baseline suite had one unrelated pre-existing failure, retained as a
limitation.

Observed mechanisms: helped—the installer enforced its human handoff; bootstrap wrote a precise
debt diagnosis; the fix rail produced and demonstrated a red regression test; both arms made
acceptable fixes. Harmed/noisy—the FRAMEWORK arm required a restore approval and its Debug test
execution hit an Application Control failure, which it reported honestly; its independent Release
suite was green. Not observable—review agents and team-review effects.

The raw rubric threshold would have labelled the run `benefit`, driven by FRAMEWORK test discipline.
That label is invalid: both arms retained a latest planted mutation commit whose parent and diff
revealed the solution; BARE explicitly read it. FRAMEWORK also read the exact diagnosis generated
during bootstrap, which is a real treatment mechanism but prevents narrower attribution. The frozen
R2 checks also duplicated test behavior already scored by R3, amplifying the raw delta.

Live diary: 0/3 tasks; not run. Keep installed: not captured. Confidence: high for mechanism reach
and the protocol defects, none for comparative value. Limitation: solution-bearing history made the
fixture ineligible. Follow-up: use neutral history-free arm snapshots, require R2 checks independent
of R3/R5, retain setup-discovery disclosure, then rerun before inviting an independent participant.

## FS-20260826-RERUN-02 — 2026-08-26 — maintainer

Profile: .NET; brownfield codebase receiving its first framework install; 200–499 source files;
Claude Code 2.1.246/Claude Sonnet 5; framework v0.77.0.

Onboarding: completed after repair; installer 0.04 minutes, bootstrap transcript 23.9 minutes, 11
developer follow-ups after the initial command; primary friction: Opus usage was unavailable so
setup ran on Sonnet, then bootstrap claimed completion while deterministic docs sync rejected
generated hazard and mirror content. A Sonnet mirror-repair session still left one stale line; the
exact final mirror correction was manual. Setup cost and time are excluded from both task arms.

Replay: valid; direction no detectable difference. Raw measures: acceptability F/B `2/2`; rubric
F/B `10/9`; wall minutes F/B `2.62/1.14`; active minutes F/B `<1/<1`; interventions F/B
`0/0`; agent cost F/B `$0.312/$0.162` (descriptive, not a material threshold). Both arms
produced byte-identical source and regression-test files, and independent applicable suites passed
`45/45` in each.

Observed mechanisms: helped—the FRAMEWORK arm wrote and demonstrated its regression test red before
the fix, ran broader verification, stated the unrelated host failure accurately, and its route,
session, and audit hooks were observable. No visible comparative effect—BARE independently produced
the same acceptable fix and regression test. Harmed/noisy—FRAMEWORK took 1.48 more wall minutes and
retried a broader suite blocked by Windows Application Control; this cost no participant
intervention and is not a material primary difference.

The FRAMEWORK `+1/10` rubric delta is below the frozen `2/10` threshold; acceptability, active
participant time, and intervention counts are tied. The private verifier passed in FRAMEWORK; the
BARE verifier is inconclusive because Application Control blocked the rebuilt test assembly while
`dotnet test` exited zero and reported no matching test. BARE's equivalent task test, independent
`45/45` suite, and byte-identical outcome support acceptability without calling that probe green.

Live diary: 0/3 tasks; not run. Keep installed: not captured. Confidence: high for outcome
equivalence and scoring, medium for direction because this is one stochastic maintainer replay.
Limitation: one small task, maintainer source, Sonnet setup forced by usage limits, and one
post-outcome verifier blocked on the BARE path. Follow-up: B-177 for setup completion that outran its
deterministic checks; then one independent Module A pilot.
