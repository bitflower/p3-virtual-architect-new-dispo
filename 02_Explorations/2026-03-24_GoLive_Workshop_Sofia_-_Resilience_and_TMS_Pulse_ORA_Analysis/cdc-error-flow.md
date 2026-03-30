# CDC Error Flow

**Workshop Date:** 2026-03-19
**Analysis Date:** 2026-03-24

## Current State - Critical Issues

**Problem:** Backend currently acknowledges ALL CDC events with HTTP 200, even when processing fails.
- Events are marked as processed even when errors occur
- No retry mechanism for failed events
- Data can become out of sync silently

## Implementation Options (from Miro Board)

### ✅ Option 1: Fix Push + Dead Letter Topic (DONE - PR)
**Status:** Implementation complete, pending PR merge
- Return HTTP 500/503 on failure instead of 200
- Configure Pub/Sub retry policy with exponential backoff
- Dead letter topic for messages exceeding retry limit
- **Characteristics:**
  - Minimal code changes
  - Uses Google Cloud native features
  - Automatic retry with backoff
  - Failed events not lost
  - Risk: Low

### ✅ Option 2: Switch to Pull Subscription (DONE)
**Status:** Already implemented
- Backend pulls messages from Pub/Sub with explicit acknowledgment control
- Explicit acknowledgment timing control
- Automatic retry for unacknowledged messages
- Backpressure handling capability
- **Characteristics:**
  - Risk: Medium
  - **Note:** Only choose if strategic infrastructure reasons exist beyond solving core problem

### Option 3: Idempotent Event Handlers + Deduplication
**Status:** Discussed for future consideration
- Make handlers idempotent
- Store processed event IDs for deduplication
- Allows safe retries without side effects
- Prevents duplicate processing
- **Characteristics:**
  - Risk: Medium
  - **Note:** Complements Option 1 or 2, doesn't solve retry mechanism on its own

### Option 4: Event Store for CDC Events
**Status:** Not prioritized
- Persist all CDC events before processing
- Complete audit trail
- Manual recovery possible
- Full event history
- **Characteristics:**
  - Significant implementation effort
  - More appropriate for future enhancement

## Event Ordering Challenges

**Critical Issue:** Pub/Sub does NOT guarantee message ordering by default

**Problem Scenario:**
1. Shipment updated (Version 1) → Event A
2. Shipment updated (Version 2) → Event B
3. Events arrive out of order: B processed, then A
4. Result: Older data overwrites newer data

**Solutions Discussed:**

### Approach 1: Partition Key / Message Ordering
- Use shipment ID as partition key
- Pub/Sub guarantees order within same key
- Requires configuration in Cloud Function publishing events
- **Implementation:** Extract common property (shipment ID), use as message key

### Approach 2: Timestamp/Version-Based Rejection
- Include timestamp or version field in events
- Before applying update, compare timestamps
- Reject older events if newer already applied
- **SQL Example:** `UPDATE record X WHERE timestamp < incoming_timestamp`
- **Requirement:** Must be in WHERE clause to handle concurrency
- **Challenge:** Needs timestamp/version support from TMS

**Preferred Solution:** Combination of both approaches
- Use partition keys where possible
- Add timestamp validation as safety net
- Only apply latest version of data

## CDC Performance Issues

**Observed Problem:** 5+ minute delays between TMS change and New Dispo update

**Potential Causes:**

### 1. Data Stream Batching
- Data Stream optimized for throughput, not latency
- Batches changes before pushing to storage
- Trade-off: High throughput vs. low latency
- **Configuration:** Polling frequency and batch size configurable

### 2. Proxy Layer (CRITICAL ISSUE)
**Discovery:** Data Stream connects through a proxy, not directly to database
- Proxy set up by previous managed service provider ~2 years ago
- Rationale (outdated): "Couldn't provide database access without proxy back then"
- **Impact:**
  - If proxy drops connection, Data Stream doesn't know
  - Replication gets into unrecoverable state
  - Requires manual recreation of Data Stream instance
  - Adds latency and unreliability

**Recommended Action:** Test direct database connection
- Requires Virtual Private Connect (VPC) setup
- DevOps component needed
- Google documentation: Data Stream should have direct TCP connection
- **Blocker:** Need Dominik/DevOps support (currently unavailable - "political" issue)

### 3. Storage Bucket Delays
- Cloud Function triggers on bucket changes
- Potential delay between file arrival and function invocation
- Less likely to be primary issue

### 4. Database Write-Back Configuration
- Some databases buffer changes in memory before disk write
- CDC can only see changes after disk write
- **Assessment:** Unlikely on cloud-managed Postgres (usually near-zero RPO)
- **Verification:** Would require direct CDC API connection test

## Batch Recovery Layer

**Purpose:** Handle missed changes after outages

**Approach:**
- Use high watermark timestamps
- Backfill data for period when CDC was down
- Manual intervention as fallback
- **Status:** Proposed for future implementation

## Open Questions & Assumptions

### Open Questions
1. Can we implement message ordering (partition keys)?
2. Do TMS events include timestamps or version fields?
3. What is acceptable latency for CDC updates?
4. When can we test direct database connection (VPC setup)?
5. Should we prioritize low latency or high throughput?
6. What is proxy configuration and can it be removed?

### Assumptions
1. **Pull-based subscription is sufficient** - No need for additional changes
2. **Returning correct HTTP codes resolves retry** - Dead letter queue handles failures
3. **Timestamp comparison can prevent out-of-order issues** - If timestamps available
4. **Direct connection will improve performance** - Proxy is bottleneck
5. **5-minute delay is unacceptable** - Need sub-minute updates

### Risks
1. **HIGH:** Proxy causing connection drops and unrecoverable CDC state
2. **MEDIUM:** Event ordering not guaranteed without partition keys
3. **MEDIUM:** DevOps unavailable for VPC setup (political issue)
4. **LOW:** Data Stream configuration not optimal for latency

## Next Steps

### CDC Error Flow
- [ ] Merge PR for HTTP error code fixes
- [ ] Investigate partition key implementation for event ordering
- [ ] Check if TMS events include timestamps/versions
- [ ] Research VPC setup requirements for direct DB connection
- [ ] Document proxy configuration and assess removal feasibility
- [ ] Test Data Stream configuration options for latency

## Miro Board Artifacts

📋 **[View Full Miro Board (SVG) →](./Miro%20New%20Dispo%202025%20(Internal)%20-%202026-03-19_Workshop-Sofia.svg)**

### CDC Error Flow Section
- **Implementation Options:**
  - Order of events needs evaluation (PR status noted)
  - Done (PR) markers on first two options
  - Risk levels documented (Low, Medium)
  - Notes on strategic infrastructure considerations
