# Tech Debt Register

> One block per item. Sort by severity then effort. Reference items by ID in commit messages and PRs.
> Run `/debt [area]` to find and fix items. Run `/docs-sync` to check for staleness.

---

## DEBT-001: Order/invoice state changes are unguarded and emit duplicate events

- **Key**: checkout::unguarded-transitions
- **Category**: API Design
- **Severity**: High
- **Effort**: M (half day)
- **Files**: `src/Orders.Api/Controllers/CheckoutController.cs:20-48`, `src/Orders.Application/Orders/OrderLifecycle.cs:9-16`

### Issue
`Place`, `Ship` and `Issue` never check the current status (`Status` is a free string) and each call emits a new event with a fresh `Guid.NewGuid()` EventId. A retry or repeated call duplicates `OrderPlaced` / `InvoiceIssued`, and consumers cannot deduplicate. `Issue` does not change any invoice state.

### Recommended fix
Decide the allowed transitions and idempotency rule with the owner (open question), enforce them in an Application service, and derive a stable EventId. Add behaviour tests first.

---

## DEBT-002: Outbox dispatch drops or loses events silently

- **Key**: messaging::dispatcher-failure-modes
- **Category**: Architecture
- **Severity**: High
- **Effort**: M (half day)
- **Files**: `src/Orders.Infrastructure/Messaging/OutboxDispatcher.cs:24-40`, `src/Orders.Infrastructure/Messaging/OutboxProcessor.cs:20-28`

### Issue
An unregistered event type is dropped with no log; a schema-version mismatch goes to `<topic>.dlq` and skips the handler; an exception from dispatch propagates out of `ExecuteAsync` after the event was already dequeued, losing it and stopping the background service.

### Recommended fix
Log and surface the drop and DLQ cases, catch and handle per-event failures in the processor, and consider validating registry/schema/`[EventVersion]` agreement in a test over the repo's own events.

---

## DEBT-003: CRUD controllers bind domain entities and bypass the Application layer

- **Key**: api::crud-controllers-bind-entities
- **Category**: API Design
- **Severity**: High
- **Effort**: L (1-2 days)
- **Files**: `src/Orders.Api/Controllers/OrdersController.cs:26`, `src/Orders.Api/Controllers/InvoicesController.cs:26`, `src/Orders.Api/Controllers/CustomersController.cs:26`, `src/Orders.Api/Controllers/ProductsController.cs:26`

### Issue
Create actions accept `Order`, `Invoice`, `Customer`, `Product` as request bodies, so callers set `Id`, `Status`, `Total`, `Paid` directly (mass assignment). Reads return entities, are unpaged, and use tracking queries (`ToListAsync` without `AsNoTracking`). Controllers hold data access, so they are not thin.

### Recommended fix
Introduce request/response DTOs and an Application-layer service per the target convention (pending developer confirmation), add paging and `AsNoTracking()` on reads.

---

## DEBT-004: No authentication or authorization

- **Key**: api::no-authn-authz
- **Category**: Security
- **Severity**: High
- **Effort**: L (1-2 days)
- **Files**: `src/Orders.Api/Program.cs:6-21`

### Issue
The pipeline has no `UseAuthentication`/`UseAuthorization` and no `[Authorize]`; every endpoint, including order and invoice mutation and report export, is anonymous. Not recorded in `SECURITY_FINDINGS.md`, which is populated only by `/security-gate`.

### Recommended fix
Run `/security-gate` on the API surface to register it with SLA, then add an authentication scheme and a default authorization policy.

---

## DEBT-005: Outbox is in-memory and written after the database commit

- **Key**: messaging::in-memory-outbox
- **Category**: Architecture
- **Severity**: High
- **Effort**: L (1-2 days)
- **Files**: `src/Orders.Api/Program.cs:13`, `src/Orders.Infrastructure/Messaging/InMemoryOutbox.cs`, `src/Orders.Api/Controllers/CheckoutController.cs:25-27`

### Issue
`SaveChangesAsync` commits first, then the event is enqueued in a process-local `ConcurrentQueue`. A crash or restart between the two, or with events queued, loses the events permanently; the queue also cannot be shared across instances.

### Recommended fix
Persist outbox rows in the same transaction as the state change (table + EF) and have the processor read from it. This needs a design decision (ADR) first.

---

## DEBT-006: Feature-flag file is read and parsed on every `ReportsController` construction

- **Key**: reports::flags-file-per-request
- **Category**: Performance
- **Severity**: Medium
- **Effort**: S (<1hr)
- **Files**: `src/Orders.Api/Controllers/ReportsController.cs:14-19`

