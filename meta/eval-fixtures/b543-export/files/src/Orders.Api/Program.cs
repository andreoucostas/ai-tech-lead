using Orders.Api;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSingleton<OrderRepository>();
builder.Services.AddSingleton<OrderService>();

var app = builder.Build();
app.MapGet("/health", () => Results.Ok(new { status = "up" }));
app.MapGet("/orders", (OrderService orders) => Results.Ok(orders.List()));
app.MapGet("/orders/{id:int}", (int id, OrderService orders) =>
    orders.Find(id) is { } order ? Results.Ok(order) : Results.NotFound());
app.MapPost("/orders", (PlaceOrderRequest request, OrderService orders) =>
{
    try
    {
        var order = orders.Place(request.Customer, request.Total, DateOnly.FromDateTime(DateTime.UtcNow));
        return Results.Created($"/orders/{order.Id}", order);
    }
    catch (ArgumentException ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});
app.Run();
