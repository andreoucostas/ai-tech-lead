# AI Tech Lead Framework — Angular

A working template that turns Claude Code and GitHub Copilot into a tech lead for your Angular codebase. Clone it, run one command, and get AI-driven development with built-in conventions, verification, and continuous improvement.

Targets **Angular 17+** (standalone components, signals, new control flow, `inject()`, `takeUntilDestroyed`). Bootstrap auto-detects your Angular version and adjusts conventions accordingly.

## Implementing this framework (for an AI agent)

Pointed at this repo and asked to install the framework into a target codebase? Do this:

1. **Copy the files in:** `bash scripts/install.sh <target-repo-path>` (or `pwsh scripts/install.ps1 <target-repo-path>`). It copies everything except the `.git` directory and the `.template-repo` marker.
2. **Populate it** in the target repo: run **`/adopt`** if it already has AI tooling (CLAUDE.md, `.cursorrules`, Copilot instructions, ADRs, Aider/Continue config…), otherwise **`/bootstrap`**.
3. **Self-verify:** `bash scripts/docs-sync-check.sh`, then read the generated `CLAUDE.md` — it is the source of truth that drives every tool.

Architecture is mapped in [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md); reviewers should start with [docs/REVIEW-GUIDE.md](./docs/REVIEW-GUIDE.md). Detailed manual steps are in "Quick Start" below.

`/adopt` also produces a **before/after impact report** in `docs/impact/` (capability diff + codebase scorecard + an optional Copilot-CLI behavioral A/B) to show tech leads what changed — fully automated, no input needed.

## Why this framework?

Without it, AI tools give you generic Angular code. The AI doesn't know your team uses signals over BehaviorSubject, `inject()` over constructor injection, or `OnPush` everywhere. It doesn't know you've migrated away from NgModules. It doesn't know about the state management pattern your team settled on after two failed experiments. Every developer gets different AI behaviour. The AI suggests patterns your team has already moved past, adds RxJS complexity where a signal would do, and never cleans up the subscriptions it leaves behind.

This framework fixes that by giving the AI team-level context — your actual conventions, your actual architecture, your actual debt priorities — and enforcing a consistent execution model across every developer and every tool.

**The AI won't hallucinate your codebase.** Verification rules require it to confirm any component, service, route, selector, or npm package exists in your code before referencing it. Version pinning is enforced too — signals, `takeUntilDestroyed`, and the new control flow syntax are version-gated, and the AI won't suggest them against a version that doesn't have them.

**Quality improves as a side effect of normal work.** The Trojan Horse principle bundles cleanup into every feature ticket and bug fix. The AI applies the Boy Scout Rule to every file it touches — replacing manual `ngOnDestroy` subscription cleanup with `takeUntilDestroyed()`, flattening nested subscribes, replacing `any` with proper types — and a counterweight leanness rule stops it from adding abstraction you don't need. Semantic changes like switching a component to `OnPush` are explicitly excluded from drive-by cleanup. After three months, every actively-developed area is measurably cleaner — without a single dedicated debt sprint.

**Security becomes systematic, not heroic.** `/security-review` runs a structured OWASP-style audit on every change — XSS via unsafe HTML binding, auth/authz gaps, secrets in source, sensitive data in logs or API responses. It doesn't require anyone to remember to ask.

**Common patterns can't be done wrong.** Skills encode the correct approach for the tasks your team does repeatedly — add a feature component end-to-end, add a service, add a lazy route, add a signal store. The AI follows that recipe, not a generic one. Junior developers get senior-level scaffolding.

**Works with the tools you already have.** The same source of truth drives Claude Code (agentic, skills, hooks) and GitHub Copilot (inline completions, chat, coding agent). You're not locked in to either.

For the full methodology — why the three-tier design, how the Trojan Horse works in practice, design culture guardrails — see [`docs/playbook.md`](./docs/playbook.md).

## Quick Start

