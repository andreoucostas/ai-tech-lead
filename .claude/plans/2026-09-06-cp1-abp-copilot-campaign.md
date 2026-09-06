# CP1 — ABP / Copilot CLI campaign contract

**Authority:** user-supplied reviewed plan, accepted for implementation on 2026-09-06.
**Authoring baseline:** `87521cdf4c893d1a45c1aea20982f8cb847a2650`.
**Design disposition:** ACCEPT WITH CONDITIONS, as reported in the handoff; see
`2026-09-06-cp1-abp-copilot-critique.md`. Protocol acceptance is not execution evidence.
Substantive protocol changes require renewed independent review.

## Objective, scope and proportionality

Test whether the complete framework improves one complex change in a large unfamiliar repository;
then investigate discovery, capture, refresh and ordinary knowledge use. This is a maintainer study,
**CP1**, derived from FS2, with a different Copilot setup procedure. Keep its results separate from
FS1, FS2, RK1 and the historical drill. B-42 still requires an independent developer's FS2 evidence.

The observed problem is an evidence gap: v0.84.0's source/gate evidence does not establish actual
Copilot discovery, application or comparative task value. One whole-product pair plus bounded
diagnostics is the smaller useful experiment; a general evaluation harness, new release gate or
shipped API change would not close that gap. One task cannot establish long-term payback or an
advantage that increases with repository size. Varying complexity requires a later study.

Use **Copilot CLI only**, including setup; VS Code is deferred until an operator and calibrated host
exist. Compare native Copilot with complete **v0.84.0**, commit
`a3986c207fe336abc5967652a021625c2a17ed75`, first. Use one fixed model and equivalent task budgets.
Authorize one Pro+ month at the advertised **$39 subscription price**, with paid overage disabled;
confirm actual billed total and allowance before purchase. No purchase precedes readiness.

## Bounded preparation before purchase

