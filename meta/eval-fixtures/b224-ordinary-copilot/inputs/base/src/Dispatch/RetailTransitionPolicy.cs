namespace Dispatch;

public sealed class RetailTransitionPolicy
{
    private readonly RetailCancellationOptions _options;

    public RetailTransitionPolicy(RetailCancellationOptions options)
    {
        _options = options;
    }

    public bool CanRelease(Shipment shipment) => shipment.State == ShipmentState.Packed;

    public bool CanCancel(Shipment shipment) =>
        shipment.State == ShipmentState.Queued &&
        shipment.CancellationAttempts < _options.MaximumAttempts;
}
