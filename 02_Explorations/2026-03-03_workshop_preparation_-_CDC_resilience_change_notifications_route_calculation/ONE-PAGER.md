# Workshop One-Pager - Architecture

**GoLive:** June 1 (90 days) | **Patrick's Must-Haves:** Grobavise + Change indicator + CDC resilience

---

## Topic 1: CDC Error Handling

**Problem:**
- `ConsumeEventCommandHandler.cs:53-57` returns HTTP 200 even on failure
- Pub/Sub sees 200 → acknowledges message → never retries → **event lost forever**
- Production: Jan 30 incident, 7 days lag, 422 GB backlog

**Fix:**
- Return HTTP 503 on failure → Pub/Sub retries → DLQ after max retries
- Add idempotency checks in handlers

**Decision:** Do it? Or accept data loss?

---

## Topic 2: Change Notifications

**Problem:**
- UI polls or user manually refreshes
- No real-time updates

**Fix:**
- SignalR: Backend hub + Frontend service
- CDC success → hub.SendAsync("DataChanged") → UI shows badge → user refreshes

**Decision:** In scope for GoLive?

---

## Topic 3: Route Calculation

**Ownership:**
- **P3:** New Dispo Frontend, Backend, TMS Bridge
- **Nagel:** TMS Database, TOP Service, PTV xServer

**Interface (P3 uses):**
- `pdis_transportorder.getxserverdto(to_tix, dplanningdate)` → returns PoolDTO

**Flow (New Dispo Backend orchestrates):**
```
1. Get PoolDTO from TMS Database (via TMS Bridge)
2. HTTP POST PoolDTO to TOP Service (Nagel)
3. TOP Service → xServer → returns calculated PoolDTO
4. Write PoolDTO back to TMS Database (via TMS Bridge)
```

**P3 Status:** ✓ Integration with TMS Database interface works

**Network:** ✓ Already set up (not a blocker)

**Issues:** Calculation quality in TMS Database + TOP Service (Nagel's domain)
- PoolDTO mapping logic (TMS DB)
- xServer request/response mapping (TOP Service)
- Master data quality (Verweildauern, opening hours, LKW profiles)

**Decision:** What calculation quality problems exist? What must work by June 1?

---

## Questions to Ask

**CDC:**
1. Acceptable data loss rate?
2. Operator capacity for manual DLQ replay?

**Notifications:**
1. Must-have or nice-to-have for GoLive?
2. Coarse-grained (just "new data") enough?

**Route Calc:**
1. What calculation quality issues exist today?
2. Where is P3's integration responsibility vs Nagel's calculation domain?
3. Master data - who validates quality?
4. What must work by June 1?
5. Debugging access to TOP Service logs?

---

## Recommendations

| Topic | Recommendation | Reason |
|-------|---------------|--------|
| CDC | Fix it | Data loss unacceptable for production |
| Notifications | Do it | Meets Patrick's requirement, low risk |
| Route Calc | Clarify responsibility boundaries | P3 integration works, focus on calculation quality |

---

## Code References

**CDC Error:**
- `Code/Disposition-Backend/.../CDC/Requests/ConsumeEvent/ConsumeEventCommandHandler.cs:28-60`

**Top-Down Sync:**
- `Code/Disposition-Backend/.../TransportOrderPlanning/Requests/AssignLegToTransportOrder/AssignLegToTransportOrderCommandHandler.cs:47-130`

**SignalR Foundation:**
- `02_Explorations/2026-01-28-signalr-foundation.md`

**TMS Bridge Interface:**
- `Code/Disposition-Abstraction-Layer/.../GraphQL/Queries/GetXserverDtoQuery/GetXserverDtoQuery.cs:15-40`
- Function: `pdis_transportorder.getxserverdto`

**TMS Database:**
- `Code/tms-alloydb-schema/src/sql/package/PDIS_TRANSPORTORDER.sql:343-365`

**Route Calc Background:**
- `02_Explorations/2025-07-28_TOP_xServer_integration_refinement.md`

**CDC Analysis:**
- `02_Explorations/2026-03-03_cdc-sync-and-error-scenarios/cdc-sync-and-error-scenarios.md`
