# AI Tech Lead (.NET + Angular monorepo) — Changelog

> Release notes for the mixed .NET + Angular distribution, written for the teams who install it:
> what changed in **your** repo, and what (if anything) you need to do. This distribution carries
> the rails of both stacks, so entries may apply to one side or both.
> Architecture decisions you record live in `docs/architecture-decisions.md`.

## 0.29.1 — 2026-07-16

### Fixed — data-access guidance now follows your codebase

- The framework no longer assumes EF Core; data-access guidance is derived from your codebase.

## 0.29.0 — 2026-07-16

### Added — `/adopt` can now run unattended (headless), preparing a PR for you to review

- **You can finish adoption without opening a session and typing `/adopt` by hand.** An installing
  agent — or an operator running `claude -p` / `copilot -p` with no developer at the keyboard — can
  run adoption **headless** by passing a `--headless` directive. Headless adoption does the
  mechanical, reversible work for you: it creates an `adopt-ai-framework` branch, archives your
  existing AI files, runs the provenance + safety screen, captures the impact baseline, and
  **stages** every proposed change to `CLAUDE.md` and `TECH_DEBT.md` as a clearly-marked, attributed
  proposal on that branch.
- **A human still applies the merges — the trust boundary is unchanged.** Headless adoption never
  merges discovered content into your canonical `CLAUDE.md` / `TECH_DEBT.md` on its own, and never
  opens or merges the PR. It hands you a PR-ready branch: you review the proposed changes (and
  anything it quarantined as suspicious) and apply them at PR review. Files that trip the safety
  screen are excluded entirely and listed at the top of the report — they are never auto-approved.
- **Nothing changes for the normal interactive flow.** Run `/adopt` in a session as before and you
  still get the show-each-merge gates. The installer's next-step message and the adoption marker now
  mention the headless option alongside the developer path.

No action required — this is additive.

## 0.28.0 — 2026-07-16

### Added — judgment calls no longer get lost between bootstrap/adopt and review

