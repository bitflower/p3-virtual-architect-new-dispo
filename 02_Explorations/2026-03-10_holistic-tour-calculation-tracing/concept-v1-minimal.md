# Holistic Tour Calculation Tracing - V1 Minimal (Local-First)

**Date:** 2026-03-10
**Version:** 1.0 - Minimal Viable Tracing
**Scope:** Frontend, Backend, TMS Bridge only
**Status:** Ready for Implementation

## Executive Summary

This minimal viable tracing solution focuses exclusively on the components you control as a service provider: **Frontend, Backend, and TMS Bridge**. It provides end-to-end visibility into your integration layer without requiring changes to TMS Database, TOP Service, or xServer.

**Goal:** Prove value quickly with a solution you can implement and test locally.

## ⚠️ NON-NEGOTIABLE: Non-Blocking Architecture

**The tracing system MUST be non-blocking at all stages and layers.**

This is not optional - it's a core architectural constraint:

- ✅ **Never blocks** the main business flow
- ✅ **Never throws exceptions** that fail the operation
- ✅ **Never impacts performance** negatively
- ✅ **Fire-and-forget** - capture async, process in background
- ✅ **Self-healing** - circuit breakers, auto-disable on failure
- ✅ **Resource-bounded** - limited queues, timeouts, sampling

**Rule:** If tracing fails, the business operation continues successfully.

All code examples in this document follow non-blocking patterns. Tracing is observability infrastructure - it must be invisible to the main application.

## Scope

### ✅ In Scope (Your Components)
- **Frontend** (Angular)
- **Backend** (.NET Core)
- **TMS Bridge** (GraphQL API)

### ❌ Out of Scope (External/Future V2)
- TMS Database stored procedures
- TOP Service (CAL DLL)
- xServer (PTV external API)

See [v2-future-enhancements.md](./v2-future-enhancements.md) for future expansion ideas.

## Architecture - V1 Minimal

```
┌─────────────────────────────────────────────────────────────────┐
│ YOUR CONTROL ZONE - V1 Scope                                    │
│                                                                 │
│  Frontend (Angular)                                             │
│    ↓ generates trace-id                                         │
│    ↓ HTTP Header: X-Trace-Id                                    │
│    ↓ CAPTURE #1: Calculate routes request initiated             │
│    │                                                            │
│  Backend (.NET)                                                 │
│    ↓ extracts trace-id                                          │
│    ↓ CAPTURE #2: CalculateRoutesCommand entry                   │
│    ↓ CAPTURE #3: Before GetPoolDto (TMS Bridge call)            │
│    ↓ CAPTURE #4: After GetPoolDto (PoolDTO received)            │
│    ↓ CAPTURE #5: Before TOP Service call                        │
│    ↓ CAPTURE #6: After TOP Service call                         │
│    ↓ CAPTURE #7: Before SetPoolDto (TMS Bridge call)            │
│    ↓ CAPTURE #8: After SetPoolDto response                      │
│    ↓ CAPTURE #9: Response to frontend                           │
│    │                                                            │
│  TMS Bridge (GraphQL)                                           │
│    ↓ receives trace-id in context                               │
│    ↓ CAPTURE #10: GetXserverDto query entry                     │
│    ↓ CAPTURE #11: SetXserverDto mutation entry                  │
│    ↓                                                            │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
                    ┌─────────────────┐
                    │  TMS Database   │ ← No changes (V1)
                    │  TOP Service    │ ← No changes (V1)
                    │  xServer        │ ← No changes (V1)
                    └─────────────────┘
```

## What You Can See (Without Database/TOP Changes)

Even without instrumenting external components, you can capture:

1. **Integration Contract Validation**
   - What PoolDTO your backend receives from TMS Bridge
   - Whether it matches expected structure
   - Field completeness and data types

2. **TOP Service Black Box Analysis**
   - PoolDTO going into TOP Service
   - Enriched PoolDTO coming out of TOP Service
   - Compare input vs. output to identify TOP transformations

3. **Data Flow Through Your Stack**
   - Request from frontend (transportOrderId, parameters)
   - All DTOs at your component boundaries
   - Response back to frontend

4. **Performance Bottlenecks in Your Code**
   - Time spent in each handler
   - TMS Bridge call latency
   - TOP Service call duration

5. **Error Propagation**
   - Where errors originate in your code
   - Error messages at each layer
   - Success/failure status at boundaries

## V1 Capture Points (11 Total)

### Frontend (2 capture points)

| #   | Capture Point     | When                           | What to Capture                            |
| --- | ----------------- | ------------------------------ | ------------------------------------------ |
| 1   | Request Initiated | User clicks "Calculate Routes" | `transportOrderId`, `timestamp`, `traceId` |
| 2   | Response Received | Backend responds               | `status`, `duration`, `success/error`      |

### Backend (7 capture points)

| #   | Capture Point      | When                                           | What to Capture                                     |
| --- | ------------------ | ---------------------------------------------- | --------------------------------------------------- |
| 3   | Command Entry      | `CalculateRoutesCommandHandler.Handle()` entry | `transportOrderId`, `databaseIdentifier`, `traceId` |
| 4   | Before GetPoolDto  | Before calling TMS Bridge `GetXserverDto`      | Request parameters                                  |
| 5   | After GetPoolDto   | After receiving PoolDTO from TMS Bridge        | **Complete PoolDTO JSON**                           |
| 6   | Before TOP Service | Before calling `topService.CalculateRoutes()`  | Input PoolDTO                                       |
| 7   | After TOP Service  | After TOP Service returns                      | **Enriched PoolDTO JSON**                           |
| 8   | Before SetPoolDto  | Before calling TMS Bridge `SetXserverDto`      | Enriched PoolDTO JSON                               |
| 9   | After SetPoolDto   | After TMS Bridge responds                      | Response status                                     |

### TMS Bridge (2 capture points)

