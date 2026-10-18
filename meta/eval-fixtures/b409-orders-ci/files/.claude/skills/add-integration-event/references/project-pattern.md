# Project pattern: integration events (DRAFT, pending PR review)

Evidence status: `observed`. Last semantic recheck 2026-10-18: reread each path below.

Instances (3, consumer-authored, whole constellation each):

| Event | Event record | Schema | Handler | Registry |
|-------|--------------|--------|---------|----------|
| order-placed | `src/Orders.Domain/Events/OrderPlacedEvent.cs` (v1) | `contracts/events/order-placed.v1.schema.json` | `src/Orders.Application/EventHandlers/OrderPlacedHandler.cs` | `src/Orders.Infrastructure/Messaging/EventRegistry.cs` |
| order-shipped | `src/Orders.Domain/Events/OrderShippedEvent.cs` (v2) | `contracts/events/order-shipped.v2.schema.json` | `src/Orders.Application/EventHandlers/OrderShippedHandler.cs` | same |
| invoice-issued | `src/Orders.Domain/Events/InvoiceIssuedEvent.cs` (v1) | `contracts/events/invoice-issued.v1.schema.json` | `src/Orders.Application/EventHandlers/InvoiceIssuedHandler.cs` | same |

Shared: DI lines in `src/Orders.Api/Program.cs:16-18`, emit methods in `src/Orders.Application/Orders/OrderLifecycle.cs`, hand-listed test in `tests/Orders.Tests/EventRegistryTests.cs`.

**Cleanest exemplar:** `OrderPlaced` (v1). Reproduce structure, not contents.

**Divergence:** `OrderShipped` is v2 and has no v1 schema; how a v1 to v2 bump is meant to be handled (parallel schemas, consumers) is unresolved. Schemas were not diffed against the records here.

**Counterevidence/limits:** handlers only log; the publisher (`ServiceBusPublisher`) only logs; so the real publish/consume contract is unobserved.

**Semantic refresh trigger:** any change to `OutboxDispatcher.cs`, `EventRegistry.cs`, or a new event. Result at creation: sources reread, no contradictions.
