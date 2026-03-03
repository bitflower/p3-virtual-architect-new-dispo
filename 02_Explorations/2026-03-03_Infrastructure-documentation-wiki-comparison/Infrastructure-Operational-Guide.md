# Infrastructure Operational Guide

**Last Updated:** 2026-03-03

**Wiki Source Reference:**
- **Extraction Date:** 2026-03-03
- **Wiki Commit:** `9a4720dfdc2a5a1827ff9a681c4fcdd616f5e1c7`
- **Wiki Commit Date:** 2026-02-27 15:36:09 +0100
- **Wiki Repository:** `WIKI/Nagel-CAL-Disposition.wiki`

**Purpose:** This document contains operational procedures, conventions, and supplementary information for the New Dispo infrastructure. It complements the main [Infrastructure Documentation](Infrastructure.md) with details extracted from historical wiki documentation and operational experience.

## Checking for Wiki Updates

To check if the wiki has been updated since this document was created:

### Quick Check for New Commits

```bash
cd "WIKI/Nagel-CAL-Disposition.wiki"
git log --oneline 9a4720dfdc2a5a1827ff9a681c4fcdd616f5e1c7..HEAD -- \
  Devops/ \
  Architecure/ \
  Architecure.md \
  Devops.md
```

### View Detailed Changes

To see what actually changed in specific files:

```bash
cd "WIKI/Nagel-CAL-Disposition.wiki"
git diff 9a4720dfdc2a5a1827ff9a681c4fcdd616f5e1c7..HEAD -- Devops/Google-SM-Secrets-Creation.md
```

### Check All Relevant Files

```bash
cd "WIKI/Nagel-CAL-Disposition.wiki"
git diff 9a4720dfdc2a5a1827ff9a681c4fcdd616f5e1c7..HEAD --stat -- \
  Devops/Environments.md \
  Devops/Google-SM-Secrets-Creation.md \
  Devops/Temporary-Workarounds.md \
  Devops/Database-migrations.md \
  Architecure.md \
  Architecure/Decision-Log.md \
  Architecure/Keycloak.md \
  Architecure/Architecture-&-Infrastructure-Requirements-2025.md
```

This will show a summary of changes to each source file referenced in this document.

## Table of Contents

