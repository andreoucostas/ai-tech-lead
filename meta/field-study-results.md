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
Offline guest/application/oracle readiness and the supported setup route precede purchase. Paid
host calibration and onboarding follow purchase and must pass before the task pair; they are not
unfunded pre-purchase requirements.

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

**Record verification.** Independent reviewer `/root/cp1_record_review` accepted immutable range
`87521cdf...a8aa59c` as a meta-only NOT READY record, with no blocking findings; concrete task/oracle
review remains outstanding. The critique file preserves scope, limitations and attributed hostile
evidence. Root ran `BacklogHygiene.Tests.ps1 -RedTest broken-index` (exit 1), then its clean run
(10 passed / 0 failed), plus `DocTruth.Tests.ps1` (13 passed / 0 failed), directly under PS7 and
native PS5.1; the latter used code page 437. The distribution bytes match the pinned release.
These checks verify authoring records, not application or Copilot outcomes.

### CP1 container follow-up — 2026-09-06 — RESTART REQUIRED / campaign NOT READY

The user proposed Docker as an alternative to manually provisioning a VM and authorized proceeding,
using Sol or lower models for appropriate work. WSD-077 prospectively permits assessment of a
Hyper-V-isolated Windows container. The [substitution contract](../.claude/plans/2026-09-06-cp1-windows-container-substitution.md)
and [independent critique](../.claude/plans/2026-09-06-cp1-windows-container-critique.md) preserve the
bounded acceptance, corrections and runtime gaps. The original preparation stop above is history.

**Observed host work.** Windows 11 Pro build 26200, PS7 7.6.5, approximately 16 GB total RAM,
3.84 GiB currently free RAM and 347 GiB free disk were observed before this attempt. Docker's
command, service and standard all-users binaries were absent. The official Docker Desktop 4.89.0
installer was downloaded; Authenticode reported Valid with Docker Inc as signer, and its file
version and SHA256 were retained externally. It was **not launched**.

Native UAC started the fixed feature helper at 09:04:44 UTC. Its 09:04:49 UTC record reports
`Microsoft-Hyper-V-All` and `Containers` Disabled before, Enabled after, `RestartRequired=true`,
and no error. The command used `-All -NoRestart`; no automatic restart or Docker installation
followed. The child process's final exit code was not captured; the feature JSON is the observed
completion evidence. The initial helper ran before its helper-specific review feedback arrived
and did not inventory dependency-feature changes. That delta is **not captured**, not inferred
from the two-root transition. A later full-state inspection cannot reconstruct the missing before.

Sol accepted a separate resume helper after full before/after snapshots, partial-failure capture
and bounded restart reporting were added. Root observed direct PS7/PS5.1 parse success and the
non-administrator exit 740; no elevated execution or recovery-path success is claimed for the
revised helper. It and the verified installer are retained in external coordinator storage with
an exact restart/resume handoff. A manual reboot and fresh state inspection are the next host steps.

**Prepared, not executed.** Official MCR metadata and the inspected SDK Dockerfile identify the
candidate Server Core image as .NET SDK 10.0.400, PowerShell 7.6.4 and MinGit 2.55.0.3; its manifest
digest is frozen externally. Node v24.20.0's downloaded Windows archive matched the official SHA256;
Copilot 1.0.83 package metadata was retained. No Docker image was built or started, no container
resource/performance/isolation probe ran, and neither container PowerShell host nor Copilot was
executed. Component metadata is not runtime compatibility evidence. The original application
snapshot selection, oracles and discovery sample remain pending; no additional candidate was read.

**Remaining boundary.** The offline smoke must use ContainerUser, explicit Hyper-V isolation,
`--network none` and no mounts. Paid setup separately requires a reviewed executable egress policy,
observed allowed/denied probes and disabled/probed server-side retrieval. The proposed L2Bridge/VFP
and external-proxy approach is unimplemented. There is no new setup, task, diagnostic, purchase or
Copilot-usage outcome, and no application or framework benefit/harm inference.

**Cumulative budget.** Charge one additional preparation hour conservatively for this follow-up,
including research, review, downloads, host work and records: **two of eight hours charged, six
remain**. This is an accounting charge, not measured human effort. One hour remains within the
container attempt's two-hour checkpoint. The existing first 100 candidates, 84 initial exclusions
and 16 unresolved entries are unchanged; candidate 101 remains out of scope.

