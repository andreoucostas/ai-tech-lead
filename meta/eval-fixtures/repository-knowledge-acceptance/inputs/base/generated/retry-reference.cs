namespace Generated.Reference;

public static class RetryReference
{
    public static bool CanRetry(int attempt, int maxAttempts) => attempt <= maxAttempts;
}

