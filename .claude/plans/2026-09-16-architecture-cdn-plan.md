# Architecture HTML CDN dependency: proposed plan

Date: 2026-09-16. Status: original proposal, pending requested Opus adversarial review.
This preserves the proposal given to the user before that review. It is not an implementation
lock or release authorization. No product source has changed.

The field finding is accurate: the shared generator loads `marked@12` and `mermaid@10` without
integrity checks or CSP, and this reaches all three distributions. Those are floating major
versions.

The risk is arbitrary JavaScript executing in the page's browser context. That does not establish
unrestricted access to the developer's machine, and we have no evidence of an actual compromise.

The recommendation is exact version pins + SRI + restrictive CSP as the smallest sufficient fix.
SRI makes the browser reject script bytes that differ from the committed hash. Vendoring also
removes runtime CDN availability requirements and enables offline rendering, but adds asset and
licence maintenance. Offline rendering is useful, though not necessary to resolve this finding.

1. Fix the generator: select verified exact releases, commit SHA-384 integrity hashes, and add
   `crossorigin="anonymous"`. Check for any further scripts those bundles load.
2. Add an early CSP: authorize the known scripts and bootstrap code explicitly; block unnecessary
   connections, frames, objects and form submissions. Avoid broad CDN permission or unrestricted
   inline JavaScript. Verify compatibility with Mermaid's rendering.
3. Prove enforcement in a browser: normal Markdown and diagrams must render from the local HTML;
   altered dependency bytes and injected scripts must fail to execute. Include a hostile
   `</script>` Markdown fixture because the current generator embeds Markdown verbatim.
4. Regenerate all three architecture pages from source, then compose the distributions. Existing
   consumer pages also need regeneration with the corrected generator.
5. Add focused regression coverage and complete release verification, including direct PS7/PS5.1
   runs, changelogs and an RCA.

The gate gap is clear: current tests check formatting and freshness. They can faithfully reproduce
an insecure template and still pass. The fix needs browser enforcement evidence alongside those
checks.

Inspected sources: `src/core/scripts/build-architecture-html.ps1`,
`src/core/tests/hooks/BuildArchitectureHtml.Tests.ps1`,
`.claude/hooks/tests/DocTruth.Tests.ps1`, `src/core/scripts/docs-sync-check.ps1`,
and the three stack source/distribution architecture HTML files.

References consulted for the proposal:
- https://www.w3.org/TR/SRI/
- https://www.w3.org/TR/CSP3/#meta-element
- https://marked.js.org/

Browser enforcement, dependency-version selection, implementation and release checks remain
unperformed. The companion review record will preserve the review and source-checked disposition.
