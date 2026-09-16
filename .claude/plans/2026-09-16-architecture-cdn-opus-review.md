# Architecture CDN proposal: Opus review and adjudication

Date: 2026-09-16. Baseline: `745bfd82d2ef50a66589e1ded7c99f3513c53e8d`, framework v0.86.7.
Subject: `2026-09-16-architecture-cdn-plan.md` in this directory. The original proposal is preserved.
Authority: the user requested the adversarial Opus review and subsequently said "go for it" after
the source-disclosure concern was explained. This delivery records design evidence, not a product
implementation, browser verification or release approval.

## Review receipt

Root froze the proposal and 18 source files in a separate temporary packet, checking SHA-256
source/copy equality. The initial Claude dispatch was rejected by automatic approval review because
repository content might be private. It did not start. Root then used unauthenticated GitHub REST
requests to verify `andreoucostas/ai-tech-lead` was public and that all 18 source files matched
published Git blobs at the baseline (using Git's path-aware canonicalization). The only additional
review content was the user-provided finding and the assistant-authored proposal/prompt. The retry
followed those checks and the user's explicit confirmation and was approved.

Root observed Claude Code 2.1.260 initialize as `claude-opus-5`, session
`d2875b39-ce1d-4b64-843a-8c75f81596fd`, with exactly Glob/Grep/Read and `dontAsk` permissions.
The launch requested `opus`, high effort, safe/restricted mode, strict empty MCP configuration,
no session persistence or fallback, and a USD5 configured limit. Native exit was 0; terminal
subtype was success, `is_error: false`, 19 turns, and CLI-reported duration 187149 ms.
CLI list-price accounting was USD0.996563, including USD0.001683 ancillary Haiku usage. This is
reported accounting, not an invoice or proof of budget enforcement.

The reviewer did not participate in the proposal. The prompt required source-first threat modelling
before the plan; the trace shows generator/tests/freshness/source/installer reads before the plan
read. Root's earlier supporting source review was not supplied as another reviewer's verdict.
Opus also inspected its own in-progress output stream. It had no shell or browser tool, performed
no runtime experiment, and explicitly limited its findings to source analysis. The supporting Codex
upgrade-path audit is attributed separately below and is not a second independent security review.

| Frozen item | SHA-256 |
|---|---|
| Original proposal | `B22DBE2F75E2D629EA7002257D6E3BFCB0792FBAC5A1515A536571735541E133` |
| Source manifest | `B8EE64466EAC380729150E2602708C2E826357AC1FD3A8017C4F14910D292718` |
| Prompt | `125F96F96777908DD80558163583ABD5B42DD56795C4872472E24730EF21DEFC` |
| Unmodified JSONL stream | `0163FD5AB65369F26B8BDEA2560A4E5D7335022A355837198E2F983BE9DD88FA` |
| Original result text | `827DCDD0CABC1E8AFCC6B0441E661CA3E8043793D48C77DE64B204B26F8E3965` |
| Public-source evidence | `CE6DA9974B8B684C902226E645B6367A36471396C77159EE835808337C41A0C2` |

## Source-checked disposition

**Opus verdict: REVISE.** Accept the conclusion that the proposal needs a concrete acceptance
contract. The CDN finding survives. Its severity is browser-context script execution exposure;
no exploit, machine compromise or private-file access was demonstrated.

- **F1, provenance: accept with a boundary.** Select an exact package version and physical file
  path. Match the CDN bytes to the same file in the exact npm registry tarball, verifying available
  package integrity and recording URLs, versions, date and locally computed hashes. Avoid blessing
  a CDN-generated transformation without an independent byte reference. This protects the pinned
  baseline against subsequent substitution; matching registry/CDN bytes does not prove that the
  publisher or selected release is benign. No actual dependency bytes were obtained in this review.
- **F2, CSP: accept specificity, reject the mandatory CDN allowlist.** CSP3 permits external script
  authorization by hashes matching SRI metadata, so `script-src https://cdn.jsdelivr.net` is not
  inherently necessary. Prefer known script hashes and a bootstrap hash, with no `unsafe-inline`
  or `unsafe-eval` in script permissions. Place meta CSP before interpolated content. Meta does
  not support `frame-ancestors`, `sandbox` or `report-uri`; blocking embedded frames concerns
  `frame-src`. The exact styling exceptions must be tested with selected Mermaid bytes; the static
  head stylesheet can be hashed, while dynamic styles may need a separately justified allowance.
  Neither Opus's file-origin generalization nor actual browser compatibility was tested.
- **F3, enforcement oracle: accept, strengthen attribution.** Preserve the generated policy and
  integrity values; change delivered bytes, not the expected hash. A genuine-byte control must
  render before and after the changed-byte case. Prefer intercepting the original request in a
  disposable browser setup. If a local server/scratch URL is necessary, record every adaptation
  and separately load the unchanged generated page from its real URLs. CORS, CSP-host denial,
  network failure and an SRI mismatch are distinct outcomes; only the latter establishes the
  intended tamper rejection. No absent sentinel alone can decide success. These remain planned
  observations, not a mandate for a new permanent browser framework.
- **F4, input handling: accept the defect, reject the suggested literal substitution.** Current
  generator line 71 reads raw `textContent`; it has no JavaScript-string or JSON decoder. Replacing
  `</script` with `<\/script` therefore changes the Markdown passed to Marked. A root PowerShell
  string probe confirmed the replacement is not equal to the original; that is a string observation,
  not a browser test. Use lossless serialization with explicit decoding and round-trip cases for
  Unicode, quotes, backslashes, mixed-case closing tags and literal examples. HTML-encode the title.
  This addresses the embedding boundary; it does not sanitize Marked's output or establish a general
  untrusted-HTML contract. Keep the adjacent fix explicit and bounded; do not add a sanitizer by
  default or claim that all Markdown XSS is solved.
- **F5, proportionality: accept the narrow scope, not the unmeasured details.** Exact pins plus SRI
  are the smallest control for runtime CDN substitution. Add bounded CSP because the local viewer
  also inserts HTML, subject to demonstrated compatibility. Vendoring and pre-rendering remain
  alternatives if runtime/offline requirements change. No measured asset-size comparison supports
  Opus's approximate size claim, and the cited DocTruth legal checks cover framework legal files,
  not a complete third-party licence audit. No claim that pre-rendering is intrinsically forbidden
  follows from PowerShell entry-point rules. Clarify the fallback: network or integrity failure can
  leave the whole viewer unrendered; point the reader to the canonical Markdown.
- **F6, verification: accept.** Extend existing PowerShell tests for emitted policy/asset contracts,
  safe serialization and deterministic output. Observe new assertions red on the unfixed generator
  or a focused mutation and clean on the fix, directly under PS7 and PS5.1. Compare each stack's
  source HTML to its corresponding dist and regeneration result; the three stacks are not identical
  documents. Browser enforcement/rendering is separate recorded evidence on a named browser/version
  with local-file and hosted loads. Existing suites and release gates still apply; no new generic
  mutation framework or Playwright/Node CI installation is justified by this review.
- **F7, upgrades: accept with conditional freshness wording.** Root and the supporting Codex audit
  checked installer lines 169-181, 1011-1016 and 1169-1172 plus the ownership manifests: Markdown is
  preserved; the HTML and generator are overwritten. The freshness advisory fires only if the two
  Markdown hashes differ and both files exist. Generator-only changes and absent HTML are silent.
  Add the target-root architecture regeneration step to the existing upgrade checklist and consumer
  release notes. Preserve current ownership; no installer redesign or new updater follows.

Primary references used to check corrections:
- [CSP3 external hashes](https://www.w3.org/TR/CSP3/#external-hash)
- [CSP3 meta delivery](https://www.w3.org/TR/CSP3/#meta-element)
- [HTML script data blocks and restrictions](https://html.spec.whatwg.org/multipage/scripting.html#the-script-element)
- [Marked's HTML sanitization boundary](https://marked.js.org/)

## Revised proposal and remaining lock work

Limit the candidate to the shared generator, its existing focused tests, the upgrade instruction,
six regenerated HTML derivatives, composed distributions and required release records. Select
exact independently cross-checked dependency bytes; enumerate a hash-based script policy and
minimal demonstrated style/resource permissions; implement lossless Markdown embedding and title
encoding; clarify load-failure text and target-root regeneration.

Before implementation lock, specify the actual file/version/hash tuple, exact CSP, lossless
encoding/decoding contract and the available disposable browser test mechanism. Required browser
cases are genuine/modified/genuine asset delivery with unchanged integrity, rejected injected
script/event handler, preserved ordinary Markdown and Mermaid rendering, and local-file/hosted
loads. Record network/CORS/CSP/SRI failures separately. The raw-text closing-tag case must retain
the original content, not merely suppress a sentinel. A rendered-output injection test is distinct
from serialization and must not become a claim that Marked sanitizes HTML.

Regenerate all three stack source pages, compose all distributions, run existing validation and
host suites, and verify upgrade from a consumer-specific Markdown fixture. Keep browser evidence
orthogonal to the PowerShell string assertions. Version/changelogs and an implementation-specific
independent review still precede release. No exact policy, dependency tuple, browser control or
implementation has been approved by Opus; root's dispositions were not returned to Opus for a
second review. B-239 remains open. Planning verification is recorded below after it runs.

## Planning verification

Root ran the existing complete `BacklogHygiene.Tests.ps1` and `DocTruth.Tests.ps1` directly under
each supported Windows host after authoring the planning records. PS7 and PS5.1 each reported
10 passed / 0 failed / 0 skipped for backlog hygiene and 16 / 0 / 0 for DocTruth, all exit 0.
DocTruth's existing applied mutation reported RED (exit 1) and verified byte-identical restoration.
This exercises repository planning/consistency checks, not a new architecture security oracle.
`git diff --check` also passed. No product source or generated distribution changed.

## Original Opus result (verbatim)

Evidence gathering is complete; writing the review now.

---

# Adversarial review — architecture.html CDN remediation plan

**Verdict: REVISE.** The finding is real and the direction (exact pin + SRI, generator-side, regenerate all six committed pages) is right. The plan is under-specified on the three things that decide whether it works: byte provenance, what CSP can actually do in `file://` from a `<meta>` tag, and what a non-vacuous enforcement test is. Scope should also be trimmed: drop vendoring and pre-rendering, keep permanent coverage PowerShell-only.

## Independent threat model (formed before reading the plan)

`src/core/scripts/build-architecture-html.ps1:68-69` emits `marked@12` and `mermaid@10` — floating **major** ranges, no `integrity`, no `crossorigin`, no CSP. jsDelivr resolves a range at request time, so the bytes executed are chosen by the CDN on every open, not by the commit. The page is generated into `src/stacks/*/files/docs/architecture.html` and `dist/*/docs/architecture.html` (manifest shows src/dist byte equality) and installed into every consumer repo.

- **Concrete exposure (observed in source):** anyone opening the page executes third-party JS whose bytes are not pinned by the repo. A jsDelivr/npm-account compromise, or a range now resolving to a new minor/patch, executes attacker JS in the page's origin. Under `file://` that origin is opaque in current Chromium, so "arbitrary JS in the developer's browser" is *not* "machine compromise" — the plan says this correctly and should keep saying it. Realistic impact: exfiltration of the rendered architecture document, `fetch()` to an attacker host, and a UI the reader trusts. That is enough to justify a fix; it is not enough to justify a dependency-management framework.
- **Second channel, same file:** `:63-64` opens `<script id="md" type="text/markdown">` and `:92` concatenates `$md` **verbatim**. A `</script` sequence anywhere in `ARCHITECTURE.md` terminates the container and the remainder is parsed as live HTML. Then `:72` does `innerHTML = marked.parse(md)` with no sanitizer. I grepped all three shipped `ARCHITECTURE.md` for `</script`, `<img`, `<iframe`, `javascript:` — **no matches**, so this is not currently live in our pages; it is live for any consumer who documents HTML. `$title` (`:20`, `:35`) is likewise interpolated unescaped.
- **What the gates can and cannot see:** `DocTruth.Tests.ps1:244-281` re-runs the generator and byte-compares all six committed pages, and `docs-sync-check.ps1:150-157` only compares the `src-sha1` stamp (advisory). Both faithfully reproduce an insecure template and pass. The plan states this; it is correct.

## Acceptance requirements I derived independently

1. Exact version + subresource integrity, with the hash derived from bytes verified against a host that is **not** the host being distrusted.
2. All six committed pages regenerated; `DocTruth` architecture-freshness green (it is the real freshness gate; `docs-sync-check` is advisory).
3. Rendering still works from `file://` on at least one browser, observed.
4. Permanent regression coverage that a maintainer can run under PS7 and PS5.1, red-tested.

## Prioritized findings

**F1 — Blocking. "Commit SHA-384 integrity hashes" has no provenance rule (plan `:19`).** Computing the hash from the same jsDelivr response you are hardening against is circular: a CDN already serving bad bytes gets its bad bytes blessed. *Smallest correction:* require the hash be computed locally over downloaded bytes **and** matched against the same file extracted from the `registry.npmjs.org` tarball for that exact version, with URL, date, version, file path and both hashes recorded in the plan/RCA. Also pin the *file path*, not just the version — `marked.min.js` vs `lib/marked.umd.js` are different artifacts. I am not asserting which versions are current or secure; that selection is the implementer's, evidenced.

**F2 — Blocking. CSP claims exceed what a `<meta>` CSP can do (plan `:22-23`).** `frame-ancestors`, `sandbox` and `report-uri` are ignored in `<meta http-equiv>`; "block frames" must mean `frame-src`/`child-src`. Under `file://`, `'self'` does not resolve to a useful origin, so the policy must name `https://cdn.jsdelivr.net` explicitly and must not lean on `'self'`. Two further traps: mermaid injects `<style>` at runtime, so `style-src` almost certainly needs `'unsafe-inline'` (the head `<style>` block at `:38-59` does too) — say so rather than discovering it as a rendering failure; and if you add a script hash **and** `'unsafe-inline'`, modern browsers ignore `'unsafe-inline'`, which silently changes behavior in a direction people mis-predict. *Correction:* state the exact directive list, and treat the inline bootstrap (`:70-82`) with a build-time-computed SHA-256 script hash rather than `'unsafe-inline'`.

**F3 — Blocking. The enforcement test as written can be vacuous (plan `:24-25`).** Corrupting the committed hash and watching the script not load proves the *browser* implements SRI; it proves nothing about our artifact. *Correction:* keep the committed `integrity` value untouched; in a scratch copy point the `src` at a locally served asset, load once with genuine bytes (renders) and once with those bytes modified to set a sentinel (blocked, sentinel undefined, SRI console error). State the residual gap honestly: this does not prove jsDelivr's live response matches — F1 is what covers that.

**F4 — Should fix, cheap. The `</script>` hostile fixture is listed as a test, but no escape is proposed (plan `:26`).** A fixture without a code change just documents the break. *Correction:* escape `</script` → `<\/script` (or equivalent) in `$md` before concatenation at `:92`, plus HTML-escape `$title`; assert both in the fixture. This is 2–3 lines and does **not** require adopting a sanitizer or an XSS redesign — do not bundle DOMPurify here.

**F5 — Scope. Cut vendoring and pre-rendering explicitly.** Pre-rendering mermaid needs a headless browser and Node, which collides with meta-invariant #3 / WSD-073 (PowerShell-only, native Windows). Vendoring adds ~1 MB of minified third-party JS into `src/` and all three dists, plus licence/NOTICE obligations that `DocTruth.Tests.ps1:229-234` already checks for, `framework-ownership.json` entries, and a `no-meta-leak` scan over minified text. It also does not replace F1 — it moves the same provenance question to commit time. Per Maintenance model #6 that is not proportionate to a documentation viewer. Note the residual you accept: with SRI, a CDN outage means the page does not render at all (and a TLS-intercepting corporate proxy that strips CORS headers will also break it). Update the `<main>` fallback text at `:62` accordingly — it currently promises a degraded-but-working page.

**F6 — Evidence. Name what PS can and cannot prove, and keep the permanent additions PowerShell-only.** PS7/PS5.1 can prove: emitted tag bytes, exact pinned version strings, `integrity`/`crossorigin` present, CSP meta present, hostile fixture neutralized, deterministic LF/BOM output, all six pages byte-identical. They cannot prove any browser *enforces* anything, nor that mermaid still renders. So the browser leg is a one-time recorded observation (browser + version + `file://` and one hosted load), attached to the RCA — **not** a new Playwright/Node toolchain in CI. Red-test the new PS assertions by mutating the generator; `Invoke-MutationRedTest` (`DocTruth.Tests.ps1:325`) is the existing pattern.

**F7 — Consumer behavior, currently unstated.** `install.ps1:169-171` protects `docs/ARCHITECTURE.md` but **not** `docs/architecture.html`, which is therefore framework-owned/overwritten on update. Consequence: an updating consumer's page is replaced by the shipped one (generated from the *template* Markdown), the `docs-sync-check` advisory at `:150-157` then fires, and they regenerate with the fixed generator. So the fix does propagate — but the plan's "existing consumer pages also need regeneration" (`:28`) should say this mechanism explicitly, and the changelog must tell consumers in their own voice to re-run the generator. I did not see `framework-ownership.json` in this packet; the ownership class above is inferred from `install.ps1`, not read from the manifest.

## Smallest revised plan / acceptance contract

Generator-only change: exact pinned versions + `integrity` + `crossorigin="anonymous"`; `<meta>` CSP with an enumerated directive list and a build-time hash for the inline bootstrap; escape `</script` in `$md` and HTML-escape `$title`; update the fallback text. Accept when: (a) provenance record per F1 exists; (b) the F3 two-case browser observation is recorded with browser/version, both `file://` and one hosted load; (c) new PS assertions exist in `BuildArchitectureHtml.Tests.ps1` and were seen red under a generator mutation; (d) all six pages regenerated, `DocTruth` architecture freshness green, `validate-dist` ×3, suites under PS7 and native PS5.1; (e) CHANGELOG ×4 + RCA per meta-invariant #7 and Maintenance model #5.

## Inspected / not inspected

Read: `CLAUDE.md`, `meta/decisions-index.md`, `src/core/scripts/build-architecture-html.ps1`, `src/core/tests/hooks/BuildArchitectureHtml.Tests.ps1`, `.claude/hooks/tests/DocTruth.Tests.ps1` (architecture-freshness region), `src/core/scripts/docs-sync-check.ps1`, `src/core/scripts/install.ps1` (ownership region), `src/stacks/monorepo/files/docs/{ARCHITECTURE.md,architecture.html}`, `manifest.json`, `public-source-evidence.json`, `DEVELOPING.md:184-189`, the plan. Grepped all three stack `ARCHITECTURE.md` for script/HTML injection vectors.

Not available here: `framework-ownership.json`, the composer, `meta/workspace-decisions.md` and `meta/BACKLOG.md`, the test harness `_HookHarness.ps1`, the actual jsDelivr/npm bytes. **Everything above is inference from source text.** I executed nothing, opened no browser, and make no claim about what any browser or CDN actually did. This is a design critique, not release approval.
