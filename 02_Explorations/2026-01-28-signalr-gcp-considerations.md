# SignalR on GCP Cloud Run - Considerations & Setup

**Date:** 2026-01-28
**Project:** New Dispo - Backend on GCP Cloud Run
**Region:** europe-west3

---

## Overview

You're deploying SignalR on **GCP Cloud Run**, which has specific considerations for WebSocket-based real-time communication. This document covers challenges, configurations, and best practices.

---

## ✅ Good News: WebSocket Support

Cloud Run **fully supports WebSockets** as of 2021, with no additional configuration required for basic functionality.

- WebSockets work out-of-the-box
- Automatic TLS/SSL termination
- HTTP/2 and gRPC support included
- Native session stickiness during connection lifetime

---

## ⚠️ Critical Challenges & Solutions

### 1. **WebSocket Timeout Limits**

**Problem:**
- Default timeout: **5 minutes** (300 seconds)
- Maximum timeout: **60 minutes** (3600 seconds)
- Connection drops after timeout, even if active

**Your Current Config:**
```bash
# No timeout specified in azure-pipelines-cloudrun-p-p.yml
# Defaults to 5 minutes
```

**Solution:**

Update your Cloud Run deployment to set maximum timeout:

```bash
gcloud run deploy cal-new-disposition-backend-p-p \
  --image europe-west3-docker.pkg.dev/prj-cal-w-wl4-p-afad-53ad/cal-new-disposition-p-p-backend/cal-new-disposition-p-p-backend:latest \
  --project prj-cal-w-wl4-p-afad-53ad \
  --region europe-west3 \
  --port 5101 \
  --timeout 3600 \  # ADD THIS - 60 minutes max
  --cpu 1 \
  --memory 1Gi \
  # ... rest of your config
```

**Client-Side Handling:**

SignalR's `withAutomaticReconnect()` already handles this, but you should configure appropriate retry logic:

```typescript
const connection = new signalR.HubConnectionBuilder()
  .withUrl(hubUrl, { accessTokenFactory: () => token })
  .withAutomaticReconnect({
    nextRetryDelayInMilliseconds: (retryContext) => {
      // Reconnect before 60-minute timeout
      // More frequent reconnects as safety margin
      if (retryContext.previousRetryCount === 0) return 0;
      if (retryContext.previousRetryCount < 5) return 5000;  // 5s
      return 30000;  // 30s
    }
  })
  .build();
```

**Recommendation:** Set `--timeout 3600` and implement client-side reconnection logic.

---

### 2. **Multi-Instance Scaling (CRITICAL)**

**Problem:**
Cloud Run auto-scales based on traffic. When you have multiple instances:
- Client A connects to Instance 1
- Client B connects to Instance 2
- Message sent from Instance 1 won't reach Client B

**Your Current Config:**
```bash
# No min-instances or max-instances set
# Cloud Run will scale from 0 to N instances based on load
```

**Solution: Redis Backplane Required**

You **MUST** use a SignalR backplane to synchronize messages across instances.

#### Option 1: Google Cloud Memorystore (Recommended)

**Step 1: Create Memorystore Redis Instance**

```bash
gcloud redis instances create signalr-backplane \
  --size=1 \
  --region=europe-west3 \
  --network=projects/prj-cal-net-s-p-19c3-53ad/global/networks/vpc-c-shared-vpc-c-net-s-p \
  --connect-mode=PRIVATE_SERVICE_ACCESS \
  --tier=STANDARD_HA \
  --redis-version=redis_7_0
```

**Step 2: Add NuGet Package**

Add to `CALConsult.Disposition.API.csproj`:

```xml
<PackageReference Include="Microsoft.AspNetCore.SignalR.StackExchangeRedis" Version="8.0.0" />
```

**Step 3: Configure SignalR with Redis (Startup.cs)**

```csharp
public void ConfigureServices(IServiceCollection services)
{
    // ... existing services ...

    services.AddSignalR()
        .AddStackExchangeRedis(options =>
        {
            options.Configuration.EndPoints.Add(
                Configuration["Redis:Host"] ?? "10.0.0.3",  // Memorystore private IP
                6379
            );
            options.Configuration.Password = Configuration["Redis:Password"] ?? "";
            options.Configuration.AbortOnConnectFail = false;
            options.Configuration.ConnectTimeout = 5000;
            options.Configuration.SyncTimeout = 5000;
        });
}
```

**Step 4: Update Cloud Run Deployment**

Add Redis configuration as environment variables:

