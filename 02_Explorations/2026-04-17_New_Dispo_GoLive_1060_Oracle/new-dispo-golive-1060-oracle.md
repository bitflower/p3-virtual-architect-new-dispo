# New Dispo GoLive 1060 (Oracle)

**Date:** 2026-05-19
**Status:** Active
**Purpose:** Holistic overview to align all stakeholders on the architecture, infrastructure, environments, and ownership for Branch 1060 on Oracle.

---

## 1. End-to-End Environment Landscape

This section maps every environment stage across both the GCP (New Dispo) side and the Oracle (TMS) side.

### 1.1 Environment Pipeline Overview

```
               GCP (New Dispo)                         Oracle (TMS)
          ========================              ========================

         +----------------------------+        +----------------------------+
 LOCAL   | Developer Workstation      |        | --                         |
         | (Docker, localhost)        |        |                            |
         +----------------------------+        +----------------------------+

         +----------------------------+        +----------------------------+
 DEV     | WL4-T-T (virtual env)      |        | ENT1                       |
         | WL5-DEV                    |        | (schema dev, unit testing) |
         | (development, feature      |        |                            |
         |  testing)                  |        |                            |
         | Note: WL4-DEV does not     |        |                            |
         |  exist — see ADR-008       |        |                            |
         +-------------+--------------+        +-------------+--------------+
                       |                                      |
                       v                                      v
         +----------------------------+        +----------------------------+
 ABN     | WL4-T-T (virtual env)      |        | ORA-ABN-1060               |
         | WL5-T-T                    |        | (acceptance, live prod     |
         | (integration, E2E)         |        |  data)                     |
         +-------------+--------------+        +-------------+--------------+
                       |                                      |
                       v                                      v
         +----------------------------+        +----------------------------+
 UAT     | WL4-T-T (virtual env)      |        | ORA-UAT-1060               |
         | WL5-T-T                    |        | (customer acceptance)      |
         | (dedicated TMS connection) |        |                            |
         +-------------+--------------+        +-------------+--------------+
                       |                                      |
                       v                                      v
         +----------------------------+        +----------------------------+
 PROD    | WL4-P-P / WL5-P-P          |        | PROD                       |
         | (production)               |        | (production)               |
         +----------------------------+        +----------------------------+
```

### 1.2 Environment Mapping Matrix

| Stage     | GCP Project (WL4)                       | GCP Project (WL5)           | Oracle Instance  | Data Profile                | Sign-Off                 |
| --------- | --------------------------------------- | --------------------------- | ---------------- | --------------------------- | ------------------------ |
| **LOCAL** | --                                      | --                          | --               | Seeded / empty              | Developer                |
| **DEV**   | WL4-T-T (virtual env, see ADR-008)      | WL5-DEV (TBD)               | ENT1 (shared)    | Schema only, no branch data | Developer                |
| **ABN**   | WL4-T-T (virtual env)                   | `prj-cal-w-wl5-t-6c00-53ad` | **ORA-ABN-1060** | Live production data (1060) | Patrick U., Max K. (P3)  |
| **UAT**   | WL4-T-T (virtual env)                   | `prj-cal-w-wl5-t-6c00-53ad` | **ORA-UAT-1060** | Production data             | Max Beisheim, Patrick U. |
| **PROD**  | `prj-cal-w-wl4-p-afad-53ad`             | `prj-cal-w-wl5-p-3e5b-53ad` | PROD             | Production                  | --                       |

All three non-prod stages (DEV, ABN, UAT) share the same WL4 GCP project `prj-cal-w-wl4-t-4c48-53ad` as virtual environments (see Section 1.3).

### 1.3 Virtual Environments within WL4-T-T (Target Picture)

Because WL4-DEV does not exist (see ADR-008), the WL4-T-T GCP project hosts three **virtual environments** — DEV, ABN, and UAT — each with its own set of Cloud Run services, Keycloak configuration, and Oracle database connection.

