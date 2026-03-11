# Implementation Plan: Holistic Tour Calculation Tracing V1

**Date:** 2026-03-10
**Status:** Ready for Execution
**Total Duration:** 4 days + 1 day validation
**Approach:** Phased with strategic parallelization

---

## Overview

This plan implements the V1 minimal tracing solution across three repositories using specialized agents and git worktrees for maximum parallelization while respecting dependencies.

### Repositories

| Repository | Path | Current Branch | Expert Agent |
|------------|------|----------------|--------------|
| Frontend | `Code/Disposition-Frontend` | master | frontend-expert |
| Backend | `Code/Disposition-Backend` | master | backend-expert |
| TMS Bridge | `Code/Disposition-Abstraction-Layer` | master | tms-bridge-expert |

### Branch Strategy

**Feature Branch:** `feature/tour-calculation-tracing-v1`

**Worktree Strategy:**
- **Day 1 (Sequential):** Single branch for coordinated trace ID propagation
- **Day 2+ (Parallel):** Worktrees for independent capture implementations

**Worktree Locations (Sibling Folders):**
```
Code/
├── Disposition-Frontend/              (main repo)
├── Disposition-Frontend-tracing-wt/   (worktree for parallel work)
├── Disposition-Backend/               (main repo)
├── Disposition-Backend-tracing-wt/    (worktree for parallel work)
├── Disposition-Abstraction-Layer/     (main repo)
└── Disposition-Abstraction-Layer-tracing-wt/ (worktree for parallel work)
```

---

## Implementation Phases

### Phase 1: Trace ID Propagation (Day 1) - SEQUENTIAL

**Goal:** Establish trace ID generation and propagation through all components

**Dependencies:** Must be sequential - each component depends on previous

**Branch Setup:**
```bash
# Create feature branch in all 3 repos (no worktrees yet)
cd Code/Disposition-Frontend && git checkout -b feature/tour-calculation-tracing-v1
cd Code/Disposition-Backend && git checkout -b feature/tour-calculation-tracing-v1
cd Code/Disposition-Abstraction-Layer && git checkout -b feature/tour-calculation-tracing-v1
```

#### Task 1.1: Frontend - Trace ID Generation (2 hours)
**Agent:** frontend-expert
**Priority:** 🔴 CRITICAL - Starts the trace

**Deliverables:**
1. Create `TraceIdService` (singleton)
   - Generate UUID v4 for trace ID
   - Store in service for current request
   - Provide getter method
2. Modify HTTP interceptor to add `X-Trace-Id` header
3. Add trace ID to tour calculation request initiation

**Files to Modify:**
- `libs/nagel-services/src/lib/trace/trace-id.service.ts` (new)
- `apps/nagel-cal-disposition/src/app/interceptors/http.interceptor.ts`
- Component that initiates tour calculation

**Test:**
```bash
nx test nagel-cal-disposition --testPathPattern=trace-id
```

---

#### Task 1.2: Backend - Trace ID Extraction (1.5 hours)
**Agent:** backend-expert
**Priority:** 🔴 CRITICAL - Middle of the chain
**Dependencies:** Task 1.1 complete

**Deliverables:**
1. Create middleware to extract `X-Trace-Id` from request headers
2. Store in `AsyncLocal<string>` for thread-safe access
3. Create `ITraceContext` interface and implementation
4. Register in DI container
5. Propagate to TMS Bridge GraphQL calls (add to headers)

**Files to Create:**
- `Infrastructure/Middleware/TraceContextMiddleware.cs`
- `Shared/Interfaces/ITraceContext.cs`
- `Infrastructure/TraceContext/TraceContext.cs`

**Files to Modify:**
- `Startup.cs` (add middleware, register DI)
- GraphQL client configuration (add trace ID to headers)

**Test:**
```bash
dotnet test --filter "FullyQualifiedName~TraceContext"
```

---

#### Task 1.3: TMS Bridge - Trace ID Reception (1.5 hours)
**Agent:** tms-bridge-expert
**Priority:** 🔴 CRITICAL - End of the chain
**Dependencies:** Task 1.2 complete

**Deliverables:**
1. Create GraphQL context extension to extract `X-Trace-Id` from headers
2. Store in request context
3. Create `ITraceContext` service
4. Log trace ID on entry

**Files to Create:**
- `Services/TraceContext/TraceContext.cs`
- `Services/TraceContext/ITraceContext.cs`

**Files to Modify:**
- `Program.cs` (HotChocolate configuration)
- `Startup.cs` or GraphQL setup

**Test:**
```bash
dotnet test --filter "FullyQualifiedName~TraceContext"
```