```bash
gcloud run deploy cal-new-disposition-backend-p-p \
  # ... existing config ...
  --set-env-vars REDIS_HOST=10.0.0.3,REDIS_PORT=6379 \
  --vpc-egress all-traffic \  # Already configured - ensures Redis access
```

**Cost Estimate:**
- Memorystore Standard HA (1GB): ~€45/month
- Memorystore Basic (1GB): ~€20/month (no HA)

#### Option 2: External Redis (Alternative)

Use Redis Cloud, Upstash, or self-hosted Redis if budget is tight.

**Recommendation:** Use Memorystore Standard HA for production reliability.

---

### 3. **Session Affinity**

**Problem:**
Cloud Run provides "best effort" session affinity, not guaranteed. New connections might route to different instances.

**Your Current Config:**
```bash
# No session affinity configured
```

**Solution:**

Enable session affinity in Cloud Run:

```bash
gcloud run services update cal-new-disposition-backend-p-p \
  --session-affinity \
  --region europe-west3 \
  --project prj-cal-w-wl4-p-afad-53ad
```

**Important:** Session affinity helps but is **NOT a replacement** for Redis backplane. Use both together.

---

### 4. **Health Checks**

**Problem:**
Cloud Run health checks might interfere with long-lived WebSocket connections.

**Solution:**

Add a dedicated health check endpoint that doesn't interfere with SignalR:

```csharp
// In Configure method (Startup.cs)
app.UseEndpoints(endpoints =>
{
    endpoints.MapControllers();
    endpoints.MapHub<NotificationHub>("/hubs/notifications");

    // Health check endpoint
    endpoints.MapGet("/health", () => Results.Ok(new { status = "healthy" }));
});
```

Update Cloud Run (if using custom health checks):

```bash
--no-cpu-throttling  # Prevents CPU throttling during idle WebSocket connections
```

---

### 5. **Billing Implications**

**Important:** Cloud Run billing for WebSockets differs from regular HTTP requests.

**How Billing Works:**
- Any instance with an **open WebSocket connection** is considered **active**
- CPU is allocated continuously (even if idle)
- Charged based on **instance time**, not per-request

**Example:**
- 1 instance with 10 WebSocket connections open for 1 hour
- Billed for: 1 CPU × 1 hour (not 10 connections × time)

**Your Current Config:**
```bash
--cpu 1
--memory 1Gi
```

**Cost Optimization:**

```bash
gcloud run deploy cal-new-disposition-backend-p-p \
  # ... existing config ...
  --cpu 1 \
  --memory 1Gi \
  --min-instances 1 \        # Keep 1 instance warm (optional)
  --max-instances 10 \       # Limit scaling to control costs
  --concurrency 1000 \       # Max connections per instance (Cloud Run supports up to 1000)
```

**Recommendation:** Start with `--max-instances 5` and monitor, scale as needed.

---

### 6. **CORS Configuration**

**Your Current Config:**
Already configured in `Startup.cs:60` via `AddOwnCors`.

**Verify CORS allows:**
- `Access-Control-Allow-Credentials: true` (required for SignalR)
- WebSocket upgrade headers

**Example:**

```csharp
services.AddCors(options =>
{
    options.AddPolicy("AllowSpecificOrigins", builder =>
    {
        builder
            .WithOrigins(
                "https://dispo.gcp.nagel-group.com",
                "http://localhost:4200"  // Dev only
            )
            .AllowAnyMethod()
            .AllowAnyHeader()
            .AllowCredentials()  // CRITICAL for SignalR
            .SetIsOriginAllowedToAllowWildcardSubdomains();
    });
});
```

---

### 7. **VPC Connector (Already Configured)**

**Your Setup:**
```bash
--network projects/prj-cal-net-s-p-19c3-53ad/global/networks/vpc-c-shared-vpc-c-net-s-p
--subnet projects/prj-cal-net-s-p-19c3-53ad/regions/europe-west3/subnetworks/sn-vpc-c-net-s-p-europe-west3-common
--vpc-egress all-traffic
```

✅ **Good to go** - This allows Cloud Run to access:
- Memorystore Redis (private IP)
- Cloud SQL PostgreSQL (already configured)
- Other VPC resources

---

### 8. **Authentication with Keycloak**

**Your Setup:**
Already using Keycloak JWT authentication.

**SignalR Configuration:**

SignalR supports JWT tokens passed via query string or headers:

