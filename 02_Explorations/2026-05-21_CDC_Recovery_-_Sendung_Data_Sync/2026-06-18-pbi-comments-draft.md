# Draft PBI Description Updates — CDC Outage Recovery

**Date:** 2026-06-18
**Source:** [Meeting Feedback](2026-06-17-pbi-review-meeting-feedback.md) from 2026-06-17 team review
**Approach:** Append a clearly separated refinement section at the end of each PBI description. Original content stays untouched.
**Status:** DRAFT — not yet pushed to Azure DevOps

---

## PBI #124824 — [BE] Implement on-demand data sync poll mechanism

**Format:** HTML (append after the existing closing `</div>`)

```html
<hr>
<h3>Refinements from Concept Review (2026-06-17)</h3>
<p>Agreed in team review with Matthias, Yosif, Boyan, Ivaylo, Kristiyan, Max Kehder. Reference: <a href="https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_wiki/wikis/Nagel-CAL-Disposition.wiki/15957/2026-05-21-CDC-Recovery-Sendung-Data-Sync">Solution Concept</a></p>
<ol>
  <li><b>Delete detection — scope to unplanned legs only.</b> The deletion detection must query only shipment IDs of unplanned local legs against TMS, not all shipments. Dispatched shipments are never deleted. This reduces the check from hundreds of thousands to hundreds/thousands of IDs per branch.</li>
  <li><b>Persist shipment <code>u_time</code> on legs for watermark comparison.</b> To avoid timezone mismatches, compare u_time against u_time (both from TMS clock domain). Persist the shipment's <code>u_time</code> as a separate field on legs so the watermark comparison stays in one clock domain.<br><em>Note: <code>u_time</code> may currently be overwritten with local time on save — needs verification before implementation.</em></li>
  <li><b>Per-shipment transaction isolation.</b> Use per-shipment transaction boundaries (<code>BeginTransaction</code> / <code>Commit</code> / <code>Rollback</code>). One shipment failing must not abort others. This is a correctness requirement, not just a performance optimization. Per-branch batching is only an option if performance issues arise later.</li>
  <li><b>Out of scope: TMS load protection mitigations.</b> Rate limiting, batching, time-window slicing are not needed for the recovery mechanism. This is a one-time outage recovery triggered manually, not a continuous scanning service.</li>
  <li><b>Out of scope: Old-state derivation risk (leg-splitting).</b> Beyond go-live scope.</li>
</ol>
```

---

## PBI #124826 — [BE] Expose an endpoint for the data sync mechanism

**Format:** HTML (append after the existing closing `</div>`)

```html
<hr>
<h3>Refinements from Concept Review (2026-06-17)</h3>
<p>Agreed in team review with Matthias, Yosif, Boyan, Ivaylo, Kristiyan, Max Kehder. Reference: <a href="https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_wiki/wikis/Nagel-CAL-Disposition.wiki/15957/2026-05-21-CDC-Recovery-Sendung-Data-Sync">Solution Concept</a></p>
<ol>
  <li><b>Watermark is auto-derived, not manual-only.</b> The primary mechanism is auto-derivation: derive the watermark from <code>max(u_time)</code> across existing legs. No manual operator input required by default. The endpoint should still accept an optional timestamp override for edge cases. Add a small overlap buffer (minutes) because re-processing is idempotent. Only a start timestamp is needed (no end date).</li>
  <li><b>Authorization required.</b> The endpoint must be gated to admin/operations roles. This endpoint can delete and modify leg data across all branches — authorization is a go-live requirement.</li>
</ol>
```

---

## PBI #125381 — [Arch] Evaluate TMS database load impact of CDC Recovery queries

**Format:** Markdown (append after the existing content)

```markdown

---

### Refinements from Concept Review (2026-06-17)

Agreed in team review with Matthias, Yosif, Boyan, Ivaylo, Kristiyan, Max Kehder.

**Actual query profile from implementation team:**

The recovery mechanism executes exactly **two queries per branch per recovery run**:

| # | Query | Purpose | Result set |
|---|-------|---------|------------|
| 1 | Select all shipment IDs (unplanned only) | Delete detection — compare against local leg IDs | IDs only, no full rows |
| 2 | Select shipments with full content where `u_time > watermark` | Insert/update sync — feed into resolvers | Full shipment rows |

Key context for Nagel coordination:
- **Two queries per branch, one-time execution per recovery run.** No continuous polling, no repeated calls.
- The recovery is triggered manually on outage, not as a background service.
- Initial population of legs and lots (which runs heavier insert operations) currently takes **8-9 seconds max for two branches**. The recovery queries are lighter than that.
- Each branch is a **separate physical TMS database**. Parallel branch processing imposes no extra load on any single DB.
```

---

## PBIs with no description changes

| PBI | Reason |
|-----|--------|
| #124827 (QA Testing) | QA test case refinements postponed |
| #123931 (Automated data loss tests) | No meeting discussion — still needs rewrite separately |
| #125382 (Operations Runbook) | No meeting discussion |

---

## Document History

| Date       | Author       | Change      |
|------------|--------------|-------------|
| 2026-06-18 | Matthias Max | Draft description updates created from meeting feedback |

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
