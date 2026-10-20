# Tech Debt Register

> One block per item. Sort by severity then effort. Reference items by ID in commit messages and PRs.

---

## DEBT-001: Events are lost: in-memory outbox and unguarded dispatch

- **Key**: messaging::volatile-outbox
- **Category**: Architecture
- **Severity**: High
- **Effort**: L (1-2 days)
- **Files**: `src/Orders.Infrastructure/Messaging/InMemoryOutbox.cs:7`, `src/Orders.Infrastructure/Messaging/OutboxProcessor.cs:18`, `src/Orders.Api/Controllers/CheckoutController.cs:23`

### Issue
Order state is saved, then the event is queued in memory. A crash or restart loses queued events, and an exception in `DispatchAsync` loses the dequeued event and faults the `BackgroundService` (which stops the host by default in .NET 8).

### Recommended fix
Persist events in the same `SaveChanges` transaction (a table-backed outbox) and have the processor catch, log and retry per event. Needs a design decision; see Known Hazard Areas.

---

## DEBT-002: Service clients block on `.Result` and create `HttpClient` per call

- **Key**: services::httpclient-sync-over-async
- **Category**: Async
- **Severity**: High
- **Effort**: S (<1hr)
- **Files**: `src/Orders.Application/Services/PricingClient.cs:5`, `src/Orders.Application/Services/ShippingClient.cs:5`, `src/Orders.Application/Services/TaxClient.cs:5`

### Issue
Each client does `new HttpClient()` and `.GetStringAsync(...).Result`, which risks socket exhaustion and thread-pool blocking. The classes are not registered in DI or referenced anywhere in the repo.

### Recommended fix
Confirm whether they are used outside this repo; if not, delete them. Otherwise make them async over an injected `HttpClient` (`AddHttpClient`).

---

## DEBT-003: CRUD controllers bind domain entities as request bodies

- **Key**: api::entity-request-bodies
- **Category**: API Design
- **Severity**: High
- **Effort**: M (half day)
- **Files**: `src/Orders.Api/Controllers/OrdersController.cs:26`, `src/Orders.Api/Controllers/InvoicesController.cs:26`, `src/Orders.Api/Controllers/CustomersController.cs:26`, `src/Orders.Api/Controllers/ProductsController.cs:26`

### Issue
Callers can set any entity property, including `Id`, `Total`, `Status`, `Amount` and `Paid` (over-posting), and responses expose entities directly. No validation exists.

### Recommended fix
Introduce request/response DTOs per endpoint and validate them. Pair with the missing-authentication question, which belongs in `/security-gate`, not here.

---

## DEBT-004: Order and invoice transitions are unguarded magic strings

- **Key**: checkout::unguarded-status-transitions
- **Category**: Architecture
- **Severity**: Medium
- **Effort**: M (half day)
- **Files**: `src/Orders.Api/Controllers/CheckoutController.cs:20`, `src/Orders.Domain/Entities/Order.cs:8`

### Issue
`Place`, `Ship` and `Issue` set `Status` to string literals without checking the current state, and repeat calls enqueue duplicate events with new `EventId`s. `Issue` changes nothing on the invoice.

### Recommended fix
Move transitions onto the entity or `OrderLifecycle` with allowed-state checks, once the intended state machine is confirmed.

---

## DEBT-005: Read queries are change-tracked and unbounded

- **Key**: controllers::unbounded-tracked-reads
- **Category**: Data Access
- **Severity**: Medium
- **Effort**: S (<1hr)
- **Files**: `src/Orders.Api/Controllers/OrdersController.cs:16`, `src/Orders.Api/Controllers/InvoicesController.cs:16`, `src/Orders.Api/Controllers/CustomersController.cs:16`, `src/Orders.Api/Controllers/ProductsController.cs:16`

### Issue
`List` returns whole tables via `ToListAsync()` with change tracking and no paging; `Get` uses `FindAsync` and no `CancellationToken` is accepted.

### Recommended fix
Add `AsNoTracking()`, paging (a `PagedResultDto` already exists but is unused) and cancellation tokens.

---

## DEBT-006: Money columns have no explicit precision

- **Key**: persistence::decimal-precision
- **Category**: Data Access
- **Severity**: Medium
- **Effort**: S (<1hr)
- **Files**: `src/Orders.Infrastructure/Persistence/Configurations/OrderConfiguration.cs:9`, `src/Orders.Infrastructure/Persistence/Configurations/InvoiceConfiguration.cs:9`, `src/Orders.Infrastructure/Persistence/Configurations/ProductConfiguration.cs:9`

### Issue
`Total`, `Amount` and `Price` are `decimal` with no `HasPrecision`; EF Core falls back to its default column type and warns. No financial policy was supplied to judge whether that default is acceptable.

### Recommended fix
Set precision and scale per the team's money policy, and add a migration. Needs the policy first.

---

## DEBT-007: CSV export does not escape values

- **Key**: reporting::csv-no-escaping
- **Category**: API Design
- **Severity**: Medium
- **Effort**: S (<1hr)
- **Files**: `src/Orders.Reporting/IReportReader.cs:28`

### Issue
Values are joined with `,` without quoting or escaping, so a value containing a comma, quote or newline corrupts the row.

### Recommended fix
Quote and escape per RFC 4180 and add a test with such a value.

---

## DEBT-008: Little behaviour is covered by tests

- **Key**: tests::dispatch-and-controllers-untested
- **Category**: Testing
- **Severity**: Medium
- **Effort**: M (half day)
- **Files**: `tests/Orders.Tests/EventRegistryTests.cs:13`, `tests/Orders.Tests/ReportCatalogTests.cs:16`, `src/Orders.Infrastructure/Messaging/OutboxDispatcher.cs:22`

### Issue
Two tests check registry and flag lookups only. `OutboxDispatcher` (DLQ routing, handler invocation), the controllers and `SqlReportReader` have no tests.

### Recommended fix
Add dispatcher tests with a fake `IMessagePublisher` using the `add-tests` skill; extend after DEBT-001 is designed.

---

## DEBT-009: Unused scaffolding

- **Key**: application::unreferenced-scaffolding
- **Category**: Architecture
- **Severity**: Low
- **Effort**: S (<1hr)
- **Files**: `src/Orders.Application/Jobs/JobSchedule.cs:3`, `src/Orders.Application/Contracts/MoneyDto.cs:3`, `src/Orders.Application/Contracts/PagedResultDto.cs:3`

### Issue
Jobs (no-op, no runner), the `Contracts/` DTOs and the quote clients are referenced nowhere in the repo. They may be consumed externally or planned.

### Recommended fix
Confirm with the team, then delete or wire them up.

---

## Dismissed proposals — do not re-propose without materially changed evidence

| Key | Affected paths / symbols | Evidence reviewed | Dismissed | Reason |
|-----|--------------------------|-------------------|-----------|--------|
| _(none)_ | _ | _ | _ | _ |

---

## Trojan Horse Opportunities

Group DEBT IDs by feature area so developers can bundle cleanup into feature work:

- **Checkout / messaging**: DEBT-001, DEBT-004, DEBT-008
- **CRUD controllers**: DEBT-003, DEBT-005
- **Persistence**: DEBT-006
- **Reporting**: DEBT-007
- **Application services**: DEBT-002, DEBT-009
