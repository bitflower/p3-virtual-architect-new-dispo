# [ADR009] TMS Bridge Credential Isolation via System-Qualified Database Identifier

**Status:** Approved (2026-05-07)
**Date:** 2026-05-11

## Context

The TMS Bridge serves multiple calling systems -- currently **New Dispo** and **Cloud4Log** -- that require different database permission levels. Cloud4Log uses a read-only QM user; New Dispo uses a user with write permissions. Today, the TMS Bridge resolves database connections through a single database identifier (e.g., `D-10-60`) that maps 1:1 to a Secret Manager entry. This means all callers share the same database credentials for a given branch.

The bridge treats the database identifier as an opaque string everywhere except for **schema name extraction**, where a strict regex (`^[DO]-(\d{1,2})-(\d{1,3})$`) in `BranchDbContextFactory.cs:22` derives the TMS schema name from the numeric parts. The Secret Manager lookup, vendor detection, and connection pool caching all work with arbitrary identifier strings already.

To isolate credentials per calling system, the identifier must carry a **system qualifier** that routes to a separate Secret Manager entry (and therefore separate database user) while still extracting the same schema name.

A related constraint reinforces this need: WL4-T-T hosts multiple virtual environments (DEV, ABN, UAT) within the same GCP project (see ADR-005, ADR-008). GCP Secret Manager is project-scoped and cannot hold duplicate secret names. The same prefix mechanism that isolates callers must also support **environment qualification** via multi-segment prefixes (e.g., `dispo-abn-O-10-60`) so that each virtual environment resolves to its own Secret Manager entry.

Key requirements:

1. **Credential isolation**: Each calling system resolves to its own Secret Manager entry and database user
2. **Environment qualification**: Virtual environments within the same GCP project resolve to separate secrets for the same branch
3. **Backward compatibility**: Existing unqualified identifiers (e.g., `D-10-60`) must continue to work
4. **Minimal code change**: Only the schema name extraction regex needs updating
5. **Operability**: Identifiers should be easy to read, grep, and audit in Secret Manager and logs

#### Options Considered

**For system qualifier placement:**

* **Option A: Prefix** -- prepend the system name (and optionally environment) before the branch identifier
  * Pattern: `{SYSTEM}-{DBMS}-{COMPANY}-{BRANCH}` or `{SYSTEM}-{ENV}-{DBMS}-{COMPANY}-{BRANCH}`
  * Examples: `dispo-D-10-60`, `cloud4log-O-10-60`, `dispo-abn-O-10-60`
  * Regex: `^(?:[a-z][a-z0-9]*(?:-[a-z][a-z0-9]*)*-)?[DO]-(\d{1,2})-(\d{1,3})$`

* **Option B: Postfix** -- append the system name after the branch identifier
  * Pattern: `{DBMS}-{COMPANY}-{BRANCH}-{SYSTEM}`
  * Examples: `D-10-60-dispo`, `O-10-60-cloud4log`
  * Regex: `^[DO]-(\d{1,2})-(\d{1,3})(?:-[a-z0-9]+)?$`

## Decision

**Option A: Prefix.** The system qualifier is prepended to the database identifier. For virtual environments sharing a GCP project, an environment segment is added between system and branch identifier.

* Pattern: `{SYSTEM}-{DBMS}-{COMPANY}-{BRANCH}` or `{SYSTEM}-{ENV}-{DBMS}-{COMPANY}-{BRANCH}`
* Examples: `dispo-D-10-60`, `dispo-abn-O-10-60`, `dispo-uat-O-10-60`

## Rationale

* **Prefix (Option A):** Reads naturally as "dispo's D-10-60" -- the system name acts as a namespace. Prefix-based namespacing is a widespread convention in infrastructure tooling (e.g., `env-resource`, `team-service`). The original branch identifier (`D-10-60`) remains recognizable at the end of the string, making it easy to spot in logs. The approach also extends naturally to multi-segment prefixes for environment qualification (e.g., `dispo-abn-D-10-60`), which aligns with existing patterns seen in Cloud4Log's environment-aware secret names.

