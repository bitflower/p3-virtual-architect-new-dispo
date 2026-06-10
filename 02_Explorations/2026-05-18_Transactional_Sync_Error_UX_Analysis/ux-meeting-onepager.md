# Sync Conflict UX

**Date:** 2026-05-20 (PO Decisions) · 2026-05-21 (Team Refinement)
**Purpose:** Align on UX behavior for sync conflicts across all 7 transactional flows
**Audience:** Patrick, Max Kehder (POs), Matthias (facilitator), Dev Team
**Scope:** What the user sees, what operations sees, what we need to decide
**Tickets:** #124105 (BE — logging + error response) · #123950 (FE — toast UX)

---

## Revision History

| Date | Change | Source |
|------|--------|--------|
| 2026-06-10 | **AC 3 dropped:** Lot operations are atomic — no partial-leg outcomes. Individual-leg-from-slider (Flow 6) = one toast per leg, no summary needed. | Refinement feedback, #123950 |
| 2026-06-10 | **Unassign UX gap:** Flows 5+6 share one FE interaction but have no explicit toast requirements. | Refinement feedback, #123950 |
| 2026-06-10 | **FE action mapping added:** Maps FE interactions to Backend flows for implementability. | Derived from refinement feedback |
| 2026-06-10 | **"Partial lot conflict" corrected:** Lots are atomic — replaced with "lot-level conflict (all-or-nothing)". | Refinement feedback, #123950 |

---

## How Sync Conflicts Work

New Dispo and TMS are two separate systems. When a user performs a transport order action, both systems must agree on the current state. Sometimes they don't.

**Before every action**, the Backend checks TMS for the real state. Two outcomes:

| Outcome | What Happens | User Experience |
|---------|-------------|-----------------|
| **Resolved conflict** | Backend detects mismatch, repairs New Dispo to match TMS, returns error | User sees a message, refreshes page, re-evaluates. |
| **Unresolved conflict** (Flow 7 only) | Backend cannot repair because the deleted TO is gone from the UI | User sees an error. Service desk must investigate and clean up manually. |

**The user never needs to "fix" anything.** The repair happens inline — the Backend corrects the local data as part of the same request. There is no background job. The user only needs to understand that the world changed and re-evaluate their next action.

### Atomicity Guarantees

| Scope | Atomic? |
|-------|---------|
| TMS operations within one flow | **Yes** |
| New Dispo DB operations within one flow | **Yes** (single `SaveChangesAsync`) |
| Cross-system (TMS + New Dispo together) | **No** — this is the out-of-sync case |

It will **never** happen that 3 of 5 legs in a lot are unassigned in New Dispo while 2 are not. The out-of-sync state is always all-or-nothing per system.

**"Non-recoverable" means per-request:** non-recoverable within this request including internal Polly retries. If the user tries again later and succeeds, that's a new iteration with a green toast.

---

## The 7 Flows at a Glance

**Note:** Lot is a New Dispo Backend concept only. TMS Bridge and TMS Database have no knowledge of lots. The Backend maps lot → legs before calling TMS Bridge.

### Assign Flows (1-4): "I want to put legs/lots onto a Transport Order"

| # | Flow | Conflict means... | What user sees today | Severity |
|---|------|-------------------|---------------------|----------|
| 1 | **Create TO from Leg** | Leg is already on a TO in TMS | Error: "Leg already assigned to TO #X" + page refresh | Medium — user must pick a different leg or go to existing TO |
| 2 | **Create TO from Lot** | One or more legs in the lot are already assigned | Per-leg list: which legs have conflicts, which are free | Medium — user sees partial info, must re-evaluate lot |
| 3 | **Assign Leg to TO** | Leg is already on a TO | Two sub-cases (see below) | Low/Medium |
| 4 | **Assign Lot to TO** | One or more legs already assigned | Per-leg list with same-TO / different-TO distinction | Low/Medium |

**Flow 3 has a special case:**

| Sub-case | Meaning | Severity |
|----------|---------|----------|
| Leg already on **this** TO | Action was already done — nothing to worry about | Info (green, auto-dismiss) |
| Leg on a **different** TO | Real conflict — leg belongs somewhere else | Warning (orange, stays) |

Flow 4 has the same sub-case distinction per leg.

### Unassign Flows (5-6): "I want to remove legs/lots from a Transport Order"

| # | Flow | Conflict means... | What user sees today | Severity |
|---|------|-------------------|---------------------|----------|
| 5 | **Unassign Lots** | Some legs in the lot were already removed in TMS | Error per lot: "Conflict occurred" + page refresh | Low — already done, legs are already gone |
| 6 | **Unassign Legs** | Some legs were already removed in TMS | Per-leg result: success / conflict / TMS failure | Low — already removed = effectively done |

