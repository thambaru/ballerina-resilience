# # Converts TimeoutConfig to decimal seconds for HTTP client configuration.
# Useful for configuring the timeout value in http:Client.
# + config - The timeout configuration record.
# + return - The timeout value as decimal seconds.
public function timeoutSeconds(TimeoutConfig config) returns decimal {
    return toSeconds(config.requestTimeoutMillis);
}
