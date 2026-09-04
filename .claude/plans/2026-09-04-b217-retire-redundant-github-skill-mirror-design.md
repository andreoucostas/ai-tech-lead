# B-217 — retire the redundant GitHub skill mirror

**Status:** LOCKED AFTER INDEPENDENT ADVERSARIAL REVIEW — APPROVE
**Filed against:** v0.81.0 (2026-09-04)
**Target:** v0.82.0
**Scope:** shipped skill discovery, update/adoption migration, and bounded host-audience truth;
no change to skill content or the other Claude/GitHub adapters.

**Review:** an independent `gpt-5.6-sol`/`xhigh` read-only review returned REVISE twice, identifying
legacy-manifest deletion limits, brownfield discovery, an invalid red fixture, stale AGENTS audience
claims, preserved sync-script risk, a release collision, and a model-operated adoption overreach.
After those corrections and a calibrated durable-warning red were incorporated, it returned
APPROVE on the contract whose pre-annotation SHA-256 was
`4b1d3d54ed410b569a9f80b9684f3c2c28039e2eb4355fd8a5dbc4c4467cdf1a`;
this status/review annotation is the only later plan change.

## Decision in one sentence

Ship project skills once, under `.claude/skills/`, because every supported GitHub Copilot skill
surface now documents that location; retire the byte-identical `.github/skills/` tree and all
framework machinery whose only job is to create or police it, while retaining every `.github`
surface that still has a distinct host contract.

## Premise, evidence, and proportionality

WSD-002 (2026-06-04) made `.github/skills/` a required mirror on the premise that Copilot CLI and
the cloud agent did not read `.claude/skills/`. That decision records no vendor source or live
canary. Current GitHub documentation now lists `.claude/skills/` as a project-skill location for
Copilot CLI, coding agent, code review, the GitHub Copilot app, and supported IDE agent modes. It
also says skill resources live with `SKILL.md`, so B-216's proposed reference sidecars do not need a
second tree. The CLI reference gives `.github/skills/` higher discovery priority than
`.claude/skills/`, making a stale mirror capable of shadowing the canonical skill.

Authoritative sources checked on 2026-09-04:

- <https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills>
- <https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#skills-reference>
- <https://docs.github.com/en/copilot/concepts/agents/about-agent-skills>
- <https://docs.github.com/en/copilot/reference/custom-instructions-support>

A deterministic local canary on GitHub Copilot CLI 1.0.80 used isolated Git roots and an empty
fixture-local `COPILOT_HOME`. `copilot skill list --json` reported a unique project skill whose only
copy was `.claude/skills/canary-claude-only/SKILL.md`; the matched fixture with neither skill tree
did not report it. No model session was invoked. This observes CLI discovery, while the named
non-CLI surfaces remain documentation-backed rather than locally executed.

The duplicate is material rather than cosmetic: the three current distributions commit 38 mirror
files totalling 191,293 bytes. The mirror also owns two shipped sync scripts, installer branches,
two parity checks, behavioral fixtures, generated-file instructions, and documentation. Historical
generated-carrier drift shows the general cost of mirrored output; skill-specific defects include a
CRLF false failure, a Bash portability repair, and an installer version that deleted unknown
consumer `.github/skills` content. No unobserved skill-mirror drift is inferred from the broader
carrier incident.

The smallest fix that removes the observed class is one canonical skill tree. Rebuilding every
GitHub adapter, relocating the shared rules carrier, or deleting `AGENTS.md` would not be
proportionate: those artifacts have different host or migration contracts and none is required to
remove this duplicate.

## Whole-surface audit and retained boundaries

| Surface | Evidence-backed classification | v0.82.0 disposition |
|---|---|---|
| `.github/skills/**` | Byte-identical copy; all named Copilot skill hosts accept `.claude/skills/**` | Retire |
| `scripts/sync-agent-files.*` | Exists only to build the retired mirror | Retire |
| `AGENTS.md` | Generated portable rules; GitHub code review and observed Codex injection need it where `CLAUDE.md` is not a documented substitute | Retain; correct its overstated audience |
| `.github/prompts/*.prompt.md` | IDE prompt UX wrappers; `.claude/commands` is documented for Copilot CLI, not all IDE prompt surfaces | Retain |
| `.github/agents/*.agent.md` | Copilot custom-agent wrappers; `.github/agents` remains the documented cloud-agent location | Retain |
| `.github/copilot-instructions.md` | Inline-completion digest, a surface not covered by agent-skill support | Retain |
| `.github/instructions/**` | Path-targeted Copilot carrier and the current imported source for four Claude rule sections | Retain |
| `.github/hooks/hooks.json` | Copilot-specific registration and decision schema; Claude settings are not equivalent | Retain |
| `.github/workflows/**` | GitHub Actions CI | Retain |
| `.github/PULL_REQUEST_TEMPLATE.md` | GitHub pull-request integration | Retain |

