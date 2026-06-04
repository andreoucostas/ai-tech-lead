# AI Tech Lead Framework — .NET C#

A working template that turns Claude Code and GitHub Copilot into a tech lead for your .NET codebase. Clone it, run one command, and get AI-driven development with built-in conventions, verification, and continuous improvement.

## Implementing this framework (for an AI agent)

Pointed at this repo and asked to install the framework into a target codebase? Do this:

1. **Copy the files in:** `bash scripts/install.sh <target-repo-path>` (or `pwsh scripts/install.ps1 <target-repo-path>`). It copies everything except the `.git` directory and the `.template-repo` marker.
2. **Populate it** in the target repo: run **`/adopt`** if it already has AI tooling (CLAUDE.md, `.cursorrules`, Copilot instructions, ADRs, Aider/Continue config…), otherwise **`/bootstrap`**.
3. **Self-verify:** `bash scripts/docs-sync-check.sh`, then read the generated `CLAUDE.md` — it is the source of truth that drives every tool.

Architecture is mapped in [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md); reviewers should start with [docs/REVIEW-GUIDE.md](./docs/REVIEW-GUIDE.md). Detailed manual steps are in "Quick Start" below.

`/adopt` also produces a **before/after impact report** in `docs/impact/` (capability diff + codebase scorecard + an optional Copilot-CLI behavioral A/B) to show tech leads what changed — fully automated, no input needed.

## Why this framework?

Without it, AI tools give you generic .NET code. The AI doesn't know your architecture, your conventions, or your team's decisions. Every developer gets different AI behaviour. The AI suggests patterns your team has already decided against, invents class names that don't exist, adds abstractions you don't need (while skipping the ones you do), and never cleans up the mess it leaves behind.

This framework fixes that by giving the AI team-level context — your actual conventions, your actual architecture, your actual debt priorities — and enforcing a consistent execution model across every developer and every tool.

**The AI won't hallucinate your codebase.** Verification rules require it to confirm any class, method, package, or route exists in your code before referencing it. If it can't confirm, it says so.

**Quality improves as a side effect of normal work.** The Trojan Horse principle bundles cleanup into every feature ticket and bug fix. The AI applies the Boy Scout Rule to every file it touches, and a counterweight leanness rule stops it from adding abstraction you don't need. After three months, every actively-developed area is measurably cleaner — without a single dedicated debt sprint.

**Security becomes systematic, not heroic.** `/security-review` runs a structured OWASP-style audit on every change — injection, auth/authz, secrets, sensitive data exposure, crypto, transport. It doesn't require anyone to remember to ask.

**Common patterns can't be done wrong.** Skills encode the correct approach for the tasks your team does repeatedly — add an endpoint end-to-end, add an EF Core entity, register a service. The AI follows that recipe, not a generic one. Junior developers get senior-level scaffolding.

**Works with the tools you already have.** The same source of truth drives Claude Code (agentic, skills, hooks) and GitHub Copilot (inline completions, chat, coding agent). You're not locked in to either.

**Built for regulated environments.** Every AI-assisted file change is logged with timestamp and branch for traceability. Security findings are tracked in a separate register with remediation SLAs. Financial domain invariants (decimal precision, idempotency, TOCTOU races) are detected automatically during codebase analysis.

For the full methodology — why the three-tier design, how the Trojan Horse works in practice, design culture guardrails — see [`docs/playbook.md`](./docs/playbook.md).

## Quick Start

