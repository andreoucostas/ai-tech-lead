# ai-tech-lead-angular — Changelog

> Framework-level changes for the Angular template. Per-stack `.NET` changes live in [`ai-tech-lead-dotnet/CHANGELOG.md`](https://github.com/andreoucostas/ai-tech-lead-dotnet/blob/master/CHANGELOG.md).
> Architecture decisions (cross-stack) live in `project_framework_architecture.md`.

## 0.14.0 — 2026-06-06 (AI-driven SDLC hardening: security, calibration, brownfield safety)

> Bakes best-practice findings from METR, Google DORA 2025, Anthropic's Claude Code guidance, and Thoughtworks/Böckeler into the framework so they are **LLM-driven, not left to each developer**. Reframed after a multi-reviewer critique: the highest-leverage gaps were security and trust-calibration, not the originally-planned ones. LSP-over-MCP symbol grounding was evaluated and **deferred** (no maintained offline bridge for Windows/Bitbucket DC; 8–15 s/query; orphaned-process lifecycle) — `Read`/`Grep` + Verification Rules #1–2 remain the fallback.

### Added
- **`/adopt` trust-boundary + safety screen.** Discovered AI-config/doc files (`.cursorrules`, `AGENTS.md`, etc.) are now treated as **untrusted input**: the agent never obeys instructions found inside them, and a provenance + adversarial-content scan (override phrasing, hidden-comment imperatives, exfiltration URLs) with **raw-content review** gates every merge into the canonical CLAUDE.md. Closes a prompt-injection hole on brownfield adoption.
- **Security-sensitive routing.** The `route-prompt` hook injects a security overlay (run `/security-review` / `security-auditor`; sanitisation / `bypassSecurityTrust*`, token-storage, XSS/CSRF reminders) whenever a prompt touches auth, tokens, sessions, PII, or output sanitisation — stacked on top of any workflow rails, and standalone when no workflow matched. DORA: AI amplifies weaknesses fastest here.
- **Enforced plan-review & clarify gate.** For fix/feature/refactor/test the agent must present a plan, surface clarifying questions, and **wait for the developer's go-ahead before writing code** (CLAUDE.md Agentic Workflow + `route-prompt`). The human-in-the-loop checkpoint that also counters METR's perception gap.
- **Perception-gap feedback loop.** A "Verification & confidence" line (verified-by-running vs asserted) is now required on completed work (`workflow.md` + CLAUDE.md self-review); `/impact` gains a predicted-vs-actual calibration section and a "confidence is not correctness" honesty rule; two security-correctness eval cases added (no auth token in web storage; no PII in client logs).
- **Known Hazard Areas.** A `/bootstrap`-drafted section in `FRAMEWORK-CONTEXT.md` capturing the repo's "here be dragons" (load-bearing workarounds, undocumented invariants, tests that don't pin behaviour) with required epistemic status (`[UNVERIFIED]`/`[SUSPECTED]`/`[VERIFIED]`) and a 90-day re-confirm rule — the lean form of brownfield hazard capture (no new doc, no new subagent).
- **Characterization mode** in the `add-tests` skill: pin **observed** (not verified-correct) behaviour before a refactor, skeleton-then-run (never invent expected values), with a mandatory "OBSERVED not VERIFIED" header and a **HALT for human review on auth/security/money** so a characterization spec can't silently bless an insecure or wrong behaviour. `/refactor` Step 2 now points at it.
- **AI-readiness disclosure.** `scripts/metrics.{ps1,sh}` emit a `readiness` block (CI present, measured coverage % or `null`=not-measured, `tsconfig` strict, tests present); `/impact` surfaces it as a **capability disclosure, never a gate** — a weak substrate is exactly where teams most need help.
- **Security parity with the .NET template.** Added `SECURITY_FINDINGS.md` (SLA register) and wired the existing `security-auditor` agent into the security overlay, `/bootstrap` (initialise the register), and the CLAUDE.md Registers note.

### Notes
- LSP-over-MCP symbol grounding: **deferred** behind a spike with explicit kill criteria — cold-start >10 s, 8–15 s/query, orphaned language-server processes, and air-gapped install of `csharp-ls`/`typescript-language-server` + an MCP bridge infeasible on Bitbucket DC. Fallback: `Read`/`Grep` + Verification Rules #1–2.

