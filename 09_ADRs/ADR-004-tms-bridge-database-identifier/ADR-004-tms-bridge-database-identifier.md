# [ADR004] TMS Bridge Database Identifier Naming Convention

**Status:** Draft
**Date:** 2026-01-27

## Context

The TMS Bridge system provides a GraphQL gateway for accessing and manipulating data across multiple TMS databases within the Nagel Group. These databases may use different database management systems (Oracle or PostgreSQL via AlloyDB) and are distributed across multiple countries, companies, and branches. The system already uses a database identifier format to route requests to the correct database instance, but the current format is ambiguous and does not meet business needs for multi-country support.

* **TMS Bridge**: A standalone system providing GraphQL API access to TMS databases.
* **TMS Databases**: Multiple database instances across different countries, each potentially using Oracle or PostgreSQL.
* **APIM**: Azure API Management layer routing requests to TMS Bridge endpoints.
* **Consumer Systems**: EBV, Cloud4Log, and New Dispo systems currently consuming TMS Bridge APIs.

The original implementation used an ambiguous identifier pattern where the first character was interpreted inconsistently. The prefix "D" was initially intended to represent "Deutschland" (Germany) but was inadvertently conflated with database type detection, where "D" routed to AlloyDB (Postgres) and "O" routed to Oracle. This created a critical architectural ambiguity discovered during discussions with Nagel IT architects.

**Note:** The actual decision whether a database is Oracle or PostgreSQL is made at runtime based on the connection string structure, not the identifier prefix. The `DbConnectionStringProvider.GetVendorName()` method (`DbConnectionStringProvider.cs`) inspects the connection string using regex patterns — PostgreSQL strings contain `Host=`, `Port=`, `Database=` while Oracle strings contain `User Id=`, `Data Source=`. This means the DBMS prefix in the identifier is technically redundant for database type resolution and serves purely as a human-readable convention.

The naming convention must address the following organizational structure within Nagel Group:
* **DBMS Type**: Oracle or PostgreSQL
* **Country**: Germany (D), Austria (AT), Poland (PL), etc.
* **Company**: Numeric identifier (01-99)
* **Branch**: Numeric identifier (01-99)

Key requirements include:

1. **Unambiguous Database Type Identification**: Clearly distinguish between Oracle and PostgreSQL databases.
2. **Country Identification**: Support multiple countries with standardized country codes.
3. **Company and Branch Identification**: Support the existing Nagel Group organizational hierarchy.
4. **Consistency with Nagel Standards**: Align with the de facto standard `{COUNTRY}-{COMPANY}-{BRANCH}` pattern used across Nagel systems.
5. **Production Compatibility**: Address breaking changes for systems already in production (specifically EBV).
6. **Future Extensibility**: Allow for growth to additional countries and database instances.

#### Options Considered

**For Database Identifier Format:**

* **Option A: Omit DB Type (Organization-Focused)**
  * Pattern: `{COUNTRY}-{COMPANY}-{BRANCH}`
  * Examples: `D-10-34`, `PL-04-30`, `SE-28-20`
  * Database type determined from connection string configuration only

* **Option B: Include DB Type Prefix (Technology-Focused)**
  * Pattern: `{DBMS}-{COUNTRY}-{COMPANY}-{BRANCH}`
  * Examples: `P-D-10-34` (Postgres, Germany, Company 10, Branch 34), `O-AT-01-01` (Oracle, Austria, Company 01, Branch 01), `P-SE-28-20` (Postgres, Sweden, Company 28, Branch 20)
  * Database type explicitly visible in identifier

* **Option C: Simplified Notation (Current Production)**
  * Pattern: `{PREFIX}{COMPANY}{BRANCH}` (no separators)
  * Examples: `D52` (currently interpreted as Postgres), `D10` (currently interpreted as Oracle)
  * Ambiguous and inconsistent

**For Scope:**

* **Include "Landesgruppe" (Country Group)**: Add an additional organizational hierarchy level used in newer systems (Zentrale Stammdaten, OMS, INV).
* **Exclude "Landesgruppe"**: Keep the pattern focused on existing TMS organizational structure.

## Decision

1. **Database Identifier Format:**
   * **Decision:** Option B - Include DB Type Prefix
   * Pattern: `{DBMS}-{COUNTRY}-{COMPANY}-{BRANCH}`
   * DBMS values: `O` (Oracle), `P` (Postgres)
   * All segments separated by hyphens

2. **Scope:**
   * **Decision:** Exclude "Landesgruppe" from the identifier pattern
   * This concept is not supported in TMS and the effort to add it later is equivalent to adding it now

## Rationale

* **DB Type Prefix (Option B)**: While the initial architectural instinct favored omitting the database type to maintain separation of concerns between organizational hierarchy and technical infrastructure, the decision to include the prefix was made for pragmatic reasons:
  * **User Familiarity**: Easier for operators and developers to identify which database type they are working with at a glance
  * **Troubleshooting**: Simplifies debugging and operations by making the database type immediately visible
  * **APIM Routing**: Supports existing routing patterns in the API Management layer
  * **Production Reality**: EBV is already live in production using a DB type prefix pattern; maintaining this pattern reduces migration risk
  * **DEV/TEST Environments**: In non-production environments, both Oracle and PostgreSQL instances of the same branch can be connected to a single TMS Bridge simultaneously. Without the DBMS prefix, identifiers would conflict since country, company, and branch alone would not be unique.