**Constraint:** GCP Secret Manager is scoped per project. A single project cannot hold two secrets with the same name. Since all three virtual environments share `prj-cal-w-wl4-t-4c48-53ad`, database secrets must be differentiated via environment-qualified identifiers (see ADR-009).

**Solution:** Credential routing via prefixed database identifiers. Each virtual environment resolves to its own Secret Manager entry, e.g., `dispo-abn-O-10-60` and `dispo-uat-O-10-60`.

```
WL4-T-T (prj-cal-w-wl4-t-4c48-53ad)
┌─────────────────────────────────────────────────────────────────────────┐
│                          Secret Manager (shared)                        │
│                          ┌───────────────────┐                          │
│                          │ dispo-dev-O-10-60  │                          │
│                          │ dispo-abn-O-10-60  │                          │
│                          │ dispo-uat-O-10-60  │                          │
│                          └───────────────────┘                          │
│                                                                         │
│  ┌─────────────────────┐ ┌─────────────────────┐ ┌───────────────────┐  │
│  │  DEV  (Prio 3)      │ │  ABN  (Prio 1)      │ │  UAT  (Prio 2)   │  │
│  │                     │ │                     │ │                   │  │
│  │  Keycloak           │ │  Keycloak           │ │  Keycloak         │  │
│  │  Frontend           │ │  Frontend           │ │  Frontend         │  │
│  │  Backend            │ │  Backend            │ │  Backend          │  │
│  │                     │ │                     │ │                   │  │
│  │  → dispo-dev-O-10-60│ │  → dispo-abn-O-10-60│ │  → dispo-uat-O-…  │  │
│  └─────────────────────┘ └─────────────────────┘ └───────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

**Priority ordering** (resource and scheduling conflicts):

| Priority | Virtual Env | Purpose                    | Status     |
| -------- | ----------- | -------------------------- | ---------- |
| **1**    | ABN         | Acceptance with live data  | Next step  |
| **2**    | UAT         | Customer acceptance        | After ABN sign-off |
| **3**    | DEV         | Development / feature testing | Lowest priority |

**Implications:**
- Each virtual environment requires its own CI/CD pipeline (separate deployments per environment)
- Secret Manager entries are namespaced via the credential routing prefix (ADR-009)
- A single Secret Manager instance is shared across all virtual environments — no duplication possible
- Cloud Run service names must include an environment suffix (e.g., `cal-new-disposition-backend-t-t-abn`)

---

## 2. Architecture Overview

### 2.1 GCP Workload Separation

| Workload    | Purpose            | Components                                     | GCP Project (Test)                                              | GCP Project (Prod)          |
| ----------- | ------------------ | ---------------------------------------------- | --------------------------------------------------------------- | --------------------------- |
| **WL4**     | User-Facing App    | Frontend, Backend, CloudSQL                    | `prj-cal-w-wl4-t-4c48-53ad`                                     | `prj-cal-w-wl4-p-afad-53ad` |
| **WL5**     | Integration & Data | TMS Bridge, Cloud4Log, Dispo Filter, CrossDock | `prj-cal-w-wl5-t-6c00-53ad`                                     | `prj-cal-w-wl5-p-3e5b-53ad` |
| **Network** | Shared VPC         | VPN, Routing, Firewall                         | `prj-cal-net-s-t-e004-53ad`                                     | `prj-cal-net-s-p-19c3-53ad` |
| **CI/CD**   | Deployment         | Workload Identity, Pipelines                   | `prj-cal-w-cicd-wl4-a1bc-53ad` / `prj-cal-w-cicd-wl5-a591-53ad` | (same)                      |

> **Virtual environments:** The WL4 and WL5 test projects each host three virtual environments (DEV, ABN, UAT). Every component listed above is deployed as a separate Cloud Run service per environment, with an environment suffix in the service name (see Section 1.3). Section 3 lists all individual deployments.

---

## 3. GCP Components by Environment

### 3.1 Cloud Run Services

Each virtual environment requires its own Cloud Run deployment (see Section 1.3). Service names follow the convention `cal-new-disposition-{component}-{project}-{env}`.

| Service    | Workload | Env  | Cloud Run Service Name                         | URL                                              | Status   |
| ---------- | -------- | ---- | ---------------------------------------------- | ------------------------------------------------ | -------- |
| Frontend   | WL4      | DEV  | `cal-new-disposition-frontend-t-t-dev`         | `https://dev-dispo.gcp.nagel-group.com`| existing |
| Frontend   | WL4      | ABN  | `cal-new-disposition-frontend-t-t-abn`         | `https://test.dispo.gcp.nagel-group.com`                                              | existing |
| Frontend   | WL4      | UAT  | `cal-new-disposition-frontend-t-t-uat`         | `https://uat-dispo.gcp.nagel-group.com`                                              | existing |
| Frontend   | WL4      | PROD | `cal-new-disposition-frontend-p-p`             | `https://dispo.gcp.nagel-group.com`              | existing |
| Backend    | WL4      | DEV  | `cal-new-disposition-backend-t-t-dev`          | `https://dev-dispo.gcp.nagel-group.com`| existing |
| Backend    | WL4      | ABN  | `cal-new-disposition-backend-t-t-abn`          | `https://test.dispo.gcp.nagel-group.com`| existing |
| Backend    | WL4      | UAT  | `cal-new-disposition-backend-t-t-uat`          | `https://uat-dispo.gcp.nagel-group.com`| existing |
| Backend    | WL4      | PROD | `cal-new-disposition-backend-p-p`              | `https://dispo.gcp.nagel-group.com`              | existing |
| TMS Bridge | WL5      | DEV  | `cal-new-disposition-tmsbridge-d-d-dev`        | `https://dev-tms-bridge.gcp.nagel-group.com`| existing |
| TMS Bridge | WL5      | ABN  | `cal-new-disposition-tmsbridge-t-t-abn`        | `https://test.tms-bridge.gcp.nagel-group.com`                                              | existing |
| TMS Bridge | WL5      | UAT  | `cal-new-disposition-tmsbridge-t-t-uat`        | `https://uat-tms-bridge.gcp.nagel-group.com`                                              | existing |
| TMS Bridge | WL5      | PROD | `cal-new-disposition-tmsbridge-p-p`            | `https://tms-bridge.gcp.nagel-group.com`         | existing |