**Partial success** applies only when individual legs are selected from the drive instructions slider — each selected leg is a separate Backend request, producing separate toasts. Lot operations are atomic: one operation = one toast. There is no per-leg partial state within a lot operation.

### Delete Flow (7): "I want to delete a Transport Order"

| # | Flow | Conflict means... | What user sees today | Severity |
|---|------|-------------------|---------------------|----------|
| 7 | **Delete TO** | If TMS deletes but local cleanup fails: orphaned data | Generic error (no specific handling yet) | **High** — user loses context, manual cleanup needed |

Flow 7 is unique: the deleted TO disappears from the UI, so the user cannot retry. Delete TO is one atomic operation = one toast, even though it internally unassigns all legs. This is the only flow where service desk involvement is required.

---

## Decisions (PO, 2026-05-20 · confirmed by team 2026-05-21)

### 1. Notification Style: 3 Severity Levels

| Severity | When | Style |
|----------|------|-------|
| **Info** | "Already done" — leg was already on this TO, lot already unassigned | Green toast, **auto-dismiss** per Figma |
| **Warning** | "Something changed" — leg is on a different TO, ~~partial lot conflict~~ **lot-level conflict** (atomic, all-or-nothing) | Yellow/orange toast, **stays until dismissed** |
| **Error** | "Something failed" — Flow 7 cleanup failure, TMS operation failed | Red toast, **stays until dismissed**, shows Log ID + copy button |

### 2. Incident ID: Error-Only

Log ID is shown **only for non-resolvable issues** (error severity). Resolvable conflicts (info/warning) are logged server-side only — no ID shown to the user.

Incident ID format: cryptic UUID/hex is acceptable. The Frontend provides a copy-paste button — users never need to read or type the ID. One fresh ID per request, no correlation across retries. Use existing GCP Cloud Run log for filtering — no dedicated log sink needed.

### 3. ~~Partial Success: Summary Toast Only~~ Partial Success: One Toast Per Request

~~Single summary toast for batch operations: *"3 of 5 legs assigned. 2 had conflicts and were resolved automatically. Please refresh the page."*~~

~~No per-leg detail panel. This summary applies only to the individual-leg-from-slider scenario where the Frontend fires multiple independent Backend requests. Lot operations are atomic — one operation = one toast.~~

**Iteration 2 (2026-06-10):** Lot operations are atomic (all-or-nothing) — there is no scenario where some legs in a lot succeed and others fail within a single operation. The individual-leg-from-slider scenario (Flow 6) fires one Backend request per leg, each producing its own toast. No summary aggregation is needed — the user sees one toast per leg result.

### 4. Flow 7 Toast: Transparent

*"Transport Order deleted. Some local data could not be cleaned up. Our team has been notified. Log ID: [Log ID]. This Log ID will no longer be accessible after dismissing this message."*

### 5. Same-TO vs. Different-TO: Distinguish

- Leg already on **this** TO → info level (already done)
- Leg on a **different** TO → warning level (show which TO if available)

### 6. Refresh Behavior: Manual

