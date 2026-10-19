# Specs — spec-driven development

This directory holds **persistent feature specs**, written by `/design` or by the agent from the `Done when:` lines of an approved plan; `/feature` implements against one; `/review` verifies the change against it. The spec is the contract for one feature. `AGENTS.md` (with the framework rules it points to) is the **constitution** every spec must comply with (Conventions, Leanness, Architecture Decisions).

Why persist it: an in-chat design is lost when the session ends. A spec on disk survives across sessions, tools (Claude Code *and* Copilot read it), and reviewers — closing the "the agent subtly missed the intent" gap that pure prompt-driven work suffers.

## Lifecycle

```
/design  → writes specs/<slug>.md (Status: Draft) — requirement, approach, and a Tasks checklist
  ↓        developer reviews & approves the spec (Status: Approved)
/feature → implements against the spec, checking off Tasks as each lands (Status: Implemented)
  ↓
/review  → verifies the spec is satisfied (acceptance criteria met + all Tasks checked)
  ↓        ship, then archive or delete the spec
```

## When to write one

Most non-trivial changes need no spec: the `Done when:` lines that open the agent's plan are the contract, and your go-ahead approves them. Write one when those lines outgrow the message or the work spans sessions, or run `/design` for deliberate design work: it thinks a larger change through, with alternatives and trade-offs, into `specs/<slug>.md`. A risk change (a known hazard, a security surface, a data shape or a contract others use) gets `Option A:` and `Option B:` in the plan itself. Leanness applies to docs too: don't write a spec longer than the change deserves.

## Template

One file per feature: `specs/<short-kebab-slug>.md`.

```markdown
## Spec: <feature name>
- **Status**: Draft | Approved | Implemented | Shipped
- **Created**: YYYY-MM-DD
- **Owner**: <name>

### Requirement
What and why. Who consumes it.

### Acceptance criteria
- [ ] ...
- [ ] ...

### Scope
- In: ...
- Out: ...

### Recommended approach
Specific files, layers, and patterns reused. Reference `AGENTS.md > Conventions` and `> Architecture Decisions`. Note any convention this pushes against.

### Alternatives considered
| Approach | Pros | Cons | Effort |
|----------|------|------|--------|

### Data flow
request → controller → application service → domain → persistence (adjust to the actual layers touched).

### Test strategy
What tests, at what level (unit / integration via WebApplicationFactory), and the key cases.

### Tasks
Ordered, checkable implementation steps the agent works through (the *how*; distinct from acceptance criteria, the *what*). Keep them small and verifiable; `/feature` checks each off in this file as it lands, so progress survives across sessions.
- [ ] ...
- [ ] ...

### Assumptions
Each assumption names what verified it, or is marked unverified for the developer to confirm.
| Assumption | Evidence (file, command or query), or "unverified — developer confirms" |
|------------|------------------------------------------------------------------------|

### Open questions
Decisions the developer must make before implementation.
```
