# Component Deployment Mapping

## Production Deployments

| Component | Workload | GCP Project ID | Service Name | Pipeline File |
|-----------|----------|----------------|--------------|---------------|
| **TMS Bridge** | WL5 | prj-cal-w-wl5-p-3e5b-53ad | cal-new-disposition-tmsbridge-p-p | `Code/Disposition-Abstraction-Layer/azure-pipelines-cloudrun-p-p.yml` |
| **Backend** | WL4 | prj-cal-w-wl4-p-afad-53ad | cal-new-disposition-backend-p-p | `Code/Disposition-Backend/azure-pipelines-cloudrun-p-p.yml` |
| **Frontend** | WL4 | prj-cal-w-wl4-p-afad-53ad | cal-new-disposition-frontend-p-p | `Code/Disposition-Frontend/azure-pipelines-cloudrun-p-p.yml` |
| **Cloud4Log** | WL5 | prj-cal-w-wl5-p-3e5b-53ad | cloud-4-log-bordero-upload<br>cloud-4-log-rollkart-upload<br>cloud-4-log-download | `Code/Nagel-GCP/Cloud4Log/devops/azure-pipelines-cloudrun-p-p.yml` |

### Production Release Branches

- **Backend & Frontend:** `release/v2.0`
- **TMS Bridge:** `release/v2.2.2`
- **Cloud4Log:** `release/cloud4log/v1.0`

## Test Deployments

| Component | Workload | GCP Project ID | Service Name | Pipeline File |
|-----------|----------|----------------|--------------|---------------|
| **TMS Bridge** | WL5 | prj-cal-w-wl5-t-6c00-53ad | cal-new-disposition-tmsbridge-t-t | `Code/Disposition-Abstraction-Layer/azure-pipelines-cloudrun-t-t-wl5.yml` |
| **Backend** | WL4 | prj-cal-w-wl4-t-4c48-53ad | cal-new-disposition-backend-t-t | `Code/Disposition-Backend/azure-pipelines-cloudrun-t-t.yml` |
| **Frontend** | WL4 | prj-cal-w-wl4-t-4c48-53ad | cal-new-disposition-frontend-t-t | `Code/Disposition-Frontend/azure-pipelines-cloudrun-t-t.yml` |
| **Dispo Filter UAT2820** | WL5 | prj-cal-w-wl5-t-6c00-53ad | new-dispo-filter-shipment-records-uat2820 | `Code/Nagel-GCP/CALConsult.Disposition.Functions/devops/azure-pipelines-cloudrun-t-t-uat2820.yml` |
| **Dispo Filter ABN1034** | WL5 | prj-cal-w-wl5-t-6c00-53ad | new-dispo-filter-shipment-records-abn1034 | `Code/Nagel-GCP/CALConsult.Disposition.Functions/devops/azure-pipelines-cloudrun-t-t-abn1034.yml` |
| **Cloud4Log** | WL5 | prj-cal-w-wl5-t-6c00-53ad | cloud-4-log-bordero-upload<br>cloud-4-log-rollkart-upload<br>cloud-4-log-download | `Code/Nagel-GCP/Cloud4Log/devops/azure-pipelines-cloudrun-t-t.yml` |
| **CrossDock Publisher** | WL5 | prj-cal-w-wl5-t-6c00-53ad | asb-mock-event-publisher-bucket | `Code/Nagel-GCP/CrossDockEventPublisher/devops/azure-pipelines-cloudrun-t-t.yml` |

### Test Release Branch

All test deployments use the `master` branch.

## Component Details

### TMS Bridge (Disposition Abstraction Layer)

**Purpose:** Provides a REST API abstraction layer for accessing the TMS AlloyDB database.

**Technology:** .NET application deployed on Cloud Run

**Database Connection:**
- Connects to AlloyDB via VPC network
- Uses network tag: `postgres-user`

**Configuration:**
- Region: europe-west3
- Memory: 1Gi
- CPU: 1
- VPC Connector attached for database access

### New Dispo Backend

**Purpose:** Core business logic API for the New Dispo application.

**Technology:** .NET application deployed on Cloud Run

**Database Connection:**
- Test: `prj-cal-w-wl4-t-4c48-53ad:europe-west3:cal-new-disposition-psql-t-t` (CloudSQL)
- Production: `prj-cal-w-wl4-p-afad-53ad:europe-west3:cal-new-disposition-postgres-p-p` (CloudSQL)
- Uses CloudSQL Proxy for connectivity

