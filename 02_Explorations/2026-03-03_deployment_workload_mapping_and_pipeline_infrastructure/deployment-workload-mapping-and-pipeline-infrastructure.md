# deployment workload mapping and pipeline infrastructure

**Date:** 2026-03-03
**Status:** Exploration

---

## Original User Input

> User requested to find pipeline and deployment information for all New Dispo components, specifically:
> - Which workload (wl4, wl5, etc.) each component is deployed to
> - Pipeline file locations
> - Information about TMS Bridge, Backend, Frontend, Dispo Filter Function, Cloud4Log, CrossDock Publisher, and CrossDock Listener

---

## Summary

This exploration documents the complete deployment infrastructure for the New Dispo system. All components are deployed to Google Cloud Platform using Azure DevOps pipelines with Workload Identity Federation. The architecture is split across two workloads:
- **WL4**: Backend, Frontend
- **WL5**: TMS Bridge, Cloud Functions (Dispo Filter, Cloud4Log, CrossDock Publisher)

No CrossDock Listener component was found - only a CrossDock Event Publisher exists.

## Component Deployment Mapping

### Production Deployments

| Component | Workload | GCP Project ID | Service Name | Pipeline File |
|-----------|----------|----------------|--------------|---------------|
| **TMS Bridge** | WL5 | prj-cal-w-wl5-p-3e5b-53ad | cal-new-disposition-tmsbridge-p-p | `Code/Disposition-Abstraction-Layer/azure-pipelines-cloudrun-p-p.yml` |
| **Backend** | WL4 | prj-cal-w-wl4-p-afad-53ad | cal-new-disposition-backend-p-p | `Code/Disposition-Backend/azure-pipelines-cloudrun-p-p.yml` |
| **Frontend** | WL4 | prj-cal-w-wl4-p-afad-53ad | cal-new-disposition-frontend-p-p | `Code/Disposition-Frontend/azure-pipelines-cloudrun-p-p.yml` |
| **Cloud4Log** | WL5 | prj-cal-w-wl5-p-3e5b-53ad | cloud-4-log-bordero-upload<br>cloud-4-log-rollkart-upload<br>cloud-4-log-download | `Code/Nagel-GCP/Cloud4Log/devops/azure-pipelines-cloudrun-p-p.yml` |

**Production Release Branches:**
- Backend & Frontend: `release/v2.0`
- TMS Bridge: `release/v2.2.2`
- Cloud4Log: `release/cloud4log/v1.0`

### Test Deployments

| Component | Workload | GCP Project ID | Service Name | Pipeline File |
|-----------|----------|----------------|--------------|---------------|
| **TMS Bridge** | WL5 | prj-cal-w-wl5-t-6c00-53ad | cal-new-disposition-tmsbridge-t-t | `Code/Disposition-Abstraction-Layer/azure-pipelines-cloudrun-t-t-wl5.yml` |
| **Backend** | WL4 | prj-cal-w-wl4-t-4c48-53ad | cal-new-disposition-backend-t-t | `Code/Disposition-Backend/azure-pipelines-cloudrun-t-t.yml` |
| **Frontend** | WL4 | prj-cal-w-wl4-t-4c48-53ad | cal-new-disposition-frontend-t-t | `Code/Disposition-Frontend/azure-pipelines-cloudrun-t-t.yml` |
| **Dispo Filter UAT2820** | WL5 | prj-cal-w-wl5-t-6c00-53ad | new-dispo-filter-shipment-records-uat2820 | `Code/Nagel-GCP/CALConsult.Disposition.Functions/devops/azure-pipelines-cloudrun-t-t-uat2820.yml` |
| **Dispo Filter ABN1034** | WL5 | prj-cal-w-wl5-t-6c00-53ad | new-dispo-filter-shipment-records-abn1034 | `Code/Nagel-GCP/CALConsult.Disposition.Functions/devops/azure-pipelines-cloudrun-t-t-abn1034.yml` |
| **Cloud4Log** | WL5 | prj-cal-w-wl5-t-6c00-53ad | cloud-4-log-bordero-upload<br>cloud-4-log-rollkart-upload<br>cloud-4-log-download | `Code/Nagel-GCP/Cloud4Log/devops/azure-pipelines-cloudrun-t-t.yml` |
| **CrossDock Publisher** | WL5 | prj-cal-w-wl5-t-6c00-53ad | asb-mock-event-publisher-bucket | `Code/Nagel-GCP/CrossDockEventPublisher/devops/azure-pipelines-cloudrun-t-t.yml` |

