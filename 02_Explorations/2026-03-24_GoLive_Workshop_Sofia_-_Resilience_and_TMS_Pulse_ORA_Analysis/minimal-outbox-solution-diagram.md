# Minimal Outbox Solution: Visual Flow Diagram

**Date:** 2026-03-25
**Purpose:** Visual explanation of the "red arrow" approach from workshop

---

## Current Problem (Scenario 2)

```mermaid
sequenceDiagram
    participant User
    participant Backend as New Dispo Backend
    participant LocalDB as New Dispo DB
    participant Bridge as TMS Bridge
    participant TMS as TMS Database

    User->>Backend: Create Transport Order
    Note over Backend: ❌ NO transaction yet

    Backend->>Bridge: Call TMS (Step 1)
    Bridge->>TMS: Execute SQL
    TMS-->>Bridge: ✅ Success (TransportOrderId: 12345)
    Bridge-->>Backend: ✅ Return TransportOrderId

    Note over Backend,LocalDB: ⚡ NOW try to save locally
    Backend->>LocalDB: SaveChangesAsync()
    LocalDB--xBackend: ❌ Database Unavailable

    Note over Backend,TMS: 🔥 DATA OUT OF SYNC<br/>TMS has order 12345<br/>Local DB has nothing

    Backend-->>User: ❌ Error: Failed to save
    Note over User: 😰 User has no way to recover<br/>Support must manually fix
```

---

## Minimal Outbox Solution

```mermaid
sequenceDiagram
    participant User
    participant Backend as New Dispo Backend
    participant LocalDB as New Dispo DB
    participant Bridge as TMS Bridge
    participant TMS as TMS Database

    User->>Backend: Create Transport Order

    rect rgb(255, 200, 200)
        Note over Backend,LocalDB: ⚡ RED ARROW: Start Transaction FIRST
        Backend->>LocalDB: BEGIN TRANSACTION

        Note over Backend,LocalDB: Step 1: Persist User Intent
        Backend->>LocalDB: INSERT INTO TmsSyncOutbox<br/>(Operation: CreateTransportOrder,<br/>Payload: {lotId, legs, date},<br/>Status: Pending)

        Backend->>LocalDB: COMMIT TRANSACTION
        LocalDB-->>Backend: ✅ Committed
        Note over Backend,LocalDB: ✅ User intent is now SAFE<br/>Cannot be lost
    end

    Backend-->>User: 202 Accepted<br/>(OutboxId: abc-123)
    Note over User: "Creating transport order..."

    rect rgb(200, 255, 200)
        Note over Backend,TMS: Step 2: Execute TMS Operation<br/>(After local commit)

        Backend->>LocalDB: UPDATE Outbox Status='Processing'

        Backend->>Bridge: Call TMS
        Bridge->>TMS: Execute SQL

        alt TMS Success
            TMS-->>Bridge: ✅ TransportOrderId: 12345
            Bridge-->>Backend: ✅ Success

            Backend->>LocalDB: BEGIN TRANSACTION
            Backend->>LocalDB: INSERT LotAssignment<br/>(TransportOrderId: 12345)
            Backend->>LocalDB: UPDATE Outbox<br/>(Status: Completed,<br/>TmsResponse: {12345})
            Backend->>LocalDB: COMMIT TRANSACTION

            Backend-->>User: ✅ 200 OK
            Note over User: ✅ "Transport order created"

        else TMS Failure OR Local DB Failure
            TMS--xBridge: ❌ Network timeout
            Bridge--xBackend: ❌ Error

            Backend->>LocalDB: UPDATE Outbox<br/>(Status: Failed,<br/>Error: "TMS timeout")

            Backend-->>User: ❌ Error + [Retry Button]
            Note over User: 🔄 User can click Retry
        end
    end
```

---

## Retry Flow (Idempotent)