**Configuration:**
- Region: europe-west3
- Memory: 1Gi
- CPU: 1
- Pub/Sub subscription: `backend-topic-sub` (test environment)

**External Integrations:**
- Keycloak for authentication
- TOP Service (XServer)
- Cloud4Log functions

### New Dispo Frontend

**Purpose:** Angular-based user interface for the New Dispo application.

**Technology:** Angular application served via Cloud Run

**Configuration:**
- Region: europe-west3
- Memory: 1Gi
- CPU: 1

### Dispo Filter Function

**Purpose:** Processes Change Data Capture (CDC) events from TMS AlloyDB and publishes filtered shipment records to Pub/Sub.

**Technology:** Python Cloud Function Gen2

**Environment Instances:**
- **UAT2820:** For UAT environment 2820 database instance
- **ABN1034:** For ABN customer environment 1034

**Triggers:**
- Cloud Storage bucket containing CDC data written by AlloyDB Datastream

**Configuration:**
- Deployed as Gen2 Cloud Function
- Attached to VPC post-deployment
- Publishes to Pub/Sub topics

### Cloud4Log

**Purpose:** Handles document upload and download operations for bordero, rollkart, and proof of delivery documents.

**Technology:** Python Cloud Functions Gen2 + Cloud Workflows

**Components:**
1. **bordero-upload:** Uploads bordero/cartage documents to DigiLiS
2. **rollkart-upload:** Uploads rollkart documents to DigiLiS
3. **download:** Downloads proof of delivery (PoD) from DigiLiS

**Function Configuration:**
- Memory: 4Gi per function
- CPU: 2 per function
- Timeout: 150s
- Max instances: 50
- Concurrency: 10 requests per instance

**Orchestration:**
- Cloud Workflows: `c4l-workflow-upload`, `c4l-workflow-download`, `c4l-workflow-restore-data`
- Cloud Scheduler jobs:
  - Upload job: `c4l-upload-job`
    - Test schedule: `*/5 * * * *` (every 5 minutes)
    - Production schedule: `* * * * *` (every minute)
  - Download job: `c4l-download-job`
    - Test schedule: `*/15 * * * *` (every 15 minutes)
    - Production schedule: `*/15 * * * *` (every 15 minutes)

### CrossDock Event Publisher

**Purpose:** Publishes TMS database events to Azure Service Bus for cross-dock operations.

**Technology:** Cloud Function Gen2

**Trigger:**
- Cloud Storage bucket: `tms-alloydb-datastream-bucket-wl5-t-t` (contains AlloyDB Datastream data)

**Configuration:**
- Database identifier: `Database3`
- Environment: `28302`
- Publishes to Azure Service Bus
- Keycloak configuration from Secret Manager: `keyCloakConfig`
- Connection string from Secret Manager: `asb-topic-connection-string`

**Deployment Status:**
- Currently only deployed to test environment
- No production pipeline exists

## Database Infrastructure

### CloudSQL (New Dispo Backend Database)

**Test Environment:**
- Instance: `cal-new-disposition-psql-t-t`
- Full path: `prj-cal-w-wl4-t-4c48-53ad:europe-west3:cal-new-disposition-psql-t-t`
- Used by: New Dispo Backend

**Production Environment:**
- Instance: `cal-new-disposition-postgres-p-p`
- Full path: `prj-cal-w-wl4-p-afad-53ad:europe-west3:cal-new-disposition-postgres-p-p`
- Used by: New Dispo Backend

## Deployment Configuration

### Cloud Run Services

All Cloud Run services (TMS Bridge, Backend, Frontend) are deployed with:
- VPC connectivity for database and internal service access
- IAM-based authentication between services
- Ingress: internal
- VPC egress: all-traffic

### Cloud Functions Gen2

Cloud Functions deployment process:
1. Initial deployment as Cloud Function Gen2
2. Post-deployment update to attach to shared VPC
3. Network tags configuration

### Multi-Environment Strategy

- **Test Environment:** Uses `master` branch
- **Production Environment:** Uses dedicated release branches
- **Configuration:** Environment-specific values injected via Azure DevOps pipeline variables
