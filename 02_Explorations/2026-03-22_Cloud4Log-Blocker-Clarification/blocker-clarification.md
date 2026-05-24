# Cloud4Log / Markant DVA: Blocker Clarification

**Date:** 2026-03-22
**Author:** Matthias Max
**Purpose:** Replace chaotic mail/chat threads with a single, structured reference for Christian Lang

---

## Summary for Christian

The idea of setting up a dedicated dev environment across all Nagel-side components and GCP was the right approach, but it has not materialized in the time and quality required. This is the root cause behind both blockers below.

Two things need resolution to unblock C4L development:

1. **Test data and environment strategy (Blocker 1):** P3 proposes **temporary** read-only access to production databases in the GCP, Cloud4Log, and Markant DEV environments (Option A) **until go-live**, after which Nagel IT provides a dedicated testing environment with live data. This is the fastest way forward:
   - Production data already meets all criteria and covers multiple depots
   - Enables Marius Huettig to perform business QA against recognizable shipments
   - Access is read-only, enforceable via DB user permissions
     - Note: introducing a new restricted DB user may require iteration — the TMS Bridge user permission switch in New Dispo took multiple rounds to get right. Using the existing user with known working permissions may be the faster path.
2. **WL5 DEV config (Blocker 2):** Activate the same configuration in DEV that already works in test. Exact gaps to be listed by Nikolay Hristov.

Everything else (TMS Bridge public IP, write access) is either a separate topic or already resolved.

---

## Context

The approved architecture (signed off by Christian, March 2026) is unchanged. P3 is implementing the resilient queue-based upload/download architecture for Cloud4Log and Markant DVA. There is no "redesign" — the term was used loosely by Cem and caused unnecessary confusion.

---

## Blockers

### Blocker 1: Development and Testing Requires Real-World Data That Nagel IT Must Provide

**Status:** BLOCKED
**Owner:** Nagel IT
**Impact:** Upload flow development, integration testing, and business QA completely stalled

---

#### Part A: Data Requirements

The databases provided for local development (`d57.tmsrel`, `D57DB.DIGILISREL`) do not contain shipment data in the states required by the Cloud4Log use case. The data inside is simply not usable for C4L.

**What "usable data" means concretely:**

For a shipment to be processable by C4L, it must satisfy *all* of the following across three systems simultaneously. If any link in this cross-system chain is missing, the shipment is invisible to C4L.

| #   | System             | Table / Resource       | Requirement                                                                                                              |
| --- | ------------------ | ---------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| 1   | TMS Oracle         | Shipment               | `verkehrsstrom = '30'`                                                                                                   |
| 2   | TMS Oracle         | Shipment               | `druckdatumE` must be non-null                                                                                           |
| 3   | TMS Oracle         | Bordero / Rollkart     | Shipment must have a related bordero OR rollkart record. If rollkart: `tranArt` must be `3` or `6`                       |
| 4   | TMS Oracle         | Person                 | Related person record (joined via `EmpfN` and `EmpfI`) with ILN value `4099200045498` or `4099200045504`                 |
| 5   | TMS Oracle         | `pstHsts`              | Related record with `status = '660'`, `mp = '4'` (if bordero) or `mp = '7'` (if rollkart), and meaningful metadata value |
| 6   | TMS Oracle         | `senLsPsts`            | Related record where `lsN` matches `dl_no` from Digilis `DL_SHIP_ORD_POS`                                                |
| 7   | TMS Oracle         | `sen_ls_ref`           | Record with `typ = 'BES'`, `lsN` matching `dl_no` from Digilis `DL_SHIP_ORD_POS`, and `sen_tix` matching the shipment    |
| 8   | TMS Oracle         | `sen_ls_ref` → `senLs` | `sen_ls_ref` must have a relation with `senLs` where `senLs.sen_tix` matches the shipment and `typ = 'BES'`              |
| 9   | Digilis Oracle     | `DL_SHIP_ORD`          | Delivery note with same `SEN_TIX` as the shipment in TMS                                                                 |
| 10  | Digilis Oracle     | `DL_SHIP_ORD_POS`      | `DL_SHIP_ORD` linked to `DL_SHIP_ORD_POS`                                                                                |
| 11  | Digilis Oracle     | `DL_DEL_NOTE_CONN`     | `DL_SHIP_ORD_POS` linked to `DL_DEL_NOTE_CONN`                                                                           |
| 12  | Digilis File Share | File system            | File must exist at the path specified in `DL_DEL_NOTE_CONN.Path`                                                         |

**Why real-world data is required (not just for development):**

- The data contract spans 3 systems (TMS Oracle, Digilis Oracle, Digilis File Share) with complex cross-references
- Creating consistent mock data requires deep domain knowledge that P3 developers do not have
- The previous iteration tested against production data (read-only) precisely for this reason
- Standard practice in enterprise integration projects: production-like data is required to validate real-world edge cases
  - New Dispo faced the same challenges — using real-world data resolved a lot of issues and raised the quality to meet the requirements
