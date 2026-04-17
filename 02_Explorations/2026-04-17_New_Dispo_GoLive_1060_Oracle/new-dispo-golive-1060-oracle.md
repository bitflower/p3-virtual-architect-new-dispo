# New Dispo GoLive 1060 (Oracle) - Architecture & Infrastructure Overview

**Date:** 2026-04-17
**Status:** Draft
**Purpose:** Holistic overview to align all stakeholders on the architecture, infrastructure, environments, and ownership for Branch 1060 on Oracle.

---

## 1. End-to-End Environment Landscape

This section maps every environment stage across both the GCP (New Dispo) side and the Oracle (TMS) side.

### 1.1 Environment Pipeline Overview

```
               GCP (New Dispo)                         Oracle (TMS)
          ========================              ========================

 LOCAL    Developer Workstation                  --
          (Docker, localhost)

 DEV      WL4-DEV / WL5-DEV                     ENT1
          (development, feature testing)         (schema dev, unit testing)
                    |                                      |
                    v                                      v
 TEST     WL4-T-T / WL5-T-T                     ABN 1060
          (integration, E2E)                     (acceptance, live prod data)
                    |                                      |
                    v                                      v
 UAT      (shares TEST infra,                   UAT 1060
           dedicated TMS connection)             (customer acceptance)
                    |                                      |
                    v                                      v
 PROD     WL4-P-P / WL5-P-P                     PROD
          (production)                           (production)
```

### 1.2 Environment Mapping Matrix

| Stage     | GCP Project (WL4)           | GCP Project (WL5)           | Oracle Instance  | Data Profile                | Sign-Off                 |
| --------- | --------------------------- | --------------------------- | ---------------- | --------------------------- | ------------------------ |
| **LOCAL** | --                          | --                          | --               | Seeded / empty              | Developer                |
| **DEV**   | WL4-DEV (TBD)               | WL5-DEV (TBD)               | ENT1 (shared)    | Schema only, no branch data | Developer                |
| **TEST**  | `prj-cal-w-wl4-t-4c48-53ad` | `prj-cal-w-wl5-t-6c00-53ad` | **ORA-ABN-1060** | Live production data (1060) | Patrick U., Max K. (P3)  |
| **UAT**   | (shares TEST infra)         | (shares TEST infra)         | **ORA-UAT-1060** | Production data             | Max Beisheim, Patrick U. |
| **PROD**  | `prj-cal-w-wl4-p-afad-53ad` | `prj-cal-w-wl5-p-3e5b-53ad` | PROD             | Production                  | --                       |

---

## 2. Architecture Overview

### 2.1 GCP Workload Separation

| Workload    | Purpose            | Components                                     | GCP Project (Test)                                              | GCP Project (Prod)          |
| ----------- | ------------------ | ---------------------------------------------- | --------------------------------------------------------------- | --------------------------- |
| **WL4**     | User-Facing App    | Frontend, Backend, CloudSQL                    | `prj-cal-w-wl4-t-4c48-53ad`                                     | `prj-cal-w-wl4-p-afad-53ad` |
| **WL5**     | Integration & Data | TMS Bridge, Cloud4Log, Dispo Filter, CrossDock | `prj-cal-w-wl5-t-6c00-53ad`                                     | `prj-cal-w-wl5-p-3e5b-53ad` |
| **Network** | Shared VPC         | VPN, Routing, Firewall                         | `prj-cal-net-s-t-e004-53ad`                                     | `prj-cal-net-s-p-19c3-53ad` |
| **CI/CD**   | Deployment         | Workload Identity, Pipelines                   | `prj-cal-w-cicd-wl4-a1bc-53ad` / `prj-cal-w-cicd-wl5-a591-53ad` | (same)                      |

---

## 3. GCP Components by Environment

### 3.1 Cloud Run Services

| Service    | Workload | Test Name                           | Test URL                                      | Prod Name                           | Prod URL                                 |
| ---------- | -------- | ----------------------------------- | --------------------------------------------- | ----------------------------------- | ---------------------------------------- |
| Frontend   | WL4      | `cal-new-disposition-frontend-t-t`  | `https://test.dispo.gcp.nagel-group.com`      | `cal-new-disposition-frontend-p-p`  | `https://dispo.gcp.nagel-group.com`      |
| Backend    | WL4      | `cal-new-disposition-backend-t-t`   | `https://test.dispo.gcp.nagel-group.com`      | `cal-new-disposition-backend-p-p`   | `https://dispo.gcp.nagel-group.com`      |
| TMS Bridge | WL5      | `cal-new-disposition-tmsbridge-t-t` | `https://test.tms-bridge.gcp.nagel-group.com` | `cal-new-disposition-tmsbridge-p-p` | `https://tms-bridge.gcp.nagel-group.com` |