### 1. Copy into your project
Copy the following into your existing Angular **project root** (where `angular.json` lives):
```
.claude/                            → Claude Code commands and hooks
.github/prompts/                    → GitHub Copilot Chat workflows (mirror of .claude/commands/)
.github/skills/                     → Copilot-facing mirror of .claude/skills/ (generated)
.github/agents/                     → Copilot custom agents wrapping the subagents
.github/hooks/hooks.json            → registers the hooks for Copilot CLI / cloud agent
.github/workflows/docs-sync-check.yml → CI guardrail (GitHub Actions; Bitbucket uses scripts/)
.github/PULL_REQUEST_TEMPLATE.md    → PR template with design rationale + Boy Scout checklist
scripts/                            → host-agnostic CI guardrail + skills-sync + Bitbucket CI sample
specs/                              → persistent feature specs (spec-driven development)
AGENTS.md                           → generated mirror of CLAUDE.md's rules (for Copilot/Codex/Cursor)
CLAUDE.md                           → template, populated by /bootstrap
FRAMEWORK-CONTEXT.md                → cross-repo context (shared libs, multi-tenancy, dashboard contracts)
LEARNINGS.md                        → append-only log of what works/doesn't
TECH_DEBT.md                        → template, populated by /bootstrap
docs/defaults.md                    → greenfield Angular conventions (used until /bootstrap runs)
docs/playbook.md                    → methodology guide
```

**Do not copy** `.template-repo` — it's a marker that exists only in this template repository to disable the CI guardrail here.

All of these files should be committed to version control — they're shared team configuration, not local settings.

### 2. Bootstrap (greenfield) **or** Adopt (existing setup)

If the repo has **no AI tooling yet**, run:
```
/bootstrap
```

If the repo **already has AI artifacts** (CLAUDE.md from another template, `.cursorrules`, Cursor rules, Copilot instructions, Aider/Continue config, generic ARCHITECTURE/CONVENTIONS/ADR docs, an existing TECH_DEBT register, etc.), run:
```
/adopt
```
`/adopt` discovers everything, archives originals to `docs/pre-adoption/`, merges useful content into our canonical structure (CLAUDE.md + TECH_DEBT.md), then runs `/bootstrap` to fill gaps. Nothing is deleted.

Either command:

This single command:
- Analyses your codebase (modules, state management, components, RxJS, API layer, testing)
- Synthesises findings into priorities
- Populates `CLAUDE.md` with your actual conventions and patterns
- Generates `TECH_DEBT.md` with prioritised debt
- Audits `.claude/skills/` against your codebase, adjusts default Common-Tasks recipes, and adds new skills for project-specific patterns
- Generates `AGENTS.md` (full rules mirror of `CLAUDE.md` for Copilot agent / Codex / Cursor / Aider) and mirrors skills to `.github/skills/`
- Generates a slim `.github/copilot-instructions.md` for Copilot inline completions

### 3. Review
Read the generated `CLAUDE.md`. It should accurately describe your codebase. Fix anything that's wrong — this is the source of truth that all AI tools will follow.

### 4. Start working

Both Claude Code and Copilot Chat use the same slash-command names:

```
/feature [description]     — implement a feature across all layers
/fix [description]         — diagnose and fix a bug (regression test first)
/design [description]      — think through design before coding
/review                    — review changes as a tech lead
/security-review           — OWASP-style scan + senior judgement on auth, trust boundaries, secrets
/refactor [target]         — refactor with safety net
/test [target]             — generate tests following project patterns
/debt [area]               — find and fix tech debt
/docs-sync                 — check documentation for drift
/adopt                     — ingest existing AI-framework artifacts into this layout
/generate-copilot          — regenerate the slim copilot-instructions.md (for inline completions)
/impact                    — before/after impact report for tech leads (auto-run by /adopt)
```

In **Claude Code**, these are loaded from `.claude/commands/`. In **Copilot Chat**, the same names are loaded from `.github/prompts/` — those files are thin wrappers that delegate to the canonical `.claude/commands/*.md` files, so there's a single source of truth per workflow.

Or just describe what you want in natural language — `CLAUDE.md` teaches the agent to route to the right workflow automatically.

## Framework versioning

Each consumer repo records the template version it was last synced from. Two locations:
- A human-readable HTML comment at the top of `CLAUDE.md`
- A machine-readable `.claude/framework-version.json`

