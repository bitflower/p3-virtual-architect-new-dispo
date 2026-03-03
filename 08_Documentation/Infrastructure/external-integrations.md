# External Integrations

This document describes the external services and systems that the New Dispo infrastructure integrates with.

## Keycloak (Identity Provider)

### Overview

Keycloak provides centralized authentication and authorization for the New Dispo system.

**Technology:** Keycloak open-source identity and access management

**Deployment:** Separate from main application components (deployment details TBD)

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

**Token Configuration:**
- Access token lifetime: (To be documented)
- Refresh token lifetime: (To be documented)
- ID token included: Yes

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
- Uses Keycloak configuration from Secret Manager
- Service account authentication (client credentials flow)
- Configuration stored in Secret: `keyCloakConfig`

### Secret Management

**Backend Client Secret:**
- Injected via Azure DevOps pipeline variable: `KEYCLOAK_CLIENT_SECRET`
- Stored in Azure DevOps secure files/variables

**CrossDock Publisher Config:**
- Full Keycloak configuration stored in GCP Secret Manager: `keyCloakConfig`
- Contains client ID, client secret, realm, and endpoint URLs

## Azure Service Bus

### Overview

Azure Service Bus is used to publish events from the New Dispo system to external consumers, particularly for cross-dock operations.

**Service:** Microsoft Azure Service Bus

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
- Accessed by CrossDock Publisher function

**Topics/Queues:**
- (To be documented - specific topic/queue names)

**Message Format:**
- (To be documented - message schema and structure)

### Environment-Specific Settings

**Test Environment:**
- Database identifier: `Database3`
- Environment: `28302`
- Source bucket: `tms-alloydb-datastream-bucket-wl5-t-t`

**Production Environment:**
- (To be documented - no production deployment exists yet)

> **Note:** Currently only deployed to test environment. Production deployment approach and configuration to be determined.

## DigiLiS (Document Management System)

### Overview

DigiLiS is an external document management system accessed via SMB/CIFS file share. Cloud4Log integrates with DigiLiS for uploading and downloading logistics documents.

**Technology:** SMB/CIFS file share

**Access Method:** Network file share access via VPC connectivity

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
- Via VPC Connector to internal network
- Likely through VPN or Cloud Interconnect
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
- Stores in Cloud Storage bucket (`$(C4L_BUCKET_POD)` / `$(C4L_BUCKET_POD_P_P)`)
- Returns status to Cloud Workflow

### Workflow Orchestration

**Upload Workflow (`c4l-workflow-upload`):**
- Scheduled: Every 5 minutes (test), every minute (production)
- Invokes: bordero-upload, then rollkart-upload
- Configuration: GCS source for depot configurations

**Download Workflow (`c4l-workflow-download`):**
- Scheduled: Every 15 minutes (both environments)
- Invokes: download function
- Configuration: GCS source for depot configurations

### Depot Configuration

**Configuration Files:**
- Stored in Cloud Storage: `c4l-static-files-files-documents-t-t` (test), `c4l-static-files-files-documents-p-p` (production)
- Format: JSON files with depot-specific settings
- Updated via dedicated pipelines: `azure-pipelines-cloudrun-t-t-c4ldepots-json.yml`, `azure-pipelines-cloudrun-p-p-c4ldepots-json.yml`

**Configuration Content:**
- Depot identifiers
- File path mappings
- Document type configurations
- Schedule overrides (if applicable)

## SMTP (Email Service)

### Overview

The New Dispo Backend integrates with an SMTP server for sending email notifications to users and administrators.

**Protocol:** SMTP (Simple Mail Transfer Protocol)

### Configuration

**Connection Details:**
- Server: Injected via pipeline variable `SMTP_SERVER`
- Port: Injected via pipeline variable `SMTP_PORT`
- Username: Injected via pipeline variable `SMTP_USERNAME`
- Password: Injected via pipeline variable `SMTP_PASSWORD`

**Security:**
- TLS encryption: (To be documented - assumed enabled)
- Authentication: Username/password

### Use Cases

**Notification Types:**
- User registration confirmations
- Password reset emails
- Disposition status updates
- System alerts and warnings
- Daily/weekly reports

**Email Templates:**
- (To be documented - template management approach)

### Integration Point

**Backend Service:**
- Sends emails based on application events
- Uses SMTP client library in .NET
- Handles email queueing and retry logic

## TOP Service

### Overview

TOP Service (Transport Optimization Platform) is an internal system that the New Dispo Backend integrates with for optimization calculations and transport planning.

**Protocol:** HTTP/HTTPS

**Deployment:** On-premises or internal network

### Endpoints

**Test Environment:**
- Base URL: https://featuretest-top.cal-consult.int/
- XServer URL: http://10.32.3.102:30000

**Production Environment:**
- (To be documented)

### Network Access

**Connection Path:**
- Backend Cloud Run service → VPC Connector → VPC → Internal network (10.32.3.0/24 or similar)
- Requires VPN or Cloud Interconnect for on-premises access

**Internal IP:** 10.32.3.102
- Suggests direct internal network connectivity
- No public internet routing

