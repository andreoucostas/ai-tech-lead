# Tech Debt Register

> One block per item. Sorted by severity then effort. Reference items by ID in commit messages and PRs.
> Run `/debt [area]` to find and fix items. Run `/docs-sync` to check for staleness.

---

## DEBT-001: Reports controller reads a flags file the API does not ship

- **Key**: reports::feature-flags-file-not-copied
- **Category**: API Design
- **Severity**: High
- **Effort**: S (<1hr)
- **Files**: `src/Orders.Api/Controllers/ReportsController.cs:17`, `src/Orders.Api/Orders.Api.csproj`, `config/feature-flags.json`

### Issue
The constructor reads `<ContentRoot>/config/feature-flags.json` on every request, but `Orders.Api.csproj` never copies that repo-root file into the API project or output (only the test project links it), so `/api/reports` likely throws `FileNotFoundException`. Not run-verified.

### Recommended fix
Bind flags once through the options pattern from configuration, or copy the file as content; read it once, not per request.

---

## DEBT-002: Checkout actions have no state guard or idempotency

- **Key**: checkout::no-state-guard
- **Category**: Architecture
- **Severity**: High
- **Effort**: M (half day)
- **Files**: `src/Orders.Api/Controllers/CheckoutController.cs:20-48`, `src/Orders.Application/Orders/OrderLifecycle.cs`

### Issue
`place`, `ship` and `issue` set `Status` strings (or enqueue) without checking the current state, so repeated calls emit duplicate events with fresh `EventId`s. Status is a free string; no concurrency token on the entities. Applicable invariants are unconfirmed.

### Recommended fix
Define allowed transitions with the owners, enforce them in the domain, and add a concurrency token plus an idempotency key.

---

## DEBT-003: Outbox dispatch loses events and can stop the host

- **Key**: messaging::dispatch-failure-loses-event
- **Category**: Architecture
- **Severity**: High
- **Effort**: M (half day)
- **Files**: `src/Orders.Infrastructure/Messaging/OutboxProcessor.cs:22-26`, `src/Orders.Infrastructure/Messaging/OutboxDispatcher.cs:37-40`

### Issue
The event is dequeued before dispatch; a handler or publish exception escapes `ExecuteAsync` (default .NET 8 behaviour stops the host) and the event is gone.

### Recommended fix
Catch and log per event, retry or dead-letter, and only remove the event after success.

---

## DEBT-004: In-memory outbox is not atomic with the database save

- **Key**: messaging::in-memory-outbox
- **Category**: Architecture
- **Severity**: High
- **Effort**: L (1-2 days)
- **Files**: `src/Orders.Api/Program.cs:13`, `src/Orders.Infrastructure/Messaging/InMemoryOutbox.cs`, `src/Orders.Api/Controllers/CheckoutController.cs:25-27`

### Issue
`SaveChangesAsync` and the enqueue are separate steps and the queue lives in process memory, so a crash or restart loses events that the database already reflects.

### Recommended fix
Persist outbox rows in the same transaction (table-backed outbox) and have the processor drain them. Record an ADR.

---

## DEBT-005: CRUD controllers bind entities and use the DbContext directly

- **Key**: api::entity-binding-dbcontext-in-controller
- **Category**: API Design
- **Severity**: High
- **Effort**: L (1-2 days)
- **Files**: `src/Orders.Api/Controllers/OrdersController.cs`, `CustomersController.cs`, `InvoicesController.cs`, `ProductsController.cs`

### Issue
`Create(Order item)` etc. accept domain entities, so clients can set `Total`, `Status`, `Paid`, `Id`. List endpoints return whole tables with tracking and no paging.

### Recommended fix
Introduce request/response DTOs and a service layer; use `AsNoTracking()` and paging on reads.

---

## DEBT-006: No authentication or authorization

- **Key**: security::no-authn-authz
- **Category**: Security
- **Severity**: High
- **Effort**: L (1-2 days)
- **Files**: `src/Orders.Api/Program.cs`, `src/Orders.Api/Controllers/`

### Issue
No `UseAuthentication`/`UseAuthorization` or `[Authorize]` anywhere in `src/`; every endpoint, including report export and checkout, is anonymous. Run `/security-gate` to triage; this register is not the security findings register.

### Recommended fix
Add authentication and authorization policies once the identity provider is decided.

---

## DEBT-007: Dispatcher fails silently when an event is half-wired

