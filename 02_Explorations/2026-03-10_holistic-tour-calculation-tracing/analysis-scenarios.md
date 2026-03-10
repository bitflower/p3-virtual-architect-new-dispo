# Trace Analysis Scenarios - Debugging Workflows

**Date:** 2026-03-10

## Overview

This document provides practical examples of how to use the holistic tracing system to debug common issues in the tour calculation flow, particularly focusing on time zone problems and data transformation mismatches.

## Scenario 1: Time Zone & Date Calculation Issues

### Problem Description

Tour calculations show incorrect arrival/departure times. The issue could be:
- Time zone conversions applied multiple times
- Missing time zone information
- UTC vs. local time confusion
- Database time zone settings mismatch

### Debugging Workflow

#### Step 1: Identify the Problematic Request

```sql
-- Find traces from the last hour with tour calculation
SELECT
    trace_id,
    first_timestamp,
    capture_count
FROM trace.get_recent_traces(100)
WHERE first_timestamp > NOW() - INTERVAL '1 hour'
ORDER BY first_timestamp DESC;
```

#### Step 2: Extract All Time-Related Data from Trace

```sql
-- Get all timestamp data across the entire flow
WITH trace_data AS (
    SELECT
        trace_id,
        component_name,
        capture_point,
        timestamp as capture_timestamp,
        data
    FROM trace.capture
    WHERE trace_id = 'trace-abc-123'
    ORDER BY timestamp
)
SELECT
    component_name,
    capture_point,
    capture_timestamp,
    -- Extract PlanningDate from PoolDTO
    data->'PoolDto'->>'PlanningDate' as planning_date,
    data->'PoolDto'->'PlanningInterval'->>'Start' as planning_interval_start,
    data->'PoolDto'->'PlanningInterval'->>'End' as planning_interval_end,
    -- Extract tour element times
    data->'EnrichedPoolDto'->'Plans'->0->'Tours'->0->'TourElements'->0->>'StartTime' as first_tourpoint_start,
    data->'EnrichedPoolDto'->'Plans'->0->'Tours'->0->'TourElements'->0->>'EndTime' as first_tourpoint_end,
    -- Extract location opening intervals
    (data->'PoolDto'->'Locations'->0->'OpeningIntervals'->0->>'Start') as first_location_opening_start
FROM trace_data
WHERE data IS NOT NULL;
```

#### Step 3: Analyze Time Zone Representation

```sql
-- Check if time zones are consistent across transformations
SELECT
    component_name,
    capture_point,
    -- Check for timezone indicators: +01:00, +00:00, Z, etc.
    CASE
        WHEN data::text LIKE '%+01:00%' THEN 'CET/CEST detected'
        WHEN data::text LIKE '%+00:00%' OR data::text LIKE '%Z%' THEN 'UTC detected'
        WHEN data::text LIKE '%1900-01-01%' THEN 'Default time detected (potential issue)'
        ELSE 'No timezone or unknown format'
    END as timezone_analysis,
    -- Extract sample timestamps for manual inspection
    substring(data::text from '"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[^"]*') as sample_timestamp
FROM trace.capture
WHERE trace_id = 'trace-abc-123'
  AND data IS NOT NULL
ORDER BY timestamp;
```

#### Step 4: Compare Before/After xServer Call

```sql
-- Extract times before and after xServer processing
WITH before_xserver AS (
    SELECT
        data->'PoolDto'->'Plans'->0->'Tours'->0->'TourElements' as tour_elements
    FROM trace.capture
    WHERE trace_id = 'trace-abc-123'
      AND capture_point = 'BeforeTOPService'
),
after_xserver AS (
    SELECT
        data->'EnrichedPoolDto'->'Plans'->0->'Tours'->0->'TourElements' as tour_elements
    FROM trace.capture
    WHERE trace_id = 'trace-abc-123'
      AND capture_point = 'AfterTOPService'
)
SELECT
    'Before xServer' as stage,
    jsonb_array_elements(before_xserver.tour_elements) as tour_element
FROM before_xserver
UNION ALL
SELECT
    'After xServer' as stage,
    jsonb_array_elements(after_xserver.tour_elements) as tour_element
FROM after_xserver;
```

### Common Time Zone Issues & Solutions

#### Issue 1: Times in PoolDTO use "1900-01-01" date

**Symptom:**
```json
{
  "StartTime": "1900-01-01T05:30:00+01:00",
  "EndTime": "1900-01-01T00:00:00+01:00"
}
```

