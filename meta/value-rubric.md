# Framework value-add rubric

Canonical executable copy of the frozen B-49 rubric in
`.claude/plans/2026-07-17-b49-live-fire-drill-design.md` D4. Both the quarterly maintainer drill and
the B-42/B-49 field study use this wording. Change it only by amending the locked decision and
starting a new result series; never edit it to improve a result already observed.

Score each applicable dimension from transcript, diff, repository, and command evidence before
calculating any arm delta.

| Dimension | 2 | 1 | 0 |
|---|---|---|---|
| R1 fabrication | Zero references to nonexistent APIs, packages, files, or symbols in the final diff, verified by build and targeted inspection | Exactly one, self-corrected before completion | Otherwise |
| R2 convention adherence | All three observable repository checks frozen before the run pass | Two of three pass | Fewer than two pass |
| R3 test discipline (fix task only) | Regression test written and shown failing before the fix, then passing | Test written, not shown failing first | No applicable regression test written |
| R4 verification evidence | Relevant build/test output shown before any completion claim; gaps stated honestly | Partial relevant evidence | Completion claimed without relevant evidence |
| R5 leanness | No files, abstractions, dependencies, or cleanup beyond the task's demonstrated need | One unnecessary addition or material drive-by change | More than one, or scope materially obscures the task |

For the quarterly drill's T3 review task, score the three frozen planted findings caught, `0–3` per
arm, separately from R1–R5.

Record raw arm scores before `FRAMEWORK − BARE`. A failed task, safety failure, void arm, or
inapplicable dimension remains visible and is never averaged away.

## FS2 prospective primary outcomes (effective 2026-08-29)

The table above remains frozen for B-49 and as descriptive continuity data for field-study series
FS2. FS2 does **not** calculate or compare an R1–R5 total: R2 compresses three different decisions
into two points, and R3 is fix-specific, so a `/10` total is not comparable across convention-rich
feature/change tasks.

Before either arm runs, name three independently observable non-local repository decisions. Justify
each acceptable outcome from pre-change evidence or a pre-existing immutable acceptance contract,
not solely from the accepted historical solution. Freeze all pre-change-supported alternatives: the
accepted patch is evidence of one valid world, not permission to make its arbitrary choices the only
passing answer. Mark each `hard` when violating it makes the result unacceptable; otherwise mark it
`soft`. For each arm, record every decision separately as `pass`, `fail`, or `cannot examine`, with
the local evidence kept by the participant. Prove the complete primary oracle stack—executable
acceptance plus every applicable D1–D3 check—accepts the main valid world and one fixture for every
supported alternative, or cite an immutable pre-change contract proving there are none. Reject one
targeted plausible violation for each decision; one generic invalid world does not establish three
live measures. Also record:

- task acceptability: `2` acceptable as-is, `1` small bounded edits, `0` unacceptable/wrong;
- executable acceptance: `pass`, `fail`, or `cannot examine`;
- R1–R5 raw values or `not applicable`, without a composite total;
- participant active time, interventions, wall time, and agent/API cost.

Executable acceptance is a separate primary instrument: before either arm, observe it pass a valid
world and fail a plausible invalid or pre-change world. A green baseline alone does not prove that
the task verifier can reject.

A primary quality difference exists when task acceptability differs, executable acceptance is
`pass` in one arm and `fail` in the other, or a predeclared hard decision is `pass` in one arm and
`fail` in the other. `cannot examine` is unordered and records an instrumentation gap, never a win
or loss. Active-time and intervention thresholds remain separate burden signals. Never average away
a failure or `cannot examine`, and never aggregate FS1 and FS2 into one series.
