import ballerina/http;
import ballerina/time;

## Returns the current monotonic time in milliseconds.
# Used for circuit breaker timing and delay calculations.
# + return - The current monotonic time in milliseconds.
public function currentTimeMillis() returns int {
    decimal seconds = time:monotonicNow();
    return <int>(seconds * 1000);
}

## Determines if an HTTP response status code is considered retryable.
# Retryable statuses include 5xx and 429 (Too Many Requests).
# + statusCode - The HTTP response status code to evaluate.
# + return - True if the status code is retryable, else false.
public function isRetryableStatus(int statusCode) returns boolean {
    if statusCode >= 500 {
        return true;
    }
    return statusCode == http:STATUS_TOO_MANY_REQUESTS;
}

## Checks if an HTTP method is idempotent for retry purposes.
# Idempotent methods are safe to retry (e.g., GET, PUT, DELETE).
# + method - The HTTP method name to check.
# + return - True if the method is idempotent, else false.
public function isIdempotentMethod(string method) returns boolean {
    string upper = method.toUpperAscii();
    return upper == "GET" || upper == "HEAD" || upper == "PUT" || upper == "DELETE" || upper == "OPTIONS";
}

## Converts a timeout in milliseconds to decimal seconds for HTTP client configuration.
# Useful for configuring Ballerina http:Client timeouts.
# + millis - The timeout value in milliseconds.
# + return - The timeout value as decimal seconds.
public function toSeconds(int millis) returns decimal {
    if millis <= 0 {
        return 0.0;
    }
    return <decimal>millis / 1000.0;
}
