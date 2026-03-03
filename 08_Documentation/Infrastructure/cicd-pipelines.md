# CI/CD Pipelines

## Overview

All New Dispo components use Azure DevOps pipelines for CI/CD automation. The pipelines deploy to Google Cloud Platform using Workload Identity Federation for authentication.

## Common Pipeline Configuration

### Authentication

**Method:** Workload Identity Federation (WIF)

**CI/CD Service Account:** `wl-cicd@prj-cal-w-cicd-wl5-a591-53ad.iam.gserviceaccount.com`

**Workload Identity Pools:**
- WL5: `azure-devops` (project number: 534233136072)
- WL4: `azure-devops` (project number: 607166292072)

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

**Dockerfile Configuration:**
- `Dockerfile.cloudrun-t-t` - Test environment
- `Dockerfile.cloudrun-p-p` - Production environment

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

### Dispo Filter Function

**Repository:** `Code/Nagel-GCP/CALConsult.Disposition.Functions`

**Pipelines:**
- `azure-pipelines-cloudrun-t-t-uat2820.yml` - UAT2820 environment (WL5)
- `azure-pipelines-cloudrun-t-t-abn1034.yml` - ABN1034 environment (WL5)
- `azure-pipelines-dev.yml` - Development environment

**Deployment Target:**
- All test deployments: `prj-cal-w-wl5-t-6c00-53ad`

**Environment-Specific Configuration:**
- UAT2820: Branch `release/v2.2`
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
- Cloud Functions: bordero-upload, rollkart-upload, download
- Cloud Workflows: c4l-workflow-upload, c4l-workflow-download, c4l-workflow-restore-data
- Cloud Scheduler jobs for automated execution
- Depot configuration files uploaded to Cloud Storage

### CrossDock Event Publisher

**Repository:** `Code/Nagel-GCP/CrossDockEventPublisher`

**Pipelines:**
- `azure-pipelines-cloudrun-t-t.yml` - Test deployment (WL5)
- `azure-pipelines-dev.yml` - Development environment

**Deployment Target:**
- Test: `prj-cal-w-wl5-t-6c00-53ad`

**Deployment Status:**
- Production pipeline does not exist

## Pipeline Variables

### Project IDs

**WL4:**
- `WL4_PROJECT_T_T` - Test project ID
- `WL4_PROJECT_P_P` - Production project ID

**WL5:**
- `WL5_PROJECT_T_T` - Test project ID
- `WL5_PROJECT_P_P` - Production project ID

### Network Configuration

- `VPC_CONNECTOR` - VPC connector name
- `VPC_PROJECT` - Shared VPC project ID
- `SUBNET` - Subnet for Cloud Run services

### Database

- `CLOUDSQL_INSTANCE` - CloudSQL instance connection string (Backend)

### Pub/Sub

- `WL5_CDC_TOPIC_UAT2820` - CDC topic for UAT2820
- `WL5_CDC_TOPIC_ABN1034` - CDC topic for ABN1034
- `WL5_CDC_BUCKET_UAT2820` - CDC bucket for UAT2820
- `WL5_CDC_BUCKET_ABN1034` - CDC bucket for ABN1034

### Cloud4Log

- `C4L_BUCKET_POD` - Proof of Delivery bucket (test)
- `C4L_BUCKET_POD_P_P` - Proof of Delivery bucket (production)
- `C4L_STATIC_FILES_P_P` - Static files bucket (production)

### Keycloak

- `KEYCLOAK_CLIENT_SECRET` - Backend client secret
- Secret Manager: `keyCloakConfig`

### DigiLiS

- `DIGILIS_USERNAME`
- `DIGILIS_PASSWORD`
- `DIGILIS_DOMAIN`

### TOP Service

- `TOP_BASE_URL`
- `XSERVER_URL`

### Azure Service Bus

- Secret Manager: `asb-topic-connection-string`

## Branch Strategy

### Production Deployments

- **Backend & Frontend:** `release/v2.0`
- **TMS Bridge:** `release/v2.2.2`
- **Cloud4Log:** `release/cloud4log/v1.0`
- **Dispo Filter (UAT2820):** `release/v2.2`

### Test Deployments

All test deployments use the `master` branch.

## Deployment Scheduling

### Continuous Deployment

- **Test Environment:** Automatic deployment on merge to `master` branch
- **Production Environment:** Manual trigger

### Cloud4Log Scheduled Operations

**Cloud Scheduler Jobs:**

**Production:**
- `c4l-upload-job`: Schedule `* * * * *` (every minute)
- `c4l-download-job`: Schedule `*/15 * * * *` (every 15 minutes)

**Test:**
- `c4l-upload-job`: Schedule `*/5 * * * *` (every 5 minutes)
- `c4l-download-job`: Schedule `*/15 * * * *` (every 15 minutes)

### CDC Processing

- Dispo Filter Functions: Event-driven (triggered by Cloud Storage)
- CrossDock Publisher: Event-driven (triggered by Cloud Storage)

## Monitoring

Pipeline execution can be monitored through:
- Azure DevOps pipeline dashboards
- Cloud Run revision history in GCP Console
- Cloud Function execution logs in Cloud Logging
