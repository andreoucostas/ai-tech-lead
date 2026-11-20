# Design: seven backlog items, one coordinated pass (draft 2, after adversarial review, 2026-11-19)

Maintainer ask (chat, 2026-11-19): do B-530, B-516, B-467 with B-497, B-536, B-483, B-535 and B-525;
design each with the end-to-end architecture in view, refactoring allowed; adversarial review; then
an Opus coordinator runs Sonnet or Opus subagents to do the work. Copilot access is promised.

Status: draft 1 was written from four read-only research passes and attacked by three fresh
reviewers (read-only, one with scratch execution). Draft 2 is the result. Section 10 lists what the
review changed. Nothing here has been run except where a line says "executed" or "read".

## 0. Constraints that shape every item

- **WSD-139:** a change ships only for a harm seen in a field report or a failing eval, with a test
  that can see the fix; otherwise record the trigger and close. Each item names its harm and its
  instrument; "measure, then close without shipping" is an accepted outcome.
- **WSD-138:** architecture stays with the main session, coordination and supervision go to an Opus
  agent, implementation to Sonnet agents, and **paid eval runs start from the main session**. The
  coordinator queues a paid run (exact command, worktree, commit, cap) and the main session starts
  it. The maintainer's ask today allows Opus implementers "as needed": Sonnet is the default, Opus
  takes a piece that is design-heavy (named in section 9) or that failed one Sonnet round.
- **Evals must not run from the main checkout while it is dirty.** The runner does not refuse a
  dirty `dist/` (it checks only that the dist version matches the CHANGELOG head), so a run there
  would silently measure another session's uncommitted edits. Every eval runs from a clean worktree
  at a named commit, and the row records that commit.
- **A `-TargetPatch` is left uncommitted,** and `/review` with no scope reviews uncommitted changes.
  Any measurement that runs `/review` on a patched install commits the patch in the fixture first.
- **Another session is editing the main checkout** (the WSD-122 override; 20 files, last write
  21:01 UTC), including the eval runner, the four CHANGELOGs, the footprint baseline and the decision
  log: every file this pass also touches. That work must be committed before anything here can land.
- **No release.** Releases are the maintainer's.
- **Tiers** are read off the changed paths (root `AGENTS.md`). Step 4 (a fresh session attacks the
  diff) applies to the installers, `adoption-archive.ps1`, `guard.ps1`, the retirement and ownership
  policy and root `AGENTS.md`; nothing planned below touches those.

## 1. End-to-end architecture: what the review left standing

Draft 1 proposed three shared pieces. The review removed two and reshaped one.

- **Withdrawn: one shared review-quality instrument.** Its justification was four consumers. B-497's
  remainder closes on arithmetic (section 4), B-530's own cell already reads "reviewers started"
  (section 2), and B-504 does not need it. Only B-467 would use it, and it is new runner work, not
  reuse: the runner can complete a review only inside a go-ahead dialog on Claude Code, approves a
  reviewer's hash command in one literal form, and has no such path on Copilot. It is built only if
  the maintainer rules that B-467 is worth it (section 4).
- **Withdrawn: the wrapper-hop suspicion.** Retained B-425 journals show five of six runs read
  `review.md`, Step 1 included, and skipped dispatch because the diff was small. The hop is taken;
  inlining wrappers at build time has no basis. The candidate is `review.md` Step 1's wording.
- **Kept, redesigned: one real-host check built on a scripted local model endpoint** (section 5).
  The project already proved the method once (B-437, tools since lost): both host programs can be
  pointed at a local endpoint that plays a scripted model, so real hooks fire on real tool calls
  with no key, no access and no cost. That is the deterministic base for B-536 and a reusable base
  for later host questions (B-504's "a reviewer has no edit tool", B-535's CLI half).

Considered and rejected: splitting the 9,700-line eval runner. The pieces that edit it go through
one serial lane (section 9).

## 2. B-530: does a requested review run reviewers on Copilot CLI

