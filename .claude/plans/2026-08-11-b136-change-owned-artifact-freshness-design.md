# B-136 — make artifact freshness part of completing an AI-authored change

**Status:** REVISED AFTER CODEX ADVERSARIAL REVIEW — awaiting Claude Opus review

**Scope:** shipped Agentic Workflow/self-review tail, workflow commands, and the smallest
stack-specific recipe additions needed to keep repository descriptions and registers aligned with
the change that invalidates them

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
