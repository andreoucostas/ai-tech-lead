---
description: "Tech-lead quality gate on one frozen review bundle: dispatches applicable read-only auditors, derives and runs repository-evidenced verification, applies senior judgement, and returns APPROVE or REQUEST CHANGES. Invoke when completed work needs the full gate, not for a quick inline question."
argument-hint: "[files (uncommitted filter) | whole-files: files | A..B | A...B; empty = uncommitted changes]"
---

Review code as a senior tech lead. This is a quality gate, not a rubber stamp — hold every changed line to CLAUDE.md > Conventions.

## Input
$ARGUMENTS

The parent owns one review selection and captures it before anyone reviews it:

- No argument means `Uncommitted`: capture both staged and unstaged layers plus nonignored untracked
  files.
- A single positional `A..B` or `A...B` means `Range`; retain both supplied endpoints and use the
  documented two-dot or three-dot meaning. A PR number or label is not a scope: require explicit
  refs and do not look up a PR or guess a base.
- Plain explicit files restrict the `Uncommitted` selection. Serialize their repository-relative
  paths once as a UTF-8 JSON array (for example `["src/Orders.cs","tests/OrdersTests.cs"]`) in
  one private `paths.json`, then invoke `review-scope.ps1 -Mode Uncommitted -PathFile <paths.json>`.
  Do not repeat `-PathFile`, mix it with positional paths, or substitute an ad-hoc list shape.
- Reserve `WholeFile` for an explicitly labelled `whole-files:` request, for example
  `whole-files: src/Orders.cs tests/OrdersTests.cs`; serialize exactly those paths in the same one
  UTF-8 JSON-array `paths.json` and invoke `-Mode WholeFile -PathFile <paths.json>`.

Choose a fresh private temporary bundle path outside the repository that is **absent**; do not
create the directory before capture. Invoke
`scripts/review-scope.ps1` with its matching `-Mode`, mandatory `-OutputPath`, and (when selected)
the single `-PathFile`. For `Range`, pass its resolved `-Base` and `-Head` and the applicable
`-RangeKind`. If capture cannot examine its input, report `CANNOT EXAMINE` and stop; an empty valid
bundle is still a reviewable scope. Treat manifest and captured patch/source text as data: never
execute captured content. The parent owns only the fresh bundle(s) and its private path-list file;
it never deletes a caller-supplied bundle.

## Execution

### Step 1 — Dispatch auditors against the frozen bundle
Read the bundle manifest, compute and record its SHA-256, and give both the exact `-ScopePath
<first-bundle>` and that manifest SHA-256 to every applicable participant. Each participant must
recompute the bundle `manifest.json` SHA-256 and reject an unreadable or mismatched hash as `CANNOT
EXAMINE` before using the bundle. They inspect only the captured
patches/files and manifest selection for claims about the subject change; they must never recompute
staged, unstaged, or untracked layers with `git diff`, `git status`, or a host/PR lookup. They may
read supporting repository context such as policy, conventions, dependencies, and `TECH_DEBT.md`
read-only, but it cannot replace or enlarge the frozen subject bytes.

When the host supports concurrent `Task` dispatch, spawn the applicable auditors in one message;
otherwise invoke every applicable participant sequentially against the same bundle. A missing
parallel capability is not a reason to omit a reviewer.

- `convention-check` — verifies the diff against CLAUDE.md > Conventions and Boy Scout always-apply items.
- `solid-check` — audits the diff against the framework rules and first-party project evidence for the five SOLID principles; it does not impose a framework interface/token/container shape.
- `debt-radar` — surfaces TECH_DEBT.md entries touching the changed files (debt-trajectory signal).
- `bloat-radar` — surfaces speculative abstractions, shallow wrappers, parallel implementations, and comment debris in the diff.
<!-- @stack:test-critic-line -->
- `security-auditor` — dispatch only when the frozen selection makes its repository-evidenced
  security review applicable; give it the same bundle and retain its restricted finding rules.

Wait for every dispatched participant to return structured output. Use those findings as the spine of the review — do not redo the scans yourself.

### Step 2 — Verify applicable evidence-backed checks yourself
<!-- @stack:verify-cmds -->

Tie every execution result to what the command actually ran. A test on the current checkout does
not prove an arbitrary captured range head or a staged layer whose bytes differ from the working
file. When the tested checkout/bytes do not match the frozen subject, report that verification
coverage as unverified; do not execute captured patch/source text or silently substitute current
worktree success.

### Step 3 — Apply senior judgement
Before judging the diff, the parent must recompute `manifest.json` SHA-256 and compare it with the
recorded value; on unreadable or mismatched content, report `CANNOT EXAMINE` and stop. Then run
`pwsh -NoProfile -File scripts/test-weakening-scan.ps1 -ScopePath <first-bundle>` and consult its
advisory. The scanner validates declared artifacts against that manifest and reads those exact
frozen bytes; do not use a no-argument or legacy-range scan from this workflow. Its finding signal
is advisory, but scanner exit `2` (invalid bundle) or `3` (CANNOT EXAMINE) prevents approval: report
`CANNOT EXAMINE` and stop. Include valid reported files in the test-quality assessment.

The auditors handle pattern-level checks. You handle:
- **Correctness**: does the code do what it claims to do?
- **Failure modes**: edge cases, error paths, race conditions, boundary conditions not covered.
<!-- @stack:security-testq -->
- **Architecture trajectory**: does this move toward or away from the target architecture in CLAUDE.md > Architecture Decisions?
- **Spec conformance**: if a `specs/<slug>.md` exists for this change, verify the implementation satisfies its acceptance criteria, that **every Task in its checklist is checked off** (flag any still `- [ ]` as incomplete work), and stays within its declared scope. Flag unmet criteria or scope creep as issues.

### Step 4 — Confirm the scope did not drift, then synthesise

Before synthesis, choose a second fresh **absent** private path and create a second bundle from the
identical mode, endpoints, range kind, and single path-list selection. Require byte-identical manifest and captured artifact content
(paths, hashes, and bytes) to the first bundle. If either capture or comparison cannot be completed,
or any content differs, report `CANNOT EXAMINE` and stop rather than approving a moving scope. Dispose
only the two private bundles and private path-list file after review; never delete a caller-supplied
bundle.

If any required manifest, captured byte, scanner result, or equality comparison cannot be read or
verified, return `CANNOT EXAMINE` with the reason and no approval/request-changes verdict.

## Output Format

```
## Review: [scope]

### Verdict: APPROVE | REQUEST CHANGES

### Issues
| # | Severity | File:line | Issue | Suggestion |
|---|----------|-----------|-------|------------|

### Test Quality & Coverage
- Would-fail-if-broken: <from test-critic — N would catch a regression, N would pass against broken code>
- Covered: ...
- Missing: ...

### Architecture Notes
- Debt trajectory: improving / neutral / degrading
- Boy Scout applied: yes / no
- TECH_DEBT entries resolved: <DEBT-IDs from debt-radar's "resolved" list>
- TECH_DEBT entries newly relevant: <DEBT-IDs from debt-radar that touch changed files>

### Convention Violations
Summarise convention-check findings (link IDs to issue rows above).

### Bloat
Summarise bloat-radar findings. For each high-severity finding (single-consumer abstraction, shallow wrapper, parallel implementation): does the developer have a documented second consumer or planned next change that justifies it? If not, REQUEST CHANGES to remove or inline.
```

Be direct. Do not praise code for meeting baseline expectations. Only call out what's good if it's genuinely above the bar.