### 3.2 Cloud Functions (Gen2)

| Function               | Workload | Trigger       | Test Instance                               | Prod Instance                               | Config |
| ---------------------- | -------- | ------------- | ------------------------------------------- | ------------------------------------------- | ------ |
| Dispo Filter (UAT1060) | WL5      | Cloud Storage | `new-dispo-filter-shipment-records-uat1060` | `new-dispo-filter-shipment-records-uat1060` | Python |

### 3.3 Databases

| Database             | Type                | Test Instance                  | Prod Instance                      |
| -------------------- | ------------------- | ------------------------------ | ---------------------------------- |
| New Dispo Backend DB | CloudSQL PostgreSQL | `cal-new-disposition-psql-t-t` | `cal-new-disposition-postgres-p-p` |

### 3.6 Cloud Storage Buckets

| Bucket                   | Environment | Purpose                | Status |
| ------------------------ | ----------- | ---------------------- | ------ |
| `WL5_CDC_BUCKET_ABN1060` | Test        | CDC bucket for ABN1060 | TBD    |
| `WL5_CDC_BUCKET_UAT1060` | Test        | CDC bucket for UAT1060 | TBD    |
| `WL5_CDC_BUCKET_1060`    | Prod        | CDC bucket for 1060    | TBD    |

### 3.7 Pub/Sub

| Resource                | Environment | Purpose                | Status |
| ----------------------- | ----------- | ---------------------- | ------ |
| `WL5_CDC_TOPIC_ABN1060` | Test        | CDC events for ABN1060 | TBD    |
| `WL5_CDC_TOPIC_UAT1060` | Test        | CDC events for UAT1060 | TBD    |
| `WL5_CDC_TOPIC_1060`    | Prod        | CDC events for 1060    | TBD    |

### 3.8 Networking

| Resource            | Test                                   | Prod                                   | Status            |
| ------------------- | -------------------------------------- | -------------------------------------- | ----------------- |
| Shared VPC          | `vpc-c-shared-vpc-c-net-s-t`           | `vpc-c-shared-vpc-c-net-s-p`           | * to be confirmed |
| Subnet              | `sn-vpc-c-net-s-t-europe-west3-common` | `sn-vpc-c-net-s-p-europe-west3-common` | * to be confirmed |
| Hub VPC Project     | `prj-cal-net-h-5332-53ad`              | `prj-cal-net-h-5332-53ad`              | * to be confirmed |
| CAL VPN Endpoints   | `34.157.54.59`, `34.157.191.34`        | (same hub)                             | * to be confirmed |
| Nagel VPN Endpoints | `35.242.18.84`, `34.157.189.239`       | (same hub)                             | * to be confirmed |

---

## 4. Security - Users & Service Accounts

### 4.1 Authentication Patterns by Context

| Context                       | Method                           | Identity Provider                     | Status          |
| ----------------------------- | -------------------------------- | ------------------------------------- | --------------- |
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

**Keycloak Servers:**

| Environment | URL                                             |
| ----------- | ----------------------------------------------- |
| Local       | `http://localhost:8080`                         |
| Dev         | `https://dev.new-dispo.nagel.p3ds.net/keycloak` |
| Production  | `https://nagel-staging.ddns.net:8081/keycloak`  |

### 4.3 GCP Service Accounts

| Service Account                                                  | Scope            | Purpose                                                        | Status            |
| ---------------------------------------------------------------- | ---------------- | -------------------------------------------------------------- | ----------------- |
| `wl-cicd@prj-cal-w-cicd-wl4-a1bc-53ad.iam.gserviceaccount.com`   | WL4 CI/CD        | Azure DevOps pipeline deployments (Frontend, Backend)          | * to be confirmed |
| `wl-cicd@prj-cal-w-cicd-wl5-a591-53ad.iam.gserviceaccount.com`   | WL5 CI/CD        | Azure DevOps pipeline deployments (TMS Bridge, Cloud4Log, CDC) | * to be confirmed |
| `wl5-cloudrun@prj-cal-w-wl5-t-6c00-53ad.iam.gserviceaccount.com` | WL5 Test Runtime | Cloud Run + Workflow execution (Test)                          | * to be confirmed |
| `wl5-cloudrun@prj-cal-w-wl5-p-3e5b-53ad.iam.gserviceaccount.com` | WL5 Prod Runtime | Cloud Run + Workflow execution (Prod)                          | * to be confirmed |

