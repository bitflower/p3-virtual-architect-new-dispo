# Transactional Resilience: Solution Flow Diagrams

**Date:** 2026-03-25
**Status:** Technical Documentation
**Related:** `concept-transactional-resilience.md`

---

## 1. Current Problem: Scenario 2 (TMS Success, Local DB Failure)

```mermaid
sequenceDiagram
    autonumber
    participant U as User
    participant BE as New Dispo<br/>Backend
    participant NDB as New Dispo DB
    participant TB as TMS Bridge
    participant TMS as TMS Database

    U->>BE: Create Transport Order<br/>(drag & drop lot)

    Note over BE,TMS: WARNING: NO LOCAL TRANSACTION YET

    BE->>TB: createTransportOrderFromLeg()<br/>(company, branch, shipmentId, date)
    TB->>TMS: Execute SQL INSERT
    TMS-->>TB: Success<br/>transportOrderId: 987654<br/>legId: 333
    TB-->>BE: Return IDs

    Note over BE: Backend has TMS IDs<br/>but not yet saved locally

    BE->>NDB: BEGIN TRANSACTION
    BE->>NDB: INSERT LotAssignment<br/>(transportOrderId: 987654)
    NDB--xBE: [X] FAILURE<br/>(DB timeout / unavailable)

    rect rgb(255, 230, 230)
        Note over BE,TMS: ERROR: DATA INCONSISTENCY<br/><br/>[OK] TMS: transport order 987654 exists<br/>[X] New Dispo: no LotAssignment<br/><br/>IRRECOVERABLE
    end

    BE-->>U: [X] 500 Internal Server Error
    Note over U: User sees error<br/>No retry option<br/>Cannot recover
```

**Root Cause:** External system (TMS) called BEFORE local transaction committed. If local save fails, TMS changes cannot be rolled back.

---

## 2. Minimal Outbox Solution: Happy Path

```mermaid
sequenceDiagram
    autonumber
    participant U as User
    participant BE as New Dispo<br/>Backend
    participant NDB as New Dispo DB
    participant TB as TMS Bridge
    participant TMS as TMS Database

    U->>BE: Create Transport Order<br/>(drag & drop lot)

    rect rgb(255, 220, 220)
        Note over BE,NDB: [TX1] TRANSACTION 1: PERSIST USER INTENT
        BE->>NDB: BEGIN TRANSACTION
        BE->>NDB: INSERT INTO TmsSyncOutbox<br/>OperationType: 'CreateTransportOrder'<br/>Payload: {lotId, legs, date, ...}<br/>Status: 'Pending'<br/>TmsResponse: NULL
        BE->>NDB: COMMIT TRANSACTION
        NDB-->>BE: Committed (OutboxId: abc-123)
        Note over BE,NDB: USER INTENT NOW SAFE<br/>Cannot be lost
    end

    BE-->>U: 202 Accepted<br/>{outboxId: 'abc-123'}
    Note over U: "Creating transport order..."

    BE->>NDB: UPDATE TmsSyncOutbox<br/>SET Status='Processing'<br/>WHERE Id='abc-123'

    rect rgb(220, 240, 255)
        Note over BE,TMS: [EXTERNAL] EXTERNAL CALL (Outside transaction)
        BE->>TB: createTransportOrderFromLeg()<br/>(parameters from Payload)
        TB->>TMS: Execute SQL INSERT
        TMS-->>TB: Success<br/>transportOrderId: 987654<br/>legId: 333
        TB-->>BE: Return IDs
    end

    rect rgb(220, 255, 220)
        Note over BE,NDB: [TX2] TRANSACTION 2: COMPLETE BUSINESS LOGIC
        BE->>NDB: BEGIN TRANSACTION
        BE->>NDB: INSERT LotAssignment<br/>(transportOrderId: 987654)
        BE->>NDB: DELETE Lot (from unplanned)
        BE->>NDB: UPDATE TmsSyncOutbox<br/>SET Status='Completed'<br/>TmsResponse: {transportOrderId: 987654, ...}<br/>CompletedAt: NOW()
        BE->>NDB: COMMIT TRANSACTION
        NDB-->>BE: Committed
    end

    BE-->>U: [OK] 200 OK<br/>{transportOrderId: 987654}
    Note over U: "Transport order created"
```

**Key Innovation:** User intent persisted in Transaction 1 BEFORE calling TMS. All subsequent failures are recoverable.

---

## 3. Failure Scenario A: TMS Call Fails