Repository selection anchor: [ABP 10.6.0](https://github.com/abpframework/abp/releases/tag/10.6.0),
`58d7243319c2b399944357edf51583135df10f1f`. The planning handoff reports 22,227 tracked files and
671 .NET project files there; these are repository counts, not first-party or executed-test counts.
Recheck the actual selected pre-change tree, including its SDK, instructions and dependencies.
The handoff reports .NET 10 at the release anchor and .NET 8 on this machine.

Preparation stops at **eight active maintainer hours or 100 candidate integrations**. Keep a
cumulative preparation ledger; do not reset caps on resumption. If readiness cannot be established,
stop and report the obstacle.

1. Freeze accepted first-parent integrations in the 90 days ending at the anchor's commit
   timestamp. Traverse newest-first; record every exclusion. Choose the first eligible integration
   touching 3–8 hand-authored files across at least two architectural areas, requiring three
   independently testable nonlocal decisions including an integration or ownership decision.
   Exclude trivial, generated-only, dependency-only and security-sensitive changes. Do not select
   for expected framework advantage.
2. Use its **actual pre-change snapshot**, complete in both arms. Inspect repository manifests and
   build scripts; restore, build and run the relevant application tests. Prove those tests exercise
   checkout source and report nonzero executed counts. A full build of all ABP projects is unnecessary.
3. Before discovery, freeze the private task request, three decisions and hard/soft labels,
   pre-change evidence, acceptable alternatives, severe-error definitions, executable checks and
   evidence-based question-response card. Grade the contract, never historical patch similarity.
   A separate reviewer inspects the concrete cards and evidence. Demonstrate the complete oracle
   passing a valid solution and each supported alternative (or immutable evidence that there are
   none), executable acceptance failing a pre-change/invalid solution, and a targeted violation of
   each decision failing while other decisions remain valid where feasible. Preserve cannot-examine.
4. Independently freeze eight source-grounded reference facts across four areas, collectively
   covering quiet unique rules, helper-dependent behavior, conflicting scopes and reusable
   operations. Keep facts, task answers, cards and solutions hidden from setup.
5. Use a **disposable native Windows guest**, initially **8 GB RAM / 100 GB disk**. Verify VM
   availability, isolation and relevant test performance. Prepare dependencies before sealing.

Raw snapshots, selection details, task cards, solutions, graders, logs and generated artifacts remain
outside the authoring repository and outside every setup/task scope. Existing maintainer records
receive sanitized evidence and gaps only.

## Isolation and setup

Native Copilot retains all ABP code, documentation, native agent instructions and skills. Any needed
safety configuration change applies equally to both arms. Each setup/task session gets a history-free
repository and fresh Copilot profile. It cannot access the original clone, historical solutions,
other arm, grading material, previous sessions or their artifacts. Remove remotes; compare initial
tree ids; retain one neutral snapshot commit before setup. Follow FS2 A3's archive/cache controls.

Prove allowed and denied filesystem access using identically permissioned controls in the actual
execution boundary before setup and each task. Block public code, issue, PR, web-search and remote
MCP retrieval during runs while allowing required Copilot transport. Test the network boundary.
Disclose that pre-existing model familiarity with public ABP remains possible.

Inspect the pinned installer's dry-run output **at the selected snapshot**. Use the documented
developer-started Copilot **headless adoption** workflow: stage proposals and invoke its supported
bootstrap phase. A human reviews/applies proposals and integrates the result locally. Preserve every
documented migration stop, including legacy skill directories. Do not invent a CLI slash command,
bypass adoption, replicate it manually or silently repair setup. If no supported Copilot route
exists, stop **NOT READY**. The developer initiates setup; preparation does not impersonate them.

Before either task:

- Complete adoption decisions and marker lifecycle.
- Inspect all setup changes against a predeclared allowed-path list derived from the installer's
  dry run/ownership and declared context outputs. Freeze ignored build/cache exceptions in advance.
  Unexpected application changes are onboarding harm; retain evidence and reject the pair. Do not
  repair into eligibility. Answer-bearing setup output makes the candidate ineligible; retain it
  and continue only within the frozen selection window and cumulative preparation cap.
- Require the actual `scripts/docs-sync-check.ps1` to pass and preserve its output.
- Rerun the application baseline in both prepared arms, proving nonzero executed counts.
- Freeze untouched generated artifacts and preserve exact prepared states before task execution.

Randomize arm order **after preparation**. Run both on the same day with identical prompts, model,
tools and limits. Only an explicit framework task-plan approval receives `Go ahead`, counted as an
intervention. Other questions follow the frozen evidence-based response card. Freeze artifacts
before any repair and disclose scorer familiarity.

## Primary comparison and observations

| Observation | Procedure and evidence | Limits |
|---|---|---|
| Native vs full framework | One selected task in each arm: acceptance, D1–D3, serious errors, interventions, review/rework, elapsed time and usage | Preserve nulls, regressions and timeouts |
| B-222 broad discovery | Untouched setup against eight hidden facts: sampled recall, grounded findings, actual reads, scope and uncovered areas | No whole-repository recall claim |
| B-223 capture | Destinations, references, statuses, dates, owner-content preservation, unsupported assertions, duplicates, lost scope, fabricated verification, installed context cost | Distribution footprint is not generated consumer cost |
| B-224 ordinary use | Task traces without naming knowledge entries: finding, reading bodies, correct application, executing verification | These are four separate observations |
| B-216 local conventions | Evidenced project practice, unsupported libraries, competing patterns, ambiguity | Only operations and stack actually exercised |

The shipped shared discovery pass budgets **40 content files**, with **two additional dependency
hops per seed**. Measure compliance and partial coverage; this is neither runtime enforcement nor
a limit on all onboarding activity.

After the primary pair, use remaining diagnostic allocation in this fixed order:

1. One bounded continuation into uncovered areas.
2. One refresh case: changed helper and quiet caller, rename/deletion, unchanged control,
   unavailable evidence and owner-edited knowledge.
3. One combined ordinary-use stress case: index above 30 entries, absent hooks, irrelevant,
   conflicting or stale claims.
4. One local-convention operation in the selected task's primary stack.

Each paid diagnostic requires frozen acceptance and observed positive/targeted-negative controls.
Refresh starts from genuinely captured claims. Missing claims remain **NOT EXERCISED**; label any
synthetic supplement separately. The combined case cannot identify which individual factor caused
a miss. Other-stack and unrun cases remain gaps. Diagnostics never modify the sealed primary pair.

## Budget, calibration and stopping

After purchase record entitlement, reset date and remaining allowance. **Q = min(actual remaining
included allowance, 7,000 credits)**. Record setup, failures and child-agent usage. Reserve the second
task arm's full allowance before launching the first.

| Allocation | Credit ceiling | Time ceiling |
|---|---:|---:|
| Host/model/observer calibration | 5% of Q | 20 minutes |
| Complete framework onboarding | 20% | 60 minutes |
| Native task | 25% | 45 minutes |
| Framework task | 25% | 45 minutes |
| Four optional diagnostics | 10% total | 15 minutes each |
| Unspent accounting reserve | 15% | — |

Each diagnostic is capped at **min(175 credits, 2.5% of Q)**. Record exact model, effort, context tier,
CLI binary/version and worker routes. Disable Auto routing and updates during the comparison. If
worker routing cannot be established, use the documented sequential fallback consistently.
Advertised flags do not prove credit enforcement: calibrate limits, route and observers before
launch. Missing primary route/accounting/isolation evidence means NOT READY.

A planned task timeout is an outcome. Provider/quota interruption preventing equivalent exposure
makes the pair **NOT COMPARABLE**; never resume it next month as the same pair.

## Frozen scoring and reporting

Apply FS2's outcome rules from `meta/field-study-kit.md` and `meta/value-rubric.md`:

- Acceptability: acceptable as-is / acceptable after bounded edits / unacceptable.
- Executable acceptance and each independent decision: pass / fail / cannot examine. Cannot-examine
  is unordered; if it prevents comparability, the pair is void.
- Quality difference is material when acceptability, executable acceptance, or a hard decision
  differs. Burden is material at **both 15% and five active minutes**, or at least **two interventions**.
- Classify benefit, harm, mixed, no detectable difference or void, retaining raw measures without
  a composite score. Score each arm before computing differences.

Task scoring is capped at **30 active minutes per arm**. Small edits mean **at most ten active
minutes**, without repairing a hard-decision violation or rewriting architecture. Record the
original result before repairs and disclose scorer familiarity.

For generated knowledge audit the **first 30 factual assertion units** in relative-path/document
order in the frozen generated-artifact corpus, under a **60-minute review cap**. Record supported,
unsupported, cannot-examine and unreviewed counts. A compound assertion passes only if all material
clauses are supported. Keep this audit separate from eight-fact sampled recall.

Report onboarding and refresh costs separately. This single task cannot establish observed
long-term payback. Report only observed host/stack/operation outcomes and retain all gaps.

## Later work and records

**B-225 / RK1:** prepare the existing `meta/repository-knowledge-component-study.md` packet for four
held-out tasks in four areas. Independently review immutable variants differing only in
discovery/capture/use; unrelated repairs match. Whole v0.83.0 vs v0.84.0 releases do not isolate the
component. RK1 is **preparation-only** in this campaign: eight task runs, potentially eight setups
and calibration are not assumed to fit this month's allowance.

**VS Code:** deferred until operator/calibrated host exist; CLI results are no substitute.
**B-42:** remains open for independent FS2 evidence.
**Complexity hypothesis:** requires a later separately designed study varying complexity.

Persist contract and attributed critique under `.claude/plans/`; record the prospective relationship
to existing studies and sanitized results/gaps in existing meta records. No general harness,
release gate or shipped behavior change is part of CP1.
