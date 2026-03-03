# CI/CD Pipelines

## Overview

All New Dispo components use Azure DevOps pipelines for CI/CD automation. The pipelines deploy to Google Cloud Platform using Workload Identity Federation for secure, keyless authentication.

## Common Pipeline Configuration

### Authentication

**Method:** Workload Identity Federation (WIF)

**CI/CD Service Account:** `wl-cicd@prj-cal-w-cicd-wl5-a591-53ad.iam.gserviceaccount.com`

**Workload Identity Pools:**
- WL5: `azure-devops` (project number: 534233136072)
- WL4: `azure-devops` (project number: 607166292072)

> **Note:** All components, including those deployed to WL4, use the WL5 CI/CD service account. This centralized approach simplifies CI/CD management.

### Deployment Region

All components are deployed to: **europe-west3**

## Pipeline Files by Component

### TMS Bridge (Disposition Abstraction Layer)

**Repository:** `Code/Disposition-Abstraction-Layer`

**Pipelines:**
- `azure-pipelines-cloudrun-p-p.yml` - Production deployment (WL5)
- `azure-pipelines-cloudrun-t-t-wl5.yml` - Test deployment (WL5)
- `azure-pipelines-dev.yml` - Development environment
- `azure-pipelines-staging.yml` - Staging environment

**Deployment Target:**
- Production: `prj-cal-w-wl5-p-3e5b-53ad`
- Test: `prj-cal-w-wl5-t-6c00-53ad`

**Additional Configuration:**
- `deployment.yaml` - Cloud Run service configuration
- VPC connector attachment for AlloyDB access
- Network tags: `postgres-user`, `http-web-user`, `https-user`

### New Dispo Backend

**Repository:** `Code/Disposition-Backend`

**Pipelines:**
- `azure-pipelines-cloudrun-p-p.yml` - Production deployment (WL4)
- `azure-pipelines-cloudrun-t-t.yml` - Test deployment (WL4)
- `azure-pipelines-cloudrun-kc-p-p.yml` - Keycloak-specific production deployment
- `azure-pipelines-cloudrun-perms.yml` - Permissions management
- `azure-pipelines-staging.yml` - Staging environment
- `azure-pipelines.yml` - Legacy/alternative pipeline

**Deployment Target:**
- Production: `prj-cal-w-wl4-p-afad-53ad`
- Test: `prj-cal-w-wl4-t-4c48-53ad`

**Docker Configuration:**
- `Dockerfile.cloudrun-t-t` - Test environment Dockerfile
- `Dockerfile.cloudrun-p-p` - Production environment Dockerfile

**Additional Configuration:**
- `deployment.yaml` - Cloud Run service configuration
- CloudSQL proxy configuration for database access
- Pub/Sub subscription binding
- Secret injection for Keycloak, SMTP, and TOP Service

### New Dispo Frontend

**Repository:** `Code/Disposition-Frontend`

**Pipelines:**
- `azure-pipelines-cloudrun-p-p.yml` - Production deployment (WL4)
- `azure-pipelines-cloudrun-t-t.yml` - Test deployment (WL4)
- `azure-pipelines-staging.yml` - Staging environment
- `azure-pipelines.yml` - Legacy/alternative pipeline

**Deployment Target:**
- Production: `prj-cal-w-wl4-p-afad-53ad`
- Test: `prj-cal-w-wl4-t-4c48-53ad`

**Build Process:**
- Angular application build
- Environment-specific configuration injection
- Static asset optimization
- Container image creation and deployment

**Additional Configuration:**
- `deployment.yaml` - Cloud Run service configuration

### Dispo Filter Function

**Repository:** `Code/Nagel-GCP/CALConsult.Disposition.Functions`

**Pipelines:**
- `azure-pipelines-cloudrun-t-t-uat2820.yml` - UAT2820 environment (WL5)
- `azure-pipelines-cloudrun-t-t-abn1034.yml` - ABN1034 environment (WL5)
- `azure-pipelines-dev.yml` - Development environment

**Deployment Target:**
- All test deployments: `prj-cal-w-wl5-t-6c00-53ad`