| #   | Capture Point       | When                      | What to Capture                                     |
| --- | ------------------- | ------------------------- | --------------------------------------------------- |
| 10  | GetXserverDto Entry | GraphQL query received    | `databaseIdentifier`, `transportOrderId`, `traceId` |
| 11  | SetXserverDto Entry | GraphQL mutation received | `poolDtoJsonString` length, `traceId`               |

## Storage Strategy - V1 Local-First

### Option 1: Structured Logging (Recommended for V1)

Use existing logging infrastructure with structured logs.

**Pros:**
- No database changes required
- Works locally immediately
- Easy to implement
- Can view in console or log files

**Cons:**
- Harder to query across traces
- Limited retention

**Implementation:**
```csharp
_logger.LogInformation(
    "[TRACE:{TraceId}] {Component}::{CapturePoint} | Direction:{Direction} | Data:{Data}",
    traceId,
    "Backend",
    "AfterGetPoolDto",
    "Response",
    JsonSerializer.Serialize(poolDto)
);
```

### Option 2: In-Memory Cache (Development Only)

Store traces in memory for immediate analysis during development.

**Pros:**
- Fast querying
- No external dependencies
- Perfect for local development

**Cons:**
- Lost on restart
- Not for production

**Implementation:**
```csharp
// Simple in-memory store
public class InMemoryTraceStore
{
    private static readonly ConcurrentDictionary<string, List<TraceCapturePoint>> _traces = new();

    public void Capture(TraceCapturePoint point)
    {
        _traces.AddOrUpdate(
            point.TraceId,
            new List<TraceCapturePoint> { point },
            (key, list) => { list.Add(point); return list; }
        );
    }

    public List<TraceCapturePoint> GetTrace(string traceId)
    {
        return _traces.TryGetValue(traceId, out var trace) ? trace : new List<TraceCapturePoint>();
    }
}
```

### Option 3: Local File Storage ⭐ **Recommended for AI/Analytics**

Write traces to JSON files for downstream AI agents and analytics.

**Pros:**
- ✅ Survives restarts
- ✅ Easy to share traces with team
- ✅ Can commit example traces to repo
- ✅ **Perfect for feeding into AI agents**
- ✅ **Easy to batch process for analytics**
- ✅ Version control friendly
- ✅ No database overhead

**Cons:**
- Manual file management (mitigated with cleanup script)
- Need simple query helper (provided below)

**File Structure:**
```
traces/
├── 2026-03-10/                    # Organized by date
│   ├── trace-1710073245-abc123.json
│   ├── trace-1710074456-def456.json
│   └── trace-1710075567-ghi789.json
├── 2026-03-11/
│   └── ...
└── examples/                      # Curated examples for testing
    ├── successful-tour-calc.json
    ├── timezone-issue.json
    └── performance-slow.json
```

**Trace File Format:**
```json
{
  "TraceId": "trace-1710073245-abc123",
  "StartTime": "2026-03-10T14:30:45.123Z",
  "EndTime": "2026-03-10T14:30:51.456Z",
  "DurationMs": 6333,
  "CaptureCount": 11,
  "Components": ["Frontend", "Backend", "TMSBridge"],
  "Captures": [
    {
      "Component": "Backend",
      "CapturePoint": "CalculateRoutesCommand.Entry",
      "Direction": "Request",
      "Timestamp": "2026-03-10T14:30:45.123Z",
      "TimestampIso": "2026-03-10T14:30:45.1230000Z",
      "Data": {
        "TransportOrderId": 123456,
        "DatabaseIdentifier": "1034"
      }
    },
    {
      "Component": "Backend",
      "CapturePoint": "AfterGetPoolDto",
      "Direction": "Response",
      "Timestamp": "2026-03-10T14:30:46.234Z",
      "TimestampIso": "2026-03-10T14:30:46.2340000Z",
      "Data": {
        "PoolDto": { /* full PoolDTO */ },
        "Summary": { /* metadata */ }
      }
    }
    // ... more captures
  ]
}
```

**Implementation:** See code in Phase 2 section below.

## Implementation Guide - V1

### Phase 1: Trace ID Propagation (Day 1)

#### 1.1 Frontend

**File:** `Code/Disposition-Frontend/libs/nagel-services/src/lib/tracing/trace-id.service.ts`

```typescript
import { Injectable } from '@angular/core';

@Injectable({ providedIn: 'root' })
export class TraceIdService {
  generateTraceId(): string {
    return `trace-${Date.now()}-${crypto.randomUUID()}`;
  }
}
```

**File:** `Code/Disposition-Frontend/libs/nagel-services/src/lib/tracing/trace-id.interceptor.ts`

```typescript
import { Injectable } from '@angular/core';
import { HttpInterceptor, HttpRequest, HttpHandler, HttpEvent } from '@angular/common/http';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { TraceIdService } from './trace-id.service';

@Injectable()
export class TraceIdInterceptor implements HttpInterceptor {
  constructor(private traceIdService: TraceIdService) {}

  intercept(req: HttpRequest<any>, next: HttpHandler): Observable<HttpEvent<any>> {
    const traceId = this.traceIdService.generateTraceId();

    const tracedRequest = req.clone({
      setHeaders: { 'X-Trace-Id': traceId }
    });

    // CAPTURE #1: Request initiated
    console.log(`[TRACE:${traceId}] Frontend::RequestInitiated`, {
      method: req.method,
      url: req.url,
      timestamp: new Date().toISOString()
    });

    return next.handle(tracedRequest).pipe(
      tap({
        next: (event) => {
          // CAPTURE #2: Response received (in HttpResponse handler)
          if (event.type === 4) { // HttpEventType.Response
            console.log(`[TRACE:${traceId}] Frontend::ResponseReceived`, {
              status: event['status'],
              timestamp: new Date().toISOString()
            });
          }
        },
        error: (error) => {
          console.error(`[TRACE:${traceId}] Frontend::Error`, error);
        }
      })
    );
  }
}
```

