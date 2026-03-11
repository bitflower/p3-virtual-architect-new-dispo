# User Guide: Holistic Tour Calculation Tracing

**Version:** V1 Minimal Implementation
**Date:** 2026-03-10
**Audience:** Developers, DevOps, Support Engineers

---

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Understanding Traces](#understanding-traces)
4. [Querying Traces](#querying-traces)
5. [Common Scenarios](#common-scenarios)
6. [Troubleshooting](#troubleshooting)
7. [Best Practices](#best-practices)
8. [Reference](#reference)

---

## Overview

### What is Tour Calculation Tracing?

The holistic tour calculation tracing system captures detailed information about every tour calculation request as it flows through the system:

```
Frontend → Backend → TMS Bridge → Backend → Frontend
```

Each request is assigned a **Trace ID** (UUID) that follows it through all components, allowing you to:
- Debug tour calculation issues
- Analyze performance bottlenecks
- Understand data transformations
- Track errors across services

### Key Benefits

1. **End-to-End Visibility**: See the complete journey of a request
2. **Performance Analysis**: Measure time spent in each stage
3. **Debug Production Issues**: Trace specific requests in production
4. **Data Inspection**: View PoolDTO before and after TOP Service
5. **Error Tracking**: Understand where and why failures occur

---

## Quick Start

### 1. Trigger a Tour Calculation

1. Open your browser and navigate to a transport order
2. Open **Developer Tools** (F12) → **Console** tab
3. Click **"Calculate Routes"** button
4. Look for the trace ID in console:

```
[TraceIdService] Generated new trace ID: 550e8400-e29b-41d4-a716-446655440000
[CalculateRoutesService] Starting tour calculation for order 12345 with trace ID: 550e8400-...
```

### 2. Find Trace in Backend Logs

```bash
# Search backend logs for your trace ID
grep "550e8400-e29b-41d4-a716-446655440000" /var/log/backend.json

# Or use CloudWatch Insights
fields @timestamp, @message, TraceId, CapturePointId, Component, Label
| filter TraceId = "550e8400-e29b-41d4-a716-446655440000"
| sort @timestamp asc
```

### 3. Analyze the Trace

Look for all capture points in order:
- **CP-FE-1**: Request started
- **CP-BE-1** through **CP-BE-8**: Backend processing
- **CP-TB-1**, **CP-TB-2**: TMS Bridge operations
- **CP-FE-2**: Response received

---

## Understanding Traces

### Trace Lifecycle

```
1. Frontend generates UUID v4 trace ID
2. Frontend adds X-Trace-Id header to HTTP request
3. Backend extracts trace ID from header
4. Backend propagates trace ID to TMS Bridge (GraphQL header)
5. TMS Bridge extracts trace ID from GraphQL header
6. All components log captures with the same trace ID
7. Frontend marks trace as complete
```

### Capture Points

A **capture point** represents a specific moment in the request flow where data is recorded.

#### Frontend Capture Points (2)

| ID | Location | Description |
|----|----------|-------------|
| CP-FE-1 | Request initiation | User clicks "Calculate Routes" |
| CP-FE-2 | Response received | Success or error response |

#### Backend Capture Points (8)

| ID | Location | Description | Critical |
|----|----------|-------------|----------|
| CP-BE-1 | Controller entry | Request enters backend | |
| CP-BE-2 | Before GetPoolDto | About to call TMS Bridge | |
| CP-BE-3 | After GetPoolDto | **PoolDTO received from TMS** | 🔥 |
| CP-BE-4 | Before TOP Service | About to optimize routes | |
| CP-BE-5 | After TOP Service | **Optimized PoolDTO** | 🔥 |
| CP-BE-6 | Before SetPoolDto | About to save to TMS | |
| CP-BE-7 | After SetPoolDto | Save confirmed | |
| CP-BE-8 | Controller exit | Response sent to frontend | |

#### TMS Bridge Capture Points (4)

| ID | Location | Description |
|----|----------|-------------|
| CP-TB-1 | GetXserverDto entry | GraphQL query received |
| CP-TB-1-Complete | GetXserverDto exit | Query completed |
| CP-TB-2 | SetXserverDto entry | GraphQL mutation received |
| CP-TB-2-Complete/Error | SetXserverDto exit | Mutation completed or failed |

### Data Captured

Each capture point records:
- **Trace ID**: Unique identifier
- **Timestamp**: When capture occurred
- **Component**: Frontend, Backend, or TMS-Bridge
- **Label**: Human-readable description
- **Data**: Context-specific information (request params, DTOs, etc.)
- **Duration**: Time elapsed (for completion points)
- **Error**: Error details (if applicable)

---

## Querying Traces

### Using Browser DevTools (Frontend)

**Filter Console Logs:**
```
Filter: [TraceCaptureService]
```

**Find Specific Trace:**
```javascript
// In console, filter by trace ID
// Look for: {"traceId":"550e8400-e29b-41d4-a716-446655440000",...}
```

### Using Backend Logs (Serilog JSON)

**All captures for a trace:**
```bash
cat /var/log/backend.json | jq 'select(.TraceId == "550e8400-e29b-41d4-a716-446655440000")'
```

**Show only capture points:**
```bash
grep "CapturePoint" /var/log/backend.json | jq '{timestamp: .Timestamp, point: .CapturePointId, label: .Label, duration: .DurationMs}'
```

**Find slow requests (> 5 seconds total):**
```bash
cat /var/log/backend.json | jq 'select(.CapturePointId == "CP-BE-8" and .DurationMs > 5000)'
```

**Count requests by result:**
```bash
cat /var/log/backend.json | jq -r 'select(.CapturePointId == "CP-FE-2") | .Data.success' | sort | uniq -c
```

### Using CloudWatch Insights (Production)

**Basic Query:**
```
fields @timestamp, TraceId, CapturePointId, Component, Label, DurationMs
| filter TraceId = "550e8400-e29b-41d4-a716-446655440000"
| sort @timestamp asc
```

**Performance Analysis:**
```
fields @timestamp, CapturePointId, DurationMs
| filter CapturePointId in ["CP-BE-3", "CP-BE-5", "CP-BE-7"]
| stats avg(DurationMs) as AvgDuration, max(DurationMs) as MaxDuration by CapturePointId
```

**Error Rate:**
```
fields @timestamp, TraceId, Error
| filter CapturePointId = "CP-FE-2" and Error.Message is not null
| stats count() as ErrorCount by bin(5m)
```

---

## Common Scenarios

### Scenario 1: Debug a Failed Tour Calculation

**Problem:** User reports "Calculate routes failed" but no clear error message.

**Steps:**

1. **Get trace ID from user:**
   - Ask user to open DevTools Console
   - Look for trace ID in logs

2. **Query backend logs:**
   ```bash
   grep "<trace-id>" /var/log/backend.json | jq .
   ```

3. **Identify failure point:**
   - Look for capture points with Error field
   - Check which component failed (CP-BE-*, CP-TB-*)

4. **Inspect data:**
   - If CP-BE-3 succeeded: PoolDTO was retrieved correctly
   - If CP-BE-5 failed: TOP Service issue
   - If CP-TB-2-Error: TMS Bridge couldn't save

5. **Root cause:**
   ```bash
   # Extract error details
   cat /var/log/backend.json | jq 'select(.TraceId == "<trace-id>" and .Error != null) | .Error'
   ```

### Scenario 2: Analyze Slow Tour Calculation

**Problem:** Tour calculation takes too long (> 10 seconds).

**Steps:**

1. **Find the slow trace:**
   ```bash
   cat /var/log/backend.json | jq 'select(.CapturePointId == "CP-BE-8" and .DurationMs > 10000)'
   ```

2. **Break down timing:**
   ```bash
   # Extract all durations for this trace
   cat /var/log/backend.json | jq 'select(.TraceId == "<trace-id>" and .DurationMs != null) | {point: .CapturePointId, duration: .DurationMs}'
   ```

3. **Identify bottleneck:**
   - CP-BE-3 duration: Time to fetch PoolDTO from TMS Bridge
   - CP-BE-5 duration: Time in TOP Service (tour optimization)
   - CP-BE-7 duration: Time to save to TMS Bridge

4. **Typical durations:**
   - CP-BE-3 (GetPoolDto): 200-500ms
   - CP-BE-5 (TOP Service): 2000-5000ms (depends on complexity)
   - CP-BE-7 (SetPoolDto): 300-700ms

5. **If TOP Service is slow:**
   - Check PoolDTO complexity (tour elements count)
   - Review TOP configuration
   - Consider optimization parameters

### Scenario 3: Compare PoolDTO Before/After TOP

**Problem:** Routes don't match expectations after optimization.

**Steps:**

1. **Extract PoolDTO before TOP (CP-BE-3):**
   ```bash
   cat /var/log/backend.json | jq 'select(.TraceId == "<trace-id>" and .CapturePointId == "CP-BE-3") | .Data'
   ```

2. **Extract PoolDTO after TOP (CP-BE-5):**
   ```bash
   cat /var/log/backend.json | jq 'select(.TraceId == "<trace-id>" and .CapturePointId == "CP-BE-5") | .Data'
   ```

3. **Compare:**
   - Use diff tool or visual comparison
   - Focus on Plan.TourElements
   - Check route sequences, times, distances

4. **Validate:**
   - Ensure all tour points present
   - Check calculated times and distances
   - Verify route optimization applied

### Scenario 4: Production Issue Investigation

**Problem:** Multiple users reporting intermittent failures.

**Steps:**

1. **Find all failed traces in time window:**
   ```bash
   # Last hour
   grep "CP-FE-2" /var/log/backend.json | jq 'select(.Data.success == false and .Timestamp > "2026-03-10T10:00:00")'
   ```

2. **Group by error type:**
   ```bash
   cat /var/log/backend.json | jq -r 'select(.Error != null) | .Error.Message' | sort | uniq -c
   ```

3. **Identify pattern:**
   - Same error message? → Common issue
   - Same component? → Component-specific issue
   - Time-based? → Infrastructure issue
   - User-specific? → Data issue

4. **Correlate with other logs:**
   - Check TMS Bridge logs for same time period
   - Check infrastructure metrics (CPU, memory, network)
   - Check database logs

---

## Troubleshooting

### Issue: Trace ID Missing in Logs

**Symptoms:**
- Console shows trace ID generated
- Backend logs don't have TraceId field

**Diagnosis:**
```bash
# Check if X-Trace-Id header is sent
# Open DevTools → Network → Select request → Headers tab
# Look for: X-Trace-Id: <uuid>
```

**Solutions:**
1. Verify `traceIdInterceptor` is registered in `app.config.ts`
2. Check interceptor order (traceId should be before logger)
3. Verify `TraceContextMiddleware` is early in Backend pipeline
4. Check if request path matches middleware condition

### Issue: Captures Not Appearing

**Symptoms:**
- Trace ID present but some capture points missing

**Diagnosis:**
```bash
# List all capture points for trace
cat /var/log/backend.json | jq -r 'select(.TraceId == "<trace-id>") | .CapturePointId'
```

**Solutions:**
1. Check if code path executed (add breakpoints)
2. Verify capture service injected correctly
3. Check for exceptions before capture point
4. Review circuit breaker status

### Issue: Circuit Breaker Opened

**Symptoms:**
- Warning logs: "Circuit breaker open, capture skipped"

**Diagnosis:**
```bash
# Check stats in code
var stats = traceCaptureService.GetStats();
// stats.CircuitBreakerOpen == true
// stats.ConsecutiveFailures >= 5
```

**Solutions:**
1. Review error logs for root cause
2. Fix underlying serialization/storage issue
3. Circuit breaker auto-closes on next successful capture
4. Can manually clear if needed: `traceCaptureService.ClearAllTraces()`

### Issue: Performance Degradation

**Symptoms:**
- Requests slower after enabling tracing

**Diagnosis:**
```bash
# Measure capture overhead
# Add stopwatch around capture calls in code
```

**Solutions:**
1. Verify captures are async/non-blocking
2. Reduce data captured (e.g., summary instead of full PoolDTO)
3. Enable sampling (only trace 10% of requests)
4. Check if large objects being serialized

---

## Best Practices

### For Developers

1. **Always use trace context:**
   ```csharp
   var traceId = _traceContext.GetTraceId();
   // Use traceId for logging
   _logger.LogInformation("Processing request {TraceId}", traceId);
   ```

2. **Non-blocking captures:**
   ```csharp
   await _traceCaptureService.CaptureAsync(traceId, capturePoint);
   // Never block on capture
   ```

3. **Handle missing trace ID:**
   ```csharp
   if (string.IsNullOrEmpty(traceId))
   {
       _logger.LogDebug("No trace ID for capture");
       return; // Don't throw
   }
   ```

4. **Capture errors:**
   ```csharp
   catch (Exception ex)
   {
       await CaptureAsync(traceId, "CP-XX", "Operation failed", error: new ErrorInfo
       {
           Message = ex.Message,
           Stack = ex.StackTrace
       });
       throw; // Re-throw after capturing
   }
   ```

### For Operations

1. **Monitor circuit breakers:**
   - Alert if circuit breaker opens
   - Review logs for consecutive failures

2. **Log retention:**
   - Keep traces for 30-90 days minimum
   - Consider longer for production issues

3. **Performance baseline:**
   - Capture overhead should be < 10ms per point
   - Total overhead < 100ms per request

4. **Storage management:**
   - Monitor log volume (traces can be large)
   - Consider sampling for high-traffic environments

### For Support Engineers

1. **Always get trace ID first:**
   - Ask users to provide trace ID from console
   - Or search logs by timestamp + transport order ID

2. **Document findings:**
   - Include trace ID in support tickets
   - Attach relevant log excerpts

3. **Escalation:**
   - If trace shows TOP Service slowness → Escalate to optimization team
   - If trace shows TMS Bridge errors → Escalate to TMS team

---

## Reference

### Trace ID Format

- **Type:** UUID v4
- **Example:** `550e8400-e29b-41d4-a716-446655440000`
- **Generated:** Frontend (Angular)
- **Propagated:** Via `X-Trace-Id` HTTP header

### Header Format

```
X-Trace-Id: 550e8400-e29b-41d4-a716-446655440000
```

### Log Format (Serilog JSON)

```json
{
  "@timestamp": "2026-03-10T14:30:45.123Z",
  "Level": "Information",
  "MessageTemplate": "[TraceCaptureService] TraceId={TraceId}, CapturePoint={CapturePointId}...",
  "TraceId": "550e8400-e29b-41d4-a716-446655440000",
  "CapturePointId": "CP-BE-3",
  "Component": "Backend",
  "Label": "After GetPoolDto call - PoolDTO received",
  "Timestamp": "2026-03-10T14:30:45.123Z",
  "DurationMs": 342.5,
  "Data": { "PoolDto": {...} }
}
```

### Service Configuration

#### Frontend
- **Service:** `TraceCaptureService`
- **Lifetime:** Singleton
- **Storage:** In-memory Map (max 100 traces)
- **Output:** Browser console

#### Backend
- **Service:** `TraceCaptureService`
- **Lifetime:** Singleton
- **Storage:** ConcurrentDictionary + Channel
- **Output:** Serilog

#### TMS Bridge
- **Service:** `TraceCaptureService`
- **Lifetime:** Singleton
- **Storage:** ConcurrentDictionary
- **Output:** Serilog

### Circuit Breaker Settings

- **Threshold:** 5 consecutive failures
- **Action:** Skip captures (log warning)
- **Recovery:** Automatic on first successful capture

### Retention Limits

- **In-Memory:** 100 traces (FIFO)
- **Logs:** Per logging policy (30-90 days recommended)

---

## Additional Resources

- [Implementation Plan](implementation-plan.md) - Technical implementation details
- [Test Validation](test-validation.md) - Test scenarios and validation
- [Storage Strategy](storage-strategy.md) - Storage options and recommendations
- [Concept V1](concept-v1-minimal.md) - Original design document

---

## Support

For questions or issues:
1. Check this guide first
2. Review [Troubleshooting](#troubleshooting) section
3. Check [Test Validation](test-validation.md) for common scenarios
4. Escalate to development team with trace ID and logs

---

**Last Updated:** 2026-03-10
**Version:** 1.0
**Maintained By:** New Dispo Development Team