**Analysis Query:**
```sql
SELECT
    component_name,
    capture_point,
    data::text ~ '1900-01-01' as uses_default_date
FROM trace.capture
WHERE trace_id = 'trace-abc-123'
ORDER BY timestamp;
```

**Root Cause:** Database uses time-only storage and xServer requires full datetime

**Solution:** Verify that pTop_LoadingList.get() combines date correctly

#### Issue 2: Time Zone Lost During Transformation

**Symptom:** UTC times in database become timezone-naive in application

**Analysis Query:**
```sql
-- Compare timezone info at each stage
SELECT
    component_name,
    capture_point,
    CASE
        WHEN data::text ~ 'T\d{2}:\d{2}:\d{2}\+\d{2}:\d{2}' THEN 'Has timezone offset'
        WHEN data::text ~ 'T\d{2}:\d{2}:\d{2}Z' THEN 'UTC explicit'
        WHEN data::text ~ 'T\d{2}:\d{2}:\d{2}"' THEN 'NO TIMEZONE (PROBLEM)'
        ELSE 'Unknown format'
    END as timezone_status
FROM trace.capture
WHERE trace_id = 'trace-abc-123'
  AND data::text ~ '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}'
ORDER BY timestamp;
```

#### Issue 3: Multiple Timezone Conversions

**Symptom:** Times shifted incorrectly (e.g., +2 hours instead of +1)

**Analysis Query:**
```sql
-- Extract all times and calculate differences
WITH time_extracts AS (
    SELECT
        component_name,
        capture_point,
        timestamp,
        -- Extract a specific known time field
        (data->'PoolDto'->>'PlanningDate')::timestamptz as planning_date
    FROM trace.capture
    WHERE trace_id = 'trace-abc-123'
      AND data->'PoolDto'->>'PlanningDate' IS NOT NULL
    ORDER BY timestamp
)
SELECT
    component_name,
    capture_point,
    planning_date,
    LAG(planning_date) OVER (ORDER BY timestamp) as previous_value,
    planning_date - LAG(planning_date) OVER (ORDER BY timestamp) as time_shift
FROM time_extracts;
```

## Scenario 2: Data Transformation Mismatches

### Problem Description

Data is lost, modified, or incorrectly transformed between components:
- Location coordinates change
- Order counts differ
- Vehicle attributes missing
- Distance/duration calculations incorrect

### Debugging Workflow

#### Step 1: Compare Input vs. Output at Each Boundary

```sql
-- Count locations/orders/vehicles at each stage
SELECT
    component_name,
    capture_point,
    timestamp,
    jsonb_array_length(data->'PoolDto'->'Locations') as location_count,
    jsonb_array_length(data->'PoolDto'->'Orders') as order_count,
    jsonb_array_length(data->'PoolDto'->'Vehicles') as vehicle_count
FROM trace.capture
WHERE trace_id = 'trace-abc-123'
  AND data->'PoolDto' IS NOT NULL
ORDER BY timestamp;
```

#### Step 2: Deep Dive on Specific Field Changes

```sql
-- Track a specific location through the flow
WITH location_tracking AS (
    SELECT
        component_name,
        capture_point,
        timestamp,
        jsonb_array_elements(data->'PoolDto'->'Locations') as location
    FROM trace.capture
    WHERE trace_id = 'trace-abc-123'
      AND jsonb_array_length(data->'PoolDto'->'Locations') > 0
)
SELECT
    component_name,
    capture_point,
    location->>'Id' as location_id,
    location->>'Name1' as name,
    location->>'Longitude' as longitude,
    location->>'Latitude' as latitude,
    location->'RequiredVehicleEquipment' as equipment
FROM location_tracking
WHERE location->>'Id' = '10340430073544'  -- Specific location to track
ORDER BY timestamp;
```

#### Step 3: Detect Data Loss

```sql
-- Find fields that exist in one stage but not in another
WITH before_data AS (
    SELECT data->'PoolDto' as pool_dto
    FROM trace.capture
    WHERE trace_id = 'trace-abc-123'
      AND capture_point = 'AfterGetPoolDto'
),
after_data AS (
    SELECT data->'EnrichedPoolDto' as pool_dto
    FROM trace.capture
    WHERE trace_id = 'trace-abc-123'
      AND capture_point = 'AfterTOPService'
)
SELECT
    'Before' as stage,
    jsonb_object_keys(before_data.pool_dto) as field_name
FROM before_data
UNION
SELECT
    'After' as stage,
    jsonb_object_keys(after_data.pool_dto) as field_name
FROM after_data
ORDER BY stage, field_name;
```

