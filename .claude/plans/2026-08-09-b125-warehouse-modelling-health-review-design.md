# B-125 design — evidence-ranked warehouse modelling health review (LOCKED 2026-08-09, rev 3)

> **Status: DESIGN LOCKED. Not implemented.** Deviations need a new entry in
> `meta/workspace-decisions.md`. Trigger: `meta/BACKLOG.md` B-124–B-129, filed 2026-08-08
> (capability "warehouse technical leadership"); B-125 is the foundational item the remaining
> three (B-126–B-128) consume — **B-124 closed 2026-08-09, premise rejected; see §1.** **Review
> disposition (§6): rev 1 was reviewed adversarially by codex (`gpt-5.6-sol`), not Claude Opus —
> a budget-driven, explicitly recorded substitution (WSD-036). 12 findings returned (2 blocking,
> 8 significant, 2 minor); all 12 verified and accepted, folded into rev 2. A Claude Opus pass is
> still owed before implementation. Rev 3 (this revision) only corrects the now-stale B-124
> consumer reference and cites B-124's closure as concrete evidence for §2's phased approach —
> no other content changed, and rev 3 has not itself been re-reviewed.**

---

## 1. Problem

The warehouse map's report step (`SKILL.md` step 9, subsection **9.6 "Findings"**,
`src/stacks/dotnet/files/.claude/skills/map-warehouse/SKILL.md:189-190`) is a five-item catch-all:
unstated grain, loads without rerun protection, inconsistent SCD handling, disabled declared keys,
conflicting join paths. (Rev 1 of this design misnamed this "step 6" throughout, confusing it with
the skill's actual top-level step 6, "Control and idempotency mechanics",
`SKILL.md:142-147` — a different step entirely. Fixed in this revision; see §6 finding 11.) It has
no structure — no confidence, no severity, no consequence, no remediation — and does not check the
eight failure classes B-125 is filed against: **fact, dimension, bridge, role-playing,
conformance, SCD, special-member, and additivity** (`meta/BACKLOG.md:3221-3224`).