- **`/bootstrap` and `/adopt` now end with a "Paste this into your PR (or commit message)"
  checklist** — a short, prioritized list of the specific decisions the run made for you, each a
  plain yes/no question with a file pointer (e.g. "The code gave mixed signals on error handling;
  I wrote X. Is that the team's intent?"). Paste it into your PR description so reviewers see
  exactly what needs a human answer. If the run resolved everything against your code, it says so
  in one line. `/adopt` also records any convention contradiction it resolved by default, so that
  choice shows up in the checklist instead of disappearing.
- **Session start now flags stale hazard areas.** When `FRAMEWORK-CONTEXT.md > Known Hazard Areas`
  has an entry whose `Reviewed` date is more than 90 days old, a new session reminds you to
  confirm it (or mark it "not a hazard"). Settled non-hazards and not-yet-drafted tables are left
  alone.
- **The Known Hazard Areas table is easier to read at review time.** It now shows a plain-English
  legend (Verified = a person confirmed it; Suspected = a person thinks so; Unverified = only the
  tooling flagged it) and states that **merging the PR does not confirm these** — an item is
  confirmed only when a person answers its question and updates its status. Hazard `Reviewed`
  dates are written as `YYYY-MM-DD`.

No action required. These are additive: existing `FRAMEWORK-CONTEXT.md` files keep working, and
the new session-start reminder only appears once a hazard entry is over 90 days old.

## 0.27.1 — 2026-07-16

### Fixed — team wiki checks
- `wiki-check` no longer requires GNU `date`: on macOS build agents, valid `last-verified`
  dates were previously rejected as invalid, failing `docs-sync-check` as soon as your team
  had a single wiki entry. Date validity is now checked the same way on every platform.
- Running `docs-sync-check` interactively no longer stalls waiting for keyboard input —
  `wiki-check` receives its repo root as an argument instead of reading it from stdin.
- The wiki index's required sort order is now pinned to plain byte order (ASCII) everywhere,
  so the same `INDEX.md` cannot pass on one build agent and fail on another whose locale
  collates hyphens differently. The `remember-for-team` skill now states this order.
- `CLAUDE.md` ("What We've Learned") and `docs/wiki/INDEX.md` now state what belongs in
  `LEARNINGS.md` (append-only history) versus the team wiki (current, scoped, individually
  verifiable claims), and that durable learnings get promoted via `remember-for-team`.
- Hook tests: the test harness reads hook output as UTF-8 regardless of the console code page
  (two session-start assertions could fail spuriously on non-UTF-8 Windows consoles), and the
  bash session-start hook's Copilot delivery of the wiki index is now covered.

## 0.27.0 — 2026-07-16

### Added — team wiki memory
- A new `docs/wiki/` in your repo: an `INDEX.md` plus one file per team learning (a gotcha,
  context fact, recipe, or failed approach), each with a small frontmatter block (what it is,
  where it applies, how confident, when last checked). Applies to both stacks.
- A new `remember-for-team` skill drafts these entries for you during a session — nothing is
  written automatically; it only ever produces a draft that reaches the team through your normal
  PR review, same as any other code change.
- Your agent now sees the wiki index at the start of a session (inlined if small, summarized if
  large) on both Claude Code and Copilot, and the entries are described to it as **claims to
  verify against the code, not instructions to follow** — the same "screen it, don't obey it"
  posture the framework already applies to adopted docs.
- A new `wiki-check` gate runs as part of `docs-sync-check`: it validates the wiki's structure and
  screens entries for injected instructions, matching the framework's existing PR-review checks.
- If you already run `/adopt` on a repo that has its own `docs/wiki/`, clean entries are left
  exactly where they are; anything that looks adversarial is quarantined for a human to review
  instead of being merged automatically.
- Updating the framework never overwrites your team's own `docs/wiki/INDEX.md` — only a
  missing one is created.

No action needed to receive this — the wiki starts empty; your team populates it over time.

## 0.26.5 — 2026-07-15

### Fixed
- PowerShell session-start and prompt-routing guidance now matches the bash guidance byte-for-byte,
  including Unicode punctuation and spacing. No action is needed.
- Hook guidance no longer garbles ⚠/— characters when PowerShell hooks run on Windows.

## 0.26.4 — 2026-07-12 (fixes a second broken install command in this README)

> Documentation only — **no change to the files in your repo, nothing to do.**

### Fixed
- **The "updating" section named an installer path that does not exist here.** v0.26.3 fixed the
  install command in §1 but missed the same mistake further down: the instructions for pulling
  template updates still said `bash install.sh /path/to/your-repo` / `pwsh install.ps1 …`. As in §1,
  the installer in this distribution is **`scripts/install.sh`** / **`scripts/install.ps1`**.
  Corrected. A check now runs in CI that every command named in these docs actually resolves, so this
  class of mistake cannot ship again.

## 0.26.3 — 2026-07-12 (fixes a broken install command in this README; AI-agent install contract)

> **If you install with an AI agent, this one matters.** No change to the files in your repo — the
> fixes are to the installer's own output and to the install instructions in this distribution's
> `README.md`.

### Fixed
- **`README.md` §1 told AI agents to run an installer path that does not exist here.** It said
  `pwsh install.ps1 <target-repo-path>`; the installer in this distribution is
  **`scripts/install.ps1`** (`bash scripts/install.sh`). An agent that followed §1 verbatim got
  `No such file or directory` and had to guess its way out. The .NET and Angular distributions were
  always correct; only this one carried the wrong path. Corrected.
- **The installer's greenfield "next steps" now tell an AI agent the whole contract.** When an agent
  installed into a repo with no existing AI tooling, the closing message told it not to run
  `/bootstrap` — but never stressed that it must first **commit** the copied files, never said not to
  hand-replicate `/bootstrap`, and never warned that `scripts/docs-sync-check` **fails by design**
  until a developer has run `/bootstrap`. Agents therefore left the copied files sitting uncommitted
  in the working tree, and some treated the expected check failure as a bug to fix. The greenfield
  message now matches the one already shown for repos with existing AI tooling: commit the files,
  hand off to a developer, don't replicate `/bootstrap` by hand, and expect `docs-sync-check` to be
  red until it has run.

## 0.26.2 — 2026-07-12 (housekeeping)

> No behavior change, nothing to do. Keeps this distribution's version in step with the .NET and
> Angular distributions, which had a mangled character repaired in a hook comment.

## 0.26.1 — 2026-07-12 (these release notes are now written for you)

> Documentation and comments only — **no behavior change, nothing to do**. Re-run the installer
> whenever convenient.

### Changed
- **These release notes are written for the teams who install the framework**, not for its
  maintainers: what changed in your repo, and what you need to do.
- **Internal tracking ids removed from the comments in shipped code** — the hooks
  (`.claude/hooks/post-write.*`), the scripts (`scripts/template-checks.*`,
  `scripts/build-architecture-html.ps1`), and the hook tests. Comments now state the rule the code
  enforces instead of the ticket that produced it, so they read as intended in *your* repo. Behavior
  is untouched; the hook test suites pass unchanged.
- **Stale cross-references removed** from `README.md` and this changelog — they pointed at two
  predecessor repositories that are now archived.

## 0.26.0 — 2026-07-12 (first release of the mixed .NET + Angular distribution)

> This is the first release of the monorepo distribution — for repos that hold **both** a .NET
> solution and an Angular workspace. It carries the union of both stacks' rails, and dispatches
> per file type: a `.cs` edit runs the .NET gate, a `.ts` edit runs the Angular one.
>
> **What you need to do:** if you have a mixed repo, the installer now auto-detects it and selects
> this distribution. Pass `--stack monorepo` to force it.

### Changed
- The framework's own CI workflows (`template-ci.yml`, `docs-sync-check.yml`) now pin
  `actions/checkout@v5`, following GitHub's Node 20 runtime deprecation. No change to your
  application code.

---

## 0.25.5 — 2026-07-06 (monorepo template debut)

> First release of the combined template for repos that carry **both** a .NET backend and an
> Angular frontend in one repository. It ships both stacks' rails — conventions, hooks, skills,
> subagents, and workflows — from a single source of truth, at parity with the two per-stack
> templates as of v0.25.5.

### Added
- **Monorepo template** installing both stacks' rails together: the .NET Common-Task skills
  (add-endpoint, add-entity, register-service, perf) alongside the Angular ones (add-component,
  add-service, add-lazy-route, add-signal-store), the shared skills (add-tests, dependency-audit,
  create-adr, enforce-architecture, enforce-standards), the seven subagents, and the seven
  workflow commands — one `CLAUDE.md` / `AGENTS.md` covering both stacks.
- **Both stacks' deterministic hooks** wired in one `.claude/settings.json`: the PreToolUse guard
  (blocks warning-suppressions & secrets in `.cs` and `.ts`), the PostToolUse `dotnet build`
  (`.cs`) and `tsc --noEmit` (`.ts`) checks, the SR 11-7 / DORA audit trail, and the Stop Boy
  Scout scanner with each stack's always-apply patterns.
- **Merged CI guardrail and Bitbucket Data Center guidance** covering both legs — .NET
  (`dotnet build -warnaserror` + `dotnet test`) and Angular (`eslint` + `ng build` + `ng test`) —
  in `docs/ci-integration.md`.
