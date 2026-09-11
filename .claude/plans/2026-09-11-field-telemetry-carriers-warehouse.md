# B-236: field telemetry, carrier references, and warehouse finding scope

## Evidence and proportionality

The user reports three consumer defects: audit telemetry stages under normal Git workflows;
CLAUDE.md omits the debt identifier that AGENTS.md and Copilot instructions call DEBT-001;
and a warehouse map generalises absent PK/FK declarations to both systems although only eight
fact tables were inspected and the remainder were inventory-only. The user confirms we have no
access to those consumer repositories. Their artifacts and outcomes remain reported, not observed.

In this authoring checkout, the shared .claude/.gitignore ignores only .state/, the seed audit log
instructs committing it, and the hook comment calls it committed. Bootstrap writes conventions
before debt IDs, then generates carriers without an explicit canonical-reference reconciliation.
Warehouse coverage lists blind spots but does not explicitly bind negative findings and remedies
to the inspected object set. Existing confidence and schema-impact rules remain in force.

Small changes to these existing carriers address the reported mechanisms. No automatic index
mutation, warehouse-wide scan, new gate, identifier registry, or model evaluation harness is needed.

## Frozen contract

1. Ignore .claude/ai-audit.log through the existing shared nested ignore file. Retain .state/
   and normal configuration tracking. Correct the seed and hook comment to describe local mutable
   telemetry. Preserve hook executable behavior and installer copy-if-absent ownership.
2. Document a conditional, consumer-root migration for an already tracked log using git ls-files
   and git rm --cached, keeping disk bytes and history. No automatic untracking or history rewrite.
3. In all three bootstrap sources, reconcile canonical CLAUDE.md references to specific debt items
   after assigning real register IDs and before generating carriers. Generic register links need
   no ID; ambiguity is reported, never guessed or renumbered. Do not hard-code DEBT-001 into
   an unpopulated template. Shared generation preserves canonical IDs and qualifications and
   reports missing canonical detail instead of independently enriching derived rules.
4. In the single dotnet map-warehouse source (also composed into monorepo), enumerate inspected
   objects/database/schema scope versus inventory-only/unread objects. Negative findings and
   remedies stay within evidenced inspected objects. Group inventory-only/unread coverage without
   inventing individual finding rows; their uninspected properties remain unresolved. Preserve
   existing UNRESOLVED candidate-edge rows and finding-confidence meanings;
   absence of declarations in inspected source does not prove a whole live database lacks keys
   or justify schema changes. Keep existing confidence and impact-analysis requirements.
5. Compose all three dists, update all four changelogs for the next patch release, and record RCA
   and evidence. These changes do not repair inaccessible consumer artifacts or prove model use.

## Verification

Preimplementation critique: separate agent /root/carrier_scope accepted the narrow premises and
scope after reading the current sources. Root accepted its corrections: match only specific debt
references, preserve established IDs and report ambiguity; group unread coverage without row
explosion; absent declarations alone do not prove defects. For telemetry, migrate before update
preflight, check Git examination separately from tracking, preserve bytes, and supersede retained
old seed advice. No source was edited before this critique.

Use disposable consumer fixtures with actual shipped installers/hooks and Git under direct native
PS7 and PS5.1. The current ignore must produce a red staging result; the repaired ignore must keep
new telemetry out while ordinary configuration stages. Demonstrate that an already tracked log
still stages with ignore alone, then the documented index removal retains its bytes and prevents
future telemetry staging. Include both Claude and Copilot hook event shapes and a hostile code page.
Review adverse/valid prose examples: canonical missing/present debt IDs and eight inspected facts
versus whole-system negative claims. This is source/semantic review, not observed model adherence.
Freeze the implementation range for a nonimplementer review. Run release gates and required CI.

## RCA

Existing hook tests check appends and path normalization, while installer tests check preserved
bytes; neither observes subsequent Git staging. The seed retained the old version-control advice
after telemetry was reclassified. Related .state/ is already ignored; inspect the same source
surface for further mutable outputs. Carrier parser gates compare selected rule sections rather
than populated convention/debt semantics; warehouse checks do not prove claims against coverage.
The existing scoped-evidence and canonical-generation workflow needs the bounded instructions
above, with consumer/model outcomes explicitly left unverified.

## Focused evidence at implementation checkpoint

Immutable range: `3bbd413ad597da272b8db58fa52f67c8c09ec868` to
`6af8827dec2f22bfc002ad35d98e58df215ce417`. The contract file at that checkpoint has SHA256
`BC9EE6963EFE0B593A6D0294FC999E71182309B07A17919F92BBEF61FFD5DF8F`.

