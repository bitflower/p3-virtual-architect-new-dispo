# Sync Conflict UX

**Date:** 2026-05-20
**Purpose:** Align on UX behavior for sync conflicts across all 7 transactional flows
**Audience:** Patrick, Max Kehder (POs), Matthias (facilitator)
**Scope:** What the user sees, what operations sees, what we need to decide

---

## How Sync Conflicts Work

New Dispo and TMS are two separate systems. When a user performs a transport order action, both systems must agree on the current state. Sometimes they don't.

**Before every action**, the Backend checks TMS for the real state. Two outcomes:

| Outcome | What Happens | User Experience |
|---------|-------------|-----------------|
| **Resolved conflict** | Backend detects mismatch, repairs New Dispo to match TMS, returns error | User sees a message, page refreshes with corrected data. User decides whether to repeat the action. |
| **Unresolved conflict** (Flow 7 only) | Backend cannot repair because the deleted TO is gone from the UI | User sees an error. Service desk must investigate and clean up manually. |

**The user never needs to "fix" anything.** The repair happens inline — when the user triggers an action and a mismatch is found, the Backend corrects the local data as part of that same request. There is no background job. The user only needs to understand that the world changed and re-evaluate their next action.

---

## The 7 Flows at a Glance

### Assign Flows (1-4): "I want to put legs/lots onto a Transport Order"

| # | Flow | Conflict means... | What user sees today | Severity |
|---|------|-------------------|---------------------|----------|
| 1 | **Create TO from Leg** | Leg is already on a TO in TMS | Error: "Leg already assigned to TO #X" + page refresh | Medium — user must pick a different leg or go to existing TO |
| 2 | **Create TO from Lot** | One or more legs in the lot are already assigned | Per-leg list: which legs have conflicts, which are free | Medium — user sees partial info, must re-evaluate lot |
| 3 | **Assign Leg to TO** | Leg is already on a TO | Two sub-cases (see below) | Low/Medium |
| 4 | **Assign Lot to TO** | One or more legs already assigned | Per-leg list with same-TO / different-TO distinction | Low/Medium |

**Flow 3 has a special case:**

| Sub-case | Meaning | Suggested severity |
|----------|---------|-------------------|
| Leg already on **this** TO | Action was already done — nothing to worry about | Low (info) |
| Leg on a **different** TO | Real conflict — leg belongs somewhere else | Medium (warning) |

Flow 4 has the same sub-case distinction per leg.

### Unassign Flows (5-6): "I want to remove legs/lots from a Transport Order"

| # | Flow | Conflict means... | What user sees today | Severity |
|---|------|-------------------|---------------------|----------|
| 5 | **Unassign Lots** | Some legs in the lot were already removed in TMS | Error per lot: "Conflict occurred" + page refresh | Low — mostly benign, legs are already gone |
| 6 | **Unassign Legs** | Some legs were already removed in TMS | Per-leg result: success / conflict / TMS failure | Low — already removed = effectively done |

**Partial success:** Flows 5 and 6 can have mixed results — some legs removed successfully, others had conflicts. The page refreshes and shows the corrected state.

### Delete Flow (7): "I want to delete a Transport Order"

| # | Flow | Conflict means... | What user sees today | Severity |
|---|------|-------------------|---------------------|----------|
| 7 | **Delete TO** | If TMS deletes but local cleanup fails: orphaned data | Generic error (no specific handling yet) | **High** — user loses context, manual cleanup needed |

Flow 7 is unique: the deleted TO disappears from the UI, so the user cannot retry. This is the only flow where service desk involvement is required.

---

## Decisions (PO, 2026-05-20)

### 1. Notification Style: 3 Severity Levels

| Severity | When | Style |
|----------|------|-------|
| **Info** | "Already done" — leg was already on this TO, lot already unassigned | Green toast, **auto-dismiss** per Figma |
| **Warning** | "Something changed" — leg is on a different TO, partial lot conflict | Yellow/orange toast, **stays until dismissed** |
| **Error** | "Something failed" — Flow 7 cleanup failure, TMS operation failed | Red toast, **stays until dismissed**, shows Log ID + copy button |

### 2. Incident ID: Error-Only

Log ID is shown **only for non-resolvable issues** (error severity). Resolvable conflicts (info/warning) are logged server-side only — no ID shown to the user.

### 3. Partial Success: Summary Toast Only

Single summary toast for batch operations: *"3 of 5 legs assigned. 2 had conflicts and were resolved automatically. Please refresh the page."*

No per-leg detail panel.

### 4. Flow 7 Toast: Transparent

*"Transport Order deleted. Some local data could not be cleaned up. Our team has been notified. Log ID: [Log ID]. This Log ID will no longer be accessible after dismissing this message."*

### 5. Same-TO vs. Different-TO: Distinguish

- Leg already on **this** TO → info level (benign)
- Leg on a **different** TO → warning level (show which TO if available)

### 6. Refresh Behavior: Manual

No auto-refresh. User refreshes the page manually after seeing the toast. (Overrides original parent #123326 AC2; parent updated.)

### 7. Message Style: Generic Template

Generic template with `[action name]` slot. Not flow-specific wording.

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
| Structured conflict logging (type, entities, action taken) | Not yet | Yes — replace generic `LogError` with structured fields |
| Log pairing for Flow 7 ("initiated" / "finished") | Not yet | Yes — enables proactive detection of orphaned deletions |
| Cloud alerting on unpaired Flow 7 events | Not yet | Yes — so operations doesn't rely on user reports |
| Recovery endpoint for orphaned assignments | Not yet (POC exists) | Yes — expose existing CDC recovery logic as callable endpoint |

---

## Summary: Minimal Building Blocks

| Building Block | Covers | Effort |
|---------------|--------|--------|
| Incident ID in error responses | All 7 flows | ~1 line backend code |
| Structured sync conflict logging | Flows 1-6 | Small backend change |
| Severity-based toast in Frontend | All 7 flows | Frontend UX work (needs PO input from this meeting) |
| Log pairing for deletions | Flow 7 | Small backend change |
| Recovery endpoint | Flow 7 | Reuse CDC POC logic |
| Cloud alert on unpaired deletions | Flow 7 | GCP config |

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
