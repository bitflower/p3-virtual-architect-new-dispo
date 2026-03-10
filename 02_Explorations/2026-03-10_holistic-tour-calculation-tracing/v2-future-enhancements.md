# V2 Future Enhancements - External Component Instrumentation

**Date:** 2026-03-10
**Version:** 2.0 - Future Enhancements
**Status:** Future Consideration (after V1 proves value)
**Dependencies:** V1 must be implemented and validated first

## Overview

This document outlines potential future enhancements that would extend tracing into components you don't directly control:
- TMS Database (PostgreSQL stored procedures)
- TOP Service (CAL DLL)
- xServer (PTV external API)

**Important:** These enhancements require coordination with external teams (CAL for TOP, database team for schema changes) and should only be pursued after V1 demonstrates value.

## Why V2?

V1 gives you visibility at **your component boundaries**. V2 would add visibility **inside external components**.

### What V1 Shows You
- ✅ PoolDTO received from TMS Bridge (complete structure)
- ✅ PoolDTO before/after TOP Service (input/output comparison)
- ✅ TOP Service as a "black box" (duration, success/failure)

### What V2 Would Add
- 📊 How PoolDTO is generated inside TMS Database
- 📊 What TOP Service does internally (before xServer call)
- 📊 Actual xServer request/response payloads
- 📊 Time spent in each sub-component

## V2 Enhancement 1: TMS Database Instrumentation

### Goal
Understand how PoolDTO is constructed from TMS tables.

### Implementation Requirements

**Prerequisite:** Database schema change permissions

#### 1. Create Trace Capture Table

```sql
-- Create trace schema
CREATE SCHEMA IF NOT EXISTS trace;

-- Create capture table
CREATE TABLE trace.capture (
    id BIGSERIAL PRIMARY KEY,
    trace_id VARCHAR(255) NOT NULL,
    component_name VARCHAR(100) NOT NULL,
    capture_point VARCHAR(255) NOT NULL,
    direction VARCHAR(50) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    data JSONB,
    metadata JSONB
);

CREATE INDEX idx_trace_capture_trace_id ON trace.capture(trace_id);
CREATE INDEX idx_trace_capture_timestamp ON trace.capture(timestamp);

-- Helper function
CREATE OR REPLACE FUNCTION trace.capture_log(
    p_trace_id VARCHAR(255),
    p_component_name VARCHAR(100),
    p_capture_point VARCHAR(255),
    p_direction VARCHAR(50),
    p_data JSONB DEFAULT NULL,
    p_metadata JSONB DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO trace.capture (
        trace_id, component_name, capture_point,
        direction, data, metadata
    ) VALUES (
        p_trace_id, p_component_name, p_capture_point,
        p_direction, p_data, p_metadata
    );
EXCEPTION
    WHEN OTHERS THEN
        -- Don't fail main transaction if trace logging fails
        RAISE WARNING 'Trace capture failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;
```

#### 2. Enhance Database Functions

**Update:** `pdis_transportorder.getxserverdto()`

```sql
CREATE OR REPLACE FUNCTION pdis_transportorder.getxserverdto(
    sid VARCHAR,
    trace_id VARCHAR DEFAULT NULL  -- Add optional trace_id parameter
) RETURNS TEXT AS $$
DECLARE
    v_frk_tix VARCHAR;
    v_pool_dto TEXT;
BEGIN
    -- Capture function entry
    IF trace_id IS NOT NULL THEN
        PERFORM trace.capture_log(
            trace_id,
            'TMSDatabase',
            'getxserverdto.Entry',
            'Request',
            jsonb_build_object('sid', sid)
        );
    END IF;

    -- Retrieve FRK_TIX
    SELECT frk_tix INTO v_frk_tix
    FROM frk_unt
    WHERE ta_tix = sid::BIGINT AND lfd_n = 1
    LIMIT 1;

    -- Capture FRK_TIX retrieval
    IF trace_id IS NOT NULL THEN
        PERFORM trace.capture_log(
            trace_id,
            'TMSDatabase',
            'FRK_TIX_Retrieved',
            'Response',
            jsonb_build_object('frk_tix', v_frk_tix, 'ta_tix', sid)
        );
    END IF;

    -- Call pTop_LoadingList.get()
    SELECT ptop_loadinglistdto.get(v_frk_tix, TRUNC(LOCALTIMESTAMP))
    INTO v_pool_dto;

    -- Capture PoolDTO generation
    IF trace_id IS NOT NULL THEN
        PERFORM trace.capture_log(
            trace_id,
            'TMSDatabase',
            'PoolDTO.Generated',
            'Response',
            v_pool_dto::JSONB,
            jsonb_build_object(
                'frk_tix', v_frk_tix,
                'dto_length', LENGTH(v_pool_dto)
            )
        );
    END IF;

    RETURN v_pool_dto;
END;
$$ LANGUAGE plpgsql;
```