### Integration Points

**Backend Service:**
- Calls TOP Service APIs for route optimization
- Uses XServer endpoint for specific calculations
- Configuration injected via pipeline variables

**Use Cases:**
- Route planning and optimization
- Cost calculations
- Transport capacity analysis
- Scheduling optimization

### Configuration

**Environment Variables:**
- `TOP_BASE_URL`: Base URL for TOP Service API
- `XSERVER_URL`: XServer-specific endpoint

## TMS Database (AlloyDB)

### Overview

While technically a GCP service, the TMS Database (AlloyDB) serves as an external data source for the New Dispo system, managed separately with its own deployment lifecycle.

**Technology:** Google Cloud AlloyDB for PostgreSQL

**Management:** GitHub Actions workflows (separate from main application)

### Integration Points

**TMS Bridge:**
- Primary consumer of TMS data
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
- UAT2820: `$(WL5_CDC_BUCKET_UAT2820)`
- ABN1034: `$(WL5_CDC_BUCKET_ABN1034)`

### Environment Instances

Multiple TMS database instances exist for different environments:
- **UAT2820:** User acceptance testing environment 2820
- **ABN1034:** ABN customer environment 1034
- (Additional instances to be documented)

Each instance has its own CDC configuration and consumer functions.

## External API Summary

| External System | Protocol | Purpose | Integrated By | Network Path |
|-----------------|----------|---------|---------------|--------------|
| Keycloak | HTTPS (OAuth2/OIDC) | Authentication & Authorization | Frontend, Backend, CrossDock Publisher | Public HTTPS |
| Azure Service Bus | AMQP over TLS | Event publishing | CrossDock Publisher | Public HTTPS/AMQP |
| DigiLiS | SMB/CIFS | Document upload/download | Cloud4Log functions | VPN/Interconnect |
| SMTP Server | SMTP | Email notifications | Backend | Public SMTP or internal |
| TOP Service | HTTP | Route optimization | Backend | VPN/Interconnect (internal IP) |
| TMS Database | PostgreSQL | TMS data access | TMS Bridge, Dispo Filter, CrossDock Publisher | VPC (AlloyDB) |

## Security Considerations

### Credential Management

- All credentials stored in GCP Secret Manager or Azure DevOps secure variables
- No hardcoded credentials in source code or configuration files
- Credentials rotated regularly (policy to be documented)

### Network Security

- External HTTPS connections use TLS 1.2 or higher
- Certificate validation enforced for all HTTPS connections
- SMB/CIFS connections encrypted (verify configuration)
- Internal network access via VPN or Cloud Interconnect

### Access Control

- Service accounts follow principle of least privilege
- External API access limited to specific service accounts
- Network firewall rules restrict access to necessary services only
- Regular audit of external access patterns

## Monitoring and Alerting

### Integration Health Checks

**Recommended Monitoring:**
- Keycloak: Token validation success rate, authentication latency
- Azure Service Bus: Message publish success rate, queue depth
- DigiLiS: File upload/download success rate, connection failures
- SMTP: Email send success rate, bounce rate
- TOP Service: API call success rate, response time
- TMS Database: Connection pool health, query performance

**Alerting Thresholds:**
- Error rate > 5% for any integration
- Latency > 5 seconds for critical APIs
- Connection failures > 3 consecutive attempts
- Queue backlog exceeding thresholds

### Logging

All external integration calls should be logged with:
- Request timestamp
- Request/response correlation ID
- Success/failure status
- Error messages (if applicable)
- Response time

Logs available in Cloud Logging for all services.

## Disaster Recovery

### External Service Outages

**Keycloak:**
- Impact: Users cannot authenticate (critical)
- Mitigation: Cached tokens, graceful degradation with limited functionality
- Recovery: Automated health checks, failover to backup instance (if configured)

**Azure Service Bus:**
- Impact: Events not published (degraded functionality)
- Mitigation: Queue messages locally, retry with exponential backoff
- Recovery: Resume publishing when service restored

**DigiLiS:**
- Impact: Documents not uploaded/downloaded (degraded functionality)
- Mitigation: Cloud Storage staging area retains documents, retry on next scheduled run
- Recovery: Workflow resumes automatically when service restored

**SMTP:**
- Impact: Emails not sent (degraded functionality)
- Mitigation: Queue emails in database, retry periodically
- Recovery: Resume email sending when service restored

**TOP Service:**
- Impact: Optimization calculations unavailable (degraded functionality)
- Mitigation: Use cached results or fallback algorithms
- Recovery: Resume calculations when service restored

**TMS Database:**
- Impact: No TMS data access (critical)
- Mitigation: High-availability AlloyDB configuration, automatic failover
- Recovery: AlloyDB automatic failover, no manual intervention needed

## Future Considerations

- Document production configurations for all integrations
- Implement comprehensive health check endpoints for all external dependencies
- Set up automated alerting for integration failures
- Regular testing of disaster recovery procedures
- Implement rate limiting and circuit breakers for external API calls
- Consider caching strategies to reduce external dependencies
