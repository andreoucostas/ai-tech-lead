---
name: add-integration-event
description: >
  DRAFT, pending PR review: add a new integration event to the Orders service (event record,
  versioned JSON schema, handler, EventRegistry entry, DI registration). Use when adding or
  versioning an event published through the outbox.
origin: discovered
---

# Add an integration event (DRAFT)

**Status:** candidate skill derived from three current first-party instances (`OrderPlaced`,
`OrderShipped`, `InvoiceIssued`). It is a lead, not authority; `AGENTS.md > Conventions` wins on any
conflict. Draft pending PR review; not team-approved policy.

**Provenance:** discovered by `/bootstrap` (A8) on 2026-10-18 from the files listed in
[references/project-pattern.md](./references/project-pattern.md). Confidence: `observed` for the file
set and ordering; `unresolved` for the publish/handler contract (all handlers are logging stubs).

## Steps

1. Check whether an existing event already owns the responsibility (`src/Orders.Domain/Events/`); version an existing one instead of adding a near-duplicate.
2. Add `src/Orders.Domain/Events/<Name>Event.cs`: `[EventVersion(N)] public sealed record <Name>Event(Guid EventId, ...) : IIntegrationEvent;`.
3. Add `contracts/events/<topic>.vN.schema.json`. **N must equal `[EventVersion]`.** `OutboxDispatcher` parses `\.v(\d+)\.schema\.json$` from the registered path; on mismatch the event goes to `<topic>.dlq` and its handler never runs, with no error.
4. Add `src/Orders.Application/EventHandlers/<Name>Handler.cs` implementing `IIntegrationEventHandler<<Name>Event>`.
5. Register in `EventRegistry` (`src/Orders.Infrastructure/Messaging/EventRegistry.cs`): `Register<TEvent, THandler>("<topic>", "contracts/events/<topic>.vN.schema.json")`. An event type missing here is dropped silently.
6. Register the handler in `src/Orders.Api/Program.cs` (`AddScoped<THandler>()`). The dispatcher resolves it with `GetRequiredService`, so a missing line fails at runtime, not build.
7. Emit it from `OrderLifecycle` (`src/Orders.Application/Orders/OrderLifecycle.cs`) via `_outbox.Enqueue(...)`.
8. Add the type to the `[InlineData]` list in `tests/Orders.Tests/EventRegistryTests.cs`.

## Unresolved

Whether the outbox/at-least-once semantics, ordering, and duplicate-EventId rules are intended (see TECH_DEBT DEBT-001/002/005 and Known Hazard Areas); do not copy the current emit-after-commit pattern into new financial flows without confirming.

## After review

Add to `AGENTS.md > Common Tasks`: ``- `add-integration-event` — add an outbox integration event: record, versioned schema, handler, registry and DI registration``. Then delete the DRAFT wording from this file's description and body.