When you next pull template updates into your repo, bump both. CI tooling and a future `/framework-update` command read the JSON file to detect drift between your repo and the latest template version. If the version stamps disagree, treat the JSON file as authoritative.

## What's in the box

| File | Purpose |
|------|---------|
| `CLAUDE.md` | **Single source of truth** (authored) — conventions, architecture, common tasks, agentic workflow. Read directly by Claude Code. Copilot/Codex/Cursor read its generated mirror `AGENTS.md`. |
| `FRAMEWORK-CONTEXT.md` | Cross-repo context: shared npm libraries, multi-tenancy conventions, dashboard contracts, cross-service patterns. Maintainer-curated; bootstrap populates the "Detected Framework Packages" section. |
| `AGENTS.md` | **Generated** — full mirror of CLAUDE.md's portable rules (Verification, Leanness, Conventions, Boy Scout, Agentic Workflow) so AGENTS.md-native tools (Copilot agent mode & CLI, Codex, Cursor, Gemini, Aider) get the real ruleset, not a pointer. Refreshed by `/generate-copilot`. |
| `.github/copilot-instructions.md` | **Generated** — slim imperative ruleset (≤80 lines) for Copilot **inline completions** only. Agent-mode tools read the fuller `AGENTS.md`. |
| `.github/prompts/*.prompt.md` | Copilot Chat workflows. Thin wrappers that delegate to `.claude/commands/`. |
| `.claude/commands/*.md` | Canonical workflow definitions (used by Claude Code natively, and by the Copilot prompt files). |
| `.claude/skills/*/SKILL.md` | Auto-discovered Common Tasks recipes (add-component, add-service, add-lazy-route, add-signal-store, add-tests, dependency-audit, create-adr, enforce-architecture). Body loads only when triggered. Mirrored to `.github/skills/` for Copilot. |
| `.claude/agents/*.md` | Subagents (security-auditor, solid-check, convention-check, bloat-radar, debt-radar, bootstrap-pass). Run in isolated context; return structured findings. The five user-facing ones are mirrored to `.github/agents/*.agent.md` as Copilot custom agents. |
| `.claude/workflow.md` | Shared self-review + flag-drift tail inlined by the workflow commands via `@.claude/workflow.md`. |
| `.claude/hooks/*.sh` | SessionStart context preload, UserPromptSubmit intent router, **PreToolUse guard** (blocks warning-suppressions & secrets), PostToolUse type-checker, Stop Boy Scout scanner. Each has a `.ps1` twin for Windows-only teams. |
| `.claude/settings.json` | Registers hooks for Claude Code: SessionStart, UserPromptSubmit, PreToolUse (`guard` before `.ts` writes), PostToolUse (`tsc --noEmit` after `.ts` writes), and Stop. |
| `.github/hooks/hooks.json` | Registers the same hooks for Copilot cloud agent and CLI (on Bitbucket, the CLI surface only). Points to the same scripts in `.claude/hooks/`. |
| `.github/skills/`, `.github/agents/` | **Generated** Copilot-facing mirrors: `.github/skills/` is a byte-identical copy of `.claude/skills/` (via `scripts/sync-agent-files.*`); `.github/agents/*.agent.md` wrap the subagents as Copilot custom agents. |
| `scripts/` | Host-agnostic helpers: `install.{sh,ps1}` (install into a target repo), `docs-sync-check.{sh,ps1}` (CI guardrail), `sync-agent-files.{sh,ps1}` (skills mirror), `build-architecture-html.{sh,ps1}`, `metrics.{sh,ps1}` + `impact-run.{sh,ps1}` (impact harness), `ci/` samples (Bitbucket Pipelines, dependency-cruiser). |
| `specs/` | Persistent feature specs (spec-driven development). `/design` writes one, `/feature` implements against it, `/review` verifies. See `specs/README.md`. |
| `tests/impact/` + `docs/impact/` | Before/after impact harness — task suite + config; the generated report (`IMPACT.md` + `impact.html`) lands in `docs/impact/`. |
| `TECH_DEBT.md` | **Generated** by `/bootstrap` — prioritised debt register with Trojan Horse opportunities. |
| `LEARNINGS.md` | Append-only log of what worked / what didn't / what rule changed. Read on non-trivial work. |
| `docs/playbook.md` | Methodology guide (the "why" behind the framework). |
| `docs/ARCHITECTURE.md` (+ `architecture.html`) | Canonical architecture map with Mermaid diagrams; HTML is the generated, drift-checked view for reviewers. |
| `docs/REVIEW-GUIDE.md` | A senior reviewer's annotated tour — reading order, what each piece guarantees, how to verify, and the tradeoffs. |

