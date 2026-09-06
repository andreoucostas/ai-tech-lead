# Repository-knowledge component study — offline execution packet

**Series:** RK1. **Status:** offline protocol; no live run has been authorised or performed.
**Question:** on the same repository tasks, does the enhanced bounded discovery/capture/use
increment improve outcomes over the current released framework on the same observed Copilot host
and exact model?

**2026-09-06 prospective relationship:** the separately authorized
[CP1 campaign](../.claude/plans/2026-09-06-cp1-abp-copilot-campaign.md) compares native Copilot with
complete v0.84.0 first. RK1 remains preparation-only there: four held-out tasks across four areas,
independently reviewed immutable variants differing only in discovery/capture/use, and matching
unrelated repairs. Whole v0.83.0/v0.84.0 releases cannot isolate this treatment. Eight task runs,
potentially eight setups and calibration are not assumed to fit CP1's first subscription allowance.
CP1 stopped NOT READY before a task snapshot was selected; those four cards, variant review and
executable controls remain outstanding. See `meta/field-study-results.md`; never pool CP1 and RK1.

This is the B-225 component experiment, not FS2. FS2 compares the complete framework with a bare
agent and remains governed by `meta/field-study-kit.md`; never pool RK1 with FS1 or FS2. RK1 reuses
the field study's privacy, history-free snapshot, filesystem isolation and oracle-reachability
controls. It does not add a general eval harness. `.claude/evals/run-agent-evals.ps1` remains the
Claude-specific typed-evidence runner; do not call it a Copilot executor or alter its scenarios for
this protocol.

## Authority and stop boundary

This packet permits offline task-card preparation and synthetic control calibration only. Before a
live arm, obtain all of the following and record them below: an approved repository snapshot and
privacy boundary; independent task/domain oracle review; an installed Copilot CLI or VS Code seat;
an exact, stable model route; calibrated host-specific observers; and explicit time, model and
credit caps. Private code stays within its existing authorised provider/host boundary. Do not
contact a participant, export traces, query production, or spend provider credits without separate
authority. A missing prerequisite is `NOT RUN` or `NOT COMPARABLE`, never a loss for that arm.

## Freeze before discovery or task execution

The coordinator completes and hashes this private card before either setup arm can see it. Store the
card, accepted solutions and graders outside both setup/task scopes.

| Frozen field | Value required before live work |
|---|---|
| RK1 run id and protocol revision | |
| Repository snapshot/revision and allowed local dependencies | |
| CURRENT and ENHANCED framework commits plus artifact hashes | |
| Exact allowed discovery treatment delta; all other repairs identical | |
| Privacy/provider boundary and prohibited material | |
| Exact Copilot host/version and mode (CLI or VS Code) | |
| Exact model id and proof the route is stable | |
| Setup entrypoint/mode and equal per-arm setup/discovery cap | |
| Task-selection population/window, traversal order and exclusions | |
| Four or more held-out task ids and repository areas | |
| Arm-order counterbalancing schedule | |
| Equal per-task arm cap; setup/discovery/refresh cap; total cap | |
| Materiality thresholds for quality, severe errors, review time and intervention | |
| Observer positive/negative calibration and retained evidence fields | |
| Independent oracle reviewer and review boundary | |
| Explicit live time/model/credit authority | |

Select tasks objectively before discovery. Freeze a chronological or otherwise repository-
justified candidate window and traverse it by a declared order, recording a sanitised exclusion
reason for every earlier candidate. Each selected task must have discoverable pre-change evidence,
an observable requested change, independent acceptance, and at least one correctness-material
nonlocal decision. Its request, accepted solutions and grading key stay hidden from both discovery
setups. Do not select tasks because either arm is expected to win.

The set includes at least four different repository areas and, across them, a quiet unique rule, a
helper-derived rule, a reusable cross-component operation and conflicting legitimate scopes. These
are adversarial shapes, not a domain taxonomy. Reporting, ingestion and finance are optional
examples only. A task whose only “correct” answer depends on unavailable owner intent is ineligible;
if the uncertainty is repository-visible, asking or returning a bounded unresolved decision is a
valid outcome and must be in the frozen alternatives.

