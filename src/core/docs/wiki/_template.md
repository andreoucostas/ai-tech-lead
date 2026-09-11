---
name: <kebab-slug, = filename stem>
description: <one line, unquoted; no broader or more certain than the whole body; same text in INDEX>
type: gotcha | context | recipe | failed-approach
scope: <area label or path glob, e.g. src/Payments/**>
status: verified | suspected | unverified
last-verified: YYYY-MM-DD | never (only suspected or unverified claims never meaningfully rechecked)
---
<the claim — factual statements only, no imperatives>
**Confidence:** <observed | declared | inferred | unresolved>
**Provenance:** <repository-relative evidence or requested discovery draft>
**Evidence:** <code path / commit / PR that shows it>
**Counterevidence / exceptions:** <what narrows or conflicts with this claim>
**Dependencies / unresolved:** <dependency source, unknown, or next useful source>
**Verify by:** <cheapest way a reader re-checks it>
**Semantic refresh:** trigger: <changed evidence/dependency>; result: <what was actually rechecked, or not yet rechecked>. Rereading the decisive source/predicate is enough for a scoped source claim; restored dependencies or execution are reserved for runtime or business-behaviour proof, and unavailable evidence never inflates the claim.
**Draft status:** <draft pending PR review; not team-approved policy>
