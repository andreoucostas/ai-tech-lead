# Guidance-effect canary — REJECTED

**Status:** **REJECTED 2026-08-17** after adversarial critique
(`.claude/plans/2026-08-17-b145-sol-critique.md`). Not built. Recorded because the reasoning is
reusable and the item will otherwise be re-proposed.

## Why it was rejected — three findings, each verified independently

1. **The backlog already forbids it.** `meta/BACKLOG.md:1772` says, in an existing entry:
   *"Reuse the B-41 harness; do not build a second one."* This design proposed exactly the second rig
   that instruction rules out. `.claude/evals/run-agent-evals.ps1` is 3,372 lines already doing
   disposable-repo lifecycle, dist install, scenario selection, typed grading and versioned results;
   the only Claude-specific part is the executor (`Invoke-ClaudeProcess`, `(Get-Command claude)`).
   Roughly 6 of the 8 capabilities this design needed already exist. If the experiment is ever
   justified, the move is an **executor interface on B-41**, not a new system.

2. **N=6 per arm cannot detect what the design implied it could.** Exact two-sided Fisher tests:
   `0/6 vs 4/6 -> p=0.0606`, `1/6 vs 5/6 -> p=0.0801`, `0/6 vs 5/6 -> p=0.0152`. So the smallest
   separation reaching conventional significance is five successes. A plausible, visually striking
   0/6→4/6 does **not** clear it. The design called itself a trend instrument while declaring no
   margin and no equivalence test — which invites reading a null as "guidance does not work" when it
   actually says "no near-total transformation was observed". `N=6` was inherited from B-98's rule
   for a different question; it is not a power analysis.

3. **Proportionality points elsewhere.** The two decisions offered as justification do not need it:
   B-17 was already correctly rejected for lack of observed harm, and B-66 has the strongest evidence
   class this repo possesses — a real field report — so it can be decided on engineering judgement
   provided the causal claim is stated honestly as unmeasured.

## Correction to this document's own reasoning

The draft treated the static-context ceiling (142 characters of monorepo headroom) as a reason
guidance is expensive. **That was wrong for the case it was applied to.** Measured against
`meta/context-footprint.json`: a skill's *body* is `ondemand-info` and `docs/defaults.md` is
`instructed`; only a skill's *frontmatter* is `static.claude`. Neither on-demand nor instructed has a
declared ceiling. Prescriptive guidance placed in a skill body or in `defaults.md` therefore does not
compete for the scarce bucket at all.

## What would revive this

A concrete, observed hooks-off Copilot failure — not an argument that one is likely. Then: add a
Copilot executor and evidence adapter behind an interface in `run-agent-evals.ps1`, first proving
that Copilot CLI exposes reliable machine-readable tool outcomes; if it does not, grade final
repository state from commands the harness runs itself and drop the tool-event signal. Choose the
sample size from a stated minimum effect and error rate before any run, and carry this sentence:

> With six independent runs per arm, this canary is capable only of detecting a very large
> behavioural effect; failure to meet the pre-registered margin is inconclusive about small or
> moderate effects and must not be reported as evidence that guidance generally does not work.

---

## Original draft, retained for the record

## 1. The question, and why it is the framework's most important unanswered one

The product's entire value proposition is that its prose steers a model. On the Claude surface that
is partly instrumented (B-41's harness). **On the Copilot surface — the one most enterprise consumers
actually run, frequently with agent-hooks OFF — it is measured for *delivery* and never for
*effect*.** Canary 2 and 3 asked "does the text arrive". Nothing has ever asked "does the text change
the output".

The cost of that gap is now concrete and repeated:
- **B-17** was rejected this session precisely because no instrument could show its guidance changed
  behaviour.
- **B-66**'s forms guidance is blocked for the same reason, and has been since v0.40.0.
- **B-72** exists because the one behavioural probe that was built could not reproduce the field
  report it came from.

Every "should we add this guidance" decision is currently settled by argument. This makes it
settleable by evidence, and the same rig answers all three items.

## 2. Design

**Host:** Copilot CLI (scriptable here; canaries 2 and 3 already ran on it). **Hooks OFF** — that is
the population being measured, not a limitation. Copilot quota, not the constrained Claude budget.

**Shape:** paired arms over N runs, fresh disposable repo per run.
- **Arm A** — framework installed, carrier only. The status quo.
- **Arm B** — byte-identical repo plus the candidate guidance file. One variable.

**Prompt:** states the *business goal*, never the mechanism. B-72's finding #2 is that the old probe's
prompt telegraphed the answer ("bindable with `formControlName`" is close to a specification of the
`NgControl` approach), so it scored a PASS that proved nothing. Write the prompt a developer would
write, then check it does not name the technique.

**Scoring — typed, observable evidence only.** Never "the transcript mentions the rule". For the
test-integrity question, against a fixture carrying a deliberate production defect:

| signal | how it is observed |
|---|---|
| the produced test actually FAILS on the unfixed code | run it; record the runner's exit code |
| no tautological assertion | pattern scan of the written file bytes |
| does not mock the type under test | pattern scan |
| the agent ran the suite at all | a typed tool-call event, not prose |

## 3. Sequencing — the cheap early exit that could void the whole exercise

**Step 1: build the grader and red-test it OFFLINE**, against a hand-written good test and a
hand-written bad test. B-72's finding #1 is that the previous grader's patterns missed the very
idioms the guidance recommended, so it would have flipped green with no behaviour change. A grader
that has not been shown to score a known-bad artifact as BAD is not a grader.

**Step 2: run Arm A ONLY, N=6.** This is a feasibility gate, not data collection. **If Arm A already
scores near-perfect, STOP** — there is no headroom, the guidance cannot demonstrate value, and the
correct output is "no change justified", recorded. That is exactly the state that invalidated B-66's
probe, discovered *after* the guidance was drafted. Discovering it first costs six runs.

**Step 3: only if Arm A shows headroom, run Arm B, N=6.**

## 4. Pre-registration (Maintenance rule 4, both directions)

Written and committed BEFORE any live run:
- **Primary signal** (one, named in advance — no post-hoc selection among four).
- **Success world:** B beats A on the primary signal by a pre-declared margin that survives N runs.
- **Failure/no-effect world:** no material difference. **This is a useful result and the design
  commits to acting on it** — the guidance does not ship, and the context budget is spared.
- **Void world:** Arm A near-perfect (no headroom), or the grader fails its offline red-test.

Stochastic behaviour needs N>1; six runs per arm follows B-98's rule. This is a trend instrument,
never a release gate.

## 5. Why this is worth building rather than more prose

It converts the framework's central claim from an assertion into a measurement, on the surface where
most consumers run it. It unblocks B-66 and B-17 and gives B-72 its missing instrument. And it can
return "no" — which is the point: the honest outcome of measuring is sometimes that the thing you
wanted to ship should not ship, and this repo's context budget (142 characters of monorepo headroom)
means every "no" is worth real money.

## 6. Risks, stated up front

- **Grader defeat** (B-72 #1) — mitigated by step 1's offline red-test.
- **Prompt telegraphing** (B-72 #2) — mitigated by the business-goal rule, and checkable by a second
  reader before the run.
- **Signal conflation** (B-72 #3) — the old `cva` signal scored a correct pattern and a runtime-broken
  one identically. Each signal must distinguish the states it claims to.
- **Copilot CLI version drift** — record the CLI version with every result, as the host-certification
  table already does.
