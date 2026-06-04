# Reviewer's Guide (Angular)

> For a senior developer reviewing what this framework actually does — and whether it holds up. Start with [ARCHITECTURE.md](./ARCHITECTURE.md) for the map; this guide gives you a reading order, what each piece *guarantees*, how to *verify* the claims yourself, and the tradeoffs worth probing.

## 30-second orientation

One file is authored by hand — **`CLAUDE.md`**. Everything an AI tool actually obeys is either that file or generated from it and drift-checked. The framework's two opposing forces are **Boy Scout** (improve every file you touch) and **Leanness + `bloat-radar`** (resist over-abstraction); **SOLID** is mandated on top, reconciled with Leanness via a seam/data distinction. Determinism lives in **hooks** (block bad writes, type-check after writes) and **CI** (`scripts/docs-sync-check.sh`); judgement lives in **subagents** invoked by `/review` and `/security-review`.

## Reading order (≈45 min)

1. **`CLAUDE.md`** — the source of truth. Read Verification Rules, Leanness, SOLID, Boy Scout. *Guarantees:* every AI tool gets the same rules.
2. **`docs/ARCHITECTURE.md`** + open **`docs/architecture.html`** — how the pieces connect (diagrams).
3. **`.claude/commands/`** — the workflows. Read `feature.md`, `fix.md`, `review.md`, `bootstrap.md`. *Guarantees:* a repeatable execution model (plan → verified subtasks → Boy Scout → self-review).
4. **`.claude/agents/`** — `solid-check`, `convention-check`, `bloat-radar`, `security-auditor`, `debt-radar`. *Guarantees:* `/review` is backed by specialist passes, not one model's vibe.
5. **`.claude/hooks/`** — `guard` (PreToolUse), `post-write`, `route-prompt`, `boy-scout-check`. *Guarantees:* deterministic enforcement that doesn't rely on the model remembering.
6. **`tests/evals/cases.yaml`** — the executable spec of behavior. The fastest way to see what the framework *promises* (and refuses).
7. **`CHANGELOG.md`** — how it got here and why.

## How to verify the claims (don't take them on faith)

- **Single source + no drift:** run `bash scripts/docs-sync-check.sh` (it self-skips in the template repo via `.template-repo`; run it in a bootstrapped consumer repo). It checks CLAUDE.md is bootstrapped and within budget, AGENTS.md/copilot-instructions are current, `.github/skills` mirrors `.claude/skills`, and `architecture.html` is fresh.
- **Hooks actually fire:** `echo '{"prompt":"the toast button is broken"}' | bash .claude/hooks/route-prompt.sh` → should print the `/fix` rails. The guard: `echo '{"tool_name":"Write","tool_input":{"file_path":"a.ts","content":"// @ts-ignore"}}' | bash .claude/hooks/guard.sh; echo $?` → blocks (exit 2).
- **`/review` runs the build itself** (review.md Step 2) — it doesn't trust that tests pass.
- **Behavior is pinned by evals:** read `tests/evals/cases.yaml`. e.g. `angular-001` requires a DI abstraction (token) for an injected service (DIP); `angular-004` requires it **and** forbids a speculative provider layer (the SOLID-vs-future-proofing line).

## Tradeoffs worth probing (named honestly)

- **SOLID vs Leanness.** Literal SOLID (an abstraction/token per injected service) is mandated, which deliberately overrides Leanness #2 for services. The line: abstractions are required at the service seam; *data* (models/DTOs/enums) and *speculation* (factories for imagined providers) are still forbidden. Probe: does `solid-check` vs `bloat-radar` ever contradict? (They're scoped not to — services vs data.)
- **Literal SOLID is heavier in Angular than in .NET.** TS interfaces don't exist at runtime, so DIP means an `abstract class` DI token (or `interface` + `InjectionToken`) per service — more ceremony than idiomatic Angular. If the mandate is really backend-only, this side can be relaxed to principled-DIP.
- **Deterministic DIP backstop isn't wired.** `solid-check` is semantic (an LLM pass). The deterministic dependency-direction enforcement (**dependency-cruiser** / `eslint-plugin-boundaries`) is documented but must be added in the consumer repo.
- **Bitbucket Data Center.** Only the local layer applies — no Copilot cloud agent, no GitHub Actions, no Rovo Dev. The CI guardrail must be wired into Bamboo/Jenkins/pre-receive + Code Insights. See README.
- **Hooks need a shell.** git-bash or PowerShell; they degrade gracefully. Copilot only runs them via the CLI surface, not the cloud agent.
- **Evals are intentionally tiny** — a regression tripwire for the framework's own rules, not test coverage for your app.
- **Generated files will lag if not regenerated.** `AGENTS.md`, `copilot-instructions.md`, `.github/skills`, `architecture.html` are generated; review `CLAUDE.md`/`ARCHITECTURE.md`, and let `docs-sync` / CI catch staleness.

## Probing checklist

- [ ] Is `CLAUDE.md` genuinely the only hand-authored ruleset, with everything else generated + drift-checked?
- [ ] Do the workflows force *verification before reference* (anti-hallucination) and *tests before fixes*?
- [ ] Is quality enforced both deterministically (hooks, CI) **and** by judgement (subagents), not just one?
- [ ] Does the SOLID/Leanness reconciliation actually hold in the eval cases?
- [ ] Is Angular's literal-SOLID ceremony worth it for us, or should it relax to principled-DIP?
- [ ] For our platform (Bitbucket DC): is the CI guardrail wired where Actions can't run?
