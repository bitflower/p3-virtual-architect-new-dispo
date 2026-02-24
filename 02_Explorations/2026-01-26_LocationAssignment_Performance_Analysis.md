# Location Assignment App - Performance Analysis Report

## Executive Summary

The Location Assignment application is experiencing critical performance issues with database queries taking 30+ seconds, causing cascade failures across the system. The root cause is a combination of missing database indexes, massive data volume (24M strategy records, 272M+ variable records), and cross-microservice synchronization issues.

## System Architecture Overview

### What is the Location Assignment App?

The Location Assignment system is a **configurable decision-making engine** that determines optimal warehouse storage locations for items. It operates through:

- **Strategies**: Configurable workflows that evaluate multiple criteria to find optimal storage locations
- **Strategy Templates**: Reusable blueprints defining decision logic
- **Strategy Steps**: Individual decision points (EvaluateItem, EvaluateSpace, CreateMovementRequest)
- **Variables**: Key-value pairs storing decision context during execution

### Business Value

Strategies handle various operational scenarios:
- **Inbound Processing**: Where to store incoming goods
- **Replenishment**: Moving items from bulk to pick locations
- **Cross-Docking**: Direct transfer without storage
- **Returns Processing**: Handling returned merchandise
- **Relocation**: Optimizing existing inventory placement

## Critical Performance Issues Identified

### 1. Database Query Performance Crisis

**Primary Issue**: 30+ second database queries causing system-wide failures

**Evidence from Logs**:
```
Failed executing DbCommand (30,031ms)
SELECT l.* FROM location_assignment AS l
WHERE l.owner_id = ANY (@__ToList_0) AND l.status = 1 
AND EXISTS (
    SELECT 1 FROM strategy AS s
    WHERE l.id = s.location_assignment_id 
    AND EXISTS (
        SELECT 1 FROM variable AS v
        WHERE s.id = v.strategy_id 
        AND v.key = 'handlingUnit.Id' 
        AND v.value = @__ToString_1
    )
)
```

**Query Execution Plan Analysis**:
- **Sequential scan** on variable table: 272+ million rows examined
- **42+ seconds** spent on variable table lookup alone
- **Only 582 rows** matched out of 272 million scanned
- **Missing critical indexes** on composite key lookups

### 2. Data Volume Issues

**Massive Data Accumulation**:
- **24 million strategy records** in strategy table
- **272+ million variable records** in variable table
- **No automatic cleanup** of completed strategies
- **High-volume warehouse operations** creating millions of records daily

**Data Growth Pattern**:
```
LocationAssignment → Strategy → StrategySteps → Variables
     (1)          →    (1+)   →     (multiple) →  (multiple)
```

### 3. Missing Database Indexes

**Current Index Coverage** (from migration analysis):
```sql
-- Existing indexes (basic coverage):
ix_strategy_location_assignment_id     -- strategy(location_assignment_id)
ix_variable_strategy_id                -- variable(strategy_id)
ix_location_assignment_owner_id        -- location_assignment(owner_id)
ix_location_assignment_status          -- location_assignment(status)
```

**Critical Missing Indexes**:
```sql
-- MISSING: Composite index for variable lookups (PRIMARY BOTTLENECK)
ix_variable_strategy_id_key_value      -- variable(strategy_id, key, value)

-- MISSING: Specialized index for hot lookup patterns
ix_variable_key_value                  -- variable(key, value)

-- MISSING: Composite filtering indexes
ix_location_assignment_owner_id_status -- location_assignment(owner_id, status)
```

## Application-Level Issues

### 1. Dictionary Key Errors

**Error Pattern**:
```
System.Collections.Generic.KeyNotFoundException: 
"The given key 'strategyId' was not present in the dictionary."
```

**Root Cause**: Unsafe header access in message processing
```csharp
// Problematic code in LocationAssignmentStrategyHelper.cs line 312:
id ??= messageContext.Headers.Get<long>("strategyId"); // Throws exception if key missing
```

**Error Flow**:
1. Database query times out (30+ seconds)
2. Message processing fails
3. Message gets retried with incomplete headers
4. Code tries to access missing `strategyId` header
5. KeyNotFoundException thrown

### 2. Message Processing Architecture

**Entry Points for Events**:
- **Primary**: `LocationAssignmentTriggerEventHandler` (handles raw messages from queue)
- **Queue**: `events/Subscriptions/prd_locationassignment_events`
- **Secondary**: Various specialized handlers for strategy execution results

