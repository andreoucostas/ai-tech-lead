# Architecture viewer retirement: locked implementation design

Date: 2026-09-16. Baseline: `48d841642ab0ac92c9b39f5a0995af5d3f5438ad`, v0.86.7. Target: v0.87.0.
Tracks B-239. This is the re-locked design the prior three records asked for before implementation
(`meta/BACKLOG.md` B-239 "Next:", WSD-087). It supersedes the retention/hardening direction of
`2026-09-16-architecture-cdn-plan.md` for product purposes; that plan's controls remain the
fallback if retention is ever reselected.

Every line number below was read directly at this baseline by the author of this plan, not
inherited from the review records. Where a prior record's claim was checked and found wrong, that
is stated.

---

## 1. Premise re-validation

B-239 was filed today against v0.86.7, so the Maintenance-model-#1 staleness rule (re-validate an
entry filed more than ~5 minor versions ago) does not bite. The premise was nonetheless re-checked
against source rather than against the review narratives:

- `src/core/scripts/build-architecture-html.ps1:68-69` emits `marked@12` and `mermaid@10` from a
  CDN with no SRI and no CSP; `:70-82` executes inline JS. Confirmed present.
- The exposure reaches six committed pages: `src/stacks/{dotnet,angular,monorepo}/files/docs/architecture.html`
  and `dist/{dotnet,angular,monorepo}/docs/architecture.html`. Confirmed by glob.
- **Correction to my own earlier model and to the framing in the review trail:** this generator has
  no Markdown-producing path to preserve. It *reads* the hand-authored `docs/ARCHITECTURE.md` and
  emits only HTML (`:18-23`, `:92-94`). "Retire the generator, keep the Markdown" therefore means
  deleting the whole script; the Markdown is a protected consumer artifact that the script never
  wrote. A supporting agent proposed instead rewriting the `$tail` here-string to be inert, i.e.
  keeping the generator. That is rejected: it retains a generation step, a freshness contract and a
  second copy of the page for no remaining benefit.

No exploitation, compromise or browser behaviour was observed, then or now. The finding is a
source fact about unpinned third-party execution, nothing more.

## 2. Proportionality case (Maintenance model #6 / WSD-034)

The already-observed harm is real and shipped: six committed pages in all three distributions
execute floating, unpinned third-party script in a reviewer's browser with no integrity or policy
control. The materially smaller fix — exact version pins plus SRI, without CSP or embedding work —
was compared and does close the byte-substitution gap; it is rejected not on correctness but
because retention converts a one-time repair into a standing obligation to re-earn browser
evidence on every dependency bump, in a repository whose evidence regime is PS7 + PS5.1 with no
browser leg, whereas retirement costs one migration and one static file that can never fetch
anything.

Qualification, per root correction #8 in the Opus retirement review: this is a
reduced-ongoing-responsibility argument. The absence of a browser CI leg does not by itself decide
product necessity, and browser evidence is not forbidden — it is simply not required by anything in
this design, because the stub's inertness is a byte fact.

## 3. Adversarial critique (pre-lock)

Recorded as required by Maintenance model #1, licensed to reject the premise.

- **C1 — Does the viewer carry value that retirement destroys?** Yes, a real one: direct
  browser rendering of Mermaid diagrams, which the framework itself instructs
  (`REVIEW-GUIDE.md:12`). Retiring it loses that. Accepted with explicit disclosure in the stub and
  both changelogs. Not refuted: no evidence establishes non-use, and no substitute was verified on
  any consumer host. `README.md:157` is *not* consumer evidence — `install.ps1:164` excludes
  `README.md` from install — but REVIEW-GUIDE and the protected ARCHITECTURE.md preamble are.