## 0.13.2 — 2026-06-05 (hooks fire on Windows: PowerShell-default + CRLF-safe)

### Fixed
- **Claude Code hooks silently no-opped on Windows.** The default `.claude/settings.json` invoked `bash .claude/hooks/*.sh`; on a Windows box without git-bash on PATH (or with CRLF-mangled `.sh` files), the hooks failed quietly — so the framework's enforcement (secret/suppression blocking via the PreToolUse guard, the PostToolUse checks, the Stop boy-scout check) **wasn't actually running**. The default now uses the PowerShell (`pwsh`) twins, which don't depend on bash. `scripts/install.ps1` falls back to Windows PowerShell 5.1 (`settings.windows.json`) when `pwsh` is absent; `scripts/install.sh` switches to the bash twins when `pwsh` is absent. Copilot's `.github/hooks/hooks.json` already declared both interpreters and was unaffected — this brings Claude Code to parity. (Reported from a real implementation.)
- **`.sh` hooks corrupted to CRLF on Windows checkout.** Added `.gitattributes` pinning `*.sh` (and `*.ps1`) to LF, so `core.autocrlf=true` can't rewrite the shebang line to `bash\r` and break the bash twins — the second reason the bash hooks failed on Windows.

## 0.13.1 — 2026-06-05 (impact harness: exclude build artifacts from the A/B diff)

### Fixed
- **Build artifacts leaked into the behavioral A/B file list.** `scripts/impact-run.{sh,ps1}` now exclude `node_modules/`, `dist/`, `.angular/`, `bin/`, `obj/`, `.vs/`, `TestResults/`, and `coverage/` from the captured diff via git pathspec exclusions (`:(exclude,glob)**/…/**`). Without it, a consumer repo that doesn't gitignore those dirs fed generated/vendored files (compiled output under `dist/`, packages under `node_modules/`) into the acceptance asserts and the `metrics.sh` scorecard, corrupting the A/B signal and inflating file/LOC counts. We filter the file list rather than clean the tree — note `git clean -fd` does **not** remove ignored dirs; that needs `-fdx`. (Reported from a real implementation.)

## 0.13.0 — 2026-06-05 (presentation deck + impact-harness Windows/Copilot fixes)

### Added
- **Presentation deck** — `docs/presentation/framework-briefing.html`, a self-contained, offline HTML briefing (keyboard nav, built-in speaker-notes overlay, print-to-PDF) for pitching the framework to tech leads and their teams: overview + practical implications for both audiences. Companion **`docs/presentation/TALKING-POINTS.md`** carries two runs-of-show (leads vs teams), a pre-meeting checklist, per-slide notes, and anticipated Q&A. Listed in the README "What's in the box" table.

### Fixed
- **Impact harness was skipped during `/adopt`** (observed in a real Opus-4.6 adoption). `/adopt` Phase 9 is now **mandatory**, with a "Definition of done" that gates completion on `docs/impact/IMPACT.md` existing, and Phase 8 explicitly hands off to it — the report can no longer be silently dropped.
- **Copilot CLI not detected on Windows.** `scripts/impact-run.{sh,ps1}` now resolve the agent robustly — probing `copilot`, `copilot.cmd`, `copilot.exe`, and npm-global locations (`npm prefix -g`, `%APPDATA%\npm`) — instead of a single `command -v copilot`, which missed the npm-global `.cmd` shim. `/impact` now tells the agent to trust the runner's exit code (`3` = genuinely absent) rather than pre-judging availability with a bare PATH check.
- **`git worktree` failed on Windows long paths (MAX_PATH).** The behavioral A/B now creates worktrees at a short drive-root base (`<drive>:/iwt/wN`) with `core.longpaths=true`, instead of deep temp+GUID paths that overflowed the 260-char limit once a deep source tree was checked out.

## 0.12.0 — 2026-06-04 (CLAUDE.md review + README-drift check)

### Added
- **`docs-sync-check` README-drift check** — advisory NOTE when a skill (`.claude/skills/`) or agent (`.claude/agents/`) isn't mentioned in `README.md`, so the hand-maintained What's-in-the-box / subagents tables can't silently fall behind (the gap that had let the README drift to 0.7.2).

