# Reviewing changes and pull requests (.NET + Angular)

For a developer checking their own change before pushing, or reviewing a colleague's pull request,
with AI Tech Lead. The reviewers themselves are listed in [reference.md](reference.md#specialist-reviewers).

## Your own change, before you push

1. Type `/review`. With no argument it reviews everything uncommitted: staged, unstaged and new files.
   To review only some files, name them (`/review src/Orders.cs`); to review a range of commits, give
   it (`/review main...HEAD`).
2. It freezes the changes it will review, runs the specialist reviewers on them in parallel, runs
   your repository's own build and test commands itself rather than trusting a claim that they pass,
   and returns **APPROVE** or **REQUEST CHANGES** with the findings that decided it. A check your
   repository has no command for is reported as `not available`, not as passed.
3. Fix what it asks for, or say why not, and run it again.
4. If the change touches authentication, authorization, money or secrets, also run `/security-gate`
   (injection, authentication and route guards, secrets, unsafe HTML binding). The agent is told to run it on such changes by itself; check that it did.

In Copilot CLI, `/review` is the CLI's own command. Ask for this repository's review by name: "run
the review skill from this repository on my staged changes".

## A colleague's pull request

Review it locally, against the branch it will merge into:

```powershell
git fetch origin
git switch --detach origin/<source-branch>
```

Then type `/review origin/<target-branch>...HEAD`. The three dots review only what the pull request
adds, not what the target branch gained since. `/review` does not look a pull request up by number;
give it the two branches.

## Reading what it says

- **Conventions** findings compare the change with `AGENTS.md > Conventions`. If the convention is
  wrong rather than the code, fix `AGENTS.md` in the same pull request.
- **SOLID** findings are judged against your project evidence (the boundaries your code already
  uses), not against a shape the framework imposes; it never asks for an interface per service.
- **Bloat** findings push back on abstraction nobody needs yet; they are the counterweight to the
  cleanups the agent makes as it goes.
- **Test** findings ask whether each test would fail if the code it covers broke.
- **Debt** findings name `TECH_DEBT.md` entries the change touches: a chance to fix one on the way.

## Questions worth asking about a change an agent wrote

- Can the author explain why this design, in their own words? The plan the agent posted before
  coding, and its assumptions with their evidence, are a good place to start.
- Did a new test fail before the fix? The agent reports it; the diff should show it.
- Does the agent's closing report separate what was run, with its result, from what is only
  asserted? Do the plan's `Done when:` lines each have a check in the change?

## Why some of the framework rules read as they do

The always-loaded framework rules state each rule without its reason, to keep them short. The reasons,
for a reviewer who wants them:

- **A new test is seen to fail before it is trusted** (Verification Rule 9). AI-generated tests are the
  highest-risk for tautological or over-mocked assertions that pass even against broken code; a test you
  have watched fail cannot be vacuous.
- **No over-mocking** (Test leanness 14). AI assistants frequently produce tests that assert on mock
  interactions and would still pass if the real code were broken.
- **No tautological assertions** (Test leanness 15). A large share of LLM-generated assertions are weak
  or vacuous: they bank coverage without catching regressions.
- **Leanness** counterweights the Boy Scout Rule. Bloat is not style: it is AI-assisted development's
  highest-cost long-term failure mode.

## What review does not cover

The reviewers are model judgement, apart from the scripts that freeze the changes and report removed
assertions. A rule your CI does not enforce can still slip through, and nothing here stops a push.
The one gate that holds for every person and tool is the required build in your CI:
[ci-integration.md](ci-integration.md). Which local checks run in which client is in
[enforcement-surfaces.md](enforcement-surfaces.md).
