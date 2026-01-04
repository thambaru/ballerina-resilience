public type ResilienceError distinct error;
public type CircuitOpenError distinct ResilienceError;
public type MaxRetriesExceededError distinct ResilienceError;
public type ClientInitError distinct ResilienceError;

public function circuitOpenError() returns CircuitOpenError {
    return error("Circuit is open");
}

public function maxRetriesExceededError(int attempts) returns MaxRetriesExceededError {
    return error(string `Max retry attempts exceeded after ${attempts} attempts`);
}

public function clientInitError(error cause) returns ClientInitError {
    return error(string `Failed to create HTTP client: ${cause.message()}`);
}