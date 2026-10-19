# How AI Tech Lead works, and why (.NET)

For a tech lead deciding whether to adopt AI Tech Lead, and for anyone who wants to know why it
behaves as it does: the problem, the approach, what is guaranteed, what it costs, its limits, and how
to check the claims. To start using it, read [getting-started.md](getting-started.md); for the exact
list of commands and files, [reference.md](reference.md).

## The problem this solves

Teams that adopt AI coding tools without a framework hit the same wall after a few months. The AI is fast, but it's generic. It doesn't know that your team wraps EF Core queries in the service layer, not the controller. It doesn't know that you use FluentValidation, not DataAnnotations. It doesn't know about the tech debt in the payments module that you've been carefully routing around. It doesn't know that the last three PRs introduced async voids that nobody caught in review.

The result: the AI accelerates you in the wrong direction. Code quality drifts. Conventions fragment. Junior developers adopt whatever the AI suggests, which is the average of the internet, not the average of your best engineers.

The deeper problem is that AI tools are additive by default. They add code, add abstractions, add interfaces "for testability", add comments to explain what they just wrote. Left unchecked, this produces a codebase that's larger, more complex, and harder to reason about than the one you started with — all while passing tests.

This framework is the counterweight.

---

## The Core Idea: Trojan Horse

Every feature ticket, every bug fix, every PR is an opportunity to leave the codebase better than you found it. Most teams know this as the "Boy Scout Rule" but treat it as optional. This framework makes it automatic.

When you run `/feature add export button`, the command doesn't just implement the feature — it also:
- Applies Boy Scout improvements to every file it touches
- Checks for nearby tech debt that can be bundled into the same change
- Self-reviews against conventions before presenting
- Flags any documentation drift

After three months of this, every actively-developed area is cleaner, better-tested, and consistent — without a single dedicated tech debt sprint.

---

## Two-Tier Architecture

### Tier 1 — Directed (agent-mode reasoning)
**Files**: `AGENTS.md` (authored single source of truth), `CLAUDE.md` (Claude Code stub that imports it), plus optional `.github/instructions/*.instructions.md` for path-scoped rules

Supported GitHub Copilot agent surfaces, GitHub code review, Codex, and Cursor load `AGENTS.md` directly; Claude Code loads it, and the framework rules, through the `CLAUDE.md` imports. Gemini defaults to `GEMINI.md`, and Aider sees these rules only when explicitly configured to read them. Conventions, architecture, common tasks, agentic workflow. When a developer types a natural language request, the agent follows the applicable carrier and workflow automatically. Per-developer working preferences live in Claude Code's persistent memory, not in AGENTS.md.

### Tier 2 — Explicit (workflow commands)
**Files**: `.claude/commands/*.md` (canonical), `.agents/skills/*/SKILL.md` (Copilot skill wrappers)

Purpose-built workflows invoked via `/command` in either Claude Code or Copilot (VS Code and Copilot CLI). Each encodes a specific methodology: `/feature` decomposes into subtasks, `/fix` reproduces first and uses a red regression test when an applicable harness exists, and `/design` forces design thinking before code. The Copilot skill wrappers delegate to the canonical `.claude/commands/` files — single source of truth per workflow.

### Automated Verification (Hooks)
**File**: `.claude/settings.json`

In a repository with an evidenced .NET application, hooks fire automatically after Claude Code writes `.cs` files. They run incremental `dotnet build` against the nearest solution, or the nearest project when no solution exists, to catch compilation errors immediately. A warehouse-only repository has no `.cs` write or application build to trigger. Tests are run explicitly within command workflows, not as hooks — full test suites are too slow for per-file-write execution.

---

## How Tiers Work Together

```
Developer types: "add export button to dashboard"
                    │
                    ▼
         AGENTS.md + framework rules (Tier 1)
         Classifies as: feature
         Routes to: feature workflow
                    │
                    ▼
         /feature methodology (Tier 2)
         Plan → Subtask → Build → Test → Boy Scout → Self-review
                    │
                    ▼ (after each file write)
         Hooks (settings.json)
         applicable post-write build → catch compilation errors → self-correct
```

---

## The rules the instruction files encode

- **Verification Rules:** never invent APIs, checking the version this repo pins;
  failures are signals, never silenced.
