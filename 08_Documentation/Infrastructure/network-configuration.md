# Network Configuration

## Overview

The New Dispo infrastructure uses Google Cloud's Shared VPC architecture, with centralized network management and per-environment isolation.

**Common Settings:**
- **Region:** europe-west3 (Frankfurt)
- **Shared VPC Management:** Centralized in dedicated network projects
- **VPC Access:** Via VPC Connectors for serverless services

## VPC Architecture

### Test Environment

**VPC Name:** `vpc-c-shared-vpc-c-net-s-t`

**VPC Project:** `prj-cal-net-s-t-e004-53ad`

**Subnet:** `sn-vpc-c-net-s-t-europe-west3-common`

**Workloads:**
- WL4 Test: `prj-cal-w-wl4-t-4c48-53ad`
- WL5 Test: `prj-cal-w-wl5-t-6c00-53ad`

**Subnet Configuration:**
- Primary IP range: (To be documented - check GCP Console)
- Secondary ranges: (To be documented - for GKE, if applicable)

### Production Environment (WL4)

**VPC Name:** `vpc-c-shared-vpc-c-net-s-p`

**VPC Project:** `prj-cal-net-s-p-19c3-53ad`

**Subnet:** `sn-vpc-c-net-s-p-europe-west3-common`

**Workload:**
- WL4 Production: `prj-cal-w-wl4-p-afad-53ad`

### Production Environment (WL5)

**VPC Name:** `vpc-c-shared-vpc-c-net-s-p`

**VPC Project:** `prj-cal-net-s-p-19c3-53ad`

**Subnet:** `sn-vpc-c-net-s-p-europe-west3-common`

**Workload:**
- WL5 Production: `prj-cal-w-wl5-p-3e5b-53ad`

> **Note:** Both WL4 and WL5 production workloads share the same VPC and subnet, providing seamless connectivity between components.

## Network Tags

Network tags are used to control firewall rules and routing for Cloud Run services and Cloud Functions.

### Test Environment Tags

Applied to all test services (WL4 and WL5):
- `vpc-connector` - VPC Connector traffic
- `postgres-user` - AlloyDB/PostgreSQL client access
- `http-web-user` - HTTP client access
- `https-user` - HTTPS client access
- `p5101-user` - Port 5101 client access (custom application port)
- `p8080-user` - Port 8080 client access (custom application port)
- `https-producer` - HTTPS server/producer
- `p5101-producer` - Port 5101 server/producer
- `p8080-producer` - Port 8080 server/producer

### Production Environment Tags

> **Note:** Production network tags to be documented. Likely similar to test environment but verify in GCP Console.

### Tag Usage by Component

| Component | Key Tags | Purpose |
|-----------|----------|---------|
| TMS Bridge | `postgres-user`, `https-producer` | Access AlloyDB, serve HTTPS |
| Backend | `postgres-user`, `https-producer`, `p5101-producer` | Access CloudSQL, serve HTTPS, custom port |
| Frontend | `https-producer` | Serve HTTPS |
| Dispo Filter | `postgres-user` (via VPC) | Network access for processing |
| Cloud4Log | `https-user` | Outbound HTTPS for DigiLiS |
| CrossDock Publisher | `https-user` | Outbound HTTPS for ASB |

## Firewall Rules

Firewall rules are managed at the Shared VPC level and apply based on network tags.

### Ingress Rules

**Allow Cloud Load Balancer to Services:**
- Source: Google Cloud Load Balancer IP ranges
- Target: Services with `https-producer` tag
- Ports: 443, 8080
- Purpose: External access to Frontend and Backend via load balancer

**Allow VPC Connector:**
- Source: VPC Connector subnet ranges
- Target: All resources in VPC
- Ports: All
- Purpose: Serverless services access to VPC resources

**Allow Internal Communication:**
- Source: Subnet CIDR ranges
- Target: All resources in VPC
- Ports: Varies by service
- Purpose: Service-to-service communication

### Egress Rules

**Default Egress:**
- Allow all egress by default
- Specific restrictions if required for compliance (to be documented)

**External Service Access:**
- Allow HTTPS (443) to:
  - Azure Service Bus (CrossDock Publisher)
  - DigiLiS file share (Cloud4Log)
  - Public internet for package downloads, etc.

**Database Access:**
- AlloyDB: Private IP within VPC
- CloudSQL: Private IP via CloudSQL Proxy