### Fixed
- **Boy Scout rule "inline single-consumer interfaces" contradicted mandatory SOLID/DIP.** Reworded in CLAUDE.md + AGENTS.md to carve out DI service seams: service abstractions/tokens are required even with one implementation and must never be inlined; only data/internal abstractions are inline candidates.
- **CLAUDE.md Agentic Workflow** now references persisting a `specs/<slug>.md` spec for larger features (it lagged the AGENTS.md mirror and the `/design`→`/feature` flow).
- **CLAUDE.md drift note** now says to regenerate `copilot-instructions.md` **and** `AGENTS.md` (both are generated by `/generate-copilot`).

## 0.11.1 — 2026-06-04 (README accuracy)

### Fixed
- **README reference sections brought up to date** with the current toolset: What's-in-the-box now lists `solid-check`, `enforce-architecture`, the impact-harness scripts, and `docs/ARCHITECTURE.md` / `REVIEW-GUIDE.md`; the subagents table shows all six (incl. `solid-check`, now "six … five user-facing"); `/impact` added to the command list. The embedded changelog had drifted to 0.7.2 — it now points to `CHANGELOG.md` instead of duplicating it.

## 0.11.0 — 2026-06-04 (deterministic SOLID backstop + PowerShell parity)

### Added
- **`enforce-architecture` skill** — scaffolds the **deterministic** layer/feature dependency-direction CI gate that complements the semantic `solid-check` agent: a **dependency-cruiser** config (no circular deps, core/shared ⊄ features, no cross-feature imports), with a copy-paste sample at `scripts/ci/dependency-cruiser.sample.js`. Referenced from `CLAUDE.md > SOLID` and Common Tasks.
- **PowerShell twins** for the impact harness — `scripts/metrics.ps1` and `scripts/impact-run.ps1` — so Windows-only / PowerShell shops get full parity (the bash versions remain primary).

### Decided
- **Angular SOLID stays literal** (an abstraction/token per injected service) — confirmed, no relaxation to principled-DIP.

## 0.10.0 — 2026-06-04 (impact harness)

### Added
- **Impact harness** — a fully automated before/after of the framework's value, run by `/adopt` (and standalone via `/impact`), with **no user input**.
  - **`/impact` command** (+ Copilot prompt wrapper): writes `docs/impact/IMPACT.md` and a generated `docs/impact/impact.html`.
  - **Tier 1 (always):** a capability diff (old setup archived in `docs/pre-adoption/` vs this framework) + a deterministic codebase scorecard via `scripts/metrics.sh` (anti-pattern / SOLID-DIP / security / test counts → JSON), baselined at adoption (`docs/impact/baseline.json`).
  - **Tier 2 (if Copilot CLI is present):** a behavioral A/B — `scripts/impact-run.sh` runs `tests/impact/tasks.json` through the headless agent **twice**, in throwaway git worktrees at the `pre-adoption` tag (old framework) vs `HEAD` (this one), N trials each, capturing build / acceptance-asserts / anti-patterns-on-diff per run. Only the framework differs between arms.
  - `/adopt` Phase 0 freezes the baseline and tags `pre-adoption` **before any change**; Phase 9 runs `/impact`.
- **`scripts/build-architecture-html.{sh,ps1}` generalized** to `[src] [out] [title]`, so `/impact` renders `impact.html` from the same drift-safe generator.

### Note
- Tier 2 needs a headless agent (Copilot CLI), authenticated once; without it, Tier 1 still runs. Results are stochastic — read trials as a distribution and pin the same model in both arms. PowerShell twins of `metrics`/`impact-run` are a follow-up (the harness already requires git-bash, a framework prerequisite).

## 0.9.1 — 2026-06-04 (architecture docs + AI install path)

### Added
- **`docs/ARCHITECTURE.md`** — canonical, human-readable architecture map with Mermaid diagrams (three-tier model, source→generated flow, hook lifecycle, GitHub-vs-Bitbucket surface split, repo map). Renders on GitHub/Bitbucket; AI agents still read CLAUDE.md/AGENTS.md, not this.
- **`docs/architecture.html`** — generated from ARCHITECTURE.md by `scripts/build-architecture-html.{sh,ps1}` (renders diagrams via marked + mermaid; embeds the source so it cannot silently drift). Cross-tool `src-sha1` marker; `docs-sync-check` flags staleness.
- **`docs/REVIEW-GUIDE.md`** — a senior reviewer's annotated tour: reading order, what each piece guarantees, how to verify it, and the tradeoffs worth probing.
- **`scripts/install.{sh,ps1}`** — install the framework into a target repo (excludes `.git` and the `.template-repo` marker), then prints next steps; plus an "Implementing this framework (for an AI agent)" entrypoint in the README.
- **`docs-sync-check`** gains an `architecture.html` freshness check.

