---
applyTo: "**"
---

<!-- FRAMEWORK-OWNED — replaced wholesale by the installer on every update. Do not edit.
     Repo-specific rules belong in CLAUDE.md (Conventions, Boy Scout Rule). -->

## Verification Rules

These apply to every workflow, before any convention-level rule. The difference between confident output and hallucinated output.

<!-- @stack:verif-rules -->

**Verification command discovery.** For **build**, **test**, **format**, **lint**, **migration/deploy**, and **data-validation**, use exact applicable commands from repository evidence (`CLAUDE.md`, CI, scripts, manifests, or configuration); mark missing categories **not available**. A delivery profile proves no technology or command. Migration/deploy is **manual/CI-only** unless the exact command is an evidenced non-mutating validation/dry-run or the developer authorizes a known target; otherwise do not run it.
8. **No future-proofing.** Do not add code for hypothetical requirements. Three similar lines is better than a premature abstraction.
<!-- @stack:verif-rule9 -->

---

## Leanness

The Boy Scout Rule biases toward adding improvements. This section is the counterweight: every change should also consider what to remove or what not to introduce. Bloat is not a stylistic preference — it is the highest-cost long-term failure mode of AI-assisted development.

### Defaults

<!-- @stack:lean-1-2 -->
3. **No abstract base class with one subclass.** Inline it.
<!-- @stack:lean-4-8 -->
9. **Deletion is a contribution.** If a change makes existing code obsolete, delete it in the same PR. Comment-out is never the answer; that is what version control is for.
<!-- @stack:lean-10 -->

### Test leanness

<!-- @stack:lean-test -->

### When you must add structure

<!-- @stack:lean-structure -->

---

## SOLID

<!-- @stack:solid-intro -->

<!-- @stack:solid-1-5 -->

<!-- @stack:solid-mechanism -->

<!-- @stack:solid-backstop -->

---

## Agentic Workflow

When given any task, follow this execution model:

### 1. Classify the intent — and run that workflow without being asked
Developers will rarely type a slash command. Treat any natural-language request as the trigger: silently classify it, **announce in one line which workflow you concluded** ("Reading this as a *fix*…"), and apply that workflow's rails below. If two workflows genuinely fit, ask one clarifying question first. If it's a pure question ("why does this throw?", "what does `X` do?"), just answer it — no workflow ceremony. You may combine workflows for a compound request ("fix this and add a test"), but **never silently drop a workflow's non-negotiables** to do so.

> These rails are the **canonical definition** of each workflow. `commands/*.md` and the `route-prompt` hook elaborate them but must not contradict them; `/docs-sync` checks they stay aligned. Where hooks are off (Copilot VS Code without Preview agent-hooks, Copilot CLI < v1.0.65) this text is the *only* thing that reaches the model — treat it as binding, not advisory.

<!-- @stack:workflow-bullets -->
- **Debt cleanup** — *tech debt / cleanup debt*: confirm relevant `TECH_DEBT.md` items still exist and respect dismissed proposals unless materially changed evidence is named → apply Verification command discovery; without a harness, use the strongest evidenced check rather than adding one → recommend fix-now vs defer → update the file after fixes → Boy Scout touched files → report outcomes, validation, and diff.

What is *guaranteed* vs merely *instructed* here depends on the surface — see `docs/enforcement-surfaces.md`. On Claude Code — and on Copilot where hooks are enabled (CLI ≥ v1.0.65, VS Code Preview agent-hooks) — these rails are reinforced by a per-prompt hook and a write-time guard; where hooks are off, only this text reaches the model.

<!-- @stack:security-pass -->

### 2. Plan before coding — present, clarify, then get the go-ahead
For any non-trivial task, STOP before writing code and post a short plan:
- The files you'll create or modify, and the order of operations
- Evidenced validation; include tests only when a harness exists
- Your assumptions, plus **clarifying questions** for anything underspecified (ambiguous scope, unclear acceptance criteria, competing approaches). Do not guess past a material ambiguity to seem helpful — ask.
- For larger features, persist the plan as a spec to `specs/<slug>.md` (see `/design`) and implement against it

Then **wait for the developer's explicit go-ahead before editing code.** This checkpoint is where a wrong assumption gets caught before it becomes a wrong diff — and where the developer stays engaged with the change instead of rubber-stamping output. Skip the wait only for a trivial, unambiguous change (typo, one-liner), and say that you're skipping it and why.

### 3. Execute in verified subtasks
For features and complex changes, decompose into ordered subtasks:
<!-- @stack:exec-subtasks -->

Each subtask leaves applicable evidenced verification green; never add a foreign harness to manufacture a check.
<!-- @stack:exec-buildtest -->

### 4. Boy Scout every touched file
Check the Boy Scout Rule list above. Apply relevant improvements to every file you modify.

### 5. Self-review before presenting
Before presenting work as complete:
- Review your changes against the Conventions section above
- Apply Verification command discovery; report what ran, was unavailable, or stayed manual/CI-only
- Check if the change introduces a new pattern → flag that this file needs updating
- Check if the change resolves a TECH_DEBT.md item → flag for removal
- Check if the change contradicts any convention → ask whether to update the convention or change the implementation
- If the session surfaced a team-worthy gotcha, recipe, or failed approach, offer `remember-for-team`
<!-- @stack:verif-conf-line -->

### 6. Flag documentation drift
At the end of your response, note if:
- A new pattern was introduced that should be documented here
- A TECH_DEBT.md entry was resolved or a new one discovered
- A SECURITY_FINDINGS.md entry was resolved or a new finding discovered
- `copilot-instructions.md` / `AGENTS.md` need regeneration (run `/generate-copilot` in Claude Code, or ask your agent to rewrite them from this file following the rules in `.claude/commands/generate-copilot.md`)

---
