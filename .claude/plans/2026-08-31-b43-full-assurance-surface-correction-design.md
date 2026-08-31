# B-43 full assurance-surface correction — locked design

**Locked:** 2026-08-31 at immutable candidate
`486fd01d0d6505ce34cdcd720d18f01fb404901d`, after reading the standing decisions in
`meta/decisions-index.md`, WSD-055, WSD-057, WSD-062, WSD-064 and WSD-066; the two rejected
blind-first reviews of the tag-to-candidate range; and a fresh read-only adversarial premise/design
critique by `/root/claim_fix_design`. The critique accepted every blocker below and rejected a live
provider exercise or runtime redesign as disproportionate.

## Premise and proportionality

The second independent review found one already-observed defect class beyond the first correction's
narrative scope. Shipped hook comments promote emitted JSON to current host consumption, direct
fixtures are labelled host-firing evidence, two negative canaries diagnose one cause from absence,
maintenance commands call one routing carrier exclusive, and generated architecture diagrams turn
registration into an unconditional lifecycle. Each contradicts WSD-066 and can misdirect a consumer
without any hook logic being wrong.

The smallest repair is wording inside the existing artifacts plus narrow protection for the exact
historical spellings. No runtime branch, provider run, new suite, semantic claim classifier,
recertification schedule, or platform expansion is justified. Existing exact-claim machinery is the
cheapest durable control; semantic completeness remains an independent-review obligation.

## Frozen semantic contract

Across every changed surface, keep these facts distinct:

1. A direct fixture proves the script accepted an input and emitted an output shape.
2. Registration proves configuration, not host firing.
3. Script emission proves neither host consumption nor model delivery.
4. A visible denial or returned marker is positive evidence only for that run and capability.
5. An absent denial or marker is inconclusive: trust, launch, interpreter, event, payload,
   consumption, model compliance, and observation can fail independently.
6. The dated Copilot CLI observations and the narrow 2026-06-25 VS Code guard observation remain
   available in `docs/enforcement-surfaces.md`; unknown versions and unobserved lifecycles remain
   unknown.

## Frozen authored scope

### Core PowerShell/bash twins

- `src/core/.claude/hooks/route-prompt.{ps1,sh}`: describe the plain and JSON shapes emitted by the
  script. Remove current VS Code consumption/injection claims from the header and surface dispatch.
- `src/core/.claude/hooks/session-start.{ps1,sh}`: make the same emission/consumption distinction in
  the header, routing-pointer comment, and surface dispatch.
- `src/core/.claude/hooks/guard.{ps1,sh}`: say the script emits the documented Copilot-compatible
  superset deny shape. Whether a client honors it is capability-specific. Preserve the truthful
  input-shape/parser comments.
- `src/core/scripts/framework-doctor.{ps1,sh}`: a visible deny is positive for that run; no deny is
  inconclusive and requires the controlled canary described by WSD-066 before assigning a cause.

### Core maintenance commands

- `src/core/.claude/commands/generate-copilot.md`: AGENTS section 1 is the canonical file-based
  routing definition, not Copilot's exclusive route; a registered prompt hook is an independent,
  capability-specific salience path.
- `src/core/.claude/commands/docs-sync.md`: make the same canonical-versus-live-delivery distinction
  and remove the false `Claude-only` label from the route-prompt mirror.

### All three stack siblings

- `src/stacks/{dotnet,angular,monorepo}/files/.claude/hooks/boy-scout-check.{ps1,sh}`: SCAN writes
  the queue and emits a Copilot-shaped response; DELIVER emits/deletes the queued response. Replace
  `reaches the model` and `flagged to the model` with script-emission/reporting language. Do not
  change scan, queue, delivery, deduplication, or JSON behavior.
- `src/stacks/*/files/docs/REVIEW-GUIDE.md`: relabel the direct commands as hook-script fixtures and
  state that they prove parser/output behavior, not client firing or consumption.
- `src/stacks/*/files/README.md`: a returned WIDGET marker is positive evidence of delivery and
  instruction-following for that run; absence is inconclusive and proves neither non-delivery nor
  an exclusive fallback carrier.