- **C2 — Is deletion of the installed page a viable alternative to a stub?** No, and this is the
  load-bearing reason the stub exists. Ledger deletion requires previous framework ownership *and*
  a recognized digest (`install.ps1:294-331`); a hash miss preserves the file (`:326-330`).
  Consumer pages are regenerated from *their* ARCHITECTURE.md, so their bytes are unknowable, and
  deletion would preserve precisely the at-risk files. Ordinary overwrite reaches them;
  ledger retirement does not. "Simply delete" is struck from the option set on this evidence.
- **C3 — Can one path be both overwritten and retired?** No. `install.ps1:212` throws if a ledger
  path is still in the incoming ownership manifest, and `build.ps1:428-431` fails the compose for
  the same reason. Hence two different contracts for two different paths (§4).
- **C4 — Does the stub's reader path depend on behaviour I cannot verify?** It must not. The stub
  gives the destination as text *and* a relative link, with no redirect, no script and no external
  resource, so the instruction survives regardless of how `file://` navigation behaves.
- **C5 — Am I over-building?** The single marginal item is the `framework-doctor.ps1` residue list
  (§5.6). It is one array entry plus one focused test case; the doctor is the consumer's on-demand
  diagnostic and would otherwise stay silent about the generator forever. Included, flagged as the
  one item a reviewer could reasonably cut.
- **C6 — What breaks silently that no prior record identified?** One thing, found only by reading
  the installer at this baseline: `install.ps1:719-723` builds the `.sh` twin's migration
  replacement *only if* the corresponding `.ps1` is still in the incoming ownership manifest.
  Retiring the `.ps1` makes that condition false, so `scripts/build-architecture-html.sh` — retired
  since 0.83.0 — **silently loses its existing MIGRATION diagnostic**. This change would have
  removed a working consumer diagnostic as a side effect. Fixed explicitly in §5.4.

## 4. The locked contract

Two paths, two different mechanisms. This separation is the whole design.

| Path | Mechanism | Authority |
|---|---|---|
| `docs/architecture.html` | **Ordinary overwrite.** Stays in `framework-ownership.json` as `framework-owned/overwritten`; replaced through the normal apply path. | `install.ps1:1000-1017` |
| `scripts/build-architecture-html.ps1` | **Ledger retirement.** Hash-gated deletion; unknown/modified bytes preserved with `CANT-VERIFY`. | `install.ps1:294-331` |
| `docs/ARCHITECTURE.md` | **Untouched.** Protected + copy-if-absent; byte-preserved on every update. | `install.ps1:169-171`, `:180-182` |

`framework-ownership.json` is **generated** from the composed tree (`build.ps1:377-412`), so
deleting the generator removes it from all three manifests automatically and the stub retains its
`framework-owned/overwritten` classification automatically. No manifest is hand-edited. (A
supporting agent reported a `src/core/framework-ownership.json` source file; verified by glob —
**it does not exist**.)

### 4.1 The stub

Authored **once** at `src/core/docs/architecture.html`, composing to all three dists. The three
stack whole-file overrides are deleted, removing the monorepo-sibling hazard. `src/core/docs/`
already exists and demonstrably composes to `dist/*/docs/` (`upgrade-checklist.md`,
`enforcement-surfaces.md` verified present in `dist/dotnet/docs/`).

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Architecture — see docs/ARCHITECTURE.md</title>
<style>
  body { font-family: -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
         line-height: 1.6; max-width: 42rem; margin: 0 auto; padding: 2rem 1.25rem; }
  code { font-family: ui-monospace, SFMono-Regular, Consolas, monospace; }
</style>
</head>
<body>
<h1>This generated view is retired</h1>
<p>This page is no longer generated. It used to load its Markdown and diagram renderers from a
third-party content delivery network each time it was opened, which this framework no longer
ships.</p>
<p><strong>Read <code>docs/ARCHITECTURE.md</code> instead.</strong> It is the canonical source and
is unchanged. Open it in your editor or your Git host, which display the Mermaid diagrams this page
used to render.</p>
<p><a href="ARCHITECTURE.md">docs/ARCHITECTURE.md</a></p>
<p>This file remains only so existing links and bookmarks do not break, and is safe to delete.</p>
</body>
</html>
```

Contract: no `<script`, no `http://` or `https://`, no `http-equiv`, no `<iframe`/`<object`/`<link`,
no embedded Markdown, no external asset, no automatic navigation. Diagram loss is stated on the
page itself.

