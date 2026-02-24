# Backend Version Endpoint - Code Examples

This document shows how to add `/api/version` endpoints to your ASP.NET Core services.

---

## Part 1: Disposition-Backend

### Step 1: Create VersionController

**Create new file**: `CALConsult.Disposition.API/Controllers/VersionController.cs`

```csharp
using Microsoft.AspNetCore.Mvc;
using System;

namespace CALConsult.Disposition.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class VersionController : ControllerBase
{
    /// <summary>
    /// Returns version information about this service
    /// </summary>
    /// <returns>Version metadata including component version, system version, and git commit</returns>
    [HttpGet]
    public IActionResult GetVersion()
    {
        var versionInfo = new
        {
            component = Environment.GetEnvironmentVariable("COMPONENT_NAME") ?? "disposition-backend",
            version = Environment.GetEnvironmentVariable("COMPONENT_VERSION") ?? "unknown",
            systemVersion = Environment.GetEnvironmentVariable("SYSTEM_VERSION") ?? "unknown",
            gitCommit = Environment.GetEnvironmentVariable("GIT_COMMIT") ?? "unknown",
            timestamp = DateTime.UtcNow
        };

        return Ok(versionInfo);
    }
}
```

### Step 2: Test Locally

Add to `appsettings.Development.json` (for local testing):

```json
{
  "COMPONENT_NAME": "disposition-backend",
  "COMPONENT_VERSION": "dev",
  "SYSTEM_VERSION": "dev",
  "GIT_COMMIT": "local"
}
```

Or set environment variables:

```bash
export COMPONENT_NAME=disposition-backend
export COMPONENT_VERSION=dev
export SYSTEM_VERSION=dev
export GIT_COMMIT=local

dotnet run
```

### Step 3: Test Endpoint

```bash
curl http://localhost:5101/api/version

# Expected response:
{
  "component": "disposition-backend",
  "version": "1.2.3",
  "systemVersion": "42",
  "gitCommit": "abc123",
  "timestamp": "2026-02-24T12:30:00Z"
}
```

---

## Part 2: TMS-Bridge (Disposition-Abstraction-Layer)

### Step 1: Create VersionController

**Create new file**: `CALConsult.TMSBridge.API/Controllers/VersionController.cs`

```csharp
using Microsoft.AspNetCore.Mvc;
using System;

namespace CALConsult.TMSBridge.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class VersionController : ControllerBase
{
    /// <summary>
    /// Returns version information about this service
    /// </summary>
    [HttpGet]
    public IActionResult GetVersion()
    {
        var versionInfo = new
        {
            component = Environment.GetEnvironmentVariable("COMPONENT_NAME") ?? "tms-bridge",
            version = Environment.GetEnvironmentVariable("COMPONENT_VERSION") ?? "unknown",
            systemVersion = Environment.GetEnvironmentVariable("SYSTEM_VERSION") ?? "unknown",
            gitCommit = Environment.GetEnvironmentVariable("GIT_COMMIT") ?? "unknown",
            timestamp = DateTime.UtcNow
        };

        return Ok(versionInfo);
    }
}
```

### Step 2: Test

```bash
curl http://localhost:7153/api/version

# Expected response:
{
  "component": "tms-bridge",
  "version": "2.1.0",
  "systemVersion": "42",
  "gitCommit": "def456",
  "timestamp": "2026-02-24T12:30:00Z"
}
```

---

## Alternative: Extend Existing Health Check

If you prefer to add to existing endpoints instead of creating new ones:

### Option A: Add to Startup.cs

```csharp
// In Startup.cs Configure method, add before UseEndpoints:
app.UseEndpoints(endpoints =>
{
    endpoints.MapGet("/api/version", async context =>
    {
        var versionInfo = new
        {
            component = Environment.GetEnvironmentVariable("COMPONENT_NAME") ?? "disposition-backend",
            version = Environment.GetEnvironmentVariable("COMPONENT_VERSION") ?? "unknown",
            systemVersion = Environment.GetEnvironmentVariable("SYSTEM_VERSION") ?? "unknown",
            gitCommit = Environment.GetEnvironmentVariable("GIT_COMMIT") ?? "unknown",
            timestamp = DateTime.UtcNow
        };

        context.Response.ContentType = "application/json";
        await context.Response.WriteAsJsonAsync(versionInfo);
    });

    endpoints.MapControllers();
});
```

### Option B: Add to Existing Controller

If you have a HealthController or similar:

