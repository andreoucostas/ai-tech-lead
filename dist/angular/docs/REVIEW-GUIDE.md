# Reviewer's Guide (Angular)

> For a senior developer reviewing what this framework actually does — and whether it holds up. Start with [ARCHITECTURE.md](./ARCHITECTURE.md) for the map; this guide gives you a reading order, what each piece *guarantees*, how to *verify* the claims yourself, and the tradeoffs worth probing.

## 30-second orientation

One file is authored by hand — **`CLAUDE.md`**. Supported clients load it or generated carriers from it; actual model delivery and hook enforcement vary by host. The framework's two opposing forces are **Boy Scout** and **Leanness + `bloat-radar`**; deterministic controls apply only on their documented hooked/CI surfaces.

## Reading order (≈45 min)

1. **`CLAUDE.md`** — the authored framework-rule source. Read Verification Rules, Leanness, SOLID, Boy Scout; verify the client carrier and host support before relying on delivery.
2. **`docs/ARCHITECTURE.md`** + open **`docs/architecture.html`** — how the pieces connect (diagrams).
3. **`.claude/commands/`** — the workflows. Read `feature.md`, `fix.md`, `review.md`, `bootstrap.md`. *Guarantees:* a repeatable execution model (plan → verified subtasks → Boy Scout → self-review).
4. **`.claude/agents/`** — `solid-check`, `convention-check`, `bloat-radar`, `security-auditor`, `debt-radar`. *Guarantees:* `/review` is backed by specialist passes, not one model's vibe.
5. **`.claude/hooks/`** — `guard` (PreToolUse), `post-write`, `route-prompt`, `boy-scout-check`. *Guarantees only when live:* deterministic actions on the supported events; shell writes and unavailable hooks remain outside that scope.
6. **`tests/evals/cases.yaml`** — a readable catalogue of intended behavior. The fastest way to see what the framework *promises* (and refuses).
7. **`CHANGELOG.md`** — how it got here and why.

## How to verify the claims (don't take them on faith)

- **Single source + no drift:** run `pwsh -NoProfile -File scripts/docs-sync-check.ps1` (it self-skips in the template repo via `.template-repo`; run it in a bootstrapped consumer repo). It checks CLAUDE.md is bootstrapped and within budget, AGENTS.md/copilot-instructions are current, project skills live only under `.claude/skills`, and `architecture.html` is fresh.
- **Hook-script input/output fixtures (not host firing):** pipe representative JSON into `pwsh -NoProfile -File .claude/hooks/route-prompt.ps1` and `.claude/hooks/guard.ps1`; confirm `/fix` rails and exit 2 for a prohibited suppression. These direct commands prove parser and output-shape behavior only; they do not prove that a client fires the event or consumes the output.
- **`/review` derives and runs applicable repository-evidenced checks itself** (review.md Step 2) —
  it does not trust unverified pass claims, and reports unsupported categories as `not available`.
- **Behavior is documented as cases:** read `tests/evals/cases.yaml`. e.g. `angular-001` and `angular-004` derive a service seam from named project evidence and reject an unsupported token, container, or provider layer.

## Tradeoffs worth probing (named honestly)

- **SOLID vs Leanness.** Project evidence and correctness needs select a service seam; the framework does not mandate an abstraction, token, or container. Preserve evidenced boundaries, while *data* (models/DTOs/enums) and speculative provider layers remain out of scope. Probe: does `solid-check` distinguish project evidence from speculation?
- **Angular DI is project-shaped.** TypeScript interfaces are not runtime tokens, but this does not make `abstract class` or `InjectionToken` a framework default; follow the consumer's evidenced mechanism when a seam is needed.
- **Deterministic DIP backstop isn't wired.** `solid-check` is semantic (an LLM pass). A consumer may choose an evidenced dependency-direction check; until one is wired, report that limitation rather than inventing dependency-cruiser or another library.
- **Bitbucket Data Center.** Only the local Windows layer applies — Copilot coding-agent cloud hook execution is unsupported. Wire the PowerShell CI guardrail into Bamboo/Jenkins on a self-hosted Windows agent and require its build status. See README.
- **Hooks need a working interpreter and client support.** Dated canaries cover only the capabilities they exercised, not every registered event; Copilot CLI `agentStop` firing and its queue write remain unverified, as do current VS Code Preview-hook lifecycles. VS Code hooks are Preview, off by default, and org-gated; shell writes are outside the editor guard.
- **Evals are intentionally tiny** — a regression tripwire for the framework's own rules, not test coverage for your app.
- **Generated files will lag if not regenerated.** `AGENTS.md`, `copilot-instructions.md`, and `architecture.html` are generated; review `CLAUDE.md`/`ARCHITECTURE.md`, and let `docs-sync` / CI catch staleness. Project skills are canonical under `.claude/skills`; a legacy `.github/skills` tree is a migration failure because it can shadow them.

## Probing checklist

- [ ] Is `CLAUDE.md` genuinely the only hand-authored ruleset, with everything else generated + drift-checked?
- [ ] Do the workflows force *verification before reference* (anti-hallucination) and *tests before fixes*?
- [ ] Which hooks and CI jobs are actually live and blocking here, and which controls remain instruction or judgement only?
- [ ] Do the eval cases derive the seam from named project evidence rather than a framework default?
- [ ] Does Angular DI follow its evidenced mechanism without adding token ceremony?
- [ ] For our platform (Bitbucket DC): is the CI guardrail wired where Actions can't run?
