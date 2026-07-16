# Framework Context

> Cross-repo context that AI agents need but cannot derive from this single repo.
> Covers: shared library APIs, multi-tenancy conventions, dashboard contracts, and cross-service patterns.
>
> **Maintenance**: Every section is drafted by `/bootstrap` from this repo's code. Drafted sections open with an auto-draft comment and cover only what this repo's code shows — the cross-repo half (why a convention exists org-wide, what other services consume, a library's full surface) still needs a maintainer. Edit any section freely; `/bootstrap` never overwrites maintainer-written content. "Detected Framework Packages" and "Known Hazard Areas" are also refreshed by `/docs-sync`.
>
> **Precedence**: If `FRAMEWORK-CONTEXT.md` and `CLAUDE.md` disagree on a convention, **`CLAUDE.md` (this repo's authoritative source) wins** — but the agent must flag the contradiction. Framework-level conventions are baseline; per-repo conventions can diverge with rationale.
>
> **Versioning caveat**: Auto-drafted "Shared Libraries" entries document the **consumed** API surface at the version this repo pins; maintainer-written entries may document the **latest** surface. Either way — see "Detected Framework Packages" below — before recommending a shared-library API, verify it exists in the version this repo actually references. If unsure, say so.

---

## Production Architecture

<!-- One paragraph describing how this repo fits into the larger system:
     - Is this an application repo, a shared library repo, or the dashboard?
     - What does this repo consume? What does it expose?
     - Where do other systems integrate with this one? -->

<!-- PRODUCTION_ARCHITECTURE_PENDING: run /bootstrap to draft this from the repo's code. -->

_Not yet populated. `/bootstrap` drafts this from the repo's code; a maintainer adds the cross-repo context the code cannot show._

---

## Shared Libraries

<!-- List the shared NuGet packages the team maintains.
     For each: name, purpose, source repo, where to look for usage docs.
     Document the latest version's public API surface, with a disclaimer that
     older consumer repos may pin to earlier versions. -->

<!-- SHARED_LIBRARIES_PENDING: run /bootstrap to draft entries from this repo's detected framework packages and their observed usage. -->

_Not yet populated. `/bootstrap` drafts an entry per detected framework package (consumed surface, observed in this repo); a maintainer adds purpose, pitfalls, and the full API surface. Entries exist so AI agents do not reimplement helpers that already exist._

Template entry:

```markdown
### Acme.Framework.Auth

- **Source**: https://github.com/<org>/Acme.Framework.Auth
- **Purpose**: Tenant-aware authentication primitives, JWT bearer middleware, OIDC handlers.
- **Latest version**: 4.2.0
- **Public API surface (latest)**:
  - `services.AddAcmeAuthentication(options => ...)` — registers JWT bearer + OIDC + tenant resolver
  - `services.AddAcmeAuthorization()` — registers default policy + role handlers
  - `[RequireTenant]` attribute — enforces tenant claim on the action
- **Common pitfalls**: Do not call `AddAuthentication()` directly after `AddAcmeAuthentication()` — it overwrites the scheme registration.
```

---

## Multi-Tenancy Conventions

<!-- If applicable: how is tenancy modeled? Where are tenant boundaries enforced?
     How is tenant data isolation handled? What are the conventions for adding
     new tenant-aware features? -->

<!-- MULTI_TENANCY_PENDING: run /bootstrap to draft this from the repo's code (or record a verified negative). -->

_Not yet populated. `/bootstrap` drafts this from observed tenant signals — or records that none were found._

---

## Dashboard Integration Contracts

<!-- If this repo registers with a multi-tenant dashboard or similar control plane:
     - Registration protocol
     - Required metadata (app name, owner, callbacks, etc.)
     - Health-check / heartbeat contracts
     - How configuration flows from dashboard to app -->

<!-- DASHBOARD_INTEGRATION_PENDING: run /bootstrap to draft this from the repo's code (or record a verified negative). -->

_Not yet populated. `/bootstrap` drafts this from observed registration/health-check wiring — or records that none was found._

---

## Cross-Service Communication

<!-- Patterns for service-to-service calls within the org:
     - HTTP conventions (versioning, auth, retry, idempotency)
     - Message bus / event patterns (if any)
     - Shared error/response envelopes
     - Distributed tracing / correlation ID propagation -->

<!-- CROSS_SERVICE_COMMUNICATION_PENDING: run /bootstrap to draft this from the repo's code (or record a verified negative). -->

_Not yet populated. `/bootstrap` drafts this from observed HttpClient/message-bus/correlation wiring; a maintainer adds the org-wide conventions._

---

## Known Hazard Areas

<!-- Auto-drafted by /bootstrap (and /adopt) from the Phase-2 Tier-1 architectural-risk
     synthesis (plus any domain-invariant / security findings); refined by maintainers. These
     are the "here be dragons" of this repo: load-bearing workarounds, undocumented invariants,
     high-blast-radius modules, and places where the tests do not actually pin the behaviour.
     The agent reads this before planning any change in a listed area.

     Epistemic status is REQUIRED on every row and the agent must honour it:
       [VERIFIED]   a human confirmed the cause / why it must stay this way.
       [SUSPECTED]  a human believes so but is unsure.
       [UNVERIFIED] inferred by tooling only, no human confirmation — treat as a hypothesis, not
                    a finding; it must NOT raise your confidence.
     Re-confirm any row older than ~90 days — a stale hazard map causes false confidence. -->

**Legend:** `[VERIFIED]` = a person confirmed it. `[SUSPECTED]` = a person thinks so. `[UNVERIFIED]` = only the tooling flagged it — treat it as an open question, not a finding.

Merging the PR does not confirm these — an item is confirmed only when a person answers its question and updates its status.

<!-- KNOWN_HAZARD_AREAS_PENDING: run /bootstrap to draft this from the codebase. -->

| Area / file(s) | Hazard | Status | Reviewed |
|----------------|--------|--------|----------|
| _(drafted by /bootstrap)_ | _ | _ | _ |

---

## Detected Framework Packages

<!-- Auto-populated by /bootstrap and /docs-sync.
     Lists the framework packages this repo references, with version.
     Helps the AI give version-aware advice and flag drift. -->

<!-- DETECTED_FRAMEWORK_PACKAGES_PENDING: run /bootstrap to populate. -->

| Package | Version | Source (csproj / Directory.Packages.props) |
|---------|---------|--------------------------------------------|
| _(populated by /bootstrap)_ | _ | _ |
