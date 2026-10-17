# Tech Debt Register

> One block per item. Sort by severity then effort. Reference items by ID in commit messages and PRs.

---

## DEBT-001: Outbound clients create `HttpClient` per call and block on `.Result`

- **Key**: services::httpclient-sync-over-async
- **Category**: Async
- **Severity**: High
- **Effort**: S (<1hr)
- **Files**: `src/Orders.Application/Services/PricingClient.cs:7-8`, `src/Orders.Application/Services/ShippingClient.cs`, `src/Orders.Application/Services/TaxClient.cs`

### Issue
Each client does `new HttpClient()` per call and `.GetStringAsync(...).Result`, which risks socket exhaustion and thread-pool starvation. URLs are hard-coded, and the clients are not registered in `Program.cs`.

### Recommended fix
Make the methods async with a `CancellationToken`, use `IHttpClientFactory` typed clients, and move base URLs to configuration. Nothing calls them today, so the change is low risk.

---

## DEBT-002: Outbox dispatch has no failure handling

- **Key**: messaging::dispatch-failure-handling
- **Category**: Architecture
- **Severity**: High
- **Effort**: M (half day)
- **Files**: `src/Orders.Infrastructure/Messaging/OutboxProcessor.cs:22-25`, `src/Orders.Infrastructure/Messaging/OutboxDispatcher.cs:24-40`

### Issue
An event is dequeued before dispatch. An exception from the publisher or the handler is unhandled inside `BackgroundService.ExecuteAsync`, so the event is lost and the host's default behaviour stops the process. Publish happens before the handler runs, so a handler failure leaves it published but unprocessed. Unregistered events are silently dropped (line 26).

### Recommended fix
Catch per event, log, and retry or dead-letter. Decide on delivery semantics together with DEBT-005.

---

## DEBT-003: Checkout actions have no state guard or idempotency

- **Key**: checkout::state-transition-idempotency
- **Category**: API Design
- **Severity**: High
- **Effort**: M (half day)
- **Files**: `src/Orders.Api/Controllers/CheckoutController.cs:25-27,36-38,45-47`, `src/Orders.Application/Orders/OrderLifecycle.cs:12-18`

### Issue
`Place` and `Ship` set `Status` to a free string whatever the current state, and each call emits a new event with a fresh `Guid.NewGuid()` `EventId`. Repeated or concurrent calls therefore produce duplicate events that consumers cannot de-duplicate. `Issue` persists nothing and enqueues an event every time. There is no concurrency token. Money invariants are unconfirmed: no policy is stated in the repo.

### Recommended fix
Define the allowed transitions (an enum rather than a string) and make the operations idempotent, for example with a derived `EventId` and a row-version check. Confirm the policy with the owner first.

---

## DEBT-004: No authentication, and CRUD controllers bind and return entities directly

- **Key**: api::unauthenticated-entity-crud
- **Category**: Security
- **Severity**: High
- **Effort**: M (half day)
- **Files**: `src/Orders.Api/Program.cs`, `src/Orders.Api/Controllers/CustomersController.cs`, `src/Orders.Api/Controllers/InvoicesController.cs`, `src/Orders.Api/Controllers/OrdersController.cs`, `src/Orders.Api/Controllers/ProductsController.cs`

### Issue
`Program.cs` has no authentication or authorization, so every endpoint is open. Four near-identical controllers use `OrdersDbContext` directly and accept domain entities as request bodies (over-posting: client-set `Id`, `Total`, `Paid`, `Status`) with no validation. Run `/security-gate` to triage whether this belongs in `SECURITY_FINDINGS.md`.

### Recommended fix
Add authentication and authorization, introduce request/response DTOs with validation, and move logic into an Application service.

---

## DEBT-005: Outbox is in-memory and not atomic with the database write

- **Key**: messaging::in-memory-outbox
- **Category**: Architecture
- **Severity**: High
- **Effort**: L (1-2 days)
- **Files**: `src/Orders.Infrastructure/Messaging/InMemoryOutbox.cs:9`, `src/Orders.Api/Program.cs:13`, `src/Orders.Api/Controllers/CheckoutController.cs:26-27`

### Issue
Events live only in a `ConcurrentQueue`. A restart or crash between `SaveChangesAsync` and dispatch loses the event, and a second instance would not share the queue.

### Recommended fix
Persist outbox rows in the same transaction as the state change (EF table plus processor). This needs a spike on delivery semantics and a schema deployment path, which is not evidenced in the repo.

---

## DEBT-006: Tests do not cover behaviour

- **Key**: tests::thin-coverage
- **Category**: Testing
- **Severity**: High
- **Effort**: L (1-2 days)
- **Files**: `tests/Orders.Tests/EventRegistryTests.cs`, `tests/Orders.Tests/ReportCatalogTests.cs`

