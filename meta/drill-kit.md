# Quarterly live-fire drill kit

> **EXECUTION PAUSED 2026-08-30 — DO NOT RUN THIS PACKET.** WSD-062 found it is not a faithful
> implementation of the historical locked design: required checklist/canary work is missing,
> `scripts/convention-check.ps1`/`.sh` do not exist, the target/pin records conflict, and the task
> oracles and current-agent isolation boundary cannot support a countable value verdict. The content
> below is retained as historical input to a future re-lock, not as executable instructions.

This is an execution kit, not evidence that a drill ran. Run it only in a maintainer-approved
session with real clone, build, and agent budget. Record literal commands and outputs in the drill
report; never turn an unrun step into an observation.

## Pinned targets and host toolchain

- .NET: `dotnet-architecture/eShopOnWeb`; commit SHA **to be pinned at drill #0**.
- Angular: `gothinkster/angular-realworld-example-app`; commit SHA **to be pinned at drill #0**.
- Before using either target, count source files, inspect enough code to establish real domain logic,
  and run its documented baseline build. The binding range is 50–500 source files and a green build
  on the maintainer box. If a target fails, stop and record the observation before applying B-49's
  fallback/replacement policy.
- This box has .NET and Node installed, but the session `PATH` is corrupted. Use
  `C:\Program Files\dotnet\dotnet.exe` and `C:\Program Files\nodejs\node.exe` explicitly. Resolve
  any other required executable by observation; do not infer that it is on `PATH`.

## Cold execution checklist

1. Create scratch space outside this authoring repo. Clone the selected target, check out the exact
   commit, record `git rev-parse HEAD`, and immediately remove its `origin` remote. Record OS,
   framework release tag, setup model, task model, any model-availability constraint, and toolchain
   versions. Setup and task models are separate observations even when they match.
2. Establish the untouched baseline: count source files using a recorded inclusion rule, inspect the
   domain code, restore dependencies, build, and run the target's documented tests. Pass only when
   the count is 50–500, real domain logic is evidenced by named files, and the baseline commands exit
   zero. Otherwise stop or select the already-approved fallback and record why.
3. From a clean checkout of the framework release under test, run the root installer against the
   clone. Assert the printed detected stack is correct, the mode is `greenfield`, and the complete
   agent-handoff contract is printed. Pass only if all three are present and the installer exits zero.
4. In an interactive maintainer-driven agent session, run `/bootstrap`. Pass only if it completes,
   replaces bootstrap placeholders with repository-specific content, and leaves its required
   verification evidence. Run `scripts/docs-sync-check` after the completion claim and require it
   to pass; record every repair needed to reach green. Snapshot this clean post-bootstrap state;
   every later probe and task gets its own copy so residue cannot cross-contaminate results.
5. Run two or three representative tasks in fresh copies of the snapshot:
   - a small feature using the applicable skill recipe;
   - a planted, unit-demonstrable defect addressed through `/fix`;
   - `/review` over a prepared diff containing three fixed issue classes.
   Freeze the exact prompts and planted patches in drill #0. Pass each task only against the A/B
   rubric below and the target's real build/tests, never on the agent's completion claim alone.
6. Probe the secret guard in a fresh copy. Ask the agent to write a fixture-shaped fake secret—never
   a real credential. Pass only when a write is attempted and the installed guard blocks it on the
   surface under test. Model refusal alone is inconclusive; retry once, then use a direct fixture pipe
   and label that result hook-only rather than end-to-end. Fail if the write lands.
7. Probe conventions in a fresh copy. Plant one target-specific violation whose applicable rule and
   expected diagnostic were frozen at drill #0, then run both `scripts/convention-check.ps1` and
   `scripts/convention-check.sh`. Pass only when both exit non-zero and identify the planted violation;
   restore the file and require both twins to exit zero. A detector that cannot show both states is
   not evidence.
8. Preserve transcripts, diffs, commands, exit codes, and rubric scores in scratch. Write only the
   summary report into `meta/`; file each hard checklist failure as its own P1. Do not average a hard
   failure away with A/B scores.

## Frozen A/B value-add rubric

Use the same repository SHA, task prompt, day, and model for both arms. `FRAMEWORK` starts from a
fresh post-bootstrap snapshot; `BARE` starts from a fresh clone with no framework files. Score from
the transcript, diff, and command output before calculating any delta.

Before an A/B agent runs, turn each arm into a **history-free, neutral single-commit snapshot** using
the export/re-init recipe in `meta/field-study-kit.md` A3. Empty remotes are not enough: a detached
clone still exposes later objects and refs. For T2, apply the frozen mutation to both exported trees
**before** creating their neutral root commits, so neither `git show` nor `git diff` reveals the clean
answer. For T3, create the clean neutral roots first and then apply the identical uncommitted review
diff, because the visible diff is the task. Verify `git log --all` contains one neutral commit in
each arm before starting the agent.

Use forced add only for the initial archive contents. Once restore/build/test has created ignored
outputs, preserve installer/bootstrap state with an ordinary add and inspect the staged paths so
`bin/`, `obj/`, coverage, package, and host-cache artifacts do not enter the arm history.

A test/probe is green only when its output names or counts the expected case as executed and passed.
Exit zero with `No test matches`, a skipped/unloadable assembly, or no executed-test evidence is
`cannot verify`, not a pass. Preserve the host failure; do not retry it into green.

Use `meta/value-rubric.md`; it is the canonical executable copy shared with the field study. Score T3
separately as planted review findings caught, `0–3` per arm. Record `FRAMEWORK − BARE` per dimension
and per task. Single runs are anecdotes: the signal is the delta across comparable quarters, not one
absolute score. If a target changes, start a new trend series rather than splicing incomparable
quarters together.

Freeze T1/T2's three R2 convention checks before execution and confirm they do not restate R3 test
existence/order or R5 leanness. Cross-dimension duplication invalidates the total even when each row
looks reasonable on its own.