For every task freeze this private card:

```text
Task id and repository area:
Selection position and sanitised prior exclusions:
Exact request (hidden from setup):
Observable pre-change state:
Baseline and targeted verification commands:
Required nonlocal decisions and pre-change evidence:
Supported correct alternatives, including ask/unresolved where applicable:
Executable acceptance valid-world construction:
Executable acceptance invalid/pre-change-world construction:
Targeted invalid construction for each required nonlocal decision:
Severe-error definitions:
Knowledge entry/source that could be discovered (never supplied to the task prompt):
Independent oracle review result:
```

Before task agents run, execute the complete oracle against one valid implementation and every
supported alternative, then against the pre-change/invalid world and one targeted violation per
nonlocal decision. A zero exit without the expected probe/test count is `CANNOT EXAMINE`. If the
measure cannot register both success and failure, the task is ineligible; do not repair the oracle
after observing an arm.

## Prepare the paired component arms

Create history-free snapshots from the same approved repository revision, following
`meta/field-study-kit.md > A3` for neutral one-commit Git roots, no remotes, restricted scopes and
outside-root canaries. The arms are:

- **CURRENT:** the exact current released framework and its ordinary setup/discovery behavior.
- **ENHANCED:** the exact candidate release containing only the reviewed discovery increment being
  measured.

Freeze both framework commits, immutable artifact hashes and the exact allowed treatment delta. If
the later candidate release also contains B-216, B-226, B-227 or another repair, either apply that
same repair to both arms or prepare and independently review a component-only ENHANCED artifact.
Never attribute the outcome of an entire changed release to discovery.

Use the same setup host and exact model in both arms, with equal setup/discovery caps. Run the
ordinary requested bootstrap/rebootstrap discovery; never name a held-out task, expected rule,
fixture answer or grading key. Preserve every generated claim/skill/coverage artifact exactly as
produced. Record setup reads, elapsed time, active human time, interventions and observable usage
separately from task cost. Do not “improve” CURRENT by hand or repair ENHANCED into eligibility.

After setup, freeze each arm's generated artifact manifest and bytes. The task agent for one arm
must not be able to address the other arm, the source repository/history, private cards/oracles,
accepted solutions, coordinator storage, global memory containing task knowledge, or prior task
sessions/results. Materialise one arm at a time when the host cannot enforce sibling isolation.
Credentials and personal/organisation instructions must be absent or identical and non-answer-
bearing. Run the baseline in both prepared arms; setup breakage makes the pair void and remains a
setup outcome.

## Offline controls that must be observed before a live arm

These are targeted controls, not a new general checker. Record commands/artifacts and exact
results; a narrative claim is insufficient.

| ID | Constructible valid world | Targeted invalid world that must be rejected |
|---|---|---|
| RK1-C1 selection freeze | Card hash and task order exist before either setup starts | Change a task/order field after the setup timestamp; the recorded hash differs |
| RK1-C2 no answer-bearing setup | Setup-visible tree lacks task request, solution and grader tokens | Plant one unique grader/request token in a setup-visible file; preflight finds it and refuses the task |
| RK1-C3 history isolation | One neutral commit, no remotes/other refs, identical pre-install tree ids | Add a later solution-bearing commit/ref; preflight refuses the arm |
| RK1-C4 filesystem isolation | Probe reads its own random canary and cannot address the other arm, cards, originals or prior results | Expose one excluded canary; the arm is refused, not merely warned |
| RK1-C5 arm purity | CURRENT manifest contains only released-current setup output; ENHANCED has its own frozen output | Copy one ENHANCED knowledge artifact into CURRENT; manifest/byte comparison refuses the pair |
| RK1-C6 oracle reachability | Valid implementation and all frozen alternatives pass; pre-change and targeted violations fail | An inert oracle accepts one targeted violation or rejects a supported valid alternative; task is refused |
| RK1-C7 observer calibration | Known host actions produce inspectable discovery/read/tool-execution observations; independent oracle inspection separately judges semantic application | A final-text keyword echo with no underlying read/action is no host observation, and no event alone is called correct application |
| RK1-C8 stable route | Both paired executions record the same exact host/model route under frozen caps | Route/model changes, is hidden, or Auto resolves differently; pair is `NOT COMPARABLE` |
| RK1-C9 finite execution | Each arm stops at its declared cap and retains partial state as an outcome | A timeout/retry crosses the cap; execution is stopped and not silently rerun |
| RK1-C10 absent evidence | Agent asks or returns the frozen unresolved outcome when necessary evidence is inaccessible | Grader rewards an invented policy or treats `CANNOT EXAMINE` as a pass/fail win |

