Hi Christian, hi Pascal,

We need an additional environment for the Dispo acceptance process to properly live the target process.

**Current Situation:**

After an exchange with Dominik Landau (February 11) we identified that WL4 doesn't have the standard 4-environment setup (Shared, Dev, Test, Prod) that typically comes out of the box for GCP workloads. The attached GCP landscape overview clearly shows the missing Dev environment for WL4.

**Proposed Solution:**

Dominik can support setting up the missing Dev environment with roughly one hour of effort.

**Usage:**

The new environment will be used for UAT testing and connect to:
- UAT2820
- UAT1034 (potentially behind schema-wise)

**Naming Convention:**

The environment will technically be called "DEV" in GCP. We'll harmonize the usage and naming in the future, but not immediately. I need to lead internal discussions first to decide on the approach here.

**Next Priority:**

The upleveling of the GCP workload landscape remains our next major focus.

**Request:**

I wanted to align with you and get your go for this setup.

Thank you,
Matthias