Register in app config.

#### 1.2 Backend

**File:** `Code/Disposition-Backend/CALConsult.Disposition.API/Infrastructure/Tracing/TraceIdMiddleware.cs`

```csharp
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;

namespace CALConsult.Disposition.API.Infrastructure.Tracing;

public class TraceIdMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<TraceIdMiddleware> _logger;

    public TraceIdMiddleware(RequestDelegate next, ILogger<TraceIdMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var traceId = context.Request.Headers["X-Trace-Id"].FirstOrDefault()
                     ?? $"trace-backend-{Guid.NewGuid()}";

        context.Items["TraceId"] = traceId;
        context.Response.Headers.Append("X-Trace-Id", traceId);

        using (_logger.BeginScope(new Dictionary<string, object> { ["TraceId"] = traceId }))
        {
            await _next(context);
        }
    }
}
```

**File:** `Code/Disposition-Backend/CALConsult.Disposition.API/Infrastructure/Tracing/TraceIdExtensions.cs`

```csharp
using Microsoft.AspNetCore.Http;

namespace CALConsult.Disposition.API.Infrastructure.Tracing;

public static class TraceIdExtensions
{
    public static string GetTraceId(this HttpRequest request)
    {
        return request.HttpContext.Items["TraceId"]?.ToString() ?? "unknown";
    }

    public static string GetTraceId(this HttpContext context)
    {
        return context.Items["TraceId"]?.ToString() ?? "unknown";
    }
}
```

Register middleware in `Startup.cs`:
```csharp
app.UseMiddleware<TraceIdMiddleware>();
```

#### 1.3 TMS Bridge

**File:** `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Infrastructure/GraphQL/TraceIdInterceptor.cs`

```csharp
using HotChocolate.AspNetCore;
using HotChocolate.Execution;
using Microsoft.AspNetCore.Http;

namespace CALConsult.TMSBridge.API.Infrastructure.GraphQL;

public class TraceIdInterceptor : DefaultHttpRequestInterceptor
{
    public override ValueTask OnCreateAsync(
        HttpContext context,
        IRequestExecutor requestExecutor,
        IQueryRequestBuilder requestBuilder,
        CancellationToken cancellationToken)
    {
        var traceId = context.Request.Headers["X-Trace-Id"].FirstOrDefault();

        if (!string.IsNullOrEmpty(traceId))
        {
            requestBuilder.SetProperty("TraceId", traceId);
            context.Items["TraceId"] = traceId;
        }

        return base.OnCreateAsync(context, requestExecutor, requestBuilder, cancellationToken);
    }
}
```

Register in GraphQL configuration:
```csharp
services.AddGraphQLServer()
    .AddHttpRequestInterceptor<TraceIdInterceptor>();
```

### Phase 2: Capture Service (Day 2)

**File:** `Code/Disposition-Backend/CALConsult.Disposition.API/Infrastructure/Tracing/ITraceCapture.cs`

```csharp
namespace CALConsult.Disposition.API.Infrastructure.Tracing;

public interface ITraceCapture
{
    Task CaptureAsync(TraceCapturePoint point);
    List<TraceCapturePoint> GetTrace(string traceId);
}

public class TraceCapturePoint
{
    public string TraceId { get; set; }
    public string Component { get; set; }
    public string CapturePoint { get; set; }
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    public string Direction { get; set; } // "Request" or "Response"
    public object Data { get; set; }
}
```

**File:** `Code/Disposition-Backend/CALConsult.Disposition.API/Infrastructure/Tracing/InMemoryTraceCapture.cs`

```csharp
using System.Collections.Concurrent;
using System.Text.Json;
using Microsoft.Extensions.Logging;

namespace CALConsult.Disposition.API.Infrastructure.Tracing;

public class InMemoryTraceCapture : ITraceCapture
{
    private readonly ILogger<InMemoryTraceCapture> _logger;
    private static readonly ConcurrentDictionary<string, List<TraceCapturePoint>> _traces = new();
    private static readonly JsonSerializerOptions _jsonOptions = new()
    {
        WriteIndented = true
    };

    public InMemoryTraceCapture(ILogger<InMemoryTraceCapture> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// NON-BLOCKING: Returns immediately, never throws
    /// </summary>
    public Task CaptureAsync(TraceCapturePoint point)
    {
        try
        {
            // Store in memory - fast, non-blocking
            _traces.AddOrUpdate(
                point.TraceId,
                new List<TraceCapturePoint> { point },
                (key, list) =>
                {
                    list.Add(point);
                    return list;
                }
            );

            // Log for immediate visibility (best-effort)
            try
            {
                var dataJson = JsonSerializer.Serialize(point.Data, _jsonOptions);
                _logger.LogInformation(
                    "[TRACE:{TraceId}] {Component}::{CapturePoint} | {Direction}\n{Data}",
                    point.TraceId,
                    point.Component,
                    point.CapturePoint,
                    point.Direction,
                    dataJson
                );
            }
            catch
            {
                // Suppress serialization errors - don't fail main operation
            }
        }
        catch (Exception ex)
        {
            // CRITICAL: Never throw - tracing must not break business logic
            _logger.LogDebug(ex, "Trace capture failed (non-critical)");
        }

        return Task.CompletedTask;
    }

    public List<TraceCapturePoint> GetTrace(string traceId)
    {
        return _traces.TryGetValue(traceId, out var trace)
            ? trace.OrderBy(t => t.Timestamp).ToList()
            : new List<TraceCapturePoint>();
    }

    // Helper for development: get recent traces
    public List<string> GetRecentTraceIds(int count = 10)
    {
        return _traces.Keys
            .OrderByDescending(k => k)
            .Take(count)
            .ToList();
    }
}
```

