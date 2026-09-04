# Framework field study — execution packet (FS2)

FS2 applies prospectively from 2026-08-29. FS-20260826-RERUN-02 remains an unchanged FS1 result and
must not be rescored or aggregated with this series. FS2 retains FS1's isolation, privacy,
onboarding, and diary controls while replacing the paired task shape and primary outcome contract.

Use this packet to answer two different questions:

1. On the same real repository task, does the installed framework change the result versus the same
   agent without repository framework files?
2. During normal work, which framework surfaces help, harm, make no visible difference, or never
   become observable?

The minimum useful return is **Module A**, one controlled convention-rich historical-change replay.
**Module B** adds a short three-task live diary. The maintainer may run the same protocol, but must
identify the evidence source as `maintainer`; only another developer can produce `independent`
evidence.

Estimated participant effort: 90–150 minutes for Module A after dependencies are available; roughly
two minutes of recording after each Module B task. Agent/API use is approximately doubled in Module
A because the task runs twice. Set an explicit time and cost cap before selecting the task.

## What to receive from the coordinator

- a study id;
- the exact released framework tag and a local checkout or approved source for it;
- `meta/value-rubric.md`;
- `meta/field-study-response-template.md`;
- a return route for the completed, sanitised response.

You should not need to send the coordinator your repository, prompt, transcript, diff, command
output, client identity, ticket, file paths, or business vocabulary.

### Copy/paste invitation

The coordinator only needs to fill the three bracketed values:

```text
Would you run the AI Tech Lead field study on one safe, convention-rich historical change in your repository?

Study id: [ID]
Framework release: [TAG AND APPROVED LOCAL/SOURCE LOCATION]
Return the sanitised response to: [ROUTE]

Please follow meta/field-study-kit.md. Module A is the minimum useful run; Module B is the optional
three-task follow-up. Keep your source, prompt, transcripts, diffs, command output, and client details
local. Return only a completed copy of meta/field-study-response-template.md. Stop and return a
partial response if isolation, sensitivity, time, or cost becomes a concern.
```

## Safety and privacy rules

1. Use scratch clones, never the live working clone. Remove every remote before an agent runs.
2. Do not choose a production incident, security-sensitive change, real credential, personal data,
   or task whose replay itself creates risk.
3. Raw artifacts remain local: source, prompt, transcripts, diffs, logs, build output, and the known
   solution. Return only the sanitised response form.
4. Participation is voluntary. Stop if the task becomes sensitive, the baseline cannot be made
   green, isolation is uncertain, or cost/time exceeds your limit. Record the stop as a partial or
   void run; do not force completion.
5. Results assess the framework, not the participant or their job performance.

## Module A — controlled convention-rich historical-change replay

### A1. Select one eligible task objectively before deciding arm order

Freeze a chronological candidate window before inspecting task suitability. Choose its source
population and endpoints only from availability and recency constraints, not expected framework
fit. Traverse accepted mainline changes newest-to-oldest by completion order; record the count and
sanitised eligibility criterion for every exclusion. Choose the first eligible already-completed,
accepted feature or multi-file change in that order that:

- has a known pre-change commit and an accepted outcome;
- has no framework installation at that base commit, or has an exact preserved pre-install snapshot;
- touches 3–8 hand-authored files across at least two architectural areas;
- requires three independent non-local repository decisions, including at least one integration or
  ownership decision; none of their expected outcomes is stated in the task prompt, and every
  outcome and hard/soft label is justified from pre-change evidence or a pre-existing immutable
  acceptance contract rather than inferred solely from the accepted historical implementation;
- is small enough for one agent session under the participant's frozen equal per-arm time/cost caps;
- has executable private acceptance evidence and a baseline command that currently passes;
- has an observable pre-change state that makes the requested change meaningful;
- is not a trivial rename, generated change, production incident, or security/privacy-sensitive;
- does not require returning any raw artifact to the coordinator.

If a candidate fails a criterion, record only the sanitised criterion and assess the next
chronological candidate. Do not choose a task because the framework is expected to excel or fail on
it. Record only its broad shape in the response, such as `cross-layer endpoint with repository
ownership conventions`.

Do not manufacture BARE by deleting framework files from an installed repository: protected files
contain mixed consumer/framework history and hand-removal can leave a partially treated control. If
no honest pre-install base exists, run Module B only or define a separate maintainer-only LEAN
ablation; do not label either one BARE.

