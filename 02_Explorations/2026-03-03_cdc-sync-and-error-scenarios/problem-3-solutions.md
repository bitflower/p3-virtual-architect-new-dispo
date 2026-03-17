# Problem 3 Solutions: External TMS Modifications

**Date:** 2026-03-03
**Status:** ⚠️ **Descoped** - Solutions not pursued
**Related Problem:** `problem-3-external-tms-modifications.md`

---

## Summary

Solutions for detecting external TMS modifications (via Uniface, SQL tools, etc.) were proposed but **not pursued** as this problem was descoped.

---

## Historical Solution Options (Not Implemented)

The following solutions were considered before descoping:

### Option A: Expand CDC Coverage

- Enable CDC on additional TMS tables beyond `sendung`
- Configure events for all relevant operations
- Ensure all external modifications trigger CDC events

**Effort:** Low-Medium (depends on CDC audit findings)
**Risk:** Low

---

### Option B: Periodic Reconciliation Jobs

- Background job compares TMS vs. New Dispo data
- Detect and alert on inconsistencies
- Optional: Automatic sync repair

**Effort:** Medium
**Risk:** Low

---

### Option C: Read-Through Cache Pattern

- New Dispo queries TMS for missing data on-demand
- Cache results locally
- Eventual consistency via lazy loading

**Effort:** Medium-High
**Risk:** Medium

---

### Option D: Restrict Direct TMS Access

- Force all modifications through New Dispo/TMS Bridge
- Decommission Uniface (if possible)
- Block direct SQL access

**Effort:** Depends on business process changes
**Risk:** High (business disruption)

---

## Why This Was Descoped

This problem was descoped before investigation phase. Focus shifted to:
- **Problem 1:** Top-down sync (New Dispo → TMS)
- **Problem 2:** Bottom-up sync (TMS → New Dispo via CDC)

External modification detection was deemed lower priority or out of scope.

---

## Cross-References

- **Problem Analysis:** `problem-3-external-tms-modifications.md`
- **Original Request:** `_archive/matthias-input.md` (mentioned this problem)
