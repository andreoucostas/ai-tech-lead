# AI Tech Lead Framework — Angular

A working template that turns Claude Code and GitHub Copilot into a tech lead for your Angular codebase. Clone it, run one command, and get AI-driven development with built-in conventions, verification, and continuous improvement.

When repository evidence selects an Angular profile, the framework supports Angular 17+ defaults (standalone components, signals, new control flow, `inject()`, `takeUntilDestroyed`). `/bootstrap` detects the workspace and version before applying any Angular convention; an Angular distribution name is not evidence by itself.

## 1. For AI agents (LLMs)

If you are an AI agent reading this repository, start here.

**Your source of truth is [`CLAUDE.md`](./CLAUDE.md)** (Claude Code reads it directly) or its generated mirror **[`AGENTS.md`](./AGENTS.md)** (Copilot agent/CLI, Codex, Cursor, Gemini, Aider). Read that file before doing anything else — it defines the verification rules, conventions, SOLID/leanness constraints, and the step-by-step workflow you must follow.

**If you were asked to install this framework into a target codebase** — installation is a two-actor flow: you (the agent) copy files and commit; a **developer** must then run the populate command. Your task is not complete until you have handed off explicitly:
1. **Copy the files in:** `pwsh scripts/install.ps1 <target-repo-path>` (or `bash scripts/install.sh <target-repo-path>`). The installer detects the mode itself: **greenfield** (plain copy), **brownfield** (the target already has AI tooling — the originals its copy would overwrite are moved to `docs/pre-adoption/` and `.claude/adoption-pending.json` is written), or **update** (target already stamped with `.claude/framework-version.json` — protected consumer paths are restored, framework machinery is overwritten, and `.claude/settings.json` is backed up before refresh).
2. **Commit the copied files** in the target repo — they are team-shared config, not local settings.
3. **Hand off to the developer.** Populating is done by **`/adopt`** (brownfield — the installer wrote `.claude/adoption-pending.json`) or **`/bootstrap`** (greenfield). Both are **developer-initiated**: the model cannot invoke them, and they only exist inside a Claude Code session started in the target repo — so you cannot run them, and you must not try to replicate them by hand. End your run by telling the developer, verbatim: *"start a Claude Code session in `<target repo>` and type `/adopt`"* (or `/bootstrap`). Until that happens, the SessionStart hook warns every new session and `scripts/docs-sync-check` fails CI — expect that check to fail at this stage; it passes only after the developer has run the command.

**If you were asked to do development work in a repo that already has this installed:** follow the **Agentic Workflow** in `CLAUDE.md` — classify intent, post a plan and wait for go-ahead, execute in verified subtasks using repository-evidenced commands for the changed area, Boy Scout every touched file, self-review with a verification line. Trigger the matching skill in `.claude/skills/` when the task fits one.

Architecture: [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) · Reviewer's tour: [docs/REVIEW-GUIDE.md](./docs/REVIEW-GUIDE.md) · Full methodology: [docs/playbook.md](./docs/playbook.md).

## 2. What installing this gets you

No marketing. Each item is a concrete mechanism and the effect it produces.

1. **Less context burned per task — skills load on demand.** The Common-Task recipes (add-component, add-service, add-lazy-route, add-signal-store, …) ship as skills whose body loads *only when the task matches*. They don't sit in the prompt the way a monolithic CONVENTIONS doc would. You pay context for the one recipe in use, not all of them — main context stays lean.

2. **Less context burned per review — subagents run isolated.** `/review` and `/security-review` fan out to subagents (solid-check, convention-check, bloat-radar, debt-radar, test-critic, security-auditor) that each run in their own context window. Their file-reading and intermediate reasoning never enter the main conversation — the parent gets one structured findings table per agent, not the full transcript.

3. **One command instead of hours hand-writing the AI's context.** `/bootstrap` (or brownfield `/adopt`) first proves an Angular profile from Git-root evidence, runs only the applicable module, state, component, RxJS, API, and verification passes, then writes `CLAUDE.md`, `TECH_DEBT.md`, `AGENTS.md`, and `copilot-instructions.md`. You stop hand-authoring AI context — it's derived from the real codebase.

