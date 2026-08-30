# B-196 — BOM-prefixed disabled-skill ledger

**Date:** 2026-08-30  
**Filed against:** v0.78.3  
**Planned:** v0.79.0
**Status:** COMPLETE 2026-08-30 — independent immutable review approved and exact supported-host run
`33333912064` at `dbdc38f508463c3c2fa7cb3d55d830deb7cd014b` green; planned v0.79.0

## Independent immutable completion review

Blind-first reviewer `/root/b196_blind_immutable_review` (Codex GPT-5; no implementation
participation) read frozen contract `ca8b79a`, reviewed exact implementation `ca8b79a..49420ad` and
its survival at `dbdc38f`, then mutated one final octal BOM byte in a detached clone. Only the
existing Bash skill-reconciliation result failed (50/1); PowerShell stayed green. Exact-byte
restoration returned UpdateDelivery 51/0 under PowerShell 7 and native Windows PowerShell
5.1/CP437. Direct boundaries were 15/15, InstallerConvergence 12/0, all validators and Bash syntax
passed, protected bytes were unchanged, and authored/all-dist installers shared SHA-256
`4e1ec9bc474af61aa4f098ffd8555f121ee0a00aef7c9473bf955dd0a4c6e282`. Run `33333912064` is
attributed native-Linux corroboration only; BSD/macOS and Bash 3.2 were not executed or required.

## Value decision

Do B-196. `LEARNINGS.md` is a protected consumer file and the installer already treats an exact
`## Disabled framework skill: <name>` heading as durable operator intent. Windows PowerShell 5.1's
normal UTF-8 writer can place the standard UTF-8 BOM at the start of that file. Treating those
encoding bytes as heading content makes the Bash installer silently reactivate a deliberately
disabled framework skill, while the PowerShell installer recognizes the same file. Review also
reproduced the same consequence for trailing whitespace already admitted by the Bash heading
grammar: prefix-only extraction leaves spaces or CR attached to the name, so exact lookup misses it.
These are reachable cross-host policy violations in one parser and remain P1.

Challenge the backlog's proposed new “subject,” however. The existing UpdateDelivery fixture and
its skill-reconciliation result already execute the exact product path and assert that `perf` stays
inactive. Making that fixture deterministic BOM input is more discriminating than adding another
installer child. InstallerConvergence independently retains the ordinary no-BOM control. Add no
suite and no `It` result.

## Behavioral contract

1. A single standard UTF-8 BOM at the start of `LEARNINGS.md` is an encoding marker, not part of the
   first record. The Bash installer must recognize the same exact disabled-skill headings as it
   recognizes in a BOM-less file.
2. Remove the marker only from the first record of the parsing stream. Do not rewrite, normalize, or
   otherwise change the protected consumer file.
3. Preserve the existing anchored, case-sensitive heading and skill-name grammar, including its
   existing trailing-whitespace allowance. Extraction must emit only the captured `[a-z0-9-]+`
   name, without admitted spaces or a CRLF carriage return.
4. Do not accept leading spaces, alternate heading levels, alternate casing, arbitrary Unicode
   zero-width characters, a BOM on a later record, or malformed/doubled BOM bytes as syntax.
5. A genuine no-match is an empty disabled ledger. If a file selected for parsing disappears,
   becomes unreadable, or a parsing stage fails, the pipeline must fail before target mutation
   rather than silently reactivate every skill. Preserve the intentional absent-file skip.
6. Preserve ordinary BOM-less behavior and PowerShell behavior. No other `LEARNINGS.md` reader or
   installer policy changes in B-196.

## Red-first, value-bounded oracle

In `UpdateDelivery.Tests.ps1`, change `New-LegacyConsumer` to write `LEARNINGS.md` with
`[Text.UTF8Encoding]::new($true)`, explicit CRLF, and a trailing ASCII horizontal tab after `perf` on
every host. The tab makes the historic prefix-only extraction fail even where Git Bash masks a CR;
native Linux observes both. Construct the producer text with an explicit `` `t`` escape and spell
the complete expected byte array independently rather than deriving the oracle from that same
text. Capture the pre-install bytes, require their exact equality (including one `EF BB BF`, `23`
next, the admitted tab, and CRLF), and require the protected file to remain byte-identical inside
the existing protected-document result. Keep the existing per-twin result that requires
`.claude/skills/perf` to be absent and
`.claude/disabled-skills/perf/SKILL.md` to exist.

Against the unchanged Bash installer, require exactly the existing Bash skill-reconciliation result
to fail while the PowerShell result remains green. The suite cardinality remains 50. The existing
InstallerConvergence fixture continues to write BOM-less UTF-8 and must remain green for both twins,
so the BOM case does not replace the ordinary control.

## Bounded implementation

Change only the authored Bash installer's disabled-ledger parsing pipeline. In a C locale, stream
`LEARNINGS.md` through a first-record substitution that removes the exact three UTF-8 BOM bytes,
using Bash-3.2-safe ANSI-C octal quoting, as its own `pipefail`-visible stage. Feed that into a
second, ambient-locale `sed -n -E` stage whose single anchored capture both enforces the existing
heading grammar and emits only `[a-z0-9-]+`, removing admitted trailing whitespace/CR. A no-match
naturally emits nothing with status zero, while `pipefail` propagates a read or tool error. This is
smaller and less error-prone than preserving the historic `grep || true` plus prefix-only `sed`
topology. Reuse the installer's existing `sed` dependency; add no parser, temporary file, or write
to the consumer file. Leave the PowerShell installer unchanged, then compose all three
distributions.

## Verification and completion boundary

- Observe the focused red first, then 50/0 under PowerShell 7 and native Windows PowerShell
  5.1/CP437 with Bash actually executed.
- Run InstallerConvergence, composer parity, all three distribution validators, Bash syntax, test
  AST/BOM, source/dist hashes, and the relevant backlog/doc gates.
- Before full-installer closure, use bounded direct byte-pipeline probes: one BOM at offset zero and
  BOM-less input emit the exact name; doubled, partial, later-record, and leading-space BOM variants
  emit no name (malformed bytes may instead fail closed on BSD `sed`); a selected input that
  disappears or is unreadable remains nonzero under `pipefail` while the product's outer
  absent-file guard remains unchanged.
- In isolated exact-candidate copies, first remove only the BOM substitution and then separately
  restore prefix-only name extraction. Each mutation must make the same Bash skill-reconciliation
  result fail while PowerShell remains observed; restore bytes and return 50/0.
- Obtain an independent immutable-candidate review. Because a test is modified, the exact candidate
  is not complete and cannot release until its first Windows/Linux CI run is green; Git Bash is not
  Linux evidence.
