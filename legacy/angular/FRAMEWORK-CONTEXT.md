# Framework Context

> Cross-repo context that AI agents need but cannot derive from this single repo.
> Covers: shared library APIs, multi-tenancy conventions, dashboard contracts, and cross-service patterns.
>
> **Maintenance**: Edit the static sections (Production Architecture, Shared Libraries, etc.) when framework-level conventions change. The "Detected Framework Packages" section is auto-populated by `/bootstrap` and refreshed by `/docs-sync`.
>
> **Precedence**: If `FRAMEWORK-CONTEXT.md` and `CLAUDE.md` disagree on a convention, **`CLAUDE.md` (this repo's authoritative source) wins** — but the agent must flag the contradiction. Framework-level conventions are baseline; per-repo conventions can diverge with rationale.
>
> **Versioning caveat**: The "Shared Libraries" section documents the **latest** API surface. This consumer repo may pin to older versions — see "Detected Framework Packages" below. Before recommending a shared-library API, verify it exists in the version this repo actually references. If unsure, say so.

---

## Production Architecture

<!-- One paragraph describing how this repo fits into the larger system:
     - Is this an application repo, a shared library repo, or the dashboard?
     - What does this repo consume? What does it expose?
     - Where do other systems integrate with this one? -->

_Not yet populated. A maintainer should describe the production architecture here once._

---

## Shared Libraries

<!-- List the shared npm packages the team maintains.
     For each: name, purpose, source repo, where to look for usage docs.
     Document the latest version's public API surface, with a disclaimer that
     older consumer repos may pin to earlier versions. -->

_Not yet populated. Add an entry per shared library so AI agents do not reimplement helpers that already exist._

Template entry:

```markdown
### @acme/ui-kit

- **Source**: https://github.com/<org>/acme-ui-kit
- **Purpose**: Shared design-system components (buttons, modals, forms) with theming.
- **Latest version**: 3.1.0
- **Public API surface (latest)**:
  - `<acme-button>` — primary/secondary/ghost variants; emits `(click)`
  - `<acme-modal>` — content-projected modal with `[open]` input
  - `provideAcmeTheme({ ... })` — global theme provider, call in `bootstrapApplication`
- **Common pitfalls**: Do not import `acme-ui-kit/legacy` — it is for repos still on Angular 14 or below.
```

---

## Multi-Tenancy Conventions

<!-- If applicable: how is tenancy modeled in the frontend?
     - Tenant resolution (subdomain / path / header)
     - Tenant-scoped routing, theming, feature flags
     - How tenant context is provided to components / services -->

_Not applicable / not yet populated._

---

## Dashboard Integration Contracts

<!-- If this app registers with a multi-tenant dashboard or similar control plane:
     - Registration protocol
     - Required metadata (app name, owner, callbacks, etc.)
     - Health-check / heartbeat contracts
     - How configuration flows from dashboard to app -->

_Not applicable / not yet populated._

---

## Cross-Service Communication

<!-- Patterns for backend calls / cross-app communication:
     - API base URL conventions, versioning, auth headers
     - Shared error/response envelopes
     - Correlation ID propagation, logging conventions
     - WebSocket / SSE patterns (if any) -->

_Not yet populated._

---

## Detected Framework Packages

<!-- Auto-populated by /bootstrap and /docs-sync.
     Lists the framework packages this repo references, with version.
     Helps the AI give version-aware advice and flag drift. -->

<!-- DETECTED_FRAMEWORK_PACKAGES_PENDING: run /bootstrap to populate. -->

| Package | Version | Source (package.json) |
|---------|---------|-----------------------|
| _(populated by /bootstrap)_ | _ | _ |
