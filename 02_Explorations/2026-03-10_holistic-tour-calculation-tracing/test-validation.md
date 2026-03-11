# Test Validation: Holistic Tour Calculation Tracing V1

**Date:** 2026-03-10
**Status:** Ready for Testing
**Version:** V1 Minimal Implementation

---

## Test Scenarios

### Scenario 1: Happy Path - Successful Tour Calculation

**Objective:** Verify all 11+ capture points fire correctly during a successful tour calculation.

**Prerequisites:**
- All three services running (Frontend, Backend, TMS Bridge)
- Valid transport order exists in system
- User authenticated via Keycloak

**Test Steps:**
1. Open browser DevTools Console (to see Frontend logs)
2. Navigate to transport order details page
3. Click "Calculate Routes" button
4. Wait for calculation to complete
5. Check logs in all three components

**Expected Results:**

#### Frontend Logs (Browser Console)
```
[TraceIdService] Generated new trace ID: <uuid>
[CalculateRoutesService] Starting tour calculation for order <id> with trace ID: <uuid>
[TraceCaptureService] {"traceId":"<uuid>","capturePointId":"CP-FE-1","component":"Frontend","label":"Calculate routes request initiated",...}
[TraceCaptureService] {"traceId":"<uuid>","capturePointId":"CP-FE-2","component":"Frontend","label":"Calculate routes response received - Success",...}
[CalculateRoutesService] Tour calculation completed for order <id>, trace ID: <uuid>, duration: <ms>ms
```

#### Backend Logs (Serilog)
```
[TraceContextMiddleware] Request received with trace ID: <uuid>
[TransportOrdersController] TraceId=<uuid>, CapturePoint=CP-BE-1, Component=Backend, Label=Calculate Routes request received
[CalculateRoutesCommandHandler] TraceId=<uuid>, CapturePoint=CP-BE-2, Component=Backend, Label=Before GetPoolDto call to TMS Bridge
[GraphQLQueryService] Propagating trace ID to TMS Bridge: <uuid>
[CalculateRoutesCommandHandler] TraceId=<uuid>, CapturePoint=CP-BE-3, Component=Backend, Label=After GetPoolDto call - PoolDTO received
[CalculateRoutesCommandHandler] TraceId=<uuid>, CapturePoint=CP-BE-4, Component=Backend, Label=Before TOP Service call
[CalculateRoutesCommandHandler] TraceId=<uuid>, CapturePoint=CP-BE-5, Component=Backend, Label=After TOP Service call - Enriched PoolDTO
[CalculateRoutesCommandHandler] TraceId=<uuid>, CapturePoint=CP-BE-6, Component=Backend, Label=Before SetPoolDto call to TMS Bridge
[CalculateRoutesCommandHandler] TraceId=<uuid>, CapturePoint=CP-BE-7, Component=Backend, Label=After SetPoolDto call
[TransportOrdersController] TraceId=<uuid>, CapturePoint=CP-BE-8, Component=Backend, Label=Calculate Routes response sent
```

#### TMS Bridge Logs
```
[TraceContextRequestMiddleware] GraphQL request received with trace ID: <uuid>
[TraceCaptureService] TraceId=<uuid>, CapturePoint=CP-TB-1, Component=TMS-Bridge, Label=GetXserverDto GraphQL query entry
[TraceCaptureService] TraceId=<uuid>, CapturePoint=CP-TB-1-Complete, Component=TMS-Bridge, Label=GetXserverDto completed
[TraceContextRequestMiddleware] GraphQL request received with trace ID: <uuid>
[TraceCaptureService] TraceId=<uuid>, CapturePoint=CP-TB-2, Component=TMS-Bridge, Label=SetXserverDto GraphQL mutation entry
[TraceCaptureService] TraceId=<uuid>, CapturePoint=CP-TB-2-Complete, Component=TMS-Bridge, Label=SetXserverDto completed successfully
```

**Success Criteria:**
- ✅ All 14 capture points logged
- ✅ Same trace ID in all logs
- ✅ Timestamps are sequential
- ✅ Performance data captured (durations in ms)
- ✅ Complete PoolDTO captured at CP-BE-3 and CP-BE-5
- ✅ No errors in capture system
- ✅ Response returned successfully to Frontend

