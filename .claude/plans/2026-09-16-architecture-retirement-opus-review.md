# Architecture viewer: Opus review of retirement

Date: 2026-09-16. Frozen baseline: `fad1063f1c4d97a3469ee4b10c316bcc707bda52`, v0.86.7.
The user requested Opus review of the current proposal and explicitly authorized sending the
necessary data. This records design review, not product implementation or release approval.

## Review receipt

Root sent a frozen, read-only packet of 38 repository files: the original finding and proposal,
both previous reviews, authoring constraints, generator, installer, retirement authorities,
ownership manifests, caller, documentation, generated pages and relevant existing tests. Every
packet copy was SHA-256 checked against the clean baseline. The prompt required a source-first
threat/value assessment before prior verdicts and comparison with minimal pins/SRI as well as
larger hardening. Usage, substitute rendering and runtime behavior were explicitly unknown.

The fresh Claude Code 2.1.260 session initialized as `claude-opus-5`, session
`8308db06-6b3e-4fb8-be57-a1543621ab5b`, using only Read/Glob/Grep, `dontAsk`, safe/restricted
mode, no MCP tools, slash commands, persistence or fallback model. The native exit was 0 and the
structured result was `success`, `is_error: false`, 20 turns, 342617 ms. Reported total cost was
USD 1.7904025; model accounting included USD 1.7882325 for Opus and USD 0.00217 for a Haiku
auxiliary call. This does not change the observed reviewer identity. No browser, installation,
build, mutation or product edit was performed by the reviewer.

SHA-256 receipts:

- Packet manifest: `6D167FB5C17394BBA2A292DF7DB0474AD3D7F9B7D065908CC26A3DCFD6EA0735`.
- Reviewed Astra proposal: `8AB5C0737276764B48F2D8CAF8D197AA53A3CCCD8498BACAADF97E89C0511420`.
- Dispatch prompt: `7D64D71BC8B36AD9D2F83A90016327AEF94FC1C346084E49C474AC3B31CE82AC`.
- Original response: `E32CBD2771F4E8A47D3D4F798976D719448B716F025DE6A7A7F5B270AE3217A1`.
- Completed stream: `865A6AB180CC99A89831C9D8324C07B4EB01BC6591D03D3F7E1F50282E17E06A`.

## Root disposition

**Accept retirement as the preferred direction; revise the transition and verification details.**
Opus agrees with Astra on the product premise and returns REVISE on scope. The original CDN
finding remains valid. The viewer adds presentation convenience, including direct browser diagram
rendering, but no separate knowledge. No evidence establishes non-use, lack of value or equivalent
rendering on every consumer host. Retiring it removes an ongoing dependency, embedding and browser
verification responsibility; it is not necessarily the smallest initial patch. Exact pins/SRI
remain a smaller retained-viewer repair to later byte substitution, with the previously recorded
input and rendering boundaries. The recommendation weighs the ongoing responsibility against a
documented convenience; it does not claim observed exploitation or measured maintenance savings.

Root rechecked installer branches, composer ledger rules, callers, documentation and test scopes.
A supporting agent independently checked the disputed lifecycle/test claims; this was source
corroboration, not another release review. Accept Opus's concrete findings with these corrections:

1. **Keep the HTML pathname as an ordinary overwritten compatibility page.** Deletion-only cannot
   neutralize consumer-regenerated pages with unknown hashes or updates lacking a valid prior
   ownership manifest. `install.ps1:276-333,1000-1017` distinguishes conservative retirement from
   ordinary replacement. Preserve `docs/ARCHITECTURE.md` bytes. A brownfield collision is archived
   under `docs/pre-adoption/` (`:873-907`), so old active content may survive there. Custom/impact
   reports and unupdated installations remain outside default-path replacement; provide useful
   migration guidance without deleting arbitrary reports.
2. **Diagnose both generator extensions cumulatively.** Add specific guidance for
   `scripts/build-architecture-html.ps1` and its already-retired `.sh` predecessor to the existing
   protected-reference and residual-warning branches (`install.ps1:664-725`). Otherwise the PS1
   reference is silent, and the SH residual message points at the now-retired PS1. Messages should
   direct readers to canonical Markdown and explain retirement. Extend the residual predicate
   narrowly; diagnostics grant no new deletion authority. Source and maintainer retirement JSON
   must carry matching cumulative entries/hashes (`scripts/build.ps1:434-450`), an existing rule
   not inspected by Opus. Known historical generator hashes must be verified before use.
