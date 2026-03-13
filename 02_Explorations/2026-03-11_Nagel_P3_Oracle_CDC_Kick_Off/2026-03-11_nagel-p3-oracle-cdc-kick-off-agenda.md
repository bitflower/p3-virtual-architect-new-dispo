# Nagel P3 Oracle CDC Kick Off

**Date:** 2026-03-11
**Status:** Exploration

Link: https://teams.microsoft.com/meet/39050326979606?p=6txN2RVcQCVGEmqpuZ

---

## Original User Input

> Ich sollte zwei Dinge vorbereiten als Dokument:
>
> einmal den Den isolierten Shipment Flow, wie er derzeit in Postgres umgesetzt ist mit Data Stream. Vielleicht wirklich ganz im Detail von unten nach oben aufgezählt mit dem Replication Slot, mit der Publication Mit dem Proxy, then Data Stream, then Object Store.
>
> Zweite Quelle, die aufgearbeitet werden muss, ist die Taskliste von Josef, die wir im Zuge der Schätzungen verwendet haben. Diese stellt unter anderem auch nochmal die Abhängigkeiten dar, die erfüllt sein müssen auf Nagelseite.
>
> Und drittens dann Das Transkript aus der Vorbereitung gestern mit Martin. Dort habe ich bereits die Story einmal erzählt und die verwendet auch diese beiden genannten Quellen. Alles drei zusammen ergibt dann meine Storyline für den Termin heute.

---

## Summary

Preparation for Nagel P3 Oracle CDC Kick Off meeting focusing on three key documents:

1. **Isolated Shipment Flow** - Current Postgres + DataStream CDC implementation (detailed bottom-to-top architecture)
2. **Yosif's Task List** - Estimation breakdown for two CDC options (DataStream vs Striim) with Nagel-side dependencies
3. **Meeting with Martin** - Yesterday's preparation session establishing timeline, responsibilities, and presentation structure

**Meeting Goals:**
- Present two CDC options for Oracle support (DataStream vs Striim)
- Define success criteria for POC
- Establish timeline (End of March for POC, June 1st Go-Live)
- Clarify task distribution and Nagel-side dependencies
- Secure resource commitments from Nagel team

## Analysis

### 1. Current Postgres CDC Implementation (Isolated Shipment Flow)

**Technology Stack:**
- PostgreSQL Logical Replication (native feature)
- Plugin: `pgoutput` (standard PostgreSQL logical decoding plugin)
- Google Datastream (CDC capture)
- Google Cloud Storage (change event storage)
- Cloud Functions (event filtering)
- Google Pub/Sub (event distribution)
- Backend CDC Controller (event processing)

**Bottom-to-Top Architecture:**

1. **Replication Slot Level**
   ```sql
   PG_CREATE_LOGICAL_REPLICATION_SLOT('slot_name', 'pgoutput');
   ```
   - Captures logical changes (INSERT/UPDATE/DELETE)
   - Uses PostgreSQL's native logical replication

2. **Publication Level**
   ```sql
   CREATE PUBLICATION publication_name FOR TABLE tablename;
   ```
   - Per-table configuration (NOT database-wide)
   - Currently: `sendung` table is published
   - Only tables in publication are captured

3. **Datastream Proxy/Capture**
   - Google Datastream reads from replication slot
   - Captures full row data for each change
   - Includes old and new row states

4. **Cloud Storage Bucket**
   - JSON change events written to GCS bucket
   - Full shipment row data embedded in payload
   - Organized by table/change type

5. **Cloud Function (FilterShipmentsTrigger)**
   - Triggered by bucket storage events
   - Filters shipments where `shipmentType == 'A'`
   - Forwards filtered events to Pub/Sub

6. **Pub/Sub Topic**
   - Distributes events to subscribers
   - Push subscription to Backend CDC endpoint

7. **Backend CDC Controller**
   - Endpoint: `/pubsub/consume`
   - Deserializes Pub/Sub messages
   - Routes to specific event handlers

8. **Event Handlers**
   - `NewShipmentCreatedEventHandler` - Creates Legs & Lots
   - `ShipmentUpdatedEventHandler` - Updates existing Legs & Lots
   - `DeletedShipmentEventHandler` - Removes Legs & Lots
   - **Key**: Data comes from event payload, NOT database queries

**Critical Characteristics:**
- ✅ Real-time propagation (seconds)
- ✅ Event-driven architecture
- ✅ Full row data in each event
- ❌ Does NOT query database for shipment data
- ❌ Does NOT use `v_dis_shipment_all` view
- 📝 Only 44 of 100+ `sendung` columns currently mapped

