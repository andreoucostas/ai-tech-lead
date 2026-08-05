# B-97 implementation plan — Option A: split framework-owned blocks out of the protected files

**Status:** **rev 2 — LOCKED for implementation.** rev 1 was reviewed adversarially and returned
7 BLOCKING findings with verdict *redesign*. All seven are accepted; two of them are dissolved rather
than patched, by a new observation (canary 5). Every decision rev 1 deferred "to review" is now decided.
**Owns:** B-97 implementation. **Design authority:**
`.claude/plans/2026-08-05-b97-protected-file-delivery-design.md` (DESIGN COMPLETE, rev 3).

> **rev 1 → rev 2, in one line each.** One carrier, not two (canary 5). The composer does **not** catch
> a missed snippet rename — it silently empties the section, so a new inventory gate is required. The
> reference sweep is 77 sites across six file types, not ~20 markdown ones. The Claude legacy path is
> **discovery, not delivery**, and B-97 does not fully close on ship. The commit sequence had a
> knowingly-red step. Boy Scout's permanent gap is now stated. Brownfield collision is decided.

---

## 0. Settled by observation (do not re-litigate)

| Question | Answer | Evidence |
|---|---|---|
| `@import` resolves from a root `CLAUDE.md`? | Yes | Canary 1, zero tool calls |
| `.github/instructions/` reaches Copilot CLI? | Yes | Canary 2, with negative control |
| Narrow `applyTo` delivers on a fileless prompt? | **No** — ship `"**"` | Canary 3 |
| `.github/instructions/` reaches VS Code agent mode? | Yes | Canary 4 (manual, n=1 — stays qualified) |
| Stale `AGENTS.md` overrides fresh instructions? | **No** — fresh wins, *on Copilot VS Code only* | Canary 4 (manual, n=1) |
| **Does Claude Code resolve an `@import` pointing INTO `.github/instructions/`, frontmatter and all?** | **Yes** | **Canary 5 (new, 2026-08-05)** |

**Canary 5**, run because rev 1's two-carrier scheme was found to violate meta-invariant #1.
`.claude/scripts/canary-single-carrier.ps1`, two arms, distinct sentinels, identical prompt:

| Arm | `CLAUDE.md` imports | Result |
|---|---|---|
| control | `@.claude/framework-rules.md` (canary 1's known-positive) | sentinel returned |
| subject | `@.github/instructions/framework-rules.instructions.md`, **with `applyTo: "**"` frontmatter** | sentinel returned |

Verified independently of the script's own check: `"type":"tool_use"` occurs **0 times** in the subject
transcript, the sentinel occurs **0 times** in that fixture's `CLAUDE.md` and once in the instructions
file, and the returned result was exactly the sentinel. The control arm reproducing canary 1 is what
makes the subject arm mean anything.

**What canary 5 does not establish:** it is n=1 like canary 1, and for the same reason that is adequate
— it measures the host's *deterministic* context assembly, not a stochastic model behaviour. It says
nothing about precedence between conflicting rule copies (§5.3), which is a model behaviour and is
explicitly **not** settled.

---

## 1. Scope

### 1.1 Which blocks move

Exactly the four that are framework-owned *and* that `/bootstrap` does not rewrite:

| Block | Moves? | Evidence |
|---|---|---|
| Verification Rules, Leanness, SOLID | **Yes** | absent from `bootstrap.md` Phase 3a's rewrite list |
| Agentic Workflow | **Yes** | `bootstrap.md:181` — *"Preserve the Agentic Workflow section as-is"* |
| Boy Scout Rule | **No** | `bootstrap.md:179` rewrites it from the repo's actual debt — consumer-augmented |
| Conventions, Codebase Context, Repository Structure, Architecture Decisions, Common Tasks, What We've Learned | **No** | bootstrap-populated |

**State the Boy Scout consequence rather than leaving it implicit** (review, NON-BLOCKING 8): after
bootstrap, Boy Scout content is consumer-owned, so **future framework changes to the Boy Scout scaffold
remain greenfield-only, permanently, and B-97 does not fix that.** Stop describing its content as
framework-deliverable anywhere it is so described.

### 1.2 Carriers — ONE file, both legs

| Host family | Carrier | Protected? | Consumer action |
|---|---|---|---|
| Claude Code | `.github/instructions/framework-rules.instructions.md`, reached by `@`-import from `CLAUDE.md` | No | **one line, once** |
| Copilot (CLI + VS Code agent mode) | the **same file**, read natively | No | **none** — arrives on update |
| Codex, Cursor, Gemini, Aider | `AGENTS.md`, unchanged (keeps the four blocks inline) | Yes | none possible; status quo |

`.claude/framework-rules.md` from rev 1 **does not exist**. Frontmatter, fixed by canary 3 and carried
unchanged into Claude's context per canary 5:

```yaml
---
applyTo: "**"
---
```

Explicit `"**"` rather than omitting frontmatter: both deliver, but the explicit form states intent
instead of resting on an undocumented default.

**Why one carrier is materially better, not merely tidier:** two carriers meant two authored copies in
`src/`, which collides head-on with meta-invariant #1 (author once, compose) and recreates the
delivery-drift defect *inside* `src/` — the review's second BLOCKING finding. One carrier deletes the
duplication, the byte-identity gate, and the composer-alias mechanism rev 1 was going to need.

### 1.3 `AGENTS.md` keeps its inline copy

Do not strip the four blocks from `AGENTS.md`. Only Copilot reads `.github/instructions/`; Codex,
Cursor, Gemini and Aider have neither an import nor an instructions mechanism, so stripping would
delete the ruleset outright for four advertised hosts. Absence of usage telemetry is not evidence those
consumers are fictional.

Accepted cost, stated in the release notes: **Copilot receives the rules twice** (`AGENTS.md` + the
instructions file). Measured via `static.copilot` in `meta/context-footprint.json`.

**Parity is not "byte-identical", and rev 1 said so wrongly.** `AGENTS.md` deliberately condenses
Agentic Workflow steps 2–6; `template-checks` has only ever compared **§1** of that section. The
correct definition, which §4.1 implements:

| Pair | Relation |
|---|---|
| carrier § Verification Rules / Leanness / SOLID ↔ `AGENTS.md` same sections | verbatim |
| carrier § Agentic Workflow **§1 only** ↔ `AGENTS.md` §1 | verbatim |
| carrier § Agentic Workflow steps 2–6 ↔ `AGENTS.md` | **intentionally divergent — never compared** |
| `CLAUDE.md` § Boy Scout Rule ↔ `AGENTS.md` § Boy Scout Rule | verbatim (unchanged) |

### 1.4 Non-goals

No change to `$protected`. No `/sync-template`, no block-replacing writer, no write to a protected file.
No consumption of `meta/block-manifest.json` (§7). No change to `/rebootstrap`. No new context for
migrated or greenfield consumers.

---

## 2. Source-side changes (`src/`)

### 2.1 New core file: `src/core/.github/instructions/framework-rules.instructions.md`

Move the four sections out of `src/core/CLAUDE.md` **verbatim, including their `<!-- @stack:NAME -->`
markers**, under the `applyTo` frontmatter. Move the corresponding snippet directories in **all three**
stacks [#1]:

```
src/stacks/<stack>/snippets/CLAUDE.md/<NAME>
  → src/stacks/<stack>/snippets/.github/instructions/framework-rules.instructions.md/<NAME>
```

The **exact and complete** move set — 16 markers × 3 stacks = **48 files** (verified against
`src/core/CLAUDE.md` and all three snippet directories, which currently hold an identical 28-name set):

```
verif-rules  verif-rule9                                   (Verification Rules)
lean-1-2  lean-4-8  lean-10  lean-test  lean-structure     (Leanness)
solid-intro  solid-1-5  solid-mechanism  solid-backstop    (SOLID)
workflow-bullets  security-pass  exec-subtasks  exec-buildtest  verif-conf-line   (Agentic Workflow)
```

Everything else stays: `stamp` (header), `repo-structure`, `repo-diagram`, `defaults-comment`,
`skills-list`, `enforce-skills`, `registers`, `bs-add`, `bs-subtract`, `bs-primary-add`,
`bs-primary-subtract`, `bs-items-note`.

> **rev 1 contained a false safety claim; this is the review's first BLOCKING finding and it is
> correct.** rev 1 said the composer "already fails on unresolved markers — the existing safety net for
> a missed rename". **It does not.** `Get-SnippetLines` returns an empty array for an absent snippet
> (`scripts/build.ps1:99-100`) and awk's `emit_snip` emits nothing for an unreadable path
> (`scripts/build.sh:51-54`); the marker line is consumed either way. The twins agree. A missed rename
> therefore produces a **marker-free, valid-looking dist with a silently empty rule section** — the
> exact defect class the plan claimed protection from. §4.0 replaces the imagined safety net with a
> real one.

File header (framework-owned):

```markdown
<!-- FRAMEWORK-OWNED — replaced wholesale by the installer on every update. Do not edit.
     Repo-specific rules belong in CLAUDE.md (Conventions, Boy Scout Rule). -->
```

### 2.2 `src/core/CLAUDE.md`

- The four sections are replaced **at their current position** by
  `@.github/instructions/framework-rules.instructions.md` plus a short framework-owned comment naming
  what it carries and warning that deleting the line disables four rule sets.
- Amend — do not delete — the header's *"single source of truth"* sentence: `CLAUDE.md` is the
  repo-specific source of truth and imports the framework rules.
- Keeping the import at the sections' current position preserves rule-before-repo-content ordering in
  the assembled context and makes the `docs-sync-check` line-budget shift a known quantity.

### 2.3 Cross-reference sweep — 77 sites, six file types

rev 1 estimated ~20 markdown sites. **Measured, `src/` only:**

| Reference | Count |
|---|---|
| `CLAUDE.md > SOLID` | 38 |
| `CLAUDE.md > Leanness` | 22 |
| `CLAUDE.md > Verification Rules` | 11 |
| `CLAUDE.md > Agentic Workflow` | 6 |
| **Total** | **77** |

They live in `.md`, `.yaml` (eval cases), `.sh`, `.ps1` (`route-prompt`, `guard`, `session-start`),
`.js` and `.cs` samples, and **extensionless snippet files** (`snippets/.claude/commands/feature.md/leanness`,
`snippets/.claude/agents/solid-check.md/intro`). A markdown-only sweep — rev 1's proposal — would have
missed the live hooks, which is the worst possible miss. Also present and easy to overlook: the
markdown-link form `[CLAUDE.md](./CLAUDE.md) > Agentic Workflow` in all three `AGENTS.md`.

Do **not** sweep by hand. Build §4.2's gate first, run it, and let it enumerate. Rewrite each site to
name the carrier, in one consistent form:

> `` the framework rules (`.github/instructions/framework-rules.instructions.md` › Leanness; `AGENTS.md` › Leanness on AGENTS.md-native tools) ``

Bare citations that carry no path (*"Verification Rule #1"*, *"Leanness #7"*) need **no** change — only
path-shaped references do.

**Explicit policy decision, so the implementer does not guess:** references inside `CHANGELOG.md` files
are **historical text and are not swept.** A changelog records what was true at that version. The gate
in §4.2 must exclude changelogs by path, and say so in a comment.

### 2.4 Dependent matrix (the review's fourth BLOCKING finding — enumerate, don't gesture)

Hook *behaviour* is unaffected — no hook parses `CLAUDE.md` for these headings. What changes is every
**canonical-source claim**. Each row is a required edit:

| File | What it claims | Action |
|---|---|---|
| `src/core/.claude/hooks/route-prompt.{ps1,sh}` | rails "mirror `CLAUDE.md > Agentic Workflow` section 1 — the canonical definition, already in your context"; two `CLAUDE.md > Leanness` cites each | retarget to the carrier; keep "already in your context" (true via the import) |
| `src/core/.claude/hooks/session-start.{ps1,sh}` | routes to `CLAUDE.md > Agentic Workflow` (section 1) | retarget |
| `src/core/.claude/hooks/guard.{ps1,sh}` | header cites `CLAUDE.md > Verification Rules #5/#7` | retarget the header comment; the `Verification Rule #N` strings in block reasons are bare cites — leave |
| `src/core/docs/enforcement-surfaces.md` | routing is Instructed via `CLAUDE.md §1` | retarget **and** add the delivery-tier row (§5.4) |
| all three `src/stacks/*/files/AGENTS.md` | markdown-link cites to `CLAUDE.md > Agentic Workflow` for condensed steps 2–6 | retarget the link, keep the condensation |
| `src/core/.claude/commands/{docs-sync,refactor,review,design,impact}.md`, `.claude/agents/solid-check.md` + `.github` twins | section cites | retarget |
| all stacks' `add-tests`, `enforce-architecture` SKILL.md (`.claude` **and** `.github` copies) | section cites | retarget |
| all stacks' `tests/evals/cases.yaml` | 20+ cites in expectations | retarget; re-run the suite |
| all stacks' `README.md`, `docs/defaults.md`, `docs/REVIEW-GUIDE.md`, language samples (`.js`, `.cs`) | section cites | retarget |
| `src/core/tests/hooks/ScriptTwinParity.Tests.ps1` | fixtures hard-code the current layout | update fixtures |
| all stacks' `CHANGELOG.md` | historical claims | **do not touch** (§2.3) |
| `src/core/scripts/docs-sync-check.{ps1,sh}` | required-heading list is checked against **`AGENTS.md`**, which keeps the blocks | **no change needed** — verified at `docs-sync-check.ps1:66`; rev 1 wrongly flagged this |

---

## 3. Installer — no change, plus one decided edge case

Both the carrier and its directory sit outside `$protected` (verified across all six dist installer
twins: eight protected paths, neither among them), so update mode copies them. Verify by observation
(§6.2), not by reading.

**Brownfield collision — DECIDED (rev 1 left it open; the review's seventh finding):** extend the
**brownfield-only** archive to cover a pre-existing
`.github/instructions/framework-rules.instructions.md`, moving it to `docs/pre-adoption/` with the same
provenance the other archived originals get. Rationale: brownfield's contract is *nothing the consumer
already had is destroyed without a copy*, and a name collision — however unlikely — would violate it
silently. **Update mode is explicitly excluded**: overwriting there is the delivery mechanism.

`.github/instructions` remaining an `$adoptionSignals` entry is a pre-existing wrinkle (a consumer who
deletes `.claude/framework-version.json` re-detects as brownfield). Accepted, noted, not fixed here.

---

## 4. Gates — each red-tested before its green counts (Maintenance model #4)

### 4.0 NEW, and the highest-priority gate: marker-expansion inventory

Replaces the safety net rev 1 imagined. In `validate-dist.{ps1,sh}` (or `build`, if the implementer
shows it fits better — but then in **both** twins):

1. Derive, mechanically, the set of `(core-relpath, NAME)` markers from `src/core/**`.
2. For each `(relpath, NAME, stack)`, assert the composed dist region is **non-empty** — i.e. every
   marker that had a snippet before the move still expands to content after it.
3. Fail loudly, naming relpath + marker + stack.

**Red-test:** delete one snippet file (e.g. `lean-test` for angular) → non-zero exit naming it; restore
→ clean pass. This is the test that would have caught the failure mode rev 1 was blind to, so it is not
optional and it is not "verified by inspection".

### 4.1 `template-checks.{ps1,sh}` — retarget the mirror check, layout-tolerantly

Implement exactly the parity table in §1.3 — including that Agentic Workflow steps 2–6 are **never**
compared. Keep the "missing section" hard failures, retargeted, so deleting a block still fails.

**The shipped gate must accept both layouts.** It runs in the *consumer's* repo, and an un-migrated
consumer legitimately has the sections in `CLAUDE.md` with no carrier. Resolve each section from the
carrier if present, else `CLAUDE.md`; fail only if neither has it. Without this, every un-migrated
consumer's gate goes red for having not yet done a migration they may not know about.

**Red-test:** delete a line from `AGENTS.md` § Leanness → non-zero naming the section; restore → pass.
Then a second red-test proving the layout-tolerance branch: a fixture in the old layout must pass, and
one missing the section in *both* locations must fail.

### 4.2 New gate: section-path references resolve

Scan **every shipped textual file** — not `*.md` (review finding 3) — using the binary/text
classification already used elsewhere in the gates. Match a **finite registry** of citation forms:

- carriers: `CLAUDE.md`, `AGENTS.md`, `.github/instructions/framework-rules.instructions.md`
- both plain (`` `CLAUDE.md > Leanness` ``) and markdown-link (`[CLAUDE.md](./CLAUDE.md) > Leanness`) forms
- headings: the finite set that exists in the dist, longest-match

Assert each cited heading exists in the cited file. Exclude `CHANGELOG.md` by path (§2.3).

A permissive heading regex is the wrong shape: rev 1's version would fire on prose continuations like
`CLAUDE.md > Conventions wins on any conflict` and `CLAUDE.md > Boy Scout Rule before considering the
work complete`, and the fix under time pressure is to weaken it until it catches nothing — B-59's
inert-check class. A finite registry cannot over-fire, so it cannot be weakened.

**Red-test with real shapes, not a synthetic one:** plant a citation to a heading that has genuinely
moved (`CLAUDE.md > SOLID` after the split) → non-zero naming file and line. Also assert the two
prose-continuation shapes above do **not** fire. Run the gate before the sweep to enumerate the 77
sites, and after to prove completeness.

### 4.3 `validate-dist` — the import must resolve

Assert the shipped `CLAUDE.md` contains `@.github/instructions/framework-rules.instructions.md` and that
the file exists in the dist. **This lands in the same commit that introduces the import** (§8), never
later. Red-test: remove the line → non-zero; restore → pass. Both twins.

### 4.4 `context-footprint.{ps1,sh}`

- The carrier joins **both** `static.claude` (Claude resolves the import into every turn) and
  `static.copilot` (Copilot reads it natively). The script's own comment already anticipates the second
  half: *"B-17 instructions join static.copilot when added"*.
- **Also fix the derived metric** (review NON-BLOCKING 9, verified at `context-footprint.ps1:293-295`
  and the `.sh` equivalent at 59-60): the monorepo ratio is computed from the `CLAUDE.md` **item alone**,
  which silently stops meaning "static Claude context" the moment part of that context lives in an
  imported file. Recompute it from the group total.
- Expected `static.claude` net change ≈ 0 (content moved, not added) + the import line. **A materially
  different number is information — stop and find out why before shipping.**
- B-68 is adjacent and out of scope.

---

## 5. Migration and discovery

### 5.1 The asymmetry

- **Copilot leg: zero consumer action, delivered.** The file appears at the next update; existing
  consumers are fixed silently. Lead the release notes with this.
- **Claude leg: one line, once.** The framework cannot write it — the boundary condition, not a flaw.

### 5.2 `session-start.{ps1,sh}` conditional pointer

Emit **only** when all three hold: `CLAUDE.md` exists, it does **not** contain the import line, and the
carrier file **does** exist. Silent for greenfield, migrated, and never-delivered consumers.

Content: what to add, where, and a precedence line — load-bearing, because an un-migrated consumer's
`CLAUDE.md` still carries **stale copies of these very sections**:

> *"`.github/instructions/framework-rules.instructions.md` is the current framework ruleset and
> supersedes any identically-titled sections in `CLAUDE.md`. Read it now. To make this permanent, add
> `@.github/instructions/framework-rules.instructions.md` to `CLAUDE.md` where those sections are, and
> delete them."*

Pointer, not content: injecting the blocks would duplicate the stale inline copies in the same window —
producing a contradiction rather than an update — and cost ~7 KB every session. That is what sank
Option D in the design.

Both twins [#3]; both output shapes [#5], reusing the existing surface dispatch. Twin-parity fixtures
for: import present, import absent, `CLAUDE.md` absent, carrier absent.

### 5.3 What this does and does not achieve — B-97 does NOT fully close

The review's fifth BLOCKING finding is accepted in substance. For an existing **Claude Code** consumer,
this ships **discovery, not delivery**: two conflicting copies of the rules are simultaneously visible
(stale inline, fresh carrier), and a prose "supersedes" sentence is asserted precedence, not
demonstrated precedence. Canary 4 settled stale-vs-fresh **only** for Copilot VS Code
(`AGENTS.md` vs instructions); nothing has been observed for Claude Code.

Therefore:

- Release notes and `enforcement-surfaces.md` say **discovery** for the un-migrated Claude case. Do not
  write a sentence that implies the pointer delivers.
- **B-97 moves to Done only for the Copilot leg and for greenfield/migrated Claude consumers.** The
  un-migrated Claude population stays open as a successor entry: *"stale inline rules vs a fresh carrier
  — which does a Claude Code model actually follow?"*, to be answered by a multi-run canary under
  **B-98's six-run rule**, because unlike canaries 1 and 5 this is a stochastic model behaviour.

**Where I part company with the reviewer:** it proposed blocking the release on that evidence, or
splitting into two releases with a migration window. I reject both, and the reason is the counterfactual.
Today an un-migrated Claude consumer has stale rules and **no signal at all**; after this ships they have
stale rules plus a pointer to the current ones. That is a strict improvement under every outcome of the
unrun canary, so gating the improvement on the canary buys nothing and delays the Copilot leg — which is
unambiguous, deterministic delivery to *every* existing Copilot consumer — behind a question that does
not affect it. Ship, label honestly, and run the canary next.

### 5.4 `framework-doctor.{ps1,sh}` — two honest rows

1. **Framework rules delivery** — `[OK]` when `CLAUDE.md` carries the import and the carrier exists;
   `[MISSING]` with the one-line fix when the carrier is present but the import is absent.
2. **Protected-file sync** — compare `CLAUDE.md`'s header version stamp against
   `.claude/framework-version.json`. On divergence, in exactly this wording:

   > `DIVERGED — protected file not synchronized with installed machinery; review required`

   **Never "you are behind."** The divergence proves the protected file was not synchronised; it does
   not prove a block is stale, nor distinguish a deliberate consumer edit.

B-63 applies: both rows read files from the repo root the doctor was given — no host-capability probe,
nothing that answers differently per machine. B-61/B-64 apply: these are the first new doctor rows since
the twins were caught returning opposite verdicts, so each goes into `ScriptTwinParity.Tests.ps1` with
fixtures **and** a planted-defect test asserting the honest row appears.

### 5.5 Commands and docs

`bootstrap.md` and `adopt.md` (all three stacks) must be told never to delete the import line, and
`bootstrap.md`'s *"Preserve the Agentic Workflow section as-is"* now refers to a file it does not touch.
`generate-copilot.md` keeps emitting the four blocks into `AGENTS.md` (§1.3) and must know the carrier is
framework-generated, not hand-edited. `enforcement-surfaces.md` gains a **delivery-tier row** stating
which surfaces receive a framework-rules change on update and which need the one-time migration — and
per §5.3 it must say *discovery* for the un-migrated Claude case. All three `README.md`s and shipped
`CHANGELOG.md`s carry the migration paragraph in the consumer's voice: what appears, what you do once,
what happens if you do nothing.

---

## 6. Verification

### 6.1 Deterministic

`build.{ps1,sh}` ×3 then `git status --porcelain dist/` empty — **run the `.sh` twin too**, since 48
directory renames are exactly where twins diverge. `validate-dist.{ps1,sh}` ×3. Hook suites ×3 + the
meta suite, under **both** PowerShell hosts and a hostile code page. Every gate in §4.0–§4.4 red-tested,
with the failing output recorded in the commit or backlog entry — not asserted.

### 6.2 The test that matters most — update over a pre-B-97 consumer

Fixture in the shape of a real existing consumer: bootstrapped `CLAUDE.md` with the four sections inline
and a stale stamp, populated Conventions, an `AGENTS.md`, `.claude/framework-version.json` at an older
version. Run update mode. Assert:

1. `CLAUDE.md` **byte-identical** to before — if this fails, stop everything;
2. the carrier is present and current;
3. `session-start` emits the migration pointer on **both** output shapes;
4. `framework-doctor` reports `[MISSING]` on delivery and `DIVERGED` on sync;
5. after adding the import and deleting the inline sections by hand, all four go quiet and the doctor is
   clean.

Plus, per the review's sixth §10 answer, two cases rev 1 omitted:

6. a consumer who **edited the carrier** — update overwrites it. That is deliberate (it is
   framework-owned), but it must be *asserted* in the fixture and *disclosed* in the release notes and in
   the file's own header, not discovered by a consumer;
7. brownfield install over a repo that already has a file at the carrier path → archived to
   `docs/pre-adoption/` with provenance (§3).

### 6.3 Also required

Greenfield + brownfield smoke installs, three dists, both twins. **CI green on both legs before this is
called done** — B-70's fourth instance; 48 renames plus new `.sh` gate logic is precisely the shape that
passes on Windows and fails on Linux.

### 6.4 Not required

No re-run of canaries 1–5. Opportunistically worth re-observing, non-blocking: canary 4 (n=1, manual).

---

## 7. Deliberately deferred

- **Manifest consumption** (`meta/block-manifest.json` → a shipped classifier): §5.4's stamp divergence
  is a cheap reliable signal, and per-block staleness answers a question that disappears on migration.
  8 KB shipped for that is Leanness #1. Keep it in `meta/`.
- **Changelog delivery-surface convention** (*machinery* vs *protected* per entry): valuable, cheap, but
  it is a release-process change with its own review surface. Own backlog entry, citing B-97 sweep
  finding 2.
- **The stale-vs-fresh Claude precedence canary** (§5.3) — successor entry, six runs.
- **B-65, B-67, B-68** — adjacent, each has its own entry.

---

## 8. Sequencing — no commit leaves the tree red

The review's sixth finding was correct: rev 1's step 2 removed the sections while `template-checks` still
required them, and the import gate arrived a commit after the import. Corrected:

1. **§4.2 gate + red-test.** Passes on the current tree; proves the instrument and enumerates the 77 sites.
2. **§4.0 marker-inventory gate + red-test.** Passes on the current tree. Both gates exist *before* the
   thing they protect against.
3. **§4.1 layout-tolerance** added to `template-checks` while the old layout is still in place. Green.
4. **The split, atomically:** carrier file + 48 snippet renames + the `CLAUDE.md` import + §4.3's import
   gate + rebuild ×3, in **one commit**. Green because step 3 made the gate layout-tolerant.
5. **§2.3 sweep**, driven by re-running §4.2. Green.
6. §5.2 session-start + fixtures; §5.4 doctor rows + twin-parity + planted-defect tests. Green.
7. §5.5 commands and docs; §4.4 context-footprint. Green.
8. §6.2 update-over-legacy fixture test.
9. Root `CHANGELOG.md`, shipped changelogs (consumer voice), `meta/LEARNINGS.md`, a WSD recording
   Option A + the single-carrier decision + canary 5, backlog: B-97 partially Done per §5.3, successor
   entry filed, RCA.
10. Release **v0.45.0** via `.claude/scripts/release.ps1` [#7]. Watch CI (B-88/B-91).

---

## 9. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| A missed snippet rename silently empties a rule section | **High** | §4.0's inventory gate — the only real defence; red-tested |
| The sweep leaves a dangling cite and a model looks in the wrong file | Medium | §4.2 is both the sweep instrument and the permanent guard |
| Un-migrated Claude consumer holds stale inline rules *and* the pointer | Medium | disclosed as discovery (§5.3); successor canary entry |
| `.sh` twin diverges across 48 renames + new gate logic | Medium | twin-parity fixtures + CI Linux leg before done |
| A consumer edits the carrier and update overwrites it | Low | asserted in §6.2 case 6; disclosed in the file header and release notes |
| Copilot double-loads the rules (`AGENTS.md` + carrier) | Low | identical content; measured in `context-footprint`; §1.3 records the alternative |
