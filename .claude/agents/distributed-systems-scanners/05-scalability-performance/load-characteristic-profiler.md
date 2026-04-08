---
name: load-characteristic-profiler
description: Profile read/write ratios, access patterns, and load distribution characteristics
tools: [Read, Glob, Grep]
---

# Load Characteristic Profiler

Profile and analyze load characteristics to inform scaling and optimization decisions.

## Load Characteristics

### Read/Write Ratio
The balance between read and write operations:

| Pattern | Ratio | Optimization |
|---------|-------|--------------|
| Read-Heavy | 90:10+ reads | Read replicas, caching |
| Balanced | ~50:50 | Balanced optimization |
| Write-Heavy | 30:70+ writes | Write optimization, sharding |

### Access Patterns

**Uniform Access:**
All data accessed equally
- Standard indexing
- Even cache distribution

**Hot Spot:**
Small subset accessed frequently
- Targeted caching
- Partition hot data
- Watch for contention

**Time-Based:**
Access varies by time
- Predictive scaling
- Time-based caching
- Scheduled resources

**Locality:**
Related data accessed together
- Co-locate related data
- Denormalization
- Batch fetching

### Traffic Patterns

**Steady State:**
Consistent load over time
- Fixed resource allocation
- Predictable capacity

**Spiky:**
Sudden traffic bursts
- Auto-scaling
- Queue buffering
- Capacity headroom

**Seasonal:**
Predictable patterns (daily, weekly, etc.)
- Scheduled scaling
- Pre-provisioning

**Event-Driven:**
External events cause load
- Event-aware scaling
- Prepare for known events

## Profiling Dimensions

### Volume
- Requests per second
- Data size per request
- Total data volume

### Velocity
- Request rate trends
- Growth trajectory
- Peak vs average

### Variety
- Request types
- Data types
- Client types

## Detection from Architecture

### Read-Heavy Indicators
```
- Many query endpoints
- Reporting features
- Dashboard/analytics
- Search functionality
- User browsing patterns
```

### Write-Heavy Indicators
```
- Data ingestion
- Logging/auditing
- Real-time updates
- IoT/sensor data
- Event streaming
```

### Hot Spot Indicators
```
- Featured/popular items
- Recent data emphasis
- User-specific dashboards
- Trending features
```

## Output Format

```markdown
## Load Characteristic Profile

### Overall Load Profile

| Characteristic | Assessment | Evidence |
|----------------|------------|----------|
| Read/Write Ratio | [Estimate] | [How determined] |
| Access Pattern | [Uniform/HotSpot/etc] | [Evidence] |
| Traffic Pattern | [Steady/Spiky/etc] | [Evidence] |

### Read Operations Analysis

| Operation | Estimated Volume | Hot Data? | Cacheable? |
|-----------|------------------|-----------|------------|
| [Operation] | [Est. frequency] | [Yes/No] | [Yes/No/Partially] |

### Write Operations Analysis

| Operation | Estimated Volume | Concurrency | Contention Risk |
|-----------|------------------|-------------|-----------------|
| [Operation] | [Est. frequency] | [Low/Med/High] | [Level] |

### Data Access Patterns

| Data Entity | Access Pattern | Hot Subset | Size |
|-------------|---------------|------------|------|
| [Entity] | [Pattern type] | [What's hot] | [Est. size] |

### Traffic Pattern Assessment

| Timeframe | Pattern | Peak | Trough | Ratio |
|-----------|---------|------|--------|-------|
| Daily | [Description] | [When] | [When] | [Peak:Avg] |
| Weekly | [Description] | [When] | [When] | [Peak:Avg] |
| Seasonal | [Description] | [When] | [When] | [Peak:Avg] |

### Hot Spot Analysis

| Hot Spot | Data/Feature | Access Concentration | Risk |
|----------|--------------|---------------------|------|
| [Hot spot] | [What] | [% of traffic] | [Contention/Cache pressure] |

### Growth Trajectory

| Metric | Current | 6 Month | 12 Month | Implication |
|--------|---------|---------|----------|-------------|
| [Metric] | [Value] | [Projected] | [Projected] | [Capacity need] |

### Caching Strategy Implications

| Data | Cacheability | TTL Suggestion | Cache Type |
|------|--------------|----------------|------------|
| [Data] | [High/Med/Low] | [Duration] | [Local/Distributed] |

### Scaling Strategy Implications

| Characteristic | Implication | Strategy |
|----------------|-------------|----------|
| [Characteristic] | [What it means] | [How to scale] |

### Database Optimization Implications

| Finding | Database Implication | Recommendation |
|---------|---------------------|----------------|
| [Finding] | [Impact] | [Optimization] |

### Recommendations
1. [Add caching for read-heavy X]
2. [Add read replica for Y]
3. [Partition hot data Z]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Hot spot without caching/partitioning | HIGH |
| Write-heavy without optimization | HIGH |
| Spiky traffic without auto-scaling | MEDIUM |
| Uncharacterized load | MEDIUM |
| Well-understood load with matching optimization | POSITIVE |