**File:** `Code/Disposition-Backend/CALConsult.Disposition.API/Infrastructure/Tracing/FileBasedTraceCapture.cs` ⭐ **Use this for AI/Analytics**

```csharp
using System.Collections.Concurrent;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace CALConsult.Disposition.API.Infrastructure.Tracing;

public class FileBasedTraceCapture : ITraceCapture
{
    private readonly ILogger<FileBasedTraceCapture> _logger;
    private readonly string _tracesBasePath;
    private static readonly JsonSerializerOptions _jsonOptions = new()
    {
        WriteIndented = true,
        DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull
    };

    // In-memory buffer for active traces
    private static readonly ConcurrentDictionary<string, List<TraceCapturePoint>> _activeTraces = new();

    public FileBasedTraceCapture(
        ILogger<FileBasedTraceCapture> logger,
        IConfiguration configuration)
    {
        _logger = logger;
        _tracesBasePath = configuration["Tracing:TracesPath"] ?? "traces";
        Directory.CreateDirectory(_tracesBasePath);
    }

    /// <summary>
    /// NON-BLOCKING: Returns immediately, processes file I/O in background, never throws
    /// </summary>
    public Task CaptureAsync(TraceCapturePoint point)
    {
        try
        {
            // Add to in-memory buffer (fast, non-blocking)
            _activeTraces.AddOrUpdate(
                point.TraceId,
                new List<TraceCapturePoint> { point },
                (key, list) =>
                {
                    list.Add(point);
                    return list;
                }
            );

            // Log for immediate visibility (best-effort)
            try
            {
                _logger.LogInformation(
                    "[TRACE:{TraceId}] {Component}::{CapturePoint} | {Direction}",
                    point.TraceId,
                    point.Component,
                    point.CapturePoint,
                    point.Direction
                );
            }
            catch
            {
                // Suppress logging errors
            }

            // Fire-and-forget: Flush to file in background when trace completes
            if (IsEndOfTrace(point))
            {
                _ = Task.Run(async () =>
                {
                    try
                    {
                        await FlushTraceToFileAsync(point.TraceId);
                    }
                    catch (Exception ex)
                    {
                        // Background task - just log, never propagate
                        _logger.LogDebug(ex, "Trace file flush failed (non-critical)");
                    }
                });
            }
        }
        catch (Exception ex)
        {
            // CRITICAL: Never throw - tracing must not break business logic
            _logger.LogDebug(ex, "Trace capture failed (non-critical)");
        }

        return Task.CompletedTask;
    }

    private bool IsEndOfTrace(TraceCapturePoint point)
    {
        // Flush when we see the final capture point or after timeout
        return point.CapturePoint == "CalculateRoutes.Exit" ||
               point.CapturePoint == "AfterSetPoolDto";
    }

    private async Task FlushTraceToFileAsync(string traceId)
    {
        // Wait a bit to ensure all capture points are buffered
        await Task.Delay(100);

        try
        {
            if (!_activeTraces.TryRemove(traceId, out var captures))
            {
                return;
            }

            // Organize by date
            var datePath = Path.Combine(_tracesBasePath, DateTime.UtcNow.ToString("yyyy-MM-dd"));
            Directory.CreateDirectory(datePath);

            // Generate filename
            var fileName = $"{traceId}.json";
            var filePath = Path.Combine(datePath, fileName);

            // Create structured trace document
            var traceDocument = new
            {
                TraceId = traceId,
                StartTime = captures.Min(c => c.Timestamp),
                EndTime = captures.Max(c => c.Timestamp),
                DurationMs = (captures.Max(c => c.Timestamp) - captures.Min(c => c.Timestamp)).TotalMilliseconds,
                CaptureCount = captures.Count,
                Components = captures.Select(c => c.Component).Distinct().ToList(),
                Captures = captures.OrderBy(c => c.Timestamp).Select(c => new
                {
                    c.Component,
                    c.CapturePoint,
                    c.Direction,
                    c.Timestamp,
                    TimestampIso = c.Timestamp.ToString("O"),
                    c.Data
                }).ToList()
            };

            // Write to file
            var json = JsonSerializer.Serialize(traceDocument, _jsonOptions);
            await File.WriteAllTextAsync(filePath, json);

            _logger.LogInformation(
                "✅ Trace saved: {FilePath} ({CaptureCount} captures, {DurationMs}ms)",
                filePath,
                captures.Count,
                traceDocument.DurationMs
            );
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to flush trace to file: {TraceId}", traceId);
        }
    }

    public List<TraceCapturePoint> GetTrace(string traceId)
    {
        // Try in-memory first (for active traces)
        if (_activeTraces.TryGetValue(traceId, out var activeTrace))
        {
            return activeTrace.OrderBy(t => t.Timestamp).ToList();
        }

        // Try loading from file
        return LoadTraceFromFile(traceId);
    }

    private List<TraceCapturePoint> LoadTraceFromFile(string traceId)
    {
        try
        {
            // Search recent 7 days
            for (int i = 0; i < 7; i++)
            {
                var date = DateTime.UtcNow.AddDays(-i).ToString("yyyy-MM-dd");
                var filePath = Path.Combine(_tracesBasePath, date, $"{traceId}.json");

                if (File.Exists(filePath))
                {
                    var json = File.ReadAllText(filePath);
                    var doc = JsonDocument.Parse(json);
                    var captures = doc.RootElement.GetProperty("Captures");

                    var result = new List<TraceCapturePoint>();
                    foreach (var capture in captures.EnumerateArray())
                    {
                        result.Add(new TraceCapturePoint
                        {
                            TraceId = traceId,
                            Component = capture.GetProperty("Component").GetString(),
                            CapturePoint = capture.GetProperty("CapturePoint").GetString(),
                            Direction = capture.GetProperty("Direction").GetString(),
                            Timestamp = capture.GetProperty("Timestamp").GetDateTime(),
                            Data = JsonSerializer.Deserialize<object>(
                                capture.GetProperty("Data").GetRawText())
                        });
                    }

                    return result;
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to load trace from file: {TraceId}", traceId);
        }

        return new List<TraceCapturePoint>();
    }

    // === Helpers for AI/Analytics ===

    /// <summary>
    /// Get all trace IDs for a specific date (for batch processing)
    /// </summary>
    public List<string> GetTraceIdsForDate(DateTime date)
    {
        var datePath = Path.Combine(_tracesBasePath, date.ToString("yyyy-MM-dd"));
        if (!Directory.Exists(datePath))
        {
            return new List<string>();
        }

        return Directory.GetFiles(datePath, "*.json")
            .Select(f => Path.GetFileNameWithoutExtension(f))
            .ToList();
    }

    /// <summary>
    /// Load all traces for a date (for AI analysis pipeline)
    /// </summary>
    public async Task<List<string>> LoadTracesForDateAsync(DateTime date)
    {
        var datePath = Path.Combine(_tracesBasePath, date.ToString("yyyy-MM-dd"));
        if (!Directory.Exists(datePath))
        {
            return new List<string>();
        }

        var traces = new List<string>();
        var files = Directory.GetFiles(datePath, "*.json");

        foreach (var file in files)
        {
            try
            {
                var json = await File.ReadAllTextAsync(file);
                traces.Add(json);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to load trace file: {File}", file);
            }
        }

        return traces;
    }

    /// <summary>
    /// Cleanup old traces (call from background job or startup)
    /// </summary>
    public void CleanupOldTraces(int daysToKeep = 30)
    {
        try
        {
            var directories = Directory.GetDirectories(_tracesBasePath);
            var cutoffDate = DateTime.UtcNow.AddDays(-daysToKeep);

            foreach (var dir in directories)
            {
                var dirName = Path.GetFileName(dir);
                if (DateTime.TryParse(dirName, out var dirDate) && dirDate < cutoffDate)
                {
                    Directory.Delete(dir, recursive: true);
                    _logger.LogInformation("🧹 Deleted old traces: {Directory}", dir);
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to cleanup old traces");
        }
    }
}
```