**Update:** `pdis_transportorder.setxserverdto()`

```sql
CREATE OR REPLACE FUNCTION pdis_transportorder.setxserverdto(
    sjson TEXT,
    trace_id VARCHAR DEFAULT NULL  -- Add optional trace_id parameter
) RETURNS TEXT AS $$
DECLARE
    v_result TEXT;
BEGIN
    -- Capture entry
    IF trace_id IS NOT NULL THEN
        PERFORM trace.capture_log(
            trace_id,
            'TMSDatabase',
            'setxserverdto.Entry',
            'Request',
            sjson::JSONB,
            jsonb_build_object('json_length', LENGTH(sjson))
        );
    END IF;

    -- Call pTop_LoadingList.put()
    SELECT ptop_loadinglistdto.put(sjson)
    INTO v_result;

    -- Capture result
    IF trace_id IS NOT NULL THEN
        PERFORM trace.capture_log(
            trace_id,
            'TMSDatabase',
            'setxserverdto.Result',
            'Response',
            jsonb_build_object('result', v_result)
        );
    END IF;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;
```

#### 3. Update TMS Bridge to Pass Trace ID

```csharp
// In GetXserverDtoQuery.cs
var functionParameters = new RoutineParameterBuilder()
    .AddInput("sid", input.Id)
    .AddInput("trace_id", traceId)  // Add this line
    .Build();

// In SetXServerDtoMutation.cs
var procedureParameters = new RoutineParameterBuilder()
    .AddInput("sjson", poolDtoJsonString)
    .AddInput("trace_id", traceId)  // Add this line
    .Build();
```

### Benefits of Database Instrumentation

- 📊 See FRK_TIX lookup and mapping
- 📊 Understand PoolDTO generation process
- 📊 Identify database-level performance issues
- 📊 Trace time zone handling in stored procedures

### Risks & Considerations

- ⚠️ Requires database schema changes
- ⚠️ Need approval from database team
- ⚠️ Potential performance impact (mitigated by EXCEPTION handling)
- ⚠️ Need to coordinate stored procedure changes

## V2 Enhancement 2: TOP Service Internal Instrumentation

### Goal
Understand what TOP Service does between receiving PoolDTO and calling xServer.

### Implementation Options

#### Option A: Enhance TOP DLL (Requires CAL Coordination)

**Coordinate with CAL to add:**

```csharp
// In TOP DLL entry point
public class TOPService
{
    public PoolDto CalculateRoutes(PoolDto poolDto, string traceId = null)
    {
        if (!string.IsNullOrEmpty(traceId))
        {
            TraceLogger.Log(traceId, "TOPService.Entry", poolDto);
        }

        // Prepare xServer request
        var xServerRequest = PrepareXServerRequest(poolDto);

        if (!string.IsNullOrEmpty(traceId))
        {
            TraceLogger.Log(traceId, "BeforeXServerCall", new
            {
                Url = _xServerUrl,
                Request = xServerRequest
            });
        }

        // Call xServer
        var xServerResponse = CallXServer(xServerRequest);

        if (!string.IsNullOrEmpty(traceId))
        {
            TraceLogger.Log(traceId, "AfterXServerCall", new
            {
                Response = xServerResponse,
                Duration = _lastCallDuration
            });
        }

        // Process response
        var enrichedPoolDto = ProcessXServerResponse(xServerResponse, poolDto);

        if (!string.IsNullOrEmpty(traceId))
        {
            TraceLogger.Log(traceId, "TOPService.Exit", enrichedPoolDto);
        }

        return enrichedPoolDto;
    }
}
```

**Deliverables needed from CAL:**
1. Accept trace ID parameter in TOP DLL
2. Add logging at key points (entry, before xServer, after xServer, exit)
3. Publish updated NuGet package

