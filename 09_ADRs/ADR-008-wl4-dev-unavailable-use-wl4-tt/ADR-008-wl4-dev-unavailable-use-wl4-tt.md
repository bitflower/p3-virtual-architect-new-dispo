# [ADR008] Use WL4-T-T for Development Due to Missing WL4-DEV Environment

**Status:** Approved (by Christian, 2026-04-21)
**Date:** 2026-04-20

## Context

The original environment pipeline for New Dispo planned a dedicated **WL4-DEV** GCP project for development and feature testing. This environment was part of the standard stage progression: LOCAL -> DEV -> TEST -> UAT -> PROD.

As of April 2026, **WL4-DEV does not exist and is blocked** (confirmed by Matt Wilkinson, 2026-04-20). P3 requires additional environments beyond what is currently available -- specifically the ones that were originally planned but have not been provisioned. Without a DEV environment, developers cannot deploy and test WL4 workloads (Frontend, Backend, CloudSQL) in a GCP-hosted stage before TEST.

#### Options Considered

1. **Development environment for WL4:**
    * **Option A: Wait for WL4-DEV provisioning** -- defer development work until the originally planned DEV project is made available
    * **Option B: Use WL4-T-T for development** -- deploy development builds to the existing TEST environment (WL4-T-T) as a workaround

## Decision

**Option B: Use WL4-T-T for development.** Development and feature testing deployments for WL4 workloads will target the TEST environment (`prj-cal-w-wl4-t-4c48-53ad`) until a dedicated DEV environment becomes available.

## Rationale

* **Option B (use WL4-T-T):** WL4-DEV is blocked with no timeline for resolution. P3 cannot wait indefinitely -- active development and the 1060 go-live require a functioning GCP environment for integration testing. WL4-T-T already exists and is operational, making it the only viable near-term option.

* **Option A (wait for WL4-DEV):** Rejected because it would stall development progress. There is no confirmed date for WL4-DEV provisioning, and the 1060 go-live timeline does not allow for indefinite delays.

## Consequences

* **Positive**: Development and feature testing can proceed without further delay; no new infrastructure provisioning required.
* **Negative**: Additional DevOps capacity is required to set up deployment pipelines targeting WL4-T-T for development purposes. These deployments will need to be torn down and reconfigured once a proper DEV environment becomes available or when the TEST environment is needed exclusively for integration/E2E testing. Mixing development and test workloads in a single environment increases the risk of interference between dev deployments and formal test runs.

## References

* [GoLive 1060 (Oracle)](../../02_Explorations/2026-04-17_New_Dispo_GoLive_1060_Oracle/new-dispo-golive-1060-oracle.md) -- holistic environment and go-live overview where this gap was identified

## Document History

| Date       | Author       | Change                                                    |
| ---------- | ------------ | --------------------------------------------------------- |
| 2026-04-20 | Matthias Max | Initial ADR created based on feedback from Matt Wilkinson |
| 2026-04-21 | Matthias Max | Status updated to Approved (approved by Christian)         |

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