### 3.2 Cloud Functions (Gen2)

No DEV instance needed — ENT1 is schema-only without CDC pipeline.

| Function     | Workload | Trigger       | Env  | Instance Name                                  | Config | Status |
| ------------ | -------- | ------------- | ---- | ---------------------------------------------- | ------ | ------ |
| Dispo Filter | WL5      | Cloud Storage | ABN  | `new-dispo-filter-shipment-records-abn1060`    | Python | done|
| Dispo Filter | WL5      | Cloud Storage | UAT  | `new-dispo-filter-shipment-records-uat1060`    | Python | done|
| Dispo Filter | WL5      | Cloud Storage | PROD | `new-dispo-filter-shipment-records-1060`       | Python | PR created|

### 3.3 Databases

Each virtual environment's Backend requires its own CloudSQL database for isolation (see Section 1.3). All virtual environments share the WL4-T-T CloudSQL instance; database-level separation is TBD.

| Database             | Type                | Env  | CloudSQL Instance                      | Database Name | Status   |
| -------------------- | ------------------- | ---- | -------------------------------------- | ------------- | -------- |
| New Dispo Backend DB | CloudSQL PostgreSQL | DEV  | `cal-new-disposition-psql-d-d`         | TBD           | TBD      |
| New Dispo Backend DB | CloudSQL PostgreSQL | ABN  | `cal-new-disposition-psql-t-t`         | cal-new-dispo| existing|
| New Dispo Backend DB | CloudSQL PostgreSQL | UAT  | `cal-new-disposition-psql-t-t`         | cal-new-dispo-uat| existing|
| New Dispo Backend DB | CloudSQL PostgreSQL | PROD | `cal-new-disposition-postgres-p-p`     | cal-new-dispo| existing |

### 3.4 Azure Service Bus

