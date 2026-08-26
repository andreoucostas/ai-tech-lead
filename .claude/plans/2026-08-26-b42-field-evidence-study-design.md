# B-42/B-49 field evidence study — design

**Status: CORRECTED MAINTAINER REPLAY COMPLETE; INDEPENDENT PILOT READY, 2026-08-26.** This is a
meta-only study design. It does not ship to consumers and changes no framework behavior. The first
run completed both arms but was void; the corrected history-isolated replay completed validly and
found no detectable material difference on one small fix. The protocol gate before an independent
participant is now satisfied. Independent review is still required before any future version is
promoted into `dist/` as a consumer self-assessment.

- **Decision record:** `meta/workspace-decisions.md` WSD-053
- **Execution packet:** `meta/field-study-kit.md`
- **Response form:** `meta/field-study-response-template.md`
- **Result ledger:** `meta/field-study-results.md`

## Premise correction

`meta/field-reports.md` is an improvement-only issue ledger. The maintainer acted on actionable
negative reports and did not record unsolicited positive feedback. Its negative distribution is
therefore intentional sampling, not evidence that overall experience is negative. It remains useful
for diagnosing defects, but cannot support any satisfaction, adoption, or value claim.

Balanced outcome evidence belongs in a separate study record that captures benefit, harm, mixed
effects, and no detectable difference using the same prompts and fields.

## What can be measured without another person

The maintainer can measure:

1. deterministic install, update, recovery, host-delivery, hook, gate, context, and runtime behavior;
2. framework-versus-bare behavior on isolated historical-task replays;
3. full-versus-lean instruction ablations on the same replay;
4. rubric score, test outcome, verification evidence, intervention count, elapsed time, and active
   time for those arms;
5. positive, neutral, mixed, and harmful effects across consecutive tasks in the maintainer's own
   production use.

Those measurements can establish mechanism reach and author-workflow value. They cannot establish
that a non-author understands onboarding, accepts the policy choices, experiences tolerable
friction, or gets the same result in a team review. Those claims require an independent participant.

### Recommended solo sequence

1. Complete B-49 Drill 0 against the current released tag; keep its pinned-OSS result separate from
   real-work evidence.
2. Dry-run Module A on one historical fix and correct protocol defects before inviting anyone.
3. Run three historical-fix replays selected by a rule fixed before looking at likely framework
   performance—for example, the first eligible accepted fix from each of three consecutive weeks.
   Use a base before framework installation or a pinned OSS target; never create BARE by hand-deleting
   framework files from a treated repository.
4. Where budget permits, run each arm three times to expose model variance; otherwise retain `n=1`
   prominently and make no reliability claim.
5. Record the next ten eligible maintainer production tasks with the Module B card. This gives a
   balanced author-workflow denominator rather than another memorable-incident ledger.
6. After the FRAMEWORK-versus-BARE baseline exists, a maintainer-only `LEAN` arm may test a reduced
   instruction set. Do not ask participants to pay for that component-ablation work.

## Chosen design

One packet supports two modules and identifies the evidence source as `maintainer` or `independent`.

### Module A — controlled historical fix replay

Run one already-completed, non-sensitive bug fix from the repository's pre-fix commit in two local,
remote-less clones:

- `FRAMEWORK`: install the exact released framework tag and complete the installer-selected
  `/bootstrap` or `/adopt` path;
- `BARE`: no repository framework files.

Both arms use the same base commit, task prompt, host, model, day, baseline commands, and fresh
session. The task must have an applicable existing test harness and a known acceptable outcome.
Arm order is randomised; outputs are scored only after both arms finish.

The shared B-49 rubric remains frozen: fabrication, convention adherence, test discipline,
verification evidence, and leanness, each 0–2. Task acceptability, active time, wall time, and human
interventions are recorded separately. Review-task findings are not substituted for leanness; the
locked B-49 design scores those separately.

This module estimates the package effect versus no repository framework. It does not identify which
individual rule caused a delta. A later maintainer-only `LEAN` arm may isolate that question, but it
is not required from participants.

### Module B — three consecutive live-task diary

Use the installed framework for the next three eligible real tasks, not three hand-picked memorable
ones. After each task, record a two-minute card: outcome, rework, active time, framework surfaces
that helped, harmed, had no visible effect, or could not be observed, plus any noise or ignored
guidance. There is no bare counterfactual, so this module measures reach and friction rather than
causal value.

### Onboarding observation

For a first-time installer, record time and interventions from opening the packet through the first
green `docs-sync-check`. This is kept separate from task time. A maintainer rerun cannot answer the
non-author comprehension question and is labelled accordingly.

## Fixed outcome interpretation

Never average away a failed task. Record raw values first.

A difference is material when at least one of these holds:

- task acceptability differs (`accepted`, `accepted after small edits`, `not acceptable`);
- frozen-rubric totals differ by at least 2 points out of 10;
- active participant time differs by at least 15% and at least 5 minutes;
- human steering/intervention count differs by at least 2.

Classify the replay:

- **benefit:** FRAMEWORK materially wins at least one primary measure and loses none;
- **harm:** FRAMEWORK materially loses at least one primary measure and wins none;
- **mixed:** each arm materially wins at least one primary measure;
- **no detectable difference:** no primary measure crosses its material threshold;
- **void:** the bases, prompts, model, environment, task reachability, or scoring evidence are not
  comparable.

The classification is a compact description, not a statistical conclusion. Preserve the individual
measures beside it.

## Privacy and participant boundary

- Raw repositories, prompts, transcripts, diffs, command output, and client vocabulary stay local.
- Only the sanitised response form is returned. It contains stack, size/test bands, scores, counts,
  timings, and technical shapes—not names, code, paths, tickets, or business data.
- Participation is voluntary, may stop at any time, and is never used for employee-performance
  evaluation.
- Both clones have remotes removed before an agent runs. No real secrets or production data are
  planted.
- A participant can return `not captured` or decline any field. Missing data is not inferred.

## Proportionality

The observed harm is an evidence record that could be misread as broad negative sentiment and a
B-42/B-49 value question that has no prepared participant path. A prose correction alone fixes the
first problem but not the second. Shipping automation, telemetry, or a new command would add product
surface, privacy exposure, host-specific failure modes, and context cost before a participant has
shown that the protocol is usable. The smallest adequate response is therefore a meta-only packet,
response form, and balanced ledger.

## Alternatives considered

1. **Testimonials or a satisfaction survey only — rejected.** Cheap, but self-selected sentiment
   cannot show what the framework changed or distinguish value from politeness.
2. **Two-to-four-week diary only — rejected as the whole design.** Good for real friction, but no
   counterfactual and vulnerable to task mix. Retained as Module B.
3. **Automated telemetry shipped to consumers — rejected for now.** It would introduce consent,
   confidentiality, host-coverage, and interpretation problems before the field question is known.
4. **Historical-task replay plus consecutive-task diary — chosen.** The replay provides a bounded
   counterfactual without risking live work; the diary restores ecological validity and captures
   both positive and negative experience.

## Adversarial critique folded before marking ready

1. **Learning contamination:** running the same task twice can teach the participant. Mitigation:
   fresh agent sessions, no cross-arm transcript sharing, random arm order, prewritten prompt, and no
   scoring until both finish.
2. **Task-selection bias:** a participant could choose a showcase or pathological task. Mitigation:
   eligibility rules require an already-completed fix chosen before arm order; the diary uses the
   next three eligible tasks.
3. **Bare-arm straw man:** `BARE` may be worse than a normal repo with good native instructions.
   Mitigation: the claim is explicitly package-versus-no-framework. A maintainer-only `LEAN` arm is
   the follow-up for component attribution.
4. **Setup asymmetry:** `/bootstrap` or `/adopt` costs time only in FRAMEWORK. Mitigation: onboarding
   is measured and reported separately; task comparison starts after both baselines are green.
5. **Self-grading bias:** the participant knows the arm. Mitigation: executable tests dominate task
   acceptability, three repository-convention checks are frozen before execution, raw arm scores are
   written before the delta, and an optional blind reviewer may be used without being required.
6. **Confidentiality leakage:** prompts and diffs may contain client facts. Mitigation: raw artifacts
   never leave the participant environment; only a sanitised aggregate form returns.
7. **Composite-score camouflage:** a good documentation score could hide incorrect code. Mitigation:
   task acceptability is separate and can never be averaged away.
8. **Rubric drift:** `meta/drill-kit.md` had replaced the locked plan's leanness row with review
   findings. Mitigation: restore the authoritative B-49 five dimensions before any study run and
   keep review-task findings separate.
9. **N=1 overclaim:** one replay is stochastic. Mitigation: every result retains source and sample
   count; maintainer runs should use repeated trials when affordable, and independent results are
   aggregated descriptively only after at least three complete replays.
10. **Participant burden:** a full install, two agent runs, grading, and a diary can be abandoned.
    Mitigation: Module A is the minimum useful return; Module B is optional but requested, the form
    uses bounded fields, and incomplete studies remain valid partial observations.
11. **Solution-bearing history:** a detached historical checkout still exposes later commits, while
    a planted latest commit exposes its clean parent and exact mutation. Mitigation: build both arms
    from identical history-free snapshots with one neutral root commit and verify `git log --all`
    before either agent runs.
12. **Double-counted behavior:** R2 convention checks can restate R3 test discipline or R5 leanness
    and inflate a delta. Mitigation: freeze three independently observable repository conventions
    and reject a task card whose R2 checks duplicate another rubric dimension.

