# Database Identifier Normalization - Issue Resolution

**Date**: 2026-03-02
**Status**: Solution Designed
**Component**: TMS Bridge (Disposition-Abstraction-Layer)
**Issue**: Database identifier `10/1` not resolved correctly

## Overview

This exploration addresses the issue where TMS Bridge fails to resolve company 10, branch 1 when provided as `D-10-01` instead of `D-10-1`. The solution makes TMS Bridge resilient by normalizing database identifiers, ensuring both formats resolve to the same TMS database.

## Files in This Exploration

1. **solution-design.md** - Comprehensive solution design document
   - Problem analysis
   - Implementation strategy
   - Configuration requirements
   - Testing approach
   - Migration path

2. **IMPLEMENTATION.md** - Step-by-step implementation guide
   - Exact code changes required
   - File locations
   - Testing checklist
   - Deployment strategy
   - Rollback plan

3. **BranchDbContextFactory-proposed.cs** - Complete proposed implementation
   - Ready-to-use code with normalization logic
   - Enhanced logging
   - Full documentation

4. **BranchDbContextFactoryTests-additions.cs** - Comprehensive test suite
   - Unit tests for normalization
   - Integration tests for schema resolution
   - Edge case coverage
   - Tests for the specific issue reported

## Problem Statement

### Current Behavior
- `D-10-1` → schema `tms101` ✓
- `D-10-01` → schema `tms1001` ✗ (wrong, causes lookup failure)

### Target Behavior
- `D-10-1` → schema `tms101` ✓
- `D-10-01` → normalized to `D-10-1` → schema `tms101` ✓

## Solution Summary

Add a **NormalizeDatabaseIdentifier** method that:
1. Extracts company and branch numbers from identifier
2. Parses them as integers (removes leading zeros)
3. Reconstructs identifier in normalized format
4. Uses normalized identifier for all lookups and cache keys

### Key Changes

**Single File Modified**: `BranchDbContextFactory.cs`
- Add normalization method (~20 lines)
- Call normalization at entry point of `CreateDbContext`
- Enhanced logging for debugging

**Test File Updated**: `BranchDbContextFactoryTests.cs`
- Add 7 new test methods
- Cover normalization logic
- Verify issue resolution

## Impact Analysis

### Positive Impacts
✅ Resolves the `10/1` issue
✅ Prevents future similar issues
✅ Improves cache efficiency
✅ Backward compatible
✅ Clear error messages
✅ Self-documenting code

### Risks
⚠️ Low - Configuration keys might need updating to normalized format
⚠️ Low - Minimal performance impact (~0.1ms per request)

### Complexity
🟢 **Low** - Single method, isolated change, comprehensive tests

## Next Steps

1. **Review** - Team reviews solution design and implementation guide
2. **Approve** - Stakeholders approve the approach
3. **Implement** - Developer applies code changes
4. **Test** - Run unit and integration tests
5. **Deploy** - Roll out to dev → staging → production
6. **Verify** - Confirm both formats work in production
7. **Document** - Update API docs with normalization info

## Related Issues

- OG reported `10/1` resolution failure
- Pascal Leicht questioned `"01"` vs `1` formatting
- Discussion about TMS numeric vs. string representation
- EBV rollout discovered the inconsistency

## Technical Context

### Database Identifier Pattern
```
[D|O]-{company}-{branch}
where:
  D/O = Database type prefix
  company = 1-2 digit number
  branch = 1-3 digit number
```

### Schema Naming Convention
```
{vendor_prefix}{company}{branch}
Examples:
  PostgreSQL: tms101, tms1034, tms2820
  Oracle: TMS101, TMS1034, TMS2820
```

### Current Regex
```csharp
@"^[DO]-(\d{1,2})-(\d{1,3})$"
```
Accepts both formats but doesn't normalize them.

## References

### Code Locations
- **BranchDbContextFactory.cs**: Line 22-82
- **DbConnectionStringProvider.cs**: Line 15-24
- **GetDriversQueryHandler.cs**: Line 45-48 (shows usage in Backend)

### Configuration Examples
- `Code/Disposition-Backend/CALConsult.Disposition.API/Resources/branchdescriptions.json`
- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/appsettings.json`

### Test Data
- Test cases use `D-10-52`, `D-20-200`, `D-10-34`
- Backend tests use `D-10-1`, `D-1-1`, `D-28-20`

## Approval Required From

- [ ] Lead Developer (code review)
- [ ] TMS Bridge Team (solution validation)
- [ ] New Dispo Backend Team (integration confirmation)
- [ ] DevOps (deployment planning)

## Time Estimate

- **Implementation**: 2 hours
- **Testing**: 2 hours
- **Code Review**: 1 hour
- **Deployment**: 1 hour
- **Total**: ~6 hours

## Success Metrics

After deployment, verify:
1. Both `D-10-1` and `D-10-01` work in API calls
2. No errors in logs related to database resolution
3. Cache hit rate maintains or improves
4. No performance degradation
5. All existing functionality continues to work

---

**Conclusion**: This is a well-scoped, low-risk solution that addresses the root cause of the database identifier resolution issue while improving the overall resilience of the TMS Bridge system.