- `src/stacks/*/files/docs/ARCHITECTURE.md`: label the hook diagram as registered/conditional flows;
  state that each arrow is script I/O only when the exact host event fires; use `script emits` and
  conditional event labels. Change the Copilot CLI table row from unconditional local execution to
  registration plus the capability-matrix pointer.
- Regenerate each `src/stacks/*/files/docs/architecture.html` with
  `src/core/scripts/build-architecture-html.{ps1,sh}`; never edit generated HTML by hand.

### Meta records and generated outputs

- Add nine narrow grouped entries to
  `.claude/hooks/tests/vendor-claims-denylist.txt` and matching provenance objects to
  `.claude/hooks/tests/VendorClaims.Tests.ps1`; raise the seeded rule floor from 9 to 18.
- The nine groups cover only recovered `486fd01` spellings: route/session VS Code consumption;
  guard blanket denial; Boy Scout model delivery; direct-fixture host firing; doctor null diagnosis;
  WIDGET null/exclusive-carrier diagnosis; exclusive routing; unconditional architecture opening;
  and the unconditional Copilot CLI table row. Alternatives within a group use exact token
  sequences and bounded whitespace only—no `.*`, generic `reaches the model`, or generic
  `VS Code ... consumes` inference.
- Amend the root and all three consumer `0.79.2 — Unreleased` entries. Say hook logic and
  registration are unchanged; do not claim all user-visible runtime text is unchanged because the
  doctor and Boy Scout summaries are corrected.
- Amend B-43's completion/RCA and append one concise learning for the second review's newly observed
  surface class. Regenerate `meta/context-footprint.json`.
- Compose all three distributions from `src/`; never edit `dist/` directly.

## Scope review

Every changed executable function is already required by this contract: only `Finish`'s doctor
diagnostic text and the Boy Scout summary text change. No branching, parser, queue, deduplication,
payload, registration, installer, or enforcement behavior changes. Every other changed artifact is
either an identified false assurance, the narrow gate/record for that assurance, or a generated
copy required by composition. Revert any additional surface not named above.

## Explicit exclusions

No hook JSON; no audit-trail or post-write commentary; no guard input-shape commentary; no
enforcement matrix, host ledger, canary result, installer, or WSD-066 change; no live Copilot/VS
Code run; no recurring recertification; no new test suite, semantic diagram parser, or prose
classifier; no macOS/BSD/provider leg; no B-49 work; and no inference that native instruction
delivery proves a Preview-hook event.

## Evidence contract

1. Recover every gated historical alternative verbatim from `486fd01`. Each provenance object must
   prove the pattern matches its real historical text and spares at least two legitimate corrected
   or canonical statements.
2. On the immutable correction candidate, reinsert every retired spelling at its original authored
   surface, verify source bytes changed, compose all three dists, verify every spelling reached the
   expected composed output, and require `VendorClaims` to report every expected reason. A generic
   non-zero exit is insufficient.
3. Treat a missing/unreadable source or dist, composer failure, permission error, zero scanned files,
   or unavailable interpreter as inability to examine—not a claim defect.
4. Restore saved source bytes, regenerate HTML and dists, and require byte-identical candidate hashes
   plus a clean VendorClaims rerun. These controls cover literal/syntactic inertness, exit-domain
   collision, absent-versus-cannot-examine, and normalization/comparison reachability.
5. Run related hook suites, architecture-generator twin comparison, VendorClaims, ClaimTruth,
   DocTruth, BacklogHygiene, both footprint twins, both validators for all three dists, BOM/twin
   checks, the full meta suite, and a disposable-clone Bash composition oracle.
6. Commit an immutable correction range. A separate implementation reviewer must begin blind,
   inspect the correction and full tag range, scope-review every changed artifact, run a
   release-specific hostile mutation, restore bytes, and rerun clean. Windows local evidence is not
   Linux evidence; exact-commit CI must provide both supported platform legs before release.

## RCA boundary

The earlier repair inventoried matrices and narrative carriers but omitted shipped executable
comments, diagnostic conclusions, maintenance commands, and generated human diagrams. Composition
and parser gates preserved those statements exactly while proving none of their host semantics.