---

#### Phase 1 Completion Criteria
- ✅ Trace ID generated in Frontend
- ✅ Trace ID propagates to Backend via HTTP header
- ✅ Trace ID propagates to TMS Bridge via GraphQL header
- ✅ All tests pass
- ✅ Manual test: Generate tour calculation, verify trace ID in all 3 logs

**Commit & Merge:** Commit changes in each repo, verify propagation end-to-end

---

### Phase 2: Trace Capture Services (Day 2) - PARALLEL

**Goal:** Create trace capture infrastructure in each component

**Dependencies:** Phase 1 complete, but individual services are independent

**Branch Setup:**
```bash
# Create worktrees for parallel development
cd Code/Disposition-Frontend && git worktree add ../Disposition-Frontend-tracing-wt feature/tour-calculation-tracing-v1
cd Code/Disposition-Backend && git worktree add ../Disposition-Backend-tracing-wt feature/tour-calculation-tracing-v1
cd Code/Disposition-Abstraction-Layer && git worktree add ../Disposition-Abstraction-Layer-tracing-wt feature/tour-calculation-tracing-v1
```

#### Task 2.1: Frontend - Trace Capture Service (2 hours)
**Agent:** frontend-expert
**Location:** `Code/Disposition-Frontend-tracing-wt/`
**Parallel:** ✅ Can run in parallel with 2.2 and 2.3

**Deliverables:**
1. Create `TraceCaptureService` (singleton)
   - In-memory storage (Map<traceId, TraceData>)
   - Non-blocking capture methods
   - Circuit breaker pattern
   - Max 100 traces retention
2. Create trace data models
3. Create console formatter for structured logs
4. Add DI registration

**Files to Create:**
- `libs/nagel-services/src/lib/trace/trace-capture.service.ts`
- `libs/nagel-services/src/lib/trace/models/trace-data.model.ts`
- `libs/nagel-services/src/lib/trace/models/capture-point.model.ts`

**Implementation Requirements:**
- Use RxJS `Subject` for non-blocking captures
- Implement buffer/debounce to batch logs
- Add try-catch around all operations (non-blocking!)
- Circuit breaker: auto-disable after 5 consecutive failures

---

#### Task 2.2: Backend - Trace Capture Service (3 hours)
**Agent:** backend-expert
**Location:** `Code/Disposition-Backend-tracing-wt/`
**Parallel:** ✅ Can run in parallel with 2.1 and 2.3

**Deliverables:**
1. Create `TraceCaptureService` class
   - ConcurrentDictionary for thread-safe storage
   - Non-blocking async captures
   - Circuit breaker pattern
   - Background cleanup task
2. Create capture point models/DTOs
3. Serilog enricher for trace context
4. Register in DI

**Files to Create:**
- `Infrastructure/TraceCapture/TraceCaptureService.cs`
- `Infrastructure/TraceCapture/ITraceCaptureService.cs`
- `Shared/Dtos/TraceCaptureDto.cs`
- `Infrastructure/Logging/TraceContextEnricher.cs`
- `Infrastructure/ServiceSetupExtensions/TraceCapture/TraceCaptureServiceSetupExtensions.cs`

**Implementation Requirements:**
- Use `Channel<T>` for async non-blocking queue
- Background task processes queue
- Circuit breaker: auto-disable after 5 consecutive failures
- Configurable: max traces (default 100), retention time
- Never throw exceptions to caller

---

#### Task 2.3: TMS Bridge - Trace Capture Service (2.5 hours)
**Agent:** tms-bridge-expert
**Location:** `Code/Disposition-Abstraction-Layer-tracing-wt/`
**Parallel:** ✅ Can run in parallel with 2.1 and 2.2

**Deliverables:**
1. Create `TraceCaptureService` class
   - ConcurrentDictionary for storage
   - Non-blocking captures
   - Circuit breaker pattern
2. Create capture models
3. Serilog enricher
4. Register in DI

**Files to Create:**
- `Services/TraceCapture/TraceCaptureService.cs`
- `Services/TraceCapture/ITraceCaptureService.cs`
- `Models/TraceCaptureModel.cs`
- `Logging/TraceContextEnricher.cs`

**Implementation Requirements:**
- Use async Task.Run for non-blocking
- Circuit breaker with auto-recovery
- Structured logging with Serilog
- Never throw to caller

---

#### Phase 2 Completion Criteria
- ✅ All 3 services created and tested independently
- ✅ Unit tests pass
- ✅ Services can capture and retrieve data
- ✅ Circuit breakers work correctly
- ✅ No blocking operations

