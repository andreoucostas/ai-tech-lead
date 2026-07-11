# Forensic review (rev. 2, post-adversarial): framework self-sufficiency at enforcing standards

## Context

Maintainer goal: maximize self-sufficient standards enforcement while developers prompt only in
natural language. Consumer profile: **GitHub Copilot in VS Code, Windows, Bitbucket Data
Center**; Copilot Preview agent-hooks **unknown / probably off** in consumer orgs.

Method: three parallel exploration passes (hook surface matrix; prose/NL-routing; outer loop),
direct verification of contested claims, then an **adversarial critique pass** plus **live web
research** on Copilot's hook roadmap. Rev. 1 of this review was substantially revised by both:
the critique demoted two of its P0s and surfaced a missing higher-leverage layer; the web
research overturned a load-bearing assumption baked into the framework itself.

Deliverable (user-selected): **findings + roadmap only — no framework changes now.** On
approval: persist this review to `C:\temp\AIdrivenDev\.claude\plans\`, add one ADR line to
`docs/workspace-decisions.md`, commit the meta repo. No template-repo changes.

---

## Part 1 — Two headline findings

### 1a. The enforcement gap (corrected scope)

Rev. 1 claimed "~0% of enforcement is deterministic" for this profile. The adversarial pass
corrected that as overstated — three deterministic mechanisms DO survive: instruction-file
*loading* (AGENTS.md / copilot-instructions.md are harness-injected every request — obedience
is probabilistic, delivery is not), the consumer's **compiler/linters**, and `docs-sync-check`
once wired into the Bamboo/Jenkins CI that DC shops necessarily already run.

The defensible headline: **the framework ships no deterministic *code-standards* gate that
survives this consumer profile by default.** Under default settings (Preview hooks off, no CI
wiring done):

| Stage | Ships | Executes for this profile by default |
|---|---|---|
| Prompt time | `route-prompt` salience injection | Nothing (see 1b — this is now fixable) |
| Write time | `guard.*` (secrets, test-defeats, suppressions) | Nothing unless Preview agent-hooks enabled |
| Commit / push | — | Nothing (no git hooks shipped; DC runs no Pipelines) |
| PR / CI | `docs-sync-check` (host-agnostic, unwired); checks framework *state*, not code standards | Nothing until consumer wires it |

### 1b. The stale-assumption finding (new — from web research)

The framework's `hooks.json` comments, `enforcement-surfaces.md`, and CLAUDE.md §1 ("On
Copilot only this text reaches the model") rest on: *Copilot discards `userPromptSubmitted`
stdout.* **That is no longer true.** As of ~mid-2026:

- Copilot **CLI is GA** (Feb 2026); v1.0.65+ injects `userPromptSubmitted` →
  `additionalContext` into the model-facing prompt.
- **VS Code agent mode (Preview hooks)** consumes `UserPromptSubmit` → `additionalContext` and
  `SessionStart` → `hookSpecificOutput.additionalContext` — independently confirmed (Ken Muse,
  2026-06-18: "the model receives it as if it were built into the system prompt").
- The docs.github.com hooks-reference still says "output processed: No" for
  `userPromptSubmitted` — it lags the CLI changelog and the VS Code docs ("inject system
  context" is a listed UserPromptSubmit use case). A verification spike is mandatory before
  building.

Consequence: the routing / plan-gate / security-salience layer believed to be Claude-Code-only
**can be ported to Copilot surfaces** with an output-shape change and hooks.json registration —
no architectural work. Remaining gate: VS Code hooks are Preview and org-policy can disable
them.

### 1c. Answer to "is it just a matter of time until Copilot catches up — should we wait?"

**The inner loop: mostly yes, and it partially already happened.** CLI hooks are GA; VS Code
consumes prompt-time injection behind the Preview flag; the flag itself is the kind of thing
that GAs. So: do **not** build elaborate inner-loop workarounds — but **do** the cheap port
(WS-2) so the framework benefits the moment the flag flips, and fix the now-false claims in
shipped docs regardless (accuracy is non-negotiable per the framework's own rules).

**The outer loop and toolchain: no — waiting never covers it.** Analyzers, linters, CI
required-builds, and platform secret scanning enforce against *humans and every tool*, cannot
be `--no-verify`'d, and are valuable whatever Copilot ships. That layer is also where the
adversarial pass found the review's biggest omission (WS-1).

## Part 2 — Findings register (post-critique)

**Confirmed critical**
- F1. No surface-independent code-standards gate ships. The guard regex suite exists only
  inside AI-harness hooks that probably never fire for consumers.
- F2. **[NEW — biggest omission in rev. 1]** Every category guard blocks has a first-class,
  AST-accurate, everywhere-running toolchain equivalent the framework does not wire:
  `TreatWarningsAsErrors` + `.editorconfig` severities (kills `#pragma` value), xunit.analyzers
  (skipped tests, boolean asserts), `@typescript-eslint/ban-ts-comment` + eslint-comments +
  focused-test lint rules as errors, Bitbucket DC **native secret scanning** (8.12+,
  push-blocking, zero custom code). These run in the IDE (the agent itself sees red squiggles),
  every local build, and existing CI. The framework already has the exact delivery pattern:
  the `enforce-architecture` skill (NetArchTest).