```typescript
// Frontend - Pass JWT token
const connection = new signalR.HubConnectionBuilder()
  .withUrl('https://your-backend.com/hubs/notifications', {
    accessTokenFactory: () => this.authService.getToken()  // Get from Keycloak
  })
  .withAutomaticReconnect()
  .build();
```

**Backend - Hub Authorization:**

```csharp
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

[Authorize]  // Require authentication
public class NotificationHub : Hub
{
    public override async Task OnConnectedAsync()
    {
        var userId = Context.User?.Identity?.Name;
        Console.WriteLine($"User {userId} connected");
        await base.OnConnectedAsync();
    }

    [Authorize(Roles = "Admin")]  // Role-based authorization
    public async Task BroadcastToAll(string message)
    {
        await Clients.All.SendAsync("ReceiveMessage", message);
    }
}
```

---

## Complete Deployment Configuration

### Updated Cloud Run Deployment Command

```bash
gcloud run deploy cal-new-disposition-backend-p-p \
  --image europe-west3-docker.pkg.dev/prj-cal-w-wl4-p-afad-53ad/cal-new-disposition-p-p-backend/cal-new-disposition-p-p-backend:latest \
  --project prj-cal-w-wl4-p-afad-53ad \
  --region europe-west3 \
  --port 5101 \
  --cpu 1 \
  --memory 1Gi \
  --timeout 3600 \                    # ADD: 60-minute timeout
  --session-affinity \                # ADD: Session affinity
  --min-instances 1 \                 # ADD: Keep 1 warm (optional)
  --max-instances 10 \                # ADD: Scale limit
  --concurrency 1000 \                # ADD: Max concurrent connections
  --allow-unauthenticated \
  --network projects/prj-cal-net-s-p-19c3-53ad/global/networks/vpc-c-shared-vpc-c-net-s-p \
  --subnet projects/prj-cal-net-s-p-19c3-53ad/regions/europe-west3/subnetworks/sn-vpc-c-net-s-p-europe-west3-common \
  --vpc-egress all-traffic \
  --network-tags vpc-connector,postgres-user,http-web-user,https-user,p5101-user,p8080-user \
  --ingress internal \
  --add-cloudsql-instances prj-cal-w-wl4-p-afad-53ad:europe-west3:cal-new-disposition-postgres-p-p \
  --set-env-vars REDIS_HOST=10.x.x.x,REDIS_PORT=6379  # ADD: Redis config
```

---

## Implementation Checklist

### Backend

- [ ] Add `Microsoft.AspNetCore.SignalR.StackExchangeRedis` NuGet package
- [ ] Create Memorystore Redis instance in GCP
- [ ] Configure SignalR with Redis backplane in `Startup.cs`
- [ ] Add Redis connection string to `appsettings.Production.json`
- [ ] Add `/health` endpoint for health checks
- [ ] Add `[Authorize]` attributes to hub methods
- [ ] Update Cloud Run deployment with timeout, session-affinity, Redis env vars

### Frontend

- [ ] Install `@microsoft/signalr@^10.0.0`
- [ ] Create SignalR service with automatic reconnection
- [ ] Pass Keycloak JWT token via `accessTokenFactory`
- [ ] Handle reconnection events in UI
- [ ] Test connection across multiple Cloud Run instances

### Infrastructure (GCP)

- [ ] Create Memorystore Redis (Standard HA recommended)
- [ ] Update VPC firewall rules if needed (likely already OK)
- [ ] Configure Cloud Run with updated settings
- [ ] Set up monitoring for WebSocket connections
- [ ] Monitor Redis backplane performance

### Testing

- [ ] Test WebSocket connection establishment
- [ ] Test automatic reconnection after timeout
- [ ] Test message delivery across multiple instances
- [ ] Test authentication with Keycloak tokens
- [ ] Load test with concurrent connections
- [ ] Verify Redis backplane message propagation

---

## Monitoring & Observability

### Key Metrics to Monitor

1. **Cloud Run Metrics:**
   - Active instance count
   - Request count (WebSocket upgrades)
   - Request latency
   - CPU and memory utilization
   - Billable instance time

2. **Redis Metrics:**
   - Connected clients
   - Commands/sec
   - Memory usage
   - Pub/Sub channels

3. **SignalR Metrics:**
   - Active connections per instance
   - Message delivery success rate
   - Reconnection frequency

### Logging

Add structured logging to your hub:

