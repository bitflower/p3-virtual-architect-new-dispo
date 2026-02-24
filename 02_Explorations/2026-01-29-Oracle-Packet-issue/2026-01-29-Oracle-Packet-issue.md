# ORA-12570 TNS Packet Reader Failure Analysis

**Date**: 2026-01-29
**Issue**: ORA-12570: TNS:packet reader failure in GCP setup with 35 concurrent bordero/rollcart functions

---

## Executive Summary

**Problem**: ORA-12570 "TNS:packet reader failure" errors are occurring in our GCP Cloud Functions deployment with 35 branches, each running bordero and rollcart functions that connect to separate Oracle schemas.

**Root Cause**:
1. **No connection pooling configuration** - Connection strings lack explicit pooling parameters, leading to uncontrolled connection reuse
2. **GCP network timeouts** - Load balancers drop idle TCP connections after 10 minutes
3. **No connection validation** - Stale/dead pooled connections are returned without health checks
4. **Cloud Function lifecycle mismatch** - Container reuse across invocations attempts to reuse connections that have been dropped by GCP infrastructure

**Solution**:
- Add connection pooling parameters to all Oracle connection strings (`Max Pool Size=10`, `Connection Lifetime=300`, `Validate Connection=true`)
- Configure `SQLNET.EXPIRE_TIME=5` to send keepalive probes
- Force connection recycling every 5 minutes (before GCP's 10-minute timeout)

**Expected Impact**: Near-elimination of ORA-12570 errors, better resource utilization, improved reliability under concurrent load.

---

## Understanding Cloud Functions Connection Lifecycle

### Critical Misconception: "Stateless" Does NOT Mean "No Persistent Memory"

**The biggest misconception about Cloud Functions is what "stateless" actually means.**

#### What People Think "Stateless" Means

❌ **WRONG:** "Container is destroyed after every request, memory is cleared"
❌ **WRONG:** "No in-memory state exists between function invocations"
❌ **WRONG:** "Connection pools can't persist because functions are stateless"

#### What "Stateless" Actually Means

✓ **CORRECT:** "Don't design your application to rely on state being there (container may terminate unpredictably)"
✓ **CORRECT:** "Multiple containers may handle requests (no shared memory across containers)"
✓ **CORRECT:** "Session data should be stored externally (not in memory)"

**But containers ARE reused and in-memory state DOES persist across invocations!**

#### The Reality: Container Reuse

From [Google Cloud Functions Documentation](https://cloud.google.com/functions/docs/concepts/execution-environment):

> **"Container instances are reused across requests to optimize performance."**
>
> **"Global variables declared in your function's global scope are initialized when your function is cold-started, but they retain their values across subsequent warm-started invocations."**

**What this means in practice:**

```
Request 1 (Cold Start)
├─ GCP spins up new container
├─ Initialize .NET runtime
├─ Load assemblies
├─ Initialize static fields (including connection pools!)
├─ Execute function
└─ Return response → Container stays alive in memory

Request 2 (seconds later) - Warm Start
├─ Reuse same container
├─ .NET runtime still running
├─ Static fields still in memory (connection pool exists!)
├─ Execute function
└─ Return response → Container stays alive again

Request 3 (10 minutes later) - Still Warm Start
├─ Same container, same memory
├─ Connection pool STILL EXISTS
├─ Pool tries to return cached connection
└─ ❌ Connection was dropped by GCP → ORA-12570

Eventually (15+ minutes idle)
└─ Container terminated, memory cleared
```

**Container lifetime:** Typically 15 minutes after last invocation, but can be longer.

#### Proof: Static Variables Persist

You can verify this with a simple counter:

```csharp
public class MyFunction : IHttpFunction
{
    // This static variable PERSISTS across invocations!
    private static int _requestCounter = 0;

    public async Task HandleAsync(HttpContext context)
    {
        _requestCounter++;
        await context.Response.WriteAsync(
            $"This container has handled {_requestCounter} requests"
        );
    }
}
```

**Output from same container:**
```
Request 1: "This container has handled 1 requests"
Request 2: "This container has handled 2 requests"  ← Reused!
Request 3: "This container has handled 3 requests"  ← Still same container!
Request 4: "This container has handled 4 requests"  ← Still reusing!
```

**The counter proves container reuse is real and common.**

#### Why Connection Pools Can Persist

Oracle.ManagedDataAccess.Core stores connection pools in **static fields** inside the library:

```csharp
// Inside Oracle.ManagedDataAccess.Core (simplified)
internal static class OracleConnectionPoolManager
{
    // This dictionary persists for the entire AppDomain lifetime
    private static Dictionary<string, ConnectionPool> _pools = new();

    public static OracleConnection GetConnection(string connectionString)
    {
        if (!_pools.ContainsKey(connectionString))
        {
            _pools[connectionString] = new ConnectionPool(connectionString);
        }

        return _pools[connectionString].GetConnection();
    }
}
```

**When you call `new OracleConnection(connStr)`, it doesn't create a new pool - it retrieves from the static dictionary!**

#### The ORA-12570 Problem Exists BECAUSE of Container Reuse

**If containers were truly destroyed after each request:**
- ✓ No stale connections (pools destroyed each time)
- ❌ Terrible performance (constant cold starts = 2-5 second delays)
- ❌ High Oracle server load (constant connection churn)
- ❌ Higher costs (more CPU/memory for cold starts)

**Because containers are reused (the actual behavior):**
- ✓ Great performance (warm starts = 10-50ms)
- ✓ Efficient resource usage
- ❌ Connection pools persist and cache stale connections
- ❌ GCP drops TCP connections after 10 minutes while pool thinks they're valid

**Our solution (Connection Lifetime=300, Validate Connection=true) works BECAUSE containers are reused.** These parameters tell the persistent pool how to manage its cached connections.

#### This is Standard for All Serverless Platforms

- **AWS Lambda:** Same behavior (container reuse, warm starts)
- **Azure Functions:** Same behavior (instance reuse)
- **Google Cloud Run:** Same behavior (container reuse)

**Serverless platforms optimize for performance by reusing containers, which means in-memory state persists across invocations.**

---

### How GCP Cloud Functions Work

Now that we understand containers are reused, let's examine the lifecycle in detail.

Cloud Functions operate differently from traditional always-running servers, which is critical to understanding the Oracle connection issue:

#### 1. Cold Start vs Warm Start

**Cold Start** (First Invocation):
```
User Request → GCP spins up new container → Initialize runtime → Load dependencies →
Execute global scope → Create connection pool → Execute function → Keep container alive
```

**Warm Start** (Subsequent Invocation):
```
User Request → Reuse existing container → Skip initialization →
Reuse existing connection pool → Execute function
```

#### 2. Container Lifecycle Phases

**Phase 1: Initialization (Cold Start Only)**
- GCP allocates a new container/sandbox
- .NET runtime is initialized
- Application assemblies are loaded
- **Global scope code executes** (service registration, static initializers)
- Connection pools are created at this stage

**Phase 2: Invocation**
- HTTP request arrives
- Function handler is called
- DbContext is created from factory
- Connection is requested from the pool
- Database operations execute
- DbContext is disposed
- Connection returns to pool (NOT closed)
- Response is sent

**Phase 3: Idle State**
- Container remains alive for potential reuse
- Connection pools stay in memory
- TCP connections remain open (but idle)
- **Critical**: GCP infrastructure may drop idle TCP connections after 10 minutes
- Oracle may also close connections based on server timeout settings

**Phase 4: Container Reuse or Termination**
- If new request arrives within ~15 minutes: Container is reused (warm start)
- If no requests: Container is terminated, connections are lost
- **Problem**: Connection pool is unaware that underlying TCP connections were dropped

### How Our Application Creates Connections

Our code creates connections through this flow:

**1. Function Invocation** (`BorderoUploadFunction.cs`, `RollkartUploadFunction.cs`)
```csharp
public async Task<IActionResult> Handle(HttpRequest req)
{
    // Function executes
    var result = await _service.ProcessData(company, branch);
    // DbContext is disposed here, connection returns to pool
}
```

**2. Service Layer** (`DigiLiSService.cs`)
```csharp
public async Task ProcessData(int company, int branch)
{
    var context = await _contextProvider.GetVendorContextAsync(company, branch);
    // Use context
} // Context disposed, connection returned to pool
```

**3. Context Provider** (`DigiLiSDbContextProvider.cs`)
```csharp
public async Task<DigiLiSDbContext> GetVendorContextAsync(int company, int branch)
{
    var connectionString = await GetConnectionStringFromSecretManager(...);
    return _factory.CreateVendorContext(connectionString);
}
```

**4. Factory Creates Connection** (`DigiLiSDbContextFactory.cs:31-44`)
```csharp
private DbContextOptions<DigiLiSDbContext> GetVendorContextOptions(string connectionString)
{
    var optionsBuilder = new DbContextOptionsBuilder<DigiLiSDbContext>();
    var oracleConnection = new OracleConnection(connectionString);
    // No pooling parameters in connectionString!
    return optionsBuilder.UseOracle(oracleConnection).Options;
}
```

### Connection Pool Behavior in Cloud Functions

**What Happens in a Cold Start:**
```
1. Container starts
2. First OracleConnection created with connection string "User Id=digilis1034;..."
3. Oracle.ManagedDataAccess.Core creates a NEW connection pool for this connection string
4. Min Pool Size connections are established (default: 0, so none)
5. Function requests a connection
6. Pool creates 1 new connection to Oracle
7. Function completes, connection returns to pool
8. Connection stays in pool (NOT closed)
```

**What Happens in Warm Starts:**
```
9. Second request arrives (warm start)
10. Same connection pool exists from step 3
11. Function requests connection
12. Pool returns the SAME connection from step 6 (if still valid)
13. Function executes, returns connection to pool
```

**What Happens After 10+ Minutes Idle:**
```
14. Container is idle for 10 minutes
15. GCP load balancer drops the idle TCP connection
16. Connection pool is UNAWARE the TCP connection was dropped
17. New request arrives
18. Pool returns the "dead" connection
19. Application tries to use it → ORA-12570: TNS:packet reader failure
20. Retry logic kicks in, new connection is created
21. New connection works, returns to pool
```

### The Critical Problem

**Connection Pool Assumptions**:
- Connection pools are designed for long-running servers
- They assume TCP connections stay alive indefinitely
- They cache connections for performance

**Cloud Functions Reality**:
- Containers are ephemeral but may live for hours
- GCP infrastructure drops idle connections after 10 minutes
- Oracle may drop connections based on server settings
- Pool has no way to know the underlying TCP socket is dead

**Why This Causes ORA-12570**:
1. Application creates OracleConnection with no pooling parameters
2. Default pooling behavior: connections never expire (`Connection Lifetime=0` means infinite)
3. Connection is used, returned to pool, TCP socket stays open
4. 10+ minutes pass, GCP drops the TCP connection
5. Next invocation gets the "cached" connection from pool
6. Pool thinks connection is valid (it was never disposed)
7. Application tries to send Oracle TNS packets
8. Packet reader fails because TCP socket is closed → ORA-12570

### Why This Affects Multiple Branches

**Concurrent Load Multiplier Effect**:
```
35 branches × 2 functions (bordero + rollcart) = 70 potential concurrent functions
Each function = separate container with separate connection pool
Each connection string (DIGILIS-{company}-{branch}) = separate pool

Result: 35+ different connection pools, each caching stale connections
```

**Sequential Execution Per Branch**:
- Bordero function runs first (may take several minutes)
- Rollcart function runs after bordero completes
- Both reuse the same connection pool within the container
- If bordero finishes, container is idle until rollcart starts
- Connection becomes stale during this gap

### Current Connection String Format

```
User Id=digilis1034;Password=mockPassword;Data Source=digilis.1034:1521/digilis.1034;
```

**Missing Parameters**:
- No `Connection Lifetime` → connections never recycled
- No `Validate Connection` → no health check before use
- No `Max Pool Size` → unlimited connections possible
- No explicit `Pooling=true` → relying on default behavior

---

## Problem Overview

We're experiencing ORA-12570 errors in our GCP Cloud Functions deployment where 35 branches each spawn 2 functions (bordero and rollcart) in series, creating significant concurrent load on Oracle databases.

## Current Connection Handling

### Connection Factory Implementation

File: `DigiLiSDbContextFactory.cs:31-44`

```csharp
private DbContextOptions<DigiLiSDbContext> GetVendorContextOptions(string connectionString)
{
    var optionsBuilder = new DbContextOptionsBuilder<DigiLiSDbContext>();
    var oracleConnection = new OracleConnection(connectionString);

    return optionsBuilder.UseOracle(oracleConnection).Options;
}
```

### Current Connection String Format

```
User Id=digilis1034;Password=mockPassword;Data Source=digilis.1034:1521/digilis.1034;
```

**Critical Finding**: No connection pooling parameters are configured.

## Root Cause Analysis

### 1. No Connection Pooling Configuration

- Oracle.ManagedDataAccess.Core v23.9.1 uses connection pooling by default
- Without explicit limits, it can create too many connections or reuse stale connections
- With 35 branches × 2 functions = 70 concurrent connections, this overwhelms the Oracle server

### 2. GCP Network Timeouts

- GCP load balancers drop idle TCP connections after **10 minutes** (600 seconds)
- ORA-12570 "packet reader failure" occurs when trying to reuse pooled connections that have been dropped by GCP infrastructure
- No keepalive mechanism configured to prevent connection drops

### 3. No Connection Validation

- Pooled connections aren't validated before use
- Dead/stale connections get returned from the pool, causing immediate failures

### 4. Cloud Function Container Reuse

- Containers are reused across invocations (warm starts)
- Connection pools persist in memory between invocations
- Pools attempt to reuse connections that were dropped by GCP during idle periods
- No mechanism to detect or refresh stale connections

## Recommended Solution

### Oracle Connection String Parameters

Add these parameters to all connection strings in Google Secret Manager:

```
User Id=digilis1034;
Password=mockPassword;
Data Source=digilis.1034:1521/digilis.1034;
Pooling=true;
Min Pool Size=1;
Max Pool Size=10;
Connection Lifetime=300;
Connection Timeout=60;
Validate Connection=true;
Incr Pool Size=2;
Decr Pool Size=1;
```

### Parameter Explanations

| Parameter | Value | Purpose |
|-----------|-------|---------|
| **Pooling** | true | Explicitly enable connection pooling |
| **Min Pool Size** | 1 | Minimum connections to maintain per pool |
| **Max Pool Size** | 10 | Limit maximum connections per connection string |
| **Connection Lifetime** | 300 | Force reconnection every 5 minutes (below GCP's 10-min timeout) |
| **Connection Timeout** | 60 | Timeout for establishing new connections (seconds) |
| **Validate Connection** | true | Test connections before returning from pool |
| **Incr Pool Size** | 2 | Add 2 connections when pool exhausted |
| **Decr Pool Size** | 1 | Remove 1 connection when pool shrinks |

### Key Design Decisions

1. **Connection Lifetime = 300 seconds (5 minutes)**
   - Below GCP's 10-minute idle timeout
   - Ensures connections are recycled before network drops them
   - Prevents stale connection reuse
   - Works with Cloud Function container reuse pattern

2. **Max Pool Size = 10**
   - Limits connections per connection string
   - With 35+ different schemas, this prevents overwhelming Oracle
   - Oracle recommendation: 1-10 connections per CPU core
   - Each function typically needs 1-2 concurrent connections

3. **Validate Connection = true**
   - Tests connection health before returning from pool
   - Catches dead connections early
   - Small performance overhead but critical for reliability
   - Essential for detecting GCP-dropped connections

### Addressing Network Team Feedback: "Disposing Connections Neatly"

The network team has suggested ensuring that "every database connection is properly closed after use to prevent open connections and related problems." This is an important concern, and our solution addresses it - but not by closing connections immediately after each request. Here's why:

#### Current Code Already Disposes Correctly

Our application **already disposes connections properly** at the code level:

**Location:** `DigiLiSService.cs:144`
```csharp
await using var digiLiSContext = await dbContextProvider.GetDbContext(databaseIdentifier);
var shipmentOrders = digiLiSContext.DeliveryNoteShipmentOrders
    .Join(...)
    .ToList();
return shipmentOrders;
// DbContext automatically disposed here
```

The `await using` statement ensures DbContext is disposed at the end of each method call.

#### But Why Keep a Connection Pool?

**If we closed connections immediately after every request:**
- ❌ Every request would create a new TCP connection to Oracle (100-200ms overhead)
- ❌ SSL/TLS handshake repeated on every connection (expensive)
- ❌ Oracle server overwhelmed by constant connection/disconnection
- ❌ Function execution time increased by 20-30%
- ❌ **GCP timeout issue would still occur** (pool would just re-create dropped connections)

**Connection pooling is not optional - it's essential for performance.**

#### How Our Solution "Closes Connections Neatly"

Our solution achieves the network team's goal through **periodic connection recycling**:

**1. Connection Lifetime = 300 seconds**
- Every 5 minutes, connections are removed from the pool
- The underlying TCP connection is **closed properly**
- New fresh connection is created on next use
- This is "neat disposal" on a schedule that prevents stale connections

**2. Validate Connection = true**
- Before returning a connection from the pool, health is checked
- If the connection is dead/stale, it's **closed and discarded**
- A new connection is opened
- This catches any connections that became invalid between requests

**3. Max Pool Size = 10**
- Limits the maximum number of open connections per schema
- Prevents connection leaks and resource exhaustion
- Oracle sees a predictable, controlled number of connections

#### The Mental Model

Think of it like a car rental service:

**Without pooling (closing every time):**
```
Customer → Rent new car → Drive → Return & destroy car → Next customer needs new car
```
Very wasteful and expensive!

**With pooling (our solution):**
```
Customer → Rent car from lot → Drive → Return to lot → Next customer gets same car
Cars are replaced every 5 minutes (Connection Lifetime)
Cars are inspected before rental (Validate Connection)
Maximum 10 cars per lot (Max Pool Size)
```
Efficient, fast, but still ensures cars are in good condition.

#### What DbContext.Dispose() Actually Does

When you call `Dispose()` on a DbContext:
```csharp
await using var context = CreateContext(); // Get connection from pool
// ... use context ...
// Dispose() called here - returns connection to pool, does NOT close it
```

**DbContext.Dispose() ≠ Close TCP Connection**

DbContext.Dispose() tells the connection pool: "I'm done with this connection, someone else can use it." The pool keeps it open for the next request.

#### Summary: We're Already Following Best Practices

| Concern | How Our Solution Addresses It |
|---------|-------------------------------|
| Connections left open indefinitely | `Connection Lifetime=300` closes them every 5 min |
| Stale/dead connections reused | `Validate Connection=true` detects and closes them |
| Too many connections | `Max Pool Size=10` limits per schema |
| Proper code-level disposal | `await using` already implemented correctly |
| Network timeouts | Connections recycled before GCP's 10-min timeout |

**The network team's concern is valid and important - and our solution addresses it through industry-standard connection pooling best practices rather than naive connection closing.**

## Where Connection Pools Are Managed

A critical concept to understand is **where connection pools actually live** in the Cloud Functions architecture. This affects troubleshooting, monitoring, and understanding the behavior of the system.

### Connection Pool Location: Client-Side (In-Memory in Cloud Functions)

**Connection pools are NOT managed on the Oracle database server.**

Connection pools are managed by the **Oracle.ManagedDataAccess.Core** client library, which runs **inside each Cloud Function container's memory**.

```
┌─────────────────────────────────────────────────┐
│  Cloud Function Container (In GCP Cloud)        │
│  ┌───────────────────────────────────────────┐  │
│  │  .NET Runtime (In-Memory)                 │  │
│  │  ┌─────────────────────────────────────┐  │  │
│  │  │ Oracle.ManagedDataAccess.Core       │  │  │
│  │  │                                     │  │  │
│  │  │ Connection Pool #1 (DIGILIS-10-52) │  │  │
│  │  │ ├─ Connection 1 (TCP to Oracle)    │  │  │
│  │  │ ├─ Connection 2 (TCP to Oracle)    │  │  │
│  │  │ └─ Connection 3 (TCP to Oracle)    │  │  │
│  │  │                                     │  │  │
│  │  │ Connection Pool #2 (DIGILIS-10-53) │  │  │
│  │  │ ├─ Connection 1 (TCP to Oracle)    │  │  │
│  │  │ └─ Connection 2 (TCP to Oracle)    │  │  │
│  │  └─────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
         │
         │ TCP connections travel through
         │ GCP Load Balancers (timeout: 10 min)
         ▼
┌─────────────────────────────────────────────────┐
│  Oracle Database Server (On-Premise/Cloud)      │
│  - Sees individual TCP connections              │
│  - No knowledge of client-side pools            │
│  - Each connection appears as a separate session│
└─────────────────────────────────────────────────┘
```

### Key Implications

#### 1. Each Container Has Its Own Pool(s)

```
Branch 10, Company 52, Bordero Function:
  Container A → Pool for "DIGILIS-10-52" → 3 connections to Oracle

Branch 10, Company 52, Rollcart Function:
  Container B → Pool for "DIGILIS-10-52" → 2 connections to Oracle

Branch 10, Company 53, Bordero Function:
  Container C → Pool for "DIGILIS-10-53" → 4 connections to Oracle
```

**Result:** Multiple containers can each have their own pool for the same connection string. Oracle sees 3+2+4 = 9 total connections for company 52.

#### 2. Pools Are Scoped to Connection Strings

Oracle.ManagedDataAccess.Core creates a **separate pool for each unique connection string**:

```csharp
// Two different connection strings = two different pools
string connStr1 = "User Id=digilis1052;Password=xxx;Data Source=digilis.1052:1521/digilis.1052;...";
string connStr2 = "User Id=digilis1053;Password=xxx;Data Source=digilis.1053:1521/digilis.1053;...";

var conn1 = new OracleConnection(connStr1); // Uses Pool #1
var conn2 = new OracleConnection(connStr2); // Uses Pool #2 (separate!)
var conn3 = new OracleConnection(connStr1); // Reuses Pool #1
```

**With 35 branches:** Each container may have **up to 35 different connection pools** in memory (one per schema).

#### 3. Pools Persist As Long As Container Lives

**Cold Start:**
```
1. Container starts
2. First OracleConnection created
3. Pool is created in memory
4. Connection established to Oracle
5. Function completes
6. Container stays alive, pool stays in memory
```

**Warm Start (minutes later):**
```
7. Same container reused
8. Pool still exists in memory
9. Connection from pool is reused (if still valid)
10. No new pool creation
```

**Container Termination:**
```
11. After ~15 minutes of inactivity
12. GCP terminates container
13. Pool is destroyed (memory released)
14. All connections are closed
15. Next request = cold start, new pool
```

#### 4. The Pool Cannot See GCP Network Timeouts

**The problem visualized:**

```
Time 0:00 - Function executes
            Container: Pool has Connection A (TCP socket open)
            GCP: TCP socket for Connection A is active
            Oracle: Session for Connection A is active

Time 0:05 - Function completes
            Container: Connection A returned to pool (TCP socket still open)
            GCP: TCP socket idle
            Oracle: Session idle

Time 10:00 - GCP timeout
            Container: Pool still thinks Connection A is valid
            GCP: ❌ Drops TCP socket (10-min idle timeout)
            Oracle: Session may still be open (waiting)

Time 10:01 - New function execution
            Container: Pool returns Connection A
            Application tries to send data
            TCP socket is closed → ORA-12570
```

The pool has **no visibility into GCP's network layer** that drops the TCP socket.

#### 5. Why Connection Lifetime Fixes This

```
With Connection Lifetime = 300 seconds:

Time 0:00 - Connection A created
Time 5:00 - Connection A marked as "expired" (5 min lifetime)
            Pool closes Connection A properly
            Pool removes it from available connections
Time 5:01 - New request
            Pool creates Connection B (fresh)
            ✓ No stale connection issue
Time 10:00 - GCP timeout (irrelevant, connection already closed at 5:00)
```

**Connection Lifetime gives the pool a "maximum age" policy that prevents connections from living long enough to hit GCP timeouts.**

#### 6. Oracle Server's Perspective

From Oracle's point of view:
- Each TCP connection appears as a separate database session
- Oracle has **no knowledge** of client-side connection pools
- Oracle sees `SELECT * FROM v$session` showing many sessions from the same source IP
- Oracle doesn't know if a client-side pool is reusing connections

**Optional: Database Resident Connection Pooling (DRCP)**

Oracle *does* have **server-side connection pooling** called DRCP:
- Pool managed **on the Oracle server**
- Multiple clients share a smaller pool of server-side connections
- Reduces server-side resource usage
- Requires connection string change: `Data Source=...;Pooled=true;` or `:POOLED` suffix
- **This is optional and separate from client-side pooling**

With DRCP:
```
Client Side (Cloud Function):
  Pool #1 → Connection String with ":POOLED"
           ↓
Server Side (Oracle):
  DRCP Pool → 100 shared server processes
  Your connection temporarily uses one, then releases it
```

DRCP can complement client-side pooling but doesn't replace it.

### Monitoring Connection Pools

Since pools are client-side (in-memory in Cloud Functions):

**You CANNOT monitor pools from:**
- ❌ Oracle database queries (`v$session` shows connections, not pools)
- ❌ GCP Cloud Console (no visibility into application memory)
- ❌ Network monitoring tools (only see TCP connections)

**You CAN monitor pools through:**
- ✓ Application logging (add logging to `DigiLiSDbContextFactory`)
- ✓ Cloud Logging (search for ORA-12570 errors)
- ✓ Oracle session counts over time (`SELECT count(*) FROM v$session WHERE username = 'DIGILIS1052'`)
- ✓ GCP Cloud Functions metrics (invocation count, errors)

**Adding Pool Statistics Logging (Optional):**

```csharp
// In DigiLiSDbContextFactory.cs
private DbContextOptions<DigiLiSDbContext> GetVendorContextOptions(string connectionString)
{
    var optionsBuilder = new DbContextOptionsBuilder<DigiLiSDbContext>();
    var oracleConnection = new OracleConnection(connectionString);

    // Log pool statistics (if Oracle provides them)
    logger.LogInformation(
        "Creating Oracle connection for {Schema}. Pool stats: {Stats}",
        ExtractSchema(connectionString),
        GetPoolStats(connectionString) // Custom method to inspect pool
    );

    return optionsBuilder.UseOracle(oracleConnection).Options;
}
```

Note: Oracle.ManagedDataAccess.Core doesn't expose rich pool statistics APIs, so direct monitoring is limited.

### Summary: Client-Side vs Server-Side

| Aspect | Client-Side Pool (Our Case) | Server-Side Pool (DRCP) |
|--------|----------------------------|-------------------------|
| **Location** | Cloud Function container memory | Oracle database server |
| **Managed by** | Oracle.ManagedDataAccess.Core | Oracle Database |
| **Lifetime** | Lives as long as container | Lives as long as database |
| **Scope** | One pool per connection string per container | One shared pool for all clients |
| **Configuration** | Connection string parameters | Oracle SQL commands |
| **Our solution** | ✓ Using this | Optional enhancement |

**Bottom Line:** Connection pools in our architecture are **client-side, in-memory, in Cloud Functions containers**. The GCP network timeout issue occurs because these in-memory pools attempt to reuse TCP connections that GCP has dropped, and the pool has no way to know the connection is dead until it tries to use it.

Our solution (`Connection Lifetime=300`, `Validate Connection=true`) gives the pool the tools it needs to manage connection health proactively.

## Additional Configuration: SQLNET.EXPIRE_TIME

Oracle's `SQLNET.EXPIRE_TIME` parameter sends keepalive probes to prevent firewall/load balancer timeouts.

### Option 1: Programmatic Configuration

Add to `DigiLiSDbContextFactory` or startup:

```csharp
// During application startup
OracleConfiguration.SqlNetExpireTime = 5; // Send keepalive every 5 minutes
```

### Option 2: Via Connection String

```
...;Statement Cache Size=10;Load Balancing=true;
```

Note: Oracle.ManagedDataAccess.Core may have limited support for sqlnet.ora file-based configuration. Programmatic configuration is preferred.

## Implementation Steps

### Step 1: Update Secret Manager Connection Strings

For each of the 35+ database connection strings in Google Secret Manager (format: `DIGILIS-{company}-{branch}`):

1. Retrieve current secret value
2. Append pooling parameters
3. Update secret with new version

Example script:
```bash
# Get current secret
gcloud secrets versions access latest --secret="DIGILIS-10-52"

# Update with new connection string including pooling parameters
echo "User Id=digilis1052;Password=xxx;Data Source=...;Pooling=true;Min Pool Size=1;Max Pool Size=10;Connection Lifetime=300;Connection Timeout=60;Validate Connection=true;Incr Pool Size=2;Decr Pool Size=1;" | \
  gcloud secrets versions add DIGILIS-10-52 --data-file=-
```

### Step 2: Add SQLNET.EXPIRE_TIME Configuration

Update `DigiLiSSetupExtensions.cs`:

```csharp
public static IServiceCollection AddDigiLiS(this IServiceCollection services)
{
    // Configure Oracle keepalive
    OracleConfiguration.SqlNetExpireTime = 5; // 5 minutes

    services.AddScoped<IDigiLiSDbContextFactory, DigiLiSDbContextFactory>();
    services.AddScoped<IDigiLiSDbContextProvider, DigiLiSDbContextProvider>();
    services.AddScoped<IDigiLiSService, DigiLiSService>();

    return services;
}
```

### Step 3: Add Connection Pool Monitoring (Optional)

Update `DigiLiSDbContextFactory.cs` to log pool statistics:

```csharp
private DbContextOptions<DigiLiSDbContext> GetVendorContextOptions(string connectionString)
{
    var optionsBuilder = new DbContextOptionsBuilder<DigiLiSDbContext>();
    var oracleConnection = new OracleConnection(connectionString);

    // Optional: Log for debugging
    logger.LogDebug("Creating Oracle connection for schema {Schema}",
        connectionString.Contains("digilis") ? "digilis..." : "unknown");

    return optionsBuilder.UseOracle(oracleConnection).Options;
}
```

### Step 4: Testing

1. Deploy updated configuration to a single branch first
2. Monitor for ORA-12570 errors
3. Check Cloud Logging for connection pool behavior
4. Gradually roll out to remaining branches

## Alternative: Database Resident Connection Pooling (DRCP)

If you control the Oracle database server, consider enabling DRCP:

### Benefits
- Handles tens of thousands of concurrent connections
- Server-side connection pooling
- Better resource utilization

### Configuration

On Oracle database:
```sql
-- Start connection pool
EXEC DBMS_CONNECTION_POOL.START_POOL();

-- Configure pool
EXEC DBMS_CONNECTION_POOL.ALTER_PARAM('', 'MINSIZE', '5');
EXEC DBMS_CONNECTION_POOL.ALTER_PARAM('', 'MAXSIZE', '100');
EXEC DBMS_CONNECTION_POOL.ALTER_PARAM('', 'INCRSIZE', '5');
```

Update connection string:
```
...;Data Source=digilis.1034:1521/digilis.1034:POOLED;
```

Note: Requires Oracle Database 11g or higher.

## Expected Outcomes

After implementing these changes:

1. **Reduced ORA-12570 errors**: Connection validation prevents stale connection usage
2. **Better resource utilization**: Connection pooling limits prevent overwhelming Oracle
3. **Automatic connection refresh**: Connection Lifetime ensures fresh connections
4. **Network resilience**: Keepalive probes prevent timeout-based drops
5. **Cloud Function compatibility**: Connection recycling works with container reuse pattern

## Monitoring

Monitor these metrics post-deployment:

- ORA-12570 error frequency (should approach zero)
- Connection pool statistics (if logging enabled)
- Oracle database session counts
- Cloud Function cold start latency (may increase slightly with validation)
- Overall function success rate

## References

- [Simulating KeepAlive in Oracle with SQLNET.EXPIRE_TIME](https://vahiddb.com/en/oracle/database-administration/simulating-keepalive-in-oracle-with-sqlnet-expire-time-a-solution-for-firewall-enforced-environments-and-idle-sessions-en)
- [Database Resident Connection Pool (DRCP) in Oracle Database](https://oracle-base.com/articles/11g/database-resident-connection-pool-11gr1)
- [Configuring Database Resident Connection Pooling](https://docs.oracle.com/cd/B28359_01/server.111/b28310/manproc004.htm)
- [Session Pooling and Connection Pooling in OCI](https://docs.oracle.com/en/database/oracle/oracle-database/18/lnoci/session-and-connection-pooling.html)
- [ODP.NET – "Pooling" and "Connection request timed out"](https://blog.ilab8.com/2011/09/02/odp-net-pooling-and-connection-request-timed-out/)
- [GCP Connection Timeout Documentation](https://cloud.google.com/knowledge/kb/connection-timeout-when-connecting-to-sql-instance-000004506)
- [Oracle Documentation - ORA-12570](https://docs.oracle.com/error-help/db/ora-12570/)

## Technical Context

### Affected Components

- **Functions**: BorderoUploadFunction, RollkartUploadFunction
- **Services**: DigiLiSService
- **Infrastructure**: DigiLiSDbContextFactory, DigiLiSDbContextProvider
- **Dependencies**: Oracle.ManagedDataAccess.Core v23.9.1, Oracle.EntityFrameworkCore v8.23.60

### Connection Architecture

```
Cloud Functions (35 branches × 2 functions)
    ↓
DigiLiSDbContextFactory
    ↓
Google Secret Manager (retrieve connection string)
    ↓
OracleConnection (with pooling parameters)
    ↓
Oracle Database (per schema: DIGILIS{company}{branch})
```

### Existing Retry Logic

The codebase already has retry logic for Oracle operations:
- Max retry count: **5 attempts**
- Exponential backoff: `100 * Math.Pow(2, retryAttempt - 1)` milliseconds
- Catches `DbException`

This retry logic will work better with connection validation enabled, as it can quickly retry after detecting a dead connection.

---

## Summary and Conclusion

### The Problem in Simple Terms

Our Cloud Functions are trying to reuse database connections that were silently dropped by Google's network infrastructure after 10 minutes of inactivity. The connection pool doesn't know these connections are dead, so it hands them back to our code, which immediately fails with ORA-12570 errors.

### Why This Happens Specifically in Cloud Functions

Unlike traditional servers that run continuously, Cloud Functions:
- Spin up on demand and may stay alive for hours
- Reuse containers and connection pools across multiple invocations
- Experience unpredictable idle periods between invocations
- Are subject to GCP infrastructure timeouts that don't exist in traditional hosting

This creates a perfect storm where connection pools designed for always-running servers encounter network timeouts designed for stateless serverless functions.

### The Fix

Two simple configuration changes eliminate the problem:

1. **Connection Lifetime = 300 seconds**: Forces new connections every 5 minutes, before GCP can drop them
2. **Validate Connection = true**: Checks connection health before use, catches any that slip through

### Implementation Priority

**Critical** (Do immediately):
- Add `Connection Lifetime=300` to all connection strings
- Add `Validate Connection=true` to all connection strings
- Add `Max Pool Size=10` to prevent connection explosion

**Important** (Do soon):
- Add `OracleConfiguration.SqlNetExpireTime = 5` to keep connections alive
- Add logging to monitor connection pool behavior

**Optional** (Nice to have):
- Consider DRCP for server-side pooling if you control the database
- Add metrics/dashboards for ongoing monitoring

### Expected Timeline

- **Configuration change**: 1-2 hours to update all 35+ secrets in Secret Manager
- **Code change**: 30 minutes to add SqlNetExpireTime configuration
- **Testing**: Deploy to 1 branch, monitor for 24 hours
- **Full rollout**: Gradual deployment over 1 week with monitoring

### Success Criteria

- ORA-12570 error rate drops to near zero (< 0.1% of requests)
- Oracle database connection count remains stable and predictable
- Function success rate improves to > 99.9%
- No increase in function execution time or cold start latency

### Risk Assessment

**Low Risk Changes**:
- Adding pooling parameters only affects how connections are managed
- No code changes required, only configuration
- Can be rolled back instantly by reverting Secret Manager versions
- Changes are well-documented Oracle best practices

**Potential Issues**:
- Slight increase in connection creation overhead (negligible)
- Small validation overhead per connection use (~10ms)
- May expose other latent database issues if connections were hiding problems

### Next Steps

1. **Immediate**: Update connection strings in Secret Manager with pooling parameters
2. **Day 1**: Deploy to single test branch, monitor for 24 hours
3. **Day 2**: If successful, deploy to 5 branches
4. **Week 1**: Gradual rollout to all 35 branches
5. **Week 2**: Add SqlNetExpireTime configuration as code change
6. **Week 3**: Review metrics and adjust pool sizes if needed

This solution addresses the fundamental mismatch between Cloud Functions' ephemeral nature and Oracle's connection pooling expectations, resulting in reliable database connectivity regardless of function invocation patterns.