4. **The AI stops inventing your codebase.** Verification rules force it to confirm any component, service, route, selector, or npm package exists (via Read/Grep) before referencing it, and to honour version pinning — signals, `takeUntilDestroyed`, and the new control flow are version-gated, so it won't suggest them against a version that lacks them. Fewer hallucinated APIs means fewer wrong diffs and less rework.

5. **Fast type feedback on supported editor writes.** When the PostToolUse hook and interpreter are live, a `.ts` editor/file-write event runs `tsc --noEmit`; shell/external writes do not trigger it.

6. **Defined bad editor writes blocked deterministically.** On supported hosts with hooks available, the PreToolUse guard blocks editor/file-write events that add a suppression (`// eslint-disable`, `@ts-ignore`, `@ts-nocheck`) or a hardcoded secret. Shell/terminal writes are outside that event scope.

7. **Natural language routes to the right workflow — no slash commands to memorise.** Typing *"the export button is broken"* auto-injects the `/fix` rails (cause-first diagnosis, an evidenced regression test when a harness exists, blast-radius cleanup). The seven workflows are still available as explicit slash commands when you want deterministic routing.

8. **Common tasks carry explicit guardrails.** Skills encode repository-grounded recipes (for example, add-component follows the evidenced scaffold, routing, model, service, state, and verification patterns). The agent follows *your* recipe, not a generic one.

9. **Quality improves as a side effect of normal work.** The Boy Scout Rule cleans every file the agent touches — manual `ngOnDestroy` cleanup → `takeUntilDestroyed()`, nested subscribes flattened, `any` replaced with real types; the Trojan Horse principle bundles debt cleanup into feature and fix tickets; a leanness counterweight stops it adding abstraction you don't need. (Semantic changes like switching to `OnPush` are deliberately excluded from drive-by cleanup.) No dedicated debt sprints.

10. **Security is systematic, not heroic.** `/security-review` runs an OWASP-style pass (XSS via unsafe HTML binding, auth/route-guard gaps, secrets in source, sensitive data in logs or responses) on every change; findings land in `SECURITY_FINDINGS.md` with remediation SLAs.

11. **One authored rule source, surface-dependent delivery.** `CLAUDE.md`, its `AGENTS.md` mirror, and `copilot-instructions.md` carry the same framework rules where a client loads them; host support and hook enforcement still vary by surface.

12. **Built for any stack alongside Angular.** Path-scoped Copilot instructions (`applyTo:`) let a colocated .NET/Node/Python backend get its own rules while `.ts` files keep the Angular ones. One repo, correct rules per file type.

## Quick Start