---

### Scenario 2: Error Path - TMS Bridge Returns Error

**Objective:** Verify trace capture works correctly when TMS Bridge returns an error.

**Test Steps:**
1. Configure TMS Bridge to simulate error (or use invalid transport order ID)
2. Trigger tour calculation
3. Verify error is captured in trace

**Expected Results:**
- ✅ CP-FE-1 through CP-BE-2 captured normally
- ✅ CP-TB-2-Error captured with error details
- ✅ CP-FE-2 captured with error state
- ✅ Trace marked as complete even with error
- ✅ Error details include message and stack trace
- ✅ No exceptions thrown from capture system

**Error Capture Example:**
```json
{
  "traceId": "<uuid>",
  "capturePointId": "CP-TB-2-Error",
  "component": "TMS-Bridge",
  "label": "SetXserverDto failed",
  "error": {
    "message": "Database error message",
    "stack": "..."
  },
  "durationMs": 250
}
```

---

### Scenario 3: Error Path - TOP Service Fails

**Objective:** Verify trace capture when tour optimization fails.

**Test Steps:**
1. Configure invalid PoolDTO or TOP parameters
2. Trigger tour calculation
3. Verify captures up to failure point

**Expected Results:**
- ✅ CP-FE-1 through CP-BE-4 captured
- ✅ Exception at CP-BE-5 is handled
- ✅ Error propagates to Frontend
- ✅ CP-FE-2 captures error state
- ✅ All captures non-blocking (system still responds)

---

### Scenario 4: Performance Test - 10 Consecutive Calculations

**Objective:** Verify no memory leaks, cleanup works, and circuit breaker doesn't trip.

**Test Steps:**
1. Clear all traces: Call `traceCaptureService.clearAllTraces()` in each service
2. Trigger 10 consecutive tour calculations (same or different orders)
3. Check trace capture statistics
4. Verify cleanup after retention limit

**Expected Results:**
- ✅ All 10 traces captured successfully
- ✅ Circuit breaker remains closed (no consecutive failures)
- ✅ Memory usage stable (no leaks)
- ✅ Old traces removed when exceeding max 100 traces
- ✅ Performance overhead < 10ms per capture point

**Statistics Check (Backend example):**
```csharp
var stats = traceCaptureService.GetStats();
// stats.ActiveTraces = 10
// stats.TotalCapturePoints = 80 (8 points × 10 traces)
// stats.CircuitBreakerOpen = false
// stats.ConsecutiveFailures = 0
```

---

### Scenario 5: Circuit Breaker Test

**Objective:** Verify circuit breaker opens after 5 consecutive failures and recovers.

**Test Steps:**
1. Simulate 5 consecutive capture failures (e.g., by injecting exceptions)
2. Verify circuit breaker opens
3. Trigger new calculation
4. Verify captures are skipped with warning logs
5. Fix issue and trigger calculation
6. Verify circuit breaker closes

**Expected Results:**
- ✅ Circuit breaker opens after 5 failures
- ✅ Warning logs: "Circuit breaker open, capture skipped"
- ✅ System continues to function normally
- ✅ Circuit breaker auto-closes on first successful capture
- ✅ No impact on main request processing

---

### Scenario 6: Missing Trace ID

**Objective:** Verify graceful handling when trace ID is not set.

**Test Steps:**
1. Make a request without X-Trace-Id header (direct API call)
2. Verify system doesn't crash
3. Check debug logs

**Expected Results:**
- ✅ No exceptions thrown
- ✅ Debug logs: "No trace ID available for capture point"
- ✅ Request processes normally
- ✅ No capture points recorded
- ✅ System remains stable

---

## Manual Validation Checklist

### Pre-Test Setup
- [ ] All three services deployed and running
- [ ] Logging configured (Frontend: Console, Backend/TMS Bridge: Serilog)
- [ ] Test transport order exists
- [ ] User has valid Keycloak session

### Happy Path Validation
- [ ] Generate trace ID in Frontend
- [ ] Trace ID in Backend logs
- [ ] Trace ID in TMS Bridge logs
- [ ] All 14 capture points fire
- [ ] Sequential timestamps
- [ ] Performance data captured
- [ ] PoolDTO captured at critical points (CP-BE-3, CP-BE-5)
- [ ] Trace marked complete

