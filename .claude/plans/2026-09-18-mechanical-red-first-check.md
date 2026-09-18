# Mechanical red-first check — replace personally-recorded hostile evidence with a checker

**Class:** mechanism (new `.ps1`; root `AGENTS.md` rule text; new test cases in an existing-vs-new
suite file, decided below). Must not become critical — no edit touches `.github/workflows/ci.yml`,
`.claude/scripts/release.ps1`, `.claude/scripts/check-outgoing-commits.ps1`,
`.claude/scripts/push-and-check.ps1`, `scripts/build.ps1`, `install.ps1`, `src/`, `dist/`, or any
records file.

**Constraints read:** `meta/decisions-index.md` (in full); WSD-028 (a gate can expose evidence or its
absence, never certify independence or quality); WSD-034 (proportionality lives inside the pre-lock
critique, not a separate gate); WSD-057 (independent review is evidence-bound not rank-bound;
historic decisions are rebuttable defaults, re-open only when a changed condition could alter the
outcome); WSD-089 (root `AGENTS.md` is canonical, ceilings 200 lines / 19,500 LF-bytes gated by
DocTruth, ceremony follows change class, renumbering existing Maintenance-model rules is forbidden
because `release.ps1`, `DEVELOPING.md` and locked plans cite them by number — WSD-034's own
"Rejected" paragraph). Also read: the B-237 plan and commit (`651be294`), `_HookHarness.ps1`,
`Invoke-HookTests.ps1`, `ReleaseCiWatch.Tests.ps1`, `DocTruth.Tests.ps1`'s ceiling check, and the
`meta-gates`/`meta-review-handoff`/`meta-release` skills.

## Premise re-validation (observed at source, 2026-09-18)

- B-237 (`.claude/plans/2026-09-18-b237-tag-the-watched-commit.md`, commit `651be294`) is real and
  current: `git show --stat 651be294 -- .claude/scripts/release.ps1` shows **1 file changed, 4
  insertions(+), 1 deletion(-)** — a single-hunk, single-line functional fix (the rest is a comment).
  Its own plan says plainly: *"An orthogonal second vantage (maintenance model #2) for this
  false-green class is not available inside this session; ... recorded as review debt"* — folded
  into B-239 per the commit message. That is the exact ceremony/value gap the user is asking to close.
- `.claude/hooks/tests/_HookHarness.ps1`'s `Write-TestSummary` emits exactly `[ok] <name>`,
  `[FAIL] <name> -- <msg>`, `[skip] <name> -- <why>` per case, and `Invoke-HookTests.ps1`'s exit code
  is a **summed failing-case count** (confirmed by reading both files) — the exit-domain collision
  the checker must not fall into.
- Grepped the whole `.claude/hooks/tests/` suite for `orthogonal|review debt|rank-bound|RCA`: the two
  hits are historical comments (`v0.41.0 RCA`) in unrelated files, not assertions on `AGENTS.md`
  prose. No existing gate hardcodes the Maintenance-model wording this plan changes — only
  `DocTruth.Tests.ps1`'s structural checks (banner, import, line/byte ceilings, `## Status` pointers)
  apply, and none of them touch the sentences being edited. The wording edits are gate-safe.
- Measured `AGENTS.md` today: 196 lines / 16,554 LF-normalised UTF-8 bytes (`DocTruth`'s own
  method: `TrimEnd("\n") -split "\n"` for lines, `[Text.Encoding]::UTF8.GetByteCount` for bytes).
  Ceiling is 200 / 19,500.

## Observed harm (why this, not something smaller)

B-237's own record names the harm precisely: a critical-class change produced a 75-line plan, a
separate critique session, ~100 lines of tests, full two-host + CP437 gates, two ~10-minute CI waits,
an RCA obligation and a new backlog stub — and still **skipped the one step the whole ceremony
exists for** (an independent session watching the new tests fail pre-fix), parking it as debt inside
an unrelated entry (B-239). The ceremony is not hypothetically disproportionate; it already failed to
deliver its own central claim once, concretely, on this exact class of change.

## Proportionality (#6) — two smaller alternatives weighed and rejected

- **AGENTS.md wording only, no script.** Just deleting the orthogonal-vantage/review-debt sentence and
  letting "one release-specific hostile case... observed red" stay purely personal removes ceremony
  but removes the ONE thing in the old rule that was independently checkable — the reviewer's claim to
  have watched it fail becomes exactly as unverifiable as before (WSD-028/057's whole complaint).
  Cheaper, but it is the wrong cut: it deletes the evidence, not the ceremony around it.
- **Script only, no rule change.** A tool nobody is required to run, with the old wording still
  demanding a personally-recorded hostile case, changes nothing — B-237's exact failure mode (the step
  gets silently skipped under time pressure) recurs. Ceremony is a rule problem; a script without a
  rule change is decoration.
