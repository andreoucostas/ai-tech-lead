# AI Tech Lead Framework — .NET C#

A working template that turns Claude Code and GitHub Copilot into a tech lead for your .NET codebase. Clone it, run one command, and get AI-driven development with built-in conventions, verification, and continuous improvement.

## 1. For AI agents (LLMs)

If you are an AI agent reading this repository, start here.

**Your source of truth is [`CLAUDE.md`](./CLAUDE.md)** (Claude Code reads it directly) or its generated mirror **[`AGENTS.md`](./AGENTS.md)** (Copilot agent/CLI, Codex, Cursor, Gemini, Aider). Read that file before doing anything else — it defines the verification rules, conventions, SOLID/leanness constraints, and the step-by-step workflow you must follow.

**If you were asked to install this framework into a target codebase** — installation is a two-actor flow: you (the agent) copy files and commit; a **developer** must then run the populate command. Your task is not complete until you have handed off explicitly:
1. **Copy the files in:** `pwsh scripts/install.ps1 <target-repo-path>` (or `bash scripts/install.sh <target-repo-path>`). The installer detects the mode itself: **greenfield** (plain copy), **brownfield** (the target already has AI tooling — the originals its copy would overwrite are moved to `docs/pre-adoption/` and `.claude/adoption-pending.json` is written), or **update** (target already stamped with `.claude/framework-version.json` — consumer-owned content files are left untouched).
2. **Commit the copied files** in the target repo — they are team-shared config, not local settings.
3. **Hand off to the developer.** Populating is done by **`/adopt`** (brownfield — the installer wrote `.claude/adoption-pending.json`) or **`/bootstrap`** (greenfield). Both are **developer-initiated**: the model cannot invoke them, and they only exist inside a Claude Code session started in the target repo — so you cannot run them, and you must not try to replicate them by hand. End your run by telling the developer, verbatim: *"start a Claude Code session in `<target repo>` and type `/adopt`"* (or `/bootstrap`). Until that happens, the SessionStart hook warns every new session and `scripts/docs-sync-check` fails CI — expect that check to fail at this stage; it passes only after the developer has run the command.

**If you were asked to do development work in a repo that already has this installed:** follow the **Agentic Workflow** in `CLAUDE.md` — classify intent, post a plan and wait for go-ahead, execute in verified subtasks (build + test after each), Boy Scout every touched file, self-review with a verification line. Trigger the matching skill in `.claude/skills/` when the task fits one.

Architecture: [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) · Reviewer's tour: [docs/REVIEW-GUIDE.md](./docs/REVIEW-GUIDE.md) · Full methodology: [docs/playbook.md](./docs/playbook.md).

## 2. What installing this gets you

No marketing. Each item is a concrete mechanism and the effect it produces.

1. **Less context burned per task — skills load on demand.** The Common-Task recipes (add-endpoint, add-entity, register-service, …) ship as skills whose body loads *only when the task matches*. They don't sit in the prompt the way a monolithic CONVENTIONS doc would. You pay context for the one recipe in use, not all of them — main context stays lean.

2. **Less context burned per review — subagents run isolated.** `/review` and `/security-review` fan out to subagents (solid-check, convention-check, bloat-radar, debt-radar, test-critic, security-auditor) that each run in their own context window. Their file-reading and intermediate reasoning never enter the main conversation — the parent gets one structured findings table per agent, not the full transcript.

3. **One command instead of hours hand-writing the AI's context.** `/bootstrap` (or `/adopt`) analyses architecture, domain, DI, API surface, testing, and code quality, then writes `CLAUDE.md`, `TECH_DEBT.md`, `AGENTS.md`, and `copilot-instructions.md`. You stop hand-authoring AI context — it's derived from the real codebase.

4. **The AI stops inventing your codebase.** Verification rules force it to confirm any class, method, NuGet package, or route exists (via Read/Grep) before referencing it, and to honour version pinning. Fewer hallucinated APIs means fewer wrong diffs and less rework.

5. **Compile errors caught the moment they're written.** A PostToolUse hook runs an incremental `dotnet build` after every `.cs` write, so an error surfaces on the next step instead of compounding across ten files.

