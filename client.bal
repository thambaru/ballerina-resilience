import ballerina/http;

# Create a resilient HTTP client that wraps ballerina/http:Client with retries,
# circuit breaker, and timeout-aware configuration.
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

# Private implementation backing the exported ResilientClient type.
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

    public function get(string path, map<string|string>? headers = ()) returns http:Response|error {
        return self.execute("GET", path, (), headers);
    }

    public function post(string path, anydata payload, map<string|string>? headers = ()) returns http:Response|error {
        return self.execute("POST", path, payload, headers);
    }

    private function execute(string method, string path, anydata payload, map<string|string>? headers)
            returns http:Response|error {
        function () returns http:Response|error op = function () returns http:Response|error {
            return self.performCall(method, path, payload, headers);
        };

        return executeWithRetry(op, self.retryConfig, self.circuitBreaker, self.resilienceListener, method,
            self.timeoutConfig.requestTimeoutMillis);
    }

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
