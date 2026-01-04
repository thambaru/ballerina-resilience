const string CIRCUIT_CLOSED = "CLOSED";
const string CIRCUIT_OPEN = "OPEN";
const string CIRCUIT_HALF_OPEN = "HALF_OPEN";

public isolated class CircuitBreaker {
    private string state = CIRCUIT_CLOSED;
    private int failureCount = 0;
    private int successCount = 0;
    private int lastOpenedAtMillis = 0;
    private boolean halfOpenTrialInProgress = false;
    private readonly & CircuitBreakerConfig config;
    private ResilienceListener? resilienceListener;

    public function init(CircuitBreakerConfig config, ResilienceListener? resilienceListener) {
        self.config = <readonly & CircuitBreakerConfig>config.cloneReadOnly();
        self.resilienceListener = resilienceListener;
    }

    # Verify if the next call is permitted. Handles time-based transition to HALF_OPEN.
    public function isCallPermitted(int nowMillis) returns boolean {
        lock {
            if self.state == CIRCUIT_OPEN {
                int elapsed = nowMillis - self.lastOpenedAtMillis;
                if elapsed >= self.config.openTimeoutMillis {
                    self.state = CIRCUIT_HALF_OPEN;
                    self.successCount = 0;
                    self.failureCount = 0;
                    self.halfOpenTrialInProgress = true;
                    ResilienceListener? listenerLocal = self.resilienceListener;
                    if listenerLocal is ResilienceListener {
                        listenerLocal.onCircuitHalfOpen();
                    }
                    return true;
                }
                return false;
            }

            if self.state == CIRCUIT_HALF_OPEN {
                if self.halfOpenTrialInProgress {
                    return false;
                }
                self.halfOpenTrialInProgress = true;
                return true;
            }

            return true;
        }
    }

    # Record a successful call and handle state transitions.
    public function recordSuccess() {
        lock {
            if self.state == CIRCUIT_HALF_OPEN {
                self.successCount += 1;
                self.halfOpenTrialInProgress = false;
                if self.successCount >= self.config.successThreshold {
                    self.closeCircuit();
                }
                return;
            }

            self.failureCount = 0;
        }
    }

    # Record a failure and open the circuit immediately after threshold breach.
    public function recordFailure(int nowMillis) {
        lock {
            if self.state == CIRCUIT_HALF_OPEN {
                self.openCircuit(nowMillis);
                return;
            }

            self.failureCount += 1;
            if self.failureCount >= self.config.failureThreshold {
                self.openCircuit(nowMillis);
            }
        }
    }

    private isolated function openCircuit(int nowMillis) {
        lock {
            self.state = CIRCUIT_OPEN;
            self.lastOpenedAtMillis = nowMillis;
            self.successCount = 0;
            self.halfOpenTrialInProgress = false;
            ResilienceListener? listenerLocal = self.resilienceListener;
            if listenerLocal is ResilienceListener {
                listenerLocal.onCircuitOpen();
            }
        }
    }

    private isolated function closeCircuit() {
        lock {
            self.state = CIRCUIT_CLOSED;
            self.failureCount = 0;
            self.successCount = 0;
            self.halfOpenTrialInProgress = false;
            ResilienceListener? listenerLocal = self.resilienceListener;
            if listenerLocal is ResilienceListener {
                listenerLocal.onCircuitClose();
            }
        }
    }
}
