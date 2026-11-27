# Plan: clean up old installs, one instruction file, and every open report point

For the maintainer, 2026-11-27; approved in chat the same day through the decisions below.
Five pieces of work, in the order at the end. Each says what is known and what is proposed.

## Decisions (the maintainer, in chat 2026-11-27)

1. **Instruction files:** "my understanding the industry has landed on agents.md ; confirm it and let's consolidate." The claim is being confirmed from the vendors' own pages; the consolidation in section 2 goes ahead.
2. **What other repositories read (latest report):** "Measure then." The unmeasured hidden-contract case runs on Copilot in the December session.
3. **December Copilot session:** "Ok." One session. Cap ("spending cap - you decide - you know better than me"; the figure is the session's): 6,000 AI credits or 90 premium requests in total, whichever comes first, B-530's recorded 1,800 credits included; never more than 70% of the allowance Copilot reports as remaining when the session starts (the monthly allowance is not on record); 500 credits per process, as set for B-530; the session stops at the first quota, sign-in or rate-limit refusal. Basis: recorded Copilot runs cost 7 to 57 credits each for ordinary tasks (B-528: 24 runs, 687 credits) and up to about 500 for a full set-up run; about 80 runs are planned, about 6,500 credits if every check ran in full. The checks run in the order of section 3.3, so what does not fit drops off the end and is reported as not run.
4. **SonarQube:** "Ok forget the sonarcube idea." Section 4.2 is dropped; section 4.1 (a resolved debt item is deleted in the same change) stays.
5. **Old Copilot instructions file:** "I think the model should ask them whether it should clean it up." An update keeps the file and its own line tells an AI agent running the update to ask the team; a switch on the update removes it (WSD-153).

## 1. Remove what old installs still carry (files and contents)

Rule, in your words: "If the framework doesn't need it we should remove it. We can flag it." For a file a team may have edited: change only text that is byte-for-byte what the framework shipped, keep the original recoverable, say what changed, and name anything that differs.

### 1.1 Built (WSD-153; built in an isolated copy, attacked by fresh sessions in three rounds)

| Leftover | Releases | Action |
|---|---|---|
| Old Copilot instructions file | 0.76.0 to 0.89.2 | Keep and name a shipped text or a copy the retired generator wrote; the update tells an AI agent to ask the team; the `-RemoveLeftovers` switch removes it; flag a team's own file |
| Old Boy Scout lines in the team's instruction file | 0.76.0 to 0.85.0 | Replace or remove each exact line |
| Task-list lines for retired skills | 0.76.0 to 0.91.0 | Remove each exact line once the skill file is gone |
| Empty skill folders | 0.76.0 | Remove; the completion check ignores a folder with no files |

### 1.2 The rest of the contents (new, sized by a sweep of every release from 0.76.0)

The sweep found 74 old lines or paragraphs in ten of the eleven files an update never rewrites, plus one whole document. Seventeen are instructions today's product contradicts, fourteen point at things that no longer exist.

| File | What is stale | Kind |
|---|---|---|
| Team instruction file | Version-stamp comment, placeholders, a comment saying "CLAUDE.md loads on nearly every agent turn", reworded skill lines, a paragraph about mirroring skills, a line naming the retired security command | Superseded and dead pointers |
| Cross-repository context file | "CLAUDE.md (this repo's authoritative source) wins" | Contradicts today's layout |
| Debt register | Old table header; today's debt command and reviewer read blocks and do not see table rows | Breaks a current reader |
| Security findings register | Header and placeholder naming the retired security command | Dead pointer |
| Audit log header | "Retain this file in version control" | Contradicts today's product |
| Decision log, wiki index | One header line each | Dead pointer, description |
| Architecture document | 44 old whole-file versions, about 11 KB describing the framework itself; today's version is a short "this file is yours" stub | Mostly description, some dead pointers |

Proposal:
- **Whole file never edited:** when a team-owned file is byte-for-byte a version the framework shipped, replace it with today's version. Nobody's work is in it.
- **Edited file:** inside the named file and section, replace or remove each exact old line, as 1.1 does.
- **One list, generated from the release tags,** holds every old text and its successor.
- **Stop it recurring:** a build check fails when a seeded team-owned file changes in source and the old text is not added to that list. Today nothing forces that, which is how these accumulated.

### 1.3 Content old commands wrote (not seeded text)

| Leftover | Effect today | Proposal |
|---|---|---|
| Risk-table rows written before 0.85.0 with no file path | The completion check fails on them (an agent ran today's check on such a row) | The failure says which rows and what to add; the set-up refresh fixes them |
| No recorded test command (installs from 0.76.0) | The session-start line that makes Copilot run the failing test first has nothing to name | The health check flags it and names the set-up refresh |
| Mentions of two retired commands in team files | Not reported; only the old security command is | Add both to the update's report |
| Conventions carried from the old instruction file | Team-specific, so no exact match is possible | The update recommends the full set-up refresh when an install crosses the layout change |

### 1.4 Make the state visible

The health check gains one section listing anything recognised but not removed, and its one-line report gains a count. That gives you a number from a team without seeing its files.

### 1.5 Known gap in the evidence

Simulations used installs that had never been through set-up, and not the combined product. Before release: one simulated update of a set-up repository per product.

## 2. One instruction file in the standard place

### 2.1 What each tool reads today (vendor documentation read 2026-11-27, and this repository's host records)

| | `AGENTS.md` | `CLAUDE.md` | Rules file under `.github/instructions` | Skills in `.claude/skills` |
|---|---|---|---|---|
| Claude Code | Yes from 2.1.277, but by default only when no `CLAUDE.md` exists; older builds, Bedrock and telemetry-disabled sessions read `CLAUDE.md` only (documentation, as reported by the documentation agent) | Yes | No; it reads `.claude/rules` instead | Yes |
| Copilot CLI | Yes | Yes, and combines it with the others | Yes | Yes |
| VS Code Copilot | Yes | Not established | Yes | Yes |
| Copilot cloud agent, code review, JetBrains | Yes | Yes | Yes | Documented for cloud agent; code review and JetBrains document `.github/skills` only |
| Visual Studio | Not documented | No | Yes | Yes |

Recorded here: with today's two-line `CLAUDE.md` stub, Copilot CLI 1.0.89 put `AGENTS.md` and the rules file into its context twice. The latest report measured a 46 KB `AGENTS.md`, so that team may be paying for about 90 KB on every turn. Re-check is queued for December.

### 2.2 What the product ships per tool today

Ten tool-specific or duplicating items per product. Two carry the same instructions twice (the `CLAUDE.md` stub and the rules file reached through it). Three are thin Copilot wrappers around a Claude-path file: 13 workflow wrappers, 6 reviewer wrappers, one hook registration.

### 2.3 Target

| Today | Target | Why it is possible | What it costs |
|---|---|---|---|
| `AGENTS.md` plus a `CLAUDE.md` stub that imports it | `AGENTS.md` only | Every Copilot surface that reads repository instructions reads it except Visual Studio chat and JetBrains chat; Claude Code reads it natively when no `CLAUDE.md` of any kind exists | A developer's personal `CLAUDE.local.md`, or a `CLAUDE.md` in a parent folder, switches Claude Code's native reading off (measured); the next row covers that |
| Rules file loaded by Claude Code through the stub | One framework-owned file in `.claude/rules` holding only two imports: `AGENTS.md` and the rules file. One rules file, nothing copied | Measured 2026-11-27 on Claude Code 2.1.332: both load in 3 of 3 runs even with a personal notes file present, and a 45 KB `AGENTS.md` is not loaded twice | Copilot CLI and VS Code with this layout are unmeasured until December; VS Code documents reading that folder |
| Old Copilot instructions file | Removed (1.1) | Nothing reads or maintains it | None |
| 13 workflow commands plus 13 Copilot wrappers | 13 skills in `.claude/skills`, read by both tools | Both tools document that folder | Larger move; names clash with two Copilot built-ins; needs the December checks |
| Reviewer wrappers, hook registration | Keep | No location both tools read is documented | None |

Existing installs: the update moves any team text out of `CLAUDE.md` into `AGENTS.md` (it already does this for the old layout), removes a stub that is exactly the framework's, and keeps and flags one a team edited.

This reverses the recorded choice "never no `CLAUDE.md`" (decision WSD-151) and adds a named exception to the promise that an update never touches a team's own files. The supported Claude Code version does not need to rise: the import route does not depend on native `AGENTS.md` reading.

### 2.4 Removing `CLAUDE.md`: every place it exists (the maintainer, in chat 2026-11-27: "remember to remove the Claude.md")

1. **The product:** stop shipping it in all three stacks; the build check fails if one appears in a built product.
2. **Existing installs:** an update folds any team text into `AGENTS.md`, removes a file that is exactly the framework's stub, and keeps and flags one a team edited. The same for a `.claude/CLAUDE.md`. Installs older than 0.90.0 still hold their whole instructions in `CLAUDE.md`; the existing one-time move handles those first.
3. **Everything that names it:** the session-start pointer (printed today only when `CLAUDE.md` exists), the health check and the template check (both report a missing import today), the set-up and adoption commands, the shipped documents, the size accounting, and their tests.
4. **This repository itself:** its own `CLAUDE.md` imports `AGENTS.md` and holds six notes for Claude Code; the notes move to a file in the rules folder beside the two imports, and the file goes. The container folder one level up has its own `CLAUDE.md` and `AGENTS.md` pair, in a separate repository; it goes the same way.
5. **The rulebook:** invariant 2 in the root `AGENTS.md` describes the stub and is rewritten (guarded, the maintainer reads the diff).

### 2.5 Checks

Done 2026-11-27 on Claude Code 2.1.332, cheapest model, about 0.04 USD (results in the host record):
- `AGENTS.md` alone loads; a personal notes file switches it off; the two-import rules-folder file loads `AGENTS.md` and the rules in 3 of 3 runs with that file present; no second copy.
- Could not examine: the `--bare` one-shot mode (not logged in under a subscription).

Still to do, December session:
- Copilot CLI and VS Code: is each file loaded once with the new layout?
- A reviewer sub-agent on Claude Code.
- A canary in the health check that fails when a tool did not load the instructions.

## 3. Open points from client reports

### 3.1 Latest report (2026-11-25): six findings, two shipped, four open

| Finding | State | Next step | Needs |
|---|---|---|---|
| Adoption carries old statements forward unchecked; later checks miss a wrong one | Harm reproduced on Claude Code (6 of 6 plans went the wrong way); the shipped adoption merged the statement in only 1 of 6 | Run the adoption cells on Copilot; ship "sort rules from facts, check each fact against code" if it reproduces there | December session |
| Instruction file about 46 KB against a 16 KB budget | Nothing shipped | Three levers: section 2 halves the load if Copilot reads it twice; the fix above moves facts out; adoption stops or asks when over budget | Follows the row above |
| Nothing records what other repositories read from this one | An obvious format change was already caught in 6 of 6 plans; a hidden one is unmeasured | Decision 2 | You |
| No home with an owner for facts true at run time | Shipped in 0.99.1, text-checked only | Watch for use | None |
| No list of behaviours to keep when replacing something | Shipped in 0.99.1, text-checked only | Watch for use | None |

Not covered by any entry: the developer's own document describing the multi-repository deployment process. It can be committed under `docs/` today and named in one line of `AGENTS.md`; an existing rule already tells the agent to read the repository's own description of a subsystem first. That needs no framework change, only telling the team.

### 3.2 Other open points

| Report | Point | State |
|---|---|---|
| 14 | The review ran in none of 39 sessions and starts no reviewer on Copilot CLI | December, cap 1,800 credits recorded |
| 15 | New chats asked to address review comments; the team's reviewer | Command shipped for Claude Code; Copilot in December; one free counts card waits on the team |
| 16 | Application not started after an upgrade | Start-up test shipped; upgrade question added this week; Copilot cells in December |
| 17 | Too many classes, too many tests | On your hold. Section 1 removes the old interface rule from the Copilot file and the old "unit tests for public methods" line, which may be the cause. After that release, ask the team to update and report again |
| 10 | Review-tool markers for the baseline file | Waits on the reporter |

### 3.3 One December session

All ten Copilot checks plus section 2.4, run as one planned session with one cap (decision 3), in this order: instructions loaded once; review starts a reviewer; commands listed in VS Code; adoption cells; start-up cells with one upgrade prompt; review-comment handling; reviewer tool lists; the rest.

## 4. Debt register and SonarQube

### 4.1 Does a resolved item leave the register?

Only when the debt command fixes it: that command deletes the item's whole block. The feature, fix and refactor flows only "flag the entry for removal" in their closing message, so an item fixed in passing stays until someone deletes it. Proposal: in every flow, an item the change resolves is deleted in the same change, so the pull request shows it.

The register is not loaded on every turn. It is read when a command needs it; a hook counts entries that touch recently changed files and prints one line.

### 4.2 Importing every SonarQube finding: dropped

Dropped by the maintainer on 2026-11-27. The reasons against a bulk import were its size, two sets of books (SonarQube closes a finding itself; the copy stays), that the framework does not fix unrelated code unasked, and that security findings start a 7-day or 30-day clock in the separate register.

## 5. Monthly convergence review (the maintainer's idea, in chat 2026-11-27)

Goal, in the maintainer's words: "eventually we only have generic configs and not different for Claude and copilot".

What it is: once a month, when the maintainer asks ("on my trigger"; nothing is scheduled, decision WSD-152), check whether any file the product ships for one tool only can now be replaced by a location both tools read.

- **The list it works from** (kept in the host record, about ten rows): each tool-specific or duplicating item the product ships, why it exists, and the exact condition that would let it go.

| Item today | Condition that would let it go |
|---|---|
| `CLAUDE.md` stub | Being removed now (section 2) |
| Rules file reached by each tool its own way | One location both tools load on every request |
| 13 Copilot workflow wrappers beside 13 Claude commands | Both tools list and run a skill from the same folder, with no clash with a built-in command |
| 6 Copilot reviewer wrappers beside 7 Claude reviewer files | Copilot documents reading the Claude agent folder, or a shared agent format appears |
| Copilot hook registration beside the Claude one | Copilot runs the hooks registered for Claude Code alone, once, and accepts one blocking signal for both tools |
| Two hook output formats inside each hook | One documented way to block a tool call on both tools |

- **Each month:** read the two vendors' changelogs and the pages behind each condition; run the free tool checks on the current tool versions; refresh the supported-versions table.
- **What you get:** one short report: what changed at the vendors, which conditions are now met (each becomes a proposed change), what a vendor has deprecated and by when, and any supported version that should rise.
- **Cost control:** the reading runs on Sonnet; only the summary uses a stronger model. No paid tool run without your word, as now.
- **First run:** with the December session, which already checks the instruction files, the skill folder and the hooks on both tools.

## Order of work

1. Now: finish and land 1.1; fix 4.1.
2. This week: 1.2, 1.3, 1.4 with the recurrence check; simulate set-up repositories (1.5).
3. 2026-12-01: the December session (3.3), including 2.4.
4. After the session: ship section 2 in the same release as the report fixes the session supports.
5. Then ask the team to update and report again (report 17).

## What I checked and what I did not

- Checked myself: the installer's removal code, the released texts of the Copilot file (18 versions, 0.26.0 to 0.89.2), the debt command and closing-step wording, the backlog status lines.
- From agents, re-read by an independent reviewer: the simulated updates and the leftover list.
- From agents, not re-checked by me: the vendor documentation (URLs in the session record), the 74-text inventory, the December queue.
- Not examined by anyone: a set-up repository through an update, the combined product, current Copilot versions.
