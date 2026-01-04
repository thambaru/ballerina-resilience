import ballerina/http;

# # Timeout configuration (per-request) in milliseconds.
# Sets the maximum duration for each HTTP request.
# + requestTimeoutMillis - Timeout for each request (ms).
public type TimeoutConfig record {
    int requestTimeoutMillis = 5000;
};

# # Retry configuration applied to idempotent calls by default.
# Controls retry attempts, backoff, and jitter.
# + maxAttempts - Maximum number of retry attempts.
# + initialDelayMillis - Initial delay before first retry (ms).
# + backoffMultiplier - Multiplier for exponential backoff.
# + maxDelayMillis - Maximum delay between retries (ms).
# + jitter - Whether to apply jitter to delays.
# + allowRetryOnNonIdempotent - Allow retries on non-idempotent methods.
public type RetryConfig record {
    int maxAttempts = 3;
    int initialDelayMillis = 200;
    float backoffMultiplier = 2.0;
    int maxDelayMillis = 2000;
    boolean jitter = true;
    boolean allowRetryOnNonIdempotent = false;
};

# # Optional hooks to observe resilience lifecycle events.
# Implement to receive notifications on retry and circuit breaker state changes.
# All methods are optional and must not block or panic.
public type ResilienceListener isolated object {
    isolated function onRetry(int attempt);
    isolated function onCircuitOpen();
    isolated function onCircuitHalfOpen();
    isolated function onCircuitClose();
};

# # Circuit breaker configuration controlling failure thresholds and recovery.
# Determines when the circuit opens, closes, and recovers.
# + failureThreshold - Number of failures to open the circuit.
# + successThreshold - Number of successes to close the circuit from half-open.
# + openTimeoutMillis - Time to wait before transitioning from open to half-open (ms).
public type CircuitBreakerConfig record {
    int failureThreshold = 5;
    int successThreshold = 2;
    int openTimeoutMillis = 10000;
};

# # Aggregate resilience configuration for a resilient HTTP client.
# Bundles retry, circuit breaker, timeout, and optional listener.
# + 'retry - Retry configuration.
# + circuitBreaker - Circuit breaker configuration.
# + timeout - Timeout configuration.
# + 'listener - Optional resilience event listener.
public type ResilienceConfig record {
    RetryConfig 'retry = {};
    CircuitBreakerConfig circuitBreaker = {};
    TimeoutConfig timeout = {};
    ResilienceListener? 'listener = ();
};

# # Public resilient HTTP client API mirroring http:Client verbs.
# Provides GET and POST methods with resilience features.
public type ResilientClient object {
    public function get(string path, map<string|string>? headers = ()) returns http:Response|error;
    public function post(string path, anydata payload, map<string|string>? headers = ()) returns http:Response|error;
};