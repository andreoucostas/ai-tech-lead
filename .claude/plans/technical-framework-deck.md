# Technical framework deck

## Objective

Add a technical companion to the existing persuasive framework briefing. The new material must let
an engineering audience trace how a request becomes a governed change, distinguish instructed from
deterministically enforced standards, understand cross-tool limitations, and see how the framework
itself is composed, validated, released, and adopted.

## Deliverables

1. `src/core/docs/presentation/framework-technical.html` — a self-contained, offline technical deck
   with keyboard navigation, speaker notes, print/PDF styling, and an explicit claim-to-evidence
   appendix.
2. `src/core/docs/presentation/framework-system-map.html` — a printable one-page reference that
   combines the runtime, enforcement, and framework supply-chain views.
3. Update the three stack READMEs so the new presentation assets are discoverable.
4. Add consumer-facing changelog entries and release the shipped documentation through the normal
   versioned composition flow.

## Content architecture

1. Whole-system map.
2. Installed repository anatomy.
3. Request lifecycle.
4. Seven workflow contracts and the security overlay.
5. Technical convictions.
6. Enforcement-strength model.
7. Tool and delivery-surface matrix.
8. Knowledge, governance, and traceability.
9. Framework composition and validation.
10. Adoption, measurement, and honest boundaries.
11. Claim-to-evidence appendix.

## Quality gates

- Claims distinguish instructions, soft context, advisory analysis, hard local blocks, deterministic
  validation, and human authority.
- No claim overstates semantic guarantees or cross-tool parity.
- All files work offline and remain legible at 16:9 presentation size and when printed.
- Rebuild and validate `dotnet`, `angular`, and `monorepo` distributions.
- Run the relevant documentation/template and install-smoke verification required by the repository.

