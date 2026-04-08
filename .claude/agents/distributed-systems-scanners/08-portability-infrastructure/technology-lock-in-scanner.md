---
name: technology-lock-in-scanner
description: Find vendor/technology lock-in risks and assess escape paths
tools: [Read, Glob, Grep]
---

# Technology Lock-In Scanner

Identify technology and vendor lock-in risks and evaluate mitigation options.

## Lock-In Types

### Vendor Lock-In
Dependency on specific vendor:
- Cloud provider (AWS, GCP, Azure)
- SaaS provider
- Hardware vendor

### Technology Lock-In
Dependency on specific technology:
- Proprietary database features
- Framework-specific patterns
- Language-specific libraries

### Data Lock-In
Difficulty moving data:
- Proprietary formats
- Export limitations
- Large data volumes

### Contract Lock-In
Legal/commercial barriers:
- Long-term contracts
- Termination penalties
- Volume commitments

## Lock-In Assessment Factors

### Switching Cost
What does it cost to change?
- Development effort
- Data migration
- Retraining
- Downtime

### Availability of Alternatives
Are there alternatives?
- Direct competitors
- Open-source equivalents
- Standard protocols

### Strategic Risk
What's the business risk?
- Vendor viability
- Price increases
- Feature direction
- Support quality

## Detection Patterns

### High Lock-In Risk
```
- Proprietary API used directly
- Vendor-specific data formats
- No abstraction layer
- Features only in one vendor
- Large data volumes in proprietary system
```

### Lower Lock-In Risk
```
- Standard protocols (SQL, HTTP, OIDC)
- Abstraction layers
- Open-source alternatives exist
- Data export capabilities
- Multi-vendor deployment tested
```

## Output Format

```markdown
## Technology Lock-In Analysis

### Lock-In Inventory

| Component | Vendor/Technology | Lock-In Type | Severity |
|-----------|-------------------|--------------|----------|
| [Component] | [Vendor/Tech] | [Vendor/Tech/Data] | [High/Med/Low] |

### Vendor Lock-In Details

| Vendor | Components Using | Switching Cost | Alternatives |
|--------|------------------|----------------|--------------|
| [Vendor] | [Components] | [Cost estimate] | [Alternatives] |

### Technology Lock-In Details

| Technology | Usage | Standard Alternative | Migration Effort |
|------------|-------|---------------------|------------------|
| [Tech] | [Where used] | [Alternative] | [Effort] |

### Data Lock-In Assessment

| Data Store | Data Volume | Export Capability | Format | Migration Risk |
|------------|-------------|-------------------|--------|----------------|
| [Store] | [Volume] | [Yes/No/Partial] | [Standard/Proprietary] | [Risk] |

### Proprietary Feature Usage

| Feature | Vendor | Standard Alternative | Refactor Effort |
|---------|--------|---------------------|-----------------|
| [Feature] | [Vendor] | [Alternative] | [Effort] |

### Abstraction Layer Assessment

| Integration | Has Abstraction? | Quality | Switching Effort |
|-------------|------------------|---------|------------------|
| [Integration] | [Yes/No] | [Good/Partial/None] | [With/Without abstraction] |

### Contract Lock-In

| Vendor | Contract Term | Exit Clause | Penalty | Risk |
|--------|---------------|-------------|---------|------|
| [Vendor] | [Duration] | [Clause] | [Cost] | [Level] |

### Strategic Risk Assessment

| Vendor | Viability | Price Risk | Direction Risk | Support Risk |
|--------|-----------|------------|----------------|--------------|
| [Vendor] | [Assessment] | [Risk] | [Risk] | [Risk] |

### Escape Path Analysis

| Lock-In | Escape Path | Effort | Timeline | Cost |
|---------|-------------|--------|----------|------|
| [Lock-in] | [How to escape] | [Effort] | [Duration] | [Est. cost] |

### Multi-Vendor Readiness

| Component | Vendor A | Vendor B | Tested? |
|-----------|----------|----------|---------|
| [Component] | [Support] | [Support] | [Yes/No] |

### Recommendations
1. [Add abstraction for X]
2. [Plan escape path for Y]
3. [Test multi-vendor for Z]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Critical component, single vendor, no alternative | CRITICAL |
| Proprietary data format, large volume | HIGH |
| No abstraction, direct vendor API | HIGH |
| Vendor dependency but alternatives exist | MEDIUM |
| Abstracted with tested alternatives | POSITIVE |
