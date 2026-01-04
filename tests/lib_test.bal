import ballerina/http;
import ballerina/test;
import resilience.utils;

listener http:Listener testListener = new (9091);

isolated int flakyCounter = 0;
isolated int postCounter = 0;

service /sim on testListener {
    isolated resource function get flaky() returns http:Response {
        int currentCount;
        lock {
            flakyCounter += 1;
            currentCount = flakyCounter;
        }
        http:Response res = new;
        if currentCount < 3 {
            res.statusCode = 500;
            res.setPayload("temporary failure");
            return res;
        }
        res.statusCode = 200;
        res.setPayload("ok");
        return res;
    }

    resource function get alwaysFail() returns http:Response {
        http:Response res = new;
        res.statusCode = 503;
        res.setPayload("down");
        return res;
    }

    isolated resource function post 'record() returns http:Response {
        lock {
            postCounter += 1;
        }
        http:Response res = new;
        res.statusCode = 500;
        res.setPayload("post failure");
        return res;
    }
}

@test:Config {}
function testRetryCompletesAfterTransientFailures() returns error? {
    utils:ResilienceConfig cfg = {
        'retry: { maxAttempts: 3, initialDelayMillis: 10, maxDelayMillis: 20, jitter: false },
        circuitBreaker: { failureThreshold: 4, successThreshold: 1, openTimeoutMillis: 200 },
        timeout: { requestTimeoutMillis: 2000 }
    };

    utils:ResilientClient resilientClient = check newResilientClient("http://localhost:9091/sim", cfg);
    var result = resilientClient.get("/flaky");
    test:assertTrue(result is http:Response, msg = "Expected http response after retries");
    if result is http:Response {
        test:assertEquals(result.statusCode, 200);
    }
}

@test:Config {}
function testCircuitOpensAndFailsFast() returns error? {
    lock {
        flakyCounter = 0;
    }
    utils:ResilienceConfig cfg = {
        'retry: { maxAttempts: 1 },
        circuitBreaker: { failureThreshold: 1, successThreshold: 1, openTimeoutMillis: 500 },
        timeout: { requestTimeoutMillis: 2000 }
    };

    utils:ResilientClient|utils:ResilienceError clientOrError = newResilientClient("http://localhost:9091/sim", cfg);
    test:assertFalse(clientOrError is utils:ResilienceError, msg = "Client creation failed");
    utils:ResilientClient resilientClient = check clientOrError;

    var first = resilientClient.get("/alwaysFail");
    test:assertTrue(first is http:Response);
    var second = resilientClient.get("/alwaysFail");
    test:assertTrue(second is utils:CircuitOpenError, msg = "Circuit should be open and reject calls");
}

@test:Config {}
function testNonIdempotentDoesNotRetryByDefault() returns error? {
    lock {
        postCounter = 0;
    }
    utils:ResilienceConfig cfg = {
        'retry: { maxAttempts: 3 },
        circuitBreaker: { failureThreshold: 2, successThreshold: 1, openTimeoutMillis: 200 },
        timeout: { requestTimeoutMillis: 1000 }
    };

    utils:ResilientClient resilientClient = check newResilientClient("http://localhost:9091/sim", cfg);
    var resp = resilientClient.post("/record", { name: "demo" });
    int count;
    lock {
        count = postCounter;
    }
    test:assertEquals(count, 1, msg = "POST should not retry by default");
    test:assertTrue(resp is http:Response);
}
