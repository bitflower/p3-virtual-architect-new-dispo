# Oracle CDC Architecture Evaluation

**Date:** 2026-01-16
**Author:** Solution Architecture Team
**Status:** Draft for Review

---

## 1. Executive Summary

This document evaluates CDC (Change Data Capture) options for integrating on-premises Oracle databases with the NewDispo system via Google Pub/Sub. The evaluation incorporates findings from initial brainstorming, customer requirements, and critical constraints discovered in stakeholder communications.

### Key Finding

**Striim is already deployed** in the customer environment (currently on 5 branches, historically on all). This fundamentally changes the evaluation landscape from the initial brainstorming session, which treated all options as greenfield implementations.

### Recommendation Preview

| Priority | Option | Rationale |
|----------|--------|-----------|
| 1 | **Leverage existing Striim** | Already deployed, proven, avoids dual-CDC risk |
| 2 | **GCP Datastream** | Native GCP, existing internal knowledge on GCP side |
| 3 | **Debezium** | Open source, but requires infrastructure management |

---

## 2. Requirements Recap

### 2.1 Business Requirements

| Requirement | Source | Priority |
|-------------|--------|----------|
| Enable NewDispo independently from Project G | Mails_1 | Critical |
| CDC events published to Pub/Sub | Mails_1 | Critical |
| Same tables as AlloyDB setup | Mails_1 | High |
| Avoid dual-CDC systems | Mails_2 | High |

> **Action Required:** If a non-Striim solution is selected, coordinate Striim decommissioning plan with customer before enabling new CDC tool. Running dual CDC systems risks data conflicts and doubles infrastructure complexity.

### 2.2 Use Case Characteristics

> **Important Clarification (from Mails_2):**
> This is **NOT** a bulk data replication use case. The goal is to trigger business logic based on **specific data changes** (e.g., "new shipment arrives"). The scope is narrow: changes to specific fields in specific table records.

This is a significant constraint that affects tool selection - high-throughput capabilities are less important than reliability and low operational overhead.

### 2.3 Technical Environment Constraints

| Constraint | Details | Impact |
|------------|---------|--------|
| Oracle Versions | 12.1.0.2 (main), 19.9/19.21 (KRITIS) | All support LogMiner |
| **Edition Mix** | Enterprise (HQ), **Standard Edition 2** (branches) | **Critical** - SE2 has LogMiner limitations |
| Archivelog Mode | Enabled | Required for CDC - confirmed available |
| Redo Log Retention | **~1 hour at some branches (D33)** | **Critical** - very short recovery window |
| Infrastructure State | Described as "creeky" | Reliability concerns |
| Network to GCP | Established | Enables cloud-hosted tools |

---

## 3. Critical Constraints Analysis

### 3.1 Standard Edition 2 Limitation

**Oracle Standard Edition 2** does not support all LogMiner features. Specifically:
- No support for **Continuous LogMiner** (the streaming API)
- Limited concurrent LogMiner sessions
- No support for **Supplemental Logging** at the database level in some configurations

**Impact:** Any CDC tool relying on LogMiner streaming capabilities (Datastream, Debezium) may have **degraded functionality or incompatibility** on SE2 branches.

> **Action Required:** Validate LogMiner feature availability on SE2 branches with DBA team.

### 3.2 Redo Log Retention Window

The ~1 hour retention window at some branches (D33 example) presents a **severe operational risk**:

| Scenario | Consequence |
|----------|-------------|
| Network outage > 1 hour | Transaction sequence lost, **full initial load required** |
| CDC tool restart/maintenance | Risk of missing transactions |
| GCP region issues | Recovery requires re-seeding all data |

This affects **all LogMiner-based solutions equally**, including Datastream, Debezium, and Striim.

> **Action Required:** Design CDC solution with recovery/resync capability. Accept that full initial load may be required after extended outages at branches with short retention windows.

### 3.3 Existing Striim Deployment

**Discovery from Mails_2:** Striim is already deployed and has historical coverage across all branches.

