# GCP Resources

## Cloud Storage Buckets

### Test Environment

| Bucket Name | Purpose | Used By |
|-------------|---------|---------|
| `tms-alloydb-datastream-bucket-wl5-t-t` | AlloyDB CDC data stream | CrossDock Event Publisher, Dispo Filter |
| `test-cdc-2` | Dev environment CDC bucket | Dispo Filter Function (dev) |
| `c4l-static-files-files-documents-t-t` | Cloud4Log static files and depot configurations | Cloud4Log functions |
| `$(C4L_BUCKET_POD)` | Proof of Delivery document storage | Cloud4Log download function |
| `$(WL5_CDC_BUCKET_UAT2820)` | CDC bucket for UAT2820 environment | Dispo Filter UAT2820 |
| `$(WL5_CDC_BUCKET_ABN1034)` | CDC bucket for ABN1034 environment | Dispo Filter ABN1034 |

### Production Environment

| Bucket Name | Purpose | Used By |
|-------------|---------|---------|
| `c4l-static-files-files-documents-p-p` | Cloud4Log static files and depot configurations | Cloud4Log functions |
| `$(C4L_BUCKET_POD_P_P)` | Proof of Delivery document storage | Cloud4Log download function |

### Bucket Access Patterns

**AlloyDB Datastream Buckets:**
- Written to by AlloyDB Datastream service (CDC)
- Trigger Cloud Functions on new object creation
- JSON format CDC events
- Organized by table and timestamp

**Cloud4Log Buckets:**
- Static configuration files (depot JSON configurations)
- Document staging area for upload/download operations
- Structured by document type (bordero, rollkart, PoD)

## Pub/Sub Topics and Subscriptions

### Topics

| Topic Name | Purpose | Environment | Publishers | Subscribers |
|------------|---------|-------------|------------|-------------|
| `$(WL5_CDC_TOPIC_UAT2820)` | Change Data Capture events for UAT2820 | Test (WL5) | Dispo Filter UAT2820 | New Dispo Backend |
| `$(WL5_CDC_TOPIC_ABN1034)` | Change Data Capture events for ABN1034 | Test (WL5) | Dispo Filter ABN1034 | New Dispo Backend |
| `$(P3_CDC_TOPIC)` | Development environment CDC topic | Dev | Dispo Filter (dev) | Backend (dev) |

### Subscriptions

| Subscription Name | Topic | Subscriber | Environment |
|-------------------|-------|------------|-------------|
| `backend-topic-sub` | CDC topics | New Dispo Backend | Test |

**Subscription Configuration:**
- Push subscription model to Backend Cloud Run service
- Message retention: Standard (7 days)
- Acknowledgment deadline: Configurable per environment
- Dead letter queue: To be documented if configured

## Databases

### AlloyDB (TMS Database)

**Purpose:** Transactional Management System (TMS) primary database

**Deployment:** Managed via GitHub Actions workflows

**Key Features:**
- High-availability configuration
- Change Data Capture (Datastream) enabled
- VPC-based connectivity
- Multiple environment instances (UAT2820, ABN1034, etc.)

**Access:**
- TMS Bridge: Direct VPC connection with network tags
- Dispo Filter Functions: Read CDC events from Cloud Storage
- CrossDock Publisher: Read CDC events from Cloud Storage

**Schema Management:**
- Repository: `Code/tms-alloydb-schema`
- Automated schema updates via GitHub Actions
- Manual schema operations available
- Version control for all schema changes

### CloudSQL PostgreSQL (New Dispo Backend Database)

**Test Environment:**
- **Instance Name:** `cal-new-disposition-psql-t-t`
- **Full Path:** `prj-cal-w-wl4-t-4c48-53ad:europe-west3:cal-new-disposition-psql-t-t`
- **Region:** europe-west3
- **Used By:** New Dispo Backend

**Production Environment:**
- **Instance Name:** `cal-new-disposition-postgres-p-p`
- **Full Path:** `prj-cal-w-wl4-p-afad-53ad:europe-west3:cal-new-disposition-postgres-p-p`
- **Region:** europe-west3
- **Used By:** New Dispo Backend

**Access Method:**
- CloudSQL Proxy (sidecar pattern)
- Configured via `--add-cloudsql-instances` flag in Cloud Run deployment
- Private IP connectivity through VPC

**Purpose:**
- Application-specific data storage
- User preferences and settings
- Operational data separate from TMS data

## Cloud Workflows

Cloud4Log uses Google Cloud Workflows for orchestrating multi-step document processing operations.

### Workflows

| Workflow Name | Purpose | Trigger | Environment |
|---------------|---------|---------|-------------|
| `c4l-workflow-upload` | Orchestrate bordero/rollkart upload to DigiLiS | Cloud Scheduler (`c4l-upload-job`) | Test, Production |
| `c4l-workflow-download` | Orchestrate PoD download from DigiLiS | Cloud Scheduler (`c4l-download-job`) | Test, Production |
| `c4l-workflow-restore-data` | Data restoration operations | Manual | Test |