## How it works

Every workflow command follows the same execution model:
1. **Plan** before coding (CLAUDE.md is auto-loaded — no need to re-read)
2. **Execute in verified subtasks** (build + test + lint after each)
3. **Boy Scout** every touched file
4. **Self-review** against conventions (shared `@.claude/workflow.md` tail)
5. **Flag drift** in documentation

### Deterministic hooks
| Hook | When | What it does |
|------|------|--------------|
| `SessionStart` | New session | Preloads branch, last 3 commits, `BOOTSTRAP_PENDING` warning, the workflow-routing primer, and the count of TECH_DEBT entries touching files modified in the last 14 days |
| `UserPromptSubmit` | Every prompt (Claude Code only) | Regex-classifies natural-language prompts as `fix`/`feature`/`refactor`/`test`/`design`/`debt`/`review` and injects that workflow's hard rules. Skips explicit `/command` invocations. **Copilot does not consume hook stdout for this event** ([hooks reference](https://docs.github.com/en/copilot/reference/hooks-configuration)), so in Copilot the equivalent vocabulary is shipped via the `SessionStart` primer and the model self-classifies. |
| `PreToolUse` (Write/Edit) | Before every `.ts` write | **Hard-blocks** the write if it adds a suppression (`// eslint-disable`, `@ts-ignore`, `@ts-nocheck`) or a hardcoded secret (private key, cloud token, credential literal). Deterministic enforcement of Verification Rule #7. Runs in Claude Code **and** Copilot CLI. |
| `PostToolUse` (Write/Edit) | After every `.ts` write | Runs `tsc --noEmit` (1-2 s) — catches type errors before they compound |
| `Stop` | End of every turn (Claude Code only) | Scans modified `.ts` files for the always-apply Boy Scout patterns (manual `ngOnDestroy` + `subscribe`, nested `subscribe`, `any`, commented-out code blocks); soft-warns the model. `OnPush` is intentionally excluded — switching a component to `OnPush` is a semantic change, not a drive-by cleanup. Copilot has no equivalent event. |

The router is the key piece. **In Claude Code**, a developer who types *"the export button is broken"* gets the `/fix` rails (regression-test-first, blast-radius Boy Scout) auto-injected per-prompt, without typing a slash command. **In Copilot**, the same vocabulary is preloaded once per session and the model self-classifies — works well with top-tier models, less reliable with smaller ones. Either way, the seven workflows are also invokable explicitly as slash commands (`/feature`, `/fix`, …) for deterministic routing.

#### Hook compatibility

The same hook scripts run across Claude Code and GitHub Copilot. All hooks are bash scripts with a PowerShell twin. Two hook surfaces are supported:

| Surface | Config file | Payload shape | Notes |
|---------|-------------|---------------|-------|
| **Claude Code** (CLI + VS Code extension) | `.claude/settings.json` | `tool_name` ∈ {`Write`,`Edit`}; `tool_input.file_path` | Native hook support with `matcher` field — hooks already filtered by tool name before the script runs. |
| **GitHub Copilot** (cloud agent + CLI) | `.github/hooks/hooks.json` | `toolName` ∈ {`edit`,`create`}; `toolArgs.filePath` (parsed object, not a JSON string) | No `matcher` support — the scripts filter by tool name internally. |

Platform compatibility for running the bash scripts:

