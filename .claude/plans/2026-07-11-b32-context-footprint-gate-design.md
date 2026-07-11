# B-32 context-footprint gate — design (P0)

> **Status (2026-07-11): design FINAL (rev-2)** — adversarially critiqued 2026-07-11 (verdict:
> **LOCK WITH AMENDMENTS**; 2 HIGH + 5 MEDIUM + 5 LOW, all folded; findings log at the bottom;
> both HIGH findings independently re-verified by the maintainer session before folding).
> Decision record: **WSD-017**. Design-first per the Investigation meta-workflow.
> Implementation is maintainer-side (no shipped-behavior change → no version slot per
> invariant #7), freeze-compatible in principle, but recommended **immediately after Phase 6 /
> v0.26.0** so the first committed baseline measures the first merged release, and **before or
> with B-27** (v0.27.0) so the wiki inherits the counting rule (D7). The one shipped piece
> (doctor surfacing, D6) rides B-16 (≥ v0.28.0).

## Problem and trigger

B-26 records an accepted debt: *"CLAUDE.md §1 rails reach the model up to 3× per prompt …
token cost accepted for salience; **re-measure if context budgets tighten**."* That trigger has
fired (maintainer, 2026-07-11: consumers are becoming token-cost conscious). But there is no
measurement machinery anywhere in the repo — the WSD-015 "D4 token gate" (monorepo CLAUDE.md =
1.17× the larger single-stack, fallback trigger ~1.5×) was a **one-off manual check during the
merge**, not a repeatable gate. Today, nothing tells the maintainer when a change silently grows
what every consumer pays on every prompt, and nothing re-checks the 1.5× monorepo ratio again.

The goal is **visibility with a deterministic tripwire**, not minimization: WSD-011 already
decided token economy is handled by targeted point fixes, and B-26 deliberately accepted the
salience cost. This gate makes the cost of each change *visible in review* so growth is always a
deliberate act; it does not reverse the salience-over-bytes trade.

## Measured current state (2026-07-11; re-measured post-critique — H1 corrected the draft)

Counting rule everywhere: LF-normalized byte count; tokens ≈ chars ÷ 4 (approximation, stated as
such; see D1). Frontmatter = summed YAML blocks of skills+commands+agents (30 files single-stack,
**34 monorepo** — it carries the 13-skill union vs 9 per single stack; the draft's "~same" was
false, caught by critique H1).

| Component | dotnet | angular | monorepo | When it costs |
|---|---|---|---|---|
| `CLAUDE.md` (Claude Code, always) | 22,866 | 23,638 | 27,589 | every prompt |
| frontmatter, skills+commands+agents (Claude Code) | 11,739 | 10,313 | **13,854** | every prompt |
| **`static.claude` total** | **34,605 ≈ 8,651 tok** | **33,951 ≈ 8,488** | **41,443 ≈ 10,361** | every prompt |
| `AGENTS.md` (Copilot, always) | 20,836 | 21,656 | 24,923 | every prompt |
| `.github/copilot-instructions.md` (Copilot, always — critique H2) | 3,239 | 3,625 | 5,450 | every prompt |
| **`static.copilot` total** | **24,075 ≈ 6,019 tok** | **25,281 ≈ 6,320** | **30,373 ≈ 7,593** | every prompt |
| `FRAMEWORK-CONTEXT.md` (instructed-load) | 6,511 | 6,391 | 7,480 | every non-trivial task |
| `session-start` rendered (fixture) | 607 ≈ 151 tok | — | — | once per session |
| `route-prompt` rendered, worst intent (`fix`) | 4,423 ≈ 1,105 tok | — | — | per matched prompt |
| `route-prompt` security overlay alone | 1,893 ≈ 473 | — | — | per sensitive prompt |

Headline: **static per-prompt overhead on Claude Code is ≈ 8.5–10.4K tokens** before the user
types anything (monorepo highest), plus up to ~1.1K on a matched `fix` prompt. Copilot pays
≈ 6.0–7.6K. Monorepo CLAUDE.md ratio today: 27,589 / 23,638 = **1.17×** (re-confirms WSD-015).

Two scopes must not be conflated:
- **Template footprint** (what we ship) — ours to gate. This design.
- **Consumer footprint** (their bootstrapped CLAUDE.md, their FRAMEWORK-CONTEXT, later their
  wiki INDEX) — grows outside our control; we can only *measure and report honestly* on their
  box (D6), never fail them.

## Approaches weighed

**A — standalone `context-footprint` script twins + committed baseline, freshness-style gate
(CHOSEN).** New `scripts/context-footprint.ps1/.sh` (twin parity per invariant #3, like the
other composer/gate scripts) measures the manifest below per dist and writes/compares a
committed baseline `docs/context-footprint.json`. `-Check` (default) fails on any mismatch;
`-Update` rewrites the baseline. Wired into `release.ps1` and CI. Pros: mirrors the proven
dist-freshness pattern (a growth is impossible to ship silently — the baseline diff appears in
the same commit and quantifies the cost); the only FAIL conditions are deterministic
(measured ≠ committed; hook-twin render mismatch, D2), all *policy* judgments are visible
warns; reusable counting rule for B-27's index threshold. Cons: one more script pair + baseline
file to maintain.

**B — fold into `validate-dist` as check 6.** Pros: no new wiring. Cons: validate-dist checks
are boolean structural validity of one dist in isolation; the footprint gate is cross-dist
(monorepo ratio), needs a baseline file and an `-Update` mode (validate-dist has no write mode),
and needs to *execute* hooks against fixtures (validate-dist only parses). Forcing a
stateful, cross-dist, executing check into a stateless per-dist validator distorts both.
Rejected.

**C — measurement-only report at release (no gate).** Re-measure in `release.ps1`, print the
table, record in CHANGELOG. Pros: minimal. Cons: recreates the exact failure mode being fixed —
B-26 was a "re-measure when…" note that nobody executed across a year of releases; numbers
nobody diffs are numbers nobody sees. The workspace's whole track record (check-lockstep,
template-checks, freshness) says gates work and advisory notes rot. Rejected.

