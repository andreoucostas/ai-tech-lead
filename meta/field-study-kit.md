# Framework field study — execution packet

Use this packet to answer two different questions:

1. On the same real repository task, does the installed framework change the result versus the same
   agent without repository framework files?
2. During normal work, which framework surfaces help, harm, make no visible difference, or never
   become observable?

The minimum useful return is **Module A**, one controlled historical-fix replay. **Module B** adds a
short three-task live diary. The maintainer may run the same protocol, but must identify the evidence
source as `maintainer`; only another developer can produce `independent` evidence.

Estimated participant effort: 60–90 minutes for Module A after dependencies are available; roughly
two minutes of recording after each Module B task. Agent/API use is approximately doubled in Module
A because the task runs twice.

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
Would you run the AI Tech Lead field study on one safe historical fix in your repository?

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

## Module A — controlled historical-fix replay

### A1. Select one eligible task before deciding arm order

Choose an already-completed bug fix that:

- has a known pre-fix commit and an accepted outcome;
- has no framework installation at that base commit, or has an exact preserved pre-install snapshot;
- is small enough for one agent session, normally 15–45 minutes;
- has an existing applicable test harness and a baseline command that currently passes;
- has an observable symptom that is true at the pre-fix commit;
- is not a trivial rename, generated change, production incident, or security/privacy-sensitive;
- does not require returning any raw artifact to the coordinator.

Do not choose a task because the framework is expected to excel or fail on it. Record only its broad
shape in the response, such as `boundary bug in an application service`.

Do not manufacture BARE by deleting framework files from an installed repository: protected files
contain mixed consumer/framework history and hand-removal can leave a partially treated control. If
no honest pre-install base exists, run Module B only or define a separate maintainer-only LEAN
ablation; do not label either one BARE.

### A2. Freeze a private task card

Before either arm runs, keep this card locally:

```text
Base commit:
Exact task prompt:
Observable wrong result at the base commit:
Baseline restore/build/test commands:
Targeted verification command:
History-isolation method:
Three existing repository conventions to score:
Known acceptable outcome:
Time/cost stop limit:
```

Verify the wrong result is reachable and the baseline build/test command is green. If either cannot
be demonstrated, choose another task; otherwise the replay cannot distinguish agent behavior from a
broken fixture.

A test command is green only when its output proves that the expected test or probe was discovered,
executed, and passed. Exit code zero with `No test matches`, a skipped or unloadable test assembly,
or no executed-test count is `cannot verify`, not success. Record the host failure and use a
predeclared equivalent instrument only when the equivalence itself is inspectable; do not rerun an
ambiguous command until it happens to look green.

The three R2 convention checks must be independently observable and must not merely restate R3 test
existence/order or R5 leanness. Otherwise one behavior is counted twice in the total.

### A3. Create isolated arms

Create two **history-free snapshots** from the same base. A detached checkout is not isolated: its
object database and branch refs still expose later fix commits, and a locally planted latest commit
exposes its clean parent and mutation diff. Either gives the task agent an answer key.

A typical PowerShell sequence for repositories without submodules or LFS is:

```powershell
git -C <existing-local-repo-path> archive --format=tar --output=<scratch-path>\base.tar <base-commit>
New-Item -ItemType Directory <scratch-path>\bare, <scratch-path>\framework
tar -xf <scratch-path>\base.tar -C <scratch-path>\bare
tar -xf <scratch-path>\base.tar -C <scratch-path>\framework

foreach ($arm in @('<scratch-path>\bare', '<scratch-path>\framework')) {
    git -C $arm init
    git -C $arm config core.autocrlf false
    git -C $arm add --force --all
    git -C $arm -c user.name=Field-Study -c user.email=field-study@local.invalid `
        commit -m 'Field-study base snapshot'
    git -C $arm remote -v
}