### Issue
Controllers are created per request, so each request does synchronous file I/O and JSON parsing; a missing file throws a 500. The file lives at repo-root `config/` and `Orders.Api.csproj` does not copy it to the output, so it may be missing at runtime (deployment unobserved).

### Recommended fix
Load flags once via the options/configuration system and inject them.

---

## DEBT-007: Outbound HTTP clients are sync-over-async and unregistered

- **Key**: services::http-clients-sync-over-async
- **Category**: Async
- **Severity**: Medium
- **Effort**: M (half day)
- **Files**: `src/Orders.Application/Services/PricingClient.cs:5-9`, `src/Orders.Application/Services/ShippingClient.cs`, `src/Orders.Application/Services/TaxClient.cs`

### Issue
Each client creates `new HttpClient()` per call (socket exhaustion) and blocks with `.Result` (thread-pool starvation, no cancellation, no timeout/retry). They return untyped strings, are not registered in DI, and have no callers yet.

### Recommended fix
Convert to typed `IHttpClientFactory` clients with async, `CancellationToken`, and typed results when first used.

---

## DEBT-008: Test coverage is minimal and partly tautological

- **Key**: tests::minimal-coverage
- **Category**: Testing
- **Severity**: Medium
- **Effort**: M (half day)
- **Files**: `tests/Orders.Tests/EventRegistryTests.cs`, `tests/Orders.Tests/ReportCatalogTests.cs`

### Issue
Two test files check that a hand-listed set of events is registered and reports are visible. Nothing covers `OutboxDispatcher` (version mismatch, DLQ), `OrderLifecycle`, controllers, or the report reader. Listing the same items by hand in the test duplicates the registry rather than catching an omitted registration.

### Recommended fix
Use the `add-tests` skill: behaviour tests for dispatcher routing and lifecycle events with real instances and in-memory fakes; derive event/report lists by reflection so a missed registration fails.

---

## DEBT-009: Money fields have no currency, precision or computation rules

- **Key**: domain::money-representation
- **Category**: Types/Nullability
- **Severity**: Medium
- **Effort**: M (half day)
- **Files**: `src/Orders.Domain/Entities/Order.cs:9`, `src/Orders.Domain/Entities/Invoice.cs:9`, `src/Orders.Infrastructure/Persistence/Configurations/OrderConfiguration.cs`

### Issue
`Total`, `Amount`, `Price` are bare `decimal`, client-supplied, with no EF precision config and no currency (`MoneyDto` exists but is unused). The governing invariants are unconfirmed; this is a lead, not a verdict.

### Recommended fix
Confirm the invariants with the owner, then set explicit column precision and decide currency handling.

---

## DEBT-010: Scheduled-job abstractions have no host

- **Key**: jobs::unwired-schedule
- **Category**: Architecture
- **Severity**: Low
- **Effort**: S (<1hr)
- **Files**: `src/Orders.Application/Jobs/JobSchedule.cs`, `src/Orders.Application/Jobs/NightlyReconciliationJob.cs`, `src/Orders.Application/Jobs/PurgeStaleCartsJob.cs`

### Issue
`IScheduledJob`, `JobSchedule.Cron` and the two empty jobs are referenced nowhere else; nothing schedules or locks them. Confirm whether this is intended scaffolding or dead code.

### Recommended fix
Either wire a scheduler or delete the stubs.

---

## DEBT-011: CSV export does not escape values; view name is interpolated into SQL

- **Key**: reports::csv-and-sql-composition
- **Category**: Security
- **Severity**: Low
- **Effort**: S (<1hr)
- **Files**: `src/Orders.Reporting/IReportReader.cs:17-29`

### Issue
Values are joined with `,` unescaped (commas/quotes/newlines break rows; formula-injection risk if text columns are added). `SELECT * FROM {viewName}` is safe today only because `viewName` comes from compile-time constants in `IReportExport` implementations.

### Recommended fix
Escape CSV fields; validate `viewName` against the catalog if the reader is ever exposed to other callers.

---

## Dismissed proposals — do not re-propose without materially changed evidence

> These are reviewed claims the team determined are not debt. Keep every row for auditability.
> A later scan may reopen one only by naming the concrete evidence delta in a new active item.

| Key | Affected paths / symbols | Evidence reviewed | Dismissed | Reason |
|-----|--------------------------|-------------------|-----------|--------|
| _(none)_ | _ | _ | _ | _ |

---

## Trojan Horse Opportunities

Group DEBT IDs by feature area so developers can bundle cleanup into feature work:

- **Checkout / events**: DEBT-001, DEBT-002, DEBT-005
- **API surface**: DEBT-003, DEBT-004, DEBT-009
- **Reports**: DEBT-006, DEBT-011
- **Outbound services / jobs**: DEBT-007, DEBT-010
- **Tests**: DEBT-008