| Aspect | Status |
|--------|--------|
| Current Coverage | 5 branches |
| Historical Coverage | All branches (can be re-enabled) |
| Strategic Question | Phase out (post-Alloy migration) or expand? |

This is a **pivotal discovery** that was not factored into the initial Gemini brainstorming session.

> **Action Required:** Clarify strategic direction for Striim with customer stakeholders (Christian Lang). Decision: phase out post-Alloy migration, or expand for long-term use?

### 3.4 Striim Cost Concern

**From Gemini brainstorming:** Striim is listed at **$9,600+/month** for a new GCP Marketplace deployment. This makes it the most expensive option by a significant margin.

| Solution | Monthly Cost | Annual Cost |
|----------|--------------|-------------|
| Striim (new) | $9,600+ | **$115,200+** |
| GCP Datastream | ~$2/GiB (variable) | Volume-dependent |
| Debezium | $50-200 (VM only) | $600-2,400 |
| GoldenGate | $1,000+ | $12,000+ |

**Critical Unknown:** The evaluation assumes that *extending* an existing Striim deployment costs less than a new deployment. This assumption is **unverified**.

Possible scenarios:
1. **Best case:** Adding Pub/Sub as a target is a configuration change with no additional licensing cost
2. **Moderate case:** Per-target or per-connector licensing applies, adding incremental cost
3. **Worst case:** Full licensing scales with number of sources/branches, making expansion equally expensive

> **Action Required:** Obtain actual Striim cost data from customer before recommending Striim as primary option. If Striim expansion costs approach new-deployment pricing, the cost/benefit analysis shifts significantly toward GCP Datastream (if SE2 compatible).

---

## 4. Option Evaluation

### 4.1 Option A: Leverage Existing Striim

**Description:** Extend the existing Striim deployment to publish to Pub/Sub instead of (or in addition to) current targets.

| Criterion | Assessment | Score |
|-----------|------------|-------|
| Internal Knowledge | **Operational experience exists** (already deployed) | High |
| Implementation Risk | Low - extend existing, proven infrastructure | Low |
| Dual-CDC Risk | **Eliminated** - single CDC system | None |
| Cost (incremental) | **Unknown** - see Section 3.4. New deployment = $9,600+/mo | **TBD** |
| GCP Integration | Striim has native Pub/Sub writer | Good |
| SE2 Compatibility | **Already proven** at branches | Verified |

**Strengths:**
- Already deployed and operational
- Proven compatibility with customer's Oracle environment
- Eliminates risk of running dual CDC systems
- Existing operational procedures and knowledge

**Weaknesses:**
- High licensing cost if expanding coverage (need cost data)
- Dependency on third-party vendor
- Not aligned with "GCP-native" strategy if that's a goal

**Open Questions:**
1. What are current Striim costs (current + 6 months historical)?
2. Can existing Striim deployment be extended to write to Pub/Sub?
3. What is the long-term Striim strategy (phase out vs. expand)?

---

### 4.2 Option B: GCP Datastream + Cloud Functions

**Description:** Use GCP Datastream to capture Oracle changes into GCS, then trigger Cloud Functions to publish to Pub/Sub (mirrors existing AlloyDB pattern).

| Criterion | Assessment | Score |
|-----------|------------|-------|
| Internal Knowledge | **High on GCP side**, new for Oracle source | Med-High |
| Implementation Risk | Medium - new Oracle source configuration | Medium |
| Dual-CDC Risk | **Present** if Striim continues | High |
| Cost | ~$2.00/GiB CDC data | Medium |
| GCP Integration | Native, fully managed | Excellent |
| SE2 Compatibility | **Uncertain** - requires validation | Unknown |

**Strengths:**
- Consistent with existing GCP architecture (AlloyDB pattern)
- Leverages existing Cloud Function → Pub/Sub pipeline
- Fully managed, no infrastructure to maintain
- Native GCP monitoring and integration

**Weaknesses:**
- **SE2 compatibility unverified** - may not work on branch databases
- Creates dual-CDC scenario if Striim continues
- Latency through GCS bucket (not direct streaming)
- New Oracle-specific configuration required