**Workload Identity Pools (Azure DevOps Federation):**
- WL4: `azure-devops` (project number: 607166292072)
- WL5: `azure-devops` (project number: 534233136072)

### 4.4 Database Users

| Database               | User                    | Context                    | Notes                                    |
| ---------------------- | ----------------------- | -------------------------- | ---------------------------------------- |
| ORA-ABN-1060       | TBD                     | TMS Bridge -> ORA-ABN-1060  | Pending: connection details from Joachim |
| ORA-UAT-1060       | TBD                     | TMS Bridge -> ORA-UAT-1060  | Pending: after ABN sign-off              |
| ORA-PROD-1060      | TBD                     | TMS Bridge -> ORA-PROD-1060 | Pending: after UAT sign-off              |

**Database Identifier Convention (ADR-004):**
Format: `{DBMS}-{COUNTRY}-{COMPANY}-{BRANCH}` (e.g., `O-D-10-60` for Oracle Germany Company 10 Branch 60)
\* to be discussed in scope

### 4.5 Secret Manager

| Secret Name                                  | Purpose                       | Injected Into                  |
| -------------------------------------------- | ----------------------------- | ------------------------------ |
| `D-{COMPANY}-{BRANCH}`                       | PostgreSQL connection string  | TMS Bridge                     |
| `O-{COMPANY}-{BRANCH}`                       | Oracle connection string      | TMS Bridge                     |

---

## 5. External Integrations

| System                | Protocol          | Purpose                                      | Connected From                | Owner       |
| --------------------- | ----------------- | -------------------------------------------- | ----------------------------- | ----------- |
| **Keycloak**          | HTTPS (OIDC)      | Authentication & Authorization               | Frontend, Backend, TMS Bridge | CAL / Nagel |
| **Azure Service Bus** | AMQP/TLS          | Event publishing for CALSuite                | CrossDock Publisher           | CAL         |
| **TOP Service**       | HTTP              | Route optimization                           | Backend (on-prem)             | Nagel       |
| **xServer**           | HTTP              | Routing calculations                         | TOP Service                   | PTV         |
| **SMTP (Office 365)** | STARTTLS          | Email notifications                          | Backend                       | CAL         |
| **Timocom**           | REST API          | Freight exchange                             | Backend                       | External    |
| **Trans.eu**          | REST API (OAuth2) | Freight exchange                             | Backend                       | External    |

---

## 6. Ownership & Responsibility Matrix

### 6.1 Go-Live 1060 -- Who Does What

| #   | Task                                                | Owner                                   | Support | Status        | Notes                                          |
| --- | --------------------------------------------------- | --------------------------------------- | ------- | ------------- | ---------------------------------------------- |
| 1   | **Oracle ENT1 schema development**                  | Joachim Schreiner (Nagel)               | --      | Active        | Wrapper procedures for 1060                    |
| 2   | **Provision ORA-ABN-1060**                          | Bernd Friedewald, Thomas Paulus (Nagel) | Joachim | In Progress   | Live production data from 1060                 |
| 3   | **Provision ORA-UAT-1060**                          | Bernd Friedewald, Thomas Paulus (Nagel) | Joachim | Pending       | After ABN sign-off                             |
| 4   | **Oracle deployment pipeline (QS tool)**            | Joachim Schreiner (Nagel)               | --      | Operational   | ENT -> ABN -> UAT -> PROD                      |
| 5   | **ORA-ABN-1060 connection details**                 | Joachim Schreiner (Nagel)               | --      | Pending       | Host, port, credentials, network               |
| 6   | **TMS Bridge config for ORA-ABN-1060**              | P3 (Matthias, Max K.)                   | Joachim | Pending       | Blocked on #5                                  |
| 7   | **Backend TEST env config for Oracle**              | P3 (Matthias, Max K.)                   | --      | Pending       | Blocked on #6                                  |
| 8   | **GCP Secret Manager: Oracle connection strings**   | P3 / CAL Infra                          | --      | Pending       | `O-{COMPANY}-{BRANCH}` entries                 |
| 9   | **Network/VPN: Oracle on-prem reachable from GCP**  | CAL Infra / Nagel Infra                 | --      | TBD           | Verify `oracle-user` tag grants access to 1060 |
| 10  | **End-to-end integration test (ABN 1060)**          | P3 (Matthias, Max K.)                   | Joachim | Pending       | Frontend -> Backend -> Bridge -> ORA-ABN-1060  |
| 11  | **Character encoding validation (UTF-8 vs Oracle)** | P3                                      | Joachim | Pending       | Polish/special-char data in ABN 1060           |
| 12  | **TMS Pulse load test (ABN 1060)**                  | P3                                      | Nagel   | Pending       | Requires ABN with real data                    |
| 13  | **ABN sign-off**                                    | Patrick U., Max K. (P3)                 | --      | Pending       | Gate to UAT                                    |
| 14  | **UAT sign-off**                                    | Max Beisheim, Patrick U. (Nagel)        | --      | Pending       | Gate to PROD                                   |
| 15  | **Oracle CDC pipeline (Striim/Datastream)**         | TBD                                     | --      | Open Question | Should CDC connect to ABN/UAT too?             |
| 16  | **Dispo Filter function for 1060 CDC**              | P3                                      | --      | Pending       | New function instance per branch               |
| 17  | **Pub/Sub topic for 1060 CDC**                      | P3 / CAL Infra                          | --      | Pending       | `WL5_CDC_TOPIC_1060`                           |

