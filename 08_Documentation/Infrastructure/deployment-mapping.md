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
- Uses network tags for connectivity: `postgres-user`

**Key Configuration:**
- Region: europe-west3
- VPC Connector attached for database access
- Memory: 2Gi
- CPU: 2
- Max instances: 100

### New Dispo Backend

**Purpose:** Core business logic API for the New Dispo application.

**Technology:** .NET application deployed on Cloud Run

**Database Connection:**
- Test: `prj-cal-w-wl4-t-4c48-53ad:europe-west3:cal-new-disposition-psql-t-t` (CloudSQL)
- Production: `prj-cal-w-wl4-p-afad-53ad:europe-west3:cal-new-disposition-postgres-p-p` (CloudSQL)
- Uses CloudSQL Proxy for connectivity

**Key Configuration:**
- Region: europe-west3
- Pub/Sub subscription: `backend-topic-sub` (test environment)
- Memory: 2Gi
- CPU: 2
- Max instances: 100

**External Integrations:**
- Keycloak for authentication
- SMTP for email notifications
- TOP Service (XServer)
- Cloud4Log functions

### New Dispo Frontend

**Purpose:** Angular-based user interface for the New Dispo application.

**Technology:** Angular application served via Cloud Run

**Key Configuration:**
- Region: europe-west3
- Serves static assets and SPA
- Memory: 1Gi
- CPU: 1
- Max instances: 50

### Dispo Filter Function

**Purpose:** Processes Change Data Capture (CDC) events from TMS AlloyDB and publishes filtered shipment records to Pub/Sub.

**Technology:** Python Cloud Function Gen2

**Environment Instances:**
- **UAT2820:** For UAT environment 2820 database instance
- **ABN1034:** For ABN customer environment 1034

**Triggers:**
- Cloud Storage bucket: CDC data written by AlloyDB Datastream
- Bucket examples: `$(WL5_CDC_BUCKET_UAT2820)`, `$(WL5_CDC_BUCKET_ABN1034)`

**Key Configuration:**
- Deploys as Gen2 Cloud Function
- Post-deployment updated to attach to VPC
- Publishes to Pub/Sub topics: `$(WL5_CDC_TOPIC_UAT2820)`, `$(WL5_CDC_TOPIC_ABN1034)`

> **Note:** Multiple environment-specific instances exist to support different database instances or customer environments. This pattern allows isolation between different TMS databases.

### Cloud4Log

**Purpose:** Handles document upload and download operations for bordero, rollkart, and proof of delivery documents.

**Technology:** Python Cloud Functions Gen2 + Cloud Workflows

**Components:**
1. **bordero-upload:** Uploads bordero/cartage documents to DigiLiS
2. **rollkart-upload:** Uploads rollkart documents to DigiLiS
3. **download:** Downloads proof of delivery (PoD) from DigiLiS

**Performance Configuration:**
- Memory: 4Gi per function
- CPU: 2 per function
- Timeout: 150s
- Max instances: 50
- Concurrency: `maxInstanceRequestConcurrency: 10`

**Orchestration:**
- Uses Cloud Workflows for process orchestration
- Workflows: `c4l-workflow-upload`, `c4l-workflow-download`, `c4l-workflow-restore-data`
- Scheduled via Cloud Scheduler:
  - Upload: Every 5 minutes (test), every minute (production)
  - Download: Every 15 minutes (both environments)

### CrossDock Event Publisher

**Purpose:** Publishes TMS database events to Azure Service Bus for cross-dock operations.

**Technology:** Cloud Function Gen2

**Trigger:** Cloud Storage bucket containing AlloyDB Datastream data
- Test: `tms-alloydb-datastream-bucket-wl5-t-t`

**Key Configuration:**
- Database identifier: `Database3`
- Environment: `28302`
- Publishes to Azure Service Bus (not GCP Pub/Sub)
- Uses Keycloak configuration from Secret Manager

> **Note:** Currently only deployed to test environment. No production pipeline exists yet.

## Database Infrastructure

### AlloyDB (TMS Database)

**Repository:** `Code/tms-alloydb-schema`

**Deployment Method:** GitHub Actions (not Azure DevOps)

**Key Workflows:**
- `manual_db_schema_create.yml` - Create TMS database
- `manual_cron_db_schema_create.yml` - Create TMS CRON database
- `manual_db_privileges_create.yml` - Create roles and privileges
- `auto_db_schema_create.yml` - Automated schema creation
- `manual_file_db_schema_create.yml` - File-based schema creation
- `manual_db_schema_build_image.yml` - Build schema Docker image

**Change Data Capture:**
- Uses AlloyDB Datastream to capture database changes
- CDC data written to Cloud Storage buckets
- Triggers Dispo Filter Function and CrossDock Publisher

### CloudSQL (New Dispo Backend Database)

**Test Environment:**
- Instance: `cal-new-disposition-psql-t-t`
- Full path: `prj-cal-w-wl4-t-4c48-53ad:europe-west3:cal-new-disposition-psql-t-t`
- Used by: New Dispo Backend

**Production Environment:**
- Instance: `cal-new-disposition-postgres-p-p`
- Full path: `prj-cal-w-wl4-p-afad-53ad:europe-west3:cal-new-disposition-postgres-p-p`
- Used by: New Dispo Backend

## Deployment Patterns

### Cloud Run Services

All main application components (TMS Bridge, Backend, Frontend) are deployed as Cloud Run services with:
- VPC connectivity for database and internal service access
- IAM-based authentication between services
- Automatic scaling based on load
- Blue-green deployment via Cloud Run revisions

### Cloud Functions Gen2

All Cloud Functions use Gen2 with a specific deployment pattern:
1. Initial deployment as Cloud Function Gen2
2. Post-deployment update to attach to shared VPC
3. Additional configuration updates for network tags and settings

This workaround is necessary due to Gen2 limitations in the deployment API.

### Multi-Environment Strategy

- **Test Environment:** Uses `master` branch, allows rapid iteration
- **Production Environment:** Uses dedicated release branches (`release/v2.0`, `release/v2.2.2`, etc.)
- **Environment-specific configurations:** Injected via Azure DevOps pipeline variables
