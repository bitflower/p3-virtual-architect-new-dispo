# CDC Sync and Error Scenarios - Exploration Overview

**Date:** 2026-03-03
**Status:** Active
**Meeting Reference:** `00_Meetings/2025-10-10_yosif-cdc-sync-and-error-flow.md`

---

## Summary

This exploration addresses synchronization challenges between New Dispo and TMS Database, focusing on CDC event processing failures.

---

## Documents

### Active Problems

| Problem | Document | Status |
|---------|----------|--------|
| **Problem 1**: Distributed Transaction Failure (Top-Down) | `problem-1-distributed-transaction-failure.md` | ✅ Covered in `02_Explorations/2026-03-16_Transactional-Behaviour-New-Dispo-TMS-Transport-Orders/` |
| **Problem 2**: CDC Event Processing Failure (Bottom-Up) | `problem-2-cdc-event-processing-failure.md` | 🔴 **Active - requires solution** |
| **Problem 3**: External TMS Modifications | `problem-3-external-tms-modifications.md` | ⚠️ Descoped |

### Supporting Documents

- `potential-solutions.md` - Solution proposals for all problems
- `document-separation-analysis.md` - Analysis and rationale for splitting the original mega-document

### Archive

- `_archive/matthias-input.md` - Original exploration request (no longer relevant)
- `_archive/cdc-sync-and-error-scenarios-original.md` - Original combined analysis (split into focused documents)

---

## Quick Navigation

### I need to understand CDC event processing failures
👉 Read: `problem-2-cdc-event-processing-failure.md`

### I need to understand the distributed transaction problem
👉 Read: `problem-1-distributed-transaction-failure.md`
👉 Then go to: `02_Explorations/2026-03-16_Transactional-Behaviour-New-Dispo-TMS-Transport-Orders/`

### I need solution proposals
👉 Read: `potential-solutions.md`

### I want to understand why documents were split
👉 Read: `document-separation-analysis.md`

---

## Focus: Problem 2 - CDC Event Processing Failure

This exploration primarily focuses on **Problem 2**: CDC events are consumed but lost if processing fails.

**Key Issue:** HTTP 200 OK returned even on processing failures → Pub/Sub acknowledges message → Event lost forever

**Recommended Solution:** Return HTTP 500/503 on failure + configure Pub/Sub retry policy + dead letter topic

---

## Cross-References

- **Original Meeting:** `00_Meetings/2025-10-10_yosif-cdc-sync-and-error-flow.md`
- **Problem 1 Detailed Analysis:** `02_Explorations/2026-03-16_Transactional-Behaviour-New-Dispo-TMS-Transport-Orders/`