The audit is a removal boundary, not a permanent assertion that every retained adapter must always
exist. Prompt, agent, instruction, and hook adapters may be retired later only against their own
surface-specific documentation and positive/negative canary. A general statement that Copilot
supports some Claude files is insufficient evidence for another capability.

The same primary-documentation pass found stale `AGENTS.md` audience claims. Codex defaults to
`AGENTS.md` and has no documented automatic import of `CLAUDE.md`; GitHub code review documents
`AGENTS.md`, not `CLAUDE.md`; Cursor discovers both. Gemini defaults to `GEMINI.md` unless a user
configures other filenames, and Aider requires explicit `--read`/configuration. The full mirror is
therefore retained for Codex and code review, but active files must stop saying Copilot CLI, Gemini,
or Aider uniquely or automatically require/load it. Adoption may still ingest their existing
artifacts; that is a different claim.

## Frozen implementation contract

### 1. One skill source and no generated mirror

- `.claude/skills/**` remains the only authored and shipped project-skill tree.
- Delete every `src/**/.github/skills/**` whole file and snippet. Rebuilding all profiles must
  produce no `.github/skills` framework file.
- Delete `src/core/scripts/sync-agent-files.ps1` and `.sh`. They are a twin retirement, not an
  exception to twin parity.
- Narrow `/generate-copilot` to its remaining outputs: `AGENTS.md` and
  `.github/copilot-instructions.md`. Remove its skill-sync phase and mirror repair scope; do not
  rename the command in this release because both outputs remain Copilot-facing generated files.
- Common Tasks and architecture documentation identify `.claude/skills/` as the shared
  Claude/Copilot location. Historical changelog entries remain historical and are not rewritten.
- Correct active root and shipped AGENTS/README/playbook/architecture/bootstrap/generation/
  presentation claims to the evidence above. Do not add a `GEMINI.md`, Aider configuration, or a
  third generated carrier in the name of deduplication.

### 2. Installer convergence and consumer safety

- Remove only the installer code that parses incoming `.github/skills`, constructs mirror pairs,
  recreates mirrors from final active Claude skills, or tree-deletes GitHub mirrors during skill
  disable. Preserve the existing `.claude/skills` backup, exemplar, disable, re-enable, and
  discovered-skill behavior.
- Add every formerly shipped `.github/skills/**` leaf and both sync-script leaves to the cumulative
  `framework-retirements.json`, with every distinct SHA-256 observed in release-tag distributions
  for all three profiles. Update the maintainer baseline byte-for-byte.
- On update, the existing WSD-051 intersection remains deletion authority: the prior ownership
  manifest must classify the path as framework-owned, and current bytes must match a known digest.
  Known-clean stock files are deleted. Modified, unknown, malformed, unsafe, unhashable, or
  reparse-traversing files remain in place with `CANT-VERIFY`; unknown consumer-only skills are
  untouched. Never recursively remove `.github/skills/` or an individual skill directory.
- Automatic retirement is possible only when the immediately prior
  `framework-ownership.json` is valid and classifies the leaf as framework-owned. Tags before the
  ownership manifest, direct/legacy installs, and targets with a missing or malformed manifest must
  preserve even known stock bytes. Emit a high-signal per-path `CANT-VERIFY` migration warning for
  every surviving retired `.github/skills/**` or `scripts/sync-agent-files.*` path, rather than
  allowing the generic additive-mode message to imply the precedence risk is resolved.
- Make that warning durable across later releases: independently inspect the exact high-risk paths
  named by the incoming retirement ledger after reconciliation planning, and warn for every path
  that exists but is not in the qualified deletion plan. Do not require it to appear in the
  immediately prior manifest merely to diagnose it. The read-only residual check grants no deletion
  authority, follows no reparse/symlink, and states whether a GitHub skill may shadow its canonical
  `.claude` slug or a sync script may recreate such shadows.
- A preserved GitHub-path customization can shadow the canonical Claude skill because GitHub gives
  that path higher priority. The update output and consumer release note must therefore say exactly
  what remains and instruct the owner to migrate intentional customization to `.claude/skills/`
  before removing the old copy. This is an honest manual conflict, not authority to delete it.
