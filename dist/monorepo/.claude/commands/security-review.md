---
description: "Security gate on changed code: spawns the security-auditor subagent, cross-checks tenant isolation and shared-library auth patterns, and records only repository-safe critical/high findings in SECURITY_FINDINGS.md. Credential incidents require restricted human handling and never mutate Git automatically."
argument-hint: "[files or PR; empty = uncommitted changes]"
---

Run a security review of changed code as a senior tech lead. This is a quality gate, not a rubber stamp — every finding must be acted on, deferred with rationale, or rejected with rationale.

## Input
$ARGUMENTS

If no specific files or PR given, review the most recent uncommitted changes (both staged and unstaged).

## Execution

### Step 1 — Dispatch the security auditor
In a single message, spawn the `security-auditor` subagent via the `Task` tool against the in-scope files. Wait for the structured findings table to return — do not redo the OWASP-style scan yourself.

### Step 2 — Cross-check against FRAMEWORK-CONTEXT.md
Read `FRAMEWORK-CONTEXT.md`. If it documents tenancy boundaries/resolution, dashboard auth contracts, or shared-library auth/token patterns:
- Verify the changes do not bypass tenant isolation / tenant context (subdomain / header / claim).
- Verify auth/token patterns from `Shared Libraries` are used correctly (not reimplemented).
- **.NET:** Flag any direct use of low-level auth APIs when a shared-library wrapper exists.
- **Angular:** Flag any direct `localStorage.setItem('token', ...)` when a shared interceptor or auth client exists.

### Step 3 — Apply senior judgement
The auditor handles pattern-level checks. You handle what static patterns cannot:

- **Authorisation logic** — **.NET:** does each endpoint enforce the right permission for the resource it touches? Object-level auth (a user can only mutate their own records) is invisible to a pattern scan. **Angular:** client-side hide-if-not-admin is UX, not security — verify the backend re-checks on every state-changing request.
- **Data flow / trust boundaries** — **.NET:** does sensitive data leave the trust boundary it should stay within? (DB → API DTO → log — does anything sensitive reach a place it shouldn't?) **Angular:** anything coming from the user, the URL, the DOM, or `postMessage` is untrusted. Trace it through the flow.
- **Concurrency / race conditions** (.NET): are check-then-act sequences correct? (e.g., balance check then debit)
- **Token lifecycle** (Angular): how is the token acquired, stored, refreshed, revoked? Is there a logout that actually invalidates server-side?
- **Error envelopes**: do error responses leak schema (SQL state, full type names, stack traces; full backend stack, internal hostnames) outside Development?

### Step 4 — Verify the auditor's findings
Spot-check 2–3 findings by opening the cited files and confirming the pattern is real. The auditor uses heuristics; false positives happen. Confirm or downgrade them.

### Step 5 — Synthesise

Classify each finding before writing the response. For an ordinary code finding, include a
repository-relative `file:line` only when both the locator and target are safe for every repository
reader. For an active or suspected credential finding, do not echo protected incident detail. State
only that restricted human handling is required and the minimum immediate action class (for example,
revoke/rotate the credential and stop further disclosure). Do not name identities, infrastructure,
tenants, environments, customers, hosts/IPs, users/home paths, vaults/keys, concrete secret paths or
lines, transcript/session/log/CI artifacts, disclosure channels, secret material, partial or masked
fragments, secret-derived fingerprints, or unapproved references/URLs.

## Output Format

```
## Security review: [scope]

### Verdict: APPROVE | REQUEST CHANGES | BLOCK

### Findings (<count>)
| # | Severity | File:line | Risk | Action |
|---|----------|-----------|------|--------|

### Auth / authz / token analysis
- Object-level checks present (.NET): yes / no / partial
- Token storage location (Angular): localStorage / sessionStorage / httpOnly cookie / memory
- Tenant isolation / context propagation verified: yes / no / n/a
- Bypass paths considered: ...

### Data exposure analysis
- Sensitive fields in DTOs / templates / logs / errors: list any
- New surface introduced: yes / no, describe

### Dependencies flagged
- (Auditor output, summarised; recommend the touched stack's scan if this is a release-bound branch — .NET: `dotnet list package --vulnerable --include-transitive`; Angular: `npm audit --omit=dev`)

### Recommended next actions
1. ...
2. ...
```

**Verdict thresholds**:
- `BLOCK`: any `critical` finding (auth bypass, RCE, data loss, token leak, secret committed)
- `REQUEST CHANGES`: any `high` finding (XSS, sensitive data exposure), or `medium` findings that bundle into the same blast radius as the change
- `APPROVE`: only when all findings are `low` or have explicit accepted-risk rationale

Be direct. Do not praise code for not being insecure — that is the baseline.

---

## Step 6 — Update SECURITY_FINDINGS.md

For every ordinary repository-safe finding rated `critical` or `high`, synthesise and append a
minimised row to `SECURITY_FINDINGS.md`. Never paste auditor/chat/tool output into the register.

For an active or suspected credential finding, make no automatic Git mutation and create no
placeholder row or invented reference. Ask a human to establish restricted incident handling. Only
after containment may a human with incident authority explicitly authorise a minimal historical row
using an organisation-approved opaque reference; never infer containment yourself.

Before appending, require the current header containing `Affected area (redacted when sensitive)` and
`Repository-safe summary`. If either heading is absent, do not modify the register. Give only this
non-sensitive instruction: `SECURITY_FINDINGS.md uses a legacy schema; a human with incident
authority must review/redact or remove unsafe legacy metadata, then adopt the current header.`
Never ingest or restate legacy active, accepted-risk, resolved, or `docs/security-archive.md` rows.

Calculate the due date from today:
- `critical` → today + 7 calendar days
- `high` → today + 30 calendar days

Only append during ordinary maintenance — never modify or delete existing rows. A human with
incident authority may redact or remove unsafe metadata during containment. If a finding duplicates
an open row (same safe affected area, same category), update neither row and note the duplicate only
in a repository-safe response.

If the verdict is `APPROVE` (no critical or high findings), note this in the output but do not modify `SECURITY_FINDINGS.md`.

---

## Standing scanners (set up once, not per-review)

`/security-review` is the per-change gate. Back it with automated scanning so regressions are caught between reviews:

- **Dependencies**: run the `dependency-audit` skill — vulnerable/deprecated NuGet **and** npm packages plus Dependabot (GitHub) or Renovate (Bitbucket / host-agnostic).
- **SAST**: on GitHub, enable **CodeQL** code scanning (C# **and** JavaScript/TypeScript). On **Bitbucket Data Center**, CodeQL is unavailable — run a SAST tool (Semgrep, SonarQube) in Bitbucket Pipelines / Bamboo / Jenkins and publish results via the **Code Insights API** so findings appear inline on the PR. See the README "Running on Bitbucket Data Center" section.

These are infrastructure, not review steps — recommend them once, then let CI carry them.