- F3. Stale enforcement claims now shipped in `hooks.json` comments, `enforcement-surfaces.md`,
  CLAUDE.md §1 (see 1b) — the same "false enforcement claims" class purged in v0.23.0.
- F4. Bitbucket DC last mile is documentation, not implementation — but the fix is narrower
  than rev. 1 proposed: pre-receive needs DC *system admin* consumers don't have, and Code
  Insights presupposes a CI job anyway. The usable primitive is DC's **required-build merge
  check** driven by the consumer's existing Jenkins/Bamboo.

**Confirmed high**
- F5. Perception gap: consumers cannot tell which enforcement tier is active; degradation is
  silent (Preview off; `guard.sh` jq fail-open is loud but only in unread logs). No doctor
  exists. NOTE (critique): no script can *reliably* detect the Copilot hooks toggle (org policy
  is server-side) — any doctor must have an honest "cannot verify from a script" tier.
- F6. No consumer version-drift detection; README promises a `/framework-update` command that
  doesn't exist — though `install.ps1` already has a working update mode (reword, don't build).

**Medium / low**
- F7. Angular is missing audit-trail entirely (hook files absent, not just a hooks.json line) —
  pre-existing tracked debt in the forensic-audit memory, not a new find.
- F8. `post-write` triggers only on `.cs`/`.ts` — config/`.csproj` breakage gives no feedback.
- F9. Cheapest unused lever: **surface choice guidance** — guard works today on GA Copilot CLI;
  a one-paragraph consumer recommendation converts existing tested enforcement into coverage.

**What is already strong (keep):** honest `enforcement-surfaces.md`; dual-shape guard with
matcher-less Copilot registration; live template CI (both OS legs); BOM/twin/mirror gates;
host-agnostic `docs-sync-check` contract; brownfield adoption quarantine.

**Rev. 1 items killed by the critique (with reasons):**
- ~~Silent `core.hooksPath` git-hook wiring at P0~~ — invasive (husky collision; installer never
  touched `.git/` before), per-clone not per-team, `--no-verify` bypassable by the very actor
  it polices, sh-shim startup tax on every commit, brownfield false-positive trap. Survives
  only as opt-in convenience (WS-6).
- ~~`standards-scan.ps1/.sh` shipped twin family~~ — regex reimplementation of what analyzers do
  better (F2); the regexes stay only inside guard.* where they exist and are tested.
- ~~Pre-receive template + Code Insights publisher at P0~~ — median consumer can't install the
  former; the latter is an accessory to CI, and both would ship unverified (no DC instance),
  violating the workspace's own evidence rule. Backlog on first consumer request.
- ~~Advisory leanness heuristics~~ — false-positive farming; leanness is what the instructed
  layer and `/review` are for.
- ~~"applyTo instructions = deterministic salience"~~ — category error; deterministic
  *inclusion*, probabilistic compliance. Survives relabeled and descoped (WS-5).

## Part 3 — Revised roadmap (defensible ordering)

