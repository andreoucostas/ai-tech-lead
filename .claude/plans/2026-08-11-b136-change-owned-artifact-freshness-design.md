# B-136 — make artifact freshness part of completing an AI-authored change

**Status:** BOUNDED DESIGN RE-LOCKED 2026-09-01 — APPROVED by a fresh blind-first review.
WSD-068 locks the exact 470-byte candidate. This design-only session authorises no implementation.

**Current scope:** one exact replacement of Agentic Workflow Step 6 in the shared carrier. The
broader workflow-command and stack-specific scope below is superseded design history.

**Effort:** M under Maintenance model rules 1 and 6

## Problem and observed baseline

The requested behavior is that an AI which changes a repository also keeps the repository's living
descriptions current: for example, a warehouse change may invalidate `docs/warehouse-map.md`, while
ordinary application changes may invalidate `CLAUDE.md` conventions/structure, architecture
decisions, `FRAMEWORK-CONTEXT.md`, task recipes, debt/security records, team-wiki claims, or generated
agent mirrors.

The current shipped contract does not require that outcome. The canonical Agentic Workflow §5–6 and
`.claude/workflow.md` say to **flag** a new pattern, resolved debt, new security finding, or mirror
drift at the end. `/feature` likewise asks only for a summary of documentation drift. `/docs-sync`
is deliberately read-mostly and says not to apply changes automatically. Warehouse-specific rails
are stronger before a write: `add-warehouse-load` requires a current map or an equivalent live-schema
inventory. They still do not establish the general post-change rule that the actor which invalidated
an artifact owns refreshing it before claiming completion.

This item governs artifacts whose truth changed because of the current task. It is not authority to
rewrite unrelated documentation, invent architectural intent, mutate a human-owned record, or turn
every code edit into a repository-wide documentation sweep.

## Alternatives and decision

1. **Keep the existing report-only rule and improve the final warning.** Rejected: it makes known
   stale state somebody else's follow-up and does not satisfy the requested completion contract.
2. **Run `/docs-sync` after every AI change and apply its report.** Rejected: the command is a broad,
   read-mostly audit whose output needs judgment; it may report pre-existing or unrelated drift and
   does not itself update anything. Making it universal adds cost without proving the changed
   artifact was repaired.
3. **Require every known framework artifact on every change.** Rejected: most files are not affected,
   some are generated, some are append-only, some require human approval, and some should record an
   unresolved contradiction rather than be rewritten to agree with code.
4. **Selected: change-scoped affected-artifact reconciliation.** Before completion, inspect the diff
   and its behavioral/structural consequences, name each repository artifact whose factual claims or
   status the change invalidates, and reconcile it according to that artifact's ownership semantics.
   Update writable canonical truth in the same task; regenerate derivatives from their source;
   append rather than rewrite chronological records; remove/close register entries only with the
   evidence their own contract requires; and explicitly report `none` or a concrete blocked item.

The contract is causal, not keyword-based: changing SQL does not automatically require a warehouse
map refresh, but changing a mapped table, key, relationship, grain, load flow, SCD/idempotency rule,
or consumption surface does. Likewise, adding a local implementation detail does not automatically
create a convention or ADR.

## Candidate ownership and action table