- **Chosen:** both together. The script makes "observed red" a fact `release.ps1`'s evidence string
  can name and anyone can re-run (`RED_FIRST PASS`, exit 0), and the rule change spends the freed
  trust budget on dropping the orthogonal-vantage/review-debt/blanket-RCA ceremony that was never
  machine-checked in the first place and, per B-237, wasn't reliably done by hand either.

## Critique (non-implementer, 2026-09-18)

Separate read-only Claude Opus session, from the phase-1 plan and this repo's source (not from my
narrative). Verdict: **REVISE** — premise and the four directions accepted; seven required fixes (R1–R7)
and six optional items (O1–O6). Coordinator's dispositions and what I re-verified at source, below.

- **R1 (name parsing).** Verified: `ReleaseGateWaiver.Tests.ps1` (×2), `DocTruth.Tests.ps1`,
  `ReleaseDistGateTiming.Tests.ps1` each declare a case name containing literal `" -- "` (grepped
  directly). Splitting on the first `" -- "` would truncate them. **Fixed**: `Resolve-Mark` matches
  the full declared name as an anchored, `[regex]::Escape`d literal (`^\[(ok|FAIL|skip)\] <name>(?: -- .*)?$`)
  and requires exactly one match per tree; zero or several → `CANNOT_EXAMINE`. Closes duplicate names
  too (test: "a duplicate case name is refused as ambiguous").
- **R2 (no `-File` on shipped runners).** Verified: `src/core/tests/hooks/Invoke-HookTests.ps1` and
  every `dist/*/tests/hooks/Invoke-HookTests.ps1` declare only `[switch]$FixtureDiscovery,
  [string]$CaseCountPath` — no `-File`. **Fixed**: the script now runs each declared file directly
  (`& $hostExe -File <clone>/<file>`), exactly what the root runner does internally at
  `Invoke-HookTests.ps1:195`. This also removed the runner-overlay/manifest-drift concern entirely.
- **R3 (red for the wrong reason).** Verified: `_HookHarness.ps1`'s `It` catches every exception
  identically. **Fixed both ways**: (a) the parent-side matched line for every declared case is
  always printed (`-- parent-side result...` block), even on `PASS`; (b) a liveness control requires
  at least one non-declared case to be `[ok]` on the parent for that file, else `CANNOT_EXAMINE`. My
  own suite's control case ("the fixture builds a linear four-commit history...") never calls the
  subject, so it stays `[ok]` on a parent where `assert-red-first.ps1` doesn't exist yet — the
  dogfood liveness anchor R3 asked for.
- **R4 (unparsable trailer).** Implemented exactly as specified: split on `\r?\n`, trim, a
  case-insensitive `red-first` substring that doesn't match `^(?i)red-first\s*:\s*(.+)$` or lacks a
  `::` separator refuses, quoting the line. Test: "an unparsable Red-first-like trailer line is
  refused, quoting it".
- **R5 (path-keyed residue).** Restored a narrowed second-vantage requirement to the critical row for
  `install.ps1` ownership/protected/retirement/legal blocks specifically (exact text in Design §C
  below); the "review debt" escape is removed everywhere, matching the coordinator's note that this
  narrows the user's direction 3 and will be put to the user at sign-off.
- **R6 (`reviewer user` not agent-claimable).** Maintenance model #2 now says the user's own
  reviewed, approved diff qualifies — a session cannot record this on the user's behalf. Paid for
  with the words: cut the B-237 parenthetical (`4 insertions, 1 deletion`) from class rule 6.
- **R7 (WSD ships with the rule).** No records file touched here (still out of my boundary); the
  coordinator writes the WSD, `decisions-index.md` and backlog edits into the same master commit at
  integration. **Finding recorded** (see Findings): this WSD amends WSD-089's decision point 3
  (mechanism/critical ceremony) mid-way through WSD-089's own 2026-09-30 success-measure window: any
  read of that measure after this change lands should be evaluated against the RULES IN FORCE AT THE
  TIME of each measured release, not retroactively against the amended text.
- **O1 (size bound, coordinator override).** Rule 6's bound is **≤10 insertions+deletions in the
  subject `.ps1` alone, recomputable from `git show --stat`**, not counting accompanying tests —
  overriding my ≤5 proposal, because 5 pressures dropping the explanatory comment B-237's real fix
  included (4 code + 1 comment insertion... object actually 4 insertions/1 deletion total, but the
  point holds generally). Recorded as the user's open number to ratify at sign-off.
- **O2 (new file, price paid).** Critic agreed with keeping cases in a new file. Manifest diff and
  `TIMING` line are in the Delivery section below.
- **O3 (temp clone, not `git archive`).** Verified: 16 of the 36 `.claude/hooks/tests/*.Tests.ps1`
  files shell out to `git`, and several (`DocTruth.Tests.ps1:91`, `RepositoryPrivacy.Tests.ps1:36`)
  compute their own `$repoRoot` from `$PSScriptRoot` and run real `git` commands against it — a bare
  `git archive` export has no `.git` there at all. **Fixed**: one `git clone --no-hardlinks` per run,
  `checkout --detach --force` to the parent then the commit in sequence (one clone, reused — simpler,
  half the disk). Only the temp clone is ever checked out; `git rev-parse`/`log`/`ls-tree` against the
  real `$RepoRoot` stay read-only throughout, verified by inspecting every git subcommand in the
  finished script.
