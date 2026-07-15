# B-35 design — Derive, don't assume: persistence-stack neutrality (LOCKED 2026-07-15, WSD-020)

> **Status: DESIGN LOCKED.** Implement as specified; deviations need a new WSD entry.
> Trigger: consumer dev-team feedback (2026-07-15) — *"the framework goes with EF Core even
> though the back end is MongoDB; it should have derived things from the codebase."*
> Implementer: read root `CLAUDE.md` (meta-invariants #1–#7) and `DEVELOPING.md` first.
> Ship via `.claude/scripts/release.ps1` [#7].

---

## 1. Problem

The dotnet (and monorepo) dist hard-codes **EF Core** as the assumed persistence layer in
artifacts that are live *regardless of what the consumer's codebase actually uses*. On a
MongoDB backend the framework actively pushes EF Core advice. This is a defect on a supported
configuration: the dist targets ".NET web API", not ".NET web API on a relational store".

## 2. Evidence (verified 2026-07-15 against src/, v0.26.4)

Ranked by harm:

1. **`boy-scout-check` hook, heuristic #3 — deterministic misfire.**
   `src/stacks/dotnet/files/.claude/hooks/boy-scout-check.ps1:67-71` (+ `.sh:56-59` twin, + both
   monorepo siblings) flags any file containing `.ToListAsync(|FirstOrDefaultAsync(|SingleOrDefaultAsync(|AnyAsync(|CountAsync(`
   without `AsNoTracking` as a *"read-style EF Core query without AsNoTracking()"*.
   **MongoDB.Driver exposes those exact method names** (`IAsyncCursorSourceExtensions.ToListAsync`,
   `IMongoQueryable` LINQ extensions). On a Mongo codebase the hook nags on effectively every
   query file, telling developers to add an **EF-only API** to Mongo code. This alone plausibly
   generated the consumer feedback — it fires on every write, pre- or post-bootstrap.
2. **`docs/defaults.md` > Data Access — unconditional EF Core defaults.**
   `src/stacks/dotnet/files/docs/defaults.md:23-26` (+ monorepo sibling): "EF Core with
   repository pattern…", "Always use `.AsNoTracking()` for read-only queries." These apply
   whenever CLAUDE.md > Conventions is unbootstrapped — i.e. exactly the cold-start window where
   the agent has no codebase-derived counterweight. Test-shape line 55 also names EF Core.
3. **`/bootstrap` A2 — closed detection list.**
   `bootstrap.md:50` (dotnet; `:61` monorepo): "ORM — EF Core / Dapper / both; DbContext
   organisation". A document store isn't representable in the pass's own vocabulary, so even a
   *bootstrapped* Mongo repo gets its persistence analysed through an EF/Dapper frame, plus
   sub-bullets ("Migration management", "missing includes, untracked-query opportunities") that
   are relational-only.
4. **`add-entity` skill — unconditional EF recipe.**
   `src/stacks/dotnet/files/.claude/skills/add-entity/SKILL.md` (+ `.github` mirror, + monorepo
   siblings): triggers on "add a new entity backed by a new database table" and walks
   IEntityTypeConfiguration/DbSet/migration steps with no evidence gate. Pre-bootstrap it is
   live as-is; post-bootstrap, 3a's skill audit says "delete defaults that don't apply" but
   names no persistence check, so it survives in practice.
5. **`.github/copilot-instructions.md` shipped default** — "don't wrap DbContext for its own
   sake" (`:29` dotnet, `:24` monorepo). Cold-start only (regenerated from CLAUDE.md after
   bootstrap), but it's the *inline-completion* surface, where a wrong prior is invisible.
6. **Minor, example-level (fix opportunistically, do not scope-creep):** `security-auditor.md`
   UPDLOCK/`FromSqlRaw` phrasing; `lean-test` #12 "EF Core can read its own writes" (fine — it's
   an example of *not* testing the framework, harmless on Mongo); README/playbook prose naming
   EF Core as illustration (fine).

