import ballerina/http;
import ballerina/test;

@test:Config {}
function testCalculateDelayWithoutJitterCapsAtMax() {
	RetryConfig config = {
		maxAttempts: 4,
		initialDelayMillis: 100,
		backoffMultiplier: 3.0,
		maxDelayMillis: 500,
		jitter: false
	};

	int attempt1 = calculateDelayMillis(config, 1);
	int attempt2 = calculateDelayMillis(config, 2);
	int attempt3 = calculateDelayMillis(config, 3);

	test:assertEquals(attempt1, 100);
	test:assertEquals(attempt2, 300);
	test:assertEquals(attempt3, 500, msg = "Delay should cap at maxDelayMillis");
}

@test:Config {}
function testCalculateDelayWithDeterministicJitter() {
	RetryConfig config = {
		maxAttempts: 5,
		initialDelayMillis: 100,
		backoffMultiplier: 2.0,
		maxDelayMillis: 800,
		jitter: true
	};

	int delay = calculateDelayMillis(config, 3);
	test:assertEquals(delay, 393);
}

@test:Config {}
function testIsRetryableStatus() {
	test:assertTrue(isRetryableStatus(500));
	test:assertTrue(isRetryableStatus(http:STATUS_TOO_MANY_REQUESTS));
	test:assertFalse(isRetryableStatus(499));
}

@test:Config {}
function testIsIdempotentMethod() {
	test:assertTrue(isIdempotentMethod("get"));
	test:assertTrue(isIdempotentMethod("DELETE"));
	test:assertFalse(isIdempotentMethod("post"));
}

@test:Config {}
function testToSecondsConversion() {
	test:assertEquals(toSeconds(1500), <decimal>1.5);
	test:assertEquals(toSeconds(0), <decimal>0.0);
	test:assertEquals(toSeconds(-10), <decimal>0.0);
}

@test:Config {}
function testCircuitBreakerTransitions() {
	CircuitBreakerConfig config = { failureThreshold: 2, successThreshold: 1, openTimeoutMillis: 50 };
	CircuitBreaker breaker = new (config, ());

	test:assertTrue(breaker.isCallPermitted(0));
	breaker.recordFailure(0);
	breaker.recordFailure(10);
	test:assertFalse(breaker.isCallPermitted(20));

	test:assertTrue(breaker.isCallPermitted(70));
	breaker.recordSuccess();
	test:assertTrue(breaker.isCallPermitted(80));
}

@test:Config {}
function testCircuitBreakerHalfOpenFailureReopens() {
	CircuitBreakerConfig config = { failureThreshold: 1, successThreshold: 1, openTimeoutMillis: 10 };
	CircuitBreaker breaker = new (config, ());

	breaker.recordFailure(0);
	test:assertFalse(breaker.isCallPermitted(5));

	test:assertTrue(breaker.isCallPermitted(15));
	breaker.recordFailure(15);
	test:assertFalse(breaker.isCallPermitted(20));
}

@test:Config {}
function testExecuteWithRetryRetriesOnFailures() {
	RetryConfig retryConfig = {
		maxAttempts: 3,
		initialDelayMillis: 0,
		backoffMultiplier: 1.0,
		maxDelayMillis: 0,
		jitter: false
	};
	CircuitBreaker breaker = new ({ failureThreshold: 5, successThreshold: 1, openTimeoutMillis: 1000 }, ());

	int attempts = 0;
	function () returns http:Response|error op = function () returns http:Response|error {
		attempts += 1;
		if attempts < 3 {
			return error("synthetic failure");
		}
		http:Response res = new;
		res.statusCode = 200;
		return res;
	};

	http:Response|error result = executeWithRetry(op, retryConfig, breaker, (), "GET", 500);
	test:assertTrue(result is http:Response, msg = "Should succeed on final attempt");
	test:assertEquals(attempts, 3);
}

@test:Config {}
function testExecuteWithRetryMaxRetriesExceeded() {
	RetryConfig retryConfig = {
		maxAttempts: 2,
		initialDelayMillis: 0,
		backoffMultiplier: 1.0,
		maxDelayMillis: 0,
		jitter: false
	};
	CircuitBreaker breaker = new ({ failureThreshold: 5, successThreshold: 1, openTimeoutMillis: 1000 }, ());

	int attempts = 0;
	function () returns http:Response|error op = function () returns http:Response|error {
		attempts += 1;
		return error("always fail");
	};

	http:Response|error result = executeWithRetry(op, retryConfig, breaker, (), "GET", 500);
	test:assertTrue(result is MaxRetriesExceededError);
	test:assertEquals(attempts, 2);
}

@test:Config {}
function testExecuteWithRetryRespectsNonIdempotentDefault() {
	RetryConfig retryConfig = {
		maxAttempts: 4,
		initialDelayMillis: 0,
		backoffMultiplier: 1.0,
		maxDelayMillis: 0,
		jitter: false,
		allowRetryOnNonIdempotent: false
	};
	CircuitBreaker breaker = new ({ failureThreshold: 5, successThreshold: 1, openTimeoutMillis: 1000 }, ());

	int attempts = 0;
	function () returns http:Response|error op = function () returns http:Response|error {
		attempts += 1;
		return error("non-idempotent failure");
	};

	http:Response|error result = executeWithRetry(op, retryConfig, breaker, (), "POST", 500);
	test:assertEquals(attempts, 1, msg = "POST should not retry by default");
}
