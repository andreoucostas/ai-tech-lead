# B-97 — how a post-bootstrap consumer receives an always-on instruction change

**Status:** DRAFT **rev 2** — reviewed 2026-08-05, **sequencing REJECTED**, recommendation withdrawn.
Not locked. No implementation until the two live canaries in §7 are run.
**Owns:** B-97. **Gates:** B-96, B-99, and every future change to a protected file.

> **rev 1 → rev 2.** The adversarial review rejected the §4 recommendation on four blocking findings.
> The two that carried it: `.github/instructions/` is an **unprotected** Copilot surface the design
> never considered (so Option A's supposed Copilot gap may not exist), and Option C cannot honestly
> say "behind" from on-disk state. §4 is replaced; §7 records the disposition. Findings and the
> corrected sequence are the reviewer's; the verification of its central claim is mine.

## 1. The problem, stated precisely

Framework-owned content and consumer-owned content live **in the same file**, and the ownership
boundary is a *section* boundary inside it. Every delivery mechanism operates on *files*. That
mismatch is the whole defect.

Verified, three independent mechanisms, none of which delivers:

1. **Installer, update mode.** `$protected` = `CLAUDE.md, AGENTS.md, TECH_DEBT.md,
   SECURITY_FINDINGS.md, LEARNINGS.md, FRAMEWORK-CONTEXT.md, .github/copilot-instructions.md,
   docs/ARCHITECTURE.md` (`dist/dotnet/scripts/install.ps1:30-31`). Update mode triggers on
   `.claude/framework-version.json` (`:42`), snapshots those files (`:74-81`), copies the dist over
   the target, then restores the snapshot on top (`:115-123`).
2. **`/bootstrap`** — replaces Conventions only (`src/core/CLAUDE.md:85`), does not enumerate
   Verification Rules among what it rewrites (`bootstrap.md:164-181`), and is
   `disable-model-invocation: true` (`:3`).
3. **`/rebootstrap`** — re-derives from the consumer's own repo; no template or `dist/` source, so
   nothing to deliver *from*.

**The protection is correct and is not the bug.** It was introduced in v0.20.0 as a fix:
*"previously a re-run overwrote a populated `CLAUDE.md` with the template"* (shipped CHANGELOG
`:777`). Clobbering a bootstrapped `CLAUDE.md` is the worse failure. Do not revert it.

**What the framework actually intended** — and this reframes the whole item. The shipped
`CLAUDE.md` header says: *"When you sync template updates, bump these fields and update
`.claude/framework-version.json`"* (`dist/dotnet/CLAUDE.md:6`). Delivery of protected files was
**manual by design**. It is not that a mechanism broke; it is that the manual path was never
assisted, never measured, and the changelog was written as though it were automatic. B-97 is
therefore not "restore delivery" — it is **"make the intended manual path real, or replace it."**

## 2. What the answer must satisfy

1. **Never clobber consumer-owned content.** Non-negotiable; it is why `$protected` exists.
2. **Reach Copilot, not just Claude Code.** `AGENTS.md` and `.github/copilot-instructions.md` are
   both protected, and Copilot has no import mechanism. A Claude-only fix leaves half the supported
   surface unfixed — and per `docs/enforcement-surfaces.md` the Copilot leg is already the weaker one.
3. **Survive `/bootstrap` and `/adopt`.** Both rewrite parts of these files.
4. **Cost no meaningful static context.** Headroom is 1,429 chars (~357 tokens) on dotnet, 2,602 on
   monorepo, ceilings in characters (`meta/context-footprint.json:4-8`).
5. **Degrade honestly.** If a consumer is behind, that must be *visible*, not silent. Silence is what
   produced 24 releases of undetected non-delivery.

## 3. Options

### A. Split framework-owned blocks into an unprotected imported file
Move Verification Rules / Leanness / SOLID / Boy Scout / Agentic Workflow into
`.claude/framework-rules.md`; `CLAUDE.md` keeps consumer-owned sections and imports it via
`@.claude/framework-rules.md`. The imported file is unprotected → delivers on every update, forever.

- **For:** permanent structural fix — the ownership boundary becomes a file boundary, which is what
  every mechanism already operates on. The `@path` import is already used and proven in this repo
  (`.claude/commands/{feature,fix,refactor,debt}.md` all inline `@.claude/workflow.md`).
- **Against:** one-time migration needed — the consumer must add the import line, which is a
  `CLAUDE.md` edit the framework cannot make. Chicken-and-egg, but *once*.
- **~~Against, harder: Copilot.~~ WITHDRAWN at rev 2 — this was the argument that decided B over A,
  and it does not survive.** rev 1 claimed `AGENTS.md` is protected and Copilot resolves no imports,
  so A leaves Copilot on the manual path. The second half was asserted with no repository evidence.
  More importantly, **`.github/instructions/` is not protected**: `install.ps1:31` lists eight
  protected paths and that directory is not among them, while `:37` names it in `$adoptionSignals` —
  so the framework recognises it as an AI-tooling surface *and lets it update*. **B-17** already
  plans to use it (`applyTo:`-scoped instruction files generated by `/generate-copilot`). If a
  framework-rules instruction file works there, Option A gains a native unprotected Copilot leg and
  the case for B collapses. Unverified — see §7 canary 2.
- **Against (still standing):** `/generate-copilot` regenerating `AGENTS.md` is *not* a free
  mitigation. Both `AGENTS.md` and `.github/copilot-instructions.md` are protected, i.e. the
  installer made an explicit ownership decision; calling them "generated" does not undo it, and a
  consumer may have edited them. Regeneration must be developer-initiated, diff-first and
  backup-backed, or it reintroduces the v0.20.0 clobber in a new place.

### B. Assist the manual sync (the documented intent, made real)
Keep the layout. Add (i) machine-readable delimiters around framework-owned blocks, (ii) a drift
check that compares the consumer's blocks against the shipped version and reports staleness, and
(iii) a model-invocable `/sync-template` that replaces **only** the delimited blocks, leaving
everything else untouched.

- **For:** works identically for `CLAUDE.md`, `AGENTS.md` and `copilot-instructions.md` — so it fixes
  the Copilot leg, which A does not. No restructure, no import semantics, no chicken-and-egg: the
  delimiters ship in the template and the *tool* finds the blocks by heading if they are absent.
  Matches the documented intent rather than replacing it.
- **Against:** relies on the consumer running it. Delivery becomes opt-in, so it is "reliably
  offered", not "automatic".
- **Against:** a block-replacing tool that gets its boundaries wrong destroys consumer content — the
  exact failure v0.20.0 fixed. Needs a dry-run default and a backup, and needs red-testing.

### C. Report only — a doctor/`docs-sync` row that names the drift and stops
- **For:** cheapest, honest, consistent with WSD-027 (tooling may verify but not promote). Zero risk
  to consumer content.
- **Against:** delivers nothing. On its own it converts a silent failure into a visible one, which is
  real progress but does not close the gap.

### D. Session-start hook injection
The hook is unprotected and runs every session; it could inject framework rules as context.
- **Against, likely fatal:** duplicates content already in a greenfield consumer's `CLAUDE.md`
  (double context cost against a ceiling with ~357 tokens of headroom); per meta-invariant #5 the
  output shape differs per surface and Copilot VS Code without Preview hooks receives nothing; and it
  makes always-on rules invisible in the file that is supposed to be the single source of truth.
  Recorded so it is not re-proposed without new information.

## 4. ~~Recommendation — B first, then A, with C shipped immediately regardless~~ WITHDRAWN

rev 1 recommended: delimiters → C → B → re-evaluate A. **Rejected at review, and the rejection is
accepted.** Both load-bearing arguments failed:

- *"B is the only option that fixes the Copilot leg"* — false, or at least unproven.
  `.github/instructions/` is unprotected and delivers (§3.A, verified). A may have a native Copilot
  leg after all.
- *"Ship C now regardless"* — false **as worded**. C cannot truthfully report "behind" (§5 below).
  A weaker, honestly-labelled row is shippable; the confident one is not.

Nothing is recommended in rev 2. The next step is evidence, not a decision — see §7.

### Option E (added at review) — conditional discovery, no protected-file write

Not a delivery mechanism; a *discovery* mechanism, and the missing piece rev 1 lacked. Option D was
rejected for injecting duplicate rules on every turn; E injects a **pointer**, not content:

- an unprotected **versioned migration manifest** carrying canonical historical block fingerprints;
- `session-start` (and/or `route-prompt`) emits a short warning **only** when a protected file
  fingerprints as known-old or unknown-diverged — both hooks are unprotected and registered on Claude
  and Copilot (`settings.json:4`, `hooks.json:5`), and `session-start` already conditionally reads
  files and warns (`session-start.ps1:54`);
- doctor and `/docs-sync` expose the same classification;
- **no automatic write to a protected file**; acknowledgment is stored outside it.

Its measured cost is hundreds of characters, against ceilings that are characters not tokens. It
cannot be the sole Copilot answer — VS Code without Preview hooks drops hook output
(`enforcement-surfaces.md:24,36`) — but it materially improves discovery for the existing population,
which is the one that has been silently behind for 24 releases.

## 5. Migration and the honest limit

Every option requires **one consumer action, once** — because the framework cannot write to a file it
has correctly promised not to touch. That is not a flaw in the options; it is the boundary condition.
The design goal is to make that action *discoverable and safe*, not to eliminate it.

**State this in the changelog rather than around it.** Per B-97's second sweep finding, every release
entry should say whether it lands as *machinery* (delivers on update) or *protected* (needs the sync
action). That convention can ship with C and costs nothing but candour.

## 6. Open questions for the critique

1. **Is B's block-replacement safe enough to exist?** It writes into a consumer-owned file. What is
   the minimum guard set — dry-run default, backup to `docs/pre-adoption/`, refuse on any consumer
   edit inside a delimited block, refuse when delimiters are absent rather than guessing by heading?
   Is "refuse when absent" a fatal usability problem for the 24 releases' worth of consumers who have
   no delimiters at all?
2. **Does the `@import` in A actually resolve for a consumer's `CLAUDE.md`?** Proven for
   `commands/*.md` in this repo; *assumed* for `CLAUDE.md`. Must be verified by observation before A
   is costed, not asserted. If it does not resolve, A collapses.
3. **Is the Copilot leg worth this much weight?** It drives the recommendation of B over A. If Copilot
   consumers are a small or declining population, A becomes the better first move. This is a
   maintainer fact, not a repo fact — flag it for the maintainer rather than guessing.
4. **Does C's drift check have a defensible comparison basis?** It must compare the consumer's blocks
   against the *shipped version they installed*, which means knowing that version — `.claude/framework-version.json`
   gives it, but the consumer's file may have been legitimately edited. Distinguish "behind" from
   "deliberately diverged", or the row cries wolf and gets ignored.
5. **Does this subsume B-78 and part of B-46?** Both describe pieces of the same delivery gap. If so,
   say which parts, so they are closed rather than left as duplicates.

## 7. Review disposition (2026-08-05) and the corrected next steps

Four BLOCKING findings, one NON-BLOCKING. All accepted. One central claim re-verified independently
before acceptance (`install.ps1:31` vs `:37`) rather than taken on the reviewer's word.

| # | Finding | Disposition |
|---|---|---|
| 3 | The Copilot argument deciding B over A is unverified; `.github/instructions/` is unprotected and was never considered | **Accepted, verified myself.** §3.A rewritten, §4 withdrawn |
| 4 | Root-`CLAUDE.md` import resolution is unverified — proven only for `commands/*.md` | **Accepted.** Was already flagged as assumed; now canary 1 |
| 5 | Option C cannot truthfully say "behind" from on-disk state | **Accepted.** See below — the mismatch it *can* detect is real but weaker |
| 2 | `/generate-copilot` regenerating protected files can erase consumer edits | **Accepted.** Folded into §3.A as a standing con |
| 6 | No conditional-discovery path considered | **Accepted.** Added as Option E |

**On finding 5, the honest version of C.** The installer overwrites `.claude/framework-version.json`
during the general copy (`install.ps1:87`) and then restores the *old* protected `CLAUDE.md`
(`:115`), whose header carries its own version stamp. So the two stamps diverge on every update, and
that divergence is a **reliable, cheap signal that the protected file was never synced**. What it
does *not* prove is that any particular block is stale, or that a difference is not a deliberate
consumer edit. C therefore ships as `DIVERGED — protected file not synchronized with installed
machinery; review required`, never as "you are behind". The confident version needs the versioned
fingerprint manifest, which is Option E's manifest — the same artifact, so build it once.

**Corrected next steps — evidence before decision.** Steps 1 and 2 are **live host canaries**; they
cannot be answered by reading the repo, and asserting them from general knowledge of how the hosts
behave is exactly what this review caught twice.

1. ~~**Canary: does `@.claude/framework-rules.md` resolve from a root `CLAUDE.md`?**~~
   **RUN 2026-08-05 — POSITIVE. It resolves. Option A does not collapse; it is viable.**

   Method: scratch consumer, sentinel `ZORBLAX-7Q4M` present **only** in `.claude/framework-rules.md`,
   root `CLAUDE.md` carrying `@.claude/framework-rules.md` and not the sentinel; prompt asked for the
   codeword, forbade reading files, and offered `NOT-IN-CONTEXT` as the escape.

   Result: the model answered `ZORBLAX-7Q4M`. Verified independently of the script's own check —
   **the transcript contains zero tool invocations of any name**, so it could not have reached the
   sentinel by reading; and the control re-check confirms `CLAUDE.md` does not contain the sentinel
   while the imported file does. Script: `scratchpad/canary1-import.ps1` (exit 0 = POSITIVE, 1 =
   NEGATIVE, 2 = INCONCLUSIVE, where a positive is downgraded to inconclusive if any file tool ran).

   **n=1 is adequate here, and the reason matters:** this measures the *host's* context assembly,
   which is deterministic — the import is either resolved before the model sees anything, or it is
   not. That is categorically unlike routing (canary/B-98), which is a stochastic model behaviour and
   is why six runs are registered there. Do not cite this run count as precedent for those.

   **Scope of the claim:** proves the mechanism for Claude Code CLI. It says nothing about Copilot —
   which Option A never claimed via imports, and which canary 2 owns.
2. ~~**Canary: does an unprotected `.github/instructions/` file reach Copilot?**~~
   **RUN 2026-08-05 on Copilot CLI 1.0.77 — POSITIVE. It reaches. The recommendation flips to A.**

   Three-way controlled design, because a bare null would not distinguish "the surface does not
   deliver" from "my method is wrong":

   | Arm | Fixture | Result |
   |---|---|---|
   | **Subject** | sentinel only in `.github/instructions/framework-rules.instructions.md` (`applyTo: "**"`) | sentinel returned |
   | **Positive control** | sentinel only in `.github/copilot-instructions.md` (known-supported) | sentinel returned |
   | **Negative control** | no instruction file at all | returned `NOT-IN-CONTEXT`, as designed |

   Raw output shows `Changes +0 -0` and no tool invocation, so the model did not reach the sentinel
   by reading. The negative control is what makes the positive meaningful: with no instruction file
   the model correctly reports absence rather than confabulating.
   Script: `.claude/scripts/canary-copilot-instructions.ps1`.

   **Two limits on this claim, both material:**
   - **Copilot CLI only.** VS Code agent mode is untested, and Preview-hooks-disabled VS Code
     especially so — the surface `docs/enforcement-surfaces.md` already rates weakest. The review
     asked for both; only one was run. Precedence against a stale `AGENTS.md` is also untested.
   - ~~`applyTo: "**"` was used, and B-17 rejected a `**` variant…~~ **SETTLED by canary 3, below —
     and the feared collision with B-17 was overstated on two counts.**
3. Define the historical fingerprint / migration manifest (design work, no host needed — **this is
   the only step executable today**).
4. Ship the honestly-labelled C row plus Option E conditional discovery.
5. Re-evaluate A versus a substantially redesigned B.

~~Both canaries need live agent sessions and therefore quota.~~ **Both were run on 2026-08-05.**
Quota was never the binding constraint — the actual blocker was that no agent host resolves by bare
name on this box (see the host-path table in `DEVELOPING.md`), and measured cost was ~$0.05/run.

## 8. Conclusion (rev 3) — Option A, both legs proven

**Split the framework-owned blocks out of the protected files into unprotected ones, delivered
natively per host.** Both legs are now observed, not assumed:

| Host | Carrier | Protected? | Evidence |
|---|---|---|---|
| Claude Code | `CLAUDE.md` → `@.claude/framework-rules.md` | **No** — delivers on update | Canary 1, positive, zero tool calls |
| Copilot | `.github/instructions/framework-rules.instructions.md` | **No** (`install.ps1:31` vs `:37`) | Canary 2, positive, with negative control |

Option B (`/sync-template` writing into a consumer-owned file) is **dead**: it existed only because A
was thought to leave Copilot stranded, and it carried the v0.20.0 clobber risk into a new place for
no remaining benefit.

**The migration asymmetry is the best property of this answer, and it was not visible in rev 1:**

- **The Copilot leg needs no consumer action at all.** `.github/instructions/` is unprotected, so the
  file simply appears at the next update. Existing consumers are fixed silently and immediately.
- **The Claude leg needs one line, once** — the `@import` added to a `CLAUDE.md` the framework may not
  write. That is the whole of the remaining migration problem, and it is now small enough to solve
  with Option E's conditional machinery: `session-start` is unprotected and already reads files
  conditionally, so it can inject the rules **only when the import line is absent**. That carries no
  double-context cost for migrated or greenfield consumers, which is precisely what sank Option D.

### Canary 3 (2026-08-05) — `applyTo` breadth is load-bearing, and there is a cleaner option

Three arms, identical fileless prompt, distinct sentinels, a real `Program.cs` present so a
`**/*.cs` glob had something to match. Script: `.claude/scripts/canary-applyto-scope.ps1`.

| `applyTo` | Delivered? |
|---|---|
| `"**"` | **yes** |
| `"**/*.cs"` | **no** — returned `NOT-IN-CONTEXT` |
| *no frontmatter at all* | **yes** |

1. **A narrow `applyTo` does not deliver on a prompt that names no file.** Framework rules, which
   must arrive on every task, therefore cannot be narrowly scoped.
2. **No frontmatter also delivers** — an option neither the design nor the review considered, and it
   sidesteps the `**` question entirely. Prefer explicit `applyTo: "**"` for a shipped artifact
   nonetheless: it states the intent, whereas no-frontmatter leans on an undocumented default that
   can change silently. Recorded because it is the fallback if `"**"` ever becomes contentious.
3. **The collision with B-17 was overstated, on two counts.** B-17's *"no `applyTo: **` variant"* is
   scoped to its own item — **scoped instruction delivery for _test files_** — and rejects shipping a
   broad variant *of the test-integrity rules*, not a broad framework-rules file. And canary 3
   **validates B-17's premise with evidence it never had**: narrow scoping genuinely gates delivery
   on the model touching a matching file, which is exactly the "highest marginal salience" behaviour
   B-17 is after. The two designs are complementary, not in conflict.

### Canary 4 (VS Code) — POSITIVE, and it also settles the stale-`AGENTS.md` precedence question

> **Correction.** An earlier revision of this section stated the GitHub Copilot extension was not
> installed and that VS Code could therefore not be tested here. **That was wrong.**
> `code --list-extensions` **excludes built-ins**, and VS Code 1.128 ships **`GitHub.copilot-chat`
> v0.56.0 as a built-in** under a versioned install path
> (`…\Microsoft VS Code\fc3def6774\resources\app\extensions\copilot`). The
> `globalStorage\github.copilot-chat` entry was the true signal and was misread as a stale remnant.
> Method lesson worth keeping: **`--list-extensions` is not an inventory of what the host can do.**

Fixture (`C:\temp\b97-canary4-vscode`) deliberately set the two sources against each other — the
state every already-installed consumer is actually in:

- **fresh** codeword `NIMBUS-2X9K` in `.github/instructions/framework-rules.instructions.md` (unprotected)
- **stale** codeword `OBSOLETE-1A1A` in `AGENTS.md` (protected — what a consumer still carries)

**Result: `NIMBUS-2X9K`.** Two findings in one run:

1. **`.github/instructions/` reaches VS Code agent mode**, not merely the CLI. The Copilot leg holds
   on both surfaces.
2. **Fresh instructions beat the stale protected mirror.** This was the open risk that could have
   sunk the whole design: if `AGENTS.md` won, every existing consumer's stale copy would override
   what we deliver, and Option A would deliver text that never takes effect.

**Evidential status, stated plainly:** this is a **single manual observation reported by the
maintainer**, not a machine-captured transcript like canaries 1–3, so there is no tool-use check
behind it. It is strong — the sentinel is unambiguous and the *discriminating* answer was returned
rather than the more conspicuous root-level `AGENTS.md` value — but it is n=1 and unautomated. Re-run
it if VS Code or the built-in Copilot version changes materially.

Also resolved: **B-17's claim that `.github/instructions/` "works today with Preview hooks off"** is
now supported for VS Code agent mode. Instruction files are a native Copilot feature and do not
depend on the Preview hooks machinery at all — which is why the hook-availability caveat that governs
`session-start` output does not apply to this delivery path.

## 9. Status: DESIGN COMPLETE — every question closed by observation

| Question | Answer | Evidence |
|---|---|---|
| Does `@import` resolve from a root `CLAUDE.md`? | Yes | Canary 1 (zero tool calls) |
| Does `.github/instructions/` reach Copilot CLI? | Yes | Canary 2 (+ negative control) |
| Does a narrow `applyTo` deliver on a fileless prompt? | **No** — ship `"**"` | Canary 3 |
| Does `.github/instructions/` reach VS Code agent mode? | Yes | Canary 4 (manual) |
| Does a stale `AGENTS.md` override it? | **No** — fresh wins | Canary 4 (manual) |

Nothing in this design now rests on an assumption about host behaviour. Implementation may proceed.
