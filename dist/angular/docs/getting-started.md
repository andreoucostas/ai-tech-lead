# Getting started

For a developer in a repository where AI Tech Lead has just been installed. It takes you from the
install commit to your first reviewed fix. What every command and file does is in
[reference.md](reference.md); why the framework works this way is in [playbook.md](playbook.md).

## What the install changed

The install is one commit in your repository; nothing outside it changed.

- **`AGENTS.md`** at the root holds your repository's conventions; every AI tool here follows it.
  Until step 2 it is a template. **`CLAUDE.md`** only imports it, and the framework's own rules,
  for Claude Code.
- **`.claude/`, `.agents/` and `.github/`** hold the workflows, specialist reviewers, skills and
  hooks. The framework replaces them on every update, so do not edit them.
- **`docs/`** holds these guides, plus `docs/architecture-decisions.md` and `docs/wiki/`, which are
  your team's.
- **`TECH_DEBT.md`, `SECURITY_FINDINGS.md`, `LEARNINGS.md` and `FRAMEWORK-CONTEXT.md`** are registers
  the agent reads and keeps up to date with you.

## 1. Check your machine (once per developer)

From the repository root:

```powershell
pwsh -NoProfile -File scripts/framework-doctor.ps1
```

It lists which controls are live on your machine. The hooks need Windows, PowerShell 7 (or Windows
PowerShell 5.1), and Claude Code 2.1.141 or newer, or GitHub Copilot. The workflows and rules work
without them; [enforcement-surfaces.md](enforcement-surfaces.md) says exactly what each client
enforces.

## 2. Populate `AGENTS.md` from your code (once per repository)

Start Claude Code, or an interactive Copilot CLI session, at the repository root and type:

- `/bootstrap` if the repository had no AI tooling before, or
- `/adopt` if it had some (a `CLAUDE.md`, `.cursorrules`, Copilot instructions). The installer moved
  any file it would have overwritten to `docs/pre-adoption/`; `/adopt` merges that material in and
  then runs `/bootstrap`. Nothing is deleted.

Until one of them has run, every new session reminds you which one. Only you can start it: the agent
will tell you to type it rather than run it.

`/bootstrap` reads the code, asks you a few questions where the code is ambiguous, and writes
`AGENTS.md`, `TECH_DEBT.md` and parts of `FRAMEWORK-CONTEXT.md`. For an operation your code repeats
it may draft a project skill for your team to approve.

## 3. Review what it wrote

Read `AGENTS.md`, especially **Conventions**, and fix anything wrong: a line marked
`<!-- INFERRED -->` is where the code gave mixed signals. Review `TECH_DEBT.md` and any drafted
skills. Commit on a branch and open a pull request, pasting the block `/bootstrap` printed under
"Paste this into your PR" so your team sees what still needs a human answer.

## 4. Your first task

Describe it in plain words, for example:
"the export button does nothing when the list is empty".

What happens next:

1. The agent says in one line which workflow it is following (here, a bug fix).
2. If something material is unclear, it asks up to five questions first, each with the assumption it
   would otherwise make.
3. It posts a plan that opens with `Done when:`, the request restated as a few checkable criteria
   with their edge cases, then the files it will change, how it will verify the change, and its
   assumptions, each with the evidence behind it. For a risky change (a known hazard, security, a
   data shape or a contract others use) it lays out `Option A:` and `Option B:` and recommends one.
   Nothing has changed yet.
4. You reply with a go-ahead, or correct the plan; your go-ahead approves the `Done when:` lines.
5. For a bug, where your repository has a test harness, it writes a test that fails first, then
   fixes the code and runs your repository's own build and test commands.
6. It ends with a report: what changed, the checks it ran with their results, and anything it could
   not verify.

Where hooks run, writing a `.ts` file triggers `tsc --noEmit` and a component template triggers
`ngc --noEmit`, and the agent sees any errors.
A write that adds a warning suppression or a hardcoded secret is blocked; fix the cause rather than
work around it.

You can also name a workflow directly:

| Command | Use it to |
|---|---|
| `/fix [description]` | Find the cause, add a regression test where a harness exists, fix |
| `/feature [description]` | Add a feature at the boundaries your code already uses |
| `/design [description]` | Think a design through, with trade-offs, without writing code |
| `/refactor [target]` | Restructure in verified steps without changing behaviour |
| `/test [target]` | Add tests that follow your existing test patterns |
| `/debt [area]` | Find and fix recorded tech debt |
| `/review` | Review your changes as a tech lead: APPROVE or REQUEST CHANGES |
| `/security-gate` | Security review of a change |
| `/docs-sync` | Check `AGENTS.md` and the other docs for drift from the code |

## 5. Review before you push

Run `/review` on your changes before opening the pull request; it runs specialist reviewers in
parallel and gives a verdict. When a change touches authentication, money or secrets, the agent also
runs `/security-gate`. To review a colleague's pull request, follow
[REVIEW-GUIDE.md](REVIEW-GUIDE.md).

## From then on

- **Keep `AGENTS.md` true.** When a convention changes, change `AGENTS.md` in the same pull request;
  `/docs-sync` reports drift between the docs and the code.
- **Record what the team learns.** Ask for the `remember-for-team` skill to draft a gotcha or recipe
  for the wiki, and `create-adr` to record an architecture decision.
- **Per-developer preferences** ("skip the summaries") belong in your own agent memory, not in
  `AGENTS.md`.
- **Updates** are usually one person's job: [upgrade-checklist.md](upgrade-checklist.md).

## When something looks wrong

- **The agent ignores your conventions.** Check that `AGENTS.md` is populated (the session reminder
  says so if it is not), then run the doctor from step 1.
- **A write was blocked.** Read the reason in the agent's output and fix the cause; a shell command
  that writes files is not checked, so do not route around the guard.
- **In Copilot CLI, `/review` runs the CLI's own review.** Ask for this repository's review by name
  instead: "run the review skill from this repository on my staged changes".
- **Something is enforced in one client but not another.** That is expected; see
  [enforcement-surfaces.md](enforcement-surfaces.md).
