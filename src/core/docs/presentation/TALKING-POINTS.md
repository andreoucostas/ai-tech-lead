# Talking Points — The AI Tech Lead Framework

Companion to **`framework-briefing.html`**. The deck is self-contained: double-click to open in any
browser, no internet required. Navigate with **← →** or **Space**; press **N** for the built-in
speaker-notes overlay, **F** for fullscreen, **P** to print or export to PDF.

You're presenting to two audiences. Use the **same deck**, but change emphasis and pace per the two
"runs of show" below.

---

## How to run it

| Audience | Length | Lead with | Go light on | Skip if short |
|----------|--------|-----------|-------------|---------------|
| **Tech leads** (decision) | 20–25 min | Governance, enforcement (7), impact (10), tradeoffs (13), the ask (14) | Live workflow detail | 9 (developer detail) |
| **Teams** (enablement) | 15–20 min | Daily workflow (9), what's enforced (6–7), demo | Governance/audit, ROI | 8, 13 |

> **Golden rule:** to leads, you're selling *governance + measurable impact*. To teams, you're selling
> *less friction + fewer review cycles*, and being honest about the constraints.

---

## Pre-meeting checklist (do this once, before the leads session)

1. **Run a pilot adoption** on one real repo: `/adopt` → it produces `docs/impact/IMPACT.md`.
2. **Open the impact report** and copy the headline numbers (capability gaps closed, scorecard deltas,
   and — if the Copilot CLI is installed — the behavioral A/B acceptance/build rates).
3. **Paste those real numbers into slide 10's talking track.** Do **not** invent figures — the entire
   credibility of that slide is that the numbers are measured on *your* code.
4. Have the repo open in VS Code in case someone wants to see CLAUDE.md or run a command live.
5. Decide your concrete ask (slide 14): which repo, which sprint, who champions it.

---

## Per-slide talking points

These mirror the in-deck speaker notes (press **N**), collected here for printing or rehearsal.

### 1 · Title
- Open: *"AI is already writing a meaningful share of our code. This is how we make sure it writes
  **our** code, to **our** standards — and how we prove it."*
- Frame the two audiences and that this is rails over the tools we already use, not a new tool.

### 2 · The shift
- Speed is real and good; the lack of governance is the risk.
- Example: *"Three developers ask for 'a service to do X' and get three different shapes."*
- Punchline: **AI accelerates whatever you point it at — including our mistakes.**

### 3 · The problem
- Walk the six failure modes; ask *"how many have you seen in a PR this month?"*
- These six map 1:1 to the countermeasures on the next slides.

### 4 · What it is
- The reframe that relaxes the room: **not another AI tool** — a layer over Copilot/Claude/etc.
- Hammer **"authored once."** Everything hangs off one file.

### 5 · One source of truth
- CLAUDE.md → generated mirrors for each tool. We maintain **one** rule set and project it.
- The **CI drift check** is what stops this rotting in six months.

### 6 · Four pillars
- Verification, Leanness, SOLID, Boy Scout — the standards a good lead enforces in review, now
  enforced continuously.
- SOLID is **literal and mandatory**, with a **deterministic** CI backstop (not just an LLM opinion).
- If challenged on "leanness vs SOLID": SOLID governs *structure*, leanness governs *ceremony beyond
  that structure* — they're reconciled, not in conflict.

### 7 · Enforced, not documented  *(leads' favourite)*
- The pre-write hook **hard-blocks** suppressions (`#pragma warning disable`) and secrets — the AI
  literally cannot write them.
- Subagents review; CI guardrails fail the build on drift / architecture violations; every AI change
  is logged.
- **Bitbucket:** guardrails run in Bamboo/Jenkins or a pre-receive hook and post to PRs via Code
  Insights. No cloud required.
- Punchline: **rules that aren't enforced are just suggestions.**

### 8 · For tech leads
- The framework **amplifies you** — your standards at machine scale and consistency.
- Honest cost: **you own CLAUDE.md.** It's small and budgeted, drift-checked, but it's a living doc.
- Land it: less review time on "you forgot a CancellationToken," more on "is this the right design."

### 9 · For developers  *(teams' core slide)*
- Lead with what's easier: slash commands run the workflow; skills auto-trigger; the AI already knows
  our conventions; guardrails catch slips before review.
