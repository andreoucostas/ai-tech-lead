# B-21 reviewer-profile systemic fixes — design (P0)

> **Status (2026-07-06): design FINAL** — adversarially critiqued 2026-07-06 (verdict: LOCK
> WITH AMENDMENTS; 2 HIGH + 4 MEDIUM + 4 LOW folded in; findings log at the bottom). Decision
> record: **WSD-013**. Design-first per BACKLOG B-21 and the Investigation meta-workflow.
> Implementation is **post-merge** (merged `ai-tech-lead` repo, ≥ v0.28.0; single `src/` edit
> per artifact — invariant references below name the current dual-repo forms and their composer
> equivalents), independent of B-27 and gated behind B-25-EXEC. Freeze-compatible: meta-only.

## The reviewer profile (binding constraint)

Consumers' PRs are reviewed by **competent engineers with very limited AI understanding**
(maintainer-confirmed from rollouts). They will correct wrong *content* about their own code;
they will NOT restructure artifacts or reason about AI mechanics (epistemic markers, token
budgets, which file drives what). Design rule: **speak to reviewers in plain engineering terms
about their own code; the pipeline makes every AI-architecture call itself.**

## Current state (verified 2026-07-06 at v0.25.5 — the backlog entry is partially stale)

The three fixes were filed 26 days ago; two have since partially landed:

| Fix (as filed) | Already shipped | Actual remaining gap |
|---|---|---|
| #3 adopt contradiction prompts as engineering choices | **Done** — `adopt.md:179` asks "Your codebase has [A]; your [file] says [B] — which is intended?"; safe default = in-code pattern; bulk "accept all defaults" path | Defaulted-without-an-answer contradictions **disappear** — Phase 8's report never lists them, so nobody re-reviews the choices the machine made |
| #1 review gate checklist + confidence tags | **Partial** — `<!-- INFERRED -->` markers exist (tightly scoped, `bootstrap.md:154`); Phase 4 says "review for accuracy, not AI-architecture" | No **prioritized spot-check checklist** — the report says "verify it" but never enumerates the specific items that need human judgment, in question form, where a reviewer will actually see them |
| #2 hazard `[UNVERIFIED]` UX | **Partial** — `bootstrap.md` 3d-bis asks plain, answerable questions per hazard (single message, (a)/(b)/(c) mapping, graceful degradation); the FRAMEWORK-CONTEXT comment explains the ladder and says "re-confirm rows older than ~90 days" | The 90-day rule is **a comment, not a mechanism** (session-start surfaces only SECURITY_FINDINGS SLAs); **"PR-merge ≠ verification" is stated nowhere**; the persistent table still leads with bare `[UNVERIFIED]` tokens |

The unifying residual problem: **judgment-needed items are created with good UX but then
scatter and expire silently.** Nothing collects them for the PR reviewer, and nothing brings
them back when they go stale.

## Design

### D1 — One "Needs a human decision" checklist, emitted for the PR/commit (fix #1 + #3 tail)

`bootstrap.md` Phase 4 and `adopt.md` Phase 8 gain a **prioritized checklist of every
judgment-needed item this run created**, capped at ~10 entries, each phrased as a plain yes/no
engineering question with a file pointer. Sources, in priority order:

