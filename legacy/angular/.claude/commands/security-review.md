---
description: "Security gate on changed code: spawns the security-auditor subagent, cross-checks tenant isolation and shared-library auth patterns, appends critical/high findings to SECURITY_FINDINGS.md with SLA due dates. Invoke before presenting any change that touches auth, payments, balances, ledgers, transactions, idempotency, or secrets."
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
Read `FRAMEWORK-CONTEXT.md`. If it documents tenancy resolution, dashboard auth contracts, or shared-library token handling:
- Verify the changes do not bypass tenant context (subdomain / header / claim).
- Verify auth/token patterns from `Shared Libraries` are used correctly (not reimplemented).
- Flag any direct `localStorage.setItem('token', ...)` when a shared interceptor or auth client exists.

### Step 3 — Apply senior judgement
The auditor handles pattern-level checks. You handle what static patterns cannot:

- **Authorisation logic**: client-side hide-if-not-admin is UX, not security. Verify the backend re-checks on every state-changing request.
- **Trust boundaries**: anything coming from the user, the URL, the DOM, or `postMessage` is untrusted. Trace it through the flow.
- **Token lifecycle**: how is the token acquired, stored, refreshed, revoked? Is there a logout that actually invalidates server-side?
- **Error envelopes**: do error responses leak schema (full backend stack, internal hostnames)?

### Step 4 — Verify the auditor's findings
Spot-check 2–3 findings by opening the cited files and confirming the pattern is real. The auditor uses heuristics; false positives happen. Confirm or downgrade them.

### Step 5 — Synthesise

## Output Format

```
## Security review: [scope]

### Verdict: APPROVE | REQUEST CHANGES | BLOCK

### Findings (<count>)
| # | Severity | File:line | Risk | Action |
|---|----------|-----------|------|--------|

### Auth/token analysis
- Token storage location: localStorage / sessionStorage / httpOnly cookie / memory
- Tenant context propagation verified: yes / no / n/a
- Bypass paths considered: ...

### Data exposure analysis
- Sensitive fields in templates / logs / errors: list any
- New surface introduced: yes / no, describe

### Dependencies flagged
- (Auditor output, summarised; recommend `npm audit --omit=dev` if this is a release-bound branch)

### Recommended next actions
1. ...
2. ...
```

**Verdict thresholds**:
- `BLOCK`: any `critical` finding (auth bypass, token leak, secret committed)
- `REQUEST CHANGES`: any `high` finding (XSS, sensitive data exposure), or `medium` findings that bundle into the same blast radius as the change
- `APPROVE`: only when all findings are `low` or have explicit accepted-risk rationale

Be direct. Do not praise code for not being insecure — that is the baseline.

---

## Standing scanners (set up once, not per-review)

`/security-review` is the per-change gate. Back it with automated scanning so regressions are caught between reviews:

- **Dependencies**: run the `dependency-audit` skill — `npm audit` plus Dependabot (GitHub) or Renovate (Bitbucket / host-agnostic).
- **SAST**: on GitHub, enable **CodeQL** code scanning (JavaScript/TypeScript). On **Bitbucket Data Center**, CodeQL is unavailable — run a SAST tool (Semgrep, SonarQube) in Bitbucket Pipelines / Bamboo / Jenkins and publish results via the **Code Insights API** so findings appear inline on the PR. See the README "Running on Bitbucket Data Center" section.

These are infrastructure, not review steps — recommend them once, then let CI carry them.
