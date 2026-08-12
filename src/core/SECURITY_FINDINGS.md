# Security Findings Register

> Managed by `/security-review`. Separate from TECH_DEBT.md — these carry remediation SLAs and require evidence of resolution for internal audit.
>
> **Do not delete rows during ordinary maintenance.** Set Status to `Resolved` or `Risk Accepted`
> (with rationale) instead. A human with incident authority may redact or remove unsafe metadata as
> part of security containment.
> Run `/security-review` to add new findings. Run `/docs-sync` to check for stale entries.
>
> This Git file is a minimised coordination index for ordinary repository-safe findings. It is not
> the system of record for an active or suspected credential incident. Such incidents require
> restricted human handling and must not be recorded here automatically.

---

## SLA Reference

| Severity | Remediation deadline | Evidence required |
|----------|----------------------|-------------------|
| Critical | 7 calendar days | Fix PR + test + sign-off |
| High | 30 calendar days | Fix PR + test |
| Medium | 90 calendar days | Fix PR or accepted-risk rationale |
| Low | Next planned release | Fix PR or backlog entry |

---

## Findings

| ID | Severity | Category | Affected area (redacted when sensitive) | Repository-safe summary | Discovered | Due | Status | Owner role/team (optional) | Internal reference (optional) | Resolved |
|----|----------|----------|-----------------------------------------|-------------------------|------------|-----|--------|----------------------------|-------------------------------|----------|
| _  | _        | _        | _                                       | _Run `/security-review` to populate_ | _ | _ | _ | _ | _ | _ |

Use only an organisation-approved opaque reference. A contained credential incident may gain a
minimal historical row only when a human with incident authority explicitly authorises it. Never
invent a reference or add a placeholder row.

---

## Accepted risks

_Document only repository-safe findings the team has consciously accepted rather than fixed. Apply
the same minimisation rules as the active table. Requires sign-off from an authorised owner._

| Finding ID | Repository-safe rationale | Owner role/team (optional) | Internal reference (optional) | Review date |
|------------|---------------------------|----------------------------|-------------------------------|-------------|

---

## Resolved findings (last 12 months)

_Retain only repository-safe history. Apply the same minimisation rules when moving rows to
`docs/security-archive.md`; never ingest and restate legacy rows automatically. Older than 12 months
can be archived after human review._

| ID | Severity | Affected area (redacted when sensitive) | Repository-safe summary | Internal reference (optional) | Resolved date |
|----|----------|-----------------------------------------|-------------------------|-------------------------------|---------------|
