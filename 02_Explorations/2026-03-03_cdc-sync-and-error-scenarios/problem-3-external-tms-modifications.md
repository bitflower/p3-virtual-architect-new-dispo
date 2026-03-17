# Problem 3: External TMS Modifications Invisible to New Dispo

**Date:** 2026-03-03
**Status:** ⚠️ **Descoped** - No longer being actively addressed
**Meeting Reference:** `00_Meetings/2025-10-10_yosif-cdc-sync-and-error-flow.md`

---

## Problem Statement

When someone modifies data directly in TMS Database (e.g., via old Uniface fat client or SQL tools), New Dispo doesn't detect these changes.

**Direction:** External System → TMS (New Dispo unaware)

**Complexity:** Unknown (was not investigated)

**Category:** External Write Detection Gap

---

## Why This Was Descoped

This problem was identified during initial exploration but was descoped before detailed analysis. The focus shifted to:
- **Problem 1**: Top-down sync (New Dispo → TMS)
- **Problem 2**: Bottom-up sync (TMS → New Dispo via CDC)

---

## Potential Sources of External Modifications

- Uniface fat client (legacy TMS client)
- Direct SQL access (DBAs, reporting tools)
- Other system integrations
- Batch jobs and scheduled processes
- Manual data fixes

---

## Questions That Remain Unanswered

1. Which TMS tables have CDC configured?
2. Are all relevant operations captured by CDC?
3. How often do external modifications occur?
4. What business processes still use Uniface?
5. Is there a plan to decommission external write access?

---

## Cross-References

- **Solutions:** `problem-3-solutions.md` (descoped - not pursued)
- **Original Request:** `_archive/matthias-input.md` (mentioned this problem)
- **Related Problems:**
  - `problem-1-distributed-transaction-failure.md` (Top-down sync)
  - `problem-2-cdc-event-processing-failure.md` (Bottom-up sync)