### 1. Copy into your project
Copy the following into your existing repository's **Git root**. `angular.json` (or an exact-case Angular token in an Nx/project plugin/executor/generator/schematic/target-default field, or an exact-case `"@angular/core"` key in a `package.json` dependency map) is Angular evidence, not an installation-root requirement; a key/string elsewhere in a manifest is not:
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
docs/defaults.md                    → evidence-conditional Angular defaults (used only when Angular is evidenced, until /bootstrap runs)
docs/playbook.md                    → methodology guide
```

**Do not copy** `.template-repo` — it's a marker that exists only in this template repository to disable the CI guardrail here.

All of these files should be committed to version control — they're shared team configuration, not local settings.

> **Hook prerequisite — the interpreter wired in `.claude/settings.json` must resolve in the agent host.** The host may show the developer a launch-error notice, but this framework and the model do not recover the missing guard, feedback, or telemetry. The installer selects a PowerShell or bash twin for the installing machine; committed team config must work on every developer machine. VS Code agent hooks are Preview, off by default, org-gated, and the full lifecycle is not certified. See `docs/enforcement-surfaces.md` and verify with the actual-host canaries.
> Not sure what is live on your machine? Run `pwsh scripts/framework-doctor.ps1` or `bash scripts/framework-doctor.sh` once per developer machine.

### 2. Bootstrap (greenfield) **or** Adopt (existing setup)

If the repo has **no AI tooling yet**, run:
```
/bootstrap
```

If the repo **already has AI artifacts** (CLAUDE.md from another template, `.cursorrules`, Cursor rules, Copilot instructions, Aider/Continue config, generic ARCHITECTURE/CONVENTIONS/ADR docs, an existing TECH_DEBT register, etc.), run:
```
/adopt
```
`/adopt` discovers and screens everything. Clean mature architecture/ADR and wiki evidence keeps its project-owned path and bytes; other approved merge candidates are archived to `docs/pre-adoption/` before useful content is merged into CLAUDE.md + TECH_DEBT.md. It then runs `/bootstrap` to fill gaps. Nothing is deleted.

> **Installed by an AI agent?** The installer detects the brownfield case itself: it archives the artifacts its copy would overwrite to `docs/pre-adoption/` and writes `.claude/adoption-pending.json`. From then on, every new Claude Code session and every `docs-sync-check` run points at `/adopt` until a developer runs it. `/adopt` and `/bootstrap` are deliberately **not model-invocable** — an agent-driven install ends with a handoff message ("type `/adopt`"), never with the agent running or imitating the command.

Either command:
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
/feature [description]     — implement a feature at evidenced boundaries
/fix [description]         — diagnose and fix a bug (test when a harness exists)
/design [description]      — think through design before coding
/review                    — review changes as a tech lead
/security-review           — OWASP-style scan + senior judgement on auth, trust boundaries, secrets
/refactor [target]         — refactor with safety net
/test [target]             — generate tests following project patterns
/debt [area]               — find and fix tech debt
/docs-sync                 — check documentation for drift
/adopt                     — ingest existing AI-framework artifacts into this layout
/generate-copilot          — regenerate the slim copilot-instructions.md (for inline completions)
/impact                    — descriptive current-state metrics; not auto-run by /adopt and makes no A/B claim
```

In **Claude Code**, these are loaded from `.claude/commands/`. In **Copilot Chat**, the same names are loaded from `.github/prompts/` — those files are thin wrappers that delegate to the canonical `.claude/commands/*.md` files, so there's a single source of truth per workflow.

Or just describe what you want in natural language — `CLAUDE.md` teaches the agent to route to the right workflow automatically.

## Framework versioning

Each consumer repo records the template version it was last synced from. Two locations:
- A human-readable HTML comment at the top of `CLAUDE.md`
- A machine-readable `.claude/framework-version.json`

To pull template updates, re-run the installer from a fresh template checkout against your repo (`bash scripts/install.sh /path/to/your-repo` or `pwsh scripts/install.ps1 /path/to/your-repo`) — it detects the existing `.claude/framework-version.json` and switches to **update mode**. Preserve local edits to framework-owned files before running it, then review the resulting diff before committing. Update treats files in three ownership classes: the protected consumer paths named by the installer (`CLAUDE.md`, `AGENTS.md`, `TECH_DEBT.md`, `SECURITY_FINDINGS.md`, `LEARNINGS.md`, `FRAMEWORK-CONTEXT.md`, `.github/copilot-instructions.md`, `docs/ARCHITECTURE.md`, and `docs/architecture-decisions.md`) are restored; framework-owned machinery (hooks, commands, skills, scripts, and the JSON stamp) is overwritten; mixed-ownership `.claude/settings.json` is first backed up to `.claude/.state/settings.json.pre-update`, then refreshed and adapted to the host. Bump the CLAUDE.md header comment yourself as part of the update commit. CI tooling reads the JSON file to detect drift between your repo and the latest template version. If the version stamps disagree, treat the JSON file as authoritative. The update also refreshes `.github/instructions/framework-rules.instructions.md`. The update proves file arrival, not Copilot host consumption; see `docs/enforcement-surfaces.md` for dated, client-specific consumption evidence. Existing Claude Code consumers must once add `@.github/instructions/framework-rules.instructions.md` to `CLAUDE.md` where the four inline framework sections were, then delete those old sections. Until then, `session-start` provides discovery only. The carrier is framework-owned: update deliberately overwrites consumer edits to it. Boy Scout content remains consumer-owned after bootstrap, so future scaffold changes to it are greenfield-only.

