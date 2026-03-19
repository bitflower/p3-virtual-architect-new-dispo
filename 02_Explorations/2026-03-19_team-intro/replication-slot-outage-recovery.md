# Replication Slot Outage Recovery: Legacy DB to Object Store Sync

---

## Business Context

**Critical Challenge:**
Single-table CDC sync from Legacy DB (PostgreSQL/Oracle) to Object Store (GCS) with **1-hour replication slot retention window**.

**The Problem:**
- Replication slot (WAL) has 1-hour buffer before logs are purged
- Network outage > 1 hour = gap in data stream
- When slot expires: connection lost, changes missed, manual recovery required

**Current Risk:**
→ Upstream gap between Legacy DB and Object Store when connection breaks longer than retention window

**Business Impact:**
- Data loss in downstream analytics/reporting
- Manual intervention required for recovery
- No automated self-healing mechanism

---

## Implementation Options

### 1. High-Water Mark (HWM) Recovery

**Manual/scripted recovery using last known timestamp or ID.**

- **How:** Identify latest `updated_at` timestamp or `ID` in Object Store, query Legacy DB for `WHERE timestamp > [Last_Successful_Timestamp]`, upload delta
- **Pros:** Very low complexity, no schema changes, perfect for single-table focus
- **Cons:** Requires reliable indexed incrementing column (ID or timestamp)
- **Best for:** Quick wins, single-table scenarios

### 2. Transactional Outbox (The "Bulletproof" Fix)

**Persistent table-based buffer that bypasses replication slot limitation.**

- **How:** Create `sync_outbox` table in Legacy DB, database trigger records PK of every changed row, sync tool reads from outbox table instead of replication slot
- **Pros:** Completely immune to 1-hour WAL/slot limit, guaranteed delivery, data persists indefinitely
- **Cons:** Requires schema change, adds write overhead to Legacy DB
- **Best for:** Mission-critical tables requiring 100% data integrity

### 3. Storage-Based Reconciliation ("Anti-Entropy")

**Background safety net ensuring Object Store eventually matches Legacy DB.**

- **How:** Scheduled job (every 6-12 hours) compares row count/checksum between Legacy table and Object Store
- **Fix:** Discrepancy detected → automated "Gap-Fill" upload for specific time range
- **Pros:** Automated self-healing, catches silent failures, hands-off long-term consistency
- **Cons:** Complex comparison logic for high-volume tables
- **Best for:** Long-term operational resilience without manual monitoring

### 4. Checkpoint & Manifest Pattern

**Detection system that identifies exactly when gaps occur.**

- **How:** Sync tool writes `manifest.json` to Object Store with last processed LSN/timestamp after each batch
- **Fix:** On restart, read manifest; if required logs deleted → automated alert triggers HWM recovery
- **Pros:** High observability, prevents silent data loss
- **Cons:** Detection only, does not fix gap automatically
- **Best for:** Essential for knowing when gap happened, combines well with Option 1

---

## Implementation Comparison

| Strategy | Solves 1-Hour Limit? | Complexity | Recommended For |
|----------|---------------------|------------|-----------------|
| **High-Water Mark** | Yes (Manual/Scripted) | Low | Easiest to implement for single table |
| **Outbox Table** | **Yes (Fully)** | High | Mission-critical table, 100% integrity |
| **Reconciliation** | Yes (Automated) | Medium | Hands-off, long-term consistency |
| **Manifests** | No (Detection only) | Low | Essential for gap detection |

---

## Challenges

- **Incrementing Column Requirement:** HWM requires reliable `updated_at` timestamp or auto-incrementing ID
- **Schema Changes:** Outbox pattern requires DBA approval and Legacy DB modification
- **Write Overhead:** Outbox triggers add performance impact to Legacy DB
- **Comparison Logic:** Reconciliation needs efficient checksum/comparison for high-volume scenarios

---

## Action Required

**IMPORTANT:** This analysis applies to **any CDC pipeline with limited WAL retention**, not just single-table syncs.

**Recommended Approach:**
1. **Immediate (Option 1):** Implement High-Water Mark recovery script for current single-table scenario
2. **Short-term (Option 4):** Add Checkpoint & Manifest pattern for observability
3. **Long-term (Option 2 or 3):** Evaluate Transactional Outbox for mission-critical tables OR Reconciliation for automated self-healing

**We must audit and verify:**
- Which tables have reliable incrementing identifiers (timestamp or ID)?
- Can Legacy DB schema be modified (for Outbox pattern)?
- What is acceptable recovery time objective (RTO) for this table?
- Is manual intervention acceptable or must recovery be fully automated?

**Each CDC pipeline needs:** Recovery strategy selection, identifier validation, monitoring/alerting setup, runbook documentation.

---

**Source:** Gemini architectural exploration (2026-03-17)
