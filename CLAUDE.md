# New Dispo Tech-Stack

## Components & Repositories

`Code/` and `WIKI/` are **gitignored** — they contain independent git repos that must be cloned separately.

### Root Repository

| Provider | Remote                       | User        |
| -------- | ---------------------------- | ----------- |
| GitHub   | `github.com/bitflower/p3-virtual-architect-new-dispo` | `bitflower` |

### Nested Repositories

| Folder                                             | Component                    | Provider         | User                             | Remote URL                                                                       |
| -------------------------------------------------- | ---------------------------- | ---------------- | -------------------------------- | -------------------------------------------------------------------------------- |
| Code/tms-alloydb-schema                            | TMS Database                 | GitHub           | `matthiasmax-p3`                 | `github.com/cal-consult/tms-alloydb-schema.git`                                  |
| Code/Disposition-Abstraction-Layer                 | TMS Bridge                   | Azure DevOps     | `matthias.max@p3-group.com`      | `dev.azure.com/p3ds/Nagel-CAL%20Disposition/_git/Disposition-Abstraction-Layer`  |
| Code/Disposition-Backend                           | New Dispo Backend            | Azure DevOps     | `matthias.max@p3-group.com`      | `dev.azure.com/p3ds/Nagel-CAL%20Disposition/_git/Disposition-Backend`            |
| Code/Disposition-Frontend                          | New Dispo Frontend           | Azure DevOps     | `matthias.max@p3-group.com`      | `dev.azure.com/p3ds/Nagel-CAL%20Disposition/_git/Disposition-Frontend`           |
| Code/Nagel-GCP                                     |                              | Azure DevOps     | `matthias.max@p3-group.com`      | `dev.azure.com/p3ds/Nagel-CAL%20Disposition/_git/Nagel-GCP`                      |
| ↳ .../CALConsult.Disposition.Functions             | New Dispo Cloud Functions    |                  |                                  |                                                                                  |
| ↳ .../Cloud4Log                                    | Cloud4Log Cloud Functions    |                  |                                  |                                                                                  |
| Code/Driver-Terminal/Self-Service-Terminal-Backend | Driver-Terminal: SST Backend | Azure DevOps     | `matthias.max@p3-group.com`      | `dev.azure.com/p3ds/P3-Self-Service-Terminal/_git/Self-Service-Terminal-Backend` |
| Code/Disposition-Rollout-Tools                     | Rollout Tools / Helpers      | Azure DevOps     | `matthias.max@p3-group.com`      | `dev.azure.com/p3ds/Nagel-CAL%20Disposition/_git/Disposition-Rollout-Tools`      |
| Code/Disposition-UI-Automation                     | UI Tests (Selenium/NUnit)    | Azure DevOps     | `matthias.max@p3-group.com`      | `dev.azure.com/p3ds/Nagel-CAL%20Disposition/_git/Disposition-UI-Automation`      |
| Code/CALConsult.TOP                                | TOP (Tour Optimization)      | symlink → CALtms | `x_matthias.max@nagel-group.com` | `dev.azure.com/caldevops/Agile/_git/CALtms`                                      |
| Code/CALConsult.TmsProxy                           | TMS Proxy                    | symlink → CALtms | `x_matthias.max@nagel-group.com` | `dev.azure.com/caldevops/Agile/_git/CALtms`                                      |
| Code/CALConsult.TmsProxyClient                     | TMS Proxy Client             | symlink → CALtms | `x_matthias.max@nagel-group.com` | `dev.azure.com/caldevops/Agile/_git/CALtms`                                      |
| WIKI/Nagel-CAL-Disposition.wiki                    | "New TMS" Wiki               | Azure DevOps     | `matthias.max@p3-group.com`      | `dev.azure.com/p3ds/Nagel-CAL%20Disposition/_git/Nagel-CAL-Disposition.wiki`     |
| ↳ .../Documentation                                | User-Facing "New TMS" Docs   |                  |                                  |                                                                                  |

**Symlinks:** The `CALConsult.*` entries are symlinks into the CALtms monorepo (`3GL/` subfolder), which must be cloned outside this repo.

## Testing

- New Dispo Backend uses **MSTest** (`MSTest.TestFramework` / `Microsoft.VisualStudio.TestTools.UnitTesting`). Use `[TestClass]`, `[TestMethod]`, `[TestInitialize]` — not xUnit or NUnit.

