# ai-tech-lead-angular — Changelog

> Framework-level changes for the Angular template. Per-stack `.NET` changes live in [`ai-tech-lead-dotnet/CHANGELOG.md`](https://github.com/andreoucostas/ai-tech-lead-dotnet/blob/master/CHANGELOG.md).
> Architecture decisions live in `docs/architecture-decisions.md`.

## 0.25.3 — 2026-07-05 (B-14: port audit-trail PostToolUse hook to Angular)

> Ports the `audit-trail` PostToolUse hook from the dotnet template, closing a parity gap.
> Every AI-assisted file write is now logged to `.claude/ai-audit.log` on both stacks.

### Added
- **`audit-trail` PostToolUse hook** (`.claude/hooks/audit-trail.ps1` + `.claude/hooks/audit-trail.sh`).
  Appends a tab-delimited ISO-8601-UTC / git-branch / repo-relative-file-path entry to
  `.claude/ai-audit.log` on every AI-assisted Write/Edit (Claude Code and Copilot surfaces).
  Angular-specific build artifacts (`node_modules`, `dist`, `.angular`, `coverage`) are skipped.
  The log itself is always skipped to prevent recursion. (B-14)
- **`.claude/ai-audit.log` seed file.** Tracks AI-assisted file changes; committed to version control
  with a 5-line header. (B-14)
- **`tests/hooks/AuditTrail.Tests.ps1`** (byte-identical to dotnet twin). Behavioral tests for
  audit-trail: append, self-skip, Copilot surface parity, tab-delimited 3-field format. (B-14)

### Changed
- **`.claude/settings.json`** — `PostToolUse` `Write|Edit` block gains `audit-trail.ps1` as second hook. (B-14)
- **`.github/hooks/hooks.json`** — `postToolUse` array gains `audit-trail` entry (`timeoutSec: 10`). (B-14)

---

## 0.25.2 — 2026-07-04 (P2 gate-honesty: fix silent-drift gates + a twin routing bug)

> Fable-exit backlog P2 band (`BACKLOG.md` B-04…B-09). Gates that passed while the drift they
> existed to catch slipped through, plus a PowerShell-only `post-write` routing divergence.
> Lockstep with the .NET twin.

### Fixed
- **`post-write.ps1` misrouted type-check failures to the wrong surface on malformed/empty payloads.**
  `$tn` (tool name) was assigned only inside the JSON-parse `try`, so a malformed payload with the
  `CLAUDE_FILE_PATH` env fallback left it `$null`; `$null -eq ''` is `$false` in PowerShell, so the
  Claude empty-case exit-2 branch was skipped and a failed `tsc --noEmit` was emitted to the Copilot
  (exit-0) branch instead — the model never saw it, diverging from the `.sh` twin's `case … "")`.
  Pre-declared `$tn = ''`. Added `tests/hooks/PostWriteRouting.Tests.ps1` (static guard + build-free
  twin agreement). (B-09)

### Added (deterministic gates)
- **Skills-mirror gate** in `scripts/template-checks.ps1/.sh`: `.claude/skills` must match
  `.github/skills` (Copilot reads the `.github` copy), EOL-normalized. Editing one and forgetting
  the other previously shipped stale Copilot guidance with every check green. (B-07)

### Changed
- **`post-write` `timeoutSec` unified to 120** in `.github/hooks/hooks.json` (was 60; the ceiling
  only bounds a single type-check and a too-low value kills a cold `tsc` run mid-check). The file
  is now gated by `check-lockstep` (structured registration parity). (B-05, WSD-009)
- **Enforcement matrix** (`docs/enforcement-surfaces.md`) gains three capability rows — build/
  type-check feedback, Boy Scout stop-nudge, audit trail — recording the B-03 live finding that
  Copilot does **not** consume `postToolUse` `additionalContext` (so `post-write` feedback is
  not surfaced to the Copilot model, though `audit-trail`'s file side-effect still fires). (B-08)

_Maintainer-only (does not ship): `check-lockstep.ps1` now enumerates the union of both repos for
IDENTICAL-class files (B-04), computes the shared-skill set instead of a hand-kept list (B-06), and
gates `hooks.json`; covered by a new `CheckLockstep.Tests.ps1` self-test._

## 0.25.1 — 2026-07-04 (P1 correctness + enforcement-honesty fixes)

> Fable-exit backlog P1 band (`BACKLOG.md` B-01/B-02/B-03). A shipped hook that crashed on a
> supported consumer path, plus two honesty corrections where docs/comments claimed a control
> fires where it doesn't. Lockstep with the .NET twin.

### Fixed
- **`post-write.ps1` crashed on every write under Windows PowerShell 5.1 in comma-decimal
  locales** (de-DE/el-GR/fr-FR). The throttle epoch used
  `[int][double]::Parse((Get-Date -UFormat %s))`; on 5.1 `-UFormat %s` returns a fractional
  local-time string and `[double]::Parse` is culture-sensitive, so the dot parsed as a group
  separator, overflowed `Int32`, and threw a terminating error `SilentlyContinue` does not
  swallow. Replaced with `[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()` — culture-free, integer,
  UTC — which also removes a UTC/local throttle-stamp skew against the `.sh` twin's `date +%s`.
  Added `tests/hooks/PostWrite.Tests.ps1` (host-independent regression, red before green). (B-02)

### Changed (enforcement honesty)
- **Guard write hard-block scoped to editor/file-write tools.** `docs/enforcement-surfaces.md`
  now carries a caveat that `guard.*` only sees `Write`/`Edit` (Claude Code) and file-path/content
  (Copilot) tool calls — a write routed through a terminal/shell tool (`sed -i`, `echo >>`,
  heredoc, `Set-Content`) carries no such payload and is **not** intercepted. Softened the
  Verification-Rule-7 parenthetical in `CLAUDE.md`/`AGENTS.md` accordingly. (B-01)
- **Copilot `additionalContext` consumption live-verified** (Copilot CLI 1.0.68, sentinel canary):
  `userPromptSubmitted` additionalContext **is** consumed (routing/plan-gate/security salience
  reaches the CLI model); `postToolUse` additionalContext is **not** consumed by the model, and
  repo hooks fire **only after the workspace folder is trusted**. Updated the
  `enforcement-surfaces.md` Status notes and corrected the now-falsified "consumes postToolUse
  feedback" comment in the `post-write` twins. (B-03)

## 0.25.0 — 2026-07-02 (toolchain-first enforcement: `enforce-standards` skill + Copilot prompt injection)

> First implementation slice of the 2026-07-02 self-sufficiency review (workspace WSD-008). Two
> P0s: (1) the lint/compiler toolchain becomes the surface-independent standards floor —
> deterministic in the IDE, every local build, and CI, binding humans and every AI tool alike;
> (2) the `route-prompt` salience layer — believed Copilot-inert since 0.7.2 removed its
> registration — is ported to Copilot, whose hooks now consume `userPromptSubmitted`
> `additionalContext` (CLI ≥ v1.0.65 per its changelog; VS Code agent mode per the official
> agent-hooks docs). Lockstep with the .NET twin.

### Added
- **`enforce-standards` skill** + `scripts/ci/eslint-standards.sample.mjs` — makes `@ts-ignore`
  (`ban-ts-comment` → error), `// eslint-disable` (dead via `linterOptions.noInlineConfig` +
  `reportUnusedDisableDirectives`), and `fit`/`fdescribe`/`xit`/`xdescribe`
  (`no-restricted-syntax`) lint-breaking with **zero new dependencies**. Mirrors the
  `enforce-architecture` delivery pattern; referenced from Common Tasks, README, and
  `docs/ci-integration.md` leg 2. Brownfield ratchet guidance included.
- **Copilot prompt injection**: `.github/hooks/hooks.json` registers `userPromptSubmitted` →
  `route-prompt.*`. `route-prompt.*` and `session-start.*` now self-detect the surface — Claude
  Code events carry `hook_event_name` and keep plain stdout (behavior unchanged); everything
  else gets dual-shape JSON (`additionalContext` + `hookSpecificOutput` wrapper, mirroring
  `guard.*`). Older Copilot versions ignore the JSON — a harmless no-op. The `.sh` twins need
  `jq`/`python3` to JSON-encode (same posture as `guard.sh`); without either they fall back to
  plain stdout, the pre-port behavior.
- `tests/hooks/RoutePrompt.Tests.ps1` — 10 surface-shape cases: plain-vs-JSON dispatch, plan
  gate, security overlay, slash-command and answer-only no-ops, twin decision agreement.

### Changed
- **Stale enforcement claims fixed** (the class 0.23.0 purged): the hooks.json `_comment` no
  longer says Copilot discards `userPromptSubmitted` stdout; `docs/enforcement-surfaces.md`
  routing/plan-gate/security rows now show per-prompt injection on Copilot **where hooks are
  enabled**, with an explicit status note that the injection path is fixture-tested but not yet
  live-verified on a real Copilot install (the github.com hooks-reference still lags — verify
  with the canary prompt); CLAUDE.md/AGENTS.md §1 "on Copilot only this text reaches the model"
  is now conditional on hooks being off.

## 0.24.2 — 2026-07-02 (CI integration doc: the required build consumers are expected to wire)

> On Bitbucket Data Center — the primary consumer profile — the team's own CI is the framework's
> only enforcement point that constrains every actor (any agent, any IDE, any human, any
> `--no-verify`). The README stated that expectation as four bullets ("wire `docs-sync-check` in
> whichever way fits your DC setup") with no recipe, and never said that the framework-state check
> alone does not gate code standards. Surfaced by the 2026-07-02 self-sufficiency forensic review
> (workspace WSD-008, finding F4). Lockstep with the .NET twin.

### Added
- `docs/ci-integration.md` — the required-build recipe: leg 1 = `scripts/docs-sync-check.sh`/`.ps1`
  (framework state), leg 2 = `eslint` + `ng build` + `ng test` (code-standards gate, with the
  dependency-cruiser step where the `enforce-architecture` gate exists); Bamboo and Jenkins
  reference configurations; blocking via Bitbucket DC's **required builds** merge check
  (repo/project admin only — no server plugins); pointers to native secret scanning (DC 8.12+)
  and Code Insights; an explicit "what CI still cannot gate" boundary.

### Changed
- README › "Running on Bitbucket Data Center": the guardrail section now states the required-build
  expectation explicitly and links `docs/ci-integration.md`. The pre-receive-hook suggestion moved
  out of the primary path — it needs DC *system* admin most consumer teams don't have; required
  builds don't.
- `scripts/ci/bitbucket-pipelines.example.yml` — DC note points at `docs/ci-integration.md`.

## 0.24.1 — 2026-07-02 (session-start: port the security-findings preload; twin-parity regression tests)

> The .NET twin's session-start preloads open/overdue SECURITY_FINDINGS.md counts at session
> start; this repo's `session-start.ps1`/`.sh` never got that section — an accidental lockstep gap
> (the register and its SLAs are identical here). Ported both twins, including the fixed
> open-findings count (the .NET `.sh` had a `grep -c … || echo 0` bug that wrote an
> integer-comparison error to stderr when zero findings were open; the port includes the fix).
> Caught red-first by a new twin-parity regression test. Lockstep with the .NET twin.

### Added
- `.claude/hooks/session-start.ps1` / `.sh` — section 5: overdue/open SECURITY_FINDINGS.md counts
  preloaded at session start, matching the .NET twin.
- `tests/hooks/TwinParity.Tests.ps1` — session-start security-preload regression cases: twins must
  agree on the security note (none / one open finding) and emit clean stderr, run from fixture CWDs.

## 0.24.0 — 2026-07-01 (deterministic self-enforcement: template CI + machine-checked framework invariants)

> 0.23.3 fixed the drift a forensic self-audit found; this release adds the machine gates that
> keep it fixed. Until now the template repo had **zero effective CI** — its only workflow ran
> `docs-sync-check`, which exits silently on `.template-repo`, so every invariant rested on the
> maintainer remembering a manual checklist. That is the exact failure mode this framework exists
> to prevent in consumer repos. Lockstep with the .NET twin.

### Added
- `scripts/template-checks.ps1` / `.sh` — deterministic framework checks: version-stamp sync (CLAUDE.md header == framework-version.json == CHANGELOG head; pair-check in consumer repos, which carry no CHANGELOG), **verbatim CLAUDE.md ↔ AGENTS.md mirror diff** (the four portable-rule sections + Agentic Workflow §1 — the `/docs-sync` "hard drift finding" is now a machine check, not a model instruction), copilot-instructions.md present and ≤ 80 lines, UTF-8 BOM sweep, hook `.ps1`/`.sh` twin existence, and script syntax.
- `.github/workflows/template-ci.yml` — the first CI that actually gates this repo: windows + linux legs run the hook test suite (the linux leg drives every `.sh` twin via real bash) and the framework checks on every push/PR.

### Changed
- `scripts/docs-sync-check.ps1`/`.sh` no longer goes silent in the template repo: `.template-repo` now routes to `template-checks` instead of skipping everything (the silent skip is how the 0.23.x stamp/mirror drift shipped unnoticed). Consumer runs additionally invoke `template-checks` as check 6b — the same invariants hold after install.
- `docs-sync-check` and `template-checks` anchor to their own script location instead of the caller's cwd/git root — running them from outside the repo can no longer silently audit the wrong directory.

### Fixed
- `docs-sync-check.ps1` counted lines with `Measure-Object -Line`, which skips blank lines and diverges from the `.sh` twin's `wc -l` (checks 1b and 3 could pass on one surface and fail on the other near the limit); both twins now count identically.

## 0.23.3 — 2026-07-01 (self-application fixes: stamp sync, verbatim AGENTS.md mirror, guard.sh honesty)

> A forensic self-audit found the framework failing its own drift rules in ways no deterministic
> check covered. This release fixes the shipped artifacts; the next minor adds the machine checks
> that keep them fixed. Lockstep with the .NET twin.

### Fixed
- `CLAUDE.md` header stamp had drifted two releases behind `.claude/framework-version.json` (0.23.0 vs 0.23.2) — the release recipe bumped the json but never the HTML comment. Both now read 0.23.3.
- `AGENTS.md > Agentic Workflow §1` was paraphrased, violating the `/generate-copilot` "copy §1 VERBATIM" mandate (§1 is Copilot's only routing surface). All portable-rule sections (Verification Rules, Leanness, SOLID, Boy Scout Rule, and §1) are now byte-identical to CLAUDE.md; steps 2–6 stay condensed by design under a `### Steps 2–6` heading.
- `AGENTS.md` claimed "seven workflows" while §1 defines six (the security pass is cross-cutting, not a workflow); the count claim is removed.
- `CLAUDE.md > Agentic Workflow` step 6 was missing the SECURITY_FINDINGS.md drift bullet the .NET twin already had (lockstep fix); `AGENTS.md`'s Quick reference also gained the security-findings register link.
- `guard.sh` header claimed the secret patterns "FAIL CLOSED", but with neither `jq` nor `python3` on PATH the hook allowed everything silently. It still allows in that state (blocking would brick every write) but now prints a loud `write-guard INACTIVE` warning to stderr, and the header + `docs/enforcement-surfaces.md` state the parser dependency honestly. (`guard.ps1` is unaffected — PowerShell parses JSON natively.)
- CHANGELOG header pointed at `project_framework_architecture.md`, a maintainer-workspace file that never ships; now points at `docs/architecture-decisions.md`.

### Added
- `.github/copilot-instructions.md` — the slim inline-completion digest mandated by `/generate-copilot` Part A had never been generated. It now ships (pre-bootstrap content sourced from `docs/defaults.md`), so `AGENTS.md`'s Quick-reference link and consumer `docs-sync-check` check #3 no longer dangle.
- `docs/architecture-decisions.md` — seeded empty so the `CLAUDE.md > Architecture Decisions` link resolves before the first `create-adr` run.

## 0.23.2 — 2026-06-29 (hook test harness: cross-platform `Get-BashPath` fix)

> Follow-up to 0.23.1, caught by a `/code-review` pass. The harness's bash resolver (`Get-BashPath` in `tests/hooks/_HookHarness.ps1`) built its candidate list with `Join-Path $env:ProgramFiles …`, which **throws** when `$env:ProgramFiles` is null/empty — the case on every non-Windows `pwsh` host (and a Windows box lacking the x86 var). That crashed the suite on Linux/macOS CI *before* the `bash`-on-`PATH` fallback could run, exactly where the `.sh` twin tests matter most. Now the candidate list is built null-safe (a Git path is added only when its env var is set), then falls back to `bash` on `PATH`. Lockstep with the .NET twin.

### Fixed
- `tests/hooks/_HookHarness.ps1` — `Get-BashPath` no longer throws on hosts without `%ProgramFiles%`; it resolves `bash` from `PATH` on Unix so the `.sh` twin-parity tests run there instead of erroring.

## 0.23.1 — 2026-06-29 (hook test harness: automated, twin-parity-checked tests for the framework's own hooks)

> The framework's own hooks and scripts had **zero automated tests** — only manual recipes — and that gap had already shipped a real defect: in 0.23.0 the bash `guard.sh` was found missing the test-defeat blocks its `guard.ps1` twin enforced (a silent twin-drift the manual process didn't catch). This release adds a **dependency-free PowerShell test harness** (no Pester, so it runs air-gapped and under Windows PowerShell 5.1) that pipes JSON events to each hook and asserts exit code + per-surface output (Claude `exit 2`+stderr vs Copilot `permissionDecision` JSON), plus **behavioural twin-parity** tests that run the `.ps1` and `.sh` on the same input and assert the same decision — the check that would have caught the `guard.sh` regression. Authored in lockstep with the .NET twin.

### Added
- **`tests/hooks/` hook test harness** — `_HookHarness.ps1` (dependency-free runner: pipes an event to a hook, captures exit/stdout/stderr, normalises to a BLOCK/DENY/ALLOW decision; drives `.sh` twins via Git's `bin\bash.exe` for full-PATH fidelity; falls back to `powershell.exe` when `pwsh` is absent; `.sh` tests self-skip when no bash is present), `Guard.Tests.ps1` (surface matrix over every block pattern + clean inputs, incl. the RxJS `skip()` and `*Tests*`-file false-positive allowances), `TwinParity.Tests.ps1` (deep `guard` `.ps1`↔`.sh` decision parity on both surfaces + empty/malformed-stdin robustness parity for every twin pair — Angular has 5 pairs, no `audit-trail`), a shared fixture library (`fixtures/guard-cases.ps1`), and `Invoke-HookTests.ps1` (suite runner; exit code = failing-test count).

### CI
- Run as a **dedicated step**: `pwsh -NoProfile -File tests/hooks/Invoke-HookTests.ps1` (fail the build on non-zero exit). Intentionally **not** wired into `docs-sync-check` (which early-exits on `.template-repo` and is a framework-state guardrail, not a test runner).

## 0.23.0 — 2026-06-25 (workflow disciplines made reachable on Copilot; deterministic write-floor extended to VS Code; false enforcement claims removed)

> The framework's value is gated behind workflow commands the target developers won't type, and on the primary surface (GitHub Copilot in VS Code against a local Bitbucket Data Center) the picture was worse than assumed: routing/plan-gate/security context **cannot** be injected there (Copilot discards `sessionStart`/`userPromptSubmitted` stdout; VS Code agent-hooks are Preview-only), and the one Copilot write-block we shipped used a JSON shape (`{decision,reason}`) that **no longer matches the current Copilot spec** — i.e. the v0.22.0 Copilot guard had silently become a no-op. This release (a) inlines every workflow's non-negotiables into the always-on `CLAUDE.md`/`AGENTS.md` §1 so classification leads to discipline on Copilot without a slash command, (b) fixes the guard deny shape and extends the deterministic write-floor to VS Code agent mode, and (c) stops the framework claiming enforcement on surfaces where it doesn't fire. Authored in lockstep with the .NET twin. Researched against the Claude Code, Copilot CLI, and VS Code agent-hooks references (June 2026).

> **Migration note:** *when* discipline fires has changed. The `route-prompt` per-prompt rails now point at `CLAUDE.md §1` as the canonical source (they remain a just-in-time salience copy, not an independent fork), and a question-shaped prompt with no imperative verb is now treated as answer-only (no workflow ceremony). If you relied on the old keyword-listed session-start primer "routing on Copilot," note that it never did — see `docs/enforcement-surfaces.md`.

### Fixed
- **`guard.ps1`/`.sh` Copilot deny shape was a no-op.** It emitted `{"decision":"deny","reason":…}`; current Copilot honours `{"permissionDecision":"deny","permissionDecisionReason":…}`. Now emits a **superset** (top-level *and* `hookSpecificOutput`-nested `permissionDecision`) so a single output blocks on **both Copilot CLI and VS Code agent mode**. The Claude Code `exit 2` path is unchanged.
- **The guard no-opped on VS Code entirely** — its tool-name switch only matched Claude/CLI names, never VS Code's camelCase tools. It now gates on *"the payload carries a file path + content"* (surface-agnostic), so secret-writes and test-defeats (`fit`/`fdescribe`/`.only`, `expect(true).toBe(true)`) are blocked under VS Code agent mode too (when Preview agent-hooks are enabled).

### Added
- **`CLAUDE.md`/`AGENTS.md` §1 now carries each workflow's non-negotiables inline** (fix → root-cause-then-regression-spec-first; refactor → green-before-touch + net LOC delta; test → red-before-green, assert rendered output/emitted events/store state, no over-mocking; etc.). Previously these lived only in `commands/*.md`, which Copilot never auto-loads — so a Copilot dev who never typed `/fix` got "follow the fix workflow" with no reachable definition. §1 is now the **canonical routing definition** and the load-bearing surface on Copilot.
- **`docs/enforcement-surfaces.md`** — the honest guaranteed-vs-instructed matrix per surface (Claude Code / Copilot CLI / Copilot VS Code). Linked from §1 and `hooks.json`.
- **Answer-only carve-out** in `route-prompt` + §1: a question-shaped prompt with no imperative verb is answered directly, no plan-gate ceremony (reduces false-positive routing without advertising an override keyword).

### Changed
- **`route-prompt.ps1`/`.sh` intro now names `CLAUDE.md §1` as the canonical source** the rails mirror (the rails stay for just-in-time salience on Claude; they are bound to §1, not deleted).
- **`session-start.ps1`/`.sh` no longer re-lists a routing keyword vocabulary** and no longer claims to route on Copilot (Copilot discards its stdout); it now points at §1. Comment in `.github/hooks/hooks.json` corrected accordingly.
- **`generate-copilot.md`** now mandates the §1 block be copied **verbatim** into `AGENTS.md` (carved out of the "may be condensed to one line per step" license) — otherwise regeneration would erase the inline non-negotiables from the one surface that needs them.
- **`/docs-sync`** gained two binding checks: AGENTS.md §1 must match `CLAUDE.md` §1 verbatim, and the `route-prompt` rails must stay substance-consistent with §1.

### Verification
- `guard.*` re-verified on all three surfaces: Claude `Edit` + AWS key → `exit 2` + stderr; Copilot CLI `edit` + key → `permissionDecision` JSON (exit 0); VS Code `create`/`str_replace` + key **or** `expect(true).toBe(true)` → superset `permissionDecision` JSON (exit 0, the newly-covered surface); clean content → exit 0. `guard.*` byte-identical across both repos; UTF-8 BOM preserved.
- All four edited hooks (`route-prompt`, `session-start`) parse clean under Windows PowerShell 5.1 + pwsh 7 and `bash -n`; answer-only suppression confirmed (a pure "why does this throw?" emits no rails; "fix the login crash" routes).
- **Task 0 (VS Code Preview-hook spike) was run and confirmed agent-hooks DO fire in VS Code agent mode.** The captured payload uses the Anthropic text-editor tool schema — `create` (`toolArgs.path` + `toolArgs.file_text`), `str_replace`/`insert` (`new_str`) — field names the guard's extractor did **not** previously read, so VS Code writes would have slipped the floor. Added `file_text` / `new_str` / `path` to the field extraction (both `guard.ps1` and `guard.sh`, jq + python paths); re-verified the guard blocks a `create`+secret and `str_replace`+private-key under the real VS Code shape. **Verified end-to-end:** a `create` of a deny-listed path in VS Code agent mode was blocked at runtime with the hook's reason surfaced to the model — the superset `permissionDecision` deny is honored. (Enablement remains org-gated: where Preview agent-hooks are disabled, VS Code degrades to instruction-only, as documented.)
- **`guard.sh` brought to parity with `guard.ps1`:** the bash path was missing the v0.22.0 test-defeat blocks (a lockstep miss). It now also blocks `[Fact/Theory(Skip=…)]`, `Assert.True(true)`/`Assert.False(false)`, `fit`/`fdescribe`/`.only`, `xit`/`xdescribe`/`.skip`, and `expect(true).toBe(true)` — verified firing on Claude (exit 2) and Copilot (`permissionDecision` JSON), and verified to still ALLOW the RxJS `skip()` operator and clean files.

## 0.22.0 — 2026-06-25 (test integrity: defend against the test pathologies AI assistants are most prone to)

> The framework had a strong testing *philosophy* (behaviour-first, lean, characterization-before-refactor) but three structural gaps, fixed in lockstep with the .NET twin: no guidance on test *shape* (only test types); no defence against the failure mode its own users are most exposed to — AI assistants routinely emit over-mocked, tautological specs that pass even when the code is broken (2026 empirical studies across Claude/Copilot/Cursor; majority-incorrect LLM oracles); and an enforcement asymmetry where architecture had a deterministic CI gate but testing had only soft review. This release closes the doctrine + cheap-enforcement gaps. Coverage-as-diagnostic and CI-enforced diff-scoped mutation testing are scoped for 0.23.0.

### Added
- **`test-critic` review agent** (`.claude/agents/test-critic.md` + `.github/agents/test-critic.agent.md`), spawned by `/review` alongside the existing four auditors. Its single question per spec: *would this fail if the code under test broke?* Flags oracle-invalid (would-not-fail) specs, over-mocking, specs that never render the real template, weak expectations, missing error/edge paths, implementation-coupling, and nondeterminism — a separate context from the code author, per the "the agent doing the work isn't the one grading it" principle. `/review`'s output block is renamed **Test Quality & Coverage** with a would-fail-if-broken verdict.
- **Test-integrity rules** (`CLAUDE.md` / `AGENTS.md` > Leanness > Test leanness #14–#16): no over-mocking (mock only true external boundaries — HTTP via `provideHttpClientTesting`, time, storage; render the real template), no tautological expectations, assert behaviour not implementation — each with its plain-language *why*.
- **Verification Rule #9 — red before green**: a new behavioral spec must be *seen to fail* against broken/pre-fix code before it is trusted; generalised from the bug-fix-only habit already in `fix.md`. The cheapest defence against vacuous specs.
- **Test shape + determinism defaults** (`docs/defaults.md`): a trophy-shaped heuristic (strict TS + lint as the wide base; component/integration tests via `TestBed` + harnesses as the centre of gravity; thin E2E; fewest isolated unit tests; the inverted / ice-cream-cone anti-shape) plus a determinism/hermeticity stanza (`fakeAsync`/`tick` or marbles for time; `provideHttpClientTesting`; no real timers/HTTP/`Math.random`). Bootstrap-overridable.

### Changed
- **`guard.ps1` PreToolUse hook now hard-blocks test-defeats** (deterministic floor; both surfaces/shells preserved — exit 2 + stderr for Claude, JSON deny for Copilot, `-ceq`, UTF-8 BOM): `fit`/`fdescribe`/`.only`/`xit`/`xdescribe`/`.skip` and `expect(true).toBe(true)` in `*.spec.ts` (plus `[Fact/Theory(Skip=…)]` / `Assert.True(true)` in `*.cs`, since both stacks share one guard). Enforces the previously-unenforced "no `fdescribe`/`fit`/`xit` on main" default.
- **`add-tests` skill and `/test`** gained the over-mocking/real-oracle guidance and the red-before-green check; `/test` now points at the trophy-shaped Test shape heuristic and states the TDD position (no test-first mandate for features; red-first for fixes and regressions).
- **§5 Verification & confidence line** now requires showing the evidence — the command run and its observed pass/fail counts (e.g. `ng test --watch=false` → 87 passed) — not the bare claim "tests pass."
- **`metrics.ps1`** discloses two new anti-pattern counts (`tests_skipped_focused`, `tautological_expect`) for `/impact` — disclosure, not a gate. A `test-integrity-real-oracle` probe was added to `tests/impact/tasks.json` so the change is measurable through the framework's own A/B harness.

### Verification
- `guard.ps1` re-verified under Windows PowerShell 5.1 and pwsh 7: blocks `fit(`, `it.only`, `expect(true).toBe(true)`, `[Fact(Skip=…)]`, `Assert.True(true)` (exit 2); passes clean specs and the RxJS `skip()` operator (exit 0); existing `@ts-ignore` / `eslint-disable` blocks unaffected; UTF-8 BOM preserved.
- `guard.ps1` and `metrics.ps1` parse cleanly (0 errors); `metrics.ps1` runs and emits the new keys; `tests/impact/tasks.json` is valid JSON with the new probe.
- `.github/skills` re-synced and byte-identical to `.claude/skills`; `test-critic` mirrored to `.github/agents`; `AGENTS.md` updated with Rule #9 and Test leanness #14–#16; both repos stamped `0.22.0`; `docs-sync-check` clean. The impact A/B run itself (`impact-run.ps1`, needs Copilot CLI + two git refs) was not executed this session.

## 0.21.0 — 2026-06-12 (hook feedback actually reaches the model; PowerShell 5.1 hooks un-broken)

> Field finding (consumer report, fixed in lockstep with the .NET twin): "hooks always exit with 0 — build failures silently get ignored." Confirmed, and the audit found three distinct silent-failure mechanisms, all in the feedback path between a hook and the model. The hooks *ran* fine; their output went nowhere. Verified against the Claude Code hooks reference (exit-code/stdout semantics per event) and the GitHub Copilot hooks reference (stdout parsed as JSON only).

### Fixed
- **`post-write` type-check failures never reached the model** (`post-write.sh` + `.ps1`). Claude Code feeds PostToolUse output to the model only via **exit 2 + stderr** — plain exit-0 stdout goes to the debug log; Copilot consumes postToolUse stdout only as **JSON** (`{"additionalContext": …}`). The hook printed the `tsc --noEmit` failure as plain text and exited 0: invisible on both surfaces, so the agent kept working on top of broken types. Now: Claude surface → failure tail on stderr + exit 2; Copilot surface (`edit`/`create` tool names) → `additionalContext` JSON on stdout. The throttle stamp is also cleared on failure so the next write re-checks instead of skipping the known-broken state for the rest of the 5 s window. `post-write.sh` additionally gained a `tool_name` initialisation — under `set -u` the new surface branch would otherwise abort on the python3 fallback path.
- **`boy-scout-check` Stop-hook findings were equally invisible** (`boy-scout-check.sh` + `.ps1`). Findings addressed to the agent ("address them … before considering the work complete") were emitted as plain exit-0 stdout, which Stop hooks send to the debug log only. Now emitted as `{"hookSpecificOutput": {"hookEventName": "Stop", "additionalContext": …}}` — the model sees the findings, and the hook stays *soft* (no forced continuation). Switch to `{"decision":"block","reason":…}` for strict enforcement, as before.
- **`guard.ps1` failed open for Claude's `Edit` tool.** PowerShell `-eq` is case-insensitive, so `'Edit' -eq 'edit'` routed Claude's Edit through the **Copilot** branch: a JSON deny on stdout with exit 0, which Claude Code does not honour as a block — the write (e.g. one adding `@ts-ignore` or `eslint-disable`) went through. Now `-ceq` (the bash twin was never affected; `case` patterns are case-sensitive). The same comparison in the new `post-write` surface branch uses `-ceq` from the start. `Write` was unaffected, which is why the guard appeared to work.
- **No `.ps1` in the repo parsed under Windows PowerShell 5.1** where it contained non-ASCII. All `.ps1` files were BOM-less UTF-8; 5.1 reads those as ANSI, so the em-dashes inside `guard.ps1`'s string literals mangled into multi-byte garbage and produced a **hard parse error** — on `settings.windows.json` installs (the no-pwsh fallback) the guard never blocked anything, exiting 1 (which PreToolUse treats as non-blocking). UTF-8 BOM added to **every** `.ps1` in the repo (hooks + scripts); required by 5.1, harmless under pwsh 7.

### Verification
- All four post-write paths exercised with a stubbed failing/passing toolchain under pwsh 7, Windows PowerShell 5.1, and bash: Claude failure → exit 2 + stderr; Copilot failure → `additionalContext` JSON + exit 0; success → silent exit 0, stamp kept. Guard re-verified blocking on both surfaces and both shells; boy-scout JSON verified well-formed from both shells; all 23 `.ps1` files across both template repos re-parse cleanly.

## 0.20.0 — 2026-06-11 (mode-aware installer; adoption-pending becomes durable, machine-checked state)

> Field finding (observed on the .NET twin, fixed in lockstep): an agent (Opus 4.8) given the repo and asked to "implement the framework" ran the install script and stopped — `/adopt` never happened. Root causes: `/adopt` is deliberately not model-invocable and didn't exist in the installing session anyway; every pointer to it was ephemeral stdout or README prose addressed to a human; and the only durable post-install state (`BOOTSTRAP_PENDING`) steered the *wrong* way (`/bootstrap`). Worse, on brownfield targets the installer overwrote the very artifacts `/adopt` exists to merge (the consumer's `CLAUDE.md`, `AGENTS.md`, `TECH_DEBT.md`, …). This release makes the installer mode-aware and turns "adoption pending" into durable state that the SessionStart hook, CI, and `/bootstrap` all enforce — with an explicit handoff contract for installing agents.

### Added
- **Installer mode detection** (`scripts/install.ps1`/`.sh`): **greenfield** / **brownfield** / **update**, decided from an `/adopt`-Phase-1-style artifact scan and the presence of `.claude/framework-version.json`. The mode is printed and drives the next-steps output.
- **Brownfield: originals preserved + durable marker.** Files the copy would clobber (`CLAUDE.md`, `AGENTS.md`, `TECH_DEBT.md`, `SECURITY_FINDINGS.md`, `LEARNINGS.md`, `FRAMEWORK-CONTEXT.md`, `.github/copilot-instructions.md`, `docs/ARCHITECTURE.md`) are moved to `docs/pre-adoption/` *before* the copy, and `.claude/adoption-pending.json` records the detected artifacts and the archive mapping.
- **SessionStart adoption warning** (`session-start.ps1`/`.sh`): while the marker exists, every new session opens with 🔴 ADOPTION PENDING — next step is `/adopt`, **not** `/bootstrap`; the model cannot invoke it, so agents must stop and hand off to the developer. Takes precedence over the `BOOTSTRAP_PENDING` warning, which previously pointed brownfield repos at the wrong command.
- **CI guardrail**: `docs-sync-check.ps1`/`.sh` gained check 0 — fail while `.claude/adoption-pending.json` exists.
- **`/bootstrap` pre-flight guard** (check 0, `bootstrap.md`): aborts and redirects to `/adopt` when the marker exists, or when live AI artifacts (`.cursorrules`, `.clinerules`, `GEMINI.md`, …) exist without `docs/pre-adoption/`. `/adopt`'s own Phase-7 bootstrap run is unaffected — its Phase 3 clears both conditions first.
- **Agent handoff contract** (installer output + README §1): an installing agent's task ends with copy + commit + telling the developer verbatim to start a Claude Code session in the target repo and type `/adopt` (or `/bootstrap`); it must not attempt the command or replicate it by hand. The installer's brownfield output now addresses the agent case explicitly ("IF YOU ARE AN AI AGENT running this installer: …").

### Changed
- **`/adopt` consumes the marker** (`adopt.md`): Phase 0 reads `.claude/adoption-pending.json` as a discovery seed; Phase 1 treats installer-archived originals as merge candidates at their original paths (the repo-root `CLAUDE.md` is now the template — the consumer's original lives in `docs/pre-adoption/`); Phase 3 deletes the marker; the definition of done includes its removal.
- **Update runs no longer clobber consumer content**: re-running the installer on a repo stamped with `.claude/framework-version.json` refreshes the framework machinery but restores the consumer-owned content files listed above (previously a re-run overwrote a populated `CLAUDE.md` with the template).
- **Installer no longer ships template-repo meta files**: `README.md`, `CHANGELOG.md`, `.gitignore`, `.gitattributes` are excluded from the copy — previously they overwrote the consumer's own README/changelog/gitignore. This aligns the installer with the documented copy list in README Quick Start §1.

## 0.19.0 — 2026-06-10 (slash commands exposed to model-driven invocation)

> Previously none of the 14 `.claude/commands/*.md` files had frontmatter, so Claude Code's SlashCommand tool could not surface them to the model: in natural-language chat the model could never escalate from the condensed `route-prompt` rails to the full workflow — even when those rails explicitly told it to ("Run /security-review on the diff"). The architecture is hook-as-floor, command-as-ceiling; this release makes the ceiling model-reachable. The `route-prompt` hook keeps injecting the deterministic floor on every prompt; the model can now invoke the full command (e.g. `/review`'s four-auditor fan-out) when the condensed rails aren't enough.

### Added
- **`description:` frontmatter on all 14 command files**, written as routing guidance (when to invoke, what the command spawns and produces). This exposes the workflow commands — `/feature`, `/fix`, `/refactor`, `/test`, `/design`, `/debt`, `/review`, `/security-review`, `/generate-copilot`, `/docs-sync` — to model-driven invocation via the SlashCommand tool.
- **`argument-hint:` frontmatter** on the workflow commands that take `$ARGUMENTS`, for slash-menu autocomplete.

### Changed
- **Setup/maintenance commands opted out of model invocation**: `/bootstrap`, `/rebootstrap`, `/adopt`, and `/impact` carry `disable-model-invocation: true` — they reshape the framework configuration or run the A/B harness, and stay developer-initiated.

## 0.18.0 — 2026-06-10 (FRAMEWORK-CONTEXT.md fully auto-drafted by `/bootstrap`)

> Previously `/bootstrap` populated only two of FRAMEWORK-CONTEXT.md's seven sections (Detected Framework Packages, Known Hazard Areas); the five context sections (Production Architecture, Shared Libraries, Multi-Tenancy, Dashboard Integration, Cross-Service Communication) stayed as "_Not yet populated_" placeholders waiting on a maintainer — and in practice stayed empty (observed in real adoptions). They are now auto-drafted from single-repo evidence with explicit honesty about scope: the draft describes what *this repo's code shows*, opens with a comment handing the cross-repo half to a maintainer, and a section with no signals gets a verified negative ("no multi-tenancy signals found — checked X, Y, Z") instead of a placeholder.

### Added
- **`/bootstrap` Phase 3d-ter** (`bootstrap.md`). Drafts the five context sections from Read/Grep evidence: app-vs-publishable-library classification + consumes/exposes from `environment*.ts` and `angular.json` (Production Architecture); per-detected-package consumed-surface entries titled "Consumed API surface (observed in this repo)" — never "latest" (Shared Libraries); tenant resolution / tenant-header / tenant-scoped-config signals (Multi-Tenancy); control-plane registration, `postMessage`, heartbeat wiring (Dashboard Integration); interceptor chain, API base URL conventions, typed envelopes, WebSocket/SSE (Cross-Service Communication). Non-interactive — drafts land in the PR diff for content review, same path as mined skills. Never touches a section a maintainer has written (per-section `*_PENDING` markers gate it).
- **Per-section `*_PENDING` markers** in the FRAMEWORK-CONTEXT.md template, so drafting is gated per section and maintainer-written content deterministically survives re-runs.
- **Phase 4 report bullet**: one line per drafted section (what was found, or the verified negative) with the reminder that cross-repo facts still need a maintainer.

### Changed
- **FRAMEWORK-CONTEXT.md header**. Maintenance note reflects that every section is now bootstrap-drafted; versioning caveat distinguishes auto-drafted entries (consumed surface at the pinned version) from maintainer entries (may document latest).
- **`/docs-sync` Step 4** (`docs-sync.md`). Per-section drift now re-checks the four architecture/communication sections against the 3d-ter evidence lists and proposes updates in the report (still never rewrites in place).
- **`/adopt` Phase 7** (`adopt.md`). Explicitly drafts the still-unpopulated context sections; sections filled by merged content in Phase 4 are left untouched.

### Fixed
- **`bootstrap.prompt.md` wrapper had drifted**: claimed six analysis passes (now seven, A7 added in 0.16.0) and "do not ask for confirmation between phases" (contradicting the 0.17.0 interactive gates). Now defers to the workflow's own pauses.
- **CLAUDE.md template version stamp** had drifted from `.claude/framework-version.json` (0.13.2 vs 0.17.0); both now read 0.18.0.

## 0.17.0 — 2026-06-10 (interactive gates in `/bootstrap` and `/adopt`)

> `/bootstrap` now pauses at two points for developer input rather than running end-to-end and deferring all review to a PR. Phase 2b collects ≤5 targeted questions (convention contradictions, pattern intent) in a single message before generating any artifact — the developer's answers are baked in, not deferred. Phase 3d-bis asks each candidate hazard as a plain engineering question before writing it to FRAMEWORK-CONTEXT.md; answers map to `[VERIFIED]`, `[REVIEWED: not a hazard — <date>]`, or `[UNVERIFIED]` — no row is dropped (audit trail preserved). `/adopt` Phase 4a reframes contradiction-resolution from an AI-artifact-merge question into a plain engineering choice with a safe default and an "accept all defaults" escape.

### Changed
- **`/bootstrap` Phase 2b** (`bootstrap.md`). New clarify-before-writing gate: ≤5 questions in one message, covering convention contradictions and pattern intent. Skip signal ("proceed", "accept defaults") continues without markers; `<!-- INFERRED -->` reserved for genuine code ambiguity only.
- **`/bootstrap` Phase 3d-bis** (`bootstrap.md`). Rewrites the hazard-confirmation step: each candidate hazard is asked in-session before being written, not after. Answered rows get `[VERIFIED]` or `[REVIEWED: not a hazard — <date>]`; unanswered rows remain `[UNVERIFIED]`. All rows are written (none dropped).
- **`/bootstrap` Phase 4 reminder** (`bootstrap.md`). Narrowed from "review CLAUDE.md before using any other commands" to "Verify the Conventions section — `<!-- INFERRED -->` marks areas where code analysis was genuinely ambiguous."
- **`/adopt` Phase 4a** (`adopt.md`). Contradiction-resolution reframed as a plain engineering question: "Your existing codebase has [A] for [area]; your `[filename]` says [B]. Which is intended?" Safe default keeps the in-code pattern. "Accept all defaults" escape applies it to all contradictions without per-item prompting.

## 0.16.0 — 2026-06-09 (project-specific skill discovery + exemplar grounding)

> `/bootstrap` now mines each codebase for its own tribal-knowledge recipes — multi-step operations that recur with non-obvious, repo-specific steps no shipped template can predict. Found candidates are auto-written as skills with `origin: discovered` frontmatter (visible in the PR diff for review). Instance-shaped skills (`add-component`, `add-service`, `add-lazy-route`, `add-signal-store`, and any mined `add-X`) are grounded in a real repo exemplar so the agent reproduces the project's conventions and structure, not an abstract template. The resurrection guard in `/rebootstrap` records removed mined skills as declined recipes in `LEARNINGS.md` so they are not re-proposed.

### Added
- **A7 pass: project-specific skill discovery** (`bootstrap-pass.md`, `bootstrap.md`). Runs unconditionally in every repo — mines naming/directory clusters whole-tree (no recency sampling), applies a tribal-knowledge criterion + framework-exclusion list, proposes ≤3–5 candidates. Respects `## Declined recipe:` entries in `LEARNINGS.md`.
- **Exemplar grounding** (`bootstrap.md` Phase 3a). For instance-shaped skills, pins a `see also` prose line to a real file in the repo. Quality-gated against Phase-2 synthesis: patterns flagged as debt are routed to `TECH_DEBT.md` instead.
- **Phase 4 mined-skills report** (`bootstrap.md`). PR-reviewable listing of discovered skills in plain engineering language.
- **Resurrection guard** (`rebootstrap.md`). Detects deleted mined skills and appends `## Declined recipe:` blocks to `LEARNINGS.md`; reported in Phase-4 final report.
- **Exemplar re-pinning in `/rebootstrap`**. Proposes updated `see also` lines when exemplar files move or a cleaner instance exists.
- **`LEARNINGS.md` declined-recipe convention**. Header now documents the auto-managed `## Declined recipe:` format so maintainers know not to remove these entries.

## 0.15.0 — 2026-06-06 (spec-driven development: explicit Tasks artifact)

> A targeted alignment after reviewing how the frontier labs and institutions (AWS Kiro, GitHub Spec-Kit, Google Antigravity, OpenAI Codex) frame AI-driven SDLC: they have converged on Spec → Plan → **Tasks** → Implement. The framework already had the spec lifecycle (`/design → spec → /feature → /review`, with CLAUDE.md as the "constitution") and is ahead on governance / calibration / eval — this adds the one element it underweighted: a persisted, checkable Tasks breakdown.

### Added
- **Tasks checklist in the spec lifecycle.** The `specs/<slug>.md` template now carries an ordered, checkable **Tasks** section (the *how* — distinct from acceptance criteria, the *what*). `/design` drafts it; `/feature` works through it and checks each `- [ ]` → `- [x]` **in the spec file** as it lands, so implementation progress survives across sessions and tools; `/review` flags any unchecked Task as incomplete work. No new command or artifact — an extension of the existing flow, and the lean answer to industry spec-driven development.

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
