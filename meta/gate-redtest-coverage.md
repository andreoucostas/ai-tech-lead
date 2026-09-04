# Gate and diagnostic planted-defect coverage

Inventory date: 2026-08-18, against v0.60.0 plus the B-149 working-tree changes in this delivery.
Amended 2026-08-19: one row added for `VendorClaims.Tests.ps1`, a suite created after the inventory
date by B-55. No other row was re-inventoried, so every verdict below still dates from 2026-08-18.
**This is a historical evidence snapshot, not the current gate inventory or authority. Preserve its
dated rows and verdicts unchanged.** For the v0.83 PowerShell-only retirement classification, see
[`2026-09-04-b219-windows-powershell-only-consolidation.md`](../.claude/plans/2026-09-04-b219-windows-powershell-only-consolidation.md#test-retirement-classification-and-dual-host-evidence);
the current executable file and semantic-case inventories are pinned by the aggregate runners.
`COVERED` means an executable negative fixture or mutation exists and a repository record
shows the subject producing the expected failure/honest adverse row. `HAPPY-PATH-ONLY` means a clean
test exists but no qualifying red observation could be established. `NONE` means no test was found.
Where source inspection could not establish an observation, the Seen column says `UNKNOWN`; it does
not upgrade the verdict.

## Distribution validator and template gates

| Gate / location | Planted-defect test | Seen red / record | Twin(s) | Verdict |
|---|---|---|---|---|
| validate-dist 1 `markers` — `scripts/validate-dist.{ps1,sh}` | `ValidateDist.Tests.ps1` cases 22 and marker fixture | Yes — executable cases; this delivery's B-64 report | ps1 + sh | COVERED |
| validate-dist 2 `json` | `ValidateDist.Tests.ps1` case 23 and unparseable JSON cases | Yes — executable cases; B-64 report | ps1 + sh | COVERED |
| validate-dist 3 `bash-syntax` | `ValidateDist.Tests.ps1` case 24 | Yes — executable case; B-64 report | ps1 + sh validators | COVERED |
| validate-dist 4 `ps-syntax` | `ValidateDist.Tests.ps1` case 25 | Yes — executable case; B-64 report | ps1 + sh validators | COVERED |
| validate-dist 5 `template-checks` | `ScriptTwinParity.Tests.ps1` planted version/section/inventory drift | Yes — `2026-08-16-b58-implementation-report.md` | ps1 + sh | COVERED |
| validate-dist 6 `no-meta-leak` | `ValidateDist.Tests.ps1` empty-tree and machine-path/meta-token cases | Yes — `meta/review-ledger.md` v0.51.0 | ps1 + sh | COVERED |
| validate-dist 7 `no-dead-instruction` | `ValidateDist.Tests.ps1` cases 9–10 plus link/command mutations | Yes — `meta/review-ledger.md` v0.52.1 | ps1 + sh | COVERED |
| validate-dist 8 `hook-registration` | `ValidateDist.Tests.ps1` cases 1–8, 13–16 | Yes — executable cases; B-64 report | ps1 + sh (two explicitly PS-only branch duplicates) | COVERED |
| validate-dist 9 `marker-expansion` | `ValidateDist.Tests.ps1` marker-expansion matrix | Yes — `meta/review-ledger.md` v0.45.0 | ps1 + sh | COVERED |
| validate-dist 10 `section-path` | `ValidateDist.Tests.ps1` case 18 | Yes — `meta/review-ledger.md` v0.45.0 | ps1 + sh | COVERED |
| validate-dist 11 `carrier-import` | `ValidateDist.Tests.ps1` case 17 | Yes — `meta/review-ledger.md` v0.45.0 | ps1 + sh | COVERED |
| validate-dist 12 `step-references` | `ValidateDist.Tests.ps1` zero/broken/dead-reference matrix | Yes — `meta/review-ledger.md` v0.53.0 includes a literal numbering defect | ps1 + sh | COVERED |
| validate-dist 13 `prompt-hook-cardinality` | `ValidateDist.Tests.ps1` duplicate-user-prompt-hook | Yes — `2026-08-18-b148-implementation.md` | ps1 + sh | COVERED |
| dotnet `template-checks` | shared `ScriptTwinParity.Tests.ps1` scratch gate | Yes — `2026-08-16-b58-implementation-report.md` | ps1 + sh | COVERED |
| angular `template-checks` | shared `ScriptTwinParity.Tests.ps1` scratch gate | Yes — same report | ps1 + sh | COVERED |
| monorepo `template-checks` | shared `ScriptTwinParity.Tests.ps1` scratch gate | Yes — same report | ps1 + sh | COVERED |

## Framework doctor rows

All rows live in `src/core/scripts/framework-doctor.{ps1,sh}` and are parsed by
`src/core/tests/hooks/FrameworkDoctor.Tests.ps1`. Its exact 12-name assertion proves every parsed run
reaches every row; that is reachability, not automatically a planted adverse-state test.

| Diagnostic row | Planted-defect / adverse-state test | Seen red / record | Twin(s) | Verdict |
|---|---|---|---|---|
| Install state | Healthy fixture only; no missing-version/invalid-state mutation found | UNKNOWN | ps1 primarily | HAPPY-PATH-ONLY |
| Framework rules delivery | `missing framework-rules import is reported honestly` | Yes — executable fixture; B-64 report | ps1 | COVERED |
| Protected-file sync | `protected-file version divergence uses the required honest wording` | Yes — executable fixture; B-64 report | ps1 | COVERED |
| Bootstrap/adoption state | Pending and non-pending fixtures, but no malformed/adverse mutation found | UNKNOWN | ps1 + parity runs | HAPPY-PATH-ONLY |
| Wired hook shell | missing absolute interpreter fixture | Yes — executable fixture; B-64 report | ps1 | COVERED |
| Hook liveness | absent record → `CANT-VERIFY`, present record → `OK` | Yes — executable honest-row fixtures; B-64 report | ps1 + sh | COVERED |
| Hook files | missing hook file plus argument-resolution fixtures | Yes — executable fixtures; B-64 report | ps1 + sh | COVERED |
| Guard JSON parser | absent parser, working `python`, Store-stub, and NAME-only mutant | Yes — `meta/review-ledger.md` v0.46.0/v0.51.4 | ps1 + sh | COVERED |
| Stack toolchain | three templates × tools present/absent | Yes — executable adverse rows; B-64 report | ps1 + sh | COVERED |
| Copilot surface | both/neither/one-twin visibility matrix | Yes — executable adverse rows; B-64 report | ps1 + sh | COVERED |
| Mirror and version integrity | planted failing `template-checks` twins | Yes — executable fixture; B-64 report | ps1 + sh | COVERED |
| Audit trail substrate | Empty audit file only; no missing/unreadable audit fixture found | UNKNOWN | ps1 + parity runs | HAPPY-PATH-ONLY |

## Other gates and diagnostics

| Gate / location | Planted-defect test | Seen red / record | Twin(s) | Verdict |
|---|---|---|---|---|
| context-footprint — `scripts/context-footprint.{ps1,sh}` | planted +200-character ceiling breach | Yes — `meta/review-ledger.md` v0.49.0 | ps1 observed; sh parity not recorded | COVERED |
| hazard-check — `src/core/.claude/hooks/hazard-check.{ps1,sh}` | `HazardCheck.Tests.ps1` plus four applied mutations | Yes — `meta/review-ledger.md` v0.58.0 | ps1 + sh | COVERED |
| wiki-check — `src/core/scripts/wiki-check.{ps1,sh}` | `WikiCheck.Tests.ps1` negative matrix and B-75 reached-set mutation | Yes — this delivery's B-75 report | ps1 + sh | COVERED |
| warehouse-map-check — `src/core/scripts/warehouse-map-check.{ps1,sh}` | `WarehouseMapCheck.Tests.ps1` invalid-map fixtures | Seen adverse exits when suite runs; no earlier standalone record located | ps1 + sh | COVERED |
| docs-sync-check — `src/core/scripts/docs-sync-check.{ps1,sh}` | `DocsSyncCheck.Tests.ps1` plants a skills-mirror drift and asserts both twins exit 1 | Yes — executable B-149 mutation; `2026-08-18-b149-implementation.md` | ps1 + sh | COVERED |
| build-architecture-html — `src/core/scripts/build-architecture-html.{ps1,sh}` | `BuildArchitectureHtml.Tests.ps1` fixture-removal reached-set mutation | Yes — this delivery's B-75 report | ps1 + sh | COVERED |
| composer — `scripts/build.{ps1,sh}` | `Composer.Tests.ps1` plants a malformed marker and an unapproved whole-file collision against both twins. Missing snippets are intentionally removed, not rejected. | Yes — executable B-149 mutations; `2026-08-18-b149-implementation.md` | ps1 + sh | COVERED |

## Maintainer meta suites

One row follows for every `*.Tests.ps1` under `.claude/hooks/tests/` on the inventory date.

| Suite | Planted-defect / negative test | Seen red / record | Twin(s) exercised | Verdict |
|---|---|---|---|---|
| `BacklogHygiene.Tests.ps1` | `-RedTest` named mutations, including vacuity mutations | Yes — executable arms; strongest reference named by B-64 | n/a (PS-only meta) | COVERED |
| `DocClaims.Tests.ps1` | `-RedTest` named claim/registry mutations | Yes — `2026-08-18-b76-implementation.md` | n/a | COVERED |
| `DocTruth.Tests.ps1` | Static live-tree assertions; external planted-heading replay | Yes — `meta/review-ledger.md` v0.53.0 | n/a | COVERED |
| `VendorClaims.Tests.ps1` | nine `-RedTest` arms (3 planted claims, section-skipper, 4 vacuity/parse, unproved-pattern), plus a permanent in-suite provenance proof per pattern | Yes — all nine observed red, and the gate caught all four genuine instances in the real `dist/dotnet` at `3ea42f8^`; `meta/BACKLOG-DONE.md` B-55 | n/a (PS-only meta) | COVERED |
| `Composer.Tests.ps1` | malformed-marker and unapproved-overlay-collision mutations | Yes — `2026-08-18-b149-implementation.md` | composer ps1 + sh | COVERED |
| `DocsSyncCheck.Tests.ps1` | planted `.claude/skills` versus `.github/skills` drift | Yes — `2026-08-18-b149-implementation.md` | docs-sync-check ps1 + sh | COVERED |
| `FidelityCheck.Tests.ps1` | Invalid-ref negative contract | Yes — suite fixture; no separate earlier record located | ps1 + sh subject | COVERED |
| `GateBudgetConsistency.Tests.ps1` | drift, missing, and non-numeric ceiling fixtures | Yes — executable negative fixtures; B-64 report | n/a | COVERED |
| `GuardPatternErrors.Tests.ps1` | four `_MutationHelper` invalid-regex mutations | Yes — B-59 implementation report | guard ps1 + sh | COVERED |
| `InstallerContract.Tests.ps1` | missing `commit the copied files` contract-line mutation | Yes — executable B-149 mutation; `2026-08-18-b149-implementation.md` | installer ps1 + sh | COVERED |
| `LicenseDelivery.Tests.ps1` | conflicting licence/notice and ownership-marker removal | Yes — `meta/review-ledger.md` v0.54.0 | installer ps1 + sh | COVERED |
| `LicenseDrift.Tests.ps1` | Equality assertion only; one-byte external mutation | Yes — `2026-08-17-b81-implementation-report.md` | n/a | COVERED |
| `MetaHooks.Tests.ps1` | BOM-less, out-of-scope, legacy-name, and non-PS fixtures | Yes — executable negative fixtures; B-64 report | hook ps1 + sh | COVERED |
| `PushAndCheck.Tests.ps1` | failed push, red CI, absent CI, invalid git fixtures | Yes — executable adverse fixtures; B-64 report | PS-only meta script | COVERED |
| `ReleaseChangelogStamp.Tests.ps1` | missing/mismatched/malformed heads and planted Unreleased heads | Yes — executable cases; B-64 report | PS-only meta script | COVERED |
| `ReleaseCiWatch.Tests.ps1` | failed/skipped/unknown/event/timeout/re-run fixtures | Yes — executable cases and `meta/review-ledger.md` v0.49.0 follow-up | PS-only meta script | COVERED |
| `ReleaseGateWaiver.Tests.ps1` | unwaived failure, stale/blanket/non-run waiver fixtures | Yes — `meta/review-ledger.md` v0.49.0 | PS-only meta script | COVERED |
| `ReleaseStagingGuard.Tests.ps1` | stray file and gitlink refusal fixtures | Yes — executable cases; B-64 report | PS-only meta script | COVERED |
| `RepositoryPrivacy.Tests.ps1` | concrete-home detection and missing-environment fixtures | Test exists; prior report located design but no explicit observed-red record | n/a | HAPPY-PATH-ONLY |
| `RootInstallerWarehouse.Tests.ps1` | planted broken warehouse-selection result makes the suite reject the install | Yes — executable B-149 mutation; `2026-08-18-b149-implementation.md` | installer ps1 + sh | COVERED |
| `ScriptTwinCoverage.Tests.ps1` | Classification assertion only; no planted unclassified-twin mutation found | UNKNOWN | inventories ps1 + sh | HAPPY-PATH-ONLY |
| `SkillListParity.Tests.ps1` | External vacuous-pass probe | Yes — `meta/review-ledger.md` v0.53.0 | n/a | COVERED |
| `UpdateDelivery.Tests.ps1` | missing preflight/guard and collision/ownership negative paths | Yes — `2026-08-17-b46-implementation-report.md` and v0.56.0 ledger | installer ps1 + sh | COVERED |
| `ValidateDist.Tests.ps1` | 40+ focused mutations covering all 13 checks | Yes — records cited in validator table above | validator ps1 + sh | COVERED |
| `WorkspaceBom.Tests.ps1` | BOM-less and invalid-UTF-8 positive controls | Yes — executable controls; B-64 report | n/a | COVERED |

## Highest-value remaining gaps

The remaining happy-path-only gaps are the framework-doctor `Install state`, `Bootstrap/adoption
state`, and `Audit trail substrate` rows plus `RepositoryPrivacy` and `ScriptTwinCoverage`. The
matrix does not authorise adding those tests in this task.
