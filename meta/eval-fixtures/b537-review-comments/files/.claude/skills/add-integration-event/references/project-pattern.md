# Project pattern: integration events (draft, pending PR review)

Not team-approved policy. Observed 2026-11-15; revision: `b28d35f`. Status: `observed`.

## Instances (all consumer-authored; exemplar: `order-placed`)

| Event | Record | Handler | Schema | Registry |
|-------|--------|---------|--------|----------|
| order-placed v1 (**exemplar**) | `src/Orders.Domain/Events/OrderPlacedEvent.cs` | `src/Orders.Application/EventHandlers/OrderPlacedHandler.cs` | `contracts/events/order-placed.v1.schema.json` | `EventRegistry.cs:12` |
| order-shipped v2 | `.../OrderShippedEvent.cs` | `.../OrderShippedHandler.cs` | `contracts/events/order-shipped.v2.schema.json` | `EventRegistry.cs:13` |
| invoice-issued v1 | `.../InvoiceIssuedEvent.cs` | `.../InvoiceIssuedHandler.cs` | `contracts/events/invoice-issued.v1.schema.json` | `EventRegistry.cs:14` |

Shared: `Program.cs:17-19` registers each handler; `tests/Orders.Tests/EventRegistryTests.cs` lists each type; `OrderLifecycle.cs` emits each.

## Where instances diverge

Only the version (`order-shipped` is v2, others v1); no evidenced reason. Only the `order-shipped` schema content was read.

## Counterevidence / exceptions

- Handlers are logging stubs (`HandleAsync` only logs); real handler behaviour is not evidenced.
- `ServiceBusPublisher` only logs; no broker package.

## Dependencies

`OutboxDispatcher.cs:29-40` (version check, handler resolution), `Program.cs`, `EventRegistry.cs`.
