# B-142 decision — cross-file numbered-rule citations

## Decision: do not implement

All current citations still resolve, but extending check 12 with the proposed range resolver would
not detect B-142's named failure mode. The item asks for a red test that inserts a rule mid-list and
expects downstream citations to fail. Inserting a numbered rule shifts meanings while every old
number remains inside the valid range; a range resolver necessarily stays green. Shipping that
check would add parser and twin maintenance while supplying false confidence.

## Current-tree verification

Command: for each composed dist, read every non-CHANGELOG shipped file with explicit UTF-8, extract
the four citation grammars, and resolve them against the composed carrier's observed ranges:
Verification Rules 1–11, Leanness 1–16, Test leanness 11–16, Agentic Workflow 1–6.

Observed:

```text
dotnet CITATIONS=51 UNRESOLVED=0
angular CITATIONS=52 UNRESOLVED=0
monorepo CITATIONS=58 UNRESOLVED=0
```

This re-verifies the no-live-defect claim after the v0.59.0/v0.60.0 rule changes.

## Cost and proportionality

Check 12 currently reads a bounded set of Markdown workflow files once, blanks fences, and performs
file-local label/reference checks. The proposed extension would need to parse named subsections from
the composed carrier, scan additional file types and scopes (hooks, README/docs, YAML evals), avoid
historical CHANGELOG text, keep four citation aliases distinct, add vacuity/ambiguity fixtures, and
duplicate all behavior in PowerShell and shell. That is already comparable to or larger than check
12, not a near-free reuse.

More importantly, that cost buys only existence/range checking, which catches a typo such as
`Verification Rule #99`; it does not catch silent semantic repointing after insertion. Detecting the
actual defect requires stable rule identities or binding each citation to expected rule text/a
registry. That is a materially larger canonicalization design, disproportionate to hypothetical
harm with no live defect.

The constructible success world for the proposed range measure is a citation outside the current
range. The constructible B-142 defect world — insert a rule at position N and renumber later rules —
does not make the measure fail. Therefore the requested red test is unreachable under the proposed
mechanism, and Maintenance model rule 4 makes the experiment void before implementation.

No B-142 code or tests were changed. No PowerShell 5.1 leg applies because nothing was implemented;
5.1 was not observed.