### A2. Freeze a private task card

Before either arm runs, keep this card locally:

```text
Base commit:
Frozen candidate window, newest-to-oldest position, excluded count/criterion codes:
Exact task prompt:
Observable pre-change state:
Baseline restore/build/test commands:
Targeted verification command:
History-isolation method:
Executable-acceptance valid-world construction:
Executable-acceptance invalid/pre-change-world construction:
Decision 1 (pre-change evidence/immutable contract, acceptable outcome(s), hard/soft):
Decision 2 (pre-change evidence/immutable contract, acceptable outcome(s), hard/soft):
Decision 3 (pre-change evidence/immutable contract, acceptable outcome(s), hard/soft):
Complete-primary-oracle valid-world construction (executable acceptance + applicable D1–D3):
Supported-alternative complete-stack proof (no alternatives by pre-change contract, or passing fixture per alternative):
Oracle D1-targeted violation construction:
Oracle D2-targeted violation construction:
Oracle D3-targeted violation construction:
Known acceptable outcome(s):
Equal per-arm time/cost stop limits; setup/selection total cap:
```

Verify the pre-change state and green baseline. Before inviting either agent, demonstrate that the
complete primary oracle stack—executable acceptance plus every applicable D1–D3 check—passes the
main valid implementation and one fixture for every frozen pre-change-supported alternative, or cite
the immutable pre-change contract proving there are no alternatives. Separately demonstrate that
executable acceptance rejects a plausible invalid or pre-change world. For each of D1–D3, reject a
plausible targeted violation while the other decisions remain valid where feasible. Record which
oracle observation isolates each measure. If
any state is unreachable, fewer than three independent decisions exist, or a framework setup
artifact gives away the requested change, mark the candidate ineligible and take the next
chronological one; otherwise the replay cannot distinguish behavior from a broken fixture or an
inert primary measure.

Grade the pre-change contract, not similarity to the accepted patch. Freeze every supported
alternative outcome before task agents run; do not make the historical implementation uniquely
correct unless pre-change evidence actually did.

A test command is green only when its output proves that the expected test or probe was discovered,
executed, and passed. Exit code zero with `No test matches`, a skipped or unloadable test assembly,
or no executed-test count is `cannot verify`, not success. Record the host failure and use a
predeclared equivalent instrument only when the equivalence itself is inspectable; do not rerun an
ambiguous command until it happens to look green.

The three decisions must be independently observable and must not merely restate test existence/order
or leanness. Keep their local evidence separate; FS2 does not compress them into an R2 score.

### A3. Create isolated arms

Create two **history-free snapshots** from the same base and put them behind separate enforced
filesystem scopes. A detached checkout is not isolated: its object database and branch refs still
expose later fix commits, and a locally planted latest commit exposes its clean parent and mutation
diff. Two sibling directories under one agent-readable scratch root are also not isolated: the
second agent can inspect the first arm's completed solution. Either leak gives a task agent an answer
key.

A typical PowerShell sequence for repositories without submodules or LFS is:

```powershell
git -C <existing-local-repo-path> archive --format=tar --output=<coordinator-only-path>\base.tar <base-commit>
New-Item -ItemType Directory <bare-isolated-root>, <framework-isolated-root>
tar -xf <coordinator-only-path>\base.tar -C <bare-isolated-root>
tar -xf <coordinator-only-path>\base.tar -C <framework-isolated-root>

foreach ($arm in @('<bare-isolated-root>', '<framework-isolated-root>')) {
    git -C $arm init
    git -C $arm config core.autocrlf false
    git -C $arm add --force --all
    git -C $arm -c user.name=Field-Study -c user.email=field-study@local.invalid `
        commit -m 'Field-study base snapshot'
    git -C $arm remote -v
}