**Test Release Branch:** `master`

## Infrastructure Details

### Common Infrastructure Elements

**All Deployments:**
- **Region:** europe-west3
- **CI/CD Authentication:** Azure DevOps with Workload Identity Federation
- **CI/CD Service Account:** `wl-cicd@prj-cal-w-cicd-wl5-a591-53ad.iam.gserviceaccount.com`
- **Workload Identity Pool:** `azure-devops` (project number: 534233136072 for WL5, 607166292072 for WL4)

### Network Configuration by Environment

**Test Environment (WL4 & WL5):**
- VPC: `vpc-c-shared-vpc-c-net-s-t`
- VPC Project: `prj-cal-net-s-t-e004-53ad`
- Subnet: `sn-vpc-c-net-s-t-europe-west3-common`
- Network Tags: `vpc-connector,postgres-user,http-web-user,https-user,p5101-user,p8080-user,https-producer,p5101-producer,p8080-producer`

**Production Environment WL4:**
- VPC: `vpc-c-shared-vpc-c-net-s-p`
- VPC Project: `prj-cal-net-s-p-19c3-53ad`
- Subnet: `sn-vpc-c-net-s-p-europe-west3-common`

**Production Environment WL5:**
- VPC: `vpc-c-shared-vpc-c-net-s-p`
- VPC Project: `prj-cal-net-s-p-19c3-53ad`
- Subnet: `sn-vpc-c-net-s-p-europe-west3-common`

### Service Endpoints

**Test Environment:**
- Frontend: `https://test.dispo.gcp.nagel-group.com`
- Backend: `https://test.dispo.gcp.nagel-group.com`
- TMS Bridge: `https://test.tms-bridge.gcp.nagel-group.com`
- Keycloak: `https://test.dispo.gcp.nagel-group.com/keycloak`

**Production Environment:**
- Frontend: `https://dispo.gcp.nagel-group.com`
- Backend: `https://dispo.gcp.nagel-group.com`
- TMS Bridge: `https://tms-bridge.gcp.nagel-group.com`
- Keycloak: `https://dispo.gcp.nagel-group.com/keycloak`

## Findings

### Key Architectural Decisions

1. **Split Workload Architecture:**
   - Backend and Frontend run on WL4
   - TMS Bridge and all Cloud Functions run on WL5
   - This separation may be due to different security/compliance requirements or organizational boundaries

2. **CI/CD Centralization:**
   - All pipelines use the WL5 CI/CD service account, even for WL4 deployments
   - This suggests a centralized CI/CD management approach

3. **Cloud Functions Deployment Pattern:**
   - All Cloud Functions are deployed as Gen2 functions
   - They are updated post-deployment to attach to shared VPC (Gen2 limitation workaround)
   - Multiple configuration updates needed after initial deployment

4. **Database Connectivity:**
   - Backend has CloudSQL proxy configuration: `--add-cloudsql-instances prj-cal-w-wl4-t-4c48-53ad:europe-west3:cal-new-disposition-psql-t-t`
   - TMS Bridge connects to AlloyDB via VPC network tags

5. **CrossDock Event Publisher:**
   - Only test deployment exists (no production pipeline found)
   - Triggered by Cloud Storage bucket: `tms-alloydb-datastream-bucket-wl5-t-t`
   - Publishes to Azure Service Bus (not Pub/Sub)
   - Environment variable: `DATABASE_IDENTIFIER=Database3` and `ENVIRONMENT=28302`

6. **No CrossDock Listener:**
   - Despite the user's question, no CrossDock Listener component exists
   - Only the CrossDock Event Publisher was found