## 0.9.0 — 2026-06-04 (literal SOLID)

### Added
- **SOLID is now mandatory** — a standing `## SOLID` section in CLAUDE.md (mirrored to AGENTS.md): an abstraction/token for **every injected service** (DIP), plus SRP / OCP / LSP / ISP rules. Literal classic SOLID, per tech-lead mandate. DIP mechanism is an `abstract class` DI token (or `interface` + `InjectionToken`). Data carriers (models, DTOs, enums) are exempt.
- **`solid-check` subagent** (`.claude/agents/` + `.github/agents/` mirror), dispatched by `/review` Step 1 alongside convention-check / bloat-radar / debt-radar. Self-skips in repos without a `## SOLID` section.
- **`docs/architecture-decisions.md`** is now the home for full ADRs; `docs/defaults.md` DI section mandates an abstraction per service for greenfield.

### Changed
- **Leanness #2 reconciled with SOLID**: abstractions are now expected for injected services; anti-bloat teeth remain on *data* (never abstract a model/DTO) and on *speculation*.
- **`bloat-radar` recalibrated**: no longer flags a single-implementation abstraction/token on an injected service (required by DIP now); still flags abstractions on non-service types, speculative bases, and single-use pipes/directives. The SOLID lens moved to `solid-check`.
- **`/generate-copilot`** now emits a SOLID block into `copilot-instructions.md` and copies the full SOLID section into the `AGENTS.md` mirror.
- **Eval suite** flipped to the new policy: `angular-001` now requires a DI abstraction for the service; `angular-004` requires the abstraction **and** still forbids a speculative provider layer (DIP yes, future-proofing no).

### Fixed
- **`/adopt` ADR merge** now appends full ADRs to `docs/architecture-decisions.md` with a one-line index in CLAUDE.md (was inline), matching the `create-adr` skill and `/bootstrap` Phase 3a.

### Note
- Deterministic DIP backstop is **dependency-cruiser** (or `eslint-plugin-boundaries`) enforcing module/layer direction in CI; the semantic SOLID gate is the `solid-check` agent.

## 0.8.0 — 2026-06-04 (cross-tool parity + Bitbucket + spec-driven)

