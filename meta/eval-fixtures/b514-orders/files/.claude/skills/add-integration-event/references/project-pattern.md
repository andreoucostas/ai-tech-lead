# Project pattern: integration events (draft, pending PR review)

**Provenance:** requested `/bootstrap` discovery, 2026-11-25. **Confidence:** observed. Draft pending PR review; not team-approved policy.

## Instances (all consumer-authored)

| Event | Record | Schema | Handler | Registration |
|-------|--------|--------|---------|--------------|
| order-placed v1 | `src/Orders.Domain/Events/OrderPlacedEvent.cs` | `contracts/events/order-placed.v1.schema.json` | `src/Orders.Application/EventHandlers/OrderPlacedHandler.cs` | `src/Orders.Infrastructure/Messaging/EventRegistry.cs`, `src/Orders.Api/Program.cs` |
| order-shipped v2 | `.../OrderShippedEvent.cs` | `contracts/events/order-shipped.v2.schema.json` | `.../OrderShippedHandler.cs` | same |
| invoice-issued v1 | `.../InvoiceIssuedEvent.cs` | `contracts/events/invoice-issued.v1.schema.json` | `.../InvoiceIssuedHandler.cs` | same |

Raised from `src/Orders.Application/Orders/OrderLifecycle.cs`; dispatched by `src/Orders.Infrastructure/Messaging/OutboxDispatcher.cs`; test rows in `tests/Orders.Tests/EventRegistryTests.cs`.

**Exemplar (cleanest):** `order-placed` (v1, schema and attribute aligned, matching handler).

## Divergence and counterevidence

- `order-shipped` is v2 with no v1 in the repo: the version number is not always 1.
- The handlers are identical log-only stubs; real handler logic has no instance yet.
- The in-memory outbox and in-process dispatch are flagged as debt (DEBT-003, DEBT-004); the recipe describes current behaviour, not a target.

## Unresolved

Nothing beyond the above; no other consumer of the schemas is visible in this repo.