| Artifact class | Trigger from the current change | Completion action |
|---|---|---|
| `CLAUDE.md` context, structure, conventions, Common Tasks | A factual claim, stable pattern, or recipe became false/new | Update canonical `CLAUDE.md`; keep high-frequency text bounded |
| `AGENTS.md`, Copilot instructions/rails, skill mirrors | Their canonical source changed | Regenerate with the existing mechanism; never hand-edit a generated mirror |
| Architecture decisions | The task makes or supersedes a material decision | Use the existing ADR workflow/index; do not infer intent merely from implementation |
| `FRAMEWORK-CONTEXT.md` and wiki claims | A scoped claim the task relied on or changed is now stale | Propose/perform the artifact's existing review-safe update; preserve maintainer refinements and evidence |
| `TECH_DEBT.md` / `SECURITY_FINDINGS.md` | The task resolves, creates, or materially changes a tracked item | Follow the register's own proof, retention, security, and ownership rules; do not delete or disclose by default |
| `LEARNINGS.md` | The task discovers a durable recurring lesson | Append; never rewrite history merely to match the latest implementation |
| Domain/stack maps such as `docs/warehouse-map.md` | A mapped fact changed | Refresh the affected bounded section with current repository evidence, update freshness metadata/coverage, and preserve unresolved/conflicting states; if safe refresh cannot be completed, do not present dependent work as fully complete |
| Generated views such as architecture HTML | Canonical input changed | Run the existing generator and drift check |

Opus must test whether this table is complete enough to guide behavior without becoming a second,
stale inventory of framework files. A likely refinement is to state durable principles in the shared
workflow and keep file-specific triggers in the artifacts/skills that already own them.

## Candidate implementation after review

1. Revise canonical Agentic Workflow §5–6 from “flag drift” to “reconcile change-owned artifacts.”
   Require the actor to inspect the diff/consequences, update affected canonical artifacts in the
   same task, regenerate derivatives, and end with either `Affected artifacts: none` or the named
   updates/blockers. Preserve the rule that uncertain intent is surfaced rather than fabricated.
2. Align `.claude/workflow.md` and the direct workflow commands that bypass or summarise its tail.
   Keep one normative definition; other surfaces should point to or compactly carry it according to
   their current delivery constraints. Update `/docs-sync` only enough to distinguish broad audit
   from change-scoped completion—do not silently convert it into an auto-writer.
3. Add narrowly stack-owned post-change duties where generic wording cannot encode the trigger.
   The first required case is the dotnet/monorepo warehouse workflow: after changing mapped warehouse
   structure or behavior, refresh the affected map sections and freshness/coverage evidence, or
   state why the task remains incomplete. Review other shipped skills for an already-declared
   durable artifact; add no duplicate inventories or speculative file lists.
4. Define deterministic delivery checks for the normative rule and mirror/stack composition. Add
   behavioral fixtures only if an existing agent-eval scenario can distinguish “changed mapped
   structure but stale map” from “unrelated SQL change”; do not claim Markdown substring checks prove
   model compliance. Red-test every deterministic checker before accepting its green result.
5. Compose all distributions, run `validate-dist` x3, relevant hook/meta suites, and greenfield plus
   update install smokes. Update root/consumer changelogs and learnings for shipped behavior. Close
   with the required RCA and a same-class sweep of framework-created living artifacts.

## Verification contract

- **Generic affected case:** a fixture changes a repository fact named in a writable canonical
  artifact. The completed result updates that artifact, not merely the final prose.
- **Generic unaffected case:** a local implementation-only change does not churn unrelated maps,
  ADRs, registers, or context files; the result can truthfully report no affected artifacts.
- **Generated case:** changing canonical instructions regenerates mirrors; hand-edited derived files
  remain forbidden and mirror checks prove delivery.
- **Protected/uncertain case:** when updating requires human intent, security authority, or evidence
  the task lacks, the agent preserves the artifact, reports the exact blocker, and does not claim
  full reconciliation.
- **Warehouse case:** changing a mapped key/relationship/grain/load behavior makes a stale map an
  incomplete outcome; refreshing only the affected bounded content plus freshness/coverage is green.
  An unrelated SQL edit is the false-positive control.
- **Append-only/register case:** the new general rule cannot overwrite `LEARNINGS.md` history or
  remove/declassify register rows without their existing evidence and authority.

Structural source-to-dist assertions prove instruction delivery, not that a model follows it. Any
behavioral claim needs a pre-registered, answer-key-free fixture and a grader observed both failing
and succeeding; otherwise report only the rendered contract.

## Proportionality

