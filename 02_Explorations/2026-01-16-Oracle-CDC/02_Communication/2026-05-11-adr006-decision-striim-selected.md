**Subject:** [ADR006] Decision: Striim Selected for Oracle CDC — Go-Live 1060

**To:** Christian Lang, Matt Wilkinson, Ron Vervenne, Thomas Paulus, Martin Dittmann

---

**Status:** Accepted — Decision Date: 2026-04-28

**Decision:** Striim is the CDC solution for Go-Live 1060 (June 2026).

Decided in the April 28 follow-up meeting. The Datastream LogMiner approach (Option B3) was ruled out on April 21 due to unacceptable latency (~42-66 min). The Datastream Binary Log Reader (Option B2) is being explored in parallel as a potential post-go-live optimization but is not blocking the go-live decision.

**Rationale for Striim over waiting for Binary Log Reader:**

- Production-proven (~2 years streaming Oracle to GCP at Nagel)
- Sub-second latency confirmed in PoC (vs. Binary Log Reader's unproven performance at scale)
- License secured until October 2026 (borrowed Google license, extended by Matt Wilkinson)
- Binary Log Reader is in GCP Preview (not GA), requires excessive Oracle permissions beyond documentation, and has not been validated under production load
- Go-live deadline (June 2026) does not allow waiting for Binary Log Reader GA or further investigation

**Cost note:** Striim is currently running on a borrowed Google license (confirmed unsustainable). If Nagel must pay independently, marketplace pricing starts at $19,200/month (8-core minimum). Actual Striim quote required.

**Full ADR:** [ADR006 on Wiki] *(link to wiki page)*

Best regards,
Matthias Max
