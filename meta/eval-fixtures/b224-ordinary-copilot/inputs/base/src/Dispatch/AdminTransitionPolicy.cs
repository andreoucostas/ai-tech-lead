namespace Dispatch;

public sealed class AdminTransitionPolicy
{
    private readonly RetailCancellationOptions _options;

    public AdminTransitionPolicy(RetailCancellationOptions options)

    {
        _options = options;
    }

    public bool CanCancel(Shipment shipment) =>
        shipment.State is ShipmentState.Queued or ShipmentState.Reserved &&
        shipment.CancellationAttempts <= _options.MaximumAttempts;
}