#### Option B: Wrapper with Reflection (Immediate, Limited Visibility)

If CAL can't modify TOP DLL, wrap it:

```csharp
public class TracingTOPServiceWrapper : ITOPService
{
    private readonly ITOPService _innerService;
    private readonly ITraceCapture _traceCapture;
    private readonly IHttpContextAccessor _httpContextAccessor;

    public async Task<PoolDto> CalculateRoutes(
        PoolDto poolDto,
        CancellationToken cancellationToken)
    {
        var traceId = _httpContextAccessor.HttpContext?.Request.GetTraceId();

        // Capture input
        await _traceCapture.CaptureAsync(new TraceCapturePoint
        {
            TraceId = traceId,
            Component = "TOPService",
            CapturePoint = "Entry",
            Direction = "Request",
            Data = poolDto
        });

        var stopwatch = Stopwatch.StartNew();

        try
        {
            var result = await _innerService.CalculateRoutes(poolDto, cancellationToken);

            stopwatch.Stop();

            // Capture output
            await _traceCapture.CaptureAsync(new TraceCapturePoint
            {
                TraceId = traceId,
                Component = "TOPService",
                CapturePoint = "Exit",
                Direction = "Response",
                Data = new
                {
                    EnrichedPoolDto = result,
                    DurationMs = stopwatch.ElapsedMilliseconds
                }
            });

            return result;
        }
        catch (Exception ex)
        {
            stopwatch.Stop();

            await _traceCapture.CaptureAsync(new TraceCapturePoint
            {
                TraceId = traceId,
                Component = "TOPService",
                CapturePoint = "Error",
                Direction = "Response",
                Data = new
                {
                    Error = ex.Message,
                    DurationMs = stopwatch.ElapsedMilliseconds
                }
            });

            throw;
        }
    }
}
```

**Limitation:** Can only see input/output, not internal operations or xServer call details.

### Benefits of TOP Instrumentation

- 📊 See xServer request payload (what TOP sends to PTV)
- 📊 See xServer response payload (what PTV returns)
- 📊 Measure time spent in xServer vs. TOP processing
- 📊 Identify if issues are in TOP logic or xServer

### Risks & Considerations

- ⚠️ Requires coordination with CAL team
- ⚠️ May need NuGet package update and deployment
- ⚠️ CAL team may have different priorities
- ⚠️ Option B (wrapper) is limited but immediate

## V2 Enhancement 3: xServer Request/Response Capture

### Goal
Capture the actual HTTP requests/responses to/from xServer API.

### Implementation Options

#### Option A: HTTP Client Interceptor in TOP

If TOP DLL is enhanced, add HTTP client logging:

```csharp
// In TOP DLL
public class TracingHttpClientHandler : DelegatingHandler
{
    private readonly string _traceId;

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request,
        CancellationToken cancellationToken)
    {
        // Capture request
        var requestBody = request.Content != null
            ? await request.Content.ReadAsStringAsync()
            : null;

        TraceLogger.Log(_traceId, "XServer.Request", new
        {
            Url = request.RequestUri,
            Method = request.Method,
            Headers = request.Headers,
            Body = requestBody
        });

        var stopwatch = Stopwatch.StartNew();
        var response = await base.SendAsync(request, cancellationToken);
        stopwatch.Stop();

        // Capture response
        var responseBody = await response.Content.ReadAsStringAsync();

        TraceLogger.Log(_traceId, "XServer.Response", new
        {
            StatusCode = response.StatusCode,
            Headers = response.Headers,
            Body = responseBody,
            DurationMs = stopwatch.ElapsedMilliseconds
        });

        return response;
    }
}
```

#### Option B: Network-Level Capture (Development Only)

For local development, use a proxy:

```bash
# Use Fiddler, Charles, or mitmproxy to intercept xServer traffic
mitmproxy --mode reverse:http://10.32.3.102:30000 --listen-port 30001

# Configure TOP to use proxy
# In configuration: xServer URL = http://localhost:30001
```

**Limitation:** Only works in development, requires VPN and proxy setup.

### Benefits of xServer Capture

- 📊 See exact xServer API request (routes, constraints, vehicles)
- 📊 See exact xServer API response (calculated routes, times, distances)
- 📊 Measure xServer performance
- 📊 Identify if xServer is the bottleneck

