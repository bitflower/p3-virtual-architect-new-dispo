# GCP Monitoring Dashboards - IaC vs Console UI

**Date:** 2026-06-18
**Status:** Exploration

---

## Original User Input

> A DevOps colleague created a dashboard in GCP:
> `https://console.cloud.google.com/monitoring/dashboards/builder/46b8c621-ded5-4120-8da5-1b02d88aa662`
> Project: `prj-cal-w-wl5-t-6c00-53ad`
>
> Questions:
> 1. How is this done? IaC or Console UI?
> 2. Does my user have rights to create dashboards?

---

## Summary

GCP Monitoring dashboards can be created both via the Console UI and via Infrastructure as Code (Terraform, gcloud CLI, Monitoring API). In our project, dashboards are created **manually in the Console UI** -- there is no Terraform or IaC configuration managing them. The user (`x_matthias.max@nagel-group.com`) does not currently have sufficient permissions on the target project, but access has been requested.

## Analysis

### How Dashboards Are Created

| Method | How | Used in our project? |
|--------|-----|---------------------|
| **Console UI** | Monitoring > Dashboards > Create Custom Dashboard | Yes -- all 4 custom dashboards are UI-created |
| **Terraform** | `google_monitoring_dashboard` resource with JSON layout | No -- no `.tf` files found in the codebase |
| **gcloud CLI** | `gcloud monitoring dashboards create --config-from-file` | No |
| **Monitoring API** | REST API `projects.dashboards.create` | No |

A search across the entire codebase (`Code/`) found **no Terraform files** and **no monitoring dashboard definitions** in any IaC format. All custom dashboards are created and maintained directly in the GCP Console.

### Dashboard Inventory (project: prj-cal-w-wl5-t-t-53ad)

| Type | Count | Examples |
|------|-------|---------|
| Custom | 4 | Cloud4Log Custom Dashboard, Cloud4Log Custom Dashboard backup, copies |
| Google Services | 27 | Cloud Run Monitoring, Cloud Storage, Load Balancers, etc. |
| Playbook | 7 | GCE Interactive Playbooks for troubleshooting |

Note: The colleague's dashboard is on project `prj-cal-w-wl5-t-6c00-53ad` (different from `prj-cal-w-wl5-t-t-53ad` where the screenshot was taken -- extra `t` vs `6c00`).

### Permissions

**Required roles for dashboard management:**

| Role | Scope |
|------|-------|
| `roles/monitoring.dashboardEditor` | Create/edit/delete dashboards only |
| `roles/monitoring.editor` | Broader monitoring write access |
| `roles/monitoring.admin` | Full monitoring access |
| `roles/serviceusage.serviceUsageConsumer` | Required for API/CLI access to the project |

**Current state for `x_matthias.max@nagel-group.com`:**

- `gcloud projects get-iam-policy` -- PERMISSION_DENIED (no IAM viewer rights)
- `gcloud monitoring dashboards describe` -- PERMISSION_DENIED (missing `serviceUsageConsumer`)
- Console UI on `prj-cal-w-wl5-t-t-53ad` (different project) -- "Create Custom Dashboard" button visible, indicating dashboard permissions exist there
- Access to target project `prj-cal-w-wl5-t-6c00-53ad` has been requested

### Export Path (once access is granted)

To export the dashboard as JSON (for IaC migration or inspection):

```bash
gcloud monitoring dashboards describe 46b8c621-ded5-4120-8da5-1b02d88aa662 \
  --project=prj-cal-w-wl5-t-6c00-53ad \
  --format=json > dashboard.json
```

This JSON can then be used with:
- **Terraform**: `google_monitoring_dashboard` resource (`dashboard_json` attribute)
- **gcloud**: `gcloud monitoring dashboards create --config-from-file=dashboard.json`

## Findings

1. **All custom dashboards in our project are Console UI-created** -- no IaC manages them
2. **Both approaches are possible** -- GCP supports full IaC lifecycle for dashboards
3. **The user has dashboard permissions on `prj-cal-w-wl5-t-t-53ad`** but not yet on the target project `prj-cal-w-wl5-t-6c00-53ad`
4. **Two different GCP projects are involved** -- the dashboard URL and the Console screenshot reference different projects

## Questions/Open Items

- [ ] Access request to `prj-cal-w-wl5-t-6c00-53ad` -- pending approval
- [ ] Once granted: export dashboard JSON via `gcloud monitoring dashboards describe`
- [ ] Decision: should dashboards be managed as IaC going forward, or remain Console-managed?
