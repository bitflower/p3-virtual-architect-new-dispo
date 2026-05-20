# AI Use Cases for Dispatchers - Real-World Logistics Process Improvements

**Date:** 2026-05-20
**Status:** Exploration
**Author:** Matthias Max (Virtual Architect)

---

## Original User Input

> As a creative AI & Business consultant - what AI use cases would you identify from the Code repos of TMS Database, New Dispo Backend & Frontend, TMS Bridge that would make the life of dispatchers easier? I'm not looking for development flows that are AI-supported but real-world dispatcher & logistics processes that could benefit from AI.

---

## Summary

Analysis of TMS Database (774 tables), New Dispo Backend (CQRS/.NET 8), New Dispo Frontend (Angular 19), and TMS Bridge (GraphQL) to identify where AI could reduce dispatcher workload, improve decision quality, and accelerate logistics processes. Eight concrete use cases identified, ranked by impact and feasibility based on data readiness in the existing system.

**Key Insight:** The New Dispo system is a *manual tactical planning tool* with minimal intelligence. Dispatchers have good tools for organizing shipments into routes, but they make all key business decisions themselves. The data infrastructure to support AI is already rich - 93 history tables, comprehensive master data, real-time MDE events - but none of it is used predictively today.

---

## The Dispatcher's Day (As the Code Tells It)

### Current Flow

1. **Shipments arrive** via CDC (Change Data Capture from TMS via Google Pub/Sub)
2. **Decomposed into legs** based on traffic mode (VL = full load, HL = half load, NL = less-than-half load)
3. **Auto-grouped into lots** by basic rule matching (same origin, destination, product group, date window)
4. **Dispatchers manually build transport orders** by drag-and-drop in the Planning view
5. **Tour points sequenced** - dispatchers set pickup/delivery stops, time windows, loading references
6. **Route optimization** triggered via TOP (Transport Optimization Platform)
7. **Vehicles and drivers assigned** manually per transport order
8. **Customer notifications** sent manually (Email/EDI)

### What's "Smart" Today (Rule-Based, Not AI)

| Feature | How It Works | Limitation |
|---|---|---|
| Auto Lot Matching | `PickupPlanningSuitableLotForLegProvider` matches legs to lots by origin/destination/product/date | Binary match only, no scoring or ranking |
| Merge Suggestion | `GetLotAssignmentMergeSuggestionQuery` suggests which lot assignment to merge a leg into | Single suggestion, no alternatives offered |
| Route Calculation | TOP service optimizes tour point sequence | Only sequences given stops, doesn't suggest which stops to include |
| Lot Aggregation | Auto-sums weight, volume, floor pallets per lot | No capacity warning relative to vehicle |

---

## AI Use Cases

### Use Case 1: Intelligent Tour Composition ("Auto-Dispo")

**Dispatcher Impact:** Very High | **Data Readiness:** High | **Effort:** High

#### What dispatchers do today

Drag legs/lots one by one onto transport orders, mentally juggling:
- Capacity constraints (weight, pallet spaces, volume)
- Temperature compatibility (frozen class "04" / fresh / dry)
- Time windows (pickup from/to, delivery from/to, hard deadlines)
- Geographic proximity of pickup and delivery points
- Vehicle equipment requirements (ATP cooling, partition walls, double deck)

For every lot, they scan a list and make a match. For a typical branch with 150-200 shipments per day, this takes 2-3 hours.

#### What AI could do

Given the day's unplanned legs, propose complete transport orders - not just "which leg fits where" but "here are 12 optimized tours for tomorrow's 180 shipments." The dispatcher reviews, adjusts, approves.

#### Why it's feasible

The system already has all constraint data:
- **Vehicle capacities:** `LADERAUM_LKW` table has 100+ columns of equipment, dimensions, payload limits
- **Driver qualifications:** `FAHRER` table tracks hazmat certs (GGVS classes), license types, audit dates
- **Time windows:** `SENDUNG` has `abh_von_d/z`, `abh_bis_d/z`, `fix_von_d/z`, `fix_bis_d/z`, `fixtermin_datum/zeit`
- **Temperature classes:** Product group "04" = frozen flag in lot matching logic
- **Geographic data:** `ORT` table has coordinates, zones, regions, traffic areas for 800+ locations

