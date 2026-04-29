# AI Tech Lead Framework — .NET C#

A working template that turns Claude Code and GitHub Copilot into a tech lead for your .NET codebase. Clone it, run one command, and get AI-driven development with built-in conventions, verification, and continuous improvement.

## Why this framework?

Without it, AI tools give you generic .NET code. The AI doesn't know your architecture, your conventions, or your team's decisions. Every developer gets different AI behaviour. The AI suggests patterns your team has already decided against, invents class names that don't exist, adds abstractions you don't need, and never cleans up the mess it leaves behind.

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
.github/workflows/docs-sync-check.yml → CI guardrail for framework state
.github/PULL_REQUEST_TEMPLATE.md    → PR template with design rationale + Boy Scout checklist
AGENTS.md                           → pointer for any agent-style tool
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
- Writes `AGENTS.md` (a pointer at `CLAUDE.md` for Copilot agent / Codex / Cursor / Aider)
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
| `CLAUDE.md` | **Single source of truth** — conventions, architecture, common tasks, agentic workflow. Read directly by Claude Code and by Copilot's coding agent / CLI. |
| `FRAMEWORK-CONTEXT.md` | Cross-repo context: shared NuGet libraries, multi-tenancy conventions, dashboard contracts, cross-service patterns. Maintainer-curated; bootstrap populates the "Detected Framework Packages" section. |
| `AGENTS.md` | Pointer to `CLAUDE.md` for any agent-style tool (Copilot agent, Codex, Cursor, Aider). |
| `.github/copilot-instructions.md` | **Generated** — slim imperative ruleset (≤80 lines) for Copilot **inline completions** only. The agent reads `CLAUDE.md` directly. |
| `.github/prompts/*.prompt.md` | Copilot Chat workflows. Thin wrappers that delegate to `.claude/commands/`. |
| `.claude/commands/*.md` | Canonical workflow definitions (used by Claude Code natively, and by the Copilot prompt files). |
| `.claude/skills/*/SKILL.md` | Auto-discovered Common Tasks recipes (add-endpoint, add-entity, register-service). Body loads only when triggered. |
| `.claude/agents/*.md` | Subagents (convention-check, debt-radar, bootstrap-pass). Run in isolated context; return structured findings to the parent. |
| `.claude/workflow.md` | Shared self-review + flag-drift tail inlined by the workflow commands via `@.claude/workflow.md`. |
| `.claude/hooks/*.sh` | SessionStart context preload, UserPromptSubmit intent router, Stop-hook Boy Scout scanner. Bash; needs git-bash on Windows. |
| `.claude/settings.json` | Registers hooks: SessionStart, UserPromptSubmit, PostToolUse (`dotnet build` after `.cs` writes), and Stop. Claude Code only — Copilot has no hook system. |
| `TECH_DEBT.md` | **Generated** by `/bootstrap` — prioritised debt register with Trojan Horse opportunities. |
| `LEARNINGS.md` | Append-only log of what worked / what didn't / what rule changed. Read on non-trivial work. |
| `docs/playbook.md` | Methodology guide (the "why" behind the framework). |

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
| `SessionStart` | New session | Preloads branch, last 3 commits, `BOOTSTRAP_PENDING` warning, count of TECH_DEBT entries touching files modified in the last 14 days |
| `UserPromptSubmit` | Every prompt | Regex-classifies natural-language prompts as `fix`/`feature`/`refactor`/`test`/`design`/`debt`/`review` and injects that workflow's hard rules. Skips explicit `/command` invocations |
| `PostToolUse` (Write/Edit) | After every `.cs` write | Runs solution-level incremental `dotnet build` — catches compilation errors before they compound |
| `Stop` | End of every turn | Scans modified `.cs` files for the always-apply Boy Scout patterns (async without `CancellationToken`, interpolated logger calls, EF read queries without `AsNoTracking()`, excess null-forgiving `!`); soft-warns the model |

The router hook is the key piece: a developer who types *"the export endpoint is broken"* gets the `/fix` rails (regression-test-first, blast-radius Boy Scout) auto-injected without typing a slash command. Same for the other six workflows.

#### Hook compatibility

All hooks are bash scripts. Compatibility per platform:

| Platform | Status | Notes |
|----------|--------|-------|
| macOS (bash 3.2+) | Works out of the box | `git`, `grep`, `tr`, `printf`, `wc` are all default. |
| Linux | Works out of the box | Same as macOS. |
| Windows + Git for Windows (git-bash) | Works | Default installer puts `bash.exe` on PATH. Claude Code finds it automatically. |
| Windows + WSL only | Not recommended | Path translation between `/mnt/c/...` and Windows-style paths breaks the hooks. Install Git for Windows alongside WSL — Claude Code will pick up git-bash. |
| Windows + PowerShell only (no git-bash) | Works via PowerShell variant | Use the shipped PowerShell hooks. Copy `.claude/settings.windows.json` over `.claude/settings.json` (team-wide) or to `.claude/settings.local.json` (per-developer). Uses Windows PowerShell 5.1 — preinstalled on every Windows machine, no extra install. PowerShell 7 (`pwsh`) also works. |

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
Three subagents live in `.claude/agents/`:

| Agent | Purpose | Invoked by |
|-------|---------|-----------|
| `convention-check` | Audits a diff against CLAUDE.md > Conventions; returns a structured findings table. Read-only. | `/review` Step 1; ad-hoc |
| `debt-radar` | Maps a file path or feature area to TECH_DEBT entries; suggests trojan-horse bundles. Read-only. | `/review` Step 1; `/feature` Step 1; ad-hoc |
| `bootstrap-pass` | Runs a single bootstrap analysis pass (A1–A6) in isolation. Read-only. | `/bootstrap` Phase 1 (six in parallel) |

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

## Keeping it alive

- When conventions change: update `CLAUDE.md` and ask your agent (or `/generate-copilot`) to refresh `.github/copilot-instructions.md`
- Quarterly: run `/docs-sync` to find drift, or `/rebootstrap` for a deeper refresh
- Always: the Boy Scout Rule and Trojan Horse principle mean every change improves the codebase incrementally
