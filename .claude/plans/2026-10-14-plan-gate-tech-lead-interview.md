# Plan: tech-lead questions in the plan gate (2026-10-14)

> **Status 2026-10-14.** Drafted by a Fable session from read-only investigation at HEAD `01c79002`, clean tree, and promoted
> straight to `.claude/plans/` at the maintainer's request so that a separate session (Opus driving Sonnet) implements it.
> No build, gate, test, `claude -p` or `copilot` run was made to write this plan. Every `path:line` below was read at
> `01c79002`; re-read before editing. The implementing session commits this file in its work commit (AGENTS.md > Ship:
> records ride in the work commit).

## 1. Why

The maintainer asked whether the framework has a skill that interviews a developer the way a tech lead would: ask the
right questions before designing, make them design, and verify assumptions with evidence. Two shipped surfaces already
hold part of this:

| Surface | Where | What it does today |
|---|---|---|
| Plan gate | `src/core/.github/instructions/framework-rules.instructions.md:71-79` (always loaded on both surfaces via `applyTo: "**"` and the `CLAUDE.md` import) and `$railsPlanGate` in `src/core/.claude/hooks/route-prompt.ps1:106-109` (injected per prompt for the `fix`, `feature`, `refactor` and `test` intents on both surfaces) | Post a plan, assumptions and "clarifying questions for anything underspecified", then wait for the go-ahead. |
| `/design` | `src/core/.claude/commands/design.md`, its Copilot wrapper `src/core/.agents/skills/design/SKILL.md`, and `$railsDesign` at `route-prompt.ps1:69-76` | Requirement, impact, two approaches, recommendation, open questions, spec in `specs/<slug>.md`. |

The gaps, and the constraint that decides where the fix goes:

1. **Questions come after the design, not before.** Both surfaces let the agent fill every gap, draft the whole plan or
   design, then list leftovers at the end. The answers never shape the plan.
2. **No question set is stated.** "Clarifying questions for anything underspecified" is the whole instruction. A strong
   model knows what a tech lead asks; the Copilot models do not, and a checklist helps them most.
3. **Assumptions are stated, never verified.** Nothing asks for the file, command or query that confirmed an assumption.
4. **Consumers' developers do not type slash commands.** They type "add an endpoint for X" and rely on what fires by
   itself. `route-prompt.ps1:138-144` routes that to `feature`; the `design` intent fires only on phrasing like "how
   should I", "design a", "trade-offs". So `/design` is the wrong home: the interview must live in the plan gate (both
   the always-loaded section 2 and the per-prompt rail), with `/design` only kept consistent.
5. **Nothing is measured.** `meta/eval-results.md` holds many plan-gate *routing* observations and none of a clarifying
   question being asked; the eval runner's `-p` prompts tell the agent to "make reasonable assumptions and proceed
   autonomously" (eval-results, the RAIL side check near line 3669), so the current harness cannot see this behaviour.

Decided (maintainer, 2026-10-14): **no new skill, agent, command or test file** (Leanness; context budget; two surfaces
already overlap). Strengthen the plan gate; keep `/design` consistent; ship unmeasured with one BACKLOG line for a
multi-turn measurement (precedent: WSD-111, B-348 and B-356 shipped unmeasured at `fb42bb7a` and `e44102b4`).

## 2. Scope

**In:** the six edits in section 3, the CHANGELOG entries, the red-first test case, `dist/*` rebuilt,
`meta/context-footprint.json` updated after review, one BACKLOG line.

**Out:** any new skill, agent, command or test file; the `design` Copilot wrapper (`src/core/.agents/skills/design/SKILL.md`
reads `design.md` and says "follow it exactly", so it needs no edit); `docs/enforcement-surfaces.md` (its Plan-gate row,
"plan + clarify before code", stays true); any eval run; the B-356 bullet at `framework-rules.instructions.md:75`, which
stays as is; stack snippets (no touched file's `@stack:` marker changes, so the monorepo-sibling review in AGENTS.md >
Verification has nothing to review).

## 3. The edits (exact current text, then proposed text)

All under `src/`, never `dist/`. In the consumer's voice. Keep every rail line short: `$railsPlanGate` is injected on
every routed `fix`/`feature`/`refactor`/`test` prompt (the `feature` fixture is 2,524 chars today,
`meta/context-footprint.json` dotnet `prompt` block) and section 2 is always loaded.

### 3.1 `src/core/.github/instructions/framework-rules.instructions.md`, section 2, line 76

Current line 76:

```
- Your assumptions, plus **clarifying questions** for anything underspecified (ambiguous scope, unclear acceptance criteria, competing approaches). Do not guess past a material ambiguity to seem helpful — ask.
```

Replace with these two bullets (the second keeps the current closing sentence):

```
- Your assumptions, each with the evidence that verified it (a file, command or query), or marked *unverified — developer confirms*.
- If the request leaves a material gap, **ask first and plan after**: post at most five questions, each with the assumption you would otherwise make, and post the plan only once they are answered. Draw them from the tech-lead list — who consumes this and what breaks for them; what fails and how the developer would know in production; reversibility and rollback; data that moves or changes shape, including migration; blast radius against `FRAMEWORK-CONTEXT.md > Known Hazard Areas`. Do not guess past a material ambiguity to seem helpful — ask.
```

