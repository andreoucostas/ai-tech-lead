# B-125 design — evidence-ranked warehouse modelling health review (LOCKED 2026-08-09, rev 10)

> **Status: IMPLEMENTED; CORRECTIONS UNDER CLAUDE OPUS RE-REVIEW.** Deviations need a new entry in
> `meta/workspace-decisions.md`. Trigger: `meta/BACKLOG.md` B-124–B-129, filed 2026-08-08
> (capability "warehouse technical leadership"); B-125 is the foundational item the remaining
> three (B-126–B-128) consume — **B-124 closed 2026-08-09, premise rejected; see §1.** **Review
> disposition (§6): rev 1 was reviewed adversarially by codex (`gpt-5.6-sol`), not Claude Opus —
> a budget-driven, explicitly recorded substitution (WSD-036). 12 findings returned (2 blocking,
> 8 significant, 2 minor); all 12 verified and accepted, folded into rev 2. A Claude Opus pass is
> was still owed before implementation. Rev 3 corrected the stale B-124 reference. Rev 4 incorporates
> the independent Claude Opus design review recorded in §6 (`ACCEPT WITH CHANGES`): one blocking, six
> significant, and four minor findings accepted after verification; one significant finding was
> rejected with direct gate evidence. Rev 5 additionally incorporates Opus's independent review of
> the Phase-2 baseline instrument: three blocking, five significant, and five minor corrections.**

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

**Proportionality (revised after Opus review).** The concrete observed harm is an internal
contradiction in the shipped artifact: relationship edges must carry evidence and confidence and
must abstain when unresolved (`SKILL.md:91-104`), and Coverage must name blind spots
(`SKILL.md:185-188`), while Findings emits five bare defect claims with none of that structure
(`SKILL.md:189-190`). Phase 1 is the smallest fix: structure only those already-emitted findings;
it adds no detector. No field incident specific to the additional defect classes is claimed.
Phase 2 therefore remains evidence-gated per class (§2)
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
- **Phase 2 (scoped additions, each separately gated): the backlog-named classes.** Each
  class is added only where steps 1–4's evidence can support at least a `Likely`-confidence
  candidate (§3.2); where it cannot (see §6 findings 2, 9, 10), the class is either narrowed to
  what the evidence supports, moved to the on-demand deepening (§3.5), or filed as a distinct
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
| **Fact** — mixed/unstated grain, wrong fact type, natural keys on facts | Phase 1 covers unstated grain; Phase 2 adds mixed grain and natural-key-on-fact checks. Wrong-fact-type detection remains deferred | Mixed grain requires incompatible row identities, not measures with different additivity on one atomic grain. Natural-key misuse requires an evidenced fact-to-dimension join plus recorded key types; a copied identifier/name candidate stays unresolved | Unstated/natural-key misuse: `Confirmed` with direct proof; mixed grain: `Likely` or `Confirmed` according to proof |
| **Dimension / conformance** — non-conformance, inappropriate snowflaking | Phase 2 adds structural non-conformance only. Snowflaking-appropriateness is deferred because default evidence supports only a `Possible` question | DDL plus an explicit repository rule can directly prove that the same governed entity is represented at incompatible grains/keys; value-level disagreement remains invisible from structure alone | Structural non-conformance: `Confirmed` with both sources, otherwise not emitted; snowflaking: not emitted |
| **Bridge** — missing bridge/allocation for a stated many-to-many | Phase 2, on-demand only (§3.5) | Requires an explicit cardinality rule plus a scalar fact column that can represent only one related member and no existing bridge/allocation owner | `Confirmed` when all evidence exists; silent without the trigger or when a correct bridge exists |
| **Role-playing** — a role-playing dimension reached but not distinguished | Phase 2 only if the existing edge list and dimensional semantics fail to distinguish the roles; any explicit structured location counts | Step 3's `role` column already records this per edge (`SKILL.md:75-76`); a fact reaching the same dimension via 2+ differently-named keys with no distinct role is a `Confirmed` map-coverage gap, not yet a model defect | `Confirmed` coverage gap |
| **SCD** — inconsistent or unstated SCD strategy per dimension | Phase 1 structures the existing inconsistency finding; Phase 2 adds a signal only when the complete already-open load statement makes the write pattern plain | Step 7 gathers Type 1/Type 2/mixed (`SKILL.md:149-158`). A complete MERGE with only `WHEN NOT MATCHED` directly proves it cannot create a changed version; no CTE/temp/helper tracing is allowed | `Confirmed` for that complete structural proof; otherwise unresolved, not a finding |
| **Special member** — ambiguous or missing unknown/N/A dimension rows | Phase 2 checks evidenced collisions only; absence remains deferred | Seed/rule evidence proves distinct governed states expose the same consumer-facing label; two reserved keys alone are insufficient | Label collision: `Confirmed`; missing/usage claims: not emitted |
| **Additivity** — incorrect measure additivity classification or use | Phase 1 structures the classification; Phase 2 adds evidence-ranked use review | A load can support classification; a consumer must also be read before asserting unsafe aggregation is performed | `Likely` for classification risk; `Confirmed` when an inspected consumer directly performs the unsafe aggregation |