- **Key**: messaging::silent-registry-drop
- **Category**: Architecture
- **Severity**: Medium
- **Effort**: S (<1hr)
- **Files**: `src/Orders.Infrastructure/Messaging/OutboxDispatcher.cs:24-35`, `src/Orders.Infrastructure/Messaging/EventRegistry.cs`, `tests/Orders.Tests/EventRegistryTests.cs`

### Issue
An event missing from `EventRegistry` is dropped without a log; a version/schema mismatch goes to a `.dlq` topic; a handler missing from `Program.cs` throws at dispatch. The existing test hard-codes three event types, so a new event is not checked.

### Recommended fix
Log the drop, and add a test that enumerates every `IIntegrationEvent` type and checks registry, schema version and handler registration.

---

## DEBT-008: Decimal money columns have no configured precision

- **Key**: data::decimal-precision-unconfigured
- **Category**: Data Access
- **Severity**: Medium
- **Effort**: S (<1hr)
- **Files**: `src/Orders.Infrastructure/Persistence/Configurations/OrderConfiguration.cs`, `InvoiceConfiguration.cs`, `ProductConfiguration.cs`

### Issue
`Total`, `Amount` and `Price` use EF's default decimal mapping; scale and rounding policy are not stated anywhere (unconfirmed with the team).

### Recommended fix
Confirm the monetary scale, then `HasPrecision` in each configuration.

---

## DEBT-009: Report CSV has no escaping and uses SELECT *

- **Key**: reports::csv-no-escaping
- **Category**: API Design
- **Severity**: Medium
- **Effort**: S (<1hr)
- **Files**: `src/Orders.Reporting/IReportReader.cs:21,28`

### Issue
Values are joined with commas without quoting, so text containing commas or quotes corrupts the CSV; `viewName` is interpolated into SQL (currently only from code constants).

### Recommended fix
Quote/escape fields and select named columns; keep `viewName` restricted to catalog values.

---

## DEBT-010: No schema deployment path for `db/` or the `dbo` tables

- **Key**: data::no-migrations
- **Category**: Data Access
- **Severity**: Medium
- **Effort**: XL (needs spike)
- **Files**: `db/views/`, `db/security/reporting-grants.sql`, `src/Orders.Infrastructure/Persistence/OrdersDbContext.cs`

### Issue
No EF migrations and no script or pipeline applying the views and grants were found; how `dbo.*` tables and `rpt.*` views reach a database is unrecorded.

### Recommended fix
Decide the vehicle (EF migrations plus an ordered script step, or an SQL project) and record the command in Verification Commands.

---

## DEBT-011: Unused HTTP clients create `HttpClient` per call with `.Result`

- **Key**: services::unused-sync-over-async-clients
- **Category**: Async
- **Severity**: Low
- **Effort**: S (<1hr)
- **Files**: `src/Orders.Application/Services/PricingClient.cs`, `ShippingClient.cs`, `TaxClient.cs`

### Issue
Three identical classes, referenced nowhere, each blocking on `GetStringAsync(...).Result` with a new `HttpClient`.

### Recommended fix
Delete if dead; otherwise use `IHttpClientFactory` typed clients with async calls and a resilience policy.

---

## DEBT-012: Scheduled jobs are not wired to a scheduler

- **Key**: jobs::unwired-scheduled-jobs
- **Category**: Architecture
- **Severity**: Low
- **Effort**: S (<1hr)
- **Files**: `src/Orders.Application/Jobs/JobSchedule.cs`, `NightlyReconciliationJob.cs`, `PurgeStaleCartsJob.cs`

### Issue
Both jobs have empty bodies and nothing registers or runs them; `JobSchedule.Cron` is unused.

### Recommended fix
Delete or implement and register with a scheduler.

---

## Dismissed proposals — do not re-propose without materially changed evidence

| Key | Affected paths / symbols | Evidence reviewed | Dismissed | Reason |
|-----|--------------------------|-------------------|-----------|--------|
| _(none)_ | _ | _ | _ | _ |

---

## Trojan Horse Opportunities

- **Checkout / events**: DEBT-002, DEBT-003, DEBT-004, DEBT-007
- **Reports**: DEBT-001, DEBT-009
- **API surface**: DEBT-005, DEBT-006
- **Data**: DEBT-008, DEBT-010
- **Dead code**: DEBT-011, DEBT-012