| Platform | Status | Notes |
|----------|--------|-------|
| macOS (bash 3.2+) | Works out of the box | `git`, `grep`, `tr`, `printf`, `wc` are all default. |
| Linux | Works out of the box | Same as macOS. |
| Windows + Git for Windows (git-bash) | Works | Default installer puts `bash.exe` on PATH. Claude Code and Copilot find it automatically. |
| Windows + WSL only | Not recommended | Path translation between `/mnt/c/...` and Windows-style paths breaks the hooks. Install Git for Windows alongside WSL. |
| Windows + PowerShell only (no git-bash) | Works via PowerShell variant | Use the shipped PowerShell hooks. Copy `.claude/settings.windows.json` over `.claude/settings.json` (team-wide) or to `.claude/settings.local.json` (per-developer). Uses Windows PowerShell 5.1 — preinstalled on every Windows machine. PowerShell 7 (`pwsh`) also works. |

**Verify your setup** after copying the template into your repo:

```bash
# Bash version (macOS / Linux / Windows + git-bash):
echo '{"prompt":"the export button is broken"}' | bash .claude/hooks/route-prompt.sh
# Expected: "## Routed intent: `fix` ..." plus the fix-workflow rules.
```

```powershell
# PowerShell version (Windows-only PowerShell teams):
'{"prompt":"the export button is broken"}' | powershell -NoProfile -ExecutionPolicy Bypass -File .claude\hooks\route-prompt.ps1
# Expected: "## Routed intent: `fix` ..." plus the fix-workflow rules.
```

Hooks degrade gracefully — a failing hook doesn't break the session, you just lose that hook's contribution.

### Common Tasks via skills
Recipes for "add a new feature component", "add a new service", "add a new lazy route", "add a new signal-based store" live as auto-discovered skills in `.claude/skills/`. The model triggers the relevant one when the user describes that kind of task; the body loads only when triggered, keeping main context lean.

### Subagents for isolated specialist work
Six subagents live in `.claude/agents/` — the five user-facing ones are mirrored to `.github/agents/*.agent.md` as Copilot custom agents:

| Agent | Purpose | Invoked by |
|-------|---------|-----------|
| `security-auditor` | OWASP-style scan of a diff (XSS/unsafe DOM sinks, auth/route guards, secrets, sensitive-data exposure, vulnerable deps). Read-only. | `/security-review`; ad-hoc |
| `solid-check` | Audits a diff against CLAUDE.md > SOLID — the five principles (an abstraction/token per injected service). Read-only. | `/review` Step 1; ad-hoc |
| `convention-check` | Audits a diff against CLAUDE.md > Conventions; returns a structured findings table. Read-only. | `/review` Step 1; ad-hoc |
| `bloat-radar` | Flags speculative abstractions, shallow service wrappers, parallel implementations, single-use pipes/directives, comment debris. Read-only. | `/review` Step 1; ad-hoc |
| `debt-radar` | Maps a file path or feature area to TECH_DEBT entries; suggests trojan-horse bundles. Read-only. | `/review` Step 1; `/feature` Step 1; ad-hoc |
| `bootstrap-pass` | Runs a single bootstrap analysis pass (A1–A6) in isolation. Read-only. | `/bootstrap` Phase 1 (six in parallel) |

Subagents run in isolated context — analysis chatter does not pollute the parent's main conversation. The parent receives one structured message per subagent and synthesises.

Full `ng build` and `ng test` run inside command workflows, not as hooks — they're too slow for per-write execution.

## Mixed-stack repos (Angular + backend in one repository)

If your repo has significant code in another stack alongside Angular — e.g. a colocated .NET API, a Node/Express backend, or a Python service — use **path-scoped Copilot instructions** so each stack gets the right rules.

Create files under `.github/instructions/` with `applyTo:` frontmatter:

```markdown
---
applyTo: "**/*.cs"
---
# C# / .NET rules
- Propagate CancellationToken through every async call chain.
- Use `.AsNoTracking()` for read-only EF Core queries.
- ...
```

Copilot's coding agent and inline completions both honour `applyTo` — `.ts` files see the Angular rules from `copilot-instructions.md`, `.cs` files see the .NET rules from `.github/instructions/csharp.instructions.md`. The repo-wide rules apply on top of either.