### 3.5 On-demand deepening (unchanged in shape from rev 1, renamed to avoid step-number collision)

Named **"Modelling health deepening"** — not a numbered step in the skill's main sequence, invoked
by name and scoped to a named fact or view, exactly like the existing scoped-trace pattern in step
3's cost discipline (`SKILL.md:106-112`):

1. **Bridge/allocation completeness for a named fact**, once the many-to-many trigger in §3.4 is
   satisfied.
2. **Multi-hop fan/chasm path for a named report or consumption view** — opens the named view and
   anything it depends on; explicitly out of the default pass because it opens files beyond step
   1's inventory. A view that directly joins two facts before independently aggregating them is a
   `Confirmed` structural chasm shape; numeric impact remains conditional on actual cardinality.

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

### 3.8 Phase-2 evidence and stopping rules

Run pre-registered unchanged-skill baselines before adding any Phase-2 instruction. Decisions are
**per detector**, never a count over one correlated map. A detector is already handled only when it:

1. passes in every one of at least three independent defect-fixture runs within the
   evidence-dependent confidence band in §3.4;
2. remains silent in every clean-fixture and explicit-coherent-convention-fixture run; and
3. for bridge, remains silent on a many-to-many-shaped fixture with no trigger evidence.

Report an aggregate count descriptively, but never use it to suppress an individually observed
failure. Each failing detector proceeds only with its own observed harm and proportionality case;
the bundle is abandoned. A deferred `Possible`-only detector needs a future specificity criterion
with clean and intentionally unusual counterfixtures that emit zero findings before re-entering
scope.

Use two domain-plausible, defect-neutral fixtures of four to five defects rather than one crowded
fixture. Assert that no fixture path, comment, convention, map, prompt, or artifact name states the
conclusion being measured. Split default-pass and on-demand evidence: a plain-map scenario covers
the default detectors; a separate deepening scenario names both the fact (bridge scope) and the
consumption view (fan/chasm scope). A truncated findings table is inconclusive, not a failure.

The grader binds each detector to its intended section and reports entity, defect semantics, and
observed confidence tier. Role-playing counts as handled when the map explicitly distinguishes both
roles in its structured edge list, dimensional semantics, or Coverage, and emits no role defect in
Findings; forcing an already-correct edge into Coverage would add prose without removing harm.
Additivity additionally requires transcript evidence that the relevant load was read in the same
pass. Self-tests must demonstrate for every detector: a constructible green row, deleted-row red,
right-entity/wrong-semantics red, right-semantics/wrong-entity red, unsupported-tier red, and
cross-detector non-confusion. Run both PowerShell hosts under a hostile code page before using the
live numbers.

## 4. Files touched (at implementation — not this session)

- `src/stacks/dotnet/files/{.claude,.github}/skills/map-warehouse/SKILL.md` — subsection 9.6
  rewrite (Phase 1 + Phase 2 classes from §3.4), new "Modelling health deepening" named procedure
  (§3.5), §3.3's convention-check pointer.