git -C <scratch-path>\bare show -s --format=%T HEAD
git -C <scratch-path>\framework show -s --format=%T HEAD
```

Equivalent bash or snapshot/export commands are acceptable. Both tree ids must match before the
framework is installed, and both `remote -v` commands must print nothing. Before inviting an agent,
confirm that each arm's `git log --all` contains only the neutral snapshot commit and no later fix or
mutation commit. If the repo uses submodules, LFS, generated prerequisites, or machine-local
dependency caches, prepare both arms identically and record the difference from this recipe. Do not
invite an agent until the history check passes.

The forced add in this recipe is only for the initial archive contents, before any build has run.
After restore/build/test creates ignored outputs, commit framework installation or setup with an
ordinary `git add --all`; never force-add `bin/`, `obj/`, coverage, package, or host-cache
artifacts. Inspect the staged paths before preserving the prepared baseline.

Run the frozen baseline commands in both arms. Stop if either is not green.

### A4. Prepare the FRAMEWORK arm and record onboarding separately

Install the exact released tag supplied by the coordinator:

```powershell
pwsh <framework-release-path>\install.ps1 <scratch-path>\framework
```

or:

```bash
bash <framework-release-path>/install.sh <scratch-path>/framework
```

Follow the installer's printed handoff exactly; do not choose the setup command from the ordinary
English labels `greenfield` or `brownfield`. On a first framework install with no pre-existing AI
tooling, the handoff normally requires `/bootstrap`. When the installer records adoption as pending,
`/bootstrap` redirects the developer to `/adopt`, which later runs bootstrap as part of adoption.
Complete whichever command the installed handoff requires in a fresh interactive agent session.

The setup command is developer-initiated. If an AI agent is coordinating the study, it must stop at
this boundary and ask the developer to start the session and type the printed command; it must not
invoke the command or reproduce its work by hand. Start the onboarding timer immediately before
reading/running the install instruction; stop it after the first green `scripts/docs-sync-check`.
Record the printed command, human interventions, and anything unclear. Do not include this time in
either task arm.

Commit the prepared framework state locally or otherwise preserve an exact baseline. Run the first
`scripts/docs-sync-check` and require it to pass before the task arm starts; a setup agent's
completion statement is not that evidence. Record the framework tag, setup host/model, any
availability constraint that selected a lower tier, repair sessions, and whether hooks were actually
live. Keep setup-model evidence separate from the model frozen for both task arms. The BARE arm
receives no repository framework files. Personal and organisation-level host instructions must
remain the same in both arms; record their presence if known.

Record whether setup generated an artifact that already names the task's diagnosis or recommended
fix. Do not delete or conceal it: generated repository understanding is part of the end-to-end
FRAMEWORK treatment. It does, however, limit attribution—the replay then measures the installed
package including bootstrap discovery, not task-time rails alone. A separate execution-only study
must prepare framework context on the accepted clean state before creating identical history-free
defective snapshots; do not silently turn this end-to-end protocol into that variant.

### A5. Randomise and run

Flip a coin after both arms are ready:

- heads: FRAMEWORK first;
- tails: BARE first.

Record the result. Use a fresh agent conversation for each arm, the same exact model, and the same
private task prompt. Do not show one arm's transcript or diff to the other.

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

Use the frozen B-49 wording in `meta/value-rubric.md`. Score from the transcript, diff, repository,
and command output—not the agent's completion statement.

Also score task acceptability separately:

- `2` — acceptable as-is after the recorded verification and review;
- `1` — acceptable after small, bounded human edits;
- `0` — not acceptable or wrong.

Write both arms' raw scores before computing `FRAMEWORK − BARE`.

### A7. Classify the observed direction

A primary difference is material when:

- task acceptability differs; or
- rubric totals differ by at least 2/10; or
- active participant time differs by at least 15% and at least 5 minutes; or
- intervention count differs by at least 2.

Classify as:

- `benefit` — FRAMEWORK materially wins at least one primary measure and loses none;
- `harm` — FRAMEWORK materially loses at least one and wins none;
- `mixed` — each arm materially wins at least one;
- `no detectable difference` — no primary difference crosses a threshold;
- `void` — the arms were not comparable or the task/measurement could not register both success
  and failure.

Keep every raw measure beside this label. It is not a testimonial or a statistical conclusion.

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