```mermaid
sequenceDiagram
    participant User
    participant Backend as New Dispo Backend
    participant LocalDB as New Dispo DB
    participant Bridge as TMS Bridge
    participant TMS as TMS Database

    User->>Backend: POST /api/transportorders/retry<br/>(OutboxId: abc-123)

    Backend->>LocalDB: SELECT * FROM TmsSyncOutbox<br/>WHERE Id = 'abc-123'
    LocalDB-->>Backend: Outbox Entry<br/>(Status: Failed,<br/>Payload: {lotId, legs, date})

    Note over Backend: Check idempotency:<br/>Was TMS operation completed?

    alt TmsResponse exists in outbox
        Note over Backend: TMS succeeded previously,<br/>only local DB failed
        Backend->>LocalDB: Use existing TmsResponse<br/>(TransportOrderId: 12345)
        Note over Backend,TMS: ⏭️ Skip TMS call (idempotent)
    else TmsResponse is NULL
        Note over Backend: TMS never succeeded,<br/>safe to call again
        Backend->>Bridge: Query TMS<br/>(Check if order exists for lotId)
        Bridge->>TMS: SELECT * WHERE context_matches

        alt Transport Order exists in TMS
            TMS-->>Bridge: Found: TransportOrderId 12345
            Bridge-->>Backend: Existing record
            Note over Backend: Idempotency: Use existing
        else Transport Order NOT in TMS
            TMS-->>Bridge: Not found
            Bridge-->>Backend: NULL
            Backend->>Bridge: Create new transport order
            Bridge->>TMS: Execute SQL
            TMS-->>Bridge: ✅ TransportOrderId: 67890
            Bridge-->>Backend: ✅ New order created
        end
    end

    rect rgb(200, 255, 200)
        Note over Backend,LocalDB: Final local commit
        Backend->>LocalDB: BEGIN TRANSACTION
        Backend->>LocalDB: INSERT LotAssignment<br/>(TransportOrderId: 12345 or 67890)
        Backend->>LocalDB: UPDATE Outbox<br/>(Status: Completed)
        Backend->>LocalDB: COMMIT TRANSACTION
    end

    Backend-->>User: ✅ 200 OK
    Note over User: ✅ "Transport order created"
```

---

## Key Differences: Before vs After

### Before (Current Code)

| Step | Action | Risk |
|------|--------|------|
| 1 | Call TMS | If succeeds → go to step 2 |
| 2 | Save local DB | ❌ **If fails → DATA OUT OF SYNC** |
| 3 | Return to user | User has no recovery option |

**Problem:** No persistent record of user intent if step 2 fails.

### After (Minimal Outbox Solution)

| Step | Action | Risk |
|------|--------|------|
| 1 | **Save outbox entry** | ✅ **If fails → fail fast, user retries** |
| 2 | Call TMS | If fails → outbox has record, can retry |
| 3 | Update local DB | If fails → outbox has TMS response, can retry |
| 4 | Return to user | User can retry from persistent state |

**Solution:** User intent persisted FIRST (red arrow), all subsequent steps are retryable.

---

## Red Arrow Principle

> **"Commit local state BEFORE calling external systems"**

This is a fundamental principle of distributed systems:

1. **Local First:** Persist to your own database with ACID guarantees
2. **External Later:** Call external systems (which may fail) with retry capability
3. **Eventual Consistency:** External systems will catch up via retry mechanism

This inverts the risk model:
- **Old:** External success + Local failure = **Out of sync**
- **New:** Local success + External failure = **Recoverable**

---

## Workshop Image Reference

This design directly implements the concepts from your workshop Miro board:

**Red Arrow (Start Transaction):**
- Visualization: Red arrow from "New Dispo" to "New Dispo DB"
- Meaning: Local transaction starts BEFORE calling TMS
- Implementation: Outbox entry creation in local transaction

**Synchronize to TMS:**
- Visualization: Arrow from "New Dispo" to "TMS Bridge" AFTER local commit
- Meaning: TMS call happens after local state is safe
- Implementation: Outbox processor executing TMS operation

**Yellow Boxes (Solution Progression):**
- Box 3: "User-retry based, on locally pending changes, resolving"
- Our solution: Outbox = "locally pending changes"
- User can retry from outbox entries

**Scenario 2 Diagram:**
- Shows: "TMS updated, New Dispo not updated" → DATA OUT OF SYNC
- Our fix: Outbox ensures "New Dispo updated FIRST" → TMS is secondary
- If TMS fails: Retry from outbox (no data loss)

---

## Summary

The **red arrow** is not just a theoretical concept - it's a concrete architectural principle:

✅ **Commit local intent atomically**
✅ **Call external systems asynchronously**
✅ **Retry from persistent local state**

This is exactly what the **Transactional Outbox Pattern** provides, and our simplified version makes it achievable for the June go-live.