- **O4 (200/200 margin).** Tightened Maintenance model #1's re-audit sentence (it restated WSD-057
  almost verbatim) — exact before/after in Design §C. Did not need the DEVELOPING.md-recipe trade
  from phase 1 either way. Final measured: **198 lines / 16,831 bytes** (DocTruth's own method).
- **O5 (release.ps1 stays stale).** Recorded as a finding, not fixed (forbidden file).
- **O6 (the inversion).** Recorded as a known limitation, no rule text added: rule 6 only fires on
  `assert-red-first.ps1 exit 0`, which a message-text-only edit to a critical `.ps1` can never
  produce (nothing to observe red), so the cheapest edits stay at the most expensive ceremony.

## Design

### A. `.claude/scripts/assert-red-first.ps1`

**As shipped (post-critique; see R1–R4, O3 above for why this differs from the phase-1 draft).**
Params: `-Commit <rev> = 'HEAD'`, `-RepoRoot <path>` (default: two levels up from `$PSScriptRoot`),
`-Case <string[]>` (repeatable; exclusive alternative to trailers). Steps, as implemented in
`.claude/scripts/assert-red-first.ps1` (read there for the exact code):
1. Resolve `$Commit` to a full sha and its parent via `git rev-parse`; either failure → `CANNOT_EXAMINE`
   (root commit / shallow clone worded as one case, per O3's shallow-source note).
2. Parse declared cases from `-Case` or, failing that, `Red-first:` trailers (R4's strict parse, one
   line at a time, refusing any line that mentions "red-first" but doesn't fit the grammar). Zero
   declared → `CANNOT_EXAMINE`.
3. `git clone --no-hardlinks --quiet` the real `$RepoRoot` into an isolated temp dir (O3) — the only
   `checkout` in the whole script happens against this clone, never the caller's own tree/index.
4. Check out the parent (`--detach --force`), then for each declared directory `git checkout $sha --
   <dir>` (overlays that directory with the commit's version) and remove any path present at the
   parent's `ls-tree` for that directory but absent at the commit's (mirrors deletions). Run every
   declared file directly (`& $hostExe -File <clone>/<file>`, R2) and capture stdout, LF-normalised
   (Windows joins captured lines with CRLF, which defeats a `(?m)^...$` anchor otherwise).
5. Check out the commit (`--detach --force`) and run every declared file again.
6. Liveness (R3b): for each declared file, at least one *non-declared* case must be `[ok]` on the
   parent output, else `CANNOT_EXAMINE` naming the file.
7. Exact-match resolution (R1): for each declared case, an anchored, escaped-literal regex against
   both outputs; zero or >1 matches on either side → `CANNOT_EXAMINE` (not-found / ambiguous-duplicate).
   `skip` on either side → `CANNOT_EXAMINE`.
8. Verdict: `PASS` only if every declared case is `FAIL` on the parent and `ok` on the commit;
   otherwise `WRONG`, naming every offending case and which side failed. The parent-side matched line
   for every declared case is always printed (R3a), even on `PASS`.
9. Final stdout line always: `RED_FIRST <PASS|WRONG|CANNOT_EXAMINE> declared=<n> red_on_parent=<m>
   green_on_commit=<k>`. A `finally` removes the temp clone on every path, including failure.

Two PS5.1-only defects found by running the tests, not by inspection, and fixed in the shipped
script (see Delivery): Windows PowerShell wraps a redirected native child's stderr lines into
promotable `ErrorRecord`s, which `$ErrorActionPreference='Stop'` turns into a terminating exception
for an *ordinary* git failure (bad parent, etc.) or a clean subprocess run — every native `git`/host
invocation now drops to `'Continue'` for just that call. `$PSNativeCommandUseErrorActionPreference`
is explicitly set `$false` for the unrelated PS7.4+ non-zero-exit-promotion mechanism. UTF-8 BOM
verified on both new files by reading the first three bytes back (Delivery), not assumed.

### B. Tests

**Where.** A **new** file, `.claude/hooks/tests/AssertRedFirst.Tests.ps1`, not cases folded into an
existing one. I checked the fit against every candidate whose subject touches git/release mechanics
(`OutgoingCommits`, `ReleaseCiWatch`, `ReleaseStagingGuard`, `ReleaseGateWaiver`,
`ReleaseChangelogStamp`, `PushAndCheck`) — every one of them opens with a one-line `Subject:` naming
one existing script, and none of their subjects is this one. `assert-red-first.ps1` is a standalone,
freestanding tool with its own concerns (tree export, overlay reconciliation, exit-domain-safe
parsing); folding ~6 new scratch-git-repo-heavy cases for a *different* script into any of those
files would misstate that file's stated subject for the sake of avoiding two lines of ceremony. Class
rule 2's price for a new file is small and one-time: the `$expectedTestFiles` diff (insert
`'AssertRedFirst.Tests.ps1'` alphabetically between `AdoptionArchiveIntegrity...` and
`B215OwnershipBoundary...`) and quoting the runner's `TIMING AssertRedFirst.Tests.ps1 <n>` line —
both captured in phase 2, not asserted here. **Flagging this for the critique**, since the task's own
framing leaned toward reuse.

**Fixture (hermetic, no dependency on this repo's history).** Build a scratch git repo in temp with a
*stub* runner and harness — not a copy of the real ones — because `assert-red-first.ps1`'s contract
depends on exactly three properties: `[ok]/[FAIL]/[skip] <name>` lines on stdout and exit code =
failing-case count (R2 dropped the need for a `-File`-capable stub entirely — files run directly).
Linear four-commit history (as shipped; R4/R1/R3b added commits C and D and two more cases beyond
the phase-1 draft):
- **A "base"**: `.claude/hooks/tests/_Stub.ps1` + `Sample.Tests.ps1` with one always-passing case
  ("the baseline case is unaffected") — root commit, no parent.
- **B "feature"**: adds `feature.ps1` at the repo root; `Sample.Tests.ps1` gains "the feature returns
  the documented value" (genuine, throws on A), "...under load" (superstring name, trivially passes
  both trees — planted inert / R1's name-anchoring probe), "an UNWAIVED failure still blocks -- the
  mechanism must not fail open by default" (genuine, name containing `" -- "` — R1), "an unrelated
  case that always fails" (exit-domain collision), and "the shared outcome" registered **twice**
  (duplicate-name probe — R1); `OnlyDeclared.Tests.ps1` (one genuine case, nothing else — R3b's
  liveness probe). Message carries a valid `Red-first:` trailer for the genuine case.
- **C "malformed trailer"**: trivial follow-up; message contains `red-first oops no colon or case
  name` (mentions "red-first", doesn't parse — R4).
- **D "no trailer"**: `--allow-empty`; message says nothing about red-first at all.

**Cases, each observed red before being trusted (see Delivery for the actual red/green transcripts
under both hosts):**
1. Control: the fixture itself builds 4 distinct commit shas — never calls the subject, so it stays
   `[ok]` on a parent where `assert-red-first.ps1` doesn't exist (R3b's dogfood liveness anchor).
2. Genuine red-first via the commit-B trailer → `PASS`; asserts the parent-side `[FAIL]` line is
   printed verbatim (R3a).
3. The `" -- "`-named case via `-Case` → `PASS` (R1's anchoring, not splitting).
4. The planted inert case → `WRONG`, naming it "passed on the parent (inert, not red-first)".
5. Declaring only the genuine case, with the always-failing case present → still `PASS` (exit-domain
   collision: the wrapped file's own exit code is non-zero on both trees throughout this suite).
6. The duplicate-named case → `CANNOT_EXAMINE`, "ambiguous (duplicate case name?)".
7. `OnlyDeclared.Tests.ps1`'s sole case declared alone → `CANNOT_EXAMINE`, liveness refusal.
8. A made-up case name → `CANNOT_EXAMINE`, not-found.
9. Commit C (malformed trailer) → `CANNOT_EXAMINE`, quoting the offending line.
10. Commit D (no trailer, no `-Case`) → `CANNOT_EXAMINE`.
11. Commit A (root, no parent) → `CANNOT_EXAMINE`.
All 11 were run with the subject script renamed away first (real red: PowerShell's own "term not
recognized", exit 64/−196608 per host) before the script was written, then iterated to green — see
Delivery for both transcripts and the two real PS5.1-only defects that observation caught.

**One-off observation against real history (executed, not merely planned — see Delivery for the
verbatim `RED_FIRST` lines and parent-side messages under both hosts):**
```
& '.claude/scripts/assert-red-first.ps1' -Commit 651be294 -Case '<hostile case 1>','<hostile case 2>'
# RED_FIRST PASS declared=2 red_on_parent=2 green_on_commit=2, EXIT=0
& '.claude/scripts/assert-red-first.ps1' -Commit 651be294 -Case '<control case>'
# RED_FIRST WRONG (green on parent too -- correctly inert), EXIT=1
```
Note on invocation form: `pwsh.exe -File script.ps1 -Case a -Case b` (repeating the flag, or an
array literal exploded across native argv) is refused by the host's own CLI-level binder
("specified more than once") — a genuine PowerShell limitation independent of this script. The
working form is a single comma-joined array literal in the calling expression: `-Case 'a','b'`.

### C. Root `AGENTS.md` amendments

All edits keep every other rule's text and numbering intact — WSD-034's "Rejected" paragraph is
explicit that rules 2–4 of the Maintenance model are cited by number elsewhere, so nothing is
renumbered; the new class-rule is appended as **6**, matching how WSD-034 itself appended rule 6
rather than reordering.

**C1 — Change-class table, mechanism row.** Drop the trailing `→ RCA` (RCA is now scoped globally by
class rule 5, not hard-required per mechanism delivery) and record that exemption in "Not required":
```diff
- ... → full local gates → release with #2 evidence → RCA | second reviewer, multi-round critique, a new test *file* unless rule 2 below |
+ ... → full local gates → release with #2 evidence | second reviewer, multi-round critique, RCA unless a defect escaped, a new test *file* unless rule 2 below |
```

**C2 — Change-class table, critical row.** Drop the orthogonal-vantage addendum (direction 3):
```diff
- Maintenance model 1–7 in full plus the orthogonal second vantage (#2)
+ Maintenance model 1–7 in full; `install.ps1` ownership/protected/retirement/legal blocks
+ additionally need a second orthogonal reviewer or execution vantage
```
R5 restored a narrowed, path-keyed version of the requirement direction 3 dropped outright: the
critic (and WSD-057's own "Rejected" paragraph, still live) found the second vantage disproportionate
on B-237's *tiny* fix, not valueless on the installer's deletion authority — the highest-harm path
in the whole class table. The "review debt" escape is gone everywhere regardless.

**C3 — New class rule 6** (the size+path reduction, direction 2; size bound per O1's override),
appended after existing rule 5:
```
6. A fix to `scripts/build.ps1`, `.claude/scripts/release.ps1`, or `check-outgoing-commits.ps1` of at
   most 10 insertions+deletions in that file alone (recomputable from `git show --stat`; its
   accompanying tests do not count) takes the mechanism row, not critical, when
   `assert-red-first.ps1` exits 0 against the commit. Never applies to `install.ps1`
   protected/retirement/legal blocks, `scripts/meta-denylist.txt`, or `ci.yml`.
```
The phase-1 draft proposed ≤5 (B-237's exact diff) and cited the diff parenthetically; the coordinator
overrode to ≤10 (a 5-line comment-only budget on top of a 5-line fix) per O1, and R6 required cutting
the B-237 citation since a bound tied to one historical number reads as if the rule certifies that
specific commit rather than a general size test — the number itself is recomputable and self-evident
from `git show --stat`, so the citation added nothing the rule text didn't already state. Still
deliberately does not exclude `anything data-loss/security/false-green` as a class, since B-237 *was*
exactly that and is the case this rule exists to demote (O1/R5 discussion, unchanged from phase 1).
The user is expected to ratify or adjust the ≤10 number at sign-off (O1).

**C4 — Class rule 5** (RCA scope, direction 3):
```diff
- 5. Maintenance model #5 applies to mechanism and critical, and to any class in which a defect escaped.
+ 5. Maintenance model #5 (RCA) applies only where a defect escaped, in any class.
```

**C5 — Maintenance model #2** (mechanical evidence + user-review-counts-for-mechanism, directions 1
and 4; drops the orthogonal-vantage/review-debt sentence, direction 3):
```diff
- 2. **Independent review is evidence-bound, not rank-bound** (WSD-057; prose is exempt per WSD-089).
-    The reviewer uses a separate session, did not participate in implementation, starts from the
-    frozen contract and immutable range before reading the implementer's narrative, forms an
-    independent threat model, and records model/agent, environment, one release-specific hostile case
-    or applied mutation observed red, a clean rerun, and coverage gaps. Prefer another model family,
-    host or toolchain; rank alone neither qualifies nor disqualifies. Data-loss, security-bypass and
-    false-green changes need a second orthogonal reviewer or execution vantage, else record the gap as
-    review debt. Review scope too: every changed function is required by the contract, or justified.
-    Windows is the sole platform leg; direct PS7 and PS5.1 runs are separate required legs and neither
-    may relaunch the other.
+ 2. **Independent review is evidence-bound, not rank-bound** (WSD-057; records and prose are exempt per
+    WSD-089). The reviewer uses a separate session, did not implement the change, and starts from the
+    frozen contract and immutable range before reading the implementer's narrative. A change carrying a
+    commit `Red-first:` trailer records `assert-red-first.ps1`'s `RED_FIRST PASS` line as its
+    hostile-case evidence; otherwise the reviewer personally records one release-specific hostile case
+    or applied mutation observed red, plus a clean rerun, model/agent, environment and coverage gaps.
+    Prefer another model family, host or toolchain; rank alone neither qualifies nor disqualifies. The
+    user's own reviewed, approved diff also qualifies, for mechanism as well as prose. Every changed
+    function is required by the contract, or justified. Windows is the sole platform leg; direct PS7 and
+    PS5.1 runs are separate required legs and neither may relaunch the other.
```

**C6 — Maintenance model #5** (RCA only for escaped defects, direction 3):
```diff
- 5. **Close mechanism and critical deliveries — and any escaped defect — with an RCA** in the backlog
-    entry: why did no gate catch it, and what else is exposed to the same class. The sweep produces
-    backlog stubs, not edits (class rule 1).
+ 5. **Close an escaped defect, in any class, with an RCA** in the backlog entry: why did no gate catch
+    it, and what else is exposed to the same class. The sweep produces backlog stubs, not edits
+    (class rule 1).
```

**Verification section:** no line added, same reasoning as phase 1 — `assert-red-first.ps1` is
already named inside the amended Maintenance model #2 (C5) and gets its full recipe in
`DEVELOPING.md`.

**Measured result, on the real file, DocTruth's own method (see Delivery for the gate's own PASS):**
**198 lines / 16,831 LF-normalised bytes**, vs. 196 / 16,554 before and a 200-line / 19,500-byte
ceiling — 2 lines and 2,669 bytes of margin, per O4's compression of Maintenance model #1 (its
re-audit sentence restated WSD-057 almost verbatim; exact before/after below).

**C7 — Maintenance model #1** (O4, tightened to make room; semantics unchanged, cites WSD-057
instead of restating it):
```diff
- 1. **Locked design + adversarial critique before implementing a mechanism or critical change.** The
-    critique may reject the premise, not merely tighten the approach, and must state the
-    proportionality case (#6). Re-validate the premise of any entry filed more than ~5 minor versions
-    ago (`**Filed against:** vN (date)` says how much history to check). A reviewer's corrections are
-    input, not verdict — re-verify them. Historic decisions are evidence-bearing defaults, not
-    doctrine: a material change in models, hosts, tools, cost or outcomes licenses a recorded
-    re-audit — re-open only when the change could alter the outcome and the decision value exceeds
-    the audit cost; preserve the record, supersede explicitly, start a new result series when the
-    measurement contract changes; "models are better now" is a reason to re-test, not evidence.
+ 1. **Locked design + adversarial critique before implementing a mechanism or critical change.** The
+    critique may reject the premise, not merely tighten the approach, and must state the
+    proportionality case (#6). Re-validate the premise of any entry filed more than ~5 minor versions
+    ago (`**Filed against:** vN (date)` says how much history to check); a reviewer's corrections are
+    input, not verdict — re-verify them. Historic decisions are evidence-bearing defaults, not
+    doctrine, and re-audit only when a materially changed condition could alter the outcome (WSD-057).
```
(9 lines → 6 lines: −3.) Net line delta across C1–C7 applied to the real file: −3 (C7) + 0 (C1/C2/C4/C6,
inline table/row edits) + 4 (C3, new rule) + 0 (C5, same line count as before) = +1 line vs. the
phase-1 projection's +4, landing at 198 instead of 200.

**`DEVELOPING.md`** gets one new subsection with the command recipe (both invocation forms, the
`RED_FIRST` line contract, and a pointer to `AssertRedFirst.Tests.ps1` and this plan) — no line
ceiling applies to it.

### D. Consistency sweep (findings only — none fixed here, all outside this task's boundary)

- **`.claude/scripts/release.ps1`** (read, not edited): the `-ReviewEvidence` refusal text (around the
  `## FATAL: no review evidence` block) still says *"High-risk changes also need an orthogonal
  reviewer or execution vantage"* and the `meta/review-ledger.md` preamble it writes repeats
  "Maintenance model" generally. Once C5/C2 land, that sentence contradicts `AGENTS.md`. **Finding for
  a backlog stub:** update `release.ps1`'s refusal text to match (mechanism-class change to that file
  — small, but it IS `.claude/scripts/release.ps1`, so it's critical-row unless it separately
  qualifies for the new rule 6 reduction).
- **`.claude/skills/meta-release/SKILL.md`**: "Critical additionally names the orthogonal second
  reviewer or execution vantage" — goes stale for the same reason. **Finding for a backlog stub**
  (this file is `.claude/skills/**`, mechanism-class on its own, cheaper to fix).
- **`.claude/skills/meta-review-handoff/SKILL.md`**: its reviewer-prompt step 5 still only offers
  "one release-specific hostile case or applied mutation you observed RED" — not wrong, just
  incomplete now that a mechanical `RED_FIRST PASS` line or a user's own diff review also qualify.
  **Finding**, lower priority (stale, not contradictory).
- **`meta/review-ledger.md`** preamble and **`.claude/skills/meta-gates/SKILL.md`**: neither hardcodes
  the sentences being changed; both stay accurate as written. No finding.
- **DocTruth / other meta tests**: confirmed by direct grep (see Premise re-validation) that nothing
  asserts the specific prose being edited. No finding.
- **`meta/BACKLOG.md` / `meta/BACKLOG-DONE.md`** (out of scope to edit): B-239 carries forward B-237's
  "review debt" per today's own commit log (`ad26a8ab`: "archive B-237, carry its review debt into
  B-239"). Once review-debt tracking is dropped as a concept, that carried note is orphaned — it
  describes an obligation the new rules no longer recognise. **Finding for the coordinating session
  to reconcile at integration** (close, reword, or explicitly grandfather B-239), since I cannot edit
  records files here and doing so would risk an id collision with another active session anyway.
- **WSD-089's own success-measure window (R7).** WSD-089's "Success measure (read on 2026-09-30 …)"
  is a live, in-progress measurement of the ceremony this change amends (mechanism/critical review
  requirements, `AGENTS.md`'s line ceiling itself). **Finding**: the new WSD should state explicitly
  that any 2026-09-30 read evaluates each measured release against the rules in force *at the time
  that release shipped*, not retroactively against this amendment — otherwise a pre-amendment release
  correctly following the old orthogonal-vantage rule could misleadingly read as a deviation once the
  rule has changed under it.

## Inertness shapes this checker is exposed to, and how each is closed

Applying Maintenance model #4's four shapes to `assert-red-first.ps1` itself:
- **Literal/syntactically inert assertion** — a trailer regex or empty-declared-cases path that never
  fires. Closed by an explicit, tested exit-2 branch when zero cases are declared (test case 3), so
  "nothing declared" cannot silently read as passing.
- **Exit-domain collision** — trusting the directly-invoked test file's own process exit code (itself
  a failing-case COUNT, per `Write-TestSummary`) as the verdict. Closed by parsing only the per-case
  `[ok]/[FAIL]` lines and discarding the process exit code outright (test case 5, an unrelated
  always-failing case that must not flip the result for any declared case).
- **Empty/absent conflated with inability to examine** — a declared case name that resolves to
  nothing in one tree's output must not default to "didn't fail" (which would look like a pass).
  Closed by an explicit "found in both maps or exit 2" check before any verdict is computed (test
  case 4).
- **Normalization/comparison that stops comparing** — a substring or regex-based name lookup would
  let one case's `[FAIL]` line satisfy a different, superset-named declared case. Closed by exact
  string comparison on the parsed name, and the fixture deliberately includes a case name that is a
  superstring of another (test case 2) so this bug is reachable and not just asserted away.
- **Self-referential fifth risk specific to this design**: the parent-checkout overlay silently
  no-op'ing would leave the parent already looking like the fixed tree. Not given a dedicated case
  because it is already caught by case 2 (genuine red-first): if the overlay never applied, the
  *commit*-side run would also never have gained the new case (nothing declared it present anywhere
  to run against), so the "green on commit" half of `PASS` fails too and the checker reports
  `CANNOT_EXAMINE`/`WRONG`, not a false `PASS`. A sixth, R3-added risk — "red for the wrong reason"
  (the whole file/harness broken on the parent, not just the feature absent) — is closed by the
  liveness control and R3a's always-printed parent message, per the critique disposition above.

## Out of scope

No change to `release.ps1`, `check-outgoing-commits.ps1`, `push-and-check.ps1`, `ci.yml`, `install.ps1`,
any `src/`/`dist/` content, or any records file. `assert-red-first.ps1` is not wired into
`release.ps1`'s automatic gate ladder in this task — it is a manually-invoked tool whose output a
reviewer or `-ReviewEvidence` string names, exactly like `/meta-review-handoff`'s packet is manual
today. Wiring it into an automatic gate is a separate, larger (likely critical-class, since it would
touch `release.ps1`) decision left to a backlog stub. No WSD is written here — the coordinating
session records one at integration to avoid id collisions.

## Points raised in phase 1, resolved by the critique

All four phase-1 judgment calls were put to the critique and resolved (dispositions above): (1) new
test file vs. reuse — critic agreed, kept as a new file (O2). (2) the size bound counting only the
subject file's own diff, not its tests — kept, coordinator set the number to ≤10 (O1). (3) direction
3's unconditional orthogonal-vantage removal — narrowed back for `install.ps1` protected/retirement
blocks specifically (R5); the rest of direction 3 (review-debt, blanket RCA) still lands as asked.
(4) the zero-line-margin risk — moot; O4's compression left 198/200 with 2 lines of real margin.

## Delivery (phase 2 — commands run, output observed)

**Red first**, subject renamed away, both hosts (`AssertRedFirst.Tests.ps1`, 1 control + 10
behavioural cases): `pwsh` → 1 passed, 10 failed, EXIT=10, every behavioural case failing with
`exit 64: ... 'assert-red-first.ps1' is not recognized`; `powershell.exe` → identical shape,
`exit -196608`. Restored the script, iterated to green; caught two genuine PS5.1-only defects along
the way (Windows PowerShell wraps a redirected native child's stderr into a promotable `ErrorRecord`,
which `$ErrorActionPreference='Stop'` turned into a terminating exception for an ordinary git failure
and for a clean subprocess run alike — fixed by dropping to `'Continue'` around every native `git`
and host invocation) and one cross-host bug (CRLF-joined captured output defeating the `(?m)^...$`
anchor — fixed by normalising to LF before matching).

**Green, both hosts:** `AssertRedFirst.Tests.ps1` 11/0/0, `TIMING AssertRedFirst.Tests.ps1` 
(captured via `-CaseCountPath`, included in the 422-case full-suite total below). Manifest diff:
inserted `'AssertRedFirst.Tests.ps1'` into `$expectedTestFiles` in
`.claude/hooks/tests/Invoke-HookTests.ps1`, alphabetically before `B215OwnershipBoundary.Tests.ps1`.

**One-off, real history, both hosts** (`& '.claude/scripts/assert-red-first.ps1' -Commit 651be294
-Case '<a>','<b>'` — array-literal syntax; repeating `-Case` or splatting an exploded array into a
native `pwsh -File` invocation is refused by the host's own CLI binder, "specified more than once" —
a PowerShell limitation unrelated to this script, worth knowing before anyone else tries it):
```
-- parent-side result for each declared case --
[FAIL] a commit landing during the CI watch does not receive the release tag -- tag peels to
  'e6112e21...' -- the watched commit is ce45358b..., the unwatched HEAD is e6112e21...
[FAIL] a retry after HEAD advanced accepts the existing tag on the watched commit -- a correct
  existing tag was refused after HEAD moved to f97a9f74... (EXIT=1): Tag FAILED: v9.9.9 already
  exists at 192e446 but the release commit is f97a9f7.
RED_FIRST PASS declared=2 red_on_parent=2 green_on_commit=2      (pwsh, EXIT=0)
RED_FIRST PASS declared=2 red_on_parent=2 green_on_commit=2      (powershell.exe, EXIT=0)
```
Control case declared alone:
```
[ok] control: with HEAD unchanged since the watch, the tag lands on the release commit
WRONG: 'control...' passed on the parent (inert, not red-first)
RED_FIRST WRONG declared=1 red_on_parent=0 green_on_commit=1     (both hosts, EXIT=1)
```
This is the machine-observed red B-237's own plan recorded as deferred review debt.

**Gates:** `DocTruth.Tests.ps1` 18/0/0 EXIT=0 (both before and after the `AGENTS.md`/`DEVELOPING.md`
edits); `RepositoryPrivacy.Tests.ps1` 7/0/0 EXIT=0. Full meta suite, `pwsh`: 0 failures/37 files,
`TOTAL 422`, EXIT=0. Full meta suite, `powershell.exe`: 0 failures/37 files, `TOTAL 422`, EXIT=0 —
equal non-zero case counts. CP437 hostile leg (`AssertRedFirst.Tests.ps1` only, per
`DEVELOPING.md`'s recipe): 11/0/0, EXIT=0. UTF-8 BOM verified by reading the first three bytes on
both new files: present on both.

**Dogfood, and a real bug it caught.** Running the shipped `assert-red-first.ps1` against its own
commit `7ce02eeb` (trailers, no `-Case`) refused with `CANNOT_EXAMINE`: the trailer scanner treated
any line *containing* "red-first" as a case-insensitive substring as an attempted trailer needing
strict parsing, so the commit's own subject ("...mechanical red-first check...") tripped it before
reaching the ten real trailers lower in the message — every mention of the script's own hyphenated
name has this problem. Fixed in a follow-up commit `e31d32ac` (anchor the trigger to lines whose
trimmed text *starts with* the word "red-first"); re-verified `AssertRedFirst.Tests.ps1` 11/0/0 both
hosts and a pwsh confidence re-run of the full 37-file suite (0 failures) before re-dogfooding:
```
[FAIL] a genuine red-first case exits 0 via the commit-message trailer, ...  -- got 64
[FAIL] a case name containing " -- " is matched exactly, not truncated      -- got 64
[FAIL] a planted inert case ... is reported WRONG, naming it                -- got 64
[FAIL] declaring only the genuine case still exits 0 ... (exit-domain collision) -- got 64
[FAIL] a duplicate case name is refused as ambiguous                        -- got 64
[FAIL] a file with only the declared case fails the liveness control        -- got 64
[FAIL] a declared case name absent from either tree is refused              -- got 64
[FAIL] an unparsable Red-first-like trailer line is refused, quoting it     -- got 64
[FAIL] no Red-first trailers and no -Case is refused                        -- got 64
[FAIL] a root commit with no parent is refused                              -- got 64
RED_FIRST PASS declared=10 red_on_parent=10 green_on_commit=10              (pwsh, EXIT=0)
RED_FIRST PASS declared=10 red_on_parent=10 green_on_commit=10              (powershell.exe; got
                                                                             -196608 on parent)
```
Every declared case failed on `7ce02eeb`'s parent because the subject script did not exist there yet
(native "term not recognized", exit 64 / −196608 per host) and passed on `7ce02eeb` itself. The
control case (deliberately never declared) was independently confirmed `[ok]` on a script-less
parent in the original red-first observation above.