**Architecture Pattern:**
```
Oracle DB → [VPN/Interconnect] → Datastream → GCS → Cloud Function → Pub/Sub
```

**Open Questions:**
1. Does Datastream support Oracle Standard Edition 2 with LogMiner?
2. Can Striim be fully retired if Datastream is adopted?
3. What is the latency profile (GCS intermediate step)?

> **Action Required:** Before PoC, validate Datastream Oracle SE2 support via Google documentation and/or Google Cloud support ticket. If SE2 is unsupported, this option is not viable for branch databases.

---

### 4.3 Option C: Debezium Server on GCE

**Description:** Deploy Debezium Server on Google Compute Engine to read Oracle logs and write directly to Pub/Sub.

| Criterion | Assessment | Score |
|-----------|------------|-------|
| Internal Knowledge | **None** | Low |
| Implementation Risk | High - new technology, VM management | High |
| Dual-CDC Risk | **Present** if Striim continues | High |
| Cost | $50-200/month (VM) + operational overhead | Low |
| GCP Integration | Manual (Pub/Sub connector available) | Moderate |
| SE2 Compatibility | **Uncertain** - same LogMiner dependency | Unknown |

**Strengths:**
- Open source, no licensing costs
- Direct Oracle → Pub/Sub (no intermediate storage)
- Low latency potential
- Flexible configuration

**Weaknesses:**
- **No internal knowledge or experience**
- Requires VM management, patching, monitoring
- Same SE2/LogMiner constraints as Datastream
- Operational complexity in production
- Creates dual-CDC scenario

**Architecture Pattern:**
```
Oracle DB → [VPN/Interconnect] → Debezium (GCE VM) → Pub/Sub
```

**Assessment:** Not recommended for initial implementation due to lack of internal expertise and operational overhead. Could be reconsidered for specific edge cases or cost optimization later.

---

### 4.4 Option D: Oracle GoldenGate

**Description:** Use Oracle's native CDC tool with Pub/Sub handler.

| Criterion | Assessment | Score |
|-----------|------------|-------|
| Internal Knowledge | **None** | Low |
| Implementation Risk | Medium - Oracle expertise required | Medium |
| Dual-CDC Risk | **Present** if Striim continues | High |
| Cost | **~$1,000+/month** | High |
| GCP Integration | Via custom handler or Kafka bridge | Moderate |
| SE2 Compatibility | Yes (Oracle product) | Good |

**Assessment:** Expensive, requires Oracle-specific expertise not present in team. Not recommended unless Oracle mandates or customer specifically requests.

---

## 5. Comparative Summary

| Criterion | Striim (Extend) | Datastream | Debezium | GoldenGate |
|-----------|-----------------|------------|----------|------------|
| Internal Knowledge | **High** | Medium | None | None |
| SE2 Compatibility | **Verified** | Unknown | Unknown | Yes |
| Dual-CDC Risk | **None** | High | High | High |
| Operational Overhead | Low (existing) | Low | High | Medium |
| Licensing Cost | **Unknown** ($9,600+/mo if new) | ~$2/GiB | Free | ~$1,000/mo |
| GCP-Native | No | **Yes** | No | No |
| Time to Production | **Fastest** | Medium | Slow | Medium |
| Implementation Effort (Team) | **Low** | Medium | High | High |

> **Cost Warning:** Striim's "Already paid" assumption requires verification. See Section 3.4 for details.

---

## 6. Risk Assessment

### 6.1 Risk Matrix

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| SE2 incompatibility with LogMiner-based tools | Medium | High | Validate with PoC on SE2 branch |
| Dual-CDC conflict causing data issues | Medium | High | Retire one CDC system before enabling another |
| Redo log gap causing full reload | High | Medium | Accept as operational reality; design for recovery |
| **Striim expansion cost = new deployment cost** | **Unknown** | **High** | **Obtain pricing BEFORE committing to Striim path** |
| Datastream Oracle support limitations | Medium | Medium | PoC validation required |