| Stage | ASB Namespace | Queue | Status |
| ----- | ------------- | ----- | ------ |
| ABN   | Endpoint=sb://sb-calsuite-tst.servicebus.windows.net/| newdispo_to_lobster   | done    |
| UAT   | Endpoint=sb://sb-calsuite-tst.servicebus.windows.net/| newdispo_to_lobster   | TBD    |
| PROD  | TBD           | newdispo_to_calsuite   | TBD    |

**Purpose:** Outbound EDI messages (invoice/shipment distribution) via AMQP/TLS.

**Connection String Source:**
- Backend: `EdiSettings.ConnectionString` in appsettings

### 3.5 Secret Manager

Secret names follow the credential routing convention from ADR-009: `{SYSTEM}-{ENV}-{DBMS}-{COMPANY}-{BRANCH}`. All virtual environments within a GCP project share one Secret Manager instance, so the environment prefix is required for disambiguation.

| Secret Name              | GCP Project | Env  | Purpose                          | Injected Into | Status                   |
| ------------------------ | ----------- | ---- | -------------------------------- | ------------- | ------------------------ |
| `dispo-dev-O-10-60`     | WL4-T-T     | DEV  | Oracle connection (ENT1)         | TMS Bridge    | TBD                      |
| `dispo-O-10-60`     | WL4-T-T     | ABN  | Oracle connection (ORA-ABN-1060) | TMS Bridge    | done|
| `dispo-uat-O-10-60`     | WL4-T-T     | UAT  | Oracle connection (ORA-UAT-1060) | TMS Bridge    | done (2026-06-17)|
| `dispo-abn-O-10-60`     | WL5-T-T     | ABN  | Oracle connection (ORA-ABN-1060) | TMS Bridge    | done (2026-05-01)        |
| `dispo-uat-O-10-60`     | WL5-T-T     | UAT  | Oracle connection (ORA-UAT-1060) | TMS Bridge    | done (2026-06-17)                      |
| `O-10-60`               | WL5-P-P     | PROD | Oracle connection (PROD)         | TMS Bridge    | TBD                      |

### 3.6 Cloud Storage Buckets

| Bucket                   | GCP Project | Stage | Purpose                | Status |
| ------------------------ | ----------- | ----- | ---------------------- | ------ |
| `wl5-cdc-bucket-abn1060` | WL5-T-T     | ABN   | CDC bucket for ABN1060 | done   |
| `tms-alloydb-datastream-bucket-wl5-t-t` | WL5-T-T     | UAT   | CDC bucket for UAT1060 | done   |
| `wl5-cdc-bucket-1060`    | WL5-P-P     | PROD  | CDC bucket for 1060    | done   |

### 3.7 Pub/Sub

| Resource                | GCP Project | Stage | Purpose                | Status |
| ----------------------- | ----------- | ----- | ---------------------- | ------ |
| `WL5_CDC_TOPIC_ABN1060` | WL5-T-T     | ABN   | CDC events for ABN1060 | TBD    |
| `uat1060-sendung-topic-ordered` | WL5-T-T     | UAT   | CDC events for UAT1060 | done|
| `uat1060-sendung-topic-ordered`    | WL5-P-P     | PROD  | CDC events for 1060    | done|

### 3.8 Networking

| Resource            | Test                                   | Prod                                   | Status            |
| ------------------- | -------------------------------------- | -------------------------------------- | ----------------- |
| Shared VPC          | `vpc-c-shared-vpc-c-net-s-t`           | `vpc-c-shared-vpc-c-net-s-p`           | * to be confirmed |
| Subnet              | `sn-vpc-c-net-s-t-europe-west3-common` | `sn-vpc-c-net-s-p-europe-west3-common` | * to be confirmed |
| Hub VPC Project     | `prj-cal-net-h-5332-53ad`              | `prj-cal-net-h-5332-53ad`              | * to be confirmed |
| CAL VPN Endpoints   | `34.157.54.59`, `34.157.191.34`        | (same hub)                             | * to be confirmed |
| Nagel VPN Endpoints | `35.242.18.84`, `34.157.189.239`       | (same hub)                             | * to be confirmed |