**Merge Strategy:**
```bash
# After all 3 tasks complete, merge from worktrees to main repos
cd Code/Disposition-Frontend-tracing-wt && git add . && git commit -m "Add trace capture service"
cd Code/Disposition-Backend-tracing-wt && git add . && git commit -m "Add trace capture service"
cd Code/Disposition-Abstraction-Layer-tracing-wt && git add . && git commit -m "Add trace capture service"

# Push from main repos
cd Code/Disposition-Frontend && git pull
cd Code/Disposition-Backend && git pull
cd Code/Disposition-Abstraction-Layer && git pull
```

---

### Phase 3: Backend Capture Points (Day 3) - PARALLEL

**Goal:** Implement all 7 backend capture points

**Dependencies:** Phase 2 complete

**Strategy:** Can parallelize into 3 sub-tasks by grouping related capture points

#### Task 3.1: Entry/Exit Capture Points (2 hours)
**Agent:** backend-expert
**Location:** `Code/Disposition-Backend-tracing-wt/`
**Parallel:** ✅ Can run with 3.2 and 3.3

**Capture Points:**
1. **CP-BE-1:** Request entry (controller method start)
2. **CP-BE-8:** Response exit (controller method end)

**Deliverables:**
- Add capture calls in tour calculation controller
- Capture request DTO at entry
- Capture response DTO at exit
- Add correlation data (user, timestamp)

**Files to Modify:**
- Tour calculation controller (identify specific file)
- May need command handler depending on architecture

---

#### Task 3.2: TMS Bridge Integration Captures (3 hours)
**Agent:** backend-expert
**Location:** `Code/Disposition-Backend-tracing-wt/` (different branch/commit)
**Parallel:** ✅ Can run with 3.1 and 3.3

**Capture Points:**
3. **CP-BE-2:** Before GetPoolDto call to TMS Bridge
4. **CP-BE-3:** After GetPoolDto call (🔥 CRITICAL - complete PoolDTO received)
5. **CP-BE-6:** Before SetPoolDto call to TMS Bridge
6. **CP-BE-7:** After SetPoolDto call

**Deliverables:**
- Wrap TMS Bridge GraphQL client calls
- Capture complete PoolDTO structure (deep clone)
- Capture errors/exceptions
- Add performance timing

**Files to Modify:**
- GraphQL client wrapper or command handler that calls TMS Bridge

---

#### Task 3.3: TOP Service Integration Captures (3 hours)
**Agent:** backend-expert
**Location:** `Code/Disposition-Backend-tracing-wt/` (different branch/commit)
**Parallel:** ✅ Can run with 3.1 and 3.2

**Capture Points:**
7. **CP-BE-4:** Before TOP Service call
8. **CP-BE-5:** After TOP Service call (🔥 CRITICAL - enriched PoolDTO)

**Deliverables:**
- Wrap TOP Service DLL calls
- Capture PoolDTO before enrichment
- Capture PoolDTO after enrichment (deep clone)
- Capture TOP configuration/parameters
- Add performance timing

**Files to Modify:**
- TOP Service wrapper or tour optimization command handler

---

#### Phase 3 Coordination

**Merge Conflicts:** Likely in same controller/handler files

**Resolution Strategy:**
1. Complete tasks in sequence: 3.1 → 3.2 → 3.3
2. OR use temporary feature branches per task, then merge:
   - `feature/tour-calculation-tracing-v1-be-entry-exit`
   - `feature/tour-calculation-tracing-v1-be-tms-bridge`
   - `feature/tour-calculation-tracing-v1-be-top-service`

**Recommendation:** Sequential execution within Day 3 to avoid merge conflicts

#### Phase 3 Completion Criteria
- ✅ All 7 backend capture points implemented
- ✅ No blocking operations
- ✅ Tests pass
- ✅ Manual test: Trigger tour calc, verify all 7 captures in logs

---

### Phase 4: TMS Bridge & Frontend Captures (Day 4) - PARALLEL

**Goal:** Complete remaining capture points

**Dependencies:** Phase 2 complete (services exist)

#### Task 4.1: TMS Bridge Capture Points (2 hours)
**Agent:** tms-bridge-expert
**Location:** `Code/Disposition-Abstraction-Layer-tracing-wt/`
**Parallel:** ✅ Can run with 4.2

**Capture Points:**
9. **CP-TB-1:** GetXserverDto entry
10. **CP-TB-2:** SetXserverDto entry

**Deliverables:**
- Add capture calls in GraphQL resolvers
- Capture request parameters
- Capture xServer data (request/response if available)
- Add performance timing

