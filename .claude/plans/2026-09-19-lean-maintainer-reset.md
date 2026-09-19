# Lean maintainer reset — plan and hand-off (2026-09-19)

**Status:** REVISED after adversarial review (section 9). Awaiting the user's go on WP1.
**Filed against:** v0.86.7, master `36babcaf`.
**Decision requested by the user (2026-09-19):** replace the maintainer rules and records with a
lean two-tier regime; transition the product machinery in ordered work packages.
**How to use this file:** one work package (WP) per fresh session, in order. Each WP is
self-contained: scope, files, steps, acceptance checks, stop conditions. Do not start a WP whose
"Depends on" is not done. Do not widen a WP; an adjacent finding is one backlog line. Section 10
holds the prompt to paste into each session.

## 1. Evidence (observed by the planning session 2026-09-19 unless attributed)

| Measure | Value |
|---|---|
| Process : product bytes (`meta` + plans + meta tests + tooling vs `src/`) | 0.1x at v0.26.0 → 2.5x at HEAD |
| Last 120 commits | 75 process-only, 33 mixed, 12 product-only |
| CI per push | median 9.2 min (n=39), 9 jobs, no path filter; a `meta/**`-only push runs all of it and `push-and-check.ps1` blocks on it |
| B-237 | 5 changed lines in `release.ps1`; 207 lines of test, plan and backlog in the same commit; a second 62+/58- archive commit |
| WSD-092 (a simplification) | +1,118 lines; 510-line plan under a "1-page plan" rule |
| Full meta suite, PS7, this machine | 309 s wall, 37 files, 0 failures; six installer test files = 51% of file-seconds |
| Session-start reading the backlog demands | about 40k tokens; `meta/BACKLOG.md` alone about 25k; its first 367 lines precede the first entry |
| Archived RCAs | 77 of 166 entries; about 7 name a new check (keyword scan, crude); several cover non-defects (B-238: "the user's preference has changed") |

Sub-agent findings, not re-checked: `release.ps1` runs the full meta suite locally and CI runs it
twice more for the same commit; the 22 dist hook-test files are byte-identical across the three
dists while CI runs them 3 × 2 hosts; about 42% of meta-suite lines guard shipped product.

Two independent clean-slate designs (different models, forbidden from reading the maintainer
layer) converged on: a 40–70 line rules file; two path-keyed tiers; review only on dangerous
paths; capped records; table-driven tests of dangerous surfaces only; path-filtered CI; an
ablation-eval value loop. Caveat: both worked from the planning session's brief, so the
convergence is partly induced.

## 2. Decision shape

- **Layer 1 — rules and records: replace now (WP1).** It is text; nothing executable depends on
  its wording beyond the `DocTruth` and `BacklogHygiene` pins listed in 4.1. Records stay in
  place, not moved or deleted, because `release.ps1`, `BacklogHygiene` and
  `GateBudgetConsistency` read them.
- **Layer 2 — machinery: transition (WP2 onward).** The installer tests encode real data-loss
  incidents; the target distribution shape rests on unverified host facts; the maintainer's
  production repos run the current layout.
- **Composer and `dist/`: keep** unless WP6 or WP8 makes them moot. Compose + `validate-dist` cost
  about a minute, and the stack markers exist because always-loaded text differs per stack inside
  one file. Both clean-slate designs binned them; this plan disagrees on cost grounds.

**Smaller plan considered and rejected: WP2 + WP3 only, rules untouched.** They remove most of the
measured minutes. But under today's `AGENTS.md` both are class critical (`ci.yml`, `release.ps1`):
Maintenance model 1–7, full suites on both hosts plus CP437, locally, for each — the ceremony this
plan exists to remove, paid twice more. WP1 first makes them guarded-tier work (touched tests
only). **Order is the user's call:** WP1 → WP2 → WP3 (this plan), or WP2 → WP3 under today's rules
→ read WSD-089's 2026-09-30 measure → WP1 (the reviewer's preference). WP1 supersedes WSD-089's
success measure explicitly (WSD-093 says so); it does not wait for it.

## 3. Work packages

| WP | What | Tier under the NEW rules | Depends on | Hand-off ready |
|---|---|---|---|---|
| 1 | Rules and records reset (text only) | guarded (`AGENTS.md`) — the user reads the diff | — | yes |
| 2 | CI path filter for top-level records + `push-and-check` skips the watch for records-only pushes | guarded | 1 | yes |
| 3 | `release.ps1` fast path (B-245) | guarded | 1 | yes |
| 4 | Known defects B-247, B-248; then the batched v0.87.0 (B-244, B-249, B-250, B-240, B-239) | per item | 1, 3 | entries exist in `meta/BACKLOG.md`; one item per session |
| 5 | Meta-suite diet: retire paperwork tests, lower ceilings | guarded where the runner or a script changes | 3 | outline only |
| 6 | Distribution spike (B-258) — decision point for the installer | investigation | 4 | outline only |
| 7 | Small installer + write-set invariant, v1.0 | guarded | 6 = go | outline only |
| 8 | With/without ablation eval (B-246, B-253) | ordinary | 4 | outline only |