### 3.9 Keycloak Servers

Each virtual environment requires its own Keycloak instance or realm (see Section 1.3).

| Env   | Keycloak URL                                      | Status   |
| ----- | ------------------------------------------------- | -------- |
| LOCAL | `http://localhost:8080`                           | existing |
| DEV   | `https://dev-dispo.gcp.nagel-group.com/keycloak`| done|
| ABN   | `https://test.dispo.gcp.nagel-group.com/keycloak`| done|
| UAT   | `https://uat-dispo.gcp.nagel-group.com/keycloak`| done|
| PROD  | `https://dispo.gcp.nagel-group.com/keycloak`      | existing |

### 3.10 Entra ID

**Owner:** Nagel

| Env      | Status              | Notes                        |
| -------- | ------------------- | ---------------------------- |
| **ABN**  | done                | Set up and working           |
| **UAT**  | not set up          |                              |
| **PROD** | unknown             | To be verified               |

### 3.11 TOP Service

**Owner:** Nagel

| Env      | Status              | URL                          | Notes                        |
| -------- | ------------------- | ---------------------------- | ---------------------------- |
| **ABN**  | done                | Nikolay to provide           | Connected and working        |
| **UAT**  | done                | Nikolay to provide           | Connected and working        |
| **PROD** | pending             | `https://top.elogsvc.nagel-group.local/` | Pending confirmation (URL and further config) |

---

## 4. Security - Users & Service Accounts

### 4.1 Authentication Patterns by Context

| Context                       | Method                           | Identity Provider                     | Status           |
| ----------------------------- | -------------------------------- | ------------------------------------- | ---------------- |
| User login (Browser)          | OAuth2 Authorization Code + PKCE | Keycloak                              | * to be verified |
| Service-to-Service (Cloud)    | Client Credentials (OAuth2)      | Keycloak                              | * to be verified |
| CI/CD Pipeline                | Workload Identity Federation     | GCP IAM (Azure DevOps token exchange) | * to be verified |
| Cloud Run <-> CloudSQL        | CloudSQL Proxy + IAM             | GCP IAM                               | * to be verified |
| Cloud Functions <-> Resources | GCP Service Account              | GCP IAM                               | * to be verified |
| Local Development             | Username/Password                | Local Keycloak + local Postgres       | * to be verified |

### 4.2 Keycloak Clients

| Client ID                 | Type                    | Used By                | Environment        | Status           |
| ------------------------- | ----------------------- | ---------------------- | ------------------ | ---------------- |
| `cal-client`              | User-facing (Auth Code) | Frontend + Backend     | Production         | * to be verified |
| `ebv-client`              | User-facing             | Legacy EBV integration | Production         | * to be verified |
| `client-credentials-test` | Machine-to-Machine      | Service accounts       | Test               | * to be verified |
| `cloud-run-client`        | Machine-to-Machine      | Cloud Run functions    | Cloud environments | * to be verified |
| `tms-cloud-service`       | Machine-to-Machine      | TMS Bridge             | Cloud environments | * to be verified |
| `tmsng-client`            | Machine-to-Machine      | ?????                  | Test               | * to be verified |
| `driverapp-client`        | Machine-to-Machine      | ?????                  | Test               | * to be verified |

### 4.3 GCP Service Accounts

| Service Account                                                  | Scope            | Purpose                                                             | Status            |
| ---------------------------------------------------------------- | ---------------- | ------------------------------------------------------------------- | ----------------- |
| `wl-cicd@prj-cal-w-cicd-wl4-a1bc-53ad.iam.gserviceaccount.com`   | WL4 CI/CD        | Azure DevOps (P3) pipeline deployments (Frontend, Backend)          | * to be confirmed |
| `wl-cicd@prj-cal-w-cicd-wl5-a591-53ad.iam.gserviceaccount.com`   | WL5 CI/CD        | Azure DevOps (P3) pipeline deployments (TMS Bridge, Cloud4Log, CDC) | * to be confirmed |
| `wl5-cloudrun@prj-cal-w-wl5-t-6c00-53ad.iam.gserviceaccount.com` | WL5 Test Runtime | Cloud Run + Workflow execution (Test)                               | * to be confirmed |
| `wl5-cloudrun@prj-cal-w-wl5-p-3e5b-53ad.iam.gserviceaccount.com` | WL5 Prod Runtime | Cloud Run + Workflow execution (Prod)                               | * to be confirmed |

