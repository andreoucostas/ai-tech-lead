# B-98 step 2 design — what to do about a prompt that reaches no framework guidance

**Status: DRAFT, NOT LOCKED.** Written 2026-08-06, immediately after step 1 (`r=0/6`) and step 3
(roster sweep). Requires an adversarial critique pass by a different session before any
implementation — Maintenance model #1. The critique is licensed to reject the premise.

---

## 1. What we actually measured

Step 1, six pre-registered `sonnet` runs on framework v0.46.0, warehouse fixture, population A:

| Signal | Result |
|---|---|
| `Skill` tool invoked | **0 / 6** |
| `docs/warehouse-map.md` opened | **0 / 6** |
| Dimension correctly joined | 6 / 6 |
| Attribute reached via a dead (declared-but-unpopulated) column | 4 / 6 |

**Both channels were zero.** That is the single most important fact in this document and it is
under-read if the item is filed as "routing". The map is a *plain markdown file on disk in the
repo*. Opening it requires no skill, no routing, and no framework mechanism — just a `Read`. The
model performed 12 `Read` calls and 7 `Glob` calls in one run and opened every table DDL, both load
procedures and all three reporting views. It did not open the one document that summarises them.

## 2. What the evidence rules OUT

Recording these first, because each is a plausible remedy that the data already kills. This is the
section a critique should attack hardest.

**2.1 "The skill was not visible."** Ruled out. `map-warehouse` is named and described at
`dist/*/CLAUDE.md:71` under Common Tasks — always-loaded context that `/bootstrap` never rewrites
(design §3.4.1). It was in the window on every turn of every run.

**2.2 "The description did not match the task."** Ruled out, or at least severely weakened.
`map-warehouse`'s USE FOR already contains *"answering … 'what feeds this report'"*. The probe
prompts are report-replication tasks. A matching phrase was present and the skill still did not
fire. **Any proposal whose mechanism is "write a better description" must explain why this
observation does not also apply to it.**

**2.3 "A weaker model would do better with more signposting."** Not tested and not assumable. The
haiku pilot was discarded by pre-registration precisely because it cannot separate a routing gap
from weaker tool selection.

**2.4 "The framework was not installed properly."** Ruled out by on-disk inspection of the retained
scratch: 12 skills, the map file, population-A `CLAUDE.md`.

## 3. The best available explanation

Step 3's roster sweep supplies it. **Every skill is named and framed by the artifact it produces**,
never by the question it answers. `map-warehouse` *produces a map document*. The developer asked for
a `.sql` file. Invoking a map-producing recipe is a detour away from the requested deliverable, and
the model optimised for the deliverable — reasonably.

So the failure is not "the model could not find the right recipe". It is:

> **Nothing obliges the model to consult what this repo already knows before writing code that
> depends on it.**

That framing covers the zero-skill channel *and* the zero-file-read channel, which no purely
routing-shaped remedy does. It also generalises past warehouses: the same shape applies to
`docs/architecture-decisions.md`, `FRAMEWORK-CONTEXT.md > Known Hazard Areas`, and any
`/bootstrap`-authored convention block.

**Confidence: moderate, not high.** It is the best explanation of six runs; it is not proven. It
predicts that an obligation-shaped intervention raises both channels and that a description-shaped
one does not. That prediction is testable and §6 pre-registers it.

## 4. Options

### Option A — An always-on obligation rule ("consult before you write")
Add a rule in the Verification Rules block: before writing code against a subsystem this repository
documents, open that document first; if it is stale or absent, say so rather than proceeding
silently.

- **Delivers?** Yes, and this is new since v0.45.0. The rule lives in
  `.github/instructions/framework-rules.instructions.md`, which is **unprotected** and reaches
  already-installed consumers on update (B-97 canaries 1–4). Before v0.45.0 this option was
  undeliverable, which is why it was never on the list.
- **Targets both zero channels.** It is about consulting an artifact, not about selecting a tool.
- **General, not DW-specific** — satisfies B-99's placement objection and would very likely subsume
  B-99 itself.
- **Cost:** static context. **This is now the binding constraint and v0.47.0 made it worse:**
  monorepo `static.claude` is at 47,354 / 48,000 — **646 characters**, ~162 tokens. A ~600-character
  rule does not fit. Either the ceiling is raised deliberately (needs a WSD, and B-110 must be
  settled first because the ceiling currently cannot fail), or something is removed, or the rule is
  written at ~300 characters and loses precision.
- **Risk — the sharpest one:** B-72's lesson. A rule that reads well and does not fire is worse than
  no rule, because it gets recorded as a fix. B-99's first draft was rejected in review for exactly
  this: it required the model to *classify* its action before the rule could bite. Any wording here
  must trigger on an **observable action** ("before writing a query / before adding a filter"), not
  on an abstract category.

### Option B — Give every orphaned exclusion a destination
Step 3 found ~12 tasks named in `DO NOT USE FOR` clauses with nowhere to go (*writing queries
against an existing entity*, *modifying an existing endpoint*, *report/query tuning*, …). Route each
to a real command or skill, or stop naming it.

