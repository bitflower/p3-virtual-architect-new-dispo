# Holistic Tour Calculation Tracing

**Created:** 2026-03-10
**Status:** Ready for V1 Implementation
**Priority:** High
**Approach:** Incremental (V1 → V2)

## Overview

This exploration provides a distributed tracing solution for debugging tour calculation issues. The solution is split into two phases:

- **V1 (Minimal)**: Local-first, focuses on components you control (Frontend, Backend, TMS Bridge)
- **V2 (Future)**: Extends to external components (TMS Database, TOP Service, xServer)

## Problem

Tour calculations fail or produce incorrect results, particularly around time zones and date calculations. Currently, the team speculates about where issues occur rather than having data-driven insights.

## Solution Approach

### V1: Quick Wins with Minimal Risk ⭐ **START HERE**

Implement tracing in the 3 components you control as a service provider:
- ✅ Frontend (Angular)
- ✅ Backend (.NET Core)
- ✅ TMS Bridge (GraphQL)

**Benefits:**
- Implement in 3-4 days
- No external dependencies or coordination
- Test locally immediately
- Proves value before bigger investment

**What you'll see:**
- Complete PoolDTO received from TMS Bridge
- PoolDTO before/after TOP Service (black box analysis)
- Performance bottlenecks in your code
- Integration contract validation

### V2: Deep Instrumentation (Future)

Only pursue after V1 proves valuable. Requires coordination with:
- Database team (schema changes)
- CAL team (TOP DLL modifications)

See [v2-future-enhancements.md](./v2-future-enhancements.md) for details.

## Documents in This Exploration

### 🚀 [concept-v1-minimal.md](./concept-v1-minimal.md) - **READ THIS FIRST**
**Purpose:** Implementation-ready concept for V1

**Scope:** Frontend, Backend, TMS Bridge only (components you control)

**Key Sections:**
- 11 capture points in your components
- Storage options (in-memory, logs, files)
- Complete code examples for all 3 components
- Day-by-day implementation plan (4 days)
- Local testing instructions
- Analysis examples showing what you can learn

**Implementation Time:** 3-4 days

**Read this if:** You're ready to implement the tracing system

---

### 📋 [v2-future-enhancements.md](./v2-future-enhancements.md) - Future Consideration
**Purpose:** Ideas for extending tracing to external components

