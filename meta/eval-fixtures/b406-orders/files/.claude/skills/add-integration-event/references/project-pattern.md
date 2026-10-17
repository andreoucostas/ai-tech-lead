# Integration event pattern (draft pending PR review; not team-approved policy)

**Provenance:** requested `/bootstrap` discovery on 2026-10-17, read from first-party source at HEAD `06a55f3`.
**Confidence:** observed for steps 1-7; inferred that the order is the intended one.

## Instances (all consumer-authored)

- `OrderPlaced`: `src/Orders.Domain/Events/OrderPlacedEvent.cs`, `src/Orders.Application/EventHandlers/OrderPlacedHandler.cs`, `contracts/events/order-placed.v1.schema.json`
- `OrderShipped`: `OrderShippedEvent.cs`, `OrderShippedHandler.cs`, `contracts/events/order-shipped.v2.schema.json`
- `InvoiceIssued`: `InvoiceIssuedEvent.cs`, `InvoiceIssuedHandler.cs`, `contracts/events/invoice-issued.v1.schema.json`
- Shared wiring: `src/Orders.Infrastructure/Messaging/EventRegistry.cs:12-14`, `src/Orders.Api/Program.cs:17-19`, `src/Orders.Application/Orders/OrderLifecycle.cs:11-18`, `tests/Orders.Tests/EventRegistryTests.cs`

**Cleanest exemplar:** `OrderPlaced`, which is v1 and has a lifecycle method.

## Non-obvious, repo-specific steps

- `OutboxDispatcher.cs:29-35` compares the number in `*.vN.schema.json` with `[EventVersion]`; on mismatch it publishes to `<topic>.dlq` and returns.
- `OutboxDispatcher.cs:24-27` drops events missing from `EventRegistry` without logging.
- `OutboxDispatcher.cs:38` uses `GetRequiredService(registration.Handler)`, so the handler must be in DI.

## Counterevidence and unresolved

- `OrderShipped` is v2, but no v1 schema exists, so the version-bump procedure is unresolved.
- The schema file is never opened at runtime and its content is not validated. Whether consumers validate it is unknown.
- All three handlers only log. A handler with real logic has no precedent, and the DEBT-002 failure semantics apply.
- `Orders.Reporting` has no analogue; this is the event path only.

**Semantic refresh:** trigger: changes to the files above; result: decisive lines reread on 2026-10-17, no execution.
**Draft status:** draft pending PR review; not team-approved policy.