Lines 72-75, 77 and 79 stay unchanged. Net growth about 560 chars, always loaded, per dist. Headroom at `01c79002`
(`meta/context-footprint.json`, `static.claude` sums): dotnet 38,121 of 40,000; angular 35,910 of 40,000; monorepo 42,499
of 48,000. It fits; re-read the figures with `scripts/context-footprint.ps1 -Check` before deciding, and if the maintainer
wants more headroom, shorten the list by dropping "including migration".

### 3.2 `src/core/.claude/hooks/route-prompt.ps1`, `$railsPlanGate`, lines 106-109

Current:

```
$railsPlanGate = @'
## Plan gate (present -> clarify -> confirm)
Before writing code: post a short plan (files to change, order of operations, how you'll verify) AND any clarifying questions for whatever is underspecified — do not guess past a material ambiguity to seem helpful. Then WAIT for the developer's explicit go-ahead before editing code. Skip the wait only for a trivial, unambiguous change (typo, one-liner), and say that you're skipping it and why.
'@
```

Proposed:

```
$railsPlanGate = @'
## Plan gate (ask -> plan -> confirm)
Before writing code: if the request leaves a material gap, ASK FIRST — at most five tech-lead questions (who consumes this and what breaks for them; what fails and how you'd know in production; rollback; data that moves or changes shape; blast radius against the hazard list), each with the assumption you'd otherwise make — and post the plan only after the answers. Otherwise post the plan now (files to change, order of operations, how you'll verify), each assumption with the file, command or query that verified it or marked unverified. Do not guess past a material ambiguity to seem helpful. Then WAIT for the developer's explicit go-ahead before editing code. Skip the wait only for a trivial, unambiguous change (typo, one-liner), and say that you're skipping it and why.
'@
```

The file is a `.ps1`: keep its UTF-8 BOM (the `bom-fix` hook covers Write/Edit; a shell edit needs it added by hand) and
keep the here-string ASCII-safe apart from the em-dashes the file already carries.

### 3.3 `src/core/.claude/hooks/route-prompt.ps1`, `$railsDesign`, line 71

Current: `1. Understand the requirement — goal, users, acceptance criteria, scope boundary.`

Proposed: `1. Understand the requirement — goal, users, acceptance criteria, scope boundary; on a material gap, ask the tech-lead questions (plan gate) and wait before step 2.`

### 3.4 `src/core/.claude/commands/design.md`

- After the four bullets of **Step 1** (heading at line 17, bullets to about line 21), add one line:
  `If any of these has a material gap, ask the tech-lead questions from the framework rules (Agentic Workflow, section 2), at most five, each with the assumption you would otherwise make, and wait for the answers before Step 2. The answers shape the design; do not draft approaches around guesses.`
- In the **Output Format** block, before `### Open Questions` (line 77), add:

  ```
  ### Assumptions
  | Assumption | Evidence (file, command or query), or "unverified — developer confirms" |
  |------------|------------------------------------------------------------------------|
  ```

- **Step 5** (line 44) stays; its last sentence already says "Don't make assumptions on domain-specific decisions".
- Do not touch the `<!-- @stack:... -->` markers (`layers`, `structure`, `contract`, `dataflow`).

### 3.5 `src/core/specs/README.md`, template, before `### Open questions` (line 61)

`/design` persists its output to this template, so add the same `### Assumptions` table there with the one-line note
"Each assumption names what verified it, or is marked unverified for the developer to confirm." No `@stack:` marker
changes (`layers` and `test-levels` stay).

### 3.6 CHANGELOGs x4 (Invariant 7)

- Root `CHANGELOG.md`: under the current unreleased head, maintainer's voice; may cite this plan and the BACKLOG item.
- `src/stacks/{dotnet,angular,monorepo}/files/CHANGELOG.md`: under `## 0.96.0 — Unreleased`, consumer's voice, for example:
  "The plan gate now asks before it plans. On a request with a material gap the agent posts up to five tech-lead
  questions (consumers and what breaks for them, failure and how you would know, rollback, data that moves, blast
  radius against your hazard list), each with the assumption it would otherwise make, and plans only after your answers.
  Every assumption in a plan or `/design` spec now names the evidence that verified it, or says it is unverified."
  Mind `no-meta-leak` (`scripts/meta-denylist.txt`): no B-numbers, WSD numbers or maintainer paths in these three.

## 4. Test: one red-first case in `src/core/tests/hooks/RoutePrompt.Tests.ps1`

Add next to the existing case at lines 60-64 (`plan gate included for feature intent`), using the same helpers
(`New-CopilotPrompt`, `New-ClaudePrompt`, `Invoke-Hook`, `Assert`):