```mermaid
sequenceDiagram
    autonumber
    participant U as User
    participant BE as New Dispo<br/>Backend
    participant NDB as New Dispo DB
    participant TB as TMS Bridge
    participant TMS as TMS Database

    Note over U,TMS: User has already triggered creation<br/>Outbox entry exists (Status: 'Processing')

    BE->>TB: createTransportOrderFromLeg()
    TB->>TMS: Execute SQL
    TMS--xTB: [X] Timeout / Network Error
    TB--xBE: [X] GraphQL Error

    BE->>NDB: UPDATE TmsSyncOutbox<br/>SET Status='Failed'<br/>ErrorMessage='TMS timeout'<br/>AttemptCount=1

    rect rgb(255, 250, 220)
        Note over BE,NDB: STATE: OUTBOX STATE:<br/>Status: Failed<br/>Payload: {lotId, legs, ...}<br/>TmsResponse: NULL<br/><br/>[OK] Can retry TMS call
    end

    BE-->>U: [X] 500 Error<br/>+ [Retry Button]<br/>{outboxId: 'abc-123'}

    Note over U: User sees error dialog<br/>with retry option
```

**Recovery Path:** User clicks retry → Backend reads Payload from outbox → Retries TMS call with same parameters.

---

## 4. Failure Scenario B: Local DB Save Fails After TMS Success

```mermaid
sequenceDiagram
    autonumber
    participant U as User
    participant BE as New Dispo<br/>Backend
    participant NDB as New Dispo DB
    participant TB as TMS Bridge
    participant TMS as TMS Database

    Note over U,TMS: TMS call succeeded<br/>Backend received transportOrderId: 987654

    BE->>NDB: BEGIN TRANSACTION
    BE->>NDB: INSERT LotAssignment<br/>(transportOrderId: 987654)
    NDB--xBE: [X] Database Unavailable

    Note over BE: Transaction failed<br/>BUT TmsResponse is in memory

    BE->>NDB: UPDATE TmsSyncOutbox<br/>SET Status='Failed'<br/>TmsResponse: {transportOrderId: 987654, ...}<br/>ErrorMessage='Local DB save failed'

    rect rgb(220, 255, 220)
        Note over BE,NDB: STATE: OUTBOX STATE:<br/>Status: Failed<br/>Payload: {lotId, legs, ...}<br/>TmsResponse: {transportOrderId: 987654, ...}<br/><br/>[OK] TMS response preserved!<br/>[OK] Can complete local save on retry
    end

    BE-->>U: [X] 500 Error<br/>+ [Retry Button]<br/>{outboxId: 'abc-123'}
```

**Critical Feature:** TmsResponse stored in outbox BEFORE failing. Retry will NOT call TMS again (idempotent).

---

## 5. Failure Scenario C: Network Interruption (Response Lost)

```mermaid
sequenceDiagram
    autonumber
    participant U as User
    participant BE as New Dispo<br/>Backend
    participant NDB as New Dispo DB
    participant TB as TMS Bridge
    participant TMS as TMS Database

    Note over U,TMS: Outbox entry exists (Status: 'Processing')

    BE->>TB: createTransportOrderFromLeg()
    TB->>TMS: Execute SQL
    TMS-->>TB: [OK] Success<br/>transportOrderId: 987654

    rect rgb(255, 240, 240)
        Note over TB,BE: ERROR: NETWORK FAILURE<br/>Response lost in transit
        TB--xBE: [X] Connection timeout
    end

    Note over BE: Backend doesn't know:<br/>Did TMS succeed or fail?<br/>No TmsResponse received

    BE->>NDB: UPDATE TmsSyncOutbox<br/>SET Status='Failed'<br/>ErrorMessage='TMS Bridge timeout'<br/>TmsResponse: NULL<br/>AttemptCount=1

    rect rgb(255, 250, 220)
        Note over BE,TMS: WARNING: UNCERTAIN STATE<br/><br/>[OK] TMS: transport order 987654 EXISTS<br/>[X] Backend: no TmsResponse<br/>[X] New Dispo: no LotAssignment<br/><br/>STATE: OUTBOX STATE:<br/>Status: Failed<br/>Payload: {lotId, legs, ...}<br/>TmsResponse: NULL<br/><br/>WARNING: Must query TMS before retry<br/>to avoid duplicates
    end

    BE-->>U: [X] 500 Error<br/>+ [Retry Button]<br/>{outboxId: 'abc-123'}

    Note over U: User sees error<br/>Cannot know if TO was created<br/>Must retry with idempotency check
```

