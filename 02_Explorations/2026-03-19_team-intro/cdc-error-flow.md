# CDC Error Flow Solution Design

---

## Business Context

**Critical workflow:**
1. CDC events stream from TMS database to New Dispo via Google Bucket/Pub/Sub
2. New Dispo processes events to stay synchronized with TMS
3. Any processing failure results in permanent data loss

**The Problem:** CDC events are consumed but lost forever if internal processing fails. System returns HTTP 200 OK even on failures, causing Google Pub/Sub to acknowledge messages prematurely without retry.

**Challenges:**
- **Data loss:** TMS changes become invisible in New Dispo
- **System out of sync:** No automatic recovery mechanism
- **Silent failures:** No operator visibility into lost events
- **Premature acknowledgment:** HTTP 200 returned before processing completes

---

## Error Scenarios - The Problem (Example: CDC Event Processing)

### Current Push Model Failure

```
Pub/Sub → HTTP POST → New Dispo Backend → Returns 200 OK (premature ack!)
```

**Impact:** Backend returns HTTP 200 before processing completes, message acknowledged prematurely, event lost forever if processing fails internally.

---

## Implementation Options

1. **Fix Push + Dead Letter Topic** (Lowest Effort) - Return HTTP 500/503 on failure + configure Pub/Sub retry policy with exponential backoff and dead letter topic for messages exceeding retry limit
   - Minimal code changes, uses Google Cloud native features
   - Automatic retry with backoff
   - Failed events not lost
   - Risk: Low

2. **Switch to Pull Subscription** - Backend pulls messages from Pub/Sub with explicit acknowledgment control
   - Explicit acknowledgment timing control
   - Automatic retry for unacknowledged messages
   - Backpressure handling capability
   - Risk: Medium
   - **Note:** Only choose if strategic infrastructure reasons exist beyond solving core problem

3. **Idempotent Event Handlers + Deduplication** - Make handlers idempotent and store processed event IDs for deduplication
   - Allows safe retries without side effects
   - Prevents duplicate processing
   - Risk: Medium
   - **Note:** Complements Option 1 or 2, doesn't solve retry mechanism on its own

4. **Event Store for CDC Events** - Persist all CDC events before processing for complete audit trail and replay capability
   - Full event history and manual recovery possible
   - Complete CDC event audit trail
   - Risk: Low
   - **Note:** Can be added incrementally after implementing Option 1

---

## Push vs Pull Comparison

| Aspect | Push (Current) | Push (Fixed - Option 1) | Pull (Option 2) |
|--------|---------------|------------------------|-----------------|
| Ack Control | Poor (HTTP 200 bug) | Good (throw on error) | Excellent (explicit) |
| Cloud Run Fit | Perfect | Perfect | Acceptable (needs always-on) |
| Latency | Low (immediate push) | Low (immediate push) | Higher (polling interval) |
| Backpressure | Limited | Limited | Full control |
| Code Changes | Minimal (fix bug) | Minimal (fix bug) | Significant (new worker) |
| Deployment | Existing | Existing | New infrastructure |
| Solves Problem | No | Yes | Yes |

---

## Challenges

- **Retries may fail repeatedly** if root cause persists (e.g., bad data)
- **Manual intervention required** for dead letter queue
- **No guarantee of eventual success** for permanent failures
- **Increased Pub/Sub costs** with retry policies
- **Pull model complexity** if Option 2 chosen - requires persistent worker management