### Dispo Filter Function Variants

The Dispo Filter Function has multiple environment-specific deployments:
- **UAT2820:** Deployed from `release/v2.2` branch, uses CDC bucket `$(WL5_CDC_BUCKET_UAT2820)` and topic `$(WL5_CDC_TOPIC_UAT2820)`
- **ABN1034:** Separate pipeline exists (`azure-pipelines-cloudrun-t-t-abn1034.yml`)

This suggests different database instances or customer environments.

### Cloud4Log Architecture

Cloud4Log deploys three separate Cloud Functions:
1. **bordero-upload:** Uploads bordero/cartage documents
2. **rollkart-upload:** Uploads rollkart documents
3. **download:** Downloads proof of delivery (PoD)

**Performance Configuration:**
- **Concurrency:** `maxInstanceRequestConcurrency: 10` (set across all Cloud4Log functions)
- **Memory:** 4Gi per function
- **CPU:** 2 per function
- **Timeout:** 150s
- **Max Instances:** 50

Additionally deploys:
- **Workflows:** `c4l-workflow-upload`, `c4l-workflow-download`, `c4l-workflow-restore-data`
- **Scheduled Jobs:** Cron jobs triggering workflows (every 5 min for upload, every 15 min for download in test)

## Questions/Open Items

1. **Why is the architecture split between WL4 and WL5?**
   - Is this due to compliance/security boundaries?
   - Different organizational ownership?
   - Migration in progress?

2. **CrossDock Event Publisher Production Deployment:**
   - Why is there no production pipeline?
   - Is this component still in testing phase?
   - Is it deployed manually to production?

3. **CrossDock Listener:**
   - Does it exist under a different name?
   - Is event consumption handled within another component?
   - Is the Backend the actual "listener" for CrossDock events via Pub/Sub?

4. **Multiple Dispo Filter Function Instances:**
   - What is the relationship between UAT2820 and ABN1034?
   - Are these different customer environments or database instances?
   - How many total instances exist in production?

5. **CI/CD Service Account:**
   - Why do WL4 deployments use a WL5 CI/CD service account?
   - Is there a WL4 CI/CD service account that should be used instead?

6. **TMS Database Deployment:**
   - Where are the pipeline files for `Code/tms-alloydb-schema`?
   - Found GitHub workflow files in `.github/workflows/` but need to investigate further

## Related Files

### Pipeline Files

**Disposition-Abstraction-Layer (TMS Bridge):**
- `Code/Disposition-Abstraction-Layer/azure-pipelines-cloudrun-t-t-wl5.yml`
- `Code/Disposition-Abstraction-Layer/azure-pipelines-cloudrun-p-p.yml`
- `Code/Disposition-Abstraction-Layer/azure-pipelines-dev.yml`
- `Code/Disposition-Abstraction-Layer/azure-pipelines-staging.yml`

**Disposition-Backend:**
- `Code/Disposition-Backend/azure-pipelines-cloudrun-t-t.yml`
- `Code/Disposition-Backend/azure-pipelines-cloudrun-p-p.yml`
- `Code/Disposition-Backend/azure-pipelines-cloudrun-kc-p-p.yml`
- `Code/Disposition-Backend/azure-pipelines-cloudrun-perms.yml`
- `Code/Disposition-Backend/azure-pipelines-staging.yml`
- `Code/Disposition-Backend/azure-pipelines.yml`
- `Code/Disposition-Backend/Dockerfile.cloudrun-t-t`
- `Code/Disposition-Backend/Dockerfile.cloudrun-p-p`

**Disposition-Frontend:**
- `Code/Disposition-Frontend/azure-pipelines-cloudrun-t-t.yml`
- `Code/Disposition-Frontend/azure-pipelines-cloudrun-p-p.yml`
- `Code/Disposition-Frontend/azure-pipelines-staging.yml`
- `Code/Disposition-Frontend/azure-pipelines.yml`