```csharp
[ApiController]
[Route("api")]
public class HealthController : ControllerBase
{
    // ... existing health methods ...

    [HttpGet("version")]
    public IActionResult GetVersion()
    {
        return Ok(new
        {
            component = Environment.GetEnvironmentVariable("COMPONENT_NAME") ?? "disposition-backend",
            version = Environment.GetEnvironmentVariable("COMPONENT_VERSION") ?? "unknown",
            systemVersion = Environment.GetEnvironmentVariable("SYSTEM_VERSION") ?? "unknown",
            gitCommit = Environment.GetEnvironmentVariable("GIT_COMMIT") ?? "unknown",
            timestamp = DateTime.UtcNow
        });
    }
}
```

---

## Cloud Run Deployment Configuration

When deploying to Cloud Run, environment variables are set by the pipeline:

```bash
gcloud run deploy disposition-backend \
  --image=europe-west3-docker.pkg.dev/.../disposition-backend:1.2.3 \
  --set-env-vars="COMPONENT_NAME=disposition-backend,COMPONENT_VERSION=1.2.3,SYSTEM_VERSION=42,GIT_COMMIT=abc123"
```

These environment variables are automatically available to the ASP.NET application via `Environment.GetEnvironmentVariable()`.

---

## Testing in Deployed Environment

```bash
# Test environment
curl https://test.dispo.gcp.nagel-group.com/api/version

# Production environment
curl https://prod.dispo.gcp.nagel-group.com/api/version
```

---

## CORS Configuration

If your frontend needs to call this endpoint, ensure CORS is configured in `Startup.cs`:

```csharp
// In ConfigureServices
services.AddCors(options =>
{
    options.AddPolicy("AllowSpecificOrigins", builder =>
    {
        builder
            .WithOrigins(Configuration["CorsOrigins"])
            .AllowAnyMethod()
            .AllowAnyHeader();
    });
});

// In Configure
app.UseCors("AllowSpecificOrigins");
```

The `/api/version` endpoint will automatically respect this CORS policy.

---

## Security Considerations

### Option 1: Public Endpoint (Recommended)
Version information is generally safe to expose publicly:
- No authentication required
- Useful for monitoring and debugging
- Similar to common `/health` endpoints

```csharp
[HttpGet]
[AllowAnonymous]  // Add this if you have global auth
public IActionResult GetVersion()
{
    // ...
}
```

### Option 2: Authenticated Endpoint
If you prefer to restrict access:

```csharp
[HttpGet]
[Authorize]  // Requires authentication
public IActionResult GetVersion()
{
    // ...
}
```

---

## Monitoring Integration

You can integrate this endpoint with monitoring tools:

### Prometheus Metrics

```csharp
// Add metrics endpoint
[HttpGet("metrics")]
public IActionResult GetMetrics()
{
    var version = Environment.GetEnvironmentVariable("COMPONENT_VERSION") ?? "unknown";
    var systemVersion = Environment.GetEnvironmentVariable("SYSTEM_VERSION") ?? "unknown";

    return Content($@"
# HELP service_version Current service version
# TYPE service_version gauge
service_version{{component=""disposition-backend"",version=""{version}"",system_version=""{systemVersion}""}} 1
", "text/plain");
}
```

### Structured Logging

Add version to startup logs:

```csharp
// In Program.cs Main method
public static void Main(string[] args)
{
    var logger = Log.Logger = new LoggerConfiguration()
        .ReadFrom.Configuration(configuration)
        .CreateLogger();

    logger.Information("Starting Disposition Backend");
    logger.Information("Component Version: {ComponentVersion}",
        Environment.GetEnvironmentVariable("COMPONENT_VERSION") ?? "unknown");
    logger.Information("System Version: {SystemVersion}",
        Environment.GetEnvironmentVariable("SYSTEM_VERSION") ?? "unknown");

    // ... rest of Main
}
```

---

## Summary

### What to Add:

1. **Create** `VersionController.cs` in each service
2. **Test** locally with environment variables
3. **Deploy** with environment variables from pipeline
4. **Verify** endpoint is accessible

### Environment Variables Set by Pipeline:

- `COMPONENT_NAME` - Service name (e.g., "disposition-backend")
- `COMPONENT_VERSION` - Component version (e.g., "1.2.3")
- `SYSTEM_VERSION` - System version number (e.g., "42")
- `GIT_COMMIT` - Git commit hash (e.g., "abc123")

These are automatically injected by the Azure Pipeline and Cloud Run deployment.
