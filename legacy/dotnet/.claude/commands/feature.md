Implement a new feature in this .NET codebase.

Read CLAUDE.md before starting. Every decision must comply with the conventions and patterns documented there.

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

After each subtask:
- Run `dotnet build` — fix any compilation errors before moving on
- Run `dotnet test` — fix any test failures before moving on
- Never leave the codebase in a broken state between subtasks

### Step 3 — Boy Scout
For every file you modified, check the Boy Scout Rule in CLAUDE.md. Apply relevant improvements. This is mandatory.

### Step 4 — Self-review
Before presenting:
- Review all changes against the Conventions section in CLAUDE.md
- Verify all tests pass
- Check: did this introduce a new pattern? → flag that CLAUDE.md may need updating
- Check: did this resolve a TECH_DEBT.md item? → flag for removal
- Check: does this contradict any existing convention? → ask before proceeding

### Step 5 — Present
Summarise what was implemented, what was tested, and any documentation drift to flag.
