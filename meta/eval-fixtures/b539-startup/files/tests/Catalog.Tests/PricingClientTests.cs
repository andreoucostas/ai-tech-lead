using System.Net;
using Catalog.Api;
using Xunit;

namespace Catalog.Tests;

public class PricingClientTests
{
    private sealed class StubHandler(HttpStatusCode status, string body) : HttpMessageHandler
    {
        public int Calls { get; private set; }
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult(new HttpResponseMessage(status) { Content = new StringContent(body) });
        }
    }

    [Fact]
    public async Task GetPriceAsync_ReturnsParsedPrice()
    {
        var client = new PricingClient(new HttpClient(new StubHandler(HttpStatusCode.OK, "12.50")) { BaseAddress = new Uri("http://pricing.test/") });
        Assert.Equal(12.50m, await client.GetPriceAsync("SKU-1"));
    }

    [Fact]
    public async Task GetPriceAsync_ThrowsOnServerError()
    {
        var client = new PricingClient(new HttpClient(new StubHandler(HttpStatusCode.InternalServerError, "")) { BaseAddress = new Uri("http://pricing.test/") });
        await Assert.ThrowsAsync<HttpRequestException>(() => client.GetPriceAsync("SKU-1"));
    }
}