- A preserved modified `sync-agent-files` script is especially hazardous because running it can
  recreate the entire higher-priority mirror after v0.82.0. Name that consequence in update output
  and release notes. The installer must neither execute nor rewrite the preserved script.
- Greenfield and brownfield installs create no `.github/skills` tree. Repeated update is idempotent.

### 3. Brownfield adoption reports a deterministic manual-migration blocker

- Add `.github/skills` to both installers' adoption-signal list. A repository with that tree and no
  framework version enters `/adopt`, not a greenfield `/bootstrap` that could leave a silent
  higher-priority skill source unreviewed.
- Add `.github/skills/*/SKILL.md` plus sibling resources to `/adopt` Phase 1's Copilot inventory.
  They are untrusted consumer input, not commands for the adopting agent and not framework-owned
  merely because old framework releases once used the same path.
- Do not put these skill trees through Phase 3's generic archive or Phase 6's custom-command merge.
  In both interactive and headless modes, report the exact paths and stop before Phase 2 with the
  adoption marker intact. The checklist tells a person to move each complete directory to
  `.claude/skills/<slug>` after reviewing untrusted contents; when that slug already exists, compare
  and explicitly merge or rename instead. The workflow itself does not move, delete, overwrite,
  interpret, or execute the discovered skill. Unknown GitHub-only skills are therefore preserved.
- The developer reruns `/adopt` after the manual migration. A replacement deterministic
  `template-checks` rule rejects any remaining `.github/skills` path and points to the canonical
  location, so Phase 7 cannot report PASS while a higher-priority shadow remains. This gate, not
  model obedience to a move/delete procedure, is the completion authority.

### 4. Checks and tests lose the obsolete assertion, not skill validation

- Remove the mirror-parity branch from `template-checks.*` and `docs-sync-check.*`. Keep Common
  Tasks-to-canonical-skill inventory validation and all independent skill syntax/content checks.
  Replace parity with the narrower canonical-location assertion: a present `.github/skills` path is
  a migration failure, not a mirror to regenerate. It must name `.claude/skills` as the destination.
- Replace the sync-script cases in the existing `ScriptTwinParity` suite with no new harness.
  Update its reached-check list and the meta script-twin registry so deleting the twin cannot create
  a vacuous pass.
- Extend existing installer convergence/update cases to prove stock-retirement, modified-copy
  preservation with `CANT-VERIFY`, unknown GitHub-only preservation, canonical Claude-skill
  preservation, no mirror creation, dry-run/apply plan equality, and idempotence for both twins.
  Add missing- and malformed-prior-manifest cases proving stock paths survive with explicit manual
  migration warnings; cover a pre-v0.65 manifest-free shape and its subsequent update after the new
  manifest has arrived, proving the warning remains durable. Add an isolated test-owned modified
  sync script: prove the first update preserves and warns about it, invoke that known fixture script
  outside the installer to recreate a mirror, then prove the next update warns about both while
  deleting neither consumer byte. Cover brownfield detection plus unknown, identical, and
  conflicting GitHub-skill discovery reports, and interactive/headless early-stop instructions,
  without executing or moving discovered content. Prove the deterministic checker keeps Phase 7
  red until the GitHub path is gone.
- Extend composer/validation assertions so a fresh distribution containing a framework
  `.github/skills/**` file or either retired sync script is red. This is a repository product
  invariant; it does not reject a consumer-owned `.github/skills` directory.
- Remove mirror-only fixtures and claims from eval setup, review guides, README trees, architecture
  diagrams, installer contract text, and active generated carriers. Do not rewrite historical
  changelog, plans, decisions, or completed backlog evidence.

### 5. B-216 relationship

B-216 remains open but is retargeted to v0.83.0 or later and paused while this prerequisite ships.
Its existing Copilot pretrial results remain recorded. Before B-216 implementation, re-lock its
sidecar paths and lifecycle around the single `.claude/skills` tree; remove its now-obsolete mirror
propagation and mirror-validation requirements. The Unity defect is not silently folded into this
structural release.

## Required red and green worlds

Before implementation, capture these release-specific reds on the unfixed tree:

1. Remove `.github/skills` from an isolated current distribution and run each current
   `template-checks` twin: both must reject the missing mirror. The constructible green state under
   the old instrument is the unmodified mirrored distribution.