* **Organization-Only Pattern (Option A)**: Rejected despite cleaner separation of concerns because:
  * Database type is operationally relevant information during the migration period where both Oracle and Postgres coexist
  * The abstraction benefit does not outweigh the practical usability concerns
  * Would require more complex configuration mapping from identifier to connection string

* **Simplified Notation (Option C)**: Unacceptable because:
  * Ambiguous prefix usage (D for Deutschland conflated with database type)
  * No separator makes parsing complex for multi-digit companies/branches
  * Violates Nagel Group's de facto standard pattern
  * Limited scalability to other countries

* **Excluding Landesgruppe**: The country group concept from newer systems is not yet supported in TMS. Including it now would add complexity without immediate value. Excluding it means accepting that there will be migration effort now to adopt the new identifier pattern, and again later if Landesgruppe is added. This trade-off is accepted to avoid overloading the current decision's impact and effort scope.

## Migration and Impact

**Breaking Change Notice**: This naming convention change represents a breaking change for all existing TMS Bridge consumers.

**Affected Systems:**
* **EBV (In Production)**: Currently using simplified notation (`D52`, `D10`) with hardcoded mappings in APIM
  * D52 → Postgres
  * D10 → Oracle
  * **Coordinated Change Required**: APIM configuration must be updated simultaneously with TMS Bridge deployment

* **Cloud4Log**: Currently integrated with TMS Bridge, impact assessment required

* **New Disposition**: Currently integrated with TMS Bridge, impact assessment required

**Migration Strategy:**
1. Implement new identifier pattern in TMS Bridge code with backward compatibility support
2. Coordinate with APIM team to update routing rules
3. Deploy changes in coordinated release window
4. Update consumer system configurations
5. Remove backward compatibility support in subsequent release

**Implementation Requirements:**
* Update RegEx pattern for database identifier validation
* Update API documentation and consumer guidelines
* Create migration guide for consumer systems
* Implement validation warnings for deprecated patterns

## Consequences

* **Positive**:
  * Eliminates ambiguity between country codes and database types
  * Builds on Nagel Group's standard `{COUNTRY}-{COMPANY}-{BRANCH}` pattern by prepending the DBMS type prefix
  * Supports multi-country expansion (Germany, Austria, Poland, etc.)
  * Provides clear, self-documenting identifiers for operations and troubleshooting
  * Consistent separator usage simplifies parsing and validation
  * Prepares for future database migration scenarios

* **Negative**:
  * Breaking change requiring coordinated deployment across multiple systems
  * EBV production system requires immediate attention and careful migration
  * Exposes infrastructure details (database type) in the application-layer identifier
  * All existing API consumers must update their identifier formats
  * Documentation and training materials require updates
  * Potential for confusion during migration period with both patterns in use

## Related ADRs

* [ADR-001: Data Exchange Between TMS and CALSuite's Cross-Dock](../ADR-001-data-exchange-tms-calsuite-cross-dock/ADR-001-data-exchange-tms-calsuite-cross-dock.md) - Provides context on TMS Bridge system architecture

## References

**Code Implementation:**
* TMS Bridge repository: Disposition-Abstraction-Layer
* File: `CALConsult.TMSBridge.API/Data/DbContexts/BranchDbContextFactory.cs`

**RegEx Patterns:**
* Current pattern: `^[DO]-(\d{1,2})-(\d{1,3})$`
  * `[DO]` — single letter, D or O (1 char, alphabetic)
  * `\d{1,2}` — company, 1–2 digits (numeric)
  * `\d{1,3}` — branch, 1–3 digits (numeric)
* New pattern: `^[OP]-([A-Z]{1,2})-(\d{1,2})-(\d{1,3})$`
  * `[OP]` — DBMS type, O (Oracle) or P (Postgres) (1 char, alphabetic)
  * `[A-Z]{1,2}` — country code, 1–2 uppercase letters (e.g., D, AT, PL, SE)
  * `\d{1,2}` — company, 1–2 digits (numeric)
  * `\d{1,3}` — branch, 1–3 digits (numeric)

**Examples of Correct Identifiers:**
* `P-D-10-34` (Postgres, Germany, Company 10, Branch 34)
* `O-D-10-90` (Oracle, Germany, Company 10, Branch 90)
* `P-A-01-01` (Postgres, Austria, Company 01, Branch 01)
* `O-PL-04-30` (Oracle, Poland, Company 04, Branch 30)
* `P-SE-28-20` (Postgres, Sweden, Company 28, Branch 20)

## Document History

| Date | Author | Change |
|------|--------|--------|
| 2026-01-08 | Pascal Leicht, Nikolay, Matthias Max | Internal discussion on database identifier patterns |

| 2026-01-27 | Virtual Architect | ADR created |