## What's in the box

| File | Purpose |
|------|---------|
| `CLAUDE.md` | **Single source of truth** (authored) — conventions, architecture, common tasks, agentic workflow. Read directly by Claude Code. Copilot/Codex/Cursor read its generated mirror `AGENTS.md`. |
| `FRAMEWORK-CONTEXT.md` | Cross-repo context: shared npm libraries, multi-tenancy conventions, dashboard contracts, cross-service patterns. Every section is drafted by `/bootstrap` from the repo's code (cross-repo facts the code can't show are explicitly left to maintainers); "Detected Framework Packages" is also refreshed by `/docs-sync`; "Known Hazard Areas" by `/rebootstrap`. |
| `AGENTS.md` | **Generated** — full mirror of CLAUDE.md's portable rules (Verification, Leanness, Conventions, Boy Scout, Agentic Workflow) so AGENTS.md-native tools (Copilot agent mode & CLI, Codex, Cursor, Gemini, Aider) get the real ruleset, not a pointer. Refreshed by `/generate-copilot`. |
| `.github/copilot-instructions.md` | **Generated** — slim imperative ruleset (≤80 lines) for Copilot **inline completions** only. Agent-mode tools read the fuller `AGENTS.md`. |
| `.github/prompts/*.prompt.md` | Copilot Chat workflows. Thin wrappers that delegate to `.claude/commands/`. |
| `.claude/commands/*.md` | Canonical workflow definitions (used by Claude Code natively, and by the Copilot prompt files). |
| `.claude/skills/*/SKILL.md` | Auto-discovered Common Tasks recipes (add-component, add-service, add-lazy-route, add-signal-store, add-tests, dependency-audit, create-adr, enforce-architecture, enforce-standards). Body loads only when triggered. Mirrored to `.github/skills/` for Copilot. |
| `.claude/agents/*.md` | Subagents (security-auditor, solid-check, convention-check, bloat-radar, debt-radar, test-critic, bootstrap-pass). Run in isolated context; return structured findings. The six user-facing ones are mirrored to `.github/agents/*.agent.md` as Copilot custom agents. |
| `.claude/workflow.md` | Shared self-review + flag-drift tail inlined by the workflow commands via `@.claude/workflow.md`. |
| `.claude/hooks/*.sh` | SessionStart context preload, UserPromptSubmit intent router, **PreToolUse guard** (blocks warning-suppressions & secrets), PostToolUse type-checker, Stop Boy Scout scanner. Each has a `.ps1` twin for Windows-only teams. |
| `.claude/settings.json` | Registers hooks for Claude Code: SessionStart, UserPromptSubmit, PreToolUse (`guard` before `.ts` writes), PostToolUse (`tsc --noEmit` after `.ts` writes), and Stop. |
| `.github/hooks/hooks.json` | Registers the same hooks for Copilot cloud agent and CLI (on Bitbucket, the CLI surface only). Points to the same scripts in `.claude/hooks/`. |
| `.github/skills/`, `.github/agents/` | **Generated** Copilot-facing mirrors: `.github/skills/` is a byte-identical copy of `.claude/skills/` (via `scripts/sync-agent-files.*`); `.github/agents/*.agent.md` wrap the subagents as Copilot custom agents. |
| `scripts/` | Host-agnostic helpers include `metrics.{sh,ps1}`; `ci/` contains dependency-cruiser scaffolding to wire in consumer CI. |
| `specs/` | Persistent feature specs (spec-driven development). `/design` writes one, `/feature` implements against it, `/review` verifies. See `specs/README.md`. |
| `docs/impact/` | Optional descriptive metrics; no executable A/B harness or comparative report. |
| `TECH_DEBT.md` | **Generated** by `/bootstrap` — prioritised debt register with Trojan Horse opportunities. |
| `LEARNINGS.md` | Append-only log of what worked / what didn't / what rule changed. Read on non-trivial work. |
| `docs/playbook.md` | Methodology guide (the "why" behind the framework). |
| `docs/ARCHITECTURE.md` (+ `architecture.html`) | Canonical architecture map with Mermaid diagrams; HTML is the generated, drift-checked view for reviewers. |
| `docs/REVIEW-GUIDE.md` | A senior reviewer's annotated tour — reading order, what each piece guarantees, how to verify, and the tradeoffs. |
| `docs/presentation/` | Self-contained offline presentations: the persuasive `framework-briefing.html` + `TALKING-POINTS.md`, the implementation-level `framework-technical.html`, and the printable one-page `framework-system-map.html`. |

