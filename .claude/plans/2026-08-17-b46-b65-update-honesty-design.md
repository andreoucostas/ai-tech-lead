# B-46 (update honesty) + B-65 (defaults tier) — LOCKED after critique

**Status:** **LOCKED 2026-08-17.** The first draft's central mechanism was rejected and replaced.
Critique: `.claude/plans/2026-08-17-b46-b65-sol-critique.md`. Target v0.56.0.

## 1. What was measured

**B-46 question (1), answered by experiment:** an update **silently clobbers** every consumer edit to
shipped machinery — skills, hooks, `scripts/`, and `.claude/settings.json` — while printing
*"Framework machinery refreshed; consumer-owned content files untouched."* Protected files and
consumer-**added** files survive correctly. Recorded in the backlog with the method.

**The first design then proposed the wrong fix, and a second measurement killed it.** It would have
compared each incoming file against the installed copy and reported the differences as "local
modifications". But a difference means a consumer edit **or an ordinary framework version change**,
and the second is overwhelmingly more common. Measured: install v0.51.0, touch **nothing**, compare
against the current dist —

```
consumer touched NOTHING; shipped files differing from current dist: 31
  .claude/agents/security-auditor.md, .claude/hooks/audit-trail.{ps1,sh},
  .claude/skills/add-component/SKILL.md, AGENTS.md, CLAUDE.md, .claude/settings.json, ...
```

All 31 would have been reported as consumer modifications. All 31 false. A warning that is ~100%
noise on a realistic upgrade trains consumers to ignore it, which is worse than no warning. **The
detector is dropped.** (The first experiment only looked convincing because it updated with the same
dist version, so every difference *was* a consumer edit — the confound was in my method, not the
data.)

Three further guaranteed false positives, independent of version gap: `.claude/settings.json` is
**host-adapted at install** (rewritten for the available interpreter), refreshed skills get a
consumer exemplar line appended, `origin: discovered` skills and disabled skills are deliberately
restored, and `.github/skills` is regenerated. These files are *supposed* to differ from their dist
copies.

## 2. What ships instead (materially smaller, and true)

**a. Unconditional preflight disclosure, before the first mutation.** Not a detector — a statement of
the contract, which is always accurate and needs no baseline:

> this update replaces framework-owned files, **including `.claude/settings.json`**; commit, stash or
> copy any local edits to them first; review the resulting diff before committing.

It must print **before** anything is written. Detection after destruction is notification, not
recovery — and the installer neither requires git nor a clean tree, so "recover from git history" is
a promise we cannot keep. Do not make it.

**b. One rolling pre-overwrite backup of `.claude/settings.json`.** It is the sharpest observed case
and the only file that is simultaneously shipped machinery and *documented committed team config*
(v0.38.1). A single documented backup path, overwritten each update, named in the output. This gives
recovery without git and without a general archive lifecycle.

**Not skipped**, wholesale or otherwise: `settings.json` carries hook registrations that must evolve,
and withholding them is B-97's failure mode — an update that does not update. Backup-then-refresh is
the middle that keeps both properties.

**c. Fix the closing line.** *"consumer-owned content files untouched"* must name the files it means
or stop claiming untouched-ness it does not provide.

**d. Ownership, stated in three classes** (in the README and the WSD, because the current docs imply
two): consumer-owned protected paths (restored), framework-owned machinery (overwritten), and
**mixed-ownership `settings.json`** (backed up, then refreshed and host-adapted).

## 3. B-65 — DROP the pointer; ship only the documentation correction

The proposed carrier was a line in `CLAUDE.md`. **`CLAUDE.md` is protected**, so update restores the
consumer's copy and the line reaches **new installs only** — it would miss precisely the installed
population it exists to help. That is B-97's wall, and it makes the fix self-defeating. Putting it in
the unprotected framework-rules carrier would travel, but spends always-on context for a benefit the
2026-07-31 measurement says is **unmeasured** (an agent opened the file unaided in a valid run).

**Ship only:** the missing tier row in `docs/enforcement-surfaces.md`, which today defines
*Guaranteed* and *Instructed* and is silent about a whole delivery mode. Add an honest
**On-demand / discoverable** definition — loading is task- and model-dependent, not guaranteed —
with `docs/defaults.md` as the example. Claim no routing improvement.

## 4. Definition of done

1. Preflight text is asserted to appear **before** the first mutation; completion text only on
   exit 0. (A prior defect copied files then aborted before the banner — ordering is not cosmetic.)
2. The settings backup is written before overwrite, its path named in output, and it round-trips:
   a consumer edit is recoverable from it after an update.
3. Both twins, identical text and exit codes [#3]. Bash 3.2-safe.
4. Legal-file policy (v0.54.0) is **unchanged** — regression assertions that its refusal messages and
   exit codes still hold.
5. `UpdateDelivery.Tests.ps1` gains these cases; it is the suite that owns update behaviour and whose
   gap let this sit unverified, because it asserted what arrived and never what was lost.
6. Docs updated together, or the contract goes stale in five places: root `README.md`, all three
   stack READMEs (monorepo sibling included [#1]), both installer header comments, and a WSD in
   `meta/workspace-decisions.md` recording the three ownership classes and this policy.
7. Install smoke: greenfield + brownfield + update, three dists, both twins.
8. Four changelog heads before `release.ps1` [#7]. The consumer entry must say plainly that **past
   updates may already have discarded local edits** to shipped files.
9. CI green on both legs.

## 5. Division of labour

codex implements from this locked spec; Claude reviews, re-runs every red-test, owns git and release.