### Risks & Considerations

- ⚠️ xServer is external (PTV), can't instrument their service
- ⚠️ Request/response payloads can be very large
- ⚠️ Network proxy approach only works in development
- ⚠️ Requires TOP DLL changes for production use

## V2 Enhancement 4: Persistent Storage with Querying

### Goal
Store traces in a database for long-term analysis and querying.

### Implementation

#### Database Storage Implementation

```csharp
public class DatabaseTraceCapture : ITraceCapture
{
    private readonly IDbContextFactory<TraceDbContext> _dbContextFactory;
    private readonly ILogger<DatabaseTraceCapture> _logger;

    public async Task CaptureAsync(TraceCapturePoint point)
    {
        try
        {
            await using var dbContext = await _dbContextFactory.CreateDbContextAsync();

            var entity = new TraceCaptureEntity
            {
                TraceId = point.TraceId,
                ComponentName = point.Component,
                CapturePoint = point.CapturePoint,
                Direction = point.Direction,
                Timestamp = point.Timestamp,
                Data = JsonSerializer.Serialize(point.Data),
                Metadata = JsonSerializer.Serialize(point.Metadata)
            };

            dbContext.TraceCaptures.Add(entity);
            await dbContext.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to persist trace capture");
        }
    }

    public async Task<List<TraceCapturePoint>> GetTraceAsync(string traceId)
    {
        await using var dbContext = await _dbContextFactory.CreateDbContextAsync();

        var entities = await dbContext.TraceCaptures
            .Where(t => t.TraceId == traceId)
            .OrderBy(t => t.Timestamp)
            .ToListAsync();

        return entities.Select(e => new TraceCapturePoint
        {
            TraceId = e.TraceId,
            Component = e.ComponentName,
            CapturePoint = e.CapturePoint,
            Direction = e.Direction,
            Timestamp = e.Timestamp,
            Data = JsonSerializer.Deserialize<object>(e.Data)
        }).ToList();
    }
}
```

#### Query API

```csharp
[ApiController]
[Route("api/trace")]
public class TraceController : ControllerBase
{
    [HttpGet("{traceId}")]
    public async Task<ActionResult<TraceDetailDto>> GetTrace(string traceId)
    {
        // Implementation
    }

    [HttpGet("recent")]
    public async Task<ActionResult<List<TraceSummaryDto>>> GetRecentTraces(
        [FromQuery] int limit = 100)
    {
        // Implementation
    }

    [HttpGet("search")]
    public async Task<ActionResult<List<TraceSummaryDto>>> SearchTraces(
        [FromQuery] string component,
        [FromQuery] DateTime? from,
        [FromQuery] DateTime? to)
    {
        // Implementation
    }

    [HttpGet("{traceId}/analyze")]
    public async Task<ActionResult<TraceAnalysisDto>> AnalyzeTrace(string traceId)
    {
        // Automated analysis: time zones, data transformations, performance
    }
}
```

### Benefits of Persistent Storage

- 📊 Query traces from past days/weeks
- 📊 Compare multiple traces
- 📊 Build analytics and dashboards
- 📊 Long-term trend analysis

### Risks & Considerations

- ⚠️ Storage costs (4-5GB per month estimated)
- ⚠️ Need retention policy and cleanup
- ⚠️ Query performance with large datasets
- ⚠️ Backup and disaster recovery

## V2 Enhancement 5: Trace Visualization UI

### Goal
Build a web UI for viewing and analyzing traces.

### Features

1. **Trace Timeline View**
   - Visual flowchart of request through components
   - Time spent in each stage
   - Identify bottlenecks visually

2. **Data Comparison View**
   - Side-by-side comparison of DTOs
   - Highlight differences between stages
   - Filter by field path

3. **Time Zone Inspector**
   - Extract all timestamp fields
   - Show timezone representation
   - Flag inconsistencies

4. **Search & Filter**
   - Find traces by date range
   - Filter by component
   - Search by transport order ID

### Implementation