Register in `Startup.cs`:
```csharp
// Option 1: In-memory (for quick testing)
// services.AddSingleton<ITraceCapture, InMemoryTraceCapture>();

// Option 2: File-based (recommended for AI/analytics)
services.AddSingleton<ITraceCapture, FileBasedTraceCapture>();

services.AddHttpContextAccessor();
```

**Configuration in `appsettings.json`:**
```json
{
  "Tracing": {
    "TracesPath": "traces"  // Relative or absolute path
  }
}
```

**Add to `.gitignore`:**
```
# Trace files (keep examples folder)
traces/
!traces/examples/
```

### Phase 3: Backend Capture Points (Day 3)

**Update:** `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Resources/TransportOrders/Requests/CalculateRoutes/CalculateRoutesCommandHandler.cs`

```csharp
using CALConsult.Disposition.API.Infrastructure.Tracing;

public class CalculateRoutesCommandHandler : ICommandHandler<CalculateRoutesCommand, CalculateRoutesResponseDto>
{
    private readonly IMapper _mapper;
    private readonly IPoolDtoProvider _poolDtoProvider;
    private readonly ITOPService _topService;
    private readonly ISetPoolDtoExecutor _setPoolDtoExecutor;
    private readonly ITraceCapture _traceCapture;
    private readonly IHttpContextAccessor _httpContextAccessor;

    public CalculateRoutesCommandHandler(
        IMapper mapper,
        IPoolDtoProvider poolDtoProvider,
        ITOPService topService,
        ISetPoolDtoExecutor setPoolDtoExecutor,
        ITraceCapture traceCapture,
        IHttpContextAccessor httpContextAccessor)
    {
        _mapper = mapper;
        _poolDtoProvider = poolDtoProvider;
        _topService = topService;
        _setPoolDtoExecutor = setPoolDtoExecutor;
        _traceCapture = traceCapture;
        _httpContextAccessor = httpContextAccessor;
    }

    public async Task<CalculateRoutesResponseDto> Handle(
        CalculateRoutesCommand request,
        CancellationToken cancellationToken)
    {
        var traceId = _httpContextAccessor.HttpContext?.Request.GetTraceId();

        // CAPTURE #3: Command Entry
        _ = _traceCapture.CaptureAsync(new TraceCapturePoint
        {
            TraceId = traceId,
            Component = "Backend",
            CapturePoint = "CalculateRoutesCommand.Entry",
            Direction = "Request",
            Data = new
            {
                TransportOrderId = request.TransportOrderId,
                DatabaseIdentifier = request.DatabaseIdentifier
            }
        });

        // CAPTURE #4: Before GetPoolDto
        _ = _traceCapture.CaptureAsync(new TraceCapturePoint
        {
            TraceId = traceId,
            Component = "Backend",
            CapturePoint = "BeforeGetPoolDto",
            Direction = "Request",
            Data = new
            {
                DatabaseIdentifier = request.DatabaseIdentifier,
                TransportOrderId = request.TransportOrderId
            }
        });

        PoolDto poolDto = await _poolDtoProvider.Get(
            request.DatabaseIdentifier,
            request.TransportOrderId);

        // CAPTURE #5: After GetPoolDto - CRITICAL: Full PoolDTO
        _ = _traceCapture.CaptureAsync(new TraceCapturePoint
        {
            TraceId = traceId,
            Component = "Backend",
            CapturePoint = "AfterGetPoolDto",
            Direction = "Response",
            Data = new
            {
                PoolDto = poolDto, // FULL DTO - this is what TMS Bridge returned
                Summary = new
                {
                    PlanningDate = poolDto.PlanningDate,
                    PlanningInterval = poolDto.PlanningInterval,
                    LocationCount = poolDto.Locations?.Count ?? 0,
                    OrderCount = poolDto.Orders?.Count ?? 0,
                    VehicleCount = poolDto.Vehicles?.Count ?? 0,
                    FirstLocation = poolDto.Locations?.FirstOrDefault(),
                    FirstOrder = poolDto.Orders?.FirstOrDefault()
                }
            }
        });

        // CAPTURE #6: Before TOP Service
        _ = _traceCapture.CaptureAsync(new TraceCapturePoint
        {
            TraceId = traceId,
            Component = "Backend",
            CapturePoint = "BeforeTOPService",
            Direction = "Request",
            Data = new { PoolDto = poolDto }
        });

        PoolDto enrichedPoolDto = await _topService.CalculateRoutes(poolDto, cancellationToken);

        // CAPTURE #7: After TOP Service - CRITICAL: Enriched PoolDTO
        _ = _traceCapture.CaptureAsync(new TraceCapturePoint
        {
            TraceId = traceId,
            Component = "Backend",
            CapturePoint = "AfterTOPService",
            Direction = "Response",
            Data = new
            {
                EnrichedPoolDto = enrichedPoolDto, // FULL DTO - this is what TOP returned
                Summary = new
                {
                    Plans = enrichedPoolDto.Plans,
                    TourCount = enrichedPoolDto.Plans?.FirstOrDefault()?.Tours?.Count ?? 0,
                    FirstTour = enrichedPoolDto.Plans?.FirstOrDefault()?.Tours?.FirstOrDefault(),
                    TourElementCount = enrichedPoolDto.Plans?.FirstOrDefault()?.Tours?.FirstOrDefault()?.TourElements?.Count ?? 0
                }
            }
        });

        // CAPTURE #8: Before SetPoolDto
        _ = _traceCapture.CaptureAsync(new TraceCapturePoint
        {
            TraceId = traceId,
            Component = "Backend",
            CapturePoint = "BeforeSetPoolDto",
            Direction = "Request",
            Data = new { EnrichedPoolDto = enrichedPoolDto }
        });

        SetXServerDtoResponseDto response = await _setPoolDtoExecutor.Execute(
            enrichedPoolDto,
            request.DatabaseIdentifier);

        // CAPTURE #9: After SetPoolDto
        _ = _traceCapture.CaptureAsync(new TraceCapturePoint
        {
            TraceId = traceId,
            Component = "Backend",
            CapturePoint = "AfterSetPoolDto",
            Direction = "Response",
            Data = new
            {
                IsSuccessful = response.IsSuccessful,
                ResponseText = response.ResponseText
            }
        });

        return new CalculateRoutesResponseDto
        {
            PoolDto = _mapper.Map<CalculateRoutesPoolDto>(enrichedPoolDto),
            SetXServerDtoResponse = response
        };
    }
}
```

