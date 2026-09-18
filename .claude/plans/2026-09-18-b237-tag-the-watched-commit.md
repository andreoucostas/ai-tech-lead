# B-237 — tag the commit CI verified, not a re-read HEAD

**Class:** critical (`.claude/scripts/release.ps1`; false-green promotion). **Filed against:** v0.86.5
(2026-09-11); master is `0.87.0 — Unreleased` at `e5b67cb3`. **Constraints read:** WSD-029 (a release
tag means CI-verified green; the tag is the promotion step), WSD-028 (the script exposes evidence, it
does not judge it), WSD-034 (proportionality inside the critique). Premise re-validated at source on
2026-09-18: `release.ps1` binds `$releaseCommit = rev-parse HEAD` after the commit (step 5b), pushes
and watches that sha (5c), then at 5d sets `$releaseSha = rev-parse HEAD` again and tags,
postcondition-checks and pushes `$releaseSha`. The defect is live.

## Observed harm

v0.86.5: while 5c watched `3bbd413`, another task committed `6af8827` in the same checkout; 5d tagged
`6af8827` and the annotation said CI verified it. The tag was published and had to be force-corrected
with user approval (Actions run `34582373359`, tag object `ce10dfab`). That is a false-green
promotion — the exact meaning WSD-029 gives the tag was broken.

## Design

1. **Fix.** In step 5d replace `$releaseSha = (git -C $repo rev-parse HEAD).Trim()` with
   `$releaseSha = $releaseCommit`. Every downstream use (existing-tag comparison, `git tag -a … $releaseSha`,
   the tag-push outgoing check `-Revision $releaseSha`, the "Tagged … at" message) then refers to the
   watched commit. The comment above it states why HEAD must not be re-read.
2. **Audit of post-CI actions for ambient HEAD** (5c onward):
   - 5d tag target, existing-tag check, outgoing check, tag push — all derive from `$releaseSha`: fixed by (1).
   - `git push origin refs/tags/$tagName` pushes the tag ref, not HEAD: safe.
   - Optional live-eval evidence commit (attended console only, after the tag): `git commit` lands on
     whatever HEAD is, then pushes it to master; if HEAD advanced it would publish a foreign commit on
     master. It cannot move or mislabel the tag, it re-watches CI for what it pushes (B-91), and it is
     not reachable non-interactively. **Out of scope → one backlog stub** (class rule 1), not an edit.
   - Resume path (nothing to stage): `$releaseCommit` is HEAD at that moment and is what 5c watches,
     so watched = tagged still holds. Unchanged.
3. **Red-first instrument** in the existing `ReleaseCiWatch.Tests.ps1` (no new file, so no manifest
   change). Following `ReleaseStagingGuard.Tests.ps1`, extract the 5d region **verbatim** (bounded
   `# ---- 5d.` → `# B-41 behavioral evals`, asserted neither too small nor too large) and run it in a
   child host (`Get-Process -Id $PID` path, so PS5.1 runs 5.1) against a scratch git repo with
   `$NoPush = $true` and a GREEN `$ciDecision`. Cases:
   - **advanced HEAD:** watched commit A, then commit B lands; `$releaseCommit = A` → `v…^{commit}` must be A.
     Red on the unfixed tree (tag lands on B).
   - **retry after HEAD advanced:** tag already at A, HEAD at B → exit 0 "already present", tag
     unchanged. Red on the unfixed tree (refuses with "Tag FAILED", exit 1).
   - **unchanged HEAD (control):** HEAD = A → tag at A, exit 0. Green before and after; proves the
     instrument can pass, so the red above is the defect and not a broken harness.
   - Region-bound case: the extracted text contains `git -C $repo tag -a` and does not contain
     `watch-ci.ps1` or `Read-Host`.
4. **Gates:** full local meta suite under `pwsh` and `powershell.exe` (equal non-zero `CASE_COUNT`)
   plus a CP437 leg; DocTruth/RepositoryPrivacy/BacklogHygiene; push via `push-and-check.ps1`; CI green.
   No product change, no dist rebuild, no release (backlog rank note: maintainer tooling). Release
   evidence (#2) is recorded in the backlog entry and satisfied at the next release by a reviewer.

## Proportionality (#6)

Harm is concrete and already occurred once (a published wrong tag). The smallest fix — reuse the sha
already captured and watched — removes all of it for the tag path; a lock, a worktree, a HEAD-equality
refusal or re-watching HEAD are larger and add new failure modes (refusing a release because an
unrelated commit landed). A HEAD-equality *refusal* was considered and rejected: the tag should go on
the verified commit regardless of what else landed, which is WSD-029's meaning.

## Critique (non-implementer, 2026-09-18)

Separate read-only Claude Sonnet session; read `release.ps1`, B-237, WSD-029 and both test patterns
before this plan. Verdict: defect real, fix correct and complete; the only other HEAD reads are
`:265` (branch guard), `:822` (capture) and `:953` (the separate eval-evidence commit);
`check-outgoing-commits.ps1` always receives an explicit `-Revision`; eval-path deferral acceptable.
Required: bind every variable the region reads; assert the peeled tag commit, not only the exit code;
update the comment. All three were already in the draft cases. Optional: normalise sha comparisons
(done: full-length, trimmed). The critic could not execute code, so no orthogonal execution vantage
was supplied. That gap is recorded as review debt.

## Not done here

No change to `watch-ci.ps1`, `_ci-decision.ps1`, the eval-evidence path, or B-245's fast path. An
orthogonal second vantage (maintenance model #2) for this false-green class is not available inside
this session; if the critique session cannot supply execution evidence it is recorded as review debt.