**Files to Modify:**
- GraphQL resolvers for GetXserverDto and SetXserverDto

---

#### Task 4.2: Frontend Capture Points (2 hours)
**Agent:** frontend-expert
**Location:** `Code/Disposition-Frontend-tracing-wt/`
**Parallel:** ✅ Can run with 4.1

**Capture Points:**
11. **CP-FE-1:** Request initiation (already partially done in Phase 1)
12. **CP-FE-2:** Response received

**Deliverables:**
- Enhanced request capture (add parameters, user context)
- Response capture (result data, errors, timing)
- Console logging for debugging

**Files to Modify:**
- Tour calculation component/service
- HTTP interceptor (optional)

---

#### Phase 4 Completion Criteria
- ✅ All 11 capture points implemented
- ✅ End-to-end trace works
- ✅ All tests pass
- ✅ Manual validation complete

---

### Phase 5: Integration Testing & Validation (Day 5) - SEQUENTIAL

**Goal:** Validate entire tracing system works end-to-end

**Participants:** All developers involved

#### Task 5.1: End-to-End Test Scenarios (3 hours)
1. **Happy Path:** Successful tour calculation
   - Verify all 11 capture points fire
   - Verify trace ID propagation
   - Verify data captured (especially PoolDTO before/after TOP)

2. **Error Scenarios:**
   - TMS Bridge returns error
   - TOP Service fails
   - Validation failure
   - Verify traces still captured, no blocking

3. **Performance Test:**
   - Run 10 consecutive calculations
   - Verify no memory leaks
   - Verify cleanup works
   - Verify circuit breaker recovery

#### Task 5.2: Storage Strategy Selection (2 hours)
**Decide and configure:**
- Option 1: Structured logs (recommended) - configure Serilog
- Option 2: In-memory with query endpoint - add REST API
- Option 3: JSON file export - add export functionality

#### Task 5.3: Documentation (2 hours)
1. Update README in exploration folder
2. Add "How to Use Traces" guide
3. Document trace data format
4. Add troubleshooting guide

---

## Agent Assignment Summary

| Phase | Task | Agent | Duration | Parallel |
|-------|------|-------|----------|----------|
| 1 | Frontend Trace ID | frontend-expert | 2h | ❌ Sequential |
| 1 | Backend Trace ID | backend-expert | 1.5h | ❌ After 1.1 |
| 1 | TMS Bridge Trace ID | tms-bridge-expert | 1.5h | ❌ After 1.2 |
| 2 | Frontend Capture Service | frontend-expert | 2h | ✅ Parallel |
| 2 | Backend Capture Service | backend-expert | 3h | ✅ Parallel |
| 2 | TMS Bridge Capture Service | tms-bridge-expert | 2.5h | ✅ Parallel |
| 3 | Backend Entry/Exit | backend-expert | 2h | ⚠️ Sequential* |
| 3 | Backend TMS Bridge Calls | backend-expert | 3h | ⚠️ Sequential* |
| 3 | Backend TOP Service Calls | backend-expert | 3h | ⚠️ Sequential* |
| 4 | TMS Bridge Captures | tms-bridge-expert | 2h | ✅ Parallel |
| 4 | Frontend Captures | frontend-expert | 2h | ✅ Parallel |
| 5 | Integration Testing | All | 7h | ❌ Sequential |

\* Can be parallel with careful merge planning or sequential to avoid conflicts

---

## Critical Path

```
Day 1:
  1.1 (2h) → 1.2 (1.5h) → 1.3 (1.5h) = 5 hours sequential

Day 2:
  max(2.1: 2h, 2.2: 3h, 2.3: 2.5h) = 3 hours parallel

Day 3:
  3.1 (2h) + 3.2 (3h) + 3.3 (3h) = 8 hours sequential (safer)
  OR max(3.1, 3.2, 3.3) = 3 hours if parallel merge strategy

Day 4:
  max(4.1: 2h, 4.2: 2h) = 2 hours parallel

Day 5:
  5.1 (3h) + 5.2 (2h) + 5.3 (2h) = 7 hours sequential
```

**Total:** 25 hours (3.1 days) with optimal parallelization

---

## Worktree Management

### Creating Worktrees (Day 2 Start)
```bash
# Frontend
cd /Users/matthiasmax/Documents/CAL\ Consult/Virtual\ Architect\ -\ New\ Dispo/Code/Disposition-Frontend
git worktree add ../Disposition-Frontend-tracing-wt feature/tour-calculation-tracing-v1

# Backend
cd /Users/matthiasmax/Documents/CAL\ Consult/Virtual\ Architect\ -\ New\ Dispo/Code/Disposition-Backend
git worktree add ../Disposition-Backend-tracing-wt feature/tour-calculation-tracing-v1

# TMS Bridge
cd /Users/matthiasmax/Documents/CAL\ Consult/Virtual\ Architect\ -\ New\ Dispo/Code/Disposition-Abstraction-Layer
git worktree add ../Disposition-Abstraction-Layer-tracing-wt feature/tour-calculation-tracing-v1
```

