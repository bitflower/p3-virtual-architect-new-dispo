# GCP Cloud Run: Public Access vs Require Authentication

**Date:** 2026-05-26
**Status:** Exploration
**Trigger:** Observed during meeting (Martin, Mihailo, Matthias) that environments have inconsistent authentication settings on Cloud Run services, blocking Cloud4Log development on dev.

---

<internal>

## Original User Input

Screenshots from a meeting (2026-05-26) comparing two GCP projects in the Cloud Run services console. One project (WL5-dev) has services configured with **"Allow unauthenticated invocations"** (public), while another project has services set to **"Require authentication"**.

</internal>

---

## Status Quo

**WL5-dev project — services set to "Allow unauthenticated" (public):**

![WL5-dev Cloud Run services with public access](wl5-dev-public-services.png)

**Other project — services set to "Require authentication":**

![Other project Cloud Run services requiring authentication](other-project-require-auth.png)

---

## Summary

GCP Cloud Run has an **Authentication** setting per service that controls whether the GCP infrastructure gate checks caller identity before forwarding requests to the container. The two options are:

| Setting | Meaning | Risk |
|---------|---------|------|
| **Allow unauthenticated** | No Google OIDC identity token needed at the infrastructure gate. | No IAM-level caller verification. |
| **Require authentication** | Caller must present a valid Google OIDC token with `roles/run.invoker` permission. Unauthenticated requests get **403 Forbidden**. | Access controlled via IAM. |

**Important nuance:** "Allow unauthenticated" does **not** automatically mean "publicly reachable from the internet." It only controls the IAM check. A separate setting — **ingress** — controls network reachability. The combination `--allow-unauthenticated` + `--ingress internal` means: no OIDC token required, but only VPC-internal traffic can reach the service. The GCP console's "Authentication" column (visible in the screenshots above) shows only the IAM setting, not the ingress setting — which can be misleading.

## Analysis

### What "Public" Actually Means

When a Cloud Run service is set to "Allow unauthenticated invocations":
- GCP removes the IAM check at the ingress layer
- The service URL (e.g., `https://my-service-xyz.run.app`) is reachable by anyone
- No credentials, tokens, or identity proof is required
- The request hits your container code directly

This is appropriate for **public-facing endpoints** (websites, public APIs, webhook receivers) but **not for internal services**.

### What "Require Authentication" Means

- Every HTTP request must include an `Authorization: Bearer <ID_TOKEN>` header
- The token must be a valid Google OIDC identity token
- The caller's service account must have `roles/run.invoker` on the target service
- GCP rejects unauthorized requests **before** they reach the container

### Service-to-Service Authentication (e.g., Cloud Function calling Cloud Run)

Configuring a Cloud Function to call a "Require authentication" service is **minimal effort**:

**Step 1 — IAM binding (one-time, per caller-target pair):**

Via `gcloud`:

```bash
gcloud run services add-iam-policy-binding TARGET_SERVICE \
  --member="serviceAccount:CALLING_SERVICE_SA@PROJECT.iam.gserviceaccount.com" \
  --role="roles/run.invoker" \
  --region=REGION
```

Via Terraform:

```hcl
# Ensure the target Cloud Run service requires authentication
resource "google_cloud_run_v2_service" "target_service" {
  name     = "target-service"
  location = "europe-west1"

  template {
    containers {
      image = "gcr.io/my-project/target-service:latest"
    }
    service_account = google_service_account.target_sa.email
  }
}

# Service account for the calling Cloud Function
resource "google_service_account" "calling_function_sa" {
  account_id   = "calling-function-sa"
  display_name = "Calling Cloud Function Service Account"
}

# Grant the calling function's SA the invoker role on the target service
resource "google_cloud_run_v2_service_iam_member" "invoker" {
  name     = google_cloud_run_v2_service.target_service.name
  location = google_cloud_run_v2_service.target_service.location
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.calling_function_sa.email}"
}
```

**Step 2 — Code change (fetch and attach ID token):**

```csharp
var targetUrl = "https://my-service-xyz.run.app/api/something";

var credential = await GoogleCredential.GetApplicationDefaultAsync();
var oidcToken = await credential
    .GetOidcTokenProvider()
    .GetOidcTokenAsync(OidcTokenOptions.FromTargetAudience(targetUrl));

var httpClient = new HttpClient();
httpClient.DefaultRequestHeaders.Authorization =
    new AuthenticationHeaderValue("Bearer", await oidcToken.GetAccessTokenAsync());

var response = await httpClient.GetAsync(targetUrl);
```

The Google SDK handles **token refresh** automatically. If a shared `HttpClient` wrapper is used, this logic is written once.

### Effort Assessment

| Task | Effort |
|------|--------|
| IAM binding per service pair | ~1 `gcloud` command or 1 Terraform resource |
| Code: fetch + attach ID token | ~5-10 lines, done once in a shared HTTP client |
| Overall | Low — no reason to leave internal services public to avoid this |