**Cloud Functions:**
- `Code/Nagel-GCP/CALConsult.Disposition.Functions/devops/azure-pipelines-cloudrun-t-t-uat2820.yml`
- `Code/Nagel-GCP/CALConsult.Disposition.Functions/devops/azure-pipelines-cloudrun-t-t-abn1034.yml`
- `Code/Nagel-GCP/CALConsult.Disposition.Functions/devops/azure-pipelines-dev.yml`

**Cloud4Log:**
- `Code/Nagel-GCP/Cloud4Log/devops/azure-pipelines-cloudrun-t-t.yml`
- `Code/Nagel-GCP/Cloud4Log/devops/azure-pipelines-cloudrun-t-t-integration-tests.yml`
- `Code/Nagel-GCP/Cloud4Log/devops/azure-pipelines-cloudrun-t-t-c4ldepots-json.yml`
- `Code/Nagel-GCP/Cloud4Log/devops/azure-pipelines-cloudrun-p-p.yml`
- `Code/Nagel-GCP/Cloud4Log/devops/azure-pipelines-cloudrun-p-p-c4ldepots-json.yml`
- `Code/Nagel-GCP/Cloud4Log/devops/workflow-upload.yml`
- `Code/Nagel-GCP/Cloud4Log/devops/workflow-download.yml`
- `Code/Nagel-GCP/Cloud4Log/devops/workflow-restore-data.yml`

**CrossDock Event Publisher:**
- `Code/Nagel-GCP/CrossDockEventPublisher/devops/azure-pipelines-cloudrun-t-t.yml`
- `Code/Nagel-GCP/CrossDockEventPublisher/devops/azure-pipelines-dev.yml`

### Deployment Configuration Files
- `Code/Disposition-Abstraction-Layer/deployment.yaml`
- `Code/Disposition-Backend/deployment.yaml`
- `Code/Disposition-Frontend/deployment.yaml`

### Database Schema
- `Code/tms-alloydb-schema/.github/workflows/` - Contains GitHub Actions workflows
- `Code/tms-alloydb-schema/src/sql/scripts/config/` - Database configuration files for wl2 environments

## GCP Native Components and Services

### Cloud Storage Buckets

**Test Environment:**
- `tms-alloydb-datastream-bucket-wl5-t-t` - Triggers CrossDock Event Publisher (AlloyDB datastream)
- `test-cdc-2` - Dev environment CDC bucket for Dispo Filter Function
- `c4l-static-files-files-documents-t-t` - Cloud4Log static files and depot configurations
- `$(C4L_BUCKET_POD)` - Cloud4Log Proof of Delivery storage (test)
- `$(WL5_CDC_BUCKET_UAT2820)` - CDC bucket for UAT2820 environment
- `$(WL5_CDC_BUCKET_ABN1034)` - CDC bucket for ABN1034 environment

**Production Environment:**
- `c4l-static-files-files-documents-p-p` - Cloud4Log static files and depot configurations
- `$(C4L_BUCKET_POD_P_P)` - Cloud4Log Proof of Delivery storage (prod)

### Pub/Sub Topics and Subscriptions

**Topics:**
- `$(WL5_CDC_TOPIC_UAT2820)` - Change Data Capture topic for UAT2820 (WL5 test)
- `$(WL5_CDC_TOPIC_ABN1034)` - Change Data Capture topic for ABN1034 (WL5 test)
- `$(P3_CDC_TOPIC)` - Dev environment CDC topic

**Subscriptions:**
- `backend-topic-sub` - Backend subscription for Pub/Sub messages (test environment)

### Secret Manager Secrets

- `keyCloakConfig` - Keycloak configuration (used by CrossDock Event Publisher)
- `serviceAccountKey` - Service account credentials
- `asb-topic-connection-string` - Azure Service Bus connection string for CrossDock Publisher

### CloudSQL Instances

**Test (WL4):**
- Instance: `cal-new-disposition-psql-t-t`
- Full path: `prj-cal-w-wl4-t-4c48-53ad:europe-west3:cal-new-disposition-psql-t-t`
- Used by: Backend

