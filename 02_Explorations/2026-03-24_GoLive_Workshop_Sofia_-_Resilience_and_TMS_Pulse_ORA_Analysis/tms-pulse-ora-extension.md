# TMS Pulse ORA Extension

**Workshop Date:** 2026-03-19
**Analysis Date:** 2026-03-24

## Oracle Database Migration & Testing

### Current Situation
- **Development Database:** Postgres (1034 branch)
- **Strategic Target:** Oracle (1060 branch) - Higher business value
- **Decision Status:** Not yet determined which branch goes live
- **Last Oracle Update:** Over 1 year ago (manual process by Joachim)

### Migration Scope
- Joachim and TMS Team responsible for database migration
- Manual script execution for schema updates
- Full replication CDC already working (using Stream)
- New Oracle connector POC using Data Stream in progress

### Testing Strategy

**End-to-End Testing Required:**
- Comprehensive test plan covering all scenarios and combinations
- Must work for BOTH Postgres AND Oracle
- Automated tests where possible, manual tests where necessary
- Regression confidence before go-live

**Testing Approach:**
1. **After Migration Complete** - Only test once Joachim confirms migration done
2. **Bridge-Level Testing** - Test TMS Bridge mappings to database
3. **Functional Validation** - Verify all endpoints and procedures work
4. **Data Validation** - Check expected results match across both engines
5. **Issue Reporting** - Report failures to TMS team for fixes

**Test Plan Components:**
- Given input scenarios
- Expected output for each
- Cover all entities and combinations
- Executable for each database type
- Repeatable for regression testing

### Challenges & Concerns

**Automation Gap:**
- No automated integration tests currently exist
- Unit tests exist but may not catch database-specific issues
- Manual testing required from QA

**Migration Risk:**
- Joachim doing everything manually - high chance of missing something
- No automated deployment/migration scripts
- Different definition scripts between Postgres and Oracle

**Environment Concerns:**
- Multiple environments need coordinated updates
- Can't manually test every branch
- Need one-time setup that works for all future updates

### Dependencies

**Critical Path:**
1. TMS Team completes Oracle migration
2. CDC adapter configured for Oracle
3. Test plan created and approved
4. End-to-end testing executed
5. Issues resolved by TMS team
6. Sign-off on Oracle compatibility

**External Dependencies:**
- **Joachim/TMS Team:** Database migration, script execution
- **Database Administrators:** Schema changes, CDC configuration
- **DevOps:** Environment setup, database access
- **Project Risks:** Timeline heavily dependent on external team deliverables

## Open Questions & Assumptions

### Open Questions
1. When will Oracle migration be complete?
2. Which branch (1034 Postgres vs. 1060 Oracle) goes live?
3. Are there automated migration scripts or all manual?
4. How to harmonize test data between Postgres and Oracle?
5. What is test plan approval process?
6. Who owns test plan creation - Dev or QA?

### Assumptions
1. **Joachim will complete migration** - Trust in TMS team delivery
2. **Same behavior expected** - Postgres and Oracle should be functionally equivalent
3. **TMS Bridge abstracts database** - High-level testing sufficient
4. **Manual testing acceptable initially** - Automation is follow-up
5. **One-time effort per branch** - Don't need to repeat for every update

### Dependencies
1. **BLOCKING:** Oracle migration complete
2. **BLOCKING:** CDC adapter for Oracle configured
3. **REQUIRED:** Test plan defined and approved
4. **REQUIRED:** Test environment with migrated Oracle database
5. **REQUIRED:** TMS team available for issue resolution

## Next Steps

### TMS Pulse ORA
- [ ] Coordinate with Joachim on Oracle migration timeline
- [ ] Confirm which branch (1034 vs. 1060) goes live
- [ ] Create comprehensive test plan template
- [ ] Define test scenarios covering all entities and combinations
- [ ] Identify automation opportunities
- [ ] Plan QA resource allocation