## Key Takeaway

"Allow unauthenticated" alone is not the security risk — it depends on the **ingress** setting. The combination `--ingress internal` + `--allow-unauthenticated` is a valid posture: the service is unreachable from the internet, and Keycloak handles application-level access control within the VPC. Adding GCP IAM "Require authentication" on top provides defense in depth, but introduces an `Authorization` header conflict with Keycloak (see [below](#the-authorization-header-conflict--why-require-authentication--keycloak-is-not-straightforward)).

## Caller Authentication Code Analysis

Code analysis of all three components that call the TMS Bridge reveals a critical distinction: **all existing authentication is Keycloak-based (application-level), not GCP OIDC-based (infrastructure-level)**. These are two independent layers.

### Authentication per Caller

| Caller | Calls TMS Bridge? | Auth Mechanism | Token Type |
|--------|-------------------|---------------|------------|
| **New Dispo Backend** | Yes (GraphQL) | Keycloak JWT | Application-level Bearer token |
| **Cloud4Log** | Yes (GraphQL) | Keycloak OAuth2 client_credentials | Application-level Bearer token |
| **New Dispo Cloud Functions** | No | N/A — communicates via Pub/Sub, not HTTP | N/A |

### New Dispo Backend

The Backend attaches Keycloak JWT tokens to every TMS Bridge request via `GraphQLQueryService.cs`. Two token sources:

- **Primary:** Pass-through of the `Authorization` header from the incoming Frontend request
- **Fallback** (for PubSub background jobs): Fresh token from Keycloak via `client_credentials` grant (`KeycloakTokenProvider.cs`)

```
GraphQLQueryService.cs:
  var token = _httpContextAccessor.HttpContext?.Request.Headers["Authorization"].FirstOrDefault();
  if (string.IsNullOrEmpty(token))
      token = await keycloakTokenService.GetAccessTokenAsync();  // client_credentials
  _client.HttpClient.DefaultRequestHeaders.Authorization =
      new AuthenticationHeaderValue("Bearer", token.Replace("Bearer ", ""));
```

No Google OIDC tokens are used. The Backend does not call `GoogleCredential.GetApplicationDefaultAsync()` for TMS Bridge communication.

### Cloud4Log

Cloud4Log fetches a Keycloak token via OAuth2 `client_credentials` grant. Credentials are stored in **Google Secret Manager** (secret: `keyCloakConfig`).

```
KeycloakHttpClient.cs → GetAccessTokenAsync():
  1. Fetch keyCloakConfig from Secret Manager
  2. POST to Keycloak token endpoint with client_id + client_secret
  3. Return access_token

GraphQlRequestService.cs → EnsureDefaultHeadersSet():
  var token = await keycloakClient.GetAccessTokenAsync();
  client.HttpClient.DefaultRequestHeaders.Authorization =
      new AuthenticationHeaderValue("Bearer", token.Replace("Bearer ", ""));
```

Thread-safe single initialization via `SemaphoreSlim`. No Google OIDC tokens are used.

### New Dispo Cloud Functions

These functions do **not** call the TMS Bridge directly. They read shipment data from GCS buckets and publish filtered events to Pub/Sub topics. Authentication is only to GCP services via Application Default Credentials (ADC). The downstream consumer of the Pub/Sub messages handles TMS Bridge communication.

### Implication for "Require Authentication" on Cloud Run

The two authentication layers are **independent and cumulative**:

| Layer | Purpose | Currently used? |
|-------|---------|----------------|
| **GCP IAM (infrastructure)** | Google OIDC token proves caller SA has `roles/run.invoker` — checked by Cloud Run *before* request reaches container | **No** — no caller sends OIDC tokens |
| **Keycloak (application)** | JWT proves application-level access — checked by TMS Bridge code *inside* the container | **Yes** — Backend and Cloud4Log both send Keycloak tokens |

Enabling Cloud Run "Require authentication" on the TMS Bridge would **reject all requests** even from callers that already send Keycloak tokens, because GCP checks for a Google OIDC token *before* the request reaches the container. The Keycloak JWT is irrelevant at the infrastructure layer.

To enable "Require authentication," each caller needs an additional ~5-10 lines to fetch and attach a Google OIDC token (see code example above), plus an IAM binding granting `roles/run.invoker` to each caller's service account.

## Official GCP Documentation

- [Authenticating service-to-service | Cloud Run](https://docs.cloud.google.com/run/docs/authenticating/service-to-service) — primary guide
- [Authenticate for invocation | Cloud Run Functions](https://docs.cloud.google.com/functions/docs/securing/authenticating) — Cloud Functions specific
- [Authentication overview | Cloud Run](https://docs.cloud.google.com/run/docs/authenticating/overview)
- [Service Identity | Cloud Run](https://docs.cloud.google.com/run/docs/securing/service-identity)

## Current Blocker (from meeting + chat 2026-05-26)

### Two separate layers at play

The follow-up chat (Matthias, Yosif, Mihailo) revealed that the blocker involves **two distinct layers**, not one:

| Layer | What it controls | Dev status |
|-------|-----------------|------------|
| **1. Network / Ingress** | Can the caller's HTTP request even *reach* the service URL? | **Blocked** — services not publicly accessible, no private DNS |
| **2. GCP IAM (infrastructure)** | Does the caller present a valid Google OIDC token with `run.invoker`? | **Not implemented** — no caller sends OIDC tokens (see [Caller Authentication Code Analysis](#caller-authentication-code-analysis)) |
| **3. Keycloak (application)** | Does the caller present a valid Keycloak JWT? | **Already handled** — Backend and Cloud4Log send Keycloak Bearer tokens |

**Yosif's key insight:** *"This is not about authentication and authorization but rather about component visibility and accessibility."*

Cloud4Log and the Backend **already implement Keycloak token-based auth** when calling the TMS Bridge. The actual blocker is **network reachability** — the Cloud Functions simply can't reach the TMS Bridge or Keycloak endpoints on dev.

### Error evidence from dev

Mihailo shared a Cloud Run log entry showing the actual failure:

![Cloud Run 403 error on dev](image.png)

```
POST 403 0ms → https://dev-uploaddeliverynotesfunction-...run.app/
"The request was not authenticated. Either allow unauthenticated invocations or set the
proper Authorization header. Empty Authorization header value."
```

This confirms that on dev, **"Require authentication" is active on the Cloud Functions themselves** — and the trigger (Pub/Sub push or GCS event) fails to invoke the function with a valid Google OIDC token. The function never executes at all. This is Layer 2 (GCP IAM) blocking before Layer 3 (Keycloak) even comes into play.

### Three legs that must work

For Cloud4Log to function, three communication legs must all succeed:

```
[Trigger: Pub/Sub / GCS event]           [Keycloak]           [TMS Bridge]
           │                                  │                      │
           │  Leg 1: invoke function          │                      │
           ├─────────────► [Cloud Function] ──┤                      │
           │               (Cloud Run)        │  Leg 2: get token    │
           │                                  │◄─────────────────────┤
           │                                  │  (client_credentials)│
           │                                  │                      │
           │                                  │  Leg 3: GraphQL call │
           │                                  ├─────────────────────►│
           │                                  │  (Bearer: KC token)  │
```

| Leg | From → To | Purpose | Blocked on dev? |
|-----|-----------|---------|----------------|
| **1** | Trigger → Cloud Function | Invoke the function | **Yes** — 403, missing OIDC token |
| **2** | Cloud Function → Keycloak | Get Keycloak access token | **Yes** — network unreachable |
| **3** | Cloud Function → TMS Bridge | GraphQL query with Keycloak token | **Yes** — network unreachable |

### Pipeline and wiki evidence — test/prod are already internal

The initial assumption (from the GCP console screenshots) was that test/prod are "public." **This is incorrect.** The GCP console's "Authentication" column only shows the IAM setting. The actual deployment pipelines and wiki tell a different story:

**TMS Bridge Azure Pipelines — both test and prod deploy with:**

```yaml
--allow-unauthenticated \
--ingress internal
```

- **Prod** (`azure-pipelines-cloudrun-p-p.yml:167-168`): Introduced by Nikolay Hristov, Feb 24, 2025
- **Test/WL5** (`azure-pipelines-cloudrun-t-t-wl5.yml:165,170`): Introduced by Nikolay Hristov, May 20, 2025

**Wiki Network-Configuration.md confirms this is standard for ALL services:**

> "All Cloud Run services are configured with `--ingress internal`"
> "All Cloud Run services are configured with `--vpc-egress all-traffic`"

**Established architectural intent** (from `02_Explorations/2026-03-22_Cloud4Log-Blocker-Clarification/blocker-clarification.md`, written by Matthias Max):

> "The TMS Bridge was designed and built together with Christian. It was initially considered as an API gateway but that decision was revoked early on. **The TMS Bridge is an internal component providing access to TMS data for internal consumers only.**"

**No ADR or formal decision for `--allow-unauthenticated`:** Searched all ADRs, explorations, and meeting notes back to 2024. No documented architecture decision exists for the `--allow-unauthenticated` flag. It was added by Nikolay as a deployment configuration without documented rationale. The wiki (`Why-TMS-Bridge.md`) states Keycloak Bearer tokens are required — no mention of GCP IAM auth.

**Nikolay's statement "TMS Bridge was created to work with public access"** likely refers to the `--allow-unauthenticated` flag (no OIDC required), not to `--ingress all` (internet-reachable). The pipelines confirm ingress is `internal`.

### Environment comparison (corrected)

| Environment | Ingress | IAM (GCP console "Authentication" column) | Keycloak | Internet-reachable? | Result |
|-------------|---------|------------------------------------------|----------|-------------------|--------|
| **Test** | `internal` | Allow unauthenticated | Yes | **No** | Works — VPC egress + Keycloak |
| **Prod** | `internal` | Allow unauthenticated | Yes | **No** | Works — VPC egress + Keycloak |
| **Dev** | `internal` (?) | **Require authentication** | Yes | **No** | **Blocked** — triggers get 403, network unreachable |

Test and prod already implement `--ingress internal` + `--allow-unauthenticated` + Keycloak. This is **Option 1** from the protection options below. The dev environment is the anomaly — it additionally has "Require authentication" (GCP IAM), which blocks both the Cloud Function triggers and (if they could run) the outgoing calls.

### Why the team can't fix it themselves

- They lack **DevOps permissions** on the shared VPC project for the dev environment
- They **cannot create a private DNS zone** to enable internal communication
- Load balancers were created for Keycloak and TMS Bridge on dev, but **don't work** because the services aren't reachable
- Nikolay said the **TMS Bridge was created to work with public access**

### Private DNS zone is NOT required

Mihailo suggested creating a private DNS zone for internal communication. After research: **this is not the right approach**. GCP provides two built-in mechanisms for Cloud Function → Cloud Run communication without public access:

| Approach | How it works | Overhead |
|----------|-------------|----------|
| **Direct VPC egress** (recommended) | Cloud Function routes egress through VPC. Traffic is recognized as "internal" by Cloud Run. | Config-only, no extra infra, scales to zero cost |
| **Serverless VPC Access Connector** | Dedicated connector attaches function to VPC | Runs Compute Engine VMs (always-on cost) |

**How it works:** When a Cloud Function's egress routes through a VPC in the same project, Cloud Run recognizes the traffic as "internal" — even when using the standard `*.run.app` URL. No private DNS, no special URLs, no load balancers needed.

**Setup (Direct VPC egress):**

```hcl
resource "google_cloud_run_v2_service" "tms_bridge" {
  name     = "tms-bridge"
  location = "europe-west1"
  ingress  = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  # ... rest of config
}

resource "google_cloudfunctions2_function" "my_function" {
  name     = "my-function"
  location = "europe-west1"

  service_config {
    vpc_connector_egress_settings = "ALL_TRAFFIC"
    # Direct VPC egress — no connector needed
    vpc_connector = null
  }
  # ... rest of config
}
```

**Critical detail:** The Cloud Function's egress must be set to **`ALL_TRAFFIC`** (not just private IPs), otherwise the request to the `*.run.app` URL goes via the internet and gets rejected as non-internal.

**Shared VPC caveat:** The dev environment uses a shared VPC where the team lacks permissions. Mihailo stated: *"we don't have permissions to create anything on that project where shared VPC is for Dev environment."* However, Direct VPC egress does **not** require creating infrastructure in the host project. It only needs the host project admin to:
1. Share a specific subnet with the service project (WL5-dev)
2. Grant `compute.networkUser` on that subnet to the Cloud Run service agent

Both are one-time IAM grants. The actual Direct VPC egress configuration happens entirely in WL5-dev where the team **does** have permissions. This is a much lighter ask than creating and managing DNS zones in the host project.

### The `Authorization` header conflict — why "Require authentication" + Keycloak is not straightforward

The mid-term plan originally said: "enable GCP IAM `Require authentication` on TMS Bridge + keep Keycloak auth." Code analysis reveals a **fundamental conflict** that makes this harder than expected:

**Problem:** HTTP has one `Authorization` header. Cloud Run "Require authentication" and Keycloak both use it.

| Step | Who checks | What's in `Authorization` header | What happens |
|------|-----------|--------------------------------|--------------|
| 1. GCP infrastructure gate | Cloud Run IAM | Must be Google OIDC token | 403 if missing/invalid — request never reaches container |
| 2. Application code | TMS Bridge (Keycloak validation) | Must be Keycloak JWT | Rejected if missing/invalid |

If the caller sends a **Google OIDC token** in `Authorization`: GCP gate passes, but TMS Bridge rejects it (not a Keycloak JWT).
If the caller sends a **Keycloak token** in `Authorization`: GCP gate rejects it (not a Google OIDC token). Request never reaches container.

**You cannot satisfy both layers with a single `Authorization` header.**

### Protection options for TMS Bridge

Given the three protection layers (network, GCP IAM, Keycloak) and the header conflict, four realistic options exist:

---

#### Option 1: Internal network + Keycloak only (recommended — already active on test/prod)

| Layer | Setting | Status |
|-------|---------|--------|
| Network | `--ingress internal` | **Already active** on test/prod (pipeline-confirmed) |
| GCP IAM | Allow unauthenticated | **Already active** on test/prod |
| Application | Keycloak JWT validation | **Already implemented** in all callers |

**How it works:**
- TMS Bridge ingress set to "Internal only" — blocks all internet traffic
- Cloud Functions use Direct VPC egress (`ALL_TRAFFIC`) — traffic routed through VPC, recognized as "internal"
- Backend (also Cloud Run in same VPC) reaches TMS Bridge internally
- Keycloak token flow continues unchanged — no code changes needed

**What's protected:**
- TMS Bridge URL is unreachable from outside the VPC
- Within the VPC, Keycloak JWT validation ensures only authorized callers succeed
- Attack surface: VPC-internal only (not the entire internet)

**Current state:** Test and prod already run this configuration. The wiki (`Network-Configuration.md`) documents `--ingress internal` + `--vpc-egress all-traffic` as the standard for all services.

**To unblock dev:**
- Set Cloud Functions and TMS Bridge on dev to `--allow-unauthenticated` (matching test/prod)
- Ensure Cloud Functions on dev have VPC egress configured (matching test/prod)
- Ensure Keycloak is reachable from within the VPC on dev
- Code: **None**

**Applies to all three legs:**

| Leg | Solution |
|-----|----------|
| Trigger → Cloud Function | Set Cloud Function to "Allow unauthenticated" (trigger is internal via Pub/Sub/Eventarc) OR grant trigger SA `run.invoker` |
| Cloud Function → Keycloak | Internal via VPC egress (Keycloak must also be internal or reachable) |
| Cloud Function → TMS Bridge | Internal via VPC egress + Keycloak Bearer token |

---

#### Option 2: Internal network + GCP IAM + custom header for Keycloak

| Layer | Setting | Status |
|-------|---------|--------|
| Network | `INGRESS_TRAFFIC_INTERNAL_ONLY` | Change needed |
| GCP IAM | Require authentication | Change needed |
| Application | Keycloak JWT via **custom header** | Code change in all callers + TMS Bridge |

**How it works:**
- Caller sends **Google OIDC token** in `Authorization` header (GCP gate validates this)
- Caller sends **Keycloak token** in a custom header, e.g., `X-Keycloak-Authorization`
- GCP gate passes the request (OIDC is valid)
- TMS Bridge reads Keycloak token from `X-Keycloak-Authorization` instead of `Authorization`

**What's protected:**
- Network isolation (internal only)
- Infrastructure-level identity verification (only SAs with `run.invoker` can call)
- Application-level authorization (Keycloak JWT)
- Strongest protection — defense in depth

**Effort:**
- Everything from Option 1, PLUS:
- IAM: Grant `run.invoker` to Backend SA and Cloud4Log SA per environment
- **Code change — TMS Bridge:** Read Keycloak token from `X-Keycloak-Authorization` header (fallback to `Authorization` for backwards compatibility during migration)
- **Code change — Cloud4Log:** Add `DelegatingHandler` to GraphQL HttpClient that fetches OIDC token via `GoogleCredential.GetApplicationDefaultAsync()` and sets `Authorization` header. Move Keycloak token to `X-Keycloak-Authorization`. Cloud4Log already has the DelegatingHandler pattern (used by Markant integration in `MarkantAuthHeaderHandler`)
- **Code change — Backend:** Same OIDC + custom header logic. Backend currently creates `GraphQLHttpClient` directly (no `IHttpClientFactory` pipeline) — would need refactoring or inline logic in `GraphQLQueryService.cs`

**Cloud4Log DelegatingHandler sketch:**

```csharp
public class GoogleOidcHandler : DelegatingHandler
{
    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken ct)
    {
        // Move existing Keycloak token to custom header
        if (request.Headers.Authorization is { Scheme: "Bearer" } keycloak)
            request.Headers.Add("X-Keycloak-Authorization", $"Bearer {keycloak.Parameter}");

        // Set Google OIDC token for Cloud Run gate
        var credential = await GoogleCredential.GetApplicationDefaultAsync();
        var oidc = await credential.GetOidcTokenProvider()
            .GetOidcTokenAsync(OidcTokenOptions.FromTargetAudience(
                request.RequestUri!.GetLeftPart(UriPartial.Authority)));
        request.Headers.Authorization =
            new AuthenticationHeaderValue("Bearer", await oidc.GetAccessTokenAsync());

        return await base.SendAsync(request, ct);
    }
}
```

Registration in `TMSBridgeSetupExtensions.cs`:
```csharp
.AddHttpMessageHandler<GoogleOidcHandler>()  // insert before retry policy
```

---

#### Option 3: Internal network + GCP IAM, drop Keycloak for service-to-service

| Layer | Setting | Status |
|-------|---------|--------|
| Network | `INGRESS_TRAFFIC_INTERNAL_ONLY` | Change needed |
| GCP IAM | Require authentication | Change needed |
| Application | OIDC identity replaces Keycloak for S2S | Significant refactor |

**How it works:**
- Service-to-service calls use Google OIDC only — no Keycloak roundtrip
- TMS Bridge validates OIDC token issuer + caller SA identity
- Keycloak is kept **only** for user-facing auth (Frontend → Backend)
- Backend still needs Keycloak for user context, but uses OIDC for TMS Bridge infra auth

**What's protected:**
- Same as Option 2

**Effort:**
- **High** — TMS Bridge authorization model needs redesign
- Must handle two auth models (user-context via Keycloak, service-context via OIDC)
- Cloud4Log simplifies (remove Keycloak dependency, just use ADC)
- Backend complicates (must still convey user identity somehow)

---

#### Option 4: Public access + Keycloak only (not currently used — was incorrectly assumed for test/prod)

| Layer | Setting | Status |
|-------|---------|--------|
| Network | `INGRESS_TRAFFIC_ALL` | **Not active** — test/prod use `--ingress internal` |
| GCP IAM | Allow unauthenticated | Already active |
| Application | Keycloak JWT validation | Already implemented |

**What's protected:**
- Only Keycloak JWT validation — nothing at network or infrastructure level
- TMS Bridge URL would be reachable from the entire internet
- Protection relies entirely on application-level token validation

**Effort:**
- Would require changing ingress from `internal` to `all` — a **downgrade** from current test/prod security

This option was initially assumed to be the status quo on test/prod based on the GCP console "Authentication" column, but pipeline analysis proved this wrong. Test/prod already use the more secure Option 1. **This option should not be pursued.**

---

### Option comparison

| | Network | GCP IAM | Keycloak | Code changes | Effort | Security | Status |
|---|---------|---------|----------|-------------|--------|----------|--------|
| **Option 1** | Internal | — | Existing | None | Low | Good | **Already on test/prod** |
| **Option 2** | Internal | OIDC | Custom header | All callers + TMS Bridge | Medium | Best | Not implemented |
| **Option 3** | Internal | OIDC | Dropped for S2S | TMS Bridge redesign | High | Best | Not implemented |
| **Option 4** | Public | — | Existing | None | None | Weak | **Not in use** (initial misreading) |

### Recommendation

**Option 1 (Internal network + Keycloak) is already the production standard.** Test and prod have been running this configuration since Nikolay's pipeline setup (Feb 2025 for prod, May 2025 for test). The dev environment is the only anomaly.

The fix is to **align dev with test/prod** — not to migrate test/prod to a new model:

- Set Cloud Functions and TMS Bridge on dev to `--allow-unauthenticated` + `--ingress internal`
- Ensure VPC egress is configured for Cloud Functions on dev (test/prod already use `--vpc-egress all-traffic`)
- Ensure Keycloak is reachable from within the VPC on dev
- **Zero code changes needed** — the Keycloak auth flow works as-is

Option 2 (adding GCP IAM on top) remains available as a future hardening step, but the `Authorization` header conflict makes it a non-trivial change across three codebases. It should only be pursued if a security audit explicitly requires infrastructure-level identity verification beyond network isolation + Keycloak.

**Action plan:**

| Step | What | Effort | Owner |
|------|------|--------|-------|
| **1. Align dev** | Set Cloud Functions + TMS Bridge + Keycloak on dev to `--allow-unauthenticated` + `--ingress internal` + VPC egress | Config only | Christian/DevOps + Nikolay |
| **2. Verify VPC egress on dev** | Confirm Cloud Functions on dev have `--vpc-egress all-traffic` and the shared VPC subnet is shared with WL5-dev | Config check | Mihailo + Nikolay |
| **3. Optional future hardening** | Add "Require authentication" + OIDC handler + custom header (Option 2) | Code changes in TMS Bridge, Backend, Cloud4Log | Only if security audit requires it |

### GCP Documentation — Private Networking

- [Private networking and Cloud Run](https://docs.cloud.google.com/run/docs/securing/private-networking) — overview of internal communication
- [Restrict ingress for Cloud Run](https://docs.cloud.google.com/run/docs/securing/ingress) — ingress settings explained
- [Direct VPC egress](https://docs.cloud.google.com/run/docs/configuring/vpc-direct-vpc) — recommended approach (no connector)
- [Compare Direct VPC egress and VPC connectors](https://cloud.google.com/run/docs/configuring/connecting-vpc)
- [Direct VPC egress with Shared VPC](https://docs.cloud.google.com/run/docs/configuring/shared-vpc-direct-vpc)

### Action items

- [ ] Matthias: Escalate to Christian/DevOps — align dev Cloud Functions + TMS Bridge + Keycloak with test/prod config (`--allow-unauthenticated` + `--ingress internal` + `--vpc-egress all-traffic`)
- [ ] Check with Mihailo + Nikolay (2026-05-27): Confirm VPC egress and shared VPC subnet config on dev — raise that test/prod already have the correct setup, dev just needs to match
- [ ] Yosif is the right contact for mock data / database topics on dev (not Mihailo)

## gcloud Verification (2026-06-08)

Live `gcloud` query of all three WL5 environments, run by Matthias Max.

### TMS Bridge — Cross-Environment Comparison

| Setting | **Dev** (`prj-cal-w-wl5-d-d048-53ad`) | **Test** (`prj-cal-w-wl5-t-6c00-53ad`) | **Prod** (`prj-cal-w-wl5-p-3e5b-53ad`) |
|---------|--------|--------|--------|
| **Service name** | `cal-new-disposition-tmsbridge-d-d` | `cal-new-disposition-tmsbridge-t-t` | `cal-new-disposition-tmsbridge-p-p` |
| **Region** | europe-west3 | europe-west3 | europe-west3 |
| **Ingress** | `internal-and-cloud-load-balancing` | `internal` | `internal` |
| **IAM (`run.invoker`)** | IAP SA only | `allUsers` | `allUsers` |
| **IAP enabled** | **Yes** | No | No |
| **Default URL** | Disabled | Enabled | Disabled |
| **VPC egress** | `all-traffic` | `all-traffic` | `all-traffic` |
| **Service Account** | `94140780561-compute@developer.gserviceaccount.com` (default) | `wl5-cloudrun@...t-6c00-53ad` (custom) | `wl5-cloudrun@...p-3e5b-53ad` (custom) |
| **Min instances** | 0 (scales to zero) | 1 | 1 |
| **Max instances** | 10 | 100 | 25 |
| **Concurrency** | 80 | 60 | 80 |
| **CPU / Memory** | 1 vCPU / 1 Gi | 1 vCPU / 1 Gi | 1 vCPU / 1 Gi |
| **CloudSQL** | — | `cal-new-disposition-psql-t-t` | — |
| **Shared VPC** | `vpc-c-shared-vpc-c-net-s-d` | `vpc-c-shared-vpc-c-net-s-t` | `vpc-c-shared-vpc-c-net-s-p` |
| **Last deployed** | 2026-06-05 | 2026-06-05 | 2026-06-02 |

### IAM Policy Details

**Dev:**
```
bindings:
- members:
  - serviceAccount:service-94140780561@gcp-sa-iap.iam.gserviceaccount.com
  role: roles/run.invoker
```

**Test:**
```
bindings:
- members:
  - allUsers
  role: roles/run.invoker
```

**Prod:**
```
bindings:
- members:
  - allUsers
  role: roles/run.invoker
```

### Key Findings

**1. Dev uses IAP (Identity-Aware Proxy) — not just "Require authentication"**

The exploration originally assumed dev had simple GCP IAM "Require authentication" (i.e., callers need an OIDC token with `run.invoker`). The actual config is more complex: dev has **IAP enabled** (`run.googleapis.com/iap-enabled: true`). IAP is a separate Google infrastructure layer that sits in front of a Cloud Load Balancer, intercepts requests, and enforces Google-managed authentication before traffic reaches Cloud Run. Only the IAP service account (`service-94140780561@gcp-sa-iap.iam.gserviceaccount.com`) has `roles/run.invoker` — all traffic must flow through IAP → Load Balancer → Cloud Run. This explains both the `internal-and-cloud-load-balancing` ingress (IAP requires a load balancer) and the disabled default URL (traffic must enter via the LB, not direct Cloud Run URL).

**2. Dev uses the default Compute Engine service account**

Test and prod use a dedicated `wl5-cloudrun@...` service account. Dev uses the default Compute Engine SA (`94140780561-compute@developer.gserviceaccount.com`). This is a security anti-pattern — the default SA has `Editor` role on the project, granting far more permissions than needed.

**3. Dev has no minimum instances**

Test and prod keep at least 1 instance warm. Dev scales to zero, adding cold start latency.

**4. Ingress setting divergence confirms the blocker**

Test/prod use `--ingress internal` — only VPC-internal traffic reaches the service. Dev uses `--ingress internal-and-cloud-load-balancing` — traffic can come from internal sources OR through a Cloud Load Balancer with IAP. This is a fundamentally different networking model. Cloud Functions on dev cannot reach the TMS Bridge via direct VPC egress the way they can on test/prod, because the IAP layer intercepts.

**5. All environments share the same VPC egress pattern**

All three environments have `--vpc-access-egress: all-traffic` and are connected to the shared VPC. The network plumbing is consistent — the divergence is purely at the ingress/auth layer.

### Impact on Recommendation

The original recommendation (align dev with test/prod) remains correct, but the scope is slightly larger than assumed:

| Change needed on dev | Original assumption | Actual state |
|---------------------|---------------------|--------------|
| **Authentication** | Switch from "Require authentication" to "Allow unauthenticated" | Switch from **IAP-gated** to "Allow unauthenticated" — also requires removing IAP config and potentially the load balancer |
| **Ingress** | Already `internal` | Switch from `internal-and-cloud-load-balancing` to `internal` |
| **Service Account** | Already correct | Switch from **default Compute SA** to dedicated `wl5-cloudrun` SA |
| **Min instances** | Not discussed | Set to 1 to match test/prod |

### All Cloud Run Services on Dev (for reference)

| Service | Ingress |
|---------|---------|
| `cal-new-disposition-backend-d-d` | `internal-and-cloud-load-balancing` |
| `cal-new-disposition-frontend-d-d` | `internal-and-cloud-load-balancing` |
| `cal-new-disposition-keycloak-d-d` | `internal-and-cloud-load-balancing` |
| `cal-new-disposition-tmsbridge-d-d` | `internal-and-cloud-load-balancing` |
| `dev-download-proofofdelivery-function` | `internal` |
| `dev-downloadproofofdeliveryfunction` | `internal` |
| `dev-upload-deliverynotes-function` | `internal` |
| `dev-uploaddeliverynotesfunction` | `internal` |

All four core services (Backend, Frontend, Keycloak, TMS Bridge) on dev use `internal-and-cloud-load-balancing` with IAP. The Cloud Functions use `internal`. This confirms the IAP/LB pattern was applied project-wide to the core services on dev, not just TMS Bridge.

---

## Questions/Open Items

### Resolved by pipeline/wiki analysis

- [x] **What is the ingress setting on test/prod?** → `--ingress internal` (confirmed in both Azure Pipelines and wiki `Network-Configuration.md`). Test/prod are NOT publicly reachable from the internet.
- [x] **What does "TMS Bridge is created to work with public access" mean?** → Likely refers to `--allow-unauthenticated` (no OIDC required), not `--ingress all` (internet-reachable). Pipelines confirm ingress is `internal`. No ADR or formal decision documented — appears to be a deployment configuration choice by Nikolay, not an architectural requirement.
- [x] **Is there a mid-term migration needed for test/prod?** → No. Test/prod already implement Option 1 (internal ingress + allow unauthenticated + Keycloak). Only dev needs alignment.

### Resolved by gcloud verification (2026-06-08)

- [x] **Nikolay follow-up (2026-05-27):** Confirm dev environment config — **Dev uses IAP + `internal-and-cloud-load-balancing` ingress. Only the IAP service account has `run.invoker`. Default URL is disabled. This is a fundamentally different setup from test/prod.** Verified via `gcloud run services describe` + `get-iam-policy`.
- [x] **VPC egress on dev** → `all-traffic` — matches test/prod. VPC egress is consistent across all environments.
- [x] **Service accounts per environment** → Dev: `94140780561-compute@developer.gserviceaccount.com` (default, should be changed). Test: `wl5-cloudrun@prj-cal-w-wl5-t-6c00-53ad.iam.gserviceaccount.com`. Prod: `wl5-cloudrun@prj-cal-w-wl5-p-3e5b-53ad.iam.gserviceaccount.com`.

### Still open

- [ ] Is the shared VPC subnet shared with WL5-dev, and does the Cloud Run service agent have `compute.networkUser`?
- [ ] Is Keycloak reachable from within the VPC on dev? (EBV integration hit the same issue: "TMS Bridge KeyCloak not reachable from APIM" — meeting notes 2025-07-22)
- [ ] Who configured IAP on dev and why? Was this a deliberate security choice or a Nikolay/DevOps experiment? No ADR or documented decision found.
- [ ] Can the IAP config + load balancer on dev be safely removed, or do other consumers depend on it?
- [ ] If Option 2 (GCP IAM) is ever pursued: the following callers need `run.invoker` on the TMS Bridge — **New Dispo Backend** SA and **Cloud4Log** SA. Exact SAs now confirmed for test and prod (see table above). Dev SA needs to be migrated from default Compute SA first.

## Related Files

- Screenshots: `00_Meetings/2026-05-26_WL5-dev-public-setting/`
- Meeting transcript: `00_Meetings/2026-05-26_Martin und Mihailo DevOps Cloud4Log GCP Topics.vtt`
- Clarification chat: `02_Explorations/2026-05-26_GCP_Cloud_Run_Public_Access_vs_Require_Authentication/chat.md`
- Cloud4Log blocker clarification (TMS Bridge architectural intent): `02_Explorations/2026-03-22_Cloud4Log-Blocker-Clarification/blocker-clarification.md`
- TMS Bridge wiki — auth section: `WIKI/Nagel-CAL-Disposition.wiki/Architecure/Backend/Why-TMS-Bridge.md`
- Network config wiki (ingress/egress documentation): `WIKI/Nagel-CAL-Disposition.wiki/Technical-Documentation/Infrastructure/Network-Configuration.md`
- TMS Bridge prod pipeline (source of `--allow-unauthenticated` + `--ingress internal`): `Code/Disposition-Abstraction-Layer/azure-pipelines-cloudrun-p-p.yml:167-168`
- TMS Bridge test pipeline: `Code/Disposition-Abstraction-Layer/azure-pipelines-cloudrun-t-t-wl5.yml:165,170`
- EBV meeting notes (same Keycloak reachability issue): `WIKI/Nagel-CAL-Disposition.wiki/EBV-%2D-TMS-Bridge/EBV-Meeting-Notes-22.07.2025.md`