All template changes: both repos in lockstep (#1), `.ps1`/`.sh` twins (#3), mirror regen (#2),
CHANGELOG + `release.ps1` (#7), evidence-based verification per artifact type.

- **WS-1 (P0) — `enforce-standards` toolchain pack + skill.** Mirror the `enforce-architecture`
  pattern: a skill + sample config fragments that wire, per repo, `.editorconfig` /
  `Directory.Build.props` (warnings-as-errors, analyzer severities) + xunit.analyzers for
  dotnet; `ban-ts-comment`, eslint-comments, focused-test rules as errors for Angular. README
  line pointing DC consumers at native secret scanning (8.12+). Deterministic,
  surface-independent, constrains humans too, smallest shipped surface.
- **WS-2 (P0, spike-gated) — Copilot hook-injection port + stale-claim fixes.** Spike: pipe
  fixtures / live-test whether current Copilot CLI and VS Code agent mode inject
  `userPromptSubmitted`/`UserPromptSubmit` `additionalContext` (docs conflict — see 1b). If
  confirmed: register the event in `.github/hooks/hooks.json`, emit the per-surface output
  shapes from `route-prompt.*` and `session-start.*`, extend the hook test suite's surface
  matrix, and update `enforcement-surfaces.md` + CLAUDE.md §1 + hooks.json comments. If not
  confirmed: fix only the docs that overstate/understate, and record the finding.
- **WS-3 (P1) — One *verified* Jenkins/Bamboo required-build recipe.** Runs `docs-sync-check` +
  build + test + lint (WS-1 analyzers do the standards work — no custom scan server-side),
  wired as a DC required-build merge check (no admin plugin needed). Verified = actually
  executed against a local Jenkins container, evidence shown. Pre-receive / Code Insights:
  backlog on request.
- **WS-4 (P1) — Honest `framework-doctor`.** Three-tier report: verified-present (git hooks,
  pwsh/jq, version stamps — reusing `template-checks`, not reimplementing), verified-absent,
  and **cannot-verify-from-a-script** (Copilot hooks toggle → print a paste-into-agent-mode
  canary prompt whose deny/no-deny the developer observes). Includes the surface-choice
  guidance (F9). Maintainer meta-checks (lockstep) stay out of the shipped doctor.
- **WS-5 (P1) — Scoped instruction delivery via `.github/instructions/`, test files only.**
  `applyTo: **/*Tests.cs` / `**/*.spec.ts` carrying the test-integrity rules — highest marginal
  salience, lowest overlap with the always-on digest; works today with Preview hooks off.
  Generated by `/generate-copilot`; `template-checks` mirror-gate extended in the same task.
  No `applyTo: **` variant.
- **WS-6 (P2) — Opt-in git-hook convenience net.** `scripts/setup-git-hooks.ps1` (per-developer,
  explicit; `install.ps1 -GitHooks` flag), added-lines-only staged scan, detects and refuses on
  existing `core.hooksPath`/husky, documented as bypassable convenience — not enforcement.
- **WS-7 (P2) — Small fixes.** Port audit-trail to Angular (existing tracked debt); extend
  `post-write` trigger filter; reword README `/framework-update` promise to point at the
  installer's update mode; document boy-scout dedup semantics.

## Part 4 — Execution on approval (feedback-only scope)

1. Persist this review to
   `C:\temp\AIdrivenDev\.claude\plans\2026-07-02-self-sufficiency-forensic-review.md`.
2. Append one ADR line to `C:\temp\AIdrivenDev\docs\workspace-decisions.md`: enforcement
   strategy = toolchain-first (analyzers/CI) + cheap Copilot hook port; wait-for-Copilot
   applies to inner-loop workarounds only; roadmap WS-1…WS-7 recorded, nothing implemented.
3. Commit the meta repo (local-only).
4. No changes to either template repo.

## Verification (this scope)

- Plan file persisted; ADR line appended, prior entries untouched.
- `git -C C:\temp\AIdrivenDev status` clean after commit; both template repos show no changes.

## Sources (Copilot capability claims)

- https://code.visualstudio.com/docs/agent-customization/hooks (VS Code agent hooks, Preview;
  UserPromptSubmit "inject system context"; org-policy disable)
- https://docs.github.com/en/copilot/reference/hooks-reference (lagging: userPromptSubmitted
  "output processed: No")
- https://docs.github.com/en/copilot/how-tos/copilot-sdk/use-hooks/user-prompt-submitted
  (additionalContext output field)
- https://www.kenmuse.com/blog/guaranteed-copilot-context-with-hooks/ (2026-06-18; confirms
  model receives injected context on VS Code + CLI)
- https://github.blog/changelog/2026-02-25-github-copilot-cli-is-now-generally-available/