### Workflow Execution Pattern

**Upload Workflow:**
1. Invoke `bordero-upload` Cloud Function
2. Wait for completion
3. Invoke `rollkart-upload` Cloud Function
4. Return results

**Download Workflow:**
1. Invoke `download` Cloud Function
2. Wait for completion
3. Return results

**Configuration:**
- Function endpoints passed as workflow arguments
- GCS source configuration for depot data
- Error handling and retry logic built into workflows
- Execution logs available in Cloud Logging

## Cloud Scheduler Jobs

Automated execution of Cloud Workflows on defined schedules.

### Test Environment

| Job Name | Schedule | Target | Description |
|----------|----------|--------|-------------|
| `c4l-upload-job` | `*/5 * * * *` | `c4l-workflow-upload` | Execute document upload every 5 minutes |
| `c4l-download-job` | `*/15 * * * *` | `c4l-workflow-download` | Execute PoD download every 15 minutes |

### Production Environment

| Job Name | Schedule | Target | Description |
|----------|----------|--------|-------------|
| `c4l-upload-job` | `* * * * *` | `c4l-workflow-upload` | Execute document upload every minute |
| `c4l-download-job` | `*/15 * * * *` | `c4l-workflow-download` | Execute PoD download every 15 minutes |

**Job Configuration:**
- Time zone: Europe/Berlin (assumed, verify in console)
- Retry configuration: Standard retry with exponential backoff
- Monitoring: Execution logs in Cloud Logging

## Secret Manager

Centralized secret management for sensitive configuration.

### Secrets

| Secret Name | Purpose | Used By |
|-------------|---------|---------|
| `keyCloakConfig` | Keycloak authentication configuration | CrossDock Event Publisher |
| `serviceAccountKey` | Service account credentials | Various components |
| `asb-topic-connection-string` | Azure Service Bus connection string | CrossDock Event Publisher |

**Access Control:**
- Service accounts granted specific secret access via IAM
- Secrets accessed at runtime, not embedded in code or containers
- Automatic secret rotation supported (configuration TBD)

**Best Practices:**
- All sensitive configuration stored in Secret Manager
- No secrets in source code or pipeline definitions
- Version history maintained for all secrets
- Access audited via Cloud Audit Logs

## Cloud Run Services

### Backend Services

| Service Name | Environment | Project | Workload | Endpoint |
|--------------|-------------|---------|----------|----------|
| `cal-new-disposition-tmsbridge-t-t` | Test | prj-cal-w-wl5-t-6c00-53ad | WL5 | https://test.tms-bridge.gcp.nagel-group.com |
| `cal-new-disposition-tmsbridge-p-p` | Production | prj-cal-w-wl5-p-3e5b-53ad | WL5 | https://tms-bridge.gcp.nagel-group.com |
| `cal-new-disposition-backend-t-t` | Test | prj-cal-w-wl4-t-4c48-53ad | WL4 | https://test.dispo.gcp.nagel-group.com |
| `cal-new-disposition-backend-p-p` | Production | prj-cal-w-wl4-p-afad-53ad | WL4 | https://dispo.gcp.nagel-group.com |
| `cal-new-disposition-frontend-t-t` | Test | prj-cal-w-wl4-t-4c48-53ad | WL4 | https://test.dispo.gcp.nagel-group.com |
| `cal-new-disposition-frontend-p-p` | Production | prj-cal-w-wl4-p-afad-53ad | WL4 | https://dispo.gcp.nagel-group.com |

### Common Configuration

**All Cloud Run services:**
- Region: europe-west3
- VPC connectivity: Attached via VPC Connector
- Ingress: Internal and Cloud Load Balancing
- Authentication: IAM-based service-to-service
- User access: Via Cloud Load Balancer with Identity-Aware Proxy or Keycloak

**Scaling Configuration:**
- Min instances: 0 (scale to zero for cost optimization)
- Max instances: Varies by service (50-100)
- Concurrency: Default per service type
- CPU allocation: Only during request processing

## Cloud Functions

### Deployed Functions

| Function Name | Environment | Project | Type | Trigger |
|---------------|-------------|---------|------|---------|
| `new-dispo-filter-shipment-records-uat2820` | Test | prj-cal-w-wl5-t-6c00-53ad | Gen2 | Cloud Storage |
| `new-dispo-filter-shipment-records-abn1034` | Test | prj-cal-w-wl5-t-6c00-53ad | Gen2 | Cloud Storage |
| `cloud-4-log-bordero-upload` | Test/Prod | prj-cal-w-wl5-t/p | Gen2 | HTTP (via Workflow) |
| `cloud-4-log-rollkart-upload` | Test/Prod | prj-cal-w-wl5-t/p | Gen2 | HTTP (via Workflow) |
| `cloud-4-log-download` | Test/Prod | prj-cal-w-wl5-t/p | Gen2 | HTTP (via Workflow) |
| `asb-mock-event-publisher-bucket` | Test | prj-cal-w-wl5-t-6c00-53ad | Gen2 | Cloud Storage |

