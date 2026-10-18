---
applyTo: "**"
---

<!-- FRAMEWORK-OWNED — replaced wholesale by the installer on every update. Do not edit.
     Repo-specific rules belong in AGENTS.md (Conventions, Boy Scout Rule). -->

## Verification Rules

These apply to every workflow, before any convention-level rule.

<!-- @stack:verif-rules -->

**Verification command discovery.** For **build**, **test**, **format**, **lint**, **migration/deploy**, and **data-validation**, use exact applicable repository-evidenced commands (`AGENTS.md`, CI, scripts, manifests, or configuration); mark missing categories **not available**. `framework-owned/overwritten` paths in `framework-ownership.json` and paths in `framework-retirements.json` are framework, not application-command, evidence. Run them only when named by an explicit framework workflow or requested for framework diagnosis; report separately from application verification. Do not run a saved Verification Commands row naming one — flag `/rebootstrap`. Migration/deploy is **manual/CI-only** unless its exact command is an evidenced non-mutating validation/dry-run or developer-authorized known target; otherwise do not run it.
<!-- @stack:verif-rule9 -->

---

## Leanness

The Boy Scout Rule biases toward improvements. This counterweight requires every change also consider what to remove or not introduce.

### Defaults

<!-- @stack:lean-1-2 -->
<!-- @stack:lean-4-8 -->

### Test leanness

<!-- @stack:lean-test -->

---

## SOLID

<!-- @stack:solid-1-5 -->

---

## Agentic Workflow

When given any task, follow this execution model:

### 1. Classify the intent — and run that workflow without being asked
Natural-language requests trigger a workflow: classify silently, announce it in one line, and apply its rails. Ask if two fit; answer pure questions directly. Compound requests retain non-negotiables.
When a task matches a skill in `AGENTS.md > Common Tasks`, invoke that skill with your skill tool before planning or editing.

<!-- @stack:workflow-bullets -->
- **Debt cleanup** — *tech debt / cleanup debt*: confirm relevant `TECH_DEBT.md` items still exist and respect dismissed proposals unless materially changed evidence is named → apply Verification command discovery; without a harness, use the strongest evidenced check rather than adding one → recommend fix-now vs defer → update the file after fixes → report outcomes, validation, and diff.

**Scoped repository knowledge.** For a non-trivial change—including an ordinary feature/fix naming neither a skill nor path—locate task areas; select relevant scoped wiki, map, skill, or example entries; exclude irrelevant/nonapplicable ones; read bodies/references on demand. Investigate conflicting applicable claims and recheck decisive correctness-material evidence. Ask, or retain unresolved, only correctness-material gaps from unresolved drafts, opposing scopes, or stale, missing, or inaccessible evidence; never infer them. Name material evidence and run repository-evidenced verification. Do not preload the wiki or depend on a hook.

<!-- @stack:security-pass -->

### 2. Plan before coding — present, clarify, then get the go-ahead
For any non-trivial task, STOP before writing code and post a short plan:
- **Open the plan with `Done when:`**, the requirement restated as two to six observable criteria, one per line, each with a boundary example where a threshold, limit or state exists (the case that passes and the one that does not), then what is out of scope. Put it before any options or files. The developer corrects these lines; the go-ahead approves them.
- The files you'll create or modify, and the order of operations
- Evidenced validation; include tests only when a harness exists
- If the change adds an extension point or a third instance of an operation, and adding the next instance has a step that is easy to miss, name the one record you will add for that step unless one exists: a test over this repository's own instances that fails when one skips it (never a test of the framework, Test leanness #12), else one `AGENTS.md > Conventions` line, else, once this change makes three or more instances, a project skill draft under 3a-bis of `.claude/commands/bootstrap.md`; otherwise add none.
- Your assumptions, each with the evidence that verified it (a file, command or query), or marked *unverified — developer confirms*.
- If the request leaves a material gap, **ask first and plan after**: post at most five questions, each with the assumption you would otherwise make, and post the plan only once they are answered. Draw them from the tech-lead list — who consumes this and what breaks for them; what fails and how the developer would know in production; reversibility and rollback; data that moves or changes shape, including migration; blast radius against `FRAMEWORK-CONTEXT.md > Known Hazard Areas`. Do not guess past a material ambiguity to seem helpful — ask.
- **A risk change gets a design, not a file list.** Risk means it touches a `Known Hazard Areas` row, a security-sensitive surface (section 1), a data shape (schema, migration, event or message contract) or a public contract others consume (route, status code, package API). Post `Option A:` and `Option B:`, real alternatives each with its cost or what it breaks, then `Recommend:` one with the reason and the file list beneath it. No real alternative: say so in one line. Every other non-trivial change keeps the short plan above.
- For larger features, persist the plan as a spec to `specs/<slug>.md` (see `/design`) and implement against it

Then **wait for the developer's explicit go-ahead before editing code.** This catches wrong assumptions before wrong diffs and keeps the developer engaged rather than rubber-stamping. Skip only a trivial, unambiguous change (typo, one-liner), and say why.

### 3. Execute in verified subtasks
<!-- @stack:exec-subtasks -->

### 4. Bug-fix scope
Every bug-fix edit must be necessary for requested behaviour, existing caller/extension compatibility, or meaningful verification. Requested cleanup/refactoring is allowed; a touched file alone authorizes neither unrelated cleanup/logging nor a TODO. Necessary fixes may cross hunks. For changed public/protected signatures or virtual/override behaviour, identify any unrequested incompatibility; explicitly requested additions or breaks remain valid.

### 5. Self-review before presenting
Before presenting work as complete:
- Review your changes against `AGENTS.md > Conventions`
- Apply Verification command discovery; report what ran, was unavailable, or stayed manual/CI-only
- Check if the change introduces a new pattern → flag that AGENTS.md needs updating
- Check if the change resolves a TECH_DEBT.md item → flag for removal
- Check if the change contradicts any convention → ask whether to update the convention or change the implementation
- If the session surfaced a team-worthy gotcha, recipe, or failed approach, offer `remember-for-team`

### 6. Reconcile affected artifacts
Before finishing, inspect task effects on repository truth. Update affected writable canonical artifacts; regenerate derivatives from source. Follow their ownership, evidence, history, and security rules; never infer human intent. An affected artifact unreadable or unsafe to update is a blocker, not `none`. End with `Affected artifacts: none`, reconciled artifacts, or unresolved blockers.

---