```csharp
public class NotificationHub : Hub
{
    private readonly ILogger<NotificationHub> _logger;

    public NotificationHub(ILogger<NotificationHub> logger)
    {
        _logger = logger;
    }

    public override async Task OnConnectedAsync()
    {
        var userId = Context.User?.Identity?.Name;
        _logger.LogInformation("SignalR connection established - User: {UserId}, ConnectionId: {ConnectionId}",
            userId, Context.ConnectionId);
        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        _logger.LogInformation("SignalR connection closed - ConnectionId: {ConnectionId}, Exception: {Exception}",
            Context.ConnectionId, exception?.Message);
        await base.OnDisconnectedAsync(exception);
    }
}
```

---

## Cost Estimate (Monthly)

| Component | Configuration | Estimated Cost |
|-----------|---------------|----------------|
| Cloud Run (Backend) | 1-10 instances, 1 CPU, 1GB RAM | €50-200 (depends on usage) |
| Memorystore Redis (Standard HA) | 1GB | €45 |
| Memorystore Redis (Basic) | 1GB | €20 |
| Network Egress | Minimal (VPC internal) | ~€5 |
| **Total (with HA Redis)** | | **~€100-250/month** |
| **Total (without HA Redis)** | | **~€75-225/month** |

**Note:** Costs vary based on actual connection count and duration.

---

## Migration Path

### Phase 1: Foundation (Day 1)
- Set up Memorystore Redis
- Add Redis backplane to SignalR
- Update Cloud Run with timeout and session affinity
- Basic testing

### Phase 2: Integration (Day 2-3)
- Frontend SignalR service implementation
- Keycloak JWT integration
- Connection lifecycle management

### Phase 3: Production Hardening (Week 1)
- Load testing
- Monitoring setup
- Error handling refinement
- Documentation

---

## Known Limitations

1. **60-Minute Max Timeout**: No way to extend beyond 60 minutes on Cloud Run
2. **Best-Effort Session Affinity**: Not guaranteed, Redis backplane required
3. **Cold Starts**: First connection after scale-to-zero will be slower (use min-instances=1)
4. **Cost Model**: Active WebSocket = active instance = continuous billing

---

## Alternative: Azure SignalR Service

If GCP limitations become problematic, consider:

**Azure SignalR Service:**
- Managed service (no backplane needed)
- Unlimited connection time
- Global distribution
- ~€40/month for 1,000 concurrent connections

**Can work with GCP Cloud Run** - just point your backend to Azure SignalR endpoint.

---

## Sources & Documentation

### Official GCP Documentation
- [Using WebSockets on Cloud Run](https://docs.cloud.google.com/run/docs/triggering/websockets)
- [Set session affinity for services](https://docs.cloud.google.com/run/docs/configuring/session-affinity)
- [Configure request timeout for services](https://docs.cloud.google.com/run/docs/configuring/request-timeout)
- [Memorystore for Redis overview](https://docs.cloud.google.com/memorystore/docs/redis/memorystore-for-redis-overview)

### SignalR Documentation
- [Redis backplane for ASP.NET Core SignalR scale-out](https://learn.microsoft.com/en-us/aspnet/core/signalr/redis-backplane?view=aspnetcore-10.0)
- [SignalR Scaleout with Redis](https://learn.microsoft.com/en-us/aspnet/signalr/overview/performance/scaleout-with-redis)

### Community Resources
- [Improve responsiveness with session affinity on Cloud Run](https://cloud.google.com/blog/topics/developers-practitioners/improve-responsiveness-session-affinity-cloud-run/)
- [Building a WebSocket Chat service for Cloud Run tutorial](https://docs.cloud.google.com/run/docs/tutorials/websockets)
- [Scaling SignalR: Scaleout strategies, limits & alternatives](https://ably.com/topic/scaling-signalr)

---

## Summary

### Must-Do (Critical):
1. ✅ Add Redis backplane (Memorystore)
2. ✅ Set `--timeout 3600` on Cloud Run
3. ✅ Enable `--session-affinity`
4. ✅ Configure automatic reconnection on frontend

### Should-Do (Recommended):
1. Set `--min-instances 1` to avoid cold starts
2. Set `--max-instances 10` to control costs
3. Add structured logging for connections
4. Set up monitoring dashboards

### Nice-to-Have (Optional):
1. Implement custom reconnection strategies
2. Add connection status UI indicators
3. Implement graceful degradation for offline mode

**Total Additional Infrastructure Cost:** ~€45-65/month (Memorystore Redis)

**Additional Setup Time:** +2-3 hours beyond the basic SignalR foundation