MongoDB/Cosmos/NoSQL appear **zero** times in `src/` today (grep-verified).

## 3. Root cause

Not "missing Mongo support" — the defect is that **technology-specific guidance is not
evidence-gated**. The framework's own doctrine already says the right thing (bootstrap 3a:
"record observed reality"; Verification Rules; defaults.md header: "cold-start scaffolding
only") but four artifact classes (hook, defaults, bootstrap pass, skill) assert EF Core
unconditionally. Tomorrow the same class of bug is Dapper-on-Marten or xUnit-on-NUnit.

## 4. Approaches weighed

- **A. Evidence-gate every technology claim (CHOSEN).** Add one always-loaded core rule +
  make the four artifact classes conditional on detection. Generalizes beyond Mongo; no new
  dists; smallest shipped-token delta.
- **B. Add a MongoDB stack/dist.** Rejected: wrong altitude. Multiplies composer/CI surface the
  merge just paid to shrink; fixes one technology while leaving the assumption mechanism intact;
  a stack ≠ a persistence choice (dotnet+Mongo is still the dotnet stack).
- **C. "Run /bootstrap and it sorts itself out."** Rejected as sole fix: the hook misfires
  regardless of bootstrap; defaults.md/skills are deliberately live pre-bootstrap; and A2's
  closed list biases bootstrap's own output EF-ward.

## 5. Locked design

### D1 — Core rule: technology claims must be evidence-gated
Add to the **Conventions preamble area of `src/core/CLAUDE.md`** (exact placement: implementer
picks the spot that composes into all three dists once — likely a new numbered Verification
Rule via the `verif-rules` stack snippets, since those are per-stack): one rule, ~3 lines:

> **Derive, don't assume.** Before applying or recommending any technology-specific rule or
> recipe (ORM/data access, validation, HTTP client, test framework, state management), verify
> that technology is actually present in this repo (package reference, import, config). If the
> technology a default or skill assumes is absent, say so explicitly and derive the convention
> from what the codebase actually uses instead.

Keep it stack-neutral in core if possible; if the snippet layout forces per-stack copies, keep
wording identical across the three (monorepo = superset rule, same text). Mind the CLAUDE.md
token budget — this is one rule, not a section.

### D2 — `defaults.md` Data Access becomes conditional
Dotnet + monorepo `docs/defaults.md` (angular has no ORM section — check for equivalent
assumptions, e.g. HttpClient/interceptors are safe as they're framework-intrinsic): restructure
`### Data Access` into evidence-keyed blocks, lean:

- Opening line: "Data-access defaults are conditional on what the repo evidences (csproj
  package references). Apply only the matching block; if none match, ask."
- **If EF Core** (`Microsoft.EntityFrameworkCore*`): current three bullets unchanged.
- **If Dapper**: parameterized queries only; SQL lives in the application layer; no dynamic SQL
  concatenation.
- **If MongoDB.Driver**: typed collections via a small registry (no magic strings); review
  indexes when adding a new query shape; multi-document transactions only where the deployment
  supports them (replica set) — otherwise design idempotent single-document writes; use
  projections for read-heavy queries (the `AsNoTracking` analogue).
- **If none detected**: greenfield — ask the developer before introducing a data-access stack.

Also fix the `### Test shape` line 55: "Cross-cutting paths (routing, model binding, **data
access**, auth, serialization)" — drop the hardcoded "EF Core".

### D3 — `/bootstrap` A2 opens its detection list
Dotnet + monorepo `bootstrap.md` A2 retitled "Domain & Data Access" content:

- Replace "ORM — EF Core / Dapper / both; DbContext organisation" with:
  "Persistence — detect from package references and DI registrations: EF Core / Dapper /
  ADO.NET / MongoDB.Driver / Cosmos / Redis / other / none. Name what is present; never assume
  a technology the csproj does not evidence."
