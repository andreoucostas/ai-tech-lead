# Spec: the consumer documentation and touchpoints as a product (2026-10-15)

> **Status 2026-10-15.** Written at the maintainer's request after 0.96.1 condensed the READMEs without redesigning them.
> This page says what good looks like, audits what ships against it, and names the eval that decides whether the rework
> helped (pre-registered in `meta/eval-results.md`). Paths are source paths; each ships under `dist/<stack>/`.

## 1. Audiences, their jobs, their journeys

| Audience | Job to be done | Journey and the touchpoints it crosses |
|---|---|---|
| **Installing AI agent** (a developer pastes the GitHub URL and says "install this into my repo") | Follow a runbook with no judgment calls: newest release, right stack, commit, hand off, stop. | Root `README.md` (fetched or cloned) → clone at the newest tag outside the repo → root `install.ps1` → the installer's printed output → commit → its closing message to the developer. |
| **Developer, day one** | Know what changed in the repository and what to type. | The commit the agent made → the hand-off sentence → a session in the repo, where the SessionStart reminder names `/bootstrap` or `/adopt` → `/bootstrap`'s closing summary → the first task in plain words → plan, go-ahead, verified change → `/review` → pull request. Reference when stuck: `docs/getting-started.md`. |
| **Tech lead deciding whether to adopt** | Why, at what cost, and exactly what is and is not guaranteed. | GitHub landing page (root `README.md`) → `docs/playbook.md` (why and how, costs, limits) → `docs/enforcement-surfaces.md` (the matrix) → the presentation deck in the framework checkout → a pilot. |
| **Whoever maintains `AGENTS.md` and upgrades** | Keep the conventions true; move to a new release without losing their edits; remove it if needed. | The new release's `CHANGELOG.md` → `docs/upgrade-checklist.md` → the installer's update output → `docs-sync-check` → commit. Reference: `docs/reference.md` (files, ownership, commands, hooks). |

## 2. Rules every document and touchpoint follows

1. **One job per document**, stated in its first two lines with its reader. A second job moves to the document that owns it.
2. **Agent-facing steps are a runbook:** numbered, imperative, one command per step, an explicit stop. The same hand-off
   sentence, word for word, in the root README, the installer output and the SessionStart reminder.
3. **Caveats move, they are not deleted.** Version-dated host observations live in `docs/enforcement-surfaces.md`; the
   README and the tutorial carry one line and a link.
4. **Nothing a consumer reads names maintainer machinery** (backlog ids, decisions, eval names). The consumer CHANGELOG
   says what changed in *your* repository and what you must do, action first.
5. **The installed doc set is the developer's;** the root and stack READMEs stay in the framework checkout and must not
   be the only place a developer can learn what to type.

## 3. Target doc set

| Kind | Document (installed unless noted) | Reader | Its one job |
|---|---|---|---|
| Landing + runbook | root `README.md` (not installed) | installing agent, tech lead | What it is in one paragraph, what is guaranteed and what it costs in five lines, the install runbook with the verbatim hand-off, links. |
| Landing | `dist/<stack>/README.md` (not installed) | tech lead browsing a distribution | What this distribution adds for its stack, and a map of its docs. |
| **Tutorial** | `docs/getting-started.md` (new, framework-owned) | developer, day one | From "it was just installed" to a first reviewed fix: `/bootstrap` or `/adopt`, reviewing `AGENTS.md`, a first task, the plan gate, `/review`. |
| Task guide | `docs/upgrade-checklist.md` | maintainer | Upgrade to a newer release, and remove the framework. |
| Task guide | `docs/ci-integration.md` | tech lead, build owner | Wire the required build on Bitbucket Data Center (Bamboo, Jenkins). |
| Task guide | `docs/REVIEW-GUIDE.md` | developer, reviewer | Review a change or a pull request with the framework, and read the verdict. |
| **Reference** | `docs/reference.md` (new, framework-owned) | everyone | Commands, reviewers, skills, hooks, scripts, files and their ownership, the version stamp. |
| Reference | `docs/enforcement-surfaces.md` | tech lead, maintainer | What each client and host enforces, with dated evidence. |
| Reference (agent) | `docs/defaults.md` | the agent | Conventions before `/bootstrap`. Unchanged. |
| **Explanation** | `docs/playbook.md` | tech lead | Why it exists, how the pieces work together, what is guaranteed, what it costs, its limits, how to check the claims. |
| Consumer content | `docs/ARCHITECTURE.md` (protected), `docs/architecture-decisions.md`, `docs/wiki/` | the team | Theirs. `ARCHITECTURE.md` stops carrying a framework map that froze at install. |

## 4. Touchpoints other than documents