* **Postfix (Option B):** Rejected despite having marginally simpler regex and better lexicographic grouping by branch in Secret Manager. The branch-first sorting advantage is outweighed by the less intuitive reading order and deviation from common infrastructure naming conventions. In practice, Secret Manager filtering and search make sorting order a minor concern.

### Comparison

| Aspect | Prefix (`dispo-D-10-60`) | Postfix (`D-10-60-dispo`) |
|---|---|---|
| Regex complexity | Slightly higher (non-greedy prefix match) | Lower (optional trailing group) |
| Secret Manager sorting | By system, then branch | By branch, then system |
| Log readability | System name jumps out first | Branch jumps out first |
| Backward compatibility | `D-10-60` still works | `D-10-60` still works |
| Multi-segment extensibility | Natural (`dispo-abn-D-10-60`) | Awkward (`D-10-60-dispo-abn`) |
| Convention familiarity | Common (prefix namespacing) | Less common |

## Consequences

* **Positive**:
  * Each calling system gets its own database credentials without changes to the TMS Bridge resolution chain beyond a single-line regex update
  * Connection pool isolation is a natural side effect -- different identifiers get separate pools
  * Backward compatible -- unqualified identifiers continue to work
  * Extensible to environment-specific credentials via multi-segment prefixes

* **Negative**:
  * Secrets in Secret Manager sort by system name first, making per-branch auditing slightly less convenient
  * Connection pool count doubles per branch (one pool per calling system) -- acceptable since pools are lazy-initialized
  * New secrets must be created in Secret Manager for each system-branch combination
  * New Dispo Backend must be updated to send prefixed identifiers

## Related ADRs

* [ADR-004: TMS Bridge Database Identifier Naming Convention](../ADR-004-tms-bridge-database-identifier/ADR-004-tms-bridge-database-identifier.md) -- establishes the base `{DBMS}-{COUNTRY}-{COMPANY}-{BRANCH}` pattern that this ADR extends
* [ADR-005: Dual Instance Deployment in WL4 Test Environment](../ADR-005-dual-instance-deployment-wl4-test/ADR-005-dual-instance-deployment-wl4-test.md) -- original workaround for missing WL4-DEV; multi-segment prefixes enable credential isolation across these virtual environments
* [ADR-008: Use WL4-T-T for Development](../ADR-008-wl4-dev-unavailable-use-wl4-tt/ADR-008-wl4-dev-unavailable-use-wl4-tt.md) -- formalizes WL4-T-T as the dev target, creating the need for environment-qualified secrets

## References

**Exploration:**
* [TMS Bridge Credential Selection](../../02_Explorations/2026-05-07_TMS_Bridge_DB_User_Selection/tms-bridge-db-user-selection.md) -- full analysis of the resolution chain and option comparison

**Key Source Files:**

| File | Role |
|---|---|
| `BranchDbContextFactory.cs` | Schema regex + context creation (only file requiring code change) |
| `DbConnectionStringProvider.cs` | Secret Manager config lookup (no change needed) |
| `DbDataSourceCache.cs` | Connection pool cache (no change needed) |
| `GoogleSecretManagerConfigurationProvider.cs` | Loads all secrets at startup (no change needed) |

**Regex Change:**
* Current: `^[DO]-(\d{1,2})-(\d{1,3})$`
* New: `^(?:[a-z][a-z0-9]*(?:-[a-z][a-z0-9]*)*-)?[DO]-(\d{1,2})-(\d{1,3})$`

The regex supports zero or more prefix segments (each starting with a lowercase letter), followed by the DBMS marker and branch numbers. This handles unqualified (`O-10-60`), single-segment (`dispo-O-10-60`), and multi-segment (`dispo-abn-O-10-60`) identifiers. Each segment must start with `[a-z]`, preventing the DBMS marker `D`/`O` from being consumed as a prefix.

## Document History

| Date       | Author            | Change       |
| ---------- | ----------------- | ------------ |
| 2026-05-11 | Matthias Max | ADR created  |
| 2026-05-18 | Matthias Max | Extended with multi-segment prefix support for environment qualification (DEV/ABN/UAT in WL4-T-T); updated regex; added ADR-005/008 links |

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