## How it works

Every workflow command follows the same execution model:
1. **Plan** before coding (CLAUDE.md is auto-loaded — no need to re-read)
2. **Execute in verified subtasks** (run only applicable repository-evidenced checks after each; report unavailable categories)
3. **Boy Scout** every touched file
4. **Self-review** against conventions (shared `@.claude/workflow.md` tail)
5. **Flag drift** in documentation

### Deterministic hooks
| Hook | When | What it does |
|------|------|--------------|
| `SessionStart` | New session | Preloads branch, last 3 commits, the adoption-pending warning (`.claude/adoption-pending.json` present → steer to `/adopt`, not `/bootstrap`) or the `BOOTSTRAP_PENDING` warning, the workflow-routing primer, and the count of TECH_DEBT entries touching files modified in the last 14 days |
| `UserPromptSubmit` | Every prompt | Regex-classifies natural-language prompts as `fix`/`feature`/`refactor`/`test`/`design`/`debt`/`review` and injects that workflow's hard rules. Skips explicit `/command` invocations. Copilot CLI ≥ v1.0.65 supports `additionalContext`; single-entry delivery was observed on CLI 1.0.80 (2026-08-18). VS Code Preview hooks register the documented shape, but live `userPromptSubmitted` consumption remains unverified, so `AGENTS.md` self-classification is the fallback there. |
| `PreToolUse` (Write/Edit) | Supported `.ts` editor/file-write events | Blocks defined suppression and secret patterns when the registered hook and interpreter are live. Shell writes are outside the event scope. |
| `PostToolUse` (Write/Edit) | Supported `.ts` editor/file-write events | Runs `tsc --noEmit` and appends mutable local telemetry when the hooks are live. |
| `Stop` / `agentStop` | End of a write turn | Scans modified `.ts` files for the always-apply Boy Scout patterns (manual `ngOnDestroy` + `subscribe`, nested `subscribe`, `any`, commented-out code blocks); soft-warns the model. `OnPush` is intentionally excluded — switching a component to `OnPush` is a semantic change, not a drive-by cleanup. Claude Code uses `Stop`. Copilot CLI documents `agentStop` from 1.0.72 and the framework registers it, but live firing and the resulting queue write remain unverified; only the separate next-prompt delivery leg was observed on CLI 1.0.80. VS Code Preview-hook event spelling, firing, and delivery remain unverified. |

The router is the key piece. **In Claude Code**, a developer who types *"the export button is broken"* gets the `/fix` rails (cause-first diagnosis, an evidenced regression test when a harness exists, blast-radius Boy Scout) auto-injected per-prompt, without typing a slash command. **In Copilot CLI**, the same single-entry injection was observed on 1.0.80; `AGENTS.md` self-classification is the fallback on older or unavailable hooks. VS Code's Preview-hook prompt lifecycle remains unverified. Either way, the seven workflows are also invokable explicitly as slash commands (`/feature`, `/fix`, …) for deterministic routing.

#### Hook compatibility

The same hook logic ships as bash and PowerShell twins across three client surfaces, with different certification:

| Surface | Config file | Payload shape | Notes |
|---------|-------------|---------------|-------|
| **Claude Code** (CLI + VS Code extension) | `.claude/settings.json` | `tool_name` ∈ {`Write`,`Edit`}; `tool_input.file_path` | Native hook support with `matcher` field — hooks already filtered by tool name before the script runs. |
| **GitHub Copilot CLI** | `.github/hooks/hooks.json` | `toolName` ∈ {`edit`,`create`}; `toolArgs.filePath` | Capability-specific evidence: single-entry prompt delivery on CLI 1.0.80 (2026-08-18) and post-tool context on 1.0.80 (2026-08-20); the registered `agentStop` path is unverified. Folder trust and interpreter resolution are prerequisites. |
| **Copilot in VS Code** | `.github/hooks/hooks.json` | VS Code tool payload | Preview, off by default, org-gated. One guard deny was observed on 2026-06-25, but host/extension versions were not recorded; prompt, post-tool, and Stop lifecycles remain unverified. |