**Deployment Pattern:**
1. Deploy Cloud Function Gen2
2. Update function configuration to attach VPC
3. Update network tags for connectivity
4. Configure Cloud Storage trigger
5. Configure Pub/Sub topic for output

**Environment-Specific Configuration:**
- UAT2820: `release/v2.2` branch, CDC bucket: `$(WL5_CDC_BUCKET_UAT2820)`, topic: `$(WL5_CDC_TOPIC_UAT2820)`
- ABN1034: Separate pipeline with dedicated bucket and topic

### Cloud4Log

**Repository:** `Code/Nagel-GCP/Cloud4Log`

**Pipelines:**
- `azure-pipelines-cloudrun-p-p.yml` - Production deployment (WL5)
- `azure-pipelines-cloudrun-t-t.yml` - Test deployment (WL5)
- `azure-pipelines-cloudrun-t-t-integration-tests.yml` - Integration test runner
- `azure-pipelines-cloudrun-t-t-c4ldepots-json.yml` - Test depot configuration update
- `azure-pipelines-cloudrun-p-p-c4ldepots-json.yml` - Production depot configuration update
- `workflow-upload.yml` - Upload workflow deployment
- `workflow-download.yml` - Download workflow deployment
- `workflow-restore-data.yml` - Data restoration workflow deployment

**Deployment Target:**
- Production: `prj-cal-w-wl5-p-3e5b-53ad`
- Test: `prj-cal-w-wl5-t-6c00-53ad`

**Deployment Components:**
1. Three Cloud Functions (bordero-upload, rollkart-upload, download)
2. Three Cloud Workflows (upload, download, restore-data)
3. Cloud Scheduler jobs for automated execution
4. Depot configuration files to Cloud Storage

**Deployment Pattern:**
- Each function deployed with specific memory, CPU, and concurrency settings
- Post-deployment VPC attachment
- Workflow deployment with function endpoint configuration
- Scheduler job creation/update with cron schedules

### CrossDock Event Publisher

**Repository:** `Code/Nagel-GCP/CrossDockEventPublisher`

**Pipelines:**
- `azure-pipelines-cloudrun-t-t.yml` - Test deployment (WL5)
- `azure-pipelines-dev.yml` - Development environment

**Deployment Target:**
- Test: `prj-cal-w-wl5-t-6c00-53ad`

**Configuration:**
- Triggered by Cloud Storage bucket: `tms-alloydb-datastream-bucket-wl5-t-t`
- Publishes to Azure Service Bus
- Uses Secret Manager for Keycloak config and ASB connection string

> **Note:** No production pipeline exists. Production deployment approach to be determined.

## Pipeline Execution Flow

### Typical Cloud Run Deployment

1. **Build Stage:**
   - Checkout code from repository
   - Build Docker image
   - Tag image with build number
   - Push to Google Artifact Registry

2. **Deploy Stage:**
   - Authenticate to GCP using Workload Identity Federation
   - Deploy Cloud Run service with configuration from pipeline variables
   - Configure VPC connector, network tags, environment variables
   - Set IAM policies and service account
   - Update traffic to new revision (blue-green deployment)

3. **Verification Stage:**
   - Health check on new revision
   - Smoke tests (if configured)

### Cloud Function Gen2 Deployment Pattern

1. **Build Stage:**
   - Package function code
   - Install dependencies
   - Create deployment package

2. **Initial Deploy:**
   - Deploy Cloud Function Gen2 with basic configuration
   - Note: VPC attachment not possible during initial deployment (Gen2 limitation)

3. **Post-Deploy Configuration:**
   - Update function to attach VPC connector
   - Set network tags for connectivity
   - Configure environment variables
   - Set resource limits (memory, CPU, timeout)
   - Configure concurrency settings

4. **Trigger Configuration:**
   - Configure Cloud Storage trigger (for CDC functions)
   - Set up event filters

## Pipeline Variables and Secrets

### Common Variables (Injected per Environment)

**WL4 Projects:**
- `WL4_PROJECT_T_T` - Test project ID
- `WL4_PROJECT_P_P` - Production project ID

**WL5 Projects:**
- `WL5_PROJECT_T_T` - Test project ID
- `WL5_PROJECT_P_P` - Production project ID

