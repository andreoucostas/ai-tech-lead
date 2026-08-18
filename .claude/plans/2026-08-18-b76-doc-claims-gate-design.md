# B-76 — gate that a shipped doc's description of a command matches that command

**Status:** **REV 2 — RE-LOCKED 2026-08-18 after the rev-1 premise was rejected and the rejection
verified.** Authorised for implementation.
**Filed against:** v0.42.0 · **Re-validated against:** v0.58.0.
**Critique:** `.claude/plans/2026-08-18-b76-sol-critique.md` (verdict: REJECT PREMISE).

---

## 1. Problem — observed, not hypothetical

Three false claims were shipping simultaneously at v0.41.0, each asserting a command performs
maintenance it does not perform:

1. `FRAMEWORK-CONTEXT.md` and all three `README.md`s: *"'Detected Framework Packages' and 'Known
   Hazard Areas' are also refreshed by `/docs-sync`"*. `grep -i hazard` over `docs-sync.md`
   returned **nothing**. The packages half was true, which is what let the sentence survive reading.
2. `rebootstrap.md`'s own frontmatter `description`: *"refresh conventions, **hazards**, and mined
   skills"*. `grep -i hazard` over its body returned **only that line**. Highest-salience of the
   three: the description drives model routing and is what the developer sees in the command picker.
3. `.github/prompts/docs-sync.prompt.md` enumerated the docs-sync workflow as four steps, omitting
   Step 4 and half of Step 2 — a `src/core` file, so it ships to all three dists as the only
   workflow summary Copilot gets.

`no-dead-instruction` (check 7) matches script *invocations* and asserts the file resolves;
`DocTruth` covers authoring-repo facts. **Neither has any notion of "this prose describes that
command."** All three have since been corrected individually; nothing keeps them correct.

## 2. What rev 1 proposed, and why it was rejected

