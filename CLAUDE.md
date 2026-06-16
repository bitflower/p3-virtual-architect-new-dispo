# New Dispo Tech-Stack

## Components

| Folder                                             | Component                                      |
| -------------------------------------------------- | ---------------------------------------------- |
| Code/tms-alloydb-schema                            | TMS Database                                   |
| Code/Disposition-Abstraction-Layer                 | TMS Bridge                                     |
| Code/Disposition-Backend                           | New Dispo Backend                              |
| Code/Disposition-Frontend                          | New Dispo Frontend                             |
| Code/Nagel-GCP/CALConsult.Disposition.Functions    | New Dispo Cloud Functions                      |
| Code/Nagel-GCP/Cloud4Log                           | Cloud4Log Cloud Functions                      |
| Code/Driver-Terminal/Self-Service-Terminal-Backend | Driver-Terminal: Self-Service Terminal Backend |
| Code/CALConsult.TOP                                | TOP (Tour Optimization Platform)               |
| Code/CALConsult.TmsProxy                           | TMS Proxy                                      |
| Code/CALConsult.TmsProxyClient                     | TMS Proxy Client                               |
| Code/Disposition-Rollout-Tools                     | New Dispo Rollout Tools / Helpers              |
| Code/Disposition-UI-Automation                     | New Dispo UI Tests (Selenium/NUnit)            |

## Testing

- New Dispo Backend uses **MSTest** (`MSTest.TestFramework` / `Microsoft.VisualStudio.TestTools.UnitTesting`). Use `[TestClass]`, `[TestMethod]`, `[TestInitialize]` — not xUnit or NUnit.

## WIKI

| Folder                                        | Component                           |
| --------------------------------------------- | ----------------------------------- |
| WIKI/Nagel-CAL-Disposition.wiki               | "New TMS" Wiki                      |
| WIKI/Nagel-CAL-Disposition.wiki/Documentation | User-Facing "New TMS" Documentation |

## Setup

- Azure MCP needs Node version 20+