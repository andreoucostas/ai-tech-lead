using System.Text.Json;

namespace Synthetic.Intake;

public static class RetryPolicy
{
    public static bool CanRetry(int attempt)
    {
        var json = File.ReadAllText(Path.Combine("config", "retry.json"));
        var maxAttempts = JsonDocument.Parse(json).RootElement.GetProperty("maxAttempts").GetInt32();
        return RetryBoundary.Allows(attempt, maxAttempts);
    }
}

internal static class RetryBoundary
{
    internal static bool Allows(int attempt, int maxAttempts) => attempt < maxAttempts;
}
