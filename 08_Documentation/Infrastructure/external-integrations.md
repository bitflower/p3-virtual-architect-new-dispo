# External Integrations

This document describes the external services and systems that the New Dispo infrastructure integrates with.

## Keycloak (Identity Provider)

### Endpoints

**Test Environment:**
- URL: https://test.dispo.gcp.nagel-group.com/keycloak
- Admin Console: https://test.dispo.gcp.nagel-group.com/keycloak/admin
- Realm: `master`

**Production Environment:**
- URL: https://dispo.gcp.nagel-group.com/keycloak
- Admin Console: https://dispo.gcp.nagel-group.com/keycloak/admin
- Realm: `master`

### Configuration

**Clients:**
- `cal-client` - Main application client
- `client-credentials-test` - Service account client for test environment

**Authentication Flow:**
- OAuth2 / OpenID Connect
- Authorization Code flow for user authentication
- Client Credentials flow for service-to-service

### Integration Points

**Frontend:**
- Redirects users to Keycloak for login
- Receives OAuth2 authorization code
- Exchanges code for access token

**Backend:**
- Validates access tokens from Frontend requests
- Extracts user identity and roles from tokens
- Uses tokens for API authorization

**CrossDock Publisher:**
- Uses Keycloak configuration from Secret Manager: `keyCloakConfig`
- Service account authentication (client credentials flow)

### Secret Management

**Backend Client Secret:**
- Injected via Azure DevOps pipeline variable: `KEYCLOAK_CLIENT_SECRET`

**CrossDock Publisher Config:**
- Stored in GCP Secret Manager: `keyCloakConfig`

## Azure Service Bus

**Protocol:** AMQP 1.0 over TLS

### Integration

**Publisher:** CrossDock Event Publisher (Cloud Function)

**Event Source:** TMS AlloyDB Change Data Capture (CDC)

**Event Flow:**
1. AlloyDB Datastream writes CDC events to Cloud Storage bucket
2. CrossDock Publisher Cloud Function triggered by new objects
3. Function processes CDC events
4. Function publishes messages to Azure Service Bus topic

### Configuration

**Connection String:**
- Stored in GCP Secret Manager: `asb-topic-connection-string`
- Environment variable: `OUTBOUND_CONNECTION_STRING`

### Environment-Specific Settings

**Test Environment:**
- Database identifier: `Database3`
- Environment: `28302`
- Source bucket: `tms-alloydb-datastream-bucket-wl5-t-t`

**Production Environment:**
- No production deployment exists

## DigiLiS (Document Management System)

**Technology:** SMB/CIFS file share

### Document Types

**Uploads to DigiLiS:**
1. **Bordero (Cartage Notes):** Shipping documentation for cartage
2. **Rollkart (Roll Container Cards):** Container tracking documents

**Downloads from DigiLiS:**
1. **Proof of Delivery (PoD):** Signed delivery confirmation documents

### Connection Configuration

**Credentials:**
- Username: Injected via pipeline variable `DIGILIS_USERNAME`
- Password: Injected via pipeline variable `DIGILIS_PASSWORD`
- Domain: Injected via pipeline variable `DIGILIS_DOMAIN`

**Network Access:**
- Via VPC Connector
- SMB/CIFS protocol (ports 139, 445)

### Integration Points

**Cloud4Log Functions:**

**bordero-upload:**
- Reads bordero documents from Cloud Storage staging area
- Uploads to DigiLiS file share
- Returns status to Cloud Workflow

**rollkart-upload:**
- Reads rollkart documents from Cloud Storage staging area
- Uploads to DigiLiS file share
- Returns status to Cloud Workflow

**download:**
- Downloads PoD documents from DigiLiS file share
- Stores in Cloud Storage bucket
- Returns status to Cloud Workflow

### Workflow Orchestration

**Upload Workflow (`c4l-workflow-upload`):**
- Scheduled: Every 5 minutes (test), every minute (production)
- Invokes: bordero-upload, then rollkart-upload

**Download Workflow (`c4l-workflow-download`):**
- Scheduled: Every 15 minutes (both environments)
- Invokes: download function

### Depot Configuration

**Configuration Files:**
- Stored in Cloud Storage:
  - Test: `c4l-static-files-files-documents-t-t`
  - Production: `c4l-static-files-files-documents-p-p`
- Format: JSON files with depot-specific settings
- Updated via dedicated pipelines:
  - Test: `azure-pipelines-cloudrun-t-t-c4ldepots-json.yml`
  - Production: `azure-pipelines-cloudrun-p-p-c4ldepots-json.yml`

## TOP Service

**Protocol:** HTTP/HTTPS

### Endpoints

**Test Environment:**
- Base URL: https://featuretest-top.cal-consult.int/
- XServer URL: http://10.32.3.102:30000

### Network Access

**Internal IP:** 10.32.3.102

### Integration Points

**Backend Service:**
- Calls TOP Service APIs for route optimization
- Uses XServer endpoint for calculations
- Configuration injected via pipeline variables

### Configuration

**Environment Variables:**
- `TOP_BASE_URL`: Base URL for TOP Service API
- `XSERVER_URL`: XServer-specific endpoint

## TMS Database (AlloyDB)

**Technology:** Google Cloud AlloyDB for PostgreSQL

**Management:** GitHub Actions workflows (separate from main application)

### Integration Points

**TMS Bridge:**
- Provides REST API abstraction over TMS database
- Direct database connection via VPC

**Dispo Filter Functions:**
- Consumes Change Data Capture (CDC) events
- Processes AlloyDB Datastream output from Cloud Storage
- Publishes filtered events to Pub/Sub

**CrossDock Publisher:**
- Consumes Change Data Capture (CDC) events
- Processes AlloyDB Datastream output from Cloud Storage
- Publishes events to Azure Service Bus

### Change Data Capture (CDC)

**Mechanism:** AlloyDB Datastream

**Output:** JSON-formatted CDC events written to Cloud Storage buckets

**CDC Flow:**
1. AlloyDB captures database changes (INSERT, UPDATE, DELETE)
2. Datastream service processes changes
3. CDC events written to Cloud Storage bucket
4. Cloud Functions triggered by new objects
5. Functions process and route events

**CDC Buckets:**
- Test: `tms-alloydb-datastream-bucket-wl5-t-t`
- UAT2820: Pipeline variable `WL5_CDC_BUCKET_UAT2820`
- ABN1034: Pipeline variable `WL5_CDC_BUCKET_ABN1034`

### Environment Instances

Multiple TMS database instances exist for different environments:
- **UAT2820:** User acceptance testing environment 2820
- **ABN1034:** ABN customer environment 1034

## External API Summary

| External System | Protocol | Purpose | Integrated By |
|-----------------|----------|---------|---------------|
| Keycloak | HTTPS (OAuth2/OIDC) | Authentication & Authorization | Frontend, Backend, CrossDock Publisher |
| Azure Service Bus | AMQP over TLS | Event publishing | CrossDock Publisher |
| DigiLiS | SMB/CIFS | Document upload/download | Cloud4Log functions |
| TOP Service | HTTP | Route optimization | Backend |
| TMS Database | PostgreSQL | TMS data access | TMS Bridge, Dispo Filter, CrossDock Publisher |