3. **Keep the common page small and readable.** Author once at `src/core/docs/architecture.html`,
   remove three stack overrides and compose three dist copies. Include a textual editor/Git-host
   instruction and relative Markdown link; no runtime, embedded Markdown, external assets or
   automatic navigation. The link is convenience, not a guarantee of local Markdown rendering.
   Disclose loss of the direct diagram view. A supported-host rendering observation can refine
   viewing advice; a broad product study is unnecessary.
4. **Correct the proposed security oracle.** Opus's deny list is not a complete no-fetch check:
   `<img src="relative.png">` lacks every listed token and still specifies a resource. The
   [HTML standard](https://html.spec.whatwg.org/multipage/images.html) documents declarative image
   fetching. Prefer exact bytes against a separately reviewed fixed literal page contract across
   the shared source and all three dists, with explicit expected file existence/count. Do not
   compare only source to copies, which would accept a uniformly unsafe change. Red-test a script
   and an unlisted resource insertion, then the exact clean page. This is a bounded contract for
   one fixed document, not a general HTML sanitizer or browser observation. A focused browser
   smoke can demonstrate actual navigation/request behavior if that behavior is claimed.
5. **Do not set an automatic stub-removal release.** Knowing the stub's hash permits deletion of
   that stub later, but does not address a direct upgrade from a vulnerable release that skipped
   the transition, unknown regenerated pages, or missing manifests. Retain the tiny page while
   direct legacy upgrades are supported. Future removal needs an explicit change to that upgrade
   promise or another demonstrated migration route; known stub bytes alone are insufficient.
6. **Keep tests and callers within the actual scope.** Replace only DocTruth's architecture
   helper/case, not its unrelated checks through line 320. Consolidation changes six historical
   HTML copies to one source plus three dists. Retire generator-specific tests; remove the
   docs-sync source-hash advisory and live `/impact` render instruction; update stack review and
   architecture guidance. The v0.83 fixture/count at `UpdateDelivery.Tests.ps1:964-1007` specifically
   tests those 18 historical paths; add a focused new-retirement case instead of calling it 19
   v0.83 paths. `framework-doctor.ps1` has a separate bounded legacy list, so changing an installer
   test does not establish doctor coverage. No general doctor/installer redesign is proposed.
7. **Correct evidence descriptions.** The distributed README is excluded from consumer install
   (`install.ps1:164`), as Opus notes; it still guides repository readers. Installed human pointers
   exist in REVIEW-GUIDE and protected ARCHITECTURE.md. Astra's `impact.md:32,39` cites the Markdown
   output and optional renderer respectively; line 32 does resolve. Its older baseline is expected:
   `fad1063` records that review of `0ca6257`. Neither is evidence of stale product source here.
   `validate-dist` scans specified command/link forms in shipped documentation, not every possible
   mention or existing consumer file. Its behavior on this future change must be observed.
8. **Qualify the evidence-topology argument.** PS7/PS5.1 are required execution hosts, not a ban
   on browser evidence. `CLAUDE.md:248-256` does not force retirement or require a new generic CI
   leg. Retention's browser-sensitive behavior needs relevant browser evidence when changed;
   static source facts can also be verified without a browser. Reduced ongoing responsibility
   supports retirement; the current CI topology alone does not decide product necessity.

## Bounded next direction

The reviews now support a concrete retirement contract: common inert compatibility page delivered
by ordinary overwrite; separate content-qualified generator retirement; preserved Markdown;
cumulative actionable warnings for both generator paths; updated callers, advice and checks.
Existing retirement machinery is sufficient with narrow diagnostic/data changes. No further paid
design review, generic HTML parser, installer redesign or broad usage study follows automatically.

Implementation acceptance must demonstrate on direct PS7 and PS5.1: unsafe default HTML replaced
with exact inert bytes; protected Markdown unchanged; matching preview/apply classifications;
known generator deletion; modified generator preservation and warnings on first/later updates;
missing/malformed ownership manifests preserving deletion limits; both obsolete generator
references diagnosed; and honest archive/custom-report guidance. Show focused red/clean controls,
composition and required release gates. Obtain independent implementation evidence under the
existing policy. These are proposed checks, not results of this review.

## Planning verification

Root ran the existing BacklogHygiene suite directly under PS7 and native PS5.1: each reported
10 passed, 0 failed, 0 skipped, exit 0, including its positive/negative consistency fixtures.
The suite's advisory candidates were existing unrelated entries. Root verified all 38 frozen
packet hashes and exact preservation of the original response below; `git diff --check` passed
and `src/`/`dist/` had no changes. These verify review records, not the proposed migration.
The preceding Astra-record commit's CI was observed complete: run `35093073163`, all eight
required Windows execution jobs and parity green. This is not CI evidence for this new commit.

## Original Opus report (verbatim)

## Verdict

**REVISE — accept the product premise (retire the runtime viewer), revise the scope.** The retention→retirement shift is justified, but for a reason neither prior record states, and the proposal is missing three installer/gate items that decide whether it delivers what it claims.

## Artifact value and necessity

The HTML adds **no information**: `src/core/scripts/build-architecture-html.ps1:92` concatenates `$md` verbatim between a fixed head and tail, so the page *is* `docs/ARCHITECTURE.md` plus a renderer. Its only value is presentation — Mermaid rendering and styling.

That value is not fictional and is not refuted by "agents don't read it." The framework *instructs* the human path: `src/stacks/dotnet/files/docs/REVIEW-GUIDE.md:12` ("open `docs/architecture.html`"), `.../docs/ARCHITECTURE.md:4-5,65`. Correction to Astra's evidence: `README.md:157` is **not** consumer evidence — `README.md` is in `$excludedFromInstall` (`install.ps1:164`) and absent from `dist/dotnet/framework-ownership.json`, so it never reaches an installed repo. The installed human pointers are REVIEW-GUIDE:12 and the protected ARCHITECTURE.md preamble.

Substitutes are **plausible, not demonstrated**. Nothing in the packet shows Mermaid rendering on any supported host; the enterprise host the framework actually names is Bitbucket Data Center (`docs-sync-check.ps1:2-3`). I make no claim about browser or editor capability.

The decisive argument for retirement is neither usage nor substitutes — it is **evidence topology**. SRI/CSP/pin correctness is only observable in a browser. This repo's evidence regime is PS7 + PS5.1 (`CLAUDE.md:255-256`: "Where a required host cannot execute, that host has no evidence"), and there is no browser leg. Retention converts a one-time fix into a **permanent obligation to re-earn browser evidence** on every dependency bump, plus an ongoing input-handling contract over consumer-authored Markdown (the `</script>` class, since embedding is verbatim). Retirement's cost is one-time migration and one static file. That asymmetry — ongoing responsibility, not initial effort — carries the proportionality case (Maintenance model #6).

## Prioritized findings

**1. High — deletion is not a viable alternative; this must be stated as the reason the stub exists.** Ledger deletion requires previous framework ownership *and* recognized bytes (`install.ps1:294-331`); a hash miss preserves the file (`:326-330`). Consumer pages are regenerated from *their* ARCHITECTURE.md, so their bytes are unknowable. Deletion would therefore preserve exactly the at-risk files. The stub works because `docs/architecture.html` is `framework-owned/overwritten` (`dist/dotnet/framework-ownership.json:85`) and lands through the ordinary replace path (`install.ps1:1000-1017`). Keep the stub; drop "simply delete" from the option set on this evidence.

**2. High — retiring a `.ps1` produces no protected-carrier migration message.** `install.ps1:712-725` builds `$retiredReferenceReplacements` only for `setup-git-hooks`, the Bitbucket sample, and a generic **`.sh`-only** branch (`:719`). `docs/ARCHITECTURE.md` is protected (`:169-171`), never overwritten on update, and says at `:199` "Regenerate the HTML … `scripts/build-architecture-html.ps1`". Without an entry, the scan at `:775-797` stays silent and every updated consumer keeps a live instruction to run a deleted script. Smallest correction: one `elseif` beside `:717`, e.g. `$retiredReferenceReplacements['scripts/build-architecture-html.ps1'] = 'the generated HTML view is retired; read docs/ARCHITECTURE.md directly'`.

**3. High — later-update residual diagnostics won't cover this retirement.** The residual loop's predicate (`install.ps1:674`) admits only GitHub skills, retired sync scripts, git-hook helpers, and `retired-in == '0.83.0'`. A 0.87-era generator retirement is diagnosed on the first update only; a consumer-modified generator preserved at `:326-330` goes silent thereafter. Smallest correction: add the one path to that predicate, and extend the fixture list/cardinality at `UpdateDelivery.Tests.ps1:969-985` (currently pinned at 18).

**4. Medium — the stub's reader path must not depend on browser behavior I cannot verify.** Give the path as **text plus** a relative link ("Open `docs/ARCHITECTURE.md` in your editor or Git host"), so the instruction survives regardless of how `file://` navigation behaves. No JS, no embedded Markdown, no external resource, no `<meta http-equiv="refresh">`.

**5. Medium — exposure removal is real but bounded; say where it isn't.** Brownfield archives a colliding pre-existing page to `docs/pre-adoption/docs/architecture.html` (`install.ps1:873-907`) — correct no-loss policy, but it *relocates* rather than removes. `/impact` custom outputs (`impact.md:39`; generator params `build-architecture-html.ps1:18-20`) are never installed and are untouched. Unupdated installs stay as-is. Guidance only — never propose deleting reports or consumer Markdown.

**6. Medium — live callers/gates to change.** `docs-sync-check.ps1:150-157` (delete check 7; its NOTE names the retired script); `impact.md:39` (delete the sentence); `REVIEW-GUIDE.md:12,21,34-35` ×3; `ARCHITECTURE.md:4-5,65,190,199` ×3 (protected — new installs only, hence finding 2); `src/core/tests/hooks/BuildArchitectureHtml.Tests.ps1:8-43` retires with the generator; `DocTruth.Tests.ps1:244-320` must be **replaced, not deleted**. Six committed pages carry the CDN bytes (`src/stacks/*/files/docs/architecture.html` and `dist/*/docs/architecture.html`, lines ~234-239). `framework-retirements.json:26` already retired the `.sh` twin — the ledger mechanics are in use and need no new machinery.

**7. Low — leanness.** The stub is stack-independent; author it once at `src/core/docs/architecture.html` instead of three whole-file overrides, removing the monorepo-sibling hazard (`CLAUDE.md:55-58`).

**8. Low — define the stub's lifetime now.** Removal condition: once shipped, its bytes are framework-known, so a later release may move it to the ledger (it cannot be in both — `install.ps1:212`), where modified copies are preserved automatically. State the condition in the plan; don't leave it open-ended.

## Preferred direction and acceptance boundary

Lock: inert stub at `docs/architecture.html` + separate ledger retirement of the generator + canonical Markdown preserved. Minimum non-vacuous controls, all PS-observable:

- **Inertness over all six committed copies** — no `<script`, no `http(s)://`, no `http-equiv`, no `<iframe|object|link`; red-tested by planting one script line. This replaces DocTruth's freshness test. Byte inspection is a *complete* oracle for "fetches nothing"; no browser is needed and none should be claimed.
- **Update fixture, PS7 and PS5.1**: pre-existing CDN-bearing `architecture.html` + modified `ARCHITECTURE.md` → `PLAN replace docs/architecture.html`, post-apply bytes equal the shipped stub, `ARCHITECTURE.md` byte-identical (`UpdateDelivery.Tests.ps1:372-375` idiom), stdout contains the MIGRATION line from finding 2.
- **Generator retirement fixtures**: known bytes deleted; modified bytes preserved with a `CANT-VERIFY` naming the path; missing/malformed previous manifest → no deletion (`install.ps1:282-292`).
- **Composer**: `validate-dist`'s `no-dead-instruction` should go red on any missed doc reference — *claimed by `CLAUDE.md:268-270`; `validate-dist.ps1` is not in this packet, so treat as expected, not observed.*

**This is sufficient to proceed to a bounded implementation contract**, with one unresolved product choice that does not require a study: confirm on your own supported host whether Bitbucket Data Center / your editor renders Mermaid for the REVIEW-GUIDE:12 flow. If not, retire anyway but state the loss plainly in the stub and CHANGELOG — ARCHITECTURE.md stays readable as text either way.

## Evidence and gaps

Inspected: root `CLAUDE.md`; `build-architecture-html.ps1`; `install.ps1` (full); `framework-retirements.json`; `docs-sync-check.ps1`; `impact.md`; `upgrade-checklist.md`; three ARCHITECTURE.md/architecture.html pairs + dist copies; three README/REVIEW-GUIDE; `dist/dotnet/framework-ownership.json`; `DocTruth.Tests.ps1`, `UpdateDelivery.Tests.ps1`, `BuildArchitectureHtml.Tests.ps1`; both prior plan records (read last). Not inspected: `validate-dist.ps1`, composer, other dists' ownership manifests. Not performed: any execution, install, build, browser, or network action; no runtime, rendering, usage or user-value observation. Astra's `impact.md:32` citation did not resolve in this packet (the reference is at `:39`); its baseline commit `0ca6257` differs from the stated `fad1063`, so its line numbers are corroborated here only where I re-checked them. Prior reviewers' conclusions are treated as input, not authority. No release or implementation approval is claimed.