**Network Configuration:**
- `VPC_CONNECTOR` - VPC connector name
- `VPC_PROJECT` - Shared VPC project ID
- `SUBNET` - Subnet for Cloud Run services

**Database:**
- `CLOUDSQL_INSTANCE` - CloudSQL instance connection string (Backend)

**Pub/Sub:**
- `WL5_CDC_TOPIC_UAT2820` - CDC topic for UAT2820
- `WL5_CDC_TOPIC_ABN1034` - CDC topic for ABN1034
- `WL5_CDC_BUCKET_UAT2820` - CDC bucket for UAT2820
- `WL5_CDC_BUCKET_ABN1034` - CDC bucket for ABN1034

**Cloud4Log:**
- `C4L_BUCKET_POD` - Proof of Delivery bucket (test)
- `C4L_BUCKET_POD_P_P` - Proof of Delivery bucket (production)

**Keycloak:**
- `KEYCLOAK_CLIENT_SECRET` - Backend client secret
- Keycloak config stored in Secret Manager

**DigiLiS (Cloud4Log):**
- `DIGILIS_USERNAME`
- `DIGILIS_PASSWORD`
- `DIGILIS_DOMAIN`

**SMTP (Backend):**
- `SMTP_SERVER`
- `SMTP_PORT`
- `SMTP_USERNAME`
- `SMTP_PASSWORD`

**TOP Service (Backend):**
- `TOP_BASE_URL`
- `XSERVER_URL`

**Azure Service Bus (CrossDock Publisher):**
- Connection string stored in Secret Manager: `asb-topic-connection-string`

## Branch Strategy

### Production Deployments

Components use dedicated release branches for production:
- Backend & Frontend: `release/v2.0`
- TMS Bridge: `release/v2.2.2`
- Cloud4Log: `release/cloud4log/v1.0`
- Dispo Filter (UAT2820): `release/v2.2`

### Test Deployments

All test deployments use the `master` branch for continuous integration.

### Development Environments

Development pipelines typically trigger on feature branches or manual execution.

## AlloyDB Schema Deployment (GitHub Actions)

**Repository:** `Code/tms-alloydb-schema`

**CI/CD Platform:** GitHub Actions (not Azure DevOps)

**Workflows:**

| Workflow | Purpose | Trigger |
|----------|---------|---------|
| `manual_db_schema_create.yml` | Create TMS database schema | Manual |
| `manual_cron_db_schema_create.yml` | Create TMS CRON database | Manual |
| `manual_db_privileges_create.yml` | Create database roles and privileges | Manual |
| `auto_db_schema_create.yml` | Automated schema updates | Automated (on push to main) |
| `manual_file_db_schema_create.yml` | File-based schema creation | Manual |
| `manual_db_schema_build_image.yml` | Build schema deployment image | Manual |

**Key Differences:**
- Uses GitHub Actions instead of Azure DevOps
- Direct execution of SQL scripts against AlloyDB
- Database configuration files in `src/sql/scripts/config/` for WL2 environments
- Separate workflow for schema image building and deployment

## Deployment Scheduling

### Continuous Deployment

- **Test Environment:** Automatic deployment on merge to `master` branch
- **Production Environment:** Manual trigger after testing and approval

### Scheduled Operations

**Cloud4Log:**
- Test upload job: Every 5 minutes (`*/5 * * * *`)
- Test download job: Every 15 minutes (`*/15 * * * *`)
- Production upload job: Every minute (`* * * * *`)
- Production download job: Every 15 minutes (`*/15 * * * *`)

**CDC Processing:**
- Dispo Filter Functions: Event-driven (triggered by Cloud Storage)
- CrossDock Publisher: Event-driven (triggered by Cloud Storage)

## Monitoring and Alerting

Pipeline execution can be monitored through:
- Azure DevOps pipeline dashboards
- GitHub Actions workflow runs (for AlloyDB schema)
- Cloud Run revision history in GCP Console
- Cloud Function execution logs in Cloud Logging

> **Note:** Specific alerting configuration for pipeline failures should be documented separately if implemented.