### 6.2 Critical Decision Point

Before selecting any option, the following must be clarified:

1. **Strategic direction for Striim:** Phase out or expand?
2. **SE2 LogMiner validation:** Can Datastream/Debezium work on Standard Edition 2?
3. **Cost comparison:** Striim expansion vs. Datastream implementation

---

## 7. Recommendations

### 7.1 Immediate Actions

| # | Action | Owner | Priority |
|---|--------|-------|----------|
| 1 | Obtain Striim cost data (current + 6 months) | Matt Wilkinson | High |
| 2 | Clarify Striim strategic direction with stakeholders | Christian Lang | High |
| 3 | Validate Datastream SE2 compatibility with Google | Matthias Max | High |
| 4 | Confirm LogMiner feature availability on SE2 with DBA | Robert Zanter | High |

### 7.2 Recommended Approach

**Phase 1: Validate and Decide (1-2 weeks)**
1. Gather Striim cost data
2. Get strategic direction from customer
3. Validate Datastream SE2 compatibility (documentation review + Google support)

**Phase 2: PoC Based on Phase 1 Outcome**

| Scenario | Recommended PoC |
|----------|-----------------|
| Striim strategy = Expand | Extend Striim to Pub/Sub |
| Striim strategy = Phase Out | Datastream PoC (if SE2 validated) |
| SE2 incompatible with Datastream | Striim becomes **only** viable option |

### 7.3 Architecture Recommendation

Regardless of CDC tool selection, the target architecture should be:

```
┌─────────────────────────────────────────────────────────────────┐
│                     On-Premises (Nagel)                          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │ Oracle (HQ)  │    │ Oracle (D33) │    │ Oracle (...)  │       │
│  │ Enterprise   │    │ SE2          │    │ SE2          │       │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘       │
│         │                   │                   │               │
│         └───────────────────┴───────────────────┘               │
│                             │                                   │
│                    [CDC Tool: Striim or Datastream Agent]       │
└─────────────────────────────┼───────────────────────────────────┘
                              │ VPN/Interconnect
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                          GCP                                     │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                      Pub/Sub                              │   │
│  │  ┌─────────────────┐         ┌─────────────────┐         │   │
│  │  │ oracle-cdc-topic │         │ (other topics)  │         │   │
│  │  └────────┬────────┘         └─────────────────┘         │   │
│  └───────────┼──────────────────────────────────────────────┘   │
│              │                                                   │
│              ▼                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    NewDispo                               │   │
│  │              (Business Logic Consumers)                   │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 8. Appendix

### 8.1 Gemini Brainstorming Session Gaps

The initial brainstorming session (2026-01-15) did not account for:

| Gap | Impact |
|-----|--------|
| Existing Striim deployment | Changed evaluation from greenfield to brownfield |
| Standard Edition 2 at branches | Potential LogMiner limitations not considered |
| Very short redo log retention | Operational risk not factored into recommendations |
| Dual-CDC avoidance requirement | Constraint not present in initial analysis |

### 8.2 Pricing Reference (from Gemini session)

| Solution | Estimated Cost |
|----------|----------------|
| GCP Datastream | $2.00/GiB (first 2,500 GiB/month) |
| Debezium (VM) | $50-200/month (infrastructure only) |
| Oracle GoldenGate | $1,000+/month |
| Striim | $9,600+/month (new deployment) |

> **Note:** Striim pricing for *extending* an existing deployment may differ significantly from new deployment pricing. Cost data must be obtained from customer.

### 8.3 Document References

| Document | Location |
|----------|----------|
| Original Requirements | `Mails_1/00_Consolidated-Requirements.md` |
| Striim Side Chat | `Mails_2/00_Consolidated-Requirements.md` |
| Gemini Brainstorm | `03_Exploration/2026-01-15-gemini-conversation.md` |

---

## 9. Document History

| Date | Author | Change |
|------|--------|--------|
| 2026-01-16 | Solution Architecture | Initial evaluation draft |
