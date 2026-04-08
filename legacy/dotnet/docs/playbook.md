# AI Tech Lead Framework — Playbook

This document explains the methodology behind the framework. It's reference reading for onboarding — the executable artifacts live in `CLAUDE.md`, `.claude/commands/`, and `.claude/settings.json`.

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

## Three-Tier Architecture

### Tier 1 — Passive (Copilot)
**File**: `.github/copilot-instructions.md`

Auto-loaded by GitHub Copilot on every inline suggestion and chat interaction. Contains terse imperative rules. Handles the small stuff — naming, patterns, imports — without the developer asking.

### Tier 2 — Directed (Claude Code)
**File**: `CLAUDE.md`

Auto-loaded by Claude Code on every session. The single source of truth: conventions, architecture, agentic workflow rules. When a developer types a natural language request, Claude reads CLAUDE.md and follows the appropriate workflow automatically.

### Tier 3 — Explicit (Commands)
**Files**: `.claude/commands/*.md`

Purpose-built workflows invoked via `/command`. Each encodes a specific methodology: `/feature` decomposes into subtasks, `/fix` writes regression tests first, `/design` forces design thinking before code. Developers can invoke these explicitly, or let CLAUDE.md's agentic workflow route to the right behavior from natural language.

### Automated Verification (Hooks)
**File**: `.claude/settings.json`

Hooks fire automatically after Claude Code writes files. They run targeted `dotnet build` and `dotnet test` commands to catch errors immediately. The agent self-corrects without the developer intervening.

---

## How Tiers Work Together

```
Developer types: "add export button to dashboard"
                    │
                    ▼
         CLAUDE.md (Tier 2)
         Classifies as: feature
         Routes to: feature workflow
                    │
                    ▼
         /feature methodology (Tier 3)
         Plan → Subtask → Build → Test → Boy Scout → Self-review
                    │
                    ▼ (after each file write)
         Hooks (settings.json)
         dotnet build → catch errors → self-correct
                    │
                    ▼ (on next Copilot interaction)
         copilot-instructions.md (Tier 1)
         Inline completions follow the same rules
```

---

## Design Culture: Keeping Developers Thinking

### The risk
This framework makes it easy to produce working code without understanding it. A developer can type `/feature add export button` and get a complete, tested implementation without understanding any of it. That's dangerous if left unchecked.

### The /design command is the gatekeeper
For non-trivial features, run `/design` first. It produces a design document the developer must review — recommended approach, alternatives, trade-offs, open questions. If they can't engage with the design document, they don't understand the problem.

### PR reviews test understanding, not output
The `/review` command checks the code. You check the developer. Use this PR template:

```markdown
## Design Rationale
- What approach did you take and why?
- What alternatives did you consider?
- What existing patterns did you follow? (reference Architecture Decisions in CLAUDE.md)
- What would break if this was implemented differently?
- Did you run /design first? If not, why not?
```

If a developer consistently can't explain their own code, that's a performance signal. The framework amplifies whatever the developer already is.

---

## Daily Workflow

1. **Small stuff**: let Copilot handle it (Tier 1 rules auto-apply)
2. **Features**: type what you want or `/feature [description]`
3. **Bugs**: describe the bug or `/fix [description]`
4. **Refactoring**: `/refactor [target]`
5. **Reviews**: `/review` on changes before PR
6. **Design**: `/design [feature]` before complex work
7. **Tech debt**: `/debt [area]` to find bundleable cleanup

---

## Keeping Things in Sync

### When conventions change
Update these in the same commit:
- [ ] `CLAUDE.md` — the source of truth
- [ ] Run `/generate-copilot` to regenerate `copilot-instructions.md`
- [ ] `TECH_DEBT.md` if debt priorities shifted
- [ ] Relevant commands in `.claude/commands/` if workflow changed

### Quarterly sync
Run `/docs-sync` to cross-check all documentation against the codebase. It reports drift without auto-applying changes.

---

## Measuring Progress

- **Tech debt register length**: should trend down over time
- **Build/test pass rate**: hooks should catch regressions early
- **Boy Scout compliance**: are touched files improving?
- **Command usage**: if developers bypass commands and paste raw prompts, the methodology isn't being followed
- **"What We've Learned" entries**: is the team recording what works?