### Issue
The two test classes only check that events are registered and that three flags are visible. Nothing covers `OutboxDispatcher` (DLQ and version mismatch), `OrderLifecycle`, the controllers, or the CSV reader. No build or test command is recorded for the repo.

### Recommended fix
Use the `add-tests` skill, starting with the dispatcher and checkout paths, and record the test command in `AGENTS.md > Verification Commands`.

---

## DEBT-007: EF decimal precision is not configured

- **Key**: persistence::decimal-precision
- **Category**: Data Access
- **Severity**: Medium
- **Effort**: S (<1hr)
- **Files**: `src/Orders.Infrastructure/Persistence/Configurations/OrderConfiguration.cs`, `src/Orders.Infrastructure/Persistence/Configurations/InvoiceConfiguration.cs`, `src/Orders.Infrastructure/Persistence/Configurations/ProductConfiguration.cs`

### Issue
`Order.Total`, `Invoice.Amount` and `Product.Price` are `decimal`, but no configuration sets a column type or precision, so EF's provider default applies. The intended scale is unknown.

### Recommended fix
Set `HasPrecision` once the owner confirms the scale. Check it against the `rpt.*` views.

---

## DEBT-008: Unpaged, tracked reads

- **Key**: api::unpaged-tracked-lists
- **Category**: Performance
- **Severity**: Medium
- **Effort**: S (<1hr)
- **Files**: `src/Orders.Api/Controllers/OrdersController.cs:16`, `src/Orders.Api/Controllers/CustomersController.cs`, `src/Orders.Api/Controllers/InvoicesController.cs`, `src/Orders.Api/Controllers/ProductsController.cs`

### Issue
`List` returns every row with `ToListAsync()` and change tracking on. `PagedResultDto` exists but is unused.

### Recommended fix
Add `AsNoTracking()` and paging when these controllers are reworked (DEBT-004).

---

## DEBT-009: CSV export is unescaped and fully buffered

- **Key**: reporting::csv-escaping
- **Category**: API Design
- **Severity**: Medium
- **Effort**: S (<1hr)
- **Files**: `src/Orders.Reporting/IReportReader.cs:21-28`

### Issue
Values are joined with `,` without quoting, escaping, or a header row, and the whole result is built in memory. A value containing a comma or newline corrupts the row. `viewName` is interpolated into SQL, but it only ever comes from `ReportCatalog`.

### Recommended fix
Write the header, quote and escape fields, and stream the output.

---

## DEBT-010: Controller async actions ignore cancellation

- **Key**: api::cancellation-token
- **Category**: Async
- **Severity**: Medium
- **Effort**: M (half day)
- **Files**: `src/Orders.Api/Controllers/CheckoutController.cs`, `src/Orders.Api/Controllers/OrdersController.cs`

### Issue
Only `ReportsController.Export` accepts a `CancellationToken`. The other async actions cannot be cancelled.

### Recommended fix
Add the token to the actions you touch, as the Boy Scout rule allows.

---

## DEBT-011: Target framework is net8.0

- **Key**: platform::net8-support-window
- **Category**: Dependencies
- **Severity**: Medium
- **Effort**: M (half day)
- **Files**: `src/Orders.Api/Orders.Api.csproj`, `tests/Orders.Tests/Orders.Tests.csproj`

### Issue
All projects target `net8.0`. Unverified: .NET 8 is understood to leave support in November 2026, so confirm against Microsoft's support policy.

### Recommended fix
Use the `dependency-audit` skill to plan the upgrade.

---

## DEBT-012: Scheduled jobs are defined but never run

- **Key**: jobs::unwired-scheduler
- **Category**: Architecture
- **Severity**: Low
- **Effort**: S (<1hr)
- **Files**: `src/Orders.Application/Jobs/JobSchedule.cs`, `src/Orders.Application/Jobs/NightlyReconciliationJob.cs`, `src/Orders.Application/Jobs/PurgeStaleCartsJob.cs`

### Issue
`NightlyReconciliationJob` and `PurgeStaleCartsJob` are empty, and no runner, registration or lock implementation uses `IScheduledJob` or `JobSchedule` (grep over `src/`). The cron table is dead configuration.

### Recommended fix
Either wire a scheduler and implement the jobs, or delete them.

---

## Dismissed proposals — do not re-propose without materially changed evidence

| Key | Affected paths / symbols | Evidence reviewed | Dismissed | Reason |
|-----|--------------------------|-------------------|-----------|--------|
| _(none)_ | _ | _ | _ | _ |

---

## Trojan Horse Opportunities

- **Checkout / events**: DEBT-002, DEBT-003, DEBT-005, DEBT-010
- **API controllers**: DEBT-004, DEBT-008, DEBT-010
- **Reporting**: DEBT-009
- **Services / jobs**: DEBT-001, DEBT-012
- **Persistence**: DEBT-007
- **Platform**: DEBT-006, DEBT-011
