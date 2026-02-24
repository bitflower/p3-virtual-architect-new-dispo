# TMS Database Architecture: Entity Differentiation and Extension Mechanisms

> Created with the help of AI (not 100% reliable)

## Overview

This document captures the findings from investigating how the `sendung` table in the TMS (Transport Management System) database handles multiple business entities and the sophisticated extension mechanisms that support this architecture.

## Core Question Investigated

**How does the `sendung` table differentiate between different business entities (shipments, transport orders, etc.) and where in the codebase are these differentiations made?**

## Key Findings

### 1. Primary Entity Differentiation Mechanism: `sendungsart` Column

The primary mechanism for entity differentiation in the `sendung` table is the `sendungsart` column:

```sql
-- From sendung table structure
sendungsart character(1) NOT NULL
```

**Entity Types Identified:**
- `'S'` - Transport Orders (Transportaufträge)
- `'A'` - Shipments (Sendungen) 
- `'F'` - Freight documents
- `'Z'` - Additional shipment types
- `'U'` - Other business entities

### 2. View-Based Entity Switching: v_ta Example

The `v_ta` view demonstrates how entity switching works at the database level:

```sql
-- v_ta view filters for transport orders specifically
CREATE OR REPLACE VIEW v_ta AS
SELECT [columns...]
FROM sendung s
WHERE s.sendungsart = 'S'  -- Only Transport Orders
```

**Key Insight:** Views act as **entity-specific interfaces** to the generic `sendung` table, filtering by `sendungsart` to present the appropriate business entity context.

### 3. The res_hst/res_hst_zus Extension Pattern

A sophisticated **Entity-Attribute-Value (EAV)** pattern provides dynamic extension capabilities:

#### Core Architecture

**res_hst (Resource History)** - The "narrow" base table:
```sql
CREATE TABLE res_hst (
    res_hst_tix numeric(22,0) NOT NULL,  -- Primary key
    ref_tix numeric(22,0),               -- FK to sendung (transport order)
    art numeric(3,0),                    -- Resource type
    typ numeric(3,0),                    -- Resource subtype  
    start_e timestamp,                   -- Start time
    end_e timestamp,                     -- End time
    lfd_n numeric(6,0)                   -- Sequence number
);
```

**res_hst_zus (Resource History Additional)** - The "wide" extension table:
```sql
CREATE TABLE res_hst_zus (
    res_hst_tix numeric(22,0) NOT NULL,  -- FK to res_hst
    lfd_n numeric(4,0) NOT NULL,         -- Sequence within res_hst
    typ numeric(3,0),                    -- Data type classifier
    key character varying(255),          -- Dynamic column name
    t character varying(2000),           -- Generic string value
    art numeric(3,0) NOT NULL            -- Additional classifier
);
```

#### Design Principles

From the developer comments:
- **"Rows instead of columns" mindset** for faster feature adjustments (no strict schema/DDL)
- **All database fields stored as strings** and cast to target format as needed
- **Contains constants used in hundreds of functions**
- **Designed for rapid feature development** without schema changes

#### Connection to sendung Table

```sql
-- res_hst links to sendung via ref_tix
res_hst.ref_tix → sendung.sendung_tix (where sendungsart = 'S')

-- res_hst_zus provides unlimited dynamic attributes
res_hst_zus.key = 'PERS_TIX' → Person reference
res_hst_zus.key = 'VKSTROM' → Traffic flow
res_hst_zus.key = 'fahr_anw' → Driving instructions
res_hst_zus.key = 'RES' → Resource key
```

### 4. Function-Based API Layer

The system provides a rich API through the `reshst` package functions that abstract the complexity:

#### Time-based Functions
```sql
reshst.getankunfte(res_hst_tix)     -- Get arrival time
reshst.getabfahrte(res_hst_tix)     -- Get departure time  
reshst.getladstarte(res_hst_tix)    -- Get loading start time
reshst.getladende(res_hst_tix)      -- Get loading end time
```

#### Data Retrieval Functions
```sql
reshst.getopt(res_hst_tix, 'key')   -- Get optional value by key
reshst.getzus(res_hst_tix, typ)     -- Get additional data by type
reshst.getstpl_c(res_hst_tix)       -- Get pallet spaces
reshst.getgew(res_hst_tix)          -- Get weight
```