### Phase 4: TMS Bridge Capture Points (Day 4)

**Update:** `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/GraphQL/Queries/GetXserverDtoQuery/GetXserverDtoQuery.cs`

```csharp
public class GetXserverDtoQuery
{
    [Authorize]
    public async Task<string?> GetXserverDto(
        [Service] IDbContextProvider<BranchDbContext> dbContextProvider,
        [Service] IRoutineExecutor executor,
        [Service] ILogger<GetXserverDtoQuery> logger,
        [GlobalState("TraceId")] string traceId,
        [GraphQLNonNullType] string databaseIdentifier,
        [GraphQLNonNullType] GetXserverDtoQueryInput input)
    {
        // CAPTURE #10: GetXserverDto Entry
        logger.LogInformation(
            "[TRACE:{TraceId}] TMSBridge::GetXserverDto.Entry | Request | DatabaseId:{DatabaseId}, InputId:{InputId}",
            traceId,
            databaseIdentifier,
            input.Id
        );

        var functionName = "pdis_transportorder.getxserverdto";
        var functionParameters = new RoutineParameterBuilder()
            .AddInput("sid", input.Id)
            .Build();

        var routine = new RoutineDto
        {
            RoutineName = functionName,
            Parameters = functionParameters
        };

        var dbContext = dbContextProvider.GetDbContext(databaseIdentifier);
        var response = await executor.ExecuteRoutineAsync(dbContext, OperationType.Function, routine);

        var result = response.Rows[0].Field<string>("Result")?.ToString();

        // Log response (can be large, so log summary + first 500 chars)
        logger.LogInformation(
            "[TRACE:{TraceId}] TMSBridge::GetXserverDto.Response | Response | Length:{Length}, Preview:{Preview}",
            traceId,
            result?.Length ?? 0,
            result?.Substring(0, Math.Min(500, result?.Length ?? 0))
        );

        return result;
    }
}
```

**Update:** `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/GraphQL/Mutations/PdisTransportOrder/SetXServerDto/SetXServerDtoMutation.cs`

