# Incident ID Implementation Options

**Date:** 2026-05-18
**Context:** How to generate a trackable incident ID for sync conflict events (#124105)
**Referenced from:** [transactional-sync-error-ux-analysis.md](./transactional-sync-error-ux-analysis.md)

---

## Current State

The Backend has no incident/tracking ID in sync error responses today. But there are several existing mechanisms that already produce request-scoped identifiers — none of them are surfaced to the caller.

| Mechanism | Where | Scope | Exposed to Frontend? |
|-----------|-------|-------|---------------------|
| `HttpContext.TraceIdentifier` | ASP.NET Core built-in | Per HTTP request | No |
| `requestGuid` in `LoggingBehavior` | MediatR pipeline (line 19) | Per command handler invocation | No (local variable, logged but not returned) |
| `X-Cloud-Trace-Context` header | Injected by GCP Cloud Run | Per HTTP request, GCP-native | No |

---

## Option 1: `HttpContext.TraceIdentifier` (Recommended)

**Effort:** ~1 line of code
**Packages:** None

ASP.NET Core assigns a unique ID to every HTTP request. The `BaseExceptionHandler` already receives `HttpContext` as a parameter:

```csharp
// BaseExceptionHandler.cs:36
public virtual async ValueTask<bool> TryHandleAsync(
    HttpContext httpContext, Exception ex, CancellationToken cancellationToken)
```

Add it to the ProblemDetails response:

```csharp
var problemDetails = new ProblemDetails
{
    Detail = GetDetail(ex),
    Status = (int)StatusCode,
    Title = Title,
    Type = TypeDefinitionUri,
    Extensions = new Dictionary<string, object?>
    {
        ["errors"] = GetErrors(ex),
        ["incidentId"] = httpContext.TraceIdentifier   // <-- this
    }
};
```

**Pros:**
- Zero infrastructure, zero packages, zero config
- Already unique per request
- On Cloud Run, this ID correlates with GCP Cloud Logging entries (Cloud Run maps it to the request log)
- Works in all environments (local dev, Cloud Run, any host)
- Support can grep log files by this ID

**Cons:**
- Format is ASP.NET internal (e.g. `0HN4B8Q9O5Q6M:00000001`), not a human-friendly GUID
- Not guaranteed to match GCP trace ID format (see Option 3 for that)

---

## Option 2: Thread MediatR `requestGuid` to the Response

**Effort:** Medium (scoped service + wiring)
**Packages:** None

The `LoggingBehavior` already generates a `Guid.NewGuid()` per command:

```csharp
// LoggingBehavior.cs:19
var requestGuid = Guid.NewGuid().ToString();
_logger.LogWarning($"[START] {requestName} [{requestGuid}]");
```

This GUID is logged but trapped as a local variable. To expose it:

1. Create a scoped service (e.g., `IRequestContext` with `RequestId` property)
2. Set it in `LoggingBehavior`
3. Read it in `BaseExceptionHandler` via DI

```csharp
public interface IRequestContext { string? RequestId { get; set; } }

// In LoggingBehavior:
_requestContext.RequestId = requestGuid;

// In BaseExceptionHandler:
["incidentId"] = _requestContext.RequestId ?? httpContext.TraceIdentifier
```

**Pros:**
- Human-friendly GUID format
- Already correlated with `[START]`/`[END]`/`[PROPS]` log entries
- One consistent ID across MediatR logs and error responses

**Cons:**
- Requires wiring a scoped service through DI
- Only available inside MediatR pipeline (not for errors outside command handlers)
- Slightly more invasive than Option 1

---

## Option 3: GCP `X-Cloud-Trace-Context` Header

**Effort:** Low (~5 lines)
**Packages:** None (just reads an HTTP header)

Cloud Run automatically injects `X-Cloud-Trace-Context` into every incoming request:

```
X-Cloud-Trace-Context: 105445aa7843bc8bf206b12000100000/1;o=1
                        ^-- TRACE_ID (32 hex chars)    ^-- SPAN_ID
```

Read it in the exception handler:

```csharp
var traceHeader = httpContext.Request.Headers["X-Cloud-Trace-Context"].FirstOrDefault();
var traceId = traceHeader?.Split('/').FirstOrDefault();
```

**Pros:**
- GCP-native: support can paste this trace ID directly into Cloud Logging / Cloud Trace console to find all related logs
- Automatically correlates across Backend → TMS Bridge if the header is forwarded
- Standard format (W3C-adjacent)

**Cons:**
- Only available when running on Cloud Run (empty in local dev)
- Needs fallback for non-GCP environments
- Requires that Cloud Logging is actually used (currently logs go to rolling files via Serilog, not Cloud Logging)

---

## Comparison

| Criterion | Option 1: TraceIdentifier | Option 2: MediatR GUID | Option 3: GCP Trace |
|-----------|--------------------------|----------------------|-------------------|
| Implementation effort | ~1 line | Medium (scoped service) | ~5 lines + fallback |
| Works in all environments | Yes | Yes | Cloud Run only |
| Human-friendly format | No (internal format) | Yes (GUID) | No (hex string) |
| Correlates with existing logs | Partially (Cloud Run) | Yes (MediatR logs) | Yes (Cloud Logging) |
| GCP console searchable | Indirectly | No | Directly |
| Cross-service correlation | No | No | Yes (if header forwarded) |
| Fallback needed | No | For non-MediatR errors | For non-GCP environments |

---

## Recommendation

**Start with Option 1** (`HttpContext.TraceIdentifier`) — it's 1 line, works everywhere, and unblocks the frontend UX work immediately.

**Evolve to Option 2 if needed** — if support feedback shows that GUID format is preferred or MediatR log correlation is important, add the scoped service later. Options 1 and 2 are not mutually exclusive; the `ProblemDetails.Extensions` can carry both.

**Option 3 becomes relevant** when/if the team adopts GCP Cloud Logging (replacing Serilog file sink). At that point, the GCP trace ID becomes the most powerful option for cross-service debugging. But it's a bigger infrastructure decision beyond the scope of #124105.