### 2. Two CDC Options for Oracle Support

#### Option A: Striim → GCP Storage

**Key Tasks:**
1. Confirm Striim version + deployment type
2. Configure bucket with prefixes to isolate Striim/Oracle events
3. Create GCP service account for Striim
4. Configure Striim client/app for POC
5. Dev testing happy paths
6. **CRITICAL: Adapter implementation**
   - Striim and Datastream have different output structures
   - Need to normalize event data structure
   - Cloud Function needs adapter to unify both formats
7. Performance testing
8. Cost collection
9. Setup/Implementation guide

**Dependencies on Nagel:**
- Striim version confirmation
- Striim deployment type (VM/Kubernetes)
- Access to Striim (UI or CLI)
- Configuration strategy alignment

#### Option B: Oracle ↔ GCP Datastream

**Prerequisites (Nagel-Side):**
1. Oracle database for development/testing with:
   - ARCHIVELOG enabled
   - Supplemental logging enabled
   - Dedicated CDC user with LogMiner privileges
2. On-premise Oracle accessible from GCP
3. Dedicated GCP environment (TEST should not be blocked)

**Key Tasks:**
1. Access requirements coordination
2. **GCP environment setup with Postgres integration**
   - Setup all CDC infrastructure (DataStream, CloudStorage, PubSub, CloudFn)
   - Integrate with dev PostgresDB to simulate test/prod
   - Use single DataStream resource with multiple connection profiles
3. Verify GCP ↔ Oracle connection (Nagel-side)
4. DataStream configuration for Oracle CDC
5. Cloud Storage Bucket adjustments
6. Cloud Function adjustments for Oracle+Postgres
7. Dev testing
8. **Database load simulation**
   - Challenge: Accessing on-prem Oracle from GCP
   - May need dedicated VM or Cloud Function
9. Performance metrics collection
10. Test redo lag gap scenario + recovery docs
11. Cost collection
12. PoC Setup Guide
13. ADR document
14. Rollout Plan document
15. Cost analysis document

**Key Advantage:**
- Reuses existing DataStream infrastructure
- No adapter needed (consistent format with Postgres CDC)
- Native GCP integration

### 3. Meeting Strategy (from Martin's Session)

**Timeline:**
- **End of March**: POC completion
- **June 1st**: Go-Live target

**Presentation Structure (Martin preparing):**
1. Motivation/Go-Live context slide
2. Technical options diagram (DataStream vs Striim)
3. Task distribution per stream

**Key Clarifications Needed:**
- CDC in this project = limited scope (one or few tables, NOT full database replication)
- Diswrapper is separate workstream (NOT part of POC)
- Two separate databases needed for CDC solutions (avoid performance issues)

**Success Criteria for POC:**
- Measurable data volume transfer
- Specific throughput per time unit
- End-to-end latency metrics
- Breaking point identification

**Team Coordination:**
- Christian: Key motivator, ensures Nagel team completes setup tasks
- Ron, Dominik Landau, Nikolai: Cloud component alignment
- Ivailo: Cloud architecture involvement (check Sofia onsite participation)
- Patrick: Nagel-side communication (CC on meeting invites)

## Findings

### Critical Decision Points

1. **DataStream vs Striim Trade-off:**
   - **DataStream**: Higher effort but reuses existing infrastructure, no adapter needed
   - **Striim**: Lower effort but requires significant adapter development
   - **Key Difference**: DataStream offers consistency and long-term maintainability vs Striim's lower initial effort

2. **Nagel-Side Dependencies are Critical:**
   - Oracle database configuration (ARCHIVELOG, supplemental logging, CDC user)
   - Network connectivity from GCP to on-premise Oracle
   - Dedicated GCP environment
   - Without these, POC cannot proceed

3. **Infrastructure Complexity:**
   - Single DataStream resource with multiple connection profiles (Postgres + Oracle)
   - Separate buckets/prefixes to avoid mixing events
   - Need to simulate production-like load from GCP to on-premise Oracle

4. **Scope Boundaries:**
   - This is NOT full database replication
   - Focus on specific tables (likely `sendung` equivalent in Oracle)
   - Diswrapper integration is separate workstream

5. **Success Criteria Must Be Defined:**
   - Specific throughput targets (events/second or rows/minute)
   - Maximum acceptable latency (end-to-end)
   - Breaking point identification
   - Cost per transaction/event

