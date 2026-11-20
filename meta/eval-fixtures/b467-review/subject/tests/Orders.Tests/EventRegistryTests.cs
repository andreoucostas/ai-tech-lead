using Orders.Domain.Events;
using Orders.Infrastructure.Messaging;
using Xunit;

namespace Orders.Tests;

public class EventRegistryTests
{
    [Theory]
    [InlineData(typeof(OrderPlacedEvent))]
    [InlineData(typeof(OrderShippedEvent))]
    public void Event_is_registered(Type eventType) => Assert.True(new EventRegistry().TryGet(eventType, out _));

    [Fact]
    public void Registry_can_be_constructed() => Assert.NotNull(new EventRegistry());
}
