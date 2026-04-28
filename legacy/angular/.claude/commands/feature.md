Implement a new feature in this Angular codebase. Every decision must comply with the conventions and patterns in CLAUDE.md.

## Input
$ARGUMENTS

## Execution

### Step 1 — Design check
Before writing any code, reason through:
- Which layers are affected (models, services, state, components, routing)?
- What existing patterns should be reused? Check Common Tasks in CLAUDE.md and the relevant skill in `.claude/skills/`.
- What are the failure modes?
- What tests will verify success?

If the feature touches a clear file or area, spawn the `debt-radar` subagent via `Task` to surface bundleable TECH_DEBT entries before you scope the work. Fold any "Yes — same blast radius" entries into the plan when the marginal effort is small.

State the plan: files to create/modify, order of operations, test strategy, debt being bundled (if any).

### Step 2 — Execute in subtasks
Decompose into ordered subtasks. Execute each fully before starting the next:

1. **Models/interfaces** — data shapes, DTOs, enums + type tests if complex
2. **Service/state layer** — HTTP services, stores/signals, business logic + unit tests
3. **Component layer** — smart and dumb components, templates, styles + component tests
4. **Integration/E2E** — end-to-end verification of the feature flow

After each subtask, run `ng build`, `ng test --watch=false --browsers=ChromeHeadless`, and `ng lint` (if configured). Fix any compilation errors, test failures, or lint violations before starting the next subtask. Never leave the codebase in a broken state.

### Step 3 — Boy Scout
Apply the Boy Scout Rule (CLAUDE.md > Boy Scout Rule) to every file you modified. Mandatory.

### Step 4 — Wrap up
@.claude/workflow.md

### Step 5 — Present
Summarise what was implemented, what was tested, and any documentation drift to flag.
