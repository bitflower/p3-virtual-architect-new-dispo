# Implementation Plan: TMS Bridge Per-System Credential Selection

**Date:** 2026-05-08
**PRD:** [03_PRD/001_TMS_Bridge_Credential_Selection/user-story-tms-bridge-credential-selection.md](../../03_PRD/001_TMS_Bridge_Credential_Selection/user-story-tms-bridge-credential-selection.md)
**Exploration:** [02_Explorations/2026-05-07_TMS_Bridge_DB_User_Selection/tms-bridge-db-user-selection.md](../../02_Explorations/2026-05-07_TMS_Bridge_DB_User_Selection/tms-bridge-db-user-selection.md)
**Selected Approach:** Prefix convention (e.g., `dispo-D-10-60`)

---

## Summary

Enable the TMS Bridge to accept system-qualified database identifiers so that each calling system (New Dispo, Cloud4Log) resolves to its own Secret Manager entry and database user. The only code change in the TMS Bridge is a regex update. The remaining work is infrastructure (Secret Manager) and caller-side configuration. Note: the New Dispo Backend is a pass-through — it extracts the `Database-Identifier` HTTP header from the frontend request and forwards it unchanged to the TMS Bridge. The caller-side change is therefore in the frontend or its configuration, not the backend.

---

## Prerequisites

- [x] **Team decision:** Prefix convention (`dispo-D-10-60`) — confirmed 2026-05-08

---

## Phase 1: TMS Bridge — Regex Update

**Component:** TMS Bridge (`Code/Disposition-Abstraction-Layer`)
**Agent:** `tms-bridge-expert`
**Risk:** Low — single-line change, backward compatible

### Task 1.1: Update schema name regex

**File:** `CALConsult.TMSBridge.API/Data/DbContexts/BranchDbContextFactory.cs:22`

Current:
```csharp
[GeneratedRegex(@"^[DO]-(\d{1,2})-(\d{1,3})$")]
```

Target:
```csharp
[GeneratedRegex(@"^(?:[a-z0-9]+-)?[DO]-(\d{1,2})-(\d{1,3})$")]
```

**Behavior:**
- `D-10-60` → still matches, captures `10` and `60` → schema `tms1060` (backward compatible)
- `dispo-D-10-60` → matches, captures `10` and `60` → schema `tms1060` (new)
- `cloud4log-O-10-60` → matches, captures `10` and `60` → schema `tms1060` (new)
- `DISPO-D-10-60` → does not match (uppercase prefix rejected by `[a-z0-9]+`)

### Task 1.2: Add unit tests

**New test cases for `GetTmsSchemaName` / `CreateDbContext`:**

| Input | Expected Schema | Description |
|---|---|---|
| `D-10-60` | `tms1060` | Existing format — no regression |
| `O-10-60` | `tms1060` | Existing format — no regression |
| `dispo-D-10-60` | `tms1060` | Prefixed identifier — new |
| `cloud4log-O-10-60` | `tms1060` | Prefixed identifier — new |
| `dispo-D-1-5` | `tms15` | Minimal numeric parts — new |
| `invalid` | `FormatException` | Reject garbage — no regression |
| `D-10-60-dispo` | `FormatException` | Reject suffix format — guard against wrong convention |
| `DISPO-D-10-60` | `FormatException` | Reject uppercase prefix — enforce convention |

### Task 1.3: Verify no other regex/validation references

Grep the TMS Bridge codebase for other places that validate or parse `databaseIdentifier` to confirm no secondary validation blocks the new format.

**Files to check:**
- `DbConnectionStringProvider.cs` — uses identifier as-is for config lookup (no change needed)
- `DbDataSourceCache.cs` — uses identifier as-is for cache key (no change needed)
- `GoogleSecretManagerConfigurationProvider.cs` — loads all secrets at startup (no change needed)

---

## Phase 2: Infrastructure — Secret Manager

**Owner:** Platform / DevOps team
**Dependency:** Phase 1 deployed (so the bridge accepts the new format)

### Task 2.1: Create per-system secrets

For each branch currently in use, create a new secret with the prefixed name containing the system-specific connection string:

| Existing Secret | New Secret (New Dispo) | Database User |
|---|---|---|
| `D-10-60` | `dispo-D-10-60` | `dispo_rw` (read-write) |
| `O-10-60` | `dispo-O-10-60` | `dispo_rw` (read-write) |

Cloud4Log can continue using the existing unqualified identifiers.

### Task 2.2: Verify secret access

Confirm that the TMS Bridge's service account has read access to the new secrets in each environment (dev, staging, prod).

---

## Phase 3: Validation

### Task 3.1: End-to-end test

1. New Dispo sends `dispo-D-10-60` → TMS Bridge resolves to `dispo-D-10-60` secret → connects with `dispo_rw` user → schema `tms1060`
2. Cloud4Log sends `D-10-60` → TMS Bridge resolves to `D-10-60` secret → connects with existing user → schema `tms1060`
3. Both use separate connection pools (verify via logging)

### Task 3.2: Verify isolation

Confirm that New Dispo and Cloud4Log database sessions use different database users by checking `current_user` in PostgreSQL logs or via a diagnostic query.

---

## Rollout Order

```
Phase 1 (TMS Bridge regex)
    │
    ├── can be deployed independently, backward compatible
    │
    ▼
Phase 2 (Secret Manager entries)
    │
    ├── secrets must exist before callers switch identifiers
    │
    ▼
Phase 3 (Validation)
```

Each phase is independently deployable. The regex change is backward compatible, so Phase 1 can go to production before any other phase begins. The caller-side change (frontend sending prefixed identifiers) is a separate work stream.

---

## Out of Scope (per PRD)

- Creating database users and permissions (DBA task)
- Caller-side changes — the `Database-Identifier` header originates from the frontend; backend is a pass-through
- Cloud4Log caller changes (can adopt qualifier later)
- Changing the GraphQL schema (already `String!`, no change needed)

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
