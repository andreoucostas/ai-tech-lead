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