## Service-to-Service Communication

### Internal Communication Patterns

**Frontend → Backend:**
- Protocol: HTTPS
- Authentication: Keycloak OAuth2 tokens (user context)
- Network: Via Cloud Load Balancer or direct service URL

**Backend → TMS Bridge:**
- Protocol: HTTPS
- Authentication: Service account impersonation or API key
- Network: Direct service URL within VPC

**Backend → Cloud4Log:**
- Protocol: HTTPS (Cloud Function HTTP trigger)
- Authentication: IAM-based
- Network: Direct function URL

**Dispo Filter → Backend (via Pub/Sub):**
- Protocol: Pub/Sub push to HTTPS endpoint
- Authentication: Pub/Sub service account
- Network: Push subscription to Backend Cloud Run URL

### External Communication Patterns

**Backend → Keycloak:**
- Protocol: HTTPS
- Network: Public endpoint (https://test.dispo.gcp.nagel-group.com/keycloak)
- Purpose: User authentication, token validation

**Cloud4Log → DigiLiS:**
- Protocol: SMB/CIFS (file share)
- Network: VPN or Cloud Interconnect to on-premises
- Authentication: Username/password

**CrossDock Publisher → Azure Service Bus:**
- Protocol: AMQP over TLS
- Network: Public Azure Service Bus endpoint
- Authentication: Connection string from Secret Manager

**Backend → TOP Service:**
- Protocol: HTTP
- Network: Internal network (http://10.32.3.102:30000)
- Purpose: Integration with TOP system

## VPC Connectivity

### VPC Connectors

VPC Connectors enable Cloud Run services and Cloud Functions to access resources in the VPC.

**Test Environment Connector:**
- Name: (Variable: `VPC_CONNECTOR`)
- Network: `vpc-c-shared-vpc-c-net-s-t`
- Subnet: `sn-vpc-c-net-s-t-europe-west3-common`
- IP Range: Dedicated /28 range
- Connected Services: All Cloud Run and Cloud Functions in test

**Production Environment Connector:**
- Name: (Variable: `VPC_CONNECTOR`)
- Network: `vpc-c-shared-vpc-c-net-s-p`
- Subnet: `sn-vpc-c-net-s-p-europe-west3-common`
- IP Range: Dedicated /28 range
- Connected Services: All Cloud Run and Cloud Functions in production

**Connector Configuration:**
- Machine type: Scales automatically based on throughput
- Min/Max instances: Automatic
- Throughput: Scales from 300 Mbps up to 10 Gbps

### Private Service Access

**CloudSQL:**
- Configured with private IP addresses
- Accessed via VPC peering (automatically managed by CloudSQL)
- No public IP exposure

**AlloyDB:**
- Private IP only
- Accessed directly within VPC
- Requires VPC connectivity for all clients

## DNS Configuration

### Internal DNS

Cloud Run services and Cloud Functions have auto-generated internal DNS names:
- Format: `<service-name>-<hash>-<region>.a.run.app`
- Resolvable within GCP and via VPC

### External DNS

**Public Endpoints:**
- `test.dispo.gcp.nagel-group.com` → Test Frontend/Backend (Cloud Load Balancer)
- `test.tms-bridge.gcp.nagel-group.com` → Test TMS Bridge (Cloud Load Balancer)
- `dispo.gcp.nagel-group.com` → Production Frontend/Backend (Cloud Load Balancer)
- `tms-bridge.gcp.nagel-group.com` → Production TMS Bridge (Cloud Load Balancer)

**DNS Provider:** (To be documented - likely Cloud DNS or corporate DNS)

**SSL/TLS Certificates:**
- Managed via Google-managed certificates or corporate CA
- Automatic renewal
- Minimum TLS 1.2

## Load Balancing

### Global HTTPS Load Balancer

**Frontend/Backend Load Balancer:**
- Type: Global HTTPS Load Balancer
- Backend: Cloud Run NEG (Network Endpoint Group)
- SSL Policy: Modern (TLS 1.2+)
- CDN: Enabled for static assets (if configured)

**Routing:**
- Host: `test.dispo.gcp.nagel-group.com` or `dispo.gcp.nagel-group.com`
- Path-based routing:
  - `/api/*` → Backend service
  - `/keycloak/*` → Keycloak service
  - `/*` → Frontend service

**TMS Bridge Load Balancer:**
- Type: Global HTTPS Load Balancer
- Backend: Cloud Run NEG
- Separate endpoint for TMS Bridge service

### Health Checks

- Protocol: HTTP or HTTPS
- Path: `/health` or `/` (depends on application)
- Check interval: 10 seconds
- Timeout: 5 seconds
- Healthy threshold: 2 consecutive successes
- Unhealthy threshold: 3 consecutive failures

## IP Addressing

### Service IP Addresses

Cloud Run services and Cloud Functions do not have static IP addresses. Outbound traffic uses:
- VPC Connector IP range (for VPC-destined traffic)
- Cloud NAT IP addresses (for internet-destined traffic)

### Cloud NAT

**Test Environment NAT:**
- NAT Gateway: (To be documented - check GCP Console)
- Static IP addresses: (To be documented)
- Purpose: Provide static IPs for outbound internet traffic

**Production Environment NAT:**
- NAT Gateway: (To be documented - check GCP Console)
- Static IP addresses: (To be documented)
- Purpose: Provide static IPs for outbound internet traffic

> **Note:** If external services require IP allowlisting, use Cloud NAT IP addresses.

## On-Premises Connectivity

### DigiLiS Access (Cloud4Log)

**Connection Method:** (To be documented - VPN, Cloud Interconnect, or public)

**Network Path:**
- Cloud4Log functions → VPC Connector → VPC → On-premises network
- Protocol: SMB/CIFS over VPN or Interconnect

### TOP Service Access (Backend)

**Connection Method:** Direct network access (internal IP: 10.32.3.102)

**Network Path:**
- Backend → VPC Connector → VPC → TOP Service
- Suggests VPN or Cloud Interconnect to internal network

**Endpoints:**
- Test: https://featuretest-top.cal-consult.int/
- XServer: http://10.32.3.102:30000

> **Note:** Detailed VPN or Interconnect configuration to be documented separately.

## Security Considerations

### Network Isolation

- Test and production environments use separate VPCs
- No direct network path between test and production
- Service accounts scoped to their respective environments

### Ingress Controls

- Cloud Run ingress: "Internal and Cloud Load Balancing" (no direct internet access)
- Cloud Functions: Require authentication (IAM) for HTTP triggers
- Public access only via Cloud Load Balancer with appropriate security controls

### Private Google Access

- Enabled on all subnets
- Allows services to access Google APIs without public IP addresses
- Required for Cloud Run, Cloud Functions, Cloud Storage, etc.

## Monitoring and Troubleshooting

### VPC Flow Logs

- Status: (To be documented - enabled/disabled)
- Sample rate: (To be documented)
- Purpose: Network traffic analysis, troubleshooting connectivity issues

### Firewall Insights

- Track firewall rule usage
- Identify unused or redundant rules
- Optimize network security posture

### Network Intelligence Center

Available tools for troubleshooting:
- Connectivity Tests: Test network paths between services
- Performance Dashboard: Monitor network performance
- Firewall Insights: Analyze firewall rule effectiveness
- Network Topology: Visualize VPC layout and connections

## Network Performance

### Expected Latencies

**Service-to-Service (same region):**
- Cloud Run to Cloud Run: < 10ms
- Cloud Run to AlloyDB: < 5ms
- Cloud Run to CloudSQL: < 5ms

**Client to Service:**
- External (via Load Balancer): 20-100ms depending on client location
- Internal: < 10ms

**Database Queries:**
- AlloyDB: Typically < 5ms for simple queries
- CloudSQL: Typically < 10ms for simple queries

### Bandwidth

- VPC Connector: Scales from 300 Mbps to 10 Gbps
- Cloud Run: Up to 32 Gbps per instance (automatic scaling)
- Inter-region traffic: Lower latency within europe-west regions

## Network Cost Optimization

### Best Practices

- Keep services in the same region (europe-west3) to avoid cross-region charges
- Use Private Google Access to avoid egress charges for Google API calls
- Minimize internet egress by keeping data processing within GCP
- Use Cloud CDN for static content delivery (if applicable)

### Cost Factors

- VPC Connector: Charged per GB of data processed
- Cloud NAT: Charged per NAT gateway + data processed
- Internet egress: Charged per GB (different rates for regions)
- Inter-region traffic: Charged per GB
