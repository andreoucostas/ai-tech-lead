# Framework recovery implementation plan

**Status:** READY FOR IMPLEMENTATION — proposal adversarially reviewed in a fresh context on
2026-08-22; implementation must occur in a separate session and receive the independent review
required by the maintenance model.

**Baseline reviewed:** `master` at `45722da`, shipped v0.72.0.

## Outcome

Restore the framework to a defensible baseline before adding capabilities:

1. installing or updating cannot erase consumer configuration, custom skills, or audit history;
2. adoption emits no causal A/B claim from an invalid experiment;
3. public claims match the actual enforcement surface;
4. a warehouse-only repository is either supported through its complete lifecycle or refused
   honestly; and
5. later simplification is driven by field evidence, not file-count aesthetics.

This is a recovery sequence, not one mega-release. A release may contain only the work in one
increment below. Feature releases stay paused until increments 1–3 — including increment 3's
temporary warehouse-only routing refusal — are shipped and their first CI runs are green.

## Adversarial disposition of the original proposal

### Accepted

- Installer lifecycle has stop-ship data-loss defects.
- The shipped impact Tier 2 does not compare the old setup with the framework and cannot support a
  causal value claim.
- Compliance, hard-block, host, and architecture-backstop language exceeds observed behavior.
- B-115's pure-SQL completion is incomplete.
- Static context is effectively at its declared ceilings and needs an explicit budget decision.
- Non-author onboarding, VS Code hook, and Bitbucket required-build evidence remain incomplete.

### Corrected

- `/review` always fans out to five agents, but `/review` is not mandatory for every ordinary task.
- Sixty-one shipped `.ps1`/`.sh` files includes 23 test scripts; 38 are non-test hooks/utilities.
- Copilot CLI has dated live evidence. The gap is incomplete and ageing coverage, not zero evidence.
- Tier 2 is not runnable when its CLI is absent; the mandatory adoption report and false A/B claim
  are the problem, not an unconditional guarantee that every adoption executes the runner.
- SQL fallback applies only to repositories satisfying at least two warehouse signals, not every
  arbitrary SQL repository.

### Rejected as premature

- A new SQL distribution, or a four-way core/host/language/domain pack architecture. WSD-020,
  WSD-021, WSD-033, and B-157 reject multiplying distributions or optional installs without
  measured consumer harm.
- A wholesale doctrine/profile rewrite. Measure concrete rule friction first.
- Removing the five-agent review before B-159 measures whether and when it is naturally invoked.
- Treating direct-to-master release as an immediate consumer P0. WSD-029 already withholds the tag
  until CI; a candidate-ref design belongs in a later, separately measured change.
- An arbitrary target such as “40 installed files.” On-disk volume, static context, CI time, and
  reviewability are different costs and must not be collapsed into one number.

## Newly confirmed omissions

The fresh review found two data-loss paths absent from the original proposal:

- `.claude/ai-audit.log` is classified as framework-owned and bulk-overwritten on update. A
  disposable update probe appended a sentinel and observed `AUDIT_SURVIVED_UPDATE=False`.
- Both installers delete the entire `.github/skills` directory before rebuilding it from
  `.claude/skills`, destroying GitHub-only custom skills and other unknown descendants.

These join the already reproduced brownfield loss of `.claude/settings.json` and
`.github/hooks/hooks.json`.

## Binding constraints