**Critical Challenge:** TMS operation may have succeeded, but backend has no proof. Retry MUST query TMS first to detect existing transport order.

**Recovery Path:** User clicks retry → Backend reads Payload → Queries TMS for existing TO → Uses existing or creates new.

---

## 6. Retry Flow: Idempotent Recovery

```mermaid
sequenceDiagram
    autonumber
    participant U as User
    participant BE as New Dispo<br/>Backend
    participant NDB as New Dispo DB
    participant TB as TMS Bridge
    participant TMS as TMS Database

    U->>BE: POST /api/transportorders/retry<br/>{outboxId: 'abc-123'}

    BE->>NDB: SELECT * FROM TmsSyncOutbox<br/>WHERE Id = 'abc-123'
    NDB-->>BE: Outbox Entry<br/>(Status: Failed, Payload, TmsResponse)

    alt TmsResponse EXISTS (Scenario B)
        rect rgb(220, 255, 220)
            Note over BE: TMS already succeeded<br/>Use stored IDs
            Note over BE,TMS: SKIP: SKIP TMS CALL<br/>(idempotent)
        end

        BE->>NDB: BEGIN TRANSACTION
        BE->>NDB: INSERT LotAssignment<br/>(transportOrderId from TmsResponse)
        BE->>NDB: UPDATE TmsSyncOutbox<br/>Status='Completed'
        BE->>NDB: COMMIT TRANSACTION

    else TmsResponse IS NULL (Scenario A or C)
        rect rgb(220, 240, 255)
            Note over BE,TMS: [EXTERNAL] CHECK TMS STATE<br/>(idempotency query)<br/><br/>Critical for Scenario C:<br/>TMS may have succeeded
            BE->>TB: queryTransportOrderByShipment()<br/>(company, branch, performanceDate,<br/>shipmentId, legType from Payload)
            TB->>TMS: SELECT transportorder_id<br/>WHERE shipment_id = X<br/>AND performance_date = Y<br/>AND leg_type = Z

            alt Transport Order EXISTS in TMS
                TMS-->>TB: Found: transportOrderId 987654
                TB-->>BE: Existing record
                Note over BE: Use existing TMS IDs<br/>(Scenario C: duplicate detected!)

            else Transport Order NOT in TMS
                TMS-->>TB: Not found
                TB-->>BE: NULL
                Note over BE: Safe to create new<br/>(Scenario A: TMS never called)
                BE->>TB: createTransportOrderFromLeg()<br/>(from Payload)
                TB->>TMS: Execute SQL
                TMS-->>TB: [OK] transportOrderId: 123456
                TB-->>BE: New order created
            end
        end

        BE->>NDB: BEGIN TRANSACTION
        BE->>NDB: INSERT LotAssignment<br/>(transportOrderId)
        BE->>NDB: UPDATE TmsSyncOutbox<br/>Status='Completed'<br/>TmsResponse: {transportOrderId, ...}
        BE->>NDB: COMMIT TRANSACTION
    end

    BE-->>U: [OK] 200 OK<br/>{transportOrderId}
    Note over U: [OK] "Transport order created"
```

**Idempotency Guarantee:** System checks TmsResponse first, queries TMS if needed (critical for Scenario C), ensures no duplicate transport orders.

---

## 7. Outbox State Machine

```mermaid
stateDiagram-v2
    [*] --> Pending: User triggers operation<br/>(Outbox entry created)

    Pending --> Processing: Backend starts TMS call<br/>(AttemptCount++)

    Processing --> Completed: Success path<br/>(TmsResponse stored,<br/>LotAssignment created)
    Processing --> Failed: TMS failure OR<br/>Local DB failure<br/>(ErrorMessage stored)

    Failed --> Processing: User clicks Retry<br/>(AttemptCount++)
    Failed --> ManualReview: Support intervention<br/>(AttemptCount >= 3)

    ManualReview --> Completed: Support resolves<br/>(Manual fix applied)
    ManualReview --> [*]: Support cancels<br/>(Marked as resolved)

    Completed --> [*]: Cleanup job<br/>(After 30 days)

    note right of Pending
        Status: 'Pending'
        Payload: {...}
        TmsResponse: NULL
        AttemptCount: 0
    end note

    note right of Processing
        Status: 'Processing'
        Payload: {...}
        TmsResponse: NULL or {...}
        AttemptCount: 1+
    end note

    note right of Failed
        Status: 'Failed'
        Payload: {...}
        TmsResponse: NULL or {...}
        ErrorMessage: "..."
        AttemptCount: 1+
    end note

    note right of Completed
        Status: 'Completed'
        Payload: {...}
        TmsResponse: {...}
        CompletedAt: timestamp
    end note
```