- **Quality assurance by Nagel Business:** Marius Huettig (PO on Nagel side) needs to verify that the data arriving in Cloud4Log and Markant DVA platforms is correct. He can only do this with real-world data that he can identify and confirm against known shipments. Mock data is meaningless for business-side QA because there is no ground truth to compare against.

---

#### Part B: Environment, Access, and Multi-Depot Strategy

The core of the C4L architecture is concurrent, parallel processing across multiple depots. Testing this requires data for multiple depots — not just one. This is also the environment in which Marius Huettig will perform business QA.

Originally production data was used in the GCP, Cloud4Log and Markant DEV environments with read-only access because:

1. The C4L and Markant upload integrations only ever read, never write — this can be enforced via DB user permissions
2. Production data is constantly fed with real shipments, providing realistic multi-depot data
3. Setting up separate dev resources for 32 depots with continuously fed data is a challenge and has shown to be operationally not feasible so far

P3 proposes the following options to resolve this:

| Option                                               | Pros                                                                                                                                                     | Cons                                                 |
| ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| **A) Read-only prod access in DEV (temporary)**      | Realistic data, multi-depot, zero maintenance. Temporary until go-live, after which Nagel IT can provide a dedicated testing environment with live data. | Requires security sign-off, prod connection from DEV |
| **B) Nagel IT populates dev databases for N depots** | Clean separation from prod                                                                                                                               | Ongoing maintenance, who feeds data continuously?    |
| **C) Nagel IT provides a one-time snapshot**         | No prod connection needed                                                                                                                                | Data goes stale, limited depot coverage              |

---

**Resolution path (Matthias' recommendation):**

Option A resolves both parts at once: production databases already contain real-world data that meets the Part A criteria, across multiple depots, continuously fed. No manual data preparation needed.

If Option A is not acceptable, Option B is the fallback — but then Nagel IT must populate the dev databases with data meeting the Part A criteria. Part A's requirements become the specification for that data provisioning effort, owned by Marius Huettig's domain.

---

### Blocker 2: WL5 DEV Environment Configuration

**Status:** BLOCKED — awaiting detailed input from Nikolay Hristov (P3 DevOps)
**Owner:** Nagel IT infrastructure
**Impact:** Deployments to DEV not possible

Configurations that already function in the test environment have not been activated in the WL5 DEV environment. Without this, P3 cannot deploy and test in DEV.

**Exact issues:** TO BE FILLED IN by Nikolay Hristov — specific WL5 DEV configuration gaps vs. test environment.

| #   | Configuration Item         | Status in Test | Status in DEV | What's needed |
| --- | -------------------------- | -------------- | ------------- | ------------- |
|     | *awaiting Nikolay's input* |                |               |               |

**Resolution path:**

Mirror the working test-environment configuration to DEV. This should be a straightforward infrastructure task once the exact gaps are listed.

---

## Side Topics (Not C4L Blockers)

These were raised in the communication threads but are separate concerns that should not block C4L development.

### Side Topic 1: TMS Bridge Public IP in WL5

**Raised by:** Matt Wilkinson
**Nature:** Security/infrastructure concern

The TMS Bridge in WL5 production (`wl5-p`) is deployed with a public IP. Matt flagged this as unexpected by Christian. Nikolay confirmed this is the same deployment pattern used in `t-t` and `p-p` (cloned configuration).

**Clarification by Matthias Max (Software Architect):** The TMS Bridge was designed and built together with Christian. It was initially considered as an API gateway but that decision was revoked early on. The TMS Bridge is an internal component providing access to TMS data for internal consumers only. For example, the EBV integration uses Azure APIM to access TMS data via the TMS Bridge. The public IP concern raised by Matt should be reviewed by the infrastructure team, but the TMS Bridge's role as an internal-only component is an established architectural decision.

**Assessment:** Valid infrastructure topic to review, but the TMS Bridge's internal role is confirmed. Should be addressed by the DevOps/infrastructure team on its own timeline. It is not a C4L development blocker and should not be mixed into the C4L data discussion.

### Side Topic 2: Production Secrets in wl5-d-d

**Raised by:** Matt Wilkinson
**Nature:** Security hygiene

Production Google secrets are present in the `wl5-d-d` (dev) environment. Matt requested their removal.

**Context:** These credentials exist in the dev environment because previous development and test cycles used production data and therefore required production credentials. This is directly tied to Blocker 1 — the decision on which data source to use (Option A vs. B) determines whether these credentials stay or go.

**Assessment:** Resolves itself along with the decision for Blocker 1. Not a separate action item.

### Side Topic 3: Write Access Confusion

**Raised by:** Cem (original escalation), subsequently clarified
**Nature:** Resolved misunderstanding

Cem's original mail mentioned "Read/Write permissions" which alarmed Christian. The actual situation: P3 offered to write mock data themselves as a workaround to unblock development faster. This was not a demand and is no longer on the table. P3 needs databases with data already in them — read access is sufficient.

**Assessment:** Fully resolved. The write-access topic should not resurface.

