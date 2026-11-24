---
name: add-integration-event
description: >
  DRAFT, pending PR review: add a new integration event (record, version attribute, JSON
  schema, EventRegistry entry, handler, DI registration, lifecycle method, test row) to the
  Orders event pipeline. Use for "add an event", "publish X when Y happens", or a new topic.
origin: discovered
---

# Add an integration event (draft, pending review)

**Status:** candidate recipe derived from the three current first-party instances (`order-placed`, `order-shipped`, `invoice-issued`). It is a lead, not authority; `AGENTS.md > Conventions` wins on any conflict. Draft pending PR review; not team-approved policy.

**Scope:** `src/Orders.Domain/Events`, `src/Orders.Application`, `src/Orders.Infrastructure/Messaging`, `src/Orders.Api/Program.cs`, `contracts/events`, `tests/Orders.Tests`.

Details, instance paths and counterevidence: [references/project-pattern.md](./references/project-pattern.md).

## Steps

1. Check whether an existing event or handler already owns the responsibility; extend it instead of adding a new one.
2. Add `<Name>Event` record in `src/Orders.Domain/Events/` implementing `IIntegrationEvent` with `[EventVersion(n)]`.
3. Add `contracts/events/<topic>.v<n>.schema.json` where **`n` equals the attribute version**. This is the non-obvious step: `OutboxDispatcher` compares the `.vN.` suffix of the registered schema path with the attribute and silently publishes to `<topic>.dlq` on mismatch.
4. Add `<Name>Handler : IIntegrationEventHandler<<Name>Event>` in `src/Orders.Application/EventHandlers/`.
5. Register it in `EventRegistry` (`Register<TEvent, THandler>(topic, schemaPath)`); an unregistered event type is dropped without a log.
6. Register the handler as scoped in `src/Orders.Api/Program.cs`; the dispatcher resolves it with `GetRequiredService` and throws if absent.
7. Raise it by adding a method to `OrderLifecycle` that calls `IOutbox.Enqueue`.
8. Add an `[InlineData(typeof(<Name>Event))]` row to `tests/Orders.Tests/EventRegistryTests.cs`.
9. Verify with `dotnet build Orders.sln` and `dotnet test Orders.sln`.

## Unresolved

- Whether new events should follow the in-memory outbox as-is (see `TECH_DEBT.md` DEBT-003/004).
- Semantic refresh trigger: any change to `OutboxDispatcher.cs`, `EventRegistry.cs` or `Program.cs`. Result: decisive sources reread 2026-11-25; no runtime proof.

## After review

Add one Common Tasks line to `AGENTS.md` (`add-integration-event` — add an integration event end to end), then delete the `DRAFT, pending PR review:` wording, this status paragraph and the Unresolved note in this skill and its reference file.