6. **Bad writes blocked deterministically — no review round-trip.** A PreToolUse hook hard-blocks any write that adds a warning-suppression (`#pragma warning disable`) or a hardcoded secret. Enforced by code, not by remembering to check.

7. **Natural language routes to the right workflow — no slash commands to memorise.** Typing *"the export endpoint is broken"* auto-injects the `/fix` rails (regression-test-first, blast-radius cleanup). The seven workflows are still available as explicit slash commands when you want deterministic routing.

8. **Common tasks can't be done wrong.** Skills encode the correct end-to-end recipe (add-endpoint: domain → service → DTO → validator → thin controller → integration test). Juniors get senior-level scaffolding; the agent follows *your* recipe, not a generic one.

9. **Quality improves as a side effect of normal work.** The Boy Scout Rule cleans every file the agent touches; the Trojan Horse principle bundles debt cleanup into feature and fix tickets; a leanness counterweight stops it adding abstraction you don't need. No dedicated debt sprints.

10. **Security is systematic, not heroic.** `/security-review` runs an OWASP-style pass (injection, auth/authz, secrets, sensitive-data exposure, crypto, financial/concurrency) on every change; findings land in `SECURITY_FINDINGS.md` with remediation SLAs.

11. **One source of truth across every tool.** `CLAUDE.md` drives Claude Code; its mirror `AGENTS.md` drives Copilot agent/CLI, Codex, Cursor, Gemini, Aider; a ≤80-line `copilot-instructions.md` drives inline completions. Every developer and every tool gets the same rules — no per-developer drift.

12. **Built for regulated environments.** Every AI-assisted file change is appended to an audit log with timestamp and branch. Security findings tracked separately with SLAs. Financial invariants (decimal precision, idempotency, TOCTOU races) are detected automatically during analysis.

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

> **Hook prerequisite — the shell wired in `.claude/settings.json` must exist on every developer machine.** As shipped, Claude Code hooks run via **PowerShell 7 (`pwsh`)**, and `settings.json` is committed team config — every clone inherits it. A machine without the wired shell gets **no hooks, silently**: no write guard, no build feedback, no audit trail (the CLAUDE.md rules still instruct the model, but nothing enforces at write time). Either install PowerShell 7 on every dev machine — macOS and Linux included — or rewire once at install time: `scripts/install.sh` switches the hooks to the `.sh` (bash) twins when the installing box lacks pwsh, and `scripts/install.ps1` falls back to Windows PowerShell 5.1 (`settings.windows.json`). Whichever variant your team commits becomes the team-wide prerequisite.

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

> **Installed by an AI agent?** The installer detects the brownfield case itself: it archives the artifacts its copy would overwrite to `docs/pre-adoption/` and writes `.claude/adoption-pending.json`. From then on, every new Claude Code session and every `docs-sync-check` run points at `/adopt` until a developer runs it. `/adopt` and `/bootstrap` are deliberately **not model-invocable** — an agent-driven install ends with a handoff message ("type `/adopt`"), never with the agent running or imitating the command.

Either command:
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

To pull template updates, re-run the installer from a fresh template checkout against your repo (`bash scripts/install.sh /path/to/your-repo` or `pwsh scripts/install.ps1 /path/to/your-repo`) — it detects the existing `.claude/framework-version.json` and switches to **update mode**: framework machinery (hooks, commands, skills, scripts) is refreshed and the JSON stamp comes along, while consumer-owned content (CLAUDE.md, TECH_DEBT.md, …) is left untouched. Bump the CLAUDE.md header comment yourself as part of the update commit. CI tooling reads the JSON file to detect drift between your repo and the latest template version. If the version stamps disagree, treat the JSON file as authoritative.

## What's in the box

