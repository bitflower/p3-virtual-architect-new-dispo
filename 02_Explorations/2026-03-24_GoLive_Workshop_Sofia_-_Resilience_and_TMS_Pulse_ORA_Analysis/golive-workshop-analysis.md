# GoLive Workshop Sofia - Resilience & TMS Pulse ORA Analysis

**Date:** 2026-03-24
**Workshop Date:** 2026-03-19
**Location:** Sofia
**Participants:** Development Team (Maximilian, Matthias and team)

## Workshop Context

Last week, the entire development team gathered in Sofia for a comprehensive workshop focusing on the New Dispo go-live planned for June 2026. The workshop aimed to:
- Review all features and user stories in a timeboxed manner
- Identify risks, blockers, and assumptions
- Assess achievability of go-live goals
- Derive team setup based on estimates

**Key Constraint:** Target branch for go-live is undecided (either 1034 with Postgres or 1060 with Oracle).

---

## Main Topics

### TOPIC 1: Resilience - Transactional Behaviour

**Key Focus:** Handling distributed transaction failures between New Dispo and TMS databases

**Outcome:** Selected manual recovery mechanism with user-initiated retry (rejected: Outbox Pattern, Saga Pattern, complete architecture redesign)

📄 **[Full Analysis →](./resilience-transactional-behaviour.md)**

---

### TOPIC 2: TMS Pulse ORA Extension

**Key Focus:** Oracle database migration, testing strategy, and ensuring compatibility with both Postgres (1034) and Oracle (1060) branches

**Critical Dependencies:** Joachim/TMS Team for migration, CDC adapter configuration, comprehensive test plan

📄 **[Full Analysis →](./tms-pulse-ora-extension.md)**

---

### TOPIC 3: CDC Error Flow

**Key Focus:** Fixing CDC event acknowledgment, event ordering challenges, and performance issues (5+ minute delays)

**Critical Issues:** Proxy layer causing unrecoverable state, event ordering not guaranteed, need for direct DB connection via VPC

📄 **[Full Analysis →](./cdc-error-flow.md)**

---

## CROSS-CUTTING CONCERNS

### Timeline Pressures
- Only **~2 months** until June go-live
- Must prioritize minimal viable solutions
- Defer advanced patterns to post-go-live
- Accept limitations with documented assumptions

### Testing Capacity
- Manual testing workload concerns
- Need for additional QA resources
- Consider involving developers in testing
- Explore AI tools for test generation
- Automated test coverage needs improvement

### External Dependencies - HIGH RISK
- **TMS Team (Joachim):** Database migration, script execution, CDC configuration
- **Database Administrators:** Oracle migration, schema changes
- **DevOps (Dominik):** VPC setup for direct DB connection
- **P3 Support Team:** L2/L3 support for manual recovery

**Risk Mitigation:**
- Document all dependencies with deadlines
- Regular status checks with stakeholders
- Escalation paths for blocked items
- Buffer time for external delays

---

## Miro Board Reference

Workshop used Miro board for collaborative analysis.

📋 **[View Miro Board (SVG) →](./Miro%20New%20Dispo%202025%20(Internal)%20-%202026-03-19_Workshop-Sofia.svg)**

**Key sections documented:**
- Resilience / Transactional Behaviour (green stickies row)
- TMS Pulse ORA Extension (green stickies row)
- CDC Error Flow diagrams

---

## WORKSHOP REFLECTION

### What Went Well
- Comprehensive coverage of major topics
- Clear identification of trade-offs
- Honest assessment of limitations
- Team alignment on minimal viable approach
- Documentation of assumptions for client approval

### Challenges
- Complexity of topics led to timebox overruns
- Many external dependencies identified
- Some questions require stakeholder input
- Political/resource constraints (DevOps availability)
- Balance between ideal solution and realistic timeline

### Key Takeaways
1. **Realism over Perfection:** Team chose pragmatic solutions over ideal architectures
2. **Foundation Building:** Manual recovery sets stage for future outbox pattern
3. **Assumption Documentation:** Critical for managing client expectations
4. **External Dependencies = Risk:** Must actively manage TMS team, DevOps, support
5. **Testing is Non-Negotiable:** Comprehensive test plan required for Oracle migration

---

## APPENDIX: SOURCE MATERIALS

- **Transcript Part 1:** 2026-03-19_GoLive Workshop - Sofia - New Dispo.vtt
- **Transcript Part 2:** 2026-03-19_GoLive Workshop - Sofia - New Dispo_Part2.vtt
- **CoPilot Summary Part 1:** CoPilot_Summary_part1.md
- **CoPilot Summary Part 2:** CoPilot_Summary_part2.md
- **Miro Board:** Miro New Dispo 2025 (Internal) - 2026-03-19_Workshop-Sofia.svg
- **Miro Diagrams (User provided):** Transactional Behaviour Scenario 2, CDC Error Flow Implementation Options

**Note:** CoPilot summaries may contain inaccuracies. Primary source is VTT transcripts, though limited by single-microphone recording (no speaker separation).
