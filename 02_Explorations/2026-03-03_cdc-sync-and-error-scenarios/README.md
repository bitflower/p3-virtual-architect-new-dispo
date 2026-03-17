# CDC Sync and Error Scenarios - Exploration Overview

**Date:** 2026-03-03
**Status:** Active
**Meeting Reference:** `00_Meetings/2025-10-10_yosif-cdc-sync-and-error-flow.md`

---

## Summary

This exploration addresses synchronization challenges between New Dispo and TMS Database, focusing on CDC event processing failures.

---

## Documents

### Problems & Solutions

| Problem | Problem Doc | Solutions Doc | Status |
|---------|-------------|---------------|--------|
| **Problem 1**: Distributed Transaction Failure (Top-Down) | `problem-1-distributed-transaction-failure.md` | `problem-1-solutions.md` | ✅ Covered in `02_Explorations/2026-03-16_Transactional-Behaviour-New-Dispo-TMS-Transport-Orders/` |
| **Problem 2**: CDC Event Processing Failure (Bottom-Up) | `problem-2-cdc-event-processing-failure.md` | `problem-2-solutions.md` | 🔴 **Active - requires solution** |
| **Problem 3**: External TMS Modifications | `problem-3-external-tms-modifications.md` | `problem-3-solutions.md` | ⚠️ Descoped |

### Supporting Documents

- `document-separation-analysis.md` - Analysis and rationale for splitting the original mega-document

### Backlog

- `Backlog/current-story.md` - Original PO-drafted user story (generic)
- `Backlog/refined-story.md` - **Technical user story** for Problem 2 (ready for refinement)
- `Backlog/refinement-comparison.md` - Comparison showing improvements from PO draft to technical story

### Archive

- `_archive/matthias-input.md` - Original exploration request (no longer relevant)
- `_archive/cdc-sync-and-error-scenarios-original.md` - Original combined analysis (split into focused documents)
- `_archive/potential-solutions-original.md` - Original combined solutions (split into problem-specific documents)

---

## Quick Navigation

### I need to understand CDC event processing failures
👉 **Problem:** `problem-2-cdc-event-processing-failure.md`
👉 **Solutions:** `problem-2-solutions.md`

### I need to understand the distributed transaction problem
👉 **Problem:** `problem-1-distributed-transaction-failure.md`
👉 **Solutions:** `problem-1-solutions.md`
👉 **Detailed Analysis:** `02_Explorations/2026-03-16_Transactional-Behaviour-New-Dispo-TMS-Transport-Orders/`

### I want to understand why documents were split
👉 Read: `document-separation-analysis.md`

### I need the user story for team refinement
👉 **User Story:** `Backlog/refined-story.md` (technical, ready for refinement)
👉 **Comparison:** `Backlog/refinement-comparison.md` (shows what changed from PO draft)

---

## Focus: Problem 2 - CDC Event Processing Failure

This exploration primarily focuses on **Problem 2**: CDC events are consumed but lost if processing fails.

**Key Issue:** HTTP 200 OK returned even on processing failures → Pub/Sub acknowledges message → Event lost forever

**Solution Options:**
- **Option A (Recommended):** Fix push model - Return HTTP 500/503 on failure + Dead Letter Topic
- **Option B:** Event Store - Persist all CDC events for replay
- **Option C:** Idempotent Handlers - Add deduplication logic
- **Option D:** Pull Subscription - Switch from push to pull for explicit acknowledgment control

---

## Cross-References

- **Original Meeting:** `00_Meetings/2025-10-10_yosif-cdc-sync-and-error-flow.md`
- **Problem 1 Detailed Analysis:** `02_Explorations/2026-03-16_Transactional-Behaviour-New-Dispo-TMS-Transport-Orders/`