### Error Handling Validation
- [ ] TMS Bridge error captured
- [ ] TOP Service error handled
- [ ] Frontend receives error
- [ ] Error details in trace
- [ ] No system crashes

### Performance Validation
- [ ] Overhead < 10ms per capture
- [ ] No memory leaks
- [ ] Cleanup after 100 traces
- [ ] Circuit breaker functional
- [ ] Background processing works

### Storage Validation
- [ ] Logs queryable by trace ID
- [ ] Structured log format correct
- [ ] Can filter by component
- [ ] Can filter by capture point ID
- [ ] Performance data accessible

---

## Query Examples (Structured Logs)

### Find all captures for a trace ID
```bash
# Backend/TMS Bridge (Serilog with JSON output)
grep "\"TraceId\":\"<uuid>\"" /var/log/backend.json | jq .

# Frontend (Browser DevTools)
Filter console by: [TraceCaptureService]
```

### Find all captures at a specific point
```bash
# Find all CP-BE-3 captures (critical PoolDTO)
grep "\"CapturePointId\":\"CP-BE-3\"" /var/log/backend.json | jq .
```

### Find slow requests
```bash
# Find traces with total duration > 5000ms
grep "\"CapturePointId\":\"CP-BE-8\"" /var/log/backend.json | jq 'select(.DurationMs > 5000)'
```

### Find failed traces
```bash
# Find traces with errors
grep "\"Error\":" /var/log/backend.json | jq .
```

---

## Troubleshooting Guide

### Issue: No trace ID in logs
**Symptoms:** Logs appear but no TraceId field

**Possible Causes:**
1. Frontend not generating trace ID
2. HTTP interceptor not adding X-Trace-Id header
3. Middleware not extracting header

**Debug Steps:**
1. Check browser DevTools Network tab → Headers → Request Headers → X-Trace-Id
2. Check Backend middleware logs: "Request received with trace ID"
3. Verify TraceContextMiddleware is registered early in pipeline

---

### Issue: Circuit breaker opened
**Symptoms:** Warning logs "Circuit breaker open, capture skipped"

**Possible Causes:**
1. 5+ consecutive capture failures
2. Storage system issue
3. Serialization errors

**Debug Steps:**
1. Check stats: `traceCaptureService.GetStats()`
2. Review error logs for root cause
3. Fix underlying issue
4. Circuit breaker will auto-close on next successful capture

---

### Issue: Missing capture points
**Symptoms:** Some capture points not in logs

**Possible Causes:**
1. Code path not executed (e.g., early return)
2. Exception before capture point
3. Capture call wrapped in incorrect try-catch

**Debug Steps:**
1. Add breakpoints at missing capture points
2. Verify code path is executed
3. Check for exceptions before capture
4. Ensure capture calls are not in try-catch that swallows errors

---

### Issue: Performance degradation
**Symptoms:** Slow requests after enabling tracing

**Possible Causes:**
1. Blocking capture calls (should be async)
2. Large data objects being serialized
3. Too many capture points

**Debug Steps:**
1. Profile with Stopwatch around captures
2. Check if captures are truly non-blocking
3. Reduce data captured (e.g., only count instead of full object)
4. Consider sampling (only trace 10% of requests)

---

## Next Steps After Validation

### If All Tests Pass
1. ✅ Mark Phase 5.1 complete
2. Proceed to Task 5.2: Storage Strategy Selection
3. Proceed to Task 5.3: Documentation

### If Issues Found
1. Document issues in this file
2. Prioritize by severity
3. Fix critical issues
4. Re-test
5. Update implementation as needed

---

## Notes for Future Enhancements (V2)

Based on validation results, consider for V2:
- [ ] Add sampling capability (trace only X% of requests)
- [ ] Add query API endpoint for in-memory traces
- [ ] Add export to JSON file functionality
- [ ] Add distributed tracing correlation (if multiple backends)
- [ ] Add visualization dashboard
- [ ] Add alerting on trace anomalies
- [ ] Add trace replay for debugging