- **Leanness:** the counterweight to Boy Scout cleanups; no abstraction over data or for speculation.
- **SOLID:** single responsibility and the rest, with any injected-service boundary derived from
  project evidence and correctness needs; the framework requires no interface or DI container, and
  data carriers are exempt.
- **Bug-fix scope:** every edit serves the requested outcome, compatibility or verification.
- **Trojan Horse:** nearby debt rides along with feature and fix work, so quality compounds without
  debt sprints.
- **Financial-domain invariants:** decimal precision, idempotency, check-then-act races and rounding
  are treated as always possible, even in internal code.

---

## What is guaranteed, and what is only instructed

Every rule reaches the agent in one of three ways, and they are not equally strong:

- **Enforced by a hook:** a script runs on an event and the client acts on its result, whatever the
  model would prefer: a write that adds a warning suppression or a hardcoded secret is blocked, a
  compile error after a write is shown to the agent. This holds only where the client runs hooks
  (native Windows, with PowerShell, in a client and version that fires that event) and only for
  writes made through the editor or file tools; a shell command that writes a file is not inspected.
- **Instructed:** the framework rules and `AGENTS.md` are loaded into the agent's context and it is
  told to follow them: plan before coding, verify before referencing, a failing test before a fix.
  Strong, but a model can skip an instruction under a casual prompt or a long context.
- **On demand:** supporting material such as `docs/defaults.md` is there for the agent to open; it
  may not open it.

The required build in your CI is the only control that holds for every person and every tool:
[ci-integration.md](ci-integration.md). What each client enforces, event by event, with the date
each behaviour was observed, is in [enforcement-surfaces.md](enforcement-surfaces.md). The Copilot
cloud coding agent runs no hooks, and Linux, WSL and macOS are not supported.

## What it costs

- **Setup:** one install commit, then one `/bootstrap` (or `/adopt`) session per repository, plus the
  time to review the `AGENTS.md` it writes. Each developer runs `scripts/framework-doctor.ps1` once.
- **Platform:** Windows; Git; PowerShell 7, or Windows PowerShell 5.1; Claude Code 2.1.141 or newer,
  or GitHub Copilot in VS Code or Copilot CLI.
- **Every session:** `AGENTS.md` and the framework rules load on every turn. `/bootstrap` keeps the
  sections it writes to about 6 KB and the whole file under 16 KB; the session preload and the
  per-prompt workflow rules add a little more.
- **Every change:** the plan gate waits for your go-ahead, and `/review` runs several reviewers in
  parallel (three of them on Haiku). That is slower than accepting the first draft, by design.
- **Ongoing:** someone keeps `AGENTS.md` true and applies updates with
  [upgrade-checklist.md](upgrade-checklist.md), which also describes removing the framework.

## Limits worth knowing

- **SOLID against Leanness.** Your project's evidence selects service boundaries; the framework does
  not demand an interface or a container. `solid-check` is a model's judgement; a deterministic check
  of dependency direction exists only if you wire one (the `enforce-architecture` skill).
- **Bitbucket Data Center** gets everything local, but none of GitHub's cloud features; wire the
  required build into Bamboo or Jenkins.
- **Hooks need a working interpreter and client support.** Some events have not been observed firing
  on every client; [enforcement-surfaces.md](enforcement-surfaces.md) says which.
- **The eval cases in `tests/evals/` are deliberately small:** a catalogue of intended behaviour, not
  test coverage for your application.
- **Project skills live only in `.claude/skills/`.** A legacy `.github/skills` folder can shadow them.

## Check the claims yourself

- Read `AGENTS.md`, then the framework rules it points to
  (`.github/instructions/framework-rules.instructions.md`), then the workflows in
  `.claude/commands/` (`feature.md`, `fix.md`, `review.md`, `bootstrap.md`) and the reviewers in
  `.claude/agents/`.
- Run `pwsh -NoProfile -File scripts/docs-sync-check.ps1` in a bootstrapped repository: it checks that
  `AGENTS.md` is populated and within budget, that `CLAUDE.md` imports it, and that project skills are
  in one place.
- Pipe a sample event into a hook to see its output, for example a write that adds a suppression into
  `.claude/hooks/guard.ps1`, which should exit 2. That proves the script, not that your client runs it;
  `scripts/framework-doctor.ps1` and the canaries it lists check that.
- Read `tests/evals/cases.yaml`: the fastest way to see what the framework promises and refuses.
- Ask of any control: is it live and blocking here, or is it an instruction?