```
It 'route-prompt.ps1 both surfaces -> plan gate asks first with the tech-lead list and evidence-tagged assumptions' {
    $c = Invoke-Hook $rpPs (New-CopilotPrompt 'implement a new export button')
    $o = $c.Out | ConvertFrom-Json
    Assert ($o.additionalContext -match 'ASK FIRST' -and $o.additionalContext -match 'at most five' -and $o.additionalContext -match 'marked unverified') 'Copilot plan gate lacks ask-first, the cap or the evidence tag'
    $k = Invoke-Hook $rpPs (New-ClaudePrompt 'implement a new export button')
    Assert ($k.Out -match 'ASK FIRST' -and $k.Out -match 'at most five' -and $k.Out -match 'marked unverified') 'Claude plan gate lacks ask-first, the cap or the evidence tag'
}
```

It is red on the unfixed tree (none of the three strings exists in the current rail) and green after 3.2. Declare it with
a `Red-first:` trailer and paste the `RED_FIRST PASS` line from `.claude/scripts/assert-red-first.ps1` (DEVELOPING.md,
"Mechanical red-first check"). The section 2 and `design.md` edits are text-only and have no behaviour to show red; say so.

## 5. Verification, in order (AGENTS.md > Verification; show each command and its result line)

1. `scripts/build.ps1 dotnet`, `angular`, `monorepo`: exit 0 each; commit the `dist/` change in the same commit.
2. `scripts/validate-dist.ps1` x3: exit 0; watch check `no-meta-leak` on the three consumer CHANGELOGs.
3. `scripts/context-footprint.ps1 -Check`: expect a baseline change (section 2 grows always-loaded context; the rail grows
   the `fix`/`feature`/`refactor`/`test` and `design` prompt fixtures). Review the diff, then `-Update`, then `-Check`
   exit 0. Record the new dotnet `static.claude` total against 40,000 in the commit body. A ceiling breach is the
   maintainer's call.
4. `src/core/tests/hooks/RoutePrompt.Tests.ps1` as separate direct runs under `pwsh` and under `powershell.exe`, plus one
   CP437 leg because a `.ps1` changed (the `cmd.exe /d /c "set PSModulePath=&& chcp 437 >nul && powershell.exe ..."` line
   in DEVELOPING.md, pointed at this suite). Capture `$LASTEXITCODE` before piping anything.
5. The **dist** copy, both surfaces: pipe a Claude-shaped event (`hook_event_name: UserPromptSubmit`, prompt
   "implement a new export button") and a Copilot-shaped one (same prompt, no `hook_event_name`) into
   `dist/dotnet/.claude/hooks/route-prompt.ps1`; assert `EXIT=0` and that the output carries `ASK FIRST`. Then the three
   dist runners (`pwsh -NoProfile -File dist/<stack>/tests/hooks/Invoke-HookTests.ps1`): exit 0 each.
6. `.claude/hooks/tests/Invoke-HookTests.ps1 -File DocTruth.Tests.ps1`, `-File RepositoryPrivacy.Tests.ps1`,
   `-File BacklogHygiene.Tests.ps1`: this plan file and the BACKLOG line are top-level records.

## 6. Commit and records

- **Tier: guarded** (`src/core/.claude/hooks/**` is a guarded path). Subject starts with `guarded:`. Body at most five
  lines: the observed harm (the agent fills every gap, then lists leftovers; the developer rubber-stamps a plan built on
  guesses), the smaller fix rejected (a new interview skill: overlaps two surfaces, costs budget, never fires for
  developers who type natural language), what could be let through (a question that a weaker model never asks), plus
  the `Red-first:` trailer and the `RED_FIRST PASS` line. AGENTS.md item 4 (maintainer reads the diff or a fresh-session
  attack) does not list `route-prompt.ps1`, so it is not required.
- Note in the body that the behaviour ships unmeasured (WSD-111 precedent) and why (`-p` autonomy).
- `meta/BACKLOG.md`: one entry, next free B-number (B-403 at `01c79002`; check `meta/BACKLOG-DONE.md` for a collision, as
  B-355 once had): "Measure the plan gate's ask-first behaviour on a multi-turn run", filed against v0.96.0, priority
  P3, effort M (the eval runner needs a developer-reply turn, or a one-turn grader that scores the first assistant
  message for questions-before-plan). At most three lines.
- No `meta/workspace-decisions.md` entry: the decision (no new skill; plan gate, not `/design`) is recorded here and in
  the commit body, and nothing here would be re-litigated.
- Push with `.claude/scripts/push-and-check.ps1`. One push.

## 7. Decisions already taken, and the two the implementer may still raise

Taken: no new skill; plan gate first, `/design` consistent; cap of five questions; the fixed five-item list; evidence
column on assumptions; ship unmeasured with a BACKLOG line.

Raise, in one line each, only if hit:
- The section 2 growth breaches the dotnet 40,000 ceiling after the re-read: stop and ask the maintainer (trim or waive).
- `validate-dist` check 15 or Copilot CLI refuses something in touched frontmatter: no frontmatter changes are planned
  here, so this would be pre-existing; file one BACKLOG line, do not fix in this commit (B-359 is already open on it).