The observed framework contract explicitly permits the AI to finish after flagging drift, which is
the exact behavior the user wants changed. Replacing that completion rule and adding one bounded
warehouse post-change trigger removes most of the gap. A universal documentation graph, automatic
diff-to-doc classifier, mandatory `/docs-sync` mutation, or exhaustive per-skill inventory is larger,
brittle, and not justified by the reported harm.

## Codex adversarial review (2026-08-11)

**Verdict: requested changes; premise retained.** The first candidate said “update every affected
artifact” without defining ownership, which could make an agent rewrite generated mirrors,
append-only learning history, security records, maintainer-refined context, or ADR intent. It also
treated `/docs-sync` as a possible completion mechanism even though the command explicitly reports
instead of applying changes; risked refreshing an entire warehouse map for unrelated SQL; and had
no false-positive or blocked-authority world. The revision adopts a causal trigger, artifact-specific
semantics, bounded warehouse refresh, `none`/blocked outcomes, negative controls, and an explicit
limit on what structural checks prove. This review does **not** satisfy the Claude Opus gate.

## Opus review request

Ask Claude Opus to reject or revise the causal ownership model, the distinction between update and
flag, the artifact table's durability, the warehouse trigger/bounded refresh, protected and
append-only behavior, delivery surfaces, reachable red/green worlds, and proportionality. In
particular, test whether “do not present dependent work as fully complete” is too strong for a
documentation failure and whether a smaller shared-rule-only change would achieve most of the
behavior without stack-specific edits.

No implementation is authorised until Opus findings are independently checked and incorporated and
the resulting decision is locked in `meta/workspace-decisions.md`. If Opus is unavailable because of
limits, record `WAITING — OPUS LIMIT`; do not substitute this self-review for the required gate.

## Claude Opus review — 2026-08-22

**Verdict: REQUEST CHANGES.** The causal ownership model is sound and the codex round removed the
dangerous parts. Two findings block implementation as written, and a third shrinks the deliverable.

### 1. BLOCKING — step 1 is not deliverable within the context budget, and the plan never checks

Step 1 revises the canonical Agentic Workflow §5–6, which lives on
`.github/instructions/framework-rules.instructions.md`. That carrier is **counted in
`static.claude`** (`scripts/context-footprint.ps1:246-247`). Measured 2026-08-22:

| dist | used | ceiling | headroom |
|---|---:|---:|---:|
| dotnet | 39,501 | 40,000 | **499** |
| angular | 38,239 | 40,000 | 1,761 |
| monorepo | 47,917 | 48,000 | **83** |

"Reconcile change-owned artifacts" is necessarily *longer* than "flag drift": it must carry
inspect-the-diff, update-canonical, regenerate-derivatives, and the `none`/blocked report. That is
hundreds of characters against 83 on monorepo, and the ceiling is a **hard failure** since B-110.

The plan is not wrong, it is **unbudgeted**. Either the replacement is authored size-neutral —
displacing existing carrier text, which must then be named — or this waits on B-158(b). Do not
discover this at a release refusal; that is the failure mode B-158 exists to prevent.

### 2. BLOCKING — the artifact/action table must not ship as a table

The plan asks whether the table becomes "a second, stale inventory". It does. Today's B-164 recorded
the same shape failing: four entries each enumerated the scripts they knew about, and a fifth instance
of the same defect appeared in a script none of them listed. An artifact inventory rots identically,
and worse — a *stale* inventory of what to reconcile is read as authoritative and will suppress
reconciliation of anything absent from it.