```csharp
public class SetXServerDtoMutation
{
    [Authorize]
    public async Task<SetXServerDtoResponse> CallSetXServerDto(
        [Service] IRoutineExecutor executor,
        [Service] IDbContextProvider<BranchDbContext> dbContextProvider,
        [Service] ILogger<SetXServerDtoMutation> logger,
        [GlobalState("TraceId")] string traceId,
        [GraphQLNonNullType] string databaseIdentifier,
        [GraphQLNonNullType] string poolDtoJsonString)
    {
        // CAPTURE #11: SetXserverDto Entry
        logger.LogInformation(
            "[TRACE:{TraceId}] TMSBridge::SetXserverDto.Entry | Request | DatabaseId:{DatabaseId}, JsonLength:{Length}",
            traceId,
            databaseIdentifier,
            poolDtoJsonString.Length
        );

        // Existing implementation...
        var procedureName = "pdis_transportorder.setxserverdto";

        var procedureParameters = new RoutineParameterBuilder()
            .AddInput("sjson", poolDtoJsonString)
            .Build();

        var routine = new RoutineDto
        {
            RoutineName = procedureName,
            Parameters = procedureParameters
        };

        var result = new SetXServerDtoResponse
        {
            ResponseText = string.Empty,
            IsSuccessful = false
        };

        try
        {
            var dbContext = dbContextProvider.GetDbContext(databaseIdentifier);
            var response = await executor.ExecuteRoutineAsync(dbContext, OperationType.Function, routine);

            result = result with
            {
                ResponseText = response.Rows[0].Field<string>("Result") ?? string.Empty,
                IsSuccessful = true
            };

            logger.LogInformation(
                "[TRACE:{TraceId}] TMSBridge::SetXserverDto.Response | Response | Success:{Success}, Response:{Response}",
                traceId,
                result.IsSuccessful,
                result.ResponseText
            );
        }
        catch (Exception ex)
        {
            logger.LogError(
                ex,
                "[TRACE:{TraceId}] TMSBridge::SetXserverDto.Error | Error | Message:{Message}",
                traceId,
                ex.Message
            );

            result = result with { IsSuccessful = false };
        }

        return result;
    }
}
```

## Testing Locally

### Step 1: Start All Components

```bash
# Terminal 1: Frontend
cd Code/Disposition-Frontend
npm start

# Terminal 2: Backend
cd Code/Disposition-Backend
dotnet run --project CALConsult.Disposition.API

# Terminal 3: TMS Bridge
cd Code/Disposition-Abstraction-Layer
dotnet run --project CALConsult.TMSBridge.API
```

### Step 2: Trigger a Tour Calculation

1. Open browser to `http://localhost:4200`
2. Navigate to a transport order
3. Click "Calculate Routes"
4. Observe console and backend logs

### Step 3: View the Trace

In your backend logs, you should see:

```
[TRACE:trace-1234-abc] Backend::CalculateRoutesCommand.Entry | Request
[TRACE:trace-1234-abc] Backend::BeforeGetPoolDto | Request
[TRACE:trace-1234-abc] TMSBridge::GetXserverDto.Entry | Request
[TRACE:trace-1234-abc] TMSBridge::GetXserverDto.Response | Response
[TRACE:trace-1234-abc] Backend::AfterGetPoolDto | Response
  {
    "PoolDto": { ... full PoolDTO ... },
    "Summary": { ... }
  }
[TRACE:trace-1234-abc] Backend::BeforeTOPService | Request
[TRACE:trace-1234-abc] Backend::AfterTOPService | Response
  {
    "EnrichedPoolDto": { ... enriched PoolDTO ... }
  }
[TRACE:trace-1234-abc] Backend::BeforeSetPoolDto | Request
[TRACE:trace-1234-abc] TMSBridge::SetXserverDto.Entry | Request
[TRACE:trace-1234-abc] TMSBridge::SetXserverDto.Response | Response
[TRACE:trace-1234-abc] Backend::AfterSetPoolDto | Response
```

### Step 4: Query a Trace (Optional API Endpoint)

Add a simple controller to query traces:

**File:** `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Debug/TraceController.cs`

```csharp
using CALConsult.Disposition.API.Infrastructure.Tracing;
using Microsoft.AspNetCore.Mvc;

namespace CALConsult.Disposition.API.Application.Debug;

[ApiController]
[Route("api/debug/trace")]
public class TraceController : ControllerBase
{
    private readonly ITraceCapture _traceCapture;

    public TraceController(ITraceCapture traceCapture)
    {
        _traceCapture = traceCapture;
    }

    [HttpGet("{traceId}")]
    public ActionResult<List<TraceCapturePoint>> GetTrace(string traceId)
    {
        var trace = _traceCapture.GetTrace(traceId);
        return Ok(trace);
    }

    [HttpGet("recent")]
    public ActionResult<List<string>> GetRecentTraces()
    {
        if (_traceCapture is InMemoryTraceCapture inMemory)
        {
            return Ok(inMemory.GetRecentTraceIds(20));
        }
        return NotFound("In-memory trace store not available");
    }
}
```

Then query:
```bash
# Get recent trace IDs
curl http://localhost:5000/api/debug/trace/recent

# Get full trace
curl http://localhost:5000/api/debug/trace/trace-1234-abc
```

## Analysis Examples - What You Can Learn

### Example 1: Time Zone Issues

Even without database instrumentation, you can see:

```json
// AfterGetPoolDto capture
{
  "PoolDto": {
    "PlanningDate": "2025-03-26T00:00:00+01:00",
    "PlanningInterval": {
      "Start": "2025-03-25T23:00:00",      // ❌ Missing timezone!
      "End": "2025-03-26T23:00:00"          // ❌ Missing timezone!
    }
  }
}

// AfterTOPService capture
{
  "EnrichedPoolDto": {
    "PlanningDate": "2025-03-26T00:00:00+01:00",
    "Plans": [{
      "Tours": [{
        "TourElements": [{
          "StartTime": "1900-01-01T05:30:00+01:00"  // ⚠️ Wrong date?
        }]
      }]
    }]
  }
}
```

**Insight:** The issue is coming FROM TMS Database (timezone missing in PlanningInterval), not from your code or TOP Service.

### Example 2: Data Transformation in TOP Service

```json
// BeforeTOPService
{
  "PoolDto": {
    "Locations": [/* 5 locations */],
    "Orders": [/* 4 orders */],
    "Vehicles": [/* 1 vehicle */]
  }
}

// AfterTOPService
{
  "EnrichedPoolDto": {
    "Locations": [/* still 5 locations */],
    "Plans": [{
      "Tours": [{
        "TourElements": [/* 9 elements - 2*4 legs + 1 start point */]
      }]
    }]
  }
}
```

**Insight:** TOP Service correctly generated tour elements from orders. If count is wrong, the issue is in TOP or xServer, not your integration.

