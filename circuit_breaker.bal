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

    # # Verifies if the next call is permitted by the circuit breaker.
    # Handles time-based transition from OPEN to HALF_OPEN state.
    # + nowMillis - The current monotonic time in milliseconds.
    # + return - True if the call is allowed, else false.
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

    # # Records a successful call and manages state transitions.
    # In HALF_OPEN, increments success count and closes circuit if threshold is met.
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

    # # Records a failed call and opens the circuit if failure threshold is breached.
    # In HALF_OPEN, immediately opens the circuit on any failure.
    # + nowMillis - The current monotonic time in milliseconds.
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

    # # Opens the circuit and records the open time.
    # Notifies listener if present.
    # + nowMillis - The current monotonic time in milliseconds.
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

    # # Closes the circuit and resets counters.
    # Notifies listener if present.
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