| File | Purpose |
|------|---------|
| `CLAUDE.md` | **Single source of truth** (authored) — conventions, architecture, common tasks, agentic workflow. Read directly by Claude Code. Copilot/Codex/Cursor read its generated mirror `AGENTS.md`. |
| `FRAMEWORK-CONTEXT.md` | Cross-repo context: shared NuGet libraries, multi-tenancy conventions, dashboard contracts, cross-service patterns. Every section is drafted by `/bootstrap` from the repo's code (cross-repo facts the code can't show are explicitly left to maintainers); "Detected Framework Packages" and "Known Hazard Areas" are also refreshed by `/docs-sync`. |
| `AGENTS.md` | **Generated** — full mirror of CLAUDE.md's portable rules (Verification, Leanness, Conventions, Boy Scout, Agentic Workflow) so AGENTS.md-native tools (Copilot agent mode & CLI, Codex, Cursor, Gemini, Aider) get the real ruleset, not a pointer. Refreshed by `/generate-copilot`. |
| `.github/copilot-instructions.md` | **Generated** — slim imperative ruleset (≤80 lines) for Copilot **inline completions** only. Agent-mode tools read the fuller `AGENTS.md`. |
| `.github/prompts/*.prompt.md` | Copilot Chat workflows. Thin wrappers that delegate to `.claude/commands/`. |
| `.claude/commands/*.md` | Canonical workflow definitions (used by Claude Code natively, and by the Copilot prompt files). |
| `.claude/skills/*/SKILL.md` | Auto-discovered Common Tasks recipes (add-endpoint, add-entity, register-service, add-tests, perf, dependency-audit, create-adr, enforce-architecture, enforce-standards). Body loads only when triggered. Mirrored to `.github/skills/` for Copilot. |
| `.claude/agents/*.md` | Subagents (security-auditor, solid-check, convention-check, bloat-radar, debt-radar, test-critic, bootstrap-pass). Run in isolated context; return structured findings. The six user-facing ones are mirrored to `.github/agents/*.agent.md` as Copilot custom agents. |
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
| `docs/presentation/` | Ready-to-present, self-contained HTML briefing deck (`framework-briefing.html`) + `TALKING-POINTS.md` — for pitching the framework to tech leads and their teams (overview + practical implications). |

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
| `SessionStart` | New session | Preloads branch, last 3 commits, the adoption-pending warning (`.claude/adoption-pending.json` present → steer to `/adopt`, not `/bootstrap`) or the `BOOTSTRAP_PENDING` warning, the workflow-routing primer, the count of TECH_DEBT entries touching files modified in the last 14 days, and any overdue `SECURITY_FINDINGS` |
| `UserPromptSubmit` | Every prompt (Claude Code only) | Regex-classifies natural-language prompts as `fix`/`feature`/`refactor`/`test`/`design`/`debt`/`review` and injects that workflow's hard rules. Skips explicit `/command` invocations. **Copilot does not consume hook stdout for this event** ([hooks reference](https://docs.github.com/en/copilot/reference/hooks-configuration)), so in Copilot the equivalent vocabulary is shipped via the `SessionStart` primer and the model self-classifies. |
| `PreToolUse` (Write/Edit) | Before every `.cs` write | **Hard-blocks** the write if it adds a warning-suppression (`#pragma warning disable`) or a hardcoded secret (private key, cloud token, credential literal). Deterministic enforcement of Verification Rule #7. Runs in Claude Code **and** Copilot CLI. |
| `PostToolUse` (Write/Edit) | After every `.cs` write | Runs solution-level incremental `dotnet build` — catches compilation errors before they compound. Plus a second handler appends an SR 11-7 / DORA audit-log line. |
| `Stop` | End of every turn (Claude Code only) | Scans modified `.cs` files for the always-apply Boy Scout patterns (async without `CancellationToken`, interpolated logger calls, EF read queries without `AsNoTracking()`, excess null-forgiving `!`); soft-warns the model. Copilot has no equivalent event. |

The router is the key piece. **In Claude Code**, a developer who types *"the export endpoint is broken"* gets the `/fix` rails (regression-test-first, blast-radius Boy Scout) auto-injected per-prompt, without typing a slash command. **In Copilot**, the same vocabulary is preloaded once per session and the model self-classifies — works well with top-tier models, less reliable with smaller ones. Either way, the seven workflows are also invokable explicitly as slash commands (`/feature`, `/fix`, …) for deterministic routing.

#### Hook compatibility

The same hook logic runs across Claude Code and GitHub Copilot, shipped as both a bash script and a PowerShell twin. Two hook surfaces are supported:

