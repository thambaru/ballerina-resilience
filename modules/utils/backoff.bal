# # Calculates the next backoff delay in milliseconds, applying optional jitter if enabled.
# Used for retry strategies to determine wait time before the next attempt.
# + config - The retry configuration parameters.
# + attempt - The current retry attempt number (1-based).
# + return - The computed delay in milliseconds for the next retry.
public function calculateDelayMillis(RetryConfig config, int attempt) returns int {
    if attempt <= 1 {
        return config.initialDelayMillis;
    }

    float delay = <float>config.initialDelayMillis;
    int i = 1;
    while i < attempt {
        delay = delay * config.backoffMultiplier;
        i += 1;
    }

    int rawDelay = <int>delay;
    int cappedDelay = rawDelay > config.maxDelayMillis ? config.maxDelayMillis : rawDelay;

    if !config.jitter {
        return cappedDelay;
    }

    return applyDeterministicJitter(cappedDelay, attempt);
}

# # Applies deterministic jitter to a base delay value for retry backoff.
# Jitter helps to avoid thundering herd problems by randomizing retry delays.
# + baseDelay - The base delay in milliseconds before jitter.
# + salt - A value (typically the attempt number) to vary the jitter per attempt.
# + return - The jittered delay in milliseconds (always positive).
function applyDeterministicJitter(int baseDelay, int salt) returns int {
    if baseDelay <= 1 {
        return baseDelay;
    }
    int spread = baseDelay / 2;
    int pseudo = (salt * 1103515245 + 12345) & 0x7fffffff;
    int offset = pseudo % (spread + 1);
    int jittered = baseDelay - spread + offset;
    return jittered > 0 ? jittered : 1;
}
