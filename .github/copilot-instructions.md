## Project Overview

This repository contains a **Ballerina resilience library** that provides:

* **Automatic retries**
* **Backoff strategies**
* **Circuit breaker protection**
* **Timeout orchestration**

The library is designed to wrap or enhance **outbound HTTP calls** in Ballerina services and clients.

This package is intended for **microservices and API integrations** running in production.

---

## Package Identity

* **Organization:** `thambaru`
* **Package name:** `resilience`
* **Module path:** `thambaru/resilience`
* **Recommended import alias:** `resilience`

Example:

```ballerina
import thambaru/resilience;
```

---

## Core Goals

When generating or modifying code, ensure the library:

1. Prevents cascading failures
2. Handles transient network errors gracefully
3. Fails fast when downstream services are unhealthy
4. Is safe under concurrency
5. Requires minimal configuration to get started
6. Integrates cleanly with `http:Client`

---

## Design Principles

Always prioritize:

* **Explicit configuration**
* **Predictable behavior**
* **Fail-fast defaults**
* **Isolation between services**
* **Low overhead**

Avoid:

* Global mutable state
* Hidden retries
* Silent error swallowing
* Magic defaults without documentation

---

## Supported Resilience Features (v1)

### Retry

* Fixed delay
* Exponential backoff
* Optional jitter
* Max retry attempts

### Circuit Breaker

* Closed → Open → Half-Open states
* Failure thresholds
* Recovery timeout
* Success threshold to close

### Timeout

* Per-request timeout
* Global fallback timeout

---

## Public API Design

### Resilient HTTP Client

The primary API must wrap `http:Client`:

```ballerina
public function newResilientClient(
    string baseUrl,
    ResilienceConfig config
) returns ResilientClient|ResilienceError;
```

---

### ResilientClient Object

```ballerina
public type ResilientClient isolated object {

    public function get(string path, map<string|string>? headers = ())
        returns http:Response|error;

    public function post(string path, anydata payload, map<string|string>? headers = ())
        returns http:Response|error;

    // Additional HTTP verbs may be added later
};
```

Rules:

* Method signatures must resemble `http:Client`
* Do not invent new abstractions for HTTP
* Errors must be returned, not panicked

---

## Configuration Model

### ResilienceConfig

```ballerina
public type ResilienceConfig record {
    RetryConfig retry = {};
    CircuitBreakerConfig circuitBreaker = {};
    TimeoutConfig timeout = {};
};
```

---

### RetryConfig

```ballerina
public type RetryConfig record {
    int maxAttempts = 3;
    int initialDelayMillis = 200;
    float backoffMultiplier = 2.0;
    int maxDelayMillis = 2000;
    boolean jitter = true;
};
```

Rules:

* Retries apply only to retryable failures
* Non-idempotent methods must not retry by default

---

### CircuitBreakerConfig

```ballerina
public type CircuitBreakerConfig record {
    int failureThreshold = 5;
    int successThreshold = 2;
    int openTimeoutMillis = 10000;
};
```

Rules:

* Circuit breaker state must be per-client
* State transitions must be thread-safe
* Circuit must open immediately after threshold breach

---

### TimeoutConfig

```ballerina
public type TimeoutConfig record {
    int requestTimeoutMillis = 5000;
};
```

---

## Circuit Breaker Rules

### States

* **Closed** → Normal operation
* **Open** → Requests fail fast
* **Half-Open** → Limited trial requests

State transitions must be:

* Deterministic
* Time-based
* Safe under concurrency

---

## Retry Rules

Retries MUST occur only when:

* Network errors occur
* HTTP status codes are retryable (e.g. 5xx)

Retries MUST NOT occur when:

* Circuit is open
* Client-side validation errors occur (4xx except 429)
* Timeout is exceeded

---

## Error Handling

### ResilienceError

All library-specific errors must use:

```ballerina
public type ResilienceError distinct error;
```

Examples:

* `CircuitOpenError`
* `MaxRetriesExceeded`
* `RequestTimeout`

Error messages must be:

* Clear
* Actionable
* Non-leaky (no internal stack traces)

---

## Internal Architecture Guidelines

Recommended structure:

```
resilience/
 ├── client.bal           // Public ResilientClient
 ├── retry.bal            // Retry logic
 ├── backoff.bal          // Delay strategies
 ├── circuit_breaker.bal  // Circuit state machine
 ├── timeout.bal          // Timeout handling
 ├── errors.bal
 ├── types.bal
 └── utils.bal
```

Each module must:

* Have a single responsibility
* Be independently testable

---

## Concurrency & Safety

* All stateful components must be `isolated`
* Use atomic or synchronized access where needed
* No shared global state between clients
* Circuit state must not leak across base URLs

---

## Observability Hooks (Optional)

Provide optional hooks (not required by default):

```ballerina
public type ResilienceListener object {
    function onRetry(int attempt);
    function onCircuitOpen();
    function onCircuitHalfOpen();
    function onCircuitClose();
};
```

Hooks must:

* Never block request execution
* Never panic
* Be optional

---

## Testing Expectations

Tests must cover:

* Retry attempts and delays
* Circuit breaker opening and closing
* Half-open recovery behavior
* Timeout enforcement
* Concurrent request safety
* Non-retryable failures

Use deterministic clocks and controlled delays.

---

## Documentation Expectations

README MUST include:

* What problem this library solves
* Retry vs circuit breaker explanation
* Basic usage examples
* Safe defaults explanation
* Warnings about retries on non-idempotent requests

All public APIs must have doc comments.

---

## Style Guidelines

* Follow official Ballerina formatting
* Prefer explicit types
* Avoid overly generic maps
* Keep functions small
* Use descriptive names

---

## Out of Scope (Unless Explicitly Requested)

Do NOT generate:

* Service mesh logic
* Inbound request filters
* Rate limiting
* Bulkheads
* Custom schedulers
* Framework-specific middleware

---

## Compatibility Requirements

* Must work with the latest stable Ballerina version
* Must use stable standard library APIs only
* Avoid experimental features

---

## Success Criteria

Code generated for this repository should:

* Be safe for production use
* Reduce API failure blast radius
* Integrate naturally with `http:Client`
* Be easy to configure and reason about
* Be publishable on Ballerina Central

---

## Final Reminder

This is **resilience infrastructure**.

Favor:

* Safety
* Predictability
* Transparency

Over:

* Cleverness
* Overengineering
* Implicit behavior