Host-specific observer calibration happens only after an actual host/seat is selected. Copilot CLI
and VS Code are separate observations. CLI evidence does not fill the VS Code row; skill
registration is not invocation, invocation is not content reading, and content reading is not
correct application. An absent event is meaningful only after RK1-C7 proves that host/version can
emit the corresponding positive observation. Inline completion is outside this agent-task study.

## Counterbalanced task execution

Use fresh sessions and the same exact prompt, host, model, toolchain and calendar window for each
paired task. Counterbalance arm order using the frozen schedule. Reconfirm isolation before the
second arm. Do not show either result to the other, steer toward a known rule, or repair an arm
before scoring. Stop at the frozen cap and score what exists.

For each arm retain locally:

- independent task acceptance and every severe error;
- each required nonlocal decision (`pass`, `fail`, or `cannot examine`);
- typed/inspectable knowledge entry discovery, content/reference read, scoped application and task
  verification as four separate observations;
- active human prompting/review/repair time, intervention count and final acceptability;
- wall time and observable model/agent usage; and
- final diff/artifacts plus targeted/baseline verification output proving the expected checks ran.

`Cannot examine` is unordered and never a win/loss against pass or fail. Valid alternative
implementations pass. Grade against the frozen pre-change evidence and oracle, not similarity to a
historical patch or generated discovery artifact. Record setup and refresh cost separately from
task execution.

## Result record and decision

Complete one row per task before comparing arms. Preserve nulls, regressions and timeouts.

| Task | Arm | Acceptability | Severe errors | Decision vector | Entry found | Body/reference read | Applied correctly | Verification ran | Active review/repair | Interventions | Elapsed | Usage | Gaps |
|---|---|---:|---:|---|---|---|---|---|---:|---:|---:|---|---|
| | CURRENT | | | | | | | | | | | | |
| | ENHANCED | | | | | | | | | | | | |

After recording raw tasks, apply only the materiality thresholds frozen before discovery. Classify
the series as a bounded observation—benefit, harm, mixed, no detectable difference, or void/not
comparable—without a general productivity claim. State every unrun host/model arm.

- Grounded useful artifacts but missed access/application: repair the delivery route before adding
  discovery machinery.
- Correct application without material task improvement: do not expand extraction machinery.
- False rules or excessive review cost: narrow capture or deepen evidence rather than generating
  more.
- Material improvement: expand only the observed discovery/refresh bottleneck; do not infer a
  platform, universal banking benefit, or framework-versus-bare result.

Live results require a separate reviewed run record. They never become a general release gate.

## Offline protocol review

Root reviewed this packet after Sol authored it and returned **ACCEPT WITH CLARIFICATIONS**. The
review required immutable hashes for both framework treatments, an exact allowed discovery delta,
identical handling of unrelated repairs, a frozen setup entrypoint/mode/cap, and separation of
host-observable actions from independent semantic judgment. Those corrections are incorporated
above. The review accepted the scope, privacy, preservation, supported-alternative and null-result
boundaries. It did not execute RK1-C1–C10, authorize a live arm, certify a target host/model, or
establish product value.
