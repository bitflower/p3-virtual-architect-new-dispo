# New Dispo Infrastructure Documentation

**Last Updated:** 2026-03-03

## Overview

This document provides comprehensive infrastructure documentation for the New Dispo system deployed on Google Cloud Platform (GCP). All components utilize Azure DevOps pipelines with Workload Identity Federation for CI/CD automation.

The New Dispo system consists of multiple components deployed across two GCP workloads (WL4 and WL5) for separation of concerns and compliance requirements.

## Architecture Overview

### Workload Distribution

The New Dispo architecture is distributed across two GCP workloads:

- **WL4 (Workload 4):** User-facing application layer
  - New Dispo Backend
  - New Dispo Frontend

- **WL5 (Workload 5):** Integration and data layer
  - TMS Bridge (Disposition Abstraction Layer)
  - Cloud Functions (Dispo Filter, Cloud4Log, CrossDock Publisher)

This separation provides:
- Clear security boundaries between user-facing and integration components
- Independent scaling and resource management
- Compliance with organizational security policies

### Component Overview

| Component | Purpose | Workload | Technology |
|-----------|---------|----------|------------|
| **TMS Bridge** | Abstraction layer for TMS database access | WL5 | Cloud Run (.NET) |
| **Backend** | Business logic and API endpoints | WL4 | Cloud Run (.NET) |
| **Frontend** | User interface | WL4 | Cloud Run (Angular) |
| **Dispo Filter Function** | Filter and process shipment records from CDC | WL5 | Cloud Functions Gen2 |
| **Cloud4Log** | Document upload/download (Bordero, Rollkart, PoD) | WL5 | Cloud Functions Gen2 + Workflows |
| **CrossDock Publisher** | Publish TMS events to Azure Service Bus | WL5 | Cloud Functions Gen2 |

## Detailed Documentation

- [Component Deployment Mapping](Infrastructure/deployment-mapping.md) - Detailed deployment information for each component
- [CI/CD Pipelines](Infrastructure/cicd-pipelines.md) - Pipeline configurations and automation
- [GCP Resources](Infrastructure/gcp-resources.md) - Cloud Storage, Pub/Sub, databases, and other GCP services
- [Network Configuration](Infrastructure/network-configuration.md) - VPC, subnets, and network security
- [External Integrations](Infrastructure/external-integrations.md) - Keycloak, Azure Service Bus, DigiLiS, TOP Service, and TMS Database

## Quick Reference

### Service Endpoints

**Test Environment:**
- Frontend & Backend: https://test.dispo.gcp.nagel-group.com
- TMS Bridge: https://test.tms-bridge.gcp.nagel-group.com
- Keycloak: https://test.dispo.gcp.nagel-group.com/keycloak

**Production Environment:**
- Frontend & Backend: https://dispo.gcp.nagel-group.com
- TMS Bridge: https://tms-bridge.gcp.nagel-group.com
- Keycloak: https://dispo.gcp.nagel-group.com/keycloak

### GCP Projects

**Test Environment:**
- WL4: `prj-cal-w-wl4-t-4c48-53ad`
- WL5: `prj-cal-w-wl5-t-6c00-53ad`

**Production Environment:**
- WL4: `prj-cal-w-wl4-p-afad-53ad`
- WL5: `prj-cal-w-wl5-p-3e5b-53ad`

### Common Settings

- **Region:** europe-west3
- **CI/CD Service Account:** `wl-cicd@prj-cal-w-cicd-wl5-a591-53ad.iam.gserviceaccount.com`
- **Workload Identity Pool:** `azure-devops`
