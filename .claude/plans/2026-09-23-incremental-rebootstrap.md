# Incremental `/rebootstrap` for high-churn repositories (B-284)

User request, 2026-09-23: high-churn consumer repos need `/rebootstrap` often, and a full run costs
too many model tokens. Rework it to re-analyse only what changed since the last bootstrap. Scheduling
(an offline cron runner that opens a Bitbucket Data Center PR through Azure OpenAI or Claude on
Foundry) was discussed and deliberately dropped; the user may return to it. This design keeps
`/rebootstrap` developer-run and developer-confirmed.

## Where the cost is today

`rebootstrap.md` Phase 1 already scopes profile passes to areas changed in the last 3 months and
carries unchanged content forward, and Phase 3 confirms only changes. The unbounded costs are the
calendar window (on a high-churn repo, three months is nearly everything), the shared discovery
pass (A8; A7 in the Angular stack), which is never bounded by the change set, and running at all
when nothing relevant changed.

## Design after the fresh-session adversarial review

1. **Content-hash baseline, no commit SHA.** A state file, never loaded into session context,
   records the blob hash of every evidence path and the tree hash of each top-level directory,
   read with `git ls-tree`. Impact is computed from `git ls-tree -r HEAD` alone. A SHA baseline
   is not hermetic: the reviewer showed `git diff <sha>..HEAD` exit 128 in a fresh clone after a
   squash merge, but exit 0 in the original clone that still held the orphan commit, and a
   `--depth 1` clone sees nothing. A missing state file (first adoption) means a full run,
   reported as cannot-examine.
2. **Exclusions.** The impact computation ignores `framework-owned/overwritten` paths from
   `framework-ownership.json` (as pre-flight step 4 already does for evidence), the state file
   and the framework docs. Otherwise a framework update alone, about 97 owned paths, looks like
   application churn.
3. **Claims are keyed by a hash of their text, and evidence stays out of CLAUDE.md.** Evidence
   lines in CLAUDE.md, and in the AGENTS.md mirror, would add always-loaded text to every consumer
   session. That cuts against B-255 and B-272, and `context-footprint.ps1` does not measure
   populated consumer files. A claim a human has edited counts as affected automatically.
4. **Stop early.** When nothing relevant changed, report so and stop before any model work.
5. **Always recheck these claims:**
   - evidence that matches zero files, reported as cannot-examine (`hazard-check.ps1:60` skips
     wildcards, so a dead glob would be carried forward forever);
   - absence claims ("no test projects");
   - "all X do Y" claims.

   Each gets one cheap grep or search per run. A guessed watch glob misses new naming, e.g.
   `Foo.Spec.csproj`.
6. **When to run a profile in full:** that profile's structural manifests changed (`*.sln`,
   `*.csproj`, `angular.json`, `nx.json`, workspace `package.json`), or more than X% of its
   claims are affected. Decide this per profile in the monorepo stack. It replaces a file-count
   threshold.
7. **Renames.** Only exact renames (the same blob at a new path, the R100 case) are re-pointed
   automatically, and `Reviewed` is never changed. A rename that is below 100% similar (`-M`
   matches at 50%, e.g. a split file) goes into Phase 3c's single question message, because
   WSD-027 lets tooling verify references, not rewrite them. Ageing hazard rows are still asked,
   or session-start's 90-day warning never clears.
8. **No new session-start staleness line.** Session-start has no bootstrap-date check to replace,
   its header says "Keep fast: no expensive scans", and matching globs in PowerShell 5.1 at every
   session start would break that. At most, it prints "N commits since the last baseline".
9. **Discovery-pass scoping is held.** Bounding A8 (A7 in Angular) to changed or uncovered areas
   is the same work as B-222/B-223, held by WSD-097. It ships only if the user lifts that hold for
   this item. Otherwise this item cuts the profile passes and the early stop only.
10. **Scope of the change:** one script, plus one test file run on both PowerShell hosts; the three
    stacks' `rebootstrap.md` and `bootstrap.md` in `src/` (bootstrap writes the first state file),
    with the monorepo sibling reviewed; three stack CHANGELOG heads and a root `CHANGELOG.md` entry
    (invariant 7).

## Open decisions

- Whether to lift WSD-097 for point 9.
- The claim-percentage threshold for point 6; measure it with the B-253 eval harness, comparing an
  incremental run with a full run on a high-churn fixture. Report what incremental misses, not
  only what it saves.
