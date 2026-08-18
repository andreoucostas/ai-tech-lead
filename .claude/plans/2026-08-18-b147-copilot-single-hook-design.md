# B-147 — restore routing salience on Copilot CLI (one `userPromptSubmitted` entry)

**Status:** **REV 2 — RE-LOCKED after critique. Implementation authorised.**
**Priority:** P1 · **Invariants:** #1 #3 #5 #7 · shipped change ⇒ release.
**Critique:** `.claude/plans/2026-08-18-b147-sol-critique.md` — verdict REQUEST CHANGES, two
blocking findings, both verified by the reviewer and both incorporated below (§3a, §3b).

> **What the critique changed, and what it did not.** The premise and the merge direction survived;
> the *host* did not, as written. Finding 1: `route-prompt` exits at lines 122/125/151 on an empty
> prompt, a slash command, and an unclassified non-sensitive prompt — so as designed it could never
> deliver a queued nudge when routing text is empty, which is most read-only turns. B-52's own
> fallback text had anticipated this ("fold Boy Scout into `route-prompt` **without its
> early-exit**") and rev 1 dropped it. Finding 2: the proposed `validate-dist` check would have
> rejected a legitimate configuration — `postToolUse` carries **two** entries (`post-write`,
> `audit-trail`), verified. Both accepted.
>
> **One critique claim was checked and did not reproduce.** It reported `TwinParity.Tests` red on
> two bash-leg boy-scout cases and honourably refused to call the suite green. Re-run here:
> **13 passed, 0 failed, exit 0**, both named cases green. The Boy Scout scan reads live `git diff`
> state and the reviewer's sandbox had its own modified files in the tree. Environmental, not a
> defect — recorded so nobody re-hunts it.

---

## 1. The observation this rests on

Copilot CLI **1.0.79/1.0.80**, live, folder trusted: with more than one `userPromptSubmitted` hook
registered, **only the last entry's `additionalContext` reaches the model.** Earlier entries run,
exit 0, emit valid JSON, and their context is discarded. Four runs; the decisive control swapped the
tokens between the two scripts and the surviving token moved with the **slot**, not the script, and
a fourth run with structurally distinct messages ruled out context de-duplication.

Shipped registration in all three dists (`src/core/.github/hooks/hooks.json`):

```
userPromptSubmitted:
  1. .claude/hooks/route-prompt.*                     <- DISCARDED
  2. .claude/hooks/boy-scout-check.* --mode deliver   <- delivered
```

`sessionStart`, `agentStop`, `preToolUse` and `postToolUse` each carry **one** entry and are
unaffected. The damage is confined to the one event with two registrations — which happens to be
the one carrying the routing rail.

## 2. Proportionality (Maintenance model #6 — stated before the design locks)

The harm is observed, shipped, and load-bearing: `docs/enforcement-surfaces.md` tells consumers that
Routing, Plan-gate and **Security pass** are injected per-prompt by `route-prompt` on Copilot CLI
≥ v1.0.65. None of the three happens. The security row is the sharpest: it promises an automatic
security-review nudge on auth/money/secrets work.

**Is there a materially smaller fix?** Yes, and it must be considered rather than dismissed:
**swap the order** so `route-prompt` is last. One line, no new logic, no new failure modes, and it
restores the load-bearing rail immediately. Its cost is that the Boy Scout nudge on Copilot becomes
dead instead, so the matrix row asserting it would have to be corrected to "not delivered on CLI".

**Rejected, with the reason stated rather than asserted:** it trades one silently-dead hook for
another and buys nothing that the merge does not also buy. It also encodes a vendor bug as a layout
convention, so the day Copilot fixes multi-hook delivery the repo is left with a deliberate ordering
whose rationale has evaporated and nothing that notices. The merge is strictly better and the extra
cost is bounded (one branch in one shipped script, both twins). **However** — if the critique finds
the merge carries real risk to the Claude Code path, the reorder is the correct fallback and should
be taken; it is a genuine option, not a straw man.

## 3. Design

**One `userPromptSubmitted` entry, which is `route-prompt`.** On non-Claude surfaces only,
`route-prompt` additionally drains the Boy Scout delivery queue and appends it to its own
`additionalContext`. `boy-scout-check --mode deliver` is removed from the Copilot
`userPromptSubmitted` array; its `--mode scan` registration on `agentStop` is untouched.

Why `route-prompt` is the host rather than a new dispatcher script: it **already** surface-detects
(Claude Code events carry `hook_event_name`; everything else gets the JSON shape), so the branch it
needs exists. A new dispatcher would add a shipped script in two languages, a new registration, and
a new twin to keep in sync, to do what one existing branch can.

### 3a. The control-flow restructure (blocking finding 1)

`route-prompt` has three early exits before its surface dispatch: empty prompt (122), slash command
(125), and no-intent-and-not-sensitive (151). Under rev 1 a queued nudge would have been delivered
**only on turns that also produced routing text** — i.e. never on the read-only turns the Boy Scout
nudge most often follows. The fix:

**Move the surface gate above the early exits, and make the non-Claude path fall through to a
compose step rather than exiting.** Concretely, on the non-Claude surface: compute routing text as
today (an empty string is fine), then drain the queue, then emit if *either* is non-empty, else emit
nothing and exit 0. The Claude path keeps today's control flow byte-for-byte, early exits included.

**The queue read MUST sit behind the surface gate, not merely behind "routing text is empty".** This
is the precise shape of the Claude regression risk: `boy-scout-check` is registered independently on
Claude's `Stop` event, so any queue drain on the Claude path double-delivers.

**Surface detection is left exactly as it is** — a raw `"hook_event_name"` substring test
(`.ps1:187`, `.sh:213`) rather than structural inspection of the already-parsed event. The critique
is right that this is weaker than rev 1 called it, and right that changing the established
discriminator would enlarge a P1. Preserve it; the tests must prove **both** known shapes. File
structural detection separately if wanted.

### 3b. The `validate-dist` check (blocking finding 2)

Scope it to **`userPromptSubmitted` only**. A blanket "one entry per Copilot event" rule would reject
`postToolUse`, which legitimately carries `post-write` **and** `audit-trail` — verified: those are
side-effecting hooks whose value is not model-facing `additionalContext`, so multiple entries there
are correct and must stay legal. The constraint being encoded is about **context injection**, not
about running hooks.

**Composition order inside the payload:** routing text first, Boy Scout queue second. Routing is the
load-bearing half (it carries the plan-gate and security-pass salience); the Boy Scout nudge is
advisory by decision (WSD-024 — it must never block). If either half is empty the other is emitted
alone; if both are empty the hook emits nothing, exactly as `route-prompt` does today.

**Claude Code must not change.** `.claude/settings.json` is a separate registration and Claude
consumes every entry, so both hooks keep firing independently there. The new behaviour is gated on
the same surface check `route-prompt` already performs. A Claude-side regression is the main risk
this design carries and the tests below exist to bound it.

**Files** (invariant #1 — authored once in `src/`, composed to three dists; invariant #3 — twins):
- `src/core/.github/hooks/hooks.json` — drop the second `userPromptSubmitted` entry, and rewrite the
  `_comment`. Its current sentence *"route-prompt remains first under userPromptSubmitted and
  provides routing/plan-gate/security salience where additionalContext is consumed"* is now
  **exactly backwards** and must go: being first is what makes it not consumed.
- `src/core/.claude/hooks/route-prompt.ps1` **and** `.sh` — the non-Claude branch drains the queue.
- `docs/enforcement-surfaces.md` — correct the Routing, Plan-gate, Security-pass and Boy Scout rows
  and the line-53 narrative; record the CLI version the observation was made on.
- `CHANGELOG.md` (root) + the three `src/stacks/*/files/CHANGELOG.md` — invariant #7.

## 4. Tests — red before green

- **Fixture-level, both twins:** a `userPromptSubmitted` event on a non-Claude surface with a
  non-empty Boy Scout queue yields one JSON payload containing **both** the routing text and the
  queue; with an empty queue, routing only; with neither, no output.
- **Claude surface unchanged, both twins — and asserting "plain stdout" is NOT sufficient.**
  Duplicated Boy Scout text is also plain stdout. The guard must: seed a **real** queue file, send a
  Claude-shaped prompt that produces routing text, assert the output carries **no** Boy Scout
  sentinel, **and assert the queue file still exists afterwards**. That last assertion is the one
  that actually proves Claude's independent `Stop` delivery was not stolen.
- **Queue semantics preserved — keep today's contract literally.** `--mode deliver` reads
  `.claude/.state/boy-scout-queue`, emits it if non-whitespace, and **deletes it unconditionally
  after the read**; it never reads or writes `.claude/.state/last-boy-scout-hash` (which is why
  silence means "already flagged", not "resolved"). Move that behaviour verbatim. Deleting only
  after successful payload composition would quietly change the at-most-once contract — do not.
- **Both known event shapes proven**, since the discriminator stays a substring test: a payload
  with `hook_event_name` → plain stdout; one without → the dual JSON shape.
- **`validate-dist`:** consider a check that fails when any Copilot event carries more than one hook
  entry. This is the machine-checkable residue of the whole finding, and without it the next person
  to add a second entry re-creates it silently. Decide explicitly; if it lands, red-test it by adding
  a second entry to a scratch dist.
- **Live re-verification:** re-run the B-52 canary shape against the *fixed* dist and confirm the
  routing sentinel now arrives. A fixture proving the JSON is well-formed does not prove Copilot
  consumed it — that conflation is what produced this defect.

## 5. Verification

`build.ps1` ×3 + `git status --porcelain dist/` empty → `validate-dist` ×3 → hook suites ×3 → meta
suite → both PowerShell hosts → BOM + machine-path sweeps → both CI legs → release via
`release.ps1`. Shipped behaviour changes ⇒ version bump and four changelog heads before the release
will stamp.

## 6. What this deliberately does not do

It does not attempt to make multiple Copilot hooks work — that is the vendor's to fix. It does not
touch Claude Code's registration. And it does not assume the behaviour is permanent: if Copilot ever
honours every entry, a single composed hook still works and merely stops being necessary, which is
why the fix is written as composition rather than as an ordering trick.
