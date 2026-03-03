# Wiki vs Code-Derived Documentation: Contradiction Analysis

**Analysis Date:** 2026-03-03

**Wiki Reference:** Commit `9a4720dfdc2a5a1827ff9a681c4fcdd616f5e1c7` (2026-02-27)

**Code-Derived Docs:** `08_Documentation/Infrastructure.md` and subdirectories

---

## Summary

✅ **No major contradictions found**

The wiki and code-derived documentation are largely complementary rather than contradictory. Most differences fall into three categories:
1. **Legacy/Historical Information** - Wiki contains outdated GKE/Kubernetes info
2. **Operational Details Not in Code** - Wiki has runtime details (IPs, secrets conventions) not derivable from code
3. **Missing/Incomplete Details** - Both have gaps that the other fills

---

## Detailed Findings

### 🟡 POTENTIAL CONTRADICTIONS (Require Verification)

#### 1. TMS Bridge URL Path Suffix

| Source | URL |
|--------|-----|
| **Wiki** `Devops/Environments.md` | `https://tms-bridge.gcp.nagel-group.com/bridge/` |
| **Code-Derived Docs** | `https://tms-bridge.gcp.nagel-group.com` |
| **Exploration** | `https://tms-bridge.gcp.nagel-group.com` |

**Analysis:**
- Wiki shows `/bridge/` path suffix
- Code exploration and deployment configs don't show this suffix
- **Possible explanations:**
  - Wiki may be showing the API base path, not the service root URL
  - Wiki may be outdated (old routing configuration)
  - Load balancer routing may have changed

**Action Required:** ✋ Verify actual TMS Bridge base URL in running environment

---

### ✅ COMPLEMENTARY INFORMATION (Not Contradictions)

These are details present in one source but not the other, without conflict:

#### 1. TMS Database Instance IPs

**Wiki Only:** `Devops/Environments.md`

| Database | IP Address | Environment |
|----------|------------|-------------|
| ABN1034 | 10.100.47.236 | TEST |
| UAT2820 | 10.100.47.238 | TEST |
| TMS1034 | 10.100.64.14 | PROD |
| TMS1052 | 10.100.64.14 | PROD |

**Code-Derived Docs:** No specific IPs mentioned (AlloyDB accessed via VPC)

**Conclusion:** Wiki provides operational details not visible in code. ✅ Added to Operational Guide.

#### 2. SMTP Server Details

**Wiki:** `Architecure/Architecture-&-Infrastructure-Requirements-2025.md`
- Host: `smtp.nagel-group.local`
- Port: `25`
- Username: `kvn-tmsmail`

**Code-Derived Docs:** Generic SMTP configuration with pipeline variables

**Conclusion:** Wiki provides specific on-prem server details. ✅ Added to Operational Guide.

#### 3. Secret Manager Naming Conventions

**Wiki:** `Devops/Google-SM-Secrets-Creation.md` - Complete detailed conventions

**Code-Derived Docs:** No mention of secret naming patterns

**Conclusion:** Wiki provides operational procedures not in code. ✅ Added to Operational Guide.

#### 4. Known Workarounds & Technical Debt

**Wiki:** `Devops/Temporary-Workarounds.md` - Documents active issues

**Code-Derived Docs:** No mention of workarounds

**Conclusion:** Wiki provides operational context. ✅ Added to Operational Guide.

#### 5. TOP Service Deployment Instances

**Wiki:** `Architecure/Architecture-&-Infrastructure-Requirements-2025.md`
- Specific server names (CAL4105, CAL4106, DZVSWEB031-033)
- Load balancer service group names

**Code-Derived Docs:** Generic TOP Service URLs

**Conclusion:** Wiki provides detailed on-prem deployment info. ✅ Added to Operational Guide.

#### 6. Keycloak Deployment Details

**Both Sources:** Mention Keycloak usage but not deployment specifics

**Missing in Both:**
- Where Keycloak is deployed (GKE? Cloud Run? On-prem?)
- Version information
- Database configuration specifics
- Scaling configuration

**Conclusion:** Gap in both documentation sets. ⚠️ Needs investigation.

---

### 🗄️ LEGACY/HISTORICAL INFORMATION (Not Contradictions)

These represent the evolution from old to current infrastructure:

#### 1. GKE/Kubernetes Infrastructure

**Wiki:** Extensive GKE documentation
- `Devops/Introduction.md` - GKE deployments
- `Devops/Google-Cloud-Platform.md` - autopilot-nagel-dev cluster
- `Devops/Environments.md` - dev/staging namespaces

**Code-Derived Docs:** CloudRun only

**Conclusion:** Wiki documents historical P3-managed GKE environment. Migration to CloudRun completed. 📚 Historical record, not contradiction.

#### 2. Old Pipeline Names

**Wiki:** `Devops/Azure-Pipelines.md`
- Disposition-Frontend-Develop
- Disposition-Backend-Develop
- Frontend-Azure-to-GKE-Devel
- Backend-Azure-to-GKE-Devel