- **Cheap, unarguably correct, and independently valuable** — the roster currently says "not here"
  more often than "here", with most signposts pointing at nothing.
- **But it probably does not fix `r=0`.** No exclusion in the roster names the probe's task, so
  nothing was pushing the model away; the task was simply unclaimed. Honest assessment: this is
  hygiene that reduces future misrouting, not the remedy for the measured failure.
- v0.47.0 already applied this discipline to the four Angular skills it touched (16/16 destinations
  assert-checked), so the pattern and the check both exist.

### Option C — A `route-prompt` no-match fallback
When no skill matches, emit a line naming the nearest skills and stating that none matched.

- **Directly addresses "silence is indistinguishable from success"**, which is B-98's title.
- **But it misdiagnoses this instance.** A skill *was* eligible and *was* in context; a fallback that
  fires only when nothing matches would not have fired here at all.
- **Costs context on every single turn** — against 646 characters of monorepo headroom, this is the
  most expensive option and the least targeted.
- Keep on the list for the *general* silent-failure problem; reject as the remedy for `r=0`.

### Option D — A consumption/read-side skill
Add e.g. `query-warehouse`.

- **Rejected already, and the rejection still holds.** B-96's design rejected exactly this: a second
  selectively-routed skill "adds a routing bet without removing one". Step 1 is precisely the
  evidence that the routing bet does not pay — adding a second skill to fix a skill that was not
  reached is circular.

## 5. Recommendation

**Option A as the remedy, Option B as independent hygiene shipped separately, Option C parked, Option
D rejected.**

Sequence, and the ordering is load-bearing:

1. **Settle B-110 first.** The context ceiling is currently advisory (`WARN`, exit 0). Option A's
   whole feasibility argument is a budget argument. Deciding a budget question against an instrument
   that cannot fail is how B-99's headroom figure came to be wrong by 4×.
2. **Then decide the budget explicitly** — raise the monorepo ceiling with a WSD, or find removals.
   Do not let a 646-character headroom silently decide the wording of a rule that is supposed to
   change behaviour.
3. **Then draft the rule against §6's red-test**, not against readability.
4. **Ship Option B whenever** — it is independent of all of the above.

## 6. Pre-registered success criteria (write these before running anything)

Per Maintenance model #4 and B-72's standing rule: **a behavioural probe is only a red test once it
has been shown to fail on the unfixed tree.** Step 1 has already done that — `r=0/6` *is* the red
observation, on this exact instrument, recorded in `meta/eval-results.md`. That is the one asset this
design starts with that B-96's did not.

- **Instrument:** the same three `warehouse-route` paraphrases, same harness, same model (`sonnet`),
  same fixture. Do not build a second harness (B-96's constraint) and do not change the fixture, or
  the before/after stops being a comparison.
- **n = 6**, same as step 1. Do not shrink it, and do not substitute a cheaper model — the haiku
  pilot is already on record as uninterpretable.
- **Primary outcome:** `r` = runs where framework warehouse guidance demonstrably enters context
  (either channel). **`r ≥ 5` = the intervention works. `r ≤ 1` = it does not; do not ship it and do
  not reword it into a pass. `2 ≤ r ≤ 4` = partial; ship only with a stated reliability ceiling in
  the shipped docs.**
- **Secondary, reported but not decisive:** `usedDeadColumn`. Step 1's baseline is 4/6. It is
  secondary because the probe was not designed for it and its variance across batches is visible.
- **Falsification condition, stated in advance:** if `r` rises while `usedDeadColumn` does not fall,
  the rule is producing document-opening theatre without changing the output, and that is a failure,
  not a partial success.

## 7. Open questions for the critique

1. **Is §3's explanation right, or is it a story that fits six runs?** The competing explanation —
   the model simply judged a 9-table fixture small enough to read directly, and would behave
   differently at real scale — is not excluded by anything here, and if true it means the probe
   cannot measure the remedy either. **This is the weakest point in the document.**
2. **Does Option A survive its own §2.2 test?** A rule is prose. Step 1 showed prose in context
   (`Common Tasks` + a matching USE FOR) failing to change behaviour. Why would this prose be
   different? The intended answer is "because it states an obligation on an action rather than
   describing a capability" — but that is an assertion, and §6 is the only thing that can settle it.
3. **Is the budget worth it at all?** ~600 characters of always-on context, for every consumer of
   every stack, to fix a failure observed on one subsystem. What is the removal candidate if the
   answer is no?
4. **Does B-99 fold into this entirely?** If Option A ships as a general "consult before you write"
   obligation, B-99's "don't re-resolve an upstream decision" may become a second sentence of it
   rather than a separate rule — which would halve the budget cost of doing both.

## 8. Out of scope

No change to `map-warehouse`'s content (that is B-96, still blocked). No new skill. No second eval
harness. No fixture change. No decision on B-96's index line — settled already: it reaches greenfield
only, and the skill content it points at reaches everyone on update.
