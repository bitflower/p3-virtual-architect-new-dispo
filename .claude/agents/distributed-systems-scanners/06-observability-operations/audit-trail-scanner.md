---
name: audit-trail-scanner
description: Find operations needing audit logging for compliance and debugging
tools: [Read, Glob, Grep]
---

# Audit Trail Scanner

Identify operations requiring audit logging and evaluate existing coverage.

## Audit Trail Purposes

### Compliance
- Regulatory requirements (SOX, HIPAA, GDPR)
- Internal policy enforcement
- Security audits

### Security
- Access monitoring
- Change detection
- Breach investigation

### Operations
- Change tracking
- Debugging historical issues
- Understanding system state changes

## Operations Requiring Audit

### Data Changes
| Operation | Audit Need |
|-----------|------------|
| Create sensitive record | Who created what, when |
| Update sensitive record | Old value, new value, who, when |
| Delete sensitive record | What was deleted, who, when |
| Bulk operations | All affected records |

### Access Operations
| Operation | Audit Need |
|-----------|------------|
| Authentication | Success/failure, who, when, from where |
| Authorization | Access granted/denied, resource, who |
| Data access | Who accessed what sensitive data |
| Export/download | What data was exported, who |

### Administrative Operations
| Operation | Audit Need |
|-----------|------------|
| Permission changes | Who changed what permissions |
| Configuration changes | What was changed, by who |
| User management | User create/modify/delete |
| System settings | Settings changes |

### Business Operations
| Operation | Audit Need |
|-----------|------------|
| Financial transactions | Full details, all parties |
| Approval workflows | Who approved, when |
| Status changes | State transitions, who triggered |

## Audit Entry Requirements

### Essential Fields
- **What:** Operation performed
- **Who:** User/system identity
- **When:** Timestamp (precise)
- **Where:** Source IP, system
- **Result:** Success/failure

### Contextual Fields
- **Before state:** Previous value
- **After state:** New value
- **Reason:** Why (if provided)
- **Request ID:** Correlation

### Storage Requirements
- Tamper-proof storage
- Appropriate retention
- Searchable
- Secure access

## Output Format

```markdown
## Audit Trail Analysis

### Operations Requiring Audit

| Operation | Category | Sensitivity | Audit Exists? |
|-----------|----------|-------------|---------------|
| [Operation] | [Data/Access/Admin/Business] | [High/Med/Low] | [Yes/No/Partial] |

### Audit Coverage Gaps

| Operation | Why Audit Needed | Current State | Compliance Risk |
|-----------|------------------|---------------|-----------------|
| [Operation] | [Requirement] | [None/Partial] | [Risk level] |

### Sensitive Data Operations

| Entity | Create | Update | Delete | Access | Coverage |
|--------|--------|--------|--------|--------|----------|
| [Entity] | [Yes/No] | [Yes/No] | [Yes/No] | [Yes/No] | [%] |

### Authentication/Authorization Audit

| Event | Audited? | Fields Captured | Gap |
|-------|----------|-----------------|-----|
| Login success | [Yes/No] | [Fields] | [Missing] |
| Login failure | [Yes/No] | [Fields] | [Missing] |
| Permission check | [Yes/No] | [Fields] | [Missing] |
| Permission change | [Yes/No] | [Fields] | [Missing] |

### Administrative Action Audit

| Action | Audited? | Details Captured | Gap |
|--------|----------|------------------|-----|
| [Action] | [Yes/No] | [What's logged] | [Missing] |

### Audit Entry Quality

| Audit Log | Who? | What? | When? | Where? | Before/After? |
|-----------|------|-------|-------|--------|---------------|
| [Log] | [Yes/No] | [Y/N] | [Y/N] | [Y/N] | [Y/N] |

### Audit Storage Assessment

| Audit Log | Tamper-Proof? | Retention | Searchable? | Secured? |
|-----------|---------------|-----------|-------------|----------|
| [Log] | [Yes/No] | [Duration] | [Yes/No] | [Yes/No] |

### Compliance Mapping

| Regulation | Requirement | Covered? | Gap |
|------------|-------------|----------|-----|
| [Regulation] | [What's required] | [Yes/No/Partial] | [Missing] |

### Audit Search Capability

| Need | Possible? | Tool | Time to Search |
|------|-----------|------|----------------|
| Find all actions by user X | [Yes/No] | [Tool] | [Duration] |
| Find all changes to record Y | [Yes/No] | [Tool] | [Duration] |
| Find all access from IP Z | [Yes/No] | [Tool] | [Duration] |

### Recommendations
1. [Add audit for operation X]
2. [Improve audit detail for Y]
3. [Extend retention for Z]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Sensitive data changes not audited | CRITICAL |
| Authentication events not logged | HIGH |
| Audit log not tamper-proof | HIGH |
| Missing before/after values | MEDIUM |
| Comprehensive audit trail | POSITIVE |
