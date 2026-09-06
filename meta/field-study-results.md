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
8. Preserve each protocol series. FS1 ends with FS-20260826-RERUN-02; FS2 begins prospectively on
   2026-08-29. Never rescore or aggregate outcomes across those measurement contracts.
9. CP1 is the maintainer ABP / Copilot CLI campaign derived from FS2 with a different setup route.
   Keep CP1 separate from FS1, FS2 and RK1. Preparation is not a task outcome.

## CP1 preparation — 2026-09-06 — maintainer — NOT READY

The user authorized implementation of the reviewed
[CP1 contract](../.claude/plans/2026-09-06-cp1-abp-copilot-campaign.md). The
[critique provenance](../.claude/plans/2026-09-06-cp1-abp-copilot-critique.md) records the handoff's
reported ACCEPT WITH CONDITIONS; it is not a new acceptance review. No purchase, Copilot setup,
task arm, diagnostic, or RK1 live run was performed. There is no comparative outcome to classify.

**Observed preparation.** The authoring tree started clean at `87521cdf...`; the requested framework
release resolves to `a3986c207fe336abc5967652a021625c2a17ed75`. ABP's selection anchor resolves to
`58d7243319c2b399944357edf51583135df10f1f`, committed 2026-07-27 08:13:41 UTC. Its `git ls-tree -r`
inventory has 22,227 tracked files, 671 .NET project files and 18 native `.claude/skills/*/SKILL.md`
files, with no `.github/skills/` paths. These are whole-tree counts, not first-party code or executed
tests. `global.json` requests SDK 10.0.100 with `latestFeature`; root NuGet configuration lists
nuget.org. Its CI invokes repository PowerShell build/test scripts on Ubuntu; this is not evidence
that the CP1 native Windows application slice runs.

The first-parent window is frozen at **2026-04-28 08:13:41 through 2026-07-27 08:13:41 UTC**,
inclusive. It contains 238 integrations, including direct accepted first-parent commits. Only the
first 100 were inventoried. Initial screening records 84 exclusions and 16 unresolved candidates;
the latter include unconfirmed authorship/size, task coherence and independent-decision evidence.
**No candidate was certified eligible, and no pre-change snapshot was selected.** This is not a
finding that no eligible ABP change exists. Raw candidate identities, paths, reasons and source
inspection remain in external coordinator storage; no later candidate was inspected.

**Readiness obstacle.** Native host probes found Windows 11 Pro, PS7 7.6.5, only .NET SDK 8.0.424,
about 16 GB installed RAM, about 4 GB free RAM and about 344 GiB free disk. The process is not
elevated. No Hyper-V/VMware/VirtualBox service was returned; known Hyper-V/Sandbox executable paths
were absent. Both optional-feature probes required elevation, so feature state is **cannot
examine**, not “disabled.” Hypervisor presence alone does not establish a usable guest. No guest
or Windows installation image was supplied; the 8 GB / 100 GB guest, its performance and its
filesystem/network isolation could not be established. No host configuration or reboot occurred.

The v0.84.0 Copilot adoption wrapper and canonical headless workflow were read: the documented
`copilot -p` route stages proposals for human application and runs embedded bootstrap; legacy
`.github/skills` discovery preserves its early stop and marker. This is source evidence only.
Installer dry run at a selected snapshot, actual host routing, developer initiation, human adoption
completion, allowed-path inspection, marker lifecycle, docs sync and application baselines remain
**NOT RUN**. Pricing documentation advertises $39 / 7,000 included credits; the user's actual
billed total, allowance, overage setting and reset date were not examined. Purchase remains pending
readiness and account-specific confirmation.

**Remaining evidence.** Concrete private task/response cards, D1–D3, supported alternatives,
severe-error definitions, valid/targeted-invalid execution and independent review; eight hidden
facts; calibrated route/read/usage observers; sealed arms and tested egress controls; both task
scores; assertion audit; all four diagnostics; and RK1's four held-out task cards and matched
immutable variants. VS Code, other-stack operations, independent FS2 and complexity/payback claims
remain unexercised. No application acceptance or knowledge efficacy is inferred from this stop.

**Budget / resumption.** Charge **one hour conservatively** to the eight-active-hour preparation cap
for this session, including automated work and record preparation; this is an accounting charge,
not a measured human-effort outcome. Seven hours remain. The 100-integration inventory is retained;
do not restart the count or inspect candidate 101 under this contract. Resolve the guest obstacle
and the unresolved candidates within the existing population/caps before any purchase. Changing
the candidate limit, task criteria, guest requirement or protocol requires renewed review.

Source links for host provisioning and advertised pricing are retained in WSD-076. The external
coordinator handoff holds provisioning steps, raw evidence and the cumulative selection ledger;
it is not an isolated setup/task workspace. B-42 and B-216/B-222–B-225 remain open.

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
