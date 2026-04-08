---
name: drift-detection-evaluator
description: Assess drift detection capabilities between replicated/synced systems
tools: [Read, Glob, Grep]
---

# Drift Detection Evaluator

Evaluate capabilities to detect data drift between distributed systems.

## What is Drift?

Drift is divergence between systems that should be in sync:
- Source of truth has data replica doesn't
- Replica has data source doesn't
- Same record has different values
- Records in different states

## Drift Causes

### Transient Failures
- Network issues during sync
- Timeout mid-operation
- Partial failure not compensated

### Timing Issues
- Race conditions
- Out-of-order updates
- Clock skew affecting ordering

### Logic Errors
- Sync code bugs
- Missing edge cases
- Incorrect conflict resolution

### Operational Issues
- Missed backfill
- Failed migration
- Manual changes not propagated

## Drift Detection Methods

### Record-Level Comparison
```
For each record in A:
  Get corresponding record in B
  Compare fields
  Log differences
```
+ Precise
- Expensive at scale

### Aggregate Comparison
```
Count records in A
Count records in B
Compare counts
```
+ Fast
- Doesn't identify specific drift

### Checksum Comparison
```
Hash all records in A
Hash all records in B
Compare hashes
```
+ Efficient for large datasets
- Only detects presence of drift

### Version Vector Comparison
```
Compare version/timestamp of each record
Flag records with unexpected versions
```
+ Identifies stale records
- Requires version tracking

### Change Stream Verification
```
Track changes applied to both systems
Verify all changes reached both
```
+ Catches sync failures
- Complex infrastructure

## Detection Timing

### Real-Time
Detect drift as it happens
- Requires synchronous verification
- Highest resource cost
- Fastest detection

### Near Real-Time
Detect within minutes
- Background verification
- Moderate cost
- Good for most cases

### Periodic
Detect on schedule (hourly, daily)
- Batch comparison
- Lowest cost
- Delayed detection

## Output Format

```markdown
## Drift Detection Analysis

### Systems with Drift Risk

| Source | Replica/Sync Target | Sync Mechanism | Drift Detection? |
|--------|---------------------|----------------|------------------|
| [System] | [System] | [How synced] | [Yes/No/Partial] |

### Drift Detection Capabilities

| System Pair | Method | Coverage | Timing |
|-------------|--------|----------|--------|
| [A ↔ B] | [Method] | [Full/Partial] | [Real-time/Near/Periodic] |

### Detection Gaps

| System Pair | Gap | Drift Type Missed | Recommendation |
|-------------|-----|-------------------|----------------|
| [A ↔ B] | [What's missing] | [Undetected drift] | [How to add] |

### Drift Metrics

| System Pair | Metric | Current Value | Trend | Alert? |
|-------------|--------|---------------|-------|--------|
| [A ↔ B] | [Drift metric] | [Value] | [Trend] | [Yes/No] |

### Detection Timing Assessment

| System Pair | Current | Required | Gap |
|-------------|---------|----------|-----|
| [A ↔ B] | [Timing] | [Needed] | [Issue] |

### False Positive/Negative Analysis

| Detection | False Positives | False Negatives | Tuning Needed |
|-----------|-----------------|-----------------|---------------|
| [Detection] | [Rate/Examples] | [Risk] | [Yes/No] |

### Drift Alerting

| System Pair | Alert Exists? | Threshold | Appropriate? |
|-------------|--------------|-----------|--------------|
| [A ↔ B] | [Yes/No] | [Value] | [Yes/No] |

### Investigation Capability

| Drift Detected | Can Identify Records? | Can Show Diff? | Can Show Cause? |
|----------------|----------------------|----------------|-----------------|
| [When detected] | [Yes/No] | [Yes/No] | [Yes/No] |

### Self-Healing Capability

| System Pair | Auto-Heal? | From Which Source? | Safe? |
|-------------|------------|-------------------|-------|
| [A ↔ B] | [Yes/No] | [Source of truth] | [Yes/No/Risky] |

### Recommendations
1. [Add detection for X ↔ Y]
2. [Increase detection frequency for Z]
3. [Add drill-down capability for W]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| No drift detection for synced systems | CRITICAL |
| Detection exists but no alerting | HIGH |
| Detection too infrequent for data volatility | MEDIUM |
| Comprehensive detection with alerting | POSITIVE |