---

## Design Culture: Keeping Developers Thinking

### The risk
This framework makes it easy to produce working code without understanding it. A developer can type `/feature add export button` and get a complete, tested implementation without understanding any of it. That's dangerous if left unchecked.

### The plan's `Done when:` lines are the gate
For any non-trivial request, typed in plain words or through a command, the agent opens its plan with `Done when:`: the request restated as a few observable criteria, each with its boundary case, then what is out of scope. It edits nothing until the developer's go-ahead, and that go-ahead approves those lines. The developer's job is to correct them; if they can't, they don't understand the problem. `/design` is for deliberate design work: it thinks a larger change through, with alternatives and trade-offs, into `specs/<slug>.md`.

### PR reviews test understanding, not output
The `/review` command checks the code. You check the developer. Use this PR template:

```markdown
## Done when
<the plan's `Done when:` lines as approved>

## Design Rationale
- What approach did you take and why?
- What alternatives did you consider?
- What existing patterns did you follow? (reference Architecture Decisions in AGENTS.md)
- What would break if this was implemented differently?
```

Paste the same lines after the scope when you run `/review` in a new session; it reports how many of them a test pins.

If a developer consistently can't explain their own code, that's a performance signal. The framework amplifies whatever the developer already is.

---

## When to Skip the Boy Scout Rule

The Boy Scout Rule is mandatory during normal development. Skip it during:
- **Hotfixes**: production is down, fix the issue, get out
- **Time-sensitive incidents**: the priority is resolution, not cleanup
- **Proof-of-concept branches**: throwaway code doesn't need polishing

Do not leave a TODO merely for unrelated deferred cleanup. Use `/debt` only for a real, separately owned debt item.

---

## Keeping Things in Sync

### When conventions change
Update these in the same commit:
- [ ] `AGENTS.md` — the source of truth
- [ ] `TECH_DEBT.md` if debt priorities shifted
- [ ] Relevant commands in `.claude/commands/` if workflow changed

### Quarterly sync
Run `/docs-sync` to cross-check all documentation against the codebase. It reports drift without auto-applying changes.

---

## Token Economy & Prompt Caching

Anthropic-API consumers (Claude Code, in-house tooling, eval harness) can dramatically cut cost and latency by structuring requests to hit the prompt cache. The cache TTL is short (~5 minutes) but the cache prefix is keyed on exact bytes — any drift in early content invalidates the whole prefix.

The framework is structured so the cache-friendly prefix is large and stable:

1. **`AGENTS.md` is mostly stable.** Conventions, architecture decisions, common tasks, agentic workflow, boy-scout rules — these change at human pace, not per-session. Treat the whole file as one cache prefix candidate.
2. **`FRAMEWORK-CONTEXT.md` is mostly stable.** Maintainer-curated sections rarely change between sessions. The auto-populated "Detected Framework Packages" table changes when csproj/Directory.Packages.props change — usually rare.
3. **Volatile content lives in hooks, not in `AGENTS.md`.** `SessionStart` injects branch + recent commits + debt heat at session start; `UserPromptSubmit` injects routed-intent rails; `PostToolUse` injects build output. All of these append AFTER the AGENTS.md prefix, preserving cache integrity.

When you author or extend `AGENTS.md`:

- **Do not** paste current branch state, recent commit lists, or per-developer notes into the file. They cause cache misses and belong in hooks or memory.
- **Do** keep the section ordering stable. Reordering invalidates downstream caches even if content is unchanged.
- **Do** keep verification rules and conventions terse. The first ~200 lines get re-read most often; that is your highest-leverage real estate.

For tools built on the Anthropic SDK, place the explicit `cache_control` breakpoint at the end of `AGENTS.md` + `FRAMEWORK-CONTEXT.md`, before per-prompt user content. Read `tests/evals/cases.yaml` for framework scenarios an external harness can probe.

---

## Measuring Progress

- **Tech debt register length**: should trend down over time
- **Build/test pass rate**: hooks should catch regressions early
- **Boy Scout compliance**: are touched files improving?
- **Done-when lines in PR descriptions**: does each non-trivial PR carry its approved `Done when:` lines, each pinned by a test? A plain-words request follows the method as fully as a command.
- **LEARNINGS.md entries**: is the team recording what works?
