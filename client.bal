import ballerina/http;

# # Creates a resilient HTTP client that wraps ballerina/http:Client.
# Adds automatic retries, circuit breaker, and timeout-aware configuration.
# + baseUrl - The base URL for the HTTP client.
# + config - The resilience configuration to apply.
# + return - A ResilientClient instance or a ResilienceError on failure.
public function newResilientClient(string baseUrl, ResilienceConfig config) returns ResilientClient|ResilienceError {
    CircuitBreaker circuitBreaker = new (config.circuitBreaker, config.'listener);

    http:ClientConfiguration clientConfig = {
        timeout: timeoutSeconds(config.timeout)
    };

    http:Client|error httpClientOrError = new (baseUrl, clientConfig);
    if httpClientOrError is error {
        return clientInitError(httpClientOrError);
    }

    ResilientClientImpl impl = new (httpClientOrError, config.'retry, config.timeout, circuitBreaker, config.'listener);
    ResilientClient resilientClient = impl;
    return resilientClient;
}

# # Private implementation backing the exported ResilientClient type.
# Not intended for direct use.
public class ResilientClientImpl {
    private http:Client httpClient;
    private readonly & RetryConfig retryConfig;
    private readonly & TimeoutConfig timeoutConfig;
    private CircuitBreaker circuitBreaker;
    private ResilienceListener? resilienceListener;

    public function init(http:Client httpClient, RetryConfig retryConfig, TimeoutConfig timeoutConfig,
            CircuitBreaker circuitBreaker, ResilienceListener? resilienceListener) {
        self.httpClient = httpClient;
        self.retryConfig = <readonly & RetryConfig>retryConfig.cloneReadOnly();
        self.timeoutConfig = <readonly & TimeoutConfig>timeoutConfig.cloneReadOnly();
        self.circuitBreaker = circuitBreaker;
        self.resilienceListener = resilienceListener;
    }

    # # Issues a GET request to the given path with optional headers.
    # + path - The request path (relative to base URL).
    # + headers - Optional HTTP headers.
    # + return - The HTTP response or error.
    public function get(string path, map<string|string>? headers = ()) returns http:Response|error {
        return self.execute("GET", path, (), headers);
    }

    # # Issues a POST request to the given path with a payload and optional headers.
    # + path - The request path (relative to base URL).
    # + payload - The request body to send.
    # + headers - Optional HTTP headers.
    # + return - The HTTP response or error.
    public function post(string path, anydata payload, map<string|string>? headers = ()) returns http:Response|error {
        return self.execute("POST", path, payload, headers);
    }

    # # Executes an HTTP request with resilience features (retry, circuit breaker, timeout).
    # + method - The HTTP method (e.g., GET, POST).
    # + path - The request path.
    # + payload - The request body (if any).
    # + headers - Optional HTTP headers.
    # + return - The HTTP response or error.
    private function execute(string method, string path, anydata payload, map<string|string>? headers)
            returns http:Response|error {
        function () returns http:Response|error op = function() returns http:Response|error {
            return self.performCall(method, path, payload, headers);
        };

        return executeWithRetry(op, self.retryConfig, self.circuitBreaker, self.resilienceListener, method,
                self.timeoutConfig.requestTimeoutMillis);
    }

    # # Performs the actual HTTP call using the underlying http:Client.
    # Only GET and POST are supported.
    # + method - The HTTP method.
    # + path - The request path.
    # + payload - The request body (if any).
    # + headers - Optional HTTP headers.
    # + return - The HTTP response or error.
    private function performCall(string method, string path, anydata payload, map<string|string>? headers)
            returns http:Response|error {
        string upperMethod = method.toUpperAscii();
        if upperMethod == "GET" {
            return self.httpClient->get(path, headers = headers);
        }

        if upperMethod == "POST" {
            return self.httpClient->post(path, payload, headers = headers);
        }

        return error(string `Unsupported method ${method}`);
    }
}
