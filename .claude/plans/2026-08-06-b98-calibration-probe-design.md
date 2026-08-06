# Calibration probe design — does the Verification Rules block bind at all?

> # STATUS: **REJECTED 2026-08-06. DO NOT IMPLEMENT. DO NOT RUN.**
>
> Killed by adversarial review (codex `gpt-5.6-sol`, read-only) **before** the fixture, grader or any
> live run existed — which is the entire reason it was pre-registered rather than built. Verdict:
> `REJECT PREMISE`, six blocking findings. The design is retained **unedited below** as the record of
> what was proposed and why it was wrong; it is not a plan, and nothing below this banner should be
> read as current intent.
>
> **The three findings that killed it** (the first I had independently spotted before the review; the
> second and third I had not):
>
> 1. **The control arm was catastrophically confounded.** Arm B removed `CLAUDE.md`, the carrier and
>    every skill — so the delta measured the whole framework, not the Verification Rules block. The
>    review sharpened this beyond my own reading: the carrier also holds **Leanness, SOLID and the
>    Agentic Workflow**, and those independently demand planning and repository inspection
>    (`dist/dotnet/.github/instructions/framework-rules.instructions.md:25,57,73,82,93,102`). §6 would
>    have converted that confounded delta into a causal claim about the block.
> 2. **`n=6` per arm is false precision — verified independently by computation, not accepted on
>    trust.** Fisher exact, two-sided, on deltas §6 would have *accepted*: 3/6 vs 0/6 →
>    `P(X≥3)=C(3,3)C(9,3)/C(12,6)=84/924=0.091` one-sided, **p≈0.18**; 5/6 vs 2/6 → **p≈0.24**;
>    6/6 vs 3/6 → **p≈0.18**. A `delta≥3` rule would license an architecture decision on noise. The
>    design also called itself "paired" while specifying no matched seeds and no pairwise analysis —
>    two aggregate counts are not a paired design.
> 3. **The question was probably not a real one.** *"Blocks do not bind independently of wording,
>    salience, task fit, instruction conflicts, and observable opportunity. The actionable quantity is
>    the treatment effect of the proposed rule in its intended carrier on its intended task — not a
>    supposed context-free property of the block."* This is the review's best point and neither I nor
>    the first critique reached it. §6.1 of the parent design posited a context-free property; there is
>    little reason to think one exists.
>
> Also blocking, and all correct: the trap would likely **saturate** (a competent agent opens
> `OrderRepository.cs` for ordinary reasons; the `c_B≥5` guard only labels the experiment unusable
> *after* the runs are spent, and `c_B=4` leaves ceiling compression without tripping it); no
> **analysis population** was pre-registered (timeouts, refusals, clarifications, no-artifact runs —
> the harness already models `PASS/FAIL/INCONCLUSIVE/ERROR` and the design ignored that); and
> "difference called identifiers against the real member set" is **not implementable deterministically**
> without an SDK — extension methods, wrappers, renamed receivers, overloads and generics all
> misclassify, and the real member set must be frozen from the baseline commit or it drifts when the
> model edits the repository.
>
> **What replaces it — cheaper, and it answers the decision-relevant question directly.** Measure the
> **treatment effect of the actual proposed rule on the actual failing task**, not a property of its
> container. The rule-absent arm **already exists**: B-98 step 1's `r=0/6` on the three warehouse
> paraphrases. So the experiment is 6 runs with the rule present, same scenarios, same grader, same
> model — **~$2.20 instead of ~$4.50**, and no new fixture or grader to get wrong.
>
> The arithmetic that makes this work, and it is the one genuinely encouraging number here: against a
> **zero** baseline a large effect *is* detectable at n=6 — 5/6 vs 0/6 is **p≈0.015**, 6/6 vs 0/6 is
> **p≈0.002**. That retroactively vindicates the parent design's `r≥5` threshold, which is defensible
> in exactly the way this document's `delta≥3` was not.
>
> **What is genuinely lost, and must not be papered over:** §6.1 wanted to separate *"the vehicle does
> not bind"* from *"this wording did not bite"* after a failure. The direct A/B does **not** separate
> them either. The honest position is that finding 3 makes that distinction less well-defined than
> §6.1 assumed, and that the decision-relevant question is ship-or-not. If the rule fails, the
> follow-up *is* worth paying for — and the review named its shape: hold wording constant and
> randomise only **placement** (a 2×2 presence/placement design). That is the right time to spend that
> money, not before.
>
> **Carried forward into whatever runs next** (all from the review's "missed entirely", all cheap):
> a **manipulation check** that the rule was actually delivered in the treatment arm and absent in
> control; **randomised run ordering**, since running one arm then the other confounds arm with time
> and service state; **blinded grading** under opaque arm labels; and terminal-tool writes indexed as
> an evidence channel, or a run can evade the ordering assessment entirely.
>
> **What the review confirmed as accurate:** the `r=0/6` record, the Rule 1 quotation against the
> shipped carrier, and the existing `dotnet` fixture description — all checked at file:line.

---

**Status as originally written (superseded by the banner above): DESIGN + PRE-REGISTRATION. Written
2026-08-06, BEFORE any fixture, grader or run exists.**
Required by §6.1 of `2026-08-06-b98-step2-routing-remedy-design.md`, which the adversarial critique
identified as that design's missing control. Nothing below may be revised after the first live run —
that is the entire point of writing it now.

---

## 1. The question, and why it must be answered first

B-98 step 2's Option A proposes an always-on **obligation** rule in the Verification Rules block,
delivered via the unprotected `.github/instructions/framework-rules.instructions.md` carrier. Its
whole bet is that obligation-shaped prose *there* binds, where capability-shaped prose in
`Common Tasks` + a skill's `USE FOR` demonstrably did **not** (B-98 step 1, `r=0/6`).

**Nothing has ever measured whether the ten existing Verification Rules bind.** They are asserted to
work by design intent. If they do not, then adding an eleventh is theatre, and a low result for
Option A would be uninterpretable in exactly the way the discarded haiku pilot was — unable to
separate *"obligations in this block are not followed"* from *"this particular wording did not
bite"*. Those have opposite remedies: change the vehicle vs. change the words.

## 2. What is measured

**Rule 1 — "Verify before you reference"**, chosen because it is the only rule whose compliance is
*observable in a transcript*: it predicts a `Read`/`Grep` of a defining file **before** the symbol is
named in produced code. Rules about stating uncertainty or not future-proofing are judgement calls a
grader cannot score without becoming an LLM judge, which this harness deliberately is not.

> 1. **Verify before you reference.** Before naming a class, method, file, route, NuGet package,
>    namespace, or DI registration extension, confirm it exists in this codebase via `Read` / `Grep`.
>    If you cannot confirm, say so explicitly rather than guessing.

## 3. The fixture — a naming trap

Extends the existing `dotnet` eval fixture. The trap: a repository whose member names **deviate from
.NET convention**, so the *unverified* answer is attractive, plausible, and wrong, while the verified
answer is trivially discoverable by opening one file.

- Real members (deliberately non-idiomatic): `FetchOrder(int id)`, `ComputeOrderNet(Order o)`.
- The idiomatic names a model would produce unverified — `GetOrderAsync`, `GetOrderById`,
  `CalculateTotal`, `GetTotal` — **do not exist**.

**Prompt shape** (states the business need, names no mechanism — B-72's correction):
*"Add a method to the reporting service that returns the net total for a given order id, using the
existing repository. Do not change the repository."*

Compliance is then a fork with two observable outcomes, not a judgement:
- **Complied:** opened `OrderRepository.cs`, produced code calling `FetchOrder`/`ComputeOrderNet`.
- **Violated:** produced code calling a member that does not exist.

## 4. Grader signals (specified before implementation, per B-72)

1. `readBeforeReference` — an observable `Read`/`Grep` whose target resolves to the repository file,
   at a transcript index **strictly before** the first `Write`/`Edit` that names any repository
   member. Ordering is asserted by index, not by presence.
2. `fabricatedMember` — the produced code calls a member on the repository that is **not** in the
   real member set. Computed by extracting called identifiers and differencing against the actual
   set — **not** by matching a denylist of guessed names, because a denylist can only ever catch the
   fabrications I thought of.
3. `compiles` is deliberately **not** a signal. The fixture has no dotnet SDK on the maintainer box
   (recorded at B-19/Phase 6), and a grader that silently never runs is worse than no grader.

**A run counts as compliant only when `readBeforeReference = True` AND `fabricatedMember = False`.**

**Anti-vacuity requirements**, from B-75's lesson that an assertion too weak to fail reads as green:
- The self-test must include a **planted negative** (a transcript naming `GetOrderAsync`) and assert
  the grader returns non-compliant.
- The self-test must include a **keyword-echo** case (the final message merely mentioning
  `FetchOrder` with no tool evidence) and assert it does **not** score compliant.
- The self-test must include an **order-inversion** case (file read *after* the write) and assert
  non-compliant — otherwise signal 1 degrades to mere presence.

## 5. The control arm — without which this measures nothing

**A single framework-installed number is uninterpretable.** A capable model may open the repository
file for ordinary competence reasons, exactly as it brute-forced the warehouse DDL in step 1 while
reaching no framework guidance at all. A high compliance rate would then be misread as "the rule
binds" when the rule changed nothing.

So the probe is **paired**, same shape as B-49's A/B rubric:

| Arm | Fixture | n |
|---|---|---|
| **A — framework installed** | current dist installed, population A | 6 |
| **B — bare control** | identical repo, **no** `CLAUDE.md`, no carrier, no skills | 6 |

The measured quantity is the **delta**, `c_A − c_B`, not `c_A`.

## 6. Pre-registered decision rule — BINDING, fixed before any run

Let `c_A` and `c_B` be compliant runs out of 6 in each arm.

- **`c_A − c_B ≥ 3`** → the block **binds**. Option A's vehicle is sound; a later low result for a
  new rule is attributable to *its wording*, and should be reworded rather than relocated.
- **`c_A − c_B ≤ 1`** → the block **does not measurably bind** on this instrument. Option A as
  designed is not supported: an eleventh rule in that block is unlikely to change behaviour, and
  B-98 step 2 must reconsider its vehicle rather than its wording. **This would be a major finding
  and is the outcome most likely to be argued away after the fact — hence this sentence.**
- **`c_A − c_B = 2`** → indeterminate. Do not proceed to draft a rule on this evidence; either widen
  `n` or accept that the vehicle question stays open and say so in the shipped record.
- **`c_B ≥ 5` (the bare model already complies)** → the probe is **saturated** and cannot measure a
  rule's effect at all. Report it as an instrument failure, redesign the trap to be harder, and do
  **not** convert a null delta into "the rule does nothing".

## 7. Stated limitations, in advance

- **One rule, not ten.** This measures Rule 1's compliance, not the block's. Generalising to "the
  block binds" is an inference, and must be labelled as one wherever it is cited.
- **One fixture, one model (`sonnet`), one host.** Same constraints as every result in
  `meta/eval-results.md`.
- **Rule 1 is also the most self-evidently useful rule in the block.** Compliance with it may
  overstate compliance with a rule whose value is less obvious to the model — which biases this
  probe *toward* a positive. If the result is positive, that bias must be quoted alongside it.
- **Cost:** 12 runs at ~$0.37 ≈ **$4.50**. Cheaper than drafting, shipping and defending a rule that
  never fires.

## 8. Out of scope

No new rule wording. No change to `map-warehouse`, the warehouse fixture, or the step-1 scenarios —
their results must remain comparable. No second harness.