### 4.2 The ledger entry

Inserted at line 26 — immediately **before** the existing `.sh` entry, because
`build.ps1:179` requires strict ordinal path order and `.ps1` < `.sh` (`p` 0x70 < `s` 0x73) — into
**both** `src/core/framework-retirements.json` and `meta/framework-retirements-baseline.json`.
`B215OwnershipBoundary.Tests.ps1:245` requires the two files to be **byte-identical**, which is
stricter than the composer's entry-wise comparison at `build.ps1:434-450`.

```
    {"path":"scripts/build-architecture-html.ps1","retired-in":"0.87.0","known-content-sha256":["6b718b5145c8736d0d2ca07774eaf0b15c69e9b00791d1c516ee4a091d9acc7d","bbc5768ce40ace37a8a4b684b667d5b5e9ab9022bef8293f04a7c8ab28519d37","e2496db04812f40cc06b96a45d12b6a20b26f7cf9c16e3b60161bd10ab7fc69d","eb9cbed662dd35a2a23ff4c0f42e82819d256786a3ac1c16b6aa55da73f75df8"]},
```

**Digest provenance (observed, not assumed).** Enumerated across all 93 release tags plus HEAD ×
all three `dist/*/scripts/build-architecture-html.ps1` paths: 4 distinct blobs, SHA-256 computed
from raw bytes via `git cat-file` with byte-exact redirection. Hashes are lowercase 64-hex in
strict ordinal ascending order, satisfying `build.ps1:184-186`.

**Boundary, disclosed:** `git log --all -- scripts/build-architecture-html.ps1` returns **0**
revisions — this repository carries no pre-merge history for the legacy repo path. Consumers who
installed from the archived `ai-tech-lead-dotnet`/`-angular` repos (v0.25.5 and earlier) may hold
generator bytes not in this set. They will receive `CANT-VERIFY` and the file will be **preserved**,
which is the safe direction and exactly what the machinery is for. This is a known, accepted gap,
not an oversight.

## 5. Change surface

### 5.1 Delete
- `src/core/scripts/build-architecture-html.ps1`
- `src/stacks/{dotnet,angular,monorepo}/files/docs/architecture.html` (3)
- `src/core/tests/hooks/BuildArchitectureHtml.Tests.ps1`

### 5.2 Create
- `src/core/docs/architecture.html` (§4.1)

### 5.3 Test-runner manifest — hard dependency
`src/core/tests/hooks/Invoke-HookTests.ps1:34` — remove `'BuildArchitectureHtml.Tests.ps1'` from
the hardcoded `$expectedTestFiles` manifest. Drift detection at `:60-65` fails with exit 2 on
*either* a missing or an unexpected file, so deleting the test without this edit breaks the shipped
suite in all three dists.

### 5.4 Installer diagnostics — three edits, `src/core/scripts/install.ps1`
1. **Residual predicate `:674`** — admits only GitHub skills, retired sync scripts, git-hook
   helpers and `retired-in == '0.83.0'`. A 0.87 retirement is diagnosed on the *first* update only;
   a consumer-modified generator preserved at `:326-330` then goes silent forever. Add the one path.
2. **Residual message `:695-700`** — the generic branch would tell a reader to "migrate references
   to 'the supported PowerShell surface'", which is false: there is no replacement. And the generic
   `.sh`→`.ps1` mapping at `:696-698` would point at the now-retired `.ps1`. Add explicit branches
   for both paths directing readers to canonical `docs/ARCHITECTURE.md`.