**Consumers (corrected in rev 3).** This is the shared modelling-analysis layer consumed by
**B-126, B-127, and B-128** (`meta/BACKLOG.md`, B-125's current "Framework fit"). Rev 1/2 also
named **B-124** as a consumer; B-124 **closed 2026-08-09 with its premise rejected** — two
independent Claude Opus reviews plus a pre-registered behavioral baseline found the *unchanged*
`add-warehouse-load` skill already chose the correct fact (EXTEND vs. NEW) 2/2 on both ambiguous
test pairs, so the registered stopping rule blocked the proposed change as disproportionate to
zero observed failures (`meta/BACKLOG.md` Done section, B-124). It shipped no decision artifact
and is not a live consumer of this design's findings; its retained regression scenarios are
evidence only. Three consumers, not four.

**Honesty about proportionality (revised — see §6 finding 7; reinforced by B-124's actual outcome).**
Rev 1 argued proportionality from hypothetical downstream harm (then: B-124/126/127/128 inheriting
bad findings). CLAUDE.md's own rule 6 requires *concrete, already-observed* harm, not a hypothetical
one, and no field incident specific to these eight defect classes exists — B-96's field report was
about a missing relationship edge, not a modelling-health defect. This design does not manufacture
an incident that isn't there. Instead it takes the smaller, immediately-justified step first (§2)
and treats full eight-class coverage as a set of separately-evidenced additions, each gated on its
own fixture proof before it ships as a real finding rather than a candidate signal. **B-124 is now
concrete evidence this caution is warranted, not excessive**: a same-batch, same-day, structurally
similar item (also a warehouse pre-DDL decision procedure) was killed by exactly the failure mode
rev 2 exists to avoid — a plausible-sounding detection claim added without first confirming the
*current* skill actually gets the case wrong. Phase 2's per-class fixture requirement (§5 criterion
1: a pre-registered red baseline against the *unchanged* skill, not merely a constructed pass) is
non-negotiable for the same reason B-124's matrix was rejected: a candidate signal is not a shippable
finding until a baseline shows the default behavior actually misses it.

## 2. Two approaches, weighed — plus the smaller option codex's review identified

**(a) Fold every new detector into the Findings subsection, always on, all eight classes at
launch.** Rejected outright in rev 1 already, for the same reason repeated below.

**(b) Push all eight classes into a new, separate on-demand "review mode".** Would silently
regress the five findings the skill already produces today (unstated grain, missing rerun
protection, etc.) behind an opt-in.

**(c) — accepted, replaces rev 1's "(a) vs (b)" framing per §6 finding 7.** Two-phase, ordered by
what the evidence already gathered can actually support:

- **Phase 1 (this design's implementation target): structure the five findings the skill already
  emits.** Add confidence/severity/consequence/remediation columns to the existing five checks.
  This is proportionate on its own terms — it changes no detection logic, only formats output that
  already exists, and is justified without appeal to future consumers.
- **Phase 2 (scoped additions, each separately gated): the eight backlog-named classes.** Each
  class is added only where steps 1–4's evidence can support at least a `Likely`-confidence
  candidate (§3.2); where it cannot (see §6 findings 2, 9, 10), the class is either narrowed to
  what the evidence supports, moved to the on-demand deepening (§3.3), or filed as a distinct
  follow-on requiring its own evidence source. Acceptance criterion 1 (§5) requires a fixture proof
  *per class* before that class ships — Phase 2 is not "done" as a block.

This is not a retreat from B-125's scope — all eight classes are designed below — but it stops
promising blanket "cheap synthesis" for classes that, per §6 finding 2, actually need evidence the
default pass does not gather.

## 3. Design

### 3.1 Finding-confidence vocabulary (new — fixes §6 finding 4)

Rev 1 reused the edge-provenance vocabulary (`Declared`/`In use`/`Load-derived`/`UNRESOLVED`/
`CONFLICTING`, `SKILL.md:94-100`) directly as finding confidence. That vocabulary describes how a
*relationship* was learned; it does not describe confidence in a *defect claim* about that
relationship, and reusing it risks laundering "the FK is Declared" into "the fact-type claim about
it is Declared" — two different assertions. A finding gets its own, separate confidence tier:

| Finding confidence | What it takes |
|---|---|
| **Confirmed** | The defect is directly provable from evidence already in hand with no interpretation gap — e.g. a fact's grain literally cannot be stated from its own keys (an objective test on the DDL already read). |
| **Likely** | Strong structural signal from evidence already open, but requires an interpretation step that could be wrong without repository-specific context — e.g. a fact classified transaction-type whose measures include running balances (semi-additive signal contradicting the type). |
| **Possible** | Weak or name-based signal only; on par with the map's own `UNRESOLVED` edge state. Emitted, never silently dropped, explicitly flagged as needing developer confirmation. |

A finding's **evidence** field still cites the concrete source (table/column/view/DDL line); its
**finding confidence** is separate from any edge's own `Declared`/`In use`/etc. label, which may
still be cited as part of the evidence text.

### 3.2 Severity, decoupled from confidence (fixes §6 finding 8)

Rev 1's severity definitions asserted certainty ("numbers *will be* silently wrong") regardless of
confidence — which contradicts the map's own abstention discipline. Severity now states **impact
if the finding is correct**, independent of how confident the finding is:

| Severity | Impact if confirmed |
|---|---|
| `blocking` | Silently wrong or double-counted numbers. |
| `significant` | Misleads a report author but does not by itself corrupt totals. |
| `advisory` | Deviates from convention; no demonstrated numeric consequence. |

A finding is reported as **severity conditional on confidence** — e.g. "`blocking` impact if
confirmed; finding confidence `Likely`" — so a low-confidence, high-severity finding still reads as
what it is: worth checking, not asserted as already-broken.

### 3.3 Defect vs. convention preference — evidence source specified (fixes §6 finding 5)

Rev 1 required checking for "an explicit, coherent local convention" without naming where that
evidence comes from. Source: the skill's own step 0 instruction, already in force —
*"Match CLAUDE.md > Conventions > Data Access"* (`SKILL.md:19`) — plus `docs/defaults.md` where
B-96's DW evidence block lives. Both are already-open context for any `map-warehouse` run; no new
evidence acquisition is added. If neither source states a convention covering the pattern, the
finding is emitted; if one does, and it is explicit and coherent (not merely "this is how it's
always been"), no defect finding is emitted — the convention is noted instead.

### 3.4 The eight failure classes (fixes §6 finding 1 — full backlog scope, replaces rev 1's ad hoc nine)

| Class (per `meta/BACKLOG.md:3221-3224`) | Phase 1 (structure only) or Phase 2 (new detection)? | What steps 1–4 evidence actually supports | Confidence ceiling from default evidence |
|---|---|---|---|
| **Fact** — mixed/unstated grain, wrong fact type | Phase 1 covers unstated grain (already emitted); Phase 2 adds mixed grain and fact-type-plausibility | Unstated grain: `Confirmed` (objective, from step 2). Mixed grain: only detectable when a fact's own column set implies two different event shapes or two measure grains coexisting on one row (e.g. both a transaction amount and a running balance column) — a real but narrower signal than rev 1's collapse into "unstated grain" (§6 finding 10). Wrong fact type: only a *plausibility* signal (semi-additive measures on a fact typed "transaction") — never a bare assertion that the type is wrong | Mixed grain: `Likely` where the column-shape signal is present, else not emitted (not `Possible` — no signal, no finding). Fact type: `Possible` only |
| **Dimension** — non-conformance, inappropriate snowflaking | Phase 2 | Non-conformance: DDL can show two dimensions with the same name/business key disagreeing in column set or grain — a `Likely` signal; true semantic non-conformance (values disagree) is not visible from structure alone. Snowflaking: DDL shows normalization depth; "inappropriate" requires knowing consumer/cost tradeoffs the default pass does not gather | Non-conformance: `Likely`. Snowflaking: `Possible` only, phrased as a question ("N-level snowflake on `DimX` — confirm this is intentional") not an assertion |
| **Bridge** — missing bridge/allocation for a stated many-to-many | Phase 2, on-demand only (§3.5) | Requires the many-to-many business process to already be evidenced — either an existing bridge-shaped table elsewhere in the same schema pointing at one side, or an explicit developer statement. Absent that trigger, the detector does not fire (fixes §6 finding 9 — no silent pre-supplied conclusion) | `Likely` when triggered by real evidence; never fires speculatively |
| **Role-playing** — a role-playing dimension reached but not distinguished | Phase 2 | Step 3's `role` column already records this per edge (`SKILL.md:75-76`) — a fact reaching the same dimension via 2+ differently-named keys with no distinct `role` recorded is a `Confirmed` structural gap (the map itself is incomplete, not a modelling judgment) | `Confirmed` for the "role not recorded" case; `Possible` for "is this really role-playing" ambiguity |
| **Conformance** — see Dimension row above (same evidence path) | Phase 2 | (see Dimension) | (see Dimension) |
| **SCD** — inconsistent or unstated SCD strategy per dimension | Phase 1 covers "inconsistent SCD handling" (already emitted, structured); Phase 2 adds unstated/mixed-per-column SCD without a stated rule | Step 7 already gathers Type 1/Type 2/mixed per dimension (`SKILL.md:149-158`); a dimension with `EffectiveFrom`/`IsCurrent` columns present but no consistent write pattern across its load is a `Likely` signal from evidence already open | `Likely` |
| **Special member** — ambiguous or missing unknown/N/A dimension rows | Phase 2 | DDL/load evidence can show whether a dimension has a reserved surrogate key row for unknown/N/A (e.g. key `-1` or `0` with a sentinel description) — presence/absence is `Confirmed` from DDL/seed data already read; whether it's *correctly used* by facts (an unmatched key falling back to it) is `Possible` without tracing fact load logic | Existence check: `Confirmed`. Usage-correctness: `Possible` only |
| **Additivity** — incorrect measure additivity classification | Phase 1 covers structuring what step 4 already classifies; Phase 2 adds a plausibility check | Step 4 classifies additivity "where the load reveals it" (`SKILL.md:132-135`) — loads are examined in step 5, not step 4, so a same-pass additivity finding is only available when step 5 evidence is already in hand from the same run (fixes §6 finding 2's additivity point: this is not asserted from step 4 alone) | `Likely` only when step 5 evidence for that fact was actually read in the same pass; otherwise not emitted |

### 3.5 On-demand deepening (unchanged in shape from rev 1, renamed to avoid step-number collision)

Named **"Modelling health deepening"** — not a numbered step in the skill's main sequence, invoked
by name and scoped to a named fact or view, exactly like the existing scoped-trace pattern in step
3's cost discipline (`SKILL.md:106-112`):

1. **Bridge/allocation completeness for a named fact**, once the many-to-many trigger in §3.4 is
   satisfied.
2. **Multi-hop fan/chasm path for a named report or consumption view** — opens the named view and
   anything it depends on; explicitly out of the default pass because it opens files beyond step
   1's inventory.

### 3.6 Remediation — scope corrected (fixes §6 finding 6)

Remediation text is proportionate to what this design actually evidences: for `blocking`/
`significant` findings that would require a schema change, remediation reads **"requires impact
analysis before changing — see B-126"** rather than asserting a migration cost this design's
default pass never gathers. B-125 identifies and ranks; it does not compute change-safety, which
remains B-126's territory (unchanged from rev 1's out-of-scope statement, now made consistent with
the remediation text that references it).

### 3.7 Report shape

Findings subsection 9.6 (`SKILL.md:189-190`) gains the structured table (finding | entity |
evidence | finding confidence | severity-if-confirmed | consequence | remediation). Where
Modelling health deepening (§3.5) was invoked, its results append to the same subsection with a
note on what was and was not checked — mirroring 9.5's existing coverage statement.

## 4. Files touched (at implementation — not this session)

- `src/stacks/dotnet/files/{.claude,.github}/skills/map-warehouse/SKILL.md` — subsection 9.6
  rewrite (Phase 1 + Phase 2 classes from §3.4), new "Modelling health deepening" named procedure
  (§3.5), §3.3's convention-check pointer.
- Monorepo sibling review per meta-invariant #1 / WSD-015 (confirm no monorepo-only override
  exists before assuming a bare rebuild suffices — unresolved from rev 1, still open).
- Rebuild `dist/{dotnet,monorepo}`; `dist/angular` unchanged except version-stamp changelog entry.
- Root `CHANGELOG.md` + all four `src/stacks/*/files/CHANGELOG.md` heads; release via
  `.claude/scripts/release.ps1` (meta-invariant #7).
- `meta/context-footprint.json` — re-check ceilings (B-96 recorded dotnet headroom as thin,
  38,571/40,000, at its own design time; this table is larger than rev 1's).

## 5. Acceptance criteria (fixes §6 findings 1, 12 — full scope, all fields tested)

1. Planted-model fixtures exist for **each of the eight backlog-named classes** (not rev 1's nine
   invented ones), each with a pre-registered red baseline and a constructible success case,
   **at the confidence tier §3.4 claims for it** — a class claimed only to `Possible` must be
   proven to reach `Possible`, not silently asserted as `Confirmed`. **The red baseline must be run
   against the *unchanged* current skill, not merely constructed as a hypothetical** — this is
   B-124's own registered stopping rule (`meta/BACKLOG.md` Done section: "the unchanged skill
   chose the intended...fact in 2/2 runs each" killed a plausible-sounding change with zero
   observed failures). A class whose baseline shows the current skill already handles it does not
   ship as a new finding.
2. A clean fixture and a fixture with an explicit, coherent local convention (per §3.3's named
   evidence sources) produce **no** false defect claims.
3. Findings cite the repository evidence that produced them, not generic advice.
4. **All five output fields are separately verified on fixtures**: evidence, finding confidence,
   severity-if-confirmed, consequence, and remediation — not just evidence and severity as rev 1's
   criteria tested (fixes §6 finding 12).
5. Behavioural evals (reuse the B-41 harness — do not build a second one) show the model *uses* the
   findings to change a downstream design or review decision, not merely reproduces the table.
6. The bridge detector (§3.4 Bridge row) never fires without its stated trigger evidence present in
   the fixture — a fixture with no many-to-many signal must produce no bridge finding at all, not
   an `UNRESOLVED` one (fixes §6 finding 9).
7. `no-meta-leak`, `validate-dist` ×3, hook suites ×3, meta suite all green; context-footprint
   ceilings not regressed (§4).

## 6. Review disposition

**Rev 1 was reviewed by codex (`gpt-5.6-sol`), not Claude Opus.** Under a budget constraint (9% of
the weekly Claude allowance remaining, 2026-08-09), the maintainer directed this substitution
explicitly — recorded, not silent. See `meta/workspace-decisions.md` **WSD-036**. This does **not**
satisfy B-125's filed Opus-specific gate on its own; a Claude Opus pass is still owed before
implementation, independent of what codex found or how thoroughly rev 2 addresses it.

**12 findings returned against rev 1, all verified against the actual `SKILL.md`/`BACKLOG.md`
content and accepted — none rejected:**

1. **Blocking — scope silently narrowed** to 9 invented classes instead of the 8 backlog-named
   ones (fact, dimension, bridge, role-playing, conformance, SCD, special-member, additivity), and
   missed special members entirely despite naming them in the problem statement. → §3.4 rebuilt
   around the 8 named classes.
2. **Blocking — most "cheap" detectors need evidence beyond steps 1–4.** Wrong fact type,
   additivity, fan/chasm safety, snowflaking-appropriateness, natural-keys-on-facts, and
   non-conformance were promoted to findings without the evidence to support a defect verdict. →
   §3.4 rebuilt with an explicit confidence ceiling per class instead of a blanket "cheap" claim.
3. **Significant — bridge detector's cost rationale self-contradicted** (§2's table said new
   evidence needed; §3.2 said the same DDL sweep, no new files). → §3.5's bridge check now depends
   on a specified trigger (§3.4 Bridge row), not a cost claim.
4. **Significant — edge-provenance vocabulary reused as defect confidence**, conflating "how the
   relationship was learned" with "how sure we are the relationship is a defect." → §3.1 adds a
   separate finding-confidence tier (Confirmed/Likely/Possible).
5. **Significant — convention-override evidence source unspecified.** → §3.3 names
   `CLAUDE.md > Conventions > Data Access` and `docs/defaults.md`, both already-open per the
   skill's own step 0.
6. **Significant — remediation required migration-cost analysis the default pass doesn't gather,
   contradicting the B-126 out-of-scope statement.** → §3.6 remediation now points at B-126 rather
   than asserting cost.
7. **Significant — proportionality rested on hypothetical downstream harm, not concrete observed
   harm**, and didn't consider the smaller fix. → §1/§2 rewritten: Phase 1 (structure the 5
   existing findings) is the immediately-justified increment; Phase 2 (8 new classes) is
   evidence-gated per class rather than asserted as a block.
8. **Significant — severity asserted certainty regardless of confidence.** → §3.2 decouples
   severity (impact-if-confirmed) from finding confidence.
9. **Significant — bridge/many-to-many trigger unspecified**, usable only if the user pre-supplies
   the conclusion. → §3.4 Bridge row names the trigger; §5 criterion 6 tests it doesn't fire
   without one.
10. **Significant — "mixed grain" collapsed into the existing "unstated grain" check**, leaving
    mixed grain undetected. → §3.4 Fact row separates the two explicitly.
11. **Minor — "step 6" vs. subsection 9.6 conflated with the skill's real, different step 6**
    ("Control and idempotency mechanics"). → Fixed throughout; on-demand deepening renamed to avoid
    any numbered-step collision (§3.5).
12. **Minor — acceptance criteria didn't test confidence/consequence/remediation, only
    evidence/severity.** → §5 criterion 4 now tests all five fields.

**Verdict on rev 1: ACCEPT WITH CHANGES.** Rev 2 above is the changed version; it has not been
re-reviewed by codex or Opus. That re-review is part of the outstanding Opus-pass precondition
in §6's opening paragraph, not a separate open item.

## 7. Out of scope

No implementation this session — this is a design-lock only. No `src/`/`dist/` edits. No angular
content (this skill is dotnet/monorepo-scoped per B-40/B-96 precedent, to be confirmed at
implementation). No change to `add-warehouse-load` (B-124's territory). No schema-evolution
preflight (B-126), scoped lineage trace (B-127), or physical-design review (B-128) — this design
produces only the shared modelling-analysis layer those items are filed to consume. No Claude Opus
review in this session (§6) — implementation must not begin until one occurs, and rev 2's changes
specifically have not yet been adversarially reviewed at all (codex or Opus).