**Supported Trigger Events** (12 types):
```csharp
// Inbound Events
HandlingUnitReceivedEvent, HandlingUnitInitializedEvent, HandlingUnitSpaceChangedEvent

// Outbound Events  
LoadingRequestedEvent, HandlingUnitOutboundRequestedEvent, OutboundDeliveryHandlingUnitCreatedEvent

// Movement Events
RelocationRequestedEvent, ReplenishmentRequestedEvent, MovementRequestFailedEvent

// Processing Events
IntendedDestinationChangedEvent, ReversePickingFinishedEvent, GoodsSplitDestinationRequestedEvent
```


## Complete Failure Cascade Analysis

### The Cascade Pattern

**1. Database Performance Issue** (Root Cause):
```
PostgreSQL Query (30+ seconds) 
→ Network timeout/connection failure
→ NpgsqlException: "Exception while reading from stream"
→ EntityFramework QueryIterationFailed
```

**2. Message Processing Failure**:
```
LocationAssignmentTriggerEventHandler processing message
→ Database query times out
→ Message processing fails
→ Message gets retried or dead-lettered
```

**3. Retry Message Corruption**:
```
Retry message arrives with incomplete/missing headers
→ LocationAssignmentStrategyHelper.GetRunningLocationAssignmentAsync()
→ messageContext.Headers.Get<long>("strategyId") 
→ KeyNotFoundException: "The given key 'strategyId' was not present"
```

### Error Timeline Evidence

**Error Sequence from Logs**:
1. **Database Timeout**: `Microsoft.EntityFramework.Core.Query.QueryIterationFailed`
2. **Processing Failure**: `LocationAssignmentTriggerEventHandler.HandleAsync() line 102`
3. **Dictionary Error**: `The given key 'strategyId' was not present in the dictionary`
4. **Cross-Service Error**: `Unable to find party with ID: '203307'`

## Immediate Solutions

### 1. Emergency Database Indexes (Deploy Today)

**Critical Index for Variable Lookups**:
```sql
-- This will fix the 30-second queries
CREATE INDEX CONCURRENTLY ix_variable_strategy_id_key_value 
ON variable(strategy_id, key, value);

-- Specialized index for hot handlingUnit.Id lookups
CREATE INDEX CONCURRENTLY ix_variable_handling_unit_lookup 
ON variable(value, strategy_id) 
WHERE key = 'handlingUnit.Id';
```

**Supporting Indexes**:
```sql
-- Composite index for location assignment filtering
CREATE INDEX CONCURRENTLY ix_location_assignment_owner_id_status 
ON location_assignment(owner_id, status);

-- Strategy status filtering
CREATE INDEX CONCURRENTLY ix_strategy_location_assignment_id_status 
ON strategy(location_assignment_id, status);
```

### 2. Application Resilience Fixes (Deploy Immediately)

**Safe Header Access**:
```csharp
// Replace unsafe header access in LocationAssignmentStrategyHelper
private async Task<Strategy> GetStrategyAsync(long? id = null)
{
    if (id == null)
    {
        // Safe header access - won't throw exception
        if (!messageContext.Headers.TryGet<long>("strategyId", out var headerStrategyId))
        {
            logger.LogWarning("No strategyId in message headers - message may be corrupted retry");
            throw new InvalidOperationException("Cannot process message without strategyId");
        }
        id = headerStrategyId;
    }
    
    // Continue with database query (which should now be fast)
}
```

**Message Validation**:
```csharp
private bool ValidateMessageHeaders()
{
    var requiredHeaders = new[] { "strategyId" };
    
    foreach (var header in requiredHeaders)
    {
        if (!messageContext.Headers.ContainsKey(header))
        {
            logger.LogError("Message missing required header: {Header}", header);
            return false;
        }
    }
    return true;
}
```

## Medium-Term Solutions

### 1. Data Archival Strategy (This Week)

**Archive Completed Strategies**:
```sql
-- Archive strategies older than 30 days
CREATE TABLE strategy_archive AS 
SELECT * FROM strategy 
WHERE status IN ('Match', 'NoMatch', 'Error') 
  AND updated_at < NOW() - INTERVAL '30 days';

-- Archive related variables
CREATE TABLE variable_archive AS
SELECT v.* FROM variable v
INNER JOIN strategy_archive sa ON v.strategy_id = sa.id;

-- Clean up main tables
DELETE FROM variable WHERE strategy_id IN (SELECT id FROM strategy_archive);
DELETE FROM strategy WHERE id IN (SELECT id FROM strategy_archive);
```

### 2. Query Optimization

**Direct Strategy Lookups** (instead of complex joins):
```csharp
// More efficient approach
var strategy = await strategyRepository
    .GetQueryAsync(AuthorisationType.CurrentPartyHierarchy)
    .Where(s => s.Id == strategyId)  // Direct strategy lookup
    .Include(s => s.LocationAssignment)
    .FirstOrDefaultAsync();
```

