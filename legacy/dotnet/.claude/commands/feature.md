Implement a new feature in this .NET codebase. Every decision must comply with the conventions and patterns in CLAUDE.md.

## Input
$ARGUMENTS

## Execution

### Step 1 — Design check
Before writing any code, reason through:
- Which layers are affected (domain, application/service, API, infrastructure)?
- What existing patterns should be reused? Check Common Tasks in CLAUDE.md.
- What are the failure modes?
- What tests will verify success?

State the plan: files to create/modify, order of operations, test strategy.

### Step 2 — Execute in subtasks
Decompose into ordered subtasks. Execute each fully before starting the next:

1. **Domain/model layer** — entities, value objects, enums + unit tests
2. **Service/application layer** — business logic, interfaces + unit tests
3. **API/controller layer** — DTOs, validators, controller actions + unit tests
4. **Integration test** — end-to-end verification via WebApplicationFactory

After each subtask, run `dotnet build`, `dotnet test`, and `dotnet format`. Fix any compilation errors, test failures, or formatting violations before starting the next subtask. Never leave the codebase in a broken state.

### Step 3 — Boy Scout
Apply the Boy Scout Rule (CLAUDE.md > Boy Scout Rule) to every file you modified. Mandatory.

### Step 4 — Wrap up
@.claude/workflow.md

### Step 5 — Present
Summarise what was implemented, what was tested, and any documentation drift to flag.