## Design

### D1 — Counting rule: LF-normalized bytes, ÷4 token approximation, no tokenizer

All counts are `bytes(UTF-8 content with CRLF→LF)`, tokens reported as `round(chars/4)` and
labeled `~tok (chars÷4 approximation)`. A real tokenizer (tiktoken/anthropic package) was
rejected: it adds a package dependency to a deliberately dependency-free gate suite (and a
*gate* may not degrade through a fallback chain), and exact token counts don't matter —
**regression detection needs a deterministic, monotone proxy**, and chars÷4 is one. The JSON
stores both `chars` and `tok` per line item; the gate compares `chars` (exact integers, no
float/culture formatting in the compare path). EOL normalization is mandatory (LEARNINGS
core.autocrlf trap; the repo's `.gitattributes` `* text=auto eol=lf` keeps committed files LF,
but normalization in the counter makes the rule checkout-independent). Counting in the `.ps1`
twin must be **UTF-8 byte counts from raw file bytes** (`[IO.File]::ReadAllBytes` after CRLF→LF
on the byte level or via a pinned UTF-8 decode), never .NET `string.Length` — UTF-16 code units
diverge from UTF-8 bytes on every emoji in the hook output (critique M1.3).

### D2 — The manifest: what is measured, per dist

Per dist (`dotnet`, `angular`, `monorepo`), grouped by *when the consumer pays*:

1. **`static.claude`** — always-loaded on Claude Code: `CLAUDE.md` + the summed YAML frontmatter
   of `.claude/skills/*/SKILL.md`, `.claude/commands/*.md`, `.claude/agents/*.md` (the harness
   injects name+description each prompt; counting the whole frontmatter block is a slight,
   stable over-approximation — stated in `_notes`). The extractor **hard-FAILs** on any manifest
   file whose first line is not `---` (never silently mis-captures a body horizontal rule —
   critique L4a).