Hook interpreter by platform. **Windows and Linux are supported and release-tested; macOS is unsupported and untested.** Claude Code's `settings.json` defaults to the PowerShell (`pwsh`) twins — so hooks fire on Windows without git-bash (the old bash default silently no-opped there). The installer adapts the interpreter on supported hosts, so this is automatic:

| Platform | Hook interpreter | Notes |
|----------|------------------|-------|
| Windows + PowerShell 7 (`pwsh`) | `pwsh` (default) | Works out of the box — no git-bash required. |
| Windows, no `pwsh` | Windows PowerShell 5.1 | `install.ps1` auto-activates `settings.windows.json` (5.1 is preinstalled on every Windows box). |
| Windows + Git for Windows (git-bash) | `pwsh`, or bash if preferred | Run `install.sh` under git-bash to switch to the bash twins. `.gitattributes` pins `*.sh` to LF so CRLF can't break them. |
| Linux + `pwsh` | `pwsh` (default) | Works out of the box. |
| Linux, no `pwsh` | bash | `install.sh` switches to the bash twins (`git`, `grep`, `tr`, `printf`, `wc` are all default). |
| macOS | — | Unsupported and untested; incidental compatibility is not a release contract. |
| Windows + WSL only | — | Not recommended: `/mnt/c/...` path translation breaks the hooks. Install Git for Windows or PowerShell alongside WSL. |

> GitHub Copilot's `.github/hooks/hooks.json` already declares both a `bash` and a `powershell` command per hook and picks per-OS, so Copilot is unaffected — this change brings Claude Code to parity on Windows.

**Verify your setup** after copying the template into your repo:

```bash
# Bash version (Linux / Windows + git-bash):
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
Seven subagents live in `.claude/agents/` — the six user-facing ones are mirrored to `.github/agents/*.agent.md` as Copilot custom agents:

| Agent | Purpose | Invoked by |
|-------|---------|-----------|
| `security-auditor` | OWASP-style scan of a diff (XSS/unsafe DOM sinks, auth/route guards, secrets, sensitive-data exposure, vulnerable deps). Read-only. | `/security-review`; ad-hoc |
| `solid-check` | Audits a diff against the framework rules (`.github/instructions/framework-rules.instructions.md` › SOLID; `AGENTS.md` › SOLID on AGENTS.md-native tools) — the five principles (an abstraction/token per injected service). Read-only. | `/review` Step 1; ad-hoc |
| `convention-check` | Audits a diff against CLAUDE.md > Conventions; returns a structured findings table. Read-only. | `/review` Step 1; ad-hoc |
| `bloat-radar` | Flags speculative abstractions, shallow service wrappers, parallel implementations, single-use pipes/directives, comment debris. Read-only. | `/review` Step 1; ad-hoc |
| `test-critic` | Audits the spec changes for integrity — would each spec fail if the code under test broke? Flags over-mocking, tautological/weak expectations, missing paths, nondeterminism. Read-only. | `/review` Step 1; ad-hoc |
| `debt-radar` | Maps a file path or feature area to TECH_DEBT entries; suggests trojan-horse bundles. Read-only. | `/review` Step 1; `/feature` Step 1; ad-hoc |
| `bootstrap-pass` | Runs a single bootstrap analysis pass (A1–A7) in isolation. Read-only. | `/bootstrap` Phase 1 (seven in parallel) |

Subagents run in isolated context — analysis chatter does not pollute the parent's main conversation. The parent receives one structured message per subagent and synthesises.

All repository-evidenced verification commands run inside command workflows, not as hooks — they're too slow for per-write execution.

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

The intent is that `.ts` files see the Angular rules from `copilot-instructions.md`, `.cs` files see the .NET rules from `.github/instructions/csharp.instructions.md`, and the repo-wide rules apply on top of either.

> **Verify this actually reaches your agent before relying on it.** Path-scoped instruction files are the mechanism Microsoft documents for VS Code agent mode, but **we have not been able to confirm delivery on any surface we can test**, and a scoped file that does not reach the model **fails silently** — it installs correctly, the agent simply never receives it, and nothing distinguishes that from working.
>
> What we measured, on **Copilot CLI 1.0.80 in `-p` mode**: a narrow `applyTo` delivered **nothing at all**, even with a matching file present and named in the prompt. That held for `"**/*.cs"`, `"**/*.ts"`, `"**/*.{ts,html}"` and `"**/*.ts,**/*.html"` alike — so it is the *narrowness*, not the brace or comma syntax, that defeated delivery. Only `applyTo: "**"` was observed to arrive. **VS Code agent mode — the surface this advice is aimed at — remains unverified.**
>
> The cheap check: put a distinctive marker in the scoped file ("begin every reply about this file with WIDGET"), open a matching file, and ask your agent about it. If the marker comes back, that is positive evidence of delivery and instruction-following for that run. If it does not, the result is inconclusive: delivery, instruction-following, or observation may have failed. Absence neither proves non-delivery nor makes repo-wide `copilot-instructions.md` the only reliable carrier.

