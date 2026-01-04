# Calculate the next backoff delay in milliseconds with optional jitter.
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