**Scope:** TMS Database, TOP Service, xServer (components you don't control)

**Key Sections:**
- Database stored procedure instrumentation
- TOP Service internal tracing
- xServer request/response capture
- Persistent storage with querying
- Trace visualization UI
- Decision criteria for V2

**Implementation Time:** 13+ weeks (if all features)

**Read this if:** V1 is complete and you want to go deeper

---

### 📖 [implementation-guide.md](./implementation-guide.md) - Detailed Reference
**Purpose:** Step-by-step implementation instructions (original comprehensive version)

**Note:** This is the original guide covering all components. For V1, refer to [concept-v1-minimal.md](./concept-v1-minimal.md) instead.

---

### 🔍 [analysis-scenarios.md](./analysis-scenarios.md) - Debugging Workflows
**Purpose:** How to use traces to debug specific issues

**Key Sections:**
- Time zone debugging queries
- Data transformation analysis
- Performance bottleneck identification
- Error diagnosis workflows

**Read this if:** You have traces and need to analyze them

---

### 📚 [concept.md](./concept.md) - Original Full Concept
**Purpose:** Original comprehensive design (all components)

**Note:** This is the original concept. For a focused implementation approach, use [concept-v1-minimal.md](./concept-v1-minimal.md) for V1 and [v2-future-enhancements.md](./v2-future-enhancements.md) for future enhancements.

## Quick Start

### For Developers (Implementing V1)

1. **Read:** [concept-v1-minimal.md](./concept-v1-minimal.md)
2. **Day 1:** Implement trace ID propagation (Frontend, Backend, TMS Bridge)
3. **Day 2:** Add trace capture service
4. **Day 3:** Add backend capture points
5. **Day 4:** Add TMS Bridge capture points
6. **Day 5:** Test with real tour calculation
7. **Week 2:** Use traces to debug actual issues, prove value

### For Architects (Evaluating Approach)

1. **Read:** [concept-v1-minimal.md](./concept-v1-minimal.md) - V1 scope and benefits
2. **Read:** V1 Capture Points section (11 total)
3. **Review:** Storage Strategy section
4. **Evaluate:** 3-4 day implementation vs. value proposition
5. **Decide:** Proceed with V1 or not

### For Decision Makers (Approval)

**V1 Investment:**
- Time: 3-4 days development + 1 week validation
- Risk: Low (only your components, easily reversible)
- Dependencies: None
- Value: Eliminate speculation, data-driven debugging

**Decision Point:** Approve V1, then evaluate V2 after proving value

## V1 Architecture at a Glance

```
┌─────────────────────────────────────────────┐
│ YOUR CONTROL - V1 SCOPE                     │
│                                             │
│  Frontend → Backend → TMS Bridge            │
│  (11 capture points total)                 │
│                                             │
│  ✓ Trace ID flows through all 3            │
│  ✓ Capture PoolDTO at boundaries           │
│  ✓ Log to console/files                    │
│  ✓ Works locally immediately                │
└─────────────┬───────────────────────────────┘
              │
              ▼
       ┌─────────────┐
       │ TMS Database│  ← V2 (future)
       │ TOP Service │  ← V2 (future)
       │ xServer     │  ← V2 (future)
       └─────────────┘
```

## V1 Capture Points (11 Total)

| Component | Points | Key Captures |
|-----------|--------|--------------|
| Frontend | 2 | Request initiation, response received |
| Backend | 7 | Entry, before/after GetPoolDto, before/after TOP, before/after SetPoolDto, exit |
| TMS Bridge | 2 | GetXserverDto entry, SetXserverDto entry |

**Most Critical Captures:**
- Capture #5: Complete PoolDTO from TMS Bridge
- Capture #7: Enriched PoolDTO after TOP Service

These two give you before/after comparison without instrumenting external components.

## What V1 Can't Show You (Requires V2)

- ❌ How PoolDTO is generated inside TMS Database
- ❌ What TOP Service does internally
- ❌ xServer request/response details
- ❌ Database-level time zone handling

**But V1 shows you:**
- ✅ The PoolDTO your backend receives (complete structure)
- ✅ What TOP does to the PoolDTO (input vs. output)
- ✅ Where time zones are wrong in data you receive
- ✅ Performance bottlenecks in YOUR code

This is often enough to identify root causes!

## Storage Options (V1)

### Option 1: Structured Logs (Recommended)
- Uses existing logging infrastructure
- View in console or log files
- No database changes needed
- Works locally immediately

### Option 2: In-Memory Store
- Fast querying during development
- Lost on restart
- Perfect for local testing

### Option 3: Local JSON Files
- Survives restarts
- Easy to share with team
- Can commit example traces to repo

Choose based on your preference. All 3 work for V1.

## Success Metrics (V1)

After implementing V1, you should be able to:

- ✅ Generate unique trace ID for each tour calculation
- ✅ See trace ID flow through Frontend → Backend → TMS Bridge
- ✅ View complete PoolDTO received from TMS Bridge
- ✅ Compare PoolDTO before/after TOP Service
- ✅ Identify performance bottlenecks in your integration layer
- ✅ Debug issues without modifying TMS Database or TOP Service

## Implementation Timeline

### V1: Local-First Approach
- **Day 1**: Trace ID propagation (3 components)
- **Day 2**: Trace capture service
- **Day 3**: Backend capture points
- **Day 4**: TMS Bridge capture points
- **Week 2**: Validation and iteration

**Total:** ~1 week to implementation + validation

### V2: Future Enhancements (If Pursued)
- **Weeks 1-2**: Database instrumentation
- **Week 3**: TOP wrapper enhancement
- **Weeks 4-5**: Persistent storage
- **Week 6**: Query API
- **Weeks 7-9**: Visualization UI
- **Weeks 10-13**: TOP DLL full instrumentation (with CAL)

**Total:** ~13 weeks (if all features)

**Recommendation:** Only pursue V2 after V1 proves valuable

## Decision Point: V1 or V2?

### Reasons to Start with V1 ✅

- Want quick wins (days vs. months)
- Limited resources or time
- Need to prove value first
- Want to avoid external dependencies
- Most issues occur at integration boundaries (your code)
- Want something you can test locally

### Reasons to Go Straight to V2 ⚠️

- Already validated that boundary tracing isn't enough
- Have full buy-in and resources (3+ months)
- Have CAL and database team coordination secured
- Need deep visibility into external components from day 1

**Recommendation:** Start with V1. Most teams find boundary tracing sufficient.

## Related Documentation

- [ADR-002: xServer Integration for Tour Optimization](../../09_ADRs/ADR-002-xserver-integration-tour-optimization/ADR-002-xserver-integration-tour-optimization.md)
- [2025-07-28: TOP xServer Integration Refinement](../2025-07-28_TOP_xServer_integration_refinement.md)

## FAQ

**Q: Why not instrument everything from the start?**
A: V1 gives you 80% of the value with 20% of the effort. Prove value first, then expand.

**Q: Can I add database tracing later?**
A: Yes! V2 enhancements are additive. Start with V1, add V2 features incrementally.

**Q: What if V1 doesn't show me the root cause?**
A: V1 shows you which component has the issue. Then you can target V2 instrumentation for that specific component.

**Q: Do I need to implement all 11 capture points?**
A: Start with the critical ones (#5 and #7 - PoolDTO before/after TOP). Add others as needed.

**Q: Can I use this in production?**
A: V1 is designed for local development first. For production, consider sampling and performance impact.

**Q: How much disk space will this use?**
A: V1 with in-memory or logs: negligible. V1 with files: ~50-100KB per trace. V2 with database: ~4-5GB/month.

## Next Steps

1. ✅ **Review** [concept-v1-minimal.md](./concept-v1-minimal.md)
2. ✅ **Choose** storage option (recommended: structured logs)
3. ✅ **Implement** Day 1-4 plan
4. ✅ **Test** with a real tour calculation
5. ✅ **Analyze** first trace using captured data
6. ✅ **Validate** value (did it help debug an issue?)
7. ⚠️ **Decide** on V2 only after V1 proves valuable

## Questions Before Starting?

- [ ] Which storage option to use? (logs, in-memory, or files)
- [ ] Development environment ready?
- [ ] Team aligned on V1-first approach?
- [ ] Clear testing scenario identified?

Ready to start? Jump to [concept-v1-minimal.md](./concept-v1-minimal.md)!

---

**Remember:** The goal is eliminating speculation with data-driven debugging. V1 gets you there for issues at component boundaries. V2 adds depth if needed later.

**Last Updated:** 2026-03-10
**Status:** ✅ V1 ready for implementation | ⏳ V2 awaiting V1 validation