**Code-Derived Docs:** Current pipeline names
- cal-new-dispo-frontend-t-t-cloudrun
- cal-new-dispo-backend-t-t-cloudrun
- etc.

**Conclusion:** Pipeline naming changed during CloudRun migration. 📚 Historical record.

#### 3. Old Service Accounts

**Wiki:**
- `azure-pipelines-publisher@nagel-new-disposition.iam.gserviceaccount.com` (P3 account)
- `633636345344-compute@developer.gserviceaccount.com`

**Code-Derived Docs:**
- `wl-cicd@prj-cal-w-cicd-wl5-a591-53ad.iam.gserviceaccount.com`

**Conclusion:** Service accounts changed during migration to WL4/WL5. 📚 Historical record.

#### 4. Environment URLs - Staging/Dev

**Wiki:** `Devops/Environments.md`
- STAGING: `https://nagel-staging.ddns.net:8081` (P3 GCP)
- DEV: `https://dev.new-dispo.nagel.p3ds.net/` (P3 GCP)

**Code-Derived Docs:** Only TEST and PROD on Nagel infrastructure

**Conclusion:** Old P3 dev/staging environments replaced by Nagel TEST environment. 📚 Historical record.

---

## Terminology Differences (Not Contradictions)

### "TMS Pulse" vs "Dispo Filter"

**Wiki:** `Architecure/Architecture-&-Infrastructure-Requirements-2025.md`
- Uses term "TMS Pulse Bus" for Pub/Sub
- Uses term "Shipment Filter" for Cloud Function

**Code-Derived Docs:**
- "Dispo Filter Function"
- Direct Pub/Sub topic references

**Conclusion:** Different naming conventions for same components. Likely:
- Wiki uses business/architectural names
- Code uses implementation names
- Not a contradiction, just naming style difference

---

## Information Gaps (Missing in Both)

1. **Keycloak Deployment:**
   - Where is it deployed?
   - Version and configuration details
   - High availability setup

2. **Load Balancer Configuration:**
   - SSL certificate management details
   - WAF/Security policies
   - Routing rules beyond basic path mapping

3. **Monitoring & Alerting:**
   - What alerts are configured?
   - Alert thresholds
   - On-call procedures

4. **Disaster Recovery:**
   - RTO/RPO targets
   - Backup schedules
   - Failover procedures

5. **Cost Analysis:**
   - Current infrastructure costs
   - Cost allocation by component
   - Optimization opportunities

---

## Recommendations

### 1. Resolve TMS Bridge URL Discrepancy

**Priority:** Medium

**Action:**
```bash
# Test actual TMS Bridge endpoint
curl -I https://test.tms-bridge.gcp.nagel-group.com/health
curl -I https://test.tms-bridge.gcp.nagel-group.com/bridge/health
```

Update documentation with correct base URL and API path structure.

### 2. Archive Legacy Wiki Content

**Priority:** Low

**Action:** Add banner to top of wiki pages documenting GKE/P3 infrastructure:

```
⚠️ HISTORICAL DOCUMENTATION
This page documents the legacy P3 GKE infrastructure (dev/staging).
Migration to Nagel CloudRun infrastructure completed 2024-Q4.
See [Infrastructure.md] for current production documentation.
```

### 3. Document Keycloak Deployment

**Priority:** Medium

**Action:** Investigation needed to document:
- Deployment method (container, VM, managed service)
- Location (which GCP project/workload)
- Version and upgrade process
- Database backend configuration

### 4. Create Missing Documentation

**Priority:** Medium

**Action:** Add sections for:
- Load balancer detailed configuration
- Monitoring and alerting setup
- Disaster recovery procedures
- Cost analysis and optimization

---

## Validation Commands

To verify findings and check for additional contradictions:

### Check TMS Bridge Base Path

```bash
# From backend code
cd Code/Disposition-Backend
grep -r "tms-bridge.gcp.nagel-group.com" --include="*.cs" --include="*.json"

# From TMS Bridge code
cd Code/Disposition-Abstraction-Layer
grep -r "bridge/" --include="*.cs" --include="*.json" | grep -i route
```

### Check Database Connection Patterns

```bash
# Look for IP addresses in code
cd Code/Disposition-Abstraction-Layer
grep -r "10.100" --include="*.cs" --include="*.json" --include="*.yml"

# Check connection string patterns
grep -r "Host=" --include="*.cs" --include="*.json"
```

### Check SMTP Configuration

```bash
cd Code/Disposition-Backend
grep -r "smtp" --include="*.cs" --include="*.json" -i
```

---

## Conclusion

**No critical contradictions found.** The wiki and code-derived documentation are complementary:

✅ **Code-Derived Docs:** Authoritative for current infrastructure state (CloudRun, WL4/WL5, pipelines)

✅ **Wiki Docs:** Valuable for operational details (IPs, secret conventions, workarounds) and historical context

⚠️ **One item needs verification:** TMS Bridge URL path suffix

📚 **Historical wiki content should be archived/marked** to avoid confusion

The operational guide successfully combines both sources into a comprehensive reference.