Root inspected and corrected the temporary Git probe before executing it: migration exclusion
must be asserted on the delivered candidate too, not only when a candidate switch is supplied.
On direct native PS7 7.6.5 CP65001 and PS5.1 5.1.26100.9444 CP437, all three original dists
produced expected RED exit 1 and all three rebuilt dists clean exit 0. Each ran real Claude and
Copilot hook payloads (two appends), excluded .state/, retained ordinary config staging, proved
ignore alone insufficient for a tracked log, and preserved local SHA256 through nonforce index
removal. The existing AuditTrail suite separately passed 8/0 on each dist under both native hosts.

The audit_ignore agent ran 18 real installer smokes: three dists, greenfield/brownfield/update,
native PS7 and PS5.1, all exit 0. Root inspected the receipts, verified their hashes and all nine
records per host, then compared the actual installed bootstrap files with dist hashes across all
targets. Initial probe scaffolding errors (dirty brownfield setup and a warehouse-file expectation
for Angular) were corrected and rerun, not counted as product failures. Agent evidence covers
fresh seed delivery, existing binary audit-byte preservation, normal Git staging and documented
tracked-log migration before normal update preflight. It does not prove agent-host consumption.

During review, a concurrent release incorrectly tagged this checkpoint as v0.86.5 after testing
its parent. The user approved an exact-lease correction to the tested parent; remote verification
confirmed the repaired tag and preserved field-fix commit. Full incident and open tool repair are
recorded as B-237. There are no release-script changes in this field-fix contract.

## Independent review and release boundary

Separate nonimplementer `/root/independent_review` read the frozen contract/range and sent its
hostile threat model before implementation inspection or root test evidence. It found no
actionable P0-P3 findings. It independently executed native PS7 and PS5.1 at explicit output
encoding 437: old-ignore and tracked-ignore cases each RED exit 1; new-ignore and migrated cases
each clean exit 0. Local migration bytes matched and the prior committed log remained readable.
It also reviewed seven adverse/valid examples covering generic versus specific debt references,
ambiguous IDs, preserved scope, eight inspected facts versus whole-database absence/remediation,
and unresolved candidate edges. These are manual semantic checks, not observed model behavior.

Root read the complete review, including the reviewer's corrected source/dist comparison scope
(the existing stack marker makes full hook blobs differ); executable tokens were unchanged in
all four hook paths. The reviewer reported a GPT-6-based Codex role but no exposed exact runtime
model ID; no different-model review is claimed. Its direct Git byte/history checks are a separate
execution vantage for the manual migration. It did not run installer/hook-event/full gates.

Root additionally reran the dotnet AuditTrail suite at explicit code page 437 in both native
hosts: 8/0 each, exit 0. An earlier cmd-interposed PS5.1 launch failed before five cases could
spawn because its environment contained conflicting Path/PATH entries; a direct native launch
resolved the examination failure without product changes. No such run is recorded as product red.

Subsequent changes are release stamps/generated output and evidence/RCA records only. Ordinary
release gates and the eight native Windows CI contexts plus parity must pass before v0.86.6
promotion. Consumer artifact repair and model adherence remain unobserved.

## Release integration amendment

The first release attempt refused with WorkspaceBom and offline eval-selftest failures; nothing
was committed by that attempt. The UTF-8 sweep included this task's ignored disposable binary
audit fixtures and its live output log. After the process ended, root moved that evidence tree
outside the authoring repository, preserving receipts/bytes and a relocation note. No sweep was
weakened and no product encoding defect was inferred from the fixture failure.

The eval selftest exposed a real setup dependency: Initialize-FactBindingScenario used git add -A,
so the newly ignored seed vanished from its committed baseline and downstream clones. The frozen
B-99 contract requires unrelated audit appends and rewrites to fail, while permitting the requested
hook append. The grader only evaluates that exception when the audit path is tracked. The original
unrelated-append assertion now failed with treeExact=True and auditAppendExact=True (exit 1).

Separate preimplementation critique by /root/carrier_scope inspected both callers and the frozen
contract. Root accepted the smaller repair: explicitly force-stage only the audit seed inside the
existing NeutralKeySemantics fixture branch, checking the Git exit immediately. This preserves
the controlled fixture's old baseline for both live and selftest preparation. No consumer installer
or ignore is changed; no grader/assertion is weakened, no arbitrary ignored-file scanner is added,
and no paid live outcome is claimed. The maintainer harness explicitly requires PS7. Re-run its
offline selftest and have the nonimplementer reviewer examine this separate bounded amendment.
