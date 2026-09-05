using Unity;
using Unity.Lifetime;

namespace B216.UnityFixture;

public interface IOrderFeed { }
public sealed class OrderFeed : IOrderFeed { }

public static class CompositionRoot
{
    public static void Configure(UnityContainer container)
    {
        container.RegisterType<IOrderFeed, OrderFeed>(new ContainerControlledLifetimeManager());
    }
}