### Risk Areas

1. **Access to On-Premise Oracle:**
   - Load testing requires executing updates on Oracle
   - Cannot directly access from GCP without additional resources (VM, Cloud Function)
   - Requires additional devops effort

2. **Timeline Pressure:**
   - End of March = ~3 weeks
   - Significant effort required
   - Need Nagel team to complete prerequisites quickly

3. **Two Database Requirement:**
   - Need separate databases to avoid performance impact
   - Coordination with Nagel DBA team essential

4. **Unknowns in Oracle CDC:**
   - Oracle LogMiner performance characteristics
   - Archive log generation rate under load
   - Redo lag gap behavior and recovery procedures

## Questions/Open Items

### For Nagel Team

1. **Prerequisites Readiness:**
   - When can Oracle database with CDC configuration be provided?
   - Is ARCHIVELOG already enabled or does it need activation?
   - Who will create the dedicated CDC user with LogMiner privileges?

2. **Network Connectivity:**
   - What is the plan for GCP ↔ on-premise Oracle connectivity?
   - Timeline for VPC/network configuration?
   - Who owns this configuration on Nagel side?

3. **GCP Environment:**
   - Can we get a dedicated GCP environment (not blocking TEST)?
   - When will it be available?
   - What level of access will CAL team have?

4. **Load Testing:**
   - How will we execute update operations on on-premise Oracle from GCP?
   - Can Nagel DBA team assist with load generation?
   - Or do we need to provision dedicated VM/resources in GCP?

5. **Resource Commitment:**
   - Can Christian secure team commitment for setup tasks?
   - Who will be the Nagel-side technical lead for this POC?
   - Availability of Ron, Dominik Landau, Nikolai for cloud component alignment?

6. **Success Criteria Agreement:**
   - What throughput is acceptable? (events/second, rows/minute)
   - What is maximum acceptable latency?
   - What tables will be included in POC scope?

### For CAL Team

1. **Option Selection:**
   - Which option to pursue: DataStream or Striim?
   - Key factors: consistency with existing Postgres CDC, adapter requirements, effort trade-offs

2. **Timeline Confirmation:**
   - Is End of March realistic for POC completion?
   - How to handle June 1st go-live if POC reveals issues?

3. **Documentation Scope:**
   - Are tasks 13 (monitoring/alerting) and 14 (day-to-day operations guide) in scope?
   - ADR and Rollout Plan timing (during POC or after?)

## Related Files

### Source Documents

1. **Meeting Notes:**
   - `02_Explorations/2026-03-11_Nagel_P3_Oracle_CDC_Kick_Off/meeting-matthias-martin.md`

2. **Current Architecture:**
   - `08_Documentation/2026-02-26_leg-lot-creation-table-sendung/shipment-data-flow-architecture.md`

3. **Estimation Documents:**
   - `WIKI/Nagel-CAL-Disposition.wiki/Planning/Estimations/CDC-Oracle-Support-POC-DataStream-Option-Estimates.md`
   - `WIKI/Nagel-CAL-Disposition.wiki/Planning/Estimations/CDC-Oracle-Support-POC-Striim-Option-Estimates.md`

### Current Implementation Code

**Database Schema & CDC Configuration:**
- `Code/tms-alloydb-schema/src/sql/scripts/misc/datastream_setup.sql` - Replication slot & publication config
- `Code/tms-alloydb-schema/src/sql/view/V_DIS_SHIPMENT_ALL.sql` - View definition
- `Code/tms-alloydb-schema/src/sql/table/SENDUNG.sql` - Source table

**Cloud Functions:**
- `Code/Nagel-GCP/CALConsult.Disposition.Functions/CALConsult.Disposition.Functions.FilterShipments.Bucket/Trigger/FilterShipmentsTrigger.cs`
- `Code/Nagel-GCP/CALConsult.Disposition.Functions/CALConsult.Disposition.Functions.FilterShipments.Bucket/Dtos/GoogleBucketShipmentData.cs`

**Backend CDC:**
- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/CDC/CDCController.cs`
- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/CDC/EventHandlers/BaseEventHandler.cs`
- `Code/Disposition-Backend/CALConsult.Disposition.API/Application/Features/CDC/EventHandlers/NewShipmentCreated/NewShipmentCreatedEventHandler.cs`
- `Code/Disposition-Backend/CALConsult.Disposition.API/Infrastructure/GooglePubSub/Dtos/GoogleBucketShipmentData.cs`