### Example 3: Performance Bottleneck

```
[12:34:56.123] Backend::BeforeGetPoolDto
[12:34:56.245] Backend::AfterGetPoolDto      // ← 122ms (TMS Bridge + Database)
[12:34:56.248] Backend::BeforeTOPService
[12:35:01.789] Backend::AfterTOPService      // ← 5.5 seconds (TOP + xServer)
[12:35:01.792] Backend::BeforeSetPoolDto
[12:35:01.887] Backend::AfterSetPoolDto      // ← 95ms (TMS Bridge + Database)
```

**Insight:** TOP Service (including xServer call) is the bottleneck at 5.5 seconds. Your integration layer is fast (<250ms total).

## Benefits of V1 Minimal Approach

✅ **Quick to implement**: 3-4 days total
✅ **Local testing**: Works on your laptop immediately
✅ **No external dependencies**: No database changes needed
✅ **Proves value**: Shows if tracing helps before bigger investment
✅ **Under your control**: All code you own and maintain
✅ **Iterative**: Can add V2 features later if V1 proves valuable

## What's Missing (Deferred to V2)

❌ Database-level capture (PoolDTO generation details)
❌ TOP Service internal instrumentation
❌ xServer request/response capture
❌ Persistent storage (only in-memory/logs)
❌ UI visualization

See [v2-future-enhancements.md](./v2-future-enhancements.md) for these features.

## Non-Blocking Implementation Checklist

**Before deploying, verify these non-blocking patterns are followed:**

### Backend (.NET)

- ✅ **Fire-and-forget**: Use `_ = _traceCapture.CaptureAsync(...)` (NOT `await`)
- ✅ **Comprehensive try-catch**: All `CaptureAsync` methods wrapped in try-catch
- ✅ **Never throw**: Catch all exceptions, log at Debug level, never propagate
- ✅ **Fast return**: `CaptureAsync` returns `Task.CompletedTask` immediately
- ✅ **Background processing**: File I/O or network calls via `Task.Run` or channels
- ✅ **Circuit breaker** (optional): Auto-disable after repeated failures
- ✅ **Resource limits**: Bounded queues (drop oldest when full)
- ✅ **Timeouts**: All async operations have timeout (e.g., 2 seconds max)

### Frontend (Angular)

- ✅ **Console only**: Use `console.log` for immediate tracing (non-blocking)
- ✅ **Error suppression**: Wrap in try-catch if calling HTTP endpoints
- ✅ **RxJS tap operator**: Non-blocking, doesn't interrupt stream
- ✅ **No await**: If sending to backend, use fire-and-forget HTTP calls

### TMS Bridge (GraphQL)

- ✅ **Fire-and-forget**: Use `_ = traceCapture.SafeCaptureAsync(...)`
- ✅ **Never block resolver**: Trace capture must not delay query response
- ✅ **Error handling**: Try-catch in resolver, suppress trace errors

### Testing Non-Blocking Behavior

```csharp
// Test: Verify CaptureAsync returns immediately (< 100ms)
var stopwatch = Stopwatch.StartNew();
_ = _traceCapture.CaptureAsync(point);
stopwatch.Stop();
Assert.True(stopwatch.ElapsedMilliseconds < 100, "CaptureAsync must not block");

// Test: Verify exceptions don't propagate
var failingCapture = new Mock<ITraceCapture>();
failingCapture.Setup(x => x.CaptureAsync(It.IsAny<TraceCapturePoint>()))
    .ThrowsAsync(new Exception("Test failure"));

// Should not throw
await Assert.DoesNotThrowAsync(async () =>
{
    _ = failingCapture.Object.CaptureAsync(point);
    await Task.Delay(100); // Allow background processing
});
```

### Anti-Patterns to Avoid

**DO NOT:**
```csharp
// ❌ WRONG: Blocking await
await _traceCapture.CaptureAsync(point);
await _business.ProcessAsync();

// ❌ WRONG: Throwing exceptions
if (point == null)
    throw new ArgumentNullException();

// ❌ WRONG: Synchronous I/O
File.WriteAllText("trace.log", data); // Blocks thread

// ❌ WRONG: Unhandled exceptions
await _database.InsertAsync(point); // Can crash app
```

**DO THIS:**
```csharp
// ✅ CORRECT: Fire-and-forget
_ = _traceCapture.CaptureAsync(point);
await _business.ProcessAsync();

// ✅ CORRECT: Never throw
if (point == null) return;

// ✅ CORRECT: Background I/O
_ = Task.Run(() => File.WriteAllTextAsync("trace.log", data));

// ✅ CORRECT: Error handling
try { await _database.InsertAsync(point); }
catch (Exception ex) { _logger.LogDebug(ex, "Trace failed"); }
```

## Success Criteria

After implementing V1, you should be able to:

- ✅ See a trace ID flow through Frontend → Backend → TMS Bridge
- ✅ View the complete PoolDTO received from TMS Bridge
- ✅ Compare PoolDTO before/after TOP Service
- ✅ Identify which component takes the most time
- ✅ Debug issues without changing TMS Database or TOP Service
- ✅ Share traces with team members (via trace ID or log files)

## Next Steps

1. **Day 1**: Implement trace ID propagation (all 3 components)
2. **Day 2**: Add trace capture service
3. **Day 3**: Add backend capture points
4. **Day 4**: Add TMS Bridge capture points
5. **Day 5**: Test with real tour calculation, analyze results
6. **Week 2**: Iterate based on findings, document learnings

If V1 proves valuable, proceed to V2 enhancements.

## Questions?

Before implementing:
- [ ] Storage approach: In-memory, file-based, or structured logs?
- [ ] Development environment only or also test environment?
- [ ] Need API endpoint to query traces or logs sufficient?
- [ ] Team training needed on how to use traces?

Ready to start? Begin with Phase 1: Trace ID Propagation!
