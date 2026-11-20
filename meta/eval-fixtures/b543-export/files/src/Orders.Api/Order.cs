namespace Orders.Api;

public record Order(int Id, string Customer, DateOnly PlacedOn, decimal Total, OrderStatus Status);