If the secondary stack is .NET, the `ai-tech-lead-dotnet` template's `copilot-instructions.md` content is a sensible starting point — copy it into a `.github/instructions/csharp.instructions.md` file and add `applyTo: "**/*.cs"` at the top.

## Running on Bitbucket Data Center

This framework grew up around GitHub conventions, but its **local layer is host-agnostic** — it behaves the same whether your remote is GitHub, Bitbucket Cloud, or **Bitbucket Data Center / Server**. Only the *cloud-automation* layer is GitHub-specific. Here's precisely what applies on a self-hosted Bitbucket repo.

### Works unchanged (everything local)
- **GitHub Copilot in the IDE** (VS Code / JetBrains) — completions, chat, and **agent mode** — reads `.github/copilot-instructions.md`, `.github/instructions/`, `.github/prompts/`, `.github/agents/`, `.github/skills/`, and `AGENTS.md` **from the working tree, regardless of git host**. The `.github/` folder name carries no GitHub dependency here; Copilot just looks there.
- **Claude Code** (CLI + IDE extension) — reads `CLAUDE.md` and everything under `.claude/`. Host-agnostic.
- **GitHub Copilot CLI** (GA Feb 2026) — runs `.github/hooks/hooks.json` hooks **locally on your machine**: the PreToolUse guard and the `tsc --noEmit` type-check fire. (Only the *cloud-agent* half of hooks.json is inert on Bitbucket — the CLI half works.)
- **Skills, custom agents, prompts, slash commands** — all file-driven in the repo; no platform service required.

### Does NOT apply on Bitbucket (GitHub-only)
| GitHub feature | On Bitbucket DC | Use instead |
|----------------|-----------------|-------------|
| Copilot **coding agent** (async, assigned to issues, opens PRs) | Not available (github.com repos only) | Local CLI agents: Claude Code, Copilot CLI |
| `.github/workflows/docs-sync-check.yml` (**GitHub Actions**) | Does not run | `scripts/docs-sync-check.sh` in Bamboo/Jenkins/pre-receive (below) |
| `.github/PULL_REQUEST_TEMPLATE.md` | Not auto-applied | Bitbucket repo/project **default PR description** setting |
| Copilot **PR code review** | Not available | `/review` + `/security-review` locally pre-push; or a SAST step in CI |
| Atlassian **Rovo Dev** (native AI agent / PR reviewer) | **Cloud-only** — not on Data Center | Local CLI agents + the CI guardrail below |

> Net: on Bitbucket Data Center your agentic story is **local CLI agents + IDE Copilot**, not a cloud agent, and there is no platform-side AI PR reviewer. Gate quality with `/review` and `/security-review` *before* you push, and with the CI guardrail *after*.

