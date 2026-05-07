# User Story: TMS Bridge Per-System Credential Selection

## Problem Statement

The TMS Bridge currently resolves each database identifier (e.g., `D-10-60`) to exactly one Secret Manager entry and therefore one set of database credentials. Both New Dispo and Cloud4Log connect through the same bridge and share the same database user per branch.

Cloud4Log requires **read-only** access (QM user), while New Dispo requires **read-write** access. With the current 1:1 mapping, both systems are forced to use the same user, making it impossible to enforce least-privilege access per calling system.

## Business Need

As the system moves toward Go-Live, database access must be scoped per calling system to meet security and operational requirements. Sharing a single write-capable user across systems increases blast radius in case of bugs or misconfiguration and prevents audit trail separation.

## User Story

**As** a platform operator,
**I want** the TMS Bridge to support system-qualified database identifiers (e.g., `dispo-D-10-60` or `D-10-60-dispo`),
**so that** each calling system resolves to its own Secret Manager entry and database user with appropriately scoped permissions.

## Acceptance Criteria

- [ ] The TMS Bridge accepts database identifiers with an optional system qualifier (prefix or postfix, per team decision) in addition to the existing format
- [ ] Identifiers without a qualifier (e.g., `D-10-60`) continue to work unchanged (backward compatibility)
- [ ] A qualified identifier (e.g., `dispo-D-10-60`) resolves to its own Secret Manager entry, independent of the unqualified identifier
- [ ] A qualified identifier resolves to the same TMS schema as its unqualified counterpart (e.g., `dispo-D-10-60` and `D-10-60` both resolve to schema `tms1060`)
- [ ] Qualified and unqualified identifiers maintain separate connection pools (separate database sessions / credentials)
- [ ] Invalid identifiers (e.g., missing company/branch numbers) are rejected with a clear error message

## Out of Scope

- Creating the actual Secret Manager entries per system/branch (infrastructure task)
- Changing the database identifiers sent by New Dispo Backend or Cloud4Log (caller-side changes)
- Defining which database user permissions each system requires (DBA task)

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