### 3. Cross-Service Reference Cleanup

**Event-Driven Cleanup**:
```csharp
// Listen for deletion events from other services
public async Task HandleAsync(HandlingUnitArchivedEvent @event)
{
    // Archive strategies that reference this handling unit
    await ArchiveStrategiesByHandlingUnitId(@event.HandlingUnitId);
}
```

## Long-Term Architecture Improvements

### 1. Caching Strategy

**Hybrid Caching Approach**:
```csharp
// Cache only ACTIVE strategies
IMemoryCache activeStrategies; // Only running strategies
// Database for historical/completed strategies

// Redis cache for cross-service data
IDistributedCache crossServiceDataCache;
```

### 2. Data Lifecycle Management

**Automated Cleanup**:
- Configurable retention periods for completed strategies
- Automatic archival of old data
- Monitoring of data growth patterns

### 3. Circuit Breaker Pattern

**Prevent Cascade Failures**:
```csharp
public async Task<Party> GetPartyWithCircuitBreaker(long partyId)
{
    return await circuitBreaker.ExecuteAsync(async () => 
    {
        return await partyService.GetByIdAsync(partyId);
    });
}
```

## Monitoring and Validation

### Database Performance Monitoring

**PostgreSQL Queries**:
```sql
-- Monitor query performance improvement
SELECT 
    query,
    calls,
    mean_time,
    total_time
FROM pg_stat_statements 
WHERE query LIKE '%variable%' 
  AND query LIKE '%handlingUnit.Id%'
ORDER BY mean_time DESC;

-- Check index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan as times_used,
    idx_tup_read as tuples_read
FROM pg_stat_user_indexes 
WHERE tablename IN ('strategy', 'variable', 'location_assignment')
ORDER BY tablename, idx_scan DESC;
```

### Application Monitoring

**Key Metrics to Track**:
- Query execution times (should drop from 30s to <100ms)
- Message processing success rates
- Dictionary key error frequency
- Cross-service call latencies

### Data Distribution Analysis

**Investigate Asymmetric Distribution**:
```sql
-- Check data distribution by key
SELECT 
    key,
    COUNT(*) as total_records,
    COUNT(DISTINCT value) as unique_values,
    COUNT(DISTINCT strategy_id) as unique_strategies,
    ROUND(COUNT(*)::numeric / SUM(COUNT(*)) OVER() * 100, 2) as percentage_of_total
FROM variable 
GROUP BY key 
ORDER BY total_records DESC;

-- Find "hot" values causing performance issues
SELECT 
    value as handling_unit_id,
    COUNT(*) as record_count,
    ROUND(COUNT(*)::numeric / SUM(COUNT(*)) OVER() * 100, 4) as percentage_of_key
FROM variable 
WHERE key = 'handlingUnit.Id'
GROUP BY value 
ORDER BY record_count DESC
LIMIT 20;
```

## Expected Performance Impact

### After Emergency Fixes

**Database Performance**:
- **30+ second queries** → **<100ms queries**
- **Sequential scans eliminated** → **Index seeks**
- **272M row scans** → **Direct index lookups**

**Application Stability**:
- **Zero dictionary key errors**
- **Successful message processing**
- **No timeout-induced retry cycles**

### Success Metrics

**Database**:
- Zero `NpgsqlExecutionStrategy.ExecuteAsync` timeouts
- Zero `GetRunningLocationAssignmentAsync` failures
- Query execution time under 1 second

**Application**:
- Zero `strategyId` dictionary key errors
- Message processing success rate >99%
- Cross-service call success rate >95%

## Implementation Priority

### Priority 1 (Emergency - Deploy Today)
1. Create critical database indexes
2. Fix unsafe header access in LocationAssignmentStrategyHelper
3. Add message validation

### Priority 2 (High - This Week)
1. Implement data archival strategy
2. Add comprehensive error handling
3. Optimize query patterns

### Priority 3 (Medium - Next Sprint)
1. Implement caching strategy
2. Add circuit breaker patterns
3. Cross-service reference cleanup

## Conclusion

The Location Assignment app is experiencing a classic **cascade failure pattern** where database performance issues create secondary application failures. The root cause is well-identified and solvable through targeted database indexing and application resilience improvements.

The **24 million strategy records** and **272+ million variable records** indicate the system has grown beyond its original design capacity and requires both immediate performance fixes and long-term architectural improvements for sustainable operation.

With the proposed emergency fixes, the system should return to normal operation within hours, while the medium and long-term improvements will ensure sustainable performance as data volume continues to grow.
