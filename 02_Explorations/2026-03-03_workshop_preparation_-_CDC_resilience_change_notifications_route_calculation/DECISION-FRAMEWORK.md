## Decision Matrix

| Topic | Option | Risk | Recommendation |
|-------|--------|------|----------------|
| **CDC Error** | A: HTTP 5xx + retry | Medium (idempotency) | ✓ Yes |
| | B: DLQ + manual | High (manual ops) | No |
| | C: Do nothing | High (data loss) | No |
| **Notifications** | A: SignalR coarse | Low | ✓ Yes |
| | B: SignalR fine | Medium | No |
| | C: Keep polling | None (bad UX) | No |
| **Route Calc** | A: CAL endpoint | High (dependency) | ✓ Yes (if CAL ready) |
| | B: Host TOP ourselves | High (Docker .NET 4.5) | Post-GoLive |
| | C: Rewrite TOP | Very High | No |

---

## Risks Summary

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| CDC fix takes longer | Medium | High | Timebox to 10 days, fallback to DLQ |
| xServer network blocked | High | Critical | Start VPN setup NOW |
| PTV license issue | Medium | Critical | Clarify with Joachim/Patrick this week |
| CAL endpoint unavailable | High | High | Build our own TOP service (Plan B) |
| Master data missing | Medium | High | Data quality sprint, fallback to basic calc |
| Route calc not ready June 1 | High | Medium | Defer, use manual routing temporarily |

**Highest Risk:** Route calculation - too many unknowns.
**Recommendation:** Discuss fallback plan (defer route calc post-GoLive if needed).
