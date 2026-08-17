# Quarterly live-fire drill kit

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
   framework release tag, agent/model versions, and toolchain versions.
2. Establish the untouched baseline: count source files using a recorded inclusion rule, inspect the
   domain code, restore dependencies, build, and run the target's documented tests. Pass only when
   the count is 50–500, real domain logic is evidenced by named files, and the baseline commands exit
   zero. Otherwise stop or select the already-approved fallback and record why.
3. From a clean checkout of the framework release under test, run the root installer against the
   clone. Assert the printed detected stack is correct, the mode is `greenfield`, and the complete
   agent-handoff contract is printed. Pass only if all three are present and the installer exits zero.
4. In an interactive maintainer-driven agent session, run `/bootstrap`. Pass only if it completes,
   replaces bootstrap placeholders with repository-specific content, and leaves its required
   verification evidence. Snapshot this clean post-bootstrap state; every later probe and task gets
   its own copy so residue cannot cross-contaminate results.
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

| Dimension | 2 | 1 | 0 |
|---|---|---|---|
| Hallucinated APIs referenced | None in the final diff, verified by build and targeted inspection | Exactly one, self-corrected before completion | Any unresolved reference, or more than one |
| Convention adherence | All three target-specific checks pass | Two of three pass | Fewer than two pass |
| Test written before fix | Regression test is shown failing before the fix, then passing | Test exists but was not shown failing first | No regression test |
| Verification evidence shown | Relevant build/tests shown before the completion claim; gaps stated honestly | Partial relevant evidence | Completion claimed without relevant evidence |
| Review findings caught | All three frozen planted findings caught | Two caught | Zero or one caught |

Record `FRAMEWORK − BARE` per dimension and per task. Single runs are anecdotes: the signal is the
delta across comparable quarters, not one absolute score. Keep this wording and scoring frozen; if a
target changes, start a new trend series rather than splicing incomparable quarters together.