**Workload Identity Pools (Azure DevOps Federation):**
- WL4: `azure-devops` (project number: 607166292072)
- WL5: `azure-devops` (project number: 534233136072)

### 4.4 Database Users

| Database      | TMS Bridge  | Status Bridge                    | TMS Pulse | Status Pulse |
| ------------- | ----------- | -------------------------------- | --------- | ------------ |
| ENT1          | TBD         | --                               | TBD       | --           |
| ORA-ABN-1060  | `TMSBR1060` | Connected                        | TBD       | --           |
| ORA-UAT-1060  | `TMSBR1060` | Connected                        | TBD       | --           |
| ORA-PROD-1060 | `TMSBR1060` | Pending: after UAT sign-off      | TBD       | --           |

The exact permission scope required by the `TMSBR*` user (tables, views, functions, procedures) is defined in the [TMS Bridge Database Objects](02_Explorations/2026-04-29_TMS_Bridge_Database_Object_Inventory/tms-bridge-db-permission-scope.md) inventory.

**Database Identifier Convention (ADR-004):**
Format: `{DBMS}-{COUNTRY}-{COMPANY}-{BRANCH}` (e.g., `O-D-10-60` for Oracle Germany Company 10 Branch 60)
\* to be discussed in scope

---

## 5. External Integrations

| System                | Protocol          | Purpose                        | Connected From                | Owner       |
| --------------------- | ----------------- | ------------------------------ | ----------------------------- | ----------- |
| **Keycloak**          | HTTPS (OIDC)      | Authentication & Authorization | Frontend, Backend, TMS Bridge | P3          |
| **Entra ID**          | HTTPS (OIDC)      | Identity Provider (upstream)   | Keycloak                      | Nagel       |
| **Azure Service Bus** | AMQP/TLS          | Event publishing for CALSuite  | New Dispo                     | CAL         |
| **TOP Service**       | HTTP              | Route optimization             | Backend (on-prem)             | Nagel       |
| **xServer**           | HTTP              | Routing calculations           | TOP Service                   | Nagel       |
| **Microsoft Graph**   | HTTPS (Graph API) | Email notifications            | Backend                       | P3          |
| **Timocom**           | REST API          | Freight exchange               | Backend                       | External    |
| **Trans.eu**          | REST API (OAuth2) | Freight exchange               | Backend                       | External    |

---

## 6. Ownership & Responsibility Matrix (WIP)

### 6.1 Go-Live 1060 -- Who Does What