### Cleaning Up Worktrees (Day 5 End)
```bash
# After merging all changes and pushing
cd /Users/matthiasmax/Documents/CAL\ Consult/Virtual\ Architect\ -\ New\ Dispo/Code/Disposition-Frontend
git worktree remove ../Disposition-Frontend-tracing-wt

cd /Users/matthiasmax/Documents/CAL\ Consult/Virtual\ Architect\ -\ New\ Dispo/Code/Disposition-Backend
git worktree remove ../Disposition-Backend-tracing-wt

cd /Users/matthiasmax/Documents/CAL\ Consult/Virtual\ Architect\ -\ New\ Dispo/Code/Disposition-Abstraction-Layer
git worktree remove ../Disposition-Abstraction-Layer-tracing-wt
```

---

## Risk Mitigation

### Risk 1: Trace ID Propagation Fails
**Mitigation:** Phase 1 has explicit testing after each component

### Risk 2: Non-Blocking Requirement Violated
**Mitigation:** Code reviews after Phase 2, load testing in Phase 5

### Risk 3: Merge Conflicts in Phase 3
**Mitigation:** Sequential execution recommended for Day 3, or use sub-branches

### Risk 4: Performance Impact
**Mitigation:** Circuit breakers, sampling, async processing, Phase 5 performance tests

---

## Success Criteria

### Phase 1 Success
- [ ] Generate trace ID in Frontend
- [ ] Trace ID visible in Backend logs
- [ ] Trace ID visible in TMS Bridge logs
- [ ] No errors in propagation

### Phase 2 Success
- [ ] All 3 services created
- [ ] Services can store and retrieve traces
- [ ] Circuit breakers functional
- [ ] Unit tests pass

### Phase 3 Success
- [ ] All 7 backend capture points fire
- [ ] Complete PoolDTO captured before/after TOP
- [ ] No blocking behavior observed
- [ ] Tests pass

### Phase 4 Success
- [ ] All 11 capture points complete
- [ ] End-to-end trace visible
- [ ] Frontend can retrieve trace data

### Phase 5 Success
- [ ] Happy path test complete
- [ ] Error scenarios handled gracefully
- [ ] Performance acceptable (<10ms overhead)
- [ ] Documentation complete

---

## Post-Implementation

### Week 2: Real-World Validation
- Use traces to debug actual tour calculation issues
- Gather feedback from team
- Tune capture points as needed
- Decide on V2 investment

### Maintenance
- Monitor circuit breaker triggers
- Review captured traces periodically
- Clean up old traces (retention policy)
- Evaluate storage strategy

---

## Quick Reference Commands

### Start Implementation
```bash
# Phase 1 - Create branches
for repo in Disposition-Frontend Disposition-Backend Disposition-Abstraction-Layer; do
  cd "/Users/matthiasmax/Documents/CAL Consult/Virtual Architect - New Dispo/Code/$repo"
  git checkout -b feature/tour-calculation-tracing-v1
done
```

### Phase 2 - Create Worktrees
```bash
cd "/Users/matthiasmax/Documents/CAL Consult/Virtual Architect - New Dispo/Code"
cd Disposition-Frontend && git worktree add ../Disposition-Frontend-tracing-wt feature/tour-calculation-tracing-v1
cd Disposition-Backend && git worktree add ../Disposition-Backend-tracing-wt feature/tour-calculation-tracing-v1
cd Disposition-Abstraction-Layer && git worktree add ../Disposition-Abstraction-Layer-tracing-wt feature/tour-calculation-tracing-v1
```

### Check All Repos Status
```bash
for repo in Disposition-Frontend Disposition-Backend Disposition-Abstraction-Layer; do
  echo "=== $repo ==="
  cd "/Users/matthiasmax/Documents/CAL Consult/Virtual Architect - New Dispo/Code/$repo"
  git status -s
done
```

---

## Next Steps

1. ✅ Review this plan with team
2. ✅ Confirm agent assignments
3. ✅ Set up development environment
4. ✅ Execute Phase 1 (Day 1)
5. ⏳ Continue with subsequent phases

**Ready to start?** Begin with Phase 1, Task 1.1: Frontend Trace ID Generation using the frontend-expert agent.