---

## 8. Decision Tree: Retry Logic

```mermaid
flowchart TD
    Start([User clicks Retry]) --> LoadOutbox[Load Outbox Entry<br/>by OutboxId]

    LoadOutbox --> CheckTmsResponse{TmsResponse<br/>exists?}

    CheckTmsResponse -->|YES| UseStored[Use stored TMS IDs<br/>Skip TMS call]
    CheckTmsResponse -->|NO| QueryTms[Query TMS:<br/>Does TO exist for<br/>shipmentId + date + legType?]

    QueryTms --> TmsExists{TO found<br/>in TMS?}

    TmsExists -->|YES| UseExisting[Use existing TO IDs<br/>from TMS query]
    TmsExists -->|NO| CreateNew[Create new TO<br/>Call TMS Bridge]

    UseStored --> SaveLocal[BEGIN TRANSACTION<br/>INSERT LotAssignment<br/>UPDATE Outbox Status='Completed'<br/>COMMIT]
    UseExisting --> SaveLocal
    CreateNew --> SaveLocal

    SaveLocal --> Success{Save<br/>successful?}

    Success -->|YES| Return200[Return 200 OK<br/>to user]
    Success -->|NO| UpdateFailed[UPDATE Outbox<br/>Status='Failed'<br/>AttemptCount++]

    UpdateFailed --> Return500[Return 500 Error<br/>+ Retry Button]

    Return200 --> End([End])
    Return500 --> End

    style CheckTmsResponse fill:#ffe6e6
    style TmsExists fill:#e6f3ff
    style Success fill:#e6ffe6
```

---

## 9. Comparison: Before vs After

### Before (Current Implementation)

```mermaid
sequenceDiagram
    participant U as User
    participant BE as Backend
    participant TMS
    participant NDB as New Dispo DB

    U->>BE: Create TO
    BE->>TMS: [OK] Execute
    TMS-->>BE: [OK] Success
    BE->>NDB: [X] Save fails

    Note over U,NDB: ERROR: OUT OF SYNC<br/>No recovery
```

### After (Minimal Outbox)

```mermaid
sequenceDiagram
    participant U as User
    participant BE as Backend
    participant NDB as New Dispo DB
    participant TMS

    U->>BE: Create TO
    BE->>NDB: [OK] Save outbox
    BE->>TMS: Call TMS
    TMS-->>BE: Success/Failure
    BE->>NDB: Save business logic

    Note over U,NDB: [OK] RECOVERABLE<br/>User can retry
```

---

## 10. Key Architectural Decisions

| Decision | Rationale | Trade-off |
|----------|-----------|-----------|
| **Table-based outbox** | Workshop decision: "need to store this information anyway somewhere" (transcript line 2398). Provides audit trail, query capability, support dashboard. | More complex than log files, but enables retry and reconciliation. |
| **User-initiated retry** | Patrick approval (Workshop 2026-03-19): "manual step for the user... could be feasible" (transcript lines 1141-1177). | Simpler implementation, fits June timeline. Users must manually trigger recovery. |
| **TmsResponse storage** | Enables idempotency when TMS succeeds but local DB fails. Critical for Scenario B. | Requires JSONB field, adds storage overhead. |
| **Application-level idempotency** | TMS Bridge doesn't support idempotency keys yet. Use TMS query as fallback. | Requires TMS query endpoint, more complex retry logic. |
| **Status state machine** | Clear visibility for support team, enables monitoring and alerting. | Requires state transitions to be carefully managed. |

---

## 11. Summary

The **Minimal Outbox Solution** inverts the risk model:

| Aspect | Old Approach | Minimal Outbox |
|--------|-------------|----------------|
| **Transaction Start** | No local persistence | [OK] Outbox entry created first |
| **External Call** | Before local save | [OK] After outbox committed |
| **Failure Recovery** | [X] Manual SQL fixes | [OK] User retry button |
| **Data Consistency** | [X] Can desync | [OK] Eventually consistent |
| **Support Burden** | [X] High (manual fixes) | [OK] Low (automated retry) |
| **Audit Trail** | [X] None | [OK] Full history in outbox |

**Core Principle:** Commit local intent atomically BEFORE calling external systems.
