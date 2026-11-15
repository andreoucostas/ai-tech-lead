# Tech Debt Register

> Run `/bootstrap` to populate this file from your actual codebase analysis.
> Run `/debt [area]` to find and fix items. Run `/docs-sync` to check for staleness.

One `## DEBT-NNN` block per item. To add an item, copy the template below after the last block with the next unused number. To remove a resolved item, delete its whole block.

Template (an example, not an item):

```markdown
## DEBT-001: <Short title>

- **Key**: <area>::<claim-slug>
- **Category**: <one of the categories below>
- **Severity**: Critical | High | Medium | Low
- **Effort**: S (<1hr) | M (half day) | L (1-2 days) | XL (needs spike)
- **Files**: `path/to/file:42`, `path/to/other-file`

### Issue
<1-3 sentences on what's wrong and why it matters>

### Recommended fix
<1-3 sentences on the change and any risks>

---
```

## DEBT-001: Sync-over-async, per-call `new HttpClient()` in service clients

- **Key**: services::httpclient-sync-over-async
- **Category**: Async
- **Severity**: High
- **Effort**: M (half day)
- **Files**: `src/Orders.Application/Services/PricingClient.cs:7`, `src/Orders.Application/Services/ShippingClient.cs:7`, `src/Orders.Application/Services/TaxClient.cs:7`

### Issue
Each client creates a new `HttpClient` per call and blocks on `.Result`, risking socket exhaustion and thread-pool starvation, with no timeout, retry or cancellation. None is registered in `Program.cs` or called anywhere yet.

### Recommended fix
Before first use, register typed clients with `AddHttpClient`, make the methods async with `CancellationToken`, and add resilience.

---

## DEBT-002: Controllers bind domain entities directly, no validation

- **Key**: api::entity-request-binding
- **Category**: API Design
- **Severity**: High
- **Effort**: L (1-2 days)
- **Files**: `src/Orders.Api/Controllers/OrdersController.cs:26`, `src/Orders.Api/Controllers/InvoicesController.cs`, `src/Orders.Api/Controllers/CustomersController.cs`, `src/Orders.Api/Controllers/ProductsController.cs`, `src/Orders.Application/Contracts`

### Issue
`Create(Order item)` and siblings accept the EF entity as the body, so clients can set `Id`, `Status`, `Total` and `Paid`; there is no validation, and `GET` list endpoints return unpaged full tables via `ToListAsync()` (the unused `PagedResultDto` exists). `Orders.Application/Contracts` DTOs are unreferenced.

### Recommended fix
Use request/response DTOs with validation, compute totals server-side, add paging and `AsNoTracking()` on reads.

---

## DEBT-003: No authentication or authorization

- **Key**: api::no-auth
- **Category**: Security
- **Severity**: High
- **Effort**: L (1-2 days)
- **Files**: `src/Orders.Api/Program.cs:8-23`

### Issue
No auth middleware or `[Authorize]` exists in `src/`; all endpoints, including checkout and report exports, are open. Upstream gateway protection is unknown (unconfirmed).

### Recommended fix
Confirm the intended trust boundary; if none upstream, add authentication/authorization and route the finding through `/security-gate`.

---

## DEBT-004: Feature flags file not copied to the API output and read per request

- **Key**: reports::feature-flags-file-location
- **Category**: Architecture
- **Severity**: Medium
- **Effort**: S (<1hr)
- **Files**: `src/Orders.Api/Controllers/ReportsController.cs:14-19`, `src/Orders.Api/Orders.Api.csproj`, `config/feature-flags.json`

### Issue
The controller reads `ContentRootPath/config/feature-flags.json` in its constructor (each request); only the test project copies the file to output, so a published API likely throws `FileNotFoundException` on the reports endpoints (not executed here).

### Recommended fix
Add the file as a content item in `Orders.Api.csproj` or move flags to `IOptions` configuration.

---

## DEBT-005: Unreferenced job scaffolding

- **Key**: jobs::unused-scheduled-jobs
- **Category**: Architecture
- **Severity**: Low
- **Effort**: S (<1hr)
- **Files**: `src/Orders.Application/Jobs/JobSchedule.cs`, `src/Orders.Application/Jobs/NightlyReconciliationJob.cs`, `src/Orders.Application/Jobs/PurgeStaleCartsJob.cs`

### Issue
`IScheduledJob`, `JobSchedule.Cron` and both jobs (empty bodies) are not registered or referenced by any runner. Intent is unconfirmed.

### Recommended fix
Confirm intent; delete if dead, or add the runner that consumes `JobSchedule`.

---

## DEBT-006: Test suite only guards registration lists

- **Key**: tests::minimal-coverage
- **Category**: Testing
- **Severity**: High
- **Effort**: L (1-2 days)
- **Files**: `tests/Orders.Tests/EventRegistryTests.cs`, `tests/Orders.Tests/ReportCatalogTests.cs`

### Issue
Two theories check that events are registered and exports are visible; dispatch, DLQ routing, checkout transitions, and the money fields are untested, and there are no integration tests.

### Recommended fix
Add behaviour tests via the `add-tests` skill, starting with `OutboxDispatcher` and `CheckoutController`.

---

**Categories**: Architecture, Data Access, DI/Lifetime, API Design, Async, Testing, Types/Nullability, Performance, Dependencies, Security

---

## Dismissed proposals — do not re-propose without materially changed evidence

> These are reviewed claims the team determined are not debt. Keep every row for auditability.
> A later scan may reopen one only by naming the concrete evidence delta in a new active item.

| Key | Affected paths / symbols | Evidence reviewed | Dismissed | Reason |
|-----|--------------------------|-------------------|-----------|--------|
| _(none)_ | _ | _ | _ | _ |

---

## Trojan Horse Opportunities

_Group debt items by feature area so developers can bundle cleanup into feature work._

- **Checkout / API**: DEBT-002, DEBT-003, DEBT-006
- **Reports**: DEBT-004
- **Integrations**: DEBT-001
- **Jobs**: DEBT-005