- Author only under `src/`; compose `dist/` [invariant #1].
- Installer, composer, and shipped-script changes are PowerShell/bash twins [#3].
- Preserve WSD-043's update contract for mixed `.claude/settings.json`: disclose, back up, refresh.
  Brownfield has no equivalent licence to destroy a pre-existing settings file; it must archive it
  for `/adopt`.
- Treat `.claude/ai-audit.log` as persistent consumer state, never ordinary framework machinery.
- Do not introduce a SQL distribution (WSD-020/021/033).
- Do not add a permanent general rolling archive rejected by WSD-043. If rollback is implemented,
  use an ephemeral mutation journal deleted on success; the existing named settings backup remains.
- Every lifecycle test must first demonstrate the unfixed red state and must run against the
  composed dist on every applicable twin/CI leg.

## Increment 1 — P0 no-loss installer patch

### 1.1 Red fixtures before implementation

Extend `.claude/hooks/tests/UpdateDelivery.Tests.ps1` rather than creating another expensive test
runner. The installers are shared authored files composed into every dist, so run the deep
behavioral lifecycle cases against dotnet on both twins; prove all-dist delivery through composed
installer hashes/policy manifests plus the existing greenfield/brownfield smoke matrix. Expand a
deep case to another dist only when that dist carries different installer behavior. Prove these
current red states:

1. Brownfield sentinels in `.claude/settings.json` and `.github/hooks/hooks.json` are recoverable
   under `docs/pre-adoption/<original-relative-path>` and appear in
   `.claude/adoption-pending.json.archivedOriginals`.
2. An existing `.claude/ai-audit.log` remains byte-identical through brownfield and update.
3. A GitHub-only `.github/skills/local-only/SKILL.md` survives brownfield and update.
4. A same-path pre-existing command/skill collision is archived before replacement, proving the
   solution is not another two-path allowlist.
5. A pre-existing archive destination causes preflight refusal before the first target mutation;
   no `Move-Item -Force`/`mv -f` silently replaces an earlier archive.

The red evidence must name which cases lose data on v0.72.0. Mutation of the test itself must also
be shown to fail so a vacuous preservation assertion cannot pass.

### 1.2 Persistent audit state

In `src/core/scripts/install.{ps1,sh}` introduce one explicit persistent/copy-if-absent path policy
for `.claude/ai-audit.log`:

- greenfield: install the header when the file is absent;
- brownfield/update: leave an existing file byte-identical;
- never include it in stale-file deletion;
- classify it as `consumer-owned/protected` in generated `framework-ownership.json`.

Update both composer twins' manifest-policy extraction. The policy must be derived from both
installers and fail composition if the twins disagree.

### 1.3 Manifest-driven brownfield collision archive

Before any target mutation, read the incoming `framework-ownership.json` and calculate every
incoming file whose target path already exists. In brownfield mode:

- archive every collision that the bulk copy would replace, including settings, hooks, commands,
  skills, and instructions;
- exclude persistent copy-if-absent paths and legal paths governed by the existing refusal policy;
- preserve exact original-relative-path mappings in `adoption-pending.json`;
- preflight every archive destination and refuse on ambiguity/collision;
- do not mutate the target until the complete operation list is valid.

The manifest replaces `$brownfieldCollisions` as the collision inventory; do not grow another
hard-coded list.

### 1.4 Preserve unknown GitHub skills

Remove the whole-directory `.github/skills` reset. Upsert mirrors from `.claude/skills` while
leaving unknown target descendants untouched. Framework skills later retired are handled by
increment 4's ownership reconciliation, not by deleting the directory.

### 1.5 Dirty-tree safety

For brownfield/update targets that are Git repositories, refuse a dirty tracked/untracked tree
before mutation and print the exact commit/stash/copy recovery action. Greenfield non-Git targets
remain supported. Any override must be explicit, named on stdout, and covered by tests; do not make
it the default path.

### Acceptance

- All five deep lifecycle red fixtures pass on PowerShell and bash for the representative dotnet
  dist; composer/manifest parity and the existing smoke matrix prove delivery to angular/monorepo.
- Greenfield behavior and current protected/settings/legal/skill migration contracts remain green.
- `framework-ownership.json` names audit state protected in every dist.
- `validate-dist` ×3, hook suites ×3, and the meta suite pass; first Windows and Linux CI legs are
  green before the increment is considered delivered.

## Increment 2 — P0 retire invalid impact evidence

### 2.1 Stop the claim immediately

Change all three stack-owned `adopt.md` files and the shared `impact.md` so adoption completion no
longer depends on Tier 2. Retain only evidence that is true:

- an inventory/capability comparison of archived configuration versus installed capabilities;
- a clearly labelled repository scorecard, with no claim that adoption caused its delta; and
- an explicit statement that the former pre/post experiment was invalid because the pre ref was
  captured after installation.

Remove “old framework arm,” “only the framework differs,” and immediate behavioral-value language.
Do not create a replacement baseline inside `/adopt`; the old setup is already inactive by then.

### 2.2 Fail-closed tombstone, then removal

Impact retirement is an explicit two-release migration:

1. In this increment, keep `scripts/impact-run.{ps1,sh}`, `tests/impact/`, and their ownership
   entries, but replace both runners with inert tombstones that print why the experiment is invalid
   and exit non-zero. They must contain no agent invocation, `--allow-all-tools`, `Invoke-Expression`,
   `bash -c`, or worktree mutation. Test direct invocation, not only the `/adopt` call path.
2. In increment 4, read the target's old manifest first, authorize the paths through the incoming
   retirement ledger, then remove the authored runner/test paths and their manifest entries in the
   same release. An increment-2-to-increment-4 update fixture must prove both tombstone runners and
   all retired `tests/impact/` paths disappear.

The credible behavioral A/B remains B-49's controlled bare-versus-installed drill, not a
consumer-side unattended run.

### 2.3 Truth gate

Extend `DocClaims.Tests.ps1` or `DocTruth.Tests.ps1` with one narrow assertion that shipped adoption
docs cannot describe the post-install tag as an active old-framework arm. Red-test it with the
current sentence before changing prose.

### Acceptance

- `/adopt` can finish with no Copilot CLI and without representing skipped Tier 2 as missing value
  evidence.
- No shipped command invokes `impact-run` or calls the post-install tag the old active setup.
- Existing Tier 1 output is labelled descriptive, never causal.

## Increment 3 — P1 claims and documentation truth

Use `src/core/docs/enforcement-surfaces.md` as the factual vocabulary, not a second marketing
taxonomy. Sweep authored active READMEs, presentations, hook comments, doctor messages, review
guides, commands, and framework-rule snippets. Historical changelogs, `meta/`, backlog records, and
archived evidence are exempt from literal claim denial; they may retain old wording as history, but
must not be cited as current product behavior without an explicit correction.

### Required corrections

- Replace “any write,” “literally cannot write,” and “every AI-assisted file change” with the exact
  hooked editor/file-write scope and host prerequisites.
- Remove claims that the log satisfies SR 11-7, DORA, or a regulated audit-trail contract. Describe
  it as local, hook-dependent change telemetry with known blind spots and mutable retention.
- State NetArchTest/dependency-cruiser as scaffoldable backstops, not enforced until the consumer
  wires them into CI.
- Keep Copilot CLI's dated evidence; describe VS Code hooks as Preview/org-gated and uncertified.
- Remove brittle hard-coded install counts from root README and make each dist's
  `framework-ownership.json` authoritative.
- Correct the licence statement: the licence and notice travel in every dist.
- Remove the stale numeric status paragraphs from root `CLAUDE.md`/`AGENTS.md`; point at the machine
  version stamps rather than adding another version-sync gate.

### Temporary warehouse-only refusal

In this same pre-thaw increment, change the root installers so a repository detected only through
warehouse signals is not silently routed to the dotnet lifecycle. Return an actionable message:
warehouse signals were found, but this release does not certify solution-free adoption; explicit
`-Stack dotnet` / `--stack dotnet` is an informed override. Red-test the current auto-selection and
the corrected refusal in `RootInstallerWarehouse.Tests.ps1` on both root-installer twins. Full
solution-free support and restoration of automatic routing remain increment 5.

Add red claim fixtures for only the high-risk absolutes/regulatory phrases. Do not attempt to lint
all persuasive prose.

### Acceptance

- A repository-wide search finds no unqualified SR 11-7/DORA satisfaction, “literally cannot,” or
  “every AI-assisted change” claims in the active claim surfaces defined above.
- Honest matrix and all summaries agree on shell-write and VS Code limits.
- Root doc truth checks cover licence and manifest authority without hard-coding counts elsewhere.
- Warehouse-only auto-detection refuses honestly before feature releases resume; explicit override
  remains observable.

## Increment 4 — P1 convergent, downgrade-safe updates

### 4.1 Operation plan and dry run

Before mutation, both installers compute and print a structured operation plan: create, replace,
preserve, archive, and delete. Add `-WhatIf` / `--dry-run` that exits after this calculation and is
proved mutation-free by hashing the target tree.

### 4.2 Trusted stale owned-path reconciliation

The target's previous `framework-ownership.json` is consumer-mutable evidence of prior state, not
deletion authority. Add an incoming, framework-authored retirement ledger (for example
`framework-retirements.json`) whose entries name the exact path and retirement version. Composer
checks must reject a retirement that is still present in the incoming ownership manifest.

The ledger is cumulative and append-only by default: an entry remains in every later dist so a
consumer may skip releases and still converge. Composer checks must fail if an existing retirement
entry disappears. Shortening retention is forbidden until a minimum supported source-version
horizon exists as explicit machine-readable policy and the composer proves no supported prior
manifest can still contain the path; no such horizon is introduced by this plan.

Before using either file, validate schema and every path:

- normalized repo-relative `/` form only; reject absolute/drive/UNC paths, empty or `.`/`..`
  segments, backslashes, NULs, duplicates, and unsupported schema versions;
- resolve the candidate under the target and prove it stays under the target root;
- refuse deletion through a reparse point/symlink escape or when that check cannot be performed;
- distinguish malformed/unexaminable metadata from a genuine content decision.

Read the target's previous manifest before copying and the incoming manifest/retirement ledger from
the dist. Delete only paths satisfying all of these:

- present in the previous manifest;
- previously `framework-owned/overwritten`;
- absent from the incoming manifest; and
- explicitly authorized by the incoming retirement ledger; and
- not a named persistent runtime path.

Never delete old `consumer-owned/protected`, `mixed`, unknown, or unclassifiable paths. If the old
manifest is missing or malformed, report `CANT-VERIFY`/additive compatibility mode and perform no
stale deletion; do not misreport that state as a clean reconciliation.

Red fixtures must put a consumer file, `../outside`, an absolute path, a duplicate, and a symlink or
reparse escape into a forged prior manifest and prove none can be deleted. The green world is a
valid previous-owned path also named by the trusted incoming retirement ledger.

### 4.3 Downgrade refusal

Compare the installed and incoming semantic versions. Refuse an older incoming version before any
mutation unless an explicit `-AllowDowngrade` / `--allow-downgrade` flag is passed. Root dispatchers
must forward the flag, and all three stack selections need behavioral coverage.

### 4.4 Recoverable mutation

After all preflight checks, create an ephemeral journal containing only paths the operation plan
will replace/delete plus the list of newly created paths. On a caught failure, restore replaced and
deleted paths and remove only paths created by that run. Delete the journal on success. This is not
WSD-043's rejected permanent rolling archive.

Do not claim transactionality until a deliberately induced mid-apply failure has been observed to
restore every sentinel on both twins. If a reliable cross-platform failure injection cannot be
constructed, ship preflight/dry-run/reconciliation first and keep rollback explicitly open.

### Acceptance

- A planted retired framework hook disappears on update.
- An increment-2 installation upgraded through increment 4 removes the inert impact runners and
  retired `tests/impact/` paths, proving the tombstone migration end to end.
- An increment-2 installation upgraded directly to a simulated later post-increment-4 dist also
  removes those paths, proving cumulative retirement survives skipped releases.
- A same-named unknown/custom path survives.
- Forged consumer/out-of-root/duplicate/reparse paths are refused or ignored without deletion.
- Missing/malformed previous manifests take the explicit non-destructive compatibility path.
- Downgrade refuses before mutation; explicit downgrade is observable and tested.
- Dry-run produces the same operation set as apply and changes zero target bytes.
- Failure restoration is claimed only with a red/green induced-failure fixture.

## Increment 5 — P1 honest warehouse-only lifecycle

Starting from increment 3's honest refusal, complete support without a new distribution:

1. Make the pre-bootstrap carrier technology-neutral.
2. Audit `/bootstrap`, `/adopt`, `/feature`, `/fix`, `/review`, `/test`, and CI guidance for
   unconditional `.sln`/csproj/dotnet commands.
3. Derive build/test/format commands from repository evidence. A repo with no applicable command
   reports “not available,” never a false pass and never an invented .NET step.
4. Add pure warehouse-SQL greenfield and brownfield/adoption fixtures that reach completion without
   a solution.
5. Restore warehouse-only auto-routing only after the complete lifecycle fixture is green on both
   installer twins.

Correct B-115's record rather than silently treating a DONE entry as proof. The fix is
technology-neutral branching inside the existing dotnet/monorepo surface, consistent with
WSD-020/021/033.

## Increment 6 — evidence before structural simplification

Execute existing work instead of creating replacement machinery:

- B-158: decide the static-context ceilings and surface headroom during authoring.
- B-159: measure natural-language `/review` fan-out before changing the five-agent command.
- B-160: establish a non-warehouse skill-routing bar.
- B-42: collect non-author onboarding friction and the already requested success metrics.
- B-43/B-49: complete primary-host recertification and drill #0.
- B-15: verify the required-build recipe on a real Jenkins/Bamboo environment.

Only reopen optional packs when at least two independent non-author observations name installed
volume, reviewability, or default CI/runtime cost as material friction. Only introduce policy
profiles when field/drill evidence names a specific rule whose false-positive cost exceeds its
benefit. Until then, reduce always-loaded context by retiring content under B-44's existing
overlap-watch triggers, not by reorganizing the same text into more directories.

## Increment 7 — later release and supply-chain work

These do not block the recovery releases:

- Prototype a candidate ref containing the exact release commit, run CI on that ref, then
  fast-forward `master` and tag only the same verified SHA. Compare it with WSD-029's current
  push/watch/tag flow; do not use a squash PR, the failure mode that motivated the present design.
- Before distribution beyond the current pilot model, publish checksummed release artifacts,
  provenance/SBOM, and signed tags or attestations. First document the actual threat and delivery
  model; clone-and-run is not by itself evidence of an exploited supply-chain defect.

## Verification matrix

| Risk | Required red world | Required green world |
|---|---|---|
| Brownfield collision loss | Sentinel absent after v0.72.0 install | Sentinel archived and marker maps it |
| Audit retention | Sentinel erased by v0.72.0 update | Log remains byte-identical |
| GitHub-only skill loss | Custom skill removed by directory reset | Unknown descendant survives |
| Invalid impact | No-op SQL trial reports acceptance | No Tier 2 causal result is emitted |
| Unsafe retired runner | Direct invocation can launch an all-tools agent | Tombstone exits non-zero without an agent |
| Claim drift | Current forbidden absolute is detected | Qualified wording passes |
| Stale owned path | Retired hook survives additive update | Prior-owned + incoming-authorized retired hook is deleted |
| Forged retirement | Prior manifest names consumer/outside path | Path validation/intersection prevents deletion |
| Downgrade | Older dist mutates target | Refusal occurs before mutation |
| Dry run | Any target hash changes | Operation plan only, zero byte changes |
| SQL lifecycle | Warehouse-only install enters .NET-only bootstrap | Refusal, then later complete neutral flow |

## Definition of recovery complete

- Increments 1–5 shipped with independent review and green first CI runs.
- No known installer path can erase framework-recorded audit history or unarchived brownfield agent
  configuration.
- `/adopt` makes no causal impact claim from a post-install baseline.
- Public enforcement claims are bounded by host, hook event, and write path.
- Warehouse-only auto-detection is either disabled honestly or certified through full adoption.
- Structural simplification remains evidence-gated rather than assumed from repository size.