- Make relational-only sub-bullets conditional: "If relational/EF: migration management, N+1,
  missing includes, untracked-query opportunities. If document store: collection/index
  conventions, query-shape vs index alignment, transaction/consistency assumptions."
- Add one synthesis guard to **Phase 3a Conventions bullet**: "The Conventions section must not
  name a technology the analysis passes did not evidence in this repo."

### D4 — `add-entity` gains a Step 0 evidence gate; bootstrap 3a audit names persistence
- `add-entity/SKILL.md` (dotnet `.claude` + monorepo `.claude`; `.github` mirrors are synced by
  script — confirm, don't hand-edit if generated): new Step 0: "Confirm this repo persists via
  EF Core (Grep for `DbContext`/`Microsoft.EntityFrameworkCore`). If it does not, STOP — this
  recipe does not apply. Find the repo's actual persistence pattern (e.g. an existing
  entity/collection pair) and mirror it, or use the project-specific skill `/bootstrap` created."
  Frontmatter description gains "EF Core repos only — verifies before scaffolding" phrasing so
  the trigger itself carries the constraint.
- Bootstrap **3a Common Tasks audit** gains an explicit line: "Persistence check: if the repo's
  data access is not EF Core, delete or replace `add-entity` with a project-specific equivalent
  mined from the actual pattern (A8 candidate)."

### D5 — `boy-scout-check` heuristic #3 requires EF evidence
All four files (dotnet + monorepo × `.ps1`/`.sh` [#1][#3]): heuristic #3 additionally requires
EF evidence **in the same file** before flagging: match `using Microsoft.EntityFrameworkCore`
OR `DbContext` OR `DbSet<`. Message unchanged. Update/extend the hook test fixtures: one new
red case (Mongo-style `ToListAsync` file → **no** finding) and keep the existing green case
(EF file without AsNoTracking → finding). Both twins, byte-equal rendered output where the
suites check it (B-34 overlap — don't fix B-34 here, just don't add new divergence).

### D6 — `copilot-instructions.md` shipped default line
Dotnet + monorepo: change "Repository pattern only where it adds value; don't wrap DbContext
for its own sake." → "Repository pattern only where it adds value; don't wrap the data-access
layer for its own sake." (Generic; still true for EF.)

## 6. Out of scope (explicit)

- No MongoDB dist/stack, no Mongo-specific skills beyond the defaults.md block (D2).
- No rewrite of README/playbook narrative prose that uses EF Core as an *illustration*.
- No angular-side changes unless the implementer finds an equivalent unconditional-technology
  claim there (report it; don't invent work).
- B-34 (rendered twin parity) stays its own item.

## 7. Acceptance criteria

1. Grep proof: no artifact in `dist/*` *instructs* EF Core usage unconditionally (defaults,
   skills, hooks, bootstrap passes). Illustrative prose may remain.
2. Hook fixture: a file with `ToListAsync` + no EF markers produces **zero** boy-scout findings
   on both twins, both dists that carry the hook.
3. `/bootstrap` A2 text names document stores; Phase 3a carries the no-unevidenced-technology
   guard; `add-entity` has the Step 0 gate in every dist that ships it.
4. All standard gates green: `build.ps1` ×3 + dist freshness, `validate-dist` ×3, hook suites
   ×3 + meta suite. Version bumped + both changelogs (root = ours with B-35/WSD-020; shipped =
   consumer voice: "the framework no longer assumes EF Core; data-access guidance is derived
   from your codebase") [#7].

## 8. Effort / invariants

**M** (one session). Invariants touched: #1 (monorepo siblings for every dotnet file above),
#2 (mirror regen via rebuild), #3 (hook twins), #6 (no tracking ids in shipped text), #7
(release.ps1). Suggested version: **v0.26.x defect fix** — candidate to ship *before* B-27
since it is consumer-reported incorrect behavior.