The lot matching logic in `PickupPlanningSuitableLotForLegProvider` already encodes the compatibility rules. An AI layer would extend this from "find one match" to "find the global optimum across all unplanned work."

#### Dispatcher benefit

Turns 2-3 hours of manual planning into 15 minutes of review and adjustment.

---

### Use Case 2: Demand Pattern Prediction & Pre-Staging

**Dispatcher Impact:** High | **Data Readiness:** High (historical) | **Effort:** High

#### What the data shows

774 tables, 93 history tables (`PST_HST`, `SEN_HST`, etc.), archive tables (`ARCHIV_SENDUNG`, `ARCHIV_PST`) going back years. `SENDUNG` has 200+ columns including product codes, customer IDs, zones, traffic flows.

#### What AI could do

Learn recurring patterns:
- "Customer X sends ~40 pallets of frozen goods every Tuesday to the Hamburg region"
- "Volume from Region Z drops 30% in August every year"
- "Mondays after holidays always have 1.5x normal volume"

Pre-stage lot structures or draft transport orders before actual shipments arrive. Dispatchers would come into work and find tomorrow's plan 70% pre-built.

#### Data sources

- `SENDUNG` + `SEN_HST`: Historical shipment volumes by customer, route, product
- `PERS`: Customer master with recurring relationship patterns
- `ORT` + `ZONE` + `REGION`: Geographic demand clustering
- `LADELIST`: Historical loading patterns with planned vs. actual times

#### Dispatcher benefit

Reduces the morning scramble. Lets experienced dispatchers focus on exceptions rather than routine.

---

### Use Case 3: Anomaly & Exception Detection

**Dispatcher Impact:** High | **Data Readiness:** High | **Effort:** Medium

#### What dispatchers do today

They have 15+ parallel status fields on a shipment (`status_erf`, `status_dis`, `status_zus`, `status_frb`, `status_mod`, `status_abf`, `status_fak`, `status_rue`, `status_sta`, `status_1` through `status_15`) and filter/sort to find problems manually.

#### What AI could do

Flag anomalies proactively at planning time:

| Anomaly Type | Example Alert | Data Source |
|---|---|---|
| Weight outlier | "This shipment weighs 3x Customer Y's typical order - verify?" | `SENDUNG.gewicht` + historical patterns |
| Equipment mismatch | "4 frozen shipments to Region Z but no ATP vehicle available" | `SENDUNG.prod_k` + `LADERAUM_LKW` equipment flags |
| Time window squeeze | "Unloading window is 45 min - this customer averages 60+ min" | `TourpointEntity` planned times + `PST_HST` actual events |
| Certification gap | "Driver has no GGVS cert but tour contains hazmat shipment" | `FAHRER.ggvs_klassen` + `SENDUNG.gefahrgut` |
| Capacity overflow | "Tour 47 exceeds vehicle payload by 800 kg after adding this lot" | Lot aggregates + `LADERAUM_LKW.nutzlast` |
| New customer risk | "First shipment from this sender - no historical baseline" | `PERS` + `SENDUNG` history |

#### Dispatcher benefit

Catch problems at planning time instead of at the loading dock. Prevent costly re-routing, customer complaints, and regulatory violations.

---

### Use Case 4: Smart Vehicle-Driver Matching

**Dispatcher Impact:** High | **Data Readiness:** High | **Effort:** Medium

#### What dispatchers do today

Manually assign vehicles and drivers to transport orders. They need to mentally cross-reference:
- Which trucks have the right equipment (partition walls, temp recording, double deck, swap bodies)
- Which drivers have the right certifications (hazmat, license class)
- Which vehicle/driver is actually available (not already assigned, within hours regulation)
- Which driver knows the route/customers

#### What AI could do

Given a transport order's requirements, rank the available fleet and suggest the best vehicle-driver combination:

**Match dimensions:**
- Equipment fit: `VehicleEntity` attributes (AtpFrc, AtpFrb, PartitionWall, DoubleDeck, TankSilo, etc.)
- Certification match: `FAHRER.ggvs_klassen`, `FAHRER.fs_klassen` vs. tour requirements
- Route familiarity: Historical tour-driver association from `TOUR` + `FAHRER` joins
- Hours compliance: `RES_HST` resource tracking (start/duration/end per driver)
- Cost efficiency: `LADERAUM_LKW.km_satz_fuhrpark` (km rate), `tagessatz_fuhrpark` (daily rate)

