# Proposed Solutions - Workshop

## 1. CDC Error Handling - Proposed Fix

```mermaid
flowchart TD
    A[TMS Database<br/>Sendung table changes] --> B[Google Datastream CDC]
    B --> C[Google Cloud Storage Bucket]
    C --> D[Google Pub/Sub Topic]
    D -->|HTTP POST CloudEvent| E[New Dispo Backend<br/>/api/CDC/consume-event]
    E --> F[ConsumeEventCommandHandler.Handle]
    F --> G[Line 51: handler.Handle]
    G -->|Exception| H[catch block]
    H --> I[Log error<br/>return HTTP 503]
    I -->|HTTP 503| J[Pub/Sub receives 503]
    J --> K[Message NOT acknowledged]
    K --> L[Retry with exponential backoff]
    L -->|Success| M[Event processed ✓]
    L -->|Max retries| N[Dead Letter Queue]
    N --> O[Manual investigation<br/>and replay]

    style I fill:#4dabf7
    style L fill:#4dabf7
    style M fill:#51cf66
    style N fill:#ffd43b
    style O fill:#ffd43b
```

**Changes:**
1. Return HTTP 5xx on failure → Pub/Sub retries
2. Add idempotency check in handlers → Prevent duplicate processing
3. Configure DLQ → Preserve failed events

**Code Changes:**
- File: `ConsumeEventCommandHandler.cs:53-57`
- Change: Return `StatusCode(503)` instead of `Ok(result)` when `IsEventSuccess = false`
- Add: Idempotency check at start of each event handler
- Infra: Configure Pub/Sub DLQ topic

---

## 2. Change Notifications - SignalR Implementation

```mermaid
flowchart TD
    A[TMS Database changes] --> B[CDC]
    B --> C[New Dispo Backend<br/>processes event]
    C --> D[SaveChangesAsync]
    D --> E[Data updated ✓]
    E --> F[ConsumeEventCommandHandler<br/>line 51 success]
    F --> G[hubContext.Clients.All<br/>.SendAsync DataChanged]
    G -->|WebSocket SignalR| H[All connected clients<br/>receive notification]
    H --> I[Frontend SignalR service<br/>receives event]
    I --> J[Notification badge<br/>appears]
    J --> K[User clicks badge]
    K --> L[UI refreshes view]

    style E fill:#51cf66
    style G fill:#4dabf7
    style J fill:#ffd43b
    style L fill:#51cf66

    M[Result: Real-time notification, user sees change immediately]
    style M fill:#51cf66
```

**Components Needed:**
- Backend: `NotificationHub.cs`
- Frontend: `SignalR service`
- Integration: Hub call after CDC success
- UI: Notification badge component

**Implementation Steps:**
1. Add SignalR hub to backend (Startup.cs + NotificationHub.cs)
2. Install @microsoft/signalr in frontend
3. Create SignalR service in Angular
4. Inject hub context in ConsumeEventCommandHandler
5. Call hub.SendAsync after successful CDC processing
6. Create notification badge component in UI

**Reference:** `02_Explorations/2026-01-28-signalr-foundation.md`

---

## Summary

| Proposal | Risk | Status |
|----------|------|--------|
| CDC Error Fix | Medium | Recommended |
| SignalR Notifications | Low | Recommended |
