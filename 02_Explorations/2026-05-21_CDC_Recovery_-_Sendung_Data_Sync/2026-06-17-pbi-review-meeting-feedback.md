# Meeting Feedback: CDC Outage Recovery — PBI Review

**Date:** 2026-06-17
**Source:** [PBI Review](2026-06-17-pbi-review.md) discussed in team meeting
**Attendees:** Matthias Max, Yosif Mihaylov, Boyan Valchev, Ivaylo Petrov, Kristiyan Paunov, Maximilian Kehder

---

## TMS Database Load — Actual Query Profile

> Needed for Nagel coordination (PBI #125381).

Yosif clarified the exact load the recovery mechanism puts on a single TMS database per branch:

| # | Query | Purpose | Result set |
|---|-------|---------|------------|
| 1 | Select all shipment IDs (unplanned only) | Delete detection — compare against local leg IDs | IDs only, no full rows |
| 2 | Select shipments with full content where `u_time > watermark` | Insert/update sync — feed into resolvers | Full shipment rows |

**That's it — two queries per branch, one-time execution per recovery run.** No continuous polling, no repeated calls. The recovery is triggered manually on outage, not as a background service.

Boyan added: initial population of legs and lots (which runs heavier insert operations) currently takes 8–9 seconds max for two branches. The recovery queries are lighter than that.

---

## Consensus Decisions

### 1. Delete detection scoped to unplanned legs — confirmed

Applies **only to deletion detection**, not to update/insert flows. Boyan explicitly asked and confirmed this distinction. Yosif agreed — detecting deletions for planned shipments makes no sense.

**PBI #124824:** Add that deletion detection queries only unplanned leg shipment IDs.

### 2. U-time comparison strategy — addition

To avoid timezone mismatches, the team agreed to compare U-time against U-time (both from TMS clock domain):

- Legs already carry U-time (Kristiyan uses it for change detection)
- Persist the shipment's `u_time` as a **separate field** on legs so the watermark comparison stays in one clock domain
- Ivaylo flagged: currently `u_time` may be overwritten with local time on save — **needs verification**

**PBI #124824:** Add requirement to persist shipment `u_time` on legs for watermark comparison.

### 3. Watermark is auto-derivable from legs

Yosif proposed: derive the watermark from `max(u_time)` across existing legs, not require manual operator input. Boyan and Matthias agreed. Only a **start timestamp** is needed (no end date). Add a small overlap buffer (minutes) because re-processing is idempotent.

**PBI #124826:** The endpoint still benefits from accepting an optional timestamp override, but the primary mechanism is auto-derivation from leg data.

### 4. Per-shipment transaction isolation — confirmed

Yosif agreed per-shipment is the right granularity. Per-field (sub-shipment) is too fine-grained. Per-branch batching (e.g., 200 shipments per transaction) is an option only if performance issues arise later — not for the initial implementation.

**PBI #124824:** Specify per-shipment transaction boundaries with rollback-on-failure.

### 5. Authorization on endpoint — confirmed

Matthias: "crucial in reality, last 1% finish line, few lines of code." No disagreement. Yosif noted the same concept applies to existing water/leg generation endpoints.

**PBI #124826:** Add authorization requirement (admin/operations role).

### 6. CDC Recovery is a go-live blocker

Max (Kehder) suggested it's not a go-live blocker since it's a recovery feature. Yosif and Boyan immediately disagreed. Matthias: *"It's like driving a car without airbag. Yes, it drives. But once it crashes, you suddenly remember that was not a good idea."* Christian (customer) explicitly requested end-to-end reliability.

**Strong consensus: go-live blocker.**

---

## De-Prioritizations

### 1. TMS load protection mitigations → premature optimization

Rate limiting, batching, time-window slicing — all dropped from scope. Yosif: this is a one-time outage recovery, not a continuous scanning service. Load protection only becomes relevant for a future full-time scanning service. Matthias agreed: "premature optimization."

**PBI #124824:** Remove load protection mitigations from scope.

### 2. Direct table access optimization → not needed for go-live

Views are acceptable for a one-time recovery. Yosif: "It would be fine if it runs for 10 seconds because it's a one-time thing." If direct table access creates issues (new TMS Bridge endpoint, field mapping), accept the performance hit and use views.

**No PBI change needed** — already listed as "no separate PBI needed" in the review.

### 3. Old-state derivation risk (leg-splitting note) → beyond go-live

Matthias: "I think this one we can skip. It's really beyond go live."

**PBI #124824:** Remove this note.

### 4. Two-step process documentation → not needed in PBI

Matthias: "That's also probably overcomplicating things. Let's postpone that."

**PBI #124826:** No change needed.

### 5. Response structure detail → defer to after implementation

Matthias: "Not really a blocker on the first version, but something you need to keep in mind." Refine once main work is done, especially around partial success reporting.

**PBI #124826:** Keep "return enough information" as-is for now.

### 6. QA test case refinements → postponed

All QA gaps identified in the review (insert/update separation, delete scope testing, timestamp edge cases, TMS load observation) are deferred.

**PBI #124827:** No changes for now.

---

## Corrections to the Review

### 1. Parallel branch processing does NOT conflict with TMS load

Yosif corrected: each branch is a separate physical TMS database. Parallel branch processing imposes no extra load on any single DB. The review statement *"parallel branch processing conflicts with TMS load protection"* is factually incorrect.

### 2. Watermark source: auto-derived, not manual-only

The review states: *"watermark comes from the endpoint input (not auto-derived)."* Meeting consensus: watermark is auto-derived from `max(u_time)` in legs. Manual timestamp input is an optional override, not the primary mechanism.

### 3. TMS load protection: explicit decision, not open gap

The review lists load protection as a gap/risk. The team explicitly decided against implementing these mitigations for the outage recovery scope. This is a conscious de-prioritization, not a missing item.

### 4. Direct table access: conscious deferral, not open decision

The review recommends early measurement. The team decided views are acceptable for the recovery scope. Optimization can happen later if actual performance problems arise.

---

## Document History

| Date       | Author       | Change      |
|------------|--------------|-------------|
| 2026-06-18 | Matthias Max | Meeting feedback collected |

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