| #   | Task                                                | Owner                                   | Support | Status        | Blocked by | Waiting on | Notes                                          |
| --- | --------------------------------------------------- | --------------------------------------- | ------- | ------------- | ---------- | ---------- | ---------------------------------------------- |
| 1   | **Oracle ENT1 schema development**                  | Joachim Schreiner (Nagel)               | --      | Active        | --         | --         | Wrapper procedures for 1060                    |
| 2   | **Provision ORA-ABN-1060**                          | Bernd Friedewald, Thomas Paulus (Nagel) | Joachim | ✅ Done       | --         | --         | DB objects deployed by Eric (2026-05-01)       |
| 3   | **Provision ORA-UAT-1060**                          | Bernd Friedewald, Thomas Paulus (Nagel) | Joachim | ✅ Done       | --         | --         | Provisioned                                    |
| 4   | **Oracle deployment pipeline (QS tool)**            | Joachim Schreiner (Nagel)               | --      | Operational   | --         | --         | ENT -> ABN -> UAT -> PROD                      |
| 5   | **ORA-ABN-1060 connection details**                 | Joachim Schreiner (Nagel)               | --      | ✅ Done       | --         | --         | TMSBR1060 user provisioned by Eric (2026-05-01) |
| 6   | **TMS Bridge config for ORA-ABN-1060**              | P3 (Matthias, Max K.)                   | Joachim | ✅ Done       | --         | --         | Connected to ABN + UAT on TMS Bridge and Backend |
| 7   | **Backend ABN env config for Oracle**               | P3 (Matthias, Max K.)                   | --      | ✅ Done       | --         | --         | Resolved with #6                               |
| 8   | **GCP Secret Manager: Oracle connection strings**   | P3 / CAL Infra (Matt W.)               | --      | Active        | --         | --         | ABN + UAT done; PROD pending                   |
| 9   | **Network/VPN: Oracle on-prem reachable from GCP**  | CAL Infra / Nagel Infra                 | --      | ✅ Done       | --         | --         | Confirmed working for ABN and UAT              |
| 10  | **End-to-end integration test (ABN 1060)**          | P3 (Matthias, Max K.)                   | Joachim | In Progress   | --         | P3         | Running for ABN; UAT starting soon             |
| 11  | **Character encoding validation (UTF-8 vs Oracle)** | P3                                      | Joachim | No issues observed | --   | --         | Not encountered during ABN testing             |
| 12  | **TMS Pulse load test (ABN 1060)**                  | P3                                      | Nagel   | Pending       | #10        | P3, CAL/Nagel | Requires ABN with real data                 |
| 13  | **ABN sign-off**                                    | Patrick U., Max K. (P3)                 | --      | Pending       | #10, #11   | P3, Nagel  | Gate to UAT                                    |
| 14  | **UAT sign-off**                                    | Max Beisheim, Patrick U. (Nagel)        | --      | Pending       | #3, #13    | P3, Nagel  | Gate to PROD                                   |
| 15  | **Oracle CDC pipeline (Striim)**                    | Nagel                                   | --      | Active        | --         | --         | ABN + UAT done (Nikolay confirmed); PROD pending |
| 16  | **CDC target bucket for ABN1060**                   | P3                                      | --      | ✅ Done       | --         | --         | Different bucket than planned, but operational |
| 17  | **Dispo Filter function for 1060 CDC**              | P3                                      | --      | In Progress   | --         | --         | ABN + UAT deployed; PROD PR created            |
| 18  | **Pub/Sub topic for 1060 CDC**                      | P3                                      | --      | ✅ Done       | --         | --         | UAT + PROD done; ABN operational               |
| 19  | **Pipeline testing to Production WL4**              | P3                                      | --      | ✅ Done       | --         | --         | ABN + UAT deployed to WL4 and WL5              |
| 20  | **Keycloak and user access design**                 | P3                                      | --      | Open Question | --         | --         | Requested by Nagel (Matt W., 2026-05-01)       |
| 21  | **Entra ID setup per environment**                  | Nagel                                   | P3      | In Progress   | --         | --         | ABN done; UAT not set up; PROD unknown         |
| 22  | **TOP Service connectivity per environment**        | Nagel                                   | P3      | In Progress   | --         | --         | ABN + UAT done; PROD pending                   |

### 6.2 Standing Ownership

| Area                                  | Owner              |
| ------------------------------------- | ------------------ |
| GCP Infrastructure (WL3/WL4/WL5)      | Nagel Platform Service              |
| New Dispo Frontend                    | P3                 |
| New Dispo Backend                     | P3                 |
| TMS Bridge                            | P3                 |
| TMS AlloyDB Schema                    | P3                 |
| TMS Oracle Schema / Wrappers          | Nagel (end-to-end) |
| Oracle Dev & Deployment Pipeline      | Nagel (end-to-end) |
| Oracle Instance Provisioning          | Nagel (end-to-end) |
| Keycloak                              | P3                 |
| VPN / Network                         | Nagel Platform     |
| Azure DevOps (P3) Pipelines           | P3                 |
| Freight Exchanges (Timocom, Trans.eu) | P3                 |