### Added
- **AGENTS.md is now a generated full mirror** of CLAUDE.md's portable rules (Verification, Leanness, Conventions, Boy Scout, Agentic Workflow) — not a pointer — so AGENTS.md-native tools (GitHub Copilot agent mode & CLI, Codex, Cursor, Gemini, Aider) get the real ruleset. Emitted by `/generate-copilot` Part B; produced by `/bootstrap` Phase 3e; checked for drift by `/docs-sync` Step 2 and the CI guardrail.
- **Skills now reach Copilot.** `.claude/skills/` is mirrored byte-for-byte to `.github/skills/` (Copilot CLI / cloud agent read that path; VS Code Copilot already reads `.claude/skills/`). New `scripts/sync-agent-files.{sh,ps1}` regenerates the mirror, `/generate-copilot` Part C runs it, and the CI guardrail enforces parity.
- **Subagents exposed to Copilot** as custom agents: `.github/agents/{security-auditor,convention-check,bloat-radar,debt-radar}.agent.md` — thin wrappers delegating to the canonical `.claude/agents/` definitions (same single-source pattern as the prompt files).
- **PreToolUse guard hook** (`guard.sh` + `.ps1`) — hard-blocks any write that adds `// eslint-disable`, `@ts-ignore`/`@ts-nocheck`, or a hardcoded secret (private key, cloud token, credential literal). Registered in `.claude/settings.json`, `.claude/settings.windows.json`, and `.github/hooks/hooks.json` (Claude Code: exit-2 block; Copilot: JSON deny). Deterministic enforcement of Verification Rule #7.
- **Spec-driven development**: a `specs/` directory with `specs/README.md` (template + lifecycle). `/design` persists a spec to `specs/<slug>.md`, `/feature` implements against it, `/review` verifies conformance. CLAUDE.md is framed as the project "constitution".
- **New skills**: `add-tests` (TestBed + `HttpTestingController`, store state-transition tests), `dependency-audit` (`npm audit` + Dependabot/Renovate setup), `create-adr` (inline ADRs in CLAUDE.md > Architecture Decisions).
- **Bitbucket Data Center support**: a README "Running on Bitbucket Data Center" section (what works locally vs what's GitHub-only — incl. Atlassian Rovo Dev being Cloud-only); host-agnostic `scripts/docs-sync-check.{sh,ps1}`; `scripts/ci/bitbucket-pipelines.example.yml`; and Code Insights / pre-receive / Bamboo wiring guidance. `/security-review` gains a "Standing scanners" note (CodeQL on GitHub; Semgrep/SonarQube + Code Insights on Bitbucket).

### Changed
- `.github/workflows/docs-sync-check.yml` is now a thin caller of `scripts/docs-sync-check.sh` (host-agnostic) and is marked GitHub-only. The script also verifies the AGENTS.md mirror is current and that `.github/skills` matches `.claude/skills`.
- `/generate-copilot` now regenerates **both** `.github/copilot-instructions.md` (slim) and `AGENTS.md` (full mirror), and syncs the skills mirror.

### Token economy
- **Model routing**: `convention-check`, `bloat-radar`, and `debt-radar` now run on **Haiku** (recurring, pattern-based work); `security-auditor` and `bootstrap-pass` stay on the inherited strong model (high-stakes / one-time-high-leverage). Cuts per-`/review` cost without losing security or bootstrap quality.
- **Quiet-on-success hooks**: `post-write.{sh,ps1}` emit `tsc --noEmit` output **only on failure** — a successful write no longer injects type-check output into context.
- **CLAUDE.md size budget**: `docs-sync-check.{sh,ps1}` prints an advisory NOTE when CLAUDE.md exceeds ~400 lines (it loads on nearly every turn and anchors the prompt cache); `/bootstrap` Phase 3a documents the budget.
- **ADRs out of the hot path**: the `create-adr` skill now appends full ADRs to `docs/architecture-decisions.md` with a one-line index in CLAUDE.md, instead of pasting them inline — stops the always-loaded file from growing and avoids busting the prompt cache on every recorded decision. `/bootstrap` Phase 3a follows the same split.

## 0.7.3 — 2026-05-19 (Boy Scout OnPush demotion)

### Fixed
- **`ChangeDetectionStrategy.OnPush` is no longer an always-apply Boy Scout item.** Auto-toggling a component to `OnPush` on every drive-by edit is a semantic change, not a cleanup: components that mutate inputs in place, rely on default change detection ticking from `setInterval`/Promises/third-party callbacks, or expect re-render on ambient state changes will silently break (stale UI, no error). Moved to the *primary-target* tier with an explicit precondition (verified data flow + view-update verification). New components scaffolded from skills still default to `OnPush` per `docs/defaults.md`.

### Changed
- **`CLAUDE.md`** — removed OnPush from Boy Scout > Always apply > Add (renumbered); added a callout explaining why; added it to *Apply only when the file is the primary target* with the precondition.
- **`boy-scout-check.{sh,ps1}`** — removed the "Component without OnPush" detection. Comment header notes OnPush is intentionally excluded.
- **`tests/evals/cases.yaml`** — `angular-003` no longer requires the model to add OnPush to a touched file; rubric now explicitly forbids silently applying it, while still requiring the `takeUntilDestroyed()` migration.
- **`README.md`** — updated the "Quality improves as a side effect" paragraph and the Stop-hook row in the hooks table to reflect the demotion.

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
- **Tool-name filter in hook scripts** (`post-write.{sh,ps1}`). The filter previously accepted only Claude Code's `Write`/`Edit` (PascalCase); GitHub Copilot uses `edit`/`create` (lowercase). Every Copilot file-write event was being silently dropped before path extraction. Filter now accepts both surfaces.
- **`toolArgs` parsing** in the same scripts. Per the Copilot hooks spec, `toolArgs` is a parsed object, not a JSON-encoded string. The previous `jq fromjson` / `ConvertFrom-Json` paths threw and were silently swallowed by `2>/dev/null`, so file-path extraction from Copilot payloads returned empty. Switched to direct object access, with a fallback string-parse for legacy payload shapes.
- **Prompt-file frontmatter** — `mode: agent` → `agent: agent` across all 13 `.github/prompts/*.prompt.md` files. `mode` was deprecated by VS Code in favor of `agent` (see `github/awesome-copilot#464`).
- **Bogus `$schema` URL** in `framework-version.json`. Removed — the URL pointed to a non-existent GitHub org.
- **`tsBuildInfoFile` location** — moved from repo root (`.claude-tsbuildinfo`) to `.claude/.state/tsbuildinfo` (already gitignored) so the cache no longer leaks into the project root.

### Changed
- **README hook-compatibility table**. The "VS Code Copilot reads `.claude/settings.json` directly" row was unfounded — VS Code Copilot's surfaces are `.github/copilot-instructions.md`, `.github/instructions/`, `.github/prompts/`, and `.github/hooks/`. The table is now two rows: Claude Code (CLI + VS Code extension) and GitHub Copilot (cloud + CLI), with the exact payload shape per surface.

### Added
- **Cleanly bail-out guard** in `post-write`: skip if `node_modules` is absent, instead of failing noisily.

## 0.5.0 — 2026-04-28 (anti-bloat batch)

### Added
- **Leanness conventions** in `CLAUDE.md`. Counterweight to Boy Scout's add-bias: no interface without a second consumer, wrappers must add behavior, prefer editing over creating, deletion is a contribution.
- **`bloat-radar` subagent**. Scans diffs for speculative abstractions, shallow wrappers, parallel implementations, comment debris, defensive over-coding, trivial tests, and net-LOC density. Wired into `/review` alongside `convention-check` and `debt-radar`.
- **Anti-bloat rails** appended to `feature` and `refactor` workflow rails (route-prompt bash + PowerShell). Refactor now reports net LOC delta; growth requires explicit reason.
- **Boy Scout: Subtract** subsection in `CLAUDE.md`. Always-apply subtractions (unused imports, commented-out blocks, unreferenced privates) and primary-target subtractions (inline single-consumer interfaces, collapse shallow wrappers).
- **Stop hook** (`boy-scout-check.sh` + `.ps1`) now flags commented-out code blocks (2+ contiguous code-like `//` lines).
- **`/security-review` command + `security-auditor` subagent**. OWASP-style scan: injection / XSS / auth-authz / secrets / sensitive data / crypto / transport / dependencies. Wired into Copilot via `.github/prompts/security-review.prompt.md`.
- **Eval harness** (`tests/evals/`). Tiny regression suite that probes the rules CLAUDE.md + FRAMEWORK-CONTEXT.md encode (Verification, Leanness, Boy Scout, no future-proofing, no defensive over-coding). Two grading layers per case: deterministic regex + Haiku-graded rubric. Uses prompt caching with a `cache_control` breakpoint at end of CLAUDE.md so subsequent cases hit cache. Five cases, run quarterly or after framework version bumps.

### Changed
- `/feature` Step 1 includes a Leanness check before scoping the work.
- `/refactor` Step 7 now requires reporting net LOC delta.

## 0.4.0 — 2026-04-28

### Added
- **PowerShell hook variants** for Windows-only PowerShell teams. Ships `.ps1` equivalents of `session-start`, `route-prompt`, `boy-scout-check`, and `post-write` alongside the bash versions, plus a `settings.windows.json` users can swap into `.claude/settings.json` (or `.claude/settings.local.json`). Uses Windows PowerShell 5.1 — preinstalled on every Windows machine, no extra install. (Resolves the "hooks disabled on PowerShell-only Windows" caveat in the README compatibility table.)
- **`FRAMEWORK-CONTEXT.md` template**. Cross-repo context file for shared library APIs, multi-tenancy conventions, dashboard contracts, and cross-service patterns. Maintainer-curated; bootstrap auto-populates the "Detected Framework Packages" table from `package.json`. CLAUDE.md still wins on conflicts; agent flags contradictions.
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
- Keep entries scoped to this template. Cross-stack decisions go in `project_framework_architecture.md`; the sibling `.NET` template tracks its own changes in [`ai-tech-lead-dotnet/CHANGELOG.md`](https://github.com/andreoucostas/ai-tech-lead-dotnet/blob/master/CHANGELOG.md).
- When a framework-level change lands in both templates, write the entry separately in each — they'll diverge in detail (file paths, language idioms) and shared editing tends to drift anyway.
