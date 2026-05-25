# Tour Calculation Tracing - Shared Code Analysis

**Date:** 2026-05-24
**Status:** Decision Taken
**Work Item:** [#123587](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_workitems/edit/123342)

<!-- internal -->
---

## Original User Input

The `feature/tour-calculation-tracing-v1` branch introduces end-to-end tracing across three repos (TMS Bridge, Backend, Frontend). During PR cleanup we identified significant code duplication between Backend and TMS Bridge. This exploration documents what is duplicated, what sharing infrastructure exists today, and the decision to scope tracing to Backend only.

---

## User Story

### Tour Calculation Tracing

**As a** dispatcher or developer debugging a tour calculation,
**I want to** see a detailed timeline of what happened during a calculate-routes request — how long each step took, what data was passed, and where errors occurred,
**so that** I can identify performance bottlenecks and diagnose failures without access to cloud logging infrastructure.

### Problem Statement

Tour calculation involves multiple services (Backend, TMS Bridge, TOP) and several sequential steps (GetPoolDto, TOP optimization, SetPoolDto). When a calculation is slow or fails, there is no way to understand which step caused the issue or how long each step took. Diagnosing problems currently requires access to GCP Cloud Logging, correlating timestamps across multiple log streams manually, and deep system knowledge.

### Requirements

**Opt-in activation**
- Tracing is off by default and must not affect normal request performance
- A user can enable tracing for a specific tour calculation from the Frontend UI
- No environment variables, feature flags, or deployments needed to activate

**Unified trace identity**
- A single trace ID is shared across Frontend and Backend for one calculation request
- The Frontend generates the trace ID and passes it to the Backend
- All trace data from both components is correlated under this single ID

**Self-contained results**
- The complete trace (Frontend + Backend capture points) must be available in the Frontend immediately after the calculation completes
- No dependency on cloud logging, external dashboards, or separate API calls to retrieve traces
- The trace result is returned as part of the calculate-routes response

**Capture points**
- The trace captures timing and context at each boundary in the calculation flow:
  - Request entry and exit (Frontend and Backend)
  - Before/after each TMS Bridge call (GetPoolDto, SetPoolDto)
  - Before/after the TOP service call
- Each capture point includes: timestamp, duration since previous point, component name, and contextual data

**Non-functional**
- Tracing must not break the calculation if it fails internally (fault-tolerant)
- Tracing overhead on the response payload is acceptable only when actively tracing
- Works identically in local development and cloud environments

### Acceptance Criteria

1. User can enable tracing via a UI control before triggering a tour calculation
2. The calculate-routes response includes a `traceData` field containing all Backend capture points (when tracing is active)
3. The Frontend displays or exports the combined trace timeline (FE + BE points) with durations
4. When tracing is not active, the response contains no trace data and no performance overhead is added
5. A failed capture point does not cause the tour calculation to fail
<!-- /internal -->

---

## Decision: Backend-Only Tracing

**The Backend is the single control center for business logic.** From a tracing perspective, the Backend and TMS Bridge are treated as one node of execution. All tracing infrastructure lives in the Backend only; the TMS Bridge receives no tracing code.

### Rationale

The Backend already wraps every TMS Bridge call with before/after capture points, giving full round-trip visibility:

```
Frontend → Backend                                        → Frontend
             │                                          │
             CP-BE-1: Request entry                     CP-BE-8: Response exit
             CP-BE-2: Before GetPoolDto ──→ TMS Bridge ──→ CP-BE-3: After GetPoolDto
             CP-BE-4: Before TOP call                   CP-BE-5: After TOP call
             CP-BE-6: Before SetPoolDto ──→ TMS Bridge ──→ CP-BE-7: After SetPoolDto
```

The Backend captures:
- Complete request lifecycle (CP-BE-1 through CP-BE-8)
- Full PoolDTO payloads at every stage
- Round-trip durations for each TMS Bridge call (including network)
- TOP service call timing
- Error information at every boundary

### Original Three-Level Trace Flow (Including TMS Bridge)

For reference, this was the full capture point flow before scoping down:

```
Frontend
  └─ CP-BE-1: Request entry (controller)
  └─ CP-BE-2: Before GetPoolDto → TMS Bridge
       └─ CP-TB-1: GetXserverDto query entry            ← inside TMS Bridge
       └─ CP-TB-1-Complete: GetXserverDto completed      ← inside TMS Bridge
  └─ CP-BE-3: After GetPoolDto (PoolDTO received)
  └─ CP-BE-4: Before TOP Service call
  └─ CP-BE-5: After TOP Service call (enriched PoolDTO)
  └─ CP-BE-6: Before SetPoolDto → TMS Bridge
       └─ CP-TB-2: SetXserverDto mutation entry          ← inside TMS Bridge
       └─ CP-TB-2-Complete: SetXserverDto completed      ← inside TMS Bridge
       └─ CP-TB-2-Error: SetXserverDto failed            ← inside TMS Bridge
  └─ CP-BE-7: After SetPoolDto
  └─ CP-BE-8: Response exit (controller)
```

The CP-TB-* points are what we drop. The CP-BE-* points already bracket every TMS Bridge call, so round-trip timing is preserved.

### What We Lose (Acceptable)

Without TMS Bridge capture points (CP-TB-*), we cannot distinguish:
- Whether TMS Bridge latency is network vs. database query time
- Internal TMS Bridge error context before it surfaces as a GraphQL error

Both are refinements, not fundamentals. The Backend's before/after timing already captures total TMS Bridge duration. If internal TMS Bridge visibility becomes needed later, it can be added without changing the Backend's tracing contract.

### What We Gain

- No tracing code in TMS Bridge at all — zero PR footprint there
- No shared code problem — duplication question becomes moot
- No cross-repo coordination for tracing changes
- Simpler mental model: one component owns tracing, one place to debug

---

## Decision: Trace Activation and Resolution

### Context

Three sub-questions need answering:
1. **Activation**: How is tracing enabled? Always-on, per-environment, or per-request?
2. **Unified ID**: How do Frontend and Backend share a trace identity?
3. **Resolution**: Where are traces collected and how are they viewed?

### Decision: Response-Embedded Trace Data

Trace data is collected in-memory during Backend request processing and returned as part of the HTTP response. The Frontend is the single collection point — it combines its own capture points with the Backend trace data from the response.

```
┌─────────────────────────────────────────────────────────────┐
│ Frontend (collection point)                                 │
│                                                             │
│  1. User enables tracing (opt-in toggle)                    │
│  2. CP-FE-1 captured locally                                │
│  3. POST /calculate-routes  ──── X-Trace-Id: <uuid> ────►  │
│                                                             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Backend (in-memory capture during request)             │ │
│  │   CP-BE-1 → CP-BE-2 → CP-BE-3 → ... → CP-BE-8       │ │
│  │                                                        │ │
│  │   Response body includes:                              │ │
│  │   { ...normalPayload, traceData: { capturePoints } }  │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                             │
│  4. Response received ◄───── includes Backend trace data    │
│  5. CP-FE-2 captured locally                                │
│  6. Frontend merges: CP-FE-1 + CP-BE-1..8 + CP-FE-2        │
│     = complete trace (10 points)                            │
└─────────────────────────────────────────────────────────────┘
```

**Activation**: Opt-in per request. Frontend UI toggle (button or keyboard shortcut) controls whether a trace ID is generated and attached. No trace ID = Backend skips all capture logic. No environment variable needed.

**Unified ID**: Frontend generates a UUID via `crypto.randomUUID()`, attaches it as `X-Trace-Id` header. Backend middleware picks it up. Already implemented.

**Resolution**: No external infrastructure needed. The response carries the trace. The Frontend can display it, export it, or log it to console.

### Options Considered

#### Option A: Response-Embedded Trace Data (Chosen)

The Backend's `TraceCaptureService` collects capture points in memory during the request. The controller attaches the trace data to the response DTO when a trace ID is present. The Frontend merges its own points with the response data.

| Aspect | Assessment |
|--------|-----------|
| Cloud-ready | Yes — no dependency on log infrastructure |
| Infrastructure needed | None — uses existing request/response cycle |
| Latency impact | Negligible — in-memory collection, one extra response field |
| Frontend+Backend combined | Yes — Frontend is the single collection point |
| Persistence | Transient — lives as long as the Frontend keeps it |
| Works locally | Yes — same mechanism everywhere |

**Why chosen**: Zero infrastructure overhead. Self-contained within the existing HTTP request/response. Works identically in local dev and cloud. The Frontend already has its own capture points and can trivially merge them with the Backend data from the response.

#### Option B: GCP Cloud Logging Query (Declined)

The `TraceContextEnricher` already tags every Serilog log line with the trace ID. In GCP Cloud Logging, traces can be resolved by querying `jsonPayload.TraceId="<uuid>"`.

| Aspect | Assessment |
|--------|-----------|
| Cloud-ready | Yes — but *only* works in cloud |
| Infrastructure needed | GCP Cloud Logging access + query tooling |
| Latency impact | None — piggybacks on existing logging |
| Frontend+Backend combined | No — Frontend console logs are not in Cloud Logging |
| Persistence | Yes — retained per Cloud Logging retention policy |
| Works locally | No — local dev writes to file, not Cloud Logging |

**Why declined**: Doesn't work in local development. Frontend capture points are not in Cloud Logging, so you never get a unified view. Requires GCP access and query tooling — adds a dependency on infrastructure that not every team member has access to. The Serilog enricher remains useful for general log correlation but is not the primary trace resolution mechanism.

#### Option C: Backend Database Table (Declined)

Introduce a dedicated table (e.g., `trace_logs`) in the Backend's PostgreSQL database. The `TraceCaptureService` writes capture points to the table instead of (or in addition to) holding them in memory. A separate API endpoint serves trace data.

| Aspect | Assessment |
|--------|-----------|
| Cloud-ready | Yes |
| Infrastructure needed | DB migration, new table, new API endpoint, cleanup job |
| Latency impact | Moderate — DB writes on the hot path of tour calculation |
| Frontend+Backend combined | Partially — Backend only, Frontend still separate |
| Persistence | Yes — survives restarts, queryable historically |
| Works locally | Yes — if local DB is running |

**Why declined**: Introduces write operations on the critical path of tour calculation. Requires a DB migration, a new API endpoint to query traces, and a cleanup job to prevent unbounded growth. Over-engineered for a diagnostic tool — this is observability infrastructure, not a feature. The persistence benefit is not needed: traces are diagnostic, consumed immediately, and don't need to survive beyond the request/response cycle.

---

## Background: Duplication Analysis

The investigation that led to this decision found 6 out of 9 tracing components were functionally identical (copy-pasted) between Backend and TMS Bridge.

### Component Comparison

| Component | Backend Path | TMS Bridge Path | Verdict |
|-----------|-------------|-----------------|---------|
| TraceContext (core storage) | `Infrastructure/TraceContext/TraceContext.cs` | `Services/TraceContext/TraceContext.cs` | **IDENTICAL** |
| ITraceContext | `Shared/Interfaces/ITraceContext.cs` | `Services/TraceContext/ITraceContext.cs` | **IDENTICAL** |
| TraceContextEnricher | `Infrastructure/Logging/TraceContextEnricher.cs` | `Logging/TraceContextEnricher.cs` | **IDENTICAL** |
| CapturePoint DTO/Model | `Shared/Dtos/TraceCapture/CapturePointDto.cs` | `Models/TraceCapture/CapturePointModel.cs` | **IDENTICAL** (name: Dto vs Model) |
| TraceData DTO/Model | `Shared/Dtos/TraceCapture/TraceDataDto.cs` | `Models/TraceCapture/TraceDataModel.cs` | **IDENTICAL** (name: Dto vs Model) |
| ITraceCaptureService | `Infrastructure/TraceCapture/ITraceCaptureService.cs` | `Services/TraceCapture/ITraceCaptureService.cs` | **SIMILAR** (Dto vs Model type refs) |
| TraceCaptureService | `Infrastructure/TraceCapture/TraceCaptureService.cs` | `Services/TraceCapture/TraceCaptureService.cs` | **DIFFERENT** |
| Middleware | `Infrastructure/Middleware/TraceContextMiddleware.cs` | `Middleware/GraphQLRequest/TraceContextRequestMiddleware.cs` | **SIMILAR** (different frameworks) |
| Tests | `Tests/Infrastructure/TraceContext/TraceContextTests.cs` | `Tests/Services/TraceContext/TraceContextTests.cs` | **IDENTICAL** |

### Key Differences in Non-Identical Components

**TraceCaptureService** - the most significant divergence:
- Backend uses `Channel<T>` for bounded async queue with background processing task, implements `IDisposable`
- TMS Bridge uses simpler `Task.Run` per capture (no queue, no overflow protection)
- Both share circuit breaker logic, constants, and trace lifecycle methods

**Middleware** - different frameworks, same logic:
- Backend uses ASP.NET Core middleware (`HttpContext` directly)
- TMS Bridge uses HotChocolate GraphQL middleware (`IRequestContext`, service locator for `IHttpContextAccessor`)

## Sharing Infrastructure (For Reference)

**Finding: There is none.** This further supports the Backend-only decision.

- No shared NuGet packages (no `.nuspec`, no private feeds, no `nuget.config`)
- No cross-repo `<ProjectReference>` elements
- No git submodules (no `.gitmodules`)
- No shared project files (`.shproj`)
- Each repo has its own `.sln` with only internal projects
- Pre-existing duplication exists: CORS setup in TMS Bridge was copy-pasted with Backend's namespace still intact

### CI/CD Constraints

Both repos are built independently in Azure Pipelines:
- Each pipeline checks out only its own repo
- `dotnet publish` runs within repo boundary
- Output is packaged into a standalone Docker image
- No multi-repo checkout, no shared build context

A `<ProjectReference>` pointing outside the repo would fail with "file not found" in CI. Sharing code would require a private NuGet feed or git submodules — neither exists today.

## Consequences for Implementation

### TMS Bridge PR
- Revert all tracing code (capture points, middleware, services, models, tests)
- Keep only the `X-Trace-Id` header forwarding if useful for structured logging correlation
- Minimal or empty diff vs. master

### Backend PR
- Retains all 8 capture points (CP-BE-1 through CP-BE-8)
- Retains TraceContext, TraceCaptureService, middleware, DTOs
- Self-contained — no dependency on TMS Bridge tracing

### Frontend PR
- Unchanged — trace ID initiation and header propagation remain as-is

## Validation: Local Trace Captures (2026-05-25)

Two end-to-end trace captures were run locally to validate the Backend-only tracing implementation. The first run exposed a timing bug in `completeTrace` (reported 1 point / 0 ms); the second run confirmed the fix.

### Definitive Trace (Run 2 — post timing fix)

**Trace ID:** `ea109799-a1f1-49d7-8901-ad2fdd1a00b0` | **Total:** 4,018 ms | **Capture points:** 10

```
FE-1  |>                                                              |  Request initiated
BE-1  | >                                                             |  Backend received
BE-2  | >                                                             |  -> TMS Bridge: GetPoolDto
BE-3  |        >                                                      |  <- TMS Bridge: PoolDTO (549ms)
BE-4  |        >                                                      |  -> TOP Service
BE-5  |                                                      >        |  <- TOP Service: Enriched (3,083ms)
BE-6  |                                                      >        |  -> TMS Bridge: SetPoolDto
BE-7  |                                                            >  |  <- TMS Bridge: SetPool done (356ms)
BE-8  |                                                            >  |  Backend response sent (3,991ms total)
FE-2  |                                                             > |  Frontend received (4,018ms total)
      0s        1s        2s        3s        4s
```

| Phase | Duration | % of Total |
|---|---|---|
| Frontend → Backend transit | 9 ms | 0.2% |
| TMS Bridge: GetPoolDto | 549 ms | 13.7% |
| TOP Service optimization | 3,083 ms | **76.7%** |
| TMS Bridge: SetPoolDto | 356 ms | 8.9% |
| Backend overhead + response | 21 ms | 0.5% |
| **Total (FE-measured)** | **4,018 ms** | **100%** |

### Run Comparison

| Metric | Run 1 (cold) | Run 2 (warm) | Delta |
|---|---|---|---|
| Total (FE) | 6,433 ms | 4,018 ms | -37.5% |
| TMS Bridge: GetPoolDto | 767 ms | 549 ms | -28.4% |
| TOP Service | 5,145 ms | 3,083 ms | -40.1% |
| TMS Bridge: SetPoolDto | 403 ms | 356 ms | -11.7% |
| `completeTrace` points | 1 (bug) | 10 (fixed) | — |
| `completeTrace` duration | 0 ms (bug) | 4,000 ms (correct) | — |

### Key Findings

- **TOP Service dominates**: ~77–80% of total calculation time across both runs
- **TMS Bridge calls are fast**: GetPoolDto + SetPoolDto together account for ~20% (well under 1 second each)
- **Network/processing overhead is negligible**: Frontend ↔ Backend transit + Backend overhead < 1%
- **Warm-cache effect is significant**: 37.5% total reduction between runs, almost entirely from TOP Service (-40%)
- **Timing fix confirmed**: `completeTrace` correctly reports all 10 capture points and total duration after the fix

---

## Related Files

### Backend (Disposition-Backend) — keeps tracing
- `CALConsult.Disposition.API/Infrastructure/TraceContext/TraceContext.cs`
- `CALConsult.Disposition.API/Shared/Interfaces/ITraceContext.cs`
- `CALConsult.Disposition.API/Infrastructure/Logging/TraceContextEnricher.cs`
- `CALConsult.Disposition.API/Infrastructure/TraceCapture/ITraceCaptureService.cs`
- `CALConsult.Disposition.API/Infrastructure/TraceCapture/TraceCaptureService.cs`
- `CALConsult.Disposition.API/Shared/Dtos/TraceCapture/CapturePointDto.cs`
- `CALConsult.Disposition.API/Shared/Dtos/TraceCapture/TraceDataDto.cs`
- `CALConsult.Disposition.API/Infrastructure/Middleware/TraceContextMiddleware.cs`

### TMS Bridge (Disposition-Abstraction-Layer) — to be reverted
- `CALConsult.TMSBridge.API/Services/TraceContext/TraceContext.cs`
- `CALConsult.TMSBridge.API/Services/TraceContext/ITraceContext.cs`
- `CALConsult.TMSBridge.API/Logging/TraceContextEnricher.cs`
- `CALConsult.TMSBridge.API/Services/TraceCapture/ITraceCaptureService.cs`
- `CALConsult.TMSBridge.API/Services/TraceCapture/TraceCaptureService.cs`
- `CALConsult.TMSBridge.API/Models/TraceCapture/CapturePointModel.cs`
- `CALConsult.TMSBridge.API/Models/TraceCapture/TraceDataModel.cs`
- `CALConsult.TMSBridge.API/Infrastructure/Middleware/GraphQLRequest/TraceContextRequestMiddleware.cs`

## Related User Stories/Tasks

- [#123587 - Tour Calculation Tracing](https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_workitems/edit/123342)