### 1. Copy into your project
Copy the following into your existing .NET **solution root** (where your `.sln` file lives):
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
docs/defaults.md                    → greenfield .NET conventions (used until /bootstrap runs)
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
- Analyses your codebase (architecture, domain, DI, API, testing, code quality)
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
/security-review           — OWASP-style scan + senior judgement on auth, data flow, secrets
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
| `FRAMEWORK-CONTEXT.md` | Cross-repo context: shared NuGet libraries, multi-tenancy conventions, dashboard contracts, cross-service patterns. Maintainer-curated; bootstrap populates the "Detected Framework Packages" section. |
| `AGENTS.md` | **Generated** — full mirror of CLAUDE.md's portable rules (Verification, Leanness, Conventions, Boy Scout, Agentic Workflow) so AGENTS.md-native tools (Copilot agent mode & CLI, Codex, Cursor, Gemini, Aider) get the real ruleset, not a pointer. Refreshed by `/generate-copilot`. |
| `.github/copilot-instructions.md` | **Generated** — slim imperative ruleset (≤80 lines) for Copilot **inline completions** only. Agent-mode tools read the fuller `AGENTS.md`. |
| `.github/prompts/*.prompt.md` | Copilot Chat workflows. Thin wrappers that delegate to `.claude/commands/`. |
| `.claude/commands/*.md` | Canonical workflow definitions (used by Claude Code natively, and by the Copilot prompt files). |
| `.claude/skills/*/SKILL.md` | Auto-discovered Common Tasks recipes (add-endpoint, add-entity, register-service, add-tests, perf, dependency-audit, create-adr, enforce-architecture). Body loads only when triggered. Mirrored to `.github/skills/` for Copilot. |
| `.claude/agents/*.md` | Subagents (security-auditor, solid-check, convention-check, bloat-radar, debt-radar, bootstrap-pass). Run in isolated context; return structured findings. The five user-facing ones are mirrored to `.github/agents/*.agent.md` as Copilot custom agents. |
| `.claude/workflow.md` | Shared self-review + flag-drift tail inlined by the workflow commands via `@.claude/workflow.md`. |
| `.claude/hooks/*.sh` | SessionStart context preload, UserPromptSubmit intent router, **PreToolUse guard** (blocks warning-suppressions & secrets), PostToolUse build trigger and audit trail, Stop Boy Scout scanner. Each has a `.ps1` twin for Windows-only teams. |
| `.claude/settings.json` | Registers hooks for Claude Code: SessionStart, UserPromptSubmit, PreToolUse (`guard` before `.cs` writes), PostToolUse (`dotnet build` + audit trail after `.cs` writes), and Stop. |
| `.github/hooks/hooks.json` | Registers the same hooks for Copilot cloud agent and CLI (on Bitbucket, the CLI surface only). Points to the same scripts in `.claude/hooks/`. |
| `.github/skills/`, `.github/agents/` | **Generated** Copilot-facing mirrors: `.github/skills/` is a byte-identical copy of `.claude/skills/` (via `scripts/sync-agent-files.*`); `.github/agents/*.agent.md` wrap the subagents as Copilot custom agents. |
| `scripts/` | Host-agnostic helpers: `install.{sh,ps1}` (install into a target repo), `docs-sync-check.{sh,ps1}` (CI guardrail), `sync-agent-files.{sh,ps1}` (skills mirror), `build-architecture-html.{sh,ps1}`, `metrics.{sh,ps1}` + `impact-run.{sh,ps1}` (impact harness), `ci/` samples (Bitbucket Pipelines, NetArchTest). |
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
2. **Execute in verified subtasks** (build + test + format after each)
3. **Boy Scout** every touched file
4. **Self-review** against conventions (shared `@.claude/workflow.md` tail)
5. **Flag drift** in documentation

### Deterministic hooks
| Hook | When | What it does |
|------|------|--------------|
| `SessionStart` | New session | Preloads branch, last 3 commits, `BOOTSTRAP_PENDING` warning, the workflow-routing primer, the count of TECH_DEBT entries touching files modified in the last 14 days, and any overdue `SECURITY_FINDINGS` |
| `UserPromptSubmit` | Every prompt (Claude Code only) | Regex-classifies natural-language prompts as `fix`/`feature`/`refactor`/`test`/`design`/`debt`/`review` and injects that workflow's hard rules. Skips explicit `/command` invocations. **Copilot does not consume hook stdout for this event** ([hooks reference](https://docs.github.com/en/copilot/reference/hooks-configuration)), so in Copilot the equivalent vocabulary is shipped via the `SessionStart` primer and the model self-classifies. |
| `PreToolUse` (Write/Edit) | Before every `.cs` write | **Hard-blocks** the write if it adds a warning-suppression (`#pragma warning disable`) or a hardcoded secret (private key, cloud token, credential literal). Deterministic enforcement of Verification Rule #7. Runs in Claude Code **and** Copilot CLI. |
| `PostToolUse` (Write/Edit) | After every `.cs` write | Runs solution-level incremental `dotnet build` — catches compilation errors before they compound. Plus a second handler appends an SR 11-7 / DORA audit-log line. |
| `Stop` | End of every turn (Claude Code only) | Scans modified `.cs` files for the always-apply Boy Scout patterns (async without `CancellationToken`, interpolated logger calls, EF read queries without `AsNoTracking()`, excess null-forgiving `!`); soft-warns the model. Copilot has no equivalent event. |

