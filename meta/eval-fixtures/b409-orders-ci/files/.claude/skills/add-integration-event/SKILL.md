---
name: add-integration-event
description: >
  DRAFT, pending PR review: add a new integration event to the Orders service (event record,
  schema file, handler, EventRegistry entry, DI registration, OrderLifecycle method). Use when
  adding or versioning an outbound event such as order-placed or invoice-issued.
origin: discovered
---
# Add an integration event (draft)

**Status:** candidate, draft pending PR review. Derived from the three current first-party instances (`order-placed`, `order-shipped`, `invoice-issued`). It is a lead, not authority; `AGENTS.md > Conventions` wins on any conflict. Instances and divergences are in [references/project-pattern.md](./references/project-pattern.md).

1. Check whether an existing event already owns the responsibility (`src/Orders.Domain/Events/`, `EventRegistry.cs`). Extend or version it rather than duplicating.
2. Add `src/Orders.Domain/Events/<Name>Event.cs`: `[EventVersion(n)] public sealed record <Name>Event(Guid EventId, ...) : IIntegrationEvent;`.
3. Add `contracts/events/<topic>.v<n>.schema.json`. **The `v<n>` in the file name must equal the `[EventVersion]` value**, or `OutboxDispatcher` publishes to `<topic>.dlq` and skips the handler without logging (`OutboxDispatcher.cs:29-35`). Schema property names match the record's PascalCase members.
4. Add `src/Orders.Application/EventHandlers/<Name>Handler.cs` implementing `IIntegrationEventHandler<<Name>Event>`.
5. Add `Register<<Name>Event, <Name>Handler>("<topic>", "contracts/events/<topic>.v<n>.schema.json")` in `EventRegistry`'s constructor.
6. **Register the handler in `Program.cs`** with `AddScoped<<Name>Handler>()`; the dispatcher resolves it with `GetRequiredService` (`OutboxDispatcher.cs:38`) and fails at run time if missing.
7. Add the enqueue method to `OrderLifecycle` and call it from the controller action.
8. Add the event type to the `InlineData` list in `tests/Orders.Tests/EventRegistryTests.cs`.
9. Run `dotnet build Orders.sln` then `dotnet test Orders.sln --no-build`.

Unresolved: whether a version bump keeps the old schema file (only one `order-shipped` version exists).

Semantic refresh: trigger is a change to `OutboxDispatcher`, `EventRegistry` or `contracts/events`; result at creation: instance files read, the version check and DI lookup reread.

## After review
Add to `AGENTS.md > Common Tasks`: ``- `add-integration-event` — add an outbound integration event (record, versioned schema file, handler, registry and DI entries, test)``, then delete the `DRAFT, pending PR review:` wording and this section.