**Take the refinement the plan already proposes:** state the durable principle in the shared workflow
("the actor that invalidated an artifact owns refreshing it, according to that artifact's ownership
semantics") and leave file-specific triggers with the artifacts and skills that already own them. The
table is excellent *design reasoning* and should stay in this plan document as rationale. It should
not become shipped text.

### 3. SCOPE — the behavioural half is unbuildable now; say so rather than implying it

Step 4 conditions fixtures on "if an existing agent-eval scenario can distinguish…". Two facts settle
that today: the eval budget blocks five entries already (B-49, B-97, B-129, B-133, B-134), and B-112
found **four instruments broken in their first version**. So the honest deliverable is: ship the
rendered contract, prove *delivery* structurally, and record compliance as **UNMEASURED**. The plan's
own closing paragraph draws exactly this line — promote it from a caveat to the scope.

### 4. Proportionality — yes, a shared-rule-only change removes most of the harm

The plan asks this directly. **Yes**, and there is evidence rather than intuition: B-98 measured
guidance moved onto the always-loaded carrier going from **0/6 to 6/6 reach**, while the same content
in a selectively-routed skill stayed at 0/6. The general completion rule is the high-reach half.

Step 3's warehouse trigger is *additive text on the same constrained budget*, and its marginal value
over the general rule is unmeasured. **Recommend shipping step 1 alone**, deferring step 3 until the
general rule's effect is observed. That also halves the budget problem in finding 1. Note the cost
lands twice: skills compose into monorepo from both stacks, so a dotnet-owned trigger also consumes
the 83 characters.

### 5. Confirmed sound — the delivery surface, which was worth checking

A new rule on the carrier **does** reach already-installed consumers: the carrier is unprotected and
arrives on update (B-97 Option A, v0.45.0). Had this rule been placed in `CLAUDE.md`, it would have
reached nobody, which is B-97's original defect. The plan's placement is right for the wrong-adjacent
reason — it should say *why* explicitly, so a later editor does not "tidy" it into `CLAUDE.md`.

### 6. Protected records — sound, with one addition

The append-only, register, and security boundaries are correctly drawn. Add one explicit case the
plan omits: **an artifact the agent cannot read** (locked, permission-denied) must be reported as a
blocker, not as `Affected artifacts: none`. That is maintenance rule 7's distinction — "I could not
examine it" is not "it is fine" — and this session shipped four fixes for exactly that conflation.

### Disposition

Implementation is **not** authorised. Two blockers first: budget the carrier text against a named
displacement or B-158(b), and reduce the table to a principle. Then step 1 alone, with compliance
recorded as unmeasured.

## Bounded design re-lock — 2026-09-01

This section supersedes the candidate implementation and unresolved disposition above. It preserves
them as review history; only the bounded decision below is current.

### Frozen contract and premise

The immutable baseline is `e6c597a78824ea587d183ca957a0fac5302c23b9`. On that tree the complete
`### 6. Flag documentation drift` content, retaining one trailing separator LF, is 477
LF-normalized UTF-8 bytes with SHA-256
`9760cabef0c54c416a201f8636e2b4bf86e3ab408bf28382f28001234d4d1b35`. The block is observably
report-only: it tells the actor to note drift after the task. That establishes a contract mismatch,
not the frequency of stale handoffs or a behavioral effect.

The first delivery is frozen to one replacement block in
`src/core/.github/instructions/framework-rules.instructions.md`. It must:

- inspect this task's effects rather than only touched paths or a repository-wide inventory;
- update affected writable canonical truth in the same task and regenerate derivatives from source;
- preserve each artifact's ownership, evidence, history, security, and human-intent boundaries;
- treat inability to read or safely update an affected artifact as a blocker, never `none`; and
- end in one of three explicit states: none affected, artifacts reconciled, or unresolved blockers.

No artifact table, named-file inventory, warehouse/stack trigger, `/docs-sync` mutation, command,
hook, eval, or second normative surface is in scope. Structural checks may prove delivery only;
behavioral compliance remains **UNMEASURED**.

### Alternatives re-weighed

1. **Keep the 477-byte report-only block.** Smallest in implementation cost, but it preserves the
   exact completion contract B-136 exists to change and retains a named-file inventory.
2. **Selected: one compact causal principle.** It covers the frozen semantics in 470 bytes and
   removes seven recurring bytes without another carrier or mechanism.
3. **Use a 474-byte three-label formulation.** An independent wording pass produced a valid option,
   but it leaves less margin and compresses artifact-specific history/security behavior into the
   less direct phrase “preserve history, security, and human intent.” The selected wording binds
   those dimensions to each artifact's own rules and states the read failure directly.
4. **Revive the earlier multi-surface/table/warehouse plan.** Rejected by the Opus review and the
   frozen scope: it is additive, duplicates inventories, and has no measured marginal value over the
   shared rule.

### Exact selected replacement

The candidate is ASCII and includes exactly one trailing LF:

```markdown
### 6. Reconcile affected artifacts
Before finishing, inspect this task's effects on repository truth. Update affected writable canonical artifacts in this task; regenerate derivatives from source. Follow each artifact's ownership, evidence, history, and security rules; never infer human intent. Treat an affected artifact you cannot read or safely update as a blocker, not `none`. End with `Affected artifacts: none`, the reconciled artifacts, or unresolved blockers.
```

Measured with PowerShell 7.6.5 and .NET UTF-8 encoding: 470 bytes, SHA-256
`f6cd9c822371970831b93e6ee9d05d50d24ac9e6ca1369eb99eb877f12868fb6`, delta **-7 bytes** against
the frozen block. The same counter rejected a fuller 573-byte candidate by 96 bytes before accepting
this one, so the bounded measure has an observed red and a constructible passing state. That proves
only size; semantic correctness is the review judgment below.

Current generated headroom was separately observed as 482 bytes for dotnet, 1,959 for angular, and
966 for monorepo. Per WSD-055 those numbers are not spending authority; the negative replacement
delta is the authority.

### Blind-first adversarial review

Reviewer `/root/b136_blind_review` used a separate Codex sub-agent session on Windows x64 with
PowerShell 7.6.5. It received the immutable baseline and frozen acceptance contract first, did not
read the existing plan or candidate, and produced an independent threat model. Only then did it
receive the exact candidate and read this history. It edited no file.

**Verdict: APPROVE.** The trace found explicit coverage for causal consequences, writable canonical
truth, source-led regeneration, ownership/evidence/history/security rules, human intent, inability
to read/update, and the terminal none/reconciled/blockers result. Four hostile mutations were red by
semantic inspection: restricting inspection to changed files, replacing source regeneration with
generic file updates, deleting the inability blocker, and deleting the human-intent boundary. These
are manual semantic mutations, not an automated behavioral instrument.

The reviewer independently reproduced the 477/470/-7 byte result and both SHA-256 identities. It
also confirmed the excluded scope and proportionality. Coverage gaps are explicit: no behavioral
agent run, Linux run, build, composition, install smoke, or dist inspection exists because no
implementation exists. The B-98 carrier result was not rerun. Compliance is **UNMEASURED**.

### Delivery limit and future implementation contract

WSD-031's unprotected carrier is the correct single source: it is refreshed on update and reaches
Copilot plus greenfield or migrated Claude consumers. Do not turn that into a universal claim;
legacy unmigrated Claude consumers remain on B-97's documented assisted-migration path. Moving the
rule into protected `CLAUDE.md` would recreate the delivery wall.

A later, separately authorised implementation may replace only the frozen Step 6 source block with
the exact candidate above. Generated distributions plus required version/changelog records are
delivery bookkeeping, not extra normative surfaces. That implementation must compose all three
distributions, prove the exact rendered rule and negative byte delta, run the Markdown artifact
verification contract, and describe compliance as **UNMEASURED**. It must not opportunistically edit
Step 5, `.claude/workflow.md`, commands, skills, hooks, tests, or evals.

**Disposition:** WSD-068 locks this bounded design and clears the two Opus design blockers. No
shipped file was changed and no implementation is authorised by this design-only session.