#### Navigation Functions
```sql
reshst.getfirst(sendung_tix, typ)   -- Get first resource of type
reshst.getlast(sendung_tix, typ)    -- Get last resource of type
reshst.getsenbelad2(ta_tix, sen_tix) -- Get loading point for shipment
reshst.getsenentl2(ta_tix, sen_tix)  -- Get delivery point for shipment
```

### 5. Type System and Constants

The system uses numeric codes for different data types:

#### Resource Types (art/typ)
- `typ = 1` - Loading points (Beladepunkte)
- `typ = 3` - Delivery points (Entladepunkte)  
- `typ = 7` - Intermediate stops
- `typ = 100` - Shipment references
- `typ = 999` - Person references

#### Usage Examples in Views

**Person Reference Pattern:**
```sql
-- V_TOUR view shows dynamic person data retrieval
WHERE ((z.res_hst_tix = h.res_hst_tix) 
   AND (z.typ = (999)::numeric) 
   AND ((z.key)::text = 'PERS_TIX'::text) 
   AND (p.tix = oracle.to_number((z.t)::text)))
```

**Shipment Reference Pattern:**
```sql
-- V_TA_SEN view shows shipment linking
WHERE ((z.typ = (100)::numeric) 
   AND (NULLIF(rtrim((z.key)::text), ''::text))::numeric = s.sendung_tix)
```

### 6. Related Table Ecosystem

The investigation revealed a rich ecosystem of related tables that support the entity differentiation:

#### Core Supporting Tables
- **SEN_TB** - Transport participants (Transportbeteiligte)
- **SEN_ZUORD** - Many-to-many associations supporting circular relationships
- **SEN_LAND** - Optional country-specific data
- **sen_pos_*** - Position-related tables (mostly legacy from airfreight)

#### Service and Financial Tables
- **lst_k** - Service tree and amounts (service header)
- **lst_b** - Service participants
- **sen_ber** - Shipment calculations (optional)
- **frankatur** - Cost allocation between sender and recipient

#### Document Management Tables
- **send_ls** - Delivery notes (M:N relationship)
- **sen_pst** - Packages related to shipments
- **text_sendung** - Multiple free-text entries per shipment
- **text_in_position** - Free text per shipment position

#### Master Data Integration
- **frk** - Freight card shipment master data
- **bordero**, **rollkart**, **ladelist**, **ebordero** - Various freight document types
- **freier_tarif** - Additional tariff storage level

### 7. Developer Insights from Comments

Key insights from the core development team:

#### On res_hst Table
> "Resources table. The table name is inconsistent, so 'hst' is disregarded in meaning. REF_TIX is used as a foreign key to SENDUNG (in the sense of a transport order) but no actual constraint is enforced. In practice, only SENDUNG entries are referenced, so enforcing a real constraint is possible. The table is very narrow with most data stored in REST_HST_ZUS."

#### On res_hst_zus Table  
> "Stores all types of data — an 'all-purpose' table. Includes delivery dates, opening hours, delivery restrictions, and possible links to SENDUNG. Designed with a 'rows instead of columns' mindset for faster feature adjustments (no strict schema/DDL). Contains constants used in hundreds of functions. All database fields are stored as strings and cast to the target format as needed."

#### On sendung Table
> "Stores various business entities such as transport orders, shipments, and legs. Introduced in the context of airfreight. SEN_ZUORD table Acts as a related table with sendung, supporting many-to-many associations via IDs and allowing circular relationships."

### 8. Practical Implementation Examples

#### Equipment Management
```sql
-- Equipment data stored dynamically in res_hst_zus
reshst.getopt(ts.res_hst_tix, ptourort_lib.getzuskey_eqm()) AS eqm,
reshst.getopt(ts.res_hst_tix, ptourort_lib.getzuskey_eqm_schaden_t()) AS eqm_damage
```

#### Transport Planning
```sql
-- Dynamic transport attributes
reshst.getankunfte(belad.res_hst_tix) AS abs_ankunft_soll_e,
reshst.getladstarte(belad.res_hst_tix) AS abs_lad_start_soll_e,
reshst.getsenbelad2(ta.ta_tix, ta.sen_tix) AS belad_tix
```