### Function Configuration

**Dispo Filter Functions:**
- Runtime: Python 3.x
- Memory: 512Mi (default)
- Timeout: 60s
- Concurrency: 1 (default)
- VPC: Attached post-deployment

**Cloud4Log Functions:**
- Runtime: Python 3.x
- Memory: 4Gi
- CPU: 2
- Timeout: 150s
- Max instances: 50
- Concurrency: `maxInstanceRequestConcurrency: 10`
- VPC: Attached post-deployment

**CrossDock Publisher:**
- Runtime: Python 3.x
- Memory: 512Mi (default)
- Timeout: 60s
- VPC: Attached post-deployment

### Function Deployment Pattern

Cloud Functions Gen2 require a specific deployment pattern:
1. Initial deployment without VPC attachment (API limitation)
2. Post-deployment update to attach VPC connector
3. Network tags configuration for connectivity
4. Environment variables and secrets configuration

## VPC Connectors

VPC Connectors enable serverless services (Cloud Run, Cloud Functions) to access resources in a VPC network.

### Connectors

| Connector Name | VPC Network | Subnet | Used By | Environment |
|----------------|-------------|--------|---------|-------------|
| (Variable: `VPC_CONNECTOR`) | `vpc-c-shared-vpc-c-net-s-t` | `sn-vpc-c-net-s-t-europe-west3-common` | All services | Test (WL4, WL5) |
| (Variable: `VPC_CONNECTOR`) | `vpc-c-shared-vpc-c-net-s-p` | `sn-vpc-c-net-s-p-europe-west3-common` | All services | Production (WL4, WL5) |

**Configuration:**
- Region: europe-west3
- Machine type: Varies by workload
- IP range: Dedicated /28 range within subnet
- Throughput: Scales automatically based on load

**Connected Services:**
- All Cloud Run services (TMS Bridge, Backend, Frontend)
- All Cloud Functions (Dispo Filter, Cloud4Log, CrossDock Publisher)

**Purpose:**
- Database connectivity (AlloyDB, CloudSQL)
- Internal service-to-service communication
- Access to on-premises resources via VPN/Interconnect

## IAM Service Accounts

### CI/CD Service Account

**Email:** `wl-cicd@prj-cal-w-cicd-wl5-a591-53ad.iam.gserviceaccount.com`

**Purpose:** Used by Azure DevOps pipelines for all deployments

**Permissions:**
- Cloud Run Admin
- Cloud Functions Admin
- Cloud Workflows Admin
- Cloud Scheduler Admin
- Cloud Storage Admin
- Secret Manager Secret Accessor
- Service Account User
- IAM Service Account Admin (limited scope)

**Authentication:** Workload Identity Federation (Azure DevOps)

### Runtime Service Accounts

Each deployed service uses a dedicated service account with least-privilege permissions:

**TMS Bridge:**
- AlloyDB Client
- VPC Access User

**Backend:**
- CloudSQL Client
- Pub/Sub Subscriber
- Secret Manager Secret Accessor
- VPC Access User
- Service Account Token Creator (for service-to-service)

**Frontend:**
- VPC Access User (minimal)

**Dispo Filter Functions:**
- Cloud Storage Object Viewer (CDC buckets)
- Pub/Sub Publisher
- VPC Access User

**Cloud4Log Functions:**
- Cloud Storage Object Admin (static files, PoD buckets)
- Secret Manager Secret Accessor
- VPC Access User

**CrossDock Publisher:**
- Cloud Storage Object Viewer (datastream bucket)
- Secret Manager Secret Accessor
- VPC Access User

## Logging and Monitoring

### Cloud Logging

All services write logs to Cloud Logging:
- Application logs (stdout/stderr)
- Request logs (Cloud Run automatic)
- Function execution logs
- Workflow execution logs
- Scheduler job logs

**Log Retention:**
- Default: 30 days
- Long-term storage: Cloud Storage log sink (if configured)

### Cloud Monitoring

Key metrics available:
- Cloud Run: Request count, latency, error rate, instance count
- Cloud Functions: Invocations, execution time, error rate, memory usage
- Cloud Workflows: Execution count, success/failure rate, duration
- CloudSQL: CPU, memory, connections, query performance
- Pub/Sub: Message publish rate, subscription delivery rate, backlog

**Alerting:**
- To be documented if configured
- Recommended: Alerts on error rate spikes, latency thresholds, service downtime

## Artifact Registry

**Registry:** europe-west3-docker.pkg.dev

**Repositories:**
- TMS Bridge images
- Backend images
- Frontend images
- Cloud Function source packages (as needed)

**Image Retention:**
- Keep latest N versions (configured per repository)
- Cleanup of old images via automated policy

**Access Control:**
- CI/CD service account: Write access
- Runtime service accounts: Read access (pull images)

## Networking

See [Network Configuration](network-configuration.md) for detailed VPC, subnet, and firewall configuration.
