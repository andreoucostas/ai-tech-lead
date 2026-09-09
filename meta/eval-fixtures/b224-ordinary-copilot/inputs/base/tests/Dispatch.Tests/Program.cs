using Dispatch;

var passed = 0;
var failed = 0;

Check("packed retail shipment releases", () =>
{
    var shipment = new Shipment(ShipmentState.Packed, 0);
    var service = CreateService();
    return service.TryRelease(shipment) && shipment.State == ShipmentState.Released;
});

Check("queued retail shipment does not release", () =>
{
    var shipment = new Shipment(ShipmentState.Queued, 0);
    var service = CreateService();
    return !service.TryRelease(shipment) && shipment.State == ShipmentState.Queued;
});

Console.WriteLine($"{passed} passed, {failed} failed");
return failed;

RetailShipmentService CreateService() =>
    new(new RetailTransitionPolicy(new RetailCancellationOptions(2)));

void Check(string name, Func<bool> assertion)
{
    if (assertion())
    {
        passed++;
        Console.WriteLine($"PASS: {name}");
    }
    else
    {
        failed++;
        Console.WriteLine($"FAIL: {name}");
    }
}