### Common Transformation Issues

#### Issue 1: Coordinate Precision Loss

**Analysis Query:**
```sql
-- Compare coordinate precision
SELECT
    component_name,
    capture_point,
    location->>'Longitude' as longitude,
    location->>'Latitude' as latitude,
    -- Check decimal places
    LENGTH(location->>'Longitude') - POSITION('.' IN location->>'Longitude') as lng_decimals,
    LENGTH(location->>'Latitude') - POSITION('.' IN location->>'Latitude') as lat_decimals
FROM (
    SELECT
        component_name,
        capture_point,
        jsonb_array_elements(data->'PoolDto'->'Locations') as location
    FROM trace.capture
    WHERE trace_id = 'trace-abc-123'
) t
WHERE location->>'Id' = '10340430073544'
ORDER BY component_name;
```

#### Issue 2: Null vs Empty Array

**Analysis Query:**
```sql
-- Detect null vs empty arrays
SELECT
    component_name,
    capture_point,
    CASE
        WHEN data->'PoolDto'->'Locations' IS NULL THEN 'NULL'
        WHEN data->'PoolDto'->'Locations' = '[]'::jsonb THEN 'EMPTY ARRAY'
        ELSE 'HAS DATA'
    END as locations_status,
    jsonb_array_length(data->'PoolDto'->'Locations') as count
FROM trace.capture
WHERE trace_id = 'trace-abc-123'
  AND (data->'PoolDto' IS NOT NULL OR data->'EnrichedPoolDto' IS NOT NULL)
ORDER BY timestamp;
```

## Scenario 3: Performance Analysis

### Problem Description

Tour calculation takes too long. Identify bottlenecks in the flow.

### Debugging Workflow

#### Step 1: Calculate Latency Between Components

```sql
-- Calculate time spent in each component
WITH ordered_captures AS (
    SELECT
        component_name,
        capture_point,
        timestamp,
        LEAD(timestamp) OVER (ORDER BY timestamp) as next_timestamp
    FROM trace.capture
    WHERE trace_id = 'trace-abc-123'
)
SELECT
    component_name,
    capture_point,
    timestamp,
    next_timestamp,
    EXTRACT(EPOCH FROM (next_timestamp - timestamp)) as seconds_to_next,
    CASE
        WHEN EXTRACT(EPOCH FROM (next_timestamp - timestamp)) > 5 THEN 'SLOW'
        WHEN EXTRACT(EPOCH FROM (next_timestamp - timestamp)) > 1 THEN 'NORMAL'
        ELSE 'FAST'
    END as performance_category
FROM ordered_captures
ORDER BY timestamp;
```

#### Step 2: Identify Slowest Component

```sql
-- Aggregate latency by component
WITH component_latency AS (
    SELECT
        component_name,
        timestamp,
        LEAD(timestamp) OVER (ORDER BY timestamp) as next_timestamp
    FROM trace.capture
    WHERE trace_id = 'trace-abc-123'
)
SELECT
    component_name,
    COUNT(*) as capture_count,
    AVG(EXTRACT(EPOCH FROM (next_timestamp - timestamp))) as avg_latency_seconds,
    MAX(EXTRACT(EPOCH FROM (next_timestamp - timestamp))) as max_latency_seconds,
    SUM(EXTRACT(EPOCH FROM (next_timestamp - timestamp))) as total_time_seconds
FROM component_latency
WHERE next_timestamp IS NOT NULL
GROUP BY component_name
ORDER BY total_time_seconds DESC;
```

## Scenario 4: Error Diagnosis

### Problem Description

Tour calculation fails with an error. Determine exactly where and why.

### Debugging Workflow

#### Step 1: Find the Last Successful Capture Point

```sql
-- Get all capture points for failed trace
SELECT
    component_name,
    capture_point,
    direction,
    timestamp,
    CASE
        WHEN data::text LIKE '%error%' OR data::text LIKE '%exception%' THEN 'ERROR DETECTED'
        WHEN data::text LIKE '%isSuccessful%false%' THEN 'FAILURE FLAG'
        ELSE 'OK'
    END as status,
    SUBSTRING(data::text, 1, 200) as data_preview
FROM trace.capture
WHERE trace_id = 'trace-failed-xyz'
ORDER BY timestamp;
```

#### Step 2: Examine Error Details

