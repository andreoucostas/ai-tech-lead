namespace Dispatch;

public enum ShipmentState
{
    Draft,
    Queued,
    Reserved,
    Packed,
    Released,
    Cancelled
}

public sealed class Shipment
{
    public Shipment(ShipmentState state, int cancellationAttempts)
    {
        State = state;
        CancellationAttempts = cancellationAttempts;
    }

    public ShipmentState State { get; private set; }

    public int CancellationAttempts { get; }

    internal void MarkReleased() => State = ShipmentState.Released;

    internal void MarkCancelled() => State = ShipmentState.Cancelled;
}