**Harm and instrument.** Failing eval (B-425, Copilot CLI 1.0.98): "Review my changes." loaded the
skill 5 of 6 and started a reviewer 0 of 6. Instrument: the plan's own cells.

**Design.** Execute the existing, twice-reviewed plan
(`.claude/plans/2026-11-19-b530-copilot-go-ahead-measurement.md`) as written. No added run sets:
its X-ask-full cell already reads "reviewers started", and its probe P0 is the access probe.
- Now, no access needed: Part A (grader fix, five red-first self-test cases), then B1, B4, B6.
- Record at zero cost, in the same commit as Part A's records: the hop result above, from the six
  retained journals (verify they are still readable; cite them).
- Part C waits for two things: Copilot access, and **the maintainer's answers to the plan's open
  questions 1 to 5** (spend stop and per-run cap; observe-only if `-p` cannot answer the question
  tool; run the completed-review cell now; accept `--allow-all-tools` for the review leg in the
  disposable fixture; pin CLI 1.0.98). The plan recommends: 45 premium requests or 1,800 credits
  with a 500-credit per-run cap; observe-only; now; yes; pin.
- If "reviewers started" fails as B-425 predicts, the next candidate is one sentence in
  `review.md` Step 1 (diff size is not a reason to skip dispatch, beside the existing sentence
  about missing parallel capability), measured in the same cell with the patch committed in the
  fixture. It is its own backlog entry and commit, as the plan says.

## 3. B-516: approving a draft project skill in one action

**What exists.** `/bootstrap` phase 3a-bis drafts `.claude/skills/<slug>/SKILL.md` (description
starting `DRAFT, pending PR review:`, `origin: discovered`, an `## After review` paragraph naming
the Common Tasks line to add and the draft wording to delete). Approval is those two edits;
`/bootstrap`'s report already asks yes or no per discovered skill.

**Harm and instrument.** No field report. The maintainer ranked it first (WSD-124) and asked for it
in chat: a direction, not an observed harm, so the design measures before it ships anything.
Hypothesis: asked "Approve the add-report-export skill." in a fresh session, today's agent already
makes both edits, because the draft says what approval is.

