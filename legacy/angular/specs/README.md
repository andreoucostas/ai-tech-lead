# Specs — spec-driven development

This directory holds **persistent feature specs**. For non-trivial features, `/design` writes a spec here *before any code is written*; `/feature` implements against it; `/review` verifies the change against it. The spec is the contract for one feature. `CLAUDE.md` is the **constitution** every spec must comply with (Conventions, Leanness, Architecture Decisions).

Why persist it: an in-chat design is lost when the session ends. A spec on disk survives across sessions, tools (Claude Code *and* Copilot read it), and reviewers — closing the "the agent subtly missed the intent" gap that pure prompt-driven work suffers.

## Lifecycle

```
/design  → writes specs/<slug>.md (Status: Draft)
  ↓        developer reviews & approves the spec (Status: Approved)
/feature → implements against the spec (Status: Implemented)
  ↓
/review  → verifies the change satisfies the spec
  ↓        ship, then archive or delete the spec
```

## When to write one

A spec is for work that spans multiple files/layers or carries real design risk. **Small, obvious changes don't need a spec** — just use `/feature`. Leanness applies to docs too: don't write a spec longer than the change deserves.

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
Specific files, layers, and patterns reused. Reference `CLAUDE.md > Conventions` and `> Architecture Decisions`. Note any convention this pushes against.

### Alternatives considered
| Approach | Pros | Cons | Effort |
|----------|------|------|--------|

### Data flow
API → service → state (store/signals) → smart component → dumb component → template (adjust to the actual layers touched).

### Test strategy
What tests, at what level (unit, component via TestBed/harness, e2e), and the key cases.

### Open questions
Decisions the developer must make before implementation.
```