**Record verification.** The external resume helper is BOM-encoded and parsed under both native
PowerShell hosts. Root observed `BacklogHygiene -RedTest broken-index` exit 1, then clean 10/0 and
`DocTruth` 13/0 directly under PS7 and native PS5.1 (code page 437). These verify authoring records,
not container runtime or CP1 readiness; the immutable push/CI result remains delivery evidence.

### CP1 offline container checkpoint — 2026-09-07 — toolchain observed / campaign NOT READY

Root inspected the retained post-restart records: the reviewed helper's inspection reported no
changes or pending restart signals, and Docker's native installer logged success at 07:13:49 UTC.
Current probes independently found Docker Desktop 4.89.0, engine 29.7.2, Windows backend and Hyper-V
isolation. The earlier missing dependency before-state remains missing; these later observations
do not reconstruct it.

The frozen SDK base digest from the preceding checkpoint pulled successfully. A fresh allowlisted
context contained only generic toolchain/smoke files and the verified Node/Copilot archives; no ABP
history, task answers, credentials or host profiles entered it. Claude Code 2.1.260 reported
`claude-sonnet-5` for the delegated review/authoring work. Root reviewed and corrected the files and
executed them; this is not a claim of independent review of the final helper implementation.
The final local image is
`sha256:ac3e5084afa2e65a4a3d8b8e61f10eaa7d1278635ea9d094e89270ea327d893e`.

**Observed runtime.** Separate fresh containers ran direct PS7 7.6.4 and native PS5.1
5.1.26100.33296 as ContainerUser (SID `S-1-5-93-2-2`). Inspect records show `hyperv`, network
`none`, zero mounts, memory setting 8,589,934,592 bytes and storage option `100G`. CIM reported
9,125,695,488 physical-memory bytes and logical disk size 107,238,891,520 bytes; these observations
do not establish a hard allocation ceiling or a full-capacity storage stress test. SDK 10.0.400,
Git 2.55.0.windows.3, Node v24.20.0 and Copilot CLI 1.0.83 version/help ran successfully. Copilot
automatic updates were disabled in the image; no prompt, authentication or model call ran in it.
Docker's future update policy and study model/worker routing remain to be frozen before comparison.

On **each host**, the generic arithmetic project built and executed three xUnit cases: baseline
3 passed / 0 failed, a compilable addition-to-subtraction mutation 1 passed / 2 failed with native
test exit 1, then restored source 3 passed / 0 failed with exit 0. The final smoke and evidence-copy
commands exited 0. Root separately counted the six TRX files' actual result nodes, inspected the
container configurations and compared copied-back production source hashes to the original bytes.
PS5.1 was invoked through the command selecting code page 437. This is generic offline toolchain
evidence, not ABP application acceptance, selective-egress certification or Copilot task efficacy.

**Retained failures.** An unsupported build-only storage flag exited 125; account-name ACL mapping
failed with native exit 1332 and build exit 1. Root measured the ContainerUser SID before replacing
the name-based grants. Early smoke attempts stopped on a read-only `PSEdition` assignment, root's
local shadow of the native exit-code variable, and a matcher rejecting Copilot's trailing sentence
period. The scope correction also passed explicit native-exit 7 and 0 controls on both authoring
hosts. These helper/observation failures are preserved alongside the successful runs and are not
classified as shipped framework defects. Raw logs, manifests, files and the resume packet remain
outside authoring Git.

**Next and budget.** Certify the first eligible retained ABP candidate in the frozen order, prepare
and independently review its concrete task/oracles, then execute its application baseline in the
chosen boundary. No additional candidate was inspected: 84 initial exclusions / 16 unresolved
remain, with no certified task. Selective egress, adoption/application readiness, account-specific
purchase confirmation and paid calibration remain outstanding; no Copilot study call or purchase
occurred. RK1 stays preparation-only, VS Code deferred and independent FS2 outstanding. Charge one
additional hour conservatively for today's earlier installation follow-up and this toolchain/
record work: **three of eight preparation hours charged, five remain**. This is an accounting
charge, not measured human effort. The container attempt's two-hour checkpoint is consumed;
additional container engineering requires a newly bounded review. No product version changes.

**Record verification.** Root observed `BacklogHygiene -RedTest broken-index` exit 1 on both
native authoring hosts, then clean BacklogHygiene 10/0 and DocTruth 13/0 on each; the PS5.1 clean
command reported active code page 437. `git diff --check` passed and source/distribution bytes
were unchanged. These checks verify the authoring record, not the remaining study outcomes.

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
