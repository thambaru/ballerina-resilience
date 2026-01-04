# Resilience library for outbound HTTP

`thambaru/resilience` wraps `http:Client` with retries, backoff, circuit breaking, and per-request timeouts so downstream failures do not cascade through your services. Defaults are safe, explicit, and targeted at production microservices.

## Why
- Fail fast when a dependency is unhealthy (circuit breaker)
- Recover from transient network issues (retries with backoff)
- Bound resource usage (request timeouts)
- Keep behavior predictable and isolated per client instance

## Installation

```ballerina
bal add package thambaru/resilience
```

## Quick start

```ballerina
import thambaru/resilience;

public function main() returns error? {
    resilience:ResilienceConfig cfg = {
        retry: { maxAttempts: 3, initialDelayMillis: 200, jitter: true },
        circuitBreaker: { failureThreshold: 5, successThreshold: 2, openTimeoutMillis: 10000 },
        timeout: { requestTimeoutMillis: 3000 }
    };

    resilience:ResilientClient client = check resilience:newResilientClient("https://api.example.com", cfg);
    var result = client.get("/health");
    if result is http:Response {
        io:println(result.statusCode);
    }
}
```

## Configuration
- `retry.maxAttempts` counts the initial attempt; retries apply only to retryable failures and idempotent methods unless `allowRetryOnNonIdempotent` is set.
- `retry.backoffMultiplier`, `initialDelayMillis`, `maxDelayMillis`, and optional jitter shape delay growth.
- `circuitBreaker.failureThreshold` opens the circuit immediately after the threshold is reached; `openTimeoutMillis` controls when a half-open probe is allowed; `successThreshold` closes the circuit after consecutive successes.
- `timeout.requestTimeoutMillis` configures the underlying HTTP client request timeout.
- Optional `ResilienceListener` hooks observe retries and circuit transitions; listeners must return quickly and not panic.

## Safe defaults and warnings
- Retries target network errors and `5xx` (and `429`) responses only.
- Non-idempotent calls (e.g., `POST`) do not retry unless explicitly allowed.
- Circuit breaker state is per client instance; there is no global mutable state.
- Errors are returned as values (`ResilienceError`) and never panicked.

## Testing guidance
- Use deterministic delays (`jitter: false`) in tests.
- Keep `openTimeoutMillis` low in tests to avoid long sleeps.
- Validate concurrent access by creating multiple `ResilientClient` instances; state is isolated per client.