#### Dispatcher benefit

Eliminates the mental fleet lookup, especially valuable when dispatchers cover for absent colleagues who don't know the fleet as well. Prevents compliance violations (wrong license, expired cert).

---

### Use Case 5: Freight Exchange Pricing Intelligence

**Dispatcher Impact:** Medium | **Data Readiness:** Medium | **Effort:** Medium

#### What dispatchers do today

Manually post transport orders to Timocom and TransEu freight exchanges. Evaluate incoming offers by gut feeling. The system supports `CreateFreightOfferCommand`, `UpdateFreightOfferCommand`, `DeleteFreightOfferCommand`.

#### What AI could do

- Recommend pricing based on historical exchange data, route distance, urgency, and current fill rate
- Flag when an incoming offer is significantly above/below market rate
- Auto-suggest which unfilled transport orders should go to the exchange based on fleet utilization
- Learn seasonal and route-specific price patterns

#### Data sources

- `FreightExchange` entities: Historical offer/acceptance data
- `ENTF_ERM_REGEL`: Distance calculation rules for route costing
- `LST_G`: Historical freight costs and tariffs
- `LADERAUM_LKW`: Vehicle cost profiles (daily rate, km rate, stop flat rate)

#### Dispatcher benefit

Better margins on outsourced transport, faster accept/reject decisions on incoming offers.

---

### Use Case 6: Customer Communication Automation

**Dispatcher Impact:** Medium | **Data Readiness:** High | **Effort:** Low-Medium

#### What dispatchers do today

Manually send emails (`SendMailCommand`) and EDI notifications (`SendToEdiCommand`). `CustomerCommunicationHistory` logs what was sent, but the content is human-composed.

#### What AI could do

Auto-generate contextual customer notifications:
- **Tour finalization:** "Your delivery is scheduled for tomorrow 09:00-10:30, 3 pallets frozen goods"
- **Exception/delay:** "Delivery delayed ~45 min due to route adjustment, new ETA: 11:15"
- **Pickup confirmation:** "Pickup confirmed for 14:00, truck license plate XX-YY-1234"

Triggered by tour state changes. Natural language, not template-fill. Personalized per customer communication preferences (Email vs. EDI vs. both).

#### Data sources

- `TourpointEntity`: Planned times, shipment counts, addresses
- `TourpointClientCommunication`: Historical communication patterns per customer
- `PERS`: Customer contact preferences
- MDE events (`DispMdeAh*`): Real-time loading/unloading triggers

#### Dispatcher benefit

Removes a repetitive manual task that directly impacts customer satisfaction. Ensures consistent, timely communication.

---

### Use Case 7: Real-Time Replanning Assistance

**Dispatcher Impact:** High | **Data Readiness:** Medium (MDE data) | **Effort:** High

#### What the system has

MDE (Mobile Data Entry) mutations show real-time events from mobile scanners:
- `DispMdeAhStartEntlandung` - unloading started
- `DispMdeAhEndeEntladung` - unloading finished
- `DispMdeAhScanBarcode` - barcode scanned
- `DispMdeAhAbschlNVE` - manifest closed

Tour points have planned vs. actual times. `RES_HST` tracks resource time windows.

#### What AI could do

When actual events deviate from plan, suggest replanning options:
- "Driver is 40 min behind - swap stops 3 and 4 to keep the time-critical delivery on track"
- "New NL shipment fits into Tour 47 without detour - add it?"
- "Vehicle breakdown on Tour 12 - here are 3 options to redistribute the remaining 4 stops"
- "Unloading at Customer Z averaging 20 min longer than planned - adjust downstream ETAs"

#### Dispatcher benefit

Reactive replanning today is pure gut feeling under time pressure. AI turns it into informed, scenario-based decision-making.

---

### Use Case 8: Capacity Utilization Insights

**Dispatcher Impact:** Medium | **Data Readiness:** High | **Effort:** Low

#### What the data shows

