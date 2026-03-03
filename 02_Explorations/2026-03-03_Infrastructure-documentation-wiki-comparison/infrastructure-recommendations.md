# Infrastructure Recommendations and Proposals

**Status:** Proposals and recommendations for future implementation

**Last Updated:** 2026-03-03

---

> **Note:** This document contains proposed recommendations, alerting thresholds, and disaster recovery strategies that are **not yet implemented**. These are architectural proposals for future consideration, not documentation of the current system state.

---

## Monitoring and Alerting

### Integration Health Checks

**Recommended Monitoring:**
- Keycloak: Token validation success rate, authentication latency
- Azure Service Bus: Message publish success rate, queue depth
- DigiLiS: File upload/download success rate, connection failures
- TOP Service: API call success rate, response time
- TMS Database: Connection pool health, query performance

**Alerting Thresholds:**
- Error rate > 5% for any integration
- Latency > 5 seconds for critical APIs
- Connection failures > 3 consecutive attempts
- Queue backlog exceeding thresholds

### Logging

All external integration calls should be logged with:
- Request timestamp
- Request/response correlation ID
- Success/failure status
- Error messages (if applicable)
- Response time

Logs available in Cloud Logging for all services.

## Disaster Recovery

### External Service Outages

**Keycloak:**
- Impact: Users cannot authenticate (critical)
- Mitigation: Cached tokens, graceful degradation with limited functionality
- Recovery: Automated health checks, failover to backup instance (if configured)

**Azure Service Bus:**
- Impact: Events not published (degraded functionality)
- Mitigation: Queue messages locally, retry with exponential backoff
- Recovery: Resume publishing when service restored

**DigiLiS:**
- Impact: Documents not uploaded/downloaded (degraded functionality)
- Mitigation: Cloud Storage staging area retains documents, retry on next scheduled run
- Recovery: Workflow resumes automatically when service restored

**TOP Service:**
- Impact: Optimization calculations unavailable (degraded functionality)
- Mitigation: Use cached results or fallback algorithms
- Recovery: Resume calculations when service restored

**TMS Database:**
- Impact: No TMS data access (critical)
- Mitigation: High-availability AlloyDB configuration, automatic failover
- Recovery: AlloyDB automatic failover, no manual intervention needed

## Future Considerations

- Document production configurations for all integrations
- Implement comprehensive health check endpoints for all external dependencies
- Set up automated alerting for integration failures
- Regular testing of disaster recovery procedures
- Implement rate limiting and circuit breakers for external API calls
- Consider caching strategies to reduce external dependencies
