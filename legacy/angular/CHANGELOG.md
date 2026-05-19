# ai-tech-lead-angular — Changelog

> Framework-level changes for the Angular template. Per-stack `.NET` changes live in [`ai-tech-lead-dotnet/CHANGELOG.md`](https://github.com/andreoucostas/ai-tech-lead-dotnet/blob/master/CHANGELOG.md).
> Architecture decisions (cross-stack) live in `project_framework_architecture.md`.

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