Every lot aggregates weight (`TotalWeight`), volume pallets (`TotalVolumePalletSpaces`), floor pallets (`TotalFloorPalletSpaces`). Transport orders track the same. Vehicles have max payload (`nutzlast`), volume (`volumen`), and dimensions.

#### What AI could do

- Real-time fill-rate dashboards with trend analysis
- "Average utilization this week: 72%. Tuesday frozen tours consistently underutilized at 58% - consolidate?"
- Predict which tours will have leftover capacity and proactively suggest adding compatible lots
- Benchmark dispatcher performance over time (not to surveil, but to surface best practices)

#### Data sources

- Lot aggregates (Backend): `LotEntity.TotalWeight`, `TotalVolumePalletSpaces`, `TotalFloorPalletSpaces`
- Vehicle capacity: `LADERAUM_LKW.nutzlast`, `volumen`, dimensions
- Historical utilization: `LADELIST` + `SENDUNG` weight/volume vs. vehicle capacity over time

#### Dispatcher benefit

Direct impact on cost efficiency. Makes the business case for AI visible to management.

---

## Build-Time vs. Runtime AI

A fundamental architectural question: are these features where AI assists during development (generating rules, heuristics, configurations deployed as deterministic code) or where AI models run during dispatcher operations (inference at request time)?

**Almost all use cases require runtime AI.** The reason is structural: dispatchers solve a *different puzzle every day*. Tuesday's 180 shipments have different origins, destinations, weights, time windows, and product mixes than Monday's. Fleet availability changes, drivers call in sick, customers add urgent orders at 7am. You can't pre-compute answers to questions that don't exist yet at build time.

| # | Use Case | AI Pattern | Rationale |
|---|---|---|---|
| 1 | Auto-Dispo | **Runtime inference** | Must solve today's specific shipment mix against today's fleet - combinatorial space too large and dynamic for pre-built rules |
| 2 | Demand Prediction | **Offline training + runtime inference** | Model learns from history (batch/train), predicts tomorrow's volume (runtime inference) |
| 3 | Anomaly Detection | **Build-time possible** | AI analyzes years of `SEN_HST`/`PST_HST` data offline, exports deterministic threshold rules ("if weight > X for customer Y, flag it"). No model inference at runtime needed. Re-run periodically to update thresholds. |
| 4 | Vehicle-Driver Match | **Runtime inference** | Depends on current availability and today's specific tour requirements |
| 5 | Freight Pricing | **Runtime inference** | Market conditions are live, pricing depends on route/urgency/fill-rate at that moment |
| 6 | Customer Comms | **Runtime generation** | LLM generates context-specific messages from current tour state and events |
| 7 | Replanning | **Runtime inference** | Entirely reactive to real-time MDE scanner events and plan deviations |
| 8 | Capacity Insights | **Hybrid** | Batch analytics on historical patterns (offline) + real-time fill-rate monitoring and suggestions (runtime) |

### The Anomaly Detection Exception

Use Case 3 is the one case where **build-time AI** is a viable and arguably better pattern. The approach:

1. Use AI to analyze years of historical data (`SEN_HST`, `PST_HST`, `SENDUNG` archives)
2. Discover what "normal" looks like per customer/route/product combination
3. Export as deterministic rules with thresholds
4. Deploy as regular validation logic - no model inference at runtime
5. Re-run the AI analysis periodically (monthly/quarterly) to update thresholds as patterns shift

**Advantages of build-time for anomaly detection:** Cheaper to operate (no inference cost per shipment), easier to explain to dispatchers ("we flag shipments over 2,400 kg for this customer because their 12-month average is 800 kg"), and the rules are fully auditable.

### Architecture Implication

For the high-impact runtime use cases (Auto-Dispo, Replanning, Vehicle-Driver Matching), the New Dispo system would need an **inference endpoint** (or embedded model/optimization solver) that dispatchers hit during their planning session. This introduces a different cost, latency, and reliability profile than the current architecture supports. Key considerations:

- **Latency:** Auto-Dispo proposals need to return in seconds, not minutes, to fit the planning workflow
- **Fallback:** If the AI service is unavailable, dispatchers must be able to continue with manual planning (graceful degradation)
- **Explainability:** Dispatchers will reject black-box suggestions - the AI must surface *why* it proposes a specific tour composition
- **Feedback loop:** Dispatcher adjustments to AI proposals are training signal - capture what they change and why