| Touchpoint | What good looks like |
|---|---|
| Installer output (`src/core/scripts/install.ps1`) | Mode, what moved, then **Next steps** numbered: commit; the verbatim hand-off; `docs/getting-started.md`. The agent paragraph says the task ends at the hand-off. Brownfield offers unattended adoption only when the developer asked for it, instead of as an equal alternative to stopping. |
| SessionStart reminder (`session-start.ps1`) | While adoption or bootstrap is pending: the command, that only the developer can start it, and nothing else. Already true; kept. |
| `/bootstrap`'s closing summary | Ends with what to do next: describe tasks in plain words, `/review` before a pull request, `docs/getting-started.md`. Today it stops at "open a PR". |
| `AGENTS.md` template | Agent-facing, loaded every turn, under a footprint ceiling: kept as it is. |
| Consumer CHANGELOG | Bold one-line summary, then what changes for you and any action, in plain words; evidence detail lives in the docs. |

## 5. Audit of what ships (2026-10-15, v0.96.1)

| File | Verdict | Reason |
|---|---|---|
| root `README.md` | **Rewrite** (light) | The runbook is sound. Missing: what is guaranteed and what it costs for the tech lead; a pointer to the tutorial for humans. "Status" and "For maintainers" stay one line each. |
| `src/stacks/*/files/README.md` | **Rewrite** | Two jobs: a getting-started page that is never installed (so a developer in their repo cannot find it) and a second install runbook that differs from the root one (runs the stack installer directly). Becomes a landing page: what the stack adds, a doc map, a pointer to the root runbook. Its daily-work table, PR recipe and removal steps move to the tutorial, `REVIEW-GUIDE.md` and `upgrade-checklist.md`. |
| `src/core/docs/upgrade-checklist.md` | **Rewrite** | Step 3 runs the stack installer from a "fresh framework checkout" without saying to check out the newest tag, unlike the README; nine dense steps mix the common path with rare migrations. Becomes: the common path in five steps from a clone at the newest tag, then the migrations as a reference list, then removal (moved from the stack README). Every caveat kept. |
| `src/stacks/*/files/docs/ci-integration.md` | **Keep** | One job, already a task guide; pinned by `RootInstallerWarehouse.Tests`. |
| `src/stacks/*/files/docs/REVIEW-GUIDE.md` | **Rewrite** | Its job today is "evaluate the framework" (a reader's tour), which is the explanation doc's job. Repurposed to the task its name says: review a change or a pull request. The verify-the-claims checklist moves to `playbook.md`. |
| `src/stacks/*/files/docs/ARCHITECTURE.md` | **Rewrite** (to a short note) | Protected, so a consumer's copy never updates: a framework map that is stale after the first upgrade. Its content moves to the new framework-owned `docs/reference.md`; the shipped file becomes a note pointing there. Path kept (the installer's adoption logic and `architecture.html` name it). |
| `src/stacks/*/files/docs/playbook.md` | **Rewrite** | The explanation doc. Keeps the problem, Trojan Horse, tiers, design culture and token economy; gains what is guaranteed, the costs, the limits and how to verify the claims. Drops the daily-workflow list (tutorial owns it). |
| `src/core/docs/enforcement-surfaces.md` | **Keep** | The reference matrix, where dated caveats belong. |
| `src/stacks/*/files/docs/defaults.md` | **Keep** | Agent-facing; pinned by `OperationSkillAuthority`. |
| `src/core/docs/architecture.html` | **Keep** | Byte-pinned retired placeholder. |
| `src/core/docs/architecture-decisions.md`, `docs/wiki/*` | **Keep** | Consumer content. |
| `specs/README.md`, `tests/evals/README.md` | **Keep** | Workflow artifacts with one job each. |
| `presentation/*` (not installed) | **Keep** | The tech lead's deck; checked for contradictions only. |
| Installer output | **Rewrite** the closing block | Two pages of capitals; brownfield invites the agent to run headless adoption as an equal alternative, which contradicts the README's "stop". Pinned phrases (`InstallerContract`, `RootInstallerWarehouse`) kept. Guarded: red-first, both hosts, CP437, fresh-session attack. |
| SessionStart text | **Keep** | Already names the command and who must type it. |
| `/bootstrap` Phase 4 report | **Rewrite** the ending | Add the "what now" lines. Guarded path (`src/stacks/*/files/.claude/**`), text only. |
| `AGENTS.md` template | **Keep** | Agent-facing, footprint-ceilinged. |
| Consumer CHANGELOG voice | **Keep**, tighten new entries | Already written to the consumer; recent entries run long. |
| New `docs/getting-started.md`, `docs/reference.md` | **Add** | The tutorial and the reference the set lacks. |

## 6. Acceptance

The eval pre-registered in `meta/eval-results.md` ("consumer-docs pre-registration"): `url-install-greenfield`,
`url-install-brownfield` and `dev-setup` in `.claude/evals/scenarios.json`, three runs each before (v0.96.1) and after
(the release carrying this rework). Plus the gates for every changed path.
