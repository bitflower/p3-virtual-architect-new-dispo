# Tour Calculation — Sync State After Error

**Date:** 2026-04-24
**Status:** Exploration
**Source:** Meeting Boyan Valchev + Matthias Max (2026-04-24)

---

## Original User Input

When a tour calculation fails, transport order dates from the previous successful calculation remain in place, creating a misleading state for users. Discovered by Boyan Valchev & Vesela during testing.

---

## Problem Statement

When a tour calculation **fails** (e.g., due to fixed time restrictions that make calculation impossible):

1. The transport order **dates from the previous successful calculation remain** in the database
2. These dates are now **stale/out-of-date** because the latest changes were not accounted for
3. A user looking at this transport order sees populated dates and **assumes it is calculated and ready to plan**
4. There is **no visual indication** that the calculation failed and the dates are outdated
5. Some tour points may have dates while others don't — creating **inconsistent partial state**

## Impact

- **User confusion:** A different user (not the one who triggered the failed calculation) sees the transport order with dates and has no way to know something went wrong
- **Planning errors:** The transport order could be planned based on stale/incorrect dates
- **Data inconsistency:** Mixed state where some tour points have dates, others don't

## Proposed Solution

**Make the dates null when the calculation fails.** This would:
- Clearly signal that the transport order is not in a calculated state
- Prevent planning based on stale data
- Create a consistent state (no dates = not calculated)

This requires coordination with Nagel because:
- They have the utility/function in TMS that can edit these dates
- It's categorized as a **TMS behavior drift** item
- Need confirmation whether P3 can implement this or if Nagel needs to

## Action Items

| # | Action | Owner | Status |
|---|--------|-------|--------|
| 1 | Discuss with Joachim (or Andre/Reinhardt while Joachim is away) whether dates should be nulled on calculation failure | Matthias | **Open** |
| 2 | Find a transport order that reproduces this behavior (old one that won't be touched) | Boyan | **Open** |
| 3 | Document transport order ID and environment for reproduction | Boyan → Matthias | **Waiting** |

## Related Tickets

| Ticket | Topic |
|--------|-------|
| [ADO #124505](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_workitems/edit/124505) | Tour calculation sync state after error |

## Related Files

- `00_Meetings/2026-04-09_timezone/` — source meeting folder
- `00_Meetings/2026-04-09_timezone/info-from-boyan.md` — ticket links from Boyan
