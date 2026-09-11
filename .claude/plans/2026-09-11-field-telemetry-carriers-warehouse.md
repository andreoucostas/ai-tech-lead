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
