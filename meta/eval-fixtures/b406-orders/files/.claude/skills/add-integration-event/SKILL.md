---
name: add-integration-event
description: >
  DRAFT, pending PR review: add a new integration event to the Orders outbox, covering the
  event record, versioned JSON schema, handler, DI registration, EventRegistry entry and test.
  USE FOR: a new event such as order-cancelled, or a new version of an existing event.
  DO NOT USE FOR: changing handler logic only, or the database outbox redesign (DEBT-005).
origin: discovered
---

# Add an integration event (draft)

**Status: candidate, draft pending PR review. This is a lead, not authority. `AGENTS.md > Conventions` wins on any conflict.**

Derived from the three current first-party events (`OrderPlaced`, `OrderShipped`, `InvoiceIssued`). Scope: `src/Orders.*` and `contracts/events/`. Counterevidence and unresolved steps are listed in [references/project-pattern.md](./references/project-pattern.md).

0. Check whether an existing event or handler already owns the responsibility before adding one.
1. Add `src/Orders.Domain/Events/<Name>Event.cs`: a `sealed record` with `[EventVersion(n)]` implementing `IIntegrationEvent`, with `Guid EventId` first.
2. Add `contracts/events/<topic>.v<n>.schema.json`. The `v<n>` must equal the `[EventVersion]` value. A mismatch makes `OutboxDispatcher` publish to `<topic>.dlq` with no error.
3. Add `src/Orders.Application/EventHandlers/<Name>Handler.cs` implementing `IIntegrationEventHandler<T>`.
4. Register the handler with `AddScoped` in `src/Orders.Api/Program.cs`. The dispatcher resolves it with `GetRequiredService`, so a missing registration fails at dispatch.
5. Add a `Register<TEvent, THandler>(topic, schemaPath)` call in the `EventRegistry` constructor. An unregistered event is silently dropped.
6. If an order or invoice action raises it, add a method to `OrderLifecycle` and call it from the controller.
7. Add an `[InlineData(typeof(...))]` row to `tests/Orders.Tests/EventRegistryTests.cs`.

Refresh trigger: any change to `OutboxDispatcher`, `EventRegistry`, or the event files. Last result: instances reread on 2026-10-17; no runtime check made.

## After review

Add one line to `AGENTS.md > Common Tasks`: ``- `add-integration-event` — add an outbox event with versioned schema, handler, DI and registry entry``. Then delete the `DRAFT, pending PR review:` wording from the description and the status line above.