```sql
-- Extract error information
SELECT
    component_name,
    capture_point,
    data->'Response'->>'ResponseText' as error_message,
    data->'Response'->>'IsSuccessful' as is_successful,
    data as full_context
FROM trace.capture
WHERE trace_id = 'trace-failed-xyz'
  AND (
      data::text LIKE '%error%' OR
      data::text LIKE '%exception%' OR
      data->'Response'->>'IsSuccessful' = 'false'
  );
```

#### Step 3: Compare with Successful Trace

```sql
-- Compare failed vs successful trace at same capture point
SELECT
    'FAILED' as trace_type,
    capture_point,
    data
FROM trace.capture
WHERE trace_id = 'trace-failed-xyz'
  AND capture_point = 'AfterGetPoolDto'
UNION ALL
SELECT
    'SUCCESS' as trace_type,
    capture_point,
    data
FROM trace.capture
WHERE trace_id = 'trace-success-abc'
  AND capture_point = 'AfterGetPoolDto';
```

## Pre-built Analysis Queries

### Query 1: Trace Summary

```sql
CREATE OR REPLACE FUNCTION trace.summarize_trace(p_trace_id VARCHAR)
RETURNS TABLE (
    total_captures INT,
    components_involved TEXT[],
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    total_duration_ms NUMERIC,
    status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*)::INT as total_captures,
        ARRAY_AGG(DISTINCT component_name ORDER BY component_name) as components_involved,
        MIN(timestamp) as start_time,
        MAX(timestamp) as end_time,
        EXTRACT(EPOCH FROM (MAX(timestamp) - MIN(timestamp))) * 1000 as total_duration_ms,
        CASE
            WHEN MAX(data::text LIKE '%error%' OR data::text LIKE '%exception%')::int > 0 THEN 'ERROR'
            WHEN MAX(data::text LIKE '%isSuccessful%false%')::int > 0 THEN 'FAILED'
            ELSE 'SUCCESS'
        END as status
    FROM trace.capture
    WHERE trace_id = p_trace_id;
END;
$$ LANGUAGE plpgsql;

-- Usage:
SELECT * FROM trace.summarize_trace('trace-abc-123');
```

### Query 2: Data Flow Diff

```sql
CREATE OR REPLACE FUNCTION trace.compare_data_at_points(
    p_trace_id VARCHAR,
    p_capture_point_1 VARCHAR,
    p_capture_point_2 VARCHAR
)
RETURNS TABLE (
    field_path TEXT,
    value_at_point_1 TEXT,
    value_at_point_2 TEXT,
    changed BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    WITH point_1 AS (
        SELECT data FROM trace.capture
        WHERE trace_id = p_trace_id AND capture_point = p_capture_point_1
        LIMIT 1
    ),
    point_2 AS (
        SELECT data FROM trace.capture
        WHERE trace_id = p_trace_id AND capture_point = p_capture_point_2
        LIMIT 1
    )
    SELECT
        key as field_path,
        point_1.data->key as value_at_point_1,
        point_2.data->key as value_at_point_2,
        point_1.data->key <> point_2.data->key as changed
    FROM point_1, point_2, jsonb_object_keys(point_1.data) as key;
END;
$$ LANGUAGE plpgsql;

-- Usage:
SELECT * FROM trace.compare_data_at_points(
    'trace-abc-123',
    'AfterGetPoolDto',
    'AfterTOPService'
)
WHERE changed = true;
```

### Query 3: Time Zone Audit

```sql
CREATE OR REPLACE FUNCTION trace.audit_timezones(p_trace_id VARCHAR)
RETURNS TABLE (
    component_name VARCHAR,
    capture_point VARCHAR,
    timestamp_field TEXT,
    has_timezone BOOLEAN,
    timezone_format TEXT,
    sample_value TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH timestamps AS (
        SELECT
            c.component_name,
            c.capture_point,
            regexp_matches(c.data::text, '"(\w+)":"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[^"]*)"', 'g') as matches
        FROM trace.capture c
        WHERE c.trace_id = p_trace_id
    )
    SELECT DISTINCT
        t.component_name::VARCHAR,
        t.capture_point::VARCHAR,
        t.matches[1] as timestamp_field,
        t.matches[2] ~ '[\+\-]\d{2}:\d{2}|Z' as has_timezone,
        CASE
            WHEN t.matches[2] ~ '[\+\-]\d{2}:\d{2}' THEN 'Offset'
            WHEN t.matches[2] ~ 'Z' THEN 'UTC'
            ELSE 'None'
        END as timezone_format,
        t.matches[2] as sample_value
    FROM timestamps t;
END;
$$ LANGUAGE plpgsql;

-- Usage:
SELECT * FROM trace.audit_timezones('trace-abc-123')
WHERE has_timezone = false;
```

