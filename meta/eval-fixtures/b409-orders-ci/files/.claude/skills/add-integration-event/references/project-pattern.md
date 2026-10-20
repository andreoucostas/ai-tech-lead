# Integration event: instances (draft, pending PR review)

Exemplar (cleanest): `order-placed`.

| Event | Record | Schema | Handler | Registry |
|---|---|---|---|---|
| order-placed v1 | `src/Orders.Domain/Events/OrderPlacedEvent.cs` | `contracts/events/order-placed.v1.schema.json` | `src/Orders.Application/EventHandlers/OrderPlacedHandler.cs` | `src/Orders.Infrastructure/Messaging/EventRegistry.cs:12` |
| order-shipped v2 | `src/Orders.Domain/Events/OrderShippedEvent.cs` | `contracts/events/order-shipped.v2.schema.json` | `src/Orders.Application/EventHandlers/OrderShippedHandler.cs` | `EventRegistry.cs:13` |
| invoice-issued v1 | `src/Orders.Domain/Events/InvoiceIssuedEvent.cs` | `contracts/events/invoice-issued.v1.schema.json` | `src/Orders.Application/EventHandlers/InvoiceIssuedHandler.cs` | `EventRegistry.cs:14` |

Shared files: `src/Orders.Api/Program.cs:17-19` (handler DI), `src/Orders.Application/Orders/OrderLifecycle.cs` (enqueue), `tests/Orders.Tests/EventRegistryTests.cs`.

Counterevidence: `OrderShippedEvent` is v2 while the others are v1, and no v1 shipped schema remains, so version-bump practice is unresolved. No test validates a schema against its record.
