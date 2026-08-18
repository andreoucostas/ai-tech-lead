# Completed backlog entries

This is the archive of completed framework backlog entries. Entries are appended by release.

- **B-77** — DONE **2026-08-17**, targeted for **v0.58.0**. `hazard-check.{ps1,sh}` is a new shipped
  twin gate, wired blocking into `docs-sync-check` after `wiki-check`. It validates each
  `Known Hazard Areas` row's cell count, Status token (the four shapes `session-start` honours —
  anything else is invisible to the staleness nudge), calendar-real ISO `Reviewed` date, and that
  every path-like token in `Area / file(s)` resolves. It is read-only per WSD-027; a test asserts the
  input file is byte-identical after a failing run. Skips cleanly on a missing file, the
  `KNOWN_HAZARD_AREAS_PENDING` marker, or an absent section. 27 cases, both twins, green under pwsh 7
  and Windows PowerShell 5.1.

  **Path resolution is deliberately narrow, and that was the main design call.** The gate blocks, and
  `/bootstrap` drafts the `Area / file(s)` cell as free text — so prose ("the payment reconciliation
  flow") and symbol names (`` `TenantContext` ``) are ignored, a bare filename matches tree-wide, a
  `/`-bearing path resolves from the repo root, and a wildcard checks only its longest wildcard-free
  directory prefix. Seven of the 27 cases exist solely to hold that false-positive line. The
  bare-filename rule was added during review: resolving `PaymentService.cs` against the repo root
  would have failed a consumer's CI on an entirely ordinary row.

  **RCA — why no gate caught the original gap, and what else is exposed.** Nothing read the hazard
  table's *content*: `session-start` parsed it only far enough to compare a date, so a `[VERIFIED]`
  row pointing at a file deleted months ago stayed fresh-looking indefinitely while `CLAUDE.md` told
  the agent to consult that list for blast radius. The exposed class is **any shipped artifact whose
  freshness is measured but whose referents are not** — the same shape `wiki-check` already covers for
  the wiki and `warehouse-map-check` for the warehouse map. Remaining sibling: `LEARNINGS.md` and
  `docs/architecture-decisions.md` carry references that nothing resolves, though neither is dated,
  so neither currently makes a freshness claim it cannot keep.

  **Delivery RCA — two bash-twin defects shipped green from the implementer and were caught only by
  running the leg it could not run.** Implemented by codex (`gpt-5.6-sol`) against a locked brief;
  its sandbox had neither `bash` nor Windows PowerShell 5.1, so it honestly reported both legs as not
  observed. Reviewer-run verification then found: (1) `for part in $candidate` with `IFS=/` left the
  value **unquoted**, so bash pathname-expanded `src/app/**/*.component.ts` against the cwd and the
  "directory prefix" became the repo's own file list joined by `/` — replaced with pure parameter
  expansion; (2) the separator-row test deleted `-`/`:` unconditionally, so a row whose cells are
  **all empty** was silently skipped by `.sh` and reported by `.ps1` — a twin divergence that a green
  bash run cannot show, because agreeing to do nothing looks exactly like agreeing. Both now have
  dedicated cases. Evidence added to B-70 (twin verified on one leg only) and B-84 (a red-test whose
  mutation silently fails to apply reports a false green — it happened twice here).

- **B-46** — DONE **2026-08-17**, targeted for **v0.56.0**. Update mode now discloses before
  mutation that framework-owned files, including `.claude/settings.json`, are replaced; tells the
  consumer to commit, stash, or copy local edits first; and tells them to review the resulting diff.
  The eight protected paths are still restored. Settings, the mixed-ownership case, is copied to the
  rolling `.claude/.state/settings.json.pre-update` backup before refresh and host adaptation. The
  completion line now names those semantics. The measured-noisy per-file detector was not built.

  **RCA:** no gate caught the misleading contract because update tests asserted only what arrived
  and whether protected content survived, never what was lost or what the installer claimed before
  loss. The same class exposes any destructive refresh path whose tests begin after mutation. The
  targeted suite now asserts disclosure ordering, recovery content, greenfield exclusion, success-
  only completion output, and the unchanged legal preflight on both twins.

- **B-65** — DONE **2026-08-17**, targeted for **v0.56.0**. The enforcement-surface taxonomy now
  names on-demand/discoverable material: `docs/defaults.md` may be loaded depending on task and
  model, but is not guaranteed. No pointer or routing-improvement claim shipped; one unaided load
  observed on 2026-07-31 cannot support either claim.

  **RCA:** no gate caught the taxonomy omission because documentation truth checks validate named
  facts and paths, not whether every delivery mode has been classified. The same class exposes other
  optional documentation carriers; they must be described as on-demand unless a stronger delivery
  mechanism is demonstrated.

- **B-81** — DONE **2026-08-17**, targeted for **v0.54.0**. Every composed distribution carries
  the LF-normalised verbatim MIT text at `LICENSES/ai-tech-lead-MIT.txt` and a marked
  `NOTICE-ai-tech-lead.md` identifying the upstream project, governed framework-authored paths,
  licence location, and canonical version stamp. Both installer twins exclude those paths from the
  bulk copy and apply the same preflight policy before any target mutation: copy when absent, accept
  an identical licence, refresh a marked framework notice, and refuse a different licence or
  unmarked notice with exit 3. Brownfield therefore never hands either legal file to `/adopt`.

  This layout is standards-aligned, not scanner-verified: no compliance scanner has been run against
  an installed fixture. If a consumer identifies its scanner, verify that concrete tool before and
  after rather than claiming generic discovery. The equality gate remains in the authoring-only meta
  suite because consumer repos do not contain this repository's root `LICENSE`.

  **RCA:** no gate caught the original omission because composition and installer tests only proved
  that listed artifacts travelled; none asserted that the copied framework carried its legal text.
  The same class exposes any repository-level attribution or policy file assumed to cover generated
  or copied deliverables. The behavioral installer cases now cover both legal artifacts and both
  twins, while the drift gate covers the one deliberately duplicated legal text.

- **B-46 (part 1) / B-65** — **2026-08-17, shipped in v0.56.0.**

  **B-46's unverified question is now measured:** an update **silently clobbers** every consumer edit
  to shipped machinery (skills, hooks, `scripts/`, `.claude/settings.json`); protected and
  consumer-added files survive. The closing line claimed otherwise. Shipped: a preflight disclosure
  printed **before** the first mutation, a rolling backup of `settings.json` at
  `.claude/.state/settings.json.pre-update`, an honest closing line, three documented ownership
  classes (four READMEs + both installer headers), and **WSD-043**.

  **The first design was killed by a second measurement, and the lesson generalises.** It proposed
  naming per-file "local modifications" by diffing incoming against installed content. But a
  difference means a consumer edit *or* an ordinary version change: installing v0.51.0 and touching
  **nothing** leaves **31 files** differing from the current dist. All 31 would have been false
  positives, and a warning that is ~100% noise trains consumers to ignore it. **The first experiment
  only looked convincing because it updated with the same dist version**, so every difference
  genuinely was a consumer edit — the confound was in the method, not the data. Independently fatal:
  `settings.json` is host-adapted at install, refreshed skills gain an exemplar line,
  discovered/disabled skills are restored on purpose, and `.github/skills` is regenerated.
  *Generalisable form: an A/B where one arm is held constant can validate a mechanism that collapses
  the moment the real variable moves.*

  Skipping was rejected on the record: `settings.json` carries hook registrations that must evolve,
  so withholding it is B-97's failure mode. The message deliberately avoids "recover from git
  history" — the installer requires neither git nor a clean tree, so that is a promise we cannot keep.

  **STILL OPEN under B-46 — part (2), version awareness.** There is still **no channel by which a
  consumer learns a new framework version exists**; realistic version lag remains "forever". Untouched
  by this release. B-46's own candidate stands: a throttled `session-start` line naming the installed
  version and an update URL, using the existing `.claude/.state/` mechanism, offline-tolerant, no
  network call. **This is the larger commercial problem and it is still unsolved** — the entry heading
  says so explicitly so it cannot be read as closed.

  **B-65 — CLOSED with the pointer deliberately DROPPED.** The proposed carrier was a line in
  `CLAUDE.md`, which is protected: update restores the consumer's copy, so it would reach new installs
  only and miss the population it exists to help (B-97's wall). The unprotected carrier would travel
  but spends always-on context for a benefit the 2026-07-31 measurement leaves unmeasured. Shipped
  only the missing **on-demand / discoverable** tier in `docs/enforcement-surfaces.md`, which names
  the single unaided-open observation as insufficient to claim a routing improvement.

  **RCA (rule 5):** no gate caught the clobbering because `UpdateDelivery.Tests.ps1` asserted *what
  arrived* and never *what was lost* — the same shape as B-144's finding one release earlier, so
  twice in two releases. **Same-class sweep:** any suite asserting artifacts without asserting the
  producing command's effect on pre-existing state has this hole. `InstallerContract` still drives
  only greenfield/brownfield; B-144 (c) remains open.

- **B-66** — DONE **2026-08-17**, shipped in **v0.55.0**. The remaining prescriptive half:
  greenfield forms defaults (reactive, typed controls, validator placement, no `ngModel` +
  `formControlName` on one control) and an honest `NG_VALUE_ACCESSOR`-vs-`NgControl` trade-off table
  in `docs/defaults.md` § Forms, plus a self-contained custom-form-control branch in the
  `add-component` skill. Both `docs/defaults.md` siblings edited [#1]; the skill is byte-identical
  across angular/monorepo and both `.claude`/`.github` mirrors, verified before and after.

  **Why it shipped now, after sitting blocked since v0.40.0.** The gate was "the `angular-form-control`
  probe is already green, so guidance cannot be shown to improve anything". That inverts the evidence
  hierarchy: B-66 rests on **the only field report this framework has ever received**, which is
  stronger evidence than any probe. And the instrument that would have graded it was itself rejected
  (B-145: at N=6 per arm, exact Fisher `0/6 vs 4/6 -> p=0.0606`, and `meta/BACKLOG.md:1772` already
  forbids a second harness). A second stated reason for deferring — the static-context ceiling — was
  simply **wrong**: only skill *frontmatter* is `static.claude`; a skill *body* is `ondemand-info`
  and `docs/defaults.md` is `instructed`, and neither has a declared ceiling.

  **The claim is labelled honestly:** the guidance addresses a reported gap; its effect on model
  behaviour is **unmeasured**, and nothing in the shipped text implies a probe endorsed it.

  **Three precision traps, all verified in the diff rather than trusted:** circular DI is qualified
  to the *self-referencing* `useExisting: forwardRef(() => Self)` provider, with the note that a
  separate accessor class does not cycle; `@Input() disabled` is described as *fighting*
  `control.disable()` via `setDisabledState()`, and the false claim "Angular warns" appears nowhere
  (`grep -rn "Angular warns" dist/` is empty); signal inputs are stated read-only, so a CVA's value
  cannot be an `input()`. The wrapper-vs-bindable-control distinction that a previous eval run
  conflated is stated explicitly.

  **B-72 stays open on its own merits** — the grader defects it found are real — but no longer
  blocks anything.

  **RCA (rule 5):** no gate caught the original gap because no gate models *absence* of guidance;
  a case-sensitive grep for ten forms identifiers returning zero matches was the only signal, and a
  human ran it. **Same-class sweep:** the same grep shape would answer "what else does a stack say
  nothing about?" for other large surfaces (routing guards/resolvers, i18n, accessibility). Not run.
  That is the honest state, and it is a cheap check for whoever picks up B-42's field pilot.

- **B-58 / B-60 / B-82** — DONE **2026-08-16**, shipped together in **v0.53.0**. One cluster, one
  defect class: a structural property of a Markdown artifact that a human re-verifies by hand, that
  no instrument re-verifies at all, and whose breakage is invisible in the diff because every line
  is locally correct. Locked design + adversarial critique:
  `.claude/plans/2026-08-16-b58-b60-b82-mirror-drift-gates.md` and its `-sol-critique.md`.

  **B-58** — `template-checks` check 8 compares the **slug inventory** of `## Common Tasks` across
  `CLAUDE.md` and `AGENTS.md`: duplicates diagnosed first (a set comparison hides them), then ordinal
  inventory equality, then a zero-extraction blindness guard, then the presence rules (absent from
  both prints an explicit `OK:` naming the skip — silence is indistinguishable from a pass). It does
  **not** compare descriptions, per this entry's own original instruction.
  Found and fixed the live defect this entry was filed for and one more the entry did not know
  about: `dist/angular`'s `add-tests` line named *TestBed + `HttpTestingController`* to Claude and
  *Jasmine/Karma or Jest* to Copilot — two different test stacks shipped to the two hosts, with
  every gate green. B-57 fixed the dotnet pair by hand and missed this one. Fixed at
  `src/stacks/angular/files/AGENTS.md:100`.

  **Where the design changed under critique, and why it matters:** the first design put a per-slug
  *code-span* comparison into `template-checks` as well. That would have been wrong at the **consumer
  vantage point** — `docs-sync-check.sh:138-141` runs `template-checks` inside every consumer repo,
  and `generate-copilot.md:79` specifies Common Tasks as a condensed, model-authored list. The gate
  would have failed consumers for obeying our own generator. It moved to
  `.claude/hooks/tests/SkillListParity.Tests.ps1`, authoring-only, over the three stock dists, with
  the reason written into its header so nobody promotes it back.

  **B-60** — `validate-dist` check 12, `step-references`. Contiguity is a **run** rule over the
  numeric label sequence: a new run begins whenever a label is not `previous + 1`, and every run must
  start at 0 or 1. It never inspects the lines between items, so tables, blockquotes and headings
  inside a procedure cannot false-positive — the first design's block-breaking rule could, and could
  also silently *accept* the defect by treating a post-interruption item as a fresh run. Resolvability
  requires every numbered prose `step N` to resolve to a list label or a `Step N` heading in the same
  file, with heading lines excluded from extraction (a `### Step 3` line is a definition, not a
  reference — counting them inflated the first coverage number ~2.5x). Fenced code is blanked before
  **both** scans: three files per dist carry column-0 `N. ` lines inside fences, so a label scan that
  ignores fences is wrong on content we ship today. Out of scope and said so in the check's own
  comment: nested ordered lists, `steps N–M` ranges (0 occurrences today), unnumbered references, and
  a reference resolving against the wrong list in a multi-list file.

  **B-82** — a `DocTruth` assertion driven by an explicit `CLAUDE.md` heading → `AGENTS.md` heading
  table, asserted both directions, with the deliberate 4→1 and 2→1 merges encoded. The critique
  recommended DROP (it measures heading *topology*, not mirror *truth*); the maintainer overruled
  that and the objection is recorded both in the plan's disposition table and in the test's own
  header comment, which states plainly that deleting a section's body while leaving its heading
  standing keeps this green.

  **Verification (Maintenance rule 4 — every instrument seen to go red, by the reviewer, not the
  implementer):** the literal B-57 defect replayed (renumber `add-tests` item 1 → 0) fails both twins
  with byte-identical text; dead prose reference, zero-files and zero-prose-reference guards all red
  on both twins; a planted fenced ```` ```markdown / 1. / 3. ```` block stays green, proving the fence
  handling is load-bearing; B-82 red in three directions (CLAUDE-only heading, AGENTS-only heading,
  and a reworded mirror target); the angular code-span defect reproduced red and green after the fix.
  Full `validate-dist` green on all three dists on **both** twins.

  **Implementer/reviewer split:** implemented by codex (`gpt-5.6-sol`) across three briefed rounds
  with a checkpoint commit between each; reviewed, red-tested and committed by Claude. Two blocking
  findings came out of reviewing a *green* round-1 tree, and neither was visible in the implementer's
  own report:
  1. The bash twin of check 8 used `mapfile` and `declare -A` — **bash 4.0+ builtins in a script that
     ships into consumer repos**. `grep -rn 'mapfile|declare -A|readarray|coproc' src/core scripts
     --include=*.sh` returned only those four lines: no shipped or gate script had ever used a
     bash-4-only construct, and macOS ships bash 3.2 as `/bin/bash` while
     `generate-copilot.md:82` tells consumers to run these on macOS. Rewritten with `while read` and
     the space-delimited membership idiom already in `validate-dist.sh:70`. **Residual: not executed
     on a real bash 3.2 host** — verified by construction and `bash -n` only. Recorded, not claimed.
  2. `SkillListParity.Tests.ps1` reported **green while parsing nothing**: rewriting the list prefix
     in all six stock files left it passing. It now asserts both populations and the shared-slug
     population it actually compared. This is the B-64/B-72/B-74/B-75 class again, on a brand-new
     instrument, caught only by pointing the probe at it.

  **RCA (Maintenance rule 5) — why did no gate catch these?** All three are structural properties of
  Markdown that the existing gates deliberately do not model. The mirror gate models *verbatim
  identity* and was aimed at four sections chosen in v0.8.0, so anything condensed on purpose was
  outside its reach **by construction** — and `## Common Tasks`, the section that changes most often
  because it changes every time a skill is added, sat in that blind spot for 44 versions.
  `validate-dist` modelled *files and paths* (does this script exist, does this link resolve) and
  never document internals.
  **Same-class sweep:** the shipped docs carry a *second* numbered cross-reference grammar
  (`Verification Rule #N`, `Test leanness #N`, `Leanness #N`, `Agentic Workflow §N`) that points into
  numbered lists in a **different** file. I verified every current citation resolves (Verification
  Rules 1–11, Leanness 1–16), so there is **no live defect** — but it is the same blind spot one file
  over, and those lists are edited regularly. Filed as **B-142** with its own proportionality case
  rather than bolted on here, because "more gate is better" is exactly the reasoning Maintenance
  rule 6 exists to interrupt.

  **SECOND RCA — the release went red on CI twice before it tagged, and both causes were the same
  blind spot.** Shipped as `v0.53.0` at `9854bd2` after three release attempts. Attempt 1 died on the
  gate-runtime budget (`dist-gates 35278.5s` — the maintainer's laptop slept mid-stage;
  `Measure-Stage` uses a wall-clock `Stopwatch`. Re-run, not a ceiling change: a ceiling raised to
  absorb a laptop sleep would permanently blind the one instrument that exists to catch a real
  multi-fold slowdown). Attempts 2 and 3 died on CI with **all six Windows legs green and all three
  `linux-hooks` legs red**:

  1. The shared `TemplateFixture` had been switched to CRLF to give the new check 8 an EOL control.
     That fed carriage returns to checks 1–7 for the first time in their existence, breaking four
     tests that had nothing to do with this cluster. **Lesson: do not buy coverage for a new check by
     mutating a fixture four older checks depend on.** The CRLF control now lives in its own case.
  2. Fixing that exposed a **real shipped twin divergence**: `template-checks.sh`'s `section()`
     stripped CR from body lines but compared the *heading* with an exact string test, so on a CRLF
     checkout `## Leanness` + CR ≠ `## Leanness` and the mirror check reported four sections MISSING
     from a correct repo. The PowerShell twin was never affected. Consumer-visible, and fixed.

  **Why could no local gate catch either?** Because **MSYS opens files in text mode**: under Git Bash,
  `awk`/`sed`/`grep` receive the file already CR-stripped by the platform — verified through a file
  open *and* through a pipe. A CR-handling defect in any shipped `.sh` is therefore **structurally
  invisible on Windows**, which is the entire maintainer environment. Not "we forgot to test it" —
  *unobservable here*. The mechanism was finally proven in-memory (`awk 'BEGIN{... sprintf("%c",13)
  ...}'`), which is the only way to see it on this box, and that recipe is worth reusing.

  **Same-class sweep — what else is exposed:** every shipped `.sh` that compares a whole line
  exactly, or builds a value from `$0`/a capture without stripping CR, has the same unobservable
  exposure. `section()`/`section1()` and `common_tasks()` are now explicitly CR-safe (all via octal
  `\015`, because an awk that does not honour `\r` degrades it to a literal `r` and silently restores
  the bug). **The rest of the shipped `.sh` surface has NOT been audited for this** — that is the
  honest state, and it is the natural next item if this class recurs. Note also that the twin-parity
  fixtures cannot demonstrate CR behaviour on the maintainer box at all, so any future CR assertion
  is linux-leg-only coverage and must be labelled as such rather than read as red-tested.

  **One instrument earned its keep immediately:** `ScriptTwinParity`'s exit-mismatch assertion now
  interpolates both twins' stdout/stderr instead of two bare numbers. It turned an unreproducible red
  CI leg into a named check in one cycle — and, separately, identified B-130's last unexplained 5.1
  divergence as the corrupted `PATH`. B-130 had been open since 2026-08-08 on the strength of an
  encoding hypothesis that was wrong for both of its members.

- **B-139** — DONE **2026-08-16**. Added `.claude/hooks/tests/GateBudgetConsistency.Tests.ps1`
  (auto-discovered by `Invoke-HookTests.ps1`, no wiring needed): asserts
  `meta/gate-budget.json`'s `ceilings-seconds.total-local-gates` is at least the sum of the other
  four per-stage ceilings (chosen policy: zero margin, matching the real file's current exact-sum
  state), and separately that every required ceiling key is present and a positive number (a
  distinct MALFORMED failure, not conflated with a SUM MISMATCH). Red-tested by planting the exact
  2026-08-08 defect class (bump one stage ceiling without recomputing the aggregate) and confirming
  it fails with both disagreeing values named; also covers a correctly-recomputed fixture, a missing
  key, a non-numeric value, and the real on-disk file (all pass except the planted-defect fixture).

  Implemented by codex (`gpt-5.6-sol`) from a locked brief; reviewed and independently re-verified in
  this session (Maintenance rule 3) — full meta suite 16/16 green after moving codex's own scratch
  brief/log files out of the worktree (their presence in the tree caused the same spurious
  `WorkspaceBom.Tests`/`RepositoryPrivacy.Tests` failures B-137's delivery hit; codex's own report
  again attributed these to unrelated files rather than to its own scratch output — same
  false-attribution pattern as last time, worth naming as a recurring codex-session hygiene issue
  rather than re-diagnosing it fresh each time). No implementation defect found this round (unlike
  B-137's swallowed-stdout bug) — the diff was accepted as codex delivered it.

  **RCA (Maintenance rule 5):** no gate caught the original 2026-08-08 drift because nothing checked
  the budget file's own internal arithmetic — each per-stage ceiling revision was reviewed in
  isolation without a mechanical cross-check against the aggregate it feeds. **Same-class sweep:**
  checked `meta/context-footprint.json` (B-110's static-context budget, the closest analogue) — its
  ceilings are independent per-file/per-dist limits (40000/48000 chars, 1500 permille), not a
  sum-of-siblings aggregate, so this specific class does not recur there. Not exhaustively swept
  beyond that one analogue given this round's reviewer-budget constraint.

- **B-137** — DONE **2026-08-16**. Added `.claude/scripts/push-and-check.ps1` (maintainer-only,
  PowerShell-only — no `.sh` twin, matching `watch-ci.ps1`'s own existing exception): it pushes the
  resolved/current branch, and only when the pushed branch is in `-WatchedBranches` (default
  `master`, matching `.github/workflows/ci.yml`'s `push` trigger — documented as needing to stay in
  sync with that file) does it resolve the pushed SHA and invoke the existing, unmodified
  `watch-ci.ps1` as a real subprocess, propagating its 0/1/3 exit contract unchanged. A failed push
  never invokes the watcher at all (nothing reached origin to have an opinion about). Documented in
  `DEVELOPING.md` next to the existing "Watch any commit by hand" block.

  Implemented by codex (`gpt-5.6-sol`) per this repo's implementer/reviewer split (Maintenance model
  rule 2); this session (Claude) reviewed, independently re-ran every verification command in the
  real environment rather than trusting the self-report (rule 3), and found and fixed one real
  defect before accepting: the `-Live` git-push output path piped through `Tee-Object -Variable`
  without `| Out-Host`, which — because the enclosing function's return value is captured by its
  caller (`$r = Invoke-GitCaptured ...`) — silently swallowed the pipeline into the function's own
  output stream instead of reaching the console. Confirmed directly with an isolated repro (a
  bracketing pair of `Write-Host` calls around the call showed the git output appearing nowhere)
  before and after the fix. Practically low-severity (git's push progress mostly goes to stderr,
  which *was* reaching the console via `[Console]::Error.Write`), but the in-code comment claiming
  "stdout was streamed already" was factually false until fixed, and no automated test could have
  caught it — `PushAndCheck.Tests.ps1`'s subprocess capture cannot distinguish live-printed from
  purely-buffered output.

  **Verification (re-run independently, not from codex's self-report):**
  `PushAndCheck.Tests.ps1`: 7/7 passed (all seven cases genuinely red-tested — codex reported each
  failing at the "subject script does not exist" boundary before implementation, then green after).
  Full meta suite `Invoke-HookTests.ps1`: 14/15 files passed; the one failure
  (`RepositoryPrivacy.Tests.ps1`, a leaked `C:\Users\Costas` path at `meta/eval-results.md:1382`) is
  pre-existing on unmodified `master` and unrelated to this change (confirmed by running the same
  suite there). `git status --porcelain dist/` empty; both new `.ps1` files carry the UTF-8 BOM
  (invariant #4, byte-checked). No shipped-behavior change, so no CHANGELOG/version bump, matching
  B-88's own precedent.

  **RCA (Maintenance rule 5) — why no gate caught the original gap:** `release.ps1` step 5c's
  `watch-ci.ps1` call was the only CI-visibility wiring that existed; nothing routed the far more
  common non-release push (implementer landing commits, design-lock commits, small fixes between
  releases) through any check at all, so a red push between releases was only ever caught by someone
  manually remembering to run `gh run list`. **Same-class sweep:** `push-and-check.ps1` only covers
  pushes made *from this box via `git push`* — a PR merged through the GitHub web UI (the merge
  button) is a push to `master` this local wrapper can never observe, since it never runs on this
  machine. That residual is not closed here; it is the same "who actually watches this push" gap one
  level up, worth naming as a candidate follow-up rather than silently declaring the class closed.
  Separately: `RepositoryPrivacy.Tests.ps1` had a pre-existing failure (found incidentally, not part
  of this item's original scope) — `meta/eval-results.md:1382` leaked `C:\Users\<redacted>\...` from
  the B-129 write-up, and it had been on `master` undetected since that commit, which is exactly
  B-137's own point: nothing was watching that non-release push either. Confirmed via
  `push-and-check.ps1 -Sha f818a2c`-adjacent watch that CI was genuinely red on the merge for this
  reason (both legs, `RepositoryPrivacy.Tests.ps1` only) before the redaction below, and green after.
  Fixed in the same session rather than left open, since master was actively red: redacted to
  `C:\Users\<account>\...`, matching the scanner's own documented placeholder convention.

- **B-41** — DONE **2026-08-13**. The re-scoped DONE bar is **Claude behavioral evidence +
  Copilot hook-shape coverage (confirmed already shipping)**. Phase 1 supplied the typed Claude
  behavioral evidence. A fresh leaf-level audit confirmed Copilot event-shape coverage for every
  core hook: `AuditTrail.Tests.ps1` covers `audit-trail`, `Guard.Tests.ps1` drives `guard` through
  its Claude/Copilot surface loop, `RoutePrompt.Tests.ps1` asserts both Copilot
  `additionalContext` shapes, and the three `SessionStart*.Tests.ps1` files cover `session-start`
  (with relevant twin checks in `TwinParity.Tests.ps1`). No new assertion was built. B-23 and B-69
  are closed
  by retiring the unmaintained API-backed `tests/evals/run_evals.py` and keeping `cases.yaml` as a
  readable declarative case catalogue.

  **Cross-host evidence limitation:** Copilot `auto` mode has resolved non-deterministically to
  different vendor models (`claude-haiku-4.5` and `gpt-5-mini`) across otherwise comparable runs.
  A Claude-vs-Copilot threshold comparison would therefore confound host with model and is not
  interpretable. The open cross-host behavioral question passes explicitly to **B-43**'s host
  recertification and **B-49**'s quarterly live-fire drill, where the resolved model can be recorded
  and controlled or stratified.

  **RCA — why no gate caught the dead runner instruction:** `no-dead-instruction` encoded only the
  shell-launch grammar (`pwsh`/`powershell`/`bash` plus `.ps1`/`.sh`), so every non-shell
  interpreter was outside its matcher and a deleted Python target could false-green. The shipped-doc
  sweep found the stale `python run_evals.py` instructions in all three eval READMEs; after their
  removal, no other bare Python or Node script instruction remains. It also found legitimate,
  unguarded `npm ci` instructions in Angular and monorepo `docs/ci-integration.md` (including the
  monorepo aggregate command). Those invoke a package manager rather than a repo-relative script,
  so file-existence validation is not applicable; executable availability remains a runtime concern.
  The gate now recognizes `python <relative>.py`, the observed defect class, without pretending to
  validate all package-manager semantics.

  **RCA — host evidence blind spot:** B-98 step 2's flagship `r=0/6→6/6, p≈0.002` result is the
  first known instance of a Copilot-delivery carrier being measured entirely on Claude Code. The
  result is valid for that host but cannot establish the Copilot delivery claim; B-43/B-49 own the
  cross-host follow-through.

  **RCA — coverage-audit trap:** the adversarial remediation checked the aggregate
  `Invoke-HookTests.ps1` runner for assertion text even though that file discovers and invokes leaf
  `*.Tests.ps1` files. This **aggregate-runner/leaf-assertion trap** falsely reported missing
  coverage. Future audits of this suite must enumerate the runner's leaf files and inspect their
  live assertions, not grep the orchestration file for strings owned by its children.

- **B-135** — shipped **2026-08-12** (`## Unreleased` heads staged; not yet stamped/released). Design
  validated from scratch (not from Codex's write-up), locked as WSD-038, delta-reviewed by Codex, then
  implemented. `SECURITY_FINDINGS.md` schema replaced (`File:line`/`Description` → `Affected area
  (redacted when sensitive)`/`Repository-safe summary`, optional owner/reference, human-authorised
  opaque reference only); dotnet/monorepo `/security-review` Step 6 now makes no automatic Git
  mutation for a credential finding and only ever appends a minimised row for ordinary findings;
  Angular's false "appends findings" claim corrected to state the true no-append behavior; all three
  `security-auditor.md` definitions plus the GitHub Copilot wrapper agent now forbid returning secret
  material, partial/masked fragments, or secret-derived fingerprints; `audit-trail.ps1`/`.sh` no
  longer fall back to the original absolute path on `Resolve-Path`/`realpath` failure, instead
  recording a constant `[path-normalisation-failed]` sentinel across every fallback branch in both
  twins; new `SecurityReviewContract.Tests.ps1` (deterministic sentinel grader, red-tested against a
  planted unsafe row and a benign near-match) plus 3 new `AuditTrail.Tests.ps1` cases.

  **Implementation-round defect:** the codex implementer round lost network connectivity mid-run
  (exit 1, backend websocket unreachable) after patching ~19 of ~20 files. Verified via `git status`
  that real, mostly-correct work had already landed rather than assuming a failed exit meant no
  progress; diffed every changed file against the locked design before trusting any of it.

  **Observed red → green, found independently, not from the implementer's report (run never
  self-reported — it crashed first):** a from-scratch first run of the new tests showed 4 real
  failures, none of them in the underlying hook/content logic:
  1. Two required literal substrings in generated prose were split by a markdown line-wrap
     (`...this does\n   not suppress...`, `...header.\` Never\ningest...`), breaking `.Contains()`
     checks — reflowed so each required phrase stays on one line, in all files that had it.
  2. Angular's legacy-register paragraph was missing `do not modify the register` and `human with
     incident authority` outright (not just wrapped) — added, matching dotnet/monorepo's contract.
  3. A static-guard regex in the *test itself* used `"\$rel"` inside a **double-quoted** PowerShell
     string, which interpolates `$rel` (undefined → empty) instead of producing a literal `\$rel` for
     the regex — silently weakening the assertion until it no longer tested what its failure message
     claimed. Fixed by switching to single-quoted regex strings (see `meta/LEARNINGS.md`,
     2026-08-12).
  4. The pre-existing "Claude Write event" test never created a real on-disk file, so
     `Resolve-Path`/`realpath` was always hitting the failure branch — invisible before this task
     because the old fallback (the original path string) coincidentally still matched the test's
     loose assertion. Fixed by creating a genuine file before invoking the hook, so the success path
     is now actually exercised and distinguished from the sentinel path.

  All 4 fixed; re-ran `AuditTrail.Tests.ps1` + `SecurityReviewContract.Tests.ps1` clean (13/13 and
  6/6) on all three dists, full aggregate hook suite (`Invoke-HookTests.ps1`) on all three dists with
  zero regressions beyond one pre-existing, unrelated failure (`FrameworkDoctor.Tests.ps1` under
  Windows PowerShell 5.1 — independently reproduced on the pre-B-135 baseline via `git stash`,
  confirmed as B-130, not this item). `build.ps1` + `validate-dist.ps1` ×3 clean (markers,
  `no-meta-leak`, BOM, twin parity, hook registration, template-checks). Greenfield install smoke
  into a temp dir confirmed the new schema and sentinel both land in a real installed copy.

  **RCA — why did no gate catch the original defect, and what else is exposed to the same class?**
  No gate ever checked committed register *content* for operational-disclosure risk; `no-meta-leak`
  scans only for the framework's own development vocabulary, an orthogonal concern. The
  auditor/command output contract had no documented safe/incident boundary at all until this item —
  there was no instrument for this class before B-135, not a broken one. Sweep: `.claude/ai-audit.log`
  (found by Codex's fresh-context review, fixed in this same item, not deferred) is a confirmed second
  instance of the same class. `TECH_DEBT.md` was checked as a structurally similar committed
  free-text register and judged low-risk (its schema has no field that naturally invites operational
  identifiers) — not fixed, but named rather than silently passed over.

- **B-124** — closed **2026-08-09**, premise rejected after two independent Opus design reviews and
  a pre-registered behavioral baseline. The first fixture telegraphed its answers and was rejected;
  the corrected fixture exposes only paths/live SQL and uses non-leading prompts. On the unchanged
  v0.51.5 skill, `warehouse-fact-existing` selected **EXTEND `FactOrderLine` 2/2**, and
  `warehouse-fact-new` selected **CREATE `FactPaymentAllocation` 2/2**. One first-run new-fact row
  was falsely labelled FAIL because the grader demanded the literal `OrderLine`; its DDL correctly
  used the warehouse's degenerate `OrderNumber + LineNumber` plus `AllocationSequence`. The matcher
  was changed to those structural columns, observed red without the sequence, and green live.
  Snapshot and explicit-abstention success worlds are also retained, with red worlds for missing
  semi-additivity, map-only echo, wrong missing facts, and DDL-after-abstention. **No shipped change
  and no version bump:** the proposed eleven-axis mandatory note was disproportionate to zero
  observed failures. RCA: no gate caught the supposed gap because there was no demonstrated defect;
  the exposed class is future fact-binding regressions, now covered by the maintainer scenarios.

- **B-54** — implemented **2026-08-08** on branch `codex/b54-release-changelog-stamp`, **not yet
  released or merged** (pending independent review — see below). Codex began this item and ran out
  of budget mid-implementation with `release.ps1`'s changelog-stamping half drafted but uncommitted
  and `template-checks`'s placeholder-gate half not started; Claude resumed and finished both.

  **Part 1 (`release.ps1`, Codex's draft, verified as-is):** `Set-ReleaseChangelogHeads` now
  validates and stamps all four authored heads (root + 3 `src/stacks/*/files/CHANGELOG.md`)
  atomically — refusing on any missing, version-mismatched, or malformed head before writing any of
  them — and a new post-composition `Test-ReleaseChangelogHeads` postcondition (with
  `-IncludeDist`) refuses the release before commit unless the stamped date reached all three
  composed `dist/*/CHANGELOG.md` too. Previously only the root changelog was ever stamped.

  **Part 2 (`template-checks.{ps1,sh}`, new):** the version-stamp check now also fails when a
  changelog's head entry carries the *current stamped version* but still reads `Unreleased` instead
  of a date — the belt-and-braces half, catching a hand-authored placeholder even outside
  `release.ps1`. Discovered and fixed a Windows PowerShell 5.1-only defect in the same check while
  building it: `Get-Content` with no explicit encoding mis-decodes a BOM-less UTF-8 em dash in the
  changelog head under 5.1, garbling the failure message; switched to an absolute-path
  `[IO.File]::ReadAllText`, matching the idiom `release.ps1` already used for the same reason.

  **Live production defect found while validating this fix:** all three *already-shipped* v0.51.4
  consumer changelogs still read `## 0.51.4 — Unreleased` — the exact class B-54 exists to prevent,
  happening a third time, silently, on a release that was already tagged and CI-green. Corrected
  directly on `master` (commit `9ddc97a`, pushed) as a data-only fix (dated to match the root
  changelog's already-recorded `2026-08-08`), independent of this branch's code change, then the
  branch was rebased onto the corrected master.

  **Observed red:** the new `template-checks` case (`ScriptTwinParity.Tests.ps1`, new `It` block)
  was confirmed to fail on the unfixed scripts before the fix landed (stashed the fix, reran, saw
  `[FAIL] ... Unreleased head at the stamped version should fail`, restored the fix). The live
  v0.51.4 defect above is itself an observed-red instance in production, predating any fixture.
  `ReleaseChangelogStamp.Tests.ps1` (Codex's test) carries its own bounded legacy-fallback so its
  first case is red against the pre-fix root-only behavior by construction.

  **Observed green:** `ReleaseChangelogStamp.Tests.ps1` 3/3 under both pwsh and Windows PowerShell
  5.1. `ScriptTwinParity.Tests.ps1` 7/7 under pwsh; 6/7 under 5.1 — the one failure
  (`docs-sync-check branches and advisory prose agree`) reproduces identically on unmodified master
  with all B-54 changes stashed, confirmed pre-existing and unrelated (filed as B-130). All three
  dists (`dotnet`/`angular`/`monorepo`) composed cleanly (`git status --porcelain dist/` showed only
  the 9 expected `template-checks`/`ScriptTwinParity` files) and passed `validate-dist.ps1` fully,
  including the new check now passing against the corrected shipped changelogs. All three dist hook
  suites: 14/15 files clean, the one failure being a second, separately pre-existing 5.1-only
  `FrameworkDoctor.Tests.ps1` flake (also reproduced on unmodified master with B-54 stashed; also
  filed under B-130). Meta suite: 0 failures across 14 files.

  **RCA (why did no gate catch it twice, third time silent):** the version-stamp check only ever
  parsed the leading digits of the head line, so it structurally could not distinguish a real date
  from any other trailing text — the check's own regex made "Unreleased" and "2026-08-08"
  indistinguishable inputs. **Same-class sweep:** no other shipped gate was found doing this
  specific "parse a leading token, ignore the rest of the line" pattern against a value with a
  release-safety meaning; B-130 (filed above) is a different failure shape (host-encoding, not
  under-parsing) surfaced by the same validation pass, not the same class.

  **Deferred to actual release, not part of this commit:** the `## 0.51.5` CHANGELOG headings
  (root + 3 shipped) and the corresponding `framework-version.json`/`CLAUDE.md` version bump.
  Pre-adding a bumped heading without also bumping the version stamp fails `template-checks`'s
  existing (unchanged) drift check by design — confirmed by trying it and observing the exact
  failure — so per repo convention (see the B-63 "prepare vX.Y.Z" commit) that bump belongs to the
  single atomic release step, not to this pre-review commit.

  **Independent review round 2 (Opus, different tier — 2026-08-09):** a Sonnet-tier self-review
  found nothing; per Maintenance model rule 2 that didn't count as independent since Sonnet also
  implemented. An Opus-tier review of commit `10c89d0` returned **REQUEST CHANGES** with one real,
  verified-blocking finding and four non-blocking/nitpick findings:

  - **Blocking (fixed):** `Set-ReleaseChangelogHeads`/`Test-ReleaseChangelogHeads` required an
    already-stamped head to equal *today's* date, not merely be a valid date. A release retried on
    a later calendar day after a gate failure — the script's own banner promises this is safe — hit
    a "date mismatch" refusal telling the operator to rewrite an already-correct, already-published
    date. **Observed red** on the pre-fix committed code: a fixture stamped `2031-02-03` then
    retried with `$Date` `2031-02-04` produced four `date mismatch` problems and refused. Fixed by
    resolving the release date from any single already-agreeing stamped value across the four heads
    (falling back to `$today` only when all four still read `Unreleased`), threading that resolved
    date into the postcondition instead of a freshly recomputed `$today`, and treating a genuine
    *mix* of disagreeing dates or dated+`Unreleased` heads as its own distinct refusal (a related,
    lower-probability gap the same pass closed rather than leaving implicit). New test: `a retry on
    a later calendar day accepts an already-consistently-stamped world without rewriting the date`
    in `ReleaseChangelogStamp.Tests.ps1`, confirmed red on the pre-fix commit and green after,
    under both pwsh and Windows PowerShell 5.1.
  - **Non-blocking (fixed):** `release.ps1`'s header comment and root `CLAUDE.md` invariant #7 both
    described the shipped-changelog update as conditional ("if the release notes should reach
    consumers"); B-54 made all three mandatory on every release. Checked history first — every
    release from v0.26.0 through v0.51.4 already had a shipped entry with zero gaps, so this was
    stale wording, not a behavior change in practice. Both docs corrected.
  - **Nitpick (fixed):** `template-checks.ps1`'s `Resolve-Path 'CHANGELOG.md'` used glob-sensitive
    matching; switched to `-LiteralPath`.
  - **Non-blocking (deferred):** `release.ps1`'s changelog-head grammar (literal first `## ` line
    must be a version head) and `template-checks`'s (skips to the first version-shaped `## ` line)
    can disagree on an unusual changelog layout — fails safe in the direction observed, not
    proportionate to fix in this pass. Filed as **B-131** (an earlier draft of this entry claimed
    it was "filed as follow-up" when it wasn't yet — round-3 review caught the unsubstantiated
    claim; it is now actually filed).
  - **Nitpick (not fixed, low value):** no test pins the case where a changelog's `Unreleased` head
    is for a version that doesn't yet match `framework-version.json` (mid-authoring); reviewer
    verified by reading that the pre-existing drift branch already prevents a false positive there.

  **Independent review round 3 (Opus, same reviewer, commit `3c060f2` — 2026-08-09): APPROVE.**
  Re-extracted the helpers by AST and drove the full state matrix (fresh/retry/inconsistent/mixed)
  directly; re-ran `ReleaseChangelogStamp.Tests.ps1` 4/4 under both pwsh and Windows PowerShell 5.1
  itself rather than taking the report on trust; independently re-verified the "zero gaps" changelog
  history claim via `comm`. Three more non-blocking findings, all addressed in the same pass:
  `AGENTS.md`'s generated mirror of invariant #7 still described the shipped-changelog update as
  optional even after `CLAUDE.md` was fixed — corrected, restoring mirror parity [#2]; the
  unsubstantiated "filed as follow-up" claim above — B-131 now actually exists; and a genuinely new
  gap the round-2 fix introduced: four changelog heads that already **agree with each other** but on
  a *wrong* date (e.g. copy-pasted from the previous release and only the version edited) are now
  accepted and shipped silently, where round 1's stricter `Status -ne $Date` check would have caught
  it. Assessed as low-probability and non-blocking (the console output names the resolved date, and
  the corrected `CLAUDE.md`/`AGENTS.md` now tell an author to write `Unreleased`, not copy a date) —
  not fixed in this branch; a future-dated-head guard is cheap and worth adding but was not judged
  proportionate to hold the merge for a defect with no observed occurrence.

  **Independent review status: satisfied.** Two full rounds (Sonnet self-review did not count per
  Maintenance model rule 2; Opus round 2 found the real blocking defect; Opus round 3 re-verified
  the fix and closed the round-2 process gaps). Branch `codex/b54-release-changelog-stamp`, tip
  `3c060f2` plus whatever commit fixes round 3's three findings, is now clear to merge.

- **B-63 / B-56** — done **2026-08-08** (target v0.51.4). The audit closed B-56's
  remaining class rather than treating v0.35.0's child-Bash probe as a complete fix. The complete
  disposition is: `Framework install`, `Framework rules delivery`, `Protected-file sync`,
  `Bootstrap/adoption state`, `Hook files`, and `Mirror and version integrity` remain valid
  checkout-local structural checks; `Hook liveness` remains the actual Claude-host observation;
  `Audit trail substrate` remains a doctor-process filesystem check, not host-execution proof;
  `Wired hook shell` now treats a portable bare interpreter as deliberately unobservable and an
  absolute path as current-machine evidence only; `Guard JSON parser` derives demand from the
  actual registered Claude and Copilot `guard.sh` targets, reports `CANT-VERIFY` from PowerShell,
  and reports only on “this Bash environment” when invoked directly under Bash; `Stack toolchain`
  and `Copilot surface` now describe resolution only in “this doctor process environment,” with
  their actual-host claims left to explicit canaries. The new post-write canary requires a
  deliberate compile/type failure through the agent, the hook's own build-failure heading, a
  revert, and awareness of the throttle.

  **Observed red:** on unchanged production, the new Copilot-only-demand fixture registered
  `guard.sh` only through `.github/hooks/*.json`; the PowerShell doctor incorrectly printed
  `[OK] ... not required` instead of `CANT-VERIFY`. In the Claude-Bash fixture, a controlled parser
  visible only to the doctor-spawned child made the old PowerShell probe print `[OK]`, proving it
  was observing its inherited `PATH`, while the genuine no-Bash setup control stayed `[OK] ... not
  required`. Both defects reproduced under pwsh and Windows PowerShell 5.1. The historical-branch
  mutation reconstructs the removed function and branch between neutral, exact-once source
  anchors: with the same registrations and `PATH`, fixed production is `CANT-VERIFY` while the
  mutant is `OK`, and both keep a coherent summary and exit 0.

  **Observed green before release:** the source `FrameworkDoctor` suite passed 31/31 under pwsh
  and 30/30 under Windows PowerShell 5.1, with its one existing 5.1 invariant skip explaining that
  the host Python executable is inaccessible rather than counting it as evidence. The three
  composed distributions each passed all 15 shipped hook suites. A second composition found all
  501 generated files byte-identical (165 dotnet, 161 angular, 175 monorepo), and both validator
  twins passed all 11 checks against all three distributions. Registration matrices cover both
  twins; parser and CLI asymmetries use exact fixture-specific divergence sets; isolated command
  bins prevent the maintainer's ambient tools deciding parity. Independent review then found the
  Bash registration extractor did not match the PowerShell twin for shell-valid single-quoted
  targets/interpreters or a case-varied `BASH.EXE` basename. The permanent case pins
  `bash '.claude/hooks/guard.sh'`, `'/usr/bin/bash' .claude/hooks/guard.sh`, and
  `C:\Git\BASH.EXE .claude/hooks/guard.sh` on both twins while the existing `bash -c` command-
  position negative remains green. Before the Bash fix its first arm failed hook-target resolution;
  after it, the full source suite completes in 107.2 seconds under pwsh and 70.9 seconds under 5.1.
  The runtime optimization is confined to `FrameworkDoctor.Tests.ps1`'s B-63 parser bins; the
  shared shipped hook harness remains unchanged.

  **RCA:** v0.35.0 corrected which language performed the parser lookup but not which environment
  supplied the evidence: a child shell still inherited the doctor's `PATH`. Demand was also
  inferred from Claude's interpreter choice rather than the registered guard targets, so a
  Copilot-only Bash guard disappeared from the row. Ambient-path fixtures and whole-output parity
  comparisons hid both the invalid observation and legitimate per-surface asymmetries. The
  prevention is an explicit consumer/observation audit for every row, target-derived demand,
  `CANT-VERIFY` where the relevant host environment is unobservable, semantic row assertions,
  exact divergence sets, isolated capability worlds, a reachable historical mutation, and
  actual-host canaries for facts no local doctor process can prove. WSD-026 retains its historical
  v0.38.0 record and carries an append-only correction to the v0.38.1 portable bare-name policy.

- **B-89** — done **2026-08-08** (target v0.51.4). `src/core/scripts/sync-agent-files.ps1`'s
  `git rev-parse --show-toplevel 2>$null` fallback used the same
  `$ErrorActionPreference = 'Stop'` + native-stderr idiom that B-90 already fixed in
  `build-architecture-html.ps1`; this closes the sibling site B-90's own RCA named as still
  exposed. Wrapped the call with `$ErrorActionPreference = 'Continue'` and an explicit
  `$LASTEXITCODE` check, mirroring `watch-ci.ps1`'s `Invoke-GitQuiet`. `scripts/fidelity-check.ps1`
  (root, maintainer-only, not shipped) had the identical idiom and was fixed in the same pass.
  **Observed red:** run from a non-git directory under real Windows PowerShell 5.1, the unfixed
  `sync-agent-files.ps1` throws a terminating `NativeCommandError` naming `fatal: not a git
  repository`, exit 1. **Observed green:** the fixed script prints "No .claude/skills directory --
  nothing to sync." and exits 0, in the same non-git directory under the same 5.1 host.
  `FidelityCheck.Tests.ps1` (new, 3/3) and `ScriptTwinParity.Tests.ps1`'s new
  "sync-agent-files twins fall back to the current directory outside Git" case both pass. **RCA:**
  B-90's sweep fixed the site its own red-test targeted but did not re-run
  `grep -rn '2>\$null' --include=*.ps1 src/ scripts/` against every hit; the same idiom can recur
  anywhere a native command's stderr is redirected under `Stop`. No new gate added here beyond the
  two red-tests — B-89 itself was filed as the sweep, and the grep should be re-run again before
  assuming no third site remains.

- **B-67** — done **2026-08-08** (target v0.51.3). Check 7 in both `validate-dist`
  twins now resolves rendered single-line relative inline Markdown links from the document that
  contains them, case-exactly, accepting files and directories while rejecting paths that escape
  the dist. External URLs, pure fragments, images, fenced/inline-code examples, reference-style or
  multiline links, and anchor existence are explicitly outside this bounded grammar; this is not
  presented as a full CommonMark/network checker. The scan carries its own extracted-link floor so
  a broken regex cannot turn an empty candidate set green. The sweep exposed a real shipped defect
  in the dotnet and monorepo bootstrap instructions: an example meant for root `CLAUDE.md` rendered
  as a live `./docs/warehouse-map.md` link from `.claude/commands/`; it is now shown as literal
  Markdown syntax instead. **Observed red:** before the production change, case 32 planted
  `[B67 planted](./docs/definitely-missing-b67.md)` in a copied real dist; the PowerShell validator
  printed its old script-only OK and exited 0, so the permanent case failed. **Observed green:**
  case 32 made both twins exit 1 and name `README.md`, its line, and the missing target, while fenced
  and inline-code examples remained green; case 33 removed every rendered local link and both twins
  failed the zero-candidate floor. **Independent review found four twin/boundary gaps:** the first
  PowerShell draft accidentally stopped checking script commands inside fences; bash truncated
  angle-bracket targets containing spaces; malformed/control percent escapes differed; and links to
  the dist root were rejected. Case 34 now locks fenced-command parity, angle-bracket spaces, malformed
  and control escapes, encoded traversal, and root-directory links across both twins. Both twins then passed all
  three composed dists with 35 relative inline links each. **RCA:** the original gate defined a dead instruction only as an executable
  command, so navigational instructions had no extractor, resolution rule, count, or planted
  failure. The fix extends the existing document-reference gate rather than introducing a parser or
  dependency disproportionate to the observed local-link defect.

- **B-95** — done **2026-08-08** (meta-only; no shipped version). Both `validate-dist` twins now
  derive and check the input inventory for marker, JSON, shell, and PowerShell scans; zero inputs,
  enumeration failures, and read failures are findings, while successful lines state the actual
  nonzero population. The filed premise was narrowed during audit: checks 2 and 3 already failed an
  enumerated unreadable file as invalid, but did not distinguish the read failure; the shared live
  defects were zero-input vacuity and uncaptured enumeration status, plus check 1's definite
  fail-open read path. **Observed red:** before the validator changes, an empty dist and zero
  JSON/shell/PowerShell populations each produced `OK` and exit 0. After adding a permanent
  Windows file-sharing fixture, restoring the old marker catch/ignore behavior made a locked
  `README.md` produce `OK ... (165 files scanned)` and exit 0, so the case itself exited 1.
  **The independent post-merge review found the first closure incomplete:** it had one read-failure
  fixture for check 1, only regex evidence that clean counts were nonzero, no syntax mutants for
  checks 1–4, no spaced-root or selector-conflict coverage, and no parser-child failure fixture.
  Its line-shaped dispatcher also omitted an `It` registration that appeared after an inline
  conditional. The remediation derives registrations from the suite AST and rejects nonliteral,
  duplicate, or orphan-skip registrations. **Observed remediation evidence:** case 26 used real
  Windows deny-sharing locks for all four input types and both twins named the unreadable file; this
  caught a second real defect before closure, because both PowerShell parser paths initially called
  `Parser.ParseFile` without first probing readability and mislabeled its nonthrowing read error as
  invalid syntax. Case 27 independently enumerated each scratch dist and matched exact clean counts
  of 165 files, 6 JSON, 16 shell, and 34 PowerShell files on both twins. Case 28 rejected combined
  `--content-only`/`-Check` selectors with exit 2 on both twins; case 29 preserved a dist-root path
  containing spaces on both; case 30 made marker, JSON, shell, and PowerShell syntax mutants fail
  for their named reason on both; and case 31 replaced `pwsh` with an exit-17 shim and observed the
  bash validator's named parser-child failure. The AST dispatcher immediately exposed the omitted
  jq/python parity case: its name-only probe accepted Windows' broken Store `python3.exe` alias and
  its fallback called helpers absent from this meta harness. An execution-probed, self-contained
  fallback then passed the focused parity case (1 passed, 0 failed, 0 skipped). On POSIX, the read
  fixtures use `chmod 000` only after a capability probe proves the current user cannot still read
  the file; otherwise they are an invariant-guarding skip, never a false pass. **RCA:** no gate caught the original gap because
  success was inferred from an empty failure collection without first proving that enumeration and
  reads had produced a population. The remediation itself was under-tested because one marker-lock
  example and four broad nonzero regexes were generalized into claims about four distinct read and
  parse paths, while the dispatcher was trusted through the same source-text shape it consumed.
  The same class had already been removed from checks 6–8 by B-92; this closes checks 1–4 without a
  generic scanner framework or production fault-injection API.

- **B-71** — done **2026-08-08**. The harness already had prominent invariant-skip reporting from
  v0.46.0, but the filed 5.1 case still tested only PATH and used an ordinary skip. The doctor suite
  now resolves Windows PowerShell locally by trying the application on PATH and then
  `$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe`; the same result drives its
  healthy fixture default and its explicit 5.1 compatibility run. Genuine absence is now a named
  invariant skip. **Observed red:** with PATH restricted so `Get-Command powershell.exe` returned
  nothing while the standard executable existed and ran, the new permanent fallback case failed
  because `Resolve-WindowsPowerShell` did not exist; the file reported 20 passed, 2 failed. **Observed
  green:** after the local resolver was added, that exact case and the explicit 5.1 doctor run both
  passed; the file reported 21 passed, 1 failed. The remaining failure is the pre-existing
  PowerShell/bash parser-vantage mismatch in the Copilot-arguments fixture, tracked by B-63/B-85 and
  not presented as B-71 success. **RCA:** no gate caught the silent coverage loss because ordinary
  skips counted inside a green summary and capability was inferred from PATH spelling rather than
  the installed host. The same class exposed other invariant skips; the harness-level prominence
  fix already shipped, while this change closes the concrete false-absence probe without adding a
  shared resolver framework.

- **B-106** — done in **v0.46.0** (`d329c7c`); its still-open strategic heading was stale and is
  corrected here without another product release. That release added permanent sandboxed
  `route-prompt.sh` cases for no `jq`, a working interpreter available only as `python`, and the
  Windows Store alias stub; changed the five spelling-dependent skips to execution probes; and
  added doctor fixtures proving both the working-interpreter and Store-stub outcomes. Fresh direct
  evidence on 2026-08-08: `RoutePrompt.Tests.ps1` passed 13/13, including all three fallback
  controls. `FrameworkDoctor.Tests.ps1` executed and passed the B-106 cases (working `python`, Store
  stub, no interpreter, and the load-bearing mutation); its file-level result was 20 passed, 1
  failed because the PowerShell twin could not observe `bash` on this maintainer host while the
  shell twin could, an unrelated host-vantage mismatch tracked by B-63/B-85 rather than hidden as a
  B-106 success. **RCA:** implementation and release evidence were appended elsewhere in this
  ledger by the v0.46.0 change, but the original strategic heading was not closed. Keeping live and
  completed state in two sections allowed the contradiction; B-114's heading-integrity gate catches
  duplicate ids, not stale status, so closure still requires explicit release bookkeeping review.
- **B-90 / B-93** — done **2026-08-08**; B-93 was one call site in B-90's class and was absorbed.
  Both the maintainer and shipped test harnesses now bind PowerShell child subjects to the suite's
  current executable instead of preferring `pwsh`. The call-site audit found no current consumer
  that needs a 5.1 parent to upgrade its child: hooks can be registered with `powershell`, and the
  installers, doctor, generator, and release fixtures support both hosts. The aggregate runners may
  still choose `pwsh`; a suite invoked directly under 5.1 now remains honest. **Observed red:** in
  fresh child processes, both unchanged real harnesses were launched by
  `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` but selected PowerShell 7, and the
  identity probe exited 23; the reachable PowerShell 7 control selected itself and exited 0.
  **Observed green:** after the central change, both real harnesses selected their identical parent
  executable under both 5.1 and 7, with all four fresh probes exiting 0. **RCA:** no gate caught the
  false evidence because the harness helper encoded availability preference while its name implied
  current-host identity, and aggregate runs normally start under `pwsh`, hiding the distinction.
  Once the harness became honest, the architecture fixture went red under 5.1: an expected failed
  `git rev-parse` probe became a terminating `NativeCommandError` outside a worktree. The generator
  now lowers error preference only around that native probe and checks its exit explicitly.
  The same class exposed every child subject using that helper, so the fix was made at both helper
  definitions rather than at B-93 alone; aggregate-runner host choice remains a separately stated
  boundary, not evidence that every suite was exercised under 5.1.

- **B-108** — closed **2026-08-08** with no product change after design and adversarial review
  rejected the remedy as disproportionate. The filed inventory was itself inaccurate: the current
  composed distributions contain seven affected shell files and ten probe sites, not fifteen
  copies, and every observed site now implements the same execution-verified candidate order
  (`python3`, `python`, `py`) despite differing shell syntax. No current behavioural failure was
  reproduced. Normalising six stack overrides plus core hooks/doctor, shipping a canonical fragment,
  and adding twinned lexical validators would police formatting rather than runtime behaviour and
  introduce quoting/comment false-positive risk. The actual residual safety gap is behavioural:
  B-106 already owns permanent no-`jq` fallback tests across the affected surfaces and is the right
  next work. **RCA:** B-104 was missed because the change and review used a spelling-dependent grep,
  not because multiple correct spellings are intrinsically defective. The same class is exposed
  wherever an audit infers behavioural coverage from one textual spelling; future sweeps must derive
  their population from composed artifacts and prove behavior with executable fixtures.

- **B-122** — done **2026-08-08** (meta-only; no shipped version). Sanitized 16 incidental
  maintainer paths while preserving 14 intentional identity/URL lines, made three canary defaults
  relative to `APPDATA`/`USERPROFILE` with explicit overrides, and added an auto-discovered privacy
  test over tracked plus non-ignored untracked files. B-109's three concrete fixtures are assembled
  dynamically, so no fixture exemption weakens the gate. Red-before-green against the real
  pre-change tree: 20 concrete paths found (16 machine details plus four fixture/evidence lines),
  `EXIT=1`; focused post-change suite: 6/6, `EXIT=0`. WSD-035 records that HEAD is clean while old
  published commits retain the metadata. **RCA:** the prior privacy boundary scanned only composed
  distributions, so maintainer scripts, transcripts, plans, and records were outside its population.
  The same class exposes any non-ignored authoring-tree text file; the new gate derives that complete
  working-tree population from Git rather than maintaining a directory list.

- **B-109** — done **2026-08-08** (meta-only; no shipped version). Extended the shared
  `no-meta-leak` denylist to reject Windows user profiles and Linux/macOS home directories while
  retaining generic documentation placeholders. Added a real-dist regression covering all three
  forms on both validator twins. Red-before-green: a planted Windows user-profile path passed both
  validators (`EXIT=0`) before the change and
  failed both afterward (`EXIT=1`); the focused four-form test passed on both legs, full
  `validate-dist.ps1` passed all three dists, and the meta suite passed 11 files with zero failures.
  **RCA:** no gate caught the original leak because check 6 encoded only development vocabulary,
  not host identity or filesystem provenance. The same class exposes any shipped textual artifact
  containing an account-qualified home path; the new cross-platform patterns sweep the entire
  composed distribution without recording a maintainer's identity in the denylist itself.

- **B-114** — done **2026-08-08** (meta-only; no shipped version). Renumbered the lower-reference
  v0.48.0 post-ship review entry from B-113 to B-123; the CI-cancellation entry retains B-113 and
  its existing CHANGELOG references. `DocTruth.Tests.ps1` now extracts live item headings using
  their full `### B-nnn ·` grammar, fails on duplicate ids, and refuses a vacuous zero-id scan.
  Red-before-green: the unchanged backlog passed the old six-case suite despite its duplicate;
  the new check first reported `duplicate live backlog item ids: B-113`, then passed after the
  renumber. **RCA:** no gate caught it because no test parsed backlog identities. Concurrent filing
  exposes every identifier allocated by reading the current tail; the recurrence gate scans the
  complete live-item population rather than special-casing B-113.

- **CI watch, 2026-08-04:** one linux run failed `route-prompt twins agree: security (Copilot)` with
  `ps1=139 sh=0`. Exit 139 is SIGSEGV — the pwsh child crashed on the ubuntu runner; the harness
  recorded the crash faithfully rather than a behavioural divergence. It did **not** reproduce on a
  re-run of the same commit and did not appear on the two earlier runs of the same tree, and the
  commits in question touch no `dist/`, `src/`, or `route-prompt` file. Recorded as an observation,
  not a defect: if it recurs, it is a real bug in a shipped hook on Linux and deserves its own entry,
  and this note is the second data point.

- **B-92** — done 2026-08-04 (meta-only; no version; commits `61257f6`, `c247797`, `97bea4a`, CI
  green on both legs). Three false greens in check 8 reproduced first, then closed; the RCA sweep
  extended the fix to checks 7 and 6. **What CI caught after three local runs said green** — a
  Linux-only `Permission denied` and a Linux-only `-Force` enumeration hole that would have made
  `no-meta-leak` inspect zero hooks and zero skills there. Both are filed as B-70's third and fourth
  instances. Verified: 16 passed / 0 failed / 1 skipped under pwsh 7 **and** Windows PowerShell 5.1;
  both twins exit 0 on all three dists with identical counts; meta suite 0 failures across 8 files.
  The `python3` parser branch cannot run on the maintainer's box at all — CI is its only instrument,
  and it is green there.

- **B-92 (original entry)** — done 2026-08-03 (meta-only; no version). `validate-dist` checks 6–8 now have
  structural anti-vacuity guards in both twins, hook registrations are parsed as JSON, and the new
  real-dist regression suite exercises the PowerShell and bash legs. Check 7 remains limited to its
  inline-command grammar; B-67 owns broader markdown-link coverage. The maintainer selected B-92
  before the unordered P2/P3 items on 2026-08-03; **B-89** is the recommended next item because its
  Windows PowerShell 5.1 defect is consumer-visible. Check 7's rewrite also removed the predictable
  `/tmp/_dead_$$` path it used to write (no temporary file is created now), so the entry filed for
  that during this change was withdrawn rather than shipped.

- **B-86** — the post-ship review v0.44.0 owed, done 2026-08-03 (meta-only; no version). Three
  findings filed: **B-92** (P2), **B-93** (P2), **B-94** (P3). The adversarial pass was run by
  **codex CLI `gpt-5.6-sol`** in a separate session — a different model, which is what Maintenance
  model #2 asks for and what a second Claude session cannot supply; its report is kept as the
  evidence trail at `.claude/plans/2026-08-03-b86-codex-review.md`.

  **Every finding was re-run here before it was filed**, per Maintenance model #3 and the standing
  rule that an implementer's self-report can be a false pass. Re-run, with the observed result:

  | # | re-run | observed |
  |---|--------|----------|
  | 1 | check 8, six `"command"` keys renamed in a scratch `settings.json` | `OK: all 20 hook registrations resolve`, EXIT 0 → **B-92.1** |
  | 2 | check 8, `session-start.ps1` repointed at `C:/definitely-missing/` | `all 26 … resolve`, EXIT 0 on **both twins** → **B-92.2** |
  | 3 | check 8, quoted `-File \"… definitely missing.ps1\"` (valid JSON) | `all 26 … resolve`, EXIT 0 → **B-92.3** |
  | 4 | live `$expectedPathPattern` vs `src/*.tmp`, `meta/*.txt`, `.claude/*.log` | all `allowed=True` → **B-94.1** |
  | 5 | scratch repo: pre-staged `src/a.txt`, then guard refusal | `BEFORE=src/a.txt` → `AFTER=` → **B-94.2** |
  | 6 | scratch repo, `core.quotepath` **unset** (default), non-ASCII path | `"meta/caf\303\251.txt"`, `MATCH=False` → **B-94.3** |
  | 7 | `Get-PsExe` probed from a 5.1 host | returns `pwsh` → 7.6.4 → **B-93** |
  | 8 | **`HarnessIntegrity` red-test under Windows PowerShell 5.1** | control EXIT 0; `@()` stripped from the harness → EXIT 1 → **no finding** |

  **The flagship instrument is sound.** (8) is the one that mattered most and it holds: with the
  v0.41.0 defect re-planted, the mutant printed `3 passed,  failed, 0 skipped` — the `$null` visible
  in the summary — and still exited 1, because the file scores itself independently of the harness.
  That is the design working exactly as its header claims. Run with `powershell.exe` by **absolute
  path** (`$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe`); it is present as
  5.1.26100.8875 and **not resolvable from `PATH`**, re-confirming B-71's live evidence.

  Two corrections the re-run made to the findings as first written, both left visible: the
  git-quotepath case needs **no** unusual configuration (quoting is the default, so the review's
  "with `core.quotepath=true`" understated it), and the in-directory stray of B-94.1 **is** surfaced
  by the unconditional staged manifest, which drops it from a premise-rejection to a record
  overclaim. A finding weakened by evidence is still evidence.

  Also observed: v0.44.0's own CI run **failed** (run 30740988544), as did the three commits after
  it, and `master` is green again only from `8265daf` — the record B-88 was filed on, confirmed
  first-hand rather than read from its entry. Nothing was fixed in this pass, by design: the review's
  product is findings, and fixing them here would collapse reviewer into implementer.

- **B-88** — landed 2026-08-02 (meta-only; `.claude/` never ships, so no version). `release.ps1`
  step 5c watches the CI run for the release commit between the verified `origin/master` push and the
  tag, via a new `.claude/scripts/watch-ci.ps1` (0 green / 1 red / **3 CANT-VERIFY**) and a callable
  `Get-CiPublishDecision` in `.claude/scripts/_ci-decision.ps1`. **WSD-029**; `DEVELOPING.md` has the
  recipe.

  **Shipped stronger than the entry asked, and deliberately.** The entry said "after the tag push
  succeeds"; step 5b's own comment already claimed *"a tag always means a green release"*, so
  watching after the tag would have made that sentence false while the drill protocol checks out the
  latest tag. The watch went **before** the tag instead and the tag became the promotion step: red or
  unverifiable leaves the commit on master **untagged**, and the release exits 1 or 3. The entry's
  real constraint (don't gate the commit on CI) is untouched. This is B-83's class caught in the act
  — the *Do* was written before the reading that contradicts it.

  **Verified, not asserted.** Live against real history: `-Sha a41ab8d` → EXIT 0 on the genuinely
  green run, `-Sha fc3a140` → EXIT 1 on one of the four red ones — real `gh`, real auth, real JSON,
  under **both** PowerShell hosts. `ReleaseCiWatch.Tests.ps1` is 21 cases (18 + 4 self-test), 0
  skipped, green on pwsh 7 and Windows PowerShell 5.1. Its `-SelfTest` plants four recorded
  mutations and asserts the named case goes red for each, with a control run against the unmutated
  watcher first. Both `release.ps1` wiring assertions were red-tested by mutating the real file
  (watch relocated after the tag; the old `exit 0` restored) and observing each fail alone.

  **Four defects found in this work's own instruments, all by red-testing them:**
  1. **A unary comma over-wrapped the parsed rows**, so `$_.event` returned *every* row's event and
     `-eq 'push'` matched a non-empty result — truthy. A failed `pull_request` run for the same sha
     would have decided the release.
  2. **Windows PowerShell 5.1 does not enumerate a top-level JSON array**: `@('[{a},{b}]' |
     ConvertFrom-Json).Count` is **1** under 5.1 and **2** under pwsh 7 (measured). Same consequence
     as (1). `-NoEnumerate` does not exist in 5.1, so the flatten is explicit.
  3. **5.1 raises a terminating `NativeCommandError` for a native command's stderr** under
     `$ErrorActionPreference='Stop'` — `2>$null` redirects the text but not the record. `git rev-parse`
     against a non-repo killed the script with *no output at all* under 5.1 and worked under 7.
  4. **The test fixture was one string, not three.** In PowerShell `,` binds tighter than `+`, so
     `'[' + (New-Row) + ']', '[' + (New-Row) + ']'` is one 656-char concatenation. The polling case
     was exercising a payload that could never parse.

  (2) and (3) were invisible until the suite was made to run the watcher under **its own host**
  rather than `Get-PsExe`'s — which prefers pwsh 7 whenever it resolves. That is verbatim B-74's
  finding, one release later, in new code. Single-row payloads survive (1) and (2) *by accident*, so
  only the multi-row cases could ever see them.

  **Scope limits, recorded rather than glossed:** this notifies and withholds a tag; it does **not
  prevent** a red commit reaching `master` (direct-to-master is B-53's decision). It does **not close
  B-70** — the per-leg job check narrows that exposure, it does not replace it. And no end-to-end
  release was run: ordering and the decision mapping are covered, real parameter binding is not, so
  the next release is part of this change.

- **B-74** — shipped as **v0.44.0**, 2026-08-02. `src/core/tests/hooks/HarnessIntegrity.Tests.ps1`
  plants a fixture with **exactly one** failing test (one, not two: two or more returned a real
  integer and were always caught; one is the shape that hid) and asserts non-zero at both levels —
  the suite file's own exit code and `Invoke-HookTests.ps1`'s sum — with passing controls at each so
  a harness hard-wired to fail would not satisfy it.

  **Two defects in the test itself, both found by red-testing it and both the class it exists to
  close.** (1) The first cut ran its fixtures through the harness's `Get-PsExe`, which prefers pwsh 7
  whenever it resolves — so every fixture ran under pwsh 7 even when the suite ran under 5.1, and the
  one host where the defect exists was never the host under test. With `@()` reverted, the file
  passed. Fixtures now run under `(Get-Process -Id $PID).Path`. (2) It was **scored by the component
  it tests**: with the defect planted it correctly printed `[FAIL]` and then exited **0**, because
  the summary scoring it was the broken one. It now computes its own exit code from `$script:Tests`.
  Every other suite file may trust `Write-TestSummary`; this one provably may not.

  **Evidence:** defect planted → 5.1 `EXIT=1`; restored → `EXIT=0`. Under pwsh 7 green either way —
  recorded as a documented blind spot, not a pass. Dist suites 13 files × 3, 0 failures.

- **B-62** — shipped as **v0.44.0**, 2026-08-02, **with its premise corrected rather than executed.**
  The entry's *Do* ("fail on a bare interpreter name in a shipped settings file") contradicts
  **v0.38.1**, which deliberately reverted absolute-path interpreter pinning because
  `.claude/settings.json` is committed team configuration and a machine-specific path breaks every
  teammate on another OS or profile. A bare name is the *intended* shipped value; the check as
  written would have failed every settings file on purpose. Whether a bare name *resolves* is a
  runtime property no build-time check can observe — v0.39.0's `Hook liveness` doctor row already
  reports that from the consumer's own machine.

  The real gap was that **nothing read the registration files at all**: check 2 proved they parse as
  JSON, check 7 scanned only `*.md`. `validate-dist` check 8 (`hook-registration`, both twins) now
  resolves every reference in `.claude/settings.json`, `.claude/settings.windows.json` and
  `.github/hooks/hooks.json`, requires the opposite-language twin [#3], and rejects an unsanctioned
  interpreter. 26 registrations per dist. Extraction is textual and identical in both twins by
  decision: the bash leg's JSON parser is python3-or-jq depending on the box, so parsing there would
  leave whichever branch a machine lacks untested — B-59's inert-check class.

  > **Superseded 2026-08-04 by WSD-030 (B-92).** The textual-extraction decision recorded in the
  > paragraph above was *reversed*: registrations are now parsed as JSON, because that decision was
  > the direct cause of two of B-92's three false greens (a vacuity floor that was a second regex
  > over the same bytes, and a quoted `-File` value the regex could not read). The concern it names
  > was real and is now handled by coverage rather than by avoidance — `VALIDATE_DIST_JSON_TOOL`
  > pins the branch so both can be exercised and diffed, and the two CI legs run different ones.
  > The paragraph is left standing rather than rewritten, because the reasoning is why the reversal
  > needed its own decision record.

  **Band:** the delivered check is **P2-shaped, not P1**. The P1 severity came from silent dead
  hooks, which v0.39.0 covers consumer-side; this is build-time consistency. Recorded rather than
  silently re-banded — reopen if that reading is wrong.

  **Evidence:** red-tested on both twins against a scratch dist across three defect classes (renamed
  hook in `settings.json`, missing target in `hooks.json`, a hook stripped of its `.sh` twin); both
  legs produced byte-identical findings, and both exit 0 on all three real dists. A normalization
  bug surfaced during the red-test and was fixed: translating each backslash separately turned
  `.claude\\hooks\\x.ps1` into `.claude//hooks//x.ps1`, which resolves on Windows *and* POSIX and so
  hid the sloppiness instead of failing on it; runs of backslashes now collapse to one separator.

- **B-80** — done **2026-08-02** (meta-only, no version/CHANGELOG). `release.ps1` classifies the
  staged set before committing: a mode-`160000` gitlink is a **hard refusal with no escape hatch**
  (this repo has no submodules, so it is always a mistake), and a path outside where the repo keeps
  files refuses unless `-AllowExtraStagedPaths` is passed. The manifest prints either way, and a
  refusal `git reset`s so the index is left as found. Classification happens *after* staging because
  that is the only point at which mode `160000` exists — an unadded worktree is merely untracked
  (verified against `90f331d`, where both strays present as `:160000 000000 … D`).

  **A confirmation prompt was considered and rejected**: `release.ps1` runs non-interactively, where
  `Read-Host` reads EOF as empty — a guard treating that as "proceed" is worse than none, and one
  treating it as "refuse" is a refusal with extra steps. Hence a named escape hatch, per
  `-AllowNonMasterHead`.

  **The allowlist's first cut would have refused every release from v0.39.0 to v0.43.0.** Written
  from this entry's own wording (`src/`, `dist/`, `CHANGELOG.md`, `meta/context-footprint.json`, the
  stamps), it produced **10 false positives** replayed over the last 8 tags: every release touches
  `README.md`, and v0.41.0 touched `.claude/hooks/tests/`. A release commit carries the whole
  session's work, not the stamped set. The question it asks is now "is this file somewhere this repo
  keeps files at all?" — the actual scratch-file hazard.

  **Evidence:** `.claude/hooks/tests/ReleaseStagingGuard.Tests.ps1` (6 tests, auto-discovered by the
  meta suite, so the guard is re-verified at every release). It extracts the guard **verbatim** from
  `release.ps1` rather than re-typing it, is bounded at both ends, and replays the last 8 tags so the
  allowlist cannot silently narrow again. Red-tested by mutation: narrowing the allowlist → 1 failed;
  making the gitlink check inert → 1 failed; restored → 6/6. Meta suite 6 files, 0 failures.

  **The test's own first cut was inert twice**, both caught before landing: the extraction ran to the
  `# ---- 6.` marker and swept in the commit+push (green cases really committed, then failed to push
  to a nonexistent origin) while the marker sanity-check passed, because a too-*large* region still
  contains every marker; and the allowlist replay used a bare `[0]` on a single-match `[string]`,
  yielding its first *character*, so the pattern extracted empty and `-notmatch ''` classified 266
  paths as clean. Both now have assertions that fail rather than agree vacuously.

- **B-45** — done **2026-08-01** (meta-only, no version/CHANGELOG). Root `CLAUDE.md` gained a
  **Maintenance model** section: five rules (locked design + adversarial critique that may reject the
  premise, with a reviewer's corrections treated as input not verdict; implementer ≠ reviewer with an
  auto-filed post-ship review when tiers are equal; nothing enters the record as observed unless you
  observed it *in the environment that matters*; a green result counts only from an instrument seen to
  go red; close every delivery with an RCA). The original entry listed six rules — four of them were
  one rule in four costumes and were consolidated, and the RCA rule was added because it was practised
  but written down nowhere in the repo, which made root `CLAUDE.md`'s "nothing resolves to private
  `~/.claude` memory" claim false. **Crucially the rules are not prose-only:** an adversarial pass
  argued that a prose section plus a "the heading exists" check is theatre in a repo whose whole
  history is *prose did not hold the line*, so rules 2–4 are enforced by `release.ps1`, which now
  refuses to start without `-ReviewEvidence` or an explicit `-NoIndependentReview`, records the
  outcome in `meta/review-ledger.md`, and auto-files the post-ship review item when there was none.
  Mirrored to root `AGENTS.md`; recipes and the concurrency hazard to `DEVELOPING.md`. WSD-028.
- **B-47** — done **2026-08-01** (meta-only, no version/CHANGELOG). MIT `LICENSE` at repo root,
  copyright Costas Andreou, plus a README **Licence** section. The repo was public with no licence
  file since the 2026-07-01 audit, so default copyright made every documented install legally void.
  Posture decided by the maintainer: MIT, **root only**. The dist-travel half was deliberately
  deferred — consumers copy `dist/<stack>/` contents into their own repos and those copies still
  carry no licence text — and is filed separately.
- **B-51** — done **2026-08-01** (meta-only, no version/CHANGELOG). `release.ps1` creates, verifies
  and pushes an annotated tag after the gates and the commit succeed, so a tag always means a green
  release; the historic gap was backfilled. Verified 2026-08-01: 33 tags present, v0.42.0 and v0.43.0
  both tagged by the script during this session.
- **B-53** — done **2026-08-01** (meta-only, no version/CHANGELOG). `release.ps1` refuses to release
  when HEAD is not `master` (escape hatch `-AllowNonMasterHead`, named for what it risks), pushes the
  **commit** rather than the branch name, and asserts afterwards that `origin/master` actually
  advanced to it. Verified 2026-08-01: the branch guard refused a release attempted from a worktree
  branch, and both v0.42.0 and v0.43.0 printed the confirmed-at-origin postcondition.
- **B-73** — done **2026-08-01** (meta-only, no version/CHANGELOG). Two defects, both fixed:
  `release.ps1` now refuses a `-Summary` mangled by MSYS path conversion (the v0.40.0 commit subject
  is permanently corrupted by it), and it states its runtime up front. The runtime notice was itself
  wrong — it claimed "roughly 30 minutes" and had never been measured — and was corrected to a
  measured 5–7 minutes in v0.43.0, which also cut the gate phase 385s → 285s.

- **B-61** — shipped as **v0.41.0**, 2026-08-01. Behavioural twin parity extended from
  `.claude/hooks/` to the shipped `scripts/` twins. New shipped `tests/hooks/ScriptTwinParity.Tests.ps1`
  runs both twins of `template-checks`, `docs-sync-check`, `sync-agent-files` and `metrics` against one
  fixture; `framework-doctor` gained two **non-pending** cases so `Stack toolchain`, `Mirror and version
  integrity` and `Audit trail substrate` are twin-compared for the first time; a maintainer-only
  `.claude/hooks/tests/ScriptTwinCoverage.Tests.ps1` fails on any twin pair that is neither exercised
  nor given a written reason. `RunArg` was promoted into `_HookHarness.ps1` (array args) and
  `WikiCheck.Tests.ps1`'s shadowing local copy deleted.

  **The harness immediately found three divergences that were already shipping** — which is the item
  working, not a surprise:
  1. `metrics.sh` was missing test-integrity counters, by a **different amount per stack** (dotnet +2,
     angular +2, monorepo +4). Two adversarial review passes were needed to get this inventory right;
     the first revision of the plan asserted three keys common to all three stacks and was wrong.
  2. `docs-sync-check` twins printed different prose — four punctuation sites and two whole sentences.
  3. **The test harness itself could not go red** (see the RCA below).

  **Contract decisions, recorded so they are not re-litigated:** comparison is of the **ordered**
  `OK:`/`FAIL:` sequence, never a set (a set hides ordering and duplication defects); exactly two
  normalizations exist, both by name and both commented — `template-checks`' by-design check-6
  asymmetry and a script naming its own sibling twin — with a static assertion that fails if the
  check-6 exemption ever widens. `impact-run` is deliberately **not** behaviourally tested: it needs an
  external agent CLI, git worktrees and paid API calls, and `tests/impact/config.json` *ships*, so a
  naive "missing config" case would fall through the guard and start a real agent run in a consumer
  repo. Case-sensitivity parity is deliberately not asserted (belongs to **B-59(b)**), and the
  `Stack toolchain` regex-vs-glob branch stays unexercised; both are stated in the test rather than
  implied as coverage.

### RCA of v0.41.0 — filed 2026-08-01

**Finding 1 (fixed in this release): the shipped test harness scored a failing suite as green.**
Under Windows PowerShell 5.1, `(… | Where-Object …).Count` on a pipeline yielding **exactly one**
object returns `$null`. `Write-TestSummary` therefore returned `$null`, `exit (Write-TestSummary …)`
became **exit 0**, and `Invoke-HookTests.ps1` — which sums child exit codes — scored the file green
while printing `[FAIL]`. Two or more failures in one file returned an int and were caught, so this hid
precisely the **lone regression**, the most common shape of a fresh break. pwsh 7 returns 1 for the
same expression, which is why CI and the maintainer box never saw it. Reproduced under 5.1 (exit 0
before, exit 1 after) rather than argued. Consumers on 5.1-only boxes — the configuration
`settings.windows.json` exists to serve — were exposed; the shipped changelogs tell them to re-run.

*Why did no gate catch it:* nothing tests the harness that reports test results. B-64 asks that gates
and diagnostics be red-tested; the **reporting layer beneath them** was not in anyone's scope.

*What else is exposed to the same class:* swept every `.ps1` under `src/`, `scripts/` and `.claude/`.
Contained — `framework-doctor.ps1` already used `@()`, and the `metrics.ps1` counters go through
`Measure-Object`, which always returns a real object with a real `Count`. The harness was the only site.

- **B-57** — shipped as **v0.36.0** (guidance) and **v0.37.0** (enforcement), 2026-07-31, WSD-025.
  Field report from a brownfield .NET install on NUnit: the reviewer's complaint was that the
  framework kept pushing xUnit instead of following the suite already in place. Six surfaces stated
  xUnit as fact while Verification Rule #10 and `bootstrap.md`'s Phase 3a synthesis guard both already
  forbade exactly that. Fixed by reusing B-35's evidence-keyed block pattern in `docs/defaults.md`
  § Testing, neutralising `copilot-instructions.md` and the skills-list one-liners, adding a Step-1
  evidence gate to `add-tests` (the .NET branch had hardcoded while Angular already derived from
  `angular.json`), branching `enforce-standards` across xUnit/MSTest/NUnit, and teaching
  `ArchitectureTests.sample.cs` to translate off xUnit. v0.37.0 then closed the enforcement half: the
  guard blocked only `[Fact(Skip=…)]`, so NUnit and MSTest repos got a weaker floor than xUnit ones.

  **Split into two releases deliberately.** The guard regex is the only part that can regress working
  behaviour — an unanchored pattern hard-blocks `public enum Mode { None, Ignore, All }` — so it did
  not ride along with prose changes. That judgement was vindicated: an adversarial review of the plan
  found five blocking defects, four of them in the regex (invalid POSIX bracket syntax that makes
  `grep` exit 2 and silently disables the `.sh` twin; `\s` unsupported by BSD grep; `-match` vs
  `grep -E` case divergence; and a missed `[TestCase(…, Ignore = …)]`, the direct analogue of
  `[Fact(Skip=)]`). All four were confirmed by execution before any code was written.

  Deliberate non-changes, recorded so they are not re-litigated: `tests/impact/tasks.json` keeps
  naming xUnit (the prompt is a direct instruction, the harness runs greenfield, and a held-constant
  prompt is what makes A/B scoring meaningful); `[Explicit]` is not blocked (legitimate NUnit idiom,
  and blocking it would make the framework stricter on NUnit than xUnit). Spun out: **B-58**.

- **B-16** — implemented for **v0.32.0** (2026-07-17). Added the locked WSD-023
  `framework-doctor.{ps1,sh}` design: nine ordered machine checks with verified/pending/missing
  states, explicit human canaries for agent-only facts, parserless bash fallback, PowerShell 5.1
  compatibility, installer/docs handoff, and fixture tests including the fresh-install and
  missing-shell failure modes. The doctor diagnoses only; `docs-sync-check` remains the CI gate.
  **Review finding fixed before merging (PR #1):** the Claude-hooks canary quoted a session-start
  banner that no shipped hook emits ("## AI Tech Lead - Session Context"; the real first line is
  "## Session preload") — exactly the WSD-023 F9 pinned-string hazard, and the F6 failure mode in
  reverse: a developer with *working* hooks would have concluded they were broken. Fixed in both
  twins (canary now also observable via asking the model, since SessionStart stdout is context,
  not chrome), and a new anti-rot test case pins every doctor-quoted string to the hook sources
  it cites (red-tested against the unfixed doctor: caught it). Accepted deviation from the spec:
  row 6 keys off the installed `template` stamp instead of `@stack` markers — one byte-identical
  core file, less drift surface; and the `.sh`-only Copilot CANT-VERIFY branch is a documented
  twin divergence (PowerShell always has a JSON parser).

- **B-40** — shipped **v0.31.0** (2026-07-17). SQL / data-warehouse guidance (WSD-021, design
  `.claude/plans/2026-07-16-b40-sql-dw-guidance-design.md` — locked and implemented same-day
  after an adversarial review of the implementation plan folded in 11 findings). Two new
  dotnet-stack skills: **`map-warehouse`** (discovery: layers incl. consumption views/marts,
  fact/dim entities + grain statements, load orchestration/ordering, batch/watermark control,
  SCD strategy, partitioning; offers `docs/warehouse-map.md`) and **`add-warehouse-load`**
  (recipe: mirror the sibling load, grain-first entity design, idempotent loads — watermark /
  batch-ID dedup / delete-window / merge+row-hash / versioned-runs semantics — SCD mechanics,
  dims-before-facts orchestration, partition alignment, deployment vehicle, sign-off
  checklist). Both gated Step-0 on two-tier evidence (SQL-repo artifacts AND ≥2 DW signals
  grepped inside SQL artifacts only — hardened against xUnit `[Fact]`/prose false positives).
  `/bootstrap` A2 detects SQL-project/stored-proc repos + DW signals; Phase 3a got a three-way
  keep/delete rule and exemplar-pins `add-warehouse-load`; `defaults.md` gained raw-SQL and DW
  evidence blocks; `add-entity` cross-routes warehouse tables. Ships to dotnet + monorepo
  (angular untouched bar the every-version changelog entry). All B-35-consistent; T-SQL as
  evidence-gated illustration only.

- **B-34** — shipped **v0.30.1** (2026-07-16). Implemented via a codex (gpt-5.6-sol) implementer
  under principal-engineer review, closing the render-parity gap B-32 left open on `guard` and
  `audit-trail`. **`guard`**: aligned the PowerShell twin's secret-type labels from ASCII `...` to
  the canonical ellipsis `…` (matching `guard.sh` exactly — e.g. `AKIA…` not `AKIA...`), and
  switched the Copilot deny-JSON construction from a plain `@{}` hashtable to `[ordered]@{}` so key
  order is deterministic and matches the bash twin's fixed `printf` format
  (`permissionDecision`/`permissionDecisionReason`/`hookSpecificOutput`) byte-for-byte — without
  `[ordered]`, PowerShell hashtable enumeration order is hash-based and not guaranteed to match.
  **`audit-trail`**: confirmed it has **no model-visible output at all** (both twins produce empty
  stdout/stderr on a real write event) — its drift was comment-only (`--`/`—`), fixed as a Boy
  Scout pass rather than a behavior change. **Test coverage**: extended the existing
  `guard-cases.ps1`-driven `TwinParity.Tests.ps1` block (not a new fixture table) to assert ordinal
  byte-equality of both stdout and stderr across all 16 guard cases × both surfaces (Claude/
  Copilot), on top of the pre-existing decision-only check. **Red-tested for real**: transiently
  reverted the `AKIA…` fix back to `AKIA...`, confirmed the new assertion caught it on both
  surfaces (`RED_EXIT=2`), then restored and reran clean. Left `post-write`/`session-start`/
  `route-prompt` untouched (out of scope — the backlog's "consider extending to post-write" note
  was optional; the primary deliverable came first and codex correctly didn't let it crowd that
  out). **Verified:** build ×3 + freshness; `validate-dist` ×3 exit 0; all three dists' hook suites
  0 failures across two independent full runs; PS-AST parse + BOM independently spot-checked (not
  just trusted codex's report). Released via `release.ps1`, all gates green, pushed.

- **B-36** — shipped **v0.30.0** (2026-07-16). Implemented the LOCKED WSD-020 design
  (`.claude/plans/2026-07-15-b36-testing-strategy-design.md`) via a codex (gpt-5.6-sol)
  implementer under principal-engineer review. **D1** — `add-tests` (all three stacks × `.claude`/
  `.github` mirrors, 6 files) gains a new symmetric **Suite bootstrap mode** section, entered from
  Step 1 when Grep finds no test project/spec files at all: confirm framework + location with the
  developer first (a real checkpoint), scaffold the minimum (one unit-test project + an HTTP
  integration fixture only if warranted, no E2E/coverage tooling day one), wire into existing
  CI/build, order first tests risk-first (hazard areas → financial invariants → critical journeys
  → domain logic), and record the remainder as one honest `TECH_DEBT.md` entry instead of implying
  coverage. **D2** — each stack's Feature workflow rail (`workflow-bullets`) gained an identical
  one-line parenthetical pointing at `Conventions > Testing` / the Test shape heuristic for level
  selection and the suite-bootstrap escape hatch, kept tight given the rail's always-loaded token
  budget. **D3** — `/bootstrap` (all three stacks) makes suite state a first-class output: the
  testing pass (`A5`/dotnet+monorepo, `A6`/angular, both subsections in monorepo) states "no test
  projects" as its *primary finding* rather than folding it into "coverage gaps"; Phase 3a's
  Conventions synthesis now requires ending `Conventions > Testing` with a one-line target test
  shape; Phase 3b writes a Severity-High `TECH_DEBT.md` entry naming suite-bootstrap mode as the
  fix, surfaced in the Phase 4 top-3 quick wins. Monorepo's dual-stack structure was handled
  correctly throughout (not copy-pasted) — both A5/.NET and A6/Angular testing passes got the
  primary-finding treatment, and the Phase 3b/3a/Phase-4 wording was generalized to "per affected
  stack" rather than assuming a single stack. **D4** — one routing line in each stack's
  `defaults.md` Testing section pointing "no test suite yet?" at `add-tests`. **Verified:**
  build ×3 + freshness; `validate-dist` ×3 exit 0 (re-run independently, not just trusted); the
  composed `dist/monorepo` skill/rail/bootstrap text spot-checked directly (not just "compose
  succeeded"); grep-confirmed the D1-D4 strings landed in all three composed dists (codex caught
  its own tooling mistake mid-verification — a non-`--hidden` `rg` search missed the dot-directory
  `.claude`/`.github` skill mirrors, silently reporting 0 matches — corrected and re-verified);
  a real greenfield install-smoke confirming the installed `add-tests` SKILL.md carries the suite-
  bootstrap routing/checkpoint/risk-first text; context-footprint measured (+178 chars per
  `CLAUDE.md`, monorepo-to-largest-stack ratio *improved* slightly to 1.159×, well under the 1.5×
  ceiling) — the un-updated baseline correctly FAILed pre-release (expected; `-Update` is
  `release.ps1`'s job, deliberately not run here). No hook/script changes, so hook suites are
  unaffected (spec's own call). Shipped in the same release as B-39 phase 2 (below) — one version
  bump covering both. Released via `release.ps1`, all gates green, pushed.

- **B-39 (phase 2)** — shipped **v0.30.0** (2026-07-16, same release as B-36 above). Implemented
  via a codex (gpt-5.6-sol) implementer under principal-engineer review. The shipped
  `src/core/tests/hooks/Invoke-HookTests.ps1` runner (single-source, composes byte-identically
  into all three dists) now runs its `*.Tests.ps1` files through a bounded 4-slot `Start-Job`
  worker pool instead of serially — each test file still runs as its own fully isolated external
  `pwsh`/`powershell` process (an extra process layer versus the job-orchestration process itself,
  which safely satisfies the B-37-discovered constraint that `_HookHarness.ps1`'s `Invoke-Hook`
  mutates process-global console encoding and must never share a runspace). Output is buffered per
  file and replayed in fixed name-sorted order after all children finish, preserving the exact
  `=== Hook test suite: N failure(s) across M file(s) ===` summary contract and `exit $total`
  behavior every caller (including `release.ps1`) depends on. The separate hand-maintained
  meta-only fork (`.claude/hooks/tests/Invoke-HookTests.ps1`) was correctly left untouched — out of
  scope. **Measured (real dist tree, dotnet):** serial 136.611s → parallel 91.999s (32.7%
  reduction); also confirmed green under Windows PowerShell 5.1 (89.661s). **Red-tested for real:**
  planted a failing assertion in one test file, confirmed it stayed visible through the buffered
  output (`[FAIL] PLANTED runner propagation failure`), the aggregate count and exit code (1)
  reflected it, and every other file still ran and reported correctly — then removed the plant and
  hash-verified its complete removal from every dist copy. **Verified:** all three dists'
  `Invoke-HookTests.ps1` (using the new parallel code) ran green (0 failures across 10 files) with
  individual wall times noted; `validate-dist` ×3 exit 0; PS-AST parse + BOM independently spot-
  checked (not just trusted codex's report). Shipped in the same release as B-36 — one version
  bump covering both. Released via `release.ps1`, all gates green, pushed.

- **B-39 (phase 1)** — done **2026-07-16** (meta-only, no version/CHANGELOG — process-only change
  to a maintainer script, per invariant #7's scoping to *shipped* behavior). Implemented via a
  codex (gpt-5.6-sol) implementer under principal-engineer review. `.claude/scripts/release.ps1`'s
  step 4 now runs the three per-dist gate pairs (`validate-dist.ps1` then that dist's
  `Invoke-HookTests.ps1`) as three concurrent `Start-Job` child processes (true process-level
  parallelism — a runspace-based approach was rejected per the B-37-discovered constraint that
  `_HookHarness.ps1` mutates process-global `[Console]::OutputEncoding`, which is unsafe to share
  across in-process runspaces) instead of serially; each dist's combined output is buffered to a
  temp log and replayed in fixed `$dists` order (dotnet, angular, monorepo) after all three jobs
  finish, so the release log stays readable rather than interleaving three suites' output.
  Both exit codes (`validate-dist`, hook suite) are gated per dist exactly as before — the
  existing `Gate` helper, its `$fatal` accumulation, and the REFUSED-exit messaging are untouched.
  **Measured (maintainer box, real dist trees, not a fixture):** serial baseline 418.46s
  (dotnet 139.6s / angular 137.6s / monorepo 141.2s) → parallel 247.12s — a 41% wall-time
  reduction (less than the spec's ~2.5min ideal-case estimate, since real concurrent process
  contention on one box doesn't hit the theoretical best case; still a substantial, honestly
  reported win). **Red-tested for real:** first attempt (renaming `.template-repo`) was a false
  negative — `validate-dist` doesn't actually check that file — caught and corrected to a defect
  class the validator does gate (`dist/angular/scripts/template-checks.ps1` missing), confirmed
  `GATE FAIL: validate-dist angular` + `$fatal=$true` with the hook suite still running and
  passing independently (both statuses are recorded per-dist regardless of the other), file
  restored, worktree left clean. **Independently re-verified** (not just trusted codex's
  self-report): PS-AST parse clean, BOM intact, a live green single-dist run, and a from-scratch
  repeat of the red test executing the literal code extracted from the file (not a retyped copy) —
  same result. Phase 2 (parallelizing `Invoke-HookTests.ps1`'s internal test files, a shipped
  change) remains open — see B-39 (phase 2) above.

- **B-38** — done **2026-07-16** (meta-only, no version/CHANGELOG — process-only fix to a
  maintainer script, per invariant #7's scoping to *shipped* behavior). Implemented via a codex
  (gpt-5.6-sol) implementer under principal-engineer review. `.claude/scripts/release.ps1`'s
  README version-stamp logic now distinguishes "line missing/reworded" (still FATAL, `exit 2`)
  from "line already carries the target version" (the state a *refused* release leaves behind,
  since stamping happens in step 2 but gates run in step 4) — the latter now skips the write and
  prints `README already stamped $Version (retry after a refused release).` instead of dying with
  a misleading "no such line" error. All three `Release REFUSED` exit points gained a one-line
  "safe to re-run as-is" hint. **Review finding fixed before merging:** the codex diff left
  `Write-Host "Stamped src + root README -> $Version ($today)."` unconditional after the if/else,
  so the already-stamped branch would have printed both "README already stamped…" and
  "Stamped src + root README…" together — self-contradictory (claims a stamp that didn't happen).
  Moved that line inside the `else` so only one message prints per branch. Audited the other three
  stamp steps (CHANGELOG `Unreleased`, core `CLAUDE.md`, the three `framework-version.json`s) for
  the same idempotency class — confirmed already-idempotent, left unchanged as the plan specified.
  **Verified:** PS-AST parse clean, BOM intact; independently re-ran (not just trusted codex's
  self-report) a standalone harness against temp README copies driving all three states —
  already-stamped (exit 0, file unchanged, single correct message), older-version (exit 0,
  rewrites), line-missing (exit 2, FATAL, unchanged) — all green post-fix. Full-loop confirmation
  (a real refused release hitting this path) deferred to the next occurrence per the plan; note
  the result in `meta/LEARNINGS.md` then.

- **B-21 (implementation)** — shipped **v0.28.0** (2026-07-16). Implemented the LOCKED WSD-013
  design (`.claude/plans/2026-07-06-b21-reviewer-profile-design.md`) via a codex (gpt-5.6-sol)
  implementer under principal-engineer review. **D1** — `bootstrap.md` Phase 4 + `adopt.md` Phase 8
  emit a prioritized "Paste this into your PR (or commit message)" judgment checklist (INFERRED
  conventions / unsure-or-tooling-only hazards / adopt-4a defaulted contradictions / discovered
  skills); bootstrap suppresses under `/adopt` (Phase 8 sole emitter via the Phase-2b adopt signal),
  bootstrap gains a commit/PR nudge, adopt-4a writes a durable `<!-- DEFAULTED: … -->` marker that
  Phase 8 re-scans. **D2** — `session-start.{ps1,sh}` (core twins) resurface hazard rows whose ISO
  `Reviewed` date is >90 days old (interval math, GNU-`date` guard, inside `$body`/`emit_body` for
  the Copilot surface); `bootstrap.md` 3d-bis pins `Reviewed` + the not-a-hazard status to ISO
  `YYYY-MM-DD`. **D3** — rendered ladder legend + "merging the PR does not confirm these" above the
  hazard table (was inside a non-rendering HTML comment); ladder tokens kept as machine anchors.
  **Structural correction** (see LEARNINGS 2026-07-16): the pre-merge spec's "one `src/core` edit
  per artifact" was stale — bootstrap.md/adopt.md/FRAMEWORK-CONTEXT.md are stack whole-file overrides,
  so this was a ×3 edit (invariant #1), only session-start is core; cross-stack inserts confirmed
  byte-identical. **Verified:** new `SessionStartHazard.Tests.ps1` (19 cases, red-tested against the
  pre-D2 HEAD hook then green on both twins incl. confirmed-stale + Copilot dual-shape); build ×3 +
  freshness; validate-dist ×3; dotnet dist hook suite 0 failures across 10 files (TwinParity 40/40).
  Released via `release.ps1`. **B-22 (headless `/adopt`) is now unblocked** (its hard dependency
  B-21 D1 shipped).

- **B-35** — shipped **v0.29.1** (2026-07-16). Implemented the LOCKED WSD-020 design
  (`.claude/plans/2026-07-15-b35-derive-dont-assume-design.md`) via a codex (gpt-5.6-sol)
  implementer under principal-engineer review. **D1** — new Verification Rule 10 ("Derive, don't
  assume") added to `verif-rule9` snippets in all three stacks (dotnet/angular/monorepo — the
  principle generalizes beyond ORM to HTTP client/state management/test framework, so it applies
  to angular too, not just the two EF-affected stacks). **D2** — dotnet + monorepo
  `docs/defaults.md` Data Access restructured into evidence-keyed blocks (EF Core / Dapper /
  MongoDB.Driver / none-detected); "Test shape" line genericized. **D3** — `/bootstrap` A2 opens
  its persistence detection list (EF Core/Dapper/ADO.NET/MongoDB.Driver/Cosmos/Redis/other/none)
  and Phase 3a gains a no-unevidenced-technology synthesis guard, dotnet + monorepo. **D4** —
  `add-entity` (`.claude` + `.github` mirrors, dotnet + monorepo) gains a Step 0 EF-evidence gate;
  bootstrap 3a Common Tasks audit gains a persistence-check line. **D5** — `boy-scout-check`
  heuristic #3 (4 files: dotnet + monorepo × `.ps1`/`.sh`) now requires an EF marker
  (`Microsoft.EntityFrameworkCore`/`DbContext`/`DbSet<`) in the same file before flagging missing
  `AsNoTracking()` — MongoDB's identically-named `ToListAsync`-family methods no longer misfire.
  **D6** — `copilot-instructions.md` (dotnet + monorepo) genericized ("data-access layer" instead
  of "DbContext"). New shared test cases added to the existing core `TwinParity.Tests.ps1` (not a
  new file — reused invariant #1's single-source test surface, angular skips via a guard since it
  doesn't carry the hook): Mongo-shaped query → zero findings, EF query without AsNoTracking →
  still flags. **Review finding fixed before shipping:** the angular consumer CHANGELOG entry
  copy-pasted the dotnet wording ("no longer assumes EF Core") verbatim — meaningless to an
  Angular consumer who never had EF Core guidance; reworded to name the actually-relevant
  technologies (HTTP client, state management, test framework). **Verified:** build ×3 + dist
  freshness; `validate-dist` ×3 exit 0 (all three, incl. skills-mirror sync); all 3 dists' hook
  suites 0 failures (dotnet `TwinParity.Tests` 42/42, up from 40/40 — exactly the 2 new cases) +
  meta suite 0 failures (`InstallerContract` 12/12). Released via `release.ps1`, all gates green,
  pushed.

- **B-22 (implementation)** — shipped **v0.29.0** (2026-07-16). Implemented the LOCKED WSD-014
  (Path A) design (`.claude/plans/2026-07-06-b22-headless-adopt-design.md`). Headless `/adopt`
  **prepares** adoption autonomously (auto-branch, archive, provenance + adversarial screen,
  impact baseline) and **stages** every `CLAUDE.md`/`TECH_DEBT.md` merge for a human to apply at
  PR review — the prompt-injection boundary is held by stage-don't-apply + quarantine-exclusion +
  a restricted tool surface, not by `disable-model-invocation` (a prompt wrapper ignores that
  anyway, so the boundary holds on the Copilot leg too). `adopt.md` ×3 gained a normative
  `## Headless mode` section (per-gate override table, restricted tool surface, marker/guard
  lifecycle, embedded-bootstrap headless propagation); `bootstrap.md` ×3 Phase 3d-bis auto-takes
  "skip all — mark as unverified" under headless; `adopt.prompt.md` (core) documents the
  `--headless` directive; `install.{sh,ps1}` twins + marker `nextStep` offer the headless entry
  alongside the developer path. **Structural correction** (same class as B-21's): the pre-merge
  spec's "single `src/core` edit" assumption was stale — `adopt.md`/`bootstrap.md` are stack
  whole-file overrides (×3), only the prompt wrapper + installers are core.
  **Deviation** (see `meta/LEARNINGS.md` 2026-07-16, B-22): the plan was to drive codex
  (gpt-5.6-sol) with `--dangerously-bypass-approvals-and-sandbox` as in B-32/B-21, but a
  relayed/cross-session authorization doesn't clear the bypass gate for a nested codex — the
  reviewer implemented directly instead (same edits, same review + gate verification). **Verified:**
  compose ×3 + `git status dist/` self-consistent (15 expected files); `validate-dist` ×3 exit 0
  (markers, template-checks/AGENTS mirror, no-meta-leak, no-dead-instruction); meta suite 0
  failures incl. `InstallerContract` 12/12 (both modes × both twins × 3 dists) and generated
  consumer marker JSON valid on both twins; dotnet dist hook suite 0 failures. Released via
  `release.ps1`, all gates green, pushed.

- **B-37** — shipped **v0.27.1** (2026-07-16). Post-ship review of v0.27.0 (B-27 team wiki
  memory) against the locked WSD-010 spec found six defects, all fixed: GNU-only `date -d`
  failing every valid `last-verified` on macOS agents (F1); both wiki-check twins reading
  `$Root` from stdin, hanging interactive `docs-sync-check` runs (F2); locale-dependent index
  sort — bare `sort` vs culture `Sort-Object`, the B-02 skew class — pinned to byte/ordinal
  order in both twins (F3); the D4/D9 boundary-doc touchpoints that never shipped (F4); the
  `.sh` hook's Copilot-JSON wiki delivery untested (F5); and a pre-existing harness bug —
  `Invoke-Hook` decoded child stdout with the console code page, so v0.27.0's "hook suites
  green" held only on UTF-8 consoles (F6, reproduced red under ibm850, fixed by pinning UTF-8
  around the capture). Fix loop: Opus 4.8 (scripts + tests) and Sonnet 5 (docs) implementers
  under Fable 5 review; verified by red-testing the F1/F3 classes and re-running both wiki
  suites green (13 + 10) under a non-UTF-8 code page. Observation logged, NO action (locked
  design): the D6 injection-marker list hard-FAILs benign descriptions containing "instead
  of" — revisit only on consumer evidence.

- **B-32** — shipped **v0.26.5** (2026-07-15). Implemented from the LOCKED spec
  (`.claude/plans/2026-07-11-b32-context-footprint-gate-design.md`, WSD-017) via a codex
  (gpt-5.6-sol) implementer + principal-engineer review loop — five review rounds, three real
  defects found and fixed before shipping (see `meta/workspace-decisions.md` WSD-017 for the
  implementation-deltas log: baseline path retargeted to `meta/context-footprint.json`, a
  pre-existing `.ps1` hook Unicode-mangling bug the fixtures caught, and two PowerShell
  correctness bugs in the gate script itself — `Measure-Object -Property` silently returning
  zero on `[ordered]` hashtable items, and a double-array-wrap that corrupted derived totals).
  Twins `scripts/context-footprint.ps1/.sh` ship as genuinely independent implementations (not
  a delegating wrapper — the first implementer's initial cut had `.sh` shell out to `.ps1`,
  rejected on review since it defeats the CI cross-OS twin proof). **Forced an unplanned
  shipped-behavior fix**: the rendered-hook fixtures proved `dist/*/.claude/hooks/{session-start,
  route-prompt}.ps1` rendered ASCII-flattened rails (`WARNING:`/`--`) where the `.sh` twins emit
  the designed `⚠`/`—`/`→` text, **and** that redirected `.ps1` hook stdout on Windows was
  encoded with the OEM code page, silently turning `⚠/—/🔴` into `?` for every consumer who
  runs the PowerShell hooks — both fixed (UTF-8-on-redirect guard + byte-identical rendered
  text), which is why this shipped as v0.26.5 rather than landing with no version slot as the
  design anticipated. `B-34` filed for the same rendered-parity sweep on `guard`/`audit-trail`
  (out of scope here). Verified: 30-pair cross-twin render matrix, baseline generation +
  idempotent `-Update` + cross-twin byte-identical proof, full red-test matrix (freshness drift,
  twin-render-mismatch detection, WARN-ceiling reachability), all 4 hook suites + `validate-dist`
  ×3 green (the one expected pre-stamp `validate-dist` FAIL — CHANGELOG at 0.26.5 vs
  `framework-version.json` at 0.26.4 — resolved by `release.ps1`'s own stamp-then-validate
  order). Released via `release.ps1`, all gates green, pushed.
- **B-27** — shipped **v0.27.0** (2026-07-16). Implemented from the LOCKED spec
  (`.claude/plans/2026-07-04-b27-wiki-memory-design.md`, D1–D10, WSD-010 + its 2026-07-11
  monorepo-retargeting appendix) via a codex (gpt-5.6-sol) implementer + principal-engineer
  review loop — two implementation rounds, five real defects found on review and fixed before
  shipping:
  1. `wiki-check.sh`'s injection-signal character class matched the INDEX grammar's own
     mandatory em-dash under real UTF-8 collation, FAILing every syntactically valid entry —
     reproduced directly, rewritten as `LC_ALL=C` byte-exact UTF-8 matching mirroring the `.ps1`
     twin's codepoint ranges.
  2. `wiki-check.sh` didn't resolve a native Windows-style root path (exactly what the
     `Invoke-Hook` test harness passes) — fixed with separator normalization + `cygpath`.
  3. `install.ps1`'s D8 copy-if-absent fix had diverged structurally from the `.sh` twin (a full
     per-file rewrite of the whole copy loop vs. the twin's surgical `docs/`-only special case,
     an invariant #3 twin-parity violation and an oversized blast radius) — restored to match.
  4. Three separate wiki-related doc insertions (`CLAUDE.md` companion-preamble line, Common
     Tasks bullet, self-review bullet ×3 each; `ci-integration.md`'s wiki-check line ×2) had
     landed tripled/duplicated — none in the 5 verbatim-gated mirror sections, so
     `template-checks` passed clean despite it; caught only by direct file reading, deduped.
  5. The shipped `_template.md` carried a leading HTML comment not present in the locked D2
     template, breaking its own frontmatter contract (`first line must be ---`) the moment an
     entry was drafted from it literally — caught by an actual skill smoke test (draft-from-
     template, not a synthetic fixture), fixed by removing the line (principal-engineer fix,
     not round-tripped — trivial one-line deletion).
  Also confirmed and corrected: every other hook-suite failure the implementer reported
  (`AuditTrail`, `PostWriteRouting`, `RoutePrompt`, `SessionStartWiki`, `TwinParity`) was its
  sandbox's Git Bash failing to start (`CreateFileMapping ... Win32 error 5`), not a real defect
  — confirmed by rerunning every suite in a working shell, all green throughout both rounds.
  **Verified:** `build.ps1` fresh ×3 + `git status --porcelain dist/` stable; `validate-dist.ps1`
  ×3 clean (markers, JSON, `bash -n`, PS-AST, `template-checks`, `no-meta-leak`,
  `no-dead-instruction`); all 3 dists' `Invoke-HookTests.ps1` 0 failures across 9 files each
  (`WikiCheck.Tests` 11/11, `TwinParity.Tests` 40/40); meta suite (`DocTruth`,
  `InstallerContract`, `MetaHooks`, `WorkspaceBom`) green; install smoke greenfield + brownfield +
  update ×3 dists all `EXIT=0`; `docs-sync-check` ×3 clean; `wiki-check` run directly against the
  real committed `dist/*` wiki dirs (both twins agree); live guard-hook fixture (a fabricated AWS
  key in a `docs/wiki/*.md` write) blocked with exit 2, proving the generic secret-scan already
  covers wiki writes with no wiki-specific code needed; hands-on skill smoke (draft from the
  corrected template → passes wiki-check with only an expected body-level WARN → single
  entry/single INDEX line, proving the dedup-not-duplicate mechanics hold). Released via
  `release.ps1`, all gates green, pushed.
- **B-33** — done **2026-07-12**, then **REOPENED AND RE-FIXED THE SAME DAY** when tested on the
  second surface. The README fix below was **Claude-only**: given the archived repo's URL, **Copilot
  never opens the README** — it clones and runs `scripts/install.ps1` directly, and duly installed
  the frozen **v0.25.5** template straight past a STOP banner it never read. The first "verified
  red→green" claim was made on one surface of a two-surface product, which is to say it was not
  verified. **Final fix: a hard refuse-and-redirect at the top of all four frozen installer twins**
  (print the STOP, `exit 1`, copy nothing) — the one channel both surfaces demonstrably obey.
  Re-tested on Copilot against the archived URL: now redirects and installs **v0.26.4**, committed,
  correct handoff. Claude path provably unaffected (guard commit touched only `scripts/install.*`).
  Repos re-archived. Lesson in `meta/LEARNINGS.md`: *documentation is advisory; executable output is
  not.* Original README work below — still correct, just not sufficient on its own.

  Both archived
  pointer READMEs rewritten, verified, and re-archived. **The hypothesis was right and the mechanism
  was worse than filed.** Reproduced end-to-end: an agent given the old URL and *"install this
  framework into our repo"* on a clean machine read the archive banner, **rationalised past it, and
  installed the frozen v0.25.5 template** — citing the banner's own words as its warrant: *"its content
  (and the byte-for-byte-identical installer) still works, and the URL you gave me is exactly this
  repo, so I installed from it as asked."* Two causes: **(1)** the only *imperative, agent-addressed*
  text on the page was the preserved §1 (*"If you are an AI agent reading this repository, start
  here"*) telling it to run the installer **there**; the archive notice was human-voice prose the model
  felt free to weigh against it and discount. **(2)** The banner's reassurance — *"reproduces this
  template byte-for-byte … moving is an update, not a behavior change"* — was written to comfort a
  human and **armed the agent**: it reads as *the old one is equivalent, so installing it is fine.* It
  was also no longer true. Fix: banner now addresses agents first and humans second; §1 is a STOP that
  redirects; the equivalence claim is gone. Re-tested identically → installs **v0.26.3**, commits in
  the target, hands off correctly. Red→green: `0.25.5` → `0.26.3`. Repos re-archived.
  Lesson in `meta/LEARNINGS.md`.

- **B-22 (P0 design)** — done **2026-07-06** (meta-only; implementation stays open, post-merge).
  Design locked as **WSD-014**, spec at `.claude/plans/2026-07-06-b22-headless-adopt-design.md`
  (rev-2). Adversarial critique returned **RETHINK** — it proved the non-negotiable
  prompt-injection boundary forbids auto-merging untrusted content into `CLAUDE.md` (a keyword
  denylist was the only automated filter). Surfaced the constraint-1-vs-2 conflict to the
  maintainer, who chose **Path A** (prepare autonomously, human applies merges at PR review) over
  Path B (constrained auto-merge, residual risk). rev-2 folds both HIGH findings (auto-merge
  breach; embedded `/bootstrap` 3d-bis stall) + M3–M7/L8–L9: invocation via the read-and-execute
  prompt pattern (drops the spike; both surfaces), provenance-exemption for installer-archived
  originals, marker/branch lifecycle pinned, restricted tool surface for untrusted-content
  handling. Depends on B-21 D1; implementation ≥ v0.28.0 in the merged repo.
- **B-21 (P0 design)** — done **2026-07-06** (meta-only; implementation stays open, post-merge).
  Design locked as **WSD-013**, spec at `.claude/plans/2026-07-06-b21-reviewer-profile-design.md`.
  Re-scoped after finding two of the three original fixes already partly shipped; three deltas
  designed (D1 judgment checklist into PR/commit, D2 session-start hazard resurface, D3 rendered
  ladder legend). Adversarially critiqued (LOCK WITH AMENDMENTS): 2 HIGH + 4 MEDIUM + 4 LOW
  folded — notably D2's date mechanism rewritten to real interval math with an ISO-pin on
  3d-bis, D1 given a real landing site + durable `<!-- DEFAULTED -->` trace, and a corrected
  (false) B-27 dependency. Implementation is B-21's remaining open work, ≥ v0.28.0 in the merged
  repo. The B-21 entry above carries the pointer.
- **B-31** — shipped **v0.25.5** (2026-07-06). Angular's `.claude/settings.windows.json` was
  missing the `audit-trail.ps1` PostToolUse registration — a gap the B-14 port missed (it wired
  `settings.json` + `hooks.json` but not the PS-5.1 fallback), found by the B-25 adversarial
  review. PS-5.1-fallback Angular consumers silently had no audit log while the v0.25.3
  CHANGELOG claimed one. Fixed (registration line byte-matches dotnet), and `check-lockstep`
  gained a §5 `settings.json`/`settings.windows.json` registration-parity gate
  (`event|matcher|command` sets; `_comment` ignored) with a planted-drift self-test
  (`CheckLockstep.Tests.ps1` B-31 case, red-before-green: the new gate first failed the old
  synthetic fixture, then 5/5). Released via release.ps1, all gates green, both repos pushed.
- **B-25 (decision + refresh)** — done **2026-07-06** (meta + the B-31 release). D1–D7 signed
  off (**WSD-012**); `MERGE-MIGRATION-PLAN.md` refreshed against v0.25.5 (fresh §1 evidence:
  138 files/repo, 128 common, 51 EOL-normalized-identical, 10+10 stack-only; new §2.5
  machinery-disposition table; composer twin policy resolving the WSD-005 collision; honest D3;
  D7 meta-layer fate; freeze scope; archive/tag moved after Phase 6; abort rule; freeze-tag
  fidelity baseline). Adversarial review pass reproduced every measured number and surfaced
  B-31 (fixed) + the stale-execution-sections and phase-ordering hazards (folded in).
  Execution continues as **B-25-EXEC**. WSD-010 + the B-27 design doc carry retarget notes
  (v0.27.0, merged repo).
- **B-19 · B-24 · B-28 · B-30** — shipped **v0.25.4** (2026-07-05, the "small-items sweep"; all
  gates green via `release.ps1`, both repos pushed). Per item:
  - **B-28**: `build-architecture-html` twins now byte-identical — `.ps1` gained the missing head
    newline, writes LF-only BOM-less UTF-8 via .NET (the content cmdlets added BOM + host EOLs, a
    third divergence beyond the two the entry named), and both twins stamp the neutral `{sh,ps1}`
    generator name. New `tests/hooks/BuildArchitectureHtml.Tests.ps1` (byte-identical both repos;
    red-before-green: 4 failures pre-fix → 5/5 green; fixture byte-compare + join-symptom guard).
    Both repos' `architecture.html` regenerated **with the `.ps1`** — surgical diff (generator
    line + sha + content only), proving parity in real use.
  - **B-30**: `test-critic` row added to the §5 agents table in both repos + HTML regen (filed by
    the WSD-011 adversarial review; rode the release, so B-11's no-version question was moot).
  - **B-24**: **premise correction** — the entry's "installer fallback is also PowerShell" was
    stale: `install.sh:120-127` already rewires Claude Code hooks to the bash twins when the
    installing box lacks pwsh. The real residual gap is *team inheritance*: committed
    `settings.json` carries the installing machine's wiring, so a teammate without that shell
    gets no hooks silently (and the manual-copy Quick Start path never rewires). Documented as a
    README "Hook prerequisite" callout in both repos.
  - **B-19**: (a) `post-write` trigger breadth — dotnet accepts
    `.cs|.csproj|.sln|.props|.targets|.razor|.cshtml`; angular accepts `.ts` under `src/` plus
    `tsconfig*.json` anywhere (tsconfig bypasses the `src/` gate; `angular.json`/`package.json`
    excluded by design — `tsc` can't validate them, a trigger there is false comfort). All four
    twins + header comments; filter reach verified via `bash -x` trace matrix (12 inputs, all as
    designed — full build-failure path not exercisable on this box: no dotnet CLI, no
    node_modules fixture; hook suites 2×7 files, 0 failures). (b) README versioning section now
    points at the installer's real update mode instead of the `/framework-update` vaporware.
    (c) Boy Scout dedup semantics documented in `enforcement-surfaces.md` (hash of sorted finding
    set; silence = already flagged, not resolved). Bonus: fixed stale "audit trail — dotnet only
    (B-14)" row in both repos' `enforcement-surfaces.md` (missed by the B-14 release).

- **B-14** — shipped **v0.25.3** (2026-07-05). Ported the `audit-trail` PostToolUse hook to Angular
  in dual-repo lockstep. Angular now carries `.claude/hooks/audit-trail.ps1/.sh` (faithful mirror of
  dotnet — byte-identical except the artifact skip: `node_modules`/`dist`/`.angular`/`coverage`
  instead of `obj`/`bin`; UTF-8 BOM on the `.ps1`), a byte-identical seed `.claude/ai-audit.log`,
  the `PostToolUse` registration in `.claude/settings.json`, and the `postToolUse` entry
  (timeoutSec 10, no matcher) in `.github/hooks/hooks.json`. CLAUDE.md/AGENTS.md Registers lines
  gained the ai-audit sentence. Added `tests/hooks/AuditTrail.Tests.ps1` (byte-identical in both
  repos, stack-agnostic behavior + static skip/append guards, red-before-green verified);
  TwinParity auto-covers the new twin. **Removed all three `check-lockstep.ps1` audit-trail
  exceptions** (the two `$onlyInDotnet` entries + the §4 hooks.json `-notmatch 'audit-trail'`
  special-case) — the gate now enforces full parity and passes clean. Delivered by Sonnet against
  an Opus plan (`.claude/plans/2026-07-04-b14-port-audit-trail-angular.md`); adversarial review
  caught a missing trailing newline on the Angular `.ps1` (fixed → now differs from the dotnet twin
  only in the skip line). Verified: release.ps1 ran every gate green (template-checks ×2, hook
  suites ×2 with AuditTrail 10/10, check-lockstep, meta suite), both repos committed + pushed.
- **B-12** — **already resolved; no change needed** (verified **2026-07-04**, meta-only). The audit
  inspected only the *root* `.gitignore` and missed the tracked, colocated **`.claude/.gitignore`**
  (present in both repos since v0.4.0), whose `.state/` line already ignores
  `.claude/.state/last-build-ts`. Evidence: `git check-ignore -v .claude/.state/last-build-ts` →
  `.claude/.gitignore:2:.state/` in both repos; no `.state` file tracked in either. Greenfield
  `install.sh` smoke into a temp dir confirmed the installer **ships** `.claude/.gitignore` and,
  after simulating the `post-write` stamp, git ignores it. **Correction to the audit's suggested
  approach:** adding `.claude/.state/` to the *root* `.gitignore` would have been wrong — the
  installer excludes the root `.gitignore` from the consumer copy (`$metaFiles` in
  `scripts/install.ps1`/`.sh`), so the nested `.claude/.gitignore` is the *only* vehicle that
  reaches consumers, and it is already correct.

> **Post-hoc review 2026-07-04 (Fable):** the P1 (v0.25.1) and P2 (v0.25.2) bands were
> independently re-verified — all gates re-run green (template-checks ×2, check-lockstep, hook
> suites 0 failures, meta suite), both repos clean and pushed, every claimed fix reviewed at diff
> level and confirmed genuine (incl. the epoch fix's graceful handling of stale fractional stamps
> from the buggy version). Only finding: `CheckLockstep.Tests.ps1` was created without a UTF-8
> BOM — folded into B-10. Accepted; no re-release needed.

- **B-11** — done **2026-07-04** (docs accuracy, **no version/CHANGELOG** — user-approved: invariant
  #7 is scoped to shipped *behavior*). Corrected every human-facing bootstrap pass-count reference to
  match each repo's `bootstrap.md`. **Scope was larger than the audit stated** — the drift was in
  *both* repos (angular said A1–A6/"six" but runs A1–A7), and the adversarial review found two the
  audit + plan missed: both repos' `.github/prompts/rebootstrap.prompt.md`, and angular's
  `bootstrap.md:2` frontmatter description ("eight"→"seven"). Files: dotnet — `README.md`,
  `docs/ARCHITECTURE.md` (×2 rows), `.github/prompts/rebootstrap.prompt.md`, regenerated
  `docs/architecture.html`; angular — same four + `.claude/commands/bootstrap.md:2`. **HTML regenerated
  with the `.sh` twin, not `.ps1`** (see B-28 — the `.ps1` twin emits divergent bytes and would have
  injected a generator-comment flip + `<script>`-tag change into the diff). Verified: exhaustive grep
  sweep (zero stale counts, both repos), content-only HTML diffs, all gates green (template-checks ×2,
  check-lockstep, hook suites 0 failures, meta suite). Canonical `commands/bootstrap.md` bodies,
  `bootstrap.prompt.md`, and the `bootstrap-pass` agents were already correct and left untouched.
- **B-10** — done **2026-07-04** (meta-only, no version/CHANGELOG). Added UTF-8 BOMs to 3 offenders (`.claude/scripts/check-lockstep.ps1`, `release.ps1`, `.claude/hooks/tests/CheckLockstep.Tests.ps1`). New `.claude/hooks/tests/WorkspaceBom.Tests.ps1` recurrence gate: asserts all root `.claude/` `.ps1` files carry a BOM on every meta-suite run, vacuous-pass guard included. Meta suite wired into `release.ps1` so the gate runs at every future release.
- **B-13** — done **2026-07-04** (maintainer memory, no repo change). `hook-output-semantics.md`
  updated: "shipped docs stale" removed; now records the v0.25.1 live-canary results (CLI 1.0.68
  consumes `userPromptSubmitted` additionalContext, does NOT consume `postToolUse`; folder-trust
  prerequisite; VS Code consumption still unverified). `self-sufficiency-roadmap.md` and
  `fable-exit-backlog.md` refreshed in the same pass.
- **B-02** — shipped **v0.25.1**. `post-write.ps1` epoch switched to
  `[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()` (both repos), killing the PS 5.1 comma-decimal
  `OverflowException` and the UTC/local twin-skew. Added `tests/hooks/PostWrite.Tests.ps1`
  (host-independent, red-before-green; crash reproduced under de-DE during the fix).
- **B-01** (minimum doc-honesty fix) — shipped **v0.25.1**. `enforcement-surfaces.md` gained the
  shell-write caveat on the Write hard-blocks row; `CLAUDE.md`/`AGENTS.md` Verification-Rule-7
  parenthetical scoped to editor/file writes. *Optional guard hardening (register on the terminal
  tool + content-sniff) was **deferred** by decision — file as a follow-on; false-positive risk +
  needs its own fixtures and a workspace-decision record.*
- **B-03** — shipped **v0.25.1**. Live-verified via sentinel canary on **Copilot CLI 1.0.68**:
  `userPromptSubmitted` additionalContext **is** consumed; `postToolUse` additionalContext is
  **not** consumed by the model; repo hooks fire **only after folder trust** (no non-interactive
  trust flag). Updated `enforcement-surfaces.md` Status notes + corrected the false
  "consumes postToolUse feedback" comment in the `post-write` twins. **Follow-ons this surfaced:**
  the `post-write`/`audit-trail` Copilot postToolUse leg is dead → fold into the B-08 matrix rows
  and the B-09 post-write demotion; the folder-trust prerequisite → `framework-doctor` (B-16).
  VS Code agent-mode consumption still unverified (canary covered the CLI only).
- **B-09** — shipped **v0.25.2**. Fixed the `post-write.ps1` `$tn=$null` misrouting (pre-declared
  `$tn=''` so malformed/env-fallback build failures hit Claude's exit-2 branch, matching the `.sh`
  twin). Added `tests/hooks/PostWriteRouting.Tests.ps1` (static `$tn` guard + build-free twin
  agreement). Note: post-write's *build-failure* routing can't be exercised in the byte-identical
  `tests/hooks` dir (stack-specific `.cs`-vs-`.ts` build); boy-scout decision-output likewise — both
  covered only for robustness there. B-02's epoch bug (the other divergence B-09 named) shipped in 0.25.1.
- **B-04** — shipped **v0.25.2** (maintainer gate). `check-lockstep` enumerates the union of both
  repos for every IDENTICAL class (missing-in-dotnet now fails too), throw-safe on missing dirs.
  Self-test: `.claude/hooks/tests/CheckLockstep.Tests.ps1` (green control + planted angular-only file).
- **B-06** — shipped **v0.25.2** (maintainer gate). Replaced the static `$sharedSkills` list with a
  computed rule: any skill present in both repos is shared-and-required; only stack-specific skills are
  declared. `enforce-standards` now enforced. Self-tested.
- **B-05** — shipped **v0.25.2**. Unified `post-write` `timeoutSec` to 120 (angular was 60; WSD-009)
  and added a structured `hooks.json` registration-parity gate to `check-lockstep` (audit-trail the
  one dotnet-only exception). Self-tested (planted timeout drift).
- **B-07** — shipped **v0.25.2**. `template-checks.ps1/.sh` gained an EOL-normalized `.claude/skills`
  ↔ `.github/skills` mirror gate (runs in both repos' `template-ci.yml`). Trap recorded in LEARNINGS:
  the gate must EOL-normalize (core.autocrlf) and `[IO.File]::ReadAllText` needs absolute paths
  (process-CWD ≠ `Set-Location`).
- **B-08** — shipped **v0.25.2**. `enforcement-surfaces.md` gained three capability rows (build/
  type-check feedback, Boy Scout stop-nudge, audit trail) encoding the B-03 live findings — Copilot
  does not consume `postToolUse` additionalContext (post-write feedback not surfaced), while
  `audit-trail`'s file side-effect still fires.

### B-33 · Make the archived legacy repos route an *agent* to the merged repo — **DONE 2026-07-12, see Done section**

**Why:** consumers adopt this framework by pointing an LLM at a repo URL and saying "install this
into our repository". For 25 versions those URLs were `ai-tech-lead-dotnet` and
`ai-tech-lead-angular`, whose READMEs opened with §1 *"For AI agents (LLMs)"*. Both are now archived
(read-only) with pointer READMEs. **Nobody has verified those pointers work on the audience that
actually uses them** — an agent, not a human. If a pointer README is a human-voice "this repo has
moved" line with no agent-addressed instruction, an agent told to install from the old URL will
either install the **frozen v0.25.5 template** it can still see in the tree, or improvise. Old URLs
are plausibly still the *majority* of inbound traffic.

**Do:** read both pointer READMEs (they could not be verified from the maintainer's box — local
clones are frozen at `bd8bb2f`, the pointers were added on GitHub). If they do not tell an agent, in
imperative voice, to go to `andreoucostas/ai-tech-lead` and install from `dist/<stack>/` — and to
**not** install what it finds in the archived tree — then: unarchive → fix → re-archive. Both repos.

**Not:** any other change to the legacy repos. They stay frozen at v0.25.5.

**Evidence trail:** v0.26.3 (2026-07-12), `meta/LEARNINGS.md` — "a merge can preserve every artifact
and still retire the entrypoint they were reached through". This is the same defect class, on the
one door that could not be fixed from here.

---

### B-56 · Host-dependent capability probes make gate outcomes machine-dependent — **DONE 2026-08-08, see Done**
**Effort:** S · **Priority:** P2 · **Invariants:** #3

**Why:** `framework-doctor`'s "Guard JSON parser" row asked PowerShell's `Get-Command jq` (Windows
PATH + PATHEXT) while *reporting on* `guard.sh`, which runs under bash. On a machine where `jq` is an
extensionless binary, the twins disagreed (PS `[MISSING]`, bash `[OK]`), the twin-parity test failed,
and — because `release.ps1` gates on the hook suites — **every release was blocked** until it was
diagnosed. Fixed for that row in v0.35.0 by probing from bash's vantage point, but the class is open:
a check that asks the wrong shell about another surface's capability yields a different verdict per
machine, and the fixtures exercise the real host rather than a pinned environment.

**Do:** audit the doctor's remaining probes for the same shape — where a check is about surface X's
capability, ask X. Pin the probe environment in the twin-parity fixtures so a maintainer's local tool
layout cannot decide whether a gate passes.

### B-60 · Skill step cross-references rot silently when a numbered list changes — **DONE in v0.53.0, see Done section**
**Effort:** S · **Priority:** P3 hygiene

**Why:** skills cross-reference their own steps in prose — `add-tests` alone has "financial-domain
invariants from **step 4** above" and "apply **step 6**'s red-check to every test". Markdown
auto-renumbers ordered lists, so changing the first item's number silently repoints every such
reference. This was caught by hand during B-57 (an implementer renamed step 1 to 0, leaving
`0,2,3,4,5,6,7`, which renders as `0,1,2,3,4,5,6` and shifts both cross-references onto the wrong
steps) in all three stacks. Nothing gates it, and the failure is invisible in the diff — each line
looks locally correct.

**Do:** a small check in `validate-dist` (or `template-checks`): for each shipped skill/command, parse
the ordered-list labels, confirm they are contiguous from 1, and confirm every `step N` reference in
the prose resolves to an existing item. Red-test by planting a gap. Cheap, and it protects a
correctness property no human reliably re-verifies.

### B-58 · `CLAUDE.md` ↔ `AGENTS.md` skills list is ungated and has already drifted — **DONE in v0.53.0, see Done section**

`template-checks.{ps1,sh}` mirrors exactly four sections — `## Verification Rules`, `## Leanness`,
`## SOLID`, `## Boy Scout Rule` (plus `### 1. Classify the intent`). The skills list under
`## Common Tasks` is **never compared**, and it had already drifted in all three dists while every
gate was green. Found while shipping B-57, which edits exactly those lines:

```
dist/dotnet/CLAUDE.md:134   - `add-tests` — add unit/integration tests following project patterns (xUnit + `WebApplicationFactory`)
dist/dotnet/AGENTS.md:100   - `add-tests` — add tests following project patterns (xUnit + `WebApplicationFactory`)
dist/angular/CLAUDE.md:133  - `add-tests` — add specs following project patterns (TestBed + `HttpTestingController`, harnesses, …)
dist/angular/AGENTS.md:99   - `add-tests` — add tests following project patterns (Jasmine/Karma or Jest spec + HTTP mocks)
```

Angular's pair had drifted far enough to name a *different technology* on each side. B-57 fixed the
lines by hand and hand-diffed them; nothing stops them drifting again.

**Do not add `## Common Tasks` to the verbatim mirror list** — that was the first idea and it is
wrong. A section diff shows `AGENTS.md`'s Common Tasks is *deliberately* condensed: shorter
descriptions throughout and the `/bootstrap` paragraph dropped. A verbatim gate goes red in all three
dists and would force rewriting a section that is intentionally different.

The right gate compares the **set of backtick-quoted skill slugs** in each file, ignoring the prose
around them: catches "a skill was added/removed on one side only" without fighting the intentional
condensation. It does *not* catch description drift (the actual B-57 defect), so consider whether a
second, looser check is worth it — e.g. flag when one side names a technology token the other does
not. Red-test per `DEVELOPING.md`: plant a slug on one side only, show non-zero exit, then the clean
pass. Both twins.

### B-61 · Twin behavioural parity does not cover shipped `scripts/`, only `.claude/hooks/` — **DONE, heading corrected 2026-08-16, see Done section**
**Effort:** M · **Priority:** P1

**Why:** `tests/hooks/TwinParity.Tests.ps1` genuinely runs both twins against fixtures and diffs
stdout/stderr, but its coverage is scoped to hooks: guard, boy-scout-check, and the empty/malformed-
stdin cases. `framework-doctor.ps1` and `framework-doctor.sh` returned **opposite verdicts on the
same machine at the same moment**: OK vs MISSING, exit 0 vs exit 1. No gate noticed. That divergence
was the only reason the bug was found; running either twin alone showed a clean bill of health. The
doctor is the diagnostic every other honesty claim rests on.

**Do:** extend the behavioural twin comparison to the shipped `scripts/` twins, framework-doctor
first.

### B-62 · No gate validates the hook registrations we ship — **DONE, heading corrected 2026-08-16, see Done section**
**Effort:** S · **Priority:** P1

**Why:** a bare interpreter name shipped in `dist/*/.claude/settings.json` for many versions with no
check. `validate-dist` has `no-meta-leak` and `no-dead-instruction`, but nothing inspects whether a
hook registration can actually start. `settings.windows.json` ships a bare `powershell` and carries
the same exposure.

**Do:** add a `validate-dist` check that fails on a bare interpreter name in a shipped settings
file; red-test it by planting one.

### B-63 · Audit every capability probe for vantage-point validity — **DONE 2026-08-08, see Done**
**Effort:** M · **Priority:** P2

**Why:** this is the **second** instance of the class; the first was a jq probe checking from
PowerShell's vantage point instead of bash's. The remaining `Invoke-BashProbe` use for the Guard JSON
parser row still has it: it spawns bash as a child of the doctor, so that bash inherits the doctor's
`PATH`, not the host's. Measured: from the host's shell `pwsh` was not found; from a doctor-spawned
bash it **was** found. It does not bite today only because jq's location does not vary the way
pwsh's does. A comment now warns against reuse, but the flaw is unfixed.

**Do:** enumerate every capability probe across hooks, scripts and gates; for each, state which
environment it observes and which one actually matters. Where the relevant environment is
unobservable, report CANT-VERIFY rather than guessing, or remove the dependency.

### B-65 · Restore reliable post-bootstrap discovery of `docs/defaults.md` — **CLOSED in v0.56.0, pointer deliberately dropped; see Done** — **DONE in v0.56.0, see Done section**
**Effort:** S · **Priority:** P2

**Why:** every inbound pointer is conditional on being un-bootstrapped: the `CLAUDE.md`
`BOOTSTRAP_PENDING` comment and `add-tests/SKILL.md`. `bootstrap.md` instructs the model to delete the
`BOOTSTRAP_PENDING` marker and the placeholder line, severing the only pointer. `session-start` and
`route-prompt` reference the file nowhere. Every bootstrapped consumer repo therefore carries a
greenfield-conventions document that nothing can route a model to. This also means on-demand `docs/`
files are a weaker delivery tier than Instructed, and `enforcement-surfaces.md` has no row for it.

**Do:** decide whether `defaults.md` should be reachable post-bootstrap or explicitly retired at
bootstrap, and add the missing tier to `enforcement-surfaces.md`.

**Amended 2026-07-31 after the Phase A experiment:** the unreachability framing above is too strong
and is superseded by measurement. Agents do reach on-demand `docs/` files in bootstrapped repos; in
one valid no-pointer run, the agent opened the file unaided. Removing the pointer therefore
plausibly reduces the *reliability* with which guidance is found rather than making the file
unreachable. Keep this item open: restoring the pointer that `/bootstrap` deletes is cheap and
still worth doing. The causal question—whether the pointer increases load probability—needs more
runs before the framework asserts anything about pointers in shipped documentation. For the Angular
work, a pattern catalogue in `docs/` is a viable delivery location on this evidence.

### B-67 · `no-dead-instruction` does not validate markdown link targets — **DONE 2026-08-08, see Done**
**Effort:** S · **Priority:** P3

**Why:** the check greps for script invocations and asserts the script resolves; it has no notion of
markdown links, so a doc-to-doc reference can dangle in all three dists with no gate firing.

**Do:** extend it to markdown link targets; red-test with a planted dangling link.

### B-71 · Silently skipped tests make a green local suite weaker than it looks — **DONE 2026-08-08, see Done**
**Effort:** S · **Priority:** P2

**Why:** the FrameworkDoctor suite prints `[skip] Windows PowerShell 5.1 compatibility --
powershell.exe unavailable on this host` and still summarises as green. On the maintainer machine
`powershell.exe` cannot be resolved because the session `PATH` is missing System32, so the one test
that guards meta-invariant #4's entire rationale — Windows PowerShell 5.1 mis-parses BOM-less UTF-8
— never runs locally. A `[skip]` line scrolls past inside an otherwise-green summary and reads as
benign. The same machine condition is what made the v0.38.0 hook defect possible in the first
place, so this is not hypothetical: local coverage silently shrank exactly where the invariant
needed it.

**Do:** distinguish an ordinary skip from a skip of an invariant-guarding test. Surface the latter
prominently in the suite summary — a count and a named list, not just an inline line — and consider
making the summary state which invariants went unexercised on this host. Cross-reference
framework-doctor's CANT-VERIFY tier: the honest-reporting pattern already exists in this repo and
should apply to the test harness too.

**Not:** do not make the skip a hard failure; a host genuinely without Windows PowerShell should
still be able to run the suite.

**Live evidence, 2026-08-01 (shipping B-61) — this entry is no longer hypothetical.** The
FrameworkDoctor suite reported `15 passed, 0 failed, 1 skipped` on the maintainer box all through the
v0.41.0 work; the skip was the Windows PowerShell 5.1 case, because `Get-Command powershell.exe
-CommandType Application` cannot resolve it when the session `PATH` lacks System32. In the *same
session* a **5.1-only** harness defect was found (see the v0.41.0 RCA) — the exact host whose coverage
had silently lapsed. `powershell.exe` was in fact present and usable at
`$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe`; only PATH resolution failed. So
besides surfacing invariant-guarding skips prominently, the probe should fall back to the well-known
absolute path before declaring the host incapable — a skip caused by a broken PATH is not the same
fact as a host without 5.1, and reporting them identically is what let the gap persist.

### B-78 · Warehouse-map staleness has four populations no signal reaches — **DONE, heading corrected 2026-08-16, see Done section**
**Effort:** S · **Priority:** P3 · found 2026-08-01 shipping v0.42.0

> **DONE in v0.51.0.** `warehouse-map-check` reaches current/missing/stale/declined/not-applicable
> states directly and through advisory docs-sync output; the load recipe requires current map or
> equivalent live evidence. Pure-SQL adoption is covered with B-115.

**Why:** v0.42.0 added a freshness caveat inside `add-warehouse-load` (fires when the map is read)
and a `/docs-sync` bullet gated on `docs/warehouse-map.md` existing. Both are structurally blind to
repos that have **no** map but should:

- bootstrapped on v0.31.0–v0.34.1, before the Phase-4 nudge existed — and `/bootstrap` is
  `disable-model-invocation: true`, so it is not re-run;
- the developer declined the offer — `map-warehouse` says "offer, don't force";
- the repo **grew** a warehouse after bootstrap, where `/bootstrap` Phase 3a's three-way rule
  already deleted both warehouse skills, so nothing warehouse-shaped remains to fire at all;
- `/adopt` — the brownfield path an existing warehouse actually takes — never mentions warehouses,
  and declares its own Phase 8 the sole emitter during adoption.

Compounding it: the Phase-4 nudge is a bullet in a chat report. It leaves no artifact, so it is a
one-shot mention, not a durable pointer.

**Do:** decide which of these deserve a signal — this is a scoping question, not an obvious fix.
Cheapest candidate is a durable pointer written into `CLAUDE.md > Conventions > Data Access` when A2
finds warehouse signals, which survives where a report bullet does not; second is a warehouse row in
`/adopt`'s Phase-8 checklist.

**Stakes raised 2026-08-07.** `add-warehouse-load`'s new dimension-binding step tells the reader to
search `docs/warehouse-map.md`'s table inventory for the business key before creating a dimension. A
missing or stale map now costs a *wrong write* — a duplicate dimension — where before it cost a wrong
read. Every population listed above inherits that. B-115 closes the `/adopt` one as a side effect of
making a warehouse-only repo adoptable at all; the other three are still unreached.

---

### B-80 · `release.ps1`'s `git add -A` commits whatever is sitting in the working tree — **DONE, heading corrected 2026-08-16, see Done section**
**Effort:** S · **Priority:** P2 release integrity · **Invariants:** #7 · found 2026-08-01 after v0.43.0

**Why:** the release stages with a blanket `git add -A` (step 5). That is deliberate — the release
commit must carry the stamps, the rebuilt `dist/`, and the footprint baseline together — but it also
sweeps in anything else present. A git worktree created under `.claude/worktrees/` (where the
tooling puts them by default) is recorded as a **gitlink**, mode 160000, so v0.42.0 and v0.43.0 each
shipped a stray pointer to a directory that ceased to exist the moment the worktree was removed.
Caught only because removing the worktrees showed two tracked deletions.

`.gitignore` now covers `.claude/worktrees/`, which closes this instance. The general hazard is not
closed: `git add -A` will do the same for any untracked scratch file, editor backup, or temp output
that happens to be in the tree when a release runs, and the release prints no manifest of what it
staged, so nothing surfaces it.

**Do:** before committing, diff the staged set against what a release is *expected* to touch
(`src/**`, `dist/**`, `CHANGELOG.md`, `meta/context-footprint.json`, the version stamps) and refuse
— or at minimum print a prominent warning and require confirmation — when anything else appears.
A stray gitlink (mode 160000) anywhere in the index should be a hard refusal: this repo has no
submodules, so it is always a mistake. Red-test by planting an untracked file and a worktree.

**Cross-links:** B-53 and B-73 (same script, other release-integrity failures -- both now closed). Consider closing all
three as one pass over `release.ps1`.

---
### B-74 · Nothing proves a test harness can report failure — **DONE in v0.44.0; stale heading corrected 2026-08-08, see Done**
**Effort:** S · **Priority:** P2 · **Invariants:** #3 · found 2026-08-01 shipping B-61

**Why:** B-64 covers gates and diagnostics. It does not cover `_HookHarness.ps1` / `Invoke-HookTests.ps1`,
which decide whether *any* gate's verdict is heard. A defect there is maximally silent: every suite
still prints, and every exit code lies. The v0.41.0 finding above is the existence proof, and it
survived on a supported host for an unknown number of releases.

**Do:** add a self-test that plants a deliberately failing test in a throwaway fixture and asserts the
harness returns non-zero — run under **both** PowerShell hosts, since this defect existed only on 5.1.
Extend the same idea to the runner: a file that exits 1 must make `Invoke-HookTests.ps1` exit non-zero.

**Not:** do not fold this into B-64. B-64's subject is the checks; this one's subject is the scoreboard.

---

### B-88 · Nothing tells you a release broke CI — four red runs went unnoticed until asked — **DONE 2026-08-02, see Done section**
**Effort:** M · **Priority:** **P1** · filed 2026-08-02, observed the same day

**Why:** v0.44.0 was released, tagged, pushed and reported green. **CI went red on both legs, and so
did the three commits after it.** Nobody noticed for over an hour, and only because the maintainer
asked. `release.ps1` runs every local gate and refuses to commit on failure — but it exits **before**
CI has an opinion, so "Release complete" is a statement about the maintainer's box, not about the
repo. Four consecutive red runs is exactly the state the whole gate apparatus exists to make
impossible, and the release path is blind to it.

The specific break was B-70's class (a new test never exercised on a CI leg before shipping) with a
**vantage-point** cause (B-63's class): `ReleaseStagingGuard.Tests` replays release tags, and
`actions/checkout` defaults to `--depth=1 --no-tags`. The test observed a full clone; CI observed a
shallow one. Both legs failed identically, which is the good case — a test that failed on only one
leg would have been read as flakiness.

**Do:** after the tag push succeeds, have `release.ps1` **watch the CI run for the release commit**
and report its conclusion — poll `gh run list --commit <sha>` (or the API) to a terminal state, print
success/failure, and exit non-zero on failure so the release is not reported as complete when it is
not. The release is already a 5–7 minute operation; adding the wait is cheap next to shipping a red
master. If `gh` is absent, say so explicitly and print the run URL — an unverifiable CI result must
read as CANT-VERIFY, never as success (the doctor's tier already models this).

**Not:** don't make the release *depend* on CI passing before committing — the freshness gate needs
the commit to exist. This is a post-condition, like the `origin/master` advance check (B-53), not a
precondition.

**Cross-links:** B-70 (the shipped-untested-on-a-leg gap this instance is), B-63 (vantage point),
B-53 (the precedent: a release that exits 0 without verifying its own postcondition).

---

### B-81 · The licence does not travel with what consumers actually copy — **DONE for v0.54.0, see Done section**
**Effort:** S · **Priority:** P3 · filed 2026-08-01 alongside B-47

**Why:** B-47 put MIT at the repo root, which makes the repository legally consumable. But the unit
of consumption is `dist/<stack>/` — the installers copy those contents into the consumer's own repo
— and those copied files carry no licence text. A consumer whose compliance process inspects *their*
tree (not ours) still finds unlicensed files. Root-only was the deliberate decision at B-47; this is
the deferred half, not a reversal.

**Do:** decide whether each dist ships a `LICENSE` copy. If yes it is authored once in
`src/core/` and reaches all three dists, and it is new **shipped** content, so it needs a
`no-meta-leak` pass and a line in the shipped changelogs. If no, say so explicitly in the README
licence section so the answer is recorded rather than re-litigated.

---

### B-82 · Root `CLAUDE.md` ↔ `AGENTS.md` mirror parity is ungated — **DONE in v0.53.0, see Done section**
**Effort:** S · **Priority:** P3 · filed 2026-08-01 while shipping B-45

**Why:** meta-invariant #2 has two halves. The **shipped** half is gated per dist by
`template-checks` (verbatim section diff + version stamps). The **root** half — this repo's own
hand-maintained `AGENTS.md` mirror — is gated by nothing at all. `DocTruth` treats the four root
docs as a set but never compares them to each other. Adding the Maintenance model section required
editing both files by hand with no check that the second edit happened; the next such section may not
be so lucky.

**Do:** add a `DocTruth` assertion driven by a table of expected `CLAUDE.md` heading →
`AGENTS.md` heading mappings, asserted **both** directions, and encoding the deliberate merges
(Workflows / Definition of done / Verification / Inherited disciplines all collapse into one mirror
section; Commit & push folds into Conventions). Verbatim diffing is the wrong instrument for a
deliberately condensed mirror — that is B-58's lesson. Red-test by adding a section to one file only.
Guard against the vacuous pass: assert the mapping table is non-empty, and count with `@(...).Count`
(a bare pipeline `.Count` returns `$null` for a single match under 5.1 — the v0.41.0 RCA).

---
### B-86 · Post-ship review owed for v0.44.0 — **DONE 2026-08-03, see Done section** (findings: B-92, B-93, B-94)
**Effort:** S · **Priority:** P2 · filed automatically by `release.ps1` on 2026-08-02

**Why:** v0.44.0 shipped with `-NoIndependentReview`, so no second session re-ran a gate or a
red-test against it. Maintenance model #2 requires the review to be filed rather than assumed when
it did not happen. Summary of what shipped: instruments that could not fail now can - harness red-test, hook-registration gate, release staging guard

**Do:** review the v0.44.0 diff as an independent session -- re-run at least one gate and one
red-test yourself, do not read the release output as evidence -- and file whatever it finds. Then
close this entry, recording what was re-run.

---
### B-89 · Windows PowerShell 5.1 turns a native command's stderr into a terminating error — one *shipped* script remains exposed — **DONE 2026-08-08, see Done**
**Effort:** S · **Priority:** P2 · filed 2026-08-02 (RCA of B-88) · **Invariants:** #3 #5

**Why:** under 5.1, a native command that writes to stderr raises a `NativeCommandError` record, and
with `$ErrorActionPreference = 'Stop'` that record is **terminating**. `2>$null` redirects the *text*
but does not stop the record. pwsh 7 does not do this (`$PSNativeCommandUseErrorActionPreference`
defaults to `False` — measured on 7.6.4). So the idiom `$root = (git rev-parse --show-toplevel
2>$null)`, written to degrade gracefully, degrades gracefully on one host and dies on the other.

Found in new code while shipping B-88, then swept. Two shipped scripts originally matched both
conditions. B-90's now-honest 5.1 architecture test reproduced and fixed
`src/core/scripts/build-architecture-html.ps1`; **`src/core/scripts/sync-agent-files.ps1:12`
remains exposed**, and it is not theoretical. Run from a non-git directory,
`dist/dotnet/scripts/sync-agent-files.ps1`:

```
5.1: git : fatal: not a git repository ... + FullyQualifiedErrorId : NativeCommandError   (no exit code at all)
7  : No .claude/skills directory -- nothing to sync.                                       EXIT=0
```

The remaining script intends the fallback that pwsh 7 gives it. Consumers on Windows may use either host,
and the 5.1 outcome is a raw .NET error dump instead of the message the author wrote. This is also a
**twin divergence** the `.sh` side does not have (`2>/dev/null` in bash is just a redirect), so it is
invariant #3 territory as well as #5.

**Do:** wrap the remaining native call so the exit code is inspected rather than the error record —
set `$ErrorActionPreference = 'Continue'` around the call and test `$LASTEXITCODE`, as
`.claude/scripts/watch-ci.ps1`'s `Invoke-GitQuiet` now does. Red-test it from a non-git directory
**under 5.1**. B-90 supplies the completed architecture-generator red/green evidence. Then sweep the remaining `2>$null` sites listed by
`grep -rn '2>\$null' --include=*.ps1 src/ scripts/` and decide each; most do not set `Stop`, which is
the only reason this has not bitten more widely.

---

### B-90 · A suite can spawn its subject under a host the defect cannot exist on — **DONE 2026-08-08, see Done**
**Effort:** M · **Priority:** P2 · filed 2026-08-02 (RCA of B-88) · **Invariants:** #3

**Why:** `_HookHarness.ps1`'s `Get-PsExe` prefers `pwsh` whenever it resolves. Any suite that uses it
to spawn the code under test therefore exercises that code under **pwsh 7 even when the suite itself
is running under 5.1** — so running the suite under 5.1 proves nothing about 5.1. B-74's RCA recorded
exactly this (fixtures were switched to `(Get-Process -Id $PID).Path`), and it **recurred immediately
in new code**: `ReleaseCiWatch.Tests.ps1`'s first cut used `Get-PsExe`, reported 18/18 green under
5.1, and was hiding two 5.1-only defects — a terminating `NativeCommandError` (B-89) and 5.1's
`ConvertFrom-Json` not enumerating a top-level array. Both appeared the moment the child was bound to
the suite's own host, and one of them would have mis-decided a release.

A fix applied to one file is not a fix applied to a class. Nothing stops the next suite reaching for
`Get-PsExe`, because `Get-PsExe` is the obvious thing to reach for and its name does not warn.

**Do:** audit every `*.Tests.ps1` in `.claude/hooks/tests/` and `src/core/tests/hooks/` that spawns
the subject. Where the subject must be exercised on the host under test, bind it to
`(Get-Process -Id $PID).Path`; where `Get-PsExe` is genuinely right (the subject is *always* invoked
by pwsh in production, as hooks registered with an explicit interpreter are), say so in a comment so
the choice is visible. Consider renaming or documenting `Get-PsExe` at its definition — "resolves a
host, NOT necessarily this one" — since the trap is that the name reads as "the PowerShell I am".
Cross-links: B-74 (first instance), B-71 (the sibling: a skipped 5.1 test inside a green summary).

---

### B-93 · The staged-set guard's 5.1 hardening is tested only under pwsh 7 — **ABSORBED by B-90 2026-08-08, see Done**
**Effort:** S · **Priority:** P2 · filed 2026-08-03 by the B-86 post-ship review · **Invariants:** #3

**Why:** `.claude/hooks/tests/ReleaseStagingGuard.Tests.ps1:83` spawns the extracted guard region via
`Get-PsExe`. Measured on this box: under a **Windows PowerShell 5.1** suite run, `Get-PsExe` returns
`pwsh`, resolving to `pwsh 7.6.4`. So running the suite under 5.1 exercises the guard under 7, and
the `@()` wrappers the guard carries *explicitly and only* for a 5.1 defect (`release.ps1:398-401`,
citing the v0.41.0 RCA) are never executed on the host they defend against.

This is B-90 verbatim, and the timing is the point: B-90 was filed 2026-08-02 as the *class* behind
B-74's recurrence, and the file that repeats it was added by v0.44.0 — the release whose theme was
instruments that cannot fail. The trap is that `Get-PsExe` reads at the call site as "the PowerShell
I am" when it means "the best PowerShell on this box".

**Do:** bind the fixture to `(Get-Process -Id $PID).Path`, as `HarnessIntegrity.Tests.ps1:57` and
`ReleaseCiWatch.Tests.ps1` already do, and run the suite under both hosts. Fold this file into
B-90's audit rather than treating it as separate work — it is one more row in that sweep, filed
separately only because it landed after B-90 was written.

**Cross-links:** B-90 (the class), B-74 (first instance), B-71 (the sibling: a 5.1 test skipped
inside a green summary).

---

### B-103 · Post-ship review owed for B-102 — implementer and reviewer were the same session — **DONE, heading corrected 2026-08-16, see Done section**

> **DONE — review performed 2026-08-05** by an independent session (Opus 5; B-102's implementer was
> a different session), with an adversarial second pass by codex `gpt-5.6-sol` over the review's own
> findings. **It did not come back clean: 9 findings, 5 of them defects in shipped code or in the
> record.** Filed as B-104 (P1), B-105, B-106, B-107, B-108; F7 appended to B-101.
>
> | # | finding | disposition |
> |---|---|---|
> | F1 | `route-prompt.sh` never fixed; its `python` branch selects the Store stub and the `elif` chain makes the regex fallback unreachable — routing dies **silently** on Windows | **B-104, P1** |
> | F2 | `framework-doctor.{ps1,sh}` never fixed; post-B-102 it now reports the write floor **backwards** (`MISSING` while the guard is active) | **B-105** |
> | F3 | the false skip B-102 claims to have fixed is untouched, plus four more of the same shape in shipped suites | **B-106** |
> | F4 | `enforcement-surfaces.md:48` overclaims for `route-prompt.sh` and omits three hooks that gained the dependency | folded into B-104 |
> | F5 | `_pybin` reachability across all six sites — **no defect** (checked by ordering, not by counting; confirmed independently) | closed |
> | F6 | comments in `audit-trail.sh` and `guard.sh` now contradict the code beneath them | **B-107** |
> | F7 | resolution re-runs per invocation, uncached, on a per-tool-call hook | appended to **B-101** |
> | F8 | one resolver, two grammars, fifteen copies — which is *how* F1 was missed | **B-108** |
> | F9 | the no-`jq` fallback branch has no regression test in any suite | folded into B-106 |
>
> The three answers B-103 explicitly asked for: `_pybin` is safe on every reachable path (F5); the
> per-invocation latency cost is real but small and belongs to B-101 (F7); and yes, the
> `enforcement-surfaces.md` wording **does** now overclaim in the other direction (F4) — it promises
> execution-probing for a hook that does not do it.
>
> **Method note, worth keeping:** the review's own adversarial pass returned 5 blocking findings, of
> which **4 were accepted and 1 was refuted by execution** (it claimed a test file did not exist; the
> file is tracked and unignored, and the reviewer had searched a tree that skipped `.claude/` — this
> repo's own documented search hazard, at the top of this file). Maintenance model #1's "a reviewer's
> corrections are input, not verdict" earned its keep again.

**Effort:** S · **Priority:** P2 · filed 2026-08-05 at release time, per Maintenance model #2

**Why:** B-97 followed the intended pipeline — an adversarial reviewer returned 7 blocking findings
on the plan, an external implementer built it, and a different session re-ran the gates and
red-tests independently, catching four defects the implementer's report did not contain. **B-102 did
not.** It was found, designed, implemented and verified in one session by one model. Maintenance
model #2 is explicit that this does not count as reviewed, and the honest response is to file the
review rather than to pretend it happened.

That matters more than usual here because B-102 changes the **write guard's** parser resolution in
ten shipped hooks — the framework's central enforcement claim — and because the same session
inflicted two defects on itself while doing it (a failed `sed` that left eight hooks calling an
unassigned variable and still passed `bash -n`; a compound `elif` whose invocation was rewritten
while its assignment landed in another branch). Both were caught, but by the author, which is the
condition this rule exists to distrust.

**Do:** an independent session reviews commit `6eb7752` specifically for: the resolver's behaviour
when a candidate exists but is broken in a way other than the Store stub (e.g. a Python whose
`json` import fails, a `py` launcher with no installed runtime); whether `_pybin` can be unset on any
reachable path in any of the ten hooks (assert ordering, do not count occurrences); whether probing
by execution introduces a meaningful latency cost on the no-`jq` path for hooks that run per tool
call; and whether the `enforcement-surfaces.md` wording now overclaims in the other direction.
Re-run the jq-hidden red-test independently rather than trusting the recorded before/after.

**Cross-links:** B-102 (the change under review), B-63 (probe vantage-point audit — B-102 is its
third instance), B-45 (the review ledger that made this fileable at release time).

---

### B-104 · `route-prompt.sh` selects the Windows Store stub and then silently routes nothing — **DONE, heading corrected 2026-08-16, see Done section**
**Effort:** S · **Priority:** **P1** · found 2026-08-05 by B-103's review · **Invariants:** #3 #5 #6

**Why:** `src/core/.claude/hooks/route-prompt.sh` extracts the prompt through an `elif` chain:
`jq` → `command -v python3` → `command -v python` → last-resort regex. On Windows, `python3` never
resolves (python.org ships `python.exe` only), so the chain reaches `command -v python` — which
resolves `%LOCALAPPDATA%\Microsoft\WindowsApps\python.exe`, the Store *alias stub*: it prints
"Python was not found" and exits 49. Because this is an `elif` chain, **selecting the stub commits
to that branch** — the regex `else` is never re-entered — so `prompt` comes back empty and the hook
exits without routing anything. The output-encode site (~line 210) name-probes `python3` the same way
and falls through to plain stdout, which Copilot drops.

The consequence is the whole natural-language routing and discipline-injection delivery on the bash
leg, failing **silently**, on the primary target platform. B-102 fixed exactly this class in five
other hooks and its commit message names `route-prompt.sh` as the one hook with a bare-`python`
fallback — but `git show --stat 6eb7752` does not contain the file. A *loud* degradation was
converted into a silent one, which is what B-102 existed to prevent.

**Do:** resolve a **working** interpreter by execution over `python3 → python → py`, using the exact
grammar already in `guard.sh:46-52` (do not author a third dialect — see B-108). Resolve **lazily**,
inside the `else` of the `jq` test only: this hook runs on every prompt and must not pay interpreter
startups on the common path. Resolve **once** and memoise for both sites; initialise the variable for
`set -u`. When no interpreter resolves, the regex path and the plain-stdout path must be genuinely
reachable — *that reachability is the bug, not the name*. `route-prompt.ps1` needs no change
(PowerShell parses JSON natively); state that explicitly rather than silently skipping the twin [#3].
Also correct `docs/enforcement-surfaces.md:48` (F4): it promises execution-probing for
`route-prompt.sh`, which is currently false, and omits `audit-trail.sh`, `post-write.sh` and
`boy-scout-check.sh`, which gained the same dependency in the same commit.

**Red-test (B-106 owns the permanent one):** sandbox `PATH` with no `jq`/`python3`/`py` and a fake
`python` that exits 49; the hook must still route via the regex path.

**Cross-links:** B-102 (the change that missed it), B-103 (the review that found it), B-108 (the
two-grammar duplication that *caused* the miss), B-63.

### B-105 · The doctor reports the write floor backwards — `MISSING` while the guard is active — **DONE, heading corrected 2026-08-16, see Done section**
**Effort:** S · **Priority:** P2 · found 2026-08-05 by B-103's review · **Invariants:** #3 #5

**Why:** `framework-doctor.sh` still name-probes `python3` at `:43` (version-stamp read), `:134`
(the `Guard JSON parser` row) and `:153`/`:162` (Copilot `hooks.json` validity); `framework-doctor.ps1`
`:172-173` asks the same question through `Invoke-BashProbe` and, when that observation is
unavailable, **guesses from PowerShell's own PATH** — the wrong-vantage-point shape B-63 has already
had to correct twice.

Since B-102, this inverts. On a Windows box with a working python.org install and no `jq`, `guard.sh`
is now **active**, and the doctor tells the consumer *"the bash write guard is INACTIVE"*. The
diagnostic that every other honesty claim rests on (B-61) now produces a false alarm about the write
floor — a defect **created by the fix**, because the doctor was out of that change's scope while its
record claimed otherwise.

**Do:** implement both twins to one verdict table, and test every row: `jq` present → OK; no `jq` but
a working `python`/`py` → **OK** (today: wrongly MISSING); only the Store stub → MISSING; no parser →
MISSING; parser present but `hooks.json` malformed → **invalid**, not CANT-VERIFY; bash unobservable
(`.ps1` twin) → CANT-VERIFY. **Delete the `.ps1` PATH-guess fallback** — the row reports on
`guard.sh`, which runs under bash, so when bash cannot be observed the honest answer is CANT-VERIFY.
Keep "no parser" distinguishable from "invalid JSON".

**Not yet observed live:** the inversion follows from the code by inspection. Constructing the host
condition (no `jq`, working non-`python3` python) and recording the row before and after is required
before this closes — do not close it on inference.

### B-106 · The no-`jq` fallback has no test, and five skips lapse exactly where it matters — **DONE in v0.46.0; bookkeeping corrected 2026-08-08, see Done**
**Effort:** M · **Priority:** P2 · found 2026-08-05 by B-103's review · **Invariants:** #3

**Why:** B-102's red-test was run by hand and recorded in a commit message. **Nothing in any suite
forces the no-`jq` branch**, so B-104 could regress tomorrow with every gate green — B-64's class, on
the change that most needed it. Meanwhile five test cases silently stop covering it:

- `.claude/hooks/tests/ValidateDist.Tests.ps1:158-161` — `Get-Command python3`, then
  *"python3 is unavailable on this host"*, and the suite summarises green. B-102's entry claims to
  have fixed this; the file is not in the commit.
- `src/core/tests/hooks/SessionStart{FrameworkRules,Hazard,Wiki}.Tests.ps1` (`:22`, `:27`, `:15`) —
  each probes `command -v jq || command -v python3` and skips its Copilot-JSON case as *"no
  jq/python3 in bash"*; the Wiki file has two cases behind one skip.
- `src/core/tests/hooks/FrameworkDoctor.Tests.ps1:73` asserts the **pre-fix** contract by name.

**Do:** add a `route-prompt` no-`jq` case and a doctor inverted-row case, both driven from a sandbox
`PATH`. Reuse the utility-sandbox already at `FrameworkDoctor.Tests.ps1:73-95` — do not invent a new
one: a naive PATH scrub breaks the hook before the branch under test is reached (`route-prompt.sh`
needs `cat`/`tr`/`grep`/`sed`), while an inherited PATH may expose a real `jq` so the stub is never
selected. That fixture already carries the Git-Bash/POSIX split both CI legs need. Convert the five
skips to execution probes, and when a host genuinely lacks every parser surface it as an
**invariant-guarding** skip per B-71, not an inline `[skip]` inside a green summary. Both legs [B-70].

### B-107 · Comments left contradicting the code beneath them — **DONE, heading corrected 2026-08-16, see Done section**
**Effort:** S · **Priority:** P3 · found 2026-08-05 by B-103's adversarial pass

`audit-trail.sh:73` still says *"fall back to python3"* directly above the new three-candidate
resolver; `guard.sh:13` still describes absence as *"no jq, no python3"*, which is no longer the
capability condition. The header of the change's own flagship file misdescribes it. Sweep the other
parser-dependent hooks for the same wording while there.

### B-108 · One resolver, two grammars, fifteen copies — and that is how B-104 was missed — **CLOSED 2026-08-08, premise rejected; see Done**
**Effort:** S–M · **Priority:** P2 · found 2026-08-05 by B-103's review · **Invariants:** #3 #6

**Why:** `guard.sh` spells the parser probe as a multi-line `for` loop; `audit-trail`, `post-write`,
`boy-scout-check` and `session-start` spell the same contract as a ~200-char one-liner inside an
`elif` condition; `route-prompt` spells it a third way. Hooks are standalone by design (nothing is
sourced), so *duplication* is structural and acceptable — **two different grammars for one contract
is not.** It is B-55's class, and it is the direct cause of B-104: the change was scoped by grepping
`command -v python3`, and the sites that survived are the ones spelled differently.

**Do:** normalise every site to one grammar, then add a `validate-dist` check that fails any shipped
`.sh` naming `python3` outside the sanctioned probe form. Red-test it by planting a bare
`command -v python3` and showing the non-zero exit before the clean pass — per the trap in B-101, an
optimised or narrowed gate that silently checks fewer sites is worse than no gate.

### B-109 · `no-meta-leak` denies our vocabulary but not the maintainer's filesystem — **DONE 2026-08-08, see Done section**
**Effort:** S · **Priority:** **P2** · found 2026-08-05 while reviewing B-106's implementation ·
**Invariants:** #6

**Why:** `scripts/meta-denylist.txt` catches tracking ids, "lockstep", the two-repo past — our
*development vocabulary*. It has **no pattern for a machine-specific absolute path**. Caught live:
an implementer added host-resolution helpers to `src/core/tests/hooks/_HookHarness.ps1`, which
composes into all three dists, containing

```powershell
$fallback = 'C:\Python314\python.exe'
$fallback = '<home>\bin\jq.exe'
```

Both would have reached every consumer. `no-meta-leak` caught the `B-nn` ids in the same commit and
**passed the paths** — so the gate that exists to hold the don't-ship boundary reported a clean scan
over a file naming the maintainer's home directory. A consumer's test harness reaching into a
username on a machine that is not theirs is a worse leak than a tracking id: the id is embarrassing,
the path is a broken artifact plus an information disclosure.

This is also the shape B-97's `$protected` work already knows about — *shipped* content is the only
thing a consumer sees, and prose alone has never held this line (~190 leaking lines shipped once
before, per the invariant's own note).

**Do:** add DENY patterns for machine-local absolute paths in shipped content — at minimum
`[A-Za-z]:\\Users\\`, `/home/[^/]+/`, `/Users/[^/]+/`, and the maintainer's own username as a
belt-and-braces literal. Red-test by planting one and showing the non-zero exit. Consider whether
any *legitimate* shipped file needs an absolute example path (documentation placeholders like
`C:\path\to\repo` are the plausible case) and carve those out with a narrow `ALLOW` rather than
weakening the DENY, per the invariant's standing rule.

**Cross-links:** invariant #6, B-103 (the review during which this surfaced), B-62/B-92 (the other
"nothing validates what we ship" entries).

---

### RCA — v0.45.0 (B-102), filed 2026-08-05 with B-103's review

**Why did no gate catch it?** The change was scoped by a grep for `command -v python3`, and the sites
that survived are precisely the ones spelling the probe differently (B-108) — plus a diagnostic and
five test files nobody re-ran the grep against. **No gate knows which files are parser-dependent**, so
"fixed everywhere" was an unfalsifiable claim: there is no inventory for a gate to re-derive and diff.
`bash -n` passed on every hook, because a syntax check is not a coverage check, and the correctness
gates only ever exercised the `jq` path that works on this box.

**What else is exposed?** Every claim of the form "fixed everywhere / in all N files" made without an
inventory a gate can re-derive. The sweep is worth doing on the standing ones: the `.sh`/`.ps1` twin
sets, the six `boy-scout-check` headers (B-55), and the `enforcement-surfaces.md` capability rows.

**And the pattern above the defect.** This is the **third consecutive release whose record
overclaimed what it shipped** — B-94 (the staged-set guard's record overclaimed in three places),
B-102 (three fixes asserted that are not in the commit), and the v0.45.0 commit message itself, which
reports a "14 files × 3 dists" verification for files the commit does not contain. Each was caught by
the next independent review, never by the authoring session and never by a gate. That is the argument
for Maintenance model #2 being enforced rather than encouraged: **the failing component is not the
implementation, it is the self-report.** Worth considering whether `release.ps1` should require the
claimed blast radius to be stated as a file list it can diff against the commit.

### B-110 · The context-footprint ceiling is advisory — the budget gate cannot fail on a breach — **DONE, heading corrected 2026-08-16, see Done section**

> **DONE 2026-08-06 (meta-only; the twins do not ship — they are authoring gates, absent from
> `dist/*/scripts/`, so no version bump).** **Decision: the ceilings are LIMITS, not guidance.**
> A breach now prints `FAIL:` per breached metric with the measured value and the overage, then
> exits 1 — in **both** `-Check` and `-Update`, and **before** the `-Update` write, so a breach can
> never leave a rewritten baseline behind. The escape hatch is `-AllowCeilingBreach` /
> `--allow-ceiling-breach`, named for what it risks per this repo's convention: it prints
> `WARN (CEILING WAIVED):` and continues. Raising a ceiling stays a two-twin edit, deliberately.
>
> **Red-tested — the instrument was seen to go red before its green counted (Maintenance model #4).**
> Planted +1,180 chars into `dist/dotnet/CLAUDE.md` (38,997 → 40,201, over by 201), restored
> unconditionally via `git checkout` in a `finally` (B-84's rule). Observed:
>
> | run | observed |
> |---|---|
> | `.ps1 -Check` | `FAIL: dotnet static.claude is 40201 chars, ceiling 40000 (over by 201).` · **exit 1** |
> | `.ps1 -Update` | same FAIL · **exit 1** · `baseline_untouched=True` — **this is the defect, closed** |
> | `.sh -Check` | byte-identical verdict · **exit 1** |
> | `.sh -Check -AllowCeilingBreach` | `WARN (CEILING WAIVED)` then fell through to the drift check · exit 1 (drift, correct — the waiver waives the ceiling, not drift) |
> | `.ps1 -Update -AllowCeilingBreach` | `WARN (CEILING WAIVED)` + `UPDATED` · **exit 0** |
> | both twins, restored tree | `OK: context footprint matches…` · **exit 0** |
>
> Both CI legs already invoke their own twin with `-Check` (`ci.yml:45-46`, `:81-82`) and
> `release.ps1:232` gates on `-Update` exiting 0, so the new failure mode is enforced everywhere
> without wiring changes. Current values are all under ceiling (dotnet 38,997 / angular 37,835 /
> monorepo 47,354 / ratio 1,214), so nothing is blocked today.
>
> **Also closed from this entry's "worth checking":** the twins previously had *no* fixture
> exercising the ceiling branch on either side (B-75's inert-fixture class — both agreed about
> nothing). The red-test above is the first execution of that branch in either twin, and they were
> shown to agree on it.
>
> **NOT done, deliberately, and it is the honest residual:** no *permanent* test was added. The
> red-test was performed and is recorded here as observed output, not as executable text — which is
> exactly the gap **B-84** exists to close, and this is now a second worked example for it. The
> reason is cost, not oversight: a single `context-footprint` run takes minutes (it renders both hook
> twins across three dists), so a suite case would add multi-minute runtime to a meta suite B-101
> just cut from 1,027s to 270s. That trade should be made deliberately with B-84's mutation helper,
> which could plant the breach against a scratch dist rather than the real one. Filed as the reason,
> not as a claim that testing happened.
**Effort:** S · **Priority:** P2 · found 2026-08-06 while shipping v0.47.0 · **Invariants:** #3

**Why:** `scripts/context-footprint.ps1:323-331` checks the ceilings and emits
`WARN: <dist> static.claude exceeds 40000 chars.` / `WARN: monorepo static.claude exceeds 48000
chars.` / the 1.5× ratio warning — and **never sets a non-zero exit**. The script's only failing
condition is *baseline drift* (`FAIL: context footprint differs from meta/context-footprint.json`),
which the documented remedy `-Update` resolves by accepting whatever the new numbers are. So the
sequence "make a change, run `-Update`, commit" absorbs a ceiling breach silently, and a `WARN:` line
scrolls past inside an otherwise-clean run — B-71's shape as well as B-64's.

This matters more than a normal advisory: the footprint gate is the instrument **every** static-context
decision is weighed against. B-97 cited it to argue "whatever the answer is, it is not add more to
`CLAUDE.md`"; B-99's placement decision was costed against it and its headroom figure was already
wrong once (characters read as tokens, a 4× error, corrected in that entry). A budget whose enforcement
is a print statement invites exactly that.

Live relevance: v0.47.0 took monorepo `static.claude` to **47,354 / 48,000 — 646 characters (~162
tokens) of headroom**. The next static-context addition can breach the ceiling, and on current code
nothing would stop it.

**Do:** decide whether the ceilings are limits or guidance, and make the code say so. If limits: exit
non-zero on breach (with an explicit opt-out switch for a deliberate, recorded raise, since the
ceilings are a judgment call and not physics). If guidance: rename them and say so, so no future entry
cites them as a gate. Either way, **red-test it** — plant a file that breaches the ceiling and show the
non-zero exit (or the documented WARN-only behaviour) before the clean pass. Twin edit: the `.sh` twin
carries the same logic and must reach the same verdict [#3].

**Also worth checking in the same pass:** whether `.sh` and `.ps1` agree on the ceiling branch at all.
It is un-exercised code on both sides, which is B-75's inert-fixture class — a branch no fixture
triggers makes both twins agree about nothing.

**Cross-links:** B-64 (planted-defect tests for diagnostics — this is one), B-71 (a warning inside a
green summary), B-75 (inert fixtures), B-32/WSD-017 (the gate's origin), B-97/B-99 (entries whose
reasoning rests on these numbers).

---

### B-113 · CI is being cancelled at exactly 15 minutes, and the windows leg already runs 12–14.5 — **DONE, heading corrected 2026-08-16, see Done section**
**Effort:** S to diagnose · **Priority:** **P1** — it blocks every release · found 2026-08-06 shipping v0.48.0

**Why:** the v0.48.0 release commit (`beface1`) could not be tagged, because `release.ps1`'s CI watch
(B-88) correctly refused to tag against a red run. But the run did not *fail* — **both jobs were
`cancelled`, simultaneously, at exactly 15m01s, with no failing step in either.** Reproduced by an
explicit `gh run rerun`: identical outcome, same 15-minute boundary
(`16:49:45Z → 17:04:46Z` linux, `→ 17:04:47Z` windows). Two independent jobs, so this is not
`fail-fast`.

**What it is not, checked rather than assumed:**
- **Not the code.** Every local gate passed twice: compose ×3, `validate-dist` ×3, hook suites ×3,
  meta suite, eval self-test. The change under test is a 420-character markdown rule.
- **Not a configured timeout.** `grep -rn timeout .github/workflows/` returns nothing; GitHub's
  default job timeout is 6 hours.
- **Not an Actions quota.** The repository is **public** (`private=false`), so Actions minutes are
  not metered.
- **Not `fail-fast`/concurrency.** `ci.yml` declares two independent jobs, no matrix, no
  `concurrency:` block.

**The part that makes this P1 rather than a curiosity — we were already at the edge and nobody
measured it.** Recent green runs, wall clock:

| commit | duration |
|---|---|
| `b1e24b5` | 12m27s (windows leg 12m24s, linux 5m24s) |
| `5eeda5d` | **14m33s** |
| `e88f8eb` | 12m36s |
| `ef38832` | 11m12s |
| `7ff3e2b` | 12m10s |

Every green run fits under 15 minutes; the longest cleared it by 27 seconds. **The windows leg is the
long pole and it has been running at 80–97% of a ceiling nobody knew existed.** So this is not "one
unlucky run" — the repo has been one small slowdown away from being unable to release, and B-88 will
correctly refuse to tag every time it happens. B-101 measured and optimised the *local* gates
(1,027s → 270s); nothing has ever measured CI duration, and no signal exists for approaching a limit.

> **CAUSE FOUND 2026-08-06: GitHub Actions was in a `major_outage`.**
> `curl https://www.githubstatus.com/api/v2/components.json` → the `Actions` component reports
> `"status":"major_outage"`. Repo-side Actions config is healthy
> (`repos/.../actions/permissions` → `enabled:true, allowed_actions:"all"`), so nothing here caused
> it and nothing here can fix it.
>
> **The evidence that settles it, and it arrived in the order that made it obvious:**
>
> | commit | what it changed | outcome |
> |---|---|---|
> | `beface1` | the v0.48.0 release | both legs cancelled at exactly 15m01s |
> | `e90adac` | **`meta/BACKLOG.md` only — one markdown file** | both legs cancelled at exactly 15m01s |
> | `68cf0aa` | the CI split below | **no workflow run was created at all** |
>
> A commit touching one markdown file cannot produce a 15-minute build, let alone a cancelled one.
> That row alone rules out repo content; the third rules out "slow build hits a ceiling" entirely,
> because the platform stopped scheduling runs.
>
> **Correction to this entry as first written.** It framed the 15-minute boundary as a *ceiling the
> windows leg was creeping toward* and made that the P1. The duration data was real — recent green
> runs at 11–14.5 minutes, the longest clearing by 27 seconds — but the causal story was **wrong**,
> and it was wrong in the direction of blaming the thing I had just changed. The 15m00s figure is an
> outage artifact, not a configured limit. Left visible rather than rewritten: this is the same
> failure shape the entries above it are about — a confident explanation that fit the data and was
> not the cause.
>
> **What survives the correction, and is still worth doing:** the margin genuinely was thin. A
> 12–14.5 minute windows leg with a 27-second worst-case margin is fragile regardless of what
> cancelled it, and the split below stands on its own merits. But it must be re-verified once
> Actions recovers — **it has never had a green run**, so it is currently an unvalidated change to
> the one system that validates everything else.
>
> **Do first, when Actions recovers:** re-run CI on `68cf0aa` and confirm (a) all eight jobs appear,
> (b) the matrix legs actually execute, (c) `watch-ci.ps1`'s extended `ExpectedJobs` matches the real
> job names — GitHub's `<job> (<value>)` naming is assumed, not observed. Then re-run the release to
> tag v0.48.0.

**Do:** (1) ~~establish what is doing the cancelling~~ — **answered: a GitHub Actions outage.** Retained
so the reasoning that led there is not lost. (1) establish what is doing the cancelling — a GitHub-side incident, an account/org runner
policy, or something in this environment; the 15m00s boundary is too exact to be coincidence, and it
is the one fact that would identify the mechanism. (2) Independently of the cause, get the windows leg
well clear of 15 minutes — it duplicates work the linux leg already does, and B-101's parallelisation
of `ValidateDist.Tests` was applied to the meta suite but the shipped hook suites (~174–217s per dist)
still run serially per dist in CI. (3) Add a duration signal: print each leg's elapsed time and warn
past a threshold, the same treatment B-101 gave `validate-dist` per-check timings.

**Not:** do not tag v0.48.0 with `-AllowUnverifiedCi` to get past this. That switch exists and is
honest — it records the waiver in the tag annotation — but using it to paper over an unexplained,
*reproducible* cancellation would put a "CI-verified" tag on a build nobody has seen pass. That is
precisely the claim the tag is supposed to carry.

**Status:** v0.48.0 is **on `master` and pushed (`beface1`) but UNTAGGED** — the documented safe state
(`release.ps1` prints it explicitly). Re-running the identical release command re-watches and tags if
CI comes back green; nothing needs unwinding.

> **NEW, 2026-08-07 — `68cf0aa` also broke the meta suite, and that now blocks every release.**
> Found while shipping B-96, which cannot reach its own ship gates because of it. `ReleaseCiWatch.Tests`
> reports **5 failures**; `release.ps1` gates on the meta suite (`:271`), so **no release can be cut
> until this is fixed** — including v0.49.0.
>
> **Cause, confirmed rather than inferred.** `68cf0aa` extended `watch-ci.ps1`'s default
> `ExpectedJobs` (`:47`) to the six split legs — `windows-hooks (dotnet|angular|monorepo)`,
> `linux-hooks (…)`. Five test fixtures still register only the old two jobs, so the watcher correctly
> returns `EXIT=3 CI CANT-VERIFY: expected CI leg(s) not present … Jobs observed: linux, windows`.
> `git log -- .claude/scripts/watch-ci.ps1` shows `68cf0aa` as the last change to that file; B-96's
> diff touches no file under `scripts/` at all.
>
> **The five are not about job naming.** They test *watcher logic* — a `pull_request` run must not
> decide the release, a re-run supersedes an earlier failure, polling reaches a terminal state, query
> scoping. Each broke incidentally because its stub job list no longer covers the widened default.
> Updating those stubs restores them to testing what they exist for.
>
> **What updating them must NOT be mistaken for.** It does not verify the real job names. This entry
> already records that GitHub's `<job> (<value>)` naming is *assumed, not observed*, and Actions being
> down is exactly why it still cannot be observed. That assumption lives in `watch-ci.ps1`'s default
> and is equally unverified before and after. Do not let a green meta suite be read as confirmation
> of the naming — the "Do first, when Actions recovers" checklist above stays owed in full.
>
> **Effort:** S. **Priority: P1** — it is now on the critical path of every release, not just this one.
>
> **FIXED 2026-08-07 (v0.49.0). And the naming question above is now ANSWERED BY OBSERVATION.**
> CI run `31168445026` produced exactly eight jobs — `windows`, `linux`,
> `windows-hooks (dotnet|angular|monorepo)`, `linux-hooks (dotnet|angular|monorepo)` — matching
> `watch-ci.ps1`'s widened default. The six split legs each ran in **1:21–3:16**, nowhere near the
> 15-minute ceiling. So all three items on the "Do first, when Actions recovers" checklist are
> discharged: eight jobs appear, the matrix legs execute, and `ExpectedJobs` matches the real names.
> The `<job> (<value>)` shape is no longer an assumption. **The 15-minute cancellation is gone —
> `68cf0aa`'s split worked, and the outage that masked it has passed.**
>
> **The fix is structural, not a patch.** `New-Jobs` in `ReleaseCiWatch.Tests.ps1` no longer restates
> the leg list; it **derives it from `watch-ci.ps1`'s own `-ExpectedJobs` default** by AST. Restating
> it is precisely what drifted. Red-tested both directions: widening `ExpectedJobs` with a brand-new
> leg — the exact `68cf0aa` scenario — leaves the suite **18/18 green** because the stubs follow
> automatically, and removing the parameter fails **loudly** (14 failures), never silently.
> **This breakage class cannot recur by omission.**
>
> **What this cost while it was open, worth remembering:** five stubs that had nothing to do with job
> naming — they test that a `pull_request` run does not decide a release, that a re-run supersedes an
> earlier failure, that the watcher polls to a terminal state, and that queries are scoped — blocked
> *every* release for a day, including a documentation-only one. That asymmetry is the argument for
> `-AllowFailingGate`, added in the same release.

**Cross-links:** B-88 (the watch that caught it and is working correctly), B-101 (gate runtime — the
local half of this, and its "nothing measures cost" thesis now has a CI-side instance), B-70 (a change
is not done until CI is green — which is now unachievable through no fault of the change).

---
### B-114 · Two entries both claim the id `B-113` — **DONE 2026-08-08, see Done section**
**Effort:** XS · **Priority:** P3 · found 2026-08-07 while filing B-115..B-118

**Why:** `### B-113 · Post-ship review owed for v0.48.0` and `### B-113 · CI is being cancelled at
exactly 15 minutes` are both live entries with the same id. Every cross-link written as "B-113" is
now ambiguous, including the one in v0.49.0's CHANGELOG ("B-113 records that `68cf0aa` extended the
watcher's `ExpectedJobs`"), which meant the CI entry — a reader following it to the post-ship-review
entry learns nothing about `ExpectedJobs`.

**Why no gate caught it:** nothing parses this file. Ids are allocated by reading the tail and adding
one, which fails exactly when two items are filed from different sessions on the same day.

**Do:** renumber the *post-ship review* one (it has fewer inbound references) and add a duplicate-id
check to the meta suite — a five-line scan over `^### B-\d+`, in the file that already sweeps this
repo's documentation for truth.

---
### B-115 · Pure SQL / SSDT / dbt repos cannot be installed, and `/adopt` cannot run in one — **DONE, heading corrected 2026-08-16, see Done section**
**Effort:** S · **Priority:** P3 · found 2026-08-07 (dimension-binding work)

> **DONE in v0.51.0.** Root fallback uses the shared category signal table after application-stack
> detection misses; PowerShell/Bash behavior tests install a pure-SQL fixture without a solution.

**Why:** three independent blocks, none of which the installer reports as a stack problem:
1. auto-detect covers only `*.csproj`/`*.sln`/`angular.json`, so a bare `.sqlproj`, a dbt project, or
   a plain `Tables/`+`StoredProcedures/` tree hard-errors with "Could not determine the stack"
   (`install.ps1:57,63,65`; `install.sh:62,67,69`). `-Stack dotnet` works and is named nowhere the
   consumer will look.
2. `/adopt` Phase 0 step 3 is "**Locate the solution root** — find the `.sln` file. All paths are
   relative to this root" (`adopt.md:53`). `/adopt` is the brownfield path an existing warehouse
   actually takes, so this stops the very repo the warehouse skills exist for.
3. pre-bootstrap, the shipped `CLAUDE.md` says "defer to `docs/defaults.md` for greenfield **.NET**
   conventions" (`src/stacks/dotnet/snippets/CLAUDE.md/defaults-comment`) — a technology claim about
   a repo that evidences no .NET, i.e. exactly the class Verification Rule 10 exists to prevent.

**Not urgent for the current consumer set** — the reporting maintainer's repos all carry a `.sln`
alongside the SQL warehouse, so all three blocks are bypassed. Filed because the guidance is aimed at
warehouses and a warehouse-only repo is the shape most likely to want it.

**Do:** add a SQL fallback to detection, evaluated **only after** dotnet and angular both miss so a
mixed repo still resolves to `dotnet`, and gate it on the **≥2 warehouse signals `map-warehouse`
step 0 already defines** — reuse that list rather than inventing a second one, or the two will drift.
Generalise `/adopt`'s root-finding. Make the pre-bootstrap pointer technology-neutral (it costs
static budget — measure it).

**Rejected in advance:** a `sql`/`warehouse` dist. WSD-020 and WSD-021 both call that the wrong
altitude, and nothing here changes that.

---
### B-116 · `route-prompt` has no data or warehouse vocabulary — **DONE, heading corrected 2026-08-16, see Done section**
**Effort:** S · **Priority:** P3 · found 2026-08-07 · **Cross-link:** B-98 (the general routing question)

> **DONE (no code) in v0.51.0.** The write-side baseline routed correctly, so warehouse regexes
> were not added without evidence of a failure.

**Why:** "implement a new import into the data warehouse" classifies as a generic `feature` on
`\bimplement\b` (`route-prompt.ps1:140`), and `$railsFeature` never mentions skills, `docs/`, or the
warehouse map. The prompt most characteristic of a warehouse consumer therefore gets rails written
for application features. This is not a claim that adding keywords would fix it — B-98 step 2 found
that broadening a `description` is the mechanism the `r=0` observation *weakens*. It is a claim that
the router is currently silent on an entire delivery surface, and nobody had written that down.

**Do:** nothing standalone. Fold into B-98's general question, and settle it with the write-side
baseline (`meta/eval-results.md`, dimension-binding Stage A) rather than by adding regexes on
intuition.

---
### B-118 · RCA: a recipe listed what to build without ever asking whether it should exist — **DONE, heading corrected 2026-08-16, see Done section**
**Effort:** S (the sweep) · **Priority:** P2 · filed 2026-08-07 · **Cross-link:** B-112 (sibling class)

> **DONE in v0.51.0.** The warehouse, endpoint, entity, DI service, Angular component/service,
> lazy-route, and signal-store recipes now search for an existing owner before scaffolding.

**Why:** `add-warehouse-load` shipped in v0.31.0 and was revised through v0.49.0 without anyone
noticing that it goes from "find a load pattern to copy" straight to "design the entity" — it never
asks *whether the dimension already exists*. The commonest real warehouse task is a new fact against
dimensions that all already exist, and the recipe's structure quietly assumes the opposite.

**Why no gate caught it.** None could, and that is the point. `validate-dist` proves the file is
present, parses, mirrors to `.github/skills`, and leaks no meta vocabulary. `no-dead-instruction`
proves every script it names exists. **Every gate we have checks that the guidance is well-formed;
none checks that it is complete.** The B-96 field report is the same shape one layer over: the map
was a valid document that omitted the thing a reader needed.

**What else is exposed to the same class — sweep, the answer is not "nothing".** Any instance-shaped
`add-X` skill that enumerates construction steps without a preceding *should this exist / does it
already exist* decision. First-pass candidates, to be confirmed by reading rather than assumed:
`add-endpoint` (does this route already exist under another name?), `register-service` (is there
already a service doing this?), `add-entity` (is this a new table or a column on an existing one?),
`add-component`/`add-service` on the Angular side. `add-tests` is likely exempt — it is process-
shaped, not instance-shaped, and its subject already exists by definition.

**Do:** read each candidate for a missing reuse gate; add one only where a real duplicate is
plausible in that stack. Do not mass-apply a template — that would be the "recipe lists what to
build" failure repeated at the meta level.

---
### B-119 · The dimension-binding post-change arm is owed — v0.50.0 shipped an unproven fix — **DONE, heading corrected 2026-08-16, see Done section**

> **DONE 2026-08-08.** Re-ran `warehouse-bind-mixed` ×2 against v0.50.0 (`2915412`), both completed
> cleanly (no spend-cap error this time): `regionOnFact` **0/2**, `Pass` **2/2** — the floor of the
> pre-registered range, not the ambiguous middle. **The dimension-binding step works on the defect it
> was written for.** Full write-up in `meta/eval-results.md` under "POST-CHANGE ARM — COMPLETE".

**Effort:** S (one arm, ~$5) · **Priority:** **P2** · filed 2026-08-07 shipping v0.50.0

**Why:** the Stage A baseline established the defect — on the `warehouse-mixed` fixture the model put
`RegionKey` directly on the new fact **2/2 counted (3/3 including the uncounted batch)**, while the
pure-SQL fixture bound correctly 2/2. v0.50.0 ships the dimension-binding step that targets exactly
that. **Whether the step changes the behaviour is unmeasured.**

The post-change arm ran against the released dist and got **one of two** scenarios: `bind-sql`
**PASS** (no regression, under the stricter resolution criterion). `bind-mixed` — the only fixture
that ever exhibited the defect — terminated on `api_error_status: 429`, *"You've hit your monthly
spend limit"*, having produced no SQL at all. Environment stop, not a result.

**The trap this leaves in the record, stated so nobody walks into it:** that run's `Detail` reads
`regionOnFact=False newDimTables= naturalKeyOnFact=False` — every value the *desired* one. All three
are artifacts of `factWritten=False`. Anyone skimming `meta/eval-results.md` for a post-change number
will find a row that looks like a clean pass and is nothing of the kind. The row is annotated in
place; this entry exists because annotations get skimmed too.

**Do:** re-run `warehouse-bind-mixed` ×2 against v0.50.0 (`2915412`), `sonnet`, `-TimeoutSeconds 900`,
once budget allows. Thresholds are **already pre-registered** in `meta/eval-results.md` (post-change
arm) — do not re-derive them after seeing the output: `regionOnFact` 0/2 = works, 1/2 = partial ship
with a stated ceiling, 2/2 = **it does not work**, record that plainly.

**Cross-links:** B-118 (the RCA that produced the step), B-117 (the disambiguation class this arm's
`reachedAddEntity=0/6` did *not* discharge).

---
### B-120 · A produce-nothing run scores every per-signal field as its desirable value — **DONE, heading corrected 2026-08-16, see Done section**
**Effort:** XS · **Priority:** P3 · filed 2026-08-07 · **Cross-link:** B-112 (instrument class)

> **DONE in v0.51.0.** No-fact runs are INCONCLUSIVE and emit `n/a` for artifact-derived fields;
> the self-test includes an engaged successful-tool transcript that produces no output.

**Why:** in `warehouseDimensionBinding`, every absence-shaped signal (`regionOnFact`,
`naturalKeyOnFact`, `newDimTables`) is computed from a fact body that is the empty string when no
fact was written. A run that produces nothing therefore reports the same values as a perfect run.
`Pass` is safe — it requires `factWritten` — and `Status` is `INCONCLUSIVE` when nothing was produced
*and* no warehouse-tree tool call was made. But a run that made tool calls and then died mid-flight
falls through both, as the B-119 run did; it graded `ERROR` only because the harness separately
checks `agentExit`. Had the CLI exited 0 after an early stop, the row would have looked clean.

**Why no gate catches it:** the self-test's non-engagement case has no tool calls, so it exercises the
`INCONCLUSIVE` path and never the "engaged, then produced nothing" one.

**Do:** emit `n/a` rather than `False` for every field derived from `$factBody` when `factWritten` is
false, and add the missing self-test case — a transcript with successful tool calls and an empty
target tree. Sweep the other graders for the same shape: **an absence-shaped signal is
indistinguishable from a missing artifact unless the artifact's existence is reported alongside it.**

---

### B-121 · Post-ship review owed for v0.51.0 — **DONE, heading corrected 2026-08-16, see Done section**

> **DONE (discharged) 2026-08-08.** Independent review by Claude Sonnet 5, separate session from
> the implementer. Re-ran validate-dist ×3 fresh (all 8 checks, all three dists), rebuilt all three
> dists and confirmed freshness, red-tested `no-meta-leak` (seen RED on a planted `WSD-999`, then
> GREEN restored), ran the dotnet hook suite and the meta suite (0 failures, 26 files total). No
> defects found in the v0.51.0 diff. Full evidence in `meta/review-ledger.md`.

---
### B-122 · Remove personal machine details from the public authoring repository — **DONE 2026-08-08, see Done section**
**Effort:** S–M · **Priority:** P3 · filed 2026-08-08 following B-109 · **Scope:** maintainer layer,
not shipped distributions

**Why:** B-109 established a generic gate preventing account-qualified home paths from reaching a
composed distribution, but the public authoring repository still contains personal machine details.
Observed on 2026-08-08: 30 tracked case-insensitive occurrences of the maintainer's name or GitHub
handle, including unnecessary `C:\Users\<account>\...` and `/c/Users/<account>/...` paths in
maintainer scripts, operational documentation, backlog evidence, decision records, and eval output.
The three `dist/` trees contained zero occurrences of the maintainer's name. Some authoring-repo
identity is intentional and public — the MIT copyright attribution and GitHub repository URLs — so
this is a classification and sanitisation task, not a blind text replacement.

**Do:** inventory every tracked account-qualified home path and personal-name occurrence, classify
each as required public identity or incidental machine detail, then:
1. replace incidental paths in prose/evidence with stable placeholders such as `<home>`,
   `<username>`, or `<repo>` without falsifying the recorded technical result;
2. replace hard-coded maintainer paths in executable scripts with parameters, environment variables,
   or existing host-resolution helpers, with behavioural tests for any changed executable;
3. preserve `LICENSE` attribution and repository-owner URLs unless the maintainer explicitly chooses
   otherwise;
4. add a repository-level gate for account-qualified home paths outside fixtures, distinct from
   B-109's distribution boundary, with narrow allow rules for deliberate test fixtures and an
   executable red test on Windows, Linux, and macOS forms;
5. record an explicit decision on Git history. Working-tree cleanup does not erase already-pushed
   commits; history rewriting requires a separate, maintainer-approved migration because it changes
   every descendant commit and affects collaborators, tags, and forks. Do not rewrite history as
   part of this item without that approval.

**Done when:** the tracked-tree sweep reports no incidental personal machine paths; every remaining
name/handle occurrence is enumerated and justified; affected scripts still pass their behavioural
tests; the new prevention gate has been observed red on planted generic fixtures and green on the
clean tree; and the history-retention/rewrite decision is recorded.

---
### B-124 · Decide whether a warehouse change belongs in an existing fact or a new fact — **CLOSED 2026-08-09, premise rejected; see Done**
**Effort:** M · **Priority:** P2 · filed 2026-08-08 · **Capability:** warehouse technical leadership

**Final status (2026-08-09): premise rejected.** Design/eval instrument:
`.claude/plans/2026-08-09-b124-fact-binding-design.md`. Opus rev 1 rejected the first design; rev 2
required a non-telegraphing `n>=2` ambiguous-pair baseline before premise lock. The corrected
instrument is red/green self-tested. After invalid spend-limit runs were excluded, the unchanged
skill chose the intended existing/new fact in 2/2 runs each. The registered stopping rule therefore
rejects the shipped matrix as unproportionate; no distribution change was made.

**Why:** `add-warehouse-load` now asks whether a dimension already exists, but it has no equally
explicit decision for facts. A new measure or business event can therefore be placed in a new fact
unnecessarily, or added to an existing fact whose grain, lifecycle, dimensionality, sparsity, or
loading semantics are incompatible. Either failure fragments a business process or creates a
mixed-grain fact whose numbers are easy to misinterpret.

**Do:** design a fact-binding decision that inspects the warehouse map and live repository evidence
before DDL is proposed. Compare business process, declared atomic grain, dimensionality, event
frequency and lifecycle, measure additivity, source authority, update/load semantics, and existing
consumer contracts. The outcome must distinguish: extend an existing fact, create a new fact,
model a separate snapshot/accumulating snapshot, or abstain pending a named missing fact. Explain
the evidence and trade-off; do not infer compatibility from similar table names.

**Framework fit:** integrate with B-125's modelling findings, B-126's change-impact contract,
B-127's scoped lineage, and B-128's physical review. Reuse `map-warehouse` and
`add-warehouse-load`; do not create a competing warehouse inventory or a second generic workflow.
Preserve evidence/confidence labels, bounded tracing, and explicit abstention.

**Design/review gate:** write and lock a design before implementation, including the proportionality
case and at least two approaches. Then obtain an independent adversarial review with **Claude Opus**;
the review may reject the premise. If Opus is rate- or spend-limited, mark the review **WAITING —
OPUS LIMIT** and continue only work that is independent of this item's implementation. Do not
substitute a lower tier and call the review complete.

**Done when:** ambiguous existing-vs-new fact fixtures have a pre-registered red baseline and a
constructible success case; post-change evals demonstrate the intended choice without mixed grain;
all applicable dists carry the guidance; and B-41 records whether the behavior is reliable enough
to ship.

---
### B-125 · Produce an evidence-ranked warehouse modelling health review — **DONE 2026-08-10**
**Effort:** M–L · **Priority:** P2 · filed 2026-08-08 · **Capability:** warehouse technical leadership ·
**Design:** `.claude/plans/2026-08-09-b125-warehouse-modelling-health-review-design.md` (rev 14;
Opus reviews plus user-authorized fresh Sol review; final verdict `ACCEPT — ship: YES`)

**Why:** the warehouse map reports several local findings, but it is not yet a systematic modelling
review. The framework can describe a model without consistently challenging mixed or unstated
grain, the wrong fact type, missing many-to-many bridges or allocations, duplicated/non-conformed
dimensions, inappropriate snowflaking, natural keys on facts, ambiguous special members, incorrect
measure additivity, or unsafe fan/chasm paths. The framework's premise requires it to surface these
issues and propose proportionate improvements, not merely catalogue tables.

**Do:** design a bounded review mode or extension to `map-warehouse` that checks dimensional
semantics and produces findings with evidence, confidence, severity, consequence, and a suggested
remediation. It must separate an observed defect from a convention preference, show uncertainty,
and avoid proposing a remodel without considering migration cost and downstream consumers. Include
the common fact, dimension, bridge, role-playing, conformance, SCD, special-member, and additivity
failure classes, while allowing repository-specific conventions to override generic advice when
they are explicit and coherent.

**Framework fit:** this is the shared modelling-analysis layer consumed by B-126, B-127, and B-128.
B-124 closed without a shipped dependency; its retained regression scenarios are evidence only.
Extend the existing map/finding vocabulary rather than creating a parallel architecture
document. Keep the default pass cheap; deeper tracing must remain scoped and on demand.

**Design/review gate:** locked design plus proportionality case, followed by an independent
adversarial **Claude Opus** review before implementation. If Opus is unavailable because of limits,
record **WAITING — OPUS LIMIT** and proceed only with independent design/backlog work.

**Done when:** planted-model fixtures make each claimed detector visibly fail before the change and
pass after it; clean and intentionally unconventional fixtures do not receive false defect claims;
recommendations cite repository evidence; and behavioural evals show the model uses the findings
rather than merely reproducing them.

**Done:** `map-warehouse` now emits structured evidence/confidence/severity/consequence/remediation
findings, applies evidence-gated modelling-health checks, and offers bounded allocation/fan-chasm
deepening. Rev-14 fixtures cover each supported detector plus clean, explicit-convention,
no-trigger, and existing-correct-bridge controls. The downstream scenario is finding-led and
requires direct load/consumer reads plus a safe one-as-of-date decision. Claude live reruns were
unavailable after HTTP 429 monthly-limit errors; the user authorized fresh Sol high-reasoning
substitution, whose final verdict was `ACCEPT — ship: YES` after independently rerunning the suite.

**RCA:** the first evaluator encoded expected words and confidence tiers before proving that the
fixture supported those conclusions. Reachability self-tests showed the matcher could turn green
and red, but could not establish that its answer key was true; correlated inherited defects hid the
problem. The corrected gate binds claims to direct artifacts/tool events, uses counterfixtures for
absent triggers, conventions, and already-correct structures, validates the full Findings contract,
and mutates plausible contradictory outputs rather than only missing keywords.

---
### B-126 · Make dimension and fact enhancement safe across downstream warehouse consumers — **CLOSED 2026-08-14, Phase 0 baseline reliable, no shipped change; see below**
**Effort:** M–L · **Priority:** P2 · filed 2026-08-08 · **Capability:** warehouse technical leadership

**Why:** deciding to reuse an existing dimension or fact is only the first decision. The current
recipe does not require a complete change-impact argument for attribute ownership, per-attribute
SCD behavior, source-authority conflicts, historical backfill, null/default semantics, grain or type
changes, or affected views, marts, procedures, semantic models, reports, exports, and external
contracts. A locally correct ALTER can still break the warehouse's overall design.

**Do:** design a warehouse schema-evolution preflight used before enhancing an existing fact or
dimension. It must identify upstream authority and downstream consumers, classify compatible versus
breaking changes, define history/backfill and deployment sequencing, preserve old consumers during
migration where required, and state rollback/deprecation obligations. It must establish the named
target fact/dimension from live evidence (B-124 shipped no separate decision artifact), consume
modelling findings from B-125 and scoped lineage from B-127; physical
consequences route to B-128 rather than being reinvented here.

**Framework fit:** add a composable preflight to the existing warehouse change workflow. Do not turn
`add-warehouse-load` into an exhaustive global scan: request deeper evidence only for the entities
and consumers touched by the proposed change, and abstain when the dependency graph is incomplete.

**What established practice says (checked 2026-08-11):** Kimball's dimensional guidance makes
fact grain uniformity and per-attribute SCD treatment semantic contracts, not incidental table
details; a Type 2 change creates a new surrogate-keyed row and changes which version future facts
reference. Fowler/Sadalage's evolutionary-database practice requires versioned migrations,
automated data movement, consumer-contract testing, and collaboration with people who can see
dependencies beyond the immediate application. Parallel Change supplies the compatible
expand → migrate → contract sequence for interfaces with multiple consumers. Microsoft's current
Power BI guidance says to inspect lineage and impact before changing a shared semantic model, test
dependent reports, and interpret the result as *potential* impact rather than proof of failure; its
architecture guidance likewise recommends compatibility with at least the preceding schema and
sequencing destructive changes across releases. Sources:
[Kimball SCD overview](https://www.kimballgroup.com/2008/08/slowly-changing-dimensions/),
[Kimball Type 2](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/type-2/),
[Kimball fact-table grain](https://www.kimballgroup.com/2003/01/fact-tables-and-dimension-tables/),
[Fowler/Sadalage evolutionary database design](https://www.martinfowler.com/articles/evodb.html),
[Fowler Parallel Change](https://martinfowler.com/bliki/ParallelChange.html),
[Power BI semantic-model impact analysis](https://learn.microsoft.com/en-us/power-bi/collaborate-share/service-dataset-impact-analysis),
and [Azure schema-update guidance](https://learn.microsoft.com/en-gb/azure/architecture/guide/multitenant/approaches/storage-data).

**Fresh-context adversarial review (Codex, 2026-08-11; does not satisfy the Opus gate):** verdict
**REJECT pending redesign and unchanged-skill baseline**. The first candidate assumed a behavioral
gap from missing prose, made `compatible in-place` unreachable by asking static repository evidence
to prove every runtime consumer, misstated the whole-file composition layout, conflated relationship
and finding vocabularies, depended on unimplemented B-127/B-128 work, and specified fixture topics
rather than discriminating graders. It also treated compatibility as one property when schema,
semantics, history, deployment, privacy, and rollback can disagree. The revised plan below folds
those findings. It remains unlocked and must receive a fresh Opus review after the redesign.

**Implementation plan — revised design candidate:**

1. **Test the premise before authorising shipped edits.** Freeze at least two non-telegraphing paired
   fixtures, expected artifacts, three-or-more repeated runs per available agent surface, direct-read
   observations, truncation/inconclusive rules, and grader mutations. Include (a) a repository-closed,
   genuinely compatible existing-dimension change and (b) identical additive DDL made incompatible
   by a visible consumer; add grain/SCD and incomplete-external-consumer cases. Run the unchanged
   `add-warehouse-load`. Stop with no shipped change if it reliably inventories the right evidence,
   distinguishes the pair, preserves uncertainty, and produces an executable migration decision.
2. Define evidence closure before grading safety. **Repository-visible compatibility** enumerates
   what the scan actually found and never implies completeness. **Deployment approval** additionally
   requires a stated closed-world premise or named owner/catalog/runtime attestation for external
   consumers, operational constraints, and authority. Name the constructible evidence world for
   every outcome; unavailable or access-limited evidence is `Unknown`, not a pass or an affected
   consumer. `Potential consumer` and `confirmed dependency` remain distinct.
3. Only if the baseline proves a material gap, add a bounded **Evolution preflight** section to
   `add-warehouse-load` after the skill has proved the target entity and before it writes DDL/load
   logic. Trigger it only for an existing fact/dimension change; a new entity continues through the
   existing path. The actual sources are the dotnet whole-file mirrors at
   `src/stacks/dotnet/files/{.claude,.github}/skills/add-warehouse-load/SKILL.md`; composition carries
   them into dotnet and monorepo. There is no monorepo source sibling and no new skill or
   always-loaded instruction.
4. Build an evidence packet for only the named entity and proposed fields: current declared and
   effective grain; keys and dependent facts; each field's source authority, type/null/default and
   SCD/history policy; load and backfill code; repository-visible views, procedures, marts, exports,
   semantic/report artifacts, tests, and deployment references. Reuse the fresh warehouse map and
   B-125 Findings. Until B-127 exists, permit only a minimal direct trace through already-open SQL
   and named repository references; mark the boundary and request deeper lineage instead of claiming
   B-127 was consumed or implementing a general lineage graph.
5. Emit a compact change matrix with one row per proposed semantic change: `Change`, `Current
   contract`, `Proposed contract`, `Evidence`, `Upstream authority`, `Affected consumers`,
   `Compatibility dimensions`, `History/backfill`, `Deploy sequence`, `Verification`, and `Open
   owner`. Define claim status separately (`Observed`, `Reported/attested`, `Inferred`, `Unknown`)
   rather than pretending it is the map's relationship or B-125 finding vocabulary. Grade schema,
   semantic, historical, privacy/security, deployment, and rollback compatibility independently per
   consumer before deriving a recommendation. Classify compatibility per consumer, not from DDL
   shape: additive nullable data can still change row
   counts, SCD interpretation, measures, wildcard extracts, or security exposure. Separate
   potential from confirmed impact.
6. Require an explicit invariants check before recommending reuse: no silent grain change; no
   attribute moved between authorities without conflict resolution; SCD behavior stated per changed
   attribute; unknown/null/default-member semantics preserved or migrated; fact/dimension key and
   effective-date resolution intact; historical recomputation policy named; reconciliation totals
   and privacy/security exposure considered. A grain change, key reinterpretation, destructive type
   change, or changed historical meaning defaults to breaking for the relevant dimension unless the
   explicitly bounded evidence proves otherwise.
7. Produce one of three decisions: **repository-compatible candidate** (with enumerated coverage,
   migration/backfill and consumer tests; deployment approval still separately gated),
   **parallel evolution** (expand with a new field/view/version, dual-write or backfill,
   migrate named consumers, observe, then contract after an owner/date/deprecation gate), or
   **stop/abstain** (authority, lineage, runtime consumer, or rollback evidence is missing). Never
   describe rollback as simply reversing DDL after consumers or history have changed; name restore,
   replay, or forward-fix mechanics and the last safe point. For parallel evolution name the
   authoritative pre-cutover write path, dual-write/backfill reconciliation, cutover and abort
   criteria, backup/restore assumptions, replay boundary, post-cutover writes, and the point where
   rollback becomes compensating forward migration.
8. Keep minimum operational feasibility here: backfill volume/window, locks, log growth, partition
   mechanics, deploy ordering, and last-safe-point evidence determine whether the migration is
   executable. Route optimisation and broader physical-design judgment to B-128. Likewise do not
   duplicate B-129's reporting-interface design; here a report/semantic model is a contract to
   preserve, test, migrate, and deprecate, while B-129 owns choosing/designing a new publication
   surface.
9. Expand the pre-registered fixtures only if the unchanged baseline fails. Cover: a truly compatible
   nullable descriptive Type-1 attribute; the same DDL with a `SELECT *` extract or sensitive-field
   exposure (not automatically safe); a Type-1→Type-2 policy change; a fact-grain change; a widening
   and a narrowing/type-semantic change; historical backfill with late-arriving facts; an external
   or access-limited semantic consumer; and incomplete lineage. Plant mutations that omit a
   consumer, call every `ADD COLUMN` safe, fabricate rollback, or confuse potential with confirmed
   impact. Bind grader assertions to the correct entity/consumer and direct artifact reads; include
   clean/convention counterfixtures, contradictory prose, empty/truncated output, and independent
   mutations for lineage, compatibility, sequencing, and rollback. The abstention cases alone cannot
   prove discrimination. Show every grader red and green.
10. After implementation, run the repeated behavioral matrix, then greenfield, brownfield, and update
   delivery through both installer twins and applicable root stack-detection paths. Verify both skill
   mirrors refresh as intended without overwriting protected consumer material. Success requires the
   correct evidence boundary, dimension-level compatibility result, and usable migration sequence,
   not checklist words. Then compose/freshness and `validate-dist` ×3; Angular behavior stays
   unchanged, while release-wide version/changelog stamping remains expected.

**Proportionality:** the current evidence proves a prose omission, not behavioral harm. The unchanged
baseline is therefore the smallest response and can close the item without a shipped change. Only a
reproduced decision defect authorises one demand-triggered section in an existing skill. A persistent
lineage service, warehouse-wide graph, schema registry, or new routed skill remains out of scope
until B-127/B-42 supplies observed evidence that the bounded repository scan is insufficient.

**Status: OPUS GATE COMPLETE, DELTA-REVIEWED 2026-08-13 — LOCK WITH REVISIONS (Phase 0 only).** See
`meta/workspace-decisions.md` WSD-041. Steps 1-2 (premise test) locked with a named three-world
fixture set (compatible-visible-consumer / incompatible-visible-consumer / incomplete-closure
abstention control), each with a non-breaking or breaking visible consumer as specified, identical
closed-world statement, and byte-identical prompts; graders proven red/green before the baseline
runs; closed-world attestation sources enumerated with the abstention control proving "deployment
approval" reachable. Steps 3-10 (the shipped preflight, **including the fork-point insertion
location** — delta review caught this being locked prematurely) remain explicitly unlocked pending
the baseline's actual result, and now carry a non-binding redesign watch list covering the fork
point, the change-matrix/six-dimension contradiction, the operational-impact taxonomy gap, the
backfill trichotomy, and the body-growth ceiling. Dangling-dependency watch list extended to cover
B-127 (deferred), B-128 (rejected outright by WSD-039 — stronger gap), and B-129 (probe-only). Next:
build fixtures, prove graders, run the baseline.

**Done when (superseded by WSD-041 for the currently-authorised Phase 0 scope — this is the shipped
preflight's criteria, applicable only if steps 3-10 are later locked):** ~~fixtures cover safe
additive evolution, SCD-policy change, historical backfill, grain or type breakage, and a downstream
semantic/report consumer; the framework names affected artifacts and a compatible migration path; and
evals prove it does not treat every additive column as safe.~~

**Done when (actual, Phase 0 scope, per WSD-041):** Phase-0 graders proven red/green before any paid
run; the three-world fixture set (compatible-visible-consumer / incompatible-visible-consumer /
incomplete-closure abstention) runs n≥2 with byte-identical prompts; if unchanged `add-warehouse-load`
reliably distinguishes the compatible and incompatible worlds and reaches "deployment approval" only
via a named attestation, B-126 closes with no shipped change (WSD-037 pattern) and the fixture is
retained as regression evidence; otherwise steps 3-10 are redesigned against the observed gap.

**Final status (2026-08-14): baseline reliable, closed with no shipped change.** Graders were proven
red/green before every paid run. All three worlds ran n=2 on the live Claude Code host (one
transport-error attempt on `warehouse-schema-incompatible` discarded, not counted): compatible-
visible-consumer PASS/PASS (`DEPLOYMENT_APPROVED` via named-owner attestation both times);
incompatible-visible-consumer PASS/PASS (the unchanged skill detected the `SELECT *` break both
times, fixed it, and reached `DEPLOYMENT_APPROVED` via named-owner attestation); incomplete-closure
abstention control PASS/PASS (the skill wrote the provably-safe additive DDL but correctly withheld
"deployment approved" both times, since no attestation source exists in that fixture by design — the
`schema-incomplete-attested-green` self-test independently proves that state is reachable given a
real attestation, so the abstention isn't a decorative unreachable measure per Maintenance rule 4).

**RCA (Maintenance model #5).** Two real grader defects were caught during this baseline, both by
reading the raw transcript rather than trusting the boolean verdict, both the same under-crediting
class as WSD-039/B-128's RCA: (1) the `warehouse-schema-incomplete` grader only recognized two
response shapes (full abstention with no DDL, or DDL with an attested approval) and scored a
demonstrably more correct third shape — writing the provably-safe additive DDL while correctly
withholding the separate deployment-approval claim — as FAIL; (2) the `deploymentApproval` regex
required "deployment" immediately followed by "(is )approved" and missed the natural
"Deployment decision: Approved" colon-and-label phrasing, scoring a fully correct, well-reasoned
approval as FAIL. **Why no gate caught it:** both graders were self-tested against hand-authored
transcripts *before* the live run per Maintenance rule 4, but the hand-authored transcripts were
written by the same reasoning that wrote the grader, so both shared the author's blind spot about
which response shapes and phrasings a real model would actually produce — self-authored fixtures
proved the grader was *internally consistent*, not that it covered the real behavioral space. **What
else is exposed to the same class:** every other from-scratch grader built this cycle (B-127's and
B-129's, not yet run live) has the identical structural risk — a hand-authored red/green pair can
only prove reachability of the cases its author thought of. Recommend, when B-127/B-129 run their own
live baselines, budgeting for at least one grader-correction round found by direct transcript read
before accepting any FAIL as a true framework gap, rather than treating a self-tested grader as
final. Full transcripts, evidence, and both fixes are in `meta/eval-results.md` (B-126 Phase 0
sections) and `.claude/evals/run-agent-evals.ps1` (commits `a5dcb02`, `bcc3856`, `855a9cb` on
`codex/b126-schema-evolution-probe`).

**Correction (2026-08-15), prompted by B-127's routing-non-reach result.** B-127's baseline (WSD-040)
gated its decision-outcome score on the skill actually being read; when applying the equivalent check
here retroactively, all six counted trials' recorded `Detail` fields show `skill=False` in five of
six — `add-warehouse-load` was invoked as a `Skill` tool call in only one trial (rep 2's
`warehouse-schema-compatible` case). This grader was never built with WSD-040 revision (i)'s
routing-attribution gate (WSD-041 predates it), so the "Final status" prose above overclaims: it
attributes the observed correct behavior to `add-warehouse-load`'s guidance, but the guidance was
barely consulted. **The behavioral finding itself still holds** — every counted trial correctly
distinguished compatible from incompatible and reached deployment approval only via a named
attestation, regardless of whether the skill was read — so "no shipped change" remains the right
disposition; what is wrong is the attribution. The accurate statement is: *Claude Code, mostly
reasoning from the fixture's directly-supplied evidence docs rather than the skill's body, reliably
produced the correct outcome*, which is if anything a stronger case for "no shipped change" (the
outcome doesn't depend on the skill), not a weaker one.

This is also a new, more specific data point for B-98: B-124's near-identically-phrased write-task
prompts ("Implement this warehouse change... I approve the change in advance...") routed to
`add-warehouse-load` in **4 of 4** counted trials, while B-126's equally write-task-shaped prompts
routed in only **1 of 6** — a real discrepancy between two items testing the same skill with similar
phrasing, not just another instance of "sometimes it doesn't fire." The likely difference is that
B-126's fixture stages `docs/schema-evolution-premise.md` and `docs/product-consumer-closure.md`
directly and prominently, giving the model an equally-relevant path that doesn't require the skill —
B-124's fixture did not stage comparably on-point documents. Cross-referenced at B-98 as a second,
more diagnostic confirmation of that item's necessity.

**RCA addendum, Maintenance rule 5 (why did no gate catch it, what else is exposed):** the original
grader recorded `skill=` in its `Detail` output but never gated `$pass` on it, unlike B-127's grader
built one day later under WSD-040's explicit revision (i). No self-test caught this because the gap
was in what the grader *measured*, not in whether it scored correctly against its own frozen
transcripts — a self-test proves internal consistency with the grader's own assumptions, not that
those assumptions (here, "the skill doesn't need to be gated because the prompt shape resembles
B-124's") were checked against the live data. **What else is exposed:** B-129 (WSD-042) has its own
routing-gated design and should be checked for the same class before its baseline runs; B-124 was
checked and is clean (4/4 skill-invoked), B-128 was checked and does not depend on a skill-attribution
claim at all. Full skill= values: `meta/eval-results.md` B-126 Phase 0 rep 1/rep 2 sections.

Steps 3-10 (the shipped preflight) remain unauthorised and unimplemented. The three-world fixture set
and both grader fixes are retained under `.claude/evals/` as regression evidence (WSD-037 pattern).

---
### B-127 · Trace a warehouse attribute or metric from source to consumption on demand — **CLOSED 2026-08-15, Phase 0 baseline ran, no shipped change; see below**
**Effort:** M–L · **Priority:** P2 · filed 2026-08-08 · **Capability:** warehouse technical leadership

**Why:** the map records entity-level flow, relationships, and consumption surfaces, but it cannot
yet explain a named attribute or metric end to end. Without scoped lineage the framework can miss
filters, derivations, defaulting, deduplication, effective-date resolution, currency/unit/time-zone
conversion, and semantic redefinition between source, staging, core facts/dimensions, marts, and
reports. Whole-warehouse column lineage would be costly and brittle; the need is a bounded trace
for the change or question at hand.

**Do:** design an on-demand trace that starts from a named source field, warehouse attribute,
measure, or reported metric and follows repository evidence in either direction. Record each
transformation, filter, join/key resolution, unit/currency/time-zone rule, aggregation, owning
definition, and consumer, with gaps and conflicts explicitly marked. Capture canonical metric
semantics where the repository defines them, but do not invent business definitions or claim
runtime lineage from static evidence alone.

**Framework fit:** enrich the existing warehouse map or a linked scoped artifact using its evidence
and confidence vocabulary. B-125 uses the trace for modelling findings, B-126 for impact, and B-128
for workload evidence; B-124's retained evals may use it in future regression fixtures, but there is
no shipped B-124 consumer. The trace must be demand-driven and
budgeted, not an always-on whole-repository graph.

**What established practice says (checked 2026-08-11):** OpenLineage's current column-lineage
facet distinguishes a value-producing `DIRECT` dependency from `INDIRECT` influences such as
joins, filters, grouping, sorting, windows, and conditions, then records transformation subtype,
description, and masking. That distinction prevents a trace from claiming that a metric depends
only on the columns in its final expression. OpenMetadata supports column-level impact tracing but
also allows manual lineage where automation cannot surface it. Microsoft Purview's current docs are
more important for their limits than their happy path: stored procedures with create/drop patterns,
dynamic M parameters, non-Azure-SQL Power BI sources, process-mediated manual column links, and
several Fabric/Synapse paths can leave lineage incomplete. Kimball grounds a metric in the fact's
declared grain and distinguishes additive, semi-additive, and non-additive measures; for ratios the
additive components should be aggregated before division. A catalog edge or same-named field is
therefore evidence of a candidate path, not proof of semantic equivalence or runtime execution.
Sources: [OpenLineage column-lineage facet](https://openlineage.io/docs/spec/facets/dataset-facets/column_lineage_facet/),
[OpenMetadata column lineage](https://docs.open-metadata.org/latest/how-to-guides/data-lineage/column),
[Microsoft Purview lineage guide](https://learn.microsoft.com/en-us/azure/purview/catalog-lineage-user-guide),
[Power BI lineage limitations](https://learn.microsoft.com/en-us/purview/how-to-lineage-powerbi),
[Fabric lineage limitations](https://learn.microsoft.com/en-us/purview/data-map-lineage-fabric),
[Kimball facts and grain](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/facts-for-measurement/),
and [Kimball measure additivity](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/additive-semi-additive-non-additive-fact/).

**Fresh-context adversarial review (Codex, 2026-08-11; does not satisfy the Opus gate):** verdict
**REJECT pending baseline-first redesign**. The reviewer found that the first candidate conflated
connector-extracted lineage, captured execution, and runtime values; forced a branching lineage DAG
into a false ordered path; could manufacture metric authority from an implementation owner; gave no
executable search limits; overclaimed effective grain from static SQL; and made unimplemented
B-126/B-128/B-129 work acceptance dependencies. Persistence also conflicted with the map's fixed
seven-heading contract. The investigation-first plan below incorporates those findings and remains
unlocked.

**Implementation plan — revised investigation and conditional design:**

1. **Authorise only the unchanged-skill baseline now.** Freeze non-telegraphing forward and reverse
   questions, normalized edge answers, exact decisive-artifact reads, three-or-more runs per
   available agent surface, hard budgets, truncation/inconclusive rules, and grader mutations. Ask
   unchanged `map-warehouse` explicitly to perform the scoped second semantic pass it already offers
   (not an ordinary map refresh). Include one key-resolution trace it should solve today, one
   attribute trace, one branching metric, one conflict, and one budget-exhaustion case. Close or
   narrow B-127 without shipped changes if that behavior is already reliable and decision-useful.
2. Define the trace as one named **subject** and one named **question/direction**, not a
   whole-repository graph: source field → published attribute/metric, warehouse field/measure → sources and consumers,
   or reported metric → definition and inputs. Resolve ambiguous names before tracing; record exact
   fully-qualified identifiers, requested scope, start/end, and the warehouse-map freshness/boundary.
3. **Only if the baseline reproduces a material decision defect**, design an on-request **Trace one
   attribute or metric** mode in the existing `map-warehouse` skill. The sources are the dotnet
   whole-file mirrors at
   `src/stacks/dotnet/files/{.claude,.github}/skills/map-warehouse/SKILL.md`, composed into dotnet
   and monorepo. Do not add an always-routed skill, change Angular behavior, or run this semantic
   second pass during an ordinary map refresh.
4. Pre-register an executable search contract, then calibrate it from baseline cost without moving
   the thresholds after seeing correctness. Initial ceiling: one repository-wide indexed text
   reference search (report total hits, inspect at most the first 100 under deterministic
   path/identifier ranking), 16 files opened, graph depth 8, 12 candidate edges per frontier,
   4 semantic/publication artifacts, and 20k trace-task tokens. Maintain a visited node+artifact set
   to stop cycles. Terminate as `question answered`, `budget exhausted`, `ambiguous frontier`,
   `unsupported artifact`, or `external boundary`; list skipped candidates and the exact bounded
   continuation. Binary/remote semantic models are unsupported unless a directly readable export or
   connector record exists.
5. Emit a bounded trace **edge table**, not a linear path:

   | edge id | from node(s) | to node(s) | influence | operation | declared semantics | evidence coordinates | evidence dimensions |
   |---------|--------------|------------|-----------|-----------|--------------------|----------------------|---------------------|

   Stable node IDs permit branches, merges, multiple inputs/outputs, and cycles. `influence` is value,
   row selection, grouping/partition/order, key/version resolution, or conditional control;
   `operation` records identity, transform, aggregation, filter, join, group, window,
   conditional/default, deduplication, conversion, union, or semantic alias. Declared input/output
   grain, grouping, temporal rule, cardinality, and additivity are independently `Unknown` when the
   artifact cannot establish them. An optional narrative may summarize the graph but never replace it.
6. Keep evidence on four independent axes: **origin** (repository, catalog, execution event, human),
   **acquisition** (direct read, connector-extracted, run-captured, attested), **assertion** (declared
   transform, possible path, observed execution, observed value behavior), and **scope/time**
   (branch/version, environment, run/job ID, timestamp). Add completeness only as `none`, `bounded`
   with its enumerated frontier, or `externally attested`. Use map provenance only for its existing
   fact→dimension assertion. Static SQL never proves execution or effective cardinality; a captured
   run proves only that run; connector output inherits the connector's documented limits.
7. For a metric, add a **candidate semantic contract**, not a canonical one: implementation
   definition, publication definition, accountable business authority, authority evidence, event or
   declared grain, numerator/denominator or base measures, aggregation/additivity, dimensions,
   filters/exclusions, calendar/as-of rule, units/currency/time zone, null/default behavior, and
   publication consumers. Authority requires an explicit governance/convention artifact or named
   accountable attestation for that metric and scope; a developer, catalog owner, or model owner is
   not interchangeable with business authority. Preserve conflicting definitions separately and
   abstain. Include a fixture where a real governance artifact makes authority reachable.
8. Default to an ephemeral response. Persist only with explicit user approval to a separate
   `docs/warehouse-traces/<stable-subject-id>.md`, linked from the existing map Coverage or
   Dimensional-semantics section without adding an eighth required heading. Do not auto-retain or
   auto-delete traces. Record subject/question, verifier, verified date, source-map fingerprint, the
   normalized sorted list of decisive artifact paths+content hashes, coverage/frontier, and refresh
   triggers. A changed decisive hash or missing path marks it stale; replacement/retirement remains
   an explicit reviewed edit.
9. Design fixtures that discriminate rather than reward abstention: direct rename; derived measure
   with filter-only and join-key influences; deduplication/window; currency and time-zone conversion;
   ratio whose components must aggregate before division; SCD effective-date resolution; reverse
   trace from a semantic/report measure; conflicting definitions; dynamic SQL/external catalog gap;
   and a same-named decoy. Include clean controls and paired fixtures where one predicate changes the
   correct answer. Mutate missing indirect edges, wrong direction, wrong grain, fabricated authority,
   false completeness, and plausible-but-wrong field binding; show every deterministic grader red
   and green and require direct reads of the decisive artifacts.
10. Measure utility, not document production. Use a self-contained decision such as whether report X
    must migrate before attribute Y changes, or whether metric Z aggregates its components before
    division; construct paired worlds whose correct outcome differs only at a decisive trace edge.
    Success requires the trace to change that decision correctly while staying within the budget;
    a complete-looking path that does not affect a decision, or a correct abstention on every case,
    is insufficient. B-125/B-126/B-128/B-129 may later consume the contract, but are not acceptance
    dependencies. B-128 receives only candidate query/physical paths; workload frequency, volume,
    latency, skew, and runtime use require separate telemetry or captured execution evidence.
11. After implementation, repeat behavioral trials on each available supported host and verify
    greenfield, brownfield, and update delivery through both installer twins and relevant root stack
    detection. Confirm delivery and update of both skill mirrors plus dotnet/monorepo composition.
    Separately use behavioral fixtures for trace/staleness
    semantics and a brownfield document fixture to prove an existing user-authored map/trace is not
    silently overwritten. Then compose/freshness and `validate-dist` ×3; Angular receives only
    release-wide stamps/changelog truth, not warehouse behavior.

**Proportionality:** the existing map already identifies edges, consumption surfaces, and offers an
on-request semantic second pass; no behavioral harm is yet observed. Only the unchanged-skill
baseline is presently proportionate and authorised. If it demonstrates a repeatable decision defect,
the smallest candidate is one demand-triggered bounded edge response, ephemeral by default. A
persistent service/graph, parser, catalog integration, whole-warehouse scan, automatic retention, or
new skill is not authorised.

**Status: OPUS GATE COMPLETE, DELTA-REVIEWED 2026-08-13 — LOCK WITH REVISIONS (baseline only).** See
`meta/workspace-decisions.md` WSD-040. Items 1-2 locked with binding revisions: plain non-telegraphing
consumer prompt (no skill named); grade on paired-world decision outcome, not exact-artifact-read
matching; drop the unreachable numeric budget-exhaustion case; add the same-named-decoy case to the
baseline; prove graders red/green before the baseline runs; correct necessity framing to the
routing-promise/body-gap mismatch; cite `meta/field-reports.md` #3 and the `usedDeadColumn` residual
signal, each labelled precisely (observed-shape harm vs. noisy residual, neither proof of this
baseline's result); name the one supported live-eval host and track skill-selected/read as
attribution evidence separate from the decision outcome (a routing non-reach must not be scored as a
pass). Items 3-10 (the trace-mode design) remain explicitly unlocked. Next: build fixtures, prove
graders, run the baseline.

**Done when (superseded by WSD-040 for the currently-authorised baseline scope — this is the
trace-mode design's criteria, applicable only if items 3-10 are later locked):** ~~multi-stage
fixtures prove forward and reverse tracing through SQL transformations and a consuming semantic/report
artifact; conflicting and absent evidence produce abstention rather than a fabricated line;
cost/coverage is reported; and evals show the trace changes a downstream design or review decision.~~

**Done when (actual, baseline scope, per WSD-040):** baseline graders proven red/green before any
paid run; the plain-language, non-telegraphing baseline (including the same-named-decoy case) runs
n≥2 on the named live-eval host with skill-selected/read tracked separately; if unchanged
`map-warehouse` reliably answers the paired-world decision without fabrication, B-127 closes with no
shipped change (WSD-037 pattern) and the fixture is retained as regression evidence; otherwise items
3-10 are redesigned against the observed failure mode, not the current sketch.

**Final status (2026-08-15): routing precondition never fired, closed with no shipped change.**
Sol built the eight locked WSD-040 baseline cases (key-resolution pinned/deferred,
attribute-transform FX-conversion/null-default, metric ratio/additive, same-named decoy per
`field-reports.md` #3, and the conflicting-views abstention control), self-tested every grader
red/green against frozen transcripts before any paid run, per (e). Sol's sandbox again had no network
egress and could not write to this worktree's `.git` index (same limitations as B-126); Claude took
over both directly, independently re-verifying the build (real PowerShell 7 parse + full `-SelfTest`
re-run, not trusting Sol's self-report, since Sol's own sandbox lacked `pwsh` and had self-tested
against a patched copy) before accepting the commit.

The live baseline ran n=2 per scenario (16 trials total) against unchanged `map-warehouse` on Claude
Code, the named live-eval host. **All 16 trials came back `ROUTING_NON_REACH`**: the skill was never
read or selected for any plain, non-telegraphing, no-skill-named prompt, in any of the five case
shapes. Per WSD-040 revision (i) this is not scored as a pass or fail — the baseline's actual
decision-outcome question was never exercised in a single trial. Five transcripts were read directly
and all five showed Claude Code reasoning to a correct, well-evidenced answer via direct DDL/view
inspection without the skill — the same brute-force pattern already on record in
`meta/eval-results.md`'s 2026-08-06 entry, viable at this fixture's ≤4-table scale but not at the
scale the field reports describe. Full per-scenario detail, both reps, and the harness bug found and
fixed along the way: `meta/eval-results.md` "B-127 Phase 0" sections.

**RCA (Maintenance model #5).** *Why did no gate catch it before run-time?* This wasn't a process
gap — WSD-040 revision (i) was written specifically to anticipate and correctly handle exactly this
outcome; the design worked as intended when the anticipated edge case occurred. One real harness bug
was found and fixed same-day: `Test-ScenarioEvidence` correctly returned `Status='ROUTING_NON_REACH'`,
but the `-Live` driver's outer status computation only special-cased `INCONCLUSIVE` before falling
through to `'FAIL'`, silently reprinting every non-reach as a decision-outcome failure — the grader's
own self-test didn't catch it because the bug was in the outer driver loop, not the grader function;
it was caught only by reading a real `-Live` run's output. *What else is exposed to the same class?*
Any future scenario family that introduces a new `Test-ScenarioEvidence` status distinct from
`PASS`/`FAIL`/`INCONCLUSIVE` needs the matching branch added to the outer driver at the same time —
self-testing the grader function in isolation does not prove the live driver reports it correctly.
B-129 (WSD-042) has its own routing-gated "carrier unreachable" concept and should check for the same
gap when its probe is built.

The observed routing gap is not new evidence: it reproduces the already-tracked B-98 ("a prompt
matching no skill description fails silently"), explicitly out of scope for B-127 per WSD-040's
Rejected section. Because no decision-outcome defect was observed in either direction, WSD-040's
escape hatch for authorizing items 3-10 ("redesigned against the observed failure mode") does not
apply — there is no observed decision-outcome failure mode, only a routing failure already tracked
elsewhere. **B-127 closes with no shipped change**; items 3-10 (the trace-mode design) remain
unauthorised, and the fixture set and grader are retained as regression evidence and as a second live
confirmation of B-98's necessity.

---
### B-128 · Review warehouse physical design against its actual load and query workload — **CLOSED 2026-08-13, premise rejected; see below**
**Effort:** M–L · **Priority:** P2 · filed 2026-08-08 · **Capability:** warehouse technical leadership

**Why:** the framework records partitioning, columnstore, retention, and load ordering, but does not
systematically test whether physical design supports the warehouse's observed loading and access
patterns. Sound logical modelling can still fail through unsuitable partition keys, indexes,
columnstore layout, distribution/sharding, compression, statistics, materialisation, or an
unexamined load-versus-query trade-off.

**Do:** design a physical-design review driven by repository evidence about fact size/growth,
incremental and backfill patterns, join/filter/grouping paths, concurrency, retention, platform
capabilities, and operational constraints. Assess partitioning, indexing/columnstore, distribution,
compression, statistics, aggregates/materialised views, and maintenance cost where applicable.
Recommendations must name the workload assumption and expected benefit, distinguish measured facts
from estimates, and request plans/runtime evidence rather than asserting performance when static
code is insufficient. This is architecture review, not a replacement for single-query tuning.

**Framework fit:** establish the grain/fact target from current repository evidence (B-124 shipped
no separate choice artifact) and optionally use B-125's shipped logical findings. B-126/B-127 are
unlocked future integrations, not inputs or acceptance dependencies. Keep platform-specific advice
behind detected capabilities and avoid universal vendor prescriptions. Prefer extending the
warehouse review workflow over a new always-routed skill unless the design demonstrates a routing
need.

**What established practice says (checked 2026-08-11):** Microsoft's current SQL Server guidance
treats index choice as a workload-dependent balance between query speed, write/maintenance overhead,
and storage. Query Store supplies query, plan, runtime, variation, and wait history; an estimated plan
does not execute and carries no runtime resource/row evidence, while an actual plan does. Columnstore
benefits large scans, but small rowgroups, partition granularity, load batch shape, deletes, and
selective point access materially change the answer. Snowflake says explicit clustering is unnecessary
for most tables: use large-table scan evidence and common filters, then prove benefit offsets initial
and ongoing credit/storage cost. BigQuery likewise ties partition/clustering value to eligible
predicates, pruning, column order, bytes scanned, table size, and update patterns; expressions can
defeat pruning even when the “right” column appears. Leading vendor advice therefore supports an
evidence ladder — declared layout → estimated behavior → observed representative workload → measured
before/after outcome — and rejects universal index, partition, or materialisation recipes. Sources:
[SQL Server index design](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-index-design-guide),
[Query Store workload practice](https://learn.microsoft.com/en-us/sql/relational-databases/performance/best-practice-with-the-query-store),
[estimated vs actual plans](https://learn.microsoft.com/en-us/sql/relational-databases/performance/display-and-save-execution-plans),
[columnstore design](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-design-guidance),
[columnstore loading](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-data-loading-guidance),
[SQL Server statistics](https://learn.microsoft.com/en-us/sql/relational-databases/statistics/statistics),
[Snowflake table/clustering considerations](https://docs.snowflake.com/en/user-guide/table-considerations),
[Snowflake clustering cost](https://docs.snowflake.com/en/user-guide/tables-auto-reclustering),
[BigQuery partitioning](https://docs.cloud.google.com/bigquery/docs/partitioned-tables), and
[BigQuery clustered-query guidance](https://docs.cloud.google.com/bigquery/docs/querying-clustered-tables).

**Fresh-context adversarial review (Codex, 2026-08-11; does not satisfy the Opus gate):** verdict
**REJECT candidate beyond a redesigned unchanged-skill baseline**. The reviewer found no observed
harm attributable to current guidance; asking a structural grep-based mapping skill for a detailed
physical review would mostly test model improvisation and telegraph the desired rubric. The first
plan also left “representative workload” unreachable, offered a feature taxonomy instead of safe
versioned platform adapters, blurred evidence validity, omitted mixed/invalid experiment outcomes,
under-specified noise/privacy/cost controls, and expanded an M–L item into a cross-vendor tuning
product. The narrower investigation below folds those findings and remains unlocked.

**Implementation plan — revised investigation and conditional design:**

1. **Authorise Phase 0 only.** Pre-register a small unchanged-framework behavioral baseline before
   adding any instructions. Compare (a) ordinary routed warehouse work, (b) an explicit physical-
   design question, and (c) a control with no performance question. Use two or three paired SQL
   Server text fixtures plus normalized supplied telemetry: identical DDL with scan-heavy versus
   selective workload; point lookup versus columnstore/load trade-off; representative versus biased
   sample; and a justified no-change case. Do not put expected tuning vocabulary in the prompts.
2. Attribute failure carefully. Freeze prompts, decisive artifacts, evidence available, normalized
   outputs, direct-read requirements, three-or-more repetitions per available surface, and red/green
   grader mutations. A shipped change is authorised only if unchanged behavior repeatedly makes a
   materially wrong or unsafe decision *because framework guidance is missing or misleading*, not
   because a general model lacks specialist database knowledge. Otherwise close or narrow B-128.
3. Define workload representativeness before any recommendation: named population (queries/jobs in
   scope), capture source and integrity, environment/version/settings, selection method, time window,
   release/seasonal/peak periods, parameter/skew classes, coverage by execution count and by the
   primary resource/cost measure, excluded classes, and a stability comparison with an adjacent
   window. No universal percentage is assumed; the owner pre-registers the material population and
   minimum coverage. Missing or unstable coverage yields `Evidence collection required` only.
4. Record evidence on independent axes: origin/acquisition (direct repository read, supplied export,
   captured execution, aggregate telemetry, attestation); exact coordinates/integrity; platform,
   version/edition/service, environment and settings; time/window/population; direct versus attested;
   and representativeness status. Static DDL/query text is a candidate mechanism; estimated plans are
   predictions; actual plans prove one execution; aggregates are meaningful only with population
   metadata. Screenshots or exports without coordinates, freshness, and environment remain unverified.
5. Use a complete deterministic state transition: `Evidence collection required`, `Reject from
   evidence`, `Candidate experiment`, `Awaiting authority`, `Invalid experiment`, `No material
   difference`, `Measured improvement`, `Measured regression`, or `Mixed/guardrail failure`.
   Define a constructible fixture world for each exercised state. Improvement requires the primary
   threshold, every correctness/load/cost/maintenance guardrail, comparable environments, and proper
   authority; it cannot hide a regression behind one faster query. Abstention is not the only pass.
6. If Phase 0 reproduces an attributable gap, Phase 1 may add one ephemeral on-request **comparison
   and experiment-planning** section to the existing dotnet `map-warehouse` mirrors at
   `src/stacks/dotnet/files/{.claude,.github}/skills/map-warehouse/SKILL.md`, composed into dotnet
   and monorepo. It performs no query, DDL, plan generation, telemetry export, or persistence. Keep
   the C#-only `perf` skill and Angular behavior unchanged.
7. Phase 1 supports only the evidenced platform/version family from Phase 0 (initially SQL Server).
   Its adapter contract names detection precedence, required version/edition/service and managed-
   feature state, permissions, current official capability source/date, supported alternatives and
   diagnostics, `Unknown/unsupported` behavior, and expiry/recheck trigger. Snowflake, BigQuery, or
   other adapters require a later separately reviewed evidence case and discriminating fixture; do
   not ship vendor-name substitutions from the research survey.
8. The conditional output compares `No change` plus only applicable alternatives, binding each to
   evidence, predicted mechanism, query benefit, load/write cost, storage/maintenance cost,
   operational risk, reversibility, falsifying diagnostic, safe experiment proposal, authority
   needed, and decision state. Static review can nominate or reject an experiment, never label an
   optimization measured or validated.
9. A proposed experiment must pre-register identical data/configuration, randomized or interleaved
   A/B order where possible, compilation and cold/warm-cache populations, background-load/noisy-
   neighbor/autoscaling controls, parameter and concurrency mix, stabilization, repetitions, raw-run
   retention, robust distribution/uncertainty summary, outlier rule, correctness, primary outcome,
   all guardrails, abort/invalidation conditions, and rollback/drop plan. The fixed snapshot's scope
   and representativeness are explicit; no execution is part of this item.
10. Define authority levels separately for repository reads, telemetry/history read or export, plan
    generation, query execution/replay, non-production DDL, production action, and spend. Default is
    proposal-only. Require minimization/redaction of literals and sensitive query text, secret
    exclusion, approved storage/retention, cost ceiling, and named abort owner before proposing a
    higher-authority phase. A restored database or estimated compilation can still expose data or
    consume resources.
11. Phase-0 graders bind table/workload/evidence coordinates, validate units/arithmetic/comparison
    direction, reject cherry-picked samples and vendor-keyword matching, and mutate evidence axes,
    representativeness, no-change, cost, guardrails, and state transitions red→green. Include one
    unsupported-platform control that safely requests capability evidence rather than inventing
    advice. Broader platform/mechanism fixtures are explicitly deferred.
12. Keep boundaries honest: B-125 may provide current logical context; B-126/B-127 are future
    integrations, not prerequisites; B-129 owns publication design. Scope is one named table/fact
    plus the named interacting objects required to evaluate its joins, aggregate, distribution, or
    load. Single-query tuning remains out unless that query is part of the pre-registered workload.
13. If Phase 1 is eventually implemented, verify exact changed-skill delivery: both authored mirrors,
    dotnet/monorepo composition, disabled/discovered-skill semantics, greenfield and update installs
    through both twins, and dotnet/monorepo root detection. Specify the expected brownfield collision
    behavior for a same-name customized framework skill. Add document-preservation tests only if a
    later design actually writes a document. Then compose/freshness and `validate-dist` ×3.

**Proportionality:** no harmful framework-caused tuning decision has been observed, and the current
skill promises structural mapping rather than performance review. Only the small unchanged-framework
baseline is presently proportionate. If it proves attributable harm, an ephemeral SQL Server
comparison/experiment-planning section is the maximum authorised candidate. Automated capture,
execution, production DDL, cross-platform tuning engine, persistent telemetry, whole-warehouse scan,
or new skill is not authorised.

**Status: OPUS GATE COMPLETE, DELTA-REVIEWED 2026-08-13 — REJECT PREMISE, substitute locked.** See
`meta/workspace-decisions.md` WSD-039. The 4-fixture-family baseline, 9-state evidence machine, and
7-rung authority ladder above are rejected — the decisive evidence for this question does not exist
in a static repository, and Phase 0 as designed would predetermine its own `close` verdict against
zero observed harm at a cost order of magnitude larger than the substitute. Authorised instead: an
n≥2 probe (cost unmeasured, estimate only) targeting `add-warehouse-load` `SKILL.md:160-163` step 8's
**unconditional** partition-function/scheme-reuse clause specifically (not its separate,
partition-switch-only staging-table filegroup/index clause — delta review caught the first draft
misquoting this), pre-registered stopping rule (WSD-037 pattern). Next: execute the substitute probe.

**Done when (superseded by WSD-039 — this is the rejected design's original criteria, retained only
for record):** ~~representative fixtures cover rowstore and columnstore/partitioned designs, harmful
and appropriate configurations, incremental loads and backfills, and absent workload evidence;
recommendations are platform-scoped and evidence-ranked; false-positive controls are demonstrated;
and behavioral evals show the framework can decline an unjustified optimization.~~

**Done when (actual, per WSD-039):** the substitute probe's grader is proven red/green before the
baseline runs; unchanged `add-warehouse-load` behavior is observed n≥2 on the partition-function-reuse
mismatch fixture; if it passes, B-128 closes with no shipped change and the fixture retained as
regression evidence (WSD-037 pattern); if it fails, the one-clause fix to step 8's unconditional
clause is applied and re-verified n≥2.

**Final status (2026-08-13): premise rejected.** The first pass (n=2 pre-fix, both graded FAIL) led to
a one-clause skill fix that was implemented, composed, validated, and committed — but re-verification
also graded FAIL, identically, which turned out to be the tell. Direct inspection of the actual
written DDL (not just the grader's boolean summary) showed the model had been making the *correct*
partition decision, with documented reasoning, in **every one of the four real runs against the
committed scenario prompt — including both "pre-fix" ones.** The grader only recognized one specific
tool-call shape (`AskUserQuestion`) as success and scored a correct, unprompted, evidence-grounded
engineering judgment as failure. Corrected and red/green-tested the grader (a documented in-artifact
deviation now also passes; a case using the same keywords while still applying the mismatched scheme
still fails); rescored all four real transcripts at zero further live cost: **all four PASS.** The
one-clause `add-warehouse-load` fix was reverted — it was never necessary. Full detail, including the
RCA on two independent under-crediting instruments caught only by reading the artifact directly, is
in `meta/workspace-decisions.md` → WSD-039.

---
### B-137 · A push outside `release.ps1` gets no CI check at all — B-88's fix only covers the release commit — **DONE 2026-08-16, see Done section**
**Effort:** S · **Priority:** P2 · filed 2026-08-13 · **Invariants:** #7

**Why:** B-88 wired `.claude/scripts/watch-ci.ps1` into `release.ps1` step 5c, so a *release* commit's
CI run is checked before the tag is allowed. Every other push to `master` — an implementer's landing
commit, a design-lock commit, a small fix commit made between releases, all routine and frequent in
this repo's actual working history (codex-implementer rounds, adversarial-review-lock commits, etc.)
— pushes straight to `origin/master` with **no automatic CI check at all**. The only way to learn it
broke CI is to manually run `gh run list`/`gh run view`, which costs a deliberate, easy-to-skip step
(and real inference effort to remember and execute) rather than being a fact the tooling hands back.

**Caught live, 2026-08-13:** four consecutive pushes to `master` went CI-red and none were noticed
until the maintainer asked directly — B-135's commit (`afabd90`, `context-footprint.json` went stale
and nobody ran `-Update`), a docs-only design-lock commit that inherited the same stale baseline,
and two B-41 commits (one of which had its own, different defect: editing `src/stacks/*/files/CHANGELOG.md`
without rebuilding `dist/`, caught only because the *next* CI run's `git diff --cached --exit-code
-- dist` failed). This is B-88's exact failure mode (`meta/BACKLOG.md`'s own B-88 entry: "four red
runs went unnoticed until asked"), recurring in the one place B-88 didn't reach.

**Do:** after every push to `master` (not just `release.ps1`'s), run the existing, already-tested
`watch-ci.ps1` / `Get-CiPublishDecision` (`.claude/scripts/_ci-decision.ps1`, B-88/WSD-029 — reuse it,
do not write a second CI-status reader) against the pushed commit, and print the 0/1/3 verdict as
part of the command's own output — a deterministic script fact, not something an agent has to
remember to go check and spend a reasoning pass deciding to look for. The cheapest wiring point is
likely a small wrapper (`scripts/push-and-check.ps1`/`.sh`, or a documented one-liner in
`DEVELOPING.md`'s commit recipe) that every non-release push routes through, mirroring step 5c's
poll-until-terminal logic exactly rather than reinventing it. Out of scope: gating the push itself
(this repo's own commit-and-push policy is "never leave changes uncommitted"; the fix is *visibility*
after the fact, not a pre-push block) and building anything that duplicates `watch-ci.ps1`'s polling.

**Proportionality:** B-88 already paid for the hard part (a red-tested, twin-parity CI watcher with a
real 0/1/3 decision table). This is wiring the existing tool into the other call sites that skip it,
not new machinery — small effort, and the harm is already observed twice over (B-88's own history,
and this incident).

### B-139 · `total-local-gates` can silently drift out of sync with the per-stage ceilings it's supposed to bound — **DONE 2026-08-16, see Done section**
**Effort:** S · **Priority:** P2 · filed 2026-08-13 · **Invariants:** #4

**Why:** on 2026-08-08, `meta-suite`'s own ceiling was correctly raised 300s → 650s with a recorded,
justified reason (B-67's genuine new scope) — but `total-local-gates` (the aggregate ceiling every
stage's time is summed against) was never recomputed to match, and has been 1000s since inception.
Once `dist-gates` (700s) and `meta-suite` (650s) both carry ceilings whose sum alone (1350s) already
exceeds the 1000s aggregate, it is mathematically impossible for both stages to legitimately run
anywhere near their own individually-justified ceilings and still pass the aggregate — the gate was
already inconsistent with itself for five days before it was ever triggered. Caught live, 2026-08-13:
two consecutive v0.52.1 release attempts refused on `total-local-gates` while every individual stage
passed its own ceiling comfortably (dist-gates 668.4s/609.4s < 700; meta-suite 554.4s/527.3s < 650).
This is the exact same defect class Maintenance rule 4 already names for behavioural instruments —
an aggregate check that can go stale independently of the components it's supposed to bound, and
nothing notices until someone hits it.

**Do:** add a gate — to the meta suite itself, so it runs on every ordinary change, not only at
release time — that asserts `meta/gate-budget.json`'s `total-local-gates` ceiling is at least the sum
of the current per-stage ceilings (or some explicitly documented, deliberately-chosen margin below
that sum, if the intent is that stages are assumed never to all peak simultaneously — state which
policy is intended and enforce that one). Red-test by planting the exact 2026-08-08 defect class: bump
one per-stage ceiling in a fixture copy of the file without updating the aggregate, and confirm the
new gate fails. This makes the inconsistency a same-commit review-time failure for whoever next
revises a per-stage ceiling, instead of a five-days-later surprise during an unrelated release.

**Proportionality:** small, mechanical, and B-110/B-101's own established pattern (declare a ceiling,
make violating it a hard failure) applied one level up to the ceilings themselves. The alternative —
trusting whoever edits a per-stage ceiling to remember to also update the aggregate — is the exact
discipline that already failed once.

---

### B-145 · Guidance-effect canary — **REJECTED 2026-08-17, do not re-propose without new evidence**
**Effort:** n/a · filed and rejected the same day · design + critique in `.claude/plans/`

Proposed a Copilot-side A/B canary to measure whether framework prose changes model behaviour. It was
rejected on three grounds, each verified:

1. **The repo already forbids it.** `meta/BACKLOG.md:1772` — *"Reuse the B-41 harness; do not build a
   second one."* `run-agent-evals.ps1` already supplies ~6 of the 8 needed capabilities; only the
   executor is Claude-specific.
2. **N=6 per arm cannot detect a moderate effect.** Exact two-sided Fisher: `0/6 vs 4/6 -> p=0.0606`.
   The design would have produced nulls that read as "guidance does not work" but mean "no near-total
   transformation was observed".
3. **Proportionality pointed elsewhere** — B-17 was already rejected without it, and B-66 has a field
   report and can be decided on judgement.

**What would revive it:** a concrete observed hooks-off Copilot failure, then a Copilot **executor
interface inside `run-agent-evals.ps1`** — never a second rig — with the sample size chosen from a
stated minimum effect rather than inherited from B-98.

**Keep this entry.** The idea is attractive and will be re-proposed by anyone who notices that the
framework's central claim is unmeasured on Copilot. It is unmeasured; that is accepted, recorded, and
not worth this instrument at this price.

---
### B-21 · Reviewer-profile systemic fixes — **DONE (shipped v0.28.0, 2026-07-16) — see Done section**
**Effort:** M–L · **P0 design complete 2026-07-06** (WSD-013) · **Invariants:** #1 #3 #4 #5

> **Design LOCKED — do not re-derive.** Full spec (adversarially critiqued, LOCK WITH
> AMENDMENTS, findings folded): **`.claude/plans/2026-07-06-b21-reviewer-profile-design.md`**;
> decision record **WSD-013**. Implement from that doc **post-merge, ≥ v0.28.0**, as single
> `src/core` edits in the merged repo; independent of B-27. Frozen under WSD-012's shipped-work
> freeze until the merge lands.

Consumers are competent engineers with limited AI understanding; the pipeline must make every
AI-architecture call so reviewers only answer plain questions about their own code. The design
found the original framing partly stale (adopt-4a contradiction prompts + bootstrap 3d-bis plain
hazard questions already shipped) and re-scoped to the residual gap — judgment items scatter and
expire silently. Three fixes: **D1** a prioritized "needs a human decision" checklist into the
PR/commit (bootstrap Phase 4 + adopt Phase 8, single-emitter, durable `<!-- DEFAULTED -->`
marker for adopt-4a); **D2** session-start hazard-staleness resurface (real interval math,
ISO-pinned, inside `$body`/`emit_body`); **D3** rendered legend + "merge ≠ verified" line, ladder
tokens kept. The remaining backlog work is the implementation (M–L).
**Implementation checklist addition (2026-07-11, WSD-017):** while editing the report emitters,
sanity-check each report's verbosity against the reviewer profile — output leanness applies only
where it doesn't cost the plain-engineering explanations the profile requires (WSD-013). No
standalone "output leanness" backlog item exists, by decision.

### B-29 · Haiku-tier agent adequacy evidence (P3) — **absorbed by B-41** (strategic section above) as its planted-defect extension
**Area:** both repos' `tests/evals/` · **Effort:** M · **Invariants:** #1 · added 2026-07-05

The v0.8.0 model-routing entry claims the haiku downgrade of `convention-check`, `bloat-radar`,
and `debt-radar` comes "without losing security or bootstrap quality" — that claim has never
been evidenced (no eval covers these agents; evals have never gated a release, B-23). Add eval
cases with planted defects each agent must catch on Haiku: known convention violations for
`convention-check`, over-abstraction patterns for `bloat-radar`, seeded TECH_DEBT references for
`debt-radar`. Mirror to both repos [#1]. If Haiku misses at a meaningful rate, revisit the
tiering (WSD-011) rather than the eval. Cross-links: B-23 (evals as release gate), WSD-011
(token-policy record that filed this gap).

**Amended 2026-07-11 (B-32 design pass, WSD-017):** rising consumer token-cost consciousness
raises this item's value — it is the enabler for safely *extending* the WSD-011 tiering to more
agents (the cheapest cost lever available; extension without evidence would repeat the original
unevidenced claim). Scope addition: decide/verify whether the shipped `.github/agents/*.agent.md`
wrappers should pin GitHub's documented `model:` field — tiering currently reaches Claude Code
only (WSD-011 implementation fact), so the Copilot half of every consumer surface gets no benefit.
A wrong pin is consumer-visible: verify on a live Copilot surface before shipping.

---

### B-95 · `validate-dist` checks 1–4 still carry the vacuity shapes B-92 removed from 6–8 — **DONE 2026-08-08, see Done**
**Effort:** S · **Priority:** P3 · filed 2026-08-04 (B-92's independent review) · **Invariants:** #3

**Why:** B-92 was scoped to checks 6, 7 and 8, and those now guard their inputs, count what they
scanned, and report read errors. The four checks above them were not touched and still have the
shapes B-92 exists to remove — confirmed by reading during the pre-commit review:

- **check 1** (`@stack` markers) swallows read errors in both twins (`-ErrorAction
  SilentlyContinue` / `2>/dev/null || true`), so an unreadable file is indistinguishable from a
  clean one.
- **checks 2, 3 and 4** each print their own `OK:` on **zero** inputs. A dist containing no
  `*.json`, no `*.sh` or no `*.ps1` gets three individual passes saying those files are all valid.
  Other checks would redden the run overall, but each of those specific claims is vacuous.

This is a genuine residual, not a regression: it is the same class, one check group over. It is P3
because a dist with zero JSON/shell/PowerShell files fails checks 5–8 loudly anyway.

**Do:** give checks 1–4 the treatment 6–8 received — count inputs, state the counts on the OK line,
and record read/enumeration errors as findings rather than skipping the file. Decide explicitly
whether zero inputs is legitimate for each (it is not, for any of the three). Red-test each with a
planted unreadable file and an emptied tree, both twins.

**Cross-links:** B-92 (the same class in checks 6–8, fixed), B-59 (the inert-check family), B-64
(planted-defect tests for diagnostics).

---

---

## Archived original entry text

> Moved here 2026-08-17 during the backlog restructure. The heading below carries a historical
> **PARTIALLY DONE** note from v0.40.0 that the v0.55.0 delivery superseded; it is kept verbatim
> rather than edited, because the whole point of this archive is that finished entries are not
> rewritten. The current disposition is the `B-66` record above.

### B-66 · The Angular stack ships no forms guidance at all — **DONE in v0.55.0, see `meta/BACKLOG-DONE.md`**
**Effort:** M · **Priority:** P2

**Why:** case-sensitive grep across `src/stacks/angular/` for `ControlValueAccessor`, `NgControl`,
`FormControl`, `FormGroup`, `FormBuilder`, `Validators`, `ngModel`, `NG_VALUE_ACCESSOR`,
`formControlName`, and `ReactiveFormsModule` returns no matches; likewise `ng-content`,
`ngTemplateOutlet`, `hostDirectives`, `defer`, `viewChild`, `contentChild`, and `toSignal`. Forms are
the largest surface of a line-of-business Angular app. This is the standing defect behind the first
field report the framework has ever received.

**Do:** the immediate transcript-independent piece is a Forms section in the Angular conventions:
reactive over template-driven for new code, typed forms, where validators live, and when a component
becomes a `ControlValueAccessor`. State the `NG_VALUE_ACCESSOR`-provider vs `NgControl`-injection
trade-off honestly rather than naming either an anti-pattern, and name the double-registration hazard
(providing both causes a circular-DI runtime error).

**Not:** do not ship a broad pattern catalogue before the delivery-tier question in B-65 is
answered.

**PARTIALLY DONE — delivery half shipped as v0.40.0 (2026-07-31); the guidance half is deliberately
still open.** What shipped: `/bootstrap` and `/adopt` now author a `Forms` subsection (both stacks,
monorepo siblings included), `/bootstrap`'s A3 pass probes for it, `docs/defaults.md` gained a
**detect-only** `### Forms` section in the `### SSR / Hydration` house style, and the two surfaces
asserting `@Input`/`@Output` **only** (`copilot-instructions.md`, `defaults.md` § Component Design)
were carved out. That closes the delivery-tier problem: the reason the guidance could not reach a
bootstrapped repo was that nothing wrote `Conventions > Forms`, and the `add-component` skill
subordinates itself to `CLAUDE.md > Conventions` at its first line — so routing around the tier was
never going to work.

What did **not** ship, and why: the prescriptive greenfield block (reactive-over-template-driven,
typed forms, the `NG_VALUE_ACCESSOR`-vs-`NgControl` trade-off table, the double-registration hazard)
and an `add-component` form-control branch. The `angular-form-control` baseline **passed with no
forms guidance shipped at all** — the agent self-injected `NgControl`, set `valueAccessor = this`,
used `setDisabledState` rather than an `@Input() disabled`, and commented that this avoids the
circular-DI `forwardRef`. Writing prescriptive guidance whose only instrument is green before the
fix would be shipping on faith. **Resume this half once B-72 re-specifies the probe** so it states
the business need without naming the mechanism, and shows where the model actually fails.

> **UNBLOCKED 2026-08-17 — the gate above was the wrong test, and one of its stated reasons was
> factually wrong.** Two corrections, both verified:
> 1. **The context-budget objection does not apply.** It was raised on the 142-character
>    `static.claude` monorepo headroom. Measured against `meta/context-footprint.json`: a skill's
>    *body* is `ondemand-info`, `docs/defaults.md` is `instructed`, and only a skill's *frontmatter*
>    is `static.claude`. Prescriptive forms guidance placed in a skill body or in `defaults.md` never
>    touches the scarce bucket, and neither of the buckets it does touch has a declared ceiling.
> 2. **"The probe is green, so we cannot demonstrate improvement" is not a reason to withhold
>    guidance a real user asked for.** B-66 rests on **the only field report this framework has ever
>    received** — the strongest evidence class available here, stronger than any probe. Requiring a
>    behavioural instrument to bless it inverts that. The instrument to build it with was itself
>    rejected (see `.claude/plans/2026-08-17-b145-guidance-effect-canary-design.md`): at N=6 per arm
>    it could only detect a near-total transformation, and the repo already forbids a second harness
>    (`meta/BACKLOG.md:1772`).
>
> **Ship it on the field report, and label the claim honestly:** the guidance addresses a reported
> gap; its effect on model behaviour is **unmeasured**, and the entry must say so rather than imply
> a probe endorsed it. B-72 remains open on its own merits — the grader defects it found are real —
> but B-66 no longer waits on it. The
technical content is drafted and reviewed in
`<home>\.claude\plans\let-s-go-ahead-and-sorted-quill.md` (including three precision traps:
qualify circular DI to the *self-referencing* `useExisting` provider; do **not** claim "Angular
warns" about `@Input() disabled` — it collides with `setDisabledState()`, which is a different
thing; signal inputs are read-only so a CVA's *value* cannot be an `input()`).

Scope note: `bootstrap.md`/`adopt.md` were taken deliberately even though B-66 deferred the
delivery-tier question to B-65. B-65 is about restoring the pointer `/bootstrap` *deletes*; this was
about what `/bootstrap` *writes*. Adjacent, not the same.

- **B-17** — **REJECTED on evidence 2026-08-17** (not deferred; WSD-045). Scoped
  `.github/instructions/` delivery for test files rested on a marginal-salience premise that three
  verified facts killed: the broad `applyTo: "**"` carrier already delivers the red-test rule and
  "No tautological assertions" (canary 3 proved `"**"` delivers), so a scoped file adds locality and
  not coverage; "test files" is not expressible as a glob, because xUnit imposes no filename
  convention and `**/*Tests.cs` silently misses `*Test.cs`, `*Spec.cs` and directory-convention
  layouts — a miss being indistinguishable from delivery, since scoped instructions have no
  telemetry; and widening to `**/*.cs` restores coverage while destroying the salience premise in
  the same move. The design and its critique are
  `.claude/plans/2026-08-17-b17-b81-consumer-value-design.md` and
  `.claude/plans/2026-08-17-b17-b81-sol-critique.md`.

  **Why this sat open for a day as a live item:** the rejection was recorded only in a commit
  message and two plan files. `meta/BACKLOG.md` still listed B-17 as work to do, and
  `meta/decisions-index.md` — the file `CLAUDE.md` tells you to read before locking any design — did
  not carry it. That is B-83's class exactly, and it is why the rejection now has a WSD.

- **B-25-EXEC** — DONE **2026-07-12**, shipped as **v0.26.0** (WSD-018). Phases 0–6 of the monorepo
  merge all completed; both legacy repos archived on GitHub with pointer READMEs. The entry stayed
  in the open file for five weeks after its own body recorded `B-25-EXEC DONE`, because the hygiene
  gate reads the *heading* and this entry's heading never carried a completion marker.

- **B-46** — DONE. Part 1 (does update mode clobber consumer edits?) was answered by execution and
  disclosed in **v0.56.0** (WSD-043): it **silently clobbers** every consumer edit to shipped
  machinery, `.claude/settings.json` included, and the update now names three ownership classes and
  backs up settings before refreshing. Part 2 (version awareness) shipped in **v0.57.0**: both
  `session-start` twins emit one honest line at most once per seven days — the installed version
  plus the releases page — with no network request, no assertion that an update exists, and the
  `.claude/.state/last-version-awareness` throttle claimed before emission so an unwritable state
  path stays a quiet soft failure.

- **B-102** — DONE. The shipped `.sh` hooks now resolve a JSON parser by **execution** over
  `jq → python3 → python → py`, so the documented fallback engages on Windows, where
  `python3.exe` does not exist and the Microsoft Store `python.exe` stub resolves by name and then
  fails. The core fix shipped in **v0.45.0**; the three residues its own correction identified — the
  doctor (B-105), `route-prompt.sh`'s silent fail-open (B-104, P1) and the false `python3 is
  unavailable` skip (B-106) — were filed separately and have all since been delivered. Kept as a
  standing lesson: a probe that tests a **name** rather than the **capability** reports health it
  cannot deliver, and a skip that misreports its cause is indistinguishable from coverage.

- **B-141** — DONE **2026-08-18**. `DocTruth.Tests.ps1` was green under pwsh 7 and failed 2 of 8
  under Windows PowerShell 5.1 on an unmodified tree. `-Include *.md` does not filter under 5.1, so
  the phantom-marker scan read every file in the repo and flagged its own source; and
  `meta/BACKLOG.md` is BOM-less UTF-8, so 5.1 decoded it against the system codepage, the non-ASCII
  middle dot in the `### B-nn` heading grammar stopped matching, and the duplicate-id gate yielded
  zero ids. The vacuous-pass guard caught the second one and said so — working exactly as designed —
  but the consequence is that **the duplicate-id gate had never once run under 5.1**, and B-114 (two
  entries claiming one id) is precisely what it exists to catch. Now `-Filter` and an explicit
  `[IO.File]::ReadAllLines(..., UTF8)`, the pattern `template-checks.ps1:31-36` already documented
  for this exact trap three files away. A 5.1 arm was added so the divergence cannot return silently.

  **The arm's first version reported `[ok]` when it had run nothing** — under 5.1 itself, and on a
  host with no `powershell.exe`. It now reports SKIP with the reason in both cases. A leg that
  verified nothing must not be indistinguishable from one that passed; that is B-71's class in its
  stronger form, appearing inside the very change that exists to close a never-ran-there gap.

  Verified by the reviewer, not from the implementer's report: pwsh 7 → 9/0/0 exit 0; 5.1 → 8/0/1
  exit 0; reverting `-Filter` alone → 5.1 red on the phantom-marker case; reverting the UTF-8 read
  alone → 5.1 red on zero-live-ids; each mutation asserted to have applied before running.

- **B-76** — DONE **2026-08-18**. `.claude/hooks/tests/DocClaims.Tests.ps1` (new, meta-only, no twin
  per WSD-005) guards that a shipped doc's description of a command matches that command. It is a
  **literal registry of six claim contracts** plus a **narrow completeness net** that fails on any
  new maintenance-claim-shaped line not yet adjudicated — `DocTruth`'s existing heading-mirror
  pattern (explicit table + assertions that nothing on either side is missing from it). Per row it
  asserts both directions: the claim still exists in the claiming file, and it is true of the
  command. Frontmatter is stripped before the body search, which is what makes the `rebootstrap`
  row test the defect that actually happened — a promise that lived only in the description.

  **The first design was rejected on premise, and the rejection was right.** Rev 1 proposed
  `validate-dist` check 13: three lexical extractors over ~91 Markdown files per dist, in both
  twins. The adversarial pass killed it and every load-bearing finding was re-verified before
  acceptance. Its subject extractor did not parse the real lines — `SECURITY_FINDINGS.md:3` is
  `> Managed by /security-review`, with no quoted subject *preceding* the attribution, so the rule
  skipped the very anchor rev 1 listed as covered; `README.md:141` carries three attributions on one
  line and a per-line single match missed two; and it reaped `CHANGELOG.md` history, which would let
  a dated record of what we once believed block a current command edit — the exact reason
  `DocTruth.Tests.ps1:37` already excludes `CHANGELOG.md` by name. Its description-vs-body shape
  produced findings in **95 of 101 files** under a generous 38-word stoplist: `docs-sync.md`'s
  description ends *"Read-mostly; safe to run anytime"*, a correct usage note whose words appear
  nowhere in the body and should not. **Rev 1 was inferring a subject from arbitrary prose, which is
  NLP wearing a regex costume** — the thing `DocTruth`'s own header already refuses to build.

  Moving it to a meta test also deleted the whole twin-divergence class the critique raised (case
  folding, `\s` semantics, YAML folded scalars — B-59's live class, re-armed).

  Verified: green on both PowerShell hosts, BOM present; all six `-RedTest` arms observed red; the
  completeness grammar matched **none** of six provenance phrases (`Auto-populated by`, `Used by`,
  `Managed by`, `drafted by`, `spawned by`, `Invoked in parallel by`) and yielded 9 live hits, all
  genuine and all registered. Decisively: **all three historical defects were reconstructed in a
  scratch copy of `dist/dotnet` and all three were caught**, with each mutation asserted to have
  applied first and the copy green again after restore.

  **Honest limit, recorded rather than smoothed over:** the completeness net recognises seven verbs.
  A new false claim phrased *"is kept current by `/docs-sync`"* would not be discovered. That is a
  deliberate precision-over-recall trade — the alternative fired on 94% of correct files — but the
  net has a known mesh size and the registry, not the net, is the floor.

- **B-144** — DONE **2026-08-18**. The shipped `set -e` abort itself was fixed in v0.54.0; this
  entry's remaining halves were the sweep and the audit, and both are now discharged **by evidence
  rather than by fixing things**.

  **(a) The sweep found nothing, and that is a result.** All twelve shipped `.sh` files running
  under `set -e` / `set -eu` / `set -euo pipefail` (`install.sh`, `sync-agent-files.sh`,
  `build-architecture-html.sh` × `src/core` + three dists) were reviewed statement by statement for
  a command that is both a bare statement and legitimately non-zero in normal operation. **No REAL
  or LATENT hit.** Every high-value near-miss is already guarded: `install.sh:171` explicitly ends
  the normal-no-match `grep` with `|| true`, `cmp` sits under `if !`, `command -v` sits in `if`
  conditions. Recorded deliberately: blanket-appending `|| true` on this evidence would convert
  real errors into silence, which is the opposite defect. Full file-by-file record in
  `.claude/plans/2026-08-18-b144-sweep.md`.

  **(b) The audit found three suites that assert what landed without asserting that the run
  succeeded** — B-144's generalisable lesson, since `UpdateDelivery` proved *what arrived* and never
  proved *the run exited 0*, and the files did arrive while the run failed. All three are now fixed
  and red-tested:

  | suite | was | now |
  |---|---|---|
  | `MetaHooks.Tests.ps1` | piped nine `Invoke-Hook` results to `Out-Null`, asserting only file bytes | asserts `Exit -eq 0` on each |
  | `RootInstallerWarehouse.Tests.ps1` | asserted the installed `adopt.md` exists | asserts the installer's exit first |
  | `InstallerContract.Tests.ps1` | asserted stdout only across 12 real installs | asserts exit first — this is the suite that *claims* to cover installer behaviour, and an installer that printed the whole contract and then aborted was indistinguishable from a clean run |

  **The red-tests were themselves inert on the first attempt, and that is the part worth keeping.**
  Appending `exit 7` / `exit 3` to the end of `bom-fix.ps1` and `install.ps1` produced GREEN suites
  — which reads exactly like "the new assertion does nothing". It was neither: both scripts end with
  their own terminal `exit` (`bom-fix.ps1:36`, `install.ps1:86`), so the appended line was never
  reached. The file *had* changed, so a change-assertion passed; the **executed behaviour** had not.
  Mutating the real terminal statements instead turned all three red immediately, with the intended
  messages. B-84 already records that a red-test reporting green is ambiguous between an inert check
  and a mutation that never applied — this adds that *asserting the file changed is not enough*; the
  mutated line must be shown to be **on the executed path**.

- **B-146** — DONE **2026-08-18** (filed and resolved the same day). Check B shipped; **check A was
  dropped on evidence**. See the entry's own resolution note, kept in the archive for the lesson:
  the proposed body/heading marker check fired 18 times on ordinary wrapped prose, and even a much
  sharper rule (bold span + version stamp or ISO date — 4/4 recall, zero of the original false
  positives) still fired 12 times on `**STEP 3 DONE**`, `**LARGELY DONE**`, `**OPUS GATE COMPLETE**`
  in genuinely open entries. Separating those from `**DONE — shipped v0.45.0**` is a reading, which
  is precisely what B-83 decided against and what `meta/decisions-index.md` carries as a standing
  constraint. **That index was not read before the design was specified, though `CLAUDE.md` says to
  read it before locking any design** — two rounds were spent building something already forbidden.
  Check B (a commit subject recording a decision for a still-open id) is a genuine string match,
  shipped, and was verified against real history rather than a fixture: replaying the actual log
  against a backlog where B-17 was still open reproduces the exact finding that motivated it.
  Honest coverage note: of the four stale entries found that day, check B would have caught only
  B-17; the other three announced completion in their own bodies, and periodic human triage remains
  the only mechanism for that.