3. **`$retiredReferenceReplacements` `:712-725`** — add an explicit entry for the `.ps1`, **and**
   an explicit entry for the `.sh` twin, which otherwise loses its existing diagnostic (C6). These
   feed the protected-carrier scan at `:775-798`, which is how a consumer whose protected
   `docs/ARCHITECTURE.md` still says "run `scripts/build-architecture-html.ps1`" gets told.

Diagnostics only. No new deletion authority is granted anywhere.

### 5.5 Live callers and gates
- `src/core/scripts/docs-sync-check.ps1:150-157` — delete check 7 entirely (its NOTE names the
  retired script; the whole freshness concept dies with the generator).
- `src/core/.claude/commands/impact.md:39` — delete the sentence offering HTML rendering.

### 5.6 Doctor (the marginal item, C5)
- `src/core/scripts/framework-doctor.ps1:202-221` — add `scripts/build-architecture-html.ps1` to
  `Get-RetiredFrameworkResidueResult`'s list (19 entries).
- `src/core/tests/hooks/FrameworkDoctor.Tests.ps1` — leave the existing 18-path v0.83 case and its
  `-eq 18` assertion **unchanged**, and add a *separate* focused case for the new path. Bumping the
  v0.83 case to 19 would conflate two retirement generations — the same error root correction #6
  flagged for the UpdateDelivery fixture.

