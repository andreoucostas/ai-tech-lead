---
applyTo: "**"
---

<!-- FRAMEWORK-OWNED — replaced wholesale by the installer on every update. Do not edit.
     Repo-specific rules belong in CLAUDE.md (Conventions, Boy Scout Rule). -->

## Verification Rules

These apply to every workflow, before any convention-level rule. The difference between confident output and hallucinated output.

<!-- @stack:verif-rules -->

**Verification command discovery.** For **build**, **test**, **format**, **lint**, **migration/deploy**, and **data-validation**, use exact applicable repository-evidenced commands (`CLAUDE.md`, CI, scripts, manifests, or configuration); mark missing categories **not available**. `framework-owned/overwritten` paths in `framework-ownership.json` and paths in `framework-retirements.json` are framework, not application-command, evidence. Run them only when named by an explicit framework workflow or requested for framework diagnosis; report separately from application verification. Do not run a saved Verification Commands row naming one — flag `/rebootstrap`. A delivery profile proves no technology or command. Migration/deploy is **manual/CI-only** unless its exact command is an evidenced non-mutating validation/dry-run or developer-authorized known target; otherwise do not run it.
8. **No future-proofing.** Do not add code for hypothetical requirements. Three similar lines is better than a premature abstraction.
<!-- @stack:verif-rule9 -->

---

## Leanness

The Boy Scout Rule biases toward improvements. This counterweight requires every change also consider what to remove or not introduce. Bloat is not style — it is AI-assisted development's highest-cost long-term failure mode.

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
Natural-language requests trigger a workflow: classify silently, announce it in one line, and apply its rails. Ask if two fit; answer pure questions directly. Compound requests retain non-negotiables.

> These rails are canonical. Commands and `route-prompt` may elaborate, not contradict; carriers and hooks remain independent.

<!-- @stack:workflow-bullets -->
- **Debt cleanup** — *tech debt / cleanup debt*: confirm relevant `TECH_DEBT.md` items still exist and respect dismissed proposals unless materially changed evidence is named → apply Verification command discovery; without a harness, use the strongest evidenced check rather than adding one → recommend fix-now vs defer → update the file after fixes → report outcomes, validation, and diff.

Registered, observed, and instructed differ by surface; these rails remain binding.

**Scoped repository knowledge.** For a non-trivial change—including an ordinary feature/fix naming neither a skill nor path—locate task areas; select relevant scoped wiki, map, skill, or example entries; exclude irrelevant/nonapplicable ones; read bodies/references on demand. Investigate conflicting applicable claims and recheck decisive correctness-material evidence. Ask, or retain unresolved, only correctness-material gaps from unresolved drafts, opposing scopes, or stale, missing, or inaccessible evidence; never infer them. Name material evidence and run repository-evidenced verification. Hook registration alone proves neither firing nor consumption; do not preload the wiki or depend on a hook.

<!-- @stack:security-pass -->

### 2. Plan before coding — present, clarify, then get the go-ahead
For any non-trivial task, STOP before writing code and post a short plan:
- The files you'll create or modify, and the order of operations
- Evidenced validation; include tests only when a harness exists
- Your assumptions, plus **clarifying questions** for anything underspecified (ambiguous scope, unclear acceptance criteria, competing approaches). Do not guess past a material ambiguity to seem helpful — ask.
- For larger features, persist the plan as a spec to `specs/<slug>.md` (see `/design`) and implement against it

Then **wait for the developer's explicit go-ahead before editing code.** This catches wrong assumptions before wrong diffs and keeps the developer engaged rather than rubber-stamping. Skip only a trivial, unambiguous change (typo, one-liner), and say why.

### 3. Execute in verified subtasks
For features and complex changes, decompose into ordered subtasks:
<!-- @stack:exec-subtasks -->

Each subtask leaves applicable evidenced verification green; never add a foreign harness to manufacture a check.
<!-- @stack:exec-buildtest -->

### 4. Bug-fix scope
Every bug-fix edit must be necessary for requested behaviour, existing caller/extension compatibility, or meaningful verification. Requested cleanup/refactoring is allowed; a touched file alone authorizes neither unrelated cleanup/logging nor a TODO. Necessary fixes may cross hunks. For changed public/protected signatures or virtual/override behaviour, identify any unrequested incompatibility; explicitly requested additions or breaks remain valid.

### 5. Self-review before presenting
Before presenting work as complete:
- Review your changes against the Conventions section above
- Apply Verification command discovery; report what ran, was unavailable, or stayed manual/CI-only
- Check if the change introduces a new pattern → flag that this file needs updating
- Check if the change resolves a TECH_DEBT.md item → flag for removal
- Check if the change contradicts any convention → ask whether to update the convention or change the implementation
- If the session surfaced a team-worthy gotcha, recipe, or failed approach, offer `remember-for-team`
<!-- @stack:verif-conf-line -->

### 6. Reconcile affected artifacts
Before finishing, inspect task effects on repository truth. Update affected writable canonical artifacts; regenerate derivatives from source. Follow their ownership, evidence, history, and security rules; never infer human intent. An affected artifact unreadable or unsafe to update is a blocker, not `none`. End with `Affected artifacts: none`, reconciled artifacts, or unresolved blockers.

---