2. Run an isolated current update fixture with canonical `.claude/skills` and no incoming GitHub
   skill files, coherently removing those files' entries from the scratch incoming ownership
   manifest as well. The old installer must reach `OPERATION-PLAN` and plan/create the exact GitHub
   mirror leaves, proving the machinery is live rather than dead prose.
3. Plant a retired stock mirror, a one-byte-modified mirror, and an unknown GitHub-only skill in an
   update fixture. Before the new ledger exists, no retirement plan can distinguish/delete the
   stock path. After implementation, only the stock leaf must be planned/deleted; the other two
   must be preserved and the modified path must produce `CANT-VERIFY`.
4. Build a scratch update with a valid prior v0.82-shaped ownership manifest that does not own the
   retired path, a cumulative incoming ledger that names it, and a surviving GitHub skill plus
   modified sync script. The old installer must reach `OPERATION-PLAN` but omit the targeted
   residual warning. After implementation, both the first run and a later update must warn for the
   exact paths without planning or performing deletion.

Pre-implementation evidence observed on 2026-09-04:

- In an isolated dotnet v0.81.0 distribution with `.github/skills` removed, PowerShell and Bash
  `template-checks` each exited 3 and named mirror drift. The fixture was removed afterward.
- In isolated update fixtures whose incoming mirror files and corresponding scratch-manifest rows
  were both removed, each v0.81.0 installer reached `OPERATION-PLAN`, exited 0 in dry-run mode, and
  planned 12 `create .github/skills/.../SKILL.md` operations. The fixtures were removed afterward.
- In an isolated residual fixture, the scratch incoming ledger named one GitHub skill and both sync
  scripts while the valid prior manifest owned none of them; a sync script was consumer-modified.
  Both v0.81.0 installers reached `OPERATION-PLAN` and exited 0, but emitted zero targeted residual
  warnings and planned 12 mirror writes. This calibrates the new durable diagnostic's old-red state;
  the fixture was removed afterward.

The already calibrated `copilot skill list --json` positive/negative pair is the discovery green
oracle. Re-run it against one composed candidate distribution containing no `.github/skills`.
Success is the expected stock canonical skill inventory with `source: project` and `.claude` paths;
failure or inability to examine is not reclassified as a distribution defect.

## Verification and delivery

1. Generate retirement digests from every reachable release tag and all three distribution paths;
   retain the command output as review evidence and verify each new entry is absent from incoming
   ownership.
2. Build all three distributions from `src/`; never edit `dist/` directly. Require a clean
   build-diff check after the committed generated outputs are refreshed.
3. Run `validate-dist` for all profiles; the root meta suite; relevant direct installer,
   convergence, composer, docs-sync, and script-twin suites; both installer twins in greenfield,
   brownfield, old-stock update, modified-mirror update, and repeat-update fixtures; and syntax/BOM
   checks for every changed script.
4. Run the candidate Copilot metadata canary without a model session. No live model A/B is required:
   host discovery, filesystem convergence, residual diagnosis, and adoption completion are
   deterministic. `/adopt` gains only an early report-and-stop instruction; it performs no new
   model-selected migration, and `template-checks` prevents a false completed state. Compliance
   with the explanatory wording remains unmeasured and is not reported as observed behavior.
5. Freeze the final contract and immutable diff for an independent blind-first review. The reviewer
   must see a release-specific hostile mutation go red, then the clean candidate go green, and must
   check that every changed function is required by this contract.
6. Record B-217, WSD-072, the decisions index, LEARNINGS, field-report attribution, RCA, and all four
   v0.82.0 changelog heads. Release with supplied review evidence, observe required Windows/Linux CI,
   then commit and push `master`.

## Honest limits

- The local canary observes Copilot CLI 1.0.80 only. Non-CLI Copilot skill discovery is supported by
  current GitHub documentation, not locally exercised here.
- Removing the mirror does not reduce always-loaded context; skills are on-demand. It removes
  committed payload, shadowing risk, installer mutation, and maintenance surface.
- Consumer-modified retired mirrors cannot be removed automatically without violating WSD-051.
  Such a repository needs a disclosed manual migration.
- Releases before `framework-ownership.json`, direct/legacy installs, and missing or malformed
  prior manifests cannot satisfy WSD-051 even when current bytes match a known stock digest. Their
  old mirror and sync scripts remain until the owner follows the explicit migration warning.
- This release does not prove that prompt, agent, hook, inline-completion, or portable-instruction
  adapters are redundant, and it does not claim that all of `.github` is Claude configuration.
