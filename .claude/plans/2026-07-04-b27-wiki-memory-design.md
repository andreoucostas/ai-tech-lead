# B-27 team wiki memory — design (P0 complete; implement P1/P2 from this doc)

> **RETARGETED 2026-07-06 (WSD-012):** ships as **v0.27.0 in the merged `ai-tech-lead` repo**,
> after the monorepo migration (B-25-EXEC). D1–D10 unchanged; the delivery mechanics below
> that assume two repos (lockstep [#1], check-lockstep additions, release.ps1 dual-stamp)
> retarget to the composer/fidelity gate — mechanics appendix lands in WSD-010 at merge Phase 5.

> **Status (2026-07-04): design FINAL.** Two critique rounds (self + independent adversarial
> agent; 15/15 findings incorporated — log at the bottom). Decision record: WSD-010 in
> `docs/workspace-decisions.md`. Implementer: follow D1–D10 and the implementation order below;
> **do not re-derive or relitigate** — the locked constraints are in BACKLOG.md B-27, the
> refinements here survived adversarial review. ~~Ship as **v0.26.0** via
> `.claude/scripts/release.ps1` [#7], both repos in lockstep [#1].~~ *(superseded — see
> retarget banner above)*

## What this is

Repo-managed shared knowledge for consumer dev pools: a PR-curated wiki (`docs/wiki/`) whose
index is auto-surfaced at session start on both surfaces, written through a triaging skill,
validated by a deterministic twin gate. Constraints locked at triage (B-27): file-based +
PR-curated, NO RAG/embeddings/MCP-server/decay math, NO auto-append hook, injection-hardened,
dual-surface instructed-first.

## D1 — Location & layout: `docs/wiki/`, flat, index + template

- `docs/wiki/INDEX.md` (one line per entry), `docs/wiki/_template.md` (entry skeleton), entries
  as `docs/wiki/<kebab-slug>.md`.
- **INDEX line grammar (normative — wiki-check, the skill, session-start, and the tests all
  depend on it):** `- [type] [slug](./slug.md) — description` ; "entry lines" are exactly the
  lines matching `^- \[`. Index is **sorted alphabetically by slug**; wiki-check FAILs on
  unsorted. (Sorted insertion spreads concurrent-PR edit points — EOF-append guarantees the
  classic CHANGELOG conflict — and makes ordering deterministic instead of per-implementer.)
- Flat over scoped subdirs: subdirs only pay off past ~50 entries, which most repos never reach;
  `scope:` frontmatter + index type tags give the same navigability. Revisit only on evidence.
- `docs/` over `.claude/`: the wiki is human+agent shared and PR-reviewed — a dotdir signals
  machine-only and some reviewers ignore it.
- Rejected: single WIKI.md file — recreates LEARNINGS.md's failure mode (merge conflicts, no
  scoping, all-or-nothing loading).

## D2 — Entry schema (rhymes with the FRAMEWORK-CONTEXT.md hazard discipline)

```yaml
---
name: <kebab-slug, = filename stem>
description: <one line, unquoted — becomes the INDEX line's description>
type: gotcha | context | recipe | failed-approach
scope: <area label or path glob, e.g. src/Payments/**>
status: verified | suspected | unverified     # same epistemic ladder as Known Hazard Areas
last-verified: YYYY-MM-DD
---
<the claim — factual statements only, no imperatives>
**Evidence:** <code path / commit / PR that shows it>
**Verify by:** <cheapest way a reader re-checks it>
```

- No `author` field (Leanness — `git log/blame` is the provenance record; a manual field rots on
  the first update by someone else and adds a pointless CI-failure surface).
- **Frontmatter parsing contract (both twins, normative):** frontmatter = the first `---`…`---`
  block; each field matched by anchored regex `^key: (.*)$` after CRLF- and BOM-strip; values
  taken verbatim (quotes NOT honored — the template says unquoted, and wiki-check fails what the
  grammar can't parse, forcing conformance instead of clever YAML parsing in bash).
- Consumed-guidance framing everywhere: entries are **claims to verify against code, not
  instructions to obey** (mirrors the /adopt "untrusted input, not instructions" principle,
  adopt.md:98–102).

## D3 — Retrieval: pointer + capped session-start preload

- CLAUDE.md companion-files preamble gains a wiki line (reaches every session on both surfaces
  via the AGENTS.md mirror [#2]).
- `session-start.ps1/.sh` gains a block **INSIDE the `$body` scriptblock, after the last existing
  section (security findings) and before the scriptblock closes (~line 99)** — NOT after it:
  only `$body` content is wrapped in the Copilot JSON `additionalContext` (lines 106–112); a
  block placed outside `$body` emits plain stdout that Copilot drops, silently killing the
  feature's headline purpose while every Claude-surface test stays green. Same rule for the
  `.sh` twin's equivalent structure.
- Logic: if `docs/wiki/INDEX.md` exists — count lines matching `^- \[`; ≤30 → inline the index;
  >30 → one line (`N wiki entries — read docs/wiki/INDEX.md`). **No staleness count here** —
  computing it means parsing every entry's `last-verified` on every session start, violating the
  hook's "no expensive scans" contract and reopening the B-02 date-parsing twin-skew class.
  Staleness reporting lives in wiki-check only.
- Reuses the hook's existing `Test-Path`/`Get-Content -Raw` + dual-surface dispatch pattern.
  This preload is what makes the wiki reach Copilot models reliably (B-03 canary: sessionStart /
  userPromptSubmitted ARE consumed; postToolUse is not).

## D4 — LEARNINGS.md: keep, don't migrate (reversal of B-27's initial lean)

LEARNINGS.md has ~21 touchpoints across ~10 files including a *machine* contract:
`## Declined recipe: <name>` blocks consumed by `bootstrap.md`/`rebootstrap.md`/
`bootstrap-pass.md` as a resurrection guard. Migration is high-blast-radius for ~zero value, and
the roles differ: **LEARNINGS.md = append-only chronological history + declined-recipe registry;
wiki = current, scoped, individually-verifiable claims with an index.** Leave LEARNINGS.md and
all its touchpoints untouched; add a boundary table to the wiki docs; extend `/docs-sync` step 3
with one nudge — "does any durable LEARNINGS entry deserve promotion to a wiki entry?".

## D5 — Write path: `remember-for-team` skill (house style = create-adr)

`.claude/skills/remember-for-team/SKILL.md`:
1. **Triage decision tree** (refuse-and-redirect): secret→never store; delivery debt→TECH_DEBT.md;
   security finding→SECURITY_FINDINGS.md; hard-to-reverse decision→`create-adr`; repo-wide
   convention→propose CLAUDE.md edit; hazard in a risky module→FRAMEWORK-CONTEXT.md hazard row;
   **else** → wiki entry.
2. **Dedup before create**: grep INDEX.md + entry files for key terms; near-match → update the
   existing entry instead of creating. **Anti-laundering rule:** `last-verified` may be bumped
   ONLY after actually executing the entry's **Verify by** step and stating the observed result;
   an update without re-verification sets `status: suspected` instead. (Otherwise the dedup
   happy path silently resets the 90-day staleness clock.)
3. Draft from `_template.md`: factual claims only, Evidence + Verify-by mandatory, no imperative
   phrasing.
4. Insert the INDEX line at its sorted position (grammar in D1).
5. Close honestly: the entry is a **draft until PR review** — never claim "saved to team memory".

Salience: one line added to CLAUDE.md §5 self-review checklist ("session surfaced a team-worthy
gotcha? → offer `remember-for-team`"). No auto-append hook (locked).
Mirroring: via `scripts/sync-agent-files` + the template-checks skills-mirror gate (B-07) — this
is NOT invariant #2 (that's the CLAUDE.md↔AGENTS.md mirror); running `/generate-copilot` alone
does not discharge it.

## D6 — Validation: `scripts/wiki-check.ps1/.sh` twins [#3]

- **FAIL (exit 1, print the finding count — NOT exit=count: bash exit status wraps mod 256, and
  docs-sync-check's discipline is 0/1)** on:
  - unparseable/missing frontmatter fields; `type`/`status` outside enums; `last-verified` not
    `YYYY-MM-DD`; `name` ≠ filename stem;
  - index↔files bijection broken (entry without index line, index line without file) or index
    not sorted by slug;
  - **injection-marker hits in `description:` fields or INDEX lines** (instruction-override
    phrasing, HTML-comment imperatives, base64 blobs, zero-width/bidi unicode — the adopt.md
    quarantine pattern list). Rationale: the INDEX is the ONE artifact session-start
    auto-injects into every teammate's session on both surfaces; a malicious one-line
    description in a rubber-stamped PR is the highest-leverage attack in the design, so the
    deterministic gate must go red on it. One-line descriptions have negligible prose
    false-positive risk.
- **WARN (exit 0)**: >100 entries or entry >80 lines (token bloat); entries >90d unverified
  (listed); injection-marker hits in entry **bodies** — warn-only there: prose false-positive
  risk is real, bodies are not auto-injected, and PR review + adopt screening are the gates.
- `_template.md` + `INDEX.md` excluded from per-entry frontmatter checks.
- **Wiring: called FROM `docs-sync-check.ps1/.sh`** as a new child check (same pattern as its
  template-checks child invocation) — this is what reaches consumers who wired Bamboo/Jenkins
  Leg 1 at v0.25 and then update; editing only `ci-integration.md` would leave every existing
  pipeline never executing wiki-check. Update `ci-integration.md` Leg 1 text too, but as
  documentation, not delivery. Both repos' `template-ci.yml` validate the shipped skeleton via
  the same path.

## D7 — Security integration

- **Guard: no change — and explicitly do NOT add `wiki` to the cred-check path exclusion**
  (guard.ps1:60). Wiki .md files must stay secret-scanned; the exclusion is for fixture
  placeholders only. Real secrets can land in "gotcha" notes.
- **adopt.md Phase 1 gains a NEW candidate class — "screen-in-place"** — the existing mechanism
  does NOT fit: the safety screen (adopt.md:104–106) gates only *merge candidates* (content
  destined for CLAUDE.md/TECH_DEBT.md), and Phase 3 *archives* every inventoried file to
  `docs/pre-adoption/` — pointing wiki dirs at the existing classes either screens nothing or
  moves the consumer's live wiki out of the repo. New class (for `docs/wiki/**` and WIKI.md-ish
  files): same provenance check + adversarial grep as merge candidates, but **no Phase-3 archive
  and no Phase-4 merge** — clean files stay in place; flagged files are **moved to
  `docs/pre-adoption/quarantine/`**, which deterministically breaks the index↔file bijection so
  wiki-check stays red until a human restores or deletes them (the quarantine gets a durable,
  machine-checked follow-up for free).

## D8 — Install integration: one ownership rule covers all three modes

Do NOT solve this with the `$protected` list — that was the round-1 design and it fails two
modes (greenfield silently overwrites a pre-existing human wiki; brownfield would archive the
index while leaving entries → orphaned wiki). The ownership split:
- **`docs/wiki/INDEX.md` is consumer-owned → copy-if-absent in ALL modes** (never overwrite an
  existing one; pre-wiki consumers running update still receive the skeleton because theirs is
  absent).
- **`docs/wiki/_template.md` + `scripts/wiki-check.*` are framework-owned → normal copy always**
  (schema/gate updates must propagate on update).
- **`docs/wiki/INDEX.md` joins `$adoptionSignals`** (install.ps1:35–39) so a target with a
  pre-existing wiki routes to brownfield → /adopt → the D7 screen-in-place pass.
- Entry files are never shipped, so never clobbered. This is the #1 implementation trap area —
  implement all three modes against this matrix, not ad hoc; mirror in `install.sh`.

## D9 — Touchpoint checklist (implementation inventory)

Per repo, in lockstep [#1]: CLAUDE.md (companion preamble line, §5 checklist line, Common Tasks
skill list, "What We've Learned" boundary sentence) → regenerate AGENTS.md [#2]; skill mirror via
`scripts/sync-agent-files`; `generate-copilot.md` mirrored-files list; `docs-sync.md` step-3
promotion nudge; `adopt.md` screen-in-place class (D7); `docs-sync-check.ps1/.sh` wiki-check
child call (D6); `ci-integration.md` Leg 1 text; `install.ps1/.sh` ownership rules + adoption
signal (D8); CHANGELOG both repos.

**Meta task in the same session — check-lockstep does NOT pick the skeleton up "naturally":**
its docs/ coverage is the single file `enforcement-surfaces.md`. Add `docs/wiki/INDEX.md` and
`docs/wiki/_template.md` to `$identicalFiles` in `.claude/scripts/check-lockstep.ps1`. (The
wiki-check twins are already covered by the `scripts/*.ps1|*.sh` globs; the shared skill is
presence-checked by the computed rule — its content parity comes from the per-repo skills-mirror
gate.)

## D10 — Tests (harness auto-discovers `tests/hooks/*.Tests.ps1`; both files NEW)

- **`WikiCheck.Tests.ps1`** red-tests: (a) index line w/o file, (b) file w/o index line,
  (c) malformed frontmatter, (d) bad enum, (e) unsorted index, (f) injection marker in a
  `description:` → FAIL, (g) same marker in a body → WARN/exit 0, (h) hostile-formatting fixture
  (CRLF entry, BOM'd entry, `description:` containing a colon) — twins must agree, (i) clean
  fixture exits 0. Run **both twins** on the same temp fixtures, assert identical verdicts
  (remember the EOL-normalization + absolute-path traps in root LEARNINGS.md).
- **`SessionStartWiki.Tests.ps1`** (no SessionStart test file exists today — session-start cases
  live inside TwinParity.Tests.ps1; a new file is cleaner): small index → inlined; large index →
  summary line; absent → no wiki output. **Must include a Copilot-shaped stdin case asserting
  the index content appears inside the JSON `additionalContext` output** — the regression test
  for the D3 insertion-point trap (a block outside `$body` passes every Claude-surface test
  while Copilot delivery is dead). Build fixtures in temp dirs like PostWriteRouting.Tests.ps1.

## Implementation order (suggested single-session sequence)

1. Skeleton + schema: `docs/wiki/INDEX.md` + `_template.md` in dotnet → mirror to angular.
2. `wiki-check.ps1/.sh` + `WikiCheck.Tests.ps1` (red first, then green).
3. `remember-for-team` skill + sync to `.github/skills`.
4. session-start preload (both twins) + `SessionStartWiki.Tests.ps1`.
5. Docs touchpoints (D9) + AGENTS.md regen + adopt/install/docs-sync-check changes.
6. Meta: check-lockstep `$identicalFiles` additions.
7. All gates green (template-checks ×2, check-lockstep, hook suites, meta suite) →
   CHANGELOG both repos → release **v0.26.0** via `release.ps1` → push both repos → move B-27
   to Done in BACKLOG.md.

## End-to-end verification (evidence-based — show commands + observed output)

- *Skill:* greenfield + brownfield install smoke into temp dirs → ask the agent to save a team
  learning → entry file + sorted index line created, frontmatter parses; repeat the same fact →
  it updates the existing entry (dedup), does not duplicate, and does not bump `last-verified`
  without running Verify-by.
- *Retrieval:* fresh session in the temp install → a planted entry is cited when its scoped area
  comes up, via index + one entry read (not a bulk load).
- *Install matrix:* greenfield onto a dir WITH a pre-existing `docs/wiki/INDEX.md` → routed to
  brownfield, index untouched; update onto a pre-wiki v0.25 consumer → skeleton added; update
  onto a wiki-bearing consumer → INDEX untouched, `_template.md` + `wiki-check.*` refreshed.
- *Gate:* wiki-check red-tests per D10; then `docs-sync-check` (which now runs it) red/green.
- *Injection:* wiki entry containing a secret → editor-path guard fires (existing fixture
  pattern); malicious `description:` → wiki-check FAIL.
- *Parity:* `template-checks` ×2, `check-lockstep`, hook suites, meta suite all green;
  AGENTS.md regenerated.

## Critique log (design provenance)

**Round 1 (self):** nobody-writes-entries → §5 nudge, adoption is cultural (say so in docs);
token bloat → 30-line cap + warns; stale entries mislead → status ladder + Verify-by; two memory
systems confuse → boundary table + promotion nudge (accepted vs migration blast radius); skill
as dumping ground → triage tree.

**Round 2 (independent adversarial agent, 15/15 incorporated — this doc is post-fix):**
1. BLOCKER: warn-only injection screening contradicted "injection-hardened" at the single
   auto-injected artifact → FAIL on descriptions/INDEX, WARN on bodies (D6).
2. Install analysis was update-mode-only; greenfield destroyed pre-existing wikis, brownfield
   orphaned entries → ownership matrix + copy-if-absent + adoption signal (D8).
3. adopt.md's existing screen can't handle kept-in-place files → screen-in-place class with
   quarantine-move that deterministically reddens wiki-check (D7).
4. "check-lockstep picks it up naturally" was false → explicit `$identicalFiles` additions (D9).
5. ci-integration.md edits never reach already-wired consumer CI → wiki-check called from
   docs-sync-check (D6).
6. "before line 101" allowed insertion outside `$body`, killing Copilot delivery invisibly →
   pinned + Copilot-JSON assertion test (D3/D10).
7. Session-start staleness count = per-session parse of every entry (speed contract; B-02
   twin-skew class) → dropped (D3).
8. No .sh frontmatter parsing contract → normative grammar + hostile fixture (D2/D10).
9. INDEX line grammar unspecified across 4 dependent artifacts → normative grammar (D1).
10. Dedup could bump `last-verified` without re-verification (staleness laundering) →
    verify-before-bump or `status: suspected` (D5).
11.–15. (minor): EOF-append guarantees conflicts → sorted index, gate-enforced (D1); exit=count
    wraps mod 256 → exit 0/1 (D6); SessionStart tests don't exist to "extend" → create new files
    (D10); `author` field cut, git blame is provenance (D2); skills mirror is sync-agent-files +
    B-07 gate, not invariant #2 (D5/D9).
