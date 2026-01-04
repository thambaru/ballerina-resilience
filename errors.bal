# Resilience error hierarchy

public type ResilienceError distinct error;

public type CircuitOpenError distinct ResilienceError;

public type MaxRetriesExceededError distinct ResilienceError;

public type RequestTimeoutError distinct ResilienceError;

public type ClientInitError distinct ResilienceError;

public function circuitOpenError() returns CircuitOpenError {
    return error("Circuit is open");
}

public function maxRetriesExceededError(int attempts) returns MaxRetriesExceededError {
    return error(string `Max retry attempts exceeded after ${attempts} attempts`);
}

public function requestTimedOutError(int timeoutMillis) returns RequestTimeoutError {
    return error(string `Request timed out after ${timeoutMillis} ms`);
}

public function clientInitError(error cause) returns ClientInitError {
    return error(string `Failed to create HTTP client: ${cause.message()}`);
}