## 4. WP1 — rules and records reset (text only)

**Goal.** A fresh session reads about 5k tokens of rules instead of about 40k, under two tiers,
with no change to any executable file and every existing gate still green.

**Hard constraints.** No edit to any `.ps1`, `.json`, `.yml`, or anything under `src/`, `dist/`,
`scripts/`. No file moved or deleted under `meta/` or `.claude/plans/`. No test changed. If a gate
goes red, fix the text, not the test; if that is impossible, STOP and report.

### 4.1 Pins the new text must satisfy (verified by the reviewer against the repo, 2026-09-19)
`DocTruth.Tests.ps1`, on root `AGENTS.md`:
- a line matching `^> \*\*YOU ARE IN THE FRAMEWORK AUTHORING REPO`;
- a `## Status` section containing no version number, `B-n` id, date, or "current shipped version";
- the literal strings `dist/*/.claude/framework-version.json`, `CHANGELOG.md`, `tags`, `meta/BACKLOG.md`;
- at most 200 lines and 19,500 LF-normalised bytes; no `@`-import token lines;
- every `scripts/…` or `.claude/…` script path named in a root doc exists (the reviewer tested all
  ten in Appendix A; the four `src/core/…` paths are outside that check's regex and also exist);
- the marker syntax the docs teach is the one the composer implements — Appendix A keeps
  `<!-- @stack:NAME -->` for this reason.
`DocTruth`, on root `CLAUDE.md`: exactly one live `@AGENTS.md` line outside code; at most 40 lines.
`BacklogHygiene.Tests.ps1`, on `meta/BACKLOG.md`: every open `### B-n` entry carries a line matching
`^\*\*Filed against:\*\* v[0-9]+\.[0-9]+(?:\.[0-9]+)? \([0-9]{4}-[0-9]{2}-[0-9]{2}\)`; archive-pointer
lines must resolve; no completed record under an open heading. `meta/decisions-index.md` cites only
`workspace-decisions.md` and `BACKLOG-DONE.md` today, so compacting `BACKLOG.md` breaks no citation.
`BacklogHygiene.Tests.ps1:84-92`, archive pointers: it matches only the plain form
``see `meta/BACKLOG-DONE.md` `` (today `meta/BACKLOG.md:291` and `:1129`; the bracketed-link forms at
`:1122`/`:1126` do not match), throws if it finds zero, and for each match walks back to the previous
sentence end (`.`, `!`, `?` followed by whitespace) and requires every `B-n` in that clause to be
archived. `DocTruth`/`BacklogHygiene` also require the heading grammar `### B-n · title` (the `·`
is required).
`ClaimTruth.Tests.ps1:9` also reads root `AGENTS.md` (three deny-regexes for false-assurance
claims); the cold-read reviewer checked Appendix A trips none. Every other `AGENTS.md` reference in
the test tree targets `src/`, `dist/` or installed copies.
`MetaHooks.Tests.ps1`: refuses only a zero-skill scan; each remaining skill needs a frontmatter
`name` equal to its directory, a description, and the `meta-` prefix.

### 4.2 Files
1. **`AGENTS.md`** — replace the whole file with Appendix A, verbatim. Then `Test-Path` every path
   it names; correct a wrong path, change nothing else.
2. **`CLAUDE.md`** — keep the banner, the `@AGENTS.md` line and the "Claude Code specifics" list.
   In that list: the "Maintainer skills" bullet becomes `/meta-gates <tier>` only (remove
   `/meta-review-handoff` and `/meta-release`); replace the auto-memory bullet's second sentence with "A decision goes to
   `meta/workspace-decisions.md`; nothing goes to private memory."
3. **`DEVELOPING.md`** — recipes only. Delete these sections entirely: "Verify reviewer-side probes
   before recording green" and "Hazard: reviewing a branch that is still moving". Also replace the
   repo-map row for `.claude/skills/meta-*/` (about line 24) with a `/meta-gates`-only row, and
   delete the "Implementer and reviewer sessions" paragraph that instructs `/meta-review-handoff`
   (about line 485). "Release process" means from its `##` heading (about line 383) to the end of
   the file, including its `###` subsections: inside it delete any numbered step or paragraph that
   instructs a review packet, an RCA, or a second reviewer; renumber the remaining steps; replace
   the evidence-format instructions with the one-line `-ReviewEvidence` form from Appendix A
   "Ship". Keep every command recipe. Add nothing else.
4. **`.claude/skills/meta-review-handoff/`** and **`.claude/skills/meta-release/`** — delete both
   directories. **`.claude/skills/meta-gates/SKILL.md`** — rewrite its ladder to the recipes in
   Appendix A "Verification", keeping the exit-code capture discipline. In its frontmatter keep
   `name`, change `argument-hint` to `guarded|ordinary`, and reword `description` to the two tiers.
   Then `grep` the repo (outside `meta/` archives and `.claude/plans/`) for `meta-review-handoff`
   and `meta-release`; no live reference may remain.
5. **`meta/BACKLOG.md`** — rewrite to: a header of at most eight lines; the "Pick-up order" table
   with this plan's WP1–WP3 inserted as the first rows (B-245 is WP3 and moves up; B-264 is WP5);
   then every currently open `### B-n · title` entry reduced to its heading, its `**Filed against:**`
   line unchanged, its `**Priority:** … · **Effort:** … · **Invariants:** …` line, and at most three
   lines of status. B-232 uses a different grammar (`**Priority / effort:** P2 / M. **Status:** …`):
   keep that line's priority/effort part verbatim. Delete the "Execution order and common delivery
   contract" section and all campaign narrative. The header must say: "Full pre-reset text:
   `git show 36babcaf:meta/BACKLOG.md`."
   **Archive pointers (4.1):** end the file with a `## Archived` section holding exactly these two
   lines, each on its own line, the section's first line preceded by a sentence ending in a full
   stop: ``B-219 and B-221 — see `meta/BACKLOG-DONE.md`.`` and
   ``B-225 and B-254 — see `meta/BACKLOG-DONE.md`.`` Drop the bracketed-link pointer lines for
   B-241 and B-235 (they never matched the gate). Name no open id in that section.
   **New stub**, with these literal first two lines: `### B-270 · release.ps1 -NoIndependentReview
   files its stub under an anchor that no longer exists` and `**Filed against:** v0.86.7
   (2026-09-19)`, then `**Priority:** P3 · **Effort:** S · **Invariants:** #7` and one sentence:
   the `## Known deferred work` anchor (`release.ps1:669`) is absent from this file, so the stub
   filing already degrades to a WARNING; the new rules use `-ReviewEvidence` only. (If `B-270` is
   taken, use the next free id.) Do not archive open entries: all 37 stay (Appendix A's cap is
   40). Target: under 320 lines.
6. **`meta/workspace-decisions.md`** — append `## WSD-093: lean maintainer reset — two tiers, capped
   records (2026-09-19)`, at most 25 lines: context (three numbers from section 1); the two
   approaches weighed (bin everything vs replace layer 1 and transition layer 2) with one trade-off
   each; the decision; what it supersedes (WSD-089's classes and its 2026-09-30 success measure,
   WSD-092 items 3–5, WSD-028/WSD-057 ledger and review scope outside the guarded list); the new
   measure (escaped defects per release over the next five releases, and minutes from "change
   ready" to pushed); and "from this entry on, a decision entry is at most ten lines".
7. **`meta/decisions-index.md`** — add the WSD-093 line in the existing citation format; change
   nothing else. (The index stays a citation index: `BacklogHygiene` requires every bullet to
   resolve to a `## WSD-nnn:` or `### B-n` heading elsewhere.)

### 4.3 Steps
1. `git status --porcelain` is empty; HEAD is `36babcaf` or a descendant.
2. Make the edits in 4.2.
3. Under `pwsh`, then again under `powershell.exe`, capturing `$LASTEXITCODE` after each:
   `.claude/hooks/tests/Invoke-HookTests.ps1 -File DocTruth.Tests.ps1`, `-File BacklogHygiene.Tests.ps1`,
   `-File RepositoryPrivacy.Tests.ps1`, `-File MetaHooks.Tests.ps1`.
4. The whole meta suite once under `pwsh` (about 5 min): root docs are pinned in places this plan
   may not have enumerated. Expect 0 failures across 37 files.
5. Show the user `git diff --stat` and the `AGENTS.md` diff. **The user's approval in their own
   words is the review.** Do not commit before it.
6. One commit, subject `guarded: AGENTS.md, CLAUDE.md, DEVELOPING.md, .claude/skills, meta/ — lean
   maintainer reset (WSD-093)`; body at most five lines (harm, smaller fix rejected, what could be
   let through; "text-only: no behaviour to show red"). Push once with
   `.claude/scripts/push-and-check.ps1`.

### 4.4 Acceptance
`AGENTS.md` ≤ 120 lines; `meta/BACKLOG.md` < 320 lines with 38 `### B-` headings; step 3 exits 0
on both hosts; the full suite exits 0; CI green; exactly one commit and one push.

### 4.5 Stop conditions
A gate that cannot be made green by editing text; any need to touch a `.ps1`/`.json`/`.yml`; the
user has not approved the diff.

## 5. WP2 — top-level records pushes stop paying for CI

**Goal.** A push whose every changed path is a top-level `meta/*.md` file (except
`meta/eval-results.md`) or under `.claude/plans/**` triggers no CI run, and `push-and-check.ps1`
does not wait for one. Every other push behaves exactly as today.

**Why this narrow.** `meta/` also holds gate inputs — `gate-budget.json`, `context-footprint.json`,
`framework-retirements-baseline.json`, `block-manifest.json`, `eval-fixtures/**` — that CI must
keep seeing. And `release.ps1:949-989` commits `meta/eval-results.md` after a tag and calls
`watch-ci.ps1 -Sha` on it directly; if that push produced no run, `watch-ci.ps1` would stall for
`AppearSeconds` (180 s) and exit 3 "no push run appeared". Keeping that one file heavy leaves
`release.ps1` untouched.

**Design (chosen).** In `.github/workflows/ci.yml`, on the `push` trigger only:
```yaml
    paths:
      - '**'
      - '!meta/*.md'
      - '!.claude/plans/**'
      - 'meta/eval-results.md'
```
(`*` does not cross `/`, so `meta/eval-fixtures/**/*.md` stays heavy; later patterns override
earlier ones; a push runs if any changed file remains included — confirm all three statements
against GitHub's workflow-syntax documentation before editing, and by the acceptance pushes.)
`pull_request:` is a separate key and stays unfiltered; `paths:` goes under `push:` as a sibling of
`branches:` (`ci.yml:9-11`, four-space indent).
In `push-and-check.ps1` (it computes no range today — it shells out to the outgoing check at about
`:104-106` and pushes at `:112`): immediately **after** the outgoing check succeeds and **before**
`git push`, list the outgoing commits with the shape `check-outgoing-commits.ps1:142` uses —
`git rev-list --reverse --topo-order $Branch --not --remotes=$Remote` — and for each commit list
paths with `git diff-tree --root --no-commit-id --name-only -r -m <sha>` (`-m` so a merge commit
lists the paths of every parent diff; union them all). Classify with a pure function,
`Test-LightChangePath([string]$Path)`, that returns true only for `^meta/[^/]+\.md$` other than
`meta/eval-results.md`, or `^\.claude/plans/`. The push is light only when the path list is
non-empty and every path is light. After the existing `$WatchedBranches` check (about `:120-123`),
when light, skip the `watch-ci.ps1` call and print `CI_WATCH SKIPPED records-only`. Update the
"keep in sync" comment near `:10`.
**Rejected.** `paths-ignore: meta/**` (hides gate inputs; breaks the eval-evidence watch). A
`changes` job with per-job `if:` (`watch-ci.ps1` requires all nine job names to conclude success,
so skipped jobs need new decision logic). Root `README.md`/`CHANGELOG.md`/`AGENTS.md` stay heavy on
purpose: `DocTruth` and `ClaimTruth` police them.
**Known cost.** `DocTruth`/`BacklogHygiene`/`RepositoryPrivacy` no longer run in CI for a light
push; they run locally (Appendix A recipe) and in CI on the next heavy push.

**Files.** `.github/workflows/ci.yml`, `.claude/scripts/push-and-check.ps1`,
`.claude/hooks/tests/PushAndCheck.Tests.ps1` (cases added to the existing file; no new file).
No test pins `ci.yml`'s `on:` block (`ReleaseDistGateTiming`'s `Get-CiJob` scans only under `jobs:`).
**Red-first cases** (existing fake-git harness): (a) light-only range → `watch-ci` not invoked and
the skip line printed; (b) mixed range → invoked; (c) a range touching `meta/eval-results.md`,
`meta/gate-budget.json` or `meta/eval-fixtures/x/README.md` → invoked; (d) the light rules in
`push-and-check.ps1` equal the negated patterns parsed from `ci.yml` (drift guard); (e) an empty
or unreadable path list → the watch RUNS (inability to classify is never "records-only").
**Harness notes.** `New-GitStub` (`PushAndCheck.Tests.ps1`, about `:32-35`) answers `rev-list` and
`diff-tree` with empty output today, so the six existing cases fall into (e) and stay green
unchanged — confirm that first. Cases (a)–(c) need a new `-ChangedPaths` substitution on the stub.
Case (d) cannot use the fake-git harness: lift `Test-LightChangePath` out of `push-and-check.ps1`
by AST, as `ReleaseGateWaiver.Tests.ps1:32-40` lifts its function, and parse the `paths:` list from
the real `ci.yml` by regex (there is no YAML module on this machine); assert that the negated
patterns and the re-included file equal what the function encodes.
**Steps.** Read the three files and `watch-ci.ps1` first. Write the cases, see them red, make the
change. Run `PushAndCheck.Tests.ps1`, `ReleaseCiWatch.Tests.ps1`, `ReleaseDistGateTiming.Tests.ps1`
and `CiCaseParity.Tests.ps1` under `pwsh` and `powershell.exe`, plus one CP437 leg
(`DEVELOPING.md`, "Host resolution and the legacy-host hostile-code-page leg"). Run
`assert-red-first.ps1` against the commit. Commit `guarded: …` with `Red-first:` trailers; push.
**Acceptance.** Those files green on both hosts; `RED_FIRST PASS`; the code push shows a normal
nine-job CI run; then one deliberate light follow-up push (mark WP2 done in `meta/BACKLOG.md`)
shows no CI run in `gh run list` and returns in seconds.
**Stop conditions.** GitHub's documented `paths` semantics differ from the three statements above;
any route by which a release commit or tag could be classified light.

## 6. WP3 — `release.ps1` fast path (B-245)

**Goal.** The local `meta-suite` stage drops from about five minutes to about one; the tag still
waits for CI's full run on the exact release commit (B-237 binding untouched). "About one minute"
is a hypothesis: `DocTruth` alone measured 33 s standalone on 2026-09-19 (its mutation case copies
the repo to temp), and four serial `-File` runs each re-pay the runner's manifest check and host
probe. Measure the four-file subset first and set the ceiling from the measurement; do not drop a
file from the subset to fit a number.
**Principle for the local subset.** Run locally only the files whose subject the release commit
itself changes — version stamps, changelog heads, tag reconciliation, the gate budget, new `.ps1`
bytes: `DocTruth`, `ReleaseChangelogStamp`, `GateBudgetConsistency`, `WorkspaceBom`. Everything
else was verified by CI on the pre-release HEAD and is verified again by CI on the release commit
before the tag. Compose, freshness, `validate-dist` ×3, `context-footprint`, `eval-selftest` stay
(`AgentEvals.Tests.ps1` runs nowhere else).
**Rejected.** The reviewer's wider subset (adding `OutgoingCommits`, `PushAndCheck`, all
`Release*`): `-File` is single-valued (`Invoke-HookTests.ps1:19`), so a subset runs serially, and
those files sum to about 250 s serial against 309 s for the whole suite in parallel — no saving.
A multi-file selector on the runner: more mechanism in the false-green surface. A `-Fast` switch:
two paths to keep true.
**Known pins this change must rewrite, not merely read.**
- `ReleaseDistGateTiming.Tests.ps1:128-130`, case "the full root meta suite remains on its existing
  default throttled runner with RESULT and waiver parsing", asserts the stage text matches
  `Invoke-HookTests\.ps1'\) \*> \$metaLog`. Rewrite it to assert the four `-File` invocations.
- `release.ps1:601-607`: `Resolve-GateWaiverOutcome` parses `RESULT` lines from `$metaText`; the
  per-file invocations must be **concatenated** into one `$metaText` or `-AllowFailingGate` loses
  its evidence.
- `release.ps1:160-163` **already** refuses a waiver for a file the suite did not run ("…which the
  meta suite did not run. Check the filename."). The new behaviour is only the distinction: a
  waiver naming a real manifest file outside the local subset is refused with the literal text
  `runs in CI only`. The pure waiver function therefore needs the subset (or the manifest) as a new
  parameter, which changes the signature `ReleaseGateWaiver.Tests.ps1:32-40` lifts by AST — that
  file is a pin to rewrite too.
- `meta/gate-budget.json`: `GateBudgetConsistency.Tests.ps1:43` only requires
  `total-local-gates >= sum`, so it stays green even if the ceiling stops measuring anything. Set
  `meta-suite` to about twice the first measured subset time, recompute `total-local-gates` to the
  literal sum, and add a `ceiling-revisions` entry, although no gate demands one.
- The printed banner is at about `release.ps1:299` ("full root meta suite (default throttled
  runner)") with its comment block at `:288-298` ("re-measure before changing the budget or this
  banner"); update both, including the stale "~30 minutes".
**Precondition added to the recipe, not to the script:** before releasing, the latest `master` CI
run is green (`gh run list --branch master --limit 1`).
**Red-first cases.** (a) the stage invokes exactly the four files; (b) a waiver for a manifest file
outside the subset is refused **with the literal `runs in CI only`** — asserting refusal alone
passes on the parent and `assert-red-first.ps1` would report WRONG; (c) the B-237 cases in
`ReleaseCiWatch.Tests.ps1` stay green untouched. All four subset files are in `$expectedTestFiles`
and run standalone via `-File` (cold-read reviewer, verified).
**Steps / acceptance.** As WP2: touched test files on both hosts + CP437, `RED_FIRST PASS`. The
first real release afterwards quotes its `TIME` lines in the commit body; the meta-suite stage's
measured time is recorded in `gate-budget.json`.
**Stop:** any change that would let a tag be created without CI success on the release commit.

## 7. WP4–WP8 — outlines (not hand-off ready; each needs its own short brief when reached)

- **WP4.** B-247, then B-248, from `meta/BACKLOG.md`, one per session (both guarded: shipped
  hooks). Then one v0.87.0 release batching B-244, B-249, B-250, B-240, B-239.
- **WP5.** After WP3 the local suite is off the release path, so this is about maintenance cost.
  Candidates, each verified before deletion (the subject is retired, or a named other case covers
  it): `FidelityCheck` + `scripts/fidelity-check.ps1` (B-251), `ReleasePostEvalPrompt`,
  `GateBudgetConsistency`, the `BacklogHygiene` cases that pin backlog prose, the `DocTruth`
  ceiling constants (lower to 120/40 so Appendix A's cap is enforced). Merge the six `Release*`
  files. Every deletion updates `$expectedTestFiles` and keeps PS7/PS5.1 case parity.
- **WP6.** B-258 spike, one to two days, on real hosts: can a Claude Code plugin or a single owned
  directory carry PowerShell hooks and work offline in a locked-down environment? Output: one
  decision entry, go / no-go for WP7.
- **WP7 (only if WP6 = go).** New installer under 300 lines beside the old one; one invariant on
  every scenario — everything outside the allowed write set is byte-identical before and after;
  dry-run default; real uninstall. Migrate the maintainer's own repos by hand; ship v1.0; then
  delete the old installer, the retirement ledger and the six installer test files.
- **WP8.** B-246 then B-253: ablation eval — a rule whose case passes equally well without the
  rule is deleted. It reports; it never gates a release (decisions index: "Evals are not a release
  gate").

## 8. Risks

| Risk | Control |
|---|---|
| The reset drops a rule that was preventing a real defect | Section 9 records the clause-by-clause diff; four dropped obligations were restored; archives stay readable; WSD-093's measure counts escaped defects over the next five releases |
| Guarded list misses a dangerous path | Widened after review to the runner, every shipped hook and settings file, and `context-footprint`; anyone may raise a tier |
| Light classification wrongly skips CI for a gate input | Only top-level `meta/*.md`; cases (c), (d), (e) |
| Fast path lets a red suite reach a tag | The tag still requires CI success on the exact release commit; B-237 cases untouched |
| The new regime accretes again | 120-line cap with cut-to-add (enforced at 200 until WP5 lowers the constant); 40-entry backlog cap; "no new script, test file or record unless the task requires it" |

## 9. Adversarial review record (Opus, read-only, non-author; verdict REVISE)

The planning session re-verified findings 1, 2, 5, 6 and 8's anchor claim in the repo before acting.

| # | Finding | Disposition |
|---|---|---|
| 1 BLOCKER | `paths-ignore: meta/**` makes the post-release `meta/eval-results.md` watch stall 180 s and exit 3 | Accepted and widened: the planning session also found `meta/` holds gate inputs. WP2 now filters only top-level `meta/*.md`, keeps `eval-results.md` heavy, leaves `release.ps1` untouched |
| 2 BLOCKER | 25-entry cap against 37 open entries | Accepted: cap is 40; WP1 archives nothing |
| 3 MAJOR | Guarded list missed the runner, shipped and maintainer settings, every hook but `guard.ps1`, `context-footprint` | Accepted: all added; human-read step stays limited to the destructive subset |
| 4 MAJOR | Dropped without a mechanical backstop: hermetic gates, Copilot `postToolUse` caveat, "a host that cannot execute has no evidence" (WSD-061), `meta/LEARNINGS.md` as the why-trail | Accepted: all four restored in Appendix A |
| 5 MAJOR | Free-standing decisions in the index collide with `BacklogHygiene`'s citation rule | Accepted: `workspace-decisions.md` stays open, entries capped at ten lines; index unchanged |
| 6 MAJOR | WP3 breaks `ReleaseDistGateTiming:128-130`; `-File` is single-valued; `$metaText` must be concatenated; `GateBudgetConsistency` missing from the subset | Accepted, except the wider subset — rejected with measured timings (section 6) |
| 7 MAJOR | `release.ps1` demands `-ReviewEvidence` or `-NoIndependentReview`; the 300-character rule has no instrument | Accepted: Appendix A gives the one-line `-ReviewEvidence` form; the 300-character claim is gone |
| 8 MINOR | Pins verified clean; `## Known deferred work` anchor is already absent | Recorded in 4.1; one backlog stub added in WP1 |
| 9 MINOR | Compute the outgoing set before the push, reusing the existing range shape; preserve the filed-against grammar; keep the marker syntax; wrong WSD id; 120 cap unenforced | All accepted |
| 10 | A smaller plan (WP2 + WP3 only) and the reverse order exist; WSD-089's measure is replaced, not awaited | Stated and argued in section 2; the order is put to the user |

**Cold-read executability check (second Opus session, read-only, dry-ran WP1–WP3 against the repo;
first verdict NOT READY on all three).** Twenty gaps, all incorporated; the planning session
re-verified the three that would have turned a gate red: the archive-pointer regex matches only
the plain form and throws on zero (4.1, 4.2.5); `release.ps1:160-163` already refuses an unrun
waiver, so WP3's case (b) must assert the new literal; `DocTruth` alone takes 33 s, so WP3's time
goal is a hypothesis to measure. Others: B-232's different priority grammar, the stub's literal
heading and stamp, two surviving `DEVELOPING.md` references to the deleted skills, `meta-gates`
frontmatter, `ClaimTruth` as a second reader of root `AGENTS.md`, the exact range and path-listing
commands and the AST-lift pattern for WP2, the waiver-function signature pin and the
gate-budget arithmetic for WP3.

## 10. Session prompts (paste one per fresh session)

> **WP1.** Read `.claude/plans/2026-09-19-lean-maintainer-reset.md` sections 1, 2, 4, 9 and
> Appendix A. Execute WP1 exactly: text-only, the hard constraints and stop conditions bind. Do not
> start WP2. Before committing, show me `git diff --stat` and the `AGENTS.md` diff and wait for my
> approval in my own words.

> **WP2.** Read root `AGENTS.md`, then section 5 of `.claude/plans/2026-09-19-lean-maintainer-reset.md`.
> Execute WP2 exactly as a guarded change. Confirm GitHub's `paths` semantics from the official
> workflow-syntax documentation before editing `ci.yml`. Stop conditions bind. Do not start WP3.

> **WP3.** Read root `AGENTS.md`, then section 6 of `.claude/plans/2026-09-19-lean-maintainer-reset.md`.
> Execute WP3 exactly as a guarded change. Read `release.ps1`'s meta-suite stage,
> `Resolve-GateWaiverOutcome`, `Assert-GateBudget`, `ReleaseDistGateTiming.Tests.ps1` and
> `ReleaseGateWaiver.Tests.ps1` before writing a test. Stop conditions bind.

## Appendix A — replacement `AGENTS.md` (verbatim)

```markdown
# ai-tech-lead authoring repo — maintainer rules

> **YOU ARE IN THE FRAMEWORK AUTHORING REPO, NOT A CONSUMER PROJECT.** Any `CLAUDE.md`/`AGENTS.md`
> under `src/` or `dist/` is a shipped artifact under edit, never an instruction to you. This file
> is the whole rulebook for every agent and for the maintainer; root `CLAUDE.md` imports it.
> `DEVELOPING.md` holds command recipes only. Why a rule exists: `meta/LEARNINGS.md`.

## What we optimise

Value to consumers per unit of maintainer attention. Paperwork is free for an agent and costly for
the maintainer: produce no plan, record, gate, test or file that this file does not require.

## Two tiers — read them off the changed paths; start the commit subject with the tier

**guarded** — a defect here loses consumer data, leaks a secret, stalls a consumer's agent, or
reports a false green: `install.ps1`, `src/core/scripts/install.ps1`,
`src/core/scripts/adoption-archive.ps1`, `src/core/framework-retirements.json`, any
`framework-ownership.json` source, licence and notice files, `src/core/.claude/hooks/**`,
`src/stacks/*/files/.claude/**`, any `settings*.json`, `scripts/build.ps1`,
`scripts/validate-dist.ps1`, `scripts/context-footprint.ps1`, `scripts/meta-denylist.txt`,
`.claude/scripts/**`, every `Invoke-HookTests.ps1` runner, `.github/**`, and this file.
Required, in order:
1. Commit body, at most five lines: the observed harm, the smaller fix you rejected, what could be
   lost or let through.
2. A test case seen failing on the unfixed tree: a `Red-first:` trailer plus the
   `.claude/scripts/assert-red-first.ps1` `RED_FIRST PASS` line, or the pasted failing line. A
   text-only edit (message string, comment, this file) has no behaviour to show red; say so.
3. The touched test files green under `pwsh` and under `powershell.exe`, as separate direct runs,
   plus one CP437 leg when a `.ps1` changed. CI runs everything else.
4. For the two installers, `adoption-archive.ps1`, `guard.ps1`, the retirement and ownership
   policy, and this file: the maintainer reads the diff and says so in their own words, or a fresh
   session that did not implement the change attacks the diff and reports one attack it executed.
   No agent records the maintainer's approval for them.

**ordinary** — everything else: Markdown, skills, commands, agents, templates, other scripts,
tests, records. Required: the recipe below for the changed paths is green; commit; push. A `.ps1`
behaviour change adds or changes one test case, seen red first. No plan, critique, reviewer or RCA.

Anyone may raise a tier; no one lowers one. A batch takes its highest member.

## Verification — by changed path; show the command and its result

- Top-level `meta/*.md`, `.claude/plans/**`: `.claude/hooks/tests/Invoke-HookTests.ps1 -File
  DocTruth.Tests.ps1`, `-File RepositoryPrivacy.Tests.ps1`, `-File BacklogHygiene.Tests.ps1`.
- `src/**`: stacks diverge at `<!-- @stack:NAME -->` markers and `src/stacks/<stack>/` snippets and
  whole-files. Review the `src/stacks/monorepo/` sibling of any stack snippet or whole-file you
  touch (it does not reach `dist/monorepo` otherwise) → `scripts/build.ps1 <dist>` ×3 → commit the
  resulting `dist/` change in the same commit → `scripts/validate-dist.ps1 <dist>` ×3.
- A hook or script: also its test file on both hosts; test the **dist** copy by piping a fixture
  JSON event and asserting `EXIT=` plus output, on both agent surfaces where it enforces on both.
- An installer change: greenfield and brownfield smoke installs into temp directories.
- Capture `$LASTEXITCODE` before piping a gate into anything. Do not run suites while another
  session is editing the tree.

## Evidence

- Claim only what you ran; quote the command and its result line. Attribute anything you did not
  observe. State uncertainty instead of smoothing it over.
- A green check counts only from an instrument you have seen go red on the unfixed tree.
- "The artifact is wrong" and "I could not examine it" are different results; a gate's exit must
  say which. A host that cannot execute a leg has produced no evidence for it.
- Gates are hermetic: they decide from repository content and explicit inputs, never from ambient
  release state.
- A reviewer's correction is input, not verdict; re-check it.

## Scope

- Do the asked change only. An adjacent finding is one line in `meta/BACKLOG.md`, not an edit.
- No new script, test file, gate, record or document unless the task requires it; propose it in
  one line instead. Prefer deleting to adding.
- An escaped defect — one that reached a tag, or a gate that was green on a wrong artifact — gets
  the case that would have caught it plus at most three sentences in the commit body: cause, why
  no gate caught it, the check added or "none, accepted because …". Nothing else gets an RCA.
- This file stays under 120 lines; adding a clause means cutting one.

## Invariants

1. Author once under `src/`; never hand-edit `dist/` (CI rebuilds and diffs).
2. Per dist, the shipped `CLAUDE.md` is canonical and `AGENTS.md` its composed mirror; fix drift in
   `src/`; the gate is `validate-dist`.
3. Framework-owned executables are PowerShell on native Windows: 7 primary, 5.1 fallback; neither
   host may relaunch the other in a test leg.
4. Every `.ps1` carries a UTF-8 BOM. The `bom-fix` hook covers Write/Edit; add it by hand otherwise.
5. Hook output differs per surface: Claude Code blocks with `exit 2` + stderr; Copilot with stdout
   JSON `permissionDecision: deny`. A hook enforcing on both emits both. Copilot CLI `postToolUse`
   context consumption is version-dependent; tests must not assume it.
6. Only `dist/` ships. `validate-dist`'s `no-meta-leak` scans against `scripts/meta-denylist.txt`:
   add a narrow `ALLOW`, never weaken a `DENY`.
7. A shipped behaviour change needs a root `CHANGELOG.md` entry and a `## <version> — Unreleased`
   head in all three `src/stacks/*/files/CHANGELOG.md`, in the consumer's voice.

## Records

- `meta/BACKLOG.md`: open work only, at most 40 entries, each a heading, its filed-against line,
  its priority line and at most three lines. A finished entry is deleted and leaves one line in
  `meta/BACKLOG-DONE.md`.
- `meta/workspace-decisions.md`: a decision you would otherwise re-litigate, at most ten lines,
  indexed by one line in `meta/decisions-index.md`.
- Archives — older entries of those files, `meta/review-ledger.md`, `.claude/plans/`: read an entry
  only when a task names it; never required reading.

## Ship

Commit to `master` and push with `.claude/scripts/push-and-check.ps1` when the task is done; never
leave work uncommitted. One push per session: records ride in the work commit, and there is no
separate commit to record a CI run or close an item. Releases are batched, roughly weekly, only via
`.claude/scripts/release.ps1 -ReviewEvidence "<tier>; reviewer user|fresh session|none; <range>"`.
No commit to `master` while a release is between push and tag.

## Status

Version authority is the `dist/*/.claude/framework-version.json` stamps; release history is
`CHANGELOG.md` plus tags; the work list is `meta/BACKLOG.md`.
```
