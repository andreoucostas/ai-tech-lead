---
name: add-integration-event
description: >
  DRAFT, pending PR review: add a new versioned integration event to the Orders service
  (event record, handler, EventRegistry entry, JSON schema, DI registration, test). Use when adding
  or changing an event such as order-placed, order-shipped or invoice-issued, or bumping an event version.
origin: discovered
---

# Add an integration event (draft, pending review)

**Status:** candidate skill, draft pending PR review; not team-approved policy. Derived from the three current
first-party instances (`order-placed`, `order-shipped`, `invoice-issued`). It is a lead, not authority:
`AGENTS.md > Conventions` wins on any conflict.

**Scope:** `src/Orders.Domain/Events`, `src/Orders.Application/EventHandlers`,
`src/Orders.Infrastructure/Messaging/EventRegistry.cs`, `contracts/events`, `src/Orders.Api/Program.cs`,
`tests/Orders.Tests/EventRegistryTests.cs`.

**Provenance:** read directly from those files on 2026-11-15; evidence, instance list and divergences are in
[references/project-pattern.md](references/project-pattern.md).

## Steps

1. Check whether an existing event or handler already owns the responsibility; extend it rather than adding a new one.
2. Add the record in `Orders.Domain/Events` implementing `IIntegrationEvent` with `[EventVersion(n)]`.
3. Add `contracts/events/<topic>.v<n>.schema.json`. **The `v<n>` in the file name must equal `[EventVersion(n)]`**:
   `OutboxDispatcher` parses it from the path and sends the event to `<topic>.dlq` on a mismatch (non-obvious).
4. Add a handler in `Orders.Application/EventHandlers` implementing `IIntegrationEventHandler<TEvent>`.
5. Add `Register<TEvent, THandler>("<topic>", "<schema path>")` in the `EventRegistry` constructor.
6. **Register the handler in `Orders.Api/Program.cs`** (`AddScoped<THandler>()`): the dispatcher resolves it with
   `GetRequiredService`, so omission fails only at runtime (non-obvious).
7. Add the event type to the `[InlineData]` list in `EventRegistryTests.cs`.
8. Emit it from `OrderLifecycle` (or the owning service) via `IOutbox.Enqueue`.
9. Run `dotnet build Orders.sln` and `dotnet test Orders.sln`.

## Unresolved

- Whether schema fields must be kept in sync with the record by hand: nothing validates payloads against the schema.
- Outbox durability is a known hazard (`FRAMEWORK-CONTEXT.md > Known Hazard Areas`); new events inherit it.

**Semantic refresh trigger:** reread `OutboxDispatcher.cs`, `EventRegistry.cs` and `Program.cs` when any changes. Result at creation: sources reread, steps match.

## After review

Add to `AGENTS.md > Common Tasks`: `` `add-integration-event` — add a versioned integration event (record, schema, handler, registry, DI, test) ``, then delete the draft wording above (Status line, `DRAFT, pending PR review:` in the description, this paragraph).
