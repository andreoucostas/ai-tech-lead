# ai-tech-lead-dotnet — Changelog

> Framework-level changes for the .NET template. Per-stack Angular changes live in [`ai-tech-lead-angular/CHANGELOG.md`](https://github.com/andreoucostas/ai-tech-lead-angular/blob/master/CHANGELOG.md).
> Architecture decisions (cross-stack) live in `project_framework_architecture.md`.

## 0.9.0 — 2026-06-04 (literal SOLID)

### Added
- **SOLID is now mandatory** — a standing `## SOLID` section in CLAUDE.md (mirrored to AGENTS.md): an interface for **every injected service** (DIP), plus SRP / OCP / LSP / ISP rules. Literal classic SOLID, per tech-lead mandate. Data carriers (DTOs, entities, value objects, `Options`) are exempt — they are not services.
- **`solid-check` subagent** (`.claude/agents/` + `.github/agents/` mirror), dispatched by `/review` Step 1 alongside convention-check / bloat-radar / debt-radar. Covers the five principles semantically; self-skips in repos without a `## SOLID` section.
- **`docs/architecture-decisions.md`** is now the home for full ADRs; `docs/defaults.md` DI section mandates interface-per-service for greenfield.

### Changed
- **Leanness #2 reconciled with SOLID**: interfaces are now expected for injected services; the anti-bloat teeth remain on *data* (never interface a DTO/entity/value object) and on *speculation* (no abstractions for hypothetical variation).
- **`bloat-radar` recalibrated**: it no longer flags a single-implementation interface on an injected service (required by DIP now); it still flags interfaces/abstractions on non-service types, speculative bases, and helper classes. The SOLID lens moved to `solid-check`.
- **`/generate-copilot`** now emits a SOLID block into `copilot-instructions.md` and copies the full SOLID section into the `AGENTS.md` mirror.
- **Eval suite** flipped to the new policy: `dotnet-001` now requires `IEmailNotifier`; `dotnet-004` requires `ISmsService` **and** still forbids a speculative provider factory (DIP yes, future-proofing no).

### Fixed
- **`/adopt` ADR merge** now appends full ADRs to `docs/architecture-decisions.md` with a one-line index in CLAUDE.md (was pasting them inline), matching the `create-adr` skill and `/bootstrap` Phase 3a — keeps CLAUDE.md within budget and the prompt cache warm.

### Note
- Deterministic DIP backstop is **NetArchTest** (dependency-direction tests in CI); the semantic SOLID gate is the `solid-check` agent. Wire NetArchTest into your test project to fail builds on layer violations.

## 0.8.0 — 2026-06-04 (cross-tool parity + Bitbucket + spec-driven)

### Added
- **AGENTS.md is now a generated full mirror** of CLAUDE.md's portable rules (Verification, Leanness, Conventions, Boy Scout, Agentic Workflow) — not a pointer — so AGENTS.md-native tools (GitHub Copilot agent mode & CLI, Codex, Cursor, Gemini, Aider) get the real ruleset. Emitted by `/generate-copilot` Part B; produced by `/bootstrap` Phase 3f; checked for drift by `/docs-sync` Step 2 and the CI guardrail.
- **Skills now reach Copilot.** `.claude/skills/` is mirrored byte-for-byte to `.github/skills/` (Copilot CLI / cloud agent read that path; VS Code Copilot already reads `.claude/skills/`). New `scripts/sync-agent-files.{sh,ps1}` regenerates the mirror, `/generate-copilot` Part C runs it, and the CI guardrail enforces parity.
- **Subagents exposed to Copilot** as custom agents: `.github/agents/{security-auditor,convention-check,bloat-radar,debt-radar}.agent.md` — thin wrappers delegating to the canonical `.claude/agents/` definitions (same single-source pattern as the prompt files).
- **PreToolUse guard hook** (`guard.sh` + `.ps1`) — hard-blocks any write that adds `#pragma warning disable` or a hardcoded secret (private key, cloud token, credential literal). Registered in `.claude/settings.json`, `.claude/settings.windows.json`, and `.github/hooks/hooks.json` (Claude Code: exit-2 block; Copilot: JSON deny). Deterministic enforcement of Verification Rule #7.
- **Spec-driven development**: a `specs/` directory with `specs/README.md` (template + lifecycle). `/design` persists a spec to `specs/<slug>.md`, `/feature` implements against it, `/review` verifies conformance. CLAUDE.md is framed as the project "constitution".
- **New skills**: `add-tests` (xUnit + `WebApplicationFactory`), `dependency-audit` (vulnerable NuGet + Dependabot/Renovate setup), `create-adr` (inline ADRs in CLAUDE.md > Architecture Decisions).
- **Bitbucket Data Center support**: a README "Running on Bitbucket Data Center" section (what works locally vs what's GitHub-only — incl. Atlassian Rovo Dev being Cloud-only); host-agnostic `scripts/docs-sync-check.{sh,ps1}`; `scripts/ci/bitbucket-pipelines.example.yml`; and Code Insights / pre-receive / Bamboo wiring guidance. `/security-review` gains a "Standing scanners" note (CodeQL on GitHub; Semgrep/SonarQube + Code Insights on Bitbucket).

### Fixed
- **A7 bootstrap pass was dead.** `/bootstrap` dispatched seven passes (incl. **A7 Financial Domain Invariants**) but `bootstrap-pass` only accepted A1–A6 and Phase 2 synthesised "six" — so the financial-domain analysis silently never ran. `bootstrap-pass`, Phase 2, the README agents table, and the `/bootstrap` + `/rebootstrap` prompt wrappers now all agree on **seven (A1–A7)**.

### Changed
- `.github/workflows/docs-sync-check.yml` is now a thin caller of `scripts/docs-sync-check.sh` (host-agnostic) and is marked GitHub-only. The script also verifies the AGENTS.md mirror is current and that `.github/skills` matches `.claude/skills`.
- `/generate-copilot` now regenerates **both** `.github/copilot-instructions.md` (slim) and `AGENTS.md` (full mirror), and syncs the skills mirror.

### Token economy
- **Model routing**: `convention-check`, `bloat-radar`, and `debt-radar` now run on **Haiku** (recurring, pattern-based work); `security-auditor` and `bootstrap-pass` stay on the inherited strong model (high-stakes / one-time-high-leverage). Cuts per-`/review` cost without losing security or bootstrap quality.
- **Quiet-on-success hooks**: `post-write.{sh,ps1}` emit `dotnet build` output **only on failure** — a successful write no longer injects a build summary into context.
- **CLAUDE.md size budget**: `docs-sync-check.{sh,ps1}` prints an advisory NOTE when CLAUDE.md exceeds ~400 lines (it loads on nearly every turn and anchors the prompt cache); `/bootstrap` Phase 3a documents the budget.
- **ADRs out of the hot path**: the `create-adr` skill now appends full ADRs to `docs/architecture-decisions.md` with a one-line index in CLAUDE.md, instead of pasting them inline — stops the always-loaded file from growing and avoids busting the prompt cache on every recorded decision. `/bootstrap` Phase 3a follows the same split.

## 0.7.2 — 2026-05-16 (Copilot routing parity)

### Fixed
- **Natural-language routing in Copilot was a silent no-op.** Per the [GitHub Copilot hooks reference](https://docs.github.com/en/copilot/reference/hooks-configuration), the `userPromptSubmitted` event is fire-and-forget — stdout is discarded, so `route-prompt.sh|ps1` couldn't inject workflow rails on the Copilot side regardless of schema correctness. Removed the misleading `userPromptSubmitted` entry from `.github/hooks/hooks.json`.

### Added
- **Workflow-routing primer in `SessionStart`** (both `session-start.sh` and `session-start.ps1`). Once per session, the hook emits the seven workflow names with their trigger vocabulary so the model can self-classify natural-language prompts in Copilot. In Claude Code the per-prompt `route-prompt` router still runs and dominates; the primer is harmless reinforcement there.

### Changed
- **README "Deterministic hooks" table** now flags `UserPromptSubmit` and `Stop` as Claude Code only and distinguishes per-prompt routing (Claude Code) from session primer + self-classification (Copilot).

## 0.7.1 — 2026-05-15 (hook plumbing forensic-fix batch)

### Fixed
- **`.claude/settings.json` hook schema** (both bash and PowerShell variants). Restructured to the documented Claude Code form: each event entry now wraps handlers in a nested `hooks` array with explicit `"type": "command"`. The previous flattened form was non-conformant and likely failed to register hooks on recent Claude Code versions.
- **`.github/hooks/hooks.json` schema**. Added the required `"version": 1` field; converted the top-level `hooks` from an array to an object keyed by event name; added `"type": "command"` to every handler; added `timeoutSec` per event. The prior shape did not match the GitHub Copilot hooks reference and the hooks almost certainly weren't being loaded by the cloud agent.
- **Tool-name filter in hook scripts** (`post-write.{sh,ps1}`, `audit-trail.{sh,ps1}`). The filter previously accepted only Claude Code's `Write`/`Edit` (PascalCase); GitHub Copilot uses `edit`/`create` (lowercase). Every Copilot file-write event was being silently dropped before path extraction. Filter now accepts both surfaces.
- **`toolArgs` parsing** in the same scripts. Per the Copilot hooks spec, `toolArgs` is a parsed object, not a JSON-encoded string. The previous `jq fromjson` / `ConvertFrom-Json` paths threw and were silently swallowed by `2>/dev/null`, so file-path extraction from Copilot payloads returned empty. Switched to direct object access, with a fallback string-parse for legacy payload shapes.
- **Prompt-file frontmatter** — `mode: agent` → `agent: agent` across all 13 `.github/prompts/*.prompt.md` files. `mode` was deprecated by VS Code in favor of `agent` (see `github/awesome-copilot#464`).
- **`settings.windows.json` audit-trail parity** — the bash variant registered two `PostToolUse` hooks (post-write + audit-trail); the PowerShell variant only registered post-write, so Windows-only PowerShell teams had no SR 11-7 / DORA audit log. Added the audit-trail handler.
- **Bogus `$schema` URL** in `framework-version.json`. Removed — the URL pointed to a non-existent GitHub org.
- **Tracked runtime state** — removed `.claude/.state/last-build-ts` from the working tree. It is gitignored but had been committed before the rule was added.
- **`post-write` throttle window** — raised from 5 s to 60 s. Real `dotnet build` runs take 30 s+; the 5 s throttle expired long before the in-flight build finished, so burst writes still stomped on the running compile.
- **Boy-scout `!` (null-forgiving) detector** false-positive on `x!=y` (no surrounding spaces). Now requires the `!` to be in postfix-operator position.

### Changed
- **README hook-compatibility table**. The "VS Code Copilot reads `.claude/settings.json` directly" row was unfounded — VS Code Copilot's surfaces are `.github/copilot-instructions.md`, `.github/instructions/`, `.github/prompts/`, and `.github/hooks/`. The table is now two rows: Claude Code (CLI + VS Code extension) and GitHub Copilot (cloud + CLI), with the exact payload shape per surface.

### Added
- **Cleanly bail-out guard** in `post-write`: skip if the `dotnet` CLI is not on PATH, instead of failing noisily.

## 0.5.0 — 2026-04-28 (anti-bloat batch)

### Added
- **Leanness conventions** in `CLAUDE.md`. Counterweight to Boy Scout's add-bias: no interface without a second consumer, wrappers must add behavior, prefer editing over creating, deletion is a contribution.
- **`bloat-radar` subagent**. Scans diffs for speculative abstractions, shallow wrappers, parallel implementations, comment debris, defensive over-coding, trivial tests, and net-LOC density. Wired into `/review` alongside `convention-check` and `debt-radar`.
- **Anti-bloat rails** appended to `feature` and `refactor` workflow rails (route-prompt bash + PowerShell). Refactor now reports net LOC delta; growth requires explicit reason.
- **Boy Scout: Subtract** subsection in `CLAUDE.md`. Always-apply subtractions (unused usings, commented-out blocks, unreferenced privates) and primary-target subtractions (inline single-consumer interfaces, collapse shallow wrappers).
- **Stop hook** (`boy-scout-check.sh` + `.ps1`) now flags commented-out code blocks (2+ contiguous code-like `//` lines).
- **`/security-review` command + `security-auditor` subagent**. OWASP-style scan: injection / XSS / auth-authz / secrets / sensitive data / crypto / transport / dependencies. Wired into Copilot via `.github/prompts/security-review.prompt.md`.
- **Eval harness** (`tests/evals/`). Tiny regression suite that probes the rules CLAUDE.md + FRAMEWORK-CONTEXT.md encode (Verification, Leanness, Boy Scout, no future-proofing, no defensive over-coding). Two grading layers per case: deterministic regex + Haiku-graded rubric. Uses prompt caching with a `cache_control` breakpoint at end of CLAUDE.md so subsequent cases hit cache. Five cases, run quarterly or after framework version bumps.

### Changed
- `/feature` Step 1 includes a Leanness check before scoping the work.
- `/refactor` Step 7 now requires reporting net LOC delta.

## 0.4.0 — 2026-04-28

### Added
- **PowerShell hook variants** for Windows-only PowerShell teams. Ships `.ps1` equivalents of `session-start`, `route-prompt`, `boy-scout-check`, `post-write`, and `audit-trail` alongside the bash versions, plus a `settings.windows.json` users can swap into `.claude/settings.json` (or `.claude/settings.local.json`). Uses Windows PowerShell 5.1 — preinstalled on every Windows machine, no extra install. (Resolves the "hooks disabled on PowerShell-only Windows" caveat in the README compatibility table.)
- **`FRAMEWORK-CONTEXT.md` template**. Cross-repo context file for shared library APIs, multi-tenancy conventions, dashboard contracts, and cross-service patterns. Maintainer-curated; bootstrap auto-populates the "Detected Framework Packages" table from `*.csproj` / `Directory.Packages.props`. CLAUDE.md still wins on conflicts; agent flags contradictions.
- **`/bootstrap` Phase 3d**: detects framework packages and populates `FRAMEWORK-CONTEXT.md > Detected Framework Packages`. Removes the `DETECTED_FRAMEWORK_PACKAGES_PENDING` marker on success.
- **`/docs-sync` Step 4**: re-scans for framework package add/remove/version-bump and flags drift in FRAMEWORK-CONTEXT.md.
- **CI guardrail check**: `docs-sync-check.yml` now verifies `FRAMEWORK-CONTEXT.md` exists and the bootstrap marker has been removed.

### Fixed
- **`route-prompt.sh` JSON parsing** no longer truncates on prompts containing escaped quotes (`\"`). Now prefers `jq` (handles all JSON escapes), falls back to `python3` / `python`, and finally to a regex that decodes common escapes. Same fix applied to the PowerShell variant via `ConvertFrom-Json`.

### Decided
- **Multi-repo architecture (Option B chosen)**: framework context is baked into each template via `FRAMEWORK-CONTEXT.md` rather than a central `ai-framework-context` repo. Self-contained repos avoid the unverified `--add-dir` mechanism and the silent-failure onboarding risk. Drift mitigated by `/docs-sync` and the CI guardrail. See `project_framework_architecture.md` for the full rationale.

---

## How to update this changelog

- One section per release (or per "Unreleased" working window). Date the heading.
- Group entries by **Added / Changed / Fixed / Removed / Decided**.
- One line per change. Reference the file or workflow touched, not the implementation detail.
- Keep entries scoped to this template. Cross-stack decisions go in `project_framework_architecture.md`; the sibling Angular template tracks its own changes in [`ai-tech-lead-angular/CHANGELOG.md`](https://github.com/andreoucostas/ai-tech-lead-angular/blob/master/CHANGELOG.md).
- When a framework-level change lands in both templates, write the entry separately in each — they'll diverge in detail (file paths, language idioms) and shared editing tends to drift anyway.