2. **`static.copilot`** — always-loaded on Copilot: `AGENTS.md` **+
   `.github/copilot-instructions.md`** (repo-wide instructions are injected into every Copilot
   request — GA documented behavior; missing it was critique H2's silent-growth channel).
   `_notes` records the honest exclusions: `.github/skills` frontmatter and
   `.github/agents/*.agent.md` wrapper consumption are **unverified** on Copilot (fold into the
   B-16 canary work if it matters); `.github/instructions/*.instructions.md` joins this group
   when B-17 lands.
3. **`instructed`** — loaded per instruction, not per prompt: `FRAMEWORK-CONTEXT.md` (every
   non-trivial task), `docs/defaults.md` (pre-bootstrap conventions — the shipped template is
   permanently pre-bootstrap; critique L3), and post-B-27 the shipped wiki `INDEX.md` seed
   (referenced from the CLAUDE.md preamble per B-27 constraint 7; it moves to `session` only if
   B-27's optional session-start preload is adopted — critique L2).
4. **`session`** — `session-start` rendered against a **deterministic fixture**: temp dir,
   **no `.git`** (kills branch/commit lines, the nondeterministic part), template `CLAUDE.md`
   (BOOTSTRAP_PENDING present), planted `SECURITY_FINDINGS.md` with pinned-past due dates
   (always overdue → stable output forever; only the *count* of findings is printed, no dates).
5. **`prompt`** — `route-prompt` rendered for a **fixed prompt set** (one per intent ×7 +
   security-only + `fix`+security worst case), each its own line item; the max is the headline.
   Fixture prompts are literals inside the script — changing them is a visible diff. The
   security prompts must use **shared-vocabulary tokens** (e.g. `password`, `auth`) that match
   every dist's resolved `sensitive-grep`; per-dist overlay sizes are *expected* to differ
   (vocabularies diverge by stack — critique L1) and are simply separate per-dist line items.
6. **`ondemand` (info-only, never gated)** — summed bodies of skills/commands/agents. They cost
   only when triggered; reported so bloat there is visible, but body growth is usually
   deliberate feature work.

**Rendered measurements (4, 5) execute BOTH hook twins per fixture** — `bash <hook>.sh` and
`pwsh -NoProfile -File <hook>.ps1` — and **FAIL on any output mismatch** between them (critique
M5: the shipped `settings.json` wires the `.ps1` twins for Claude Code, so measuring only `.sh`
would leave the twin consumers actually run ungated; the hook suites prove decision/robustness
parity but never rendered-rails *content* parity — this check closes that gap as a bonus gate).
The agreed byte count is the stored line item. Dependency posture: both footprint twins
hard-require working `bash` **and** `pwsh` (FATAL exit 2 if missing, never skip — same posture
as validate-dist's bash requirement; GitHub ubuntu runners ship pwsh, the maintainer box has
both). Capture rules, load-bearing for determinism (critique M1/M3):

- Every fixture event **includes `"hook_event_name"`** so both hooks take the plain-stdout
  branch — otherwise output routes through the jq/python3/fallback chain and the bytes depend
  on what's installed on the box.
- Hook stdout is **redirected to a temp file inside the invoked shell** (`bash -c '… > out'`;
  `pwsh -File … *> out` equivalents), then counted via raw bytes after CRLF→LF — never captured
  through the PowerShell pipeline, whose `[Console]::OutputEncoding` decode (OEM code page on
  PS 5.1) and line-splitting `-join` mangle multi-byte UTF-8 (the ⚠/🔴 lines) and drop trailing
  newlines.
- `LC_ALL=C` pinned on bash invocations.

### D3 — Canonical baseline serialization (normative — critique M2/L4)

Byte-identical JSON from two twins across PS 5.1 / pwsh 7 / bash is achievable only by
**hand-rolled emission in both twins** — stock serializers disagree on whitespace and escaping
(PS 5.1 vs pwsh 7 `ConvertTo-Json` differ; the `.sh` twin has no serializer at all under the
no-dependency posture). Normative contract for `docs/context-footprint.json`:

- Fixed key order (schema order, not insertion/hash order); line items sorted by **ordinal**
  (culture-invariant, byte-wise) path — never `Get-ChildItem`/glob collation order.
- 2-space indent, LF EOLs, single trailing newline, **BOM-less UTF-8** on `-Update` (precedent:
  `BuildArchitectureHtml.Tests.ps1` asserts exactly this write discipline).
- Paths forward-slash, dist-relative. Numbers integers only (no floats, no culture formatting).
- `generated-by` names the script pair only — **no timestamp, hostname, or username**, or
  `-Update` stops being reproducible.
- Content: per dist → per group → line items `{path-or-fixture, chars, tok}`; a `derived` block
  (per-surface static totals, monorepo ratio ×100 as an integer permille/percent to avoid
  floats); a `ceilings` block (D4's warn thresholds — changing a threshold is a visible diff);
  a `_notes` array (the honest caveats from D2).

### D4 — Baseline + gate semantics: exact-match freshness, warns for policy

- **FAIL (exit 1)** iff measured ≠ baseline (any integer differs, any item added/removed), or
  any hook twin-render mismatch (D2). The fix is never "make the gate pass" — it is: review the
  growth, then rerun with `-Update` and commit the baseline diff *in the same commit as the
  change that caused it* (identical discipline to `dist/` freshness). Honest expectation
  (critique L5): maintainers will run `-Update` as reflexively as they run `build.ps1`; the
  gate's real, sufficient guarantee is that **the numbers always appear in the PR diff** —
  deliberation is invited, not enforced.
- **WARN (stdout; exit stays 0 when the baseline matches)** on advisory ceilings, all recorded
  in the JSON `ceilings` block:
  - `static.claude` total > **40,000 chars single-stack / 48,000 chars monorepo** (critique H1:
    one shared ceiling was incoherent — monorepo is structurally larger, 41,443 today, and a
    permanently-firing warn is advisory rot, the exact disease approach C was rejected for.
    Headroom at lock: ~16% for both classes).
  - monorepo `CLAUDE.md` / max(single-stack `CLAUDE.md`) > **1.5×** — absorbs the WSD-015 D4
    fallback trigger and makes it re-checked at every gate run instead of never. Crossing it
    reopens WSD-015's split-the-root-file fallback; a design decision, so warn not fail.
- Why warns aren't fails: the freshness FAIL already guarantees no silent change; a hard fail on
  a policy number invites threshold-fiddling under deadline, which destroys the number's
  meaning. The deterministic part is the gate; the judgment part stays judgment.

### D5 — Wiring

- **CI (`ci.yml`):** the windows leg runs the `.ps1` twin `-Check`, the linux leg the `.sh` twin
  `-Check`, both against the same committed baseline — which *is* the cross-OS twin-parity proof
  (mirrors the composer's twin proof; a counting divergence fails one leg).
- **`release.ps1` runs `-Update`, not `-Check`** (critique M4): release stamps
  `version:`/`applied:` into `src/core/CLAUDE.md` *before* the gates run, so a length-changing
  version transition (0.9.0→0.10.0 happened; 0.x→1.0.0 will) would fail a `-Check` mid-release
  with a half-stamped tree and no way to have pre-updated the baseline. Instead release
  re-measures and commits the baseline in the release commit — by that point CI's `-Check` has
  already gated every content PR, so the release-time delta is the stamp alone, and it still
  lands as a visible diff. (Alternative — normalizing the version header out of the count — was
  rejected: it opens a measurement hole in genuinely-shipped bytes to dodge a wiring problem.)
- **Not** inside `validate-dist` (approach B rejection) and **not** shipped to consumers —
  `scripts/` and `docs/` are authoring-repo-only (invariant #6; installers copy `dist/` only).

### D6 — Consumer-side surfacing (ships later, with B-16 framework-doctor)

The doctor gains a "context cost" section: measure the *installed repo's actual*
CLAUDE.md / AGENTS.md+copilot-instructions / frontmatter / INDEX with the same counting rule
(logic ported into the doctor's twins — the maintainer script itself never ships), print
per-surface totals with the one-line honest framing: "this is what the framework adds to every
prompt on your surface; large-and-stable is cheaper than it looks under prompt caching, but it
is never free — trim your CLAUDE.md Conventions before trimming the rails." Report-only, never
a failure — the consumer's own content dominates and it is theirs. Sizing guidance (what's
normal, when to worry) goes in `docs/enforcement-surfaces.md` alongside the existing per-surface
honesty tables.

### D7 — B-27 wiki integration (the forcing function)

B-27's `INDEX.md` will be the framework's first *unbounded, consumer-grown* always-loaded file,
and its design (constraint 4) promises an index-size threshold. Rule: **B-27's `wiki-check`
reuses B-32's counting rule** (chars÷4, LF-normalized — restated in wiki-check's twins, since
maintainer scripts don't ship) so consumer-facing threshold warnings and maintainer gate numbers
can never disagree about what a "token" is. On the maintainer side, the shipped wiki `INDEX.md`
seed joins the `instructed` group automatically once present (see D2.3 for the classification).
Sequencing: B-32 lands before or with B-27 implementation (v0.27.0).

### D8 — Prompt-cache economics note (recorded so the gate isn't misused)

A large **stable** CLAUDE.md is cheaper than raw size suggests for active sessions (cached
prefix reads); the expensive events are growth, churn, and cache-cold surfaces. Therefore the
gate targets **growth and churn visibility**, not size minimization — do not use B-32 as a
mandate to compress the rails (B-26/WSD-011 already accepted the salience cost deliberately;
reversing that requires new evidence of harm, e.g. rail-adherence regressions, not just a big
number). This paragraph exists so a future session doesn't "optimize" CLAUDE.md against the
warn ceiling and quietly degrade enforcement salience.

## Non-goals (explicit, to survive handover)

- No real tokenizer, no per-model token tables (D1).
- No dynamic budgets, routing, or output-token measurement (WSD-011 stands).
- No consumer-side FAIL, ever (D6 is report-only).
- No gating of `ondemand` bodies (info-only).
- No attempt to measure what the *harness* adds (system prompt, tool schemas) — not ours.

## Verification (for the executing agent — evidence-based)

- **Determinism:** run each twin twice on a clean tree → byte-identical JSON both times; run
  `.ps1` and `.sh` → byte-identical JSON; CI cross-OS legs prove it again against the committed
  baseline. Verify the JSON is BOM-less LF on a Windows `-Update` (the M2 trap).
- **Red tests (gate script class, per Definition of done):** (a) append 100 chars to
  `src/core/CLAUDE.md`, rebuild → `-Check` exits 1 naming the changed line item; (b) `-Update`,
  re-run → exit 0 and the JSON diff shows exactly the delta; (c) plant a twin-render divergence
  (edit one dist hook twin's rails text in a scratch dist copy) → FAIL names the hook + fixture;
  (d) plant a `static.claude` total over its ceiling → WARN line, exit 0; (e) force the
  monorepo ratio > 1.5× → ratio WARN. Revert all.
- **Fixture stability:** session-start fixture output contains no date/branch/hash-derived
  bytes; both hook twins' fixture events carry `hook_event_name` (assert the plain-stdout
  branch was taken — e.g. output does not start with `{`).
- **Frontmatter guard:** plant a manifest file whose first line isn't `---` → hard FAIL.
- **release.ps1:** a length-changing version stamp on a scratch copy passes (release runs
  `-Update`); CI `-Check` red-tested via (a).

## Alternatives rejected log

- validate-dist check 6 (approach B) — stateless/stateful mismatch, cross-dist scope.
- Report-only (approach C) — recreates the B-26 rot this design exists to fix.
- Real tokenizer — dependency for no decision-relevant precision gain.
- Hard-fail ceilings — invites threshold-fiddling; freshness FAIL already prevents silence.
- Shipping the footprint script to consumers — invariant #6; doctor gets ported logic instead.
- Normalizing version headers out of the count — measurement hole to dodge a wiring problem
  (M4 resolved via release-time `-Update` instead).
- Measuring only the `.sh` hook twins — leaves the `.ps1` twins consumers actually run ungated
  (M5 resolved via render-both + mismatch FAIL).

## Findings log (adversarial critique 2026-07-11 — verdict LOCK WITH AMENDMENTS, all folded)

| # | Sev | Finding | Disposition |
|---|---|---|---|
| H1 | HIGH | Draft's "frontmatter ~same" was false — monorepo carries the 13-skill union (13,854 B) and `static.claude` = 41,443 already exceeded the draft's single 40K ceiling → permanent-warn advisory rot | **Folded.** Re-measured independently (numbers above); per-class ceilings 40K/48K in D4; current-state table corrected |
| H2 | HIGH | `static.copilot` missed shipped `.github/copilot-instructions.md` (3,239/3,625/5,450 B, injected every Copilot request) — a silent-growth channel inside the design's own goal | **Folded.** Added to D2.2 + `_notes` exclusions extended (.agent.md wrappers, B-17 forward note); verified present in all three dists |
| M1 | MED | `.ps1` twin capturing hook stdout via the PS pipeline is byte-lossy (OEM-codepage decode of ⚠/🔴, line-split `-join` drops trailing NL, UTF-16 `.Length` ≠ UTF-8 bytes) | **Folded.** D2 capture rules: redirect-to-file inside the invoked shell, raw-byte counts, `LC_ALL=C`; D1 bans `string.Length` |
| M2 | MED | Baseline byte-determinism asserted but serializer unspecified; no stock serializer delivers it across PS 5.1/pwsh/bash | **Folded.** New normative D3 (hand-rolled emitter contract: key order, ordinal sort, LF, BOM-less, integer-only) |
| M3 | MED | Fixture stdin shape unpinned → jq/python3/fallback chain makes output bytes depend on installed tools | **Folded.** D2: every fixture event carries `hook_event_name`; stated load-bearing; verification asserts the branch |
| M4 | MED | release.ps1 stamps version before gates → length-changing version transitions fail `-Check` mid-release with a half-stamped tree | **Folded.** D5: release runs `-Update` (CI `-Check` gates PRs; release delta = stamp only); header-normalization alternative rejected |
| M5 | MED | "Measure only `.sh`, parity gated elsewhere" overclaims — hook suites never compare rendered rails content, and shipped settings.json wires the `.ps1` twins consumers actually run | **Folded.** D2: render both twins, FAIL on mismatch (bonus rails-content parity gate); pwsh added to hard requirements |
| L1 | LOW | Per-dist `sensitive-grep` vocabularies differ; one security fixture prompt could measure 0 on a dist | **Folded.** D2.5: shared-vocabulary prompts; per-dist overlay items expected to differ |
| L2 | LOW | Wiki INDEX classed `static.claude` contradicts B-27 constraint 7 (preamble-referenced = instructed; session only if optional preload adopted) | **Folded.** D2.3 reclassifies to `instructed` with the preload caveat |
| L3 | LOW | `docs/defaults.md` is instructed-load pre-bootstrap and the shipped template is permanently pre-bootstrap | **Folded.** Added to `instructed` |
| L4 | LOW | Extractor should hard-FAIL on missing frontmatter; `generated-by` must carry no timestamp/hostname; enumeration order must be ordinal | **Folded.** D2.1 + D3 |
| L5 | LOW | "Review the growth, then -Update" oversells; -Update will be reflexive like build.ps1 | **Folded.** D4 states the honest guarantee: numbers in the PR diff, deliberation invited not enforced |

Reviewer verifications retained as design facts: session-start fixture is genuinely
date-independent as specified; `docs/context-footprint.json` cannot ship (invariant #6);
"no version slot" is correct under invariant #7; the 1.5× warn faithfully absorbs WSD-015's
fallback trigger; validate-dist's bash-on-Windows posture is precedent for D2's requirements.
Reviewer's H1 measurements corrected by maintainer re-measurement (angular frontmatter 10,313
not ~10,583; monorepo 13,854 not ~13,888; conclusions unchanged).
