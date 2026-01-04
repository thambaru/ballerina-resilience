import ballerina/http;

# Retry configuration applied to idempotent calls by default.
public type RetryConfig record {
    int maxAttempts = 3;
    int initialDelayMillis = 200;
    float backoffMultiplier = 2.0;
    int maxDelayMillis = 2000;
    boolean jitter = true;
    boolean allowRetryOnNonIdempotent = false;
};

# Circuit breaker configuration controlling failure thresholds and recovery.
public type CircuitBreakerConfig record {
    int failureThreshold = 5;
    int successThreshold = 2;
    int openTimeoutMillis = 10000;
};

# Timeout configuration (per-request) in milliseconds.
public type TimeoutConfig record {
    int requestTimeoutMillis = 5000;
};

# Aggregate resilience configuration.
public type ResilienceConfig record {
    RetryConfig 'retry = {};
    CircuitBreakerConfig circuitBreaker = {};
    TimeoutConfig timeout = {};
    ResilienceListener? 'listener = ();
};

# Optional hooks to observe resilience lifecycle events.
public type ResilienceListener isolated object {
    isolated function onRetry(int attempt);
    isolated function onCircuitOpen();
    isolated function onCircuitHalfOpen();
    isolated function onCircuitClose();
};

# Public resilient HTTP client API mirroring http:Client verbs.
public type ResilientClient object {
    public function get(string path, map<string|string>? headers = ()) returns http:Response|error;
    public function post(string path, anydata payload, map<string|string>? headers = ()) returns http:Response|error;
};
