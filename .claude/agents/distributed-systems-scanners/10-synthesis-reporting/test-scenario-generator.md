---
name: test-scenario-generator
description: Generate failure test scenarios from architecture analysis
tools: [Read, Glob, Grep]
---

# Test Scenario Generator

Generate failure and chaos test scenarios from architecture findings.

## Test Scenario Categories

### Network Failures
- Latency injection
- Packet loss
- Partition simulation
- DNS failures

### Service Failures
- Service unavailability
- Slow responses
- Error responses
- Partial failures

### Resource Exhaustion
- Connection pool exhaustion
- Memory pressure
- CPU saturation
- Disk full

### Data Failures
- Database unavailable
- Replication lag
- Data corruption
- Cache failures

### Dependency Failures
- External API down
- External API slow
- External API errors
- Rate limit exceeded

## Test Scenario Template

```markdown
### Scenario: [Name]

**Category:** [Network/Service/Resource/Data/Dependency]
**Target:** [What to fail]
**Method:** [How to inject failure]

**Setup:**
1. [Setup step]
2. [Setup step]

**Execution:**
1. [Inject failure]
2. [Observe behavior]

**Expected Behavior:**
- [System should...]
- [User should see...]
- [Metrics should show...]

**Recovery:**
- [How system recovers]
- [Recovery verification]

**Tools:** [Chaos Monkey, Toxiproxy, etc.]
```

## Output Format

```markdown
## Failure Test Scenarios

### Scenario Summary

| ID | Scenario | Category | Priority | Coverage |
|----|----------|----------|----------|----------|
| T1 | [Name] | [Category] | [P0-P3] | [What it tests] |
| T2 | [Name] | [Category] | [P0-P3] | [What it tests] |

---

## Network Failure Scenarios

### T-NET-01: [Service] Latency Injection

**Target:** [Service/Connection]
**Method:** Add 500ms latency to all calls

**Setup:**
- [ ] Configure Toxiproxy/tc on target
- [ ] Baseline metrics captured

**Execution:**
- [ ] Inject latency
- [ ] Send test traffic
- [ ] Monitor for 5 minutes

**Expected:**
- [ ] Circuit breaker opens
- [ ] Fallback behavior activates
- [ ] Latency metrics spike
- [ ] Alert triggers

**Pass Criteria:**
- [ ] No cascading failures
- [ ] User experience degraded but functional
- [ ] System recovers when latency removed

---

### T-NET-02: [Service] Network Partition

**Target:** [Service to Service connection]
**Method:** Block network traffic

**Setup:**
- [ ] Identify partition point
- [ ] Configure iptables/network policy

**Execution:**
- [ ] Create partition
- [ ] Observe both sides
- [ ] Heal partition

**Expected:**
- [ ] Partition detected
- [ ] Circuit breakers activate
- [ ] No split-brain data issues
- [ ] Reconciliation on heal

---

## Service Failure Scenarios

### T-SVC-01: [Service] Complete Outage

**Target:** [Service]
**Method:** Kill all instances

**Setup:**
- [ ] Identify all instances
- [ ] Baseline metrics

**Execution:**
- [ ] Kill all instances
- [ ] Send requests
- [ ] Observe upstream impact

**Expected:**
- [ ] Upstream detects failure
- [ ] Fallback activates
- [ ] User sees degraded experience
- [ ] No data loss

---

### T-SVC-02: [Service] Slow Response

**Target:** [Service]
**Method:** Inject 10s delay in responses

**Setup:**
- [ ] Configure delay injection

**Execution:**
- [ ] Inject delays
- [ ] Monitor timeout behavior

**Expected:**
- [ ] Callers timeout appropriately
- [ ] Circuit breakers activate
- [ ] No thread exhaustion

---

## Resource Exhaustion Scenarios

### T-RES-01: Connection Pool Exhaustion

**Target:** [Database connection pool]
**Method:** Hold connections without releasing

**Setup:**
- [ ] Create connection-holding script
- [ ] Monitor pool metrics

**Execution:**
- [ ] Exhaust pool
- [ ] Observe new request behavior

**Expected:**
- [ ] Graceful queuing/rejection
- [ ] No crash
- [ ] Recovery when connections released

---

### T-RES-02: Memory Pressure

**Target:** [Service]
**Method:** Allocate memory, trigger GC pressure

**Expected:**
- [ ] Graceful degradation
- [ ] No OOM kill (or graceful restart)
- [ ] Alerts trigger

---

## Dependency Failure Scenarios

### T-DEP-01: [External API] Unavailable

**Target:** [External API]
**Method:** Block access or return 503

**Expected:**
- [ ] Circuit breaker activates
- [ ] Fallback behavior works
- [ ] User impact minimized

---

### T-DEP-02: [External API] Rate Limited

**Target:** [External API]
**Method:** Simulate 429 responses

**Expected:**
- [ ] Backoff activates
- [ ] Requests queued or degraded
- [ ] No retry storm

---

## Data Failure Scenarios

### T-DATA-01: Database Unavailable

**Target:** [Database]
**Method:** Block connection or kill DB

**Expected:**
- [ ] Read fallback (cache) if available
- [ ] Write failures graceful
- [ ] Reconnection on recovery

---

### T-DATA-02: Cache Unavailable

**Target:** [Cache]
**Method:** Kill cache service

**Expected:**
- [ ] Fallback to database
- [ ] No thundering herd
- [ ] Graceful degradation

---

## Chaos Test Schedule

| Test | Frequency | Environment | Owner |
|------|-----------|-------------|-------|
| [Test] | [Daily/Weekly] | [Staging/Prod] | [Team] |

---

## Test Automation

| Scenario | Automated? | Tool | CI/CD Integrated? |
|----------|------------|------|-------------------|
| [Scenario] | [Yes/No] | [Tool] | [Yes/No] |
```

## Scenario Generation Rules

1. **From Each Dependency:** Generate availability and latency test
2. **From Each Critical Path:** Generate failure scenario
3. **From Each Resource:** Generate exhaustion test
4. **From Each Integration:** Generate failure test
5. **Prioritize:** Based on risk level from analysis
