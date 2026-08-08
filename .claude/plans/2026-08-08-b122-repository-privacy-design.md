# B-122 — repository privacy cleanup and prevention

**Status:** LOCKED after adversarial critique and proportionality correction

**Scope:** public authoring repository; B-109 already protects consumer distributions

**Effort:** M under Maintenance model #1

## Evidence and classification

On `origin/master` at `55370e4`, a case-insensitive tracked-tree search for the maintainer name or
GitHub handle returns 30 matching lines across 13 files; `dist/` returns zero.

- Fourteen lines are intentional public identity: MIT attribution, root README attribution/clone
  URL, and historical repository URLs. Preserve them.
- Sixteen lines are incidental machine provenance: three canary executable defaults, three
  `DEVELOPING.md` examples, eight backlog paths, one eval path, and one workspace-decision path.
  Sanitize them without changing the recorded technical fact.

The privacy invariant is concrete account-qualified home paths, not names. Names and handles remain
legal because licence attribution and real repository URLs require them.

## Proportionality case (Maintenance model #6)

The observed harm is bounded: 16 ordinary text lines in the public authoring tree reveal a local
account/home layout, and three of them make canaries machine-specific. There is no credential and no
consumer-dist leak. The first reviewed design grew into a generic host resolver plus a standalone
encoding/gitlink/reparse-point scanner framework. That is disproportionate to the evidence, repeats
B-108's mistake, and is rejected.

The smaller fix removes every observed path, makes the three defaults environment-relative, and
adds one compact meta test over non-ignored working-tree files. It removes the current harm and the
ordinary recurrence path without building infrastructure for hypothetical UTF-32 files, submodules,
or adversarial filenames. Existing repository UTF-8/BOM and staged-set gates retain their own jobs.

## Locked implementation

### 1. Sanitize the 16 incidental lines

Use `<home>`, `<username>`, `<temp>`, or environment-variable notation. Preserve the actual error,
tool, and host conclusion. Do not touch the fourteen intentional identity lines.

### 2. Make canary defaults environment-relative

- In `canary-applyto-scope.ps1` and `canary-copilot-instructions.ps1`, default `CopilotCmd` to an
  empty string. After parameter binding, when empty, construct
  `$env:APPDATA\npm\copilot.cmd`; if `APPDATA` is absent or the leaf is missing, throw a generic
  message instructing the caller to pass `-CopilotCmd`. Retain explicit override and current
  `NodeDir` behavior.
- In `canary-single-carrier.ps1`, add `-ClaudeCmd`. When empty, construct
  `$env:USERPROFILE\.local\bin\claude.exe`; if unavailable, throw a generic message instructing
  the caller to pass `-ClaudeCmd`. Invoke the resolved variable instead of a literal path.

This is intentionally not a generalized resolver library. These are maintainer-only historical
canaries, the environment-derived paths reproduce their current host contract, and explicit
parameters cover other installations.

### 3. Add a compact repository privacy test

Add auto-discovered `.claude/hooks/tests/RepositoryPrivacy.Tests.ps1`:

1. Enumerate `git -C $repoRoot ls-files --cached --others --exclude-standard`; check the exit code
   and require a non-zero file population. New, non-ignored files are included before staging.
2. For each existing regular file outside `.git`, use `.NET ReadAllText` (BOM-aware), catch read
   errors as failures, and skip content containing NUL as binary. Do not add directory/file
   allowlists.
3. Detect case-insensitive Windows drive/MSYS/Linux/macOS concrete homes:
   `X:\Users\account`, `X:/Users/account`, `/x/Users/account`, `/home/account`, `/Users/account`.
   The account must start with `[A-Za-z0-9._-]` and end at slash, whitespace, quote, punctuation,
   or end-of-string, so `<account>` and regex documentation do not self-trigger. Extended Windows
   paths contain the normal drive-path substring and are covered incidentally.
4. Define the scanner as a small function. Self-tests dynamically assemble all four concrete forms,
   prove slash/case/home-root boundaries and filename/line diagnostics, and prove placeholders and
   the regex source stay clean. A positive control must find at least one synthetic leak.
5. Refactor B-109's literal `C:\Users\ExamplePerson\...` fixture to assemble its segments at runtime;
   no fixture-file exemption is allowed.

This gate targets the actual UTF-8/BOM-marked repository contract. `WorkspaceBom.Tests.ps1` remains
the encoding gate; B-122 does not duplicate it. If a future binary/submodule encoding leak is
observed, extend the responsible population gate then rather than pre-building that machinery now.

### 4. Retain published history explicitly

Append a lightweight ADR to `meta/workspace-decisions.md`: sanitize HEAD and retain history. State
plainly that old published commits still contain the paths. They are privacy-sensitive metadata,
not credentials; rewriting commits/tags/forks is a separate maintainer-approved migration if
historical erasure is desired. Do not rewrite shared history in B-122.

## Verification

1. Add the privacy test before sanitization and observe it fail on the real current files, naming
   offenders. This is the required red observation.
2. Run its synthetic boundary tests, then sanitize/refactor and observe the real-tree scan green.
3. Add focused static/behavioral assertions that both Copilot canaries use APPDATA when no explicit
   value is supplied, the Claude canary uses USERPROFILE, explicit overrides win, and missing env or
   leaf produces the generic `pass -...Cmd` diagnostic. Tests use temp fake leaves and do not launch
   an agent host.
4. Parse changed PowerShell files, preserve BOM, run the focused privacy test and full meta suite.
5. Run a final inventory: zero concrete personal home paths; exactly the enumerated intentional
   name/handle lines remain and are justified; `no-meta-leak` remains green for all three dists.

## Delivery and RCA

This is meta-only: no version or shipped changelog. Move B-122 to Done and record the RCA: the
existing privacy boundary inspected only composed distributions, leaving maintainer scripts,
transcripts, plans, and records exposed; the new meta test derives its population from the whole
non-ignored working tree.

## Rejected alternatives

- Ban the maintainer name: breaks licence attribution and real URLs.
- Exclude `meta/`, plans, or fixtures: those contain most observed leaks.
- Build a general host-resolution library or encoding/submodule scanner: disproportionate to the
  observed ordinary-text/default-path harm.
- Rewrite history: disruptive and outside the approved HEAD-cleanup scope.