## Maintainer dry-run observation — 2026-08-26

The pinned .NET historical-fix fixture reached the known wrong result, and both remote-less arms
passed the same applicable 44-test baseline. The full repository suite also exposed one unrelated
pre-existing integration failure, so the applicable unit suite—not the whole-solution command—is
the frozen arm baseline and the broader failure remains a limitation rather than being retried away.

Installing exact release `v0.77.0` into the existing codebase took 2.204 seconds and selected
installer mode `greenfield`. Its authoritative handoff required a developer to start Claude Code
and type `/bootstrap`; it explicitly prohibited an AI agent from invoking or reproducing that step.
The packet had incorrectly hard-coded `/adopt` from the codebase's ordinary brownfield status. The
packet and response form now bind to the installer's printed lifecycle command. The developer
completed bootstrap; `docs-sync-check` and the applicable 44-test baseline were green before arm
order was randomised to FRAMEWORK first.

Both Claude Sonnet 5 arms returned acceptable fixes and passed the same private acceptance probe.
FRAMEWORK added a red-first regression test, scored a raw `9/10`, took 6.43 wall minutes, and needed
one restore approval; BARE added no test, scored a raw `6/10`, took 1.23 minutes, and needed no
intervention. Independent final suites passed 45/45 and 44/44 respectively. The formal raw threshold
would therefore say `benefit`.

The result is nevertheless `void`. Both arms retained the planted latest commit, so its neutral
parent and exact mutation were visible; BARE explicitly used `git show` to read the answer. The
FRAMEWORK bootstrap separately generated an exact debt diagnosis and recommended test, which is a
legitimate end-to-end treatment mechanism but prevents attribution to task-time rails. Two frozen
R2 checks also duplicated R3 test behavior. The packet now requires history-free neutral snapshots,
records bootstrap answer discovery, and prohibits R2 overlap. These are dry-run findings, not value
evidence. The replacement snapshot recipe was then executed in scratch: both arms produced the same
non-empty tree id, exactly one neutral commit, and zero remotes. That closed the first dry run; the
corrected replay is recorded below.

## Corrected maintainer replay — 2026-08-26

FS-20260826-RERUN-02 exported the planted defective tree into two neutral root repositories. Before
installation both arms had the same non-empty tree id, one commit, zero remotes, clean working
trees, the same demonstrated wrong result, and independent `44/44` baselines. The setup and task
models are separate observations: Opus usage was unavailable, so the developer ran bootstrap with
`claude-sonnet-5`; both task arms also used `claude-sonnet-5`, high effort, under identical
prompt/tool conditions. Bootstrap did not name the target diagnosis in this run.

Onboarding itself found a shipped workflow defect. Bootstrap claimed completion while
`docs-sync-check` rejected backticked hazard statuses, one invalid hazard path, and a stale Boy
Scout mirror. A Sonnet `/generate-copilot` repair still left one mirror line stale while claiming
the sections matched; the coordinator made the exact deterministic correction and the third check
passed. B-177 tracks that product failure. The setup transcript spanned 23.9 minutes and required 11
developer follow-ups after the initial command; setup repair cost and time remain outside task-arm
measures.

The cryptographic coin selected FRAMEWORK first. Both task agents returned the same acceptable,
byte-identical one-line fix and colocated xUnit regression test with zero human intervention.
FRAMEWORK wrote and demonstrated the test red before changing production code; BARE changed
production code first and then showed its test green. Independent applicable suites passed
`45/45` in both arms. Frozen scores were FRAMEWORK `10/10`, BARE `9/10`; acceptability
`2/2`; active participant time `<1/<1` minutes; wall time `2.62/1.14` minutes; interventions
`0/0`; agent cost `$0.312/$0.162` (descriptive only). The `+1` rubric delta crosses no
predeclared material threshold, so the valid direction is `no detectable difference`, not benefit.

One verification limitation remains visible. The private probe passed in FRAMEWORK, while Windows
Application Control later blocked BARE's rebuilt test assembly and `dotnet test` incorrectly
exited zero with no matching test. That command is inconclusive, not green; equivalent BARE task
coverage, the independent `45/45` suite, and byte-identical probe-passing outcome files support
acceptability without erasing the host failure. The packet and quarterly drill now require evidence
that the expected test actually executed, forbid force-adding post-build ignored artifacts, and
record setup-model constraints separately.

## Done when

- the packet can be sent without an oral explanation beyond the released framework location;
- one dry run proves every requested field can be populated or honestly marked `not captured`;
- results distinguish `maintainer` from `independent` and balanced outcomes from issue reports;
- no raw client artifact is required to leave the participant environment;
- the first independent run either completes or produces a protocol defect to fix.
