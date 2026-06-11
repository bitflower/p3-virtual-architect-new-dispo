# Azure DevOps Pipelines as GCP Provisioning Mechanism

**Date:** 2026-06-11
**Status:** Exploration Complete

---

## Original User Input

> My GCloud account does not have the permission to create and provision components. However, I have the rights to create pipelines in our Azure repository where all the pipelines live. Could I create components this way by preparing a pipeline and then asking our DevOps engineer to run it?

---

## Summary

Yes — this is already the established pattern in the project. Azure DevOps pipelines authenticate to GCP via **Workload Identity Federation** and execute `gcloud` CLI commands to provision and manage GCP resources. Multiple "permissions" and "infrastructure" pipelines already exist that follow exactly this workflow: write the YAML, push it, have someone with run rights trigger it.

## How It Works

### Authentication: Workload Identity Federation

All pipelines authenticate to GCP without personal credentials. The flow is:

1. Azure DevOps pipeline starts and runs an `AzureCLI@2` task
2. The task uses the `google-cloud` service connection (`connectedServiceNameARM`) to obtain an identity token (`$idToken`)
3. The token is written to a JWT file, and a GCP external account credential config is generated
4. `gcloud auth login --cred-file=...` authenticates the pipeline as a GCP service account
5. Subsequent `gcloud` commands run with that service account's permissions

### Service Accounts (CI/CD)

Two Workload Identity setups exist, one per workload project:

| Workload | Service Account | Project Number | Pool/Provider |
|----------|----------------|----------------|---------------|
| **WL4** (New Dispo) | `wl-cicd@prj-cal-w-cicd-wl4-a1bc-53ad.iam.gserviceaccount.com` | 607166292072 | `azure-devops` / `p3-azure-devops` |
| **WL5** (Cloud4Log) | `wl-cicd@prj-cal-w-cicd-wl5-a591-53ad.iam.gserviceaccount.com` | 534233136072 | `azure-devops` / `p3-azure-devops` |

### Credential Config Template (used in every pipeline)

```json
{
  "type": "external_account",
  "audience": "//iam.googleapis.com/projects/<PROJECT_NUMBER>/locations/global/workloadIdentityPools/azure-devops/providers/p3-azure-devops",
  "subject_token_type": "urn:ietf:params:oauth:token-type:jwt",
  "token_url": "https://sts.googleapis.com/v1/token",
  "credential_source": {
    "file": "<path-to-jwt-file>"
  },
  "service_account_impersonation_url": "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/<SERVICE_ACCOUNT>:generateAccessToken"
}
```

## Existing Pipelines Inventory

### Azure DevOps Configuration

- **Organization:** `https://dev.azure.com/p3ds`
- **Project:** `Nagel-CAL Disposition`
- **Total pipelines:** 47
- **Default queue:** Azure Pipelines (ubuntu-latest)

### Pipeline Categories

#### Application Deployment Pipelines (CI/CD)

These trigger on branch pushes and deploy application code:

| Pipeline | ID | Repository | YAML Path | Trigger |
|----------|-----|------------|-----------|---------|
| cal-new-dispo-backend-develop | 1818 | Disposition-Backend | (CI/CD YAML) | Branch push |
| cal-new-dispo-frontend-develop | 1820 | Disposition-Frontend | (CI/CD YAML) | Branch push |
| cal-new-dispo-tms-bridge-develop | 1882 | Disposition-Abstraction-Layer | (CI/CD YAML) | Branch push |
| cal-new-dispo-backend-staging | 1834 | Disposition-Backend | (CI/CD YAML) | Branch push |
| cal-new-dispo-frontend-staging | 1835 | Disposition-Frontend | (CI/CD YAML) | Branch push |
| cal-new-dispo-tms-bridge-staging | 1998 | Disposition-Abstraction-Layer | (CI/CD YAML) | Branch push |
| cal-new-dispo-backend-t-t-cloudrun | 1932 | Disposition-Backend | (CI/CD YAML) | Branch push |
| cal-new-dispo-frontend-t-t-cloudrun | 1933 | Disposition-Frontend | (CI/CD YAML) | Branch push |
| cal-new-dispo-tms-bridge-t-t-cloudrun | 2003 | Disposition-Abstraction-Layer | (CI/CD YAML) | Branch push |
| cal-new-dispo-backend-p-p-cloudrun | 1923 | Disposition-Backend | (CI/CD YAML) | Branch push |
| cal-new-dispo-frontend-p-p-cloudrun | 1928 | Disposition-Frontend | (CI/CD YAML) | Branch push |
| cal-new-dispo-tms-bridge-p-p-cloudrun | 2020 | Disposition-Abstraction-Layer | (CI/CD YAML) | Branch push |
| cal-new-dispo-keycloak-p-p-cloudrun | 1917 | (Keycloak) | (CI/CD YAML) | Branch push |
| cloud-4-log-t-t-cloudrun | 2153 | Nagel-GCP | Cloud4Log/devops/azure-pipelines-cloudrun-t-t.yml | master branch |
| cloud-4-log-p-p-cloudrun | 2216 | Nagel-GCP | (CI/CD YAML) | Branch push |

#### Permissions / Infrastructure Pipelines (Manual Trigger)

These are the relevant "provisioning-by-pipeline" precedents — `trigger: none`, run manually:

| Pipeline | ID | Repository | YAML Path |
|----------|-----|------------|-----------|
| **cal-new-dispo-nagel-gcp-permissions** | 1947 | Disposition-Backend | `azure-pipelines-cloudrun-perms.yml` |
| **wl5-permissions** | 2050 | Disposition-Abstraction-Layer | `azure-pipelines-cloudrun-perms.yml` |
| **cloud-4-log-d-d-gcp-permissions** | 2256 | Nagel-GCP | `Cloud4Log/devops/azure-pipelines-cloudrun-perms.yml` |
| **cloud-4-log-infrastrusture-deploy** | 2281 | Nagel-GCP | `Cloud4Log/devops/azure-pipelines-infra.yml` |

#### UAT / Environment-Specific Pipelines

| Pipeline | ID |
|----------|----|
| cal-new-dispo-frontend-t-t-cloudrun-uat | 2325 |
| cal-new-dispo-backend-t-t-cloudrun-uat | 2326 |
| cal-new-dispo-keycloak-t-t-cloudrun-uat | 2327 |
| cal-new-dispo-tms-bridge-t-t-cloudrun-uat | 2328 |
| cal-new-dispo-frontend-d-d-cloudrun | 2330 |
| cal-new-dispo-backend-d-d-cloudrun | 2331 |
| tms-bridge-cloudrun-d-d-cloudrun | 2317 |
| cal-new-dispo-keycloak-d-d-cloudrun | 2320 |
| cloud-4-log-d-d-cloudrun | 2316 |

## What Is Already Being Provisioned via Pipelines

The Cloud4Log T-T pipeline (`azure-pipelines-cloudrun-t-t.yml`) is the most comprehensive example, provisioning:

### Cloud Run Services
```bash
gcloud run deploy <service-name> \
  --image <image> --project <PROJECT_ID> --region europe-west3 \
  --network <shared-vpc> --subnet <subnet> \
  --ingress internal --vpc-egress all-traffic \
  --network-tags <tags> --memory 4Gi --cpu 2
```

### Cloud Functions (Gen2)
```bash
gcloud functions deploy <function-name> \
  --gen2 --project <PROJECT_ID> --source <path> \
  --entry-point <dotnet-class> --runtime dotnet8 \
  --build-service-account=<sa> --trigger-http \
  --service-account=<sa> --set-env-vars <vars> \
  --region europe-west3
```

### GCP Workflows
```bash
gcloud workflows deploy <workflow-name> \
  --project <PROJECT_ID> --source <yaml-path> \
  --service-account=<sa> --location europe-west3
```

### Cloud Scheduler Jobs (idempotent create-or-update pattern)
```bash
gcloud scheduler jobs describe <job-name> ... >/dev/null 2>&1 \
  && (gcloud scheduler jobs update http <job-name> ...) \
  || (gcloud scheduler jobs create http <job-name> ...)
```

### IAM Bindings
```bash
gcloud projects add-iam-policy-binding <PROJECT_ID> \
  --member="user:<email>" --role="roles/<role>"
```

### API Enablement
```bash
gcloud services enable <api>.googleapis.com --project <PROJECT_ID>
```

## GCP Project IDs

Referenced across the pipeline YAML files:

| Environment | Project ID | Shared VPC Project |
|-------------|-----------|-------------------|
| Test (T-T) | `prj-cal-w-wl4-t-4c48-53ad` | `prj-cal-net-s-t-e004-53ad` |
| Prod (P-P) | `prj-cal-w-wl4-p-afad-53ad` | `prj-cal-net-s-p-19c3-53ad` |
| WL5 Test | Variable: `$(PROJECT_ID_WL5_T_T)` → `prj-cal-w-wl5-t-6c00-53ad` | Same shared VPC as WL4 T-T |

## How to Use This Approach

### Option 1: Modify an Existing Perms Pipeline

1. Edit the `azure-pipelines-cloudrun-perms.yml` in the relevant repo
2. Uncomment or add new `gcloud` commands
3. Push the change
4. Ask the DevOps engineer to run the pipeline

This is the pattern used historically — the perms YAML files contain many commented-out commands as a log of previous provisioning operations.

### Option 2: Create a New Pipeline YAML

1. Write a new YAML file in the target repo (e.g. `azure-pipelines-provision-<component>.yml`)
2. Use `trigger: none` (manual only)
3. Copy the Workload Identity auth block from an existing perms pipeline
4. Add your `gcloud` provisioning commands
5. Push to the repo
6. Ask the DevOps engineer to create a new Azure DevOps pipeline pointing to the YAML file:
   ```bash
   az pipelines create --name "<pipeline-name>" --yml-path "<path-to-yaml>" --repository "<repo-name>" --repository-type tfsgit
   ```
7. Then trigger it

### Prerequisite Check

Before asking for a run, verify with the DevOps engineer:
- Does the CI/CD service account (WL4 or WL5) have IAM permissions for the resource type you want to create?
- If not, they need to grant those permissions first (this itself can be done via the perms pipeline if they have access)

## Findings

1. **The pattern is already established** — this is not a workaround, it's how the team operates
2. **Two auth contexts exist** (WL4 / WL5) — choose based on which GCP project you're targeting
3. **Perms pipelines serve as audit logs** — commented-out commands document what was provisioned when
4. **All GCP resource types are covered** — Cloud Run, Cloud Functions, Workflows, Scheduler, IAM, APIs have all been provisioned this way
5. **The `google-cloud` Azure service connection** is the single trust anchor between Azure DevOps and GCP
6. **Variable groups** (`Nagel-Disposition`, `Cloud4Log`) and **Secure Files** store environment-specific config and secrets

## Questions/Open Items

- Which specific GCP component do you want to provision? (Cloud Function, Cloud Run service, Pub/Sub topic, etc.)
- Which GCP project/environment is the target? (determines WL4 vs WL5 and project ID)
- Does the CI/CD service account already have IAM roles for that resource type?