---

## 7. CI/CD & Release Branches

Branching & versioning concept currently in the making.

---

## 8. Risks & Open Items (WIP)

| #   | Risk / Open Item                            | Impact                               | Mitigation                                    | Owner        |
| --- | ------------------------------------------- | ------------------------------------ | --------------------------------------------- | ------------ |
| 3   | Character encoding (UTF-8 vs Oracle legacy) | Data corruption (Poland incident)    | Not encountered during ABN testing            | P3           |
| 4   | Wrapper edge cases on real 1060 data        | Runtime failures in production       | ABN 1060 has real data -- test early          | P3 + Joachim |
| 6   | Oracle CDC pipeline for 1060 not scoped     | CDC events missing for 1060 branches | Striim active, final bucket name pending (Nikolay) | P3 / Nagel |
| 7   | Sign-off criteria undefined                 | Unclear go/no-go gate                | Define criteria for ABN and UAT               | Patrick U.   |
| 9   | Keycloak and user access design undefined   | Blocks security review               | Nagel waiting for documentation from P3       | P3           |

**Resolved:**

| #   | Risk / Open Item                            | Resolution                                                    | Resolved   |
| --- | ------------------------------------------- | ------------------------------------------------------------- | ---------- |
| 1   | ORA-ABN-1060 availability date unknown      | ABN1060 provisioned, DB objects deployed by Eric              | 2026-05-01 |
| 2   | ORA-ABN-1060 connection details pending     | TMSBR1060 user provisioned, secret created in WL5-T-T        | 2026-05-01 |
| 5   | VPN/Network path to Oracle 1060 from GCP    | Confirmed working — ABN and UAT connected                     | 2026-06-22 |
| 8   | Packet loss GCP <-> Nagel on-prem           | Managed by Telekom/Arista -- monitoring in place              | 2026-04-20 |

---

## 9. Next Steps (WIP)

1. **Obtain ORA-ABN-1060 connection details** from Joachim (host, port, user, network path)
2. **Verify VPN/network connectivity** from GCP WL5 to Oracle 1060 on-prem
3. **Create GCP secrets** for Oracle 1060 connection (`O-D-10-60` pattern)
4. **Configure TMS Bridge** appsettings for ORA-ABN-1060
5. **Run first end-to-end integration test** through full stack
6. **Test character encoding** with Polish/special-character data
7. **Scope Oracle CDC** for 1060 (Striim/Datastream decision)
8. **TMS Pulse load test** against ABN 1060
9. **ABN sign-off** -> proceed to UAT 1060
10. **Clarify application access methods** per environment (Citrix for UAT, Cameyo for ABN, direct access in Nuremberg)
11. **UAT sign-off** -> go-live

---

## 10. Related Resources

| Resource                          | Location                                                                   |
| --------------------------------- | -------------------------------------------------------------------------- |
| Oracle Environment Assessment     | `02_Explorations/2026-04-10_Oracle_DEV_ABN_UAT_Instances_for_Branch_1060/` |
| Infrastructure Documentation      | `08_Documentation/Infrastructure/`                                         |
| GCP Resources Reference           | `08_Documentation/Infrastructure/gcp-resources.md`                         |
| Deployment Mapping                | `08_Documentation/Infrastructure/deployment-mapping.md`                    |
| Network Configuration             | `08_Documentation/Infrastructure/network-configuration.md`                 |
| Technical Platform Overview       | `02_Explorations/2026-04-08_Technische_Plattform_Ubersicht/`               |
| GCP Workloads Diagram             | `07_Diagrams/GCP-workloads.svg`                                            |
| Wiki: Environments                | `WIKI/Nagel-CAL-Disposition.wiki/Devops/Environments.md`                   |
| ADR-004: DB Identifier Convention | `01_ADRs/`                                                                 |
| TMS Bridge Database Objects       | `02_Explorations/2026-04-29_TMS_Bridge_Database_Object_Inventory/tms-bridge-db-permission-scope.md` |

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
