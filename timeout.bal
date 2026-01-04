# Convert TimeoutConfig to decimal seconds for http client configuration.
public function timeoutSeconds(TimeoutConfig config) returns decimal {
    return toSeconds(config.requestTimeoutMillis);
}