**TMS Bridge:**
- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/GraphQL/Queries/ShipmentQuery/ShipmentQuery.cs`
- `Code/Disposition-Abstraction-Layer/CALConsult.TMSBridge.API/Data/DbContexts/BranchDbContext.cs`

## Related User Stories/Tasks

[To be linked]

---

## Meeting Storyline (Proposed Flow)

### 1. Context Setting
- **Goal**: Oracle CDC support for P3
- **Timeline**: POC by End of March, Go-Live June 1st
- **Scope**: Limited to specific tables (NOT full database replication)
- **Why Now**: Critical for P3 integration with New Dispo system

### 2. Current State - Postgres CDC Success Story
Walk through the **isolated shipment flow** bottom-to-top:

```
Postgres sendung table
  ↓ (logical replication)
Replication Slot (pgoutput plugin)
  ↓
Publication (per-table config)
  ↓
Google Datastream (CDC capture)
  ↓
Cloud Storage Bucket (JSON events)
  ↓
Cloud Function (FilterShipmentsTrigger)
  ↓
Pub/Sub Topic
  ↓
Backend CDC Controller
  ↓
Event Handlers (Create/Update/Delete Legs & Lots)
  ↓
Backend Database
```

**Key Points:**
- Real-time (seconds latency)
- Event-driven architecture
- Full row data in payload
- Proven in production
- Handles 44 mapped columns from sendung table

### 3. Two Options for Oracle

Present Martin's slide with both options:

**Option A: Striim → GCP Storage**
- Pros: Lower effort, Striim already deployed at Nagel
- Cons: Requires adapter, different output format, additional dependency
- Key Risk: Adapter complexity and maintenance

**Option B: Oracle ↔ GCP Datastream**
- Pros: Consistent with Postgres CDC, reuses infrastructure, no adapter needed
- Cons: Higher upfront effort, requires Oracle LogMiner setup

### 4. Nagel-Side Prerequisites (Critical)

Present **dependency map** from Yosif's task list:

**Must-Have from Nagel:**
1. ✅ Oracle database with:
   - ARCHIVELOG enabled
   - Supplemental logging enabled
   - CDC user with LogMiner privileges
2. ✅ Network connectivity: GCP ↔ on-premise Oracle
3. ✅ Dedicated GCP environment
4. ✅ DBA support for load testing or GCP access for test automation

**Timeline Impact:**
- Without prerequisites: POC cannot start
- Need confirmation: When will these be ready?

### 5. Task Distribution & Responsibilities

Show Yosif's task breakdown for DataStream option:

**CAL Team:**
- GCP infrastructure setup
- DataStream configuration
- Cloud Function adjustments
- Performance testing
- Documentation (ADR, Rollout Plan, Cost Analysis)

**Nagel Team:**
- Oracle database preparation
- Network/VPC setup
- GCP environment provisioning
- Christian: Team motivation & commitment

**Shared:**
- Load testing execution (coordinate access approach)
- Cost collection and analysis

### 6. Success Criteria Discussion

**Propose Measurable Targets:**
- Throughput: [X events/second] or [Y rows/minute]
- Latency: Maximum [Z seconds] end-to-end
- Volume: Successfully process [N records] in test
- Stability: Run for [M hours] without failure

**Ask Nagel:**
- What are acceptable thresholds?
- Which tables must be included in POC?
- What constitutes "success" for your team?

### 7. Timeline & Milestones

Present timeline visualization:

```
Today (March 11)         End of March          June 1st
    |                         |                   |
    └─ POC Start              └─ POC Complete     └─ Go-Live

Week 1-2: Prerequisites & Setup
Week 3: DataStream Configuration & Testing
Week 4: Performance Testing & Documentation
```

**Key Dates:**
- March 14: Prerequisites confirmation
- March 21: Infrastructure setup complete
- March 28: POC validation complete
- June 1: Production go-live

### 8. Next Steps & Commitments

**Immediate Actions:**
1. Nagel confirms prerequisites timeline (this week)
2. Confirm DataStream option selection (today)
3. Assign Nagel-side technical lead (today)
4. Schedule weekly POC sync meetings
5. Create shared task tracking (Yosif's list as baseline)

**Decision Needed Today:**
- [ ] DataStream vs Striim option selection
- [ ] POC scope (which tables)
- [ ] Success criteria agreement
- [ ] Resource commitment confirmation

### 9. Questions & Discussion

Open floor for:
- Technical questions
- Resource concerns
- Timeline adjustments
- Scope clarifications