| Surface | Config file | Payload shape | Notes |
|---------|-------------|---------------|-------|
| **Claude Code** (CLI + VS Code extension) | `.claude/settings.json` | `tool_name` ∈ {`Write`,`Edit`}; `tool_input.file_path` | Native hook support with `matcher` field — hooks already filtered by tool name before the script runs. |
| **GitHub Copilot** (cloud agent + CLI) | `.github/hooks/hooks.json` | `toolName` ∈ {`edit`,`create`}; `toolArgs.filePath` (parsed object, not a JSON string) | No `matcher` support — the scripts filter by tool name internally. |

Hook interpreter by platform. **Claude Code's `settings.json` defaults to the PowerShell (`pwsh`) twins** — so hooks fire on Windows without git-bash (the old bash default silently no-opped there). The installer adapts the interpreter to your machine, so this is automatic:

| Platform | Hook interpreter | Notes |
|----------|------------------|-------|
| Windows + PowerShell 7 (`pwsh`) | `pwsh` (default) | Works out of the box — no git-bash required. |
| Windows, no `pwsh` | Windows PowerShell 5.1 | `install.ps1` auto-activates `settings.windows.json` (5.1 is preinstalled on every Windows box). |
| Windows + Git for Windows (git-bash) | `pwsh`, or bash if preferred | Run `install.sh` under git-bash to switch to the bash twins. `.gitattributes` pins `*.sh` to LF so CRLF can't break them. |
| macOS / Linux + `pwsh` | `pwsh` (default) | Works out of the box. |
| macOS / Linux, no `pwsh` | bash | `install.sh` switches to the bash twins (`git`, `grep`, `tr`, `printf`, `wc` are all default). |
| Windows + WSL only | — | Not recommended: `/mnt/c/...` path translation breaks the hooks. Install Git for Windows or PowerShell alongside WSL. |

> GitHub Copilot's `.github/hooks/hooks.json` already declares both a `bash` and a `powershell` command per hook and picks per-OS, so Copilot is unaffected — this change brings Claude Code to parity on Windows.

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
Seven subagents live in `.claude/agents/` — the six user-facing ones are mirrored to `.github/agents/*.agent.md` as Copilot custom agents:

| Agent | Purpose | Invoked by |
|-------|---------|-----------|
| `security-auditor` | OWASP-style scan of a diff (injection, auth/authz, secrets, crypto, financial/concurrency). Read-only. | `/security-review`; ad-hoc |
| `solid-check` | Audits a diff against CLAUDE.md > SOLID — the five principles (literal interface-per-injected-service). Read-only. | `/review` Step 1; ad-hoc |
| `convention-check` | Audits a diff against CLAUDE.md > Conventions; returns a structured findings table. Read-only. | `/review` Step 1; ad-hoc |
| `bloat-radar` | Flags speculative abstractions, shallow wrappers, parallel implementations, comment debris, trivial tests. Read-only. | `/review` Step 1; ad-hoc |
| `test-critic` | Audits the test changes for integrity — would each test fail if the code under test broke? Flags over-mocking, tautological/weak assertions, missing paths, nondeterminism. Read-only. | `/review` Step 1; ad-hoc |
| `debt-radar` | Maps a file path or feature area to TECH_DEBT entries; suggests trojan-horse bundles. Read-only. | `/review` Step 1; `/feature` Step 1; ad-hoc |
| `bootstrap-pass` | Runs a single bootstrap analysis pass (A1–A8) in isolation. Read-only. | `/bootstrap` Phase 1 (eight in parallel) |

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

### The CI guardrail on Bitbucket — a required build is expected, not optional
**Every repo using this framework is expected to wire one required build in its own CI (Bamboo/Jenkins/TeamCity) that gates PR merges.** The full recipe — what the build must run (the shipped `scripts/docs-sync-check.sh`/`.ps1` framework-state check **plus** `dotnet build -warnaserror` + `dotnet test` as the code-standards gate), Bamboo and Jenkins configurations, and how to make it blocking via Bitbucket DC's *required builds* merge check (repo-admin only, no server plugins) — lives in **[docs/ci-integration.md](./docs/ci-integration.md)**.
- **Also enable** Bitbucket DC's native **secret scanning** (8.12+, push-time blocking — zero custom code).
- **Optionally surface it on the PR** via the **Code Insights REST API** (`/rest/insights/1.0/...`); cosmetic on top of required builds, not a substitute.
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
