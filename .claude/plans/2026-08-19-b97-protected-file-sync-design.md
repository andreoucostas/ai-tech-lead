# B-97 remainder — make `Protected-file sync` tell the truth

**Status:** **REV 2 — RE-LOCKED after critique. Implementation authorised.**
**Priority:** P1 (maintainer-designated top priority, 2026-08-19) · **Effort:** S · **Invariants:** #1 #3 #6
**Parent:** B-97 (PARTIALLY DONE) · **Governing decision:** WSD-031
**Critique:** `.claude/plans/2026-08-19-b97-sol-critique.md` — REQUEST CHANGES, five blocking
findings. **Rev 1's central premise — consume `meta/block-manifest.json` — is REJECTED.** Findings
1–4 accepted; finding 5 is dissolved by the new design (no stamp comparison survives).

---

## 1. What is already decided, and must not be re-opened

Read `meta/decisions-index.md` → WSD-031 before proposing anything here.

- **Option A shipped (v0.45.0).** The four framework-owned blocks — Verification Rules, Leanness,
  SOLID, Agentic Workflow — live in one unprotected carrier,
  `.github/instructions/framework-rules.instructions.md`.
- **Injecting the rules from `session-start` is REJECTED** (WSD-031: duplicates the stale copy and
  costs ~7 KB every session). The shipped source says so at the site. Do not propose a variant.
- **Reverting installer protection is REJECTED** — clobbering a bootstrapped `CLAUDE.md` is worse.
- **Boy Scout Rule stays in `CLAUDE.md`**, greenfield-only, permanently. It is **not** one of the
  four blocks and must never be checked here.

## 2. Why rev 1 was wrong (kept, because the correction is the useful part)

Rev 1 proposed shipping the 8 KB fingerprint manifest and classifying each inline block by hash.
The critique killed it on four independently sufficient grounds, all verified directly:

1. **A materially smaller fix was never evaluated.** The row immediately above,
   `Framework rules delivery`, *already* performs the actionable carrier/import check with exact fix
   text (`framework-doctor.ps1:64-69`, `.sh:118-124`). Rev 1 assessed one alternative (compare
   against `coverage.latest-release`) and ignored the one sitting one row up. That is precisely the
   Maintenance model #6 failure the rule exists to catch.
2. **Shipping the manifest violates invariant #6.** Its `purpose` field reads *"…See B-97."*
   (`meta/block-manifest.json:4`) — `scripts/meta-denylist.txt:19` denies `\bB-[0-9]{2}[a-z]?\b`, so
   the composed dist would fail `no-meta-leak`. It also advertises a maintainer-only generator path
   that cannot exist in a consumer repo.
3. **The `.sh` twin cannot implement it cheaply.** `framework-doctor.sh:2` declares *"No jq/python
   dependency by design."* There is **no SHA-256 anywhere in shipped shell** — the only hashing is
   `shasum` (SHA-1) in two unrelated scripts. Nested-JSON querying plus a portable SHA-256 cascade is
   a large new dependency surface for a diagnostic row.
4. **It would not even fix the stated harm.** Rev 1 called a retained inline block `BEHIND`, so the
   population it was meant to relieve would still see a warning — just a differently-worded one.

Rev 1 also overstated the affected population: a fresh v0.45.0+ install returns `OK`. The real
population is *consumers who installed earlier and never hand-edited their `CLAUDE.md` version
stamp* — still effectively every pre-existing consumer, but the precise claim is the one to make.

## 3. The actual defect

```powershell
# dist/*/scripts/framework-doctor.ps1:72-77
if ($claudeContent -and $claudeContent -match '(?m)^\s*version:\s*([^\s]+)\s*$') { $claudeVersion = $matches[1] }
if ($claudeVersion -and ([string]$stamp.version -eq $claudeVersion)) { Row OK 'Protected-file sync' ... }
else { Row MISSING 'Protected-file sync' 'DIVERGED — protected file not synchronized with installed machinery; review required' }
```

The row compares **two version strings** and calls the result a synchronization verdict. After
v0.45.0 that question is meaningless: `CLAUDE.md` is consumer-owned and its stamp is *expected* to
lag. So the row reports `DIVERGED` to pre-existing consumers permanently, names no block, offers no
fix, and cannot see an actual hand-edit. A diagnostic that cries wolf trains people to ignore the
one signal the delivery gap has.

## 4. Design — report the migration state, ship nothing new

**Delete the version comparison.** Recompute `Protected-file sync` from what is already in hand:
the carrier's presence, the import line's presence (both already computed for the row above), and
whether any of the **four** framework block headings still appear in `CLAUDE.md`. No manifest, no
hashing, no JSON parsing, no new shipped bytes.

| Consumer state | Row | Message |
|---|---|---|
| Import present, no framework block headings remain in `CLAUDE.md` | `OK` | migrated — the carrier is authoritative |
| Import present, **but** one or more of the four headings remain inline | `PENDING` | name them: migration incomplete — these duplicate the carrier and may conflict; delete them from `CLAUDE.md` |
| Import absent, or carrier absent | `OK` (silent) | **defer** — `Framework rules delivery` already owns and reports this exact state with its fix text. Do not double-report. |
| `CLAUDE.md` absent | `MISSING` | say so; never silently pass |

**Why this is the right shape, not merely the cheap one.** The unresolved successor question in
B-97 — *does a Claude Code model follow the fresh carrier or the stale inline copy when both are
visible?* — only has force while both copies exist. This row detects exactly that state and tells
the consumer to remove the duplicate. **Removing the conflict is strictly better than measuring who
wins it**, and it is available now, where the measurement needs B-98's six-run rule and real spend.
The shipped `session-start` pointer already instructs *"add … where those sections are, **and delete
them**"* — this row is the check that the instruction was actually followed, which nothing currently
verifies.

**Wording.** Drop `DIVERGED — protected file not synchronized…` from this row: it was settled for a
hash-based verdict that is not being built, and using it for a heading check would overclaim. Say
what was observed — which sections remain, and that they duplicate the carrier.

**Detection.** Match the four headings at line start (`^##\s+Verification Rules` etc.), the same
`## <name>` convention `build-block-manifest.ps1` uses. Both twins can do this with facilities they
already use. **Never match Boy Scout Rule** — it lives there permanently by decision, and flagging
it would be a false positive by construction.

## 5. Tests — red first, both hosts, both twins

Each arm seen to fail on the unfixed tree before its green counts:

1. Import present + all four headings absent → `OK`.
2. Import present + `## Leanness` still inline → `PENDING`, **naming Leanness**.
3. Import present + all four inline → `PENDING`, naming all four.
4. Import present + `## Boy Scout Rule` inline (and none of the four) → `OK`, **not** flagged.
5. Import absent → this row silent/OK; `Framework rules delivery` still reports `MISSING` with its
   fix. Assert no double-report.
6. `CLAUDE.md` absent → `MISSING`.
7. **Vacuity guard:** a fixture where the check inspects zero files, or the heading list is empty,
   must **fail** rather than pass green.
8. Twin agreement: `.ps1` and `.sh` produce the same row and status for arms 1–7.

## 6. Not

- Do **not** touch `session-start` (WSD-031).
- Do **not** ship `meta/block-manifest.json`, or move it. It stays in `meta/`, unread, until
  something legitimately consumes it (Leanness #1). Rev 1's move is withdrawn.
- Do **not** add a `jq`, `python`, or SHA-256 dependency to the `.sh` twin.
- Do **not** make the row blocking — `framework-doctor` reports, it does not gate.
- Do **not** fold in the `copilot-instructions.md` same-class audit named in B-97's RCA. It is real;
  file it separately.