```typescript
// Angular component
@Component({
  selector: 'app-trace-viewer',
  template: `
    <div class="trace-viewer">
      <h2>Trace: {{ traceId }}</h2>

      <!-- Timeline -->
      <div class="timeline">
        <div *ngFor="let capture of captures" class="capture-point">
          <div class="timestamp">{{ capture.timestamp | date:'HH:mm:ss.SSS' }}</div>
          <div class="component">{{ capture.component }}</div>
          <div class="capture-point-name">{{ capture.capturePoint }}</div>
          <div class="duration" *ngIf="capture.duration">
            {{ capture.duration }}ms
          </div>
        </div>
      </div>

      <!-- Data inspector -->
      <div class="data-inspector">
        <app-json-diff
          [before]="selectedCaptureData"
          [after]="nextCaptureData">
        </app-json-diff>
      </div>
    </div>
  `
})
export class TraceViewerComponent {
  // Implementation
}
```

### Benefits of Visualization UI

- 📊 Non-technical stakeholders can understand traces
- 📊 Faster issue identification
- 📊 Better collaboration (share trace links)
- 📊 Reduced learning curve

### Risks & Considerations

- ⚠️ Development effort (2-3 weeks)
- ⚠️ Need UI/UX design
- ⚠️ Maintenance overhead
- ⚠️ May need dedicated frontend resources

## Implementation Sequence (If Pursuing V2)

### V2.1: Database Instrumentation (2 weeks)
- Prerequisites: V1 validated, database team buy-in
- Effort: 1 week development, 1 week testing
- Dependencies: Schema changes approved

### V2.2: TOP Service Wrapper Enhancement (1 week)
- Prerequisites: V1 validated
- Effort: 3 days development, 2 days testing
- Dependencies: None (wrapper approach)

### V2.3: Persistent Storage (2 weeks)
- Prerequisites: V1 validated, V2.1 optional
- Effort: 1 week development, 1 week testing
- Dependencies: Database available

### V2.4: Query API (1 week)
- Prerequisites: V2.3 complete
- Effort: 3 days development, 2 days testing
- Dependencies: V2.3

### V2.5: Visualization UI (3 weeks)
- Prerequisites: V2.4 complete
- Effort: 2 weeks development, 1 week testing
- Dependencies: V2.3, V2.4

### V2.6: TOP DLL Full Instrumentation (4 weeks)
- Prerequisites: CAL coordination, agreement on approach
- Effort: 2 weeks CAL development, 2 weeks integration/testing
- Dependencies: CAL team availability

**Total V2 Effort (if all features pursued):** 13 weeks

## Decision Criteria for V2

Proceed with V2 enhancements only if:

1. ✅ V1 has been implemented and tested
2. ✅ V1 has proven valuable (solved real debugging issues)
3. ✅ V1 limitations are blocking important investigations
4. ✅ Stakeholder buy-in for additional investment
5. ✅ Resources available (database team, CAL coordination, frontend developers)
6. ✅ Clear ROI justification

## Alternative: Incremental V2

Rather than implementing all V2 features, consider incremental approach:

1. **Start with most valuable feature**: e.g., database instrumentation if time zone issues are most critical
2. **Pilot with one enhancement**: Prove value before investing in others
3. **Evaluate after each enhancement**: Continue or stop based on ROI

## V1 vs V2 Trade-offs

| Aspect | V1 (Minimal) | V2 (Full) |
|---|---|---|
| **Implementation Time** | 3-4 days | 13+ weeks |
| **Components Affected** | 3 (yours) | 6 (all) |
| **External Dependencies** | None | Many |
| **Storage** | In-memory/logs | Database |
| **Visibility** | Boundaries only | Internal operations |
| **Coordination Needed** | None | CAL, database team |
| **Risk** | Low | Medium-High |
| **Value** | Quick wins | Comprehensive |

## Recommendation

1. **Implement V1 first** - Get quick wins with minimal risk
2. **Validate V1's value** - Use it for 4-8 weeks on real issues
3. **Identify V1 limitations** - What questions can't V1 answer?
4. **Prioritize V2 features** - Pick 1-2 most valuable enhancements
5. **Pilot selected V2 features** - Test value before full investment

**Don't commit to full V2 upfront.** Build incrementally based on proven need.

## Conclusion

V2 enhancements offer deeper visibility but come with significant coordination overhead and dependencies. The V1 minimal approach gives you 80% of the value with 20% of the effort. Only invest in V2 if V1's limitations are blocking critical debugging scenarios.

**Next Step:** Focus on implementing and validating V1 first.
