---
description: "Full feature workflow: plan gate, ordered subtasks with build+test after each, Boy Scout on touched files, self-review against CLAUDE.md Conventions. Invoke for new multi-layer functionality when the inline feature rails are not enough."
argument-hint: "[feature description]"
---

Implement a new feature in this mixed .NET + Angular codebase. Every decision must comply with the conventions and patterns in CLAUDE.md.

## Input
$ARGUMENTS

## Execution

### Step 1 — Design check

**Check for a spec first.** If `specs/<slug>.md` exists for this work, read it and treat it as the contract — implement against its acceptance criteria, scope, and chosen approach, **working through its Tasks checklist and checking off each `- [ ]` → `- [x]` in the spec file as you complete it** (so progress survives across sessions), and flag any deviation. If the feature is non-trivial and no spec exists, recommend `/design` first (it writes one). For small changes, proceed without a spec.

Before writing any code, reason through:
- Which layers are affected — .NET: domain, application/service, API, infrastructure; Angular: models, services, state, components, routing?
- What existing patterns should be reused? Check Common Tasks in CLAUDE.md and the relevant skill in `.claude/skills/`.
- What are the failure modes?
- What tests will verify success?
- **Leanness check** (CLAUDE.md > Leanness): can this fit in existing files? Are you tempted to introduce a new interface / helper / wrapper / pipe / directive — is there a second consumer in this change-set? If not, defer the abstraction.

If the feature touches a clear file or area, spawn the `debt-radar` subagent via `Task` to surface bundleable TECH_DEBT entries before you scope the work. Fold any "Yes — same blast radius" entries into the plan when the marginal effort is small.

State the plan: files to create/modify, order of operations, test strategy, debt being bundled (if any).

### Step 2 — Execute in subtasks
Decompose into ordered subtasks. Execute each fully before starting the next:

Pick the subtask list(s) for the stack(s) this feature touches — a full-stack feature runs the .NET list first, then the Angular list.

**.NET:**
1. **Domain/model layer** — entities, value objects, enums + unit tests
2. **Service/application layer** — business logic, interfaces + unit tests
3. **API/controller layer** — DTOs, validators, controller actions + unit tests
4. **Integration / end-to-end test** — verify the full flow through the real pipeline via `WebApplicationFactory`, exercising the endpoint as a caller would (real routing, model binding, serialization, middleware), not just the unit

**Angular:**
1. **Models/interfaces** — data shapes, DTOs, enums + type tests if complex
2. **Service/state layer** — HTTP services, stores/signals, business logic + unit tests
3. **Component layer** — smart and dumb components, templates, styles + component tests
4. **Integration/E2E** — end-to-end verification of the feature flow

After each subtask, run the touched stack's gates — .NET: `dotnet build`, `dotnet test`, and `dotnet format`; Angular: `ng build`, `ng test --watch=false --browsers=ChromeHeadless`, and `ng lint` (if configured). Fix any compilation errors, test failures, or formatting/lint violations before starting the next subtask. Never leave the codebase in a broken state.

### Step 3 — Boy Scout
Apply the Boy Scout Rule (CLAUDE.md > Boy Scout Rule) to every file you modified. Mandatory.

### Step 4 — Wrap up
@.claude/workflow.md

### Step 5 — Present
Summarise what was implemented, what was tested, and any documentation drift to flag.
