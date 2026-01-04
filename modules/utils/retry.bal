import ballerina/http;

public function executeWithRetry(function () returns http:Response|error operation,
    RetryConfig retryConfig, CircuitBreaker circuitBreaker, ResilienceListener? resilienceListener,
    string method, int timeoutMillis) returns http:Response|error {
    int attempt = 1;
    int effectiveMaxAttempts = resolveMaxAttempts(method, retryConfig);

    while attempt <= effectiveMaxAttempts {
        int nowMillis = currentTimeMillis();
        if !circuitBreaker.isCallPermitted(nowMillis) {
            return circuitOpenError();
        }

        http:Response|error result = operation();

        if result is http:Response {
            int status = result.statusCode;
            if isRetryableStatus(status) {
                circuitBreaker.recordFailure(currentTimeMillis());
            } else {
                circuitBreaker.recordSuccess();
                return result;
            }
        } else {
            circuitBreaker.recordFailure(currentTimeMillis());
        }

        if attempt >= effectiveMaxAttempts {
            if result is http:Response {
                return result;
            }
            return maxRetriesExceededError(attempt);
        }

        int delayMillis = calculateDelayMillis(retryConfig, attempt);
        if resilienceListener is ResilienceListener {
            resilienceListener.onRetry(attempt);
        }
        if delayMillis > 0 {
            int target = currentTimeMillis() + delayMillis;
            while currentTimeMillis() < target {
            }
        }
        attempt += 1;
    }

    return maxRetriesExceededError(attempt);
}

function resolveMaxAttempts(string method, RetryConfig retryConfig) returns int {
    if isIdempotentMethod(method) {
        return retryConfig.maxAttempts;
    }
    if retryConfig.allowRetryOnNonIdempotent {
        return retryConfig.maxAttempts;
    }
    return 1;
}