## Automated Analysis Scripts

### Script 1: Daily Health Check

```sql
-- Run daily to identify problematic patterns
WITH daily_traces AS (
    SELECT
        trace_id,
        MIN(timestamp) as start_time,
        MAX(timestamp) as end_time,
        COUNT(*) as capture_count,
        COUNT(DISTINCT component_name) as component_count,
        MAX(CASE WHEN data::text LIKE '%error%' THEN 1 ELSE 0 END) as has_error
    FROM trace.capture
    WHERE timestamp > NOW() - INTERVAL '1 day'
    GROUP BY trace_id
)
SELECT
    DATE_TRUNC('hour', start_time) as hour,
    COUNT(*) as total_traces,
    SUM(has_error) as error_count,
    AVG(EXTRACT(EPOCH FROM (end_time - start_time))) as avg_duration_seconds,
    MAX(EXTRACT(EPOCH FROM (end_time - start_time))) as max_duration_seconds,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (end_time - start_time))) as p95_duration_seconds
FROM daily_traces
GROUP BY DATE_TRUNC('hour', start_time)
ORDER BY hour DESC;
```

### Script 2: Find Anomalies

```sql
-- Identify traces with unusual patterns
WITH trace_stats AS (
    SELECT
        trace_id,
        COUNT(*) as capture_count,
        EXTRACT(EPOCH FROM (MAX(timestamp) - MIN(timestamp))) as duration_seconds,
        jsonb_array_length(MAX(data->'PoolDto'->'Locations')) as location_count,
        jsonb_array_length(MAX(data->'PoolDto'->'Orders')) as order_count
    FROM trace.capture
    WHERE timestamp > NOW() - INTERVAL '1 day'
    GROUP BY trace_id
),
stats_summary AS (
    SELECT
        AVG(duration_seconds) as avg_duration,
        STDDEV(duration_seconds) as stddev_duration,
        AVG(location_count) as avg_locations,
        STDDEV(location_count) as stddev_locations
    FROM trace_stats
)
SELECT
    t.trace_id,
    t.duration_seconds,
    t.location_count,
    t.order_count,
    CASE
        WHEN t.duration_seconds > s.avg_duration + (3 * s.stddev_duration) THEN 'SLOW'
        WHEN t.location_count > s.avg_locations + (3 * s.stddev_locations) THEN 'UNUSUAL_SIZE'
        ELSE 'ANOMALY'
    END as anomaly_type
FROM trace_stats t
CROSS JOIN stats_summary s
WHERE
    t.duration_seconds > s.avg_duration + (3 * s.stddev_duration) OR
    t.location_count > s.avg_locations + (3 * s.stddev_locations);
```

## Frontend Debugging Tools

### Browser Console Helper

Add this to browser console for interactive debugging:

```javascript
// Trace helper utilities
window.traceDebug = {
    // Get current trace ID from last request
    getLastTraceId() {
        // Extract from console logs or storage
        const logs = performance.getEntriesByType('resource');
        // Implementation would extract from request headers
    },

    // Query trace data
    async queryTrace(traceId) {
        const response = await fetch(`/api/trace/${traceId}`);
        return response.json();
    },

    // Compare two traces
    async compareTraces(traceId1, traceId2) {
        const [trace1, trace2] = await Promise.all([
            this.queryTrace(traceId1),
            this.queryTrace(traceId2)
        ]);
        console.table([trace1, trace2]);
    },

    // Print trace timeline
    async printTimeline(traceId) {
        const trace = await this.queryTrace(traceId);
        console.log('=== TRACE TIMELINE ===');
        trace.capturePoints.forEach(point => {
            console.log(`${point.timestamp} | ${point.component} | ${point.capturePoint}`);
        });
    }
};
```

## Conclusion

With these analysis scenarios and queries, you can:

1. **Quickly identify** where issues occur in the tour calculation flow
2. **Precisely diagnose** time zone and data transformation problems
3. **Compare** successful vs. failed traces
4. **Monitor** performance and detect anomalies
5. **Eliminate speculation** by examining actual data flow

The key is to always start with a trace ID and work through the capture points systematically, using the provided queries as templates and adapting them to your specific investigation needs.
