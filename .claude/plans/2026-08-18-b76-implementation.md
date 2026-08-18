# B-76 — implementation record

**Delivered:** `.claude/hooks/tests/DocClaims.Tests.ps1` (new, meta-only, no twin per WSD-005).
**Design:** `.claude/plans/2026-08-18-b76-doc-claims-gate-design.md` rev 2.
**Implemented by** codex `gpt-5.6-sol` against the locked rev-2 spec. **All verification below was
run by the reviewer**, not taken from the implementer's report — the implementer's run was cut off
by a tool timeout before it wrote one, so there is no self-report to trust or distrust here.

## What it asserts

Two assertions over all three dists:

1. **Contract** — for each of six registered claim rows: the claim file exists **and still contains
   the claim text** (a claim reworded away fails; that is the vacuity direction), and the command it
   names contains the required phrase, or has the required top-level step count. `Get-MarkdownBody`
   strips frontmatter before searching, so the `rebootstrap` row tests the *body* — which is exactly
   the historical defect, where the promise lived only in the description.
2. **Completeness** — any line matching a narrow maintenance-claim grammar that is not in the
   registry fails the suite. `CHANGELOG.md` excluded by name, following `DocTruth.Tests.ps1:37`.

## Verification (reviewer-run; command → observed output)

**Green anchor, both hosts** — B-141 had just proved this directory diverges between them:

```
pwsh 7                     DocClaims.Tests: 2 passed, 0 failed, 0 skipped   EXIT=0
Windows PowerShell 5.1     DocClaims.Tests: 2 passed, 0 failed, 0 skipped   EXIT=0
BOM                        efbbbf
```

**All six `-RedTest` arms observed red**, each with a specific message:

| arm | exit | message |
|---|---|---|
| `broken-contract` | 1 | `.claude/commands/demo.md lacks 'Needle'` |
| `missing-claim` | 1 | `claim text is missing … "Thing" is updated by /demo` |
| `wrong-step-count` | 1 | `expected 3, found 2` |
| `unregistered-claim` | 1 | `unregistered command-maintenance claim … "Extra" is maintained by /other` |
| `vacuous-registry` | 1 | `registry is empty -- contract check is vacuous` |
| `vacuous-grammar` | 1 | `zero attribution claims -- completeness grammar is vacuous` |

**These arms run against a synthetic fixture, so on their own they prove the assertion functions
work and nothing more.** `ValidateDist.Tests.ps1`'s own header records that synthetic fixtures
previously hid false greens here. The test that decides whether this closes B-76 is the next one.

**The three historical defects, reconstructed in a scratch copy of `dist/dotnet`** (working tree
never mutated; every mutation asserted to have actually changed the file before the run, per B-84):

```
baseline on the untouched copy                                    2 passed, 0 failed   EXIT=0
defect 1  docs-sync loses "Detected Framework Packages"   CAUGHT  EXIT=1
          -> broken claim contract in dotnet/FRAMEWORK-CONTEXT.md:
             .claude/commands/docs-sync.md lacks 'Detected Framework Packages'
defect 2  rebootstrap body loses every hazard mention     CAUGHT  EXIT=1
          -> broken claim contract in dotnet/FRAMEWORK-CONTEXT.md:
             .claude/commands/rebootstrap.md lacks 'Known Hazard Areas'
defect 3  prompt claims four steps, not six               CAUGHT  EXIT=1
          -> claim text is missing in dotnet/.github/prompts/docs-sync.prompt.md: all six steps
copy restored                                                     2 passed, 0 failed   EXIT=0
```

All three. This is the evidence that the gate closes the entry rather than something adjacent.

**Completeness grammar audited for precision.** Six provenance/routing phrases that must not be
read as maintenance claims — `Auto-populated by /bootstrap`, ``Used by `/review` ``,
``Managed by `/security-review` ``, ``drafted by `/bootstrap` ``, ``spawned by `/review` ``,
``Invoked in parallel by `/bootstrap` `` — **none matched**. Live yield across all three dists is
**9 hits, all genuine**, all registered:

```
[dotnet|angular|monorepo] FRAMEWORK-CONTEXT.md  "Detected Framework Packages" is also refreshed by /docs-sync
[dotnet|angular|monorepo] FRAMEWORK-CONTEXT.md  "Known Hazard Areas" is re-confirmed by /rebootstrap
[dotnet|angular|monorepo] README.md             "Detected Framework Packages" is also refreshed by /docs-sync
```

## Honest limits — what this does NOT do

- **The completeness net is verb-bounded.** It recognises seven verbs
  (`refreshed|re-confirmed|reconfirmed|regenerated|repopulated|maintained|updated`). A new false
  claim phrased *"…is kept current by `/docs-sync`"* would not be discovered, and would ship. This
  is a deliberate precision-over-recall trade: the alternative was rev 1, which fired on 94% of
  correct files. The registry is the floor; the grammar is a net with a known mesh size.
- **Three registry rows are never exercised by the completeness half** — `README.md`'s
  ``"Known Hazard Areas" by `/rebootstrap` `` has no verb, and the `rebootstrap` description and
  prompt step-count rows are not attribution-shaped at all. They are contract rows only. Their
  regressions are caught (defects 2 and 3 above prove it); their *disappearance* would be caught by
  the claim-text assertion; but no discovery mechanism would notice a *sibling* of them appearing.
- **Nothing here checks semantic agreement** between a description and a body in general. The 94%
  figure is the evidence for why that cannot be a blocking lexical gate; it belongs to review/evals.

## Notes for follow-up

- `.github/prompts/*.prompt.md` are the only shipped files that summarise another document's
  workflow, and there is exactly one count claim among the fourteen. If more are added, each is a
  new registry row — cheap, but it must actually be added, which nothing forces.
- The step-count matcher is `^### Step [0-9]+`. If a command file ever numbers its steps at a
  different heading depth the row would fail loudly rather than silently, which is the right
  direction.