#### Tour Management
```sql
-- Tour point management with dynamic person data
FROM res_hst h,
     res_hst_zus z,
     v_pers2 p
WHERE ((z.res_hst_tix = h.res_hst_tix) 
   AND (z.typ = (999)::numeric) 
   AND ((z.key)::text = 'PERS_TIX'::text) 
   AND (p.tix = oracle.to_number((z.t)::text)))
```

## Architecture Benefits

### 1. Flexibility
- **Schema Evolution**: New attributes can be added without DDL changes
- **Rapid Development**: "Faster feature adjustments" as noted by developers
- **Multi-Entity Support**: Single table supports multiple business entities

### 2. Performance Optimizations
- **Cached Functions**: Functions like `reshst.cachepunkt()` optimize access
- **Indexed Access**: Strategic indexing on key columns
- **Function-Based Interface**: Abstracts complexity from application layer

### 3. Data Integrity
- **Type Safety**: Functions provide typed access to string data
- **Validation**: Business logic embedded in function layer
- **Consistency**: Centralized access patterns through API functions

## Architecture Challenges

### 1. Complexity
- **Learning Curve**: Requires deep understanding of type codes and keys
- **Documentation**: Complex relationships need thorough documentation
- **Debugging**: Harder to trace data flow through generic structures

### 2. Performance Considerations
- **String Storage**: Overhead of storing all data as strings
- **Casting Operations**: Runtime type conversion costs
- **Query Complexity**: Complex joins across extension tables

### 3. Maintenance
- **Schema Discovery**: Dynamic schema makes structure discovery difficult
- **Data Migration**: Complex when restructuring dynamic attributes
- **Testing**: Comprehensive testing of dynamic behaviors required

## Integration Patterns

### Entity Differentiation + Dynamic Extensions

The architecture demonstrates a sophisticated combination:

1. **sendungsart** determines the **entity type** (Transport Order vs Shipment)
2. **res_hst/res_hst_zus** provides **dynamic attributes** for transport orders
3. **Function API** provides **type-safe access** to dynamic data
4. **Views** create **entity-specific interfaces** to the generic structures

### Historical Evolution

The system shows evidence of **30+ years of evolution**:
- **Legacy Support**: Tables like `sen_pos_artikel` marked as "Relic from Airfreight"
- **Incremental Enhancement**: Extension patterns added over time
- **Backward Compatibility**: Old structures maintained alongside new patterns

## Recommendations for Working with This Architecture

### 1. Understanding the Layers
- **Physical Layer**: sendung + res_hst + res_hst_zus tables
- **Logical Layer**: reshst.* function API
- **Presentation Layer**: Entity-specific views (v_ta, etc.)

### 2. Development Patterns
- **Use Functions**: Always access dynamic data through reshst.* functions
- **Understand Types**: Learn the typ/art code system thoroughly  
- **Follow Conventions**: Use established key naming patterns
- **Cache Awareness**: Leverage cached functions for performance

### 3. Debugging Strategies
- **Trace Through Layers**: Follow data from view → function → table
- **Understand Type Codes**: Keep reference of typ/art meanings
- **Use Comments**: Leverage the detailed comments.sql insights
- **Test Dynamic Behavior**: Verify extension data thoroughly

## Conclusion

The TMS database architecture represents a sophisticated solution to the challenge of supporting multiple business entities within a unified data model. The combination of:

- **sendungsart-based entity differentiation**
- **res_hst/res_hst_zus dynamic extension pattern**  
- **Function-based API abstraction**
- **View-based entity interfaces**

Creates a flexible yet structured system that has successfully evolved over decades to meet complex transportation logistics requirements. While the architecture introduces complexity, it provides the flexibility needed for a domain with rapidly changing business requirements and diverse entity types.

The key insight is that **entity switching happens at multiple levels**:
1. **Database level**: Through sendungsart filtering in views
2. **Extension level**: Through res_hst_zus dynamic attributes  
3. **API level**: Through reshst.* function interfaces
4. **Application level**: Through entity-specific views and business logic

This multi-layered approach provides both the **flexibility** needed for complex business requirements and the **structure** needed for maintainable software systems.
