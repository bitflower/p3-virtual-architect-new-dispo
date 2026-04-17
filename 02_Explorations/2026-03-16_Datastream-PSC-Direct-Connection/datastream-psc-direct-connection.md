# Direct TMS Database Connection (Postgres) vs. via Proxy. 

**Date:** 2026-03-16
**Status:** Abandoned — never pursued

---

## Original User Input

Meeting notes from Dominik Landau (2026-03-16):

> Ok, das mit den DBs konfigurieren ist kein Problem, da können wir einfache Privat Service Connect einsetzten und dann sollte alles funktionieren.
>
> Bei dem Datastream könnte es sein, dass der proxy nicht benötigt wird, wenn wir über PSC gehen. Gibt in der Doku nichts genaues, müsste einmal ausprobiert werden.
> Unten der Momentante Aufbau, weshlb der Porxy benötigt.

**Current Architecture:** Datastream connects to AlloyDB via Private Service Connect proxy (10.64.3.2) in a peered subnet configuration.

---

## Summary

**Proposal: Test Direct Connection from Datastream to AlloyDB using Private Service Connect (PSC)**

This exploration proposes eliminating the proxy layer currently used between Datastream and AlloyDB by leveraging Private Service Connect for direct connectivity. While the proxy approach is functional, it introduces an additional network hop and potential maintenance overhead that may be unnecessary with PSC.

## Analysis

### Current Architecture
- Datastream → Private Service Connect Proxy (10.64.3.2) → AlloyDB
- Proxy sits in peered subnet between source and target
- Additional network component to configure and maintain

### Proposed Architecture
- Datastream → Private Service Connect → AlloyDB (direct)
- Eliminates intermediate proxy layer
- Simplified network topology

### Benefits of Direct Connection

1. **Reduced Complexity**
   - Fewer network components to configure and maintain
   - Simpler troubleshooting and monitoring
   - Less potential points of failure

2. **Performance**
   - Eliminates one network hop
   - Potentially lower latency
   - Reduced network overhead

3. **Cost Optimization**
   - No proxy infrastructure costs
   - Reduced network egress charges (potentially)

4. **Maintenance**
   - Fewer components to patch and update
   - Simplified security model

### Risks & Considerations

1. **Documentation Gap**
   - GCP documentation doesn't explicitly confirm whether Datastream supports PSC without proxy
   - Requires testing to validate feasibility

2. **Configuration Changes**
   - May require adjustments to Datastream connection settings
   - Need to ensure proper PSC endpoint configuration

3. **Security**
   - Must verify that direct PSC connection maintains equivalent security posture
   - Review firewall rules and access controls

## Findings

### Key Insight from Meeting
According to Dominik Landau, configuring databases with simple Private Service Connect is straightforward and should work without issues. However, for Datastream specifically, the documentation is unclear about whether the proxy can be eliminated when using PSC.

### Recommendation
**Proceed with a proof-of-concept test** to validate whether Datastream can connect directly to AlloyDB via PSC without the proxy layer.

## Test Plan

### Phase 1: Research & Preparation
1. Review GCP Datastream documentation for PSC connectivity requirements
2. Review AlloyDB Private Service Connect configuration options
3. Document current proxy configuration for rollback reference
4. Identify test Datastream job for validation

### Phase 2: Implementation
1. Configure Private Service Connect endpoint for AlloyDB
2. Attempt to configure Datastream connection directly to PSC endpoint
3. Test connection establishment
4. Validate data replication functionality

### Phase 3: Validation
1. Monitor Datastream job performance metrics
2. Compare latency and throughput with proxy-based approach
3. Verify security controls and access patterns
4. Document any configuration differences or limitations

### Phase 4: Decision
- If successful: Plan migration of production Datastream jobs
- If unsuccessful: Document limitations and maintain proxy approach

## Questions/Open Items

1. Does GCP Datastream officially support direct PSC connectivity to AlloyDB?
2. Are there any specific AlloyDB or Datastream versions/configurations required?
3. What are the security implications of direct PSC vs. proxy approach?
4. Will this change affect existing replication jobs or require reconfiguration?
5. Are there any bandwidth or performance limitations specific to PSC direct connections?

## Related Files

- Current architecture diagram: `00_Meetings/2026-03-16_Datastream-Direct-Connection-Postgres/image.png`
- Meeting notes: `00_Meetings/2026-03-16_Datastream-Direct-Connection-Postgres/readme.md`

## Next Steps

1. **Present this proposal to the client** for approval to proceed with testing
2. **Schedule POC testing window** with minimal production impact
3. **Assign technical resources** for implementation and validation
4. **Define success criteria** for the direct connection approach
5. **Create rollback plan** if direct connection proves unfeasible