Rev 1 proposed `validate-dist` check 13: three lexical extractors (attribution-by-proximity,
frontmatter-token-vs-body, step-count) run over ~91 Markdown files per dist, in both twins. The
adversarial critique rejected the premise. Every load-bearing finding was **re-verified by the
reviewer before acceptance** (Maintenance model #1 — corrections are input, not verdict):

- **Shape A's extractor does not parse the real lines.** `SECURITY_FINDINGS.md:3` is
  `> Managed by \`/security-review\`.` — the subject *follows* nothing; there is no quoted token
  before the attribution, so the rule skips the very anchor rev 1 listed as covered. `README.md:141`
  carries **three** attributions on one line, and a per-line single-match rule silently misses two.
  And the extractor reaps `CHANGELOG.md` history (`mandated by /generate-copilot`, `spawned by
  /review`), which would let a dated record of what we once believed block a current command edit —
  the exact reason `DocTruth.Tests.ps1:37` already excludes `CHANGELOG.md` by name.
- **Shape B is unenforceable.** Applied to the real corpus with a generous 38-word stoplist it
  produced findings in **95 of 101 files** (264 / 228 / 333 across the three dists). Spot-verified:
  `docs-sync.md`'s description ends *"Read-mostly; safe to run anytime"* — a correct usage note
  whose words appear nowhere in the body, and **should not**. A gate that fires on 94% of correct
  files is not a gate.
- **Shape C has exactly one live instance**, which rev 1 already conceded — one bespoke twin
  extractor for one contract is not proportionate.
- **The twins would diverge.** Case-folding, `\s` semantics, named capture groups and YAML folded
  scalars are all specified differently (or not at all) between PowerShell and POSIX `grep -E` —
  B-59's live class, re-armed.

The rejection is correct. Rev 1 tried to infer a *subject* from arbitrary prose, which is NLP
wearing a regex costume — the thing `DocTruth`'s own header already refuses to build as a gate.

## 3. Rev 2 — the mechanism

**A declarative registry of exact claim contracts, plus a completeness assertion, as a meta test.**

Three deliberate changes from rev 1, each removing a whole class of the critique's objections:

| | rev 1 | rev 2 | what it kills |
|---|---|---|---|
| **what is checked** | subjects inferred from prose | contracts declared in a table | the entire false-positive surface |
| **where it lives** | `validate-dist` check 13, both twins | `.claude/hooks/tests/DocClaims.Tests.ps1`, meta-only | twin divergence (WSD-005: meta scripts are PowerShell-only by decision) |
| **cost** | 91 files × 3 dists, token matching | one pass, registry-sized | the B-101 infeasible-twin risk |

### 3a. The registry

A literal table in the test, one row per contract:

```
@{ Claim = 'FRAMEWORK-CONTEXT.md'; Line = '"Detected Framework Packages" is also refreshed by `/docs-sync`'
   Command = '.claude/commands/docs-sync.md';    Requires = 'Detected Framework Packages' }
@{ Claim = 'FRAMEWORK-CONTEXT.md'; ... Command = '.claude/commands/rebootstrap.md'; Requires = 'Known Hazard Areas' }
@{ Claim = 'README.md';            ... Command = '.claude/commands/docs-sync.md';   Requires = 'Detected Framework Packages' }
@{ Claim = 'README.md';            ... Command = '.claude/commands/rebootstrap.md'; Requires = 'Known Hazard Areas' }
@{ Claim = '.claude/commands/rebootstrap.md' (frontmatter description promises 'hazards')
   Command = '.claude/commands/rebootstrap.md'; Requires = 'Hazard' }   # shape B's one real contract
@{ Claim = '.github/prompts/docs-sync.prompt.md' ('all six steps')
   Command = '.claude/commands/docs-sync.md';   RequiresStepCount = 6 } # shape C's one real contract
```

Per row, per dist, assert: the claim file exists **and still contains the claim text** (a claim that
was reworded away must not silently pass — that is the vacuity direction), and the command file
contains `Requires` / has `RequiresStepCount` top-level steps.

### 3b. The completeness assertion — this is what stops it from being a memo

A registry alone only catches regression in rows someone remembered to add. The completeness half
makes a **new** claim fail the gate until it is adjudicated:

> Scan the shipped docs for attribution-shaped lines using a **narrow, high-precision** grammar —
> a `"quoted"` or `` `backticked` `` token followed within one clause by
> `(is|are)?\s*(also\s+)?(refreshed|re-confirmed|reconfirmed|regenerated|repopulated|maintained|updated)\s+by\s+`?/cmd`?` —
> and fail on any hit not present in the registry.

Note what this grammar is and is not. It is **not** the rev-1 extractor: it does not try to find a
subject for every `by /cmd` mention, it matches a specific maintenance-claim sentence shape and
ignores everything else. Provenance markers (`Auto-populated by /bootstrap`), agent frontmatter
(`Used by /review`) and `Managed by` all fall outside it by construction, and `CHANGELOG.md` is
excluded by name, following `DocTruth.Tests.ps1:37`. If the grammar's yield is zero the test FAILS
(vacuity guard) — a silent zero is how B-75's fixture went inert.

This is the pattern `DocTruth.Tests.ps1:107-141` already uses for the CLAUDE.md↔AGENTS.md heading
mirror: an explicit mapping table plus assertions that nothing on either side is missing from it. It
is proven in this repo, it has no NLP, and a new claim costs one reviewed line.

## 4. Proportionality (Maintenance model #6)

Harm is observed and shipped, so *whether* to fix was never the question. Rev 2 is the smaller fix:
it removes the observed harm (all three defects become registry rows that fail if reintroduced),
adds a bounded discovery net for new claims, and costs one meta test instead of a thirteenth
validator check in two languages. What it deliberately does **not** buy: semantic agreement between
a description and a body in general. That is a review/eval concern, and the 94% figure is the
evidence that it cannot be a blocking lexical gate.

## 5. Tests — red before green

The test file **is** the gate, so its red-tests are `-RedTest` arms, following
`BacklogHygiene.Tests.ps1:117-137` (six named mutations, three of them vacuity mutations — the
strongest instance of this discipline in the repo, and the pattern to copy):

- `broken-contract` — a registry row whose command body lacks `Requires` must throw;
- `missing-claim` — a registry row whose claim text is no longer in the claim file must throw;
- `wrong-step-count` — `RequiresStepCount` disagreeing must throw;
- `unregistered-claim` — an attribution-shaped line absent from the registry must throw;
- `vacuous-registry` — an empty registry must throw;
- `vacuous-grammar` — a corpus yielding zero attribution matches must throw.

Each arm must be **observed to fail** and each mutation must be asserted to have actually applied
before the command runs (B-84: a red-test that reports green is ambiguous between an inert check
and a mutation that never landed).

Then, separately: revert each of the three historical defects into a scratch dist copy and show the
gate catches all three. That is the only evidence that this closes B-76 rather than something
adjacent.

## 6. Verification

`DocClaims.Tests.ps1` green under **pwsh 7 and Windows PowerShell 5.1** (B-141 just proved that
divergence is live in this very directory; `meta/BACKLOG.md` and the dist docs must be read with an
explicit UTF-8 encoding, not `Get-Content`) → all six `-RedTest` arms observed red → meta suite
green → BOM + machine-path sweeps.

Scope: `.claude/` only ⇒ **meta-only, no version bump** (invariant #7) — unless the completeness
scan finds a live false claim in `src/`, which is then a shipped correction on the normal release
path.
