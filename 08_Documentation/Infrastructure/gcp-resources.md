# GCP Resources

## Cloud Storage Buckets

### Test Environment

| Bucket Name | Purpose | Used By |
|-------------|---------|---------|
| `tms-alloydb-datastream-bucket-wl5-t-t` | AlloyDB CDC data stream | CrossDock Event Publisher, Dispo Filter |
| `test-cdc-2` | Dev environment CDC bucket | Dispo Filter Function (dev) |
| `c4l-static-files-files-documents-t-t` | Cloud4Log static files and depot configurations | Cloud4Log functions |

### Production Environment

| Bucket Name | Purpose | Used By |
|-------------|---------|---------|
| `c4l-static-files-files-documents-p-p` | Cloud4Log static files and depot configurations | Cloud4Log functions |

### Bucket Variables

These bucket names are referenced as pipeline variables:
- `C4L_BUCKET_POD` - Proof of Delivery bucket (test)
- `C4L_BUCKET_POD_P_P` - Proof of Delivery bucket (production)
- `WL5_CDC_BUCKET_UAT2820` - CDC bucket for UAT2820 environment
- `WL5_CDC_BUCKET_ABN1034` - CDC bucket for ABN1034 environment

## Pub/Sub Topics and Subscriptions

### Topics

Topic names are referenced as pipeline variables:
- `WL5_CDC_TOPIC_UAT2820` - CDC topic for UAT2820 environment
- `WL5_CDC_TOPIC_ABN1034` - CDC topic for ABN1034 environment
- `P3_CDC_TOPIC` - Development environment CDC topic

### Subscriptions

| Subscription Name | Topic | Subscriber | Environment |
|-------------------|-------|------------|-------------|
| `backend-topic-sub` | CDC topics | New Dispo Backend | Test |

Configuration:
- Push subscription model to Backend Cloud Run service

## Databases

### CloudSQL PostgreSQL (New Dispo Backend Database)

**Test Environment:**
- Instance: `cal-new-disposition-psql-t-t`
- Full path: `prj-cal-w-wl4-t-4c48-53ad:europe-west3:cal-new-disposition-psql-t-t`
- Region: europe-west3
- Used by: New Dispo Backend

**Production Environment:**
- Instance: `cal-new-disposition-postgres-p-p`
- Full path: `prj-cal-w-wl4-p-afad-53ad:europe-west3:cal-new-disposition-postgres-p-p`
- Region: europe-west3
- Used by: New Dispo Backend

**Access Method:**
- CloudSQL Proxy configured via `--add-cloudsql-instances` flag in Cloud Run deployment

## Cloud Workflows

### Workflows

| Workflow Name | Trigger | Environment |
|---------------|---------|-------------|
| `c4l-workflow-upload` | Cloud Scheduler (`c4l-upload-job`) | Test, Production |
| `c4l-workflow-download` | Cloud Scheduler (`c4l-download-job`) | Test, Production |
| `c4l-workflow-restore-data` | Manual | Test |

## Cloud Scheduler Jobs

### Test Environment

| Job Name | Schedule | Target |
|----------|----------|--------|
| `c4l-upload-job` | `*/5 * * * *` | `c4l-workflow-upload` |
| `c4l-download-job` | `*/15 * * * *` | `c4l-workflow-download` |

### Production Environment

| Job Name | Schedule | Target |
|----------|----------|--------|
| `c4l-upload-job` | `* * * * *` | `c4l-workflow-upload` |
| `c4l-download-job` | `*/15 * * * *` | `c4l-workflow-download` |

## Secret Manager

### Secrets

| Secret Name | Used By |
|-------------|---------|
| `keyCloakConfig` | CrossDock Event Publisher |
| `serviceAccountKey` | Various components |
| `asb-topic-connection-string` | CrossDock Event Publisher |

## Cloud Run Services

| Service Name | Environment | Project | Workload | Endpoint |
|--------------|-------------|---------|----------|----------|
| `cal-new-disposition-tmsbridge-t-t` | Test | prj-cal-w-wl5-t-6c00-53ad | WL5 | https://test.tms-bridge.gcp.nagel-group.com |
| `cal-new-disposition-tmsbridge-p-p` | Production | prj-cal-w-wl5-p-3e5b-53ad | WL5 | https://tms-bridge.gcp.nagel-group.com |
| `cal-new-disposition-backend-t-t` | Test | prj-cal-w-wl4-t-4c48-53ad | WL4 | https://test.dispo.gcp.nagel-group.com |
| `cal-new-disposition-backend-p-p` | Production | prj-cal-w-wl4-p-afad-53ad | WL4 | https://dispo.gcp.nagel-group.com |
| `cal-new-disposition-frontend-t-t` | Test | prj-cal-w-wl4-t-4c48-53ad | WL4 | https://test.dispo.gcp.nagel-group.com |
| `cal-new-disposition-frontend-p-p` | Production | prj-cal-w-wl4-p-afad-53ad | WL4 | https://dispo.gcp.nagel-group.com |

### Configuration

All Cloud Run services deployed with:
- Region: europe-west3
- Ingress: `internal`
- VPC egress: `all-traffic`
- Memory: 1Gi
- CPU: 1

## Cloud Functions

### Deployed Functions

| Function Name | Environment | Project | Type | Trigger |
|---------------|-------------|---------|------|---------|
| `new-dispo-filter-shipment-records-uat2820` | Test | prj-cal-w-wl5-t-6c00-53ad | Gen2 | Cloud Storage |
| `new-dispo-filter-shipment-records-abn1034` | Test | prj-cal-w-wl5-t-6c00-53ad | Gen2 | Cloud Storage |
| `cloud-4-log-bordero-upload` | Test/Prod | prj-cal-w-wl5-t-6c00-53ad / prj-cal-w-wl5-p-3e5b-53ad | Gen2 | HTTP (via Workflow) |
| `cloud-4-log-rollkart-upload` | Test/Prod | prj-cal-w-wl5-t-6c00-53ad / prj-cal-w-wl5-p-3e5b-53ad | Gen2 | HTTP (via Workflow) |
| `cloud-4-log-download` | Test/Prod | prj-cal-w-wl5-t-6c00-53ad / prj-cal-w-wl5-p-3e5b-53ad | Gen2 | HTTP (via Workflow) |
| `asb-mock-event-publisher-bucket` | Test | prj-cal-w-wl5-t-6c00-53ad | Gen2 | Cloud Storage |

### Cloud4Log Function Configuration

Configuration from pipeline files:
- Runtime: Python 3.x
- Memory: 4Gi
- CPU: 2
- Timeout: 150s
- Max instances: 50
- Concurrency: 10 requests per instance (`maxInstanceRequestConcurrency: 10`)

## IAM Service Accounts

### CI/CD Service Account

- Email: `wl-cicd@prj-cal-w-cicd-wl5-a591-53ad.iam.gserviceaccount.com`
- Purpose: Used by Azure DevOps pipelines for all deployments
- Authentication: Workload Identity Federation (Azure DevOps)

## Artifact Registry

- Registry: `europe-west3-docker.pkg.dev`
- Used for: Container images for Cloud Run services

## Networking

See [Network Configuration](network-configuration.md) for VPC, subnet, and network configuration details.
