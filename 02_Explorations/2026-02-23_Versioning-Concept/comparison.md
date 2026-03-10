# Versioning Approaches - Comparison

## Quick Decision Matrix

| Criteria | Runtime PoC | Pragmatic Static | Winner |
|----------|-------------|------------------|--------|
| Time to implement | 40-60 days | 8-10 days | **Static** |
| Infrastructure cost | €50-100/month + dev time | €0 | **Static** |
| Operational complexity | High (new service) | Low (static files) | **Static** |
| Failure points | +3 (service, DB, functions) | 0 (static files) | **Static** |
| Validates concept | Yes, but after investment | Yes, immediately | **Static** |
| Decoupled pipelines | Yes | Yes | **Tie** |
| Historical tracking | Yes, via database | Yes, via Git/Storage | **Tie** |
| Real-time accuracy | Always current | Current on FE deploy | PoC |
| Ability to evolve | Medium | High (can upgrade later) | **Static** |

## Feature Comparison

| Feature | Runtime PoC | Pragmatic Static |
|---------|-------------|------------------|
| **User sees version in UI** | ✅ Yes | ✅ Yes |
| **Support can debug issues** | ✅ Yes | ✅ Yes |
| **Automatic maintenance** | ✅ Yes | ✅ Yes |
| **Works in all environments** | ✅ Yes | ✅ Yes |
| **No manual intervention** | ✅ Yes | ✅ Yes |
| **Pipeline decoupling** | ✅ Yes | ✅ Yes |
| **Historical version lookup** | ✅ Database query | ✅ Git tags / Cloud Storage |
| **Shows current component versions** | ✅ Always current | ⚠️ Current as of last FE deploy |
| **Complex version queries** | ✅ SQL queries possible | ❌ Manual search |
| **API for external tools** | ✅ Yes | ⚠️ Would need to add |

## Implementation Complexity

### Runtime PoC Components
1. **Version Management Service** (new microservice)
   - API endpoints for registration
   - API endpoints for querying
   - Database schema
   - Deployment configuration
   - Monitoring & alerting
   - Error handling

2. **Cloud Functions** (per component)
   - Version registration logic
   - Deployment hooks
   - Authentication
   - Error handling

3. **Database**
   - Schema design
   - Migration scripts
   - Backup strategy
   - Query optimization

4. **CI/CD Integration**
   - Modify all pipelines
   - Add version registration calls
   - Handle failures gracefully

**Estimated effort:** 40-60 hours

### Pragmatic Static Components
1. **Version generation script** (per component)
   - 30-line bash script
   - Add to existing CI/CD

2. **Version aggregation script** (Frontend)
   - 50-line bash script
   - Fetches component versions
   - Generates JSON

3. **UI component** (Frontend)
   - Display version info
   - 50-100 lines

4. **Git tagging** (optional)
   - Add `git tag` to deployment script
   - 5 lines

**Estimated effort:** 8-16 hours

## Risk Analysis

### Runtime PoC Risks
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Service downtime affects version display | Medium | Low | Cache fallback |
| Database issues block queries | Medium | Medium | Read replicas |
| Increased system complexity | High | Medium | Good documentation |
| Development delay | Medium | High | Proper planning |
| Maintenance burden | High | Medium | Dedicated ownership |

### Pragmatic Static Risks
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Version info slightly outdated | Medium | Low | Update on FE deploy |
| Git history cleanup loses tags | Low | Low | Backup to Cloud Storage |
| Aggregation script fails | Low | Low | Use cached version |

## When to Choose Runtime PoC

Choose the runtime service if you need:

1. **Real-time version resolution**
   - Must know exact versions of all services at any moment
   - Can't wait for Frontend deployment

2. **Complex version queries**
   - "Show all deployments between dates"
   - "Find environments running backend v2.2.5"
   - "Version compatibility matrix"

3. **External system integration**
   - Other services need to query versions programmatically
   - Automated compatibility checks

4. **High component count**
   - >20 independently deployed services
   - Complex dependency graphs

5. **Dedicated operations team**
   - Team to maintain the service
   - SLA requirements

## When to Choose Pragmatic Static

Choose static files if:

1. **Proving the concept** ✓ (your situation)
   - No versioning exists today ✓
   - Need to validate value ✓

2. **Small to medium scale** ✓
   - <10 components ✓
   - Simple architecture ✓

3. **Bug reporting focus** ✓
   - Primary use case: support tickets ✓
   - Manual debugging process ✓

4. **Limited resources** ✓
   - Small team ✓
   - Can't maintain additional services ✓

5. **Simple requirements** ✓
   - Show version in UI ✓
   - Historical lookup occasionally ✓

## Evolution Path

```
Phase 0: No versioning (current state)
    ↓
Phase 1: Static files + manual PoC (1 week)
    ↓ Validate concept
    ↓
Phase 2: Static files + automation (2 weeks)
    ↓ Use for 3-6 months
    ↓ Gather requirements from real usage
    ↓
Phase 3: Assess needs
    ├─→ Static sufficient? → Stay with it
    ├─→ Need API? → Add lightweight API layer
    └─→ Need complex queries? → Upgrade to runtime service
```

**Key insight:** You can always upgrade from static to runtime. You can't downgrade from runtime to static without throwing away work.

## Cost Projection (12 months)

### Runtime PoC
| Cost Type | Amount |
|-----------|--------|
| Initial development | 50 hours × €80 = €4,000 |
| Infrastructure (Cloud Run, DB) | €75/month × 12 = €900 |
| Maintenance (bugs, updates) | 5 hours/month × €80 × 12 = €4,800 |
| **Total Year 1** | **€9,700** |

### Pragmatic Static
| Cost Type | Amount |
|-----------|--------|
| Initial development | 12 hours × €80 = €960 |
| Infrastructure | €0 |
| Maintenance | 1 hour/month × €80 × 12 = €960 |
| **Total Year 1** | **€1,920** |

**Savings: €7,780 in Year 1**

## Recommendation

**Start with pragmatic static approach because:**

1. ✅ Solves the immediate problem (bug reporting)
2. ✅ 5x faster to implement
3. ✅ 80% cost savings
4. ✅ Zero infrastructure overhead
5. ✅ Validates concept before major investment
6. ✅ Easy to evolve if proven valuable
7. ✅ Low risk, high learning

**Consider runtime PoC when:**
- Static approach proves insufficient (after 6+ months)
- Requirements grow beyond simple bug reporting
- Team has capacity to maintain additional services
- Business case justifies the investment

## Action Items

1. **This week:** Review pragmatic proposal with team
2. **Next week:** Implement manual PoC (Phase 1)
3. **Week 3:** Test with real bug reports
4. **Week 4:** Decide: automate or iterate

---

**See detailed proposals:**
- `pragmatic-proposal-GROUNDED.md` - Full implementation guide
- `01_Communication/2026-02-23_answers-from-architect.md` - Direct answers to questions
- `storage-details.md` - Where version.json is stored throughout lifecycle
