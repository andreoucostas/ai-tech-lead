# B-174 JSON registration/stamp contract — locked design

**Locked:** 2026-08-31, after reading `meta/decisions-index.md`, reproducing v0.79.1 outcomes,
checking the current Claude and GitHub hook references, and incorporating adversarial critique.

## Proportionality and observed harm

The current doctor accepts a scalar Copilot hook file as healthy, treats unrelated nested
`command`/`bash` fields as active registrations, and diverges between PowerShell and Bash on ASCII
case-colliding keys. The root Bash installer can also select a shallowly probed `jq`, lose a working
Python fallback when the real stamp query fails, and report the stamp invalid. These are deterministic
false OK, false MISSING, twin-divergence, and false actionable diagnosis states on v0.79.1.

The fix is bounded to doctor registration extraction and root update-stamp selection. It is not a
generic JSON framework or full vendor-schema validator.

## Frozen registration-extraction contract

All decisions start with strict JSON syntax. Object-member names are decoded and compared within
each object recursively. Ordinal-distinct names equal after explicit ASCII `A`-`Z` folding are
contract-invalid. Exact decoded duplicates retain the parsers' common last-value behavior. PowerShell
may reject additional non-ASCII case pairs; that residual is disclosed rather than called normalized.

For `.claude/settings.json`:

- root is an object with an exact lower-case `hooks` object;
- each event value is an array; each matcher group is an object with an exact `hooks` array; each
  inner handler is an object;
- an exact non-empty string `command` contributes a registration only when `type` is absent or is
  exactly `command`; schema-valid HTTP/MCP/prompt/agent handlers and unrelated properties contribute
  no file registration;
- wrong containers are valid JSON with malformed registration shape; empty `hooks` is structurally
  valid but contains zero registrations.

For `.github/hooks/hooks.json`:

- root is an object with an exact lower-case `hooks` object;
- each event value is an array and each event entry is an object;
- exact non-empty string `bash` and `powershell` fields contribute registrations only at that event
  entry; unrelated nested properties do not;
- this deliberately does not enforce `version`, both-leg portability, `command` fallback, or the full
  current vendor item schema. Those belong to authored-dist validation or future observed harm;
- empty `hooks` is structurally valid but contains zero registrations.

Every dependent doctor row consumes the same typed state. Malformed settings cannot silently fall
through as healthy Hook-files or Guard-parser evidence. Diagnostics distinguish invalid syntax,
valid JSON with malformed registration shape, read failure, and provider/query inability.

## Frozen provider protocol

The Bash `jq` capability probe requires an exact sentinel from a meaningful parse/query, not exit
zero alone. Each touched query has typed, cardinality-checked outcomes: read failure,
syntax-invalid, extraction-invalid, valid match, valid no-match, and provider/query failure.

After a successful provider probe, nonzero query status, zero/partial output, unexpected output, or
wrong cardinality is provider inability until another provider establishes content state. A working
Python fallback re-reads the original path with BOM-safe UTF-8 and returns an exact typed result.
Only narrowly caught read/JSON/collision failures become artifact outcomes; an unexpected Python
exception remains inability. If no provider can examine the artifact, the doctor says
`CANT-VERIFY`; the root installer exits 2, says it cannot determine the stamp, performs no
delegation, and changes no target bytes.

PowerShell root-stamp reads are split from parse/schema failures. Bash stamp read failure is likewise
not called invalid. Both root twins preserve explicit stack override behavior.

## Frozen implementation and test scope

Changed product functions are limited to:

- `install.ps1`: strict stamp read/parse classification;
- `install.sh`: meaningful `jq` probe, typed stamp query, and Python fallback;
- `src/core/scripts/framework-doctor.ps1`: bounded registration extraction and propagation;
- `src/core/scripts/framework-doctor.sh`: meaningful provider probe, typed stamp and registration
  extraction, Python fallback, and state propagation.

Fold evidence into the existing `FrameworkDoctor.Tests.ps1` and
`RootInstallerWarehouse.Tests.ps1` matrices. Required worlds are: valid non-empty registrations;
valid empty hooks/zero registrations; scalar/wrong containers; unrelated nested decoys; non-command
Claude handlers ignored; exact duplicate last-wins positive; ASCII collision rejection; post-probe
query exit; zero/empty or wrong-cardinality output; Python recovery; Python-proven invalid content;
no provider/inability; and installer no-delegation/no-mutation. Assertions must name expected
registrations/counts and actual states, not only exit codes.

No new suite, `It`, fixture family, parser, generic abstraction, Angular-evidence rewrite, lexical
exact-duplicate rejection, Unicode-wide normalization, or full vendor-schema validation. Angular's
current fail-closed inability path is recorded as exposed but does not enter this patch without a
direct decision-bearing red observation.

## Hostile evidence and review

The release-specific hostile mutation restores recursive registration scanning (or equivalently
accepts a wrong root) and must make the existing matrix fail for the intended assertion. Record
source hashes before mutation, restore bytes exactly, and rerun clean. The four semantic-inertness
checks are:

1. exact sentinels/cardinality prevent literal or empty success;
2. typed provider/content outcomes prevent exit-domain collisions;
3. valid-empty, absent, malformed, unreadable, and unexaminable remain distinct;
4. decoded-name collision and exact-duplicate positive controls prove normalization still compares.

B-174 receives its own immutable implementation commit/range. A reviewer who did not implement it
gets this frozen contract before the diff, performs a blind-first threat model, reviews every changed
function/artifact for necessity, then checks the immutable range and hostile/clean evidence. Windows
and Linux exact-commit CI are the supported platform evidence.

## RCA boundary

The prior matrices aligned syntax extensions but never froze registration containers or provider
outcomes. Recursive property scans made plausible text look active, and the shallow `jq` probe made
exit zero look like query capability. The exposed class is every parser-backed diagnostic where a
content verdict is inferred from unvalidated provider output or from properties outside the schema
position that gives them meaning.