No auto-refresh. User refreshes the page manually after seeing the toast. (Overrides original parent #123326 AC2; parent updated.)

### 7. Message Style: Generic Template

Generic template with `[action name]` slot. Not flow-specific wording. Action names: "assign leg", "assign lot", "create transport order", "unassign leg", "unassign lot", "delete transport order".

---

## Ticket Status

### #124105 — [BE] Log Dispo<->TMS transactional issues and return proper response

**State:** To Refine | **Effort:** 1.5 (predates scope expansion — worth re-estimating)

| AC | Scope |
|----|-------|
| AC 1 | Incident ID in all sync conflict responses (`HttpContext.TraceIdentifier`) |
| AC 2 | Structured sync conflict logging (incidentId, conflictType, affectedEntity, transportOrderId, actionTaken, flowName) |
| AC 3 | Unified error response shape (replacing 3 inconsistent contracts) |
| AC 4 | Log pairing for Flow 7 ("deletion initiated" / "deletion finished") |

### #123950 — [FE] Implement Transactional Issue Communication with user

**State:** To Refine | **Depends on:** #124105

| AC | Scope |
|----|-------|
| AC 1 | Info toast — "already done" conflicts (green, auto-dismiss) |
| AC 2 | Warning toast — real conflicts (orange, stays until dismissed) |
| ~~AC 3~~ | ~~Batch summary toast (Flows 2, 4, 5, 6)~~ **Dropped (Iteration 2)** — lot operations are atomic, individual legs = one toast per request |
| AC 4 | Error toast — non-resolvable (red, Log ID + copy button) |
| AC 5 | Same-TO vs. Different-TO distinction (Flows 3, 4) |
| AC 6 | General behavior (manual refresh, generic template, no auto-retry) |

**Iteration 2 — Gaps (2026-06-10):**

- **Unassign flows (5+6) covered under AC 1/AC 2.** Both are triggered via the same FE interaction (removing items from a TO). Unassign sync conflicts are already done (already removed in TMS) → info level (AC 1). If reassigned to different TO → warning level (AC 2). No separate AC needed — AC 1 and AC 2 examples updated to include unassign scenarios.
- **FE action → Backend flow mapping needed.** The 7 Backend flows map to fewer FE interactions:

| FE Action | Backend Flow(s) | Toast Behavior |
|-----------|----------------|----------------|
| Create TO (from leg) | Flow 1 | AC 1 or AC 2 (single toast) |
| Create TO (from lot) | Flow 2 | AC 1 or AC 2 (single toast, atomic) |
| Assign leg to TO | Flow 3 | AC 1 (same TO) or AC 2 (different TO), per AC 5 |
| Assign lot to TO | Flow 4 | AC 1 (same TO) or AC 2 (different TO), per AC 5 |
| Unassign from TO (slider) | Flow 5 (lots) + Flow 6 (legs) | **Gap: no AC.** One toast per request. Mostly info level. |
| Delete TO | Flow 7 | AC 4 (error toast with Log ID) |

---

## Operations / Service Desk View

### What Happens on a Conflict (Flows 1-6)

```
User action
  → Backend checks TMS state
    → Mismatch detected
      → Backend repairs local database (inline, same request)
      → Backend logs: conflict type, affected entities, incident ID
      → Backend returns error to Frontend
        → User sees toast, page refreshes
        → User re-evaluates and optionally repeats action
```

**Operations does not need to act.** The repair happens during the user's request — no background process, no manual intervention. Logs are available for auditing and trend analysis.

### What Happens on a Flow 7 Failure

```
User deletes TO
  → TMS deletes TO successfully
    → Local cleanup fails (crash, timeout, network)
      → Backend logs: "deletion initiated" event WITHOUT matching "deletion finished" event
      → User sees error toast with incident ID
      → Orphaned leg/lot assignments remain in New Dispo database
```

**Operations must act:**
1. **Detection:** Cloud logging alert on unpaired deletion events (initiated without finished)
2. **Investigation:** Search logs by incident ID — find transport order ID, affected legs
3. **Resolution:** Trigger recovery endpoint (reuses existing CDC recovery logic) to clean up orphaned assignments

### Logging — What's There vs. What's Needed

| Capability | Current state | Needed for Go-Live |
|------------|--------------|-------------------|
| Incident ID in error response | Not yet | Yes — use existing ASP.NET `TraceIdentifier` (~1 line of code) |
| Structured conflict logging (type, entities, action taken) | Not yet | Yes — prefix like "transaction issue" + incident ID + entity IDs |
| Log pairing for Flow 7 ("initiated" / "finished") | Not yet | Yes — enables proactive detection of orphaned deletions |
| Cloud alerting on unpaired Flow 7 events | Not yet | Yes — so operations doesn't rely on user reports |
| Recovery endpoint for orphaned assignments | Not yet (POC exists) | Yes — expose existing CDC recovery logic as callable endpoint |

### Known Limitations

- **Backend crash**: If the Backend process itself crashes (not just a TMS or DB failure), there will be no incident ID in the response and no structured log entry. Manual cloud log investigation is the fallback. Scoped out for now.
- **Figma multi-entity designs**: Current Figma designs (Mehmet) cover single-entity scenarios only. Don't block on this — build simplest version first.

---

## Summary: Minimal Building Blocks

| Building Block | Covers | Ticket | Effort |
|---------------|--------|--------|--------|
| Incident ID in error responses | All 7 flows | #124105 AC 1 | ~1 line backend code |
| Structured sync conflict logging | Flows 1-6 | #124105 AC 2 | Small backend change |
| Unified error response shape | All 7 flows | #124105 AC 3 | Backend — agree shape with FE team |
| Log pairing for deletions | Flow 7 | #124105 AC 4 | Small backend change |
| Severity-based toast in Frontend | All 7 flows | #123950 AC 1-5 | Frontend UX work |
| Recovery endpoint | Flow 7 | TBD | Reuse CDC POC logic |
| Cloud alert on unpaired deletions | Flow 7 | TBD | GCP config |

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