1. `<!-- INFERRED -->` conventions — "The code gave mixed signals on [area]; I wrote **[rule]**. Is that the team's intent? (CLAUDE.md > Conventions > [subsection])"
2. `(c) unsure` / tooling-only hazards from 3d-bis — "Is [specific risk] real in this codebase? If you're not sure, leave it as it is. (FRAMEWORK-CONTEXT.md > Known Hazard Areas)"
3. **Contradictions resolved by default** in adopt 4a — "You had [A] in your code and [B] in [old file]; I kept **[A]**. Right call? (CLAUDE.md > [section])" *(closes fix #3's tail: the machine's defaulted choices become visible again)*
4. `origin: discovered` skills — existing plain-language line, folded in unchanged.

The user-facing strings must be free of artifact-mechanics vocabulary (no "row", "Status",
"INFERRED", "epistemic") — the parenthetical file pointer is the only navigation aid (L4).

**Delivery — the block needs a home, and today only `/adopt` has one.** The checklist is
printed in the report **inside a fenced block titled "Paste this into your PR (or commit
message)"**. No checkbox is auto-ticked; an empty category is omitted; if every category is
empty, the block is replaced by one line ("No open judgment calls — the run resolved
everything against your code").

- **`/adopt`** already recommends a branch (Phase 0) and ends by telling the user to commit
  (Phase 8) — the block slots into that final report ahead of the commit step, and Phase 8 is
  the **single emitter** (see the double-emission note below).
- **`/bootstrap`** today has **no branch / PR / commit step at all** — it only references "the
  PR diff" assuming someone else opened one. So D1 adds a short closing instruction to
  bootstrap Phase 4: emit the block, then a one-line nudge — "commit these changes on a branch
  and open a PR; paste the block above into the description so your team sees what needs a human
  answer." That gives the block a landing site without assuming a PR already exists (H2a).

**Durable trace for source #3 (H2b).** Unlike the `<!-- INFERRED -->` markers (source #1) and
the written hazard table (source #2), which persist in the artifacts and can be re-scanned, an
adopt-4a contradiction "resolved by default" **writes nothing** — it silently keeps the in-code
pattern. Relying on conversation memory to carry it from Phase 4a → Phase 8 is fragile: Phase 7
runs the entire `/bootstrap` pipeline (multiple subagent passes) in between. So 4a must write a
**durable marker at resolution time** — `<!-- DEFAULTED: [area] — kept [A] over [B] from
[file] -->` appended to the relevant CLAUDE.md section (or a scratch `docs/pre-adoption/
adoption-decisions.md` note) — which the Phase-8 checklist pass re-scans and then may strip.
This is a real 4a edit, not the "one line" the first draft assumed (see re-cost below).

**Double-emission (M1).** Under `/adopt`, Phase 7 invokes `/bootstrap`, which — post-D1 — would
print its own Phase-4 checklist *inside* the adopt run, then adopt Phase 8 would print another.
bootstrap already detects the adopt context (it skips Phase 2b under adopt). Reuse that signal:
**bootstrap suppresses its Phase-4 checklist block when invoked from `/adopt`**; adopt Phase 8
is the sole emitter, aggregating bootstrap-side sources (INFERRED, hazards, skills) with the
adopt-only source (defaulted contradictions).

**Alternatives weighed:** (a) persist as a committed `docs/review-checklist.md` — rejected:
new-file cost (Leanness #1) and it rots the moment review ends; (b) leave items scattered in
their sections — rejected: that is the status quo failure; (c) PR-template placeholder —
rejected: the shipped `PULL_REQUEST_TEMPLATE.md` is static and can't carry run-specific items.
The PR description / commit message is the one place the reviewer profile says reviewers
reliably look.

### D2 — Hazard staleness becomes a mechanism: session-start resurface (fix #2 core)

Turn the 90-day comment into a real check. Extend `session-start.ps1/.sh` (twins [#3]) to parse
the `## Known Hazard Areas` table and, for eligible rows whose `Reviewed` date is **more than 90
days before today**, emit one plain line — tooling-only / unsure rows worded as the open
question ("N hazard area(s) have waited over 90 days for a human answer — confirm each, or mark
it 'not a hazard', in FRAMEWORK-CONTEXT.md"), confirmed rows as a lighter re-confirm nudge.

**This is interval arithmetic, not the security block's compare (H1).** The SECURITY_FINDINGS
block (`session-start.ps1:82-90`, `.sh:69-77`) lexically compares a stored *due* date against
today — it computes no interval. D2 must compute a **cutoff = today − 90 days** and compare each
row's `Reviewed` date against that cutoff:
- **PS:** `([datetime]::ParseExact($rev,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture)) -lt (Get-Date).AddDays(-90)` — culture-invariant, ISO-pinned; wrap in try/catch so an unparseable cell is skipped, not fatal.
- **sh:** `cutoff=$(date -d '90 days ago' +%F 2>/dev/null || true)` then a lexical `[ "$rev" \< "$cutoff" ]` (safe **only** because both are ISO `YYYY-MM-DD`). `date -d` is **GNU-only** (breaks BSD/macOS `date`); guard: if `$cutoff` is empty, skip the block (degrade safe). Do **not** reach for `date -j`/epoch math — that reopens the B-02 locale/`%s` twin-skew hazard.

**Date-format dependency (H1, requires a 3d-bis edit — so D3's "3d-bis unchanged" is dropped).**
The `Reviewed` value D2 parses is written by 3d-bis as "(today's date)" with **no format
pinned** (`bootstrap.md`), so an agent might write `2026-07-06`, `July 6 2026`, or `06/07/2026`
— and D2's degrade-safe would then silently no-op on real repos. Pin it: 3d-bis writes
`Reviewed` as ISO **`YYYY-MM-DD`**, and the `(b) not a risk` status becomes
`[REVIEWED: not a hazard — YYYY-MM-DD]`. Small, additive 3d-bis change; the parser keys on it.

**Eligible-row rules (M4).** Resurface only `[UNVERIFIED]` / `[SUSPECTED]` (open question) and
`[VERIFIED]` (lighter nudge). **Exclude**: `[REVIEWED: not a hazard — …]` rows (a settled
negative — never resurface, even past 90 days), the `_`-cell placeholder row
(`| _(drafted by /bootstrap)_ | … |`), and any file still carrying the
`KNOWN_HAZARD_AREAS_PENDING` marker. No file / no table / unparseable dates → silence.

**Delivery contract (M5).** The block must sit **inside** the `$body` scriptblock (PS) /
`emit_body` function (sh), alongside the security block — output emitted *outside* that scope
is plain stdout that the Copilot surface drops (the exact trap B-27's design flagged), which
would pass every Claude test while silently failing Copilot. Per-surface [#5]: plain stdout on
Claude, JSON `additionalContext` on Copilot — inherited automatically by living in `$body`.

**Cost note (L2).** This adds per-session parsing of FRAMEWORK-CONTEXT.md, which the hook does
not read today; its header says "keep fast … git / CLAUDE.md / TECH_DEBT.md / SECURITY_FINDINGS
only". Acceptable because the hazard table is capped at ~12 rows (unlike B-27's 100+ wiki
entries, which is *why* B-27 kept staleness out of session-start); update the header comment to
include FRAMEWORK-CONTEXT.md and note the row cap.

**Alternatives weighed:** (a) `docs-sync-check` advisory NOTE — reaches CI logs, not the person
opening the file; kept as an optional follow-on, not core; (b) a dedicated refresh command —
rejected: new surface nobody will run; (c) do nothing (comment stays advisory) — rejected: a
comment is not a mechanism, and the whole point of fix #2 is that the 90-day rule must actually
fire. *(Sequencing note — corrected: B-27 does **not** depend on this. B-27's locked design
rejected session-start staleness and put its staleness reporting in `wiki-check`; it ships first
(v0.27.0) and is independent. D2 stands on its own merit.)*

### D3 — Keep the ladder tokens; fix the framing around them (fix #2 remainder)

`[VERIFIED]/[SUSPECTED]/[UNVERIFIED]` stay — they are machine-parsed anchors. The durable
consumers are D2's new parser, bootstrap 3d-bis's writer, and the in-file instruction that tells
the agent to honour each status (`FRAMEWORK-CONTEXT.md` hazard comment). *(B-27 reuses the ladder
**concept** but a different serialization — lowercase `status: verified|suspected|unverified`
frontmatter, not the bracketed tokens — so it is not a consumer of this anchor; L1.)* Replacing
the tokens with prose would break those consumers to fix a problem the legend fixes for free.

The change is framing only — but it must land as **rendered text**, not inside the HTML comment
(M3). The existing ladder explanation lives inside `<!-- … -->` (FRAMEWORK-CONTEXT.md hazard
block), which **does not render** in GitHub file view or markdown preview — so a reviewer
opening the file never sees it, defeating the plain-English goal. Add, as a visible line
directly **above the hazard table** (outside any comment):

- A one-line legend: *"Verified = a person confirmed it. Suspected = a person thinks so.
  Unverified = only the tooling flagged it — treat it as an open question, not a finding."*
- The missing sentence: **"Merging the PR does not confirm these — an item is confirmed only
  when a person answers its question and updates its status."**

3d-bis gains the small ISO-date pin from D2 (H1); otherwise its creation-time behaviour is
unchanged (it already asks plain, answerable questions).

**Alternative weighed:** replace tokens with plain-English status phrases — rejected: breaks the
machine anchors (D2 parser, 3d-bis writer, honour-instruction) to fix a problem the rendered
legend fixes for free.

## Implementation notes (for the executing session, post-merge)

- **Artifacts touched:**
  - `bootstrap.md` — Phase 4 (emit checklist + commit/PR nudge; suppress under `/adopt`),
    3d-bis (pin `Reviewed` to ISO `YYYY-MM-DD`; ISO-date the `[REVIEWED: not a hazard]` status).
  - `adopt.md` — Phase 8 (single-emitter checklist incl. defaulted-contradiction source),
    Phase 4a (write the `<!-- DEFAULTED: … -->` durable marker at resolution time).
  - `session-start.ps1` **and** `session-start.sh` (twins [#3], BOM on the `.ps1` [#4]) — D2
    block **inside** `$body` / `emit_body`; header "keep fast" comment updated (L2).
  - `FRAMEWORK-CONTEXT.md` template — rendered legend + confirm sentence above the hazard table
    (M3). Stack-agnostic wording (core; no snippets expected).
  - **Mirror note (L3):** the command edits (`bootstrap.md`, `adopt.md`) mirror to their
    `.github/prompts/*.prompt.md` wrappers [#1], **not** AGENTS.md (AGENTS.md mirrors CLAUDE.md's
    portable rules — untouched here). The `FRAMEWORK-CONTEXT.md` template edit touches no mirror.
    In the merged repo each is one `src/core` edit.
- **State-passing (H2b):** the defaulted-contradiction source needs a durable artifact marker
  (not conversation memory) because Phase 7 runs the full `/bootstrap` pipeline between adopt 4a
  and 8. Sources #1 (`<!-- INFERRED -->`) and #2 (hazard table) are already durable in the
  written files; the Phase-4/8 checklist pass re-scans them rather than trusting in-context recall.
- **Tests:** extend the hook suite with `SessionStart` hazard-resurface cases — fixture
  FRAMEWORK-CONTEXT with planted rows (old ISO date → resurfaces; fresh → silent; unparseable →
  skipped; `[REVIEWED: not a hazard]` past 90d → NOT resurfaced; placeholder `_` row → skipped;
  `KNOWN_HAZARD_AREAS_PENDING` present → silent). Twin agreement (.ps1 vs .sh identical verdict)
  **and a Copilot-shaped stdin case asserting the hazard line lands in JSON `additionalContext`**
  (M5). Red-before-green per Verification Rule #9.
- **Effort: M–L** (matches BACKLOG B-21) — cross-phase durable-marker plumbing, twin date-math
  with the GNU-`date` portability guard, the 3d-bis format pin, double-emission handling, and the
  new fixtures push it above a plain M. CHANGELOG + release per invariant #7 (post-merge: one
  CHANGELOG).
- Checklist + resurface wording must pass the reviewer-profile test: every string answerable by
  an engineer who has never heard of CLAUDE.md mechanics (L4 — no "row"/"Status"/"INFERRED").

## Out of scope

Restructuring the ladder vocabulary (would break the B-27 concept-reuse and the D2 parser),
auto-expiring hazard rows (a stale hazard is still a hazard — only a human retires one), any
dual-repo implementation before the merge (freeze).

## Adversarial critique (2026-07-06) — findings log

Fresh-context Plan agent; verdict **LOCK WITH AMENDMENTS**; premise + three-fix strategy
survived, all findings folded above.

- **H1** — D2 misdescribed as "mirror the SECURITY_FINDINGS block" (that block does a lexical
  two-date compare, not interval math) **and** depended on 3d-bis's unpinned `Reviewed` date →
  would silently no-op. Fixed: D2 does cutoff=today−90d interval math (per-shell, ISO-pinned,
  GNU-`date` guard); 3d-bis pins `Reviewed` to ISO; "3d-bis unchanged" dropped from D3.
- **H2** — D1's PR-description block had no landing site in bootstrap (no branch/PR/commit step),
  and its hardest source (adopt-4a defaulted contradictions) had no durable trace. Fixed:
  bootstrap Phase 4 adds a commit/PR nudge; 4a writes a `<!-- DEFAULTED: … -->` marker; re-cost.
- **M1** — double-emission (adopt Phase 7 runs bootstrap → two checklists). Fixed: bootstrap
  suppresses its checklist under `/adopt`; adopt Phase 8 is sole emitter.
- **M2** — D2's "B-27 needs this pattern" justification was false (B-27 rejected session-start
  staleness, uses `wiki-check`). Fixed: justified on own merit; sequencing note corrected.
- **M3** — legend placed in an HTML comment (invisible to reviewers). Fixed: rendered text above
  the table.
- **M4** — resurface set under-specified. Fixed: exclude `[REVIEWED: not a hazard]` + placeholder
  `_` rows + pending marker.
- **M5** — D2 block must live inside `$body`/`emit_body` or Copilot drops it. Fixed: pinned +
  Copilot-shaped test required.
- **M6** — effort M → M–L.
- **L1** — "three consumers" overcounted (B-27 uses a different serialization). Corrected.
- **L2** — per-session FRAMEWORK-CONTEXT parsing tension acknowledged; header comment to update.
- **L3** — command edits mirror to `.github/prompts` wrappers, not AGENTS.md. Corrected.
- **L4** — jargon leak ("row"/"Status") in user-facing strings. Tightened.