### 5.7 Shipped documentation (×3 stacks, 12 files)
- `README.md` (`:157`/`:158`/`:160`) — the `docs/ARCHITECTURE.md (+ architecture.html)` row.
- `docs/REVIEW-GUIDE.md` `:12` (reading order), `:21` (docs-sync claim "architecture.html is
  fresh"), `:34`/`:35` (generated-files-lag list).
- `docs/ARCHITECTURE.md` — `:4` (preamble), `:5` (Generated view), `:65` (file table row),
  `:167-170` (CI guardrail claim), `:189-192` (repo map line), `:198-201` (regenerate footer).
  Protected on update, so these bytes reach **new installs only**; existing consumers are served by
  §5.4.3.
- `CHANGELOG.md` ×3 — new `## 0.87.0 — Unreleased` head in the consumer's voice.

### 5.8 Maintainer records
- `meta/framework-retirements-baseline.json` (§4.2, byte-identical)
- `.claude/hooks/tests/DocTruth.Tests.ps1` — replace, do not delete (§6.2)
- `.claude/hooks/tests/UpdateDelivery.Tests.ps1` — new focused cases (§6.3)
- `meta/gate-redtest-coverage.md:67` — the row citing the generator and its removed test
- root `CHANGELOG.md` — `## 0.87.0 — Unreleased` head (invariant #7 requires all four heads before
  `release.ps1` will stamp)
- `meta/BACKLOG.md` B-239 + delivery RCA; `meta/workspace-decisions.md` WSD-088;
  `meta/LEARNINGS.md` append

## 6. Verification contract

Instruments must be seen red on the unfixed tree before any green is accepted (Maintenance
model #4). Every suite runs directly under PS7 **and** native Windows PowerShell 5.1.

### 6.1 Compose and gates
`build.ps1 <dist>` ×3 → `git status --porcelain dist/` empty; `validate-dist.ps1 <dist>` ×3.

**Honest scope of `no-dead-instruction` (verified, not assumed).** Opus treated this check as
"expected, not observed". Read at `validate-dist.ps1:557`: the extractor requires a leading
`pwsh|bash|powershell` token. It therefore catches `ARCHITECTURE.md:199`
(`pwsh -NoProfile -File scripts/build-architecture-html.ps1`) and will go red if that line is
missed — a genuine net. It does **not** catch `impact.md:39` (no interpreter token) or the repo-map
line at `:190`. This gate is a partial net; §5.5 and §5.7 are not covered by it and must be
verified by inspection.

### 6.2 Replacing DocTruth's architecture case
`Get-ArchitectureFreshnessViolations` (`:244-281`) and its `It` (`:317-320`) currently re-run the
generator and compare CR-normalized text across six copies. With the generator gone the function
cannot exist. Replace — never merely delete — with a **fixed literal page contract**: exact byte
equality of all four committed copies (`src/core/docs/architecture.html` + three
`dist/*/docs/architecture.html`) against the expected stub, plus explicit existence and count
assertions so an empty or missing input fails rather than passes.

Per Opus correction #4, a token deny-list is **not** used: it is not a complete no-fetch oracle
(`<img src="relative.png">` contains none of the listed tokens and still specifies a resource).
Exact bytes are the oracle. Comparing source to copies alone is also rejected — it would accept a
uniformly unsafe change.

The replacement must preserve the existing "could not examine" versus "is wrong" distinction that
`:259` and `:275` already implement (meta-invariant #7).

**Red-tests:** plant a `<script>` line into one copy; separately plant an unlisted resource
(`<img src="x.png">`); separately remove one copy. Each must go red with a message naming which of
the two failure kinds occurred. Then the clean pass.

### 6.3 Installer behaviour, PS7 and PS5.1
New focused cases in `UpdateDelivery.Tests.ps1`, kept **separate** from the v0.83 18-path fixture
at `:964-1008` (whose `-eq 18` cardinality assertion stays untouched):
1. Pre-existing CDN-bearing `architecture.html` + modified `ARCHITECTURE.md` → plan shows
   `replace docs/architecture.html`; post-apply bytes equal the shipped stub; `ARCHITECTURE.md`
   byte-identical (idiom at `:372-375`); preview and apply classify identically.
2. Generator at a **known** digest → deleted.
3. Generator at a **modified** digest → preserved, with `CANT-VERIFY` naming the path.
4. **Missing / malformed** previous ownership manifest → no deletion at all (`:282-292`).
5. A protected `docs/ARCHITECTURE.md` naming the retired generator → `MIGRATION:` line on the
   first update **and** residual diagnosis on later updates (the `:674` fix).
6. The `.sh` twin still receives its migration message (C6 regression guard).

### 6.4 Suites
`dist/<d>/tests/hooks/Invoke-HookTests.ps1` ×3 (must report a nonzero case count and the expected
manifest after the §5.3 edit); meta suite `.claude/hooks/tests/Invoke-HookTests.ps1` including
`InstallerContract` and `DocTruth`; BOM and PS-AST sweeps.

### 6.5 Release
Four changelog heads at 0.87.0 before `release.ps1` (invariant #7); CI green on the first run is
part of done, not after it.

## 7. Boundaries — what this design does not claim

- No browser evidence is produced or needed; stub inertness is a byte fact, not a rendering claim.
- No claim that Mermaid renders on any particular consumer host. The stub's link is convenience,
  not a guarantee.
- Brownfield collisions are **archived** to `docs/pre-adoption/docs/architecture.html`
  (`install.ps1:873-907`) — relocated, not removed. Disclosed, never auto-deleted.
- `/impact` custom outputs (`impact.html` and arbitrary `[src] [out] [title]` renders) are never
  installed and are **not** repaired by this change. Guidance only; no arbitrary report is deleted.
- Unupdated installations remain exposed under every option, including this one.
- Pre-merge legacy-repo generator bytes are unknown (§4.2) and will be preserved, not deleted.
- No installer redesign, no generic HTML sanitizer, no browser CI leg, no usage study.

## 8. Independent review

Required before release under Maintenance model #2: separate session, no implementation
participation, starting from this frozen contract and the immutable baseline. This change is
capable of false-green enforcement behaviour (a retirement diagnostic that goes silent) and of
consumer file deletion, so it falls in the class requiring a second orthogonal reviewer or
execution vantage; absent that, incomplete coverage is recorded and review debt filed.