- Then the constraints, framed as rails: state intent, don't silence failures, SOLID/leanness enforced.
- **Demo idea:** run `/feature` on a small change live — plan → verified subtasks → self-review.
- Pre-empt "enforced on a deadline?": yes, friction is cheaper than cleanup — but there's a documented
  escape hatch for genuine hotfixes.

### 10 · Measurable impact  *(the differentiator)*
- Most "AI standards" decks ask for faith. **This produces a report on your codebase.**
- Tier 1 = capability diff + deterministic scorecard (immediate). Tier 2 = behavioral A/B through a
  real agent, old framework vs new, **same model, same tasks** — several trials.
- Be honest about **stochasticity**: read distributions, not single runs.
- **← paste your pilot's real headline numbers here.**

### 11 · Fits our environment
- Kills the "but we're on local Bitbucket, not GitHub cloud" objection up front.
- GitHub Actions / Copilot cloud agent / Rovo Dev are **not** required. Host-agnostic; CI wired to
  what we already run. Every script has a **PowerShell twin** (Windows-first).

### 12 · Adoption path
- The word that matters: **reversible.** Adoption **archives** originals, never deletes.
- Recommend piloting one active-but-not-critical repo for a sprint — low blast radius, real signal.
- Recently hardened: adoption now *always* produces the impact report, reliably detects the Copilot
  CLI on Windows, and uses short worktree paths so it doesn't trip Windows' 260-char path limit.

### 13 · Honest tradeoffs  *(credibility)*
- Name the costs yourself — it disarms skeptics who've seen silver-bullet pitches.
- Token cost: managed (cheap agents for cheap checks, heavy model only where it matters, tight base
  file). Discipline cost: the friction is the point. Learning curve: a handful of commands.
- ROI line: cost is tokens + discipline; return is consistency, fewer review cycles, a **measurable**
  quality delta.

### 14 · The ask
- Small and concrete: **one repo, one sprint, then we look at the numbers.**
- If the room is warm, offer to run the pilot adoption this week and book the report review.

---

## Anticipated questions & answers

**"Does this lock us into Claude / one vendor?"**
No. CLAUDE.md is the source, but it's mirrored to the open `AGENTS.md` standard and to Copilot's
formats. Copilot, Cursor, Gemini, and Aider all read it. Swap assistants without rewriting the rules.

**"We already have a coding-standards doc. How is this different?"**
A doc is advisory and goes stale. This is *executable and enforced* — hooks block violations in real
time, CI fails on drift, and the standards travel with the repo into the AI's context on every task.

**"What does it cost us in AI spend?"**
More context per turn, but actively managed: cheaper models handle cheap checks, the expensive model
runs only where it matters, and the per-turn base file is budgeted and prompt-cache-stable.

**"Will it slow developers down?"**
Up front, slightly — new commands and enforced discipline. Net, it's faster: less prompting (the AI
knows our conventions), fewer review round-trips (guardrails catch slips early), and consistent output.

**"Can it run on our Bitbucket Data Center / behind the firewall?"**
Yes — that's a design constraint, not an afterthought. Everything runs locally; CI uses
Bamboo/Jenkins/pre-receive + Bitbucket Code Insights. No GitHub-cloud features required.

**"How do we know it actually helps?"**
The impact harness. `/adopt` produces a before/after on your own repo — capability diff, deterministic
scorecard, and a same-model behavioral A/B. We decide rollout on that evidence.

**"What's the maintenance burden?"**
Mainly keeping CLAUDE.md current as conventions evolve — a few hundred budgeted lines, with drift
checks that flag when mirrors or docs fall behind. The tech lead owns it; it's a first-class artifact.

**"What if someone needs to ship a hotfix right now?"**
The Boy Scout / cleanup rules have a documented skip for hotfixes and incidents (leave a TODO marker;
`/debt` cleans up later). The hard blocks (secrets, suppressions) stay on by design.

---

## One-line summary (for the calendar invite / Slack)

> A repo-level standard that makes every AI assistant follow our conventions, enforces them with hooks
> and CI, and measures the before/after on our own code — built for local Bitbucket on Windows.