### 6.2 Standing Ownership

| Area                                  | Owner                       | Backup      |
| ------------------------------------- | --------------------------- | ----------- |
| GCP Infrastructure (WL3/WL4/WL5)      | P3 (?)                      | --          |
| New Dispo Frontend                    | P3                          | --          |
| New Dispo Backend                     | P3                          | --          |
| TMS Bridge                            | P3                          | --          |
| TMS AlloyDB Schema                    | P3                          | --          |
| TMS Oracle Schema / Wrappers          | Nagel (end-to-end)          | --          |
| Oracle Dev & Deployment Pipeline      | Nagel (end-to-end)          | --          |
| Oracle Instance Provisioning          | Nagel (end-to-end)          | --          |
| Keycloak                              | P3                          | --          |
| VPN / Network                         | Nagel Platform              | --          |
| Azure DevOps Pipelines                | P3                          | --          |
| Freight Exchanges (Timocom, Trans.eu) | P3                          | --          |

---

## 7. CI/CD & Release Branches

Branching & versioning concept currently in the making.

---

## 8. Risks & Open Items

| #   | Risk / Open Item                            | Impact                               | Mitigation                                    | Owner        |
| --- | ------------------------------------------- | ------------------------------------ | --------------------------------------------- | ------------ |
| 1   | ORA-ABN-1060 availability date unknown      | Blocks all integration testing       | Coordinate with Joachim for timeline          | Matthias     |
| 2   | ORA-ABN-1060 connection details pending     | Blocks TMS Bridge config             | Obtain from Joachim once provisioned          | Matthias     |
| 3   | Character encoding (UTF-8 vs Oracle legacy) | Data corruption (Poland incident)    | Explicit testing with Polish data in ABN 1060 | P3           |
| 4   | Wrapper edge cases on real 1060 data        | Runtime failures in production       | ABN 1060 has real data -- test early          | P3 + Joachim |
| 5   | VPN/Network path to Oracle 1060 from GCP    | TMS Bridge cannot reach Oracle       | Verify with CAL Infra                         | CAL Infra    |
| 6   | Oracle CDC pipeline for 1060 not scoped     | CDC events missing for 1060 branches | Decide: Striim vs Datastream for Oracle CDC   | TBD          |
| 7   | Sign-off criteria undefined                 | Unclear go/no-go gate                | Define criteria for ABN and UAT               | Patrick U.   |
| 8   | Packet loss GCP <-> Nagel on-prem           | Intermittent failures                | Managed by Telekom/Arista -- monitor          | CAL Infra    |

---

## 9. Next Steps (Sequenced)

1. **Obtain ORA-ABN-1060 connection details** from Joachim (host, port, user, network path)
2. **Verify VPN/network connectivity** from GCP WL5 to Oracle 1060 on-prem
3. **Create GCP secrets** for Oracle 1060 connection (`O-D-10-60` pattern)
4. **Configure TMS Bridge** appsettings for ORA-ABN-1060
5. **Run first end-to-end integration test** through full stack
6. **Test character encoding** with Polish/special-character data
7. **Scope Oracle CDC** for 1060 (Striim/Datastream decision)
8. **TMS Pulse load test** against ABN 1060
9. **ABN sign-off** -> proceed to UAT 1060
10. **UAT sign-off** -> go-live

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
