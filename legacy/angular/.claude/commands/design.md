Reason through the design of a change before writing any code. This is a thinking exercise, not an implementation task.

Anchor the design in CLAUDE.md > Repository Structure, Conventions, and Architecture Decisions.

## Input
$ARGUMENTS

## Execution

### DO NOT WRITE ANY CODE. This command produces a design document only.

### Step 1 — Understand the requirement
- What is the user trying to achieve?
- Who are the users/consumers of this feature?
- What are the acceptance criteria?
- What's the scope boundary — what is explicitly NOT part of this?

### Step 2 — Analyse the impact
- Which layers are affected (models, services, state, components, routing)?
- Which existing files will need to change?
- Which new files will need to be created?
- What existing patterns from CLAUDE.md should be reused?
- What data flows through the system for this feature?

### Step 3 — Consider approaches
Identify at least two approaches. For each:
- Brief description
- Pros and cons
- Which CLAUDE.md conventions it follows or conflicts with
- Effort estimate (S/M/L)

### Step 4 — Recommend
State your recommended approach and why. Be specific:
- Component structure (smart/dumb split)
- State management approach
- Service layer changes
- Routing changes
- Test strategy

### Step 5 — Surface questions
List anything you're unsure about or that the developer needs to decide before implementation. Don't make assumptions on domain-specific decisions.

## Output Format

```
## Design: [feature name]

### Requirement
[what and why]

### Scope
- In: ...
- Out: ...

### Recommended Approach
[description with specific files and patterns]

### Alternatives Considered
| Approach | Pros | Cons | Effort |
|----------|------|------|--------|

### Data Flow
[how data moves: API → service → state → component → template]

### Test Strategy
[what tests are needed and at what level]

### Open Questions
[decisions needed from the developer]
```

## Persist the spec (non-trivial features)

For anything beyond a trivial change, write the design above to `specs/<short-kebab-slug>.md` using the template in [`specs/README.md`](../../specs/README.md), with **Status: Draft**. This persists the contract across sessions and tools so `/feature` implements against it and `/review` verifies against it. For a trivial change, skip the file — say so and proceed.

`CLAUDE.md` is the **constitution**: the spec must comply with its Conventions, Leanness, and Architecture Decisions. Flag any place the requirement pushes against a convention so the developer decides *before* code is written.

When the developer is ready to implement, they run `/feature` — it picks up `specs/<slug>.md` and implements against it.
