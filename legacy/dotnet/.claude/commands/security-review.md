Run a security review of changed code as a senior tech lead. This is a quality gate, not a rubber stamp — every finding must be acted on, deferred with rationale, or rejected with rationale.

## Input
$ARGUMENTS

If no specific files or PR given, review the most recent uncommitted changes (both staged and unstaged).

## Execution

### Step 1 — Dispatch the security auditor
In a single message, spawn the `security-auditor` subagent via the `Task` tool against the in-scope files. Wait for the structured findings table to return — do not redo the OWASP-style scan yourself.

### Step 2 — Cross-check against FRAMEWORK-CONTEXT.md
Read `FRAMEWORK-CONTEXT.md`. If it documents tenancy boundaries, dashboard contracts, or shared-library auth patterns:
- Verify the changes do not bypass tenant isolation.
- Verify auth/authz patterns from `Shared Libraries` are used correctly (not reimplemented).
- Flag any direct use of low-level auth APIs when a shared-library wrapper exists.

### Step 3 — Apply senior judgement
The auditor handles pattern-level checks. You handle what static patterns cannot:

- **Authorisation logic**: does each endpoint enforce the right permission for the resource it touches? Object-level auth (a user can only mutate their own records) is invisible to a pattern scan.
- **Data flow**: does sensitive data leave the trust boundary it should stay within? (DB → API DTO → log — does anything sensitive reach a place it shouldn't?)
- **Concurrency / race conditions**: are check-then-act sequences correct? (e.g., balance check then debit)
- **Error envelopes**: do error responses leak schema (SQL state, full type names, stack traces) outside Development?

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

### Auth/authz analysis
- Object-level checks present: yes / no / partial
- Tenant isolation verified: yes / no / n/a
- Bypass paths considered: ...

### Data exposure analysis
- Sensitive fields in DTOs / logs / errors: list any
- New surface introduced: yes / no, describe

### Dependencies flagged
- (Auditor output, summarised; recommend `dotnet list package --vulnerable --include-transitive` if this is a release-bound branch)

### Recommended next actions
1. ...
2. ...
```

**Verdict thresholds**:
- `BLOCK`: any `critical` finding (auth bypass, RCE, data loss, secret committed)
- `REQUEST CHANGES`: any `high` finding, or `medium` findings that bundle into the same blast radius as the change
- `APPROVE`: only when all findings are `low` or have explicit accepted-risk rationale

Be direct. Do not praise code for not being insecure — that is the baseline.