- There is no monorepo source sibling: the dotnet whole-file is composed into monorepo. The
  `.github/skills/map-warehouse/SKILL.md` mirror does exist beside the `.claude` source and must be
  updated in the same change.
- Rebuild `dist/{dotnet,monorepo}`; `dist/angular` unchanged except version-stamp changelog entry.
- Root `CHANGELOG.md` + all four `src/stacks/*/files/CHANGELOG.md` heads; release via
  `.claude/scripts/release.ps1` (meta-invariant #7).
- `meta/context-footprint.json` — refresh the measured on-demand body size. The current gate counts
  skill bodies as `ondemand-info` and explicitly does not policy-gate them; the 40,000/48,000
  ceilings apply to static context, so they are not a blocker for this body-only change.

## 5. Acceptance criteria (fixes §6 findings 1, 12 — full scope, all fields tested)

1. Planted-model fixtures exist for each detector retained after §3.8's per-detector stopping rule,
   each with a pre-registered red baseline and a constructible success case,
   **within the evidence-dependent confidence band §3.4 claims for it**. **The red baseline must be run
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
5. Behavioural evals (reuse the B-41 harness — do not build a second one) show a structured finding
   changes the existing map read-side outcome: a report query or review decision follows the
   finding instead of merely reproducing its table. This is the live consumer; B-126–B-128 are not.
6. The bridge detector (§3.4 Bridge row) never fires without its stated trigger evidence and never
   fires when a correct bridge/allocation owner already represents the relationship.
7. `no-meta-leak`, `validate-dist` ×3, hook suites ×3, meta suite all green; context-footprint is
   refreshed and the on-demand delta reported (§4).

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

**Historical verdict on rev 1: ACCEPT WITH CHANGES.** Rev 2 was the changed version and at that
point had not been re-reviewed by codex or Opus. The review below now discharges that precondition.

### Claude Opus review of rev 3 (2026-08-09) — incorporated in rev 4

Independent Claude Opus returned **ACCEPT WITH CHANGES**. After checking each claim against the
tree, rev 4 accepts: the unfalsifiable `Possible`-tier gate; the omitted natural-key-on-fact case;
the SCD cost-discipline mismatch; the false `Confirmed` claim from special-member absence; the
missing aggregate stopping rule; the nonexistent B-126–B-128 behavioural consumer; the stale line
citations; the duplicate Conformance row; relocation of the role-playing map gap to Coverage; and
the unresolved sibling/mirror inventory.

One finding is rejected after verification: Opus treated the 39,527/40,000 dotnet static-context
number as a blocker and requested a pre-named cut. `scripts/context-footprint.ps1:270-271,286-291`
and its bash twin classify skill frontmatter as `static.claude` but skill bodies as
`ondemand-info`; `meta/context-footprint.json` explicitly says the latter is reported but never
policy-gated. This change does not alter frontmatter. Rev 4 still requires reporting the body delta,
but does not invent a static-ceiling risk. Opus explicitly said the accepted changes do not require
another full adversarial pass. This discharges the pre-implementation gate for the rev-3 design;
later material deltas retain their own review gates.

### Claude Opus review of the Phase-2 baseline instrument (2026-08-09) — incorporated in rev 5

Opus returned **ACCEPT WITH CHANGES**. Rev 5 accepts all three blocking findings: a one-run aggregate
is correlated rather than nine independent samples; detector booleans must enforce confidence
ceilings; and role-playing/additivity need section- and transcript-aware evidence. It also accepts
the required neutral naming/no-leak assertions, default-vs-deepening split, named-fact bridge scope,
baseline negative controls, stronger mutated-row/cross-detector self-tests, two smaller defect
fixtures, explicit section boundaries, fixture isolation, and hostile-code-page/two-host checks.
These are preconditions to the Phase-2 live baseline, not post-run repairs.

### Rev 6 evidence-instrument corrections after baseline batch 1

The first baseline batch exposed two instrument defects and two over-constrained readings. Its
default-A row is invalidated because the truncation regex matched ordinary prose saying staging was
"not truncated/filtered"; only explicit line-start truncation/output-limit markers count now. Its
bridge observation is invalidated because the planted `FactCampaignResponse` was itself an
allocation owner at sale×campaign grain. The replacement fixture puts one `CampaignKey` on
`FactSales` while repository evidence states one sale can carry multiple percentage allocations,
leaving no artifact that can represent all allocations. Confidence parsing now accepts a tier cell
that begins with `Likely`/`Confirmed` and then explains it. Finally, a directly-read view that joins
two facts before aggregation supports a **Confirmed structural chasm finding**; whether the numeric
impact occurs remains conditional on data cardinality. Two attempted Opus follow-up sessions timed
out without a verdict and are not counted as reviews; these corrections follow direct retained-map
evidence and the original Opus instruction to verify reviewer claims rather than treating them as
verdicts.

### Rev 7 confidence calibration after corrected invocation 1

The retained maps prove the earlier ceilings were too coarse. A complete one-statement SCD load can
directly prove that no matched change path exists; an explicit repository identity rule plus
incompatible DDL grains can directly prove structural non-conformance; and an explicit many-to-many
rule plus one scalar fact key directly proves the representation gap. All are `Confirmed` structural
claims while their runtime consequences remain conditional. The natural-key matcher also accepts
the evidenced equivalent wording "raw `CustomerId` text versus surrogate `CustomerKey`" rather than
requiring the literal word "natural". These corrections narrow lexical coupling; they do not add a
detector or reinterpret an absent artifact as a pass.

### Rev 8 — frozen Phase-2 implementation scope after corrected baseline observations

One retained invocation was regraded under the final matcher and two later invocations ran under
that matcher. Natural-key misuse and role-playing documentation were handled in the retained
regrade and both later observations, so receive no new instruction. Every other registered class missed its required
world or tier at least once: mixed grain and balance additivity were never accepted; structural
conformance, special members, bridge allocation and fan/chasm detection were inconsistent; and the
clean control emitted an unsupported SCD finding in 2/3 runs. Phase 2 therefore adds one compact,
evidence-gated modelling-health checklist covering exactly those seven classes. It requires default
pass findings for local DDL/load proof, reserves allocation and named consumer-view fan/chasm
analysis for scoped deepening, uses the per-class confidence labels in §3.4, and forbids SCD
findings based only on absent history markers or an unread load. No other
detector or generic warehouse advice is authorized by this baseline.

### Rev 9 — implementation-review corrections

Claude Opus rejected the first Phase-2 implementation. Rev 9 accepts its blocking findings: use
explicit per-class tiers rather than a generic direct/cross-artifact heuristic; keep allocation and
fan/chasm checks in a named on-request deepening; enumerate the health classes in the Findings
procedure; and require post-change evidence plus context/changelog gates. The recorded baseline is
described as two later observations plus a retained-artifact regrade, not three runs of one frozen
instrument. The implementation-review rejection is the adversarial review of the rev-8 delta; the
corrected implementation requires a follow-up verdict before acceptance.

### Rev 10 — final-review instrument correction

The user-authorized fresh `gpt-5.6-sol` high-reasoning review returned **REJECT** and independently
confirmed a Terra audit: default-A's original running balance did not prove mixed row grain, its
`CustomerId` had no evidenced dimension join, and its correct additivity finding was rejected only
for a defensible stronger confidence. Rev 10 replaces those premises with direct evidence: two
explicit row identities, an actual business-key dimension join, and an inspected unsafe consumer.
Confidence is evidence-dependent, not an exact class-wide answer key. Special-member scope is
narrowed to a proven consumer-label collision. The grader parses fields separately, checks complete
evidence/severity/consequence/remediation, locates role coverage in Coverage, strengthens negative
controls, adds a correct-existing-bridge control, and adds a finding-led report-review outcome.
The corrected implementation requires a fresh Sol verdict before release.

## 7. Out of scope

No angular
content (this skill is dotnet/monorepo-scoped per B-40/B-96 precedent, to be confirmed at
implementation). No change to `add-warehouse-load` (B-124's territory). No schema-evolution
preflight (B-126), scoped lineage trace (B-127), or physical-design review (B-128) — this design
produces only the shared modelling-analysis layer those items are filed to consume. Review status
is recorded per revision in §6 and rev 9.