### The framework-state guardrail on Bitbucket
The checks live in **`scripts/docs-sync-check.sh`** (PowerShell twin: `scripts/docs-sync-check.ps1`) — host-agnostic, exit 0/1. Wire it in whichever way fits your DC setup:
- **Bamboo / Jenkins / TeamCity**: a build step that runs `bash scripts/docs-sync-check.sh` and fails on non-zero exit.
- **Pre-receive hook** (server-side, blocks the push): call the script from a Bitbucket DC [pre-receive hook](https://confluence.atlassian.com/bitbucketserver/managing-merge-checks-and-hooks).
- **Surface it on the PR**: publish the verdict (and annotations) via the **Code Insights REST API** (`/rest/insights/1.0/...`), available on Bitbucket Data Center 10.x — the closest DC equivalent of a required GitHub check.
- **Bitbucket Cloud** repos: copy `scripts/ci/bitbucket-pipelines.example.yml` into `bitbucket-pipelines.yml`.

### Standing scanners on Bitbucket
- **Dependencies**: Dependabot is GitHub-only — use **Renovate** (self-hostable) or the `dependency-audit` skill's CI fallback (`npm audit --audit-level=high`).
- **SAST**: CodeQL is GitHub-only — run **Semgrep** or **SonarQube** (JS/TS) in CI and publish via Code Insights.

## Keeping it alive

- When conventions change: update `CLAUDE.md` and ask your agent (or `/generate-copilot`) to refresh `.github/copilot-instructions.md`
- Quarterly: run `/docs-sync` to find drift, or `/rebootstrap` for a deeper refresh
- Always: the Boy Scout Rule and Trojan Horse principle mean every change improves the codebase incrementally

## Changelog

> **Current, full changelog: [CHANGELOG.md](./CHANGELOG.md).** The entries below are an older excerpt kept for context.

### 0.7.2 — 2026-05-16 (Copilot routing parity)

**Fixed**
- **Natural-language routing in Copilot was a silent no-op.** Per the [GitHub Copilot hooks reference](https://docs.github.com/en/copilot/reference/hooks-configuration), the `userPromptSubmitted` event is fire-and-forget — stdout is discarded, so `route-prompt.sh|ps1` couldn't inject workflow rails on the Copilot side regardless of schema correctness. Removed the misleading `userPromptSubmitted` entry from `.github/hooks/hooks.json`.

**Added**
- **Workflow-routing primer in `SessionStart`** (both `session-start.sh` and `session-start.ps1`). Once per session, the hook now emits the seven workflow names with their trigger vocabulary so the model can self-classify natural-language prompts in Copilot. In Claude Code the per-prompt `route-prompt` router still runs (and dominates); the session-start primer is harmless reinforcement there.

**Changed**
- **README "Deterministic hooks" table** now flags `UserPromptSubmit` and `Stop` as Claude Code only, and the introductory paragraph distinguishes per-prompt routing (Claude Code) from session primer + self-classification (Copilot).

### 0.7.1 — 2026-05-15 (hook plumbing forensic-fix batch)

**Fixed**
- **`.claude/settings.json` hook schema** (bash + PowerShell variants). Restructured to the documented Claude Code form: each event entry now wraps handlers in a nested `hooks` array with explicit `"type": "command"`. The previous flattened form was non-conformant and likely failed to register hooks on recent Claude Code versions.
- **`.github/hooks/hooks.json` schema**. Added the required `"version": 1` field; converted the top-level `hooks` from an array to an object keyed by event name; added `"type": "command"` to every handler; added `timeoutSec` per event. The prior shape did not match the GitHub Copilot hooks reference and the hooks almost certainly weren't being loaded by the cloud agent.
- **Tool-name filter in hook scripts** (`post-write.{sh,ps1}`). The filter previously accepted only Claude Code's `Write`/`Edit` (PascalCase); GitHub Copilot uses `edit`/`create` (lowercase). Every Copilot file-write event was being silently dropped before path extraction. Filter now accepts both surfaces.
- **`toolArgs` parsing** in the same scripts. Per the Copilot hooks spec, `toolArgs` is a parsed object, not a JSON-encoded string. The previous `jq fromjson` / `ConvertFrom-Json` paths threw and were silently swallowed, so file-path extraction from Copilot payloads returned empty. Switched to direct object access, with a fallback string-parse for legacy payload shapes.
- **Prompt-file frontmatter** — `mode: agent` → `agent: agent` across all 13 `.github/prompts/*.prompt.md` files. `mode` was deprecated by VS Code in favor of `agent` (see `github/awesome-copilot#464`).
- **Bogus `$schema` URL** in `framework-version.json`. Removed — the URL pointed to a non-existent GitHub org.
- **`tsBuildInfoFile` location** — moved from repo root (`.claude-tsbuildinfo`) to `.claude/.state/tsbuildinfo` (already gitignored) so the cache no longer leaks into the project root.

**Changed**
- **README hook-compatibility table**. The "VS Code Copilot reads `.claude/settings.json` directly" row was unfounded — VS Code Copilot's surfaces are `.github/copilot-instructions.md`, `.github/instructions/`, `.github/prompts/`, and `.github/hooks/`. The table is now two rows: Claude Code (CLI + VS Code extension) and GitHub Copilot (cloud + CLI), with the exact payload shape per surface.

**Added**
- **Clean bail-out guard** in `post-write.sh|ps1`: skip if `node_modules` is absent, instead of failing noisily.
