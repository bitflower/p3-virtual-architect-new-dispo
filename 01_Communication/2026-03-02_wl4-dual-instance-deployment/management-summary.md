# Management Summary: WL4 Deployment Strategy

Hi Ron,

As discussed and requested by you and Matt, here is the decision regarding the WL4 deployment strategy.

**Decision:** We will deploy two instances of all New Dispo components in the WL4 TEST environment instead of one.

**Reason:** WL4 is missing the DEV environment which should have been there from the beginning.

**The problem:**
- WL1, WL2, WL3, WL5: each has DEV, TEST, and PROD
- WL4: only has TEST and PROD (DEV missing)
- We need an environment for internal testing before exposing to customers

**The solution:**
Deploy two instances in WL4 TEST:
1. Instance 1: internal testing (DEV-equivalent)
2. Instance 2: customer-facing testing (TEST-proper)

**Why this approach:**
- Bureaucratic overhead of provisioning a new DEV environment > accepting this technical debt
- Unblocks development immediately
- Maintains separation between internal and customer testing
- Reversible if WL4 DEV gets provisioned later

**Components affected:**
- New Dispo Backend and Frontend (WL4)
- New Dispo Database (WL4)
- KeyCloak (WL4)

WL5 components (TMS Bridge, Cloud Functions) not affected.

**Costs:**
Approx. 2x infrastructure costs in TEST environment (2x Cloud Run, 2x databases, etc.).

This is an anti-pattern compared to the other GCP setup and technical debt, but pragmatic given the alternative.

Full documentation: ADR-005

Thanks
Matthias