**Production (WL4):**
- Instance: `cal-new-disposition-postgres-p-p`
- Full path: `prj-cal-w-wl4-p-afad-53ad:europe-west3:cal-new-disposition-postgres-p-p`
- Used by: Backend

### AlloyDB

- **Schema Repository:** `Code/tms-alloydb-schema`
- **Deployment:** GitHub Actions workflows (not Azure DevOps)
- **Workflows:**
  - `manual_db_schema_create.yml` - Create TMS database
  - `manual_cron_db_schema_create.yml` - Create TMS CRON database
  - `manual_db_privileges_create.yml` - Create roles and privileges
  - `auto_db_schema_create.yml` - Automated schema creation
  - `manual_file_db_schema_create.yml` - File-based schema creation
  - `manual_db_schema_build_image.yml` - Build schema Docker image

### Workflows (Cloud Workflows)

Cloud4Log uses Google Cloud Workflows for orchestration:

**Test Environment (WL5):**
- `c4l-workflow-upload` - Orchestrates bordero/rollkart upload process
- `c4l-workflow-download` - Orchestrates proof of delivery download
- `c4l-workflow-restore-data` - Data restoration workflow

**Production Environment (WL5):**
- `c4l-workflow-upload` - Orchestrates bordero/rollkart upload process
- `c4l-workflow-download` - Orchestrates proof of delivery download

### Cloud Scheduler Jobs

**Test Environment:**
- `c4l-upload-job`
  - Schedule: `*/5 * * * *` (every 5 minutes)
  - Triggers: `c4l-workflow-upload`
  - Args: borderoUpload, rollkartUpload endpoints, gcsSource config

- `c4l-download-job`
  - Schedule: `*/15 * * * *` (every 15 minutes)
  - Triggers: `c4l-workflow-download`
  - Args: downloadPod endpoint, gcsSource config

**Production Environment:**
- `c4l-upload-job`
  - Schedule: `* * * * *` (every minute)
  - Triggers: `c4l-workflow-upload`

- `c4l-download-job`
  - Schedule: `*/15 * * * *` (every 15 minutes)
  - Triggers: `c4l-workflow-download`

### Keycloak (Identity Provider)

**Not a GCP service** - Keycloak is deployed separately but integrated with all components.

**Test Environment:**
- URL: `https://test.dispo.gcp.nagel-group.com/keycloak`
- Realm: `master`
- Clients: `cal-client`, `client-credentials-test`

**Production Environment:**
- URL: `https://dispo.gcp.nagel-group.com/keycloak`
- Realm: `master`

**Configuration:**
- Secret Manager: `keyCloakConfig` (used by CrossDock Publisher)
- Backend ClientSecret: Injected via pipeline variables
- Authentication: OAuth2/OIDC

### External Services Integration

**Azure Service Bus:**
- Used by: CrossDock Event Publisher
- Connection String: Stored in Secret Manager (`asb-topic-connection-string`)
- Purpose: Publishing events to external systems
- Environment variable: `OUTBOUND_CONNECTION_STRING=asb-topic-connection-string`

**DigiLiS (SMB/File Share):**
- Used by: Cloud4Log
- Configuration: Username, Password, Domain (injected via pipeline)
- Purpose: File exchange integration

**SMTP/Email:**
- Used by: Backend
- Configuration: Server, Port, Username, Password (injected via pipeline)
- Purpose: Email notifications

**TOP Service:**
- Used by: Backend
- Test Base URL: `https://featuretest-top.cal-consult.int/`
- XServer URL: `http://10.32.3.102:30000`

## Related Documentation

See `CLAUDE.md` for the official component mapping:
- Code/tms-alloydb-schema → TMS Database
- Code/Disposition-Abstraction-Layer → TMS Bridge
- Code/Disposition-Backend → New Dispo Backend
- Code/Disposition-Frontend → New Dispo Frontend
- Code/Nagel-GCP/CALConsult.Disposition.Functions → New Dispo Cloud Functions
- Code/Nagel-GCP/Cloud4Log → Cloud4Log Cloud Functions