The router is the key piece. **In Claude Code**, a developer who types *"the export endpoint is broken"* gets the `/fix` rails (regression-test-first, blast-radius Boy Scout) auto-injected per-prompt, without typing a slash command. **In Copilot**, the same vocabulary is preloaded once per session and the model self-classifies — works well with top-tier models, less reliable with smaller ones. Either way, the seven workflows are also invokable explicitly as slash commands (`/feature`, `/fix`, …) for deterministic routing.

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
echo '{"prompt":"the export endpoint is broken"}' | bash .claude/hooks/route-prompt.sh
# Expected: "## Routed intent: `fix` ..." plus the fix-workflow rules.
```

```powershell
# PowerShell version (Windows-only PowerShell teams):
'{"prompt":"the export endpoint is broken"}' | powershell -NoProfile -ExecutionPolicy Bypass -File .claude\hooks\route-prompt.ps1
# Expected: "## Routed intent: `fix` ..." plus the fix-workflow rules.
```

Hooks degrade gracefully — a failing hook doesn't break the session, you just lose that hook's contribution.

### Common Tasks via skills
Recipes for "add a new endpoint end-to-end", "add a new EF Core entity", "register a new service" live as auto-discovered skills in `.claude/skills/`. The model triggers the relevant one when the user describes that kind of task; the body loads only when triggered, keeping main context lean.

### Subagents for isolated specialist work
Six subagents live in `.claude/agents/` — the five user-facing ones are mirrored to `.github/agents/*.agent.md` as Copilot custom agents:

| Agent | Purpose | Invoked by |
|-------|---------|-----------|
| `security-auditor` | OWASP-style scan of a diff (injection, auth/authz, secrets, crypto, financial/concurrency). Read-only. | `/security-review`; ad-hoc |
| `solid-check` | Audits a diff against CLAUDE.md > SOLID — the five principles (literal interface-per-injected-service). Read-only. | `/review` Step 1; ad-hoc |
| `convention-check` | Audits a diff against CLAUDE.md > Conventions; returns a structured findings table. Read-only. | `/review` Step 1; ad-hoc |
| `bloat-radar` | Flags speculative abstractions, shallow wrappers, parallel implementations, comment debris, trivial tests. Read-only. | `/review` Step 1; ad-hoc |
| `debt-radar` | Maps a file path or feature area to TECH_DEBT entries; suggests trojan-horse bundles. Read-only. | `/review` Step 1; `/feature` Step 1; ad-hoc |
| `bootstrap-pass` | Runs a single bootstrap analysis pass (A1–A7) in isolation. Read-only. | `/bootstrap` Phase 1 (seven in parallel) |

Subagents run in isolated context — analysis chatter does not pollute the parent's main conversation. The parent receives one structured message per subagent and synthesises.

## Mixed-stack repos (.NET + frontend in one repository)

If your repo has significant code in another stack alongside .NET — e.g. a colocated Angular SPA, a Razor/Blazor frontend, or a sizeable JavaScript build pipeline — use **path-scoped Copilot instructions** so each stack gets the right rules.

Create files under `.github/instructions/` with `applyTo:` frontmatter:

```markdown
---
applyTo: "**/*.ts"
---
# TypeScript / Angular rules
- Use signals over BehaviorSubject for new code.
- Prefer the `inject()` function over constructor injection.
- ...
```

Copilot's coding agent and inline completions both honour `applyTo` — `.cs` files see the .NET rules from `copilot-instructions.md`, `.ts` files see the TypeScript rules from `.github/instructions/typescript.instructions.md`. The repo-wide rules apply on top of either.

If the secondary stack is Angular, the `ai-tech-lead-angular` template's `copilot-instructions.md` content is a sensible starting point — copy it into a `.github/instructions/typescript.instructions.md` file and add `applyTo: "**/*.{ts,html}"` at the top.

## Running on Bitbucket Data Center

This framework grew up around GitHub conventions, but its **local layer is host-agnostic** — it behaves the same whether your remote is GitHub, Bitbucket Cloud, or **Bitbucket Data Center / Server**. Only the *cloud-automation* layer is GitHub-specific. Here's precisely what applies on a self-hosted Bitbucket repo.

### Works unchanged (everything local)
- **GitHub Copilot in the IDE** (VS Code / Visual Studio / JetBrains) — completions, chat, and **agent mode** — reads `.github/copilot-instructions.md`, `.github/instructions/`, `.github/prompts/`, `.github/agents/`, `.github/skills/`, and `AGENTS.md` **from the working tree, regardless of git host**. The `.github/` folder name carries no GitHub dependency here; Copilot just looks there.
- **Claude Code** (CLI + IDE extension) — reads `CLAUDE.md` and everything under `.claude/`. Host-agnostic.
- **GitHub Copilot CLI** (GA Feb 2026) — runs `.github/hooks/hooks.json` hooks **locally on your machine**: the PreToolUse guard, the `dotnet build`, and the SR 11-7 / DORA audit trail all fire. (Only the *cloud-agent* half of hooks.json is inert on Bitbucket — the CLI half works.)
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
- **Dependencies**: Dependabot is GitHub-only — use **Renovate** (self-hostable) or the `dependency-audit` skill's CI fallback (`dotnet list package --vulnerable --include-transitive`).
- **SAST**: CodeQL is GitHub-only — run **Semgrep** or **SonarQube** in CI and publish via Code Insights.

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
- **Tool-name filter in hook scripts** (`post-write.{sh,ps1}`, `audit-trail.{sh,ps1}`). The filter previously accepted only Claude Code's `Write`/`Edit` (PascalCase); GitHub Copilot uses `edit`/`create` (lowercase). Every Copilot file-write event was being silently dropped before path extraction — meaning the SR 11-7 / DORA audit log never recorded a Copilot-initiated change. Filter now accepts both surfaces.
- **`toolArgs` parsing** in the same scripts. Per the Copilot hooks spec, `toolArgs` is a parsed object, not a JSON-encoded string. The previous `jq fromjson` / `ConvertFrom-Json` paths threw and were silently swallowed, so file-path extraction from Copilot payloads returned empty. Switched to direct object access, with a fallback string-parse for legacy payload shapes.
- **`settings.windows.json` audit-trail parity** — the bash variant registered two `PostToolUse` hooks (post-write + audit-trail); the PowerShell variant only registered post-write, so Windows-only PowerShell teams had no audit log. Added the audit-trail handler.
- **Prompt-file frontmatter** — `mode: agent` → `agent: agent` across all 13 `.github/prompts/*.prompt.md` files. `mode` was deprecated by VS Code in favor of `agent` (see `github/awesome-copilot#464`).
- **Bogus `$schema` URL** in `framework-version.json`. Removed — the URL pointed to a non-existent GitHub org.
- **`post-write` throttle window** — raised from 5 s to 60 s. Real `dotnet build` runs take 30 s+; the 5 s throttle expired long before the in-flight build finished, so burst writes still stomped on the running compile.
- **Boy-scout `!` (null-forgiving) detector** false-positive on `x!=y` (no surrounding spaces). Now requires the `!` to be in postfix-operator position.

**Changed**
- **README hook-compatibility table**. The "VS Code Copilot reads `.claude/settings.json` directly" row was unfounded — VS Code Copilot's surfaces are `.github/copilot-instructions.md`, `.github/instructions/`, `.github/prompts/`, and `.github/hooks/`. The table is now two rows: Claude Code (CLI + VS Code extension) and GitHub Copilot (cloud + CLI), with the exact payload shape per surface.

**Added**
- **Clean bail-out guard** in `post-write.sh|ps1`: skip if the `dotnet` CLI is not on PATH, instead of failing noisily.