- [Tech Stack Details](#tech-stack-details)
- [Secret Manager Conventions](#secret-manager-conventions)
- [Connected TMS Database Instances](#connected-tms-database-instances)
- [Known Workarounds & Technical Debt](#known-workarounds--technical-debt)
- [Database Operations](#database-operations)
- [External System Details](#external-system-details)
- [Key Architectural Decisions](#key-architectural-decisions)

---

## Tech Stack Details

### Frontend

**Core Technologies:**
- Language: TypeScript 5
- Framework: Angular 17
- Component Library: Angular Material 17
- CSS Framework: Tailwind CSS 3

**Design Approach:**
- "Hands-On" mentality over pixel-perfect implementation
- Design system wraps Angular Material components with "Cal" prefix
- Velocity prioritized over 100% design accuracy

**Requirements:**
- Internationalization (i18n) - Used across Europe
- Responsive design - Simple approach with columns breaking to rows at tablet breakpoint
- Dark Mode support

**Testing:**
- Unit tests: Jest 9
- End-to-End tests: Frontend automation (Happy paths)

### Backend

**Core Technologies:**
- Language: C# .NET Core 8.0
- Framework: ASP.NET Core API (Linux/container compatible)
- Database Connector: DevArt dotConnect for PostgreSQL

**Data Exchange:**
- Protocol: REST / JSON
- Authentication: JWT / Token-based (Keycloak as issuer)

**Testing:**
- Unit tests: MSTest
- Strategy: Responsibility boundary testing with happy path focus
- Approach: Mock libraries or in-memory database for DB access

### Automated Tests

**Technologies:**
- Language: C# .NET 8.0

**UI Tests:**
- .NET Core
- NUnit
- Selenium WebDriver

**API Tests:**
- .NET Core
- RestSharp

### TMS Bridge

**Technology:** .NET application (not Java as previously documented elsewhere)

**Purpose:** Abstraction layer for TMS database access

> **Source:** `WIKI/Nagel-CAL-Disposition.wiki/Architecure.md` (lines 1-83)

---

## Secret Manager Conventions

### Overview

All sensitive configuration is stored in GCP Secret Manager. Proper naming conventions and labels are critical for the backend to load secrets correctly.

### Connection String Secrets

**Naming Patterns:**

| Database Type | Pattern | Example |
|---------------|---------|---------|
| PostgreSQL TMS | `D-{COMPANY}-{BRANCH}` | `D-1034-52` |
| Oracle TMS | `O-{COMPANY}-{BRANCH}` | `O-1034-52` |
| DigiLiS | `DIGILIS-{COMPANY}-{BRANCH}` | `DIGILIS-1034-52` |

**Secret Configuration:**

1. **Name:** Follow pattern above
2. **Value:** Connection string
   - PostgreSQL example: `Host=10.100.47.236;Port=5432;Database=tms;Username=tmsbr1034;Password=<password>;`
   - DigiLiS example: `User Id=digilisent1;Password=<password>;Data Source=ent1.digilis:1521/ent1.digilis;`
3. **Label:** Add label with key `connectionstring` and blank value
4. **Annotation:** Add environment annotation (see below)

**Application Configuration:**

Connection string secret names must be added to `application.json` files in the backend under connection string sections.

### Provider-Specific Secrets

For third-party service integrations (e.g., TIMOCOM, Trans.eu):

**Format:**
- Name: Any descriptive value
- Value: JSON object with provider options
- Labels: Key = database identifier, Value = options type

**Example Value:**
```json
{
    "ServerUrl": "https://sandbox.timocom.com/freight-exchange/3",
    "Username": "Nagel-Group",
    "Password": "654W92bEReKTytd-8KJ7Ig",
    "Id": "901637",
    "Deeplink": "https://my.timocom.com/app/tccargo/freights/editor/view"
}
```

**Application Configuration:**

Add corresponding JSON structure in `application.json` for provider options.

### Environment Annotations

**Requirement:** Since Secret Manager is shared across multiple environments, each secret must be tagged with its target environment.

**Implementation:**
- Add annotation under `annotations` property
- Key: `Environment`
- Value: Environment name (e.g., `test`, `production`, `dev`)

**Example:**

```
Annotations:
  Environment: test
```

### Important Notes

- Backend must be **redeployed** after secret changes (secrets loaded on startup)
- Secret names are **case-sensitive**
- Labels and annotations are **mandatory** for proper secret loading

> **Source:** `WIKI/Nagel-CAL-Disposition.wiki/Devops/Google-SM-Secrets-Creation.md` (complete file)

---

## Connected TMS Database Instances

### Overview

New Dispo connects to multiple TMS database instances via TMS Bridge. Each environment connects to specific instances.

### Production Instances

| Database | Company-Branch | TMS Bridge User | IP Address | Notes |
|----------|----------------|-----------------|------------|-------|
| TMS1034 | 10-34 | tmsbr1034 | 10.100.64.14 | Production instance |
| TMS1052 | 10-52 | tmsbr1052 | 10.100.64.14 | Production instance |

### Test Instances

| Database | Company-Branch | TMS Bridge User | IP Address | Notes |
|----------|----------------|-----------------|------------|-------|
| ABN1034 | ABN-1034 | tmsbr1034 | 10.100.47.236 | Test instance |
| UAT2820 | UAT-2820 | tms2820 | 10.100.47.238 | UAT instance |

### Connection Details

- **Protocol:** PostgreSQL (AlloyDB)
- **Port:** 5432
- **Network:** Private IP via VPC
- **Authentication:** Database-specific service accounts
- **Connection String Pattern:** See [Secret Manager Conventions](#connection-string-secrets)

### Adding New Database Connections

1. Create connection string secret in Secret Manager following naming pattern
2. Add label `connectionstring` with blank value
3. Add environment annotation
4. Update backend `application.json` with new connection string reference
5. Redeploy backend service
6. Verify connectivity via TMS Bridge health endpoint

> **Source:** `WIKI/Nagel-CAL-Disposition.wiki/Devops/Environments.md` (lines 15-23)

---

## Known Workarounds & Technical Debt

This section documents temporary solutions and technical debt that should be addressed in future iterations.

### 1. Pub/Sub Internal Network Access

**Issue:** Pub/Sub cannot use internal networks for push subscriptions to Cloud Run services.

**Current Workaround:**
- Events pushed directly to backend public URL: `https://cal-new-disposition-backend-t-t-633636345344.europe-west3.run.app/pubsub/consume`
- Backend exposed on public IP for Pub/Sub delivery

**Ideal Solution:**
- CAL/Nagel to provide working solution for internal Pub/Sub delivery
- Consider Pull subscription model with backend polling
- Investigate Private Service Connect for Pub/Sub

**Impact:** Security - backend endpoint exposed publicly (though requiring authentication)

### 2. Email Sending Authentication

**Issue:** Current implementation uses STARTTLS with basic authentication (username/password).

**Current Implementation:**
- SMTP with STARTTLS
- Username: kvn-tmsmail
- Password authentication

**Required Solution:**
- Migrate to Outlook API with modern authentication
- Implement OAuth2 flow for email sending

**Impact:** Security - basic auth less secure than OAuth2

**Priority:** Medium (functional but not best practice)

### 3. DigiLiS SMB Access

**Issue:** Cloud Functions need privileged access to DigiLiS file shares.

**Current Workaround:**
- Cloud Functions deployed with `smb-op-user` service account
- Temporary solution pending proper access model

**Required Solution:**
- Nagel/CAL to suggest proper SMB access pattern
- Potentially: VPN/Interconnect with dedicated service account
- Alternative: API-based integration instead of file shares

**Impact:** Security - overly privileged service account

**Affected Components:** Cloud4Log functions

### 4. VPC Connector for Cloud Functions

**Issue:** Cloud Functions Gen2 cannot be directly configured with shared VPC network during initial deployment (GCP API limitation).

**Current Workaround:**
1. Deploy function with bare minimum configuration (no VPC)
2. Update function post-deployment to attach VPC connector
3. Additional update for network tags

**Implementation:**
- All Cloud Function pipelines use two-stage deployment
- Initial deploy + VPC update

**Impact:** Deployment complexity, pipeline duration

**Affected Components:**
- Dispo Filter Functions (UAT2820, ABN1034)
- Cloud4Log functions (bordero-upload, rollkart-upload, download)
- CrossDock Event Publisher

**Notes:**
- This is a GCP platform limitation, not configuration error
- Workaround is stable and reliable
- Monitor GCP updates for native VPC configuration support

> **Source:** `WIKI/Nagel-CAL-Disposition.wiki/Devops/Temporary-Workarounds.md` (complete file)

---

## Database Operations

### Database Migration Strategy

**Approach:** Integrated backend migrations

**Implementation:**
- Database migrations integrated into backend application
- Migrations run automatically **on each backend startup**
- No separate migration job or init container required

**Migration Framework:**
- Entity Framework Core Migrations (assumed based on .NET stack)
- Version controlled in backend repository
- Applied in order based on timestamp

**Deployment Impact:**
- Backend startup time includes migration execution
- First instance to start runs migrations
- Subsequent instances detect migrations already applied

**Best Practices:**
- Test migrations in test environment before production
- Ensure migrations are reversible where possible
- Monitor backend startup logs for migration success/failure
- Coordinate migrations with zero-downtime deployments

### AlloyDB Management

**Repository:** `Code/tms-alloydb-schema`

**Deployment Method:** GitHub Actions (not Azure DevOps)

**Key Points:**
- TMS database managed separately from application
- Schema changes follow separate approval process
- Read-only views provided for New Dispo consumption
- Write access only via stored procedures (no direct SQL)

> **Source:** `WIKI/Nagel-CAL-Disposition.wiki/Devops/Database-migrations.md` (lines 1-4)

---

## External System Details

### SMTP Server

**Purpose:** Nagel corporate email server for sending customer notifications

**Connection Details:**
- Host: `smtp.nagel-group.local`
- Port: `25`
- Protocol: SMTP
- Encryption: STARTTLS (see Technical Debt section)

**Authentication:**
- Username: `kvn-tmsmail`
- Password: Stored in Secret Manager or pipeline variables

**Network Access:**
- On-premises server
- Access from GCP WL4 via VPC connector
- Network tags required: `p25-user` (verify actual tag)

**Usage:**
- Backend sends emails for:
  - User notifications
  - Disposition status updates
  - System alerts
  - Reports

> **Source:** `WIKI/Nagel-CAL-Disposition.wiki/Architecure/Architecture-&-Infrastructure-Requirements-2025.md` (lines 80-115)

### CALSuite Service Bus

**Purpose:** Azure Enterprise Service Bus for CAL system integration

**Technology:** Azure Service Bus

**Queues:**
- `newdispo_to_lobster` - EDI JSON messages from New Dispo

**Publishers:**
- CrossDock Event Publisher
- New Dispo Backend (direct publishing for specific use cases)

**Message Format:** EDI JSON bodies

**Authentication:**
- Connection string stored in Secret Manager: `asb-topic-connection-string`
- Already shared with P3 team

> **Source:** `WIKI/Nagel-CAL-Disposition.wiki/Architecure/Architecture-&-Infrastructure-Requirements-2025.md` (lines 42-76)

### TOP Service

**Purpose:** .NET 4.6 WebAPI for routing and optimization calculations

**Deployment Type:** On-premises

**Test Instances:**
- **Feature Test:** `featuretest-calconsult-top.cal-consult.int` (CAL4105)
- **Development:** `development-calconsult-top.cal-consult.int` (CAL4106)
- **System Test:** `systemtest-calconsult-top.cal-consult.int` (CAL4103 & CAL4104)
  - Load balancer service group: `svc_grp_sys_calconsult_top`

**Production Instance:**
- **URL:** `calconsult-top.elogsvc.nagel-group.local`
- **Servers:** DZVSWEB031, DZVSWEB032, DZVSWEB033
- **Load balancer service group:** `svc_grp_prod_calconsult_top`

**Integration:**
- Called by New Dispo Backend for route optimization
- Communicates with xServer for actual routing calculations
- Repository: `CALtms/CALConsult.TOP`

**Strategic Direction:**
- Long-term: New Dispo to call xServer directly
- TOP Service as temporary middleware
- No APIM planned (direct microservice approach preferred)

> **Source:** `WIKI/Nagel-CAL-Disposition.wiki/Architecure/Architecture-&-Infrastructure-Requirements-2025.md` (lines 262-318)

### xServer

**Purpose:** Third-party HTTP web service for routing and logistics calculations

**Deployment:** Self-hosted by Nagel

**Test Endpoint:**
- Base URL: `https://featuretest-top.cal-consult.int/`
- XServer URL: `http://10.32.3.102:30000`

**Production Endpoint:**
- TBD (verify with Pascal Leicht)

**Integration:**
- Called by TOP Service (currently)
- Future: Direct integration with New Dispo Backend

**Authentication:**
- Credentials shared with P3 (Matthias & Stanislav)

> **Source:** `WIKI/Nagel-CAL-Disposition.wiki/Architecure/Architecture-&-Infrastructure-Requirements-2025.md` (lines 228-260)

### EntraID (Microsoft Entra ID)

**Purpose:** Corporate identity provider for user synchronization

**Status:** TBD

**Planned Integration:**
- Sync users from EntraID to Keycloak
- Enable SSO for corporate users
- Maintain Keycloak as primary IAM for New Dispo

**Current State:**
- Not yet implemented
- Keycloak operates independently
- Future user base merge planned

> **Source:** `WIKI/Nagel-CAL-Disposition.wiki/Architecure/Architecture-&-Infrastructure-Requirements-2025.md` (lines 320-348)

---

## Key Architectural Decisions

This section documents critical architectural decisions made during the project. Full details available in wiki Decision Log.

### 2024-04-15: Cloud Platform & Architecture

**Decisions:**
- **Cloud Provider:** Google Cloud Platform (GCP)
- **Hosting:** CAL-hosted infrastructure
- **Architecture:** Cloud-agnostic/container-based (Kubernetes) where appropriate, GCP-native when advantageous
- **Environments:**
  - PROD: GCP managed by CAL, Infrastructure as Code, Appsbroker support
  - DEV/TEST/STAGING: P3 GCP cloud (now migrated to CAL)
- **Authentication:** Keycloak as IAM provider, separate instance initially, future merge possible
- **Features:**
  - I18n required (European deployment)
  - Responsive design required (tablet breakpoint)
  - Dark mode required

> **Source:** `WIKI/Nagel-CAL-Disposition.wiki/Architecure/Decision-Log.md` (lines 3-12)

### 2024-05-03 & 2024-05-13: Database Platform

**Decision:** No Oracle support

**Rationale:**
- Confirmed by Christian Lang (05-03)
- Re-enforced by MD Matthias Rieger (05-13)
- PostgreSQL/AlloyDB chosen instead
- PostgreSQL Version 15 selected

**Impact:**
- AlloyDB for TMS database
- PostgreSQL (CloudSQL) for New Dispo application database
- No Oracle Bridge implementation needed

> **Source:** `WIKI/Nagel-CAL-Disposition.wiki/Architecure/Decision-Log.md` (lines 14-23)

### 2024-05-21: TMS Data Access & Business Logic

**Decisions:**

1. **AlloyDB Usage:**
   - Use AlloyDB provided at 10.100.4.9
   - Updated every Friday with migration results

2. **Data Views:**
   - Implement data from view `V_TA` (40% contained fake data at time)
   - Reduced view `V_TA_LIST` provided if needed

3. **Business Logic Location:**
   - **No new business logic in branch database**
   - All new logic in P3-built backend services
   - Backend handles: branch selection, filtering, user settings, freight exchange integration
   - TMS Bridge: Read-only abstraction of database data and existing business logic
   - Transport order data remains in database, read in real-time, no caching

4. **Architecture Impact:**
   - Clear separation between TMS data (read-only) and application logic
   - Backend as the intelligence layer
   - Database as single source of truth

> **Source:** `WIKI/Nagel-CAL-Disposition.wiki/Architecure/Decision-Log.md` (lines 25-44)

### 2024-08-02: TMS Bridge Scope

**Decision:** Split TMS Bridge into 3 "sizes" to shorten roadmap and descope non-MVP features

**Rationale:** Client request for shorter time-to-market

**Details:** See TMS Bridge wiki documentation

> **Source:** `WIKI/Nagel-CAL-Disposition.wiki/Architecure/Decision-Log.md` (lines 54-59)

### 2024-08-26: Authentication Strategy V1

**Decision:** Keycloak to remain the IAM for New Dispo within scope of V1

**Rationale:**
- Alignment with CALSuite approach (potential future user base merge)
- Avoid authentication migration in V1 scope
- Focus on core functionality delivery

**Note:** CALSuite team planning to step away from Keycloak long-term, but timeline unclear

> **Source:** `WIKI/Nagel-CAL-Disposition.wiki/Architecure/Decision-Log.md` (lines 61-65) and `WIKI/Nagel-CAL-Disposition.wiki/Architecure/Keycloak.md`

### 2024-09-02: Write Access to AlloyDB

**Decision:** First write access requirements for cross-dock feature

**Rules Established:**
1. **No direct SQL:** No UPDATE, INSERT, or DELETE statements allowed
2. **Procedure-based:** All writes via stored procedures/packages
3. **Business Logic Preservation:** Existing database triggers and logic must be maintained
4. **Abstraction:** CAL (Pascal) creates new database objects for each use case
5. **Interface Stability:** Database changes shouldn't require .NET-side changes

**Rationale:**
- Preserve existing TMS business logic
- Enable refactoring on database side without breaking consumers
- Maintain data integrity
- Support for views becoming procedures transparently

> **Source:** `WIKI/Nagel-CAL-Disposition.wiki/Architecure/Decision-Log.md` (lines 67-73)

### 2024-09-05: Portal Strategy

**Decision:** Each application has its own URL and feature section, no unified portal

**Rationale:**
- **No capacity** for portal overhead
- Avoids dependencies:
  - Additional UX/UI work (bottleneck)
  - Additional permission concept
  - Additional frontend work and technology (micro frontends)

**Approach:**
- Re-use building blocks (auth, design system)
- Shared authentication (same token, no re-login)
- UI-level integration acceptable
- Components built as re-usable as possible for future portal

**Rule of Thumb:** If it only affects UI, it's ok to integrate

> **Source:** `WIKI/Nagel-CAL-Disposition.wiki/Architecure/Decision-Log.md` (lines 75-91)

### 2024-12-10: Cross-Dock Architecture

**Decision:** Mock-based architecture for Cross-Dock approved by Pascal Leicht

**Clarifications:**
- Event name plural ("orders") aligns with TMS procedure returning arrays
- Skip high-level wrapper properties (e.g., `ForwardingOrders`) - not needed by CALSuite
- Prototype architecture approved

> **Source:** `WIKI/Nagel-CAL-Disposition.wiki/Architecure/Decision-Log.md` (lines 92-104)

---

## Operational Procedures

### Secret Rotation

**Frequency:** To be defined (recommended: quarterly)

**Process:**
1. Update secret value in GCP Secret Manager
2. Create new version (old version preserved)
3. Redeploy affected services to pick up new secret
4. Verify service functionality
5. Disable old secret version after verification period

**Services Requiring Redeployment:**
- Backend: Connection strings, provider secrets, SMTP credentials
- TMS Bridge: Connection strings, Keycloak config
- Cloud4Log: DigiLiS credentials
- CrossDock Publisher: Keycloak config, Azure Service Bus connection string

### Adding New Environment

**Checklist:**
1. Create GCP project with appropriate workload (WL4 or WL5)
2. Configure VPC and subnets
3. Set up VPC Connector
4. Configure network tags and firewall rules
5. Create CloudSQL instance (if needed for backend)
6. Configure AlloyDB connectivity
7. Create Secret Manager secrets with environment annotation
8. Update Azure DevOps pipeline variables
9. Create pipeline for new environment
10. Deploy services
11. Configure Cloud Scheduler (for Cloud4Log, if applicable)
12. Set up monitoring and alerting
13. Update documentation

### Troubleshooting Common Issues

**Backend won't start:**
- Check Secret Manager secrets loaded correctly (environment annotation)
- Verify connection strings format
- Check CloudSQL connectivity
- Review database migrations for errors

**TMS Bridge connection failures:**
- Verify AlloyDB IP addresses and connectivity
- Check VPC network tags on Cloud Run service
- Verify TMS Bridge user credentials in secrets

**Cloud4Log not processing:**
- Check Cloud Scheduler jobs running
- Verify Workflows executing successfully
- Check DigiLiS credentials and network connectivity
- Review Cloud Function logs for SMB access errors

**Pub/Sub messages not reaching Backend:**
- Verify subscription push endpoint URL
- Check backend `/pubsub/consume` endpoint accessibility
- Review Pub/Sub dead letter queue (if configured)

---

## Maintenance Schedule

**Regular Activities:**

- **Weekly:**
  - Review Cloud Logging for errors and warnings
  - Monitor Cloud Function execution rates and errors

- **Monthly:**
  - Review Secret Manager access logs
  - Check for security updates to dependencies
  - Review Cloud Storage bucket sizes and cleanup old CDC data

- **Quarterly:**
  - Rotate secrets (recommended)
  - Review and update network firewall rules
  - Review IAM permissions for service accounts
  - Update this documentation with operational learnings

---

## Related Documentation

- [Infrastructure.md](Infrastructure.md) - Main infrastructure documentation
- [Infrastructure/deployment-mapping.md](Infrastructure/deployment-mapping.md) - Component deployments
- [Infrastructure/cicd-pipelines.md](Infrastructure/cicd-pipelines.md) - Pipeline details
- [Infrastructure/gcp-resources.md](Infrastructure/gcp-resources.md) - GCP services
- [Infrastructure/network-configuration.md](Infrastructure/network-configuration.md) - Network setup
- [Infrastructure/external-integrations.md](Infrastructure/external-integrations.md) - External systems

---

## Document History

| Date | Author | Changes |
|------|--------|---------|
| 2026-03-03 | System | Initial version extracted from wiki documentation (commit `9a4720df`) with source references |