---

## Prioritization Matrix

| # | Use Case | Dispatcher Impact | Data Readiness | Effort | Recommended Phase |
|---|---|---|---|---|---|
| 1 | Auto-Dispo (Tour Composition) | Very High | High | High | Phase 2 (flagship) |
| 3 | Anomaly & Exception Detection | High | High | Medium | Phase 1 (quick win) |
| 4 | Vehicle-Driver Matching | High | High | Medium | Phase 1 (quick win) |
| 8 | Capacity Utilization Insights | Medium | High | Low | Phase 1 (quick win) |
| 6 | Customer Communication Auto | Medium | High | Low-Medium | Phase 1 (quick win) |
| 2 | Demand Prediction & Pre-Staging | High | High | High | Phase 2 |
| 7 | Replanning Assistance | High | Medium | High | Phase 3 |
| 5 | Freight Exchange Pricing | Medium | Medium | Medium | Phase 3 |

**Recommended approach:** Start with Phase 1 (Anomaly Detection, Vehicle-Driver Matching, Capacity Insights, Customer Comms) to build trust and demonstrate value with lower-risk, data-ready use cases. Then tackle Auto-Dispo as the flagship Phase 2 project once dispatchers trust AI-generated suggestions.

---

## Source Code Evidence

| Component | Key Files / Patterns | Relevance |
|---|---|---|
| **Lot Matching** | `PickupPlanningSuitableLotForLegProvider` | Encodes compatibility rules - foundation for AI matching |
| **Merge Suggestion** | `GetLotAssignmentMergeSuggestionQuery` | Multi-level matching (location > product > consignee) - extendable |
| **Route Optimization** | `RecalculateRouteService` + TOP integration | External optimization exists but only for sequencing |
| **CDC Pipeline** | `PubSubMessageHandler` + Event Handlers | Real-time shipment ingestion - trigger point for predictions |
| **MDE Events** | `DispMdeAh*` mutations in TMS Bridge | Real-time operational signals for replanning |
| **Vehicle Equipment** | `VehicleEntity` (12+ equipment attributes) | Rich constraint data for matching |
| **Driver Certs** | `FAHRER` table (hazmat, license classes) | Certification compliance data |
| **Historical Data** | 93 `*_HST` / `*_TS` / `ARCHIV_*` tables | Deep history for learning patterns |
| **Status System** | 15+ status fields on `SENDUNG` | Complex state = complex exception detection surface |
| **Customer Comms** | `SendMailCommand` / `SendToEdiCommand` | Existing email/EDI infrastructure to augment |
| **Freight Exchange** | `FreightExchange` feature (Timocom/TransEu) | Marketplace integration already built |

---

## Open Questions

To sharpen these use cases, the following operational knowledge is needed:

1. **Decision drivers:** How do dispatchers actually decide which legs belong together? Is it pure geography + product, or are there unwritten rules (driver-customer relationships, preferred routes, depot politics)?
2. **Work split:** What's the ratio of planned work (regular customers, recurring volumes) vs. reactive work (spot market, urgent orders)?
3. **Time allocation:** Where do dispatchers spend most of their *thinking* time vs. most of their *clicking* time?
4. **Failure modes:** What goes wrong most often, and what's the cost when it does? (Missed time windows? Underutilized trucks? Wrong equipment at customer site?)
5. **Regional variation:** How much do planning patterns differ between branches/depots? Can a model trained on one branch transfer to another?
6. **Dispatcher trust:** What's the appetite for AI suggestions? Would dispatchers accept "here's a full plan, adjust as needed" or only "here's a ranked list of options"?

---

## Related Files

- `Code/Disposition-Frontend/` - Angular 19 dispatcher UI (Planning view, Transport Orders, Drive Instructions)
- `Code/Disposition-Backend/` - .NET 8 CQRS backend (lot matching, TO planning, CDC, route calc)
- `Code/Disposition-Abstraction-Layer/` - TMS Bridge GraphQL API (42 mutations, master data, MDE events)
- `Code/tms-alloydb-schema/` - TMS Database (774 tables, 832 views, 93 history tables)
- `Code/CALConsult.TOP/` - Tour Optimization Platform (route sequencing)
