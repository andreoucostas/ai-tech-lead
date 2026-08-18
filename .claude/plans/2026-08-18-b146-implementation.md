# B-146 implementation report — 2026-08-18

## Outcome

**STOPPED on the required current-backlog check.** The drafted body/heading string check is red on
the current `meta/BACKLOG.md` under both PowerShell hosts. Per the task instruction, I did not
weaken the check and did not proceed to red-test-arm verification.

The assertion-position grammar also matches ordinary wrapped prose whenever a physical line happens
to begin with one of the requested words. Every current hit is below:

- B-55 — `shipped \`agentStop\`, **five** of those surfaces still asserted ...`
- B-64 — `done already requires red-testing for composer/gate scripts ...`
- B-70 — `shipped. Consider promoting that from a suggestion ...`
- B-83 — `shipped settings file" — was *already wrong when read* ...`
- B-83 — `shipped decision. It was caught only because ...`
- B-96 — `resolved each business key to the dimension version ...`
- B-96 — `rejected in the design; no whole-warehouse ...`
- B-100 — `> shipped BOM-less into all three dists. ...`
- B-112 — `shipped at all**, i.e. its measure may be saturated ...`
- B-132 — `**Done when:** the PS7 prerequisite is machine-enforced ...`
- B-133 — `**Rejected first design ...:** the initial plan ...`
- B-133 — `rejected the counter design materially improved this plan ...`
- B-134 — `implemented domain behavior from a repository ...`
- B-131 — `Rejected as disproportionate: no consumer requested ...`
- B-131 — `shipped notes as conditional. Record the locked choice ...`
- B-138 — `done: show the before/after wall-clock time ...`
- B-142 — `done inside check 12 for roughly the cost ...`
- B-18 — `rejected — keep it opt-in.`

These are findings about the proposed lexical specification, not evidence that all listed backlog
entries are complete. In particular, B-83 demonstrates that position at the start of a wrapped
Markdown line does not reliably mean “assertion position.” Deciding which of these phrases actually
closes an entry would cross the B-83 boundary into semantic judgement.

The decision-subject check was drafted with direct verb/id adjacency and was green against the
current last-200-subject window. That result is not reported as final verification because the task
requires stopping when Check A is not green.

## Observed host results

`pwsh -NoProfile -File .claude/hooks/tests/BacklogHygiene.Tests.ps1`

```text
[ok] open backlog headings contain no completed records
[ok] PARTIALLY DONE headings remain valid open records
[FAIL] open backlog bodies contain no assertion-position completion markers -- completion marker in body disagrees with open heading B-55: shipped `agentStop`, **five** of those surfaces still asserted "Copilot has no equivalent event", and
[ok] PARTIALLY DONE and STILL OPEN bodies remain valid open records
[ok] a body discussing a quoted completion marker is not a completion assertion
[ok] recent commit decisions name no ids that remain open in the backlog
[ok] archive pointers resolve to archived ids
[ok] decision-index sources and quoted phrases resolve
BacklogHygiene.Tests: 7 passed, 1 failed, 0 skipped
```

Exit code: `1`.

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/tests/BacklogHygiene.Tests.ps1`
produced the same eight case lines and summary:

```text
BacklogHygiene.Tests: 7 passed, 1 failed, 0 skipped
```

Exit code: `1`.

## Required verification not performed

- Clean green under either host: **not observed**; both were red as shown.
- The six existing `-RedTest` arms: **not run after the stop condition**.
- The drafted `body-heading-disagreement` and `decision-outside-backlog` arms: **not run after the
  stop condition**.
- The drafted vacuity arms: **not run after the stop condition**.
- Assertions shown failing through mutation: **none**. No mutation run was begun, so no claim is
  made that a mutation changed its subject.

The `.ps1` retained its UTF-8 BOM. No machine-local absolute path is recorded in this report.