git -C <bare-isolated-root> show -s --format=%T HEAD
git -C <framework-isolated-root> show -s --format=%T HEAD
```

Equivalent PowerShell snapshot/export commands are acceptable. This recipe prepares content; it does
not create the required access boundary. Use a workspace sandbox, container, VM, or OS account whose
agent-readable scope—including setup and task agents—contains only the assigned arm and, for setup,
the exact framework release. It excludes the other arm, original source clone or accepted history,
private task card/oracle, coordinator storage, and any completed first-arm artifact.
If the host cannot enforce that, materialise one arm at a time and keep every excluded input/result
outside the task agent's addressable filesystem. Instructions saying “do not look” are not isolation.

Before setup and before each task, test the real execution boundary with random canaries outside the
checkout: an identically permissioned probe must read its own execution-root canary and receive
access-denied or not-found for every excluded storage class above. Remove the own-root canary before
starting that agent. Both Git tree ids must match before framework installation, both `remote -v` commands
must print nothing, and each arm's `git log --all` must contain only the neutral snapshot commit and
no later fix or mutation commit. If the repo uses submodules, LFS, generated prerequisites, or
machine-local dependency caches, prepare both arms identically and record the difference from this
recipe. Do not invite an agent until history and filesystem isolation both pass.

The forced add in this recipe is only for the initial archive contents, before any build has run.
After restore/build/test creates ignored outputs, commit framework installation or setup with an
ordinary `git add --all`; never force-add `bin/`, `obj/`, coverage, package, or host-cache
artifacts. Inspect the staged paths before preserving the prepared baseline.

Run the frozen baseline commands in both arms. Stop if either is not green.

### A4. Prepare the FRAMEWORK arm and record onboarding separately

Install the exact released tag supplied by the coordinator:

```powershell
pwsh -NoProfile -File <framework-release-path>\install.ps1 <framework-isolated-root>
```

Follow the installer's printed handoff exactly; do not choose the setup command from the ordinary
English labels `greenfield` or `brownfield`. On a first framework install with no pre-existing AI
tooling, the handoff normally requires `/bootstrap`. When the installer records adoption as pending,
`/bootstrap` redirects the developer to `/adopt`, which later runs bootstrap as part of adoption.
Complete whichever command the installed handoff requires in a fresh interactive agent session.

Run that setup session inside the same canary-proven restricted scope defined in A3. Before setup,
freeze an exact allowed-path set from the installer's dry-run/ownership manifest plus the setup
command's declared context outputs. After setup and before committing, inspect a byte/name-status
diff including untracked and task-relevant ignored paths. A generated/cache ignored class may be
excluded only when its pattern is frozen from the pre-setup inventory and recorded before setup;
setup cannot expand that exclusion. Every changed path must be predeclared; product source, tests,
dependencies, build configuration, and unrelated repository configuration are never implied by a
generic “context” allowance. Any unexpected delta is onboarding harm: retain the evidence, mark the
pair void, and do not repair it into eligibility.

The setup command is developer-initiated. If an AI agent is coordinating the study, it must stop at
this boundary and ask the developer to start the session and type the printed command; it must not
invoke the command or reproduce its work by hand. Start the onboarding timer immediately before
reading/running the install instruction; stop it after the first green `scripts/docs-sync-check`.
Record the printed command, human interventions, and anything unclear. Do not include this time in
either task arm.

Only after that path/diff inspection, commit the prepared framework state locally or otherwise
preserve an exact baseline. Run the first
`scripts/docs-sync-check` and require it to pass before the task arm starts; a setup agent's
completion statement is not that evidence. Then rerun the frozen product baseline in FRAMEWORK and
BARE immediately before A5 and require both to prove the expected tests/probes executed and passed.
If setup changed or broke that baseline, retain it as onboarding harm and mark the task pair void;
do not attribute the drift to a task agent. Record the framework tag, setup host/model, any
availability constraint that selected a lower tier, repair sessions, and whether hooks were actually
live. Keep setup-model evidence separate from the model frozen for both task arms. The BARE arm
receives no repository framework files. Personal, memory, and organisation-level host instructions
must be identical and must not contain AI Tech Lead-derived or answer-bearing task guidance. If that
cannot be established or disabled, the control is not BARE; run Module B or a separately named LEAN
ablation instead.

Record whether setup generated an artifact that already names the requested change or a recommended
implementation. Do not delete or conceal it. For FS2 this makes the candidate ineligible: retain the
onboarding observation, do not start either task arm, and take the next chronological candidate under
the same frozen window and cap. General repository maps and conventions are the intended treatment;
an answer-bearing setup artifact is not. A separate execution-only study must prepare framework
context on the accepted clean state before creating identical history-free pre-change snapshots; do
not silently turn this end-to-end protocol into that variant.

### A5. Randomise and run

Flip a coin after both arms are ready:

- heads: FRAMEWORK first;
- tails: BARE first.

Record the result. Use the same current frontier model available to the participant at study start,
the same exact model id, private task prompt, host/toolchain, and calendar day, with a fresh agent
conversation for each arm. Any drift makes the pair void; an explanation documents the failure but
does not waive the contract. Do not show one arm's transcript or diff to the other. Before the
second arm, reconfirm that its execution context cannot address the first checkout, transcript,
diff, or result.

Avoid steering. If the FRAMEWORK arm asks for the plan approval its rules require, reply `Go ahead`
and count that as one intervention. For any other question, answer only what is necessary and record
the intervention. Do not silently repair either arm before scoring it.

For each arm record locally:

- wall-clock task time;
- participant active minutes spent prompting, answering, inspecting, or repairing;
- human interventions after the initial prompt;
- agent/API cost reported by the host, or `not captured`;
- final diff and transcript;
- targeted and baseline verification output, including proof that the expected tests actually ran;
- whether the result was acceptable as-is, acceptable after small edits, or not acceptable.

Stop an arm at the frozen time/cost limit and score what exists. A timeout is an outcome, not missing
data.

### A6. Score both arms before calculating a delta

Use `meta/value-rubric.md`'s FS2 primary-outcome contract. Score from the transcript, diff,
repository, and command output—not the agent's completion statement. For each arm record executable
acceptance as `pass`, `fail`, or `cannot examine`, and record each named decision separately as
`pass`, `fail`, or `cannot examine`.

Score task acceptability:

- `2` — acceptable as-is after the recorded verification and review;
- `1` — acceptable after small, bounded human edits;
- `0` — not acceptable or wrong.

Retain raw R1–R5 values or `not applicable` as descriptive continuity data only. Do not calculate an
FS2 composite total. Write both arms' acceptability, executable result, decision vector, process
observations, time, interventions, and cost before comparing them.

For executable acceptance and D1–D3, `pass` and `fail` are ordered; `cannot examine` is not. Only a
`pass` versus `fail` comparison is a directional win or loss. Record `cannot examine` as an
instrumentation gap. If it makes acceptability or arm comparability unjudgeable, classify the pair
`void`; otherwise classify from the remaining observable measures and retain the limitation.

### A7. Classify the observed direction

A material observed difference exists when either a primary quality outcome or a separate burden
signal crosses its threshold:

- task acceptability differs; or
- executable acceptance is `pass` in one arm and `fail` in the other; or
- a predeclared hard decision is `pass` in one arm and `fail` in the other; or
- active participant time differs by at least 15% and at least 5 minutes; or
- intervention count differs by at least 2.

Classify as:

- `benefit` — FRAMEWORK materially wins at least one quality or burden measure and loses none;
- `harm` — FRAMEWORK materially loses at least one quality or burden measure and wins none;
- `mixed` — each arm materially wins at least one;
- `no detectable difference` — no quality or burden difference crosses a material threshold;
- `void` — the arms were not comparable or the task/measurement could not register both success
  and failure.

Keep every raw measure beside this label. It is not a testimonial or a statistical conclusion.
Do not aggregate this FS2 result with FS1. Preserve the first valid pair even when it reports no
difference; never tune the task, decisions, oracle, or thresholds and rerun because of its direction.

## Module B — three consecutive live-task diary

After Module A, use the installed framework on the next three eligible normal tasks within one week.
Do not choose only unusually good or bad sessions. Skip incidents and sensitive work, record the
skip count, and take the next eligible task.

Immediately after each task, fill one diary card in the response form:

- task shape and outcome;
- active time and human interventions;
- review/rework needed after the agent said it was complete;
- surfaces observed (`rail`, `skill`, `hook`, `review agent`, `doctor`, or `other`);
- for each observed surface: `helped`, `harmed`, `no visible effect`, or `not observable`;
- any false positive, noise, ignored guidance, or useful catch;
- confidence in the observation: `high`, `medium`, or `low`, with one sentence why.

This diary has no bare counterfactual. It supports claims about reach, friction, and observed
episodes—not causal productivity.

## Finish and return

1. Complete `meta/field-study-response-template.md` without copying raw task material into it.
2. Search the response for names, paths, URLs, ticket identifiers, code, secrets, and domain terms;
   remove them.
3. Return only that response through the agreed route.
4. Keep or delete local raw artifacts according to your organisation's policy. The framework
   maintainer does not need them.

An incomplete response is still useful when it says exactly where and why the protocol stopped.
