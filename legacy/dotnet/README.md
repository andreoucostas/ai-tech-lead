# AI Tech Lead Framework — .NET C#

A working template that turns Claude Code and GitHub Copilot into a tech lead for your .NET codebase. Clone it, run one command, and get AI-driven development with built-in conventions, verification, and continuous improvement.

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
/refactor [target]         — refactor with safety net
/test [target]             — generate tests following project patterns
/debt [area]               — find and fix tech debt
/docs-sync                 — check documentation for drift
/adopt                     — ingest existing AI-framework artifacts into this layout
/generate-copilot          — regenerate the slim copilot-instructions.md (for inline completions)
```

In **Claude Code**, these are loaded from `.claude/commands/`. In **Copilot Chat**, the same names are loaded from `.github/prompts/` — those files are thin wrappers that delegate to the canonical `.claude/commands/*.md` files, so there's a single source of truth per workflow.

Or just describe what you want in natural language — `CLAUDE.md` teaches the agent to route to the right workflow automatically.

## What's in the box

| File | Purpose |
|------|---------|
| `CLAUDE.md` | **Single source of truth** — conventions, architecture, common tasks, agentic workflow. Read directly by Claude Code and by Copilot's coding agent / CLI. |
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