If the secondary stack is .NET, consider installing the **monorepo** distribution instead — it carries both stacks' rails and dispatches per file type. Failing that, the .NET distribution's `copilot-instructions.md` content is a sensible starting point: copy it into a `.github/instructions/csharp.instructions.md` file and add `applyTo: "**/*.cs"` at the top.

## Running on Bitbucket Data Center

This framework grew up around GitHub conventions, but its **local layer is host-agnostic** — it behaves the same whether your remote is GitHub, Bitbucket Cloud, or **Bitbucket Data Center / Server**. Only the *cloud-automation* layer is GitHub-specific. Here's precisely what applies on a self-hosted Bitbucket repo.

### Local files, subject to client prerequisites
- **GitHub Copilot in the IDE** (VS Code / JetBrains) can read its working-tree instruction carriers regardless of git host. That does not certify Preview VS Code hooks; enable them where permitted and run the canaries before relying on enforcement.
- **Claude Code** (CLI + IDE extension) — reads `CLAUDE.md` and everything under `.claude/`. Host-agnostic.
- **GitHub Copilot CLI** — capability-specific observations, not a blanket certificate: single-entry prompt delivery on CLI 1.0.80 (2026-08-18) and post-tool context on 1.0.80 (2026-08-20). Other registered events, including `agentStop`, require their own live evidence; folder trust and interpreter resolution remain prerequisites.
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
**Every repo using this framework is expected to wire one required build in its own CI (Bamboo/Jenkins/TeamCity) that gates PR merges.** The full recipe — the shipped `scripts/docs-sync-check.sh`/`.ps1` framework-state check plus only the code gates evidenced by this repository (or an explicit `not available` gap), Bamboo and Jenkins configurations, and how to make it blocking via Bitbucket DC's *required builds* merge check (repo-admin only, no server plugins) — lives in **[docs/ci-integration.md](./docs/ci-integration.md)**.
- **Also enable** Bitbucket DC's native **secret scanning** (8.12+, push-time blocking — zero custom code).
- **Optionally surface it on the PR** via the **Code Insights REST API** (`/rest/insights/1.0/...`); cosmetic on top of required builds, not a substitute.
- **Bitbucket Cloud** repos: copy `scripts/ci/bitbucket-pipelines.example.yml` into `bitbucket-pipelines.yml`.

### Standing scanners on Bitbucket
- **Dependencies**: Dependabot is GitHub-only — when committed package manifests evidence an applicable ecosystem, use **Renovate** (self-hostable) or the exact CI fallback derived by `dependency-audit`; otherwise record dependency scanning as `not available`.
- **SAST**: CodeQL is GitHub-only — configure **Semgrep**, **SonarQube**, or another existing scanner only for repository-evidenced languages, then publish via Code Insights.

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