**Design.**
1. New scenario `skill-approve` on the `b514-orders` fixture, as shipped, n=3 on Claude Code and
   n=3 on Copilot CLI. **Semantic oracle** (not byte equality with `approved.patch`, which also
   keeps a draft H1 the paragraph does not list and adds both skills' lines): the named Common
   Tasks line appears exactly once under Common Tasks; the three pieces of draft wording the
   paragraph names are gone; `origin: discovered` is still present; every other file is
   byte-identical, the second draft included.
2. Runner work this needs, each with a red-first self-test: a permission allow class for Edit and
   Write under `.claude/skills/<slug>/` and on `AGENTS.md` only (today the permission channel
   grants the question tool and review-bundle reads, nothing else, and only in dialog mode); first
   try whether an allow rule passed on the command line is enough. The row records whether Claude
   Code asked for or refused the write. (Recorded fact is narrow: a headless `/bootstrap` in
   acceptEdits had a write under `.claude/skills/` denied; no interactive prompt was observed.)
3. **Reading, per host:** passes on a host at 3 of 3, or 2 of 3 with the miss explained by hand.
   **Both hosts pass:** the one action exists. Ship nothing. Record the result and record "drafts
   stay live" (maintainer, 2026-11-15, today only a backlog line) as a decision that amends WSD-109;
   the shipped sentence "do not advertise or activate it as an approved Common Task before review"
   stays as it is. Close B-516.
4. **A host fails:** candidate T: 3a-bis says the `## After review` paragraph tells the agent that
   a request to approve the skill means making these two edits (three `bootstrap.md` copies,
   guarded text-only; `DocClaims.Tests.ps1` pins the phrases and changes with it). T on a
   hand-patched fixture is a proxy for what `/bootstrap` would generate, and the plan says so; one
   `/bootstrap` generation leg (about 1.15 USD) is required before T ships.
5. Rejected for now: a deterministic `approve-skill.ps1` (the paragraph is free prose; a script
   needs a machine-readable field first). For the maintainer to overrule: deleting the approval
   ceremony, since B-514 showed a draft is used as often as an approved skill.

## 4. B-497 and B-467: a cheaper `/review`

**B-497 remainder (merge the three Haiku reviewers): close on arithmetic, no run.** Executed
2026-11-19 on a retained full-review stream (`b416-dialog-asked-full`, final `modelUsage`): all
Haiku usage cost 0.042 USD of 1.305 USD, 3.2%; against a review-only pass of about 0.6 USD the
three Haiku reviewers are about 7%. A merge can save only part of that, so no measurement could
reach a saving worth a guarded change that retires five agent files and six wrappers and touches
about twenty files that name the reviewers. Close with that number under WSD-139; reopen if a host
starts charging per sub-agent start. The de-duplication half is already shipped in `/review`
Step 4. **Needs the maintainer's word to close.**

**B-467 (reviewers carry the instruction chain): held for a maintainer ruling.** What is known:
on Claude Code the chain adds about 9,200 tokens to each reviewer's first request; the three
Sonnet reviewers are where the money is, so the saving is roughly 0.1 USD per review, on a review
that since WSD-131 runs only when the developer asks. R1 (the cut) held; R2 (findings not worse)
had one valid run per arm. The instrument is lost and cannot be rebuilt as it was (the subject
files and frozen patterns are gone; seven of the twelve defects were natural findings), so
finishing R2 means new runner work (a review that completes outside a dialog, with the reviewer
permission problem that invalidated runs last time), a calibration run and about 10 to 12 USD.
Under WSD-139 a measured cost is not a field report or a failing eval. Recommendation: close with a
reopen trigger (a field report that review cost matters on Claude Code, or reviews becoming
default-on), and note in B-504 the fact already in the journals: on Copilot the four wrappers that
set `include-custom-instructions: true` run on about 26,200 tokens against about 7,300 for the two
that do not. If the maintainer rules to finish it, it is the last unit of lane H and gets its own
pre-registration. The branch `b467-candidate` is left alone either way.

## 5. B-536: a check of the real host programs before a release

**Harm and instrument.** Two defects reached a tag because a host behaved differently from what the
tests assumed: 9e8dbb28 (after the agent changed directory inside a running Claude Code session no
framework hook ran, because Claude Code starts a hook in the session's current directory and
ignores `cwd`) and 7db19ed4 (brownfield agents left the install uncommitted). `Guard.Tests` already
pins the command-level half of the first; what nothing checks is the real host. The instrument must
go red on the pre-9e8dbb28 registration, deterministically.

**Design: `.claude/scripts/host-smoke.ps1`** (guarded path) plus a scripted model endpoint.
- **The endpoint** (PowerShell, in the repo beside the script): a local listener that plays a fixed
  script, one tool call per turn then text, in the two wire shapes the hosts speak (chat
  completions for Copilot CLI over its bring-your-own-key and offline settings, as B-437 recorded;
  the Anthropic messages shape for Claude Code through its base-URL setting). The Claude Code side
  is new: B-437 only pointed it at a closed port. First step: prove each host completes one scripted
  tool call against the endpoint with zero cost recorded; if Claude Code cannot be driven this way,
  stop and report rather than fall back to a paid model.
- **The script** installs `dist/dotnet` into a scratch repository with the shipped installer, then
  per host program found on PATH plays: change directory into a subfolder, write a harmless file,
  write a file holding a planted key-shaped string. Pass = the harmless write lands with its audit
  line and the planted write is refused by the guard. It also reads what is free: the commands and
  skills each host lists (`copilot skill list --json`; Claude Code's init event), and Copilot's
  loaded-hook count, expected as the entries of `hooks.json` plus those of `.claude/settings.json`
  (12 on a dotnet install, read in the record), not `hooks.json` alone.
- **Evidence** comes from traces that already exist (the session-start state file, the guard's
  audit line, each host's hook events), not from a shim on PATH, which would stand in for the
  interpreter the defect was about.
- Known host facts the script must not read as failures: Claude Code started *in* a subfolder loads
  no project hooks (so every Claude leg starts at the root and moves); a prompt refused by a hook
  cancels the hooks behind it.
- **Exits:** 0 pass; 1 a host misbehaved (the leg is named); 2 could not examine (host absent,
  endpoint could not be reached, host refused the offline mode), matching the existing convention.
- **Tests (guarded steps 2 and 3):** a test file for the script's own classification with fake host
  programs, as `RepositoryPrivacy.Tests.ps1` does for the canaries, red first. **Red-first for the
  live leg:** rewrite the scratch install's hook commands to the pre-9e8dbb28 form; the
  moved-directory leg must fail on Claude Code. That meets B-521's reopen bar for host mechanics
  ("a live check that catches a known escape CI misses") and is recorded so.
- **What it does not cover, stated in the script header:** agent behaviour (7db19ed4's class).
- **Getting it run.** v1 adds one line to `DEVELOPING.md`'s per-release recipe. A recipe line alone
  is the mechanism B-525 shows being skipped, so the design names the follow-up for the maintainer:
  a printed, non-blocking result line in `release.ps1` (guarded; not a gate under WSD-016 or
  WSD-125). Not done in this pass without the maintainer's word.
- The four B-97 canaries stay: they test whether an import reaches the model, which no free leg
  answers, and `host-certification.md` cites them.

## 6. B-483: the warehouse map check reports "current" when it is not

**Harm and instrument.** Reproduced false green in `src/core/scripts/warehouse-map-check.ps1`
(ordinary by path; ships in all three dists): it compares file write times only. A deleted or
renamed table reads `current`; a row appended to an unstamped stale map turns it `current`; a fresh
clone of an unchanged commit reads `stale`. The source is a fresh-session review's scratch
reproduction, not a field report or eval: it stands under WSD-124 (a guarded false green that
ordinary use triggers) and the maintainer asked for it after WSD-139; the commit body says so.
Instrument: `WarehouseMapCheck.Tests.ps1`.

**Design: content decides, time decides nothing.**
- **Artifact set.** In a Git work tree the check takes the files Git knows or would add (tracked,
  plus untracked and not ignored), filtered by today's name rules. Executed in review: today's walk
  ignores `.gitignore`, so a dbt `target/` or `dbt_packages/` folder counts as warehouse artifacts
  and would make every teammate's clone disagree. Outside a Git work tree it keeps today's walk.
- **Digest.** SHA-256 over the ordinally sorted list (`[StringComparer]::Ordinal`; the default sort
  is culture-aware, executed) of forward-slash relative path and content id. In a Git work tree the
  content id is Git's blob id for the working file (`git hash-object`), which applies the
  repository's line-ending and encoding rules exactly, so two clones of one commit agree. Outside
  Git it is a hash of the bytes. An unreadable or locked artifact is exit 2, never `stale`.
- **The digest is printed only on request** (`-Digest`). Verdict lines never carry it: a scoped
  pass or a load step that saw it could copy it into the stamp and certify what it never read (the
  stale-map grader already scores a re-stamped full-pass line as a wrong edit).
- **Stamp:** `<!-- warehouse-map full pass: <UTC time> digest=<16 hex> -->`. The time stays for
  readers; the check ignores it. A full pass asks for the digest at its start and writes that value
  at its end; if a long pass has lost it, it asks again and says so in Coverage.
- **Verdicts:** `full pass: none` → stale (unchanged). Stamp digest equals the computed one →
  `current`. Differs → `stale (warehouse artifacts changed since the full pass)`. No digest in the
  stamp, or no stamp → `stale (no content stamp; a full pass records one)`. Exit codes unchanged;
  nothing parses past the verdict keyword (read: `docs-sync-check.ps1` uses the exit code).
- **Tests, each seen red first:** deleted artifact; renamed artifact; row appended to an unstamped
  map; write times touched with content unchanged (stays current); a second clone with the other
  line-ending setting (same digest); an ignored generated folder (does not change the digest);
  ordinal order; locked file exits 2; no digest without `-Digest`. Existing case 6's "unstamped map
  reads current" flips; case 3 loses its sleeps.
- **Migration is a behaviour change, and the maintainer chooses.** Every existing map reads `stale`
  once, until its next full pass, and `stale` is not advisory: `add-warehouse-load` step 1 and
  Rule 11 then run a scoped pass on the objects the task touches, and after the WSD-122 override
  that pass rewrites contradicted rows unasked. Option A (recommended, built by default): honest
  `stale`, said plainly in the four CHANGELOG entries. Option B: a time-only stamp keeps today's
  time rule until its next full pass, which keeps the false green for every existing map.
- **Skill text** (guarded, `src/stacks/dotnet/files/.claude/skills/**`): `map-warehouse` step 9's
  "judges freshness from it" and `add-warehouse-load` l.188's reason both become false and are
  reworded; the scoped pass's "leave the full-pass line as it is" stays true. Eval fixtures are
  left alone (their stamps must keep reading stale, and a self-test pins the stamp's shape).
- **Rejected:** a `-Stamp` switch that writes the line (the script becomes a writer of a consumer
  file); a per-file manifest so `stale` can name what changed (a second file; e003c8c8).
- **Known limit, unchanged by this fix:** in an active warehouse `current` is rare, because any SQL
  write after a full pass makes the map stale. Today's time rule has the same property.

**Sequencing.** Script and tests can be built at once. The skill text lands only after the parked
WSD-122 work is on `master`: it edits the same paragraphs.

## 7. B-535: does VS Code's default Copilot mode list the framework's commands

Measurement only; nothing ships. The existing VS Code rows came from four methods, and only one, a
session the maintainer typed in the Chat view, shows what VS Code's own picker lists; the others
show what the bundled runtime loads. So this needs the maintainer's hands. The coordinator
prepares a three-step check (open a framework-installed scratch repository in VS Code; in the Chat
view, in the mode a new user lands in, named exactly; type `/` and list what appears) and says
which answer means what: commands present from `.agents/skills` → one `host-certification.md` row,
close; commands missing → a backlog entry for the defect; commands also read from
`.claude/commands` → the entry's wrapper-shrink question stays open, filed as its own line.
The record's CLI rows say the CLI lists `.agents/skills` *in place of* `.claude/commands`, which
the backlog entry states the other way round; the row corrects it.

## 8. B-525: one pass of the model-change check on Fable 5.2

`DEVELOPING.md`'s model-change lines, once, with `-Model fable` in place of the recipe's Sonnet
and Opus: `route-fix,warehouse-bind-sql` framework arm, then `-Arm none`, then
`angular-feature-placement` (the recipe names Opus for it; the substitution is stated in the row
header). `-Trials 2` so "framework 0 of 2" can be read. Run from a clean worktree at a named
commit before any lane change is integrated; the rows record it.
- The first row's `initModel` must show Fable 5.2 (installed Claude Code is 2.1.312); if the alias
  resolves elsewhere, stop and pass the explicit id.
- Each scenario passes its own `--max-budget-usd` (1.25 or 1.50). A run that ends on that cap is an
  error, not a score: on the first such row, stop and report; do not raise a budget silently.
- Cap 15 USD for the pass (ten runs at their caps are about 14). The runner has no total cap, so
  the main session runs one scenario set at a time and adds up after each. The single `-Trials 6`
  rerun an alarm calls for is asked for separately (up to 9 USD).
- Rows go to `meta/eval-results.md`; a backlog line only if the rerun repeats an alarm. Ordinary.

## 9. Execution plan

**Roles.** Main session (Fable): architecture decisions, every paid run. Coordinator (Opus session,
own worktree and branch): sequencing, supervision, integration, gates, records, reports. Workers:
subagents, each in its own worktree, Sonnet by default.

**Lanes** (serial inside a lane; lanes in parallel):
- **H, eval runner and scenarios, one worker at a time:** H1 B-530 Part A → H2 B-530 B1, B4, B6 →
  H3 `skill-approve` with its allow class. Grader logic has a history of defects here: Opus.
- **M, map check:** script and tests now (Opus: guarded batch, Git edge cases); skill text and
  CHANGELOG entries after the parked work lands (Sonnet).
- **S, host smoke:** the endpoint proof first, then the script and its tests (Opus: new protocol code).
- **Records, no lane:** B-497's close-out line with its arithmetic; the hop result in B-530's entry;
  B-535's three-step check for the maintainer. Sonnet.
- **Paid runs, queued to the main session in this order:** B-525 (needs nothing) → B-516 baseline
  after H3 → B-530 P0 and Part C after H2, access and the maintainer's answers.
- **Review of every guarded diff:** a fresh subagent that did not write it, one round, a second on
  the fix. If a change ever reaches step 4, the coordinator stops and asks the main session to start
  a fresh session for the attack.
- Workers in worktrees run PowerShell through the PowerShell tool with absolute paths.

**Integration and landing.** The coordinator integrates lane branches serially on its own branch.
`dist/` and the footprint baseline are rebuilt, never hand-merged (a baseline change is reviewed
before it is updated); CHANGELOG and record conflicts are merged by hand. The repository lands
worktree work by merging `master` into the work branch and then having `master` take it by a
fast-forward merge run in the main checkout, followed by `.claude/scripts/push-and-check.ps1`
there. That cannot happen while the main checkout is dirty with overlapping files, and it is
dirty now. So: the other session commits first; the coordinator merges that result, rebuilds,
re-runs the gates for what it touched, and lands unit by unit. Until then finished units wait on
the branch, each as one commit whose subject starts with its tier, and the maintainer is told.

**Spend caps (stop and report at each).** Claude: 21 USD in total (B-525 15, B-516 5 plus 1.15 for
the generation leg if T is needed; B-536 0). Copilot: the B-530 plan's stop, once the maintainer
confirms it, plus 100 credits for B-516's Copilot leg.

**Needs the maintainer.** Copilot access; answers to the B-530 plan's questions 1 to 5; close
B-497's remainder on the arithmetic; the B-467 ruling; the map-check migration option; the other
session's uncommitted work committed; hands on VS Code for B-535; whether `release.ps1` prints the
host-smoke line.

## 10. What the adversarial review changed

Three fresh reviewers, read-only; one executed scratch attacks on the map check's file walk.
- **Paid runs** moved from the coordinator to the main session (WSD-138, raised by all three).
- **B-497:** a planned 8 USD measurement replaced by a close on arithmetic (Haiku is 3.2% of a
  review run's cost; re-read by the main session from the retained stream).
- **B-467:** the shared instrument withdrawn; the item held for a ruling, with the real size of the
  saving and of the rebuild stated.
- **B-530:** the hop hypothesis refuted from retained journals and dropped; the extra run set and
  extra probe dropped; the plan's unanswered maintainer questions made a prerequisite.
- **B-536:** the paid one-prompt leg (which could not go red reliably) replaced by the scripted
  endpoint; the PATH shim dropped; the hook-count expectation corrected from 6 to 12; exit 3
  changed to the existing exit 2; a test file for the script added; canary deletion dropped.
- **B-483:** ignored and generated files excluded through Git (executed: today's walk counts a dbt
  `target/` folder); Git blob ids in place of hand-rolled line-ending folding; the digest moved
  off verdict lines; "stale is advisory only" corrected and turned into a maintainer choice;
  fixtures left alone.
- **B-516:** byte-equality oracle replaced by a semantic one; the missing permission class made
  explicit runner work; the consumer-doc sentence dropped (no instrument); T labelled a proxy.
- **B-525:** runs moved to a clean worktree at a named commit; per-run budget failure mode and the
  rerun's cost stated.
- **Landing:** rewritten to the route the repository actually uses, with the dependency on the
  other session's commit stated.
- **Not verified by anyone:** whether Claude Code completes a scripted tool call against a local
  endpoint; whether `copilot skill list` works from a subfolder; whether a command-line allow rule
  lifts Claude Code's refusal to write under `.claude/skills/`; Fable 5.2's cost per run.
