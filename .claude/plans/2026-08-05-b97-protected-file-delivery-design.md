# B-97 — how a post-bootstrap consumer receives an always-on instruction change

**Status:** DRAFT for adversarial critique. Not locked. No implementation until this is settled.
**Owns:** B-97. **Gates:** B-96, B-99, and every future change to a protected file.

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
- **Against, harder:** Copilot. `AGENTS.md` is protected and Copilot resolves no imports, so the
  mirror must stay fully inlined — meaning the split helps Claude Code and leaves Copilot on the
  manual path. Partial mitigation: `/generate-copilot` is model-invocable and regenerates `AGENTS.md`
  from `CLAUDE.md` + imports, so a consumer who runs it is current. That is still a consumer action.

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

## 4. Recommendation — B first, then A, with C shipped immediately regardless

**Ship C now, independently.** It is small, it is pure gain, and it is the only part that needs no
decision: a drift row that tells a consumer their framework blocks are behind. Twenty-four releases
of silent non-delivery is the cost of not having it.

**Then B**, because it is the only option that fixes the Copilot leg, and because the enabling
primitive it needs — **delimiters marking framework-owned blocks** — is also what C needs to be
accurate and what A needs to know what to move. One small change unlocks all three.

**A stays on the table as the later structural move**, not the first one. It is the better end state
for Claude Code and a worse fit for Copilot; taking it first would fix the stronger surface and leave
the weaker one behind.

Sequencing: delimiters → C (report) → B (`/sync-template`, dry-run by default) → re-evaluate A.

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
